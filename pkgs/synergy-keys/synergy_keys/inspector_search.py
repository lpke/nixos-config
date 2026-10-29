"""Fuzzy discovery of remote mappings, with keyboard-role and modifier aliases."""

import re

from .chords import KEYS, MODIFIERS, generic, parse
from .inspector import applies, trace


def words(text):
    tokens = re.split(r"[^a-z0-9_]+", text.lower())
    return [generic(MODIFIERS[token]) if token in MODIFIERS else KEYS.get(token, token)
            for token in tokens if token]


def subsequence(needle, haystack):
    chars = iter(haystack)
    return all(any(c == letter for c in chars) for letter in needle)


class Catalog:
    def __init__(self, sources, device="Keyboard"):
        self.sources, self.device = sources, device
        inputs = set()
        for rule in sources.data["keymap"]:
            if any(applies(rule, mode, device) for mode in ["mac", "mac-super-left", "mac-super-right"]):
                inputs.update(rule["remap"])
        for rule in sources.data["modmap"]:
            if not any(applies(rule, mode, device) for mode in ["mac", "mac-super-left", "mac-super-right"]):
                continue
            for key, value in rule["remap"].items():
                if key.startswith("SUPER_"):
                    continue
                inputs.add(("SUPER-" if isinstance(value, dict) and value.get("skip_key_event") else "") + key)
        self.rows = [trace(sources, key, device) for key in sorted(inputs)]
        self.index = [words(" ".join([row.input, row.rule or "", *(o["output"] for o in row.outcomes)])) for row in self.rows]
        for row, tokens in zip(self.rows, self.index):
            modifiers = {generic(m) for m in parse(row.input).modifiers}
            tokens.extend(alias for alias, mod in MODIFIERS.items() if len(alias) > 1 and generic(mod) in modifiers)

    def search(self, query):
        query_words = words(query)
        parts = [p for p in re.split(r"[+\-\s]+", query.lower().strip()) if p]
        # A chord query searches input keys, not incidental letters in action
        # descriptions. 'thumb+l' must not match every rule containing 'local'.
        chord_query = len(parts) > 1 and all(p in MODIFIERS for p in parts[:-1])
        modifier_query = len(parts) == 1 and parts[0] in MODIFIERS and parts[0] not in {"c", "s"}
        key_query = len(parts) == 1 and len(parts[0]) == 1
        wanted_mods = {MODIFIERS[p] for p in (parts if modifier_query else parts[:-1])} if chord_query or modifier_query else set()
        wanted_key = KEYS.get(parts[-1].removeprefix("key_"), parts[-1].removeprefix("key_")) if parts else ""
        exact = None
        try:
            exact = parse(query)
        except ValueError:
            pass
        results = []
        for row, tokens in zip(self.rows, self.index):
            candidate = parse(row.input)
            if exact and candidate.matches(exact):
                score = -100
            elif chord_query or modifier_query or key_query:
                if any(not any(m == c or (m == generic(m) and m == generic(c)) for c in candidate.modifiers) for m in wanted_mods):
                    continue
                if not modifier_query and not (wanted_key == candidate.key or (len(wanted_key) > 1 and subsequence(wanted_key, candidate.key))):
                    continue
                score = len(candidate.modifiers) - len(wanted_mods)
            elif not query_words:
                score = 0
            elif all(any(word == token or subsequence(word, token) for token in tokens) for word in query_words):
                score = sum(0 if word in tokens else 10 for word in query_words) + len(words(row.input))
            elif subsequence("".join(query_words), "".join(words(row.input))):
                score = 50
            else:
                continue
            results.append((score, row.input, row))
        # Unmapped valid chords are inspectable too; never invent a nearby remap.
        if exact and not any(score == -100 for score, _, _ in results):
            row = trace(self.sources, query, self.device)
            results.append((-100, row.input, row))
        return [row for _, _, row in sorted(results, key=lambda r: (r[0], len(r[1]), r[1]))]
