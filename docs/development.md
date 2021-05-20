# Developer guide

## Toolchain

The product requires Guile 3.0, Make, and a C11 compiler on macOS or Linux with
an exclusive rename API. The native code is a small filesystem timestamp adapter.
There are no third-party Scheme modules or native audio dependencies.

macOS:

```sh
xcode-select --install   # only if Command Line Tools are absent
brew install guile
make
```

Debian or Ubuntu:

```sh
sudo apt-get update
sudo apt-get install guile-3.0 make gcc
make
```

Full verification additionally needs Python 3.10 or newer and Node 18 or newer.
The Python and JavaScript checks use their standard libraries. There is no pip
install, npm install, lockfile resolution, or network access during verification.

## Build products

`make` compiles the timestamp adapter into `.cache/native/fingerprint.so` and
Scheme modules into `.cache/compiled/`. The `.so` suffix is used on both supported
platforms; the macOS binary is built with `-dynamiclib`.

The launcher finds its repository using its own directory. It adds `src` to
Guile's module path and the repository's compiled cache to the compiled module
path. Automatic compilation is disabled. Compilation never needs to write a
Guile cache in the user's home directory.

Invoke `bin/murmur` from the checkout or by its absolute path. A package install
layout and symlink-based launcher installation are not provided. `GUILE=...` can
select a different Guile executable. Make also accepts `CC=...`.

```sh
make build       # native adapter and all Scheme modules
make test        # native adapter plus Scheme unit/property/integration cases
make check       # compile every module, then Scheme suite
make verify      # source-bound full acceptance battery
make bench       # three complete-publication performance cases
make accounting  # physical source counts by language and role
make demo        # create a synthetic session, or verify its existing bundle
make clean       # remove compiler products, retain generated recordings
```

A previously generated `build/demo` is verified rather than overwritten. To
create another fresh session, use `bin/murmur demo build/another-session`.

## Read the code in this order

1. [Error boundary](../src/murmur/error.scm),
   [clocks](../src/murmur/clock.scm), and
   [audio buffers](../src/murmur/buffer.scm).
2. [Data grammar](../src/murmur/data.scm),
   [project parser](../src/murmur/project/parse.scm), and
   [binding](../src/murmur/project/compile.scm).
3. [Redaction](../src/murmur/redact.scm),
   [streaming source cache](../src/murmur/wave/stream.scm), and
   [resampling](../src/murmur/dsp/resample.scm).
4. [Mixer](../src/murmur/mix.scm) and
   [effect registry](../src/murmur/effects.scm).
5. [Render transaction](../src/murmur/render.scm),
   [bundle verification](../src/murmur/bundle.scm), and
   [public source identity](../src/murmur/source-hash.scm).
6. [Independent acceptance](../tests/acceptance.py) and
   [defect regressions](defects.md).

Small modules expose the representation boundary they own. A decoded native
buffer and an output-clock buffer use the same audio record, but their ownership
and allowed producers differ. Do not bypass the source reader when adding a
sampler or a preview path.

## Add a streaming effect

Add a strict schema entry in `effects.scm`, validate every parameter, and build a
factory returning a fresh block processor. A processor receives consecutive
planar buffers of a fixed rate and channel count. It returns the processed buffer
and preserves any required state across calls.

Keep channel-linked state outside the channel loop. Give every time constant an
explicit sample-clock definition. Do not use elapsed wall time, a global random
stream, or a counter restarted on each block.

Verify an analytic or independent reference, then partition the same signal into
unequal blocks and require identical encoded samples. Include empty blocks and
initial/final transient behavior when those affect the contract. Add the effect
to a whole-publication privacy pair as well as its local numerical tests.

## Add an offline effect

Declare the effect offline in the registry. Its factory must accept the complete
sanitized output mix and preserve rate, channels, and frame count. Check its
aggregate temporary-buffer requirement before allocation. A spectral effect may
use `stft-process`, which handles boundary extension and squared-window
normalization.

The current pipeline has no latency-compensation protocol and no tail extension.
An effect that changes output duration needs a new explicit scheduling contract;
it cannot quietly append samples or shift the meaning of output markers.

## Add a format

Keep container scanning separate from PCM decoding. Scanner offsets and lengths
must be exact integers with checked bounds. A format must define block alignment,
sample normalization, finite-value handling, and empty-file behavior.

A new input format must pass through the same native-coordinate redaction and
canonical sanitized identity path. A new export format must have an independent
decoder in acceptance checks and must omit source metadata by construction.

## Error and ownership rules

Use `fail` or `ensure` for expected input, budget, and I/O-contract failures.
Internal Scheme exceptions remain distinguishable as exit 70. Do not convert an
unexpected programming error into a successful partial render.

Each opened port has one owning dynamic-wind or call-with-file scope. The render
transaction owns exactly one newly created staging tree. Cleanup may recurse
only within that owned tree. All input source paths remain read-only.

The executable entry point delivers SIGINT and SIGTERM as cancellation
exceptions so cleanup runs before exiting. A library user chooses its own signal
policy. SIGKILL, machine crashes, and hostile filesystem behavior are outside
normal unwind guarantees.

## Verification workflow

Write a reproducer before repairing a behavioral defect. Keep the regression and
add its observed failure and fix to [the ledger](defects.md). Syntax and module
errors are caught by compiling every production module, not just modules reached
by a particular happy-path test.

`make verify` captures a source manifest before building. It deletes only known
previous generated check reports, runs the required suites, and compares the
source manifest again before issuing `build/verification.json`. A source or test
change during the run prevents an acceptance receipt.

The manifest covers implementation, native adapter, tests, build/check scripts,
CI configuration, examples, Makefile, and ignore rules. Documentation prose and
screenshots are outside the behavioral source digest. Raw check reports are
preserved beside the receipt and uploaded by CI even when a job fails.

## Style and changes

Use comments to explain numerical conventions, ordering constraints, resource
ownership, and failure boundaries. Keep public documentation free of unsupported
claims and performance extrapolation. State where a measurement came from and
what the test does not establish.

The existing code uses two-space Scheme indentation, explicit module imports,
SRFI-9 records for owned representations, and homogeneous numeric vectors in
sample loops. Browser assets have no package dependencies. Python check scripts
remain separate from the Scheme implementation and do not import its algorithms.
