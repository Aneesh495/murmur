# Defect ledger

Each behavioral defect found during development is tied to a regression that
failed before its repair. Syntax and module-load errors are caught by the suite's
mandatory load of every test and its referenced implementation modules.

## R001: dynamically resolved record accessor

The initial source-redaction test failed with `Wrong type to apply` because a
Guile SRFI-9 accessor obtained through `module-ref` was a syntax transformer.
Importing the buffer interface directly allows Guile to expand the accessor.
`replacement noninterference` failed before the repair and now exercises all
three replacement modes over every sample in both channels.

## R002: compressor upper knee boundary

`soft-knee compression curve` observed zero reduction exactly at the upper knee
instead of the linear branch's -2 dB. Both adjacent comparisons were strict.
The linear branch now includes the upper boundary. The three knee regions and
both boundary values are retained in the curve regression.

## R003: browser playhead off by one at decimal markers

Browser verification of the 2.550-second marker at 24000 Hz displayed frame
61199. The binary floating media clock fell just below the integral boundary
before `floor`. Displayed media frames now round to nearest, consistent with the
edit clock. The observed browser failure is retained as the `frameAt(2.55, 24000,
184800) == 61200` regression. Source selection boundaries still expand outwards.

## R004: raw source fingerprints escaped into public review artifacts

The independent whole-bundle regression changed only forbidden input samples.
Audio, edit maps, and measurements were identical, but `review.html`,
`receipt.json`, and `manifest.mur` changed because they contained raw input
fingerprints. This violated the intended publication boundary and could support
small-domain guesses about removed content.

Public source identities now hash a domain-separated canonical representation
of sanitized native samples. Raw byte digests remain local for pinning and
concurrent-change checks. Patches bind to sanitized identities plus the semantic
plan. The regression compares every byte of every publication artifact, with no
excluded fields or normalized-away failures.

## R005: guard expansion at the one-day timestamp limit

A source ending at 86400 seconds could not redact its final sample with a guard.
The internal expanded endpoint was incorrectly revalidated as a user timestamp.
Expansion now uses the already validated exact clock directly, then clamps to
source frames. The regression uses a small 1 Hz WAV to exercise the full day
without allocating a day of conventional-rate audio.

## R006: malformed empty manifest entry

`(file)` reached `car` before its shape was checked, producing an internal error.
Manifest entry shape now precedes all key extraction. The empty-entry regression
fails with a structured bundle diagnostic.

## R007: changed-and-restored input escaped the final hash check

A regression modified a bound source, restored identical bytes, reset its mtime,
and observed that the final raw hash still passed. Bytes read during the
intermediate revision could have produced a mixed render. Binding now captures
inode, device, size, mtime, and ctime with nanosecond fields. The reader checks
that fingerprint around every page read; binding and final validation check it
around hashing too. This detects ordinary concurrent edits, including reverted
ones. It is not snapshot isolation against a privileged hostile filesystem.

Guile 3.0.11 on the tested macOS host returned zero nanosecond fields. The first
Scheme-only fingerprint still failed this regression. A small C adapter now
uses the platform's actual `fstat` timestamps behind a fixed seven-word ABI.

## R008: marker ties used a different rounding rule

A marker at half of the first 8000 Hz frame appeared at frame zero in the edit
map, while the edit clock specifies ties toward the future. The serializer had
used generic tie-to-even `round`. It now uses `seconds->frame`, and the retained
half-frame regression requires frame one in the published marker map.

## R009: SIGINT left the private staging directory

A real-process regression waited until the output stage existed, then sent
SIGINT. The process terminated with the normal signal status but did not unwind
Scheme cleanup, leaving the owned stage behind. The executable entry point now
turns SIGINT and SIGTERM into caught cancellation exceptions. Dynamic-wind closes
ports and deletes the stage before exits 130 or 143. The regression checks the
exit status, absence of both destination and stage, and unchanged source bytes.

## R010: manifest symlinks passed bundle verification

The whole-command regression moved a valid manifest outside its bundle and
replaced it with a symlink. Verification incorrectly succeeded even though the
flat bundle contract requires regular files. The manifest now receives an lstat
regular-file check before parsing, just like artifact entries receive before
hashing. This also refuses a FIFO manifest before opening it.

The source-reversion regression was also strengthened to restore mtime with its
exact nanoseconds and assert that restoration. Its failure must therefore depend
on the retained ctime/identity evidence, not a rounded mtime difference.

## R011: public identities inherited replacement math-library rounding

The first sanitized identity hashed generated tone/noise values as float64.
Source patch bindings therefore depended on platform sin/cos low bits even when
original samples and edit settings were the same. An independent Python digest
regression exposed the mismatch with the intended portable canonical form.
Masked positions now serialize as zero, while normalized mask settings and the
relevant noise seed serialize separately. Actual rendered audio keeps its own
artifact hash. No public identity needs transcendental DSP arithmetic.

## R012: compiled Linux wide-word conversion

The first Ubuntu 24.04 job passed the interpreted Scheme suite, then failed the
compiled CLI at source binding with an unsigned conversion of a negative wide
integer. Splitting the noise mixer's products into 16-bit limbs was insufficient:
the new compiled suite isolated failures in SHA-256, including known answers.
Its rotations shifted whole words before discarding the unused high bits. They
now mask the wrapping low bits first, keeping rotation intermediates within 32
bits. Boundary rotations are checked against quotient/remainder arithmetic;
noise products are checked against arbitrary-precision multiplication.

The full Scheme suite runs in both interpreted and compiled modes, with separate
reports, so compiled-only failures cannot hide behind interpreter tests.
