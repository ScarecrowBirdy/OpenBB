# Architecture and cleanup status

The supported build contains the three asset tools and a headless simulation
example. World state and scene construction now compile without DSFML. The
historical graphical examples remain source references pending a graphics API
migration; a working graphical application is not claimed.

| Location | Responsibility | Verification |
|---|---|---|
| `source/openbb/io/` | BOX, MFB, FAT, M10, palettes, PNG, binary reads | Synthetic tests and full asset corpus |
| `source/openbb/world/` | Map/layers, entities, tick-driven movement/animation, inventory and job state | Headless synthetic tests |
| `source/openbb/graphics/scene.d` | Read-only scene construction and draw commands | Headless cadence/snapshot tests |
| `source/openbb/tools/` | Shared arguments, entry selection, output policy and diagnostics | Executable CLI integration tests |
| `tools/*.d` | Extraction/conversion and filesystem output | CLI and full corpus tests |
| `examples/headless/` | Small executable demonstrating the state/render boundary | Built and run without game files |
| `examples/demo/` | Interactive demo plus DSFML command adapter | Source migrated; not compiled/run |
| `examples/spriteviewer/` | Historical DSFML sprite viewer | Source migrated; not compiled/run |
| `tests/` | Asset, world and CLI tests plus optional Python corpus audit | `build.ps1 -Test` |
| `docs/reference/videoboxconsts.txt` | Inherited resource ordering/constants | Historical reference |

## State, ticks and rendering

`Map` owns explicit tile layers and a collection of entities in insertion order.
It does not create random terrain or load textures. `Map.tick()` advances every
entity by its configured fixed duration, then increments the tick counter. Adding
entities during a tick and recursive ticks are rejected. There is no automatic
wall clock, catch-up policy, job AI or production system inside the model.

`Entity` stores identity, position, size, presentation identifiers, animation,
job state and inventory. `DynamicEntity` provides a bounded straight-line movement
prototype with an arrival/idle transition. Inventory transfers check source
quantity and destination overflow before removing goods. Jobs are explicitly
assigned, started and cleared by the caller. These are generic, testable
scaffolding APIs, not native job selection, wages, needs or harvesting behavior.

Animation takes integer milliseconds through `tick()`. Clip ranges are half-open;
pause preserves the current frame and fractional frame time, resume continues,
and seek resets the remainder. Neither frame reads nor drawing advance time.
`Building` stores a construction-stage placeholder without owning a sprite.

`Map.snapshot()` copies tile layers, actor state and inventory entries. Callers can
modify these copies without changing the model. `buildScene(snapshot, resource)`
accepts const state and emits resource/frame/position commands. It cannot tick the
world. The demo adapter translates those commands into DSFML sprites. A real
renderer can consume the same boundary without adding DSFML to the world model.

Prototype limits and conventions:

- Movement positions are caller-defined 2D units; the example treats them as
  presentation coordinates. They are not native fixed-point object coordinates.
- Tile `resID` is a direct frame index in the prototype; native terrain selectors
  require additional mapping. Tile flags are prototype flags, not native masks.
- Scene order is tile planes followed by actors in insertion order. The layer
  field is metadata; native depth sorting, composite buildings, elevations,
  overlays, culling and terrain-origin rules remain future rendering work.
- Job names, resource names, target IDs and construction state are application
  scaffolding. There is no automatic worker/bakery/food chain or target resolution.
- Snapshotting is synchronous and detached, not a concurrent world synchronization
  mechanism. A failing tick propagates its error; it does not roll back prior
  entities in that tick. Removal/spawn command queues remain future work.

## Evidence versus prototype policy

The investigated executable is BEASTS.EXE SHA256
`BBBE15AFAD96051082DB8CD68F6145262AC45FB666BE6073B6D085C07E0093D0`.
Our local sibling `Decomp` repository is research input, not a build dependency.
The relative links below work in the shared workspace; a standalone OpenBB clone
can use the named document/function references to locate that research.

| Decision | Evidence and limit |
|---|---|
| Default 28 ms model tick | [TimingAndScheduling](../../Decomp/docs/TimingAndScheduling.md), main loop `00406B30`: 28 ms scheduling deadline. OpenBB does not implement the native command queue, pending-step gate or per-object cadence. |
| Default 78/20/39 tile spacing | [RenderingAndMaps](../../Decomp/docs/RenderingAndMaps.md), terrain renderer `0040C860`: horizontal step 78, vertical row step 20, odd-row offset 39. The utility is not a complete native projection. |
| Per-frame/raw and initial/compressed MFB keys | [Asset contracts](asset-formats.md#mfb-sprites), loader `00431500` and DirectDraw key helpers. Static executable evidence and corpus checks. |
| Generic movement/jobs | Explicit prototype implementation. [MovementAndJobs](../../Decomp/docs/MovementAndJobs.md) distinguishes preferred job, carry category, role and request; these have not been ported into the generic JobState. |
| Later engine validation | [LiveMovementAndFoodChain](../../Decomp/docs/LiveMovementAndFoodChain.md) contains investigation evidence to compare against future engine behavior, not proof that this prototype implements that chain. |

## API changes from the inherited prototype

| Previous API | Current approach |
|---|---|
| `Entity.render()` / `DynamicEntity.render()` | Snapshot -> `buildScene()` -> renderer adapter |
| DSFML vectors/sprites inside world classes | `Position`, `Size`, resource identifiers and frame numbers |
| `StaggeredMap` / `DiamondMap` coupled to windows | Data-only `Map`, explicit tile initialization and presentation-side `TileLayout` |
| `Animation : Sprite`, timer-driven `update()` | `world.Animation.tick(milliseconds)`; `graphics.animation` is a compatibility import of the state type, not the old Sprite API |
| `usePalette()` and global `palette` | Read-only `getPalette(Palette)` and per-call MFB conversion |
| `mfb[]` following global palette selection | `mfb.sheet(Palette.Loading)`; `mfb[]` consistently uses Main |
| `BOXFile.dump(filename)` | Inspect metadata or use `unbox`'s manifest; filesystem output stays in applications |

## Cleanup milestones

1. Pinned, repeatable asset build and validation: complete for supported headless
   targets. Graphics dependency migration is explicitly separate.
2. Maintained source, tools, examples, tests and docs organized: complete.
3. Bounded asset parsing, metadata, safe extraction and regression coverage: complete
   for documented formats and corpus, not an unrestricted security audit.
4. Game-state/graphics separation and explicit ticks: complete. Movement, jobs,
   inventory, animation and read-only scene behavior are tested without a window.
5. Consistent CLI contract and output-free decoders: complete. Mixed archives,
   error context, exit codes and output refusal are integration tested.
6. Build/contribution/provenance documentation and implementation roadmap: complete.
   These documents should continue to evolve alongside engine implementation.

The cleanup is a foundation for continued development, not a finished remake.
See the [roadmap](roadmap.md), [build guide](build.md) and
[asset verification](asset-tools.md).
