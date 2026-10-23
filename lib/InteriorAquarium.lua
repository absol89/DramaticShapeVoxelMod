-- TEST95: real imported Pokemon in the authored Cerulean wall aquariums.
-- Uses the Collection/standalone providers, never starts an import. Bounded
-- to nine instances, one allocation per frame, 30 Hz animation and no physics.
local V=...
local R,Mat=V.require('Voxel3D'),V.require('Mat4')
local M={stats={}}
local cached={}
local retryAfter={}
local function releaseFish(f)
 if f.instance then pcall(f.instance.release,f.instance);f.instance=nil end
end
function M.invalidate(id)
 for k,c in pairs(cached)do if not id or id==k then
  for _,f in ipairs(c.fish)do releaseFish(f)end
  cached[k]=nil;M.stats[k]=nil
 end end
end
function M.setLive(live)
 for id in pairs(cached)do if not(live and live[id])then M.invalidate(id)end end
end
local function findMod(id)
 local fn=V.mod and V.mod.find
 if type(fn)~='function'then return nil end
 local ok,h=pcall(fn,id);if ok and h then return h end
 ok,h=pcall(fn,V.mod,id);return ok and h or nil
end
local function providers()
 local h=findMod('STADIUM2_IMPORTER');local e=h and h.exports
 local host=findMod('LEGENDARY_STADIUM_OVERWORLD_MODELS')
 -- In the Collection, components are handles inside the importer root.
 if not host and e and e.collection and e.collection.components then
  host=e.collection.components.LEGENDARY_STADIUM_OVERWORLD_MODELS
 end
 local lib=host and host.exports and host.exports.lib
 local opts=lib and lib.mod and lib.mod.options
 local preferOne=opts and opts.get and opts:get('overworldModelPack')=='stadium1'
 return e,lib,preferOne
end
local function makeFish(dex,e,lib,preferOne)
 if not preferOne and e and e.models and (not e.modelsEnabled or e.modelsEnabled())then
  local s=e.status and e.status()
  if s and s.state=='ready'then
   local inst=e.models.newInstance(dex,'normal',{textureFilter='nearest',anisotropy=4,flipY=false,anchorTravel=true})
   if inst then
    local ok,b=pcall(function()inst:playContext('idle',true);return inst:metrics().bounds end)
    if ok and b and type(b.radius)=='number'and b.radius>0 and b.radius<1e8 then return inst,b,'Stadium 2'end
    pcall(inst.release,inst)
   end
  end
 end
 -- Stadium 1 remains available when that is the player's selected pack.
 if lib then
  local Pack=lib.require('StadiumPack')
  if Pack.available(dex,false)then
   local Mon=lib.require('StadiumMon');local mon=Mon.new('enemy')
   local ok,result=pcall(function()
    if not mon:setSpecies(dex,false)then return end
    local model=mon.model;local root=model.rootScale or 1;if root<=0 then root=1 end
    local h=model.height or 1;local radius=model.radius or h
    local b={cx=0,cy=((model.floor or 0)+h*.5)/root,cz=0,radius=math.sqrt(radius*radius+h*h*.25)/root}
    local inst={}
    function inst:update(dt)mon:update(dt);return mon:build()end
    function inst:draw(o)return mon.rig:draw(o.modelMatrix)end
    function inst:release()mon:release()end
    return {inst,b,'Stadium 1'}
   end)
   if ok and result then return unpack(result)end
   pcall(mon.release,mon)
  end
 end
 return nil,nil,'waiting for imported Pokemon models'
end
local function visible(tk)
 local eye=R.eye;if not eye then return true end
 if tk.side=='N'then return eye[3]>tk.wall-.5 end
 if tk.side=='W'then return eye[1]>tk.wall-.5 end
 return eye[1]<tk.wall+.5
end
-- A smooth oval, with tangent-facing yaw: no snapping at the ends.
function M.swimPose(tk,f,time)
 local a=time*(f.speed or .18)+f.phase
 local span=math.max(0,tk.w*.5-18-f.radius)
 local along=math.cos(a)*span;local across=math.sin(a)*3
 local dx,dz=-math.sin(a)*span,math.cos(a)*3
 local x,z=tk.x+along,tk.z+across
 if tk.axis=='z'then x,z=tk.x+across,tk.z+along;dx,dz=dz,dx end
 return x,f.y+math.sin(a*1.7+f.phase)*2,z,math.atan2(dx,dz)
end
local function prepare(map,fx)
 local c=cached[map.id]
 if c and c.source==fx.aquarium then return c end
 M.invalidate(map.id)
 c={source=fx.aquarium,fish={},nextLoad=0,providerAt=0}
 -- A small, bounded community in each bay. Real model silhouettes are
 -- large enough to read from the entrance; no particle stand-ins for fish.
 local species={{118,11.5,26,.17},{116,9,42,.13},{129,10.5,29,.21}}
 for i,tk in ipairs(fx.aquarium)do
  for j,sp in ipairs(species)do
   if #c.fish<9 then c.fish[#c.fish+1]={tank=tk,dex=sp[1],
    radius=sp[2],y=sp[3],speed=sp[4],phase=(i-1)*1.4+(j-1)*math.pi*2/3}end
  end
 end
 cached[map.id]=c;M.stats[map.id]={pokemon=0,status='aquarium ready'}
 return c
end
local function drawFish(map,fx,time)
 local c=prepare(map,fx);local status=M.stats[map.id]
 -- Recheck the selected provider once per second, including its toggle.
 if time>=c.providerAt then
  c.providerAt=time+1
  local e,lib,one=providers()
  local enabled=not e or not e.modelsEnabled or e.modelsEnabled()
  local key=(one and 'one'or'two')..':'..tostring(enabled)
  if c.providerKey and c.providerKey~=key then
   for _,f in ipairs(c.fish)do releaseFish(f)end
   c.nextLoad=0
  end
  c.providerKey,c.exports,c.lib,c.preferOne,c.enabled=key,e,lib,one,enabled
 end
 if not c.enabled then status.pokemon=0;status.status='Pokemon models disabled';return end
 -- Allocate at most one visible model in this frame; failed loads back off.
 if time>=c.nextLoad then
  for step=1,#c.fish do
   local i=((c.cursor or 0)+step-1)%#c.fish+1;local f=c.fish[i]
   if not f.instance and visible(f.tank)then
    c.cursor=i;c.nextLoad=time+10
    local ok,inst,b,kind=pcall(makeFish,f.dex,c.exports,c.lib,c.preferOne)
    if ok and inst then
     f.instance,f.bounds=inst,b;f.scale=f.radius/b.radius;f.lastTick=nil
     c.nextLoad=time+.1;status.status='swimming Pokemon: '..kind
    else status.status=ok and(kind or'model unavailable')or tostring(inst)end
    break
   end
  end
 end
 status.pokemon=0
 local tick=math.floor(time*30)
 local view=R.eye and R.focus and Mat.lookAt(R.eye,R.focus,{0,1,0})or Mat.identity()
 for _,f in ipairs(c.fish)do if f.instance and visible(f.tank)then
  local ok,err=pcall(function()
   if tick~=f.lastTick then
    local dt=f.lastTick and math.min(.1,math.max(0,(tick-f.lastTick)/30))or 0
    f.instance:update(dt,{context='idle'});f.lastTick=tick
   end
   local x,y,z,yaw=M.swimPose(f.tank,f,time);local b=f.bounds
   local matrix=Mat.mul(Mat.translate(x,y,z),Mat.mul(Mat.rotateY(yaw),Mat.mul(Mat.scale(f.scale,f.scale,f.scale),Mat.translate(-(b.cx or 0),-(b.cy or 0),-(b.cz or 0)))))
   love.graphics.setColor(1,1,1,1)
   local _,write=love.graphics.getDepthMode()
   local result,why=f.instance:draw({modelMatrix=matrix,camera={view=view,viewProjection=R.vp},
    light={direction={.25,.8,.35},ambient={.60,.68,.73},diffuse={.45,.55,.6}},
    tint={.84,.95,1,1},flipWinding=true,disableCulling=true,depthWrite=write==true})
   if result==false then error(why or'aquarium draw failed')end
  end)
  if not ok then releaseFish(f);c.nextLoad=time+10;status.status=tostring(err)
  else status.pokemon=status.pokemon+1 end
 end end
end
function M.draw(map,fx)
 if not(fx and fx.aquarium and #fx.aquarium>0 and R.vp)or R.reflectionPlane then return end
 local time=love.timer.getTime()
 if time<(retryAfter[map.id]or 0)then return end
 local g=love.graphics;g.push('all')
 local ok,err=pcall(drawFish,map,fx,time)
 g.pop()
 -- Stadium 1 rigs may change host uniforms that push/pop cannot restore.
 if R.glass then R.glass(false)end
 if R.seams then R.seams(false)end
 if not ok then
  M.invalidate(map.id);M.stats[map.id]={pokemon=0,status=tostring(err)}
  retryAfter[map.id]=time+10
 end
end
return M
