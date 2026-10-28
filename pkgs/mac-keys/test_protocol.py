"""Check the new protocol against the preserved pre-migration xremap behavior."""
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


def resolve(config, mode, modifiers, key):
    for block in config["keymap"]:
        if mode not in block["mode"]:
            continue
        for source, output in sorted(block["remap"].items(), key=lambda item: -len(chord(item[0])[0])):
            needed, source_key = chord(source)
            if source_key != key or not needed <= modifiers or block.get("exact_match") and needed != modifiers:
                continue
            if not isinstance(output, str):
                continue
            target, output_key = chord(output)
            if output_key == "f8" and target == {"ctrl", "alt", "shift", "rightcmd"}:
                return ({"ctrl"} if mode == "synergy-terminal" else {"cmd"}), "l"
            return target | (modifiers - needed), output_key
    return modifiers, key


@unittest.skipUnless(shutil.which("nix"), "Nix evaluation required")
class ProtocolTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        def evaluate(name):
            return json.loads(subprocess.check_output(["nix", "eval", "--json", "--file", str(ROOT / "user/xremap" / name)]))
        cls.old = evaluate("mac-legacy.nix")
        cls.new = evaluate("mac.nix")
        cls.manifest = json.loads((ROOT / "user/xremap/synergy-keymap.json").read_text())

    def test_all_context_dependent_modifier_combinations_match_legacy(self):
        expected = {}
        for key in [*"abcdefghijklmnopqrstuvwxyz", "left", "right", "up", "down", "backspace", "delete", "enter", "home", "end"]:
            target_key = KEYS.get(key, key)
            for bits in itertools.product([False, True], repeat=4):
                modifiers = {name for name, enabled in zip(["ctrl", "shift", "alt", "cmd"], bits) if enabled}
                if key not in {"home", "end"} and "ctrl" not in modifiers:
                    continue
                normal = resolve(self.old, "mac", modifiers, target_key)
                terminal = resolve(self.old, "synergy-terminal", modifiers, target_key)
                if normal != terminal:
                    expected[(frozenset(modifiers), target_key)] = normal, terminal
        actual = {}
        for binding in self.manifest["bindings"]:
            source = binding["source"]
            key = frozenset(source["modifiers"]), source["key"]
            self.assertNotIn(key, actual)
            actual[key] = tuple((set(binding[context]["modifiers"]), binding[context]["key"]) for context in ["normal", "terminal"])
        self.assertEqual(actual, expected)
        self.assertEqual(len(actual), 148)

    def test_common_shortcuts_and_gestures_are_unchanged(self):
        self.assertEqual(self.old["modmap"], self.new["modmap"])
        self.assertEqual(self.old["modeSwitchInternalKeymap"], self.new["modeSwitchInternalKeymap"])
        names = {"Synergy thumb+L pilot", "Synergy terminal shortcuts", "mac shortcuts"}
        self.assertEqual([block for block in self.old["keymap"] if block["name"] not in names], self.new["keymap"][1:-1])

    def test_transport_is_identical_in_all_remote_modes_and_collision_free(self):
        relays = self.new["keymap"][0]
        self.assertEqual(len(relays["mode"]), 6)
        self.assertTrue(relays["exact_match"])
        self.assertEqual(relays["remap"], {binding["input"]: binding["relay"] for binding in self.manifest["bindings"]})
        tokens = {(binding["transport"]["key"], frozenset(binding["transport"]["modifiers"])) for binding in self.manifest["bindings"]}
        self.assertEqual(len(tokens), 148)
        reserved = {"m", "n", "d", "escape", "h", "j", "k", "l", "y", *[f"f{i}" for i in range(9, 17)]}
        hyper = frozenset(["ctrl", "alt", "shift", "cmd"])
        self.assertFalse(tokens & {(key, hyper) for key in reserved})
        self.assertFalse(any(key in {"f17", "f18", "f19", "f20"} for key, _ in tokens))

    def test_dotfiles_protocol_mirror(self):
        canonical = Path.home() / ".local/share/chezmoi/dot_hammerspoon/synergy-keymap.json"
        if not canonical.exists():
            self.skipTest("Canonical dotfiles checkout unavailable")
        self.assertEqual(canonical.read_bytes(), (ROOT / "user/xremap/synergy-keymap.json").read_bytes())


if __name__ == "__main__":
    unittest.main()
