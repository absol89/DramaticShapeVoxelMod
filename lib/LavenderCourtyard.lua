-- TEST17: private Lavender courtyard geometry; never used by road builders.
local V=...;local C=V and V.require('SurfaceCraft') or assert(loadfile('lib/SurfaceCraft.lua'))()
local Gardens=V and V.require('WorldGardens') or assert(loadfile('lib/WorldGardens.lua'))()
local M={REVISION='lavender-ambiance-20'}
local function noise(x,z,s)
 local n=(x*73856093+z*19349663+s*83492791)%104729
 return ((n*n*37+n*17+s*101)%104729)/104729
end
function M.style(id)
 id=tostring(id or ''):upper()
 if id=='VERMILION_CITY' or id=='CINNABAR_ISLAND' then return 'brick' end
 return 'stone'
end
function M.palette(id)
 id=tostring(id or ''):upper()
 if M.style(id)=='brick' then return {moss={.27,.31,.19,1},dark={.27,.24,.20,1},shadow={.39,.23,.17,1},body={.58,.34,.24,1},light={.78,.73,.61,1}} end
 if id=='LAVENDER_TOWN' then return {moss={.25,.34,.26,1},dark={.25,.29,.29,1},shadow={.36,.38,.47,1},body={.52,.54,.64,1},light={.73,.74,.79,1}} end
 return {moss={.29,.35,.20,1},dark={.27,.29,.24,1},shadow={.39,.40,.38,1},body={.59,.60,.55,1},light={.77,.78,.70,1}}
end
local function clip(poly,axis,edge,sign)
 local out={};local prev=poly[#poly];if not prev then return out end
 local pd=(prev[axis]-edge)*sign
 for _,q in ipairs(poly)do
  local d=(q[axis]-edge)*sign
  if (pd<=0)~=(d<=0) then local t=pd/(pd-d);out[#out+1]={prev[1]+(q[1]-prev[1])*t,prev[2]+(q[2]-prev[2])*t} end
  if d<=0 then out[#out+1]=q end
  prev,pd=q,d
 end
 return out
end
local function crop(poly,x,z)
 return clip(clip(clip(clip(poly,1,x,-1),1,x+8,1),2,z,-1),2,z+8,1)
end
local function inset(poly,cx,cz,n)
 local out={}
 for _,p in ipairs(poly)do
  local dx,dz=p[1]-cx,p[2]-cz;local d=math.sqrt(dx*dx+dz*dz);local k=math.max(0,1-n/math.max(d,.001))
  out[#out+1]={cx+dx*k,cz+dz*k}
 end
 return out
end
-- Staggered shared boundaries: stone outlines vary without changing the
-- source tile mask or putting artificial joints at chunk/tile cuts.
local cells={};local cellCount=0
local function seed(col,row)
 return (col+.5)*4.8+(noise(col,row,1)-.5)*2.6,
        (row+.5)*4.3+(noise(col,row,2)-.5)*2.3
end
local function territory(col,row)
 local key=col..":"..row
 if cells[key] then return cells[key][1],cells[key][2],cells[key][3] end
 local cx,cz=seed(col,row)
 local p={{cx-14,cz-14},{cx+14,cz-14},{cx+14,cz+14},{cx-14,cz+14}}
 for iz=row-2,row+2 do for ix=col-2,col+2 do
  if ix~=col or iz~=row then
   local nx,nz=seed(ix,iz);local a,b=nx-cx,nz-cz;local c=(nx*nx+nz*nz-cx*cx-cz*cz)/2
   local out={};local prev=p[#p]
   if prev then
    local pd=a*prev[1]+b*prev[2]-c
    for _,q in ipairs(p)do local d=a*q[1]+b*q[2]-c
     if (d<=0)~=(pd<=0)then local t=pd/(pd-d);out[#out+1]={prev[1]+(q[1]-prev[1])*t,prev[2]+(q[2]-prev[2])*t}end
     if d<=0 then out[#out+1]=q end
     prev,pd=q,d
    end
   end
   p=out
  end
 end end
 cellCount=cellCount+1;if cellCount>4096 then cells={};cellCount=1 end
 cells[key]={p,cx,cz};return p,cx,cz
end
-- Clip complete 3D faces; interpolated elevation keeps bevels continuous
-- across source tile/chunk boundaries, including raised kerb blocks.
local function clip3(p,axis,edge,sign)
 local out={};local prev=p[#p];if not prev then return out end
 local pd=(prev[axis]-edge)*sign
 for _,q in ipairs(p)do
  local d=(q[axis]-edge)*sign
  if (pd<=0)~=(d<=0)then local t=pd/(pd-d);out[#out+1]={prev[1]+(q[1]-prev[1])*t,prev[2]+(q[2]-prev[2])*t,prev[3]+(q[3]-prev[3])*t}end
  if d<=0 then out[#out+1]=q end;prev,pd=q,d
 end
 return out
end
function M.build(id,x,z,h,emit,edges)
 if id~='LAVENDER_TOWN' then return end
 local function face(p,swatch,tone)
  p=clip3(clip3(clip3(clip3(p,1,x,-1),1,x+8,1),3,z,-1),3,z+8,1)
  for i=2,#p-1 do
   local a,b,c=p[1],p[i],p[i+1]
   local ux,uy,uz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
   local vx,vy,vz=c[1]-a[1],c[2]-a[2],c[3]-a[3]
   if (uy*vz-uz*vy)^2+(uz*vx-ux*vz)^2+(ux*vy-uy*vx)^2>(id=='LAVENDER_TOWN' and 1e-18 or 1e-12) then
    emit({a,b,c,c},swatch,tone)
   end
  end
 end
 local function flat(p,y,s,t)
  local q={};for _,v in ipairs(p)do q[#q+1]={v[1],y,v[2]}end;face(q,s,t)
 end
 local function rect(a,b,c,d,y,s,t)if c>a and d>b then flat({{a,b},{c,b},{c,d},{a,d}},y,s,t)end end
 local function raised(p,cx,cz,top,bevel,swatch,tone)
  local inner=inset(p,cx,cz,bevel)
  flat(inner,top,swatch,tone)
  for i=1,#p do local j=i%#p+1;local a,b,c,d=p[i],p[j],inner[j],inner[i]
   local dx,dz=b[1]-a[1],b[2]-a[2]
   local light=.85+.19*(dx-dz)/math.max(.001,math.sqrt(dx*dx+dz*dz))
   face({{a[1],top-.14,a[2]},{b[1],top-.14,b[2]},{c[1],top,c[2]},{d[1],top,d[2]}},swatch,tone*light)
   face({{b[1],h,b[2]},{a[1],h,a[2]},{a[1],top-.14,a[2]},{b[1],top-.14,b[2]}},'shadow',tone*.86)
  end
 end
 local garden=edges and edges.garden and id=='LAVENDER_TOWN'
 rect(x,z,x+8,z+8,h,garden and 'moss' or 'dark',garden and .79 or 1)
 local brick=M.style(id)=='brick';local step=brick and 2.8 or 4.3
 for row=math.floor(z/step)-1,math.floor((z+8)/step)+1 do
  for col=math.floor(x/(brick and 6 or 4.8))-2,math.floor((x+8)/(brick and 6 or 4.8))+1 do
   local p,cx,cz
   if brick then local a=col*6+(row%2)*3;local b=row*2.8
    p={{a,b},{a+6,b},{a+6,b+2.8},{a,b+2.8}};cx,cz=a+3,b+1.4
   else p,cx,cz=territory(col,row)end
   local cover=garden and C.field(cx/22,cz/22,180)>.61
   if not cover then
   -- Worn clipped corners break the perfect Voronoi/brick silhouette.
   local worn={}
   for i,q in ipairs(p)do
    local prev,next=p[(i-2)%#p+1],p[i%#p+1]
    local f=(brick and .025 or .075)+noise(col+i,row,61)*(brick and .025 or .07)
    worn[#worn+1]={q[1]+(prev[1]-q[1])*f,q[2]+(prev[2]-q[2])*f}
    worn[#worn+1]={q[1]+(next[1]-q[1])*f,q[2]+(next[2]-q[2])*f}
   end
   local tone=.84+noise(col,row,9)*.30
   local top=h+(brick and .24 or .25)+noise(col,row,12)*(brick and .09 or .19)
   raised(inset(worn,cx,cz,brick and .11 or .16),cx,cz,top,brick and .12 or .20,'body',tone)
   -- Fine joint growth follows ragged polygon edges, not broad face paint.
   if id=='LAVENDER_TOWN' and noise(col,row,101)>.28 then
    local ring=inset(worn,cx,cz,.12)
    for k=1,#ring do
     local a=ring[k];local b=ring[k%#ring+1]
     local dx,dz=b[1]-a[1],b[2]-a[2]
     if dx*dx+dz*dz>1.2 and noise(col+k,row,103)>.36 then
      -- Tapered fingers follow long mortar edges, below the stone top.
      local u=.12+noise(col+k,row,347)*.18
      local v=.66+noise(col+k,row,348)*.24
      local ax,az=a[1]+dx*u,a[2]+dz*u
      local bx,bz=a[1]+dx*v,a[2]+dz*v
      local t=.022+noise(col+k,row,349)*.035
      flat({{ax,az},{bx,bz},{bx+(cx-bx)*t,bz+(cz-bz)*t},
        {ax+(cx-ax)*t*.6,az+(cz-az)*t*.6}},top-.08,'moss',.78+noise(col+k,row,104)*.32)
     end
    end
   end
   -- Fine chips inset on the raised face; never across a mortar joint.
   if noise(col,row,74)>.42 then
    local r=.10+noise(col,row,75)*.13
    flat({{cx-r,cz},{cx,cz-r*.55},{cx+r,cz+r*.35},{cx,cz+r}},top+.008,'light',tone*.86)
   end
   -- Small irregular moss islands in the recessed joints, never painted
   -- over the walking surface. World seeds remain identical across tiles.
   if not brick or noise(col,row,32)>.76 then
    for i,a in ipairs(p)do
     if noise(col+i,row,21)>.48 then
      local r=.18+noise(col,row+i,18)*.28
      flat({{a[1]-r,a[2]},{a[1]-.15,a[2]-r*.9},{a[1]+r,a[2]-.1},{a[1]+r*.5,a[2]+r}},h+.018,'moss',.78+noise(col,row,23)*.35)
     end
    end
   end
   else
    -- Irregular, layered low cushions follow the stone territory. A dark
    -- perimeter and small lobes soften the join without square turf holes.
    flat(p,h+.028,'moss',.80+noise(col,row,370)*.25)
    local g=C.builder(x,z,emit)
    if noise(col,row,375)>.68 then
     local px,pz=cx+.9,cz-.7;local r=.30+noise(col,row,376)*.35
     local top={px,h+.25+noise(col,row,377)*.18,pz}
     for j=0,4 do
      local a,b=j*math.pi*2/5,(j+1)*math.pi*2/5
      g.face({{px+math.cos(a)*r,h+.075,pz+math.sin(a)*r},
        {px+math.cos(b)*r,h+.075,pz+math.sin(b)*r},top},'body',.73+j*.045)
     end
    end
    if noise(col,row,183)>.54 then
     for k=0,3 do g.blade(cx,cz,h+.08,.35+noise(col+k,row,184)*.55,.10,.3,k*1.57,'leaf',1.05)end
     if C.field(cx/22,cz/22,180)>.64 then
      -- Three offset spikes per selected pocket; bounded, not a tile-wide scatter.
      for k=0,2 do
       local a=k*2.4+noise(col,row,371)*6.28
       local radius=.55+noise(col+k,row,372)*.65
       local fx,fz=cx+math.cos(a)*radius,cz+math.sin(a)*radius
       Gardens.foliage(g,fx,fz,h+.09,col+k+row*17,1.05+noise(col+k,row,373)*.30)
       Gardens.flower(g,fx,fz,h+.09,1.70+noise(col+k,row,186)*1.25,col+k+row*17,1.12+noise(col+k,row,374)*.28)
      end
     end
    end
   end
  end
 end
 -- A separate world-space moss field crosses every removed-stone territory.
 -- Its small lobes sit below intact paving, hiding underneath surviving stones.
 -- This prevents each missing stone from becoming a green stone-shaped decal.
 if garden then
  local g=C.builder(x,z,emit);local spacing=1.7
  for iz=math.floor(z/spacing)-2,math.floor((z+8)/spacing)+2 do
   for ix=math.floor(x/spacing)-2,math.floor((x+8)/spacing)+2 do
    local cx=(ix+.5)*spacing+(C.hash(ix,iz,261)-.5)*1.35
    local cz=(iz+.5)*spacing+(C.hash(ix,iz,262)-.5)*1.35
    local r=.88+C.hash(ix,iz,263)*.34;local poly={}
    local tone=.70+C.field(cx/6,cz/6,264)*.34+C.hash(ix,iz,268)*.06
    for j=0,5 do local a=j*math.pi/3;local rr=r*(.80+C.hash(ix+j,iz,265)*.25)
     poly[#poly+1]={cx+math.cos(a)*rr,h+.063,cz+math.sin(a)*rr}
    end
    local center={cx,h+.12+C.hash(ix,iz,266)*.10,cz}
    for j=1,6 do g.face({poly[j],poly[j%6+1],center},'moss',tone+(j%2)*.012)end
   end
  end
 end
 -- Substantial segmented stone edging; all of it stays inside path masks.
 if edges then
  local function block(a,b,c,d,k)
   local gap=.075
   raised({{a+gap,b+gap},{c-gap,b+gap},{c-gap,d-gap},{a+gap,d-gap}},(a+c)/2,(b+d)/2,h+.66,.13,'light',.88+noise(x+k,z,45)*.14)
  end
  local function gutter(a,b,c,d,vertical)
   rect(a,b,c,d,h+.46,'shadow',.79)
   for j=0,3 do
    local u=1.6+j*1.5
    if vertical then rect(a+.04,z+u,c-.04,z+u+.16,h+.47,'dark',.70)
    else rect(x+u,b+.04,x+u+.16,d-.04,h+.47,'dark',.70)end
   end
  end
  if edges.w then gutter(x+1.13,z+1.15,x+1.55,z+6.85,true)end
  if edges.e then gutter(x+6.45,z+1.15,x+6.87,z+6.85,true)end
  if edges.n then gutter(x+1.6,z+1.13,x+6.4,z+1.55,false)end
  if edges.s then gutter(x+1.6,z+6.45,x+6.4,z+6.87,false)end
  for i=0,2 do local a=i*8/3;local b=(i+1)*8/3
   local lo=math.max(a,edges.n and 1.1 or 0)
   local hi=math.min(b,edges.s and 6.9 or 8)
   if hi-lo>.18 then
    if edges.w then block(x,z+lo,x+1.1,z+hi,i)end
    if edges.e then block(x+6.9,z+lo,x+8,z+hi,i+3)end
   end
   if edges.n then block(x+a,z,x+b,z+1.1,i+6)end
   if edges.s then block(x+a,z+6.9,x+b,z+8,i+9)end
  end
 end
end
return M
