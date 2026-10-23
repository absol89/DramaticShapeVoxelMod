-- TEST18: healing halls, shopfronts and laboratories use their own structures.
-- Footprint and every entrance are inherited from the source placement.
local V=...;local M={};local min,max=math.min,math.max
function M.model(s,c)
 -- TEST38: Professor Oak's laboratory has its own dedicated design.
 if c.kind=='oak_lab'then return V.require('OakLab').model(s,c)end
 if not(c.clinic or c.kind=='mart'or c.lab)then return nil end
 local R=V.require('KantoRegionalKit').new(s,c);local K=R.K;local Ems=V.require('KantoEmblems')
 local x0,x1,z0,z1=s.x0,s.x1,s.z0,s.z1;local W,D=x1-x0,z1-z0;local cx,cz=(x0+x1)/2,(z0+z1)/2
 local f=c.name;local H=35;local v
 local u=cx;for _,d in ipairs(s.doors or{})do if(d.side or'front')=='front'then u=d.u or d.x;break end end
 local radius=min(7.4,W*.115);u=max(x0+radius+1,min(x1-radius-1,u))
 if c.clinic then
  local spec={h=H,wall=f=='quarry'and'ktSandstone'or f=='woodland'and'ktLime'or'ktPlaster',base=c.base,trim=f=='reserve'and'lvTimber'or c.trim,roof='ktTerracotta',window=19,levels={{9,23}}}
  if f=='woodland'or f=='village'then spec.hip=14;spec.roof=c.roof
  elseif f=='reserve'then spec.profile={{0,2},{.12,0},{.37,12},{.63,12},{.88,0},{1,2}};spec.roof='lvSlate'
  elseif f=='metropolitan'then spec.parapet=2.1;spec.roof='ktSteel'
  elseif f=='quarry'then spec.parapet=3;spec.roof='lvSlate'
  else spec.profile={{0,0},{.12,4},{.28,8},{.5,9.5},{.72,8},{.88,4},{1,0}};spec.tile=f~='volcanic'end
  v=R.volume(spec)
  local E=v.elevations.front
  -- A substantial civic cornice supports the crest, separate from the label.
  E.box(u-radius-2,33.9,u+radius+2,36.3,.28,1.12,'red',1)
  E.box(u-radius-2.2,36.3,u+radius+2.2,36.85,.25,1.26,c.trim,1.12)
  Ems.center(K,u,44.5,z1+1.48,radius,f=='reserve'and'lvTimber'or f=='quarry'and'ktBasalt'or'ktBronze')
  if f=='quarry'or f=='metropolitan'then
   local a,b=min(12,W*.19),min(9,D*.23)
   K.box(cx-a,H+.3,cz-b,cx+a,H+6,cz+b,c.trim,1)
   K.face({cx-a+.7,H+6.05,cz-b+.7},{cx+a-.7,H+6.05,cz-b+.7},{cx+a-.7,H+6.05,cz+b-.7},{cx-a+.7,H+6.05,cz+b-.7},'ktGlass',1)
   K.box(cx-.18,H+6.07,cz-b,cx+.18,H+6.5,cz+b,c.trim,1)
  end
 elseif c.kind=='mart'then
  H=34
  local spec={h=H,wall=f=='garden'and'ktBrick'or c.wall,base=c.base,trim=c.trim,roof=f=='woodland'and'green'or f=='reserve'and'lvSlate'or'ktMarine',window=27,levels={{7,23}}}
  if f=='reserve'then spec.profile={{0,1.5},{.12,0},{.40,9},{.60,9},{.88,0},{1,1.5}}
  elseif f=='woodland'then spec.profile={{0,0},{.25,7},{.75,7},{1,0}}
  elseif f=='garden'then spec.profile={{0,0},{.18,9},{.82,9},{1,0}};spec.roof='ktCopper'
  elseif f=='quarry'then spec.parapet=3;spec.roof='lvSlate'
  elseif f=='metropolitan'or f=='volcanic'then spec.profile={{0,0},{1,3.8}};spec.tile=false
  else spec.hip=10 end
  v=R.volume(spec)
  local E=v.elevations.front
  -- A broad folded awning and deep window displays make this a shop.
  E.box(x0+.3,26.3,x1-.3,27.0,2.65,3.1,'ktMarine',1)
  E.box(x0+.3,26.0,x1-.3,26.3,2.65,3.1,'extrim',1)
  K.face({x0+.3,28.3,z1+.25},{x1-.3,28.3,z1+.25},{x1-.3,27.0,z1+3.1},{x0+.3,27.0,z1+3.1},'ktMarine',1)
  for x=x0+1,x1-1,5.2 do
   K.face({x,28.34,z1+.25},{min(x+1.6,x1-.5),28.34,z1+.25},{min(x+1.6,x1-.5),27.04,z1+3.1},{x,27.04,z1+3.1},'extrim',1)
  end
  Ems.mart(K,u,44,z1+1.4,radius,'ktMarine',f=='reserve'and'lvTimber'or'ktBronze')
 else
  H=c.kind=='oak_lab'and 36 or 38
  local spec={h=H,wall=c.kind=='oak_lab'and'ktLime'or'ktPearl',base=c.base,trim=c.kind=='oak_lab'and'ktCedar'or'ktSteel',roof=c.kind=='oak_lab'and'ktCopper'or'ktSteel',window=25,levels={{10,25}},tile=false}
  -- A high glazed monitor, unlike either the Center roof or the Mart awning.
  spec.profile={{0,0},{.30,6},{.31,12},{.69,12},{.70,6},{1,0}}
  spec.roofGlazing={[2]=true,[4]=true}
  v=R.volume(spec)
  for z=z0+1,z1-1,5.4 do
   for _,t in ipairs({.305,.695})do local x=x0+W*t
    K.box(x-.18,H+6,z-.16,x+.18,H+12.2,z+.16,c.trim,1)
   end
  end
  Ems.research(K,u,H+5.3,z1+1.2,min(4.8,W*.075))
  -- A roof instrument and ribbed extractor stay behind the public entrance.
  local x=x0+W*.81;local y=H+6.1;local z=z0+D*.30
  K.box(x-2.7,H+1,z-2.7,x+2.7,y+4.7,z+2.7,'ktSteel',1)
  for j=0,3 do K.box(x-2.2,y+.4+j*.9,z+2.73,x+2.2,y+.68+j*.9,z+2.92,'ktBasalt',1)end
  if c.kind~='oak_lab'then
   K.beam({x0+W*.17,H+3,z0+D*.3},{x0+W*.17,H+13,z0+D*.3},.45,'ktSteel',1)
   for j=0,2 do K.beam({x0+W*.17-2+j*.4,H+8+j*2,z0+D*.3},{x0+W*.17+2-j*.4,H+8+j*2,z0+D*.3},.25,'ktPearl',1)end
  end
 end
 -- Window-level treatment is handled by the regional kit, with all portals cut.
 R.sign();return R.G.out
end
return M
