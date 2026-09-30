-- Cinnabar furniture uses its approved coastal paving and existing atlas.
-- No city-ground override: the three-color stone pattern remains untouched.
local V=...;local M={}
function M.plan(map,S,key)
 local P={features={},cells={},lamps={},beds=0}
 if map.id~='CINNABAR_ISLAND'then return P end
 local function path(x,z)
  if x<1 or z<1 or x>=map.def.width*4-1 or z>=map.def.height*4-1 then return false end
  local k=key(x,z);local s=S.shapeAt[k];local t=S.tileAt[k]
  -- Both 44 and 48 are paved by the existing Cinnabar coastal override.
  return s and s.class=='ground' and s.flat and not S.skip[k] and s.art~='grass' and t~=60 and t~=91
 end
 local access=V.require('DistrictAccess').new(map,S,key,function()return false end,path)
 local function valid(f,pending)
  local q=f.bounds
  if access.actorBlocked(q) or access.routeBlocked(q)then return false end
  local level
  for z=math.floor(q[2]/8),math.floor((q[4]-.001)/8)do for x=math.floor(q[1]/8),math.floor((q[3]-.001)/8)do
   if not path(x,z)then return false end
   local y=S.shapeAt[key(x,z)].h or 0;if level and y~=level then return false end;level=y
  end end
  for _,list in ipairs({P.features,pending or {}})do for _,g in ipairs(list)do if V.require('DistrictAccess').overlap(q,g.bounds,2)then return false end end end
  -- Water railings, source signs and wall bases all retain their own space.
  for z=math.floor(q[2]/8)-1,math.floor(q[4]/8)+1 do for x=math.floor(q[1]/8)-1,math.floor(q[3]/8)+1 do
   local s=S.shapeAt[key(x,z)]
   if s and (S.skip[key(x,z)] or s.class=='water' or not s.flat) and V.require('DistrictAccess').overlap(q,{x*8,z*8,x*8+8,z*8+8},2)then return false end
  end end
  return true
 end
 local function feature(kind,x,z,rx,rz,edge)
  return {kind=kind,cx=x,cz=z,rx=rx,rz=rz,edge=edge,depthScale=.8,style='coastal',bounds={x-rx,z-rz,x+rx,z+rz}}
 end
 local function commit(f)
  P.features[#P.features+1]=f
  for z=math.floor(f.bounds[2]/8),math.floor((f.bounds[4]-.001)/8)do for x=math.floor(f.bounds[1]/8),math.floor((f.bounds[3]-.001)/8)do
   local k=key(x,z);P.cells[k]=P.cells[k]or {};P.cells[k][#P.cells[k]+1]=f
  end end
 end
 local candidates={}
 for z=3,map.def.height*4-4 do for x=3,map.def.width*4-4 do if path(x,z)then
  for _,d in ipairs({{0,-1,'n'},{0,1,'s'},{-1,0,'w'},{1,0,'e'}})do
   local back=S.shapeAt[key(x+d[1]*2,z+d[2]*2)]
   if back and (back.class=='building' or back.class=='water')then
    local open=true
    -- Keep a 24-unit-deep, 24-unit-wide passage in front of each seat/bed.
    for step=1,3 do for side=-1,1 do if not path(x-d[1]*step+d[2]*side,z-d[2]*step+d[1]*side)then open=false end end end
    if open then candidates[#candidates+1]={x=x*8+4,z=z*8+4,dx=d[1],dz=d[2],edge=d[3],water=back.class=='water'}end
   end
  end
 end end end
 table.sort(candidates,function(a,b)if a.z~=b.z then return a.z>b.z elseif a.x~=b.x then return a.x<b.x else return a.edge<b.edge end end)
 P.candidateCount=#candidates
 -- TEST92: a coastal seat should face the water, away from through alleys.
 -- Search for shore views beyond the entire clear seating approach. Reuse
 -- the existing full-footprint, actor, rail, level and group checks below.
 local seaSeats={}
 for z=3,map.def.height*4-4 do for x=3,map.def.width*4-4 do if path(x,z)then
  for _,d in ipairs({{0,-1,'s'},{0,1,'n'},{-1,0,'e'},{1,0,'w'}})do
   local water=S.shapeAt[key(x+d[1]*5,z+d[2]*5)]
   if water and water.class=='water' then
    local open=true
    for step=1,4 do for side=-1,1 do
     if not path(x+d[1]*step+d[2]*side,z+d[2]*step+d[1]*side)then open=false end
    end end
    if open then seaSeats[#seaSeats+1]={x=x*8+4,z=z*8+4,dx=-d[1],dz=-d[2],edge=d[3]}end
   end
  end
 end end end
 table.sort(seaSeats,function(a,b)if a.z~=b.z then return a.z>b.z elseif a.x~=b.x then return a.x<b.x else return a.edge<b.edge end end)
 local function seatApproach(p)
  -- Seats face away from their back direction, toward the water. Include enough
  -- lateral clearance for two people, not only the center tile.
  local x,z=p.x-p.dx*28,p.z-p.dz*28
  local rx,rz=p.dx==0 and 16 or 3.6,p.dx==0 and 3.6 or 16
  return {math.min(p.x,x)-rx,math.min(p.z,z)-rz,math.max(p.x,x)+rx,math.max(p.z,z)+rz}
 end
 local seats={}
 for _,p in ipairs(seaSeats)do if #seats<1 then
  local near=false;for _,q in ipairs(seats)do if (p.x-q.x)^2+(p.z-q.z)^2<72^2 then near=true end end
  if not near then
   local bench=feature('bench',p.x,p.z,p.dx==0 and 10 or 3.6,p.dx==0 and 3.6 or 10,p.edge)
   local approach=seatApproach(p)
   local clear=not access.actorBlocked(approach) and not access.routeBlocked(approach);local level
   for z=math.floor(approach[2]/8),math.floor((approach[4]-.001)/8)do for x=math.floor(approach[1]/8),math.floor((approach[3]-.001)/8)do
    if not path(x,z)then clear=false else
     local y=S.shapeAt[key(x,z)].h or 0;if level and y~=level then clear=false end;level=y
    end
   end end
   for _,g in ipairs(P.features)do if V.require('DistrictAccess').overlap(approach,g.bounds)then clear=false end end
   -- Bin goes beyond the reserved approach rather than within it.
   local bin=feature('bin',p.x+p.dz*20,p.z+p.dx*20,1.9,1.9)
   if clear and valid(bench) and valid(bin,{bench})then
    commit(bench);commit(bin);bench.approach=approach;access.reserve(approach);seats[#seats+1]=p
   end
  end
 end end
 local details={}
 for _,s in ipairs(V.require('DistrictLife').specs.CINNABAR_ISLAND)do
  for _,p in ipairs(candidates)do if p.water or s[1]=='coastalCrates' then
   local near=false;for _,g in ipairs(details)do if (p.x-g.cx)^2+(p.z-g.cz)^2<44^2 then near=true end end
   local f=feature(s[1],p.x,p.z,p.dx==0 and s[2] or s[3],p.dx==0 and s[3] or s[2],p.edge)
   if not near and valid(f)then commit(f);details[#details+1]=f;break end
  end end
 end
 P.lifeCount=#details;P.access=access
 for _,p in ipairs(candidates)do if P.beds<1 then
  local f=feature('borderbed',p.x,p.z,p.dx==0 and 8 or 4,p.dx==0 and 4 or 8,p.edge)
  local near=false;for _,g in ipairs(P.features)do if g.kind=='borderbed' and (f.cx-g.cx)^2+(f.cz-g.cz)^2<72^2 then near=true end end
  if not near and valid(f)then commit(f);P.beds=P.beds+1 end
 end end
 return P
end
function M.build(x,z,h,f,emit)
 return V.require('StreetFurniture').build(x,z,h+.46,f,emit,'CINNABAR_ISLAND')
end
return M
