# Redaction and publication boundary

Murmur removes marked native source samples before they can enter resampling,
mixing, effect state, analysis, or a public source identity. Marking a source
region applies to every clip that references that source.

## The property being checked

Take two supported source recordings with the same rate, channels, frame count,
and samples outside the normalized masks. Let their forbidden samples differ
arbitrarily within the finite PCM domain. Both inputs must pass local binding
checks; an unchanged raw-file pin intentionally rejects any changed original.
Render the same semantic project on
the same platform and toolchain.

Every publication file must be identical:

- `audio.wav`
- `analysis.json`
- `plan.json`
- `review.html`
- `receipt.json`
- `manifest.mur`

The independent acceptance suite compares all bytes, with no excluded fields.
It exercises mute, tone, and noise replacement through streaming and spectral
chains, repeated clips, overlap, fades, and sample-rate conversion. An additional
control changes an unmasked sample and requires output to change.

That is a tested engineering property for the implemented paths, not a formal
proof for every program execution. A bug catalogue records the failures that led
to stronger checks, including a raw-fingerprint leak. See [defects](defects.md).

## Coordinate rules

A redaction interval is half open in source seconds. Its start rounds down and
its end rounds up on the source clock. Guard time expands those endpoints before
clamping to the source. This can remove a neighboring sample at a fractional
boundary. It cannot retain a sample that lies inside the stated interval.

Fades inside a replacement region use only the replacement signal. They never
crossfade original samples back into the mask. A tone is phase-indexed by native
frame; noise is derived from seed, source alias, channel, and frame. Neither uses
the removed values to choose its sound.

The clip's normal gain and pan happen later. Mastering filters can spread the
replacement sound outside the visually marked output interval. They cannot
spread the original forbidden samples because those samples never enter their
state.

## What is intentionally public

The publication bundle contains rendered audio, source aliases, source durations,
redaction locations and modes, clip placements, effect settings, user-entered
markers, a seed, and sanitized source fingerprints.

A source alias or marker can itself contain identifying text. Murmur does not
claim to recognize sensitive labels or infer which unmarked phrase should have
been removed. Review those values before sharing a bundle.

The current public identity hashes the complete native source with masked
positions replaced by canonical zero, plus the normalized replacement recipe.
It includes
unmarked samples that a clip may not use. It discloses a fingerprint of that
representation. It does not publish those unused samples, and forbidden sample
changes cannot alter it. This is an integrity mechanism, not confidentiality for
all unmarked content.

Input filenames, canonical filesystem paths, original metadata chunk bodies,
raw source byte hashes, and imported label text are absent from public artifacts.
Raw file pins remain in local `.mur` documents when requested by `init`.

## Review patches

A patch includes the semantic plan digest and one sanitized identity for every
source. It cannot silently apply to another edit plan or to changed unmasked
source content. Applying it creates a new document beside the original, retaining
the meaning of relative source paths.

A change confined to an already forbidden region intentionally does not invalidate
a public patch identity. Those bytes have no effect on the existing publication.
Local optional raw source pins can still reject a changed original file.

Browser selection maps output clip time back to each contributing source and
rounds conservatively. Overlapping source intervals are merged. It does not
invert filter tails, compressor history, or spectral windows. The desk labels
that limitation; use the source coordinate editor when inspecting such cases.

## Filesystem assumptions

Sources must be regular files on a normal local filesystem. Binding, page reads,
and final checks compare device, inode, length, and nanosecond mtime/ctime. A
changed-and-restored file fails even if its raw hash returns to its original
value. The C adapter is necessary because a tested Guile macOS build discarded
subsecond `stat` fields.

This detects ordinary concurrent writes. It does not establish snapshot isolation
against a privileged attacker who can forge metadata or control filesystem
responses. Copies made before editing remain the straightforward way to isolate
recordings from another editor.

Publication refuses an existing directory, file, or symlink. Exclusive rename
prevents replacing a destination that appears after the initial check. Private
staging directories use mode 0700. Normal error cleanup only traverses the
newly owned staging tree and does not follow symlinks.

## Parser and HTML boundaries

Project, patch, and manifest parsing uses a bounded custom grammar. It does not
invoke Guile's reader or evaluator. Reader extensions, cyclic notation, dotted
pairs, executable forms, and multiple top-level documents are rejected.

The review desk receives JSON with `<`, `>`, `&`, line separators, and control
characters escaped. User-facing values are inserted with `textContent`. Assets
are inlined, the WAV path is fixed, and the content policy blocks connection
requests and remote dependencies. There are no network calls in the application.

## Outside the guarantee

Murmur does not recognize speech, locate private phrases automatically, remove
unmarked room reflections already mixed into other samples, secure the user's
operating system, erase the original source, encrypt bundles, or authenticate
manifest authorship. WAV input must be finite; unsupported and nonfinite input
fails before publication.
