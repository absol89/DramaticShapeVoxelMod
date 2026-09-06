local checks = 0
local function ok(value, message)
  checks = checks + 1
  if not value then error("FAIL " .. message, 0) end
end

local wrapped
local setting = { value = "battle_art" }
function setting:get() return self.value end
local ModSetting = { new = function() return setting end }

local artMode, generation = "animated", "gen2"
local function image(id, w, h, opaqueAt)
  local out = { id=id, w=w or 56, h=h or 56 }
  function out:getDimensions() return self.w, self.h end
  function out:getWidth() return self.w end
  function out:getHeight() return self.h end
  function out:newImageData()
    local data = {}
    function data:getDimensions() return out.w, out.h end
    function data:getPixel(x, y)
      local opaque = opaqueAt == nil or opaqueAt(x, y)
      return 1, 1, 1, opaque and 1 or 0
    end
    return data
  end
  return out
end
local frame1 = image("frame1")
local frame2 = image("frame2")
local footFrame1 = image("foot1")
local footFrame2 = image("foot2")
local staticImage = { id="static" }
local cropped = setmetatable({}, { __mode="k" })
local summaryFrame1 = image("summary-frame1")
local summaryFrame2 = image("summary-frame2")
local fittedArgs
local BattleArt = {
  setting = { get = function() return artMode end },
  frontAnimationSetting = { get = function() return generation end },
  displayMode = function() return "gbc" end,
  staticSpeciesRelativePath = function(_, _, shiny)
    return "assets/battle/front-static/" .. (shiny and "shiny/" or "")
      .. "pikachu.png"
  end,
  generationRelativePath = function()
    return "assets/battle/front-animated/gen1/pikachu.png"
  end,
  interfaceStaticFrontImage = function() return staticImage end,
  isShiny = function(battler) return battler and battler.shiny == true end,
  metrics = function(img)
    if img == footFrame1 or img == footFrame2 then
      return { y1=49, padBottom=6 }
    end
  end,
  cropPreparedBottom = function(img, rows)
    if rows <= 0 then return img end
    if cropped[img] then return cropped[img] end
    local out = image(img.id .. "-cropped", img.w, img.h - rows)
    cropped[img] = out
    return out
  end,
  fitPreparedFrames = function(frames, w, h)
    fittedArgs = { frames=frames, w=w, h=h }
    return { summaryFrame1, summaryFrame2 }
  end,
}
local lastInterfaceSource, lastInterfaceBattler
local AnimatedBattleArt = {
  interfaceFront = function(species, selected, _, source, battler)
    lastInterfaceSource = source
    lastInterfaceBattler = battler
    if species == "LUGIA" and selected == "gen2" then
      return { frame1, frame2 }, { 100, 100 }
    elseif species == "FOOTMON" and selected == "gen2" then
      return { footFrame1, footFrame2 }, { 100, 100 }
    end
  end,
}

local summaryCalls, summarySprite
local SummaryMenu = {}
function SummaryMenu.new(_, mon)
  return { mon=mon, page=2, sprite={id="rom-summary"}, spriteTrueColor=false }
end
function SummaryMenu.update() end
function SummaryMenu.draw(self, marker)
  if marker == "kept" then summaryCalls = (summaryCalls or 0) + 1 end
  summarySprite = self and self.sprite
end
package.loaded["src.ui.SummaryMenu"] = SummaryMenu

local TitleState = {}
function TitleState.currentSprite() return {id="rom-title"}, false end
function TitleState.update() end
function TitleState.draw(self) TitleState.currentSprite(self) end
package.loaded["src.ui.TitleState"] = TitleState

local dexSprite
local DexEntryMenu = {}
function DexEntryMenu.new(_, species)
  return { def={id=species}, sprite={id="rom-dex"}, spriteTrueColor=false }
end
function DexEntryMenu.update() end
function DexEntryMenu.draw(self) dexSprite = self.sprite end
package.loaded["src.ui.DexEntryMenu"] = DexEntryMenu

local legacyTrainerData
package.loaded["src.render.Assets"] = {
  imageData = function(path)
    if path == "assets/generated/title/player.png" then
      return legacyTrainerData
    end
  end,
}

local trueColorMarks = {}
package.loaded["src.render.PaletteFX"] = {
  markTrueColor = function(x, y, w, h)
    trueColorMarks[#trueColorMarks + 1] = { x=x, y=y, w=w, h=h }
  end,
}

local drawn = {}
love = love or {}
love.graphics = love.graphics or {}
love.filesystem = love.filesystem or {}
love.filesystem.getInfo = function() return true end
love.graphics.draw = function(image, ...)
  drawn[#drawn + 1] = { image=image, args={...} }
end

local missingAsset
local V = { mod = {
  hooks = { wrap = function(_, name, fn)
    if name == "pokemon.sprite" then wrapped = fn end
  end },
  assets = { path = function(_, rel)
    if missingAsset then return nil end
    return "mod/" .. rel
  end },
} }
function V.require(name)
  return assert(({ ModSetting=ModSetting, BattleArt=BattleArt,
    AnimatedBattleArt=AnimatedBattleArt })[name], name)
end

local InterfaceSprites = assert(loadfile("lib/InterfaceSprites.lua"))(V)
local installed, err = pcall(InterfaceSprites.install)
ok(installed, "install does not call an undefined helper: " .. tostring(err))
ok(type(wrapped) == "function", "pokemon.sprite wrapper is installed")
ok(wrapped(function(path) return path end, "rom.png", nil) == "rom.png",
  "nil sprite context fails open")

local titleCtx = {kind="title",species="LUGIA",trueColor=false}
ok(wrapped(function(path) return path end, "rom-title.png", titleCtx)
    == "rom-title.png", "title hook never returns the complete atlas path")
local dexCtx = {kind="dex",species="LUGIA",trueColor=false}
ok(wrapped(function(path) return path end, "rom-dex.png", dexCtx)
    == "rom-dex.png", "unadapted animated interface retains safe ROM art")

-- Red is opaque at only his top-left pixel in this synthetic mask. The title
-- adapter must restore the Pokemon immediately beside/behind that pixel but
-- never replay the trainer pixel itself.
local trainer = image("red", 40, 56,
  function(x, y) return x == 0 and y == 0 end)
local title = {cycleSpecies={"LUGIA"},cycleIndex=1,player=trainer}
local image, trueColor = TitleState.currentSprite(title)
ok(image == frame1 and not trueColor,
  "title defers true-color replay for its prepared atlas frame")
ok(lastInterfaceSource == "rom-title.png",
  "title decoder receives the provider path from the sprite hook")
TitleState.update(title, 0.11)
image, trueColor = TitleState.currentSprite(title)
ok(image == frame2 and not trueColor, "title advances with atlas timing")
TitleState.draw(title)
local function marked(px, py)
  for _, r in ipairs(trueColorMarks) do
    if px >= r.x and px < r.x + r.w and py >= r.y and py < r.y + r.h then
      return true
    end
  end
  return false
end
ok(not marked(82, 80),
  "alpha-aware title replay never repaints an opaque trainer pixel")
ok(marked(83, 80),
  "alpha-aware title replay restores Pokemon pixels behind transparent trainer space")

-- Legacy 0.1.83 moves the title mon in pixels with monOffset (newer engines
-- use slideIn in tiles). True-color marks must move with the drawn frame.
trueColorMarks = {}
title.monOffset = 8
TitleState.draw(title)
ok(not marked(40, 80) and marked(48, 80),
  "legacy monOffset moves the title true-color replay with the Pokemon")

-- Legacy Red is reconstructed from atlas quads. Source (0,0) is opaque, but
-- this quad places it at screen (90,80), not the flat-atlas origin (82,80).
trueColorMarks = {}
title.monOffset = 0
local quad = { getViewport = function() return 0, 0, 8, 8 end }
title.playerQuads = { { quad, 8, 0 } }
TitleState.draw(title)
ok(marked(82, 80) and not marked(90, 80),
  "legacy trainer quads mask their composed pixels instead of flat atlas bounds")
title.playerQuads = nil

-- On 0.1.83 Image:newImageData is unavailable. The adapter must read the
-- trainer source through Assets.imageData instead of excluding its rectangle.
trueColorMarks = {}
legacyTrainerData = trainer:newImageData()
local legacyTrainer = { getDimensions = function() return 40, 56 end }
title.player = legacyTrainer
TitleState.draw(title)
ok(not marked(82, 80) and marked(83, 80),
  "legacy source ImageData preserves transparent trainer holes")
title.player = trainer

local footTitle = {cycleSpecies={"FOOTMON"},cycleIndex=1,player=trainer}
local footImage = TitleState.currentSprite(footTitle)
ok(footImage:getHeight() == 56,
  "title retains the generation sprite's native dimensions")
drawn = {}
TitleState.draw(footTitle)
local footDraw
for _, call in ipairs(drawn) do
  if call.image == footFrame1 then footDraw = call end
end
ok(footDraw and footDraw.args[2] == 86,
  "neutral opaque foot aligns to Red's y=135 foot row")

-- Pokédex entry pages own an Image, not an atlas path. They need the same
-- prepared-frame playback adapter as title and summary.
wrapped(function() return "provider-dex.png" end, "rom-dex.png",
  {kind="dex", species="LUGIA"})
local dex = DexEntryMenu.new({}, "LUGIA")
DexEntryMenu.draw(dex)
ok(dexSprite == frame1 and dex.spriteTrueColor,
  "Pokédex uses the selected prepared generation frame")
ok(lastInterfaceSource == "provider-dex.png",
  "Pokédex decoder receives the provider atlas path")
DexEntryMenu.update(dex, 0.11)
DexEntryMenu.draw(dex)
ok(dexSprite == frame2, "Pokédex animation advances with atlas timing")

local summaryMon = {species="LUGIA", shiny=true}
wrapped(function() return "provider-summary.png" end, "rom-summary.png",
  {kind="summary", species="LUGIA", mon=summaryMon})
local summary = SummaryMenu.new({}, summaryMon)
SummaryMenu.draw(summary, "kept")
ok(summarySprite == summaryFrame1 and summary.spriteTrueColor,
  "summary uses a fitted prepared true-color frame")
ok(fittedArgs and fittedArgs.frames[1] == frame1
    and fittedArgs.w == 56 and fittedArgs.h == 56,
  "summary fits the animation into its canonical 56x56 viewport")
ok(lastInterfaceSource == "provider-summary.png",
  "summary decoder receives the provider path from the sprite hook")
ok(lastInterfaceBattler == summaryMon,
  "summary decoder receives the caught Pokemon for shiny routing")
SummaryMenu.update(summary, 0.11)
SummaryMenu.draw(summary)
ok(summarySprite == summaryFrame2, "fitted summary animation advances")

setting.value, artMode = "off", "animated"
SummaryMenu.draw(summary)
ok(summarySprite.id == "rom-summary" and not summary.spriteTrueColor,
  "disabling interface art restores the original summary sprite")

setting.value, artMode, generation = "battle_art", "static", "gen2"
local staticCtx = {kind="hof",species="PIKACHU",trueColor=false}
local path = wrapped(function(old) return old end, "rom-static.png", staticCtx)
ok(path == "mod/assets/battle/front-static/pikachu.png"
  and staticCtx.trueColor, "static interface paths opt out of SGB recoloring")

local shinyStaticCtx = {
  kind="summary", species="PIKACHU", mon={shiny=true}, trueColor=false,
}
-- A summary normally uses its Image adapter; calling the path resolver here
-- verifies that any other mon-aware static interface uses the same shiny rule.
shinyStaticCtx.kind = "hof"
local shinyPath = wrapped(function(old) return old end,
  "rom-shiny-static.png", shinyStaticCtx)
ok(shinyPath == "mod/assets/battle/front-static/shiny/pikachu.png",
  "mon-aware static interfaces route shiny Pokemon through the shiny folder")

local battleMenuCtx = {
  kind="battle", side="front", species="PIKACHU", trueColor=false,
}
local battleMenuPath = wrapped(function() return "provider-front.png" end,
  "rom-front.png", battleMenuCtx)
ok(battleMenuPath == "mod/assets/battle/front-static/pikachu.png"
  and battleMenuCtx.trueColor,
  "battle-kind menu fronts use Battle Art's static front")
ok(wrapped(function() return "provider-back.png" end, "rom-back.png",
  {kind="battle",side="back",species="PIKACHU"}) == "provider-back.png",
  "battle backs remain owned by the battle pipeline")
missingAsset = true
ok(wrapped(function() return "provider-missing.png" end, "rom-front.png",
  {kind="battle",side="front",species="PIKACHU"}) == "provider-missing.png",
  "a missing Battle Art menu front preserves the provider result")
missingAsset = false
artMode = "rom"
ok(wrapped(function() return "provider-rom.png" end, "rom-front.png",
  {kind="battle",side="front",species="PIKACHU"}) == "provider-rom.png",
  "ROM mode preserves the provider result for battle-kind menus")

print(("%d checks passed (Interface Sprites install/playback)"):format(checks))
