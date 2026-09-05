-- Faceted S.S. Anne exterior. All finishes are original source texels;
-- height/depth, glazing and rail construction are an authored 3D remaster.
local V=...
local Budget=V.require('BuildBudget')
local M={}
local EPS=1e-7
local function copy(p)return{p[1],p[2],p[3]}end
local function lerp(a,b,t)return{a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t}end
local function cross(a,b,c)
 local u,v={b[1]-a[1],b[2]-a[2],b[3]-a[3]},{c[1]-a[1],c[2]-a[2],c[3]-a[3]}
 return{u[2]*v[3]-u[3]*v[2],u[3]*v[1]-u[1]*v[3],u[1]*v[2]-u[2]*v[1]}
end
local function length(n)return math.sqrt(n[1]^2+n[2]^2+n[3]^2)end
local function clipped(poly,axis,k,low)
 local out={};local a=poly[#poly];local ain=low and a[axis]<=k+EPS or not low and a[axis]>=k-EPS
 for _,b in ipairs(poly)do
  local bin=low and b[axis]<=k+EPS or not low and b[axis]>=k-EPS
  if bin~=ain then local t=(k-a[axis])/(b[axis]-a[axis]);local p=lerp(a,b,t);p[axis]=k;out[#out+1]=p end
  if bin then out[#out+1]=copy(b)end;a,ain=b,bin
 end
 local clean={}
 for _,p in ipairs(out)do local q=clean[#clean];if not q or math.abs(p[1]-q[1])+math.abs(p[2]-q[2])+math.abs(p[3]-q[3])>EPS then clean[#clean+1]=p end end
 if #clean>1 then local a,b=clean[1],clean[#clean];if math.abs(a[1]-b[1])+math.abs(a[2]-b[2])+math.abs(a[3]-b[3])<EPS then table.remove(clean)end end
 return clean
end
function M.model(sp)
 assert(sp.W==128 and sp.H==48,'ship remaster needs complete source body')
 local faces,roles={},{}
 local function material(x,z,expected)
  local i=z*128+x;assert(sp.col[i]==expected,'ship material source shade changed');return i
 end
 local white=material(62,4,0);local grey=material(60,18,1)
 local dark=material(50,1,2);local black=material(64,47,3)
 local function face(poly,source,role,outward)
  Budget.tick()
  local n=cross(poly[1],poly[2],poly[3]);if length(n)<EPS then return end
  if outward and n[1]*outward[1]+n[2]*outward[2]+n[3]*outward[3]<0 then local r={};for i=#poly,1,-1 do r[#r+1]=poly[i]end;poly=r;n=cross(poly[1],poly[2],poly[3])end
  local shade=.69+.23*math.max(0,n[2]/length(n))+.08*math.max(0,n[3]/length(n))
  local pieces={poly}
  -- Real flat facets are split at the same8px lattice as terrain. This
  -- avoids the long-face world-curvature cracks of a custom uncut mesh.
  for axis=1,3 do
   local nextPieces={}
   for _,part in ipairs(pieces)do
    local lo,hi=math.huge,-math.huge;for _,p in ipairs(part)do lo=math.min(lo,p[axis]);hi=math.max(hi,p[axis])end
    local rest=part;local at=(math.floor((lo+EPS)/8)+1)*8
    while at<hi-EPS do
     local a=clipped(rest,axis,at,true);rest=clipped(rest,axis,at,false)
     if #a>=3 then nextPieces[#nextPieces+1]=a end;at=at+8
    end
    if #rest>=3 then nextPieces[#nextPieces+1]=rest end
   end
   pieces=nextPieces
  end
  local function put(a,b,c,d)
   if length(cross(a,b,c))<EPS or length(cross(a,c,d))<EPS then return end
   faces[#faces+1]={a,b,c,d,source=source,shade=shade,role=role};roles[role]=(roles[role]or 0)+1
  end
  for _,part in ipairs(pieces)do
   if #part==4 then put(part[1],part[2],part[3],part[4])
   else for i=2,#part-1 do local a,b,c=part[1],part[i],part[i+1];put(a,b,lerp(b,c,.5),c)end end
  end
 end
 local function quad(a,b,c,d,source,role,outward)face({a,b,c,d},source,role,outward)end
 local function box(x0,x1,y0,y1,z0,z1,source,role,top)
  quad({x0,y0,z0},{x0,y1,z0},{x1,y1,z0},{x1,y0,z0},source,role,{0,0,-1})
  quad({x0,y0,z1},{x1,y0,z1},{x1,y1,z1},{x0,y1,z1},source,role,{0,0,1})
  quad({x0,y0,z0},{x0,y0,z1},{x0,y1,z1},{x0,y1,z0},source,role,{-1,0,0})
  quad({x1,y0,z0},{x1,y1,z0},{x1,y1,z1},{x1,y0,z1},source,role,{1,0,0})
  quad({x0,y1,z0},{x0,y1,z1},{x1,y1,z1},{x1,y1,z0},top or source,role,{0,1,0})
 end
 local stations={{0,23},{4,15},{12,8},{24,4},{40,1},{56,0},{64,0},{80,0},{96,1},{112,4},{122,8},{128,14}}
 local outline={};for _,p in ipairs(stations)do outline[#outline+1]={p[1],p[2]}end
 for j=#stations,1,-1 do local p=stations[j];outline[#outline+1]={p[1],48-p[2]}end
 local function point(p,y,sx,sz)return{64+(p[1]-64)*sx,y,24+(p[2]-24)*sz}end
 local bands={{0,.94,.66,dark},{4,.98,.80,dark},{6,1,.86,black},{8,1,.90,white},{16,1,1,white},{18,1,1,white},{19,1,1,black},{20,1,1,grey}}
 for i=1,#bands-1 do
  local a,b=bands[i],bands[i+1]
  for j,p in ipairs(outline)do local next=outline[j%#outline+1]
   -- Entrance sides are independent flat jambs. Leave the exact source
   -- gangway interval open from localy2 to18, including curved hull bands.
   local portal=p[2]==0 and next[2]==0 and p[1]>=64 and next[1]<=80
   local function band(y0,y1)
    local t0=(y0-a[1])/(b[1]-a[1]);local t1=(y1-a[1])/(b[1]-a[1])
    local ax,az=a[2]+(b[2]-a[2])*t0,a[3]+(b[3]-a[3])*t0
    local bx,bz=a[2]+(b[2]-a[2])*t1,a[3]+(b[3]-a[3])*t1
    local A,B,C,D=point(p,y0,ax,az),point(next,y0,ax,az),point(next,y1,bx,bz),point(p,y1,bx,bz)
    local outward={(p[1]+next[1])/2-64,0,(p[2]+next[2])/2-24}
    -- Two flat triangles give each flare station a deliberate clean facet.
    face({A,B,C},b[4],'hull',outward);face({A,C,D},b[4],'hull',outward)
   end
   if portal then if a[1]<2 then band(a[1],math.min(2,b[1]))end;if b[1]>18 then band(math.max(18,a[1]),b[1])end
   else band(a[1],b[1])end
  end
 end
 -- Level deck, no stretched side-wall picture. The boat's source gray is
 -- the plank finish; the periphery and rail geometry make its extent clear.
 for j=1,#stations-1 do local a,b=stations[j],stations[j+1]
  quad({a[1],20,a[2]},{a[1],20,48-a[2]},{b[1],20,48-b[2]},{b[1],20,b[2]},grey,'deck',{0,1,0})
 end
 -- Continuous ground0 boarding threshold and open16px-high passage.
 box(64,80,0,2,0,10,dark,'boarding-floor',grey)
 quad({64,2,0},{64,18,0},{64,18,10},{64,2,10},white,'boarding-jamb',{1,0,0})
 quad({80,2,0},{80,2,10},{80,18,10},{80,18,0},white,'boarding-jamb',{-1,0,0})
 quad({64,2,10},{64,18,10},{80,18,10},{80,2,10},black,'boarding-back',{0,0,-1})
 quad({64,18,0},{80,18,0},{80,18,10},{64,18,10},white,'boarding-soffit',{0,-1,0})
 local function bevel(x0,x1,z0,z1,b)return{{x0+b,z0},{x1-b,z0},{x1,z0+b},{x1,z1-b},{x1-b,z1},{x0+b,z1},{x0,z1-b},{x0,z0+b}}end
 local function cabin(x0,x1,y0,y1,z0,z1,b,role)
  local poly=bevel(x0,x1,z0,z1,b)
  for j,p in ipairs(poly)do local q=poly[j%#poly+1];local dx,dz=q[1]-p[1],q[2]-p[2];local span=math.sqrt(dx*dx+dz*dz)
   local steps=math.max(1,math.floor(span/6));local outward={dz,0,-dx}
   for k=0,steps-1 do local f0,f1=k/steps,(k+1)/steps;local a={p[1]+dx*f0,p[2]+dz*f0};local c={p[1]+dx*f1,p[2]+dz*f1}
    local function wall(v0,v1,lo,hi,mat)
     local a0,a1=a[1]+(c[1]-a[1])*v0,a[2]+(c[2]-a[2])*v0
     local b0,b1=a[1]+(c[1]-a[1])*v1,a[2]+(c[2]-a[2])*v1
     quad({a0,lo,a1},{b0,lo,b1},{b0,hi,b1},{a0,hi,a1},mat,role,outward)
    end
    wall(0,1,y0,y0+2,white);wall(0,1,y1-1,y1,white)
    wall(0,.14,y0+2,y1-1,white);wall(.86,1,y0+2,y1-1,white)
    wall(.14,.86,y0+2,y0+3,dark);wall(.14,.86,y0+3,y1-2,black);wall(.14,.86,y1-2,y1-1,grey)
   end
  end
  local center={(x0+x1)/2,y1,(z0+z1)/2}
  for j,p in ipairs(poly)do local q=poly[j%#poly+1];face({center,{p[1],y1,p[2]},{q[1],y1,q[2]}},grey,role..'-roof',{0,1,0})end
 end
 cabin(38,111,20,31,12,36,3,'cabin')
 box(37,112,31,32,11,37,white,'cabin-eave',grey)
 cabin(37,57,32,39,17,31,2,'bridge')
 box(36,58,39,40,16,32,white,'bridge-eave',grey)
 local function beam(a,b,r,source,role)
  local dx,dz=b[1]-a[1],b[3]-a[3];local d=math.sqrt(dx*dx+dz*dz)
  if d<EPS then return end
  local nx,nz=-dz/d*r,dx/d*r
  local p={{a[1]+nx,a[2]-r,a[3]+nz},{b[1]+nx,b[2]-r,b[3]+nz},{b[1]-nx,b[2]-r,b[3]-nz},{a[1]-nx,a[2]-r,a[3]-nz}}
  local t={};for j=1,4 do t[j]={p[j][1],p[j][2]+2*r,p[j][3]}end
  for j=1,4 do local k=j%4+1;quad(p[j],p[k],t[k],t[j],source,role,{(p[j][1]+p[k][1]-a[1]-b[1])/2,0,(p[j][3]+p[k][3]-a[3]-b[3])/2})end
  quad(t[1],t[4],t[3],t[2],source,role,{0,1,0})
 end
 for j,p in ipairs(outline)do local q=outline[j%#outline+1]
  local a={64+(p[1]-64)*.982,20,24+(p[2]-24)*.955}
  local b={64+(q[1]-64)*.982,20,24+(q[2]-24)*.955}
  local span=math.sqrt((b[1]-a[1])^2+(b[3]-a[3])^2);local n=math.max(1,math.ceil(span/8))
  for k=0,n-1 do local t=k/n;local x,z=a[1]+(b[1]-a[1])*t,a[3]+(b[3]-a[3])*t
   box(x-.33,x+.33,20,25,z-.33,z+.33,white,'rail-post')
  end
  for _,y in ipairs({22.25,24.7})do beam({a[1],y,a[3]},{b[1],y,b[3]},.25,white,'rail')end
 end
 local function ring(cx,cz,y,rx,rz,n,lean)
  local out={};for j=0,n-1 do local theta=2*math.pi*j/n;out[j+1]={cx+math.cos(theta)*rx+(lean or 0),y,cz+math.sin(theta)*rz}end;return out
 end
 local function loft(a,b,source,role,inside)
  for j,p in ipairs(a)do local k=j%#a+1;local q=a[k];local normal={(p[1]+q[1])/2-(a[1][1]+a[math.floor(#a/2)+1][1])/2,0,(p[3]+q[3])/2-(a[1][3]+a[math.floor(#a/2)+1][3])/2}
   if inside then normal={-normal[1],0,-normal[3]}end
   quad(p,q,b[k],b[j],source,role,normal)
  end
 end
 for _,cx in ipairs({70,89})do
  local base=ring(cx,24,32,6,5,12);local lower=ring(cx,24,34,5,4,12);local upper=ring(cx,24,52,4.5,3.7,12,1.5);local lip=ring(cx,24,55,5.1,4.3,12,1.5)
  loft(base,lower,white,'funnel-base');loft(lower,upper,grey,'funnel');loft(upper,lip,black,'funnel-cap')
  local mouth=ring(cx,24,55,3.6,2.8,12,1.5);local floor=ring(cx,24,49,3.6,2.8,12,1.5)
  for j,p in ipairs(lip)do local k=j%12+1;quad(p,lip[k],mouth[k],mouth[j],black,'funnel-rim',{0,1,0})end
  loft(mouth,floor,dark,'funnel-inside',true)
  for j=1,12,2 do quad({cx+1.5,49,24},floor[j],floor[j%12+1],floor[(j+1)%12+1],black,'funnel-floor',{0,1,0})end
 end
 -- The original drawing contains two covered boats along the visible side.
 for _,cx in ipairs({72,97})do
  box(cx-5,cx-4,20,24,38.5,42,black,'boat-support');box(cx+4,cx+5,20,24,38.5,42,black,'boat-support')
  local lower=ring(cx,40.2,24,6.5,1.4,12);local rim=ring(cx,40.2,27,8,3,12);local cover=ring(cx,40.2,28,6,1.9,12)
  loft(lower,rim,white,'lifeboat');loft(rim,cover,grey,'lifeboat-cover')
  for j=1,12,2 do quad({cx,28.8,40.2},cover[j],cover[j%12+1],cover[(j+1)%12+1],white,'lifeboat-lid',{0,1,0})end
  for _,x in ipairs({cx-3,cx+3})do beam({x,28.1,38.7},{x,28.1,41.7},.12,dark,'lifeboat-strap')end
 end
 -- Circular dark portholes are geometric insets on the white hull course.
 for _,side in ipairs({-1,1})do
  for _,x in ipairs({28,40,52,88,100,112})do
   local function hullZ(px,py,offset)
    local a,b
    for j=1,#stations-1 do if px>=stations[j][1]and px<=stations[j+1][1]then a,b=stations[j],stations[j+1];break end end
    assert(a and b,'porthole stays on measured hull side')
    local u,v=(px-a[1])/(b[1]-a[1]),(py-8)/8
    local A,B,C,D=24+(a[2]-24)*.9,24+(b[2]-24)*.9,b[2],a[2]
    local north=u>=v and(A+u*(B-A)+v*(C-B))or(A+u*(C-D)+v*(D-A))
    return 24+side*(24-north)+side*offset
   end
   local outer,inner={},{}
   for j=0,7 do local a=2*math.pi*j/8
    local ox,oy=x+1.5*math.cos(a),13+1.5*math.sin(a)
    local ix,iy=x+1.05*math.cos(a),13+1.05*math.sin(a)
    outer[j+1]={ox,oy,hullZ(ox,oy,.08)};inner[j+1]={ix,iy,hullZ(ix,iy,.10)}
   end
   for j=1,8 do local k=j%8+1;quad(outer[j],outer[k],inner[k],inner[j],grey,'porthole-rim',{0,0,side})end
   for j=1,8,2 do quad({x,13,hullZ(x,13,.11)},inner[j],inner[j%8+1],inner[(j+1)%8+1],black,'porthole',{0,0,side})end
  end
 end
 for _,z in ipairs({18,30})do box(18,20,20,22,z-1,z+1,black,'bollard',white)end
 return{W=128,ytop=54,zmin=0,zmax=47,at=function()return nil end,surfaces=faces,roles=roles,
  design={deck=20,entrance={64,80,2,18,0,10},funnels={{70,24},{89,24}},railTop=25,top=55}}
end
return M
