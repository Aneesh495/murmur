#!/usr/bin/env python3
"""Parse a real exported HTML document with adversarial user marker text."""

import json
import tempfile
from html.parser import HTMLParser
from pathlib import Path

from acceptance import ROOT, run, write_pcm


class ReviewParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.counts = {}
        self.data = ""
        self.in_data = False
        self.audio = []
        self.remote = []

    def handle_starttag(self, tag, attrs):
        self.counts[tag] = self.counts.get(tag, 0) + 1
        attrs = dict(attrs)
        if tag == "script" and attrs.get("id") == "review-data":
            self.in_data = True
        if tag == "audio":
            self.audio.append(attrs.get("src"))
        for key in ("src", "href"):
            if attrs.get(key, "").startswith(("http:", "https:", "//")):
                self.remote.append(attrs[key])

    def handle_endtag(self, tag):
        if tag == "script":
            self.in_data = False

    def handle_data(self, data):
        if self.in_data:
            self.data += data


payload = "</script><img src=x onerror=alert(1)><script>bad()</script>"
with tempfile.TemporaryDirectory(prefix="murmur-html-") as temp:
    base = Path(temp)
    write_pcm(base / "input.wav", [1000, -1000] * 100)
    (base / "edit.mur").write_text(f"""(murmur (version 1) (rate 8000) (channels 1)
      (source field (path "input.wav")) (clip a (source field) (to 1/40))
      (marker (at 0) (label {json.dumps(payload)})))""")
    run("render", base / "edit.mur", base / "out")
    text = (base / "out/review.html").read_text()
    parser = ReviewParser()
    parser.feed(text)
    assert all(parser.counts.get(tag) == 1 for tag in ("html", "head", "body"))
    assert parser.counts.get("script") == 3
    assert parser.counts.get("img", 0) == 0 and parser.audio == ["audio.wav"]
    assert not parser.remote and payload not in text
    assert json.loads(parser.data)["plan"]["markers"][0]["label"] == payload
(ROOT / "build/review-html.json").write_text(
    json.dumps(
        {
            "status": "passed",
            "checks": [
                "document shape",
                "script escaping",
                "relative audio",
                "offline resources",
            ],
        },
        indent=2,
    )
    + "\n"
)
print(
    "review HTML: structural shape, hostile marker escaping, and offline resource references passed"
)
