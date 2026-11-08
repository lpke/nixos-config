"""Public command interface; no credentials or encrypted T3 catalog access."""

import argparse
import json
import os
import subprocess
import sys
from . import runtime


def main():
    parser = argparse.ArgumentParser(prog="t3-tailscale", description="Control the T3 Tailscale gateway route and tray.")
    parser.add_argument("command", nargs="?", default="status",
                        choices=["start", "stop", "status", "quit", "help", "logs"])
    parser.add_argument("--json", action="store_true", help="Print structured status")
    args = parser.parse_args()
    if args.json and args.command != "status":
        parser.error("--json is only for status")
    try:
        if args.command in ("start", "stop", "quit"):
            runtime.control(args.command)
            print(f"T3 Tailscale: {args.command}")
        elif args.command == "help":
            os.execvp("alacritty", ["alacritty", "-e", "nvim", "--", str(runtime.help_file())])
        elif args.command == "logs":
            subprocess.run(["journalctl", "--user", "-u", runtime.TRAY, "-n", "60", "--no-pager"], check=True)
            subprocess.run(["journalctl", "-u", "tailscaled.service", "-n", "60", "--no-pager"], check=False)
        else:
            state = runtime.snapshot()
            print(json.dumps(state) if args.json else runtime.describe(state))
            return 0 if state["connected"] or state["status"] == "Paused" else 1
    except (OSError, ValueError, TypeError, subprocess.SubprocessError) as error:
        detail = error.stderr.strip() if isinstance(error, subprocess.CalledProcessError) and error.stderr else str(error)
        if args.json:
            print(json.dumps({"connected": False, "active": False, "status": "Gateway error", "detail": detail}))
        else:
            print(f"T3 Tailscale: {detail}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
