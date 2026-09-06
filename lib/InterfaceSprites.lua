-- Interface sprites: show BATTLE ART's FRONT outside battles.
-- Title and Gen 1 summary have Image-frame adapters; other hook-aware callers
-- can consume ordinary single-image collections. Independently toggleable of
-- DUPLICATE FIX, which owns only battle pictures.
--
-- Implementation note -- this does NOT mutate the pokemon data table. The
-- engine resolves every pokemon picture through the `pokemon.sprite` hook,
-- passing a ctx that says what it is resolving (ctx.kind / ctx.side). We wrap
-- that single seam and, for interface (non-battle) contexts, answer with our
-- selected-generation front path. Because we read the option live on every
-- call, the toggle needs no restart and no data-record capture/restore.
--
-- Front-only by owner decision: the interfaces show our chosen front and
-- never a back. Battles keep their own (separate) logic in main.lua's
-- pokemon.sprite wrap (player back -> front substitution).

local V = ...

local ModSetting = V.require("ModSetting")
local BattleArt = V.require("BattleArt")
local AnimatedBattleArt = V.require("AnimatedBattleArt")

local InterfaceSprites = {}

-- OFF       : leave interface sprites to the engine / other mods (e.g. ROM).
-- BATTLE ART : install our selected-generation front in every interface.
-- MODDED    : identical to OFF here -- another sprite mod or the ROM owns it.
InterfaceSprites.setting = ModSetting.new("interfaceSprites",
  "INTERFACE SPRITES",
  { "off", "battle_art", "modded" },
  { "OFF", "BATTLE ART", "MODDED" }, 1)

local function active()
  return InterfaceSprites.setting:get() == "battle_art"
end

-- Build our front path for a species, or nil to fall back to the engine/ROM.
--
-- Rules (owner):
--  * mon-aware callers use the caught Pokemon's DVs to select a shiny child;
--    species-only callers (title/dex) retain the regular form.
--  * STATIC mode  -> front-static/<slug>.png (generation-neutral).
--  * ANIMATED mode -> title/summary consume prepared frames from the generation
--    atlas; path-only interfaces use Gen 1's single image or retain ROM art.
--  * ROM mode or a missing file -> nil, so the engine's own (ROM) art shows.
local function ourFront(ctx)
  if not active() then return nil end
  -- These screens are adapted at their Image-object seam below. Returning an
  -- animated PNG here would make their static loader draw the complete atlas.
  if ctx and (ctx.kind == "title" or ctx.kind == "summary"
              or ctx.kind == "dex") then return nil end
  -- The species can arrive in several shapes depending on caller (battle ctx,
  -- title ctx, dex ctx). Accept the common fields.
  local species = (ctx and (ctx.species
                  or (ctx.mon and ctx.mon.species)
                  or (ctx.data and ctx.data.species))) or nil
  if not species then return nil end
  local mode = BattleArt.setting:get()
  if mode == "rom" then return nil end
  local battler = ctx and ctx.mon or nil
  local shiny = BattleArt.isShiny(battler)
  local rel
  if mode == "static" then
    rel = BattleArt.staticSpeciesRelativePath(species, "front", shiny)
  else
    -- ANIMATED (or any other non-rom mode): generation atlas, regular form.
    local gen = BattleArt.frontAnimationSetting:get()
    -- pokemon.sprite returns a path, not an atlas frame. Gen 1 is a genuine
    -- single image; later generations need a screen adapter. Until a caller
    -- has one, retaining its ROM image is safer than drawing the whole sheet.
    if gen ~= "gen1" then return nil end
    rel = BattleArt.generationRelativePath(species, gen, "front", shiny)
  end
  if not rel then return nil end
  if ctx then ctx.trueColor = true end
  return V.mod.assets:path(rel)
end

local titleStates = setmetatable({}, { __mode = "k" })
local summaryStates = setmetatable({}, { __mode = "k" })
local dexStates = setmetatable({}, { __mode = "k" })
local summarySources = setmetatable({}, { __mode = "k" })
local titleSources = {}
local dexSources = {}

-- TitleState's stock true-color path replays rectangular pieces of the UI
-- canvas after the SGB palette pass.  It excludes Red's entire 40x56 bounds,
-- because replaying that rectangle would also repaint the trainer without his
-- title palette.  A Pokemon whose art extends behind Red therefore changes
-- palette at x=82 even where the trainer image is transparent -- Gastly's aura
-- makes the rectangular cut especially obvious.
--
-- Cache alpha masks and mark only runs where THIS Pokemon has a visible pixel
-- and the trainer does not.  The post-palette replay then restores every aura
-- pixel around Red while preserving each opaque trainer pixel above it.  This
-- is based on Image alpha, not generation dimensions, so the same adapter works
-- for Gen 1's static front and Gen 2-5 atlas frames of any authored canvas.
local alphaMasks = setmetatable({}, { __mode = "k" })

local function alphaMask(image, source)
  if not image then return nil end
  local cached = alphaMasks[image]
  if cached and cached ~= false then return cached end
  if cached == false and not source then return nil end
  local mask = nil
  local ok = pcall(function()
    local data = image.newImageData and image:newImageData() or nil
    if not data and BattleArt.imageData then
      data = BattleArt.imageData(image)
    end
    -- Image:newImageData is absent on the legacy 0.1.83/LÖVE surface. Read
    -- the same resolved source through Assets.imageData instead; unlike a
    -- fallback rectangle this preserves transparent holes between Red's
    -- limbs and therefore cannot recolor the Pokemon at the trainer boundary.
    if not data and source then
      local Assets = require("src.render.Assets")
      data = Assets.imageData and Assets.imageData(source) or nil
    end
    if not data then return end
    local w, h = data:getDimensions()
    local rows = {}
    for y = 0, h - 1 do
      local row = {}
      for x = 0, w - 1 do
        local _, _, _, a = data:getPixel(x, y)
        row[x] = a > 0.001
      end
      rows[y] = row
    end
    mask = { w = w, h = h, rows = rows }
  end)
  alphaMasks[image] = (ok and mask) or false
  return ok and mask or nil
end

local function markRectOutside(x, y, w, h, cover)
  local P = require("src.render.PaletteFX")
  if not cover then P.markTrueColor(x, y, w, h); return end
  local cx, cy, cw, ch = cover[1], cover[2], cover[3], cover[4]
  local right, bottom = x + w, y + h
  local ix1, iy1 = math.max(x, cx), math.max(y, cy)
  local ix2, iy2 = math.min(right, cx + cw), math.min(bottom, cy + ch)
  if ix1 >= ix2 or iy1 >= iy2 then
    P.markTrueColor(x, y, w, h)
    return
  end
  if y < iy1 then P.markTrueColor(x, y, w, iy1 - y) end
  if iy2 < bottom then P.markTrueColor(x, iy2, w, bottom - iy2) end
  if x < ix1 then P.markTrueColor(x, iy1, ix1 - x, iy2 - iy1) end
  if ix2 < right then P.markTrueColor(ix2, iy1, right - ix2, iy2 - iy1) end
end

-- Return whether a screen pixel is covered by an opaque trainer pixel. Legacy
-- 0.1.83 composes Red from three atlas quads and moves the ball quad
-- separately; treating the source atlas as one image leaves false rectangular
-- holes in the Pokemon's true-color replay. The second result says that the
-- point lies in drawn trainer bounds, so an unreadable alpha mask can still
-- fail safely without repainting Red.
local function trainerPixel(title, screenX, screenY)
  local player = title and title.player
  if not player then return false, false end
  local mask = alphaMask(player, title.__battleArtTrainerSource)
  local function sample(quad, dx, dy)
    local sx, sy, sw, sh = 0, 0, nil, nil
    if quad and quad.getViewport then
      local ok, a, b, c, d = pcall(quad.getViewport, quad)
      if not ok then return false, false end
      sx, sy, sw, sh = a, b, c, d
    elseif player.getDimensions then
      sw, sh = player:getDimensions()
    end
    if not (sw and sh) then return false, false end
    local px, py = screenX - dx, screenY - dy
    if px < 0 or py < 0 or px >= sw or py >= sh then return false, false end
    if not mask then return false, true end
    local mx, my = sx + px, sy + py
    return mask.rows[my] and mask.rows[my][mx] or false, true
  end

  if title.playerQuads then
    for _, part in ipairs(title.playerQuads) do
      local opaque, inside = sample(part[1], 82 + (part[2] or 0),
                                   80 + (part[3] or 0))
      if opaque then return true, true end
      if inside and not mask then return false, true end
    end
    if title.ballQuad and title.ballY then
      local opaque, inside = sample(title.ballQuad, 82, title.ballY)
      if opaque or (inside and not mask) then return opaque, inside end
    end
    return false, false
  end
  return sample(nil, 82, 80)
end

local function markTitleFrame(image, x, y, title)
  local mon = alphaMask(image)
  if not mon then
    local w, h = image:getDimensions()
    local player = title and title.player
    local pw, ph
    if player and player.getDimensions then pw, ph = player:getDimensions() end
    markRectOutside(x, y, w, h, player and { 82, 80, pw, ph } or nil)
    return
  end

  local P = require("src.render.PaletteFX")
  for sy = 0, mon.h - 1 do
    local row = mon.rows[sy]
    local start = nil
    for sx = 0, mon.w do
      local visible = sx < mon.w and row[sx]
      if visible then
        local opaque, uncertain = trainerPixel(title, x + sx, y + sy)
        if opaque or uncertain
            and not alphaMask(title and title.player,
                              title and title.__battleArtTrainerSource) then
          visible = false
        end
      end
      if visible and start == nil then
        start = sx
      elseif not visible and start ~= nil then
        P.markTrueColor(x + start, y + sy, sx - start, 1)
        start = nil
      end
    end
  end
end

local function redrawTitleTrainer(title)
  if not (title and title.player and love and love.graphics) then return end
  if title.playerQuads then
    for _, part in ipairs(title.playerQuads) do
      love.graphics.draw(title.player, part[1],
        82 + (part[2] or 0), 80 + (part[3] or 0))
    end
    if title.ballQuad and title.ballY then
      love.graphics.draw(title.player, title.ballQuad, 82, title.ballY)
    end
  else
    love.graphics.draw(title.player, 82, 80)
  end
end

local function selectedPlayback(owner, states, species, source, battler)
  if not (owner and species and active()) then
    if owner then states[owner] = nil end
    return nil
  end
  local artMode = BattleArt.setting:get()
  if artMode == "rom" then states[owner] = nil; return nil end
  local generation = artMode == "animated"
    and BattleArt.frontAnimationSetting:get() or "static"
  local display = BattleArt.displayMode()
  local shiny = BattleArt.isShiny(battler)
  local key = table.concat({ tostring(species), artMode, tostring(shiny),
                             tostring(generation), tostring(display),
                             tostring(source) }, "|")
  local state = states[owner]
  if state and state.key == key then return state end

  local frames, durations
  if artMode == "static" then
    local image = BattleArt.interfaceStaticFrontImage(species, display, battler)
    frames = image and { image } or nil
  else
    frames, durations = AnimatedBattleArt.interfaceFront(
      species, generation, display, source, battler)
  end
  if not (frames and frames[1]) then states[owner] = nil; return nil end
  -- Imported sets end on their neutral/rest pose. Title uses that single
  -- opaque foot row as its species anchor; every other frame keeps the same
  -- draw origin, preserving authored vertical movement (including entrances
  -- from below) instead of grounding each frame independently.
  local neutral = BattleArt.metrics and BattleArt.metrics(frames[#frames])
  state = { key = key, frames = frames, durations = durations or {},
            frame = 1, elapsed = 0,
            titleFootY = neutral and neutral.y1 or nil }
  states[owner] = state
  return state
end

local function advance(state, dt)
  if not (state and #state.frames > 1) then return end
  state.elapsed = state.elapsed + math.max(0, tonumber(dt) or 0)
  local duration = math.max(1,
    tonumber(state.durations[state.frame]) or 100) / 1000
  while state.elapsed >= duration do
    state.elapsed = state.elapsed - duration
    state.frame = state.frame % #state.frames + 1
    duration = math.max(1,
      tonumber(state.durations[state.frame]) or 100) / 1000
  end
end

local titleInstalled = false
function InterfaceSprites.installTitle()
  if titleInstalled then return end
  local ok, TitleState = pcall(require, "src.ui.TitleState")
  if not (ok and TitleState and TitleState.currentSprite and TitleState.update) then
    return
  end
  local originalCurrent, originalUpdate = TitleState.currentSprite, TitleState.update
  local originalDraw = TitleState.draw
  TitleState.currentSprite = function(self, ...)
    local originalImage, originalTrueColor = originalCurrent(self, ...)
    local species = self and self.cycleSpecies
      and self.cycleSpecies[self.cycleIndex]
    local state = selectedPlayback(self, titleStates, species,
      titleSources[species] or originalImage)
    if state then
      -- Suppress TitleState's rectangle-based true-color marker. draw() below
      -- installs the alpha-aware runs after the frame and trainer are composed.
      local frame = state.frames[state.frame]
      self.__battleArtTitleFrame = frame
      -- draw() takes over only this Pokemon draw so it can use the opaque
      -- neutral-frame baseline. Calling currentSprite outside draw remains a
      -- useful, backwards-compatible way to inspect the selected image.
      if self.__battleArtCustomTitleDraw then return nil, false end
      return self.__battleArtTitleFrame, false
    end
    if self then self.__battleArtTitleFrame = nil end
    return originalImage, originalTrueColor
  end
  TitleState.update = function(self, dt, ...)
    local result = originalUpdate(self, dt, ...)
    advance(titleStates[self], dt)
    return result
  end
  if type(originalDraw) == "function" then
    TitleState.draw = function(self, ...)
      -- Legacy TitleState omits currentSprite during the moving-ball phase.
      -- Clear the prior frame so that phase cannot leave stale replay marks.
      if self then self.__battleArtTitleFrame = nil end
      if self then
        local source = self.title and self.title.player
        if type(source) == "table" then source = source.path end
        self.__battleArtTrainerSource = source
          or "assets/generated/title/player.png"
        self.__battleArtCustomTitleDraw = true
      end
      local result = originalDraw(self, ...)
      if self then self.__battleArtCustomTitleDraw = nil end
      local drawnMonOffset = self and self.monOffset
      local frame = self and self.__battleArtTitleFrame
      if frame and not self.yellowLayout then
        local w, h = frame:getDimensions()
        -- 0.1.83 uses pixel-valued monOffset; current engines use a tile-valued
        -- slideIn. Match the exact branch the engine's TitleState.draw uses.
        local motion = drawnMonOffset
        if motion == nil then motion = self.monOffset end
        if motion == nil then motion = (self.slideIn or 0) * 8 end
        local x = 40 + math.floor((56 - w) / 2) + motion
        local state = titleStates[self]
        local metric = BattleArt.metrics and BattleArt.metrics(frame)
        local anchorY = state and state.titleFootY
          or metric and metric.y1 or (h - 1)
        -- Red's unshifted title sprite occupies y=80..135. Align the neutral
        -- Pokemon's lowest opaque row to that foot row without rescaling it.
        local y = 135 - anchorY
        love.graphics.draw(frame, x, y)
        -- The custom baseline draw happens after TitleState's stock pass;
        -- replay Red once so he remains in front exactly as the engine intends.
        redrawTitleTrainer(self)
        markTitleFrame(frame, x, y, self)
      end
      return result
    end
  end
  titleInstalled = true
end

-- Party, Pokédex and PC ask for kind="battle" fronts so they match combat.
-- Combat itself installs prepared Images in BattleArt.apply; those UIs only
-- consume a path. Serve the same front-static file (never an atlas sheet).
local function battleMenuFront(ctx)
  if not ctx or ctx.kind ~= "battle" then return nil end
  if ctx.side == "back" then return nil end
  if BattleArt.setting:get() == "rom" then return nil end
  local species = ctx.species
    or (ctx.mon and ctx.mon.species)
    or (ctx.data and ctx.data.species)
  if not species then return nil end
  local shiny = BattleArt.isShiny(ctx.mon)
  local function resolve(useShiny)
    local rel = BattleArt.staticSpeciesRelativePath(species, "front", useShiny)
    if not rel then return nil end
    local assetPath = V.mod.assets:path(rel)
    if not assetPath then return nil end
    if love and love.filesystem and love.filesystem.getInfo
        and not love.filesystem.getInfo(assetPath) then
      return nil
    end
    return assetPath
  end
  local assetPath = resolve(shiny) or (shiny and resolve(false)) or nil
  if not assetPath then return nil end
  ctx.trueColor = true
  return assetPath
end

-- Register the pokemon.sprite seam. Called from main.lua after the module is
-- required, so V.mod (and its hooks table) is fully populated.
function InterfaceSprites.install()
  -- The seam. next() first so any sprite-replacing mod loaded before us still
  -- gets the last word on WHICH art; we only change interface fronts.
  V.mod.hooks:wrap("pokemon.sprite", function(next, path, ctx)
    local out = next(path, ctx)
    -- Retain the provider's path before suppressing atlas paths at the static
    -- Image loader. Clean builds carry metadata but not private art, so the
    -- title/status adapters may need to decode the atlas another mod supplied.
    if ctx and type(out) == "string" then
      if ctx.kind == "summary" and ctx.mon then
        summarySources[ctx.mon] = out
      elseif ctx.kind == "title" and ctx.species then
        titleSources[ctx.species] = out
      elseif ctx.kind == "dex" and ctx.species then
        dexSources[ctx.species] = out
      end
    end
    -- Menu portraits that request the battle front (Modern Party / Dex / PC).
    -- Do not touch battle BACK slots; main.lua owns player back -> front.
    local menuFront = battleMenuFront(ctx)
    if menuFront then return menuFront end
    -- Remaining battle requests (backs, ROM mode, missing file) stay stock.
    if ctx and ctx.kind == "battle" then return out end
    -- Only a BACK slot must keep the engine's back sprite. Title and summary
    -- were already intercepted above because they need Image frames, not paths.
    if ctx and ctx.side == "back" then return out end
    -- Substitute a safe single-image front for other hook-aware interfaces.
    local front = ourFront(ctx)
    return front or out
  end)

  InterfaceSprites.installSummary()
  InterfaceSprites.installTitle()
  InterfaceSprites.installDex()
end

-- SummaryMenu already draws the canonical shaped HP gauge through
-- HudTiles.drawHPBar(data, 11, 3, mon, 1). Its fill begins at (104,24), uses
-- six partial/full 8x8 segment tiles, and ends with the type-1 cap. Do not
-- paint a rectangle over it; the engine also owns the correct health palette.

local summaryInstalled = false

function InterfaceSprites.installSummary()
  if summaryInstalled then return end
  local ok, SummaryMenu = pcall(require, "src.ui.SummaryMenu")
  if not (ok and SummaryMenu and SummaryMenu.draw) then return end
  local originalDraw = SummaryMenu.draw
  local originalNew, originalUpdate = SummaryMenu.new, SummaryMenu.update
  if type(originalNew) == "function" then
    SummaryMenu.new = function(...)
      local self = originalNew(...)
      if self then
        self.__battleArtOriginalSprite = self.sprite
        self.__battleArtOriginalTrueColor = self.spriteTrueColor
        self.__battleArtOriginalCaptured = true
        selectedPlayback(self, summaryStates,
          self.mon and self.mon.species,
          self.mon and summarySources[self.mon]
            or self.__battleArtOriginalSprite,
          self.mon)
      end
      return self
    end
  end
  if type(originalUpdate) == "function" then
    SummaryMenu.update = function(self, dt, ...)
      local result = originalUpdate(self, dt, ...)
      advance(summaryStates[self], dt)
      return result
    end
  end
  SummaryMenu.draw = function(self, ...)
    if self and not self.__battleArtOriginalCaptured then
      self.__battleArtOriginalSprite = self.sprite
      self.__battleArtOriginalTrueColor = self.spriteTrueColor
      self.__battleArtOriginalCaptured = true
    end
    local state = selectedPlayback(self, summaryStates,
      self and self.mon and self.mon.species,
      self and self.mon and summarySources[self.mon]
        or (self and self.__battleArtOriginalSprite),
      self and self.mon)
    if state then
      if not state.summaryFrames then
        state.summaryFrames = BattleArt.fitPreparedFrames
          and BattleArt.fitPreparedFrames(state.frames, 56, 56)
          or state.frames
      end
      self.sprite = state.summaryFrames[state.frame]
      self.spriteTrueColor = true
    elseif self and self.__battleArtOriginalCaptured then
      self.sprite = self.__battleArtOriginalSprite
      self.spriteTrueColor = self.__battleArtOriginalTrueColor
    end
    originalDraw(self, ...)
  end
  summaryInstalled = true
end

local dexInstalled = false

-- DexEntryMenu is another Image-object owner: returning a Gen 2-5 atlas path
-- through pokemon.sprite only makes its static loader draw the whole sheet (or
-- forces our safe ROM fallback). Adapt new/update/draw exactly like Summary so
-- the selected generation is decoded once and advances with authored timing.
function InterfaceSprites.installDex()
  if dexInstalled then return end
  local ok, DexEntryMenu = pcall(require, "src.ui.DexEntryMenu")
  if not (ok and DexEntryMenu and DexEntryMenu.new and DexEntryMenu.draw) then
    return
  end
  local originalNew, originalUpdate, originalDraw =
    DexEntryMenu.new, DexEntryMenu.update, DexEntryMenu.draw
  DexEntryMenu.new = function(...)
    local self = originalNew(...)
    if self then
      self.__battleArtOriginalSprite = self.sprite
      self.__battleArtOriginalTrueColor = self.spriteTrueColor
      self.__battleArtOriginalCaptured = true
      local species = self.def and self.def.id
      selectedPlayback(self, dexStates, species,
        dexSources[species] or self.__battleArtOriginalSprite)
    end
    return self
  end
  if type(originalUpdate) == "function" then
    DexEntryMenu.update = function(self, dt, ...)
      local result = originalUpdate(self, dt, ...)
      advance(dexStates[self], dt)
      return result
    end
  end
  DexEntryMenu.draw = function(self, ...)
    local species = self and self.def and self.def.id
    local state = selectedPlayback(self, dexStates, species,
      species and dexSources[species]
        or (self and self.__battleArtOriginalSprite))
    if state then
      self.sprite = state.frames[state.frame]
      self.spriteTrueColor = true
    elseif self and self.__battleArtOriginalCaptured then
      self.sprite = self.__battleArtOriginalSprite
      self.spriteTrueColor = self.__battleArtOriginalTrueColor
    end
    return originalDraw(self, ...)
  end
  dexInstalled = true
end

return InterfaceSprites
