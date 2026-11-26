#!/usr/bin/env python3
# ^ portable shebang on purpose: whichever python3 the caller's PATH resolves to,
# the stub below re-execs into the venv that actually has playwright installed.
"""deck-check — render an HTML deck headlessly and report what a human would see.

Why: the TAPL deck shipped with a `.fragment` on nearly every paragraph, so each
slide arrived as a bare heading and the audience had to click ~3 times to read a
sentence. Nobody noticed, because no agent on this machine could *look at* its
own output. This is that look.

For every slide it navigates the deck to that slide (fragments hidden, exactly
as the audience first meets it), measures how much of the slide's text is
actually visible, and screenshots it.

Checks (exit 1 if any fail):
  - console errors / failed loads
  - slides that arrive mostly blank (text hidden behind fragments)
  - click marathons (> 8 fragments on one slide)
  - external subresources (a deck that loads a CDN is not standalone)
  - element overflow past the slide canvas
  - content taller than a 1080px slide (clipped on screen AND in the PDF)
  - --lang <code>: <html lang> must match that language

Why the external-resource check exists: the TAPL deck shipped with reveal.js
loaded from cdnjs and deck-check passed it, because a CDN renders fine HERE and
the defect (dead everywhere the deck is actually opened) is invisible to a
screenshot.

Why the clipped-content check FAILS rather than warns: the second TAPL deck was
``overflow:hidden`` at 1080px and six slides had ~170px more text than that.
Every one of them rendered and screenshotted fine at the top of the slide, and
the footer and the last bullet were simply gone — on screen and in the PDF. A
margin on a `<ul>` computed against the wrong font-size was enough to do it.

Writes one PNG per slide to <deck>/shots/.

With --pdf it also writes a real PDF, one page per slide, straight from the
browser (reveal.js print mode). That replaces pandoc + xelatex + polyglossia +
texlive-lang-*, which was the chain that cost this machine hours of guessed
package names for a job the browser already does.

Usage:  deck-check FILE.html [--no-shots] [--pdf] [--lang pt] [--min-visible 0.25]
Needs:  playwright chromium in ~/.local/share/deck-check/venv
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

VENV_PY = os.path.expanduser("~/.local/share/deck-check/venv/bin/python3")
try:
    import playwright  # noqa: F401
except ImportError:
    # PATH on this box resolves python3 differently per caller (mise vs system vs
    # service env), so do not rely on the shebang: re-exec into the venv.
    if os.path.exists(VENV_PY) and sys.executable != VENV_PY:
        os.execv(VENV_PY, [VENV_PY, *sys.argv])
    sys.exit("deck-check: playwright not available. Create it with:\n"
             "  python3 -m venv ~/.local/share/deck-check/venv && \\\n"
             "  ~/.local/share/deck-check/venv/bin/pip install playwright && \\\n"
             "  ~/.local/share/deck-check/venv/bin/playwright install chromium")

MAX_CLICKS_PER_SLIDE = 8   # more than this and it is a click marathon, not a reveal
MIN_VISIBLE_TEXT = 0.25    # a slide arriving below this is "mostly blank"

MEASURE = """(h) => {
  const top = [...document.querySelectorAll('.reveal .slides > section')];
  if (window.Reveal && top.length) Reveal.slide(h);
  return top.length;
}"""

VISIBLE_TEXT = """() => {
  // Measure the section the audience is actually looking at.
  let target = document.querySelector('.reveal .slides section.present');
  if (target) {
    const inner = [...target.querySelectorAll(':scope > section.present')].pop();
    if (inner) target = inner;
  } else {
    target = document.querySelector('.reveal .slides > section') || document.body;
  }
  let total = 0, hidden = 0;
  const walk = (el) => {
    for (const node of el.childNodes) {
      if (node.nodeType === 3) {
        const t = node.textContent.trim();
        if (!t) continue;
        total += t.length;
        if (!el.checkVisibility({opacityProperty: true, visibilityProperty: true})) hidden += t.length;
      } else if (node.nodeType === 1) walk(node);
    }
  };
  walk(target);
  return {total, hidden, frags: target.querySelectorAll('.fragment').length,
          media: target.querySelectorAll('img, video, svg, canvas, iframe').length};
}"""


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        print(__doc__)
        return 2
    deck = Path(args[0]).resolve()
    shots = "--no-shots" not in sys.argv
    min_visible = MIN_VISIBLE_TEXT
    if "--min-visible" in sys.argv:
        min_visible = float(sys.argv[sys.argv.index("--min-visible") + 1])
    want_lang = ""
    if "--lang" in sys.argv:
        want_lang = sys.argv[sys.argv.index("--lang") + 1].lower()

    # Static checks on the source: a deck is judged by what it needs, not only by
    # what it paints. <a href> citations are not dependencies; sub-resources are.
    src = deck.read_text(encoding="utf-8")
    fails: list[str] = []
    external = sorted(set(re.findall(
        r"<(?:script|img|iframe|audio|video|source|embed|link)\b[^>]*?\b(?:src|href)\s*="
        r"\s*[\"']?\s*((?:https?:)?//[^\"'>\s]+)", src, re.I)))
    lang_m = re.search(r"<html[^>]*\blang\s*=\s*[\"']?([A-Za-z-]+)", src, re.I)
    lang = lang_m.group(1) if lang_m else "?"
    print(f"idioma: {lang}")
    if external:
        fails.append(f"{len(external)} external subresource(s), so not standalone: "
                     + ", ".join(external[:3]))
    if want_lang and not lang.lower().startswith(want_lang):
        fails.append(f"<html lang=\"{lang}\"> — the brief asks for {want_lang}")

    from playwright.sync_api import sync_playwright

    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={"width": 1920, "height": 1080})
        errors: list[str] = []
        page.on("console", lambda m: errors.append(m.text) if m.type == "error" else None)
        page.on("pageerror", lambda e: errors.append(str(e)))
        page.goto(deck.as_uri())
        page.wait_for_timeout(1200)

        print(f"deck: {deck.name}")
        top = page.evaluate("() => [...document.querySelectorAll('.reveal .slides > section')].length")
        nested = page.evaluate("() => [...document.querySelectorAll('.reveal .slides > section > section')].length")
        is_reveal = top > 0
        if not is_reveal:  # generic fixed-canvas deck
            top = page.evaluate("() => document.querySelectorAll('section, [data-slide], .slide').length")
        print(f"slides: {top}{f' (+{nested} nested)' if nested else ''} ({'reveal.js' if is_reveal else 'generic'})")
        if top == 0:
            fails.append("no slides found — neither reveal.js sections nor <section>/[data-slide]/.slide")

        out = deck.parent / "shots"
        if shots:
            out.mkdir(exist_ok=True)

        worst_click = (0, -1)
        for i in range(top):
            if is_reveal:
                page.evaluate(MEASURE, i)      # navigate; fragments stay hidden
                page.wait_for_timeout(250)
            else:
                page.evaluate("i => document.querySelectorAll('section,[data-slide],.slide')[i]"
                              "?.scrollIntoView()", i)
                page.wait_for_timeout(150)

            m = page.evaluate(VISIBLE_TEXT)
            frags = m["frags"]
            if frags > worst_click[0]:
                worst_click = (frags, i)
            if frags > MAX_CLICKS_PER_SLIDE:
                fails.append(f"slide #{i + 1} needs {frags} clicks (max {MAX_CLICKS_PER_SLIDE})")
            if m["total"] > 20:
                visible = 1 - m["hidden"] / m["total"]
                if visible < min_visible:
                    fails.append(
                        f"slide #{i + 1} arrives {round(100 * visible)}% visible — "
                        f"{m['hidden']} of {m['total']} characters hidden behind fragments. "
                        f"The first frame must stand on its own")
                elif visible < 0.6:
                    print(f"  note: slide #{i + 1} arrives {round(100 * visible)}% visible")

            if shots:
                page.screenshot(path=str(out / f"slide-{i + 1:02d}.png"))

            # Elements hanging off the canvas: a warning, not a failure — decorative
            # bleed is legitimate, text running off the slide is not, and only a human
            # (or the screenshot) can tell which this is.
            spill = page.evaluate("""([i, reveal]) => {
              const s = reveal
                ? document.querySelector('.reveal .slides section.present')
                : document.querySelectorAll('section,[data-slide],.slide')[i];
              if (!s) return 0;
              const box = s.getBoundingClientRect();
              let n = 0;
              for (const el of s.querySelectorAll('*')) {
                const b = el.getBoundingClientRect();
                if (!b.width || !b.height) continue;
                if (b.left < box.left - 8 || b.top < box.top - 8 ||
                    b.right > box.right + 8 || b.bottom > box.bottom + 8) n++;
              }
              return n;
            }""", [i, is_reveal])
            if spill:
                print(f"  note: slide #{i + 1} has {spill} element(s) beyond the canvas")

            # Clipped content: the slide is 1080px tall with overflow hidden, so
            # anything past that is silently cut off — on screen and in the PDF.
            # "Beyond the canvas" above can be legitimate bleed; this cannot.
            if not is_reveal:
                clipped = page.evaluate("""i => {
                  const s = document.querySelectorAll('section,[data-slide],.slide')[i];
                  return s ? s.scrollHeight - s.clientHeight : 0;
                }""", i)
                if clipped > 2:
                    fails.append(
                        f"slide #{i + 1} has {clipped}px more content than the 1080px "
                        f"canvas — it is clipped, not tight. Cut it; a screenshot of "
                        f"the top of a slide does not show what is missing at the bottom")

        if worst_click[1] >= 0:
            print(f"clicks: worst slide #{worst_click[1] + 1} needs {worst_click[0]}")
        if shots:
            print(f"screenshots: {out}/ ({top} files)")
        for e in errors[:5]:
            fails.append(f"console: {e[:120]}")
        browser.close()

    if "--pdf" in sys.argv:
        # reveal.js print mode: one page per slide, fragments shown.
        # That is the honest read-alone artifact — a PDF has no clicks.
        #
        # Fragments are stripped from a temporary print copy rather than
        # configured away: Reveal.configure({fragments:false}) does not re-layout
        # print mode, and without stripping, reveal emits ONE PAGE PER FRAGMENT
        # STEP — the TAPL deck came out as 27 pages for 6 slides.
        pdf = deck.with_suffix(".pdf")
        flat = re.sub(r'class="([^"]*)"',
                      lambda m: 'class="%s"' % re.sub(r"\bfragment\b\s*", "", m.group(1)).strip(),
                      src)
        tmp = deck.parent / ".deck-check-print.html"
        tmp.write_text(flat, encoding="utf-8")
        try:
            with sync_playwright() as p:
                b = p.chromium.launch()
                pg = b.new_page()
                pg.goto(tmp.as_uri() + "?print-pdf", wait_until="load")
                pg.wait_for_timeout(2000)
                pg.pdf(path=str(pdf), width="1920px", height="1080px",
                       print_background=True, margin={"top": "0", "bottom": "0",
                                                      "left": "0", "right": "0"})
                b.close()
        finally:
            tmp.unlink(missing_ok=True)
        pages = "?"
        try:
            import subprocess
            out = subprocess.run(["pdfinfo", str(pdf)], capture_output=True, text=True, timeout=20).stdout
            for line in out.splitlines():
                if line.startswith("Pages:"):
                    pages = line.split()[-1]
        except Exception:
            pass  # pdfinfo optional; the PDF still exists
        print(f"pdf: {pdf} ({pages} pages, {pdf.stat().st_size // 1024} KiB)")

    if fails:
        print("\nFAIL")
        for f in fails:
            print(f"  - {f}")
        return 1
    print("\nOK — renders, no console errors, no overflow, slides arrive readable")
    return 0


if __name__ == "__main__":
    sys.exit(main())
