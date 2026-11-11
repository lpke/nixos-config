"""Private desktop runner. Never mounts the owner's HOME, session or GPU."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--artifacts', type=Path, required=True)
    parser.add_argument('--app-dir', type=Path, required=True)
    parser.add_argument('--fhs-root', type=Path)
    parser.add_argument('--python')
    parser.add_argument('--desktop', choices=('wayland', 'x11'), default='wayland')
    parser.add_argument('--package', help='Built t3-quake package, for packaging acceptance')
    parser.add_argument('--tiler', help='Built patched Krohnkite package')
    args = parser.parse_args()
    root = args.artifacts.resolve()
    if root.exists() and any(root.iterdir()):
        parser.error('Choose a new, empty artifacts directory')
    (root / 'home').mkdir(parents=True, exist_ok=True)
    repo = Path(__file__).resolve().parents[3]
    expression = '''let f = builtins.getFlake (builtins.getEnv "T3_QUAKE_TEST_FLAKE");
      p = f.nixosConfigurations.lpnix.pkgs;
    in { python = "${p.python3.withPackages (ps: [ ps.pyqt6 ])}/bin/python";
         mesa = toString p.mesa;
         qml = "${p.kdePackages.plasma5support}/lib/qt-6/qml";
         kwinX11 = "${p.kdePackages.kwin-x11}/bin/kwin_x11"; }'''
    deps = json.loads(subprocess.check_output(['nix', 'eval', '--impure', '--json', '--expr', expression],
        env=os.environ | {'T3_QUAKE_TEST_FLAKE': str(repo)}, text=True, timeout=60))
    deps.update(package=args.package, tiler=args.tiler, desktop=args.desktop)
    (root/'dependencies.json').write_text(json.dumps(deps))
    fhs_root = args.fhs_root
    if fhs_root is None:
        wrapper = Path(shutil.which('appimage-run')).read_text()
        fhs_root = Path(re.search(r'/nix/store/[a-z0-9]+-appimage-run-fhsenv-rootfs', wrapper)[0])
    cmd = ['bwrap', '--unshare-all', '--die-with-parent', '--new-session',
           '--ro-bind', '/nix', '/nix', '--ro-bind', '/etc', '/etc',
           '--ro-bind', '/run/current-system', '/run/current-system',
           '--proc', '/proc', '--dev', '/dev', '--tmpfs', '/tmp',
           '--bind', str(root), '/lab', '--bind', str(root / 'home'), '/home/luke',
           '--ro-bind', str(repo), '/src', '--ro-bind', str(args.app_dir.resolve()), '/app',
           '--chdir', '/lab']
    for entry in fhs_root.iterdir():
        if entry.name in ('etc', 'nix-support'):
            continue
        if entry.is_symlink():
            cmd += ['--symlink', os.readlink(entry), '/' + entry.name]
        else:
            cmd += ['--ro-bind', str(entry), '/' + entry.name]
    cmd += ['--clearenv', '--setenv', 'PATH', '/run/current-system/sw/bin:/usr/bin:/bin',
            '--setenv', 'LANG', 'C.UTF-8', args.python or deps['python'], '/src/pkgs/t3-quake/tests/lab.py']
    subprocess.run(cmd, check=True)


if __name__ == '__main__':
    main()
