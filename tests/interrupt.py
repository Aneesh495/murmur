#!/usr/bin/env python3
"""Interrupt a real render after staging begins and verify complete cleanup."""

from pathlib import Path
import hashlib
import json
import signal
import subprocess
import tempfile
import time
import wave
from acceptance import ROOT

with tempfile.TemporaryDirectory(prefix="murmur-interrupt-") as temp:
    base = Path(temp)
    source = base / "input.wav"
    with wave.open(str(source), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(44100)
        f.writeframes(b"\x00\x04" * 1000000)
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    project = base / "edit.mur"
    project.write_text(
        """(murmur (version 1) (rate 48000)
      (source field (path "input.wav")) (clip long (source field) (to 1000000/44100)))"""
    )
    child = subprocess.Popen(
        [str(ROOT / "bin/murmur"), "render", str(project), str(base / "output")],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        deadline = time.monotonic() + 30
        while not list(base.glob(".murmur-*")):
            if child.poll() is not None:
                raise AssertionError(child.communicate())
            if time.monotonic() > deadline:
                raise TimeoutError("render did not enter staging")
            time.sleep(0.01)
        child.send_signal(signal.SIGINT)
        stdout, stderr = child.communicate(timeout=20)
        exit_code = (
            child.returncode if child.returncode >= 0 else 128 - child.returncode
        )
        assert exit_code == 130, (child.returncode, stdout, stderr)
        assert not (base / "output").exists()
        assert not list(base.glob(".murmur-*"))
        assert hashlib.sha256(source.read_bytes()).hexdigest() == digest
    finally:
        if child.poll() is None:
            child.kill()
            child.wait()
(ROOT / "build/interrupt.json").write_text(
    json.dumps(
        {"status": "passed", "signal": "SIGINT", "exitCode": 130, "stageCleaned": True},
        indent=2,
    )
    + "\n"
)
print(
    "interrupt: SIGINT exits 130, removes the owned stage, and preserves source bytes"
)
