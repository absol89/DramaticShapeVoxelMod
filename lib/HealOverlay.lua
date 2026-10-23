-- The Pokemon Center heal overlay, put where the machine actually is.
--
-- AnimateHealingMachine (engine/overworld/healing_machine.asm) is OAM: a
-- monitor tile over the console's screen and one ball per healed mon in two
-- mirrored columns, all blinking through the jingle.  The GB draws them at
-- FIXED screen coordinates with the player's cell BG-aligned at (64,64), and
-- the engine keeps that: fxHeal paints each tile at `ha.px - 64 + dx`,
-- `ha.py - 64 + dy`, and ctx.drawFx slides the whole block onto ONE projected
-- point -- the player's own feet.
--
-- That is exactly right for a flat renderer and wrong for this one.  The art
-- belongs about 60 world pixels north of the player, on a cabinet 17 voxels
-- tall; a perspective camera foreshortens that lever arm, so a rigid -60px
-- screen slide overshoots upward and the balls and the monitor hang in the
-- air over the machine.  Measured against the machine's own surfaces the
-- block rides ~9px high at the 35 degree rung and ~14px at 50 -- and the
-- monitor and the balls drift by DIFFERENT amounts, so no single corrected
-- anchor seats them both.  Only per-piece placement does.
--
-- So this hands back world points, not a screen offset.  The drawing that
-- voxel_heights.lua extrudes into the machine and the drawing the OAM lands
-- on are the same 32x32 grid, and Buildings extrudes its front elevation by
-- one rule -- drawn row r stands at height GROUND_ROW - r, from the base's
-- last row on the floor to the console's lid.  Reading the OAM offsets
-- through that rule is all it takes: the monitor comes out on the console's
-- face inside the inset the drawing cuts for it, and the balls come out on
-- the cabinet's front panel in the two columns the fascia notches.
--
-- Placing a piece is only half of it: it also has to be the right SIZE on
-- the machine, and the flat renderer's pixels-per-world-pixel is not that
-- number on every rung.  See `place` below, which measures it.
--
-- Kept OUT of the flat and tilt paths, which want the GB's own placement and
-- already get it.  See tests/heal_overlay_test.lua, which holds every number
-- below against the center_heal_machine template it was read off.

local V = ...

local HealOverlay = {}

-- TEST232: the machine as geometry (HealBalls3D): real Poke Balls in its
-- slots and a lit screen, drawn inside the world pass. Its hook goes into
-- the late seam NOW, as this module loads (main.lua requires it ahead of the
-- modules that wrap the same seam), so the very first heal frame is 3D.
-- `false` once it would not load: this file then behaves exactly as before.
local balls3D
local function threeD()
  if balls3D == nil then
    local ok, B = pcall(V.require, "HealBalls3D")
    balls3D = ok and type(B) == "table" and B or false
  end
  return balls3D or nil
end
do
  local B = threeD()
  if B and B.install then pcall(B.install) end
end

-- The plot, relative to the cell the player healed on.  Not a guess: the
-- engine paints the monitor tile at flat world (px - 20, py - 44), and that
-- tile's lit rectangle is the console inset at grid (13, 6) -- so the tile's
-- top-left is grid (12, 4) and the plot's north-west corner is 32 west and
-- 48 north of the heal cell.  Whichever machine of the pair the player is
-- standing at, they are standing at it the same way.
local PLOT_DX, PLOT_DY = -32, -48

-- The plot's two front planes, in plot-local depth.  The cabinet's box runs
-- `depthPx` 10 back from `desk.z` 16, and the console stands on its lid,
-- `depth` 4 from its own `z` 20 -- so the console's face sits 2px behind the
-- cabinet's, which is why the balls and the monitor do not share a plane.
local FRONT_Z, CONSOLE_Z = 26, 24

-- The whole front elevation extrudes upward off the floor line: drawn row 31
-- is the ground, the base band climbs to 14, the fascia's two rows are the
-- lid's edge at 16 and 15, and the console's facade carries straight on
-- above it.  One rule the length of the machine.
local GROUND_ROW = 31

-- The OAM, engine-side (OverworldController's fxHeal and HEAL_BALL_XY): a
-- tile's top-left goes to flat world (ha.px - 64 + dx, ha.py - 64 + dy), so
-- its plot grid position is (dx - 32, dy - 16).  `true` is OAM_XFLIP, the
-- right-hand column.
local GRID_DX, GRID_DY = -32, -16
local MONITOR = { 44, 20 }
local BALLS = { { 40, 27 }, { 48, 27, true },
                { 40, 32 }, { 48, 32, true },
                { 40, 37 }, { 48, 37, true } }

-- Where the ink actually sits inside each 8x8 tile of the player's own
-- extracted heal_machine sheet (PokeCenterFlashingMonitorAndHealBall, found
-- through field.overworldFx like the engine finds it): the monitor's lit
-- rectangle is x 1..6, y 2..4, and the ball is x 2..7, y 2..7.  The tile is
-- mostly margin, and it is the INK that has to land on the machine, so every
-- point below is the centre of the ink.
local MONITOR_INK = { x = 4, y = 3.5 }
local BALL_INK = { x = 5, y = 5 }

-- How far the whole ball group stands off the drawing's own reading, in
-- world pixels, applied equally to all six.
--
-- The drawing puts them lower than the machine wants them here.  The
-- cabinet's dark front panel is drawn rows 17..28, so its last row extrudes
-- to height 3 and the cream lip at the machine's foot takes rows 29..30
-- below it, while the ball art's ink reaches down to height 2 -- a pixel
-- past the panel, hanging over the lip.
--
-- 1 to 3 is the whole usable range.  Below 1 the bottom row hangs over that
-- lip; above 3 the top row's ink reaches into the console's screen, the
-- inset drawn rows 6..8 whose bottom edge stands at height 22, covering the
-- very surface the monitor tile is drawn on.  Inside the range it is a
-- matter of looks, and 2 is the one that reads right on the machine.
--
-- It moves the WORLD point only, not the ink's place inside its tile --
-- shifting BALL_INK instead would cancel itself out, because the blit
-- offsets from the same number the height is measured with.
HealOverlay.PANEL_ROWS = { 17, 28 }
HealOverlay.BALL_LIFT = 2

-- FlashSprite8Times XORs rOBP1 ($28): the sprites never disappear, the two
-- middle shades swap in place.  ha.visible == false is that half of the beat.
local FLASH_MAP = { [0] = 0, [1] = 2, [2] = 1, [3] = 3 }

-- The overlay's OBJECT palette out of an ADVANCED (RED++) pack's `world`
-- table, plus the group it came from, or nil when the pack has no OBJ data.
--
-- ADVANCED bakes the world true colour and bakes the OBP into every sprite
-- SHEET as it loads (SpriteRenderer:resolveImage), which is why
-- ctx.spriteColors answers nil there: nothing is left to colorize.  The heal
-- sheet is the exception.  It is not a sprite def, nothing bakes it, and it
-- reaches the canvas in its raw DMG greys -- grey Poke Balls on a fully
-- coloured machine.
--
-- The GB gives the whole overlay one palette (OBP1) and so does this, taking
-- the pack's own OBJ group 0, the one it assigns the player.  That is not an
-- arbitrary pick: the ball art is drawn as outline, upper body, lower body
-- over shades 3, 2 and 1, and group 0 answers those with black, (255,58,8)
-- red and a pale body -- a Poke Ball, which is what the art is.
--
-- Pure, and separate from the pack lookup, so the choice is checkable
-- without a GPU or a running map.
function HealOverlay.objPalette(world)
  local palettes = world and world.spritePalettes
  local assign = world and world.spriteAssignment
  local group = assign and assign[0]
  if not (palettes and type(group) == "number" and palettes[group]) then
    return nil
  end
  return palettes[group], group
end

-- The plot's north-west corner in world pixels, from the heal cell.
function HealOverlay.plot(ha)
  return ha.px + PLOT_DX, ha.py + PLOT_DY
end

-- One record per piece the overlay draws, in world space:
--   kind   "monitor" or "ball"
--   x, h, z   the point the piece's ink is centred on -- east, up, south
--   flip   the right-hand ball column, drawn mirrored like its OAM
--   ink    where that centre lies inside the 8x8 tile, for the blit
local function piece(kind, px0, py0, oam, ink, plane, lift)
  local flip = oam[3] == true
  local gx = oam[1] + GRID_DX
  local row = oam[2] + GRID_DY
  return {
    kind = kind,
    -- a mirrored tile draws leftward, so its ink centre reflects across the
    -- tile's own width rather than staying put
    x = px0 + gx + (flip and (8 - ink.x) or ink.x),
    h = GROUND_ROW - (row + ink.y) + (lift or 0),
    z = py0 + plane,
    flip = flip,
    ink = ink,
  }
end

function HealOverlay.points(ha)
  local px0, py0 = HealOverlay.plot(ha)
  local out = { piece("monitor", px0, py0, MONITOR, MONITOR_INK, CONSOLE_Z) }
  local lit = math.max(0, math.min(tonumber(ha.lit) or 0, #BALLS))
  for i = 1, lit do
    out[#out + 1] = piece("ball", px0, py0, BALLS[i], BALL_INK, FRONT_Z,
                          HealOverlay.BALL_LIFT)
  end
  return out
end

-- The sheet, cached on the overworld state under the ENGINE's own field
-- names.  fxHeal populates these lazily too, and it still runs on the flat
-- and tilt paths, so the two share one image and one pair of quads instead
-- of each holding its own copy of an 8x16 texture.
local function sheet(state)
  local Game = require("src.core.Game")
  local field = Game.data and Game.data.field
  local def = field and field.overworldFx and field.overworldFx.healMachine
  if state.healMachineImg == nil and def then
    local ok, image = pcall(love.graphics.newImage, def.path)
    state.healMachineImg = ok and image or false
  end
  local img = state.healMachineImg
  if not img then return nil end
  if not state.healMachineQuads then
    local w, h = img:getWidth(), img:getHeight()
    state.healMachineQuads = {
      love.graphics.newQuad(0, 0, 8, 8, w, h),   -- monitor ($7c)
      love.graphics.newQuad(0, 8, 8, 8, w, h),   -- ball ($7d)
    }
  end
  return img, state.healMachineQuads
end

-- ------- standing behind what stands in front

-- The overlay is composited flat, after the geometry, with the depth test
-- off -- so it paints over the counter the player is standing at, and in a
-- low orbit or in first person the balls hang in front of a counter that is
-- nearer the eye than they are.
--
-- The frame's own depth buffer already knows better.  beginOverlay binds the
-- colour canvas alone, which leaves that texture readable, so the sprites can
-- do the test the hardware would have done: sample the scene's depth under
-- each fragment and drop the ones the scene is in front of.  Same comparison,
-- same window-depth convention, as the water's self-occlusion test.
--
-- The palette remap rides along in the same shader because a fragment can
-- only be discarded where it is coloured; the three thresholds are
-- PaletteFX.shader()'s, which is the copy to keep this honest against.
local OCCLUDE_SHADER = [[
  extern vec3 c0; extern vec3 c1; extern vec3 c2; extern vec3 c3;
  extern LOVE_HIGHP_OR_MEDIUMP Image depthTex;
  extern float pieceZ;
  vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    if (pieceZ > Texel(depthTex, sc / love_ScreenSize.xy).r) discard;
    vec4 p = Texel(tex, tc);
    vec3 mapped = p.r > 0.83 ? c0 : (p.r > 0.5 ? c1 : (p.r > 0.17 ? c2 : c3));
    return vec4(mapped, p.a);
  }
]]

local occluder  -- false once the driver has refused to compile it

local function occludeShader()
  if occluder == nil then
    local ok, sh = pcall(love.graphics.newShader, OCCLUDE_SHADER)
    occluder = ok and sh or false
  end
  return occluder or nil
end

-- A piece is painted ON the face it belongs to, so its own depth TIES with
-- that face's and the test above would throw the whole overlay away.  Nudge
-- the point the depth is taken at toward the eye first -- the same move
-- Voxel3D.draw's `pull` makes for a character card leaning over the wall in
-- front of it.
--
-- Two world pixels is the whole margin needed: it clears a tie against the
-- surface the piece is painted on, and anything that genuinely stands in the
-- way is a whole tile row nearer, not two pixels.
HealOverlay.PULL = 2

function HealOverlay.depthPoint(p, eye)
  if not eye then return p.x, p.h, p.z end
  local dx, dy, dz = eye[1] - p.x, eye[2] - p.h, eye[3] - p.z
  local len = math.sqrt(dx * dx + dy * dy + dz * dz)
  if len < 1e-6 then return p.x, p.h, p.z end
  local k = HealOverlay.PULL / len
  return p.x + dx * k, p.h + dy * k, p.z + dz * k
end

-- Where a piece lands on the canvas, and how big one world pixel draws
-- there.  nil when the point is behind the camera.
--
-- The size has to be MEASURED, not assumed.  `fallback` is the flat
-- renderer's own pixels-per-world-pixel, and for the orbit camera that is
-- very nearly the answer already: the orbit frames exactly `vh` world pixels
-- top to bottom, so a world pixel is a scale pixel give or take the depth of
-- the piece.  The 1ST and 3RD rungs are not the orbit.  They ride a PLACED
-- camera (FirstPerson.frame) whose framing comes from its own 65 degree fov
-- and how far the eye stands from what it looks at, with no relation to the
-- view size at all -- standing at the counter a world pixel draws about 3.8
-- times bigger than `fallback` says, and off the boom about 1.45 times.  Sized
-- by `fallback` on those rungs the balls and the monitor come out at roughly
-- a quarter and two thirds of the size of the machine they are painted on.
--
-- So step one world pixel along each of the face's own axes, east and up, and
-- take the longer.  Head on the two agree.  Seen along the machine the east
-- step collapses while the up step does not, and taking the longer keeps the
-- piece a sensible size rather than shrinking it away to nothing.
function HealOverlay.place(project, p, fallback)
  local sx, sy = project(p.x, p.h, p.z)
  if not sx then return nil end
  local ex, ey = project(p.x + 1, p.h, p.z)
  local ux, uy = project(p.x, p.h + 1, p.z)
  local east = ex and math.sqrt((ex - sx) ^ 2 + (ey - sy) ^ 2) or 0
  local up = ux and math.sqrt((ux - sx) ^ 2 + (uy - sy) ^ 2) or 0
  local s = math.max(east, up)
  -- a camera that has no answer at all (both neighbours behind it) still has
  -- to draw something rather than a zero-sized nothing
  if not (s > 1e-3) then s = fallback end
  return sx, sy, s
end

-- Composite the overlay into the finished scene.  `project(wx, wy, wz)`
-- answers in canvas pixels and `scale` is canvas pixels per world pixel as
-- the flat renderer counts them -- the same two the rest of the FX pass
-- uses, with `scale` here only the fallback that `place` measures past.
-- Still unscaled by DEPTH within a piece, like every other billboard here:
-- a piece keeps its authored proportions and only its anchor and its size
-- on the machine move.
function HealOverlay.draw(ha, project, scale, ctx)
  -- TEST232: this frame's world pass already stood the balls and the screen
  -- on the machine as geometry: nothing is left to composite. Anything that
  -- stopped it (no Voxel3D, a draw error, the hook lost) leaves the claim
  -- unmade, and everything below draws exactly as it always has.
  local B = threeD()
  if B and B.claimed and B.claimed(ha) then return true end
  local state = ctx and ctx.state
  if not (ha and state and project and scale) then return false end
  local img, quads = sheet(state)
  if not img then return false end

  local PaletteFX = require("src.render.PaletteFX")
  -- ADVANCED hands out no sprite palette (see objPalette), the SGB modes
  -- hand out the map's, and the mono ones hand out none and want none
  local colors
  if PaletteFX.usesGbcPack() then
    local pack = PaletteFX.gbcPack()
    local palette, group = HealOverlay.objPalette(pack and pack.world)
    colors = palette and PaletteFX.darkObp(palette, group) or nil
  else
    colors = ctx.spriteColors and ctx.spriteColors() or nil
  end
  -- The flashed half of the beat swaps the two middle shades IN PLACE --
  -- rOBP1 ^= $28 recolours the sprites, it does not repaint them grey. So
  -- permute whatever palette is in force rather than always permuting GRAYS
  -- the way the flat closure does, which is what would otherwise drop a
  -- coloured overlay to grey twice a second on the ADVANCED pack.
  if not ha.visible then
    colors = PaletteFX.permute(colors or PaletteFX.GRAYS, FLASH_MAP)
  end
  -- The occluding shader colours as well as discards, so it replaces the
  -- palette one outright wherever there is a depth texture to test against.
  -- Where there is not -- a driver with no readable depth, the same case that
  -- turns the water back into ordinary terrain -- the overlay falls back to
  -- colour alone and draws in front, which is exactly what it did before.
  local Voxel3D = V.require("Voxel3D")
  local depthTex = Voxel3D.depthTexture and Voxel3D.depthTexture() or nil
  local shader = depthTex and occludeShader() or nil
  -- only the occluder has a pieceZ to be told about, and a driver that
  -- refused to compile it must not be sent one
  local eye = shader and Voxel3D.eye or nil
  if shader then
    pcall(shader.send, shader, "depthTex", depthTex)
  else
    shader = colors and PaletteFX.shader() or nil
  end
  -- GRAYS is the identity remap for a DMG sheet, so the occluding shader has
  -- something to colour with in the modes that hand out no palette at all
  -- rather than mapping every shade onto an unsent uniform.
  if shader then
    PaletteFX.sendColors(shader, colors or PaletteFX.GRAYS)
    love.graphics.setShader(shader)
  end

  love.graphics.setColor(1, 1, 1, 1)
  for _, p in ipairs(HealOverlay.points(ha)) do
    local sx, sy, s = HealOverlay.place(project, p, scale)
    if sx then
      if eye then
        local _, _, _, pz = project(HealOverlay.depthPoint(p, eye))
        if pz then pcall(shader.send, shader, "pieceZ", pz) end
      end
      local quad = quads[p.kind == "monitor" and 1 or 2]
      local top = sy - p.ink.y * s
      if p.flip then
        love.graphics.draw(img, quad, sx + p.ink.x * s, top, 0, -s, s)
      else
        love.graphics.draw(img, quad, sx - p.ink.x * s, top, 0, s, s)
      end
    end
  end

  if shader then love.graphics.setShader() end
  return true
end

return HealOverlay
