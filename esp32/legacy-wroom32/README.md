# Legacy WROOM32 Experimental Probe

This folder is an isolated probe track for classic ESP32 (ESP-WROOM-32) boards.

Purpose:

- Verify USB serial enumeration and basic flash loop.
- Validate board heartbeat independently of production scanner/uplink firmware.
- Keep S3 production paths untouched.

This is not production scanner/uplink firmware.

## Build / Flash

From this folder:

```bash
pio run
pio run -t upload
pio device monitor -b 115200
```

Expected serial output:

- "FoF legacy WROOM32 probe booted"
- alternating "tick:on" and "tick:off" every ~500ms

## Notes

- Current Friend or Foe scanner/uplink firmware targets ESP32-S3 only.
- Use this probe track to establish hardware baseline before any compatibility adapter work.