-- Legendary forest trees: shared, bounded native meshes replacing ROM-pixel
-- hulls. Opaque folded leaves need no alpha blending, extra draws or particles.
local V=...
local M={REVISION='forest-deep-crowns-105',RADIUS=46,GROUND_RADIUS=15.2,OVERHANG_HEIGHT=24}
local cache={}
local pi=math.pi
local function hash(n,s)local v=math.sin(n*12.9898+s*78.233)*43758.5453;return v-math.floor(v)end
local function add(a,b)return {a[1]+b[1],a[2]+b[2],a[3]+b[3]}end
local function mul(a,s)return {a[1]*s,a[2]*s,a[3]*s}end
local function cross(a,b)return {a[2]*b[3]-a[3]*b[2],a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1]}end
local function unit(a)local l=math.sqrt(a[1]^2+a[2]^2+a[3]^2);return mul(a,1/math.max(l,.00001))end
local function between(a,b,t)return {a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t}end
function M.enabled(map,custom)
 return custom and map and (map.id or(map.def or{}).id)=='VIRIDIAN_FOREST'
  and ((map.tileset or{}).id or(map.def or{}).tileset)=='FOREST' or false
end
function M.variant(cx,cy)return (cx*17+cy*29)%4 end
function M.detail(value)return (value=='handheld'or value=='balanced')and value or 'full'end
function M.template(variant,detail)
 variant=variant%4;detail=M.detail(detail)
 local key=variant..':'..detail;if cache[key]then return cache[key]end
 local out,branches,lobes,woodPaths={},{},{},{}
 local function face(a,b,c,d,mat,t)
  V.require('BuildBudget').tick()
  out[#out+1]={a,b,c,d,referenceMaterial=mat,shade=t or 1,u=.00390625,v=.00390625}
 end
 local function limb(a,b,ra,rb,sides)
  branches[#branches+1]={a=a,b=b,ra=ra,rb=rb}
  local dir=unit({b[1]-a[1],b[2]-a[2],b[3]-a[3]})
  local u=unit(cross(dir,math.abs(dir[2])>.9 and {1,0,0}or{0,1,0}));local v=cross(dir,u)
  local A,B={},{}
  for i=0,sides-1 do
   local t=i*2*pi/sides;local d=add(mul(u,math.cos(t)),mul(v,math.sin(t)))
   A[i+1]=add(a,mul(d,ra));B[i+1]=add(b,mul(d,rb))
   -- Flatten the foot ring to the source ground plane even on leaning boles.
   if a[2]<.01 then A[i+1][2]=0 end
  end
  for i=1,sides do local j=i%sides+1
   local tone=.88+.10*math.cos(i*2*pi/sides+.6)
   face(A[i],A[j],B[j],B[i],'forestBark',tone)
   if a[2]<.01 then face(a,A[j],A[i],A[i],'forestBark',.76)end
   face(b,B[i],B[j],B[j],'forestBark',.82)
  end
 end
 -- Each bent tube shares its rings between adjoining sections. Independent
 -- segment frames leave wedge-shaped holes at bends, especially on thick boles.
 local function woodPath(points,radii,sides,closed)
  local first=#out+1
  local u,v
  if closed then u,v={1,0,0},{0,0,1} -- horizontal trunk rings, flat grounded foot
  else
   local a,b=points[1],points[#points]
   local dir=unit({b[1]-a[1],b[2]-a[2],b[3]-a[3]})
   u=unit(cross(dir,math.abs(dir[2])>.9 and {1,0,0}or{0,1,0}));v=cross(dir,u)
  end
  local rings={}
  for j,p in ipairs(points)do
   rings[j]={}
   for i=0,sides-1 do
    local a=i*2*pi/sides+(closed and .025*math.sin(j*.9+variant)or 0)
    local relief=closed and (.94+.06*math.cos(i*pi+variant*.1))or 1
    rings[j][i+1]=add(p,add(mul(u,math.cos(a)*radii[j]*relief),mul(v,math.sin(a)*radii[j]*relief)))
   end
  end
  for j=1,#points-1 do
   branches[#branches+1]={a=points[j],b=points[j+1],ra=radii[j],rb=radii[j+1]}
   for i=1,sides do local k=i%sides+1
    face(rings[j][i],rings[j][k],rings[j+1][k],rings[j+1][i],
     'forestBark',.88+.10*math.cos(i*2*pi/sides+.6))
   end
  end
  if closed then
   for i=1,sides do local k=i%sides+1
    face(points[1],rings[1][k],rings[1][i],rings[1][i],'forestBark',.76)
    local n=#points
    face(points[n],rings[n][i],rings[n][k],rings[n][k],'forestBark',.84)
   end
  end
  woodPaths[#woodPaths+1]={first=first,last=#out,sides=sides,closed=closed or false}
  if closed then
   -- Two shallow knot collars follow the real trunk faces, not floating decals.
   for knot=1,2 do
    local j=knot+1;local i=(variant*3+knot*7)%sides+1;local k=i%sides+1
    local A,B,C,D=rings[j][i],rings[j][k],rings[j+1][k],rings[j+1][i]
    local normal=unit(cross(add(B,mul(A,-1)),add(D,mul(A,-1))))
    if normal[1]*A[1]+normal[3]*A[3]<0 then normal=mul(normal,-1)end
    local function patch(u,v,lift)
     local p
     if v<=u then p=add(add(mul(A,1-u),mul(B,u-v)),mul(C,v))
     else p=add(add(mul(A,1-v),mul(C,u)),mul(D,v-u))end
     return add(p,mul(normal,lift))
    end
    local rings={}
    for band=1,3 do
     rings[band]={};local size=({1,.65,.3})[band]
     for n=0,11 do local a=n*2*pi/12
      rings[band][n+1]=patch(.5+math.cos(a)*.36*size,.48+math.sin(a)*.28*size,({.05,.28,.13})[band])
     end
    end
    for band=1,2 do for n=1,12 do local k=n%12+1
     face(rings[band][n],rings[band][k],rings[band+1][k],rings[band+1][n],'forestBark',band==1 and .92 or .69)
    end end
    local center=patch(.5,.48,.14)
    for n=1,12 do local k=n%12+1;face(rings[3][n],rings[3][k],center,center,'forestBark',.74)end
   end
  end
 end
 -- One continuous capped trunk; its branching forks share their elbow rings.
 local lean=({.8,-1.1,1.7,-.6})[variant+1]
 local trunk={{0,0,0},{lean*.2,7,-.35},{lean,15,.45},{lean*.7,23,0},{lean*.4,31,-.3},{0,39,0}}
 local radii={8.4,6.4,5.2,3.8,2.2,.55}
 woodPath(trunk,radii,20,true)
 for i=0,4 do
  local a=i*2*pi/5+variant*.41
  limb({lean*.1,3.2,0},{math.cos(a)*10,.32,math.sin(a)*10},2.3,.32,6)
 end
 local function lobe(c,r,seed,leaves)
  lobes[#lobes+1]={center=c,radius=r}
  local rings,segments=6,9;local points,shades={},{}
  local function surface(n,az,latitude,embed)
   local ripple=1+.075*math.sin(az*3+seed)+.035*math.sin(latitude*5+seed)
   local rise=1+.11*math.sin(az*2+seed)*math.cos(latitude)
   return {c[1]+n[1]*r[1]*ripple*embed,c[2]+n[2]*r[2]*rise*embed,c[3]+n[3]*r[3]*ripple*embed}
  end
  for j=0,rings do points[j]={};shades[j]={}
   local latitude=-pi/2+j*pi/rings
   for i=0,segments-1 do
    local a=i*2*pi/segments
    local n={math.cos(latitude)*math.cos(a),math.sin(latitude),math.cos(latitude)*math.sin(a)}
    points[j][i+1]=surface(n,a,latitude,1)
    shades[j][i+1]=.79+.16*(n[2]+1)/2+.055*n[1]-.04*n[3]
   end
  end
  for j=0,rings-1 do for i=1,segments do local k=i%segments+1
   local q={points[j][i],points[j][k],points[j+1][k],points[j+1][i]}
   -- At the poles one triangle is intentionally shared at a single vertex.
   face(q[1],q[2],q[3],q[4],'forestCore',{shades[j][i],shades[j][k],shades[j+1][k],shades[j+1][i]})
  end end
  local count=leaves and (detail=='full'and 61 or detail=='balanced'and 45 or 29)or 0
  for i=1,count do
   -- A stable spherical distribution avoids horizontal tiers and checker rows.
   local y=1-2*(i-.5)/count;local az=i*2.39996323+seed
   local n={math.sqrt(1-y*y)*math.cos(az),y,math.sqrt(1-y*y)*math.sin(az)}
   -- Anchor each sprig on the actual triangulated core, avoiding buried leaves.
   local u=(az%(2*pi))*segments/(2*pi);local cell=math.floor(u);u=u-cell
   local v=(math.asin(y)+pi/2)*rings/pi;local row=math.min(rings-1,math.floor(v));v=v-row
   local A,B,C,D=points[row][cell+1],points[row][(cell+1)%segments+1],points[row+1][(cell+1)%segments+1],points[row+1][cell+1]
   local root
   if v<=u then root=add(add(mul(A,1-u),mul(B,u-v)),mul(C,v))
   else root=add(add(mul(A,1-v),mul(C,u)),mul(D,v-u))end
   local around=unit(cross(n,math.abs(n[2])>.9 and{1,0,0}or{0,1,0}))
   local along=unit(cross(around,n))
   local twist=hash(i,seed+14)*2*pi
   local direction=unit(add(add(mul(around,math.cos(twist)),mul(along,math.sin(twist))),mul(n,.42)))
   local tangent=unit(cross(direction,n))
   local normal=n
   local length=1.55+hash(i,seed)*.95;local width=.68+hash(i,seed+2)*.35
   local tip=add(root,mul(direction,length))
   local mid=add(root,mul(direction,length*.50))
   local left=add(mid,mul(tangent,width));local right=add(mid,mul(tangent,-width))
   local ridge=add(mid,mul(normal,.23))
   local tone=.86+hash(i,seed+8)*.23+math.max(0,y)*.05
   face(root,left,tip,ridge,'forestLeaf',tone)
   out[#out].uv={{.5,0},{0,.48},{.5,1},{.5,.52}}
   face(root,ridge,tip,right,'forestLeaf',tone*.9)
   out[#out].uv={{.5,0},{.5,.52},{.5,1},{1,.48}}
   if detail~='handheld' then
    local shoot=add(root,mul(direction,length*.28))
    local side=unit(add(add(mul(direction,.45),mul(tangent,i%2==0 and .85 or -.85)),mul(n,.25)))
    local tip=add(shoot,mul(side,length*.78));local center=between(shoot,tip,.5)
    local across=unit(cross(side,n))
    face(shoot,add(center,mul(across,width*.65)),tip,add(center,mul(across,-width*.65)),'forestLeaf',tone*.94)
    out[#out].uv={{.5,0},{0,.48},{.5,1},{1,.48}}
   end
  end
 end
 -- Buried core joins the upper stem to the outward leaf-bearing lobes.
 lobe({lean*.5,32.5,0},{10.5,11,10.0},variant+2,false)
 local twist=variant*.77
 for i=0,4 do
  local a=i*2*pi/5+twist;local h=33.5+hash(i,variant+10)*4
  local rr=14.8+hash(i,variant+40)*1.5
  local c={math.cos(a)*rr,h,math.sin(a)*rr}
  local elbow=between(trunk[3],c,.57);elbow[2]=h-4
  woodPath({trunk[3],elbow,c},{2.3,1.3,.4},7,false)
  lobe(c,{5.5*(.92+hash(i,variant+55)*.16),math.min(h-26,6.4+hash(i,variant+57)*1.5),5.4*(.92+hash(i,variant+58)*.16)},11+i+variant*7,true)
 end
 for i=0,3 do
  local a=i*2*pi/4+twist+.52;local rr=8.5
  local c={math.cos(a)*rr,35.0+hash(i,variant+29)*5,math.sin(a)*rr}
  local elbow=between(trunk[4],c,.55)
  woodPath({trunk[4],elbow,c},{1.6,.95,.35},6,false)
  lobe(c,{7.6,8.8,7.4},31+i+variant*7,true)
 end
 lobe({-2.4,37.8,1.3},{8.8,10.2,8.5},71+variant,true)
 -- Low fern fans occupy root pockets, never a new walkable/encounter cell.
 -- Reuse the native leaf material so battle cutaway also clears these fronds.
 local fernStart=#out+1
 for cluster=0,2 do
  local angle=variant*.91+cluster*2*pi/3+.35
  local root={math.cos(angle)*8.2,.2,math.sin(angle)*8.2}
  for frond=0,3 do
   local a=angle+(frond-1.5)*.65
   local length=2.8+hash(frond,variant+cluster+90)*.8
   local mid={root[1]+math.cos(a)*length*.52,1.7,root[3]+math.sin(a)*length*.52}
   local tip={root[1]+math.cos(a)*length,.7,root[3]+math.sin(a)*length}
   local left={mid[1]-math.sin(a)*.62,mid[2]-.18,mid[3]+math.cos(a)*.62}
   local right={mid[1]+math.sin(a)*.62,mid[2]-.18,mid[3]-math.cos(a)*.62}
   face(root,left,tip,mid,'forestLeaf',.87)
   out[#out].uv={{.5,0},{0,.48},{.5,1},{.5,.52}}
   face(root,mid,tip,right,'forestLeaf',.80)
   out[#out].uv={{.5,0},{.5,.52},{.5,1},{1,.48}}
  end
 end
 -- Coherent family proportions: broad oak, upright, leaning, compact fork.
 local sy=({1,1.06,1.02,.94})[variant+1]
 local sx=({1,.98,1,1.03})[variant+1]
 local sz=({.98,.97,1,.99})[variant+1]
 local maxr=0
 for _,q in ipairs(out)do for i=1,4 do local p=q[i];maxr=math.max(maxr,math.sqrt((p[1]*sx)^2+(p[3]*sz)^2))end end
 local radial=math.min(.96,23/maxr)
 -- Preserve TEST100's approved total height while reshaping the upper crown.
 local heightCaps={
  {handheld=47.694199174382,balanced=47.497405479385,full=47.757148441553},
  {handheld=48.456732311606,balanced=48.669642478879,full=48.500985898734},
  {handheld=47.794178813826,balanced=48.263116255094,full=48.541297628389},
  {handheld=44.754138262546,balanced=44.842419410153,full=44.820747004693},
 }
 local maxY=0
 for _,q in ipairs(out)do for i=1,4 do maxY=math.max(maxY,q[i][2]*sy)end end
 local heightScale=(heightCaps[variant+1][detail]-24)/(maxY-24)
 -- Double crown depth above the clear underside; keep the main trunk height. Ground-level
 -- wood stays inside its source footprint; the large crown overhang is raised.
 local function transformed(p,fern,keepTrunk)
  local y=p[2]*sy;if y>24 then
   y=24+(y-24)*heightScale
   if not keepTrunk then y=24+2*(y-24)end
  end;local scale=fern and 1.2 or 2
  local x,z=p[1]*sx*radial*scale,p[3]*sz*radial*scale
  local radius=math.sqrt(x*x+z*z)
  if y<24 and radius>M.GROUND_RADIUS then
   local k=M.GROUND_RADIUS/radius;x,z=x*k,z*k
  end
  return {x,y,z}
 end
 -- Faces share vertex tables. Transform each table exactly once.
 local done={}
 for qi,q in ipairs(out)do for i=1,4 do local p=q[i]
  if not done[p]then local t=transformed(p,qi>=fernStart,qi<=woodPaths[1].last);p[1],p[2],p[3]=t[1],t[2],t[3];done[p]=true end
 end end
 -- Transform metadata separately; limb endpoints also belong to face tables.
 local meta={}
 for bi,b in ipairs(branches)do
  local function pt(p)if done[p]then return {p[1],p[2],p[3]}end;return transformed(p,false,bi<=#trunk-1)end
  local a,c=pt(b.a),pt(b.b)
  meta[#meta+1]={a=a,b=c,ra=b.ra*radial*2,rb=b.rb*radial*2}
 end
 local crowns={}
 for _,l in ipairs(lobes)do
  crowns[#crowns+1]={center=transformed(l.center),radius={l.radius[1]*sx*radial*2,l.radius[2]*sy*heightScale*2,l.radius[3]*sz*radial*2}}
 end
 local result={quads=out,branches=meta,lobes=crowns,variant=variant,detail=detail,radius=M.RADIUS,fernStart=fernStart,woodPaths=woodPaths}
 cache[key]=result;return result
end
function M.stamp(template,cx,cy,base)
 local a=((cx*11+cy*7)%16)*2*pi/16
 return {quads=template.quads,mx=cx*16+16,mz=cy*16+16,r=16,
  forestTree=true,treeCos=math.cos(a),treeSin=math.sin(a),lift=base or 0}
end
function M.expand(q,st,sc)
 for i=1,4 do local p,s=q[i],sc[i]
  s[1]=st.mx+p[1]*st.treeCos-p[3]*st.treeSin
  s[2]=p[2]+(st.lift or 0)
  s[3]=st.mz+p[1]*st.treeSin+p[3]*st.treeCos
 end
end
return M
