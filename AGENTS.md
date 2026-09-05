# Legendary Battle Art working rules

Read PROJECT_HANDOFF.md before making changes. It separates repository evidence
from reports in the earlier Battle Art Voxel Options conversation.

## Ownership and compatibility

- Build on Battle Art's existing architecture. Battle Art owns scene order,
  terrain, camera, lighting, depth, battle presentation, and its effects.
- Stadium importers, player/NPC character assets, Colosseum UI, and Battle
  Cinematics remain separate companions. Use exported provider APIs; do not copy
  their assets or runtimes into Battle Art to bypass integration problems.
- Keep engine-owned gameplay, collision, warps, stats, catch odds, inventory,
  and input behavior intact. Requested Pokemon size changes are visual changes.
- Target the user's Gen1Recomp 0.2.53 setup while preserving supported fallbacks.
  Do not introduce cross-mod private-file reads, debug upvalue access, shared
  global assumptions, or replacement of protected engine callbacks.
- Preserve stock sprites/UI and per-feature Battle Art defaults when optional
  providers or Legendary options are unavailable or disabled.

## Approved presentation

- Preserve TEST366-style granite pillars, recessed warm side lanterns, charcoal
  trim, non-emissive granite tops, and Separate/Bottom Link/Top Interlock layouts.
- Wall and ledge colors must not recolor pillars. Preserve staggered masonry,
  timber bridges/fences, approved trees, landscaping, and smooth sky blending.
- Preserve the Legendary Pokeball system, capture effects, 3D smoke integration,
  standing selected trainer, naming-screen compatibility, and 2D fallback.
- Cave opening fixes must target opening geometry, not globally lower walls or
  alter collision. Keep unaffected walls and slopes intact.
- Avoid shader-state leaks between terrain, Pokemon, and character draws.

## Workflow and verification

- Continue on the user's Legendary-Additions branch unless instructed otherwise.
- Inspect actual files before relying on old TEST numbers or prior diagnoses.
  Label historical test claims separately from checks performed in this checkout.
- Make focused changes and use relevant existing tests. Distinguish static or
  mocked validation from actual Android gameplay and visual verification.
- Keep companion patches in their own packages. If the exact source package is
  missing, record the missing input instead of substituting an unrelated mod.
- Do not include ROMs, generated imported model packs, or user-supplied artwork
  in source changes. Respect the existing asset exclusions.
- Keep PROJECT_HANDOFF.md current with changes, evidence, and remaining work.
  Packaging should retain the correct manifest, mod identity, and install layout.
