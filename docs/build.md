# Build and validation

Run commands from the OpenBB directory. Windows x64 and PowerShell 5.1+ are the
supported environment. DMD 2.111.0 is pinned; the portable bootstrap checksum and
compiler provenance are documented in the [README](../README.md).

```powershell
./build.ps1 -Bootstrap -Test   # first build; download/cache the pinned compiler
./build.ps1 -Test             # subsequent offline build and tests
./build.ps1 -Target unbox     # build one tool
./build.ps1 -Target assets    # build all three asset tools
./build.ps1 -Target headless-demo
./bin/headless-demo.exe
./build.ps1 -Test -GameDirectory ../BeastsBumpkinsGame
```

`-Target` accepts `all` (default), `assets`, `unbox`, `mfbdecoder`, `m10decoder`
and `headless-demo`. `-Test` requires `all`, so the CLI tests always exercise freshly
built tools. `-GameDirectory` requires `-Test` and Python 3.10+ on PATH. Ordinary
asset/world/CLI tests need neither Python, DSFML, game files nor Ghidra. Compiler
and game-directory overrides are resolved before the script changes directories.
`make.bat` forwards arguments to this build using Windows PowerShell.

| Check | Coverage |
|---|---|
| `tests/asset_tests.d` | Malformed files, metadata, RLE, alpha, speech boundaries, independent palette calls |
| `tests/world_tests.d` | Explicit ticks, movement/arrival, animation pause/wrap, job state, inventory conservation, detached snapshots, rendering-cadence independence |
| `tests/cli_tests.d` | Real executable help/exit codes, mixed archives, missing/broken inputs, entry-specific errors, collisions, unsafe names, existing outputs, partial-directory failure |
| `tests/verify_corpus.py` | All supported original asset hashes, extracted archive reconstruction, PNG pixels, WAV containers, input immutability |

The build stops at the first compiler/test failure. Synthetic CLI tests use a
unique temporary directory and remove only that directory on exit. Corpus runs
retain their generated output under ignored `build/corpus-*`; their results are
recorded in `build/verification.json`. Neither test path modifies original assets.

The included headless example prints JSON after 100 explicit 28 ms ticks. Its
animation frame is 4 and it emits seven draw commands (six tiles and one actor).
It loads no sprites and simulates no native production/food rules. It demonstrates
how state can be exercised without a graphics backend.

The full suite is checked in the normal debug/test build. Asset and world unit
tests have also been checked with DMD `-O -release -unittest` to exercise runtime
validation without contracts. No platform portability beyond this Windows x64
configuration is claimed.

## Graphical examples

The old DSFML/SFML graphics API is not installed/pinned by this build. The demo
source now consumes snapshots through `examples/demo/renderer.d`, and uses
explicit ticks instead of render-driven updates. The viewer uses explicit palettes.
Neither graphical program has been compiled or run after this migration. See
[examples](../examples/README.md) for prerequisites and the separate graphics task.
