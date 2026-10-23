-- Solo Dolo q57 geometry/material adapter for Battle Art's world units.
-- Gameplay and inventory stay with the engine. See Q57-PORT-NOTES.txt.
local V=...
local Plasma=V.require('q57/Plasma')
local Material=V.require('q57/Material')
local Release=V.require('q57/Release')
local Breakout=V.require('q57/Breakout')
local Mat4=V.require('Mat4')
local Voxel3D=V.require('Voxel3D')
local Settings=V.require('PokeballSettings')
local A={releaseDuration=Release.DURATION}
-- TEST233: a sent-out Pokemon's ball opens toward the battlefield. Its
-- front -- the button, where it opens -- faces the other side's spot, so the
-- Pokemon comes out facing the fight; it used to face world +Z, which on
-- most arenas is the thrower and the camera behind them (Joseph: "it lands
-- and opens towards me"). Lance's ball opens toward you, yours toward him.
-- The Legendary Collection's throw lands its ball turned the same way when
-- it sees this flag.
A.RELEASE_FACES_FOE=true
local owner,meshes=nil,{}
local function ease(x) x=math.max(0,math.min(1,x));return x*x*x*(x*(x*6-15)+10) end
function A.clear()
  Breakout.clear()
  for _,e in pairs(meshes) do if e.mesh and e.mesh.release then e.mesh:release() end end
  meshes={}
  if owner then owner.legendaryQ57=nil end
  owner=nil
end
function A.prepare(battle,arena,ground,n,entries)
  if not battle then return end
  if owner~=battle then A.clear();owner=battle end
  local poses={};battle.legendaryQ57=poses
  if not Settings.active() then return end
  local function source(side)
    local point=arena[side]
    return {point[1],ground+7,point[2]}
  end
  if n and n.owner==battle and n.ball then
    local mouth={n.ball:mouth()}
    if n.captureFxT and n.captureFxT>0 and not n.captureClosed then
      -- Fit the original convert/hold/drain profile into the selected intake.
      local elapsed=1-math.max(0,math.min(1,n.captureFxT/Settings.captureDuration()))
      n.ball.impactFx=nil
      poses.enemy=Plasma.pose({},0.77+elapsed*1.555,source('enemy'),mouth,14,14,0)
    elseif n.phase=='escape' and (n.escapeAge or 0)<0.28 then
      local age=n.escapeAge or 0;local progress=age/0.28
      local p=Plasma.pose({},1.32,source('enemy'),mouth,14,14,0)
      p.timer,p.release,p.pull,p.convert=age,true,1-ease(progress/.45),1-ease((progress-.28)/.17)
      p.burst=true;p.burstProgress=progress;p.subjectDone=progress>=.45
      p.ball=n.ball
      poses.enemy=p
    end
  end
  if poses.enemy and n then poses.enemy.captureOwner=n end
  for side,e in pairs(entries or {}) do
    if not poses[side] and e.shell and e.age and e.age<Release.DURATION then
      local point=arena[side]
      if point then
        e.shell.pos={point[1],ground+2.2*e.shell.scale,point[2]}
        if A.RELEASE_FACES_FOE then
          local foe=arena[side=='player' and 'enemy' or 'player']
          local dx=foe and tonumber(foe[1]) and foe[1]-point[1]
          local dz=foe and tonumber(foe[2]) and foe[2]-point[2]
          if dx and dz and dx*dx+dz*dz>1e-6 then e.shell.yaw=math.atan2(dx,dz) end
        end
        local opening=math.min(1,e.age/.15)
        local closing=math.max(0,math.min(1,(e.age-1.0)/.15))
        e.shell.lid=opening*(1-closing);e.shell.lidTarget=e.shell.lid
        local p=Release.pose(e.age,source(side),{e.shell:mouth()},14,14,0,'battle')
        if p then p.shell=e.shell;p.entry=e end
        poses[side]=p
      end
    end
  end
end
function A.draw(battle)
  local poses=battle and battle.legendaryQ57
  if not poses then return false end
  local drew=false
  for side,p in pairs(poses) do
    local e=meshes[side]
    if not e then e={};e.vertices,e.indices=Plasma.newGeometry();meshes[side]=e end
    local model=Mat4.identity()
    local paint=p
    if p.burst then
      local u=p.burstProgress
      local beat=Breakout.pose(p.timer)
      local core=beat and beat.core or 0
      Plasma.updateBurst(e.vertices,p.timer,core*(1-ease((u-.12)/.33)))
      local size=(2.2*(p.ball and p.ball.scale or 1)/.048)*(beat and beat.scale or 0)
      model=Mat4.mul(Mat4.translate(p.mouth[1],p.mouth[2],p.mouth[3]),Mat4.scale(size,size,size))
      paint={timer=p.timer,source=p.mouth,mouth=p.mouth,width=p.width,height=p.height,yaw=p.yaw,convert=1,release=true}
    else Plasma.update(e.vertices,p) end
    if not e.mesh then e.mesh=Voxel3D.newMesh(e.vertices,e.indices)
    elseif e.mesh.setVertices then e.mesh:setVertices(e.vertices) end
    if p.burst then
      Breakout.draw(p.timer,p.mouth,p.yaw,p.ball and p.ball.scale)
      if p.ball then p.ball:drawBreakShell(p.burstProgress) end
    end
    if p.shell and p.timer<1.15 then p.shell:drawShell(0) end
    local volumeVisible=p.burst or ((p.fade or 1)>.001 and (not p.release or p.pull<.995))
    if volumeVisible and e.mesh and Material.draw(Voxel3D,e.mesh,nil,model,0,paint,false) then
      drew=true
      if p.captureOwner then p.captureOwner.q57Used=true end
      if p.entry then p.entry.q57Used=true end
    end
  end
  return drew
end
return A
