# ESP32-C3 Three-Node Deployment Plan

## Objective

Deploy three flashed ESP32-C3 BLE scanner nodes as a pilot coverage layer and validate stability, detection quality, and placement performance.

## Scope

- Hardware: 3 x ESP32-C3
- Firmware: `ble-scanner-c3`
- Topology: front/center/rear placement
- Validation window: 24 hours minimum, 72 hours preferred

## Phase 1: Physical deployment

1. Place node front at property ingress/drive approach.
2. Place node center near main occupancy zone.
3. Place node rear/opposite edge for overlap and persistence.
4. Confirm each node has stable power and no thermal throttling symptoms.

## Phase 2: Bring-up verification per node

1. Connect by USB.
2. Verify serial output at 115200.
3. Confirm repeated JSON messages:
   - `type=status`
   - `type=detection`
4. Record timestamp and RSSI examples in deployment notes.

## Phase 3: Coverage validation

1. Run all three nodes for at least 24h.
2. Compare detection volume by node and time bucket.
3. Flag dead zones where only one node reports consistently.
4. Adjust placement for balance and overlap.

## Phase 4: Quality gates

Pass criteria:

1. Each node emits status at expected intervals for >= 99% of window.
2. Each node emits detections during active RF periods.
3. No sustained reboot loops or serial lockups.
4. Combined coverage improves over single-node baseline.

Fail criteria:

1. Any node missing status for > 10 minutes repeatedly.
2. Any node with repeated watchdog/reboot behavior.
3. Detection stream absent despite known RF activity.

## Phase 5: Operational handoff

1. Keep this C3 fleet tagged as pilot.
2. Keep S3 fleet as primary production path.
3. Promote C3 role only after stability and integration goals are met.

## Deployment notes template

Use one block per node:

- Node:
- MAC:
- Placement:
- Power source:
- First online time:
- Last checked:
- Status reliability:
- Detection quality notes:
- Actions taken:
