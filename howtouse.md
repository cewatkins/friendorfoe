# FriendorFoe How To Use (Backend + Device Visibility)

This file is an operator quick-start focused on your current setup.

## 1) What Was Verified Today

Backend service state is healthy:

- `/health` returns `status: ok`
- Docker services are up and healthy (`api`, `postgres`, `redis`)

Intermittent device visibility is currently explained by node-side input state:

- `/detections/nodes/status` shows one node online: `uplink_F1A528`
- Node has both scanners reported as not connected:
  - BLE slot: `connected: false`
  - WiFi slot: `connected: false`
- Detection counters are zero (`detection_count: 0`, `total_detections: 0`)
- `/detections/devices/live` reports `devices: []`

The Android status checks now probe both Wi-Fi backend addresses used on this LAN:

- `http://192.168.1.208:8000/`
- `http://192.168.1.218:8000/`

The app will keep whichever one answers `/health` first and show that choice in the connection status.

That means backend is running correctly, but no scanner detections are reaching it right now.

## 2) Original FriendorFoe Docs (Primary References)

Start here for official project guidance:

- Main repo guide: [README.md](README.md)
- Hardware wiring and runtime checks: [docs/HARDWARE_WIRING_GUIDE.md](docs/HARDWARE_WIRING_GUIDE.md)
- Live backend smoke checks and expected node behavior: [docs/tdd-live-playbook.md](docs/tdd-live-playbook.md)
- Release/runtime validation checklist: [docs/game_mode_release_checklist.md](docs/game_mode_release_checklist.md)
- Game mode operator workflow: [docs/game_mode_how_to_play.md](docs/game_mode_how_to_play.md)
- Architecture details: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

## 3) Additions Made To Date

The following practical additions were applied in this environment:

1. Docker Compose v2 plugin installed, so `docker compose` works.
2. New operator helper script added: [scripts/fofctl](scripts/fofctl)
3. Backend restart/health flow verified after install.

## 4) Run From Any Terminal Window (Not Just VS Code)

### One-time setup

Add `fofctl` to your user PATH so you can run it anywhere:

```bash
mkdir -p "$HOME/.local/bin"
ln -sf /home/oo/src/friendorfoe/scripts/fofctl "$HOME/.local/bin/fofctl"
grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
source "$HOME/.bashrc"
```

If you move the repo to a new path, update the symlink target:

```bash
ln -sf /NEW/PATH/friendorfoe/scripts/fofctl "$HOME/.local/bin/fofctl"
```

### Daily operations from any shell

Start backend:

```bash
fofctl up
```

Restart backend:

```bash
fofctl restart
```

Stop backend:

```bash
fofctl down
```

Quick status:

```bash
fofctl ps
fofctl health
fofctl nodes
fofctl devices
```

Default interactive monitor (new):

```bash
fofctl
```

Direct monitor launch (same as above):

```bash
fofctl screen
```

Start monitor on a specific view:

```bash
fofctl screen summary
fofctl screen nodes
fofctl screen devices
fofctl screen compose
fofctl screen raw
```

## 5) Live Status Screen (Terminal Dashboard)

Run a continuously refreshing status screen:

```bash
fofctl
```

What it shows:

- Docker container state
- `/health` JSON
- `/detections/devices/live` summary
- `/detections/nodes/status` key node/scanner fields

Interactive controls:

- `1` summary view
- `2` node detail view
- `3` live devices view
- `4` compose services view
- `5` raw JSON view
- `+` faster refresh
- `-` slower refresh
- `r` restart backend stack
- `q` quit monitor

Exit any time with `q` or `Ctrl+C`.

## 6) Phone Update Workflow (USB Manual Install)

When you need to manually update Android by cable:

```bash
cd /home/oo/src/friendorfoe/android
./gradlew assembleDebug
adb devices
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

If `adb devices` does not list your phone:

- Confirm USB cable supports data, not charge-only.
- Re-enable USB debugging on device.
- Accept RSA prompt on phone.

## 7) Why Devices Sometimes Disappear

Most common causes in your current evidence:

1. Uplink heartbeat is present, but scanner UART slots are not connected.
2. Scanner is connected but producing no detections.
3. Device-side radio environment changed (no emitters in range).

Minimum checks when this happens:

```bash
fofctl health
fofctl nodes
fofctl devices
```

Then inspect scanner connectivity fields in node status (`scanners[].connected`, `health`, `uart_raw_seen`).

## 8) Fast Start After Server Move/Reboot

On a fresh boot or moved server, do:

```bash
fofctl restart
fofctl screen
```

If `fofctl` is not found, re-run the one-time setup in section 4.
