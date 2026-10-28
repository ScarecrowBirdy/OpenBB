# Inherited graphical examples

`demo/main.d` preserves the interactive random-map demo. `demo/theapp.d` is its
unused season/application scaffold. `spriteviewer/main.d` preserves the standalone
sprite viewer. Their library imports now resolve under `../source/openbb/`.

These examples require the old DSFML/SFML graphics, window, system and audio APIs,
plus removed Phobos modules (`std.perf` and, in the viewer, `std.stream`). The
current pinned DMD asset build neither installs those dependencies nor compiles
these entry points. A supported graphical target requires an explicit dependency
and API migration; there is no verified graphics build command yet.

They also assume local game assets in the process working directory. Do not copy
game data into Git. Keep these examples as references while introducing real world
loading and separating graphics from simulation. Their random tiles, sample actor
and render-driven animation are prototype behavior, not verified game rules.

The supported programs are the three headless tools documented in the
[project README](../README.md).
