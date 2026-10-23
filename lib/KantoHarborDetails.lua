-- Preserve Vermilion's approved shells and coastal colors; add one resident cue.
local V=...;local M={}
local function append(mesh,s)
 if s.map~='VERMILION_CITY'or s.kind=='gym'or s.style=='center'or s.style=='mart'or s.style=='club'then return mesh end
 local K=V.require('KantoArchitectureKit').new(s);local G=K.G
 local x0,x1,z1=s.x0,s.x1,s.z1;local W=x1-x0
 local door=(s.doors or{})[1];local x=door and(door.u or door.x)or(x0+x1)/2
 local y=s.style=='townhouse'and 37 or 31.5;local z=z1+1.30
 local dest=s.destination or''
 if dest:find('OLD_ROD',1,true)then
  K.ring(x,y,z,2.5,.24,'wood','xy',20);G.disc(x,y,z+.10,.48,'gold',1)
  for i=0,7 do local a=i*math.pi/4;G.beam({x+math.cos(a)*.5,y+math.sin(a)*.5,z+.11},{x+math.cos(a)*3.1,y+math.sin(a)*3.1,z+.11},.16,'wood',1)end
 elseif dest:find('TRADE',1,true)then
  local E=K.elevation('front',x0,x1,z1,35)
  E.poly({{x-3.2,y+1},{x+1,y+1},{x+1,y+2},{x+3.2,y+.1},{x+1,y-1},{x+1,y},{x-3.2,y}},1.42,'gold',.95)
  E.poly({{x+3.2,y-1.5},{x-1,y-1.5},{x-1,y-.5},{x-3.2,y-2.4},{x-1,y-3.5},{x-1,y-2.5},{x+3.2,y-2.5}},1.42,'white',1)
 elseif dest:find('PIDGEY',1,true)then
  -- A small maritime bird loft: paired entry holes, perch and pitched hood.
  G.box(x-3.2,29,z1+.35,x+3.2,35.2,z1+.88,'wood',1)
  for _,u in ipairs({x-1.4,x+1.4})do G.disc(u,32.8,z1+.93,.82,'dark',1)end
  G.box(x-3.6,28.7,z1+.4,x+3.6,29.2,z1+1.55,'blue',1)
  for _,sg in ipairs({-1,1})do
   G.face({x,37,z1+.3},{x+sg*3.8,35.1,z1+.3},{x+sg*3.8,35.1,z1+1.15},{x,37,z1+1.15},'slate',1)
  end

 else
  G.disc(x,y,z,2.3,'wood',1);K.ring(x,y,z+.10,1.75,.18,'gold','xy',20)
  G.face({x-1.1,y-.4,z+.2},{x+1.1,y-.4,z+.2},{x,y+1.1,z+.2},{x,y+1.1,z+.2},'white',1)
 end
 for _,q in ipairs(G.out)do mesh[#mesh+1]=q end
 return mesh
end
function M.append(mesh,s)
 mesh=append(mesh,s)
 if s.map=='VERMILION_CITY'and s.style=='mart'then
  local K=V.require('KantoArchitectureKit').new(s)
  V.require('KantoEmblems').mart(K,(s.x0+s.x1)/2,44,s.z1+2.5,5.7,'navy','white')
  for _,q in ipairs(K.G.out)do mesh[#mesh+1]=q end
 end
 return V.require('KantoExteriorMaterials').apply(mesh,s)
end
return M
