-- Visual support for external Stadium providers. Native StadiumModels already
-- calls BattleRaft.support before applying its move/capture choreography.
local V=...;local M={}
local rest=setmetatable({},{__mode='k'})
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<1e7 end
-- Stadium 1 exposes skinned bounds; the Stadium 2 overworld bridge exposes
-- only metrics in the units consumed by its matrix. Do not skip that bridge.
local function bounds(mon)
 if type(mon.rig.posedBounds)=='function'then
  local ok,lo,hi=pcall(mon.rig.posedBounds,mon.rig)
  if ok and finite(lo)and finite(hi)and hi>lo then return lo,hi end
 elseif mon.stadium2==true and type(mon.model)=='table'then
  local floor,height=tonumber(mon.model.floor)or 0,tonumber(mon.model.height)
  if finite(floor)and finite(height)and height>0 then return floor,floor+height end
 end
end
-- Read the skinned idle shape, not just the pack's bind floor. Freeze this
-- model-space baseline through attacks/recoil/capture so their lift survives.
function M.rest(mon,battle,side)
 if not(mon and mon.model and mon.rig)then return 0 end
 local rec=rest[mon]
 if rec and(rec.model~=mon.model or rec.rig~=mon.rig)then rest[mon]=nil;rec=nil end
 local q=side and battle and battle.legendaryQ57 and battle.legendaryQ57[side]
 local intake=side=='enemy'and battle and battle.dramaticShape3DBallIntake
 local deformed=(q and not q.subjectDone)or(type(intake)=='table'and intake.active)
 if mon.state=='idle'and not deformed and not(battle and battle.animPlaying)
     and (tonumber(mon.scale)or 1)>=.999
     and type(mon.rig.posedBounds)=='function'then
  local ok,lo,hi=pcall(mon.rig.posedBounds,mon.rig)
  local root=tonumber(mon.model.rootScale)or 1
  if root<=0 then root=1 end
  local floor,height=tonumber(mon.model.floor),tonumber(mon.model.height)
  if ok and finite(lo)and finite(floor)and finite(height)and height>0
      and math.abs(lo-floor/root)<height/root*2 then
   rec=rec or{model=mon.model,rig=mon.rig};rec.delta=lo-floor/root
   if finite(hi)and hi>lo and hi-lo<height/root*3 then rec.span=hi-lo end
   rest[mon]=rec
  end
 end
 return rec and rec.delta or 0,rec and rec.span
end
function M.model(model,metrics,root,worldHeight,ground,battle,arena,side,grounded,restDelta,wetHeight)
 if not(model and metrics and arena and arena.map and arena.map.isWaterCell)
   or V.require('UiBackplates').arenaFill:get()~='OFF'
   or not V.require('CommunityVisuals').customRoads()then return model end
 local raft=V.require('BattleRaft')
 if not raft.onWater(arena.map,arena[side])or raft.kind(battle,side)=='air'then return model end
 -- Q57 owns the entire deformed capture envelope, including its source/mouth.
 local q=battle and battle.legendaryQ57 and battle.legendaryQ57[side]
 if q and not q.subjectDone then return model end
 local h=tonumber(worldHeight)
 if not(h and h>0 and h<10000)then return model end
 local support=raft.support(arena,battle,side,ground,finite(wetHeight)and wetHeight>0 and wetHeight or h,0)
 local pull=0
 local intake=side=='enemy'and battle and battle.dramaticShape3DBallIntake
 if type(intake)=='table'and intake.active then
  pull=math.max(0,math.min(1,tonumber(intake.pull)or 0))
 end
 if not grounded then model=V.require('SafariFooting').unhover(model,metrics,root,.5)end
 if raft.kind(battle,side)=='swimmer'and finite(restDelta)and restDelta~=0 then
  local Mat=V.require('Mat4');model=Mat.mul(model,Mat.translate(0,-restDelta,0))
 end
 -- Fade the support offset along the existing intake trajectory so its end
 -- remains the actual ball mouth. Hops, recoil and Fly translations survive.
 local dy=(support-ground)*(1-pull)
 if dy~=0 then local Mat=V.require('Mat4');model=Mat.mul(Mat.translate(0,dy,0),model)end
 return model
end
function M.legacy(out,provider,arena,ground,battle)
 if not(provider.legendaryStadium1Adapter and type(out)=='table')then return out end
 for _,side in ipairs({'enemy','player'})do
  local p=out[side];local mon=p and p.mon
  if mon and mon.model and type(mon.worldHeight)=='function'then
   local ok,h=pcall(mon.worldHeight,mon)
   if ok then
    local grounded=side=='enemy'and V.require('SafariFooting').standing(battle,arena,side)
    local delta,span,wetHeight=0;local raft=V.require('BattleRaft')
    if arena and V.require('CommunityVisuals').customRoads()
        and V.require('UiBackplates').arenaFill:get()=='OFF'
        and raft.kind(battle,side)=='swimmer'and raft.onWater(arena.map,arena[side])then
     delta,span=M.rest(mon,battle,side)
     -- worldHeight describes bind scale; idle shape can have very different
     -- bounds. Use its measured height, held through attack/capture motion.
     local root=tonumber(mon.model.rootScale)or 1
     local height=tonumber(mon.model.height)
     if finite(span)and root>0 and height and height>0 then wetHeight=span*root*h/height end
    end
    p.modelMatrix=M.model(p.modelMatrix,mon.model,mon.model.rootScale,h,ground,battle,arena,side,grounded,delta,wetHeight)
   end
  end
 end
 return out
end
-- The Stadium bridge prepares these matrices before this hook. Never change
-- actor coordinates. A Surf mount and its render-only saddle move together.
function M.roaming(posed,state)
 if not(state and state.map and V.require('CommunityVisuals').customRoads())then return end
 local raft=V.require('BattleRaft');local Mat=V.require('Mat4')
 local water=(V.require('TileShape').heights()or{}).water or -2
 for _,p in ipairs(posed or{})do
  local mon,m,e=p.stadiumMon,p.stadiumMatrix,p.entity
  local ride=type(p.surfMount)=='table'and p.surfMount or nil
  local rider=ride and ride.playerPose
  local seat=rider and rider.surfRide
  local liveRide=ride and ride.mountPose==p and seat and finite(seat.seatY)
    and finite(ride.seatY)and state.player and state.player.surfing
    and not state.flyAnim and not state.player._pokepcAsPokemon
  if mon and mon.rig and m and e and not p.isPlayer and not p.surfRide
      and (not p.surfMount or liveRide)
      and not e._stadiumSkyRideMount and not e._stadiumSkyRideLift
      and (liveRide or raft.speciesKind(p.stadiumDex)=='swimmer')then
   local map=state.map
   for _,g in ipairs(state.ghosts or{})do if g.npc==e then map=g.map or map;break end end
   local x,z=tonumber(e.cellX),tonumber(e.cellY)
   if liveRide and finite(p.px)and finite(p.py)then
    x,z=math.floor((p.px+8)/16),math.floor((p.py+8)/16)
   end
   if x and z and map.isWaterCell and map:isWaterCell(x,z)==true then
    local lo,hi=bounds(mon)
    -- Ordinary swimming matrices have yaw and scale. Do not approximate a
    -- banked/tilted or deformed provider with a vertical-only bounds measure.
    if finite(lo)and finite(hi)and hi>lo and finite(m[6])and m[6]>0
        and math.abs(m[5])<1e-6 and math.abs(m[7])<1e-6 then
     local h=(hi-lo)*m[6]
     local bob=liveRide and math.sin((tonumber(mon.time)or 0)*1.8)*.12 or 0
     local target=water-raft.immersion(p.stadiumDex,h)+(tonumber(p.lift)or 0)+bob
     local dy=target-(m[8]+lo*m[6])
     if finite(dy)and math.abs(dy)<math.max(16,h*2)then
      p.stadiumMatrix=Mat.mul(Mat.translate(0,dy,0),m)
      mon.model_matrix=p.stadiumMatrix
      if liveRide then
       ride.seatY=ride.seatY+dy
       if seat~=ride then seat.seatY=seat.seatY+dy end
      end
     end
    end
   end
  end
 end
end
return M
