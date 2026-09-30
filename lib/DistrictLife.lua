-- Useful-looking regional details without adding more planted beds.
-- Decorative only: source interactions, collisions and NPC rules are unchanged.
local V=...;local C=V.require('SurfaceCraft');local M={}
M.specs={
 PALLET_TOWN={{'mailbox',2.2,2.2,1,'REDS_HOUSE'},{'mailbox',2.2,2.2,1,'BLUES_HOUSE'},{'villagePump',3.4,3.4,1}},
 VIRIDIAN_CITY={{'picnic',11,6.5,1},{'birdbath',4,4,1},{'logHabitat',7,4,2}},
 PEWTER_CITY={{'mineralDisplay',6.5,4,2,'MUSEUM'},{'quarryCart',6,4.5,1,'GYM'}},
 CERULEAN_CITY={{'shoreBoat',11,5,1,nil,true},{'waterBasin',6,5,1,'GYM'},{'mooring',5,4,1,nil,true}},
 FUCHSIA_CITY={{'safariSupplies',7,4.5,1,'SAFARI'},{'lookout',3,3,2,nil,true},{'fieldMap',5,3,1,'SAFARI'}},
 SAFFRON_CITY={{'streetClock',2.7,2.7,1,'SILPH'},{'newsKiosk',3.2,3,2},{'utilityCabinet',3.4,2.6,1}},
 ROUTE_17={{'cyclePump',3,3,2},{'repairStand',4,3,2},{'drinkingStation',3,3,2}},
 CINNABAR_ISLAND={{'rescueRing',4,3,1},{'mooring',5,4,1},{'coastalCrates',5.5,4,1}},
}
M.kinds={};for _,specs in pairs(M.specs)do for _,s in ipairs(specs)do M.kinds[s[1]]=true end end
function M.build(x,z,h,f,emit,id)
 -- Keep the accepted layout plan stable; only this entrance fixture is removed.
 -- Retaining its reserved clearance prevents a flower bed taking its place.
 if id=='FUCHSIA_CITY' and f.kind=='safariSupplies'then return end
 local G=C.builder(x,z,emit);local a,b=f.cx,f.cz
 local function pos(u,v)
  if f.edge=='s'then return a+u,b-v elseif f.edge=='w'then return a+v,b+u
  elseif f.edge=='e'then return a-v,b+u else return a+u,b+v end
 end
 local function box(u,v,c,d,lo,hi,mat,t)
  local px,pz=pos(u,v);local qx,qz=pos(c,d)
  G.box(math.min(px,qx),math.min(pz,qz),math.max(px,qx),math.max(pz,qz),h+lo,h+hi,mat,t or 1)
 end
 local function face(p,mat,t)
  local q={};for _,v in ipairs(p)do local xx,zz=pos(v[1],v[3]);q[#q+1]={xx,h+v[2],zz}end
  if f.edge=='s' or f.edge=='w'then local r={};for i=#q,1,-1 do r[#r+1]=q[i]end;q=r end
  G.face(q,mat,t)
 end
 local function ring(u,v,y,r,thick,mat,vertical)
  for i=0,15 do
   local aa,bb=i*math.pi/8,(i+1)*math.pi/8
   local function p(t,rr)return vertical and {u+math.cos(t)*rr,y+math.sin(t)*rr,v} or {u+math.cos(t)*rr,y,v+math.sin(t)*rr}end
   local q={p(aa,r),p(bb,r),p(bb,r-thick),p(aa,r-thick)}
   local m=vertical and (i%4==0 or i%4==1) and 'cityAccent' or mat
   face(q,m,1)
   if vertical then face({q[4],q[3],q[2],q[1]},m,.94)end
  end
 end
 local kind=f.kind
 if kind=='mailbox' then
  box(-.32,-.35,.32,.35,.15,6.2,'wood',.85)
  box(-1.8,-1.4,1.8,1.4,5.8,8.2,'cityAccent',1)
  box(-1.95,-1.55,1.95,1.55,8.2,8.55,'shadow',.8)
  box(-1.35,1.42,1.35,1.49,6.7,7.2,'shadow',.65)
  box(-.7,1.5,.7,1.57,6.05,6.4,'cityBorder',1.1)
  box(1.84,-.5,2.02,-.28,7.0,9.1,'cityBorder',1)
  box(1.84,-.5,2.02,.45,8.6,9.1,'cityAccent',1.1)
 elseif kind=='villagePump' or kind=='drinkingStation' then
  box(-3,-2.6,3,2.6,.1,.5,'cityBorder',.9)
  box(-1.4,-1.1,1.4,1.1,.5,5.3,kind=='villagePump' and 'wood' or 'shadow',.9)
  box(-.55,-.55,.55,.55,5.3,9,'shadow',.8)
  box(-.6,.3,.6,2.2,6.1,6.6,'shadow',.88)
  box(-.45,1.8,.45,2.35,5.6,6.6,'shadow',.9)
  box(-1.4,-.55,-.95,1.65,7.7,8.1,'wood',1)
  box(-1.6,1.35,-.8,1.85,7.4,8.35,'wood',.8)
  box(-2.1,.75,2.1,2.5,.6,1.1,'stonePaving',.9)
  box(-1.55,1.1,1.55,2.1,1.11,1.15,'basinWater',.95)
 elseif kind=='picnic' then
  for _,u in ipairs({-7,7})do
   box(u-.4,-5.7,u+.4,5.7,1,1.6,'wood',.8)
   box(u-.4,-2,u+.4,-1.3,1,6,'shadow',.8)
   box(u-.4,1.3,u+.4,2,1,6,'shadow',.8)
   for _,v in ipairs({-5,5})do box(u-.35,v-.35,u+.35,v+.35,.15,3.6,'wood',.85)end
  end
  for v=-2.4,2.4,1.2 do box(-10,v,10,v+.95,6,6.5,'wood',.95+(v%2)*.035)end
  for _,v in ipairs({-5.8,4.5})do box(-10,v,10,v+1.3,3.5,4,'wood',1)end
 elseif kind=='birdbath' or kind=='waterBasin' then
  local r=kind=='birdbath' and 3.5 or 5.4
  box(-r,-r*.8,r,r*.8,.1,.55,'cityBorder',.86)
  box(-1,-1,1,1,.55,kind=='birdbath' and 5.8 or 2.5,'stonePaving',.94)
  local y=kind=='birdbath' and 5.8 or 2.5
  for i=0,11 do
   local aa,bb=i*math.pi/6,(i+1)*math.pi/6
   face({{math.cos(aa)*r,y,math.sin(aa)*r*.8},{math.cos(bb)*r,y,math.sin(bb)*r*.8},{math.cos(bb)*r,y+1,math.sin(bb)*r*.8},{math.cos(aa)*r,y+1,math.sin(aa)*r*.8}},'cityBorder',.86+i*.01)
   face({{0,y+.82,0},{math.cos(aa)*(r-.5),y+.82,math.sin(aa)*(r-.5)*.8},{math.cos(bb)*(r-.5),y+.82,math.sin(bb)*(r-.5)*.8}},'basinWater',.97)
   face({{math.cos(aa)*r,y+1,math.sin(aa)*r*.8},{math.cos(bb)*r,y+1,math.sin(bb)*r*.8},{math.cos(bb)*(r-.5),y+1,math.sin(bb)*(r-.5)*.8},{math.cos(aa)*(r-.5),y+1,math.sin(aa)*(r-.5)*.8}},'stonePaving',1)
  end
  ring(0,0,y+.85,r*.42,.035,'basinWater')
  if kind=='waterBasin'then box(-.7,-.7,.7,.7,y+.2,y+3.5,'cityBorder',1);box(-1.3,-1.3,1.3,1.3,y+3.5,y+3.8,'stonePaving',1.03)end
 elseif kind=='logHabitat' then
  for i=0,2 do
   local v=-2.0+i*1.9;local yy=i==1 and 2.2 or 1.25;local r=.95
   for j=0,7 do
    local aa,bb=j*math.pi/4,(j+1)*math.pi/4
    local ya,yb=yy+math.cos(aa)*r,yy+math.cos(bb)*r
    local va,vb=v+math.sin(aa)*r,v+math.sin(bb)*r
    face({{-6,ya,va},{6,ya,va},{6,yb,vb},{-6,yb,vb}},'wood',.68+j*.035)
    for _,u in ipairs({-6,6})do
     local q={{u,yy,v},{u,ya,va},{u,yb,vb}};face(q,'cityBorder',.78);face({q[3],q[2],q[1]},'cityBorder',.78)
    end
   end
   box(-2.5,v-.32,.8,v+.32,yy+r-.05,yy+r+.08,'canopy',.72)
  end
 elseif kind=='mineralDisplay' then
  box(-6,-3.5,6,3.5,.1,.5,'stonePaving',.8)
  box(-5.6,-3.1,5.6,3.1,.5,2.1,'cityBorder',.95)
  box(-5.2,-2.7,5.2,2.7,2.1,2.3,'shadow',.72)
  for j=0,4 do
   local u=-3+j*1.5;local v=(j%2)*1.8-1;local y=4.2+(j%3)*.8
   for i=0,4 do
    local aa,bb=i*math.pi*.4,(i+1)*math.pi*.4
    local p={u+math.cos(aa)*.85,2.3,v+math.sin(aa)*.85};local q={u+math.cos(bb)*.85,2.3,v+math.sin(bb)*.85}
    local r={u+.15+math.cos(bb)*.70,y-.65,v+math.sin(bb)*.70};local s={u+.15+math.cos(aa)*.70,y-.65,v+math.sin(aa)*.70}
    local mat=j%3==0 and 'cityAccent' or 'cityBorder'
    face({p,q,r,s},mat,.84+i*.045);face({s,r,{u+.25,y,v}},mat,1.03)
   end
  end
  box(-2.4,2.45,2.4,3.05,2.31,2.55,'cityBorder',1)
  -- Museum sample trays: brass labels, mineral veins and low retaining clips.
  for j=0,2 do local u=-3.7+j*3.6
   box(u-.75,2.35,u+.75,2.88,2.31,2.43,'wood',.82)
   box(u-.55,2.41,u+.55,2.80,2.44,2.48,'cityBorder',1.10)
   for k=0,2 do box(u-.40+k*.28,2.48,u-.29+k*.28,2.68,2.485,2.50,'shadow',.70)end
  end
  for _,u in ipairs({-5.6,5.3})do box(u,-3.05,u+.30,3.05,2.11,2.40,'shadow',.82)end
 elseif kind=='quarryCart' then
  -- Flanged wheels, recessed plank sides and unequal quarried specimens.
  for _,u in ipairs({-4,4})do
   box(u-.15,-3.75,u+.15,3.75,.83,1.13,'shadow',.80)
   for _,v in ipairs({-3.7,3.7})do
    for i=0,9 do local a,b=i*math.pi/5,(i+1)*math.pi/5
     local function pt(t,r,depth)return{u+math.cos(t)*r,1.08+math.sin(t)*r,v+depth}end
     face({pt(a,.92,-.24),pt(b,.92,-.24),pt(b,.92,.24),pt(a,.92,.24)},'shadow',.81)
     for _,d in ipairs({-.25,.25})do
      face({pt(a,.92,d),pt(b,.92,d),pt(b,.52,d),pt(a,.52,d)},'shadow',.74)
      face({pt(a,.47,d),pt(b,.47,d),{u,1.08,v+d}},'cityBorder',.91)
     end
    end
   end
  end
  box(-5.6,-3.2,5.6,3.2,1.7,2.3,'wood',.9)
  for y=2.3,5.2,1.05 do
   for _,u in ipairs({-5.6,5.15})do box(u,-3.2,u+.45,3.2,y,y+.91,'wood',.82+(y%1)*.13)end
   for _,v in ipairs({-3.2,2.75})do box(-5.6,v,5.6,v+.45,y,y+.91,'wood',.91+(y%1)*.08)end
  end
  for j=0,3 do local u=-3.7+j*2.35;local v=j%2==0 and -.8 or .6
   local height=5.45+(j%3)*.63
   for i=0,5 do local a,b=i*math.pi/3,(i+1)*math.pi/3
    local p={u+math.cos(a)*1.4,3.2,v+math.sin(a)*1.2};local q={u+math.cos(b)*1.4,3.2,v+math.sin(b)*1.2}
    local r={u+.2+math.cos(b),height-.7,v+math.sin(b)*.9};local t={u+.2+math.cos(a),height-.7,v+math.sin(a)*.9}
    face({p,q,r,t},'stonePaving',.84+(i%3)*.07)
    face({t,r,{u+.35,height,v}},'cityBorder',.88+(i%2)*.10)
   end
  end
  for _,u in ipairs({-4.9,4.5})do for _,v in ipairs({-3.25,3.2})do
   box(u,v,u+.35,v+.06,2.3,5.9,'shadow',.7)
   for _,y in ipairs({2.65,4.65,5.55})do box(u+.09,v-.025,u+.26,v+.09,y,y+.14,'cityBorder',1)end
  end end
 elseif kind=='shoreBoat' then
  local hull={{-10,0},{-7,-3.8},{6,-3.8},{10,0},{6,3.8},{-7,3.8}}
  for i,p in ipairs(hull)do local q=hull[i%#hull+1]
   face({{p[1]*.7,.4,p[2]*.6},{q[1]*.7,.4,q[2]*.6},{q[1],3.5,q[2]},{p[1],3.5,p[2]}},'wood',.77+i*.035)
   face({{p[1],3.5,p[2]},{q[1],3.5,q[2]},{q[1]*.92,3.5,q[2]*.85},{p[1]*.92,3.5,p[2]*.85}},'cityBorder',.9)
  end
  box(-6,-1.8,6,1.8,.5,.75,'wood',.66)
  for _,u in ipairs({-4,3})do box(u-.65,-3.1,u+.65,3.1,2.4,2.8,'wood',1.05)end
  box(-7,-.2,7,.2,3.6,3.9,'wood',.93);box(-8,-.65,-5,.65,3.6,3.9,'wood',.98)
  -- Continuous lapstrakes follow the hull rather than separate square boards.
  for i,p in ipairs(hull)do local q=hull[i%#hull+1]
   for _,yy in ipairs({1.4,2.45})do
    local t=(yy-.4)/3.1;local sx,sz=.7+.3*t,.6+.4*t
    face({{p[1]*sx,yy,p[2]*sz},{q[1]*sx,yy,q[2]*sz},{q[1]*(sx+.008),yy+.08,q[2]*(sz+.012)},{p[1]*(sx+.008),yy+.08,p[2]*(sz+.012)}},'shadow',.79)
   end
  end
  for _,v in ipairs({-3.55,3.55})do
   box(2.3,v-.2,3.2,v+.2,3.5,3.8,'cityBorder',1.07)
   box(2.63,v-.13,2.88,v+.13,3.8,4.2,'shadow',.84)
  end
  for u=-5,5,2 do box(u-.04,-1.7,u+.04,1.7,.76,.79,'shadow',.71)end
  ring(-2,0,.81,.95,.18,'cityBorder')
 elseif kind=='mooring' then
  box(-4.4,-3.1,4.4,3.1,.1,.4,'wood',.9)
  for _,u in ipairs({-2.8,2.8})do box(u-.7,-.7,u+.7,.7,.4,4.6,'shadow',.8);box(u-1.15,-.85,u+1.15,.85,4.2,4.7,'shadow',.85)end
  for r=1.2,2.8,.42 do ring(0,0,.48,r,.23,'cityBorder')end
  if id=='CERULEAN_CITY'then
   for _,u in ipairs({-2.8,2.8})do
    box(u-.72,-.72,u+.72,.72,3.5,3.73,'cityBorder',1.03)
    for _,v in ipairs({-.52,.52})do box(u-.49,v-.055,u+.49,v+.055,4.71,4.77,'cityBorder',.98)end
   end
   for _,v in ipairs({-2.9,2.7})do box(-4.35,v,4.35,v+.16,.41,.44,'shadow',.80)end
  end
 elseif kind=='safariSupplies' or kind=='coastalCrates' then
  for i=0,2 do
   local u=-3.4+i*3.4;local yy=i==1 and 5.8 or 3.9
   box(u-1.5,-2.4,u+1.5,2.4,.1,yy,'wood',.8+i*.07)
   for _,v in ipairs({-2.45,2.35})do
    box(u-1.48,v,u+1.48,v+.1,.7,1.05,'shadow',.7)
    box(u-1.48,v,u+1.48,v+.1,yy-.8,yy-.45,'shadow',.7)
   end
   box(u-1.55,-2.45,u+1.55,2.45,yy,yy+.25,'wood',1)
  end
  for i=0,2 do
   local u=-3.4+i*3.4;local yy=i==1 and 5.8 or 3.9
   for y=1.3,yy-.3,1.15 do
    box(u-1.48,2.46,u+1.48,2.50,y,y+.075,'shadow',.72)
    box(u-1.48,-2.51,u+1.48,-2.47,y,y+.075,'shadow',.72)
   end
   for _,du in ipairs({-1.15,1.15})do
    box(u+du-.10,-2.53,u+du+.10,2.53,yy+.26,yy+.33,'shadow',.85)
    for _,v in ipairs({-2.52,2.52})do
     box(u+du-.12,v-.035,u+du+.12,v+.035,.25,yy+.3,'shadow',.8)
     for _,y in ipairs({.6,yy-.3})do box(u+du-.055,v-.055,u+du+.055,v+.055,y,y+.11,'cityBorder',.85)end
    end
   end
   box(u-.48,2.52,u+.48,2.58,yy*.47,yy*.47+.35,'cityBorder',.86)
  end
  if kind=='safariSupplies'then
   -- Open field rack: two uprights, a shelf and three strapped canvas packs.
   for _,u in ipairs({-5.6,5.6})do box(u-.24,-3.4,u+.24,-2.9,.15,11.5,'wood',.86)end
   box(-5.9,-3.45,5.9,-2.85,10.8,11.35,'wood',.96)
   box(-5.9,-3.5,5.9,-1.55,6.5,6.8,'wood',.96)
   for u=-4.2,4.2,4.2 do
    box(u-.95,-2.8,u+.95,-1.75,6.8,9.6,'canopy',.85)
    box(u-1.05,-2.85,u+1.05,-1.65,9.2,9.65,'canopy',.96)
    for _,du in ipairs({-.57,.57})do box(u+du-.10,-1.73,u+du+.10,-1.59,6.9,9.65,'wood',.91)end
    box(u-.3,-1.59,u+.3,-1.5,8.25,8.7,'cityBorder',.95)
    box(u-.25,-2.7,u+.25,-2.45,9.65,10.15,'shadow',.8)
   end
  end
 elseif kind=='lookout' then
  box(-2.5,-2.5,2.5,2.5,.1,.45,'cityBorder',.9)
  box(-.42,-.42,.42,.42,.45,10.2,'wood',.83)
  box(-1.6,-.6,1.6,.6,10.2,10.7,'shadow',.85)
  for _,u in ipairs({-.9,.9})do
   box(u-.52,-2.2,u+.52,1.5,10.7,11.75,'shadow',.8)
   box(u-.62,-2.3,u+.62,-1.7,10.55,11.9,'cityBorder',.83)
  end
 elseif kind=='fieldMap' or kind=='newsKiosk' or kind=='utilityCabinet' then
  local field=kind=='fieldMap';local cabinet=kind=='utilityCabinet'
  local w=field and 4.5 or 2.8
  box(-w,-1.8,w,1.8,.1,field and 1.0 or 8.5,field and 'wood' or cabinet and 'stonePaving' or 'pavingBand',.84)
  if field then for _,u in ipairs({-3.8,3.8})do box(u-.32,-.32,u+.32,.32,.4,9.4,'wood',.9)end end
  if not cabinet then
   box(-w,-.55,w,.55,field and 6 or 8.5,field and 13 or 11.6,'wood',.92)
   box(-w+.5,.57,w-.5,.65,field and 6.5 or 9,field and 12.5 or 11.15,'cityBorder',1.04)
  else box(-w-.15,-1.95,w+.15,1.95,8.5,8.8,'shadow',.83)end
  if field then
   for i=0,2 do box(-3.1+i*2,.67,-1.9+i*2,.7,7.2,8.5+i,'canopy',.86+i*.07)end
   box(-2.7,.72,2.7,.77,9.0,9.3,'cityAccent',.9)
  elseif cabinet then
   for y=2,6,1 do box(-1.9,1.81,1.9,1.86,y,y+.16,'shadow',.7)end
   box(1.5,1.86,1.8,1.94,6.8,7.7,'shadow',.75)
  else
   for y=9.4,10.7,.45 do box(-1.8,.67,1.5-(y%1),.71,y,y+.1,'shadow',.8)end
   for y=3,7,1 do box(-2,1.82,2,1.9,y,y+.55,'cityBorder',.92)end
   box(-2,1.92,2,1.98,7.6,8.15,'shadow',.75)
  end
 elseif kind=='streetClock' then
  box(-2,-2,2,2,.1,.65,'cityBorder',.93)
  box(-.55,-.55,.55,.55,.65,18.4,'shadow',.75)
  box(-2.5,-.65,2.5,.65,18.4,23.5,'shadow',.8)
  for _,v in ipairs({-.7,.7})do
   box(-2.13,v-.03,2.13,v+.03,18.77,23.13,'cityBorder',1.08)
   for j=0,11 do
    local t=j*math.pi/6;local u=math.sin(t)*1.7;local y=20.95+math.cos(t)*1.7
    box(u-.10,v-.08,u+.10,v+.08,y-.1,y+.1,'shadow',.6)
   end
   box(-.11,v-.1,.11,v+.1,20.8,22.2,'shadow',.65)
   box(-.1,v-.1,1.15,v+.1,20.84,21.06,'shadow',.65)
  end
 elseif kind=='cyclePump' or kind=='repairStand' then
  box(-2.6,-2.1,2.6,2.1,.1,.45,'cityBorder',.87)
  box(-.35,-.35,.35,.35,.45,kind=='cyclePump' and 6.8 or 9.5,'shadow',.78)
  if kind=='cyclePump'then
   box(-1.8,-.25,1.8,.25,6.8,7.2,'wood',.9)
   box(.65,-.3,1.1,.3,.8,5.5,'cityAccent',1)
   box(-.12,.4,.12,1.5,4.5,4.75,'shadow',.8)
   box(-.12,1.2,.12,1.5,1.5,4.7,'shadow',.8)
  else
   box(-2.6,-.32,2.6,.32,9.2,9.6,'shadow',.9)
   for _,u in ipairs({-2,1.8})do box(u,-.5,u+.25,.8,8.8,10.2,'wood',.87)end
   box(-2,-1.6,2,1.6,3.6,3.9,'shadow',.9)
   for u=-1.1,1.1,1.1 do box(u-.13,-.9,u+.13,.9,3.9,4.1,'cityBorder',1)end
  end
 elseif kind=='rescueRing' then
  for _,u in ipairs({-2.5,2.5})do box(u-.24,-.3,u+.24,.3,.1,10.2,'wood',.9)end
  box(-3.5,-.4,3.5,.4,9.7,10.25,'wood',1)
  for _,v in ipairs({-.5,.5})do
   ring(0,v,6.2,2.8,.7,'cityBorder',true)
   for _,u in ipairs({-2.4,2.4})do box(u-.32,v-.04,u+.32,v+.04,5.65,6.75,'cityAccent',1.08)end
  end
  for i=0,15 do for _,r in ipairs({2.1,2.8})do
   local aa,bb=i*math.pi/8,(i+1)*math.pi/8
   local q={{math.cos(aa)*r,6.2+math.sin(aa)*r,-.5},{math.cos(bb)*r,6.2+math.sin(bb)*r,-.5},{math.cos(bb)*r,6.2+math.sin(bb)*r,.5},{math.cos(aa)*r,6.2+math.sin(aa)*r,.5}}
   face(q,i%4==0 and 'cityAccent' or 'cityBorder',.94)
   face({q[4],q[3],q[2],q[1]},'cityBorder',.85)
  end end
 end
end
return M
