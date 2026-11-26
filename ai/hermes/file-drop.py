#!/usr/bin/env python3
"""file-drop: read-only listing of ~/share, one page, stdlib only.

Replaced `python3 -m http.server` on 2026-10-22. That listing is a bare list of
names — no sizes, dates, sort order, path or filter — which stops being usable
the moment the directory holds more than one file.

Still GET/HEAD only: no uploads, no writes, no Range (a resumed download is not
possible; fine for documents and modpacks, not for a 2 GB world archive).

    python3 file-drop.py --selftest    # one runnable check, no server started
"""
import html
import io
import os
import sys
import time
import urllib.parse

ROOT = os.path.expanduser("~/share")


def human(n: int) -> str:
    for unit in ("B", "K", "M", "G"):
        if n < 1024 or unit == "G":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.1f} G"


def make_handler():
    from http.server import SimpleHTTPRequestHandler

    class Handler(SimpleHTTPRequestHandler):
        def __init__(self, *a, **kw):
            super().__init__(*a, directory=ROOT, **kw)

        def list_directory(self, path):
            rel = os.path.relpath(path, ROOT)
            try:
                entries = sorted(os.scandir(path),
                                 key=lambda e: (not e.is_dir(), e.name.lower()))
            except OSError:
                self.send_error(404, "No permission to list directory")
                return None

            crumbs = [("/", "share")]
            if rel != ".":
                acc = "/"
                for part in rel.split(os.sep):
                    acc += part + "/"
                    crumbs.append((acc, part))
            nav = " / ".join(
                f'<a href="{urllib.parse.quote(p)}">{html.escape(t)}</a>'
                for p, t in crumbs)
            if rel != ".":
                nav = '<a href="../">..</a> &nbsp; ' + nav

            rows = []
            for e in entries:
                try:
                    st = e.stat()
                    size = human(st.st_size) if e.is_file() else "—"
                    when = time.strftime("%Y-%m-%d %H:%M", time.localtime(st.st_mtime))
                except OSError:                      # dangling symlink
                    size, when = "?", "?"
                href = urllib.parse.quote(e.name) + ("/" if e.is_dir() else "")
                label = html.escape(e.name) + ("/" if e.is_dir() else "")
                rows.append(f'<tr><td><a href="{href}">{label}</a></td>'
                            f'<td class="n">{size}</td><td class="d">{when}</td></tr>')

            body = f"""<!doctype html><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>files — {html.escape(rel)}</title>
<style>
:root{{color-scheme:light dark}}
body{{font:15px/1.5 system-ui,sans-serif;max-width:56rem;margin:2rem auto;padding:0 1rem}}
a{{color:#3b82f6;text-decoration:none}}a:hover{{text-decoration:underline}}
nav{{margin-bottom:1rem}}input{{width:100%;padding:.45rem .6rem;margin-bottom:1rem;
border:1px solid #8884;border-radius:6px;background:transparent;color:inherit;font:inherit}}
table{{width:100%;border-collapse:collapse}}td{{padding:.35rem 0;border-bottom:1px solid #8883}}
.n{{text-align:right;white-space:nowrap;padding-left:1rem;opacity:.75}}
.d{{text-align:right;white-space:nowrap;padding-left:1rem;opacity:.55;font-variant-numeric:tabular-nums}}
footer{{margin-top:1rem;opacity:.5;font-size:13px}}
@media(prefers-color-scheme:dark){{a{{color:#7aa2f7}}}}
</style>
<nav>{nav}</nav>
<input id="q" placeholder="filter {len(rows)} entries…" autofocus>
<table><tbody id="t">{''.join(rows) or '<tr><td><em>empty</em></td></tr>'}</tbody></table>
<footer>read-only · {sum(1 for e in entries if e.is_file())} files</footer>
<script>
q.oninput=()=>{{const f=q.value.toLowerCase();
for(const r of t.rows) r.hidden = !r.cells[0].textContent.toLowerCase().includes(f);}}
</script>"""
            data = body.encode("utf-8", "surrogateescape")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            return io.BytesIO(data)

    return Handler


def selftest():
    assert human(0) == "0 B" and human(999) == "999 B"
    assert human(1536) == "1.5 K" and human(5 * 1024 ** 3) == "5.0 G"
    assert urllib.parse.quote("relatório çã.pdf") == "relat%C3%B3rio%20%C3%A7%C3%A3.pdf"
    print("selftest ok")


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        selftest()
        sys.exit(0)
    from http.server import ThreadingHTTPServer
    port = int(sys.argv[sys.argv.index("--port") + 1]) if "--port" in sys.argv else 58100
    ThreadingHTTPServer(("127.0.0.1", port), make_handler()).serve_forever()
