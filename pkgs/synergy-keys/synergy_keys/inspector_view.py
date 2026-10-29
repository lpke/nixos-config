"""Palette-aware presentation of a shortcut trace using Qt's rich-text subset."""

from html import escape
from pathlib import Path

from PyQt6.QtCore import QEvent
from PyQt6.QtGui import QColor, QPalette, QTextOption
from PyQt6.QtWidgets import QFrame, QTextBrowser


def colors(palette):
    base = palette.color(QPalette.ColorRole.Base)
    text = palette.color(QPalette.ColorRole.Text)
    accent = palette.color(QPalette.ColorRole.Highlight)

    def blend(color, amount):
        return QColor(*(round(a * amount + b * (1 - amount)) for a, b in
                        zip(color.getRgb()[:3], base.getRgb()[:3]))).name()

    return {"text": text.name(), "muted": blend(text, .65), "line": blend(text, .18),
            "tint": blend(accent, .10), "link": palette.color(QPalette.ColorRole.Link).name()}


def source_label(source):
    path = Path(source["path"])
    for folder, label in [("nixos", "NixOS"), ("chezmoi", "Dotfiles")]:
        if folder in path.parts:
            relative = Path(*path.parts[path.parts.index(folder) + 1:])
            return f"{label} / {relative}" + (f":{source['line']}" if source["line"] else "")
    return str(path) + (f":{source['line']}" if source["line"] else "")


def render(row, query, palette=None):
    theme = colors(palette or QPalette())
    style = f"""
        body {{ color: {theme['text']}; }}
        p {{ margin-top: 0px; margin-bottom: 6px; }}
        .muted {{ color: {theme['muted']}; }}
        .heading {{ font-size: 11pt; font-weight: 600; margin-bottom: 10px; }}
        .input {{ font-size: 21pt; font-weight: 600; margin-bottom: 6px; }}
        .rule {{ font-size: 12pt; }}
        .transport {{ font-family: monospace; font-size: 12pt; font-weight: 600; }}
        .output {{ font-size: 15pt; font-weight: 600; }}
        .section {{ padding-top: 16px; padding-bottom: 16px; border-bottom: 1px solid {theme['line']}; }}
        .band {{ padding: 12px; background-color: {theme['tint']}; }}
        .outcome {{ padding: 12px; border-top: 1px solid {theme['line']}; }}
        .source {{ padding-top: 8px; padding-bottom: 8px; }}
        a {{ color: {theme['link']}; text-decoration: none; }}
    """

    def paragraph(text, kind=""):
        return f'<p class="{kind}">' + escape(text).replace("\n", "<br>") + "</p>"

    def section(title, content, step=None):
        number = f'<span class="muted">{step:02d}&nbsp;&nbsp;</span>' if step else ""
        return f'<tr><td class="section"><p class="heading">{number}{escape(title)}</p>{content}</td></tr>'

    parts = [section("Input", paragraph(row.input, "input") +
                     paragraph(f"Entered: {query or row.typed} · {row.device}", "muted"), 1),
             section("PC rule", paragraph(row.rule or "None", "rule"), 2)]
    if row.transport:
        human, separator, encoded = row.transport.partition("  [")
        content = paragraph(human, "transport")
        if separator:
            content += paragraph("xremap: " + encoded.removesuffix("]"), "muted")
        parts.append(section("Transport", '<table width="100%" cellspacing="0" cellpadding="0"><tr>'
                             f'<td class="band">{content}</td></tr></table>', 3))
    if row.outcomes:
        outcomes = []
        for outcome in row.outcomes:
            chord, arrow, action = outcome["output"].partition(" → ")
            output = paragraph(action if arrow else chord, "output")
            if arrow:
                output += paragraph(chord, "muted")
            outcomes.append('<tr><td class="outcome" width="47%" valign="middle">' +
                            paragraph(outcome["when"]) + '</td><td class="outcome" valign="middle">' + output + '</td></tr>')
        parts.append(section("Mac outcomes", '<table width="100%" cellspacing="0" cellpadding="0">' +
                             "".join(outcomes) + '</table>', 4))
    if row.sources:
        links = []
        for source in row.sources:
            path = Path(source["path"])
            location = escape(source_label(source))
            link = (f'<a href="{escape(path.as_uri(), quote=True)}" title="{escape(str(path), quote=True)}">{location}</a>'
                    if source["exists"] else location + " (unavailable)")
            links.append('<tr><td class="source">' + paragraph(source["purpose"], "muted") + f'<p>{link}</p></td></tr>')
        parts.append(section("Edit locations", '<table width="100%" cellspacing="0" cellpadding="0">' +
                             "".join(links) + '</table>'))
    if row.notes:
        parts.append(section("Details", "".join(paragraph(note, "muted") for note in row.notes)))
    return f'<html><head><style>{style}</style></head><body><table width="100%" cellspacing="0" cellpadding="0">' + "".join(parts) + '</table></body></html>'


class TraceView(QTextBrowser):
    def __init__(self):
        super().__init__()
        self.current_trace = None
        self.setFrameShape(QFrame.Shape.NoFrame)
        self.document().setDocumentMargin(22)
        option = self.document().defaultTextOption()
        option.setWrapMode(QTextOption.WrapMode.WrapAtWordBoundaryOrAnywhere)
        self.document().setDefaultTextOption(option)

    def show_trace(self, row, query):
        self.current_trace = (row, query)
        self.setHtml(render(row, query, self.palette()))

    def clear(self):
        self.current_trace = None
        super().clear()

    def setPlainText(self, text):
        self.current_trace = None
        super().setPlainText(text)

    def changeEvent(self, event):
        super().changeEvent(event)
        if event.type() in {QEvent.Type.PaletteChange, QEvent.Type.ApplicationPaletteChange} and self.current_trace:
            scroll = self.verticalScrollBar().value()
            self.show_trace(*self.current_trace)
            self.verticalScrollBar().setValue(scroll)
