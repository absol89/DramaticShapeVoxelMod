-- Map-local Prize Room furnishings. Original cells still own interaction/collision.
local V=...
local M={}
local cached
local palette={{.075,.08,.10},{.14,.15,.18},{.48,.34,.16},{.77,.60,.30},
 {.27,.045,.075},{.44,.075,.105},{.87,.79,.59},{.055,.065,.08},
 {.72,.12,.10},{.18,.45,.32},{.93,.62,.24},{.42,.44,.48},
 {.105,.025,.043},{.15,.035,.053},{.20,.055,.075},{.28,.13,.10}}
local function key(x,y)return (y+64)*4096+x+64 end
function M.layout(map)
 if V.require("CommunityVisuals").prizeRoom:get()~="n64memory" then return end
 if not(map and map.id=='GAME_CORNER_PRIZE_ROOM' and map.tileset.id=='LOBBY'
  and map.def.width==5 and map.def.height==4)then return end
 -- Require the original three windows and counter before replacing shared art.
 for _,x in ipairs({4,8,12})do
  if map:tileAt(x,3)~=10 or map:tileAt(x+1,3)~=11 then return end
 end
 for x=0,19 do if map:tileAt(x,4)~=39 or map:tileAt(x,5)~=21 then return end end
 local r={floor={},claim={}}
 for y=0,15 do for x=0,19 do
  r.floor[#r.floor+1]={x=x*8,z=y*8};r.claim[key(x,y)]={x,y}
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
   box(left,base,-2,right-left,64-base,2,1)
   box(left,60,.05,right-left,1.1,1.8,3)
   box(left,62,.05,right-left,.4,2.4,4)
   if base==0 then
    box(left,.3,0,right-left,1.4,.7,3)
    box(left,16,0,right-left,.65,.9,3)
    for x=left+2,right-24,32 do
     box(x,2,.06,24,12,.2,16);frame(x,2,.3,24,12,3)
     box(x,20,.06,24,35,.2,5);frame(x,20,.3,24,35,3)
     -- Geometric inset in the fabric panel.
     frame(x+3,24,.51,18,27,2)
    end
    for x=left+32,right-16,64 do
     box(x-2,36,.65,4,12,.65,2)
     box(x-1.5,38,1.4,3,7,1.5,11)
     for _,xx in ipairs({x-1.7,x+1.35})do box(xx,37.6,3,.35,7.7,.35,3)end
     box(x-2,37,1.1,4,.7,2.5,3);box(x-2,45,1.1,4,.7,2.5,3)
    end
   end
  end
  if part=='north' then ox,oz,turn=80,0,0;wallSpan(-80,80)
  elseif part=='west' then ox,oz,turn=0,64,1;wallSpan(-64,64)
  elseif part=='east' then ox,oz,turn=160,64,-1;wallSpan(-64,64)
  elseif part=='south' then
   ox,oz,turn=80,130,2
   -- Original two-cell exit stays usable; recessed doors sit beyond the warp.
   -- Doorway at world x64..96 remains an opening.
   wallSpan(-80,-16);wallSpan(16,80);wallSpan(-16,16,36)
   V.require("CasinoDoors").add(box,quad,0,true)
  elseif part=='ceiling' then
   -- Downward-facing recessed coffers, all decoration stays above headroom.
   for x=0,159,32 do for z=0,127,32 do
    box(x,65,z,32,1,32,1)
    box(x+2,64.1,z+2,28,.4,28,2)
    box(x+3,63.8,z+3,26,.3,26,3)
    box(x+3.5,63.5,z+3.5,25,.3,25,1)
   end end
   for x=0,160,32 do box(x-.35,62.8,0,.7,.6,128,3)end
   for z=0,128,32 do box(0,62.8,z-.35,160,.6,.7,3)end
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
   for _,cx in ipairs({80})do
    ox,oz,turn=cx,80,0
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
  if part=='chandeliers' then for _,p in ipairs(vs)do p[1]=80+(p[1]-80)*.8;p[3]=80+(p[3]-80)*.8;p[2]=p[2]-8 end end
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

 ox,oz,turn=0,0,0
 local function frame(x,y,z,w,h,col)
  box(x,y,z,w,.4,.3,col);box(x,y+h-.4,z,w,.4,.3,col)
  box(x,y,z,.4,h,.3,col);box(x+w-.4,y,z,.4,h,.3,col)
 end
 local font={P={'110','101','110','100','100'},R={'110','101','110','101','101'},
 I={'111','010','010','010','111'},Z={'111','001','010','100','111'},
 E={'111','100','110','100','111'},S={'111','100','111','001','111'},
 ['1']={'010','110','010','010','111'},['2']={'110','001','010','100','111'},
 ['3']={'110','001','010','001','110'}}
 local function text(s,x,y,z,scale)
  for n=1,#s do for j,row in ipairs(font[s:sub(n,n)])do for i=1,3 do
   if row:sub(i,i)=='1'then box(x+(n-1)*4*scale+(i-1)*scale,y+(5-j)*scale,z,scale*.85,scale*.85,.15,11)end
  end end end
 end
 -- A runner leads between the untouched two-cell exit and the service aisle.
 box(65,.055,60,30,.035,68,5)
 for _,x in ipairs({65.6,93.8})do box(x,.095,60,.6,.015,68,3)end
 for z=64,120,16 do
  quad({78,.115,z},{80,.115,z+2},{82,.115,z},{80,.115,z-2},3)
 end
 -- Continuous counter remains entirely inside original blocked row 4/5.
 box(0,0,33,160,9,13,1)
 box(0,9,32,160,1.2,15,2)
 box(0,9.9,47,160,.35,.35,3)
 for x=1,145,16 do
  box(x,1,46,14,6.8,.3,16);frame(x,1,46.35,14,6.8,3)
 end
 -- Three recessed service openings line up with bg_events (2,2), (4,2), (6,2).
 box(0,10.2,25,160,29,3,1)
 for _,cx in ipairs({40,72,104})do
  box(cx-11,11,28.1,22,19,.2,8)
  frame(cx-11,11,28.35,22,19,3)
  box(cx-9.5,28.2,28.8,19,.45,1.2,11)
  box(cx-10,11,29,20,.5,8,2)
  box(cx-9.5,11.5,29,19,.25,1.3,3)
  -- Pass-through tray and desk bell; nothing projects into the customer aisle.
  box(cx-4,10.25,40,8,.18,5,12)
  box(cx-3.5,10.45,40.4,7,.12,4,8)
  cylinder(10.25,.3,1.3,1.3,3,cx+7,42)
  cylinder(10.55,.8,1.1,.2,4,cx+7,42)
 end
 for n,cx in ipairs({40,72,104})do
  box(cx-3,31,28.2,6,6,.2,3);box(cx-2.6,31.4,28.45,5.2,5.2,.15,5)
  text(tostring(n),cx-1.05,32,28.7,.7)
 end
 -- Crown marquee and inset sunburst ornaments.
 box(0,39,24,160,1,6,3)
 box(46,40,25,68,9,3,1);frame(46.5,40.5,28.1,67,8,3)
 text('PRIZES',66.2,42,28.5,1.2)
 for _,cx in ipairs({16,136})do
  box(cx-7,14,28.2,14,20,.3,5);frame(cx-7,14,28.55,14,20,3)
  quad({cx,30,29},{cx+4,24,29},{cx,18,29},{cx-4,24,29},3)
  quad({cx,28,29.1},{cx+2.5,24,29.1},{cx,20,29.1},{cx-2.5,24,29.1},5)
 end
 -- South display cabinets face into the room, inside their original footprints.
 local function prize(x,y,z,kind)
  if kind==0 then
   -- Pokeball specimen, geometric and legible at handheld resolution.
   for j=0,11 do
    local a,b=j*math.pi/6,(j+1)*math.pi/6
    quad({x,y,z},{x+1.65*math.cos(a),y+1.65*math.sin(a),z},
     {x+1.65*math.cos(b),y+1.65*math.sin(b),z},{x,y,z},j<6 and 9 or 7)
   end
   box(x-1.65,y-.15,z+.1,3.3,.3,.1,1)
   box(x-.45,y-.45,z+.22,.9,.9,.15,1);box(x-.22,y-.22,z+.4,.44,.44,.08,7)
  elseif kind==1 then
   cylinder(y-1.8,.4,1.5,1.5,3,x,z-1)
   cylinder(y-1.4,1,.45,.45,3,x,z-1)
   cylinder(y-.4,2,.6,1.6,4,x,z-1)
   box(x-1.7,y+1.6,z-2.7,3.4,.25,3.4,3)
  else
   box(x-1.5,y-1.5,z-1,3,3,.8,10);frame(x-1.5,y-1.5,z-.15,3,3,3)
   box(x-.9,y-.2,z+.2,1.8,.35,.1,7)
  end
 end
 for _,cx in ipairs({16,48,112,144})do
  ox,oz,turn=cx,112,2
  box(-15,0,-13,30,29,23,1)
  box(-15,0,10,30,1,1,3)
  box(-14,2,10.1,28,6,.2,16);frame(-14,2,10.35,28,6,3)
  box(-14,9,10.1,28,18,.2,8);frame(-14,9,10.35,28,18,3)
  for row=0,1 do
   box(-13,10+row*8,10.5,26,.5,1.4,3)
   box(-12.5,16.8+row*8,10.6,25,.35,.5,11)
   for col=0,2 do
    local x=-8+col*8
    prize(x,13.5+row*8,11,(col+row)%3)
    box(x-1.5,10.6+row*8,11.1,3,.55,.2,7)
   end
  end
  box(-15.4,28,-13.3,30.8,1,24,3)
  box(-14.8,29,-12.7,29.6,.6,23,1)
 end
 return vs,ix
end
local function prepare(map)
 if V.require("CommunityVisuals").prizeRoom:get()~="n64memory" then return end
 if not(map and map.id=='GAME_CORNER_PRIZE_ROOM')then return end
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
 local r=prepare(map);if not r then return end
 for k in pairs(r.layout.claim)do
  S.skip[k]=true;S.ground[k]=false
  S.shapeAt[k]={class='ground',h=0,flat=true,art='flat',authored=true}
 end
end
function M.draw(map,shadow)
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
-- Keep the far walls and remove boundaries that obscure an exterior camera.
function M.visibleShell(eye)
 eye=eye or {80,24,80}
 return {north=eye[3]>0,south=eye[3]<128,west=eye[1]>0,east=eye[1]<160,
  ceiling=eye[2]<61,chandeliers=eye[2]<61}
end
function M.invalidate()
 if cached then for _,mesh in pairs(cached.shell or {})do mesh:release()end;cached.mesh:release();cached.texture:release();cached.mask:release();cached=nil end
end
function M.setLive(live)if not live.GAME_CORNER_PRIZE_ROOM then M.invalidate()end end
return M
