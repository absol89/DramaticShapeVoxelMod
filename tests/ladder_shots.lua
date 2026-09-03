-- Driver: the cave ladders, shot from the south at the orbit rungs.
--
-- These cells used to be pinned to the staircase classes and came out as
-- four-step flights thrown across the cell.  They are a `ladder` standee
-- now -- the same per-pixel object pass that builds signs, posts and
-- bicycles -- and this is the shot that says what actually reaches the
-- screen.
--
-- SEAFOAM_ISLANDS_B2F carries one of each with dark floor to the south to
-- stand on -- an up ladder at cell (5,3) and a down one at (5,13) -- so a
-- single map states both halves.
--
-- It also prints the geometry it shot, because a screenshot cannot be
-- asserted on: how many quads each ladder cell built and the height band
-- they span.
--
-- BOTH stand on the floor plane, including the descending ladder.  That is
-- the standee path's one concession and it is deliberate -- the shared
-- object pipeline stands a drawing up and has no notion of a hole, so a
-- ladder DOWN cannot be excavated the way the old stairwell pin was.  A
-- band that dips below 0 would mean something has changed, so the check
-- below is that nothing does.
--
--   POKEPORT_DRIVER=mods/BattleArtVoxelFork/tests/ladder_shots.lua \
--   SHOT_DIR=.scratchpad/ladder lovec .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Pipelines = require("src.render.Pipelines")
  local PaletteFX = require("src.render.PaletteFX")

  local ROOT = (os.getenv("SHOT_DIR") or "shots/ladder")
    .. "/" .. (os.getenv("AB_TAG") or "after")

  local handle = game.mods.exports["BATTLE_ART_VOXEL_FORK"]
  if not (handle and handle.lib) then
    print("[ladder] BATTLE_ART_VOXEL_FORK not loaded (is the DramaticShape junction still present? they conflict)")
    love.event.quit(1)
    return
  end
  local V = handle.lib
  local DayNight = V.require("DayNight")
  local ChunkMesher = V.require("ChunkMesher")
  local Structures = V.require("Structures")
  local Voxel = V.require("VoxelState")

  require("src.world.OverworldController").rollEncounter = function() return nil end
  local TileRenderer = require("src.render.TileRenderer")
  TileRenderer.tick = function() end
  TileRenderer.animFrame = function() return 0 end
  DayNight.setting:sync("day")

  pcall(os.execute, 'mkdir -p "' .. ROOT .. '" 2>/dev/null')
  pcall(os.execute, 'mkdir "' .. ROOT:gsub("/", "\\") .. '" 2>nul')

  -- COLOUR PACK.  The engine ships several and the default is `gbc` (SGB),
  -- which is what an unset run shoots.  SHOT_COLORS takes a mode id --
  -- `redpp` is the one the options menu calls ADVANCED, the per-tile
  -- pokered-gbc colorization.  It is set BEFORE the teleport so the map
  -- loads with the right baked atlas: switching a live map only rebuilds
  -- it through a reload, and the frames in between are the wrong pack.
  local COLORS = os.getenv("SHOT_COLORS")
  if COLORS and COLORS ~= "" then
    pcall(function()
      game.save.options.colors = COLORS
      PaletteFX.setMode(COLORS)
    end)
    print(("[ladder] colour pack: %s (%s)"):format(
          COLORS, PaletteFX.modeLabel and PaletteFX.modeLabel(COLORS) or "?"))
  end

  local Zoom = require("src.render.Zoom")
  pcall(function()
    game.save.options.zoom = 1
    Zoom.applyOptions(game.save.options)
  end)

  local function settle()
    for _ = 1, 900 do
      if ChunkMesher.pending() == 0 then break end
      U.wait(1)
    end
    for _ = 1, 300 do
      if Voxel.t >= 1 and Voxel.ready and ChunkMesher.pending() == 0 then break end
      U.wait(1)
    end
    U.wait(30)
  end

  local SCENES = {
    { map = "SEAFOAM_ISLANDS_B2F", cx = 5, cy = 3,  x = 5, y = 5,
      label = "up" },
    { map = "SEAFOAM_ISLANDS_B2F", cx = 5, cy = 13, x = 5, y = 15,
      label = "down" },
  }

  local shots, bad = 0, 0
  for _, s in ipairs(SCENES) do
    U.teleport(game, s.map, s.x, s.y, "up")
    Pipelines.setLevel("voxel", 3)
    Pipelines.setLevel("tiltshift", 0)
    settle()

    -- the quads standing in this cell: the ladder is the only thing built
    -- there, so its footprint names them without tagging the geometry
    local ow = game.overworld
    local S = ow and ow.map and Structures.forMap(ow.map)
    local mx0, mx1 = s.cx * 16, s.cx * 16 + 16
    local mz0, mz1 = s.cy * 16, s.cy * 16 + 16
    local n, lo, hi = 0, math.huge, -math.huge
    for _, q in ipairs((S and S.objectQuads) or {}) do
      local x, z = q[1][1], q[1][3]
      if x >= mx0 and x <= mx1 and z >= mz0 and z <= mz1 then
        n = n + 1
        for i = 1, 4 do
          lo = math.min(lo, q[i][2])
          hi = math.max(hi, q[i][2])
        end
      end
    end
    if n == 0 then
      print(("[ladder] %s cell (%d,%d) built NO geometry"):format(
            s.label, s.cx, s.cy))
      bad = bad + 1
    else
      print(("[ladder] %-4s cell (%2d,%2d): %d quads, y %.1f .. %.1f")
            :format(s.label, s.cx, s.cy, n, lo, hi))
      -- a standee stands ON the floor: nothing should reach below it
      if lo < -0.01 then
        print(("[ladder]   `%s` dips below the floor plane -- a standee "
               .. "cannot excavate, so something else built this")
              :format(s.label))
        bad = bad + 1
      end
    end

    for _, rung in ipairs({ 3, 5 }) do
      Pipelines.setLevel("voxel", rung)
      settle()
      local path = ("%s/%s_v%d.png"):format(ROOT, s.label, rung)
      game.capturePath = path
      U.wait(8)
      local f = io.open(path, "rb")
      if f then f:close() shots = shots + 1
      else print("[ladder] capture missed: " .. path) end
    end
  end

  print(("[ladder] %d shots into %s, %d problems"):format(shots, ROOT, bad))
  love.event.quit(bad > 0 and 1 or 0)
end
