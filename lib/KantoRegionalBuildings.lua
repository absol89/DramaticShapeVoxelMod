-- TEST18: individual house silhouettes and regional construction details.
-- Regional homes resolve here; civic buildings have a dedicated builder.
-- Gyms, Lavender, Vermilion and landmarks keep their own architectural systems.
local V=...;local M={};local min,max=math.min,math.max
function M.model(s,c)
 local R=V.require('KantoRegionalKit').new(s,c);local K=R.K
 local x0,x1,z0,z1=s.x0,s.x1,s.z0,s.z1;local W,D=x1-x0,z1-z0;local cx,cz=(x0+x1)/2,(z0+z1)/2
 local f=c.name;local cut=R.split(c.variant%2==0 and .64 or .36)
 local function pair(main,wing)
  -- Resident identity governs the silhouette; several houses are full-width
  -- cottages/halls instead of every address receiving the same split block.
  local single=(f=='village'and c.kind=='rival_house')or(f=='woodland'and c.cupola)
   or(f=='quarry'and c.variant%2==1)or(f=='reserve'and(c.kind=='meeting_hall'or c.fishing))
   or(f=='metropolitan'and c.oculus)
  if single then
   if f=='village'then main.profile=nil;main.hip=18 end
   if f=='quarry'then main.profile={{0,0},{.5,c.rise},{1,0}};main.parapet=nil end
   if f=='woodland'then main.profile=nil;main.hip=18 end
   return R.volume(main)
  end
  if cut then
   local mirror=c.variant%2==1 and not(c.clinic or c.shop or c.lab)
   if mirror then wing.x0=x0;wing.x1=cut;main.x0=cut;main.x1=x1
   else main.x0=x0;main.x1=cut;wing.x0=cut;wing.x1=x1 end
   local peak=wing.h;for _,p in ipairs(wing.profile or{})do peak=max(peak,wing.h+p[2])end
   main.windowAbove=peak+6
   return R.volume(main),R.volume(wing)
  end
  return R.volume(main)
 end
 local function profile(r,center)return{{0,0},{center or .5,r},{1,0}}end
 local function roofbox(x,y,z,w,d,h,mat)
  K.box(x-w/2,y,z-d/2,x+w/2,y+h,z+d/2,mat,1)
  K.box(x-w/2-.35,y+h,z-d/2-.35,x+w/2+.35,y+h+.45,z+d/2+.35,'ktSteel',1.1)
 end
 if f=='village'then
  -- Clapboard farmhouse with an attached lower lean-to and a brick chimney.
  local main,wing=pair({h=c.lab and 36 or 33,profile=profile(c.lab and 13 or 17),wall=c.kind=='rival_house'and'blue'or'cream',trim='white',roof=c.roof},
   {h=32,profile={{0,9},{1,0}},wall=c.variant%2==0 and'cream'or'white',trim='white',roof=c.roof,window=14})
  R.chimney(main,'ktBrick')
  local a=main.bounds;local E=main.elevations.front;local u=(a.x0+a.x1)/2
  if not main.hip then E.box(u-2.3,main.h+5,u+2.3,main.h+8,.07,.31,'ktCedar',.86)
  for x=u-1.7,u+1.8,.85 do E.box(x-.11,main.h+5.3,x+.11,main.h+7.7,.33,.52,'white',1.05)end end
  for _,x in ipairs({a.x0+1.3,a.x1-1.3})do
   E.beam(x,main.h-3.6,x,main.h-1,.45,.46,'white',1)
  end
  if c.lab then
   -- A glazed rooftop research lantern on the lean-to, not a house cupola.
   local v=wing or main;local a=v.bounds;local x=(a.x0+a.x1)/2;local y=43;local w=min(14,(a.x1-a.x0)-5)
   local bottom=min(R.roofHeight(v,x-w/2),R.roofHeight(v,x+w/2))-.4
   y=max(y,max(R.roofHeight(v,x-w/2),R.roofHeight(v,x+w/2))+.5)
   roofbox(x,bottom,cz,w,min(21,D*.42),y+5-bottom,'ktCedar')
   K.face({x-w/2+.8,y+.7,cz+min(21,D*.42)/2+.06},{x+w/2-.8,y+.7,cz+min(21,D*.42)/2+.06},{x+w/2-.8,y+4.3,cz+min(21,D*.42)/2+.06},{x-w/2+.8,y+4.3,cz+min(21,D*.42)/2+.06},'ktGlass',1)
  end
 elseif f=='woodland'then
  -- Substantial cedar lodge, steep main roof and a separate lower green gable.
  local main,wing=pair({h=c.cupola and 37 or 34,profile=profile(c.cupola and 22 or 19,c.variant%2==0 and .48 or .65),wall=c.variant%2==0 and'ktCedar'or'ktSage',trim='lvTimber',roof='green',window=16},
   {h=31,profile=profile(10,.54),wall='ktOchre',trim='lvTimber',roof='green',window=13})
  R.chimney(main,'ktSandstone')
  local E=main.elevations.front;local a=main.bounds;local u=(a.x0+a.x1)/2;local y=main.h+7
  E.box(u-3,y,u+3,y+4,.06,.34,'dark',.9)
  for x=u-2.4,u+2.5,1.2 do E.box(x-.15,y+.3,x+.15,y+3.7,.36,.57,'ktCedar',1.1)end
  if c.cupola then
   local h=main.h+18;roofbox(u,h-3,cz,9,9,7,'ktCedar')
   K.G.disc(u,h+1,cz+4.57,2.7,'ktLime',1)
   K.beam({u,h+1,cz+4.65},{u,h+2.65,cz+4.65},.22,'dark',1)
   K.beam({u,h+1,cz+4.65},{u+1.1,h+.4,cz+4.65},.22,'dark',1)
  end
 elseif f=='quarry'then
  -- Broad quarry-stone blocks and weighty layered parapets. No cottage roof.
  local main,wing=pair({h=c.clinic and 39 or 36,parapet=3.4,wall='ktSandstone',trim='ktBasalt',roof='lvSlate',window=13},
   {h=31,parapet=2.2,wall=c.variant%2==0 and 'ktOchre'or 'ktLime',trim='ktBasalt',roof='lvSlate',window=12})
  for _,v in ipairs(R.volumes)do local a=v.bounds;local y=v.h+3.5
   if not v.profile then K.box(a.x0-.6,y,a.z0-.6,a.x1+.6,y+.65,a.z1+.6,'ktSandstone',1.10)end
   -- Solid cap is above the roof; the void beneath is an enclosed attic.
   local E=v.elevations.front
   for _,x in ipairs({a.x0+1.4,a.x1-1.4})do
    E.box(x-.65,7,x+.65,v.h-1,.25,.86,'ktBasalt',.95)
    E.box(x-.86,v.h-1,x+.86,v.h+.15,.15,.91,'ktSandstone',1.15)
   end
  end
  if not main.profile then
   local a=main.bounds;local u=(a.x0+a.x1)/2;local hw=min(6,(a.x1-a.x0)*.18);local hd=min(5,D*.16)
   roofbox(u,main.h+4.2,cz,hw*2+1.2,hd*2+1.2,3,'ktBasalt')
   K.face({u-hw,main.h+7.72,cz-hd},{u+hw,main.h+7.72,cz-hd},{u+hw,main.h+7.72,cz+hd},{u-hw,main.h+7.72,cz+hd},'ktGlass',1)
  else R.chimney(main,'ktSandstone')end
 elseif f=='waterfront'then
  -- White canal villas: offset heights, blue lintels, usable-looking terraces
  -- and timber shade pergolas. Wide low windows replace the former arches.
  local main,wing=pair({h=34,parapet=2.0,hip=c.roofKind=='hip'and 12 or nil,profile=c.roofKind=='gable'and profile(15)or c.roofKind=='mansard'and{{0,0},{.20,11},{.80,11},{1,0}}or nil,wall='ktPlaster',trim='ktMarine',roof=c.roof,window=21},
   {h=31,parapet=.8,wall=c.variant%2==0 and 'ktPearl'or 'ktMarine',trim='white',roof='ktPearl',window=17})
  R.terrace(wing or main,'ktMarine',not c.clinic)
  local a=main.bounds;local u=(a.x0+a.x1)/2;local E=main.elevations.front
  E.box(a.x0+.6,main.h-2,a.x1-.6,main.h-1.2,.07,.75,'ktMarine',1.05)
  if c.badge or c.lab then
   local y=main.h-4.5
   E.box(u-4,y-3,u+4,y+3,.03,.4,'ktPlaster',1)
   K.G.disc(u,y,z1+.46,2.4,'ktMarine',1)
   K.ring(u,y,z1+.56,2.0,.24,'white','xy',24)
  end
  if c.lab then roofbox(u,main.h+.25,z0+D*.35,13,min(12,D*.35),6,'ktSteel')end
 elseif f=='garden'then
  if c.kind=='diner'then
   -- A low corner diner, broad horizontal shopfront and striped fabric awning.
   local main,wing=pair({h=35,wall='ktBrick',trim='ktLime',roof='ktCopper',parapet=1.1,window=24,levels={{8,23}}},
    {h=31,wall='ktLime',trim='ktCedar',roof='ktCopper',parapet=1.0,window=21,levels={{8,22}}})
   K.box(x0-.45,27.9,z1+.2,x1+.45,28.35,z1+3.2,'ktLime',1)
   for x=x0,x1-1,5 do K.face({x,28.4,z1+.4},{min(x+2.4,x1),28.4,z1+.4},{min(x+2.4,x1),28.4,z1+3.1},{x,28.4,z1+3.1},'red',1)end
  else
   -- Asymmetric garden townhouses: a tall brick wing and lower roof garden.
   local main,wing=pair({h=c.kind=='hotel'and 57 or c.clinic and 39 or 53,wall='ktBrick',trim='ktLime',roof='ktCopper',parapet=1.3,hip=c.roofKind=='hip'and 11 or nil,profile=c.roofKind=='mansard'and{{0,0},{.18,12},{.82,12},{1,0}}or c.roofKind=='gable'and profile(15)or nil,window=c.kind=='hotel'and 13 or 18},
    {h=c.shop and 32 or 32+c.variant*1.5,wall=c.wall,trim='ktCedar',roof='ktCopper',parapet=.8,window=17})
   R.terrace(wing or main,'ktCedar',true)
   local a=main.bounds;local y=main.h+.3
   -- Copper crown follows the actual roof instead of a floating flat slab.
   if not main.profile and not main.hip then
    K.box(a.x0-.65,y,a.z0-.65,a.x1+.65,y+.7,a.z1+.65,'ktCopper',1.08)
   end
   if c.kind=='hotel'then
    local E=main.elevations.front
    for _,o in ipairs(E.openings)do if o.b>30 then
     E.box(o.u-o.w/2-.5,o.b-.8,o.u+o.w/2+.5,o.b-.2,.08,1.15,'ktBronze',1)
     E.beam(o.u-o.w/2,o.b+2.4,o.u+o.w/2,o.b+2.4,1.13,.35,'ktBronze',1)
    end end
   end

  end
 elseif f=='reserve'then
  -- Minka-inspired timber halls: articulated flared eaves, lattice screens,
  -- low attached wing and a capped ridge rather than a European gabled house.
  local lift=c.kind=='meeting_hall'and 15 or c.variant%2==0 and 11 or 14
  local p={{0,2},{.14,0},{.38,lift},{.62,lift},{.86,0},{1,2}}
  local main,wing=pair({h=c.kind=='meeting_hall'and 36 or 33,profile=p,wall=c.wall=='ktLime'and 'ktOchre'or c.wall,trim='lvTimber',roof=c.roof,window=19},
   {h=31,profile={{0,8},{.77,0},{1,1.2}},wall='ktLime',trim='lvTimber',roof=c.roof,window=16})
  local a=main.bounds;local u=(a.x0+a.x1)/2;local y=main.h+lift+.5
  K.box(u-1,y,z0-.7,u+1,y+.7,z1+.7,'lvSlate',1.08)
  for z=z0+.7,z1,3.2 do K.box(u-1.08,y+.72,z-.28,u+1.08,y+1.04,z+.28,'ktBasalt',1)end
  if c.kind=='meeting_hall'then
   local E=main.elevations.front
   for _,o in ipairs(E.openings)do if o.door then
    E.box(o.u-o.w/2-2.2,28.8,o.u+o.w/2+2.2,30,.08,2.45,'ktCedar',1.1)
    for _,sg in ipairs({-1,1})do local x=o.u+sg*(o.w/2+1.4)
     E.beam(x,26.7,x+sg*1.7,28.8,.85,.55,'lvTimber',1)
    end
   end end
  end
  -- Continuous outward-facing rafters below eaves, all above walk clearance.
  for _,v in ipairs(R.volumes)do local E=v.elevations.front
   for x=v.bounds.x0+1.2,v.bounds.x1-1,3.3 do E.box(x-.19,v.h-1.15,x+.19,v.h-.60,.12,.88,'ktCedar',1.08)end
  end
 elseif f=='metropolitan'then
  -- Concrete/steel urban blocks: ribbon glazing, stepped height and inset
  -- rooftop utility pavilion. Residential volumes are deliberately taller.
  local main,wing=pair({h=54+c.variant,profile=c.roofKind=='mansard'and{{0,0},{.18,12},{.82,12},{1,0}}or nil,wall=c.wall,trim='ktSteel',roof=c.roofKind=='mansard'and'ktMarine'or'ktObsidian',parapet=1.5,window=c.oculus and 12 or 18+c.variant*3},
   {h=c.clinic and 32 or 34,wall='ktObsidian',trim='ktSteel',roof='ktSteel',parapet=1.0,window=25})
  local a=main.bounds;local half=min(8,(a.x1-a.x0)*.25);local u=(a.x0+a.x1)/2
  if not main.profile then roofbox(u,main.h+.25,z0+D*.30,half*2,min(16,D*.38),7,'ktSteel')end
  for _,v in ipairs(R.volumes)do local E=v.elevations.front
   for _,o in ipairs(E.openings)do if not o.door then
    E.box(o.u-o.w/2-.6,o.t+1.1,o.u+o.w/2+.6,o.t+1.55,.08,.94,'ktObsidian',1.05)
   end end
  end
  if wing then R.terrace(wing,'ktSteel',false)end
  if c.oculus then
   local E=main.elevations.front
   K.G.disc(u,main.h-8,z1+.8,4.0,'ktViolet',1)
   K.ring(u,main.h-8,z1+.9,3.5,.45,'ktBronze','xy',24)
   K.G.disc(u,main.h-8,z1+1,1.1,'gold',1)
  end
 elseif f=='volcanic'then
  -- Basalt plinths and marine metal above; two sloping research/coastal sheds.
  -- Cinnabar's laboratory gets a sawtooth clerestory instead of a cottage roof.
  local main,wing=pair({h=34,profile=c.lab and {{0,0},{.43,10},{.48,3},{1,12}}or{{0,0},{1,11}},roofGlazing=c.lab and {[2]=true}or nil,wall='ktPearl',trim='ktBasalt',roof='ktSteel',tile=false,window=25},
   {h=31,profile={{0,8},{1,0}},wall='ktMarine',trim='ktBasalt',roof='ktSteel',tile=false,window=20})
  -- Raised standing seams follow the actual sloping roof planes.
  for _,v in ipairs(R.volumes)do local a=v.bounds;local p=v.profile
   for i=1,#p-1 do local aa,bb=p[i],p[i+1]
    if bb[1]>aa[1]then
     for z=a.z0+1,a.z1-1,5 do K.beam({a.x0+(a.x1-a.x0)*aa[1],v.h+aa[2]+.30,z},{a.x0+(a.x1-a.x0)*bb[1],v.h+bb[2]+.30,z},.25,'ktSteel',1.13)end
    else
     local x=a.x0+(a.x1-a.x0)*aa[1]
     K.face({x,v.h+bb[2],a.z0},{x,v.h+aa[2],a.z0},{x,v.h+aa[2],a.z1},{x,v.h+bb[2],a.z1},'ktGlass',1)
    end
   end
  end
  local a=main.bounds;local u=a.x0+(a.x1-a.x0)*.27
  local bottom=min(R.roofHeight(main,u-3),R.roofHeight(main,u+3))-.4
  local y=max(R.roofHeight(main,u-3),R.roofHeight(main,u+3))+.4
  roofbox(u,bottom,z0+D*.35,6,7,y+4-bottom,'ktBasalt')
  for i=0,3 do K.box(u-2.3,y+.5+i*.8,z0+D*.35+3.51,u+2.3,y+.72+i*.8,z0+D*.35+3.72,'ktSteel',1.1)end
 end
 R.sign();return R.G.out
end
return M
