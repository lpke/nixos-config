"""Trace configured remote shortcuts. No input devices, SSH, or service controls."""

from dataclasses import asdict, dataclass, field
import json

from .chords import Chord, from_mac, generic, parse


@dataclass
class Trace:
    typed: str
    input: str
    device: str
    transport: str | None = None
    rule: str | None = None
    outcomes: list = field(default_factory=list)
    notes: list = field(default_factory=list)
    sources: list = field(default_factory=list)

    def json(self):
        return json.dumps(asdict(self), indent=2)


def applies(rule, mode, device):
    modes = rule.get("mode", [mode])
    if mode not in ([modes] if isinstance(modes, str) else modes):
        return False
    devices = rule.get("device", {})
    # The configured names are plain substring filters, not regexes.
    if "only" in devices and not any(name in device for name in devices["only"]):
        return False
    if any(name in device for name in devices.get("not", [])):
        return False
    return True


def trace(sources, text, device="Keyboard"):
    chord = parse(text)
    result = Trace(text, chord.label(), device, notes=list(sources.warnings))
    mode = "mac-super-right" if "rightmeta" in chord.modifiers else (
        "mac-super-left" if any(generic(m) == "meta" for m in chord.modifiers) else "mac")
    result.notes.append("Preview assumes Synergy is on the Mac and the keyboard uses its Linux layer. Thumb = Ctrl; pinky = Meta.")

    def ref(repo, path, needle, purpose):
        value = sources.reference(repo, path, needle, purpose)
        if value not in result.sources:
            result.sources.append(value)

    # Modmaps precede keymaps. Gestures and suppressed G903 buttons must not
    # masquerade as keymap passthrough. These are the only remote modmap forms.
    for rule in sources.data["modmap"]:
        if not applies(rule, mode, device):
            continue
        for key, target in rule["remap"].items():
            if key.startswith("SUPER_"):
                continue  # modifier state tracking, not a shortcut
            if parse(key).key != chord.key:
                continue
            result.rule = rule["name"]
            ref("nixos", rule["inspect_source"], rule["name"], "PC button handling")
            if isinstance(target, dict) and target.get("skip_key_event"):
                result.transport = "Press: " + json.dumps(target["press"]) + "\nRelease: " + json.dumps(target["release"])
                moving = chord.key == "btn_left"
                result.outcomes = [{"when": "All Mac apps", "output": "Move window with Cmd+Ctrl+left drag" if moving else
                                    "Resize window with Ctrl+right drag; restore held Command on release"}]
                result.notes.append("Move uses macOS window dragging; resize uses Easy Move+Resize. Extra held modifiers may affect the gesture.")
                result.notes.append("Mac settings: NSWindowShouldDragOnGesture enables native movement; configure resizing in Easy Move+Resize's menu.")
                ref("dotfiles", "dot_config/private_karabiner/private_karabiner.json", "", "Native Mac input rules, separate from Synergy")
                return result
            if target == []:
                result.transport = "None; button is suppressed on the PC"
                return result
            if isinstance(target, str) and parse(target).key == chord.key:
                continue
            if isinstance(target, dict) and target.get("held") == key:
                result.notes.append(f"PC delays this button by {target.get('alone_timeout_millis')} ms to suppress duplicate clicks.")
                continue
            result.transport = json.dumps(target)
            result.notes.append("This modmap needs manual inspection; its sequence is shown verbatim.")
            return result

    for rule in sources.data["keymap"]:
        if not applies(rule, mode, device):
            continue
        for key, target in rule["remap"].items():
            binding = parse(key)
            if not binding.matches(chord, rule.get("exact_match", False)):
                continue
            result.rule = rule["name"]
            ref("nixos", rule["inspect_source"], key if rule["inspect_source"] != "user/xremap/mac.nix" else "relay =", "PC remap")
            if rule.get("application") or rule.get("window"):
                result.notes.append("This rule also has a Linux app/window filter; inspect its source before assuming it applies.")
            if isinstance(target, dict):
                result.transport = "None; PC action: " + json.dumps(target)
                return result
            if isinstance(target, list):
                result.transport = "Sequence: " + json.dumps(target)
                # G903 Hyper sequences explicitly press and release modifiers.
                pressed = [step.get("press") for step in target if isinstance(step, dict) and "press" in step]
                if pressed[:4] == ["CTRL_L", "ALT_L", "SHIFT_L", "SUPER_L"] and len(pressed) == 5:
                    output = parse("C-ALT-SHIFT-SUPER_L-" + pressed[-1])
                else:
                    result.notes.append("Sequence shown verbatim; no single transported chord.")
                    return result
            else:
                output = parse(target)
                if not rule.get("exact_match", False):
                    remaining = {m for m in chord.modifiers if generic(m) not in {generic(b) for b in binding.modifiers}}
                    output = Chord(output.modifiers | remaining, output.key)
                result.transport = output.label() + "  [" + target + "]"
            if rule["inspect_source"] == "user/xremap/mac.nix":
                ref("nixos", "user/xremap/synergy-keymap.json", f'"input":"{key}"', "PC transport assignment; mirror the chezmoi manifest")
            decode(sources, result, output, ref)
            return result

    result.rule = result.rule or "No PC remap"
    result.transport = chord.label() + " (unchanged)"
    result.notes.append("No matching PC Synergy remap. Mac handlers may still recognize the unmodified shortcut.")
    ref("nixos", "user/xremap/mac-common.nix", "keymap =", "Common Mac mappings")
    ref("nixos", "user/xremap/synergy-keymap.json", "", "App-dependent mappings")
    decode(sources, result, chord, ref)
    return result


def decode(sources, result, chord, ref):
    # Synergy renames Linux Meta to macOS Command. It does not rewrite the token.
    result.notes.append("Synergy carries the same chord. Linux Meta becomes Mac Command; there is no second encoded value.")
    if chord.key in {"f17", "f18", "f19", "f20"}:
        result.notes.append("This Mac's Synergy client has dropped F17–F20 in prior tests. An unencoded key in that range may not arrive.")
    signature = lambda c: ({generic(m) for m in c.modifiers}, c.key)
    if sources.receiver is None:
        result.outcomes = [{"when": "Mac", "output": "Unknown; receiver source is unavailable"}]
        return
    for binding in sources.receiver["bindings"]:
        if signature(from_mac(binding["transport"])) != signature(chord):
            continue
        bundles = sources.app_policy()
        names = {"org.alacritty": "Alacritty", "com.googlecode.iterm2": "iTerm2"}
        if bundles is None:
            normal, terminal = "normal branch; app detection unrecognized", "terminal branch; app detection unrecognized"
            result.notes.append("Mac app detection changed or is unavailable. Read the receiver source; branch selection cannot be predicted.")
        else:
            terminal = ", ".join(names.get(b, b) + " [" + b + "]" for b in bundles) + "; also missing/empty app ID"
            normal = "All other identified apps"
        result.outcomes = [{"when": normal, "output": from_mac(binding["normal"]).label(mac=True)},
                           {"when": terminal, "output": from_mac(binding["terminal"]).label(mac=True)}]
        ref("dotfiles", "dot_hammerspoon/synergy-keymap.json", f'"input":"{binding["input"]}"', "Mac output chords; keep PC mirror in sync")
        ref("dotfiles", "dot_hammerspoon/synergy-keys.lua", "local terminal =", "Foreground app detection and native key events")
        ref("dotfiles", "dot_config/alacritty/alacritty.toml.tmpl", "[keyboard]", "Alacritty's further handling of the output chord")
        ref("dotfiles", "Library/Application Support/iTerm2/DynamicProfiles/terminal-profiles.json", "Keyboard Map", "iTerm2's further handling of the output chord")
        result.notes.append("Outputs are the key events Hammerspoon emits. Terminal bindings and shell programs may interpret them further.")
        if "rightcmd" in binding["terminal"]["modifiers"]:
            result.notes.append("Right Command is intentional: it bypasses iTerm2's left-Command remap.")
        return

    mods, key = signature(chord)
    hyper = mods == {"ctrl", "alt", "shift", "meta"}
    action, file, anchor = None, None, None
    if hyper and key in {"m", "n", "d", "escape"}:
        action = {"m": "Open a new Alacritty window", "n": "Open a new Helium window",
                  "d": "Toggle OLED blackout", "escape": "Turn off OLED blackout"}[key]
        file, anchor = "synergy-actions.lua", f"[hs.keycodes.map.{key}]"
    elif mods == {"meta"} and key == "delete":
        action, file, anchor = "Close the focused window", "synergy-actions.lua", "[hs.keycodes.map.forwarddelete]"
    elif hyper and key in {"pageup", "pagedown"}:
        action = "Command+wheel up for app zoom" if key == "pageup" else "Command+wheel down for app zoom"
        file, anchor = "synergy-actions.lua", "local zoomRelays ="
    elif hyper and key in {"f9", "f10", "f13", "f14", "f15", "f16"}:
        action = {"f9": "Grow window down", "f10": "Grow window right", "f13": "Focus window left",
                  "f14": "Focus window down", "f15": "Focus window up", "f16": "Focus window right"}[key]
        file, anchor = "window-shortcuts.lua", f'key = "{key}"'
    elif (hyper and key in {"f11", "f12"}) or (mods == {"ctrl"} and key in {"xupscroll", "xdownscroll"}):
        action = "Raise hovered window" if key in {"f11", "xupscroll"} else "Lower hovered window"
        file, anchor = "scroll-stack.lua", "local relays ="
    if file:
        source = sources.read("dot_hammerspoon/" + file)
        ref("dotfiles", "dot_hammerspoon/" + file, anchor, "Mac action handler")
        if anchor not in source:
            result.notes.append("Expected Mac action handler is unavailable or changed; confirm its implementation.")
            action = None
    result.outcomes = [{"when": "All Mac apps", "output": chord.label(mac=True) + (f" → {action}" if action else "") }]
    if hyper and key in {"h", "j", "k", "l"}:
        result.notes.append("macOS symbolic shortcuts handle this relay: H = desktop left, J = application windows, K = Mission Control, L = desktop right. Edit these on the Mac in System Settings → Keyboard → Keyboard Shortcuts → Mission Control; they are not managed in chezmoi.")
    if mods == {"meta"} and key == "space":
        result.notes.append("macOS handles Command+Space. Spotlight must use this shortcut in System Settings → Keyboard → Keyboard Shortcuts → Spotlight.")
    if mods == {"ctrl", "alt", "shift"} and key == "s":
        result.notes.append("macOS handles Ctrl+Option+Shift+S: select a screenshot area and copy it to the clipboard. This shortcut is configured in System Settings → Keyboard → Keyboard Shortcuts → Screenshots.")
