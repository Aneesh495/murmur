# Command reference

Every command works without a network service or audio device. Paths with spaces
must be quoted by the shell. Commands return zero on success, one for expected
input/runtime failures, two for usage failures, and 70 for an internal error.
The executable handles SIGINT with exit 130 and SIGTERM with exit 143.

## Start a recording

```sh
bin/murmur init recording.wav edit.mur
```

Writes a new document with a raw source pin, a full-length clip, small edge fades,
a high-pass filter, and a sample limiter. Mono input creates mono output. The
source path stays relative when it is beside the new document; otherwise the
starter stores its canonical absolute path. Edit the data file before rendering.
An existing document is never overwritten.

## Render and review

```sh
bin/murmur render edit.mur build/review
```

The output parent must exist, and the destination must be new. Open
`build/review/review.html` alongside the other generated files. The desk plays only
`audio.wav`, displays the encoded waveform, maps active clips, and lists source
redactions and output markers.

Options:

| Option | Meaning |
| --- | --- |
| `--block-size N` | 1 through 65536 frames, default 4096 |
| `--bits 16`, `24`, `32` | Signed integer PCM, default 16 |
| `--float` | IEEE float, default width 32 |
| `--float --bits 64` | IEEE double output |
| `--no-dither` | Disable indexed TPDF dither for integer encoding |

Options do not depend on order. Duplicate and unknown options fail. Float output
with an explicitly selected integer-only width fails rather than silently
changing the width.

The renderer rejects nonfinite output and values above full scale. Add an
explicit limiter or reduce clip gains. Final measurements are recomputed from
the encoded WAV.

## Inspect, analyze, and explain

```sh
bin/murmur inspect recording.wav
bin/murmur analyze recording.wav
bin/murmur plan edit.mur
bin/murmur explain edit.mur 61200
```

`inspect` prints format, dimensions, and chunk names/sizes. `analyze` prints JSON
measurements, bounded waveform buckets, and channel-safe silence suggestions.
These commands inspect the file you named, so naming an original recording means
you are asking to inspect that original.

`plan` binds and validates a project and prints the path-free semantic edit map.
`explain` prints the selected output frame's pre-effect contributors, exact native
position, conservative interpolation stencil, and whether the center is masked.
It does not invert stateful master effects.

## Add redactions from the desk

Select a waveform range with Shift + drag, or type start and end seconds and
choose **Set selection**. Choose a replacement mode and download the source
patch. Apply it locally:

```sh
bin/murmur apply-patch edit.mur patch.mur revised.mur
bin/murmur render revised.mur build/revised-review
```

The new document must be beside its original. Both the semantic plan and every
sanitized source identity must match the patch. Conflicting redaction settings
fail before writing the new project.

## Import interval labels

```sh
bin/murmur labels edit.mur field labels.tsv mute > patch.mur
```

The source name must match the document. The optional replacement is `mute`,
`tone`, or `noise`, defaulting to mute. The parser reads tab-separated start/end
seconds and discards label text. Apply the resulting patch as above.

## Verify an export

```sh
bin/murmur verify build/review
```

Checks manifest structure, the exact flat file set, regular file types, every
artifact hash, WAV structure, and rate/channel/frame dimensions. It rejects
unlisted extra files. It does not execute the original edit document or establish
that a third party's manifest was honest.

## Demo and environment

```sh
bin/murmur demo build/new-demo
bin/murmur doctor
bin/murmur version
```

The demo creates two synthetic inputs, a full project, a label file, and a review
bundle. Share only its `review` directory. `doctor` reports the Guile version,
host, and tool requirements; it is an environment summary, not a substitute for
`make verify`.
