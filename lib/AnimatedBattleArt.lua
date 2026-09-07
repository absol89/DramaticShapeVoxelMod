-- Runtime playback for authoring-time GIF conversions.
--
-- LÖVE does not decode animated GIFs. The importer flattens each GIF into a
-- PNG atlas and one generated data table per set records the logical cell and
-- timing data. This module extracts exact ImageData rectangles: no Canvas DPI
-- participates, so one source pixel remains one logical battle-art pixel.
local V = ...

local BattleArt = V.require("BattleArt")
local SETS = {
  gen2 = V.data("animated_battle_sprites_gen2"),
  gen3 = V.data("animated_battle_sprites_gen3"),
  gen4 = V.data("animated_battle_sprites_gen4"),
  gen5 = V.data("animated_battle_sprites_gen5"),
}
local BACK_SETS = {
  gen3 = V.data("animated_battle_backs_gen3"),
  gen5 = SETS.gen5,
}
local SHINY_SETS = {
  gen2 = V.data("animated_battle_sprites_gen2_shiny"),
  gen3 = V.data("animated_battle_sprites_gen3_shiny"),
  gen4 = V.data("animated_battle_sprites_gen4_shiny"),
  gen5 = V.data("animated_battle_sprites_gen5_shiny"),
}
-- Gen 1 fronts are ordinary single-frame PNGs. Later generations retain the
-- atlas decoder and timing metadata they have always used.
local FRONT_SOURCE_KIND = {
  gen1 = "static",
  gen2 = "animated",
  gen3 = "animated",
  gen4 = "animated",
  gen5 = "animated",
}
-- Gen 1 SGB, Gen 2 Crystal, and Gen 4 backs are intentionally single-frame
-- collections even while BATTLE ART is ANIMATED. An explicit source table
-- prevents a static generation folder from being decoded as an atlas.
local BACK_SOURCE_KIND = {
  gen1 = "static",
  gen2 = "static",
  gen3 = "animated",
  gen4 = "static",
  gen5 = "animated",
}
local PLAYER_SETS = V.data("animated_player_trainers")
local AnimatedBattleArt = {}

local loaded, loadOrder = {}, {}
local interfaceLoaded = setmetatable({}, { __mode = "k" })
local LOAD_LIMIT = 6
local states = setmetatable({}, { __mode = "k" }) -- battler -> playback
local trainerStates = setmetatable({}, { __mode = "k" }) -- battle -> playback

local function currentImage(state)
  if not state then return nil end
  return state.frames and state.frames[state.frame] or state.image
end

local function forgetFromOrder(def)
  for i = #loadOrder, 1, -1 do
    if loadOrder[i] == def then table.remove(loadOrder, i) end
  end
end

local function remember(def, mode, frames)
  forgetFromOrder(def)
  loaded[def] = { mode = mode, frames = frames }
  loadOrder[#loadOrder + 1] = def
  if #loadOrder > LOAD_LIMIT then
    local old = table.remove(loadOrder, 1)
    loaded[old] = nil
  end
end

local function atlasPath(def)
  local path = def and def.image and V.mod.assets:path(def.image)
  return path
end

local function decodeFrames(def, mode, source)
  local result
  local ok = pcall(function()
    local sheet
    if source then
      if type(source) == "string" then
        sheet = love.image.newImageData(source)
      elseif type(source.newImageData) == "function" then
        sheet = source:newImageData()
      else
        return
      end
    else
      local path = atlasPath(def)
      if not path then return end
      sheet = love.image.newImageData(path)
    end
    if not sheet then return end
    local sheetW, sheetH = sheet:getDimensions()
    local frames = {}
    local cells = def.cells
    local autoColumns = tonumber(def.autoColumns)
    local count = cells and #cells or autoColumns or assert(tonumber(def.frames))
    if count < 1 then return end
    -- Tightened Gen 4 sheets and the original sheets may coexist during copying.
    -- Select only an exact sheet layout, never slice an old atlas with tight cells.
    local layout = def
    if def.legacyLayout and not cells and not autoColumns then
      local columns = assert(tonumber(def.columns))
      local rows = math.ceil(count / columns)
      local function matches(candidate)
        return sheetW == candidate.width * columns
          and sheetH == candidate.height * rows
      end
      if not matches(def) then
        if not matches(def.legacyLayout) then return end
        layout = def.legacyLayout
      end
    end
    local autoWidth
    if autoColumns then
      if autoColumns % 1 ~= 0 or sheetW % autoColumns ~= 0 then return end
      autoWidth = sheetW / autoColumns
    end
    for index = 0, count - 1 do
      local x, y, width, height
      if cells then
        local c = cells[index + 1]
        x, y = tonumber(c.x) or 0, tonumber(c.y) or 0
        width, height = assert(tonumber(c.width)), assert(tonumber(c.height))
      elseif autoColumns then
        x, y = index * autoWidth, 0
        width, height = autoWidth, sheetH
      else
        width = assert(tonumber(layout.width))
        height = assert(tonumber(layout.height))
        local columns = assert(tonumber(def.columns))
        x = (index % columns) * width
        y = math.floor(index / columns) * height
      end
      if width < 1 or height < 1 or x < 0 or y < 0
         or x + width > sheetW or y + height > sheetH then return end
      local cell = love.image.newImageData(width, height)
      cell:paste(sheet, 0, 0, x, y, width, height)
      local image = BattleArt.prepareData(cell, mode)
      if not image then return end
      frames[#frames + 1] = image
    end
    if #frames == count then
      if def.stableAnchor then
        BattleArt.shareFrameAnchor(frames, #frames)
      end
      result = frames
    end
  end)
  return ok and result or nil
end

local function loadFrames(def, mode)
  local hit = loaded[def]
  if hit and hit.mode == mode then return hit.frames end
  local result = decodeFrames(def, mode)
  if not result then return nil end
  remember(def, mode, result)
  return result
end

-- A clean redistributable build does not contain the owner's private sprite
-- PNGs, but another sprite provider may still return the matching atlas from
-- pokemon.sprite. Decode that received Image as a fallback, while the normal
-- bounds checks above reject an ordinary ROM sprite whose dimensions do not
-- match this generation's metadata.
local function loadInterfaceFrames(def, mode, source)
  local frames = loadFrames(def, mode)
  if frames or not source then return frames end
  local cached = interfaceLoaded[source]
  if cached and cached.def == def and cached.mode == mode then
    return cached.frames
  end
  frames = decodeFrames(def, mode, source)
  if frames then
    interfaceLoaded[source] = { def = def, mode = mode, frames = frames }
  end
  return frames
end

local function restoreTrainer(battle)
  local state = battle and trainerStates[battle]
  if not state then return end
  if battle.playerBackPic == currentImage(state) then
    battle.playerBackPic = state.original
  end
  trainerStates[battle] = nil
end

local function updateStaticPlayerTrainer(battle, mode)
  local image = BattleArt.namedImage("player", "back")
  local state = trainerStates[battle]
  if state and (state.kind ~= "static" or state.mode ~= mode
                or state.image ~= image) then
    restoreTrainer(battle)
    state = nil
  end
  if not image or not battle.playerBackPic then
    restoreTrainer(battle)
    return
  end
  if not state then
    state = { kind = "static", mode = mode, original = battle.playerBackPic,
              image = image }
    trainerStates[battle] = state
  elseif battle.playerBackPic ~= state.image
     and battle.playerBackPic ~= state.original then
    trainerStates[battle] = nil
    return
  end
  battle.playerBackPic = state.image
end

-- Five authored poses are tied to SlideTrainerPicOffScreen rather than to a
-- free-running clock. Frame one waits with the stationary intro portrait;
-- frames two through five divide the 72-pixel leftward walk, then clamp.
local function updatePlayerTrainer(battle, mode)
  if not (battle and battle.showPlayerBack and not battle.demo) then
    restoreTrainer(battle)
    return
  end
  local selected = BattleArt.effectivePlayerAnimationSet
    and BattleArt.effectivePlayerAnimationSet()
    or BattleArt.playerAnimationSetting:get()
  if selected == "png" then
    updateStaticPlayerTrainer(battle, mode)
    return
  end
  local def = selected ~= "rom" and PLAYER_SETS[selected] or nil
  if not def or not battle.playerBackPic then
    restoreTrainer(battle)
    return
  end
  local state = trainerStates[battle]
  if state and (state.def ~= def or state.mode ~= mode) then
    restoreTrainer(battle)
    state = nil
  end
  if not state then
    local frames = loadFrames(def, mode)
    if not frames then return end
    state = { kind = "animated", def = def, mode = mode,
              original = battle.playerBackPic,
              frames = frames, frame = 1 }
    trainerStates[battle] = state
  elseif battle.playerBackPic ~= state.frames[state.frame]
     and battle.playerBackPic ~= state.original then
    trainerStates[battle] = nil
    return
  end

  local offset = 0
  if type(battle.picOffset) == "function" then
    local ok, got = pcall(battle.picOffset, battle, "back")
    if ok then offset = tonumber(got) or 0 end
  end
  local progress = math.max(0, math.min(72, -offset))
  if progress <= 0 then
    state.frame = 1
  else
    local movingFrames = math.max(1, #state.frames - 1)
    state.frame = math.min(#state.frames,
      2 + math.floor(math.max(0, progress - 1) * movingFrames / 72))
  end
  battle.playerBackPic = state.frames[state.frame]
end

local function restore(battler)
  local state = battler and states[battler]
  if not state then return end
  if battler.sprite == currentImage(state) then
    battler.sprite = state.original
  end
  states[battler] = nil
end

local function definition(battler, side)
  -- MODDED owns presentation, not Pokemon art: capture the image selected by
  -- the provider chain (or ROM) without installing any Battle Art frame.
  if not BattleArt.ownsSpeciesArt() then return nil end
  local species = BattleArt.speciesFor(battler)
  local key = species and tostring(BattleArt.speciesAlias(species)):upper()
  local setting = side == "back" and BattleArt.backAnimationSetting
                                  or BattleArt.frontAnimationSetting
  local generation = setting:get()
  local collections = side == "back" and BACK_SETS or SETS
  local selected = collections[generation]
  local detectedShiny = BattleArt.isShiny(battler)
  local shiny = detectedShiny and BattleArt.ownsShinyArt()
  -- Shiny front AND back atlases have independent geometry and timing. Never
  -- rewrite only the normal definition's filename: e.g. Gen 5 Krabby changes
  -- from a 55x43 / 73-frame normal back to a 56x56 / 18-frame shiny back.
  if shiny and SHINY_SETS[generation] then
    selected = SHINY_SETS[generation]
  end
  local bySide = selected and key and selected[key]
  return bySide and bySide[side] or nil
end
AnimatedBattleArt.definitionFor = definition

-- Prepared frames for non-battle interfaces. Mon-aware screens pass the caught
-- Pokemon so shiny DVs select the shiny atlas; species-only screens omit it and
-- retain the regular collection. The title and summary screens accept Image
-- objects but not atlas descriptors, so their adapters consume this narrow
-- decoder instead of returning the whole sheet through pokemon.sprite's
-- string-path contract.
function AnimatedBattleArt.interfaceFront(species, generation, mode, source, battler)
  if not tostring(generation or ""):match("^gen[1-5]$") then return nil end
  local key = species and tostring(BattleArt.speciesAlias(species)):upper()
  local selected = SETS[generation]
  if BattleArt.isShiny(battler) and BattleArt.ownsShinyArt()
      and SHINY_SETS[generation] then
    selected = SHINY_SETS[generation]
  end
  local bySide = selected and key and selected[key]
  local def = bySide and bySide.front or nil
  if FRONT_SOURCE_KIND[generation] == "static"
      or (generation == "gen2" and not def) then
    local image = BattleArt.interfaceGenerationFrontImage(
      species, generation, mode, battler)
    return image and { image } or nil, nil
  end
  if not def then return nil end
  return loadInterfaceFrames(def, mode, source), def.durations
end

local function updateBattler(battler, side, dt, mode)
  if not battler then return end
  local def = definition(battler, side)
  if not (def and battler.sprite) then restore(battler); return end

  local state = states[battler]
  if state and (state.kind ~= "animated" or state.def ~= def
                or state.mode ~= mode or state.side ~= side) then
    restore(battler)
    state = nil
  end
  if not state then
    local frames = loadFrames(def, mode)
    if not frames then return end -- missing/malformed atlas: retain ROM art
    state = { kind = "animated", side = side, def = def, mode = mode,
              original = battler.sprite,
              frames = frames, frame = 1, elapsed = 0 }
    states[battler] = state
  elseif battler.sprite ~= state.frames[state.frame]
     and battler.sprite ~= state.original then
    -- Transform or another battle effect owns the sprite now.
    states[battler] = nil
    return
  end

  state.elapsed = state.elapsed + (tonumber(dt) or 0)
  local durations = def.durations or {}
  local duration = math.max(1, tonumber(durations[state.frame]) or 100) / 1000
  while state.elapsed >= duration do
    state.elapsed = state.elapsed - duration
    state.frame = state.frame % #state.frames + 1
    duration = math.max(1, tonumber(durations[state.frame]) or 100) / 1000
  end
  battler.sprite = state.frames[state.frame]
end

local function updateStaticBack(battler, generation, mode)
  if not (battler and battler.sprite) then return end
  local species = BattleArt.speciesFor(battler)
  local image = species
                and BattleArt.generationBackImage(species, generation, battler)
  local state = states[battler]
  if state and (state.kind ~= "static" or state.generation ~= generation
                or state.mode ~= mode or state.image ~= image) then
    restore(battler)
    state = nil
  end
  if not image then restore(battler); return end
  if not state then
    state = { kind = "static", side = "back", generation = generation,
              mode = mode, original = battler.sprite, image = image }
    states[battler] = state
  elseif battler.sprite ~= state.image and battler.sprite ~= state.original then
    -- A transform or battle effect owns the sprite for this frame.
    states[battler] = nil
    return
  end
  battler.sprite = state.image
end

local function updateStaticFront(battler, generation, mode)
  if not (battler and battler.sprite) then return end
  local species = BattleArt.speciesFor(battler)
  local image = species
                and BattleArt.generationFrontImage(species, generation, battler)
  local state = states[battler]
  if state and (state.kind ~= "static" or state.side ~= "front"
                or state.generation ~= generation or state.mode ~= mode
                or state.image ~= image) then
    restore(battler)
    state = nil
  end
  if not image then restore(battler); return end
  if not state then
    state = { kind = "static", side = "front", generation = generation,
              mode = mode, original = battler.sprite, image = image }
    states[battler] = state
  elseif battler.sprite ~= state.image and battler.sprite ~= state.original then
    -- A transform or battle effect owns the sprite for this frame.
    states[battler] = nil
    return
  end
  battler.sprite = state.image
end

local function updateFront(battler, generation, dt, mode)
  -- GEN 2 is normally atlas-driven, but later species can be supplied as
  -- ordinary PNGs when no animation metadata exists for them.
  if FRONT_SOURCE_KIND[generation] == "static"
      or (generation == "gen2" and not definition(battler, "front")) then
    updateStaticFront(battler, generation, mode)
  else
    updateBattler(battler, "front", dt, mode)
  end
end

function AnimatedBattleArt.update(battle, dt)
  if not battle then return end
  if BattleArt.setting:get() ~= "animated" then
    AnimatedBattleArt.finish(battle)
    return
  end
  local mode = BattleArt.displayMode()
  BattleArt.releaseSpeciesOverrides(battle)
  -- Restore a static PLAYER ART replacement before the animation manager
  -- captures the engine portrait, then leave managed animation frames alone.
  BattleArt.applyTrainers(battle)
  updatePlayerTrainer(battle, mode)
  local frontGeneration = BattleArt.frontAnimationSetting:get()
  updateFront(battle.enemy, frontGeneration, dt, mode)
  local playerSide = BattleArt.playerSide()
  if playerSide == "back" then
    local generation = BattleArt.backAnimationSetting:get()
    if BACK_SOURCE_KIND[generation] == "animated" then
      updateBattler(battle.player, "back", dt, mode)
    else
      updateStaticBack(battle.player, generation, mode)
    end
  else
    updateFront(battle.player, frontGeneration, dt, mode)
  end
end

-- The staged renderer asks this before deciding whether to suppress the
-- engine's original player pics layer. A managed back image belongs in the
-- world; no managed image means the selected file/atlas was absent or bad,
-- so the untouched ROM backsprite remains attached to the UI.
function AnimatedBattleArt.hasWorldBack(battler)
  local state = battler and states[battler]
  return state and state.side == "back"
         and battler.sprite == currentImage(state) or false
end

-- UI scaling needs to distinguish any supplied native-resolution player image
-- (the static PNG or an animated atlas frame) from the ROM's deliberately
-- half-resolution back picture. Both occupy the same engine field, but only
-- the ROM image should receive the Game Boy 2x scale.
function AnimatedBattleArt.hasPlayerTrainerFrame(battle)
  local state = battle and trainerStates[battle]
  return state and battle.playerBackPic == currentImage(state) or false
end

function AnimatedBattleArt.finish(battle)
  if not battle then return end
  restoreTrainer(battle)
  restore(battle.enemy)
  restore(battle.player)
end

-- Transform has already put the target's ROM picture on the battler. Drop the
-- old Ditto playback state without restore(); the next update may claim the
-- copied species' atlas, or deliberately leave that transformed ROM fallback.
function AnimatedBattleArt.abandonForTransform(battler)
  if not battler then return false end
  states[battler] = nil
  return true
end

function AnimatedBattleArt.invalidate()
  loaded, loadOrder = {}, {}
  trainerStates = setmetatable({}, { __mode = "k" })
end

return AnimatedBattleArt
