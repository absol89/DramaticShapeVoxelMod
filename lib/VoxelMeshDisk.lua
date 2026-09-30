-- Persistent raw voxel-mesh streams.
--
-- LOVE Mesh objects are driver/session resources and cannot survive a restart.
-- The six-float vertex streams which create them can: cache those under the
-- save directory, then upload them cooperatively next session instead of
-- rerunning Structures and the terrain carve.
--
-- Every read fails open. Missing, truncated, corrupt, or version-incompatible
-- files are ignored and the ordinary mesher rebuilds them. Geometry/config
-- identity lives in the cache path, while the fixed BAVC header only owns the
-- binary stream format and CACHE_REVISION. Old FORMAT 2 files keep their exact
-- embedded fingerprint as a read-only migration guard so an existing world
-- precache can be reused without letting a different visual variant borrow it.

local V = ...
local traceOK, CacheTrace = pcall(V.require, "CacheTrace")
if not traceOK or type(CacheTrace) ~= "table" or type(CacheTrace.log) ~= "function" then
  CacheTrace = { log = function() end }
end

local Budget = V.require("BuildBudget")
local Timings = V.require("LoadTimings")
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
local sessionOnly = false
local retainGenerated = false
local ramDirty, ramRejected, ramGenerated = {}, {}, {}
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
  pcall(function() collectgarbage("collect") end)
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
-- Revision 31 adds explicit rear entrances, clean rear facades, cave exit
-- portals and hanging scrolls while retaining the current disk-record layout.
-- Revision 32 rejects stale lower-floor cave records. Revision 33 also routes
-- the raised walkable CAVERN shelf through dirt. Revision 34 darkens only the
-- dirt vertex response while preserving the approved walls and grain layout.
-- TEST66 keys that work behind the opt-in CAVES setting, so Battle Art and
-- Legendary Visuals can never reuse one another's derived cave meshes.
-- Revision 35 seals the natural cave facets against a continuous rock backing.
-- Revision 36 extends each terrain record with the small suppressible-visual
-- streams and Legendary placement registry that were previously session-only.
-- Cached terrain can now restore signs, trees and pillars without rerunning the
-- complete Structures/terrain pipeline at every cold map crossing.
-- Revision 37 combines these streams with upstream prop spans, restored
-- ladders and museum/Safari geometry. Neither parent cache is reusable.
Disk.CACHE_REVISION = 37
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
local LEGACY_FORMAT = 2
local FORMAT = 3
local VARIANT_PREFIX = "variant-"
local VARIANT_PATTERN = "variant%-%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x"
local RAW_CHUNK = 1024 * 1024

local function available()
  return not (sessionActive and sessionOnly and not retainGenerated)
    and (storage ~= nil or sessionActive)
    and love and love.data and love.data.pack and love.data.unpack
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
  local id, product, variant = tail:match("^([^/]+)/([^/]+)/([^/]+)$")
  if not id then id, product = tail:match("^([^/]+)/([^/]+)$") end
  if not id then return nil end
  if variant and not variant:match("^" .. VARIANT_PATTERN .. "$") then
    return nil
  end
  local variantSuffix = variant and ("." .. variant) or ""
  -- The aux payload was renamed to "deco" on disk (Windows reserved-name fix,
  -- 1.7.4/potato_voxel), but the legacy FFI filesystem still stores it as
  -- ".aux.bavc". Accept both so legacy engines (<= 0.1.83) can read AND write
  -- the aux segment instead of failing on an unknown "deco" product.
  if product == "aux" or product == "deco" then
    return LEGACY_ROOT .. "/" .. id .. ".aux" .. variantSuffix .. ".bavc"
  end
  if product == "full-terrain" then
    return LEGACY_ROOT .. "/" .. id .. ".full.terrain" .. variantSuffix .. ".bavc"
  end
  if product == "body-terrain" then
    return LEGACY_ROOT .. "/" .. id .. ".body.terrain" .. variantSuffix .. ".bavc"
  end
  if product:match("^tree%-%w[%w_-]*%-%w[%w_-]*$") then
    return LEGACY_ROOT .. "/" .. id .. "." .. product .. variantSuffix .. ".bavc"
  end
  return nil
end

local function legacyKey(name)
  local id, variant = name:match("^(.-)%.aux%.(" .. VARIANT_PATTERN .. ")%.bavc$")
  if id and #variant == #VARIANT_PREFIX + 16 then
    return LOGICAL_DIRECTORY .. "/" .. id .. "/deco/" .. variant
  end
  id, variant = name:match("^(.-)%.full%.terrain%.(" .. VARIANT_PATTERN .. ")%.bavc$")
  if id and #variant == #VARIANT_PREFIX + 16 then
    return LOGICAL_DIRECTORY .. "/" .. id .. "/full-terrain/" .. variant
  end
  id, variant = name:match("^(.-)%.body%.terrain%.(" .. VARIANT_PATTERN .. ")%.bavc$")
  if id and #variant == #VARIANT_PREFIX + 16 then
    return LOGICAL_DIRECTORY .. "/" .. id .. "/body-terrain/" .. variant
  end
  local treeId, product, treeVariant = name:match(
    "^(.-)%.(tree%-%w[%w_-]*%-%w[%w_-]*)%.(" .. VARIANT_PATTERN .. ")%.bavc$")
  if treeId and product and treeVariant and #treeVariant == #VARIANT_PREFIX + 16 then
    return LOGICAL_DIRECTORY .. "/" .. treeId .. "/" .. product .. "/" .. treeVariant
  end
  id = name:match("^(.-)%.aux%.bavc$")
  if id then return LOGICAL_DIRECTORY .. "/" .. id .. "/deco" end
  id = name:match("^(.-)%.full%.terrain%.bavc$")
  if id then return LOGICAL_DIRECTORY .. "/" .. id .. "/full-terrain" end
  id = name:match("^(.-)%.body%.terrain%.bavc$")
  if id then return LOGICAL_DIRECTORY .. "/" .. id .. "/body-terrain" end
  treeId, product = name:match("^(.-)%.(tree%-.+)%.bavc$")
  if treeId and product then
    return LOGICAL_DIRECTORY .. "/" .. treeId .. "/" .. product
  end
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
  local merged = {
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
  if type(primary.delete) == "function" then
    merged.delete = function(_, key) return primary:delete(key) end
  end
  return merged
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
  local primary = {
    list = function(_, prefix) return api:list(scope, prefix) end,
    readBytes = function(_, key) return api:readBytes(scope, key) end,
    writeBytes = function(_, key, bytes)
      return api:writeBytes(scope, key, bytes)
    end,
  }
  if type(api.delete) == "function" then
    primary.delete = function(_, key) return api:delete(scope, key) end
  end
  storage = mergeLegacyReads(primary)
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
  local function clearProbe()
    if type(store.delete) == "function" then
      local ok, did = pcall(store.delete, store, probe)
      if ok and did == true then return end
    end
    pcall(store.writeBytes, store, probe, "")
  end
  local ok, wrote = pcall(store.writeBytes, store, probe, sentinel)
  if not ok or wrote ~= true then
    clearProbe()
    return false
  end
  local rok, got = pcall(store.readBytes, store, probe)
  clearProbe()
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
  local mapId = tostring(map.id or ""):upper()
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
  if mapId=='CELADON_CITY' and tileset.id=='OVERWORLD'
      and (kind=='terrain'or kind=='aux') and V.require('CommunityVisuals').referenceBuildings()then
    parts[#parts+1]='celadon-luxury-casino-exteriors-120'
    if kind=='terrain' then parts[#parts+1]='celadon-neon-marquee-122' end
  end
  if (mapId=='PEWTER_CITY'or mapId=='CERULEAN_CITY')and(kind=='terrain'or kind=='aux')
      and tileset.id=='OVERWORLD'and(V.require('CommunityVisuals').customRoads()or V.require('CommunityVisuals').referenceBuildings())then
    parts[#parts+1]='mineral-waterfront-polish-111'
  end
  if (kind=='terrain'or kind=='aux') and V.require('ForestTrees').enabled(map,V.require('CommunityVisuals').customForest())then
    parts[#parts+1]='forest-readable-floor-94'
  end
  if (kind=='terrain'or kind=='aux') and V.require('ForestTrees').enabled(map,V.require('CommunityVisuals').customForest())then
    parts[#parts+1]=V.require('ForestTrees').REVISION..':'..V.require('ForestTrees').detail(V.require('CommunityVisuals').treeDetailLevel())
  end
  if (kind=='terrain'or kind=='aux') and mapId=='CERULEAN_CITY'
      and V.require('CommunityVisuals').customRoads() and tileset.id=='OVERWORLD'then
    parts[#parts+1]='cerulean-bridge-arrival-clear-92'
  end
  if (kind=='terrain'or kind=='aux') and mapId=='FUCHSIA_CITY'
      and V.require('CommunityVisuals').customRoads() and tileset.id=='OVERWORLD'then
    parts[#parts+1]='safari-entrance-clear-108'
  end
  if kind=='terrain' and mapId=='CINNABAR_ISLAND'
      and V.require('CommunityVisuals').customRoads() and tileset.id=='OVERWORLD'then
    parts[#parts+1]='cinnabar-clear-dock-alley-92'
    parts[#parts+1]='cinnabar-natural-bed-124'
  end
  if kind=='terrain' and V.require('CinnabarCoast').enabled(mapId,
      V.require('CommunityVisuals').customRoads(),tileset.id) then
    parts[#parts+1]='cinnabar-coastal-furniture-91'
  end
  if kind=='terrain' and V.require('VermilionHarbor').enabled(mapId,
      V.require('CommunityVisuals').customRoads(),tileset.id) then
    parts[#parts+1]='vermilion-courtyard-edge-60'
  end
  if mapId=='ROUTE_24' and V.require('CommunityVisuals').customRoads() then parts[#parts+1]='cerulean-bridge-89' end
  if mapId=='ROUTE_17' and V.require('CommunityVisuals').customSigns() then parts[#parts+1]='cycling-information-islands-89' end
  -- Only the generic OVERWORLD road fallback changed. Bespoke city/trail
  -- builders retain their existing cache families and accepted geometry.
  if kind=='terrain' and tileset.id=='OVERWORLD'
      and V.require('CommunityVisuals').customRoads()
      and mapId~='CELADON_CITY' and mapId~='ROUTE_11'
      and not V.require('VermilionHarbor').enabled(mapId,true,tileset.id)
      and not V.require('CinnabarCoast').enabled(mapId,true,tileset.id) then
    parts[#parts+1]='legendary-light-cobble-86'
  end
  if V.require('CityStreets').themes[mapId] and V.require('CommunityVisuals').referenceBuildings() then
    parts[#parts+1]='city-facade-detail-89'
    if mapId=='PEWTER_CITY' or mapId=='FUCHSIA_CITY' or mapId=='VIRIDIAN_CITY'then parts[#parts+1]='landmark-legibility-91'end
  end
  if mapId=='CINNABAR_ISLAND' and V.require('CommunityVisuals').referenceBuildings() then
    parts[#parts+1]='cinnabar-facade-detail-91'
  end
  if kind=='terrain' and (mapId=='ROUTE_20' or mapId=='ROUTE_21') and V.require('CommunityVisuals').customRoads() then
    parts[#parts+1]='coastal-shore-plants-90'
  end
  if (kind=='terrain' or kind=='aux') and V.require('CityStreets').enabled(mapId,
      V.require('CommunityVisuals').customRoads(),tileset.id) then
    parts[#parts+1]='legendary-town-gardens-90'
    if mapId~='SAFFRON_CITY' and mapId~='ROUTE_17'then parts[#parts+1]='regional-detail-91'end
  end
  if kind=='terrain' and mapId=='CELADON_CITY' then
    parts[#parts+1]='celadon-light-cobble-86'
  end
  if kind=='terrain' and tileset.id=='OVERWORLD' and mapId=='ROUTE_11' and V.require('CommunityVisuals').customRoads() then
    parts[#parts+1]='route11-taller-sprouts-53'
  end
  if tileset.id=='OVERWORLD' or tileset.id=='FOREST' or tileset.id=='PLATEAU' then
    parts[#parts+1]='kanto-architecture-62:'..V.require('CommunityVisuals').buildings:get()
  end
  if tileset.id=='OVERWORLD' and V.require('CommunityVisuals').customCourtyards() then
    parts[#parts+1]='community-timber-metal-fence-47'
  end
  -- PR51 changed shrub vertices/UVs; only Safari needs its meshes rebuilt.
  if map.id=='SAFARI_ZONE_CENTER' or map.id=='SAFARI_ZONE_EAST'
      or map.id=='SAFARI_ZONE_NORTH' or map.id=='SAFARI_ZONE_WEST' then
    parts[#parts + 1] = "safari-canopy-source-shading-v1"
    if kind=="terrain" or kind=="aux" then
      parts[#parts+1]=V.require("SafariReserve").REVISION..":"..tostring(V.require("SafariReserve").enabled(map))..":"..V.require("CommunityVisuals").treeDetailLevel()
    end
  end
  -- Community visuals are real geometry/UV inputs. Keep each choice in the
  -- canonical fingerprint so a DEFAULT cache can never be reused for custom
  -- trees/fences/pillars (or vice versa), while every default remains the
  -- creator's original cache family.
  local CommunityVisuals = V.require("CommunityVisuals")
  if kind == "terrain" and tileset.id == "OVERWORLD"
      and (CommunityVisuals.customRoads() or CommunityVisuals.customGrass()
        or (mapId == "LAVENDER_TOWN" and CommunityVisuals.customCityGround())) then
    parts[#parts + 1] = "rollback16-decor-water-wood-grass"
  end
  if kind == "terrain" and tileset.id == "OVERWORLD" and mapId == "LAVENDER_TOWN"
      and (CommunityVisuals.customCityGround() or CommunityVisuals.customRoads()) then
    parts[#parts + 1] = "lavender-ambiance-20"
  end
  if kind == "terrain" and tileset.id == "OVERWORLD" and CommunityVisuals.customRoads() then
    parts[#parts + 1] = "walkpath19-dock-emission21"
  end
  if kind == "terrain" and tileset.id == "OVERWORLD" then
    local city=CommunityVisuals.isCityGroundMap(map)
    if CommunityVisuals.customRoads()
        or (city and CommunityVisuals.customCityGround())
        or (not city and CommunityVisuals.customGrass()) then
      parts[#parts + 1] = "grass-base-deck-grain-22"
    end
  end
  if tileset.id=="OVERWORLD" then
    local city=CommunityVisuals.isCityGroundMap(map)
    local grass=(city and CommunityVisuals.customCityGround()) or (not city and CommunityVisuals.customGrass())
    if kind=="terrain" and (CommunityVisuals.customRoads() or CommunityVisuals.customWalls()) then
      parts[#parts+1]="dock-masonry-23"
    elseif kind=="aux" and grass then parts[#parts+1]="grass-variation-23" end
  end
  -- Final contract: brick courses, bridge boards, crown-lock and the
  -- grain-mapped TEST435 fence must never reuse an older community mesh.
  parts[#parts + 1] = "legendary-visuals-final"
  parts[#parts + 1] = "interiors56"
  parts[#parts + 1] = CommunityVisuals.casino:get()
  parts[#parts + 1] = CommunityVisuals.prizeRoom:get()
  parts[#parts + 1] = CommunityVisuals.tunnels:get()
  parts[#parts + 1] = CommunityVisuals.rocket:get()
  parts[#parts + 1] = CommunityVisuals.elevator:get()

  parts[#parts + 1] = CommunityVisuals.layout()
  parts[#parts + 1] = CommunityVisuals.trees:get()
  parts[#parts + 1] = CommunityVisuals.forest:get()
  if CommunityVisuals.customForest() then
    parts[#parts + 1] = "viridian-finished-ring-and-varied-boulders-v2"
  end
  parts[#parts + 1] = CommunityVisuals.cutTrees:get()
  parts[#parts + 1] = CommunityVisuals.signs:get()
  -- TEST83 changes only the opted-in Legendary sign support geometry.  Name
  -- that contract directly instead of invalidating Battle Art/default maps
  -- with a global cache-revision bump.
  if mapId:match("^ROCKET_HIDEOUT_B[1-4]F$") or mapId=="ROCKET_HIDEOUT_ELEVATOR" then parts[#parts+1]="rocket6-elevator-steel-cabin" end
  if CommunityVisuals.customSigns() then
    if mapId=="LAVENDER_TOWN" then parts[#parts+1]="lavender-tower-sign-north-v1" end
    parts[#parts + 1] = "kanto-wayfinder-viridian-v6"
    parts[#parts + 1] = "sign-labels"
    for _, sign in ipairs(def.signs or {}) do
      parts[#parts + 1] = tostring(sign.x)
      parts[#parts + 1] = tostring(sign.y)
      parts[#parts + 1] = tostring(sign.text)
    end
  end
  if mapId:match("^UNDERGROUND_PATH_") then parts[#parts+1]="underground1-stone-shell" end
  if mapId=="GAME_CORNER_PRIZE_ROOM" then parts[#parts+1]="prizes1-redemption-room" end
  if mapId=="GAME_CORNER" then parts[#parts+1]="casino4-jackpot-poster" end
  local cityGroundMap = CommunityVisuals.isCityGroundMap(map)
  -- CITY GROUND fully owns Lavender/Fuchsia turf. The broad GRASS row is not
  -- a geometry/material input there, so do not create redundant city cache
  -- variants when a player changes route grass independently. Route 10 is not
  -- a city map and still follows GRASS.
  if not cityGroundMap then parts[#parts + 1] = CommunityVisuals.grass:get() end
  if kind == "aux" then
    -- TEST138 removes only exposed east tile-boundary caps while preserving
    -- every camera-safe interior cap and crossed centre card. Force a clean
    -- auxiliary mesh rebuild so TEST137's rigid field-edge strips cannot be
    -- reused from disk.
    parts[#parts + 1] = "closed-tall-grass-v5-east-edge-softened"
  end
  if mapId:match("^UNDERGROUND_PATH_") then parts[#parts+1]="tunnels3-exclusive-stairs-closed-corners" end
  if mapId == "ROUTE_10" then
    -- The final eleven block rows share the cave-to-Lavender treatment.
    -- The Tower lawn is body geometry and the baseline flowerbed lives in AUX.
    parts[#parts + 1] = "route10-lavender-approach-v3-exit-lawn"
    parts[#parts+1]="legendary-garden7-matched-apron"
    parts[#parts+1]=CommunityVisuals.cityGround:get()
    if kind == "aux" then
      parts[#parts + 1] = "route10-tower-flowerbed-v2-baseline"
    end
  end
  parts[#parts + 1] = CommunityVisuals.roads:get()
  if tileset.id=="OVERWORLD" then parts[#parts+1]="ember106-wall4-ground2-edge1" end
  if cityGroundMap then
    parts[#parts + 1] = "city-ground-ember106-v1"
    if mapId=="LAVENDER_TOWN" then parts[#parts+1]=CommunityVisuals.towerWallStyle() end
    parts[#parts + 1] = CommunityVisuals.cityGround:get()
    if mapId == "LAVENDER_TOWN" then
      -- Battle Art now snapshots the current Legendary Lavender lawn/path
      -- treatment too. Invalidate the prior default-mode sandy city body so
      -- an old persistent mesh cannot make the parity fix appear to do nothing.
      parts[#parts + 1] = "lavender-battle-parity-v5"
      -- TOWER VISUALS now suppresses the stock exterior building quads. Keep
      -- Battle Art and Legendary body caches distinct so neither silhouette
      -- can be resurrected from persistent storage after switching modes.
      parts[#parts + 1] = "legendary-tower-exterior-v1"
      parts[#parts + 1] = CommunityVisuals.tower:get()
    end
  end
  if mapId:match("^POKEMON_TOWER_[1-7]F$") then
    parts[#parts + 1] = "pokemon-tower-stone-v14-master-wall-blue-void"
    parts[#parts + 1] = CommunityVisuals.tower:get()
    parts[#parts + 1] = CommunityVisuals.towerWallStyle()
  end
  parts[#parts + 1] = CommunityVisuals.walls:get()
  parts[#parts + 1] = CommunityVisuals.courtyards:get()
  -- TEST65 keeps TEST64's all-walkable dirt routing and dense grain, but uses
  -- a deeper earth palette and lower floor-only light response.
  if tileset.id == "CAVERN" or def.tileset == "CAVERN" then
    parts[#parts + 1] = CommunityVisuals.caves:get()
    parts[#parts + 1] = "cave-geological-strata-v10-dark-dirt"
  end
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

-- Stable 64-bit textual identity for one canonical geometry fingerprint.
-- Two pure-arithmetic FNV-1a lanes avoid depending on love.data.hash/bit ops,
-- which are intentionally absent from several supported headless/test builds.
-- This is a lookup key, not a corruption checksum: the fixed BAVC header below
-- owns stream compatibility and the body parser still owns structural safety.
local HASH_PRIME = 16777619
local HASH_LANE_A, HASH_LANE_B = 2166136261, 2654435769
local XOR4 = {}
for a = 0, 15 do
  XOR4[a] = {}
  for b = 0, 15 do
    local x, y, r = a, b, 0
    for place = 0, 3 do
      if x % 2 ~= y % 2 then r = r + 2 ^ place end
      x, y = math.floor(x / 2), math.floor(y / 2)
    end
    XOR4[a][b] = r
  end
end

local function xor8(a, b)
  return XOR4[math.floor(a / 16)][math.floor(b / 16)] * 16
       + XOR4[a % 16][b % 16]
end

local function hashStep(h, byte)
  local lo = h % 65536
  local hi = (h - lo) / 65536
  lo = lo - lo % 256 + xor8(lo % 256, byte)
  return (lo * HASH_PRIME + (hi * HASH_PRIME % 65536) * 65536) % 4294967296
end

local function variantId(fp)
  local a, b = HASH_LANE_A, HASH_LANE_B
  fp = tostring(fp or "")
  for i = 1, #fp do
    local byte = fp:byte(i)
    a = hashStep(a, byte)
    b = hashStep(b, byte)
  end
  return ("%08x%08x"):format(a, b)
end

Disk.variantId = variantId

local function basePathFor(map, slot, kind)
  local suffix = kind == "aux" and kindSegment(kind)
                 or (tostring(slot) .. "-terrain")
  return Disk.DIRECTORY .. "/" .. safeId(map.id) .. "/" .. suffix
end

local function variantPath(base, fp)
  return base .. "/" .. VARIANT_PREFIX .. variantId(fp)
end

local function pathFor(map, slot, kind, fp)
  return variantPath(basePathFor(map, slot, kind), fp)
end

-- TEST97 persists the already-expanded mature-tree triangle streams beside
-- the terrain containers.  Keep each current/neighbor placement signature in
-- its own path: a map's FULL owner can suppress trees beneath connected map
-- bodies while the same map drawn as a neighbour must keep its complete body.
local TREE_MATERIALS = { "trunks", "stones", "hoods", "detail", "shadows" }
local function treeBasePath(map, recipe, signature)
  return Disk.DIRECTORY .. "/" .. safeId(map.id) .. "/tree-"
         .. safeId(recipe) .. "-" .. safeId(signature)
end

local function treeFingerprint(map, recipe, signature)
  return Disk.fingerprint(map, "body", nil, "trees")
         .. "|tree-stream-v2-sections-lod|recipe|" .. tostring(recipe)
         .. "|placement|" .. tostring(signature)
end

local function treePath(map, recipe, signature, fp)
  return variantPath(treeBasePath(map, recipe, signature), fp)
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
  ramGenerated[path] = nil
  if rejected then ramRejected[path] = true end
end

local function rejectBody(map, path, detail)
  detail = tostring(detail or "malformed BAVC payload")
  CacheTrace.log("reject-cache-body", map and map.id, path .. " " .. detail)
  StaticGeometry.record(map and map.id, "cache.record", path, detail)
  discard(path, true)
  return nil
end

local function header()
  return MAGIC .. u32(FORMAT) .. u32(Disk.CACHE_REVISION)
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
    -- FORMAT 3 adds /variant-<digest> after the readable product. Priority is
    -- still a property of map/product, never of which visual variant it is.
    local id, product = tail:match("^([^/]+)/([^/]+)")
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
  if (sessionActive and sessionOnly) or not storage or not available() then
    return {}, 0
  end
  local names, bytes = {}, 0
  local ok, listed = pcall(storage.list, storage, Disk.DIRECTORY)
  if not ok then return names, bytes end
  -- A path hash identifies the exact geometry variant, but the title screen
  -- intentionally does not load/instantiate every map merely to recompute all
  -- active hashes. If one map/product has multiple retained variants (for
  -- example OFF and FULL, or an older cache revision), preloading an arbitrary
  -- lexical one would waste the finite RAM budget and FULL would multiply RAM
  -- use indefinitely. Preload only unambiguous groups; ambiguous groups stay on
  -- disk until gameplay requests its exact variant, which is then retained in
  -- the ordinary session RAM mirror.
  local groups = {}
  for _, key in ipairs(listed or {}) do
    if key:sub(1, #Disk.DIRECTORY + 1) == Disk.DIRECTORY .. "/" then
      local base = key:match("^(.-)/" .. VARIANT_PATTERN .. "$")
                   or key
      local group = groups[base]
      if not group then group = {}; groups[base] = group end
      group[#group + 1] = key
    end
  end
  for _, group in pairs(groups) do
    if #group == 1 then
      local key = group[1]
      names[#names + 1] = key
      local held = ramFiles[key]
      bytes = bytes + (held and #held or knownSizes[key] or 0)
    end
  end
  Disk.orderRamNames(names, priority)
  return names, bytes
end

-- OFF drops every compressed record. LIVE CACHE explicitly retains generated
-- records, but never preloads from disk. No filesystem calls or full GC here.
function Disk.setSessionOnly(enabled, keepGenerated)
  enabled, keepGenerated = enabled == true, keepGenerated == true
  if sessionOnly == enabled and retainGenerated == keepGenerated then return false end
  sessionOnly, retainGenerated = enabled, keepGenerated
  if enabled then
    for path in pairs(ramFiles) do
      if not retainGenerated or not ramGenerated[path] then discard(path) end
    end
  end
  return true
end

function Disk.beginSession(ramOnly, keepGenerated)
  sessionActive = true
  if ramOnly ~= nil then Disk.setSessionOnly(ramOnly, keepGenerated) end
end

function Disk.beginPrecache()
  ramFiles, ramDirty, ramRejected, ramGenerated = {}, {}, {}, {}
  ramBytes = 0
  sessionActive = false
  diskGc()
end

function Disk.loadIntoRam(name)
  if not sessionActive or sessionOnly or not storage or type(name) ~= "string"
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
  ramFiles, ramDirty, ramRejected, ramGenerated = {}, {}, {}, {}
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

local function reportMismatch(map, path, info, expected)
  info = info or { kind = "header", detail = "invalid BAVC header" }
  local detail = info.detail
  if info.kind == "variant" then
    detail = "legacy variant mismatch: " .. fingerprintDifference(info.actual, expected)
  end
  detail = detail or "invalid BAVC header"
  local event = info.kind == "variant" and "reject-variant"
             or info.kind == "revision" and "reject-cache-version"
             or "reject-cache-header"
  CacheTrace.log(event, map and map.id, path .. " " .. detail)
  StaticGeometry.record(map and map.id, "cache.record", path, detail)
end

-- FORMAT 3 has a fixed compatibility header: magic, stream format, geometry
-- revision. The exact visual/config fingerprint is intentionally absent; its
-- digest selects the physical cache variant instead. FORMAT 2 is accepted only
-- from the old flat path and still requires its embedded fingerprint to match.
local function parseHeader(blob, expected, allowLegacy)
  if not blob or #blob < 8 then
    return nil, { kind = "header", detail = "truncated BAVC header" }
  end
  if blob:sub(1, 4) ~= MAGIC then
    return nil, { kind = "header", detail = "invalid BAVC magic" }
  end
  local format = readU32(blob, 5)
  if format == FORMAT then
    if allowLegacy then
      return nil, { kind = "format", detail =
        "FORMAT 3 cache record requires a variant-specific path" }
    end
    if #blob < 12 then
      return nil, { kind = "header", detail = "truncated BAVC version header" }
    end
    local revision = readU32(blob, 9)
    if revision ~= Disk.CACHE_REVISION then
      return nil, { kind = "revision", detail =
        ("unsupported cache revision %s (expected %d)"):format(
          tostring(revision), Disk.CACHE_REVISION) }
    end
    return 13, { format = format, revision = revision }
  end
  if format == LEGACY_FORMAT and allowLegacy then
    if #blob < 12 then
      return nil, { kind = "header", detail = "truncated legacy BAVC header" }
    end
    local n = readU32(blob, 9)
    if not n or n <= 0 or 12 + n > #blob then
      return nil, { kind = "header", detail = "invalid legacy fingerprint header" }
    end
    local first = 13
    local actual = blob:sub(first, first + n - 1)
    if actual ~= expected then
      return nil, { kind = "variant", actual = actual, format = format }
    end
    return first + n, { format = format, actual = actual, legacy = true }
  end
  return nil, { kind = "format", detail =
    ("unsupported BAVC format %s (expected %d)"):format(tostring(format), FORMAT) }
end

-- Cheap resume probe for the title-screen whole-game generator.  Reading and
-- decompressing a 20+ MiB route merely to learn that it is already cached
-- would make "resume" nearly as expensive as generating it. New records need
-- only their fixed version header; a FORMAT 2 fallback additionally checks its
-- embedded fingerprint. The ordinary load path still validates every stream.
local function probeHeader(path, expected, map, allowLegacy)
  if not available() then return false, "cache backend unavailable" end
  local ok, blob = true, ramFiles[path]
  if not blob then
    if (sessionActive and sessionOnly) or not storage then
      return false, "record not generated this session"
    end
    ok, blob = pcall(storage.readBytes, storage, path)
  end
  if not ok then return false, "read error: " .. tostring(blob) end
  if type(blob) ~= "string" or #blob == 0 then
    return false, "missing or empty cache record"
  end
  knownSizes[path] = #blob
  local pos, info = parseHeader(blob, expected, allowLegacy)
  if pos then
    -- Keep resume cheap while rejecting obviously truncated containers. Terrain
    -- and AUX have two empty streams plus their metadata/spans (28 bytes min);
    -- an empty tree section needs its four counters plus part count (20 bytes).
    local minimum = path:find("/tree-", 1, true) and 20 or 28
    if #blob - pos + 1 < minimum then
      local detail = ("truncated BAVC payload (%d bytes, need at least %d)"):
        format(math.max(0, #blob - pos + 1), minimum)
      CacheTrace.log("reject-cache-body", map and map.id, path .. " " .. detail)
      StaticGeometry.record(map and map.id, "cache.record", path, detail)
      return false, detail, true
    end
    return true, nil, true
  end
  reportMismatch(map, path, info, expected)
  local detail = info and info.detail
  if info and info.kind == "variant" then
    detail = "legacy variant mismatch: " .. fingerprintDifference(info.actual, expected)
  end
  return false, detail or "invalid BAVC header", true
end

local function headerMatches(path, legacyPath, expected, map)
  local matched, err, existed = probeHeader(path, expected, map, false)
  if matched then return true end
  local legacyMatched, legacyErr, legacyExisted =
    probeHeader(legacyPath, expected, map, true)
  if legacyMatched then return true end
  if existed then return false, err, path end
  if legacyExisted then return false, legacyErr, legacyPath end
  return false, err or legacyErr or "missing or empty cache record", path
end

-- Whether one map/slot has both persistent products the renderer will ask
-- for: shared grass/flower/figure data and its terrain+water stream.
function Disk.complete(map, bodyOnly, masks)
  if not map or not Disk.staticEligible(map) then return false end
  local slot = bodyOnly and "body" or "full"
  local auxFp = Disk.fingerprint(map, "aux", nil, "aux")
  local terrainFp = Disk.fingerprint(map, slot, masks, "terrain")
  local auxBase = basePathFor(map, "aux", "aux")
  local terrainBase = basePathFor(map, slot, "terrain")
  return headerMatches(variantPath(auxBase, auxFp), auxBase, auxFp, map)
     and headerMatches(variantPath(terrainBase, terrainFp), terrainBase,
                       terrainFp, map)
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
  local auxFp = Disk.fingerprint(map, "aux", nil, "aux")
  local terrainFp = Disk.fingerprint(map, slot, masks, "terrain")
  local auxBase = basePathFor(map, "aux", "aux")
  local terrainBase = basePathFor(map, slot, "terrain")
  local checks = {
    { kind = "deco", path = variantPath(auxBase, auxFp),
      legacyPath = auxBase, fp = auxFp },
    { kind = slot .. "-terrain", path = variantPath(terrainBase, terrainFp),
      legacyPath = terrainBase, fp = terrainFp },
  }
  local failures = {}
  for _, check in ipairs(checks) do
    local matched, err, failedPath =
      headerMatches(check.path, check.legacyPath, check.fp, map)
    if not matched then
      failures[#failures + 1] = {
        kind = check.kind, path = failedPath or check.path,
        physical = physicalPath(failedPath or check.path), error = err,
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
                aux = 0, full = 0, body = 0, trees = 0 }
  if not storage or not available() then return out end
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
      local id, product = name:match("^([^/]+)/([^/]+)")
      if id and (product == "deco" or product == "aux"
          or product == "full-terrain" or product == "body-terrain"
          or product:match("^tree%-.+$")) then maps[id] = true end
      if product == "deco" or product == "aux" then
        out.aux = out.aux + 1
      elseif product == "full-terrain" then
        out.full = out.full + 1
      elseif product == "body-terrain" then
        out.body = out.body + 1
      elseif product and product:match("^tree%-.+$") then
        out.trees = out.trees + 1
      end
    end
  end
  for _ in pairs(maps) do out.maps = out.maps + 1 end
  return out
end

local function streamRecord(blob, pos, yieldFn)
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
    if yieldFn then yieldFn() end
  end
  if total ~= expected or (expected == 0 and chunks ~= 0) then return nil end
  return { n = n, chunks = rawChunks }, pos
end

local function readCandidate(path, fp, map, allowLegacy)
  if not available() then
    CacheTrace.log("cache-unavailable", map and map.id, path)
    return nil
  end
  local blob = ramFiles[path]
  if blob then CacheTrace.log("ram-hit", map and map.id, path) end
  if not blob then
    if (sessionActive and sessionOnly) or not storage then CacheTrace.log("cache-policy-skip", map and map.id, path); return nil end
    if sessionActive and ramRejected[path] then CacheTrace.log("cache-rejected-session", map and map.id, path); return nil end
    local ok, loaded = pcall(storage.readBytes, storage, path)
    if not ok or not loaded then CacheTrace.log("disk-miss", map and map.id, path); return nil end
    CacheTrace.log("disk-hit", map and map.id, path .. " bytes=" .. #loaded)
    blob = loaded
    knownSizes[path] = #blob
  end
  CacheTrace.log("cache-validate", map and map.id, path)
  local pos, info = parseHeader(blob, fp, allowLegacy)
  if not pos then
    reportMismatch(map, path, info, fp)
    -- A valid FORMAT 2 file with another fingerprint is another geometry
    -- variant, not corruption. Keep it available so switching back can use it.
    if not (info and info.kind == "variant") then discard(path, true) end
    return nil
  end
  if sessionActive and not ramFiles[path] then
    ramFiles[path] = blob
    ramBytes = ramBytes + #blob
  end
  return blob, pos, path
end

local function readValidated(path, legacyPath, fp, map)
  -- Existing FORMAT 2 precaches are commonly already in the CONTINUE RAM
  -- mirror. Avoid a pointless variant-path disk miss before using that held
  -- legacy record; otherwise always prefer the new variant-specific file.
  local triedLegacy = false
  if not ramFiles[path] and ramFiles[legacyPath] then
    triedLegacy = true
    local blob, pos, used = readCandidate(legacyPath, fp, map, true)
    if blob then return blob, pos, used end
  end
  local blob, pos, used = readCandidate(path, fp, map, false)
  if blob then return blob, pos, used end
  if triedLegacy then return nil end
  return readCandidate(legacyPath, fp, map, true)
end

-- Prop runs stored with a record: a u32 count, then four floats per run.
-- A precached map never runs the geometry pass, so without these the cut
-- fast path in ChunkMesher would never fire on one.
local function readSpans(blob, pos)
  local count = readU32(blob, pos)
  if not count or count > 1048576 then return nil end
  pos = pos + 4
  local spans = {}
  for _ = 1, count do
    if pos + 15 > #blob then return nil end
    local a, b, c, d, nextPos = love.data.unpack("<ffff", blob, pos)
    spans[#spans + 1] = a
    spans[#spans + 1] = b
    spans[#spans + 1] = c
    spans[#spans + 1] = d
    pos = nextPos
  end
  return spans, pos
end

local function decodeTerrainBlob(blob, pos, map, path)
  local terrain, nextPos = streamRecord(blob, pos)
  local water, visualPos
  if nextPos then water, visualPos = streamRecord(blob, nextPos) end
  local visualCount = visualPos and readU32(blob, visualPos) or nil
  if not terrain or not water or not visualCount or visualCount > 4096 then
    return rejectBody(map, path, "malformed terrain/water stream")
  end
  pos = visualPos + 4
  local visuals = {}
  for _ = 1, visualCount do
    local nameBytes = readU32(blob, pos)
    if not nameBytes or nameBytes == 0 or nameBytes > 4096
       or pos + 4 + nameBytes - 1 > #blob then
      return rejectBody(map, path, "malformed terrain visual name")
    end
    local id = blob:sub(pos + 4, pos + 3 + nameBytes)
    local stream, nextVisual = streamRecord(blob, pos + 4 + nameBytes)
    if not stream or visuals[id] then
      return rejectBody(map, path, "malformed or duplicate terrain visual stream")
    end
    visuals[id] = stream
    pos = nextVisual
  end
  local registryBytes = readU32(blob, pos)
  if not registryBytes or registryBytes > 8 * 1024 * 1024
     or pos + 4 + registryBytes - 1 > #blob then
    return rejectBody(map, path, "malformed placement registry")
  end
  local registry = blob:sub(pos + 4, pos + 3 + registryBytes)
  local finalPos = pos + 4 + registryBytes
  local spans
  spans, finalPos = readSpans(blob, finalPos)
  if not spans or finalPos ~= #blob + 1 then
    return rejectBody(map, path, "malformed terrain spans or trailing bytes")
  end
  return { terrain = terrain, water = water,
           visuals = visuals, registry = registry, spans = spans }
end

function Disk.loadTerrain(map, slot, masks)
  if not Disk.staticEligible(map) then return nil end
  local fp = Disk.fingerprint(map, slot, masks, "terrain")
  local legacyPath = basePathFor(map, slot, "terrain")
  local path = pathFor(map, slot, "terrain", fp)
  local blob, pos, usedPath = readValidated(path, legacyPath, fp, map)
  if not blob then return nil end
  usedPath = usedPath or path
  local decoded = decodeTerrainBlob(blob, pos, map, usedPath)
  if decoded or usedPath ~= path then return decoded end
  -- A compatible legacy record is still valuable if the preferred FORMAT 3
  -- container has a good header but a damaged body. The failed new variant was
  -- quarantined by rejectBody(), so retry only the exact-fingerprint flat file.
  local legacyBlob, legacyPos, legacyUsed =
    readCandidate(legacyPath, fp, map, true)
  if not legacyBlob then return nil end
  return decodeTerrainBlob(legacyBlob, legacyPos, map, legacyUsed or legacyPath)
end

local function float4(blob, pos)
  if pos + 15 > #blob then return nil end
  local a, b, c, d, nextPos = love.data.unpack("<ffff", blob, pos)
  return { a, b, c, d }, nextPos
end

local function decodeAuxBlob(blob, pos, map, path)
  local grass, p2 = streamRecord(blob, pos)
  local flowers, p3
  if p2 then flowers, p3 = streamRecord(blob, p2) end
  local count = p3 and readU32(blob, p3) or nil
  if not grass or not flowers or not count or count > 1024 then
    return rejectBody(map, path, "malformed auxiliary grass/flower stream")
  end
  pos = p3 + 4
  local figures = {}
  for _ = 1, count do
    local stream, nextPos = streamRecord(blob, pos)
    local meta, finalPos
    if nextPos then meta, finalPos = float4(blob, nextPos) end
    if not stream or not meta then
      return rejectBody(map, path, "malformed auxiliary figure stream")
    end
    stream.wx, stream.wz, stream.y, stream.w = meta[1], meta[2], meta[3], meta[4]
    figures[#figures + 1] = stream
    pos = finalPos
  end
  -- tuft and billboard runs, after the figures
  local grassSpans, afterGrass = readSpans(blob, pos)
  local flowerSpans, finalPos
  if afterGrass then flowerSpans, finalPos = readSpans(blob, afterGrass) end
  if not grassSpans or not flowerSpans or finalPos ~= #blob + 1 then
    return rejectBody(map, path, "malformed auxiliary spans or trailing bytes")
  end
  grass.spans, flowers.spans = grassSpans, flowerSpans
  return { grass = grass, flowers = flowers, figures = figures }
end

function Disk.loadAux(map)
  if not Disk.staticEligible(map) then return nil end
  local fp = Disk.fingerprint(map, "aux", nil, "aux")
  local legacyPath = basePathFor(map, "aux", "aux")
  local path = pathFor(map, "aux", "aux", fp)
  local blob, pos, usedPath = readValidated(path, legacyPath, fp, map)
  if not blob then return nil end
  usedPath = usedPath or path
  local decoded = decodeAuxBlob(blob, pos, map, usedPath)
  if decoded or usedPath ~= path then return decoded end
  local legacyBlob, legacyPos, legacyUsed =
    readCandidate(legacyPath, fp, map, true)
  if not legacyBlob then return nil end
  return decodeAuxBlob(legacyBlob, legacyPos, map, legacyUsed or legacyPath)
end

-- Load mature-tree sections as raw unindexed six-float streams.  GPU meshes
-- are deliberately reconstructed by CommunityFlora under its own four-ms
-- frame budget; a cache hit therefore avoids both the procedural crown build
-- and an unbounded upload on the render thread.
local function decodeTreeBlob(blob, pos, map, path, yieldFn)
  local treeCount = readU32(blob, pos)
  local treeN = treeCount and readU32(blob, pos + 4)
  local boulderN = treeN and readU32(blob, pos + 8)
  local cellCount = boulderN and readU32(blob, pos + 12)
  if not treeCount or not treeN or not boulderN or not cellCount
     or cellCount > 65536 then
    return rejectBody(map, path, "malformed tree section header")
  end
  pos = pos + 16
  local cells = {}
  for i = 1, cellCount do
    local meta, nextPos = float4(blob, pos)
    if not meta then return rejectBody(map, path, "malformed tree placement cell") end
    cells[#cells + 1] = {
      meta[1], meta[2], meta[3] == 1 and "b" or "t",
      meta[4] > -1e20 and meta[4] or nil,
    }
    pos = nextPos
    if yieldFn and i % 128 == 0 then yieldFn() end
  end
  local count = readU32(blob, pos)
  if not count or count > 4096 then
    return rejectBody(map, path, "malformed tree part count")
  end
  pos = pos + 4
  local parts = {}
  for _ = 1, count do
    local meta, nextPos = float4(blob, pos)
    if not meta then return rejectBody(map, path, "malformed tree part metadata") end
    pos = nextPos
    local flags, farCount = readU32(blob, pos), readU32(blob, pos + 4)
    if not flags or flags > 1 or not farCount then
      return rejectBody(map, path, "malformed tree part flags")
    end
    pos = pos + 8
    local part = { x = meta[1], y = meta[2], z = meta[3], radius = meta[4],
                   apron = flags == 1, detailFarCount = farCount }
    for _, name in ipairs(TREE_MATERIALS) do
      local stream
      stream, pos = streamRecord(blob, pos, yieldFn)
      if not stream then
        return rejectBody(map, path, "malformed tree material stream " .. name)
      end
      part[name] = stream
    end
    parts[#parts + 1] = part
    if yieldFn then yieldFn() end
  end
  if pos ~= #blob + 1 then
    return rejectBody(map, path, "malformed tree trailing bytes")
  end
  return { parts = parts, count = treeCount, tN = treeN, bN = boulderN,
           cells = cells }
end

function Disk.loadTreeParts(map, recipe, signature, yieldFn)
  if not Disk.staticEligible(map) then return nil end
  local fp = treeFingerprint(map, recipe, signature)
  local legacyPath = treeBasePath(map, recipe, signature)
  local path = treePath(map, recipe, signature, fp)
  local blob, pos, usedPath = readValidated(path, legacyPath, fp, map)
  if not blob then return nil end
  usedPath = usedPath or path
  local decoded = decodeTreeBlob(blob, pos, map, usedPath, yieldFn)
  if decoded or usedPath ~= path then return decoded end
  local legacyBlob, legacyPos, legacyUsed =
    readCandidate(legacyPath, fp, map, true)
  if not legacyBlob then return nil end
  return decodeTreeBlob(legacyBlob, legacyPos, map,
                        legacyUsed or legacyPath, yieldFn)
end

local function write(file, bytes) file:write(bytes) end

local function writeChunked(file, record, yieldFn)
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
      if yieldFn then yieldFn() end
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
    if yieldFn then yieldFn() end
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
  ramGenerated[path] = true
  ramRejected[path] = nil
end

local function encoded(fp, writer)
  local parts = {}
  local sink = {}
  function sink:write(bytes)
    parts[#parts + 1] = bytes
    return true
  end
  write(sink, header())
  writer(sink)
  return table.concat(parts)
end

local function writeFile(path, fp, writer)
  -- OFF does not even encode a throwaway compressed copy of live GPU geometry.
  if sessionActive and sessionOnly and not retainGenerated then return true end
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
  if not storage or not available() then
    return false, 0, 0, { "cache API unavailable" }
  end
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

local function writeSpans(file, spans)
  local count = math.floor(#(spans or {}) / 4)
  write(file, u32(count))
  for i = 1, count * 4, 4 do
    write(file, love.data.pack("string", "<ffff",
                               spans[i], spans[i + 1],
                               spans[i + 2], spans[i + 3]))
  end
end

function Disk.saveTerrain(map, slot, masks, terrain, water, visuals, registry)
  if not Disk.staticEligible(map) then return false end
  local fp = Disk.fingerprint(map, slot, masks, "terrain")
  local path = pathFor(map, slot, "terrain", fp)
  return writeFile(path, fp, function(file)
    writeChunked(file, terrain)
    writeChunked(file, water)
    local ids = {}
    for id, stream in pairs(type(visuals) == "table" and visuals or {}) do
      if type(id) == "string" and id ~= "" and stream then
        ids[#ids + 1] = id
      end
    end
    table.sort(ids)
    write(file, u32(#ids))
    for _, id in ipairs(ids) do
      write(file, u32(#id))
      write(file, id)
      writeChunked(file, visuals[id])
      Budget.check()
    end
    registry = type(registry) == "string" and registry or ""
    write(file, u32(#registry))
    write(file, registry)
    writeSpans(file, terrain and terrain.spans)
  end)
end

local function f32x4(a, b, c, d)
  return love.data.pack("string", "<ffff", a or 0, b or 0, c or 0, d or 0)
end

function Disk.saveAux(map, aux)
  if not Disk.staticEligible(map) then return false end
  local fp = Disk.fingerprint(map, "aux", nil, "aux")
  local path = pathFor(map, "aux", "aux", fp)
  return writeFile(path, fp, function(file)
    writeChunked(file, aux.grass)
    writeChunked(file, aux.flowers)
    write(file, u32(#(aux.figures or {})))
    for _, figure in ipairs(aux.figures or {}) do
      writeChunked(file, figure)
      write(file, f32x4(figure.wx, figure.wz, figure.y, figure.w))
      Budget.check()
    end
    writeSpans(file, aux.grass and aux.grass.spans)
    writeSpans(file, aux.flowers and aux.flowers.spans)
  end)
end

function Disk.saveTreeParts(map, recipe, signature, parts, yieldFn)
  if not Disk.staticEligible(map) then return false end
  parts = parts or {}
  local fp = treeFingerprint(map, recipe, signature)
  local path = treePath(map, recipe, signature, fp)
  return writeFile(path, fp, function(file)
    write(file, u32(parts.count or 0))
    write(file, u32(parts.tN or 0))
    write(file, u32(parts.bN or 0))
    write(file, u32(#(parts.cells or {})))
    for i, cell in ipairs(parts.cells or {}) do
      write(file, f32x4(cell[1], cell[2], cell[3] == "b" and 1 or 0,
                        cell[4] == nil and -1e30 or cell[4]))
      if yieldFn and i % 128 == 0 then yieldFn() end
    end
    write(file, u32(#(parts.parts or {})))
    for _, part in ipairs(parts.parts or {}) do
      write(file, f32x4(part.x, part.y, part.z, part.radius))
      write(file, u32(part.apron and 1 or 0))
      write(file, u32(part.detailFarCount or 0))
      for _, name in ipairs(TREE_MATERIALS) do
        assert(writeChunked(file, part[name], yieldFn))
      end
      if yieldFn then yieldFn() end
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
  -- engines. Prefer its delete primitive so list()/stats()/RAM planning cannot
  -- keep seeing zero-byte tombstones. Older facades fall back to empty writes.
  -- The native legacy backend is removed only by the filesystem loop below so
  -- each physical record is counted once.
  if storage and storage.list and storage.writeBytes then
    local ok, names = pcall(storage.list, storage, LOGICAL_DIRECTORY)
    if ok then
      for _, key in ipairs(names or {}) do
        if key:sub(1, #LOGICAL_DIRECTORY + 1) == LOGICAL_DIRECTORY .. "/" then
          local called, did
          if type(storage.delete) == "function" then
            called, did = pcall(storage.delete, storage, key)
          elseif not Disk.legacy() then
            called, did = pcall(storage.writeBytes, storage, key, "")
          end
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
  ramFiles, ramDirty, ramBytes, ramRejected, ramGenerated = {}, {}, 0, {}, {}
  return removed
end

-- Wrapping complete cache stages avoids per-byte/per-vertex timer overhead.
-- streamRecord and writeChunked may yield; the owning pump pauses the clock.
readValidated = Timings.wrap("cache_read", readValidated)
streamRecord = Timings.wrap("cache_decode", streamRecord)
writeChunked = Timings.wrap("cache_encode", writeChunked)
encoded = Timings.wrap("cache_encode", encoded)
writePersistent = Timings.wrap("cache_write", writePersistent)
Disk.fingerprint = Timings.wrap("cache_other", Disk.fingerprint)
Disk.loadTerrain = Timings.wrap("cache_other", Disk.loadTerrain)
Disk.loadAux = Timings.wrap("cache_other", Disk.loadAux)
Disk.loadTreeParts = Timings.wrap("cache_other", Disk.loadTreeParts)
Disk.saveTerrain = Timings.wrap("cache_other", Disk.saveTerrain)
Disk.saveAux = Timings.wrap("cache_other", Disk.saveAux)
Disk.saveTreeParts = Timings.wrap("cache_other", Disk.saveTreeParts)
Disk.saveRamToDisk = Timings.wrap("cache_other", Disk.saveRamToDisk)

return Disk
