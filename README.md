# OpenBB

A continuing Beasts & Bumpkins remake project, forked from Trass3r's OpenBB.
The current maintained build contains **three command-line asset tools**. The
graphical DSFML application and simulation classes remain an unfinished prototype.

## Build and test on Windows x64

From this directory, in PowerShell:

```powershell
./build.ps1 -Bootstrap -Test
```

This downloads the official portable **DMD 2.111.0** archive into `.tools/`, checks
its pinned SHA256, builds all three tools into `bin/`, and runs synthetic regression
tests. No administrator install or global PATH change is needed. Network access
is only needed for the first download; afterward use `./build.ps1 -Test` offline.
`make.bat -Bootstrap -Test` forwards to the same build from Command Prompt.

Requirements: Windows x64 and PowerShell 5.1 or newer. The optional corpus suite
also requires Python 3.10+ on PATH. The tools use D's standard library; neither
DSFML nor a graphics window is needed. DMD uses an available Visual C++ toolchain
or its bundled LLD/UCRT fallback, as described in the
[official Windows compiler documentation](https://dlang.org/dmd-windows.html).
This milestone was verified using Windows, DMD 2.111.0 and the installed Microsoft
linker. The bundled fallback has not been separately tested here.

The compiler archive is from the [official release archive](https://downloads.dlang.org/releases/2025/).
Its pinned SHA256 is
`6A37075BA547D25B9B836023B25A878827EF0234F8A9243C6058AD1F63036A15`.
To use an already installed copy of the same version, pass
`-Compiler 'C:\path\to\dmd.exe'`. The build intentionally checks the version.
“Reproducible” here means a pinned, repeatable source build and checked asset
outputs, not byte-identical PE executables across different linker installations.

## Tools

Each command requires an input BOX and an **explicit, new output directory**:

```powershell
./bin/unbox.exe ../BeastsBumpkinsGame/MISC.BOX ./build/extracted-misc
./bin/mfbdecoder.exe ../BeastsBumpkinsGame/VIDEO.BOX ./build/sprites
./bin/m10decoder.exe ../BeastsBumpkinsGame/SPEECH0.BOX ./build/speech
```

| Program | Output |
|---|---|
| `unbox` | Unchanged entry payloads and `_box_manifest.json` with ordered raw headers and hashes |
| `mfbdecoder` | One RGBA PNG sprite sheet per MFB entry |
| `m10decoder` | One 22050 Hz, signed 16-bit mono PCM WAV per M10 entry |

`--help` returns usage. Success returns exit code 0; argument, parsing or output
errors return a nonzero code. Existing output directories are refused. Filenames
retain archive case; unsafe names and case-insensitive output collisions are
rejected before creating the directory. The stored developer paths are never
used as extraction destinations. The programs do not change the working directory
or alter input files. Partial outputs remain if a later resource fails.

To unpack every archive in a directory, with one subdirectory per BOX:

```powershell
./tools/unbox-all.ps1 ../BeastsBumpkinsGame ./build/all-archives
```

`unboxall.bat INPUT_DIRECTORY NEW_OUTPUT_DIRECTORY` provides the same operation.
The previous batch script's mixed conversion/extraction commands have been replaced
by explicit tools. The secondary wrapper is now `source/openbb/io/make.bat`; it
forwards to the supported build and tests without `cppver.obj` or `cv2pdb`.

## Verify against your game files

```powershell
./build.ps1 -Test -GameDirectory ../BeastsBumpkinsGame
```

The optional suite checks the documented game edition using the committed hash
manifest, then runs the actual CLIs into a fresh `build/corpus-*` directory:

- 13 BOX files / 2,653 entries, including exact reconstruction from extraction metadata.
- 624 PNG sheets, with independently decoded pixels and PNG CRC/size checks.
- 5,866 indexed MFB frames against the independent reverse-engineering audit.
- 1,358 WAV files against the inherited decoder baseline and PT sample counts.
- 158 FAT entries across four banks, plus unchanged hashes for all 17 input files.

`build/verification.json` records the result and output location. This suite needs
the original files locally; **no game payloads are included in this repository**.
Other editions fail the corpus identity check rather than silently updating the
expected results. Synthetic tests work without any game data.

See [asset-tool behavior and verification](docs/asset-tools.md) for provenance,
the four corrected speech-boundary cases, and limits of the current evidence.

## Development direction

- `source/openbb/io/`: BOX, MFB, FAT, M10, palette and PNG support.
- `source/openbb/graphics/`: inherited rendering and animation code.
- `source/openbb/world/`: inherited map and entity classes.
- `source/openbb/tools/`: shared CLI argument and destination policy.
- `tools/`: extraction/conversion entry points and build support scripts.
- `examples/`: preserved DSFML demo and sprite viewer, outside the verified build.
- `tests/`: synthetic tests, optional corpus harness and hashes, without game assets.
- `docs/`: architecture, format contracts and verification evidence.
- `.tools/`, `bin/`, `build/`: ignored compiler, executables and generated output.

Cleanup milestones 2 and 3 are complete: sources are organized for continued
work, parser boundaries are checked, and the full local corpus passes. MFB alpha
conversion now follows the surface color-key setup recovered from the executable;
all indexed-frame and WAV hashes remain unchanged from milestone 1.

See [architecture and remaining work](docs/architecture.md),
[asset format contracts](docs/asset-formats.md), and
[contribution notes](CONTRIBUTING.md). The next cleanup milestone is separating
simulation state from DSFML and advancing animation through explicit ticks.
Real `.mis`/`.sav` loading and a static renderer remain future engine work.

Upstream copyright and GPL-3.0-or-later notice are preserved in [LICENSE](LICENSE).
Decoder attribution and evidence sources are recorded in [NOTICE.md](NOTICE.md).
