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
