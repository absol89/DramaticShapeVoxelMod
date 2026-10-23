-- Native Battle Art Seasonal Decor. One scheduler, loaded-neighborhood ownership,
-- and the same probed storage backend as terrain. No companion registration.
local V=...
local M={}
local mod=V.mod
local Disk=V.require('VoxelMeshDisk')
local Mesher=V.require('ChunkMesher')
local Budget=V.require('BuildBudget')
local RenderDistance=V.require('RenderDistance')
local Mat4=V.require('Mat4')
local R=V.require('Voxel3D')
local function module(name,...)
 local path='lib/seasonal/'..name..'.lua'
 return assert(load(assert(mod:read(path)),'@'..mod.path..'/'..path))(...)
end
local Settings=module('Settings',V);M.Settings=Settings
local G=module('Geometry')
G.checkpoint=function()
 Budget.check()
 local owner=G.owner
 if owner and coroutine.running() and love.timer.getTime()-owner.sliceStart>owner.sliceBudget then coroutine.yield()end
end
local SpiderGeometry=module('Geometry');SpiderGeometry.texture=G.texture
local Spiders=module('Spiders',V,SpiderGeometry,R);M.Spiders=Spiders
local Models=module('Models',G)
local Scene=module('Scene',G,Models)
local Placement=module('Placement')
local Bridge=module('HostBridge',mod,G)
local Effects=module('Effects',G)
local Pillars=module('PillarSnow')
local Snow=module('Snow',G,Pillars)
local Snowfall=module('Snowfall',G,Effects)
local Particles=module('Particles',G,Effects)
local Footprints=module('Footprints',G,Snow)
local private={id=mod.id,path=mod.path,log=mod.log,cache=Disk.seasonalCache(),assets={}}
function private:read(path)
 if path=='lib/Native.lua'then return mod:read('lib/SeasonalDecor.lua')end
 return mod:read((path:gsub('^lib/','lib/seasonal/')))
end
function private.assets:path(path)return mod.assets:path((path:gsub('^assets/audio/','assets/seasonal/audio/')))end
local Audio=module('SnowAudio',private,Snow)
local Cache=module('Cache',private,G)
local Runtime=module('Runtime',private,Settings,G,Scene,Placement,Bridge,Effects,Snow,Snowfall,Footprints,Pillars,Audio,Cache,Particles)
local records,visible={},{}
local rootId,previousId,epoch=nil,nil,0
local boundGame,installed,unhook=nil,false,nil
local clock=0
local function report(rec,err)
 rec.error=tostring(err)
 if rec.error~=rec.reported then rec.reported=rec.error;mod.log:error('Battle Art seasonal %s: %s',rec.map.id,rec.error)end
end
local function dispose(rec)
 rec.prepare=nil
 if rec.runtime then rec.runtime:dispose()end
end
function M.dispose()
 Spiders.dispose()
 for _,rec in pairs(records)do dispose(rec)end
 records,visible={},{};rootId,previousId,boundGame=nil,nil,nil
 -- Every runtime is gone: the shared atlas can go too (rebuilt on demand).
 G.releaseTexture()
end
local function relevantOptions(game)
 local options={}
 for id,values in pairs(game.mods and game.mods.modOptions or game.save and game.save.options and game.save.options.modOptions or {})do
  if id~='LEGENDARY_SEASONAL_DECOR' then
   local copy={}
   for k,v in pairs(values)do if id~=mod.id or not k:match('^seasonal')then copy[k]=v end end
   options[id]=copy
  end
 end
 local versions={}
 for _,entry in ipairs(game.mods and game.mods.loaded or {})do
  local manifest=entry.manifest
  if manifest then versions[manifest.id]=manifest.version end
 end
 return options,versions
end
local function authoredActors(map)
 local actors={}
 for _,o in ipairs(map.def and map.def.objects or {})do
  if not o.runtime and type(o.x)=='number'and type(o.y)=='number'then
   actors[#actors+1]={pose={x=o.x*16+8,z=o.y*16+8}}
  end
 end
 return actors
end
local function create(map,generation,game)
 local rec={map=map,generation=generation,epoch=epoch,last=clock}
 rec.prepare=coroutine.create(function()
  local snapshot,err=V.companion:seasonalSnapshot(map)
  assert(snapshot,err)
  snapshot.actors=authoredActors(map)
  local r=Runtime.new();rec.runtime=r
  local config,versions=relevantOptions(game)
  local native={V=V,R=R,version='1.11.5-seasonal-test167-spiders84-roof76-cerulean75',Budget=Budget}
  native.preparationKey=function(cache,live,options)
   return cache:key({host=Disk.fingerprint(live,'body',nil,'terrain'),
    blocks=live.def and live.def.blocks,actors=snapshot.actors,
    config=config,mods=versions,holiday=options.holiday,density=options.density,
    treeSpot=options.treeSpots and options.treeSpots[live.id],planVersion=live.id=='OAKS_LAB' and 'lab-clear-floor-41' or live.id=='GAME_CORNER' and 'casino-clear-floor-40' or 'classic-tree-8',
    treeSize=options.treeSize,interiors=options.interiors,groundSnow=options.groundSnow})
  end
  r.bridge=native;r.snapshot=snapshot;r.world={map=map}
 end)
 return rec
end
local function addVisible(map,x,z,bodyOnly,game)
 if not(map and map.id)then return end
 local ready,generation=Mesher.seasonalState(map,bodyOnly)
 local rec=records[map.id]
 if rec and(rec.generation~=generation or rec.epoch~=epoch or rec.map~=map)then dispose(rec);records[map.id]=nil;rec=nil end
 if ready and not rec then rec=create(map,generation,game);records[map.id]=rec end
 if rec then
  rec.last=clock;rec.ready=ready;rec.ox=x;rec.oz=z;rec.bodyOnly=bodyOnly
  visible[#visible+1]=rec
 end
end
local function busy(rec)
 local r=rec.runtime
 return rec.prepare or(r and(r.pending or r.job or r.snowJob or r.pillarJob
  or Settings.decorRevision~=r.revision or Settings.snowRevision~=r.snowRevision))
end
function M.update(game,dt)
 Settings.tick()
 clock=clock+math.min(.1,math.max(0,tonumber(dt)or 0))
 local state=game and game.overworld
 if not(state and state.map and V.companion)then return end
 Settings.bindGame(game);Settings.migrate(game);local options=Settings.all()
 local spiderReady=Mesher.seasonalState(state.map,false)or Mesher.seasonalState(state.map,true)
 Spiders.update(spiderReady and state or nil,dt,options)
 -- TEST156: Halloween moon tint (sky disc + water reflection). Cheap: a table swap.
 do
  local DN=V.require('DayNight');local m,h=options.moon,options.holiday
  local on=(h=='halloween'and(m=='halloween'or m=='both'))or(h=='harvest'and m=='both')
  DN.MOON_OVERRIDE=on and DN.HARVEST_MOON_COLORS or nil
 end
 if options.holiday=='off'then if next(records)then M.dispose()end;return end
 if boundGame~=game then
  -- RAM precache OFF must not leave native seasonal persistence unbound.
  if not Disk.available()then Disk.bind(game,false)end
  boundGame=game
 end
 if rootId~=state.map.id then previousId=rootId;rootId=state.map.id end
 visible={};addVisible(state.map,0,0,false,game)
 for _,nb in ipairs(state.neighbors or {})do
  if RenderDistance.neighbor(nb,state.player)then addVisible(nb.map,nb.ox or 0,nb.oy or 0,true,game)end
 end
 local keep={[rootId]=true};if previousId then keep[previousId]=true end
 for _,rec in ipairs(visible)do keep[rec.map.id]=true end
 for id,rec in pairs(records)do if not keep[id]then dispose(rec);records[id]=nil end end
 -- One construction budget for the entire neighborhood, never one per map.
 local chosen
 for _,rec in ipairs(visible)do if rec.ready and not rec.error and busy(rec)then chosen=rec;break end end
 local seconds=state.player and state.player.moving and .003 or .006
 for _,rec in ipairs(visible)do
  local background=rec.map.id~=rootId
  if rec==chosen and rec.prepare then
   Budget.begin(rec.prepare,seconds,4)
   local ok,err=coroutine.resume(rec.prepare);Budget.finish()
   if not ok then report(rec,err);dispose(rec)
   elseif coroutine.status(rec.prepare)=='dead'then rec.prepare=nil end
  elseif rec.runtime and rec.ready then
   local r=rec.runtime
   r.frame={time=V.require('DayNight').time(),mapId=rec.map.id}
   local scene={map=rec.map,player=not background and state.player or nil}
   local ok,err=pcall(r.pump,r,{overworld=scene,save=game.save},dt,rec==chosen and seconds or 0,background)
   if not ok then report(rec,err);dispose(rec)end
  end
 end
end
function M.draw(state,late)
 if not(state and state.map)or Settings.get('holiday')=='off'then return end
 if not late then Spiders.draw(state,Settings.all())end
 -- Render the current frame's actual neighborhood. Never use stale offsets
 -- from the update immediately before a seam crossing.
 local function draw(map,x,z,background)
  local rec=map and records[map.id];local r=rec and rec.runtime
  if not(r and r.alive and r.decorReady)or rec.error then return end
  local model=(x~=0 or z~=0)and Mat4.translate(x,0,z)or nil
  local ok,err=pcall(r.draw,r,late,model,background)
  if not ok then report(rec,err)end
 end
 draw(state.map,0,0,false)
 for _,nb in ipairs(state.neighbors or {})do if RenderDistance.neighbor(nb,state.player)then draw(nb.map,nb.ox or 0,nb.oy or 0,true)end end
end
-- Battle pass: host map at the origin, neighbors at their offsets.
function M.drawBattle(host,neighbors,late)
 if not(host and host.id)or Settings.get('holiday')=='off'then return end
 local function one(map,model,root)
  local rec=map and records[map.id];local r=rec and rec.runtime
  if not(r and r.alive)or rec.error then return end
  local ok,err=pcall(r.drawBattle,r,late,model,root)
  if not ok then report(rec,err)end
 end
 one(host,nil,true)
 for _,nb in ipairs(neighbors or {})do
  if nb.map then one(nb.map,Mat4.translate(nb.ox or 0,0,nb.oy or 0),false)end
 end
end
function M.status()
 local options=Settings.all()
 local out={integration='Battle Art TEST26',backend=private.cache.backend(),current=rootId,maps={},
  choice=options.holidayChoice,holiday=options.holiday}
 for id,rec in pairs(records)do
  local s={preparing=rec.prepare~=nil,error=rec.error}
  for k,v in pairs(rec.runtime and rec.runtime.stats or {})do s[k]=v end
  out.maps[id]=s
 end
 return out
end
M.statusSetting={key='seasonalStatus'}
Settings.settings[#Settings.settings+1]=M.statusSetting
local names={christmas='CHRISTMAS',halloween='HALLOWEEN',harvest='HARVEST',easter='EASTER',july='JULY 4TH'}
local function statusText()
 local options=Settings.all()
 if options.holiday=='off'then return options.holidayChoice=='auto'and 'AUTO: NO EVENT TODAY'or 'OFF'end
 local rec=rootId and records[rootId];local r=rec and rec.runtime
 if rec and rec.error then return 'LOAD ERROR'end
 if not r then return 'WAITING FOR TERRAIN'end
 local s=r.stats
 if s.state=='build failed'or s.snowState=='failed'then return 'LOAD ERROR'end
 if s.coverage=='none'then return 'NOTHING TO DECORATE HERE'end
 if not r.decorReady then return 'DECOR '..tostring(s.completed or 0)..'/'..tostring(s.placements or 0)end
 if s.snowState=='building'then return 'PACKING SNOW'end
 local complete,total=0,0
 for _,other in ipairs(visible)do
  total=total+1
  local stats=other.runtime and other.runtime.stats
  if stats and stats.state=='ready'then complete=complete+1 end
 end
 if complete<total then return 'NEARBY '..complete..'/'..total end
 if s.cacheError or s.cacheAvailable==false or private.cache.backend()=='legacy-read' or private.cache.backend()=='unbound'then return 'READY / SESSION ONLY'end
 return s.preparationCache=='hit'and 'READY / RESTORED'or 'READY'
end
function M.statusRow()
 return{id=mod.id..':seasonalStatus',label='SEASONAL STATUS',optionSetting=M.statusSetting,value=function()
  local text=statusText();local options=Settings.all()
  if options.holidayChoice=='auto'and options.holiday~='off'then return 'AUTO '..names[options.holiday]..': '..text end
  return text
 end}
end
-- TOWN TREE SPOT: right = put this town's tree where the player stands,
-- left = back to automatic placement.
M.treeSetting=V.require('ModSetting').new('seasonalTreeSpot','TOWN TREE SPOT',
 {'auto','move'},{'AUTO','MOVE HERE'},1)
-- Register a real schema entry so the mod-manager page offers this action too.
table.insert(Settings.settings,4,M.treeSetting)
table.insert(Settings.entries,4,{M.treeSetting,
 'Stand where you want this town tree, then choose MOVE HERE. Applies to Christmas and Halloween. AUTO restores automatic placement. To move again, choose AUTO then MOVE HERE.',full=true})
function M.treeRow()
 return{id=mod.id..':seasonalTreeSpot',label='TOWN TREE SPOT',optionSetting=M.treeSetting,
  value=function()
   local g=boundGame;local map=g and g.overworld and g.overworld.map
   if not(map and map.id)then return 'AUTO'end
   if not Placement.towns[map.id]then return 'TOWNS ONLY'end
   return Settings.treeSpot(map.id)and 'MOVED HERE  < AUTO'or 'AUTO  > MOVE HERE'
  end,
  step=function(game,dir)
   local st=game and game.overworld;local map=st and st.map;local p=st and st.player
   if not(map and map.id and Placement.towns[map.id])then return true end
   if (dir or 1)>0 and p then
    Settings.setTreeSpot(game,map.id,(p.px or p.x or 0)+8,(p.py or p.y or 0)+8)
   else Settings.setTreeSpot(game,map.id,nil)end
   return true
  end}
end
function M.treeSetting:row()return M.treeRow()end
function M.treeOptionChanged(game,value)
 if value~='auto'and value~='move'then return end
 M.treeRow().step(game,value=='move'and 1 or -1)
end
function M.install()
 if installed then return end;installed=true
 unhook=mod.hooks:wrap('core.update',function(next,game,dt)
  local result=next(game,dt);M.update(game,dt);return result
 end)
 mod.events:on('mod.options_changed',function(p)
  if not p then return end
  if p.mod==mod.id and p.key=='seasonalTreeSpot'then M.treeOptionChanged(boundGame,p.value)end
  if p.mod==mod.id and Settings.changed(p.key,p.value)then return end
  epoch=epoch+1
 end)
 mod.events:on('map.reloaded',function(p)
  if p and p.reason=='colors'then return end
  local id=p and(p.mapId or p.map and p.map.id)
  if id and records[id]then dispose(records[id]);records[id]=nil end
 end)
 mod.events:on('world.block_replaced',function(p)
  local id=p and(p.mapId or p.map and p.map.id)
  if id and records[id]then dispose(records[id]);records[id]=nil end
 end)
 mod.hooks:wrap('core.quit_to_launcher',function(next,...)
  M.dispose();if unhook then unhook();unhook=nil end;return next(...)
 end)
end
return M
