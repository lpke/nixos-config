"""User commands and the T3 launch hook."""

import argparse
import json
import os
import subprocess
import sys

from . import runtime


def main():
    parser = argparse.ArgumentParser(prog="t3-ssh", description="Control the persistent T3 SSH connection.")
    parser.add_argument("command", nargs="?", default="status",
                        choices=["start", "stop", "status", "quit", "help", "logs", "auto-start"])
    parser.add_argument("--json", action="store_true", help="Print status for the tray")
    args = parser.parse_args()
    if args.json and args.command != "status":
        parser.error("--json is only for status")
    try:
        if args.command in ("start", "stop", "quit", "auto-start"):
            runtime.control(args.command)
        elif args.command == "help":
            os.execvp("alacritty", ["alacritty", "-e", "nvim", "--", str(runtime.help_file())])
        elif args.command == "logs":
            os.execvp("journalctl", ["journalctl", "--user", "-u", runtime.TUNNEL,
                                   "-u", runtime.TRAY, "-n", "60", "--no-pager"])
        else:
            state = runtime.snapshot()
            print(json.dumps(state) if args.json else runtime.describe(state))
            return 0 if state["connected"] or state["status"] == "Paused" else 1
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        detail = error.stderr.strip() if isinstance(error, subprocess.CalledProcessError) and error.stderr else str(error)
        if args.json:
            print(json.dumps({"connected": False, "active": False, "status": "Connection error", "detail": detail}))
        else:
            print(f"T3 SSH: {detail}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
