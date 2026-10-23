-- TEST259: Celadon's small, distant parade spectators in one mesh.
-- Artwork is rendered offline from the exact TEST79 Collection trainers:
-- eight bearings and four elevations. No runtime capture or model readback.
-- Close-ups, moving actors, sleep poses, player/follower and unknown models
-- keep the existing provider. No gameplay objects are removed.
local V=...
local M={ENABLED=true,ENTER=.16,EXIT=.20,MAX=48}
local abs,sqrt,sin,cos,floor,min,max,pi=math.abs,math.sqrt,math.sin,math.cos,math.floor,math.min,math.max,math.pi
local atan2=math.atan2 or math.atan
local classes={OPP_BUG_CATCHER='bug_catcher',OPP_LASS='lass',OPP_YOUNGSTER='youngster',
 OPP_HIKER='hiker',OPP_FISHER='fisherman',OPP_SAILOR='sailor',OPP_SUPER_NERD='super_nerd',
 OPP_GENTLEMAN='gentleman',OPP_BEAUTY='beauty',OPP_COOLTRAINER_M='ace_trainer_male',
 OPP_COOLTRAINER_F='ace_trainer_female',OPP_JR_TRAINER_M='camper'}
local sprites={SPRITE_OFFICER_JENNY='officer_jenny',SPRITE_CLERK='mart_clerk_male'}
local yaw={down=0,up=pi,right=pi/2,left=-pi/2}
local ID={1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
local NOSHADOW={1,0,0,100000,0,1,0,100000,0,0,1,100000,0,0,0,1}
local format={{'VertexPosition','float',3},{'VertexTexCoord','float',2},{'VertexShade','float',1}}
local tex,mesh,catalog,modRef,checked,failed
local serial=-1
local queue,mirrors,rows={},{},{}
local hookR,hookCP,oldEndCast,wrapEndCast,oldBeginWater,wrapBeginWater
local copying=false
local choices=setmetatable({},{__mode='k'})
M.stats={cards=0,reflected=0,batches=0,shadowSkipped=0,failures=0}
local function finite(x)return type(x)=='number'and x==x and abs(x)<1e12 end
local function release(x)if x and x.release then pcall(x.release,x)end end
local function compatible(mod)
 if not(mod and type(mod.find)=='function')then return false end
 local ok,h=pcall(mod.find,'STADIUM2_IMPORTER')
 if not(ok and type(h)=='table')then ok,h=pcall(mod.find,mod,'STADIUM2_IMPORTER')end
 local c=ok and type(h)=='table'and h.exports and h.exports.collection
 return type(c)=='table'and c.version=='TEST79-RIVAL-EYES1'
end
function M.prepare(mod)
 if not M.ENABLED or failed then return false end
 if tex and mesh then return true end
 if checked then return false end
 checked=true;modRef=mod or V.mod
 if not compatible(modRef)then return false end
 local newTex,newMesh
 local ok=pcall(function()
  local src=assert(modRef:read('assets/parade/crowd/catalog.lua'))
  catalog=assert((loadstring or load)(src,'@parade-crowd-catalog'))()
  assert(catalog.version=='TEST79-RIVAL-EYES1'and catalog.width==2048 and catalog.height==2048)
  local path=modRef.assets and modRef.assets.path and modRef.assets:path('assets/parade/crowd/trainers.png')
   or assert(modRef.path or V.path)..'/assets/parade/crowd/trainers.png'
  -- Own this image: a borrowed mod.assets:image must never be released.
  newTex=assert(love.graphics.newImage(path,{mipmaps=false}))
  assert(newTex:getWidth()==2048 and newTex:getHeight()==2048)
  newTex:setFilter('linear','linear');newTex:setWrap('clamp','clamp')
  for i=1,M.MAX*6 do rows[i]={0,0,0,0,0,1}end
  newMesh=assert(love.graphics.newMesh(format,rows,'triangles','stream'))
  assert(type(newMesh.setVertices)=='function'and type(newMesh.setDrawRange)=='function')
 end)
 if not ok then
  release(newMesh);release(newTex);catalog=nil;failed=true;M.stats.failures=M.stats.failures+1
  return false
 end
 tex,mesh=newTex,newMesh
 return true
end
function M.clear()
 release(mesh);release(tex)
 tex,mesh,catalog,modRef,checked,failed=nil,nil,nil,nil,nil,nil
 serial=-1;queue={};mirrors={};rows={};choices=setmetatable({},{__mode='k'})
 M.stats.failures=0
end
function M.warm(mod,CP)
 if CP and CP.crowdDetailView and CP.crowdDetailView(true)then return M.prepare(mod)end
 return false
end
-- Exposed for the real-roster projection regression (no graphics required).
function M.projectedHeight(vp,x,y,z,h)
 if type(vp)~='table'or not finite(vp[16])then return nil end
 local w=vp[13]*x+vp[14]*y+vp[15]*z+vp[16]
 local wt=w+vp[14]*h
 if not finite(w)or not finite(wt)or min(w,wt)<=.1 then return nil end
 local bottom=(vp[5]*x+vp[6]*y+vp[7]*z+vp[8])/w
 local top=(vp[5]*x+vp[6]*(y+h)+vp[7]*z+vp[8])/wt
 return abs(top-bottom)*.5 -- fraction of viewport height, independent of resolution
end
local function selection(ctx,actor,entry,R,CP,reflection)
 if not M.ENABLED or failed or(R.reflectionPlane and not reflection)or type(CP.crowdDetailView)~='function'then return nil end
 local cam,shot=CP.crowdDetailView()
 local eye=type(cam)=='table'and cam.eye
 if not(type(eye)=='table'and finite(eye[1])and finite(eye[2])and finite(eye[3]))then return nil end
 local key=classes[entry.trainerClass]or sprites[entry.sprite or ctx.spriteId]
 local model=catalog and catalog.models[key]
 local gender=actor.gender or(type(actor.def)=='table'and actor.def.gender)
 if key=='mart_clerk_male'and(gender=='female'or gender=='F')then return nil end
 -- No footsteps, NPC relocation, or facial/gesture effect may be frozen.
 if not model or(actor.moving and not actor.marching)or ctx.isPlayer or ctx.role=='player'then return nil end
 local x,y,z=tonumber(ctx.px),tonumber(ctx.groundHeight)or 0,tonumber(ctx.py)
 if not(finite(x)and finite(y)and finite(z))then return nil end
 x,z=x+8,z+8;y=y+(tonumber(ctx.lift)or 0)
 local frac=M.projectedHeight(R.vp,x,y,z,model.height)
 if not frac then return nil end
 local old=choices[actor]
 local limit=old and old.shot==shot and old.card and M.EXIT or M.ENTER
 local card=frac<limit
 choices[actor]={shot=shot,card=card}
 if not card then return nil end
 local dx,dz=eye[1]-x,eye[3]-z
 local horizontal=sqrt(dx*dx+dz*dz)
 if horizontal<32 then return nil end -- never replace someone under the lens
 local az=atan2(dx,dz)
 local el=atan2(eye[2]-y-model.height*.5,horizontal)
 if el<-.15 or el>pi*.46 then return nil end
 -- ctx.facing is the camera-relative direction for flat engine sprites.
 -- Match the Collection's world-facing priority for a 3D person.
 local facing=tostring((ctx.pose and ctx.pose.facing)or actor.facing or ctx.facing or'down'):lower()
 local fy=yaw[facing]
 if not fy then return nil end
 local a=floor(((az-fy)%(2*pi))/(pi/4)+.5)%8
 local e=max(0,min(3,floor(el/(20*pi/180)+.5)))
 return model.frames[e*8+a+1],x,y,z,az,el
end
function M.try(method,ctx,actor,entry,R,CP,mod,fallback)
 local reflection=method=='drawReflection'
 if copying or(method~='drawEntity'and method~='drawShadow'and not reflection)then return false end
 if reflection and not(hookR==R and wrapEndCast and finite(R.reflectionPlane))then return false end
 if not(CP.crowdDetailView and CP.crowdDetailView())then return false end
 if not M.prepare(mod)then return false end
 local frame,x,y,z,az,el=selection(ctx,actor,entry,R,CP,reflection)
 if not frame then return false end
 local current=tonumber(CP.frameSerial)
 if not current then return false end
 if serial~=current then queue={};mirrors={};serial=current end
 if method=='drawShadow'then M.stats.shadowSkipped=M.stats.shadowSkipped+1;return true end
 local pending=reflection and mirrors or queue
 if #pending>=M.MAX then return false end
 -- One independent context per queued actor; host contexts can be reused.
 local saved={};for k,v in pairs(ctx)do saved[k]=v end
 pending[#pending+1]={frame=frame,x=x,y=y,z=z,az=az,el=el,ctx=saved,fallback=fallback,method=method,
  plane=reflection and R.reflectionPlane or nil,raise=tonumber(ctx.reflectionRaise)or 0}
 if reflection then M.stats.reflected=M.stats.reflected+1 else M.stats.cards=M.stats.cards+1 end
 return true
end
function M.flush(R,CP,reflection)
 local pending=reflection and mirrors or queue
 if #pending==0 then return end
 if reflection then mirrors={}else queue={}end
 if serial~=tonumber(CP.frameSerial)then return end
 if not CP.crowdDetailView()then return end
 local g=love.graphics
 local cr,cg,cb,ca
 if g.getColor then cr,cg,cb,ca=g.getColor()end
 local ok=pcall(function()
  local n=0
  for _,q in ipairs(pending)do
   local f=q.frame;local sa,ca,se,ce=sin(q.az),cos(q.az),sin(q.el),cos(q.el)
   local rx,rz=ca,-sa
   local ux,uy,uz=-se*sa,ce,-se*ca
   local lift=max(0,-(f[9]or 0)*ce)+.12
   local function vertex(xx,yy,u,v)
    n=n+1;local r=rows[n]
    r[1],r[2],r[3]=q.x+rx*xx+ux*yy,q.y+lift+uy*yy,q.z+rz*xx+uz*yy
    if q.plane then r[2]=2*q.plane-r[2]+q.raise end
    r[4],r[5],r[6]=u,v,1
   end
   local x0,y0,x1,y1=f[1],f[2],f[1]+f[3],f[2]+f[4]
   vertex(x0,y0,f[5],f[8]);vertex(x1,y0,f[7],f[8]);vertex(x1,y1,f[7],f[6])
   vertex(x0,y0,f[5],f[8]);vertex(x1,y1,f[7],f[6]);vertex(x0,y1,f[5],f[6])
  end
  mesh:setVertices(rows);mesh:setDrawRange(1,n)
  if g.setColor then g.setColor(1,1,1,1)end
  if R.seams then R.seams(false)end
  if R.glass then R.glass(false)end
  -- Same alpha cutout, world lighting, curve and depth testing as real NPCs.
  R.draw(mesh,tex,ID,0,NOSHADOW)
  M.stats.batches=M.stats.batches+1
 end)
 if R.seams then pcall(R.seams,true)end
 if R.glass then pcall(R.glass,true)end
 if cr and g.setColor then g.setColor(cr,cg,cb,ca)end
 if not ok then
  -- Failed batching must not leave holes in the crowd. Disable this path
  -- for the stop and draw the queued actors through the original provider.
  failed=true;M.stats.failures=M.stats.failures+1
  for _,q in ipairs(pending)do pcall(q.fallback,q.method,q.ctx)end
 end
end
-- A reflected batch must be submitted while the reflection target is still
-- bound. The rare SSR-only fallback keeps the ordinary provider, because its
-- paint callback is not the main scene. All hooks are inert outside Celadon.
function M.install(R,CP)
 if hookR then return end
 hookR,hookCP=R,CP
 if type(R.endCast)=='function'then
  oldEndCast=R.endCast
  wrapEndCast=function(...)
   -- The enclosing cast callback is already inside actor_draw; endCast is
   -- outside it, so include this one batch in that same diagnostic counter.
   pcall(function()
    local okT,T=pcall(V.require,'LoadTimings')
    if okT and T and T.call then T.call('actor_draw',M.flush,R,CP,true)
    else M.flush(R,CP,true)end
   end)
   return oldEndCast(...)
  end
  R.endCast=wrapEndCast
 end
 if type(R.beginWater)=='function'then
  oldBeginWater=R.beginWater
  wrapBeginWater=function(paint,...)
   if type(paint)~='function'then return oldBeginWater(paint,...)end
   local function ordinary(...)
    local before=copying;copying=true
    local result={pcall(paint,...)};copying=before
    if not result[1]then error(result[2],0)end
    return (table.unpack or unpack)(result,2)
   end
   return oldBeginWater(ordinary,...)
  end
  R.beginWater=wrapBeginWater
 end
end
function M.dispose()
 M.clear()
 if hookR then
  if hookR.endCast==wrapEndCast then hookR.endCast=oldEndCast end
  if hookR.beginWater==wrapBeginWater then hookR.beginWater=oldBeginWater end
 end
 hookR,hookCP,oldEndCast,wrapEndCast,oldBeginWater,wrapBeginWater=nil,nil,nil,nil,nil,nil
 copying=false
end
return M
