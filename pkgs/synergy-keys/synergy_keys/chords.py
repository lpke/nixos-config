"""Shortcut notation shared by the inspector's text entry, capture and model."""

from dataclasses import dataclass
import re

MODIFIERS = {
    "c": "ctrl", "control": "ctrl", "ctrl": "ctrl", "thumb": "ctrl",
    "s": "shift", "shift": "shift", "alt": "alt", "option": "alt",
    "super": "meta", "meta": "meta", "cmd": "meta", "command": "meta", "pinky": "meta",
    "ctrl_l": "leftctrl", "ctrl_r": "rightctrl", "leftctrl": "leftctrl", "rightctrl": "rightctrl",
    "rightcommand": "rightmeta", "leftcommand": "leftmeta", "rightcmd": "rightmeta", "leftcmd": "leftmeta",
    "super_l": "leftmeta", "super_r": "rightmeta", "leftmeta": "leftmeta", "rightmeta": "rightmeta",
    "alt_l": "leftalt", "alt_r": "rightalt", "shift_l": "leftshift", "shift_r": "rightshift",
    "leftalt": "leftalt", "rightalt": "rightalt", "leftshift": "leftshift", "rightshift": "rightshift",
    "leftcontrol": "leftctrl", "rightcontrol": "rightctrl",
}
KEYS = {
    "del": "delete", "return": "enter", "esc": "escape", "pgup": "pageup", "pgdn": "pagedown",
    "forwarddelete": "delete", "ins": "insert",
    "spacebar": "space", "leftclick": "btn_left", "rightclick": "btn_right",
    "wheelup": "xupscroll", "wheeldown": "xdownscroll", "minus": "-", "plus": "+",
    "equal": "=", "grave": "`", "leftbrace": "[", "rightbrace": "]", "backslash": "\\",
    "semicolon": ";", "apostrophe": "'", "comma": ",", "dot": ".", "slash": "/",
}
SPECIAL = {"enter", "escape", "space", "tab", "backspace", "delete", "home", "end", "insert",
           "left", "right", "up", "down", "pageup", "pagedown", "pause", "print", "scrolllock", "capslock",
           "btn_left", "btn_right", "btn_middle", "btn_forward", "btn_extra", "btn_side", "btn_task",
           "xupscroll", "xdownscroll", "xhires_upscroll", "xhires_downscroll"}
ORDER = {"ctrl": 0, "alt": 1, "shift": 2, "meta": 3}


def generic(modifier):
    return modifier.removeprefix("left").removeprefix("right")


@dataclass(frozen=True)
class Chord:
    modifiers: frozenset[str]
    key: str

    def label(self, mac=False):
        def label(mod):
            base = generic(mod)
            name = {"ctrl": "Ctrl", "alt": "Option" if mac else "Alt", "shift": "Shift",
                    "meta": "Cmd" if mac else "Meta"}[base]
            return ("Right " if mod.startswith("right") else "Left " if mod.startswith("left") else "") + name
        mods = sorted(self.modifiers, key=lambda m: (ORDER[generic(m)], m))
        key = {"-": "Minus", "+": "Plus"}.get(self.key, self.key.upper() if len(self.key) == 1 else self.key.title())
        return "+".join([*(label(m) for m in mods), key])

    def matches(self, other, exact=True):
        remaining = set(other.modifiers)
        for mod in self.modifiers:
            candidate = next((m for m in remaining if m == mod or (mod == generic(mod) and generic(m) == mod)), None)
            if candidate is None:
                return False
            remaining.remove(candidate)
        return self.key == other.key and (not exact or not remaining)


def parse(text):
    text = text.strip().lower()
    if text in {"+", "-"}:
        text = "plus" if text == "+" else "minus"
    elif text.endswith("++"):
        text = text[:-1] + "plus"
    elif text.endswith(("+-", "--")):
        text = text[:-1] + "minus"
    text = re.sub(r"\b(left|right)\s+(ctrl|control|alt|shift|meta|cmd|command)\b", r"\1\2", text)
    # Nix uses dashes; user-facing entry also accepts Ctrl+L and thumb+l.
    parts = re.split(r"\s*[+-]\s*|\s+", text)
    if not parts or not parts[-1]:
        raise ValueError("Enter a key, for example thumb+l, Meta+m or Ctrl+Delete. Use 'plus' or 'minus' for those keys.")
    mods = []
    for part in parts[:-1]:
        if part not in MODIFIERS:
            raise ValueError(f"Unknown modifier: {part}")
        mods.append(MODIFIERS[part])
    if len({generic(m) for m in mods}) != len(mods):
        raise ValueError("Use each modifier once.")
    key = parts[-1].removeprefix("key_")
    key = KEYS.get(key, key)
    if not (len(key) == 1 or key in SPECIAL or re.fullmatch(r"f([1-9]|1[0-9]|2[0-4])", key)):
        raise ValueError(f"Unknown key: {key}")
    return Chord(frozenset(mods), key)


def from_mac(value):
    mods = {"cmd": "meta", "rightcmd": "rightmeta"}
    modifiers = {mods.get(m, m) for m in value["modifiers"]}
    # The receiver replaces generic Command with explicitly right Command.
    if "rightmeta" in modifiers:
        modifiers.discard("meta")
    key = {"delete": "backspace", "forwarddelete": "delete", "return": "enter"}.get(value["key"], value["key"])
    return Chord(frozenset(modifiers), key)
