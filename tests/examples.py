#!/usr/bin/env python3
"""Run the real demo and every shipped edit document in a fresh private tree."""

from pathlib import Path
import json
import shutil
import tempfile
from acceptance import ROOT, run

checked = []
with tempfile.TemporaryDirectory(prefix="murmur-examples-") as temp:
    base = Path(temp)
    (base / "build").mkdir()
    (base / "examples").mkdir()
    run("demo", base / "build/demo")
    run("verify", base / "build/demo/review")
    for example in sorted((ROOT / "examples").glob("*.mur")):
        document = base / "examples" / example.name
        shutil.copyfile(example, document)
        output = base / example.stem
        run("render", document, output)
        result = json.loads(run("verify", output).stdout)
        assert result["frames"] > 0 and result["files"] == 5
        checked.append(example.name)
assert len(checked) == 3
(ROOT / "build/examples.json").write_text(
    json.dumps({"status": "passed", "examples": checked}, indent=2) + "\n"
)
print("examples: synthetic demo and all three shipped edit documents passed")
