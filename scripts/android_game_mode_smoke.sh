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
  scripts/android_game_mode_smoke.sh [--skip-build] [--device SERIAL] [--replace-signature] [--verify-host]

Options:
  --skip-build      Skip Gradle assemble/install steps
  --device SERIAL   Target specific adb device serial
  --replace-signature
                    If install fails due signature mismatch, uninstall existing
                    com.friendorfoe from device and retry installDebug.
  --verify-host     Skip launch/build flow and run host DB verification only.

Manual runtime flow after launch:
  1) Enable Game Mode in AR view
  2) Play one session and let timer end
  3) Play another session and end manually
  4) Open History screen and confirm "Recent Game Sessions" cards appear

DB checks (auto-printed by script) validate local persistence in game_sessions table.
EOF
}

SKIP_BUILD=0
REPLACE_SIGNATURE=0
VERIFY_HOST_ONLY=0
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
    --replace-signature)
      REPLACE_SIGNATURE=1
      shift
      ;;
    --verify-host)
      VERIFY_HOST_ONLY=1
      shift
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

warn_if_lockscreen_visible() {
  local ui_tmp
  ui_tmp="/tmp/friendorfoe_ui_lockcheck.xml"
  run_adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 || return 0
  run_adb pull /sdcard/ui.xml "$ui_tmp" >/dev/null 2>&1 || return 0
  if grep -q "com.android.systemui" "$ui_tmp" && grep -q "Device locked\|keyguard" "$ui_tmp"; then
    echo "Warning: device appears locked; unlock it before gameplay steps or adb UI automation." >&2
  fi
}

run_host_verification() {
  python3 - <<'PY'
import os
import sqlite3
import subprocess
import sys
import tempfile

app_id = "com.friendorfoe"
candidate_paths = [
    "databases/friendorfoe.db",
    "files/friendorfoe.db",
    "files/databases/friendorfoe.db",
    "no_backup/friendorfoe.db",
]

def run(cmd):
    return subprocess.run(cmd, check=False, capture_output=True, text=True)

db_tmp = os.path.join(tempfile.gettempdir(), "friendorfoe_runtime_smoke.db")
pulled = False
used = None
for rel in candidate_paths:
    exists = run(["adb", "exec-out", "run-as", app_id, "sh", "-c", f"[ -f {rel} ] && echo yes || true"])
    if "yes" not in exists.stdout:
        continue
    with open(db_tmp, "wb") as f:
        proc = subprocess.run(["adb", "exec-out", "run-as", app_id, "cat", rel], check=False, stdout=f)
    if proc.returncode == 0 and os.path.getsize(db_tmp) > 0:
        pulled = True
        used = rel
        break

if not pulled:
    print("DB not found yet. Complete two sessions first, then rerun with --verify-host.")
    sys.exit(0)

conn = sqlite3.connect(db_tmp)
cur = conn.cursor()
cur.execute("SELECT COUNT(*) FROM game_sessions")
count = cur.fetchone()[0]
print(f"db_path: {used}")
print(f"game_sessions count: {count}")
cur.execute(
  """
  SELECT exit_reason, COUNT(*)
  FROM game_sessions
  GROUP BY exit_reason
  """
)
reason_counts = {reason: c for reason, c in cur.fetchall()}
manual_count = reason_counts.get("manual", 0)
timer_count = reason_counts.get("timer", 0)
print(f"exit_reason counts: manual={manual_count}, timer={timer_count}")
cur.execute(
    """
    SELECT id, duration_seconds, score, shots, hits, misses, best_streak, accuracy_percent, exit_reason
    FROM game_sessions
    ORDER BY ended_at DESC
    LIMIT 5
    """
)
rows = cur.fetchall()
if rows:
    print("latest sessions:")
    for r in rows:
        print(r)
else:
    print("No session rows yet.")

if manual_count >= 1 and timer_count >= 1:
  print("SMOKE_STATUS: PASS (manual + timer sessions persisted)")
else:
  print("SMOKE_STATUS: INCOMPLETE (need at least one manual and one timer session)")
conn.close()
PY
}

ensure_device

if [[ "$VERIFY_HOST_ONLY" == "1" ]]; then
  run_host_verification
  exit 0
fi

if [[ "$SKIP_BUILD" == "0" ]]; then
  echo "[1/4] Building and installing debug APK..."
  (
    cd "$ANDROID_DIR"
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
    PATH=/usr/lib/jvm/java-17-openjdk-amd64/bin:$PATH \
      ./gradlew :app:assembleDebug --no-daemon
  )

  INSTALL_OK=0
  (
    cd "$ANDROID_DIR"
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
    PATH=/usr/lib/jvm/java-17-openjdk-amd64/bin:$PATH \
      ./gradlew :app:installDebug --no-daemon
  ) && INSTALL_OK=1

  if [[ "$INSTALL_OK" == "0" ]]; then
    if [[ "$REPLACE_SIGNATURE" == "1" ]]; then
      echo "Install failed. Attempting uninstall + reinstall due --replace-signature..."
      run_adb uninstall "$APP_ID" || true
      (
        cd "$ANDROID_DIR"
        JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
        PATH=/usr/lib/jvm/java-17-openjdk-amd64/bin:$PATH \
          ./gradlew :app:installDebug --no-daemon
      )
    else
      echo "Install failed (possibly signature mismatch). Re-run with --replace-signature to uninstall existing app and retry." >&2
      exit 1
    fi
  fi
else
  echo "[1/4] Skipping build/install (--skip-build)"
fi

echo "[2/4] Launching app..."
run_adb shell am start -n "$MAIN_ACTIVITY"
warn_if_lockscreen_visible

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

# Host fallback (works even when device sqlite3 is unavailable)
python3 - <<'PY'
import os
import sqlite3
import subprocess
import sys
import tempfile

app_id = "com.friendorfoe"
candidate_paths = [
  "databases/friendorfoe.db",
  "files/friendorfoe.db",
  "files/databases/friendorfoe.db",
  "no_backup/friendorfoe.db",
]

def run(cmd):
  return subprocess.run(cmd, check=False, capture_output=True, text=True)

db_tmp = os.path.join(tempfile.gettempdir(), "friendorfoe_runtime_smoke.db")
pulled = False
for rel in candidate_paths:
  exists = run(["adb", "exec-out", "run-as", app_id, "sh", "-c", f"[ -f {rel} ] && echo yes || true"])
  if "yes" not in exists.stdout:
    continue
  with open(db_tmp, "wb") as f:
    proc = subprocess.run(["adb", "exec-out", "run-as", app_id, "cat", rel], check=False, stdout=f)
  if proc.returncode == 0 and os.path.getsize(db_tmp) > 0:
    pulled = True
    break

if not pulled:
  print("DB not found yet. Complete two sessions first, then rerun this fallback block.")
  sys.exit(0)

conn = sqlite3.connect(db_tmp)
cur = conn.cursor()
cur.execute("SELECT COUNT(*) FROM game_sessions")
count = cur.fetchone()[0]
print(f"game_sessions count: {count}")
cur.execute(
  """
  SELECT exit_reason, COUNT(*)
  FROM game_sessions
  GROUP BY exit_reason
  """
)
reason_counts = {reason: c for reason, c in cur.fetchall()}
manual_count = reason_counts.get("manual", 0)
timer_count = reason_counts.get("timer", 0)
print(f"exit_reason counts: manual={manual_count}, timer={timer_count}")

cur.execute(
  """
  SELECT id, started_at, ended_at, duration_seconds, score, shots, hits, misses, best_streak, accuracy_percent, exit_reason
  FROM game_sessions
  ORDER BY ended_at DESC
  LIMIT 5
  """
)
rows = cur.fetchall()
if rows:
  print("latest sessions:")
  for r in rows:
    print(r)
else:
  print("No session rows yet.")

if manual_count >= 1 and timer_count >= 1:
  print("SMOKE_STATUS: PASS (manual + timer sessions persisted)")
else:
  print("SMOKE_STATUS: INCOMPLETE (need at least one manual and one timer session)")

conn.close()
PY
EOF

echo
echo "Tip: add '--device SERIAL' when multiple adb targets are connected."
echo "Tip: rerun quick host verification with: scripts/android_game_mode_smoke.sh --verify-host"
