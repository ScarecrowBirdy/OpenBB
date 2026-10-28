# Continued development roadmap

The six cleanup milestones are complete within the supported headless scope.
The next work is engine implementation and validation, not more source reshuffling.

1. **Load real world state.** Add bounded `.mis`/`.sav` readers from the recovered
   layouts. Preserve unknown fields, keep native IDs distinct from presentation
   IDs, and compare parsed records with the independent Decomp audits.
2. **Render a static native world.** Implement terrain selector mapping, sprite
   origins, elevation, overlays, owner/palette effects, object composition and
   depth ordering. Pick and pin a supported graphics backend; retain a headless
   route for render-command or image comparisons.
3. **Port simulation rules in verified slices.** Replace straight-line movement
   with recovered coordinates, routes and collision rules. Introduce actual role,
   job, need, carry, inventory and money fields. Port the worker-to-food chain with
   original-game traces as acceptance evidence; generic inventory transfers alone
   do not establish native economic behavior.
4. **Recover scheduling and animation semantics.** Model pending steps, pause,
   command order, object-slot update order, per-object countdowns, directional
   animation banks and effect timing. The 28 ms default is only one scheduling fact.
5. **Run controlled comparisons.** Use the prepared investigation maps/saves to
   compare state, images and sound with the original. Record discrepancies rather
   than updating expected results just to obtain passing tests.

Keep each step reviewable and protect existing asset hashes. Defer a language
port, speculative production framework, new asset encodings and broad optimization
until real-world loading and rendering are established. The
[architecture evidence table](architecture.md#evidence-versus-prototype-policy)
links the current implementation boundaries to our research.
