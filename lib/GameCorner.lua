-- Map-local Game Corner furnishings. Original cells still own interaction/collision.
local V=...
local M={}
local cached
local palette={{.075,.08,.10},{.14,.15,.18},{.48,.34,.16},{.77,.60,.30},
 {.27,.045,.075},{.44,.075,.105},{.87,.79,.59},{.055,.065,.08},
 {.72,.12,.10},{.18,.45,.32},{.93,.62,.24},{.42,.44,.48},
 {.105,.025,.043},{.15,.035,.053},{.20,.055,.075},{.28,.13,.10}}
local occupied={['2:10']=true,['2:13']=true,['5:11']=true,['8:11']=true,
 ['8:14']=true,['11:15']=true,['14:11']=true,['17:13']=true}
local function key(x,y)return (y+64)*4096+x+64 end
function M.layout(map)
 if V.require("CommunityVisuals").casino:get()~="n64memory" then return end
 if not(map and map.id=='GAME_CORNER' and map.tileset.id=='LOBBY')then return end
 local r={seats={},banks={},floor={},claim={},racks={},cases={},walls={},counter={},posters={}}
 local function claim(x,y)r.claim[key(x,y)]={x,y}end
 for ty=0,map.def.height*4-2,2 do for tx=0,map.def.width*4-2,2 do
  if map:tileAt(tx,ty)==7 and map:tileAt(tx+1,ty)==8
      and map:tileAt(tx,ty+1)==23 and map:tileAt(tx+1,ty+1)==24 then
   local cx,cy=math.floor(tx/2),math.floor(ty/2)
   local dx=(map:tileAt(tx-1,ty)==57 or map:tileAt(tx-1,ty)==76)and -1 or 1
   local bx=tx+dx*2
   local t=map:tileAt(bx,ty)
   if t==54 or t==75 then
    r.seats[#r.seats+1]={x=tx*8+8,z=ty*8+8,cx=cx,cy=cy,occupied=occupied[cx..':'..cy]}
    r.banks[#r.banks+1]={x=bx*8+8,z=ty*8+8,turn=dx==-1 and 1 or -1}
    for y=ty,ty+1 do for x=tx,tx+1 do claim(x,y)end end
    for y=ty,ty+1 do for x=bx,bx+1 do claim(x,y)end end
   end
  end
 end end
 if #r.banks==0 then return end
 -- Complete both halves of each matched bank, including the wall-facing side.
 local seen={}
 for _,p in ipairs(r.banks)do seen[p.x..':'..p.z]=true end
 local count=#r.banks
 for i=1,count do
  local p=r.banks[i];local tx,ty=(p.x-8)/8,(p.z-8)/8
  local other=math.floor(tx/4)*4+(tx%4==0 and 2 or 0)
  local x=other*8+8;local id=x..':'..p.z
  if not seen[id] and (map:tileAt(other,ty)==54 or map:tileAt(other,ty)==75)then
   seen[id]=true;r.banks[#r.banks+1]={x=x,z=p.z,turn=-p.turn}
   for y=ty,ty+1 do for a=other,other+1 do claim(a,y)end end
  end
 end
 -- Matched bank caps directly above the cabinets, not the cashier counter.
 for _,p in ipairs(r.banks)do
  local tx,ty=(p.x-8)/8,(p.z-8)/8
  if map:tileAt(tx,ty-2)==38 and map:tileAt(tx+1,ty-2)==41 then
   for y=ty-2,ty-1 do for x=tx,tx+1 do claim(x,y)end end
  end
 end
 -- Match complete original drawings, never broad shared tile IDs.
 local function matches(x,y,rows)
  for j,row in ipairs(rows)do for i,t in ipairs(row)do
   if map:tileAt(x+i-1,y+j-1)~=t then return false end
  end end;return true
 end
 local function add(list,x,y,w,h)
  list[#list+1]={x=x*8,z=y*8}
  for yy=y,y+h-1 do for xx=x,x+w-1 do claim(xx,yy)end end
 end
 for y=0,map.def.height*4-1 do for x=0,map.def.width*4-1 do
  if matches(x,y,{{42,43,44,45},{58,59,60,61},{64,65,66,67},{80,81,82,83}})then add(r.racks,x,y,4,4)end
  if matches(x,y,{{38,41},{34,35},{34,35},{50,51}})then add(r.cases,x,y,2,4)end
  if matches(x,y,{{72,73},{88,89}})then add(r.posters,x,y,2,2)end
  if matches(x,y,{{1},{33}})then add(r.walls,x,y,1,2)end
  if y==14 and map:tileAt(x,y)==39 and map:tileAt(x,y+1)==21 then add(r.counter,x,y,1,2)end
 end end
 -- The cashier's final corner is 41/21; only claim it beside the matched run.
 if #r.counter>0 then
  local last=r.counter[#r.counter];local x=last.x/8+1
  if matches(x,14,{{41},{21}})then add(r.counter,x,14,1,2)end
 end
 for y=0,map.def.height*4-1 do for x=0,map.def.width*4-1 do
  local t=map:tileAt(x,y)
  if t==55 or t==69 or r.claim[key(x,y)]then
   r.floor[#r.floor+1]={x=x*8,z=y*8};claim(x,y)
  end
 end end
 return r
end
function M.geometry(r,part)
 local vs,ix={},{}
 local ox,oz,turn=0,0,0
 local function point(p)
  if turn==1 then return {ox+p[3],p[2],oz-p[1]}end
  if turn==-1 then return {ox-p[3],p[2],oz+p[1]}end
  if turn==2 then return {ox-p[1],p[2],oz-p[3]}end
  return {ox+p[1],p[2],oz+p[3]}
 end
 local function quad(a,b,c,d,col,shade)
  local n=#vs
  for _,p in ipairs({a,b,c,d})do p=point(p);vs[#vs+1]={p[1],p[2],p[3],(col-.5)/16,.5,shade or 1}end
  for _,i in ipairs({1,2,3,1,3,4})do ix[#ix+1]=n+i end
 end
 local function box(x,y,z,w,h,d,col)
  local X,Y,Z=x+w,y+h,z+d
  quad({x,y,Z},{X,y,Z},{X,Y,Z},{x,Y,Z},col,.95)
  quad({X,y,z},{x,y,z},{x,Y,z},{X,Y,z},col,.76)
  quad({x,y,z},{x,y,Z},{x,Y,Z},{x,Y,z},col,.82)
  quad({X,y,Z},{X,y,z},{X,Y,z},{X,Y,Z},col,.88)
  quad({x,Y,Z},{X,Y,Z},{X,Y,z},{x,Y,z},col,1)
  quad({x,y,z},{X,y,z},{X,y,Z},{x,y,Z},col,.7)
 end
 local function cylinder(y,h,r0,r1,col,x,z)
  x,z=x or 0,z or 0
  for i=0,11 do
   local a,b=i*math.pi/6,(i+1)*math.pi/6
   local ca,sa,cb,sb=math.cos(a),math.sin(a),math.cos(b),math.sin(b)
   quad({x+r0*ca,y,z+r0*sa},{x+r1*ca,y+h,z+r1*sa},
    {x+r1*cb,y+h,z+r1*sb},{x+r0*cb,y,z+r0*sb},col,.85+.10*ca)
   quad({x,y+h,z},{x+r1*cb,y+h,z+r1*sb},{x+r1*ca,y+h,z+r1*sa},{x,y+h,z},col)
  end
 end
 -- Independent enclosure meshes let the exterior-facing camera cut away walls.
 if part then
  local function frame(x,y,z,w,h,col)
   box(x,y,z,w,.45,.4,col);box(x,y+h-.45,z,w,.45,.4,col)
   box(x,y,z,.45,h,.4,col);box(x+w-.45,y,z,.45,h,.4,col)
  end
  local function wallSpan(left,right,base)
   base=base or 0
   box(left,base,-2,right-left,72-base,2,1)
   box(left,68,.05,right-left,1.1,1.8,3)
   box(left,70,.05,right-left,.4,2.4,4)
   if base==0 then
    box(left,.3,0,right-left,1.4,.7,3)
    box(left,16,0,right-left,.65,.9,3)
    for x=left+2,right-24,32 do
     box(x,2,.06,24,12,.2,16);frame(x,2,.3,24,12,3)
     box(x,20,.06,24,43,.2,5);frame(x,20,.3,24,43,3)
     -- Geometric inset in the fabric panel.
     frame(x+3,24,.51,18,35,2)
    end
    for x=left+32,right-16,64 do
     box(x-2,36,.65,4,12,.65,2)
     box(x-1.5,38,1.4,3,7,1.5,11)
     for _,xx in ipairs({x-1.7,x+1.35})do box(xx,37.6,3,.35,7.7,.35,3)end
     box(x-2,37,1.1,4,.7,2.5,3);box(x-2,45,1.1,4,.7,2.5,3)
    end
   end
  end
  if part=='north' then ox,oz,turn=160,62,0;wallSpan(-160,160)
  elseif part=='west' then ox,oz,turn=-2,176,1;wallSpan(-112,112)
  elseif part=='east' then ox,oz,turn=322,176,-1;wallSpan(-112,112)
  elseif part=='south' then
   ox,oz,turn=160,290,2
   -- Original two-cell exit stays usable; recessed doors sit beyond the warp.
   -- Doorway at world x240..272 remains an opening.
   wallSpan(-160,-112);wallSpan(-80,160);wallSpan(-112,-80,36)
   V.require("CasinoDoors").add(box,quad,-96,false)
  elseif part=='ceiling' then
   -- Downward-facing recessed coffers, all decoration stays above headroom.
   for x=0,319,32 do for z=64,287,32 do
    box(x,73,z,32,1,32,1)
    box(x+2,72.1,z+2,28,.4,28,2)
    box(x+3,71.8,z+3,26,.3,26,3)
    box(x+3.5,71.5,z+3.5,25,.3,25,1)
   end end
   for x=0,320,32 do box(x-.35,70.8,64,.7,.6,224,3)end
   for z=64,288,32 do box(0,70.8,z-.35,320,.6,.7,3)end
  elseif part=='chandeliers' then
   local function hoop(y,radius,col)
    for i=0,23 do
     local a,b=i*math.pi/12,(i+1)*math.pi/12
     local ca,sa,cb,sb=math.cos(a),math.sin(a),math.cos(b),math.sin(b)
     quad({radius*ca,y,radius*sa},{radius*cb,y,radius*sb},
      {radius*cb,y+1,radius*sb},{radius*ca,y+1,radius*sa},col)
     quad({(radius-.7)*ca,y+1,(radius-.7)*sa},{radius*ca,y+1,radius*sa},
      {radius*cb,y+1,radius*sb},{(radius-.7)*cb,y+1,(radius-.7)*sb},col)
    end
   end
   for _,cx in ipairs({64,160,256})do
    ox,oz,turn=cx,204,0
    cylinder(70,.8,3.8,3.8,3)
    cylinder(62,8,.4,.4,3)
    cylinder(57,5,.9,.55,3)
    cylinder(55,2,2,.9,3)
    hoop(54,12,3);hoop(60,7.5,3)
    for i=0,7 do
     local a=i*math.pi/4;local ca,sa=math.cos(a),math.sin(a)
     -- Radial brass arms and warm faceted glass drops.
     local px,pz=-sa*.35,ca*.35
     local a0={px,54.25,pz};local b0={12*ca+px,54.25,12*sa+pz}
     local c0={12*ca-px,54.25,12*sa-pz};local d0={-px,54.25,-pz}
     local a1={px,54.85,pz};local b1={b0[1],54.85,b0[3]}
     local c1={c0[1],54.85,c0[3]};local d1={-px,54.85,-pz}
     quad(a1,b1,c1,d1,3);quad(d0,c0,b0,a0,3)
     quad(a0,b0,b1,a1,3);quad(c0,d0,d1,c1,3)
     cylinder(53,2,1.7,1.7,3,12*ca,12*sa)
     cylinder(49.5,3.5,.75,1.4,7,12*ca,12*sa)
     cylinder(48.5,1,0,.75,7,12*ca,12*sa)
     cylinder(55,2.2,.75,.75,11,12*ca,12*sa)
     if i%2==0 then
      quad({px,60.5,pz},{7.5*ca+px,60.5,7.5*sa+pz},
       {7.5*ca-px,60.5,7.5*sa-pz},{-px,60.5,-pz},3)
      quad({px,60,pz},{7.5*ca+px,60,7.5*sa+pz},
       {7.5*ca+px,60.5,7.5*sa+pz},{px,60.5,pz},3)
      quad({7.5*ca-px,60,7.5*sa-pz},{-px,60,-pz},
       {-px,60.5,-pz},{7.5*ca-px,60.5,7.5*sa-pz},3)
      cylinder(60,2,.8,.8,11,7.5*ca,7.5*sa)
      cylinder(57,3,.4,1.1,7,7.5*ca,7.5*sa)
     end
    end
    cylinder(51,4,0,2,7)
   end
  end
  return vs,ix
 end
 for _,p in ipairs(r.floor)do
  ox,oz,turn=p.x,p.z,0
  local tone=13+((math.floor(p.x/8)*17+math.floor(p.z/8)*7)%3==0 and 1 or 0)
  quad({0,.035,8},{8,.035,8},{8,.035,0},{0,.035,0},tone)
  -- Fine woven herringbone motifs, low contrast; not a checkerboard.
  if (p.x+p.z)%16==0 then
   quad({2,.045,4},{4,.045,6},{4.3,.045,5.7},{2.3,.045,3.7},15)
   quad({4,.045,6},{6,.045,4},{5.7,.045,3.7},{3.7,.045,5.7},15)
  end
 end
 for index,p in ipairs(r.banks)do
  ox,oz,turn=p.x,p.z,p.turn
  box(-7,0,-7,14,1.2,14,1)
  box(-6.6,1.2,-6.7,13.2,10.3,12.5,2)
  box(-6.8,1.2,5.8,13.6,.45,.35,3)
  box(-5.7,2.3,5.85,11.4,5.8,.16,1)
  box(-5.2,2.9,6.05,10.4,.5,.9,3) -- coin tray lip
  box(-5.2,3.4,5.96,10.4,1.5,.1,8)
  box(-6.4,11.5,-6.2,12.8,11.2,8.1,1)
  -- Sloped player deck, independently edged.
  quad({-6.6,10.8,6.4},{6.6,10.8,6.4},{6.6,13.2,2},{-6.6,13.2,2},2)
  box(-6.7,10.6,6.2,13.4,.45,.45,3)
  for _,x in ipairs({-6.7,6.25})do box(x,11.5,-6.1,.45,11.4,8.2,3)end
  -- Recessed reel panel, glass border and cream individual reels.
  box(-5.8,14,1.95,11.6,7.4,.3,3)
  box(-5.3,14.5,2.28,10.6,6.4,.12,8)
  for reel=0,2 do
   local x=-4.8+reel*3.3
   box(x,15.1,2.43,2.9,5.2,.08,7)
   box(x,15.1,2.53,2.9,.45,.02,12)
   box(x,19.85,2.53,2.9,.45,.02,12)
   -- Discrete 3D reel symbols: Pokeball, seven, or paired cherries.
   local symbol=(index+reel)%3
   if symbol==0 then
    for j=0,7 do
     local a,b=j*math.pi/4,(j+1)*math.pi/4
     quad({x+1.4,17.5,2.58},{x+1.4+.98*math.cos(a),17.5+.98*math.sin(a),2.58},
      {x+1.4+.98*math.cos(b),17.5+.98*math.sin(b),2.58},{x+1.4,17.5,2.58},j<4 and 9 or 7)
    end
    box(x+.43,17.35,2.62,1.94,.25,.05,1)
    box(x+1.12,17.17,2.69,.56,.6,.04,1)
    box(x+1.27,17.31,2.75,.26,.3,.02,7)
   elseif symbol==1 then
    box(x+.4,18.2,2.57,2,.4,.12,9)
    for j=0,3 do box(x+1.7-j*.3,17.7-j*.45,2.57,.55,.6,.12,9)end
   else
    box(x+.4,16.7,2.57,.85,1,.12,9);box(x+1.6,16.9,2.57,.85,1,.12,9)
    box(x+.95,17.6,2.57,.2,1,.12,10);box(x+1.85,17.8,2.57,.2,.8,.12,10)
    box(x+1.1,18.5,2.57,.9,.2,.12,10)
   end
  end
  -- Marquee, inset amber lettering bars, beveled crown.
  box(-6.9,22,-6.6,13.8,3.7,9,2)
  box(-6.4,22.4,2.43,12.8,2.5,.2,3)
  box(-5.9,22.75,2.66,11.8,1.8,.12,8)
  for j=0,6 do box(-5+j*1.5,23,2.80,.7,1.1,.05,11)end
  quad({-6.9,25.7,2.4},{6.9,25.7,2.4},{6.2,26.4,1.7},{-6.2,26.4,1.7},3)
  box(-6.2,25.7,-6,12.4,.7,7.7,1)
  -- Raised deck buttons and narrow coin slot.
  for j=0,2 do box(-4+j*2,11.3,5.2,1.25,.55,.75,j==2 and 9 or 11)end
  box(3,11.8,3.8,1.8,.6,.65,12);box(3.7,12.41,3.85,.22,.04,.5,8)
  -- Side panels and ventilation, visible from either aisle.
  for _,x in ipairs({-6.62,6.5})do
   box(x,3,-4,.12,6,7,4)
   for j=0,3 do box(x-.03,15+j*.85,-4.8,.18,.25,3.3,12)end
  end
 end
 for _,p in ipairs(r.seats)do
  ox,oz,turn=p.x,p.z+(p.occupied and 5 or 0),0
  cylinder(.05,.55,3.3,3.6,1)
  cylinder(.6,.4,3.6,2.8,12)
  cylinder(1,3.6,.65,.65,12)
  for i=0,11 do
   local a,b=i*math.pi/6,(i+1)*math.pi/6
   local ca,sa,cb,sb=math.cos(a),math.sin(a),math.cos(b),math.sin(b)
   quad({2.6*ca,2,2.6*sa},{2.6*ca,2.3,2.6*sa},{2.6*cb,2.3,2.6*sb},{2.6*cb,2,2.6*sb},3)
   quad({2.2*ca,2.3,2.2*sa},{2.2*cb,2.3,2.2*sb},{2.6*cb,2.3,2.6*sb},{2.6*ca,2.3,2.6*sa},3)
  end
  cylinder(4.6,.5,2.8,3.35,3)
  cylinder(5.1,.9,3.35,3.35,4)
  cylinder(6,.35,3.35,2.95,5)
 end
 -- Cashier cabinetry and room finishes use the same palette as the machines.
 ox,oz,turn=0,0,0
 local function panel(x,y,z,w,h)
  box(x,y,z,w,h,.5,1)
  box(x+.8,y+.8,z+.52,w-1.6,h-1.6,.2,16)
  box(x+.8,y+.8,z+.75,w-1.6,.2,.12,3)
  box(x+.8,y+h-1,z+.75,w-1.6,.2,.12,3)
  for _,xx in ipairs({x+.8,x+w-1})do box(xx,y+.8,z+.75,.2,h-1.6,.12,3)end
 end
 local font={J={'111','001','001','101','111'},A={'010','101','111','101','101'},K={'101','110','100','110','101'},P={'110','101','110','100','100'},T={'111','010','010','010','010'},C={'111','100','100','100','111'},O={'111','101','101','101','111'},
 I={'111','010','010','010','111'},N={'1001','1101','1011','1001','1001'},S={'111','100','111','001','111'}}
 local function lettering(text,x,y,z,scale)
  for i=1,#text do local rows=font[text:sub(i,i)]
   for j,row in ipairs(rows)do for k=1,#row do if row:sub(k,k)=='1'then
    box(x+(k-1)*scale,y+(5-j)*scale,z,scale*.83,scale*.83,.18,11)
   end end end
   x=x+(#rows[1]+1)*scale
  end
 end
 for _,p in ipairs(r.posters or {})do
  local x,z=p.x,p.z+14
  -- A shallow mounted frame, never a freestanding cube. Source event is untouched.
  box(x,5,z,16,27,.6,1)
  box(x+.35,5.35,z+.62,15.3,26.3,.35,3)
  box(x+.85,5.85,z+1,14.3,25.3,.12,7)
  box(x+1.25,6.25,z+1.14,13.5,24.5,.08,5)
  box(x+1.7,26.5,z+1.25,12.6,3.1,.08,8)
  lettering('JACKPOT',x+2.5,26.95,z+1.36,.4)
  -- Radiating gold lines surround a bold triple-seven emblem.
  for j=0,6 do
   local a=(j+1)*math.pi/8
   local ax,ay=x+8+6*math.cos(a),18+6*math.sin(a)
   box(ax,ay,z+1.25,.22,1.5,.05,3)
  end
  for j=0,2 do
   local xx=x+2.5+j*4
   box(xx-.3,13,z+1.3,3.5,8,.1,3)
   box(xx,13.3,z+1.42,2.9,7.4,.08,7)
   box(xx+.4,18.6,z+1.55,2.1,.65,.06,9)
   for k=0,4 do box(xx+1.7-k*.27,18-k*.63,z+1.55,.55,.8,.06,9)end
  end
  box(x+2.2,10.7,z+1.25,11.6,.25,.06,3)
  lettering('COINS',x+4.5,8,z+1.35,.35)
  -- Corner studs and a narrow warm picture light.
  for _,xx in ipairs({x+.6,x+15})do for _,yy in ipairs({5.7,31})do
   box(xx,yy,z+1.3,.35,.35,.15,4)
  end end
  box(x+7.5,31.3,z,.8,1.6,.8,3)
  box(x+3,32.6,z+.1,10,.6,1.8,3)
  box(x+3.4,32.5,z+1,9.2,.15,.8,11)
 end
 for _,p in ipairs(r.racks or {})do
  local x,z=p.x,p.z
  -- Solid rear cabinetry with framed cash drawers, not floating shelves.
  box(x,0,z+3,32,33,10,1)
  box(x,0,z+13,32,1.2,2,3)
  for j=0,2 do for i=0,3 do
   local xx,yy=x+1.2+i*7.6,2+j*7.2
   panel(xx,yy,z+13,6.8,6.5)
   box(xx+2.3,yy+2.6,z+13.95,2.1,.55,.4,12)
   box(xx+2.1,yy+4.6,z+13.85,2.5,.8,.12,7)
  end end
  box(x-.15,24,z+13,32.3,.6,.8,3)
  panel(x+1,25,z+13,30,6)
  box(x-.2,32,z+2.7,32.4,1.3,11.3,3)
  box(x+.4,33.3,z+3.3,31.2,.7,10,1)
 end
 for _,p in ipairs(r.counter or {})do
  local x,z=p.x,p.z
  box(x,0,z+3,8,9,10,1)
  panel(x+.25,1,z+13,7.5,7)
  box(x-.1,9,z+1.5,8.2,1.1,13,2)
  box(x-.1,9.7,z+14.45,8.2,.32,.2,3)
 end
 if #(r.counter or {})>0 then
  local first,last=r.counter[1].x,r.counter[#r.counter].x+8
  local z=126
  -- Face-height service windows stay open around both original clerks.
  for x=first+2,last-2,8 do
   local window=(x>23 and x<57)or(x>71 and x<105)
   if not window then box(x,10,z,.65,19,.65,3)end
  end
  for _,x in ipairs({first+1,23,57,71,105,last-2})do
   box(x,10,z-.4,1.3,20,1.3,2);box(x+.35,10,z+1,.45,20,.2,3)
  end
  box(first,28.5,z-1,last-first,1.2,2,3)
  box(first,30,z-2,last-first,8,3,1)
  box(first,37.6,z-2.3,last-first,.5,3.6,3)
  local mid=(first+last)/2
  box(mid-22,30.8,z+1.05,44,6.1,.35,3)
  box(mid-21.4,31.3,z+1.43,42.8,5.1,.12,8)
  lettering('COINS',mid-10,31.55,z+1.6,1)
  for _,x in ipairs({40,88})do
   box(x-4.5,10.2,z-2.5,9,.18,3.4,12)
   box(x-4,10.4,z-2,8,.12,2.4,8)
  end
 end
 for _,p in ipairs(r.cases or {})do
  local x,z=p.x,p.z
  box(x,0,z+12,16,27,12,1)
  panel(x+.7,1.2,z+24,14.6,7)
  box(x+.6,9,z+24,14.8,16,.4,3)
  box(x+1.3,9.7,z+24.45,13.4,14.6,.12,8)
  for j=0,2 do
   box(x+1.4,10+j*4.5,z+24.7,13.2,.45,1,3)
   for i=0,2 do box(x+2.5+i*4,11+j*4.5,z+24.7,2.5,2,.6,7)end
  end
  box(x-.2,26.6,z+11.8,16.4,.7,12.6,3)
 end
 for _,p in ipairs(r.walls or {})do
  local x,z=p.x,p.z
  box(x,0,z+6,8,29,2,1)
  panel(x+.3,1.5,z+8,7.4,10)
  box(x,12,z+8,8,.45,.5,3)
  box(x+.2,13,z+8,7.6,14,.2,5)
  box(x,28,z+5.5,8,1,3,3)
 end
 -- Low side returns contain the floor while keeping rotating camera views open.
 for _,x in ipairs({-2,320})do
  box(x,0,80,2,11,208,1)
  box(x-.15,10.6,80,2.3,.45,208,3)
 end
 return vs,ix
end
local function prepare(map)
 if V.require("CommunityVisuals").casino:get()~="n64memory" then return end
 if not(map and map.id=='GAME_CORNER')then return end
 if cached then return cached end
 local layout=M.layout(map);if not layout then return end
 local R=V.require('Voxel3D')
 local vertices,indices=M.geometry(layout)
 local mesh=R.newMesh(vertices,indices);if not mesh then return end
 local d=love.image.newImageData(16,1)
 for i,c in ipairs(palette)do d:setPixel(i-1,0,c[1],c[2],c[3],1)end
 local texture=love.graphics.newImage(d);texture:setFilter('nearest','nearest');d:release()
 local md=love.image.newImageData(16,1)
 for i=1,16 do md:setPixel(i-1,0,1,1,1,(i==11 and .5 or (i==7 and .16 or 0)))end
 local mask=love.graphics.newImage(md);mask:setFilter('nearest','nearest');md:release()
 local shell={}
 for _,part in ipairs({'north','south','east','west','ceiling','chandeliers'})do
  local vv,ii=M.geometry(layout,part);shell[part]=R.newMesh(vv,ii)
 end
 cached={mesh=mesh,texture=texture,mask=mask,layout=layout,shell=shell};return cached
end
function M.build(S,map)
 if V.require("RocketRoom").accepts(map) then return V.require("RocketRoom").build(S,map) end
 if map and map.id=='ROUTE_10' then return V.require('LegendaryGarden').build(S,map) end
 if map and map.tileset and V.require('UndergroundRoom').accepts(map) then return V.require('UndergroundRoom').build(S,map) end
 if map and map.id=='GAME_CORNER_PRIZE_ROOM' then return V.require('PrizeRoom').build(S,map) end
 local r=prepare(map);if not r then return end
 for k in pairs(r.layout.claim)do
  S.skip[k]=true;S.ground[k]=false
  S.shapeAt[k]={class='ground',h=0,flat=true,art='flat',authored=true}
 end
end
function M.draw(map,shadow)
 if V.require("RocketRoom").accepts(map) then return V.require("RocketRoom").draw(map,shadow) end
 if map and map.id=='ROUTE_10' then return V.require('LegendaryGarden').draw(map,shadow) end
 if map and map.tileset and V.require('UndergroundRoom').accepts(map) then return V.require('UndergroundRoom').draw(map,shadow) end
 if map and map.id=='GAME_CORNER_PRIZE_ROOM' then return V.require('PrizeRoom').draw(map,shadow) end
 local r=prepare(map);if not r then return end
 if shadow then shadow.draw(r.mesh,r.texture)else
  local R=V.require('Voxel3D');local old=R.glassMask
  R.glassMaskNow(r.mask);R.glass(true)
  local ok,err=pcall(function()
   R.draw(r.mesh,r.texture)
   local visible=M.visibleShell(R.eye)
   for _,part in ipairs({'north','south','east','west','ceiling','chandeliers'})do
    if visible[part] and r.shell[part]then R.draw(r.shell[part],r.texture)end
   end
  end)
  R.glass(false);R.glassMaskNow(old)
  if not ok then error(err)end
 end
end
function M.support(map,cx,cy)
 if V.require("CommunityVisuals").casino:get()~="n64memory" then return end
 if map and map.id=='GAME_CORNER' and map.cellTile then
  local t=map:cellTile(cx,cy)
  if t==23 or t==24 then return 0 end
 end
end
-- Keep the far walls; omit any boundary between an exterior camera and the room.
function M.visibleShell(eye)
 eye=eye or {160,24,176}
 return {north=eye[3]>64,south=eye[3]<288,west=eye[1]>0,east=eye[1]<320,
  ceiling=eye[2]<69,chandeliers=eye[2]<69}
end
function M.invalidate()
 V.require("RocketRoom").invalidate()
 V.require('LegendaryGarden').invalidate()
 V.require('UndergroundRoom').invalidate()
 V.require('PrizeRoom').invalidate()
 if cached then for _,mesh in pairs(cached.shell or {})do mesh:release()end;cached.mesh:release();cached.texture:release();cached.mask:release();cached=nil end
end
function M.setLive(live)
 V.require("RocketRoom").setLive(live)
 V.require('LegendaryGarden').setLive(live)
 V.require('UndergroundRoom').setLive(live)
 V.require('PrizeRoom').setLive(live)
 if not live.GAME_CORNER and cached then
  for _,mesh in pairs(cached.shell or {})do mesh:release()end
  cached.mesh:release();cached.texture:release();cached.mask:release();cached=nil
 end
end
return M
