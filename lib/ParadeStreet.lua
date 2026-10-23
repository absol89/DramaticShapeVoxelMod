-- TEST226: THE PARADE ROUTE, DRESSED. Solo Dolo asked for one bigger, more
-- detailed parade in a big city instead of four small ones. Celadon's main
-- street, from the Route 7 gate to the plaza at the Department Store, is
-- made up for the day:
--
--   * a crowd two deep along both pavements and filling the plaza: low-poly
--     townsfolk (shirts in every colour, a lot of them in the Champion's red
--     and gold; caps and sun hats; children at the front, a few up on a
--     parent's shoulders) waving flags and holding up placards ("GO!", "#1",
--     a heart, "WOW"). The people nearest the float cheer hardest -- arms up,
--     jumping -- so a wave of cheering follows you down the street; the
--     rest wave and clap on their own beat. The town's own people (and the
--     ones the parade brings) stand in front of them at the rope.
--   * red velvet ropes on gold posts along both kerbs
--   * tall gold poles carrying strings of rainbow pennants along the kerbs
--     and across the street ("Celadon City: the City of Rainbow Dreams")
--   * bunches of balloons tied along the ropes; at the finale the plaza lets
--     go of its own balloons, and they rise away over the rooftops
--   * two banners across the street, and two long banners on the
--     Department Store
--   * two confetti cannons on tripods in the plaza (for the finale)
--   * cameras flashing in the crowd
--
-- Cost: the crowd is a few static meshes in groups (each group one draw, two
-- poses: arms down and arms up; the group's pose and bounce change, never its
-- vertices), the ropes, poles and pennants one mesh, the balloons three; all
-- built under the white card, a group a frame, never while the camera rolls.
-- In LITE (ChampionParade drops to it if the frame rate does) only half the
-- crowd's groups are drawn.
--
-- Everything here is decoration: nothing walks, nothing collides, the town's
-- own meshes are not touched. The layout comes from ChampionParade (its
-- stop's `set`); geometry is pure Lua so it can be checked and previewed
-- without a screen.
local V=...
local S={REVISION='parade-street-226'}
local floor,max,min,abs,sin,cos,sqrt,pi=math.floor,math.max,math.min,math.abs,math.sin,math.cos,math.sqrt,math.pi
local atan2=math.atan2 or math.atan

local function now()local ok,t=pcall(love.timer.getTime);return ok and t or 0 end
local function smooth(u)u=max(0,min(1,u));return u*u*(3-2*u)end
local function log(fmt,...)
 local args={...}
 pcall(function()require('src.core.Logger').warn('[ParadeStreet] '..fmt,unpack(args))end)
end

------------------------------------------------------------------ the paint
-- One 64x32 picture: colours one texel each on the top two rows, and the
-- four placards below (32x12 each).
S.TEX_W,S.TEX_H=64,32
S.COLORS={
 skin1={.98,.82,.68},skin2={.90,.68,.52},skin3={.72,.50,.34},skin4={.46,.31,.21},
 hair1={.12,.09,.08},hair2={.30,.19,.11},hair3={.55,.36,.18},hair4={.88,.72,.38},hair5={.64,.25,.12},hair6={.66,.66,.68},
 red={.86,.13,.16},gold={.98,.76,.22},blue={.20,.40,.86},sky={.50,.74,.96},green={.24,.62,.34},lime={.64,.84,.32},
 pink={.96,.52,.72},purple={.56,.38,.82},orange={.98,.56,.18},white={.96,.96,.94},teal={.16,.62,.62},navy={.16,.20,.44},
 cream={.95,.90,.78},black={.13,.13,.15},
 denim={.22,.30,.54},dark={.16,.16,.20},khaki={.66,.58,.40},brown={.42,.29,.18},grey={.46,.46,.50},
 eye={.10,.08,.08},stick={.62,.48,.30},brass={.97,.78,.30},brassDark={.74,.54,.18},velvet={.66,.06,.13},
 string={.90,.88,.84},metal={.26,.26,.30},
 bRed={.95,.18,.18},bOrange={1,.55,.12},bYellow={1,.88,.20},bGreen={.25,.75,.30},bBlue={.20,.48,1},bPurple={.62,.32,.92},
 lRed={.95,.12,.18},lGold={1,.80,.26},lBlue={.24,.50,1},lWhite={.98,.98,.98},lPink={1,.50,.78},lGreen={.30,.82,.40},
}
S.ORDER={}
do
 local names={}
 for k in pairs(S.COLORS)do names[#names+1]=k end
 table.sort(names)
 for i,k in ipairs(names)do S.ORDER[k]=i-1 end
end
local function colUV(name)
 local i=S.ORDER[name]or 0
 return((i%64)+.5)/S.TEX_W,(floor(i/64)+.5)/S.TEX_H
end
S.colUV=colUV
-- the placards: {u0,v0,u1,v1} in the picture
S.PLACARDS={{0,4,32,16},{32,4,64,16},{0,18,32,30},{32,18,64,30}}
local function placardUV(k)
 local r=S.PLACARDS[k]
 return r[1]/S.TEX_W,r[2]/S.TEX_H,r[3]/S.TEX_W,r[4]/S.TEX_H
end

-- a 3x5 letter set, for the placards
local GLYPH={
 G={'111','100','101','101','111'},O={'111','101','101','101','111'},['!']={'010','010','010','000','010'},
 ['#']={'101','111','101','111','101'},['1']={'010','110','010','010','111'},W={'101','101','101','111','101'},
}
local HEART={'.XXX...XXX.','XXXXX.XXXXX','XXXXXXXXXXX','XXXXXXXXXXX','.XXXXXXXXX.','..XXXXXXX..','...XXXXX...','....XXX....','.....X.....'}
-- the picture's pixels, as rows of {r,g,b,a} (pure: previewable)
function S.picture()
 local W,H=S.TEX_W,S.TEX_H
 local px={}
 for y=0,H-1 do px[y]={}for x=0,W-1 do px[y][x]={0,0,0,0}end end
 for name,i in pairs(S.ORDER)do
  local c=S.COLORS[name]
  px[floor(i/64)][i%64]={c[1],c[2],c[3],1}
 end
 local function card(k,bg,border,ink,draw)
  local r=S.PLACARDS[k]
  for y=r[2],r[4]-1 do for x=r[1],r[3]-1 do
   local edge=x==r[1]or x==r[3]-1 or y==r[2]or y==r[4]-1
   local c=edge and border or bg
   px[y][x]={c[1],c[2],c[3],1}
  end end
  draw(function(x,y)if px[r[2]+y]and px[r[2]+y][r[1]+x]then px[r[2]+y][r[1]+x]={ink[1],ink[2],ink[3],1}end end)
 end
 local function text(set,str,ox,oy)
  local x=ox
  for ch in str:gmatch('.')do
   local g=GLYPH[ch]
   if g then
    for gy=1,5 do for gx=1,3 do
     if g[gy]:sub(gx,gx)=='1'then
      for a=0,1 do for b=0,1 do set(x+(gx-1)*2+a,oy+(gy-1)*2+b)end end
     end
    end end
   end
   x=x+8
  end
 end
 local C=S.COLORS
 card(1,{1,1,1},C.red,C.red,function(set)text(set,'GO!',5,1)end)
 card(2,C.red,C.gold,{1,1,1},function(set)text(set,'#1',9,1)end)
 card(3,{1,1,1},C.blue,{.94,.16,.30},function(set)
  for y,row in ipairs(HEART)do for x=1,#row do if row:sub(x,x)=='X'then set(10+x,y+1)end end end
 end)
 card(4,C.bYellow,C.blue,C.blue,function(set)text(set,'WOW',5,1)end)
 return px,W,H
end

------------------------------------------------------------------ shapes
-- quads: {a,b,c,d, colour name (or {u0,v0,u1,v1} for a placard), shade}
-- The shade a face gets from where it points (Voxel3D's own face shading,
-- blended for faces that lean: the sun is in the south-east).
local function shadeOf(nx,ny,nz)
 local l=sqrt(nx*nx+ny*ny+nz*nz);if l<1e-9 then return 1 end
 nx,ny,nz=nx/l,ny/l,nz/l
 return nx*nx*(nx>0 and .84 or .72)+ny*ny*(ny>0 and 1 or .55)+nz*nz*(nz>0 and .90 or .68)
end
S.shadeOf=shadeOf
local function sub(a,b)return a[1]-b[1],a[2]-b[2],a[3]-b[3]end
local function faceShade(a,b,c)
 local ux,uy,uz=sub(b,a)
 local vx,vy,vz=sub(c,a)
 local nx,ny,nz=uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx
 return nx,ny,nz
end

-- A frame: an origin and three axes (unit vectors, world), with a scale.
-- Points given in the frame come out in the world.
local function frame(ox,oy,oz,yaw,s)
 local c,sn=cos(yaw),sin(yaw)
 -- local x -> world (c,0,-sn); local z (forward) -> world (sn,0,c)
 return{o={ox,oy,oz},x={c,0,-sn},y={0,1,0},z={sn,0,c},s=s or 1}
end
local function at(F,lx,ly,lz)
 local s=F.s
 lx,ly,lz=lx*s,ly*s,lz*s
 return{F.o[1]+F.x[1]*lx+F.y[1]*ly+F.z[1]*lz,F.o[2]+F.x[2]*lx+F.y[2]*ly+F.z[2]*lz,F.o[3]+F.x[3]*lx+F.y[3]*ly+F.z[3]*lz}
end
-- a frame turned inside another: about its local z (sideways, `rz`) then x
-- (forward, `rx`), pivoting at local (px,py,pz)
local function turned(F,px,py,pz,rz,rx)
 local o=at(F,px,py,pz)
 local function rot(v)
  -- v in F's local axes; rotate about z by rz then about x by rx
  local x,y,z=v[1],v[2],v[3]
  local c,s=cos(rz or 0),sin(rz or 0)
  x,y=x*c-y*s,x*s+y*c
  c,s=cos(rx or 0),sin(rx or 0)
  y,z=y*c-z*s,y*s+z*c
  return{F.x[1]*x+F.y[1]*y+F.z[1]*z,F.x[2]*x+F.y[2]*y+F.z[2]*z,F.x[3]*x+F.y[3]*y+F.z[3]*z}
 end
 return{o=o,x=rot({1,0,0}),y=rot({0,1,0}),z=rot({0,0,1}),s=F.s}
end
-- a box in a frame: x0..x1, y0..y1, z0..z1 local; `skip` faces by name
-- (top, bottom, front, back, left, right)
local function box(Q,F,x0,x1,y0,y1,z0,z1,col,skip)
 skip=skip or{}
 local p={}
 for i=0,7 do
  p[i]=at(F,(i%2==0)and x0 or x1,(floor(i/2)%2==0)and y0 or y1,(floor(i/4)==0)and z0 or z1)
 end
 local function q(a,b,c,d)
  local nx,ny,nz=faceShade(a,b,c)
  Q[#Q+1]={a,b,c,d,col,shadeOf(nx,ny,nz)}
 end
 -- corners: i = xbit + 2*ybit + 4*zbit
 if not skip.right then q(p[1],p[5],p[7],p[3])end     -- +x
 if not skip.left then q(p[4],p[0],p[2],p[6])end      -- -x
 if not skip.top then q(p[2],p[3],p[7],p[6])end       -- +y
 if not skip.bottom then q(p[0],p[4],p[5],p[1])end    -- -y
 if not skip.front then q(p[5],p[4],p[6],p[7])end     -- +z
 if not skip.back then q(p[0],p[1],p[3],p[2])end      -- -z
end
S.box,S.frame,S.at,S.turned=box,frame,at,turned
-- a flat card in a frame (x0..x1, y0..y1 at z), facing +z
local function card(Q,F,x0,x1,y0,y1,z,col)
 local a,b,c,d=at(F,x0,y0,z),at(F,x1,y0,z),at(F,x1,y1,z),at(F,x0,y1,z)
 local nx,ny,nz=faceShade(a,b,c)
 Q[#Q+1]={a,b,c,d,col,shadeOf(nx,ny,nz)}
end
local function tri(Q,a,b,c,col)
 local nx,ny,nz=faceShade(a,b,c)
 Q[#Q+1]={a,b,c,c,col,shadeOf(abs(nx),abs(ny),abs(nz))}
end

------------------------------------------------------------------ the people
-- p: {x,z,gy,yaw,s,kid,skin,hair,long,shirt,pants,hat,hatCol,prop,propCol,placard,carry}
-- pose: 'down' or 'up'
-- (an arm hangs along its own -y from the shoulder: rz swings it out to the
-- side and up, rx tips it forward -- toward the street -- whichever way it
-- points)
local function arm(Q,F,side,pose,P,lift)
 local rz,rx,len=side*.12,0,5.6
 if pose=='up'then
  rz,rx,len=side*(pi-.36),.16,6.4
  if P.prop=='placard'then rz,rx,len=side*(pi-.30),.30,6.4 end
 elseif P.prop=='placard'then rz,rx=side*.10,-.75 end
 if P.prop=='flag'and side==1 then rz,rx,len=pi-.18,.12,5.4 end
 if lift then rz,rx=side*(pi-.55),.10 end
 local A=turned(F,side*2.7,12.4,0,rz,rx)
 box(Q,A,-.65,.65,-len,0,-.65,.65,P.shirt,{top=true})
 -- the hand
 box(Q,A,-.6,.6,-len-1.0,-len,-.6,.6,P.skin,{top=true})
 return A,len
end
function S.person(Q,P,pose)
 local F=frame(P.x,P.gy,P.z,P.yaw,P.s)
 -- legs and body
 box(Q,F,-1.9,1.9,0,6.4,-1.2,1.2,P.pants,{top=true,bottom=true})
 box(Q,F,-2.7,2.7,6.4,12.9,-1.65,1.65,P.shirt,{bottom=true})
 -- the head (a child's is bigger for its size), its hair, its eyes
 local H=turned(F,0,12.6,0,0,0)
 if P.kid then H.s=H.s*1.16 end
 box(Q,H,-2.55,2.55,-.2,5.4,-2.35,2.35,P.skin,{top=true,bottom=true,back=true})
 box(Q,H,-2.55,2.55,-.2,5.4,-2.36,-2.35,P.hair,{top=true,bottom=true,front=true,left=true,right=true})
 box(Q,H,-2.75,2.75,4.3,6.4,-2.55,2.45,P.hair,{bottom=true})
 if P.long then box(Q,H,-2.65,2.65,.6,4.4,-2.8,-2.3,P.hair,{top=true,front=true})end
 for _,ex in ipairs({-1.05,1.05})do card(Q,H,ex-.33,ex+.33,2.3,3.2,2.37,'eye')end
 -- a hat
 if P.hat=='cap'then
  box(Q,H,-2.85,2.85,6.1,7.3,-2.6,2.6,P.hatCol,{bottom=true})
  box(Q,H,-2.4,2.4,6.1,6.5,2.6,4.4,P.hatCol)
 elseif P.hat=='sunhat'then
  box(Q,H,-3.9,3.9,5.9,6.3,-3.9,3.9,P.hatCol)
  box(Q,H,-2.6,2.6,6.3,8.0,-2.6,2.6,P.hatCol,{bottom=true})
 end
 -- arms, and what they hold
 local flagUp=P.prop=='flag'
 local lifting=P.carry~=nil
 local AL=arm(Q,F,-1,pose,P,lifting)
 local AR,lenR=arm(Q,F,1,flagUp and'up'or pose,P,lifting)
 if P.prop=='flag'then
  -- the stick upright in the right hand, its flag waving one way then the
  -- other (the stick's frame is the body's, at the hand, so up is up)
  local tilt=pose=='up'and .32 or-.28
  local hp=at(AR,0,-lenR-.5,0)
  local St=turned(frame(hp[1],hp[2],hp[3],P.yaw,P.s),0,0,0,tilt,0)
  box(Q,St,-.22,.22,-1.0,7.6,-.22,.22,'stick',{bottom=true})
  local c1,c2=P.propCol[1],P.propCol[2]
  card(Q,St,.22,4.6,4.9,7.4,0,c1)
  card(Q,St,.22,4.6,3.6,4.9,0,c2)
 elseif P.prop=='placard'then
  local u0,v0,u1,v1=placardUV(P.placard)
  local y=pose=='up'and 21.0 or 10.2
  local z=pose=='up'and 1.6 or 3.1
  local a,b,c,d=at(F,-3.7,y-1.4,z),at(F,3.7,y-1.4,z),at(F,3.7,y+1.4,z),at(F,-3.7,y+1.4,z)
  local nx,ny,nz=faceShade(a,b,c)
  -- (u runs left to right across the front; rows run down the picture)
  Q[#Q+1]={a,b,c,d,{u0,v1,u1,v0},shadeOf(nx,ny,nz)}
  -- and its back, plain card
  local a2,b2,c2,d2=at(F,3.7,y-1.4,z-.12),at(F,-3.7,y-1.4,z-.12),at(F,-3.7,y+1.4,z-.12),at(F,3.7,y+1.4,z-.12)
  nx,ny,nz=faceShade(a2,b2,c2)
  Q[#Q+1]={a2,b2,c2,d2,'cream',shadeOf(nx,ny,nz)}
 end
end

------------------------------------------------------------------ the plan
-- A small fixed random sequence: the same street every time (and in the
-- previews), whatever the game's random state is.
local function rng(seed)
 local s=(floor(seed)%2147483646)+1
 return function()s=(s*16807)%2147483647;return s/2147483647 end
end
S.rng=rng
local SKINS={'skin1','skin1','skin2','skin2','skin3','skin4'}
local HAIRS={'hair1','hair1','hair2','hair2','hair3','hair4','hair5','hair6'}
local SHIRTS={'red','gold','red','gold','blue','sky','green','lime','pink','purple','orange','white','teal','navy','cream','red','white'}
local PANTS={'denim','denim','dark','khaki','brown','grey','navy'}
local HATS={'red','gold','white','blue','navy','cream'}
local FLAGS={{'red','gold'},{'gold','red'},{'blue','white'},{'green','gold'},{'purple','pink'}}
local function choice(r,list)return list[floor(r()*#list)%#list+1]end
local function makePerson(r,x,z,yaw,front,gy)
 local kid=r()<(front and .30 or .07)
 local P={x=x,z=z,gy=gy or 0,yaw=yaw,kid=kid,s=kid and(.66+.06*r())or(.93+.14*r()),
  skin=choice(r,SKINS),hair=choice(r,HAIRS),shirt=choice(r,SHIRTS),pants=choice(r,PANTS)}
 P.long=r()<.32
 local h=r()
 if h<.16 then P.hat='cap';P.hatCol=choice(r,HATS)elseif h<.24 then P.hat='sunhat';P.hatCol=choice(r,{'cream','white','pink','gold'})end
 local pr=r()
 if pr<.17 then P.prop='flag';P.propCol=choice(r,FLAGS)
 elseif pr<.26 then P.prop='placard';P.placard=floor(r()*4)%4+1 end
 return P
end
-- desc: {seed, strips={{x0,x1,z,yaw,back,rows,gap,spacing,band}}, areas={{x0,x1,z0,z1,look={x,z},spacing,band}},
--        avoid={{x,z,r}}} ; returns the people, each with its group key
function S.plan(desc,groundFn)
 local r=rng(desc.seed or 226)
 local people={}
 local avoid=desc.avoid or{}
 local function clear(x,z)
  for _,a in ipairs(avoid)do
   local dx,dz=x-a[1],z-a[2]
   if dx*dx+dz*dz<a[3]*a[3]then return false end
  end
  for _,b in ipairs(desc.avoidBoxes or{})do
   if x>b[1]and x<b[2]and z>b[3]and z<b[4]then return false end
  end
  return true
 end
 local function gy(x,z)
  if not groundFn then return 0 end
  local ok,h=pcall(groundFn,x,z);return ok and tonumber(h)or 0
 end
 for si,st in ipairs(desc.strips or{})do
  local band=st.band or 64
  for row=0,(st.rows or 2)-1 do
   local z0=st.z+(st.back or 1)*row*(st.gap or 6.5)
   local x=st.x0+r()*2
   local k=0
   while x<st.x1 do
    local px=x+(r()-.5)*1.6
    local pz=z0+(r()-.5)*1.2
    if clear(px,pz)then
     k=k+1
     local P=makePerson(r,px,pz,(st.yaw or 0)+(r()-.5)*.45,row==0,gy(px,pz))
     P.group=('s%d_%d_%d'):format(si,floor((px-st.x0)/band),k%2)
     people[#people+1]=P
     -- now and then a child up on a grown-up's shoulders (the back row)
     if row>0 and not P.kid and r()<.08 then
      local C=makePerson(r,px,pz,P.yaw,true,P.gy)
      C.kid=true;C.s=.66;C.prop=r()<.5 and'flag'or nil;C.propCol=C.propCol or choice(r,FLAGS)
      C.shoulders=P;P.carry=C
      C.gy=P.gy+14.6*P.s;C.z=P.z-.5*cos(P.yaw);C.x=P.x-.5*sin(P.yaw);C.group=P.group
      -- (legs either side of the neck: drawn as one with the grown-up's head)
      people[#people+1]=C
     end
    end
    x=x+(st.spacing or 7)*(.86+.28*r())
   end
  end
 end
 for ai,ar in ipairs(desc.areas or{})do
  local sp=ar.spacing or 7
  local z=ar.z0
  local rowi=0
  while z<ar.z1 do
   local x=ar.x0+(rowi%2)*sp*.5
   while x<ar.x1 do
    local px,pz=x+(r()-.5)*2.2,z+(r()-.5)*2.2
    if clear(px,pz)then
     local yaw=atan2(ar.look[1]-px,ar.look[2]-pz)+(r()-.5)*.4
     local d=sqrt((ar.look[1]-px)^2+(ar.look[2]-pz)^2)
     local P=makePerson(r,px,pz,yaw,d<(ar.near or 40),gy(px,pz))
     local band=ar.band or 48
     P.group=('a%d_%d_%d'):format(ai,floor((px-ar.x0)/band),#people%2)
     people[#people+1]=P
    end
    x=x+sp*(.9+.2*r())
   end
   z=z+sp*.92
   rowi=rowi+1
  end
 end
 return people
end

-- the ropes, poles, pennants, cannons: one static list of quads
-- set: {ropes={{x0,x1,z,step}}, poles={{x,z,h}}, strings={{a={x,y,z},b={x,y,z},sag,pennants}},
--       cannons={{x,z,yaw,pitch}}}
local PENNANTS={'bRed','bOrange','bYellow','bGreen','bBlue','bPurple'}
function S.dressing(desc,groundFn)
 local Q={}
 local function gy(x,z)
  if not groundFn then return 0 end
  local ok,h=pcall(groundFn,x,z);return ok and tonumber(h)or 0
 end
 -- velvet ropes on brass posts
 for _,rp in ipairs(desc.ropes or{})do
  local step=rp.step or 20
  local xs={}
  local x=rp.x0
  while x<=rp.x1+.01 do xs[#xs+1]=x;x=x+step end
  for i,px in ipairs(xs)do
   local g=gy(px,rp.z)
   local F=frame(px,g,rp.z,0,1)
   box(Q,F,-1.3,1.3,0,.6,-1.3,1.3,'brassDark',{bottom=true})
   box(Q,F,-.42,.42,.6,8.4,-.42,.42,'brass',{bottom=true,top=true})
   box(Q,F,-.8,.8,8.4,9.8,-.8,.8,'brass',{bottom=true})
   if i>1 then
    -- the rope from the last post, hanging in a curve
    local ax,bx=xs[i-1],px
    local n=6
    for k=0,n-1 do
     local u0,u1=k/n,(k+1)/n
     local y0=8.0-2.4*sin(u0*pi)
     local y1=8.0-2.4*sin(u1*pi)
     local x0,x1=ax+(bx-ax)*u0,ax+(bx-ax)*u1
     local w=.36
     local a,b=g+y0,g+y1
     Q[#Q+1]={{x0,a+w,rp.z+w},{x1,b+w,rp.z+w},{x1,b+w,rp.z-w},{x0,a+w,rp.z-w},'velvet',1}
     Q[#Q+1]={{x0,a-w,rp.z+w},{x1,b-w,rp.z+w},{x1,b+w,rp.z+w},{x0,a+w,rp.z+w},'velvet',.90}
     Q[#Q+1]={{x1,b-w,rp.z-w},{x0,a-w,rp.z-w},{x0,a+w,rp.z-w},{x1,b+w,rp.z-w},'velvet',.68}
    end
   end
  end
 end
 -- tall poles (for the pennants and the banners), gold with a ball on top
 for _,pl in ipairs(desc.poles or{})do
  local g=gy(pl[1],pl[2])
  local F=frame(pl[1],g,pl[2],0,1)
  local h=pl[3]or 48
  box(Q,F,-1.4,1.4,0,1.2,-1.4,1.4,'brassDark',{bottom=true})
  box(Q,F,-.55,.55,1.2,h,-.55,.55,'brass',{bottom=true,top=true})
  box(Q,F,-1.05,1.05,h,h+2.1,-1.05,1.05,'gold',{bottom=true})
 end
 -- strings of pennants
 local k=0
 for si,s in ipairs(desc.strings or{})do
  -- (heights are above the ground under each end)
  local a={s.a[1],s.a[2]+gy(s.a[1],s.a[3]),s.a[3]}
  local b={s.b[1],s.b[2]+gy(s.b[1],s.b[3]),s.b[3]}
  local dx,dy,dz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
  local len=sqrt(dx*dx+dz*dz)
  local n=max(4,floor(len/3.2))
  local sag=s.sag or 4
  local function P(u)return{a[1]+dx*u,a[2]+dy*u-sag*sin(u*pi),a[3]+dz*u}end
  -- the cord
  for i=0,n-1 do
   local p0,p1=P(i/n),P((i+1)/n)
   Q[#Q+1]={{p0[1],p0[2]+.18,p0[3]},{p1[1],p1[2]+.18,p1[3]},{p1[1],p1[2]-.18,p1[3]},{p0[1],p0[2]-.18,p0[3]},'string',.9}
  end
  -- the pennants hanging from it (both faces: they are seen from both sides)
  local hx,hz=dx/len,dz/len
  for i=1,n-1 do
   k=k+1
   local c=PENNANTS[(i+si)%#PENNANTS+1]
   local p=P(i/n)
   local w=1.25
   local A={p[1]-hx*w,p[2]-.1,p[3]-hz*w}
   local B={p[1]+hx*w,p[2]-.1,p[3]+hz*w}
   local C={p[1],p[2]-3.0,p[3]}
   Q[#Q+1]={A,B,C,C,c,.95}
  end
 end
 -- confetti cannons on tripods
 for _,cn in ipairs(desc.cannons or{})do
  local g=gy(cn.x,cn.z)
  local F=frame(cn.x,g,cn.z,cn.yaw or 0,1)
  for _,lg in ipairs({{-1.6,-1.2},{1.6,-1.2},{0,1.8}})do
   local a=at(F,lg[1],0,lg[2])
   local b=at(F,0,7.2,0)
   local w=.32
   Q[#Q+1]={{a[1]-w,a[2],a[3]},{a[1]+w,a[2],a[3]},{b[1]+w,b[2],b[3]},{b[1]-w,b[2],b[3]},'metal',.8}
   Q[#Q+1]={{a[1],a[2],a[3]-w},{a[1],a[2],a[3]+w},{b[1],b[2],b[3]+w},{b[1],b[2],b[3]-w},'metal',.7}
  end
  local Bf=turned(F,0,7.2,0,0,-(cn.pitch or .9))
  box(Q,Bf,-1.35,1.35,-1.35,1.35,-2.0,7.2,'brass')
  box(Q,Bf,-1.55,1.55,-1.55,1.55,1.2,2.4,'red',{front=true,back=true})
  box(Q,Bf,-1.55,1.55,-1.55,1.55,5.2,6.4,'red',{front=true,back=true})
  box(Q,Bf,-1.7,1.7,-1.7,1.7,6.8,7.6,'gold')
  cn.muzzle=at(Bf,0,0,7.8)
  local tip=at(Bf,0,0,9)
  cn.dir={tip[1]-cn.muzzle[1],tip[2]-cn.muzzle[2],tip[3]-cn.muzzle[3]}
 end
 return Q
end

-- balloons: bunches on the posts. Each bunch {x,z,gy,balloons={{x,y,z,col}}}
local BALLOONS={'lRed','lGold','lBlue','lWhite','lPink','lGreen'}
function S.bunches(desc,groundFn)
 local r=rng((desc.seed or 226)+77)
 local out={}
 for _,b in ipairs(desc.balloons or{})do
  local g=0
  if groundFn then local ok,h=pcall(groundFn,b[1],b[2]);g=ok and tonumber(h)or 0 end
  local n=3+floor(r()*3)
  local B={x=b[1],z=b[2],gy=g,top=g+9.4,balloons={}}
  for i=1,n do
   local a=i/n*pi*2+r()
   local rr=1.2+r()*1.3
   B.balloons[i]={b[1]+cos(a)*rr,g+23+r()*6,b[2]+sin(a)*rr,choice(r,BALLOONS),1.55+r()*.35}
  end
  out[#out+1]=B
 end
 return out
end
-- one balloon: a rounded diamond, eight faces, and its string to (sx,sy,sz)
local function balloon(Q,x,y,z,rad,col,sx,sy,sz)
 local top={x,y+rad*1.25,z}
 local bot={x,y-rad*1.15,z}
 local ring={}
 for i=0,3 do
  local a=i/4*pi*2+.4
  ring[i]={x+cos(a)*rad,y+.15*rad,z+sin(a)*rad}
 end
 for i=0,3 do
  local a,b=ring[i],ring[(i+1)%4]
  tri(Q,top,a,b,col)
  tri(Q,bot,b,a,col)
 end
 if sx then
  local w=.12
  Q[#Q+1]={{sx-w,sy,sz},{sx+w,sy,sz},{x+w,bot[2],z},{x-w,bot[2],z},'string',.9}
 end
end
S.balloon=balloon
function S.bunchQuads(Q,B)
 for _,b in ipairs(B.balloons)do
  balloon(Q,b[1],b[2],b[3],b[5],b[4],B.x,B.top,B.z)
 end
end

------------------------------------------------------------------ meshes
local tex=nil
local function picture()
 if tex==nil then
  tex=false
  pcall(function()
   local px,W,H=S.picture()
   local d=love.image.newImageData(W,H)
   for y=0,H-1 do for x=0,W-1 do local c=px[y][x];d:setPixel(x,y,c[1],c[2],c[3],c[4])end end
   local img=love.graphics.newImage(d)
   pcall(img.setFilter,img,'nearest','nearest')
   tex=img
  end)
 end
 return tex or nil
end
S.texture=picture
-- quads -> a Voxel3D mesh
local function toMesh(Q)
 if #Q==0 then return nil end
 local R=V.require('Voxel3D')
 local verts,idx={},{}
 for i,q in ipairs(Q)do
  local c=q[5]
  if type(c)=='table'then
   local u0,v0,u1,v1=c[1],c[2],c[3],c[4]
   local uv={{u0,v0},{u1,v0},{u1,v1},{u0,v1}}
   for k=1,4 do local p=q[k];verts[#verts+1]={p[1],p[2],p[3],uv[k][1],uv[k][2],q[6]}end
  else
   local u,v=colUV(c)
   for k=1,4 do local p=q[k];verts[#verts+1]={p[1],p[2],p[3],u,v,q[6]}end
  end
  R.pushQuad(idx,i-1)
 end
 return R.newMesh(verts,idx)
end
S.toMesh=toMesh

------------------------------------------------------------------ a dressed street
local Set={};Set.__index=Set
S.Set=Set
-- desc: the stop's `set` (see ChampionParade.STOPS); groundFn(x,z)
function S.new(desc,groundFn,opts)
 local self=setmetatable({desc=desc,groundFn=groundFn,groups={},order={},built=false,step=0,
  lite=false,released=false,flashes={},freed=nil,opts=opts or{}},Set)
 return self
end
-- the parts drawn into pictures: outside the scene pass (ChampionParade
-- calls this as the stop is entered)
function Set:prepare(texts)
 picture()
 self.banners={}
 for _,b in ipairs(self.desc.banners or{})do
  local text=b.text
  if texts and b.key and texts[b.key]then text=texts[b.key]end
  local cv=S.bannerCanvas(text,b)
  local g=0
  if self.groundFn then local ok,h=pcall(self.groundFn,b.x,b.z);g=ok and tonumber(h)or 0 end
  if cv then self.banners[#self.banners+1]={def=b,canvas=cv,gy=g}end
 end
end
-- built a piece a frame, under the card: the plan, then the dressing, then
-- the crowd a group at a time. Returns true while there is more to do.
function Set:buildStep()
 if self.released or self.built then return false end
 local t0=now()
 repeat
  self.step=self.step+1
  if self.step==1 then
   self.people=S.plan(self.desc,self.groundFn)
   for _,P in ipairs(self.people)do
    local g=self.groups[P.group]
    if not g then
     g={key=P.group,people={},cx=0,cz=0,n=0}
     self.groups[P.group]=g
     self.order[#self.order+1]=g
    end
    g.people[#g.people+1]=P
    P.grp=g
    g.cx,g.cz,g.n=g.cx+P.x,g.cz+P.z,g.n+1
   end
   for i,g in ipairs(self.order)do
    g.cx,g.cz=g.cx/g.n,g.cz/g.n
    g.phase=(i*.618)%1*pi*2
    g.rate=1.6+((i*.37)%1)*1.4
    g.parity=tonumber(g.key:sub(-1))or i%2
    -- its size, for the camera's cut: a ball about its middle that holds
    -- everyone in it (shoulders and placards up included)
    local gy,far=0,0
    for _,P in ipairs(g.people)do
     gy=gy+P.gy
     far=max(far,sqrt((P.x-g.cx)^2+(P.z-g.cz)^2)+6*P.s)
    end
    g.gy=gy/g.n
    g.r=sqrt(far*far+18*18)+4
   end
   self.gi=0
  elseif self.step==2 then
   local Q=S.dressing(self.desc,self.groundFn)
   self.cannonList=self.desc.cannons
   local ok,m=pcall(toMesh,Q)
   self.dressingMesh=ok and m or nil
   if not ok then log('the street dressing would not build: %s',tostring(m))end
  elseif self.step==3 then
   self.bunchList=S.bunches(self.desc,self.groundFn)
   self.bunchMeshes={}
   for j=1,3 do
    local Q={}
    for i,B in ipairs(self.bunchList)do if i%3==j-1 then S.bunchQuads(Q,B)end end
    local ok,m=pcall(toMesh,Q)
    if ok and m then self.bunchMeshes[#self.bunchMeshes+1]={mesh=m,phase=j*2.1}end
   end
  elseif self.step==4 then
   -- the soft shadows under everyone: a mesh for each half of the crowd
   -- (LITE draws one half: its shadows go with it)
   local R=V.require('Voxel3D')
   self.shadowMeshes={}
   for parity=0,1 do
    local verts,idx={},{}
    local n=0
    for _,P in ipairs(self.people or{})do
     if not P.shoulders and P.grp and P.grp.parity==parity then
      local rx,rz=(P.kid and 2.4 or 3.2),(P.kid and 2.0 or 2.6)
      local y=P.gy+.12
      local c,s=cos(P.yaw),sin(P.yaw)
      local function v(lx,lz,u,w)return{P.x+c*lx+s*lz,y,P.z-s*lx+c*lz,u,w,1}end
      verts[#verts+1]=v(-rx,-rz,0,0);verts[#verts+1]=v(rx,-rz,1,0)
      verts[#verts+1]=v(rx,rz,1,1);verts[#verts+1]=v(-rx,rz,0,1)
      R.pushQuad(idx,n);n=n+1
     end
    end
    if n>0 then local ok,m=pcall(R.newMesh,verts,idx);self.shadowMeshes[parity]=ok and m or nil end
   end
  else
   -- the crowd, a group at a time: arms down and arms up
   self.gi=self.gi+1
   local g=self.order[self.gi]
   if not g then self.built=true;return false end
   local Qd,Qu={},{}
   for _,P in ipairs(g.people)do
    S.person(Qd,P,'down')
    S.person(Qu,P,'up')
   end
   local ok1,md=pcall(toMesh,Qd)
   local ok2,mu=pcall(toMesh,Qu)
   g.down=ok1 and md or nil
   g.up=ok2 and mu or nil
   g.quads=#Qd
  end
 until now()-t0>.004
 return true
end
function Set:busy()return not self.built and not self.released end

-- every frame: how excited each group is (the float near, the finale)
-- focus: {x,z} of the float (or the walker); boost: 0..1 everyone
-- whether a group is drawn at this LITE level (2: its half, and only near
-- the float -- by distance, so the finale's cheering does not bring the
-- whole street back)
local function shown(self,gr)
 if not self.lite then return true end
 if gr.parity==1 then return false end
 return self.lite~=2 or(gr.near or 0)>=.3
end
function Set:update(dt,t,focus,boost)
 if self.released or not self.built then return end
 self.t=t
 for _,g in ipairs(self.order)do
  local d=focus and sqrt((g.cx-focus[1])^2+(g.cz-focus[2])^2)or 999
  local near=1-smooth((d-46)/120)
  g.near=near
  local e=max(boost or 0,.12+.88*near)
  g.ex=e
  local own=sin(t*g.rate+g.phase)
  g.isUp=own>(.80-1.35*e)
  g.bob=g.isUp and((.25+1.1*e)*abs(sin(t*(6.5+g.rate)+g.phase)))or 0
 end
 -- camera flashes: a few at a time, near the float more often
 local F=self.flashes
 for i=#F,1,-1 do if t-F[i].t0>.13 then table.remove(F,i)end end
 local want=(self.lite and 3 or 7)*(.4+.6*(boost or .5))
 if #F<want and self.people and #self.people>0 and math.random()<.35 then
  local P=self.people[math.random(#self.people)]
  if not P.kid and P.grp and shown(self,P.grp)then
   F[#F+1]={x=P.x+sin(P.yaw)*2.8,y=P.gy+(P.carry and 26 or 15.5)*P.s,z=P.z+cos(P.yaw)*2.8,t0=t}
  end
 end
end

-- LITE: 1 draws half the crowd (one of each group's pair); 2 only that
-- half's groups near the float (ChampionParade steps down if it stays slow)
function Set:setLite(level)
 if level==true then level=1 end
 self.lite=(level and level~=false and level>0)and level or false
end

-- the plaza's cannons: {muzzle={x,y,z}, dir={x,y,z}}
function Set:cannons()
 local out={}
 for _,c in ipairs(self.cannonList or{})do
  if c.muzzle then out[#out+1]={muzzle=c.muzzle,dir=c.dir}end
 end
 return out
end

-- the finale: the plaza lets its balloons go. They rise from among the
-- crowd and drift off over the rooftops: one small mesh, rewritten each
-- frame (nine faces a balloon, its string the ninth).
S.FREED_FACES=9
function Set:letGo(t,area,n)
 if self.released or self.freed then return end
 area=area or self.desc.release
 if not area then return end
 local r=rng(991)
 n=n or 32
 local g=0
 if self.groundFn then
  local ok,h=pcall(self.groundFn,(area[1]+area[2])/2,(area[3]+area[4])/2);g=ok and tonumber(h)or 0
 end
 local list={}
 for i=1,n do
  local b={x=area[1]+(area[2]-area[1])*r(),z=area[3]+(area[4]-area[3])*r(),
   y0=g+14+r()*8,rise=15+r()*9,sway=1.5+r()*2,ph=r()*6.28,col=choice(r,BALLOONS),rad=1.6+r()*.4,delay=r()*1.4}
  -- its shape about its own middle, once: {x,y,z,shade} a corner, 8 faces
  local Q={}
  balloon(Q,0,0,0,b.rad,b.col)
  local shape={}
  for _,q in ipairs(Q)do for k=1,4 do shape[#shape+1]={q[k][1],q[k][2],q[k][3],q[6]}end end
  b.shape=shape
  b.u,b.v=colUV(b.col)
  list[i]=b
 end
 local mesh=nil
 pcall(function()
  local R=V.require('Voxel3D')
  local nv=n*S.FREED_FACES*4
  mesh=love.graphics.newMesh(R.FORMAT,nv,'triangles','stream')
  local idx={}
  for q=0,n*S.FREED_FACES-1 do R.pushQuad(idx,q)end
  mesh:setVertexMap(idx)
 end)
 local verts={}
 for i=1,n*S.FREED_FACES*4 do verts[i]={0,-9999,0,0,0,1}end
 self.freed={t0=t,list=list,mesh=mesh,verts=verts}
end
-- where a freed balloon is at time t (nil: not yet let go, or long gone)
local function freedAt(F,b,t)
 local a=t-F.t0-b.delay
 if a<=0 or a>=14 then return nil end
 return b.x+sin(a*1.3+b.ph)*b.sway+a*1.2,b.y0+b.rise*a,b.z+cos(a*1.1+b.ph)*b.sway*.6-a*.8,a
end
-- (pure: the quads of the freed balloons at time t, as balloon() makes
-- them; for the previews)
function S.freedQuads(F,t)
 local Q={}
 for _,b in ipairs(F.list)do
  local x,y,z,a=freedAt(F,b,t)
  if x then
   balloon(Q,x,y,z,b.rad,b.col,x+sin(a*2+b.ph)*.8,y-b.rad*1.15-6,z)
  else
   for _=1,S.FREED_FACES do Q[#Q+1]=false end
  end
 end
 return Q
end
-- each frame of the finale: every balloon's corners moved to where it is
-- (written into the same vertex tables: nothing new is made per frame)
local function freedFrame(self,t)
 local F=self.freed
 if not(F and F.mesh)then return nil end
 local v=F.verts
 local su,sv=colUV('string')
 local n=0
 for _,b in ipairs(F.list)do
  local x,y,z,a=freedAt(F,b,t)
  if x then
   for _,c in ipairs(b.shape)do
    n=n+1
    local e=v[n]
    e[1],e[2],e[3],e[4],e[5],e[6]=x+c[1],y+c[2],z+c[3],b.u,b.v,c[4]
   end
   -- the string, from the balloon's knot down to its swinging end
   local bot=y-b.rad*1.15
   local sx=x+sin(a*2+b.ph)*.8
   local w=.12
   local e
   n=n+1;e=v[n];e[1],e[2],e[3],e[4],e[5],e[6]=sx-w,bot-6,z,su,sv,.9
   n=n+1;e=v[n];e[1],e[2],e[3],e[4],e[5],e[6]=sx+w,bot-6,z,su,sv,.9
   n=n+1;e=v[n];e[1],e[2],e[3],e[4],e[5],e[6]=x+w,bot,z,su,sv,.9
   n=n+1;e=v[n];e[1],e[2],e[3],e[4],e[5],e[6]=x-w,bot,z,su,sv,.9
  else
   for _=1,S.FREED_FACES*4 do
    n=n+1
    local e=v[n]
    e[1],e[2],e[3]=0,-9999,0
   end
  end
 end
 pcall(F.mesh.setVertices,F.mesh,v)
 return F.mesh
end

------------------------------------------------------------------ banners
-- The cloth is drawn once, into a canvas, as the stop is entered. Canvases
-- and fonts are made at one pixel a pixel (dpiscale 1): on a phone the
-- screen's own density (2.75 or so) would make each canvas and each font's
-- glyph texture many times larger for nothing. A font is made at the size
-- the text needs (worked out from one probe), used and let go.
local fontBytes=nil
local function newFont(size)
 size=max(8,floor(size))
 if fontBytes==nil then
  fontBytes=false
  pcall(function()
   local bytes=V.mod:read('assets/parade/Caladea-Bold.ttf')
   if type(bytes)=='string'and #bytes>0 then fontBytes=bytes end
  end)
 end
 local f=nil
 if fontBytes then
  pcall(function()
   local fd=love.filesystem.newFileData(fontBytes,'Caladea-Bold.ttf')
   local ok,ff=pcall(love.graphics.newFont,fd,size,'normal',1)
   if not(ok and ff)then ok,ff=pcall(love.graphics.newFont,fd,size)end
   if ok then f=ff end
  end)
 end
 if not f then
  local ok,ff=pcall(love.graphics.newFont,size,'normal',1)
  if not(ok and ff)then ok,ff=pcall(love.graphics.newFont,size)end
  f=ok and ff or nil
 end
 return f
end
S.newFont=newFont
-- the size at which `text` is `width` pixels wide (at most `cap`)
local function fitSize(text,width,cap)
 local probe=newFont(64)
 if not probe then return nil end
 local w=probe:getWidth(text)
 pcall(probe.release,probe)
 if not(w and w>0)then return cap end
 return max(12,min(cap,floor(64*width/w)))
end
local function newCanvas(W,H)
 local g=love.graphics
 local ok,cv=pcall(g.newCanvas,W,H,{dpiscale=1})
 if not(ok and cv)then ok,cv=pcall(g.newCanvas,W,H)end
 return ok and cv or nil
end
-- a banner's cloth: across the street (b.w x b.h world px, wide) or hanging
-- (b.vertical: tall, a star and the letters one under another)
function S.bannerCanvas(text,b)
 local g=love.graphics
 local W,H
 if b.vertical then W,H=128,512 else W=512;H=max(64,min(192,floor(512*b.h/b.w)))end
 local cv=newCanvas(W,H)
 if not cv then return nil end
 local bg,fg=b.bg or{.62,.07,.10},b.fg or{1,.85,.42}
 local made={}
 pcall(function()
  g.push('all')
  g.setCanvas(cv)
  g.origin()
  g.clear(bg[1],bg[2],bg[3],1)
  g.setColor(fg[1],fg[2],fg[3],1)
  if b.vertical then
   g.setLineWidth(8);g.rectangle('line',10,10,W-20,H-20)
   -- a five-pointed star near the top, as ten triangles from its middle
   -- (a filled polygon must be convex; a star is not)
   local cx,cy,Ro,Ri=W/2,92,40,16
   for k=0,9 do
    local a0,a1=-pi/2+k*pi/5,-pi/2+(k+1)*pi/5
    local r0=(k%2==0)and Ro or Ri
    local r1=(k%2==0)and Ri or Ro
    pcall(g.polygon,'fill',cx,cy,cx+cos(a0)*r0,cy+sin(a0)*r0,cx+cos(a1)*r1,cy+sin(a1)*r1)
   end
   local f=newFont(46)
   if f then
    made[#made+1]=f
    if text then
     g.setFont(f)
     local y=150
     -- (closer together for a long word: the last letter clears the fringe)
     local step=min(f:getHeight()*.78,(H-44-f:getHeight()*.7-150)/max(1,#text-1))
     for ch in text:gmatch('.')do
      if ch~=' 'then g.print(ch,floor((W-f:getWidth(ch))/2),y)end
      y=y+step
     end
    end
   end
   -- a gold fringe
   for x=14,W-14,10 do g.rectangle('fill',x,H-26,5,16)end
  else
   g.setLineWidth(4);g.rectangle('line',6,6,W-12,H-12)
   g.setLineWidth(2);g.rectangle('line',14,14,W-28,H-28)
   if text then
    local size=fitSize(text,W*.86,floor(H*.52))
    local f=size and newFont(size)
    if f then
     made[#made+1]=f
     g.setFont(f)
     g.print(text,floor((W-f:getWidth(text))/2),floor((H-f:getHeight())/2))
    end
   end
  end
  g.setCanvas()
  g.pop()
 end)
 -- (the text is in the canvas now: its fonts can go)
 for _,f in ipairs(made)do pcall(f.release,f)end
 pcall(cv.setFilter,cv,'linear','linear')
 return cv
end

------------------------------------------------------------------ drawing
local IDENT,MOVE=nil,nil
-- (MOVE: one translation, its numbers set before each draw -- the shader is
-- sent a copy, so nothing new is made per group per frame)
local function moved(x,y,z)
 MOVE[4],MOVE[8],MOVE[12]=x,y,z
 return MOVE
end
-- the sides of the picture, as planes (from the frame's view-projection,
-- row-major: left, right, bottom, top, near), or nil
local function frustum(R)
 local m=R.vp
 if type(m)~='table'or not m[16]then return nil end
 local F={}
 for _,pl in ipairs({{1,0},{-1,0},{1,4},{-1,4},{1,8}})do
  local s,o=pl[1],pl[2]
  local a,b,c,d=m[13]+s*m[o+1],m[14]+s*m[o+2],m[15]+s*m[o+3],m[16]+s*m[o+4]
  local l=sqrt(a*a+b*b+c*c)
  if l>1e-9 then F[#F+1]={a/l,b/l,c/l,d/l}end
 end
 return F
end
S.frustum=frustum
-- is a group in the picture? Its ball, dropped by the world's curve as the
-- vertex shader drops it, against each side
local function inView(F,gr,k,kx,kz)
 if not F then return true end
 local x,z=gr.cx,gr.cz
 local y=(gr.gy or 0)+14
 if k>0 then local dx,dz=x-kx,z-kz;y=y-(dx*dx+dz*dz)*k end
 local r=(gr.r or 48)*1.1+4
 for i=1,#F do
  local p=F[i]
  if p[1]*x+p[2]*y+p[3]*z+p[4]< -r then return false end
 end
 return true
end
S.inView=inView
-- In the late world pass. K: LeagueRoad's effect kit.
function Set:draw(K,t)
 if self.released then return end
 local R=V.require('Voxel3D')
 local Mat4=V.require('Mat4')
 local g=love.graphics
 local img=picture()
 if not img then return end
 IDENT=IDENT or Mat4.identity()
 MOVE=MOVE or Mat4.translate(0,0,0)
 g.setColor(1,1,1,1)
 if R.seams then R.seams(false)end
 if R.glass then R.glass(false)end
 -- (whatever happens in here, the seams and the glass come back on)
 local ok,err=pcall(function()
  if self.dressingMesh then R.draw(self.dressingMesh,img,IDENT)end
  -- the crowd: the groups shown at this LITE level, in the picture
  if self.built then
   local F=frustum(R)
   local k,kx,kz=R.curveK or 0,R.curveX or 0,R.curveZ or 0
   local n=0
   for _,gr in ipairs(self.order)do
    if shown(self,gr)and inView(F,gr,k,kx,kz)then
     n=n+1
     local m=gr.isUp and gr.up or gr.down
     if m then
      if gr.bob and gr.bob>.01 then R.draw(m,img,moved(0,gr.bob,0))
      else R.draw(m,img,IDENT)end
     end
    end
   end
   self.drawnGroups=n
  end
  -- the balloons on the posts, swaying
  for _,bm in ipairs(self.bunchMeshes or{})do
   local sx=sin(t*.9+bm.phase)*.45
   local sz=cos(t*.7+bm.phase*1.3)*.35
   R.draw(bm.mesh,img,moved(sx,0,sz))
  end
  -- the balloons let go
  if self.freed then
   local m=freedFrame(self,t)
   if m then R.draw(m,img,IDENT)end
  end
  -- banners: their cloth, both faces readable
  local BB=nil;pcall(function()BB=V.require('BattleBillboard')end)
  if BB and self.banners then
   for _,b in ipairs(self.banners)do
    local d=b.def
    local yaw=d.yaw or 0
    local fx,fz=sin(yaw)*(d.gap or .35),cos(yaw)*(d.gap or .35)
    local y=d.y+(b.gy or 0)
    R.draw(BB.mesh(),b.canvas,BB.matrix(d.x+fx,y,d.z+fz,d.w,d.h,yaw))
    if not d.flat then R.draw(BB.mesh(),b.canvas,BB.matrix(d.x-fx,y,d.z-fz,d.w,d.h,yaw+pi))end
   end
  end
 end)
 if R.glass then pcall(R.glass,true)end
 if R.seams then pcall(R.seams,true)end
 g.setColor(1,1,1,1)
 if not ok then error(err,0)end
 -- soft shadows under the crowd (LITE: the half that is drawn; LITE 2:
 -- none, rather than shadows under people who are not there)
 local SH=self.shadowMeshes
 if SH and K and K.soft and self.lite~=2 then
  pcall(R.withEffect,'alpha',function()
   g.setColor(0,0,0,.34)
   if SH[0]then R.draw(SH[0],K.soft,IDENT)end
   if SH[1]and not self.lite then R.draw(SH[1],K.soft,IDENT)end
  end)
 end
 -- camera flashes
 if #self.flashes>0 and K and K.cross and K.soft then
  pcall(R.withEffect,'add',function()
   for _,f in ipairs(self.flashes)do
    local a=1-(t-f.t0)/.13
    if a>0 then
     g.setColor(.95,.97,1,.85*a)
     R.draw(K.cross,K.soft,Mat4.mul(Mat4.translate(f.x,f.y,f.z),Mat4.scale(2.6,2.6,2.6)))
    end
   end
  end)
 end
 g.setColor(1,1,1,1)
end
function Set:release()
 if self.released then return end
 self.released=true
 for _,g in ipairs(self.order)do
  if g.down then pcall(g.down.release,g.down)end
  if g.up then pcall(g.up.release,g.up)end
  g.down,g.up=nil,nil
 end
 local SH=self.shadowMeshes or{}
 -- (a numbered loop: any of these may be missing, and ipairs would stop
 -- at the first gap)
 local list={self.dressingMesh,SH[0],SH[1],self.freed and self.freed.mesh or nil}
 for i=1,4 do local m=list[i];if m then pcall(m.release,m)end end
 for _,bm in ipairs(self.bunchMeshes or{})do pcall(bm.mesh.release,bm.mesh)end
 for _,b in ipairs(self.banners or{})do pcall(b.canvas.release,b.canvas)end
 self.dressingMesh,self.shadowMeshes,self.bunchMeshes,self.freed,self.banners=nil,nil,nil,nil,nil
 self.people=nil
end

function S.dispose()
 if tex then pcall(tex.release,tex)end
 tex=nil
 fontBytes=nil
end
return S
