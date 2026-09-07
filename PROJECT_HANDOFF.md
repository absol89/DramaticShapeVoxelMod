# Requested world-feature restoration — 2026-09-06

Audited the active `DramaticShapeVoxelMod` checkout on local `master` at
`278862b`, loaded by `mods/BATTLE_ART_VOXEL_FORK` through its directory link.
Changes below are local working-tree changes; no commit, push or release made.

## Findings and changes

- PR #41 (`dfc177c`): newer `ladder_up`/`ladder_down` pins bypassed its
  standee geometry. Restored the original `ladder` pins and two-voxel prop
  depth. The newer shaft builder remains available but is not selected by
  the shipped cave ladder pins. This restores the requested source-art
  ladders without changing the game's warp or collision data.
- Heal alignment (`c083147`): `HealOverlay.lua` survived, but main.lua no
  longer called it and Voxel3D no longer exposed the required depth value
  and texture. Restored all three connections, including animation-state
  restoration when field FX throw.
- Player water reflection (`55e195d`): restored the planar cast canvas,
  reflected billboard transform, water-shader compositing and cleanup.
  The existing water setting and readable-depth/canvas fallbacks still apply.
- Immediate cut-tree removal (`7991ccee`): restored prop ownership spans,
  cached span serialization, targeted mesh uploads and the block-edit hook's
  coordinates/map/old-block arguments. Adapted span declarations to the
  current sink order and kept enlarged Legendary tree ownership on its
  authored cell. Unowned border geometry cannot extend a preceding prop run.
  Mesh cache revision is now 32 so pre-restoration records cannot be reused.

The cut fix retains the current terrain and neighbouring map caches and
removes the changed prop immediately. It still marks the edited map for a
budgeted background rebuild, just like the linked commit. This is not a
claim that all rebuild work or every possible frame-time spike is eliminated.
The format/ladder change requires caches to be rebuilt once after upgrading.

## Verification

Run from the engine root with `DS_MOD_PATH=dev/DramaticShapeVoxelMod`:

- `cave_ladder_test.lua`: 38 checks; updated its dead-pin check to recognize
  the newer explicit `sapling_tiles` detector metadata.
- `heal_overlay_test.lua`: 63 checks.
- `water_cast_reflection_test.lua`: 47 checks.
- `cut_drop_test.lua`: 22 checks.
- `restored_world_features_test.lua`: 22 checks covering actual registered
  pipeline calls, heal error recovery, the real Map:setBlock hook, the water
  pass/player transform connection and reflection error recovery.
- `cut_mesh_refresh_test.lua`: 10 checks covering table-sink spans, zeroed
  vertex uploads, retained drawable terrain and unaffected neighbour cache.

Run from the mod root:

- `voxel_build_budget_test.lua`: 35 checks.
- `voxel_mesh_disk_storage_test.lua`: 6 checks.

These are headless/mocked checks using the local LuaJIT/Lua 5.1 runtime, not
in-game visual, GPU-shader or Android performance validation. Lua syntax and
Git whitespace checks also pass.

Broader suites attempted but not passing: `battle_art_voxel_fork_test.lua`
exceeds Lua's 200-local limit; `voxel_visual_object_filter_test.lua` lacks a
CommunityVisuals fixture; `companion_main_uninstall_integration_test.lua`
has a platform fixture without `metalRenderer`. Those suites need separate
harness maintenance. Historical shaft-specific Astra ladder tests describe
the superseded ladder design, rather than this requested PR #41 restoration.

## Follow-up: platform-independent OFF and crash audit

Removed the unsuccessful iOS OFF-to-FULL override. OFF now skips all automatic
voxel cache storage probes/reads, preload planning, and speculative destination
work on every platform. Live geometry still builds cooperatively and its records
remain in session RAM, even without a persistent storage backend. Manual cache
generation/saving remain explicit actions. Added cancellation that preserves jobs
promoted to live terrain, and guarded the remaining direct GC call.

71 cache-policy checks pass, alongside the 243 earlier targeted checks. The map
audit completed Pallet, Route 1 and Celadon geometry against local Yellow data;
Celadon and Route 1 have materially larger geometry footprints than Pallet.
No iOS crash log was available, so memory pressure is a lead, not a confirmed
diagnosis. See `docs/OFF_MODE_CRASH_AUDIT.md` for exact semantics, measurements,
test coverage and the limits of these checks.

## Master integration — 2026-09-07

Fast-forwarded local master from `278862b` to `7743de9`, including PR #47
(museum fossils/cave corners) and PR #48 (Safari scenery/interior textures).
The remote advanced from two to four commits ahead during the fetch.

Reapplied all pending local edits and untracked documentation/tests, including
the user's manifest version `1.10.4`. The sole textual conflict was the cache
revision: upstream used 33 and the local span restoration used 32. The combined
geometry and record format now use revision 34. Local edits remain unstaged and
uncommitted; no push was made. A named safety stash retains the pre-integration
working tree.

The 314 targeted local checks pass on the combined code. Upstream museum,
Safari wall/stair, NATURE underlay, and real-map retaining cave/corner tests
also pass. The real-map test used local Yellow data. Syntax/whitespace and
unmerged-path checks pass; mobile gameplay remains unverified.

## Gen 4 tight atlas migration (2026-09-07)

Inspected `dev/gen4_front_tight-1.10.3` (770 regular/shiny PNG atlases).
Compared every frame against installed originals after a constant per-animation
translation: no altered visible pixels, clipped pixels, or empty frames. All
sheet dimensions match supplied metadata. Species, paths, timings and frame
counts are unchanged. No Unown PNG is supplied (existing metadata also refers
to an absent unown.png).

Merged only frame dimensions into both Gen 4 data tables, retaining original
sizes as legacyLayout. AnimatedBattleArt selects tight or legacy cells by exact
sheet dimensions, so incremental asset overlays remain compatible. No assets
were copied; the owner will overlay supplied assets onto the mod assets folder,
retaining files absent from the pack, then restart. Do not overwrite the merged
data tables with the supplied ones: that removes legacy compatibility.

Keep Summary BATTLE ART fitting: 580/770 opaque animation bounds exceed 56x56;
removing it overlaps name/HP/number UI. Existing fitting already uses scale <=1
and does not downscale artwork whose opaque bounds fit. Cropping preserves the
visible art size, so it cannot eliminate required fitting. Dex uses native
frames and benefits from reduced padding. Runtime/device visual QA remains
outstanding. Decoder and interface playback: 55 checks pass; metadata-only
comparison and Lua syntax checks pass.

## Interface scaling and Android title banding (2026-09-07)

Added INTERFACE SCALING: FIT/FULL (default FIT) beside INTERFACE SPRITES in
POKEMON ART. It applies to BATTLE ART Summary and Dex Image adapters. FIT uses
56x56 opaque-union fitting; FULL uses complete native prepared frames. Switching
is live and retains animation progress. FULL may overlap the stock screen UI.
Title rendering is independent. This supersedes the previous decision to keep
status fitting mandatory; the user explicitly requested FULL as a test option.

Android screenshot (user reports engine 0.2.56) shows horizontal bands on Ditto.
A suspected contributor is fractional display scaling of the title alpha-mask
true-color replay, previously one scissored pass per horizontal pixel run.
Coalesced identical consecutive runs into taller rectangles without changing
covered pixels or trainer exclusion. This reduces internal scissor boundaries
and draw calls, but is a mitigation, not a confirmed Android fix. Engine renderer
also has DPI-aware scissor rounding; device scaling and GPU behavior still need
verification. Ask tester to compare integer display scaling if bands persist.

Mocked interface/title tests: 3169 checks passed, including pixel-by-pixel mask
coverage, trainer occlusion, FIT/FULL live changes, and animation. Lua syntax and
git diff whitespace checks passed. No actual Android/device visual test performed.

## FULL interface anchor correction (2026-09-07)

User screenshots show padded Dewgong/Croconaw frames positioned too low. FULL
now removes shared animation-wide transparent margins and top-aligns visible
art at native resolution in a canvas at least 56x56. Oversized art retains all
pixels and can overlap UI. FIT is unchanged. Shared bounds preserve authored
animation motion. Native and fitted results use separate caches. Synthetic
production-fitter tests verify pixel preservation, top alignment, motion and
cache separation; device visual verification remains outstanding.

## Status centering and installed deployment (2026-09-07)

FULL Summary portraits now center within x=0..71; wider canvases start at x=0
to preserve the left edge. Only the sprite draw and matching true-color mark
move; scoped wrappers restore on errors. FIT remains unchanged. Kanto-Reforged
installed ui/summary_ui.lua labels now use ATK, DEF, SPEED, SPATK, SPDEF to
fit before three-digit values. Companion patch staged separately at
D:/gen1recomp/.codex-temp/interface-deploy/summary_ui.lua.
Compared tracked Battle Art runtime/data/shaders/main/manifest to installed
BATTLE_ART_VOXEL_FORK and copied only differences (2 files); also deployed
1 companion UI file. All copied hashes verified. Backups retained at
D:/gen1recomp/.codex-temp/interface-deploy/backup-20260907-030042.
No asset copying or deletion. Local playback/centering tests passed; in-game
visual verification requires restart.

## FULL Dex vertical centering (2026-09-07)

FULL Dex sprites now center vertically in the 72-pixel portrait area including
the number row, clamped at y=0 for oversized art instead of stock 64-h which
clips the top. Number remains drawn over the sprite as authorized. Matching
true-color marks move with the sprite; FIT is unchanged. 3173 mocked interface
checks and syntax/whitespace checks pass. Deployed InterfaceSprites.lua to the
installed BATTLE_ART_VOXEL_FORK with backup and matching SHA256. Device visual
verification remains outstanding.

## First-pose Dex anchor (2026-09-07)

Per user correction, FULL Dex vertical position now uses the first prepared
frame opaque y0/y1, not maximum animation/canvas height. Subtract first y0
from centered placement, keeping placement constant across animation. Shared
canvas still preserves pixels; it does not determine placement. Status remains
unchanged (user approved Charizard). 3173 mock checks and syntax/whitespace pass.
Deployed InterfaceSprites.lua with backup and SHA256 verification. Actual
animation stretching is not established by the screenshot; native pixels are
not rescaled by this anchor change. Device visual confirmation remains pending.
