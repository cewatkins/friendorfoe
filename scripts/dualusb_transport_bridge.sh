#!/usr/bin/env bash
set -euo pipefail

# Dual-USB scanner->uplink transport bridge.
# Reads scanner JSON lines from one USB serial device and forwards them to
# uplink USB control as FOF_SCANNER_RX frames.

usage() {
  cat <<'EOF'
Usage:
  scripts/dualusb_transport_bridge.sh --scanner-port <port> --uplink-port <port> [--slot ble|wifi]

Options:
  --scanner-port   Scanner serial device (prefer /dev/serial/by-id/*)
  --uplink-port    Uplink serial device (prefer /dev/serial/by-id/*)
  --slot           Logical scanner slot label for uplink ingest (default: ble)

Example:
  eval "$(scripts/discover_dual_usb.sh)"
  scripts/dualusb_transport_bridge.sh --scanner-port "$FOF_SCANNER_PORT" --uplink-port "$FOF_UPLINK_PORT" --slot ble
EOF
}

scanner_port=""
uplink_port=""
slot="ble"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scanner-port)
      scanner_port="${2:-}"
      shift 2
      ;;
    --uplink-port)
      uplink_port="${2:-}"
      shift 2
      ;;
    --slot)
      slot="${2:-ble}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$scanner_port" || -z "$uplink_port" ]]; then
  usage >&2
  exit 1
fi

if [[ ! -e "$scanner_port" ]]; then
  echo "scanner port does not exist: $scanner_port" >&2
  exit 2
fi
if [[ ! -e "$uplink_port" ]]; then
  echo "uplink port does not exist: $uplink_port" >&2
  exit 2
fi

# Configure line-oriented serial behavior.
stty -F "$scanner_port" raw -echo 115200 || true
stty -F "$uplink_port" raw -echo 115200 || true

echo "[dualusb-bridge] scanner=$scanner_port uplink=$uplink_port slot=$slot"

# Open uplink fd once and keep it for low-latency writes.
exec 3>"$uplink_port"

# Scanner may emit normal logs and JSON. Forward only likely scanner protocol JSON.
stdbuf -oL cat "$scanner_port" | while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  [[ "${line:0:1}" != "{" ]] && continue
  if [[ "$line" == *'"type":"detection"'* ||
        "$line" == *'"type":"status"'* ||
        "$line" == *'"type":"scanner_info"'* ||
        "$line" == *'"type":"fw_check"'* ||
        "$line" == *'"type":"fw_ready"'* ||
        "$line" == *'"type":"ota_'* ]]; then
    printf 'FOF_SCANNER_RX:%s:%s\n' "$slot" "$line" >&3
  fi
done
