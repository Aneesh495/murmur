#!/usr/bin/env python3
"""Physical source accounting, with generated data and build products excluded."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GROUPS = {
    "scheme-production": [],
    "scheme-tests": [],
    "scheme-build": [],
    "c-adapter": [],
    "browser-js": [],
    "browser-css": [],
    "browser-html": [],
    "python-verification": [],
    "documentation": [],
}
for directory in ["src", "native", "tests", "scripts", "docs"]:
    for path in sorted((ROOT / directory).rglob("*")):
        if not path.is_file() or "__pycache__" in path.parts:
            continue
        suffix = path.suffix
        group = None
        if suffix == ".scm":
            group = (
                "scheme-production"
                if directory == "src"
                else "scheme-tests" if directory == "tests" else "scheme-build"
            )
        elif suffix == ".c":
            group = "c-adapter"
        elif suffix in (".js", ".cjs"):
            group = "browser-js"
        elif suffix == ".css":
            group = "browser-css"
        elif suffix == ".html":
            group = "browser-html"
        elif suffix == ".py":
            group = "python-verification"
        elif suffix == ".md":
            group = "documentation"
        if group:
            GROUPS[group].append(path)
for name in ["README.md", "PLAN.md"]:
    if (ROOT / name).exists():
        GROUPS["documentation"].append(ROOT / name)
result = {}
for group, files in GROUPS.items():
    lines = [line for path in files for line in path.read_text().splitlines()]
    result[group] = {
        "files": len(files),
        "physicalLines": len(lines),
        "nonblankLines": sum(bool(line.strip()) for line in lines),
    }
(ROOT / "build").mkdir(exist_ok=True)
(ROOT / "build/source-accounting.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result, indent=2))
