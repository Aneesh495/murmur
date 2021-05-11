# Edit document reference

A `.mur` file is UTF-8 data with one top-level form. Semicolon comments run to the
end of a line. The grammar accepts lists, lowercase symbols, strings, signed
exact decimals, integers, and rational numbers. It does not evaluate Scheme.

```scheme
(murmur
  (version 1)
  (rate 48000)
  (channels 2)
  (seed 7)
  (source field (path "field.wav"))
  (redact field (from "00:12.350") (to "00:13.900")
          (mode tone) (guard 0.02) (hz 1000) (level-db -24))
  (clip first (source field) (from 0) (to 30) (at 0)
        (gain-db -3) (pan 0) (fade-in 0.02) (fade-out 0.04))
  (effect highpass (hz 80))
  (effect limit (ceiling-db -1))
  (marker (at 0) (label "Start")))
```

The example requires a source at least 30 seconds long. For runnable generated
inputs, use the files under [examples](../examples/README.md).

## Project fields

| Field | Default | Constraint |
| --- | --- | --- |
| `version` | Required | Exactly `1` |
| `rate` | `48000` | Integral 8000 to 384000 Hz |
| `channels` | `2` | Mono `1` or stereo `2` |
| `seed` | `7` | Integral 0 through 2^32 - 1 |
| `source` | Required | One to 64 distinct source identifiers |
| `clip` | Required | One to 4096 distinct clip identifiers |
| `redact` | None | Up to 4096 source intervals |
| `effect` | None | Up to 32 effects, in written order |
| `marker` | None | Output time and a label of at most 200 characters |

Unknown or duplicate scalar fields fail. Source, clip, redaction, effect, and
marker declarations can repeat as described above. Identifiers are lowercase
symbols from the data grammar, at most 64 characters. Source and clip names must
be unique in their own namespaces.

## Source

```scheme
(source field
  (path "recordings/day-one.wav")
  (sha256 "64-lowercase-hex-digits-go-here"))
```

The optional `sha256` shown schematically must be replaced by a real 64-digit
hexadecimal digest. `murmur init` creates the pin automatically. This is a local
raw-file identity; it is not copied to the public edit map or receipt.

Relative source paths resolve against the edit document, including when the CLI
is launched from another directory. Absolute paths are allowed. Only regular
files are accepted. The timeline routes mono or stereo input. The lower-level
WAV codec can decode up to eight channels.

## Times

Times accept exact numbers such as `1/3`, exact decimal literals such as `0.125`,
or strings such as `"01:12.350"` and `"1:02:03.5"`. Only the seconds component may
be fractional. Minutes and seconds inside a multi-component timestamp must be
below 60. A user timestamp lies between zero and one day.

Decimals become rational values directly. They are never first parsed as binary
floating-point numbers. Clip endpoints and placement use nearest frame with ties
toward the future. Redaction endpoints round outward. Resampled clip duration is
rounded upward to include its final output sample.

## Redaction

```scheme
(redact field (from 12.35) (to 13.9) (mode mute) (guard 0.02))
```

| Parameter | Default | Constraint |
| --- | --- | --- |
| `from`, `to` | Required | Positive half-open interval inside source duration |
| `mode` | `mute` | `mute`, `tone`, or `noise` |
| `guard` | `0.01` | Zero to one second |
| `level-db` | `-18` | -96 to -3 dBFS replacement amplitude |
| `hz` | `1000` | 20 to 16000 Hz; tone must be below native Nyquist |

All channels are redacted. Compatible overlapping or adjacent intervals merge.
Overlapping intervals with different replacement settings fail. Redactions are
source-wide: repeating a clip cannot reveal the same phrase again.

A replacement's five-millisecond edge window uses only replacement samples.
Even during the edge ramp, original masked samples do not contribute.

## Clip

```scheme
(clip first (source field) (from 10) (to 20) (at 5)
      (gain-db -6) (pan -0.25) (fade-in 0.05) (fade-out 0.1))
```

`source` and `to` are required. `from` and `at` default to zero. Gain defaults to
zero dB and accepts -96 to +24 dB. Pan defaults to zero and accepts -1 to +1.
Fades default to zero; their combined duration cannot exceed the selected clip.
Rounded fades are checked again on the output clock.

For mono entering stereo, pan uses equal-power gains. For stereo entering stereo,
pan is a balance control that attenuates the opposite side. Stereo entering mono
uses the arithmetic mean of the two channels. Mono output requires zero pan.
Overlapping clips sum before master effects.

## Effects

All optional values below use the shown defaults. Parameters are checked before
render staging. Frequencies must also satisfy the current output Nyquist limit.

```scheme
(effect gain (db 0))
(effect highpass (hz 80) (q 0.7071067811865476))
(effect lowpass (hz 6000) (q 0.7071067811865476))
(effect notch (hz 60) (q 10))
(effect peak (hz 2000) (q 1) (gain-db 3))
(effect low-shelf (hz 180) (q 0.7071067811865476) (gain-db -3))
(effect high-shelf (hz 6000) (q 0.7071067811865476) (gain-db 2))
(effect compress (threshold-db -18) (ratio 3) (knee-db 6)
        (attack-ms 10) (release-ms 120) (makeup-db 0))
(effect gate (threshold-db -45) (hysteresis-db 6) (hold-ms 80)
        (attack-ms 5) (release-ms 120) (range-db -40))
(effect limit (ceiling-db -1) (release-ms 80))
(effect declick (threshold 0.15) (sensitivity 8) (radius 3))
(effect denoise (profile-from 0) (profile-to 0.5)
        (size 512) (strength 1.2) (floor-db -18) (smoothing 0.6))
(effect normalize (peak-db -1) (max-gain-db 18))
(effect remove-dc)
```

The seven filter types plus gain, compressor, gate, and limiter stream. `declick`,
`denoise`, `normalize`, and `remove-dc` request full-buffer execution. Effect order
is literal: a noise profile is measured after earlier effects in the chain.

A denoise profile must include a complete FFT window inside the rendered output.
Its coordinates are output seconds, not source seconds. Window size is a power
of two from 32 through 8192; hop is one quarter of that size. Select a passage
containing the noise you intend to suppress. There is no automatic speech model.

The limiter enforces a linked sample ceiling before encoding. It does not claim
intersample peak control. The renderer refuses over-full-scale output rather
than silently relying on encoder saturation.

## Patches and labels

The browser produces a `murmur-patch` document containing version, base plan hash,
sanitized source identities, and additional `redact` forms. Apply it with:

```sh
bin/murmur apply-patch edit.mur patch.mur revised.mur
```

`revised.mur` must be new and beside `edit.mur`. The CLI validates every resulting
redaction before writing it. Existing source pins and original edits remain.

Audacity-style tab-separated interval labels can produce the same patch format:

```sh
bin/murmur labels edit.mur field labels.tsv mute > patch.mur
```

Each nonempty line needs start seconds, a tab, and end seconds. Optional label
text is discarded. Point markers cannot become redactions. Blank lines and lines
starting with `#` are ignored.
