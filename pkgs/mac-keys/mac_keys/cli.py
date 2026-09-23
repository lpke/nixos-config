import argparse
import asyncio
import os
import subprocess
import sys
import time

from . import modes, synergy
from .runtime import CONTROLLER_UNIT, SSH_UNIT, TRAY_UNIT, configuration, describe, request


RECOVERY = '''
SSH is attempted once when Synergy starts. After failure or disconnection,
enable SSH on the Mac, then run mac-keys retry. There are no automatic retries.
Stopping detection keeps SSH cached and preserves Ctrl while on the Mac.
Quitting Synergy stops detection and restores PC mappings.

If SSH fails, run these commands in Terminal on the Mac:
  1. Check the LAN IP: ifconfig | grep "inet "
     On the PC, compare it with: ssh -G {host} | grep '^hostname '
  2. Get temporary admin access if needed; enter your Mac password:
     /Applications/Privileges.app/Contents/MacOS/PrivilegesCLI --add --reason "Software Engineering"
  3. Enable SSH and allow your account:
     sudo systemsetup -setremotelogin on
     sudo dseditgroup -o edit -a "$(id -un)" -t user com.apple.access_ssh
Then retry on the PC: mac-keys retry
'''


def main():
    parser = argparse.ArgumentParser(
        prog="mac-keys",
        description="Control Mac app detection for Synergy.",
        epilog=RECOVERY.format(host=configuration()["host"]),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("command", nargs="?", default="status",
                        choices=["status", "start", "stop", "retry", "logs"],
                        help="start/retry: connect once; stop: pause detection; status/logs: inspect")
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
        os.execvp("journalctl", ["journalctl", "--user", "-u", CONTROLLER_UNIT,
                               "-u", SSH_UNIT, "-u", TRAY_UNIT, "-n", "60", "--no-pager"])
    if not synergy.processes()["running"]:
        print("Synergy is stopped. Start Synergy sharing first.")
        return 0 if args.command == "status" else 1
    try:
        if args.command in {"start", "retry"}:
            subprocess.run(["systemctl", "--user", "reset-failed", CONTROLLER_UNIT], check=True, timeout=10)
            subprocess.run(["systemctl", "--user", "start", CONTROLLER_UNIT], check=True, timeout=10)
            # Wait for the local command socket, without making an SSH attempt here.
            for _ in range(20):
                try:
                    request("status")
                    break
                except OSError:
                    time.sleep(0.1)
        response = request(args.command)
        print(describe(response) if args.command == "status" else response.get("message", response.get("error")))
        return 1 if args.command != "status" and response.get("error") else 0
    except (OSError, subprocess.SubprocessError) as error:
        print(f"Mac keys controller unavailable: {error}. Run mac-keys logs.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
