-- TEST9: layered bounded beds and clustered water gardens, baked into terrain.
local V=...;local C=V and V.require('SurfaceCraft') or assert(loadfile('lib/SurfaceCraft.lua'))()
local M={}
-- Reusable low-cost foliage: broad bent leaves with a raised central ridge.
local function leaf(G,cx,cz,y,length,width,angle,tone)
 local dx,dz=math.cos(angle),math.sin(angle);local a={cx,y,cz}
 local b={cx+dx*length*.5-dz*width,y+length*.40,cz+dz*length*.5+dx*width}
 local c={cx+dx*length,y+length*.24,cz+dz*length}
 local d={cx+dx*length*.5+dz*width,y+length*.40,cz+dz*length*.5-dx*width}
 local m={cx+dx*length*.46,y+length*.55,cz+dz*length*.46}
 for _,p in ipairs({{a,b,m},{b,c,m},{c,d,m},{d,a,m}})do
  G.face(p,'leaf',tone);G.face({p[3],p[2],p[1]},'leaf',tone*.82)
 end
end
function M.foliage(G,cx,cz,h,seed,scale)
 scale=scale or 1
 local angle=C.hash(cx,cz,seed)*6.28
 for ring=0,1 do for j=0,3 do
  local a=angle+j*math.pi/2+ring*.72
  leaf(G,cx,cz,h+.06+ring*.28,(1.10+C.hash(seed,j,301)*.65)*scale,
    .38*scale,a,(.83+ring*.20+j*.035))
 end end
end
-- Cluster anchors live in world space. A tile only clips the resulting pads;
-- it never places its own fixed-count row of lilies.
function M.lilySites(x,z)
 local sites={};local n=C.hash;local step=23
 for gz=math.floor((z-16)/step),math.floor((z+24)/step)do
  for gx=math.floor((x-16)/step),math.floor((x+24)/step)do
   local ax=(gx+.5)*step+(n(gx,gz,311)-.5)*13
   local az=(gz+.5)*step+(n(gx,gz,312)-.5)*13
   if n(gx,gz,313)>.20 then
    local angle=n(gx,gz,314)*6.28;local ca,sa=math.cos(angle),math.sin(angle)
    local wide=5+n(gx,gz,315)*5;local narrow=3+n(gx,gz,316)*3
    for k=0,8+math.floor(n(gx,gz,317)*9)do
     local a=n(gx+k,gz,318)*6.28;local d=math.sqrt(n(gx,gz+k,319))
     local u,v=math.cos(a)*d*wide,math.sin(a)*d*narrow
     local cx,cz=ax+u*ca-v*sa,az+u*sa+v*ca
     local radius=.64+n(gx+k,gz,320)*1.13
     if cx+radius+1.1>=x and cx-radius-1.1<=x+8 and cz+radius+1.1>=z and cz-radius-1.1<=z+8 then
      sites[#sites+1]={cx,cz,radius,n(gx+k,gz,321),n(gx,gz+k,322)}
     end
    end
   end
  end
 end
 return sites
end
function M.flower(G,cx,cz,h,height,seed,fullness)
 local size=fullness or 1
 local n=C.hash;local angle=n(cx,cz,seed)*6.28
 for j=0,2 do leaf(G,cx,cz,h+.04,1.35+n(seed,j,238)*.85,.34,angle+j*2.094,.80+j*.16)end
 G.blade(cx,cz,h+.04,height,.09,.20,angle,'leaf',1)
 -- Five separated florets spiral around a tapered spike, with faceted petals.
 for tier=0,4 do
  local a=angle+tier*2.4;local y=h+height-.95+tier*.23
  local r=(.30+(4-tier)*.055)*size;local px,pz=cx+math.cos(a)*.18,cz+math.sin(a)*.18
  local top={px,y+.30,pz};local ring={}
  for j=0,4 do local b=j*math.pi*2/5+a;ring[#ring+1]={px+math.cos(b)*r,y+.07,pz+math.sin(b)*r}end
  for j=1,5 do
   local q=ring[j%5+1]
   G.face({ring[j],q,top},'petal',.77+n(seed,tier,240)*.45+tier*.06)
  end
 end
end
function M.build(kind,id,x,z,h,edges,emit)
 edges=edges or {};local G=C.builder(x,z,emit);local n=C.hash
 if kind=='terrace' then return end
 if kind=='lawn' then
  for iz=0,3 do for ix=0,3 do
   local a,b=x+ix*2,z+iz*2
   local tone=.90+.20*C.field((a+1)/27,(b+1)/27,130)+.08*C.field((a+1)/9,(b+1)/9,131)
   if id=='LAVENDER_TOWN' then tone=.76+.38*C.field((a+1)/27,(b+1)/27,130)+.18*C.field((a+1)/9,(b+1)/9,131) end
   G.flat(a,b,a+2,b+2,h+.02,'turf',tone)
  end end
  if not edges.bed and not edges.verge then return end
  local patch=C.field((x+4)/23,(z+4)/23,132)
  -- Keep quiet lawn between broad groups. No decorations on gameplay grass.
  if patch>.22 then
   local short=not edges.bed
   for k=0,(short and 6 or patch>.59 and 13 or 8)do
    local cx,cz=x+.85+n(x+k,z,133)*6.3,z+.85+n(x,z+k,134)*6.3
    for j=0,3 do G.blade(cx,cz,h+.025,(short and .25 or .7)+n(x+k,z+j,135)*(short and .40 or 1.35),short and .10 or .20,short and .20 or .62,j*1.6+n(x,z,136),'leaf',.82+n(k,z,137)*.42)end
    if not short and k<3 and patch>.47 then M.foliage(G,cx,cz,h,k,.80)end
   end
  end
  return
 end
 if kind=='bed' then
  if not edges.bed then return end
  if id=='LAVENDER_TOWN' then
   -- Irregular groups with a leafy skirt and quiet gaps between flower heads.
   -- Same safety mask; fewer sites than the old 5x5 flower lattice.
   for iz=0,3 do for ix=0,3 do
    local cx=x+1+ix*2+(n(x+ix,z+iz,341)-.5)*1.10
    local cz=z+1+iz*2+(n(x+ix,z+iz,342)-.5)*1.10
    local group=C.field(cx/11,cz/11,343)
    local depth=2.6+group*3.0
    local inside=(edges.w and cx-x<depth) or (edges.e and x+8-cx<depth)
      or (edges.n and cz-z<depth) or (edges.s and z+8-cz<depth)
    if inside and group>.30 and n(x+ix,z+iz,344)>.16 then
     local seed=ix+iz*7
     M.foliage(G,cx,cz,h,seed,1.25+group*.40)
     -- Lower, differently sized spikes emerge from leaf clumps; some stay leafy.
     if n(x+ix,z+iz,345)>.24 then
      M.flower(G,cx+.20,cz-.14,h,1.75+n(x+ix,z+iz,346)*1.45,seed,1.18+group*.18)
     end
    end
   end end
   return
  end
  -- Broad beds taper in depth along each foundation, instead of three thin
  -- straight lines. Stems share one lattice so corner beds don't double up.
  for iz=0,4 do for ix=0,4 do
   local cx=x+.8+ix*1.55+(n(x+ix,z+iz,141)-.5)*.4
   local cz=z+.8+iz*1.55+(n(x+ix,z+iz,142)-.5)*.4
   local depth=3.5+1.6*C.field(cx/13,cz/13,241)
   local inside=(edges.w and cx-x<depth) or (edges.e and x+8-cx<depth)
     or (edges.n and cz-z<depth) or (edges.s and z+8-cz<depth)
   if inside and n(x+ix,z+iz,243)>.08 then
    local r=.75+n(ix,z+iz,244)*.26
    local p={};for j=0,6 do local a=j*math.pi*2/7;p[#p+1]={cx+math.cos(a)*r,h+.012,cz+math.sin(a)*r}end
    G.face(p,'moss',.76+n(ix,iz,246)*.23)
    M.foliage(G,cx,cz,h,ix+iz*7,1.10)
    M.flower(G,cx,cz,h,2.25+n(x+ix,z+iz,242)*1.65,ix+iz*7)
   end
  end end
  return
 end
 if kind~='shore' then return end
 local near=edges.w or edges.e or edges.n or edges.s
 local function pad(cx,cz,r,level,tone)
  for j=0,9 do
   local angle=C.hash(cx,cz,323)*6.28
   local a,b=j*math.pi/5+angle,(j+1)*math.pi/5+angle
   local p,q={cx+math.cos(a)*r,h+level,cz+math.sin(a)*r},{cx+math.cos(b)*r,h+level,cz+math.sin(b)*r}
   if j~=1 then
    G.face({{cx,h+level+.065,cz},p,q},'leaf',tone+n(j,cz,155)*.20)
    G.face({{p[1],h+level-.14,p[3]},{q[1],h+level-.14,q[3]},q,p},'leaf',tone*.72)
   end
  end
 end
 for _,site in ipairs(edges.lilySites or M.lilySites(x,z))do
  local cx,cz,r=site[1],site[2],site[3]
  pad(cx,cz,r,.15+site[4]*.09,.83+site[5]*.30)
  if site[5]>.48 then
   local a=site[4]*6.28
   pad(cx+math.cos(a)*.8,cz+math.sin(a)*.8,r*.53,.14,.87)
  end
  if site[4]>.65 then
   -- Open radial petals replace the old stacked square flower.
   for tier=0,1 do for j=0,5 do
    local a=j*math.pi/3+tier*.5;local r2=(.72-tier*.20)*(.72+r*.32)
    local center={cx,h+.29+tier*.18,cz}
    local left={cx+math.cos(a-.25)*r2,h+.68+tier*.18,cz+math.sin(a-.25)*r2}
    local tip={cx+math.cos(a)*r2*1.18,h+.80+tier*.19,cz+math.sin(a)*r2*1.18}
    local right={cx+math.cos(a+.25)*r2,h+.68+tier*.18,cz+math.sin(a+.25)*r2}
    G.face({center,left,tip,right},'petal',1.03+tier*.20)
    G.face({right,tip,left,center},'petal',.91+tier*.16)
   end end
   G.box(cx-.15,cz-.15,cx+.15,cz+.15,h+.35,h+.53,'glass',1.02)
  end
 end
 -- A few dense, irregular reed fans, no picket-like row along every bank.
 for i,e in ipairs({'w','e','n','s'})do if edges[e] and n(x,z,i+160)>.60 then
  local along=2.3+n(x,z,i+251)*3.4
  for j=0,5 do
   local u=along+(n(x+j,z,252)-.5)*2.4;local inset=.7+n(x,z+j,253)*1.5
   local cx=e=='w' and x+inset or e=='e' and x+8-inset or x+u
   local cz=e=='n' and z+inset or e=='s' and z+8-inset or z+u
   local height=2.0+n(x+j,z,i+161)*2.8
   G.blade(cx,cz,h-.6,height+.6,.115,.3,j*1.9,'leaf',1.02)
   G.box(cx-.13,cz-.13,cx+.13,cz+.13,h+height-.80,h+height-.15,'shadow',.80)
   for a=0,2 do G.blade(cx,cz,h-.12,height*.70,.23,1.0,a*2.094+j,'leaf',.92+a*.10)end
  end
 end end
end
return M
