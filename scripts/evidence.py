#!/usr/bin/env python3
"""Bind acceptance results to an unchanged source and test manifest."""

import hashlib
import json
import platform
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"
REPORTS = [
    "scheme-tests.json",
    "native-abi.json",
    "identity.json",
    "acceptance.json",
    "commands.json",
    "malformed.json",
    "signals.json",
    "review-tests.json",
    "examples.json",
    "interrupt.json",
    "structure.json",
    "review-html.json",
]


def source_manifest():
    files = []
    for directory in ["src", "native", "tests", "scripts", ".github", "examples"]:
        files.extend(
            p
            for p in (ROOT / directory).rglob("*")
            if p.is_file() and "__pycache__" not in p.parts and p.suffix != ".md"
        )
    files += [ROOT / "Makefile", ROOT / ".gitignore"]
    entries = {
        str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in sorted(files)
    }
    canonical = json.dumps(entries, sort_keys=True, separators=(",", ":")).encode()
    return {"sha256": hashlib.sha256(canonical).hexdigest(), "files": entries}


def version(command):
    result = subprocess.run(command, text=True, capture_output=True, check=True)
    return result.stdout.splitlines()[0]


def main():
    if not __debug__:
        raise SystemExit("verification requires Python assertions enabled")
    BUILD.mkdir(exist_ok=True)
    if len(sys.argv) != 2 or sys.argv[1] not in ["begin", "finish"]:
        raise SystemExit("usage: evidence.py begin|finish")
    if sys.argv[1] == "begin":
        for name in REPORTS + ["verification.json"]:
            (BUILD / name).unlink(missing_ok=True)
        (BUILD / "source-manifest.json").write_text(
            json.dumps(source_manifest(), indent=2) + "\n"
        )
        return
    original = json.loads((BUILD / "source-manifest.json").read_text())
    current = source_manifest()
    if current != original:
        raise SystemExit(
            "source or tests changed during acceptance; no acceptance receipt issued"
        )
    results = {}
    for name in REPORTS:
        path = BUILD / name
        content = json.loads(path.read_text())
        if name == "scheme-tests.json" and (
            content["failures"] != 0 or content["cases"] == 0
        ):
            raise SystemExit("Scheme suite did not pass")
        results[name] = {
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "result": content,
        }
    report = {
        "status": "passed",
        "sourceSha256": current["sha256"],
        "host": platform.platform(),
        "python": sys.version.split()[0],
        "guile": version(["guile", "--version"]),
        "cc": version(["cc", "--version"]),
        "node": version(["node", "--version"]),
        "reports": results,
    }
    (BUILD / "verification.json").write_text(json.dumps(report, indent=2) + "\n")
    print("verified unchanged source", current["sha256"])


if __name__ == "__main__":
    main()
