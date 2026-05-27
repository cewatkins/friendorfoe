# Game Mode WROOM32 Parallel Plan Model

This plan defines a safe experimental track for ESP-WROOM-32 boards without changing the current ESP32-S3 production path.

## Objective

Enable controlled experimentation on classic ESP32 hardware while preserving the existing S3 scanner/uplink architecture and game mode behavior.

## Branch Model

- Primary production branch: game-mode-esp32-backend-support
- Experimental branch: game-mode-wroom32-parallel
- Recovery tag: s3-baseline-game-mode-2026-05-27

Return path (no rebasing required):

```bash
git checkout game-mode-esp32-backend-support
git checkout s3-baseline-game-mode-2026-05-27
```

## Layer 0-7 Consistency Contract

The following must remain consistent with production behavior unless explicitly approved in a dedicated migration step:

0. Protocol contracts: scanner-uplink JSON keys and semantics in shared protocol definitions.
1. Detection semantics: confidence meaning, source mapping, and candidate identity rules.
2. Fusion math: Bayesian scoring constants, decay, and clamp behavior.
3. Position/filter semantics: triangulation inputs and stability assumptions.
4. Backend API contracts: detection ingest and node status endpoints.
5. Android game behavior: scoring, shotdown logic, cooldown, and persistence semantics.
6. Operator flow: deploy/start scripts and expected readiness outcomes.
7. Recovery paths: fallback branch/tag checkout and non-destructive rollback procedure.

## Isolation Rules

- Keep WROOM32 work under esp32/legacy-wroom32 first.
- Do not modify S3 production envs in esp32/scanner/platformio.ini and esp32/uplink/platformio.ini unless the change is proven to be shared-safe.
- Any shared-file changes must include compatibility notes in this plan and explicit test evidence.

## Phase Plan

### Phase A: Hardware Probe Track

- Add isolated WROOM32 probe firmware for USB/serial/LED validation.
- Confirm board detection and flash loop with a data-capable cable.

Exit criteria:

- Device enumerates as /dev/ttyUSB* or /dev/ttyACM*.
- Probe firmware boots and prints expected startup lines at 115200.

### Phase B: Capability Mapping

- Map classic ESP32 constraints vs current S3 feature set (BLE, WiFi promiscuous, memory).
- Define reduced capability profile if full parity is not feasible.

Exit criteria:

- Written capability matrix with hard blockers and feasible substitutions.

### Phase C: Compatibility Adapter Design

- Design adapters that preserve protocol and backend contracts while allowing reduced hardware behavior.
- Keep Android/backend gameplay contracts unchanged.

Exit criteria:

- Adapter design documented with no contract drift in layers 0-7.

### Phase D: Incremental Integration

- Introduce opt-in build targets only.
- Validate no regressions on S3 paths.

Exit criteria:

- S3 build/test paths remain green.
- WROOM32 path builds as experimental target.

## Validation Checklist

- Guardrail report shows which files diverged from baseline tag.
- Android game mode unit tests remain passing.
- Backend smoke endpoints remain passing.
- ESP32 S3 compile path remains unchanged unless intentionally modified.

## Current Status

- Branch and baseline tag established.
- WROOM32 board identified as incompatible with current S3-only production firmware targets.
- Experimental track active for staged compatibility exploration.