# Numerical contracts

The engine uses exact integers and rationals for clocks and double-precision
planar vectors for samples. This keeps edit decisions exact without pretending
that transcendental DSP arithmetic is bit-identical across every math library.

## Sampling conventions

Frame `n` is a simultaneous set of channel samples at time `n / rate`. Intervals
are half open. The last frame of a source with `N` frames is `N - 1`; its duration
is `N / rate`.

For a clip selecting integral native frames `[a,b)` and output rate `Fo` from
native rate `Fi`, the output length is:

```
ceil((b - a) * Fo / Fi)
```

Its local output frame `k` samples native position `a + k * Fi / Fo`. The integer
quotient and remainder are computed directly, rather than integrating a floating
phase accumulator. Seeking and changing output block size use the same position.

## Resampling kernel

The low-pass cutoff is `0.94 * min(1, Fo / Fi)` in native Nyquist-normalized units.
The support radius is `ceil(16 / cutoff)`. Each phase uses a sinc multiplied by a
Blackman window, then normalizes its finite weights to sum to one. This preserves
DC at every phase, including the bounded phase-table approximation.

For reduced output denominator at most 2048, every rational phase is precomputed.
Unusual coprime pairs use 256 phase intervals and interpolate adjacent normalized
weight vectors. Each table includes the endpoint needed for interpolation. A
32 MiB per-table limit and 64 MiB session table limit bound kernel allocations.

Equal-rate sampling bypasses the kernel and reads the exact native sample.
Outside a selected clip, the sampling closure extends the nearest selected edge
sample. No stencil reads outside `[a,b)`.

The independent signal suite measures passband error against analytically sampled
sines and checks suppression of 6 kHz and 9 kHz input when converting 48 kHz to
8 kHz. Measurements use float output so that the stopband is not hidden by 16-bit
quantization. See [verification](verification.md) for actual observed values.

## Pan and fades

For mono pan `p` in `[-1,1]`, gains are:

```
left  = cos((p + 1) * pi / 4)
right = sin((p + 1) * pi / 4)
```

Their squared sum is one. Stereo balance leaves the near side at one and uses a
cosine attenuation on the far side. Mono downmix is `(left + right) / 2`.

Edit fades are linear in amplitude. Two aligned copies with complementary linear
fades preserve amplitude. A fade of `L` frames reaches zero at the first sample;
the steady region begins at sample `L`. The final sample of a fade-out is zero.
Replacement windows use a raised cosine inside the masked interval only.

## Filters

Biquads use the RBJ formulas and normalize `a0` to one. Transposed direct form II
stores two state values per channel:

```
y  = b0*x + z1
z1 = b1*x - a1*y + z2
z2 = b2*x - a2*y
```

Coefficient design checks finite parameters and the second-order Schur
conditions on the normalized denominator. Tests check DC response, corner gain,
notch depth, state partition invariance, and rejection at Nyquist.

Shelf controls use the supplied Q through the same alpha convention as the
implementation; no separate shelf-slope parameter is exposed. Frequency, Q,
gain, and output rate are explicit in the edit document.

Reference: [W3C Audio EQ Cookbook](https://www.w3.org/TR/audio-eq-cookbook/).
The implementation is original Scheme code using those published equations.

## Dynamics

The compressor measures the maximum channel magnitude per frame, converts it to
dB, applies a quadratic soft-knee curve, and smooths gain reduction in dB. A
one-pole coefficient `exp(-1000 / (rate * milliseconds))` supplies attack and
release times. Its exact upper-knee boundary is covered by a regression.

The gate has separate open and close thresholds, a sample-counted hold, and
smoothed gain toward one or the configured closed attenuation. Both compressor
and gate share gain across channels to avoid independently moving the stereo
image.

The limiter attacks immediately. Its gain is the smaller of the current safe
gain and the release trajectory. Therefore the processed sample magnitude cannot
exceed its ceiling, apart from floating rounding. It has no lookahead, introduces
no latency, and does not constrain reconstructed analog intersample peaks.

## FFT and spectral reconstruction

The FFT is iterative radix two with precomputed bit reversal and split real and
imaginary twiddles. The forward transform is unnormalized. The inverse divides
by `N`. Known short transforms are checked against a direct DFT; production
window sizes are checked with an analytic shifted impulse, Parseval energy, and
inverse reconstruction.

The STFT uses periodic Hann windows and a dividing hop at most `N/2`. Processing
starts before frame zero with zero extension and continues until every right
boundary sample has overlap support. Analysis and synthesis both apply the
window. Each output frame divides by the accumulated squared windows. This
reconstructs first and final samples, including recordings shorter than a window.

Denoising uses the average periodogram of complete windows inside a frozen noise
profile. Per-bin target gain is the square root of a power subtraction ratio,
clamped to a configured floor. Temporal smoothing reduces abrupt gain changes.
The gain is mirrored across conjugate bins to preserve a real output. It is a
stationary-noise tool; changing noise and musical transients require listening.

Reference: Julius O. Smith's
[Spectral Audio Signal Processing](https://www.dsprelated.com/freebooks/sasp/).

## Click repair

For each interior sample, the detector compares it with the median of neighboring
samples excluding the center. A threshold based on both absolute difference and
neighbor median deviation identifies an isolated outlier. Replacement is the
mean of the immediately adjacent original sanitized samples. Detection does not
feed repaired samples back into later decisions.

The method repairs isolated impulses. It does not reconstruct clipped plateaus,
long dropouts, or prove that a percussion transient is an error. It is opt-in.

## Encoding

Input integer PCM is normalized by `2^(bits-1)`, with unsigned offset binary for
8-bit PCM. Floating input is finite and may exceed full scale during internal
processing. A render must reach a finite full-scale-bounded result before export.

Output integer PCM rounds to nearest with Scheme's tie-to-even rule, then
saturates to the asymmetric signed range. Optional TPDF dither subtracts two
uniform counter-derived values in units of one LSB. Coordinates include seed,
channel, and absolute output frame, so a new block does not restart the noise.
Dither is an audio generator, not cryptographic randomness.

Exports contain newly constructed format and data chunks, plus `fact` when
required for floating PCM. Original metadata is not copied. RIFF output above
its 32-bit container size is rejected; RF64 is not implemented.

## Measurements and reproducibility

Meters report sample peak, unweighted RMS, DC mean, crest factor, zero crossings,
and counts of decoded samples at or above magnitude one. The `clippedSamples`
field denotes that threshold count, not proof that a source was clipped. It is
asymmetric for integer PCM because positive full scale is below one. There is no
LUFS, EBU R128, dBTP, or speech-quality compliance claim.

Analysis runs on the encoded WAV, so it measures what was exported rather than
an earlier float buffer. Public waveform buckets cover every output frame and
include zero in their envelope range.

Within a fixed platform and toolchain, blocking does not affect edit positions,
noise coordinates, mixer results, or streaming effect state. Cross-platform
floating results are checked with tolerances; low bits may differ through `libm`.
