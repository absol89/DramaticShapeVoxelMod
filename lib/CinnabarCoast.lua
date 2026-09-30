-- Cinnabar-only clipped geometry, baked into existing terrain meshes.
local V=...
local C=V and V.require('SurfaceCraft') or assert(loadfile('lib/SurfaceCraft.lua'))()
local M={}
-- Faceted, flattened coastal stones; all faces stay in the owning terrain tile.
local function rock(G,cx,cz,y,rx,rz,height,seed,swatch,tone,segments)
 local n=segments or 8
 local lower,upper={},{}
 for j=0,n-1 do
  local a=j*math.pi*2/n;local r=.87+C.hash(seed,j,951)*.13
  lower[j+1]={cx+math.cos(a)*rx*r,y,cz+math.sin(a)*rz*r}
  upper[j+1]={cx+math.cos(a)*rx*r*.64,y+height*(.82+C.hash(seed,j,952)*.18),cz+math.sin(a)*rz*r*.64}
 end
 for j=1,n do
  local k=j%n+1
  G.face({lower[j],lower[k],upper[k],upper[j]},swatch,tone*(.76+j*.027))
  G.face({upper[j],upper[k],{cx,y+height,cz}},swatch,tone*1.06)
 end
end
local function flower(G,cx,cz,y,height,r,seed)
 G.blade(cx,cz,y,height,.065,.08,seed,'leaf',.82)
 local top=y+height
 for j=0,4 do
  local a=j*math.pi*2/5;local b=a+.52;local c=a-.52
  G.face({{cx,top,cz},{cx+math.cos(c)*r,top+.08,cz+math.sin(c)*r},
   {cx+math.cos(a)*r*1.25,top+.15,cz+math.sin(a)*r*1.25},
   {cx+math.cos(b)*r,top+.08,cz+math.sin(b)*r}},'petal',.94+C.hash(seed,j,953)*.18)
 end
 G.flat(cx-.12,cz-.12,cx+.12,cz+.12,top+.17,'light',.8)
end
-- Low broad leaves fill beds below the flowers, rather than a row of thin stalks.
local function foliage(G,cx,cz,y,r,seed)
 for j=0,5 do
  local a=j*math.pi/3+C.hash(seed,j,1031)*.4
  local dx,dz=math.cos(a),math.sin(a)
  local length=r*(.72+C.hash(seed,j,1032)*.35)
  local width=length*.31;local lift=.42+length*.42
  local mid={cx+dx*length*.55,y+lift,cz+dz*length*.55}
  local tip={cx+dx*length,y+.13,cz+dz*length}
  local left={mid[1]-dz*width,y+lift*.75,mid[3]+dx*width}
  local right={mid[1]+dz*width,y+lift*.75,mid[3]-dx*width}
  local base={cx,y,cz}
  for _,tri in ipairs({{base,left,mid},{left,tip,mid},{tip,right,mid},{right,base,mid}})do
   G.face(tri,'leaf',.76+(j%3)*.095)
   G.face({tri[3],tri[2],tri[1]},'leaf',.68+(j%3)*.07)
  end
 end
end
local function smooth(a,b,x)
 local t=math.max(0,math.min(1,(x-a)/(b-a)));return t*t*(3-2*t)
end
function M.material(col,row,cx,cz)
 local field=C.field(cx/21,cz/21,1002)
 local pick=C.hash(col,row,1021)
 if pick<smooth(.43,.68,field) then return 'cinder' end
 if pick>1-smooth(.43,.20,field) then return 'sand' end
 return 'body'
end
function M.enabled(id,roads,tileset)
 return id=='CINNABAR_ISLAND' and roads and tileset=='OVERWORLD'
end
-- Continuous coastal runs; entrances and docks are excluded by the caller.
-- Only real water edges receive timber; buildings never receive rails.
function M.frontage(x,z,edges)
 local out={}
 for _,e in ipairs({'w','e','n','s'})do
  local along=(e=='w' or e=='e') and z/8 or x/8
  if edges[e] and edges['water_'..e] and edges.plant then
   out[#out+1]={edge=e,dx=e=='w' and -1 or e=='e' and 1 or 0,
    dz=e=='n' and -1 or e=='s' and 1 or 0,post=along%2==0,lamp=along%4==0,
    cornerStart=edges[(e=='w' or e=='e') and 'n' or 'w'] and edges['water_'..((e=='w' or e=='e') and 'n' or 'w')],
    cornerEnd=edges[(e=='w' or e=='e') and 's' or 'e'] and edges['water_'..((e=='w' or e=='e') and 's' or 'e')]}
  end
 end
 return out
end
function M.hasFixture(x,z,edges)return #M.frontage(x,z,edges)>0 end
function M.lamps(x,z,edges)
 local out={}
 for _,f in ipairs(M.frontage(x,z,edges))do if f.lamp and not f.cornerStart and not f.cornerEnd then
  out[#out+1]={x+4+f.dx*2.5,z+4+f.dz*2.5}
 end end
 return out
end
function M.lightPush(push,lamps,h)
 return function(c,uv,shade)
  local out={}
  for i,v in ipairs(c)do
   local s=type(shade)=='table' and shade[i] or shade
   if s>=64 then out[i]=s else
    local light=0
    for _,p in ipairs(lamps)do
     local d=math.sqrt((v[1]-p[1])^2+(v[3]-p[2])^2)
     local f=math.max(0,1-d/18)
     light=light+f*f*math.max(0,1-math.abs(v[2]-h)/18)
    end
    local level=math.floor(math.min(1,light)*15+.5)
    out[i]=128+level*4+math.max(0,math.min(3.95,s))
   end
  end
  return push(c,uv,out)
 end
end
local territories={};local territoryCount=0
local function seed(col,row)
 return (col+.5)*5.4+(C.hash(col,row,991)-.5)*2.8,
        (row+.5)*4.8+(C.hash(col,row,992)-.5)*2.5
end
function M.territory(col,row)
 local key=col..':'..row
 if territories[key] then return territories[key] end
 local cx,cz=seed(col,row)
 local p={{cx-15,cz-15},{cx+15,cz-15},{cx+15,cz+15},{cx-15,cz+15}}
 for iz=row-2,row+2 do for ix=col-2,col+2 do if ix~=col or iz~=row then
  local nx,nz=seed(ix,iz);local a,b=nx-cx,nz-cz;local c=(nx*nx+nz*nz-cx*cx-cz*cz)/2
  local out={};local prev=p[#p]
  if prev then
   local pd=a*prev[1]+b*prev[2]-c
   for _,q in ipairs(p)do
    local d=a*q[1]+b*q[2]-c
    if (d<=0)~=(pd<=0)then local t=pd/(pd-d);out[#out+1]={prev[1]+(q[1]-prev[1])*t,prev[2]+(q[2]-prev[2])*t}end
    if d<=0 then out[#out+1]=q end
    prev,pd=q,d
   end
  end
  p=out
 end end end
 territoryCount=territoryCount+1
 if territoryCount>512 then territories={};territoryCount=1 end
 territories[key]=p;return p
end
function M.paving(x,z,h,emit,edges)
 local G=C.builder(x,z,emit)
 G.flat(x,z,x+8,z+8,h-.035,'dark',.90)
 -- Voronoi territories share world-space boundaries across tile cuts.
 for row=math.floor(z/4.8)-2,math.floor((z+8)/4.8)+2 do
  for col=math.floor(x/5.4)-2,math.floor((x+8)/5.4)+2 do
   local pts=M.territory(col,row)
   local cx,cz=0,0;for _,p in ipairs(pts)do cx=cx+p[1]/#pts;cz=cz+p[2]/#pts end
   local poly={};local rise=h+.24+C.hash(col,row,932)*.16
   for i,p in ipairs(pts)do
    local prev,next=pts[(i-2)%#pts+1],pts[i%#pts+1]
    local chip=.025+C.hash(col+i,row,933)*.035
    for _,q in ipairs({prev,next})do
     local px,pz=p[1]+(q[1]-p[1])*chip,p[2]+(q[2]-p[2])*chip
     poly[#poly+1]={cx+(px-cx)*.956,rise,cz+(pz-cz)*.956}
    end
   end
   local tone=.77+C.hash(col,row,934)*.36
   local swatch=M.material(col,row,cx,cz)
   local inner={}
   for _,p in ipairs(poly)do
    local dx,dz=p[1]-cx,p[3]-cz
    local k=math.max(0,1-.16/math.max(.01,math.sqrt(dx*dx+dz*dz)))
    inner[#inner+1]={cx+dx*k,rise,cz+dz*k}
   end
   G.face(inner,swatch,tone)
   for i,p in ipairs(poly)do
    local q=poly[i%#poly+1];local a,b=inner[i],inner[i%#inner+1]
    local dx,dz=q[1]-p[1],q[3]-p[3]
    local light=.92+.17*(dx-dz)/math.max(.01,math.sqrt(dx*dx+dz*dz))
    G.face({{p[1],rise-.14,p[3]},{q[1],rise-.14,q[3]},b,a},swatch,tone*light)
    G.face({{p[1],h-.025,p[3]},{q[1],h-.025,q[3]},
      {q[1],rise-.14,q[3]},{p[1],rise-.14,p[3]}},'shadow',.8)
   end
   -- Tiny growth in sheltered perimeter joints, below the walking stones.
   if edges and edges.plant and C.hash(col,row,1041)>.72 then
    for _,p in ipairs(pts)do
     local near=(edges.w and p[1]<x+2) or (edges.e and p[1]>x+6)
       or (edges.n and p[2]<z+2) or (edges.s and p[2]>z+6)
     if near then
      local r=.12+C.hash(col,row,1042)*.10
      G.face({{p[1]-r,h+.025,p[2]},{p[1],h+.025,p[2]-r*.7},
       {p[1]+r,h+.025,p[2]+r*.3},{p[1],h+.025,p[2]+r}},'moss',.72)
     end
    end
   end
   -- Sparse branching wear, rotated per stone and kept inside its top polygon.
   if C.hash(col,row,936)>.84 then
    local angle=C.hash(col,row,1022)*math.pi*2
    local dx,dz=math.cos(angle),math.sin(angle)
    local radius=math.huge
    for _,p in ipairs(inner)do radius=math.min(radius,math.sqrt((p[1]-cx)^2+(p[3]-cz)^2))end
    local length=math.min(1.15,radius*.40)
    local function point(u,v)return {cx+dx*u-dz*v,rise+.009,cz+dz*u+dx*v}end
    G.face({point(-length,0),point(-.1,.025),point(length*.6,.22),point(.05,-.035)},'dark',.72)
    if C.hash(col,row,1023)>.55 then
     G.face({point(0,0),point(.03,.06),point(-length*.25,.48)},'shadow',.84)
    end
   end
   if C.hash(col,row,1024)>.76 and #inner>2 then
    local i=1+math.floor(C.hash(col,row,1025)*#inner)
    local a,b=inner[i],inner[i%#inner+1]
    local u=.25+C.hash(col,row,1026)*.25
    local px,pz=a[1]+(b[1]-a[1])*u,a[3]+(b[3]-a[3])*u
    G.face({{px,rise+.01,pz},{px+(b[1]-a[1])*.14,rise+.01,pz+(b[3]-a[3])*.14},
      {px+(cx-px)*.12,rise+.01,pz+(cz-pz)*.12}},'shadow',.82)
   end

  end
 end
 if not edges then return end
 local planted=false
 local edgeCount=0;for _,e in ipairs({'w','e','n','s'})do if edges[e]then edgeCount=edgeCount+1 end end
 for _,e in ipairs({'w','e','n','s'})do if edges[e] then
  local function point(inset,along)
   if e=='w' then return x+inset,z+along elseif e=='e' then return x+8-inset,z+along
   elseif e=='n' then return x+along,z+inset else return x+along,z+8-inset end
  end
  -- Broken warm coping bands frame the promenade; no repeated green square.
  for k=0,2 do
   local a,b=point(.10,k*2.66+.12);local c,d=point(1.05,k*2.66+2.50)
   G.box(math.min(a,c),math.min(b,d),math.max(a,c),math.max(b,d),h-.05,h+.52,'light',.92+C.hash(x+k,z,937)*.1)
  end
  -- Plant in distinct pockets with open stretches between, never a continuous fringe.
  local seed=x*3+z*7+string.byte(e)
  local pocket=edges.plant and not planted and (edgeCount>=2 or C.hash(x/8,z/8,string.byte(e)+960)>.55)
  if pocket then
   planted=true
   local center=3.2+C.hash(x,z,961)*1.6
   local depth=(edgeCount>=2 and 3.7 or 3.2)+C.hash(x,z,962)*.3
   local soil={}
   for j=0,9 do
    local a=j*math.pi/5
    local px,pz=point(2.25+math.cos(a)*(depth-2.25),center+math.sin(a)*2.8)
    soil[#soil+1]={px,h+.44,pz}
   end
   G.face(soil,'sand',.58)
   for k=0,3 do
    local cx,cz=point(1.4+C.hash(seed,k,1006)*1.7,center-2+C.hash(seed,k,1007)*4)
    rock(G,cx,cz,h+.46,.12+C.hash(seed,k,1008)*.15,.19,.10,seed+k,'sand',.82,5)
   end
   -- Three unequal rocks anchor each bed; foliage rises between them.
   for k=0,2 do
    local cx,cz=point(1.4+k*.5,center-1.95+k*1.55)
    rock(G,cx,cz,h+.45,.5+k*.13,.65,.42+k*.14,seed+k,'body',.69,6)
   end
   -- Broad foliage masses and differently sized flower groups, with clear breaks between beds.
   for k=0,3 do
    local cx,cz=point(1.85+C.hash(seed,k,963)*(depth-2.15),center-1.8+k*1.14)
    foliage(G,cx,cz,h+.47,.72+C.hash(seed,k,1033)*.48,seed+k)
    local height=1.25+C.hash(seed,k,965)*1.7
    if k~=1 or edgeCount>=2 then
     flower(G,cx+.18,cz,h+.48,height,.52+C.hash(seed,k,966)*.24,seed+k)
     if k%2==0 then flower(G,cx-.35,cz+.3,h+.48,height*.71,.38,seed+k+19)end
    end
   end
   for k=0,1 do
    local cx,cz=point(1.45,center-1.6+k*3.2)
    for j=0,4 do G.blade(cx,cz,h+.46,1.3+C.hash(seed+k,j,1034)*1.9,.14,.48,j*1.256,'leaf',.9)end
   end
  end
 end end
end
function M.water(x,z,h,edges,emit)
 local G=C.builder(x,z,emit)
 local near=edges.w or edges.e or edges.n or edges.s
 -- Quiet deep floor; a raised shelf at the coast gives the existing underwater pass detail.
 G.flat(x,z,x+8,z+8,h-(near and 2.1 or 7),'body',near and .88 or .57)
 for _,e in ipairs({'w','e','n','s'})do if edges[e] then
  local function point(inset,along)
   if e=='w' then return x+inset,z+along elseif e=='e' then return x+8-inset,z+along
   elseif e=='n' then return x+along,z+inset else return x+along,z+8-inset end
  end
  -- Broad submerged shelves and broken outcrops replace the straight block course.
  for k=0,2 do
   local seed=x*7+z*3+k+string.byte(e)
   local width=1.2+C.hash(seed,k,971)*1.5
   local cx,cz=point(width*.55,.6+k*2.8+C.hash(seed,k,974)*.7)
   rock(G,cx,cz,h-3.0,width,1.7,1.8,seed,'body',.69,4)
   if not edges.dock then
    local cap=1.3+C.hash(seed,k,972)*1.2
    rock(G,cx,cz,h+.05,width,1.6+C.hash(seed,k,975)*.35,cap,seed+1,'body',.57,6)
    if edges.plant and k==1 and C.hash(x,z,973)>.55 then
     for j=0,4 do G.blade(cx,cz,h+cap+.06,1.1+j*.17,.12,.4,j*1.256,'leaf',.81) end
    end
   end
  end
 end end
end
function M.keepLilies(x,z,edges)
 -- Sheltered corners only; leave the open sea clear.
 local count=0;for _,e in ipairs({'w','e','n','s'})do if edges[e] then count=count+1 end end
 return not edges.dock and count>=2 and C.field((x+4)/28,(z+4)/28,910)>.48
end
function M.dock(x,z,h,dx,dz,emit)
 local G=C.builder(x,z,emit)
 local cx=x+(dx<0 and 1.1 or dx>0 and 6.9 or 1.2)
 local cz=z+(dz<0 and 1.1 or dz>0 and 6.9 or 1.2)
 -- Mooring ring and low cleat confined to the outer edge; no central props.
 for j=0,11 do
  local a,b=j*math.pi/6,(j+1)*math.pi/6
  G.face({{cx+.64*math.cos(a),h+.35,cz+.64*math.sin(a)},
    {cx+.64*math.cos(b),h+.35,cz+.64*math.sin(b)},
    {cx+.45*math.cos(b),h+.35,cz+.45*math.sin(b)},
    {cx+.45*math.cos(a),h+.35,cz+.45*math.sin(a)}},'dark',.68)
 end
 G.box(cx-.14,cz-.14,cx+.14,cz+.14,h+.2,h+.6,'dark',.7)
 G.box(cx-.7,cz-.12,cx+.7,cz+.12,h+.55,h+.73,'dark',.8)
end
return M
