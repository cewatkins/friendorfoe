#!/usr/bin/env bash
set -euo pipefail

# Quick operator check for ESP32-C3 BLE scanner nodes over serial.
# Usage:
#   ./scripts/c3_fleet_quickcheck.sh /dev/ttyACM0
# Optional:
#   CHECK_SECONDS=20 ./scripts/c3_fleet_quickcheck.sh /dev/ttyACM0

PORT="${1:-}"
CHECK_SECONDS="${CHECK_SECONDS:-15}"
PIO="/home/oo/.platformio/penv/bin/pio"
ESPTOOL_PY="/home/oo/.platformio/packages/tool-esptoolpy/esptool.py"
PYTHON_BIN="/home/oo/.platformio/penv/bin/python"

if [[ -z "$PORT" ]]; then
  echo "Usage: $0 /dev/ttyACM0" >&2
  exit 2
fi

if [[ ! -e "$PORT" ]]; then
  echo "Port not found: $PORT" >&2
  exit 3
fi

echo "[1/3] Probing chip and MAC on $PORT"
sudo -n "$PYTHON_BIN" "$ESPTOOL_PY" --port "$PORT" chip_id | sed -n '1,18p'

echo "[2/3] Capturing ${CHECK_SECONDS}s serial output"
LOG_FILE="/tmp/c3_quickcheck_$(basename "$PORT")_$(date +%s).log"
sudo -n timeout "${CHECK_SECONDS}"s "$PIO" device monitor -p "$PORT" -b 115200 --raw > "$LOG_FILE" || true

echo "[3/3] Evaluating log: $LOG_FILE"
STATUS_COUNT="$(grep -c '"type":"status"' "$LOG_FILE" || true)"
DETECTION_COUNT="$(grep -c '"type":"detection"' "$LOG_FILE" || true)"

echo "status lines: $STATUS_COUNT"
echo "detection lines: $DETECTION_COUNT"

if [[ "$STATUS_COUNT" -gt 0 && "$DETECTION_COUNT" -gt 0 ]]; then
  echo "PASS: status and detection output observed"
  exit 0
fi

if [[ "$STATUS_COUNT" -gt 0 ]]; then
  echo "WARN: status seen but no detections in this short window"
  exit 1
fi

echo "FAIL: no status output observed"
exit 1
