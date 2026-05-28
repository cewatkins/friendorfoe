#!/usr/bin/env bash
set -euo pipefail

# Pulls Room DB files from Android app sandbox and validates persisted game sessions on host.

APP_ID="com.friendorfoe"
ADB_BIN="${ADB_BIN:-adb}"
OUT_PREFIX="${OUT_PREFIX:-/tmp/friendorfoe}"
REQUIRE_BOTH=0
WAIT_FOR_BOTH=0
WAIT_TIMEOUT_SECONDS=180
POLL_INTERVAL_SECONDS=2
ADB_TARGET_ARGS=()

usage() {
  cat <<'EOF'
Usage:
  scripts/android_game_mode_db_verify.sh [--device SERIAL] [--out-prefix /tmp/friendorfoe] [--require-both] [--wait-for-both] [--wait-timeout-seconds 180] [--poll-interval-seconds 2]

Options:
  --device SERIAL      Target specific adb device serial
  --out-prefix PATH    Output prefix for pulled files (default: /tmp/friendorfoe)
  --require-both       Exit non-zero unless both timer and manual sessions exist
  --wait-for-both      Keep polling until both timer and manual sessions exist (implies --require-both)
  --wait-timeout-seconds N
                       Timeout for wait mode (default: 180)
  --poll-interval-seconds N
                       Poll interval for wait mode (default: 2)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device)
      [[ $# -lt 2 ]] && { echo "Missing value for --device" >&2; exit 1; }
      ADB_TARGET_ARGS=(-s "$2")
      shift 2
      ;;
    --out-prefix)
      [[ $# -lt 2 ]] && { echo "Missing value for --out-prefix" >&2; exit 1; }
      OUT_PREFIX="$2"
      shift 2
      ;;
    --require-both)
      REQUIRE_BOTH=1
      shift
      ;;
    --wait-for-both)
      WAIT_FOR_BOTH=1
      REQUIRE_BOTH=1
      shift
      ;;
    --wait-timeout-seconds)
      [[ $# -lt 2 ]] && { echo "Missing value for --wait-timeout-seconds" >&2; exit 1; }
      WAIT_TIMEOUT_SECONDS="$2"
      shift 2
      ;;
    --poll-interval-seconds)
      [[ $# -lt 2 ]] && { echo "Missing value for --poll-interval-seconds" >&2; exit 1; }
      POLL_INTERVAL_SECONDS="$2"
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

if ! command -v "$ADB_BIN" >/dev/null 2>&1; then
  echo "Missing required command: $ADB_BIN" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Missing required command: python3" >&2
  exit 1
fi

DB_PATH="${OUT_PREFIX}.db"
WAL_PATH="${OUT_PREFIX}.db-wal"
SHM_PATH="${OUT_PREFIX}.db-shm"

run_adb() {
  "$ADB_BIN" "${ADB_TARGET_ARGS[@]}" "$@"
}

run_once() {
  run_adb exec-out run-as "$APP_ID" cat databases/friendorfoe.db > "$DB_PATH"
  run_adb exec-out run-as "$APP_ID" cat databases/friendorfoe.db-wal > "$WAL_PATH"
  run_adb exec-out run-as "$APP_ID" cat databases/friendorfoe.db-shm > "$SHM_PATH"

  python3 - "$DB_PATH" "$REQUIRE_BOTH" <<'PY'
import sqlite3
import sys

path = sys.argv[1]
require_both = sys.argv[2] == "1"

con = sqlite3.connect(path)
cur = con.cursor()

cur.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='game_sessions'")
exists = cur.fetchone()[0]
print(f"game_sessions_table_exists={exists}")
if not exists:
    con.close()
    sys.exit(1 if require_both else 0)

cur.execute("SELECT COUNT(*) FROM game_sessions")
count = cur.fetchone()[0]
print(f"game_sessions_count={count}")

cur.execute("SELECT COALESCE(exit_reason, 'unknown'), COUNT(*) FROM game_sessions GROUP BY COALESCE(exit_reason, 'unknown') ORDER BY 2 DESC, 1")
reason_counts = cur.fetchall()
print("exit_reason_counts:")
for reason, n in reason_counts:
    print(f"  {reason}: {n}")

cur.execute(
    """
    SELECT id, started_at, ended_at, duration_seconds, score, shots, hits, misses,
           best_streak, accuracy_percent, exit_reason
    FROM game_sessions
    ORDER BY ended_at DESC
    LIMIT 10
    """
)
rows = cur.fetchall()
print("latest_sessions:")
for row in rows:
    print("  " + repr(row))

have_timer = any((reason == "timer") for reason, _ in reason_counts)
have_manual = any((reason == "manual") for reason, _ in reason_counts)

if require_both:
    if have_timer and have_manual:
        print("coverage_check=PASS (found timer + manual)")
        code = 0
    else:
        missing = []
        if not have_timer:
            missing.append("timer")
        if not have_manual:
            missing.append("manual")
        print("coverage_check=FAIL (missing " + ", ".join(missing) + ")")
        code = 2
else:
    code = 0

con.close()
sys.exit(code)
PY
}

if [[ "$WAIT_FOR_BOTH" == "1" ]]; then
  deadline=$((SECONDS + WAIT_TIMEOUT_SECONDS))
  attempt=1
  while true; do
    echo "wait_attempt=${attempt}"
    if run_once; then
      exit 0
    fi
    if (( SECONDS >= deadline )); then
      echo "wait_result=TIMEOUT (missing timer/manual coverage after ${WAIT_TIMEOUT_SECONDS}s)" >&2
      exit 2
    fi
    sleep "$POLL_INTERVAL_SECONDS"
    attempt=$((attempt + 1))
  done
else
  run_once
fi
