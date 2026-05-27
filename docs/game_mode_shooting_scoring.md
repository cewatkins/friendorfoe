# Game Mode Shooting and Scoring

This document defines how a shot is evaluated, how points are awarded, and how targets are removed after being shot down.

## Shot Lifecycle

1. Player taps a target label in AR.
2. If game mode is active and shot cooldown has passed, the shot is counted.
3. If the target is valid and still active, the shot is a hit.
4. If no valid target is selected, the shot is a miss.
5. Hits increase streak; misses reset streak to 0.

## Hit Scoring Formula

Each hit uses:

- Base points
- Confidence bonus
- Distance bonus
- Streak multiplier

In simplified form:

- `hit_points = (base + confidence_bonus + distance_bonus) * streak_multiplier`

Higher confidence, longer distance context, and larger pre-hit streak produce larger rewards.

## Shotdown Mechanics

Each target tracks cumulative hit count and cumulative points from hits.

A target is considered shot down when either threshold is reached:

- Aircraft:
  - Hit threshold: 3 hits
  - Points threshold: 900 points
  - Shotdown bonus: +250 points
- Drone:
  - Hit threshold: 2 hits
  - Points threshold: 600 points
  - Shotdown bonus: +150 points

Once shot down:

1. The target is removed from active AR gameplay overlays.
2. It no longer grants additional gameplay points.
3. A shotdown event is recorded in the session state and history summary.

## Session Metrics

Game mode tracks:

- Total score
- Shots, hits, misses
- Accuracy percent
- Current streak and best streak
- Shotdown count
- Shotdown target summaries

Session history stores shotdown count and a compact list of shotdown targets for post-game review.
