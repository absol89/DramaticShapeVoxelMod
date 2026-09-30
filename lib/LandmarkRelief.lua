-- Shallow, static architectural relief. No new pedestrian footprint.
local M={}
function M.elevation(s,side,low,high,H,openings,block,panel)
 if s.map=='PEWTER_CITY'and(s.kind=='museum'or s.kind=='museum_wing'or s.kind=='gym')then
  -- High relief stays above doors/windows and within the existing facade bays.
  local y=H-4.2
  for u=low+3,high-4,4.5 do
   local clear=true;for _,o in ipairs(openings)do if u<o.u+o.w/2+1 and u+2.4>o.u-o.w/2-1 and y<o.t+1 then clear=false end end
   if clear then
    block(u,y,u+2.4,y+.55,.18,.7,'mortar',.95)
    if s.kind=='gym'then
     block(u+.2,y+.7,u+2.15,y+1.1,.2,.9,'stone',.82)
     panel(u+.8,y+1.1,u+1.6,y+1.8,.94,'slate',1)
    else
     for j=0,2 do block(u+.2+j*.8,y+.65,u+.55+j*.8,y+1.35,.25,.75,'stone',1)end
    end
   end
  end
  return
 elseif s.map=='CERULEAN_CITY'and(s.kind=='gym'or s.kind=='bike_shop')then
  for _,o in ipairs(openings)do local y=o.t+1.4
   if y+1.2<H-1 and o.u-o.w/2>low+1 and o.u+o.w/2<high-1 then
    block(o.u-o.w/2,y,o.u+o.w/2,y+.3,.15,.55,'navy',.9)
    for j=0,5 do local u=o.u-o.w/2+.3+j*(o.w-.8)/6
     local yy=y+.5+math.sin(j*1.1)*.25
     panel(u,yy,u+.45,yy+.30,.58,'white',1)
    end
   end
  end
  return
 end
 if s.map~='CINNABAR_ISLAND' or s.kind~='ruined_mansion'then return end
 -- Individually weathered wall courses: exclude the complete window/door
 -- rectangle including trim, and keep the joints above the ground plane.
 local function clear(a,b,c,d)
  for _,o in ipairs(openings)do
   if a<o.u+o.w/2+1.2 and c>o.u-o.w/2-1.2 and b<o.t+1.4 and d>o.b-1 then return false end
  end
  return true
 end
 for row=0,math.floor((H-8)/4)do
  local y=6+row*4
  for col=0,math.floor((high-low-7)/6)do
   local a=low+2+col*6;local n=(col*17+row*23+#side*11)%19
   local w=2.2+(n%4)*.6;local b=y+.4+(n%3)*.3
   if n<11 and clear(a,b,a+w,b+1.5)then
    panel(a,b,a+w,b+1.3,.025,'stone',.62+(n%5)*.035)
    block(a+.15,b+.15,a+w-.3,b+.24,.04,.13,'dark',.61)
    if n%3==0 then block(a+.4,b+.25,a+.53,b+.93,.04,.10,'dark',.65)end
   end
  end
 end
 -- Subtle damp courses at the foot of the walls, with real door gaps.
 for u=low+2,high-4,3.5 do if clear(u,.9,u+2.8,3.8)then
  panel(u,.9,u+2.8,2.7+(math.floor(u)%3)*.35,.03,'stone',.68)
 end end
end
function M.roof(s,G,H)
 if s.map~='PEWTER_CITY'then return end
 local kind=s.kind
 if kind~='museum' and kind~='museum_wing' and kind~='gym'then return end
 local a,c,z=s.x0,s.x1,s.z1;local cx=(a+c)/2
 -- Distinct plaques occupy the high corner bays, away from the center sign.
 for _,x in ipairs({a+6.4,c-6.4})do
  local y=H-7.5
  G.box(x-3.2,y-3,z+.6,x+3.2,y+3.4,z+1.15,'dark',.78)
  G.box(x-2.85,y-2.65,z+1.15,x+2.85,y+3.05,z+1.35,'stone',.87)
  if kind=='museum'then
   -- Ribbed ammonite spiral, recognisable even without reading its label.
   for i=0,23 do
    local t=i*.40;local u=t+.40;local r=2.35*(1-i/28);local rr=2.35*(1-(i+1)/28)
    G.beam({x+math.cos(t)*r,y+math.sin(t)*r,z+1.55},{x+math.cos(u)*rr,y+math.sin(u)*rr,z+1.55},.24,'mortar',1.12)
   end
  elseif kind=='museum_wing'then
   -- A triplet of mineral crystals gives the Gallery a different emblem.
   for i=-1,1 do
    local u=x+i*1.45;local top=y+1.4+(i==0 and 1.05 or 0)
    G.face({u-.57,y-1.65,z+1.42},{u+.57,y-1.65,z+1.42},{u+.57,top-.65,z+1.42},{u-.57,top-.65,z+1.42},'slate',.91)
    G.face({u-.57,top-.65,z+1.42},{u+.57,top-.65,z+1.42},{u,top,z+1.42},{u,top,z+1.42},'mortar',1.08)
    G.beam({u,y-1.65,z+1.48},{u,top-.60,z+1.48},.12,'white',.86)
   end
  else
   -- Quarry strata, with an angular stone badge in the middle.
   for i=-2,2 do G.box(x-2.6,y+i*.8,z+1.4,x+2.6,y+i*.8+.26,z+1.6,i%2==0 and 'mortar' or 'terra',.8)end
   G.face({x-1.7,y,z+1.75},{x,y+2,z+1.75},{x+1.7,y,z+1.75},{x,y-1.8,z+1.75},'gold',.93)
  end
 end
 if kind=='museum_wing'then
  -- Low display lantern: maintains the wing's lower silhouette than Museum.
  local w=math.min(13,(c-a)*.18);local b=s.z0;local d=s.z1
  G.box(cx-w,H+1,b+(d-b)*.3,cx+w,H+5,b+(d-b)*.7,'stone',.95)
  G.face({cx-w+.6,H+5.05,b+(d-b)*.3+.6},{cx+w-.6,H+5.05,b+(d-b)*.3+.6},{cx+w-.6,H+5.05,b+(d-b)*.7-.6},{cx-w+.6,H+5.05,b+(d-b)*.7-.6},'glass',.8)
  for x=cx-w+2,cx+w-1,3 do G.box(x-.15,H+5.1,b+(d-b)*.3,x+.15,H+5.4,b+(d-b)*.7,'mortar',1)end
 end
end
return M
