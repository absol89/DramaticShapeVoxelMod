-- TEST206/207: CERULEAN WATER. The cave's lake and channels are the Game
-- Boy's water tile laid flat as GROUND, level with the floor (voxel_heights
-- pins cave water $14 to `ground`: it is terrain, never the water pass),
-- which is why they read as a dark carpet of little light squares. In
-- Cerulean Cave the water is covered by its own surface:
--
--   * THE BODY: a deep, dark sheet just above the engine's water, with slow
--     broad drifts of deeper and shallower colour (opaque: what was under it
--     no longer shows through);
--   * THE LIGHT FROM BELOW: two webs of crystal light, one in each of the
--     floor's two crystal colours, sliding across each other in different
--     directions and at different scales, so the pattern never repeats in an
--     obvious way;
--   * GLINTS: points of light winking on the ripples.
--
-- The light layers lie on the water cells only; their pattern slides by
-- moving the texture coordinates (a small per-frame update), so nothing
-- spills onto the floor beside the water.
-- Presentation only: Surf, encounters and the water cells are untouched.
local V=...
local Assets=require("src.render.Assets")
local Mat4=V.require("Mat4")
local Voxel3D=V.require("Voxel3D")

local M={REVISION='cerulean-water-206'}
local floor,min,max,abs,sin,cos,sqrt=math.floor,math.min,math.max,math.abs,math.sin,math.cos,math.sqrt
local cache=setmetatable({},{__mode='k'})
local bodyTex,webTex,glintTex

local WATER_Y=0          -- TEST207: cave water is ground, at the floor plane
M.BODY_Y=WATER_Y+.10     -- over the engine's tile art, under anything standing in it
M.PERIOD={body=144,webA=48,webB=34,glint=40}

local function hash(ix,iy,s)
 local n=(ix*73856093+iy*19349663+s*83492791)%104729
 if n<0 then n=n+104729 end
 return n/104729
end
-- tileable value noise: lattice of `per` cells wrapping
local function tnoise(x,y,per,s)
 local ix,iy=floor(x),floor(y)
 local fx,fy=x-ix,y-iy
 fx,fy=fx*fx*(3-2*fx),fy*fy*(3-2*fy)
 local x0,x1,y0,y1=ix%per,(ix+1)%per,iy%per,(iy+1)%per
 local a,b=hash(x0,y0,s),hash(x1,y0,s)
 local c,d=hash(x0,y1,s),hash(x1,y1,s)
 return(a+(b-a)*fx)*(1-fy)+(c+(d-c)*fx)*fy
end
local function newTex(N,fn)
 local ok,img=pcall(function()
  local d=love.image.newImageData(N,N)
  for y=0,N-1 do for x=0,N-1 do d:setPixel(x,y,fn(x,y))end end
  local im=love.graphics.newImage(d,{mipmaps=true})
  im:setFilter("linear","linear");pcall(im.setMipmapFilter,im,"linear")
  im:setWrap("repeat","repeat")
  d:release();return im
 end)
 return ok and img or false
end
-- the body: broad soft drifts, from deep (.50) to shallow (1.0)
local function body()
 if bodyTex==nil then bodyTex=newTex(64,function(x,y)
  local n=.60*tnoise(x/16,y/16,4,4101)+.28*tnoise(x/8,y/8,8,4103)+.12*tnoise(x/4,y/4,16,4105)
  local v=.50+.50*n
  return v,v,v,1
 end)end
 return bodyTex or nil
end
-- a web of light: the bright ridges where a noise field crosses its middle,
-- bent by a second field (the shape caustics take on a lit bed)
local function web()
 if webTex==nil then webTex=newTex(128,function(x,y)
  local u,v=x/128,y/128
  local warp=tnoise(u*4,v*4,4,4111)
  local n=tnoise(u*6+warp*1.6,v*6+warp*1.2,6,4113)
  local m=tnoise(u*10-warp,v*10+warp*.8,10,4115)
  local a=(1-abs(2*n-1))^6*.85+(1-abs(2*m-1))^9*.45
  return 1,1,1,min(1,a)
 end)end
 return webTex or nil
end
-- glints: a scatter of small soft points
local function glint()
 if glintTex==nil then
  local pts={}
  -- a sine hash here: the lattice hash steps linearly with i, which lined
  -- the points up in rows
  local function rh(a,b)local v=sin(a*12.9898+b*78.233)*43758.5453;return v-floor(v)end
  for i=1,26 do pts[i]={rh(i,1.7)*64,rh(i,5.3)*64,.9+rh(i,9.1)*1.6}end
  glintTex=newTex(64,function(x,y)
   local a=0
   for _,p in ipairs(pts)do
    local dx,dy=abs(x-p[1]),abs(y-p[2])
    dx,dy=min(dx,64-dx),min(dy,64-dy)
    local d=sqrt(dx*dx+dy*dy)/p[3]
    if d<1 then a=max(a,(1-d)^2)end
   end
   return 1,1,1,a
  end)
 end
 return glintTex or nil
end

local function group()return{verts={},indices={},quads=0}end
local function mesh(g)if g.quads==0 then return nil end;return Voxel3D.newMesh(g.verts,g.indices)end
-- a flat quad over one cell, its texture mapped from world position
local function cellQuad(g,cx,cy,y,per)
 local x0,z0,x1,z1=cx*16,cy*16,cx*16+16,cy*16+16
 for _,p in ipairs({{x0,z0},{x1,z0},{x1,z1},{x0,z1}})do
  g.verts[#g.verts+1]={p[1],y,p[2],p[1]/per,p[2]/per,1}
  if g.base then g.base[#g.base+1]={p[1]/per,p[2]/per}end
 end
 Voxel3D.pushQuad(g.indices,g.quads);g.quads=g.quads+1
end
-- a layer whose texture slides: keeps its vertex table and base uvs so
-- the coordinates can be moved each frame without making new tables
local function sliding()local g=group();g.base={};return g end

local function build(map)
 local wc,hc=map.widthCells or 0,map.heightCells or 0
 local function water(cx,cy)
  if not(map.isWaterCell and cx>=0 and cy>=0 and cx<wc and cy<hc)then return false end
  local ok,r=pcall(map.isWaterCell,map,cx,cy);return ok and r or false
 end
 local wet={}
 local any=false
 for cy=0,hc-1 do for cx=0,wc-1 do if water(cx,cy)then wet[cy*4096+cx]=true;any=true end end end
 if not any then return false end
 local P=M.PERIOD
 local bodyG,aG,bG,gG=group(),sliding(),sliding(),sliding()
 for cy=0,hc-1 do for cx=0,wc-1 do
  if wet[cy*4096+cx]then
   cellQuad(bodyG,cx,cy,M.BODY_Y,P.body)
   cellQuad(aG,cx,cy,M.BODY_Y+.06,P.webA)
   cellQuad(bG,cx,cy,M.BODY_Y+.09,P.webB)
   cellQuad(gG,cx,cy,M.BODY_Y+.12,P.glint)
  end
 end end
 local function layer(g)local m=mesh(g);return m and{mesh=m,verts=g.verts,base=g.base}or nil end
 return{body=mesh(bodyG),webA=layer(aG),webB=layer(bG),glint=layer(gG)}
end

local function release(s)
 if not s then return end
 for _,m in ipairs({s.body,s.webA and s.webA.mesh,s.webB and s.webB.mesh,s.glint and s.glint.mesh})do
  if m and m.release then pcall(m.release,m)end
 end
end
local function applies(map)
 local ok,r=pcall(function()return V.require("CeruleanDepths").applies(map)end)
 return ok and r or false
end
local function detail()
 local ok,d=pcall(function()return V.require("CommunityVisuals").caveDetailLevel()end)
 return ok and d or"full"
end
function M.slotFor(map)
 if not(map and applies(map))or detail()=="off" then return nil end
 local s=cache[map]
 if s==nil then
  local ok,r=pcall(build,map)
  if not ok then
   if V.mod and V.mod.log and V.mod.log.info then pcall(V.mod.log.info,V.mod.log,'Cerulean water failed: %s',tostring(r))end
   r=false
  end
  s=r or false;cache[map]=s
 end
 return s or nil
end

-- the body: opaque, unlit, depth-writing, before the engine's water pass
-- (which then stays hidden beneath it). spec: {deep, shallow, glowA, glowB}
function M.draw(map,spec)
 local s=M.slotFor(map)
 if not(s and s.body and spec)then return false end
 local tex=body()
 if not tex then return false end
 local g=love.graphics
 local pushed=g.push and pcall(g.push,"all")
 local ok=pcall(function()
  g.setDepthMode("lequal",true)
  g.setBlendMode("alpha")
  Voxel3D.lighting(false)
  local c=spec.shallow
  g.setColor(c[1],c[2],c[3],1)
  Voxel3D.draw(s.body,tex)
 end)
 pcall(Voxel3D.lighting,true)
 if pushed then pcall(g.pop)end
 pcall(g.setColor,1,1,1,1)
 return ok
end
-- slide a layer's texture: (du,dv) in texture repeats, wrapped to 0..1
local function slide(L,t,vx,vz,per)
 if not(L.mesh.setVertices)then return end
 local du,dv=((t*vx)/per)%1,((t*vz)/per)%1
 local v,b=L.verts,L.base
 for i=1,#v do local q=v[i];q[4]=b[i][1]-du;q[5]=b[i][2]-dv end
 pcall(L.mesh.setVertices,L.mesh,v)
end
-- the light: after the water pass (CeruleanDepths.drawLate)
function M.drawLight(map,spec,battle)
 local s=M.slotFor(map)
 if not(s and spec)then return false end
 local wt,gt=web(),glint()
 local g=love.graphics
 local t=0;pcall(function()t=love.timer.getTime()end)
 local P=M.PERIOD
 local k=battle and .75 or 1
 pcall(Voxel3D.withEffect,"add",function()
  local a,b=spec.glowA,spec.glowB
  if wt and s.webA then
   slide(s.webA,t,2.2,1.3,P.webA)
   g.setColor(a[1],a[2],a[3],(.19+.04*sin(t*.5))*k)
   Voxel3D.draw(s.webA.mesh,wt)
  end
  if wt and s.webB then
   slide(s.webB,t,-1.5,2.4,P.webB)
   g.setColor(b[1],b[2],b[3],(.13+.04*sin(t*.37+1.3))*k)
   Voxel3D.draw(s.webB.mesh,wt)
  end
  if gt and s.glint then
   slide(s.glint,t,.6,-.9,P.glint)
   local tw=.5+.5*sin(t*2.3)
   g.setColor(.80+.20*a[1],.80+.20*a[2],.85+.15*a[3],(.18+.30*tw)*k)
   Voxel3D.draw(s.glint.mesh,gt)
  end
 end)
 pcall(g.setColor,1,1,1,1)
 return true
end

function M.invalidate()
 for _,s in pairs(cache)do release(s)end
 cache=setmetatable({},{__mode='k'})
 for _,m in ipairs({bodyTex or nil,webTex or nil,glintTex or nil})do if m and m.release then pcall(m.release,m)end end
 bodyTex,webTex,glintTex=nil,nil,nil
end
Assets.register(M.invalidate)
return M
