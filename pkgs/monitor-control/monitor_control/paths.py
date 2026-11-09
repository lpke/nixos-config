import os
from pathlib import Path


def runtime_directory():
    root = Path(os.environ["XDG_RUNTIME_DIR"]) / "monitor-control"
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    return root


def settings_file():
    return Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "monitor-control/settings.json"
