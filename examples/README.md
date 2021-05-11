# Examples

All inputs are generated locally by `make demo`. There are no downloads or
recorded voices. The source signal contains harmonic pulses, a synthetic chirp,
hum, noise, and two isolated clicks.

```sh
make demo
mkdir -p build/examples
bin/murmur render examples/interview.mur build/examples/interview
bin/murmur render examples/restoration.mur build/examples/restoration
bin/murmur render examples/overlap.mur build/examples/overlap
```

- [interview.mur](interview.mur): source redaction, two takes, resampling,
  equal-power mono placement, compression, and limiting. Streams in blocks.
- [restoration.mur](restoration.mur): notch filtering, click repair, a frozen noise
  profile, and peak normalization. Uses the bounded full-buffer path.
- [overlap.mur](overlap.mur): repeated source material and a stereo bed. The same
  redaction is retained in both occurrences of the marked source phrase.

Open each generated `review.html`. Keep the whole output directory together.
Commands refuse an existing destination. For another render, choose a new output
name; existing bundles can be checked with `bin/murmur verify DIRECTORY`.
