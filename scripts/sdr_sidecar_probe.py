#!/usr/bin/env python3
"""Lightweight SDR sidecar probe for parallel game-mode testing.

This script does not integrate SDR IQ into the app pipeline.
It only records host-level SDR availability and basic probe output so
operators can continue app testing while hardware flashing is blocked.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


RTL_PATTERNS = ("0bda:2838", "rtl2838", "rtl2832", "realtek")


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def run_cmd(cmd: list[str], timeout_s: float = 8.0) -> tuple[int, str, str]:
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout_s,
            check=False,
        )
        return proc.returncode, proc.stdout.strip(), proc.stderr.strip()
    except Exception as exc:  # pragma: no cover - defensive path
        return 99, "", str(exc)


def detect_rtl_usb() -> dict[str, Any]:
    if shutil.which("lsusb") is None:
        return {
            "connected": False,
            "reason": "lsusb_not_available",
            "matches": [],
        }

    rc, out, err = run_cmd(["lsusb"])
    if rc != 0:
        return {
            "connected": False,
            "reason": "lsusb_failed",
            "error": err,
            "matches": [],
        }

    matches: list[str] = []
    for line in out.splitlines():
        low = line.lower()
        if any(p in low for p in RTL_PATTERNS):
            matches.append(line)

    return {
        "connected": len(matches) > 0,
        "reason": "ok",
        "matches": matches,
    }


def probe_tool(name: str, args: list[str], timeout_s: float = 6.0) -> dict[str, Any]:
    exe = shutil.which(name)
    if exe is None:
        return {
            "available": False,
            "path": None,
            "rc": None,
            "stdout": "",
            "stderr": "",
        }

    rc, out, err = run_cmd([exe, *args], timeout_s=timeout_s)
    return {
        "available": True,
        "path": exe,
        "rc": rc,
        "stdout": out,
        "stderr": err,
    }


def build_status() -> dict[str, Any]:
    rtl_usb = detect_rtl_usb()
    rtl_test = probe_tool("rtl_test", ["-t"], timeout_s=10.0)
    rtl_433 = probe_tool("rtl_433", ["-h"], timeout_s=5.0)
    dump1090 = probe_tool("dump1090", ["--help"], timeout_s=5.0)

    healthy = bool(rtl_usb.get("connected")) and (
        bool(rtl_test.get("available"))
        or bool(rtl_433.get("available"))
        or bool(dump1090.get("available"))
    )

    install_hint = None
    if not healthy:
        install_hint = {
            "helper_script": "scripts/install_sdr_tools.sh --apply",
            "required_tools": ["rtl_test", "rtl_433"],
            "optional_tools": ["dump1090"],
        }

    return {
        "updated_at": utc_now(),
        "healthy": healthy,
        "rtl_usb": rtl_usb,
        "tools": {
            "rtl_test": rtl_test,
            "rtl_433": rtl_433,
            "dump1090": dump1090,
        },
        "note": "Host SDR health only; not direct app ingest.",
        "install_hint": install_hint,
    }


def write_status(path: Path, status: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(status, indent=2), encoding="utf-8")


def run_once(output: Path) -> dict[str, Any]:
    status = build_status()
    write_status(output, status)
    return status


def main() -> int:
    parser = argparse.ArgumentParser(description="FoF SDR sidecar probe")
    parser.add_argument(
        "--output",
        default="/tmp/fof_sdr_status.json",
        help="Path to write status JSON (default: /tmp/fof_sdr_status.json)",
    )
    parser.add_argument(
        "--watch",
        action="store_true",
        help="Continuously refresh status file",
    )
    parser.add_argument(
        "--interval",
        type=float,
        default=5.0,
        help="Watch interval in seconds (default: 5)",
    )
    args = parser.parse_args()

    output = Path(args.output)

    if not args.watch:
        status = run_once(output)
        print(json.dumps(status, indent=2))
        return 0

    print(f"Writing SDR status to {output} every {args.interval:.1f}s")
    while True:
        status = run_once(output)
        print(
            f"[{status['updated_at']}] healthy={status['healthy']} "
            f"usb_connected={status['rtl_usb']['connected']}"
        )
        time.sleep(max(args.interval, 1.0))


if __name__ == "__main__":
    raise SystemExit(main())
