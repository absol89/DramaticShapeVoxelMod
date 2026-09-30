-- Native connected tropical templates; shared per variant, never per map cell.
local V=...;local M={};local cache={};local pi=math.pi
local function kit()return V.require('CityMesh').new({.5/128,.5/48})end
local function ellipsoid(G,x,y,z,rx,ry,rz,seed,n,lat)
 local rings={};n=n or 10;lat=lat or 6
 for j=0,lat do local a=-pi/2+j*pi/lat;rings[j+1]={}
  for i=0,n-1 do local b=i*2*pi/n
   local r=1+.065*math.sin(i*2.7+j*1.3+seed)
   rings[j+1][i+1]={x+math.cos(a)*math.cos(b)*rx*r,y+math.sin(a)*ry,z+math.cos(a)*math.sin(b)*rz*r}
  end
 end
 for j=1,lat do for i=1,n do local k=i%n+1
  G.face(rings[j][i],rings[j][k],rings[j+1][k],rings[j+1][i],'forestCore',.91+.10*math.sin(i+seed))
 end end
end
local function frond(G,a,b,width,seed,feathered)
 local dx,dy,dz=b[1]-a[1],b[2]-a[2],b[3]-a[3];local l=math.sqrt(dx*dx+dz*dz)
 if l<.01 then return end
 local ux,uz=-dz/l,dx/l;local prev,center
 local arch=math.min(4.6,l*.22)
 for j=0,6 do
  local t=j/6;local w=math.sin(t*pi)^.72*width
  local sweep=math.sin(t*pi)*math.sin(seed*2.7)*l*.07
  local c={a[1]+dx*t+ux*sweep,a[2]+dy*t+math.sin(t*pi)*arch,a[3]+dz*t+uz*sweep}
  local curl=.22*math.sin(t*4+seed)
  local row={{c[1]+ux*w,c[2]-.32*w+curl,c[3]+uz*w},c,{c[1]-ux*w,c[2]-.42*w-curl,c[3]-uz*w}}
  if prev then
   for k=1,2 do
    G.face(prev[k],prev[k+1],row[k+1],row[k],'forestLeaf',k==1 and 1.03 or .83)
    G.out[#G.out].uv={{0,(j-1)/6},{1,(j-1)/6},{1,t},{0,t}}
   end
   -- The midrib follows the leaf's arch; no straight floating stick below it.
   G.face({center[1]-ux*.04,center[2]+.035,center[3]-uz*.04},{center[1]+ux*.04,center[2]+.035,center[3]+uz*.04},
    {c[1]+ux*.02,c[2]+.035,c[3]+uz*.02},{c[1]-ux*.02,c[2]+.035,c[3]-uz*.02},'leaf',.94)
  end
  prev,center=row,c
 end
 if feathered then
  for j=1,9 do local t=j/11
   local sweep=math.sin(t*pi)*math.sin(seed*2.7)*l*.07
   local cx,cy,cz=a[1]+dx*t+ux*sweep,a[2]+dy*t+math.sin(t*pi)*arch,a[3]+dz*t+uz*sweep
   local span=math.sin(t*pi)^.72*width
   for _,side in ipairs({-1,1})do
    local p={cx+ux*span*.7*side,cy-span*.25,cz+uz*span*.7*side}
    local q={cx+ux*span*1.4*side+dx*.065,cy-span*.56,cz+uz*span*1.4*side+dz*.065}
    local r={p[1]+dx*.053,p[2]-.09,p[3]+dz*.053}
    G.face(p,q,r,r,'forestLeaf',.87+(j%3)*.065)
   end
  end
 end
end
function M.template(kind,variant)
 local detail=V.require('CommunityVisuals').treeDetailLevel()
 local key=kind..':'..variant..':'..detail;if cache[key]then return cache[key]end
 local G=kit()
 if kind=='hedge'then
  -- Four growth habits, not four identical balls. Every root stays in the
  -- original blocked 16px cell; the full rotating envelope is bounded below.
  local tier=detail=='handheld'and 0 or detail=='full'and 2 or 1
  if variant%2==0 then
   for i=0,1 do local a=i*pi+variant*.7;local x,z=math.cos(a)*1.8,math.sin(a)*1.8
    local y=variant==2 and 3.9-i*1.3 or 3.0+i*.8
    G.beam({x*.4,.05,z*.4},{x,y+1,z},.55,'forestBark',.88)
    local coreFirst=#G.out+1
    ellipsoid(G,x,y,z,3.8,2.75,3.35,variant+i,8,4)
    -- Folded shell leaves interrupt the large support facets, including the
    -- upper crown. Their roots lie on the connected shrub volume.
    for j=0,5+tier*3 do
     local support=G.out[coreFirst+8+(j*11+i*3)%24]
     local cx=(support[1][1]+support[2][1]+support[3][1])/3
     local cy=(support[1][2]+support[2][2]+support[3][2])/3
     local cz=(support[1][3]+support[2][3]+support[3][3])/3
     local aa=math.atan2(cz-z,cx-x)
     local ux,uz=-math.sin(aa),math.cos(aa)
     local root={cx,cy,cz};local tip={cx+math.cos(aa)*.65,cy+.8,cz+math.sin(aa)*.65}
     local left={cx+ux*.52,cy+.28,cz+uz*.52};local right={cx-ux*.52,cy+.28,cz-uz*.52}
     G.face(root,left,tip,tip,'forestLeaf',1.02);G.face(root,tip,right,right,'forestLeaf',.86)
    end
    for j=0,3+tier do local aa=j*2.399+variant+i
     local radius=4.8+(j%2)*.9
     frond(G,{x,y+1.4,z},{math.cos(aa)*radius,1.6+(j%3)*.9,math.sin(aa)*radius},1.05+(j%2)*.22,j+i,false)
    end
   end
  else
   -- Bird's-nest fern and spreading cycad: layered, folded blades rise out
   -- of one connected heart, with no exposed lollipop stems.
   ellipsoid(G,0,1.2,0,2.1,1.2,2.1,variant,8,4)
   for ring=0,1 do local count=ring==0 and 7+tier or 5+tier
    for j=0,count-1 do local a=j*2*pi/count+ring*.65+variant
     local radius=ring==0 and 6.9 or 4.7
     frond(G,{0,1.6+ring,0},{math.cos(a)*radius,ring==0 and 1.25 or 4.9,math.sin(a)*radius},variant==1 and 1.65 or 1.15,j,variant==3 and tier>0)
    end
   end
  end
  for j=0,2 do local a=j*2*pi/3+variant*.4
   frond(G,{0,.6,0},{math.cos(a)*6.5,.65,math.sin(a)*6.5},.65,j,false)
  end
 elseif kind=='palm'then
  local top={math.sin(variant)*2.8,32+variant*1.3,math.cos(variant)*2.2}
  local rings={};local n=10
  for j=0,7 do local t=j/7;local radius=2.55*(1-t)+1.3*t;rings[j+1]={}
   for i=0,n-1 do local a=i*2*pi/n;rings[j+1][i+1]={top[1]*t*t+radius*math.cos(a),top[2]*t,top[3]*t*t+radius*math.sin(a)}end
  end
  for j=1,7 do for i=1,n do local k=i%n+1;G.face(rings[j][i],rings[j][k],rings[j+1][k],rings[j+1][i],'forestBark',.82+j*.023)end end
  -- Shallow growth collars follow the trunk's actual bend.
  for j=1,8 do local t=j/9;local r=2.55*(1-t)+1.3*t+.055
   for i=0,9 do local a,b=i*2*pi/10,(i+1)*2*pi/10
    local x,y,z=top[1]*t*t,top[2]*t,top[3]*t*t
    G.face({x+r*math.cos(a),y,z+r*math.sin(a)},{x+r*math.cos(b),y,z+r*math.sin(b)},{x+r*math.cos(b),y+.18,z+r*math.sin(b)},{x+r*math.cos(a),y+.18,z+r*math.sin(a)},'wood',.95)
   end
  end
  -- Overlapping tiers, broad tips and unequal droop give real tropical volume.
  -- Crowns remain high; trunks/roots keep the same source ownership.
  for ring=0,1 do local count=detail=='handheld'and 7 or 10
   for i=0,count-1 do local a=i*2*pi/count+variant*.6+ring*.31
    local r=ring==0 and 18+(i%3)*1.1 or 13+(i%2)*1.2
    frond(G,{top[1],top[2]+ring*.65,top[3]},
     {top[1]+math.cos(a)*r,top[2]+(ring==0 and -8.3+(i%4)*1.4 or .6+(i%3)*.8),top[3]+math.sin(a)*r},
     ring==0 and 3.35 or 3.0,i+ring*11,detail~='handheld')
   end
  end
  for i=0,3 do local a=i*pi/2+variant
   frond(G,top,{top[1]+math.cos(a)*5.4,top[2]+6.2,top[3]+math.sin(a)*5.4},1.35,i,false)
  end
  ellipsoid(G,top[1],top[2]-.4,top[3],2.7,2.0,2.7,variant)
  for i=0,4 do local a=i*2*pi/5
   G.beam({math.cos(a)*3.3,.1,math.sin(a)*3.3},{0,4,0},.65,'forestBark',.9)
  end
 else
  local source=V.require('ForestTrees').template(variant%4,detail)
  for _,q in ipairs(source.quads)do
   local p={};for i=1,4 do p[i]={q[i][1]*.52,q[i][2]*.72,q[i][3]*.52}end
   G.out[#G.out+1]={p[1],p[2],p[3],p[4],uv=q.uv or{{.5/128,.5/48},{.5/128,.5/48},{.5/128,.5/48},{.5/128,.5/48}},shade=q.shade,referenceMaterial=q.referenceMaterial,own=true}
  end
 end
 -- Bound all rotated shrub geometry inside its original blocked cell.
 if kind=='hedge'then local seen={};for _,q in ipairs(G.out)do for i=1,4 do local p=q[i]
  if not seen[p]then seen[p]=true;local len=math.sqrt(p[1]^2+p[3]^2);if len>7.65 then p[1]=p[1]*7.65/len;p[3]=p[3]*7.65/len end;p[2]=math.max(.03,p[2])end
 end end end
 local out={quads=G.out};cache[key]=out;return out
end
function M.stamp(kind,variant,x,z)
 local tpl=M.template(kind,variant);local a=variant*.71
 return {quads=tpl.quads,mx=x,mz=z,r=kind=='hedge'and 8 or 16,forestTree=true,treeCos=math.cos(a),treeSin=math.sin(a),lift=0,safariTree=true}
end
return M
