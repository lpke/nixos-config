"""Output selection and blackout semantics, independent of Qt and rendering."""

from dataclasses import dataclass
import json
import os
from pathlib import Path
import tempfile

ALL = "all"


@dataclass(frozen=True)
class Output:
    name: str
    title: str
    active: bool = True


class State:
    def __init__(self, settings: Path):
        self.settings = settings
        self.outputs = {}
        self.blacked = set()
        self.target = ALL
        try:
            saved = json.loads(settings.read_text())
            if isinstance(saved.get("hotkey_monitor"), str):
                self.target = saved["hotkey_monitor"]
        except (OSError, ValueError, AttributeError):
            pass

    @property
    def eligible(self):
        return {key for key, output in self.outputs.items() if output.active}

    @property
    def all_black(self):
        return bool(self.eligible) and self.eligible <= self.blacked

    def refresh(self, outputs):
        self.outputs = {output.name: output for output in outputs}
        self.blacked.intersection_update(self.eligible)

    def toggle(self, target):
        if target == ALL:
            if self.all_black:
                self.blacked.clear()
            else:
                self.blacked.update(self.eligible)
        elif target in self.eligible:
            self.blacked.symmetric_difference_update({target})
        else:
            raise ValueError(f"Monitor unavailable: {target}")

    def select(self, target):
        if target != ALL and target not in self.outputs:
            raise ValueError(f"Monitor unavailable: {target}")
        self.settings.parent.mkdir(parents=True, exist_ok=True)
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(mode="w", dir=self.settings.parent,
                                             delete=False) as stream:
                temporary = Path(stream.name)
                json.dump({"hotkey_monitor": target}, stream)
                stream.write("\n")
                stream.flush()
                os.fsync(stream.fileno())
            temporary.replace(self.settings)
            self.target = target
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)

    def snapshot(self):
        return {
            "hotkey_monitor": self.target,
            "all_black": self.all_black,
            "blacked_out": sorted(self.blacked),
            "outputs": [vars(output) for output in self.outputs.values()],
        }
