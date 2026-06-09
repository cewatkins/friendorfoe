#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-/dev/ttyACM0}"
BACKEND_URL="${2:-}"
WIFI_SSID="${3:-}"

backend_base="${BACKEND_URL%/}"
status_url="${backend_base}/detections/nodes/status"

if [[ -z "${BACKEND_URL}" || -z "${WIFI_SSID}" ]]; then
  echo "Usage: $0 <port> <backend_url> <wifi_ssid>"
  echo "Example: $0 /dev/serial/by-id/<uplink-id> http://192.168.1.218:8000 bpd2"
  echo "Note: if more than one /dev/ttyACM* is present, use /dev/serial/by-id/... or set ALLOW_MULTI_TTYACM=1"
  exit 1
fi

if ! ls /dev/ttyACM* >/dev/null 2>&1; then
  echo "Error: no /dev/ttyACM* devices found. Connect uplink USB data and retry."
  exit 1
fi

mapfile -t ACM_PORTS < <(ls -1 /dev/ttyACM* 2>/dev/null)
if [[ "${#ACM_PORTS[@]}" -gt 1 && "${ALLOW_MULTI_TTYACM:-0}" != "1" ]]; then
  if [[ "$PORT" != /dev/serial/by-id/* ]]; then
    echo "Error: multiple ttyACM devices detected (${ACM_PORTS[*]})."
    echo "Refusing to continue with ambiguous port '$PORT'."
    echo "Use a stable /dev/serial/by-id/... path, unplug one device, or set ALLOW_MULTI_TTYACM=1 to override."
    exit 1
  fi
fi

if [[ ! -e "$PORT" ]]; then
  echo "Error: selected port does not exist: $PORT"
  echo "Available ttyACM devices: ${ACM_PORTS[*]}"
  if [[ -d /dev/serial/by-id ]]; then
    echo "Available by-id links:"
    ls -1 /dev/serial/by-id 2>/dev/null || true
  fi
  exit 1
fi

if [[ ! -c "$PORT" ]]; then
  echo "Error: selected port is not a character device: $PORT"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required but not installed."
  exit 1
fi

if [[ -z "${WIFI_PASS:-}" ]]; then
  read -r -s -p "WiFi password (input hidden): " WIFI_PASS
  echo
fi

set_backend_json="$(jq -cn --arg url "$BACKEND_URL" --arg ssid "$WIFI_SSID" --arg pass "$WIFI_PASS" '{cmd:"set_backend",url:$url,wifi_ssid:$ssid,wifi_pass:$pass,enable:true}')"
set_mode_json='{"cmd":"set_mode","mode":"backend","persist":true}'

echo "Configuring serial port $PORT..."

SUDO_CMD=""
if ! stty -F "$PORT" 115200 raw -echo -echoe -echok -crtscts -ixon -ixoff 2>/dev/null; then
  if sudo -n true 2>/dev/null; then
    SUDO_CMD="sudo"
    sudo stty -F "$PORT" 115200 raw -echo -echoe -echok -crtscts -ixon -ixoff
  else
    echo "Error: cannot access $PORT as current user, and passwordless sudo is unavailable."
    echo "Add your user to dialout (or equivalent) and re-login, or run once with sudo in a terminal."
    exit 1
  fi
fi

send_line() {
  local line="$1"
  if [[ -n "$SUDO_CMD" ]]; then
    $SUDO_CMD python3 - "$PORT" "$line" <<'PY'
import os
import sys
import time

port = sys.argv[1]
payload = (sys.argv[2] + "\n").encode("utf-8", "replace")
fd = os.open(port, os.O_WRONLY | os.O_NONBLOCK)
try:
    sent = 0
    deadline = time.time() + 1.5
    while sent < len(payload):
        if time.time() > deadline:
            raise TimeoutError(f"serial write timeout on {port}")
        n = 0
        try:
            n = os.write(fd, payload[sent:])
        except BlockingIOError:
            time.sleep(0.02)
            continue
        if n <= 0:
            time.sleep(0.02)
            continue
        sent += n
finally:
    os.close(fd)
PY
  else
    python3 - "$PORT" "$line" <<'PY'
import os
import sys
import time

port = sys.argv[1]
payload = (sys.argv[2] + "\n").encode("utf-8", "replace")
fd = os.open(port, os.O_WRONLY | os.O_NONBLOCK)
try:
    sent = 0
    deadline = time.time() + 1.5
    while sent < len(payload):
        if time.time() > deadline:
            raise TimeoutError(f"serial write timeout on {port}")
        n = 0
        try:
            n = os.write(fd, payload[sent:])
        except BlockingIOError:
            time.sleep(0.02)
            continue
        if n <= 0:
            time.sleep(0.02)
            continue
        sent += n
finally:
    os.close(fd)
PY
  fi
  sleep 0.3
}

echo "Sending FOF control commands..."
send_line "FOF_PING"
send_line "FOF_CTL:${set_backend_json}"
send_line "FOF_CTL:${set_mode_json}"
send_line "FOF_REBOOT"

echo "Commands sent. Waiting for reboot..."
sleep 6

echo "Polling backend node status via ${status_url} (45s)..."
for _ in {1..22}; do
  out="$(curl -s --max-time 3 "$status_url" || true)"
  count="$(echo "$out" | jq -r 'if (.count|type)=="number" then .count else 0 end' 2>/dev/null || echo 0)"
  [[ -z "$count" ]] && count="0"
  ids="$(echo "$out" | jq -r '.nodes[].device_id' 2>/dev/null | paste -sd ',' -)"
  [[ -z "$ids" ]] && ids="none"
  echo "$(date +%H:%M:%S) count=${count} ids=${ids}"
  if [[ "$count" =~ ^[0-9]+$ ]] && (( count > 0 )); then
    echo "$out" | jq .
    echo "SUCCESS: at least one node is posting."
    exit 0
  fi
  sleep 2

done

echo "No node heartbeat seen yet at ${status_url}. Check uplink WiFi credentials, network reachability, and scanner->uplink UART wiring."
exit 2
