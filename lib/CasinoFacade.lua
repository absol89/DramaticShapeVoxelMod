-- Celadon's paired Art Deco facades. Static geometry uses the established
-- ReferenceMaterials atlas/shader and the actual CityBuildings door openings.
-- No scene callbacks, collision edits, textures, particles or extra draw pass.
local V=...
local M={}
local Neon=V.require("CasinoNeon")
function M.elevation(G,s,side,low,high,H,openings,p,panel,block)
 local front=side=='front'
 local function face(a,b,c,d,mat,t)
  if side=='east' or side=='back' then a,b,c,d=d,c,b,a end
  G.face(a,b,c,d,mat,t)
 end
 local function line(a,b,c,d,n,w,mat,t)
  -- Draw in this elevation's local plane, including east/west faces. G.beam's
  -- global XY cross section cannot represent diagonal side-wall tracery.
  local dx,dy=c-a,d-b;local len=math.sqrt(dx*dx+dy*dy)
  if len<.001 then return end
  local ux,uy=-dy/len*w/2,dx/len*w/2
  local pts={{a+ux,b+uy},{a-ux,b-uy},{c-ux,d-uy},{c+ux,d+uy}}
  local function point(i,z)return p(pts[i][1],pts[i][2],z)end
  face(point(1,n),point(2,n),point(3,n),point(4,n),mat,t)
  for i=1,4 do local j=i%4+1
   face(point(i,n-.10),point(j,n-.10),point(j,n),point(i,n),mat,t*.8)
  end
 end
 local function rim(a,b,c,d,n,w,mat,t)
  -- One hollow frame, with no hidden backs or overlapping corner blocks.
  local outer={{a,b},{c,b},{c,d},{a,d}}
  local inner={{a+w,b+w},{c-w,b+w},{c-w,d-w},{a+w,d-w}}
  for i=1,4 do local j=i%4+1
   local function q(r,k,z)return p(r[k][1],r[k][2],z)end
   face(q(outer,i,n),q(outer,j,n),q(inner,j,n),q(inner,i,n),mat,t)
   face(q(outer,i,n-.12),q(outer,j,n-.12),q(outer,j,n),q(outer,i,n),mat,t*.78)
   face(q(inner,j,n-.12),q(inner,i,n-.12),q(inner,i,n),q(inner,j,n),mat,t*.72)
  end
 end
 local function bevel(a,b,c,d,n,w,mat)
  -- Four sloping faces give the panels a real reveal instead of coplanar paint.
  local outer={{a,b},{c,b},{c,d},{a,d}}
  local inner={{a+w,b+w},{c-w,b+w},{c-w,d-w},{a+w,d-w}}
  for i=1,4 do local j=i%4+1
   face(p(outer[i][1],outer[i][2],n),p(outer[j][1],outer[j][2],n),
    p(inner[j][1],inner[j][2],n-.20),p(inner[i][1],inner[i][2],n-.20),mat,({.62,.82,1,.74})[i])
  end
 end
 local function diamond(u,y,rx,ry,n)
  local pts={{u-rx,y},{u,y-ry},{u+rx,y},{u,y+ry}}
  face(p(pts[1][1],pts[1][2],n-.12),p(pts[2][1],pts[2][2],n-.12),
   p(pts[3][1],pts[3][2],n-.12),p(pts[4][1],pts[4][2],n-.12),'dark',.6)
  for i=1,4 do local j=i%4+1;line(pts[i][1],pts[i][2],pts[j][1],pts[j][2],n,.14,'gold',.9)end
  face(p(u-rx*.22,y,n+.04),p(u,y-ry*.40,n+.04),p(u+rx*.22,y,n+.04),p(u,y+ry*.40,n+.04),'gold',1)
 end
 local function infill(a,b,c,d)
  if c-a<1.7 or d-b<1.7 then return end
  panel(a,b,c,d,.12,'red',.58)
  rim(a,b,c,d,.30,.10,'gold',.70)
  rim(a+.34,b+.34,c-.34,d-.34,.33,.10,'dark',.8)
 end
 -- Cut the actual shell around apertures, not around a guessed centered door.
 local cuts={low,high}
 for _,o in ipairs(openings)do cuts[#cuts+1]=o.u-o.w/2;cuts[#cuts+1]=o.u+o.w/2 end
 table.sort(cuts)
 for i=1,#cuts-1 do
  local a,c=cuts[i],cuts[i+1];local mid=(a+c)/2
  if c-a>.001 then
   local segments={{0,H}}
   for _,o in ipairs(openings)do if mid>o.u-o.w/2 and mid<o.u+o.w/2 then
    local next={}
    for _,v in ipairs(segments)do
     if v[1]<o.b then next[#next+1]={v[1],math.min(v[2],o.b)}end
     if v[2]>o.t then next[#next+1]={math.max(v[1],o.t),v[2]}end
    end
    segments=next
   end end
   for _,v in ipairs(segments)do if v[2]>v[1] then
    panel(a,v[1],c,v[2],0,'dark',.65)
    if v[1]==0 then
     panel(a,0,c,math.min(2.1,v[2]),.10,'stone',.37)
     block(a,2.1,c,2.35,.12,.35,'gold',.66)
    end
    infill(a+.75,math.max(3.1,v[1]+1.5),c-.75,math.min(26.8,v[2]-1.4))
   end end
  end
 end
 for _,o in ipairs(openings)do
  local l,r=o.u-o.w/2,o.u+o.w/2
  if o.door then
   -- Opaque wood leaves, recessed inside the old luminous shop-door aperture.
   panel(l,0,r,22,-.56,'dark',.50)
   for _,sg in ipairs({-1,1})do
    local a=sg<0 and l+.35 or o.u+.10
    local c=sg<0 and o.u-.10 or r-.35
    block(a,.25,c,21.6,-.50,-.22,'wood',.95)
    rim(a+.12,.45,c-.12,21.35,.02,.18,'gold',.84)
    for _,range in ipairs({{1.2,6.1},{7.1,20.6}})do
     local b,d=range[1],range[2]
     panel(a+.52,b,c-.52,d,-.13,'wood',.88)
     bevel(a+.42,b-.1,c-.42,d+.1,.13,.30,'oak')
     rim(a+.38,b-.14,c-.38,d+.14,.22,.12,'gold',.84)
    end
    diamond((a+c)/2,15.2,math.min(1.3,(c-a)*.24),2.1,.26)
    local u=o.u+sg*.72
    block(u-.20,7.8,u+.20,12.1,.24,.32,'dark',.8)
    for _,y in ipairs({8.15,11.75})do block(u-.16,y-.12,u+.16,y+.12,.32,.63,'gold',.82)end
    block(u-.13,8.15,u+.13,11.75,.54,.72,'gold',1)
    for _,y in ipairs({3.5,18.5})do block(sg<0 and a or c-.13,y,sg<0 and a+.13 or c,y+1.0,.06,.25,'gold',.77)end
   end
   -- Jambs stay out of the aperture; narrow flutes echo the accepted interior.
   for _,u in ipairs({l-.95,r+.95})do
    block(u-.62,.2,u+.62,22.5,.04,.82,'dark',.63)
    for j=-1,1 do block(u+j*.33-.065,1.5,u+j*.33+.065,21.9,.82,.96,'gold',.85)end
    for _,y in ipairs({.3,1.05,22.2})do block(u-.82,y,u+.82,y+.32,.08,1.10,'gold',.77)end
   end
   block(l-1.9,22.6,r+1.9,23.05,.08,front and 2.3 or .85,'gold',.84)
   panel(l-1.25,23.25,r+1.25,26.7,.14,'red',.54)
   rim(l-1.45,23.08,r+1.45,26.9,.51,.19,'gold',.87)
   for j=-3,3 do
    line(o.u,23.55,o.u+j*(o.w/2+.45)/3,26.28,.45,.10,'gold',.88)
   end
   diamond(o.u,23.75,.43,.53,.58)
   if front then
    for j=-3,3 do
     Neon.front(G,p(o.u,23.75,.65),p(o.u+j*(o.w/2+.45)/3,26.28,.65),.12,'neonGold')
    end
   end
   block(l-.2,0,r+.2,.22,-.65,.85,'stone',.58)
   block(l-.2,.22,r+.2,.30,-.65,.9,'gold',.70)
   -- Attached lanterns; no poles, planters or props in the approach.
   for _,u in ipairs({l-2.6,r+2.6})do if u-.6>low and u+.6<high then
    block(u-.38,13.4,u+.38,19.4,.16,.75,'dark',.6)
    panel(u-.26,13.85,u+.26,18.95,.78,'glass',.91,true)
    for _,du in ipairs({-.34,.27})do block(u+du,13.65,u+du+.07,19.15,.76,.84,'gold',.9)end
    for _,y in ipairs({13.4,19.05})do block(u-.52,y,u+.52,y+.35,.10,.90,'gold',.8)end
   end end
  else
   panel(l,o.b,r,o.t,-.50,'glass',.82,true)
   for _,u in ipairs({l-.25,r-.10})do block(u,o.b-.4,u+.35,o.t+.5,-.55,.45,'dark',.85)end
   block(l-.35,o.t-.15,r+.35,o.t+.5,-.55,.52,'dark',.85)
   rim(l-.2,o.b-.2,r+.2,o.t+.25,.60,.14,'gold',.84)
   block(l-.6,o.b-.7,r+.6,o.b-.4,.05,.80,'stone',.49)
   block(l-.6,o.b-.4,r+.6,o.b-.18,.10,.88,'gold',.77)
   for _,du in ipairs({-o.w*.25,0,o.w*.25})do
    block(o.u+du-.075,o.b+.05,o.u+du+.075,o.t-.05,-.42,.03,'gold',.77)
   end
   block(l+.1,o.t-3.25,r-.1,o.t-3.06,-.42,.02,'gold',.77)
   -- Fanlight tracery above clear, tall panes.
   for j=-2,2 do line(o.u,o.t-3.0,o.u+j*(o.w/2-.45)/2,o.t-.40,.12,.13,'gold',.87)end
   block(l-.8,o.t+.65,r+.8,o.t+.98,.05,.79,'gold',.71)
   if r-l>5 then diamond(o.u,5.3,.58,.80,.51)end
  end
 end
 -- Low-profile fluted corner pilasters never extend into the adjacent shell.
 for _,u in ipairs({low+.75,high-.75})do
  block(u-.7,0,u+.7,H,.04,.65,'dark',.83)
  for j=-1,1 do block(u+j*.4-.055,2.7,u+j*.4+.055,27.4,.66,.78,'gold',.72)end
  for _,y in ipairs({.4,2.2,27.4,31.4})do block(u-.74,y,u+.74,y+.4,.1,.85,'gold',.8)end
 end
 -- Side and rear entablatures share the entry palette with a shallow profile.
 if not front then
  block(low,28,high,30.6,.05,.60,'red',.60)
  for _,y in ipairs({27.8,30.6,31.4})do block(low,y,high,y+.25,.08,.84,'gold',.73)end
 end
end

-- Continuous raised strokes, deliberately local to these two landmark signs.
local glyphs={
 C={{{1,.88},{.78,1},{.22,1},{0,.78},{0,.22},{.22,0},{.78,0},{1,.12}}},
 A={{{0,0},{.38,1},{.62,1},{1,0}},{{.2,.4},{.8,.4}}},
 S={{{1,.9},{.8,1},{.2,1},{0,.8},{0,.65},{.2,.5},{.8,.5},{1,.35},{1,.2},{.8,0},{.2,0},{0,.1}}},
 I={{{.12,1},{.88,1}},{{.5,1},{.5,0}},{{.12,0},{.88,0}}},
 N={{{0,0},{0,1},{1,0},{1,1}}},
 O={{{.2,0},{.8,0},{1,.2},{1,.8},{.8,1},{.2,1},{0,.8},{0,.2},{.2,0}}},
 P={{{0,0},{0,1},{.8,1},{1,.8},{1,.65},{.8,.5},{0,.5}}},
 R={{{0,0},{0,1},{.8,1},{1,.8},{1,.65},{.8,.5},{0,.5}},{{.50,.5},{1,0}}},
 Z={{{0,1},{1,1},{0,0},{1,0}}},
 E={{{1,1},{0,1},{0,0},{1,0}},{{0,.5},{.8,.5}}},
}
local function title(G,str,cx,cy,z,w,h)
 local glyphW=w/(#str+(#str-1)*.36);local left=cx-w/2
 for i=1,#str do for _,stroke in ipairs(assert(glyphs[str:sub(i,i)]))do
  for j=1,#stroke-1 do
   local a,b=stroke[j],stroke[j+1]
   G.beam({left+(i-1)*glyphW*1.36+a[1]*glyphW,cy+a[2]*h,z},
    {left+(i-1)*glyphW*1.36+b[1]*glyphW,cy+b[2]*h,z},h*.073,'gold',1)
   Neon.front(G,{left+(i-1)*glyphW*1.36+a[1]*glyphW,cy+a[2]*h,z+h*.055},
    {left+(i-1)*glyphW*1.36+b[1]*glyphW,cy+b[2]*h,z+h*.055},h*.052,
    str=='CASINO' and 'neonRose' or 'neonGold')
  end
 end end
end
function M.detail(G,s,H)
 local box,face,beam=G.box,G.face,G.beam
 local x0,x1,z0,z1=s.x0,s.x1,s.z0,s.z1;local cx=(x0+x1)/2;local W=x1-x0
 local casino=s.kind=='arcade';local depth=casino and 3.8 or 2.5
 local function pane(a,b,c,d,z,mat,t,glow)
  face({a,b,z},{c,b,z},{c,d,z},{a,d,z},mat,t,glow)
 end
 local function bulb(x,y,z,r)
  -- Eight facets are ample for these small stationary lamp bezels.
  for i=0,7 do local a,b=i*math.pi/4,(i+1)*math.pi/4
   local q={x+r*math.cos(b),y+r*math.sin(b),z}
   face({x,y,z},{x+r*math.cos(a),y+r*math.sin(a),z},q,q,'gold',.86)
  end
  -- A round luminous lens; color and gentle chase are independent of glass.
  for i=0,7 do local a,b=i*math.pi/4,(i+1)*math.pi/4;local rr=r*.80
   local q={x+rr*math.cos(b),y+rr*math.sin(b),z+.045}
   face({x,y,z+.045},{x+rr*math.cos(a),y+rr*math.sin(a),z+.045},q,q,'neonBulb',1.35)
  end
 end
 -- Raised fascia clears the door transoms; all overhangs stay inside TEST119's
 -- front projection and have a dark underside rather than a floating strip.
 box(x0+.15,27.65,z1+.02,x1-.15,28.1,z1+depth,'dark',.64)
 box(x0+.15,28.1,z1+.10,x1-.15,30.7,z1+depth,'red',.62)
 for _,y in ipairs({27.9,30.6})do box(x0+.15,y,z1+depth,x1-.15,y+.25,z1+depth+.25,'gold',.80)end
 box(x0+.15,30.9,z1+.10,x1-.15,31.3,z1+depth+.35,'dark',.75)
 box(x0+.15,31.3,z1+.10,x1-.15,31.6,z1+depth+.42,'gold',.83)
 for x=x0+3,x1-2,casino and 3.2 or 4.5 do bulb(x,29.35,z1+depth+.29,.25)end
 for x=x0+2,x1-1,4 do box(x-.28,30.85,z1+depth+.1,x+.28,31.3,z1+depth+.28,'gold',.70)end
 -- Brass coping ties the roof to the facade without widening the building.
 for _,x in ipairs({x0,x1-.35})do box(x,H+4,z0,x+.35,H+4.22,z1,'gold',.72)end
 for _,z in ipairs({z0,z1-.35})do box(x0,H+4,z,x1,H+4.22,z+.35,'gold',.72)end
 local half=math.min(W*.39,casino and 35 or 24)
 local bottom=H+1;local top=H+(casino and 14 or 10)
 box(cx-half,bottom,z1-3,cx+half,top,z1+.8,'gold',.79)
 box(cx-half+.4,bottom+.4,z1+.81,cx+half-.4,top-.4,z1+1.28,'red',.58)
 box(cx-half+1.3,bottom+1.3,z1+1.30,cx+half-1.3,top-1.3,z1+1.62,'dark',.57)
 local textH=casino and 7.7 or 4.7
 title(G,casino and 'CASINO' or 'PRIZES',cx,(bottom+top-textH)/2,z1+2.05,half*2-9,textH)
 Neon.frame(G,cx-half+1.65,bottom+1.65,cx+half-1.65,top-1.65,z1+1.88,.23,'neonCyan')
 -- Continuous cornice tubes, slimmer on the matching prize pavilion.
 for _,y in ipairs({28.1,30.65})do
  Neon.front(G,{x0+.75,y,z1+depth+.30},{x1-.75,y,z1+depth+.30},casino and .23 or .18,
   y<29 and 'neonRose' or 'neonCyan')
 end
 -- Corner light pairs echo the fluted brass pilasters and stay above foot traffic.
 for _,x in ipairs({x0+.45,x1-.45})do
  Neon.front(G,{x,5.0,z1+.9},{x,26.7,z1+.9},.22,'neonCyan')
 end
 for x=cx-half+1,cx+half-1,3 do bulb(x,bottom+.7,z1+1.40,.23);bulb(x,top-.7,z1+1.40,.23)end
 if casino then
  local cy=top+7
  box(cx-17,top-1,z1-5,cx+17,top+15,z1-1,'dark',.66)
  for i=-1,1 do local x=cx+i*10
   box(x-4.7,cy-5.5,z1-.9,x+4.7,cy+5.5,z1+.3,'gold',.82)
   pane(x-4.25,cy-5.05,x+4.25,cy+5.05,z1+.34,'dark',.70)
   pane(x-3.85,cy-4.6,x+3.85,cy+4.6,z1+.39,'cream',.98)
   beam({x-2.4,cy+3,z1+.53},{x+2.4,cy+3,z1+.53},.85,'red',.68)
   beam({x+2.4,cy+3,z1+.53},{x-1.6,cy-3,z1+.53},.85,'red',.68)
   Neon.front(G,{x-2.4,cy+3,z1+.99},{x+2.4,cy+3,z1+.99},.42,'neonRose')
   Neon.front(G,{x+2.4,cy+3,z1+.99},{x-1.6,cy-3,z1+.99},.42,'neonRose')
   Neon.frame(G,x-4.35,cy-5.15,x+4.35,cy+5.15,z1+.57,.20,'neonGold')
  end
  for i=-2,2 do local height=4+(2-math.abs(i))*2
   box(cx+i*5-1,top+15,z1-4,cx+i*5+1,top+15+height,z1-2,'gold',.87)
   Neon.front(G,{cx+i*5,top+15.4,z1-1.84},{cx+i*5,top+14.7+height,z1-1.84},.28,'neonGold')
  end
 else
  local y=top+3;local z=z1+.2
  box(cx-2.1,top-.1,z-.8,cx+2.1,y,z+.35,'dark',.66)
  box(cx-2.25,y-.25,z-.85,cx+2.25,y,z+.4,'gold',.80)
  box(cx-2.6,y,z-.4,cx+2.6,y+1,z+.4,'gold',.89)
  box(cx-.5,y+1,z-.2,cx+.5,y+3,z+.3,'gold',.9)
  face({cx-1,y+3,z+.5},{cx+1,y+3,z+.5},{cx+3,y+7,z+.5},{cx-3,y+7,z+.5},'gold',.94)
  Neon.front(G,{cx-1,y+3,z+.73},{cx-3,y+6.84,z+.73},.22,'neonGold')
  Neon.front(G,{cx-3,y+6.84,z+.73},{cx+3,y+6.84,z+.73},.22,'neonGold')
  Neon.front(G,{cx+3,y+6.84,z+.73},{cx+1,y+3,z+.73},.22,'neonGold')
  for _,sg in ipairs({-1,1})do
   beam({cx+sg*2.5,y+6,z+.4},{cx+sg*4,y+6,z+.4},.5,'gold',.88)
   beam({cx+sg*4,y+6,z+.4},{cx+sg*3,y+3.7,z+.4},.5,'gold',.88)
   beam({cx+sg*3,y+3.7,z+.4},{cx+sg*1.5,y+3.7,z+.4},.5,'gold',.88)
  end
 end
end
return M
