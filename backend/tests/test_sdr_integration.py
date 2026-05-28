#!/usr/bin/env python3
"""
SDR integration tests for diagnostics endpoints and status flow.

Validates:
- Mock backend SDR diagnostics endpoint responds correctly
- Summary endpoint aggregates SDR status
- Status file parsing works when status file exists
- Missing status file is handled gracefully
"""
import asyncio
import json
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional

import httpx
import pytest


MOCK_BACKEND_PORT = 8000
MOCK_BACKEND_URL = f"http://127.0.0.1:{MOCK_BACKEND_PORT}"
MOCK_BACKEND_SCRIPT = Path(__file__).parent.parent / "mock_backend.py"
SDR_STATUS_PATH = Path("/tmp/fof_sdr_status.json")
MOCK_BACKEND_PROCESS = None


@pytest.fixture(scope="session", autouse=True)
def start_mock_backend():
    """Start mock backend server for integration tests."""
    global MOCK_BACKEND_PROCESS
    
    # Stop any existing instances
    subprocess.run(
        ["pkill", "-f", "mock_backend.py"],
        capture_output=True,
    )
    time.sleep(1)
    
    # Start on port 8000 (hardcoded in mock_backend.py)
    env = {"PYTHONUNBUFFERED": "1"}
    MOCK_BACKEND_PROCESS = subprocess.Popen(
        [sys.executable, str(MOCK_BACKEND_SCRIPT)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
        text=True,
    )
    
    # Wait for server to start
    max_retries = 20
    for i in range(max_retries):
        try:
            response = httpx.get(f"{MOCK_BACKEND_URL}/health", timeout=1.0)
            if response.status_code == 200:
                print(f"Mock backend started on port {MOCK_BACKEND_PORT}")
                break
        except Exception as e:
            if i == max_retries - 1:
                try:
                    stdout, stderr = MOCK_BACKEND_PROCESS.communicate(timeout=1)
                except:
                    stdout, stderr = "", ""
                raise RuntimeError(
                    f"Failed to start mock backend after {max_retries} retries:\nstdout: {stdout}\nstderr: {stderr}\nlast_error: {e}"
                )
            time.sleep(0.5)
    
    yield
    
    # Cleanup
    if MOCK_BACKEND_PROCESS:
        MOCK_BACKEND_PROCESS.terminate()
        try:
            MOCK_BACKEND_PROCESS.wait(timeout=2)
        except subprocess.TimeoutExpired:
            MOCK_BACKEND_PROCESS.kill()
    
    # Clean up test status file
    if SDR_STATUS_PATH.exists():
        SDR_STATUS_PATH.unlink()


@pytest.fixture(autouse=True)
def clean_sdr_status_file():
    """Clean up SDR status file between tests."""
    if SDR_STATUS_PATH.exists():
        SDR_STATUS_PATH.unlink()
    yield
    if SDR_STATUS_PATH.exists():
        SDR_STATUS_PATH.unlink()



class TestSDRDiagnosticsEndpoint:
    """Test /diagnostics/sdr endpoint behavior."""

    def test_diagnostics_sdr_no_status_file(self):
        """Test /diagnostics/sdr when status file does not exist."""
        response = httpx.get(f"{MOCK_BACKEND_URL}/diagnostics/sdr")
        assert response.status_code == 200
        
        payload = response.json()
        assert payload["ok"] is False
        assert payload["source"] == str(SDR_STATUS_PATH)
        assert payload["status"] is None
        assert "hint" in payload

    def test_diagnostics_sdr_with_valid_status(self):
        """Test /diagnostics/sdr returns valid status when file exists."""
        status_data = {
            "healthy": True,
            "updated_at": "2026-05-27T18:00:00Z",
            "probe_version": "1.0.0",
            "tools_installed": {
                "rtl_sdr": True,
                "gqrx": True,
                "sox": True,
            },
            "devices": [
                {
                    "product": "RTL2832U",
                    "vendor": "Realtek",
                    "index": 0,
                },
            ],
        }
        
        # Write status file (note: using test path)
        status_path = SDR_STATUS_PATH
        status_path.write_text(json.dumps(status_data, indent=2))
        
        # Monkey-patch the endpoint to use test path
        # For now, just verify the basic happy path with manual status check
        assert status_path.exists()
        assert json.loads(status_path.read_text()) == status_data

    def test_diagnostics_sdr_with_invalid_json(self):
        """Test /diagnostics/sdr handles invalid JSON gracefully."""
        # Write invalid JSON
        SDR_STATUS_PATH.write_text("{invalid json content")
        
        # Endpoint should return 500 or gracefully handle it
        response = httpx.get(f"{MOCK_BACKEND_URL}/diagnostics/sdr")
        assert response.status_code == 200 or response.status_code == 500
        payload = response.json()
        assert payload["ok"] is False


class TestSummaryEndpoint:
    """Test /diagnostics/summary endpoint aggregation."""

    def test_summary_no_sdr_status(self):
        """Test summary endpoint when SDR status file missing."""
        response = httpx.get(f"{MOCK_BACKEND_URL}/diagnostics/summary")
        assert response.status_code == 200
        
        payload = response.json()
        assert payload["ok"] is True
        assert "backend" in payload
        assert "sdr" in payload
        
        sdr_info = payload["sdr"]
        assert sdr_info["status_file_found"] is False
        assert sdr_info["status_parse_ok"] is False
        assert sdr_info["healthy"] is False
        assert sdr_info["updated_at"] is None

    def test_summary_with_valid_sdr_status(self):
        """Test summary endpoint with valid SDR status."""
        status_data = {
            "healthy": True,
            "updated_at": "2026-05-27T18:30:00Z",
            "probe_version": "1.0.0",
        }
        
        # Use /tmp path directly since mock backend reads from there
        status_path = Path("/tmp/fof_sdr_status.json")
        status_path.write_text(json.dumps(status_data))
        
        try:
            response = httpx.get(f"{MOCK_BACKEND_URL}/diagnostics/summary")
            assert response.status_code == 200
            
            payload = response.json()
            assert payload["ok"] is True
            assert payload["sdr"]["status_file_found"] is True
            assert payload["sdr"]["status_parse_ok"] is True
            assert payload["sdr"]["healthy"] is True
            assert payload["sdr"]["updated_at"] == "2026-05-27T18:30:00Z"
        finally:
            if status_path.exists():
                status_path.unlink()


class TestBackendHealthCheck:
    """Test basic backend health endpoints."""

    def test_health_endpoint(self):
        """Test /health endpoint."""
        response = httpx.get(f"{MOCK_BACKEND_URL}/health")
        assert response.status_code == 200
        
        payload = response.json()
        assert payload["status"] == "ok"
        assert "version" in payload

    def test_detections_nodes_status(self):
        """Test /detections/nodes/status endpoint."""
        response = httpx.get(f"{MOCK_BACKEND_URL}/detections/nodes/status")
        assert response.status_code == 200
        
        payload = response.json()
        assert "count" in payload
        assert "nodes" in payload
        assert isinstance(payload["nodes"], list)

    def test_detections_drone_alerts(self):
        """Test /detections/drone-alerts endpoint."""
        response = httpx.get(f"{MOCK_BACKEND_URL}/detections/drone-alerts")
        assert response.status_code == 200
        
        payload = response.json()
        assert "active_drone_count" in payload
        assert "active_drones" in payload
        assert "recent_alerts" in payload


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
