# ESP32-C3 Fleet Inventory (3 Nodes)

## Status

All three ESP32-C3 units were flashed with `ble-scanner-c3` and serial-verified.

## Node list

1. Node ID: c3-node-01
   MAC: 10:00:3b:dc:c7:9c
   Firmware: ble-scanner-c3
   Verification: detection/status JSON seen on serial monitor

2. Node ID: c3-node-02
   MAC: 10:00:3b:dc:c6:18
   Firmware: ble-scanner-c3
   Verification: detection/status JSON seen on serial monitor

3. Node ID: c3-node-03
   MAC: 10:00:3b:dc:c6:64
   Firmware: ble-scanner-c3
   Verification: detection/status JSON seen on serial monitor

## Recommended labels

- c3-node-01-front
- c3-node-02-center
- c3-node-03-rear

## Placement baseline

- Mount height: 2 to 3 meters
- Keep 1+ meter away from WiFi APs and metal surfaces
- USB power should be stable (avoid noisy adapters)

## Deployment mode

This C3 set is a pilot BLE sensor tier (edge scan role), not a replacement for S3 scanner/uplink production path.
