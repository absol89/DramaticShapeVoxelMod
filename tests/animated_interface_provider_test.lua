local checks = 0
local function ok(value, message)
  checks = checks + 1
  if not value then error("FAIL " .. message, 0) end
end

local sets, shinySets = {}, {}
for n = 2, 5 do
  local generation = "gen" .. n
  local def = {
    image = "assets/private/" .. generation .. "/squirtle.png",
    width = 2, height = 2, columns = 2, frames = 2,
    durations = { 100, 200 },
  }
  sets[generation] = { SQUIRTLE = { front = def } }
  local shinyDef = {
    image = "assets/private/" .. generation .. "/shiny/squirtle.png",
    width = 2, height = 2, columns = 2, frames = 2,
    durations = { 300, 400 },
  }
  shinySets[generation] = { SQUIRTLE = { front = shinyDef } }
end
local gen1Image = { id = "gen1-static-front" }
local BattleArt = {
  speciesAlias = function(species) return species end,
  isShiny = function(battler) return battler and battler.shiny == true end,
  ownsShinyArt = function() return true end,
  prepareData = function(cell)
    return { width=cell.width, height=cell.height, paste=cell.lastPaste }
  end,
  shareFrameAnchor = function() end,
  interfaceGenerationFrontImage = function(_, generation)
    return generation == "gen1" and gen1Image or nil
  end,
}
local V = {
  mod = { assets = { path = function() return "missing-private.png" end } },
}
function V.require(name) assert(name == "BattleArt"); return BattleArt end
function V.data(name)
  local shinyGeneration = name:match(
    "^animated_battle_sprites_(gen[2-5])_shiny$")
  if shinyGeneration then return shinySets[shinyGeneration] end
  local generation = name:match("^animated_battle_sprites_(gen[2-5])$")
  if generation then return sets[generation] end
  return {}
end

local function data(width, height)
  local out = { width=width, height=height }
  function out:getDimensions() return self.width, self.height end
  function out:paste(_, dx, dy, sx, sy, w, h)
    self.lastPaste = { dx=dx, dy=dy, sx=sx, sy=sy, width=w, height=h }
  end
  return out
end

love = { image = {} }
function love.image.newImageData(a, b)
  if type(a) == "number" then return data(a, b) end
  if a == "provider-atlas.png" then return data(4, 2) end
  if a == "tight-atlas.png" then return data(2, 1) end
  if a == "wrong-atlas.png" then return data(6, 2) end
  if a == "rom-front.png" then return data(2, 2) end
  error("missing image")
end

local Animated = assert(loadfile("lib/AnimatedBattleArt.lua"))(V)
local gen1 = Animated.interfaceFront("SQUIRTLE", "gen1", "gbc")
ok(gen1 and gen1[1] == gen1Image,
  "Gen 1 interface fronts use their single prepared image")

local frames, durations = Animated.interfaceFront(
  "SQUIRTLE", "gen2", "gbc", "provider-atlas.png")
ok(frames and #frames == 2, "external provider atlas is decoded")
ok(frames[1].width == 2 and frames[1].height == 2,
  "provider frames retain metadata dimensions")
ok(frames[1].paste.sx == 0 and frames[2].paste.sx == 2,
  "provider atlas cells use the metadata coordinates")
ok(durations[1] == 100 and durations[2] == 200,
  "provider playback retains metadata timing")

for n = 3, 5 do
  local generation = "gen" .. n
  local generationFrames = Animated.interfaceFront(
    "SQUIRTLE", generation, "gbc", "provider-atlas.png")
  ok(generationFrames and #generationFrames == 2,
    generation .. " interface fronts decode through the shared atlas path")
end

local rejected = Animated.interfaceFront(
  "SQUIRTLE", "gen2", "gbc", "rom-front.png")
ok(rejected == nil, "ordinary ROM image is rejected as a two-frame atlas")

local shinyFrames, shinyDurations = Animated.interfaceFront(
  "SQUIRTLE", "gen2", "gbc", "provider-atlas.png", {shiny=true})
ok(shinyFrames and #shinyFrames == 2,
  "mon-aware interface playback selects the shiny atlas definition")
ok(shinyDurations[1] == 300 and shinyDurations[2] == 400,
  "shiny interface playback retains the shiny atlas timing")

-- Both layouts must work while users replace asset folders incrementally.
for _, shiny in ipairs({false, true}) do
  local def = (shiny and shinySets or sets).gen4.SQUIRTLE.front
  def.width, def.height = 1, 1
  def.legacyLayout = {width=2, height=2}
  for _, path in ipairs({"tight-atlas.png", "provider-atlas.png"}) do
    local images, timing = Animated.interfaceFront(
      "SQUIRTLE", "gen4", "gbc", path, {shiny=shiny})
    local size = path == "tight-atlas.png" and 1 or 2
    ok(images and #images == 2, "tight and legacy sheets both decode")
    ok(images[1].width == size and images[2].paste.sx == size,
      "actual sheet dimensions select the correct frame boundaries")
    ok(timing[2] == (shiny and 400 or 200), "layout selection preserves timing")
  end
  ok(Animated.interfaceFront("SQUIRTLE", "gen4", "gbc",
    "wrong-atlas.png", {shiny=shiny}) == nil, "unknown layouts are rejected")
end

print(("%d checks passed (external interface atlas decoder)"):format(checks))
