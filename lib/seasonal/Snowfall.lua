-- One indexed allocation. Animation is evaluated by the vertex shader; the
-- identical rounded 80-triangle flakes no longer cross Lua/GPU every frame.
local G,Effects=...
local M={};M.__index=M
M.shaderSource=[[
#ifdef VERTEX
uniform mat4 snowVP;
uniform vec3 snowCurve;
uniform vec2 snowPlayer;
uniform float snowTime;
#endif
#ifdef PIXEL
uniform vec2 snowClip;
#endif
varying float snowHeight;
#ifdef VERTEX
attribute vec4 SnowSeed;
attribute float SnowPhase;
vec4 position(mat4 ignored, vec4 p) {
 float a=snowTime*.55+SnowPhase;
 float co=cos(a),si=sin(a),ct=cos(a*.73),st=sin(a*.73);
 vec3 r=vec3(p.x*ct-p.y*st,p.x*st+p.y*ct,p.z);
 vec3 w=vec3(r.x*co+r.z*si,r.y,-r.x*si+r.z*co);
 float x=SnowSeed.x+snowTime*2.2+sin(snowTime*.7+SnowPhase)*1.8;
 float z=SnowSeed.y+snowTime*.8;
 w+=vec3(snowPlayer.x+mod(x-snowPlayer.x+130.,260.)-130.,
  mod(SnowSeed.z-snowTime*SnowSeed.w,130.),
  snowPlayer.y+mod(z-snowPlayer.y+130.,260.)-130.);
 snowHeight=w.y;
 vec2 d=w.xz-snowCurve.xy;
 w.y-=dot(d,d)*max(0.,snowCurve.z);
 return snowVP*vec4(w,1.);
}
#endif
#ifdef PIXEL
vec4 effect(vec4 color,Image tex,vec2 uv,vec2 screen) {
 if(snowClip.x>0.5 && snowHeight<snowClip.y) discard;
 return Texel(tex,uv)*color;
}
#endif
]]
function M.new(mode)
 local self=setmetatable({count=mode=='full'and 420 or 180,vertices={},indices={},seeds={},uploads=0},M)
 local ok,shader=pcall(love.graphics.newShader,M.shaderSource)
 if ok then self.shader=shader else self.fallbackReason=tostring(shader)end
 local format={{'VertexPosition','float',3},{'VertexTexCoord','float',2},{'VertexShade','float',1},{'SnowSeed','float',4},{'SnowPhase','float',1}}
 for i=1,self.count do
  local seed={G.hash(i,71)*260,G.hash(i,23)*260,G.hash(i,17)*130,7+G.hash(i,51)*6,.10+G.hash(i,33)*.24}
  self.seeds[i]=seed;local offset=#self.vertices
  for _,p in ipairs(Effects.points)do
   local u,v=G.uv('snowflake',.5+.47*(p[1]*.32+p[2]*.80+p[3]*.30),.5)
   self.vertices[#self.vertices+1]={p[1]*seed[5],p[2]*seed[5]*.7,p[3]*seed[5]*.88,u,v,1,seed[1],seed[2],seed[3],seed[4],i}
  end
  for _,f in ipairs(Effects.faces)do for _,j in ipairs(f)do self.indices[#self.indices+1]=offset+j end end
 end
 local made,err=pcall(function()
  self.mesh=love.graphics.newMesh(format,self.vertices,'triangles',self.shader and 'static'or 'dynamic')
  self.mesh:setVertexMap(self.indices)
 end)
 if not made then self:dispose();error(err,0)end
 self.mode=mode
 return self
end
function M:update(time,px,pz)
 self.time,self.px,self.pz=time,px,pz
 if self.shader then return end
 -- Compatibility fallback reuses 42 vertex rows per flake, at most 30 uploads
 -- per second (TEST3 allocated/uploaded 240 rows per flake at 60 Hz).
 local tick=math.floor(time*30);if self.tick==tick then return end;self.tick=tick
 local n=0
 for i,seed in ipairs(self.seeds)do
  local a=time*.55+i;local co,si,ct,st=math.cos(a),math.sin(a),math.cos(a*.73),math.sin(a*.73)
  local x=px+((seed[1]+time*2.2+math.sin(time*.7+i)*1.8-px+130)%260)-130
  local z=pz+((seed[2]+time*.8-pz+130)%260)-130
  local y=(seed[3]-time*seed[4])%130
  for _,p in ipairs(Effects.points)do
   n=n+1;local v=self.vertices[n];local xx,yy,zz=p[1]*seed[5],p[2]*seed[5]*.7,p[3]*seed[5]*.88
   local rx,ry=xx*ct-yy*st,xx*st+yy*ct
   v[1],v[2],v[3]=x+rx*co+zz*si,y+ry,z-rx*si+zz*co
  end
 end
 self.mesh:setVertices(self.vertices);self.uploads=self.uploads+1
end
function M:draw(R,texture)
 if not self.time then return end
 R.withEffect('alpha',function()
  love.graphics.setColor(1,1,1,.80)
  if self.shader then
   if not R.vp then return end
   local s=self.shader
   s:send('snowVP','row',R.vp);s:send('snowCurve',{R.curveX or 0,R.curveZ or 0,R.curveK or 0})
   s:send('snowPlayer',{self.px,self.pz});s:send('snowTime',self.time)
   s:send('snowClip',{R.reflectionPlane and 1 or 0,R.reflectionPlane or 0})
   love.graphics.setShader(s);self.mesh:setTexture(texture);love.graphics.draw(self.mesh)
  else R.draw(self.mesh,texture)end
 end)
end
function M:dispose()
 if self.mesh then self.mesh:release();self.mesh=nil end
 if self.shader then self.shader:release();self.shader=nil end
end
function M:fallback(reason)
 if self.shader then self.shader:release();self.shader=nil end
 self.tick=nil;self.fallbackReason=tostring(reason)
end
return M
