# Friend or Foe Grand Overview: Sensors, Game Mode, and Integration Plan

## Current status

- Backend is reachable on LAN and is receiving live sensor heartbeats.
- Sensor node uplink_F1A528 is now registered as a fixed node with non-zero coordinates.
- Android game flow is functional and shotdown SFX playback is integrated.
- Calibration walk can fail to start when a previous walk session is still active.

## Why you saw 503 during calibration walk start

Error observed:

- 503 failed to arm fleet calibration mode: calibration already active

What it means:

- A prior calibration session lease is still active in backend session state.
- Starting a second walk session is intentionally blocked to avoid mixed data.

Recovery path:

1. Use the same phone that started the walk and end or abort that session in-app.
2. If the app session is stuck, call backend abort endpoint with that session_id.
3. Retry walk start only after fleet mode returns inactive.

Relevant backend endpoints:

- POST /detections/calibrate/walk/start
- POST /detections/calibrate/walk/sample
- GET /detections/calibrate/walk/feedback
- POST /detections/calibrate/walk/end
- POST /detections/calibrate/walk/abort

## System architecture overview

### 1) ESP32 sensor fleet

Roles:

- Scanner: captures BLE and WiFi RF evidence and emits normalized detections.
- Uplink: bridges scanner output to backend over WiFi and reports node heartbeat/status.

Current production direction in this repo:

- ESP32-S3 targets are the primary path for scanner and uplink hardware.
- Existing S3 scanner profiles include combo and seed variants.

Sensor lifecycle:

1. Sensor boots and joins WiFi.
2. Uplink sends heartbeat and runtime state to backend.
3. Backend merges runtime state with registered node metadata.
4. Geometry and map views consume the normalized sensor state.

### 2) Backend services

Core responsibilities:

- Ingest and normalize detections from sensor nodes.
- Maintain online/offline node status and map/sensor APIs.
- Run triangulation and quality filtering.
- Host calibration walk workflows to fit signal models.

Important behavior:

- Registered fixed node coordinates are used by geometry logic.
- Runtime heartbeat coordinates can still appear in some sensor endpoints if stale payloads are sent.
- Calibration is token-protected using X-Cal-Token.

### 3) Android app

Main surfaces:

- AR and map/list views for situational awareness.
- Game mode for engagement workflows.
- Calibration walk screen for model fitting.

Calibration flow:

1. Test connectivity.
2. Validate token.
3. Load walk sensor list.
4. Start walk and advertise BLE calibration UUID.
5. Tap I am here near each sensor to anchor fit.
6. End walk and apply fit.

## Game mode and sensor integration

How they connect:

- Sensor backend state feeds readiness and live awareness context.
- Game mode itself can run independently, but backend-aware status improves operator confidence.
- Shotdown events now include short randomized explosion SFX.

Operational recommendation:

- Keep one known-good backend URL and token profile on each test phone.
- Use one phone for gameplay checks and one for calibration/operator tasks.

## New ESP32 hardware testing plan

Goal:

- Bring up additional sensor hardware safely without destabilizing known-good fleet behavior.

Phase A: Hardware bring-up

1. Flash target firmware profile for board variant.
2. Verify serial connectivity and stable boot logs.
3. Confirm WiFi join and uplink heartbeat.

Phase B: Backend registration and geometry readiness

1. Register node device_id with fixed lat/lon.
2. Confirm it appears in node registry with geometry enabled.
3. Validate online state in node status endpoint.

Phase C: End-to-end RF path validation

1. Confirm detections arrive from new node.
2. Verify map and sensor APIs show expected node.
3. Run short calibration walk (or anchor checkpoint) if needed.

Phase D: Regression checks

1. Ensure existing nodes remain online.
2. Ensure game mode start/readiness behavior does not regress.
3. Capture logs and notes for any hardware-specific pin/UART differences.

## Branching and execution guidance

Suggested branch for this stream:

- additional-sensor-testing

Suggested commit scopes:

1. docs: overview and operator runbook updates
2. esp32: board profile or pin/serial updates
3. backend: node calibration/sensor normalization fixes
4. android: calibration UX or diagnostics improvements

## Practical next steps

1. Clear active calibration session and return fleet mode to inactive.
2. Validate walk start from one phone only.
3. Add first new ESP32 sensor node, register coordinates, verify online map presence.
4. Run a short controlled calibration and snapshot results.
5. Proceed to second hardware unit after first passes end-to-end checks.
