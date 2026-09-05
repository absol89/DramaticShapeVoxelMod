-- The Stadium-hosted intro hides only a successfully replaced player trainer.
local f=assert(io.open("lib/OverworldBattle.lua","rb"))
local source=f:read("*a"); f:close()
local a=assert(source:find("  function BattleState:drawPicsLayer(",1,true))
local b=assert(source:find("  local innerText",a,true))
-- End at the next wrapper's introduction rather than loading unrelated hooks.
local ending=assert(source:find("\n  end",a,true))
local chunk=assert(loadstring(source:sub(a,ending+6)))
local state, shot, calls={},nil,{}
local env=setmetatable({BattleState=state,
  OverworldBattle={stageShot=function() return shot end},
  innerPics=function(_,_,_,_,side) calls[#calls+1]=side or "both" end,
},{__index=_G})
setfenv(chunk,env); chunk()
local battle=setmetatable({showPlayerBack=true,playerBackPic={}},{__index=state})
for _,drawn in ipairs({false,true,false}) do
  shot={trainerDrawn=drawn}
  calls={}
  battle:drawPicsLayer(0,0,0)
  assert(calls[1]==(drawn and "enemy" or "both"))
  calls={}
  battle:drawPicsLayer(0,0,0,"player")
  assert(#calls==(drawn and 0 or 1))
end
shot={trainerDrawn=true}
battle.showPlayerBack=false
calls={}; battle:drawPicsLayer(0,0,0)
assert(calls[1]=="both", "Pokemon must remain visible after the intro")
print("hosted trainer visibility: passed")
