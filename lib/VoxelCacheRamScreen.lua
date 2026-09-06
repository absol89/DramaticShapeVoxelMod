-- Opaque CONTINUE gate which copies compressed persistent voxel containers to
-- RAM before gameplay. Disk files remain authoritative; this table removes
-- traversal-time filesystem reads without keeping decompressed/GPU copies of
-- the entire world resident.

local V = ...

local Font = require("src.render.Font")
local Disk = V.require("VoxelMeshDisk")
local Screen = {}
Screen.__index = Screen
Screen.isOpaque = true

local function sizeText(bytes)
  bytes = tonumber(bytes) or 0
  if bytes >= 1024 * 1024 * 1024 then
    return ("%.2f GiB"):format(bytes / (1024 * 1024 * 1024))
  end
  return ("%.1f MiB"):format(bytes / (1024 * 1024))
end

local function put(text, row)
  Font.draw(tostring(text or ""), 8, row * 8)
end

function Screen.new(game, onReady, limit, names, total)
  Disk.beginSession()
  if not names then names, total = Disk.ramPlan() end
  local resident = Disk.ramStats().bytes or 0
  return setmetatable({
    game = game,
    onReady = onReady,
    names = names or {},
    total = total or 0,
    limit = limit,
    index = 1,
    loaded = resident,
    failed = 0,
    titleUiBox = { 0, 0, 19, 17 },
  }, Screen)
end

function Screen:finish()
  local callback = self.onReady
  self.onReady = nil
  self.game.stack:pop()
  if callback then callback() end
end

function Screen:update()
  -- Read at least one file per frame, then small records up to an 8 MiB slice.
  -- A large route is intentionally one loading-screen frame rather than a
  -- traversal hitch later.
  local slice, processed = 0, 0
  while self.names[self.index]
      and (self.limit == nil or self.loaded < self.limit)
      and (processed == 0 or slice < 8 * 1024 * 1024) do
    local ok, bytes, added = Disk.loadIntoRam(self.names[self.index])
    if ok and added then
      self.loaded = self.loaded + bytes
    elseif not ok then
      self.failed = self.failed + 1
    end
    self.index = self.index + 1
    slice, processed = slice + (added and bytes or 0), processed + 1
  end
  if not self.names[self.index]
      or (self.limit ~= nil and self.loaded >= self.limit) then
    -- Restricted mobile mod sandboxes may remove collectgarbage entirely.
    pcall(collectgarbage, "collect")
    self:finish()
  end
end

function Screen:draw()
  love.graphics.clear(0, 0, 0, 1)
  love.graphics.setColor(1, 1, 1, 1)
  Font.drawBox(0, 0, 20, 18)
  love.graphics.setColor(0, 0, 0, 1)
  put("LOADING VOXELS", 2)
  put(("FILE %d/%d"):format(math.min(self.index - 1, #self.names),
                              #self.names), 5)
  put(("RAM %s"):format(sizeText(self.loaded)), 7)
  if self.limit == nil then
    put(("TOTAL %s"):format(sizeText(self.total)), 8)
  else
    put(("LIMIT %s"):format(sizeText(self.limit)), 8)
  end
  if self.failed > 0 then put(("DISK FALLBACK %d"):format(self.failed), 11) end
  put("PLEASE WAIT", 14)
end

return Screen
