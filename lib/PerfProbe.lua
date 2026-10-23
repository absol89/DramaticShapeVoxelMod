-- TEST184: PERF PROBE (PERFORMANCE). One press measures, on the phone itself,
-- what each part of the outdoor picture costs: the frame rate as it is, then
-- with one thing taken away at a time, a few seconds each, then a table on
-- screen (and in perfprobe.txt in the save folder). Nothing it switches is
-- saved: every step is put back when the next starts, and all of it at the
-- end, or the moment a menu, a battle or a door interrupts it.
local V = ...
local ModSetting = V.require("ModSetting")

local M = {}
M.setting = ModSetting.new("legendaryPerfProbe", "PERF PROBE",
  { "off", "run" }, { "OFF", "RUN" }, 1)

M.SETTLE = 1.5     -- seconds ignored after each switch (shader compiles, recasts)
M.MEASURE = 3.0    -- seconds measured
M.SHOW = 45        -- seconds the result stays on screen
-- TEST188: repeatable runs. The probe first waits until background work
-- (terrain, cache, mesh uploads, tree building, culling index) has been
-- quiet for QUIET seconds (at most WAIT_MAX), then measures AS IS again
-- after every two steps; each step is compared with the AS IS measured
-- around it (interpolated in time), so drift (heat, loading) cancels out.
M.QUIET = 2.0
M.WAIT_MAX = 30
M.PAIR = 2

local function settingSwap(get, idx)
  return function()
    local s = get()
    local old = s.index
    s:read()
    old = s.index
    s.index = idx
    return function() s.index = old end
  end
end
local function flag(name)
  return function()
    V.perfProbe = V.perfProbe or {}
    V.perfProbe[name] = true
    return function() if V.perfProbe then V.perfProbe[name] = nil end end
  end
end
local function scale(v)
  return function()
    local AA = V.require("AntiAlias")
    AA.probeScale = v
    return function() AA.probeScale = nil end
  end
end
-- TEST188: draw-only (VoxelScene's drawNb). Swapping RenderDistance.neighbor
-- itself changed the live set: the neighbours were evicted and reloaded,
-- which is the terrain/cache work that leaked into the following steps.
local noNeighbors = flag("noNeighbors")
local function fullShader()
  local V3 = V.require("Voxel3D")
  local old = V3.SPLIT_SHADER
  V3.SPLIT_SHADER = false
  return function() V3.SPLIT_SHADER = old end
end
local function shadowsOff()
  return settingSwap(function() return V.require("Shadows").setting end, 2)()
end
local function waterOff()
  return settingSwap(function() return V.require("Water").setting end, 3)()
end

-- TEST189: compile-time variants (Voxel3D.probeShaderFor), compiled ahead
-- of the run while the probe waits for loading to settle
local function variant(defs)
  return function()
    V.perfProbe = V.perfProbe or {}
    V.perfProbe.variant = defs
    return function() if V.perfProbe then V.perfProbe.variant = nil end end
  end
end
M.VARIANTS = { "LG_PROBE_LITE", "LG_FLAT_FOREST", "LG_FLAT_TOWN",
               "LG_FLAT_EXTERIOR", "LG_FLAT_HIGH", "LG_FLAT_TINT" }
local function noMap(id)
  return function()
    V.perfProbe = V.perfProbe or {}
    V.perfProbe.noMaps = V.perfProbe.noMaps or {}
    V.perfProbe.noMaps[id] = true
    return function() if V.perfProbe and V.perfProbe.noMaps then V.perfProbe.noMaps[id] = nil end end
  end
end

-- TEST189: the steps that measured 0-5% in both maps twice (water, grass,
-- trees/props, render 50%) and the two already answered (full shader,
-- culling) are out; the two big unknowns are split instead: which
-- neighbour (one step per neighbour drawn, added at the start of a run)
-- and which family of surface finishes.
M.STEPS = {
  { "RENDER 75%", scale(0.75) },
  { "SHADOWS OFF", shadowsOff },
  { "NO SKY/MOUNTAINS", flag("noSky") },
  { "NO NEIGHBOUR MAPS", noNeighbors },
  { "FLAT SURFACES", variant("LG_PROBE_LITE") },
  { "FLAT TREES 1-28", variant("LG_FLAT_FOREST") },
  { "FLAT TOWN 29-51", variant("LG_FLAT_TOWN") },
  { "FLAT BUILDINGS 52-93", variant("LG_FLAT_EXTERIOR") },
  { "FLAT ROUTES 100+", variant("LG_FLAT_HIGH") },
  { "FLAT ATLAS TINT", variant("LG_FLAT_TINT") },
  { "ALL OF THEM OFF", function()
      local undo = {}
      for _, f in ipairs({ shadowsOff, waterOff, flag("noSky"), flag("noGrass"),
                           flag("noProps"), noNeighbors, variant("LG_PROBE_LITE") }) do
        undo[#undo + 1] = f()
      end
      return function() for i = #undo, 1, -1 do undo[i]() end end
    end },
}

local BASE = { "AS IS" }
local run = nil       -- { slot, plan, t0, frames, dts, undo, results, map }
local shown = nil     -- { lines, untilT }
local font

local function now() return love.timer.getTime() end

-- TEST186: where the CPU time goes. LoadTimings' exclusive totals (game
-- update, prefetch, trees, terrain, cache, the scene's own probes) and
-- VoxelScene's inclusive sections, read before and after a step.
local function snap()
  local s = { t = {}, sec = {} }
  local okT, T = pcall(V.require, "LoadTimings")
  local sn = okT and T and T.snapshot and T.snapshot()
  if sn and sn.totals then for k, v in pairs(sn.totals) do s.t[k] = v end end
  local okS, VS = pcall(V.require, "VoxelScene")
  if okS and VS and VS.sectionMs then for k, v in pairs(VS.sectionMs) do s.sec[k] = v end end
  return s
end
local function delta(a, b, frames)
  local d = { t = {}, sec = {} }
  for _, part in ipairs({ "t", "sec" }) do
    for k, v in pairs(b[part]) do d[part][k] = (v - (a[part][k] or 0)) / frames end
  end
  return d
end
local BG_KEYS = { "terrain_build", "terrain_upload", "terrain_other",
  "cache_read", "cache_decode", "cache_encode", "cache_write", "cache_other",
  "mesh_alloc", "mesh_write", "tree_build", "tree_pack", "tree_upload" }
local function bgTotal()
  local okT, T = pcall(V.require, "LoadTimings")
  local sn = okT and T and T.snapshot and T.snapshot()
  local sum = 0
  if sn and sn.totals then for _, k in ipairs(BG_KEYS) do sum = sum + (sn.totals[k] or 0) end end
  return sum
end
local function indexPending()
  local ok, CM = pcall(V.require, "ChunkMesher")
  if ok and CM and CM.indexPending then
    local okP, n = pcall(CM.indexPending)
    if okP then return n or 0 end
  end
  return 0
end

-- The frame's present (swap): where a wait for the GPU or the display shows
-- up directly. Wrapped only while a probe runs.
local presentMs, presentOrig = 0, nil
local function wrapPresent()
  if presentOrig or not (love.graphics and love.graphics.present) then return end
  presentOrig = love.graphics.present
  local original = presentOrig
  love.graphics.present = function(...)
    local t = love.timer.getTime()
    local r1, r2 = original(...)
    presentMs = presentMs + (love.timer.getTime() - t) * 1000
    return r1, r2
  end
end
local function unwrapPresent()
  if presentOrig then love.graphics.present = presentOrig; presentOrig = nil end
end

local GROUPS = {
  { "update", { "update_other" } },
  { "prefetch", { "prefetch" } },
  { "trees", { "tree_build", "tree_pack", "tree_upload", "tree_keys", "tree_other", "tree_draw" } },
  { "terrain", { "terrain_build", "terrain_upload", "terrain_other" } },
  { "cache", { "cache_read", "cache_decode", "cache_encode", "cache_write", "cache_other" } },
  { "mesh", { "mesh_alloc", "mesh_write" } },
}
local SECTIONS = {
  { "setup", "scene_setup" }, { "shadows", "scene_shadows" }, { "begin", "scene_begin" },
  { "sky", "scene_sky" }, { "terrain", "scene_terrain" }, { "props", "scene_props" },
  { "trees", "scene_trees" }, { "windows", "scene_windows_decor" }, { "water", "scene_water" },
  { "chars", "scene_characters" }, { "grass", "scene_grass" }, { "life", "scene_life" },
  { "end", "scene_end" }, { "fx", "fx_overlay_resolve" },
}
local function cpuLines(label, r)
  local d = r.cpu
  if not d then return {} end
  local all, used, parts = 0, {}, {}
  for k, v in pairs(d.t) do all = all + v end
  for _, g in ipairs(GROUPS) do
    local sum = 0
    for _, k in ipairs(g[2]) do sum = sum + (d.t[k] or 0); used[k] = true end
    parts[#parts + 1] = ("%s %.1f"):format(g[1], sum)
  end
  local scene = 0
  for k, v in pairs(d.t) do if not used[k] then scene = scene + v end end
  local secs = {}
  for _, sct in ipairs(SECTIONS) do
    secs[#secs + 1] = ("%s %.1f"):format(sct[1], d.sec[sct[2]] or 0)
  end
  local present = r.present or 0
  -- 0 exactly: the engine did not present through love.graphics.present
  -- (a stored copy), so the split is unknown
  local presentText = present > 0 and ("%.1f"):format(present) or "n/a"
  return {
    ("CPU-side %s: frame %.1f ms = timed calls %.1f (%s, scene %.1f) + present %s + other untimed %.1f")
      :format(label, r.mean or r.ms, all, table.concat(parts, ", "), scene, presentText,
              math.max(0, (r.mean or r.ms) - all - present)),
    "   scene: " .. table.concat(secs, " ", 1, 8),
    "   " .. table.concat(secs, " ", 9) .. ("   | Graphics: %d draws, %d canvas, %d shader switches")
      :format(r.draws or 0, r.canvases or 0, r.shaders or 0),
  }
end


local function stopStep()
  if run and run.undo then pcall(run.undo); run.undo = nil end
end

local function stepOf(slot) return run.plan[slot] end

local function startSlot(i)
  stopStep()
  run.slot, run.t0, run.frames, run.time, run.dts = i, now(), 0, 0, {}
  run.snap, run.draws, run.canvases, run.shaders = nil, 0, 0, 0
  run.recastW = V.require("ShadowMap").worldCasts or 0
  run.recastC = V.require("ShadowMap").castCasts or 0
  run.bg0, run.present0, run.pendingMax = nil, nil, 0
  local fn = stepOf(i)[2]
  if fn then
    local ok, undo = pcall(fn)
    run.undo = ok and undo or nil
  end
end

local function info()
  local lines = {}
  local ok, name, version, vendor, device = pcall(love.graphics.getRendererInfo)
  if ok then lines[#lines + 1] = (tostring(device) .. " / " .. tostring(name) .. " " .. tostring(version)):sub(1, 90) end
  local okP, pw, ph = pcall(love.graphics.getPixelDimensions)
  if okP then lines[#lines + 1] = ("screen %dx%d  render scale %d%%"):format(pw, ph,
    math.floor(V.require("AntiAlias").renderScale() * 100 + .5)) end
  return lines
end

local function median(t, q)
  if #t == 0 then return 0 end
  local c = {}
  for i, v in ipairs(t) do c[i] = v end
  table.sort(c)
  local k = math.max(1, math.min(#c, math.floor((q or .5) * #c + .5)))
  return c[k]
end

-- AS IS at time t, interpolated between the baselines around it
local function baseAt(bases, t)
  if #bases == 0 then return nil end
  if t <= bases[1].tmid then return bases[1].ms end
  for i = 2, #bases do
    local a, b = bases[i - 1], bases[i]
    if t <= b.tmid then
      local f = (t - a.tmid) / math.max(1e-6, b.tmid - a.tmid)
      return a.ms + (b.ms - a.ms) * f
    end
  end
  return bases[#bases].ms
end

local function finish(reason)
  stopStep()
  unwrapPresent()
  V.perfProbe = nil
  if not run then return end
  local lines = { "PERF PROBE  " .. tostring(run.map) .. (reason and ("  (" .. reason .. ")") or "")
                  .. (run.unsettled and "  (loading never settled)" or "") }
  for _, l in ipairs(info()) do lines[#lines + 1] = l end
  local bases, vars = {}, {}
  for _, r in ipairs(run.results) do
    if r.base then bases[#bases + 1] = r else vars[#vars + 1] = r end
  end
  local bl = {}
  for _, b in ipairs(bases) do bl[#bl + 1] = ("%.1f%s"):format(b.ms, b.disturbed and "*" or "") end
  if #bases > 0 then
    local lo, hi = math.huge, -math.huge
    for _, b in ipairs(bases) do lo = math.min(lo, b.ms); hi = math.max(hi, b.ms) end
    lines[#lines + 1] = ("AS IS (median ms, in order): %s   drift %.0f%%")
      :format(table.concat(bl, " "), 100 * (hi - lo) / math.max(1, lo))
  end
  for _, r in ipairs(vars) do
    local ref = baseAt(bases, r.tmid)
    local gain = ref and ("%+3d%%"):format(math.floor((ref / r.ms - 1) * 100 + .5)) or "  -"
    lines[#lines + 1] = ("%-21s %5.1f ms (p90 %5.1f)  %s vs AS IS  [shadows %.1f/%.1f] [geometry %s]%s")
      :format(r.name, r.ms, r.p90, gain, r.rw, r.rc,
              r.geo and ("%d%%"):format(math.floor(r.geo * 100 + .5)) or "-",
              r.disturbed and "  * loading" or "")
  end
  lines[#lines + 1] = "ms = median frame time; vs AS IS = speed-up against the AS IS runs either side; * = background loading during the step"
  local first, last = bases[1], vars[#vars]
  if first then for _, l in ipairs(cpuLines("AS IS", first)) do lines[#lines + 1] = l end end
  if last then for _, l in ipairs(cpuLines(last.name, last)) do lines[#lines + 1] = l end end
  run = nil
  shown = { lines = lines, untilT = now() + M.SHOW }
  pcall(love.filesystem.write, "perfprobe.txt", table.concat(lines, "\n") .. "\n")
end

local function buildPlan(ow)
  local plan = { BASE }
  local n = 0
  local steps = {}
  for i, st in ipairs(M.STEPS) do
    steps[#steps + 1] = st
    -- one NO <map> step per neighbour drawn, right after NO NEIGHBOUR MAPS
    if st[1] == "NO NEIGHBOUR MAPS" then
      local RD = V.require("RenderDistance")
      for _, nb in ipairs((ow and ow.neighbors) or {}) do
        local ok, on = pcall(RD.neighbor, nb, ow.player)
        if nb.map and nb.map.id and ok and on then
          steps[#steps + 1] = { "NO " .. tostring(nb.map.id), noMap(nb.map.id) }
        end
      end
    end
  end
  for _, st in ipairs(steps) do
    plan[#plan + 1] = st
    n = n + 1
    if n % M.PAIR == 0 then plan[#plan + 1] = BASE end
  end
  if plan[#plan] ~= BASE then plan[#plan + 1] = BASE end
  return plan
end

local function update(game, dt)
  local ow = game and game.overworld
  local top = game and game.stack and game.stack.top and game.stack:top()
  if not run then
    if M.setting:get() == "run" and ow and ow.map and top == ow then
      M.setting:setIndex(1, game)        -- one press, one run
      run = { results = {}, map = ow.map.id, plan = buildPlan(ow), waiting = true,
              waitT0 = now(), quietT0 = now(), bgLast = bgTotal() }
      V.perfProbe = {}
      shown = nil
      wrapPresent()
    end
    return
  end
  if not (ow and ow.map and top == ow and ow.map.id == run.map) then
    finish("interrupted")
    return
  end
  if run.waiting then
    -- wait for background work to go quiet before the first measurement
    local bg = bgTotal()
    if bg > run.bgLast + 0.05 or indexPending() > 0 then run.quietT0 = now() end
    run.bgLast = bg
    local waited = now() - run.waitT0
    -- TEST189: compile the probe's shader variants now, one a frame, so no
    -- compile lands inside a measured step
    local V3 = V.require("Voxel3D")
    if V3.precompileProbe then
      local okC, more = pcall(V3.precompileProbe, M.VARIANTS, V3.lastShaderProfile)
      if not okC then finish("probe shader error"); return end
      if more then run.quietT0 = now(); return end
    end
    if now() - run.quietT0 >= M.QUIET or waited >= M.WAIT_MAX then
      run.unsettled = waited >= M.WAIT_MAX
      run.waiting = false
      startSlot(1)
    end
    return
  end
  local t = now() - run.t0
  if t > M.SETTLE then
    -- snapshot on the first counted frame; that frame itself is not counted
    if not run.snap then
      run.snap = snap(); run.bg0 = bgTotal(); run.present0 = presentMs
      run.recastW = V.require("ShadowMap").worldCasts or 0
      run.recastC = V.require("ShadowMap").castCasts or 0
      run.tStart = now()
      return
    end
    run.frames = run.frames + 1
    run.time = run.time + (dt or 0)
    run.dts[#run.dts + 1] = (dt or 0) * 1000
    run.pendingMax = math.max(run.pendingMax, indexPending())
    local okG, st = pcall(love.graphics.getStats)
    if okG and st then
      run.draws = run.draws + (st.drawcalls or 0)
      run.canvases = run.canvases + (st.canvasswitches or 0)
      run.shaders = run.shaders + (st.shaderswitches or 0)
    end
    local okV, V3 = pcall(V.require, "Voxel3D")
    local cs = okV and V3 and V3.cullStats
    if cs and (cs.total or 0) > 0 then
      run.geo = (run.geo or 0) + cs.drawn / cs.total
      run.geoN = (run.geoN or 0) + 1
    end
  end
  if t > M.SETTLE + M.MEASURE and run.snap then
    local SM = V.require("ShadowMap")
    local secs = math.max(0.001, now() - run.tStart)
    local frames = math.max(1, run.frames)
    local step = stepOf(run.slot)
    local bgPer = (bgTotal() - (run.bg0 or 0)) / frames
    local rw = ((SM.worldCasts or 0) - run.recastW) / secs
    run.results[#run.results + 1] = {
      name = step[1], base = (step == BASE),
      tmid = (run.tStart + now()) / 2,
      ms = median(run.dts, .5), p90 = median(run.dts, .9),
      mean = 1000 * run.time / frames,
      rw = rw,
      rc = ((SM.castCasts or 0) - run.recastC) / secs,
      geo = run.geoN and run.geoN > 0 and run.geo / run.geoN or nil,
      cpu = delta(run.snap, snap(), frames),
      present = (presentMs - (run.present0 or 0)) / frames,
      bg = bgPer,
      disturbed = bgPer > 0.2 or run.pendingMax > 0,
      draws = run.draws / frames,
      canvases = run.canvases / frames,
      shaders = run.shaders / frames,
    }
    run.geo, run.geoN = nil, nil
    if run.slot < #run.plan then startSlot(run.slot + 1) else finish() end
  end
end

local function draw(g)
  if not (run or shown) then return end
  if shown and now() > shown.untilT then shown = nil; return end
  if not font then font = g.newFont(12) end
  local w, h = g.getDimensions()
  g.origin(); g.setShader(); g.setScissor(); g.setDepthMode(); g.setBlendMode("alpha")
  g.setFont(font)
  local lines
  if run and run.waiting then
    lines = { ("PERF PROBE: waiting for loading to finish (%.0fs)   -- stand still, don't open menus")
      :format(now() - run.waitT0) }
  elseif run then
    lines = { ("PERF PROBE %d/%d: %s   -- stand still, don't open menus")
      :format(run.slot or 0, #run.plan, run.slot and stepOf(run.slot)[1] or "") }
  else
    lines = shown.lines
  end
  local lh = font:getHeight()
  local widest = 0
  for _, line in ipairs(lines) do widest = math.max(widest, font:getWidth(line)) end
  local bw, bh = widest + 16, #lines * lh + 14
  local fit = math.min(1, math.max(1, w - 24) / bw, math.max(1, h - 64) / bh)
  g.translate(12, 52); g.scale(fit, fit)
  g.setColor(.03, .04, .06, .85); g.rectangle("fill", 0, 0, bw, bh, 6, 6)
  g.setColor(.75, 1, .8, 1)
  for i, line in ipairs(lines) do g.print(line, 8, 7 + (i - 1) * lh) end
end

function M.install()
  local mod = V.mod
  if not (mod and mod.hooks and mod.hooks.wrap) then return end
  mod.hooks:wrap("render.hud", function(next, game, viewport)
    local r1, r2, r3 = next(game, viewport)
    if love and love.graphics and love.timer then
      local ok = pcall(update, game, love.timer.getDelta())
      if not ok then pcall(finish, "probe error") end
      local g = love.graphics
      g.push("all"); pcall(draw, g); g.pop()
    end
    return r1, r2, r3
  end)
end

return M
