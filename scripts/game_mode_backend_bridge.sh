#!/usr/bin/env bash
set -euo pipefail

# Starts the local mock backend and bridges it to all connected Android devices.
# Useful when full backend dependencies cannot run on host Python.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOCK_BACKEND="$REPO_ROOT/backend/mock_backend.py"
PREF_FILE="/tmp/fof_settings_localhost.xml"
APP_ID="com.friendorfoe"
PORT="8000"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

need_cmd python3
need_cmd adb
need_cmd curl

if [[ ! -f "$MOCK_BACKEND" ]]; then
  echo "Mock backend not found: $MOCK_BACKEND" >&2
  exit 1
fi

# Stop any existing mock backend instances to avoid port conflicts.
pkill -f "python3 .*backend/mock_backend.py" >/dev/null 2>&1 || true

nohup python3 "$MOCK_BACKEND" > /tmp/fof_mock_backend.log 2>&1 &

# Wait for health endpoint.
for _ in {1..20}; do
  if curl -fsS "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done

if ! curl -fsS "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
  echo "Mock backend failed to start. Check /tmp/fof_mock_backend.log" >&2
  exit 1
fi

cat > "$PREF_FILE" <<EOF
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <boolean name="sensor_backend_enabled" value="true" />
    <string name="sensor_backend_url">http://127.0.0.1:${PORT}/</string>
</map>
EOF

DEVICES=$(adb devices | awk 'NR>1 && $2=="device" {print $1}')
if [[ -z "${DEVICES}" ]]; then
  echo "No connected adb devices found." >&2
  exit 1
fi

for d in $DEVICES; do
  echo "Configuring $d"
  adb -s "$d" reverse "tcp:${PORT}" "tcp:${PORT}" >/dev/null
  adb -s "$d" push "$PREF_FILE" /data/local/tmp/fof_settings_localhost.xml >/dev/null
  adb -s "$d" shell run-as "$APP_ID" mkdir -p shared_prefs
  adb -s "$d" shell run-as "$APP_ID" cp /data/local/tmp/fof_settings_localhost.xml shared_prefs/fof_settings.xml
  adb -s "$d" shell am force-stop "$APP_ID"
  adb -s "$d" shell am start -n "$APP_ID"/.presentation.MainActivity >/dev/null
  echo "Ready on $d"
done

echo "Mock backend bridge active on http://127.0.0.1:${PORT}"
echo "Log: /tmp/fof_mock_backend.log"
