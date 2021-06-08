# Recorded acceptance

These are unmodified JSON outputs from a fresh GitHub clone and both hosted CI
jobs for code revision `fe20506f9b66c99da401b0587c3c0c9b58187516`.
All three runs passed with the same behavioral source digest:

```text
4d247cd1df7ce4ca02f07ec1585af4ec1e151448a7cce555ba4be007a2b77f26
```

| Execution | Receipt | Source manifest |
| --- | --- | --- |
| Fresh clone, macOS arm64 | [Verification](local-fresh/verification.json) | [Files](local-fresh/source-manifest.json) |
| Ubuntu 24.04 hosted job | [Verification](ubuntu-24.04/verification.json) | [Files](ubuntu-24.04/source-manifest.json) |
| macOS 15 hosted job | [Verification](macos-15/verification.json) | [Files](macos-15/source-manifest.json) |

[Hosted run](https://github.com/Aneesh495/murmur/actions/runs/39556557588).
Each receipt embeds its observations and records the SHA-256 of every individual
report beside it. Those hashes were independently checked before these files
were copied here. Source manifests agree across all three environments.

Each Scheme mode passed 72 cases and 34,840 assertions. The whole-command checks
also passed, including six whole-bundle redaction comparisons, independent PCM
decoding, 303 malformed inputs, analytic signal probes, patch application,
source mutation, cancellation, and every shipped example. See
[verification scope](../verification.md) for the precise checks and limits.

The fresh clone also ran the optional [publication benchmark](local-fresh/benchmark.json).
Its [source accounting](local-fresh/source-accounting.json) records 2,564
production Scheme lines, 811 Scheme test lines, and 26 Scheme build/entry lines.
Counts are physical lines and include comments and blank lines. Generated files
are excluded. Documentation counts describe that revision before this evidence
directory was added.

The receipt binds behavioral files, examples, and CI configuration. Markdown and
screenshots are outside that digest. Later evidence-only or documentation commits
do not imply a changed algorithm. Run `make verify` in the current checkout to
obtain a new receipt; these saved observations do not replace a current run.
