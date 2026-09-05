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
