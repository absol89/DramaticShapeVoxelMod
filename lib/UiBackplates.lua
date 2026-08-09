-- The three battle-UI backplate options added for the 1.66 update:
--
--   C) SPRITE LIGHT  UNLIT / SHADED   -- whether the mon cards receive the
--      world's day tint and cast shadows (SHADED) or draw flat and full
--      bright (UNLIT). UNLIT keeps them readable on the white arena fill (B);
--      SHADED is the default OG look and is also supported on white.
--
--   B) ARENA FILL    WHITE / OFF       -- a solid white rendering layer in
--      front of the whole voxel world, with only the mons, their attack
--      animations and the menus above it. Hides the 3D terrain while keeping
--      the animated sprites -- the middle step between the OG battle and the
--      full voxel one. Works with SHADED or UNLIT sprites (UNLIT just keeps
--      the cards brighter on white).
--
--   A) TEXTBOX FILL  WHITE / HALF / BLACK / OFF
--      Controls the engine's own battle-box paper at draw time. Because the
--      fill, border and ink stay in the same 160x144 UI canvas, BATTLE SIZE
--      FIXED and FILL transform them together and the corners stay aligned.

-- Each is a ModSetting: it gets an OPTIONS-menu row and a mod-manager schema
-- for free, and persists under options.modOptions.BATTLE_ART_VOXEL_FORK like the
-- others. Defining them here -- rather than inline in main.lua -- keeps the
-- three of them, and the render-path queries they answer, in one place.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local ModSetting = V.require("ModSetting")

local UiBackplates = {}

-- ------- C) SPRITE LIGHT -------

UiBackplates.spriteLight = ModSetting.new("spriteLight", "SPRITE LIGHT",
  { "SHADED", "UNLIT" }, { "SHADED", "UNLIT" })

-- Whether the mon cards should be drawn flat and full bright (UNLIT) rather
-- than receiving the world's day tint and shadows (SHADED). ARENA FILL: WHITE
-- forces this on: a solid white battle field carries no night tint -- as in
-- the traditional games -- so the sprites draw flat and true-colour
-- regardless of the SPRITE LIGHT setting.
function UiBackplates.spritesUnlit()
  if UiBackplates.arenaWhite() then return true end
  return UiBackplates.spriteLight:get() == "UNLIT"
end

-- ------- B) ARENA FILL -------

UiBackplates.arenaFill = ModSetting.new("arenaFill", "ARENA FILL",
  { "OFF", "WHITE" }, { "OFF", "WHITE" })

-- Whether to draw the solid white layer over the voxel world. Decoupled from
-- sprite light: it works with SHADED cards too (they just read a little
-- dimmer on white), so WHITE is offered independently of UNLIT.
function UiBackplates.arenaWhite()
  return UiBackplates.arenaFill:get() == "WHITE"
end

-- ------- A) TEXTBOX FILL -------

UiBackplates.textboxFill = ModSetting.new("textboxFill", "TEXTBOX FILL",
  { "WHITE", "HALF", "BLACK", "OFF" },
  { "WHITE", "HALF", "BLACK", "OFF" })

-- ARENA FILL: WHITE keeps the latest-build presentation: black ink on opaque
-- paper. On the 3D arena, the player's explicit textbox choice owns the box.
function UiBackplates.textboxMode()
  if UiBackplates.arenaWhite() then return "WHITE" end
  return UiBackplates.textboxFill:get()
end

function UiBackplates.textboxFillStyle()
  local mode = UiBackplates.textboxMode()
  if mode == "WHITE" then return { 1, 1, 1, 1 } end
  if mode == "HALF" then return { 0, 0, 0, 0.5 } end
  if mode == "BLACK" then return { 0, 0, 0, 1 } end
  return nil
end

function UiBackplates.textboxUsesWhiteInk()
  return UiBackplates.textboxMode() ~= "WHITE"
end

return UiBackplates
