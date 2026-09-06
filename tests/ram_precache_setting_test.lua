package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local root = os.getenv("DS_MOD_PATH") or "mods/DramaticShapeVoxelMod"
local loaded = {}
local ios = false
local V = {
  mod = {
    id = "BATTLE_ART_VOXEL_FORK",
    options = { get = function() return nil end },
  },
}

function V.require(name)
  if name == "Voxel3D" then
    return { metalRenderer = function() return ios end }
  end
  if loaded[name] then return loaded[name] end
  local chunk = assert(loadfile(root .. "/lib/" .. name .. ".lua"))
  local module = chunk(V)
  loaded[name] = module
  return module
end

local RamPrecache = V.require("RamPrecache")
local setting = RamPrecache.setting
local expected = { 256, 512, 768, 1024, 1536, 2048, 2560, 3072, false, 0 }
local labels = { "256", "512", "768", "1024", "1536", "2048", "2560",
                 "3072", "FULL", "OFF" }

T.eq(setting.label, "RAM PRECACHE MB", "the performance row has its final label")
T.eq(#setting.values, #expected, "the ladder has exactly the requested rungs")
for i, value in ipairs(expected) do
  T.eq(setting.values[i], value, "stored rung " .. i .. " is ordered")
  T.eq(setting.labels[i], labels[i], "display rung " .. i .. " is ordered")
end
T.eq(setting:get(), 256, "the first and default rung is 256 MiB")
T.eq(RamPrecache.bytes(), 256 * 1024 * 1024,
  "the default converts to a byte budget")
setting:setIndex(9)
T.eq(RamPrecache.bytes(), nil, "FULL has no byte ceiling")
setting:setIndex(10)
T.eq(RamPrecache.bytes(), 0, "OFF requests no eager preload")
ios = true
T.eq(RamPrecache.bytes(), nil,
  "OFF selects the 1.9.6 full preload on Phosphor/iOS")
ios = false

local maps = {
  ROUTE_2 = { connections = {
    north = { map = "PEWTER_CITY" }, south = { map = "VIRIDIAN_CITY" },
  } },
  PEWTER_CITY = { connections = { east = { map = "ROUTE_3" } } },
  VIRIDIAN_CITY = { connections = { south = { map = "ROUTE_1" } } },
  ROUTE_3 = { connections = {} }, ROUTE_1 = { connections = {} },
}
local priority = RamPrecache.priorityMaps({ maps = maps }, "ROUTE_2", 2)
T.same(priority,
  { "ROUTE_2", "PEWTER_CITY", "VIRIDIAN_CITY", "ROUTE_3", "ROUTE_1" },
  "the saved map leads a deterministic two-hop connection neighborhood")

local DiskV = { require = function(name)
  if name == "BuildBudget" or name == "StaticGeometry" then return {} end
  error("unexpected module " .. tostring(name))
end }
local Disk = assert(loadfile(root .. "/lib/VoxelMeshDisk.lua"))(DiskV)
local prefix = Disk.DIRECTORY .. "/"
local names = {
  prefix .. "OTHER/full-terrain",
  prefix .. "PEWTER_CITY/full-terrain",
  prefix .. "ROUTE_2/body-terrain",
  prefix .. "PEWTER_CITY/deco",
  prefix .. "ROUTE_2/full-terrain",
  prefix .. "PEWTER_CITY/body-terrain",
  prefix .. "ROUTE_2/deco",
}
Disk.orderRamNames(names, { "ROUTE_2", "PEWTER_CITY" })
T.same(names, {
  prefix .. "ROUTE_2/deco",
  prefix .. "ROUTE_2/full-terrain",
  prefix .. "PEWTER_CITY/body-terrain",
  prefix .. "PEWTER_CITY/deco",
  prefix .. "ROUTE_2/body-terrain",
  prefix .. "PEWTER_CITY/full-terrain",
  prefix .. "OTHER/full-terrain",
}, "RAM reads current-map boot records, then neighbor bodies, before the rest")

T.finish("RAM precache setting")
