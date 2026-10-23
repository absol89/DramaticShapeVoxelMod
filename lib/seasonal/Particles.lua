-- GPU-animated holiday particles: Halloween embers and bats, Harvest leaves,
-- Easter petals and July fireworks. One static indexed mesh per effect; the
-- vertex shader moves every particle, so nothing crosses Lua->GPU per frame.
-- A CPU fallback (no shader support) rewrites one fixed vertex buffer at most
-- 30 times a second and never allocates while running.
local G,Effects=...
local M={};M.__index=M
local H=Effects.hash
M.kinds={
 embers={count=100,shape='ico'},
 bats={count=12,shape='bat'},
 petals={count=110,shape='card'},
 leaves={count=90,shape='card'},
 fireworks={count=294,shape='ico'},
}
-- Each uniform is declared only in the stage that reads it: GLSL ES needs a
-- uniform's precision to match in both stages, and the pixel stage defaults
-- to mediump on handhelds (a shared declaration fails to link there).
local header=[[
#ifdef VERTEX
uniform mat4 fxVP;
uniform vec3 fxCurve;
uniform vec2 fxPlayer;
uniform float fxTime;
#endif
#ifdef PIXEL
uniform vec2 fxClip;
#endif
varying float fxHeight;
varying vec4 fxTint;
]]
local helpers=[[
#ifdef VERTEX
attribute vec4 FxSeed;
attribute vec4 FxData;
float fxHash(float a,float b,float c){return fract(sin(a*12.9898+b*78.233+c*37.719)*43758.5453);}
vec3 fxSpin(vec3 p,float a){
 float co=cos(a),si=sin(a),ct=cos(a*.73),st=sin(a*.73);
 vec3 r=vec3(p.x*ct-p.y*st,p.x*st+p.y*ct,p.z);
 return vec3(r.x*co+r.z*si,r.y,-r.x*si+r.z*co);
}
vec3 fxWrap(vec2 c,float span){return vec3(fxPlayer.x+mod(c.x-fxPlayer.x+span,span*2.)-span,0.,fxPlayer.y+mod(c.y-fxPlayer.y+span,span*2.)-span);}
#endif
]]
local tail=[[
#ifdef VERTEX
vec4 position(mat4 ignored, vec4 p) {
 fxTint=vec4(0.);
 vec3 w=fxMove(p.xyz);
 fxHeight=w.y;
 vec2 d=w.xz-fxCurve.xy;
 w.y-=dot(d,d)*max(0.,fxCurve.z);
 return fxVP*vec4(w,1.);
}
#endif
#ifdef PIXEL
vec4 effect(vec4 color,Image tex,vec2 uv,vec2 screen) {
 if(fxClip.x>0.5 && fxHeight<fxClip.y) discard;
 vec4 t=Texel(tex,uv);
 return vec4(mix(t.rgb,fxTint.rgb,fxTint.a),t.a)*color;
}
#endif
]]
local motion={
 embers=[[
#ifdef VERTEX
vec3 fxMove(vec3 p){
 float i=FxData.x,r=FxData.y,t=fxTime;
 vec3 w=fxWrap(vec2(FxSeed.x+sin(t*.31+i)*6.,FxSeed.y+t*2.),75.);
 w.y=mod(FxSeed.z+t*FxSeed.w,40.);
 return w+fxSpin(vec3(p.x*r,p.y*r*.70,p.z*r*.88),t*.55+i);
}
#endif
]],
 petals=[[
#ifdef VERTEX
vec3 fxMove(vec3 p){
 float i=FxData.x,r=FxData.y,t=fxTime;
 vec3 w=fxWrap(vec2(FxSeed.x+t*4.,FxSeed.y+t*2.),90.);
 w.y=mod(FxSeed.z-t*FxSeed.w,65.);
 return w+fxSpin(vec3(p.x*r,p.y*r,p.z*r),t+i);
}
#endif
]],
 leaves=[[
#ifdef VERTEX
vec3 fxMove(vec3 p){
 float i=FxData.x,r=FxData.y,t=fxTime;
 vec3 w=fxWrap(vec2(FxSeed.x+t*3.+sin(t*.6+i)*5.,FxSeed.y+t*1.2+cos(t*.45+i)*3.),85.);
 w.y=.3+mod(FxSeed.z-t*FxSeed.w,60.);
 return w+fxSpin(vec3(p.x*r,p.y*r,p.z*r),t*1.4+i);
}
#endif
]],
 bats=[[
#ifdef VERTEX
vec3 fxMove(vec3 p){
 float i=FxData.x,s=FxData.y,wing=FxData.z,speed=FxData.w,t=fxTime;
 float a=t*speed+i*2.1;
 vec3 c=vec3(fxPlayer.x+FxSeed.x,FxSeed.w+sin(t*1.3+i)*2.2,fxPlayer.y+FxSeed.y);
 vec3 w=c+vec3(cos(a)*FxSeed.z,0.,sin(a)*FxSeed.z);
 float fx=-sin(a)*sign(speed),fz=cos(a)*sign(speed);
 vec3 q=vec3(p.x,p.y+wing*sin(t*13.+i*1.7)*1.25,p.z)*s;
 return w+vec3(q.x*fz+q.z*fx,q.y,-q.x*fx+q.z*fz);
}
#endif
]],
 fireworks=[[
#ifdef VERTEX
vec3 fxMove(vec3 p){
 float j=FxSeed.x,i=FxSeed.y,kind=FxSeed.z,t=fxTime;
 float age=mod(t+j*2.8,9.);float cycle=floor((t+j*2.8)/9.);
 vec3 c=vec3(fxPlayer.x+(fxHash(j,cycle+1.,41.)-.5)*160.,0.,fxPlayer.y+65.+fxHash(j,cycle+1.,52.)*80.);
 float peak=105.+fxHash(j,cycle+1.,18.)*45.;
 float k=mod(j+cycle,4.);
 vec3 col=k<.5?vec3(1.,.22,.18):k<1.5?vec3(1.,1.,1.):k<2.5?vec3(.30,.50,1.):vec3(1.,.80,.30);
 float size=0.;vec3 w=c;
 if(kind<.5){
  if(age<1.4){w.y=peak*pow(age/1.4,.75)-i*1.6;size=.45*(1.-i/9.);fxTint=vec4(1.,.75,.35,1.);}
 }else if(age>=1.4&&age<4.7){
  float tt=age-1.4,radius=tt*20.;float v=1.-2.*(i-.5)/90.;float hh=sqrt(max(0.,1.-v*v));float a=i*2.399963;
  w=c+vec3(hh*cos(a)*radius,peak+v*radius-3.4*tt*tt,hh*sin(a)*radius);
  size=max(.12,.55-tt*.11);fxTint=vec4(col,1.);
 }
 return w+fxSpin(p*size,t*.55);
}
#endif
]]}
function M.source(kind)return header..helpers..motion[kind]..tail end
local function shapeOf(kind)
 local s=M.kinds[kind].shape
 if s=='card'then return Effects.cardPoints,Effects.cardFaces
 elseif s=='bat'then return Effects.batPoints,Effects.batFaces end
 return Effects.points,Effects.faces
end
local function material(kind,i)
 if kind=='embers'then return i%3==0 and 'orange'or 'warm'
 elseif kind=='petals'then return i%2==0 and 'pink'or 'ivory'
 elseif kind=='leaves'then return i%3==0 and 'leafRed'or i%3==1 and 'leafGold'or 'leafOrange'
 elseif kind=='bats'then return 'black'end
 return 'white'
end
-- Per-particle constants: seed (4) and data (4).
local function particle(kind,i)
 if kind=='embers'then return {G.hash(i,29)*150,G.hash(i,21)*150,G.hash(i,71)*40,1+G.hash(i,2)},{i,.09+G.hash(i,72)*.11,0,0}
 elseif kind=='petals'then return {G.hash(i,35)*180,G.hash(i,59)*180,G.hash(i,91)*65,2+G.hash(i,31)*2},{i,.38,0,0}
 elseif kind=='leaves'then return {G.hash(i,45)*170,G.hash(i,63)*170,G.hash(i,97)*60,1.6+G.hash(i,37)*1.4},{i,.55+G.hash(i,12)*.25,0,0}
 elseif kind=='bats'then
  local speed=(.30+G.hash(i,14)*.35)*(i%2==0 and 1 or -1)
  -- TEST159: higher and further out, so a bat never sweeps across the lens
  return {(G.hash(i,81)-.5)*110,-42-G.hash(i,83)*60,16+G.hash(i,85)*26,40+G.hash(i,87)*28},{i,.85+G.hash(i,89)*.5,0,speed}
 end
 local j=math.floor((i-1)/98)+1;local k=(i-1)%98
 if k<8 then return {j,k,0,0},{i,0,0,0}end
 return {j,k-7,1,0},{i,0,0,0}
end
function M.new(kind,cpu)
 local spec=assert(M.kinds[kind],'unknown particle kind')
 local self=setmetatable({kind=kind,count=spec.count,vertices={},indices={},rows={},uploads=0},M)
 if not cpu then
  local ok,shader=pcall(love.graphics.newShader,M.source(kind))
  if ok then self.shader=shader else self.fallbackReason=tostring(shader)end
 end
 local points,faces=shapeOf(kind);self.points=points
 local format={{'VertexPosition','float',3},{'VertexTexCoord','float',2},{'VertexShade','float',1},{'FxSeed','float',4},{'FxData','float',4}}
 for i=1,self.count do
  local seed,data=particle(kind,i);local offset=#self.vertices
  local mat=material(kind,i)
  self.rows[i]={seed=seed,data=data,first=offset+1}
  for _,p in ipairs(points)do
   local u,v=G.uv(mat,.5+.4*(p[1]*.32+p[3]*.30),.5)
   local d={data[1],data[2],p[4]or 0,data[4]}
   self.vertices[#self.vertices+1]={p[1],p[2],p[3],u,v,1,seed[1],seed[2],seed[3],seed[4],d[1],d[2],d[3],d[4]}
  end
  for _,f in ipairs(faces)do for _,j in ipairs(f)do self.indices[#self.indices+1]=offset+j end end
 end
 local made,err=pcall(function()
  self.mesh=love.graphics.newMesh(format,self.vertices,'triangles',self.shader and 'static'or 'dynamic')
  self.mesh:setVertexMap(self.indices)
 end)
 if not made then self:dispose();error(err,0)end
 if self.shader then self.vertices=nil end -- GPU path never needs the Lua rows again
 return self
end
-- CPU mirror of the shaders, used only when no shader could be compiled.
local floor,sin,cos,sqrt=math.floor,math.sin,math.cos,math.sqrt
local function wrap(c,p,half)return p+((c-p+half)%(half*2))-half end
local function spin(x,y,z,a)
 local co,si,ct,st=cos(a),sin(a),cos(a*.73),sin(a*.73)
 local rx,ry=x*ct-y*st,x*st+y*ct
 return rx*co+z*si,ry,-rx*si+z*co
end
function M:cpuFrame(t,px,pz)
 local kind,verts,points=self.kind,self.vertices,self.points
 local fwColors={'red','white','blue','gold'}
 for i,row in ipairs(self.rows)do
  local s,d=row.seed,row.data;local cx,cy,cz=0,-1000,0;local size,angle,flatY,flatZ=0,0,1,1
  local yawF,yawS,wingT=nil,nil,0;local mat
  if kind=='embers'then
   cx=wrap(s[1]+sin(t*.31+d[1])*6,px,75);cz=wrap(s[2]+t*2,pz,75);cy=(s[3]+t*s[4])%40
   size=d[2];angle=t*.55+d[1];flatY,flatZ=.70,.88
  elseif kind=='petals'then
   cx=wrap(s[1]+t*4,px,90);cz=wrap(s[2]+t*2,pz,90);cy=(s[3]-t*s[4])%65;size=d[2];angle=t+d[1]
  elseif kind=='leaves'then
   cx=wrap(s[1]+t*3+sin(t*.6+d[1])*5,px,85);cz=wrap(s[2]+t*1.2+cos(t*.45+d[1])*3,pz,85);cy=.3+(s[3]-t*s[4])%60
   size=d[2];angle=t*1.4+d[1]
  elseif kind=='bats'then
   local a=t*d[4]+d[1]*2.1;local sg=d[4]<0 and -1 or 1
   cx=px+s[1]+cos(a)*s[3];cz=pz+s[2]+sin(a)*s[3];cy=s[4]+sin(t*1.3+d[1])*2.2
   size=d[2];yawF,yawS=cos(a)*sg,-sin(a)*sg;wingT=sin(t*13+d[1]*1.7)*1.25
  else
   local j,k,trail=s[1],s[2],s[3]<.5
   local age=(t+j*2.8)%9;local cycle=floor((t+j*2.8)/9)
   local bx=px+(H(j,cycle+1,41)-.5)*160;local bz=pz+65+H(j,cycle+1,52)*80;local peak=105+H(j,cycle+1,18)*45
   mat=fwColors[(j+cycle)%4+1];angle=t*.55
   if trail then
    if age<1.4 then cx,cz=bx,bz;cy=peak*(age/1.4)^.75-k*1.6;size=.45*(1-k/9);mat='warm'end
   elseif age>=1.4 and age<4.7 then
    local tt=age-1.4;local radius=tt*20;local v=1-2*(k-.5)/90;local hh=sqrt(math.max(0,1-v*v));local a=k*2.399963
    cx=bx+hh*cos(a)*radius;cy=peak+v*radius-3.4*tt*tt;cz=bz+hh*sin(a)*radius;size=math.max(.12,.55-tt*.11)
   end
  end
  local u,v
  if mat then u,v=G.uv(mat,.5,.5)end
  for n,p in ipairs(points)do
   local vert=verts[row.first+n-1];local x,y,z
   if yawF then
    local qx,qy,qz=p[1]*size,(p[2]+(p[4]or 0)*wingT)*size,p[3]*size
    x,y,z=cx+qx*yawF+qz*yawS,cy+qy,cz-qx*yawS+qz*yawF
   else
    local rx,ry,rz=spin(p[1]*size,p[2]*size*flatY,p[3]*size*flatZ,angle)
    x,y,z=cx+rx,cy+ry,cz+rz
   end
   vert[1],vert[2],vert[3]=x,y,z
   if u then vert[4],vert[5]=u,v end
  end
 end
end
function M:update(time,px,pz)
 self.time,self.px,self.pz=time,px,pz
 if self.shader or not self.mesh then return end
 local tick=floor(time*30);if self.tick==tick then return end;self.tick=tick
 self:cpuFrame(time,px,pz)
 self.mesh:setVertices(self.vertices);self.uploads=self.uploads+1
end
function M:draw(R,texture,alpha)
 if not(self.time and self.mesh)then return end
 R.withEffect('alpha',function()
  love.graphics.setColor(1,1,1,alpha or .85)
  if self.shader then
   if not R.vp then return end
   local s=self.shader
   s:send('fxVP','row',R.vp);s:send('fxCurve',{R.curveX or 0,R.curveZ or 0,R.curveK or 0})
   s:send('fxPlayer',{self.px,self.pz});s:send('fxTime',self.time)
   s:send('fxClip',{R.reflectionPlane and 1 or 0,R.reflectionPlane or 0})
   love.graphics.setShader(s);self.mesh:setTexture(texture);love.graphics.draw(self.mesh)
  else R.draw(self.mesh,texture)end
 end)
end
function M:fallback(reason)
 -- The shader failed at draw time: rebuild this effect on the CPU path.
 local kind=self.kind;self:dispose()
 local ok,fresh=pcall(M.new,kind,true)
 if ok then for k,v in pairs(fresh)do self[k]=v end end
 self.fallbackReason=tostring(reason);self.tick=nil
 return ok
end
function M:dispose()
 if self.mesh then self.mesh:release();self.mesh=nil end
 if self.shader then self.shader:release();self.shader=nil end
end
return M
