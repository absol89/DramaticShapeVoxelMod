local G,Models=...
local M={}
-- Older plans (and TEST25 caches) carry no variant; map the old seed rotation.
local legacyChristmas={[0]='snowman','candy','minitree','wreathpost','gifts'}
function M.build(item,options)
 local g=G.new();local holiday=options.holiday;local pal=item.palette;local p=Models.palette(pal)
 local twinkle=true -- Animation is controlled at draw time, without rebuilding scenery.
 local rich=options.density=='extravagant'
 -- spans: {{a,b,y},...} trim lines at the facade's real height per stretch.
 -- spot: wreath centre {x,y}, or false when every spot would cover a sign.
 local function trim(x0,x1,y,z,depthAt,canopy,spans,spot)
  local at=depthAt or function()return z end
  spans=spans or {{x0,x1,y}}
  local main=spans[1]
  for _,sp in ipairs(spans)do
   if sp[3]>main[3]+.5 or(math.abs(sp[3]-main[3])<=.5 and sp[2]-sp[1]>main[2]-main[1])then main=sp end
  end
  local wx,wy=(main[1]+main[2])/2,main[3]
  if spot then wx,wy=spot[1],spot[2]end
  for si,sp in ipairs(spans)do
   local a0,a1,yy=sp[1],sp[2],sp[3]
   if holiday=='christmas'then
    local pieces=math.max(1,math.ceil((a1-a0)/35))
    for i=0,pieces-1 do
     local a,b=a0+(a1-a0)*i/pieces,a0+(a1-a0)*(i+1)/pieces
     Models.garland(g,{a,yy,at(a)},{b,yy,at(b)},1.5,pal,twinkle,i+si*7,at)
    end
   elseif holiday=='halloween'then
    Models.bunting(g,{a0,yy,at(a0)},{a1,yy,at(a1)},holiday,at)
    -- A string of tiny flickering lanterns under the bunting.
    local n=math.max(2,math.floor((a1-a0)/9))
    for i=1,n do local x=a0+(a1-a0)*i/(n+1);local zz=at(x)+.6
     local sag=math.sin(i/(n+1)*math.pi)*1.6
     G.bulb(g,x,yy-1.2-sag,zz,.38,item.spectral and(i%2==0 and 'violetGlow'or 'spirit')or(i%2==0 and 'warm'or 'orange'),true)
    end
   elseif holiday=='harvest'then Models.bunting(g,{a0,yy,at(a0)},{a1,yy,at(a1)},'harvest',at)
   elseif holiday=='easter'then
    local colors={'pink','mint','lilac','egg'}
    for i=0,math.floor((a1-a0)/5)do local x=a0+i*5;local zz=at(x)
     G.tube(g,{x,yy,zz},{x,yy-2.2,zz},.07,'gold',3);Models.egg(g,x,yy-5,zz,1.05,colors[i%4+1],i)
    end
   else Models.bunting(g,{a0,yy,at(a0)},{a1,yy,at(a1)},'july',at)end
  end
  if holiday=='christmas'then
   if canopy then
    -- Hang smaller wreaths below the projecting marquee, clear of its lettering.
    for _,f in ipairs({.22,.78})do
     local x=x0+(x1-x0)*f;local zz=math.max(at(x-3.8),at(x),at(x+3.8))+.45
     G.tube(g,{x,y-.6,zz},{x,y-3.5,zz},.075,'gold',4)
     Models.wreath(g,x,y-6.0,zz,2.6,pal,twinkle)
    end
   elseif spot~=false then
    local zz=math.max(at(wx-6.5),at(wx),at(wx+6.5))+.55
    Models.wreath(g,wx,wy-8,zz,4.7,pal,twinkle)
   end
  elseif holiday=='halloween'then
   local f,l=spans[1],spans[#spans]
   -- TEST147: pin both ends of every string to the wall, and tuck the webs
   -- into the corners ABOVE the string so they read as attached, not hung.
   for _,sp in ipairs(spans)do
    for _,ex in ipairs({sp[1],sp[2]})do local zz=at(ex)
     G.tube(g,{ex,sp[3]+.25,zz-2.0},{ex,sp[3]+.25,zz+.45},.16,'iron',4)
     G.sphere(g,ex,sp[3]+.25,zz+.5,.24,.24,.12,'iron',5,3)
    end
   end
   -- Indoors the wall continues above the string; outside the eave is right
   -- above it, so the webs sit on the wall just below the string instead.
   local up=item.kind=='indoor_trim'and 2.6 or -3.8
   Models.web(g,f[1]+3.6,f[3]+up,math.max(at(f[1]),at(f[1]+3.6),at(f[1]+7.2))+.2,3.4)
   Models.web(g,l[2]-3.6,l[3]+up,math.max(at(l[2]),at(l[2]-3.6),at(l[2]-7.2))+.2,3.4)
  elseif holiday=='harvest'and spot~=false then
   -- Autumn wreath of leaves.
   local x=wx;local yy=wy;local zz=math.max(at(x-5),at(x),at(x+5))+.5;local r=3.6
   Models.ring(g,x,yy-6.5,zz,r,.55,'deadwood',16,true,4)
   local mats={'leafRed','leafGold','leafOrange','copper'}
   for i=0,19 do local a=i*2*math.pi/20;local px,py=x+math.cos(a)*r,yy-6.5+math.sin(a)*r
    G.quad(g,{px,py,zz+.3},{px+math.cos(a+.8)*1.6,py+math.sin(a+.8)*1.6,zz+.5},{px+math.cos(a+1.4)*1.2,py+math.sin(a+1.4)*1.2,zz+.6},{px+math.cos(a+.3)*.4,py+math.sin(a+.3)*.4,zz+.4},mats[i%4+1])
   end
   Models.bow(g,x,yy-6.5-r,zz+.8,1.1,'copper')
  end
 end
 if item.kind=='centerpiece'then
  local scale=item.indoor and .46 or math.min(1.5,item.radius/18)
  if holiday=='christmas'then
   g=Models.tree{height=item.height,radius=item.radius,palette=pal,rich=rich,twinkle=twinkle,seed=item.seed}
   if not item.indoor then
    local r=item.radius
    -- Ornamental rail is open toward the main viewing side.
    for i=0,12 do local a=(i+2)*math.pi/8
     if i<11 then local b=(i+3)*math.pi/8
      G.tube(g,{math.cos(a)*(r+2),4,math.sin(a)*(r+2)},{math.cos(b)*(r+2),4,math.sin(b)*(r+2)},.16,'gold',4)
     end
     G.tube(g,{math.cos(a)*(r+2),.1,math.sin(a)*(r+2)},{math.cos(a)*(r+2),5,math.sin(a)*(r+2)},.26,'gold',5)
    end
    -- Two glowing reindeer keep watch at the open side.
    if item.radius>=20 then
     Models.reindeer(g,-r*.55,r+5,.75,.5)
     Models.reindeer(g,r*.55,r+5,.75,-.5)
    end
   end
  elseif holiday=='halloween'then
   if item.indoor then
    Models.pumpkin(g,-2.4,0,0,2.2,true,1);Models.pumpkin(g,1.8,0,1.2,1.6,true,2);Models.pumpkin(g,.2,0,-2.2,1.3,nil,3)
    Models.candle(g,3.6,0,-1.2,1.1,item.spectral and 'violetGlow'or nil);Models.candle(g,-4.4,0,1.8,.8,item.spectral and 'violetGlow'or nil)
    -- TEST147: no free-floating web over the floor; a small bale grounds the
    -- group against the wall behind it instead.
    Models.hay(g,0,0,-4.4,6.0,2.6,2.8,item.seed or 1);Models.pumpkin(g,1.2,2.6,-4.4,1.1,true,4)
   else
    g=Models.hauntedPlaza{scale=math.min(1.5,item.radius/21),spectral=item.spectral,seed=item.seed}
   end
  elseif holiday=='harvest'then
   if item.indoor then
    Models.appleBasket(g,-2,0,0,.9);Models.gourds(g,2.5,1,1.1,2);Models.pumpkin(g,0,0,-3,1.8,nil,1)
    Models.cornShock(g,-5,-3,.45,4)
   else g=Models.harvestPlaza{scale=math.min(1.5,item.radius/21)}end
  elseif holiday=='easter'then g=G.translate(Models.easter{},0,0,0,0,item.indoor and .45 or scale)
  else g=G.translate(Models.july{},0,0,0,0,item.indoor and .45 or math.min(1.4,item.radius/18))end
 elseif item.kind=='facade'then
  local b=item.building;local x0,x1=b.x0-item.x,b.x1-item.x
  local y=(b.trimY or b.eave-.6)-item.y
  local function at(x)
   local profile=b.frontProfile;local wx=x+item.x
   if not profile or #profile==0 then return b.z1-item.z+1.8 end
   local z=profile[1].z
   if wx>=profile[#profile].x then z=profile[#profile].z
   else for i=2,#profile do local a,c=profile[i-1],profile[i]
    if wx<=c.x then z=math.max(a.z,c.z);break end
   end end
   return z-item.z+1.8
  end
  -- Follow the real front height: stepped and monitor-roof facades are lower
  -- at their wings, where a single trim line would hang in the air.
  local spans
  local prof=b.frontProfile
  -- TEST161: gable / gambrel / barn fronts. Their front top climbs to a
  -- peak, so the "eave" is far above the low corners and a straight trim
  -- there hangs in the sky. Hang the garland at the low eave instead and
  -- outline the gable itself with a light string that follows its slope.
  local gable
  local fi,la
  for i,pt in ipairs(prof or {})do if pt.ftop then fi=fi or i;la=i end end
  if fi and la and la-fi>=2 then
   local lo,hi=math.huge,-math.huge
   for _,pt in ipairs(prof)do if pt.ftop then lo=math.min(lo,pt.ftop);hi=math.max(hi,pt.ftop)end end
   local first,last=prof[fi].ftop,prof[la].ftop
   local peak=0;for i,pt in ipairs(prof)do if pt.ftop==hi then peak=i end end
   if hi-lo>6 and peak>fi and peak<la and math.abs(first-last)<6 then
    gable={lo=lo,hi=hi}
    y=math.min(y,lo-item.y-1.2)
   end
  end
  if prof and #prof>1 and prof[1].top and not gable then
   spans={};local cur
   for _,pt in ipairs(prof)do
    local lx=math.max(x0,math.min(x1,pt.x-item.x))
    local lv=math.min(y,pt.top-item.y-1.2)
    if lv<y-18 then cur=nil
    elseif cur and math.abs(lv-cur[3])<1.2 then cur[2]=lx;cur[3]=math.min(cur[3],lv)
    else cur={lx,lx,lv};spans[#spans+1]=cur end
   end
   for i=#spans,1,-1 do if spans[i][2]-spans[i][1]<4 then table.remove(spans,i)end end
   if #spans==0 then spans=nil end
  end
  -- The wreath avoids emblems, plaques and signs standing proud of the wall.
  local spot
  if b.badges then
   local main
   for _,sp in ipairs(spans or {{x0,x1,y}})do
    if not main or sp[3]>main[3]+.5 or(math.abs(sp[3]-main[3])<=.5 and sp[2]-sp[1]>main[2]-main[1])then main=sp end
   end
   spot=false
   for _,f in ipairs({.5,.36,.64,.25,.75})do
    local wx=main[1]+(main[2]-main[1])*f;local wy=main[3]-8
    local free=wx-6>=main[1]-1 and wx+6<=main[2]+1
    for _,bd in ipairs(b.badges)do
     if free and bd.x1-item.x>wx-6.5 and bd.x0-item.x<wx+6.5 and bd.y1-item.y>wy-6.5 and bd.y0-item.y<wy+6.5 then free=false end
    end
    if free then spot={wx,main[3]};break end
   end
   -- Main front blocked by a sign or emblem: try the middle of each wing.
   if not spot then
    for _,sp in ipairs(spans or {})do
     if sp~=main and sp[2]-sp[1]>=14 and not spot then
      local wx,wy=(sp[1]+sp[2])/2,sp[3]-8;local free=true
      for _,bd in ipairs(b.badges)do
       if bd.x1-item.x>wx-6.5 and bd.x0-item.x<wx+6.5 and bd.y1-item.y>wy-6.5 and bd.y0-item.y<wy+6.5 then free=false end
      end
      if free then spot={wx,sp[3]}end
     end
    end
   end
  end
  trim(x0,x1,y,at(0),at,b.canopy,spans,spot)
  if holiday=='christmas'then
   -- TEST76: attach strings to measured roof polygons. Wall profiles and
   -- garland clearance envelopes are not roof edges (they float at oblique
   -- views). Keep each section separate, with only a small mounting offset.
   local roof=b.roof or {}
   local left,right=math.huge,-math.huge
   for _,q in ipairs(roof)do for _,v in ipairs(q)do
    left=math.min(left,v[1]);right=math.max(right,v[1])
   end end
   local seen,edgeCounts={},{}
   local function pointKey(v)return string.format('%.3f:%.3f:%.3f',v[1],v[2],v[3])end
   -- Shared polygon edges are internal seams, not exposed mounting edges.
   for _,q in ipairs(roof)do for j=1,#q do
    local ka,kc=pointKey(q[j]),pointKey(q[j%#q+1])
    local key=ka<kc and ka..'|'..kc or kc..'|'..ka
    edgeCounts[key]=(edgeCounts[key]or 0)+1
   end end
   for _,q in ipairs(roof)do
    local front=-math.huge
    for _,v in ipairs(q)do front=math.max(front,v[3])end
    for j=1,#q do
     local a,c=q[j],q[j%#q+1]
     local dx,dy,dz=c[1]-a[1],c[2]-a[2],c[3]-a[3]
     local frontEdge=math.abs(a[3]-front)<.05 and math.abs(c[3]-front)<.05 and math.abs(dx)>.5
     local sideEdge=math.abs(dz)>.5 and
      ((math.abs(a[1]-left)<.05 and math.abs(c[1]-left)<.05)or
       (math.abs(a[1]-right)<.05 and math.abs(c[1]-right)<.05))
     if frontEdge or sideEdge then
      local ka,kc=pointKey(a),pointKey(c);local key=ka<kc and ka..'|'..kc or kc..'|'..ka
      local L=math.sqrt(dx*dx+dy*dy+dz*dz)
      if not seen[key]and edgeCounts[key]==1 and L>.5 then
       seen[key]=true
       local ox=sideEdge and (a[1]<=(left+right)/2 and -.12 or .12)or 0
       local oz=frontEdge and .12 or 0
       local aa={a[1]-item.x+ox,a[2]-item.y+.10,a[3]-item.z+oz}
       local cc={c[1]-item.x+ox,c[2]-item.y+.10,c[3]-item.z+oz}
       G.tube(g,aa,cc,.075,'black',3)
       local n=math.max(1,math.ceil(L/2.6))
       for i=1,n do local f=i/n
        G.bulb(g,aa[1]+dx*f,aa[2]+dy*f-.22,aa[3]+dz*f,.40,p[i%4+1],twinkle)
       end
      end
     end
    end
   end
   -- Snow owns exposed roof/ledge geometry once per map (not per facade).
  end
 elseif item.kind=='pumpkin_patch'then
  g=Models.pumpkinPatch{w=item.w,d=item.d,seed=item.seed,holiday=holiday,mini=item.mini}
 elseif item.kind=='sleigh'then
  -- the model runs from the sleigh's back (x=-13) to the lead pair (~x=59)
  local pairs_=item.pairs or 3
  g=Models.santaSleigh{seed=item.seed,pairs=pairs_}
  G.transformInPlace(g,-(-13+20+(pairs_-1)*15+9)/2,0,0,0)
 elseif item.kind=='inflatables'then
  local set=holiday=='christmas'and{Models.inflatableSnowman,Models.inflatableSanta,Models.inflatablePresents}
   or{Models.inflatablePumpkin,Models.inflatableGhost,Models.inflatableCat}
  local start=(item.seed or 1)%3
  for i=0,2 do local f=set[(start+i)%3+1]
   local sc=item.scale or .92
   f(g,(i-1)*21*sc/.92,((i%2)*2-1)*2.5,sc)
  end
 elseif item.kind=='nutcrackers'then
  -- TEST161: a graduated line of nutcracker guards, tallest in the middle
  local W,D=item.w or 80,item.d or 48
  local n=math.max(3,math.min(7,math.floor(W/15)));if n%2==0 then n=n-1 end
  local mid=(n+1)/2;local step=(W-14)/(n-1)
  local big=math.max(1.45,math.min(2.1,D/30))
  local seed=item.seed or 1
  for i=1,n do
   local off=math.abs(i-mid)
   local sc=big*(1-off*.24);local xx=-W/2+7+(i-1)*step
   Models.nutcracker(g,xx,-off*2.2,sc,seed+i*7,0)
  end
  -- gifts at their feet
  for i=1,n-1 do
   local xx=-W/2+7+(i-.5)*step
   Models.inflatablePresents(g,xx,D*.22,.42)
  end
 elseif item.kind=='yard'then
  -- TEST157: a full front-yard display sized to its lawn. Back row: a giant
  -- centre inflatable flanked by two big ones; front row: smaller pieces.
  local W,D=item.w or 80,item.d or 64
  local k=math.max(.85,math.min(1.45,math.min(W/80,D/64)))
  local seed=item.seed or 1
  local bx,bz,fz=W*.31,-D*.16,D*.24
  if holiday=='christmas'then
   Models.inflatableSanta(g,0,bz-2,1.55*k)
   Models.inflatableSnowman(g,-bx,bz,1.12*k)
   Models.inflatableSnowman(g,bx,bz,1.12*k)
   Models.inflatablePresents(g,-W*.19,fz,1.25*k)
   Models.reindeer(g,W*.12,fz-2,1.45*k,seed,.35)
   Models.reindeer(g,W*.27,fz+3,1.25*k,seed+1,.6)
   Models.nutcracker(g,-W*.43,fz+2,.80*k,seed);Models.nutcracker(g,W*.43,fz+3,.80*k,seed+2)
   Models.candy(g,0,0,fz+9,14*k)
   for _,sx in ipairs({-1,1})do
    local t=Models.tree{height=24*k,radius=4.6*k,palette=pal,rich=false,mini=true,twinkle=twinkle,seed=seed+sx}
    G.append(g,G.translate(t,sx*W*.46,0,bz-4,0,1))
   end
  else
   Models.inflatablePumpkin(g,0,bz-2,1.55*k)
   Models.inflatableGhost(g,-bx,bz,1.12*k)
   Models.inflatableCat(g,bx,bz,1.12*k)
   Models.tombstone(g,-W*.20,fz-2,1.25*k,.18,'round',seed)
   Models.tombstone(g,W*.20,fz-3,1.15*k,-.2,seed%2==0 and'cross'or'round',seed+1)
   Models.tombstone(g,W*.42,bz+10,1.0*k,-.4,'round',seed+2)
   for i=-1,1 do Models.pumpkin(g,i*W*.12,0,fz+7,(i==0 and 3.6 or 2.9)*k,true,seed+i+5)end
   Models.pumpkin(g,-W*.42,0,fz+3,2.7*k,true,seed+9);Models.pumpkin(g,W*.42,0,fz+5,2.4*k,true,seed+11)
  end
 elseif item.kind=='inflatable'then
  local set=holiday=='christmas'and{Models.inflatableSnowman,Models.inflatableSanta,Models.inflatablePresents}
   or{Models.inflatablePumpkin,Models.inflatableGhost,Models.inflatableCat}
  set[(item.seed or 1)%3+1](g,0,0,.9)
 elseif item.kind=='hayride'then
  g=Models.hayride{seed=item.seed,holiday=holiday}
 elseif item.kind=='indoor_trim'then trim(-item.width/2,item.width/2,item.ceiling,0,nil,nil,item.spans)
 elseif item.kind=='door_pumpkins'then
  Models.pumpkin(g,-item.side*1.2,0,0,2.35,true,item.seed)
  Models.pumpkin(g,item.side*2.0,0,1.3,1.45,item.seed%2==0,item.seed+1)
  if item.seed%3==0 then Models.candle(g,item.side*3.2,0,-.6,.7,item.spectral and 'violetGlow'or nil)end
 elseif item.kind=='door_decor'then
  if holiday=='christmas'then
   -- TEST161: every other doorway gets a pair of little nutcracker guards
   if math.floor((item.doorX or 0)/16+(item.doorZ or 0)/16)%2==0 then Models.nutcracker(g,0,0,.56,math.floor(item.doorX or item.seed),0)
   else Models.pottedPine(g,0,0,.95,pal,twinkle,item.seed)end
  elseif holiday=='harvest'then Models.cornShock(g,-item.side*.4,0,.75,item.seed);Models.pumpkin(g,item.side*2.2,0,1.7,1.4,nil,item.seed)
  elseif holiday=='easter'then Models.flowerPot(g,0,0,1.0,item.seed)
  else Models.flag(g,0,0,0,9,5,item.side*.3);G.tube(g,{0,0,0},{0,1.6,0},1.0,'blue',8,1.2)end
 elseif item.kind=='wall_skeleton'then
  Models.skeleton(g,'hang',item.scale)
  -- Two visible suspension ties attach shoulders to the measured eave.
  for _,side in ipairs({-1,1})do
   G.tube(g,{side*1.4,13.4*item.scale,1.2*item.scale},{side*1.4,item.anchorY-item.y,-1.4},.07,'rope',3)
  end
 elseif item.kind=='roof_skeleton'then
  Models.skeleton(g,'sit',item.scale)
 elseif item.kind=='lamp_skeleton'then
  Models.skeleton(g,'hug',item.scale,item.poleRadius)
 elseif item.kind=='palm_lights'then
  Models.palmLights(g,item.palm,holiday,pal,twinkle)
  return g
 elseif item.kind=='rail_garland'then
  Models.railGarland(g,item.segs,item.posts,holiday,pal,twinkle)
  return g
 elseif item.kind=='dock_garland'then
  Models.dockGarland(g,item.run,holiday,pal,twinkle)
  return g
 elseif item.kind=='lamp_decor'then
  Models.lampDecor(g,holiday,item.height or 20,item.poleRadius,pal,twinkle,item.seed)
 elseif item.kind=='street'then
  local v=item.variant
  if holiday=='christmas'then
   v=v or legacyChristmas[item.seed%5]
   if v=='snowman'then Models.snowman(g,0,0,0,item.small and .55 or .72,pal)
   elseif v=='candy'then Models.candy(g,-2,0,0,14);Models.candy(g,3,0,1,11);Models.lantern(g,-3,0,3,1.0,holiday)
   elseif v=='minitree'then
    g=Models.tree{height=item.small and 19 or 28,radius=item.small and 3.8 or 5.5,palette=pal,rich=false,mini=true,twinkle=twinkle,seed=item.seed}
   elseif v=='wreathpost'then
    G.tube(g,{0,0,0},{0,21,0},.34,'gold',6);Models.wreath(g,0,16.5,.2,3.6,pal,twinkle);Models.lantern(g,0,0,0,1.0,holiday)
   elseif v=='reindeer'then Models.reindeer(g,0,0,.62,.35)
   else
    Models.gift(g,-2,0,0,5.4,4.2,4.6,p[1],'gold',item.seed)
    Models.gift(g,2.4,0,1.8,4.0,3.2,3.6,p[2],p[1],item.seed+1)
    Models.gift(g,-1,4.4,0,3.4,2.6,3.1,p[3],'ivory',item.seed+2)
    Models.lantern(g,3,0,-2,1.0,holiday)
   end
  elseif holiday=='halloween'then
   local glow=item.spectral and 'violetGlow'or nil
   v=v or 'hay'
   if v=='graves'then
    Models.tombstone(g,-2.6,-1.0,.72,.15,'round',item.seed);Models.tombstone(g,2.8,-.4,.62,-.2,item.seed%2==0 and 'cross'or 'round',item.seed+1)
    Models.candle(g,0,0,2.2,.8,glow);Models.pumpkin(g,4.2,0,2.6,1.1,true,item.seed)
   elseif v=='cauldron'then Models.cauldron(g,0,0,.8,item.spectral and 'spirit'or 'slime');Models.pumpkin(g,4.0,0,2.2,1.2,true,item.seed)
   elseif v=='ghost'then Models.ghost(g,0,3.0+item.seed%3*.6,0,.72,0,'ghost');Models.pumpkin(g,-3.2,0,2.4,1.2,true,item.seed)
   elseif v=='totem'then
    Models.hay(g,0,0,0,6.5,3.6,4.6,item.seed)
    Models.pumpkin(g,0,3.6,0,2.3,true,item.seed);Models.pumpkin(g,0,6.95,0,1.7,true,item.seed+1);Models.pumpkin(g,0,9.4,0,1.2,true,item.seed+2)
    Models.crow(g,2.4,3.6,.6,.7,.8)
   elseif v=='scarecrow'then
    Models.scarecrow(g,0,0,-1,.42,item.seed%2==0 and 'purple'or 'green',item.seed%2==0 and 'sack'or nil)
    Models.pumpkin(g,-3.2,0,2.4,1.4,true,item.seed);Models.pumpkin(g,3.0,0,2.0,1.0,false,item.seed+1)
   elseif v=='candles'then
    for i=0,4 do local a=i*1.3;Models.candle(g,math.cos(a)*1.6,0,math.sin(a)*1.6,.6+(i%3)*.18,glow)end
    Models.pumpkin(g,0,0,-1.8,1.2,true,item.seed)
   elseif v=='pumpkins'then
    Models.pumpkin(g,-1.8,0,0,2.0,true,item.seed);Models.pumpkin(g,1.9,0,.9,1.4,true,item.seed+1);Models.pumpkin(g,.3,0,-1.9,1.1,nil,item.seed+2)
   else
    Models.hay(g,0,0,0,8.5,4.6,5.8,item.seed)
    Models.pumpkin(g,-1.8,4.6,0,1.9,true,item.seed);Models.pumpkin(g,3.4,0,2.6,1.8,true,item.seed+1)
    Models.lantern(g,-3.4,0,2.6,.7,holiday,glow,true)
   end
  elseif holiday=='harvest'then
   v=v or 'corn'
   if v=='apples'then Models.appleBasket(g,-1.5,0,0,.95);Models.appleBasket(g,2.4,.4,1.6,.75);Models.gourds(g,.2,-2.2,.9,item.seed)
   elseif v=='leaves'then Models.leafPile(g,0,0,.95,item.seed);Models.pumpkin(g,3.1,0,1.6,1.3,nil,item.seed)
   elseif v=='hayharvest'then Models.hay(g,0,0,0,8.0,4.4,5.4,item.seed);Models.gourds(g,0,4.4,.8,item.seed);Models.pumpkin(g,3.6,0,2.4,1.6,nil,item.seed);Models.lantern(g,-3.4,0,2.4,.7,holiday,nil,true)
   elseif v=='wheel'then Models.wagonWheel(g,0,-1,.85,0);Models.appleBasket(g,2.6,1.4,.7);Models.pumpkin(g,-2.4,0,1.6,1.2,nil,item.seed)
   elseif v=='gourds'then Models.gourds(g,0,0,1.4,item.seed);Models.pumpkin(g,1.8,0,-1.6,1.3,nil,item.seed)
   else Models.cornShock(g,-1.2,-.5,.95,item.seed);Models.pumpkin(g,2.6,0,2.0,1.6,nil,item.seed);Models.gourds(g,-2.8,2.4,1.1,item.seed)end
  elseif holiday=='easter'then
   v=v or 'eggs'
   if v=='flowers'then Models.flowerPot(g,-1.8,0,.9,item.seed);Models.flowerPot(g,2.2,1.0,.7,item.seed+1)
   elseif v=='basket'then
    G.tube(g,{0,0,0},{0,2.4,0},2.4,'hay',10,3.0);Models.ring(g,0,2.4,0,3.0,.22,'hay',12,false,3)
    local pts={};for i=0,8 do local a=i*math.pi/8;pts[#pts+1]={math.cos(a)*2.9,2.4+math.sin(a)*3.2,0}end;Models.chain(g,pts,.16,'hay',3)
    local colors={'pink','mint','lilac','egg'};for i=1,6 do local a=i*2.4;local r=i==1 and 0 or 1.5;Models.egg(g,math.cos(a)*r,1.6,math.sin(a)*r,.75,colors[i%4+1],i)end
    Models.bow(g,0,5.6,.1,.8,'pink')
   else
    local colors={'pink','mint','lilac'};for i=1,3 do Models.egg(g,(i-2)*3,0,(i%2)*2,1.6,colors[i],i)end
    Models.bow(g,0,6,0,1.1,'pink')
   end
  else
   v=v or 'flagpost'
   if v=='flagpair'then Models.flag(g,-1.2,0,0,10,5.2,-.3);Models.flag(g,1.4,0,.6,8.5,4.4,.4);G.tube(g,{0,0,0},{0,1.8,0},1.6,'red',10,1.9)
   elseif v=='drums'then
    for i=1,2 do local x=(i-1.5)*4.2;G.tube(g,{x,0,0},{x,3.4,0},1.7,i==1 and 'red'or 'blue',10)
     Models.ring(g,x,.4,0,1.75,.18,'gold',10,false,3);Models.ring(g,x,3.0,0,1.75,.18,'gold',10,false,3)end
    Models.flag(g,0,3.4,-.6,6,4,0)
   else
    G.tube(g,{0,0,0},{0,17,0},.22,'gold',5)
    Models.bunting(g,{-5,15,0},{5,15,0},'july')
    for i=1,3 do Models.gift(g,(i-2)*2.8,0,0,2.7,3.1,2.8,({'red','ivory','blue'})[i],'gold',i)end
   end
  end
 end
 return G.transformInPlace(g,item.x,item.y,item.z,item.yaw or 0)
end
return M
