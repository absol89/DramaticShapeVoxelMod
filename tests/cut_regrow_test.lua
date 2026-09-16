-- A tree that grew back has to be drawn again -- in EVERY mesh the map keeps.
--
-- Cut drops the felled tree's vertices from the meshes on screen so it goes
-- on the frame it was cut. That mesh is then owed a rebuild, and refresh()
-- marks it stale, but only the slot something is DRAWING gets asked for
-- again: standing in a town the scene asks for FULL every frame and never
-- for BODY, which is the variant its neighbours draw.
--
-- So the body mesh kept the hole. Gen 1 regrows a cut tree when the map is
-- re-entered (OverworldState:setMap restores cutBlocks), and the block --
-- and its collision -- came back while that mesh still had nothing there:
-- a tree you must cut to get past and cannot see.
--
--   POKEPORT_DRIVER=mods/BattleArtVoxelFork/tests/cut_regrow_test.lua \
--   "/c/Program Files/LOVE/lovec.exe" .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Pipelines = require("src.render.Pipelines")

  local failures, checks = 0, 0
  local function check(ok, what)
    checks = checks + 1
    if not ok then
      failures = failures + 1
      print("FAIL " .. what)
    else
      print("ok   " .. what)
    end
  end

  local handle = game.mods.exports["BATTLE_ART_VOXEL_FORK"]
  if not (handle and handle.lib) then
    print("FAIL BATTLE_ART_VOXEL_FORK is not loaded")
    love.event.quit(1)
    return
  end
  local V = handle.lib
  local ChunkMesher = V.require("ChunkMesher")
  local MeshDisk = V.require("VoxelMeshDisk")
  local Voxel = V.require("VoxelState")
  pcall(function() V.require("DayNight").setting:sync("day") end)
  require("src.world.OverworldController").rollEncounter = function() return nil end
  pcall(MeshDisk.bind, game, false)

  Pipelines.setLevel("voxel", 5)
  Pipelines.setLevel("tiltshift", 0)

  local function settle(extra)
    for _ = 1, 6000 do
      if ChunkMesher.pending() == 0 and Voxel.ready then break end
      U.wait(1)
    end
    U.wait(extra or 40)
  end

  -- Cerulean's cuttable block: one tree in the middle of a hedge.
  local BX, BY = 9, 14

  -- how many vertices stand on that block in a slot, 0 when the slot is gone
  local function verts(map, bodyOnly)
    local mesh = ChunkMesher.pair(map, bodyOnly)
    if not mesh then return nil end
    local px0, pz0 = BX * 32, BY * 32
    local ok, n = pcall(function()
      local count = 0
      for i = 1, mesh:getVertexCount() do
        local x, _, z = mesh:getVertex(i)
        if x >= px0 and x < px0 + 32 and z >= pz0 and z < pz0 + 32 then
          count = count + 1
        end
      end
      return count
    end)
    return ok and n or nil
  end

  U.teleport(game, "CERULEAN_CITY", 19, 30, "up")
  Pipelines.setLevel("voxel", 5)
  settle()
  local ow = game.overworld or game.stack:top()
  local map = ow.map
  local block = map:blockAt(BX, BY)
  local after
  for _, sw in ipairs(game.data.field.cutTreeSwaps) do
    if sw.before == block then after = sw.after break end
  end
  local standingFull, standingBody = verts(map, false), verts(map, true)
  check(standingFull and standingFull > 0,
        "the standing tree is in the full mesh")
  check(standingBody and standingBody > 0,
        "the standing tree is in the body mesh")

  -- the cut, exactly as OverworldState:tryCut does it
  ow.cutBlocks = ow.cutBlocks or {}
  ow.cutBlocks[map.id] = ow.cutBlocks[map.id] or {}
  table.insert(ow.cutBlocks[map.id], { bx = BX, by = BY, block = block })
  map:setBlock(BX, BY, after)
  map.renderer:rebuild()
  U.wait(1)
  local cutFull = verts(map, false)
  check(cutFull and cutFull < standingFull,
        "the felled tree leaves the drawn mesh on the frame it was cut")
  settle()

  -- in a door and back out: the regrowth restores the block
  ow:startWarpTo("CERULEAN_POKECENTER", 3, 5, "down", nil, { via = "warp" })
  for _ = 1, 600 do
    if ow.map and ow.map.id == "CERULEAN_POKECENTER"
       and not ow.transitioning then break end
    U.wait(1)
  end
  settle(120)
  ow:startWarpTo("CERULEAN_CITY", 19, 30, "up", nil, { via = "warp" })
  for _ = 1, 600 do
    if ow.map and ow.map.id == "CERULEAN_CITY" and not ow.transitioning then
      break
    end
    U.wait(1)
  end
  settle()
  U.wait(120)

  check(ow.map:blockAt(BX, BY) == block,
        "the block itself grew back, so the tree is solid again")
  local backFull, backBody = verts(ow.map, false), verts(ow.map, true)
  check(backFull == standingFull,
        ("the full mesh draws the tree again (%s, was %s standing)")
        :format(tostring(backFull), tostring(standingFull)))
  check(backBody == standingBody,
        ("the body mesh draws the tree again (%s, was %s standing)")
        :format(tostring(backBody), tostring(standingBody)))

  print(("%d/%d checks passed"):format(checks - failures, checks))
  love.event.quit(failures == 0 and 0 or 1)
end
