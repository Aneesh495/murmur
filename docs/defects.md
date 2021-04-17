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
