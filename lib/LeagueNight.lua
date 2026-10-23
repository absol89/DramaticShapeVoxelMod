-- TEST168: THE LEAGUE AFTER DARK. Static overlay meshes built once per map
-- from LeagueArchitecture.nightPlan() and drawn additively after dusk:
--
--  * WASHES  warm wall-washer cones thrown up (and down) the stone from
--            every lantern sconce, up the facade bays and pilasters, up the
--            gatehouse and hall fronts, and over the doorways;
--  * POOLS   warm light pooled on the paving under lamps, sconces and doors,
--            and along the gorge rim;
--  * AQUA    turquoise pools round the fountains and the waterfalls' basins;
--  * HALOS   the glow round every lantern.
--
-- Four meshes, four draws, nothing at all by day. Built in world space; the
-- caller passes the map's offset matrix (neighbour maps draw it too).
local V=...
local M={REVISION='league-night-168'}
local Voxel3D=V.require("Voxel3D")
local pi,cos,sin,floor,min,max,abs,sqrt,exp=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs,math.sqrt,math.exp
local washTex,poolTex,haloTex

local function newTex(w,h,fn)
 local ok,img=pcall(function()
  local d=love.image.newImageData(w,h)
  for y=0,h-1 do for x=0,w-1 do d:setPixel(x,y,1,1,1,max(0,min(1,fn(x,y))))end end
  local made=love.graphics.newImage(d,{mipmaps=false})
  made:setFilter("linear","linear");made:setWrap("clamp","clamp")
  d:release();return made
 end)
 return ok and img or nil
end
-- a wall-washer's scallop: bright at the lamp, widening and fading upward
local function washFn(x,y)
 local u=(x+.5)/32-.5;local v=(y+.5)/64          -- v=0 at the lamp
 local sig=.10+.36*v
 local cone=exp(-(u/sig)^2*1.7)*(1-v)^1.35*min(1,v*14)
 local core=exp(-(u/.07)^2*2)*exp(-v*9)*.7
 return min(1,cone+core)
end
local function poolFn(x,y)
 local u,v=(x+.5)/32-1,(y+.5)/32-1;local r=sqrt(u*u+v*v)
 if r>=1 then return 0 end
 return (1-r)^1.7
end
local function haloFn(x,y)
 local u,v=(x+.5)/32-1,(y+.5)/32-1;local r=sqrt(u*u+v*v)
 if r>=1 then return 0 end
 return min(1,(1-r)^2.6+.6*(1-r)^9)
end
local function textures()
 washTex=washTex or newTex(32,64,washFn)
 poolTex=poolTex or newTex(64,64,poolFn)
 haloTex=haloTex or newTex(64,64,haloFn)
 return washTex,poolTex,haloTex
end
M._washFn,M._poolFn,M._haloFn=washFn,poolFn,haloFn

------------------------------------------------------------------ geometry
-- Pure: returns vertex/index tables per layer (headless-testable).
function M.geometry(P)
 local layers={wash={v={},i={}},soft={v={},i={}},pool={v={},i={}},aqua={v={},i={}},halo={v={},i={}}}
 local function quad(L,a,b,c,d,uv)
  local n=#L.v
  L.v[n+1]={a[1],a[2],a[3],uv[1][1],uv[1][2],1}
  L.v[n+2]={b[1],b[2],b[3],uv[2][1],uv[2][2],1}
  L.v[n+3]={c[1],c[2],c[3],uv[3][1],uv[3][2],1}
  L.v[n+4]={d[1],d[2],d[3],uv[4][1],uv[4][2],1}
  local k=#L.i
  L.i[k+1],L.i[k+2],L.i[k+3],L.i[k+4],L.i[k+5],L.i[k+6]=n+1,n+2,n+3,n+1,n+3,n+4
 end
 -- texture rows: image row 0 is the lamp end (v=0)
 for _,w in ipairs(P.washes or{})do
  local p=w.p
  if p then
   -- two strengths: lamp washes, and the softer panel/banner uplights
   local L=((w.k or 1)>=.8)and layers.wash or layers.soft
   if w.dir and w.dir<0 then
    quad(L,p[1],p[2],p[3],p[4],{{0,1},{1,1},{1,0},{0,0}})
   else
    quad(L,p[1],p[2],p[3],p[4],{{0,0},{1,0},{1,1},{0,1}})
   end
  end
 end
 local function flat(L,x,y,z,r)
  quad(L,{x-r,y,z-r},{x+r,y,z-r},{x+r,y,z+r},{x-r,y,z+r},{{0,0},{1,0},{1,1},{0,1}})
 end
 for _,pl in ipairs(P.pools or{})do flat(layers.pool,pl.x,pl.y,pl.z,pl.r)end
 for _,pl in ipairs(P.aqua or{})do flat(layers.aqua,pl.x,pl.y,pl.z,pl.r)end
 for _,h in ipairs(P.halos or{})do
  local x,y,z,r=h.x,h.y,h.z,h.r
  quad(layers.halo,{x-r,y-r,z},{x+r,y-r,z},{x+r,y+r,z},{x-r,y+r,z},{{0,0},{1,0},{1,1},{0,1}})
  quad(layers.halo,{x,y-r,z-r},{x,y-r,z+r},{x,y+r,z+r},{x,y+r,z-r},{{0,0},{1,0},{1,1},{0,1}})
  quad(layers.halo,{x-r*.8,y,z-r*.8},{x+r*.8,y,z-r*.8},{x+r*.8,y,z+r*.8},{x-r*.8,y,z+r*.8},{{0,0},{1,0},{1,1},{0,1}})
 end
 return layers
end

function M.build(P)
 if not P then return nil end
 local layers=M.geometry(P)
 local out={}
 for name,L in pairs(layers)do
  if #L.v>0 then
   local ok,m=pcall(Voxel3D.newMesh,L.v,L.i)
   if ok and m then out[name]=m end
  end
 end
 return out
end

function M.release(slot)
 if not slot then return end
 for _,m in pairs(slot)do if type(m)=='userdata'or(type(m)=='table'and m.release)then pcall(m.release,m)end end
end

-- night: 0..1 (DayNight.windowLight); t: seconds; model: the map offset
function M.draw(slot,night,t,model)
 if not slot or night<.03 then return end
 local wT,pT,hT=textures()
 if not(wT and pT and hT)then return end
 local g=love.graphics
 local breathe=.94+.06*sin(t*.9)
 pcall(Voxel3D.withEffect,"add",function()
  if slot.wash then g.setColor(1,.78,.50,.62*night*breathe);Voxel3D.draw(slot.wash,wT,model)end
  if slot.soft then g.setColor(1,.80,.56,.40*night);Voxel3D.draw(slot.soft,wT,model)end
  if slot.pool then g.setColor(1,.74,.44,.50*night);Voxel3D.draw(slot.pool,pT,model)end
  if slot.aqua then g.setColor(.30,.92,1,.38*night);Voxel3D.draw(slot.aqua,pT,model)end
  if slot.halo then g.setColor(1,.80,.48,.60*night*breathe);Voxel3D.draw(slot.halo,hT,model)end
 end)
 pcall(g.setColor,1,1,1,1)
end

function M.invalidate()
 for _,tx in ipairs({washTex,poolTex,haloTex})do if tx and tx.release then pcall(tx.release,tx)end end
 washTex,poolTex,haloTex=nil,nil,nil
end
return M
