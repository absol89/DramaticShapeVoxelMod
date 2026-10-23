-- TEST143: Celadon Department Store roof terrace, rebuilt as one authored
-- scene. The ROM map still owns collision, warps, NPCs and the vending
-- machine text; every piece is placed on the original cells, read from the
-- live tile grid (LOBBY tileset classes, data/voxel_heights):
--   railing/parapet cells  -> stone parapet with a steel guard rail
--   vending machine cells  -> lit drink machines (generic, no brands)
--   round-table cells      -> cafe tables with striped umbrellas
--   stool cells            -> cafe chairs (seat kept at the pinned 5)
--   stair cell + stairhead -> a small rooftop stair kiosk
--   any other blocked cell -> planter beds with shrubs, flowers and trees
-- Walkable floor gets warm stone pavers and a Poke Ball mosaic. String
-- lights cross the terrace; a backlit sign stands on the north parapet; the
-- store's upper facade drops away below the parapet. The engine's border
-- ring (the giant edge slabs) is hidden for this map only.
local V=...
local M={REVISION='celadon-roof-143'}
local Base=V.require('RedsHouseRoom')
local K=Base.kit
local builder,hash,pottedPlant,flowers=K.builder,K.hash,K.pottedPlant,K.flowers
local pi,cos,sin,floor,min,max,abs,sqrt=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs,math.sqrt
local cached,white
local function key(x,y)return (y+64)*4096+x+64 end

function M.accepts(map)
 return map and map.id=='CELADON_MART_ROOF' and map.def and map.def.width==10
   and map.def.height==4 or false
end

------------------------------------------------------------------ layout
local CLASS={}
for cls,tiles in pairs({
 stair={10,11,26,27,12,13,28,29}, vend={34,35,50,51},
 table={9,25,39,54,57,70,71,85,86,87}, stool={7,8,23,24},
 rail={1,33,68,75,76,77,78,79,84,91},
})do for _,t in ipairs(tiles)do CLASS[t]=cls end end
local RANK={stair=6,vend=5,table=4,stool=3,rail=2}
function M.layout(map)
 local cw,ch=map.def.width*2,map.def.height*2
 local L={cw=cw,ch=ch,cell={},walk={},source='tiles'}
 local read=0
 for cy=0,ch-1 do for cx=0,cw-1 do
  local best
  if map.tileAt then
   for j=0,1 do for i=0,1 do
    local ok,t=pcall(map.tileAt,map,cx*2+i,cy*2+j)
    if ok and t then read=read+1
     local c=CLASS[t];if c and(not best or RANK[c]>RANK[best])then best=c end
    end
   end end
  end
  local okW,w=pcall(map.isWalkableCell,map,cx,cy)
  w=okW and w or false
  L.walk[cy*cw+cx]=w
  if best=='stool' and not w then best='table' end
  if not best and not w then
   local edge=cx==0 or cy==0 or cx==cw-1 or cy==ch-1
   best=edge and 'rail' or 'planter'
  end
  L.cell[cy*cw+cx]=best or (w and 'floor') or 'planter'
 end end
 if read<cw*ch*4 then L.source='fallback' end
 -- Blocked cells beside the stairs are the stairhead, not planters.
 for cy=0,ch-1 do for cx=0,cw-1 do
  if L.cell[cy*cw+cx]=='stair'then
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
    local x,y=cx+d[1],cy+d[2]
    if x>=0 and y>=0 and x<cw and y<ch and L.cell[y*cw+x]=='planter'then L.cell[y*cw+x]='kiosk'end
   end
  end
 end end
 return L
end
local function at(L,cx,cy)
 if cx<0 or cy<0 or cx>=L.cw or cy>=L.ch then return 'out' end
 return L.cell[cy*L.cw+cx]
end
-- Connected groups of one class (tables, kiosks).
local function groups(L,cls)
 local seen,out={},{}
 for cy=0,L.ch-1 do for cx=0,L.cw-1 do
  local i=cy*L.cw+cx
  if L.cell[i]==cls and not seen[i]then
   local g={x0=cx,x1=cx,y0=cy,y1=cy,cells={}};local stack={{cx,cy}};seen[i]=true
   while #stack>0 do
    local c=table.remove(stack);g.cells[#g.cells+1]=c
    g.x0,g.x1,g.y0,g.y1=min(g.x0,c[1]),max(g.x1,c[1]),min(g.y0,c[2]),max(g.y1,c[2])
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local x,y=c[1]+d[1],c[2]+d[2];local j=y*L.cw+x
     if x>=0 and y>=0 and x<L.cw and y<L.ch and L.cell[j]==cls and not seen[j]then seen[j]=true;stack[#stack+1]={x,y}end
    end
   end
   out[#out+1]=g
  end
 end end
 return out
end

------------------------------------------------------------------ pieces
local function pavers(G,L)
 local face=G.face
 for cy=0,L.ch-1 do for cx=0,L.cw-1 do
  local c=at(L,cx,cy)
  if c~='rail'and c~='planter'and c~='stair'then
   for j=0,1 do for i=0,1 do
    local x,z=cx*16+i*8,cy*16+j*8
    local alt=(floor(x/8)+floor(z/8))%2==0
    local tone=.94+hash(floor(x/8),floor(z/8))*.10
    face({x+.35,0,z+.35},{x+.35,0,z+7.65},{x+7.65,0,z+7.65},{x+7.65,0,z+.35},alt and'ktSandstone'or'cream',tone)
    face({x,-.05,z},{x,-.05,z+8},{x+8,-.05,z+8},{x+8,-.05,z},'mortar',.7)
   end end
  end
 end end
end
-- Poke Ball mosaic in the most open patch of floor.
local function mosaic(G,L)
 local best,bx,bz=0
 for cy=1,L.ch-2 do for cx=1,L.cw-2 do
  local n=0
  for y=-1,1 do for x=-1,1 do if at(L,cx+x,cy+y)=='floor'then n=n+1 end end end
  if n>best then best,bx,bz=n,cx,cy end
 end end
 if not bx or best<9 then return end
 local x,z,r=bx*16+8,bz*16+8,17
 local face,n=G.face,28
 for i=0,n-1 do local a,b=i*2*pi/n,(i+1)*2*pi/n
  local mat=(a<pi-1e-6)and'red'or'white'
  face({x,.06,z},{x+cos(b)*r,.06,z-sin(b)*r},{x+cos(a)*r,.06,z-sin(a)*r},{x+cos(a)*r,.06,z-sin(a)*r},mat,mat=='red'and 1 or 1.08)
  face({x+cos(a)*r,.05,z-sin(a)*r},{x+cos(b)*r,.05,z-sin(b)*r},{x+cos(b)*(r+1.2),.05,z-sin(b)*(r+1.2)},{x+cos(a)*(r+1.2),.05,z-sin(a)*(r+1.2)},'dark',.8)
 end
 G.box(x-r,.06,z-1.4,x+r,.1,z+1.4,'dark',.8)
 for i=0,n-1 do local a,b=i*2*pi/n,(i+1)*2*pi/n
  face({x,.12,z},{x+cos(b)*5.5,.12,z-sin(b)*5.5},{x+cos(a)*5.5,.12,z-sin(a)*5.5},{x+cos(a)*5.5,.12,z-sin(a)*5.5},'dark',.8)
  face({x,.16,z},{x+cos(b)*3.5,.16,z-sin(b)*3.5},{x+cos(a)*3.5,.16,z-sin(a)*3.5},{x+cos(a)*3.5,.16,z-sin(a)*3.5},'white',1.15)
 end
end
local function parapet(G,L,cx,cy)
 local box=G.box
 local x0,z0=cx*16,cy*16
 local inner={}
 for _,d in ipairs({{1,0,'e'},{-1,0,'w'},{0,1,'s'},{0,-1,'n'}})do
  local c=at(L,cx+d[1],cy+d[2]);inner[d[3]]=c~='rail'and c~='out'
 end
 box(x0,0,z0,x0+16,8.5,z0+16,'ktSandstone',.95)
 box(x0-.2,8.5,z0-.2,x0+16.2,9.6,z0+16.2,'white',1.06)            -- coping
 -- steel guard rail set on the outer edge of the parapet
 local function rail(ax,az,bx,bz)
  local len=sqrt((bx-ax)^2+(bz-az)^2);local n=max(1,floor(len/4))
  for k=0,n do local t=k/n;local px,pz=ax+(bx-ax)*t,az+(bz-az)*t
   box(px-.25,9.6,pz-.25,px+.25,17,pz+.25,'ktSteel',1.05)
  end
  box(min(ax,bx)-.35,16.6,min(az,bz)-.35,max(ax,bx)+.35,17.3,max(az,bz)+.35,'ktSteel',1.15)
  box(min(ax,bx)-.15,12.8,min(az,bz)-.15,max(ax,bx)+.15,13.2,max(az,bz)+.15,'ktSteel',1.0)
 end
 if cy==0 then rail(x0,z0+2,x0+16,z0+2)end
 if cy==L.ch-1 then rail(x0,z0+14,x0+16,z0+14)end
 if cx==0 then rail(x0+2,z0,x0+2,z0+16)end
 if cx==L.cw-1 then rail(x0+14,z0,x0+14,z0+16)end
 -- flower boxes along the terrace side of the parapet
 if hash(cx,cy)<.45 then
  for side,ok in pairs(inner)do if ok then
   local fx,fz=x0+8,z0+8
   if side=='s'then fz=z0+16.6 elseif side=='n'then fz=z0-.6 elseif side=='e'then fx=x0+16.6 else fx=x0-.6 end
   local hx,hz=(side=='e'or side=='w')and 1.4 or 6,(side=='n'or side=='s')and 1.4 or 6
   box(fx-hx,5.5,fz-hz,fx+hx,7.6,fz+hz,'ktTerracotta',1.0)
   for k=0,4 do local t=(k+.5)/5
    local px=(side=='e'or side=='w')and fx or fx-hx+t*2*hx
    local pz=(side=='n'or side=='s')and fz or fz-hz+t*2*hz
    box(px-.7,7.6,pz-.7,px+.7,8.8,pz+.7,'leaf',1.0)
    box(px-.45,8.6,pz-.45,px+.45,9.3,pz+.45,({'flower','gold','white','flower','red'})[k+1],1.12)
   end
  end end
 end
end
local DRINKS={{'red','white'},{'blue','ktPearl'},{'gold','red'},{'green','gold'}}
local function vending(G,L,cx,cy,index)
 local box,face=G.box,G.face
 local x0,z0=cx*16,cy*16
 -- face toward the walkable side (south by default)
 local dir='s'
 if at(L,cx,cy+1)~='floor'and at(L,cx,cy+1)~='stool'then
  for _,d in ipairs({{0,-1,'n'},{1,0,'e'},{-1,0,'w'}})do
   local c=at(L,cx+d[1],cy+d[2]);if c=='floor'or c=='stool'then dir=d[3];break end
  end
 end
 local col=DRINKS[index%#DRINKS+1]
 -- build facing +z in a local frame, then rotate into place
 local turn=dir=='s'and 0 or dir=='n'and 2 or dir=='e'and -1 or 1
 G.frame(x0+8,z0+8,turn)
 box(-7,0,-6.5,7,26,5.5,col[1],.92)                                 -- cabinet
 box(-7.3,26,-6.8,7.3,27.2,5.8,'dark',.8)
 box(-6,10,5.5,2.5,24,5.7,'dark',.6)                                -- display
 face({-5.5,10.5,5.75},{2,10.5,5.75},{2,23.5,5.75},{-5.5,23.5,5.75},'ktPearl',1.15,true)
 for r=0,2 do for k=0,3 do
  local bx=-4.9+k*1.8;local by=11.5+r*4
  box(bx,by,5.8,bx+1,by+2.8,6.1,DRINKS[(k+r+index)%#DRINKS+1][1],1.2,true)
  box(bx+.25,by+2.8,5.8,bx+.75,by+3.3,6.05,'white',1.2,true)
 end end
 box(3.4,18,5.5,6.2,23.5,5.8,'dark',.7)                              -- buttons
 for k=0,3 do box(3.9,18.6+k*1.2,5.8,5.7,19.4+k*1.2,6.05,k==0 and'green'or col[2],1.2,true)end
 box(4.2,14,5.5,5.4,16.5,6,'ktSteel',1.1)                            -- coin slot
 box(-5.5,3,5.5,5.5,7,6.3,'dark',.55)                                 -- pickup tray
 box(-5,3.4,6.3,5,4,6.5,'ktSteel',1.0)
 box(-7,24,5.5,7,26,5.9,col[2],1.25,true)                           -- header band
 G.frame(0,0,0)
end
local function cafeTable(G,g,palette)
 local box,cyl,face=G.box,G.cyl,G.face
 local x=(g.x0+g.x1+1)*8;local z=(g.y0+g.y1+1)*8
 local r=min(g.x1-g.x0+1,g.y1-g.y0+1)*8-3.5
 cyl(x,0,.6,z,4,4.6,'dark',12,.8)
 cyl(x,.6,9,z,.7,.7,'ktSteel',8,1.0)
 cyl(x,9,10,z,r,r,'white',20,1.06)
 cyl(x,8.6,9,z,r-.4,r-.6,'ktSteel',20,.9)
 -- small things on the table: a menu stand and two cups
 box(x-1,10,z-2.5,x+1,13,z-2.1,'red',1.1)
 for _,o in ipairs({{-3,2},{3.2,1.5}})do cyl(x+o[1],10,11.2,z+o[2],.7,.6,'white',8,1.15)end
 -- striped umbrella
 cyl(x,10,30,z,.35,.35,'ktSteel',6,1.1)
 local R,n=r+9,12
 for i=0,n-1 do local a,b=i*2*pi/n,(i+1)*2*pi/n
  local mat=i%2==0 and palette[1]or palette[2]
  face({x,33,z},{x+cos(a)*R,28,z+sin(a)*R},{x+cos(b)*R,28,z+sin(b)*R},{x+cos(b)*R,28,z+sin(b)*R},mat,1.05)
  face({x+cos(b)*R,28,z+sin(b)*R},{x+cos(a)*R,28,z+sin(a)*R},{x,33,z},{x,33,z},mat,.78)
  -- scalloped valance
  local m=(a+b)/2
  face({x+cos(a)*R,28,z+sin(a)*R},{x+cos(b)*R,28,z+sin(b)*R},{x+cos(m)*R*1.01,26.6,z+sin(m)*R*1.01},{x+cos(m)*R*1.01,26.6,z+sin(m)*R*1.01},mat,.95)
 end
 cyl(x,33,34.2,z,.7,.3,'ktSteel',6,1.1)
end
local function chair(G,L,cx,cy,tables)
 local box=G.box
 local x,z=cx*16+8,cy*16+8
 -- the back faces away from the nearest table
 local best,tx,tz=1e9,x,z
 for _,g in ipairs(tables)do local gx,gz=(g.x0+g.x1+1)*8,(g.y0+g.y1+1)*8
  local d=(gx-x)^2+(gz-z)^2;if d<best then best,tx,tz=d,gx,gz end
 end
 local dx,dz=x-tx,z-tz
 box(x-4.4,4.2,z-4.4,x+4.4,5,z+4.4,'ktSteel',1.05)
 box(x-4,5,z-4,x+4,5.25,z+4,'blue',1.05)
 for _,l in ipairs({{-4,-4},{3.2,-4},{-4,3.2},{3.2,3.2}})do box(x+l[1],0,z+l[2],x+l[1]+.8,4.2,z+l[2]+.8,'ktSteel',.9)end
 if abs(dx)>abs(dz)then
  local bx=dx>0 and x+3.6 or x-4.4
  box(bx,5,z-4.4,bx+.8,12.5,z+4.4,'ktSteel',1.0)
  for k=0,2 do box(bx-.05,6.5+k*2,z-4,bx+.85,7.4+k*2,z+4,'blue',1.05)end
 else
  local bz=dz>0 and z+3.6 or z-4.4
  box(x-4.4,5,bz,x+4.4,12.5,bz+.8,'ktSteel',1.0)
  for k=0,2 do box(x-4,6.5+k*2,bz-.05,x+4,7.4+k*2,bz+.85,'blue',1.05)end
 end
end
local function planter(G,cx,cy,seed)
 local box=G.box
 local x0,z0=cx*16,cy*16
 box(x0+.5,0,z0+.5,x0+15.5,7,z0+15.5,'ktTerracotta',.95)
 box(x0,7,z0,x0+16,8,z0+16,'ktSandstone',1.05)
 box(x0+1.5,7.2,z0+1.5,x0+14.5,7.6,z0+14.5,'wood',.6)                  -- soil
 if seed%3==0 then
  -- a small ornamental tree
  box(x0+7.4,7.6,z0+7.4,x0+8.6,19,z0+8.6,'wood',.9)
  for k=0,5 do local a=k*1.05+seed;local r=2.4+hash(seed,k)*1.6
   box(x0+8+cos(a)*r-3,17+hash(k,seed)*4,z0+8+sin(a)*r-3,x0+8+cos(a)*r+3,22+hash(k,seed)*4,z0+8+sin(a)*r+3,k%2==0 and'leaf'or'green',1.0)
  end
 else
  for k=0,5 do local a=k*1.05+seed;local r=3.5+hash(seed,k)*2
   box(x0+8+cos(a)*r-2,7.6,z0+8+sin(a)*r-2,x0+8+cos(a)*r+2,10.5+hash(k,seed)*2,z0+8+sin(a)*r+2,k%2==0 and'leaf'or'green',1.0)
  end
  flowers(G,x0+8,7.6,z0+8,1.0,seed)
 end
end
local function kiosk(G,L)
 local box=G.box
 for _,g in ipairs(groups(L,'stair'))do
  -- the stair hole and descending steps
  local x0,z0,x1,z1=g.x0*16,g.y0*16,(g.x1+1)*16,(g.y1+1)*16
  for i=0,4 do local z=z0+i*3.2;local h=-(i+1)*3.6
   box(x0+1,h-.5,z,x1-1,h,z+3.2,'ktSandstone',1.0)
  end
  box(x0,-22,z0,x0+1,0,z1,'dark',.5);box(x1-1,-22,z0,x1,0,z1,'dark',.5)
  box(x0,-22,z0,x1,0,z0+.6,'dark',.45)
  -- the kiosk shell covers the stair and its stairhead cells
  local kx0,kx1,kz0,kz1=x0,x1,z0,z1
  for cy=g.y0-1,g.y1+1 do for cx=g.x0-1,g.x1+1 do
   if at(L,cx,cy)=='kiosk'then kx0,kx1=min(kx0,cx*16),max(kx1,(cx+1)*16);kz0,kz1=min(kz0,cy*16),max(kz1,(cy+1)*16)end
  end end
  for cy=floor(kz0/16),floor(kz1/16)-1 do for cx=floor(kx0/16),floor(kx1/16)-1 do
   if at(L,cx,cy)=='kiosk'then
    box(cx*16,0,cy*16,cx*16+16,30,cy*16+16,'ktPlaster',.95)
    box(cx*16+3,10,cy*16+15.9,cx*16+13,24,cy*16+16.2,'glass',1.2,true)
   end
  end end
  box(kx0-1.5,30,kz0-1.5,kx1+1.5,32,kz1+1.5,'slate',.9)    -- roof
  box(kx0-1.8,31.6,kz0-1.8,kx1+1.8,32.4,kz1+1.8,'white',1.05)
  -- door frame over the stair opening, a lamp and a little sign
  box(x0,24,z1-1,x1,30,z1,'ktPlaster',.95)
  box(x0-.6,0,z1-1.2,x0+.6,24,z1+.2,'white',1.08);box(x1-.6,0,z1-1.2,x1+.6,24,z1+.2,'white',1.08)
  box(x0+3,25,z1,x1-3,28.5,z1+.3,'green',1.1)
  box(x0+4.2,26,z1+.3,x1-4.2,27.5,z1+.4,'white',1.25,true)
  box((x0+x1)/2-1,22,z1,(x0+x1)/2+1,23.6,z1+1.4,'gold',1.4,true)
 end
end
-- 3x5 pixel lettering for the rooftop sign.
local FONT={C={'111','100','100','100','111'},E={'111','100','110','100','111'},
 L={'100','100','100','100','111'},A={'010','101','111','101','101'},
 D={'110','101','101','101','110'},O={'111','101','101','101','111'},
 N={'1001','1101','1011','1001','1001'},P={'110','101','110','100','100'},
 T={'111','010','010','010','010'},S={'111','100','111','001','111'},R={'110','101','110','101','101'}}
local function lettering(G,text,x,y,z,s,mat)
 for i=1,#text do local ch=text:sub(i,i)
  local rows=FONT[ch]
  if rows then
   for j,row in ipairs(rows)do for k=1,#row do if row:sub(k,k)=='1'then
    G.box(x+(k-1)*s,y+(5-j)*s,z,x+(k-1)*s+s*.85,y+(5-j)*s+s*.85,z+.3,mat,1.35,true)
   end end end
   x=x+(#rows[1]+1)*s
  else x=x+3*s end
 end
 return x
end
local function textWidth(text,s)
 local w=0;for i=1,#text do local r=FONT[text:sub(i,i)];w=w+((r and #r[1] or 2)+1)*s end
 return w-s
end
local function sign(G,L)
 local W=L.cw*16
 local text='CELADON DEPT STORE';local s=1.25
 local tw=textWidth(text,s);local x0=W/2-tw/2-4;local x1=W/2+tw/2+4
 local z=7
 for _,px in ipairs({x0+3,x1-3})do G.box(px-.5,9.6,z-.5,px+.5,24,z+.5,'ktSteel',1.0)end
 G.box(x0,22,z-.6,x1,33,z+.4,'navy',.9)
 G.box(x0-.5,21.5,z-.8,x1+.5,22.2,z+.6,'gold',1.1);G.box(x0-.5,32.8,z-.8,x1+.5,33.5,z+.6,'gold',1.1)
 lettering(G,text,W/2-tw/2,24.2,z+.4,s,'white')
 -- a little Poke Ball emblem at each end
 for _,ex in ipairs({x0+2.2,x1-2.2})do
  G.disc(ex,27.5,z+.5,1.6,'red',1.3,12,true)
  G.box(ex-1.6,27.3,z+.55,ex+1.6,27.7,z+.7,'dark',.8)
 end
end
local function stringLights(G,L)
 local W,D=L.cw*16,L.ch*16
 local posts={{6,6},{W-6,6},{W-6,D-6},{6,D-6},{W/2,6},{W/2,D-6}}
 for _,p in ipairs(posts)do G.box(p[1]-.6,9.6,p[2]-.6,p[1]+.6,34,p[2]+.6,'ktSteel',1.0)end
 local function strand(a,b,seed)
  local len=sqrt((b[1]-a[1])^2+(b[2]-a[2])^2);local n=max(4,floor(len/7))
  local prev
  for k=0,n do local t=k/n
   local x,z=a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t
   local y=33.4-sin(pi*t)*len*.045
   if prev then
    -- a thin ribbon between the two points (both sides), not a bounding box
    local px,py,pz=prev[1],prev[2],prev[3]
    G.face({px,py,pz},{x,y,z},{x,y-.16,z},{px,py-.16,pz},'dark',.6)
    G.face({px,py-.16,pz},{x,y-.16,z},{x,y,z},{px,py,pz},'dark',.6)
   end
   if k>0 and k<n then
    local c=({'gold','gold','white','flower'})[(k+seed)%4+1]
    G.box(x-.45,y-1.2,z-.45,x+.45,y-.3,z+.45,c,1.45,true)
   end
   prev={x,y,z}
  end
 end
 strand(posts[1],posts[3],0);strand(posts[2],posts[4],1)
 strand(posts[5],posts[6],2);strand(posts[1],posts[2],3);strand(posts[4],posts[3],1)
end
-- The store's upper storeys below the parapet, so the roof is a building top.
local function facade(G,L)
 local W,D=L.cw*16,L.ch*16
 local box=G.box
 local drop=-86
 box(-1,drop,-1,0,0,D+1,'ktPlaster',.8);box(W,drop,-1,W+1,0,D+1,'ktPlaster',.85)
 box(-1,drop,-1,W+1,0,0,'ktPlaster',.75);box(-1,drop,D,W+1,0,D+1,'ktPlaster',.9)
 for y=-20,drop+10,-17 do
  for x=6,W-14,14 do
   box(x,y,D+1,x+9,y+9,D+1.2,'glass',1.15,true)
   box(x,y,-1.2,x+9,y+9,-1,'glass',1.0,true)
  end
  for z=6,D-14,14 do
   box(W+1,y,z,W+1.2,y+9,z+9,'glass',1.05,true)
   box(-1.2,y,z,-1,y+9,z+9,'glass',1.05,true)
  end
  box(-1.3,y-3,-1.3,W+1.3,y-2.4,D+1.3,'white',.95)
 end
end

function M.scene(L)
 local G=builder()
 pavers(G,L)
 mosaic(G,L)
 local tables=groups(L,'table')
 local umbrellas={{'red','white'},{'blue','white'},{'gold','white'},{'green','white'}}
 for i,g in ipairs(tables)do cafeTable(G,g,umbrellas[(i-1)%#umbrellas+1])end
 local vend=0
 for cy=0,L.ch-1 do for cx=0,L.cw-1 do
  local c=at(L,cx,cy)
  if c=='rail'then parapet(G,L,cx,cy)
  elseif c=='vend'then vend=vend+1;vending(G,L,cx,cy,vend)
  elseif c=='stool'then chair(G,L,cx,cy,tables)
  elseif c=='planter'then planter(G,cx,cy,cx*7+cy*13)
  end
 end end
 kiosk(G,L)
 sign(G,L)
 stringLights(G,L)
 facade(G,L)
 return G
end

------------------------------------------------------------------ runtime
local function texture()
 if not white then
  local d=love.image.newImageData(2,2);for y=0,1 do for x=0,1 do d:setPixel(x,y,1,1,1,1)end end
  white=love.graphics.newImage(d);white:setFilter('nearest','nearest');d:release()
 end
 return white
end
local function prepare(map)
 if not M.accepts(map)then return end
 if cached then return cached end
 local R=V.require('Voxel3D')
 local L=M.layout(map)
 local G=M.scene(L)
 local mesh=R.newMesh(G.vs,G.ix);if not mesh then return end
 cached={mesh=mesh,source=L.source}
 if V.mod and V.mod.log and V.mod.log.info then
  pcall(V.mod.log.info,V.mod.log,'Legendary TEST143 Celadon roof: layout from %s',L.source)
 end
 return cached
end
function M.build(S,map)
 if not M.accepts(map)then return end
 for ty=0,map.def.height*4-1 do for tx=0,map.def.width*4-1 do
  local k=key(tx,ty)
  S.skip[k]=true;S.ground[k]=nil
  S.shapeAt[k]={class='ground',h=0,flat=true,art='flat',authored=true}
 end end
 -- Drop the border ring: unclaimed ring cells are not meshed.
 S.hideBareRing=true
 S.celadonRoof=true
end
function M.draw(map,shadow)
 local r=prepare(map);if not r then return end
 local tex=texture()
 if shadow then shadow.draw(r.mesh,tex);return end
 local R=V.require('Voxel3D')
 R.glass(false)
 local ok,err=pcall(function()
  if R.seams then R.seams(false)end
  R.draw(r.mesh,tex)
 end)
 if R.seams then R.seams(true)end
 R.glass(true)
 if not ok then error(err)end
end
function M.invalidate()
 if cached then cached.mesh:release();cached=nil end
end
function M.setLive(live)if not(live and live.CELADON_MART_ROOF)then M.invalidate()end end
return M
