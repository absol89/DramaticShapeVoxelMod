-- Bounded, static planted beds. Reuses the existing atlas and terrain batch.
local V=...;local C=V.require('SurfaceCraft');local M={}
local function plant(G,x,z,y,seed,size)
 local angle=C.hash(x,z,seed)*6.28
 for j=0,5 do
  local a=angle+j*math.pi/3;local length=(1.5+C.hash(j,seed,74)*.8)*size
  local dx,dz=math.cos(a),math.sin(a);local w=.45*size
  local root={x,y,z};local mid={x+dx*length*.5,y+length*.65,z+dz*length*.5}
  local left={mid[1]-dz*w,y+length*.38,mid[3]+dx*w}
  local right={mid[1]+dz*w,y+length*.38,mid[3]-dx*w}
  local tip={x+dx*length,y+length*.32,z+dz*length}
  for _,tri in ipairs({{root,left,mid},{left,tip,mid},{tip,right,mid},{right,root,mid}})do
   G.face(tri,'canopy',.88+j*.025);G.face({tri[3],tri[2],tri[1]},'canopy',.78+j*.02)
  end
 end
 for j=0,2 do
  local a=angle+j*2.4;local px,pz=x+math.cos(a)*.6,z+math.sin(a)*.6
  local top=y+(2.2+C.hash(seed,j,7401)*1.35)*size
  G.blade(px,pz,y,top-y,.07,0,a,'leaf',.9)
  local color=seed%3==0 and 'flowerWhite' or seed%3==1 and 'flowerViolet' or 'petal'
  for k=0,4 do
   local u=k*math.pi*.4;local r=.64*size
   G.face({{px,top-.12,pz},{px+math.cos(u-.35)*r,top,pz+math.sin(u-.35)*r},{px+math.cos(u+.35)*r,top,pz+math.sin(u+.35)*r}},color,1)
  end
 end
end
function M.build(x,z,h,f,emit)
 local G=C.builder(x,z,emit);local rx,rz=f.rx,f.rz;local n=f.kind=='centerpiece' and 20 or 12
 local rim=.65;local soil=h+.78;local top=h+1.3
 for i=0,n-1 do
  local a,b=i*2*math.pi/n,(i+1)*2*math.pi/n
  local function p(t,r1,r2,y)return {f.cx+math.cos(t)*r1,y,f.cz+math.sin(t)*r2}end
  local oa,ob=p(a,rx,rz,top),p(b,rx,rz,top)
  local ia,ib=p(a,rx-rim,rz-rim,top),p(b,rx-rim,rz-rim,top)
  -- Small mortar joints divide the rim into individual coping stones.
  local joint=.012
  G.face({p(a+joint,rx,rz,top),p(b-joint,rx,rz,top),p(b-joint,rx-rim,rz-rim,top),p(a+joint,rx-rim,rz-rim,top)},'stone',1.08-(i%3)*.025)
  G.face({p(a,rx,rz,top-.035),p(b,rx,rz,top-.035),p(b,rx-rim,rz-rim,top-.035),p(a,rx-rim,rz-rim,top-.035)},'shadow',.72)
  G.face({p(a,rx,rz,h+.16),p(b,rx,rz,h+.16),ob,oa},'stone',.78)
  G.face({ia,ib,p(b,rx-rim,rz-rim,soil),p(a,rx-rim,rz-rim,soil)},'stone',.69)
  G.face({{f.cx,soil,f.cz},p(a,rx-rim,rz-rim,soil),p(b,rx-rim,rz-rim,soil)},'soil',.91+C.hash(i,rx,7402)*.14)
 end
 -- Low, irregular groundcover fills gaps without obscuring the blooms.
 for i=0,11 do
  local a=i*2.39996;local radius=math.sqrt((i+.5)/12)*.86
  local px=f.cx+math.cos(a)*(rx-1.5)*radius
  local pz=f.cz+math.sin(a)*(rz-1.5)*radius
  for j=0,2 do G.blade(px,pz,soil+.035,.55+C.hash(i,j,7601)*.7,.23,.35,a+j*2.1,'leaf',.78+j*.07)end
 end
 local count=f.kind=='centerpiece' and 18 or 9
 for i=0,count-1 do
  local a=i*2.39996;local radius=math.sqrt((i+.5)/count)*.92
  local px=f.cx+math.cos(a)*math.max(1,rx-2.5)*radius
  local pz=f.cz+math.sin(a)*math.max(.4,rz-2.5)*radius
  plant(G,px,pz,soil+.02,i+math.floor(f.cx),f.kind=='centerpiece' and 1.1 or .88)
 end
end
-- A shallow mulch saucer with roots, small stones and low flowering herbs.
-- Entire footprint fits inside the existing tree registration (radius 10.5).
function M.treeBase(x,z,h,f,emit)
 local G=C.builder(x,z,emit);local cx,cz=f.cx,f.cz;local n=16
 local y=h+.24
 for i=0,n-1 do
  local a,b=i*math.pi*2/n,(i+1)*math.pi*2/n
  local ra=5.7+C.hash(i,0,7610)*.6
  local rb=5.7+C.hash((i+1)%n,0,7610)*.6
  G.face({{cx,y,cz},{cx+math.cos(a)*ra,y,cz+math.sin(a)*ra},{cx+math.cos(b)*rb,y,cz+math.sin(b)*rb}},'soil',.78+C.hash(i,0,7611)*.14)
 end
 -- Tapered exposed root flares anchor the trunk in the soil.
 for i=0,4 do
  local a=i*math.pi*.4;local dx,dz=math.cos(a),math.sin(a)
  local tip={cx+dx*2.5,y+.04,cz+dz*2.5}
  G.face({{cx-dz*.42,y,cz+dx*.42},{cx+dx*.5,h+1.1,cz+dz*.5},tip},'wood',.76)
  G.face({tip,{cx+dx*.5,h+1.1,cz+dz*.5},{cx+dz*.42,y,cz-dx*.42}},'wood',.64)
 end
 for i=0,6 do
  local a=i*2.39996;local r=3.8+(i%2)*.55
  plant(G,cx+math.cos(a)*r,cz+math.sin(a)*r,y+.02,i+76,.65)
 end
 -- Sparse smooth pebbles, each a four-face pyramid rather than many cubes.
 for i=0,8 do
  local a=i*2.39996;local r=2.4+C.hash(i,0,7613)*2.8
  local px,pz=cx+math.cos(a)*r,cz+math.sin(a)*r
  local w=.26+C.hash(i,0,7614)*.23
  for j=0,3 do
   local u,v=j*math.pi*.5,(j+1)*math.pi*.5
   G.face({{px,y+.28,pz},{px+math.cos(u)*w,y+.02,pz+math.sin(u)*w},{px+math.cos(v)*w,y+.02,pz+math.sin(v)*w}},'stone',.86+j*.04)
  end
 end
 -- Fine grass feathers soften only parts of the mulch edge.
 for i=0,8 do
  local a=i*2.39996;local px,pz=cx+math.cos(a)*6.2,cz+math.sin(a)*6.2
  for j=0,2 do G.blade(px,pz,h+.17,.8+C.hash(i,j,7615)*.9,.12,.55,a+j*2,'leaf',.85)end
 end
end
return M
