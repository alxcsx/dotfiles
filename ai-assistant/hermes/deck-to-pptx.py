#!/usr/bin/env python3
"""deck-to-pptx — turn a deck-check HTML deck into an editable PPTX.

Why: the HTML deck is the source of truth, but people edit decks in Slides or
PowerPoint. This maps each <section class="slide"> to one 16:9 slide at the same
coordinates and the same type scale, so the editable copy is the same design.

EXTENSIBILITY — the contract is the CSS, not this file.
The deck's `:root` block is the theme: palette, type scale, measures, grid.
This converter reads those custom properties and bakes them into shapes. A new
template (maximalist, brutalist, whatever) needs no Python change as long as it
keeps the token names — see `--tokens` to print what was resolved. Anything the
converter does not recognise is reported as an unknown block instead of being
silently dropped, so a new layout fails loudly rather than exporting blank.

Tokens (unitless = multiple of --u, `px` suffix = fixed size):
  colours  --bg --ink --muted --rule --wash
  families --font-sans --font-mono
  type     --fs-title --fs-h2 --fs-h2-big --fs-h3 --fs-body --fs-sub --fs-big
           --fs-mono --fs-caption --fs-small --fs-foot --fs-table
  measures --measure --measure-list --measure-pre --measure-table
           --measure-title --measure-divider --measure-sub --measure-big
  grid     --pad-t --pad-x --pad-b --gap --gap-tight --li-gap --li-indent
           --pre-pad-y --pre-pad-x --table-pad-y

What carries over: layout grid, type scale, palette, hairlines, letter-spacing,
uppercase eyebrows, tables, inference rules, code blocks, header/footer.
What cannot: CSS itself (PPTX has no stylesheet) and the *file format* of the
font. This box renders "Adwaita Sans", which is Rasmus Andersson's Inter renamed
by GNOME (fontconfig foundry: RSMS) — so the export names Inter, same metrics,
and it is a Google Font, which is what Google Slides can actually display.

Heights are measured in Chromium, not estimated: one text box per block, height =
what the browser says that block occupies at that width. Without it, a one-line
error in one block shifts everything below it.

Usage:
  deck-to-pptx DECK.html [-o OUT.pptx] [--font Inter] [--mono "JetBrains Mono"]
                          [--verify] [--tokens]

Needs: python-pptx in ~/.local/share/deck-check/venv (same venv as deck-check).
      playwright optional; without it heights are estimated and drift.
      python-pptx 1.0.2, playwright chromium.
"""
from __future__ import annotations

import argparse
import html as htmllib
import os
import re
import sys
from dataclasses import dataclass, field
from html.parser import HTMLParser
from pathlib import Path

VENV_PY = os.path.expanduser("~/.local/share/deck-check/venv/bin/python3")
PX = 6350  # EMU per px: 1920 px == 13.333 in == 12192000 EMU


def _reexec_into_venv() -> None:
    try:
        import pptx  # noqa: F401
        return
    except ImportError:
        pass
    if os.path.exists(VENV_PY) and Path(sys.executable).resolve() != Path(VENV_PY).resolve():
        os.execv(VENV_PY, [VENV_PY, *sys.argv])
    sys.exit("deck-to-pptx: python-pptx not available.\n"
             f"  {VENV_PY} -m pip install python-pptx")


# ── HTML tree (stdlib) ──────────────────────────────────────────────────────

VOID = {"br", "img", "hr", "meta", "link", "input"}


class Node:
    __slots__ = ("tag", "attrs", "children")

    def __init__(self, tag: str, attrs: dict[str, str]):
        self.tag = tag
        self.attrs = attrs
        self.children: list[Node | str] = []

    @property
    def cls(self) -> set[str]:
        return set((self.attrs.get("class") or "").split())

    def find_all(self, tag: str, cls: str | None = None) -> list[Node]:
        out: list[Node] = []
        for c in self.children:
            if isinstance(c, Node):
                if c.tag == tag and (cls is None or cls in c.cls):
                    out.append(c)
                out.extend(c.find_all(tag, cls))
        return out

    def text(self) -> str:
        return "".join(c if isinstance(c, str) else c.text() for c in self.children)


class Tree(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.root = Node("#root", {})
        self.stack = [self.root]

    def handle_starttag(self, tag, attrs):
        n = Node(tag, dict(attrs))
        self.stack[-1].children.append(n)
        if tag not in VOID:
            self.stack.append(n)

    def handle_startendtag(self, tag, attrs):
        self.stack[-1].children.append(Node(tag, dict(attrs)))

    def handle_endtag(self, tag):
        for i in range(len(self.stack) - 1, 0, -1):
            if self.stack[i].tag == tag:
                del self.stack[i:]
                return

    def handle_data(self, data):
        self.stack[-1].children.append(data)


def parse(path: Path) -> Node:
    t = Tree()
    t.feed(path.read_text(encoding="utf-8"))
    return t.root


# ── inline runs ─────────────────────────────────────────────────────────────

INLINE = {"b": "b", "strong": "b", "i": "i", "em": "i", "code": "code",
          "sub": "sub", "sup": "sup", "a": None, "span": None, "br": "br"}


def runs(node: Node, style: frozenset = frozenset()) -> list[tuple[str, frozenset]]:
    out: list[tuple[str, frozenset]] = []
    for c in node.children:
        if isinstance(c, str):
            if c:
                out.append((c, style))
            continue
        if c.tag not in INLINE:
            out.extend(runs(c, style))
            continue
        flag = "muted" if (c.tag == "span" and "m" in c.cls) else INLINE[c.tag]
        if flag == "br":
            out.append(("\n", style))
            continue
        st = style | ({flag} if flag else set())
        out.extend(runs(c, frozenset(st)))
    return out


def inner_html(node: Node) -> str:
    parts = []
    for c in node.children:
        if isinstance(c, str):
            parts.append(htmllib.escape(c, quote=False))
        elif c.tag in INLINE:
            attrs = f' class="{c.attrs["class"]}"' if c.attrs.get("class") else ""
            parts.append(f"<{c.tag}{attrs}>{inner_html(c)}</{c.tag}>")
        else:
            parts.append(inner_html(c))
    return "".join(parts)


# ── theme tokens ────────────────────────────────────────────────────────────

# Defaults = the editorial template. A deck that defines no tokens still converts.
TOKEN_DEFAULTS = {
    "fs-title": 6.2, "fs-h2": 3.15, "fs-h2-big": 4.4, "fs-h3": 1.6,
    "fs-body": 1.45, "fs-sub": 1.7, "fs-big": 1.95, "fs-mono": 1.1,
    "fs-caption": .95, "fs-small": 1.05, "fs-foot": .9, "fs-table": 1.22,
    "measure": 50, "measure-list": 52, "measure-pre": 74, "measure-table": 72,
    "measure-title": 54, "measure-divider": 40, "measure-sub": 34, "measure-big": 46,
    "pad-t": 5.4, "pad-x": 6.3, "pad-b": 4.1,
    "gap": 1.5, "gap-tight": 1.1, "li-gap": .95, "li-indent": 1.6,
    "pre-pad-y": 1.4, "pre-pad-x": 1.7, "table-pad-y": .7, "accent-w": 0,
}

COLOUR_DEFAULTS = {"bg": "F7F7F5", "ink": "111111", "muted": "6B6B6B",
                   "rule": "D9D9D4", "wash": "ECECEA", "accent": "C2410C"}

# A font has to exist on the machine that OPENS the file. This box has Adwaita
# Sans (Inter, renamed by GNOME — foundry RSMS) and JetBrains Mono; Google Slides
# has Inter and JetBrains Mono. Map the private name to the public one.
GOOGLE_FONTS = {
    "adwaita sans": "Inter", "adwaita mono": "JetBrains Mono",
    "dejavu sans": "Inter", "dejavu sans mono": "JetBrains Mono",
    "noto sans": "Noto Sans", "liberation sans": "Arial", "helvetica": "Arial",
    "helvetica neue": "Arial", "arial": "Arial", "inter": "Inter",
    "jetbrains mono": "JetBrains Mono", "sf pro": "Inter",
}


@dataclass
class Theme:
    w: float = 1920.0
    h: float = 1080.0
    tok: dict[str, float] = field(default_factory=dict)
    col: dict[str, str] = field(default_factory=dict)
    css_sans: str = ""
    css_mono: str = ""

    @property
    def u(self) -> float:
        return self.w / 100.0

    def px(self, name: str) -> float:
        return self.tok.get(name, TOKEN_DEFAULTS[name] * self.u)


def _stack_first(value: str) -> str:
    first = value.split(",")[0].strip().strip('"\'')
    return first


def theme_from(src: str) -> Theme:
    t = Theme()
    m = re.search(r"@page\s*\{[^}]*?size\s*:\s*(\d+)px\s+(\d+)px", src)
    if m:
        t.w, t.h = float(m.group(1)), float(m.group(2))
    u = t.w / 100.0

    for name, default in COLOUR_DEFAULTS.items():
        mm = re.search(rf"--{name}\s*:\s*#([0-9a-fA-F]{{6}})", src)
        t.col[name] = (mm.group(1) if mm else default).upper()

    for name, default in TOKEN_DEFAULTS.items():
        mm = re.search(rf"--{name}\s*:\s*([0-9.]+)\s*(px)?", src)
        if not mm:
            t.tok[name] = default * u
        else:
            val = float(mm.group(1))
            t.tok[name] = val if mm.group(2) else val * u

    mm = re.search(r"--font-sans\s*:\s*([^;]+);", src)
    t.css_sans = _stack_first(mm.group(1)) if mm else ""
    mm = re.search(r"--font-mono\s*:\s*([^;]+);", src)
    t.css_mono = _stack_first(mm.group(1)) if mm else ""
    return t


def google_font(name: str, fallback: str) -> str:
    if not name:
        return fallback
    return GOOGLE_FONTS.get(name.lower(), name)


def emu(px: float) -> int:
    return int(round(px * PX))


def pt(px: float) -> float:
    """1920 px over 13.333 in => 1 pt == 2 px."""
    return px / 2.0


# ── browser measurement ─────────────────────────────────────────────────────

class Measurer:
    """Line-box heights for a block at a given width, in Chromium."""

    def __init__(self, sans: str, mono: str):
        self.ok = False
        try:
            from playwright.sync_api import sync_playwright
        except Exception:
            return
        self._pw = sync_playwright().start()
        self._browser = self._pw.chromium.launch()
        self._page = self._browser.new_page()
        self._page.set_content("<!doctype html><html><body style='margin:0'></body></html>")
        self.sans, self.mono = sans, mono

    def heights(self, items: list[dict]) -> list[float]:
        if not items:
            return []
        if not self.ok:
            return [self._estimate(it) for it in items]
        return self._page.evaluate("""(items) => items.map(it => {
            const d = document.createElement('div');
            d.style.cssText = 'position:absolute;left:-99999px;top:0;'
              + `width:${it.w}px;font-family:${it.font};font-size:${it.fs}px;`
              + `line-height:${it.lh};letter-spacing:${it.ls || 'normal'};`
              + 'white-space:normal;text-align:left;';
            d.innerHTML = it.html;
            d.querySelectorAll('code').forEach(c => {
              c.style.fontFamily = it.mono; c.style.fontSize = '0.9em';
              c.style.padding = '0.04em 0.2em';
            });
            document.body.appendChild(d);
            const h = d.getBoundingClientRect().height;
            d.remove();
            return h;
        })""", [dict(it, font=self.sans, mono=self.mono) for it in items])

    @staticmethod
    def _estimate(it: dict) -> float:
        chars = len(re.sub(r"<[^>]+>", "", it["html"]).replace("&nbsp;", " "))
        per_line = max(1.0, it["w"] / (it["fs"] * 0.52))
        return max(1, -(-chars // int(per_line))) * it["fs"] * float(it["lh"])

    def close(self) -> None:
        if self.ok:
            self._browser.close()
            self._pw.stop()


# ── blocks ──────────────────────────────────────────────────────────────────

@dataclass
class Block:
    kind: str
    node: Node | None = None
    font: float = 0.0
    lh: float = 1.5
    color: str = ""
    width: float = 0.0
    indent: float = 0.0
    height: float = 0.0
    ls: float = 0.0            # letter-spacing, em
    upper: bool = False
    extra: dict = field(default_factory=dict)


UNKNOWN_TAGS = {"div", "section", "figure", "img", "svg", "h4", "h5", "h6",
                "blockquote", "dl", "aside", "article"}
unknown: list[str] = []


def classify(node: Node, t: Theme) -> Block | None:
    cls = node.cls
    ink, muted = t.col["ink"], t.col["muted"]
    if node.tag == "h1":
        return Block("title", node, t.px("fs-title"), 1.02, ink,
                     t.px("measure-title"), ls=-.035)
    if node.tag == "h2":
        big = "divider" in cls
        return Block("title", node, t.px("fs-h2-big") if big else t.px("fs-h2"), 1.1,
                     ink, t.px("measure-divider") if big else t.px("measure"),
                     ls=-.025)
    if node.tag == "h3":
        return Block("title", node, t.px("fs-h3"), 1.2, ink, t.px("measure"))
    if node.tag == "p":
        if "sub" in cls:
            return Block("para", node, t.px("fs-sub"), 1.4, muted, t.px("measure-sub"))
        if "big" in cls:
            return Block("para", node, t.px("fs-big"), 1.4, muted, t.px("measure-big"))
        if "lede" in cls:
            return Block("para", node, t.px("fs-body"), 1.5, muted, t.px("measure"))
        return Block("para", node, t.px("fs-body"), 1.5, "1D1D1D", t.px("measure"))
    if node.tag in ("ul", "ol"):
        return Block("list", node, t.px("fs-body"), 1.5, ink, t.px("measure-list"),
                     t.px("li-indent"), extra={"ordered": node.tag == "ol"})
    if node.tag == "pre":
        return Block("pre", node, t.px("fs-mono"), 1.6, ink, t.px("measure-pre"))
    if node.tag == "table":
        return Block("table", node, t.px("fs-table"), 1.4, ink, t.px("measure-table"))
    if node.tag == "div":
        if "rules" in cls:
            return Block("rules", node, t.px("fs-small"), 1.5, ink, 0)
        if "meta" in cls:
            return Block("meta", node, t.px("fs-small"), 1.4, muted, 0)
    if node.tag in UNKNOWN_TAGS or cls:
        # Not a known block: keep the words, flag the gap. A new template must
        # teach the converter, not silently lose a section.
        unknown.append(f"<{node.tag}{' class=' + ' '.join(sorted(cls)) if cls else ''}>")
        return Block("para", node, t.px("fs-body"), 1.5, ink, t.px("measure"))
    return None


def slide_blocks(body: Node, t: Theme) -> list[Block]:
    out: list[Block] = []
    for child in body.children:
        if not isinstance(child, Node):
            continue
        b = classify(child, t)
        if b:
            out.append(b)
    return out


# ── pptx plumbing ───────────────────────────────────────────────────────────

def _pPr_setup(par, color: str, mar: int, hang: int, bullet: str | None) -> None:
    """Hanging indent + a real bullet char, so the list edits like a list."""
    from lxml import etree
    from pptx.oxml.ns import qn
    pPr = par._p.get_or_add_pPr()
    pPr.set("marL", str(mar))
    pPr.set("indent", str(hang))
    for tag in ("a:buClr", "a:buFont", "a:buChar", "a:buAutoNum", "a:buNone"):
        el = pPr.find(qn(tag))
        if el is not None:
            pPr.remove(el)
    clr = etree.SubElement(pPr, qn("a:buClr"))
    etree.SubElement(clr, qn("a:srgbClr")).set("val", color)
    etree.SubElement(pPr, qn("a:buFont")).set("typeface", "Arial")
    if bullet is None:
        etree.SubElement(pPr, qn("a:buAutoNum")).set("type", "arabicPeriod")
    else:
        etree.SubElement(pPr, qn("a:buChar")).set("char", bullet)


def _cell_hairline(cell, color: str) -> None:
    from lxml import etree
    from pptx.oxml.ns import qn
    tcPr = cell._tc.get_or_add_tcPr()
    ln = etree.Element(qn("a:lnB"))
    ln.set("w", "9525")  # 0.75 pt
    etree.SubElement(etree.SubElement(ln, qn("a:solidFill")), qn("a:srgbClr")).set("val", color)
    tcPr.insert(0, ln)


def pre_lines(node: Node) -> list[list[tuple[str, frozenset]]]:
    flat = runs(node)
    lines: list[list[tuple[str, frozenset]]] = [[]]
    for text, flags in flat:
        parts = text.split("\n")
        for i, part in enumerate(parts):
            if i:
                lines.append([])
            if part:
                lines[-1].append((part, flags))
    return lines


class Renderer:
    def __init__(self, prs, t: Theme, m: Measurer, font: str, mono: str):
        self.prs, self.t, self.m = prs, t, m
        self.font, self.mono = font, mono

    # -- primitives ---------------------------------------------------------
    def textbox(self, slide, x, y, w, h, align="l", anchor="t"):
        from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
        from pptx.util import Emu
        box = slide.shapes.add_textbox(Emu(emu(x)), Emu(emu(y)),
                                       Emu(emu(max(w, 8))), Emu(emu(max(h, 8))))
        tf = box.text_frame
        tf.word_wrap = True
        tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
        tf.vertical_anchor = MSO_ANCHOR.TOP if anchor == "t" else MSO_ANCHOR.MIDDLE
        tf.paragraphs[0].alignment = {"l": PP_ALIGN.LEFT, "r": PP_ALIGN.RIGHT,
                                      "c": PP_ALIGN.CENTER}[align]
        return box

    def rect(self, slide, x, y, w, h, color: str):
        from pptx.dml.color import RGBColor
        from pptx.enum.shapes import MSO_SHAPE
        from pptx.util import Emu
        sh = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, Emu(emu(x)), Emu(emu(y)),
                                    Emu(emu(w)), Emu(emu(h)))
        sh.fill.solid()
        sh.fill.fore_color.rgb = RGBColor.from_string(color)
        sh.line.fill.background()
        sh.shadow.inherit = False
        return sh

    def fill_runs(self, par, node: Node, fs: float, color: str,
                  ls: float = 0.0, upper: bool = False) -> None:
        from pptx.dml.color import RGBColor
        from pptx.util import Pt
        tf = par._parent
        for text, flags in runs(node):
            for i, chunk in enumerate(text.split("\n")):
                if i:
                    par = tf.add_paragraph()
                if not chunk:
                    continue
                r = par.add_run()
                r.text = chunk.upper() if upper else chunk
                f = r.font
                f.size = Pt(pt(fs * (0.9 if "code" in flags else 1.0)))
                f.bold = "b" in flags
                f.italic = "i" in flags
                f.name = self.mono if "code" in flags else self.font
                f.color.rgb = RGBColor.from_string(
                    self.t.col["muted"] if "muted" in flags else color)
                rPr = r._r.get_or_add_rPr()
                if ls:
                    rPr.set("spc", str(int(round(ls * fs / 2.0 * 100))))
                if "sub" in flags:
                    rPr.set("baseline", "-25000")
                elif "sup" in flags:
                    rPr.set("baseline", "30000")

    # -- blocks -------------------------------------------------------------
    def draw_text(self, slide, b: Block, x, y):
        box = self.textbox(slide, x, y, min(b.width, self.t.w - 2 * x) or 100, b.height)
        par = box.text_frame.paragraphs[0]
        par.line_spacing = b.lh
        self.fill_runs(par, b.node, b.font, b.color, b.ls, b.upper)
        return b.height

    def draw_list(self, slide, b: Block, x, y):
        from pptx.util import Pt
        box = self.textbox(slide, x, y, b.width, b.height)
        tf = box.text_frame
        items = [li for li in b.node.children if isinstance(li, Node) and li.tag == "li"]
        mar, hang = int(round(b.indent / 2.0 * 12700)), -int(round(b.indent / 2.0 * 12700))
        for i, li in enumerate(items):
            par = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
            par.line_spacing = b.lh
            par.space_after = Pt(pt(self.t.px("li-gap")))
            _pPr_setup(par, self.t.col["ink"], mar, hang,
                       None if b.extra.get("ordered") else "\u2013")
            self.fill_runs(par, li, b.font, b.color)
        return b.height

    def draw_pre(self, slide, b: Block, x, y):
        from pptx.dml.color import RGBColor
        from pptx.util import Pt
        padx, pady = self.t.px("pre-pad-x"), self.t.px("pre-pad-y")
        self.rect(slide, x, y, b.width, b.height, self.t.col["wash"])
        self.rect(slide, x, y, 2, b.height, self.t.col["ink"])
        box = self.textbox(slide, x + padx, y + pady, b.width - 2 * padx,
                           b.height - 2 * pady)
        tf = box.text_frame
        for i, line in enumerate(pre_lines(b.node)):
            par = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
            par.line_spacing = b.lh
            par.space_after = Pt(0)
            if not line:
                line = [("\u00a0", frozenset())]
            for text, flags in line:
                r = par.add_run()
                r.text = text
                r.font.size = Pt(pt(b.font))
                r.font.name = self.mono
                r.font.color.rgb = RGBColor.from_string(
                    self.t.col["muted"] if "muted" in flags else self.t.col["ink"])
        return b.height

    def draw_table(self, slide, b: Block, x, y):
        from pptx.enum.text import MSO_ANCHOR
        from pptx.util import Emu
        rows = b.node.find_all("tr")
        cells = [[td for td in tr.children if isinstance(td, Node)
                  and td.tag in ("td", "th")] for tr in rows]
        if not cells:
            return 0
        ncol = max(len(r) for r in cells)
        widths = b.extra["col_w"]
        gf = slide.shapes.add_table(len(rows), ncol, Emu(emu(x)), Emu(emu(y)),
                                    Emu(emu(b.width)), Emu(emu(b.height)))
        tbl = gf.table
        tbl.first_row = False
        tbl.horz_banding = False
        tbl.vert_banding = False
        for i, w in enumerate(widths):
            tbl.columns[i].width = Emu(emu(w))
        for r, row in enumerate(cells):
            tbl.rows[r].height = Emu(emu(b.extra["row_h"][r]))
            for c in range(ncol):
                cell = tbl.cell(r, c)
                cell.fill.background()
                cell.margin_left = Emu(0)
                cell.margin_right = Emu(emu(1.4 * self.t.u))
                cell.margin_top = Emu(emu(self.t.px("table-pad-y")))
                cell.margin_bottom = Emu(emu(self.t.px("table-pad-y")))
                cell.vertical_anchor = MSO_ANCHOR.MIDDLE
                _cell_hairline(cell, self.t.col["rule"])
                if c >= len(row):
                    continue
                src = row[c]
                head = src.tag == "th"
                self.fill_runs(cell.text_frame.paragraphs[0], src,
                               self.t.px("fs-caption") if head else b.font,
                               self.t.col["muted"] if head else self.t.col["ink"],
                               .12 if head else 0.0, upper=head)
        return b.height

    def draw_rules(self, slide, b: Block, x, y):
        gap = 3 * self.t.u
        cur = x
        rules = [r for r in b.node.children if isinstance(r, Node) and r.tag == "div"]
        for rule in rules:
            num = next((d for d in rule.children if isinstance(d, Node) and "num" in d.cls), None)
            den = next((d for d in rule.children if isinstance(d, Node) and "den" in d.cls), None)
            nm = next((d for d in rule.children if isinstance(d, Node) and "nm" in d.cls), None)
            w = b.extra["widths"][id(rule)]
            yy = y + b.extra["pad"]
            for part, size, col in ((num, b.font, self.t.col["ink"]),
                                    (den, b.font, self.t.col["ink"]),
                                    (nm, b.font * 0.78, self.t.col["muted"])):
                if part is None:
                    continue
                if part is nm:
                    yy += self.t.px("li-gap") - 0.05 * self.t.u
                box = self.textbox(slide, cur, yy, w, size * 1.5, align="c")
                box.text_frame.paragraphs[0].line_spacing = b.lh
                self.fill_runs(box.text_frame.paragraphs[0], part, size, col,
                               .12 if part is nm else 0.0, upper=part is nm)
                yy += size * 1.5
                if part is num:
                    self.rect(slide, cur, yy, w, 1, self.t.col["ink"])
                    yy += 0.45 * self.t.u
            cur += w + gap
        return b.height

    def draw_meta(self, slide, b: Block, x, y):
        cur = x
        for span in [s for s in b.node.children if isinstance(s, Node)]:
            w = b.extra["widths"].get(id(span), 120)
            box = self.textbox(slide, cur, y, w + 4, b.font * 1.4)
            self.fill_runs(box.text_frame.paragraphs[0], span, b.font, self.t.col["muted"])
            cur += w + 3 * self.t.u
        return b.height


# ── main ────────────────────────────────────────────────────────────────────

def build(deck: Path, out: Path, font: str | None, mono: str | None) -> dict:
    from pptx import Presentation
    from pptx.dml.color import RGBColor
    from pptx.util import Emu

    src = deck.read_text(encoding="utf-8")
    t = theme_from(src)
    font = font or google_font(t.css_sans, "Inter")
    mono = mono or google_font(t.css_mono, "JetBrains Mono")
    root = parse(deck)
    sections = [s for s in root.find_all("section") if "slide" in s.cls]
    if not sections:
        sys.exit('deck-to-pptx: no <section class="slide"> found')

    m = Measurer(font, mono)
    prs = Presentation()
    prs.slide_width = Emu(emu(t.w))
    prs.slide_height = Emu(emu(t.h))
    blank = prs.slide_layouts[6]
    R = Renderer(prs, t, m, font, mono)

    pad_x, pad_t, pad_b = t.px("pad-x"), t.px("pad-t"), t.px("pad-b")
    content_w = t.w - 2 * pad_x
    head_fs, foot_fs = t.px("fs-caption"), t.px("fs-foot")
    head_h = head_fs * 1.2 + 1.0 * t.u
    foot_h = foot_fs * 1.2
    gap = t.px("gap")

    stats = {"slides": 0, "shapes": 0, "chars": 0}
    for sec in sections:
        slide = prs.slides.add_slide(blank)
        bg = slide.background.fill
        bg.solid()
        bg.fore_color.rgb = RGBColor.from_string(t.col["bg"])
        is_cover = "cover" in sec.cls
        rail = t.tok["accent-w"]
        if rail:
            R.rect(slide, 0, 0, rail, t.h, t.col["accent"])

        header = next((n for n in sec.children if isinstance(n, Node) and n.tag == "header"), None)
        footer = next((n for n in sec.children if isinstance(n, Node) and n.tag == "footer"), None)
        body = next((n for n in sec.children if isinstance(n, Node)
                     and n.tag == "div" and "body" in n.cls), None)

        if header:
            spans = [s for s in header.children if isinstance(s, Node)]
            for i, span in enumerate(spans[:2]):
                right = i == 1
                box = R.textbox(slide, pad_x + (content_w * 0.4 if right else 0), pad_t,
                                content_w * 0.6, head_fs * 1.2,
                                align="r" if right else "l")
                R.fill_runs(box.text_frame.paragraphs[0], span, head_fs,
                            t.col["muted"], .14, upper=True)
        R.rect(slide, pad_x, pad_t + head_h - 1, content_w, 1, t.col["rule"])

        if footer:
            spans = [s for s in footer.children if isinstance(s, Node)]
            fy = t.h - pad_b - foot_h
            for i, span in enumerate(spans[:2]):
                right = i == len(spans[:2]) - 1
                box = R.textbox(slide, pad_x + (content_w * 0.5 if right else 0), fy,
                                content_w * 0.5, foot_h, align="r" if right else "l")
                R.fill_runs(box.text_frame.paragraphs[0], span, foot_fs,
                            t.col["muted"], .1, upper=True)

        if not body:
            stats["slides"] += 1
            continue
        blocks = slide_blocks(body, t)
        if not blocks:
            stats["slides"] += 1
            continue

        # ---- measure every block before placing any ----
        items, index = [], []
        for b in blocks:
            if b.kind == "list":
                lis = [li for li in b.node.children if isinstance(li, Node) and li.tag == "li"]
                for li in lis:
                    index.append(("li", b, li))
                    items.append({"html": inner_html(li), "w": b.width - b.indent,
                                  "fs": b.font, "lh": b.lh})
            elif b.kind == "pre":
                b.height = len(pre_lines(b.node)) * b.font * b.lh + 2 * t.px("pre-pad-y")
            elif b.kind == "table":
                rows = b.node.find_all("tr")
                cells = [[td for td in tr.children if isinstance(td, Node)
                          and td.tag in ("td", "th")] for tr in rows]
                ncol = max(len(r) for r in cells) if cells else 1
                nat = [0.0] * ncol
                for row in cells:
                    for ci, cell in enumerate(row):
                        if ci < ncol:
                            nat[ci] = max(nat[ci], len(cell.text()) * b.font * 0.52)
                total = sum(nat) or 1.0
                col_w = [max(0.15 * b.width, b.width * n / total) for n in nat]
                scale = b.width / sum(col_w)
                b.extra["col_w"] = [w * scale for w in col_w]
                b.extra["row_h"] = [b.font * 1.4 + 2 * t.px("table-pad-y")
                                    for _ in cells]
                b.height = sum(b.extra["row_h"])
            elif b.kind == "rules":
                widths, maxw = {}, 0.0
                for rule in [r for r in b.node.children if isinstance(r, Node) and r.tag == "div"]:
                    texts = [d.text() for d in rule.children if isinstance(d, Node)]
                    w = max(len(x) for x in texts) * b.font * 0.62 if texts else 200
                    w = max(w, 0.0) + 2 * 0.5 * b.font
                    widths[id(rule)] = max(w, 180.0)
                    maxw = max(maxw, widths[id(rule)])
                b.extra["widths"] = widths
                b.extra["pad"] = 1.2 * t.u
                b.width = sum(widths.values()) + 3 * t.u * max(0, len(widths) - 1)
                b.height = 2 * 1.2 * t.u + b.font * 1.5 * 2 + t.px("li-gap") + b.font
            elif b.kind == "meta":
                widths, total = {}, 0.0
                for span in [s for s in b.node.children if isinstance(s, Node)]:
                    w = max(60.0, len(span.text()) * b.font * 0.55)
                    widths[id(span)] = w
                    total += w + 3 * t.u
                b.extra["widths"] = widths
                b.width, b.height = total, b.font * 1.4
            else:
                index.append(("solo", b, None))
                items.append({"html": inner_html(b.node), "w": min(b.width, content_w),
                              "fs": b.font, "lh": b.lh, "ls": b.ls})

        heights = m.heights(items)
        for (kind, b, _), h in zip(index, heights):
            if kind == "li":
                b.extra.setdefault("li_h", []).append(h)
            else:
                b.height = h
        for b in blocks:
            if b.kind == "list":
                hs = b.extra.get("li_h", [])
                b.height = sum(hs) + t.px("li-gap") * max(0, len(hs) - 1)

        # ---- place: vertically centred, exactly like the CSS flex box ----
        total_h = sum(b.height for b in blocks) + gap * (len(blocks) - 1)
        body_top = pad_t + head_h + 1.0 * t.u
        body_bottom = t.h - pad_b - foot_h - 1.0 * t.u
        avail = body_bottom - body_top
        y = (max(body_top, body_bottom - total_h) if is_cover
             else body_top + max(0.0, (avail - total_h) / 2))

        for b in blocks:
            if b.kind == "list":
                R.draw_list(slide, b, pad_x, y)
            elif b.kind == "pre":
                R.draw_pre(slide, b, pad_x, y)
            elif b.kind == "table":
                R.draw_table(slide, b, pad_x, y)
            elif b.kind == "rules":
                R.draw_rules(slide, b, pad_x, y)
            elif b.kind == "meta":
                R.draw_meta(slide, b, pad_x, y)
            else:
                R.draw_text(slide, b, pad_x, y)
            y += b.height + gap

        stats["slides"] += 1
        stats["shapes"] += len(slide.shapes)
        stats["chars"] += len(re.sub(r"<[^>]+>", "", body.text()))

    m.close()
    prs.save(str(out))
    stats.update(file=str(out), font=font, mono=mono, theme=t)
    return stats


def verify(path: Path, expect: int) -> tuple[list[str], list[str]]:
    from pptx import Presentation
    prs = Presentation(str(path))
    fails, notes = [], []
    if len(prs.slides) != expect:
        fails.append(f"{len(prs.slides)} slides, expected {expect}")
    W, H = prs.slide_width, prs.slide_height
    for i, s in enumerate(prs.slides, 1):
        boxes = []
        for sh in s.shapes:
            if sh.left is None:
                continue
            if (sh.left < -10 or sh.top < -10 or sh.left + sh.width > W + 10
                    or sh.top + sh.height > H + 10):
                fails.append(f"slide {i}: shape off-canvas "
                             f"({sh.left/PX:.0f},{sh.top/PX:.0f})")
            if sh.has_text_frame and sh.text_frame.text.strip():
                boxes.append(sh)
        if not boxes:
            fails.append(f"slide {i}: no text at all")
        # overlap between stacked blocks on the same rail (hairlines excluded)
        tall = sorted([b for b in boxes if b.width / PX > 40], key=lambda b: b.top)
        for a in tall:
            for b in tall:
                if b is a or b.top <= a.top:
                    continue
                if a.left + a.width <= b.left + 2 or b.left + b.width <= a.left + 2:
                    continue        # side by side, not stacked
                if a.top + a.height <= b.top + 3:
                    continue
                notes.append(f"slide {i}: '{a.text_frame.text[:24]}' overlaps "
                             f"'{b.text_frame.text[:24]}' by "
                             f"{(a.top + a.height - b.top) / PX:.0f}px")
    return fails, notes


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("deck", type=Path)
    ap.add_argument("-o", "--out", type=Path)
    ap.add_argument("--font", default=None, help="default: map the deck's font to Google Fonts")
    ap.add_argument("--mono", default=None)
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--tokens", action="store_true", help="print the resolved theme")
    a = ap.parse_args()
    if not a.deck.exists():
        sys.exit(f"no such file: {a.deck}")
    _reexec_into_venv()

    if a.tokens:
        t = theme_from(a.deck.read_text(encoding="utf-8"))
        print(f"canvas: {t.w:.0f}x{t.h:.0f} px   u={t.u:.2f}px   "
              f"sans={google_font(t.css_sans, 'Inter')} mono={google_font(t.css_mono, 'JetBrains Mono')}")
        for name in ("bg", "ink", "muted", "rule", "wash", "accent"):
            print(f"  --{name:<14} #{t.col[name]}")
        for name in TOKEN_DEFAULTS:
            v = t.tok[name]
            print(f"  --{name:<14} {v:8.2f} px")
        return 0

    out = a.out or a.deck.with_suffix(".pptx")
    stats = build(a.deck, out, a.font, a.mono)
    print(f"pptx: {stats['file']} ({stats['slides']} slides, {stats['shapes']} shapes, "
          f"{stats['chars']} chars)")
    print(f"fonts: {stats['font']} / {stats['mono']}")
    if unknown:
        print(f"WARN unknown block(s) exported as plain paragraphs: "
              f"{', '.join(sorted(set(unknown)))}")
    if a.verify:
        fails, notes = verify(out, stats["slides"])
        for n in notes[:10]:
            print("  note:", n)
        if fails:
            print("\nFAIL")
            for f in fails[:20]:
                print("  -", f)
            return 1
        print(f"verify: all shapes inside {stats['theme'].w:.0f}x{stats['theme'].h:.0f}, "
              f"no empty slide, {len(notes)} overlap note(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
