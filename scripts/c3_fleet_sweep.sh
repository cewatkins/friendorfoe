#!/usr/bin/env bash
set -euo pipefail

# Sweep all connected ESP32-C3 serial ports and produce a report.
#
# Usage:
#   ./scripts/c3_fleet_sweep.sh
#   CHECK_SECONDS=20 ./scripts/c3_fleet_sweep.sh
#   ./scripts/c3_fleet_sweep.sh /dev/ttyACM0 /dev/ttyACM1
#
# Notes:
# - Uses sudo -n for serial tools so it fails fast if sudo auth is needed.
# - Designed for later reuse during deployment checks.

CHECK_SECONDS="${CHECK_SECONDS:-15}"
PIO="/home/oo/.platformio/penv/bin/pio"
ESPTOOL_PY="/home/oo/.platformio/packages/tool-esptoolpy/esptool.py"
PYTHON_BIN="/home/oo/.platformio/penv/bin/python"
OUT_DIR="/home/oo/src/friendorfoe/docs/notes/c3-reports"

mkdir -p "$OUT_DIR"
STAMP="$(date +%Y%m%d_%H%M%S)"
REPORT="$OUT_DIR/c3_fleet_sweep_${STAMP}.md"

find_ports() {
  if [[ "$#" -gt 0 ]]; then
    printf '%s\n' "$@"
    return
  fi

  for p in /dev/ttyACM* /dev/ttyUSB*; do
    [[ -e "$p" ]] || continue
    printf '%s\n' "$p"
  done
}

chip_probe() {
  local port="$1"
  sudo -n "$PYTHON_BIN" "$ESPTOOL_PY" --port "$port" chip_id 2>&1 | sed -n '1,24p'
}

read_mac() {
  local port="$1"
  sudo -n "$PYTHON_BIN" "$ESPTOOL_PY" --chip esp32c3 --port "$port" read_mac 2>&1 | awk '/^MAC:/{print $2; exit}'
}

serial_capture() {
  local port="$1"
  local log_file="$2"
  sudo -n timeout "${CHECK_SECONDS}"s "$PIO" device monitor -p "$port" -b 115200 --raw > "$log_file" 2>&1 || true
}

count_json() {
  local needle="$1"
  local file="$2"
  grep -c "$needle" "$file" || true
}

main() {
  mapfile -t ports < <(find_ports "$@")

  {
    echo "# ESP32-C3 Fleet Sweep Report"
    echo
    echo "- Generated: $(date -Iseconds)"
    echo "- Check window per port: ${CHECK_SECONDS}s"
    echo
  } > "$REPORT"

  if [[ "${#ports[@]}" -eq 0 ]]; then
    {
      echo "No serial ports found."
      echo
      echo "Looked for: /dev/ttyACM* and /dev/ttyUSB*"
    } >> "$REPORT"
    echo "No ports found. Report: $REPORT"
    exit 1
  fi

  local total=0
  local c3_count=0
  local pass_count=0

  for port in "${ports[@]}"; do
    total=$((total + 1))

    local probe
    probe="$(chip_probe "$port")"

    {
      echo "## Port: $port"
      echo
      echo '```text'
      echo "$probe"
      echo '```'
      echo
    } >> "$REPORT"

    if ! grep -q "ESP32-C3" <<< "$probe"; then
      echo "- Result: skipped (not ESP32-C3)" >> "$REPORT"
      echo >> "$REPORT"
      continue
    fi

    c3_count=$((c3_count + 1))

    local mac
    mac="$(read_mac "$port" || true)"
    [[ -n "$mac" ]] || mac="unknown"

    local log_file
    log_file="$OUT_DIR/$(basename "$port")_${STAMP}.log"
    serial_capture "$port" "$log_file"

    local status_count detection_count
    status_count="$(count_json '"type":"status"' "$log_file")"
    detection_count="$(count_json '"type":"detection"' "$log_file")"

    local verdict="FAIL"
    if [[ "$status_count" -gt 0 && "$detection_count" -gt 0 ]]; then
      verdict="PASS"
      pass_count=$((pass_count + 1))
    elif [[ "$status_count" -gt 0 ]]; then
      verdict="WARN"
    fi

    {
      echo "- MAC: $mac"
      echo "- Status lines: $status_count"
      echo "- Detection lines: $detection_count"
      echo "- Verdict: $verdict"
      echo "- Log: $log_file"
      echo
    } >> "$REPORT"
  done

  {
    echo "## Summary"
    echo
    echo "- Ports scanned: $total"
    echo "- ESP32-C3 ports: $c3_count"
    echo "- PASS nodes: $pass_count"
    echo
  } >> "$REPORT"

  echo "Fleet sweep complete. Report: $REPORT"
  if [[ "$pass_count" -lt 1 ]]; then
    exit 1
  fi
}

main "$@"
