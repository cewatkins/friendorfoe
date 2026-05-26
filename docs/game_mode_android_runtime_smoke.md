# Android Runtime Smoke - Game Mode Persistence

This checklist verifies gameplay runtime behavior and local persistence on a real Android device or emulator.

## Preconditions

1. Android SDK + adb available.
2. One connected adb target (`adb devices`).
3. Repo built with Java 17 for Android tasks.

## Fast Path

Run:

```bash
scripts/android_game_mode_smoke.sh
```

This will:

1. Build/install debug APK.
2. Launch `com.friendorfoe/.presentation.MainActivity`.
3. Print SQL commands for local DB verification.

## Manual Validation Flow

1. Open AR view and enable Game Mode.
2. Play one session and let timer expire.
3. Start another session and end it manually.
4. Open History screen.
5. Confirm `Recent Game Sessions` cards are visible and ordered by recency.

## Expected UI Results

1. At least two session cards in History.
2. Each card shows:
   - score
   - date/time
   - duration
   - hits/misses
   - best streak
   - accuracy percent
   - exit reason (`timer` or `manual`)
3. Session cards are visible even when detection history list is empty.

## DB Verification

```bash
adb shell run-as com.friendorfoe \
  sqlite3 databases/friendorfoe.db "SELECT COUNT(*) FROM game_sessions;"
```

```bash
adb shell run-as com.friendorfoe \
  sqlite3 -header -column databases/friendorfoe.db \
  "SELECT id, datetime(started_at/1000,'unixepoch','localtime') AS started,
          datetime(ended_at/1000,'unixepoch','localtime') AS ended,
          duration_seconds, score, shots, hits, misses, best_streak, accuracy_percent, exit_reason
   FROM game_sessions
   ORDER BY ended_at DESC
   LIMIT 5;"
```

## Failure Signals

1. `game_sessions` count stays zero after completed sessions.
2. Session exits from AR are not saved unless app is restarted.
3. History shows empty state despite session rows in DB.
4. Duration or accuracy is clearly inconsistent with session behavior.

## Notes

- Gameplay guide: `docs/game_mode_how_to_play.md`

- If multiple adb targets are connected, use a specific serial:

```bash
scripts/android_game_mode_smoke.sh --device <serial>
```
