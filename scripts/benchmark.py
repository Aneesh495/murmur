#!/usr/bin/env python3
"""Measure the actual publication command, including startup, hashes, and review."""

from pathlib import Path
import argparse
import json
import math
import platform
import resource
import statistics
import struct
import subprocess
import tempfile
import time
import wave

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--runs", type=int, default=3)
args = parser.parse_args()
if not 1 <= args.runs <= 10:
    raise SystemExit("runs must be 1 to 10")
results = []
with tempfile.TemporaryDirectory(prefix="murmur-benchmark-") as temp:
    base = Path(temp)
    for name, native, output, effects in [
        ("native-stream", 8000, 8000, "(effect highpass (hz 80)) (effect limit)"),
        (
            "rational-resample",
            44100,
            48000,
            "(effect highpass (hz 80)) (effect compress) (effect limit)",
        ),
        (
            "spectral-repair",
            8000,
            8000,
            "(effect denoise (profile-from 0) (profile-to 0.25) (size 512)) (effect limit)",
        ),
    ]:
        directory = base / name
        directory.mkdir()
        frames = native * 2
        samples = [
            round(
                (
                    0.01 * math.sin(i * 1.913)
                    + (
                        0.15 * math.sin(math.tau * 440 * i / native)
                        if i >= native // 3
                        else 0
                    )
                )
                * 32768
            )
            for i in range(frames)
        ]
        with wave.open(str(directory / "input.wav"), "wb") as f:
            f.setnchannels(1)
            f.setsampwidth(2)
            f.setframerate(native)
            f.writeframes(struct.pack("<" + "h" * len(samples), *samples))
        (directory / "edit.mur").write_text(
            f"""(murmur (version 1) (rate {output}) (channels 2)
          (source field (path "input.wav")) (redact field (from 1) (to 1.1) (guard 0))
          (clip a (source field) (to 2)) {effects})"""
        )
        times = []
        for run in range(args.runs):
            start = time.perf_counter()
            subprocess.run(
                [
                    str(ROOT / "bin/murmur"),
                    "render",
                    str(directory / "edit.mur"),
                    str(directory / f"out-{run}"),
                ],
                check=True,
                capture_output=True,
                text=True,
            )
            times.append(time.perf_counter() - start)
        results.append(
            {
                "case": name,
                "nativeRate": native,
                "outputRate": output,
                "frames": output * 2,
                "wallSeconds": times,
                "medianSeconds": statistics.median(times),
                "framesPerSecond": output * 2 / statistics.median(times),
            }
        )
peak = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
report = {
    "host": platform.platform(),
    "runs": args.runs,
    "scope": "fresh CLI processes; includes source identity, render, encoded analysis, HTML, hashes, and publication; warm filesystem cache",
    "maximumChildRssBytes": peak if platform.system() == "Darwin" else peak * 1024,
    "cases": results,
}
(ROOT / "build").mkdir(exist_ok=True)
(ROOT / "build/benchmark.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
