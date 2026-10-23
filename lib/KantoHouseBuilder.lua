local V=...;local M={};local min,max,abs=math.min,math.max,math.abs
function M.model(s,c)
 local K=V.require('KantoArchitectureKit').new(s);local G=K.G;local box,beam,face=K.box,K.beam,K.face
 local x0,x1,z0,z1=s.x0,s.x1,s.z0,s.z1;local W,D=x1-x0,z1-z0;local cx,cz=(x0+x1)/2,(z0+z1)/2
 local H,R=c.height,c.rise;local family=c.name;local trim,wall,base=c.trim,c.wall,c.base
 local profile
 if c.roofKind=='gable'then profile={{0,0},{.5,R},{1,0}}
 elseif c.roofKind=='flared'then profile={{0,1.5},{.13,0},{.5,R},{.87,0},{1,1.5}}
 elseif c.roofKind=='mansard'then profile={{0,0},{.16,R*.72},{.5,R},{.84,R*.72},{1,0}}end
 local function decorate(E)
  local lo,hi,side=E.lo,E.hi,E.side;local front=side=='front';local p,block,panel=E.p,E.box,E.panel
  local depth=front and 1.2 or .75
  -- Depth stays inside source side margins, including all cornice and sill ends.
  for _,u in ipairs({lo+.7,hi-.7})do
   block(u-.55,5.8,u+.55,H-.12,.06,.55,trim,1)
   if family=='quarry'or family=='waterfront'or family=='volcanic'then
    for y=7,H-2,4.3 do block(max(lo,u-.8),y,min(hi,u+.8),y+2.1,.08,.66,base,1.08)end
   elseif family=='metropolitan'then
    block(u-.16,6,u+.16,H-1,.58,.76,'ktBronze',1.03)
   end
  end
  block(lo,H-1,hi,H-.15,.04,.72,trim,1)
  if c.floors>1 then block(lo,28.6,hi,29.5,.06,.67,base,1.06)end
  for _,o in ipairs(E.openings)do
   local l,r,u,b,t=o.u-o.w/2,o.u+o.w/2,o.u,o.b,o.t
   E.frame(o, family=='quarry'and 'ktSandstone'or family=='metropolitan'and 'ktSteel'or trim,family=='quarry'and .9 or .65)
   E.pane(o,'glass',not(c.lab and side=='back'))
   if o.door then
    if not c.clinic then
     panel(l+.30,.15,r-.30,21.4,-.67,'ktCedar',1)
     for v=l+1,r-.4,2.2 do block(v-.045,.35,v+.045,21.1,-.65,-.50,trim,.8)end
     for _,y in ipairs({2.2,10.2,20})do block(l+.8,y,r-.8,y+.40,-.43,-.17,'ktCedar',1.13)end
     for _,v in ipairs({l+1,r-1})do block(v-.20,2.6,v+.20,20,-.42,-.25,'ktCedar',1.14)end
     if c.shop or c.lab then panel(l+1.1,11.3,r-1.1,19.5,-.15,'glass',.95,true);block(u-.15,11.3,u+.15,19.5,-.12,.19,trim,1)end
    else
     block(l+.4,.1,r-.4,4,-.70,-.60,'ktSteel',.9)
     block(u-.18,.2,u+.18,26,-.68,.35,trim,1)
    end
    for _,sg in ipairs(c.clinic and {-1,1}or{1})do
     local v=c.clinic and u+sg*1.1 or r-2.1
     block(v-.28,9.2,v+.28,12.2,-.10,.35,'ktBronze',1.03)
     block(v-.10,9.8,v+.10,11.8,.35,.64,'gold',.9)
    end
    block(l+.20,21.5,r-.20,22,-.5,.30,trim,1)
    if c.shape~='rect'then
     for _,sg in ipairs({-1,1})do E.beam(u,22.1,u+sg*o.w*.30,24.6,-.29,.22,trim,1)end
    end
    block(l-.25,0,r+.25,.30,-.8,.8,base,1.06)
    -- Every entrance gets an attached canopy/hood, without posts in the path.
    local canopy=c.name=='waterfront'or c.shop or c.name=='woodland'or c.name=='reserve'
    if canopy then
     block(l-.8,28.2,r+.8,28.65,.1,front and 2.0 or .82,c.roof,1)
     block(l-.8,28.65,r+.8,29,.1,front and 2.05 or .85,trim,1.08)
    elseif family=='quarry'or family=='metropolitan'then
     block(l-1,28.1,r+1,29,.08,depth,base,1.11)
     block(l-1.3,29,r+1.3,29.6,.08,depth+.07,trim,1)
    end
    for _,v in ipairs({l-1.8,r+1.8})do if v>lo+1 and v<hi-1 then E.lantern(v,16,trim,family=='metropolitan')end end
   else
    -- Window patterns belong to the region rather than borrowing Lavender arches.
    local mid=(b+o.spring)/2
    if family=='reserve'then
     for v=l+2,r-1,3 do block(v-.12,b,v+.12,o.spring,-.74,.12,trim,.98)end
     for y=b+3,o.spring-.4,3 do block(l+.25,y,r-.25,y+.18,-.71,.21,trim,1.02)end
     block(l-.5,t+.7,r+.5,t+1.25,.08,depth,c.roof,.94)
    elseif family=='metropolitan'then
     for _,sg in ipairs({-1,1})do block(u+sg*o.w*.23-.13,b,u+sg*o.w*.23+.13,t,-.72,.19,'ktBronze',.97)end
     block(l+.25,b+3,r-.25,b+3.25,-.71,.24,trim,1)
     block(l-.4,t+.75,r+.4,t+1.3,.04,.82,base,1.08)
    else
     block(u-.17,b,u+.17,t-.25,-.72,.22,trim,1)
     block(l+.25,mid-.14,r-.25,mid+.14,-.70,.31,trim,1.05)
     if family=='village'or family=='woodland'then
      for _,sg in ipairs({-1,1})do block(u+sg*o.w*.26-.09,b,u+sg*o.w*.26+.09,o.spring,-.69,.10,trim,.92)end
     elseif family=='waterfront'or family=='garden'then
      for _,sg in ipairs({-1,1})do E.beam(u,o.spring-1,u+sg*o.w*.32,t-1.7,-.2,.17,trim,.96)end
     end
    end
    if c.shutters then
     for _,sg in ipairs({-1,1})do
      local a=sg<0 and l-2.55 or r+.7
      if a>lo+.8 and a+1.75<hi-.8 then
       block(a,b,a+1.7,o.spring,.08,.30,c.shutters,.86)
       for y=b+.5,o.spring-.3,1.55 do block(a+.12,y,a+1.58,y+.22,.32,.57,c.shutters,1.09)end
      end
     end
    end
    if family=='quarry'then
     block(u-.65,t-.35,u+.65,t+1.3,.05,.80,'ktBasalt',1.03)
     block(l-.8,b-1,r+.8,b-.6,.1,.82,'ktSandstone',1.13)
    end
    if family=='garden'and b>28 and front then
     -- Juliet rail within the existing wall margin, no ground balcony platform.
     local relief=s.doors and #s.doors>0 and 1 or .70
     block(l-.65,b-.75,r+.65,b-.35,.2,1.25*relief,base,1.06)
     for v=l,r,2.5 do block(v-.08,b-.35,v+.08,b+3.25,.95*relief,1.10*relief,'dark',1)end
     block(l-.5,b+3.25,r+.5,b+3.48,.93*relief,1.13*relief,'ktBronze',.98)
    end
    if family=='metropolitan'and b>=30 then
     -- Recessed spandrels and stepped lintels give urban facades real relief.
     block(l-.3,b-3.5,r+.3,b-1.2,.05,.25,base,.92)
     panel(l+.3,b-3,r-.3,b-1.7,.29,trim,.85)
     for _,sg in ipairs({-1,1})do E.beam(u,b-3.0,u+sg*1.8,b-1.7,.38,.13,'ktBronze',1)end
     block(l-.7,t+.65,r+.7,t+1.15,.12,.65,trim,1.10)
     for v=l+.8,r-.4,2.8 do block(v-.12,t+1.18,v+.12,t+1.65,.15,.70,base,1)end
    elseif family=='garden'then
     -- Curved fan tracery and fine carved keystones, distinct from seaside bays.
     block(u-.4,t-.1,u+.4,t+1,.1,.77,trim,1.15)
     if b<28 then
      panel(l+.3,6.4,r-.3,7.5,.28,base,.95)
      for _,sg in ipairs({-1,1})do E.beam(u,6.9,u+sg*2.5,7.2,.38,.14,'ktBronze',1)end
     end
    elseif family=='quarry'then
     for _,sg in ipairs({-1,1})do
      local v=sg<0 and l-.43 or r+.43
      block(v-.10,b+.6,v+.10,o.spring-.6,.60,.78,'ktLime',.91)
     end
    elseif family=='waterfront'then
     block(u-.45,t-.3,u+.45,t+1.15,.05,.79,'white',1.1)
     for _,sg in ipairs({-1,1})do
      local v=sg<0 and l+.8 or r-.8
      block(v-.12,b-1.5,v+.12,b-.55,.10,.71,trim,.93)
     end
    end
    if c.shop and front and b<28 then
     for y=b+1,b+6,5 do
      block(l+.6,y,r-.6,y+.30,-.60,-.26,trim,1)
      for v=l+1.7,r-1,3.4 do
       local mat=({'red','green','ktMarine'})[(math.floor(v+y)%3)+1]
       block(v-.55,y+.31,v+.55,y+2.15,-.59,-.30,mat,.94)
       block(v-.4,y+.85,v+.4,y+1.2,-.25,-.16,'white',1)
      end
     end
    end
   end
  end
  -- Regional structural language, kept out of every ground-floor aperture.
  for u=lo+3,hi-2,8 do
   if family=='woodland'or family=='reserve'or family=='village'then
    block(u-.25,H-3,u+.25,H-1.1,.18,depth*.65,trim,1)
   elseif family=='waterfront'or family=='garden'then
    block(u-.30,H-1.65,u+.30,H-.6,.12,.79,trim,1.10)
   end
  end
  if profile and (side=='front'or side=='back')then
   for i=1,#profile-1 do local a,b=profile[i],profile[i+1]
    E.beam(lo+(hi-lo)*a[1],H+a[2],lo+(hi-lo)*b[1],H+b[2],.54,.60,trim,1.08)
   end
   if c.roofKind=='gable'then
    local u=(lo+hi)/2
    block(u-.25,H+.8,u+.25,H+R-.6,.06,.49,trim,1)
    if family=='woodland'or family=='village'then
     for _,sg in ipairs({-1,1})do E.beam(u,H+1,u+sg*(hi-lo)*.28,H+R*.40,.31,.48,trim,1)end
    end
   end
  end
 end
 local elevations={}
 for _,v in ipairs({{'front',x0,x1,z1},{'back',x0,x1,z0},{'west',z0,z1,x0},{'east',z0,z1,x1}})do
  local side,lo,hi,plane=v[1],v[2],v[3],v[4]
  local E=K.elevation(side,lo,hi,plane,H,(side=='front'or side=='back')and profile or nil);elevations[side]=E
  local doors={}
  for _,d in ipairs(s.doors or{})do if(d.side or'front')==side then
   local u=d.u or d.x;local w=d.w or 14
   if u-w/2>=lo and u+w/2<=hi then local o=E.open(u,w,0,27,c.shape,true);doors[#doors+1]=o end
  end end
  for floor=0,c.floors-1 do
   local spans={{lo+4.5,hi-4.5}}
   if floor==0 then for _,d in ipairs(doors)do
    local out={};for _,r in ipairs(spans)do
     if d.u-d.w/2-4>r[1]then out[#out+1]={r[1],min(r[2],d.u-d.w/2-4)}end
     if d.u+d.w/2+4<r[2]then out[#out+1]={max(r[1],d.u+d.w/2+4),r[2]}end
    end;spans=out
   end end
   for _,span in ipairs(spans)do local width=span[2]-span[1]
    if width>=8 then
     local n=max(1,math.floor(width/(c.shutters and 24 or 21)))
     for i=1,n do
      local u=span[1]+width*(i-.5)/n;local w=min(c.windowWidth,width/n-(c.shutters and 4.8 or 2.5))
      local b=floor==0 and 9 or 33;local t=floor==0 and 26 or H-4
      E.open(u,w,b,t,c.shape)
     end
    end
   end
  end
  if profile and c.roofKind=='gable'and R>=18 and (side=='front'or side=='back')then
   E.open((lo+hi)/2,7,H+3,H+12,'round')
  end
  E.walls(wall,base);decorate(E)
 end
 -- The soffit is below, never coplanar with, the complete roof envelope.
 box(x0-.7,H-.30,z0-.7,x1+.7,H-.06,z1+.7,trim,.83)
 if profile then K.profileRoof(profile,H,c.roof,true)
 elseif c.roofKind=='hip'then K.hip(H,R,c.roof,true)
 elseif c.roofKind=='monitor'then
  -- Low research roof with a genuinely raised glazed clerestory.
  K.hip(H,8,c.roof,true)
  local y=H+8;local w=min(24,W*.38);local d=min(20,D*.48)
  box(cx-w/2,y-5,cz-d/2,cx+w/2,y+7,cz+d/2,trim,.95)
  for _,z in ipairs({cz-d/2-.05,cz+d/2+.05})do
   face({cx-w/2+.7,y,z},{cx+w/2-.7,y,z},{cx+w/2-.7,y+6,z},{cx-w/2+.7,y+6,z},'ktGlass',1)
   for x=cx-w/2+2,cx+w/2-1,4 do box(x-.14,y-.1,z-.08,x+.14,y+6.2,z+.08,trim,1)end
  end
  K.roof({{cx-w/2-.6,y+7,cz-d/2-.6},{cx+w/2+.6,y+7,cz-d/2-.6},{cx+w/2+.6,y+7,cz+d/2+.6},{cx-w/2-.6,y+7,cz+d/2+.6}},c.roof,true)
 else
  K.roof({{x0-.7,H,z0-.7},{x1+.7,H,z0-.7},{x1+.7,H,z1+.7},{x0-.7,H,z1+.7}},c.roof,false)
  for _,x in ipairs({x0,x1-.65})do box(x,H,z0,x+.65,H+4.5,z1,trim,1)end
  for _,z in ipairs({z0,z1-.65})do box(x0,H,z,x1,H+4.5,z+.65,trim,1)end
  -- Art Deco stepped crown; each variant changes its width and number of steps.
  for tier=0,1+c.variant%2 do
   local half=W*(.30-tier*.065)
   box(cx-half,H+4+tier*1.5,z1-2.5,cx+half,H+5.7+tier*1.5,z1-.7,base,1.03)
   box(cx-half,H+5.65+tier*1.5,z1-2.55,cx+half,H+5.9+tier*1.5,z1-.64,'ktBronze',1)
  end
 end
 -- Individual roof features break repeated housing silhouettes, with no walkable
 -- roof platforms and no new ground furniture/flower beds.
 if not c.lab and not c.clinic and not c.shop and c.roofKind~='flat'then
  local x=cx-W*(c.variant%2==0 and .24 or -.24);local z=z0+D*.36
  local y=H+R+3
  box(x-1.4,H+R*.30,z-1.4,x+1.4,y,z+1.4,base,1)
  box(x-1.85,y-.5,z-1.85,x+1.85,y+.3,z+1.85,trim,1.08)
  box(x-1,y+.32,z-1,x+1,y+.45,z+1,'dark',.6)
 end
 if (family=='waterfront'and not c.clinic and not c.shop and not c.lab)
    or(family=='garden'and c.variant%2==0)then
  local y=H+R-3;local dz=min(9,D*.18);local wx=min(10,W*.13)
  box(cx-wx/2,y,cz-dz/2,cx+wx/2,y+5.2,cz+dz/2,trim,.92)
  face({cx-wx/2+.5,y+.6,cz+dz/2+.06},{cx+wx/2-.5,y+.6,cz+dz/2+.06},{cx+wx/2-.5,y+4.4,cz+dz/2+.06},{cx-wx/2+.5,y+4.4,cz+dz/2+.06},'ktGlass',1)
  box(cx-.13,y+.4,cz+dz/2+.1,cx+.13,y+4.6,cz+dz/2+.28,trim,1)
  K.roof({{cx-wx/2-.5,y+5.25,cz-dz/2-.5},{cx+wx/2+.5,y+5.25,cz-dz/2-.5},{cx+wx/2+.5,y+5.25,cz+dz/2+.5},{cx-wx/2-.5,y+5.25,cz+dz/2+.5}},c.roof,true)
 end
 if c.cupola then
  local y=H+R;box(cx-3.5,y-5,cz-3.5,cx+3.5,y+5,cz+3.5,trim,1)
  face({cx-2.5,y-.5,cz+3.55},{cx+2.5,y-.5,cz+3.55},{cx+2.5,y+3.8,cz+3.55},{cx-2.5,y+3.8,cz+3.55},'dark',1)
  K.ring(cx,y+1.5,cz+3.65,1.3,.2,'gold','xy',16)
  for i=0,3 do local pts={{-1,-1},{1,-1},{1,1},{-1,1}};local a,b=pts[i+1],pts[(i+1)%4+1]
   face({cx+a[1]*4.3,y+5,cz+a[2]*4.3},{cx+b[1]*4.3,y+5,cz+b[2]*4.3},{cx,y+10,cz},{cx,y+10,cz},c.roof,1)
  end
 end
 local E=elevations.front
 if c.label then
  local u=cx;if c.floors==1 and s.doors and s.doors[1]then u=s.doors[1].u or s.doors[1].x or cx end
  local scale=min(.72,(W-8)/max(1,#c.label*4));local width=(#c.label*4-1)*scale+2
  u=max(x0+width/2+1,min(x1-width/2-1,u))
  local y=c.floors>1 and 29.9 or 29.6
  local mat=c.clinic and 'red'or c.shop and 'navy'or trim
  E.box(u-width/2,y,u+width/2,y+4.7,.72,1.08,mat,1)
  G.text(c.label,u,y+.6,z1+1.16,scale,'white')
  if c.clinic then
   local y=H+7;G.disc(cx,y,z1+.81,3.7,base,1.08);G.disc(cx,y,z1+.95,3.0,'white',1)
   E.panel(cx-.65,y-2,cx+.65,y+2,1.07,'red',1);E.panel(cx-2,y-.65,cx-.65,y+.65,1.07,'red',1);E.panel(cx+.65,y-.65,cx+2,y+.65,1.07,'red',1)
  end
 end
 if family=='woodland'or family=='reserve'then
  -- A single attached trellis on a verified blank strip, with modeled leaves.
  local u=x1-2.4;local clear=true
  for _,o in ipairs(E.openings)do if o.b<28 and abs(o.u-u)<o.w/2+1.2 then clear=false end end
  if clear then
   for y=7,19,3 do E.box(u-.6,y,u+.6,y+.15,.1,.4,trim,.8);K.leaf({u,y,z1+.6},{u-.9,y+1.9,z1+.8},.55,'leaf')end
  end
 end
 if c.badge then
  G.disc(cx,H+5,z1+.8,2.6,'ktBronze',1);G.disc(cx,H+5,z1+.94,1.9,'ktMarine',1)
 end
 if c.oculus then K.ring(cx,H+4,z1-.55,3.1,.32,'ktBronze','xy')end
 -- One fine rear rainpipe, material and cap shape follow the local style.
 local x=c.variant%2==0 and x0+.6 or x1-.6
 box(x-.13,1,z0-.35,x+.13,H-.5,z0-.1,trim,.83)
 for y=7,H-2,10 do box(x-.24,y,z0-.48,x+.24,y+.25,z0-.06,base,1)end
 return G.out
end
return M
