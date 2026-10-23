-- TEST147: 3D party snapshots for the loading card's parade.
--
-- Each party Pokemon is drawn ONCE from its Stadium 2 model (the same models
-- your follower and battles use, via STADIUM2_IMPORTER's scene-neutral
-- instance API v2) into a small picture, trimmed to the model, and the model
-- is released straight away. The card then shows the pictures, which cost
-- no more than a sprite. Live models are never drawn on the card, so the
-- area build behind it keeps its time.
--
--   * At most one snapshot per card repaint (the card repaints 15x a second),
--     and only after the card has been up a moment.
--   * Kept across loads (one per species in the party, at most six); a
--     species that leaves the party is released.
--   * Anything missing (no importer, models off, a model that will not load
--     or draw) gives nil and the card keeps its sprite for that Pokemon.
--     A species that fails is not retried for 30 s, and gives up after three
--     tries.
local V=...
local Mat=V.require('Mat4')
local S={SIZE=256,FOV=math.rad(30),YAW=math.rad(35),RETRY=30,TRIES=3,MAX=6}
local shots={}        -- species -> {image=canvas, quad=..., w, h} | {failed=n, until=t}
local clock=0
function S.update(dt)clock=clock+math.max(0,tonumber(dt)or 0)end
local function now()
 if love and love.timer and love.timer.getTime then return love.timer.getTime()end
 return clock
end

-- The importer's model API, feature-detected (README "Scene-neutral model instances").
function S.provider()
 local find=V.mod and V.mod.find
 local h=find and find('STADIUM2_IMPORTER');local e=h and h.exports
 if not e then return nil end
 if e.modelsEnabled then local ok,on=pcall(e.modelsEnabled);if ok and on==false then return nil end end
 local api=e.models
 if api and (tonumber(api.apiVersion)or 0)>=2 and type(api.newInstance)=='function' then return api end
end

local function dexFor(species)
 local ok,Game=pcall(require,'src.core.Game')
 local data=ok and Game and Game.data
 local def=data and data.pokemon and data.pokemon[species]
 local dex=def and tonumber(def.dex)
 if dex and dex>=1 and dex<=251 then return math.floor(dex)end
end
S.dexFor=dexFor

-- Camera that fits the model's box. Mat4.rotateY takes the model's front
-- (+z, toward the camera) to (sin yaw, 0, cos yaw): a positive yaw turns it
-- toward screen right, the way the parade walks.
function S.camera(b,yaw)
 local tangent=math.tan(S.FOV/2);local c,s=math.cos(yaw),math.sin(yaw)
 local distance=0
 for _,x in ipairs({b.minX-b.cx,b.maxX-b.cx})do
  for _,y in ipairs({b.minY-b.cy,b.maxY-b.cy})do
   for _,z in ipairs({b.minZ-b.cz,b.maxZ-b.cz})do
    local rx,rz=c*x+s*z,-s*x+c*z
    distance=math.max(distance,rz+math.max(math.abs(rx),math.abs(y))*1.10/tangent)
   end
  end
 end
 distance=math.max(b.radius*.25,distance)
 local view=Mat.lookAt({0,0,distance},{0,0,0},{0,1,0})
 local projection=Mat.mul(Mat.scale(1,-1,1),Mat.perspective(S.FOV,1,math.max(.001,distance-b.radius*1.2),distance+b.radius*4))
 local model=Mat.mul(Mat.rotateY(yaw),Mat.translate(-b.cx,-b.cy,-b.cz))
 return model,view,Mat.mul(projection,view)
end

-- Opaque pixel box of the picture, so feet sit on the parade ground.
function S.trim(data,w,h)
 local x0,y0,x1,y1=w,h,-1,-1
 for y=0,h-1 do for x=0,w-1 do
  local _,_,_,a=data:getPixel(x,y)
  if a>.04 then if x<x0 then x0=x end;if x>x1 then x1=x end;if y<y0 then y0=y end;if y>y1 then y1=y end end
 end end
 if x1<x0 then return nil end
 return x0,y0,x1-x0+1,y1-y0+1
end

local function take(api,species,dex)
 local g=love.graphics
 local instance=api.newInstance(dex,'normal',{textureFilter='nearest',anisotropy=4,flipY=false,anchorTravel=true})
 if not instance then error('no model for '..species,0)end
 local canvas
 local ok,err=pcall(function()
  local metrics=assert(instance:metrics())
  local b=assert(metrics.bounds,'no bounds')
  assert(tonumber(b.radius)and b.radius>0,'invalid model bounds')
  for _,k in ipairs({'minX','maxX','minY','maxY','minZ','maxZ','cx','cy','cz'})do assert(tonumber(b[k]),'incomplete bounds')end
  pcall(instance.playContext,instance,'idle',true)
  pcall(instance.update,instance,0,{context='idle'})
  canvas=g.newCanvas(S.SIZE,S.SIZE,{format='rgba8',dpiscale=1})
  canvas:setFilter('linear','linear')
  local model,view,vp=S.camera(b,S.YAW)
  g.push('all')
  local drew,derr=pcall(function()
   g.origin();g.setScissor();g.setShader();g.setColor(1,1,1,1)
   g.setCanvas({canvas,depth=true});g.clear(0,0,0,0,0,1)
   g.setBlendMode('alpha','alphamultiply');g.setDepthMode('lequal',true);g.setMeshCullMode('none')
   local done,e=instance:draw({modelMatrix=model,camera={view=view,viewProjection=vp},
    light={direction={.35,.7,.62},ambient={.6,.6,.6},diffuse={.65,.65,.65}},
    tint={1,1,1,1},flipWinding=true,disableCulling=true,depthWrite=true})
   if not done then error(e or 'model draw failed',0)end
  end)
  g.pop()
  if not drew then error(derr,0)end
 end)
 pcall(instance.release,instance)       -- the snapshot keeps nothing alive
 if not ok then if canvas then pcall(canvas.release,canvas)end;error(err,0)end
 local data=canvas:newImageData()
 local x,y,w,h=S.trim(data,S.SIZE,S.SIZE)
 pcall(data.release,data)
 if not x then pcall(canvas.release,canvas);error('empty snapshot',0)end
 return {image=canvas,quad=g.newQuad(x,y,w,h,S.SIZE,S.SIZE),w=w,h=h}
end

-- The picture for a species, or nil (keep the sprite), and whether this call
-- tried a new snapshot. `allow` lets it try; the card allows one per repaint.
function S.get(species,allow)
 local rec=shots[species]
 if rec and rec.image then return rec,false end
 if not allow then return nil,false end
 if rec and (rec.failed>=S.TRIES or now()<rec.retry)then return nil,false end
 if not(love and love.graphics and love.graphics.newCanvas)then return nil,false end
 local api=S.provider();if not api then return nil,false end
 local dex=dexFor(species);if not dex then return nil,false end
 local ok,value=pcall(take,api,species,dex)
 if ok and value then shots[species]=value;return value,true end
 local failed=(rec and rec.failed or 0)+1
 shots[species]={failed=failed,retry=now()+S.RETRY,error=tostring(value)}
 if V.mod and V.mod.log and failed==1 then pcall(V.mod.log.info,V.mod.log,'Loading card snapshot for %s: %s',tostring(species),tostring(value))end
 return nil,true
end

-- Release pictures for species no longer on the card (the party and the
-- current and next "Who's that Pokemon?"). Failure records are kept, so a
-- missing model is not retried every time it comes round again.
function S.keep(list)
 local want={};for _,sp in ipairs(list or{})do want[sp]=true end
 local n=0
 for sp,rec in pairs(shots)do
  if rec.image then
   if not want[sp]then pcall(rec.image.release,rec.image);shots[sp]=nil else n=n+1 end
  end
 end
 return n
end
-- TEST148: true while a 3D picture for this species can still come (the
-- importer is there, the species has a model number, and it has not failed),
-- so the card can show its mystery ball instead of flashing the sprite first.
function S.pending(species)
 local rec=shots[species]
 if rec and (rec.image or rec.failed)then return false end
 return S.provider()~=nil and dexFor(species)~=nil
end
function S.release()
 for _,rec in pairs(shots)do if rec.image then pcall(rec.image.release,rec.image)end end
 shots={}
end
S.shots=function()return shots end
return S
