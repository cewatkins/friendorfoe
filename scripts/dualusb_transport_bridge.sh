#!/usr/bin/env bash
set -euo pipefail

# Dual-USB scanner->uplink transport bridge.
# Reads scanner JSON lines from one USB serial device and forwards them to
# uplink USB control as FOF_SCANNER_RX frames.

usage() {
  cat <<'EOF'
Usage:
  scripts/dualusb_transport_bridge.sh --scanner-port <port> --uplink-port <port> [--slot ble|wifi]
  scripts/dualusb_transport_bridge.sh --dry-run [--slot ble|wifi] [--input-file <path>]

Options:
  --scanner-port   Scanner serial device (prefer /dev/serial/by-id/*)
  --uplink-port    Uplink serial device (prefer /dev/serial/by-id/*)
  --slot           Logical scanner slot label for uplink ingest (default: ble)
  --dry-run        Parse/filter/forward locally without opening serial devices
  --input-file     Scanner line source for --dry-run (default: stdin)
  --once           Exit after forwarding the first accepted frame
  --stats-interval <sec>   Periodic stats print interval (default: 5)
  --resend-interval <sec>  Min delay between metadata resends (default: 10)
  --resend-stale <sec>     ACK age threshold to trigger resend/warning (default: 20)
  --max-seconds <sec>      Stop bridge after bounded runtime

Example:
  eval "$(scripts/discover_dual_usb.sh)"
  scripts/dualusb_transport_bridge.sh --scanner-port "$FOF_SCANNER_PORT" --uplink-port "$FOF_UPLINK_PORT" --slot ble
EOF
}

scanner_port=""
uplink_port=""
slot="ble"
dry_run=false
once=false
input_file=""
stats_interval_s=5
resend_interval_s=10
resend_ack_stale_s=20
max_seconds=0

sent_count=0
ack_count=0
err_count=0
resend_count=0
err_slot_count=0
err_empty_count=0
err_ingest_count=0
last_ack_epoch=0
last_stats_epoch=0
last_resend_epoch=0

last_status_line=""
last_scanner_info_line=""
forwarded_count=0
stop_requested=false
terminate_reason=""
fd3_open=false
fd4_open=false
timer_pid=""

is_positive_int() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

print_final_summary() {
  local pending ack_age
  pending=$((sent_count - ack_count - err_count))
  ack_age=-1
  if (( last_ack_epoch > 0 )); then
    ack_age=$(( $(date +%s) - last_ack_epoch ))
  fi
  echo "[dualusb-bridge] final reason=${terminate_reason:-normal_exit} forwarded=$forwarded_count sent=$sent_count ack=$ack_count err=$err_count resend=$resend_count pending=$pending ack_age_s=$ack_age"
}

close_bridge_fds() {
  if [[ "$fd4_open" == "true" ]]; then
    { exec 4>&-; } 2>/dev/null || true
    fd4_open=false
  fi
  if [[ "$fd3_open" == "true" ]]; then
    { exec 3>&-; } 2>/dev/null || true
    fd3_open=false
  fi
}

request_shutdown() {
  local reason="$1"
  stop_requested=true
  if [[ -z "$terminate_reason" ]]; then
    terminate_reason="$reason"
  fi
}

cancel_max_runtime_timer() {
  if [[ -n "$timer_pid" ]]; then
    kill "$timer_pid" >/dev/null 2>&1 || true
    wait "$timer_pid" 2>/dev/null || true
    timer_pid=""
  fi
}

start_max_runtime_timer() {
  if (( max_seconds <= 0 )); then
    return
  fi
  (
    sleep "$max_seconds"
    kill -s ALRM "$$" >/dev/null 2>&1 || true
  ) &
  timer_pid="$!"
}

on_exit() {
  cancel_max_runtime_timer
  close_bridge_fds
  print_final_summary
}

trap 'request_shutdown "signal_int"' INT
trap 'request_shutdown "signal_term"' TERM
trap 'request_shutdown "max_seconds"' ALRM
trap on_exit EXIT

print_startup_config() {
  local mode source
  mode="serial"
  source="$scanner_port"
  if [[ "$dry_run" == "true" ]]; then
    mode="dry-run"
    source="${input_file:-stdin}"
  fi

  echo "[dualusb-bridge] config mode=$mode slot=$slot once=$once stats_interval_s=$stats_interval_s resend_interval_s=$resend_interval_s resend_ack_stale_s=$resend_ack_stale_s"
  echo "[dualusb-bridge] config source=$source uplink=${uplink_port:-n/a} max_seconds=$max_seconds"
}

send_bridge_frame() {
  local payload="$1"
  ((sent_count++))
  if [[ "$dry_run" == "true" ]]; then
    # In dry-run mode we report what would be forwarded and treat it as acked.
    echo "[dualusb-bridge][dry-run] FOF_SCANNER_RX:$slot:$payload"
    ((ack_count++))
    last_ack_epoch=$(date +%s)
    return 0
  fi
  printf 'FOF_SCANNER_RX:%s:%s\n' "$slot" "$payload" >&3
}

handle_scanner_line() {
  local line="$1"

  [[ -z "$line" ]] && return 0
  [[ "${line:0:1}" != "{" ]] && return 0

  if [[ "$line" == *'"type":"status"'* ]]; then
    last_status_line="$line"
  elif [[ "$line" == *'"type":"scanner_info"'* ]]; then
    last_scanner_info_line="$line"
  fi

  if [[ "$line" == *'"type":"detection"'* ||
        "$line" == *'"type":"status"'* ||
        "$line" == *'"type":"scanner_info"'* ||
        "$line" == *'"type":"fw_check"'* ||
        "$line" == *'"type":"fw_ready"'* ||
        "$line" == *'"type":"ota_'* ]]; then
    send_bridge_frame "$line" || return 1
    ((forwarded_count++))
    if [[ "$once" == "true" ]]; then
      stop_requested=true
    fi
  fi

  return 0
}

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

  echo "[dualusb-bridge] stats sent=$sent_count ack=$ack_count err=$err_count resend=$resend_count pending=$pending ack_age_s=$ack_age slot_err=$err_slot_count empty_err=$err_empty_count ingest_err=$err_ingest_count"
  if (( pending > 50 )); then
    echo "[dualusb-bridge] warning: high pending backlog ($pending)" >&2
  fi
  if (( sent_count > 0 && ack_age > resend_ack_stale_s )); then
    echo "[dualusb-bridge] warning: uplink ACK stale (${ack_age}s)" >&2
  fi

  last_stats_epoch=$now
}

maybe_resend_cached_control_frames() {
  local now ack_age did_resend
  now=$(date +%s)

  if (( sent_count == 0 || last_ack_epoch == 0 )); then
    return
  fi

  ack_age=$((now - last_ack_epoch))
  if (( ack_age < resend_ack_stale_s )); then
    return
  fi
  if (( last_resend_epoch > 0 && now - last_resend_epoch < resend_interval_s )); then
    return
  fi

  did_resend=0
  if [[ -n "$last_status_line" ]]; then
    if send_bridge_frame "$last_status_line"; then
      ((resend_count++))
      did_resend=1
    fi
  fi
  if [[ -n "$last_scanner_info_line" ]]; then
    if send_bridge_frame "$last_scanner_info_line"; then
      ((resend_count++))
      did_resend=1
    fi
  fi

  if (( did_resend == 1 )); then
    last_resend_epoch=$now
    echo "[dualusb-bridge] resend: replayed cached status/scanner_info after stale ACK" >&2
  fi
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
    --dry-run)
      dry_run=true
      shift
      ;;
    --input-file)
      input_file="${2:-}"
      shift 2
      ;;
    --once)
      once=true
      shift
      ;;
    --stats-interval)
      stats_interval_s="${2:-}"
      shift 2
      ;;
    --resend-interval)
      resend_interval_s="${2:-}"
      shift 2
      ;;
    --resend-stale)
      resend_ack_stale_s="${2:-}"
      shift 2
      ;;
    --max-seconds)
      max_seconds="${2:-}"
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

if [[ "$dry_run" != "true" ]]; then
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
fi

if [[ -n "$input_file" && ! -f "$input_file" ]]; then
  echo "input file does not exist: $input_file" >&2
  exit 2
fi

if ! is_positive_int "$stats_interval_s"; then
  echo "invalid --stats-interval '$stats_interval_s' (must be positive integer seconds)" >&2
  exit 2
fi
if ! is_positive_int "$resend_interval_s"; then
  echo "invalid --resend-interval '$resend_interval_s' (must be positive integer seconds)" >&2
  exit 2
fi
if ! is_positive_int "$resend_ack_stale_s"; then
  echo "invalid --resend-stale '$resend_ack_stale_s' (must be positive integer seconds)" >&2
  exit 2
fi
if [[ "$max_seconds" != "0" ]] && ! is_positive_int "$max_seconds"; then
  echo "invalid --max-seconds '$max_seconds' (must be 0 or positive integer seconds)" >&2
  exit 2
fi

start_max_runtime_timer

if [[ "$slot" != "ble" && "$slot" != "wifi" && "$slot" != "0" && "$slot" != "1" ]]; then
  echo "invalid --slot '$slot' (use ble|wifi|0|1)" >&2
  exit 2
fi

if [[ "$dry_run" == "true" ]]; then
  print_startup_config
  echo "[dualusb-bridge] dry-run enabled"
  while IFS= read -r line; do
    print_bridge_stats_if_due
    handle_scanner_line "$line" || break
    if [[ "$stop_requested" == "true" ]]; then
      break
    fi
  done < "${input_file:-/dev/stdin}"
  if [[ -z "$terminate_reason" && "$once" == "true" && "$stop_requested" == "true" ]]; then
    terminate_reason="once_complete"
  fi
  exit 0
fi

# Configure line-oriented serial behavior.
stty -F "$scanner_port" raw -echo 115200 || true
stty -F "$uplink_port" raw -echo 115200 || true

print_startup_config

while true; do
  if [[ "$stop_requested" == "true" ]]; then
    if [[ -z "$terminate_reason" ]]; then
      terminate_reason="stop_requested"
    fi
    break
  fi

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
  fd3_open=true

  # Read uplink control responses for ACK/ERR tracking.
  exec 4< <(stdbuf -oL cat "$uplink_port") || {
    echo "[dualusb-bridge] failed to start uplink response monitor, retrying..."
    close_bridge_fds
    sleep 1
    continue
  }
  fd4_open=true

  while IFS= read -r line; do
    drain_uplink_responses
    print_bridge_stats_if_due
    maybe_resend_cached_control_frames
    handle_scanner_line "$line" || break
    if [[ "$stop_requested" == "true" ]]; then
      break
    fi
  done < <(stdbuf -oL cat "$scanner_port")

  drain_uplink_responses
  close_bridge_fds
  if [[ "$stop_requested" == "true" ]]; then
    if [[ -z "$terminate_reason" && "$once" == "true" ]]; then
      terminate_reason="once_complete"
    elif [[ -z "$terminate_reason" ]]; then
      terminate_reason="stop_requested"
    fi
    break
  fi
  echo "[dualusb-bridge] stream interrupted, reconnecting..."
  sleep 1
done
