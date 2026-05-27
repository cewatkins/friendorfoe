#!/usr/bin/env bash
set -euo pipefail

# Install common RTL-SDR userland tools used by the sidecar probe.
# Default behavior is dry-run to avoid accidental package changes.

APPLY=0

usage() {
  cat <<'EOF'
Usage:
  scripts/install_sdr_tools.sh [--apply]

Options:
  --apply    Execute package installation (requires sudo/root)
  -h,--help  Show this help

Default:
  Dry-run (prints the command that would be executed)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      APPLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

install_cmd=""

if command -v apt-get >/dev/null 2>&1; then
  install_cmd="sudo apt-get update && sudo apt-get install -y rtl-sdr rtl-433"
elif command -v dnf >/dev/null 2>&1; then
  install_cmd="sudo dnf install -y rtl-sdr rtl_433"
elif command -v pacman >/dev/null 2>&1; then
  install_cmd="sudo pacman -Sy --noconfirm rtl-sdr rtl_433"
else
  echo "No supported package manager detected (apt-get/dnf/pacman)." >&2
  echo "Install manually: rtl_test (rtl-sdr), rtl_433, optionally dump1090." >&2
  exit 2
fi

echo "Detected package manager command: ${install_cmd}"

if [[ "$APPLY" == "0" ]]; then
  echo "Dry-run only. Re-run with --apply to install."
  exit 0
fi

bash -lc "${install_cmd}"
echo "Installation completed."
