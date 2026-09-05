-- Optional, user-supplied battle art. Nothing in these folders is used by
-- the Pokedex, party menu or status screen.
local V = ...

local ModSetting = V.require("ModSetting")
local BattleArt = {}
local SPECIES_BY_DEX = V.data("battle_species_dex_386")

BattleArt.setting = ModSetting.new("battleArt", "BATTLE ART",
  { "static", "animated", "rom" }, { "STATIC", "ANIMATED", "ROM" }, 2)
BattleArt.frontAnimationSetting = ModSetting.new("frontAnimatedSet", "ANIM FRONT GEN",
  { "gen1", "gen2", "gen3", "gen4", "gen5" },
  { "GEN 1", "GEN 2", "GEN 3", "GEN 4", "GEN 5" }, 5)
-- The selected generation names the static back folder in STATIC mode. In
-- ANIMATED mode uses atlases for Gen 3 and Gen 5; Gen 1, 2 and 4 use their
-- single images. The mode, not just the generation, decides the decoder.
BattleArt.backAnimationSetting = ModSetting.new("backAnimatedSet", "BACK ART SET",
  { "gen1", "gen2", "gen3", "gen4", "gen5" },
  { "GEN 1", "GEN 2", "GEN 3", "GEN 4", "GEN 5" }, 5)
BattleArt.viewSetting = ModSetting.new("playerView", "PLAYER",
  { "front", "back" }, { "FRONT SPRITES", "BACK SPRITES" }, 2)
BattleArt.backPlacementSetting = ModSetting.new(
  "backPlacement", "BACK PLACEMENT",
  { "auto", "world", "ui" }, { "AUTO", "WORLD", "OG UI" })
BattleArt.trainerSetting = ModSetting.new(
  "trainerArtSet", "TRAINER ART",
  { "gen1", "gen2", "gen3" }, { "GEN 1", "GEN 2", "GEN 3" })
BattleArt.playerArtSetting = ModSetting.new(
  "playerArtSet", "PLAYER ART",
  { "png", "gen1", "gen2", "gen3", "gen4", "gen5", "ash", "gary", "boy", "lass", "hilbert", "rom" },
  { "PNG", "GEN 1", "GEN 2", "GEN 3", "GEN 4", "GEN 5", "ASH", "GARY", "BOY", "LASS", "HILBERT", "ROM" })
BattleArt.playerAnimationSetting = ModSetting.new(
  "playerAnimatedSet", "PLAYER ANIM",
  { "png", "gen1", "gen2", "gen3", "gen4", "gen5", "ash", "gary", "red",
    "ash_front", "misty_front", "brock_front", "bulma_front", "gary_front", "rom" },
  { "PNG", "GEN 1", "GEN 2", "GEN 3", "GEN 4", "GEN 5", "ASH", "GARY", "RED/GREEN",
    "ASH FRONT", "MISTY FRONT", "BROCK FRONT", "BULMA FRONT", "GARY FRONT", "ROM" }, 2)
-- One owner for species pictures. BATTLE ART keeps this mod's selected front
-- and back collections in charge, including its imported shiny children.
-- MODDED leaves every Pokemon picture to the underlying sprite provider (or
-- the ROM), whether the Pokemon is ordinary or shiny. Battle Art still stages
-- and captures that provider's result; it does not install a species image.
-- Trainers are people rather than battlers, so this never affects trainer art.
BattleArt.duplicateSetting = ModSetting.new(
  "duplicateFix", "DUPLICATE FIX",
  { "battle_art", "modded" }, { "BATTLE ART", "MODDED" })

-- Player-side front pictures need one presentation decision after their
-- source has been chosen. Battle Art's ordinary fronts face the same way as
-- the opponent and are mirrored in world space so the pair face each other.
-- Some sprite mods instead publish an already-oriented player picture (for
-- example Crystal Animated Sprites' flipped backsprite). DEFAULT preserves
-- that authored orientation instead of mirroring it a second time.
BattleArt.frontFlipSetting = ModSetting.new(
  "frontFlip", "FLIP FRONT SPRITE",
  { "battle_art", "default" }, { "BATTLE ART", "DEFAULT" })

function BattleArt.prefersModded()
  return BattleArt.duplicateSetting:get() == "modded"
end

function BattleArt.ownsSpeciesArt()
  return not BattleArt.prefersModded()
end

function BattleArt.ownsShinyArt()
  return BattleArt.ownsSpeciesArt()
end

-- Gen 1 already stores the four DVs Gen 2 uses for shininess. Own that
-- stable data contract here instead of asking whichever sprite mod happens
-- to be installed: every shiny encounter mod ultimately has to produce the
-- same DV pattern, while cross-mod image identity APIs are neither universal
-- nor available under every sandbox/IO policy.
local SHINY_ATTACK = {
  [2] = true, [3] = true, [6] = true, [7] = true,
  [10] = true, [11] = true, [14] = true, [15] = true,
}

function BattleArt.isShiny(battler)
  local mon = battler and (battler.mon or battler)
  local dvs = mon and mon.dvs
  if type(dvs) ~= "table" then return false end
  local attack = tonumber(dvs.attack)
  local defense = tonumber(dvs.defense)
  local speed = tonumber(dvs.speed)
  local special = tonumber(dvs.special)
  if defense ~= 10 or speed ~= 10 or special ~= 10
     or not SHINY_ATTACK[attack] then
    return false
  end

  -- HP DV is derived from the low bit of the other four DVs. Gen 1 normally
  -- stores only those four, but honour an explicit HP DV supplied by a mod
  -- only when it agrees with the canonical derivation (0 or 8 for a shiny).
  local hp = (attack % 2) * 8 + (defense % 2) * 4
             + (speed % 2) * 2 + (special % 2)
  return dvs.hp == nil or tonumber(dvs.hp) == hp
end

function BattleArt.flipsPlayerFront()
  return BattleArt.frontFlipSetting:get() == "battle_art"
end

-- Upgrade the two settings used through 1.7.8 without keeping two dead rows
-- in the new schema. If the old front/back choices disagreed, MODDED wins: it
-- is the only migration that does not silently take a user's modded art away.
function BattleArt.migrateDuplicateSetting(game)
  game = game or require("src.core.Game")
  local loader = game and game.mods
  local buckets = loader and loader.modOptions
  local bucket = buckets and buckets[(V.mod and V.mod.id)
                                     or "BATTLE_ART_VOXEL_FORK"]
  if type(bucket) ~= "table" then return false end
  if bucket.duplicateFix ~= nil then
    BattleArt.duplicateSetting:sync(bucket.duplicateFix)
    return false
  end
  if bucket.frontShiny == nil and bucket.backShiny == nil then return false end
  local value = (bucket.frontShiny == "on" or bucket.backShiny == "on")
                and "modded" or "battle_art"
  local index = value == "modded" and 2 or 1
  BattleArt.duplicateSetting:setIndex(index, game)
  return true
end

-- BATTLE ART: ROM owns the normal player portrait as completely as it owns
-- species art. Keep the visible PLAYER ART row honest instead of leaving a
-- stale named PNG selected while the renderer silently ignores it.
function BattleArt.forceRomPlayer(game)
  if BattleArt.setting:get() ~= "rom"
     or BattleArt.playerArtSetting:get() == "rom" then return false end
  for i, value in ipairs(BattleArt.playerArtSetting.values) do
    if value == "rom" then
      BattleArt.playerArtSetting:setIndex(i, game)
      return true
    end
  end
  return false
end

local cache = {}
local external = setmetatable({}, { __mode = "k" })
local metrics = setmetatable({}, { __mode = "k" })
-- LOVE 0.1.83 Images cannot be read back with Image:newImageData(). Retain the
-- already-prepared pixels weakly so title alpha compositing can inspect them
-- without a GPU readback or a second atlas decode.
local preparedData = setmetatable({}, { __mode = "k" })
local bottomCrops = setmetatable({}, { __mode = "k" })
local fittedFrameSets = setmetatable({}, { __mode = "k" })
local original = setmetatable({}, { __mode = "k" })
local trainerOriginal = setmetatable({}, { __mode = "k" })

local function speciesAlias(species)
  local number
  if type(species) == "number" then
    number = species
  elseif type(species) == "string" then
    -- Accept common mod-facing numeric spellings without confusing named
    -- forms (DEOXYS_D etc.) with Pokédex identifiers.
    number = tonumber(species:match("^#?0*(%d+)$"))
  end
  if number and number % 1 == 0 then
    return SPECIES_BY_DEX[number] or species
  end
  return species
end
BattleArt.speciesAlias = speciesAlias

local function slug(species)
  species = speciesAlias(species)
  local s = tostring(species or ""):lower()
  s = s:gsub("♀", "-f"):gsub("♂", "-m")
  s = s:gsub("['’%.]", "")
  s = s:gsub("[^%w]+", "-"):gsub("^-+", ""):gsub("-+$", "")
  return s
end
BattleArt.slug = slug

function BattleArt.playerSide()
  return BattleArt.viewSetting:get() == "back" and "back" or "front"
end

local function shinyPrefix(side, shiny)
  -- species-only. Players can never be shiny, so this never consults player
  -- art; `side` remains part of the call contract for the folder resolvers.
  -- BATTLE ART routes confirmed shinies to its flat override folder. MODDED
  -- never reaches this helper for a shiny through the public image resolver.
  return BattleArt.ownsShinyArt() and shiny and "shiny/" or ""
end

-- Transform does not rewrite mon.species. Our engine hook records the copied
-- shape independently, so species routing never needs another mod's marker.
function BattleArt.speciesFor(battler)
  local species = battler and (battler.__battleArtTransformed
                               or (battler.mon and battler.mon.species)) or nil
  return speciesAlias(species)
end

-- Generation collections keep their shiny overrides inside the selected
-- generation (`gen3/shiny`), not in a parallel `shiny/gen3` tree. Flat
-- front-static species art remains the deliberate exception because it has
-- no generation selector of its own.
local function generationFolder(generation, side, shiny)
  if BattleArt.ownsShinyArt() and shiny then
    return generation .. "/shiny"
  end
  return generation
end

local function generationRelativePath(species, generation, side, shiny)
  if not tostring(generation or ""):match("^gen[1-5]$") then return nil end
  local kind = side == "back" and "back-static" or "front-animated"
  return ("assets/battle/%s/%s/%s.png"):format(
    kind, generationFolder(generation, side, shiny), slug(species))
end
BattleArt.generationRelativePath = generationRelativePath

local function staticSpeciesRelativePath(species, side, shiny)
  if side == "back" then
    return generationRelativePath(
      species, BattleArt.backAnimationSetting:get(), "back", shiny)
  end
  -- Static fronts are deliberately bring-your-own and generation-neutral.
  -- Their only optional child is the flat shiny override folder.
  return ("assets/battle/front-static/%s%s.png"):format(
    shinyPrefix("front", shiny), slug(species))
end
BattleArt.staticSpeciesRelativePath = staticSpeciesRelativePath

-- Called only after the engine has installed the copied ROM picture. Forget
-- our old ownership without restoring Ditto over that picture: if the selected
-- collection lacks the copied species, the engine's transformed art must stay.
function BattleArt.markTransformed(battler, species)
  if not (battler and species) then return false end
  original[battler] = nil
  battler.__battleArtTransformed = speciesAlias(species)
  return true
end

local function pathFor(species, side, shiny)
  local mode = BattleArt.setting:get()
  if mode == "rom" then return nil end
  -- Animated atlases need frame rectangles/timing, not just an image path.
  -- Keep the folder and setting stable while that decoder is added; an
  -- unrecognised atlas must never appear as one giant sprite sheet.
  if mode == "animated" then return nil end
  -- STATIC never consults an atlas. In particular, a Gen 5 back means the
  -- ordinary PNG at back-static/gen5; only AnimatedBattleArt decodes atlases.
  local rel = staticSpeciesRelativePath(species, side, shiny)
  local path = V.mod.assets:path(rel)
  return path, rel
end

local function staticPathFor(name, side)
  if BattleArt.setting:get() == "rom" then return nil end
  return V.mod.assets:path(
    ("assets/battle/%s-static/%s.png"):format(side, name))
end

local function rgbaKey(data, w, h)
  local corners = { {0, 0}, {w - 1, 0}, {0, h - 1}, {w - 1, h - 1} }
  local counts, values, order = {}, {}, {}
  for _, p in ipairs(corners) do
    local r, g, b = data:getPixel(p[1], p[2])
    local key = (math.floor(r * 255 + .5) * 65536)
              + (math.floor(g * 255 + .5) * 256)
              + math.floor(b * 255 + .5)
    counts[key] = (counts[key] or 0) + 1
    values[key] = { r, g, b }
    if counts[key] == 1 then order[#order + 1] = key end
  end
  local best, n = order[1], -1
  for _, k in ipairs(order) do
    local count = counts[k]
    if count > n then best, n = k, count end
  end
  return values[best]
end

local function displayMode()
  local ok, fx = pcall(require, "src.render.PaletteFX")
  return ok and fx and fx.mode or "gbc"
end
BattleArt.displayMode = displayMode

local function applyDisplayFilter(data, mode)
  if mode == "gbc_inv" then
    data:mapPixel(function(_, _, r, g, b, a)
      if a <= 0 then return r, g, b, a end
      return 1 - r, 1 - g, 1 - b, a
    end)
    return
  end
  if mode ~= "og" and mode ~= "og_inv" and mode ~= "classic" then return end
  local PaletteFX = require("src.render.PaletteFX")
  local colors = PaletteFX.effectiveColors(PaletteFX.GRAYS)
  data:mapPixel(function(_, _, r, g, b, a)
    if a <= 0 then return r, g, b, a end
    local luma = r * 0.2126 + g * 0.7152 + b * 0.0722
    local i = luma > 0.83 and 1 or luma > 0.5 and 2
              or luma > 0.17 and 3 or 4
    local c = colors[i]
    return c[1] / 255, c[2] / 255, c[3] / 255, a
  end)
end

-- Turn one logical sprite image into battle-ready art. Animated atlases use
-- this same path after extracting a cell, so static and animated art receive
-- identical transparency keying, display-palette filtering and anchoring.
function BattleArt.prepareData(data, mode)
  local made
  local ok = pcall(function()
    local w, h = data:getDimensions()
    if w < 1 or h < 1 then return end

    local opaque = true
    for y = 0, h - 1 do
      for x = 0, w - 1 do
        local _, _, _, a = data:getPixel(x, y)
        if a < 0.999 then opaque = false break end
      end
      if not opaque then break end
    end

    -- Fully opaque art commonly carries a flat matte. Infer it from the
    -- corners and remove only matching pixels connected to the border, so a
    -- matching eye/highlight enclosed by the silhouette is preserved.
    if opaque then
      local key = rgbaKey(data, w, h)
      local seen, stack, top = {}, {}, 0
      local function push(x, y)
        if x < 0 or y < 0 or x >= w or y >= h then return end
        local i = y * w + x
        if seen[i] then return end
        local r, g, b = data:getPixel(x, y)
        if math.abs(r - key[1]) > 0.5 / 255
           or math.abs(g - key[2]) > 0.5 / 255
           or math.abs(b - key[3]) > 0.5 / 255 then return end
        seen[i], top = true, top + 1
        stack[top] = i
      end
      for x = 0, w - 1 do push(x, 0); push(x, h - 1) end
      for y = 0, h - 1 do push(0, y); push(w - 1, y) end
      while top > 0 do
        local i = stack[top]; stack[top], top = nil, top - 1
        local x, y = i % w, math.floor(i / w)
        local r, g, b = data:getPixel(x, y)
        data:setPixel(x, y, r, g, b, 0)
        push(x - 1, y); push(x + 1, y); push(x, y - 1); push(x, y + 1)
      end
    end

    applyDisplayFilter(data, mode)

    local x0, x1, y0, y1 = w, -1, h, -1
    for y = 0, h - 1 do
      for x = 0, w - 1 do
        local _, _, _, a = data:getPixel(x, y)
        if a > 0.001 then
          if x < x0 then x0 = x end; if x > x1 then x1 = x end
          if y < y0 then y0 = y end; if y > y1 then y1 = y end
        end
      end
    end
    if x1 < x0 then return end
    made = love.graphics.newImage(data)
    made:setFilter("nearest", "nearest")
    external[made] = true
    preparedData[made] = data
    metrics[made] = { x0 = x0, x1 = x1, y0 = y0, y1 = y1,
                      w = w, h = h, padBottom = h - 1 - y1,
                      center = (x0 + x1 + 1) / 2 }
  end)
  return (ok and made) or nil
end

local function prepare(path, mode)
  local cacheKey = path .. "#" .. mode
  local hit = cache[cacheKey]
  if hit ~= nil then return hit or nil end
  local made
  local ok = pcall(function()
    made = BattleArt.prepareData(love.image.newImageData(path), mode)
  end)
  cache[cacheKey] = (ok and made) or false
  return made
end

function BattleArt.image(species, side, battler)
  if not BattleArt.ownsSpeciesArt() then return nil end
  local shiny = BattleArt.isShiny(battler)
  local path = pathFor(species, side, shiny)
  local image = path and prepare(path, displayMode()) or nil
  -- Authored static species fronts preserve their illustration brightness in
  -- the battle scene. BattleScene reads this tag to omit only the clock tint;
  -- ordinary world lighting, shadows, depth and display filtering remain.
  if image and side == "front" and metrics[image] then
    metrics[image].staticFront = true
  end
  return image
end

-- Back-generation choices Gen 1-5 are ordinary, independently replaceable
-- PNGs. They use the same transparency keying, palette filtering and native
-- pixel metrics as BATTLE ART: STATIC, but live in generation subfolders so
-- switching the selector does not require renaming or replacing files.
function BattleArt.generationBackImage(species, generation, battler)
  if not BattleArt.ownsSpeciesArt() then return nil end
  local shiny = BattleArt.isShiny(battler)
  local rel = generationRelativePath(
    species, generation, "back", shiny)
  if not rel then return nil end
  local path = V.mod.assets:path(rel)
  return prepare(path, displayMode())
end

-- Gen 1 has no animated front atlas. ANIMATED mode still offers it as a
-- compatibility collection so SGB and ROM-hack fronts can coexist with the
-- independently animated player-trainer intro. Each species is one ordinary
-- image; no metadata or timing sidecar is involved.
function BattleArt.generationFrontImage(species, generation, battler)
  if not tostring(generation or ""):match("^gen[1-5]$") then return nil end
  -- Shiny-compatible: BATTLE ART selects the generation's shiny child folder
  -- (`front-animated/<gen>/shiny/<slug>.png`).
  -- MODDED leaves every species image to another sprite mod or the ROM.
  if not BattleArt.ownsSpeciesArt() then return nil end
  local shiny = BattleArt.isShiny(battler)
  local rel = generationRelativePath(
    species, generation, "front", shiny)
  local path = V.mod.assets:path(rel)
  return prepare(path, displayMode())
end

-- Non-battle interfaces have their own ownership setting. Mon-aware callers
-- (STATUS/summary, party, Hall of Fame) may supply the caught Pokemon so its
-- DVs select the same shiny child as battle. Species-only callers such as the
-- title and Pokedex omit it and deliberately retain the regular form.
function BattleArt.interfaceStaticFrontImage(species, mode, battler)
  local rel = staticSpeciesRelativePath(
    species, "front", BattleArt.isShiny(battler))
  local path = rel and V.mod.assets:path(rel)
  return path and prepare(path, mode or displayMode()) or nil
end

function BattleArt.interfaceGenerationFrontImage(species, generation, mode, battler)
  local rel = generationRelativePath(
    species, generation, "front", BattleArt.isShiny(battler))
  local path = rel and V.mod.assets:path(rel)
  return path and prepare(path, mode or displayMode()) or nil
end

function BattleArt.namedImage(name, side)
  local path = staticPathFor(name, side)
  return path and prepare(path, displayMode()) or nil
end

-- Opponent trainer pictures are always static, but can be switched as a
-- complete generation set without renaming files. Deliberately do not fall
-- through to another generation (or to the old flat folder): a missing class
-- is useful and predictable as a per-trainer ROM fallback.
local function currentGameSave()
  local ok, Game = pcall(require, "src.core.Game")
  if ok and type(Game) == "table" then
    return Game.save
  end
  return nil
end

local function chooseYourHeroBucket()
  local ok, other = pcall(function()
    return V.mod.find and V.mod.find("choose_your_hero")
  end)
  if ok and other and other.save and other.save.get then
    local readOK, bucket = pcall(function()
      return {
        player = other.save:get("player", "red"),
        rival = other.save:get("rival", "blue"),
      }
    end)
    if readOK then return bucket end
  end
  local save = currentGameSave()
  local md = save and save.modData
  if type(md) ~= "table" then return nil end
  local bucket = md.choose_your_hero
  if type(bucket) == "table" then return bucket end
  return nil
end

local function chooseYourHeroRival()
  local bucket = chooseYourHeroBucket()
  if type(bucket) == "table" and type(bucket.rival) == "string" then
    return bucket.rival
  end
  return "blue"
end

local function chooseYourHeroPlayer()
  local bucket = chooseYourHeroBucket()
  if type(bucket) == "table" and type(bucket.player) == "string" then
    return bucket.player
  end
  return "red"
end
BattleArt.chooseYourHeroPlayer = chooseYourHeroPlayer
BattleArt.chooseYourHeroRival = chooseYourHeroRival

function BattleArt.effectivePlayerAnimationSet()
  local selected = BattleArt.playerAnimationSetting:get()
  -- Old saves that still store GREEN are the combined RED/GREEN row.
  if selected == "green" then selected = "red" end
  if selected == "red" then
    return chooseYourHeroPlayer() == "green" and "green" or "red"
  end
  return selected
end

function BattleArt.effectivePlayerArtSet()
  return BattleArt.playerArtSetting:get()
end

local function yellowRivalFile(name)
  if type(name) ~= "string" then return nil end
  if name == "rival" then return "rival1f" end
  if name:match("^rival[123]$") then return name .. "f" end
  return nil
end

function BattleArt.trainerImage(name)
  if BattleArt.setting:get() == "rom" then return nil end
  local generation = BattleArt.trainerSetting:get()
  local function load(file)
    local rel = ("assets/battle/front-static/%s/%s.png"):format(
      generation, file)
    local path = V.mod.assets:path(rel)
    if not path then return nil end
    return prepare(path, displayMode())
  end
  -- The engine class slug is prof-oak; accept the authored engine-style
  -- filename first while retaining existing hyphenated collections.
  if name == "prof-oak" or name == "prof.oak" then
    return load("prof.oak") or load("prof-oak")
  end
  if chooseYourHeroRival() == "yellow" then
    local femName = yellowRivalFile(name)
    if femName then
      -- nil leaves the companion's engine-installed Yellow portrait intact.
      -- Falling back to the standard rival file would turn her back into Blue.
      return load(femName)
    end
  end
  return load(name)
end

-- The normal player trainer intro has its own collection, independent of
-- Pokemon BATTLE ART. This is why ROM is an explicit choice here: users can
-- keep custom species and opponent trainers while retaining the original
-- player portrait. Oak and Old Man remain separately named scripted roles.
function BattleArt.playerTrainerImage()
  local set = BattleArt.effectivePlayerArtSet()
  if set == "rom" then return nil end
  local function load(name)
    local rel = "assets/battle/back-static/" .. name
    local path = V.mod.assets:path(rel)
    return prepare(path, displayMode())
  end
  if set == "png" then return load("player.png") end
  if set == "green" then
    return load("greenplayer.png") or load("player.png")
  end
  -- A named collection may be incomplete without making every battle fall
  -- all the way back to ROM. player.png is the collection-independent BYO
  -- fallback; only its own absence reaches the engine portrait.
  return load(set .. "player.png") or load("player.png")
end

local function trainerKey(battle)
  local id = battle and battle.oppClass
  if type(id) ~= "string" then return nil end
  if id == "OPP_ROCKET" and (battle.dramaticShapeTrainerParty or 1) >= 42 then
    return "jessie-james"
  end
  return slug(id:gsub("^OPP_", ""))
end

local function replaceTrainerField(battle, field, img)
  local rec = trainerOriginal[battle]
  if not rec then rec = {}; trainerOriginal[battle] = rec end
  local saved = field .. "Saved"
  if img then
    if not rec[saved] then
      rec[field], rec[saved] = battle[field] or false, true
    end
    battle[field] = img
  elseif rec[saved] then
    battle[field] = rec[field] or nil
    rec[field], rec[saved] = nil, nil
  end
end

function BattleArt.applyTrainers(battle)
  if not battle then return end
  local enemy = battle.showEnemyTrainer and trainerKey(battle) or nil
  replaceTrainerField(battle, "trainerPic",
    enemy and BattleArt.trainerImage(enemy) or nil)

  local player, playerImage
  if battle.showPlayerBack then
    local artMode = BattleArt.setting:get()
    if artMode == "rom" then
      -- A stale PLAYER ART selection must never leak a custom trainer back
      -- into ROM mode. nil restores the engine-owned portrait.
      playerImage = nil
    elseif battle.demo then
      player = tostring(battle.demoName or ""):find("OAK", 1, true)
               and "oak" or "old-man"
      playerImage = BattleArt.namedImage(player, "back")
    elseif artMode == "animated" then
      -- AnimatedBattleArt owns this field in animated mode. Passing nil here
      -- first restores any static PLAYER ART image from a live mode switch;
      -- on subsequent frames it leaves the animation manager's image alone.
      playerImage = nil
    else
      playerImage = BattleArt.playerTrainerImage()
    end
  end
  replaceTrainerField(battle, "playerBackPic",
    playerImage)
end

function BattleArt.apply(battle)
  if not battle then return end
  local function releaseIfOwned(battler)
    local saved = original[battler]
    if not saved then return end
    -- Another sprite provider may have replaced our image after it was
    -- installed. Relinquish the stale cache without restoring the ROM over
    -- that provider; only the image we own authorizes a restore.
    if BattleArt.isExternal(battler.sprite) then
      battler.sprite = saved
    end
    original[battler] = nil
  end
  local function applyOne(battler, side)
    local species = BattleArt.speciesFor(battler)
    if not species then return end
    -- AnimatedBattleArt owns Pokemon sprites in this mode. Trainers still
    -- pass through applyTrainers below for opponent and scripted trainer art;
    -- AnimatedBattleArt separately owns the normal player's animated intro.
    if BattleArt.setting:get() == "animated" then
      releaseIfOwned(battler)
      return
    end
    local img = BattleArt.image(species, side, battler)
    if img then
      if not BattleArt.isExternal(battler.sprite) then
        original[battler] = battler.sprite
      end
      battler.sprite = img
    elseif original[battler] then
      releaseIfOwned(battler)
    end -- otherwise retain the ROM image
  end
  applyOne(battle.enemy, "front")
  applyOne(battle.player, BattleArt.playerSide())
  BattleArt.applyTrainers(battle)
end

-- AnimatedBattleArt must begin from the engine-owned pictures, not from a
-- static Battle Art image left by a live mode switch. Do this once before the
-- animation manager claims the battlers; BattleArt.apply() may then run during
-- texture capture without restoring the ROM sprite over the selected frame.
function BattleArt.releaseSpeciesOverrides(battle)
  if not battle then return end
  for _, battler in ipairs({ battle.enemy, battle.player }) do
    if battler and original[battler] then
      if BattleArt.isExternal(battler.sprite) then
        battler.sprite = original[battler]
      end
      original[battler] = nil
    end
  end
end

function BattleArt.isExternal(img) return external[img] and true or false end
function BattleArt.metrics(img) return metrics[img] end
function BattleArt.imageData(img) return img and preparedData[img] or nil end

-- Return a title-only copy with a known-transparent bottom strip removed.
-- TitleState bottom-aligns image dimensions, so shortening the canvas by N
-- lowers every remaining pixel by N without changing the art inside it. The
-- caller uses the minimum strip shared by every animation frame, preserving
-- all authored relative motion and guaranteeing that no opaque pixel is cut.
function BattleArt.cropPreparedBottom(img, rows)
  rows = math.floor(tonumber(rows) or 0)
  if not img or rows <= 0 then return img end
  local byRows = bottomCrops[img]
  if byRows and byRows[rows] then return byRows[rows] end
  local source, metric = preparedData[img], metrics[img]
  if not (source and metric) then return img end
  local w, h = source:getDimensions()
  rows = math.min(rows, h - 1, metric.padBottom or 0)
  if rows <= 0 then return img end
  local made
  local ok = pcall(function()
    local data = love.image.newImageData(w, h - rows)
    data:paste(source, 0, 0, 0, 0, w, h - rows)
    made = love.graphics.newImage(data)
    made:setFilter("nearest", "nearest")
    external[made], preparedData[made] = true, data
    metrics[made] = {
      x0 = metric.x0, x1 = metric.x1, y0 = metric.y0, y1 = metric.y1,
      w = w, h = h - rows,
      padBottom = math.max(0, (metric.padBottom or 0) - rows),
      center = metric.center,
    }
  end)
  if not (ok and made) then return img end
  byRows = byRows or setmetatable({}, { __mode = "v" })
  bottomCrops[img], byRows[rows] = byRows, made
  return made
end

-- SummaryMenu reserves exactly 56x56 pixels at (8,0), then starts the
-- Pokédex-number row at y=56. Generation atlases often use a larger logical
-- canvas even when their visible drawing would fit that box; the stock draw
-- code clamps such a canvas to y=0 and lets its lower rows cover the number.
-- Fit the union of the complete animation once, rather than centering each
-- frame independently. That keeps authored translations/swoops intact while
-- giving every frame the same centered, bottom-aligned 56x56 viewport.
function BattleArt.fitPreparedFrames(images, boxW, boxH)
  if type(images) ~= "table" or #images == 0 then return images end
  boxW, boxH = math.floor(tonumber(boxW) or 0), math.floor(tonumber(boxH) or 0)
  if boxW <= 0 or boxH <= 0 then return images end

  local cached = fittedFrameSets[images]
  local cacheKey = boxW .. "x" .. boxH
  if cached and cached[cacheKey] then return cached[cacheKey] end

  local x0, x1, y0, y1
  for _, image in ipairs(images) do
    local metric = metrics[image]
    if not (metric and preparedData[image]) then return images end
    x0 = x0 and math.min(x0, metric.x0) or metric.x0
    x1 = x1 and math.max(x1, metric.x1) or metric.x1
    y0 = y0 and math.min(y0, metric.y0) or metric.y0
    y1 = y1 and math.max(y1, metric.y1) or metric.y1
  end
  local unionW, unionH = x1 - x0 + 1, y1 - y0 + 1
  if unionW <= 0 or unionH <= 0 then return images end

  local scale = math.min(1, boxW / unionW, boxH / unionH)
  local drawW = math.max(1, math.min(boxW, math.floor(unionW * scale + 0.5)))
  local drawH = math.max(1, math.min(boxH, math.floor(unionH * scale + 0.5)))
  local destX, destY = math.floor((boxW - drawW) / 2), boxH - drawH
  local fitted, ok = {}, true
  for _, image in ipairs(images) do
    local source = preparedData[image]
    local made
    ok = pcall(function()
      local sourceW, sourceH = source:getDimensions()
      local data = love.image.newImageData(boxW, boxH)
      for dy = 0, drawH - 1 do
        local sy = y0 + math.min(unionH - 1,
          math.floor(dy * unionH / drawH))
        for dx = 0, drawW - 1 do
          local sx = x0 + math.min(unionW - 1,
            math.floor(dx * unionW / drawW))
          if sx >= 0 and sy >= 0 and sx < sourceW and sy < sourceH then
            data:setPixel(destX + dx, destY + dy, source:getPixel(sx, sy))
          end
        end
      end

      local fx0, fx1, fy0, fy1 = boxW, -1, boxH, -1
      for py = 0, boxH - 1 do
        for px = 0, boxW - 1 do
          local _, _, _, alpha = data:getPixel(px, py)
          if alpha > 0.001 then
            if px < fx0 then fx0 = px end; if px > fx1 then fx1 = px end
            if py < fy0 then fy0 = py end; if py > fy1 then fy1 = py end
          end
        end
      end
      if fx1 < fx0 then error("empty fitted frame") end
      made = love.graphics.newImage(data)
      made:setFilter("nearest", "nearest")
      external[made], preparedData[made] = true, data
      metrics[made] = {
        x0 = fx0, x1 = fx1, y0 = fy0, y1 = fy1,
        w = boxW, h = boxH, padBottom = boxH - 1 - fy1,
        center = (fx0 + fx1 + 1) / 2,
      }
    end)
    if not (ok and made) then return images end
    fitted[#fitted + 1] = made
  end

  cached = cached or setmetatable({}, { __mode = "v" })
  fittedFrameSets[images], cached[cacheKey] = cached, fitted
  return fitted
end
-- Animated transforms are authored inside a fixed logical canvas. Gen 3 back
-- APNGs in particular translate the same opaque drawing across that canvas;
-- recomputing the placement anchor from every frame's opaque bounds cancels
-- the motion. Copy only the neutral reference frame's placement coordinates
-- while retaining each frame's own bounds and pixels.
function BattleArt.shareFrameAnchor(images, referenceIndex)
  local reference = images and images[referenceIndex or #images]
  local anchor = reference and metrics[reference]
  if not anchor then return false end
  for _, image in ipairs(images) do
    local metric = metrics[image]
    if not metric or metric.w ~= anchor.w or metric.h ~= anchor.h then
      return false
    end
  end
  for _, image in ipairs(images) do
    local metric = metrics[image]
    metric.center = anchor.center
    metric.y1 = anchor.y1
    metric.padBottom = anchor.padBottom
  end
  return true
end
function BattleArt.isStaticFront(img)
  local m = img and metrics[img]
  return m and m.staticFront == true or false
end

function BattleArt.invalidate()
  cache = {}
  external = setmetatable({}, { __mode = "k" })
  metrics = setmetatable({}, { __mode = "k" })
  preparedData = setmetatable({}, { __mode = "k" })
  bottomCrops = setmetatable({}, { __mode = "k" })
  fittedFrameSets = setmetatable({}, { __mode = "k" })
  original = setmetatable({}, { __mode = "k" })
  trainerOriginal = setmetatable({}, { __mode = "k" })
end

return BattleArt
