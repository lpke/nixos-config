"""Validate shortcut intent, transport safety, and the Nix/dotfiles contract."""
import itertools
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
ALIASES = {"C": "ctrl", "SHIFT": "shift", "S": "shift", "ALT": "alt", "SUPER": "cmd", "SUPER_R": "rightcmd"}
KEYS = {"enter": "return", "backspace": "delete", "delete": "forwarddelete"}


def chord(value):
    parts = value.split("-")
    return set(ALIASES[part] for part in parts[:-1]), KEYS.get(parts[-1].lower(), parts[-1].lower())


def intended(context, modifiers, key):
    # Global window close wins over app-specific editing on exact Ctrl+Delete.
    if modifiers == {"ctrl"} and key == "forwarddelete":
        return {"rightcmd"}, key
    if modifiers == {"ctrl"} and key == "l":
        return {"ctrl" if context == "terminal" else "cmd"}, key
    if context == "terminal":
        if {"ctrl", "shift"} <= modifiers and key in {"c", "v"}:
            return (modifiers - {"ctrl", "shift"}) | {"rightcmd"}, key
        if {"ctrl", "shift"} <= modifiers and key == "down":
            return modifiers | {"alt", "rightcmd"}, "y"
        if "ctrl" in modifiers and key == "delete" and "shift" not in modifiers:
            return modifiers, "w"
    else:
        if "ctrl" in modifiers:
            if key in set("acfrtvwxz") | {"return"}:
                return (modifiers - {"ctrl"}) | {"cmd"}, key
            if key in {"left", "right", "delete", "forwarddelete"}:
                return (modifiers - {"ctrl"}) | {"alt"}, key
        if key in {"home", "end"}:
            return modifiers | {"cmd"}, "left" if key == "home" else "right"
    return modifiers, key


@unittest.skipUnless(shutil.which("nix"), "Nix evaluation required")
class ProtocolTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.config = json.loads(subprocess.check_output([
            "nix", "eval", "--json", "--file", str(ROOT / "user/xremap/mac.nix")]))
        cls.manifest = json.loads((ROOT / "user/xremap/synergy-keymap.json").read_text())

    def test_all_app_dependent_modifier_combinations_match_intent(self):
        expected = {}
        for key in [*"abcdefghijklmnopqrstuvwxyz", "left", "right", "up", "down", "delete", "forwarddelete", "return", "home", "end"]:
            for bits in itertools.product([False, True], repeat=4):
                modifiers = {name for name, enabled in zip(["ctrl", "shift", "alt", "cmd"], bits) if enabled}
                if key not in {"home", "end"} and "ctrl" not in modifiers:
                    continue
                normal = intended("normal", modifiers, key)
                terminal = intended("terminal", modifiers, key)
                if normal != terminal:
                    expected[(frozenset(modifiers), key)] = normal, terminal
        actual = {}
        for binding in self.manifest["bindings"]:
            source = binding["source"]
            key = frozenset(source["modifiers"]), source["key"]
            self.assertNotIn(key, actual)
            actual[key] = tuple((set(binding[c]["modifiers"]), binding[c]["key"]) for c in ["normal", "terminal"])
        self.assertEqual(actual, expected)
        self.assertEqual(len(actual), 148)

    def test_transport_is_identical_in_all_remote_modes_and_collision_free(self):
        relays = self.config["keymap"][0]
        self.assertEqual(set(relays["mode"]), {"mac", "mac-super-left", "mac-super-right"})
        self.assertTrue(relays["exact_match"])
        self.assertEqual(relays["remap"], {b["input"]: b["relay"] for b in self.manifest["bindings"]})
        tokens = {(b["transport"]["key"], frozenset(b["transport"]["modifiers"])) for b in self.manifest["bindings"]}
        self.assertEqual(len(tokens), 148)
        reserved = {"m", "n", "d", "escape", "h", "j", "k", "l", "y", *[f"f{i}" for i in range(9, 17)]}
        hyper = frozenset(["ctrl", "alt", "shift", "cmd"])
        self.assertFalse(tokens & {(key, hyper) for key in reserved})
        for key, mods in tokens:
            self.assertNotIn(key, {"f17", "f18", "f19", "f20"})
            self.assertFalse(key in {f"f{i}" for i in range(1, 13)} and {"ctrl", "alt"} <= mods and "shift" not in mods,
                             "Ctrl+Alt+Fn switches Linux virtual consoles, even with Meta")
            self.assertFalse(key in {"left", "right", "up", "down"} and mods == {"ctrl", "shift", "cmd"},
                             "KDE moves windows between desktops with this chord")

    def test_common_actions_and_mode_keys_remain_available(self):
        blocks = {b["name"]: b for b in self.config["keymap"]}
        self.assertEqual(blocks["Synergy Mac actions"]["remap"], {
            "SUPER-m": "C-ALT-SHIFT-SUPER_R-m", "SUPER-n": "C-ALT-SHIFT-SUPER_R-n", "C-delete": "SUPER_R-delete"})
        self.assertEqual(blocks["Synergy app-independent shortcuts"]["remap"], {"SUPER-space": "C-space"})
        internal = self.config["modeSwitchInternalKeymap"]
        self.assertEqual(internal[1]["remap"], {"KEY_F22": {"set_mode": "local"}, "KEY_F24": {"set_mode": "mac"}})
        self.assertTrue(all(b["device"]["only"] == ["ydotoold virtual device"] for b in internal))

    def test_dotfiles_protocol_mirror(self):
        canonical = Path.home() / ".local/share/chezmoi/dot_hammerspoon/synergy-keymap.json"
        if not canonical.exists():
            self.skipTest("Canonical dotfiles checkout unavailable")
        self.assertEqual(canonical.read_bytes(), (ROOT / "user/xremap/synergy-keymap.json").read_bytes())


if __name__ == "__main__":
    unittest.main()
