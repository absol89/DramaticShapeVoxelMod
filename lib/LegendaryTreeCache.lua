-- One mature/sapling GPU owner per map, shared by host and neighbor draws.
-- All generation, decoding and upload run inside ChunkMesher's build queue.
local V = ...
local Budget = V.require("BuildBudget")
local Disk = V.require("VoxelMeshDisk")
local Trace = V.require("CacheTrace")
local Visuals = V.require("CommunityVisuals")
local Cache = {}
local groups = { "sapling", "mature" }

function Cache.new(M)
  local self = { slots = {}, pending = {}, previous = {}, requests = {} }
  local function release(slot)
    if slot then M.releaseTreeParts(slot.parts) end
  end
  local function cancelGroup(id, group)
    V.require("ChunkMesher").cancelWork(id, "legendary-" .. group)
  end
  function self:evict(id)
    if id == nil then
      local ids = {}
      for key in pairs(self.slots) do ids[key] = true end
      for _, job in pairs(self.pending) do ids[job.id] = true end
      for key in pairs(ids) do self:evict(key) end
      self.previous, self.requests = {}, {}
      return
    end
    for _, group in ipairs(groups) do
      cancelGroup(id, group)
      release(self.slots[id] and self.slots[id][group])
    end
    self.slots[id], self.requests[id] = nil, nil
    M.TRUNK.cache[id], M.TRUNK.sapcache[id] = nil, nil
    M.TRUNK.saplingHistory[id] = nil
    Trace.log("tree-evict", id, "GPU and unfinished sections released")
  end
  function self:setLive(live, keepPrevious)
    local history = keepPrevious == false and {} or self.previous
    for id in pairs(self.slots) do
      if not live[id] and not history[id] then self:evict(id) end
    end
    local cancelled = {}
    for _, job in pairs(self.pending) do
      if not live[job.id] then cancelled[#cancelled + 1] = job end
    end
    for _, job in ipairs(cancelled) do cancelGroup(job.id, job.group) end
    self.previous = live
  end
  local function requestGroup(map, masks, priority, bodyOnly, group)
    local id = map.id
    local key = id .. ":" .. group
    local ctx = M.treeInputs(map, group)
    local recipe = group == "sapling" and "sapling" or Visuals.treeDetailLevel()
    ctx.buildRecipe, ctx.buildGroup = recipe, group
    local signature = recipe .. ":" .. M.treeCacheSignature(id, ctx.registry, nil, masks,
      M.treeConfig(), ctx.bases)
    local owned = self.slots[id] or {}
    self.slots[id] = owned
    local slot = owned[group]
    if not next(ctx.registry) then
      cancelGroup(id, group)
      release(slot); owned[group] = nil
      if group == "sapling" then M.TRUNK.sapcache[id] = nil
      else M.TRUNK.cache[id] = nil end
      return
    end
    if slot and (slot.signature == signature or (bodyOnly and slot.full)) then
      slot.full = slot.full or not bodyOnly
      return
    end
    if self.pending[key] and self.pending[key].signature == signature then
      self.pending[key].full = self.pending[key].full or not bodyOnly
      V.require("ChunkMesher").requestWork(map, "legendary-" .. group, signature,
        math.min(priority or 0, group == "sapling" and 1.75 or 1.5))
      return
    end
    -- Maps can be reused by the engine: capture their stable table fields now.
    local target = setmetatable({}, getmetatable(map))
    for k, value in pairs(map) do target[k] = value end
    local job = { signature = signature, parts = {}, id = id, group = group, context = ctx, full = not bodyOnly }
    local function cancel()
      -- Includes a partially uploaded mesh which has not reached publication.
      for mesh in pairs(ctx.resources or {}) do pcall(mesh.release, mesh) end
      ctx.resources = {}
      job.parts = {}
      job.cancelled = true
      if job.co then M.treeContexts[job.co] = nil end
      if self.pending[key] == job then self.pending[key] = nil end
      Trace.log("tree-cancel", id, "group=" .. group)
    end
    local function build()
      if job.cancelled then return end
      job.co = coroutine.running()
      M.treeContexts[job.co] = ctx
      Trace.log("tree-start", id, "recipe=" .. recipe)
      local indexKey = "sections-v3-quad22-" .. signature:gsub(":", "-")
      local cached = Disk.loadTreeParts(target, recipe, indexKey, Budget.check)
      local cacheHit = cached ~= nil
      if cached then
        for i in ipairs(cached.parts or {}) do
          local part = Disk.loadTreeParts(target, recipe, indexKey .. "-" .. i, Budget.check)
          if not part or not M.uploadTreeCache(part, job.parts) then cacheHit = false; break end
          Budget.check()
        end
      end
      if not cacheHit then
        release(job); job.parts = {}
        local index = { parts = {}, cells = {} }
        local wrote = true
        ctx.sectionWriter = function(raw)
          local i = #index.parts + 1
          index.parts[i] = { x = raw.x, y = raw.y, z = raw.z,
            radius = raw.radius, apron = raw.apron, detailFarCount = raw.detailFarCount }
          if Disk.available() then
            wrote = Disk.saveTreeParts(target, recipe, indexKey .. "-" .. i,
              { parts = { raw } }, Budget.check) and wrote
          end
          Trace.log("tree-section", id, "section=" .. i .. " vertices=" .. tostring(raw.detail and raw.detail.n or 0))
          Budget.check()
        end
        local _, _, count = M.buildTrunks(target, masks, group, job.parts)
        ctx.sectionWriter = nil
        index.count, index.tN, index.bN = count or 0, ctx.tN, ctx.bN
        index.cells = ctx.cells
        if Disk.available() then
          if not wrote or not Disk.saveTreeParts(target, recipe, indexKey, index, Budget.check) then
            error("Legendary section cache write failed for " .. id)
          end
        end
        cached = index
      end
      if job.cancelled then return end
      release(owned[group])
      local result = { parts = job.parts, signature = signature, full = job.full,
        cells = cached and cached.cells or {}, count = cached and cached.count or 0 }
      owned[group] = result
      local cache = group == "sapling" and M.TRUNK.sapcache or M.TRUNK.cache
      cache[id] = result
      self.pending[key] = nil
      M.treeContexts[job.co] = nil
      ctx.resources = {} -- completed meshes are now owned exclusively by the slot
      job.parts = {}
      Trace.log(cacheHit and "tree-cache-hit" or "tree-built", id,
        "sections=" .. #result.parts .. " recipe=" .. recipe)
    end
    V.require("ChunkMesher").requestWork(target, "legendary-" .. group, signature,
      math.min(priority or 0, group == "sapling" and 1.75 or 1.5), build, cancel)
    self.pending[key] = job
  end
  function self:request(map, masks, priority, bodyOnly, onlySapling)
    if not map or not map.id then return end
    if not (Visuals.customTrees() or Visuals.customCutTrees() or Visuals.customForest()) then return end
    local ok, static = pcall(V.require, "StaticGeometry")
    local data = ok and static.data and static.data()
    if data then masks = V.require("VoxelPrecache").masksFor(data, map.id) end
    requestGroup(map, masks, priority, bodyOnly, "sapling")
    if not onlySapling then requestGroup(map, masks, priority, bodyOnly, "mature") end
    self.requests[map.id] = { map = map, masks = masks, priority = priority, bodyOnly = bodyOnly }
  end
  function self:ensure(map, masks, priority, bodyOnly)
    local owned = self.slots[map.id]
    if owned and next(owned) then return end
    if self.pending[map.id .. ":mature"] or self.pending[map.id .. ":sapling"] then return end
    self:request(map, masks, priority, bodyOnly)
  end
  function self:get(id, group)
    return (self.slots[id] and self.slots[id][group]) or self.pending[id .. ":" .. group]
  end
  function self:changed(map)
    local prior = self.requests[map.id]
    if prior then self:request(map, prior.masks, prior.priority, prior.bodyOnly, true) end
  end
  function self:stats()
    local maps, sections, vertices, pending = 0, 0, 0, 0
    for _, owned in pairs(self.slots) do
      maps = maps + 1
      for _, slot in pairs(owned) do
        for _, part in ipairs(slot.parts or {}) do
          sections = sections + 1
          for _, name in ipairs({ "trunks", "stones", "hoods", "detail", "shadows" }) do
            local mesh = part[name]
            if mesh and mesh.getVertexCount then vertices = vertices + mesh:getVertexCount() end
          end
        end
      end
    end
    for _ in pairs(self.pending) do pending = pending + 1 end
    return { maps = maps, sections = sections, vertices = vertices, pending = pending }
  end
  return self
end
return Cache
