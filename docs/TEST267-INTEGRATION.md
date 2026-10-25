# TEST267 integration — 2026-10-23

Integrated IterationTEST267 into legendary-update-1.11.2 from 39ff49d (tag 1.11.2).
The master branch and existing tag remain at 39ff49d. This integration is local
and uncommitted; no push or new version/tag was performed. Subsequently, the six changed Lua files were deployed to the user-requested staging folder with verified backups and SHA-256 matches on 2026-10-23. User Elite Four playtesting is pending.

## Diff and merge

Changed main.lua, InteriorCivic.lua, ParadeCull.lua, ShadowMap.lua and Voxel3D.lua;
added ParadeSwitches.lua. No destination-only files were removed.
Reconstructed the earlier donor baseline from f11c3e8 by reversing only the
four a07146b production-file changes. Verified reconstructed bytes against the
original import SHA-256 inventory (allowing CRLF/LF normalization), then used
three-way merges to retain the local fixes. No text conflicts occurred.

The donor's CommunityVisuals, ItemPokeballs, LegendaryVisualsPreset and VoxelScene
copies lack our latest controls. Those four destination files remain unchanged.
The merged main.lua retains seasonal preset registration, optional item-ball
menu integration and exported version 1.11.2. Manifest, name, description and
provenance are unchanged. No donor media or historical validation archive was
imported. PNG/JPG/JPEG exclusions remain; no raster files are tracked.

## Incoming behavior

- Elevator panels mount against the north wall; Celadon store elevator door
  openings no longer sit behind plaster, skirting or wainscot rails.
- Scene depth defaults to owned, non-readable depth (TEST266). Depth-dependent
  water, underwater capture and depth-overlay consumers skip their sampled-depth
  paths in that mode. The SCENE DEPTH row restores TEST265 readable depth.
  This is a diagnostic policy, not proof of a handheld crash fix.
- Shadow draws copy the completed map into a separate read canvas. Allocation,
  bind or draw failure retains the original-map fallback. The extra canvas costs
  about 16 MiB at 2048 square plus one copy draw per shadow redraw.
- Native and parade cullers share an exception-safe range handoff, preserving
  visible spans through wrappers that forward only five arguments. The repair
  avoids repeating a full range list for every grouped span. Diagnostic switches
  and the test267cull1 log beacon are included as supplied.

## Validation performed against merged code

LuaJIT 2.1 compilation: all 345 production Lua files pass.

Supplied suites run with Lupa Lua 5.4 (as their notes request):
- test267/integration: 4,487 checks / 48 matrix frames.
- cullhandoff/cullhandoff: 23 checks.
- test267/culling-geometry: 300 camera/offset/curve cases.
- test267/beacon: passes.
- paradeswitches/paradeswitches: 12 checks.
- test266/depth-isolation: 873 checks.
- test264/ride-only: 68 checks.
- test258/replay: 185 checks.

Additional LuaJIT 2.1 runs (table.unpack alias supplied to portable fixtures):
- shadowcopy/shadowcopy: 212 checks; uses a scratch copy of the merged libraries
  plus the supplied baseline reference that the fixture requires.
- test266/elevator-regression: 211 geometry checks.
- test247/mart-stairs: 43 checks.
- tests/legendary_world_off_test: 30 checks.
- tests/item_ball_setting: passes all sprite/mesh, preset and persistence guards.

Initial Lua 5.4 elevator/stairs runs stopped on the absent math.atan2 extension;
rerunning with the target LuaJIT runtime passed. The first shadow test lacked its
baseline under the production root; the isolated scratch fixture supplied it.
No production code or assertions were weakened to obtain these passes.

Git whitespace and preservation checks passed. These are static, geometry and
mocked-renderer tests, not GPU/gameplay evidence. No game, save or options were
changed. Native rendering, companion combinations and the Pocket FIT/Adreno
parade timeout remain unverified here. The donor's reported device evidence is
historical; the relation of the reproduced culling defect to its crash remains
an inference in the author's findings.
