-- PARADE SWITCHES (independent renderer review, diagnostic, 2026-10-23).
-- The Champion's Parade: the Celadon title card freezes ~13-14 s while the
-- first frame there is drawn. In TEST264 the parade then came up and played;
-- since TEST266 + Cull Handoff the kernel logs a "gpu timeout" there and the
-- game goes black or crashes. Between TEST264 and this build only two game
-- changes touch drawing, both in lib/Voxel3D.lua:
--   SCENE DEPTH   TEST266  the owned, NON-readable scene depth (TEST266's
--                          isolation test; water/effects skip depth reads)
--                 TEST265  the readable depth texture of TEST264/TEST265
--                          (Voxel3D.SAMPLED_DEPTH = true)
--   CULL HANDOFF  ON       drawCulled's runs survive a five-argument draw
--                          wrapper (Cull Handoff 1/2)
--                 OFF      TEST264's drawCulled exactly
-- Both rows at TEST265 / OFF draw as TEST264 did (plus the shadow copy).
-- Applied at the start of every 3D scene; a change is logged once:
--   [PARADE-SWITCHES] scene depth TEST266 (owned), cull handoff ON
local V = ...
local ModSetting = V.require("ModSetting")
local M = {}
M.depthSetting = ModSetting.new("legendarySceneDepth", "SCENE DEPTH",
  { "owned", "readable" }, { "TEST266", "TEST265" }, 1)
M.cullSetting = ModSetting.new("legendaryCullHandoff", "CULL HANDOFF",
  { "on", "off" }, { "ON", "OFF" }, 1)

local function get(setting, fallback)
  local ok, v = pcall(setting.get, setting)
  return (ok and v) or fallback
end
local function log(msg)
  msg = (tostring(msg):gsub("%%", ""))
  local ok, L = pcall(require, "src.core.Logger")
  if ok and type(L) == "table" and type(L.info) == "function" and pcall(L.info, msg) then return end
  pcall(print, msg)
end

-- The rows' defaults (TEST266 / ON) are Voxel3D's own defaults, so the flags
-- are written only when a row CHANGES (or starts away from its default):
-- code that sets Voxel3D.SAMPLED_DEPTH itself is left alone otherwise.
local lastDepth, lastCull = "owned", "on"
local logged = false
function M.apply(Voxel3D)
  local depth = get(M.depthSetting, "owned")
  local cull = get(M.cullSetting, "on")
  local changed = false
  if depth ~= lastDepth then
    Voxel3D.SAMPLED_DEPTH = (depth == "readable")
    lastDepth, changed = depth, true
  end
  if cull ~= lastCull then
    Voxel3D.CULL_HANDOFF = (cull ~= "off")
    lastCull, changed = cull, true
  end
  if changed or not logged then
    logged = true
    log(("[PARADE-SWITCHES] scene depth %s, cull handoff %s"):format(
      Voxel3D.SAMPLED_DEPTH and "TEST265 (readable)" or "TEST266 (owned)",
      Voxel3D.CULL_HANDOFF == false and "OFF (TEST264)" or "ON"))
  end
  return depth, cull
end
function M._reset() lastDepth, lastCull, logged = "owned", "on", false end
return M
