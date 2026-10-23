-- TEST169: THE LEAGUE'S TREES. Rebuilt flora for the forest ledges and the
-- gorge around Route 23 and the Indigo Plateau (and the garden cypresses).
--
-- What made the old trees read as fake was not the polygon count but the
-- shading: every facet one flat tone, every crown one dark green, lumps that
-- were all the same sphere. These are built the way a painter blocks a
-- tree in:
--
--  * every crown is a few CLUSTERS, each an ellipsoid with a lumpy, smooth
--    silhouette, shaded PER VERTEX (soft, rounded light, never flat facets)
--    from the sun's side, with the crown's own occlusion deepening toward
--    its underside and its heart;
--  * the species are the Roman landscape's: umbrella-topped stone pines,
--    tall flame-shaped Italian cypresses, round broadleaf (holm oak /
--    plane) and, down the valley, firs with drooping, ragged tiers;
--  * trunks taper and lean, fork into limbs that actually reach their
--    clusters, and wear plated bark (lgBark);
--  * the leaf surfaces (lgLeaf / lgNeedle, Voxel3D) carry the clusters'
--    own relief, a green chosen per tree, and stir in the wind.
--
-- Three levels of detail: FULL (the ledges you look down on), MID (the
-- valley floor), FAR (the far bank, a few hundred units off).
--
-- E is LeagueArchitecture's emitter: E.quad(a,b,c,d,mat,shade[,glow]) with
-- shade a number or one value per corner.
local V=...
local M={REVISION='league-flora-170'}
local pi,cos,sin,floor,min,max,abs,sqrt=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs,math.sqrt
local function rh(a,b,s)local v=sin(a*12.9898+b*78.233+s*37.719)*43758.5453;return v-floor(v)end
M.rh=rh

-- the sun's side (matches the scene's face shading: up, south, east)
local LX,LY,LZ=.36,.84,.41
local function light(nx,ny,nz)
 local l=sqrt(nx*nx+ny*ny+nz*nz);if l<1e-6 then return .8 end
 nx,ny,nz=nx/l,ny/l,nz/l
 return .55+.48*max(0,nx*LX+ny*LY+nz*LZ)+.12*ny
end
M.light=light

-- One leaf cluster: an ellipsoid, lumpy but continuous, shaded per vertex.
-- o.y0/o.y1: the crown's vertical extent (for the crown's own occlusion);
-- o.lump: silhouette relief; o.core: the crown's centre (inner faces darker).
local function cluster(E,mat,cx,cy,cz,rx,ry,rz,seg,rings,seed,o)
 o=o or{}
 local lump=o.lump or .17
 local y0,y1=o.y0 or cy-ry,o.y1 or cy+ry
 local kx,kz=o.kx,o.kz
 local rot=rh(seed,1,3)*pi*2
 local P,S={},{}
 for j=0,rings do
  local b=-pi/2+pi*j/rings
  local cb,sb=cos(b),sin(b)
  P[j]={};S[j]={}
  for i=0,seg-1 do
   local a=rot+i/seg*pi*2
   local dx,dy,dz=cos(a)*cb,sb,sin(a)*cb
   local k=1+lump*cb*(.55*sin(a*3+seed*1.7+b*2)+.30*sin(a*5-seed*.9+b*3.3)
    +.55*(rh(seed+i*7.1,j*3.3,17)-.5))
   if j==0 or j==rings then k=1 end
   local px,py,pz=cx+dx*rx*k,cy+dy*ry*k,cz+dz*rz*k
   P[j][i]={px,py,pz}
   local sh=light(dx/rx,dy/ry,dz/rz)
   -- the crown's own occlusion: deeper toward its underside...
   local t=max(0,min(1,(py-y0)/max(1e-3,y1-y0)))
   sh=sh*(.66+.34*t)
   -- ...and on faces turned in toward the crown's heart
   if kx then
    local ox,oz=cx-kx,cz-kz;local ol=sqrt(ox*ox+oz*oz)
    if ol>1e-3 then
     local f=(dx*ox+dz*oz)/ol
     sh=sh*(.86+.14*max(-1,min(1,f)))
    end
   end
   S[j][i]=sh*(.95+.10*(k-1)/max(lump,1e-3)*.5)
  end
 end
 for j=0,rings-1 do
  for i=0,seg-1 do
   local i2=(i+1)%seg
   E.quad(P[j][i],P[j][i2],P[j+1][i2],P[j+1][i],mat,{S[j][i],S[j][i2],S[j+1][i2],S[j+1][i]})
  end
 end
end
M.cluster=cluster

-- A tapered limb between two points, shaded round.
local function limb(E,mat,a,b,r0,r1,sides,tone)
 sides=sides or 5;tone=tone or 1
 local dx,dy,dz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
 local l=sqrt(dx*dx+dy*dy+dz*dz);if l<1e-4 then return end
 dx,dy,dz=dx/l,dy/l,dz/l
 -- a frame around the axis
 local ux,uy,uz
 if abs(dy)<.9 then ux,uy,uz=-dz,0,dx else ux,uy,uz=1,0,0 end
 local ul=sqrt(ux*ux+uy*uy+uz*uz);ux,uy,uz=ux/ul,uy/ul,uz/ul
 local vx,vy,vz=dy*uz-dz*uy,dz*ux-dx*uz,dx*uy-dy*ux
 local A,B,S={}, {}, {}
 for i=0,sides-1 do
  local t=i/sides*pi*2
  local nx,ny,nz=ux*cos(t)+vx*sin(t),uy*cos(t)+vy*sin(t),uz*cos(t)+vz*sin(t)
  A[i]={a[1]+nx*r0,a[2]+ny*r0,a[3]+nz*r0}
  B[i]={b[1]+nx*r1,b[2]+ny*r1,b[3]+nz*r1}
  S[i]=light(nx,ny*.4,nz)*tone
 end
 for i=0,sides-1 do
  local k=(i+1)%sides
  E.quad(A[i],A[k],B[k],B[i],mat,{S[i]*.82,S[k]*.82,S[k],S[i]})
 end
end
M.limb=limb

-- turn a local offset by yaw
local function turn(yaw,x,z)local c,s=cos(yaw),sin(yaw);return x*c+z*s,-x*s+z*c end

------------------------------------------------------------------ species
-- STONE PINE (Pinus pinea): the Roman umbrella pine. A tall, leaning,
-- slightly crooked trunk forks into limbs carrying a broad, flat-topped
-- canopy of clustered needles.
function M.stonePine(E,x,y,z,H,seed,yaw,lod,maxR)
 lod=lod or 1
 local R=H*(.40+.08*rh(seed,2,5))
 if maxR then R=min(R,maxR/1.25)end
 local la=(rh(seed,3,7)-.5)*H*.16
 if maxR then la=la*min(1,maxR/(H*.6))end
 local lx,lz=turn(yaw,la,la*.3)
 local fork={x+lx,y+H*.60,z+lz}
 local mid={x+lx*.35+(rh(seed,4,1)-.5)*.8,y+H*.32,z+lz*.35}
 local r0=max(.7,H*.034)
 local top=y+H
 local cyy=y+H*.86
 if lod>=3 then
  limb(E,'lgBark',{x,y-.5,z},fork,r0,r0*.6,4)
  cluster(E,'lgNeedle',fork[1],cyy,fork[3],R*.86,R*.36,R*.82,7,3,seed,{y0=cyy-R*.30,y1=top,lump=.20})
  return
 end
 limb(E,'lgBark',{x,y-.6,z},mid,r0*1.15,r0*.9,lod>=2 and 4 or 6)
 limb(E,'lgBark',mid,fork,r0*.9,r0*.66,lod>=2 and 4 or 6)
 -- limbs out to the canopy's main masses
 local n=lod>=2 and 2 or 3
 for k=1,n do
  local a=yaw+k/n*pi*2+rh(seed,k,9)*.9
  local d=R*(.40+.12*rh(seed,k,11))
  limb(E,'lgBark',fork,{fork[1]+cos(a)*d,y+H*(.79+.04*rh(seed,k,13)),fork[3]+sin(a)*d},r0*.55,r0*.26,4)
 end
 -- the umbrella: a ring of flattened needle masses round a central one,
 -- each its own lump, so the canopy's edge and top read as clouds of
 -- foliage rather than one disc
 local opt={y0=cyy-R*.30,y1=top,kx=fork[1],kz=fork[3],lump=.22}
 cluster(E,'lgNeedle',fork[1],cyy+R*.07,fork[3],R*.46,R*.33,R*.44,7,3,seed,opt)
 local m=lod>=2 and 4 or 6
 local a0=yaw+rh(seed,5,5)*pi
 for k=1,m do
  local a=a0+k/m*pi*2+(rh(seed,k,31)-.5)*.5
  local d=R*(.50+.14*rh(seed,k,33))
  local rr=R*(.36+.10*rh(seed,k,35))
  cluster(E,'lgNeedle',fork[1]+cos(a)*d,cyy+R*(-.05+.10*rh(seed,k,37)),fork[3]+sin(a)*d,
   rr,R*(.27+.06*rh(seed,k,39)),rr*.95,6,3,seed+k*7,opt)
 end
end

-- ITALIAN CYPRESS: a tall, closed flame of dense foliage on a short trunk,
-- fluted with vertical lobes and slightly twisted.
local CYP={{0,.50},{.08,.82},{.24,1.0},{.44,.93},{.62,.74},{.78,.50},{.91,.24},{1,0}}
function M.cypress(E,x,y,z,H,seed,yaw,lod)
 lod=lod or 1
 local R=H*(.105+.025*rh(seed,5,3))
 local sides=lod>=3 and 5 or(lod>=2 and 7 or 10)
 local base=y+H*.07
 limb(E,'lgBark',{x,y-.5,z},{x,base+1,z},R*.18,R*.14,4)
 local lean=(rh(seed,6,2)-.5)*.10
 local lx,lz=turn(yaw,lean,0)
 local rows={}
 local prof=CYP
 local step=lod>=3 and 2 or 1
 local tw=rh(seed,7,7)*pi*2
 local idx={}
 for i=1,#prof,step do idx[#idx+1]=i end
 if idx[#idx]~=#prof then idx[#idx+1]=#prof end
 for _,pi_ in ipairs(idx)do
  local t,rr=prof[pi_][1],prof[pi_][2]
  local row={}
  local cyh=base+(H*.93)*t
  local ox,oz=lx*(cyh-y),lz*(cyh-y)
  for i=0,sides-1 do
   local a=tw+i/sides*pi*2+t*.9
   local k=1+.13*cos(a*3+seed+t*4)
   local r=R*rr*k
   local px,pz=x+ox+cos(a)*r,z+oz+sin(a)*r
   -- the profile's slope gives the normal its tilt
   local slope=(t<.24)and .15 or .35+.4*t
   local sh=light(cos(a),slope,sin(a))*(.70+.30*min(1,t*1.6))
   row[i]={{px,cyh,pz},sh}
  end
  rows[#rows+1]=row
 end
 for j=1,#rows-1 do
  local A,B=rows[j],rows[j+1]
  for i=0,sides-1 do
   local k=(i+1)%sides
   E.quad(A[i][1],A[k][1],B[k][1],B[i][1],'lgNeedle',{A[i][2],A[k][2],B[k][2],B[i][2]})
  end
 end
 -- close the base of the flame
 local A=rows[1];local cx,cz=x,z
 for i=0,sides-1 do local k=(i+1)%sides
  E.quad(A[i][1],A[k][1],{cx,base-.3,cz},{cx,base-.3,cz},'lgNeedle',.5)
 end
end

-- BROADLEAF (holm oak / plane): a stout trunk forking into three limbs
-- under a domed crown of overlapping clusters.
function M.broadleaf(E,x,y,z,H,seed,yaw,lod,maxR)
 lod=lod or 1
 local R=H*(.34+.06*rh(seed,8,3))
 if maxR then R=min(R,maxR/1.25)end
 local r0=max(.6,H*.042)
 local la=(rh(seed,9,5)-.5)*H*.08
 local lx,lz=turn(yaw,la,0)
 local fork={x+lx,y+H*.42,z+lz}
 local top=y+H
 local cyy=y+H*.66
 if lod>=3 then
  limb(E,'lgBark',{x,y-.5,z},{fork[1],y+H*.36,fork[3]},r0,r0*.7,3)
  cluster(E,'lgLeaf',fork[1],y+H*.62,fork[3],R*1.08,R*.84,R*1.02,7,3,seed,{y0=y+H*.25,y1=top,lump=.24})
  return
 end
 limb(E,'lgBark',{x,y-.6,z},fork,r0*1.2,r0*.8,lod>=2 and 4 or 6)
 -- the crown: a top mass and two tiers of masses round it on an
 -- ellipsoidal envelope, with limbs reaching the lower ones
 local opt={y0=y+H*.30,y1=top,kx=fork[1],kz=fork[3],lump=.20}
 local cx,cz=fork[1]+(rh(seed,1,2)-.5)*R*.15,fork[3]
 cluster(E,'lgLeaf',cx,cyy+R*.42,cz,R*.50,R*.42,R*.48,6,3,seed,opt)
 local tiers=lod>=2 and{{0,4,.62,.46}}or{{.62,3,.50,.44},{-.10,4,.64,.43}}
 local a0=yaw+rh(seed,6,6)*pi
 for ti,tr in ipairs(tiers)do
  local el,m,dist,rad=tr[1],tr[2],tr[3],tr[4]
  for k=1,m do
   local a=a0+(k+ti*.5)/m*pi*2+(rh(seed,k*ti,41)-.5)*.5
   local d=R*dist*cos(el)*(.92+.16*rh(seed,k,43))
   local e={cx+cos(a)*d,cyy+R*.78*sin(el)+(rh(seed,k,45)-.5)*R*.12,cz+sin(a)*d}
   if lod<2 and ti==2 then limb(E,'lgBark',fork,{e[1]*.7+fork[1]*.3,e[2]-R*.25,e[3]*.7+fork[3]*.3},r0*.6,r0*.3,4)end
   local rr=R*rad*(.9+.2*rh(seed,k,47))
   cluster(E,'lgLeaf',e[1],e[2],e[3],rr,rr*.82,rr*.96,5,3,seed+k*13+ti*5,opt)
  end
 end
end

-- FIR: a straight spire of drooping, ragged tiers.
function M.fir(E,x,y,z,H,seed,yaw,lod)
 lod=lod or 1
 local R=H*(.20+.04*rh(seed,10,3))
 local tiers=lod>=3 and 3 or(lod>=2 and 4 or 5)
 local pts=lod>=3 and 6 or(lod>=2 and 8 or 10)
 local y0=y+H*.12
 if lod<3 then limb(E,'lgBark',{x,y-.5,z},{x,y0+2,z},R*.12,R*.09,4)end
 local rot=rh(seed,11,1)*pi
 for t=1,tiers do
  local f=(t-1)/tiers
  local yb=y0+(H*.88)*f*.92
  local yt=yb+H*.88/tiers*1.45
  local rb=R*(1-f*.78)
  local rt=rb*.22
  local ring,top={},{}
  for i=0,pts-1 do
   local a=rot+t*.4+i/pts*pi*2
   local outer=(i%2==0)
   local r=rb*(outer and 1 or .70)*(.9+.2*rh(seed,t*17+i,5))
   local droop=outer and -.12*rb or 0
   ring[i]={x+cos(a)*r,yb+droop,z+sin(a)*r}
   top[i]={x+cos(a)*rt,yt,z+sin(a)*rt}
  end
  for i=0,pts-1 do
   local k=(i+1)%pts
   local a=rot+t*.4+(i+.5)/pts*pi*2
   local sh=light(cos(a),.62,sin(a))*(.72+.28*f)
   E.quad(ring[i],ring[k],top[k],top[i],'lgNeedle',{sh*.78,sh*.78,sh*1.06,sh*1.06})
  end
 end
 -- the leader
 local yt=y0+H*.88+H*.10
 for i=0,3 do
  local a=rot+i/4*pi*2;local b=rot+(i+1)/4*pi*2
  local r=R*.14
  E.quad({x+cos(a)*r,yt-H*.14,z+sin(a)*r},{x+cos(b)*r,yt-H*.14,z+sin(b)*r},{x,yt,z},{x,yt,z},'lgNeedle',light(cos(a),.5,sin(a)))
 end
end

------------------------------------------------------------------ understory
-- A shrub: one or two low clusters. bloom=true dresses it in flowers
-- (oleander pinks and whites, from the planted lgBloom finish).
function M.shrub(E,x,y,z,r,seed,bloom)
 local mat=bloom and 'lgBloom' or 'lgLeaf'
 local opt={y0=y,y1=y+r*1.5,lump=.22}
 cluster(E,mat,x,y+r*.55,z,r,r*.78,r*.95,6,3,seed,opt)
 if rh(seed,3,3)>.45 then
  local a=rh(seed,4,4)*pi*2
  cluster(E,mat,x+cos(a)*r*.75,y+r*.40,z+sin(a)*r*.75,r*.68,r*.56,r*.66,5,3,seed+5,opt)
 end
end

-- A tussock of long grass: arching blades fanned out from one crown.
function M.tussock(E,x,y,z,h,seed)
 local n=6
 local rot=rh(seed,1,9)*pi*2
 for i=0,n-1 do
  local a=rot+i/n*pi*2+(rh(seed,i,3)-.5)*.6
  local len=h*(.75+.5*rh(seed,i,5))
  local lean=.45+.35*rh(seed,i,7)
  local bx,bz=cos(a),sin(a)
  local w=.30+.12*rh(seed,i,11)
  local px,pz=-bz*w,bx*w
  local tip={x+bx*len*lean,y+len*(1-lean*.45),z+bz*len*lean}
  local sh=light(bx,.8,bz)
  E.quad({x+px,y,z+pz},{x-px,y,z-pz},tip,tip,'lgMeadow',{sh*.62,sh*.62,sh*1.1,sh*1.1})
 end
end

-- A fern: low fronds radiating and arching from the crown.
function M.fern(E,x,y,z,s,seed)
 local n=5
 local rot=rh(seed,2,9)*pi*2
 for i=0,n-1 do
  local a=rot+i/n*pi*2
  local bx,bz=cos(a),sin(a)
  local px,pz=-bz*s*.30,bx*s*.30
  local mid={x+bx*s*.55,y+s*.42,z+bz*s*.55}
  local tip={x+bx*s*1.05,y+s*.10,z+bz*s*1.05}
  local sh=light(bx,.9,bz)
  E.quad({x,y+.05,z},{mid[1]+px,mid[2],mid[3]+pz},mid,{mid[1]-px,mid[2],mid[3]-pz},'lgLeaf',{sh*.6,sh,sh*1.05,sh})
  E.quad({mid[1]+px,mid[2],mid[3]+pz},tip,tip,{mid[1]-px,mid[2],mid[3]-pz},'lgLeaf',{sh,sh*.9,sh*.9,sh})
 end
end

-- A mossy boulder half sunk in the meadow.
function M.stone(E,x,y,z,r,seed)
 cluster(E,'lgRock',x,y+r*.25,z,r,r*.62,r*.85,6,3,seed,{y0=y-r*.3,y1=y+r*.9,lump=.24})
end

return M
