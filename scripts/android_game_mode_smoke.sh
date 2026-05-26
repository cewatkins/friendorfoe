#!/usr/bin/env bash
set -euo pipefail

# Android runtime smoke helper for gameplay mode persistence.
# - Builds and installs debug APK
# - Launches app main activity
# - Provides adb snippets to verify game session rows in Room DB

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_DIR="$REPO_ROOT/android"
APP_ID="com.friendorfoe"
MAIN_ACTIVITY="com.friendorfoe/.presentation.MainActivity"
ADB_BIN="${ADB_BIN:-adb}"

usage() {
  cat <<'EOF'
Usage:
  scripts/android_game_mode_smoke.sh [--skip-build] [--device SERIAL]

Options:
  --skip-build      Skip Gradle assemble/install steps
  --device SERIAL   Target specific adb device serial

Manual runtime flow after launch:
  1) Enable Game Mode in AR view
  2) Play one session and let timer end
  3) Play another session and end manually
  4) Open History screen and confirm "Recent Game Sessions" cards appear

DB checks (auto-printed by script) validate local persistence in game_sessions table.
EOF
}

SKIP_BUILD=0
ADB_TARGET_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --device)
      [[ $# -lt 2 ]] && { echo "Missing value for --device" >&2; exit 1; }
      ADB_TARGET_ARGS=(-s "$2")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

ensure_device() {
  local count
  count="$($ADB_BIN devices | awk 'NR>1 && $2=="device" {print $1}' | wc -l | tr -d ' ')"
  if [[ "$count" == "0" ]]; then
    echo "No adb device/emulator detected. Connect one and re-run." >&2
    exit 1
  fi
}

run_adb() {
  "$ADB_BIN" "${ADB_TARGET_ARGS[@]}" "$@"
}

ensure_device

if [[ "$SKIP_BUILD" == "0" ]]; then
  echo "[1/4] Building and installing debug APK..."
  (
    cd "$ANDROID_DIR"
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
    PATH=/usr/lib/jvm/java-17-openjdk-amd64/bin:$PATH \
      ./gradlew :app:assembleDebug :app:installDebug --no-daemon
  )
else
  echo "[1/4] Skipping build/install (--skip-build)"
fi

echo "[2/4] Launching app..."
run_adb shell am start -n "$MAIN_ACTIVITY"

echo "[3/4] App launched. Execute manual gameplay flow on device now."
echo "      - Complete one timer-ended session"
echo "      - Complete one manually-ended session"
echo "      - Visit History screen"

echo "[4/4] DB verification commands:"
cat <<'EOF'

# Count persisted sessions
adb shell run-as com.friendorfoe \
  sqlite3 databases/friendorfoe.db "SELECT COUNT(*) FROM game_sessions;"

# Inspect latest sessions
adb shell run-as com.friendorfoe \
  sqlite3 -header -column databases/friendorfoe.db \
  "SELECT id, datetime(started_at/1000,'unixepoch','localtime') AS started,
          datetime(ended_at/1000,'unixepoch','localtime') AS ended,
          duration_seconds, score, shots, hits, misses, best_streak, accuracy_percent, exit_reason
   FROM game_sessions
   ORDER BY ended_at DESC
   LIMIT 5;"
EOF

echo
echo "Tip: add '--device SERIAL' when multiple adb targets are connected."
