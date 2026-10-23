-- TEST242: ONLY WHAT THE CAMERA SEES, DURING THE PARADE, WHATEVER SITS IN FRONT
--
-- Battle Art draws a big map mesh in pieces: Voxel3D.drawCulled works out
-- which runs of it are on screen and hands them to Voxel3D.draw as its 6th
-- argument ("ranges"). A Collection before TEST81 replaces Voxel3D.draw with
-- its Grass + Flowers wrapper, which passes on only five arguments, so the
-- runs never arrive and every visible map is drawn WHOLE: at Celadon's main
-- street ~10.2 million terrain vertices a frame instead of ~0.8-1.9 million.
--
-- This puts the runs on the mesh itself before the call goes down the chain:
-- the runs are gathered into a few spans (Mesh:setDrawRange), and each span is
-- drawn by one ordinary call through whatever Voxel3D.draw is installed (the
-- Collection's wrapper still sees every call, so its grass and flower
-- branches behave as before), passing that span's own runs as the 6th
-- argument. Where the 6th argument arrives (Battle Art alone, or Collection
-- TEST81) Battle Art's submit draws exactly those runs and resets the range;
-- where it is dropped the span is drawn. Either way nothing that is on screen
-- is left out: a span covers every run inside it. The range is reset after.
--
-- Used only while the parade runs (ChampionParade wraps drawCulled with
-- M.drawCulled). Any error: that call, and from then on every call, goes to
-- the original drawCulled unchanged.
local V = ...
local M = { REVISION = 'parade-cull-perf1' }
M.K = 128         -- at most this many spans per mesh (one draw call each)
M.MINGAP = 256    -- gaps of fewer vertices than this are drawn through
M.broken = false
M.forwards = nil  -- true once a call shows the 6th argument reaches submit
M.stats = { calls = 0, spans = 0, verts = 0, exact = 0 }
-- The native culler projects eight corners for every indexed terrain block.
-- Wide shots revisit thousands of blocks as the camera tracks the float.
-- Test the same boxes against precomputed clip planes instead, and accept
-- a whole coarse box when it lies completely inside every plane. This does
-- not change the camera, geometry, visible runs, or Collection draw chain.
M.FAST_CULL = true
M.fastBroken = false
M.fastStats = { frames = 0, boxes = 0, inside = 0, outside = 0, cached = 0 }

local floor = math.floor
local memo = setmetatable({}, { __mode = 'k' })

local min, max = math.min, math.max
local function planesFor(vp, ox, oz)
  local p = {}
  for i = 1, 5 do
    local row = i <= 2 and 0 or 4
    local sign = i % 2 == 1 and 1 or -1
    local a, b, c, d = vp[13], vp[14], vp[15], vp[16]
    if i < 5 then
      a, b, c, d = a + sign * vp[row + 1], b + sign * vp[row + 2],
        c + sign * vp[row + 3], d + sign * vp[row + 4]
    end
    d = d + a * ox + c * oz
    p[i] = { a, b, c, d, 1e-7*(1+math.abs(a)+math.abs(b)+math.abs(c)+math.abs(d)) }
  end
  return p
end

-- 0 outside, 1 crossing a plane, 2 wholly inside. The padding and curved
-- height interval are the native culler's, including negative curvature.
local function classify(p, k, fx, fz, pad, x0, y0, z0, x1, y1, z1, whole)
  x0, y0, z0, x1, y1, z1 = x0-pad, y0-pad, z0-pad, x1+pad, y1+pad, z1+pad
  if k ~= 0 then
    local ax, bx, az, bz = x0-fx, x1-fx, z0-fz, z1-fz
    local dmax = max(ax*ax,bx*bx) + max(az*az,bz*bz)
    local dmin = ((ax<=0 and bx>=0) and 0 or min(ax*ax,bx*bx))
      + ((az<=0 and bz>=0) and 0 or min(az*az,bz*bz))
    if k > 0 then y0, y1 = y0-k*dmax, y1-k*dmin
    else y0, y1 = y0-k*dmin, y1-k*dmax end
  end
  local inside = whole
  for i = 1, 5 do
    local q = p[i]
    local a, b, c, d = q[1], q[2], q[3], q[4]
    local hi = a*(a>=0 and x1 or x0) + b*(b>=0 and y1 or y0) + c*(c>=0 and z1 or z0) + d
    -- Tiny rounding differences at a clip edge may retain one extra box;
    -- they must never remove a box the native projection could show.
    if hi < -q[5] then return 0 end
    if inside then
      local lo = a*(a>=0 and x0 or x1) + b*(b>=0 and y0 or y1) + c*(c>=0 and z0 or z1) + d
      if lo <= q[5] then inside = false end
    end
  end
  return inside and 2 or 1
end

local function fastRanges(R, mesh, idx, ox, oz)
  local vp = R.vp
  local k, pad = R.curveK or 0, R.CULL_PAD or 3
  local fx, fz = (R.curveX or 0)-ox, (R.curveZ or 0)-oz
  local cache = idx.cache
  if cache and cache.ox==ox and cache.oz==oz and cache.k==k and cache.fx==fx
      and cache.fz==fz and cache.n==idx.nb then
    local same = true
    for i=1,16 do if cache.vp[i]~=vp[i] then same=false;break end end
    if same then M.fastStats.cached=M.fastStats.cached+1;return cache.ranges,cache.drawn end
  end
  local planes = planesFor(vp,ox,oz)
  local ranges, drawn, first, last = {}, 0, nil, nil
  local total, bv = mesh:getVertexCount(), idx.bv
  local x0,y0,z0,x1,y1,z1 = idx.x0,idx.y0,idx.z0,idx.x1,idx.y1,idx.z1
  local st=M.fastStats
  st.frames=st.frames+1
  for s=1,idx.ns do
    local state=0
    if idx.sx0[s]<=idx.sx1[s] then
      st.boxes=st.boxes+1
      state=classify(planes,k,fx,fz,pad,idx.sx0[s],idx.sy0[s],idx.sz0[s],idx.sx1[s],idx.sy1[s],idx.sz1[s],true)
    end
    if state==0 then st.outside=st.outside+1
    else
      if state==2 then st.inside=st.inside+1 end
      for b=(s-1)*16+1,min(idx.nb,s*16) do
        local visible=x0[b]<=x1[b]
        if visible and state~=2 then
          st.boxes=st.boxes+1
          visible=classify(planes,k,fx,fz,pad,x0[b],y0[b],z0[b],x1[b],y1[b],z1[b])~=0
        end
        if visible then
          local a,e=(b-1)*bv+1,min(total,b*bv)
          if last and last+1==a then last=e
          else
            if first then ranges[#ranges+1]=first;ranges[#ranges+1]=last-first+1;drawn=drawn+last-first+1 end
            first,last=a,e
          end
        end
      end
    end
  end
  if first then ranges[#ranges+1]=first;ranges[#ranges+1]=last-first+1;drawn=drawn+last-first+1 end
  local indexed=idx.nb*bv
  if total>indexed then ranges[#ranges+1]=indexed+1;ranges[#ranges+1]=total-indexed;drawn=drawn+total-indexed end
  local cp={};for i=1,16 do cp[i]=vp[i] end
  idx.cache={ox=ox,oz=oz,k=k,fx=fx,fz=fz,n=idx.nb,vp=cp,ranges=ranges,drawn=drawn,total=total}
  return ranges,drawn
end
M._fastRanges=fastRanges

local function cull(R, original, mesh, texture, model, pull, sunModel, ox, oz)
  local idx=R.meshIndex and R.meshIndex[mesh]
  local probe=V and V.perfProbe
  -- Let the native implementation build/refresh its coarse index first.
  -- Its original fallbacks also own pending, mismatched and unindexed meshes.
  if M.FAST_CULL and not M.fastBroken and idx and idx.nb and idx.nb>0 and not idx.bad
      and (idx.pending or 0)==0 and idx.finalN==idx.nb and idx.ns and R.CULL and R.vp
      and mesh.setDrawRange and not(probe and probe.noCull) then
    local okCount,count=pcall(mesh.getVertexCount,mesh)
    if okCount and count==idx.verts then
      local ok,ranges,drawn=pcall(fastRanges,R,mesh,idx,ox or 0,oz or 0)
      if ok then
        R.cullStats.drawn=R.cullStats.drawn+drawn
        R.cullStats.total=R.cullStats.total+count
        if #ranges==0 then return end
        return R.draw(mesh,texture,model,pull,sunModel,ranges)
      end
      M.fastBroken=true;M.fastError=tostring(ranges)
    end
  end
  return original(mesh,texture,model,pull,sunModel,ox,oz)
end

-- { start, count, ... } -> { {a, n, sub}, ... } with at most K spans
local function groupsFor(ranges)
  local g = memo[ranges]
  if g then return g end
  local n = floor(#ranges / 2)
  g = {}
  if n == 0 then memo[ranges] = g; return g end
  -- the gaps between consecutive runs; split at the K-1 widest that are wide
  local gaps = {}
  for i = 1, n - 1 do
    local endI = ranges[2 * i - 1] + ranges[2 * i] - 1
    local gap = ranges[2 * i + 1] - endI - 1
    if gap >= M.MINGAP then gaps[#gaps + 1] = { i = i, w = gap } end
  end
  table.sort(gaps, function(p, q) if p.w ~= q.w then return p.w > q.w end return p.i < q.i end)
  local split = {}
  for j = 1, math.min(#gaps, (M.K or 6) - 1) do split[gaps[j].i] = true end
  local cur = nil
  for i = 1, n do
    local s, c = ranges[2 * i - 1], ranges[2 * i]
    if not cur then cur = { a = s, e = s + c - 1, sub = {} } end
    local sub = cur.sub
    sub[#sub + 1] = s; sub[#sub + 1] = c
    if s + c - 1 > cur.e then cur.e = s + c - 1 end
    if split[i] or i == n then
      g[#g + 1] = { a = cur.a, n = cur.e - cur.a + 1, sub = cur.sub }
      cur = nil
    end
  end
  memo[ranges] = g
  return g
end
M._groupsFor = groupsFor

local REAL = nil   -- the Voxel3D.draw in place when drawCulled was entered
local function rangedDraw(mesh, texture, model, pull, sunModel, ranges)
  local real = REAL
  if not (ranges and #ranges >= 2 and type(mesh) ~= 'nil' and mesh.setDrawRange) then
    return real(mesh, texture, model, pull, sunModel, ranges)
  end
  local st = M.stats
  if M.forwards then
    st.calls = st.calls + 1
    return real(mesh, texture, model, pull, sunModel, ranges)
  end
  local groups = groupsFor(ranges)
  local ok, err = pcall(function()
    for i = 1, #groups do
      local gr = groups[i]
      mesh:setDrawRange(gr.a, gr.n)
      real(mesh, texture, model, pull, sunModel, gr.sub)
      st.calls, st.spans, st.verts = st.calls + 1, st.spans + 1, st.verts + gr.n
      if M.forwards == nil and mesh.getDrawRange then
        -- submit resets the range after drawing the runs it was given: then
        -- the chain forwards them and one call with all of them will do
        local okG, a = pcall(mesh.getDrawRange, mesh)
        if okG and a == nil then M.forwards = true end
      end
    end
  end)
  pcall(mesh.setDrawRange, mesh)
  if not ok then error(err, 0) end
end

-- wraps an original drawCulled; `active()` says whether to step in
function M.wrap(V3, origCulled, active)
  return function(mesh, texture, model, pull, sunModel, ox, oz)
    if M.broken or not (active and active()) then
      return origCulled(mesh, texture, model, pull, sunModel, ox, oz)
    end
    local real = V3.draw
    if type(real) ~= 'function' or real == rangedDraw then
      return origCulled(mesh, texture, model, pull, sunModel, ox, oz)
    end
    REAL = real
    V3.draw = rangedDraw
    local ok, err = pcall(cull, V3, origCulled, mesh, texture, model, pull, sunModel, ox, oz)
    V3.draw = real
    REAL = nil
    if not ok then
      -- (once broken, always the plain path; this call drawn the plain way)
      M.broken = true
      M.error = tostring(err)
      pcall(function() if mesh and mesh.setDrawRange then mesh:setDrawRange() end end)
      return origCulled(mesh, texture, model, pull, sunModel, ox, oz)
    end
  end
end

function M.reset()
  memo = setmetatable({}, { __mode = 'k' })
  M.stats = { calls = 0, spans = 0, verts = 0, exact = 0 }
  M.fastStats = { frames = 0, boxes = 0, inside = 0, outside = 0, cached = 0 }
end

return M
