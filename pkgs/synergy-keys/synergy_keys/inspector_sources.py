"""Read source checkouts, without contacting a controller or changing mappings."""

import json
import os
from pathlib import Path
import re
import subprocess
from functools import lru_cache


class Sources:
    def __init__(self, nixos=None, dotfiles=None, data=None):
        self.nixos = Path(nixos or os.environ.get("SYNERGY_KEYS_NIXOS", Path.home() / ".config/nixos"))
        self.dotfiles = Path(dotfiles or os.environ.get("SYNERGY_KEYS_DOTFILES", Path.home() / ".local/share/chezmoi"))
        self.warnings = []
        self.origin = "Current NixOS and chezmoi source files"
        if data is None:
            expression = self.nixos / "pkgs/synergy-keys/inspector-data.nix"
            if expression.exists():
                result = subprocess.run(["nix", "eval", "--json", "--file", str(expression)],
                                        capture_output=True, text=True, timeout=20, check=True)
                data = json.loads(result.stdout)
            else:
                snapshot = os.environ.get("SYNERGY_KEYS_INSPECT_DATA")
                if not snapshot:
                    raise ValueError(f"Cannot find {expression}. Set SYNERGY_KEYS_NIXOS to the NixOS checkout.")
                data = json.loads(Path(snapshot).read_text())
                self.origin = "Packaged PC mappings and current chezmoi source files"
                self.warnings.append("NixOS checkout unavailable. PC rules come from this package's build snapshot.")
        self.data = data
        canonical = self.dotfiles / "dot_hammerspoon/synergy-keymap.json"
        self.receiver = None
        if canonical.exists():
            self.receiver = json.loads(canonical.read_text())
            if self.receiver != data["protocol"]:
                self.warnings.append("PC and chezmoi manifests differ. Results use the PC encoder and the chezmoi receiver separately.")
        else:
            self.warnings.append(f"Mac receiver manifest unavailable: {canonical}")
        if data["protocol"].get("version") != 1 or (self.receiver and self.receiver.get("version") != 1):
            raise ValueError("Unsupported Synergy protocol version.")

    @lru_cache(maxsize=32)
    def read(self, relative):
        try:
            return (self.dotfiles / relative).read_text()
        except OSError:
            return ""

    @lru_cache(maxsize=1024)
    def reference(self, repo, relative, needle="", purpose=""):
        path = (self.nixos if repo == "nixos" else self.dotfiles) / relative
        line = None
        try:
            line = next((i for i, text in enumerate(path.read_text().splitlines(), 1) if needle and needle in text), None)
        except OSError:
            pass
        return {"path": str(path), "line": line, "purpose": purpose, "exists": path.exists()}

    @lru_cache(maxsize=1)
    def app_policy(self):
        """Recognize the receiver's deliberately small expression, fail visibly on new logic.

        This is a config inspector, not a Lua interpreter. Never silently guess
        an app branch after the receiver's classifier changes.
        """
        source = self.read("dot_hammerspoon/synergy-keys.lua")
        match = re.search(r"local terminal = ([^\n]+)", source)
        if not match:
            return None
        parts = [s.strip() for s in match[1].split(" or ")]
        if parts[:2] != ["not bundle", 'bundle == ""']:
            return None
        bundles = []
        for part in parts[2:]:
            bundle = re.fullmatch(r'bundle == "([^"]+)"', part)
            if not bundle:
                return None
            bundles.append(bundle[1])
        if not all(s in source for s in ["hs.application.frontmostApplication()", "app and app:bundleID()",
                                        "terminal and binding.terminal or binding.normal"]):
            return None
        return bundles
