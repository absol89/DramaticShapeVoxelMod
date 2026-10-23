-- TEST173: the town interiors' furniture and finishes (InteriorRooms). A
-- model frame with self-lit faces, the room shell (walls, wainscot, cornice,
-- caps, ceiling, floor, the front door), windows and pictures for the walls,
-- and the furniture every room draws from: bookcases and cabinets, tables,
-- chairs and stools, potted plants, rugs, lamps, clocks, shelves and their
-- contents. Everything is built of ReferenceMaterials finishes; the in*
-- ones (143..171) are the interiors' own.
local V=...
local M={}
local pi,cos,sin,floor,min,max,abs,sqrt=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs,math.sqrt
local function rh(a,b,s)local v=sin(a*12.9898+b*78.233+s*37.719)*43758.5453;return v-floor(v)end
M.rh=rh
local CS=16
-- self-lit finishes take an exact shade (it picks a variant, not light)
local SELF={inScreen=true,inLamp=true,inAqua=true,inShoji=true,inWindow=true,inPanel=true,
 lgCrystal=true,lgLava=true,lgAmethyst=true,lgNight=true,dnNeon=true}
M.SELF=SELF

local function dirShade(nx,ny,nz)
 if ny>.6 then return 1 elseif ny<-.6 then return .6 end
 local l=sqrt(nx*nx+nz*nz);if l<1e-6 then return .85 end
 nx,nz=nx/l,nz/l
 local s=(nz>0 and nz*.92 or -nz*.72)+(nx>0 and nx*.86 or -nx*.80)
 local w=abs(nz)+abs(nx)
 return (s/w)*(1-.25*max(0,ny))+(ny>0 and ny*.25 or 0)
end

------------------------------------------------------------------ frames
-- A model frame on a part's emitter: local x right, y up, +z the FRONT;
-- yaw turns it (pi/2 faces east, -pi/2 west, pi north). `C` (the context)
-- lets self-lit faces skip the baked light.
function M.frame(C,E,ox,oy,oz,yaw,scale,tone)
 local co,si=cos(yaw or 0),sin(yaw or 0);scale=scale or 1;tone=tone or 1
 local L={E=E,C=C}
 local function P(p)return{ox+(p[1]*co+p[3]*si)*scale,oy+p[2]*scale,oz+(-p[1]*si+p[3]*co)*scale}end
 L.P=P
 function L.quad(a,b,c,d,mat,t)
  local A,B,Cc,D=P(a),P(b),P(c),P(d)
  if SELF[mat]then
   local was=C.flat;C.flat=true
   E.quad(A,B,Cc,D,mat,t or 1)
   C.flat=was
   return
  end
  local ux,uy,uz=Cc[1]-A[1],Cc[2]-A[2],Cc[3]-A[3]
  local vx,vy,vz=D[1]-B[1],D[2]-B[2],D[3]-B[3]
  local nx,ny,nz=uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx
  local l=sqrt(nx*nx+ny*ny+nz*nz)
  local s=(t or 1)*tone*(l>1e-9 and dirShade(nx/l,ny/l,nz/l)or .85)
  E.quad(A,B,Cc,D,mat,s)
 end
 -- a self-lit face at an exact variant (screens, windows, lamp shades)
 function L.raw(a,b,c,d,mat,v)
  local was=C.flat;C.flat=true
  E.quad(P(a),P(b),P(c),P(d),mat,v or 1)
  C.flat=was
 end
 -- an axis box in local axes; skip={top,bottom,n,s,w,e} (default no bottom)
 local NOBOT={bottom=true}
 function L.box(x0,y0,z0,x1,y1,z1,mat,t,skip)
  if x1-x0<.001 or y1-y0<.001 or z1-z0<.001 then return end
  skip=skip or NOBOT
  if not skip.bottom then L.quad({x0,y0,z1},{x1,y0,z1},{x1,y0,z0},{x0,y0,z0},mat,t)end
  if not skip.top then L.quad({x0,y1,z0},{x1,y1,z0},{x1,y1,z1},{x0,y1,z1},mat,t)end
  if not skip.s then L.quad({x0,y0,z1},{x1,y0,z1},{x1,y1,z1},{x0,y1,z1},mat,t)end
  if not skip.n then L.quad({x1,y0,z0},{x0,y0,z0},{x0,y1,z0},{x1,y1,z0},mat,t)end
  if not skip.w then L.quad({x0,y0,z0},{x0,y0,z1},{x0,y1,z1},{x0,y1,z0},mat,t)end
  if not skip.e then L.quad({x1,y0,z1},{x1,y0,z0},{x1,y1,z0},{x1,y1,z1},mat,t)end
 end
 -- a prism ring (n sides) from radius r0 at y0 to r1 at y1, capped on top
 function L.cyl(x,y0,y1,z,r0,r1,mat,n,cap,rot,mat2)
  n=n or 10;rot=rot or 0;r1=r1 or r0
  for i=0,n-1 do
   local a0,a1=rot+i/n*pi*2,rot+(i+1)/n*pi*2
   L.quad({x+cos(a0)*r0,y0,z+sin(a0)*r0},{x+cos(a1)*r0,y0,z+sin(a1)*r0},
          {x+cos(a1)*r1,y1,z+sin(a1)*r1},{x+cos(a0)*r1,y1,z+sin(a0)*r1},(mat2 and i%2==1)and mat2 or mat)
  end
  if cap~=false and r1>.01 then
   local cm=type(cap)=='string'and cap or mat
   for i=0,n-1 do
    local a0,a1=rot+i/n*pi*2,rot+(i+1)/n*pi*2
    L.quad({x,y1,z},{x,y1,z},{x+cos(a1)*r1,y1,z+sin(a1)*r1},{x+cos(a0)*r1,y1,z+sin(a0)*r1},cm)
   end
  end
 end
 -- a lumpy sphere (lat/long rings), optional jitter seed
 function L.sphere(x,y,z,rx,ry,rz,mat,n,rings,seed,mat2)
  n=n or 8;rings=rings or 5
  local pts={}
  for j=0,rings do
   pts[j]={}
   local b=-pi/2+j*pi/rings
   for i=0,n-1 do
    local a=i/n*pi*2
    local k=1
    if seed and j>0 and j<rings then k=.86+.28*rh(seed+i,j,3)end
    pts[j][i]={x+cos(a)*cos(b)*rx*k,y+sin(b)*ry*k,z+sin(a)*cos(b)*rz*k}
   end
  end
  for j=0,rings-1 do for i=0,n-1 do
   local i2=(i+1)%n
   L.quad(pts[j][i],pts[j][i2],pts[j+1][i2],pts[j+1][i],(mat2 and (i+j)%2==1)and mat2 or mat)
  end end
 end
 -- a flat disc facing +z (clock faces, plates) or up (axis='y')
 function L.disc(x,y,z,r,mat,n,axis,t)
  n=n or 14
  for i=0,n-1 do
   local a0,a1=i/n*pi*2,(i+1)/n*pi*2
   if axis=='y'then
    L.quad({x,y,z},{x+cos(a1)*r,y,z+sin(a1)*r},{x+cos(a0)*r,y,z+sin(a0)*r},{x,y,z},mat,t)
   else
    L.quad({x,y,z},{x+cos(a0)*r,y+sin(a0)*r,z},{x+cos(a1)*r,y+sin(a1)*r,z},{x,y,z},mat,t)
   end
  end
 end
 -- a ring band facing +z
 function L.ring(x,y,z,r0,r1,mat,n,t)
  n=n or 16
  for i=0,n-1 do
   local a0,a1=i/n*pi*2,(i+1)/n*pi*2
   L.quad({x+cos(a0)*r0,y+sin(a0)*r0,z},{x+cos(a0)*r1,y+sin(a0)*r1,z},{x+cos(a1)*r1,y+sin(a1)*r1,z},{x+cos(a1)*r0,y+sin(a1)*r0,z},mat,t)
  end
 end
 -- a thin rod between two local points (square section)
 function L.rod(a,b,r,mat,t)
  local dx,dy,dz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
  local l=sqrt(dx*dx+dy*dy+dz*dz);if l<1e-4 then return end
  local ux,uy,uz
  if abs(dy)/l>.9 then ux,uy,uz=1,0,0 else ux,uy,uz=0,1,0 end
  -- p = u x d, q = d x p
  local px,py,pz=uy*dz-uz*dy,uz*dx-ux*dz,ux*dy-uy*dx
  local pl=sqrt(px*px+py*py+pz*pz);px,py,pz=px/pl*r,py/pl*r,pz/pl*r
  local qx,qy,qz=(dy*pz-dz*py)/l,(dz*px-dx*pz)/l,(dx*py-dy*px)/l
  local c={{px+qx,py+qy,pz+qz},{-px+qx,-py+qy,-pz+qz},{-px-qx,-py-qy,-pz-qz},{px-qx,py-qy,pz-qz}}
  for i=1,4 do
   local o1,o2=c[i],c[i%4+1]
   L.quad({a[1]+o1[1],a[2]+o1[2],a[3]+o1[3]},{a[1]+o2[1],a[2]+o2[2],a[3]+o2[3]},
          {b[1]+o2[1],b[2]+o2[2],b[3]+o2[3]},{b[1]+o1[1],b[2]+o1[2],b[3]+o1[3]},mat,t)
  end
 end
 return L
end

------------------------------------------------------------------ parts
-- named parts on the context, with the visibility rules of LeagueRooms
function M.part(C,name,vis)return C.part(name,vis)end
-- the decor part of a shell wall: shows when its wall does
function M.wallPart(C,side)
 local S=C.shellBox
 if side=='N'then return C.part('decor:N',{axis='z',c=S.n,s=1})end
 if side=='S'then return C.part('decor:S',{axis='z',c=S.s,s=-1})end
 if side=='W'then return C.part('decor:W',{axis='x',c=S.w,s=1})end
 return C.part('decor:E',{axis='x',c=S.e,s=-1})
end
-- a frame standing ON a wall's face: local x runs along the wall (left to
-- right as you face it), y up, +z out into the room
function M.onWall(C,side,u,y)
 local S=C.shellBox;local E=M.wallPart(C,side)
 if side=='N'then return M.frame(C,E,S.w+u,y or 0,S.n,0)end
 if side=='S'then return M.frame(C,E,S.e-u,y or 0,S.s,pi)end
 if side=='W'then return M.frame(C,E,S.w,y or 0,S.s-u,pi/2)end
 return M.frame(C,E,S.e,y or 0,S.n+u,-pi/2)
end

------------------------------------------------------------------ shell
-- The room's walls from its grid: solid(cx,cy) says which cells are wall.
-- o: H, paint (wall), upper (above the rail; default paint), wainscot (nil =
-- none), rail, skirting, cornice, cap, ceiling, floor, floorT, door(cx,cy),
-- ao (contact-shade reach), blocked(cx,cy) (furniture that shades the floor)
function M.shell(C,o)
 local H=o.H or C.H or 56;C.H=H
 local cw,ch=C.cw,C.ch
 local solid=o.solid
 -- the room box: the faces of the outermost open cells
 local x0,x1,z0,z1=math.huge,-math.huge,math.huge,-math.huge
 for cy=0,ch-1 do for cx=0,cw-1 do
  if not solid(cx,cy)then
   x0=min(x0,cx*CS);x1=max(x1,(cx+1)*CS);z0=min(z0,cy*CS);z1=max(z1,(cy+1)*CS)
  end
 end end
 C.shellBox={n=z0,s=z1,w=x0,e=x1}
 C.shell={n=z0,s=z1,w=x0,e=x1}
 local paint=o.paint or'ktPlaster';local upper=o.upper or paint
 local rail=o.rail or'oak';local skirt=o.skirting or rail;local cornice=o.cornice or'white'
 local cap=o.cap or'ktLime'
 local wy=o.wainscot and(o.wainscotH or 14)or nil
 local T=3.2
 local function wallStyle(L,len,run)
  -- (TEST180: the holes in their order along the run. A wall facing north
  -- or east lists them backwards, and the rails and skirting, which walk
  -- the holes in order, ran straight across the second door: the Museum's
  -- and the Celadon Mart's second front door.)
  if run.holes and #run.holes>1 then table.sort(run.holes,function(a,b)return a[1]<b[1]end)end
  -- the face, in bands so the light reads up the wall
  local bands={0}
  if wy then bands[#bands+1]=wy end
  bands[#bands+1]=H*.55;bands[#bands+1]=H
  local function face(ya,yb,mat)
   -- Optional inset bays (aquariums) replace the face, not the shell's
   -- collision or cutaway rules. All other rooms keep the ordinary face.
   if o.face and o.face(L,len,run,ya,yb,mat)then return end
   -- cut round the run's door holes
   local xs={0}
   local holes=run.holes or{}
   local cuts={}
   for _,h in ipairs(holes)do cuts[#cuts+1]=h end
   table.sort(cuts,function(a,b)return a[1]<b[1]end)
   local at=0
   for _,h in ipairs(cuts)do
    local top=o.doorH or 34
    if h[1]>at then L.quad({at,ya,0},{h[1],ya,0},{h[1],yb,0},{at,yb,0},mat,1)end
    if yb>top then L.quad({h[1],max(ya,top),0},{h[2],max(ya,top),0},{h[2],yb,0},{h[1],yb,0},mat,1)end
    at=h[2]
   end
   if len>at then L.quad({at,ya,0},{len,ya,0},{len,yb,0},{at,yb,0},mat,1)end
  end
  for i=1,#bands-1 do
   local ya,yb=bands[i],bands[i+1]
   face(ya,yb,(wy and ya<wy)and(o.wainscot)or(ya>=(o.railY or H*.55)and upper or paint))
  end
  -- wainscot rail, skirting, cornice; each skips the door holes
  local function strip(y0,y1,d,mat,t)
   local at=0
   local holes=run.holes or{}
   for _,h in ipairs(holes)do
    if y0<(o.doorH or 34)then
     if h[1]>at then L.box(at,y0,0,h[1],y1,d,mat,t)end
     at=h[2]
    end
   end
   if len>at then L.box(at,y0,0,len,y1,d,mat,t)end
  end
  if wy then
   strip(wy-.6,wy+.8,1.1,rail,1.05)
   if o.beadboard then
    local at=2
    while at<len-1 do
     local inDoor=false
     for _,h in ipairs(run.holes or{})do if at+.35>h[1]and at<h[2]then inDoor=true;break end end
     if not inDoor then L.quad({at,1.8,.22},{at+.35,1.8,.22},{at+.35,wy-.6,.22},{at,wy-.6,.22},rail,.72)end
     at=at+(o.beadboard==true and 4 or o.beadboard)
    end
   end
  end
  strip(0,2.2,.8,skirt,.9)
  strip(H-2.4,H-1.2,1.3,cornice,1.06)
  strip(H-1.2,H,2.2,cornice,1.12)
  if o.picture then strip(o.picture,o.picture+.6,.7,rail,1.0)end
  -- the cap: the wall's cut top, over its thickness, past both ends
  L.quad({-T,H,-T},{len+T,H,-T},{len+T,H,0},{-T,H,0},cap,.95)
  L.quad({-T,H,0},{len+T,H,0},{len+T,H-.6,0},{-T,H-.6,0},cap,.8)
  if o.style then o.style(M.holeSafe(L,run,o.doorH or 34),len,run)end
 end
 local inner=o.inner
 local outerSolid=inner and function(cx,cy)return solid(cx,cy)and not inner(cx,cy)end or solid
 -- (TEST174) the side faces of a wall on the room's south side (a notch's
 -- cheeks, a stepped wall's risers) hide with it, when the eye is south
 local function openCell(x,y)return x>=0 and y>=0 and x<cw and y<ch and not solid(x,y)end
 local function visFor(run)
  if run.o~='E'and run.o~='W'then return nil end
  local sx=run.o=='E'and run.c/CS-1 or run.c/CS
  local top
  for k=run.from,run.to do
   if not(openCell(sx,k-1)and not openCell(sx,k+1))then return nil end
   top=top and min(top,k)or k
  end
  return {axis='z',c=top*CS,s=-1,tag='s'..top}
 end
 C.walls(outerSolid,wallStyle,{outside=o.outside~=false,door=o.door,prefix='wall',visFor=visFor})
 -- partitions between a multi-room plan's rooms: lower, and cut away
 -- whenever one stands between the eye and the player (see InteriorRooms)
 if inner then
  local Hi=o.innerH or H
  local saveH=H
  C.walls(inner,function(L,len,run)
   L.quad({0,0,0},{len,0,0},{len,Hi*.55,0},{0,Hi*.55,0},o.innerPaint or paint,1)
   L.quad({0,Hi*.55,0},{len,Hi*.55,0},{len,Hi,0},{0,Hi,0},o.innerPaint or upper,1)
   L.box(0,0,0,len,2.2,.8,skirt,.9)
   if o.innerStyle then o.innerStyle(L,len,run,Hi)end
  end,{outside=false,prefix='part'})
  for _,p in ipairs(C.parts)do
   if p.name:sub(1,5)=='part:'and p.vis and p.vis.axis=='z'and p.vis.s==1 then p.vis.sep=true end
  end
 end
 -- caps over every solid cell that meets the room (thick walls read solid)
 do
  local Ecap=C.part('caps')
  for cy=0,ch-1 do for cx=0,cw-1 do
   if solid(cx,cy)and(not o.capWhere or o.capWhere(cx,cy))then
    local near=false
    for dy=-1,1 do for dx=-1,1 do
     local nx,ny=cx+dx,cy+dy
     if nx>=0 and ny>=0 and nx<cw and ny<ch and not solid(nx,ny)then near=true end
    end end
    if near then
     local isIn=inner and inner(cx,cy)
     local Hc=isIn and(o.innerH or H)or H
     local E=Ecap
     if isIn and cy+1<ch and not solid(cx,cy+1)then E=C.part('part:S:'..((cy+1)*CS))
     elseif not isIn and cy>0 then
      -- (TEST174) a wall cell on the room's south side, open to the north:
      -- its cap goes when its face does (the eye south of it), or it would
      -- float over the room
      local function open(x,y)return x>=0 and y>=0 and x<cw and y<ch and not solid(x,y)end
      local south=not open(cx,cy+1)and(open(cx,cy-1)or
       (not open(cx-1,cy)and not open(cx+1,cy)and(open(cx-1,cy-1)or open(cx+1,cy-1))))
      if south then E=C.part('caps:N:'..(cy*CS),{axis='z',c=cy*CS,s=-1})end
     end
     E.quad({cx*CS,Hc,cy*CS},{(cx+1)*CS,Hc,cy*CS},{(cx+1)*CS,Hc,(cy+1)*CS},{cx*CS,Hc,(cy+1)*CS},o.cap or cap,.92)
    end
   end
  end end
 end
 -- the floor of every open cell, contact-shaded toward walls and furniture
 local E=C.part('floor')
 local block=o.blocked or solid
 local ao=C.aoField(function(cx,cy)
  if cx<0 or cy<0 or cx>=cw or cy>=ch then return true end
  return solid(cx,cy)or block(cx,cy)
 end,o.ao or 9)
 for cy=0,ch-1 do for cx=0,cw-1 do
  if not solid(cx,cy)and not(o.nofloor and o.nofloor(cx,cy))then
   C.floorRect(E,cx*CS,cy*CS,(cx+1)*CS,(cy+1)*CS,0,o.floor or'inOak',o.floorT or 1,ao,8)
  end
 end end
 -- the ceiling, seen only from under it
 if o.ceiling~=false then
  local Ec=C.part('ceiling',{below=H})
  for cy=0,ch-1 do for cx=0,cw-1 do
   if not solid(cx,cy)then
    local a,b,c,d={cx*CS,H,cy*CS},{(cx+1)*CS,H,cy*CS},{(cx+1)*CS,H,(cy+1)*CS},{cx*CS,H,(cy+1)*CS}
    Ec.quad(a,b,c,d,o.ceiling or'ktLime',.9)
   end
  end end
 end
 return C.shellBox
end

-- TEST178: a pane ScenicViews looks out of (the real town beyond a window
-- or an open door), on any frame L: span a..b along its x, lo..hi up, at
-- depth z; `inward` is +1 when the frame's +z points into the room (a wall
-- frame), -1 when it points out (a door's frame). The facing, the side and
-- the corner order come from the frame itself, so a window on any wall (or
-- turned on a run) exports correctly.
-- TEST178: a wall's dressing never crosses its doorways. A style draws its
-- bands, plinths and glass along the whole run; through this frame every
-- box (and every flat wall-aligned rectangle) that crosses a door hole
-- below the door head is cut round it, keeping what stands above the head.
-- (Before, a Mart's blue band and a gym's plinth ran straight across the
-- open front door.)
local function cutSpans(a,b,holes)
 local segs={{a,b}}
 for _,h in ipairs(holes)do
  local out={}
  for _,sg in ipairs(segs)do
   if sg[2]<=h[1]or sg[1]>=h[2]then out[#out+1]=sg
   else
    if sg[1]<h[1]then out[#out+1]={sg[1],h[1]}end
    if sg[2]>h[2]then out[#out+1]={h[2],sg[2]}end
   end
  end
  segs=out
 end
 return segs
end
M.cutSpans=cutSpans
function M.holeSafe(L,run,top)
 local holes=run and run.holes
 if not holes or #holes==0 then return L end
 local P=setmetatable({},{__index=L})
 local function crosses(x0,x1)
  for _,h in ipairs(holes)do if x0<h[2]and x1>h[1]then return true end end
  return false
 end
 function P.box(x0,y0,z0,x1,y1,z1,mat,t,skip)
  if y0>=top or not crosses(min(x0,x1),max(x0,x1))then return L.box(x0,y0,z0,x1,y1,z1,mat,t,skip)end
  for _,sg in ipairs(cutSpans(x0,x1,holes))do L.box(sg[1],y0,z0,sg[2],y1,z1,mat,t,skip)end
  -- what stands above the door head stays whole
  if y1>top then
   for _,h in ipairs(holes)do
    local a,b=max(x0,h[1]),min(x1,h[2])
    if b>a then L.box(a,top,z0,b,y1,z1,mat,t,skip)end
   end
  end
 end
 -- only a flat rectangle in the wall's plane is cut; anything else passes
 local function cutRect(a,b,c,d,mat,t,draw)
  if not(a[3]==b[3]and b[3]==c[3]and c[3]==d[3])then return false end
  local xs={a[1],b[1],c[1],d[1]};local ys={a[2],b[2],c[2],d[2]}
  local x0,x1=min(xs[1],xs[2],xs[3],xs[4]),max(xs[1],xs[2],xs[3],xs[4])
  local y0,y1=min(ys[1],ys[2],ys[3],ys[4]),max(ys[1],ys[2],ys[3],ys[4])
  for i=1,4 do
   if not((xs[i]==x0 or xs[i]==x1)and(ys[i]==y0 or ys[i]==y1))then return false end
  end
  if y0>=top or not crosses(x0,x1)then return false end
  -- each piece keeps the winding: a corner keeps its side of the rectangle
  local z=a[3]
  local function emit(u0,u1,v0,v1)
   local function X(x)return x==x0 and u0 or u1 end
   local function Y(y)return y==y0 and v0 or v1 end
   draw({X(a[1]),Y(a[2]),z},{X(b[1]),Y(b[2]),z},{X(c[1]),Y(c[2]),z},{X(d[1]),Y(d[2]),z},mat,t)
  end
  for _,sg in ipairs(cutSpans(x0,x1,holes))do emit(sg[1],sg[2],y0,y1)end
  if y1>top then
   for _,h in ipairs(holes)do
    local p0,p1=max(x0,h[1]),min(x1,h[2])
    if p1>p0 then emit(p0,p1,top,y1)end
   end
  end
  return true
 end
 function P.quad(a,b,c,d,mat,t)
  if not cutRect(a,b,c,d,mat,t,L.quad)then L.quad(a,b,c,d,mat,t)end
 end
 if L.raw then
  function P.raw(a,b,c,d,mat,v)
   if not cutRect(a,b,c,d,mat,v,L.raw)then L.raw(a,b,c,d,mat,v)end
  end
 end
 return P
end
-- (a wall run's own frame, for a style that only has the run's model)
function M.runFrame(C,run)
 local ox,oz,yaw
 if run.o=='S'then ox,oz,yaw=run.a0,run.c,0
 elseif run.o=='N'then ox,oz,yaw=run.a1,run.c,pi
 elseif run.o=='E'then ox,oz,yaw=run.c,run.a1,pi/2
 else ox,oz,yaw=run.c,run.a0,-pi/2 end
 return M.frame(C,run.E,ox,0,oz,yaw)
end
-- o.split: a long span (a glass wall) is exported in pieces no wider than
-- this, all sharing ONE eye (the span's centre), so each piece is sharp and
-- the pieces line up at their joins.
function M.pane(C,L,a,b,lo,hi,z,inward,o)
 if not C.panes then return end
 local P=L.P
 local o0,o1=P({0,0,0}),P({0,0,1})
 local dx,dz=(o1[1]-o0[1])*(inward or 1),(o1[3]-o0[3])*(inward or 1)
 local l=sqrt(dx*dx+dz*dz);if l<1e-6 then return end
 dx,dz=dx/l,dz/l
 local side
 if dz>.7 then side='north' elseif dz<-.7 then side='south'
 elseif dx>.7 then side='west' elseif dx<-.7 then side='east' else return end
 local yaw=math.atan2(-dx,dz)
 local split=o and o.split
 local n=(split and b-a>split*1.05)and math.ceil((b-a)/split)or 1
 local center=n>1 and P({(a+b)/2,(lo+hi)/2,z})or nil
 for i=0,n-1 do
  local pa,pb=a+(b-a)*i/n,a+(b-a)*(i+1)/n
  local c1,c2,c3,c4=P({pa,lo,z}),P({pb,lo,z}),P({pb,hi,z}),P({pa,hi,z})
  -- the view's right is (dz,-dx): the first corner is its left end
  if (c2[1]-c1[1])*dz-(c2[3]-c1[3])*dx<0 then c1,c2,c3,c4=c2,c1,c4,c3 end
  C.panes[#C.panes+1]={side=side,corners={c1,c2,c3,c4},yaw=yaw,center=center}
 end
end

-- Recessed exit joinery. The complete source warp span stays open; door
-- leaves sit beyond the threshold, OUTSIDE the map and the player's path.
-- A painted sky at the threshold looked like a blue wall on exit.
local function exitRecess(L,a,b,top,o)
 local fm=o.frame or'white';local depth=24
 L.box(a-2,0,-1.4,a,top+2,depth,fm,1.0)
 L.box(b,0,-1.4,b+2,top+2,depth,fm,1.0)
 L.box(a-2,top,-1.6,b+2,top+2.2,depth,fm,1.04)
 L.box(a,-.12,-.6,b,.04,depth,o.sill or'inStone',.88)
 -- A pair of actual paneled outer doors closes the view beyond the warp,
 -- rather than a flat blue sky image (or a featureless black opening).
 local leaf=o.leaf or(o.glassDoors and'inSteel'or'inOak')
 if leaf=='ktGlass'then leaf='ktMarine'end
 L.box(a,0,depth,b,top,depth+1,leaf,.9)
 local half=(b-a)/2
 for i=0,1 do
  local x=a+i*half
  L.box(x+.3,.4,depth-.45,x+half-.3,top-.4,depth,leaf,1)
  for _,band in ipairs({{3,11},{14,top-3}})do
   local lo,hi=band[1],band[2]
   if hi>lo then
    L.box(x+1.4,lo,depth-.7,x+half-1.4,hi,depth-.4,fm,.85)
    L.box(x+2,lo+.6,depth-.9,x+half-2,hi-.6,depth-.65,leaf,1.0)
   end
  end
  local hx=i==0 and x+half-1.5 or x+1
  L.box(hx,14,depth-1.6,hx+.5,19,depth-.9,'lgGold',1.1)
 end
end
-- The front door in the south wall over the exit mats: a frame, the door
-- standing open, and the bright day beyond. x0,x1 world span.
-- TEST178: the doorway is a pane onto the real street (the painted day
-- stays behind it for when there is no view); the sill runs out under it.
function M.frontDoor(C,x0,x1,o)
 o=o or{}
 local S=C.shellBox
 local E=C.part('decor:S',{axis='z',c=S.s,s=-1})
 -- yaw 0 at the south wall: -z is the room, +z the street
 local L=M.frame(C,E,0,0,S.s,0)
 exitRecess(L,x0,x1,o.top or 34,o)
 -- TEST95/178: the live street appears at the back of our deep reveal;
 -- the existing physical outer doors remain the fallback while it loads.
 if not o.inside and o.scenic~=false then M.pane(C,L,x0,x1,0,o.top or 34,23.8,-1)end
end
-- An exit through an outer wall (a gate's road door): side 'N'|'S'|'W'|'E',
-- span a..b along it (world x for N/S, world z for W/E).
function M.exitPortal(C,side,a,b,o)
 o=o or{}
 local S=C.shellBox
 local E,L
 if side=='N'then E=C.part('decor:N',{axis='z',c=S.n,s=1});L=M.frame(C,E,0,0,S.n,pi)
  a,b=-b,-a
 elseif side=='S'then E=C.part('decor:S',{axis='z',c=S.s,s=-1});L=M.frame(C,E,0,0,S.s,0)
 elseif side=='W'then E=C.part('decor:W',{axis='x',c=S.w,s=1});L=M.frame(C,E,S.w,0,0,-pi/2)
 else E=C.part('decor:E',{axis='x',c=S.e,s=-1});L=M.frame(C,E,S.e,0,0,pi/2);a,b=-b,-a end
 -- local frame: x along the wall, +z OUT of the room
 exitRecess(L,a,b,o.top or 34,o)
 if not o.inside and o.scenic~=false then M.pane(C,L,a,b,0,o.top or 34,23.8,-1)end
end

------------------------------------------------------------------ windows
-- A window on a wall frame Lw (onWall): span a..b (along), sill lo, head hi.
-- o: frame, curtain (nil|'lace'|'drape'|'cafe'|'blind'|'valance'), cloth,
-- view (inWindow variant), panes ({cols,rows}), shutters, box (flower box),
-- scenic (false: no pane for ScenicViews; TEST178 exports every other)
function M.window(C,Lw,a,b,lo,hi,o)
 o=o or{}
 local fm=o.frame or'white'
 local mid=(a+b)/2
 -- reveal and glass (the view sits back in the reveal)
 Lw.box(a-1.4,lo-1.4,-.1,b+1.4,hi+1.4,.7,fm,1.08)
 Lw.raw({a,lo,.75},{b,lo,.75},{b,hi,.75},{a,hi,.75},'inWindow',o.view or 1)
 -- TEST178: every window looks out at the real town (scenic=false keeps
 -- the painted view only); its facing comes from the wall frame
 if o.scenic~=false then M.pane(C,Lw,a,b,lo,hi,.9,1)end
 -- glazing bars
 local cols,rows=(o.panes and o.panes[1])or 2,(o.panes and o.panes[2])or 2
 for i=1,cols-1 do local x=a+(b-a)*i/cols;Lw.box(x-.35,lo,.7,x+.35,hi,1.2,fm,1.05)end
 for j=1,rows-1 do local y=lo+(hi-lo)*j/rows;Lw.box(a,y-.35,.7,b,y+.35,1.2,fm,1.05)end
 -- sill
 Lw.box(a-2.2,lo-2.2,-.1,b+2.2,lo-1.2,2.4,fm,1.12)
 if o.box then
  Lw.box(a-.5,lo-1.2,1.0,b+.5,lo+2.2,3.4,o.box,1.0)
  for i=0,floor((b-a)/2.2)do
   local x=a+.8+i*2.2
   Lw.box(x-.5,lo+2.2,1.6,x+.5,lo+3.6+rh(i,a,3)*1.5,2.8,'lgLeaf',1.05)
   Lw.box(x-.7,lo+3.4+rh(i,a,4)*1.5,1.5,x+.7,lo+4.6+rh(i,a,4)*1.5,2.9,({'flower','gold','white','red'})[i%4+1],1.15)
  end
 end
 local cloth=o.cloth or'white'
 local cur=o.curtain
 if cur=='lace'or cur=='drape'then
  local deep=cur=='drape'
  -- the rod and the gathered panels, tied back
  Lw.box(a-4.5,hi+3,1.8,b+4.5,hi+3.6,2.4,o.rod or'lgBronze',1.1)
  for s=0,1 do
   local c0=s==0 and a-4.2 or b-2.6;local c1=s==0 and a+2.6 or b+4.2
   local n=5
   for k=0,n-1 do
    local x=c0+k*(c1-c0)/n
    Lw.box(x,lo-(deep and 6 or 3),1.9+(k%2)*.5,x+(c1-c0)/n+.1,hi+3,2.6+(k%2)*.6,cloth,1.0+(k%2)*.08)
   end
   Lw.box(c0-.2,lo+4,2.8,c1+.2,lo+5,3.4,o.tie or'lgGold',1.1)
  end
  if cur=='lace'then
   local x=a-3.6
   while x<b+3.2 do Lw.box(x,hi-.4+(floor(x)%2)*.3,2.4,x+1.5,hi+3,3.1,cloth,1.12);x=x+1.6 end
  else
   Lw.box(a-4.6,hi+2.4,2.6,b+4.6,hi+5.4,3.6,o.valance or cloth,1.02)
  end
 elseif cur=='cafe'then
  Lw.box(a-.5,(lo+hi)/2,1.6,b+.5,(lo+hi)/2+.5,2.0,o.rod or'lgBronze',1.1)
  local x=a
  while x<b-.1 do Lw.box(x,lo+.2,1.8+(floor(x)%2)*.3,min(b,x+1.4),(lo+hi)/2,2.3+(floor(x)%2)*.3,cloth,1.06);x=x+1.4 end
  Lw.box(a-1,hi-2,1.8,b+1,hi+.6,2.6,cloth,1.04)
 elseif cur=='blind'then
  local y=hi-1
  while y>lo+(hi-lo)*.45 do Lw.box(a,y-.5,1.3,b,y,1.9,cloth,1.05);y=y-1.2 end
  Lw.box(a-.5,hi,1.1,b+.5,hi+1.4,2.2,cloth,1.0)
 elseif cur=='valance'then
  Lw.box(a-3,hi+1,1.5,b+3,hi+4,3.0,cloth,1.04)
  local x=a-3
  while x<b+2.4 do Lw.box(x,hi-.6,1.6,x+1.2,hi+1,3.0,cloth,1.0);x=x+2.4 end
 end
 if o.shutters then
  local w=(b-a)/2+.6
  Lw.box(a-w-1.6,lo-.5,-.1,a-1.6,hi+.5,1.2,o.shutters,1.0)
  Lw.box(b+1.6,lo-.5,-.1,b+w+1.6,hi+.5,1.2,o.shutters,1.0)
  for k=0,floor((hi-lo)/2)do
   local y=lo+k*2+.5
   Lw.box(a-w-1.2,y,1.2,a-2,y+.5,1.5,o.shutters,.85)
   Lw.box(b+2,y,1.2,b+w+1.2,y+.5,1.5,o.shutters,.85)
  end
 end
end

-- A round porthole (Vermilion, the ship-built houses)
function M.porthole(C,Lw,x,y,r,o)
 o=o or{}
 Lw.ring(x,y,.2,r,r+1.6,o.rim or'lgBronze',18,1.1)
 Lw.ring(x,y,.9,r-.5,r+.4,o.rim or'lgBronze',18,1.2)
 local n=16
 for i=0,n-1 do
  local a0,a1=i/n*pi*2,(i+1)/n*pi*2
  Lw.raw({x,y,.4},{x+cos(a0)*r,y+sin(a0)*r,.4},{x+cos(a1)*r,y+sin(a1)*r,.4},{x,y,.4},'inWindow',o.view or 2)
 end
 for i=0,5 do local a=i*pi/3;Lw.box(x+cos(a)*(r+.8)-.35,y+sin(a)*(r+.8)-.35,1.0,x+cos(a)*(r+.8)+.35,y+sin(a)*(r+.8)+.35,1.6,'lgGold',1.2)end
end

------------------------------------------------------------------ pictures
-- A framed picture on a wall frame: a..b along, lo..hi. scene: 'meadow',
-- 'sea','mountain','flowers','portrait','pokemon','abstract','city','night',
-- 'map','ship','fish','bird','fossil','pagoda','sunset','tree'
local function patch(Lw,a,b,lo,hi,z,mat,t)Lw.quad({a,lo,z},{b,lo,z},{b,hi,z},{a,hi,z},mat,t)end
M.patch=patch
function M.picture(C,Lw,a,b,lo,hi,scene,o)
 o=o or{}
 local fr=o.frame or'lgGold'
 local m=o.mat or 1.4
 Lw.box(a-m,lo-m,0,b+m,hi+m,.9,fr,1.05)
 Lw.box(a-m*.45,lo-m*.45,.9,b+m*.45,hi+m*.45,1.05,o.inner or fr,.85)
 local z=1.1
 local W,Hh=b-a,hi-lo
 local function y(f)return lo+Hh*f end
 local function x(f)return a+W*f end
 if o.mount~=false and scene~='portrait'then patch(Lw,a,b,lo,hi,z,'cream',1.05);z=z+.05 end
 if scene=='sea'then
  patch(Lw,a,b,y(.45),hi,z,'ktPearl',1.15);patch(Lw,a,b,lo,y(.48),z+.02,'ktMarine',1.05)
  patch(Lw,x(.55),x(.62),y(.48),y(.80),z+.05,'white',1.2);patch(Lw,x(.45),x(.72),y(.42),y(.50),z+.05,'wood',.9)
  patch(Lw,x(.1),x(.25),y(.75),y(.82),z+.04,'white',1.15)
 elseif scene=='meadow'or scene=='tree'then
  patch(Lw,a,b,y(.4),hi,z,'ktPearl',1.12);patch(Lw,a,b,lo,y(.42),z+.02,'leaf',1.05)
  patch(Lw,x(.0),x(.45),y(.38),y(.55),z+.03,'sage',1.0)
  if scene=='tree'then
   patch(Lw,x(.47),x(.53),y(.35),y(.6),z+.05,'wood',.9)
   for i=0,5 do local ax,ay=x(.5)+(rh(i,1,1)-.5)*W*.3,y(.66)+(rh(i,2,1)-.5)*Hh*.25
    patch(Lw,ax-W*.1,ax+W*.1,ay-Hh*.1,ay+Hh*.1,z+.06,i%2==0 and'leaf'or'green',1.05)end
  else
   for i=0,6 do local fx=x(.08+i*.13);patch(Lw,fx,fx+W*.03,y(.12),y(.2),z+.05,({'flower','gold','white','red'})[i%4+1],1.2)end
  end
  patch(Lw,x(.72),x(.86),y(.78),y(.9),z+.04,'gold',1.3)
 elseif scene=='mountain'then
  patch(Lw,a,b,lo,hi,z,'ktPearl',1.12)
  Lw.quad({a,y(.3),z+.02},{x(.45),y(.3),z+.02},{x(.28),y(.85),z+.02},{x(.28),y(.85),z+.02},'lvStone',1.0)
  Lw.quad({x(.3),y(.3),z+.03},{b,y(.3),z+.03},{x(.68),y(.95),z+.03},{x(.68),y(.95),z+.03},'lvSlate',1.05)
  Lw.quad({x(.6),y(.82),z+.04},{x(.76),y(.82),z+.04},{x(.68),y(.95),z+.04},{x(.68),y(.95),z+.04},'white',1.25)
  patch(Lw,a,b,lo,y(.32),z+.05,'leaf',1.0)
 elseif scene=='flowers'then
  patch(Lw,a,b,lo,hi,z,o.ground or'cream',1.1)
  Lw.box(x(.38),lo+.4,z,x(.62),y(.32),z+.6,'ktPearl',1.1)
  for i=0,6 do local fx=x(.3+rh(i,3,2)*.4);local fy=y(.45+rh(i,4,2)*.4)
   Lw.box(x(.5)-.15,y(.3),z+.3,x(.5)+.15,fy,z+.4,'leaf',1.0)
   Lw.box(fx-W*.06,fy-W*.05,z+.4,fx+W*.06,fy+W*.05,z+.7,({'flower','red','gold','white','flower'})[i%5+1],1.15)end
 elseif scene=='portrait'then
  patch(Lw,a,b,lo,hi,z,o.ground or'ktOchre',.95)
  Lw.box(x(.3),lo,z,x(.7),y(.55),z+.3,o.coat or'navy',1.0)
  Lw.box(x(.38),y(.5),z,x(.62),y(.8),z+.4,'ktOchre',1.15)
  Lw.box(x(.36),y(.72),z+.2,x(.64),y(.88),z+.5,o.hair or'wood',.9)
 elseif scene=='pokemon'then
  -- a trainer's poster: a ball against a burst of rays
  patch(Lw,a,b,lo,hi,z,o.ground or'ktPearl',1.12)
  local cx,cy,r=x(.5),y(.5),min(W,Hh)*.3
  -- (each ray runs out to the frame's edge, never past it)
  local function edge(t)local c,s=cos(t),sin(t)
   local k=min(abs(c)>1e-4 and W*.5/abs(c)or 1e9,abs(s)>1e-4 and Hh*.5/abs(s)or 1e9)
   return {cx+c*k,cy+s*k,z+.03}end
  for i=0,11 do local a0=i/12*pi*2;local a1=a0+pi/12
   Lw.quad({cx,cy,z+.03},edge(a0),edge(a1),{cx,cy,z+.03},o.body or'gold',1.1)end
  for i=0,15 do local a0,a1=i/16*pi*2,(i+1)/16*pi*2
   Lw.quad({cx,cy,z+.1},{cx+cos(a0)*r,cy+sin(a0)*r,z+.1},{cx+cos(a1)*r,cy+sin(a1)*r,z+.1},{cx,cy,z+.1},sin(a0+.2)>0 and'inLacquer'or'inEnamel',1.05)end
  Lw.box(cx-r,cy-r*.08,z+.1,cx+r,cy+r*.08,z+.2,'dark',1)
  Lw.disc(cx,cy,z+.25,r*.3,'dark',10);Lw.disc(cx,cy,z+.3,r*.2,'inEnamel',10,nil,1.1)
 elseif scene=='city'then
  patch(Lw,a,b,y(.5),hi,z,'ktPearl',1.15)
  for i=0,6 do local bx=x(i/7);local bh=.35+rh(i,7,1)*.5
   patch(Lw,bx,bx+W/7-.3,lo,y(bh+.1),z+.03,i%2==0 and'ktSteel'or'lvSlate',1.0)
   for k=0,3 do patch(Lw,bx+.5,bx+1.1,y(.12+k*.12),y(.17+k*.12),z+.06,'gold',1.3)end
  end
 elseif scene=='night'then
  patch(Lw,a,b,lo,hi,z,'navy',.7)
  Lw.disc(x(.75),y(.75),z+.1,min(W,Hh)*.12,'cream',12,nil,1.3)
  for i=0,9 do local sx,sy=x(rh(i,1,9)),y(.4+rh(i,2,9)*.55);patch(Lw,sx,sx+.4,sy,sy+.4,z+.08,'white',1.3)end
  patch(Lw,a,b,lo,y(.3),z+.05,'dark',.8)
 elseif scene=='map'then
  patch(Lw,a,b,lo,hi,z,'ktMarine',1.0)
  for i=0,5 do local mx,my=x(.1+rh(i,1,4)*.7),y(.1+rh(i,2,4)*.7)
   patch(Lw,mx,mx+W*(.12+rh(i,3,4)*.18),my,my+Hh*(.1+rh(i,5,4)*.15),z+.04,i%2==0 and'leaf'or'sage',1.05)end
  for i=0,7 do local px,py=x(.1+rh(i,6,4)*.8),y(.1+rh(i,7,4)*.8);patch(Lw,px,px+.6,py,py+.6,z+.08,'red',1.2)end
  for i=0,3 do patch(Lw,x(.15+i*.2),x(.17+i*.2),y(.2),y(.8),z+.06,'cream',1.0)end
 elseif scene=='ship'then
  patch(Lw,a,b,y(.4),hi,z,'ktPearl',1.15);patch(Lw,a,b,lo,y(.42),z+.02,'ktMarine',1.05)
  Lw.quad({x(.2),y(.42),z+.05},{x(.8),y(.42),z+.05},{x(.72),y(.28),z+.05},{x(.28),y(.28),z+.05},'wood',.9)
  patch(Lw,x(.49),x(.51),y(.42),y(.9),z+.06,'wood',.9)
  Lw.quad({x(.52),y(.5),z+.07},{x(.75),y(.5),z+.07},{x(.52),y(.88),z+.07},{x(.52),y(.88),z+.07},'white',1.2)
  Lw.quad({x(.48),y(.5),z+.07},{x(.48),y(.82),z+.07},{x(.3),y(.5),z+.07},{x(.3),y(.5),z+.07},'cream',1.15)
 elseif scene=='fish'then
  patch(Lw,a,b,lo,hi,z,'ktPearl',1.05)
  local cx,cy=x(.5),y(.5)
  Lw.quad({x(.15),cy,z+.1},{cx,y(.8),z+.1},{x(.8),cy,z+.1},{cx,y(.2),z+.1},'ktCopper',1.1)
  Lw.quad({x(.8),cy,z+.1},{x(.95),y(.75),z+.1},{x(.95),y(.25),z+.1},{x(.8),cy,z+.1},'ktCopper',1.0)
  Lw.disc(x(.25),y(.55),z+.2,.6,'dark',6,nil,1)
 elseif scene=='bird'then
  patch(Lw,a,b,lo,hi,z,'ktPearl',1.15)
  local cx,cy=x(.5),y(.55)
  Lw.quad({cx-W*.35,cy+Hh*.2,z+.1},{cx,cy,z+.1},{cx+W*.35,cy+Hh*.2,z+.1},{cx,cy-Hh*.1,z+.1},'ktOchre',1.0)
  Lw.disc(cx,cy,z+.15,min(W,Hh)*.1,'ktOchre',8,nil,1.05)
  patch(Lw,a,b,lo,y(.2),z+.05,'leaf',1.0)
 elseif scene=='fossil'then
  patch(Lw,a,b,lo,hi,z,'ktSandstone',1.0)
  local cx,cy=x(.5),y(.5);local r=min(W,Hh)*.35
  for i=0,10 do local t=i/10;local ang=t*pi*3.2;local rr=r*(1-t*.85)
   Lw.disc(cx+cos(ang)*rr*.8,cy+sin(ang)*rr*.8,z+.1+i*.01,r*.22*(1-t*.6),'cream',8,nil,1.1)end
 elseif scene=='pagoda'then
  patch(Lw,a,b,lo,hi,z,'cream',1.08)
  for i=0,2 do local yy=y(.25+i*.22);local hw=W*(.3-i*.07)
   Lw.quad({x(.5)-hw,yy,z+.05},{x(.5)+hw,yy,z+.05},{x(.5)+hw*.6,yy+Hh*.08,z+.05},{x(.5)-hw*.6,yy+Hh*.08,z+.05},'red',1.0)
   patch(Lw,x(.5)-hw*.5,x(.5)+hw*.5,yy-Hh*.12,yy,z+.04,'wood',.9)end
  Lw.disc(x(.78),y(.8),z+.06,min(W,Hh)*.08,'red',10,nil,1.2)
 elseif scene=='sunset'then
  patch(Lw,a,b,y(.4),hi,z,'ktOchre',1.15);patch(Lw,a,b,y(.62),hi,z+.01,'flower',1.0)
  Lw.disc(x(.5),y(.45),z+.05,min(W,Hh)*.18,'gold',12,nil,1.35)
  patch(Lw,a,b,lo,y(.42),z+.08,'navy',.85)
 elseif scene=='abstract'then
  patch(Lw,a,b,lo,hi,z,'white',1.1)
  patch(Lw,x(.1),x(.45),y(.5),y(.9),z+.04,'red',1.05);patch(Lw,x(.5),x(.9),y(.1),y(.45),z+.04,'blue',1.05)
  patch(Lw,x(.55),x(.75),y(.55),y(.85),z+.05,'gold',1.2);patch(Lw,x(.15),x(.35),y(.1),y(.35),z+.05,'dark',.9)
 else
  patch(Lw,a,b,lo,hi,z,'ktPearl',1.1)
 end
end

------------------------------------------------------------------ clocks
function M.clock(C,Lw,x,y,r,o)
 o=o or{}
 Lw.disc(x,y,.2,r+.9,o.case or'inWalnut',20,nil,1.0)
 Lw.ring(x,y,.9,r,r+.9,o.rim or'lgGold',20,1.15)
 Lw.disc(x,y,.6,r,'cream',20,nil,1.15)
 for i=0,11 do local a=i*pi/6
  Lw.box(x+cos(a)*r*.8-.18,y+sin(a)*r*.8-.18,.6,x+cos(a)*r*.8+.18,y+sin(a)*r*.8+.18,.75,'dark',.8)end
 Lw.box(x-.15,y,.75,x+.15,y+r*.55,.85,'dark',.8)
 Lw.box(x,y-.15,.75,x+r*.72,y+.15,.85,'dark',.8)
end
-- a long-case clock standing on the floor (local frame, front +z)
function M.grandfather(L,o)
 o=o or{}
 local wd=o.wood or'inWalnut'
 L.box(-4,0,-3,4,3,3,wd,.9)
 L.box(-3.2,3,-2.4,3.2,26,2.4,wd,1.0)
 L.box(-3.8,26,-3,3.8,36,3,wd,1.02)
 L.box(-4.2,36,-3.2,4.2,37.4,3.2,wd,1.08)
 L.quad({-3.6,37.4,0},{3.6,37.4,0},{0,40.5,0},{0,40.5,0},wd,1.05)
 L.disc(0,31,3.05,2.9,'cream',16,nil,1.15)
 L.ring(0,31,3.1,2.9,3.4,'lgGold',16,1.2)
 L.box(-.12,31,3.15,.12,33.2,3.25,'dark',.8);L.box(0,30.88,3.15,1.8,31.12,3.25,'dark',.8)
 L.box(-2.2,6,2.4,2.2,24,2.5,'dark',.5)
 L.box(-2.4,6,2.5,2.4,24,2.7,'ktGlass',1.2)
 L.box(-.2,10,2.2,.2,22,2.3,'lgGold',1.1)
 L.disc(0,10.5,2.32,1.4,'lgGold',10,nil,1.2)
end

------------------------------------------------------------------ furniture
-- A bookcase (local frame: x -w/2..w/2, back at z=-d/2, front +z), h tall.
-- o: wood, items ('books'|'goods'|'curios'|'jars'|'shells'|'trophies'|
-- 'plates'|'fossils'|'scrolls'|'rocks'|'dolls'|'tackle'|'files'|'toys'|
-- 'potions'|'models'|'mixed'), doors (lower cupboard), glass (mullioned
-- doors over the shelves), crown, seed
function M.bookcase(L,w,h,d,o)
 o=o or{}
 local wd=o.wood or'inWalnut'
 local hw,hd=w/2,d/2
 local seed=o.seed or 1
 L.box(-hw,0,-hd,hw,h,-hd+.6,wd,.8)                        -- back
 L.box(-hw,0,-hd,-hw+1,h,hd,wd,.95);L.box(hw-1,0,-hd,hw,h,hd,wd,.95)
 L.box(-hw-.4,h,-hd-.2,hw+.4,h+1.4,hd+.6,wd,1.05)            -- top
 if o.crown~=false then L.box(-hw-.8,h+1.4,-hd-.2,hw+.8,h+2.2,hd+1.0,wd,1.1)end
 L.box(-hw,0,hd-1.2,hw,2.2,hd+.2,wd,.85)                     -- plinth
 local doorsTop=o.doors and 14 or 2.2
 if o.doors then
  L.box(-hw+1,2.2,-hd+.6,hw-1,doorsTop,hd,wd,1.0)
  local n=max(1,floor(w/9+.5));local dw=(w-2)/n
  for i=0,n-1 do local a=-hw+1+i*dw
   L.box(a+.4,3,hd,a+dw-.4,doorsTop-.8,hd+.4,wd,1.06)
   L.box(a+1.2,3.8,hd+.4,a+dw-1.2,doorsTop-1.6,hd+.55,wd,.94)
   L.box(a+dw/2-.35,doorsTop-3.6,hd+.55,a+dw/2+.35,doorsTop-2.6,hd+1.0,'lgGold',1.15)
  end
  L.box(-hw+.6,doorsTop,-hd+.6,hw-.6,doorsTop+.8,hd+.4,wd,1.05)
 end
 -- shelves every 8 units (the inBooks/inGoods rows line up with y=8k)
 local y=floor(doorsTop/8+.999)*8
 local rows={}
 while y<h-5 do rows[#rows+1]=y;y=y+8 end
 for i,yy in ipairs(rows)do
  L.box(-hw+1,yy-.6,-hd+.6,hw-1,yy,hd,wd,1.02)
  local kind=o.items or'books'
  if kind=='mixed'then kind=({'books','curios','books','plates','books','jars'})[(i+seed)%6+1]end
  if type(o.rowItems)=='table'then kind=o.rowItems[(i-1)%#o.rowItems+1]end
  M.shelfItems(L,kind,-hw+1.2,hw-1.2,yy,min(yy+7.4,h-.2),-hd+.6,hd-.4,seed*7+i)
 end
 if o.glass then
  -- mullioned glass doors over the shelves (a frame, the panes as bars)
  local top,bot=h-.2,doorsTop+.8
  local n=max(1,floor(w/9+.5));local dw=(w-2)/n
  for i=0,n-1 do local a=-hw+1+i*dw
   L.box(a,bot,hd+.1,a+.6,top,hd+.7,wd,1.05);L.box(a+dw-.6,bot,hd+.1,a+dw,top,hd+.7,wd,1.05)
   L.box(a,top-.6,hd+.1,a+dw,top,hd+.7,wd,1.05);L.box(a,bot,hd+.1,a+dw,bot+.6,hd+.7,wd,1.05)
   L.box(a+dw/2-.2,bot,hd+.2,a+dw/2+.2,top,hd+.6,wd,1.0)
  end
 end
end
-- the contents of one shelf row between x0..x1, standing on y0, under y1
function M.shelfItems(L,kind,x0,x1,y0,y1,zb,zf,seed)
 local zc=(zb+zf)/2
 if kind=='books'or kind=='files'then
  -- a run of spines (inBooks), with a gap or a leaning book now and then
  local f=zf-1.0
  L.quad({x0,y0,f},{x1,y0,f},{x1,y1-.3,f},{x0,y1-.3,f},kind=='files'and'inGoods'or'inBooks',1)
  L.quad({x0,y1-.3,zb+.5},{x1,y1-.3,zb+.5},{x1,y1-.3,f},{x0,y1-.3,f},'inBooks',.6)
  if rh(seed,2,3)>.5 then
   local x=x0+(x1-x0)*(.2+.6*rh(seed,3,3))
   L.box(x,y0,zb+1,x+3.2,y0+2.6,zf-1,'inLeather',1.0)
   L.box(x+.4,y0+2.6,zb+1.4,x+2.8,y0+3.6,zf-1.4,'navy',1.0)
  end
 elseif kind=='goods'or kind=='potions'then
  local f=zf-1.0
  L.quad({x0,y0,f},{x1,y0,f},{x1,y1-.3,f},{x0,y1-.3,f},'inGoods',1)
  L.quad({x0,y1-.3,zb+.5},{x1,y1-.3,zb+.5},{x1,y1-.3,f},{x0,y1-.3,f},'inGoods',.6)
 elseif kind=='jars'then
  local n=max(2,floor((x1-x0)/3.2))
  for i=0,n-1 do local x=x0+(i+.5)*(x1-x0)/n
   local hh=3.2+rh(seed,i,1)*2.2
   L.cyl(x,y0,y0+hh,zc,1.1,1.1,'glass',8,false)
   L.cyl(x,y0+hh,y0+hh+.8,zc,1.2,1.2,({'red','cream','gold','sage'})[(i+seed)%4+1],8)
   L.cyl(x,y0+.2,y0+hh*.6,zc,.9,.9,({'gold','ktOchre','leaf','flower','ktCopper'})[(i*3+seed)%5+1],8)
  end
 elseif kind=='plates'then
  local n=max(1,floor((x1-x0)/6))
  for i=0,n-1 do local x=x0+(i+.5)*(x1-x0)/n
   L.box(x-.2,y0,zb+.8,x+.2,y0+1,zb+3,'inWalnut',.9)
   L.disc(x,y0+3,zb+1.2,2.8,'white',14,nil,1.12)
   L.ring(x,y0+3,zb+1.25,1.8,2.4,({'blue','flower','ktCopper','gold'})[(i+seed)%4+1],14,1.05)
  end
 elseif kind=='curios'or kind=='trophies'or kind=='models'or kind=='dolls'or kind=='toys'then
  local n=max(2,floor((x1-x0)/4.5))
  for i=0,n-1 do local x=x0+(i+.5)*(x1-x0)/n
   local r=rh(seed,i,7)
   if kind=='trophies'or(kind=='curios'and r<.25)then
    L.box(x-1.2,y0,zc-1.2,x+1.2,y0+.8,zc+1.2,'inWalnut',1)
    L.cyl(x,y0+.8,y0+2.6,zc,.35,.35,'lgGold',6)
    L.cyl(x,y0+2.6,y0+4.6,zc,.6,1.4,'lgGold',8,false)
   elseif kind=='models'or(kind=='curios'and r<.5)then
    L.cyl(x,y0,y0+.6,zc,1.6,1.6,'inWalnut',10)
    L.sphere(x,y0+2.6,zc,1.9,1.9,1.9,'ktMarine',10,6)
    L.sphere(x,y0+2.6,zc,1.95,.6,1.95,'leaf',10,3)
    L.rod({x,y0+.6,zc},{x,y0+4.8,zc},.12,'lgGold')
   elseif kind=='dolls'or kind=='toys'then
    local c=({'gold','flower','blue','red','leaf','white'})[(i+seed)%6+1]
    L.sphere(x,y0+1.4,zc,1.4,1.4,1.3,c,8,5)
    L.sphere(x,y0+3.4,zc,1.1,1.0,1.0,c,8,5)
    L.box(x-.9,y0+3.9,zc-.2,x-.4,y0+5.2,zc+.2,c,1);L.box(x+.4,y0+3.9,zc-.2,x+.9,y0+5.2,zc+.2,c,1)
    L.box(x-.45,y0+3.4,zc+.95,x-.15,y0+3.8,zc+1.05,'dark',1);L.box(x+.15,y0+3.4,zc+.95,x+.45,y0+3.8,zc+1.05,'dark',1)
   else
    L.cyl(x,y0,y0+3.6+r*1.5,zc,.9,1.4,({'ktCopper','blue','flower','ktTerracotta','white'})[(i+seed)%5+1],8)
    L.cyl(x,y0+3.6+r*1.5,y0+4.2+r*1.5,zc,.6,.6,'lgGold',8)
   end
  end
 elseif kind=='shells'then
  local n=max(2,floor((x1-x0)/3.6))
  for i=0,n-1 do local x=x0+(i+.5)*(x1-x0)/n
   if i%2==0 then L.sphere(x,y0+1,zc,1.6,1.0,1.2,({'cream','flower','white'})[i%3+1],8,4,i)
   else L.cyl(x,y0,y0+3.2,zc,1.2,.1,({'cream','ktOchre','white'})[i%3+1],6,true,i)end
  end
 elseif kind=='rocks'or kind=='fossils'then
  local n=max(2,floor((x1-x0)/4))
  for i=0,n-1 do local x=x0+(i+.5)*(x1-x0)/n
   if kind=='fossils'and i%2==0 then
    L.box(x-1.8,y0,zc-1.2,x+1.8,y0+.6,zc+1.2,'inWalnut',1)
    L.disc(x,y0+2.4,zc+.6,1.8,'ktSandstone',10,nil,1)
    for k=0,5 do local a=k*1.1;L.disc(x+cos(a)*(1.3-k*.2),y0+2.4+sin(a)*(1.3-k*.2),zc+.7,.35,'cream',6,nil,1.1)end
   else
    L.sphere(x,y0+1.2,zc,1.6+rh(i,seed,2)*.6,1.2+rh(i,seed,3)*.6,1.3,({'lgRock','lvSlate','ktSandstone','lgAmethyst','ktBasalt'})[(i+seed)%5+1],7,4,i+seed)
   end
  end
 elseif kind=='scrolls'then
  local n=max(2,floor((x1-x0)/2.4))
  for i=0,n-1 do local x=x0+(i+.5)*(x1-x0)/n
   L.cyl(x,y0+1,y0+1,zc,1,1,'cream',1)
   L.box(x-.9,y0,zb+1,x+.9,y0+1.8,zf-1,i%3==0 and'ktOchre'or'cream',1.05)
   L.box(x-1.0,y0+.6,zf-1,x+1.0,y0+1.2,zf-.8,'red',1)
  end
 elseif kind=='tackle'then
  for i=0,floor((x1-x0)/6)do local x=x0+3+i*6
   L.box(x-2.4,y0,zb+1,x+2.4,y0+3,zf-1,({'ktCopper','red','ktMarine'})[i%3+1],1.0)
   L.box(x-2.4,y0+3,zb+1,x+2.4,y0+3.4,zf-1,'ktSteel',1.1)
   L.box(x-.6,y0+3.4,zc-.3,x+.6,y0+3.9,zc+.3,'dark',1)
  end
 end
end

-- A cabinet / sideboard (front +z), w x h x d. o: wood, drawers (n), top
-- (material), legs, knobs
function M.cabinet(L,w,h,d,o)
 o=o or{}
 local wd=o.wood or'inWalnut'
 local hw,hd=w/2,d/2
 local legs=o.legs and 2.4 or 0
 if o.legs then
  for _,lx in ipairs({-hw+.6,hw-1.6})do for _,lz in ipairs({-hd+.6,hd-1.6})do L.box(lx,0,lz,lx+1,legs,lz+1,wd,.9)end end
 else L.box(-hw+.4,0,-hd+.4,hw-.4,1.2,hd-.6,'dark',.6)end
 L.box(-hw,legs+(o.legs and 0 or 1.2),-hd,hw,h-.8,hd,wd,1.0)
 L.box(-hw-.4,h-.8,-hd-.2,hw+.4,h,hd+.4,o.top or wd,1.08)
 local n=o.drawers or 2
 local y0,y1=legs+(o.legs and .6 or 1.8),h-1.4
 local rows=o.rows or 1
 local cols=n
 for r=0,rows-1 do
  local ya=y0+(y1-y0)*r/rows;local yb=y0+(y1-y0)*(r+1)/rows
  for i=0,cols-1 do local a=-hw+.6+i*(w-1.2)/cols;local b=a+(w-1.2)/cols
   L.box(a+.25,ya+.2,hd,b-.25,yb-.2,hd+.35,wd,1.06)
   local ky=rows>1 and (ya+yb)/2 or (yb-1.6)
   L.box((a+b)/2-.4,ky-.3,hd+.35,(a+b)/2+.4,ky+.3,hd+.8,o.knobs or'lgGold',1.15)
  end
 end
end

-- A table (local frame; centre at 0,0): w x d, top height `top`.
-- style: 'dining'|'round'|'kotatsu'|'trestle'|'glass'|'stone'|'desk'|'low'
-- o: wood, cloth (a tablecloth/runner mat), clothMat
function M.table(L,w,d,top,style,o)
 o=o or{}
 local wd=o.wood or'inOak'
 local hw,hd=w/2,d/2
 style=style or'dining'
 if style=='round'then
  local r=min(w,d)/2
  L.cyl(0,top-.9,top,0,r,r,wd,18)
  L.cyl(0,top-2.2,top-.9,0,r*.85,r,wd,18,false)
  L.cyl(0,1.2,top-2.2,0,.9,1.2,wd,8,false)
  L.cyl(0,0,1.2,0,r*.55,r*.35,wd,10)
  if o.cloth then L.cyl(0,top,top+.08,0,r*.62,r*.62,o.cloth,16)end
  return
 end
 if style=='kotatsu'then
  -- a low table over a quilt that spills to the floor
  L.box(-hw-2.4,0,-hd-2.4,hw+2.4,top-1.6,hd+2.4,o.quilt or'inRugRed',1.0)
  L.box(-hw-2.0,top-1.6,-hd-2.0,hw+2.0,top-1.2,hd+2.0,o.quilt or'inRugRed',1.05)
  L.box(-hw,top-1.2,-hd,hw,top,hd,wd,1.06)
  L.box(-hw-1.4,0,-hd-1.4,hw+1.4,.4,hd+1.4,o.quilt2 or'inRugGold',.95)
  return
 end
 if style=='stone'then
  L.box(-hw+2,0,-hd+2,hw-2,top-2,hd-2,'lgRock',.95)
  L.box(-hw,top-2,-hd,hw,top,hd,o.slab or'ktBasalt',1.05)
  return
 end
 if style=='glass'then
  L.box(-hw,top-.5,-hd,hw,top,hd,'ktGlass',1.15)
  L.box(-hw+.2,top-.9,-hd+.2,hw-.2,top-.5,hd-.2,'inSteel',1.05)
  for _,sx in ipairs({-1,1})do
   L.box(sx*hw-sx*1.2-.4,0,-hd+1,sx*hw-sx*1.2+.4,top-.9,-hd+1.8,'inSteel',1.0)
   L.box(sx*hw-sx*1.2-.4,0,hd-1.8,sx*hw-sx*1.2+.4,top-.9,hd-1,'inSteel',1.0)
   L.box(sx*hw-sx*1.2-.4,0,-hd+1,sx*hw-sx*1.2+.4,.6,hd-1,'inSteel',.9)
  end
  return
 end
 if style=='trestle'then
  L.box(-hw,top-1.4,-hd,hw,top,hd,wd,1.04)
  for _,sx in ipairs({-1,1})do
   local x=sx*(hw-3)
   L.box(x-.8,1.2,-1,x+.8,top-1.4,1,wd,.95)
   L.box(x-1,0,-hd+1,x+1,1.4,hd-1,wd,.9)
  end
  L.box(-hw+3,4,-.5,hw-3,5.2,.5,wd,.9)
  return
 end
 -- dining / desk / low: four legs and an apron
 local th=style=='low'and .9 or 1.0
 L.box(-hw,top-th,-hd,hw,top,hd,wd,1.04)
 L.box(-hw+.8,top-th-1.8,-hd+.8,hw-.8,top-th,hd-.8,wd,.86)
 for _,lx in ipairs({-hw+.9,hw-2.4})do for _,lz in ipairs({-hd+.9,hd-2.4})do
  L.box(lx,0,lz,lx+1.5,top-th,lz+1.5,wd,.9)
 end end
 if style=='desk'then
  L.box(hw-9,top-th-5,-hd+.8,hw-.8,top-th,hd-.8,wd,.98)
  for k=0,1 do L.box(hw-8.4,top-th-4.6+k*2.4,hd-.8,hw-1.4,top-th-2.6+k*2.4,hd-.4,wd,1.05)
   L.box(hw-5.2,top-th-3.8+k*2.4,hd-.4,hw-4.6,top-th-3.3+k*2.4,hd,'lgGold',1.15)end
 end
 if o.cloth then
  L.box(-hw-.3,top,-hd-.3,hw+.3,top+.08,hd+.3,o.cloth,1.1)
  -- the hem falling over the edges
  L.box(-hw-.4,top-2.6,hd+.2,hw+.4,top+.05,hd+.4,o.cloth,1.0)
  L.box(-hw-.4,top-2.6,-hd-.4,hw+.4,top+.05,-hd-.2,o.cloth,.9)
  L.box(-hw-.4,top-2.6,-hd-.3,-hw-.2,top+.05,hd+.3,o.cloth,.95)
  L.box(hw+.2,top-2.6,-hd-.3,hw+.4,top+.05,hd+.3,o.cloth,.95)
 end
 if o.runner then L.box(-hw+1.5,top,-1.8,hw-1.5,top+.1,1.8,o.runner,1.12)end
end

-- A seat on a walkable cell: the seat top at `seat` (the actor sits there).
-- style: 'spindle'|'stool'|'zabuton'|'modern'|'bench'|'arm'|'bar'|'log'
-- back: 'n'|'s'|'e'|'w' (which side the back is on) or nil
function M.seat(L,seat,style,back,o)
 o=o or{}
 local wd=o.wood or'inOak';local cu=o.cushion or'inRugRed'
 local r=o.r or 4.6
 if style=='zabuton'then
  L.box(-5,0,-5,5,1.2,5,cu,1.0);L.box(-4.6,1.2,-4.6,4.6,1.6,4.6,cu,1.08)
  L.box(-.6,1.6,-.6,.6,1.8,.6,o.tuft or'lgGold',1.1)
  return
 end
 if style=='log'then
  L.cyl(0,0,seat,0,r,r,'lgBark',10)
  L.cyl(0,seat-.01,seat,0,r-.3,r-.3,'inPine',10)
  return
 end
 if style=='stool'or style=='bar'then
  L.cyl(0,seat-1,seat,0,r,r,wd,12)
  L.cyl(0,seat-.2,seat+.3,0,r-.5,r-.5,cu,12)
  for i=0,3 do local a=i*pi/2+pi/4
   L.rod({cos(a)*r*.6,seat-1,sin(a)*r*.6},{cos(a)*r*.85,0,sin(a)*r*.85},.4,o.leg or wd)end
  L.ring(0,seat*.4,0,r*.6,r*.66,wd,10)
  return
 end
 if style=='modern'then
  L.box(-r,seat-1.4,-r,r,seat,r,o.shell or'inEnamel',1.05)
  L.box(-r+.6,seat,-r+.6,r-.6,seat+.4,r-.6,cu,1.05)
  L.cyl(0,0,seat-1.4,0,.5,.5,'inSteel',6)
  L.cyl(0,0,.4,0,r*.8,r*.8,'inSteel',10)
 else
  L.box(-r,seat-1,-r,r,seat-.3,r,wd,1.0)
  L.box(-r+.3,seat-.3,-r+.3,r-.3,seat,r-.3,cu,1.05)
  for _,lx in ipairs({-r+.3,r-1.5})do for _,lz in ipairs({-r+.3,r-1.5})do L.box(lx,0,lz,lx+1.2,seat-1,lz+1.2,wd,.9)end end
 end
 if back then
  local h=seat+(o.backH or 9)
  local function bk(x0,z0,x1,z1,horiz)
   L.box(x0,seat-1,z0,x0+1.1,h,z0+1.1,wd,.95)
   if horiz then L.box(x1-1.1,seat-1,z0,x1,h,z0+1.1,wd,.95);L.box(x0,h-2.2,z0-.1,x1,h,z0+1.2,wd,1.05)
    for k=1,3 do local x=x0+k*(x1-x0)/4;L.box(x-.35,seat,z0+.3,x+.35,h-2.2,z0+.8,wd,1.0)end
   else L.box(x0,seat-1,z1-1.1,x0+1.1,h,z1,wd,.95);L.box(x0-.1,h-2.2,z0,x0+1.2,h,z1,wd,1.05)
    for k=1,3 do local z=z0+k*(z1-z0)/4;L.box(x0+.3,seat,z-.35,x0+.8,h-2.2,z+.35,wd,1.0)end end
  end
  if back=='n'then bk(-r,-r,r,r,true)
  elseif back=='s'then bk(-r,r-1.1,r,r,true)
  elseif back=='w'then bk(-r,-r,r,r,false)
  else bk(r-1.1,-r,r,r,false)end
 end
end

-- A potted plant (local frame on the floor). kind: 'palm'|'fern'|'ficus'|
-- 'snake'|'bonsai'|'cactus'|'monstera'|'flowers'|'bamboo'|'orchid'|'tree'
-- o: pot (material), potR, potH, s (scale), seed
function M.plant(L,kind,o)
 o=o or{}
 local s=o.s or 1;local seed=o.seed or 3
 local pot=o.pot or'ktTerracotta'
 local pr,ph=(o.potR or 3.4)*s,(o.potH or 5.5)*s
 if kind~='bonsai'then
  L.cyl(0,0,ph,0,pr*.78,pr,pot,12,false)
  L.cyl(0,ph,ph+.7*s,0,pr*1.06,pr*1.06,pot,12,false)
  L.cyl(0,ph+.5*s,ph+.6*s,0,pr*.95,pr*.95,'forestFloor',12)
 end
 local top=ph+.6*s
 if kind=='palm'or kind=='tree'then
  local th=(kind=='palm'and 22 or 18)*s
  for i=0,5 do local t=i/6
   L.cyl((rh(seed,i,1)-.5)*.6*s,top+th*t,top+th*(t+1/6),(rh(seed,i,2)-.5)*.6*s,.75*s*(1-t*.4),.7*s*(1-(t+.17)*.4),'lgBark',6,false)end
  if kind=='palm'then
   for i=0,8 do local a=i/9*pi*2+rh(seed,i,3);local ln=(8+rh(seed,i,4)*4)*s
    local b={0,top+th,0};local m={cos(a)*ln*.55,top+th+2.4*s,sin(a)*ln*.55};local e={cos(a)*ln,top+th-3.2*s,sin(a)*ln}
    local px,pz=-sin(a)*1.6*s,cos(a)*1.6*s
    L.quad(b,{m[1]+px,m[2],m[3]+pz},e,e,'lgLeaf',1.05);L.quad(b,e,{m[1]-px,m[2],m[3]-pz},{m[1]-px,m[2],m[3]-pz},'forestCore',.9)
    L.quad({m[1]+px,m[2],m[3]+pz},{m[1]-px,m[2],m[3]-pz},e,e,'forestLeaf',1.0)
   end
  else
   for i=0,5 do local a=i*1.05+rh(seed,i,5);local r=(3+rh(seed,i,6)*2)*s
    L.sphere(cos(a)*r*.6,top+th*.8+(rh(seed,i,7)-.3)*5*s,sin(a)*r*.6,r,r*.8,r,'lgLeaf',7,4,seed+i)end
  end
 elseif kind=='fern'or kind=='monstera'or kind=='snake'then
  local n=kind=='snake'and 9 or 12
  for i=0,n-1 do local a=i/n*pi*2+rh(seed,i,1)
   local ln=(kind=='snake'and 13 or 9+rh(seed,i,2)*4)*s
   local lean=kind=='snake'and .18 or .75
   local b={cos(a)*.6*s,top,sin(a)*.6*s}
   local e={cos(a)*ln*lean,top+ln*(kind=='snake'and 1 or .55),sin(a)*ln*lean}
   if kind~='snake'then e[2]=e[2]-2.6*s end
   local m={(b[1]+e[1])/2,(b[2]+e[2])/2+(kind=='snake'and 0 or 2.2*s),(b[3]+e[3])/2}
   local w=(kind=='monstera'and 3.2 or(kind=='snake'and 1.1 or 1.6))*s
   local px,pz=-sin(a)*w,cos(a)*w
   local m1=kind=='snake'and'ktSage'or'lgLeaf'
   L.quad(b,{m[1]+px,m[2],m[3]+pz},e,e,i%2==0 and m1 or'forestLeaf',1.05)
   L.quad(b,e,{m[1]-px,m[2],m[3]-pz},{m[1]-px,m[2],m[3]-pz},'forestCore',.92)
  end
 elseif kind=='ficus'then
  L.cyl(0,top,top+9*s,0,.6*s,.4*s,'lgBark',6,false)
  for i=0,6 do local a=i*.9+rh(seed,i,1);local r=(2.4+rh(seed,i,2)*1.6)*s
   L.sphere(cos(a)*2.2*s,top+9*s+(rh(seed,i,3)-.2)*6*s,sin(a)*2.2*s,r,r*.85,r,'lgLeaf',7,4,seed+i)end
 elseif kind=='cactus'then
  L.cyl(0,top,top+11*s,0,1.8*s,1.6*s,'leaf',8,true)
  L.cyl(1.8*s,top+5*s,top+6*s,0,.8*s,.8*s,'leaf',6,false)
  L.cyl(2.6*s,top+5*s,top+9*s,0,.8*s,.7*s,'leaf',6,true)
  L.sphere(0,top+11.4*s,0,.9*s,.6*s,.9*s,'flower',6,3)
 elseif kind=='bonsai'then
  L.box(-4*s,0,-2.4*s,4*s,2*s,2.4*s,o.pot or'ktBasalt',1.0)
  L.box(-3.6*s,2*s,-2*s,3.6*s,2.3*s,2*s,'forestFloor',1)
  L.rod({0,2.3*s,0},{-1.4*s,5*s,.3*s},.55*s,'lgBark');L.rod({-1.4*s,5*s,.3*s},{1.6*s,7.6*s,0},.45*s,'lgBark')
  L.rod({1.6*s,7.6*s,0},{3.2*s,7.8*s,0},.3*s,'lgBark')
  for _,c in ipairs({{-2.6,5.8,.2,2.0},{1.8,8.4,0,2.2},{3.6,8.0,.3,1.4},{-.4,9.0,-.4,1.6}})do
   L.sphere(c[1]*s,c[2]*s,c[3]*s,c[4]*s,c[4]*.55*s,c[4]*s,'lgNeedle',8,3,seed)end
 elseif kind=='bamboo'then
  for i=0,4 do local a=i*1.3;local x,z=cos(a)*1.4*s,sin(a)*1.4*s;local hh=(16+rh(seed,i,1)*8)*s
   L.cyl(x,top,top+hh,z,.45*s,.4*s,'ktSage',6,true)
   for k=1,4 do L.cyl(x,top+hh*k/5,top+hh*k/5+.4*s,z,.55*s,.55*s,'ktSage',6,false)end
   for k=0,2 do local yy=top+hh*(.6+k*.15);local b2=a+k*2
    L.quad({x,yy,z},{x+cos(b2)*4*s,yy+1.4*s,z+sin(b2)*4*s},{x+cos(b2+.3)*5*s,yy-.6*s,z+sin(b2+.3)*5*s},{x+cos(b2+.3)*5*s,yy-.6*s,z+sin(b2+.3)*5*s},'forestLeaf',1.05)end
  end
 elseif kind=='flowers'or kind=='orchid'then
  for i=0,8 do local a=i*.8+rh(seed,i,1);local r=rh(seed,i,2)*1.8*s
   local hh=(3+rh(seed,i,3)*3)*s
   local fx,fz=cos(a)*r,sin(a)*r
   L.rod({fx*.3,top,fz*.3},{fx,top+hh,fz},.18*s,'leaf')
   local c=o.colors and o.colors[i%#o.colors+1]or({'flower','gold','white','red','flower'})[i%5+1]
   L.box(fx-.8*s,top+hh-.3*s,fz-.8*s,fx+.8*s,top+hh+.8*s,fz+.8*s,c,1.15)
   L.box(fx-.3*s,top+hh+.8*s,fz-.3*s,fx+.3*s,top+hh+1.0*s,fz+.3*s,'gold',1.2)
  end
  for i=0,5 do local a=i*1.05;L.quad({0,top,0},{cos(a)*3*s,top+1.6*s,sin(a)*3*s},{cos(a+.4)*3.6*s,top+.6*s,sin(a+.4)*3.6*s},{cos(a+.4)*3.6*s,top+.6*s,sin(a+.4)*3.6*s},'lgLeaf',1.0)end
 end
end

-- A rug on the floor (world part E): x0..x1, z0..z1. o: field, border,
-- inner, fringe, pattern ('plain'|'stripes'|'medallion'|'checks'|'oval'|
-- 'runner'|'mat'), y
function M.rug(C,E,x0,z0,x1,z1,o)
 o=o or{}
 local y=o.y or .12
 local f=o.field or'inRugRed';local b=o.border or'inRugGold'
 local function q(a,c,bx,d,mat,yy,t)E.quad({a,yy,d},{bx,yy,d},{bx,yy,c},{a,yy,c},mat,t or 1)end
 if o.pattern=='oval'then
  local cx,cz=(x0+x1)/2,(z0+z1)/2;local rx,rz=(x1-x0)/2,(z1-z0)/2
  local n=24
  for k,ring in ipairs({{1,b},{.86,f},{.5,o.inner or b},{.36,f}})do
   for i=0,n-1 do local a0,a1=i/n*pi*2,(i+1)/n*pi*2
    E.quad({cx,y+k*.02,cz},{cx+cos(a1)*rx*ring[1],y+k*.02,cz+sin(a1)*rz*ring[1]},{cx+cos(a0)*rx*ring[1],y+k*.02,cz+sin(a0)*rz*ring[1]},{cx,y+k*.02,cz},ring[2],1)
   end
  end
  return
 end
 local bw=o.bw or 1.6
 q(x0,z0,x1,z1,b,y)
 q(x0+bw,z0+bw,x1-bw,z1-bw,f,y+.02)
 if o.pattern=='stripes'then
  local z=z0+bw+2
  while z<z1-bw-1 do q(x0+bw,z,x1-bw,z+1.2,o.inner or b,y+.04);z=z+4 end
 elseif o.pattern=='checks'then
  local s=o.cell or 4
  for i=0,floor((x1-x0-2*bw)/s)-1 do for j=0,floor((z1-z0-2*bw)/s)-1 do
   if (i+j)%2==0 then q(x0+bw+i*s,z0+bw+j*s,x0+bw+(i+1)*s,z0+bw+(j+1)*s,o.inner or b,y+.04)end
  end end
 elseif o.pattern=='medallion'then
  local cx,cz=(x0+x1)/2,(z0+z1)/2
  q(x0+bw+1.4,z0+bw+1.4,x1-bw-1.4,z1-bw-1.4,o.inner or b,y+.03)
  q(x0+bw+2.2,z0+bw+2.2,x1-bw-2.2,z1-bw-2.2,f,y+.04)
  local r=min(x1-x0,z1-z0)*.22
  for i=0,7 do local a0,a1=i/8*pi*2,(i+1)/8*pi*2
   E.quad({cx,y+.06,cz},{cx+cos(a1)*r,y+.06,cz+sin(a1)*r},{cx+cos(a0)*r,y+.06,cz+sin(a0)*r},{cx,y+.06,cz},o.inner or b,1.05)end
  for _,c in ipairs({{x0+bw+3,z0+bw+3},{x1-bw-3,z0+bw+3},{x0+bw+3,z1-bw-3},{x1-bw-3,z1-bw-3}})do
   q(c[1]-1.2,c[2]-1.2,c[1]+1.2,c[2]+1.2,o.inner or b,y+.06)end
 end
 if o.fringe then
  for _,zz in ipairs({z0,z1})do
   local x=x0+.4
   while x<x1-.4 do E.quad({x,y,zz+(zz==z0 and -1.4 or 0)},{x+.4,y,zz+(zz==z0 and -1.4 or 0)},{x+.4,y,zz+(zz==z0 and 0 or 1.4)},{x,y,zz+(zz==z0 and 0 or 1.4)},o.fringe,1.05);x=x+1 end
  end
 end
end

-- A lamp. kind: 'floor'|'table'|'pendant'|'sconce'|'candle'|'lantern'
-- (local frame; pendant hangs from y=0 down). Adds its light to C.
function M.lamp(C,L,kind,o)
 o=o or{}
 local shade=o.variant or 1
 local metal=o.metal or'lgBronze'
 if kind=='floor'then
  L.cyl(0,0,.8,0,2.6,2.2,metal,10)
  L.cyl(0,.8,22,0,.35,.35,metal,6,false)
  L.cyl(0,20,26,0,4.2,2.4,'inLamp',12,false)
  L.cyl(0,20,26,0,4.25,2.45,'inLamp',12,false)
  L.cyl(0,25.8,26,0,2.4,2.4,o.cap or metal,8)
  local p=L.P({0,23,0});C.addLight(p[1],p[2],p[3],o.r or 44,o.k or .32)
  if C.fx then C.fx.glows[#C.fx.glows+1]={x=p[1],y=p[2],z=p[3],r=12,col='warm',a=.18}end
 elseif kind=='table'then
  L.cyl(0,0,.6,0,1.8,1.8,metal,10)
  L.cyl(0,.6,4.5,0,.9,.6,o.base or'ktPearl',10,false)
  L.cyl(0,4.5,7,0,.25,.25,metal,6,false)
  L.cyl(0,6.5,10,0,3,1.8,'inLamp',12,false)
  local p=L.P({0,8,0});C.addLight(p[1],p[2],p[3],o.r or 30,o.k or .26)
  if C.fx then C.fx.glows[#C.fx.glows+1]={x=p[1],y=p[2],z=p[3],r=8,col='warm',a=.16}end
 elseif kind=='pendant'then
  L.cyl(0,-(o.drop or 8),0,0,.12,.12,'dark',4,false)
  L.cyl(0,-(o.drop or 8)-4,-(o.drop or 8),0,o.r1 or 4.6,1.2,o.shadeMat or'inLamp',14,false)
  L.cyl(0,-(o.drop or 8)-4.2,-(o.drop or 8)-3.8,0,1.4,1.4,'inLamp',8)
  local p=L.P({0,-(o.drop or 8)-4,0});C.addLight(p[1],p[2]-6,p[3],o.r or 52,o.k or .34)
 elseif kind=='sconce'then
  L.box(-1.2,-2,0,1.2,2,.6,metal,1.05)
  L.rod({0,0,.6},{0,1.4,3.2},.3,metal)
  L.cyl(0,1.2,4.4,3.2,1.8,1.1,'inLamp',10,false)
  local p=L.P({0,3,3.2});C.addLight(p[1],p[2],p[3],o.r or 30,o.k or .22)
  if C.fx then C.fx.glows[#C.fx.glows+1]={x=p[1],y=p[2],z=p[3],r=6,col='warm',a=.2}end
 elseif kind=='candle'then
  L.cyl(0,0,.5,0,1.4,1.4,metal,8)
  L.cyl(0,.5,o.h or 4,0,.5,.5,o.wax or'cream',8)
  local p=L.P({0,(o.h or 4)+.4,0})
  if C.fx then C.fx.candles[#C.fx.candles+1]={x=p[1],y=p[2],z=p[3],s=o.s or .8,phase=p[1]*.37+p[3]*.11,col=o.col}end
  C.addLight(p[1],p[2],p[3],o.r or 22,o.k or .14)
 elseif kind=='lantern'then
  L.box(-1.6,0,-1.6,1.6,.6,1.6,metal,1)
  L.box(-1.3,.6,-1.3,1.3,5,1.3,'inShoji',1)
  L.box(-1.6,5,-1.6,1.6,5.6,1.6,metal,1)
  local p=L.P({0,3,0});C.addLight(p[1],p[2],p[3],o.r or 26,o.k or .2)
 end
end

-- A wall shelf (local wall frame) with things on it
function M.wallShelf(L,a,b,y,o)
 o=o or{}
 L.box(a,y-.8,0,b,y,4,o.wood or'inWalnut',1.05)
 for _,x in ipairs({a+1.4,b-2})do L.quad({x,y-.8,.2},{x+.6,y-.8,.2},{x+.6,y-3.6,.2},{x,y-.8,3.4},o.wood or'inWalnut',.9)end
 if o.items then M.shelfItems(L,o.items,a+.4,b-.4,y,y+7,.4,3.8,o.seed or 1)end
end

-- A television set on a stand (local frame, front +z). o: kind ('crt'|'flat')
function M.tv(L,o)
 o=o or{}
 local wd=o.wood or'inWalnut'
 L.box(-8,0,-5,8,6,4,wd,.95)
 L.box(-7.4,.8,4,7.4,5.4,4.3,wd,1.04)
 L.box(-6.6,3.2,4.3,-1,4.8,4.5,'dark',.9)
 if o.kind=='flat'then
  L.box(-1,6,-1,1,8,1,'inSteel',1)
  L.box(-9,8,-1.2,9,19,0,'dark',.8)
  L.raw({-8.4,8.6,.05},{8.4,8.6,.05},{8.4,18.4,.05},{-8.4,18.4,.05},'inScreen',2)
  return
 end
 L.box(-7,6,-3.6,7,17,3,o.case or'ktCedar',1.0)
 L.box(-6.4,6.6,3,4,16.4,3.4,'dark',.7)
 L.raw({-5.8,7.2,3.45},{3.4,7.2,3.45},{3.4,15.8,3.45},{-5.8,15.8,3.45},'inScreen',o.channel or 2)
 for i=0,2 do L.box(4.6,8+i*2.4,3,6.2,9.4+i*2.4,3.6,i==0 and'lgGold'or'lvSlate',1.05)end
 L.box(-1.4,17,-1,1.4,17.8,1.6,'dark',.9)
 for _,s in ipairs({-1,1})do L.rod({s*.6,17.8,.3},{s*5,26,.3},.15,'inSteel')end
end

------------------------------------------------------------------ stairs
-- A flight climbing NORTH over x0..x1, z0..z1 (world) to the wall, where it
-- runs on up through a dark opening. o: tread, riser, rail, n, top
function M.stairsUp(C,E,x0,x1,z0,z1,o)
 o=o or{}
 local L=M.frame(C,E,0,0,0,0)
 local n=o.n or 5;local top=o.top or 18
 local run=(z1-z0)/n;local rise=top/n
 for i=0,n-1 do
  local za=z1-(i+1)*run;local h=(i+1)*rise
  L.box(x0+.6,0,za,x1-.6,h-.6,za+run,o.riser or'white',1.0)
  L.box(x0+.4,h-.6,za-.3,x1-.4,h,za+run,o.tread or'inOak',1.06)
 end
 -- the stairwell's opening in the wall above the last tread
 L.quad({x0+.6,top,z0+.05},{x1-.6,top,z0+.05},{x1-.6,top+26,z0+.05},{x0+.6,top+26,z0+.05},'dark',.4)
 L.box(x0-.6,top,z0,x0+.6,top+27,z0+1.6,o.rail or'white',1.05)
 L.box(x1-.6,top,z0,x1+.6,top+27,z0+1.6,o.rail or'white',1.05)
 L.box(x0-.6,top+26,z0,x1+.6,top+28,z0+1.8,o.rail or'white',1.08)
 -- a rail up the open side
 local side=o.side or x0
 for i=0,n-1 do local zz=z1-(i+.5)*run;local h=(i+1)*rise
  L.box(side-.3,h,zz-.3,side+.3,h+9,zz+.3,o.rail or'white',1.05)end
 L.rod({side,rise+9,z1-run*.5},{side,top+9,z0+run*.5},.5,o.handrail or o.tread or'inOak')
end
-- A stairwell going DOWN: steps sinking north below the floor, a railing
-- round the opening on the room side
function M.stairsDown(C,E,x0,x1,z0,z1,o)
 o=o or{}
 local L=M.frame(C,E,0,0,0,0)
 local n=o.n or 5;local depth=o.depth or 18
 local run=(z1-z0)/n;local rise=depth/n
 -- the well's walls
 L.quad({x0,-depth-2,z0},{x1,-depth-2,z0},{x1,0,z0},{x0,0,z0},'dark',.45)
 L.quad({x0,0,z1},{x0,-depth-2,z1},{x0,-depth-2,z0},{x0,0,z0},o.wall or'ktPlaster',.6)
 L.quad({x1,-depth-2,z1},{x1,0,z1},{x1,0,z0},{x1,-depth-2,z0},o.wall or'ktPlaster',.6)
 for i=0,n-1 do
  local za=z1-(i+1)*run;local h=-(i+1)*rise
  L.box(x0,h-.6,za,x1,h,za+run,o.tread or'inOak',1.0-(i*.08))
  L.quad({x0,h,za+run},{x1,h,za+run},{x1,h+rise,za+run},{x0,h+rise,za+run},o.riser or'white',.9-(i*.08))
 end
 -- a low rail along the west side of the opening
 local rx=o.railX or x0
 for k=0,3 do local zz=z0+2+k*(z1-z0-4)/3;L.box(rx-.3,0,zz-.3,rx+.3,10,zz+.3,o.rail or'white',1.05)end
 L.box(rx-.5,10,z0+1,rx+.5,11,z1-1,o.handrail or'inOak',1.08)
 L.box(x0,-.2,z1-.6,x1,.15,z1,o.nosing or'inOak',1.05)
end

-- A potted-plant pair at a corner, a side table with a lamp, etc. are
-- composed by the rooms; these are the parts they share.
return M
