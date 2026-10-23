-- Observation views borrow the real map renderer's resources. No proxy city,
-- second simulation, synchronous mesh build, or private copy of its geometry.
local V=...
local M={MAX_MAPS=2,RANGE=512}
local C=V.require('ChunkMesher')
local R=V.require('Voxel3D')
local Mat=V.require('Mat4')
-- Small palette used only by the indoor window frames.
M.colors={{.24,.40,.20},{.12,.26,.15},{.36,.52,.25},{.23,.45,.60},
 {.59,.59,.53},{.78,.75,.65},{.39,.25,.21},{.20,.29,.32},
 {.91,.80,.48},{.85,.87,.82},{.12,.17,.23},{.47,.40,.55}}

function M.maps(origin,defs,x,z)
 local def=defs[origin];if not def then return {} end
 local out={{id=origin,def=def,x=0,z=0,d=-1}}
 local P=V.require('WorldPlacement');local root=P.position(origin,defs)
 if root then
  local candidates={}
  for id,d in pairs(defs)do
   if id~=origin and d.tileset=='OVERWORLD' and d.generation~=2 then
    local p=P.position(id,defs)
    if p and p.anchor==root.anchor then
     local ox,oz=p.x-root.x,p.y-root.y
     local dx=math.max(ox-x,0,x-ox-d.width*32)
     local dz=math.max(oz-z,0,z-oz-d.height*32)
     local distance=dx*dx+dz*dz
     if distance<=M.RANGE*M.RANGE then
      candidates[#candidates+1]={id=id,def=d,x=ox,z=oz,d=distance}
     end
    end
   end
  end
  table.sort(candidates,function(a,b)return a.d==b.d and a.id<b.id or a.d<b.d end)
  for i=1,math.min(#candidates,M.MAX_MAPS-1)do out[#out+1]=candidates[i]end
 end
 return out
end

function M.new(profile,defs)
 return {entries=M.maps(profile.city,defs,profile.x,profile.z),profile=profile}
end

local function activeMaps()
 local Game=require('src.core.Game');local ow=Game.overworld;local maps={}
 if ow and ow.map then maps[ow.map.id]=ow.map end
 for _,nb in ipairs(ow and ow.neighbors or {})do maps[nb.map.id]=nb.map end
 return maps,Game
end

function M.retain(scene,live,ids)
 for _,e in ipairs(scene and scene.entries or {})do
  if not live[e.id]then live[e.id]=true;if ids then ids[#ids+1]=e.id end end
 end
end

function M.close(scene)
 local live=activeMaps()
 for _,e in ipairs(scene and scene.entries or {})do
  -- Never dispose a resource a live gameplay map has adopted, or one which
  -- was already cached/queued before this observation view borrowed it.
  if e.owned and not live[e.id]then C.evictRuntime(e.id)end
 end
end

function M.pump(scene)
 local live,Game=activeMaps()
 local ready=true
 for i,e in ipairs(scene.entries)do
  if not e.map then
   e.map=live[e.id] or require('src.world.MapLoader').load(Game.data,e.id)
   if not e.map then error('Scenic map unavailable: '..e.id)end
   e.owned=not(C.slotKnown(e.map,true)or C.slotKnown(e.map,false)
    or C.jobPending(e.id,true)or C.jobPending(e.id,false))
  end
  -- Body geometry only: no duplicate map-border ring. The existing shared
  -- queue and frame budget own all geometry and tree uploads.
  C.request(e.map,true,nil,i==1 and 1.5 or 1)
  local visible
  e.mesh,e.water,visible,e.visuals=C.pair(e.map,true)
  if not e.mesh then
   if C.slotKnown(e.map,true)then
    if i==1 then error('Scenic terrain could not be built: '..e.id)end
   else ready=false end
  end
  if C.jobPending(e.id,true)then ready=false end
 end
 if not scene.state and scene.entries[1]and scene.entries[1].map then
  local p=scene.profile
  scene.state={map=scene.entries[1].map,player={px=p.x-8,py=p.z-8},neighbors={}}
  for i=2,#scene.entries do local e=scene.entries[i]
   scene.state.neighbors[#scene.state.neighbors+1]={map=e.map,ox=e.x,oy=e.z}
  end
 end
 scene.ready=ready and scene.state~=nil
 return scene.ready
end

function M.prepare(scene)
 local Scene=V.require('VoxelScene')
 -- Atlas generation precedes beginScene so it cannot steal its render target.
 for _,e in ipairs(scene.entries)do
  if e.mesh then
   e.atlas=Scene.warmAtlas(e.map)
   if not e.atlas then error('Scenic materials unavailable: '..e.id)end
  end
 end
end

function M.background(scene)
 local state=scene.state
 R.glass(false)
 V.require('SkyLayer').drawStars(state)
 V.require('Backdrop').draw(state)
 V.require('SkyLayer').drawForeground(state)
 R.glass(true)
end

function M.draw(scene,offset)
 for _,e in ipairs(scene.entries)do
  if e.mesh and e.atlas then
   local model=Mat.translate(e.x+(offset and offset[1]or 0),offset and offset[2]or 0,
    e.z+(offset and offset[3]or 0))
   -- Scenic views have no companion replacement pass: draw the originals.
   R.draw(e.mesh,e.atlas,model)
   for _,visual in ipairs(e.visuals or {})do R.draw(visual.mesh,e.atlas,model)end
   R.drawBattleWater(e.water,e.atlas,model)
   R.glass(false)
   R.draw(C.grass(e.map),e.atlas,model)
   R.draw(C.flowers(e.map),e.atlas,model)
   R.glass(true)
   V.require('LegendaryGarden').draw(e.map,nil,model)
   V.require('LegendaryTowerExterior').drawMap(e.map,model)
   if not offset then V.require('GranitePillars').draw(e.map,e.x,e.z)end
  end
 end
 -- Native trees are normally already in body geometry. Other selectable
 -- tree styles use their existing shared tree cache instead.
 if not offset then
  R.glass(false);V.require('CommunityFlora').drawCommunityTrees(scene.state);R.glass(true)
  V.require('StreetLights').draw(scene.state)
  V.require('SeasonalDecor').draw(scene.state,false)
 end
end
return M
