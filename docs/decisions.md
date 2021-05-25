# Design decisions

## 001: source coordinates own removal

A mute on the output clock can leave a phrase in a repeated clip or in a
resampler/filter neighborhood. Each source therefore owns a normalized mask set.
Readers sanitize native samples before exposing them to any downstream consumer.
The same source abstraction serves every clip.

Consequence: an output selection becomes a conservative patch back to all active
source contributors. It is not an inverse of master effects. The desk exposes
that distinction rather than inventing a precise causal explanation of a final
filtered sample.

## 002: exact clocks, floating samples

Scheme rationals keep decimal edit endpoints and rate ratios exact. Sample data
uses homogeneous float64 vectors, which are practical for the numerical loops.
The split is intentional: time decisions need exact boundaries; DSP needs finite
numeric tolerances and declared normalization.

The data grammar is separate from Scheme evaluation. An edit document can look
like a small program without receiving filesystem, process, or evaluator access.

## 003: public identities follow the privacy boundary

A raw source hash can change when only removed bytes change. Publishing it also
provides a potential guessing oracle for a small unknown input region. The public
identity therefore hashes sanitized native samples behind a versioned domain
prefix. Local raw hashes still pin originals and check source changes.

The first whole-bundle test exposed this distinction. That failure, including the
specific affected publication files, is retained in the defect ledger.

## 004: two explicit execution modes

Ordinary mixing and filters can stream through small buffers. Noise profiling,
STFT overlap-add, mean removal, and peak normalization need a wider view. The
first version uses a bounded full mix for these effects instead of hiding a
latency-compensating streaming scheduler inside each processor.

Consequence: offline effects have a lower duration limit. Their input and output
clock remain identical, so markers and clip-time selection do not shift. A future
streaming spectral path must preserve that contract with explicit latency and
flush behavior.

## 005: the review desk receives publication data only

The browser plays the rendered WAV and displays the encoded waveform. It never
loads originals, performs hidden repair, or changes a render in place. A downloaded
patch is validated again by the CLI and produces a new document.

Consequence: the browser has no backend, filesystem authority, service credentials,
or package runtime. Assets are inlined so the review directory can travel as a
small flat bundle.

## 006: exclusive publication is a platform primitive

Checking that a destination does not exist and then using ordinary rename leaves
a race. The implementation calls exclusive rename on supported platforms. There
is no permissive fallback that might replace a newly created destination.

A separate metadata adapter exists because the tested Guile macOS stat binding
lost nanoseconds. A fixed seven-word C ABI is smaller and easier to validate than
encoding platform `struct stat` layouts in Scheme. Audio algorithms remain in
Scheme, and Python checks the ABI independently.

## 007: evidence tests the final bytes

A float-buffer test cannot establish what quantization wrote. A unit-level privacy
check cannot establish what a receipt leaked. Acceptance therefore decodes
published audio independently and compares complete export directories across
forbidden input changes.

Raw reports bind to a frozen source manifest. Tests use controls that should
change output and inputs that should be rejected. Performance is measured through
the actual publication command, including startup and report generation.

## 008: keep format and product scope explicit

PCM WAV gives the engine a fully inspectable container and sample domain. External
compressed-codec conversion is an explicit preprocessing choice. There is no
silent subprocess or network fallback.

The first version edits and repairs audio offline. It does not promise a device
callback, plugin ecosystem, perceptual restoration, transcription, or loudness
compliance. Those would need their own product and verification contracts.
