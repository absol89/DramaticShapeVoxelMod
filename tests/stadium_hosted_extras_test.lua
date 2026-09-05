local function extract(path, first, last, env)
 local f=assert(io.open(path,'rb')); local s=f:read('*a'); f:close()
 local a=assert(s:find(first,1,true)); local b=assert(s:find(last,a+1,true))
 local fn=assert(loadstring(s:sub(a,b-1))); setfenv(fn,setmetatable(env,{__index=_G}));fn()
end
local Mat4=assert(loadfile('lib/Mat4.lua'))()
local voxel={eye={1},focus={2},camera={3},vp={4}}
local saved={voxel.eye,voxel.focus,voxel.camera,voxel.vp}
local calls, ticks, fail={},0,false
voxel.beginScene=function(w,h,x,z,vw,vh,sky,slot,shadow,borrowed)
 assert(w==640 and h==480 and borrowed.color=='host')
 assert(borrowed.vp[4]==-10 and borrowed.vp[8]==-5 and borrowed.vp[12]==-20)
 assert(voxel.eye[1]==11 and voxel.eye[2]==7 and voxel.eye[3]==23)
 calls[#calls+1]='begin'; return true
end
voxel.endScene=function()calls[#calls+1]='end' end
local scene={groundY=function()return 5 end,drawTrainerAndBall=function()
 calls[#calls+1]='draw'; if fail then error('companion failure') end; return true
end}
extract('lib/BattleScene.lua','function BattleScene.renderHostedExtras','-- Render the arena and hand back',{
 BattleScene=scene,Voxel3D=voxel,Mat4=Mat4,normalBallTick=function()ticks=ticks+1 end})
local ctx={target={width=640,height=480,color='host'},camera={vp=Mat4.identity(),eye={1,2,3},focus={0,0,0}},
 graphics={push=function()calls[#calls+1]='push' end,origin=function()end,pop=function()calls[#calls+1]='pop' end}}
for _,bad in ipairs({false,true}) do
 fail=bad; calls={}
 local ok,result=pcall(scene.renderHostedExtras,{map={}},{mid={10,20}}, {},ctx)
 assert(ok==not bad); if ok then assert(result) end
 assert(table.concat(calls,',')=='push,begin,draw,end,pop')
 assert(voxel.eye==saved[1] and voxel.focus==saved[2] and voxel.camera==saved[3] and voxel.vp==saved[4])
end
assert(ticks==2,'ball clock must advance in flat scenes')
local shader={send=function()end}
local g={setDepthMode=function()end,setMeshCullMode=function()end,setShader=function()end,setColor=function()end,
 clear=function()error('host must not clear')end,setCanvas=function()error('host must not rebind')end}
local api={shader=function()return shader end,eye={},camera={curve=0},viewProjection=function()error('use host VP')end}
extract('lib/Voxel3D.lua','function Voxel3D.beginScene','-- Depth handling for the character pass',{
 Voxel3D=api,VoxelGrid={enabled=function()return false end},love={graphics=g},
 ShadowMap={active=function()error('stale world shadow')end,texture=function()return nil end,res=1},
 GlassMask={blank=function()return nil end},IDENTITY=Mat4.identity()})
assert(api.beginScene(640,480,0,0,160,144,nil,nil,nil,{color='host',vp=Mat4.identity()}))
print('Hosted trainer/ball camera, borrowed depth target, clock and error cleanup: passed')
