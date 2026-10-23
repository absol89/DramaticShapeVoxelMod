-- Parade-owned sleep for the current follower AND town Pokemon. Native
-- sleep poses settle briefly, then hold; idle-only birds cannot keep flapping.
-- Every method/material override belongs to one live instance and is restored.
local V=...
local M={REVISION='parade-partner-sleep-263',SETTLE=.55}
local held={}
local placed={} -- pose record -> frozen town-bird placement, through getting up
local anchor=nil
local function eyes()
 local ok,E=pcall(V.require,'ParadePokemonSleepEyes');return ok and E or nil
end
local function restore(obj,name,wrapper,own)
 if wrapper and obj[name]==wrapper then obj[name]=own end
end
function M.isRestBird(owner)
 if type(owner)~='table'then return false end
 local dex=tonumber(owner.dex or owner.species or(type(owner.model)=='table'and owner.model.species))
 return dex==16 or dex==17 or dex==18
end
local MOTION={'px','py','cellX','cellY','facing','pinnedFacing','moving','progress',
 'targetX','targetY','wanders','steps'}
local function restoreMotion(p)
 for _,k in ipairs(MOTION)do p.entity[k]=p.saved[k]end
end
local function holdMotion(p)
 restoreMotion(p)
 p.entity.moving=false;p.entity.wanders=false;p.entity.steps=false
end
-- Animation time is not placement. Other overworld controllers can still
-- change position, heading, bob or scale after the parade has asked a bird
-- to sleep. Keep the actual prepared transform and feet from the first
-- falling frame; never freeze a follower/player or a shared provider.
function M.pinWalker(p,rec)
 if not(rec and type(p)=='table'and type(p.entity)=='table')then return end
 local q=placed[rec]
 if q and q.entity~=p.entity then restoreMotion(q);placed[rec]=nil;q=nil end
 if not q then
  if not(rec.sleep and M.isRestBird(p.stadiumMon)and type(p.stadiumMatrix)=='table')then return end
  q={entity=p.entity,saved={},matrix={},foot={}}
  for _,k in ipairs(MOTION)do q.saved[k]=p.entity[k]end
  for i=1,16 do q.matrix[i]=p.stadiumMatrix[i]end
  local f=p.stadiumFoot
  q.foot[1]=type(f)=='table'and f[1]or(tonumber(p.px)or 0)+8
  q.foot[2]=type(f)=='table'and f[2]or(tonumber(p.gh)or 0)+(tonumber(p.lift)or 0)
  q.foot[3]=type(f)=='table'and f[3]or(tonumber(p.py)or 0)+8
  placed[rec]=q
 end
 holdMotion(q)
 p.stadiumMatrix=q.matrix;p.stadiumFoot=q.foot
end
-- Maintain the hold even on frames where an external controller culled the
-- entity before the render hook. Cleanup restores the exact original fields.
function M.pinTick()
 for _,p in pairs(placed)do holdMotion(p)end
end
local function wake(owner,r)
 restore(owner,'play',r.wrapper,r.ownPlay)
 restore(owner,'build',r.buildWrapper,r.ownBuild)
 if r.inst then
  restore(r.inst,'update',r.updateWrapper,r.ownUpdate)
  local E=eyes();if E then E.release(r.inst)end
 end
 if r.rig then local E=eyes();if E then E.releaseLegacy(r.rig)end end
 if r.native then
  pcall(r.inst.playContext,r.inst,r.context or 'idle',true)
  owner.context=r.context or 'idle';owner.once=r.once;owner.tick=nil
 elseif r.legacy and owner.rig==r.rig then
  for _,k in ipairs(r.legacyKeys)do owner[k]=r.legacy[k]end
 end
 held[owner]=nil
 if anchor and anchor.owner==owner then anchor=nil end
end
local function hold(owner,rec,walker)
 if type(owner)~='table'then return false end
 local inst=walker and owner.instance or owner.inst
 local r=held[owner]
 if r and(r.inst~=inst or(not inst and r.rig~=owner.rig)or r.rec~=rec or not(rec and rec.sleep))then wake(owner,r);r=nil end
 if not(rec and rec.sleep)then return false end
 if r then return r.native end
 if not inst and not(walker and owner.rig and owner.model)then return false end
 r={inst=inst,rec=rec,context=owner.context or 'idle',once=owner.once,native=false,elapsed=0,
  bird=walker and M.isRestBird(owner)}
 held[owner]=r
 if inst then
  local ok,sleep=pcall(function()return inst:contextSelector('sleep')end)
  local oi,idle=pcall(function()return inst:contextSelector('idle')end)
  -- The Pidgey family's standing sleep/idle pose still reads as awake in
  -- the town shot. Freeze its current skeleton and use the planned fall;
  -- do not suppress that transform merely because a sleep selector exists.
  if not r.bird and ok and type(sleep)=='number'and sleep>=0 and sleep<65535 and not(oi and sleep==idle)then
   local played,yes=pcall(inst.playContext,inst,'sleep',true)
   r.native=played and yes==true
  end
  if r.native then owner.context='sleep';owner.once=nil;owner.tick=nil end
  if type(inst.update)=='function'then
   r.ownUpdate=rawget(inst,'update');r.update=inst.update
   r.updateWrapper=function(self,dt,runtime)
    if self~=inst or held[owner]~=r then return r.update(self,dt,runtime)end
    if r.frozen then return true end
    local step=r.native and math.min(math.max(0,tonumber(dt)or 0),math.max(0,M.SETTLE-r.elapsed))or 0
    r.elapsed=r.elapsed+step
    local rt={};for k,v in pairs(type(runtime)=='table'and runtime or{})do rt[k]=v end
    rt.context=r.native and 'sleep' or r.context
    local result=r.update(self,step,rt)
    -- Calling update(0) still runs renderer handlers/pose processing. Once
    -- settled, reuse the already-built geometry instead of rebuilding it.
    if not r.native or r.elapsed>=M.SETTLE then r.frozen=true end
    return result
   end
   inst.update=r.updateWrapper
  end
  local E=eyes();if E then r.eyeParts=E.hold(inst)or 0 end
  pcall(inst.update,inst,0,{context=owner.context})
 else
  -- Stadium 1 builds after distance-based locomotion. Freeze at that boundary.
  r.legacy={}
  r.rig=owner.rig
  r.legacyKeys={'anim','aux','time','loop','state','done','dt'}
  for _,k in ipairs(r.legacyKeys)do r.legacy[k]=owner[k]end
  if type(owner.build)=='function'then
   r.ownBuild=rawget(owner,'build');r.build=owner.build
   -- Initialise once at the captured clock. Re-running legacy anchor/skin
   -- with dt=0 is not a guaranteed no-op, and can shift an already posed rig.
   owner.dt=0
   local built,result=pcall(r.build,owner)
   r.frozen=built and result~=false
   r.buildWrapper=function(self,...)
    if self==owner and held[owner]==r then
     for _,k in ipairs(r.legacyKeys)do self[k]=r.legacy[k]end
     self.dt=0
     if r.frozen then return true end
     local result=r.build(self,...)
     if result~=false then r.frozen=true end
     return result
    end
    return r.build(self,...)
   end
   owner.build=r.buildWrapper
  end
  local E=eyes();if E then r.eyeParts=E.holdLegacy(r.rig,owner.aux)or 0 end
 end
 if walker and type(owner.play)=='function'then
  r.ownPlay=rawget(owner,'play');r.play=owner.play
  r.wrapper=function(self,context,...)
   if self==owner and held[owner]==r then
    if not r.native then return true end
    context='sleep'
   end
   return r.play(self,context,...)
  end
  owner.play=r.wrapper
 end
 return r.native
end
function M.float(md,rec)return hold(md,rec,false)end
function M.walker(mon,rec)return hold(mon,rec,true)end
function M.native(owner)local r=held[owner];return r and r.native or false end
function M.active()return next(held)~=nil end
function M.status()
 local out={total=0,birds=0,birdEyes=0,legacy=0}
 for _,r in pairs(held)do
  out.total=out.total+1;if r.rig then out.legacy=out.legacy+1 end
  if r.bird then out.birds=out.birds+1;if(r.eyeParts or 0)>0 then out.birdEyes=out.birdEyes+1 end end
 end
 return out
end
-- Ground the falling bird's actual posed vertices, including an authored
-- flying/hover offset. This matrix is shared by color, shadow and reflection.
-- As it wakes, fade the correction out with the fall angle so flight resumes.
function M.groundBird(owner,matrix,groundY,rec)
 if not(M.isRestBird(owner)and rec and matrix and tonumber(groundY))then return end
 local weight=math.min(1,math.abs(rec.a or 0)/1.2)
 if weight<=0 then return end
 local renderer=owner.rig
 if owner.instance then
  local ok,value=pcall(function()return owner.instance:renderer()end)
  if ok then renderer=value end
 end
 local low=math.huge
 for _,part in ipairs(type(renderer)=='table'and renderer.parts or{})do
  for _,v in ipairs(part.rows or{})do
   local y=matrix[5]*v[1]+matrix[6]*v[2]+matrix[7]*v[3]+matrix[8]
   if y==y and y<low then low=y end
  end
 end
 if low<math.huge and low>-math.huge then matrix[8]=matrix[8]+(groundY+.15-low)*weight end
end
function M.release(owner)local r=held[owner];if r then wake(owner,r)end end
function M.releasePose(rec)
 for owner,r in pairs(held)do if r.rec==rec then wake(owner,r)end end
 local p=placed[rec];if p then restoreMotion(p);placed[rec]=nil end
end
function M.clear()
 for owner,r in pairs(held)do wake(owner,r)end
 for rec,p in pairs(placed)do restoreMotion(p);placed[rec]=nil end
 anchor=nil
end
function M.locate(owner,matrix)
 local r=held[owner]
 if not(r and r.native and type(matrix)=='table')then return end
 local t=0;pcall(function()t=love.timer.getTime()end)
 if not r.boundsAt or t<r.boundsAt or t-r.boundsAt>=.1 then
  r.boundsAt=t
  local ok,b=pcall(r.inst.bounds,r.inst)
  if ok and type(b)=='table'and tonumber(b.minX)and tonumber(b.maxX)
      and tonumber(b.minY)and tonumber(b.maxY)and tonumber(b.minZ)and tonumber(b.maxZ)then r.bounds=b end
 end
 local b=r.bounds;if not b then return end
 local x,y,z=(b.minX+b.maxX)*.5,b.maxY,(b.minZ+b.maxZ)*.5
 anchor=anchor or{};anchor.owner=owner
 anchor[1]=matrix[1]*x+matrix[2]*y+matrix[3]*z+matrix[4]
 anchor[2]=matrix[5]*x+matrix[6]*y+matrix[7]*z+matrix[8]
 anchor[3]=matrix[9]*x+matrix[10]*y+matrix[11]*z+matrix[12]
end
function M.head()if anchor then return anchor[1],anchor[2],anchor[3],0,0,1,0,1,0 end end
return M
