# Legendary update 1.11.2 import review — 2026-10-23

Base: `a07146b45aee0b8525efc40062d73b426f7668df` on master.
Branch: `legendary-update-1.11.2`. Push destination: the user's `absol89` fork.
The user explicitly requires keeping a07146b's optional item-ball behavior.

## Import and preservation

Merged candidate production/data Lua and the fireworks synthesis tool into a
separate worktree. Used a three-way merge with a07146b's parent as the comparison
base to carry a07146b's item-ball changes over the candidate. No text conflicts.
The four production files differing from the candidate are ItemPokeballs,
LegendaryVisualsPreset, VoxelScene and main.lua; those differences retain the
item-ball setting, menu, presets, draw guard and shadow invalidation.
No tracked destination file was deleted. Destination-only tools, tests, docs
and assets/docs remain. The original master checkout remains unchanged.

Imported 120 new library modules, changes to 63 existing library modules,
main.lua and data/voxel_heights.lua, the Lua crowd catalog and fireworks_synth.py.
ItemPokeballs.lua was considered during merging but remains identical to a07146b.
Manifest, mod.card, README and changelog remain at the repository baseline.
Manifest and exported version remain 1.11.1; the branch name is not a release bump.

## Candidate layout and evidence

Root directories: assets, data, docs, lib, tools, validation.
Root files: CHANGELOG.md, IMPORTANT-NPC-Life-and-Elite-Four-Idle-Animation.txt,
LEGENDARY-MASTER-NOTES-AFTER-TEST108.md, main.lua, manifest.json,
MERGE1-REPORT.json, mod.card, PERFORMANCE-HANDOFF-TEST261.txt, README.md,
REPLAY-PARADE-HANDOFF.txt.

Candidate assets: battle, lance, legendary, parade, seasonal, world-fill.
The candidate has no assets/docs; the repository does, and it is preserved.
Candidate docs contains archive, seasonal26 and TEST61-BUILDING-AUDIT.md.
The root validation tree contains 2,855 files of historical checks and evidence.
These validation files were not imported. Forty-one processed documents and
notes were moved into the user's requested evidence folder with relative paths
and SHA-256 verification. The uninspected seasonal preview remains at source.
MERGE1-REPORT describes an earlier TEST134/seasonal merge, not this full candidate.
The root README/changelog/master notes also have historical build headings.

Candidate media was not published as part of this code import. Existing artwork
and OGG exclusions remain. New Lance, parade and seasonal features reference
separately supplied textures, fonts and audio; this branch alone is not a full
runtime asset package. The supplied crowd catalog is code, and its trainers.png
atlas remains separate. Asset packaging and availability need review before a
release. No deployment into the installed mod was performed.

## Checks performed

- LuaJIT 2.1 via Lupa 2.8: all 344 main/lib Lua files compile.
- All data Lua plus the crowd catalog compile; fireworks_synth.py parses.
- item_ball_setting.lua passes: sprite/mesh, reflection/shadow, preset,
  persistence and actor guards. This is the a07146b regression, unchanged.
- hosted_trainer_visibility_test.lua passes.
- atmosphere_companion_integration_test.lua passes.
- voxel_mesh_disk_format_test.lua passes (40 checks).
- Candidate test264/ride-only.lua passes against merged code (68 checks).
- Candidate test258/replay.lua passes against merged code (185 checks).
- battle_scene_visual_sidecar_test.lua stops on the missing SafariReserve mock.
- stadium_models_api_test.lua stops on the missing SafariFooting mock.
  Both failures also occur on the untouched a07146b checkout.
- The full SDK test cannot compile under LuaJIT: its main function exceeds
  200 locals at line 2604. That test is unchanged from a07146b.
- Git whitespace and staged-file scope checks passed before committing.

These are compilation, static and mocked checks. No game was launched and no
rendered screenshot was inspected. Red/Blue/Yellow rendering, real engine load,
GPU shaders, companion combinations, save flows and Android performance remain
unverified. No player save, options, game process or runtime media was changed.

## Outstanding candidate notes

The NPC priority note still marks Elite Four idle animation during dialogue,
battle introductions and menus as unresolved; scripted parade animation does
not establish that fix. The performance handoff reports crowd-card fallback and
Celadon loading stalls needing measured device follow-up. Replay handoff text
is historical: the current TEST264 code and passing checks use ride-only choices
and migrate the retired WALK value. Supplied historical validation claims are
not treated as new verification in this import.
