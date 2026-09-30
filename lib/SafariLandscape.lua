-- Legendary reserve landscape. Source collision and walking planes are immutable.
-- Static, batched geometry uses the existing native forest material/battle contract.
local V=...;local M={};local cache={};local pi=math.pi
local function key(x,z)return(z+64)*4096+x+64 end
local function hash(x,z,s)return V.require('SurfaceCraft').hash(x,z,s)end
local function kit()return V.require('CityMesh').new({.5/128,.5/48})end
local function append(S,qs)for _,q in ipairs(qs)do S.objectQuads[#S.objectQuads+1]=q end end
local function eventClear(map,x,z,pad)
 for _,list in ipairs({map.def.warps or{},map.def.signs or{},map.def.objects or{}})do
  for _,e in ipairs(list)do if e.x and e.y and math.abs(e.x*16+8-x)<pad and math.abs(e.y*16+8-z)<pad then return false end end
 end
 return true
end
-- Forked woody support: bark grooves follow the actual branch taper.
local function limb(G,a,b,ra,rb,seed)
 local dx,dy,dz=b[1]-a[1],b[2]-a[2],b[3]-a[3];local len=math.sqrt(dx*dx+dy*dy+dz*dz)
 local ux,uy,uz=dy/len,-dx/len,0;local vl=math.sqrt(ux*ux+uy*uy);ux,uy=ux/vl,uy/vl
 local vx,vy,vz=-dz*uy/len,dz*ux/len,(dx*uy-dy*ux)/len
 local rings={}
 for j=0,3 do local t=j/3;local r=ra*(1-t)+rb*t;rings[j+1]={}
  for i=0,9 do local aa=i*2*pi/10;local rr=r*(1+.09*math.sin(i*2.4+seed))
   rings[j+1][i+1]={a[1]+dx*t+(ux*math.cos(aa)+vx*math.sin(aa))*rr,a[2]+dy*t+(uy*math.cos(aa)+vy*math.sin(aa))*rr,a[3]+dz*t+(uz*math.cos(aa)+vz*math.sin(aa))*rr}
  end
 end
 for j=1,3 do for i=1,10 do local k=i%10+1
  G.face(rings[j][i],rings[j][k],rings[j+1][k],rings[j+1][i],'forestBark',.88+.09*math.sin(i+seed))
  if i%2==0 then
   local p,q=rings[j][i],rings[j+1][i];local u,v=rings[j][k],rings[j+1][k]
   local a,b,c,d={},{},{},{}
   for n=1,3 do a[n]=p[n]*.88+u[n]*.12;b[n]=p[n]*.82+u[n]*.18;c[n]=q[n]*.81+v[n]*.19;d[n]=q[n]*.86+v[n]*.14 end
   -- Offset along the face normal, not along the strip (which would z-fight).
   local e,f={q[1]-p[1],q[2]-p[2],q[3]-p[3]},{u[1]-p[1],u[2]-p[2],u[3]-p[3]}
   local n={e[2]*f[3]-e[3]*f[2],e[3]*f[1]-e[1]*f[3],e[1]*f[2]-e[2]*f[1]}
   local center={0,0,0};for _,v in ipairs(rings[j])do for k=1,3 do center[k]=center[k]+v[k]/10 end end
   local sign=n[1]*(p[1]-center[1])+n[2]*(p[2]-center[2])+n[3]*(p[3]-center[3])<0 and -1 or 1
   local length=math.sqrt(n[1]^2+n[2]^2+n[3]^2)
   for _,pt in ipairs({a,b,c,d})do for k=1,3 do pt[k]=pt[k]+sign*n[k]/length*.025 end end
   G.face(a,b,c,d,'forestBark',.68)
  end
 end end
end
-- Rounded lobes have uneven shoulders and curved upper rings, never a flat cap.
local function crown(G,c,rx,ry,rz,seed,tier)
 local n,lat=10,6;local rings={};local first=#G.out+1
 for j=0,lat do local a=-pi/2+j*pi/lat;rings[j+1]={}
  for i=0,n-1 do local b=i*2*pi/n;local r=1+.07*math.sin(i*2.1+j*1.7+seed)
   rings[j+1][i+1]={c[1]+math.cos(a)*math.cos(b)*rx*r,c[2]+math.sin(a)*ry,c[3]+math.cos(a)*math.sin(b)*rz*r}
  end
 end
 for j=1,lat do for i=1,n do local k=i%n+1
  G.face(rings[j][i],rings[j][k],rings[j+1][k],rings[j+1][i],'forestCore',.91+.06*math.sin(i+seed)+j*.014)
 end end
 -- Broad folded leaves are anchored to actual hull faces; no floating diamonds.
 for j=0,11+tier*8 do
  local q=G.out[first+10+(j*17+seed*3)%40];local a={}
  for k=1,3 do a[k]=(q[1][k]+q[2][k]+q[3][k])/3 end
  local angle=math.atan2(a[3]-c[3],a[1]-c[1]);local ux,uz=-math.sin(angle),math.cos(angle)
  local w=.55+(j%3)*.17;local tip={a[1]+math.cos(angle)*1.2,a[2]+.9,a[3]+math.sin(angle)*1.2}
  G.face(a,{a[1]+ux*w,a[2]+.18,a[3]+uz*w},tip,tip,'forestLeaf',1.03)
  G.face(a,tip,{a[1]-ux*w,a[2]+.18,a[3]-uz*w},{a[1]-ux*w,a[2]+.18,a[3]-uz*w},'forestLeaf',.9)
 end
end
function M.template(kind,variant)
 local detail=V.require('CommunityVisuals').treeDetailLevel();local id=kind..variant..detail
 if cache[id]then return cache[id]end
 local tier=detail=='handheld'and 0 or detail=='full'and 2 or 1;local G=kit()
 local tall=kind=='tree'or kind=='grove';local big=kind=='grove'
 local h=big and 29+variant*1.4 or tall and 18+variant*.8 or 8.5+variant*.65
 local stem=big and 3.1 or tall and 1.9 or .8
 local fork={.6*math.sin(variant),h*(tall and .61 or .24),.5*math.cos(variant)}
 limb(G,{0,.04,0},fork,stem*1.4,stem*.64,variant)
 local centers={}
 for j=0,2 do local a=j*2*pi/3+variant*.7;local spread=big and 6.4 or tall and 3.4 or 2.4
  local tip={math.cos(a)*spread,h+(j==1 and 2.8 or j==2 and -1.7 or .2),math.sin(a)*spread}
  limb(G,fork,tip,stem*.64,stem*.20,j+variant)
  centers[#centers+1]=tip
  local rx=(big and 9.2 or tall and 6.0 or 4.0)*(j==1 and .91 or j==2 and 1.06 or 1);local ry=(big and 7.4 or tall and 5.4 or 4.6)*(j==1 and 1.12 or .93)
  crown(G,tip,rx,ry,rx*(j==0 and 1.10 or .91),variant+j,tier)
 end
 -- A central upper lobe joins the shoulders into one irregular crown.
 crown(G,{-.45,h+2.1,.35},big and 8.5 or tall and 5.6 or 3.8,big and 7.0 or tall and 5.8 or 4.6,big and 7.4 or tall and 5.0 or 3.7,variant+4,tier)
 if not tall then
  for j=0,5 do local a=j*2.399+variant;local root={math.cos(a)*.6,.5,math.sin(a)*.6}
   local tip={math.cos(a)*6.5,1.7+(j%3)*.6,math.sin(a)*6.5};local mid={tip[1]*.56,3.4,tip[3]*.56};local ux,uz=-math.sin(a)*.8,math.cos(a)*.8
   G.face(root,{mid[1]+ux,mid[2]-.25,mid[3]+uz},mid,mid,'forestLeaf',.92)
   G.face(root,mid,{mid[1]-ux,mid[2]-.25,mid[3]-uz},{mid[1]-ux,mid[2]-.25,mid[3]-uz},'forestLeaf',.85)
   G.face({mid[1]+ux,mid[2]-.25,mid[3]+uz},tip,mid,mid,'forestLeaf',1.02)
   G.face(mid,tip,{mid[1]-ux,mid[2]-.25,mid[3]-uz},{mid[1]-ux,mid[2]-.25,mid[3]-uz},'forestLeaf',.9)
  end
 end
 -- Connected buttresses meet the ground instead of hovering over it.
 for j=0,3 do local a=j*pi/2+variant*.4;local r=big and 5.8 or tall and 3.8 or 2.2
  limb(G,{math.cos(a)*r,.14,math.sin(a)*r},{0,stem*2.1,0},stem*.22,stem*.5,j)
 end
 local seen={};local maxRadius=big and 18 or tall and 11.2 or 7.65
 for _,q in ipairs(G.out)do for i=1,4 do local p=q[i]
  if not seen[p]then seen[p]=true
   -- Lower parts stay inside the exact source shrub cell. High crowns may
   -- overhang only above head clearance; all branches remain connected.
   local allowed=big and maxRadius or tall and(p[2]<=18 and 7.65 or 7.65+math.min(1,(p[2]-18)/3)*(maxRadius-7.65))or maxRadius
   local r=math.sqrt(p[1]^2+p[3]^2);if r>allowed then p[1],p[3]=p[1]*allowed/r,p[3]*allowed/r end
   p[2]=math.max(.03,p[2])
  end
 end end
 local out={quads=G.out,centers=centers};cache[id]=out;return out
end
function M.plant(S,kind,variant,x,z)
 local a=variant*.83;local tpl=M.template(kind,variant)
 S.roundStamps[#S.roundStamps+1]={quads=tpl.quads,mx=x,mz=z,r=8,forestTree=true,safariTree=true,treeCos=math.cos(a),treeSin=math.sin(a),lift=0}
 S.safariPlanting[#S.safariPlanting+1]={kind=kind,x=x,z=z,variant=variant}
end
function M.shrubKind(map,p,W,H)
 if not eventClear(map,p.x,p.z,40)then return 'hedge'end
 local edge=p.x<25 or p.z<25 or p.x>W*8-25 or p.z>H*8-25
 -- Slowly varying groups plus a small coordinate hash replace ABAB hedgerows.
 local field=math.sin(p.x*.043+p.z*.027)+math.cos(p.z*.061-p.x*.014)
 local noise=hash(p.tx,p.tz,1121)
 if edge and noise>.22 or not edge and field>.10 and noise>.24 then return 'tree'end
 if noise>.16 then return 'thicket'end
 return 'hedge'
end
-- Filled earth shoulders occupy only source-blocked rim tiles. Heights ramp
-- toward adjacent raised ground, so scattered stones become a connected bank.
function M.bankHeight(S,map,wx,wz)
  local high,plain=0,24
  -- Measure distance to actual walking rectangles, not to tile centers.
  -- This field is identical at shared vertices even when claims are built
  -- in a different order, removing the old row of little conical mounds.
  for tz=math.floor(wz/8)-2,math.floor(wz/8)+2 do for tx=math.floor(wx/8)-2,math.floor(wx/8)+2 do
   local k=key(tx,tz);local near=S.shapeAt[k]
   if near and(map:isWalkableCell(math.floor(tx/2),math.floor(tz/2))or near.class=='water')then
    local dx=math.max(tx*8-wx,0,wx-(tx+1)*8);local dz=math.max(tz*8-wz,0,wz-(tz+1)*8)
    local distance=math.sqrt(dx*dx+dz*dz);local h=near.h or 0
    if h>0 then high=math.max(high,h*math.max(0,1-distance/15))else plain=math.min(plain,distance)end
   end
  end end
  local natural=.45+(math.sin(wx*.073+wz*.039)+math.cos(wz*.087-wx*.032)+2)*.24
  if plain<.05 and high<5.8 then return .035 end
  return math.max(.035,math.max(high,natural*math.min(1,.18+plain*.46)))
end
-- Interpolate the actual eight-triangle bank mesh for rooted surface details.
function M.bankSurface(S,map,wx,wz)
 local x,z=math.floor(wx/8)*8,math.floor(wz/8)*8
 local u,v=wx-x,wz-z;local c=M.bankHeight(S,map,x+4,z+4)
 local ring={{0,0},{4,0},{8,0},{8,4},{8,8},{4,8},{0,8},{0,4}}
 for i,a in ipairs(ring)do local b=ring[i%8+1]
  local den=(b[2]-4)*(a[1]-4)+(4-b[1])*(a[2]-4)
  local aa=((b[2]-4)*(u-4)+(4-b[1])*(v-4))/den
  local bb=((4-a[2])*(u-4)+(a[1]-4)*(v-4))/den
  if aa>=-1e-8 and bb>=-1e-8 and aa+bb<=1+1e-8 then
   return aa*M.bankHeight(S,map,x+a[1],z+a[2])+bb*M.bankHeight(S,map,x+b[1],z+b[2])+(1-aa-bb)*c
  end
 end
 return c
end
function M.bank(G,S,map,x,z)
 local x0,z0=x*8,z*8;local ring={};local maxh=0
 local function groundHeight(wx,wz)return M.bankHeight(S,map,wx,wz)end
 for _,p in ipairs({{0,0},{4,0},{8,0},{8,4},{8,8},{4,8},{0,8},{0,4}})do
  local h=groundHeight(x0+p[1],z0+p[2]);ring[#ring+1]={x0+p[1],h,z0+p[2]};maxh=math.max(maxh,h)
 end
 local c={x0+4,groundHeight(x0+4,z0+4),z0+4}
 for i=1,8 do local k=i%8+1
  G.face({ring[i][1],0,ring[i][3]},{ring[k][1],0,ring[k][3]},ring[k],ring[i],'forestFloor',.88)
  G.face(ring[i],ring[k],c,c,'forestFloor',.96)
 end
 -- Small rooted blades on occasional shoulders, never a repeated rock fence.
 if hash(x,z,127)>.56 then
  for j=0,3 do local a=j*2.399;local bx,bz=c[1]+math.cos(a)*.5,c[3]+math.sin(a)*.5
   G.face({bx-.18,c[2]-.06,bz},{bx+.18,c[2]-.06,bz},{bx+math.cos(a)*.6,c[2]+1.8+(j%2),bz+math.sin(a)*.6},{bx+math.cos(a)*.6,c[2]+1.8+(j%2),bz+math.sin(a)*.6},'forestLeaf',.9)
  end
 end
 S.safariBanks[#S.safariBanks+1]={x=x,z=z,h=c[2],maxh=maxh}
end
-- Inset facets preserve the entire walking cap and never bulge into a route.
function M.riser(d,x,z,y0,y1,axisPoint,emit,uv,shade)
 local axis=(d==5 or d==6)and 1 or 3;local a=axis==1 and x or z
 local function p(t,h,inset)return axisPoint(d,x,z,a+t,h,-inset)end
 local rows={}
 for j=0,2 do rows[j+1]={};local y=y0+(y1-y0)*j/2
  for i=0,2 do local inset=j==1 and i==1 and(.10+hash(x,z,1137)*.12)or 0
   rows[j+1][i+1]=p(i*4,y,inset)
  end
 end
 for j=1,2 do for i=1,2 do local q={rows[j][i],rows[j][i+1],rows[j+1][i+1],rows[j+1][i]}
  if d==6 or d==1 then q={q[4],q[3],q[2],q[1]}end
  local tone={};for k=1,4 do tone[k]=(type(shade)=='table'and shade[k]or shade)*(.98+.012*((i+j)%3))end
  emit(q,V.require('SafariMaterials').sideUV(uv[1],uv[2],uv[3],uv[4],q,axis,a,y0),tone)
 end end
end
-- A shallow planted apron hides hard map cutoffs. Only blocked outer source
-- cells can anchor it; warp corridors and connected map sides are excluded.
function M.perimeter(S,map,W,H)
 local G=kit();local seen={};local legal={}
 for _,t in ipairs({2,3,18,19,4,5,6,7,35,21,22,23,36,37,38,39,0,53,54,84,85,86,87})do legal[t]=true end
 local function connected(side)
  local cs=map.def.connections or{}
  -- Unknown host connection layouts are conservatively left completely open.
  if next(cs)then return true end
  if cs[side]then return true end
  for _,c in pairs(cs)do if type(c)=='table'and(c.direction==side or c.dir==side)then return true end end
  return false
 end
 local function segment(cx,cz,nx,nz,side)
  if connected(side)then return end
  local tile=map:tileAt(cx*2,cz*2);local x,z=cx*16+8,cz*16+8
  if map:isWalkableCell(cx,cz)or not legal[tile]or not eventClear(map,x,z,80)then return end
  local bx,bz=x+nx*8,z+nz*8;local ux,uz=-nz,nx
  local function vertex(t,r)
   local xx,zz=bx+ux*t+nx*r,bz+uz*t+nz*r
   local rise=(math.sin(xx*.061+zz*.035)+math.cos(zz*.043-xx*.029)+2)*1.05+2
   local y=r==0 and 0 or r==12 and rise or r==30 and rise*.55 or -1.05
   return{xx,y,zz}
  end
  for _,range in ipairs({{0,12},{12,30},{30,46}})do
   for j=0,1 do local a=-8+j*8;G.face(vertex(a,range[1]),vertex(a+8,range[1]),vertex(a+8,range[2]),vertex(a,range[2]),'forestFloor',.92)end
  end
  S.safariAprons[#S.safariAprons+1]={x=x,z=z,nx=nx,nz=nz}
  local id=cx..':'..cz
  if not seen[id]and hash(cx,cz,1171)>.44 then
   seen[id]=true;local variant=(cx*7+cz*3)%4;local distance=23+hash(cx,cz,1173)*8;local jitter=(hash(cx,cz,1177)-.5)*2.6
   local centerX,centerZ=bx+nx*distance+ux*jitter,bz+nz*distance+uz*jitter
   local angle=variant*.91;local co,si=math.cos(angle),math.sin(angle)
   local rise=(math.sin(centerX*.061+centerZ*.035)+math.cos(centerZ*.043-centerX*.029)+2)*1.05+2
   local base=(distance<=30 and rise*(1-(distance-12)/18*.45)or rise*.55*(1-(distance-30)/16))-.10
   local heightScale=.86+hash(cx,cz,1181)*.32
   for _,q in ipairs(M.template('grove',variant).quads)do local p={}
    for i=1,4 do local v=q[i];p[i]={centerX+v[1]*co-v[3]*si,base+v[2]*heightScale,centerZ+v[1]*si+v[3]*co}end
    G.out[#G.out+1]={p[1],p[2],p[3],p[4],uv=q.uv,shade=q.shade,referenceMaterial=q.referenceMaterial,own=true}
   end
   S.safariGroves[#S.safariGroves+1]={x=centerX,z=centerZ,ownerX=x,ownerZ=z,variant=variant,base=base}
  end
 end
 for x=0,W/2-1 do segment(x,0,0,-1,'north');segment(x,H/2-1,0,1,'south')end
 for z=1,H/2-2 do segment(0,z,-1,0,'west');segment(W/2-1,z,1,0,'east')end
 append(S,G.out)
end
-- Multi-directional folded blades replace the parallel extruded pixel slabs
-- only inside actual Safari encounter cells. Native scalar shade bypasses ROM
-- alpha cutouts, while the existing post-character grass pass stays intact.
-- Native Safari blades stand in the world; a billboard's camera pull can
-- drag nearby roots through the near plane. Other maps retain their bias.
function M.grassPull(map,pull)
 return V.require('SafariReserve').enabled(map) and 0 or pull
end
function M.grass(S,map,x0,x1,z0,z1)
 local templates={};local materials=V.require('ReferenceMaterials')
 for z=z0,z1 do for x=x0,x1 do local s=S.shapeAt[key(x,z)]
  if s and s.art=='grass'and map:isGrassCell(math.floor(x/2),math.floor(z/2))then
   local v=math.floor(hash(x,z,1191)*8);local qs=templates[v]
   if not qs then local G=kit()
    for j=0,10 do local a=j*2.399+v*.71;local r=1.0+hash(j,v,1193)*1.6
     local bx,bz=4+math.cos(a)*r,4+math.sin(a)*r
     local h=4.5+hash(j,v,1197)*4;local w=.58+hash(j,v,1201)*.27
     local ux,uz=-math.sin(a),math.cos(a);local last
     for k=0,3 do local t=k/3;local width=w*(1-t)^.65;local lean=t*t*.72
      local c={bx+math.cos(a)*lean,.075+h*t,bz+math.sin(a)*lean}
      -- A radial ridge gives the blade real depth, at the same face budget.
      local row={{c[1]-ux*width,c[2],c[3]-uz*width},{c[1]+math.cos(a)*width*.52,c[2],c[3]+math.sin(a)*width*.52},{c[1]+ux*width,c[2],c[3]+uz*width}}
      if last then for n=1,2 do G.face(last[n],last[n+1],row[n+1],row[n],'forestLeaf',n==1 and 1.03 or .85)end end
      last=row
     end
    end
    qs=G.out;templates[v]=qs
   end
   for _,q in ipairs(qs)do local p={};for i=1,4 do p[i]={x*8+q[i][1],q[i][2],z*8+q[i][3]}end
    S.grassQuads[#S.grassQuads+1]={p[1],p[2],p[3],p[4],uv=q.uv,shade=materials.encode('forestLeaf',(q.shade[1]+q.shade[2]+q.shade[3]+q.shade[4])*.25*(.94+(v%3)*.03))}
   end
  end
 end end
end
return M
