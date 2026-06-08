# ESP32 Role/MAC Map

Last updated: 2026-06-08

Purpose: prevent accidental role swaps between master (uplink) and scanner devices.

## Check-In Mark (Uplink First)

- Timestamp: 2026-06-08
- Confirmed role: uplink (master)
- Port at check-in: /dev/ttyACM0
- MAC at check-in: e8:3d:c1:f3:2c:cc
- Firmware flashed: `esp32/uplink` env `uplink-s3`

## Check-In Mark (Scanner Second)

- Timestamp: 2026-06-08
- Confirmed role: scanner
- Port at check-in: /dev/ttyACM0 (uplink currently unplugged)
- MAC at check-in: e8:3d:c1:f1:a5:28
- Firmware flashed: `esp32/scanner` env `scanner-s3-combo`

## Current Mapping

- Role: scanner candidate
  - Port: /dev/ttyACM1
  - Chip: ESP32-S3
  - MAC: e8:3d:c1:f1:a5:28
  - Notes: connected and probed with esptool.

- Role: master candidate
  - Port: /dev/ttyACM0
  - Chip: ESP32-S3
  - MAC: e8:3d:c1:f3:2c:cc
  - Notes: connected and probed with esptool.

- Previous legacy board reference (currently disconnected)
  - Port: /dev/ttyUSB0 (last seen)
  - Chip: ESP32-D0WD-V3 (classic ESP32)
  - MAC: 88:f1:55:31:cd:d8
  - Notes: use only `esp32/legacy-wroom32` env `wroom32-probe` if this board is used.

## Verification Commands

Use these before flashing:

```bash
cd /home/oo/src/friendorfoe/esp32
pio pkg exec -p tool-esptoolpy -- esptool.py --port /dev/ttyACM0 chip_id
pio pkg exec -p tool-esptoolpy -- esptool.py --port /dev/ttyACM1 chip_id
```

## Backend Online Check

```bash
curl -s http://localhost:8000/detections/nodes/status
```

If output is `{"count":0,"nodes":[]}` then no uplink is reporting, so the app will show "no ESP32 online".
