#!/usr/bin/env python3
"""Analytic signal checks independent of the Scheme DSP implementations."""

import json
import math
import random
import tempfile
from pathlib import Path

from acceptance import ROOT, decode_wave, run, write_pcm

results = {}
with tempfile.TemporaryDirectory(prefix="murmur-signals-") as temp:
    base = Path(temp)
    for frequency in [50, 440, 1000, 3000, 6000, 9000]:
        case = base / f"resample-{frequency}"
        case.mkdir()
        native, output, frames = 48000, 8000, 9600
        values = [
            round(12000 * math.sin(math.tau * frequency * i / native))
            for i in range(frames)
        ]
        write_pcm(case / "input.wav", values, native)
        (case / "edit.mur").write_text("""(murmur (version 1) (rate 8000) (channels 1)
          (source field (path "input.wav")) (clip a (source field) (to 1/5)))""")
        run("render", case / "edit.mur", case / "out", "--float", "--no-dither")
        _, _, samples, _ = decode_wave(case / "out/audio.wav")
        samples = samples[200:-200]
        rms = math.sqrt(sum(x * x for x in samples) / len(samples))
        if frequency <= 3000:
            expected = [
                12000 / 32768 * math.sin(math.tau * frequency * (i + 200) / output)
                for i in range(len(samples))
            ]
            error = max(abs(x - y) for x, y in zip(samples, expected))
            assert error < 0.0002, (frequency, error)
            results[f"{frequency}Hz-passband-max-error"] = error
        else:
            assert rms < 0.0001, (frequency, rms)
            results[f"{frequency}Hz-stopband-rms"] = rms
    rng = random.Random(1977)
    values = []
    clean = []
    for i in range(2400):
        signal = 0 if i < 480 else 0.25 * math.sin(math.tau * 1000 * i / 8000)
        noise = rng.uniform(-0.025, 0.025)
        values.append(round((signal + noise) * 32768))
        clean.append(signal)
    write_pcm(base / "noisy.wav", values)
    (base / "repair.mur").write_text("""(murmur (version 1) (rate 8000) (channels 1)
      (source field (path "noisy.wav")) (clip a (source field) (to 3/10))
      (effect denoise (profile-from 0) (profile-to 0.06) (size 128) (strength 1.2)))""")
    run("render", base / "repair.mur", base / "repaired", "--no-dither")
    _, _, actual, _ = decode_wave(base / "repaired/audio.wav")
    region = range(1000, 2200)
    before = sum((values[i] / 32768 - clean[i]) ** 2 for i in region) / len(region)
    after = sum((actual[i] - clean[i]) ** 2 for i in region) / len(region)
    improvement = 10 * math.log10(before / after)
    assert improvement > 3, (before, after, improvement)
    results["stationary-noise-snr-improvement-db"] = improvement
(ROOT / "build").mkdir(exist_ok=True)
(ROOT / "build/signals.json").write_text(json.dumps(results, indent=2) + "\n")
print("signals: six resampling frequencies and stationary-noise repair passed", results)
