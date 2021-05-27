#!/usr/bin/env python3
"""Whole-command validation, including option ordering and new-output ownership."""

import hashlib
import json
import tempfile
from pathlib import Path

from acceptance import ROOT, run, write_pcm

with tempfile.TemporaryDirectory(prefix="murmur-commands-") as temp:
    base = Path(temp)
    source = base / "recording.wav"
    write_pcm(source, [2000, -2000] * 100)
    document = base / "edit.mur"
    run("init", source, document)
    original = document.read_bytes()
    run("init", source, document, ok=False)
    assert original == document.read_bytes()
    assert json.loads(run("plan", document).stdout)["frames"] == 200
    run("explain", document, "0")
    run("explain", document, "200", ok=False)
    run("render", document, base / "normal")
    run("render", document, base / "normal", ok=False)
    manifest = base / "normal/manifest.mur"
    saved_manifest = base / "saved-manifest.mur"
    manifest.rename(saved_manifest)
    manifest.symlink_to(saved_manifest)
    result = run("verify", base / "normal", ok=False)
    assert "bundle" in result.stderr
    manifest.unlink()
    saved_manifest.rename(manifest)

    for name, options in [
        ("a", ["--float", "--bits", "16"]),
        ("b", ["--bits", "16", "--float"]),
    ]:
        result = run("render", document, base / name, *options, ok=False)
        assert "format" in result.stderr and not (base / name).exists()
    for options in [
        ("--bits", "q"),
        ("--block-size", "0"),
        ("--what",),
        ("--bits",),
        ("--bits", "16", "--bits", "24"),
    ]:
        run("render", document, base / "bad", *options, ok=False)
        assert not (base / "bad").exists()
    target = base / "dangling"
    target.symlink_to(base / "missing")
    run("render", document, target, ok=False)
    assert target.is_symlink()
    for body in [b"\xff\xfe\x00", b'#.(system "x")', b"()", b"(murmur (version 1))"]:
        (base / "bad.mur").write_bytes(body)
        run("plan", base / "bad.mur", ok=False)
    labels = base / "labels.tsv"
    labels.write_text("0.001\t0.01\tprivate transcript\n")
    patch = base / "patch.mur"
    patch.write_text(run("labels", document, "recording", labels).stdout)
    assert "private transcript" not in patch.read_text()
    run("apply-patch", document, patch, base / "next.mur")
    assert document.read_bytes() == original
    run("render", base / "next.mur", base / "patched")
    raw = hashlib.sha256(source.read_bytes()).hexdigest()
    for f in (base / "patched").iterdir():
        assert raw.encode() not in f.read_bytes()
print(
    "commands: init, errors, option ordering, patch application, and destination ownership passed"
)

(ROOT / "build" / "commands.json").write_text(
    json.dumps(
        {
            "status": "passed",
            "checks": [
                "init",
                "errors",
                "option ordering",
                "patch application",
                "destination ownership",
            ],
        },
        indent=2,
    )
    + "\n"
)
