"""Inspect or refresh local Synergy screen detection."""

import argparse
import asyncio
import json
import os
from pathlib import Path
import subprocess
import sys

from . import controls, modes, synergy
from .runtime import CONTROLLER_UNIT, TRAY_UNIT, describe, request


def main():
    parser = argparse.ArgumentParser(
        prog="synergy-keys",
        description="Inspect Synergy shortcuts and screen detection. App shortcuts are resolved on the Mac.",
    )
    parser.add_argument("command", nargs="?", default="status", choices=["status", "refresh", "logs", "help", "inspect", "pause", "resume", "synergy"])
    parser.add_argument("shortcut", nargs="?", help="Inspector search, or Synergy action: pause, resume, config")
    parser.add_argument("--json", action="store_true", help="Print an inspector trace without opening a window")
    parser.add_argument("--device", choices=["Keyboard", "Logitech G903"], default="Keyboard", help="Device for --json inspection")
    parser.add_argument("--reapply", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--reset-local", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.command not in ("inspect", "synergy") and (args.shortcut or args.json or args.device != "Keyboard"):
        parser.error("shortcut, --json and --device are only for inspect")
    if args.command == "synergy" and (args.shortcut not in ("pause", "resume", "config") or args.json):
        parser.error("synergy requires pause, resume or config")
    if args.command == "help":
        try:
            cache = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "synergy-keys"
            cache.mkdir(mode=0o700, parents=True, exist_ok=True)
            path = cache / "help.txt"
            path.write_text(parser.format_help())
            os.execvp("alacritty", ["alacritty", "-e", "nvim", "--", str(path)])
        except OSError as error:
            print(f"Cannot open command help: {error}", file=sys.stderr)
            return 1
    if args.command in ("pause", "resume", "synergy"):
        try:
            controls.control("synergy" if args.command == "synergy" else "keys", args.shortcut if args.command == "synergy" else args.command)
            print(f"{'Synergy' if args.command == 'synergy' else 'synergy-keys'}: {args.shortcut or args.command}")
            return 0
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            detail = error.stderr.strip() if isinstance(error, subprocess.CalledProcessError) and error.stderr else str(error)
            print(detail, file=sys.stderr)
            return 1
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
    if controls.preferences().get("keys_paused", False):
        print("synergy-keys is paused. Run synergy-keys resume to enable mappings.")
        return 0 if args.command == "status" else 1
    if not synergy.processes()["running"]:
        paused = controls.preferences().get("synergy_paused", False)
        print(f"Synergy is {'paused' if paused else 'stopped'}. Run synergy-keys synergy resume to start sharing.")
        return 0 if args.command == "status" else 1
    try:
        if args.command == "refresh":
            controls.start_controller()
        response = request("reapply" if args.command == "refresh" else args.command)
        print(describe(response) if args.command == "status" else response.get("message", response.get("error")))
        return 1 if response.get("error") else 0
    except (OSError, subprocess.SubprocessError) as error:
        print(f"Synergy keyboard controller unavailable: {error}. Run synergy-keys logs.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
