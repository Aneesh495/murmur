# Verification and measurements

[Recorded fresh-clone and hosted results](evidence/README.md) preserve the raw
reports and matching source manifests from macOS and Linux.

## Reproduce

```sh
make verify
make bench
make accounting
```

The normal product needs Guile, Make, and a C11 compiler. Full verification adds
Python 3.10+ and Node 18+, with no third-party packages. Tests run without an audio
device, external service, downloaded recording, or credentials.

`make verify` captures a source/test manifest before the build, removes known old
check reports, runs every required suite, and compares the manifest at the end.
A changed source or missing report prevents `build/verification.json`. The
manifest includes examples and CI configuration. Documentation is checked for
navigation and publication rules but is outside the behavioral source digest.

## Coverage by mechanism

| Boundary | Check and independent evidence |
| --- | --- |
| Exact clocks | Decimal/rational parsing, ties toward the future, outward mask rounding, frame round trips |
| Interval algebra | Union/intersection/subtraction against enumerated point sets |
| WAV | Integer extrema, float/nonfinite handling, odd padding, unknown chunks, extensible headers, malformed lengths |
| PCM publication | Python decodes PCM16, PCM24, and float32 independently and compares actual exported samples |
| Canonical identity | Python derives a fixed digest from zeroed masked samples and the normalized recipe, independently of replacement sin/cos values |
| Public integrity | Python `hashlib` checks every manifest and receipt artifact digest |
| Sample redaction | Whole-output comparisons for every sample in both channels |
| Whole-bundle redaction | Six pairs: three replacement modes through streaming and spectral chains; all public bytes compared |
| Negative controls | Unmasked change must alter output; tampered and unlisted artifacts must fail verification |
| Resampling | Analytic sine phase and passband error, stopband probes, exact DC, length, and I/O partition invariance |
| FFT | Direct DFT for small sizes; analytic impulse, energy, and inverse checks for production windows |
| STFT | Identity reconstruction at empty, one-frame, short, exact-window, and irregular boundaries |
| Dynamics | Curve/knee boundaries, stereo linking, peak ceiling, state invariance under unequal block splits |
| Repair | Stationary noise attenuation and SNR against a known clean synthetic signal; isolated-click and smooth-signal checks |
| Source concurrency | Mutation and restoration with mtime reset must still invalidate the source |
| Native ABI | Python `os.fstat` comparison, nanosecond fields, buffer canaries, bad and nonregular descriptors |
| Publication | New destination ownership, dangling symlink rejection, no replacement, manifest shape, dimension checks |
| Cancellation | Wait for a real stage, send SIGINT/SIGTERM, require exit 130/143, source preservation, and no stage/destination |
| Review | Node arithmetic, decimal marker regression, HTML parser checks with hostile marker text, relative audio and offline resources |
| Examples | Fresh synthetic demo and every shipped `.mur` document, then verified bundles |
| Repository | Local documentation links, plain text punctuation rule, and offline asset boundaries |

The Scheme suite currently contains 72 cases and 34,840 assertions per run.
Every case runs in both interpreted and compiled modes. Assertion counts include loops over
samples, phases, and point sets. They are not a line-coverage percentage or a
claim to enumerate every possible input.

## Malformed input campaign

The deterministic seed is `20261021`. The campaign covers 205 truncated or mutated
WAV inputs, 91 malformed project inputs, and seven malformed manifests. Accepted
mutations must still produce dimension-valid inspection JSON; rejected cases
must return expected errors rather than internal exit 70.

The corpus includes invalid UTF-8, reader-evaluation notation, cyclic notation,
large node counts, excessive nesting and strings, zero denominators, empty
manifest entries, path traversal names, and inconsistent RIFF fields. This is a
bounded regression campaign, not coverage-guided fuzzing or a security proof.

## Whole-publication noninterference

Each privacy pair changes all finite PCM values inside a forbidden native source
interval while leaving outside samples fixed. Two repeated and overlapping clips
reference the source. The project resamples from 8 kHz to 12 kHz and uses either
streaming dynamics or spectral repair plus normalization.

The check requires equal file sets and exact byte equality for every file,
including review HTML, receipt, and manifest. It also searches for the original
raw input fingerprint in every artifact. No fields are normalized away.

The unmasked-change control must produce different audio. Without that control,
a renderer returning constant silence or a comparison accidentally reading the
same output twice could pass a privacy check for the wrong reason.

## Independent signal observations

Observed locally on macOS arm64, using exported float32 samples for resampling:

| Probe | Observation |
| --- | --- |
| 50 Hz, 48 kHz to 8 kHz | Maximum absolute error about 9.47e-6 |
| 440 Hz | About 8.11e-6 |
| 1000 Hz | About 3.37e-6 |
| 3000 Hz | About 3.28e-5 |
| 6000 Hz stopband | RMS about 2.53e-6 |
| 9000 Hz stopband | RMS about 1.71e-6 |
| Frozen stationary-noise profile | SNR improvement about 6.42 dB in the declared synthetic region |

Input tones are quantized PCM16, so those observations include input
quantization. The noise trial has a known synthetic clean signal and a stationary
uniform noise draw. Its SNR does not predict speech intelligibility or performance
on changing real-world noise. Raw values are reproduced in `build/signals.json`.

## Publication benchmark

The script measures fresh CLI processes, including source hashing, sanitized
identity, rendering, encoded analysis, HTML generation, artifact hashing,
verification, and directory publication. Filesystem cache is warm and uncontrolled.
Each case renders two seconds into stereo, with three consecutive runs. It is
not an isolated FFT benchmark or a real-time scheduling claim.

An exploratory local run on macOS 26.7.2 arm64 observed:

| Case | Median wall time | Output frames per second |
| --- | --- | --- |
| Native 8 kHz streaming | 0.283 s | 56,455 |
| 44.1 kHz to 48 kHz with filtering/dynamics | 1.552 s | 61,858 |
| 8 kHz spectral repair | 0.374 s | 42,753 |

The maximum child RSS across that run was about 31.7 MiB. That is an OS high-water
observation across these small cases, not a memory bound for long sessions.
`make bench` emits each sample, host context, source digest, and scope in
`build/benchmark.json`; rerun it on the device being evaluated.

## Browser verification

The synthetic exported desk was exercised in an actual browser: playback,
marker seeking, exact frame display, typed selection, patch download, CLI patch
application, rendering, and bundle verification. Browser logs contained no
warnings or errors at the checked state. Screenshots are in
[the full desk view](media/desk-full.jpg).

Browser automation used an in-memory loopback HTTP server exposing only generated
export files, with byte-range support for media seeking. The embedded test browser
blocked file URLs, so direct file-mode playback was not independently automated.
The product itself emits relative-file HTML and does not need that test server.
The normal PCM16 WAV can also be opened directly in a local audio player.

## CI and raw artifacts

The workflow runs on `ubuntu-24.04` and `macos-15` with pinned action revisions.
It runs the same `make verify` target and uploads raw JSON reports even when a
job fails. A badge or receipt should be read alongside the actual job status and
source digest, not treated as proof of a stronger claim.

Important generated files:

- `source-manifest.json`: every behavioral source/test file and its SHA-256.
- `scheme-tests.json`, `scheme-compiled-tests.json`: separate interpreted and compiled case, assertion, and failure counts.
- `acceptance.json`: byte-level privacy artifacts for all six pairs.
- `malformed.json`, `signals.json`, `native-abi.json`, `identity.json`: corpus, numeric, and canonical identity results.
- `commands.json`, `review-tests.json`, `review-html.json`: product boundaries.
- `examples.json`, `interrupt.json`, `structure.json`: end-to-end and repository checks.
- `verification.json`: host/toolchain context and report hashes after the final source comparison.
- `source-accounting.json`: source size by language and role; generated audio and build products excluded.

## Remaining validation boundaries

No test run proves zero bugs. There is no production recording corpus, perceptual
speech-quality evaluation, automatic transcription audit, hostile-filesystem
model, power-loss durability campaign, real-time deadline test, or formal
noninterference proof. Those are not silently inferred from the deterministic
checks. The supported claims are the implemented contracts and the raw evidence
above.
