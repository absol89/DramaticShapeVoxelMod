# ROM backsprite alpha and PR #62 - 2026-10-26

PR #62 was merged as 3051809, preserving Code-Grub's original commit and its
explicit low-alpha GAP opt-out. This follow-up adds the user-reviewed ROM back
corrections separately. The reference report and private images remain outside
Git; only selective coordinate hints, pattern hashes, code and tests are added.

## Result and scope

All 151 Red backsprites were compared with the user's gen1 backup. The reference
is an exact 2x enlargement of native 28x28 art; all dark outlines match within
that crop. There are 49 corrected patterns: 646 excess opaque pixels removed and
190 missing body pixels restored. Original black/grey pixels are preserved.
Nine sprites have 194 additional source-ink pixels outside the reference crop;
those pixels remain unchanged. The published report lives in engine workspace
tmp/rom-back-fill-lab/reference and is not distributed with the mod.

The new data/rom_back_alpha_hints.lua contains only the reviewed RLE alpha-edit
hints and palette-independent fingerprints, not sprite pictures or palettes.
RomBackAlpha identifies the original 32px picture using alpha plus first-seen
color classes. Distinct palette recolors, including inversion, preserve identity.
Changed art, soft alpha/GAP tags, wrong dimensions, collapsed palettes and unknown
patterns do not match. All 49 corrected patterns also match the local Yellow
source images; Blue and mobile runtime behavior have not been tested.

Only the player's back pic enters the identification path. Fronts, trainers,
external art and the existing shiny bypass retain their previous ownership.
Transform can resolve by the actual picture rather than the party species name.
A matching source mask is applied after ordinary fill, using paperColor from the
current baked image. Black fades therefore restore black paint, not white.
PR62's nonzero GAP alpha remains untouched, including at an ADD-hint coordinate.
The cache distinguishes masked/unmasked uses of the same baked image; source
identities are cached weakly and invalidated with BattlePics.

## Validation

- Combined synthetic regression: 25 checks for tags, unchanged/modded art,
  palette recolor/inversion, original-white removal, missing paint, black fade,
  separate cache contexts, invalidation and graphics target/blend restoration.
- Production data/code against all 151 actual Red sources: 49 recognized hint
  patterns, 154,624 output alpha pixels and 151 recolored identity comparisons.
- 347 production Lua files compile under LuaJIT 2.1.
- SDK actual mod loading / RAM OFF integration: 26/26.
- Oversized billboards: 13 checks. Legendary OFF: 30. Item-ball regression: pass.
- Existing monolithic battle_art_voxel_fork_test cannot parse under LuaJIT:
  main function exceeds 200 locals at line 2604, before production code runs.
- Existing battle_scene_visual_sidecar_test has an incomplete fixture: unexpected
  SafariReserve dependency. Neither unrelated test was weakened for this change.

Live GPU evidence uses an isolated portable copy of the user's packaged engine
0.2.41 from D:/Games/gen1recomp-win64. Fresh Red fixture, ROUTE_1 cell (5,8), ROM
back art, WORLD placement, voxel 35 degrees, Legendary OFF, level 25 player vs
wild Pidgey 15. Inspected screenshots of Fearow, Pikachu and Jigglypuff show the
correct silhouettes. GPU readbacks assert 154/19/0 changed pixels respectively
against the original fill. No player save loaded/written; the fixture auto-quit.
Existing HUD/terrain artifacts in this old fixture were visible before this work
and are not part of the alpha correction.

Evidence and driver: engine workspace tmp/rom-alpha-integration. Four production
files were deployed to the requested live mod folder with SHA-256 verification;
originals and deployment.json are in live-backup-20261026-010638 there. Manifest,
version/provenance, assets, saves, player options and caches were not overwritten.
Restart before testing. No Android/iOS visual claim or new release tag.
