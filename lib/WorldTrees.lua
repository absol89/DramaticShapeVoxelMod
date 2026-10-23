-- TEST23: bounded native tree templates. Placement reuses authored geometry;
-- no per-cell crown construction, late tree job or separate texture/mesh pass.
local V=...
local Budget=V.require('BuildBudget')
local M={REVISION='world-native-trees-23'}
local cache={}
local pi=math.pi
local sizes={
 {name='S',height=25,radius=9.0,trunk=1.5},
 {name='M',height=31,radius=12.0,trunk=2.0},
 {name='L',height=39,radius=16.5,trunk=2.9},
 {name='XL',height=47,radius=22.0,trunk=4.3},
}
local function noise(n,s)local a=math.sin(n*12.9898+s*78.233)*43758.5453;return a-math.floor(a)end
local function mix(a,b,t)return {a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t}end
local function add(a,b)return {a[1]+b[1],a[2]+b[2],a[3]+b[3]}end
local function mul(a,s)return {a[1]*s,a[2]*s,a[3]*s}end
local function cross(a,b)return {a[2]*b[3]-a[3]*b[2],a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1]}end
local function unit(a)local n=math.sqrt(a[1]^2+a[2]^2+a[3]^2);return mul(a,1/math.max(n,.00001))end
function M.enabled(map,custom)
 if custom==nil then custom=V.require('CommunityVisuals').customTrees()end
 return custom and ((map.tileset or{}).id or(map.def or{}).tileset)=='OVERWORLD' or false
end
function M.detail(d)return (d=='handheld'or d=='balanced')and d or 'full'end
function M.family(cx,cy)
 -- Retain the established broad distribution and largest-tree owner cells.
 local old=(cx*73856093+cy*19349663)%5
 local size=({1,2,3,3,4})[old+1]
 return size,(cx*13+cy*19)%3
end
function M.template(size,variant,detail)
 size=math.max(1,math.min(4,size));variant=variant%3;detail=M.detail(detail)
 local key=size..':'..variant..':'..detail
 if cache[key]then return cache[key]end
 local spec=sizes[size];local H,R,T=spec.height,spec.radius,spec.trunk
 local faces,lobes={},{}
 local function face(a,b,c,d,mat,tone,uv)
  Budget.tick()
  faces[#faces+1]={a,b,c,d,referenceMaterial=mat,shade=tone or 1,
   u=.00390625,v=.00390625,uv=uv}
 end
 local function tube(points,radii,sides,vertical)
  local dir=unit(add(points[#points],mul(points[1],-1)))
  local u=vertical and {1,0,0}or unit(cross(dir,math.abs(dir[2])>.92 and {1,0,0}or{0,1,0}))
  local v=vertical and {0,0,1}or cross(dir,u)
  local rings={}
  for j,p in ipairs(points)do
   rings[j]={}
   for i=0,sides-1 do
    local a=i*2*pi/sides;local k=vertical and (1+.07*math.cos(i*3+variant))or 1
    rings[j][i+1]=add(p,add(mul(u,math.cos(a)*radii[j]*k),mul(v,math.sin(a)*radii[j]*k)))
    if p[2]<.1 then rings[j][i+1][2]=math.max(0,rings[j][i+1][2])end
   end
  end
  for j=1,#points-1 do for i=1,sides do local k=i%sides+1
   face(rings[j][i],rings[j][k],rings[j+1][k],rings[j+1][i],'worldBark',.82+.13*math.cos(i*2*pi/sides+.5))
  end end
  for i=1,sides do local k=i%sides+1
   face(points[1],rings[1][k],rings[1][i],rings[1][i],'worldBark',.73)
   local n=#points;face(points[n],rings[n][i],rings[n][k],rings[n][k],'worldBark',.82)
  end
 end
 local lean=({.45,-.7,1.1})[variant+1]*H/31
 local trunk={{0,0,0},{lean*.18,H*.20,.15},{lean,H*.43,-.25},{lean*.75,H*.64,.15},{lean*.5,H*.80,0}}
 tube(trunk,{T*1.32,T,T*.78,T*.44,T*.09},detail=='handheld'and 8 or 10,true)
 for i=0,4 do
  local a=i*2*pi/5+variant*.63
  local root={math.cos(a)*T*1.60,.06,math.sin(a)*T*1.60}
  tube({{0,T*.85,0},root},{T*.38,.10},4,false)
 end
 local function lobe(center,radii,seed,leaves)
  lobes[#lobes+1]={center=center,radius=radii}
  local points={};local rows,segments=4,8
  for j=0,rows do
   points[j]={};local lat=-pi/2+j*pi/rows
   for i=0,segments-1 do
    local a=i*2*pi/segments
    local ripple=1+.09*math.sin(a*3+seed)+.045*math.sin(a*5+lat*3)
    points[j][i+1]={center[1]+math.cos(a)*math.cos(lat)*radii[1]*ripple,
     center[2]+math.sin(lat)*radii[2]*(1+.08*math.cos(a*2+seed)*math.cos(lat)),
     center[3]+math.sin(a)*math.cos(lat)*radii[3]*ripple}
   end
  end
  for j=0,rows-1 do for i=1,segments do local k=i%segments+1
   local tone=.74+j*.055+.04*math.cos(i*2*pi/segments+seed)
   face(points[j][i],points[j][k],points[j+1][k],points[j+1][i],'worldCore',tone)
  end end
  if not leaves then return end
  local count=detail=='full'and 60 or detail=='balanced'and 44 or 26
  for i=1,count do
   -- Opaque folded sprigs seated on the actual faceted surface. Fullness comes
   -- from the connected crown; leaves supply texture and irregular edges.
   local y=1-2*(i-.5)/count;local angle=i*2.39996323+seed
   local n={math.sqrt(1-y*y)*math.cos(angle),y,math.sqrt(1-y*y)*math.sin(angle)}
   local fu=(angle%(2*pi))*segments/(2*pi);local cell=math.floor(fu);fu=fu-cell
   local fv=(math.asin(y)+pi/2)*rows/pi;local row=math.min(rows-1,math.floor(fv));fv=fv-row
   local A,B,C,D=points[row][cell+1],points[row][(cell+1)%segments+1],points[row+1][(cell+1)%segments+1],points[row+1][cell+1]
   local root=fv<=fu and add(add(mul(A,1-fu),mul(B,fu-fv)),mul(C,fv))or add(add(mul(A,1-fv),mul(C,fu)),mul(D,fv-fu))
   local around=unit(cross(n,math.abs(y)>.9 and {1,0,0}or{0,1,0}));local along=unit(cross(around,n))
   local a=noise(i,seed+5)*2*pi
   local direction=unit(add(add(mul(around,math.cos(a)),mul(along,math.sin(a))),mul(n,.28)))
   local tangent=unit(cross(direction,n))
   local length=R*(.115+.045*noise(i,seed+8));local width=length*.48
   local tip=add(root,mul(direction,length));local mid=add(root,mul(direction,length*.47))
   local ridge=add(mid,mul(n,length*.14));local left=add(mid,mul(tangent,width));local right=add(mid,mul(tangent,-width))
   local tone=.86+.14*noise(i,seed+10)+math.max(0,y)*.07
   face(root,left,tip,ridge,'worldLeaf',tone,{{.5,0},{0,.48},{.5,1},{.5,.52}})
   face(root,ridge,tip,right,'worldLeaf',tone*.88,{{.5,0},{.5,.52},{.5,1},{1,.48}})
   if detail~='handheld'then
    local start=add(root,mul(direction,length*.28))
    local d=unit(add(mul(direction,.44),mul(tangent,i%2==0 and .85 or -.85)))
    local endp=add(start,mul(d,length*.83));local middle=mix(start,endp,.5);local side=unit(cross(d,n))
    face(start,add(middle,mul(side,width*.69)),endp,add(middle,mul(side,-width*.69)),
     'worldLeaf',tone*.92,{{.5,0},{0,.48},{.5,1},{1,.48}})
   end
  end
 end
 -- Overlapping lower shoulders and two unequal leaders avoid a spherical cap,
 -- tiered pancake canopy, open trunk junction or flat skyline.
 lobe({lean*.7,H*.68,0},{R*.35,H*.155,R*.34},3+variant,false)
 for i=0,5 do
  local a=i*2*pi/6+variant*.71;local rr=R*(.57+.10*noise(i,variant+15))
  local h=H*(.65+.095*noise(i,variant+27))
  local c={math.cos(a)*rr+lean*.5,h,math.sin(a)*rr}
  local fork=mix(trunk[2],trunk[3],.65)
  local elbow=mix(fork,c,.59);elbow[2]=h-H*.11
  tube({fork,elbow,c},{T*.49,T*.25,.08},5,false)
  lobe(c,{R*(.41+.03*noise(i,variant+41)),H*(.13+.025*noise(i,variant+45)),R*.40},11+i+variant*13,true)
 end
 lobe({lean-R*.16,H*.83,R*.04},{R*.46,H*.14,R*.44},43+variant,true)
 lobe({lean+R*.22,H*.77,-R*.14},{R*.40,H*.16,R*.43},71+variant,true)
 local result={quads=faces,size=size,variant=variant,detail=detail,height=H,radius=R,lobes=lobes}
 cache[key]=result;return result
end
function M.stamp(cx,cy,base,detail)
 local size,variant=M.family(cx,cy);local tpl=M.template(size,variant,detail)
 local a=((cx*11+cy*7)%16)*2*pi/16
 return {quads=tpl.quads,mx=cx*16+8,mz=cy*16+8,r=8,lift=base or 0,
  keepTree=true,worldTree=true,treeCos=math.cos(a),treeSin=math.sin(a),treeSize=size}
end
function M.expand(q,st,sc)
 for i=1,4 do local p,s=q[i],sc[i]
  s[1]=st.mx+p[1]*st.treeCos-p[3]*st.treeSin
  s[2]=p[2]+st.lift
  s[3]=st.mz+p[1]*st.treeSin+p[3]*st.treeCos
 end
end
return M
