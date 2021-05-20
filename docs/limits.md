# Supported surface and limits

## Supported platforms

The build and CI target macOS and Linux. Exclusive publication uses `renamex_np`
with `RENAME_EXCL` on macOS or libc `renameat2` with `RENAME_NOREPLACE` on Linux.
There is no unsafe ordinary-rename fallback. Linux environments without that
libc interface fail explicitly. Windows-native execution is not implemented.

Guile 3 is required. Python and Node are verification tools, not runtime audio
processors. The optional browser desk uses standard HTML media playback and
relative files. PCM16 is the compatibility-oriented export default; browser
support for other valid WAV encodings can vary. A local WAV player remains useful
for the higher-width and float exports.

## WAV

| Capability | Supported |
| --- | --- |
| Container | Little-endian RIFF WAVE |
| Integer input | 8, 16, 24, 32 bits |
| Float input | IEEE 32 or 64 bits, finite samples |
| Codec channels | One through eight, preserved in file order |
| Timeline input | Mono or stereo |
| Timeline output | Mono or stereo |
| Output rate | 8000 through 384000 Hz |
| CLI integer export | 16, 24, 32 bits |
| CLI float export | 32 or 64 bits with `--float` |
| Extensible input | Known PCM GUID, matching container and valid width |
| Metadata | Chunk names/sizes inspected; original bodies omitted on export |

RF64, big-endian RIFX, compressed WAV, MP3, AAC, FLAC, broadcast metadata
preservation, reduced-valid-bit extensible PCM, and arbitrary channel matrices
are outside this implementation. Convert a copy explicitly with an external tool
when needed, then treat that converted WAV as the source coordinate domain.

The scanner rejects inconsistent byte rates and alignment, truncated chunks,
missing odd-byte padding, duplicate format or data chunks, data lengths that
split a frame, unknown format extensions, and a RIFF size that differs from the
actual file. It never assumes audio begins at byte 44.

## Resource policy

| Resource | Default limit |
| --- | --- |
| Source bytes per project | 2 GiB aggregate |
| Sources | 64 |
| Clips | 4096 |
| Redaction declarations | 4096 |
| Effects | 32 |
| Scheduled output | 200,000,000 frames |
| Sum of clip render work | Eight times output frame budget |
| One decoded buffer | 256 MiB |
| Offline rendering preflight | Three full output buffers within 256 MiB |
| One resampler table | 32 MiB |
| Resampler tables per session | 64 MiB |
| Source cache | Four pages of 4096 frames per source |
| RIFF chunks | 4096 |
| Document bytes | 1 MiB |
| Data nodes / nesting | 50,000 / 32 |
| String / atom length | 4096 / 128 characters |
| Waveform buckets | Default 1200, maximum 8192 |
| Silence suggestions | 4096 |

At 48 kHz, the default output frame limit permits about 69 minutes. Offline
stereo effects are more restrictive: the three-buffer preflight permits roughly
116 seconds at 48 kHz under the default 256 MiB policy. Streaming sessions do not
allocate one full output recording.

These are explicit allocation and work policies, not a hard cap on total process
RSS. Runtime objects, garbage collection, decoded page caches, kernel tables,
and generated HTML have overhead. The Scheme library exposes parameters for
selected budgets; the CLI keeps conservative fixed defaults.

## Audio semantics

The renderer is offline and single-threaded. It does not provide real-time device
I/O, a live monitor, time stretching, pitch shifting, plugin loading, transcript
recognition, or automatic speaker identification. Clip rate conversion preserves
playback time; it is not a speed control.

Master effects keep output length unchanged and truncate tails at the project
end. Use a longer explicit timeline with selected source silence if a tail needs
space. There is no synthetic silence clip declaration in version 1.

Meter values are sample peak and unweighted RMS. Limiting is sample-peak
limiting. There is no loudness standard, true-peak, restored-speech-quality, or
real-time-throughput certification.

## Integrity and crash behavior

Bundle hashes identify files and sanitized sources. They do not authenticate an
author, stop someone from rewriting a manifest, or encrypt audio. Raw original
hashes stay local. Source identity checks detect ordinary concurrent edits, not a
privileged hostile filesystem.

Output publication is atomic and refuses replacement on the supported native
APIs. Files are flushed and synced, but directory metadata is not recursively
synced. Power-loss durability is not claimed. SIGINT and SIGTERM unwind normal
cleanup; SIGKILL or a machine crash can leave an owned staging directory.
