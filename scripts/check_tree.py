#!/usr/bin/env python3
"""Check repository navigation, publication prose, and offline asset boundaries."""

import json
import re
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
text_suffixes = {
    ".scm",
    ".c",
    ".py",
    ".js",
    ".cjs",
    ".css",
    ".html",
    ".md",
    ".yml",
    ".toml",
    ".txt",
}
files = []
for directory in ["src", "native", "tests", "scripts", "docs", "examples", ".github"]:
    files.extend(
        p
        for p in (ROOT / directory).rglob("*")
        if p.is_file() and "__pycache__" not in p.parts
    )
files.extend(ROOT / p for p in ["README.md", "PLAN.md", "Makefile", "LICENSE"])
errors = []
links = 0
for path in files:
    if path.suffix not in text_suffixes and path.name not in ["Makefile", "LICENSE"]:
        continue
    text = path.read_text()
    if chr(0x2014) in text:
        errors.append(f"em dash in {path.relative_to(ROOT)}")
    if path.suffix == ".md":
        for label, destination in re.findall(r"\[([^]]*)\]\(([^)]+)\)", text):
            if re.match(r"[a-z]+:", destination) or destination.startswith("#"):
                continue
            target = unquote(destination.split("#", 1)[0])
            if target and not (path.parent / target).exists():
                errors.append(f"broken local link {path.relative_to(ROOT)}: {target}")
            links += 1
for path in (ROOT / "src/murmur/assets").glob("*"):
    text = path.read_text()
    if re.search(r"https?://|\beval\s*\(|\bfetch\s*\(|\.innerHTML\s*=", text):
        errors.append(f"remote or executable data boundary in {path.name}")
if errors:
    raise SystemExit("\n".join(errors))
(ROOT / "build").mkdir(exist_ok=True)
(ROOT / "build/structure.json").write_text(
    json.dumps(
        {"status": "passed", "localLinks": links, "textFiles": len(files)}, indent=2
    )
    + "\n"
)
print(
    f"structure: {links} local documentation links and offline asset boundaries passed"
)
