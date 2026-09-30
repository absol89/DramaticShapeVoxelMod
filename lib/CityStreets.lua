-- TEST90: measured regional gardens, access corridors and actor-safe furniture.
local V=...;local C=V.require('SurfaceCraft');local M={}
M.themes={
 PALLET_TOWN={stone={.71,.65,.53},border={.81,.76,.64},accent={.58,.34,.24},flower={.91,.75,.59},limit=24,rooms=3,bed=8},
 VIRIDIAN_CITY={stone={.59,.62,.51},border={.77,.74,.61},accent={.39,.46,.32},flower={.93,.77,.47},limit=64,rooms=8,bed=12},
 PEWTER_CITY={stone={.55,.53,.48},border={.76,.68,.53},accent={.48,.35,.25},flower={.87,.72,.51},limit=64,rooms=8,bed=12},
 CERULEAN_CITY={stone={.62,.67,.67},border={.85,.78,.63},accent={.31,.46,.56},flower={.58,.74,.94},limit=64,rooms=8,bed=11},
 FUCHSIA_CITY={stone={.60,.55,.46},border={.78,.68,.53},accent={.54,.32,.24},flower={.91,.42,.65},limit=72,rooms=9,bed=13},
 SAFFRON_CITY={stone={.46,.48,.49},border={.80,.73,.58},accent={.58,.43,.27},flower={.93,.76,.46},limit=64,rooms=8,bed=10},
 ROUTE_17={stone={.34,.37,.38},border={.77,.73,.61},accent={.38,.44,.33},flower={.88,.72,.45},limit=84,rooms=10,bed=9},
}
M.focus={PALLET_TOWN={'OAKS_LAB','REDS_HOUSE','BLUES_HOUSE'},VIRIDIAN_CITY={'SCHOOL','POKECENTER','GYM'},PEWTER_CITY={'MUSEUM','GYM','POKECENTER'},CERULEAN_CITY={'GYM','BIKE_SHOP','POKECENTER'},FUCHSIA_CITY={'SAFARI_ZONE_GATE','MEETING_ROOM','WARDENS_HOUSE','POKECENTER'},SAFFRON_CITY={'SILPH','FIGHTING_DOJO','GYM','POKECENTER'}}
-- One shared cap includes seating borders, lawn islands and paved planters.
-- Percentage applies to eligible lawn area; paved planters also consume it.
M.planting={
 PALLET_TOWN={beds=3,area=.10,islands=1,borders=1,spacing=64},
 VIRIDIAN_CITY={beds=8,area=.09,islands=3,borders=2,spacing=72},
 PEWTER_CITY={beds=6,area=.08,islands=2,borders=2,spacing=88},
 CERULEAN_CITY={beds=8,area=.10,islands=3,borders=2,spacing=80},
 FUCHSIA_CITY={beds=11,area=.13,islands=4,borders=3,spacing=64},
 SAFFRON_CITY={beds=8,area=.10,islands=1,borders=2,spacing=64},
 ROUTE_17={beds=4,area=.035,islands=0,borders=0,spacing=192},
}
function M.enabled(id,roads,tileset)return roads and tileset=='OVERWORLD' and M.themes[id]~=nil end
function M.draw(g,id)
 local t=assert(M.themes[id]);local colors={t.stone,t.border,t.accent,{.22,.24,.24}}
 for band=0,3 do local base=colors[band+1];local ox=band%2*64;local oy=400+math.floor(band/2)*48
  for y=0,47 do for x=0,63 do
   local grain=(C.field(x/5,y/5,8801)-.5)*.075+(C.hash(x,y,8802)-.5)*.13
   local fleck=C.hash(x,y,8803);grain=grain+(fleck>.98 and .08 or fleck<.015 and -.06 or 0)
   g.setColor(base[1]+grain,base[2]+grain,base[3]+grain,1);g.rectangle('fill',ox+x,oy+y,1,1)
  end end
 end
 if id=='VIRIDIAN_CITY' or id=='CERULEAN_CITY'then V.require('BasinWater').draw(g)end
end
-- Claims synthesize a floor from source art. Never expose a facade/fence donor
-- as a ground texture; turf, bridge timber and known paving retain their roles.
function M.claimedGround(g)
 if not g then return g end
 if g==44 or g==48 or g==60 or g==91 then return g end
 return 57
end
function M.plan(map,S,key,options)
 options=options or {};local grassEnabled=options.grassEnabled~=false
 local t=M.themes[map.id];local P={cells={},features={},lamps={},rooms={},approaches={},approachCells={},theme=t}
 if not t then return P end
 local Gardens=V.require('DistrictGardens')
 local cycling=map.id=='ROUTE_17';local width,height=map.def.width*4,map.def.height*4
 local policy=M.planting[map.id];P.planting={count=0,area=0,cap=policy.beds}
 local dirs={{'n',0,-1},{'s',0,1},{'w',-1,0},{'e',1,0}}
 local function shape(x,z)return S.shapeAt[key(x,z)]end
 local function lawn(x,z)
  local k=key(x,z);local s=shape(x,z)
  return x>=1 and z>=1 and x<width-1 and z<height-1 and grassEnabled and s and s.class=='ground' and s.flat and not S.skip[k] and (S.tileAt[k]==44 or S.tileAt[k]==48 or (S.cityLawnCells and S.cityLawnCells[k])) and not(options.courtyard and options.courtyard(x,z))
 end
 local function path(x,z)
  local k=key(x,z);local s=shape(x,z);local tile=S.tileAt[k]
  return s and s.class=='ground' and s.flat and s.art~='grass' and not S.skip[k] and not lawn(x,z) and tile~=44 and tile~=48 and tile~=60 and not(S.cityLawnCells and S.cityLawnCells[k])
 end
 local access=V.require('DistrictAccess').new(map,S,key,lawn,path)
 P.access=access
 local function actorBlocked(a,b,c,d)return access.actorBlocked({a,b,c,d})end
 local function overlaps(a,b,gap)
  return a[3]+gap>b[1] and a[1]-gap<b[3] and a[4]+gap>b[2] and a[2]-gap<b[4]
 end
 local function valid(f,pending)
  local q=f.bounds;local a,b,c,d=q[1],q[2],q[3],q[4]
  if actorBlocked(a,b,c,d)then return false end
  if access.routeBlocked(q)then return false end
  if f.kind=='pergola' then
   -- A tall arch must not frame an existing sign as its apparent doorway.
   for _,sign in ipairs(map.signs or {})do
    if overlaps(q,{sign.x*16,sign.y*16,sign.x*16+16,sign.y*16+16},16)then return false end
   end
  end
  local level
  for z=math.floor(b/8),math.floor((d-.001)/8)do for x=math.floor(a/8),math.floor((c-.001)/8)do
   if not (f.paved and path(x,z) or not f.paved and lawn(x,z))then return false end
   local h=shape(x,z).h or 0;if level and math.abs(h-level)>.001 then return false end;level=h
  end end
  -- The whole visible footprint must clear neighboring signs, buildings,
  -- trees and source fences, even when its own grass cells were unclaimed.
  for z=math.floor((b-10)/8),math.floor((d+10)/8)do for x=math.floor((a-10)/8),math.floor((c+10)/8)do
   local k=key(x,z);local s=shape(x,z)
   if s and (S.skip[k] or (not s.flat and s.class~='flower' and s.class~='grass'))then
    local gap=s.class=='building' and 8 or 5
    if overlaps(q,{x*8,z*8,x*8+8,z*8+8},gap)then return false end
   end
  end end
  for _,v in ipairs(P.features)do if overlaps(q,v.bounds,3)then return false end end
  for _,v in ipairs(pending or {})do if overlaps(q,v.bounds,3)then return false end end
  f.level=level or 0;return true
 end
 local function feature(kind,x,z,rx,rz,edge)
  return {kind=kind,cx=x,cz=z,rx=rx,rz=rz,edge=edge,depthScale=.8,bounds={x-rx,z-rz,x+rx,z+rz}}
 end
 local function commit(f)
  if f.kind=='borderbed' or f.kind=='centerpiece' or f.kind=='rockgarden' then
   f.style=f.style or Gardens.style(map.id,#P.features+1,f.kind=='borderbed')
   P.planting.count=P.planting.count+1
   P.planting.area=P.planting.area+Gardens.area(f.style)*f.rx*f.rz
  end
  P.features[#P.features+1]=f
  if f.kind=='lamp'then P.lamps[#P.lamps+1]={f.cx,f.cz}end
  local q=f.bounds
  for z=math.floor(q[2]/8),math.floor((q[4]-.001)/8)do for x=math.floor(q[1]/8),math.floor((q[3]-.001)/8)do
   local k=key(x,z);P.cells[k]=P.cells[k]or {};P.cells[k][#P.cells[k]+1]=f
  end end
 end
 local lawnArea=0
 for z=0,height-1 do for x=0,width-1 do if lawn(x,z)then lawnArea=lawnArea+64 end end end
 P.planting.lawnArea=lawnArea;P.planting.maxArea=lawnArea*policy.area
 local function planted(f)return f.kind=='borderbed' or f.kind=='centerpiece' or f.kind=='rockgarden'end
 local function add(f)
  if planted(f)then
   -- Leave Cerulean's northern bridge arrival open, without an isolated bed.
   if map.id=='CERULEAN_CITY' and f.bounds[2]<64 then return false end
   f.style=f.style or Gardens.style(map.id,#P.features+1,f.kind=='borderbed')
   -- Avoid thin crescent tips: use the rounded waterfront/tropical outline
   -- when the available bed is too narrow for a generous curved inset.
   if f.style=='crescent' and math.min(f.rx,f.rz)<7 then f.style=map.id=='FUCHSIA_CITY' and 'tropical' or 'waterfront'end
   if P.planting.count>=policy.beds or P.planting.area+Gardens.area(f.style)*f.rx*f.rz>P.planting.maxArea then return false end
   for _,g in ipairs(P.features)do if planted(g) and (f.cx-g.cx)^2+(f.cz-g.cz)^2<policy.spacing^2 then return false end end
  end
  if #P.features<t.limit and valid(f)then commit(f);return true end
 end
 local anchors={}
 for _,name in ipairs(M.focus[map.id]or {})do for _,w in ipairs(map.def.warps or {})do
  if tostring(w.destMap or ''):find(name,1,true)then
   local x,z=w.x*2+1,w.y*2+1;local duplicate=false
   for _,a in ipairs(anchors)do if (a[1]-x)^2+(a[2]-z)^2<64 then duplicate=true end end
   if not duplicate then anchors[#anchors+1]={x,z}end
  end
 end end
 if cycling then for z=12,height-12,40 do anchors[#anchors+1]={width/2,z}end end
 if #anchors==0 then anchors={{width/2,height/2}}end
 local function ranked(candidates)
  local zones={};for i=1,#anchors do zones[i]={}end
  for _,p in ipairs(candidates)do local best,dist=1,math.huge
   for i,a in ipairs(anchors)do local d=(p.x-a[1])^2+(p.z-a[2])^2;if d<dist then best,dist=i,d end end
   p.zone=best;p.score=dist;zones[best][#zones[best]+1]=p
  end
  for _,zone in ipairs(zones)do
   table.sort(zone,function(a,b)if a.score~=b.score then return a.score<b.score elseif a.z~=b.z then return a.z<b.z elseif a.x~=b.x then return a.x<b.x else return (a.edge or '')<(b.edge or '') end end)
   for i,p in ipairs(zone)do p.rank=i end
  end
  table.sort(candidates,function(a,b)if a.rank~=b.rank then return a.rank<b.rank else return a.zone<b.zone end end)
  return candidates
 end
 local candidates,centers={},{}
 -- Coverage is balanced across the town, not only the closest landmark.
 local function district(x,z)return math.floor(x/(width/3))..':'..math.floor(z/(height/3))end
 local bedZones={}
 for z=2,height-2 do for x=2,width-2 do if lawn(x,z)then
  centers[#centers+1]={x=x,z=z}
  for _,d in ipairs(dirs)do if path(x+d[2],z+d[3])then candidates[#candidates+1]={x=x,z=z,edge=d[1],dx=d[2],dz=d[3]}end end
  -- Safari's upper gardens use walkable turf rather than paved streets.
  -- Seating can face those clear lawns with a building/fence behind it.
  if map.id=='FUCHSIA_CITY' and z<height*.55 then
   for _,d in ipairs(dirs)do
    local back=shape(x+d[2]*2,z+d[3]*2)
    if back and (back.class=='building' or back.class=='post')then
     local clear=true
     for step=1,3 do for side=-1,1 do
      if not lawn(x-d[2]*step+d[3]*side,z-d[3]*step+d[2]*side)then clear=false end
     end end
     if clear then candidates[#candidates+1]={x=x,z=z,edge=({n='s',s='n',w='e',e='w'})[d[1]],dx=-d[2],dz=-d[3]}end
    end
   end
  end
 end end end
 ranked(candidates);ranked(centers)
 -- A few town-specific destinations. All footprints use the same collision,
 -- actor, slope and structure checks as the seating groups.
 local amenities={PALLET_TOWN={kind='research',target='OAKS_LAB',rx=8,rz=4},
  VIRIDIAN_CITY={kind='pondDeck',water=true,rx=12,rz=7},
  PEWTER_CITY={kind='fossil',target='MUSEUM',rx=8,rz=5},
  CERULEAN_CITY={kind='pondDeck',water=true,rx=12,rz=7},
  FUCHSIA_CITY={kind='pergola',target='SAFARI',rx=12,rz=7},
  SAFFRON_CITY={kind='tree',rx=10,rz=10}}
 local spec=amenities[map.id]
 if spec and grassEnabled then
  local locations={}
  for _,p in ipairs(centers)do
   local score=math.huge;local edge='n'
   if spec.water then
    for _,d in ipairs(dirs)do for step=2,5 do
     local n=shape(p.x+d[2]*step,p.z+d[3]*step)
     if n and n.class=='water' and step*step<score then score=step*step;edge=d[1]end
    end end
   elseif spec.target then
    for _,w in ipairs(map.def.warps or {})do if tostring(w.destMap):find(spec.target,1,true)then
     score=math.min(score,(p.x-w.x*2-1)^2+(p.z-w.y*2-1)^2)
    end end
   else score=(p.x-width/2)^2+(p.z-height*.75)^2 end
   local nearPath=false;for _,d in ipairs(dirs)do for step=1,3 do if path(p.x+d[2]*step,p.z+d[3]*step)then nearPath=true end end end
   if (nearPath or map.id=='FUCHSIA_CITY') and score<576 then locations[#locations+1]={x=p.x,z=p.z,score=score,edge=edge}end
  end
  table.sort(locations,function(a,b)if a.score~=b.score then return a.score<b.score elseif a.z~=b.z then return a.z<b.z else return a.x<b.x end end)
  local placed=0
  for _,p in ipairs(locations)do if placed<(map.id=='SAFFRON_CITY' and 2 or 1)then
   local rx,rz=spec.rx,spec.rz
   if p.edge=='e' or p.edge=='w' then rx,rz=rz,rx end
   local f=feature(spec.kind,p.x*8+4,p.z*8+4,rx,rz,p.edge)
   -- Face a nearby clear path; reserve the approach before furnishing it.
   local approach
   for _,d in ipairs(dirs)do
    for step=1,(spec.kind=='pergola' and 12 or 4)do
     -- A pergola walk must meet a real path. Four arbitrary lawn cells made
     -- the old stepping boards stop in grass directly in front of the sign.
     if path(p.x+d[2]*step,p.z+d[3]*step)then
      local xx,zz=p.x*8+4+d[2]*step*8,p.z*8+4+d[3]*step*8
      local r=d[2]==0 and 6 or 4;local t=d[2]==0 and 4 or 6
      local q={math.min(f.cx,xx)-r,math.min(f.cz,zz)-t,math.max(f.cx,xx)+r,math.max(f.cz,zz)+t}
      local clear=not actorBlocked(q[1],q[2],q[3],q[4])
      local level
      for zz=math.floor(q[2]/8),math.floor((q[4]-.001)/8)do for xx=math.floor(q[1]/8),math.floor((q[3]-.001)/8)do
       if not(lawn(xx,zz) or path(xx,zz))then clear=false else
        local yy=shape(xx,zz).h or 0;if level and math.abs(yy-level)>.001 then clear=false end;level=yy
       end
      end end
      if clear then approach=q
       if not spec.water then f.edge=({n='s',s='n',w='e',e='w'})[d[1]];if d[2]~=0 then f.rx,f.rz=spec.rz,spec.rx else f.rx,f.rz=spec.rx,spec.rz end;f.bounds={f.cx-f.rx,f.cz-f.rz,f.cx+f.rx,f.cz+f.rz}end
       break
      end
     end
    end
    if approach then break end
   end
   if approach and add(f)then
    access.reserve(approach);f.approach=approach;placed=placed+1
    if spec.kind~='tree' then
     P.approaches[#P.approaches+1]=approach
     for zz=math.floor(approach[2]/8),math.floor((approach[4]-.001)/8)do for xx=math.floor(approach[1]/8),math.floor((approach[3]-.001)/8)do
      if lawn(xx,zz)then local k=key(xx,zz);P.approachCells[k]=P.approachCells[k]or {};P.approachCells[k][#P.approachCells[k]+1]=approach end
     end end
    end
   end
  end end
 end
 -- Non-floral detail gives each district useful-looking places and equipment.
 -- Use checked street edges, not the middle of an open lawn or riding lane.
 local function placeLife(civicFronts)
 local life=V.require('DistrictLife');local lifePlaced={}
 for _,spec in ipairs(life.specs[map.id] or {})do
  local choices={}
  for _,list in ipairs({candidates,civicFronts})do for _,p in ipairs(list)do
   local score=p.score or 0;local eligible=true
   if spec[5]then
    score=math.huge
    for _,w in ipairs(map.def.warps or {})do if tostring(w.destMap):find(spec[5],1,true)then score=math.min(score,(p.x-w.x*2-1)^2+(p.z-w.y*2-1)^2)end end
    eligible=score<900
   end
   if spec[6]then
    local near=false
    for _,d in ipairs(dirs)do for step=1,6 do local s=shape(p.x+d[2]*step,p.z+d[3]*step);if s and s.class=='water'then near=true;score=math.min(score,step*step)end end end
    eligible=eligible and near
   end
   if cycling then
    local along=math.min((p.z-height*.22)^2,(p.z-height*.72)^2)
    local seat=math.huge
    for _,r in ipairs(P.rooms)do seat=math.min(seat,(p.x-r[1]/8)^2+(p.z-r[2]/8)^2)end
    score=along+seat*2;eligible=eligible and seat<144
   end
   if eligible then choices[#choices+1]={p=p,score=score,paved=list==civicFronts}end
  end end
  table.sort(choices,function(a,b)if a.score~=b.score then return a.score<b.score elseif a.p.z~=b.p.z then return a.p.z<b.p.z elseif a.p.x~=b.p.x then return a.p.x<b.p.x else return a.p.edge<b.p.edge end end)
  local count=0
  for _,choice in ipairs(choices)do if count<spec[4]then
   local p=choice.p
   local inset=choice.paved and 0 or math.max(0,spec[3]-3.5)
   local a,b=p.x*8+4-p.dx*inset,p.z*8+4-p.dz*inset
   local clear=true
   for _,g in ipairs(lifePlaced)do
    local separation=g.kind==spec[1] and (cycling and height*8*.35 or 88) or (cycling and 24 or 44)
    if (a-g.cx)^2+(b-g.cz)^2<separation^2 then clear=false end
   end
   if clear then
    local rx,rz=spec[2],spec[3];if p.dx~=0 then rx,rz=rz,rx end
    local f=feature(spec[1],a,b,rx,rz,choice.paved and p.edge or ({n='s',s='n',w='e',e='w'})[p.edge])
    f.paved=choice.paved
    if add(f)then lifePlaced[#lifePlaced+1]=f;count=count+1 end
   end
  end end
 end
 P.lifeCount=#lifePlaced
 end
 if map.id~='SAFFRON_CITY' and not cycling then placeLife({})end
 -- A seating group commits its bench, lantern and bin together. There can be
 -- no stranded lamp/bin left behind after a failed bench placement.
 for _,p in ipairs(candidates)do if #P.rooms<t.rooms and #P.features+3<=t.limit then
  local a,b=p.x*8+4,p.z*8+4;local near=false
  for _,q in ipairs(P.rooms)do if (a-q[1])^2+(b-q[2])^2<(cycling and 112 or 64)^2 then near=true end end
  if not near then
   local tx,tz=p.dz,p.dx;local edge=({n='s',s='n',w='e',e='w'})[p.edge]
   if map.id~='SAFFRON_CITY' and not cycling and (#P.rooms%2==1)then tx,tz=-tx,-tz end
   local group={feature('bench',a,b,p.dx==0 and 10 or 3.6,p.dx==0 and 3.6 or 10,edge),feature('lamp',a+tx*15,b+tz*15,1.1,1.1),feature('bin',a-tx*16.5,b-tz*16.5,1.9,1.9)}
   local pending={};local good=true
   for _,f in ipairs(group)do if not valid(f,pending)then good=false;break end;pending[#pending+1]=f end
   if good then
    for _,f in ipairs(group)do commit(f)end;P.rooms[#P.rooms+1]={a,b}
    local bx,bz=a-p.dx*13,b-p.dz*13
    if P.planting.count<math.max(0,policy.beds-policy.islands-policy.borders)then add(feature(map.id=='PEWTER_CITY' and 'rockgarden' or 'borderbed',bx,bz,p.dx==0 and 10 or 5,p.dx==0 and 5 or 10))end
    if cycling then add(feature('bikeRack',a+tx*30,b+tz*30,p.dx==0 and 6 or 3,p.dx==0 and 3 or 6,edge))end
   end
  end
 end end
 -- Substantial planted islands occupy broad lawn interiors. A smaller town
 -- receives fewer islands; each one has a distinct, complete coping and fill.
 local beds=0;local islands={}
 table.sort(centers,function(a,b)
  local da,db=math.min(a.x,width-a.x,a.z,height-a.z),math.min(b.x,width-b.x,b.z,height-b.z)
  if da~=db then return da>db end
  if a.z~=b.z then return a.z<b.z else return a.x<b.x end
 end)
 for _,p in ipairs(centers)do if beds<policy.islands then
  local a,b=p.x*8+4,p.z*8+4;local clear=(bedZones[district(p.x,p.z)]or 0)<1
  for _,q in ipairs(islands)do if (a-q[1])^2+(b-q[2])^2<76^2 then clear=false end end
  if clear then
   local rx,rz=t.bed*(map.id=='SAFFRON_CITY' and 1.35 or 1.15),t.bed*(map.id=='CERULEAN_CITY' and .70 or .76)
   if not(lawn(p.x+2,p.z)and lawn(p.x-2,p.z))then rx,rz=rz,rx end
   local kind=map.id=='PEWTER_CITY' and 'rockgarden' or 'centerpiece'
   if beds==0 and (map.id=='VIRIDIAN_CITY' or map.id=='FUCHSIA_CITY')then kind='tree';rx=12;rz=12 end
   local f=feature(kind,a,b,rx,rz)
   f.style=Gardens.style(map.id,beds+1,false)
   if add(f)then beds=beds+1;islands[#islands+1]={a,b};bedZones[district(p.x,p.z)]=(bedZones[district(p.x,p.z)]or 0)+1 end
  end
 end end
 -- Paired lighting on long street edges fills the dark stretches between rooms.
 local lamps=0
 for _,p in ipairs(candidates)do if lamps<(cycling and 18 or map.id=='PALLET_TOWN' and 2 or 12)then
  local a,b=p.x*8+4,p.z*8+4;local clear=true
  for _,q in ipairs(P.lamps)do if (a-q[1])^2+(b-q[2])^2<56^2 then clear=false end end
  if clear and add(feature('lamp',a,b,1.1,1.1))then lamps=lamps+1 end
 end end
 local civicFronts={}
 -- Saffron's broad internal streets have no lawns. Place complete groups
 -- beside recessed building fronts, reserving a 32-unit walking corridor.
 if map.id=='SAFFRON_CITY' and grassEnabled then
  local fronts={}
  for z=5,height-6 do for x=8,width-9 do if path(x,z)then
   for _,d in ipairs(dirs)do
    local back=shape(x+d[2]*2,z+d[3]*2)
    if back and back.class=='building' then
     local clear=true
     for step=1,4 do for side=-1,1 do
      if not path(x-d[2]*step+d[3]*side,z-d[3]*step+d[2]*side)then clear=false end
     end end
     if clear then fronts[#fronts+1]={x=x,z=z,edge=d[1],dx=d[2],dz=d[3]}end
    end
   end
  end end end
  ranked(fronts);civicFronts=fronts;local count=0
  for _,p in ipairs(fronts)do if count<6 and #P.features+3<=t.limit then
   local a,b=p.x*8+4,p.z*8+4;local clear=true
   for _,q in ipairs(P.rooms)do if (a-q[1])^2+(b-q[2])^2<96^2 then clear=false end end
   if clear then
    local tx,tz=p.dz,p.dx
    local group={feature('bench',a,b,p.dx==0 and 10 or 3.6,p.dx==0 and 3.6 or 10,p.edge),feature('lamp',a+tx*15,b+tz*15,1.1,1.1),feature('bin',a-tx*16.5,b-tz*16.5,1.9,1.9)}
    local pending={};local good=true
    for _,f in ipairs(group)do f.paved=true;if not valid(f,pending)then good=false;break end;pending[#pending+1]=f end
    if good then
     for _,f in ipairs(group)do commit(f)end;P.rooms[#P.rooms+1]={a,b};count=count+1
     local bed=feature('borderbed',a+tx*34,b+tz*34,p.dx==0 and 10 or 4,p.dx==0 and 4 or 10)
     bed.paved=true;add(bed)
    end
   end
  end end
 end
 if map.id=='SAFFRON_CITY'then placeLife(civicFronts)end
 if cycling then placeLife({})end
 -- Small planted borders finish empty lawn margins, with broad quiet gaps.
 local borders=0
 for _,p in ipairs(candidates)do if borders<policy.borders then
  local a,b=p.x*8+4-p.dx*4,p.z*8+4-p.dz*4;local clear=true
  for _,q in ipairs(islands)do if (a-q[1])^2+(b-q[2])^2<40^2 then clear=false end end
  if clear then
   local f=feature('borderbed',a,b,p.dx==0 and 11 or 5,p.dx==0 and 5 or 11)
   if add(f)then borders=borders+1;islands[#islands+1]={a,b}end
  end
 end end
 local cache={}
 function P.cell(x,z)
  local k=key(x,z);if cache[k]then return cache[k][1],cache[k][2]end
  local style='stonePaving';local edges={frameMaterial='cityBorder',frameWidth=.8}
  for _,w in ipairs(map.def.warps or {})do
   local wx,wz=w.x*2+1,w.y*2+1
   if math.abs(x-wx)<=3 and z>=wz and z<=wz+2 then style='wineBrick';break end
  end
  for _,d in ipairs(dirs)do
   local s=shape(x+d[2],z+d[3]);local tile=S.tileAt[key(x+d[2],z+d[3])]
   if s and s.class=='building'then edges.frontage=true end
   if s and (s.class=='water' or s.class=='building' or s.class=='ledge' or tile==44 or (tile==48 and grassEnabled))then edges[d[1]]=true end
  end
  -- Material changes follow gardens and the waterfront, not arbitrary squares.
  if style=='stonePaving' then
   local water=false;local garden=false
   for _,d in ipairs(dirs)do
    local n=shape(x+d[2],z+d[3]);water=water or(n and n.class=='water')
    garden=garden or lawn(x+d[2],z+d[3])
   end
   if (map.id=='CERULEAN_CITY' and water) or (map.id=='FUCHSIA_CITY' and garden) then style='wineBrick' end
  end
  edges.sourceBorder=S.routeBorderTiles and S.routeBorderTiles[S.tileAt[k]] or false
  if edges.sourceBorder then edges.frontage=true end
  cache[k]={style,edges};return style,edges
 end
 P.signIslands={}
 if cycling then
  -- Discover source geometry, not only text events (ROM variants can move signs).
  for z=0,height-2,2 do for x=0,width-2,2 do
   local full=true
   for dz=0,1 do for dx=0,1 do local n=shape(x+dx,z+dz)
    if not(n and n.class=='signpost')then full=false end
   end end
   if full then P.signIslands[#P.signIslands+1]={x=x*8,z=z*8}end
  end end
 end
 P.roadSpan=function(x,z)
  local n=shape(x,z)
  return path(x,z) or cycling and n and n.class=='signpost'
 end
 P.isPath=path
 return P
end
function M.fixture(x,z,h,f,emit,id)return V.require('StreetFurniture').build(x,z,h+(f.paved and .25 or 0),f,emit,id)end
function M.approach(x,z,h,q,emit,id)
 local G=C.builder(x,z,emit)
 local wood=id=='FUCHSIA_CITY' or id=='VIRIDIAN_CITY'
 if id=='FUCHSIA_CITY'then
  -- Segmented timber stepping panels leave fine turf seams. This is a garden
  -- approach on traversable lawn, rather than a road dead-ending in grass.
  local alongZ=q[4]-q[2]>=q[3]-q[1]
  local start,finish=alongZ and q[2] or q[1],alongZ and q[4] or q[3]
  for t=start,finish-.2,5.5 do
   local last=math.min(t+4.75,finish)
   if alongZ then
    G.flat(q[1]+.4,t,q[3]-.4,last,h+.055,'wood',.94)
    G.flat(q[1]+.4,t,q[1]+.65,last,h+.058,'cityBorder',.8)
    G.flat(q[3]-.65,t,q[3]-.4,last,h+.058,'cityBorder',.8)
   else
    G.flat(t,q[2]+.4,last,q[4]-.4,h+.055,'wood',.94)
    G.flat(t,q[2]+.4,last,q[2]+.65,h+.058,'cityBorder',.8)
    G.flat(t,q[4]-.65,last,q[4]-.4,h+.058,'cityBorder',.8)
   end
  end
  return
 end
 G.flat(q[1],q[2],q[3],q[4],h+.035,'cityBorder',.9)
 G.flat(q[1]+.35,q[2]+.35,q[3]-.35,q[4]-.35,h+.045,wood and 'wood' or 'stonePaving',.98)
 if q[4]-q[2]>=q[3]-q[1] then
  for v=q[2]+6,q[4]-.5,6 do G.flat(q[1]+.35,v-.055,q[3]-.35,v+.055,h+.048,'pavingBand',.72)end
 else
  for u=q[1]+6,q[3]-.5,6 do G.flat(u-.055,q[2]+.35,u+.055,q[4]-.35,h+.048,'pavingBand',.72)end
 end
end
return M
