local f=assert(io.open("lib/OverworldBattle.lua","rb"));local s=f:read("*a");f:close()
local battle={}
local scene={battle=battle,readyFrame=true,uiAnchors={player={15,102},enemy={145,39}}}
local battles={battle=function()return battle end,backPinned=function()return true end,
 animScale=function()error("native scale must not replace Stadium projection")end}
local env=setmetatable({OverworldBattle=battles,session={battle=battle},
 V={mod={find=function()return {exports={scene={current=function()return scene end}}}end}}},{__index=_G})
local a=assert(s:find("function OverworldBattle.stageShot()",1,true))
local b=assert(s:find("function OverworldBattle.providerFinish",a,true))
local fn=assert(loadstring(s:sub(a,b-1)));setfenv(fn,env);fn()
local stage=assert(loadfile("lib/BattleStage.lua"))().export(battles)
local state=stage.state(battle)
assert(state.ready and state.layerOwnsProjection)
assert(not state.backPinned and state.projectedAnchors.player[1]==15)
assert(state.projectedAnchors.enemy[1]==145)
local scale=state.animationScale
assert(math.abs(scale-math.sqrt(130*130+63*63)/math.sqrt(98*98+40*40))<1e-9)
-- Each slot is exposed without requiring any model renderer or skeletal bone.
scene.uiAnchors.enemy={91,62}
assert(stage.state(battle).projectedAnchors.enemy[1]==91)
scene.defect="failed"
assert(not stage.state(battle).ready)
print("Stadium sprite FX projection: passed")
