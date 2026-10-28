# OpenBB

A continuing Beasts & Bumpkins remake project, forked from Trass3r's OpenBB.
The maintained build contains **three command-line asset tools and a headless
world-state example**. Simulation state and scene construction are independent of
DSFML. The graphical examples and recovered gameplay implementation remain unfinished.

## Build and test on Windows x64

From this directory, in PowerShell:

```powershell
./build.ps1 -Bootstrap -Test
```

This downloads the official portable **DMD 2.111.0** archive into `.tools/`, checks
its pinned SHA256, builds the tools and headless example into `bin/`, and runs asset, world-state
and executable CLI regression tests. No administrator install or global PATH change is needed. Network access
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

`--help` returns usage and exit code 0. Incorrect argument counts return 2;
input, decoding and output failures return 1. Resource failures identify the
archive, entry index and filename. Converters select `.mfb` or `.m10` entries
case-insensitively from mixed archives and fail if no matching entries exist. Existing output directories are refused. Filenames
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
- `source/openbb/graphics/`: renderer-neutral scene construction and draw commands.
- `source/openbb/world/`: headless map/entity state, explicit ticks and animation.
- `source/openbb/tools/`: shared CLI argument and destination policy.
- `tools/`: extraction/conversion entry points and build support scripts.
- `examples/`: supported headless example plus preserved DSFML demo and sprite viewer.
- `tests/`: synthetic tests, optional corpus harness and hashes, without game assets.
- `docs/`: architecture, format contracts and verification evidence.
- `.tools/`, `bin/`, `build/`: ignored compiler, executables and generated output.

All six cleanup milestones are complete for the supported headless scope.
Asset readers and command-line behavior have regression coverage; simulation is
now testable without a window. Movement, jobs and inventory remain generic
prototype scaffolding rather than implemented native gameplay rules.

```powershell
./build.ps1 -Target headless-demo
./bin/headless-demo.exe
```

See [build targets and tests](docs/build.md), [architecture and evidence](docs/architecture.md),
[asset format contracts](docs/asset-formats.md), [roadmap](docs/roadmap.md), and
[contribution notes](CONTRIBUTING.md). Real mission/save loading, a validated native
renderer and recovered simulation rules are the next development stages.

Upstream copyright and GPL-3.0-or-later notice are preserved in [LICENSE](LICENSE).
Decoder attribution and evidence sources are recorded in [NOTICE.md](NOTICE.md).
