# ESP32-C3 Flash and Test Runbook

## Scope

This runbook is for bring-up and test flashing of ESP32-C3 boards using the BLE scanner firmware path in this repository.

- Firmware target: ble-scanner-c3
- Board class: ESP32-C3 USB JTAG/Serial boards
- Typical USB device id: 303a:1001

## Prerequisites

- Branch checked out: additional-sensor-testing
- PlatformIO available at /home/oo/.platformio/penv/bin/pio
- Board connected by USB and visible at /dev/ttyACM0 (or equivalent)

## 1) Detect the board and serial path

Run:

```bash
ls -l /dev/serial/by-id
stat -c '%A %a %U %G %n' /dev/ttyACM0
```

Expected:

- by-id symlink points to ttyACM path
- Node exists with mode 660 and group dialout

## 2) Temporary serial access without reboot (if needed)

If the current login session cannot open ttyACM:

```bash
sudo setfacl -m u:$USER:rw /dev/ttyACM0
getfacl -p /dev/ttyACM0
```

If ACL tools are unavailable:

```bash
sudo chown $USER:dialout /dev/ttyACM0
sudo chmod 660 /dev/ttyACM0
```

## 3) Build the C3 firmware

```bash
cd /home/oo/src/friendorfoe/esp32/ble-scanner
/home/oo/.platformio/penv/bin/pio run -e ble-scanner-c3
```

Success criteria:

- Environment ble-scanner-c3 reports SUCCESS

Notes:

- Build warning may report flash mismatch (expected 4MB, found 2MB). The project currently writes with flash_size 2MB during direct flash for these test boards.

## 4) Flash the board

Preferred upload:

```bash
cd /home/oo/src/friendorfoe/esp32/ble-scanner
/home/oo/.platformio/penv/bin/pio run -e ble-scanner-c3 -t upload --upload-port /dev/ttyACM0
```

If upload fails due tty permission in current session, flash directly with esptool:

```bash
cd /home/oo/src/friendorfoe/esp32/ble-scanner/.pio/build/ble-scanner-c3
sudo -n /home/oo/.platformio/penv/bin/python /home/oo/.platformio/packages/tool-esptoolpy/esptool.py \
  --chip esp32c3 --port /dev/ttyACM0 --baud 921600 write_flash -z \
  --flash_mode dio --flash_freq 80m --flash_size 2MB \
  0x0 bootloader.bin 0x8000 partitions.bin 0x10000 firmware.bin
```

## 5) Runtime verification

Capture logs for 10-15 seconds:

```bash
cd /home/oo/src/friendorfoe/esp32/ble-scanner
sudo -n timeout 15s /home/oo/.platformio/penv/bin/pio device monitor \
  -p /dev/ttyACM0 -b 115200 --raw
```

Success signals in output:

- Detection JSON lines with type=detection
- Periodic status JSON lines with type=status

## 6) Repeat for next ESP32-C3 board

For each new board:

1. Unplug current board
2. Plug the next board
3. Re-run section 1 to confirm new serial mapping
4. Re-run section 4 to flash
5. Re-run section 5 to verify logs

## Troubleshooting quick map

- Permission denied opening /dev/ttyACM0:
  - Apply section 2 ACL/ownership workaround
- Root-owned .pio artifacts causing build write errors:
  - sudo chown -R $USER:$USER .pio
  - remove failing env build dir and rebuild
- Build fails from mixed scanner shared sources:
  - Ensure branch includes C3 blocker fixes in this stream

## Current branch checkpoints

- docs: add high-level integration overview
- esp32: fix ble-scanner c3 build blockers
