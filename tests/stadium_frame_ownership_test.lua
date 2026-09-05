local f=assert(io.open("lib/OverworldBattle.lua","rb"));local s=f:read("*a");f:close()
local battle,scene={},nil
local shot={canvas={}}
local env=setmetatable({V={mod={find=function()return {exports={scene={current=function()return scene end}}}end}},
 session={battle=battle,shot=shot},OverworldBattle={}},{__index=_G})
local a=assert(s:find("local function stadiumOwnsFrame",1,true))
local b=assert(s:find("-- ------- per-frame",a,true))
local c=assert(s:find("function OverworldBattle.shot()",1,true))
local d=assert(s:find("function OverworldBattle.invalidate",c,true))
local chunk=assert(loadstring(s:sub(a,b-1)..s:sub(c,d-1)))
setfenv(chunk,env);chunk()
assert(env.OverworldBattle.shot()==shot)
scene={battle=battle,readyFrame=true}
assert(env.OverworldBattle.shot()==nil, "ready Stadium scene must not get a second normal compositor")
scene.defect="failed"
assert(env.OverworldBattle.shot()==shot, "broken Stadium scene retains fallback")
scene.defect=nil;scene.battle={}
assert(env.OverworldBattle.shot()==shot)
print("Stadium frame ownership: passed")
