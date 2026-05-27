#!/usr/bin/env python3
import json
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


class MockBackendHandler(BaseHTTPRequestHandler):
    server_version = "FoFMockBackend/1.0"

    def _send_json(self, code: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt: str, *args) -> None:
        # Keep logs concise but visible for diagnosis.
        print(f"[{self.log_date_time_string()}] {self.address_string()} {fmt % args}")

    def do_GET(self):
        path = urlparse(self.path).path

        if path == "/health":
            self._send_json(200, {
                "status": "ok",
                "version": "mock-1.0",
                "redis": "mock",
                "database": "mock",
            })
            return

        if path == "/detections/nodes/status":
            self._send_json(200, {
                "count": 1,
                "nodes": [
                    {
                        "device_id": "mock-node-1",
                        "last_seen": datetime.now().timestamp(),
                        "detection_count": 0,
                        "total_batches": 0,
                        "total_detections": 0,
                        "lat": 37.0,
                        "lon": -122.0,
                        "ip": "192.168.1.50",
                        "name": "Mock Node",
                        "age_s": 0.2,
                        "online": True,
                        "gps_registered": True,
                        "firmware_version": "mock",
                    }
                ],
            })
            return

        if path == "/detections/drone-alerts":
            self._send_json(200, {
                "active_drone_count": 0,
                "active_drones": [],
                "recent_alerts": [],
                "total_alerts": 0,
            })
            return

        if path == "/detections/drones/map":
            self._send_json(200, {
                "drone_count": 0,
                "sensor_count": 1,
                "drones": [],
                "sensors": [
                    {
                        "device_id": "mock-node-1",
                        "lat": 37.0,
                        "lon": -122.0,
                        "alt": 0.0,
                        "last_seen": datetime.now().timestamp(),
                        "online": True,
                    }
                ],
            })
            return

        if path == "/detections/sensors":
            self._send_json(200, {
                "count": 1,
                "sensors": [
                    {
                        "device_id": "mock-node-1",
                        "lat": 37.0,
                        "lon": -122.0,
                        "alt": 0.0,
                        "last_seen": datetime.now().timestamp(),
                        "online": True,
                    }
                ],
            })
            return

        if path == "/detections/events":
            self._send_json(200, {"count": 0, "events": []})
            return

        if path == "/detections/events/stats":
            self._send_json(200, {
                "total": 0,
                "unacknowledged": 0,
                "critical_unacked": 0,
                "by_type": {},
                "unack_by_type": {},
                "by_severity": {},
            })
            return

        if path == "/detections/probes":
            self._send_json(200, {"count": 0, "devices": []})
            return

        if path == "/detections/devices/live":
            self._send_json(200, {
                "devices": [],
                "summary": {
                    "total_tracked": 0,
                    "active": 0,
                    "physical_devices": 0,
                    "trackers_active": 0,
                    "classified": 0,
                    "unclassified": 0,
                    "privacy_kind_counts": {},
                    "apple_continuity_subtypes": {},
                    "beacon_density": 0,
                },
            })
            return

        if path == "/detections/wifi/ap-inventory":
            self._send_json(200, {"count": 0, "aps": []})
            return

        if path == "/detections/calibrate/model":
            self._send_json(200, {
                "rssi_ref": -59.0,
                "path_loss_exponent": 2.0,
                "is_calibrated": False,
                "is_active": False,
                "is_trusted": False,
                "active_model_source": "mock",
                "applied_listener_count": 0,
                "last_calibration": None,
                "r_squared": None,
            })
            return

        if path == "/diagnostics/sdr":
            status_path = Path("/tmp/fof_sdr_status.json")
            if status_path.exists():
                try:
                    payload = json.loads(status_path.read_text(encoding="utf-8"))
                except Exception as exc:
                    self._send_json(500, {
                        "ok": False,
                        "error": f"invalid_status_json:{exc}",
                    })
                    return

                self._send_json(200, {
                    "ok": True,
                    "source": str(status_path),
                    "status": payload,
                })
                return

            self._send_json(200, {
                "ok": False,
                "source": str(status_path),
                "status": None,
                "hint": "Run scripts/sdr_sidecar_probe.py to generate status",
            })
            return

        if path == "/diagnostics/summary":
            status_path = Path("/tmp/fof_sdr_status.json")
            sdr_status = None
            sdr_parse_ok = False
            if status_path.exists():
                try:
                    sdr_status = json.loads(status_path.read_text(encoding="utf-8"))
                    sdr_parse_ok = True
                except Exception:
                    sdr_status = None

            self._send_json(200, {
                "ok": True,
                "backend": {
                    "status": "ok",
                    "mode": "mock",
                    "version": "mock-1.0",
                },
                "sdr": {
                    "status_file": str(status_path),
                    "status_file_found": status_path.exists(),
                    "status_parse_ok": sdr_parse_ok,
                    "healthy": bool(sdr_status.get("healthy")) if sdr_status else False,
                    "updated_at": sdr_status.get("updated_at") if sdr_status else None,
                },
            })
            return

        self._send_json(404, {"detail": f"Not found: {path}"})

    def do_POST(self):
        path = urlparse(self.path).path
        if path.startswith("/detections/events/") and path.endswith("/ack"):
            parts = path.split("/")
            event_id = None
            if len(parts) >= 5:
                try:
                    event_id = int(parts[3])
                except ValueError:
                    event_id = None
            self._send_json(200, {"ok": True, "event_id": event_id, "acked": 1})
            return

        self._send_json(404, {"detail": f"Not found: {path}"})


def main() -> None:
    host = "0.0.0.0"
    port = 8000
    server = ThreadingHTTPServer((host, port), MockBackendHandler)
    print(f"Mock backend running on http://{host}:{port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
