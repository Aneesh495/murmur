#!/usr/bin/env python3
"""A public source identity must not depend on platform libm replacement values."""

from pathlib import Path
import hashlib
import json
import tempfile
from acceptance import ROOT, run, write_pcm

with tempfile.TemporaryDirectory(prefix="murmur-identity-") as temp:
    base = Path(temp)
    write_pcm(base / "input.wav", [0] * 800)
    (base / "edit.mur").write_text("""(murmur (version 1) (rate 8000) (channels 1)
      (source field (path "input.wav"))
      (redact field (from 0.01) (to 0.02) (guard 0) (mode tone) (hz 1000) (level-db -18))
      (clip a (source field) (to 0.1)))""")
    run("render", base / "edit.mur", base / "out")
    actual = json.loads((base / "out/receipt.json").read_text())["sources"][0][
        "sanitizedSha256"
    ]
    prefix = b"MURMUR-SANITIZED-SOURCE-v1\n8000 1 800\n((80 160 tone -18 1000 0))\n"
    expected = hashlib.sha256(prefix + b"\0" * (800 * 8)).hexdigest()
    assert actual == expected, (actual, expected)
(ROOT / "build/identity.json").write_text(
    json.dumps({"status": "passed", "canonicalSha256": expected}, indent=2) + "\n"
)
print("identity: independent canonical source digest excludes replacement libm values")
