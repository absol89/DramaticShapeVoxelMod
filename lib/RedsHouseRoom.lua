-- TEST137: Red's house ground floor, rebuilt as one authored room in the
-- spirit of the cosy anime family home: pale butter-yellow walls over honey
-- wainscot, lace-curtained windows, a working kitchen where the source has
-- its bookcases, a wood-cabinet CRT, a dining table with spindle chairs, a
-- white-railed staircase and a pendant lamp.
--
-- The ROM map still owns collision, warps, Mom and the TV text. Furniture is
-- placed on the source furniture cells, read from the live tile grid at load
-- (tileset REDS_HOUSE_1 classes from data/voxel_heights), so every piece sits
-- exactly where the game blocks movement. Chair seats keep the pinned stool
-- height (5) so Mom still sits on her chair. A fixed pokered layout is the
-- fallback when the tile grid cannot be read.
local V=...
local M={REVISION='reds-house-room-143'}
local RM=V.require('ReferenceMaterials')
local pi,cos,sin,floor,min,max,abs=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs
local cached,white
local W,D,WALL,NORTH=128,128,48,2
local SEAT=5        -- data/voxel_heights REDS_HOUSE_1 stool pin
local TOP=9.6       -- dining table top
M.W,M.D,M.WALL,M.NORTH=W,D,WALL,NORTH
local function key(x,y)return (y+64)*4096+x+64 end

function M.accepts(map)
 return map and map.id=='REDS_HOUSE_1F' and map.def and map.def.width==4
   and map.def.height==4 or false
end

------------------------------------------------------------------ layout
local CLASS={}
for cls,tiles in pairs({
 tv={6,7,22,23}, stair={12,13,28,29}, shelf={34,35,48,49,50,51},
 table={38,39,40,41,42,43,44,54,55,56,57,58,59,60},
 stool={2,3,18,19}, mat={4,20},
})do for _,t in ipairs(tiles)do CLASS[t]=cls end end
local RANK={stair=6,tv=5,shelf=4,table=3,stool=2,mat=1}
local CELLS=8
-- pokered RedsHouse1F as a fallback.
local FALLBACK={
 shelf={{0,0},{1,0}}, tv={{3,1}}, stair={{7,1}},
 table={{3,4},{4,4},{3,5},{4,5}}, stool={{2,4},{2,5},{5,4},{5,5}},
 mat={{2,7},{3,7}},
}
function M.layout(map)
 local out={shelf={},tv={},stair={},table={},stool={},mat={}}
 local read=0
 if map and map.tileAt then
  for cy=0,CELLS-1 do for cx=0,CELLS-1 do
   local best
   for j=0,1 do for i=0,1 do
    local ok,t=pcall(map.tileAt,map,cx*2+i,cy*2+j)
    if ok and t then read=read+1
     local c=CLASS[t]
     if c and(not best or RANK[c]>RANK[best])then best=c end
    end
   end end
   if best then local l=out[best];l[#l+1]={cx,cy}end
  end end
 end
 if read<CELLS*CELLS*4 or #out.table==0 then out=FALLBACK;out.source='fallback'
 else out.source='tiles' end
 -- Which cells the engine blocks, so furniture never reaches walkable floor.
 out.blocked={}
 if map and map.isWalkableCell then
  for cy=0,CELLS-1 do for cx=0,CELLS-1 do
   local ok,w=pcall(map.isWalkableCell,map,cx,cy)
   if ok then out.blocked[cy*CELLS+cx]=not w end
  end end
 end
 return out
end
local function bounds(list)
 if not list or #list==0 then return nil end
 local x0,z0,x1,z1=math.huge,math.huge,-math.huge,-math.huge
 for _,c in ipairs(list)do x0=min(x0,c[1]);x1=max(x1,c[1]);z0=min(z0,c[2]);z1=max(z1,c[2])end
 return {x0=x0*16,x1=(x1+1)*16,z0=z0*16,z1=(z1+1)*16,cx0=x0,cx1=x1,cz0=z0,cz1=z1}
end
-- Group cells into contiguous horizontal runs (kitchen units).
local function runs(list)
 local rows={}
 for _,c in ipairs(list)do rows[c[1]]=max(rows[c[1]] or -1,c[2])end
 local xs={};for x in pairs(rows)do xs[#xs+1]=x end;table.sort(xs)
 local out,cur={},nil
 for _,x in ipairs(xs)do
  if cur and x==cur.cx1+1 then cur.cx1=x;cur.rz=max(cur.rz,rows[x])
  else cur={cx0=x,cx1=x,rz=rows[x]};out[#out+1]=cur end
 end
 return out
end

------------------------------------------------------------------ builder
local function builder()
 local G={vs={},ix={},windows={}}
 local ox,oz,turn=0,0,0
 function G.frame(x,z,t)ox,oz,turn=x,z,t end
 local function point(p)
  if turn==1 then return ox+p[3],p[2],oz-p[1]end
  if turn==-1 then return ox-p[3],p[2],oz+p[1]end
  if turn==2 then return ox-p[1],p[2],oz-p[3]end
  return ox+p[1],p[2],oz+p[3]
 end
 -- Export the very same aperture transform used by the room mesh. The
 -- scenic image sits ahead of the glass (.95), behind the mullions (1.3).
 function G.window(a,b,lo,hi)
  local corners={}
  for _,p in ipairs({{a,lo,1.02},{b,lo,1.02},{b,hi,1.02},{a,hi,1.02}})do
   corners[#corners+1]={point(p)}
  end
  G.windows[#G.windows+1]={corners=corners,yaw=turn==-1 and math.pi/2 or turn==1 and -math.pi/2 or turn==2 and math.pi or 0}
 end
 function G.face(a,b,c,d,mat,tone,glow)
  local shade=RM.encode(mat,(tone or 1)+(glow and 64 or 0))
  local n=#G.vs
  for _,p in ipairs({a,b,c,d})do local x,y,z=point(p);G.vs[n+1]={x,y,z,.5,.5,shade};n=n+1 end
  local i=#G.ix;local s=n-4
  G.ix[i+1],G.ix[i+2],G.ix[i+3],G.ix[i+4],G.ix[i+5],G.ix[i+6]=s+1,s+2,s+3,s+1,s+3,s+4
 end
 local face=G.face
 function G.box(x0,y0,z0,x1,y1,z1,mat,t,glow)
  if x1-x0<.001 or y1-y0<.001 or z1-z0<.001 then return end;t=t or 1
  face({x0,y1,z0},{x0,y1,z1},{x1,y1,z1},{x1,y1,z0},mat,t,glow)
  face({x0,y0,z1},{x1,y0,z1},{x1,y1,z1},{x0,y1,z1},mat,t*.94,glow)
  face({x1,y0,z0},{x0,y0,z0},{x0,y1,z0},{x1,y1,z0},mat,t*.80,glow)
  face({x0,y0,z0},{x0,y0,z1},{x0,y1,z1},{x0,y1,z0},mat,t*.85,glow)
  face({x1,y0,z1},{x1,y0,z0},{x1,y1,z0},{x1,y1,z1},mat,t*.90,glow)
  face({x0,y0,z0},{x1,y0,z0},{x1,y0,z1},{x0,y0,z1},mat,t*.65,glow)
 end
 function G.cyl(x,y0,y1,z,r0,r1,mat,n,t,glow)
  n=n or 12;r1=r1 or r0
  for i=0,n-1 do local a,b=i*2*pi/n,(i+1)*2*pi/n
   face({x+r0*cos(a),y0,z+r0*sin(a)},{x+r0*cos(b),y0,z+r0*sin(b)},{x+r1*cos(b),y1,z+r1*sin(b)},{x+r1*cos(a),y1,z+r1*sin(a)},mat,(t or 1)*(.84+.14*cos(a-.7)),glow)
   face({x,y1,z},{x+r1*cos(b),y1,z+r1*sin(b)},{x+r1*cos(a),y1,z+r1*sin(a)},{x+r1*cos(a),y1,z+r1*sin(a)},mat,(t or 1)*1.04,glow)
  end
 end
 -- A flat disc facing +z (clock faces, plates on the wall).
 function G.disc(x,y,z,r,mat,t,n,glow)
  n=n or 16
  for i=0,n-1 do local a,b=i*2*pi/n,(i+1)*2*pi/n
   face({x,y,z},{x+r*cos(b),y+r*sin(b),z},{x+r*cos(a),y+r*sin(a),z},{x+r*cos(a),y+r*sin(a),z},mat,t or 1,glow)
  end
 end
 return G
end
local function hash(a,b)local h=(a*73856093+b*19349663)%2147483647;h=(h*48271)%2147483647;return h/2147483647 end

------------------------------------------------------------------ pieces
local function flowers(G,x,y,z,s,seed)
 local box,cyl=G.box,G.cyl
 for i=0,6 do
  local a=i*2.4+seed;local r=(1.0+hash(seed,i)*1.4)*s;local h=(4+hash(i,seed)*3.2)*s
  local fx,fz=x+cos(a)*r,z+sin(a)*r
  box(x+(fx-x)*.4-.12,y,z+(fz-z)*.4-.12,x+(fx-x)*.4+.12,y+h,z+(fz-z)*.4+.12,'leaf',.95)
  local col=({'flower','gold','white','flower','red'})[i%5+1]
  box(fx-.75*s,y+h-.2,fz-.75*s,fx+.75*s,y+h+.9*s,fz+.75*s,col,1.12)
  box(fx-.35*s,y+h+.9*s,fz-.35*s,fx+.35*s,y+h+1.05*s,fz+.35*s,'gold',1.2)
 end
 for i=0,4 do local a=i*1.26+seed*.5
  box(x+cos(a)*1.4*s-.5,y+1.2*s,z+sin(a)*1.4*s-.5,x+cos(a)*1.4*s+.5,y+1.8*s,z+sin(a)*1.4*s+.5,'leaf',.9)
 end
end
local function pottedPlant(G,x,y0,z,s,seed)
 G.cyl(x,y0,y0+3.2*s,z,1.7*s,2.1*s,'terra',10,.95)
 G.cyl(x,y0+3.2*s,y0+3.6*s,z,2.25*s,2.25*s,'terra',10,1.05)
 G.cyl(x,y0+3.5*s,y0+3.62*s,z,1.9*s,1.9*s,'wood',10,.6)
 for i=0,9 do local a=i*2*pi/10+hash(seed,i);local r=(2.2+hash(i,seed)*1.8)*s
  local hh=y0+(5.2+hash(seed+i,3)*4.5)*s
  local base={x,y0+3.6*s,z};local tip={x+cos(a)*r,hh,z+sin(a)*r}
  local mid={(base[1]+tip[1])/2,hh+.9*s,(base[3]+tip[3])/2}
  local px,pz=-sin(a)*.8*s,cos(a)*.8*s
  G.face(base,{mid[1]+px,mid[2],mid[3]+pz},tip,tip,i%2==0 and'leaf'or'green',1.05)
  G.face(base,tip,{mid[1]-px,mid[2]-.2,mid[3]-pz},{mid[1]-px,mid[2]-.2,mid[3]-pz},i%2==0 and'green'or'leaf',.85)
 end
end

-- Kitchen on the source bookcase run: fridge, base cabinets, sink, two-ring
-- stove with a pot, tiled splash and wall cabinets.
local function kitchen(G,x0,x1,zF)
 local box,face,cyl=G.box,G.face,G.cyl
 local z0=NORTH
 local fridge=x1-x0>=30
 local cx0=x0
 if fridge then
  local fx0,fx1=x0+.6,x0+15.2
  box(fx0,0,z0,fx1,33,zF-.4,'white',1.06)
  box(fx0+.4,24.2,zF-.4,fx1-.4,32.6,zF-.1,'white',1.1)             -- freezer door
  box(fx0+.4,.6,zF-.4,fx1-.4,23.6,zF-.1,'white',1.08)              -- fridge door
  box(fx1-2.6,26,zF-.1,fx1-1.8,31,zF+.6,'ktSteel',1.1)
  box(fx1-2.6,13,zF-.1,fx1-1.8,22,zF+.6,'ktSteel',1.1)
  -- magnets, a drawing and a list
  box(fx0+2,16,zF-.1,fx0+7,21.5,zF,'cream',1.15)
  for i=0,3 do box(fx0+2.6,17+i*1.1,zF,fx0+6.2-hash(i,7)*2,17.4+i*1.1,zF+.05,'blue',1)end
  box(fx0+8,9,zF-.1,fx0+12,13,zF,'white',1.2)
  box(fx0+8.4,9.6,zF,fx0+11.6,11.4,zF+.05,'sage',1.1);box(fx0+9.4,11.2,zF,fx0+10.6,12.4,zF+.05,'gold',1.2)
  for i,c in ipairs({'red','gold','blue'})do box(fx0+2+i*2.5,27.5,zF-.1,fx0+3.2+i*2.5,28.7,zF+.25,c,1.1)end
  pottedPlant(G,(fx0+fx1)/2,33,(z0+zF)/2,.7,3)
  cx0=x0+16
 end
 if x1-cx0<8 then return end
 local T=12
 box(cx0,0,z0,x1-.4,T-1,zF-1,'oak',.9)                               -- base cabinets
 box(cx0,0,zF-1.6,x1-.4,1.2,zF-1,'wood',.7)                          -- toe kick
 local doors=max(1,floor((x1-cx0)/8+.5));local dw=(x1-.4-cx0)/doors
 for i=0,doors-1 do local a=cx0+i*dw
  box(a+.5,1.8,zF-1,a+dw-.5,T-1.6,zF-.6,'oak',1.04)
  box(a+.9,2.2,zF-.6,a+dw-.9,T-2,zF-.45,'oak',.92)
  box(a+dw/2-.4,T-3.4,zF-.45,a+dw/2+.4,T-2.6,zF,'gold',1.15)
 end
 box(cx0-.2,T-1,z0,x1-.1,T+.2,zF,'ktPearl',1.08)                    -- counter
 -- tiled splash on the wall
 for x=cx0,x1-1.6,2 do for y=T+.2,T+9,2 do
  face({x,y,z0+.15},{x+1.9,y,z0+.15},{x+1.9,y+1.9,z0+.15},{x,y+1.9,z0+.15},
   (floor(x/2)+floor(y/2))%2==0 and'white'or'ktPearl',1.08)
 end end
 local mid=(cx0+x1)/2
 -- sink (left half) and stove (right half)
 local sx=cx0+(x1-cx0)*.28
 box(sx-4,T+.2,z0+4,sx+4,T+.32,zF-3,'ktSteel',1.1)
 box(sx-3.4,T+.32,z0+4.6,sx+3.4,T+.36,zF-3.6,'dark',.75)
 box(sx-.5,T+.2,z0+1.2,sx+.5,T+4.2,z0+2.2,'ktSteel',1.15)
 box(sx-.5,T+3.4,z0+2.2,sx+.5,T+4.2,z0+5,'ktSteel',1.15)
 local st=cx0+(x1-cx0)*.72
 box(st-4.2,T+.2,z0+3,st+4.2,T+.6,zF-2.2,'dark',.8)
 for _,bx in ipairs({st-2.2,st+2.2})do cyl(bx,T+.6,T+.75,(z0+zF)/2,1.5,1.5,'slate',12,.9)end
 cyl(st-2.2,T+.75,T+4,(z0+zF)/2,1.8,1.8,'red',12,1.0)                -- pot
 cyl(st-2.2,T+4,T+4.4,(z0+zF)/2,1.95,1.6,'red',12,1.1)
 box(st-2.6,T+4.4,(z0+zF)/2-.3,st-1.8,T+5,(z0+zF)/2+.3,'dark',.9)
 cyl(st+2.2,T+.75,T+3.2,(z0+zF)/2,1.3,1.0,'ktPearl',10,1.1)           -- kettle
 box(st+3.2,T+2,(z0+zF)/2-.2,st+4.4,T+2.5,(z0+zF)/2+.2,'ktPearl',1.1)
 for k=0,3 do box(st-3.4+k*2.2,T-.6,zF-.15,st-2.4+k*2.2,T+.1,zF+.3,'ktSteel',1.1)end -- knobs
 -- wall cabinets and range hood
 box(cx0,24,z0,x1-.4,33,z0+6.5,'oak',.96)
 for i=0,doors-1 do local a=cx0+i*dw
  box(a+.5,24.5,z0+6.5,a+dw-.5,32.5,z0+6.8,'oak',1.05)
  box(a+dw/2-.4,25.2,z0+6.8,a+dw/2+.4,26,z0+7.2,'gold',1.15)
 end
 box(st-5,21,z0,st+5,24,z0+7.4,'ktSteel',1.0)
 box(st-4.4,20.6,z0+1,st+4.4,21,z0+7,'dark',.7)
 -- jars and a plant on the counter end
 for i,c in ipairs({'cream','gold','sage'})do
  cyl(mid-1+i*1.9,T+.2,T+2.6+i*.3,z0+2.4,.75,.75,'glass',8,1.1)
  cyl(mid-1+i*1.9,T+2.6+i*.3,T+3+i*.3,z0+2.4,.8,.8,c,8,1.1)
 end
 -- dish towel over the oven door
 box(st-1.2,4,zF-.45,st+1.2,T-2.2,zF-.15,'white',1.15)
 box(st-1.2,5.2,zF-.15,st+1.2,5.8,zF-.1,'red',1.1)
end

-- A wood-cabinet CRT on a low stand, with rabbit ears and a VCR.
local function television(G,b)
 local box,face=G.box,G.face
 local x0,x1=b.x0+.8,b.x1-.8
 local zF=b.z1-2
 box(x0,0,NORTH+.5,x1,6.5,zF,'oak',.95)                             -- stand
 box(x0+.6,1,zF,x1-.6,5.8,zF+.2,'wood',.8)
 box(x0+1.2,3.6,zF+.2,x1-1.2,5.4,zF+.4,'dark',.8)                   -- VCR
 box(x0+2,4.3,zF+.4,x0+7,4.6,zF+.5,'slate',1.1)
 box(x1-3,4.3,zF+.4,x1-2.4,4.6,zF+.55,'red',1.2,true)
 local cx=(x0+x1)/2
 box(x0+.4,6.5,NORTH+3,x1-.4,18.5,zF-1,'ktCedar',.95)                -- cabinet
 box(x0+.4,6.5,zF-1,x1-.4,18.5,zF-.4,'ktCedar',1.0)
 box(x0+1.2,7.6,zF-.4,x1-4,17.4,zF-.2,'dark',.6)                    -- bezel
 face({x0+1.9,8.3,zF-.15},{x1-4.7,8.3,zF-.15},{x1-4.7,16.7,zF-.15},{x0+1.9,16.7,zF-.15},'ktMarine',1.15,true)
 face({x0+2.4,13.6,zF-.12},{x1-6.6,13.6,zF-.12},{x1-6.6,15.8,zF-.12},{x0+2.4,15.8,zF-.12},'ktPearl',1.2,true)
 for i=0,2 do box(x1-3.2,9+i*2.4,zF-.4,x1-1.6,10.4+i*2.4,zF+.2,i==0 and'gold'or'slate',1.05)end
 for i=0,4 do box(x1-3.4,15.6-i*.6,zF-.25,x1-1.4,15.8-i*.6,zF-.15,'dark',.7)end
 -- rabbit ears
 box(cx-1.4,18.5,NORTH+8,cx+1.4,19.4,NORTH+11,'dark',.8)
 for _,s in ipairs({-1,1})do
  local bx,bz=cx+s*.6,NORTH+9.5
  for k=0,7 do local t=k/8
   box(bx+s*t*5-.18,19.4+t*9,bz-.18,bx+s*t*5+.18,19.4+(t+.14)*9,bz+.18,'ktSteel',1.15)
  end
 end
end

-- Dining table and its chairs. Chair backs face away from the table.
local function dining(G,tb,stools)
 local box,cyl=G.box,G.cyl
 local x0,x1,z0,z1=tb.x0+1,tb.x1-1,tb.z0+1,tb.z1-1
 box(x0-.6,TOP-.9,z0-.6,x1+.6,TOP,z1+.6,'oak',1.04)
 box(x0+.6,TOP-2.6,z0+.6,x1-.6,TOP-.9,z1-.6,'oak',.86)               -- apron
 for _,lx in ipairs({x0+.9,x1-2.5})do for _,lz in ipairs({z0+.9,z1-2.5})do
  box(lx,0,lz,lx+1.6,TOP-.9,lz+1.6,'oak',.9)
  box(lx-.1,0,lz-.1,lx+1.7,.5,lz+1.7,'wood',.8)
 end end
 -- lace runner, placemats, vase of flowers and a fruit bowl
 local cx,cz=(x0+x1)/2,(z0+z1)/2
 box(x0+2,TOP,cz-3.2,x1-2,TOP+.06,cz+3.2,'white',1.18)
 for x=x0+2.5,x1-3,2 do box(x,TOP+.06,cz-3.6,x+1,TOP+.08,cz-3.2,'white',1.1);box(x,TOP+.06,cz+3.2,x+1,TOP+.08,cz+3.6,'white',1.1)end
 cyl(cx-4,TOP+.06,TOP+3.4,cz,1.2,.75,'ktPearl',10,1.12)
 cyl(cx-4,TOP+3.4,TOP+4,cz,.75,1.0,'ktPearl',10,1.15)
 flowers(G,cx-4,TOP+3.6,cz,.7,5)
 cyl(cx+5,TOP+.06,TOP+1.4,cz,1.4,2.6,'white',12,1.1)
 for i,c in ipairs({'red','gold','red','leaf','gold'})do
  local a=i*1.3;local fx,fz=cx+5+cos(a)*1.2,cz+sin(a)*1.2
  box(fx-.8,TOP+1.1,fz-.8,fx+.8,TOP+2.5,fz+.8,c,1.1)
 end
 for _,c in ipairs(stools)do
  local sx0,sz0=c[1]*16,c[2]*16
  local ccx,ccz=sx0+8,sz0+8
  local dx,dz=ccx-(tb.x0+tb.x1)/2,ccz-(tb.z0+tb.z1)/2
  local ax=abs(dx)*(tb.z1-tb.z0)>=abs(dz)*(tb.x1-tb.x0)
  local a0,a1,b0,b1=ccx-5.2,ccx+5.2,ccz-5.2,ccz+5.2
  box(a0,SEAT-.9,b0,a1,SEAT-.25,b1,'oak',1.0)                       -- seat
  box(a0+.3,SEAT-.25,b0+.3,a1-.3,SEAT,b1-.3,'red',1.05)              -- cushion
  for _,lx in ipairs({a0+.3,a1-1.5})do for _,lz in ipairs({b0+.3,b1-1.5})do
   box(lx,0,lz,lx+1.2,SEAT-.9,lz+1.2,'oak',.9)
  end end
  -- spindle back on the side away from the table
  local h=SEAT+10
  if ax then
   local bx=dx>0 and a1-1.2 or a0
   box(bx,SEAT-.9,b0,bx+1.2,h,b0+1.2,'oak',.95);box(bx,SEAT-.9,b1-1.2,bx+1.2,h,b1,'oak',.95)
   box(bx-.1,h-2.4,b0,bx+1.3,h,b1,'oak',1.05)
   for k=1,3 do local z=b0+k*(b1-b0)/4;box(bx+.3,SEAT,z-.35,bx+.9,h-2.4,z+.35,'oak',1.0)end
  else
   local bz=dz>0 and b1-1.2 or b0
   box(a0,SEAT-.9,bz,a0+1.2,h,bz+1.2,'oak',.95);box(a1-1.2,SEAT-.9,bz,a1,h,bz+1.2,'oak',.95)
   box(a0,h-2.4,bz-.1,a1,h,bz+1.3,'oak',1.05)
   for k=1,3 do local x=a0+k*(a1-a0)/4;box(x-.35,SEAT,bz+.3,x+.35,h-2.4,bz+.9,'oak',1.0)end
  end
 end
end

-- Stairs climbing east, white risers, honey treads, white spindle railing.
local function stairs(G,b)
 local box,face=G.box,G.face
 local x0,x1,z0,z1=b.x0,b.x1,max(b.z0,NORTH),b.z1-.4
 local n=6;local run=(x1-x0)/n;local rise=3.6
 for i=0,n-1 do
  local a=x0+i*run;local h=(i+1)*rise
  box(a,0,z0,x1,h-.5,z1,'white',1.02)
  box(a-.4,h-.5,z0,a+run,h,z1+.3,'oak',1.06)
 end
 -- stair stringer along the open side and the railing above it
 local zr=z1+.3
 for i=0,n-1 do local a=x0+i*run
  box(a+run*.5-.3,(i+1)*rise,zr-.6,a+run*.5+.3,(i+1)*rise+10,zr,'white',1.1)
 end
 local function rail(y0,y1,th)
  face({x0,y0,zr-.8},{x1,y1,zr-.8},{x1,y1+th,zr-.8},{x0,y0+th,zr-.8},'oak',.9)
  face({x0,y0+th,zr+.2},{x1,y1+th,zr+.2},{x1,y1,zr+.2},{x0,y0,zr+.2},'oak',1.0)
  face({x0,y0+th,zr-.8},{x1,y1+th,zr-.8},{x1,y1+th,zr+.2},{x0,y0+th,zr+.2},'oak',1.12)
 end
 rail(rise+10,n*rise+10,1.2)
 box(x0-1.6,0,zr-1.4,x0+.6,rise+12,zr+.8,'oak',1.0)                  -- newel
 box(x0-2,rise+12,zr-1.8,x0+1,rise+13,zr+1.2,'oak',1.1)
 -- the flight continues up through the east wall
 face({W-.25,n*rise,z0},{W-.25,n*rise,z1},{W-.25,WALL-2,z1},{W-.25,WALL-2,z0},'dark',.6)
 box(W-2,n*rise-.5,z0,W-.2,n*rise,z1,'oak',1.0)
end

local function rugs(G,L)
 local box=G.box
 local tb=bounds(L.table)
 if tb then
  local x0,x1,z0,z1=tb.x0-14,tb.x1+14,tb.z0-10,tb.z1+10
  x0,x1,z0,z1=max(x0,2),min(x1,W-2),max(z0,NORTH+24),min(z1,D-18)
  box(x0,.02,z0,x1,.14,z1,'sage',.95)
  box(x0+1.2,.14,z0+1.2,x1-1.2,.18,z1-1.2,'cream',1.0)
  box(x0+2.6,.18,z0+2.6,x1-2.6,.22,z1-2.6,'sage',1.02)
  for x=x0+4,x1-5,4 do box(x,.22,z0+3.4,x+2,.24,z0+4.2,'terra',1.05);box(x,.22,z1-4.2,x+2,.24,z1-3.4,'terra',1.05)end
 end
 local tv=bounds(L.tv)
 if tv then
  local cx=(tv.x0+tv.x1)/2
  local x0,x1,z0,z1=max(2,cx-18),min(W-2,cx+18),tv.z1+3,tv.z1+19
  box(x0,.02,z0,x1,.12,z1,'terra',.95)
  box(x0+1,.12,z0+1,x1-1,.16,z1-1,'red',1.0)
  for z=z0+3,z1-3,3 do box(x0+2.5,.16,z,x1-2.5,.18,z+.8,'cream',1.05)end
 end
 local mb=bounds(L.mat)
 if mb then
  box(mb.x0+2,0,mb.z0+3,mb.x1-2,.35,D-1,'red',.9)
  box(mb.x0+4,.35,mb.z0+5,mb.x1-4,.4,D-3,'terra',.95)
 end
end

-- Furniture, floor and fixtures that never cut away.
function M.room(L)
 local G=builder();local face=G.face
 -- Honey plank floor, staggered.
 for z=NORTH,D-.01,4 do
  local off=(floor(z/4)%3)*9;local endZ=min(D,z+4)
  for x=-off,W-.01,26 do local a=max(0,x);local b=min(W,x+26)
   if b>a then face({a,0,z},{a,0,endZ},{b,0,endZ},{b,0,z},'oak',.98+hash(floor(x),floor(z))*.10)end
  end
 end
 rugs(G,L)
 for _,r in ipairs(runs(L.shelf))do
  -- Reach into the next row only where the engine blocks every cell.
  local deeper=true
  for cx=r.cx0,r.cx1 do if not L.blocked[(r.rz+1)*CELLS+cx] then deeper=false end end
  kitchen(G,r.cx0*16,(r.cx1+1)*16,deeper and (r.rz+2)*16-1 or (r.rz+1)*16-.5)
 end
 local tv=bounds(L.tv);if tv then television(G,tv)end
 local tb=bounds(L.table);if tb then dining(G,tb,L.stool)end
 local st=bounds(L.stair);if st then stairs(G,st)end
 -- Pendant lamp over the table.
 if tb then
  local cx,cz=(tb.x0+tb.x1)/2,(tb.z0+tb.z1)/2
  G.box(cx-.15,43,cz-.15,cx+.15,WALL,cz+.15,'dark',.8)
  G.cyl(cx,40.5,43,cz,4.6,1.1,'cream',16,1.1)
  G.cyl(cx,39.8,40.6,cz,1.2,1.2,'gold',10,1.4,true)
 end
 return G
end

------------------------------------------------------------------ shell
local function wallSpan(G,left,right,opts)
 opts=opts or {}
 local box,face=G.box,G.face
 local base=opts.base or 0
 local paint,panel=opts.paint or'cream',opts.panel or'oak'
 box(left,base,-2,right,WALL,0,paint,.97)
 if base==0 then
  box(left,0,0,right,14,.6,panel,.9)                                -- wainscot
  for x=left+2,right-4,6 do box(x,1.6,.6,x+.4,13,.66,panel,.78)end  -- beadboard
  box(left,14,0,right,15,1.0,'white',1.08)                          -- chair rail
  box(left,0,0,right,1.4,1.0,'wood',.8)                             -- skirting
 end
 box(left,WALL-2.4,0,right,WALL-1.2,1.2,'white',1.08)               -- cornice
 box(left,WALL-1.2,0,right,WALL,2.0,'white',1.12)
 for _,w in ipairs(opts.windows or{})do
  local a,b,lo,hi=w[1],w[2],w[3] or 19,w[4] or 37
  G.window(a,b,lo,hi)
  box(a-1.2,lo-1.2,-.2,b+1.2,hi+1.2,.9,'white',1.08)
  box(a-1.8,lo-1.8,-.2,b+1.8,lo-1,2.6,'white',1.12)                 -- sill
  face({a,lo,.95},{b,lo,.95},{b,hi,.95},{a,hi,.95},'glass',1.25,true)
  local mid=(a+b)/2
  box(mid-.35,lo,.95,mid+.35,hi,1.3,'white',1.05)
  box(a,(lo+hi)/2-.3,.95,b,(lo+hi)/2+.3,1.3,'white',1.05)
  -- lace curtains gathered at each side, and a frilled valance
  local cur=w.curtain or opts.curtain or'white'
  box(a-3,hi+2,1.6,b+3,hi+2.5,2.1,cur,1.0)
  for s=0,1 do
   local c0=s==0 and a-3.2 or b-2.4;local c1=s==0 and a+2.4 or b+3.2
   for k=0,4 do local x=c0+k*(c1-c0)/5
    box(x,lo-3.5,1.7+(k%2)*.5,x+(c1-c0)/5+.1,hi+2,2.3+(k%2)*.5,cur,1.08+(k%2)*.07)
   end
   box(c0-.2,lo+4,2.6,c1+.2,lo+5,3.3,'flower',1.05)                 -- tie-back
  end
  for x=a-2.8,b+2.4,1.6 do box(x,hi-.6+(floor(x)%2)*.3,2.3,x+1.4,hi+2.2,3.0,cur,1.12)end
  if w.pot then pottedPlant(G,mid,lo-1,2.6,.55,floor(a))end
 end
 for _,p in ipairs(opts.pictures or{})do
  local a,b,lo,hi,mat=p[1],p[2],p[3],p[4],p[5]
  box(a-.7,lo-.7,0,b+.7,hi+.7,.6,p.frame or'wood',.95)
  face({a,lo,.65},{b,lo,.65},{b,hi,.65},{a,hi,.65},mat or'cream',1.1)
  if p.scene=='family'then
   -- a sunny photo: sky, hills, three figures
   face({a,lo+(hi-lo)*.45,.7},{b,lo+(hi-lo)*.45,.7},{b,hi,.7},{a,hi,.7},'blue',1.25)
   face({a,lo,.7},{b,lo,.7},{b,lo+(hi-lo)*.45,.7},{a,lo+(hi-lo)*.45,.7},'leaf',1.1)
   for i,c in ipairs({'red','gold','navy'})do local x=a+(b-a)*(i/4)
    box(x-.6,lo+1,.7,x+.6,lo+(hi-lo)*.55,.8,c,1.1);box(x-.45,lo+(hi-lo)*.55,.7,x+.45,lo+(hi-lo)*.68,.8,'cream',1.15)end
  elseif p.scene=='sea'then
   face({a,lo+(hi-lo)*.5,.7},{b,lo+(hi-lo)*.5,.7},{b,hi,.7},{a,hi,.7},'ktPearl',1.2)
   face({a,lo,.7},{b,lo,.7},{b,lo+(hi-lo)*.5,.7},{a,lo+(hi-lo)*.5,.7},'ktMarine',1.1)
   box(a+(b-a)*.6,lo+(hi-lo)*.5,.7,a+(b-a)*.72,lo+(hi-lo)*.8,.8,'white',1.2)
  elseif p.scene=='flowers'then
   face({a,lo,.7},{b,lo,.7},{b,hi,.7},{a,hi,.7},'cream',1.12)
   for i=0,4 do local x=a+1+i*(b-a-2)/5;box(x,lo+1,.7,x+.25,lo+(hi-lo)*.6,.75,'leaf',1)
    box(x-.7,lo+(hi-lo)*.6,.7,x+.9,lo+(hi-lo)*.6+1.4,.8,i%2==0 and'flower'or'gold',1.15)end
  end
 end
 for _,c in ipairs(opts.clocks or{})do
  local x,y,r=c[1],c[2],c[3]
  G.disc(x,y,.6,r+.6,'oak',1.0,20);G.disc(x,y,.8,r,'white',1.18,20)
  for i=0,11 do local a=i*pi/6;box(x+cos(a)*r*.82-.15,y+sin(a)*r*.82-.15,.82,x+cos(a)*r*.82+.15,y+sin(a)*r*.82+.15,.9,'dark',.8)end
  box(x-.15,y,.9,x+.15,y+r*.55,1.0,'dark',.8);box(x,y-.15,.9,x+r*.72,y+.15,1.0,'dark',.8)
  box(x-.3,y-.3,1.0,x+.3,y+.3,1.1,'red',1.1)
 end
 for _,c in ipairs(opts.calendars or{})do
  local a,b,lo,hi=c[1],c[2],c[3],c[4]
  box(a,lo,0,b,hi,.35,'white',1.15)
  box(a,hi-(hi-lo)*.42,.35,b,hi,.45,'flower',1.1)
  box(a+(b-a)*.3,hi-(hi-lo)*.36,.45,a+(b-a)*.7,hi-(hi-lo)*.08,.5,'gold',1.15)
  for r=0,3 do for k=0,4 do local x=a+.6+k*(b-a-1.2)/5;local y=lo+.6+r*1.3
   box(x,y,.35,x+(b-a-1.2)/5-.25,y+.8,.4,(r==1 and k==2)and'red'or'ktPearl',1.0)end end
 end
 for _,h in ipairs(opts.hooks or{})do
  local a,b,y=h[1],h[2],h[3]
  box(a,y,0,b,y+1.6,.7,'oak',1.0)
  local n=3
  for i=0,n-1 do local x=a+1.6+i*(b-a-3.2)/(n-1)
   box(x-.3,y+.4,.7,x+.3,y+.9,2.2,'gold',1.15)
  end
  -- a jacket and a bag hanging from the pegs
  box(a+.6,y-11,.9,a+3.6,y+.6,2.6,'navy',1.0)
  box(a+.9,y-9.5,2.6,a+3.3,y-.4,2.7,'blue',1.05)
  box(b-4,y-6,1.0,b-1.4,y+.4,3.0,'sage',1.0)
  box(b-3.2,y-1,1.0,b-2.2,y+.8,1.4,'wood',.9)
 end
end
-- Shared with the upstairs bedroom (RedsBedroomRoom).
M.kit={builder=builder,hash=hash,bounds=bounds,runs=runs,flowers=flowers,
 pottedPlant=pottedPlant,wallSpan=wallSpan,CLASS_RANK=RANK}
function M.shell(part,L)
 local G=builder()
 local tv,st,mb=bounds(L.tv),bounds(L.stair),bounds(L.mat)
 local kx1=0;for _,c in ipairs(L.shelf)do kx1=max(kx1,(c[1]+1)*16)end
 if part=='north' then
  G.frame(0,NORTH,0)
  local opts={windows={},pictures={},clocks={}}
  local left=tv and tv.x1 or kx1;local right=st and st.x0 or W
  if right-left>=30 then
   opts.windows[1]={left+(right-left)/2-11,left+(right-left)/2+11,pot=true}
  end
  if tv then
   local cx=(tv.x0+tv.x1)/2
   opts.clocks[1]={cx,38,3.6}
   opts.pictures[#opts.pictures+1]={cx-8.5,cx-3.5,22,29,'cream',scene='flowers',frame='white'}
   opts.pictures[#opts.pictures+1]={cx+3.5,cx+9.5,23,30,'cream',scene='family'}
  end
  wallSpan(G,0,W,opts)
 elseif part=='west' then
  G.frame(0,D/2,1)
  wallSpan(G,-D/2,D/2-NORTH,{windows={{-14,14,pot=true}},
   pictures={{24,36,22,31,'cream',scene='sea'}},
   calendars={{-34,-26,20,32}}})
 elseif part=='east' then
  G.frame(W,D/2,-1)
  -- the flight's opening sits at the north end; decorate the rest
  wallSpan(G,-(D/2-NORTH),D/2,{windows={{-6,18,pot=false}},
   pictures={{28,40,22,31,'cream',scene='family'},{-30,-22,21,30,'cream',scene='flowers',frame='white'}}})
 elseif part=='south' then
  G.frame(W/2,D,2)
  local box=G.box
  -- Door over the warp mat stays open; everything else is wall.
  local d0,d1=-W/2+32,-W/2+64
  if mb then d0,d1=W/2-mb.x1,W/2-mb.x0 end
  d0,d1=d0+2,d1-2
  wallSpan(G,-W/2,d0,{hooks={{d0-14,d0-2,28}}})
  wallSpan(G,d1,W/2,{windows={{d1+12,d1+32}}})
  wallSpan(G,d0,d1,{base=34})
  box(d0-1.6,0,-2,d0,34,1.6,'white',1.1);box(d1,0,-2,d1+1.6,34,1.6,'white',1.1)
  box(d0-1.6,32.6,-2,d1+1.6,34,1.8,'white',1.1)
  -- the open front door: daylight beyond the threshold
  G.face({d0,0,-1.8},{d1,0,-1.8},{d1,32.6,-1.8},{d0,32.6,-1.8},'gold',1.3,true)
  box(d0,0,-2,d1,.5,0,'oak',1.05)                                   -- threshold
 elseif part=='ceiling' then
  local box=G.box
  box(0,WALL,NORTH-2,W,WALL+1,D,'ktLime',1.0)
  for x=16,W-8,32 do box(x-1.4,WALL-2.2,NORTH,x+1.4,WALL,D,'oak',.9)end
 end
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
 local G=M.room(L)
 local mesh=R.newMesh(G.vs,G.ix);if not mesh then return end
 local shell,windows={},{}
 for _,part in ipairs({'north','south','east','west','ceiling'})do
  local s=M.shell(part,L);shell[part]=R.newMesh(s.vs,s.ix)
  for _,pane in ipairs(s.windows)do pane.side=part;windows[#windows+1]=pane end
 end
 cached={mesh=mesh,shell=shell,windows=windows,vertices=#G.vs,source=L.source}
 if V.mod and V.mod.log and V.mod.log.info then
  pcall(V.mod.log.info,V.mod.log,'Legendary TEST137 Red house room: layout from %s',L.source)
 end
 return cached
end
function M.windowPanes(map)local r=prepare(map);return r and r.windows or {}end
function M.build(S,map)
 if not M.accepts(map)then return end
 for ty=0,map.def.height*4-1 do for tx=0,map.def.width*4-1 do
  local k=key(tx,ty)
  S.skip[k]=true;S.ground[k]=nil
  S.shapeAt[k]={class='ground',h=0,flat=true,art='flat',authored=true}
 end end
 S.redsHouseRoom=true
end
function M.visibleShell(eye)
 eye=eye or {W/2,30,D}
 return {north=eye[3]>NORTH,south=eye[3]<D,west=eye[1]>0,east=eye[1]<W,ceiling=eye[2]<WALL}
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
  local visible=M.visibleShell(R.eye)
  for _,part in ipairs({'north','south','east','west','ceiling'})do
   if visible[part]and r.shell[part]then R.draw(r.shell[part],tex)end
  end
 end)
 if R.seams then R.seams(true)end
 R.glass(true)
 if not ok then error(err)end
end
function M.invalidate()
 if cached then cached.mesh:release();for _,m in pairs(cached.shell)do m:release()end;cached=nil end
end
function M.setLive(live)if not(live and live.REDS_HOUSE_1F)then M.invalidate()end end
return M
