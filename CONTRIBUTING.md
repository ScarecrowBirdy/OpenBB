# Contributing

Build and run synthetic tests with `./build.ps1 -Bootstrap -Test`; run the optional
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
