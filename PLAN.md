# Murmur implementation plan

## Product

An offline workbench for repairing and publishing recordings. A recording becomes
an explicit edit document. The renderer removes marked source samples before any
interpolation, splicing, mixing, filtering, or analysis. A portable review bundle
contains the rendered recording, waveform, edit map, and a receipt.

The useful question is simple: can I cut an interview, remove a private phrase,
repair the recording, and inspect exactly what will leave my machine?

## Implementation sequence

1. Foundation: typed errors, exact clocks, interval algebra, buffers, binary I/O,
   bounded data parser, structured diagnostics, and a test harness.
2. Audio I/O: strict RIFF scanning, integer and float PCM, metadata inspection,
   deterministic quantization, streamed block readers and writers.
3. Edit language: versioned data-only documents, source and clip validation,
   source redaction normalization, automation, edit maps, resource budgets.
4. Engine: redaction before resampling, windowed-sinc resampling, rational clip
   scheduling, channel routing, overlap mixing, fades, and safe output staging.
5. Repair: biquad filters, DC removal, dynamics, click repair, FFT/STFT,
   conservative spectral subtraction, analysis, and silence suggestions.
6. Product: command line, synthetic demonstration, standalone review interface,
   marker import/export, presets, project inspection, receipt verification.
7. Verification: analytic signal oracles, independent Python WAV checks,
   malformed-input mutation, privacy negative controls, block-size invariance,
   whole-command tests, fresh-clone reproduction, and hosted CI.
8. Documentation and publication: architecture diagrams, numerical contracts,
   command reference, developer guide, failure catalogue, measured limits,
   source accounting, reproducible examples, and a documented release.

## Acceptance requirements

- Scheme owns the audio algorithms, edit compiler, renderer, CLI, and reporting.
- A fresh clone needs Guile 3, Make, and a C11 compiler. Python 3 is used for independent checks.
- No datasets, credentials, network services, proprietary SDKs, or package
  registries are required by the normal workflow.
- Redaction tests change only forbidden input samples and compare every output
  sample. Changes must not affect output, analysis, preview, or render receipts
  except the separately identified source-file digest.
- Input files are never modified. New outputs use a private staging directory
  and refuse existing destinations.
- Invalid documents, nonfinite samples, ambiguous WAV layouts, and resource
  budget overruns fail with a diagnostic and nonzero exit status.
- Every discovered defect gets a failing regression before the repair.
- Performance and supported formats are reported from actual runs. No claim of
  universal correctness or unmeasured production capacity.
- Source size is measured by language and role. Generated fixtures and build products
  are accounted for separately from implementation.

## Design decisions

- Offline rendering, not live audio. Scheduling must be independent of wall time.
- Source-coordinate redactions, not output-coordinate muting. A repeated clip
  cannot accidentally reintroduce a marked phrase.
- Exact rational seconds in the edit document. Conservative floor/ceiling at
  source boundaries; integral frames at the output boundary.
- A small data grammar, not executable Scheme project files.
- Explicit finite resource budgets and bounded chunk I/O. Whole-session effects
  may use bounded buffers, with those limits stated before rendering.
- PCM WAV first. Compressed codecs belong behind an explicit external import
  step rather than a hidden codec dependency.

## References

- [GNU Guile manual](https://www.gnu.org/software/guile/manual/)
- [RIFF WAVE format notes and original specification links](https://www-mmsp.ece.mcgill.ca/Documents/AudioFormats/WAVE/WAVE.html)
- [HTML media elements](https://html.spec.whatwg.org/multipage/media.html)
