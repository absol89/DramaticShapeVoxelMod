local mod,Settings,G,Scene,Placement,HostBridge,Effects,Snow,Snowfall,Footprints,PillarSnow,SnowAudio,Cache,Particles=...
local M={};M.__index=M
local function release(resource)if resource and resource.release then pcall(resource.release,resource)end end
local function releaseList(list)for _,mesh in ipairs(list or {})do release(mesh)end end
function M.new()
 local self=setmetatable({alive=true,meshes={},snowMeshes={},glows={{},{},{},{}},clock=0,revision=-1,snowRevision=-1,
  footprints=Footprints.new(),snowAudio=SnowAudio.new(),cache=Cache.new(),pillarMeshes={},stats={state='waiting for Battle Art'}},M)
 if not self.cache.available then mod.log:warn('Seasonal persistent cache API unavailable; using generated scenery.')end

 return self
end
function M:clearSnow()
 self.cache:cancel()
 self.snowJob=nil;releaseList(self.snowMeshes);self.snowMeshes={};self.surface=nil;self.pillarRecord=nil
 self.pillarJob=nil;releaseList(self.pillarMeshes);self.pillarMeshes={};self.snowSource=nil;self.pillarSignature=nil;self.pillarSeen=nil
 releaseList(self.pendingPillars);self.pendingPillars=nil;self.snowAudio:reset()
 self.footprints:clear();self.footprintsBlocked=false
 self.stats.snowGroundTiles=nil;self.stats.snowCapTriangles=nil;self.stats.snowVertices=nil;self.stats.snowPillars=nil
end
function M:clear()
 self.job=nil;self.batch=nil;self:clearSnow();self.snowPending=true
 releaseList(self.meshes)
 for _,group in ipairs(self.glows)do releaseList(group)end
 self:clearParticles()
 if self.snowfall then self.snowfall:dispose();self.snowfall=nil end
 self.snowfallBlocked=nil;self.footprintsBlocked=false
 self.snowAudio:reset()
 self.meshes={};self.glows={{},{},{},{}};self.sceneId=nil;self.nativeSource=nil;self.pending=true;self.decorReady=false
end
function M:clearParticles()
 for _,fx in pairs(self.particles or {})do pcall(fx.dispose,fx)end
 self.particles={};self.particleBlocked={}
end
function M:dispose()
 -- The atlas is shared by every map (Geometry.texture); never release it here.
 self.alive=false;self:clear();self.texture=nil
 self.snapshot=nil;self.world=nil;self.stats={state='disabled'}
 self.snowAudio:dispose()
end
-- TEST26: every display on a map shares a few large meshes. TEST25 gave each
-- display its own mesh plus up to four glow meshes (90-360 draws per town).
local BATCH=60000
-- Each finished batch is its own small cache part, hashed and written as it
-- completes; one large entry would hash and write every byte in one frame.
function M:beginBatches(key,slot)
 self.batch={base={},glow={{},{},{},{}},key=key,slot=slot,parts=0,failed=not key}
end
function M:savePart(data,kind,group)
 local b=self.batch
 if b.failed then return end
 b.parts=b.parts+1
 local writer=self.cache:begin(b.slot..'-p'..b.parts,b.key)
 if not writer then b.failed=true;return end
 self.cache:append(writer,data,kind,group)
 if not self.cache:save(writer,{part=b.parts})then b.failed=true end
end
function M:flushBase(force)
 local b=self.batch;local data=b.base
 if #data>=BATCH or(force and #data>0)then
  self.meshes[#self.meshes+1]=love.graphics.newMesh(G.FORMAT,data,'triangles','static')
  self:savePart(data,'decor');b.base={};G.checkpoint()
 end
end
function M:flushGlow(i,force)
 local b=self.batch;local data=b.glow[i]
 if #data>=BATCH or(force and #data>0)then
  self.glows[i][#self.glows[i]+1]=love.graphics.newMesh(G.FORMAT,data,'triangles','static')
  self:savePart(data,'glow',i);b.glow[i]={};G.checkpoint()
 end
end
function M:upload(g)
 local b=self.batch
 for i=1,#g.vertices,3 do
  local a=g.vertices[i];local luminous=a[6]>64;local group=1
  if luminous and a[6]>=66 then group=1+math.floor(G.hash(math.floor(a[1]*2),math.floor(a[2]*2),math.floor(a[3]*2))*4)end
  local base,glow=b.base,b.glow[group]
  for j=i,i+2 do local v=g.vertices[j];if luminous then v[6]=1;glow[#glow+1]=v end;base[#base+1]=v end
  if #base>=BATCH then self:flushBase()end
  if luminous and #glow>=BATCH then self:flushGlow(group)end
  if i%3072==1 then G.checkpoint()end
 end
 self.stats.vertices=self.stats.vertices+#g.vertices
 self.stats.lights=self.stats.lights+g.lights;self.stats.ornaments=self.stats.ornaments+g.ornaments;self.stats.props=self.stats.props+g.props
end
function M:displays(plan,options)
 local key=self.cache:key({kind='displays',host=self.bridge.version,items=plan.items,holiday=options.holiday,density=options.density})
 local slot=key and self.cache:slot(self.sceneId,options.holiday,'displays')
 local manifest=self.cache:load(slot,key)
 if manifest and type(manifest.stats.parts)=='number'and manifest.stats.parts>=0 and manifest.stats.parts<=256 then
  -- Restored meshes go straight into the runtime's own lists, so clear()
  -- releases them even if this job is dropped between parts.
  local ok=true
  for k=1,manifest.stats.parts do
   local part=self.cache:load(slot..'-p'..k,key)
   if not part then ok=false;break end
   for _,b in ipairs(part.batches)do
    local list=b.kind=='glow'and self.glows[b.group]or self.meshes;list[#list+1]=b.mesh
   end
   G.checkpoint()
  end
  if ok then
   for _,name in ipairs({'vertices','lights','ornaments','props'})do self.stats[name]=self.stats[name]+(manifest.stats[name]or 0)end
   self.stats.decorCacheHits=#plan.items;self.stats.completed=#plan.items
   return
  end
  -- A missing part: release what was restored and generate afresh.
  releaseList(self.meshes);self.meshes={}
  for i=1,4 do releaseList(self.glows[i]);self.glows[i]={}end
 end
 self:beginBatches(key,slot)
 for i,item in ipairs(plan.items)do
  local g=Scene.build(item,options);self:upload(g)
  self.stats.completed=i;self.stats.decorGenerated=i;G.checkpoint()
 end
 self:flushBase(true);for i=1,4 do self:flushGlow(i,true)end
 local b=self.batch;self.batch=nil
 if not b.failed then
  -- The manifest goes last: a partial set of parts is never trusted.
  self.cache:save(self.cache:begin(slot,key),{parts=b.parts,vertices=self.stats.vertices,lights=self.stats.lights,ornaments=self.stats.ornaments,props=self.stats.props})
 end
 -- TEST25 stored one cache file per display; those can never match again.
 if self.cache.available and not self.legacyPurged then
  self.legacyPurged=true
  for i=1,#plan.items+48 do
   self.cache:remove(self.cache:slot(self.sceneId,options.holiday,'display-'..i))
   if i%16==0 then G.checkpoint()end
  end
 end
end
function M:startBuild()
 local options=Settings.all();self:clear();self.pending=false;self.revision=Settings.decorRevision
 if options.holiday=='off'then self.texture=nil;self.snowAudio:dispose();self.stats={state='off'};return end
 local snapshot,world=self.snapshot,self.world
 if not(snapshot and world and world.map and world.map.id==snapshot.id)then self.pending=true;return end
 self.stats={state='building decorations',map=snapshot.id,holiday=options.holiday,vertices=0,lights=0,ornaments=0,props=0,completed=0,placements=0}
 self.sceneId=snapshot.id
 self.loadStart=love.timer.getTime();self.stats.buildCPUSeconds=0
 self.job=coroutine.create(function()
  if not self.texture then self.texture=G.texture()end
  local prepKey=self.bridge.preparationKey and self.bridge.preparationKey(self.cache,world.map,options)
  local prepSlot=prepKey and self.cache:slot(snapshot.id,options.holiday,'prepared')
  local prepared=self.cache:load(prepSlot,prepKey)
  local info,plan
  if prepared then
   info={parkFeatures=prepared.stats.parkFeatures};plan=prepared.stats.plan
   self.nativeSource=prepared.stats.source;self.stats.preparationCache='hit'
  else
   info=HostBridge.info(self.bridge,world.map,snapshot)
   plan=Placement.plan(snapshot,info,options,G.checkpoint)
   if prepKey and Snow.enabled(snapshot,options)and plan.coverage~='none'then
    self.nativeSource=Snow.withoutPillars(Snow.sources(self.bridge,world.map,snapshot,info))
   end
   if prepKey then self.cache:save(self.cache:begin(prepSlot,prepKey),{plan=plan,source=self.nativeSource,parkFeatures=info.parkFeatures})end
   self.stats.preparationCache='built'
  end
  self.info=info;self.stats.parkFeatures=info.parkFeatures or 0
  if info.parkError then mod.log:warn('Seasonal park clearance: %s',info.parkError)end
  self.plan=plan;self.stats.placements=#plan.items;self.stats.coverage=plan.coverage
  coroutine.yield()
  -- Christmas displays load first. Snow owns a separate job and allocations;
  -- a snow error or a snow option change cannot remove these decorations.
  self:displays(plan,options)
  self.stats.drawCalls=#self.meshes;for _,group in ipairs(self.glows)do self.stats.drawCalls=self.stats.drawCalls+#group end
  self.decorReady=true;self.stats.decorReady=true;self.stats.state='building snow'
  self.stats.decorLoadSeconds=love.timer.getTime()-self.loadStart
  mod.log:info('Seasonal Decor %s %s: %d displays, %d bulbs, %d ornaments, %d triangles in %d meshes',snapshot.id,options.holiday,
   self.stats.placements,self.stats.lights,self.stats.ornaments,math.floor(self.stats.vertices/3),self.stats.drawCalls)
 end)
end
function M:winter(source,slotName,receive)
 -- Hash the actual supported surfaces, after other companions' replacements.
 -- Cosmetic sky time, particles, actor movement and SFX do not invalidate snow.
 local key=self.cache:snowKey({kind=slotName,host=self.bridge.version,map=self.sceneId,
  tiles=source.tiles,faces=source.faces,doors=source.doors,pillars=source.pillarSignature})
 local slot=key and self.cache:slot(self.sceneId,'winter',slotName)
 local cached=self.cache:load(slot,key)
 local winter
 if cached then
  for _,b in ipairs(cached.batches)do receive(b.mesh,b.kind)end
  winter=cached.stats;self.stats[slotName..'Cache']='hit'
 else
  local writer=self.cache:begin(slot,key)
  winter=Snow.build(source,function(g)
   local mesh=love.graphics.newMesh(G.FORMAT,g.vertices,'triangles','static');receive(mesh,g.snowKind)
   self.cache:append(writer,g.vertices,g.snowKind)
  end)
  self.cache:save(writer,{surface=winter.surface,groundTiles=winter.groundTiles,capTriangles=winter.capTriangles,
   vertices=winter.vertices,pillars=winter.pillars,warning=winter.warning})
  self.stats[slotName..'Cache']=self.cache.available and 'built'or 'unavailable'
 end
 winter.pillarRecord=source.pillarRecord;winter.pillarSignature=source.pillarSignature
 return winter
end
function M:startSnow()
 self:clearSnow();self.snowPending=false;self.snowRevision=Settings.snowRevision
 if not(Snow.enabled(self.snapshot,Settings.all())and self.plan.coverage~='none')then
  self.stats.snowState='off';self.stats.state='ready';return
 end
 self.stats.snowState='building';self.stats.state='building snow'
 local snapshot,map,info=self.snapshot,self.world.map,self.info
 self.snowJob=coroutine.create(function()
  local sources=self.nativeSource
  if not sources then
   if self.bridge.preparationKey then info=HostBridge.info(self.bridge,map,snapshot)end
   sources=Snow.sources(self.bridge,map,snapshot,info)
  end
  self.snowSource=sources
  -- Terrain-built pillars publish later than static structures. Keep their
  -- cache separate so early/late publication never invalidates the whole town.
  -- Ground under solid pillar bases stays hidden by the host's own geometry.
  local winter=self:winter(Snow.withoutPillars(sources),'snow',function(mesh)
   self.snowMeshes[#self.snowMeshes+1]=mesh
  end)
  local pillars=self:winter(Snow.refreshPillars(self.bridge,self.sceneId,sources),'pillars',function(mesh)
   self.pillarMeshes[#self.pillarMeshes+1]=mesh
  end)
  winter.pillarRecord=pillars.pillarRecord;winter.pillarSignature=pillars.pillarSignature;winter.pillars=pillars.pillars
  winter.vertices=winter.vertices+pillars.vertices;winter.capTriangles=winter.capTriangles+pillars.capTriangles
  self.surface=winter.surface;self.pillarRecord=winter.pillarRecord
  self.pillarSignature=winter.pillarSignature
  self.stats.snowGroundTiles=winter.groundTiles;self.stats.snowCapTriangles=winter.capTriangles
  self.stats.snowVertices=winter.vertices;self.stats.snowPillars=winter.pillars
  self.stats.snowState='ready';self.stats.state='ready'
  self.stats.loadSeconds=love.timer.getTime()-self.loadStart
  mod.log:info('Seasonal ready: %.2fs elapsed, %.2fs generation CPU',self.stats.loadSeconds,self.stats.buildCPUSeconds)
  mod.log:info('Seasonal cache: %d/%d displays restored; snow %s; pillars %s',self.stats.decorCacheHits or 0,
   self.stats.placements,self.stats.snowCache or 'off',self.stats.pillarsCache or 'off')
  if winter.warning then mod.log:warn('Seasonal snow fixture: %s',winter.warning)end
 end)
end
function M:refreshPillars()
 self.pendingPillars={};self.stats.pillarRefreshes=(self.stats.pillarRefreshes or 0)+1
 self.pillarJob=coroutine.create(function()
  local source=Snow.refreshPillars(self.bridge,self.sceneId,self.snowSource)
  local winter=self:winter(source,'pillars',function(mesh)
   self.pendingPillars[#self.pendingPillars+1]=mesh
  end)
  releaseList(self.pillarMeshes);self.pillarMeshes=self.pendingPillars;self.pendingPillars=nil
  self.pillarRecord=winter.pillarRecord;self.pillarSignature=winter.pillarSignature;self.stats.snowPillars=winter.pillars
 end)
end
function M:pump(game,dt,budget,background)
 if not self.alive then return end
 dt=math.min(.1,math.max(0,tonumber(dt)or 0));self.clock=self.clock+dt;self.world=game and game.overworld
 if not self.bridge then return end
 Settings.all() -- observe native ModSetting changes before testing revisions
 if Settings.decorRevision~=self.revision then self.pending=true end
 if self.pending then self:startBuild()end
 if Settings.snowRevision~=self.snowRevision then self.snowPending=true end
 if self.decorReady and self.snowPending then self:startSnow()end
 local job=self.job or self.snowJob or self.pillarJob
 if job and budget~=0 then
  G.owner=self
  -- Preserve the tested 3ms budget while walking. Standing still offers a
  -- bounded 6ms construction slice; no blocking whole-town build.
  local p=self.world and self.world.player
  self.sliceBudget=budget or (p and p.moving and .003 or .006)
  self.sliceStart=love.timer.getTime()
  if self.bridge.Budget then self.bridge.Budget.begin(job,self.sliceBudget,4)end
  local ok,err=coroutine.resume(job)
  if self.bridge.Budget then self.bridge.Budget.finish()end
  G.owner=nil
  self.stats.buildCPUSeconds=(self.stats.buildCPUSeconds or 0)+love.timer.getTime()-self.sliceStart
  if not ok then
   if job==self.pillarJob then
    self.pillarJob=nil;releaseList(self.pendingPillars);self.pendingPillars=nil;self.pillarPoll=self.clock+10
    self.stats.pillarError=tostring(err)
   elseif job==self.snowJob then
    self:clearSnow();self.snowPending=false;self.stats.state='ready';self.stats.snowState='failed';self.stats.snowError=tostring(err)
   else self.batch=nil;self:clear();self.pending=false;self.stats.state='build failed';self.stats.error=tostring(err)end
   mod.log:error('Seasonal build: %s',tostring(err))
  elseif coroutine.status(job)=='dead'then if job==self.job then self.job=nil elseif job==self.snowJob then self.snowJob=nil else self.pillarJob=nil end end
 end
 if not(self.world and self.world.map and self.sceneId==self.world.map.id and self.texture)then return end
 self.stats.cacheAvailable=self.cache.available;self.stats.cacheHits=self.cache.hits;self.stats.cacheWrites=self.cache.writes
 self.stats.cacheError=self.cache.error
 if self.cache.error and self.cache.error~=self.reportedCacheError then
  self.reportedCacheError=self.cache.error;mod.log:warn('Seasonal cache: %s',self.cache.error)
 end
 local options=Settings.all();local outdoor=self.snapshot and self.snapshot.tags and self.snapshot.tags.outdoor
 local covered=outdoor and self.plan and self.plan.coverage~='none'
 local want=not background and covered and options.holiday=='christmas'and options.snowfall~='off'
 if not want then self.snowfallBlocked=nil end
 if not options.footprints then self.footprintsBlocked=false end
 if self.snowfall and (not want or self.snowfall.mode~=options.snowfall)then self.snowfall:dispose();self.snowfall=nil end
 if want and not self.snowfall and self.snowfallBlocked~=options.snowfall then
  local ok,fx=pcall(Snowfall.new,options.snowfall)
  if ok then self.snowfall=fx else self.stats.snowfallError=tostring(fx);self.snowfallBlocked=options.snowfall end
 end
 local p=self.world.player or {};local px,pz=(p.px or p.x or 0)+8,(p.py or p.y or 0)+8
 if self.snowfall then
  local ok,err=pcall(self.snowfall.update,self.snowfall,self.clock,px,pz)
  if ok then
   self.stats.snowfallRenderer=self.snowfall.shader and 'GPU animated'or 'indexed CPU fallback'
   self.stats.snowfallUploads=self.snowfall.uploads
  else self.stats.snowfallError=tostring(err);self.snowfallBlocked=options.snowfall;self.snowfall:dispose();self.snowfall=nil end
 else self.stats.snowfallRenderer='off'end
 local footprintOK,footprintError=pcall(self.footprints.update,self.footprints,p,self.surface,self.clock,dt,
  not background and not self.footprintsBlocked and options.footprints and options.holiday=='christmas'and options.groundSnow=='full')
 if not footprintOK then self.stats.footprintError=tostring(footprintError);self.footprintsBlocked=true;self.footprints:clear()end
 self.stats.footprints=#self.footprints.prints
 local audioOK,audioError=pcall(self.snowAudio.update,self.snowAudio,game,p,self.surface,self.clock,dt,options.snowSteps,
  not background and covered and options.holiday=='christmas'and options.groundSnow=='full')
 if not audioOK then self.snowAudio:dispose();self.snowAudio.failed=tostring(audioError)end
 self.stats.snowAudioError=self.snowAudio.failed;self.stats.snowSteps=self.snowAudio.played
 -- Pillar cells are published as terrain becomes drawable. Detect a late
 -- record once per second, then refresh only accumulation after it settles.
 if self.decorReady and not self.snowJob and not self.pillarJob and self.stats.snowState=='ready'and self.clock>=(self.pillarPoll or 0)then
  self.pillarPoll=self.clock+1
  -- Cheap test first: the full signature sorts and joins every pillar cell,
  -- which stuttered big cities once a second. Only a different record table
  -- or a changed cell count can carry a geometric change.
  local record=PillarSnow.record(self.bridge,self.sceneId)
  local count=0;for _ in pairs(record and record.cells or {})do count=count+1 end
  local layout=record and tostring(record.layout)..'|'..tostring(record.boundary)or 'none'
  if record~=self.pillarSeen or count~=self.pillarCount or layout~=self.pillarLayout then
   self.pillarSeen,self.pillarCount,self.pillarLayout=record,count,layout
   local signature=PillarSnow.signature(record)
   if signature~=self.pillarSignature then self:refreshPillars()end
  end
 end
 -- Holiday particles: GPU-animated static meshes, created once per effect.
 local time=self.frame and self.frame.time or 300;local night=time>680 and time<1130
 local wanted={}
 if not background and covered and options.effects then
  local h=options.holiday
  if h=='halloween'then wanted.embers=true;wanted.bats=true
  elseif h=='harvest'then wanted.leaves=true
  elseif h=='easter'then wanted.petals=true
  elseif h=='july'and night then wanted.fireworks=true end
 end
 self.particles=self.particles or {};self.particleBlocked=self.particleBlocked or {}
 local names={}
 for kind,fx in pairs(self.particles)do names[#names+1]=kind..(fx.shader and ''or '(cpu)')end
 table.sort(names);self.stats.particles=#names>0 and table.concat(names,',')or nil
 for kind,fx in pairs(self.particles)do if not wanted[kind]then pcall(fx.dispose,fx);self.particles[kind]=nil end end
 for kind in pairs(wanted)do
  if not self.particles[kind]and not self.particleBlocked[kind]then
   local ok,fx=pcall(Particles.new,kind)
   if ok then self.particles[kind]=fx else self.particleBlocked[kind]=true;self.stats.particleError=tostring(fx)end
  end
  local fx=self.particles[kind]
  if fx then
   local ok,err=pcall(fx.update,fx,self.clock,px,pz)
   if not ok then pcall(fx.dispose,fx);self.particles[kind]=nil;self.particleBlocked[kind]=true;self.stats.particleError=tostring(err)end
  end
 end
end
-- Battles draw their own scene and never called the seasonal layer, so the
-- snow vanished at every encounter. In battle only winter is drawn: settled
-- snow (ground, roof/ledge/rail/pillar caps) and, for the player's own map,
-- falling snow. Displays stay out so none can stand between camera and mons.
function M:drawBattle(late,model,root)
 if not(self.alive and self.bridge and self.texture and self.world and self.world.map and self.sceneId==self.world.map.id)then return end
 local R,lg=self.bridge.R,love.graphics
 if not late then
  if self.stats.snowState~='ready'then return end
  lg.setColor(1,1,1,1);R.glass(false)
  -- Pillar/low-wall/district-rail caps are skipped: the battle scene does not
  -- draw those pillars, so their snow would float in mid-air.
  local ok,err=pcall(function()
   for _,mesh in ipairs(self.snowMeshes)do R.draw(mesh,self.texture,model)end
  end)
  R.glass(true);if not ok then error(err,0)end
 elseif root and self.snowfall then
  local worked,reason=pcall(self.snowfall.draw,self.snowfall,R,self.texture)
  if not worked then
   self.stats.snowfallError=tostring(reason)
   if self.snowfall.shader then self.snowfall:fallback(reason)
   else self.snowfallBlocked=self.snowfall.mode;self.snowfall:dispose();self.snowfall=nil end
  end
 end
end
function M:draw(late,model,staticOnly)
 if not(self.alive and self.bridge and self.texture and self.world and self.world.map and self.sceneId==self.world.map.id)or Settings.get('holiday')=='off'then return end
 local R,lg=self.bridge.R,love.graphics
 if not late then
  lg.setColor(1,1,1,1);R.glass(false)
  local ok,err=pcall(function()
   R.seasonalFoliage(Snow.enabled(self.snapshot,Settings.all())and G.snowPineRegion or nil)
   for _,mesh in ipairs(self.meshes)do R.draw(mesh,self.texture,model)end
   R.seasonalFoliage(nil)
   if self.stats.snowState=='ready'then
    for _,mesh in ipairs(self.snowMeshes)do R.draw(mesh,self.texture,model)end
    for _,mesh in ipairs(self.pillarMeshes)do R.draw(mesh,self.texture,model)end
   end
  end)
  R.seasonalFoliage(nil)
  R.glass(true);if not ok then error(err,0)end
 else
  local options=Settings.all();local animate=options.lights=='twinkle'
  local flicker=options.holiday=='halloween'or options.holiday=='harvest'
  R.withEffect('alpha',function()
   for i,group in ipairs(self.glows)do
    local light=1
    if animate and i>1 then
     local t=self.clock
     if flicker then
      -- Candle flicker: two incommensurate waves per group, never fully dark.
      light=.66+.34*(.5+.5*math.sin(t*6.3+i*2.1))*(.78+.22*math.sin(t*14.7+i*.9))
     else light=.76+.24*(.5+.5*math.sin(t*1.6+i*1.7))end
    end
    lg.setColor(light,light,light,1)
    for _,mesh in ipairs(group)do R.draw(mesh,self.texture,model)end
   end
  end)
  if staticOnly then return end
  local ok,err=pcall(self.footprints.draw,self.footprints,R,self.texture)
  if not ok then self.stats.footprintError=tostring(err);self.footprintsBlocked=true;self.footprints:clear()end
  if self.snowfall then
   local worked,reason=pcall(self.snowfall.draw,self.snowfall,R,self.texture)
   if not worked then
    self.stats.snowfallError=tostring(reason)
    if self.snowfall.shader then self.snowfall:fallback(reason)
    else self.snowfallBlocked=self.snowfall.mode;self.snowfall:dispose();self.snowfall=nil end
   end
  end
  for kind,fx in pairs(self.particles or {})do
   local worked,reason=pcall(fx.draw,fx,R,self.texture,kind=='bats'and 1 or .85)
   if not worked then
    self.stats.particleError=tostring(reason)
    if not(fx.shader and fx:fallback(reason))then pcall(fx.dispose,fx);self.particles[kind]=nil;self.particleBlocked[kind]=true end
   end
  end
 end
end
return M
