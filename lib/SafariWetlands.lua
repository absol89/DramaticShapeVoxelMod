-- Legendary pond habitats. Decorative geometry only: no encounter/collision edits.
-- All water plants fit entirely inside source water; land sedges own blocked rims.
local V=...;local M={};local pi=math.pi
local function key(x,z)return(z+64)*4096+x+64 end
local function hash(x,z,s)return V.require('SurfaceCraft').hash(x,z,s)end
local function events(map,x,z,pad)
 for _,list in ipairs({map.def.warps or{},map.def.signs or{},map.def.objects or{}})do
  for _,e in ipairs(list)do if e.x and e.y and math.abs(e.x*16+8-x)<pad and math.abs(e.y*16+8-z)<pad then return false end end
 end
 return true
end
local function water(S,x,z)
 local s=S.shapeAt[key(x,z)];return s and s.class=='water'and not S.skip[key(x,z)]
end
-- Folded, curved leaves carry width from every camera direction, not ROM alpha.
function M.sedge(G,x,y,z,variant,height,radius,ground)
 for j=0,8 do
  local a=j*2.399+variant*.61;local ux,uz=-math.sin(a),math.cos(a)
  local r=radius*(.28+hash(j,variant,1321)*.32)
  local bx,bz=x+math.cos(a)*r,z+math.sin(a)*r
  local root=ground and ground(bx,bz)or y
  local h=height*(.67+hash(j,variant,1327)*.33);local w=radius*(.19+hash(j,variant,1329)*.07)
  local last
  for k=0,3 do local t=k/3;local width=w*(1-t)^.7
   local bend=radius*.3*t*t;local c={bx+math.cos(a)*bend,root+h*t,bz+math.sin(a)*bend}
   local row={{c[1]-ux*width,c[2],c[3]-uz*width},{c[1]+math.cos(a)*width*.48,c[2],c[3]+math.sin(a)*width*.48},{c[1]+ux*width,c[2],c[3]+uz*width}}
   if last then for n=1,2 do G.face(last[n],last[n+1],row[n+1],row[n],'forestLeaf',n==1 and 1.12 or .89)end end
   last=row
  end
 end
end
local function pad(G,x,z,r,a,flower)
 -- A notched oval, curled rim and radial veins: broad enough to read in game.
 local function p(angle,scale,y)
  local u,v=math.cos(angle)*r*scale,math.sin(angle)*r*.79*scale
  return{x+u*math.cos(a)-v*math.sin(a),y,z+u*math.sin(a)+v*math.cos(a)}
 end
 local c={x,-1.58,z}
 for i=1,11 do local aa,bb=i*2*pi/12,(i+1)*2*pi/12
  local pa,pb=p(aa,.89,-1.58),p(bb,.89,-1.58)
  G.face(c,pa,pb,c,'forestLeaf',1.1+.04*math.sin(i+a))
  G.face(pa,p(aa,1,-1.54),p(bb,1,-1.54),pb,'forestLeaf',.92)
  if i%2==0 then G.face(c,p(aa,.81,-1.555),p(aa+.025,.81,-1.555),c,'leaf',1.10)end
 end
 if flower then
  for j=0,5 do local a=j*pi/3
   G.face({x,-1.50,z},{x+math.cos(a-.3)*.55,-1.28,z+math.sin(a-.3)*.55},{x+math.cos(a)*.9,-1.14,z+math.sin(a)*.9},{x+math.cos(a+.3)*.55,-1.28,z+math.sin(a+.3)*.55},'cream',1.1)
  end
 end
end
function M.build(S,map,G,W,H)
 S.safariShores={};S.safariWetlands={};local planted={};local lilyUsed={}
 local function record(kind,x,z,r,first,extra)
  S.safariWetlands[#S.safariWetlands+1]={kind=kind,x=x,z=z,r=r,first=first,last=#G.out,extra=extra}
 end
 for z=0,H-1 do for x=0,W-1 do if water(S,x,z)then
  local edges=0;local cx,cz=x*8+4,z*8+4
  for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
   local nx,nz=x+d[1],z+d[2];local near=S.shapeAt[key(nx,nz)]
   if not near or near.class~='water'then edges=edges+1 end
   if near and near.class~='water'and near.class~='building'then
    local ux,uz=-d[2],d[1]
    local ax,az=cx+d[1]*3.99,cz+d[2]*3.99
    local bx,bz=cx+d[1]*2.85,cz+d[2]*2.85
    local y=near.h or 0
    if S.safariClaims[key(nx,nz)]=='rock'then y=V.require('SafariLandscape').bankHeight(S,map,ax,az)end
    -- Filled damp earth bevel meets the real bank instead of a thin gray stripe.
    local left,right=y,y
    if S.safariClaims[key(nx,nz)]=='rock'then
     left=V.require('SafariLandscape').bankSurface(S,map,ax-ux*3.99+d[1]*.02,az-uz*3.99+d[2]*.02)
     right=V.require('SafariLandscape').bankSurface(S,map,ax+ux*3.99+d[1]*.02,az+uz*3.99+d[2]*.02)
    end
    G.face({bx-ux*3.99,-1.91,bz-uz*3.99},{bx+ux*3.99,-1.91,bz+uz*3.99},{ax+ux*3.99,right,az+uz*3.99},{ax-ux*3.99,left,az-uz*3.99},'forestFloor',.77)
    S.safariShores[#S.safariShores+1]={tx=x,tz=z,x=ax,z=az}
    local blocked=not map:isWalkableCell(math.floor(nx/2),math.floor(nz/2))
    local rim=S.safariClaims[key(nx,nz)]=='rock'
    -- A narrow fringe at selected open banks; never covers the central
    -- water-entry corridor. Long runs keep regular unplanted access gaps.
    if not blocked and events(map,cx,cz,30) and (x+z)%4~=0
        and math.sin(x*.48+z*.31)+math.cos(z*.35-x*.19)>.35 then
     local first=#G.out+1
     for j=-1,1,2 do
      local xx,zz=cx+d[1]*3.05+ux*j*1.95,cz+d[2]*3.05+uz*j*1.95
      M.sedge(G,xx,-1.86,zz,(x+z+j)%7,4.3+hash(x+j,z,1409)*2.5,.62)
     end
     record('shore-fringe',cx,cz,4,first,{dx=d[1],dz=d[2]})
    end
    -- Taller, wider habitat groups own blocked bank rims only.
    if blocked and rim and events(map,cx,cz,28)then
     local cluster=math.sin(nx*.39+nz*.22)+math.cos(nz*.47-nx*.17)
     if cluster>-.95 then
      local lk=key(nx,nz)
      if not planted[lk]and events(map,nx*8+4,nz*8+4,24)then
       planted[lk]=true;local xx,zz=nx*8+4,nz*8+4;local first=#G.out+1
       local base=V.require('SafariLandscape').bankHeight(S,map,xx,zz)-.12
       M.sedge(G,xx,base,zz,(nx+nz)%7,6.0+hash(nx,nz,1331)*3.6,3.25,function(x,z)return V.require('SafariLandscape').bankSurface(S,map,x,z)-.06 end)
       record('bank-sedge',xx,zz,3.25,first)
      end
      local xx,zz=cx+d[1]*1.7,cz+d[2]*1.7;local first=#G.out+1
      M.sedge(G,xx,-1.86,zz,(x+z)%7,6.2+hash(x,z,1337)*3.2,1.65)
      if hash(x,z,1339)>.57 then
       -- Sparse cylindrical seed heads, not identical triangular flower spikes.
       for j=0,1 do local a=j*2.4+x;local xx,zz=xx+math.cos(a)*.5,zz+math.sin(a)*.5;local h=5.7+j*.8
        G.beam({xx,-1.9,zz},{xx+.16,h,zz},.13,'forestLeaf',1.02)
        G.box(xx-.11,h-.8,zz-.11,xx+.28,h+.45,zz+.11,'wood',1.03)
       end
      end
      record('water-reed',xx,zz,1.85,first)
     end
    end
   end
  end
  -- Behind open walking shores, a few shallow-water islands add height while
  -- leaving the first full water tile unobstructed for entry and fishing.
  local island=false
  if edges==0 and events(map,cx,cz,24)and hash(x,z,1361)>.78 then
   local nearWalk=false
   for _,d in ipairs({{-2,0},{2,0},{0,-2},{0,2}})do
    local tx,tz=x+d[1],z+d[2];local s=S.shapeAt[key(tx,tz)]
    if s and s.class~='water'and map:isWalkableCell(math.floor(tx/2),math.floor(tz/2))then nearWalk=true end
   end
   if nearWalk then
    island=true;local first=#G.out+1
    local xx=cx+(hash(x,z,1367)-.5)*.8;local zz=cz+(hash(x,z,1373)-.5)*.8
    M.sedge(G,xx,-1.86,zz,(x+z)%7,7.5+hash(x,z,1379)*2.8,2.5)
    record('water-sedge',xx,zz,2.5,first)
   end
  end
  -- A broad water cell near shore hosts one asymmetric three-pad group.
  -- The group stays inside its 8px owner; never covers a walkable bank/warp.
  if edges==0 and not island and events(map,cx,cz,24)and hash(x,z,1343)>.50 then
   local shore=false
   for dz=-2,2 do for dx=-2,2 do local a=S.shapeAt[key(x+dx,z+dz)]
    if a and a.class~='water'then shore=true end
   end end
   local spaced=true;for dz=-1,1 do for dx=-1,1 do if lilyUsed[key(x+dx,z+dz)]then spaced=false end end end
   if shore and spaced then
    lilyUsed[key(x,z)]=true;local first=#G.out+1;local a=hash(x,z,1349)*2*pi
    local xx=cx+(hash(x,z,1381)-.5)*.6;local zz=cz+(hash(x,z,1387)-.5)*.6
    pad(G,xx-1.35,zz-.7,1.8+hash(x,z,1391)*.35,a,hash(x,z,1351)>.88)
    pad(G,xx+1.55,zz+.3,1.25+hash(x,z,1393)*.35,a+2.0,false)
    pad(G,xx-.3,zz+2.0,.72+hash(x,z,1399)*.25,a-.9,false)
    record('lily-cluster',cx,cz,3.6,first)
   end
  end
 end end end
end
return M
