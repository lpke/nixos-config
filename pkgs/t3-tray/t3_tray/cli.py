"""Show or hide the combined tray without changing its transport services."""

import argparse
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description="Show or hide the T3 connection tray.")
    parser.add_argument("action", nargs="?", choices=["show", "quit"], default="show")
    args = parser.parse_args()
    return subprocess.run(["systemctl", "--user", "start" if args.action == "show" else "stop",
                           "t3-tray.service"]).returncode


if __name__ == "__main__":
    sys.exit(main())
