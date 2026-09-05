# Choose Your Hero comparison and selective port

Compared `BATTLE_ART_VOXEL_FORK-1.10.15` with this repository on 2026-09-05.
The companion's installed ID is `choose_your_hero`.

Merged only the relevant changes in BattleArt.lua, AnimatedBattleArt.lua and
data/animated_player_trainers.lua:

- PLAYER ANIM's existing `red` value is labelled RED/GREEN. It selects the
  Green five-pose intro sheet when the companion save says `player=green`.
  Other explicit animation choices, including ROM, retain their behavior.
- Yellow rival selection tries rival1f/rival2f/rival3f in the chosen trainer
  generation, retaining the companion's engine-installed portrait if missing.
- The source's static Green image resolver is retained; PLAYER ART continues
  to honor its explicitly selected collection. No new static option is added.
- Optional save access is guarded. Fallback reads only the exact companion
  modData key; the source's broad search for any key containing `choose` was
  excluded to avoid taking unrelated mods' preferences.

Load Choose Your Hero alongside Battle Art in the launcher. Its engine hooks
supply the ordinary Green and Yellow portraits and overworld sheets; those
assets do not need copying into this repository. Optional Battle Art-specific
overrides are distinct: the Green intro definition accepts a five-column sheet
at assets/battle/back-animated/greenplayer.png, and rival1f/rival2f/rival3f
images belong under assets/battle/front-static/genN. Without those overrides,
retain the companion's original portraits rather than substituting Red/Blue.

There are no incoming changes for walk/bike/fishing animation or gender
state. The inspected companion modifies live player/rival sprite definitions
and introduction text. SpriteBillboards already keys its mesh by the live
image and frame, so changed sheets do not reuse the previous character's mesh.
The inspected installed companion has walk and bike swaps and fishing assets,
but its main.lua does not register a fishing replacement. Companion versions
may differ; this Battle Art port does not take over fishing or save gender.

Excluded unrelated menu-Pokemon artwork changes and all incoming renderer,
terrain, Stadium, community-visual, capture-effect and performance reversions.
StadiumBackground, BattleScene, OverworldBattle, VoxelScene and voxel meshing
are untouched. Headless tests cover the selection and fallbacks; visual
verification requires the optional art assets and a running game.
