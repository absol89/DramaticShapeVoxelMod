-- TEST150: Safari meadow life. The reserve already rebuilds every blocked
-- source cell (hedges, trees, stumps, banks, ponds); its walkable lawns were
-- left bare. This pass dresses only plain lawn cells (source tile 48) with
-- LOW ground life a trainer walks straight through: wildflower drifts,
-- clover, pebbles, ferns and mushrooms at woodland edges, sedges and stones
-- on pond shores. Nothing stands taller than ~3 units, nothing touches tall
-- grass, paths, water, warps, signs or NPCs, and collision is untouched.
-- Leaves use the native forest leaf material, so the autumn crown tint turns
-- them gold and rust by itself; flowers are species that bloom in both
-- seasons (asters, goldenrod, daisies, clover), so no seasonal cache key.
local V=...;local M={};local pi=math.pi
local function key(x,z)return(z+64)*4096+x+64 end
local function hash(x,z,s)return V.require('SurfaceCraft').hash(x,z,s)end

local function nearEvent(map,x,z,pad)
 for _,list in ipairs({map.def.warps or{},map.def.signs or{},map.def.objects or{}})do
  for _,e in ipairs(list)do
   if e.x and e.y and math.abs(e.x*16+8-x)<pad and math.abs(e.y*16+8-z)<pad then return true end
  end
 end
 return false
end

-- A single small flower: thin stem, a few petals around a bright heart.
local function flower(G,x,y,z,h,petal,heart,seed)
 local lean=(hash(seed,3,1301)-.5)*.5
 local top={x+lean,y+h,z+lean*.6}
 G.beam({x,y,z},top,.11,'forestLeaf',.9)
 -- one leaf on the stem
 for s=1,1 do local a=seed+s
  local m={x+lean*.4,y+h*.35,z+lean*.25}
  G.face(m,{m[1]+math.cos(a)*.7,m[2]+.35,m[3]+math.sin(a)*.7},{m[1]+math.cos(a+.4)*.9,m[2]+.15,m[3]+math.sin(a+.4)*.9},{m[1]+math.cos(a+.4)*.9,m[2]+.15,m[3]+math.sin(a+.4)*.9},'forestLeaf',.95)
 end
 local n=4
 for i=0,n-1 do local a=i*2*pi/n+seed
  local p={top[1]+math.cos(a)*.9,top[2]+.1,top[3]+math.sin(a)*.9}
  local l={top[1]+math.cos(a-.55)*.42,top[2]+.06,top[3]+math.sin(a-.55)*.42}
  local r={top[1]+math.cos(a+.55)*.42,top[2]+.06,top[3]+math.sin(a+.55)*.42}
  G.face(top,l,p,r,petal,1.05)
 end
 G.face({top[1]-.2,top[2]+.16,top[3]-.2},{top[1]-.2,top[2]+.16,top[3]+.2},{top[1]+.2,top[2]+.16,top[3]+.2},{top[1]+.2,top[2]+.16,top[3]-.2},heart,1.12)
end

-- Goldenrod: a plume of tiny yellow sprays on a leaning stalk.
local function goldenrod(G,x,y,z,h,seed)
 local lean=(hash(seed,5,1303)-.5)*.8
 local top={x+lean,y+h,z+lean*.5}
 G.beam({x,y,z},top,.13,'forestLeaf',.88)
 for i=0,5 do local t=.55+i*.08;local a=seed+i*2.1
  local p={x+lean*t,y+h*t,z+lean*.5*t}
  local q={p[1]+math.cos(a)*.75,p[2]+.55,p[3]+math.sin(a)*.75}
  G.beam(p,q,.32,'gold',1.08)
 end
end

local function clover(G,x,y,z,r,seed)
 -- A low mat of trefoil leaves with a couple of pink-white heads.
 for i=0,6 do local a=i*2.4+seed;local d=r*(.25+.7*hash(i,seed,1305))
  local cx,cz=x+math.cos(a)*d,z+math.sin(a)*d
  for k=0,2 do local b=a+k*2.09
   local tip={cx+math.cos(b)*.62,y+.32,cz+math.sin(b)*.62}
   G.face({cx,y+.18,cz},{cx+math.cos(b-.6)*.42,y+.26,cz+math.sin(b-.6)*.42},tip,{cx+math.cos(b+.6)*.42,y+.26,cz+math.sin(b+.6)*.42},'leaf',.92+.06*k)
  end
 end
 for i=0,1 do local a=seed*1.7+i*2.8;local cx,cz=x+math.cos(a)*r*.4,z+math.sin(a)*r*.4
  G.beam({cx,y,cz},{cx,y+.95,cz},.09,'forestLeaf',.9)
  G.box(cx-.26,y+.9,cz-.26,cx+.26,y+1.35,cz+.26,i==0 and 'flower'or 'white',1.05)
 end
end

local function pebble(G,x,y,z,s,seed)
 local n=6;local top={x,y+s*.55,z};local ring={}
 for i=0,n-1 do local a=i*2*pi/n+seed;local r=s*(.85+.25*hash(i,seed,1307))
  ring[i+1]={x+math.cos(a)*r,y+.02,z+math.sin(a)*r*.8}
 end
 for i=1,n do local k=i%n+1;G.face(ring[i],ring[k],top,top,'stone',.80+.12*hash(i,seed,1309))end
end

local function fern(G,x,y,z,s,seed)
 -- Arching fronds from one crown; leaflets pinned along each rib.
 for i=0,4 do local a=i*2*pi/5+seed*.7;local L=(3.0+hash(i,seed,1311)*1.2)*s
  local prev={x,y+.1,z}
  for k=1,3 do local t=k/3
   local p={x+math.cos(a)*L*t,y+.1+math.sin(t*pi*.85)*1.9*s,z+math.sin(a)*L*t}
   G.beam(prev,p,.08*s,'forestLeaf',.86)
   local w=(1-t*.6)*.75*s;local ux,uz=-math.sin(a)*w,math.cos(a)*w
   G.face(prev,{p[1]+ux,p[2]-.12,p[3]+uz},p,p,'forestLeaf',1.0)
   G.face(prev,p,{p[1]-ux,p[2]-.12,p[3]-uz},{p[1]-ux,p[2]-.12,p[3]-uz},'forestLeaf',.86)
   prev=p
  end
 end
end

local function mushroom(G,x,y,z,s,cap)
 G.beam({x,y,z},{x,y+1.1*s,z},.42*s,'cream',1.0)
 local n=8;local c={x,y+1.7*s,z};local rim={}
 for i=0,n-1 do local a=i*2*pi/n;rim[i+1]={x+math.cos(a)*.95*s,y+1.05*s,z+math.sin(a)*.95*s}end
 for i=1,n do local k=i%n+1;G.face(rim[i],rim[k],c,c,cap,1.02)end
 for i=1,n do local k=i%n+1;G.face(rim[k],rim[i],{x,y+1.0*s,z},{x,y+1.0*s,z},'cream',.8)end
 if cap=='red'then
  for i=0,2 do local a=i*2.2+s;G.box(x+math.cos(a)*.45*s-.1,y+1.5*s,z+math.sin(a)*.45*s-.1,x+math.cos(a)*.45*s+.1,y+1.62*s,z+math.sin(a)*.45*s+.1,'white',1.1)end
 end
end

local function sedge(G,x,y,z,h,seed)
 for i=0,6 do local a=i*2.399+seed;local r=.3+hash(i,seed,1313)*.5
  local b={x+math.cos(a)*r,y,z+math.sin(a)*r}
  local t={b[1]+math.cos(a)*.9,y+h*(.7+.3*hash(i,seed,1315)),b[3]+math.sin(a)*.9}
  G.face({b[1]-.16,y,b[3]},{b[1]+.16,y,b[3]},t,t,'forestLeaf',.9+.08*(i%2))
 end
 if hash(seed,1,1317)>.6 then -- a cattail
  G.beam({x,y,z},{x+.2,y+h+1.4,z},.1,'forestLeaf',.85)
  G.box(x+.02,y+h+.5,z-.24,x+.48,y+h+1.6,z+.24,'wood',.9)
 end
end

-- Savanna tussock: a fountain of long blades (native leaf, autumn-tinted).
local function tussock(G,x,y,z,h,seed)
 for i=0,8 do local a=i*2.399+seed;local r=.25+hash(i,seed,1391)*.45
  local b={x+math.cos(a)*r,y,z+math.sin(a)*r}
  local reach=1.0+hash(seed,i,1393)*1.6
  local mid={b[1]+math.cos(a)*reach*.45,y+h*.65,b[3]+math.sin(a)*reach*.45}
  local tip={b[1]+math.cos(a)*reach,y+h*(.75+.25*hash(i,seed,1395)),b[3]+math.sin(a)*reach}
  local ux,uz=-math.sin(a)*.22,math.cos(a)*.22
  G.face({b[1]-ux,y,b[3]-uz},{b[1]+ux,y,b[3]+uz},{mid[1]+ux*.7,mid[2],mid[3]+uz*.7},{mid[1]-ux*.7,mid[2],mid[3]-uz*.7},'forestLeaf',.86+.1*(i%2))
  G.face({mid[1]-ux*.7,mid[2],mid[3]-uz*.7},{mid[1]+ux*.7,mid[2],mid[3]+uz*.7},tip,tip,'forestLeaf',.95+.08*(i%3)*.5)
 end
end
-- Moss cap, a bracket fungus and a fern at the base of a source stump.
function M.dressStump(G,x,z,variant,seed)
 -- Matches SafariReserve.stump exactly: tilted cut, tapering bark wall.
 local h=({5.1,7.3,4.2})[variant+1];local top=3.2+variant*.25
 local tilt=.07*(variant-1)
 local function cut(u,v)return h+u*tilt+v*.035+.05 end
 local function wall(y)return 5.1+(top-5.1)*(y/h)end
 -- TEST152: moss is one irregular dark patch lying ON the sloped cut, creeping
 -- in from the rim (the old square tiles read as white squares in game).
 if hash(x,z,1321)>.45 then
  local a0=hash(x,z,1322)*2*pi;local cu,cv=math.cos(a0)*top*.45,math.sin(a0)*top*.45
  local n=9;local ring={}
  for i=0,n-1 do local a=i*2*pi/n;local r=(1.15+hash(i,seed,1323)*.9)
   local u,v=cu+math.cos(a)*r,cv+math.sin(a)*r
   local d=math.sqrt(u*u+v*v);if d>top*.97 then u,v=u*top*.97/d,v*top*.97/d end
   ring[i+1]={x+u,cut(u,v),z+v}
  end
  local c={x+cu,cut(cu,cv)+.02,z+cv}
  for i=1,n do local k=i%n+1;G.face(ring[i],ring[k],c,c,'green',.82+.1*hash(i,seed,1324))end
  -- a few sprouts rooted in the moss
  for i=0,2 do local a=a0+i*1.9;local u,v=cu+math.cos(a)*.6,cv+math.sin(a)*.6;local y=cut(u,v)
   G.face({x+u-.12,y,z+v},{x+u+.12,y,z+v},{x+u+math.cos(a)*.35,y+.9,z+v+math.sin(a)*.35},{x+u+math.cos(a)*.35,y+.9,z+v+math.sin(a)*.35},'forestLeaf',.95)
  end
 end
 -- Shelf fungus: brown half-moon brackets growing out of the bark wall.
 if hash(x,z,1325)>.55 then
  local a=hash(x,z,1327)*2*pi
  for k=0,1 do local y=h*(.32+k*.24);local r=wall(y)-.15;local size=1.25-k*.3
   local bx,bz=x+math.cos(a+k*.35)*r,z+math.sin(a+k*.35)*r
   local out_=a+k*.35;local ox,oz=math.cos(out_),math.sin(out_);local ux,uz=-oz,ox
   local prev
   for i=0,6 do local t=i/6*pi
    local p={bx+ux*math.cos(t)*size+ox*math.sin(t)*size*.85,y,bz+uz*math.cos(t)*size+oz*math.sin(t)*size*.85}
    if prev then
     G.face({bx,y+.28,bz},prev,p,p,'oak',1.0)
     G.face(prev,{prev[1],y-.22,prev[3]},{p[1],y-.22,p[3]},p,'wood',.78)
    end
    prev=p
   end
  end
 end
 if hash(x,z,1329)>.35 then
  local a=hash(x,z,1331)*2*pi;fern(G,x+math.cos(a)*5.6,0,z+math.sin(a)*5.6,.8,seed)
 end
 if hash(x,z,1333)>.7 then mushroom(G,x+5.4,0,z-2.2,.9,'red');mushroom(G,x+6.2,0,z-1.2,.6,'red')end
end

function M.build(S,map,G,W,H)
 local CW,CH=W/2,H/2
 local function lawn(cx,cz)
  if cx<0 or cz<0 or cx>=CW or cz>=CH then return false end
  if not map:isWalkableCell(cx,cz)then return false end
  if map:tileAt(cx*2,cz*2+1)~=48 then return false end
  for _,o in ipairs({{0,0},{1,0},{0,1},{1,1}})do if S.skip[key(cx*2+o[1],cz*2+o[2])]then return false end end
  return true
 end
 local function water(cx,cz)
  if cx<0 or cz<0 or cx>=CW or cz>=CH then return false end
  local s=S.shapeAt[key(cx*2,cz*2)];return s and s.class=='water'
 end
 local function woody(cx,cz)
  for _,o in ipairs({{0,0},{1,0},{0,1},{1,1}})do
   local c=S.safariClaims[key(cx*2+o[1],cz*2+o[2])]
   if c=='tree'or c=='hedge'or c=='stump'then return true end
  end
  return false
 end
 local placed=0
 local petals={'ktViolet','white','flower','ktViolet'}
 for cz=0,CH-1 do for cx=0,CW-1 do
  if lawn(cx,cz)then
   local x0,z0=cx*16,cz*16
   if not nearEvent(map,x0+8,z0+8,20)then
    local s=S.shapeAt[key(cx*2,cz*2+1)];local y=(s and s.h or 0)+.04
    local shore,edge,meadow=false,false,false
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     if water(cx+d[1],cz+d[2])then shore=d end
     if woody(cx+d[1],cz+d[2])then edge=true end
     local nx,nz=cx+d[1],cz+d[2]
     if nx>=0 and nz>=0 and nx<CW and nz<CH and map:tileAt(nx*2,nz*2+1)==32 then meadow=d end
    end
    -- Slow fields make drifts and clearings instead of an even sprinkle.
    local field=math.sin(x0*.031+z0*.017)+math.cos(z0*.043-x0*.021)
    local n=hash(cx,cz,1341)
    if shore then
     -- Bank life hugs the water side of the cell.
     local sx,sz=x0+8+shore[1]*6,z0+8+shore[2]*6
     local ux,uz=-shore[2],shore[1]
     for i=0,2 do local t=(i-1)*4.6+(hash(cx,cz,1343+i)-.5)*2
      local px,pz=sx+ux*t,sz+uz*t
      if hash(cx+i,cz,1347)>.35 then sedge(G,px,y,pz,2.2+hash(i,cx,1349)*1.0,cx*3+cz+i)
      else pebble(G,px,y,pz,.9+hash(cz,i,1351)*.8,cx+cz*5+i)end
     end
     placed=placed+1
    elseif edge and n>.45 then
     local a=n*2*pi;local px,pz=x0+8+math.cos(a)*3,z0+8+math.sin(a)*3
     if n>.8 then mushroom(G,px,y,pz,.8+n*.3,n>.9 and 'red'or 'oak');mushroom(G,px+1.3,y,pz+.8,.55,'oak')
     else fern(G,px,y,pz,.75+n*.25,cx*7+cz)end
     placed=placed+1
    elseif meadow and n>.25 then
     -- Lawn beside encounter grass: shorter tufts blend the hard stripes.
     local mx,mz=x0+8+meadow[1]*4,z0+8+meadow[2]*4
     for i=0,2 do local px=mx+(hash(cx,cz,1401+i)-.5)*10;local pz=mz+(hash(cz,cx,1405+i)-.5)*10
      tussock(G,px,y,pz,1.6+hash(i,cx,1409)*1.4,cx*5+cz*3+i)
     end
     placed=placed+1
    elseif field+n*1.4>1.35 then
     -- A wildflower drift: several flowers of one or two kinds per cell.
     local kind=math.floor(hash(math.floor(x0/48),math.floor(z0/48),1353)*5)
     for i=0,5 do
      local px=x0+2.5+hash(cx,cz,1361+i)*11;local pz=z0+2.5+hash(cz,cx,1371+i)*11
      if kind==4 or (kind==3 and i%2==0) then goldenrod(G,px,y,pz,2.6+hash(i,cx,1381)*1.2,cx+cz*3+i)
      else flower(G,px,y,pz,1.9+hash(i,cz,1383)*1.2,petals[kind%4+1],(kind%4==0 or kind%4==3)and 'gold'or 'gold',cx*5+cz+i)end
     end
     placed=placed+1
    elseif n>.55 and n<.72 then
     tussock(G,x0+4+n*8,y,z0+5+n*6,2.8+n*1.6,cx*3+cz*11);placed=placed+1
    elseif n<.10 then
     clover(G,x0+8,y,z0+8,2.6,cx+cz*7);placed=placed+1
    elseif n>.93 then
     pebble(G,x0+5+n*4,y,z0+6,1.1,cx*3+cz);pebble(G,x0+7.5+n*4,y,z0+7.4,.7,cx+cz*3);placed=placed+1
    end
   end
  end
 end end
 for _,st in ipairs(S.safariStumps or {})do M.dressStump(G,st.x,st.z,st.variant,st.x+st.z)end
 S.safariMeadow=placed
 return placed
end
return M
