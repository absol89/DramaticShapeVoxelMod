-- Run from the mod root with Lua 5.1/LuaJIT.
local circleScale, active, stageCalls, fallbackCalls = 1, false, 0, 0
local origin = { 120, 8, 240 }
local vp = { 1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1 }
local function mul(a, b)
  local out = {}
  for r=0,3 do for c=0,3 do
    local n=0
    for k=0,3 do n=n+a[r*4+k+1]*b[k*4+c+1] end
    out[r*4+c+1]=n
  end end
  return out
end
package.loaded['mods.STADIUM2_IMPORTER.lib.renderer'] = { matMul=mul, normalMatrix=function() return vp end }
local radius = function() return 24 end
local stage = { radius=radius, sink=.06 }
local marks = { player={x=10,y=20}, enemy={x=30,y=40} }
local failStage = false
stage.draw = function(g, w, h, frame)
  assert(active, 'circle drawn after voxel depth attachment was resolved')
  assert(w==320 and h==288,
    'supersampled render dimensions leaked into logical attack anchors')
  assert(frame.vp[4]==120 and frame.vp[8]==8 and frame.vp[12]==240,
    'stage camera does not translate Stadium coordinates into voxel world')
  assert(stage.radius()==24*circleScale)
  assert(stage.sink<0, 'circle is buried below the voxel floor')
  stageCalls=stageCalls+1
  if failStage then error('stage failure') end
  return { player={x=999,y=999}, enemy={x=888,y=888} }
end
local pushes = 0
local g = {
  push=function() pushes=pushes+1 end,
  pop=function() pushes=pushes-1 end,
  setCanvas=function() assert(not active) end,
  setShader=function() end, setDepthMode=function() end,
  setBlendMode=function() end, setColor=function() end,
  draw=function() assert(not active) end,
}
local canvas = { getDimensions=function() return 320,288 end }
local providerFails = false
local overworld = {
  providerBegin=function() return true end,
  providerFinish=function() end,
  providerRender=function(_, passes)
    if providerFails then return nil end
    active=true
    local ok, err=pcall(passes.draw, {vp=vp, origin=origin})
    active=false
    if not ok then error(err) end
    return canvas
  end,
}
local modules = {
  Mat4=assert(loadfile("lib/Mat4.lua"))(),
  UiBackplates={ arenaFill={get=function() return 'OFF' end},
    stadiumCircleScale=function() return circleScale end },
  OverworldBattle=overworld, Voxel3D={}, BackdropImage={},
  Gen6Backdrop={}, BossBackdrop={},
}
local api=assert(loadfile('lib/StadiumBackground.lua'))({
  require=function(name) return assert(modules[name]) end,
})
local actorCalls, shadowCalls = 0, 0
local actor = { renderer = {
  drawScene=function(_, pass, model, context)
    assert(active, 'model drawn after voxel depth was resolved')
    assert(model[4]==120 and model[8]==8 and model[12]==240)
    assert(context.viewProjection==vp)
    actorCalls=actorCalls+1
    return true
  end,
  drawShadowMap=function() shadowCalls=shadowCalls+1 end,
} }
local host={Stage=stage,actors={player=actor,enemy=actor},
  visualActor=function() return actor end,
  modelMatrix=function() return vp,0 end}
local ctx={ graphics=g, target={color={},width=1280,height=1152,
    logicalWidth=320,logicalHeight=288},
  camera={vp=vp}, marks=marks,
  scene={battle={},host=host} }
local function fallback() fallbackCalls=fallbackCalls+1; return marks end
for _, value in ipairs({1, 2/3, 0}) do
  circleScale=value
  ctx.battlerPhase="prepare"
  local owned=api.battlers(fallback,ctx)
  assert(owned.sides.player=="provider" and owned.sides.enemy=="provider")
  local before=stageCalls
  assert(api.environment(fallback,ctx)==marks)
  assert(stageCalls==before+(value>0 and 1 or 0))
  ctx.battlerPhase="draw"
  local drawn=api.battlers(fallback,ctx).drawn
  assert(drawn.player and drawn.enemy)
  assert(fallbackCalls==0, 'stage redrawn on the flattened color canvas')
  assert(stage.radius==radius and stage.sink==.06 and pushes==0)
end
assert(actorCalls==12)
ctx.shadow={viewProjection=vp}
local shadowFallback=0
api.shadow(function() shadowFallback=shadowFallback+1 end,ctx)
assert(shadowCalls==2 and shadowFallback==1,
  'provider-owned models lost their Stadium shadow casters')
circleScale=2/3
failStage=true
assert(not pcall(api.environment,fallback,ctx))
assert(stage.radius==radius and stage.sink==.06 and pushes==0,
  'failed circle draw leaks graphics or shared stage state')
providerFails=true
assert(api.environment(fallback,ctx)==marks and fallbackCalls==1)
print('stadium circle depth regression: ok')

-- Standing trainer mode must not replace either live Stadium Pokemon model.
providerFails=false
failStage=false
overworld.legendaryTrainerEnabled=function() return true end
local render=overworld.providerRender
local playerModel=true
host.visualActor=function(_,side)
  if side=='player' and not playerModel then return nil end
  return actor
end
overworld.providerRender=function(battle, passes, ...)
  assert((passes.cards and passes.cards.player or false)==not playerModel,
    'Legendary sprite must only replace an unavailable Stadium player model')
  return render(battle, passes, ...)
end
for _, available in ipairs({true, false, true}) do
  playerModel=available
  ctx.battlerPhase='prepare'
  local owned=api.battlers(fallback,ctx)
  assert(owned.sides.player=='provider' and owned.sides.enemy=='provider')
  local before=actorCalls
  api.environment(fallback,ctx)
  assert(actorCalls==before+(available and 4 or 2),
    'Stadium model was replaced or Legendary sprite duplicated')
  ctx.battlerPhase='draw'
  local drawn=api.battlers(fallback,ctx).drawn
  assert(drawn.player and drawn.enemy)
  local beforeShadow=shadowCalls
  api.shadow(function() end,ctx)
  assert(shadowCalls==beforeShadow+(available and 2 or 1),
    'Stadium shadow casters do not match the visible model actors')
end
providerFails=true
api.environment(fallback,ctx)
assert(api.battlers(function() return 'released' end,ctx)=='released',
  'failed Legendary frame retained ownership')
print('Legendary/Stadium model precedence and sprite fallback: ok')
