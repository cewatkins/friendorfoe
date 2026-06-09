# dualusb Progress

Date: 2026-06-09
Branch: dualusb

## Request
- Create a new branch named dualusb.
- Check git history to confirm whether scanner<->uplink data transport was already moved off UART to USB.
- Record findings in this file.

## Branch Status
- Branch created and checked out: dualusb.

## Git History Review (evidence)

### Commits that touched serial/USB control
- 7cab81a (2026-03-18): "Fix uplink build: use stdin/stdout for serial config instead of usb_serial_jtag"
  - Files: esp32/uplink/main/CMakeLists.txt, esp32/uplink/main/core/serial_config.c
  - Meaning: control/provisioning channel hardening on uplink console path.

- 4ea1e23 (2026-05-29): "uplink: fix runtime wifi credential usage and serial control stability"
  - Files: esp32/uplink/main/comms/wifi_sta.c, esp32/uplink/main/core/serial_config.c
  - Meaning: runtime serial control stability and Wi-Fi credential behavior fix.

- 748f426 (2026-05-29): "uplink: harden serial provisioning against tty ambiguity"
  - File: scripts/uplink_configure_serial.sh
  - Meaning: host-side provisioning reliability improvements.

- a1282a1 (2026-06-09): "network: harden uplink polling and document interface laws"
  - Files: docs/ESP32_ROLE_MAC_MAP.md, docs/NETWORK_LAWS.md, scripts/uplink_configure_serial.sh
  - Meaning: operational hardening and docs updates.

### What was searched
- History grep for terms like: dualusb, dual usb, usb cdc, usb-serial, serial jtag, scanner/uplink transport.
- File-scoped history for:
  - esp32/uplink
  - esp32/scanner
  - scripts/uplink_configure_serial.sh

## Current Transport Reality (as of this branch point)
- Inter-board data path is still UART-based, not USB data bridge:
  - esp32/shared/uart_protocol.h explicitly defines scanner<->uplink communication as UART newline-delimited JSON.
  - docs/wiring-diagram.html still documents TX->RX + GND wiring for scanner to uplink.

## Conclusion
- No prior commit found that fully migrates scanner<->uplink telemetry/data path from UART to USB CDC/USB bridge transport.
- Previous work improved serial control/provisioning and stability, but did not replace inter-board UART telemetry with USB transport.

## Plan for Dual-USB Transport (next implementation steps)
1. Add a transport abstraction in shared code (UART vs USB endpoint) while preserving current JSON schema.
2. Implement USB-CDC data channel for scanner->uplink payload flow (separate from console/control).
3. Keep UART fallback behind config flags for recovery and backward compatibility.
4. Add health metrics and heartbeat fields to report active transport (uart/usb) and error counters.
5. Update flashing/provisioning scripts to discover and pin both devices reliably under dual USB.
6. Add integration test cases for:
   - scanner online/offline over USB
   - uplink restart with scanner attached
   - reconnect behavior after USB cable replug
   - fallback to UART when USB path unavailable.

## Notes
- Existing unrelated local modifications were present before this work and were not changed by this branch task.

## Implementation Start Marker
- Date: 2026-06-09
- Active branch check-in target: backup/dualusb-20260609-084430
- Phase: Started implementation

### Implemented in this check-in
- Added shared transport abstraction scaffold for UART vs USB selection:
  - esp32/shared/transport_link.h
  - esp32/shared/transport_link.c
- Added transport telemetry keys to protocol schema (additive fields):
  - esp32/shared/uart_protocol.h
- Wired scanner TX/status path to report active transport + fallback + error counters:
  - esp32/scanner/main/comms/uart_tx.c
- Added transport feature flags in scanner/uplink Kconfig:
  - esp32/scanner/main/Kconfig.projbuild
  - esp32/uplink/main/Kconfig.projbuild
- Extended uplink parse/status surfaces with transport health fields:
  - esp32/uplink/main/comms/uart_rx.h
  - esp32/uplink/main/comms/uart_rx.c
  - esp32/uplink/main/network/http_status.c
  - esp32/uplink/main/core/serial_config.c
- Updated operational tooling for dual USB discovery/pinning:
  - scripts/discover_dual_usb.sh
  - scripts/game_mode_hardware_deploy.sh
  - scripts/fofctl
- Added and registered transport unit/integration-sim tests:
  - esp32/test/test_transport_link.c
  - esp32/test/test_transport_integration_sim.c
  - esp32/test/test_runner.c
  - esp32/platformio.ini
  - esp32/scanner/main/CMakeLists.txt

### Validation
- Native tests executed: `cd esp32 && pio test -e test`
- Result: 228 passed, 0 failed.

## Implementation Progress (Go Phase)
- Added practical USB transport path using USB console + host bridge forwarding while keeping UART fallback.

### Added
- Uplink ingest API for scanner lines over non-UART transport:
  - `uart_rx_ingest_transport_line()` in
    - esp32/uplink/main/comms/uart_rx.h
    - esp32/uplink/main/comms/uart_rx.c
- USB control command for injected scanner frames:
  - `FOF_SCANNER_RX:<slot>:<json>` handled in
    - esp32/uplink/main/core/serial_config.c
- Scanner USB output path when transport selects USB:
  - esp32/scanner/main/comms/uart_tx.c
- Host bridge script:
  - scripts/dualusb_transport_bridge.sh
- Deploy guidance updated:
  - scripts/game_mode_hardware_deploy.sh

### Validation
- Native tests re-run after bridge changes: `cd esp32 && pio test -e test`
- Result: 228 passed, 0 failed.

## Implementation Progress (Go+1)
- Hardened USB bridge ingestion observability and reconnect behavior.

### Added/Updated
- Per-scanner bridge ingestion diagnostics in uplink RX:
  - `bridge_rx_lines`, `bridge_rx_bytes`, `bridge_ingest_error_count`
  - Files:
    - esp32/uplink/main/comms/uart_rx.h
    - esp32/uplink/main/comms/uart_rx.c
- Status APIs now expose bridge diagnostics:
  - esp32/uplink/main/network/http_status.c
  - esp32/uplink/main/core/serial_config.c
- USB control ingest command now returns explicit ack/nack lines:
  - `FOF_SCANNER_RX_OK` / `FOF_SCANNER_RX_ERR:*`
  - File: esp32/uplink/main/core/serial_config.c
- Host bridge script robustness:
  - validates slot input
  - auto-reconnect loop on USB stream interruption / cable replug
  - File: scripts/dualusb_transport_bridge.sh
- Operator CLI view includes bridge diagnostics:
  - scripts/fofctl

### Validation
- Native tests re-run after observability hardening: `cd esp32 && pio test -e test`
- Result: 228 passed, 0 failed.

## Implementation Progress (Go+2)
- Hardened `FOF_SCANNER_RX` payload parsing with explicit slot validation and unit coverage.

### Added/Updated
- New shared parser helper for scanner bridge payloads:
  - `esp32/shared/usb_bridge_protocol.h`
  - `esp32/shared/usb_bridge_protocol.c`
  - Supports:
    - bare JSON (defaults to BLE slot)
    - `ble|wifi|0|1:<json>` slot forms
    - explicit parse result codes: `OK`, `EMPTY`, `BAD_SLOT`
- Uplink serial control now uses shared parser and returns specific slot errors:
  - `FOF_SCANNER_RX_ERR:slot`
  - `FOF_SCANNER_RX_ERR:empty`
  - File: `esp32/uplink/main/core/serial_config.c`
- New native tests for parser behavior:
  - `esp32/test/test_usb_bridge_protocol.c`
  - Added to `esp32/test/test_runner.c`
- Native test build now includes parser source:
  - `esp32/platformio.ini`

### Validation
- Native tests re-run after parser hardening: `cd esp32 && pio test -e test`
- Result: 235 passed, 0 failed.

## Implementation Progress (Go+3)
- Added host-bridge ACK/ERR observability to catch degraded USB forwarding in real time.

### Added/Updated
- `scripts/dualusb_transport_bridge.sh`
  - Tracks uplink responses (`FOF_SCANNER_RX_OK` / `FOF_SCANNER_RX_ERR:*`) via a read monitor FD.
  - Maintains live counters:
    - sent, ack, err, pending
    - slot_err, empty_err, ingest_err
  - Emits periodic bridge stats every 5 seconds.
  - Emits warnings on:
    - large pending backlog
    - stale ACKs while traffic is still sent.

### Validation
- Script syntax validated: `bash -n scripts/dualusb_transport_bridge.sh`.

## Implementation Progress (Go+6)
- Added one-shot operator mode for bounded bridge validation runs.

### Added/Updated
- `scripts/dualusb_transport_bridge.sh`
  - New flag: `--once`
  - Behavior:
    - exits after first accepted frame is forwarded
    - works with both normal serial mode and `--dry-run`
    - prints completion summary with forwarded count

### Validation
- Script syntax validated: `bash -n scripts/dualusb_transport_bridge.sh`.

## Implementation Progress (Go+5)
- Added dry-run mode for local validation of bridge filtering and forwarding behavior.

### Added/Updated
- `scripts/dualusb_transport_bridge.sh`
  - New flags:
    - `--dry-run`
    - `--input-file <path>`
  - Dry-run mode skips serial port open/config entirely.
  - Reuses normal JSON filtering and frame formatting logic.
  - Emits forwarded `FOF_SCANNER_RX` lines as preview output.
  - Simulates ACK accounting so bridge stats remain meaningful during local tests.

### Validation
- Script syntax validated: `bash -n scripts/dualusb_transport_bridge.sh`.

## Implementation Progress (Go+4)
- Added bounded auto-resend for control metadata frames when ACKs go stale.

### Added/Updated
- `scripts/dualusb_transport_bridge.sh`
  - Added resend gate with conservative defaults:
    - trigger only when ACK age exceeds stale threshold
    - resend interval to avoid replay storms
  - Replays only cached `status` and `scanner_info` frames.
  - Never replays `detection` frames.
  - Added `resend` counter to periodic bridge stats output.

### Validation
- Script syntax validated: `bash -n scripts/dualusb_transport_bridge.sh`.
