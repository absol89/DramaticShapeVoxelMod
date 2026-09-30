-- Role-specific details follow the actual facade openings supplied by CityArchitecture.
local V=...;local M={}
local towns={PALLET_TOWN=true,VIRIDIAN_CITY=true,PEWTER_CITY=true,CERULEAN_CITY=true,FUCHSIA_CITY=true,SAFFRON_CITY=true,CINNABAR_ISLAND=true}
function M.elevation(s,side,low,high,H,openings,block,panel)
 if not towns[s.map]then return end
 V.require('LandmarkRelief').elevation(s,side,low,high,H,openings,block,panel)
 for _,o in ipairs(openings)do
  local l,r=o.u-o.w/2,o.u+o.w/2
  if o.door then
   if s.map=='PEWTER_CITY' and (s.kind=='museum' or s.kind=='museum_wing' or s.kind=='gym')then
    -- Stone portal with fluted pilasters, capital blocks and a stepped lintel.
    for _,u in ipairs({l-1.8,r+1.8})do if u>low+1 and u<high-1 then
     block(u-.65,1,u+.65,25,.25,1.75,'stone',.97)
     for _,v in ipairs({-.32,.32})do block(u+v-.08,4,u+v+.08,22,1.75,1.83,'mortar',.86)end
     block(u-.9,1,u+.9,2.3,.25,2,'mortar',1)
     block(u-.9,23.5,u+.9,25,.25,2,'mortar',1)
    end end
    block(l-2.8,25.3,r+2.8,26.3,.2,3.5,'stone',1)
    block(l-2,26.3,r+2,27.1,.2,2.8,'mortar',1)
    for u=l-1.5,r+1.5,2.1 do block(u,24.8,u+.65,25.3,.4,3,'mortar',.95)end
   elseif s.map=='CINNABAR_ISLAND' then
    local lab=s.kind=='research_lab';local ruin=s.kind=='ruined_mansion'
    local mat=lab and 'blue' or ruin and 'dark' or 'red'
    block(l-1.8,24.3,r+1.8,25,.2,2.2,'stone',.92)
    block(l-1.3,25,r+1.3,25.5,.2,1.7,mat,.98)
    if lab then
     for _,u in ipairs({l-1.1,r+1.1})do
      block(u-.18,3,u+.18,22,.4,.8,'white',1)
      block(u-.65,15,u+.65,19.5,.45,1.2,'blue',.9)
      panel(u-.38,15.5,u+.38,19,1.24,'glass',1,true)
     end
    elseif ruin then
     for _,u in ipairs({l-2.2,r+2.2})do
      block(u-.7,1,u+.7,24,.2,1.2,'stone',.70)
      for y=4,22,5 do block(u-.8,y,u+.8,y+.28,.2,1.3,'dark',.65)end
     end
    end
   elseif s.map=='VIRIDIAN_CITY' then
    block(l-1.6,26,r+1.6,26.5,.25,4.2,'wood',1)
    for u=l-1,r+1,2.8 do block(u,26.5,u+1.2,26.85,.3,4.3,'green',.98)end
    for _,u in ipairs({l-.7,r+.7})do
     block(u-.16,23.2,u+.16,26,.65,1.05,'wood',.87)
     block(u-.17,25.1,u+.17,25.5,1.05,3.6,'wood',.87)
    end
    if s.kind=='school' then
     block(o.u-1.8,27.3,o.u+1.8,31,.2,1.1,'wood',.95)
     panel(o.u-1.1,28,o.u+1.1,30.3,1.15,'gold',1)
    end
   elseif s.map=='SAFFRON_CITY' and s.kind=='office_tower' then
    block(l-3,27.2,r+3,28.2,.4,5,'navy',1)
    block(l-3.2,28.2,r+3.2,28.65,.4,5.2,'gold',1)
    for _,u in ipairs({l-2,r+2})do
     block(u-.5,2,u+.5,26,.3,1.9,'dark',.85)
     block(u-.18,4,u+.18,25,1.9,1.95,'gold',1)
    end
   elseif s.map=='CERULEAN_CITY' then
    block(l-1.4,26,r+1.4,26.4,.2,3.5,'navy',1)
    for u=l-1,r+.8,2 do block(u,26.4,math.min(r+1,u+.9),26.65,.2,3.5,'white',1)end
   elseif s.map=='FUCHSIA_CITY' and (s.kind=='safari_gate' or s.kind=='meeting_hall')then
    for _,u in ipairs({l-2,r+2})do
     block(u-.55,1,u+.55,27,.25,1.6,'wood',1)
     for y=3,25,4 do block(u-.7,y,u+.7,y+.3,.2,1.75,'gold',.83)end
    end
    block(l-3,27,r+3,28,.2,3.5,'wood',1)
   end
  elseif o.b<24 then
   -- Leaf sprays replace the row of identical clipped cubes at street level.
   if s.kind~='office_tower' and s.kind~='arcade' and s.kind~='prize_shop'
      and not(s.map=='CINNABAR_ISLAND' and s.kind=='ruined_mansion') then
    for u=l+1,r-.8,3.1 do
     block(u-.18,5.6,u+.18,7.65,.8,1.15,'green',1)
     block(u-.72,6.1,u-.1,6.55,.65,1.7,'leaf',.94)
     block(u+.1,6.7,u+.72,7.15,.65,1.7,'leaf',1.02)
     if s.map=='CERULEAN_CITY' or s.map=='FUCHSIA_CITY' or s.map=='PALLET_TOWN' then
      block(u-.28,7.55,u+.28,7.95,.8,1.4,s.map=='CERULEAN_CITY' and 'white' or 'flower',1)
     end
    end
   end
  end
 end
 if s.map=='CERULEAN_CITY' and s.kind=='gym' then
  -- Continuous water motif above the glazing, legible on the long elevations.
  for u=low+3,high-4,6 do
   block(u,27,u+2.7,27.4,.3,.7,'blue',1)
   block(u+2.5,27.4,u+5.2,27.8,.3,.7,'white',1)
  end
 end
 if s.map=='CINNABAR_ISLAND' then
  if s.kind=='ruined_mansion' then
   -- Shallow chipped stone and narrow creeping vines, clear of openings.
   for _,u in ipairs({low+2,high-2})do for y=6,H-4,6 do
    block(u-.55,y,u+.4,y+.45,.17,.25,'dark',.74)
    if y<20 then block(u-.3,y+.7,u+.35,y+1.25,.18,.55,'leaf',.78)end
   end end
  elseif s.kind=='gym' then
   for u=low+3,high-5,8 do
    block(u,H-5,u+4.5,H-4.55,.2,.65,'terra',.8)
    block(u+1,H-4.55,u+3.5,H-4.1,.2,.65,'gold',.87)
   end
  end
 end
 if s.map=='SAFFRON_CITY' then
  for _,u in ipairs({low+2.1,high-2.1})do
   block(u-.15,H-6,u+.15,H-1.6,.25,1.3,'gold',1)
  end
 elseif s.map=='VIRIDIAN_CITY' or s.map=='FUCHSIA_CITY' then
  -- Climbing growth uses the narrow corner strips, clear of every opening.
  for _,u in ipairs({low+2.2,high-2.2})do
   local clear=true;for _,o in ipairs(openings)do if o.b<24 and math.abs(u-o.u)<o.w/2+1.4 then clear=false end end
   if clear then
    for y=4,15,2 do
     block(u-.12,y,u+.12,y+1.4,.45,.7,'wood',.8)
     block(u-.65+(y%4)*.18,y+.5,u+.35+(y%4)*.18,y+1.1,.65,1,'leaf',.94)
    end
   end
  end
 end
end
function M.roof(s,G,H)
 if not towns[s.map]then return end
 V.require('LandmarkRelief').roof(s,G,H)
 local a,b,c,d=s.x0,s.z0,s.x1,s.z1;local cx=(a+c)/2
 if s.map=='PALLET_TOWN' and s.kind=='oak_lab' then
  -- Small rooftop cold frame above the laboratory, safely within its footprint.
  local w=math.min(12,(c-a)*.24);local z=(b+d)/2
  G.box(cx-w,H+2,z-5,cx+w,H+3,z+5,'wood',.94)
  G.face({cx-w,H+3,z-5},{cx+w,H+3,z-5},{cx+w,H+8,z},{cx-w,H+8,z},'glass',.86)
  G.face({cx-w,H+8,z},{cx+w,H+8,z},{cx+w,H+3,z+5},{cx-w,H+3,z+5},'glass',.86)
  for x=cx-w,cx+w,4 do
   G.beam({x,H+3,z-5},{x,H+8,z},.35,'white',1)
   G.beam({x,H+8,z},{x,H+3,z+5},.35,'white',1)
  end
  G.beam({cx-w,H+8,z},{cx+w,H+8,z},.45,'blue',1)
  for _,x in ipairs({cx-w,cx+w})do
   G.face({x,H+3,z-5},{x,H+8,z},{x,H+3,z+5},{x,H+3,z+5},'glass',.8)
  end
 elseif s.map=='CINNABAR_ISLAND' and s.kind=='research_lab' then
  local z=(b+d)/2;local x=c-10
  G.box(x-3,H+1,z-3,x+3,H+2,z+3,'stone',.92)
  G.box(x-.45,H+2,z-.45,x+.45,H+12,z+.45,'dark',.8)
  for _,y in ipairs({H+5,H+8,H+11})do G.box(x-3,y,z-.15,x+3,y+.25,z+.15,'white',.95)end
  G.box(a+5,H+1,z-4,a+12,H+5,z+4,'white',.92)
  for u=a+6,a+11,1.3 do G.box(u,H+2,z+4.02,u+.45,H+4,z+4.15,'dark',.75)end
 elseif s.map=='SAFFRON_CITY' and s.kind=='office_tower' then
  for _,x in ipairs({a+3,c-3})do G.box(x-.5,30,d+.1,x+.5,H-2,d+.65,'gold',.9)end
 end
end
return M
