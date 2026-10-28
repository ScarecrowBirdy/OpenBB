# Contributing

Build and run asset, world and CLI tests with `./build.ps1 -Bootstrap -Test`; run the optional
local-asset suite before changing codecs or extraction behavior. See README.md.

- Keep original game assets, generated media, compilers and executables out of Git.
- Preserve upstream copyright and decoder attribution.
- Keep file parsing independent of graphical dependencies and command-line policy.
- Include a focused synthetic regression for a fixed parser/decoder defect.
- Compare decoded data before changing algorithms or optimizing floating-point math.
- Identify the source of game behavior: executable analysis, observed runtime,
  format evidence or a prototype assumption. Record unresolved discrepancies.
- Keep cleanup, behavior corrections and future engine features reviewable.

The sibling `Decomp` directory contains our investigation, but the ordinary asset
build and synthetic tests must work without it. Committed corpus hashes provide
the bridge; the corpus suite additionally requires a local supported game edition.

For state/render changes, keep DSFML and wall-clock access out of `source/openbb/world`.
Advance state only through explicit ticks/commands; render snapshots must remain
read-only with respect to the model. Add behavioral tests for tick boundaries,
state transitions or inventory conservation, and compare differing draw cadences.
Use named prototype conventions until executable/live evidence justifies a native
rule; generic job names and resource strings are not native IDs.

For CLI changes, preserve exit codes 0 (success/help), 1 (operation failure) and 2
(usage), retain archive/entry context, and test the actual executable with synthetic
BOX data. Keep console logging and filesystem output at the application boundary.
MFB palette selection must be explicit per call; palette table bytes are frozen in
`tests/fixtures/palette-hashes.json` independently of source-code formatting.

See [build targets](docs/build.md), [architecture/API migration](docs/architecture.md)
and [roadmap](docs/roadmap.md). An API migration affecting examples must update their
source and documentation even when graphics dependencies prevent a verified build.
