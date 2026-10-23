-- Legendary Lavender: five source buildings, one quiet memorial-town family.
-- Static batched geometry only. No events, collision, tower, terrain or settings.
local V=...
local M={REVISION='legendary-lavender-architecture-15'}
local abs,min,max=math.abs,math.min,math.max
local function arch(u,b,spring,peak,w)
 local points={};local l=u-w/2
 for i=0,10 do
  local f=i/10;local t=1-abs(f*2-1)
  -- Two opposed circular arcs meet at the crown, giving a true pointed arch.
  points[#points+1]={l+w*f,spring+(peak-spring)*math.sqrt(t*(4-t)/3)}
 end
 return {u=u,w=w,b=b,spring=spring,t=peak,points=points}
end
local function topAt(o,x)
 local p=o.points
 for i=1,#p-1 do
  if x<=p[i+1][1]+.0001 then
   local a,b=p[i],p[i+1];return a[2]+(b[2]-a[2])*(x-a[1])/(b[1]-a[1])
  end
 end
 return p[#p][2]
end
function M.model(s)
 if s.map~='LAVENDER_TOWN' then return nil end
 local home=s.kind=='house' or s.kind=='scenery_house'
 local center,mart=s.kind=='center',s.kind=='mart'
 if not(home or center or mart)then return nil end
 local x0,x1,z0,z1=s.x0,s.x1,s.z0,s.z1
 local W,D=x1-x0,z1-z0;local cx=(x0+x1)/2
 if W<25 or D<14 then return nil end
 local fuji=s.destination=='MR_FUJIS_HOUSE'
 local rater=s.destination=='NAME_RATERS_HOUSE'
 local H=home and (fuji and 32 or rater and 36 or 34) or center and 32 or 31
 local rise=home and min(fuji and 18 or rater and 23 or 21,W*.36) or center and 14 or 12
 local wall=fuji and 'lvPlaster' or rater and 'lvStone' or home and 'lvMauve' or center and 'lvPlaster' or 'lvMauve'
 local G=V.require('CityMesh').new(s.uv)
 local face,box,beam=G.face,G.box,G.beam
 local doors=s.doors or {}
 local function surface(a,b,c,d,mat,tone,glow)
  -- Every primitive carries stable material identity through the existing mesher.
  face(a,b,c,d,mat,tone,glow)
 end
 local function lantern(p,block,u,y)
  block(u-.65,y-1,u+.65,y+5,.16,.5,'lvTimber',.9)
  beam(p(u,y+4,.5),p(u,y+4,2.2),.30,'dark',.95)
  beam(p(u,y+2.7,.5),p(u,y+4,1.75),.22,'dark',.9)
  local l,r,b,t=u-.75,u+.75,y-1,y+2.6
  block(l-.22,b-.35,r+.22,b,.65,2.5,'dark',.95)
  block(l-.33,t,r+.33,t+.42,.55,2.65,'lvSlate',.9)
  local aa,bb,cc,dd=p(l,b+.1,2.3),p(r,b+.1,2.3),p(r,t-.1,2.3),p(l,t-.1,2.3)
  surface(aa,bb,cc,dd,'glass',1,true)
  -- Glazed returns make the lantern readable when viewed along the wall.
  for _,a in ipairs({l,r})do
   surface(p(a,b+.1,.85),p(a,b+.1,2.3),p(a,t-.1,2.3),p(a,t-.1,.85),'glass',.9,true)
   block(a-.10,b,a+.10,t,.65,2.5,'dark',.85)
  end
  block(u-.08,b,u+.08,t,2.33,2.52,'dark',.9)
 end
 local function elevation(side,low,high,plane,gable)
  local axis=(side=='front' or side=='back')and 3 or 1
  local sign=(side=='front' or side=='east')and 1 or -1
  local function p(u,y,n)return axis==3 and {u,y,plane+sign*(n or 0)} or {plane+sign*(n or 0),y,u}end
  local flip=(axis==1 and sign==1)or(axis==3 and sign==-1)
  local function panel(a,b,c,d,n,mat,tone,glow)
   if c-a<.0001 or max(d-b,0)<.0001 then return end
   local aa,bb,cc,dd=p(a,b,n),p(c,b,n),p(c,d,n),p(a,d,n)
   if flip then aa,bb,cc,dd=dd,cc,bb,aa end
   surface(aa,bb,cc,dd,mat,tone,glow)
  end
  local function slope(a,b,c,d,e,f,n,mat,tone)
   if c-a<.0001 or max(e-b,f-d)<.0001 then return end
   local aa,bb,cc,dd=p(a,b,n),p(c,d,n),p(c,f,n),p(a,e,n)
   if flip then aa,bb,cc,dd=dd,cc,bb,aa end
   surface(aa,bb,cc,dd,mat,tone)
  end
  local function block(a,b,c,d,n0,n1,mat,tone)
   if axis==3 then box(a,b,plane+min(sign*n0,sign*n1),c,d,plane+max(sign*n0,sign*n1),mat,tone)
   else box(plane+min(sign*n0,sign*n1),b,a,plane+max(sign*n0,sign*n1),d,c,mat,tone)end
  end
  local mid=(low+high)/2
  local openings={};local groundDoors={}
  for _,d in ipairs(doors)do if (d.side or 'front')==side then
   local u=d.u or d.x;local w=d.w or 14
   if u and u-w/2>=low and u+w/2<=high then
    local o=arch(u,0,24,29,w);o.door=true
    openings[#openings+1]=o;groundDoors[#groundDoors+1]=o
   end
  end end
  -- Windows occupy only whole uninterrupted bays. Nothing straddles a warp.
  local spans={{low+4,high-4}}
  for _,o in ipairs(groundDoors)do
   local next={};local l,r=o.u-o.w/2-3.2,o.u+o.w/2+3.2
   for _,v in ipairs(spans)do
    if l>v[1]then next[#next+1]={v[1],min(v[2],l)}end
    if r<v[2]then next[#next+1]={max(v[1],r),v[2]}end
   end;spans=next
  end
  for _,v in ipairs(spans)do
   local span=v[2]-v[1]
   if span>=7 then
    local count=max(1,math.floor(span/(mart and 23 or 19)))
    for j=1,count do
     local width=min(mart and 19 or fuji and 13.5 or rater and 10.5 or 12,span/count-2)
     local o=arch(v[1]+span*(j-.5)/count,mart and 8 or 10,mart and 21 or 22,27,width)
     o.shop=mart and side=='front';openings[#openings+1]=o
    end
   end
  end
  if gable then
   local o=arch(mid,H+3,H+8,H+13,8.4);o.attic=true;openings[#openings+1]=o
  end
  local cuts={low,mid,high}
  for _,o in ipairs(openings)do for _,v in ipairs(o.points)do cuts[#cuts+1]=v[1]end end
  table.sort(cuts)
  local function wallTop(u)return H+(gable and rise*(1-abs((u-mid)/((high-low)/2)))or 0)end
  local function wallStrip(a,c,b,d,e,f)
   -- Split once at the stone plinth and timber floor line. Main plaster is
   -- a continuous surface with shader grain, never hundreds of little stones.
   local bands={0,6,H, H+rise+.1}
   for k=1,#bands-1 do
    local bb,dd=max(b,bands[k]),max(d,bands[k])
    local ee,ff=min(e,bands[k+1]),min(f,bands[k+1])
    if ee>=bb and ff>=dd and max(ee-bb,ff-dd)>.0001 then
     slope(a,bb,c,dd,ee,ff,0,k==1 and 'lvStone' or wall,.97)
    end
   end
  end
  table.sort(openings,function(a,b)return a.b<b.b end)
  for i=1,#cuts-1 do
   local a,c=cuts[i],cuts[i+1];local u=(a+c)/2
   if c-a>.0001 then
    local b,d=0,0
    for _,o in ipairs(openings)do if u>o.u-o.w/2 and u<o.u+o.w/2 then
     wallStrip(a,c,b,d,o.b,o.b);b,d=topAt(o,a),topAt(o,c)
    end end
    wallStrip(a,c,b,d,wallTop(a),wallTop(c))
   end
  end
  -- Raised foundation coping is clipped around actual ground-level doors.
  local segments={{low,high}}
  for _,o in ipairs(groundDoors)do
   local t={};for _,r in ipairs(segments)do
    if o.u-o.w/2>r[1]then t[#t+1]={r[1],min(r[2],o.u-o.w/2)}end
    if o.u+o.w/2<r[2]then t[#t+1]={max(r[1],o.u+o.w/2),r[2]}end
   end;segments=t
  end
  for _,v in ipairs(segments)do block(v[1],5.7,v[2],6.4,.03,.55,'lvStone',1.10)end
  -- Articulated corners with alternating quoin lengths. No expanded buttresses.
  for _,u in ipairs({low+.6,high-.6})do
   block(u-.55,6.4,u+.55,H,.02,.52,'lvTimber',.92)
   for y=0,5,2 do block(max(low,u-.7),y,min(high,u+.7),y+1.75,.04,.62,'lvStone',1.05)end
  end
  block(low,H-1.2,high,H,.03,.70,'lvTimber',1)
  block(low,H-1.75,high,H-1.3,.05,.46,'lvStone',1.06)
  for _,o in ipairs(openings)do
   local l,r,b=o.u-o.w/2,o.u+o.w/2,o.b
   -- Actual inset panes and portal; the wall was carved to the exact arch.
   block(l-.58,b,l+.30,o.spring,-.78,.70,'lvStone',1.12)
   block(r-.30,b,r+.58,o.spring,-.78,.70,'lvStone',1.12)
   for i=1,#o.points-1 do
    local a,c=o.points[i],o.points[i+1]
    -- Inner arch reveal then deep stone voussoirs with small physical gaps.
    surface(p(a[1],a[2],-.78),p(c[1],c[2],-.78),p(c[1],c[2],.63),p(a[1],a[2],.63),'lvStone',.83)
    local normal=axis==1 and .55 or .65
    beam(p(a[1],a[2]+.12,normal),p(c[1],c[2]+.12,normal),.83,'lvStone',1.10)
   end
   if o.door then
    panel(l+.31,.15,r-.31,23.65,-.67,'lvWalnut',fuji and 1.14 or .96)
    for u=l+1.4,r-.5,2.6 do block(u-.06,.3,u+.06,23.5,-.65,-.49,'lvTimber',.85)end
    for _,yy in ipairs({2.6,11.2,21})do block(l+.65,yy,r-.65,yy+.5,-.44,-.08,'lvWalnut',1.17)end
    for _,u in ipairs({l+1,r-1})do block(u-.24,2.8,u+.24,21.5,-.43,-.20,'lvWalnut',1.18)end
    -- Iron hinges, small brass escutcheon and pull; door remains on warp axis.
    for _,yy in ipairs({6,18})do
     block(l+.65,yy,r-3,yy+.42,-.06,.11,'dark',.8)
     block(l+.65,yy-.25,l+1.25,yy+.7,-.08,.15,'dark',.95)
    end
    block(r-2.15,10,r-1.35,12.5,-.1,.16,'gold',.75)
    block(r-1.95,10.5,r-1.55,12,.2,.53,'dark',.98)
    if center then
     -- Heritage clinic: glazed double leaves over a solid lower kick plate.
     -- Proud of the timber substrate by .9; never coplanar with its panels.
     for _,sg in ipairs({-1,1})do
      local a=sg<0 and l+.85 or o.u+.45
      local c=sg<0 and o.u-.45 or r-.85
      panel(a,5.2,c,22.2,.82,'glass',.88,true)
      block(a-.18,4.9,c+.18,5.3,.78,1.04,'lvTimber',1)
      block(a-.18,22.1,c+.18,22.55,.78,1.04,'lvTimber',1)
      block(a-.18,5.3,a+.15,22.1,.78,1.04,'lvTimber',1)
      block(c-.15,5.3,c+.18,22.1,.78,1.04,'lvTimber',1)
      block(o.u+sg*1.4-.13,9,o.u+sg*1.4+.13,13,1.05,1.38,'gold',.87)
     end
     block(o.u-.22,.3,o.u+.22,23.5,.60,1.08,'lvTimber',1)
    end
    block(l+.35,23.65,r-.35,24.25,-.50,.31,'lvTimber',1)
    for i=1,#o.points-1 do local a,c=o.points[i],o.points[i+1]
     slope(a[1],24,c[1],24,a[2],c[2],-.70,'glass',1)
     -- Tag glass explicitly for the same day/night lighting as all town windows.
     local q=G.out[#G.out];q.referenceGlass=true;q.shade=65
    end
    beam(p(o.u,24.25,-.37),p(o.u,28.8,-.37),.27,'lvTimber',1)
    for _,sg in ipairs({-1,1})do beam(p(o.u,24.3,-.35),p(o.u+sg*o.w*.33,26,-.35),.24,'lvTimber',.95)end
    -- Flush threshold: no new raised walking surface or steps into the path.
    block(l-.4,0,r+.4,.30,-.65,.85,'lvStone',1.06)
    for _,u in ipairs({l-1.6,r+1.6})do
     if u>low+1.2 and u<high-1.2 then lantern(p,block,u,18)end
    end
   else
    for i=1,#o.points-1 do local a,c=o.points[i],o.points[i+1]
     slope(a[1],b,c[1],b,a[2],c[2],-.82,'glass',.92)
     local q=G.out[#G.out];q.referenceGlass=true;q.shade=64+(fuji and 1 or .85)
    end
    block(l-.65,b-.65,r+.65,b+.18,-.75,axis==1 and .82 or 1.15,'lvStone',1.13)
    block(o.u-.18,b,o.u+.18,o.t-.3,-.72,.24,'lvTimber',.94)
    block(l+.3,o.spring-2.8,r-.3,o.spring-2.45,-.72,.34,'lvTimber',1)
    for _,sg in ipairs({-1,1})do
     beam(p(o.u,o.spring-2.5,-.18),p(o.u+sg*o.w*.27,o.spring+.3,-.18),.22,'lvTimber',.94)
    end
    if not o.attic and not mart then
     -- Slender leaded diamonds inside each pane, well behind the stone frame.
     for _,sg in ipairs({-1,1})do
      local u=o.u+sg*o.w*.245;local rr=min(1.45,o.w*.12);local yy=(b+o.spring-2.8)/2
      local pts={{u-rr,yy},{u,yy+2.6},{u+rr,yy},{u,yy-2.6},{u-rr,yy}}
      for j=1,4 do beam(p(pts[j][1],pts[j][2],-.28),p(pts[j+1][1],pts[j+1][2],-.28),.15,'lvTimber',1)end
     end
    end
    if o.shop then
     -- Recognizable retail display in the lower half of the recessed window.
     for y=10,15,5 do
      block(l+.7,y,r-.7,y+.35,-.62,-.08,'lvWalnut',1.1)
      for u=l+1.8,r-1.3,3.2 do
       local mat=(math.floor(u*3+y)%3)==0 and 'red' or (math.floor(u*3+y)%3)==1 and 'blue' or 'green'
       block(u-.65,y+.38,u+.65,y+2.35,-.60,-.16,mat,.9)
       block(u-.47,y+1,u+.47,y+1.4,-.14,-.05,'white',1)
      end
     end
    end
   end
  end
  if gable then
   -- The roof structure visibly ties the gable to the building below it.
   beam(p(low-.35,H,.63),p(mid,H+rise,.63),1.10,'lvTimber',1.05)
   beam(p(mid,H+rise,.63),p(high+.35,H,.63),1.10,'lvTimber',1.05)
   block(mid-.3,H+13.8,mid+.3,H+rise-.4,.05,.65,'lvTimber',1)
   for _,sg in ipairs({-1,1})do
    beam(p(mid+sg*6,H+1,.43),p(mid+sg*(high-low)*.26,H+rise*.47,.43),.65,'lvTimber',1)
    -- Short carved brackets under the bargeboard, kept on the upper facade.
    for t=.23,.78,.18 do
     local u=mid+sg*(high-low)*.5*t;local y=H+rise*(1-t)
     beam(p(u,y-.35,.57),p(u,y-1.9,.57),.36,'lvTimber',.92)
    end
   end
  else
   -- Regular cornice brackets add depth on side elevations and civic facades.
   for u=low+4,high-3,8 do
    block(u-.28,H-3,u+.28,H-1.25,.22,axis==1 and .80 or 1.1,'lvTimber',.95)
   end
  end
  return openings,p,block,panel
 end
 local front,p,block,panel=elevation('front',x0,x1,z1,home)
 elevation('back',x0,x1,z0,home)
 elevation('west',z0,z1,x0,false);elevation('east',z0,z1,x1,false)
 -- Gabled houses and civic hipped roofs share slate, but distinct silhouettes.
 local over=.75;local rz0,rz1=z0-over,z1+over
 box(x0-over,H-.32,rz0,x1+over,H-.04,rz1,'lvTimber',.84)
 local function roofFace(poly)
  -- Broad continuous underlay, shallow staggered slate sheets on top. The
  -- sheets are batched faces rather than individual six-sided stone objects.
  local function clip(points,axis,value,above)
   local out={}
   for i,a in ipairs(points)do
    local b=points[i%#points+1]
    local ina=above and a[axis]>=value or not above and a[axis]<=value
    local inb=above and b[axis]>=value or not above and b[axis]<=value
    if ina then out[#out+1]=a end
    if ina~=inb then
     local t=(value-a[axis])/(b[axis]-a[axis]);local p={}
     for k=1,3 do p[k]=a[k]+(b[k]-a[k])*t end;out[#out+1]=p
    end
   end
   return out
  end
  local function polygon(points,lift,tone)
   for i=2,#points-1 do
    local a,b,c=points[1],points[i],points[i+1]
    local area=(b[1]-a[1])*(c[3]-a[3])-(b[3]-a[3])*(c[1]-a[1])
    if abs(area)>.0001 then
     local aa,bb,cc={a[1],a[2]+lift,a[3]},{b[1],b[2]+lift,b[3]},{c[1],c[2]+lift,c[3]}
     surface(aa,bb,cc,cc,'lvSlate',tone)
    end
   end
  end
  polygon(poly,0,.70)
  for x=x0-over,x1+over-.001,3.4 do
   local row=math.floor((x-x0+over)/3.4);local offset=row%2*2.5
   for z=rz0-offset,rz1-.001,5 do
    local p=clip(poly,1,x,true);p=clip(p,1,min(x+3.31,x1+over),false)
    p=clip(p,3,max(z,rz0),true);p=clip(p,3,min(z+4.9,rz1),false)
    if #p>=3 then
     polygon(p,.18,.94+((row*3+math.floor((z-rz0)/5)*7)%7)*.014)
     local bottom=1e9;for _,v in ipairs(p)do bottom=min(bottom,v[2])end
     for i,a in ipairs(p)do local b=p[i%#p+1]
      if abs(a[2]-bottom)<.0001 and abs(b[2]-bottom)<.0001 and abs(a[1]-b[1])+abs(a[3]-b[3])>.001 then
       surface({a[1],a[2]+.01,a[3]},{b[1],b[2]+.01,b[3]},{b[1],b[2]+.18,b[3]},{a[1],a[2]+.18,a[3]},'lvSlate',.82)
      end
     end
    end
   end
  end
 end
 local function roofPoint(side,t,z,lift)
  local edge=side<0 and x0-over or x1+over
  local fall=t
  if not home then fall=max(t,1-min(z-rz0,rz1-z)/max(1,D*.24))end
  return {cx+(edge-cx)*t,H+rise*(1-fall)+(lift or 0),z}
 end
 if home then
  for _,side in ipairs({-1,1})do
   local a,b,c,d=roofPoint(side,0,rz0),roofPoint(side,1,rz0),roofPoint(side,1,rz1),roofPoint(side,0,rz1)
   if side==1 then a,b,c,d=d,c,b,a end
   roofFace({a,b,c,d})
   local edge=side<0 and x0-over or x1+over
   box(edge-.2,H-.55,rz0,edge+.2,H+.2,rz1,'lvTimber',.95)
  end
 else
  -- Four continuous hip planes, partitioned at the ridge ends; no overlapping
  -- roof patches that could flash at shallow camera angles.
  local a,b=z0+D*.24,z1-D*.24
  for _,side in ipairs({-1,1})do
   local x=side<0 and x0-over or x1+over
   roofFace({{x,H,rz0},{x,H,rz1},{cx,H+rise,b},{cx,H+rise,a}})
  end
  roofFace({{x0-over,H,rz0},{cx,H+rise,a},{x1+over,H,rz0}})
  roofFace({{x0-over,H,rz1},{x1+over,H,rz1},{cx,H+rise,b}})
  for _,z in ipairs({rz0,rz1})do box(x0-over,H-.45,z-.16,x1+over,H+.15,z+.16,'lvTimber',1)end
 end
 -- Slate ridge cap: one continuous pair, not a chain of tiny overlapping solids.
 local cap0=home and rz0 or z0+D*.24;local cap1=home and rz1 or z1-D*.24
 surface({cx-.55,H+rise-.23,cap0},{cx,H+rise+.35,cap0},{cx,H+rise+.35,cap1},{cx-.55,H+rise-.23,cap1},'lvSlate',1.1)
 surface({cx,H+rise+.35,cap0},{cx+.55,H+rise-.23,cap0},{cx+.55,H+rise-.23,cap1},{cx,H+rise+.35,cap1},'lvSlate',.93)
 if home then
  local chx=cx-W*.25;local chz=z0+D*.34;local foot=H+rise*.43
  box(chx-1.7,foot,chz-1.7,chx+1.7,H+rise+3.2,chz+1.7,'lvStone',.93)
  box(chx-2.15,H+rise+2.3,chz-2.15,chx+2.15,H+rise+3.3,chz+2.15,'lvStone',1.1)
  box(chx-1.15,H+rise+3.31,chz-1.15,chx+1.15,H+rise+3.5,chz+1.15,'dark',.6)
 else
  -- Restrained red/blue identity panels on the slate civic roofline.
  local name=center and 'CENTER' or 'MART';local accent=center and 'red' or 'navy'
  local sw=center and 26 or 24;local yy=H-1
  block(cx-sw/2-.65,yy-.6,cx+sw/2+.65,yy+7.6,.35,1.35,'lvStone',1.13)
  block(cx-sw/2,yy,cx+sw/2,yy+7,1.38,1.7,accent,.9)
  G.text(name,cx,yy+1.45,z1+1.82,center and .9 or 1.03,'white')
  local K=V.require('KantoArchitectureKit').new(s)
  local Emblems=V.require('KantoEmblems')
  if center then
   Emblems.center(K,cx,H+15,z1+1.9,min(6.6,W*.11),'lvStone')
   for _,q in ipairs(K.G.out)do G.out[#G.out+1]=q end
  else
   Emblems.mart(K,cx,H+15,z1+1.9,min(6.4,W*.11),'navy','lvStone')
   for _,q in ipairs(K.G.out)do G.out[#G.out+1]=q end
   -- Narrow blue canopy with sculpted brackets, comfortably above head height.
   for _,o in ipairs(front)do if o.shop then
    block(o.u-o.w/2-.5,27.9,o.u+o.w/2+.5,28.6,.15,2.15,'navy',.91)
    block(o.u-o.w/2-.5,28.6,o.u+o.w/2+.5,29,.15,2.15,'lvStone',1.08)
   end end
  end
 end
 -- One house identity detail per frontage; no added beds in the walkable lawn.
 if home then
  local door=doors[1];local u=door and(door.u or door.x)
  if u and (door.side or 'front')=='front' then
   local sign=fuji and 'FUJI' or rater and 'NAMES' or nil
   if sign then
    local width=sign=='FUJI' and 10.5 or 14
    block(u-width/2-.4,30,u+width/2+.4,33.2,.75,1.07,'lvTimber',.9)
    G.text(sign,u,30.5,z1+1.2,.48,'white')
   end
  end
  if fuji then
   -- A single warm herb box tucked under an existing window, inside the wall
   -- margin. Fuji's welcoming home is distinct from the quieter memorial houses.
   for _,o in ipairs(front)do if not o.door and not o.attic then
    local half=min(4,o.w*.4)
    block(o.u-half,4,o.u+half,6,.20,1.55,'lvWalnut',1.07)
    block(o.u-half+.3,6,o.u+half-.3,6.18,.45,1.25,'dark',.7)
    for dx=-half+.8,half-.4,1.6 do
     local xx=o.u+dx
     beam({xx,6,z1+.9},{xx+.18,8,z1+.85},.13,'wood',.8)
     surface({xx-.65,7,z1+.75},{xx,7.6,z1+1.25},{xx+.55,7.25,z1+.75},{xx,6.85,z1+.52},'leaf',.9)
    end
    break
   end end
  end
 end
 -- Rain chains / pipes: fixed to rear wall, no new collision outside the shell.
 for _,x in ipairs({x0+.7,x1-.7})do
  box(x-.17,1.6,z0-.46,x+.17,H-.4,z0-.12,'dark',.87)
  for y=6,H-2,9 do box(x-.30,y,z0-.56,x+.30,y+.35,z0-.06,'lvTimber',.98)end
 end
 return G.out
end
return M
