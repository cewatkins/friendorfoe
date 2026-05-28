# ESP32-S3 Hardware Wiring Guide

## Overview
This guide documents the physical connection between two ESP32-S3-DevKitC-1 boards:
- **Board #1 (Scanner):** Running scanner-s3-combo firmware
- **Board #2 (Uplink):** Running uplink-s3 firmware

Communication: UART at 921,600 baud

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
│  │ TX (GPIO1) ────────────────────────── RX (GPIO3)             │
│  │   (Serial Out)        UART@921.6kbaud  (Serial In)           │
│  └─────────────────────────────────────────────┘                │
│    │                                       │                    │
│  ┌─────────────────────────────────────────────┐                │
│  │ RX (GPIO3) ────────────────────────── TX (GPIO1)             │
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
| TX     | 1   | GPIO1         | Serial Transmit |
| RX     | 3   | GPIO3         | Serial Receive |
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
│  Marking: Pin 1 = GND (far left)   │
│           Pin 3 = IO3 (RX)         │
│           Pin 4 = IO1 (TX)         │
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
- **From:** Board #1 TX (GPIO1, labeled "IO1" or "1")
- **To:** Board #2 RX (GPIO3, labeled "IO3" or "3")
- **Connect:** Female-to-female jumper wire
- **Purpose:** Scanner sends detection data to Uplink

#### 3. **Data Reception (RX ← TX)**
- **From:** Board #1 RX (GPIO3, labeled "IO3" or "3")
- **To:** Board #2 TX (GPIO1, labeled "IO1" or "1")
- **Connect:** Female-to-female jumper wire
- **Purpose:** Uplink sends command responses back to Scanner

### Wiring Summary Table

```
┌──────────────────┬──────────────────┬─────────────────────┐
│  Board #1        │  Board #2        │  Wire Color/Label   │
│  (Scanner)       │  (Uplink)        │                     │
├──────────────────┼──────────────────┼─────────────────────┤
│ GND              │ GND              │ Black (Ground)      │
│ GPIO1 (TX)       │ GPIO3 (RX)       │ Red (Data → )       │
│ GPIO3 (RX)       │ GPIO1 (TX)       │ Yellow (Data ← )    │
└──────────────────┴──────────────────┴─────────────────────┘
```

---

## Verification Checklist

Before powering on, verify:

- [ ] **GND wire connected** between both boards
- [ ] **TX→RX wire** goes from Board #1 GPIO1 to Board #2 GPIO3
- [ ] **RX←TX wire** goes from Board #1 GPIO3 to Board #2 GPIO1
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

## Troubleshooting

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
