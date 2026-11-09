"""Start the managed T3 connections/review listener, or quit them with the tray."""

import argparse
import subprocess
import sys


HELPERS = ('t3-ssh', 't3-tailscale', 'git-review-launcher')


def main():
    parser = argparse.ArgumentParser(description='Start T3 Controls and its services, or quit all of them.')
    parser.add_argument('action', nargs='?', choices=['show', 'quit'], default='show')
    args = parser.parse_args()
    failures = []
    for program in HELPERS:
        action = 'start' if args.action == 'show' else 'stop' if program == 'git-review-launcher' else 'quit'
        try:
            result = subprocess.run([program, action], timeout=120)
            if result.returncode:
                failures.append(f'{program}: exit {result.returncode}')
        except (OSError, subprocess.SubprocessError) as error:
            failures.append(f'{program}: {error}')
    # Do not kill our own service cgroup before the helpers finish. Keep the
    # controls available if a helper failed so the user can retry or inspect it.
    if args.action == 'show' or not failures:
        result = subprocess.run(['systemctl', '--user', *(['--no-block'] if args.action == 'quit' else []),
                                 'start' if args.action == 'show' else 'stop', 't3-tray.service'])
        if result.returncode:
            failures.append(f't3-tray.service: exit {result.returncode}')
    if failures:
        print('\n'.join(failures), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
