# ESP32-S3 Hardware Wiring Guide

## Overview
This guide documents the physical connection between two ESP32-S3-DevKitC-1 boards:
- **Board #1 (Scanner):** Running scanner-s3-combo firmware
- **Board #2 (Uplink):** Running uplink-s3 firmware

Communication: UART at 921,600 baud

Important: this guide targets current S3 production firmware pin mapping
(`scanner-s3-combo` + `uplink-s3`). Do not use legacy GPIO1/GPIO3 examples
for this pairing.

---

## Wiring Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  BOARD #1 (SCANNER)                    BOARD #2 (UPLINK)       │
│  ═══════════════════════════════════════════════════════════    │
│                                                                 │
│   USB                                     USB                   │
│   ┌─┐  (Power)                            ┌─┐  (Power)         │
│   └─┘                                     └─┘                   │
│    │                                       │                    │
│  ┌─────────────────────────────────────────────┐                │
│  │ GND ─────────────────────────────────────── GND              │
│  │   (Common Ground)                                            │
│  └─────────────────────────────────────────────┘                │
│    │                                       │                    │
│    │                                       │                    │
│  ┌─────────────────────────────────────────────┐                │
│  │ TX (GPIO17) ───────────────────────── RX (GPIO18)            │
│  │   (Serial Out)        UART@921.6kbaud  (Serial In)           │
│  └─────────────────────────────────────────────┘                │
│    │                                       │                    │
│  ┌─────────────────────────────────────────────┐                │
│  │ RX (GPIO18) ───────────────────────── TX (GPIO17)            │
│  │   (Serial In)         UART@921.6kbaud  (Serial Out)          │
│  └─────────────────────────────────────────────┘                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Pin Mapping: ESP32-S3-DevKitC-1

### UART Interface
| Signal | Pin | ESP32-S3 GPIO | Description |
|--------|-----|---------------|-------------|
| TX     | 17  | GPIO17        | Serial Transmit |
| RX     | 18  | GPIO18        | Serial Receive |
| GND    | GND | GND           | Common Ground |

### ESP32-S3-DevKitC Layout (Top View)

```
┌────────────────────────────────────┐
│  BOARD: ESP32-S3-DevKitC-1         │
│                                    │
│  USB Connector (Left)              │
│  ┌──┐                              │
│  │  │ ← Power / USB Serial Debug    │
│  └──┘                              │
│                                    │
│  IO Row (Bottom):                  │
│  ┌─────────────────────────────┐   │
│  │ GND │ IO3 │ IO1 │ ...       │   │
│  └─────────────────────────────┘   │
│                                    │
│  Use labeled GPIO pins on header:  │
│   - IO17 (TX for scanner)          │
│   - IO18 (RX for scanner)          │
│   - GND                            │
│                                    │
└────────────────────────────────────┘
```

---

## Wiring Instructions

### Materials Needed
- **2× Jumper Wires (Female-to-Female)** for TX/RX
- **1× Jumper Wire (Female-to-Female)** for GND
- Or use raw wire + male-to-female pin headers if needed

### Step-by-Step Wiring

#### 1. **Ground Connection (GND)**
- **From:** Board #1 GND pin (leftmost, labeled "G" or "GND")
- **To:** Board #2 GND pin
- **Connect:** Single female-to-female jumper wire
- **Purpose:** Common reference for both boards

#### 2. **Data Transmission (TX → RX)**
- **From:** Board #1 TX (GPIO17)
- **To:** Board #2 RX (GPIO18)  *(BLE slot on uplink)*
- **Connect:** Female-to-female jumper wire
- **Purpose:** Scanner sends detection data to Uplink

#### 3. **Data Reception (RX ← TX)**
- **From:** Board #1 RX (GPIO18)
- **To:** Board #2 TX (GPIO17)  *(BLE slot on uplink)*
- **Connect:** Female-to-female jumper wire
- **Purpose:** Uplink sends command responses back to Scanner

### Wiring Summary Table

```
┌──────────────────┬──────────────────┬─────────────────────┐
│  Board #1        │  Board #2        │  Wire Color/Label   │
│  (Scanner)       │  (Uplink)        │                     │
├──────────────────┼──────────────────┼─────────────────────┤
│ GND              │ GND              │ Black (Ground)      │
│ GPIO17 (TX)      │ GPIO18 (RX)      │ Red (Data → )       │
│ GPIO18 (RX)      │ GPIO17 (TX)      │ Yellow (Data ← )    │
└──────────────────┴──────────────────┴─────────────────────┘
```

---

## Verification Checklist

Before powering on, verify:

- [ ] **GND wire connected** between both boards
- [ ] **TX→RX wire** goes from Board #1 GPIO17 to Board #2 GPIO18
- [ ] **RX←TX wire** goes from Board #1 GPIO18 to Board #2 GPIO17
- [ ] **All wires fully inserted** into female headers (no loose connections)
- [ ] **No crossed wires** or reversed connections
- [ ] **USB cables ready** (for power; debug not needed yet)

---

## Power-Up Procedure

1. **Connect Board #1 (Scanner)** to USB power
   - Should boot normally
   - LED may blink (if equipped)

2. **Connect Board #2 (Uplink)** to USB power
   - Should boot normally
   - May show WiFi connection attempts in logs

3. **Monitor Serial Output** (optional, for diagnostics):
   ```bash
   # Board #1 (Scanner) - check for UART transmission
   sudo screen /dev/ttyACM0 115200
   
   # Board #2 (Uplink) - check for UART reception + WiFi connection
   sudo screen /dev/ttyACM1 115200
   ```

4. **Verify Backend Connection**:
   ```bash
   # Check if Uplink registered with backend
   curl -s http://localhost:8000/detections/nodes/status | jq '.nodes'
   ```

---

## Port Identification Playbook (Scanner vs Uplink)

Use this every time boards get replugged so `/dev/ttyACM*` ambiguity never blocks you.

### Why `/dev/ttyACM0` and `/dev/ttyACM1` Keep Flipping

- Linux assigns `ttyACM*` by detection order.
- Replug/reboot order can swap board numbers.
- Always use `/dev/serial/by-id/*` for stable identity instead of raw `ttyACM*`.

### Stable IDs Found On This Bench

```bash
ls -l /dev/serial/by-id

# Current observed IDs:
# usb-1a86_USB_Single_Serial_5C4C140287-if00 -> ../../ttyACM0
# usb-1a86_USB_Single_Serial_5C4D043024-if00 -> ../../ttyACM1
```

### Verified Mapping (as of 2026-05-28)

Firmware fingerprint verification from flash dump confirms:

- `SCANNER`:
   - Port: `/dev/ttyACM0`
   - Stable ID: `/dev/serial/by-id/usb-1a86_USB_Single_Serial_5C4C140287-if00`
   - USB serial short: `5C4C140287`
   - ESP32 MAC: `e8:3d:c1:f3:2c:cc`
   - Fingerprint strings: `fof_scanner`, `scanner-s3-combo`

- `UPLINK`:
   - Port: `/dev/ttyACM1`
   - Stable ID: `/dev/serial/by-id/usb-1a86_USB_Single_Serial_5C4D043024-if00`
   - USB serial short: `5C4D043024`
   - ESP32 MAC: `e8:3d:c1:f1:a5:28`
   - Fingerprint strings: `fof_uplink`, `uplink-s3`

If `ttyACM0/1` ever swap, the `/dev/serial/by-id/*` links and MAC/fingerprint
checks still identify the board roles correctly.

### Step A: Capture Stable Metadata

```bash
udevadm info -q property -n /dev/ttyACM0 | rg "ID_SERIAL_SHORT=|ID_PATH="
udevadm info -q property -n /dev/ttyACM1 | rg "ID_SERIAL_SHORT=|ID_PATH="
```

Store the result in your notes:
- `ID_SERIAL_SHORT=5C4C140287`
- `ID_SERIAL_SHORT=5C4D043024`

### Step B: Identify Which Board Is Which (Reset Test)

1. Open two serial monitors (one per stable ID).
2. Press **RST** on one physical board.
3. The terminal that prints the reboot banner belongs to that board.
4. Label that board physically (sticker/tape): `UPLINK` or `SCANNER`.

Use `picocom` (recommended):

```bash
sudo picocom -b 115200 /dev/serial/by-id/usb-1a86_USB_Single_Serial_5C4C140287-if00
sudo picocom -b 115200 /dev/serial/by-id/usb-1a86_USB_Single_Serial_5C4D043024-if00
```

Important notes:
- Use `115200` for boot/status text.
- `9600` often shows gibberish.
- Scanner UART payload can still look noisy/binary during traffic bursts; that is normal.
- Exit `picocom` with `Ctrl-a`, then `Ctrl-x`.

### Step C: Persist Mapping For Next Time

Create a small local mapping file once you confirm roles:

```bash
cat > /tmp/fof-port-map.txt <<'EOF'
SCANNER=/dev/serial/by-id/usb-1a86_USB_Single_Serial_<SHORT_ID>-if00
UPLINK=/dev/serial/by-id/usb-1a86_USB_Single_Serial_<SHORT_ID>-if00
EOF
cat /tmp/fof-port-map.txt
```

Optional permanent shell aliases:

```bash
echo "alias fof_scanner='picocom -b 115200 /dev/serial/by-id/usb-1a86_USB_Single_Serial_<SCANNER_ID>-if00'" >> ~/.bashrc
echo "alias fof_uplink='picocom -b 115200 /dev/serial/by-id/usb-1a86_USB_Single_Serial_<UPLINK_ID>-if00'" >> ~/.bashrc
source ~/.bashrc
```

### Step D: Backend Validation Command (After Uplink Config)

```bash
watch -n 2 'curl -s http://localhost:8000/detections/nodes/status | jq "{count, nodes: [.nodes[] | {device_id, online, total_batches, total_detections, age_s}]}"'
```

Expected:
- `count >= 1`

---

## Uplink USB Config (Steps 1-4)

If `picocom` shows no readable output, you can still configure uplink over USB.
The control protocol requires `FOF_CTL:` prefixes (raw JSON lines alone are ignored).

Use the helper script:

```bash
cd /home/oo/src/friendorfoe
./scripts/uplink_configure_serial.sh /dev/ttyACM1 http://192.168.1.208:8000 <YOUR_WIFI_SSID>
```

What it does:
- Step 1: sets backend URL
- Step 2: sets WiFi SSID/password (password prompt is hidden)
- Step 3: sets backend mode persistently
- Step 4: reboots uplink and polls `/detections/nodes/status`

Manual equivalent (protocol-correct):

```bash
printf 'FOF_CTL:{"cmd":"set_backend","url":"http://192.168.1.208:8000","wifi_ssid":"<SSID>","wifi_pass":"<PASS>","enable":true}\n' | sudo tee /dev/ttyACM1 >/dev/null
printf 'FOF_CTL:{"cmd":"set_mode","mode":"backend","persist":true}\n' | sudo tee /dev/ttyACM1 >/dev/null
printf 'FOF_REBOOT\n' | sudo tee /dev/ttyACM1 >/dev/null
```

Success indicators in backend status output:
- real `device_id` from uplink
- `total_batches` increasing

---

## Troubleshooting

### Big Blocker: `scanner_connected=false`

If `/api/status` shows `scanner_connected: false` and both scanner slots are
`health: "missing"`, the uplink sees zero UART bytes from scanner.

Required checks, in order:

1. Confirm scanner firmware is `scanner-s3-combo` and uplink firmware is
   `uplink-s3`.
2. Re-check physical UART wiring for S3 production mapping:
   - Scanner GPIO17 -> Uplink GPIO18
   - Scanner GPIO18 -> Uplink GPIO17
   - GND <-> GND
3. Keep both boards powered by USB (brownout can silently break UART traffic).
4. After rewiring, reboot scanner first, then uplink.
5. Re-check uplink status:

```bash
curl -s http://192.168.4.1/api/status | jq '{scanner_connected, scanners}'
```

Expected recovery signal:
- `scanner_connected: true`
- at least one scanner entry has `connected: true` and `uart_raw_seen: true`

### No UART Communication
- **Check:** Verify all three wires are firmly inserted
- **Check:** Confirm TX→RX and RX←TX directions (no swaps)
- **Check:** GND wire is connected (required for voltage reference)
- **Action:** Reseat wires and test again

### Uplink Not Connecting to WiFi
- **Check:** Uplink firmware built successfully (55.6% flash usage ✓)
- **Check:** WiFi credentials in Uplink firmware config
- **Action:** Check logs via serial console if available

### Backend Not Seeing Nodes
- **Check:** Backend running at localhost:8000
- **Check:** Uplink has active WiFi connection
- **Action:** Verify with `curl http://localhost:8000/health`

---

## Reference: ESP32-S3 UART Hardware Details

- **Baud Rate:** 921,600 bps (fixed in firmware)
- **Protocol:** Newline-delimited JSON (UART protocol defined in `esp32/shared/uart_protocol.h`)
- **Format:** Short JSON keys: `src`, `conf`, `mfr`, `mac`, `sig`, etc.
- **Idle:** When no detection data, Scanner transmits heartbeat every 30 seconds
- **Error Handling:** Both boards handle framing errors gracefully; CRC validation on multi-byte fields

---

## Next Steps

1. **Wire the boards** using the instructions above
2. **Power on both** via USB
3. **Verify communication** by checking backend node status
4. **Start game mode** and run detection session

**Estimated time to completion:** 5 minutes wiring + 2 minutes power-up + 1 minute verification = **~8 minutes**

---

*Document created: 2026-05-28*
*Hardware: ESP32-S3-DevKitC-1 (N8, 8MB QD, No PSRAM) × 2*
*Firmware: scanner-s3-combo + uplink-s3*
