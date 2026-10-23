-- Parade-only identities through the Collection's public character provider.
-- Keep the real actor identity for locomotion, placement and shared passes.
-- Trainer metadata is a temporary render view, restored even on errors; it
-- never reaches gameplay updates, trainer sight checks or saved map objects.
-- TEST228: under the parade's white card (nothing of the world shows) the
-- crowd is not drawn. Each frame warms a few of them -- at most one kind of
-- person not seen yet -- so their models load and pose behind the card; the
-- rest of the frame goes to the build the card is waiting for. Shadows and
-- reflections wait for the picture.
--
-- TEST235: POSES. Anyone in the parade can be tipped over about their feet
-- -- a doze (a droop of a few tenths of a radian) or a full fall-over (about
-- 85 degrees, lying on the ground) -- in any direction, with a little lift
-- (so a body lying down does not sink into the road) and a hop:
--   * the parade's crowd and a stop's own people (bound to an identity here
--     or not -- Pallet's Mom, Professor Oak, your rival, the townsfolk): this
--     provider draws them through the Collection's own NPC provider with
--     Voxel3D.draw (and, for their shadow, ShadowMap.draw) swapped for the
--     length of that one call, so every mesh of theirs comes out tipped;
--   * you ('player') and your partner ('partner'): ParadeFloat applies the
--     same pose to your trainer model (riding or walking) and to your
--     partner on the float; a partner walking at your heels (a Stadium model)
--     is tipped through its prepared matrix (poseStadium, after the
--     Collection has prepared it: ChampionParade's WaterFooting.roaming wrap)
-- Plus, per person, where their head is (headOf: the point, the way the face
-- looks, the way the head is up -- fallen over or not) and a hook to draw
-- something there after the models (onHead, drawn by drawHeads in the
-- parade's late world pass). Nothing is made per frame: the matrices are
-- filled in place.
local V=...
local M={REVISION='parade-cast-260'}
local floor,max,min,abs,sin,cos,sqrt,pi=math.floor,math.max,math.min,math.abs,math.sin,math.cos,math.sqrt,math.pi
local cast={}
local handle,modRef
local warm={serial=-1,budget=0,newKinds=0,seen={}}
-- true: this pass is covered by the card (claimed, nothing drawn); false:
-- draw it (covered, but this one is warmed); nil: no card, draw as ever
local function covered(entry,actor,method)
 local okP,CP=pcall(V.require,'ChampionParade')
 if not(okP and type(CP)=='table'and type(CP.covered)=='function')then return nil end
 local okC,yes=pcall(CP.covered)
 if not(okC and yes)then return nil end
 if method~='drawEntity'then return true end
 local serial=tonumber(CP.frameSerial)or 0
 if warm.serial~=serial then
  warm.serial=serial;warm.budget=tonumber(CP.WARM_PER_FRAME)or 6;warm.newKinds=1
 end
 -- (each person once, then again only now and then -- the Collection lets
 -- go of a pose not drawn for two seconds)
 local t=0
 pcall(function()t=love.timer.getTime()end)
 if entry.warmedT and t-entry.warmedT<1.5 then return true end
 local d=type(actor.def)=='table'and actor.def or{}
 local kind=tostring(entry.trainerClass or entry.sprite or d.sprite or'?')
 local new=not warm.seen[kind]
 if warm.budget<=0 or(new and warm.newKinds<=0)then return true end
 warm.budget=warm.budget-1
 if new then warm.newKinds=warm.newKinds-1;warm.seen[kind]=true end
 entry.warmedT=t
 return false
end
M._covered=covered

------------------------------------------------------------------ poses (TEST235)
M.PLAYER,M.PARTNER='player','partner'
M.FALL=1.48            -- a full fall-over (about 85 degrees)
M.LYING_LIFT=1.6       -- how far a body lying down is raised (its half thickness)
M.HEAD={adult=14,kid=10,player=13,partner=7}   -- the middle of the head, standing
local poses={}         -- key (an actor table, 'player', 'partner') -> its record
M._poses=poses
local function mat()return{1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1}end
-- out = a*b (row-major), out not b
local function mulInto(o,a,b)
 for r=0,12,4 do
  local a0,a1,a2,a3=a[r+1],a[r+2],a[r+3],a[r+4]
  o[r+1]=a0*b[1]+a1*b[5]+a2*b[9]+a3*b[13]
  o[r+2]=a0*b[2]+a1*b[6]+a2*b[10]+a3*b[14]
  o[r+3]=a0*b[3]+a1*b[7]+a2*b[11]+a3*b[15]
  o[r+4]=a0*b[4]+a1*b[8]+a2*b[12]+a3*b[16]
 end
 return o
end
M._mulInto=mulInto
-- the tilt of a record about the feet (fx,fy,fz): R(axis k, angle a) about
-- them, then up by its lift (and its hop). The head goes the way (dx,dz):
-- the axis is k=(dz,0,-dx), and (0,1,0) goes to (dx sin a, cos a, dz sin a)
local function fillTilt(m,fx,fy,fz,rec)
 local a=rec.a or 0
 local kx,kz=rec.dz or 1,-(rec.dx or 0)
 local c,s=cos(a),sin(a)
 local t=1-c
 local r00,r01,r02=c+t*kx*kx,-s*kz,t*kx*kz
 local r10,r11,r12=s*kz,c,-s*kx
 local r20,r21,r22=t*kx*kz,s*kx,c+t*kz*kz
 local up=(rec.lift or M.LYING_LIFT)*abs(s)+(rec.y or 0)
 m[1],m[2],m[3],m[4]=r00,r01,r02,fx-(r00*fx+r01*fy+r02*fz)+(rec.x or 0)
 m[5],m[6],m[7],m[8]=r10,r11,r12,fy-(r10*fx+r11*fy+r12*fz)+up
 m[9],m[10],m[11],m[12]=r20,r21,r22,fz-(r20*fx+r21*fy+r22*fz)+(rec.z or 0)
 m[13],m[14],m[15],m[16]=0,0,0,1
 return m
end
M._fillTilt=fillTilt
local function tipped(rec)
 return rec~=nil and((rec.a or 0)~=0 or(rec.y or 0)~=0 or(rec.x or 0)~=0 or(rec.z or 0)~=0 or rec.sleep==true)
end
M.tipped=tipped
-- Tip `key` by `a` radians about its feet, its head going the way (dx,dz)
-- (any length; nil keeps the last way, at first (0,1)). a=nil puts it
-- upright again. opts (optional, kept until changed): lift (how far it is
-- raised when lying; default LYING_LIFT), y (a hop, world units), head (the
-- middle of its head above its feet, standing), yaw (the way its face
-- looks, when its own facing should not say).
function M.pose(key,a,dx,dz,opts)
 if key==nil then return nil end
 local rec=poses[key]
 if a==nil then
  if rec then pcall(function()V.require('ParadePartnerSleep').releasePose(rec)end)end
  if rec then
   rec.a,rec.y,rec.eyes,rec.x,rec.z,rec.sleep=0,0,0,0,0,false
   if not rec.hook then poses[key]=nil end
  end
  return nil
 end
 if not rec then rec={a=0,dx=0,dz=1,y=0};poses[key]=rec end
 rec.a=tonumber(a)or 0
 if dx and dz then
  local l=sqrt(dx*dx+dz*dz)
  if l>1e-6 then rec.dx,rec.dz=dx/l,dz/l end
 end
 if type(opts)=='table'then
  if opts.lift~=nil then rec.lift=tonumber(opts.lift)end
  if opts.y~=nil then rec.y=tonumber(opts.y)or 0 end
  if opts.head~=nil then rec.head=tonumber(opts.head)end
  if opts.yaw~=nil then rec.yaw=tonumber(opts.yaw)end
  if opts.eyes~=nil then rec.eyes=max(0,min(1,tonumber(opts.eyes)or 0))end
  if opts.x~=nil then rec.x=tonumber(opts.x)or 0 end
  if opts.z~=nil then rec.z=tonumber(opts.z)or 0 end
  if opts.sleep~=nil then rec.sleep=opts.sleep==true end
 end
 return rec
end
function M.unpose(key)return M.pose(key,nil)end
function M.poseOf(key)return poses[key]end
-- everyone upright, every hook gone (the parade's end, a stop left)
function M.clearPoses()
 pcall(function()V.require('ParadePartnerSleep').clear()end)
 for k in pairs(poses)do poses[k]=nil end
end
-- a hook to draw at `key`'s head after the models: fn(key,hx,hy,hz,
-- nx,ny,nz,ux,uy,uz,rec,K,t) -- the head's middle, the way the face looks,
-- the way the head is up. nil takes it away.
function M.onHead(key,fn)
 if key==nil then return end
 local rec=poses[key]
 if fn==nil then
  if rec then rec.hook=nil;if not tipped(rec)then poses[key]=nil end end
  return
 end
 if not rec then rec={a=0,dx=0,dz=1,y=0};poses[key]=rec end
 rec.hook=fn
end

-- the pass of one person drawn tipped: Voxel3D.draw (and ShadowMap.draw)
-- swapped for the length of `fn`, every matrix through them multiplied by
-- the tilt; put back even on an error. (Reflections are left upright.)
local swapM,tA,tB,tS=mat(),mat(),mat(),mat()
local origVD,origSD=nil,nil
local swapRec=nil
local cullR,cullEye=nil,nil
local function vdraw(mesh,tex,model,pull,sun,ranges)
 -- The NPC provider has finished its body/camera test. All actual drawing
 -- and observers use the real world-space camera, never the inverse pose.
 if cullR then cullR.eye=cullEye end
 if type(model)=='table'then mulInto(tA,swapM,model);model=tA end
 if type(sun)=='table'then mulInto(tB,swapM,sun);sun=tB end
 if swapRec and (swapRec.eyes or 0)>0 then
  return V.require('ParadeSleepEyes').draw(origVD,mesh,tex,model,pull,sun,ranges,swapRec.eyes)
 end
 return origVD(mesh,tex,model,pull,sun,ranges)
end
local function sdraw(mesh,tex,model,...)
 if type(model)=='table'then mulInto(tS,swapM,model);model=tS end
 return origSD(mesh,tex,model,...)
end
local swapping=false
function M.withPose(rec,fx,fy,fz,method,fn,...)
 if swapping or not tipped(rec)or method=='drawReflection'then return pcall(fn,...)end
 local okR,R=pcall(V.require,'Voxel3D')
 local okS,SM=pcall(V.require,'ShadowMap')
 fillTilt(swapM,fx,fy,fz,rec)
 swapping=true;swapRec=rec
 local vR,vS=nil,nil
 if okR and type(R)=='table'and type(R.draw)=='function'then origVD=R.draw;R.draw=vdraw;vR=R end
 if okS and type(SM)=='table'and type(SM.draw)=='function'then origSD=SM.draw;SM.draw=sdraw;vS=SM end
 local ok,res=pcall(fn,...)
 if vR then vR.draw=origVD end
 if vS then vS.draw=origSD end
 origVD,origSD=nil,nil
 swapping=false;swapRec=nil
 return ok,res
end

-- Collection checks a sphere around the STANDING chest before drawing an
-- NPC. Test the camera through the inverse sleep transform so that sphere
-- follows the lying body. Otherwise a harmless close-up over its old chest
-- claims the NPC without drawing it. Keep genuine inside-body suppression.
local cullM,cullLocal=mat(),{}
function M.withNpcPose(rec,fx,fy,fz,method,fn,...)
 if method~='drawEntity'or not tipped(rec)or cullR then return M.withPose(rec,fx,fy,fz,method,fn,...)end
 local R=V.require('Voxel3D')
 local eye=R.eye
 if not(type(eye)=='table'and tonumber(eye[1])and tonumber(eye[2])and tonumber(eye[3]))then
  return M.withPose(rec,fx,fy,fz,method,fn,...)
 end
 local m=fillTilt(cullM,fx,fy,fz,rec)
 local x,y,z=eye[1]-m[4],eye[2]-m[8],eye[3]-m[12]
 -- Inverse of a rigid transform: transpose its rotation, remove translation.
 cullLocal[1]=m[1]*x+m[5]*y+m[9]*z
 cullLocal[2]=m[2]*x+m[6]*y+m[10]*z
 cullLocal[3]=m[3]*x+m[7]*y+m[11]*z
 cullR,cullEye=R,eye;R.eye=cullLocal
 local ok,claimed,res=pcall(M.withPose,rec,fx,fy,fz,method,fn,...)
 R.eye=eye;cullR,cullEye=nil,nil
 if not ok then return false,claimed end
 return claimed,res
end

-- a Stadium model (HallOfFame3D's fitted team model) drawn as
-- HallOfFame3D.drawTeamModel draws it, its feet at (x,y,z), turned to yaw,
-- tipped by `rec` (ParadeFloat's partner)
local stM=mat()
function M.drawStadium(md,x,y,z,yaw,rec,grow)
 local R=V.require('Voxel3D')
 if R.reflectionPlane or not(R.vp and R.eye and R.focus)then return true end
 if not(md and md.inst)then return false end
 local Mat4=V.require('Mat4')
 local hf=V.require('HallOfFame3D')
 local okV,view=pcall(Mat4.lookAt,R.eye,R.focus,{0,1,0})
 if not(okV and view)then return true end
 local g=love.graphics
 local write=true
 pcall(function()local _,w=g.getDepthMode();write=w==true end)
 local k=(tonumber(md.scale)or 1)*(grow or 1)
 local base=Mat4.mul(Mat4.translate(x,y,z),Mat4.mul(Mat4.rotateY(yaw or 0),
  Mat4.mul(Mat4.scale(k,k,k),Mat4.translate(-(md.cx or 0),-(md.ground or 0),-(md.cz or 0)))))
 local matrix=base
 local Sleep=V.require('ParadePartnerSleep')
 local native=Sleep.float(md,rec)
 if tipped(rec)and not native then fillTilt(stM,x,y,z,rec);matrix=Mat4.mul(stM,base)end
 if native then Sleep.locate(md,matrix)end
 local ok,drawn=pcall(md.inst.draw,md.inst,{modelMatrix=matrix,camera={view=view,viewProjection=R.vp},
  light=hf.LIGHT,tint=hf.TINT,flashAmount=0,flashColor=hf.FLASH,
  flipWinding=true,disableCulling=true,depthWrite=write})
 g.setColor(1,1,1,1)
 return ok and drawn~=false
end

-- a Pokemon walking at your heels (or anyone the Collection draws as a
-- Stadium model), tipped through the matrix the Collection prepared for this
-- frame (as WaterFooting moves a swimmer's). Called after that prepare, once
-- a frame, with the frame's posed list (two matrices kept per walker, used
-- in turn; one already tipped is never tipped again).
local stScratch,stMade=setmetatable({},{__mode='k'}),setmetatable({},{__mode='k'})
local stTilt=mat()
local function isFollower(e)
 local okF,PF=pcall(V.require,'ParadeFloat')
 if okF and type(PF)=='table'and type(PF.isFollower)=='function'then
  local ok,yes=pcall(PF.isFollower,e)
  return ok and yes or false
 end
 return false
end
function M.poseStadium(posed)
 if next(poses)==nil or type(posed)~='table'then return end
 local partner=poses[M.PARTNER]
 for i=1,#posed do
  local p=posed[i]
  local e=type(p)=='table'and p.entity
  local m=e and p.stadiumMatrix
  if m and not p.isPlayer and m~=stMade[e]then
   local rec=poses[e]
   if not rec and partner and isFollower(e)then rec=partner end
   local mon=p.stadiumMon
   local native=false
   if type(mon)=='table'then
    local Sleep=V.require('ParadePartnerSleep')
    if rec and rec~=partner then Sleep.pinWalker(p,rec);m=p.stadiumMatrix end
    native=Sleep.walker(mon,rec)
    if native and rec==partner then Sleep.locate(mon,m)end
   end
   if tipped(rec)and not native then
    local f=p.stadiumFoot
    local fx,fy,fz
    if type(f)=='table'and f[1]then fx,fy,fz=f[1],f[2],f[3]
    else fx,fy,fz=(tonumber(p.px)or 0)+8,(tonumber(p.gh)or 0)+(tonumber(p.lift)or 0),(tonumber(p.py)or 0)+8 end
    local out=stScratch[e]
    if not out then out={mat(),mat(),k=1};stScratch[e]=out end
    out.k=3-out.k
    local o=out[out.k]
    mulInto(o,fillTilt(stTilt,fx,fy,fz,rec),m)
    -- TEST262: sleeping town birds must land, including their authored hover.
    if type(mon)=='table'then V.require('ParadePartnerSleep').groundBird(mon,o,fy,rec)end
    p.stadiumMatrix=o;stMade[e]=o
    if type(p.stadiumMon)=='table'then p.stadiumMon.model_matrix=o end
   end
  end
 end
end

-- where someone's feet are, which way they face, how high their head is
local YAW={down=0,up=pi,right=pi/2,left=-pi/2}
M.YAW=YAW
local function groundOf(game,e)
 local map=game and game.overworld and game.overworld.map
 if not map then return 0 end
 local okS,VS=pcall(V.require,'VoxelScene')
 if not(okS and type(VS)=='table'and VS.groundAt)then return 0 end
 local ok,h=pcall(VS.groundAt,map,e.cellX,e.cellY,e.px,e.py)
 return ok and tonumber(h)or 0
end
local function followerOf(game)
 local ow=game and game.overworld
 if not ow then return nil end
 local list=ow.npcs
 for pass=1,2 do
  if type(list)=='table'then
   for i=1,#list do
    local e=list[i]
    if e~=ow.player and isFollower(e)then return e end
   end
  end
  list=ow.entities
 end
 return nil
end
M._followerOf=followerOf
local function kidOf(e)
 local d=type(e)=='table'and type(e.def)=='table'and e.def or{}
 return tostring(d.sprite or''):find('LITTLE',1,true)~=nil
end
-- feet x,y,z, the way the face looks (yaw), the middle of the head above
-- the feet (nil: nowhere to be found)
function M.feetOf(key,game)
 local rec=poses[key]
 local ow=game and game.overworld
 if key==M.PLAYER or key==M.PARTNER then
  local okF,PF=pcall(V.require,'ParadeFloat')
  local fl=okF and PF and PF._current and PF._current()
  if fl and fl.carrying and not fl.released and fl.riderFeet then
   local ok,x,y,z,yaw,h=pcall(fl.riderFeet,fl,key)
   if ok and x then return x,y,z,(rec and rec.yaw)or yaw,(rec and rec.head)or h end
  end
  local e=key==M.PLAYER and(ow and ow.player)or followerOf(game)
  if type(e)~='table'then return nil end
  local x,y,z,yaw,h=M.feetOf(e,game)
  if not x then return nil end
  return x,y,z,(rec and rec.yaw)or yaw,(rec and rec.head)or h
 end
 local e=key
 if type(e)~='table'or not(e.px or e.cellX)then return nil end
 local x=(tonumber(e.px)or(tonumber(e.cellX)or 0)*16)+8
 local z=(tonumber(e.py)or(tonumber(e.cellY)or 0)*16)+8
 local isP=ow and e==ow.player
 local h=(rec and rec.head)or(isP and M.HEAD.player)or(isFollower(e)and M.HEAD.partner)or(kidOf(e)and M.HEAD.kid or M.HEAD.adult)
 return x,groundOf(game,e),z,(rec and rec.yaw)or YAW[e.facing]or 0,h
end
-- R(k,a) v, the record's turn (no allocation)
local function rot(rec,vx,vy,vz)
 local a=rec and rec.a or 0
 if a==0 then return vx,vy,vz end
 local kx,kz=rec.dz or 1,-(rec.dx or 0)
 local c,s=cos(a),sin(a)
 local kv=kx*vx+kz*vz
 -- k x v, with k=(kx,0,kz)
 local cx,cy,cz=-kz*vy,kz*vx-kx*vz,kx*vy
 return vx*c+cx*s+kx*kv*(1-c),vy*c+cy*s,vz*c+cz*s+kz*kv*(1-c)
end
M._rot=rot
-- the record that tips `key` as it is drawn (a player or a follower named
-- by its entity is tipped by 'player' / 'partner')
local function recFor(key,game)
 local rec=poses[key]
 if rec or type(key)~='table'then return rec end
 local ow=game and game.overworld
 if ow and key==ow.player then return poses[M.PLAYER]end
 if isFollower(key)then return poses[M.PARTNER]end
 return nil
end
-- the middle of someone's head as they are drawn (tipped or not), the way
-- their face looks (n) and the way their head is up (u). nil: not found
function M.headOf(key,game)
 if key==M.PARTNER or(type(key)=='table'and isFollower(key))then
  local ok,S=pcall(V.require,'ParadePartnerSleep')
  if ok and S.active()then local x,y,z,nx,ny,nz,ux,uy,uz=S.head();if x then return x,y,z,nx,ny,nz,ux,uy,uz end end
 end
 local fx,fy,fz,yaw,h=M.feetOf(key,game)
 if not fx then return nil end
 local rec=recFor(key,game)
 local ux,uy,uz=rot(rec,0,1,0)
 local nx,ny,nz=rot(rec,sin(yaw),0,cos(yaw))
 local up=0
 if rec then up=(rec.lift or M.LYING_LIFT)*abs(sin(rec.a or 0))+(rec.y or 0)end
 return fx+ux*h+(rec and rec.x or 0),fy+uy*h+up,fz+uz*h+(rec and rec.z or 0),nx,ny,nz,ux,uy,uz
end
-- the hooks, after the models (the parade's late world pass)
function M.drawHeads(game,K,t)
 for key,rec in pairs(poses)do
  if rec.hook then
   local hx,hy,hz,nx,ny,nz,ux,uy,uz=M.headOf(key,game)
   if hx then
    local ok,err=pcall(rec.hook,key,hx,hy,hz,nx,ny,nz,ux,uy,uz,rec,K,t)
    if not ok then
     rec.hook=nil
     pcall(function()require('src.core.Logger').warn('[ParadeCast] a head hook failed: %s',tostring(err))end)
    end
   end
  end
 end
end

------------------------------------------------------------------ the provider
-- Both installations expose the same provider. In the combined Collection,
-- the NPC component is not a top-level mod; resolve its published handle.
local function findMod(mod,id)
 if not(mod and type(mod.find)=='function')then return nil end
 local ok,h=pcall(mod.find,id)
 if not(ok and type(h)=='table')then ok,h=pcall(mod.find,mod,id)end
 return ok and type(h)=='table'and h or nil
end
local function npcProvider(mod)
 local h=findMod(mod,'gen1_true_3d_characters')
 local ex=h and h.exports
 local provider=ex and ex.characterRenderer
 if type(provider)=='table'then return provider end
 local c=findMod(mod,'STADIUM2_IMPORTER')
 local col=c and c.exports and c.exports.collection
 local components=col and col.components
 local npc=components and components.gen1_true_3d_characters
 ex=npc and npc.exports
 provider=ex and ex.characterRenderer
 if type(provider)=='table'then return provider end
 -- Also use the live registered callback after a launcher reload, while the
 -- Collection is republishing handles. Never recurse through this provider.
 local ok,bridge=pcall(V.require,'CharacterRenderers')
 if ok and type(bridge)=='table'then
  for _,entry in ipairs(bridge.entries or {})do
   local spec=not entry.removed and entry.spec
   if type(spec)=='table'and tostring(spec.id or ''):match('^gen1_true_3d_characters%.')then return spec end
  end
 end
 return nil
end
M._npcProvider=npcProvider
-- TEST242: the provider found once a frame (it was looked up for every
-- person's every pass: three pcalls and a handle table each time in the
-- combined Collection). Only a found provider is kept; a miss looks again.
local provMemo={serial=nil,mod=nil,provider=nil,t=0}
local function npcProviderFrame(mod)
 local okS,CP=pcall(V.require,'ChampionParade')
 local serial=okS and type(CP)=='table'and tonumber(CP.frameSerial)or nil
 local okT,t=pcall(love.timer.getTime);t=okT and t or 0
 if serial and provMemo.serial==serial and provMemo.mod==mod and provMemo.provider and abs(t-provMemo.t)<=.1 then return provMemo.provider end
 local provider=npcProvider(mod)
 provMemo.serial,provMemo.mod,provMemo.provider,provMemo.t=serial,mod,provider,t
 return provider
end
M._npcProviderFrame=npcProviderFrame
------------------------------------------------------------------ TEST242: the crowd, cheaper
-- Each of the parade's people is a real trainer model the Collection poses
-- on the CPU: every time it draws one, at most 24 times a second, it works
-- the whole body (6,000-7,500 vertices) through its idle and uploads it again
-- (about a millisecond a person with the JIT off -- the crowd alone took most
-- of a frame). So, for the parade's own crowd (never anyone tipped over;
-- reflections too since budget 2, below):
--   * no one off the screen is drawn (their shadow still is);
--   * the farther people are posed less often: in between, the very mesh the
--     Collection last posed for them is drawn again, with the same texture and
--     matrices, by the same Voxel3D.draw / ShadowMap.draw (near: every frame;
--     M.LOD_MID away: M.LOD_MID_EVERY seconds; farther, or off the screen:
--     M.LOD_FAR_EVERY / M.LOD_OFF_EVERY). Anyone is posed again at least every
--     M.LOD_OFF_EVERY seconds, well inside the two seconds after which the
--     Collection lets go of a pose not drawn.
-- Any doubt (no camera, a draw that is not the plain kind, an error): the
-- person is drawn the ordinary way.
M.LOD=true
M.LOD_NEAR=110         -- world pixels from the camera: posed every frame
M.LOD_MID=230          -- up to here: every LOD_MID_EVERY s; beyond: LOD_FAR_EVERY s
M.LOD_MID_EVERY=1/8
M.LOD_FAR_EVERY=1/4
M.LOD_OFF_EVERY=1/2    -- off the screen (only their shadow is drawn)
M.LOD_CULL=true
M.LOD_SHADOW_FAR=350   -- LITE 2: off the screen and farther than this: no shadow
M.LOD_LITE=0           -- ChampionParade's LITE level (0: as above; 1: 1.3x farther apart; 2: 1.6x)
-- TEST258: A RE-POSE BUDGET. Joseph's TEST251-257 rides: the wide Celadon
-- shots (rooftop, crowd, finale) ran at 10-15 FPS with "actor draw" 40-66 ms
-- a frame, the close shots 9-12 ms. A crowd member's FULL draw re-poses it:
-- the Collection walks every vertex of its 4,500-8,600-vertex mesh in Lua
-- and uploads the whole mesh (NamedTrainers.sample/setVertices); a replay
-- re-issues the last draw and costs next to nothing. The intervals above
-- space each person's re-poses out, but nothing capped how many fell in one
-- frame: a wide shot sees all ~47 at once, ~12 of them due every frame.
-- Now at most `budget` re-poses a frame (people already drawn once; a first
-- draw is never held back), worked out from what a re-pose really costs on
-- this device (an average of the last frames) so that re-posing takes about
-- REPOSE_MS[LITE] ms a frame (between REPOSE_MIN and REPOSE_MAX of them).
-- Who goes first: the most out of date, weighted by how close (near x3,
-- mid x1.5, far x1, off the screen x0.5); everyone else replays. Nobody
-- starves: the longer one waits, the higher one ranks. (false: as before.)
M.REPOSE_BUDGET=true
M.REPOSE_MS={[0]=20,[1]=14,[2]=10}
M.REPOSE_MIN,M.REPOSE_MAX=1,12
M.REPOSE_WEIGHT={near=3,mid=1.5,far=1,off=.5}
M.repose={budget=M.REPOSE_MAX,costMs=nil,left=0,serial=-1,cand={},ranked={},queued=0,spent=0,admitted=0,timed=0,lastNow=nil,deadline=nil}
-- BUDGET 2 (the review of TEST258, with the Collection's real NamedTrainers):
-- what that budget missed, closed.
--  * REFLECTIONS. Where the water's reflection pass runs, each person's
--    reflection went straight to the Collection, which posed them afresh for
--    it every frame -- work the budget never saw (40 updates a frame in the
--    review's fixture, budget or not). Now the reflection pass shares the
--    person's one decision a frame with the shadow and the body: refreshed,
--    all three call the Collection (one pose: it keeps one mesh a person a
--    tick); otherwise all three replay -- the reflection its OWN capture (the
--    mirrored matrix the Collection drew it with, into the reflection pass's
--    own target, kept per water plane), never the body's. (LOD_REFLECT=false:
--    reflections as before.)
--  * THE COLLECTION'S CACHE. It lets go of a person's mesh when they have not
--    been posed for 2 s (swept once a second); a replay does not count. So the
--    budget never drops below what refreshes everyone, by turns, inside
--    REPOSE_DEADLINE (x.75 for slack); anyone past REPOSE_URGENT of it goes
--    first, and anyone at it goes over the budget if need be (forced); at
--    under ~2.5 FPS the deadline shortens so that one more frame cannot
--    carry a pose past REPOSE_LIFETIME; and a capture older than
--    REPOSE_STALE is never replayed (drawn afresh: the mesh may be gone). By
--    this clock; the Collection's runs on the game's dt, never ahead of it.
--  * FAIR TURNS. TEST258 admitted, in draw order, whoever beat last frame's
--    threshold: people late in the order could miss out frame after frame.
--    Now each frame's picks are made at its start, from everyone's wait at
--    that moment: the top `budget` of those due.
--  * Every refresh is charged to the frame's budget: picks, forced ones,
--    first draws, a pass with nothing captured yet, a replay that failed.
--  * Counters, lodStats (this frame) and reposeTotals (running, for a per-shot
--    profile): refreshed (people posed afresh: at most one mesh upload each),
--    admitted (picked), deferred, forced (over the budget, by the deadline),
--    extra (outside the turns), rebuilt (the Collection handed back another
--    mesh: for a named trainer, it had let go), recovered (a replay that
--    failed), reflReplay / reflFull (the reflection pass's replays and
--    Collection draws), calls (Collection draws, every pass), replays.
M.LOD_REFLECT=true
M.REPOSE_DEADLINE=1.5
M.REPOSE_STALE=1.75
M.REPOSE_LIFETIME=2     -- the Collection's (NamedTrainers.update)
M.REPOSE_URGENT=.6
function M.reposeReset()
 M.repose={budget=M.REPOSE_MAX,costMs=nil,left=0,serial=-1,cand={},ranked={},queued=0,spent=0,admitted=0,timed=0,lastNow=nil,deadline=nil}
end
M.reposeTotals={refreshed=0,admitted=0,deferred=0,forced=0,extra=0,rebuilt=0,recovered=0,reflReplay=0,reflFull=0,calls=0,replays=0}
M.lodStats={full=0,replay=0,culled=0,frame=-1}
-- TEST252: only Celadon's parade-owned crowd, while the camera is live.
-- Keep detailed shadows around either the camera or the subject. Horizontal
-- distance protects the ground under an elevated camera; the extra tile on
-- exit prevents flicker while the camera/float eases across a boundary.
-- This changes no colour/reflection draw and never touches another provider's
-- player, follower or town NPC. Tipped/sleeping people use their original pass.
M.SHADOW_CAMERA_RADIUS=96
M.SHADOW_FOCUS_RADIUS=96
M.SHADOW_HYSTERESIS=16
M.shadowStats={kept=0,skipped=0}
local lodState=setmetatable({},{__mode='k'})
-- does the box reach the screen? (Voxel3D's own test for its culling, with
-- the world curve)
local function boxOnScreen(vp,k,fx,fz,x0,y0,z0,x1,y1,z1)
 if k~=0 then
  local ax,bx=x0-fx,x1-fx
  local az,bz=z0-fz,z1-fz
  local mx=max(ax*ax,bx*bx)
  local mz=max(az*az,bz*bz)
  local nx=(ax<=0 and bx>=0)and 0 or min(ax*ax,bx*bx)
  local nz=(az<=0 and bz>=0)and 0 or min(az*az,bz*bz)
  local dmax,dmin=mx+mz,nx+nz
  if k>0 then y0,y1=y0-k*dmax,y1-k*dmin else y0,y1=y0-k*dmin,y1-k*dmax end
 end
 local a1,a2,a3,a4=vp[1],vp[2],vp[3],vp[4]
 local b1,b2,b3,b4=vp[5],vp[6],vp[7],vp[8]
 local d1,d2,d3,d4=vp[13],vp[14],vp[15],vp[16]
 local L,R,B,T,N=true,true,true,true,true
 for i=0,7 do
  local x=(i%2==0)and x0 or x1
  local y=(i%4<2)and y0 or y1
  local z=(i<4)and z0 or z1
  local cx=a1*x+a2*y+a3*z+a4
  local cy=b1*x+b2*y+b3*z+b4
  local cw=d1*x+d2*y+d3*z+d4
  if cx>=-cw then L=false end
  if cx<=cw then R=false end
  if cy>=-cw then B=false end
  if cy<=cw then T=false end
  if cw>0 then N=false end
  if not(L or R or B or T or N)then return true end
 end
 return not(L or R or B or T or N)
end
M._boxOnScreen=boxOnScreen
local function copy16(dst,src)
 if type(src)~='table'then return nil end
 dst=dst or{}
 for i=1,16 do dst[i]=src[i]end
 return dst
end
-- the capture: what the Collection draws for one person in one pass
local cap={on=false,n=0,list=nil,bad=false,orig=nil}
local function capV(mesh,tex,model,pull,sun,...)
 local orig=cap.orig
 if cap.on then
  if select('#',...)>0 or cap.n>=2 then cap.bad=true
  else
   cap.n=cap.n+1
   local c=cap.list[cap.n]or{};cap.list[cap.n]=c
   c.mesh,c.tex,c.pull=mesh,tex,pull
   c.hasModel,c.hasSun=model~=nil,sun~=nil
   if model~=nil and type(model)~='table'then cap.bad=true end
   if sun~=nil and type(sun)~='table'then cap.bad=true end
   c.model=copy16(c.model,model);c.sun=copy16(c.sun,sun)
  end
 end
 return orig(mesh,tex,model,pull,sun,...)
end
local function capS(mesh,tex,model,...)
 local orig=cap.orig
 if cap.on then
  if select('#',...)>0 or cap.n>=2 or(model~=nil and type(model)~='table')then cap.bad=true
  else
   cap.n=cap.n+1
   local c=cap.list[cap.n]or{};cap.list[cap.n]=c
   c.mesh,c.tex=mesh,tex;c.hasModel=model~=nil
   c.model=copy16(c.model,model)
  end
 end
 return orig(mesh,tex,model,...)
end
-- one ordinary draw of this person, recording what it draws into rec
local function fullCall(method,fn,ctx,pass)
 local isShadow=method=='drawShadow'
 local okT,T=pcall(V.require,isShadow and'ShadowMap'or'Voxel3D')
 if not(okT and type(T)=='table'and type(T.draw)=='function')or cap.on or swapping then
  pass.n=0;return pcall(fn,ctx)
 end
 cap.on,cap.n,cap.bad,cap.list,cap.orig=true,0,false,pass.list,T.draw
 T.draw=isShadow and capS or capV
 local ok,claimed=pcall(fn,ctx)
 T.draw=cap.orig
 local n,bad=cap.n,cap.bad
 cap.on,cap.orig,cap.list=false,nil,nil
 pass.n=(ok and claimed==true and not bad)and n or 0
 return ok,claimed
end
local function replay(method,pass)
 local isShadow=method=='drawShadow'
 local T=V.require(isShadow and'ShadowMap'or'Voxel3D')
 for i=1,pass.n do
  local c=pass.list[i]
  if isShadow then T.draw(c.mesh,c.tex,c.hasModel and c.model or nil)
  else T.draw(c.mesh,c.tex,c.hasModel and c.model or nil,c.pull,c.hasSun and c.sun or nil)end
 end
end
-- returns as pcall(fn,ctx) would
local lodR,lodCP=nil,nil
local function shadowFinite(n)return type(n)=='number'and n==n and n>-math.huge and n<math.huge end
local function farCrowdShadow(ctx,entry)
 if not lodCP then
  local ok,C=pcall(V.require,'ChampionParade')
  if ok and type(C)=='table'then lodCP=C end
 end
 local CP=lodCP
 local ok,cam,shot=false,nil,nil
 if CP and type(CP.crowdShadowView)=='function'then ok,cam,shot=pcall(CP.crowdShadowView)end
 local eye=type(cam)=='table'and cam.eye
 local focus=type(cam)=='table'and cam.focus
 local x,z=tonumber(ctx.px),tonumber(ctx.py)
 if not(ok and type(eye)=='table'and type(focus)=='table'and shadowFinite(x)and shadowFinite(z)
  and shadowFinite(eye[1])and shadowFinite(eye[3])and shadowFinite(focus[1])and shadowFinite(focus[3])
  and shadowFinite(M.SHADOW_CAMERA_RADIUS)and M.SHADOW_CAMERA_RADIUS>0
  and shadowFinite(M.SHADOW_FOCUS_RADIUS)and M.SHADOW_FOCUS_RADIUS>0
  and shadowFinite(M.SHADOW_HYSTERESIS)and M.SHADOW_HYSTERESIS>=0)then
  entry.shadowKeep,entry.shadowShot=nil,nil
  return false -- unknown camera/context: retain the normal shadow
 end
 if entry.shadowShot~=shot then entry.shadowKeep=nil;entry.shadowShot=shot end
 local margin=entry.shadowKeep and M.SHADOW_HYSTERESIS or 0
 local cr,fr=M.SHADOW_CAMERA_RADIUS+margin,M.SHADOW_FOCUS_RADIUS+margin
 x,z=x+8,z+8
 local cx,cz,fx,fz=x-eye[1],z-eye[3],x-focus[1],z-focus[3]
 local keep=cx*cx+cz*cz<=cr*cr or fx*fx+fz*fz<=fr*fr
 entry.shadowKeep=keep
 local stats=M.shadowStats
 if keep then stats.kept=stats.kept+1 else stats.skipped=stats.skipped+1 end
 return not keep
end
-- (budget 2) a frame's account and its turns, at its first decision: what a
-- refresh cost (the last frames), the budget (never below what refreshes last
-- frame's people inside the deadline at last frame's length), and the picks:
-- the most out of date of those due, by their wait NOW (weighted; anyone
-- past REPOSE_URGENT of the deadline first, by wait alone -- so a low weight,
-- someone off the screen, never starves until the deadline forces them all
-- at once)
local function byPri(a,b)return a.pri>b.pri end
local function turns(B,serial,now)
 if(B.timed or 0)>0 then
  local c=B.spent/B.timed*1000
  B.costMs=B.costMs and(B.costMs*.8+c*.2)or c
 end
 local target=M.REPOSE_MS[M.LOD_LITE]or M.REPOSE_MS[0]
 B.budget=B.costMs and max(M.REPOSE_MIN,min(M.REPOSE_MAX,floor(target/max(.05,B.costMs))))or M.REPOSE_MAX
 local cand,ranked=B.cand or{},B.ranked or{}
 B.cand,B.ranked=cand,ranked
 local dt=B.lastNow and now-B.lastNow or 0
 -- (the deadline, shortened when frames are so long that one more frame
 -- would carry a pose past the Collection's lifetime)
 local D=M.REPOSE_DEADLINE
 if dt>0 then D=max(.5,min(D,M.REPOSE_LIFETIME-.1-dt))end
 B.deadline=D
 if dt>0 and #cand>0 then
  B.budget=max(B.budget,min(#cand,math.ceil(#cand*dt/(D*.75))))
 end
 local k,urgent=0,D*M.REPOSE_URGENT
 for i=1,#cand do
  local s=cand[i];cand[i]=nil
  local wait=now-s.t
  if wait>=(s.every or 0)or wait>=urgent then
   s.pri=(wait>=urgent)and 1e6+wait or wait*(s.w or 1)
   k=k+1;ranked[k]=s
  end
 end
 for i=#ranked,k+1,-1 do ranked[i]=nil end
 table.sort(ranked,byPri)
 for i=1,min(k,B.budget)do ranked[i].pick=serial end
 for i=k,1,-1 do ranked[i]=nil end
 B.queued=k
 B.serial,B.left,B.spent,B.admitted,B.timed,B.lastNow=serial,B.budget,0,0,0,now
end
local function lodCall(method,fn,ctx,actor)
 local refl=method=='drawReflection'
 if not M.LOD or swapping or cap.on then return pcall(fn,ctx)end
 if refl then
  -- (budget 2: a reflection only inside a reflection pass, by its plane)
  if not M.LOD_REFLECT or tonumber(ctx.reflectionPlane)==nil then return pcall(fn,ctx)end
 elseif method~='drawEntity'and method~='drawShadow'then return pcall(fn,ctx)end
 if not lodR then local ok,R0=pcall(V.require,'Voxel3D');if not(ok and type(R0)=='table')then return pcall(fn,ctx)end lodR=R0 end
 local R=lodR
 if R.reflectionPlane and not refl then return pcall(fn,ctx)end
 if not lodCP then local ok,C0=pcall(V.require,'ChampionParade');if ok and type(C0)=='table'then lodCP=C0 end end
 local CP=lodCP
 local serial=CP and tonumber(CP.frameSerial)or nil
 local cam=type(R.camera)=='table'and R.camera or nil
 local eye=(cam and type(cam.eye)=='table'and cam.eye)or R.eye
 if not(serial and type(eye)=='table'and tonumber(eye[1])and tonumber(eye[3]))then return pcall(fn,ctx)end
 local okT,now=pcall(love.timer.getTime)
 if not okT then return pcall(fn,ctx)end
 local st=lodState[actor]
 if not st then
  st={t=-1e9,serial=-1,full=false,seen=true,entity={n=0,list={}},shadow={n=0,list={}}}
  lodState[actor]=st
 end
 local stats=M.lodStats
 if stats.frame~=serial then stats.frame=serial;stats.full,stats.replay,stats.culled,stats.deferred=0,0,0,0
  stats.refreshed,stats.admitted,stats.forced,stats.extra,stats.rebuilt,stats.recovered,stats.reflReplay,stats.reflFull=0,0,0,0,0,0,0,0
  stats.t0=now end
 -- (budget 2: every wait by the frame's own time, its first crowd draw -- as
 -- the Collection's clock is one time a frame; by the moment of each draw, a
 -- slow frame's own length would count against the 2 s)
 if M.REPOSE_BUDGET then now=stats.t0 or now end
 local T=M.reposeTotals
 local x=(tonumber(ctx.px)or 0)+8
 local z=(tonumber(ctx.py)or 0)+8
 local y=(tonumber(ctx.groundHeight)or 0)+(tonumber(ctx.lift)or 0)
 -- the main pass: off the screen, not drawn (and not posed)
 if method=='drawEntity'then
  local vp=R.vp
  if M.LOD_CULL and type(vp)=='table'and tonumber(vp[16])then
   local on=boxOnScreen(vp,tonumber(R.curveK)or 0,(tonumber(R.curveX)or 0),(tonumber(R.curveZ)or 0),
    x-14,y-6,z-14,x+14,y+34,z+14)
   st.seen=on
   if not on then stats.culled=stats.culled+1;return true,true end
  else st.seen=true end
 end
 -- (budget 2) what was captured before the Collection may have let go of it
 -- (2 s without a pose): never replayed, drawn afresh
 if st.called and now-st.called>M.REPOSE_STALE then
  st.entity.n,st.shadow.n=0,0
  if st.refl then for _,p in pairs(st.refl)do p.n=0 end end
 end
 -- (budget 2: the LITE 2 shadow cut below, first: someone drawn in no pass
 -- takes no turn -- a turn spent on them would be a refresh not done)
 if M.REPOSE_BUDGET and method=='drawShadow'and M.LOD_LITE==2 and not st.seen and(st.d or 0)>M.LOD_SHADOW_FAR then
  stats.culled=stats.culled+1
  return true,true
 end
 -- posed again this frame? (decided once a frame, for every pass)
 local B=M.repose
 if st.serial~=serial then
  st.serial=serial
  local dx,dy,dz=x-eye[1],y+12-(tonumber(eye[2])or 0),z-eye[3]
  local d=sqrt(dx*dx+dy*dy+dz*dz)
  st.d=d
  local lite=(M.LOD_LITE==2)and 1.6 or(M.LOD_LITE==1 and 1.3 or 1)
  local every
  if not st.seen then every=M.LOD_OFF_EVERY
  elseif d<=M.LOD_NEAR/lite then every=0
  elseif d<=M.LOD_MID then every=M.LOD_MID_EVERY*lite
  else every=M.LOD_FAR_EVERY*lite end
  every=min(every,M.LOD_OFF_EVERY)
  if st.t<-1e8 then st.t=now-math.random()*every end
  local due=every<=0 or now-st.t>=every
  st.reposed=false
  local budget=M.REPOSE_BUDGET
  if budget and B.serial~=serial then turns(B,serial,now)end
  local captured=st.entity.n>0 or st.shadow.n>0
  if not captured and st.refl then for _,p in pairs(st.refl)do if p.n>0 then captured=true;break end end end
  local late=now-st.t>=((budget and B.deadline)or M.REPOSE_DEADLINE)
  if budget then
   -- (in next frame's turns -- anyone drawn now has a capture by then: how
   -- often due, and how much a wait counts: near x3, mid x1.5, far x1, off
   -- the screen x0.5)
   local W=M.REPOSE_WEIGHT
   st.every=every
   st.w=(not st.seen and W.off)or(every<=0 and W.near)or(d<=M.LOD_MID and W.mid)or W.far
   local cand=B.cand;if cand then cand[#cand+1]=st end
  end
  if budget and captured and(due or late)then
   if st.pick==serial and B.left>0 then
    st.full=true;stats.admitted=stats.admitted+1;T.admitted=T.admitted+1
   elseif late then
    st.full=true;stats.forced=stats.forced+1;T.forced=T.forced+1
   else
    st.full=false;stats.deferred=stats.deferred+1;T.deferred=T.deferred+1
   end
  else st.full=due end
  if st.full then
   st.t=now;st.reposed=true
   stats.refreshed=stats.refreshed+1;T.refreshed=T.refreshed+1
   if budget then B.left=B.left-1;B.admitted=B.admitted+1 end
  end
 end
 -- LITE 2: no shadow from someone far away who was off the screen last frame
 -- (a shadow a few pixels long, off the screen with them)
 if method=='drawShadow'and M.LOD_LITE==2 and not st.seen and(st.d or 0)>M.LOD_SHADOW_FAR then
  stats.culled=stats.culled+1
  return true,true
 end
 local pass
 if refl then
  -- (budget 2: the reflection's own capture, one for each water plane)
  local key=tostring(tonumber(ctx.reflectionPlane))..':'..tostring(tonumber(ctx.reflectionRaise)or 0)
  local rs=st.refl
  if not rs then rs={};st.refl=rs;st.reflN=0 end
  pass=rs[key]
  if not pass then
   if(st.reflN or 0)>=4 then rs={};st.refl=rs;st.reflN=0 end
   pass={n=0,list={}};rs[key]=pass;st.reflN=(st.reflN or 0)+1
  end
 else pass=method=='drawShadow'and st.shadow or st.entity end
 if not st.full and pass.n>0 then
  local okR=pcall(replay,method,pass)
  if okR then
   stats.replay=stats.replay+1;T.replays=T.replays+1
   if refl then stats.reflReplay=stats.reflReplay+1;T.reflReplay=T.reflReplay+1 end
   return true,true
  end
  pass.n=0;stats.recovered=stats.recovered+1;T.recovered=T.recovered+1
 end
 if not st.full and M.REPOSE_BUDGET then
  -- (budget 2) a Collection draw outside the ranking -- a first draw, a pass
  -- with nothing captured, a replay that failed: this person's refresh for
  -- the frame (every later pass draws the same fresh pose), and charged
  st.full=true;st.t=now;st.reposed=true
  stats.extra=stats.extra+1;T.extra=T.extra+1
  stats.refreshed=stats.refreshed+1;T.refreshed=T.refreshed+1
  if B.serial==serial then B.left=B.left-1;B.admitted=B.admitted+1 end
 end
 stats.full=stats.full+1;T.calls=T.calls+1
 if refl then stats.reflFull=stats.reflFull+1;T.reflFull=T.reflFull+1 end
 -- what a refresh costs: timed for people drawn before (a first draw may
 -- load the model)
 local t1=nil
 if st.reposed and M.REPOSE_BUDGET and st.mesh~=nil then
  local okT1,tt=pcall(love.timer.getTime)
  if okT1 then t1=tt end
 end
 local ok,claimed=fullCall(method,fn,ctx,pass)
 st.called=now
 if t1 then
  local okT2,t2=pcall(love.timer.getTime)
  if okT2 then
   B.spent=B.spent+max(0,t2-t1)
   if st.timedSerial~=serial then st.timedSerial=serial;B.timed=(B.timed or 0)+1 end
  end
 end
 if pass.n>0 then
  local m=pass.list[1].mesh
  if st.mesh~=nil and m~=st.mesh then stats.rebuilt=stats.rebuilt+1;T.rebuilt=T.rebuilt+1 end
  st.mesh=m
 end
 return ok,claimed
end
M._lodCall=lodCall
M._lodState=lodState
-- (TEST243) someone tipped over (asleep) and now up again: posed afresh on
-- the next draw -- nothing of what was captured for them before is replayed
function M.lodReset(actor)
 if actor~=nil then lodState[actor]=nil end
end
-- TEST257: actors kept OUT of one cinematic shot (the ending's awake close-up
-- clears townsfolk who would fill its foreground). A hidden actor's body,
-- shadow and reflection are claimed and not drawn -- before any pose, any
-- cached replay, and before the Collection's provider (so no 2D sprite takes
-- its place). Anyone, cast entry or not; never the player or the follower.
-- The set is the caller's: hide() each, then hideClear() (also on clear()).
local hidden=setmetatable({},{__mode='k'})
M.hiddenStats={claimed=0}
function M.hide(actor,on)
 if type(actor)~='table'then return false end
 if on==false then hidden[actor]=nil;return true end
 if isFollower(actor)then return false end
 hidden[actor]=true
 return true
end
function M.isHidden(actor)return actor~=nil and hidden[actor]==true end
function M.hideClear()for k in pairs(hidden)do hidden[k]=nil end end
function M.hiddenCount()local n=0;for _ in pairs(hidden)do n=n+1 end;return n end
local cardsModule,cardsChecked
local function crowdCards()
 if not cardsChecked then
  cardsChecked=true
  local ok,C=pcall(V.require,'ParadeCrowdCards')
  if ok and type(C)=='table'then cardsModule=C end
 end
 return cardsModule
end
local draw
draw=function(method,ctx)
 if type(ctx)~='table'or ctx.isPlayer or ctx.role=='player'then return false end
 local actor=ctx.actor or ctx.entity or(ctx.pose and ctx.pose.entity)
 if not actor then return false end
 if hidden[actor]then M.hiddenStats.claimed=M.hiddenStats.claimed+1;return true end
 local entry=cast[actor]
 -- (TEST235: anyone tipped over -- one of ours or not -- is drawn here, by
 -- the same provider, tipped)
 local rec=poses[actor]
 if not tipped(rec)or method=='drawReflection'then rec=nil end
 if not entry and not rec then return false end
 local cov=nil
 if entry then cov=covered(entry,actor,method)end
 if cov==true then return true end
 -- Claim the skipped shadow before a provider poses/uploads a mesh, and before
 -- its cached shadow is replayed. Returning false would draw a sprite shadow.
 if entry and not rec and cov==nil and method=='drawShadow'and farCrowdShadow(ctx,entry)then return true end
 local mod=modRef or V.mod
 local okPF,provider=pcall(npcProviderFrame,mod)
 if not okPF then provider=npcProvider(mod)end
 local fn=type(provider)=='table'and provider[method]
 if type(fn)~='function'then return false end
 -- TEST259: only parade-owned, unposed, distant Celadon spectators. Warm
 -- the small shared atlas under the white card; close-ups use this same
 -- Collection provider. The late pass submits all selected cards once.
 if entry and not poses[actor]and not isFollower(actor)then
  local Cards=crowdCards()
  if Cards then
   if cov==false then
    local okP,CP=pcall(V.require,'ChampionParade')
    if okP then pcall(Cards.warm,mod,CP)end
   elseif cov==nil and(method=='drawEntity'or method=='drawShadow'or method=='drawReflection')then
    local okR,R=pcall(V.require,'Voxel3D')
    local okP,CP=pcall(V.require,'ChampionParade')
    if okR and okP and type(R)=='table'and type(CP)=='table'then
     local okC,claimed=pcall(Cards.try,method,ctx,actor,entry,R,CP,mod,draw)
     if okC and claimed then return true end
    end
   end
  end
 end
 local oldDef,oldSprite
 if entry then
  oldDef=actor.def
  -- One cached definition per actor, not fresh tables for every render pass.
  if not entry.renderDef or entry.sourceDef~=oldDef then
   local renderDef={}
   for k,v in pairs(type(oldDef)=='table'and oldDef or{})do renderDef[k]=v end
   renderDef.trainerClass=entry.trainerClass
   renderDef.trainerParty=nil
   renderDef.sprite=entry.sprite or renderDef.sprite
   entry.sourceDef,entry.renderDef=oldDef,renderDef
  end
  oldSprite=ctx.spriteId
  actor.def=entry.renderDef
  ctx.spriteId=entry.sprite or oldSprite
 end
 local success,claimed
 if rec then
  success,claimed=M.withNpcPose(rec,(tonumber(ctx.px)or 0)+8,(tonumber(ctx.groundHeight)or 0)+(tonumber(ctx.lift)or 0),
   (tonumber(ctx.py)or 0)+8,method,fn,ctx)
 else
  -- (TEST242: the crowd's LOD only with the picture up -- under the card a
  -- person drawn is one being warmed, and must really be drawn)
  if entry and cov==nil then success,claimed=lodCall(method,fn,ctx,actor)
  else success,claimed=pcall(fn,ctx)end
 end
 if entry then
  ctx.spriteId=oldSprite
  actor.def=oldDef
  if not success and not entry.warned then
   entry.warned=true
   if mod.log and mod.log.warn then
    mod.log:warn('Parade character %s: %s',entry.name or '?',tostring(claimed))
   end
  end
 end
 return success and claimed==true
end
M._draw=draw
function M.bind(actor,identity)
 if type(actor)~='table'or type(identity)~='table'then return end
 -- Copy: warnings/state must not mutate the shared roster entries.
 local entry={}
 for k,v in pairs(identity)do entry[k]=v end
 cast[actor]=entry
end
-- (the stop's people go: their identities, and anyone's pose with them)
function M.clear()
 cast={};lodState=setmetatable({},{__mode='k'});M._lodState=lodState
 M.reposeReset() -- drop candidates and cost history when leaving/restarting a stop
 warm={serial=-1,budget=0,newKinds=0,seen={}};M.clearPoses();M.hideClear()
 if cardsModule then pcall(cardsModule.clear)end
end
function M.install(mod)
 modRef=mod
 if handle then return end
 local bridge=V.require('CharacterRenderers')
 local spec={apiVersion=1,id='battle_art.parade_cast',priority=300,
  name='Champion parade: real game NPCs'}
 for _,method in ipairs({'drawEntity','drawShadow','drawReflection'})do
  local pass=method
  spec[pass]=function(ctx)return draw(pass,ctx)end
 end
 handle=assert(bridge.register(spec))
end
function M.dispose()
 M.clear()
 pcall(function()V.require('ParadeSleepEyes').clear()end)
 provMemo.serial,provMemo.mod,provMemo.provider=nil,nil,nil
 if handle then handle:release();handle=nil end
 modRef=nil
end
return M
