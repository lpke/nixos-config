"""Source-driven preview checks; no physical or synthetic system input."""

import copy
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from synergy_keys.chords import from_mac, parse
from synergy_keys.inspector import trace
from synergy_keys.inspector_search import Catalog
from synergy_keys.inspector_sources import Sources

ROOT = Path(__file__).resolve().parents[2]
DOTFILES = Path.home() / ".local/share/chezmoi"


class ChordTests(unittest.TestCase):
    def test_aliases_separators_case_and_sides(self):
        for value in ["c-l", "CTRL+l", "Control L", "thumb + l"]:
            self.assertEqual(parse(value), parse("Ctrl+L"))
        for value in ["COMMAND-m", "cmd+m", "pinky m", "SUPER-M", "meta+m"]:
            self.assertEqual(parse(value), parse("Meta+M"))
        self.assertEqual(parse("CTRL + shift - c"), parse("C-SHIFT-c"))
        self.assertEqual(parse("Ctrl+Del"), parse("Control+Delete"))
        self.assertEqual(parse("SUPER_R-m"), parse("Right Meta+M"))
        self.assertNotEqual(parse("C-delete"), parse("C-backspace"))
        self.assertEqual(parse("ctrl++"), parse("ctrl+plus"))
        self.assertEqual(parse("ctrl+-"), parse("ctrl-minus"))
        for value in ["Ctrl+Plus", "Ctrl+Minus", "Right Ctrl+Right Shift+M"]:
            self.assertEqual(parse(parse(value).label()), parse(value))

    def test_invalid_and_partial_inputs_do_not_become_chords(self):
        for value in ["", "ctrl+", "turbo+l", "ctrl+ctrl+l", "ctrl+flibble"]:
            with self.assertRaises(ValueError):
                parse(value)


class InspectorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sources = Sources(ROOT, DOTFILES)
        cls.catalog = Catalog(cls.sources)

    def test_evaluated_rules_are_the_actual_xremap_rules_in_order(self):
        production = json.loads(subprocess.check_output(["nix", "eval", "--json", "--file", str(ROOT / "user/xremap/default.nix")]))["config"]
        for name in ["modmap", "keymap"]:
            self.assertEqual([{k: v for k, v in r.items() if k != "inspect_source"} for r in self.sources.data[name]], production[name])

    def test_every_protocol_chord_and_every_app_output(self):
        self.assertEqual(len(self.sources.data["protocol"]["bindings"]), 148)
        for binding in self.sources.data["protocol"]["bindings"]:
            with self.subTest(chord=binding["input"]):
                result = trace(self.sources, binding["input"])
                self.assertIn(binding["relay"], result.transport)
                self.assertEqual([o["output"] for o in result.outcomes],
                                 [from_mac(binding[branch]).label(mac=True) for branch in ["normal", "terminal"]])
                self.assertIn("missing/empty", result.outcomes[1]["when"])
                self.assertTrue(all(s["exists"] for s in result.sources))
                self.assertTrue(any(s["line"] for s in result.sources if "synergy-keymap.json" in s["path"]))

    def test_examples_that_must_not_be_conflated(self):
        cases = {"thumb+l": ["Cmd+L", "Ctrl+L"], "ctrl+w": ["Cmd+W", "Ctrl+W"],
                 "ctrl+backspace": ["Option+Backspace", "Ctrl+W"],
                 "ctrl+shift+c": ["Shift+Cmd+C", "Right Cmd+C"]}
        for value, expected in cases.items():
            self.assertEqual([o["output"] for o in trace(self.sources, value).outcomes], expected)
        self.assertIn("Close the focused window", trace(self.sources, "ctrl+delete").outcomes[0]["output"])
        self.assertIn("Resize window", trace(self.sources, "rightmeta+rightclick").outcomes[0]["output"])
        self.assertIn('"press": "SUPER_R"', trace(self.sources, "rightmeta+rightclick").transport)
        self.assertIn("Move window", trace(self.sources, "meta+leftclick").outcomes[0]["output"])

    def test_common_actions_and_device_filters(self):
        for chord, action in {"meta+m": "Alacritty", "meta+n": "Helium", "ctrl+h": "Focus window left",
                              "meta+l": "Focus window right", "meta+alt+v": "Grow window down",
                              "meta+alt+b": "Grow window right", "meta+wheelup": "Raise hovered",
                              "meta+wheeldown": "Lower hovered"}.items():
            self.assertIn(action, trace(self.sources, chord).outcomes[0]["output"])
        self.assertEqual(trace(self.sources, "meta+m", "Logitech G903").outcomes[0]["output"], "Cmd+M")
        self.assertIn("suppressed", trace(self.sources, "F20", "Logitech G903").transport)
        self.assertIn("Left Cmd+K", trace(self.sources, "BTN_FORWARD", "Logitech G903").outcomes[0]["output"])
        self.assertIn("PC action", trace(self.sources, "F18").transport)
        self.assertEqual(trace(self.sources, "ctrl+q").rule, "No PC remap")
        self.assertEqual(trace(self.sources, "ctrl+alt+l").outcomes[0]["output"], "Ctrl+Option+L")

    def test_fuzzy_search_aliases_and_exact_ranking(self):
        for query, first in {"thumb+l": "Ctrl+L", "COMMAND-m": "Meta+M", "pinky-m": "Meta+M",
                             "ctrl + shift - c": "Ctrl+Shift+C", "control l": "Ctrl+L", "ctrl+q": "Ctrl+Q"}.items():
            self.assertEqual(self.catalog.search(query)[0].input, first)
        self.assertEqual(len(self.catalog.search("thumb+l")), 1)
        self.assertEqual(len(self.catalog.search("grw windw")), 2)
        self.assertEqual(self.catalog.search("nothingmatcheshere"), [])
        self.assertTrue(self.catalog.search("ctrl+"))
        self.assertTrue(all("Meta" in r.input for r in self.catalog.search("command")))
        self.assertTrue(self.catalog.search("comm"))
        self.assertTrue(all("Meta" in r.input for r in self.catalog.search("comm")))

    def test_source_drift_uses_receiver_transport_not_input_name(self):
        data = copy.deepcopy(self.sources.data)
        bindings = data["protocol"]["bindings"]
        inputs = [b["input"] for b in bindings]
        index = inputs.index("C-l")
        replacement = bindings[inputs.index("C-w")]["relay"]
        bindings[index]["relay"] = replacement
        next(r for r in data["keymap"] if r["name"] == "Synergy Mac-local app shortcuts")["remap"]["C-l"] = replacement
        sources = Sources(ROOT, DOTFILES, data)
        result = trace(sources, "thumb+l")
        self.assertEqual(result.outcomes[0]["output"], "Cmd+W")
        self.assertIn("differ", " ".join(result.notes))

    def test_changed_app_classifier_is_reported_not_guessed(self):
        sources = Sources(ROOT, DOTFILES, self.sources.data)
        with patch.object(sources, "read", return_value="local terminal = anotherClassifier(bundle)"):
            result = trace(sources, "ctrl+l")
        self.assertIn("unrecognized", result.outcomes[0]["when"])
        self.assertIn("cannot be predicted", " ".join(result.notes))

    def test_missing_receiver_and_packaged_pc_fallback(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            snapshot = root / "snapshot.json"
            snapshot.write_text(json.dumps(self.sources.data))
            with patch.dict(os.environ, {"SYNERGY_KEYS_INSPECT_DATA": str(snapshot)}):
                sources = Sources(root / "no-nixos", root / "no-dotfiles")
            result = trace(sources, "ctrl+l")
            self.assertIn("snapshot", " ".join(result.notes))
            self.assertIn("Unknown", result.outcomes[0]["output"])

    def test_inspect_json_never_contacts_running_services(self):
        from synergy_keys.cli import main
        with patch("sys.argv", ["synergy-keys", "inspect", "thumb+l", "--json"]), \
             patch("synergy_keys.cli.synergy.processes", side_effect=AssertionError("must not inspect live processes")), \
             patch("synergy_keys.cli.request", side_effect=AssertionError("must not contact controller")), \
             patch("builtins.print") as output:
            self.assertEqual(main(), 0)
        self.assertEqual(json.loads(output.call_args.args[0])["input"], "Ctrl+L")


if __name__ == "__main__":
    unittest.main()
