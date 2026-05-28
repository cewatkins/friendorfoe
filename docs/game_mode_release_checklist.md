# Game Mode Release Checklist

Phase 4 documentation: exact startup/deploy commands, failure recovery, and operator runbook.

## Pre-Deployment Checklist

### Host Requirements
```bash
# Verify Python 3.11+
python3 --version

# Verify Android SDK tools
adb version  # Android Debug Bridge version 37.0.0+
which aapt    # Android Asset Packaging Tool

# Verify PlatformIO (for ESP32 builds)
pio --version  # PlatformIO 6.1+

# Verify Docker (optional for backend)
docker --version  # Optional: for backend database
```

### USB Device Detection
```bash
# List all ADB devices
adb devices -l

# Expected output for phone:
# ZD222MY47W             device usb:1-5.3.2.4 product:cancunn_g_sys model:moto_g_power_5G___2024 device:cancunn

# List USB serial devices
ls -la /dev/ttyUSB* /dev/ttyACM*
# /dev/ttyACM0 = ESP32-S3 scanner/uplink (CH340 adapter)
```

## Startup Commands

### 1. Start Backend (Mock or Real)

#### Mock Backend (Pre-Hardware Testing)
```bash
cd /home/oo/src/friendorfoe/backend
python3 mock_backend.py --bind 127.0.0.1 --port 8000 > /tmp/backend.log 2>&1 &
sleep 2
curl -s http://localhost:8000/health | jq .
# Expected: {"status": "ok", "version": "mock-1.0", "redis": "mock", "database": "mock"}
```

#### Real Backend (Hardware-Ready)
```bash
cd /home/oo/src/friendorfoe/backend
source .venv/bin/activate
pip install -r requirements.txt  # If not already installed
uvicorn app.main:app --host 0.0.0.0 --port 8000 > /tmp/backend.log 2>&1 &
sleep 3
curl -s http://localhost:8000/health | jq .
# Expected: {"status": "ok", "version": "0.64+", "redis": "<status>", "database": "<status>"}
```

### 2. Build and Install Android APK

#### Set Java Version
```bash
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
```

#### Build APK
```bash
cd /home/oo/src/friendorfoe/android
./gradlew clean assembleDebug
# Build completes in ~4 minutes
# Output: app/build/outputs/apk/debug/app-debug.apk (106MB)
```

#### Install on Device
```bash
adb devices -l  # Verify device is online
adb uninstall com.friendorfoe  # Clear any existing install
adb install android/app/build/outputs/apk/debug/app-debug.apk
# Expected: Success
```

### 3. Configure Port Forwarding

```bash
adb reverse tcp:8000 tcp:8000
adb reverse --list
# Expected: UsbFfs tcp:8000 tcp:8000
```

### 4. Launch App

```bash
adb shell am start -n com.friendorfoe/.presentation.MainActivity
sleep 2

# Verify app is running
adb logcat -d | grep -i "backend\|detection\|online" | tail -5
```

### 5. Verify Backend Connectivity

#### Screenshot Check
```bash
adb shell screencap -p /sdcard/screenshot.png
adb pull /sdcard/screenshot.png /tmp/screenshot.png
# Check app shows: "Backend: online · Nodes: 1" (or 0 if no ESP32)
```

#### Backend Health Check
```bash
curl -s http://localhost:8000/health | jq .
curl -s http://localhost:8000/diagnostics/summary | jq .
# Expected: nodes list with status
```

## ESP32 Hardware Deployment (Phase 2)

### Build Firmware

#### Build Scanner Firmware (S3-Combo)
```bash
cd /home/oo/src/friendorfoe/esp32/scanner
pio run -e scanner-s3-combo
# Output: .pio/build/scanner-s3-combo/firmware.bin
# Size: ~1.1 MB (36% flash usage)
```

#### Build Uplink Firmware (S3)
```bash
cd /home/oo/src/friendorfoe/esp32/uplink
pio run -e uplink-s3
# Output: .pio/build/uplink-s3/firmware.bin
```

### Flash Hardware

#### Using Web Flasher
```bash
cd /home/oo/src/friendorfoe/esp32/web-flasher
python3 -m http.server 8080
# Open: http://localhost:8080
# Select firmware.bin from .pio/build/ folders
```

#### Using USB Serial
```bash
cd /home/oo/src/friendorfoe
python3 scripts/fof_flash.py --port /dev/ttyACM0 --firmware esp32/scanner/.pio/build/scanner-s3-combo/firmware.bin
```

## Test Execution

### Game Mode Runtime Validation

#### Test Case 1: Timer-Based Session
```bash
# 1. Open app, tap "Enable" to activate Game Mode
# 2. Let timer run for 120 seconds (auto-end)
# 3. Verify session saved to database with exit_reason="timer"

adb shell "run-as com.friendorfoe cat /data/data/com.friendorfoe/databases/sky_database.db" > /tmp/db.sqlite3
sqlite3 /tmp/db.sqlite3 "SELECT exit_reason, duration_seconds FROM game_sessions ORDER BY id DESC LIMIT 1;"
# Expected: timer, 120
```

#### Test Case 2: Manual Stop Session
```bash
# 1. Open app, tap "Enable" to activate Game Mode
# 2. After 5-10 seconds, tap "Stop" button
# 3. Verify session saved with exit_reason="manual"

sqlite3 /tmp/db.sqlite3 "SELECT exit_reason, duration_seconds FROM game_sessions ORDER BY id DESC LIMIT 1;"
# Expected: manual, <5-10 seconds>
```

#### Test Case 3: Backend Node Reporting
```bash
# While game session is active:
curl -s http://localhost:8000/detections/nodes/status | jq '.nodes[] | {id, last_seen, detection_count}'
# Expected: At least 1 node with recent timestamps and detections
```

### Automated Verification Script
```bash
cd /home/oo/src/friendorfoe
bash scripts/android_game_mode_db_verify.sh --device ZD222MY47W --wait-for-both --wait-timeout-seconds 300
# Waits for both exit_reason values (timer + manual) to appear in database
# Timeout after 5 minutes
```

## Failure Recovery

### ADB Connection Lost
```bash
# Reconnect phone via USB or network
adb kill-server
adb start-server
sleep 2
adb connect 192.168.1.142:5555  # If using network
adb devices -l
```

### Backend Not Responding
```bash
# Check backend logs
tail -50 /tmp/backend.log

# Restart backend
pkill -f "mock_backend\|uvicorn"
sleep 2
python3 mock_backend.py --bind 127.0.0.1 --port 8000 &
curl http://localhost:8000/health
```

### Port Forwarding Lost
```bash
adb reverse --remove tcp:8000
adb reverse tcp:8000 tcp:8000
adb reverse --list
```

### App Installation Failed
```bash
# Clear app data and reinstall
adb uninstall com.friendorfoe
adb install android/app/build/outputs/apk/debug/app-debug.apk

# If APK not found, rebuild:
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
cd android && ./gradlew clean assembleDebug
```

### Game Mode Sessions Not Saving
```bash
# Verify database file exists
adb shell "run-as com.friendorfoe ls -la /data/data/com.friendorfoe/databases/"

# Check database schema
sqlite3 /tmp/db.sqlite3 ".schema game_sessions"
# Expected: exit_reason TEXT NOT NULL column present

# Verify Room DAOs
adb logcat -d | grep -i "roomdao\|database" | tail -10
```

## Rollback Procedure

### Return to Production Branch
```bash
cd /home/oo/src/friendorfoe
git checkout game-mode-esp32-backend-support
git log --oneline -5
```

### Return to Baseline Tag
```bash
git checkout s3-baseline-game-mode-2026-05-27
git log --oneline -5
```

## Success Criteria

- [ ] Backend health endpoint responds at `http://localhost:8000/health`
- [ ] Phone connects via ADB (USB or network)
- [ ] App installs and shows "Backend: online"
- [ ] Port forwarding active (`adb reverse --list` shows mapping)
- [ ] Game mode session persists with exit_reason field
- [ ] Both exit_reason values ("timer" and "manual") appear in database
- [ ] Operator completes full flow in <20 minutes on prepared machine

## Support Contacts

- ESP32/PlatformIO issues: Check docs/INSTALL.md and esp32/CHANGELOG.md
- Android build issues: Check CLAUDE.md build commands section
- Backend diagnostics: `curl http://localhost:8000/diagnostics/summary | jq .`
- Database inspection: `sqlite3 /tmp/db.sqlite3 "SELECT * FROM game_sessions LIMIT 5;"`
