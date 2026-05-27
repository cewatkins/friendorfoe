# Game Mode + ESP32 + Backend Plan Model

This plan tracks the hardware-backed Game Mode implementation path (normal deployment flow, not Android-only fallback).

## Goal

Enable and validate Game Mode with a live backend and ESP32 scanner/uplink fleet using the standard deployment process.

## Scope

- Backend install and launch for sensor ingestion and map APIs.
- ESP32 firmware build pipeline for scanner and uplink targets.
- Android runtime verification against backend-backed detections.
- Operator-ready runbook for repeatable deployment.

## Out Of Scope

- Cloud production rollout automation.
- Major protocol changes between scanner and uplink.
- Re-architecture of existing game scoring logic.

## Phases

### Pre-Hardware Track (Before ESP32 Devices Arrive)

- Run backend + Android workflow without ESP32 build/flash dependency.
- Validate backend health and node-status endpoints.
- Verify AR Game Mode correctly blocks start when no nodes are online.

Exit criteria:

- Backend endpoint checks pass (`/health`, `/detections/nodes/status`).
- Android HUD shows readiness reason when backend is offline or no nodes are present.
- Operator can run `scripts/game_mode_hardware_deploy.sh --pre-hardware --start-backend` end-to-end.

### Phase 1: Environment Bootstrap

- Verify toolchain (python3, pip, adb, docker or uvicorn path, platformio).
- Install backend dependencies in `backend/.venv`.
- Confirm backend health endpoint is reachable.

Exit criteria:

- `GET /health` returns success.
- Backend process is reachable from Android device/emulator network path.

### Phase 2: Fleet Build/Deploy Prep

- Build scanner firmware (`scanner-s3-combo`, optional seed variant).
- Build uplink firmware (`uplink-s3`).
- Publish operator instructions for flashing existing hardware.

Exit criteria:

- Required firmware environments compile successfully.
- Build artifacts are available in PlatformIO output folders.

### Phase 3: Runtime Validation

- Run Android game mode against live backend + active nodes.
- Verify sessions persist and include expected exit reasons.
- Verify backend sensor endpoints return active node/drone data during gameplay.

Exit criteria:

- Manual and timer sessions persist.
- Backend reports active node telemetry during test window.

### Phase 4: Release Checklist

- Document exact startup/deploy commands.
- Record known caveats and failure recovery steps.

Exit criteria:

- A single operator can run the process from clean checkout.

## Risks

- Device-side permission and lockscreen interference during runtime smoke.
- Signature mismatch on existing debug installs.
- PlatformIO environment drift on host machines.

## Mitigations

- Keep scripted install path with clear fallback messaging.
- Use one-command host verification for persistence checks.
- Keep preflight checks in the deployment flow.

## Success Metrics

- End-to-end deploy/start flow completes in under 20 minutes on a prepared machine.
- Runtime smoke reaches PASS with manual + timer sessions.
- At least one live backend-backed target is visible during game session window.
