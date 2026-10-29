"""Inspect or refresh local Synergy screen detection."""

import argparse
import asyncio
import json
import os
import subprocess
import sys

from . import modes, synergy
from .runtime import CONTROLLER_UNIT, TRAY_UNIT, describe, request


def main():
    parser = argparse.ArgumentParser(
        prog="synergy-keys",
        description="Inspect Synergy shortcuts and screen detection. App shortcuts are resolved on the Mac.",
    )
    parser.add_argument("command", nargs="?", default="status", choices=["status", "refresh", "logs", "inspect"])
    parser.add_argument("shortcut", nargs="?", help="Initial inspector search, or exact chord with --json")
    parser.add_argument("--json", action="store_true", help="Print an inspector trace without opening a window")
    parser.add_argument("--device", choices=["Keyboard", "Logitech G903"], default="Keyboard", help="Device for --json inspection")
    parser.add_argument("--reapply", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--reset-local", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.command != "inspect" and (args.shortcut or args.json or args.device != "Keyboard"):
        parser.error("shortcut, --json and --device are only for inspect")
    if args.command == "inspect":
        if args.json:
            if not args.shortcut:
                parser.error("inspect --json requires a shortcut")
            from .inspector import trace
            from .inspector_sources import Sources
            try:
                print(trace(Sources(), args.shortcut, args.device).json())
                return 0
            except (OSError, ValueError, subprocess.SubprocessError) as error:
                print(json.dumps({"error": str(error)}), file=sys.stderr)
                return 1
        from .inspector_ui import main as inspect
        return inspect(args.shortcut or "")
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
