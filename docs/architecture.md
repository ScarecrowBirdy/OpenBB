# Source organization

The maintained build is the asset library and three command-line tools. The
graphics and world code is preserved for continued development, but is still the
inherited prototype. Moving it does not establish original-game behavior.

| Location | Responsibility | Build status |
|---|---|---|
| `source/openbb/io/` | BOX, MFB, FAT, M10, palette tables, PNG writer and bounded binary reads | Built and corpus checked |
| `source/openbb/tools/cli.d` | Shared argument and safe output-name policy | Built and tested |
| `tools/*.d` | CLI orchestration and filesystem output | Built and corpus checked |
| `source/openbb/graphics/` | DSFML sprite animation | Preserved prototype |
| `source/openbb/world/` | Map, tiles, layers and entity hierarchy | Preserved prototype; still depends on DSFML |
| `examples/demo/` | Original interactive demo and application scaffold | Not built by the supported toolchain |
| `examples/spriteviewer/` | Original sprite viewer | Not built by the supported toolchain |
| `tests/` | Synthetic fixtures, native audit and independent Python corpus checks | Executed by `build.ps1 -Test` |
| `docs/reference/videoboxconsts.txt` | Inherited resource ordering/constants | Historical reference |

`build.ps1` uses `source/` as the D import root. Entry points live in `tools/`;
module names remain `unbox`, `mfbdecoder` and `m10decoder`. The PNG module is now
`openbb.io.png`; map/entity imports are `openbb.world.*`. The demo's unused
`TheApp` scaffold is local to `examples/demo/theapp.d`. The root build scripts and
output executable names remain the supported interface.

The command-line dependency direction is tools -> asset library -> D standard
library. Neither the asset tools nor their tests import DSFML or world classes.
Parsers expose bytes and metadata; tools select resources, palettes and filenames.
The inherited mutable palette selection and optional BOX text dump remain legacy
APIs; future API cleanup can replace them without coupling readers to rendering.

## Preserved demo assumptions

- The demo creates a random 25 by 70 map and a sample woman. It does not read a
  mission or saved world, and its movement/job state is not a recovered simulation.
- Map coordinates use the inherited 77 by 40 tile geometry and staggered-row
  formulas. Those formulas are examples, not the authority for every game layer.
- Animation uses a wall-clock counter and advances during rendering. Map/entity
  classes directly reference DSFML sprites, vectors and render targets.
- The demo and viewer expect game files in the working directory. The viewer
  uses legacy `std.stream`; animation/demo use legacy `std.perf`. Their DSFML/SFML
  API generation is not available in the pinned asset-tool build.
- Sprite origins exposed by the reader are signed file values. Runtime centering,
  terrain-specific origin overrides, owner colors and palette effects belong in
  a future renderer; see [format contracts](asset-formats.md).

See [the examples note](../examples/README.md) before attempting a graphics build.

## Cleanup milestone status

1. Build baseline: completed in the prior cleanup; pinned DMD, supported headless
   tools, synthetic tests and optional corpus verification.
2. Source organization: completed; maintained source, CLI entry points, examples,
   tests and documentation have separate locations and updated imports/build paths.
3. Asset trustworthiness: completed for the documented formats and corpus;
   bounds/error handling, metadata, output policy and transparency have explicit
   contracts and regression coverage. See [verification](asset-tools.md).
4. Next: separate simulation state from DSFML and replace render-driven updates
   with explicit ticks. Keep the examples while introducing testable engine state.
5. CLI consistency: explicit arguments, nonzero failures and safe destinations
   are already implemented; remaining API/logging cleanup is separate work.
6. Documentation is maintained alongside changes; add recovered behavior and
   remaining uncertainty as engine features are implemented.

Real mission/save loading and static rendering are subsequent engine features.
Original-game audio equivalence and final visual fidelity still need live
comparison; corpus hashes establish regression consistency, not those claims.
