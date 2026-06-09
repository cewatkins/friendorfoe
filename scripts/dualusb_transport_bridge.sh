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
stats_interval_s=5

sent_count=0
ack_count=0
err_count=0
err_slot_count=0
err_empty_count=0
err_ingest_count=0
last_ack_epoch=0
last_stats_epoch=0

drain_uplink_responses() {
  local ack_line=""
  while IFS= read -r -t 0.001 ack_line <&4; do
    [[ -z "$ack_line" ]] && continue
    case "$ack_line" in
      FOF_SCANNER_RX_OK)
        ((ack_count++))
        last_ack_epoch=$(date +%s)
        ;;
      FOF_SCANNER_RX_ERR:slot)
        ((err_count++))
        ((err_slot_count++))
        ;;
      FOF_SCANNER_RX_ERR:empty)
        ((err_count++))
        ((err_empty_count++))
        ;;
      FOF_SCANNER_RX_ERR:ingest)
        ((err_count++))
        ((err_ingest_count++))
        ;;
      FOF_SCANNER_RX_ERR:*)
        ((err_count++))
        ;;
      *)
        ;;
    esac
  done
}

print_bridge_stats_if_due() {
  local now pending ack_age
  now=$(date +%s)
  if (( last_stats_epoch == 0 )); then
    last_stats_epoch=$now
    return
  fi
  if (( now - last_stats_epoch < stats_interval_s )); then
    return
  fi

  pending=$((sent_count - ack_count - err_count))
  ack_age=-1
  if (( last_ack_epoch > 0 )); then
    ack_age=$((now - last_ack_epoch))
  fi

  echo "[dualusb-bridge] stats sent=$sent_count ack=$ack_count err=$err_count pending=$pending ack_age_s=$ack_age slot_err=$err_slot_count empty_err=$err_empty_count ingest_err=$err_ingest_count"
  if (( pending > 50 )); then
    echo "[dualusb-bridge] warning: high pending backlog ($pending)" >&2
  fi
  if (( sent_count > 0 && ack_age > 20 )); then
    echo "[dualusb-bridge] warning: uplink ACK stale (${ack_age}s)" >&2
  fi

  last_stats_epoch=$now
}

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

if [[ "$slot" != "ble" && "$slot" != "wifi" && "$slot" != "0" && "$slot" != "1" ]]; then
  echo "invalid --slot '$slot' (use ble|wifi|0|1)" >&2
  exit 2
fi

# Configure line-oriented serial behavior.
stty -F "$scanner_port" raw -echo 115200 || true
stty -F "$uplink_port" raw -echo 115200 || true

echo "[dualusb-bridge] scanner=$scanner_port uplink=$uplink_port slot=$slot"

while true; do
  if [[ ! -e "$scanner_port" || ! -e "$uplink_port" ]]; then
    echo "[dualusb-bridge] waiting for device reattach..."
    sleep 1
    continue
  fi

  stty -F "$scanner_port" raw -echo 115200 || true
  stty -F "$uplink_port" raw -echo 115200 || true

  # Open uplink fd for this session so disconnects are recovered cleanly.
  exec 3>"$uplink_port" || {
    echo "[dualusb-bridge] failed to open uplink port, retrying..."
    sleep 1
    continue
  }

  # Read uplink control responses for ACK/ERR tracking.
  exec 4< <(stdbuf -oL cat "$uplink_port") || {
    echo "[dualusb-bridge] failed to start uplink response monitor, retrying..."
    exec 3>&-
    sleep 1
    continue
  }

  while IFS= read -r line; do
    drain_uplink_responses
    print_bridge_stats_if_due

    [[ -z "$line" ]] && continue
    [[ "${line:0:1}" != "{" ]] && continue
    if [[ "$line" == *'"type":"detection"'* ||
          "$line" == *'"type":"status"'* ||
          "$line" == *'"type":"scanner_info"'* ||
          "$line" == *'"type":"fw_check"'* ||
          "$line" == *'"type":"fw_ready"'* ||
          "$line" == *'"type":"ota_'* ]]; then
      ((sent_count++))
      printf 'FOF_SCANNER_RX:%s:%s\n' "$slot" "$line" >&3 || break
    fi
  done < <(stdbuf -oL cat "$scanner_port")

  drain_uplink_responses
  print_bridge_stats_if_due
  exec 3>&-
  exec 4>&-
  echo "[dualusb-bridge] stream interrupted, reconnecting..."
  sleep 1
done
