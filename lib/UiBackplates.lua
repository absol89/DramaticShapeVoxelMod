-- The three battle-UI backplate options added for the 1.66 update:
--
--   C) SPRITE LIGHT  UNLIT / SHADED   -- whether the mon cards receive the
--      world's day tint and cast shadows (SHADED) or draw flat and full
--      bright (UNLIT). UNLIT keeps them readable on the white arena fill (B);
--      SHADED is the default OG look and is also supported on white.
--
--   B) ARENA FILL    OFF / WHITE / GEN6 / PNG / BLUE -- either the voxel
--      arena, a flat Battle Art plate, or the Stadium importer's own stage.
--      BOSS BG is an independent override within illustrated collections.
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
  if UiBackplates.arenaWhite() or UiBackplates.arenaArt() then return true end
  return UiBackplates.spriteLight:get() == "UNLIT"
end

-- Visibility is independent of the saved textbox fill and HUD palette.
UiBackplates.battleUi = ModSetting.new("battleUi", "BATTLE ART UI",
  { "BOTH", "TEXTBOX", "HUD", "HIDE" },
  { "BOTH", "TEXTBOX", "HUD", "HIDE" })

function UiBackplates.uiHidden(surface)
  local mode = UiBackplates.battleUi:get()
  if surface == "hud" then return mode == "TEXTBOX" or mode == "HIDE" end
  if surface == "text" then return mode == "HUD" or mode == "HIDE" end
  if surface == "panels" then return mode == "HUD" or mode == "HIDE" end
  return false
end

-- ------- HUD COLOR -------

-- COLOR keeps the engine's black HUD glyphs and green/yellow/red HP bars,
-- adding a bright one-pixel shadow so they remain legible over terrain.
-- INVERTED is the established fork presentation: white ink with a dark
-- shadow. COLOR comes first because it is the fresh-install default used by
-- the other forks. A white arena must use black ink regardless of the saved
-- choice or the HUD would disappear into its background.
UiBackplates.hudColor = ModSetting.new("hudColor", "HUD COLOR",
  { "COLOR", "INVERTED" }, { "COLOR", "INVERTED" })

function UiBackplates.hudUsesColor()
  return UiBackplates.arenaWhite()
         or UiBackplates.hudColor:get() == "COLOR"
end

function UiBackplates.hudUsesColorShadow()
  return not UiBackplates.arenaWhite()
         and UiBackplates.hudColor:get() == "COLOR"
end

-- ------- B) ARENA FILL -------

UiBackplates.arenaFill = ModSetting.new("arenaFill", "ARENA FILL",
  { "OFF", "WHITE", "GEN6", "PNG", "BLUE" },
  { "OFF", "WHITE", "GEN6", "PNG", "BLUE" })

-- Stadium's platform is independent of the selected arena fill. The row is
-- exposed only when a scene provider advertises it (see main.lua), so this
-- saved preference is inert without the Stadium importer.
UiBackplates.stadiumCircle = ModSetting.new("stadiumCircle", "STADIUM CIRCLE",
  { "ON", "OFF", "HALF" }, { "ON", "OFF", "HALF" })

function UiBackplates.stadiumCircleScale()
  local value = UiBackplates.stadiumCircle:get()
  if value == "OFF" then return 0 end
  if value == "HALF" then return 2 / 3 end
  return 1
end

-- How far down the authored plate to begin its top crop. The values are in
-- source-image pixels (the bundled plates are 800px tall), so the same choice
-- identifies the same part of the art on a phone, tablet or desktop window.
-- Voxel3D clamps it whenever an aspect ratio leaves less crop available.
-- Range spans 0..400 (step 20). 100 is the fresh-install default, keeping
-- useful floor detail in wide windows without retaining confusing negative
-- crops in either options UI.
local offsetValues, offsetLabels = {}, {}
for px = 0, 400, 20 do
  offsetValues[#offsetValues + 1] = px
  offsetLabels[#offsetLabels + 1] = px .. " PX"
end
UiBackplates.backdropOffset = ModSetting.new(
  "backdropOffset", "BG Y-OFFSET", offsetValues, offsetLabels, 6)

function UiBackplates.backdropOffsetPixels()
  return tonumber(UiBackplates.backdropOffset:get()) or 100
end

-- Whether to draw the solid white layer over the voxel world. Decoupled from
-- sprite light: it works with SHADED cards too (they just read a little
-- dimmer on white), so WHITE is offered independently of UNLIT.
function UiBackplates.arenaWhite()
  return UiBackplates.arenaFill:get() == "WHITE"
end

function UiBackplates.arenaGen6()
  return UiBackplates.arenaFill:get() == "GEN6"
end

function UiBackplates.arenaPng()
  return UiBackplates.arenaFill:get() == "PNG"
end

function UiBackplates.arenaBlue()
  return UiBackplates.arenaFill:get() == "BLUE"
end

-- Every illustrated collection is a flat plate.  Keeping this generic makes
-- the independent boss layer work when GEN4/OPENART are added later without
-- teaching the camera and lighting code every collection name.
function UiBackplates.arenaArt()
  local value = UiBackplates.arenaFill:get()
  return value ~= "OFF" and value ~= "WHITE" and value ~= "BLUE"
end

UiBackplates.bossBg = ModSetting.new("bossBg", "BOSS BG",
  { "ON", "OFF" }, { "ON", "OFF" })

function UiBackplates.bossEnabled()
  return UiBackplates.bossBg:get() == "ON"
end

function UiBackplates.arenaFlat()
  return UiBackplates.arenaWhite() or UiBackplates.arenaArt()
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
  if mode == "HALF" then return { 0, 0, 0, 0.30 } end
  if mode == "BLACK" then return { 0, 0, 0, 1 } end
  return nil
end

function UiBackplates.textboxUsesWhiteInk()
  return UiBackplates.textboxMode() ~= "WHITE"
end

return UiBackplates
