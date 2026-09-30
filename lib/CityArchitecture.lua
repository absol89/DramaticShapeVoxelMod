local V=...
local Kit=V.require('CityMesh')
local Rules=V.require('CityBuildingRules')
local M={}
local labels={office_tower='SILPH',department_store='DEPT STORE',store_annex='DEPT',museum='MUSEUM',museum_wing='GALLERY',oak_lab='OAK LAB',research_lab='LAB',power_station='POWER',ruined_mansion='MANSION',mansion='MANSION',arcade='GAME',prize_shop='PRIZES',dojo='DOJO',bike_shop='BIKES',hotel='HOTEL',diner='DINER',daycare='DAY CARE',bill_house='BILL',school='SCHOOL',meeting_hall='HALL',underground_gate='UNDERPASS',gate='GATE',safari_gate='SAFARI',rest_house='REST',league='LEAGUE',gym='GYM'}
function M.model(s)
 local kind=s.kind;local region=Rules.region(s.map);local G=Kit.new(s.uv)
 local box,face,beam=G.box,G.face,G.beam
 local x0,x1,z0,z1=s.x0,s.x1,s.z0,s.z1
 local W,D=x1-x0,z1-z0;local cx,cz=(x0+x1)/2,(z0+z1)/2
 local gym=kind=='gym' and (Rules.gyms[s.map] or 'electric') or nil
 local floors=kind=='office_tower' and 5 or kind=='department_store' and 3 or (kind=='mansion' or kind=='hotel' or kind=='apartments' or kind=='ruined_mansion') and 2 or 1
 local H=floors*24+(kind=='league' and 20 or kind=='museum' and 14 or 8)
 local wall=region.wall;local accent=region.accent;local roof=region.roof
 if kind=='office_tower' then wall='slate';accent='mortar';roof='slate' end
 if kind=='museum' or kind=='museum_wing' or gym=='rock' then wall='stone';accent='mortar';roof='terra' end
 if kind=='research_lab' or kind=='oak_lab' then wall='white';accent='blue';roof='slate' end
 if kind=='arcade' or kind=='prize_shop' then wall='cream';accent='navy';roof='navy' end
 local luxury=s.map=='CELADON_CITY' and (kind=='arcade' or kind=='prize_shop')
 if luxury then wall='dark';accent='dark';roof='dark' end
 if kind=='dojo' or gym=='poison' then wall='cream';accent='wood';roof='slate' end
 if kind=='ruined_mansion' then wall='mortar';accent='dark';roof='terra' end
 if gym=='water' then accent='blue';roof='navy' end
 if gym=='grass' then accent='green';roof='green' end
 if gym=='psychic' then accent='navy';roof='blue' end
 if gym=='fire' then wall='stone';accent='red';roof='terra' end
 if gym=='ground' then wall='cream';accent='terra';roof='terra' end
 local function elevation(side,plane,low,high)
  local axis=(side=='west' or side=='east') and 1 or 3
  local sign=(side=='west' or side=='back') and -1 or 1
  local function p(u,y,n)return axis==3 and {u,y,plane+sign*(n or 0)} or {plane+sign*(n or 0),y,u}end
  local function panel(a,b,c,d,n,mat,t,glow)
   local aa,bb,cc,dd=p(a,b,n),p(c,b,n),p(c,d,n),p(a,d,n)
   if (axis==1 and sign==1) or (axis==3 and sign==-1)then aa,bb,cc,dd=dd,cc,bb,aa end
   face(aa,bb,cc,dd,mat,t,glow)
  end
  local function block(a,b,c,d,n0,n1,mat,t)
   if axis==3 then box(a,b,plane+math.min(sign*n0,sign*n1),c,d,plane+math.max(sign*n0,sign*n1),mat,t)
   else box(plane+math.min(sign*n0,sign*n1),b,a,plane+math.max(sign*n0,sign*n1),d,c,mat,t)end
  end
  local openings={};local groundDoors={}
  for _,d in ipairs(s.doors or {})do if (d.side or 'front')==side then
   local u=d.u or d.x;local w=math.min(d.w or 14,high-low-4)
   if u-w/2>=low and u+w/2<=high then local o={u=u,w=w,b=0,t=22,door=true};openings[#openings+1]=o;groundDoors[#groundDoors+1]=o end
  end end
  for floor=0,floors-1 do
   local n=math.max(1,math.floor((high-low)/16))
   for i=1,n do
    local u=low+(high-low)*i/(n+1);local width=math.min((kind=='office_tower' or gym=='water' or gym=='grass') and 13 or 10,(high-low)/(n+1)-3)
    local blocked=false
    if floor==0 then for _,d in ipairs(groundDoors)do if math.abs(d.u-u)<d.w/2+width/2+2 then blocked=true end end end
    if not blocked and width>2 then openings[#openings+1]={u=u,w=width,b=floor*24+9,t=floor*24+21}end
   end
  end
  if luxury then
   V.require('CasinoFacade').elevation(G,s,side,low,high,H,openings,p,panel,block)
   return
  end
  -- Split the wall around all windows and oriented entrances.
  local cuts={low,high};for _,o in ipairs(openings)do cuts[#cuts+1]=o.u-o.w/2;cuts[#cuts+1]=o.u+o.w/2 end
  table.sort(cuts)
  for j=1,#cuts-1 do local a,c=cuts[j],cuts[j+1];local mid=(a+c)/2
   if c-a>.001 then for y=0,H-.01,4 do
    local segments={{y,math.min(y+4,H)}}
    for _,o in ipairs(openings)do if mid>o.u-o.w/2 and mid<o.u+o.w/2 then
     local next={};for _,v in ipairs(segments)do
      if v[1]<o.b then next[#next+1]={v[1],math.min(v[2],o.b)}end
      if v[2]>o.t then next[#next+1]={math.max(v[1],o.t),v[2]}end
     end;segments=next
    end end
    for _,v in ipairs(segments)do if v[2]>v[1]+.001 then
     local mat=v[1]<5 and 'stone' or wall
     panel(a,v[1],c,v[2],0,mat,.96)
     if v[1]>=5 and kind~='office_tower' then block(a,v[1],c,math.min(v[2],v[1]+.12),0,.16,mat,.84)end
    end end
   end end
  end
  for _,o in ipairs(openings)do
   local l,r=o.u-o.w/2,o.u+o.w/2
   block(l-.6,o.b,l+.3,o.t+.6,-.9,.8,accent,1)
   block(r-.3,o.b,r+.6,o.t+.6,-.9,.8,accent,1)
   block(l,o.t-.2,r,o.t+.6,-.9,.8,accent,1)
   panel(l+.3,o.b+.2,r-.3,o.t-.2,-.8,'glass',.9,kind~='ruined_mansion' and (kind~='office_tower' or math.floor(o.u/7+o.b)%4~=0))
   if o.door then
    block(o.u-.2,1,o.u+.2,22,-.7,.5,'white',1)
    for _,d in ipairs({-1,1})do block(o.u+d*1.2-.12,9,o.u+d*1.2+.12,13,.55,.95,'gold',1)end
    block(l-.8,0,r+.8,.7,-.3,1.1,'stone',1)
    block(l-1,23,r+1,24.5,.1,3.5,accent,1)
    block(l-1,22.5,r+1,23,.1,3.5,'white',1)
   else
    block(l-.6,o.b-.6,r+.6,o.b+.2,-.5,1.3,'mortar',1)
    block(o.u-.18,o.b,o.u+.18,o.t,-.7,.5,'white',1)
    if kind~='office_tower' then block(l,o.b+6,r,o.b+6.3,-.7,.5,'white',1)end
    if o.b<24 and kind~='office_tower' and kind~='power_station' and kind~='ruined_mansion' and kind~='arcade' and kind~='prize_shop' then
     block(l,3,r,5,.1,2,'stone',.95)
     for u=l+.7,r-.5,1.8 do
      block(u-.5,5,u+.5,6.6,.3,1.8,'green',.95)
      block(u-.25,6.6,u+.25,7,.7,1.3,(gym=='grass' or kind=='hotel') and 'flower' or 'leaf',1)
     end
    end
    if gym=='water' then
     local u=o.u;local yy=o.b+4
     local a,b,c=p(u-2,yy,-.55),p(u+1,yy+1,-.55),p(u+1,yy-1,-.55)
     face(a,b,c,c,'gold',1)
     local a,b,c=p(u+1,yy,-.55),p(u+2.4,yy+1.3,-.55),p(u+2.4,yy-1.3,-.55)
     face(a,b,c,c,'gold',1)
    end
    if (kind=='apartments' or kind=='hotel') and o.b>24 then
     block(l-1,o.b-1,r+1,o.b-.4,.3,2.5,'stone',1)
     local iron=s.map=='SAFFRON_CITY' and 'dark' or accent
     block(l-1,o.b+2,r+1,o.b+2.4,2.3,2.6,iron,1)
     for u=l,r,2 do block(u-.1,o.b-.4,u+.1,o.b+2.2,2.3,2.5,iron,1)end
    end
   end
  end
  V.require('DistrictArchitecture').elevation(s,side,low,high,H,openings,block,panel)
  -- Stone sconces at real entrances only, with recessed warm panes.
  for _,o in ipairs(groundDoors)do
   for _,u in ipairs({o.u-o.w/2-1.5,o.u+o.w/2+1.5})do
    if u>low+1 and u<high-1 then
     block(u-.6,14,u+.6,19,.5,1.5,'dark',1)
     panel(u-.4,14.5,u+.4,18.5,1.55,'glass',1,true)
     block(u-.8,19,u+.8,19.5,.3,1.7,accent,1)
    end
   end
  end
  for _,u in ipairs({low+.6,high-.6})do block(u-.6,0,u+.6,H,.1,1,accent,1)end
  for y=29,H,24 do block(low,y,high,y+.8,.1,.8,accent,.95)end
  if V.require('CityStreets').themes[s.map] and s.map~='ROUTE_17' then
   -- Relief, lamps and awnings follow actual openings on all four facades.
   -- The pedestrian-level footprint and every doorway remain clear.
   local urban=s.map=='SAFFRON_CITY';local garden=s.map=='FUCHSIA_CITY' or s.map=='VIRIDIAN_CITY'
   for _,o in ipairs(openings)do
    local l,r=o.u-o.w/2,o.u+o.w/2
    if o.door then
     block(l-1.2,24.6,r+1.2,25.1,.3,3.0,'mortar',1)
     block(l-.5,25.1,r+.5,25.65,.3,2.3,accent,.94)
     if kind=='office_tower' then block(l-2,26,r+2,27,.4,4,'dark',.9)end
    elseif o.b<24 then
     if garden then
      -- Banded canopies above windows, with a solid dark underside.
      block(l-.5,o.t+1,r+.5,o.t+1.35,.2,2.5,'wood',.86)
      for u=l,r,2.8 do block(u,o.t+1.35,math.min(r,u+1.35),o.t+1.65,.2,2.5,'green',.97)end
     elseif urban then
      block(l-.5,o.t+1,r+.5,o.t+1.7,.1,1.6,'dark',.82)
      block(l-.7,o.t+1.7,r+.7,o.t+2.0,.1,1.8,'gold',.96)
     elseif s.map=='CERULEAN_CITY' then
      block(l-.8,o.t+.8,r+.8,o.t+1.5,.1,1.5,'navy',.88)
      block(l-.8,o.t+1.5,r+.8,o.t+1.8,.1,1.6,'white',1)
     elseif s.map=='PEWTER_CITY' then
      block(l-.8,o.t+.8,r+.8,o.t+1.8,.1,1.2,'mortar',.94)
      block(o.u-.65,o.t+.5,o.u+.65,o.t+2.1,.2,1.55,'stone',1)
     end
    end
   end
   -- Select blank wall bays for warm lanterns, keeping windows unobscured.
   for u=low+8,high-6,24 do
    local clear=true
    for _,o in ipairs(openings)do if o.b<24 and math.abs(u-o.u)<o.w/2+2.2 then clear=false end end
    if clear then
     block(u-.6,13,u+.6,19,.2,1.4,'dark',.82)
     panel(u-.37,13.5,u+.37,18.5,1.45,'glass',1,true)
     block(u-.85,19,u+.85,19.6,.2,1.65,urban and 'gold' or accent,.9)
     if garden then
      for y=5,10,2.1 do block(u-1.5,y,u+1.5,y+.18,.2,.5,'wood',.8)end
      for _,q in ipairs({-1.3,1.3})do block(u+q-.1,5,u+q+.1,11,.2,.5,'wood',.8)end
     end
    end
   end
   -- Paired cornice mouldings catch light across the long Saffron elevations.
   block(low,H-1.1,high,H-.65,.2,.85,'mortar',.9)
   block(low,H-.55,high,H-.2,.2,1.1,accent,1)
  end
 end
 elevation('front',z1,x0,x1);elevation('back',z0,x0,x1)
 elevation('west',x0,z0,z1);elevation('east',x1,z0,z1)
 -- Roof deck closes the shell; the overhang has a continuous underside.
 box(x0-1,H,z0-1,x1+1,H+1.2,z1+1,accent,1)
 local function roofProfile(profile,mat)
  for j=1,#profile-1 do local a,b=profile[j],profile[j+1]
   local za,zb=z0-1+(D+2)*a[1],z0-1+(D+2)*b[1]
   local ya,yb=H+1.2+a[2],H+1.2+b[2]
   local n=math.max(1,math.ceil((zb-za)/4))
   for i=0,n-1 do local t,u=i/n,(i+1)/n
    local zA,zB=za+(zb-za)*t,za+(zb-za)*u;local yA,yB=ya+(yb-ya)*t,ya+(yb-ya)*u
    face({x0-1,yA,zA},{x1+1,yA,zA},{x1+1,yB,zB},{x0-1,yB,zB},mat,.94+(i%2)*.025)
    for x=x0+3,x1,6 do beam({x,yA+.1,zA},{x,yB+.1,zB},.18,accent,.95)end
   end
   for _,x in ipairs({x0-1,x1+1})do
    face({x,H+.9,za},{x,ya,za},{x,yb,zb},{x,H+.9,zb},mat,.87)
    beam({x,ya+.2,za},{x,yb+.2,zb},.65,'mortar',1)
   end
  end
 end
 local flat=kind=='office_tower' or kind=='department_store' or kind=='oak_lab' or kind=='research_lab' or kind=='apartments' or kind=='museum' or kind=='museum_wing' or kind=='arcade' or kind=='prize_shop' or kind=='league' or gym=='water' or gym=='psychic' or gym=='rock'
 if gym=='grass' then
  roofProfile({{0,0},{.5,15},{1,0}},'glass')
  for z=z0+4,z1-2,6 do
   local rise=15*(1-math.abs((z-cz)/(D/2)))
   beam({x0,H+1,z},{x0,H+1+rise,z},.5,'green')
   beam({x0,H+1+rise,z},{x1,H+1+rise,z},.65,'green')
  end
 elseif kind=='dojo' or gym=='poison' then
  roofProfile({{0,2},{.10,0},{.5,14},{.90,0},{1,2}},roof)
 elseif flat then
  box(x0,H+1.2,z0,x1,H+1.6,z1,'slate',.9)
  for _,x in ipairs({x0,x1-1})do box(x,H+1,z0,x+1,H+4,z1,accent,1)end
  for _,z in ipairs({z0,z1-1})do box(x0,H+1,z,x1,H+4,z+1,accent,1)end
 else roofProfile({{0,0},{.23,10},{.77,10},{1,0}},roof)end
 -- Stepped quarry roof with stone capping, not the domestic roof recipe.
 if gym=='rock' then
  for tier=0,2 do
   local inset=2+tier*5
   box(x0+inset,H+1+tier*3,z0+inset,x1-inset,H+4+tier*3,z1-inset,'stone',.92)
   box(x0+inset-.4,H+3.4+tier*3,z0+inset-.4,x1-inset+.4,H+4.1+tier*3,z1-inset+.4,'mortar',1)
  end
 end
 -- Low pediments and roof lanterns give civic landmarks their own skyline.
 if kind=='museum' or kind=='league' then
  local half=math.min(22,W*.23);local y=H+4
  box(cx-half,H+1,z1-12,cx+half,y+4,z1+1,'stone',1)
  face({cx-half-1,y+4,z1+1.1},{cx+half+1,y+4,z1+1.1},{cx,y+14,z1+1.1},{cx,y+14,z1+1.1},'mortar',1)
  for _,sg in ipairs({-1,1})do
   face({cx,y+14,z1-13},{cx+sg*(half+2),y+4,z1-13},{cx+sg*(half+2),y+4,z1+2},{cx,y+14,z1+2},roof,.96)
   beam({cx+sg*(half+2),y+4,z1+2.1},{cx,y+14,z1+2.1},.65,'white')
  end
  if kind=='museum' then
   -- Fossil rosette, carved in stone.
   G.disc(cx,y+7,z1+1.25,3.2,'stone');G.disc(cx,y+7,z1+1.35,2.5,'mortar')
   for i=0,11 do local a=i*math.pi/6
    beam({cx+math.cos(a),y+7+math.sin(a),z1+1.4},{cx+2.4*math.cos(a+.3),y+7+2.4*math.sin(a+.3),z1+1.4},.25,'stone')
   end
  else G.disc(cx,y+7,z1+1.3,3,'gold');G.disc(cx,y+7,z1+1.4,1.8,'navy')end
 end
 if kind=='department_store' then
  -- A blue glazed rooftop pavilion and long shaded retail canopy.
  box(x0+W*.3,H+2,z0+D*.3,x0+W*.7,H+12,z0+D*.65,'navy',1)
  face({x0+W*.3+1,H+4,z0+D*.65+.1},{x0+W*.7-1,H+4,z0+D*.65+.1},{x0+W*.7-1,H+10,z0+D*.65+.1},{x0+W*.3+1,H+10,z0+D*.65+.1},'glass',.9,true)
  for x=x0+W*.3+4,x0+W*.7-2,6 do box(x-.2,H+3,z0+D*.65+.2,x+.2,H+11,z0+D*.65+.7,'gold',1)end
  box(x0+W*.3-1,H+12,z0+D*.3-1,x0+W*.7+1,H+13,z0+D*.65+1,'gold',1)
  box(x0+1,24,z1+.2,x1-1,25,z1+3.5,'green',1)
  box(x0+1,23.5,z1+3.5,x1-1,24,z1+3.8,'gold',1)
 end
 if V.require('CityStreets').themes[s.map] then
  -- Upper facade only: no new ground footprint or doorway obstruction.
  local trim=s.map=='FUCHSIA_CITY' and 'wood' or s.map=='PEWTER_CITY' and 'mortar' or s.map=='SAFFRON_CITY' and 'gold' or accent
  box(x0+2,H-3.1,z1+.18,x1-2,H-2.3,z1+.50,trim,.9)
  if kind=='safari_gate' or kind=='meeting_hall' then
   box(x0+2,H-1.5,z1+.2,x1-2,H-.8,z1+1.2,'wood',.95)
   for x=x0+5,x1-4,7 do
    beam({x-.8,H-5,z1+.5},{x+.8,H-2,z1+.5},.35,'green',.9)
   end
  elseif kind=='oak_lab' or kind=='school' then
   for _,x in ipairs({x0+5,x1-5})do
    box(x-1,H-8,z1+.18,x+1,H-4,z1+.5,'navy',.9)
    box(x-.18,H-7.4,z1+.52,x+.18,H-4.6,z1+.65,'white',1)
   end
  elseif kind=='apartments' then
   -- Small stone corbels punctuate the long cornice.
   for x=x0+4,x1-3,8 do box(x-.5,H-4.5,z1+.2,x+.5,H-2.2,z1+.9,'mortar',.9)end
  end
 end
 if kind=='arcade' or kind=='prize_shop' then V.require('CasinoExterior').detail(G,s,H) end
 if kind=='diner' or kind=='daycare' then
  for x=x0+2,x1-2,3 do
   local mat=math.floor((x-x0)/3)%2==0 and (kind=='diner' and 'red' or 'green') or 'white'
   face({x,25,z1+.1},{math.min(x+2.9,x1-2),25,z1+.1},{math.min(x+2.9,x1-2),23,z1+3.2},{x,23,z1+3.2},mat,1)
  end
 end
 if kind=='ruined_mansion' then
  -- A few weathered shutter boards and roof scars, without sealing the door.
  for _,x in ipairs({x0+8,x1-8})do
   beam({x-3,11,z1+.95},{x+3,19,z1+.95},.65,'wood',.8)
   box(x-.6,H+6,z0+D*.3,x+.6,H+8,z0+D*.55,'dark',.8)
  end
 end
 -- Sculpted dome is restricted to the Psychic Gym and Bill's observatory.
 if gym=='psychic' or kind=='bill_house' then
  local radius=math.min(W,D)*.32;local base=H+(flat and 2 or 12)
  for row=0,5 do local a,b=row*math.pi/12,(row+1)*math.pi/12
   for j=0,23 do local u,v=j*math.pi/12,(j+1)*math.pi/12
    local function p(lat,lon)return {cx+radius*math.cos(lat)*math.cos(lon),base+radius*math.sin(lat),cz+radius*math.cos(lat)*math.sin(lon)}end
    face(p(a,u),p(a,v),p(b,v),p(b,u),roof,.97)
   end
  end
  box(cx-.4,base+radius,cz-.4,cx+.4,base+radius+4,cz+.4,'gold',1)
 end
 -- Labs and the Water Gym have raised glass rooflights.
 if kind=='oak_lab' or kind=='research_lab' or gym=='water' then
  for _,x in ipairs({x0+W*.28,x0+W*.72})do
   local w=math.min(6,W*.12)
   box(x-w,H+2,z0+D*.3,x+w,H+3,z0+D*.7,accent,1)
   face({x-w+.4,H+3.05,z0+D*.3+.4},{x+w-.4,H+3.05,z0+D*.3+.4},{x+w-.4,H+3.05,z0+D*.7-.4},{x-w+.4,H+3.05,z0+D*.7-.4},'glass',1,true)
   box(x-.2,H+3.1,z0+D*.3,x+.2,H+3.5,z0+D*.7,'white',1)
  end
 end
 -- Substantial pilasters make quarry/earth gyms and museum recognizable.
 if gym=='rock' or gym=='ground' or kind=='museum' or kind=='league' then
  for _,x in ipairs({x0+2,x1-2})do
   box(x-1.4,0,z1+.2,x+1.4,H,z1+2.1,'stone',1)
   for y=4,H-2,5 do box(x-1.6,y,z1+.1,x+1.6,y+.5,z1+2.3,'mortar',.9)end
  end
  if gym=='rock' then
   face({x0,H+2,z1+1.1},{x1,H+2,z1+1.1},{cx,H+12,z1+1.1},{cx,H+12,z1+1.1},'stone',1)
  end
 end
 if kind=='power_station' or gym=='fire' then
  for _,x in ipairs({x0+W*.2,x0+W*.8})do
   box(x-2,H+5,z0+D*.25-2,x+2,H+19,z0+D*.25+2,'stone',1)
   box(x-2.6,H+19,z0+D*.25-2.6,x+2.6,H+20,z0+D*.25+2.6,'dark',1)
  end
 end
 -- Roof plant and satellite equipment belong to research/business buildings.
 if kind=='office_tower' or kind=='research_lab' or kind=='department_store' then
  box(x0+W*.2,H+2,z0+D*.25,x0+W*.4,H+8,z0+D*.5,'stone',1)
  for x=x0+W*.2+.6,x0+W*.4-.3,2 do box(x,H+8,z0+D*.26,x+.5,H+8.3,z0+D*.48,'dark',1)end
  beam({x1-5,H+2,z0+5},{x1-5,H+14,z0+5},.4,'mortar')
 end
 -- A planted cornice softens Celadon's civic facades and Grass Gym.
 if s.map=='CELADON_CITY' or gym=='grass' then
  for _,x in ipairs({x0+W*.18,x0+W*.82})do
   box(x-3,H+1,z1-3,x+3,H+3,z1-1,'stone',1)
   for xx=x-2,x+2,1.5 do box(xx-.6,H+3,z1-2.8,xx+.6,H+4.8,z1-1.3,'green',1)end
  end
 end
 local label=labels[kind]
 if label and kind~='arcade' and kind~='prize_shop' then
  local w=math.min(W-6,math.max(20,#label*3.8));local y=H-7
  if (s.map=='FUCHSIA_CITY' and kind=='safari_gate') or (s.map=='VIRIDIAN_CITY' and kind=='school') then
   y=H+2
   for _,xx in ipairs({cx-w*.36,cx+w*.36})do box(xx-.22,H-1,z1+.5,xx+.22,y,z1+1.2,'wood',.85)end
  end
  box(cx-w/2,y,z1+1,cx+w/2,y+6.4,z1+1.7,(accent=='gold' or accent=='mortar') and 'navy' or accent,1)
  G.text(label,cx,y+.8,z1+1.8,math.min(1,(w-2)/(#label*4-1)),'white')
 end
 -- Compact, architectural emblems identify businesses without path clutter.
 if kind=='bike_shop' then
  for _,x in ipairs({cx-4,cx+4})do G.disc(x,H+4,z1+1,2.5,'dark');G.disc(x,H+4,z1+1.1,1.8,'mortar')end
  beam({cx-4,H+4,z1+1.2},{cx,H+8,z1+1.2},.4,'red');beam({cx,H+8,z1+1.2},{cx+4,H+4,z1+1.2},.4,'red')
 elseif gym then
  local y=H+7
  if gym=='water' then G.disc(cx,y,z1+1.2,3,'blue');G.disc(cx-1,y+1,z1+1.3,1,'white')
  elseif gym=='grass' then face({cx,y-3,z1+1.2},{cx+4,y+1,z1+1.2},{cx+1,y+5,z1+1.2},{cx-3,y+1,z1+1.2},'leaf',1)
  elseif gym=='psychic' then G.disc(cx,y,z1+1.2,3,'gold');G.disc(cx,y,z1+1.3,1.6,'navy')
  elseif gym=='poison' then G.disc(cx,y,z1+1.2,3,'slate');G.disc(cx-1,y+1,z1+1.3,.6,'gold');G.disc(cx+1,y+1,z1+1.3,.6,'gold')
  elseif gym=='fire' then face({cx-3,y-2,z1+1.2},{cx+3,y-2,z1+1.2},{cx+1,y+5,z1+1.2},{cx-1,y+1,z1+1.2},'red',1)
  else face({cx-3,y,z1+1.2},{cx,y+4,z1+1.2},{cx+3,y,z1+1.2},{cx,y-3,z1+1.2},'gold',1)end
 end
 V.require('DistrictArchitecture').roof(s,G,H)
 -- Sills remain clear of all entrance openings; no freestanding obstacles.
 return G.out
end
function M.towerDetail(s)
 local G=Kit.new(s.uv);local x,z,D=s.x0,s.z0,s.depth
 -- Original stone dressings follow Better Buildings' existing stepped walls.
 -- The pagoda roofs, 164-unit height, haunted lamps and graves remain its own.
 for _,tier in ipairs({{4,91,8,D-4,28,58},{10,85,13,D-8,60,91},{24,71,22,D-18,92,105},{38,57,31,D-27,124,137}})do
  local a,b,c,d,lo,hi=tier[1],tier[2],tier[3],tier[4],tier[5],tier[6]
  for _,xx in ipairs({a+.4,b-.4})do
   G.box(x+xx-.5,lo,z+c,x+xx+.5,hi,z+d+.9,'dark',.95)
   for y=lo+2,hi-1,4 do G.box(x+xx-.7,y,z+d+.3,x+xx+.7,y+.35,z+d+1,'slate',.58)end
  end
  G.box(x+a,hi-.8,z+d+.1,x+b,hi,z+d+.85,'slate',.55)
 end
 -- Tall thin portal framing leaves the existing center threshold unobstructed.
 for _,xx in ipairs({33,62})do
  G.box(x+xx-.7,0,z+D-1.3,x+xx+.7,25,z+D-.3,'dark',1)
  for y=3,24,4 do G.box(x+xx-.9,y,z+D-.5,x+xx+.9,y+.4,z+D-.1,'slate',.65)end
 end
 G.beam({x+32,25,z+D-.2},{x+48,32,z+D-.2},.8,'slate',.65)
 G.beam({x+48,32,z+D-.2},{x+64,25,z+D-.2},.8,'slate',.65)
 return G.out
end
return M
