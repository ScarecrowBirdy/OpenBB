# Asset reader contracts

These describe the current supported readers, not unrestricted acceptance of
every possible file variant. Synthetic tests need no game files. Corpus validation
uses the fixed edition identified by `tests/fixtures/corpus-hashes.json`; that
manifest was not regenerated during cleanup milestones 2 and 3.

## BOX archives

An eight-byte archive header begins with `BOX`; the remaining five bytes are
preserved. Entries follow sequentially: 256-byte NUL-terminated name, 256-byte
NUL-terminated original path, eight little-endian SYSTEMTIME words, a four-byte
little-endian payload length, then the payload. Each entry header is 532 bytes.
There is no independent directory or authoritative count in this reader.

Complete headers, NUL termination and complete payloads are required. Lengths
above signed 32-bit maximum are rejected, matching the established game reader.
Zero-entry archives and zero-length payloads are supported. No trimming or
normalization is applied to the stored metadata. Unknown archive header bytes,
entry padding and timestamp words survive through raw-header inspection/export.

Lookup folds ASCII A-Z and returns the first matching entry. Index access retains
duplicate names. Bytes outside ASCII remain unchanged; native code-page case
folding is not established. Every indexed accessor reports a catchable exception
for an invalid index. Constructors own their input bytes. A failed `readArchive()`
reload leaves the prior valid contents available.

Extraction uses a new explicit destination, preserves filename case, ignores
stored developer paths, and rejects unsafe names or output collisions before
creating the directory. `_box_manifest.json` preserves raw headers, order and
hashes for exact reconstruction. Original timestamps are recorded, not applied to
the extracted filesystem. A later conversion failure can leave earlier files;
there is no transactional whole-archive rollback.

## MFB sprites

The 18-byte header contains `MFB`, version `100` or `101`, little-endian 16-bit
width/height, signed 16-bit x/y origins, flags and frame count. Bit 0 requests
transparency; bit 1 selects compression. Other flag bits are retained. Header
reads are explicit and do not depend on struct alignment. Origins are returned
as stored, including negative values; the legacy `isMaptile` argument never crops
or rewrites the decoded frames.

Raw frames have width*height palette indices. Compressed frames start with a
four-byte encoded length. The first encoded byte is the run marker; the stream
contains literal non-marker pixels or marker/count pairs. The bounded decoder
requires exact pixel output and consumption of the declared encoded frame. It
accepts zero-count pairs as no output, preserving the inherited decoder policy;
that edge case is not a claim of compatibility with the native decoder. Bytes
after the final frame are separate, retained by `trailingData()` (retail
`pspells.mfb` has one). Palette indices remain available without RGBA conversion.

Dimensions must be positive and at most 32767; frame count must be nonzero.
Indexed storage is limited to 256 MiB. Individual RGBA frame/sheet allocations
also have a 256 MiB limit, calculated with wide arithmetic before allocation.
These are tool limits, not claimed engine limits or a total-memory budget.

### Color-key evidence

The original executable's surface lifecycle distinguishes raw and compressed
frames. The following addresses were inspected in our sibling Decomp survey:

| Function | Relevant behavior |
|---|---|
| `0042F320` / `0042F5A0` | Construct the sprite before loading; current frame at +0x50 starts at zero |
| `00431500` | Raw frames receive separate surfaces and separate color-key setup; compressed frames receive one shared surface, decoded once before key setup |
| `004313A0` | Set a DirectDraw source color key using `004312D0` |
| `004312D0` | With argument `0xFFFFFFFF`, sample the first surface pixel rather than substituting a requested RGB color |
| `0042FB50` | Decode the selected compressed frame into the shared surface; does not reset its DirectDraw key |
| `0042FD90` | Select raw per-frame surfaces or refresh/reuse the shared compressed surface when drawing |

Consequently, the export policy uses each raw frame's first pixel, or the initial
decoded compressed frame's first pixel shared across that animation. It does not
use the last frame's key or assume that an RLE marker is always the first decoded
pixel. `transparencyIndex(frame)` exposes this choice. `opIndex` and sheet export
both apply it. Unused sheet cells retain the inherited opaque magenta fill.
`mfb.sheet(Palette.Loading)` and `mfb[index, Palette.Loading]` select a palette per
call; `mfb[]` and `mfb[index]` default to Main. `getPalette()` returns a read-only
table. There is no shared active palette or console/filesystem output in decoding.

This is a conclusion from static executable analysis, not a new live screenshot
comparison. Owner-color translation, seasonal palettes, darkening and surface
restoration are not implemented by this static exporter. For the current corpus,
the correction changes only `thumnail.MFB`: 224 alpha pixels across its 33 frames.
All 5,866 indexed-frame hashes remain identical. The Python PNG oracle checks the
new policy independently; synthetic cases distinguish per-frame, initial-frame,
last-frame and marker colors.

The game's loader also overrides origins for old versions and terrain resources
(`maptile.mfb`/`hills.mfb`). Those rendering rules are deliberately not applied to
raw asset metadata. Source survey files are available locally under
`Decomp/work/output/survey/functions/<address>.c`; they are not build dependencies.

## FAT audio banks

The header is ASCII `0.30` and a little-endian 32-bit entry count. Each 16-byte
directory entry contains offset, byte length, type and flag as little-endian
32-bit values. The complete directory and every payload extent are validated
before sample access; payloads may not point inside the header/directory.

`entryInfo()` returns all four metadata values and `entryBytes()` returns the
unchanged payload. Unknown type/flag values are retained without guessing their
meaning. `opIndex()` explicitly requests signed 16-bit little-endian samples and
rejects an odd payload length. It returns decoded samples without unaligned
pointer casts. An odd-sized resource remains inspectable as bytes. Empty banks
and zero-length entries are allowed; invalid indices throw exceptions.

## M10 / PT speech

PT metadata uses a little-endian data offset and tagged big-endian numeric values.
The reader requires complete metadata, a terminator, sample count and supported
compression 9. Extended-length tags remain unsupported. Decoding checks actual
bit consumption and throws on truncated input instead of reporting successful
partial speech. WAV output allocates 44 header bytes plus two bytes per declared
sample, with PCM capped at 256 MiB; output is 22050 Hz signed 16-bit mono.

The inherited synthesis mathematics and lookup tables are preserved. The history
window is now read through explicit history/sample array selection, avoiding a
pointer walk across adjacent object fields. The first history lag is checked
before subtraction to prevent an unsigned index underflow. A synthetic malformed
stream exercises that exact failure. Chunk-size tests check that callers receive
the same PCM regardless of their output-buffer size.

All 1,358 WAV hashes match the committed milestone 1 baseline, including its four
documented exact-block termination corrections. No hashes were updated to approve
the history change. This demonstrates output preservation on the corpus, not
sample-perfect agreement with the original game's audio implementation. See
[verification and remaining limitations](asset-tools.md).
