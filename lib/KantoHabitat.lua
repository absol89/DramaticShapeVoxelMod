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
return M
