#!/usr/bin/env python3
"""llm-bench — one number for "is the box fast right now, and why not".

Why this exists: throughput on derby is a function of the last ten minutes of
load, not of the model or the config. Same process, same weights, same prompt
shape measured 335-357 tok/s prefill from a cool package (66 C) and 49 tok/s
from a heat-soaked one, because the EC squeezes the dGPU from 35 W to 20 W /
~330 MHz. So a benchmark is only meaningful with the clock and the temperature
printed next to it, and the numbers in AGENTS.md are not safe to quote without
re-measuring. This prints all of it on one line.

  ./llm-bench.py            # 7k-token prefill + a few output tokens
  ./llm-bench.py --tokens 32000

Exit code is 0 even when the model is unreachable — this is a probe, not a
health check. Absence of a line means the request itself failed.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import threading
import time
import urllib.request
import uuid

MODEL = "qwen3.6-30b-a3b"
URL = "http://127.0.0.1:58000/v1/chat/completions"


def sh(*cmd: str) -> str:
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=10).stdout.strip()
    except Exception:
        return "?"


def gpu() -> str:
    out = sh("nvidia-smi", "--query-gpu=clocks.gr,power.draw,temperature.gpu,utilization.gpu",
             "--format=csv,noheader,nounits")
    return out or "nvidia-smi unavailable"


def pkg_temp() -> str:
    # "Package id 0: +63.0C" -> "63"
    line = next((l for l in sh("sensors").splitlines() if "Package id" in l), "")
    return line.split("+")[1].split(".")[0] if "+" in line else "?"


def cpu_mhz() -> int:
    """Max core clock right now. The discriminator: `--n-cpu-moe 44` puts ~92%
    of the expert FLOPs on CPU, so a heat-soaked box can lose 4-7x either because
    the CPU is throttled or because the dGPU is. Peak core MHz during the request
    says which."""
    try:
        with open("/proc/cpuinfo") as fh:
            return int(max(float(l.split(":")[1]) for l in fh if l.startswith("cpu MHz")))
    except Exception:
        return 0


def peak_mhz(stop: threading.Event, peak: list[int]) -> None:
    """Sample in place: a daemon thread that only reports on the way out is
    killed by the interpreter before it can report (measured: peak 0 MHz)."""
    while not stop.wait(0.5):
        peak[0] = max(peak[0], cpu_mhz())


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tokens", type=int, default=7000, help="filler tokens in the prompt")
    ap.add_argument("--out", type=int, default=2, help="tokens to generate")
    a = ap.parse_args()

    # ~4 chars/token, and the filler is 45 chars, so 1 word-list repeat is 11 tokens.
    filler = "The quick brown fox jumps over the lazy dog. " * ((a.tokens * 4) // 45 + 1)
    # Salt the HEAD. A cold prefill is the number we want, and llama-server keeps
    # the KV of a warm prefix: without this a smaller prompt is a pure cache hit
    # (measured 9,594 tok/s, which is not a speed, it is a lookup).
    nonce = f"[{uuid.uuid4().hex}] "
    body = json.dumps({
        "model": MODEL,
        "messages": [{"role": "user", "content": nonce + filler + "\n\nReply with exactly: OK"}],
        "max_tokens": a.out,
        "temperature": 0,
        "stream": False,
    }).encode()

    before = f"pkg={pkg_temp()}C gpu[{gpu()}]"
    stop, peak = threading.Event(), [0]
    threading.Thread(target=peak_mhz, args=(stop, peak), daemon=True).start()
    t0 = time.time()
    try:
        req = urllib.request.Request(URL, data=body, headers={"content-type": "application/json"})
        usage = json.loads(urllib.request.urlopen(req, timeout=1800).read()).get("usage", {})
    except Exception as exc:
        stop.set()
        print(f"FAILED after {time.time() - t0:.1f}s: {exc}", file=sys.stderr)
        return 0
    wall = time.time() - t0
    stop.set()
    peak[0] = max(peak[0], cpu_mhz())

    inp = usage.get("prompt_tokens") or 0
    print(f"prefill {inp} tok in {wall:.1f}s = {inp / wall:.0f} tok/s | "
          f"peak cpu {peak[0]} MHz | BEFORE {before} | "
          f"AFTER pkg={pkg_temp()}C gpu[{gpu()}]")
    return 0


if __name__ == "__main__":
    sys.exit(main())
