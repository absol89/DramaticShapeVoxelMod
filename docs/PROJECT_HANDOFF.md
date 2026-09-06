## Safari and interior texture follow-up (2026-09-06)

Ported the approved desktop candidate onto master after PR47. See SAFARI_INTERIOR_REWORK.md for scope, preserved upstream changes, exact-checkout tests and platform limitations. Mesh cache revision33; no manifest version change. Horizons artwork remains separate.

## Museum cases and exterior cave/cliff repairs (2026-09-06)

Based on current master after merged PR46. MuseumFossils replaces only the two
exact first-floor fossil displays with Kabutops/Aerodactyl skeletons in framed
glass cases. Solid geometry uses the existing atlas and chunk mesh; glass uses
10 low-alpha panes with graphics state restored. Two exhibits add 12,576 solid
vertices. Cache revision32 invalidates prior geometry. No map or collision edits.

Exterior retaining cave mouths use a six-pixel recess and stepped stone crown.
The exact 55,19/19,39 upright cliff-corner pattern uses stone rather than the raw
blue diagonal sprite. A local shade helper handles scalar and corner AO shading.

Validation: portable museum placement/bounds/fallback tests; private real Route4
geometry regression (88 recessed mouth vertices, stepped heights9/12/13,70
corner faces without tile19 UV). Desktop native captures verified museum views
with engine0.2.27. Exact0.2.53 and Quest performance remain unverified. Desktop
Astra19 backport installed separately with backups; PR preserves current upstream.

## Absol follow-up: building backs, entrances, cave exits and scrolls (2026-09-05)

Separate follow-up to merged PR #45, integrated with master38e389c (1.10.3).
No live installation is included in this source change.

- `data/voxel_heights.lua`: 29 exterior families use rear wall courses instead of
  mirrored front doors/signage. Occupancy, front art and the authored roof remain.
- `lib/FacadeEntrances.lua`: guarded real rear entrances at Cerulean's badge and
  robbed houses, Celadon Mansion, Route 5/6/12 gates and Fuchsia Good Rod house.
  Route 23's north badge-gate receives visible doors. PLATEAU deliberately uses
  its exact map/warp guards because the engine classifies it as indoor for SFX.
  Existing Route 7/8 side entrances are preserved.
- The department store and Warden's house have no corresponding rear warp in
  the generated game maps. Their backs are cleaned; no fictional exit is added.
- `lib/CaveExitVisuals.lua`: eight real outdoor cave mouths across seven maps
  gain a bounded recessed opening and local daylight panel. The panel stays
  ahead of neighboring rock facets; existing maze walls and ladders remain.
- `lib/HangingScrolls.lua`: four scrolls in Oak's lab and Fighting Dojo gain
  thin paper, raised rollers and plain backing rather than repeated glyph caps.
- Structures/Buildings integrate the modules; disk mesh cache revision is31.
  No gameplay, collision, warp, input, global lighting or provider API changes.

New focused suites validate source donors, geometry, placement guards and map
preservation. Historical snapshot tests restore only the historical rear material
configuration in memory; a separate 19,496,504-check suite tests all29 live rear
families. The ship source comparison normalizes CRLF/LF only.

Pre-1.10.3 candidate audit:75/77 portable commands passed, plus3/3 inherited Stadium
suites; all108 production Lua files compile. The two failures (voxel seam AO
and legacy Legendary visuals) reproduce on the submitted PR45 baseline.

The 1.10.3 integration preserves upstream startup/portrait/platform changes.
Both updated portrait and platform regression tests pass; all108 production
Lua files compile. Follow-up geometry files remain byte-identical to the
validated candidate.

Native comparison uses a private Windows Gen1Recomp0.2.27 runtime and copied save.
Inspection cameras may occupy non-walkable positions; they are visual evidence,
not an occupancy or route-traversal claim. Exact0.2.53 and Quest headset validation
remain pending. No whole-game performance measurement is claimed.

## Oak intro vertical placement: 2026-09-05

Battle Art marks its 96px custom Oak intro portrait with an 8px vertical
offset. The paired Gen1Recomp intro change applies it only while oakPic is the
active picture, so Pokemon, player, rival, battle portraits and ROM Oak retain
their positions. Both Gen 1 and Gen 2 intro renderers honor the field.

## iOS Voxel Companion sandbox fix: 2026-09-05

VoxelCompanion no longer indexes the forbidden love.system namespace while
building its informational platform field. The existing sandbox-safe LÖVE 12
Metal renderer probe identifies iOS; other platforms use neutral UNKNOWN
metadata. This field does not select rendering behavior. A regression test
uses a sandbox proxy that throws on love.system access and passes both paths.

## Route 2/Cerulean Legendary wall build fix: 2026-09-06

PR45 replaced shadeTimes with plane-aware shadeRect for detailed masonry but
left five calls in retainingCaveMouthSide. Legendary WALLS & LEDGES therefore
failed outdoor meshes containing the Diglett's Cave or Cerulean Cave mound
with `attempt to call global 'shadeTimes' (a nil value)`. The small scalar and
per-corner multiplier is restored specifically for passage return faces.
Terrain shading and real-map cave-exit regressions pass. Gameplay retest is
pending; unrelated working-tree edits are preserved.

## Oak portraits and player animation default: 2026-09-05

PLAYER ANIM defaults to GEN 1 (saved selections retained); TRAINER ART remains
GEN 1. Oak trainer lookup prefers front-static/<trainer generation>/prof.oak.png
and falls back to prof-oak.png, then ROM. The public intro.oak_speech.build hook
uses that same resolver for the Gen 1 new-game portrait. Generated assets are
untouched. Routing tests cover all three generations, legacy/missing assets,
intro replacement, ROM mode and existing Choose Your Hero behavior; they pass.
Modified Lua files compile. Phone/gameplay confirmation remains pending.

## PR 45 integration: 2026-09-05

Merged PR 45 atop 6e99ed5 without conflicts or content overrides. Review was
limited to the six user-named integration files. Their Lua syntax checks pass,
as do pillar cache/layout (25), terrain shading (34), disk storage (6), battle
sidecars (37), and hosted trainer/ball tests. Cave-step and public-stair tests
could not initialize because external ASTRA fixture paths were not configured.
No new in-game validation was performed. The PR retains its documented 0.2.53
playtest limitation. Release tag and installed mod are not changed by this merge.

## Flat Stadium trainer and Pokeball pass: 2026-09-05

User confirms backgrounds, HUD and Stadium FX now work in all flat fills.
Flat hosting previously skipped BattleScene's trainer and normal-ball pass.
The Stadium overlay now invokes that shared pass, prepares the trainer lifecycle
without capturing sprite cards, and publishes actual trainer draw success.
Voxel3D can borrow an active host target without clearing or rebinding it;
the host camera is translated into Battle Art arena coordinates. Both normal
and flat passes use the same trainer callback, ball clock, meshes and beam.
Graphics/camera state is restored on success and failure. OFF retains its path.

Seven targeted LuaJIT suites pass, including borrowed-target preservation,
translated camera, ball ticking and companion-error cleanup. These are mocked
checks; in-game trainer/throw appearance still needs user verification.
Master and tag are unchanged.

## Sprite FX anchors and background ordering: 2026-09-05

stageShot now publishes the active Stadium scene's logical uiAnchors and exact
animationProjection scale through BattleStage. FX consumers therefore remain
in the host-projected animation layer for species without skeletal models,
instead of redirecting to a surface with missing bone coordinates. Explicit
host scale/backPinned metadata takes precedence over ordinary Battle Art values.

The backdrop shader places plates at far depth; Stadium image drawing uses
lequal without depth writes and preserves the host depth attachment. Found an
additional installed-only edit using always/depth-write plus next(ctx) after
the image; it would block models and repaint the sky. That installed edit is
replaced by the source fix and retained in a backup.

Five targeted LuaJIT suites pass. A real LOVE GPU test draws foreground green
geometry first, then GEN6/PNG red plates: pixel readback retains green geometry
and replaces blue sky with red. In-game FX and artwork confirmation pending.
No Stadium Battle FX companion changes are needed. Master/tag unchanged.

## Flat hosted frame/HUD follow-up: 2026-09-05

Captured diagnostic: BLUE/BOTH statusAvailable=true, suppressed=false, but
nativeShot=true during Stadium HUD capture. The native Battle Art HUD wrapper
therefore skipped capture as already snapped. Companion capture now clears
both native/hosted shot markers temporarily and restores them even on errors.
A ready, non-defective Stadium scene now also prevents Battle Art from rendering
or publishing a second normal shot in flat modes. Failed/other scenes retain
the normal fallback. This removes competing normal-frame composition while
Stadium retains background-hook ownership for GEN6/PNG/WHITE/BLUE.

Six targeted LuaJIT suites pass across the two repos, including stale-marker
capture and frame-ownership regressions. A real LOVE 11.5 hidden-window GPU
probe successfully executes WHITE, GEN6 and PNG background draws. That probe
uses a generated image; it is not in-game or installed-asset visual validation.
Deduplicated diagnostic records are retained to verify the next in-game run.

## Issue 44: unified hosted UI, 2026-09-05

BattlePresentation now exports drawHostedUI. The companion Gen1 compositor
hands Battle Art a clean scene copy plus a scoped native HUD capture, bypassing
Stadium glass panels in every arena mode. Native hosted textbox drawing uses
Battle Art's fill/ink path; the native HUD pass is skipped after composition.
HUD-only also suppresses Battle Art frosted backpanels. Existing foreign UI
visibility claims remain respected. No battle model/camera logic was changed.

Tests: visibility matrix across 4 modes and 5 fills, native/hosted text gates,
HUD bands, settings/styles, and companion compose handoff pass under LuaJIT.
The paired fix requires the importer gen1_battle.lua change. In-game visual
checks, including prompts and party balls, remain pending. Master and tag are
not moved by this fix.

## S.S. Anne cabin details: 2026-09-05

Added white bulkhead tops, source-based hollow mugs and raised bunk bedding.
Cache revision30. Current port:71/73 test commands pass (two known upstream
failures),105 production Lua files compile. Astra22 native0.2.27 captures cover
8 matched views; target0.2.53/Quest playtests remain pending. No live install.
See ASTRA_WORLD_ART.md and astra_cabin_details_test.lua for final scope/evidence.

## Astra world-art PR preparation: 2026-09-05

Integrated the cumulative Astra21 art work onto c3b0ae8 in an isolated
Legendary-Additions checkout. See [ASTRA_WORLD_ART.md](ASTRA_WORLD_ART.md) for
scope, file ownership, reproduction instructions and evidence boundaries.
Current companion/provider APIs, cave behavior and cache layout are retained;
geometry cache revision is 29. Manifest and engine gameplay files are unchanged.

Current checkout: 57/59 art commands pass; both failures reproduce on untouched
upstream. All 13 current upstream feature checks and 105 production Lua compile
checks pass; pillar cache test passes 25 assertions. This is mocked/source
validation. Historical Astra21 native screenshots were captured on engine
0.2.27; a native 0.2.53 playtest and Quest validation of this port remain pending.
Prepared locally for review; no PR, push or live installation performed.

## Independent Stadium switches: 2026-09-05

BATTLES OFF uses the existing non-Stadium2 hosting path. BATTLES ON/MODELS OFF
keeps the Stadium2 host and offers both Battle Art sprite cards in voxel mode;
flat backgrounds continue through native sprite rendering. Companion source
change in dev/stadium2-importer on codex/independent-battle-model-switches removes
the model requirement from Gen1 hosting and releases actors while MODELS is OFF.
The installed importer is a separate copy and has NOT been updated. Apply the
sibling stadium2-independent-switches.patch to that companion for this behavior.

Validation: independent importer switch matrix plus Battle Art Stadium depth,
background and model API tests pass. Gameplay testing remains pending.
Shiny routing already uses shiny variants (BattleArt.isShiny and importer's DV
check); extraction creates normal/shiny packs using configured palette pairs.
This does not verify the palettes in the user's existing imported cache.

## Hosted trainer duplicate: 2026-09-05

Inspected the installed red_3d_player provider: drawBattleTrainer returns true
when it draws successfully. BattleScene now includes that result in its shot.
The Stadium-hosted native picture path uses it to omit the player's 2D trainer
intro while retaining the enemy slot. Failed/absent provider draws retain the
native fallback, and Pokemon drawing resumes after the intro. No companion
files were changed. Hosted trainer visibility, BattleScene sidecar/shadows,
and Stadium depth tests pass. In-game confirmation remains pending.

## Stadium visibility follow-up: 2026-09-05

The importer source shows visualActor() can return nil despite a loaded model:
it is gated by readyFrame, send-out, and temporary battle visibility. Corrected
Legendary sprite fallback to consult host.actors.player as well as the visible
actor. Actual model rendering still uses visualActor(), preserving hiding and
send-out behavior. The workspace mods/BATTLE_ART_VOXEL_FORK junction targets
this checkout; the running process's source path could not be verified.

Stadium depth, background API and models API tests pass, including a new
loaded-but-hidden player regression. This is a code-confirmed fallback defect;
confirmation that it resolves the user's persistent sprite symptom is pending
an in-game retest after restart.

## Stadium player model regression: 2026-09-05

Corrected the integration's unconditional Legendary player-card preference.
A live Stadium player model now takes precedence over the Legendary sprite
fallback, retaining both model draw passes and its shadow caster in the shared
voxel depth attachment. Standing trainer mode only selects the player card
when Stadium has no player model. This supersedes the unconditional player
model/shadow skipping described in the original integration notes below.

Validation: Stadium circle depth, background API, models API, BattleScene
sidecar/shadows, and battle UI visibility tests pass under LuaJIT. Regression
coverage includes Legendary enabled with both models, missing player model,
and model restoration, checking card ownership and shadow/draw counts.
The shared-depth and circle placement assertions still pass. In-game visual
confirmation with Stadium battle/models ON and overworld enabled is pending.

## Battle UI visibility: 2026-09-05

Added BATTLE ART UI to the battle options and mod-manager schema. BOTH is the
persisted default; TEXTBOX hides Pokemon HUDs and their panels, HUD hides
textbox ink and fill, and HIDE hides both. Existing textbox fill and HUD color
choices remain saved and retain their existing arena-color rules. The setting
uses BattlePresentation suppression, preserving companion claims and normal
non-staged engine UI. Battle input and state handling are unchanged.

Validation: battle_ui_visibility_test.lua, textbox_options_test.lua and
textbox_style_test.lua pass under LuaJIT. Coverage includes all four modes,
fill/palette combinations, panel visibility, cached HUD clearing, persistence,
companion suppression and unstaged fallback. Changed Lua files compile.
companion_main_uninstall_integration_test.lua has an existing fixture failure
(indexing a function in main.lua); reproduced against the preceding commit.
No in-game visual validation performed.

# Integration update: 2026-09-05

Current branch: `codex/legendary-1.10.2-integration`, created at the user's
request from `1.10.2-fixes` (`61dc730`). Merged PR #43 (`b914575`), retaining
both histories. The older handoff below describes the contributor's setup,
not an inventory of this workspace.

- Kept model shadows independent of sprite lighting, alongside Legendary ball
  shadows and world props.
- Combined Stadium shared-depth models/circles with Legendary player cards.
  The player model and its shadow are skipped when the Legendary card owns
  that slot; failed frames release ownership. Kept cave camera registration
  and the Legendary battler priority.
- Retained LOVE 12 orientation gating, build budgets, Choose Your Hero support,
  and the documentation move from the fixes branch.
- Restored the normal package name, description, and 1.10.2 version in the
  manifest; aligned the exported version. This is an integration, not a release.
- Updated test fixtures for the additional Legendary dependencies and package
  identity; added mixed player-card/model, failure fallback, and cave-camera
  regressions.

Validation: 11 targeted test files passed under Lupa's LuaJIT 2.1 runtime:
Stadium circle depth, Stadium background API, BattleScene visual sidecars,
Stadium models API, Choose Your Hero, renderer orientation, voxel build budget,
and Legendary tests 46-49. Syntax compilation passed for 180 of 181 Lua files.
The existing battle_art_voxel_fork_test.lua exceeds LuaJIT's 200-local limit;
confirmed unchanged failure on the pre-merge fixes branch. No game or Android
visual validation was performed. Before release, check Legendary on/off,
Stadium cave/outdoor battles, circles and occlusion, capture effects, selected
trainer art, and model shadows with sprite lighting on/off.

---

# Legendary Battle Art handoff

Updated 2026-09-03. This task continues the complete text history of
**Battle Art Voxel Options**, read through its first message. Historical generated
downloads and screenshot contents are not automatically verified by reading chat.

## Checkout inspected

- User fork: https://github.com/ltzLegend/DramaticShapeVoxelMod
- Active branch: `Legendary-Additions`.
- Starting HEAD: `34ab87535cacb0ec2644f4de65c6bd00d91496b6`.
- Manifest: `BATTLE_ART_VOXEL_FORK`, version `1.10.2`, API 2, Gen 1.
- Working tree was clean before these handoff documents were added.
- Recent commits include `0e31212` (Legendary world visuals and trainer bridge),
  `dee4221` (LEGENDARY SUPPORT), and `34ab875` (Stadium shadows in flat fills).
- This checkout already has community visuals, granite pillars, smooth sky,
  Legendary Pokeballs, and `mod.exports.characterRenderers`. Do not re-transplant
  old ZIP builds over it.
- `lib/StadiumModels.lua` connects to `STADIUM2_IMPORTER.exports.models`, requires
  API version 2 and `newInstance`, and honors importer model/battle toggles.

## Product direction

Legendary Visuals is Legend's optional visual expansion of Absol's Battle Art.
The original transplant used TEST435 as the environment source and Battle Art
1.10.0 Community Pillars PR Test1 as the destination. Preserve the creator's
newer architecture and make individual features reversible to Battle Art defaults.

Battle Art owns the scene; companion mods own their models, character assets,
and UI. The desired Pokemon model selection is Stadium 1 for Dex 1-151 and
Stadium 2 for Dex 152-251, with a shared shadow path and safe sprite fallback.
That model routing is a goal, not verified as implemented in this checkout.

## Latest historical test context

The user moved to Gen1Recomp 0.2.53. The chat's latest named builds were Battle
Art TEST13, Red 3D Player TEST111, Gen1 True 3D Characters TEST5, Stadium
Overworld TEST8, and Battle Cinematics TEST2. These labels are not a verified
inventory of local packages or currently installed mods.

- The user confirmed 3D characters returned after the Stadium companion's
  renderer stopped bypassing character providers (TEST7).
- TEST8 was delivered to fix glass/emissive state leaking onto NPCs; the chat
  does not establish a subsequent clean gameplay confirmation.
- Cinematics TEST2 was delivered with a supported input path in place of the
  rejected `love.touchpressed` override; field testing remained pending.
- The cyan battle line was ultimately confirmed by the user to be Quality of
  Life's separate EXP bar. Disabling it fixed the line. Earlier UI/smoke
  diagnoses in the chat were superseded.
- Colosseum options and Continue/naming screens had compatibility fixes in
  earlier packages. The supplied upstream UI 2.2.5 is not assumed to include them.

## Priority queue

1. Field-test TEST9's mobile-import logger fix on Android. The supplied TEST8
   companion has now been patched with protected warning logging; see below.
2. Validate Stadium 1 shadows and Stadium2/Johto compatibility against the
   current provider interfaces. Audit the recent shadow commit before patching.
3. Cut Legendary wall/slope geometry around cave entrances, starting with
   Diglett's Cave, then audit other cave mouths and doorway transitions.
4. Correct NPC scale and flowers clipping into characters.
5. Polish tall grass and flowers.
6. Improve tight-space camera fallback: try alternate angle, preserve distance
   where possible, modest FOV adjustment, elevation as the last fallback.
7. Field-test Battle Cinematics TEST2 with the integrated setup.

## Importer investigation in this task

- No `StadiumInstall.lua` or Stadium 1 companion ZIP exists in this repository.
- The earlier chat's `STADIUM2_IMPORTER-0.12.1.zip` attachment is readable from
  its temporary attachment location. Its manifest identifies Stadium2 Importer
  0.12.1, supporting Gen 1 and Gen 2. The archive contains no `StadiumInstall.lua`.
- The user subsequently supplied Downloads/LEGENDARY-STADIUM-OVERWORLD-MODELS-
  BATTLE-ART-TEST8-CLEAN-CHARACTER-SHADERS.zip. Its manifest identifies
  `LEGENDARY_STADIUM_OVERWORLD_MODELS`, version `0.1.57-ba.8`.
- Confirmed `lib/StadiumInstall.lua` calls `V.log:event` after opening the ROM.
  TEST9 replaces that block with a function-checked, protected `warn` call.
  This implements the fix described in the earlier conversation.
- The user then supplied `C:/Users/User/Downloads/StadiumInstall.lua`.
  Comparison against TEST8 confirms its only source change is replacing that
  event call with warning logging inside `pcall`. TEST9 implements the same
  fix with an explicit function check and direct `pcall`; comments and log text
  differ. No other importer changes from the supplied file are missing.
  TEST9 was retained without repackaging; Android validation is still pending.
- Output: `C:/Users/User/.codex/visualizations/2026/09/03/01a069a9-735b-7e63-9133-cbe4dda33876/LEGENDARY-STADIUM-OVERWORLD-MODELS-BATTLE-ART-TEST9-MOBILE-IMPORT-FIX.zip`.
  The same directory contains `TEST9-importer.patch` and `TEST9-validation.json`.
- Version/name advanced to TEST9 (`0.1.57-ba.9`); mod identity is unchanged.
  Only the installer and manifest differ. All other entries are byte-identical;
  both ZIPs passed CRC checks, with the same 29 entries. Original ZIP is intact.
- Source SHA256: `f895701d562aec72d3aadd43ea4986bafdcaa8cdbff9382f861d3efe27848835`.
- Output SHA256: `309753d3a62d1490687b2f39ffa38dcc8b2d45373c9cf021d2f2c9aed64f3292`.

## Shadow fix, test build 1

In `lib/BattleScene.lua`, the new unconditional model-shadow loop calls each
instance directly with `ShadowMap.clipVP`. The existing
`StadiumModels.drawShadow` adapter explicitly converts Battle Art's [0,1] depth
matrix to the provider's GL clip convention. The new loop bypasses that
conversion; lit modes also reach the original adapter loop and submit again.
The new loop's result is unused, and its comment about card fallback does not
match the flat-fill branch, which skips the card loop.

Corrected `lib/BattleScene.lua` to submit each model exactly once through
`StadiumModels.drawShadow`, independently of sprite lighting. Lit sprite-card
fallback is preserved; unlit sprite cards still do not cast. WHITE/art flat
fills still discard the world shadow map because they have no world receiver;
this change does not add a new flat-floor shadow catcher.

Extended `tests/battle_scene_visual_sidecar_test.lua` to verify single adapter
submission and no direct instance calls in both sprite-lighting modes.
The sidecar/shadow suite passed 37 checks, and the Stadium adapter suite passed
18 checks, including depth conversion. Executed with the Lupa Lua runtime.
No Android visual confirmation yet. This covers the built-in Stadium2 adapter,
not the separate Stadium 1 companion's complete shadow integration.

Packaged with `tools/package_mod.ps1` as
`BATTLE_ART_VOXEL_FORK-1.10.2-SHADOW-FIX-TEST1.zip` in the repository root.
The package keeps manifest version 1.10.2; the filename distinguishes this
local test build from the previous baseline ZIP.

Cave investigation: `Structures.lua` already identifies folded door columns
with `run.door`, while `ChunkMesher.lua` can apply retaining masonry to the
entire region. Inspect door-face source tiles before changing geometry; no
cave fix has been applied yet.

## Validation and next action

This task inspected repository source, Git state, and the supplied Stadium2
archive manifest. No game or Android visual validation has been performed.
Battle Art now contains the focused shadow fix above. The separate TEST9
companion package contains the importer logging change described above.

Relevant existing tests include `tests/stadium_models_api_test.lua`,
`tests/stadium_background_api_test.lua`, and
`tests/battle_scene_visual_sidecar_test.lua`. Some suites (including
`legendary_visuals_test.lua`) require the external Gen1Recomp `tests.modkit`
harness. A local Lupa runtime was installed for standalone Lua tests; it does
not provide the game, renderer, ROM fixtures, or external modkit harness.

Next: replace TEST8 with TEST9, fully restart Gen1Recomp 0.2.53, and test a fresh
Stadium ROM import plus existing model loading. Runtime and Android tests remain
pending; archive validation does not prove import success. Test the new Battle
Art shadow build in a world-backed arena with sprite lighting on/off. Continue
the separate Stadium 1 provider investigation and cave-door geometry work.

## Cave-mouth lighting and RED/GREEN static player art (2026-09-06)

The creator-provided Cerulean hotfix replaces the temporary restored
`shadeTimes` helper with the mesher's existing `sideSolid` path for all five
recessed cave-mouth faces. This retains the repaired topology and samples the
same scalar or per-corner ambient field as adjacent masonry.

STATIC mode now exposes PLAYER ART: RED/GREEN. It follows Choose Your Hero and
extracts the first 80x80 frame directly from `back-animated/redplayer.png` or
`greenplayer.png`; authors do not need duplicate files under `back-static`.
Old explicit GREEN option values continue to select Green directly. The Green
strip is a valid 400x80 five-frame atlas and remains registered for ANIMATED.

Oak's three scripted roles now have explicit asset contracts. The introduction
calls `introOakImage()` and reads the selected TRAINER ART generation's dotted
`prof.oak.png`. `OPP_PROF_OAK` slugs to `prof-oak` and reads the hyphenated
file from that generation. Yellow's Pallet Town old-man-style Pikachu capture
sets `demoName` to `PROF.OAK`; `applyTrainers()` consequently reads the
independent `assets/battle/back-static/oak.png` back sprite.

## Phosphor Route 1 compatibility preload (2026-09-06)

Tag 1.9.6 gated CONTINUE on loading every compressed BAVC container into RAM.
The later budget ladder allowed a partial preload, while OFF skipped it and
made the Pallet-to-Route-1 transition call `mod.storage.readBytes` and LZ4
decode during play. Reports identify the old full preload as stable on iOS.

On the sandbox-safe LÖVE 12 Metal detection used elsewhere in the mod,
RAM PRECACHE MB: OFF therefore resolves to an uncapped preload. On other
platforms OFF remains a zero-byte preload with on-demand reads. The loading
screen's final `collectgarbage` is guarded because that global can be absent in
restricted mobile mod environments. This is source-tested; physical iOS
Phosphor validation remains required.
