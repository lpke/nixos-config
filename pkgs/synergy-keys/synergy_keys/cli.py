"""Inspect or refresh local Synergy screen detection."""

import argparse
import asyncio
import os
import subprocess
import sys

from . import modes, synergy
from .runtime import CONTROLLER_UNIT, TRAY_UNIT, describe, request


def main():
    parser = argparse.ArgumentParser(
        prog="synergy-keys",
        description="Inspect Synergy screen detection. App shortcuts are resolved on the Mac.",
    )
    parser.add_argument("command", nargs="?", default="status", choices=["status", "refresh", "logs"])
    parser.add_argument("--reapply", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--reset-local", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.reapply:
        try:
            request("reapply")
        except OSError:
            pass
        return 0
    if args.reset_local:
        try:
            asyncio.run(modes.apply("local"))
        except (OSError, asyncio.TimeoutError) as error:
            print(f"Cannot restore PC mappings: {error}", file=sys.stderr)
            return 1
        return 0
    if args.command == "logs":
        os.execvp("journalctl", ["journalctl", "--user", "-u", CONTROLLER_UNIT, "-u", TRAY_UNIT,
                               "-n", "60", "--no-pager"])
    if not synergy.processes()["running"]:
        print("Synergy is stopped. Start Synergy sharing first.")
        return 0 if args.command == "status" else 1
    try:
        if args.command == "refresh":
            subprocess.run(["systemctl", "--user", "reset-failed", CONTROLLER_UNIT], check=True, timeout=10)
            subprocess.run(["systemctl", "--user", "start", CONTROLLER_UNIT], check=True, timeout=10)
        response = request("reapply" if args.command == "refresh" else args.command)
        print(describe(response) if args.command == "status" else response.get("message", response.get("error")))
        return 1 if response.get("error") else 0
    except (OSError, subprocess.SubprocessError) as error:
        print(f"Synergy keyboard controller unavailable: {error}. Run synergy-keys logs.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
