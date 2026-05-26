# Game Mode: How To Play

This guide explains gameplay flow in the Android AR screen and what to do when nearby ADS-B traffic is low.

## Goal

Score as many points as possible before time runs out.

## Quick Start

1. Open the AR screen.
2. Tap `Enable` in the Game Mode HUD.
3. Aim at floating targets and tap them to fire.
4. Tap `End` to stop early, or let the timer expire.
5. Check results in History under `Recent Game Sessions`.

## Scoring Basics

1. Hits increase score and streak.
2. Misses break streak and reduce accuracy.
3. Accuracy is calculated as `hits / shots`.
4. Better confidence, distance context, and streak can affect points.

## HUD Legend

1. `GAME MODE` / `GAME OFF`: current game state.
2. `Xs  Y pts`: remaining seconds and score.
3. `H / M / S`: hits, misses, streak.
4. `Final Z%`: final session accuracy after stop/timeout.
5. Context hints:
   - `No live targets...`: no current target overlays are visible.
   - `No ADS-B aircraft now...`: gameplay can continue with non-ADS-B targets.
   - `Few ADS-B targets...`: scan a wider area of sky for additional contacts.

## When You See Few ADS-B Objects

1. Slowly pan the camera across open sky and horizon.
2. Wait 10-20 seconds for polling updates.
3. Keep Game Mode enabled; non-ADS-B targets can still be used.
4. If still empty, move to a location with clearer sky view and less obstruction.

## Session Persistence

1. Manual stop and timer completion both save a session.
2. Exiting the AR screen/app while running should end and save the session.
3. Saved fields include score, shots, hits/misses, best streak, accuracy, duration, and exit reason.

## Troubleshooting

1. If the app exits unexpectedly during AR use, reopen and retry with the latest build.
2. If sessions are not visible in History, run the runtime smoke checklist in `docs/game_mode_android_runtime_smoke.md`.
