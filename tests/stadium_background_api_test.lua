local checks = 0
local function ok(value, message)
  checks = checks + 1
  if not value then error("FAIL " .. message, 0) end
end

local mode = "OFF"
local circleScale = 0
local setting = {get=function() return mode end}
local map = {id="ROUTE_1"}
local image = {getDimensions=function() return 800, 600 end}
local registered={}
local receivedCamera
local receivedShadow
local graphics = {calls={}}
function graphics.clear(...) graphics.calls[#graphics.calls+1]={"clear",...} end
function graphics.setShader(...) end
function graphics.setDepthMode(...) end
function graphics.setBlendMode(...) end
function graphics.setColor(...) end
function graphics.setCanvas(...) graphics.calls[#graphics.calls+1]={"canvas",...} end
function graphics.draw(...) graphics.calls[#graphics.calls+1]={"draw",...} end

local modules = {
  Mat4=assert(loadfile("lib/Mat4.lua"))(),
  UiBackplates={
    arenaFill=setting, arenaArt=function() return mode=="GEN6" or mode=="PNG" end,
    bossEnabled=function() return false end,
    arenaPng=function() return mode=="PNG" end,
    arenaGen6=function() return mode=="GEN6" end,
    backdropOffsetPixels=function() return 0 end,
    stadiumCircleScale=function() return circleScale end,
  },
  Gen6Backdrop={image=function(got) return got==map and image or nil end},
  BossBackdrop={image=function() return nil end},
  BackdropImage={load=function() return image end},
  Voxel3D={
    BACKDROP_BLUR_RADIUS=1,
    coverRect=function() return 0,0,1 end,
    backdropShader=function() return nil end,
    backdropTransform=function(_,_,x,y,s) return x,y,s,s end,
    metalRenderer=function() return false end,
  },
  OverworldBattle={
    map=function() return map end,
    battle=function() return {oppClass="OPP_YOUNGSTER"} end,
    providerBegin=function() return true end,
    providerRender=function(_,passes,camera,shadow)
      receivedCamera=camera
      receivedShadow=shadow
      return {getDimensions=function() return 1024,768 end}
    end,
    providerFinish=function() end,
  },
}
local mod={
  find=function(id)
    if id~="STADIUM2_IMPORTER" then return nil end
    return {exports={scene={VERSION=1,register=function(owner,phase,fn,priority)
      registered[phase]={owner=owner,phase=phase,fn=fn,priority=priority}
      return true
    end}}}
  end,
  events={on=function() end},
}
local V={mod=mod}
function V.require(name) return assert(modules[name],name) end

local provider=assert(loadfile("lib/StadiumBackground.lua"))(V)
ok(provider.install(),"registers against Stadium scene API v1")
ok(registered.background and registered.environment
  and registered.background.priority==100 and registered.environment.priority==100,
  "owns the public background and environment phases")

local fallback=0
local function next() fallback=fallback+1; return "fallback" end
local host={Stage={radius=function() return 20 end}}
function host:visualActor(side) return self.actors[side] end
function host:modelMatrix() return {"model"} end
host.actors={
  player={renderer={
    model={},
    parts={{mesh="player-mesh",prim={}}},
    primitiveRenderState=function() return {castsShadow=true} end,
    drawShadowMap=function()
    shadowDrawn=true
    return true
  end}},
  enemy={renderer={
    model={},
    parts={{mesh="enemy-mesh",prim={additive=true}}},
    primitiveRenderState=function() return {castsShadow=true} end,
    drawShadowMap=function() return true end,
  }},
}
local ctx={
  graphics=graphics,
  target={color={},depth={},width=1024,height=768},
  camera={eye={1,2,3},focus={0,0,0},projection={1,0,0,0,0,-2}},
  scene={battle={},host=host,actors=host.actors},
  shadow={map="stadium-map",sunVP={1},sunDark=.5,sunBias=.01,
    sunTexel={1/1024,1/1024}},
  marks={player={x=320,y=500},enemy={x=700,y=260}},
}
ok(registered.background.fn(next,ctx)=="fallback" and fallback==1,
  "OFF leaves the sky phase for the voxel environment to cover")
ok(registered.environment.fn(next,ctx)==ctx.marks,
  "OFF replaces Stadium platforms with the captured voxel level")
ok(graphics.calls[#graphics.calls-1][1]=="canvas"
  and graphics.calls[#graphics.calls][1]=="draw",
  "voxel result is rebound and drawn into Stadium's scene target")
ok(receivedCamera==ctx.camera,
  "OFF renders voxel terrain through Stadium's live camera")
ok(receivedShadow==ctx.shadow,
  "completed Stadium model-shadow map reaches the voxel receiver")

mode="WHITE"
ok(registered.background.fn(next,ctx)==true and graphics.calls[#graphics.calls][1]=="clear",
  "WHITE replaces the Stadium sky")
ok(registered.environment.fn(next,ctx)==ctx.marks,
  "WHITE retains model anchors without Stadium ground circles")

mode="GEN6"
ok(registered.background.fn(next,ctx)==true and graphics.calls[#graphics.calls][1]=="draw",
  "GEN6 cover-draws Battle Art location artwork")

modules.Gen6Backdrop.image=function() return nil end
ok(registered.background.fn(next,ctx)=="fallback" and fallback==2,
  "missing optional art fails open to Stadium")

mode="BLUE"
circleScale=1
ok(registered.background.fn(next,ctx)=="fallback"
  and registered.environment.fn(next,ctx)=="fallback" and fallback==4,
  "BLUE delegates both sky and ground circles to the importer")

circleScale=2/3
local halfSeen=false
local function halfNext()
  halfSeen=math.abs(host.Stage.radius()-40/3)<1e-9
  return ctx.marks
end
ok(registered.environment.fn(halfNext,ctx)==ctx.marks and halfSeen
  and host.Stage.radius()==20,
  "HALF draws with two-thirds radius and restores Stadium's provider")

local hostedBattle={}
local stage=assert(loadfile("lib/BattleStage.lua"))().export({
  ANCHOR={player={26,96},enemy={124,56}},
  enabled=function() return true end,
  battle=function() return hostedBattle end,
  stageShot=function() return {player={31,101},enemy={119,51}} end,
  shot=function() return {player={-1,-1},enemy={-1,-1}} end,
  animScale=function() return 1 end,
  backPinned=function() return false end,
})
local hostedState=stage.state(hostedBattle)
ok(hostedState and hostedState.ready
  and hostedState.projectedAnchors.player[1]==31,
  "hosted voxel anchors are published without exposing the normal shot")

print(("%d checks passed (Stadium background provider)"):format(checks))

-- Cave camera correction survives the depth/ownership integration.
mode="OFF"
local frame={eye={0,10,20},focus={0,0,0},
  projection=modules.Mat4.perspective(math.rad(45),1,.1,1000)}
assert(provider.camera(function() return frame end,ctx)==frame)
map.tileset={id="CAVERN"}
local corrected=provider.camera(function() return frame end,ctx)
assert(corrected~=frame and corrected.eye[2]>=48)
assert(corrected.vp==corrected.viewProjection and frame.eye[2]==10)
assert(registered.camera and registered.shadow and registered.battlers.priority==1000)
mode="WHITE"
assert(provider.camera(function() return frame end,ctx)==frame)
print("Stadium cave camera integration: ok")
