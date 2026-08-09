# Changelog

## 1.3.1

### Fixed

- **A staged battle on a phone stood some Pokémon three times the size of the
  square they were on.** A Pidgey towered over the arena while the mon beside
  it was the right size, which reads as a bug in one species and is not one.

  Putting the paper back inside a battle pic (BattlePics, 1.3.0) needs the
  pic's pixels, and a LOVE Image does not hand them back -- so the pic is drawn
  into a canvas of its own size and the canvas is read. `newCanvas` takes the
  SURFACE's dpi scale when it is not told otherwise, `conf.lua` turns highdpi
  on for Android and iOS, and Android's display density is routinely 2.75. So
  `newCanvas(56, 56)` allocated a 154x154 texture there, the pic was magnified
  into it, and the readback came back at the magnified size. The rebuilt pic
  was 2.75x the artwork, the engine's pics layer drew it 1:1 because it trusts
  `getWidth()`, and the mon stood on its tile nearly three times too big.

  Only a pic with an enclosed hole in it is rebuilt at all -- the rest are
  handed straight back untouched -- which is why it hit some species and not
  others, and why it never showed on desktop, where the dpi scale is already 1.
  The readback now asks for one texel per pic pixel, the way the engine's own
  `PixelCanvas` does for the same reason. The animated-tile atlas readback took
  the same fix: on a phone it would have come back magnified too, and every
  tile coordinate in it counts in eights from the top-left.

## 1.3.0

### Added

- **BACK SPRITES, a new row under 3D-BTL: your own Pokémon stays on the battle menu.**
  The staged shot stands both mons on the map, which is the mode's whole claim
  -- and it costs the framing Gen 1 is most recognisable by: your own Pokémon,
  seen from behind, sitting on top of the battle menu with its feet on the box.

  With BACK SPRITES on the foe is still geometry standing on its own tile at the far
  end of the arena, and the player's side goes back to being the GB's own flat
  back pic in the GB's own slot: same art, same 2x, same feet on row 96. It is
  the engine's own pics layer that draws it, through the `onlySide` argument
  that layer already takes, so every pic effect -- the grow-out-of-the-ball,
  the faint slide, the damage blink, the send-out trainer pic -- comes along
  unchanged and none of it is reimplemented.

  Nothing else about the shot moves. The arena, the camera and the drift are
  solved exactly as they were, so the foe stands where it always stood and the
  player's cell is simply empty ground in the foreground. Two things follow the
  setting: the `pokemon.sprite` hook stops asking for the front pic on the
  player's side (it is a back view again, and the front art would be that mon
  turned round to face the player it belongs to), and the move-animation offset
  drops that side's contribution, because a pic that has not moved cannot have
  moved the pair's centre.

  OFF by default -- what the mode advertises is the two of them out there --
  and only on the OPTIONS menu while 3D-BTL is on, since with staged battles
  off the engine already draws exactly this.

### Fixed

- **Battle pics were see-through, and it took a back sprite on a tiled floor
  to make it obvious.** Gen 1 pics are two-bit art whose lightest shade is
  white, and the decoded PNGs key that shade to alpha 0 -- which cost nothing
  when the field behind them was white too. Over a route, every belly, every
  eye white and every highlight is a hole with the world showing through, and
  the mon reads as a stencil.

  `BattlePics` exists to put that paper back and, as written, put none of it
  back. It flood-filled the outside from the border and filled what the flood
  could not reach, which is exact and, on this game's art, empty: a Gen 1
  figure is an open drawing, and its belly walks out to the border through the
  gap between its legs. Read across all 305 of the game's battle pics, that
  rule finds an enclosed hole in exactly none of them.

  The fix is to start the flood somewhere else: at the edges of the ARTWORK'S
  OWN BOUNDING BOX, and at three of them -- left, right and top. The bottom is
  closed, because it is not a side the background is behind, it is where the
  drawing was CUT. A pic is bottom-aligned in its slot with all the margin at
  the top, so a mon's lowest row is the last row it was given and everything
  below the belly simply stops. Treat that cut as open and the background
  pours up inside the figure, which is the channel of world that used to show
  through a Clefairy.

  That is exact rather than a heuristic: nothing is filled because of what
  surrounds it, only because the background provably cannot reach it. Which is
  why it needs no idea whether it is holding a front pic or a back one -- the
  sky between a pair of ears reaches the top edge and stays sky, the gap
  between a body and a raised tail reaches the side and stays gap, the belly
  reaches neither and is paper. The silhouette is untouched, so the mon still
  cuts cleanly against the world.

  It replaces the border flood outright rather than sitting beside it, since
  anything the border could not reach the box edges cannot reach either.

  The bottom edge needs one more distinction, because two different things
  meet the underside of a figure. A DRAIN is where the drawing ran out -- a
  belly whose white carries on down until the artist stopped, leaking out
  through the inch between a body and a leg -- and is sealed. A MOUTH is the
  space between two legs, background that happens to be enclosed on three
  sides, and is left open so the world shows through a trainer's stride.

  Width tells them apart, and on this game's art it is not a close call.
  Measured along the bottom of every battle pic, the drains run 3 and 4 pixels
  (Clefairy's back, Wartortle's back, Red's back) and the mouths run 10, 12, 14
  and 17 (a Rattata's underbelly, Blue's stride, Brock's, a Pikachu's back).
  Nothing lands between 4 and 10, so the cut is taken at 6 with room either
  side rather than tuned to one sprite. Apart from that number the rule stays
  exact.

  Front pics come back untouched, and not by being special-cased: they are
  near-solid silhouettes with almost nothing inside them to fill, so their own
  shape is what says so.

  Both mons were affected -- the cards in the arena as much as anything -- so
  this lands wherever a battle pic is drawn over the world, not just under
  BACK SPRITES.

- **The pinned back pic was lit at noon while the world behind it was not.**
  Everything standing in the arena goes through the voxel shader, and that
  shader multiplies by the hour's tint, so at dusk the diorama warms and at
  night it goes blue -- the two mons' cards included, because they are drawn
  in the same pass as the ground they stand on. A back pic pinned to the menu
  is not in that pass; it is a flat blit over the finished shot, and it stayed
  bright over a midnight route.

  The same tint is now applied to that one draw, by multiplying every colour
  the pics layer sets on its way past -- so the alpha, the faint slide's fade
  and the damage blink all compose with it instead of being overwritten. What
  it does not get is the sun: the cards are shadow-mapped and a pic pinned to
  the menu has no position in the scene to be shadowed at, so it carries the
  hour and not the weather.

### Added

- **The hour reaches the FLAT world too, not just the diorama.** DAYTIME drove
  the 3D pass through the voxel shader's own tint uniform -- a uniform the 2D
  tile path never runs -- so with VOXEL off, the same evening that fell on the
  diorama left the flat world at permanent noon. One clock, two worlds, one of
  them ignoring it. Outdoor maps now get the same multiply, painted as one
  rectangle over the composited world.

  The whole difficulty is WHERE, and it is worth writing down. Not on the world
  canvas: in a colorized mode that canvas is grayscale art and the blit that
  puts it on screen runs it through the palette shader, which classifies each
  pixel into a shade BY ITS RED CHANNEL -- multiply a night blue over it first
  and every pixel lands in the wrong bucket, so the world does not darken, it
  changes colour. Not over the finished frame either, or the dialog boxes and
  menus darken along with the world they are held up in front of, which is the
  same reason the tilt-shift blur is a `worldPresent` and not a `present`.

  Which leaves the instant between the world blit and the UI blit, and the
  engine has no seam there -- `worldPresent` only runs when a PIPELINE produced
  the world, which in flat mode is precisely what did not happen. So
  `Renderer:endFrame` is wrapped and the UI canvas's own draw is watched for:
  `blit` passes the canvas it is compositing as the first argument, so the
  first draw of `Renderer.canvas` IS the boundary, by identity rather than by
  counting. The shader and scissor that call arrives under belong to the UI
  blit already in progress, so both are put aside for the rectangle and handed
  straight back.

  Skipped entirely when a pipeline drew the frame (it tinted itself, and twice
  is wrong), indoors (a room has no sky to take its light from), and at midday
  (a multiply by white) -- so a game with the clock at DAY issues not one extra
  call.

### Changed

- **FULL no longer takes the two battle rows off the menu.** It still owns the
  rows that describe the LOOK -- the wireframe, the horizon bend, the blur, the
  hour -- because it is a preset for the diorama and a row that no longer
  decides anything is worse than no row. 3D-BTL and BACK SPRITES are not that:
  one decides what a fight is drawn OVER and the other how it is framed.
  FULL still SETS both on arrival; it does not hold them, and leaving them
  reachable is the difference between a preset and a lock.

  This makes `stagedBattles()` honest as a side effect. It used to answer yes
  under FULL as well, on the grounds that FULL owned the 3D-BTL row and
  switched it on -- safe only while the row was hidden. With the row reachable
  from inside FULL, that clause would have claimed staged battles for a preset
  the player had just switched them off inside, pinning BATTLE LAYOUT to OG for
  a fight that never gets staged. The row is the only thing that decides now,
  which is what `OverworldBattle.begin` and `wantsFront` already believed.

- **TILT and GBC FX are off the OPTIONS menu entirely while this mod is
  installed.** Both fight the diorama and both were already half-taken: the
  mode's own key forces them off on every press, and the registry switches
  TILT off whenever a world pipeline takes the pass. What was left was two
  rows a player could set and watch get reverted -- TILT being the flat fake
  of what this mode does for real, and GBC FX a full-screen present pass over
  the top of the whole thing.

  Dropped AND held at zero, which is the part that matters: hiding a live
  setting is a trap, because a save written before the mod was installed can
  carry TILT 3 and a row that is not there cannot turn it back off. Pinned
  wherever the value could arrive from -- the menu opening, a save being
  loaded or begun -- so there is no route by which either is on and
  unreachable. Uninstalling the mod puts both rows back, at whatever they were
  last set to.

- **The battle's text box and menus are frosted glass, like the HUDs.** The
  HUD blocks got panels because black glyphs on grass are not readable. The box
  at the bottom had the opposite problem and the same cause: it is drawn as an
  opaque white slab with a black border, which was the field's own colour back
  when the field was white and is a sheet of paper laid over the bottom third
  of the diorama now that it is not.

  It gets exactly what the HUDs get -- the world behind it, blurred to frosted
  glass and laid back down translucent, at the same frost and the same tint --
  and it is measured into the same brightness verdict, so the ink over the menu
  flips white with the ink over the HUDs rather than against it. Only the FILL
  is taken away: the border, the text, the cursor and the down arrow are the
  engine's own glyphs in their own places. The move menu's TYPE/PP box and
  Mimic's copy menu get their own panels, trimmed to the rows above the box
  below them so no pixel is frosted twice.

## 1.2.1

### Fixed

- **On Android the sky went black below its first couple of bands.** A hard-edged
  band of black ran from partway down the gradient to the horizon point, with the
  moon still hanging correctly inside it. Desktop was unaffected.

  What gave it away is that the same colour reached the screen by two routes and
  only one of them was wrong. The haze filling the void UNDER the horizon is the
  sky's palest band, and it is delivered by `love.graphics.clear` -- it landed
  correctly. The bottom of the sky above it is that same band delivered by the
  shader, and it was black. So the palette was not reaching the fragment shader,
  and nothing was wrong with the palette, the layout or the camera.

  The bands went in as `uniform vec3 bands[8]`, filled from Lua and read through
  a loop counter, and on Android's GLSL ES the tail of that array arrived as
  zero -- which is black. The likeliest reason is the fragment uniform budget:
  ES 2.0 only guarantees sixteen uniform VECTORS, and eight band slots plus the
  twilight glow plus LOVE's own built-ins is over it. A driver that truncates a
  partly-filled array, or one that reflects `bands[0]` and nothing after it,
  fails identically -- so the fix removes the whole class rather than the one
  cause.

  The bands are a one-texel-per-band TEXTURE now, sampled nearest, with the
  band index clamped against the ramp's width. One texture unit replaces eight
  uniform vectors, there is no array to index and no budget to overrun, and a
  sample past the last band lands on the last band instead of on nothing. It is
  still a palette and not a picture -- one texel per band on a single row -- so
  the sky is still computed per pixel at the size it is displayed at, with
  nothing resampled and nothing baked.

  Also gone with it: `clamp(x, 0.0, 0.999999)`, which rounds its bound to 1.0 at
  mediump -- the fragment default on GLSL ES -- and would have indexed one past
  the last band on the sky's bottom row for the same black result.

## 1.1.1

### Fixed

- A move that shakes the screen no longer whites out the frame. The zone pass
  fills each zone with its blank colour before drawing the shifted copy -- the
  hardware showing empty BG in the strip the shake vacated -- and a shake
  program alternates offset and no-offset frames, so over the map that read as
  the whole battle screen, menu box included, flashing white a few times a
  second. The fill is dropped while a battle is staged on the map; the shake
  itself still moves the HUD.

## 1.2.0

### Added

- **A gradient sky behind the diorama, on every `VOXEL` rung.** The void behind
  the world used to be a black plate at every rung but the top, where it became
  one flat blue -- enough while that void was a sliver, and a wall of paint once
  the horizon came into frame.

  It is the 8-bit skybox recipe now: four blues painted as flat horizontal bands,
  deepest overhead and palest at the bottom, with a CHECKERBOARD of the next band
  dithered into the bottom 40% of each one. Alternating two colours on a pixel
  grid is how a machine with four to a palette got a fifth, sixth and seventh out
  of them, and it is what keeps four bands reading as a gradient rather than as
  four stripes. Every channel of the palette is a multiple of 8 -- where a
  five-bit GBC channel lands -- so no colour in it is one the hardware could not
  have shown. No clouds, nothing moving.

  Where the bands END is the camera's own answer. At `75` the ground plane's
  vanishing line is genuinely in frame -- projected through the same matrix the
  geometry is drawn with -- and the pale end meets it. At the steeper rungs that
  line is above the top edge, and what shows up there is the ground running OUT
  past the map edge instead, so the bands take a fixed slice of the frame and the
  haze fills the rest. One sky across the whole ladder either way.

  **Nothing is resampled**, which is why it is drawn the way it is: no baked
  160x144 image scaled up to the window, no downsized buffer blown back up, no
  texture at all. One rectangle through a shader answers every pixel from its own
  canvas coordinate, so a pixel of sky is computed at the size it is displayed
  at and there is nothing for a filter to soften. The band edges and the dither
  cells are measured in the pass's own pixels-per-world-pixel, handed in fresh
  every frame -- so a `ZOOM` keypress is reflected in the frame that follows it,
  with nothing cached at the old scale, and the sky's grid is the same grid the
  world's own texels sit on.

  The palette goes through the display-mode transform like every other palette in
  this mod, so GRAY gets four greys and CLASSIC four greens. Below the bands the
  void is filled with the palest of them -- which is also what the bottom band
  ends on -- so the join has no seam, and a driver that cannot compile the shader
  gets flat bands and a logged line rather than a wrong sky.

  The overworld only. A battle is a staged shot whose placed camera has the
  horizon above the frame, so the arena keeps exactly the flat sky it had.

- **A day/night cycle**, on a new **DAYTIME** options row: `DAY`, `NIGHT`,
  `DUSK`, `DAWN`, `SYNC`, `CYCLE`. One twenty-minute clock underneath all of
  them -- ten minutes of sun, ten of moon -- where the four named settings
  are PINS on that dial (noon, mid-night, sunset, sunrise), `CYCLE` lets it
  run, picking up from whichever pin or SYNC sky the player was just looking
  at, and `SYNC` -- the DEFAULT -- lays the machine's own clock onto the
  dial: local noon is the DAY pin, midnight is NIGHT, six and eighteen the
  twilights, an hour of the real day is fifty seconds of dial. Everything is
  a pure function of the clock, so the pinned DUSK is exactly the running
  cycle stopped at sunset. While **VOXEL** sits on `FULL` the DAYTIME row is
  HELD at `SYNC` and taken off the menu with the other rows the preset owns
  (DayNight.forceSync, enforced from the preset, the rows hook and the
  manager's options_changed -- the same three places BATTLE LAYOUT's pin
  lives): the full diorama runs on the real sky.

  **The sun and the moon are in the sky**, and their positions are honest:
  the disc is the light's own direction projected through the same matrix the
  geometry is drawn with, so it stands over the point on the horizon its
  shadows point away from, at every pitch, window shape and zoom. The sun's
  noon is this mod's existing sun to the digit -- southeast, 45 degrees up,
  overhead behind the north-facing camera and correctly out of frame -- and
  its arc swings north at both ends, so the disc stands IN frame through dawn
  and dusk, rising half-set on the horizon. The moon arcs the northern sky
  all night, due north (screen centre) at mid-night, with scaled crater
  cells. Both are cell art on the sky's own dither grid, sized by the frame
  (a celestial body's apparent size is an angle, so zooming the ground does
  not swell it), and both are SCISSORED to the sky's region: the horizon
  point is where a setting body disappears -- it never hangs under the map.

  **The sky follows the clock.** Phase palettes -- the daytime blues,
  gold-to-violet dawn, a hotter gold-to-indigo dusk, moonlit navy -- six
  bands each now, blended along the dial and re-quantised onto the 5-bit
  lattice, so every mixed frame is still a colour the hardware could show.
  The blends bend through designed WAYPOINTS rather than straight across --
  a golden hour on the way into dusk, a violet civil twilight either side of
  the night -- because day's blue and dusk's gold are near-complements, and
  a straight lerp between complements bottoms out in dishwater grey. Through the twilights a posterised, checker-dithered GLOW
  warms the bands around the low sun -- painted light, not an airbrush. The
  blends are 75 seconds wide either side of each twilight and the pins land
  on their phase palette unmixed.

  **The shadows follow the sun and the moon.** The shear every shadow is
  thrown by (direction opposite the body's bearing, length its elevation's
  cotangent, clamped at twice the caster's height) comes off the clock, the
  shadow map's signature carries it, and the light's press fades out over the
  last twelve degrees before the horizon -- so sunset hands off to moonrise
  through a soft shadowless gap, and moonlight presses at about two-thirds
  the sun's weight. The scene shader also multiplies every surface by the
  hour's tint: neutral at noon, warm at the twilights, dim blue at night.

  **Outdoors only**, by the same `Map.isOutdoor` test the sky already rests
  on: indoors keeps the noon rig, the neutral tint and no sky -- a cave at
  midnight is exactly as dark as a cave at noon. Viridian Forest is the case
  between, a CANOPY map (DayNight.CANOPY): there is no sky to paint and no
  sun to see, so the shadow rig stays the mod's fixed noon light -- all that
  ever filtered through the leaves -- but night still FALLS in a forest, so
  of everything the clock does, exactly one thing reaches it: the hour's
  tint, in free-roam and staged battles alike. A battle staged on an
  outdoor map fights under the hour: the night sky behind the arena, the
  tint on the mons, the sunset taking the arena's shadows with it; an indoor
  arena is untouched. The engine's own `world.tod` hook is answered
  (`MORNING`/`DAY`/`EVENING`/`NIGHT`), so palette or music packs keyed to the
  period ride this clock for free.

  **The clock rides the save slot.** On the engine's `save.writing` event the
  cycle's time is written into the mod's own save-file bucket
  (`save.modData.DRAMATIC_SHAPE`), and read back when a save is opened. A
  save with no clock in it starts at day.

- **Window glass.** The panes in the overworld art -- the framed squares on
  building fronts, the small lights in doors -- are found by SHAPE in the
  tileset image (a black border row, four or five black-flanked glass rows,
  a closing border), at pixel granularity because the door's pane straddles
  a 2x2 tile block. No tile ids are hardcoded: a conversion that draws its
  own windows in the same idiom gets glass for free. The scan yields a mask
  texture aligned to the tileset atlas, which the scene shader samples with
  the same coordinates the terrain does -- so the effect lands on any wall,
  at any angle, in free-roam and staged battles alike, with no geometry
  work.

  By day a thin glint crosses the panes WHILE THE VIEW MOVES: the sweep's
  phase is fed by the camera's own travel and its strength fades out within
  a beat of standing still -- a reflection is something the viewpoint does,
  so still camera means still glass. The sweep pattern lives in the pane's
  OWN texels, not the screen's: a screen-anchored pattern has the world
  sliding through it at zoom speed whenever the camera pans, which strobed
  (worst walking against the sweep); anchored to the glass, panning moves
  nothing and a step advances the glint a fraction of a texel, the same in
  every direction. It lifts the texels toward sky-white and leaves the
  shine art visible through it. The mask is consulted only by meshes
  textured from the tileset atlas (Voxel3D.glass), never by sprite sheets,
  whose coordinates would land on the panes' atlas positions by accident.
  After dark the panes are LIT: the texel's own pattern carried into a warm
  lamp colour, replacing the shaded answer entirely -- a lit window ignores
  the sun, every shadow and the hour's tint, exactly as a window with a lamp
  behind it does. The lamps follow the clock (DayNight.windowLight): on
  through dusk, full all night, mostly out by dawn, and never lit indoors.

- **A fade out of a battle, where there used to be a hard cut.** The engine
  wipes INTO a fight with one of the original's eight transitions and cuts
  straight out of it: `BattleState:finish` pops itself and the map is simply
  there on the next frame. Between a white field and a tile map the original got
  away with that; between a placed camera looking across an arena and a diorama
  looking down on a walking player it reads as a glitch. The battle now fades to
  black, closes behind it, and the map fades up out of it -- twelve frames each
  way, registered as a `voxel_battle_exit` transitions record so the timing is
  retunable in data like the wipes it answers.

  Only while voxel mode is on, and then for EVERY battle, including one that
  found no arena and drew on the flat battle screen: what is being smoothed over
  is the return to the map, and the map is a diorama either way. With the mode
  off, the vanilla cut is untouched.

  One black rectangle over the FINISHED composite does the fading, so the world,
  the letterbox bars and the battle's own text box all darken by the same amount
  -- the renderer's existing warp-fade overlay is painted between the world and
  the UI, which would have left the text box bright over the black. A blackout's
  own warp fade or an evolution prompt still owns the way out when it takes the
  screen: the fade stops at the cut rather than fading in over the top of it.

- **A `FULL` rung on the VOXEL row**, directly after `OFF`. One choice that
  puts the whole mode in its intended state -- the 35-degree camera, the
  miniature blur at maximum, the horizon flat, the view fitted, and battles
  on the map -- rather than making a player assemble it from four rows.

  While it is selected, every row it owns comes OFF the menu: V-GRID,
  V-CURVE, 3D-BTL and T-SHIFT. A row that no longer decides anything is
  worse than no row. Stepping onto or off `FULL` rebuilds the open menu in
  place, so the rows leave and return under the cursor instead of waiting
  for the menu to be reopened.

  It applies its settings when the row ARRIVES at `FULL`, not every frame:
  holding them would make the zoom keys and the wheel dead while it was on.
  Leaving it deliberately undoes nothing -- reverting would discard whatever
  had been changed since.

### Fixed

- **The hit flash whited out the whole screen.** The engine draws it as a
  full-screen white rectangle, which is a flash on a white battle field and
  a whiteout of the map, the HUD and the text box over a world. It is now
  dropped on the way past and put back where it was ever about: the two
  Pokemon go solid white for those frames, silhouette and all, and nothing
  else in the frame moves.

- **A scripted battle cut straight in with no transition** (an ENGINE seam,
  fixed in `src/script/Commands.lua` rather than in this mod): the rival in
  Oak's lab, and every `start_battle` script, pushed the BattleState bare --
  no flash, no wipe, the theme starting late -- where the original wipes
  into scripted fights like any other. `start_battle` now routes through the
  overworld's own `pushBattle`, which is also the path this mod wraps, so a
  scripted fight gets its arena staged and the cast culled BEFORE the wipe
  instead of catching up behind it. A battle scripted with no overworld
  under it still starts bare, and no music plays twice (BattleState's own
  start is a same-song no-op).

- **A standing figure's shadow detached from its feet under a low sun.** The
  shadow compare forgives `slack` world pixels so lit ground does not acne
  against its own texels, and that same forgiveness lit the first `slack` of
  every cast shadow -- so the shadow started a bias-width away from the feet,
  further the lower the sun reached (the classic peter-panning, invisible at
  the old fixed 45 degrees and plain at a day/night golden hour or under the
  moon). Sprite cards -- characters, authored figures, flowers, battle mons
  -- are now drawn into the shadow map snugged TOWARD the sun along their
  own ray (`ShadowMap.snug`): moving along the ray changes nothing about
  where a shadow falls, but storing the card shallower takes three quarters
  of the forgiveness back for the shadow it throws -- and for nothing else:
  no terrain moved, so the acne margin is untouched where it matters. The
  obligation that comes with it: every snugged caster's LIT draw hands the
  same snugged transform to its own shadow lookup (Voxel3D.draw's
  `sunModel`), so stored and lookup agree exactly and the compare keeps its
  full margin -- read un-snugged, the missing nine tenths showed up as
  diagonal moire bands crawling across every sprite. The shadow root lands
  back under the feet at every hour.

### Changed

- **Under `VOID FILL: TREES` the border wall is modelled trees or nothing.**
  Only the first block past the map body gets carved into round trunks and
  canopies; the two blocks past that were too far out to be worth the quads,
  so they fell through to the mesher's plain box and came out as a flat-topped
  slab of tree ART sitting beside the modelled forest -- a painted-on plateau,
  and the more obvious the lower the camera got. Rather than pay to carve
  hulls nobody walks near, the wall now simply STOPS where the carving does:
  `Structures` does not build the ring past that distance (the same "nothing
  out there" `BLACK` already produces), and the mesher drops any cell inside
  it the 2x2 canopy grouping could not claim, so no strip of boxes survives at
  a corner. `WATER` and every indoor border are untouched -- a flat sheet of
  water is what water looks like from above anyway.

- **The two HP boxes snap to the window's edges during a staged battle.** The
  battle screen is 160x144 in the middle of the window and the world is the
  whole of it, which left both HUD blocks huddled together in the middle of the
  frame with map showing on either side of them -- a Game Boy screenshot pasted
  over a diorama rather than the diorama's own furniture. The foe's block now
  sits against the left edge and the player's against the right, on the same
  frosted glass, with the same tiles at the same size on the same rows. The
  pokeball rows and the safari ball count travel with the block whose rows they
  share. On a window shaped like the GB screen there is nowhere to go and
  nothing moves.

  The engine draws them into the 160x144 canvas, which clips at its own edges,
  so the layer is rendered to a texture and composited into the world image --
  the one surface here that covers the whole window. A driver that cannot do
  that falls back to the HUD in the frame rather than to no HUD.

- **`BATTLE LAYOUT` is pinned to `OG` while battles are staged on the map**, and
  the row comes off the OPTIONS menu with the rows `FULL` owns. The staged shot
  is composed in the GB's own frame -- the arena camera is solved to put a cell
  under each pic's feet, and the HUD rects and the intercepted background fill
  are measured there too -- and `WIDE` re-lays that screen out on a 304x144
  surface, moving every one of them. Set rather than worked around, on every
  route in: the options row, hotkey `8`, the mod manager's page, `FULL`'s
  preset, and a save that arrived with `WIDE` already on. Switching `3D-BTL`
  off hands the row back with `WIDE` selectable again.

- **Hotkey `3` walks the angle rungs only and steps over `FULL`.** The key is
  a display-mode cycler -- it should change the camera and nothing else --
  and `FULL` reaches in and rewrites four other settings. Landing on it
  mid-walk would silently push the blur to maximum and flatten the horizon
  with nothing on screen saying a keypress had done it. `FULL` stays on the
  OPTIONS row, where a preset that changes other rows belongs.

  A press FROM `FULL` goes to `50`. `FULL` is already the 35-degree camera,
  so stepping to the rung of that name would look like the key had done
  nothing. Matched by angle, so it follows `FULL` if that is ever retuned.

- **The mode's four options are one block in the menu.** The engine splices
  a pipeline row in beside TILT and lands a mod's own rows at the end of the
  list, which had these four in two places with unrelated engine rows
  between them. The settings now follow the pipeline rows directly.

## 1.1.0

### Added

- **Battles happen on the map you were standing on.** The battle screen's
  white field is replaced by the world: the mod finds the nearest patch of
  open ground, points a placed over-the-shoulder camera at it, and draws the
  fight over that. New **3D-BTL** row and hotkey `8`, on by default.

  The arena is a 3x6 clearing of cells the player could walk on, with the
  two mons three cells apart down the middle column and a one-cell apron all
  round so the camera looks across floor rather than into a wall. Where no
  map has room for that -- a corridor, a cave, a shop -- the search relaxes
  to a 1x4 corridor with the apron given up, and where even that will not
  fit the battle draws exactly as it always did.

  Everything else in the frame is the engine's own. The mon pics, HUDs, HP
  bars, move animations, faint slides and text box are drawn by BattleState,
  in its order, at its coordinates -- the GB's own layout, with the player's
  mon low and left and the enemy's high and right, which is why the camera
  is placed east of the arena axis rather than the layout being moved to
  suit the camera. What changes is what is behind them.

  Three things carry the shot. The overworld's cast is culled before the
  wipe, so it plays over an empty map and no bystander is standing in the
  arena. The camera drifts on a slow orbit about a point between the two
  mons, which moves the near ground and the far ground by different amounts
  -- parallax, not a sliding backdrop. And a depth-of-field pass holds the
  band of frame the two mons stand in sharp and softens the middle distance
  and the foreground; both mons are in focus by construction, because they
  are drawn as the battle screen's own pics after the pass has run.

  **Nobody moves.** The arena is where the CAMERA goes. Nothing here writes
  a cell, a facing, a flag or a warp, so a trainer's post-battle dialogue is
  still talking to someone standing in front of them, and the blackout path,
  sight lines and every script find the player exactly where they left them.

  The two HUD blocks gain the backing the white field used to be. Gen 1
  draws them as black glyphs straight onto the background with no box round
  them, and black-on-grass is not readable; the backing is painted inside
  `drawHUDs`, so it lands in the same target and takes the same zone colour
  as the HUD it sits under, in both the colorized and flat pipelines.

  Declines cleanly at every step it cannot take: no depth support, no open
  ground, the row switched off, or a terrain mesh still building all end at
  the battle screen the engine has always drawn.

### Changed

- **Characters are flat sprite billboards, and nothing about a sprite is
  voxelized any more.** Every figure -- the player, NPCs, the ghosts
  standing on a neighbour map -- is now its current 2D frame on a single
  flat quad, with the shader's alpha discard cutting the exact silhouette
  out of it. It still faces south and leans back by the camera's pitch,
  so it reads face-on at every tilt exactly as before.

  Two things went away with that. The contoured slab, which gave each row
  a thickness measured from the sheet's own side view; and the carved
  visual-hull models (`lib/VoxelModels.lua`, `tools/build_voxels.py`, and
  ~70 generated files under `assets/voxels/`, 2 MB), which reconstructed
  a figure from its three drawn views.

  A sprite is a DRAWING, not an object seen from one side. Gen 1's
  overworld figures are 16x16 icons with a fixed front-on reading, and
  turning one into a solid invents a body the artist never drew and the
  game never implied. The shipped models were also the one place this mod
  carried a description of the ROM art -- a carve is a faithful record of
  a sprite's silhouette, pixel for pixel -- which sat badly against a mod
  that otherwise ships no game data at all.

  The flat card is cheaper on every axis: no pixel access (only the
  sheet's dimensions), one quad instead of hundreds of faces, and one
  mesh shared by the solid draw, the sun pass and the player's occlusion
  silhouette. That sharing is load-bearing rather than tidy -- the
  silhouette draws with the depth test inverted, and any self-overlap in
  the mesh would read as "behind something" and repaint the figure on
  open ground.

  A mod can still ship `overrides/voxels/<name>.lua`; that path is
  unchanged and still wins where it exists.

## 1.0.6

### Added

- **Conditional pins.** A profile entry may now carry `when_above`:
  tile id -> rules keyed on the tile drawn directly north of it,
  resolved per POSITION in `TileShape.at`. A pin is per tile id and one
  graphic can mean two things -- the route gates' `$32` is both the
  wall's dark base course and every service counter's front, and it is
  the bottom row of its cell either way. Pinned `wall` the counters
  stood a full 16px; pinned `counter` the deep wall banks corrugated
  16/8 for sixteen rows and the room read as crates. What separates the
  two uses is what sits on top, so that is what the rule reads. The
  gates now have half-height counters AND level walls.

- **The Pokemon Tower has an exterior.** It is the one catalogued
  building drawing the map edge cuts off (no roof band is on the map at
  all), and it had no `buildings` entry, so it fell to the volume path
  -- which tops a run by repeating its first two rows, laying window
  courses flat across the plateau. Sealing the silhouette on the north
  alone closes it (88% fill, one piece, against 37% and 126 pieces
  unsealed), and one row of roof band spent on the drawing's top margin
  costs no window course. It stands as a real tower, panes recessed,
  door on the ground.

- **The Indigo Plateau statues stand up**, built exactly like the gym
  statues: plinth a solid 16px block, figure a per-pixel cutout riding
  it. On the avenue the statues stack with no gap, so the flood joined
  six of them into one 24-row region and the volume builder raised
  ridges of boxes with the statue art folded on the front. The same
  bird is drawn at the foot of every badge-check pillar, so those are
  crowned too.

### Fixed

- **Tall grass: one clump per tile.** Each 8x8 tile is a whole clump,
  but the template split every tile AGAIN into its top and bottom four
  art rows and stood those at two different depths -- so any blade
  running down a tile was cut in half, into two 4px stubs 4px apart.
  One tile is now one full-height standing slab at its own depth; a
  cell's 2x2 tiles still stand independently, so the player walks
  between the north and south rows.

- **Ledge lines are continuous.** `$34` is the cliff slope's foot and
  also the pillar between hop-down segments; pinned `wall` with the
  rest of the slope chain (the Diglett's Cave fix) it stood those
  pillars 16px beside a 6px lip. At ledge height the run reads as one
  lip, and the mound is unchanged -- its foot row reads as the talus it
  is drawn as.

- **A prop only stands on furniture when its own cell is blocked.**
  "Is something drawn above me" is not "am I standing on it": a chair
  drawn against the north side of a table is above the table's trim row
  too, and was being lifted onto the tabletop, with its claimed cells
  re-tiled as tabletop so the table marched two rows north. Three
  chairs in Cinnabar's trade room and Fuchsia's meeting room, and the
  Celadon diner's stools. The world already knows the difference: a
  thing that sits ON furniture occupies a blocked cell, a seat you walk
  up to is in a walkable one.

- **Caves: nothing below sea level, and the water is water.** Two tiles
  were identified backwards in the first pass. `$14` -- the tile the
  engine animates, that `Map.WATER_TILES` names and that Surf runs on
  -- was pinned `wall`, so Cerulean Cave's lake and the Seafoam sea
  stood up as rock slabs. And the pale dithered rock fill was pinned
  `water`, cutting 612 tiles of two-cell-wide trench through four maps.
  Both corrected; a sweep of all 19 cave maps now reports zero tiles
  below the datum. The elevation scheme is documented in the entry and
  derived from the game's own `tilePairs`: dark floor, water and drop
  holes at 0, the lit shelf a 6px step above, rock at 16.

- **Cave ladders climb.** Which ladder graphic goes up and which goes
  down is unanimous in the warp table -- 37 cells of one always warp
  down, 40 of the other always up -- so they are real stepped flights
  now, not painted plates.

- **Poke Mart's register stands on the counter.** The pin was on the
  wrong tile: `$08` is the counter's own top band, not the register, so
  the standee flood ate everything but two black lines. The register is
  the keypad-and-receipt drawing one row up.

- **Celadon's televisions**, which were solid 16px boxes wearing the TV
  art on one face, and the **Pokemon Tower reception desk** and the
  **gate counters**, which stood at wall height, are all their drawn
  heights now. The **Fan Club and Silph boardroom statues** were read
  as seated chairmen and painted onto the tabletop; they are cutouts
  standing on their pedestals, and the tables are cut to a true
  octagonal footprint.

## 1.0.5

### Added

- **Every remaining interior is furnished.** The profile covered ten
  tilesets; it now covers twenty-three -- 1,190 pinned tiles across
  `GATE`, `FOREST_GATE`, `LOBBY`, `MUSEUM`, `LAB`, `MANSION`,
  `INTERIOR`, `CLUB`, `SHIP`, `SHIP_PORT`, `FACILITY`, `CEMETERY` and
  `UNDERGROUND`, plus full entries for `CAVERN` and `GYM` which had only
  stubs. Roughly 130 maps, surveyed against the standard the finished
  interiors already set: one 16px wall band carrying whatever is drawn
  built into it, half-cell counters so the drawn front folds up and the
  top stays on top, `bookcase` collapse for free-standing shelves,
  thin-pool standees for plants, and small objects riding the furniture
  they are drawn above.

  What the detector was doing before, by way of what changed:

  - **Rooms with no walls.** Three tile ids (`$14`, `$32`, `$48`) are
    claimed by the engine's water set in EVERY tileset, and collision is
    per CELL, so one of them in a cell's bottom-left corner sank the
    whole cell. `$32` draws both the route gates' wall base course and
    every counter front, so all 25 gate maps were a checkered floor in a
    moat; the same trap put ponds through two thirds of Seafoam B4F,
    under every museum vitrine, along the S.S. Anne's wall corners and
    across Silph Co 1F's lobby island. The set is wider than three ids
    in practice -- `LAB`, `MANSION` and `INTERIOR` each hit six to nine
    -- because the test is per cell, so an innocent tile sharing a cell
    with a trapped one sinks with it and has to be pinned too.
  - **Towers and fused monoliths.** Counters raised to 48px dragging
    their wall band with them, merchandise racks fused sideways into
    32px blocks four tiles deep, cave shelf edges standing as 48px fins
    beside a 16px band, the Vermilion liner folded upright into a lumpy
    48px slab.
  - **Furniture that was not there at all.** Anything whose cell is
    walkable resolved to flat ground: 59 department-store stools, every
    gate lounge table and pair of binoculars, both museum staircases,
    the gym-lounge chairs, and -- via the void rule -- the black
    partition walls every gym is divided by, which left their white rim
    columns standing as hollow 48px fins.
  - **314 gravestones** in Pokemon Tower were 8px stubs, because the
    volume path measured only their bottom row and dropped the arch.

  Notable readings: the S.S. Anne's hull is `roof` (a drawing seen from
  above, so the art belongs on the top face); the Warden's specimens and
  Celadon Gym's shrubs are `cylinder` voxel balls, the first indoor use
  of that class; the Fan Club's octagonal boardroom table is `counter`
  rather than `table`, because only a counter rides its upper rows onto
  the top face in drawn order -- which is what draws the seated chairman
  exactly once, the Pokemon Center couch case verbatim.

  Fuchsia Gym's invisible maze is deliberately left flat. Raising it
  would read better as a room, and would also hand the player the
  solution; a shape is purely presentational, so the drawn answer wins
  and the gym plays as the flat game does.

### Fixed

- **A profile pin now outranks the door fold.** `Structures.forMap`
  folds a door cell into its facade so the doorway does not punch a hole
  in the wall -- but it overwrote the resolved shape unconditionally,
  including for AUTHORED tiles, which contradicts rule 1 of the
  documented resolution order. Any pin on a tile its tileset also lists
  in `doorTiles` was dead on arrival: all four Celadon Mansion
  staircases and Pokemon Mansion 3F's descent are door tiles, so
  `stair_*` pins there silently did nothing and the flights stayed
  painted flat on the floor. The fold now skips authored tiles.

## 1.0.4

### Added

- **Viridian Forest grows real trees.** Nearly everything drawn in the
  forest is ROUND, and the detector was boxing all of it: the big trees
  came out as ragged mixed-height volumes (their sparse canopy-rim
  tiles read 0px against 32px bodies, leaving gap-toothed hedge walls),
  the stump rows merged into 16px crate walls wearing folded stump art,
  and the trail signs were broken piles -- their $32 tile is the
  water-fallback trap and recessed into a pond lip in the middle of the
  woods. All of it is now profile-pinned to the treatments the rest of
  the world already uses: every tile of the tree drawing (ball, rim
  wisps, feet) and the stumps take the per-cell voxel HULL the overworld
  border forest wears -- a tree spans 2x2 cells, so its four
  quarter-hulls tile into one big lumpy canopy, and each stump becomes a
  round bollard; the signs take the standing thin-slab `signpost`
  treatment every town sign gets; and the white sparkle filler inside
  the tree masses is flat ground instead of an invisible zero-height
  box. The whole map now resolves to hulls, signs, ledges and ground --
  a detector sweep finds no stray boxed column anywhere.

  Two refinements over the first cut, both new hull-builder abilities.
  A tree's drawing spans 2x2 CELLS, and per-cell hulls unfolded it onto
  the ground -- the ball's top half sat one cell north of its bottom
  half at the same elevation, reading as a tree cut in half. The new
  `canopy` class pins the drawing's corner tile as a group anchor and
  the whole 2x2-cell drawing carves as ONE 32px hull, so every tree is
  a single tall round canopy (the carver is now parametric over its
  canvas size, and hull stamps carry their footprint radius). And the
  stumps' drawn tops are a CUT FACE -- an ellipse of growth rings seen
  at an angle, not body: the new `stump` class builds the hull from the
  bark rows alone and projects the ellipse across the round flat top,
  near arc to the south (`stump_cap` names the ellipse's drawn height),
  so the rings ride the round part in perspective.

- **Flowers stand up, and keep swaying.** The animated meadow tile
  ($03, the one tile the overworld animates by frame rewrite) now
  renders as a billboard one voxel deep: the drawing's darkest tones
  plus everything they enclose are cut out per pixel, and the ground
  beneath is synthesized from the commonest flat neighbour, exactly
  like the ground under a detected prop.

  The interesting part is that the cutout still animates. A mesh is
  static, so the geometry spans the UNION of the mask over the base art
  and all three animation frames, and the animation lives entirely in
  the texture: TerrainAtlas already rewrites the flower's slot in the
  private animated atlas each step, and for this tile it now writes
  only the current frame's mask opaque with everything else keyed to
  alpha 0 -- which the voxel shader discards, and the shadow pass with
  it. The standing silhouette trims itself frame by frame in texture
  space, off the same engine clock as the flat path, without a vertex
  moving. The class is derived, not authored: any frames-animated tile
  resolves to the new `flower` class with no profile entry, the same
  way tall grass derives from `grassTile` (hand-authoring still wins).

- **The cuttable bush is a standing cutout.** The four tiles Cut
  deletes ($2D/$2E/$3D/$3E -- across the whole tileset they appear only
  in the five cut-tree blocks) are pinned to the thin `prop` pool: a
  per-pixel standee 5 voxels deep, black-outline segmented with its
  enclosed pixels kept, the drawn grass dither flooding away. It
  stands on plain grass ($2C) -- the very tile Cut leaves behind per
  field.cutTreeSwaps -- via the profile's new `prop_ground` key, which
  names the tile painted under a pinned prop instead of whatever flat
  tile its neighbours vote in.

- **Gym statues: a solid plinth, a standing bird.** The statue pair
  flanking every badge gym's aisle (and Bruno's room) is one cell of
  figure over one cell of plinth. The plinth ($22/$23/$32/$33) is
  pinned `wall`: a solid 16px block. The figure ($02/$38/$12/$13) is
  pinned `prop`: a 5-voxel cutout that stands ON the plinth through the
  authored-box support rule, its checkered background flooded away and
  the pixels its outline encloses kept.

  The whole statue keeps ONE cell of footprint. The support rule used
  to extend the box under the claimed cell (the monitor-on-desk path),
  which marched the plinth a second block backwards; a figure whose
  support is a FULL-HEIGHT block now collapses instead -- the drawn
  figure cell becomes synthesized floor, since the block below already
  carries the whole base. Furniture supports keep the extension: their
  drawn cell is the furniture's own upper rows, and floor there would
  amputate the desk. The round boulder drawn beside some statues is
  deliberately NOT pinned -- it also tiles wall-to-wall as Pewter's
  rock rows, which are scenery for the detector.

- **Lt. Surge's trash cans stand up.** The can ($0B/$0C/$1B/$1C, the
  lone graphic of blocks 38/39) takes the same treatment as the
  cuttable bush: a 5-voxel `prop` cutout, black-outline segmented with
  its enclosed pixels kept, standing on the gyms' main floor tile
  ($11) via `prop_ground`.

- **The Poke Marts furnished to the Center's standard.** The MART
  tileset shares the Center's atlas image but is its own id, so none
  of the Center's pins applied, and every mart was raw detector
  output: a 32px double-height display band for a back wall, the two
  shelf racks fused into one four-tile-deep monolith, and the clerk's
  booth towered into a 48px slab wearing the juice poster. Pinned the
  way the finished interiors are -- the back wall's SALE cases and
  drink fridges one 16px face like the Center's healing consoles, the
  racks collapsed to one-cell-deep shelves at drawn height like Red's
  bookcases, the counter half a cell with the poster riding its top
  like the nurse's tray, and the cash register standing ON the counter
  through the authored-box support rule. One 4x4 layout serves every
  city, so this covers all eight marts.

### Fixed

- **Cut trees now vanish in voxel mode -- and grow back.** The
  engine's Cut path swapped the block with a raw `setBlock` + renderer
  rebuild, never emitting `world.block_replaced` -- so this mod's
  listener (which rebuilds the map's mesh exactly for this) never
  heard about it, and the diorama kept showing the tree. The engine
  now routes Cut through `replaceBlock`
  (src/world/OverworldController.lua), whose whole purpose -- per its
  own comment, "Victory Road barriers, Cut trees" -- is that same swap
  plus the event. The regrowth path had the same hole one door away:
  cut trees are restored block by block when the map is re-entered,
  and the card-key doors are stamped closed on floor load, both
  through the same silent `setBlock` -- with the mesh cache staying
  warm across a round trip (that is what prevLive is for), the world
  kept showing the stump you left. Both paths now announce each block.

- **A block edit no longer blinks the world down to 2D.** The
  listener used to drop the edited map's mesh outright, and mesh
  builds are asynchronous -- so cutting a tree (or stepping out of a
  door onto a map whose trees just regrew) flashed the flat 2D world
  for the frames the rebuild took. `ChunkMesher.refresh` rebuilds in
  place instead: the stale mesh keeps drawing, the replacement cooks
  in the background, and each slot swaps as its build lands -- the
  tree pops out (or back in) with the scene never leaving 3D.

- **Flowers cull the player correctly from every angle.** The flower
  billboards were baked into the terrain mesh, which draws without
  the characters' camera-ward pull -- so a walker standing among
  flowers won the depth test against ALL of them, including the
  flower south of their feet that should overdraw them. The flower
  quads now ride their own mesh, drawn after the characters with
  exactly the characters' pull (the tall-grass trick): the flower in
  front of a walker occludes their feet, the one behind them hides,
  at every camera angle. Unlike grass the flower mesh still casts
  shadows -- it is a handful of cutouts per meadow, not thousands of
  tufts.

- The `voxel_anim_probe` driver crashed on engine builds without the
  optional `TileRenderer.animFrame` seam, and again on tilesets whose
  animation list carries a "toggle" entry (spinner rooms), which claims
  a tile LIST rather than one slot. It now reads the clock through the
  mod's own fallback chain and skips toggle entries in the placement
  census.

- **The shoreline no longer opens into the sky beside buildings and
  signs.** Water recesses 2px below the ground, and the ground tile beside
  it closes the step with a small below-ground side band -- but a tile
  CLAIMED by a standing object (a building footprint, a sign standee, the
  bushes ringing Fuchsia's ponds) only painted its synthesized flat ground
  and never emitted sides. Along every stretch where such a tile met
  water, the two-pixel step was an open slit straight through to the sky
  behind the mesh. The skip branch now emits the same below-ground bands
  ordinary ground does, cut from the synthesized ground's own art, so the
  shoreline lip is continuous whatever stands on the bank.

- **Edge-row buildings keep their facades.** The south wall of Saffron's
  row houses -- profiled buildings whose front row is the map's last tile
  row -- lies exactly on the boundary plane shared with Route 6, and the
  prebuilt-quad keep rules dropped it: the strict body test excludes the
  plane, and the closed neighbour mask (which exists to kill ring scraps
  whose rects sit exactly on that line) swallowed what was left, so from
  Route 6 the houses stood hollow. The two cases are geometrically
  identical degenerate rects, but they FACE opposite ways: a face pointing
  away from the body is this map's own facade and nothing in the
  neighbour will ever draw that plane, while a face pointing into the
  body is the scrap the mask is for. The mesher now reads the winding and
  keeps outward faces on the body's boundary planes, on all four edges.

  The roof RIM had the same problem one step further out: an edge-row
  house's eave overhangs `frontEave` voxels PAST the boundary plane into
  the neighbour's airspace, and those quads are neither on the plane
  (the winding rescue) nor over the body -- the neighbour-body mask ate
  them as ring scraps, so from across the seam the roof edge was open
  sky at low camera angles. Building placements only ever scan the map
  BODY, so every building quad is this map's own structure by
  construction: they now carry an `own` flag the edge keep-rules never
  touch.

- **Diglett's Cave mounds (and cliffs everywhere) stop sprouting
  towers.** Two detector misreadings stacked up on the cave-entrance
  mound. The dark east slope of the cliff drawing ($02/$24/$34) is one
  texture repeated over the mound's whole height, but its corner tiles
  break the repeat scan, so those columns rose to 32px -- the rock
  pillar beside the entrance. And a folded doorway column reads its own
  drawn extent (the door plus everything above it), which is a house's
  real height when the door is a house's, but a 32px tower over a 16px
  plateau when the door is a cave mouth -- the entrance jumped a block
  above the mound around it. The slope chain is now profile-pinned to
  one 16px course, and a doorway column answers to its REGION entirely:
  height from the region's dominant column, top flat when those columns
  are flat repeats (the mound) and roofed when they are drawn facades
  (a house). Both cave entrances -- and every cliff built from the same
  slope tiles -- now read as one level mesa with the cave mouth at
  ground level. A new `voxel_mound_probe` driver prints the detector's
  per-column class and height over any rectangle, which is how this was
  diagnosed.

  Routes 3 and 4 had a third variant of the same misreading: the repeat
  scan anchors at a column's FRONT tile, and a plateau column that ends
  in a one-off rounded corner tile ($13/$35) never matched -- it read
  its whole capped extent and shot up as a 48px fin (several together
  made a tent). When the two rows directly above the front are
  identical, the column is now read as that repeat wearing a trim foot:
  its unit is one course plus the trim. Doorway columns still answer to
  their region first, so houses are untouched.

## 1.0.3

### Added

- **The player shows through whatever hides them.** Occlusion in this mode is
  the real thing -- walk north of Red's house and the roof is genuinely in
  front of you -- but a player who cannot see their own character has lost
  track of where they are standing, which the flat game never allowed. The
  figure now draws a second time as a translucent silhouette wherever the
  world is in front of it.

  No code anywhere asks whether the player is occluded: the depth buffer
  already knows, and the test is the question. The silhouette is drawn with
  the depth compare INVERTED -- `greater` where the scene uses `lequal` --
  so it appears exactly where the ordinary draw would have lost, and nothing
  at all is drawn when nothing is in the way. LOVE hands the compare straight
  to `glDepthFunc`, so the two are true complements with no seam between
  them.

  It goes down BEFORE the characters, so the only thing it can meet in the
  depth buffer is the world -- terrain, buildings, trees. Drawn after the
  solid pass it would meet the player's own card instead, and every fragment
  of a figure sits behind the one that just wrote it, so it would paint over
  the player permanently. Characters then draw on top as usual.

  It uses the FLAT card (`SpriteBillboards.shadowQuad`), not the relief slab
  the solid pass draws. The slab carries front and back faces and the mode
  culls neither, so with the test inverted its own back faces -- a few voxels
  deeper than the front ones that just won -- read as "behind something", and
  the figure repaints itself on open ground whether or not anything is in
  front of it. One quad has no self-overlap, which is exactly why the shadow
  pass already uses this mesh, and it cannot double-blend into a mottled
  patch either. A silhouette is an outline, so the outline is the right mesh.

  Depth writes are off: the pass is behind the scenery by definition, and
  writing would file the hidden figure in front of the building hiding it,
  which the grass pass at the end of the frame reads. The card carries the
  same transform and the same camera-ward pull as the solid draw (both now
  come from one shared `billboardMatrix`/`billboardPull`, so they cannot
  drift), which is what keeps the leaning-over-a-near-wall case out of it:
  pull already won that fight for the solid draw, so a character merely
  standing close to a wall does not shimmer a silhouette over it.

  It is drawn as ONE flat translucent grey, not as a dimmed copy of the
  sprite. Tinting through the vertex colour could only MULTIPLY the sprite's
  own pixels, which darkens each one by its own amount and keeps all the
  character's internal detail -- a murky picture of Red rather than a shape.
  So the fragment shader carries a `ghost` / `ghostColor` pair and replaces
  the colour outright, last in the chain so neither the sun nor a voxel seam
  can mottle it. Staying translucent is what keeps it reading as "behind
  that wall" rather than as a hole punched through it.

  `Voxel3D.GHOST_COLOR` and `GHOST_ALPHA` (0.5) are the knobs. Only the
  player gets this -- NPCs and the ghosts standing on a neighbouring map are
  left to honest occlusion, because it is only your own character you cannot
  afford to lose behind a roof.

## 1.0.2

### Fixed

- On Android the diorama drew into the top-left corner at a fraction of the
  screen -- about a third of the width and height on a 420dpi panel -- with
  the field effects (dust, emotes, the cut-tree shudder) correspondingly
  oversized against the world they sat on. Desktop was unaffected.

  The pipeline ctx hands over `width`/`height` measured in LOVE UNITS
  (`love.graphics.getDimensions`), but the engine composites a pipeline's
  returned canvas with `draw(canvas, 0, 0, 0, 1/dpiX, 1/dpiY)` -- a scale
  that only covers the window if the canvas is at PIXEL resolution. Sizing
  the scene canvas from the ctx therefore paid the DPI scale twice: the
  canvas came out that much smaller, and was then drawn that much smaller
  again. On desktop the two units are the same number and nothing shows;
  Android's DPI scale is the display density (2.625 at 420dpi), so that is
  where it surfaced.

  The scene canvas is now sized from `love.graphics.getPixelDimensions`
  directly rather than from the ctx. That is the number a fixed engine would
  hand over, so this does not double-correct if the ctx is ever changed to
  agree with the compositor. It also squares the FX pass for free:
  `ctx.scale` was ALREADY in pixels per world pixel (`Zoom.scale` over
  `Renderer:fitScale`, which measures the drawable), so the closures were
  being scaled for a canvas 2.6x bigger than the one they were drawing into
  -- one wrong number, not two.

## 1.0.1

### Fixed

- The RED++ texture-readback fallback in `TerrainAtlas` never worked on real
  drivers: LOVE refuses `Canvas:newImageData` while that canvas is currently
  active, and `readback()` read the pixels back before restoring the previous
  render target, so the call threw on every driver rather than only on
  stubborn ones. The previous target is now put back BEFORE the read. The
  headless suite could not see this -- its stub canvas does not enforce the
  rule -- so it survived until a live probe ran the chain unguarded.

  Harmless for vanilla tilesets, where the CPU rebuild (`gbcPixels`) answers
  first and the fallback is never consulted; it was the last-resort route for
  a map the palette pack does not know, which until now had no working route
  at all.

## 1.0.0

First release, ported from the engine-internal voxel branch onto the
`render_pipelines` mod API.

Interior furniture gets the shapes it depicts
(mods/DRAMATIC_SHAPE/tools/voxel-survey.md is the procedure that found and
verified these).

Buildings stop being boxes wearing their own elevation. A profiled
building is voxelized from its own sprite, band by band -- the pipeline
written up in `assets/docs/buidling_to_voxel/`.

Terrain meshing goes asynchronous, instanced and bounded. The first voxel
frame used to build every neighbourhood map synchronously (a ~2.4s
freeze), retain every map's analysis forever (gigabytes over a
cross-region trek), and string stray pixels along map seams.

Real shadows. The sun moves to the southeast and drops to 45 degrees, so
shadows fall northwest -- up and to the left on screen -- and run about as
long as the thing throwing them is tall.

### Added

- `voxel` render pipeline: 3D diorama overworld with extruded terrain,
  depth-buffered occlusion, leaning sprite billboards, drop shadows and
  contact AO. VOXEL options row and hotkey `3` (OFF / 15 / 35 / 50 / 75).
- `tiltshift` render pipeline: a `worldPresent` post-process giving the
  miniature-photo look. T-SHIFT options row and hotkey `6` (OFF / 1 / 2 / 3).
- Carved voxel models for 67 overworld sprites, plus the
  `tools/build_voxels.py` that produced them.
- `data/voxel_heights.lua`, the hand-authored tile shape profile.

- Furniture shape classes in the profile: `bed` (a low slab wearing its
  top-down art), `table` and `desk` (boxes at their drawn height whose
  faces fold the artwork up), `relief` (a prop drawn from above -- a
  game console -- lying flat and extruding a few voxels inside its
  outline), the standee pools `billboard` (10px) / `prop` (5px) /
  `stool` (5px, and characters standing on its walkable cell sit at
  seat height) / `cutout` (one voxel: pure profile, for the vase on the
  table), and the stair archetypes `stair_e`/`stair_w` (a rising flight
  of real steps) and `stair_down_e`/`stair_down_w` (a sunken stairwell
  descending below the floor -- stairs that lead down).  Separate pools
  cluster separately, so touching drawings never merge into one cutout.
- Standee clusters split into per-pixel connected components, each
  standing on its own feet in the depth band of the row it is drawn in:
  two stools stacked in adjacent cells become two stools, and no
  fragment of a drawing ever floats at its bounding-box height.  A
  `cutout` keeps only its largest component -- a cast shadow's drawn
  edge is background, not a floating scrap.
- `bookcase` class: free-standing shelf drawings collapse in ranks onto
  one-cell-deep boxes at their full drawn height, back rows becoming
  hidden floor; the trim row above a rank -- undetected structure or a
  row pinned `table`, since the same trim tiles cap other furniture --
  is adopted as its cap.  Pinned for Oak's Lab (`DOJO`).
- Oak's Lab tables pinned `table`: the starter-ball display and the
  north tables stand at real table height, the display frame's black
  corner brackets no longer auto-extract into standing prisms, and the
  Poke Ball / Pokedex sprites ride the authored height onto the
  tabletops.
- Pinned props drawn directly above a pinned box stand ON it: the PC
  monitor on its desk, the flower pot on the dining table.
- Profile pins for `REDS_HOUSE_1` / `REDS_HOUSE_2` (Red's house and the
  Copycat's, both floors): bed, stools, tables, PC desk with its
  standing monitor, bookcases, TV standing on the floor behind the game
  console's relief, potted plant, flower pot, both staircases, and the
  wall/window band.
- `mods/DRAMATIC_SHAPE/tests/voxel_survey.lua`: screenshot-survey driver
  behind the repeatable inspection procedure (SURVEY_MAP / SURVEY_SPOTS /
  SURVEY_LEVELS / SHOT_DIR), documented in
  mods/DRAMATIC_SHAPE/tools/voxel-survey.md.

- `lib/Buildings.lua`: a building archetype. Where the volume path folds a
  whole drawing upright (roof, facade and sloped ends alike) into one box,
  this classifies each BAND of the drawing by the 3D surface it depicts and
  applies the matching operation: top-facing rows lay flat over the
  footprint, the facade extrudes straight back, an awning band juts past
  the walls, and the drawn taper at the ends becomes a stepped slope in
  elevation. Every visible voxel carries a real texel of the drawing, so
  the model recolours with the atlas.
- A `buildings` section in `data/voxel_heights.lua`. A building is matched
  by its exact tile grid (the drawings are catalogued in `assets/docs/buildings/`),
  so one entry covers every map that places the same art -- Red's house,
  Blue's house, Bill's, the Copycat's and the two Fuchsia houses are one
  seven-placement entry, and Oak's lab is a second. Only the band table is
  authored; the silhouette, the taper rate, the eave height and every
  window and doorway are measured off the pixels.
- The flat-roofed civic block and its sixteen relatives -- every Pokemon
  Center and every Poke Mart, Fuchsia Gym, the museum, the Game Corner,
  Celadon Mansion and its department store, the Power Plant, the Route 5
  and Route 22 gates, Silph Co and five anonymous scenery blocks. They are
  one architecture drawn at eleven different footprints, from 4x4 cells up
  to Silph Co's 8x12, and they share one band table: their lattice is drawn
  from straight above, so the measured taper comes out flat and the whole
  band is depth under one level roof. No new roof mode was needed -- the
  drawn profile was always the shape, and a drawing with no taper simply
  yields a level one.
- Pewter's museum hall (`assets/docs/buildings/B24`). It is the one
  sloped-roof building in this pass, and the only one so far whose roof
  texture is not a plain repeat: the drawing states its own period by
  repeating the whole lattice-and-course motif, rows 8..31 again at 32..55,
  so the cycle is 24 rows and the roof carries its drawn courses across the
  depth instead of a bare lattice. The band below them is the roof's
  fascia, wider than the wall it covers, so it belongs to the roof and
  lands on the south rim. Note the museum is TWO drawings: this hall and
  the east entrance beside it, which is B18 and shares its drawing with the
  Route 2 gate.
- The rest of the 2:1 sloped-roof buildings: both gym drawings (the
  standard one at Cinnabar, Pewter, Vermilion and Viridian plus the
  Fighting Dojo, and the wider Celadon / Cerulean / Saffron one), the 4x2
  cottage that houses Mr Fuji, the Cubone house, Bill's grandpa, the Name
  Rater and the Viridian school, Cerulean's three wide houses, the day
  care, and three scenery blocks -- among them B01, which at 19 placements
  is the commonest drawing in the game. Each one's roof band is pixel for
  pixel one of the three already authored, so they take that sibling's band
  table unchanged: 16 rows for Red's house's, 32 for Oak's lab's, 64 for
  the museum's.
- The Safari Zone rest houses and the Victory Road entrance, the first
  buildings outside the `OVERWORLD` tileset -- `buildings` is keyed by
  tileset and until now only had the one section. The rest house's
  corrugated roof repeats every 5 rows rather than the overworld lattice's
  8, which is the point of `roofCycle` being authored per building.
- Route 10's scenery block, via a new `seal` field. Its drawing has no
  black base course -- it ends on a row of light brick -- so the silhouette
  flood climbed in from the south border through the mortar and hollowed
  the wall out, leaving 72% of the sprite in 65 pieces. `seal` names the
  sides a drawing runs off rather than closing, and the flood does not seed
  there: sealed, it is 95% in one piece, and the model is its twin the
  museum's. No other building sets it, and none changes by a voxel.
- Together these take the mod to 31 of the catalogue's 34 drawings and 144
  of its 147 placements. The last three, and why each resists, are written
  up in `assets/docs/buildings/REMAINING.md`.
- A roof no longer runs past the drawing's own silhouette. These sprites
  are inset from their boxes, and the columns outside the inset carry no
  roof: they now get none, and the fascia belongs to the outermost columns
  the drawing actually paints. Before, they raised a four-voxel slab of
  black kerb the full depth of the building, flanking its walls at ground
  level. Nothing shipped hit this -- Red's house and Oak's lab are drawn
  edge to edge -- so no existing model changes by a single voxel.
- Windows and doorways sink a voxel behind their frames, found rather than
  listed: a pane is a non-black region the drawing seals off behind its own
  black outline. A nested frame (the door's own little window) layers for
  free.
- `tools/building_voxels.py`: the reference implementation of the same
  algorithm, with the geometric asserts and isometric previews Stage 5 of
  the methodology calls for. It and the runtime agree exactly on voxel and
  shell counts for all 19 templates -- 96,617 / 12,866 for Red's house up
  to 3,715,963 / 146,762 for Silph Co, which ship as 3,410 and 13,994
  quads. Its slope asserts read the drawn columns only and stand down for a
  roof with no taper, where the check is that the roof is level instead;
  its previews fit the projection to the model rather than to a fixed
  camera, so a building taller or deeper than the first two still lands on
  the canvas.

- A sky at the 75-degree rung. Pitched that far over, the horizon comes
  into frame and a good part of the picture is void, so the void gets
  filled instead of reading as the black plate it does at every rung below.
  No skybox and no geometry -- it is the colour the scene canvas clears to.

  **Outdoor maps only.** A house, a cave or a gym is a room with a ceiling,
  and the void past its walls is the outside of a box rather than open air.
  The test is `Map.isOutdoor`, the same one the engine uses for door SFX
  and the town map, and the same one `Structures` already asks to decide
  whether a map rings with trees.

  The colour is a four-shade ramp shaped like a world palette and run
  through `PaletteFX.effectiveColors`, so it answers to the display mode
  exactly as the baked terrain does: blue in the colour modes, grey under
  GRAY, green under CLASSIC, dark under GBC INV. A hardcoded blue would sit
  wrong in every mode that is not a colour mode. It fades across the
  approach to the top rung rather than switching at the keypress, so it
  arrives with the camera tween.

- The mod's four controls sit on adjacent keys, and the two that never had
  one now have a hotkey at all:

  | key | control |
  | --- | --- |
  | 3 | VOXEL, the camera ladder |
  | 5 | V-GRID, the wireframe |
  | 6 | T-SHIFT, the blur ladder |
  | 7 | V-CURVE, the horizon bend |

  Only 6 arrives by the documented route. `Game:keypressed` answers the
  engine's own display keys first and returns -- 2 COLORS, 3 TILT, 4 ZOOM,
  5 GBC FX -- and only then offers the key to `Pipelines.hotkey`, expressly
  so that "a pipeline can never shadow one". Two of the four wanted keys are
  in that set, and V-GRID and V-CURVE own no render pass, so they have no
  registry to claim a key from in the first place. The mod wraps
  `Game:keypressed` to take the four. Polling the keyboard in `update`
  would not do: it fires alongside the engine's handler rather than instead
  of it, so 3 would cycle this mode AND the engine's TILT on one press.

  **TILT (3) and GBC FX (5) are no longer reachable by key while this mod
  is enabled.** Both are still on the OPTIONS menu. Key 9 is now free.

  So the VOXEL key turns both off itself, on every press. Both fight the
  diorama -- TILT is the flat fake of what this mode does for real, GBC FX
  a full-screen present pass laid over the top -- and with 3 the only key
  that now reaches either, it also has to be the way back from having left
  one on. Every press, not just the one that switches the mode on: the
  registry's own tilt exclusion covers switching ON, but the press that
  cycles the ladder round to OFF would otherwise leave both running with
  no key left to clear them.

  The wrapper delegates rather than reimplements: `Pipelines.hotkey` still
  applies its own gate and ladder, the settings borrow the same free-roam
  gate the voxel pipeline uses, and a screen with its own key handler keeps
  the keyboard -- so typing a nickname cannot cycle a render mode behind
  the text box.

- `lib/ShadowMap.lua`: the scene rendered once from the sun into an
  orthographic depth map, which the main pass then samples per fragment.
  What the sun cannot see is in shadow, whatever surface it is, so a
  shadow climbs a wall, drapes over a roof and slides across a passing
  NPC with no case in the code -- and every caster is simply whatever the
  pass draws. The terrain mesh goes in, which means buildings, trees,
  ledges, signs and every prop cast, where before only characters did.
- Depth is packed into two 8-bit channels of an ordinary color canvas
  (~16 bits over a ~700px frustum, a hundredth of a world pixel).
  Readable depth textures are the least portable corner of the graphics
  API, and the mod's contract is that an unsupported driver falls back
  rather than errors: `available()` reports, and VoxelScene keeps the old
  flat decals when it says no.
- The map resolution is picked per frame from a 1024/1536/2048 ladder
  against a 0.45 world-pixels-per-texel target, because the light frustum
  is fitted to the world view and that swings 3x between the closest zoom
  and a maximised window at the widest. The frustum is snapped to whole
  texels, without which every shadow edge in the world crawls as you walk.
- Ambient occlusion, the genuine article: each vertex counts the
  neighbours crowding it and steps down once per neighbour, on top faces
  (four corners, three neighbours each) and now on upright faces too --
  the crease a wall rises out of, and the inside corners where flanking
  columns box it in. It is the complement of the shadow pass rather than
  a duplicate: the map draws the long directional shadow, this draws the
  dark seam in every corner the sky cannot see into, at scales finer than
  a shadow map texel.
- Plus a ground-contact term for the prebuilt prop quads -- per-pixel
  plants, signs and lone trees, and the round-tree stamps. Those arrive
  from Structures already finished, so the neighbour counting has no
  columns to count; what it can still say is that the floor blocks half
  the sky, so a voxel's first 6px of rise ramps back to full light. It is
  what stops a prop reading as pasted over the ground rather than
  standing on it, and outdoors it is most of what AO does at all, since
  trees and posts are nearly all prop geometry.
- One knob for the lot: `AO_STRENGTH` in `ChunkMesher` scales every term
  (they are written as darkening amounts, not multipliers), against a
  floor that keeps a crank from punching holes of pure black.
- The **V-CURVE** row in OPTIONS: the curved world, the Animal Crossing
  horizon. Every vertex is pushed down by the square of its horizontal
  distance from the camera's focus, and that is the whole effect -- a
  quadratic is nearly zero near its vertex, so the ground being played on
  stays flat, and the falloff accelerates, so the far edge rolls away over
  a near horizon and the town reads as sitting on a small sphere.
- It is deliberately NOT a fisheye. A fisheye is a LENS -- a screen-space
  warp -- which bends straight lines everywhere including right in front of
  the player, resamples every pixel to do it, and would leave this mode's
  art blurred and crawling. Bending the WORLD is one line in the vertex
  shader: lines near the camera stay straight and not a pixel is resampled.
- Displacing along Y only is what keeps it readable rather than
  nauseating: the drop depends on where a column stands, not how tall it
  is, so the world tips away and the buildings on it stay upright.
- Shadows and the wireframe ride along for free. Both are already worked
  out before the bend -- the shadow map in flat world space, the grid in
  model space -- so the bend carries them exactly as if they had been
  painted on, and neither the light frustum nor the grid needs to know the
  curve exists. `Voxel3D.project` applies the same drop on the CPU, which
  is what keeps the overworld's 2D field FX on their ground points.
- The strength scales with the view height, so a rung reads the same at
  every zoom, and the ladder is calibrated against the far edge of the
  visible ground rather than against nothing.
- `lib/ModSetting.lua`: the ladder/store/rows a setting of this mod's own
  needs, now that there are two of them. V-GRID's copy of it moved here.
- A **75 degree** rung on the VOXEL ladder, below the 15/35/50 it shared
  with the engine's TILT: low enough to read as a diorama shot from table
  height. Tilt could not have it -- its flat plane degenerates into a
  horizon line down there -- but geometry only gets more of itself to show.
- The **V-GRID** row in OPTIONS: a one-display-pixel wireframe along every
  voxel edge, 3D Dot Game Heroes style. Every mesh here is built one unit
  per voxel in its OWN model space, so the seams are that space's integer
  planes, and reading them in model space rather than world space is what
  keeps them glued to a thing however it is posed -- a character's slab
  leans back by the camera's pitch and its seams lean with it.
- The seams fade out where a voxel shrinks under about 3 display pixels.
  Survey zoom draws a world pixel at roughly a display pixel, and a wall
  seen nearly edge-on squashes one to nothing at any zoom; drawn anyway,
  the lines land closer together than they are wide and the wireframe
  stops being a wireframe and becomes a flat 45% dimming of the scene.
- `lib/VoxelGrid.lua` owns the toggle. It is NOT a pipeline: it owns no
  pass of the frame, it parameterises the voxel one, so it has nothing to
  put in `drawWorld` or `present` and the registry rightly rejects it. A
  plain mod setting instead -- `options:define` for the store and the mod
  manager's page, `ui.options.rows` for the row in OPTIONS next to VOXEL
  and T-SHIFT. Both rows read and write the one stored value.
- The wireframe is a SECOND COMPILATION of the scene shader rather than a
  branch inside it, because it needs shader derivatives (`fwidth`) -- the
  one part of the mode a driver can refuse. A refusal costs the grid and
  nothing else.
- `mods/DRAMATIC_SHAPE/tests/voxel_shadow_probe.lua`: reports the fitted
  frustum and the resolution rung, dumps the map itself, and shoots a
  stand point at every pitch. `SHADOW_SUN="kx,kz"` retunes the bearing for
  one run, `SHADOW_GRID=1` forces the wireframe on, and `SHADOW_ZOOM` pins
  the zoom, without which two runs are not comparable -- a driver inherits
  whatever the player left in `options.lua`, and the world view size (which
  the light frustum is fitted to) swings 3x across that range.

- A `counter` class (8px, upright): half-cell furniture. One 8px band,
  so exactly the drawing's bottom row stands up as the front and every
  row above it rides the top face in drawn order. `table`'s 12px could
  not be retuned for it; the houses share that class.

- `tilesets.POKECENTER` in `data/voxel_heights.lua`. Before it, the
  detector merged the wall-touching counters and healing machines into
  the wall band and towered them 3-6 blocks, flattened the machines'
  near-black screens to void, read the pillar bases, plant pots and
  machine bodies as ponds (the $14/$32/$48 stale-cache water fallback),
  boxed each plant pair into one hedge cube, and extruded the lounge
  seat -- a PERSON is drawn into its tile art -- into a monolith wearing
  his face.
- The pins, by shape: the wall band, windows, poster, pillars and the
  16px machine bodies are `wall`; the counters (with the nurse's tray)
  are `counter` and the PC's desk is `table`; the machine screens and
  the PC are `billboard`, standing on the pinned boxes below them; the
  potted plants are `prop` standees like every other interior plant.
- The lounge couch with the man sitting on it is a `counter` box: its
  bottom row stands up as the couch's front and the cushion and the man
  ride the top face, each drawn exactly once.
  He cannot be stood upright, and the reason is structural rather than a
  tuning question. His skin pixels span two tile rows and stop dead at
  the row 9/10 seam; folding two rows upright requires both to share a
  class, which makes the box two tiles deep, and a fully folded box
  repeats its north row across its whole top face. So every upright
  arrangement puts his head on screen two or three times -- as a 16px
  seat-back, on the front and twice more on the top; as a 32px bookcase,
  a cabinet taller than the room's own walls. Dropping the seat in front
  of him to floor level only changes which copy you see. Nor can he be a
  standee: the drawing has no floor margin, so all three non-black
  shades touch the cluster rim and the mask drains 307 of its 420
  interior pixels -- 46% of him even segmented alone, because his skin
  is the same light shade as the couch behind him.
- Survey evidence: full before/after passes of VIRIDIAN_POKECENTER at
  15/35/50 degrees, plus spot-checks of CELADON_POKECENTER and
  CELADON_HOTEL (shared tileset, both inherit correctly) and of
  REDS_HOUSE_1F, OAKS_LAB and VIRIDIAN_CITY (unchanged -- the new class
  is additive and no other tileset lists it).

### Changed

- Pinned props are segmented the way the art is authored: objects wear a
  black outline, so background is the shades touching the cluster's edge
  (white floor around a TV, grey tabletop around a vase) flooded in from
  the aprons; the outline, its interior, paint whites and anything they
  enclose survive -- pixel-perfect cutouts on any surface.
- Indoor structure analysis floods background from all four aprons and
  accepts ground contact on any side (outdoors keeps the south-only rule
  that protects roofs), so face-on furniture drawings voxelize per pixel
  instead of rising as wall-height volumes.
- Profile-pinned standees are 10px deep (detected props stay 6px), so a
  deliberate object like a TV keeps a body at shallow camera angles.
- Authored upright boxes fold their artwork up every face (flanks and
  back wear the front stack darkened) and top faces keep the drawn
  tabletop: face-on rows wear the row above the fold instead of
  repeating their front art lying flat, and a run that folded entirely
  tops with the furniture row drawn above it (a bookcase's shelf trim).
- Characters no longer ride a pinned stair tile's class height: stairs
  are walked through at floor level, fixing the step-up onto thin air in
  front of stairwells.

- A voxelized building is as tall as its facade plus its roof slab rather
  than as tall as its drawing: the roof rows are DEPTH now, not height, so
  Red's house is 36px over a 4x3-cell plot instead of a 48px cube.
- Round trees (the `cylinder` pin: lone canopies and the border tree
  wall) stop being lathes -- the sprite wrapped around a 12-segment
  column read as exactly that, art smeared on a barrel. Each cell is now
  a real voxel hull: the canopy is segmented out of its cell as the
  darkest-pixel outline plus everything it encloses (which also drops
  the background grass that used to inflate every row to full width, and
  the cast shadow under the ball), and each mask row runs its own span's
  circular chord in depth -- the front view is the sprite pixel for
  pixel, the plan view is the sprite's width profile turned in depth.
  Dithered art with no closed outline (the tree wall) falls back to
  light-shades-only flooding, per the methodology doc's boundary rule.
  Sides de-outline like building extrusions so flanks read as canopy
  rather than solid black, and dome caps keep their outline on the rim
  while the interior samples the canopy a couple of rows deeper.
- A `post` standee pool, pinned for the overworld's vertical fence-post
  cell (tiles 14/85 -- across every map the pair appears only as this
  cell). The detector already turns HORIZONTAL fence runs (tile 57) into
  per-post standees, but a vertical run of repeated cells trips its
  scenery-repetition guard and fell to the volume path as a
  fence-textured tower (Viridian's west line, Route 25).
  `post` extracts every CELL as its own cluster -- pooled clustering
  would stand the whole line up as one drawing-tall slab at one depth --
  and classifies pixels the way the detector does (non-white is body)
  rather than by the pinned-prop outline rule, which would strip the
  posts to black skeletons; at the detector's own 6px depth, pinned and
  detected fences look alike.
- Town signs move from the `billboard` pool to a new `signpost` pool: the
  same per-pixel standing slab, but 2 voxels thin instead of 10. A sign
  is a plate on a stick, and the standee body that keeps a TV from
  vanishing at shallow angles read as a solid block of furniture here.
- The ground under a round tree matches the tree's own drawn background
  instead of the map's commonest ground tile. The hull's segmentation
  already knows which pixels are NOT the tree; those pixels are scored
  against every flat ground tile the map places and the closest art
  wins, per template -- so border trees drawn over checker grass stand
  on checker grass even on a map that is mostly pale path (the old
  fallback painted path under every mid-forest tree, which has no flat
  neighbour to vote with). The drawn cast shadow stays out of the score:
  no ground tile carries a shadow, and its darks would drag every match.

- Mesh builds stream in the background. `ChunkMesher` queues per-map
  build jobs and `pump()` -- driven from the pipeline's update -- runs
  them inside a few-millisecond frame budget (`lib/BuildBudget.lua`
  suspends the build coroutine mid-loop when the slice is spent). The
  camera tween holds at flat until the current map's terrain exists, so
  toggling voxel mode shows a handful of flat frames instead of a frozen
  one; neighbours pop in as they finish. Warp fades prefetch the
  destination (the pipeline update ticks while the Transition covers the
  screen, with a wider pump slice), so a door exit lands on terrain that
  is already built.
- Vertex packing goes through FFI into one native buffer
  (`Mesh:setVertices(ByteData)`) instead of a Lua table per vertex --
  the headless table path remains for the pure `geometry()` API and its
  suite.
- Round-tree hulls are carved once per (tileset, art, ground set) and
  kept as stamps -- template plus cell offset, expanded during vertex
  packing -- instead of materialized per-cell quad tables. A route's
  border forest was ~500 quads x hundreds of cells of retained heap.
- Mesh and analysis caches evict down to the live neighbourhood (current
  map + rendered neighbours, plus one set of history so a house
  round-trip keeps the town warm). Evicted meshes are released
  explicitly. Memory over Pallet -> Mt Moon: was ~2.9GB and monotonic,
  now oscillates between ~90 and 200MB.

- `Voxel3D.SHADOW_KX/KZ` are -0.85 / -0.55, from +0.30 / +0.45: the sun
  crosses to the southeast and drops from 62 degrees to 45. The bearing
  leans WEST of northwest on purpose -- a character is drawn as a slab
  leaning away from the camera, which covers the ground due north of its
  feet, so a shadow thrown straight up-screen lands entirely underneath
  the figure casting it and is never seen.
- `Voxel3D.SHADOW_ALPHA` 0.32 -> 0.40, a quarter darker.
- `FACE_SHADE` east 0.78 -> 0.84 and west 0.78 -> 0.72. The two were equal
  because the old sun sat due northwest and they were symmetric about it;
  under a southeastern sun east is a lit flank and west a shaded one.
- A character's shadow lookup runs off the UPRIGHT card the sun saw, not
  the leaning slab the camera sees (`Voxel3D.draw`'s `sunModel`). Casting
  the leaning slab instead would shrink every shadow to nothing as the
  camera flattened toward top-down; looking up with the leaned position
  put each sprite's own card across its front.
- The contact-shadow term in `ChunkMesher` was a one-directional stripe
  keyed to a northwestern sun -- two neighbours, one corner, top faces
  only. It is now the ambient occlusion above.
- The light frustum is fitted to the ground the CAMERA CAN SEE rather than
  to a view-sized box around the focus, and both of its margins are now
  asymmetric -- for opposite reasons. The camera sits south of its focus
  and looks north, so the ground it sees runs far north and barely south;
  the sun sits southeast, so the casters for that ground stand south and
  east of it. Paying for a view-sized box plus caster margin on all four
  sides covered about a third of what was on screen at 75 degrees, and
  overpaid at 15.
- Shadows ease off at the frustum's rim instead of ending on it. Past the
  low rungs the horizon is further out than any box worth paying for, and
  a covered region that simply stops draws a hard line across the middle
  distance where every shadow ends at once.

The Pokemon Center interiors. One `POKECENTER` group in
`data/voxel_heights.lua` plus one new class, and because
VIRIDIAN_POKECENTER places every tile the tileset's other maps use, the
one pin set covers all eleven Centers and the Celadon Hotel.

### Fixed

- The generic town-house tileset (`HOUSE` -- Blue's house, Daisy at her
  table, and eighteen more homes, the schoolhouse and the trashed house
  among them) is now pinned in `data/voxel_heights.lua` the way Red's
  rooms already were: the dining table stops towering as a wall-height
  volume and sits at table height with its front folded upright, stools
  become seat-high boxes that characters sit on, the corner potted
  plants become per-pixel standees instead of texture-smeared box
  stacks, the bookcases get clean capped tops, and the wall band (with
  its window, picture and the schoolhouse blackboard) stays one 16px
  face.  The schoolhouse's open book stands on the pinned tabletop as a
  cutout, and the trashed house's ransacked table corner keeps table
  height.
- Interior door mats lie flat again in Red's and the generic houses.
  Their collision tile is $14, which the engine's stale-cache fallback
  counts as water in every tileset, so the rug recessed into a pond lip;
  a `ground` pin now overrides the water read.

- Stray pixels along map seams: ring props (border-tree hulls) whose
  quad CENTER sat exactly on a neighbour body's edge line escaped the
  strict point-in-rect mask and survived as fragments of otherwise
  dropped trees. Object quads now keep/drop by their full extent,
  boundary inclusive; props straddling the body edge also stay whole
  instead of shedding their outer half.
- The one-step "ledge hop" when crossing a connection into a tree-ringed
  map: the seam step stands the player one cell off the new map, where
  `Map:cellTile` border-extends into the borderBlock -- a raised tile on
  maps ringed with trees. Off-map ground now reads as height 0 (the
  departed neighbour's flat walkway, which is what is actually rendered
  there).

- Cycling palette modes with voxel mode on eventually killed the pipeline
  outright: `attempt to call field 'atlasImageData' (a nil value) --
  disabled for this session`. Nothing brought it back short of a restart.

  `TerrainAtlas` reads three engine seams to animate water and flowers in
  the terrain texture, and this build ships only one of them
  (`defaultAnimatedTiles`). The tile clock, `animFrame`, was already read
  guarded and simply degrades. `atlasImageData` was called straight -- but
  only down the branch where the mod had NOT baked the atlas itself, which
  is why it looked stable until a palette changed. Every mode with no world
  palette for the map (`PaletteFX.pal` answering nil), plus RED++ and any
  trueColor tileset, takes that branch, so the first map with animated
  tiles entered under one of them threw out of `drawWorld` and the engine
  disabled the pass for the session, exactly as it should.

  The seam is now read guarded like its sibling, and when it is absent the
  pixels are recovered rather than given up on. An atlas neither we nor
  RED++ replaced is the tileset art itself, so animation carries on from
  the art on disk. RED++'s per-map bake exists only as a texture --
  `getGbcAtlas` throws its `ImageData` away -- so that one comes back off
  the GPU: the atlas is drawn 1:1 into a canvas and read back, once per map,
  with the pass's own render target captured and restored around it (the
  usual `setCanvas()` would drop the rest of the frame). A driver that
  refuses the readback declines to animate and keeps the static atlas.
  Worst case now costs one animation, never the pipeline.

- Water and flowers did not animate in voxel mode at all, and had not since
  the mode shipped -- a silent one, since the terrain was otherwise correct.

  The tile clock is the third seam, and this build does not export it
  either. Being read guarded, it answered 0 forever instead of throwing,
  which pinned every animated tile at step 0. `animFrame` is a plain local
  in `TileRenderer`, but an upvalue of the exported `tick()`, so the mod now
  reads the real counter through it. That it is the ENGINE's counter is the
  point: the flat tile layer draws from the same number, so toggling voxel
  mode mid-cycle continues the animation rather than restarting it. A build
  that exports `animFrame()` outright is preferred; a build that hides the
  local falls back to wall time in 60Hz steps, which free-runs against the
  2D path but still moves the water.

- Toggling palettes in voxel mode flashed the flat 2D world for a moment on
  every switch.

  `PaletteFX.setMode` reloads the live map to rebuild its atlas, and this
  mod dropped that map's terrain mesh on any `map.reloaded` at all. Mesh
  builds are asynchronous, so the frames between the drop and the first
  rebuilt mesh had no terrain to draw -- and a voxel `drawWorld` with no
  terrain returns nil, which is exactly how the pipeline asks for the 2D
  fallback. The flash was the mod correctly reporting that it had nothing
  to show.

  The geometry was never stale: the mesher reads block layout and tile ids
  and never reads colour, and the palette lives entirely in the texture
  `TerrainAtlas` hands back per frame, keyed by palette and so already
  rebuilt by the next frame. A reload whose reason is `colors` now keeps
  the mesh, and the new palette lands on the diorama already on screen in
  one frame. Every other reload -- warps re-entering a map, hot reload, a
  replaced block -- still drops it.

- Every non-colour palette mode rendered as SGB in voxel mode: GRAY and
  both INVERTED modes came through as the map's blue.

  `paletteFor` hands a pipeline the map's RAW SGB zone palette. The flat
  path runs that through `PaletteFX.effectiveColors` on its way to the
  shade-remap shader, and that call is where the non-colour modes actually
  happen -- OG and OG INV swap in the DMG greys (reversed for the latter),
  CLASSIC swaps in the green set, GBC INV permutes the zone's own shades,
  and only GBC and RED++ pass through. This pass bakes colour into the
  atlas and the sprite sheets ahead of the draw rather than shading at blit
  time, so it never reached that call and painted the raw zone palette in
  every mode.

  Both bakes now run the same transform the shader would have. Terrain and
  characters go through one resolve, so they cannot disagree about what
  mode is on.

- VOID FILL did nothing in voxel mode, in two separate ways.

  **BLACK crashed the build.** The mode is not a block at all --
  `TileRenderer.borderBlockFor` answers `false` for it -- and `Structures`
  added 1 to that `false`. The arithmetic threw, which failed the mesh
  build for every map in the neighbourhood, which left the mode with no
  terrain and dropped it to the flat 2D path entirely. It now builds no
  ring: `tileLookup` answers nil past the body and those keys are never
  written, which the rest of the file already copes with -- every
  neighbour query in it reaches one step outside the analysed range and
  reads nil for its trouble, so an absent cell is the shape "nothing" has
  always had here.

  **WATER changed nothing on screen.** The ring is BAKED INTO THE MESH in
  this mode rather than drawn each frame, and nothing dropped the cache
  when the option moved, so the old ring simply stayed until the meshes
  were invalidated for some other reason. The pipeline's update hook now
  polls `TileRenderer.voidFill` and invalidates on a change -- polled
  rather than hooked because the engine changes it from three places (the
  options row, `applyOptions` on load, `setVoidFill`) and none of them
  announces it, and checked ahead of the active() gate so switching it
  while voxel mode is off still drops what is cached.

  `mods/DRAMATIC_SHAPE/tests/voxel_void_probe.lua` walks the three modes
  and reports the border block, whether the mesh built and whether the
  scene took the 3D path. It deliberately does NOT invalidate the cache
  itself, since doing so would hide the second half of this.

- Water and flowers did not animate. The 2D path animates them by
  OVERDRAWING the animated cells on top of the static tile layer each
  frame, which a single static mesh has no equivalent of -- the geometry
  samples one texture and that is that. So `TerrainAtlas` animates the
  texture instead: a private copy of the atlas whose animated tile slots
  are rewritten when the step advances, which moves every instance of that
  tile across the whole mesh at once. Which is what the Game Boy does in
  the first place (`home/vcopy.asm` rewrites the tile's VRAM bytes); the
  overdraw is the port's workaround for a tile layer, not the original.
  ~130 pixels of work three times a second, on the same
  `TileRenderer.animFrame` clock the 2D path uses, so the two can never
  disagree about which frame they are on.
- The frame files (`flower1..3.png`) are raw grayscale and have to land on
  the colours of the tile they replace, but the two recolour paths do not
  share a rule -- SGB bakes one world palette over everything, RED++ picks
  a palette group per tile graphic. So the shade mapping is LEARNED from
  the atlas: read the static tile's slot in the raw art and in the finished
  atlas side by side and ask what each shade became. Right under both
  without this file knowing which one ran.
- Terrain art was off the pixel grid by up to half a pixel, with one art
  pixel per tile sampled twice and another never at all. A tile is 8
  texels across 8 world pixels -- one texel per pixel exactly -- and
  `ChunkMesher`'s uv inset squeezed that art into a 7-texel sample range
  while the quad still covered 8 world pixels, so it advanced 7/8 of a
  texel per pixel and drifted. The inset exists to stop the rasteriser
  reaching a neighbouring tile along a shared edge, but half a texel was
  fifty times more than that needs: 0.02 is as safe (interpolation error
  is nowhere near it) and drifts 0.25% of a pixel across a whole tile.
  Nothing showed the fault until the voxel wireframe drew the grid those
  pixels were supposed to be sitting on.

### Changed from the pre-mod version

- The level is no longer the mod's to keep. The engine owns the ladder, the
  options rows, the hotkeys, persistence and the TILT exclusion; the mod
  keeps only the camera-angle tween.
- Persistence moved from `save.options.voxel` / `save.options.tiltshift` to
  `save.options.pipelines.voxel` / `.tiltshift`.
- Hotkeys moved from `4`/`9` to `3`/`6`: the fork already uses `4` for
  survey zoom.
- The tilt-shift pass is a declared `worldPresent` stage rather than a call
  spliced into the world draw, so it composes with any world pipeline
  instead of only this one.
- The cut-tree animation now draws in voxel mode; the pre-mod version
  omitted it from the 3D field-effect list.
