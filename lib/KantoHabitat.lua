-- Local, bounded habitat sampling. Never changes a map, collision or scenery.
local V=...;local M={}
local towns={
 PALLET_TOWN={kind='garden',insects=.85},VIRIDIAN_CITY={kind='woodland',insects=1},
 PEWTER_CITY={kind='rocky',insects=.5},CERULEAN_CITY={kind='river',insects=.75},
 VERMILION_CITY={kind='coast',insects=.45},LAVENDER_TOWN={kind='quiet',insects=.4},
 CELADON_CITY={kind='garden',insects=.8,legacy=true},FUCHSIA_CITY={kind='wetland',insects=1},
 SAFFRON_CITY={kind='urban',insects=.32},CINNABAR_ISLAND={kind='coast',insects=.35},
 INDIGO_PLATEAU={kind='rocky',insects=.35},
}
function M.profile(map)
 if not(map and map.tileset and map.def)then return end
 local id=map.id or '';local tid=map.tileset.id
 if id=='VIRIDIAN_FOREST'and tid=='FOREST'then
  if V.require('CommunityVisuals').customForest()then return {kind='woodland',insects=1,legacy=true}end
  return
 end
 if tid=='FOREST'and ({SAFARI_ZONE_CENTER=true,SAFARI_ZONE_EAST=true,SAFARI_ZONE_NORTH=true,SAFARI_ZONE_WEST=true})[id]then return {kind='wetland',insects=1}end
 if tid~='OVERWORLD'and tid~='PLATEAU'then return end
 if towns[id]then return towns[id]end
 local r=tonumber(id:match('^ROUTE_(%d+)$'))
 if r and r>=1 and r<=25 then
  return {kind=(r>=19 and r<=21)and 'coast'or(r==24 or r==25)and 'river'or(r==3 or r==4 or r==9 or r==10 or r==23)and 'rocky'or(r>=12 and r<=15)and 'wetland'or(r>=16 and r<=18)and 'cycle'or'woodland',insects=(r>=19 and r<=21)and .3 or .85}
 end
 -- Interiors, gates, ships and caves retain their own existing audio/effects.
end
local function key(x,z)return(z+64)*4096+x+64 end
-- Reconstruct the same deterministic garden plan after a disk mesh-cache hit.
-- This is a source-layout query only; it never emits or moves furniture.
function M.gardenPlan(map,S)
 local CV=V.require('CommunityVisuals');local streets=V.require('CityStreets')
 if not streets.enabled(map.id,CV.customRoads(),map.tileset.id)then return end
 local cityGround=CV.isCityGroundMap(map)
 local grass=(not cityGround and CV.customGrass())or(cityGround and map.id=='FUCHSIA_CITY'and CV.customCityGround())or false
 local courts=CV.customCourtyards();local variant=tostring(grass)..tostring(courts)
 S.cityStreetPlans91=S.cityStreetPlans91 or{}
 if not S.cityStreetPlans91[variant]then
  local function courtyard(x,z)
   if not courts then return false end
   local tile=S.tileAt[key(x,z)]
   if tile==91 or tile==16 or tile==33 then return true end
   if tile~=35 then return false end
   for dz=-1,1 do for dx=-1,1 do local t=S.tileAt[key(x+dx,z+dz)];if t==16 or t==33 then return true end end end
   return false
  end
  S.cityStreetPlans91[variant]=streets.plan(map,S,key,{grassEnabled=grass,courtyard=courtyard})
 end
 return S.cityStreetPlans91[variant]
end
function M.scan(map,S,px,pz)
 local out={green={},water=0,greenLevel=0};local W,H=map.def.width*4,map.def.height*4
 local tid=map.tileset.id;local bestG,bestW=1e9,1e9
 local gx,gz=math.floor(px/32),math.floor(pz/32)
 for iz=gz-3,gz+3 do for ix=gx-3,gx+3 do
  -- Deterministic location per 32px patch; no random respawn when turning.
  local tx,tz=ix*4+1,iz*4+1
  if tx>0 and tz>0 and tx<W-1 and tz<H-1 then
   local k=key(tx,tz);local shape=S.shapeAt[k];local tile=S.tileAt[k]
   local x,z=tx*8+4,tz*8+4;local dist=(x-px)^2+(z-pz)^2
   if shape and shape.class=='water'then bestW=math.min(bestW,dist)end
   local natural=shape and not S.skip[k]and (shape.class=='grass'or shape.class=='flower'or shape.art=='grass'or (shape.class=='ground'and shape.flat and ((tid=='FOREST'and (tile==48 or tile==52 or tile==55 or tile==57 or tile==94 or tile==95))or(tid=='OVERWORLD'and(tile==44 or tile==48 or(S.cityLawnCells and S.cityLawnCells[k]))))))
   if natural then
    local clear=true;local height=shape.h or 0
    for dz=-1,1 do for dx=-1,1 do local kk=key(tx+dx,tz+dz);local ss=S.shapeAt[kk]
     if not ss or S.skip[kk]or(ss.class~='ground'and ss.class~='grass'and ss.class~='flower')or math.abs((ss.h or 0)-height)>.5 then clear=false end
    end end
    if clear then
     out.green[#out.green+1]={x=x,z=z,y=height,seed=(ix*53+iz*97)%997}
     bestG=math.min(bestG,dist)
    end
   end
  end
 end end
 -- Paved city gardens can also host insects, without treating pavement as lawn.
 local CV=V.require('CommunityVisuals')
 local plan=M.gardenPlan(map,S)
 for _,f in ipairs((plan or{}).features or{})do
  if f.kind=='borderbed'or f.kind=='centerpiece'or f.kind=='rockgarden'then
   local d=(f.cx-px)^2+(f.cz-pz)^2
   if d<96^2 then out.green[#out.green+1]={x=f.cx,z=f.cz,y=(f.level or 0)+2,seed=math.floor(f.cx*7+f.cz*11)%997};bestG=math.min(bestG,d)end
  end
 end
 -- Reuse the accepted park's exact bed locations for daytime butterflies.
 if map.id=='CELADON_CITY'and CV.referenceBuildings()and CV.customRoads()then
  if not S.kantoLifePark109 then
   local park=V.require('CeladonPark')
   S.kantoLifePark109=park.plan(map,S,key,function(x,z)return park.paved(S.tileAt[key(x,z)],false)end)
  end
  for _,bed in ipairs(S.kantoLifePark109.beds or{})do
   local x,z=(bed.x0+bed.x1+1)*4,(bed.z0+bed.z1+1)*4;local d=(x-px)^2+(z-pz)^2
   local s=S.shapeAt[key(math.floor(x/8),math.floor(z/8))]
   if s and d<96^2 then out.green[#out.green+1]={x=x,z=z,y=(s.h or 0)+1,seed=math.floor(x*7+z*11)%997};bestG=math.min(bestG,d)end
  end
 end
 table.sort(out.green,function(a,b)return (a.x-px)^2+(a.z-pz)^2<(b.x-px)^2+(b.z-pz)^2 end)
 out.greenLevel=math.max(0,1-math.sqrt(bestG)/100)
 out.water=math.max(0,1-math.sqrt(bestW)/110)
 return out
end

-- LOADING-STUTTER: the habitat DIGEST. scan() above reads a map's whole
-- Structures analysis (44 MB for Route 22, 176 MB for Route 23) every quarter
-- second, so KantoLife used to build that analysis on the draw -- the 2.3 s
-- freeze crossing into Route 22 and the 1.5 s one out of the Route 22 gate --
-- and then keep it for as long as the map stayed near. digest() records, once,
-- exactly what scan() reads: per 32 px patch (one map block) whether its
-- sample cell is water and, if it is clear lawn, its height; the garden plan's
-- beds; Celadon's park beds. scanDigest() replays scan() from that record and
-- returns the identical habitat (same entries, order and levels), so the
-- analysis itself need not be kept. The record holds a few hundred numbers.
-- signature() names the settings scan() depends on; a digest made under
-- other settings is not used.
function M.signature()
 local CV=V.require('CommunityVisuals')
 local function v(name)local f=CV[name];if type(f)~='function'then return'-'end;local ok,r=pcall(f);return ok and tostring(r)or'!'end
 return v('customRoads')..v('customGrass')..v('customCityGround')..v('customCourtyards')..v('referenceBuildings')
end
-- scan()'s per-patch test, verbatim: water at the sample cell, and the height
-- of a clear natural cell (nil when it is not one)
local function classify(S,tid,tx,tz)
 local k=key(tx,tz);local shape=S.shapeAt[k];local tile=S.tileAt[k]
 local water=shape and shape.class=='water'or false
 local natural=shape and not S.skip[k]and (shape.class=='grass'or shape.class=='flower'or shape.art=='grass'or (shape.class=='ground'and shape.flat and ((tid=='FOREST'and (tile==48 or tile==52 or tile==55 or tile==57 or tile==94 or tile==95))or(tid=='OVERWORLD'and(tile==44 or tile==48 or(S.cityLawnCells and S.cityLawnCells[k]))))))
 if natural then
  local height=shape.h or 0
  for dz=-1,1 do for dx=-1,1 do local kk=key(tx+dx,tz+dz);local ss=S.shapeAt[kk]
   if not ss or S.skip[kk]or(ss.class~='ground'and ss.class~='grass'and ss.class~='flower')or math.abs((ss.h or 0)-height)>.5 then return water,nil end
  end end
  return water,height
 end
 return water,nil
end
function M.digest(map,S)
 local w,h=map.def.width,map.def.height
 local W,H=w*4,h*4;local tid=map.tileset.id
 local D={w=w,h=h,water={},green={},garden={},park={},sig=M.signature()}
 local Budget=V.require('BuildBudget')
 -- scan() only ever samples patches 0..w-1 x 0..h-1 (its bounds test)
 for iz=0,h-1 do
  Budget.tick()
  for ix=0,w-1 do
   local tx,tz=ix*4+1,iz*4+1
   if tx>0 and tz>0 and tx<W-1 and tz<H-1 then
    local water,height=classify(S,tid,tx,tz)
    local idx=iz*w+ix
    if water then D.water[idx]=true end
    if height~=nil then D.green[idx]=height end
   end
  end
 end
 local CV=V.require('CommunityVisuals')
 local plan=M.gardenPlan(map,S)
 for _,f in ipairs((plan or{}).features or{})do
  if f.kind=='borderbed'or f.kind=='centerpiece'or f.kind=='rockgarden'then
   D.garden[#D.garden+1]={x=f.cx,z=f.cz,y=(f.level or 0)+2,seed=math.floor(f.cx*7+f.cz*11)%997}
  end
 end
 if map.id=='CELADON_CITY'and CV.referenceBuildings()and CV.customRoads()then
  if not S.kantoLifePark109 then
   local park=V.require('CeladonPark')
   S.kantoLifePark109=park.plan(map,S,key,function(x,z)return park.paved(S.tileAt[key(x,z)],false)end)
  end
  for _,bed in ipairs(S.kantoLifePark109.beds or{})do
   local x,z=(bed.x0+bed.x1+1)*4,(bed.z0+bed.z1+1)*4
   local s=S.shapeAt[key(math.floor(x/8),math.floor(z/8))]
   if s then D.park[#D.park+1]={x=x,z=z,y=(s.h or 0)+1,seed=math.floor(x*7+z*11)%997}end
  end
 end
 return D
end
function M.scanDigest(map,D,px,pz)
 local out={green={},water=0,greenLevel=0};local w,h=D.w,D.h
 local bestG,bestW=1e9,1e9
 local gx,gz=math.floor(px/32),math.floor(pz/32)
 for iz=gz-3,gz+3 do for ix=gx-3,gx+3 do
  if ix>=0 and iz>=0 and ix<w and iz<h then
   local tx,tz=ix*4+1,iz*4+1
   local x,z=tx*8+4,tz*8+4;local dist=(x-px)^2+(z-pz)^2
   local idx=iz*w+ix
   if D.water[idx]then bestW=math.min(bestW,dist)end
   local y=D.green[idx]
   if y~=nil then
    out.green[#out.green+1]={x=x,z=z,y=y,seed=(ix*53+iz*97)%997}
    bestG=math.min(bestG,dist)
   end
  end
 end end
 for _,list in ipairs({D.garden,D.park})do
  for _,f in ipairs(list)do
   local d=(f.x-px)^2+(f.z-pz)^2
   if d<96^2 then out.green[#out.green+1]={x=f.x,z=f.z,y=f.y,seed=f.seed};bestG=math.min(bestG,d)end
  end
 end
 table.sort(out.green,function(a,b)return (a.x-px)^2+(a.z-pz)^2<(b.x-px)^2+(b.z-pz)^2 end)
 out.greenLevel=math.max(0,1-math.sqrt(bestG)/100)
 out.water=math.max(0,1-math.sqrt(bestW)/110)
 return out
end
-- A digest as plain text for the on-disk cache (KantoLife), and back. Numbers
-- are written with 17 significant digits, which read back to the same values;
-- `key` (the cache key the record was stored under) is checked on the way in.
-- Parsed, never executed; anything malformed reads as nil.
local function num(v)return string.format('%.17g',v)end
function M.encode(D,key)
 local lines={'KLD1',tostring(key),D.w..' '..D.h}
 local ids={};for idx in pairs(D.water)do ids[#ids+1]=idx end;table.sort(ids)
 lines[#lines+1]='W '..table.concat(ids,' ')
 ids={};for idx in pairs(D.green)do ids[#ids+1]=idx end;table.sort(ids)
 local g={};for i,idx in ipairs(ids)do g[i]=idx..'='..num(D.green[idx])end
 lines[#lines+1]='G '..table.concat(g,' ')
 for _,part in ipairs({{'B',D.garden},{'P',D.park}})do
  local f={};for i,e in ipairs(part[2])do f[i]=num(e.x)..','..num(e.z)..','..num(e.y)..','..num(e.seed)end
  lines[#lines+1]=part[1]..' '..table.concat(f,' ')
 end
 return table.concat(lines,'\n')..'\n'
end
function M.decode(bytes,key)
 if type(bytes)~='string'or #bytes>1048576 then return nil end
 local ok,D=pcall(function()
  local lines={};for l in bytes:gmatch('([^\n]*)\n')do lines[#lines+1]=l end
  assert(#lines==7 and lines[1]=='KLD1'and lines[2]==tostring(key))
  local w,h=lines[3]:match('^(%d+) (%d+)$');w,h=assert(tonumber(w)),assert(tonumber(h))
  local D={w=w,h=h,water={},green={},garden={},park={}}
  assert(lines[4]:sub(1,2)=='W ')
  for idx in lines[4]:sub(3):gmatch('%S+')do idx=assert(tonumber(idx));assert(idx>=0 and idx<w*h and idx%1==0);D.water[idx]=true end
  assert(lines[5]:sub(1,2)=='G ')
  for idx,v in lines[5]:sub(3):gmatch('(%d+)=(%S+)')do
   idx=assert(tonumber(idx));assert(idx<w*h);D.green[idx]=assert(tonumber(v))
  end
  for i,part in ipairs({{'B ',D.garden},{'P ',D.park}})do
   local l=lines[5+i];assert(l:sub(1,2)==part[1])
   for x,z,y,s in l:sub(3):gmatch('([^,%s]+),([^,%s]+),([^,%s]+),([^,%s]+)')do
    local e={x=assert(tonumber(x)),z=assert(tonumber(z)),y=assert(tonumber(y)),seed=assert(tonumber(s))}
    part[2][#part[2]+1]=e
   end
  end
  return D
 end)
 if ok then return D end
 return nil
end
return M
