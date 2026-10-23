-- TEST19: four small-footprint waterfront palms, baked into the terrain cache.
-- Authored against Cinnabar's source layout, then checked against the live map.
local V=...;local M={REVISION='cinnabar-far-bank-palms-21'}
local pi=math.pi
local function key(x,z)return (z+64)*4096+x+64 end
function M.enabled(map,roads)
 return roads and map.id=='CINNABAR_ISLAND' and map.tileset.id=='OVERWORLD'
end
function M.plan(map,S)
 local out={}
 if not M.enabled(map,V.require('CommunityVisuals').customRoads())then return out end
 local P=S.cinnabarFurniture90 or V.require('CinnabarPromenade').plan(map,S,key)
 S.cinnabarFurniture90=P
 local A=V.require('DistrictAccess');local access=P.access
 -- Three southern shore palms and one in the broad eastern courtyard.
 -- The northern Mansion/Gym dock alley and all building approaches stay open.
 for i,p in ipairs({{148,220,34,.3},{220,220,38,2.2},{296,220,33,4.0},{296,108,35,5.4}})do
  local x,z=p[1],p[2];local q={x-4,z-4,x+4,z+4};local safe=true;local h
  if access.actorBlocked(q) or access.routeBlocked(q)then safe=false end
  for _,f in ipairs(P.features)do
   if A.overlap(q,f.bounds,4) or f.approach and A.overlap(q,f.approach,4)then safe=false end
  end
  for tz=math.floor(q[2]/8),math.floor((q[4]-.001)/8)do for tx=math.floor(q[1]/8),math.floor((q[3]-.001)/8)do
   local k=key(tx,tz);local s=S.shapeAt[k]
   if not s or s.class~='ground' or not s.flat or S.skip[k] or S.tileAt[k]==60 or S.tileAt[k]==91 then safe=false
   elseif h and math.abs(h-(s.h or 0))>.01 then safe=false else h=s.h or 0 end
  end end
  -- The entire crown envelope avoids buildings, signs and map connections.
  for tz=math.floor((z-19)/8),math.floor((z+19)/8)do for tx=math.floor((x-19)/8),math.floor((x+19)/8)do
   local s=S.shapeAt[key(tx,tz)]
   if tx<0 or tz<0 or tx>=map.def.width*4 or tz>=map.def.height*4
      or s and (s.class=='building' or s.class=='signpost')then safe=false end
  end end
  if safe then out[#out+1]={cx=x,cz=z,h=h or 0,height=p[3],angle=p[4],variant=i,bounds=q}end
 end
 return out
end
function M.borderPlan(map,S)
 local out={}
 if not M.enabled(map,V.require('CommunityVisuals').customRoads())then return out end
 local coast=V.require('CinnabarCoast');local height=map.def.height*32
 -- Eight palms outside the body: a row across the water, behind the pillars.
 -- The row leaves the north/east route connections and the corner clear.
 local sites={}
 for i=0,3 do sites[#sites+1]={-16,48+i*72}end
 for i=0,3 do sites[#sites+1]={48+i*72,height+16}end
 for i,site in ipairs(sites)do
  local x,z=site[1],site[2];local safe=true;local base
  for tz=math.floor((z-4)/8),math.floor((z+3.999)/8)do
   for tx=math.floor((x-4)/8),math.floor((x+3.999)/8)do
    if not coast.outerStripAt(map,S,key,tx,tz)then safe=false else
     local s=S.shapeAt[key(tx,tz)];local y=S.skip[key(tx,tz)]and 0 or(s.h or 0)
     if base and math.abs(y-base)>.01 then safe=false end;base=y
    end
   end
  end
  if safe then out[#out+1]={cx=x,cz=z,h=base or 0,height=({36,32,38,34})[(i-1)%4+1],
   angle=i*1.7,variant=i+4,borderBounds={x-19,z-19,x+19,z+19}}end
 end
 return out
end
function M.model(p)
 local out={};local height=p.height or 35;local seed=p.variant or 1;local rot=p.angle or 0
 local function face(a,b,c,d,mat,t,uv)
  V.require('BuildBudget').tick()
  local q={a,b,c,d,own=true,referenceMaterial=mat,shade=t or 1,
   uv=uv or {{.5/128,.5/48},{.5/128,.5/48},{.5/128,.5/48},{.5/128,.5/48}}}
  out[#out+1]=q
 end
 local function ring(y,r,cx,cz,n)
  local points={};for i=0,n-1 do local a=i*2*pi/n
   points[i+1]={cx+math.cos(a)*r,y,cz+math.sin(a)*r}
  end;return points
 end
 local function join(a,b,mat,t)
  for i=1,#a do local j=i%#a+1
   face(a[i],a[j],b[j],b[i],mat,t*(.88+.12*math.cos(i*2*pi/#a-.6)))
  end
 end
 local function cap(a,mat,t)
  local c={0,a[1][2],0};for _,p in ipairs(a)do c[1]=c[1]+p[1]/#a;c[3]=c[3]+p[3]/#a end
  for i=1,#a do local j=i%#a+1;face(c,a[j],a[i],a[i],mat,t)end
 end
 -- Low stone collars give the roots a believable planting pocket in the paving.
 local a=ring(.35,3.1,0,0,12);local b=ring(1.35,3.1,0,0,12)
 local c=ring(1.35,2.65,0,0,12);local d=ring(.72,2.65,0,0,12)
 join(a,b,'exktSandstone',.9);join(b,c,'exktSandstone',1.03);join(c,d,'exktBasalt',.8);cap(d,'forestFloor',.67)
 local lean=2.6;local dx,dz=math.cos(rot),math.sin(rot)
 local function center(t)return lean*t*t*dx,.74+height*t,lean*t*t*dz end
 local previous
 -- Continuous tapered trunk, with relief rings at old leaf scars.
 for j=0,18 do
  local t=j/18;local x,y,z=center(t);local r=1.45-.67*t+.38*(1-t)^7
  local q=ring(y,r,x,z,10)
  if previous then join(previous,q,'forestBark',1.25)end
  if j>0 and j<18 then
   local l=ring(y-.17,r+.095,x,z,10);local u=ring(y+.12,r+.055,x,z,10)
   join(l,u,'forestBark',1.05);join(u,q,'forestBark',1.37)
  end
  previous=q
 end
 cap(previous,'forestBark',1.1)
 local cx,cy,cz=center(1)
 local function frond(angle,length,lift,droop,phase)
  local ux,uz=math.cos(angle),math.sin(angle);local vx,vz=-uz,ux
  local function at(t)
   local drift=.42*math.sin(t*pi)*math.sin(phase)
   return {cx+ux*length*t+vx*drift,cy+lift*math.sin(t*pi*.82)-droop*t*t,cz+uz*length*t+vz*drift}
  end
  -- A raised central rib joins every leaflet; no floating leaves or flat cards.
  for j=0,7 do
   local t,u=j/8,(j+1)/8;local a,b=at(t),at(u)
   local r=.18*(1-t)+.025;local s=.18*(1-u)+.025
   face({a[1]-vx*r,a[2],a[3]-vz*r},{b[1]-vx*s,b[2],b[3]-vz*s},
    {b[1],b[2]+s,b[3]},{a[1],a[2]+r,a[3]},'leaf',.91)
   face({a[1],a[2]+r,a[3]},{b[1],b[2]+s,b[3]},
    {b[1]+vx*s,b[2],b[3]+vz*s},{a[1]+vx*r,a[2],a[3]+vz*r},'leaf',.82)
  end
  for j=1,13 do for _,side in ipairs({-1,1})do
   local t=.09+j*.061;local root=at(t)
   local reach=(.50+2.7*math.sin(t*pi)^.8)*(length/15)
   local sweep=.6+1.35*t;local width=.16+.17*math.sin(t*pi)
   local tip={root[1]+vx*side*reach+ux*sweep,root[2]-.35-reach*.40,root[3]+vz*side*reach+uz*sweep}
   local mid={(root[1]+tip[1])/2,(root[2]+tip[2])/2+.26,(root[3]+tip[3])/2}
   local left={mid[1]-ux*width,mid[2]-.12,mid[3]-uz*width}
   local right={mid[1]+ux*width,mid[2]-.12,mid[3]+uz*width}
   local tone=.99+.09*math.sin(j*.7+phase)
   local uv1={{.5,0},{0,.5},{.5,1},{.5,.5}};local uv2={{.5,0},{.5,.5},{.5,1},{1,.5}}
   face(root,left,tip,mid,'tropicLeaf',tone,uv1)
   face(root,mid,tip,right,'tropicLeaf',tone*.92,uv2)
   -- The terrain and shadow passes use cull=none: these folded surfaces
   -- already show on both sides, with no duplicate overdraw or textures.
  end end
 end
 for i=0,8 do
  local angle=rot+i*2.39996323;local length=13.3+1.1*math.sin(i*2.1+seed)
  frond(angle,length,3.1+.8*math.sin(i+seed),3.6+.7*math.cos(i*1.9),i+seed)
 end
 -- Three shorter upright young fronds make a living crown, not a flat umbrella.
 for i=0,2 do frond(rot+i*2*pi/3+.7,7.0,7.5,1.8,i+seed+10)end
 for _,q in ipairs(out)do for i=1,4 do
  local v=q[i];q[i]={v[1]+p.cx,v[2]+(p.h or 0),v[3]+p.cz}
 end end
 if p.borderBounds then for _,q in ipairs(out)do q.borderBounds=p.borderBounds end end
 return out
end
function M.build(S,map)
 if not M.enabled(map,V.require('CommunityVisuals').customRoads())then return end
 S.cinnabarPalms19=M.plan(map,S)
 for _,p in ipairs(S.cinnabarPalms19)do
  for _,q in ipairs(M.model(p))do S.objectQuads[#S.objectQuads+1]=q end
 end
 S.cinnabarBorderPalms21=M.borderPlan(map,S)
 for _,p in ipairs(S.cinnabarBorderPalms21)do
  for _,q in ipairs(M.model(p))do S.objectQuads[#S.objectQuads+1]=q end
 end
end
return M
