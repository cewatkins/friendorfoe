#!/usr/bin/env bash
set -euo pipefail

# Hardware-backed Game Mode bootstrap for local operator workflows.
# This script keeps the normal backend + ESP32 deployment path repeatable.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$REPO_ROOT/backend"
ANDROID_DIR="$REPO_ROOT/android"
SCANNER_DIR="$REPO_ROOT/esp32/scanner"
UPLINK_DIR="$REPO_ROOT/esp32/uplink"

RUN_BACKEND=0
RUN_ESP32=0
RUN_ANDROID=0
RUN_TESTS=1
START_BACKEND=0
USE_DOCKER=0
PRE_HARDWARE=0
BACKEND_URL="http://localhost:8000"

usage() {
  cat <<'EOF'
Usage:
  scripts/game_mode_hardware_deploy.sh [options]

Options:
  --all             Run backend + esp32 + android (default when none selected)
  --pre-hardware    Run backend + android only and verify backend endpoints
  --backend         Run backend setup and optional tests
  --esp32           Build ESP32 scanner/uplink firmware
  --android         Build and install Android debug app
  --no-tests        Skip backend pytest preflight
  --start-backend   Start backend after setup
  --docker          Start backend with docker compose (implies --start-backend)
  --backend-url URL Backend base URL for validation checks (default: http://localhost:8000)
  -h, --help        Show help

Examples:
  scripts/game_mode_hardware_deploy.sh --all --start-backend
  scripts/game_mode_hardware_deploy.sh --pre-hardware --start-backend
  scripts/game_mode_hardware_deploy.sh --backend --esp32 --docker
  scripts/game_mode_hardware_deploy.sh --android
EOF
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

run() {
  echo "==> $*"
  "$@"
}

backend_setup() {
  need_cmd python3
  need_cmd pip

  echo "--- Backend setup ---"
  cd "$BACKEND_DIR"

  if [[ ! -d .venv ]]; then
    run python3 -m venv .venv
  fi

  # shellcheck disable=SC1091
  source .venv/bin/activate
  run pip install -r requirements.txt

  if [[ ! -f .env && -f .env.example ]]; then
    run cp .env.example .env
  fi

  if [[ "$RUN_TESTS" == "1" ]]; then
    run python3 "$REPO_ROOT/scripts/preflight.py" backend
  fi

  if [[ "$START_BACKEND" == "1" ]]; then
    if [[ "$USE_DOCKER" == "1" ]]; then
      need_cmd docker
      run docker compose up -d
      echo "Backend (docker) started. Health: http://localhost:8000/health"
    else
      echo "Starting uvicorn in background (logs: /tmp/fof_backend.log)"
      nohup .venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000 > /tmp/fof_backend.log 2>&1 &
      echo "Backend (uvicorn) started. Health: http://localhost:8000/health"
    fi
  fi
}

esp32_build() {
  need_cmd pio

  echo "--- ESP32 firmware build ---"
  cd "$SCANNER_DIR"
  run pio run -e scanner-s3-combo

  cd "$UPLINK_DIR"
  run pio run -e uplink-s3

  cat <<'EOF'

Build complete.
Next hardware steps (normal flow):
1) Flash scanner with scanner-s3-combo artifact.
2) Flash uplink with uplink-s3 artifact.
3) Register node in backend and confirm /detections/nodes/status shows online.
EOF
}

android_install() {
  need_cmd adb

  echo "--- Android build/install ---"
  cd "$ANDROID_DIR"

  if [[ -d /usr/lib/jvm/java-17-openjdk-amd64 ]]; then
    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
    export PATH="$JAVA_HOME/bin:$PATH"
  fi

  run ./gradlew :app:assembleDebug :app:installDebug

  cat <<'EOF'

Android installed.
Set backend URL in app settings (or configured backend interceptor) to your backend host,
then run runtime checks with:
  ./scripts/android_game_mode_smoke.sh --verify-host
EOF
}

backend_validate() {
  need_cmd curl

  echo "--- Backend endpoint validation ($BACKEND_URL) ---"
  run curl -fsS "$BACKEND_URL/health" >/dev/null
  run curl -fsS "$BACKEND_URL/detections/nodes/status" >/dev/null

  echo "Backend endpoint checks passed."
  if [[ "$PRE_HARDWARE" == "1" ]]; then
    echo "Pre-hardware mode active: zero online nodes is expected until ESP32 hardware is deployed."
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      RUN_BACKEND=1
      RUN_ESP32=1
      RUN_ANDROID=1
      shift
      ;;
    --pre-hardware)
      PRE_HARDWARE=1
      RUN_BACKEND=1
      RUN_ANDROID=1
      RUN_ESP32=0
      shift
      ;;
    --backend)
      RUN_BACKEND=1
      shift
      ;;
    --esp32)
      RUN_ESP32=1
      shift
      ;;
    --android)
      RUN_ANDROID=1
      shift
      ;;
    --no-tests)
      RUN_TESTS=0
      shift
      ;;
    --start-backend)
      START_BACKEND=1
      shift
      ;;
    --docker)
      START_BACKEND=1
      USE_DOCKER=1
      shift
      ;;
    --backend-url)
      [[ $# -lt 2 ]] && { echo "Missing value for --backend-url" >&2; exit 1; }
      BACKEND_URL="$2"
      shift 2
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

if [[ "$RUN_BACKEND" == "0" && "$RUN_ESP32" == "0" && "$RUN_ANDROID" == "0" ]]; then
  RUN_BACKEND=1
  RUN_ESP32=1
  RUN_ANDROID=1
fi

if [[ "$RUN_BACKEND" == "1" ]]; then
  backend_setup
  backend_validate
fi

if [[ "$RUN_ESP32" == "1" ]]; then
  esp32_build
fi

if [[ "$RUN_ANDROID" == "1" ]]; then
  android_install
fi

echo "Done. See docs/game_mode_esp32_backend_plan.md for phase model and acceptance criteria."
