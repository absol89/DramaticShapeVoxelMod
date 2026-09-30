-- TEST90: regional garden silhouettes, bounded plants and connected ornamental trees.
-- Everything is clipped into the existing terrain mesh; no new scene draw pass.
local V=...
local C=V.require('SurfaceCraft')
local M={}
local styles={
 PALLET_TOWN={'timber','cottage','herbs'},
 VIRIDIAN_CITY={'woodland','woodland','crescent'},
 PEWTER_CITY={'quarry','terraced','quarry'},
 CERULEAN_CITY={'waterfront','crescent','corner'},
 FUCHSIA_CITY={'tropical','timber','crescent'},
 SAFFRON_CITY={'formal','corner','hedge'},
 ROUTE_17={'verge','verge','timber'},
}
function M.style(id,index,small)
 local list=styles[id] or styles.PALLET_TOWN
 if small then return id=='SAFFRON_CITY' and (index%3==0 and 'corner' or 'hedge')
  or id=='PALLET_TOWN' and (index%2==0 and 'herbs' or 'timber') or id=='PEWTER_CITY' and 'terraced'
  or id=='VIRIDIAN_CITY' and 'woodland' or id=='CERULEAN_CITY' and 'waterfront'
  or id=='FUCHSIA_CITY' and 'tropical' or id=='ROUTE_17' and 'verge' or 'timber' end
 return list[(index-1)%#list+1]
end
local function cross(a,b,c)return (b[1]-a[1])*(c[2]-a[2])-(b[2]-a[2])*(c[1]-a[1])end
function M.outline(style)
 if style=='corner' then return {{-1,-1},{1,-1},{1,-.30},{-.28,-.30},{-.28,1},{-1,1}} end
 if style=='crescent' then return {{-1,-.4},{-.72,-.85},{0,-1},{.72,-.85},{1,-.4},{.9,.45},{.65,.8},{.38,.58},{0,.36},{-.38,.58},{-.65,.8},{-.9,.45}} end
 if style=='woodland' or style=='quarry' or style=='tropical' or style=='verge' then
  return {{-1,-.48},{-.65,-.94},{-.02,-.8},{.42,-1},{.94,-.55},{1,.18},{.64,.84},{.12,1},{-.47,.68},{-.94,.56}}
 end
 if style=='waterfront' then return {{-.88,-1},{.86,-1},{1,-.55},{1,.60},{.78,1},{-.84,1},{-1,.6},{-1,-.64}} end
 return {{-1,-1},{1,-1},{1,1},{-1,1}}
end
function M.area(style)
 local p=M.outline(style);local sum=0
 for i,a in ipairs(p)do local b=p[i%#p+1];sum=sum+a[1]*b[2]-a[2]*b[1]end
 return math.abs(sum)*.5
end
local function triangles(poly)
 local ids,out={},{};for i=1,#poly do ids[i]=i end
 local guard=0
 while #ids>3 and guard<#poly*#poly do
  guard=guard+1;local found=false
  for j=1,#ids do
   local a,b,c=ids[(j-2)%#ids+1],ids[j],ids[j%#ids+1]
   if cross(poly[a],poly[b],poly[c])>1e-7 then
    local clear=true
    for _,k in ipairs(ids)do if k~=a and k~=b and k~=c then
     local p=poly[k]
     if cross(poly[a],poly[b],p)>=0 and cross(poly[b],poly[c],p)>=0 and cross(poly[c],poly[a],p)>=0 then clear=false;break end
    end end
    if clear then out[#out+1]={a,b,c};table.remove(ids,j);found=true;break end
   end
  end
  assert(found,'invalid garden outline')
 end
 if #ids==3 then out[#out+1]={ids[1],ids[2],ids[3]}end
 return out
end
local function inside(poly,x,z,margin)
 local odd=false;local mind=math.huge
 for i,a in ipairs(poly)do
  local b=poly[i%#poly+1];local dx,dz=b[1]-a[1],b[2]-a[2]
  local t=math.max(0,math.min(1,((x-a[1])*dx+(z-a[2])*dz)/(dx*dx+dz*dz)))
  mind=math.min(mind,(x-a[1]-t*dx)^2+(z-a[2]-t*dz)^2)
  if (a[2]>z)~=(b[2]>z) and x<(b[1]-a[1])*(z-a[2])/(b[2]-a[2])+a[1]then odd=not odd end
 end
 return odd and mind>=(margin or 0)^2
end
local function inset(poly,amount)
 local out={}
 for i,b in ipairs(poly)do
  local a,c=poly[(i-2)%#poly+1],poly[i%#poly+1]
  local dx,dz=b[1]-a[1],b[2]-a[2];local l=math.sqrt(dx*dx+dz*dz);dx,dz=dx/l,dz/l
  local ex,ez=c[1]-b[1],c[2]-b[2];l=math.sqrt(ex*ex+ez*ez);ex,ez=ex/l,ez/l
  local nx,nz=-dz-ez,dx+ex;local dot=nx*(-dz)+nz*dx
  out[i]={b[1]+nx*amount/math.max(.15,dot),b[2]+nz*amount/math.max(.15,dot)}
 end
 return out
end
local function rock(G,x,z,y,rx,rz,height,mat,seed)
 local n=7
 for i=0,n-1 do
  local rotation=C.hash(seed,0,9001)*6.28
  local a,b=i*math.pi*2/n+rotation,(i+1)*math.pi*2/n+rotation
  local ra=.80+C.hash(i,seed,9002)*.20;local rb=.80+C.hash((i+1)%n,seed,9002)*.20
  local p={x+math.cos(a)*rx*ra,y,z+math.sin(a)*rz*ra};local q={x+math.cos(b)*rx*rb,y,z+math.sin(b)*rz*rb}
  local ha=height*(.75+C.hash(i,seed,9003)*.25);local hb=height*(.75+C.hash((i+1)%n,seed,9003)*.25)
  local r={x+math.cos(b)*rx*rb*.67,y+hb,z+math.sin(b)*rz*rb*.67};local s={x+math.cos(a)*rx*ra*.67,y+ha,z+math.sin(a)*rz*ra*.67}
  G.face({p,q,r,s},mat,.72+C.hash(i,seed,8901)*.24)
  G.face({s,r,{x-rx*.12,y+height+.45,z}},mat,.94+C.hash(i,seed,8902)*.12)
 end
end
local function fern(G,x,z,y,size,seed)
 for j=0,5 do
  local a=j*math.pi/3+seed*.7;local dx,dz=math.cos(a),math.sin(a)
  for k=1,4 do
   local t=k/4;local px,pz=x+dx*size*t,z+dz*size*t;local yy=y+size*(.25+math.sin(t*2.2)*.52)
   local w=size*.26*(1-t*.65)
   for _,side in ipairs({-1,1})do
    local q={{px-dx*.28,yy-.15,pz-dz*.28},{px-dz*w*side-dx*.35,yy+.06,pz+dx*w*side-dz*.35},{px+dx*.38,yy+.10,pz+dz*.38}}
    G.face(q,'canopy',.88+j*.04);G.face({q[3],q[2],q[1]},'canopy',.74+j*.03)
   end
  end
 end
end
local function bloom(G,x,z,y,size,seed,white)
 V.require('WorldGardens').foliage(G,x,z,y,seed,size*.64)
 for j=0,2 do
  local a=seed*.6+j*2.4;local px,pz=x+math.cos(a)*.44,z+math.sin(a)*.44
  local top=y+(2.0+j*.38)*size
  G.blade(px,pz,y,top-y,.07,.12,a,'leaf',.9)
  for k=0,4 do
   local u=k*math.pi*.4;local r=.65*size
   G.face({{px,top-.12,pz},{px+math.cos(u-.46)*r,top,pz+math.sin(u-.46)*r},{px+math.cos(u+.46)*r,top,pz+math.sin(u+.46)*r}},white and 'flowerWhite' or 'flowerViolet',1.02)
  end
  G.flat(px-.12,pz-.12,px+.12,pz+.12,top+.02,'light',.95)
 end
end
function M.build(x,z,h,f,emit,id)
 local G=C.builder(x,z,emit);local style=f.style or M.style(id,1,false)
 local poly={};for _,p in ipairs(M.outline(style))do poly[#poly+1]={f.cx+p[1]*f.rx,f.cz+p[2]*f.rz}end
 local timber=style=='timber' or style=='herbs' or style=='cottage' or style=='coastal'
 local wild=style=='woodland' or style=='quarry' or style=='verge'
 local height=timber and 2.6 or wild and .65 or 1.8
 local rim=wild and .35 or .62;local inner=inset(poly,rim)
 local mat=timber and 'wood' or 'cityBorder'
 local function p(q,y)return {q[1],h+y,q[2]}end
 for _,tri in ipairs(triangles(poly))do G.face({p(poly[tri[1]],height-.25),p(poly[tri[2]],height-.25),p(poly[tri[3]],height-.25)},'soil',.86)end
 for i,a in ipairs(poly)do
  local j=i%#poly+1;local b=poly[j]
  G.face({p(a,.12),p(b,.12),p(b,height),p(a,height)},mat,.8+(i%3)*.05)
  G.face({p(a,height),p(b,height),p(inner[j],height),p(inner[i],height)},mat,1.06)
  G.face({p(inner[i],height),p(inner[j],height),p(inner[j],height-.25),p(inner[i],height-.25)},mat,.74)
  if timber then
   local px,pz=a[1]*.96+f.cx*.04,a[2]*.96+f.cz*.04
   G.box(px-.14,pz-.14,px+.14,pz+.14,h+.3,h+height+.06,'shadow',.64)
  end
 end
 -- Foliage covers the soil in linked masses. Flower heads remain accents.
 local World=V.require('WorldGardens')
 local quarry=style=='quarry' or style=='terraced'
 local forest=style=='woodland' or style=='verge'
 local tropical=style=='tropical' or (id=='FUCHSIA_CITY' and style=='crescent')
 local rocks={}
 if quarry then
  for i,spot in ipairs({{-.45,.12,2.8,1.85,1.25},{.12,-.18,3.4,2.25,1.85},{.56,.35,2.1,1.65,.85}})do
   local px,pz=f.cx+f.rx*spot[1],f.cz+f.rz*spot[2]
   if inside(poly,px,pz,spot[3]+.4)then
    rock(G,px,pz,h+height-.30,spot[3],spot[4],spot[5],'stonePaving',i*31+f.cx)
    rock(G,px-.3,pz+.2,h+height-.15,spot[3]*.56,spot[4]*.70,.3,'canopy',i+9)
    rocks[#rocks+1]={px,pz,spot[3]+.4}
   end
  end
 end
 local serial=0
 for zz=f.cz-f.rz+1.8,f.cz+f.rz-1.8,2.9 do for xx=f.cx-f.rx+1.8,f.cx+f.rx-1.8,2.9 do
  serial=serial+1
  local px=xx+(C.hash(serial,f.cx,8903)-.5)*1.1
  local pz=zz+(C.hash(serial,f.cz,8904)-.5)*1.1
  if inside(poly,px,pz,1.85)then
   local y=h+height-.21
   local inRock=false;for _,r in ipairs(rocks)do if (px-r[1])^2+(pz-r[2])^2<r[3]^2 then inRock=true end end
   if not inRock then
    World.foliage(G,px,pz,y,serial,.94)
    if style=='hedge' or (style=='formal' and serial%4~=0)then
     rock(G,px,pz,y,1.55,1.35,2.0+C.hash(serial,f.cx,9004)*1.1,'canopy',serial)
    elseif forest then
     if serial%3==0 and inside(poly,px,pz,3.0)then fern(G,px,pz,y,2.65,serial)
     elseif style~='verge' and serial%5==0 then bloom(G,px,pz,y,.92,serial,true)
     else
      for j=0,3 do G.blade(px,pz,y,1.2+C.hash(serial,j,9005)*1.5,.20,.75,j*1.57,'leaf',1.06)end
     end
    elseif quarry then
     if serial%4==0 then bloom(G,px,pz,y,.98,serial,true)
     else rock(G,px,pz,y,1.25,1.15,1.2,'canopy',serial)end
    elseif tropical then
     if inside(poly,px,pz,2.6)then World.foliage(G,px,pz,y+.5,serial+13,1.35)end
     if serial%3==0 and inside(poly,px,pz,2.2)then bloom(G,px,pz,y,1.28,serial,false)end
    elseif style=='coastal' then
     World.foliage(G,px,pz,y+.45,serial,.95)
     for j=0,4 do G.blade(px,pz,y,1.4+j*.32,.15,.55,j*1.26,'leaf',.88+j*.04)end
     if serial%4==0 then bloom(G,px,pz,y,.95,serial,true)end
    elseif style=='herbs' then
     for j=0,3 do G.blade(px,pz,y,1.4+j*.35,.27,.4,j*1.6,'leaf',.92+j*.06)end
     if serial%5==0 then bloom(G,px,pz,y,.8,serial,true)end
    else
     local white=id=='CERULEAN_CITY' and serial%4~=0 or id~='CERULEAN_CITY' and serial%3==0
     if serial%3~=0 then bloom(G,px,pz,y,1.05+C.hash(serial,f.cx,9006)*.20,serial,white)
     else rock(G,px,pz,y,1.3,1.2,1.65,'canopy',serial)end
    end
   end
  end
 end end
 -- Labels are mounted inside the bed, never freestanding on a walking route.
 if style=='herbs' then
  for _,off in ipairs({-.45,.45})do local px=f.cx+f.rx*off
   G.box(px-.1,f.cz-.1,px+.1,f.cz+.1,h+height,h+height+1.5,'wood',.85)
   G.box(px-.65,f.cz-.14,px+.65,f.cz+.14,h+height+1.1,h+height+1.75,'cityBorder',1)
  end
 end
end
function M.tree(x,z,h,f,emit,id)
 local G=C.builder(x,z,emit);local a,b=f.cx,f.cz
 V.require('CeladonGardenDetail').treeBase(x,z,h,f,emit)
 local function limb(ax,az,ay,bx,bz,by,r)
  local n=6
  for i=0,n-1 do
   local u,v=i*math.pi*2/n,(i+1)*math.pi*2/n
   G.face({{ax+math.cos(u)*r,h+ay,az+math.sin(u)*r},{ax+math.cos(v)*r,h+ay,az+math.sin(v)*r},{bx+math.cos(v)*r*.62,h+by,bz+math.sin(v)*r*.62},{bx+math.cos(u)*r*.62,h+by,bz+math.sin(u)*r*.62}},'wood',.78+i*.04)
  end
 end
 limb(a,b,.22,a+.3,b,23,1.1)
 local tropical=id=='FUCHSIA_CITY'
 local count=id=='SAFFRON_CITY' and 3 or tropical and 6 or 5
 local function crown(px,pz,y,rx,rz,ry,seed)
  local rings={-1,-.62,0,.64,1};local n=9
  for k=1,#rings-1 do for j=0,n-1 do
   local function pt(r,i)
    local t=rings[r];local a=i*math.pi*2/n+seed*.7
    local radius=math.sqrt(math.max(0,1-t*t))*(.9+C.hash(i%n,seed,9020)*.10)
    return {px+math.cos(a)*rx*radius,h+y+t*ry,pz+math.sin(a)*rz*radius}
   end
   G.face({pt(k,j),pt(k,j+1),pt(k+1,j+1),pt(k+1,j)},'canopy',1.02+C.hash(j,seed+k,9021)*.23)
  end end
 end
 for i=0,count-1 do
  local angle=i*2.4;local radius=i==0 and 0 or tropical and 4.5 or 3.6
  local px,pz=a+math.cos(angle)*radius,b+math.sin(angle)*radius
  local y=tropical and (23+(i%2)*1.7) or (21+(i%3)*1.6)
  limb(a+.2,b,14+i,px,pz,y,.62)
  crown(px,pz,y,tropical and 4.8 or 4.3,3.9,tropical and 3.8 or 5.6,i)
  for j=0,7 do
   local u=j*2.4;local cx=px+math.cos(u)*3.8;local cz=pz+math.sin(u)*3.2
   V.require('WorldGardens').foliage(G,cx,cz,h+y+(j%3)-1.5,i*11+j,.72)
  end
 end
end
M.inside=inside
return M
