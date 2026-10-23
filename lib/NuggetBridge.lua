-- TEST191: NUGGET BRIDGE, MADE GRAND. Route 24's bridge -- five trainers in
-- a row and a Nugget for whoever beats them all -- was a plain plank deck
-- with iron railings. Now:
--   * a GATEWAY at each end: sandstone pylons on the railing lines, a
--     curved arch, NUGGET BRIDGE in gold letters on a navy band (both
--     faces), and a great golden nugget on the crown that glints;
--   * a red CARPET with gold edges and gold lozenges down the deck;
--   * every other railing post carries a tall LAMP STANDARD with a lantern,
--     and red-and-gold BANNERS hang from every fourth;
--   * BUNTING (red, gold, cream, navy pennants) swags from lamp to lamp
--     along both railings;
--   * where the deck meets open water, a sandstone FASCIA with a stone
--     coping and buttresses down into the water.
-- After dark the lanterns burn and throw warm light on the carpet.
-- Presentation only: no tile, collision or warp changes; nothing stands on
-- the deck's walkable cells (the pylons and lamps sit on the railing line,
-- the arches clear the deck by more than a trainer's height).
local V=...
local Assets=require("src.render.Assets")
local Mat4=V.require("Mat4")
local Voxel3D=V.require("Voxel3D")
local RM=V.require("ReferenceMaterials")

local M={REVISION='nugget-bridge-191'}
local cache=setmetatable({},{__mode='k'})
local pi,cos,sin,floor,min,max,abs,sqrt=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs,math.sqrt
local function rh(a,b,s)local v=sin(a*12.9898+b*78.233+s*37.719)*43758.5453;return v-floor(v)end
local DECK,WATER=60,20          -- the OVERWORLD bridge deck tile ($3C), water
M.MAPS={ROUTE_24=true}

------------------------------------------------------------------ find
local function tileAt(map,tx,ty)
 local ok,t=pcall(map.tileAt,map,tx,ty)
 return ok and t or nil
end
-- the longest run of deck tiles on the map: its box in tiles
local function findDeck(map)
 local def=map.def or{}
 local tw,th=(def.width or 0)*4,(def.height or 0)*4
 if tw<=0 or th<=0 or type(map.tileAt)~='function' then return nil end
 local seen,best={},nil
 for ty=0,th-1 do for tx=0,tw-1 do
  local k=ty*4096+tx
  if not seen[k] and tileAt(map,tx,ty)==DECK then
   local q={{tx,ty}};seen[k]=true
   local b={x0=tx,x1=tx,y0=ty,y1=ty,n=0}
   local i=1
   while i<=#q do
    local c=q[i];i=i+1;b.n=b.n+1
    b.x0,b.x1,b.y0,b.y1=min(b.x0,c[1]),max(b.x1,c[1]),min(b.y0,c[2]),max(b.y1,c[2])
    for _,o in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local nx,ny=c[1]+o[1],c[2]+o[2]
     local nk=ny*4096+nx
     if nx>=0 and ny>=0 and nx<tw and ny<th and not seen[nk] and tileAt(map,nx,ny)==DECK then
      seen[nk]=true;q[#q+1]={nx,ny}
     end
    end
   end
   if not best or b.n>best.n then best=b end
  end
 end end
 -- a bridge, not a jetty: long and narrow
 if not best or best.n<40 then return nil end
 local long=(best.y1-best.y0)>=(best.x1-best.x0)
 if not long then return nil end   -- (Route 24's runs north-south)
 best.tw,best.th=tw,th
 return best
end

------------------------------------------------------------------ geometry
local function group()return{verts={},indices={},quads=0}end
local function quad(g,a,b,c,d,shade)
 g.verts[#g.verts+1]={a[1],a[2],a[3],0,0,shade}
 g.verts[#g.verts+1]={b[1],b[2],b[3],1,0,shade}
 g.verts[#g.verts+1]={c[1],c[2],c[3],1,1,shade}
 g.verts[#g.verts+1]={d[1],d[2],d[3],0,1,shade}
 Voxel3D.pushQuad(g.indices,g.quads);g.quads=g.quads+1
end
local function mesh(g)if g.quads==0 then return nil end;return Voxel3D.newMesh(g.verts,g.indices)end
local function mat(name,shade)return RM.encode(name,shade)end

local function build(map)
 local B=findDeck(map)
 if not B then return false end
 local g=group()
 local X0,X1=B.x0*8,(B.x1+1)*8          -- the deck
 local Z0,Z1=B.y0*8,(B.y1+1)*8
 local XC=(X0+X1)/2
 local RW,RE=X0-8,X1+8                   -- the railing lines (post centres)
 local OW,OE=X0-16,X1+16                 -- the railing cells' outer edges
 local glows,lamps,sparks={},{},{}

 -- a box, cut into pieces no longer than 12 (the world curve bends per
 -- vertex), faces shaded by which way they look
 local function box(x0,y0,z0,x1,y1,z1,m,t,skip)
  t=t or 1;skip=skip or{}
  local nx=max(1,math.ceil((x1-x0)/12));local nz=max(1,math.ceil((z1-z0)/12))
  for i=0,nx-1 do for j=0,nz-1 do
   local a0,a1=x0+(x1-x0)*i/nx,x0+(x1-x0)*(i+1)/nx
   local b0,b1=z0+(z1-z0)*j/nz,z0+(z1-z0)*(j+1)/nz
   if not skip.top then quad(g,{a0,y1,b0},{a1,y1,b0},{a1,y1,b1},{a0,y1,b1},mat(m,t))end
   if not skip.bottom then quad(g,{a0,y0,b1},{a1,y0,b1},{a1,y0,b0},{a0,y0,b0},mat(m,t*.55))end
   if j==nz-1 and not skip.s then quad(g,{a0,y0,b1},{a1,y0,b1},{a1,y1,b1},{a0,y1,b1},mat(m,t*.90))end
   if j==0 and not skip.n then quad(g,{a1,y0,b0},{a0,y0,b0},{a0,y1,b0},{a1,y1,b0},mat(m,t*.74))end
   if i==0 and not skip.w then quad(g,{a0,y0,b0},{a0,y0,b1},{a0,y1,b1},{a0,y1,b0},mat(m,t*.80))end
   if i==nx-1 and not skip.e then quad(g,{a1,y0,b1},{a1,y0,b0},{a1,y1,b0},{a1,y1,b1},mat(m,t*.86))end
  end end
 end
 -- an n-sided prism (posts, poles, finials)
 local function prism(x,z,y0,y1,r0,r1,n,m,t,cap)
  t=t or 1
  for i=0,n-1 do
   local a0,a1=i/n*pi*2,(i+1)/n*pi*2
   local sh=t*(.74+.22*(.5+.5*cos((a0+a1)/2-.6)))
   quad(g,{x+cos(a0)*r0,y0,z+sin(a0)*r0},{x+cos(a1)*r0,y0,z+sin(a1)*r0},
          {x+cos(a1)*r1,y1,z+sin(a1)*r1},{x+cos(a0)*r1,y1,z+sin(a0)*r1},mat(m,sh))
   if cap~=false and r1>.01 then
    quad(g,{x,y1,z},{x,y1,z},{x+cos(a1)*r1,y1,z+sin(a1)*r1},{x+cos(a0)*r1,y1,z+sin(a0)*r1},mat(m,t))
   end
  end
 end
 -- a faceted lump (the nugget, the finials)
 local function nugget(x,y,z,r,sd,m,t)
  local n,rings=9,6
  local pts={}
  for j=0,rings do
   pts[j]={}
   local b=-pi/2+j*pi/rings
   for i=0,n-1 do
    local a=i/n*pi*2
    local k=(j==0 or j==rings)and 1 or(.78+.42*rh(sd+i,j,3))
    pts[j][i]={x+cos(a)*cos(b)*r*k,y+sin(b)*r*.82*k,z+sin(a)*cos(b)*r*k}
   end
  end
  for j=0,rings-1 do for i=0,n-1 do
   local i2=(i+1)%n
   local up=(j+.5)/rings
   quad(g,pts[j][i],pts[j][i2],pts[j+1][i2],pts[j+1][i],mat(m,(t or 1)*(.70+.50*up)*(.9+.2*rh(i,j,sd))))
  end end
 end

 ---------------------------------------------------------------- carpet
 -- a red runner down the deck's middle, gold edges, gold lozenges
 do
  local c0,c1=XC-6,XC+6
  local z=Z0+10
  while z<Z1 do
   local z2=min(Z1,z+8)
   quad(g,{c0,.42,z},{c1,.42,z},{c1,.42,z2},{c0,.42,z2},mat('red',.92+rh(z,1,11)*.05))
   quad(g,{c0-1.1,.44,z},{c0,.44,z},{c0,.44,z2},{c0-1.1,.44,z2},mat('gold',1.18))
   quad(g,{c1,.44,z},{c1+1.1,.44,z},{c1+1.1,.44,z2},{c1,.44,z2},mat('gold',1.18))
   z=z2
  end
  for z2=Z0+26,Z1-8,32 do
   quad(g,{XC,.47,z2-3.2},{XC+2.6,.47,z2},{XC,.47,z2+3.2},{XC-2.6,.47,z2},mat('gold',1.22))
  end
 end

 ---------------------------------------------------------------- fascia
 -- sandstone along the deck's sides where open water meets them, a stone
 -- coping, and a buttress every four cells
 for _,side in ipairs({-1,1})do
  local ox=side<0 and OW or OE
  local wx=side<0 and(B.x0-3)or(B.x1+3)     -- the tile column past the rail cell
  for ty=B.y0,B.y1 do
   if tileAt(map,wx,ty)==WATER then
    local z0,z1=ty*8,ty*8+8
    local f=ox+side*.35
    local a,b=min(f,f+side*.2),max(f,f+side*.2)
    quad(g,side<0 and{f,-2.7,z1}or{f,-2.7,z0},side<0 and{f,-2.7,z0}or{f,-2.7,z1},
           side<0 and{f,.55,z0}or{f,.55,z1},side<0 and{f,.55,z1}or{f,.55,z0},mat('ktSandstone',.80+rh(ty,2,13)*.08))
    box(min(ox,ox+side*1.4),.55,z0,max(ox,ox+side*1.4),1.15,z1,'stone',1.02,{bottom=true})
    if ty%8==0 then
     local bx0,bx1=min(ox,ox+side*4.2),max(ox,ox+side*4.2)
     box(bx0,-2.7,z0+1.5,bx1,1.0,z1+2.5,'ktSandstone',.86,{bottom=true})
     box(min(ox,ox+side*4.8),1.0,z0+1,max(ox,ox+side*4.8),1.6,z1+3,'stone',1.0,{bottom=true})
    end
   end
  end
 end

 ---------------------------------------------------------------- lamps
 -- a standard on every other railing post (the posts stand at the rail
 -- cells' centres and are 9.6 tall): an iron pole, a gold collar, a
 -- lantern with a pyramid roof and a gold finial
 local cy0,cy1=floor(B.y0/2),floor(B.y1/2)
 local tops={[-1]={},[1]={}}
 for cy=cy0+2,cy1-1,2 do
  local z=cy*16+8
  for _,side in ipairs({-1,1})do
   local x=side<0 and RW or RE
   prism(x,z,9.5,10.4,.95,.95,8,'gold',1.15)
   prism(x,z,10.4,19.2,.42,.36,6,'dark',.9,false)
   prism(x,z,19.2,19.7,1.25,1.25,8,'dark',.9)
   -- the lantern: four glowing panes in an iron frame
   local r=1.05
   for i=0,3 do
    local a0,a1=i/4*pi*2+pi/4,(i+1)/4*pi*2+pi/4
    quad(g,{x+cos(a0)*r,19.7,z+sin(a0)*r},{x+cos(a1)*r,19.7,z+sin(a1)*r},
           {x+cos(a1)*r*1.12,22.6,z+sin(a1)*r*1.12},{x+cos(a0)*r*1.12,22.6,z+sin(a0)*r*1.12},mat('neonGold',1.35))
    box(x+cos(a0)*r*1.08-.16,19.7,z+sin(a0)*r*1.08-.16,x+cos(a0)*r*1.08+.16,22.6,z+sin(a0)*r*1.08+.16,'dark',.8)
   end
   prism(x,z,22.6,24.4,1.55,.15,4,'dark',.95)
   nugget(x,25.0,z,.75,cy,'gold',1.0)
   lamps[#lamps+1]={x,21.2,z}
   tops[side][#tops[side]+1]={x,17.6,z}
   -- a banner on every fourth post, hung on the deck side
   if cy%4==2 then
    local bx=x-side*.75
    local b0,b1=z-2.3,z+2.3
    local function vq(y0,y1,za,zb,m,t)
     quad(g,{bx,y0,za},{bx,y0,zb},{bx,y1,zb},{bx,y1,za},mat(m,t))
    end
    vq(11.2,17.6,b0,b1,'red',.95)
    vq(17.0,17.6,b0-.15,b1+.15,'gold',1.2)
    vq(11.2,17.0,b0-.15,b0+.25,'gold',1.15);vq(11.2,17.0,b1-.25,b1+.15,'gold',1.15)
    -- the swallowtail
    quad(g,{bx,11.2,b0},{bx,11.2,z},{bx,9.9,b0},{bx,9.9,b0},mat('red',.88))
    quad(g,{bx,11.2,z},{bx,11.2,b1},{bx,9.9,b1},{bx,9.9,b1},mat('red',.88))
    -- a gold lozenge (the nugget) in the middle
    local mx=bx-side*.04
    quad(g,{mx,14.4+1.7,z},{mx,14.4,z+1.3},{mx,14.4-1.7,z},{mx,14.4,z-1.3},mat('gold',1.25))
    -- the cross-bar it hangs from
    box(min(x,bx)-.15,17.55,b0-.3,max(x,bx)+.15,17.95,b1+.3,'dark',.85)
   end
  end
 end

 ---------------------------------------------------------------- bunting
 -- pennants on a swagged line from lamp to lamp along both railings
 local COLS={'red','gold','cream','navy'}
 for _,side in ipairs({-1,1})do
  local T=tops[side]
  for i=1,#T-1 do
   local a,b=T[i],T[i+1]
   local x=a[1]
   local len=b[3]-a[3]
   local n=floor(len/2.7)
   local function at(u)return a[3]+len*u,a[2]-4.2*sin(u*pi)end
   -- the line
   for k=0,7 do
    local z0,y0=at(k/8);local z1,y1=at((k+1)/8)
    quad(g,{x,y0,z0},{x,y1,z1},{x,y1+.14,z1},{x,y0+.14,z0},mat('dark',.7))
   end
   for k=1,n-1 do
    local u=k/n
    local z,y=at(u)
    local col=COLS[(k+i)%4+1]
    local w=.95
    quad(g,{x,y,z-w},{x,y,z+w},{x,y-2.3,z},{x,y-2.3,z},mat(col,col=='navy'and .95 or 1.08))
   end
  end
 end

 ---------------------------------------------------------------- gateways
 -- glyphs for the name, 5x7, one string of rows per letter
 local FONT={
  N={'10001','11001','10101','10011','10001','10001','10001'},
  U={'10001','10001','10001','10001','10001','10001','01110'},
  G={'01110','10001','10000','10111','10001','10001','01111'},
  E={'11111','10000','10000','11110','10000','10000','11111'},
  T={'11111','00100','00100','00100','00100','00100','00100'},
  B={'11110','10001','10001','11110','10001','10001','11110'},
  R={'11110','10001','10001','11110','10100','10010','10001'},
  I={'01110','00100','00100','00100','00100','00100','01110'},
  D={'11100','10010','10001','10001','10001','10010','11100'},
 }
 -- gold letters standing proud of a face at z=fz, read from the side
 -- the face looks to (dir +1: south, -1: north)
 local function letters(text,cx,y0,fz,dir,px)
  local n=#text
  local wid=(n*6-1)*px
  local x=cx-wid/2
  for i=1,n do
   local gl=FONT[text:sub(i,i)]
   if gl then
    for row=1,7 do
     local s=gl[row]
     local col=1
     while col<=5 do
      if s:sub(col,col)=='1' then
       local e=col
       while e<5 and s:sub(e+1,e+1)=='1' do e=e+1 end
       local lx0,lx1=x+(col-1)*px,x+e*px
       if dir<0 then lx0,lx1=2*cx-lx1,2*cx-lx0 end
       local ly1=y0+(8-row)*px;local ly0=ly1-px
       local fz0,fz1=fz,fz+dir*.3
       box(lx0,ly0,min(fz0,fz1),lx1,ly1,max(fz0,fz1),'gold',1.25,{bottom=true})
       col=e+1
      else col=col+1 end
     end
    end
   end
   x=x+6*px
  end
 end
 local function gateway(z,sd)
  local L=34            -- the lintel's underside: well over anyone's head
  for _,side in ipairs({-1,1})do
   local x=side<0 and RW or RE
   -- the pylon: plinth, shaft, gold band, cornice, an orb
   box(x-7.6,0,z-6.6,x+7.6,3.2,z+6.6,'stone',.98)
   box(x-6.6,3.2,z-5.6,x+6.6,L-3,z+5.6,'ktSandstone',1.0)
   for _,yy in ipairs({10,19})do box(x-6.8,yy,z-5.8,x+6.8,yy+.6,z+5.8,'ktSandstone',.82)end
   box(x-6.9,L-4.8,z-5.9,x+6.9,L-3.6,z+5.9,'gold',1.15)
   box(x-7.4,L-3,z-6.4,x+7.4,L-.8,z+6.4,'stone',1.02)
   -- lanterns on the pylons' faces toward each approach
   for _,dz in ipairs({-1,1})do
    local lz=z+dz*5.6
    box(x-1.1,14.6,min(lz,lz+dz*1.6),x+1.1,17.8,max(lz,lz+dz*1.6),'neonGold',1.35)
    box(x-1.4,17.8,min(lz,lz+dz*1.9),x+1.4,18.3,max(lz,lz+dz*1.9),'dark',.85)
    box(x-.9,14.1,min(lz,lz+dz*1.4),x+.9,14.6,max(lz,lz+dz*1.4),'dark',.85)
    lamps[#lamps+1]={x,16.2,lz+dz*.9}
   end
  end
  -- the lintel and the curved arch under it
  local a0,a1=RW+6.6,RE-6.6
  box(RW-6.6,L-.8,z-4.6,RE+6.6,L+8.6,z+4.6,'ktSandstone',1.0)
  box(RW-7.2,L+8.6,z-5.2,RE+7.2,L+10.2,z+5.2,'stone',1.04)
  local span=(a1-a0)/2
  local N=10
  local function yAt(xx)local q=(xx-(a0+a1)/2)/span;return L-7+6*sqrt(max(0,1-q*q))end
  for i=0,N-1 do
   local xa,xb=a0+(a1-a0)*i/N,a0+(a1-a0)*(i+1)/N
   local ya,yb=yAt(xa),yAt(xb)
   -- the spandrels down to the curve, and the curve's soffit
   quad(g,{xa,ya,z+4.4},{xb,yb,z+4.4},{xb,L-.8,z+4.4},{xa,L-.8,z+4.4},mat('ktSandstone',.92))
   quad(g,{xb,yb,z-4.4},{xa,ya,z-4.4},{xa,L-.8,z-4.4},{xb,L-.8,z-4.4},mat('ktSandstone',.74))
   quad(g,{xa,ya,z-4.4},{xb,yb,z-4.4},{xb,yb,z+4.4},{xa,ya,z+4.4},mat('stone',.62))
   -- a gold line along the arch's edge, both faces
   quad(g,{xa,ya,z+4.46},{xb,yb,z+4.46},{xb,yb+.55,z+4.46},{xa,ya+.55,z+4.46},mat('gold',1.12))
   quad(g,{xb,yb,z-4.46},{xa,ya,z-4.46},{xa,ya+.55,z-4.46},{xb,yb+.55,z-4.46},mat('gold',1.0))
  end
  -- the keystone
  box((a0+a1)/2-1.6,L-1.6,z-4.9,(a0+a1)/2+1.6,L+2.6,z+4.9,'gold',1.12)
  -- the name on navy bands, both faces
  for _,dir in ipairs({1,-1})do
   local fz=z+dir*4.6
   local fz2=fz+dir*.12
   box(XC-23.5,L+1.6,min(fz,fz2),XC+23.5,L+8.0,max(fz,fz2),'navy',.95,{bottom=true})
   letters('NUGGET BRIDGE',XC,L+2.5,fz2,dir,.62)
  end
  -- the crown: a great nugget on a stepped plinth, glinting
  box(XC-5,L+10.2,z-4,XC+5,L+11.6,z+4,'stone',1.02)
  box(XC-3.6,L+11.6,z-3,XC+3.6,L+12.8,z+3,'gold',1.12)
  nugget(XC,L+17.2,z,5.4,sd*7,'gold',1.02)
  sparks[#sparks+1]={XC,L+17.2,z,5.4}
  glows[#glows+1]={XC,L+17.2,z,13,.10}
  -- smaller nuggets on the pylon caps
  for _,side in ipairs({-1,1})do
   local x=side<0 and RW or RE
   nugget(x,L+11.9,z,2.1,sd+side,'gold',1.0)
  end
 end
 gateway(Z0+8,3)
 gateway(Z1-8,5)

 return{mesh=mesh(g),quads=g.quads,lamps=lamps,glows=glows,sparks=sparks,box=B}
end

------------------------------------------------------------------ draw
local whiteTex
local function white()
 if not whiteTex then
  local ok,img=pcall(function()
   local d=love.image.newImageData(2,2)
   for y=0,1 do for x=0,1 do d:setPixel(x,y,1,1,1,1)end end
   local m=love.graphics.newImage(d);m:setFilter("nearest","nearest");return m
  end)
  whiteTex=ok and img or nil
 end
 return whiteTex
end
local function built(map)
 local b=cache[map]
 if b==nil then
  local ok,r=pcall(build,map)
  if not ok then
   if V.mod and V.mod.log and V.mod.log.info then pcall(V.mod.log.info,V.mod.log,'Nugget Bridge failed: %s',tostring(r))end
   r=false
  end
  b=r or false;cache[map]=b
 end
 return b or nil
end
local function drawMap(map,ox,oz)
 local b=built(map);if not(b and b.mesh)then return end
 local tex=white();if not tex then return end
 local g=love.graphics
 local model=(ox~=0 or oz~=0)and Mat4.translate(ox,0,oz)or nil
 local pushed=pcall(g.push,"all")
 pcall(function()
  g.setDepthMode("lequal",true);g.setBlendMode("alpha");g.setColor(1,1,1,1)
  Voxel3D.lighting(true)
  Voxel3D.draw(b.mesh,tex,model)
 end)
 if pushed then pcall(g.pop)end
 -- the light: halos round the lanterns, warm pools on the deck after
 -- dark, the crown nuggets glinting
 local okK,K=pcall(function()return V.require("LeagueRoad").fxKit()end)
 if not(okK and K and K.soft and K.cross and K.quad)then return end
 local night=Voxel3D.glassNight or 0
 local t=0;pcall(function()t=love.timer.getTime()end)
 pcall(Voxel3D.withEffect,"add",function()
  local function TR(x,y,z,s,sy)return Mat4.mul(Mat4.translate(x+ox,y,z+oz),Mat4.scale(s,sy or s,s))end
  -- the lanterns' halos and pools: two static streams, built once, one
  -- draw each
  if b.halos==nil and K.newStream and K.streamPut then
   local n=#b.lamps
   local hs,ps=K.newStream(n),K.newStream(n)
   if hs and ps then
    for i,l in ipairs(b.lamps)do
     K.streamPut(hs,i-1,l[1],l[2],l[3],7.5,false)
     K.streamPut(ps,i-1,l[1],.6,l[3],16,true)
    end
    pcall(hs.mesh.setVertices,hs.mesh,hs.verts);pcall(ps.mesh.setVertices,ps.mesh,ps.verts)
    b.halos,b.pools=hs,ps
   else
    if hs and hs.mesh then pcall(hs.mesh.release,hs.mesh)end
    if ps and ps.mesh then pcall(ps.mesh.release,ps.mesh)end
    b.halos=false
   end
  end
  local model=Mat4.translate(ox,0,oz)
  if b.halos then
   local fl=.94+.06*sin(t*6.1)
   g.setColor(1,.70,.32,(.08+.20*night)*fl)
   Voxel3D.draw(b.halos.mesh,K.soft,model)
   if night>.05 then
    g.setColor(1,.66,.34,.10*night)
    Voxel3D.draw(b.pools.mesh,K.soft,model)
   end
  end
  for _,w in ipairs(b.glows)do
   g.setColor(1,.82,.36,w[5]+.10*night)
   Voxel3D.draw(K.cross,K.soft,TR(w[1],w[2],w[3],w[4]))
  end
  for si,s in ipairs(b.sparks)do
   for k=0,2 do
    local ph=(t*.45+k*.37+si*.21)%1
    local tw=ph<.14 and sin(ph/.14*pi)or 0
    if tw>0 then
     local a=k*2.1+si
     local x,y,z=s[1]+cos(a)*s[4]*.7,s[2]+(rh(k,si,5)-.3)*s[4],s[3]+sin(a)*s[4]*.7
     g.setColor(1,.96,.80,.85*tw)
     Voxel3D.draw(K.cross,K.soft,Mat4.mul(Mat4.translate(x+ox,y,z+oz),Mat4.scale(.45,5*tw,.45)))
     Voxel3D.draw(K.cross,K.soft,Mat4.mul(Mat4.translate(x+ox,y,z+oz),Mat4.scale(5*tw,.45,5*tw)))
    end
   end
  end
 end)
 pcall(Voxel3D.lighting,true)
end

function M.enabled(map)
 return map and M.MAPS[tostring(map.id)]==true
end
function M.draw(state)
 local map=state and state.map
 if not map then return false end
 local p=state.player
 if M.enabled(map)then drawMap(map,0,0)end
 local RD=V.require("RenderDistance")
 for _,nb in ipairs(state.neighbors or{})do
  if nb.map and M.enabled(nb.map)and(not RD or RD.neighbor(nb,p))
    and not(V.perfProbe and(V.perfProbe.noNeighbors or(V.perfProbe.noMaps and V.perfProbe.noMaps[nb.map.id])))then
   drawMap(nb.map,nb.ox or 0,nb.oy or 0)
  end
 end
 return true
end
M.build=build
M.findDeck=findDeck
function M.invalidate()
 for _,b in pairs(cache)do
  if b then
   for _,m in pairs({b.mesh,b.halos and b.halos.mesh,b.pools and b.pools.mesh})do
    if m and m.release then pcall(m.release,m)end
   end
  end
 end
 cache=setmetatable({},{__mode='k'})
 if whiteTex and whiteTex.release then pcall(whiteTex.release,whiteTex)end
 whiteTex=nil
end
Assets.register(M.invalidate)
return M
