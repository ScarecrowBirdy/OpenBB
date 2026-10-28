# Examples

## Supported headless example

Build with `./build.ps1 -Target headless-demo`, then run `./bin/headless-demo.exe`
from the project root. `headless/main.d` creates a small model, advances 100 ticks,
and prints JSON state plus a draw-command count. It needs no game files or window.
Its movement/job/inventory data are illustrative, not recovered game AI.

## Historical graphical examples

`demo/main.d` preserves the interactive random-map example. Random tile selection
now lives in the example; the world model itself initializes deterministically.
The example owns wall-clock accumulation, calls fixed world ticks before drawing,
and passes a snapshot through scene construction to `demo/renderer.d`. That
adapter alone owns DSFML sprite creation; drawing never advances animation.
`demo/theapp.d` remains an unused season/application scaffold.

`spriteviewer/main.d` preserves the standalone sprite browser with explicit palette
selection. The obsolete `std.stream` import and commented file-dump code were
removed; the demo now uses `std.datetime.stopwatch` rather than `std.perf`.

Both graphical programs still require the old DSFML/SFML graphics, window, system
and audio APIs. They expect original game files in the process working directory;
the viewer also references its historical font filename. Do not copy these assets
into Git. Their APIs/dependencies have not been ported to a supported graphics
backend, and the migrated examples have not been compiled or run. No working
modern graphics build command is claimed. A future graphical target must pin its
backend, provide asset paths, and validate rendering against the original.

The maintained headless library needs no DSFML. Its tested boundaries and remaining
prototype assumptions are documented in [architecture](../docs/architecture.md).
