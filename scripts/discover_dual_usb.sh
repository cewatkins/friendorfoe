#!/usr/bin/env bash
set -euo pipefail

# Discover and pin scanner/uplink USB serial devices for dual-USB workflows.
# Linux-first: prefers stable /dev/serial/by-id symlinks.

usage() {
  cat <<'EOF'
Usage:
  scripts/discover_dual_usb.sh [--json]

Output:
  Export lines for stable port pinning:
    export FOF_UPLINK_PORT=...
    export FOF_SCANNER_PORT=...

Flags:
  --json   Emit machine-readable JSON only
EOF
}

json_mode=0
if [[ "${1:-}" == "--json" ]]; then
  json_mode=1
elif [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
elif [[ $# -gt 0 ]]; then
  usage >&2
  exit 1
fi

if [[ ! -d /dev/serial/by-id ]]; then
  echo "dual-usb discovery requires /dev/serial/by-id" >&2
  exit 2
fi

mapfile -t candidates < <(ls -1 /dev/serial/by-id 2>/dev/null | sort)
if [[ ${#candidates[@]} -eq 0 ]]; then
  echo "no serial devices found under /dev/serial/by-id" >&2
  exit 3
fi

resolve_dev() {
  local id_path="$1"
  readlink -f "$id_path"
}

classify_role() {
  local id_name="$1"
  local tty_dev="$2"
  local lower
  lower="$(echo "$id_name $tty_dev" | tr '[:upper:]' '[:lower:]')"

  if [[ "$lower" == *"uplink"* ]]; then
    echo "uplink"
    return
  fi
  if [[ "$lower" == *"scanner"* ]]; then
    echo "scanner"
    return
  fi

  # Fallback heuristic: first ttyACM/USB -> uplink, second -> scanner.
  echo "unknown"
}

uplink=""
scanner=""
unknown=()

for name in "${candidates[@]}"; do
  id_path="/dev/serial/by-id/$name"
  dev_path="$(resolve_dev "$id_path")"
  role="$(classify_role "$name" "$dev_path")"
  case "$role" in
    uplink)
      [[ -z "$uplink" ]] && uplink="$id_path"
      ;;
    scanner)
      [[ -z "$scanner" ]] && scanner="$id_path"
      ;;
    *)
      unknown+=("$id_path")
      ;;
  esac
done

if [[ -z "$uplink" && ${#unknown[@]} -gt 0 ]]; then
  uplink="${unknown[0]}"
fi
if [[ -z "$scanner" && ${#unknown[@]} -gt 1 ]]; then
  scanner="${unknown[1]}"
fi

if [[ $json_mode -eq 1 ]]; then
  printf '{"uplink":"%s","scanner":"%s","candidates":["%s"]}\n' \
    "$uplink" "$scanner" "$(printf '%s","' "${candidates[@]}" | sed 's/","$//')"
  exit 0
fi

echo "# Dual-USB port discovery"
echo "# Candidate IDs:"
for name in "${candidates[@]}"; do
  echo "#   /dev/serial/by-id/$name -> $(resolve_dev "/dev/serial/by-id/$name")"
done

echo
if [[ -n "$uplink" ]]; then
  echo "export FOF_UPLINK_PORT=$uplink"
else
  echo "# export FOF_UPLINK_PORT=<set manually>"
fi
if [[ -n "$scanner" ]]; then
  echo "export FOF_SCANNER_PORT=$scanner"
else
  echo "# export FOF_SCANNER_PORT=<set manually>"
fi
