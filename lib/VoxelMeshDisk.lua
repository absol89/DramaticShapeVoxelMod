-- Persistent raw voxel-mesh streams.
--
-- LOVE Mesh objects are driver/session resources and cannot survive a restart.
-- The six-float vertex streams which create them can: cache those under the
-- save directory, then upload them cooperatively next session instead of
-- rerunning Structures and the terrain carve.
--
-- Every read fails open. Missing, truncated, corrupt, or fingerprint-mismatched
-- files are removed and the ordinary mesher rebuilds them. No user setting or
-- cache id is exposed; CACHE_REVISION is the format/geometry contract and must
-- be bumped whenever emitted vertices change in a way the fingerprint cannot
-- observe directly.

local V = ...

local Budget = V.require("BuildBudget")
local StaticGeometry = V.require("StaticGeometry")
local Version = require("src.core.Version")
local Platform = require("src.core.Platform")

local ffi
do
  local ok, value = pcall(require, "ffi")
  if ok then ffi = value end
end

local Disk = {}
local ramFiles, sessionActive = {}, false
local ramDirty, ramRejected = {}, {}
local ramBytes = 0
local storage
local knownSizes = {}
local writeFailures = {}
local compatibilityOverride
local backendKind
local precacheAllowed = false

-- Best-effort logger; never throws if the engine offers no Logger.
local function diskLog(...)
  local ok, L = pcall(require, "src.core.Logger")
  if ok and L and L.info then pcall(L.info, ...) end
end

-- Some engine sandboxes do not expose the global collectgarbage (observed as
-- "attempt to call global 'collectgarbage' (a nil value)"). Call it through
-- a pcall-guarded wrapper so the forced GC in beginPrecache/dropRam degrades
-- to a no-op instead of crashing on those builds.
local function diskGc()
  pcall(collectgarbage, "collect")
end

-- Static geometry is shared by every journey through one game version. Keep
-- it in a mod-private, deterministic storage scope instead of tying hundreds
-- of map blobs to a save slot. This is only the Game argument supplied to
-- this mod's storage facade; it never changes game.save or another mod's
-- playthrough identity.
local STATIC_PLAYTHROUGH = "bavc_static_mesh_v2"

-- Revision 9 replaces CAVERN brick courses with rough-hewn moonstone faces.
-- Revision 8 varies CAVERN top-surface UV donors and orientation. Revision 7
-- adds CAVERN-only rough rock faces. Revision 6 restored
-- visual-object quads to ordinary cached terrain when no extension could
-- replace them. A revision bump is required because these vertices are not
-- observable in the map-data fingerprint.
-- TEST39 lowers true inner maze walls to 30px and restores every walkable
-- ledge top to its authored height so actors share the visible floor plane.
-- Jagged TEST38 masonry, ordinary floors and the distant perimeter are locked.
Disk.CACHE_REVISION = 25
-- Patch releases which do not change emitted vertices must keep the existing
-- world cache usable. This token matches the first static-mesh-cache-v2 build;
-- CACHE_REVISION, not the public mod version, owns geometry compatibility.
Disk.CACHE_FAMILY = "1.8.1"
local LOGICAL_DIRECTORY = "cache/static-mesh-v2"
Disk.DIRECTORY = LOGICAL_DIRECTORY
Disk.PRECACHE_FAILURE_FILE =
  "mod-derived/BATTLE_ART_VOXEL_FORK/precache-failures.tsv"

local LEGACY_ROOT =
  "mod-derived/BATTLE_ART_VOXEL_FORK/static-mesh-cache-v2"

local MAGIC = "BAVC"
local FORMAT = 2
local RAW_CHUNK = 1024 * 1024

local function available()
  return storage ~= nil
    and love.data and love.data.pack and love.data.unpack
    and love.data.newByteData and love.data.compress and love.data.decompress
    and love.graphics and love.graphics.newMesh
end

function Disk.available()
  return available()
end

function Disk.legacy()
  return type(backendKind) == "string"
    and backendKind:sub(1, 6) == "legacy"
end

function Disk.precacheAvailable()
  return precacheAllowed and available()
end

local function versionParts(value)
  local major, minor, patch = tostring(value or ""):match(
    "^(%d+)%.(%d+)%.(%d+)")
  return tonumber(major), tonumber(minor), tonumber(patch)
end

local function engineAtMost(value, cutoff)
  local major, minor, patch = versionParts(value)
  if not major then return false end
  if major ~= 0 then return major < 0 end
  if minor ~= 1 then return minor < 1 end
  return patch <= cutoff
end

-- Gate the cache on engine capability, not on the OS. 0.1.83 and older expose
-- only the legacy native filesystem/FFI path; 0.1.84 and newer expose the
-- opaque mod.storage byte API, so every platform that reaches 0.1.84 uses the
-- storage backend. bind() still degrades to a read-only legacy backend when a
-- given build lacks storage writes, which avoids attempting a write that
-- would hang the app.
local function engineAtLeast(value, cutoff)
  local major, minor, patch = versionParts(value)
  if not major then return false end
  if major ~= 0 then return major > 0 end
  if minor ~= 1 then return minor > 1 end
  return patch >= cutoff
end

function Disk.precachePolicy(engineVersion, osName)
  local legacy = engineAtMost(engineVersion, 83)
  local allowed = legacy or engineAtLeast(engineVersion, 84)
  return allowed, legacy and "legacy" or "storage"
end

-- The precache generator is offered on every platform whose storage backend
-- can actually persist writes. Whether a build can write is decided by what
-- bind() managed to bind -- not by the OS or a hard-coded engine-version
-- cutoff -- so a read-only sandbox, a missing write privilege, or a future
-- gen1recomp that strips mod.storage writes is all caught the same way:
-- bind() degrades to the read-only "legacy-read" backend (see bind()) and the
-- precache screen shows the "not available" warning instead of letting a
-- doomed write hang. Callers surface the instructional message from there.
--
-- Detect the live engine environment. Wrapped in pcall because the engine
-- APIs (Version.engine, Platform.detect) may be absent or throw on some
-- builds; a detection failure must never crash the caller (e.g. the
-- precache-screen phase decision or the title-menu bind).
local function detectEnvironment()
  if compatibilityOverride then
    return compatibilityOverride.engineVersion, compatibilityOverride.osName
  end
  local ok, engineVersion = pcall(function() return Version.engine end)
  local detected = {}
  if Platform and Platform.detect then
    local ok2, d = pcall(Platform.detect)
    if ok2 and type(d) == "table" then detected = d end
  end
  return ok and engineVersion or nil, detected.os
end

-- True only when a backend bound but cannot persist writes: mod.storage
-- exposed a reader without a writer, the engine sandbox is read-only, the
-- user lacks write privilege, or a stricter gen1recomp dropped storage writes
-- entirely. Detected from the bound backend (see bind()'s "legacy-read"
-- fallback), never from the OS or engine version, so the warning is shown
-- exactly when a write would fail -- on any platform.
function Disk.cacheReadOnly()
  return backendKind == "legacy-read"
end

function Disk._setCompatibilityForTests(engineVersion, osName)
  compatibilityOverride = engineVersion and {
    engineVersion = engineVersion, osName = osName,
  } or nil
end

local function legacyName(key)
  local prefix = LOGICAL_DIRECTORY .. "/"
  if key:sub(1, #prefix) ~= prefix then return nil end
  local tail = key:sub(#prefix + 1)
  local id, product = tail:match("^([^/]+)/(.+)$")
  if not id then return nil end
  -- The aux payload was renamed to "deco" on disk (Windows reserved-name fix,
  -- 1.7.4/potato_voxel), but the legacy FFI filesystem still stores it as
  -- ".aux.bavc". Accept both so legacy engines (<= 0.1.83) can read AND write
  -- the aux segment instead of failing on an unknown "deco" product.
  if product == "aux" or product == "deco" then
    return LEGACY_ROOT .. "/" .. id .. ".aux.bavc"
  end
  if product == "full-terrain" then
    return LEGACY_ROOT .. "/" .. id .. ".full.terrain.bavc"
  end
  if product == "body-terrain" then
    return LEGACY_ROOT .. "/" .. id .. ".body.terrain.bavc"
  end
  return nil
end

local function legacyKey(name)
  local id = name:match("^(.-)%.aux%.bavc$")
  if id then return LOGICAL_DIRECTORY .. "/" .. id .. "/deco" end
  id = name:match("^(.-)%.full%.terrain%.bavc$")
  if id then return LOGICAL_DIRECTORY .. "/" .. id .. "/full-terrain" end
  id = name:match("^(.-)%.body%.terrain%.bavc$")
  if id then return LOGICAL_DIRECTORY .. "/" .. id .. "/body-terrain" end
  return nil
end

local function persistenceFilesystem()
  local fs
  pcall(function() fs = love and love.filesystem end)
  if fs then return fs end
  -- Newer sandboxes hide love.filesystem from the mod, but engine-internals
  -- permission still lets this compatibility reader ask the engine for its
  -- persistence overlay. It is read-only on modern Windows/mobile; all new
  -- writes continue through mod.storage.
  pcall(function()
    local SaveData = require("src.core.SaveData")
    fs = SaveData.persistenceFs and SaveData.persistenceFs() or nil
  end)
  return fs
end

local function legacyStorage(readOnly)
  local fs = persistenceFilesystem()
  if not (ffi and fs and fs.read and fs.getInfo and fs.getDirectoryItems) then
    return nil
  end
  if not readOnly and not (fs.write and fs.createDirectory) then return nil end
  return {
    list = function(_, prefix)
      local out = {}
      local ok, names = pcall(fs.getDirectoryItems, LEGACY_ROOT)
      if not ok then return out end
      for _, name in ipairs(names or {}) do
        local key = legacyKey(name)
        if key and key:sub(1, #prefix) == prefix then out[#out + 1] = key end
      end
      table.sort(out)
      return out
    end,
    readBytes = function(_, key)
      local path = legacyName(key)
      if not path then return nil end
      local ok, bytes = pcall(fs.read, path)
      return ok and bytes or nil
    end,
    writeBytes = function(_, key, bytes)
      if readOnly then return false, "legacy cache is read-only" end
      local path = legacyName(key)
      if not path then return false, "invalid legacy cache key" end
      local made = fs.createDirectory(LEGACY_ROOT)
      if made == false then return false, "could not create legacy cache directory" end
      return fs.write(path, bytes)
    end,
  }
end

local function bindLegacy()
  storage = legacyStorage(false)
  if not storage then return false end
  backendKind = "legacy"
  Disk.DIRECTORY = LOGICAL_DIRECTORY
  return true
end

local function mergeLegacyReads(primary)
  local legacy = legacyStorage(true)
  if not legacy then return primary end
  return {
    list = function(_, prefix)
      local out, seen = {}, {}
      for _, source in ipairs({ primary, legacy }) do
        local ok, names = pcall(source.list, source, prefix)
        if ok then
          for _, key in ipairs(names or {}) do
            if not seen[key] then seen[key], out[#out + 1] = true, key end
          end
        end
      end
      table.sort(out)
      return out
    end,
    readBytes = function(_, key)
      local ok, bytes = pcall(primary.readBytes, primary, key)
      if ok and type(bytes) == "string" then return bytes end
      return legacy:readBytes(key)
    end,
    writeBytes = function(_, key, bytes)
      return primary:writeBytes(key, bytes)
    end,
  }
end

-- Forward-declared because bindStorage performs the probe. Without this local
-- in scope there, Lua resolves the later definition as an unrelated global.
local storageRoundTrips

local function bindStorage(game)
  local api = V.mod and V.mod.storage
  if not api or type(api.list) ~= "function" then return false end
  local version = game and game.save and game.save.version
  if type(version) ~= "string" or version == "" then
    local ok, GameVersion = pcall(require, "src.core.GameVersion")
    if ok and type(GameVersion.get) == "function" then
      version = GameVersion.get()
    end
  end
  if type(version) ~= "string" or version == "" then return false end
  local scope = {
    save = { version = version,
             meta = { playthroughId = STATIC_PLAYTHROUGH } },
  }
  if type(api.readBytes) ~= "function" or type(api.writeBytes) ~= "function" then
    return false
  end
  backendKind = "storage-bytes"
  Disk.DIRECTORY = LOGICAL_DIRECTORY
  storage = mergeLegacyReads({
    list = function(_, prefix) return api:list(scope, prefix) end,
    readBytes = function(_, key) return api:readBytes(scope, key) end,
    writeBytes = function(_, key, bytes)
      return api:writeBytes(scope, key, bytes)
    end,
  })
  -- Self-test the write path. Some engine builds (observed on 0.2.x storage
  -- backend) accept writeBytes but never persist the bytes: the directory is
  -- created yet the file body is dropped, so every later launch sees an empty
  -- cache and the title-screen preloader regenerates the whole world on the
  -- main thread -- a multi-minute freeze -- while the pause-menu CACHE write
  -- silently fails. Probe a round-trip and, if it lies, refuse this backend so
  -- bind() degrades to the read-only legacy-read path instead of using a
  -- storage backend that cannot hold a single byte.
  if not storageRoundTrips(storage, scope, api) then
    diskLog("voxel cache: storage backend accepted writes but did not persist; "
            .. "degrading to read-only legacy-read")
    return false
  end
  return true
end

-- Write a sentinel to the bound scope and read it back; the backend is usable
-- for persistence only if the read returns the exact bytes written. Wrapped in
-- pcall so a throwing/missing API can never crash bind(). The probe key lives
-- OUTSIDE LOGICAL_DIRECTORY so ramPlan()/stats() never enumerate or preload it.
storageRoundTrips = function(store, scope, api)
  -- A fixed key avoids leaving one empty tombstone per launch on storage
  -- implementations where writing "" is the only available invalidation.
  local probe = "cache/__bind_probe"
  local sentinel = "BAVCbind" .. tostring(os and os.clock and os.clock() or 0)
  local ok, wrote = pcall(store.writeBytes, store, probe, sentinel)
  if not ok or wrote ~= true then
    pcall(store.writeBytes, store, probe, "")
    return false
  end
  local rok, got = pcall(store.readBytes, store, probe)
  pcall(store.writeBytes, store, probe, "")
  if not rok or got ~= sentinel then return false end
  return true
end

-- mod.storage is playthrough-scoped, while this cache is not. Bind the public
-- byte API to a private synthetic scope so a first-time user can precache
-- before NEW GAME and every later save can reuse the same immutable geometry.
function Disk.bind(game, selected)
  storage = nil
  backendKind = nil
  precacheAllowed = false
  knownSizes = {}
  local engineVersion, osName = detectEnvironment()
  local allowed, backend = Disk.precachePolicy(engineVersion, osName)
  precacheAllowed = allowed
  if not allowed then return false end
  if backend == "legacy" then return bindLegacy() end
  if bindStorage(game) then return true end
  storage = legacyStorage(true)
  if storage then
    backendKind = "legacy-read"
    precacheAllowed = false
    Disk.DIRECTORY = LOGICAL_DIRECTORY
    return true
  end
  return false
end

local function u32(n)
  n = math.floor(tonumber(n) or 0) % 4294967296
  return string.char(n % 256, math.floor(n / 256) % 256,
                     math.floor(n / 65536) % 256,
                     math.floor(n / 16777216) % 256)
end

local function readU32(s, pos)
  if not s or pos + 3 > #s then return nil end
  return s:byte(pos) + s:byte(pos + 1) * 256
       + s:byte(pos + 2) * 65536 + s:byte(pos + 3) * 16777216
end

local function addList(parts, list)
  parts[#parts + 1] = tostring(#(list or {}))
  for _, value in ipairs(list or {}) do
    if type(value) == "table" then
      addList(parts, value)
    else
      parts[#parts + 1] = tostring(value)
    end
  end
end

-- Exact canonical input description rather than a short probabilistic hash.
-- Map block edits, tileset replacements, connection-mask changes and void-fill
-- changes therefore invalidate themselves without relying on a remembered
-- cleanup event. The revision covers algorithm/data rules not present here.
local function canonicalMasks(map, masks)
  local out, seen = {}, {}
  local def = map and map.def or {}
  -- ChunkMesher's FULL ring extends three 32px blocks. Neighbours outside
  -- that rectangle cannot remove a vertex; runtime survey zoom may discover
  -- more of them than the title generator, and they must not create a false
  -- persistent variant.
  local pad, w, h = 96, (def.width or 0) * 32, (def.height or 0) * 32
  for _, mask in ipairs(masks or {}) do
    local row = { mask[1], mask[2], mask[3], mask[4] }
    local relevant = row[3] > -pad and row[1] < w + pad
                     and row[4] > -pad and row[2] < h + pad
    local key = table.concat(row, ",")
    if relevant and not seen[key] then
      seen[key], out[#out + 1] = true, row
    end
  end
  table.sort(out, function(a, b)
    for i = 1, 4 do
      if a[i] ~= b[i] then return (a[i] or 0) < (b[i] or 0) end
    end
    return false
  end)
  return out
end

function Disk.staticEligible(map)
  return StaticGeometry.source(map) ~= nil
end

function Disk.fingerprint(map, slot, masks, kind)
  map = StaticGeometry.source(map) or map
  -- BODY emits only the map's playable rectangle. Connection masks suppress
  -- the border ring of FULL meshes and cannot alter BODY vertices, so letting
  -- survey/title-screen mask discovery enter this key creates false variants.
  if slot == "body" then masks = nil end
  local def, tileset = map.def or {}, map.tileset or {}
  local parts = {
    "rev", tostring(Disk.CACHE_REVISION),
    "mod", Disk.CACHE_FAMILY,
    "kind", tostring(kind), "slot", tostring(slot),
    "map", tostring(map.id), "tileset", tostring(def.tileset),
    "size", tostring(def.width), tostring(def.height),
    "border", tostring(def.borderBlock),
    "image", tostring(tileset.image),
    "imageSize", tostring(tileset.imageWidth), tostring(tileset.imageHeight),
    "row", tostring(tileset.tilesPerRow),
    "trueColor", tileset.trueColor and "1" or "0",
  }
  -- Community visuals are real geometry/UV inputs. Keep each choice in the
  -- canonical fingerprint so a DEFAULT cache can never be reused for custom
  -- trees/fences/pillars (or vice versa), while every default remains the
  -- creator's original cache family.
  local CommunityVisuals = V.require("CommunityVisuals")
  -- Final contract: brick courses, bridge boards, crown-lock and the
  -- grain-mapped TEST435 fence must never reuse an older community mesh.
  parts[#parts + 1] = "legendary-visuals-final"
  parts[#parts + 1] = CommunityVisuals.layout()
  parts[#parts + 1] = CommunityVisuals.trees:get()
  parts[#parts + 1] = CommunityVisuals.cutTrees:get()
  parts[#parts + 1] = CommunityVisuals.signs:get()
  parts[#parts + 1] = CommunityVisuals.grass:get()
  parts[#parts + 1] = CommunityVisuals.roads:get()
  parts[#parts + 1] = CommunityVisuals.walls:get()
  parts[#parts + 1] = CommunityVisuals.courtyards:get()
  -- VOID FILL (trees vs black) only changes the apron ring that sits in the
  -- FULL slot (see Structures.lua hullRingOnly / RING). The BODY slot builds
  -- r=0 (no ring) so its vertices never vary with void fill, and AUX carries
  -- only grass/flowers/figures. Keying those on void fill needlessly
  -- invalidated the heavy slots for every map on each toggle (and main.lua's
  -- voidFill.check() forces a full mesher rebuild anyway). Keep void only in
  -- the FULL key so toggling void fill rebuilds just the light ring, not the
  -- cached body+aux for every map.
  if slot ~= "body" and slot ~= "aux" then
    local okTR, TileRenderer = pcall(require, "src.render.TileRenderer")
    parts[#parts + 1] = "void"
    parts[#parts + 1] = tostring(okTR and TileRenderer.voidFill or "trees")
  end
  parts[#parts + 1] = "blocks"
  addList(parts, def.blocks)
  parts[#parts + 1] = "tiles"
  addList(parts, tileset.blocks)
  parts[#parts + 1] = "masks"
  addList(parts, canonicalMasks(map, masks))
  return table.concat(parts, "|")
end

local function safeId(id)
  return tostring(id):gsub("[^%w_-]", "_")
end

-- Windows treats AUX, CON, PRN, NUL, COM1-9 and LPT1-9 as reserved device
-- names and refuses to create a file whose base name matches,
-- case-insensitively. Our logical "aux" payload key became a bare "aux"
-- on-disk segment, so every aux write failed (write_failed/verify_failed)
-- on Windows while terrain/water in the same directory succeeded. The
-- internal kind stays "aux" (traces, status, manifest); only the on-disk
-- segment changes. Mirrors potato_voxel's kindSegment fix (1.7.4).
local function kindSegment(kind)
  return kind == "aux" and "deco" or kind
end

local function pathFor(map, slot, kind)
  local suffix = kind == "aux" and kindSegment(kind)
                 or (tostring(slot) .. "-terrain")
  return Disk.DIRECTORY .. "/" .. safeId(map.id) .. "/" .. suffix
end

local function physicalPath(path)
  return legacyName(path) or path
end

local function recordWriteFailure(path, stage, err)
  writeFailures[#writeFailures + 1] = {
    path = tostring(path or "-"),
    physical = tostring(physicalPath(path or "") or "-"),
    stage = tostring(stage or "write"),
    error = tostring(err or "unknown error"),
  }
end

function Disk.beginFailureCapture()
  writeFailures = {}
end

function Disk.takeWriteFailures()
  local out = writeFailures
  writeFailures = {}
  return out
end

-- Forget a broken/session-stale container without touching persistent storage.
-- Gameplay is deliberately RAM-only; CACHE -> SAVE is the sole runtime path
-- which writes the canonical disk cache.
local function discard(path, rejected)
  local held = ramFiles[path]
  if held then ramBytes = math.max(0, ramBytes - #held) end
  ramFiles[path] = nil
  ramDirty[path] = nil
  if rejected then ramRejected[path] = true end
end

local function header(fp)
  return MAGIC .. u32(FORMAT) .. u32(#fp) .. fp
end

-- CONTINUE may preload the compressed BAVC containers. They remain compressed
-- here (~745 MiB for the current full world rather than ~2.7 GiB of vertices)
-- and are decoded into temporary ByteData only when a map is uploaded.
local function safePriority(priority)
  local rank = {}
  for i, id in ipairs(priority or {}) do rank[safeId(id)] = i end
  return rank
end

function Disk.orderRamNames(names, priority)
  local rank = safePriority(priority)
  local prefix = Disk.DIRECTORY .. "/"
  local function parts(path)
    local tail = path:sub(1, #prefix) == prefix and path:sub(#prefix + 1) or ""
    local id, product = tail:match("^([^/]+)/(.+)$")
    local mapRank = rank[id] or math.huge
    local current = mapRank == 1
    local phase
    if current then
      -- Decorations are small and required beside the current full terrain;
      -- the current map's neighbour-only BODY duplicate can wait.
      phase = product == "deco" and 1
           or product == "full-terrain" and 2
           or product == "body-terrain" and 5 or 7
    elseif mapRank < math.huge then
      -- Connected strips are drawn as BODY meshes during the first frame.
      phase = product == "body-terrain" and 3
           or product == "deco" and 4
           or product == "full-terrain" and 6 or 7
    else
      phase = 7
    end
    return phase, mapRank
  end
  table.sort(names, function(a, b)
    local ap, ar = parts(a)
    local bp, br = parts(b)
    if ap ~= bp then return ap < bp end
    if ar ~= br then return ar < br end
    return a < b
  end)
  return names
end

function Disk.ramPlan(priority)
  if not available() then return {}, 0 end
  local names, bytes = {}, 0
  local ok, listed = pcall(storage.list, storage, Disk.DIRECTORY)
  if not ok then return names, bytes end
  for _, key in ipairs(listed or {}) do
    if key:sub(1, #Disk.DIRECTORY + 1) == Disk.DIRECTORY .. "/" then
      names[#names + 1] = key
      local held = ramFiles[key]
      bytes = bytes + (held and #held or knownSizes[key] or 0)
    end
  end
  Disk.orderRamNames(names, priority)
  return names, bytes
end

function Disk.beginSession()
  sessionActive = true
end

function Disk.beginPrecache()
  ramFiles, ramDirty, ramRejected = {}, {}, {}
  ramBytes = 0
  sessionActive = false
  diskGc()
end

function Disk.loadIntoRam(name)
  if not sessionActive or type(name) ~= "string"
     or name:sub(1, #Disk.DIRECTORY + 1) ~= Disk.DIRECTORY .. "/" then
    return false, 0
  end
  local path = name
  local prior = ramFiles[path]
  if prior then return true, #prior, false end
  local ok, blob = pcall(storage.readBytes, storage, path)
  if not ok or type(blob) ~= "string" then return false, 0, false end
  ramFiles[path] = blob
  ramBytes = ramBytes + #blob
  knownSizes[path] = #blob
  return true, #blob, true
end

function Disk.ramReady(names)
  if not sessionActive then return false end
  for _, name in ipairs(names or {}) do
    if not ramFiles[name] then return false end
  end
  return true
end

function Disk.ramStats()
  local files, dirty, dirtyBytes = 0, 0, 0
  for _ in pairs(ramFiles) do files = files + 1 end
  for path in pairs(ramDirty) do
    dirty = dirty + 1
    dirtyBytes = dirtyBytes + #(ramFiles[path] or "")
  end
  return { enabled = sessionActive, files = files, bytes = ramBytes,
           dirty = dirty, dirtyBytes = dirtyBytes }
end

-- DROP abandons both the whole-world preload and any unsaved generated
-- containers. Already-uploaded current/neighbor meshes remain alive; future
-- requests repopulate this table lazily from disk or freshly generated data.
function Disk.dropRam()
  local stats = Disk.ramStats()
  ramFiles, ramDirty, ramRejected = {}, {}, {}
  ramBytes = 0
  sessionActive = true
  diskGc()
  return stats
end

local FP_LABEL = {
  rev = true, mod = true, kind = true, slot = true, map = true,
  tileset = true, size = true, border = true, image = true,
  imageSize = true, row = true, trueColor = true, void = true,
  blocks = true, tiles = true, masks = true,
}

local function fingerprintDifference(actual, expected)
  local a, e = {}, {}
  for part in tostring(actual or ""):gmatch("[^|]+") do a[#a + 1] = part end
  for part in tostring(expected or ""):gmatch("[^|]+") do e[#e + 1] = part end
  local n = math.max(#a, #e)
  for i = 1, n do
    if a[i] ~= e[i] then
      local label = "fingerprint"
      for j = i, 1, -1 do
        if FP_LABEL[e[j]] then label = e[j] break end
      end
      return ("%s: stored=%s expected=%s"):format(
        label, tostring(a[i]), tostring(e[i]))
    end
  end
  return "fingerprint differs"
end

local function reportMismatch(map, path, actual, expected, detail)
  StaticGeometry.record(map and map.id, "cache.record", path,
    detail or fingerprintDifference(actual, expected))
end

local function parseHeader(blob, expected)
  if not blob or #blob < 12 or blob:sub(1, 4) ~= MAGIC then return nil, nil end
  local format = readU32(blob, 5)
  local n = readU32(blob, 9)
  if format ~= FORMAT or not n or 12 + n > #blob then return nil, nil end
  local first = 13
  local actual = blob:sub(first, first + n - 1)
  if actual ~= expected then return nil, actual end
  return first + n, actual
end

-- Cheap resume probe for the title-screen whole-game generator.  Reading and
-- decompressing a 20+ MiB route merely to learn that it is already cached
-- would make "resume" nearly as expensive as generating it, so inspect only
-- the fixed header and exact fingerprint.  The ordinary load path still fully
-- validates every stream before gameplay uses it.
local function headerMatches(path, expected, map)
  if not available() then return false, "cache backend unavailable" end
  local ok, blob = pcall(storage.readBytes, storage, path)
  if not ok then return false, "read error: " .. tostring(blob) end
  if type(blob) ~= "string" or #blob == 0 then
    return false, "missing or empty cache record"
  end
  knownSizes[path] = #blob
  local pos, actual = parseHeader(blob, expected)
  local matches = pos ~= nil
  if not matches then
    reportMismatch(map, path, actual, expected,
      actual and nil or "invalid BAVC header/format")
  end
  if not matches then
    return false, actual and fingerprintDifference(actual, expected)
                  or "invalid BAVC header/format"
  end
  return true
end

-- Whether one map/slot has both persistent products the renderer will ask
-- for: shared grass/flower/figure data and its terrain+water stream.
function Disk.complete(map, bodyOnly, masks)
  if not map or not Disk.staticEligible(map) then return false end
  local slot = bodyOnly and "body" or "full"
  return headerMatches(pathFor(map, "aux", "aux"),
                       Disk.fingerprint(map, "aux", nil, "aux"), map)
     and headerMatches(pathFor(map, slot, "terrain"),
                       Disk.fingerprint(map, slot, masks, "terrain"), map)
end


function Disk.completeDetails(map, bodyOnly, masks)
  if not map then
    return false, { { kind = "map", path = "-", physical = "-",
                      error = "map unavailable" } }
  end
  if not Disk.staticEligible(map) then
    return false, { { kind = "map", path = tostring(map.id or "-"),
                      physical = "-", error = "map is not static-cache eligible" } }
  end
  local slot = bodyOnly and "body" or "full"
  local checks = {
    { kind = "deco", path = pathFor(map, "aux", "aux"),
      fp = Disk.fingerprint(map, "aux", nil, "aux") },
    { kind = slot .. "-terrain", path = pathFor(map, slot, "terrain"),
      fp = Disk.fingerprint(map, slot, masks, "terrain") },
  }
  local failures = {}
  for _, check in ipairs(checks) do
    local matched, err = headerMatches(check.path, check.fp, map)
    if not matched then
      failures[#failures + 1] = {
        kind = check.kind, path = check.path,
        physical = physicalPath(check.path), error = err,
      }
    end
  end
  return #failures == 0, failures
end

-- Small public report used by the generator screen and documentation checks.
-- It never loads a payload merely to measure it; byte totals include records
-- already read or written during this session.
function Disk.stats()
  local out = { bytes = 0, files = 0, maps = 0,
                aux = 0, full = 0, body = 0 }
  if not available() then return out end
  local ok, names = pcall(storage.list, storage, Disk.DIRECTORY)
  if not ok then return out end
  local maps = {}
  for _, path in ipairs(names or {}) do
    if path:sub(1, #Disk.DIRECTORY + 1) == Disk.DIRECTORY .. "/" then
      local name = path:sub(#Disk.DIRECTORY + 2)
      local blob = ramFiles[path]
      local size = blob and #blob or knownSizes[path]
      out.files = out.files + 1
      out.bytes = out.bytes + (size or 0)
      local id = name:match("^(.-)/deco$")
              or name:match("^(.-)/aux$")
              or name:match("^(.-)/full%-terrain$")
              or name:match("^(.-)/body%-terrain$")
      if id then maps[id] = true end
      if name:match("/deco$") or name:match("/aux$") then
        out.aux = out.aux + 1
      elseif name:match("/full%-terrain$") then
        out.full = out.full + 1
      elseif name:match("/body%-terrain$") then
        out.body = out.body + 1
      end
    end
  end
  for _ in pairs(maps) do out.maps = out.maps + 1 end
  return out
end

local function streamRecord(blob, pos)
  local n = readU32(blob, pos)
  if not n then return nil end
  local chunks = readU32(blob, pos + 4)
  if not chunks or chunks > 65536 then return nil end
  pos = pos + 8
  local expected = n * 6 * 4
  if chunks ~= (expected > 0 and math.ceil(expected / RAW_CHUNK) or 0) then
    return nil
  end
  if expected == 0 then return { n = n }, pos end
  -- Allocate the final stable buffer once. The old loader decompressed into a
  -- table of Lua strings and table.concat made a second full-size copy; a
  -- Forest-sized mesh briefly occupied ~172 MiB before upload, and an FFI
  -- pointer into that Lua string was then carried across cooperative yields.
  local rawChunks, total = {}, 0
  for _ = 1, chunks do
    local rawBytes = readU32(blob, pos)
    local packedBytes = readU32(blob, pos + 4)
    if not rawBytes or rawBytes > RAW_CHUNK
       or total + rawBytes > expected
       or not packedBytes or packedBytes > #blob - pos - 7 then
      return nil
    end
    local first = pos + 8
    local packed = blob:sub(first, first + packedBytes - 1)
    local ok, raw = pcall(love.data.decompress, "string", "lz4", packed)
    if not ok or type(raw) ~= "string" or #raw ~= rawBytes then
      return nil
    end
    rawChunks[#rawChunks + 1] = raw
    total = total + rawBytes
    pos = first + packedBytes
    Budget.check()
  end
  if total ~= expected or (expected == 0 and chunks ~= 0) then return nil end
  return { n = n, chunks = rawChunks }, pos
end

local function readValidated(path, fp, map)
  if not available() then return nil end
  local blob = ramFiles[path]
  if not blob then
    if sessionActive and ramRejected[path] then return nil end
    local ok, loaded = pcall(storage.readBytes, storage, path)
    if not ok or not loaded then return nil end
    blob = loaded
    knownSizes[path] = #blob
    if sessionActive then
      ramFiles[path] = blob
      ramBytes = ramBytes + #blob
    end
  end
  local pos, actual = parseHeader(blob, fp)
  if not pos then
    reportMismatch(map, path, actual, fp,
                   actual and nil or "invalid BAVC header/format")
    discard(path, true)
    return nil
  end
  return blob, pos
end

function Disk.loadTerrain(map, slot, masks)
  if not Disk.staticEligible(map) then return nil end
  local path = pathFor(map, slot, "terrain")
  local fp = Disk.fingerprint(map, slot, masks, "terrain")
  local blob, pos = readValidated(path, fp, map)
  if not blob then return nil end
  local terrain, nextPos = streamRecord(blob, pos)
  local water, finalPos
  if nextPos then water, finalPos = streamRecord(blob, nextPos) end
  if not terrain or not water or finalPos ~= #blob + 1 then
    discard(path, true)
    return nil
  end
  return { terrain = terrain, water = water }
end

local function float4(blob, pos)
  if pos + 15 > #blob then return nil end
  local a, b, c, d, nextPos = love.data.unpack("<ffff", blob, pos)
  return { a, b, c, d }, nextPos
end

function Disk.loadAux(map)
  if not Disk.staticEligible(map) then return nil end
  local path = pathFor(map, "aux", "aux")
  local fp = Disk.fingerprint(map, "aux", nil, "aux")
  local blob, pos = readValidated(path, fp, map)
  if not blob then return nil end
  local grass, p2 = streamRecord(blob, pos)
  local flowers, p3
  if p2 then flowers, p3 = streamRecord(blob, p2) end
  local count = p3 and readU32(blob, p3) or nil
  if not grass or not flowers or not count or count > 1024 then
    discard(path, true); return nil
  end
  pos = p3 + 4
  local figures = {}
  for _ = 1, count do
    local stream, nextPos = streamRecord(blob, pos)
    local meta, finalPos
    if nextPos then meta, finalPos = float4(blob, nextPos) end
    if not stream or not meta then discard(path, true); return nil end
    stream.wx, stream.wz, stream.y, stream.w = meta[1], meta[2], meta[3], meta[4]
    figures[#figures + 1] = stream
    pos = finalPos
  end
  if pos ~= #blob + 1 then discard(path, true); return nil end
  return { grass = grass, flowers = flowers, figures = figures }
end

local function write(file, bytes) file:write(bytes) end

local function writeChunked(file, record)
  local n = record and record.n or 0
  write(file, u32(n or 0))
  local bytes = (n or 0) * 6 * 4
  local chunks = bytes > 0 and math.ceil(bytes / RAW_CHUNK) or 0
  write(file, u32(chunks))
  if not record or n == 0 then return true end
  if record.ptr and ffi then
    local offset = 0
    while offset < bytes do
      local count = math.min(RAW_CHUNK, bytes - offset)
      local raw = ffi.string(
        ffi.cast("const uint8_t*", record.ptr) + offset, count)
      local packed = love.data.compress("string", "lz4", raw)
      write(file, u32(count))
      write(file, u32(#packed))
      write(file, packed)
      offset = offset + count
      Budget.check()
    end
    return true
  end
  if not record.chunks then return false end
  local pending, emitted = "", 0
  local function emit(raw)
    local count = #raw
    local packed = love.data.compress("string", "lz4", raw)
    write(file, u32(count))
    write(file, u32(#packed))
    write(file, packed)
    emitted = emitted + count
    Budget.check()
  end
  for _, chunk in ipairs(record.chunks) do
    pending = pending .. chunk
    while #pending >= RAW_CHUNK do
      emit(pending:sub(1, RAW_CHUNK))
      pending = pending:sub(RAW_CHUNK + 1)
    end
  end
  if #pending > 0 then emit(pending) end
  if emitted ~= bytes then error("invalid voxel cache stream length", 0) end
  return true
end

local function writePersistent(path, blob)
  diskLog("voxel cache: write start %s (%d bytes)", tostring(path), #blob)
  local called, ok, code, message = pcall(storage.writeBytes, storage, path, blob)
  if not called then
    diskLog("voxel cache: write pcall failed %s", tostring(ok))
    recordWriteFailure(path, "write exception", ok)
    return false, tostring(ok)
  end
  diskLog("voxel cache: write done %s ok=%s", tostring(path), tostring(ok == true))
  local err = ok and nil or tostring(message or code or "storage write failed")
  if ok ~= true then recordWriteFailure(path, "storage write", err) end
  return ok == true, err
end

local function remember(path, blob, dirty)
  local prior = ramFiles[path]
  if prior then ramBytes = math.max(0, ramBytes - #prior) end
  ramFiles[path] = blob
  ramBytes = ramBytes + #blob
  knownSizes[path] = #blob
  ramDirty[path] = dirty and true or nil
  ramRejected[path] = nil
end

local function encoded(fp, writer)
  local parts = {}
  local sink = {}
  function sink:write(bytes)
    parts[#parts + 1] = bytes
    return true
  end
  write(sink, header(fp))
  writer(sink)
  return table.concat(parts)
end

local function writeFile(path, fp, writer)
  if not available() then
    local err = "cache backend unavailable (" .. tostring(backendKind) .. ")"
    recordWriteFailure(path, "backend", err)
    return false, err
  end
  -- Preserve the encoder's real exception. The old bare false made an aux
  -- failure invisible, after which the mesher committed an unusable
  -- terrain-only map and the title screen appeared stuck.
  local ok, blob = pcall(encoded, fp, writer)
  if not ok then
    recordWriteFailure(path, "encode", blob)
    return false, tostring(blob)
  end
  if type(blob) ~= "string" then
    recordWriteFailure(path, "encode", "encoder returned no bytes")
    return false, "encoder returned no bytes"
  end
  if sessionActive then
    remember(path, blob, true)
    return true
  end
  return writePersistent(path, blob)
end


function Disk.writePrecacheFailureLog(rows)
  rows = rows or {}
  local lines = {
    "# BATTLE ART VOXEL FORK precache failures",
    "# Regenerated on each GENERATE PRECACHE run.",
    "map\tslot\tstage\tcache-key\tbackend-path\terror",
  }
  for _, row in ipairs(rows) do
    local values = {}
    for _, key in ipairs({ "map", "slot", "stage", "path", "physical", "error" }) do
      values[#values + 1] = tostring(row[key] or "-"):gsub("[\t\r\n]", " ")
    end
    local line = table.concat(values, "\t")
    lines[#lines + 1] = line
    diskLog("voxel precache failure: %s", line)
  end
  lines[#lines + 1] = ""
  local fs = persistenceFilesystem()
  if not (fs and fs.write and fs.createDirectory) then return false end
  local ok = pcall(function()
    assert(fs.createDirectory("mod-derived/BATTLE_ART_VOXEL_FORK"))
    assert(fs.write(Disk.PRECACHE_FAILURE_FILE, table.concat(lines, "\n")))
  end)
  return ok, Disk.PRECACHE_FAILURE_FILE
end

-- Explicit pause-menu commit. Successful files become clean RAM entries;
-- failures remain dirty so granting storage permission and selecting SAVE
-- again retries exactly the unsaved set.
function Disk.saveRamToDisk()
  if not available() then return false, 0, 0, { "cache API unavailable" } end
  local paths = {}
  for path in pairs(ramDirty) do paths[#paths + 1] = path end
  table.sort(paths)
  local saved, failures, errors = 0, 0, {}
  for _, path in ipairs(paths) do
    local blob = ramFiles[path]
    local ok, err
    if blob then
      ok, err = writePersistent(path, blob)
    else
      ok, err = false, "missing RAM data"
    end
    if ok then
      ramDirty[path] = nil
      saved = saved + 1
    else
      failures = failures + 1
      errors[#errors + 1] = path .. ": " .. tostring(err or "missing RAM data")
    end
    Budget.check()
  end
  return failures == 0, saved, failures, errors
end

function Disk.saveTerrain(map, slot, masks, terrain, water)
  if not Disk.staticEligible(map) then return false end
  local path = pathFor(map, slot, "terrain")
  local fp = Disk.fingerprint(map, slot, masks, "terrain")
  return writeFile(path, fp, function(file)
    writeChunked(file, terrain)
    writeChunked(file, water)
  end)
end

local function f32x4(a, b, c, d)
  return love.data.pack("string", "<ffff", a or 0, b or 0, c or 0, d or 0)
end

function Disk.saveAux(map, aux)
  if not Disk.staticEligible(map) then return false end
  local path = pathFor(map, "aux", "aux")
  local fp = Disk.fingerprint(map, "aux", nil, "aux")
  return writeFile(path, fp, function(file)
    writeChunked(file, aux.grass)
    writeChunked(file, aux.flowers)
    write(file, u32(#(aux.figures or {})))
    for _, figure in ipairs(aux.figures or {}) do
      writeChunked(file, figure)
      write(file, f32x4(figure.wx, figure.wz, figure.y, figure.w))
      Budget.check()
    end
  end)
end

-- Delete every on-disk static-mesh cache file so the mesher rebuilds from
-- scratch on the next frame. Used by the "DROP MESH CACHE" pause-menu action
-- (e.g. after a lift/grounding change left stale floating geometry baked in).
-- Fails open: every filesystem op is pcall-guarded, and a missing or
-- read-only backend simply reports zero removed. On the legacy FFI backend
-- (<0.1.84) the files live under LEGACY_ROOT as .bavc; on the storage
-- backend they live under LOGICAL_DIRECTORY. Clears the in-RAM mirror too.
function Disk.purge()
  local fs = persistenceFilesystem()
  local removed = 0
  -- The current storage facade is the authoritative backend on modern
  -- engines. The public byte API has no delete primitive, so overwrite each
  -- cache body with an empty value; ordinary validation treats that as absent
  -- and rebuilds it. Read-only facades simply reject these writes.
  if storage and storage.list and storage.writeBytes then
    local ok, names = pcall(storage.list, storage, LOGICAL_DIRECTORY)
    if ok then
      for _, key in ipairs(names or {}) do
        if key:sub(1, #LOGICAL_DIRECTORY + 1) == LOGICAL_DIRECTORY .. "/" then
          local called, did = pcall(storage.writeBytes, storage, key, "")
          if called and did == true then removed = removed + 1 end
        end
      end
    end
  end
  if fs and fs.getDirectoryItems then
    for _, root in ipairs({ LEGACY_ROOT, LOGICAL_DIRECTORY }) do
      local ok, names = pcall(fs.getDirectoryItems, root)
      if ok then
        for _, name in ipairs(names or {}) do
          local called, did = pcall(fs.remove, root .. "/" .. name)
          if called and did ~= false then
            removed = removed + 1
          end
        end
      end
    end
  end
  ramFiles, ramDirty, ramBytes, ramRejected = {}, {}, 0, {}
  return removed
end

return Disk
