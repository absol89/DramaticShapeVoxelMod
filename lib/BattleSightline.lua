-- TEST140: battle camera spring arm. The staged / Stadium battle camera
-- swings around the arena; in caves and towns it could end up behind a rock
-- wall, a ledge or a building and show nothing but scenery for seconds.
--
-- Each frame the line from the camera's focus out to its eye is marched over
-- the map grid. If a blocking cell rises above that line, the eye is pulled
-- in to just in front of it, like a third-person spring arm. The lens is
-- widened to match, so the Pokemon stay the same size on screen while the
-- camera slides in. Pull-in is quick and the release is gentle, so the shot
-- never pops. Whatever still crosses the view (ceiling, stalactites, tree
-- crowns) is opened by the battle sightline cutaway in Voxel3D.
--
-- TEST233: TREE CROWNS. The grid sees a Legendary route tree as a 16px
-- block on its own cell; its crown is up to 47px tall and reaches 24px past
-- the trunk. On Route 1 the long lens stood behind the row of trees south of
-- the arena and looked through them (or, swung a little, from inside one):
-- a whole intro of green leaves. So the arm now also asks BattleCrowns
-- whether the eye is in a crown or looking at either Pokemon through one,
-- and if so slides in along the same line to the longest arm that is clear.
-- Into a crown it SNAPS (never a frame of leaves); back out it eases as
-- before. The question is asked only when the pose has moved (a cut, the
-- player steering, the drift crossing a 2px step), not every frame, and a
-- camera cut (the eye or aim jumping) takes the new arm at once instead of
-- easing toward it. Authored camera-safe arenas (Viridian Forest) keep their
-- proven fixed shot. Any failure in the crown question leaves the arm
-- exactly as it was.
local V=...
local M={}
local state={key=nil,frac=1,time=nil}
local CELL=16
local STEP=3

-- TEST233 tuning
M.CROWNS=true          -- the crown question at all
M.CROWN_MIN_K=0.35     -- never pull in further than this for a crown
M.CROWN_QUANT=2        -- px: a pose that moved less reuses the last answer
M.CUT_PX=24            -- px: a jump this big in one frame is a camera cut
M.lastCrown=nil        -- diagnostics: {k=, why=, tree=} of the last answer
local logged=nil       -- the arena key the crown arm last reported on

-- one line per battle in the mod log, so a device run can confirm the arm
local function note(key,k,why,tree)
 if logged==key then return end
 logged=key
 local log=V.mod and V.mod.log
 if log and log.info then
  pcall(log.info,log,"TEST233 battle camera: %s tree crown at %s -- eye pulled in to %d%% of the arm",
    why=="inside" and "inside a" or "looking through a",tostring(tree),math.floor((k or 0)*100+.5))
 end
end

local function now()
 local ok,t=pcall(function()return love.timer.getTime()end)
 return ok and t or 0
end

-- Height that blocks the camera at a cell, or nil when the cell is open.
local function blocker(map,cx,cy,cave,groundAt)
 local okIn,inb=pcall(map.inBounds,map,cx,cy)
 if okIn and not inb then return cave and 64 or nil end
 local okW,walk=pcall(map.isWalkableCell,map,cx,cy)
 if okW and walk then return nil end
 local okH,h=pcall(groundAt,map,cx,cy,cx*CELL,cy*CELL)
 h=okH and tonumber(h) or 0
 if cave and h<=0 then
  -- a cave's unwalkable non-water cell is rock even when its shape is flat
  local okWa,wet=pcall(function()return map.isWaterCell and map:isWaterCell(cx,cy)end)
  if not(okWa and wet) then h=28 end
 end
 if h<=0 then return nil end
 -- caves draw their inner walls 1.875x the source height (ChunkMesher)
 return cave and h*1.875 or h
end
-- The cave roof (CaveAtmosphere3D, about y=66) is drawn everywhere except a
-- clearing of radius 68 around the arena; keep the eye under it.
local ROOF_Y,ROOF_CLEAR=59,64

-- TEST233: the crown arm for this pose, memoised on the pose quantised to
-- CROWN_QUANT px (and the grid arm it starts from). Returns k or nil.
local memo={valid=false}
local function crownArm(cam,map,groundY,arena,neighbors,kStart,kMin)
 local Crowns=V.require("BattleCrowns")
 local set=Crowns.forArena(map,arena,neighbors)
 if not(set and set.count and set.count>0)then M.lastCrown=nil;return nil end
 local e,f,q=cam.eye,cam.focus,M.CROWN_QUANT
 local a1,a2,a3=math.floor(e[1]/q),math.floor(e[2]/q),math.floor(e[3]/q)
 local b1,b2,b3=math.floor(f[1]/q),math.floor(f[2]/q),math.floor(f[3]/q)
 local ks=math.floor(kStart*50+.5)
 if memo.valid and memo.set==set and memo.a1==a1 and memo.a2==a2 and memo.a3==a3
    and memo.b1==b1 and memo.b2==b2 and memo.b3==b3 and memo.ks==ks
    and memo.g==groundY then
  return memo.k,set,memo.ta,memo.tb
 end
 local ta,tb=Crowns.targets(arena,groundY)
 local k=kStart
 local clear,why,tree=Crowns.poseClear(set,{f[1]+(e[1]-f[1])*kStart,
   f[2]+(e[2]-f[2])*kStart,f[3]+(e[3]-f[3])*kStart},ta,tb,f)
 if not clear then
  k=Crowns.clearArm(set,f,e,ta,tb,kStart-Crowns.ARM_STEP,kMin)
 end
 memo.valid,memo.set,memo.ta,memo.tb=true,set,ta,tb
 memo.a1,memo.a2,memo.a3,memo.b1,memo.b2,memo.b3=a1,a2,a3,b1,b2,b3
 memo.ks,memo.g,memo.k=ks,groundY,k
 M.lastCrown=not clear and {k=k,why=why,tree=tree and(tree.cx..","..tree.cy)}or nil
 return k,set,ta,tb
end

function M.adjust(cam,map,groundY,arena,neighbors)
 if not(cam and cam.eye and cam.focus and map and map.isWalkableCell)then return cam end
 local okG,VoxelScene=pcall(V.require,"VoxelScene")
 local groundAt=okG and VoxelScene and VoxelScene.groundAt
 if not groundAt then return cam end
 local cave=map.tileset and map.tileset.id=="CAVERN"
 local e,f=cam.eye,cam.focus
 local dx,dy,dz=e[1]-f[1],e[2]-f[2],e[3]-f[3]
 local dist=math.sqrt(dx*dx+dy*dy+dz*dz)
 if dist<1 then return cam end
 local base=groundY or 0
 local minDist=math.min(dist,30)

 -- march outward from the focus; the first blocker sets the arm length
 local target=1
 local steps=math.floor(dist/STEP)
 for i=1,steps do
  local s=i/steps
  local px,py,pz=f[1]+dx*s,f[2]+dy*s,f[3]+dz*s
  if s*dist>18 then
   local h=blocker(map,math.floor(px/CELL),math.floor(pz/CELL),cave,groundAt)
   local roofed=false
   if cave and py>ROOF_Y then
    local mx,mz=arena and arena.mid and arena.mid[1] or f[1],arena and arena.mid and arena.mid[2] or f[3]
    local hx,hz=px-mx,pz-mz
    roofed=hx*hx+hz*hz>ROOF_CLEAR*ROOF_CLEAR
   end
   if roofed or (h and base+h+2>py) then
    target=math.max(minDist/dist,(s*dist-7)/dist)
    break
   end
  end
 end

 -- smooth: pull in fast, ease back out slowly; reset on a new battle
 local key=arena and arena.mid and (tostring(map.id)..":"..arena.mid[1]..":"..arena.mid[2]) or tostring(map.id)

 -- TEST233: tree crowns on the same arm (see the header)
 local crownK,cset,cta,ctb=nil,nil,nil,nil
 if M.CROWNS and arena and arena.mid and arena.player and arena.enemy
    and not arena.cameraSafe then
  local kMin=math.max(minDist/dist,M.CROWN_MIN_K)
  if target>=kMin then
   local okC,k,set,ta,tb=pcall(crownArm,cam,map,base,arena,neighbors,target,kMin)
   if okC then cset,cta,ctb=set,ta,tb else memo.valid=false end
   if okC and k and k<target then crownK=k end
   if crownK and M.lastCrown then
    pcall(note,key,crownK,M.lastCrown.why,M.lastCrown.tree)
   end
  end
 end
 local want=crownK or target

 local t=now()
 -- TEST233: a camera CUT (the raw eye or aim jumping) starts on its own arm
 local cut=false
 if state.ex then
  local jx,jy,jz=e[1]-state.ex,e[2]-state.ey,e[3]-state.ez
  local fx,fy,fz=f[1]-state.fx,f[2]-state.fy,f[3]-state.fz
  local c2=M.CUT_PX*M.CUT_PX
  cut=jx*jx+jy*jy+jz*jz>c2 or fx*fx+fy*fy+fz*fz>c2
 end
 state.ex,state.ey,state.ez,state.fx,state.fy,state.fz=e[1],e[2],e[3],f[1],f[2],f[3]
 if state.key~=key or cut then state.key,state.frac,state.time=key,want,t end
 local dt=math.max(0,math.min(.1,t-(state.time or t)));state.time=t
 local rate=want<state.frac and 9 or 1.6
 state.frac=state.frac+(want-state.frac)*math.min(1,dt*rate)
 -- never ease INTO a crown: the arm is in front of it from this frame on
 if crownK and state.frac>crownK then state.frac=crownK end
 -- and no in-between arm while easing either: if this frame's eased pose
 -- would be in or behind a crown, take the answer (`want`) whole
 if cset and math.abs(state.frac-want)>1e-3 then
  local okA,clear=pcall(V.require("BattleCrowns").armClear,cset,f,e,cta,ctb,state.frac)
  if okA and clear==false then state.frac=want end
 end
 local k=state.frac
 if k>=.999 then return cam end

 local out={}
 for kk,v in pairs(cam)do out[kk]=v end
 out.eye={f[1]+dx*k,f[2]+dy*k,f[3]+dz*k}
 -- widen the lens so the subjects keep their on-screen size
 if cam.fov then
  local fov=2*math.atan(math.tan(cam.fov/2)/k)
  out.fov=math.min(fov,math.rad(85))
 end
 return out
end

-- for the suite: forget the smoothing and the memo
function M._reset()
 state={key=nil,frac=1,time=nil}
 memo={valid=false}
 M.lastCrown=nil
 logged=nil
end

return M
