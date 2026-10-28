# Asset-tool verification — 2026-10-29

This cleanup continues the fork from upstream commit
`aedc3fcf2e27caad6005e5d1a0459e380a04b27f`. Its scope is the headless asset tools,
not a language port, new graphics backend or completed game simulation.

## Parsing and output contracts

BOX parsing now fails on short headers/payloads, oversized signed lengths and
unterminated fixed fields. It retains original case and raw metadata; lookup
uses first-match ASCII case folding for the established game filenames. Unknown
code-page bytes are retained without attempting UTF-8 decoding. Duplicate
resources remain inspectable by index, but extraction rejects output collisions. Library parsing
does not catch an error and return a partly initialized successful object.

`unbox` exports the exact archive header and each raw entry header in its manifest,
including unused padding. This permits byte-exact reconstruction; retaining only
decoded strings would lose padding and other metadata. It does not restore
filesystem timestamps, but preserves the eight SYSTEMTIME words in each raw
header. It is an unpacker, not a full archive editor.

MFB checks headers, versions 100/101, dimensions, frame extents and RLE boundaries;
origins are signed. Decoded indexed pixels are exposed through `frameIndices()`.
FAT validates directory and payload extents. PT parsing validates metadata before
decoding compression 9. Bit reads now check actual consumption and avoid reading
beyond EOF merely to prefetch lookahead. Output allocation follows the declared
sample count instead of using a fixed four-million-byte WAV buffer. MFB indexed
storage, each RGBA output allocation, and M10 PCM are capped at 256 MiB as tool
resource limits; these are not aggregate process-memory limits.

All CLIs use explicit input/output arguments and a new destination directory.
They reject path separators, invalid Windows characters, device names and
case-insensitive collisions in output names. They do not derive destinations from
stored source paths. Failures return nonzero; previously written output may remain.
The decoder still contains inherited low-level pointer math: these checks do not
constitute a comprehensive hostile-file security audit.

## Regression evidence

`tests/fixtures/corpus-hashes.json` contains names, sizes and hashes, not payloads.
It was assembled from the independently audited original assets under the sibling
`Decomp` investigation, plus an explicitly captured upstream audio baseline:

| Evidence | Scope |
|---|---|
| Decomp `asset-audit.json` | 2,653 payload hashes; 624 MFB headers and 5,866 indexed-frame hashes |
| Decomp `box-format-audit.json` | Whole-archive identity, checked against BBTools and exact repacking |
| Decomp `audio-audit.json` | PT declared sample counts and FAT payload boundaries |
| Upstream M10 implementation | 1,358 WAV hashes, built with DMD 2.111.0 after adding two required explicit switch fallthrough statements |

The baseline audio capture precedes the PT/buffer/EOF changes. **1,354 WAV files
remain byte-identical.** Four upstream outputs contained an additional sample:

| Archive | Resource | Declared samples |
|---|---|---:|
| SPEECH2.BOX | Pf31.M10 | 45056 |
| SPEECH2.BOX | Pik4.M10 | 24576 |
| SPEECH2.BOX | Wiz6.M10 | 32768 |
| SPEECH3.BOX | Pf31.M10 | 61440 |

Each ends at an exact 4096-sample output-block boundary. The old decoder called
`Decode()` again and emitted one sample before noticing the declared total had
already been reached. The fixed decoder returns zero immediately when complete.
For these four cases, the expected WAV was independently constructed from the
upstream output by removing its last two bytes and updating only the RIFF/data
length fields. Its hash exactly matched the fixed decoder, establishing that all
retained PCM samples are unchanged. A synthetic 4096-sample regression covers it.

These WAV comparisons establish preservation of the inherited decoder's behavior
and correct container lengths, **not** acoustic or sample-perfect equivalence to
the original game's audio implementation. That remains a live comparison target.

The Python corpus runner checks generated PNG chunks, CRCs, dimensions, palette
mapping, transparency conversion and sheet placement independently of the PNG
writer. Indexed-frame expectations come from the earlier independent MFB audit.
Milestone 3 corrects the shared last-frame color key using executable evidence:
raw frames use their own first pixel; compressed frames share the first decoded
frame's first pixel. The only affected retail sprite sheet is `thumnail.MFB`
(224 pixel alpha changes across its 33 frames). Indexed pixels and palettes are
unchanged. The independent PNG oracle now checks that explicit policy; synthetic
fixtures distinguish first, last, per-frame and RLE-marker keys. See
[format contracts and addresses](asset-formats.md#mfb-sprites).
Palette choices remain the inherited export policy, not every runtime context.

The complete passing local run is recorded in `build/verification.json`. Its
input-hash check covers all 13 BOX files and four FAT banks. The original files,
BBTools, and the existing investigation fixtures were not modified by this cleanup.

## Building and extending

`build.ps1 -Bootstrap -Test` is the supported asset build. Subsequent builds use
the cached compiler without network access. A compiler override must report the
same pinned version. Native commands are checked immediately; a failed compiler
or test cannot be masked by a later successful command.

Synthetic tests exercise empty/truncated BOX cases, duplicate resolution, output
names, signed MFB origins, versions, RLE errors, short PT headers, truncated speech
and exact output-block termination. Milestone 3 adds all-prefix truncation checks,
BOX reload atomicity and unknown name bytes, MFB frame/sheet alpha checks, FAT
metadata and odd sample lengths, PT chunk-size independence and malformed history
references. The corpus runner also checks unsafe CLI names, existing destinations,
and conversion failures without successful partial PNG/WAV files. The optional real-corpus test checks the public
APIs and all three executables. Headless world/scene behavior is covered separately
by `world_tests.d`; the historical DSFML examples remain outside the verified build.

Native case folding for non-ASCII archive names and PT extended tags are not
established by the current corpus. Any new support should add focused fixtures and preserve the
documented working edition. Do not refresh hashes simply to make failures pass.
Record whether a changed expectation comes from executable evidence, an independent
decoder, or an intentional implementation change.

## Milestones 2 and 3 validation

The library now lives under `source/`; all supported builds pass `-Isource`.
Tools are separate entry points under `tools/`. Graphical examples are preserved
under `examples/`, with imports updated for `openbb.world.*`. Their old graphics
API is still outside the supported build; no graphical compile/run is claimed.

BOX failed reloads preserve the previous archive. MFB and FAT headers use explicit
little-endian reads rather than struct/pointer casts. FAT payloads and directory
metadata can be inspected independently of signed 16-bit sample interpretation.
An odd byte count fails only when requesting 16-bit samples.

The M10 history lookup now selects from explicit history/sample arrays instead of
walking a pointer across adjacent class members. An invalid first-block lag throws
before unsigned subtraction. All 1,358 WAV hashes still match the committed
milestone 1 expectations; no audio baselines were regenerated. Other inherited
codec arithmetic remains unchanged and is not claimed to have received a complete
security audit or an original-game acoustic comparison.

## Milestones 4, 5 and 6 validation

The supported build also compiles headless world state, explicit-tick animation,
renderer-neutral scene construction and a runnable example. World tests check
arrival, pause/resume/wrap, job transitions, inventory conservation/overflow,
independent snapshots and differing draw cadences. These are prototype API tests,
not evidence that the original worker/economy simulation has been ported.

Asset tools share one process/error boundary: 0 for success/help, 1 for operation
failure, and 2 for usage errors. Converters select matching entries from mixed
archives and reject a no-match archive before creating output. Errors name the
archive and failing entry. Native CLI tests exercise the real executables without
Python or game data, including a later-resource failure after an earlier success.

Readers no longer write BOX dumps or import console logging. MFB conversion uses
read-only per-call palettes, without a shared selected palette. Interleaved Main,
Loading and Mission conversions are tested. The eight palette tables were hashed
before the API edit into `tests/fixtures/palette-hashes.json`; the corpus test now
checks those table bytes instead of hashing unrelated palette source code. The old
`palette_source_sha256` remains historical provenance in the unchanged original
corpus manifest. No asset, frame or audio expected hashes were regenerated.

The complete corpus still passes: 13 archives, 2,653 payloads, 624 PNG sheets,
5,866 indexed frames, 1,358 speech WAVs and 158 FAT entries. Input hashes remain
unchanged. See [architecture](architecture.md), [build guide](build.md) and
[roadmap](roadmap.md) for current implementation boundaries and next steps.
