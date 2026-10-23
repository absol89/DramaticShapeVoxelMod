-- TEST138: Red's bedroom (REDS_HOUSE_2F) as one authored room, in the spirit
-- of the anime hero's bedroom: sky-blue walls over white beadboard, a wooden
-- bed with a red-and-white quilt, a beige computer on its desk, a study desk
-- under the window, a wood-cabinet CRT with the game console and two pads on
-- the floor, a round Poke Ball rug, posters, pennants, a trophy shelf, a
-- badge case, a backpack on a hook and a stairwell going down.
--
-- As downstairs, the ROM map owns collision, warps and the PC/console text.
-- Furniture sits on the source furniture cells, read from the live tile grid
-- (tileset REDS_HOUSE_2 classes, data/voxel_heights), with a fallback layout.
local V=...
local M={REVISION='reds-bedroom-room-143'}
local Base=V.require('RedsHouseRoom')
local K=Base.kit
local builder,hash,bounds,pottedPlant,wallSpan=K.builder,K.hash,K.bounds,K.pottedPlant,K.wallSpan
local pi,cos,sin,floor,min,max,abs=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs
local cached,white
local W,D,WALL,NORTH=Base.W,Base.D,Base.WALL,Base.NORTH
local SEAT=5
local CELLS=8
local function key(x,y)return (y+64)*4096+x+64 end

function M.accepts(map)
 return map and map.id=='REDS_HOUSE_2F' and map.def and map.def.width==4
   and map.def.height==4 or false
end

------------------------------------------------------------------ layout
local CLASS={}
for cls,tiles in pairs({
 stair={10,11,26,27}, pc={32,33,64,65}, tv={6,7,22,23}, console={14,15,30,31},
 bed={45,46,47,61,62,63}, plant={8,9,24,25,68,69,70,71},
 table={38,39,40,41,42,43,44,50,51,54,55,56,57,58,59,60,66,67}, stool={2,3,18,19},
})do for _,t in ipairs(tiles)do CLASS[t]=cls end end
local RANK={stair=8,pc=7,tv=6,console=5,bed=4,plant=3,table=2,stool=1}
-- pokered RedsHouse2F, as read from the original screen.
local FALLBACK={
 pc={{0,1}}, table={{1,1},{2,1},{3,1}}, stair={{7,1}},
 bed={{0,4},{0,5}}, tv={{3,4}}, console={{3,5}}, plant={{0,6}}, stool={},
}
function M.layout(map)
 local out={stair={},pc={},tv={},console={},bed={},plant={},table={},stool={}}
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
 if read<CELLS*CELLS*4 or #out.bed==0 then out=FALLBACK;out.source='fallback'
 else out.source='tiles' end
 out.blocked={}
 if map and map.isWalkableCell then
  for cy=0,CELLS-1 do for cx=0,CELLS-1 do
   local ok,w=pcall(map.isWalkableCell,map,cx,cy)
   if ok then out.blocked[cy*CELLS+cx]=not w end
  end end
 end
 return out
end
-- Back edge of a piece: the wall when it stands in the first room row.
local function backZ(b)return b.cz0<=1 and NORTH or b.z0+1 end

------------------------------------------------------------------ pieces
local function pokeballDisc(G,x,y,z,r,flat)
 -- flat: lying on the floor (rug), otherwise a wall relief facing +z
 local face,n=G.face,24
 local function P(a,rr,h)
  if flat then return {x+cos(a)*rr,y+(h or 0),z-sin(a)*rr}end
  return {x+cos(a)*rr,y+sin(a)*rr,z+(h or 0)}
 end
 for i=0,n-1 do local a,b=i*2*pi/n,(i+1)*2*pi/n
  local mat=(a<pi-1e-6)and'red'or'white'
  face(P(0,0,0),P(b,r,0),P(a,r,0),P(a,r,0),mat,mat=='red'and 1.0 or 1.12)
 end
 -- black band and centre button
 local band=r*.09
 if flat then G.box(x-r,y,z-band,x+r,y+.06,z+band,'dark',.8)
 else G.box(x-r,y-band,z,x+r,y+band,z+.06,'dark',.8)end
 for i=0,n-1 do local a,b=i*2*pi/n,(i+1)*2*pi/n
  face(P(0,0,.08),P(b,r*.30,.08),P(a,r*.30,.08),P(a,r*.30,.08),'dark',.8)
  face(P(0,0,.12),P(b,r*.19,.12),P(a,r*.19,.12),P(a,r*.19,.12),'white',1.2)
 end
end

local function bed(G,b)
 local box=G.box
 local vertical=(b.z1-b.z0)>=(b.x1-b.x0)
 local x0,x1,z0,z1=b.x0+.8,b.x1-.8,max(b.z0,NORTH)+.8,b.z1-.8
 local TOPH=7
 box(x0,0,z0,x1,3.6,z1,'oak',.9)                                    -- frame
 box(x0+.4,3.6,z0+.4,x1-.4,TOPH-1.2,z1-.4,'white',1.1)              -- mattress
 -- quilt: red with a white band, folded back under the pillow
 local hz=vertical and z0 or nil
 if vertical then
  box(x0+.1,TOPH-1.4,z0+8,x1-.1,TOPH-.2,z1-.2,'red',1.02)
  box(x0,TOPH-1.6,z0+8,x0+.1,4,z1-.2,'red',.9);box(x1-.1,TOPH-1.6,z0+8,x1,4,z1-.2,'red',.9)
  box(x0+.1,TOPH-.2,z0+16,x1-.1,TOPH-.1,z0+18.5,'white',1.15)
  box(x0+.1,TOPH-1.2,z0+7,x1-.1,TOPH,z0+9,'white',1.15)              -- folded edge
  box(x0+1.5,TOPH-1.2,z0+1.5,x1-1.5,TOPH+.6,z0+6.5,'ktPearl',1.15)   -- pillow
  -- headboard and footboard
  box(x0-.4,0,z0-.6,x1+.4,15,z0+.6,'oak',1.0)
  box(x0-.6,14,z0-.8,x1+.6,15.2,z0+.8,'oak',1.1)
  for k=1,3 do local x=x0+k*(x1-x0)/4;box(x-.6,TOPH,z0-.2,x+.6,13.6,z0+.2,'oak',.95)end
  box(x0-.4,0,z1-.6,x1+.4,10,z1+.4,'oak',.98)
 else
  box(x0+8,TOPH-1.4,z0+.1,x1-.2,TOPH-.2,z1-.1,'red',1.02)
  box(x0+7,TOPH-1.2,z0+.1,x0+9,TOPH,z1-.1,'white',1.15)
  box(x0+1.5,TOPH-1.2,z0+1.5,x0+6.5,TOPH+.6,z1-1.5,'ktPearl',1.15)
  box(x0-.6,0,z0-.4,x0+.6,15,z1+.4,'oak',1.0)
  box(x1-.6,0,z0-.4,x1+.4,10,z1+.4,'oak',.98)
 end
end

local function crt(G,x0,x1,y0,zBack,zFront,case)
 local box,face=G.box,G.face
 case=case or'ktLime'
 local h=(x1-x0)*.82
 box(x0,y0,zBack,x1,y0+h,zFront,case,1.02)
 box(x0+.8,y0+.8,zFront,x1-.8,y0+h-.8,zFront+.25,'dark',.7)
 face({x0+1.4,y0+1.4,zFront+.3},{x1-1.4,y0+1.4,zFront+.3},{x1-1.4,y0+h-1.4,zFront+.3},{x0+1.4,y0+h-1.4,zFront+.3},'ktGlass',1.15,true)
 return h
end

local function computerDesk(G,b,stools)
 local box,cyl=G.box,G.cyl
 local x0,x1,z0,z1=b.x0+.6,b.x1-.6,backZ(b),b.z1-1
 local T=11
 box(x0,T-1,z0,x1,T,z1,'oak',1.06)
 box(x0,0,z0,x0+5,T-1,z1,'oak',.92)                                 -- drawer pedestal
 for i=0,2 do box(x0+.4,1+i*3.1,z1,x0+4.6,3.6+i*3.1,z1+.2,'oak',1.02);box(x0+2.1,2.2+i*3.1,z1+.2,x0+2.9,2.6+i*3.1,z1+.5,'gold',1.15)end
 box(x1-1.2,0,z0+1,x1,T-1,z1-1,'oak',.9)
 -- beige computer, keyboard, mouse and a tower
 local cx=(x0+x1)/2+1
 local h=crt(G,cx-5,cx+5,T,z0+1,z0+8.5,'ktLime')
 box(cx-5.5,T,z0+.6,cx+5.5,T+.6,z0+9,'ktLime',.95)
 for i=0,3 do box(cx-4+i*1.3,T+h-2.6+0,z0+8.8,cx-3.2+i*1.3,T+h-2.2,z0+8.85,'white',1.3,true)end
 box(cx-5,T,z1-4.4,cx+4,T+.5,z1-1.2,'ktLime',1.0)
 for r=0,2 do for i=0,7 do box(cx-4.6+i*1.1,T+.5,z1-4+r*.95,cx-3.8+i*1.1,T+.75,z1-3.3+r*.95,'white',1.1)end end
 box(cx+5,T,z1-3.6,cx+6.4,T+.6,z1-1.6,'ktLime',1.0)
 box(x1-6,0,z0+1,x1-1.6,9,z0+9,'ktLime',.95)                        -- tower
 box(x1-5.4,6,z0+9,x1-2.2,6.8,z0+9.2,'dark',.8)
 box(x1-2.8,1.4,z0+9,x1-2.2,2,z0+9.3,'green',1.3,true)
 -- cork board with photos and notes above the desk
 box(x0+1,24,NORTH,x1-1,36,NORTH+.6,'ktCedar',.95)
 box(x0+1.6,24.6,NORTH+.6,x1-1.6,35.4,NORTH+.7,'ktOchre',1.05)
 for i=0,5 do local px=x0+2.4+hash(i,3)*(x1-x0-8);local py=25.4+hash(3,i)*6
  box(px,py,NORTH+.7,px+3.2,py+2.6,NORTH+.8,({'white','cream','blue','white','flower','cream'})[i+1],1.15)
  box(px+1.4,py+2.2,NORTH+.8,px+1.8,py+2.6,NORTH+1.1,'red',1.1)
 end
 -- swivel chairs on any stool cells
 for _,c in ipairs(stools)do
  local sx,sz=c[1]*16+8,c[2]*16+8
  cyl(sx,0,.6,sz,4.2,4.2,'dark',10,.8)
  box(sx-.5,.6,sz-.5,sx+.5,SEAT-.8,sz+.5,'ktSteel',1.0)
  cyl(sx,SEAT-.8,SEAT,sz,4.6,4.6,'red',14,1.05)
  box(sx-4,SEAT,sz+3,sx+4,SEAT+9,sz+4.4,'red',1.0)
 end
end

local function studyDesk(G,r)
 local box,cyl=G.box,G.cyl
 local x0,x1=r.cx0*16+.6,(r.cx1+1)*16-.6
 local z0,z1=NORTH,(r.rz+1)*16-1
 local T=11
 box(x0,T-1,z0,x1,T,z1,'oak',1.06)
 for _,lx in ipairs({x0+.4,x1-1.8})do for _,lz in ipairs({z0+.6,z1-2})do box(lx,0,lz,lx+1.4,T-1,lz+1.4,'oak',.9)end end
 box(x0+.4,T-3,z1-1.4,x1-.4,T-1,z1-.6,'oak',.86)                    -- apron
 local w=x1-x0
 -- books between bookends
 local bx=x0+2
 for i=0,6 do local bw=.8+hash(i,9)*.7;local bh=4+hash(9,i)*2.6
  box(bx,T,z0+1,bx+bw,T+bh,z0+6,({'red','navy','green','gold','blue','terra','sage'})[i+1],1.0+hash(i,i)*.1)
  bx=bx+bw+.1
 end
 box(bx+.2,T,z0+1,bx+.8,T+4.8,z0+6,'ktSteel',1.05)
 -- alarm clock
 local ax=x0+w*.45
 cyl(ax,T,T+.4,z0+5,1.6,1.6,'dark',12,.9)
 G.disc(ax,T+2.4,z0+5.6,2.1,'red',1.05,16);G.disc(ax,T+2.4,z0+5.7,1.6,'white',1.2,16)
 box(ax-.1,T+2.4,z0+5.75,ax+.1,T+3.6,z0+5.8,'dark',.8);box(ax,T+2.3,z0+5.75,ax+.9,T+2.5,z0+5.8,'dark',.8)
 for _,s in ipairs({-1,1})do cyl(ax+s*1.4,T+4.3,T+4.9,z0+5,.7,.7,'gold',8,1.1)end
 -- a Poke Ball on a little stand
 local px=x0+w*.62
 box(px-1.4,T,z0+3,px+1.4,T+.6,z0+6,'oak',1.0)
 cyl(px,T+.6,T+2.1,z0+4.5,1.6,1.9,'white',12,1.15)
 cyl(px,T+2.1,T+2.4,z0+4.5,1.95,1.95,'dark',12,.8)
 cyl(px,T+2.4,T+3.7,z0+4.5,1.9,1.4,'red',12,1.05)
 G.disc(px,T+2.25,z0+6.42,.55,'white',1.25,10)
 -- desk lamp
 local lx=x1-4
 cyl(lx,T,T+.5,z0+4,1.8,1.8,'red',10,1.0)
 box(lx-.2,T+.5,z0+3.8,lx+.2,T+7,z0+4.2,'ktSteel',1.1)
 box(lx-.2,T+6.8,z0+4,lx+.2,T+7.2,z0+8,'ktSteel',1.1)
 cyl(lx,T+4.8,T+7,z0+8,2.2,.8,'red',12,1.05)
 cyl(lx,T+4.6,T+4.9,z0+8,1,1,'gold',8,1.4,true)
 -- notebook and pencil cup
 box(x0+w*.22,T,z1-6,x0+w*.22+5,T+.3,z1-2,'white',1.15)
 box(x0+w*.22+.3,T+.3,z1-5.6,x0+w*.22+.6,T+.32,z1-2.4,'red',1.0)
 cyl(x1-9,T,T+3,z1-3,.9,.9,'blue',8,1.0)
 for i=0,2 do box(x1-9.3+i*.4,T+3,z1-3.2,x1-9.1+i*.4,T+4.6,z1-3,({'gold','red','green'})[i+1],1.1)end
end

local function television(G,b,facing)
 local box=G.box
 local x0,x1=b.x0+1,b.x1-1
 local zB,zF=b.z0+1.5,b.z1-1.5
 box(x0,0,zB,x1,5.5,zF,'oak',.95)
 box(x0+.6,1,zF,x1-.6,4.8,zF+.2,'wood',.8)
 box(x0+.4,5.5,zB+.6,x1-.4,17,zF-.6,'ktCedar',.95)
 box(x0+1.2,6.6,zF-.6,x1-4,16,zF-.4,'dark',.6)
 G.face({x0+1.9,7.3,zF-.35},{x1-4.7,7.3,zF-.35},{x1-4.7,15.3,zF-.35},{x0+1.9,15.3,zF-.35},'ktMarine',1.15,true)
 -- a game title screen glow: a bright band and a red logo block
 G.face({x0+3,12,zF-.32},{x1-6,12,zF-.32},{x1-6,14,zF-.32},{x0+3,14,zF-.32},'ktPearl',1.25,true)
 G.face({x0+5,9,zF-.31},{x1-8,9,zF-.31},{x1-8,10.6,zF-.31},{x0+5,10.6,zF-.31},'red',1.25,true)
 for i=0,2 do box(x1-3.2,8+i*2.4,zF-.6,x1-1.6,9.4+i*2.4,zF,i==0 and'gold'or'slate',1.05)end
end

local function console(G,b,tv)
 local box=G.box
 local cx,cz=(b.x0+b.x1)/2,(b.z0+b.z1)/2
 -- grey console, cartridge, two pads with cables back to it
 box(cx-5,0,cz-4.6,cx+5,1.8,cz+1.2,'mortar',1.05)
 box(cx-4.6,1.8,cz-4.2,cx+4.6,2.3,cz-1.2,'mortar',1.1)
 box(cx-2.6,2.3,cz-3.8,cx+2.6,4.8,cz-2.2,'slate',1.0)              -- cartridge
 box(cx-2.2,3.6,cz-2.2,cx+2.2,4.4,cz-2.1,'red',1.1)
 for _,s in ipairs({-1,1})do box(cx+s*3.4-.8,1.8,cz-.6,cx+s*3.4+.8,2.2,cz+.6,'ktViolet',1.05)end
 box(cx-3.4,0,cz+1.2,cx-2.6,.3,cz+5,'dark',.8);box(cx+2.6,0,cz+1.2,cx+3.4,.3,cz+4,'dark',.8)
 for i,px in ipairs({cx-5,cx+3.6})do
  local pz=cz+(i==1 and 5.4 or 4.4)
  box(px-1.8,0,pz,px+1.8,.9,pz+2.4,'mortar',1.08)
  box(px-1.2,.9,pz+.6,px-.4,1.1,pz+1.6,'dark',.8)
  box(px+.4,.9,pz+.5,px+.9,1.1,pz+1,'ktViolet',1.1);box(px+.9,.9,pz+1.1,px+1.4,1.1,pz+1.6,'ktViolet',1.1)
 end
end

local function stairwell(G,b)
 local box,face=G.box,G.face
 local x0,x1,z0,z1=b.x0,b.x1,max(b.z0,NORTH),b.z1
 local n=5;local run=(x1-x0)/n;local drop=3.8
 -- the flight descends westward from the east lip
 for i=0,n-1 do
  local a=x1-(i+1)*run;local h=-(i+1)*drop
  box(a,h-.5,z0,a+run,h,z1,'oak',1.04)
  box(a+run-.3,h,z0,a+run,h+drop,z1,'white',1.0)
 end
 box(x0,-n*drop-14,z0,x0+.4,0,z1,'dark',.55)
 face({x0,-n*drop-14,z1},{x1,-n*drop-14,z1},{x1,0,z1},{x0,0,z1},'wood',.6)
 face({x1,-n*drop-14,z0},{x0,-n*drop-14,z0},{x0,0,z0},{x1,0,z0},'wood',.5)
 box(x0,-n*drop-14,z0,x1,-n*drop-13.5,z1,'dark',.4)
 -- white balustrade on the open south and west edges, entry on the east
 local function post(x,z,h)box(x-.5,0,z-.5,x+.5,h,z+.5,'white',1.1)end
 for x=x0+3,x1-4,3.2 do post(x,z1-.2,10)end
 for z=z0+3,z1-3,3.2 do post(x0+.4,z,10)end
 box(x0-.2,10,z1-.9,x1-2,11.2,z1+.5,'oak',1.08)
 box(x0-.4,10,z0,x0+1.2,11.2,z1+.5,'oak',1.08)
 box(x0-1,0,z1-1.2,x0+1.6,12.5,z1+1.2,'oak',1.0)                    -- newel
 box(x0-1.3,12.5,z1-1.5,x0+1.9,13.4,z1+1.5,'oak',1.1)
end

-- Plank floor with a hole for the stairwell.
local function floorPlanks(G,hole)
 local face=G.face
 for z=NORTH,D-.01,4 do
  local off=(floor(z/4)%3)*9;local endZ=min(D,z+4)
  for x=-off,W-.01,26 do local a=max(0,x);local b=min(W,x+26)
   local segs={{a,b}}
   if hole and endZ>hole.z0 and z<hole.z1 then
    segs={}
    if hole.x0>a then segs[#segs+1]={a,min(b,hole.x0)}end
    if hole.x1<b then segs[#segs+1]={max(a,hole.x1),b}end
   end
   for _,sg in ipairs(segs)do if sg[2]>sg[1] then
    face({sg[1],0,z},{sg[1],0,endZ},{sg[2],0,endZ},{sg[2],0,z},'oak',.98+hash(floor(x),floor(z))*.10)
   end end
  end
 end
end

function M.room(L)
 local G=builder()
 local st=bounds(L.stair)
 if st then st={x0=st.x0,x1=st.x1,z0=max(st.z0,NORTH),z1=st.z1,cz0=st.cz0}end
 floorPlanks(G,st)
 -- round Poke Ball rug in the open floor
 local tv,cs=bounds(L.tv),bounds(L.console)
 local rx,rz=W*.62,D*.70
 if cs then rx,rz=(cs.x0+cs.x1)/2+22,cs.z1+8 end
 rx=min(max(rx,24),W-24);rz=min(max(rz,40),D-26)
 pokeballDisc(G,rx,.05,rz,17,true)
 if st then stairwell(G,st)end
 local bb=bounds(L.bed);if bb then bed(G,bb)end
 local pc=bounds(L.pc)
 if pc then
  -- the PC's desk spans its own cell plus adjoining table cells in its row
  local ext={}
  for _,c in ipairs(L.pc)do ext[#ext+1]=c end
  local rest={}
  for _,c in ipairs(L.table)do
   if c[2]>=pc.cz0 and c[2]<=pc.cz1 and (c[1]==pc.cx1+1 or c[1]==pc.cx0-1)then ext[#ext+1]=c else rest[#rest+1]=c end
  end
  computerDesk(G,bounds(ext),L.stool)
  for _,r in ipairs(K.runs(rest))do studyDesk(G,r)end
 else
  for _,r in ipairs(K.runs(L.table))do studyDesk(G,r)end
 end
 if tv then television(G,tv)end
 if cs then console(G,cs,tv)end
 for i,c in ipairs(L.plant)do
  pottedPlant(G,c[1]*16+8,0,c[2]*16+8,1.45,i+11)
 end
 -- round ceiling light
 G.cyl(W/2,WALL-.7,WALL,D/2,4.4,4.4,'white',16,1.2,true)
 G.cyl(W/2,WALL-.85,WALL-.7,D/2,4.7,4.7,'ktSteel',16,1.0)
 return G
end

------------------------------------------------------------------ shell
local THEME={paint='ktPearl',panel='white',curtain='blue'}
local function themed(t)for k,v in pairs(THEME)do if t[k]==nil then t[k]=v end end;return t end
local function pennants(G,x0,x1,y)
 local face=G.face
 local cols={'red','gold','blue','green','flower','navy'}
 G.box(x0,y,.2,x1,y+.3,.5,'dark',.8)
 local n=floor((x1-x0)/4.2)
 for i=0,n-1 do local a=x0+.4+i*4.2
  face({a,y,.6},{a+3.6,y,.6},{a+1.8,y-4.6,.6},{a+1.8,y-4.6,.6},cols[i%#cols+1],1.12)
 end
end
local function trophyShelf(G,x0,x1,y)
 local box,cyl=G.box,G.cyl
 box(x0,y-.8,0,x1,y,4.2,'oak',1.05)
 for _,x in ipairs({x0+1,x1-2})do box(x,y-3,0,x+1,y-.8,3.6,'oak',.9)end
 local n=3
 for i=0,n-1 do local cx=x0+(i+.5)*(x1-x0)/n
  box(cx-1.4,y,1,cx+1.4,y+1.2,3.4,'wood',.95)
  cyl(cx,y+1.2,y+2.4,2.2,.35,.35,'gold',8,1.15)
  cyl(cx,y+2.4,y+5,2.2,.6,1.6,'gold',10,1.2)
  for _,s in ipairs({-1,1})do box(cx+s*1.6-.25,y+3,1.9,cx+s*1.6+.25,y+4.4,2.5,'gold',1.1)end
 end
end
local function badgeCase(G,x0,x1,lo,hi)
 local box=G.box
 box(x0-.7,lo-.7,0,x1+.7,hi+.7,.8,'oak',1.0)
 box(x0,lo,.8,x1,hi,.9,'navy',1.0)
 for r=0,1 do for k=0,3 do
  local cx=x0+(k+.5)*(x1-x0)/4;local cy=lo+(r+.5)*(hi-lo)/2
  G.disc(cx,cy,.95,(hi-lo)*.16,'ktSteel',.85,10)
 end end
end
local function hookAndBag(G,x,y)
 local box=G.box
 box(x-3,y,0,x+3,y+1.2,.7,'oak',1.0)
 box(x-.3,y+.2,.7,x+.3,y+.8,2.4,'gold',1.15)
 -- a yellow-and-green backpack
 box(x-3,y-10,1,x+3,y-.4,4.6,'gold',1.0)
 box(x-2.4,y-7,4.6,x+2.4,y-3,5.4,'leaf',1.05)
 box(x-3.1,y-1.6,1.2,x+3.1,y-.4,4.8,'leaf',1.05)
 for _,s in ipairs({-1,1})do box(x+s*2.2-.4,y-9,4.6,x+s*2.2+.4,y-1,5,'leaf',.95)end
end

function M.shell(part,L)
 local G=builder()
 local pc,st,bb=bounds(L.pc),bounds(L.stair),bounds(L.bed)
 if part=='north' then
  G.frame(0,NORTH,0)
  local opts=themed({windows={},pictures={}})
  -- windows over the study desk run, clear of the PC's cork board
  local rest={}
  for _,c in ipairs(L.table)do if not(pc and c[2]==pc.cz0 and(c[1]==pc.cx1+1 or c[1]==pc.cx0-1))then rest[#rest+1]=c end end
  for _,r in ipairs(K.runs(rest))do
   local a,b=r.cx0*16,(r.cx1+1)*16
   if b-a>=28 then opts.windows[#opts.windows+1]={a+(b-a)/2-11,a+(b-a)/2+11,22,38}end
  end
  wallSpan(G,0,W,opts)
  -- a Poke Ball poster between the window and the stairwell
  local px=st and st.x0-14 or W-20
  G.box(px-6.8,22.2,0,px+6.8,37.8,.4,'white',1.15)
  pokeballDisc(G,px,30,.45,5.6,false)
 elseif part=='west' then
  G.frame(0,D/2,1)
  local opts=themed({pictures={}})
  wallSpan(G,-D/2,D/2-NORTH,opts)
  -- pennant string above the bed and a trophy shelf
  pennants(G,-36,18,40)
  trophyShelf(G,-30,-8,26)
 elseif part=='east' then
  G.frame(W,D/2,-1)
  wallSpan(G,-(D/2-NORTH),D/2,themed({windows={{-2,22,22,38}},
   pictures={{34,48,20,32,'cream',scene='sea'}}}))
  -- stylised region map poster
  local box=G.box
  box(-44,20,0,-28,34,.4,'ktOchre',1.05)
  box(-43,21,.4,-29,33,.5,'ktGlass',1.0)
  for i=0,5 do local x=-42+hash(i,4)*10;local y=22+hash(4,i)*8
   box(x,y,.5,x+2.6+hash(i,2)*2,y+1.8,.6,'leaf',1.1)end
  for i=0,6 do local x=-41.5+i*1.7;box(x,27.4+((i%2)*.6),.6,x+1.4,27.8+((i%2)*.6),.65,'red',1.1)end
 elseif part=='south' then
  G.frame(W/2,D,2)
  wallSpan(G,-W/2,W/2,themed({windows={{-14,8,22,38}}}))
  -- sliding closet, badge case and the backpack on its hook
  local box=G.box
  box(18,0,0,54,36,1.4,'white',1.05)
  box(18.6,1,1.4,36,35,1.8,'oak',1.0);box(36,1,1.2,53.4,35,1.6,'oak',.95)
  for _,x in ipairs({33.4,38.4})do box(x,16,1.8,x+.8,20,2.2,'gold',1.15)end
  badgeCase(G,-46,-30,26,33)
  hookAndBag(G,-24,30)
 elseif part=='ceiling' then
  local box=G.box
  box(0,WALL,NORTH-2,W,WALL+1,D,'white',1.05)
  box(0,WALL-1.2,NORTH,W,WALL,NORTH+1.6,'blue',1.0)
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
 cached={mesh=mesh,shell=shell,windows=windows,source=L.source}
 if V.mod and V.mod.log and V.mod.log.info then
  pcall(V.mod.log.info,V.mod.log,'Legendary TEST138 Red bedroom: layout from %s',L.source)
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
 S.redsBedroomRoom=true
end
M.visibleShell=Base.visibleShell
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
function M.setLive(live)if not(live and live.REDS_HOUSE_2F)then M.invalidate()end end
return M
