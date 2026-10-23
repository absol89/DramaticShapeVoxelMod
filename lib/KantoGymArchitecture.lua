-- Eight League exteriors matched to the established eight interior identities.
-- Every element is batched static geometry. Entrance coordinates stay authored.
local V=...;local M={};local min,max,abs=math.min,math.max,math.abs
M.themes={
 PEWTER_CITY={key='rock',title='BOULDER',wall='ktSandstone',trim='ktBasalt',roof='lvSlate',H=39,R=16},
 CERULEAN_CITY={key='water',title='CASCADE',wall='ktPlaster',trim='ktMarine',roof='ktGlass',H=37,R=24},
 VERMILION_CITY={key='electric',title='THUNDER',wall='ktBrick',trim='ktSteel',roof='ktObsidian',H=40,R=17},
 CELADON_CITY={key='garden',title='RAINBOW',wall='ktLime',trim='ktCopper',roof='ktGlass',H=38,R=24},
 FUCHSIA_CITY={key='poison',title='VEILED',wall='ktLime',trim='ktCedar',roof='lvSlate',H=38,R=21},
 SAFFRON_CITY={key='psychic',title='ASTRAL',wall='ktObsidian',trim='ktBronze',roof='ktViolet',H=40,R=21},
 CINNABAR_ISLAND={key='fire',title='VOLCANO',wall='ktBasalt',trim='ktSteel',roof='ktTerracotta',H=40,R=18},
 VIRIDIAN_CITY={key='ground',title='EARTH',wall='ktOchre',trim='ktSandstone',roof='ktCopper',H=42,R=14},
}
function M.model(s)
 local c=M.themes[s.map];if s.kind~='gym'or not c then return nil end
 local K=V.require('KantoArchitectureKit').new(s);local G=K.G;local box,face,beam=K.box,K.face,K.beam
 local x0,x1,z0,z1=s.x0,s.x1,s.z0,s.z1;local cx,cz=(x0+x1)/2,(z0+z1)/2;local W,D=x1-x0,z1-z0
 local H,R,key=c.H,c.R,c.key;local profile
 if key=='water'then profile={};for i=0,16 do local t=i/16;profile[#profile+1]={t,R*math.sin(math.pi*t)}end
 elseif key=='garden'then profile={{0,0},{.5,R},{1,0}}
 elseif key=='poison'then profile={{0,2},{.12,0},{.5,R},{.88,0},{1,2}}
 elseif key=='electric'then profile={{0,0},{.26,R},{.30,1},{.59,R},{.63,1},{.96,R},{1,0}}
 elseif key=='fire'then profile={{0,0},{.19,8},{.33,R},{.67,R},{.81,8},{1,0}}end
 local el={}
 for _,v in ipairs({{'front',x0,x1,z1},{'back',x0,x1,z0},{'west',z0,z1,x0},{'east',z0,z1,x1}})do
  local side,lo,hi,plane=v[1],v[2],v[3],v[4]
  local E=K.elevation(side,lo,hi,plane,H,(side=='front'or side=='back')and profile or nil);el[side]=E
  local shape=(key=='water'or key=='garden'or key=='ground')and 'round'or key=='rock'and 'segment'or 'rect'
  local doors={}
  for _,d in ipairs(s.doors or{})do if(d.side or'front')==side then
   local u=d.u or d.x;local w=d.w or 14
   if u-w/2>=lo and u+w/2<=hi then doors[#doors+1]=E.open(u,w,0,28,shape,true)end
  end end
  local spans={{lo+5,hi-5}}
  for _,d in ipairs(doors)do local out={}
   for _,r in ipairs(spans)do
    if d.u-d.w/2-5>r[1]then out[#out+1]={r[1],min(r[2],d.u-d.w/2-5)}end
    if d.u+d.w/2+5<r[2]then out[#out+1]={max(r[1],d.u+d.w/2+5),r[2]}end
   end;spans=out
  end
  for _,r in ipairs(spans)do local width=r[2]-r[1]
   if width>8 then local n=max(1,math.floor(width/22));local w=min((key=='garden'or key=='water')and 19 or 13,width/n-4)
    for j=1,n do E.open(r[1]+width*(j-.5)/n,w,9,key=='psychic'and H-5 or 29,shape)end
   end
  end
  if profile and(side=='front'or side=='back')and(key=='water'or key=='garden')then
   E.open((lo+hi)/2,min(30,(hi-lo)*.34),H+1.5,H+R-5,'round')
  end
  E.walls(c.wall,key=='water'and 'ktPearl'or c.trim)
  for _,o in ipairs(E.openings)do local u,l,r,b=o.u,o.u-o.w/2,o.u+o.w/2,o.b
   E.frame(o,c.trim,key=='rock'and 1.05 or .8)
   E.pane(o,(key=='water'or key=='garden')and 'ktGlass'or 'glass',key~='water'and key~='garden')
   if o.door then
    if key=='rock'or key=='electric'or key=='fire'or key=='ground'then
     E.panel(l+.35,.15,r-.35,22.6,-.64,key=='ground'and 'ktBronze'or 'ktObsidian',1)
     for _,sg in ipairs({-1,1})do
      local a=sg<0 and l+.9 or u+.6;local d=sg<0 and u-.6 or r-.9
      E.box(a,3,d,9,-.62,-.40,c.trim,.88);E.box(a,11,d,20.8,-.62,-.40,c.trim,.94)
      E.panel(a+.5,12.3,d-.5,19.6,-.30,'glass',.9,true)
     end
    elseif key=='poison'then
     E.panel(l+.35,.15,r-.35,22.6,-.68,'ktCedar',1)
     for x=l+1,r-.6,1.3 do E.box(x-.09,.5,x+.09,22,-.61,-.22,'dark',1)end
    end
    E.box(u-.18,0,u+.18,27.7,-.7,.32,c.trim,1)
    for _,sg in ipairs({-1,1})do E.box(u+sg*1.35-.14,9,u+sg*1.35+.14,13,.35,.64,'ktBronze',1.1)end
    E.box(l-.3,0,r+.3,.28,-.75,.8,c.trim,1.12)
    -- Full portico depth is attached above head height; no added steps/posts.
    local dep=side=='front'and 2.25 or .82
    E.box(l-1.5,29.4,r+1.5,30.4,.1,dep,c.trim,1)
    E.box(l-1.1,30.4,r+1.1,31,.1,dep+.07,key=='psychic'and 'ktViolet'or c.wall,1.07)
    for _,x in ipairs({l-2,r+2})do if x>lo+1 and x<hi-1 then E.lantern(x,17,c.trim,true)end end
   else
    if key=='poison'then
     for x=l+1.1,r-.5,2.3 do E.box(x-.10,b,x+.10,o.spring,-.69,.17,c.trim,1)end
     for y=b+3,o.spring-1,4 do E.box(l+.3,y,r-.3,y+.19,-.6,.24,c.trim,.94)end
    elseif key=='electric'or key=='fire'then
     for y=b+4,o.spring-1,5 do E.box(l+.25,y,r-.25,y+.35,-.72,.27,c.trim,1)end
     E.box(u-.22,b,u+.22,o.spring,-.74,.17,'dark',1)
    elseif key=='psychic'then
     for _,sg in ipairs({-1,1})do E.beam(u,b+1,u+sg*o.w*.35,(b+o.t)*.5,-.22,.23,'ktBronze',1);E.beam(u+sg*o.w*.35,(b+o.t)*.5,u,o.t-1,-.22,.23,'ktBronze',1)end
    else
     E.box(u-.17,b,u+.17,o.t-.3,-.70,.2,c.trim,1)
     E.box(l+.25,o.spring-2,r-.25,o.spring-1.7,-.68,.29,c.trim,1)
     for _,sg in ipairs({-1,1})do E.beam(u,o.spring-1.7,u+sg*o.w*.30,o.t-1,-.15,.20,c.trim,1)end
    end
    if b<30 and(key=='psychic'or key=='ground'or key=='rock')then
     -- Layered, inset spandrels below the glazing; no painted-on flat panels.
     E.box(l-.2,6.1,r+.2,7.8,.06,.30,c.trim,.92)
     E.panel(l+.4,6.45,r-.4,7.45,.34,c.wall,.80)
     if key=='psychic'then
      for _,sg in ipairs({-1,1})do E.beam(u,6.6,u+sg*1.7,7.2,.41,.12,'ktBronze',1)end
     end
    elseif b<30 and(key=='electric'or key=='fire')then
     E.box(l-.4,6,r+.4,7.6,.08,.38,'ktSteel',.85)
     for x=l+.5,r-.3,1.7 do E.box(x-.28,6.2,x+.28,7.3,.4,.58,'dark',1)end
     for _,x in ipairs({l-.25,r+.25})do E.box(x-.12,7.9,x+.12,8.2,.39,.63,'ktBronze',1)end
    end
    if key=='water'and b<30 then
     -- Blue enamel wave relief, disjoint strips beneath each aquarium bay.
     for j=0,5 do local a=l+(r-l)*j/6;local d=l+(r-l)*(j+1)/6
      local ya=5.8+math.sin(j*.9)*.7;local yb=5.8+math.sin((j+1)*.9)*.7
      E.poly({{a,ya},{d,yb},{d,yb+.38},{a,ya+.38}},.58,'ktPearl',1.15)
     end
    end
   end
  end
  -- Full-height pilasters occupy only blank wall strips between the openings.
  for u=lo+1.5,hi-1,13 do
   local clear=true;for _,o in ipairs(E.openings)do if abs(o.u-u)<o.w/2+1.65 then clear=false end end
   if clear then
    local w=(key=='rock'or key=='ground')and 1.25 or .52
    E.box(u-w,3,u+w,H-.12,.03,.66,c.trim,.97)
    if key=='rock'or key=='ground'then
     E.box(u-w-.2,4,u+w+.2,5.5,.06,.82,c.wall,1.12)
     E.box(u-w-.2,H-2,u+w+.2,H-.4,.06,.82,c.wall,1.12)
     for y=8,H-4,5 do E.box(u-w,y,u+w,y+.16,.67,.81,c.wall,.86)end
    elseif key=='psychic'then E.box(u-.12,5,u+.12,H-2,.69,.84,'ktBronze',1.1)
    end
   end
  end
  if key=='rock'or key=='ground'then
   -- Fluted entrance pilasters and stepped capital blocks fill the safe jamb bays.
   for _,o in ipairs(doors)do for _,sg in ipairs({-1,1})do
    local u=o.u+sg*(o.w/2+3.1)
    if u>lo+1.6 and u<hi-1.6 then
     E.box(u-1.1,1,u+1.1,27.7,.04,.54,c.trim,1)
     for _,dx in ipairs({-.55,0,.55})do E.box(u+dx-.09,3,u+dx+.09,25.4,.57,.72,c.wall,1.1)end
     E.box(u-1.4,1,u+1.4,2.1,.08,.81,c.wall,1.08)
     E.box(u-1.4,26,u+1.4,27.7,.08,.81,c.wall,1.1)
    end
   end end
  elseif key=='psychic'then
   for _,u in ipairs({lo+1.4,hi-1.4})do
    E.box(u-.36,5,u+.36,H-1,.09,.44,'ktSteel',.93)
    E.box(u-.10,7,u+.10,H-3,.46,.71,'ktBronze',1)
   end
   E.box(lo,H-.35,hi,H+.05,.12,.80,'ktBronze',1.1)
  end
  E.box(lo,H-1.3,hi,H-.5,.03,.70,c.trim,1)
  if key=='poison'or key=='garden'then
   for u=lo+3,hi-2,7 do E.box(u-.22,H-3,u+.22,H-1.4,.05,.75,c.trim,1)end
  end
 end
 box(x0-.7,H-.3,z0-.7,x1+.7,H-.06,z1+.7,c.trim,.8)
 if profile then
  K.profileRoof(profile,H,c.roof,key~='water'and key~='garden')
  if key=='water'or key=='garden'then
   -- Segmented glazing ribs are solid, continuous members, not flashing overlays.
   for z=z0-.7,z1+.71,max(6,D/7)do
    for i=1,#profile-1 do local a,b=profile[i],profile[i+1]
     beam({x0-.7+(W+1.4)*a[1],H+a[2]+.35,z},{x0-.7+(W+1.4)*b[1],H+b[2]+.35,z},.48,c.trim,1.05)
    end
   end
   for _,a in ipairs(profile)do if a[1]>.01 and a[1]<.99 then
    beam({x0-.7+(W+1.4)*a[1],H+a[2]+.4,z0-.7},{x0-.7+(W+1.4)*a[1],H+a[2]+.4,z1+.7},.3,c.trim,1)
   end end
  end
 else K.roof({{x0-.7,H,z0-.7},{x1+.7,H,z0-.7},{x1+.7,H,z1+.7},{x0-.7,H,z1+.7}},key=='psychic'and 'ktObsidian'or c.roof,false)end
 if key=='rock'then
  -- A quarry vault: tiered sandstone shoulders around a raised light well.
  for tier=0,2 do
   local ix=3+tier*5;local iz=3+tier*4
   box(x0+ix,H+tier*4,z0+iz,x1-ix,H+4+tier*4,z1-iz,c.wall,.91+tier*.03)
   box(x0+ix-.3,H+3.5+tier*4,z0+iz-.3,x1-ix+.3,H+4.2+tier*4,z1-iz+.3,c.trim,1)
  end
  for tier=0,2 do
   local ix=3+tier*5;local iz=3+tier*4;local y=H+tier*4
   for x=x0+ix+2,x1-ix-1,5 do
    box(x-.32,y+1.1,z1-iz+.04,x+.32,y+3.2,z1-iz+.22,c.trim,.95)
   end
  end
  local a,b=cx-W*.21,cx+W*.21
  box(a,H+12,cz-8,b,H+19,cz+8,'ktBasalt',.9)
  face({a+1,H+13,cz+8.1},{b-1,H+13,cz+8.1},{b-1,H+17.8,cz+8.1},{a+1,H+17.8,cz+8.1},'glass',.8,true)
  for x=a+3,b-2,5 do box(x-.17,H+12.5,cz+8.2,x+.17,H+18.3,cz+8.5,c.wall,1)end
  box(a-.8,H+19,cz-8.8,b+.8,H+20,cz+8.8,c.wall,1.1)
 elseif key=='electric'then
  -- Two rooftop induction stacks and copper busbars read as working machinery.
  for _,sg in ipairs({-1,1})do
   local x=cx+sg*W*.25;local y=H+R;local z=cz
   box(x-3.5,y-6,z-3.5,x+3.5,y+1,z+3.5,'ktSteel',1)
   for k=0,4 do
    K.ring(x,y+2+k*1.6,z,3.0-k*.13,.48,'ktBronze','xz',16)
   end
   box(x-.45,y,z-.45,x+.45,y+11,z+.45,'ktSteel',1)
   beam({x,y+1,z},{x, H+R+1,z0+10},.6,'ktBronze',1)
  end
  beam({cx-W*.25,H+R+1,z0+10},{cx+W*.25,H+R+1,z0+10},.65,'ktBronze',1)
 elseif key=='garden'then
  -- Slender roof lantern above the greenhouse ridge, with an iron crest.
  local a,b=z0+D*.25,z1-D*.25;box(cx-3,H+R-.4,a,cx+3,H+R+4,b,c.trim,1)
  for z=a+1,b-1,4 do face({cx+3.1,H+R+.3,z},{cx+3.1,H+R+.3,z+2.8},{cx+3.1,H+R+3.3,z+2.8},{cx+3.1,H+R+3.3,z},'ktGlass',1)end
  for z=a,b,5 do beam({cx,H+R+4,z},{cx,H+R+6,z},.2,c.trim,1)end
  -- Front espalier confined to blank corner bays, never another flower bed.
  for _,x in ipairs({x0+2.8,x1-2.8})do
   beam({x,7,z1+.35},{x,32,z1+.35},.25,c.trim,1)
   for y=9,28,4 do K.leaf({x,y,z1+.50},{x+(y%8==1 and -1 or 1)*1.8,y+3,z1+.85},.75,'leaf')end
  end
 elseif key=='poison'then
  -- A smaller upper pavilion, attached to the first roof instead of floating.
  local w=W*.44;local d=D*.46;local y=H+R*.65
  box(cx-w/2,y,cz-d/2,cx+w/2,y+10,cz+d/2,c.trim,.9)
  face({cx-w/2+1,y+2,cz+d/2+.05},{cx+w/2-1,y+2,cz+d/2+.05},{cx+w/2-1,y+8,cz+d/2+.05},{cx-w/2+1,y+8,cz+d/2+.05},'ktViolet',.95)
  for x=cx-w/2+2,cx+w/2-1,3 do box(x-.13,y+1.8,cz+d/2+.12,x+.13,y+8.2,cz+d/2+.45,c.trim,1)end
  local roof={{cx-w/2-1.4,y+10,cz-d/2-1.4},{cx,y+19,cz-d/2-1.4},{cx,y+19,cz+d/2+1.4},{cx-w/2-1.4,y+10,cz+d/2+1.4}}
  K.roof(roof,c.roof,true)
  K.roof({{cx,y+19,cz-d/2-1.4},{cx+w/2+1.4,y+10,cz-d/2-1.4},{cx+w/2+1.4,y+10,cz+d/2+1.4},{cx,y+19,cz+d/2+1.4}},c.roof,true)
  for _,z in ipairs({cz-d/2-1.4,cz+d/2+1.4})do beam({cx,y+19,z},{cx,y+22,z},.55,'ktBronze',1)end
 elseif key=='psychic'then
  -- Eight-sided observatory drum and faceted dome, with a rooftop armillary.
  for _,x in ipairs({x0+.2,x1-1})do
   box(x,H,z0+.2,x+.8,H+2.9,z1-.2,'ktSteel',.92)
   box(x,H+2.9,z0+.2,x+.8,H+3.15,z1-.2,'ktBronze',1.05)
  end
  for _,z in ipairs({z0+.2,z1-1})do box(x0+1,H,z,x1-1,H+2.9,z+.8,'ktSteel',.92)end
  local r=min(W*.27,D*.37);local y=H+1
  for i=0,7 do local a,b=i*math.pi/4,(i+1)*math.pi/4
   local ax,az,bx,bz=cx+math.cos(a)*r,cz+math.sin(a)*r,cx+math.cos(b)*r,cz+math.sin(b)*r
   face({ax,y,az},{bx,y,bz},{bx,y+9,bz},{ax,y+9,az},c.wall,.95)
   K.roof({{ax,y+9,az},{bx,y+9,bz},{cx,y+R,cz}},c.roof,false)
   beam({ax,y,az},{ax,y+9,az},.4,'ktBronze',1)
   beam({ax,y+9,az},{cx,y+R,cz},.3,'ktBronze',1)
  end
  K.ring(cx,y+R+6,cz,5.2,.35,'ktBronze','xy',28);K.ring(cx,y+R+6,cz,4.8,.30,'ktBronze','yz',28)
  box(cx-.4,y+R,cz-.4,cx+.4,y+R+6,cz+.4,c.trim,1)
 elseif key=='fire'then
  -- Forge exhaust stacks and ribbed heat shields, deliberately distinct heights.
  for i=1,3 do local x=x0+W*(.21+i*.14);local z=z0+D*.34;local y=H+R-1;local h=9+(i%2)*5
   box(x-2.7,H+10,z-2.7,x+2.7,y+h,z+2.7,'ktBasalt',.98)
   for k=0,2 do box(x-3,y+h-6+k*1.8,z-3,x+3,y+h-5.6+k*1.8,z+3,'ktSteel',1)end
   box(x-1.8,y+h+.03,z-1.8,x+1.8,y+h+.18,z+1.8,'dark',.6)
  end
  for _,x in ipairs({x0+W*.10,x1-W*.10})do
   box(x-1,H+5,z0+8,x+1,H+15,z1-8,'ktSteel',.9)
   for z=z0+9,z1-9,3.2 do box(x-1.15,H+5.5,z-.32,x+1.15,H+14.4,z+.32,'dark',.96)end
   box(x-1.25,H+14.5,z0+7.8,x+1.25,H+15.2,z1-7.8,'ktSteel',1.07)
  end
 elseif key=='ground'then
  -- A heavy earth citadel: recessed central roof court and four engaged towers.
  for _,x in ipairs({x0+1,x1-13})do for _,z in ipairs({z0+1,z1-13})do
   box(x,H-8,z,x+12,H+14,z+12,c.wall,1)
   for y=H,H+12,4 do box(x-.25,y,z-.25,x+12.25,y+.65,z+12.25,c.trim,1.06)end
   K.roof({{x-.3,H+14.14,z-.3},{x+12.3,H+14.14,z-.3},{x+12.3,H+14.14,z+12.3},{x-.3,H+14.14,z+12.3}},c.roof,false)
  end end
  box(x0+14,H+1,z0+2,x1-14,H+6,z0+4,c.trim,1)
  box(x0+14,H+1,z1-4,x1-14,H+6,z1-2,c.trim,1)
  -- Central recessed pavilion with inset jade clerestory.
  box(cx-W*.21,H,cz-9,cx+W*.21,H+10,cz+9,c.trim,1)
  face({cx-W*.21+1,H+3,cz+9.1},{cx+W*.21-1,H+3,cz+9.1},{cx+W*.21-1,H+8,cz+9.1},{cx-W*.21+1,H+8,cz+9.1},'ktGlass',.9)
  box(cx-W*.21-1,H+10,cz-10,cx+W*.21+1,H+11,cz+10,c.wall,1.08)
 end
 -- A single large, carefully framed gym identity with a type-specific relief.
 local E=el.front;local label=c.title..' GYM';local scale=min(.78,(W-18)/(#label*4));local half=(#label*4-1)*scale/2+1.5
 local y=H-7;E.box(cx-half-1,y-.5,cx+half+1,y+5.2,.70,1.12,c.trim,1)
 E.box(cx-half,y,cx+half,y+4.8,1.15,1.32,'dark',1);G.text(label,cx,y+.5,z1+1.41,scale,'white')
 local ry=H+5;local rz=z1+1.15
 if key=='rock'then
  G.disc(cx,ry,rz,4.5,c.trim,1);K.ring(cx,ry,rz+.14,3.5,.25,c.wall,'xy',20)
  for i=0,9 do local a=i*.65;beam({cx+math.cos(a)*(i*.26+.5),ry+math.sin(a)*(i*.26+.5),rz+.25},{cx+math.cos(a+.65)*(i*.26+.76),ry+math.sin(a+.65)*(i*.26+.76),rz+.25},.23,c.wall,1)end
 elseif key=='water'then
  local ps={{cx,ry+4},{cx+2.8,ry-.2},{cx+2,ry-2.7},{cx,ry-3.5},{cx-2,ry-2.7},{cx-2.8,ry-.2}}
  E.poly(ps,1.24,'ktPearl',1.1);E.beam(cx-.8,ry+1,cx-1.2,ry-1,1.33,.25,'white',1)
 elseif key=='electric'then
  E.poly({{cx+.7,ry+4.3},{cx-3,ry-.5},{cx-.3,ry-.5},{cx-1.2,ry-4},{cx+3.2,ry+1},{cx+.3,ry+1}},1.2,'gold',1.05)
 elseif key=='garden'then
  K.leaf({cx-2,ry-3,rz},{cx+2.5,ry+4,rz+.06},2,'leaf');E.beam(cx-2,ry-3,cx+2.5,ry+4,1.30,.18,'ktLime',1)
 elseif key=='poison'then
  E.poly({{cx,ry+4},{cx+3.7,ry},{cx,ry-4},{cx-3.7,ry}},1.23,'ktViolet',1)
  E.poly({{cx,ry+2},{cx+1.7,ry},{cx,ry-2},{cx-1.7,ry}},1.35,'ktBronze',1)
 elseif key=='psychic'then
  K.ring(cx,ry,rz,3.4,.3,'ktBronze','xy',24);K.ring(cx,ry,rz+.15,1.7,.25,'ktViolet','xy',20)
 elseif key=='fire'then
  E.poly({{cx,ry+4},{cx-2,ry+1},{cx-1.2,ry-.6},{cx-3,ry},{cx-2.2,ry-3},{cx+1.5,ry-3.5},{cx+3,ry-.4}},1.20,'red',1.1)
  E.poly({{cx,ry+1.5},{cx-1,ry-1.5},{cx+.3,ry-2.5},{cx+1.4,ry-1}},1.33,'gold',1)
 else
  for _,sg in ipairs({-1,1})do E.poly({{cx+sg*3.8,ry-2},{cx+sg*.8,ry+3.2},{cx+sg*2.4,ry-2}},1.2,c.trim,1.1)end
 end
 return G.out
end
return M
