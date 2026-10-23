-- TEST11: mobile-compatible depth-integrated low mist. No ribbons or shells.
-- One bounded 12-sample pass follows the actual opaque scene depth.
local V=...
local Assets=require('src.render.Assets')
local R=V.require('Voxel3D')
local Structures=V.require('Structures')
local Settings=V.require('TowerFogSettings')
local inverse=V.require('WaterBackdrop').inverse
local M={status='idle'}
local cache=setmetatable({},{__mode='k'})
local shader,noiseImage,attempted,shaderError
local lastTime,phase= nil,0
local reported={}

local function failure(status,err)
 M.status=status;M.error=tostring(err or status)
 -- Keep unexpected driver/runtime failures inspectable, once per error.
 -- The outer world/battle guards deliberately keep the game running.
 if not reported[M.error] then
  reported[M.error]=true
  local log=V.mod and V.mod.log
  if log and log.error then pcall(log.error,log,'Tower fog: %s',M.error)end
 end
 return false
end

M.SOURCE=[[
#ifdef GL_ES
precision highp float;
#endif
uniform LOVE_HIGHP_OR_MEDIUMP Image sceneDepth;
uniform Image graveMask;
uniform Image mistNoise;
uniform mat4 inverseVP;
uniform vec2 mapSize;
uniform vec3 worldCurve;
uniform float mistTime;
uniform float mistStrength;
uniform float mistHeight;

// No user identifier here is named texture. Undo LOVE's GLSL1 compatibility
// rename so the GLSL3 depth lookup below can call the native intrinsic.
#undef texture

vec3 unproject(vec2 uv,float d){
 vec4 p=inverseVP*vec4(uv*2.0-1.0,d*2.0-1.0,1.0);
 return p.xyz/p.w;
}
float insideFog(vec3 p){
 vec2 bend=p.xz-worldCurve.xy;
 float y=p.y+dot(bend,bend)*worldCurve.z;
 vec2 uv=p.xz/mapSize;
 if(uv.x<=0.0||uv.y<=0.0||uv.x>=1.0||uv.y>=1.0||y<-.5||y>mistHeight)return 0.0;
 float mask=Texel(graveMask,uv).r;
 // Moving banks have clear pockets; avoid a constant grey floor wash.
 vec2 flow=vec2(mistTime*.0085,-mistTime*.0055);
 float broad=Texel(mistNoise,p.xz/116.0+flow).r;
 float detail=Texel(mistNoise,p.xz/43.0-flow*.8+vec2(y*.020)).r;
 float billow=smoothstep(.30,.76,broad);
 float height=1.0-smoothstep(1.5+billow*2.0,mistHeight*(.58+.42*billow),y);
 float density=smoothstep(.30,.77,broad*.65+detail*.35);
 return mask*height*(.035+1.30*density);

}
// LOVE's default GLES effect prototype is mediump. The highp default above is
// needed for depth reconstruction, but must not change that entry signature.
// TEST8 compiled on desktop and failed GLES validation on all three vectors.
mediump vec4 effect(mediump vec4 color, Image tex, mediump vec2 tc, mediump vec2 sc){
 // Keep pixel math highp too: mediump entry coordinates cause visible bands.
 vec2 uv=love_PixelCoord/love_ScreenSize.xy;
 // LOVE's GLSL1 Texel wrapper also returns mediump on GLES. Sample depth
 // through the underlying intrinsic to retain its 24-bit precision; rounding
 // it to mediump turns a smooth floor into wide horizontal fog bands.
#if __VERSION__ >= 130
 float depth=texture(sceneDepth,uv).r;
#else
 float depth=texture2D(sceneDepth,uv).r;
#endif
 if(depth>=.999999)discard;
 vec3 start=unproject(uv,0.0);
 vec3 end=unproject(uv,depth);
 vec3 delta=end-start;
 float distance=length(delta);
 if(distance<.001)discard;
 vec3 ray=delta/distance;
 // Clip to a conservative Tower box before sampling; curves are undone in
 // density, so mist hugs curved floors too. Safe parallel-ray slab bounds.
 vec3 safeRay=vec3(abs(ray.x)<.00001?.00001:ray.x,
                   abs(ray.y)<.00001?.00001:ray.y,
                   abs(ray.z)<.00001?.00001:ray.z);
 float maxDrop=dot(mapSize+abs(worldCurve.xy),mapSize+abs(worldCurve.xy))*worldCurve.z;
 vec3 a=(vec3(0.0,-maxDrop-.5,0.0)-start)/safeRay;
 vec3 b=(vec3(mapSize.x,mistHeight,mapSize.y)-start)/safeRay;
 vec3 lo=min(a,b),hi=max(a,b);
 float enter=max(0.0,max(lo.x,max(lo.y,lo.z)));
 float leave=min(distance,min(hi.x,min(hi.y,hi.z)));
 if(leave<=enter)discard;
 // Long low sightlines have a fixed cost and a restrained opacity cap.
 enter=max(enter,leave-180.0);
 float stepLength=(leave-enter)/12.0;
 float optical=0.0;
 for(int i=0;i<12;i++){
  vec3 p=start+ray*(enter+(float(i)+.5)*stepLength);
  optical+=insideFog(p)*stepLength;
 }
 float alpha=min(.72,1.0-exp(-optical*.048*mistStrength));
 return vec4(.68,.64,.77,alpha);
}
]]

local function release(x)if x and x.release then pcall(x.release,x)end end
local function key(x,z)return(z+64)*4096+x+64 end
local function isTower(map)
 return map and map.tileset and map.tileset.id=='CEMETERY'
  and tostring(map.id or ''):match('^POKEMON_TOWER_[1-7]F$')~=nil
end
local function noise()
 if noiseImage then return noiseImage end
 local size=128;local data=love.image.newImageData(size,size)
 for z=0,size-1 do for x=0,size-1 do
  local u,v=x/size*math.pi*2,z/size*math.pi*2
  local n=.5+.16*math.sin(u+math.sin(v*2))+.13*math.cos(v*3+math.cos(u*2))
   +.09*math.sin(u*4-v*3)+.055*math.cos(u*7+v*5)
  data:setPixel(x,z,n,n,n,1)
 end end
 local ok,result=pcall(love.graphics.newImage,data);release(data)
 if not ok then error(result)end
 noiseImage=result;noiseImage:setFilter('linear','linear');noiseImage:setWrap('repeat','repeat')
 return noiseImage
end
local function field(map,S)
 local wc=map.widthCells or map.def.width*2
 local hc=map.heightCells or map.def.height*2
 local graves={}
 -- TEST174: a Tower floor InteriorRooms builds has claimed its tiles; it
 -- says where its graves are
 local okI,own=pcall(function()return V.require('InteriorRooms').graves(map)end)
 if okI and own then graves=own else
 for z=0,hc*2-1 do for x=0,wc*2-1 do
  local s=S.shapeAt[key(x,z)]
  if s and s.art=='post' then graves[#graves+1]={x*8+4,z*8+4}end
 end end
 end
 -- TEST11: lobby and all seven floors retain a light ambient mist.
 -- Local splats into a small mask: O(graves * 64), not floor x grave scans.
 local w,h=wc*2,hc*2;local values={}
 for _,p in ipairs(graves)do
  local cx,cz=math.floor(p[1]/8),math.floor(p[2]/8)
  for z=math.max(0,cz-4),math.min(h-1,cz+4)do
   for x=math.max(0,cx-4),math.min(w-1,cx+4)do
    local d=math.sqrt((x*8+4-p[1])^2+(z*8+4-p[2])^2)
    local t=math.max(0,math.min(1,(34-d)/25));t=t*t*(3-2*t)
    local k=z*w+x;values[k]=math.max(values[k]or 0,t)
   end
  end
 end
 local data=love.image.newImageData(w,h)
 for z=0,h-1 do for x=0,w-1 do local d=.62+.38*(values[z*w+x]or 0);data:setPixel(x,z,d,d,d,1)end end
 local ok,img=pcall(love.graphics.newImage,data);release(data)
 if not ok then error(img)end
 img:setFilter('linear','linear');img:setWrap('clamp','clamp')
 return {S=S,image=img,size={wc*16,hc*16},graves=#graves}
end
local function draw(map)
 if not isTower(map)or not Settings.active()then M.status='off';return false end
 if not R.drawDepthOverlay then return failure('depth unavailable','No native depth overlay')end
 if not attempted then
  attempted=true;local ok,s=pcall(love.graphics.newShader,M.SOURCE)
  if ok then shader=s else shaderError=tostring(s)end
 end
 -- Fail cleanly on unsupported hardware instead of falling back to opaque sheets.
 if not shader then return failure('shader unavailable',shaderError)end
 local inv=R.vp and inverse(R.vp)
 if not inv then return failure('camera unavailable','No invertible Tower camera')end
 local S=Structures.forMap(map);local slot=cache[map]
 if not slot or slot.S~=S then
  if slot then release(slot.image)end
  slot=field(map,S);cache[map]=slot
 end
 local now=love.timer.getTime()
 if lastTime then phase=phase+math.max(0,math.min(now-lastTime,.25))*Settings.speedMultiplier()end
 lastTime=now
 local alpha,height=Settings.thicknessMultipliers()
 local img=noise()
 local ok,err=R.drawDepthOverlay(shader,function(s)
  s:send('inverseVP','row',inv);s:send('graveMask',slot.image)
  s:send('mistNoise',img);s:send('mapSize',slot.size)
  s:send('worldCurve',{R.curveX or 0,R.curveZ or 0,R.curveK or 0})
  s:send('mistTime',phase);s:send('mistStrength',alpha);s:send('mistHeight',18*height)
 end)
 if not ok then return failure('depth unavailable',err or 'Scene has no readable depth attachment')end
 M.status='ready';M.error=nil
 return true
end
local function guardedDraw(map)
 local ok,result=pcall(draw,map)
 if not ok then return failure('render error',result)end
 return result
end
function M.draw(state)return guardedDraw(state and state.map)end
function M.drawBattle(map)return guardedDraw(map)end
function M.invalidate()
 for _,s in pairs(cache)do release(s.image)end
 cache=setmetatable({},{__mode='k'})
 release(shader);release(noiseImage);shader,noiseImage,attempted,shaderError=nil,nil,false,nil
 lastTime,phase=nil,0;M.status='idle';M.error=nil
 reported={}
end
Assets.register(M.invalidate)
return M
