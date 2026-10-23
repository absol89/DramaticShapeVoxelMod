-- TEST226: THE PARADE'S CONFETTI, ON THE GRAPHICS CARD.
--
-- Solo Dolo's note on TEST225: the confetti should be more dynamic -- it
-- came out of the people beside the road in jets, as if each of them were
-- a cannon. Now nothing comes out of anybody:
--
--   * ticker tape and paper drift down from the buildings either side of
--     the street, thickest round the float, the way it does in a city
--     parade, and keep falling ahead of you as you go
--   * the float's own two cannons (the gold poles at its prow) fire up and
--     out on the camera's big moments, and two cannons in the plaza fire at
--     the finale; a curtain of it falls over the plaza at the very end
--   * every piece tumbles as it falls: a square of paper, a long thin strip
--     of ticker tape, a curling streamer or a piece of gold or silver foil
--     that flashes as it turns to the light; the air slows a throw, then it
--     flutters down side to side, drifting a little with the breeze
--   * and it LANDS: what falls stays on the street, flat, so the road the
--     parade has passed is carpeted with it
--
-- How: every piece is four corners in a ring of M.CAP pieces, kept in
-- meshes of M.SEG pieces each (a phone's driver may copy a whole buffer
-- that is written while it is drawn; a small one is cheap to copy).
-- A piece is written once, when it is thrown: where from, how fast, when,
-- its colour, its size, and when it will land (worked out here, from the
-- same fall the shader draws). From then on the GRAPHICS CARD moves it --
-- the flight, the tumble, the flutter, the landing -- so the CPU's cost is a
-- few dozen numbers per piece thrown, and nothing per frame for the
-- thousands already in the air or on the ground. Drawn in the parade's late
-- world pass, depth-tested against the town. If this phone's driver will
-- not build the shader (or the mesh), the TEST225 way stands in: up to a
-- few hundred pieces moved here and drawn as cards, no carpet.
--
-- TEST228: a piece passing right by the camera shrinks away as it reaches
-- the lens (NEAR_FADE), instead of crossing the screen as a sheet of paper
-- the size of a door -- the float's close-ups went through the falling
-- tape.
local V=...
local M={REVISION='parade-confetti-228'}
local floor,max,min,abs,sin,cos,sqrt,exp,pi=math.floor,math.max,math.min,math.abs,math.sin,math.cos,math.sqrt,math.exp,math.pi

M.CAP=4096             -- pieces in the ring (in the air and on the ground)
M.SEG=512              -- pieces a mesh
M.CPU_CAP=420          -- the fallback's pieces
M.TAU=.42              -- seconds: how quickly the air takes a throw's speed
M.SUN={.45,.76,.47}    -- toward the sun (the south-east, as the town's light)
M.KIND={paper=0,ribbon=1,foil=2,tape=3}
M.WIND={-2.2,.8}       -- the breeze, world pixels a second
M.NEAR_FADE=7.0        -- TEST228: pieces nearer the eye than this shrink away

-- the colours
M.CONFETTI={{1,.24,.26},{1,.80,.20},{.26,.54,1},{.34,.84,.36},{1,.46,.80},{1,1,1},{1,.56,.16},{.66,.42,1}}
M.TICKER={{1,1,1},{.98,.97,.92},{1,.97,.80},{.88,.94,1},{1,1,1},{.96,.96,.96},{1,.80,.20},{1,.30,.30},{.36,.60,1}}
M.FOIL={{1,.82,.34},{.86,.88,.92},{1,.70,.30}}
M.PETALS={{1,.76,.86},{1,1,1},{1,.62,.78},{1,.86,.92},{.98,.70,.82},{1,.94,.96}}

local function now()local ok,t=pcall(love.timer.getTime);return ok and t or 0 end
local function fract(x)return x-floor(x)end
local function rnd()
 local ok,r=pcall(love.math.random);if ok and r then return r end
 return math.random()
end
local function log(fmt,...)
 local args={...}
 pcall(function()require('src.core.Logger').warn('[ParadeConfetti] '..fmt,unpack(args))end)
end

------------------------------------------------------------------ the fall
-- Height after `a` seconds: thrown up at vy, slowed by the air (TAU), falling
-- at its own steady speed vt once the throw is spent. The shader draws the
-- same curve.
function M.heightAt(y0,vy,vt,a)
 local T=M.TAU
 return y0+(vy+vt)*T*(1-exp(-a/T))-vt*a
end
-- how long until it reaches `ground` (0 if it starts below it)
function M.landAge(y0,vy,vt,ground)
 if y0<=ground then return 0 end
 local T=M.TAU
 -- once the throw is spent the fall is a straight line: start from there
 local a=max(.05,(y0-ground+(vy+vt)*T)/vt)
 for _=1,6 do
  local f=M.heightAt(y0,vy,vt,a)-ground
  local d=(vy+vt)*exp(-a/T)-vt
  if abs(d)<1e-6 then break end
  local na=a-f/d
  if na<=0 then na=a*.5 end
  if abs(na-a)<1e-4 then a=na;break end
  a=na
 end
 return max(0,min(40,a))
end
-- its steady fall: a strip of ribbon floats, foil and paper drop faster
function M.fallSpeed(kind,seed)
 if kind==1 then return 5.2+2.6*fract(seed*7.13)end
 if kind==2 then return 8.0+4.0*fract(seed*7.13)end
 if kind==3 then return 7.0+3.5*fract(seed*7.13)end
 return 8.5+5.0*fract(seed*7.13)
end
-- where it is (no tumble) at age a: the fallback's flight, and the tests'
function M.positionAt(p,a)
 local T=M.TAU
 local la=min(a,p.land)
 local e=1-exp(-la/T)
 local x=p.x+p.vx*T*e
 local z=p.z+p.vz*T*e
 local y=p.y+(p.vy+p.vt)*T*e-p.vt*la
 local k=1-exp(-la/.7)
 local ph=p.seed*6.2831853
 local fq=1.7+1.5*fract(p.seed*3.71)
 local amp=p.kind==1 and 1.3 or 2.4
 x=x+k*amp*sin(la*fq+ph)+M.WIND[1]*la
 z=z+k*amp*cos(la*fq*.83+ph*1.7)+M.WIND[2]*la
 if a>=p.land then y=p.ground+.45 end
 return x,y,z
end

------------------------------------------------------------------ the shader
M.SHADER=[[
varying vec3 vCol;
#ifdef VERTEX
uniform mat4 vp;
uniform vec3 curve;
uniform float time;
uniform vec2 wind;
uniform vec3 sunDir;
uniform vec3 light;
uniform vec3 eye;
uniform float nearFade;
attribute vec4 ConfA;   // the throw: velocity xyz, the moment it was thrown
attribute vec4 ConfB;   // its landing age, the ground there, kind + seed, its fall speed
attribute vec4 ConfC;   // its colour, its half size (0: an empty slot)
vec4 position(mat4 transform_projection, vec4 vertex_position) {
  float age = time - ConfA.w;
  if (ConfC.a <= 0.0 || age < 0.0) return vec4(2.0, 2.0, 2.0, 1.0);
  float kind = floor(ConfB.z);
  float seed = ConfB.z - kind;
  float land = ConfB.x;
  float a = min(age, land);
  float tau = 0.42;
  float e = 1.0 - exp(-a / tau);
  float vt = ConfB.w;
  vec3 p = vertex_position.xyz + ConfA.xyz * (tau * e);
  p.y -= vt * (a - tau * e);
  float k = 1.0 - exp(-a / 0.7);
  float ph = seed * 6.2831853;
  float fq = 1.7 + 1.5 * fract(seed * 3.71);
  float amp = (kind == 1.0) ? 1.3 : 2.4;
  p.x += k * amp * sin(a * fq + ph) + wind.x * a;
  p.z += k * amp * cos(a * fq * 0.83 + ph * 1.7) + wind.y * a;
  float sx = ConfC.a;
  float sy = sx;
  if (kind == 1.0) { sx *= 0.30; sy *= 3.4; }
  else if (kind == 3.0) { sx *= 0.42; sy *= 1.9; }
  vec2 cr = VertexTexCoord.xy;
  vec3 r;
  float shine;
  if (age >= land) {
    float g = ph * 1.37;
    float cg = cos(g);
    float sg = sin(g);
    r = vec3(cr.x * sx * cg - cr.y * sy * sg, 0.0, cr.x * sx * sg + cr.y * sy * cg);
    p.y = ConfB.y + 0.45 + 0.08 * fract(seed * 13.7);
    shine = (kind == 2.0) ? 1.05 : 0.80;
  } else {
    float th1 = a * (3.5 + 5.0 * fract(seed * 5.13)) + ph;
    float th2 = a * (2.5 + 4.0 * fract(seed * 9.71)) + ph * 2.3;
    float c1 = cos(th1);
    float s1 = sin(th1);
    float c2 = cos(th2);
    float s2 = sin(th2);
    vec3 q = vec3(cr.x * sx, cr.y * sy * c2, cr.y * sy * s2);
    r = vec3(q.x * c1 + q.z * s1, q.y, -q.x * s1 + q.z * c1);
    vec3 n = vec3(c2 * s1, -s2, c2 * c1);
    float f = abs(dot(n, sunDir));
    shine = 0.42 + 0.62 * f;
    if (kind == 2.0) shine += 1.4 * pow(f, 10.0);
  }
  vCol = ConfC.rgb * light * shine;
  if (nearFade > 0.0) {
    float near = smoothstep(nearFade * 0.45, nearFade, distance(p, eye));
    if (near <= 0.0) return vec4(2.0, 2.0, 2.0, 1.0);
    r *= near;
  }
  vec4 w = vec4(p + r, 1.0);
  if (curve.z > 0.0) {
    vec2 cd = w.xz - curve.xy;
    w.y -= dot(cd, cd) * curve.z;
  }
  return vp * w;
}
#endif
#ifdef PIXEL
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
  return vec4(vCol, 1.0);
}
#endif
]]
M.FORMAT={
 {'VertexPosition','float',3},
 {'VertexTexCoord','float',2},
 {'ConfA','float',4},
 {'ConfB','float',4},
 {'ConfC','float',4},
}
local CORNERS={{-1,-1},{1,-1},{1,1},{-1,1}}

local shaderObj=nil    -- nil untried, false refused
function M.shader()
 if shaderObj==nil then
  shaderObj=false
  local ok,sh=pcall(love.graphics.newShader,M.SHADER)
  if ok and sh then shaderObj=sh
  else log('the confetti shader would not build (%s): drawing it the old way',tostring(sh))end
 end
 return shaderObj or nil
end

------------------------------------------------------------------ a system
local Sys={};Sys.__index=Sys
M.Sys=Sys
-- opts: ground(x,z) -> the ground's height there; cap; cpu (force the fallback)
function M.new(opts)
 opts=opts or{}
 local cap=opts.cap or M.CAP
 cap=math.max(M.SEG,math.ceil(cap/M.SEG)*M.SEG)
 local self=setmetatable({cap=cap,head=0,pending={},np=0,t0=now(),
  groundFn=opts.ground,gcache={},thrown=0,cpu=nil,segs=nil,accum={}},Sys)
 if not opts.cpu then
  local ok,err=pcall(function()
   local sh=M.shader()
   if not sh then error('no shader')end
   local idx={}
   for q=0,M.SEG-1 do
    local b=q*4
    idx[#idx+1]=b+1;idx[#idx+1]=b+2;idx[#idx+1]=b+3
    idx[#idx+1]=b+1;idx[#idx+1]=b+3;idx[#idx+1]=b+4
   end
   local segs={}
   self.segs=segs -- Own partial allocations so fallback can release them.
   for k=1,cap/M.SEG do
    local mesh=love.graphics.newMesh(M.FORMAT,M.SEG*4,'triangles','dynamic')
    segs[k]={mesh=mesh,used=false}
    mesh:setVertexMap(idx)
    -- (a fresh mesh is zeroes: every slot empty, size 0)
   end
   self.segs=segs
  end)
  if not ok then
   log('confetti on the graphics card is off here (%s)',tostring(err))
   for _,sg in ipairs(self.segs or{})do pcall(sg.mesh.release,sg.mesh)end
   self.segs=nil
  end
 end
 if not self.segs then self.cpu={pieces={}} end
 return self
end
function Sys:clock()return now()-self.t0 end
function Sys:gpu()return self.segs~=nil end

-- the ground under a landing place (by cell; the parade's maps are flat
-- where it throws, so a cell's answer stands for the cell)
function Sys:groundAt(x,z)
 if not self.groundFn then return 0 end
 local k=floor(x/16)*4096+floor(z/16)
 local g=self.gcache[k]
 if g==nil then
  local ok,h=pcall(self.groundFn,x,z)
  g=ok and tonumber(h)or 0
  self.gcache[k]=g
 end
 return g
end

-- one piece. kind: 0 paper, 1 ribbon, 2 foil, 3 ticker tape. `delay` puts
-- off its throw (a burst's pieces leave the barrel over a beat).
function Sys:add(x,y,z,vx,vy,vz,kind,col,size,delay)
 kind=kind or 0
 local seed=rnd()*.998
 local vt=M.fallSpeed(kind,seed)
 local T=M.TAU
 -- where it comes down, near enough for the ground's height: the throw's
 -- reach and the breeze over the fall (the flutter is a few pixels)
 local guess=M.landAge(y,vy,vt,0)
 local gx=x+vx*T+M.WIND[1]*guess
 local gz=z+vz*T+M.WIND[2]*guess
 local ground=self:groundAt(gx,gz)
 local land=M.landAge(y,vy,vt,ground)
 local born=self:clock()+(delay or 0)
 self.thrown=self.thrown+1
 if self.cpu then
  local L=self.cpu.pieces
  if #L>=M.CPU_CAP then table.remove(L,1)end
  L[#L+1]={x=x,y=y,z=z,vx=vx,vy=vy,vz=vz,vt=vt,land=land,ground=ground,born=born,
   kind=kind,seed=seed,col=col,size=size}
  return
 end
 local n=self.np+1
 self.np=n
 local p=self.pending[n]
 if not p then p={};self.pending[n]=p end
 p[1],p[2],p[3],p[4],p[5],p[6],p[7]=x,y,z,vx,vy,vz,born
 p[8],p[9],p[10],p[11]=land,ground,kind+seed,vt
 p[12],p[13],p[14],p[15]=col[1],col[2],col[3],size
end

-- write what was thrown this frame into the ring: a run for each mesh the
-- new pieces fall in (two or more where the ring wraps or crosses a mesh)
local scratch={}
function Sys:flush()
 local n=self.np
 if n<=0 or not self.segs then self.np=0;return end
 if n>self.cap then n=self.cap end
 local SEG=M.SEG
 local i=1
 while i<=n do
  local slot=(self.head+i-1)%self.cap
  local seg=floor(slot/SEG)
  local first=slot%SEG
  local count=min(n-i+1,SEG-first)
  local verts=scratch
  local nv=0
  for j=i,i+count-1 do
   local p=self.pending[j]
   for c=1,4 do
    nv=nv+1
    local v=verts[nv]
    if not v then v={};verts[nv]=v end
    v[1],v[2],v[3]=p[1],p[2],p[3]
    v[4],v[5]=CORNERS[c][1],CORNERS[c][2]
    v[6],v[7],v[8],v[9]=p[4],p[5],p[6],p[7]
    v[10],v[11],v[12],v[13]=p[8],p[9],p[10],p[11]
    v[14],v[15],v[16],v[17]=p[12],p[13],p[14],p[15]
   end
  end
  for k=nv+1,#verts do verts[k]=nil end
  local sg=self.segs[seg+1]
  pcall(sg.mesh.setVertices,sg.mesh,verts,first*4+1)
  sg.used=true
  i=i+count
 end
 self.head=(self.head+n)%self.cap
 self.np=0
end

local function pick(list,r)return list[floor((r or rnd())*#list)%#list+1]end
M.pick=pick

-- a cannon: n pieces out of (x,y,z) along dir (any length), spread wide or
-- narrow, a mix of paper, ribbon and foil
function Sys:burst(x,y,z,dir,n,speed,spread,palette,opts)
 opts=opts or{}
 local dx,dy,dz=dir[1],dir[2],dir[3]
 local l=sqrt(dx*dx+dy*dy+dz*dz);if l<1e-6 then dx,dy,dz,l=0,1,0,1 end
 dx,dy,dz=dx/l,dy/l,dz/l
 spread=spread or .55
 palette=palette or M.CONFETTI
 for i=1,n do
  local s=speed*(.55+.75*rnd())
  local jx,jy,jz=(rnd()-.5)*2*spread,(rnd()-.5)*1.4*spread,(rnd()-.5)*2*spread
  local r=rnd()
  local kind=r<(opts.foil or .14)and 2 or(r<(opts.foil or .14)+(opts.ribbon or .12)and 1 or 0)
  local col=kind==2 and pick(M.FOIL)or pick(palette)
  local size=kind==1 and(.85+.35*rnd())or(.62+.34*rnd())
  self:add(x+(rnd()-.5)*1.2,y+(rnd()-.5)*1.2,z+(rnd()-.5)*1.2,
   (dx+jx)*s,(dy+jy)*s,(dz+jz)*s,kind,col,size,(opts.delay or 0)+rnd()*(opts.over or .14))
 end
end

-- a curtain: n pieces released over an area between heights y0..y1, falling
-- (the finale's drop, and the background drift over a whole street)
function Sys:drop(x0,x1,z0,z1,y0,y1,n,palette,opts)
 opts=opts or{}
 for i=1,n do
  local r=rnd()
  local kind=r<(opts.foil or .10)and 2 or(r<(opts.foil or .10)+(opts.ribbon or .10)and 1 or(r<.45 and 3 or 0))
  local col=kind==2 and pick(M.FOIL)or pick(palette or M.CONFETTI)
  self:add(x0+(x1-x0)*rnd(),y0+(y1-y0)*rnd(),z0+(z1-z0)*rnd(),
   (rnd()-.5)*4,(rnd()-.5)*2,(rnd()-.5)*4,kind,col,kind==1 and(.85+.3*rnd())or(.6+.3*rnd()),
   (opts.delay or 0)+rnd()*(opts.over or 1.5))
 end
end

-- ticker tape thrown from the buildings: `lines` are the street's frontages
-- {x0,x1,z,y0,y1,out} (out: which way the street is from the wall, +1 south
-- / -1 north; or {z0,z1,x,...,axis='z'} for a frontage that runs north to
-- south). `rate` pieces a second, from the parts of the frontages inside
-- `win` {x0,x1,z0,z1} (the stretch round the float); `id` keeps each
-- stream's fraction of a piece between frames.
function Sys:ticker(dt,lines,win,rate,palette,id)
 if rate<=0 or dt<=0 then return end
 local total=0
 local spans={}
 for i,L in ipairs(lines)do
  local a,b
  if L.axis=='z'then
   if L.x>=win.x0 and L.x<=win.x1 then a,b=max(L.z0,win.z0),min(L.z1,win.z1)end
  else
   if L.z>=win.z0 and L.z<=win.z1 then a,b=max(L.x0,win.x0),min(L.x1,win.x1)end
  end
  if a and b>a then spans[#spans+1]={L,a,b};total=total+(b-a)end
 end
 if total<=0 then return end
 local key=id or'ticker'
 local want=(self.accum[key]or 0)+rate*dt
 local n=floor(want)
 self.accum[key]=want-n
 palette=palette or M.TICKER
 for i=1,n do
  -- a frontage in proportion to its length in the window
  local pickAt=rnd()*total
  local s=spans[#spans]
  for _,sp in ipairs(spans)do
   local len=sp[3]-sp[2]
   if pickAt<=len then s=sp;break end
   pickAt=pickAt-len
  end
  local L,a,b=s[1],s[2],s[3]
  local u=a+(b-a)*rnd()
  local y=L.y0+(L.y1-L.y0)*rnd()
  local out=L.out or 1
  local push=7+16*rnd()
  local r=rnd()
  local kind=r<.42 and 3 or(r<.52 and 1 or(r<.58 and 2 or 0))
  local col=kind==2 and pick(M.FOIL)or pick(palette)
  local size=kind==1 and(.8+.3*rnd())or(.55+.3*rnd())
  if L.axis=='z'then
   self:add(L.x+out*(.6+rnd()),y,u,out*push,rnd()*5-1,(rnd()-.5)*5,kind,col,size,rnd()*dt)
  else
   self:add(u,y,L.z+out*(.6+rnd()),(rnd()-.5)*5,rnd()*5-1,out*push,kind,col,size,rnd()*dt)
  end
 end
end

------------------------------------------------------------------ drawing
-- In the late world pass (the scene shader bound, its depth attached).
-- light: {r,g,b} the hour's light on paper. Everything put back after.
function Sys:draw(R,K,light)
 if self.segs then
  self:flush()
  local sh=M.shader()
  if not(sh and R and R.vp)then return end
  local g=love.graphics
  g.push('all')
  local ok,err=pcall(function()
   g.setShader(sh)
   sh:send('vp','row',R.vp)
   pcall(sh.send,sh,'curve',{R.curveX or 0,R.curveZ or 0,R.curveK or 0})
   sh:send('time',self:clock())
   pcall(sh.send,sh,'wind',M.WIND)
   pcall(sh.send,sh,'sunDir',M.SUN)
   pcall(sh.send,sh,'light',light or{1,1,1})
   -- (TEST228: the lens; nearFade 0 turns it off)
   local eye=R.eye
   if type(eye)=='table'and tonumber(eye[1])and tonumber(eye[2])and tonumber(eye[3])then
    pcall(sh.send,sh,'eye',{eye[1],eye[2],eye[3]})
    pcall(sh.send,sh,'nearFade',M.NEAR_FADE)
   else
    pcall(sh.send,sh,'nearFade',0)
   end
   g.setBlendMode('alpha','alphamultiply')
   g.setDepthMode('lequal',true)
   if g.setMeshCullMode then g.setMeshCullMode('none')end
   g.setColor(1,1,1,1)
   for _,sg in ipairs(self.segs)do if sg.used then g.draw(sg.mesh)end end
  end)
  g.pop()
  if not ok then
   log('the confetti would not draw (%s): the old way from now on',tostring(err))
   for _,sg in ipairs(self.segs)do pcall(sg.mesh.release,sg.mesh)end
   self.segs=nil
   self.cpu={pieces={}}
  end
  return
 end
 self:drawCpu(R,K,light)
end

-- the fallback: the newest few hundred pieces in the air, as cards in six
-- colour runs (TEST225's way); nothing stays on the ground
local streams=nil
function Sys:drawCpu(R,K,light)
 local L=self.cpu and self.cpu.pieces
 if not(L and #L>0 and K and K.streamPut and K.newStream and K.white)then return end
 if streams==nil then
  streams={}
  for c=1,6 do streams[c]=K.newStream(80)or false end
 end
 local Mat4=V.require('Mat4')
 local g=love.graphics
 local t=self:clock()
 local used={0,0,0,0,0,0}
 local keep={}
 for _,p in ipairs(L)do
  local a=t-p.born
  if a<0 then keep[#keep+1]=p
  elseif a<p.land then
   keep[#keep+1]=p
   -- its colour run (each run one fixed colour: a stream is drawn in one)
   local c=floor(p.seed*6)%6+1
   local sm=streams[c]
   if sm and used[c]<sm.n then
    local x,y,z=M.positionAt(p,a)
    local flip=.35+.65*abs(sin(a*7+p.seed*20))
    -- (TEST228: one passing the lens shrinks away, as on the card)
    local near=1
    local eye=R.eye
    if type(eye)=='table'and tonumber(eye[1])and tonumber(eye[2])and tonumber(eye[3])then
     local dx,dy,dz=x-eye[1],y-eye[2],z-eye[3]
     local f=M.NEAR_FADE
     local u=(sqrt(dx*dx+dy*dy+dz*dz)-f*.45)/(f*.55)
     near=u<=0 and 0 or u>=1 and 1 or u*u*(3-2*u)
    end
    if near>0 then
     K.streamPut(sm,used[c],x,y,z,p.size*flip*near,false)
     used[c]=used[c]+1
    end
   end
  end
 end
 self.cpu.pieces=keep
 local lr,lg,lb=(light and light[1]or 1),(light and light[2]or 1),(light and light[3]or 1)
 pcall(R.withEffect,'alpha',function()
  for c=1,6 do
   local sm=streams[c]
   if sm and used[c]>0 then
    for i=used[c],sm.n-1 do K.streamPut(sm,i,0,-9999,0,0,false)end
    pcall(sm.mesh.setVertices,sm.mesh,sm.verts)
    local col=M.CONFETTI[c]
    g.setColor(col[1]*lr,col[2]*lg,col[3]*lb,1)
    R.draw(sm.mesh,K.white,Mat4.translate(0,0,0))
   end
  end
 end)
 g.setColor(1,1,1,1)
end

function Sys:release()
 for _,sg in ipairs(self.segs or{})do pcall(sg.mesh.release,sg.mesh)end
 self.segs=nil
 self.cpu=nil
 self.pending={};self.np=0
end

function M.dispose()
 if streams then for _,sm in ipairs(streams)do if sm and sm.mesh then pcall(sm.mesh.release,sm.mesh)end end end
 streams=nil
 if shaderObj then pcall(shaderObj.release,shaderObj)end
 shaderObj=nil
end
return M
