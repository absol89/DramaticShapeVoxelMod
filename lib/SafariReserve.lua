-- Legendary Safari reserve. Every structural replacement owns source scenery;
-- collision, encounter cells, event records and real map entrances are untouched.
local V=...;local M={}
M.maps={SAFARI_ZONE_CENTER=true,SAFARI_ZONE_EAST=true,SAFARI_ZONE_NORTH=true,SAFARI_ZONE_WEST=true}
M.REVISION='safari-reserve-116'
local function key(x,z)return(z+64)*4096+x+64 end
function M.enabled(map)
 return map and M.maps[map.id]and map.tileset and map.tileset.id=='FOREST'
  and V.require('CommunityVisuals').customSafari()or false
end
local function append(S,qs)for _,q in ipairs(qs)do S.objectQuads[#S.objectQuads+1]=q end end
local function claim(S,tx,tz,w,h,kind)
 for z=tz,tz+h-1 do for x=tx,tx+w-1 do local k=key(x,z)
  S.skip[k]=true;S.ground[k]=48
  S.shapeAt[k]={class='ground',h=0,flat=true,art='flat',authored=true}
  S.safariClaims[k]=kind
 end end
end
local function clear(S,tx,tz,w,h)
 for z=tz,tz+h-1 do for x=tx,tx+w-1 do if S.skip[key(x,z)]then return false end end end
 return true
end
local function rock(G,x,z,w,d,h,seed)
 -- Unequal rings and large shallow facets, rather than cube walls or per-pixel stones.
 local rings={};local n=8
 for j=0,2 do rings[j+1]={};local radius=j==0 and 1 or j==1 and .92 or .55
  for i=0,n-1 do local a=i*2*math.pi/n;local r=radius*(.94+.055*math.sin(seed+i*2.7+j))
   rings[j+1][i+1]={x+math.cos(a)*w*.5*r,j==0 and 0 or j==1 and h*.7 or h*(.9+.1*math.sin(i+seed)),z+math.sin(a)*d*.5*r}
  end
 end
 for j=1,2 do for i=1,n do local k=i%n+1
  G.face(rings[j][i],rings[j][k],rings[j+1][k],rings[j+1][i],'stone',.78+.08*math.sin(seed+i*.7+j))
 end end
 for i=1,n do local k=i%n+1;G.face(rings[3][i],rings[3][k],{x,h*.96,z},{x,h*.96,z},'stone',.88+.06*math.sin(seed+i))end
 -- Restrained mineral seams follow two facets, avoiding repeated green caps.
 for i=1,n,5 do local a,b=rings[2][i],rings[2][i%n+1]
  local mid={(a[1]+b[1])*.5,(a[2]+b[2])*.5,(a[3]+b[3])*.5}
  G.beam({a[1]*.995+x*.005,a[2]+.015,a[3]*.995+z*.005},{mid[1],mid[2]+.045,mid[3]},.065,'mortar',.86)
 end
end
function M.stump(x,z,variant)
 local G=V.require('CityMesh').new({.5/128,.5/48});local n=12
 local h=({5.1,7.3,4.2})[variant+1];local radius=3.2+variant*.25
 local tilt=.07*(variant-1)
 local function cut(u,v)return h+u*tilt+v*.035 end
 local lower,upper={},{}
 for i=0,n-1 do local a=i*2*math.pi/n+variant*.53
  local r=5.1+.5*math.sin(i*2.7+variant);local tr=radius*(1+.055*math.sin(i*2.4))
  lower[i+1]={x+math.cos(a)*r,0,z+math.sin(a)*r}
  upper[i+1]={x+math.cos(a)*tr,cut(math.cos(a)*tr,math.sin(a)*tr),z+math.sin(a)*tr}
 end
 for i=1,n do local k=i%n+1;local p,q,r,t=lower[i],lower[k],upper[k],upper[i]
  G.face(p,q,r,t,'forestBark',.86+.055*math.sin(i*2.1+variant))
  G.face(t,r,{x,h,z},{x,h,z},'oak',.98)
  -- Long shallow bark fissures follow the taper and stop below the cut.
  local a,b={},{};for j=1,3 do a[j]=p[j]*.75+t[j]*.25;b[j]=p[j]*.18+t[j]*.82 end
  G.beam(a,b,.065,'wood',.70)
  if i%3==variant then
   local angle=(i-1)*2*math.pi/n+variant*.53
   local ux,uz=-math.sin(angle),math.cos(angle)
   local ax,az=x+math.cos(angle)*6.5,z+math.sin(angle)*6.5
   local bx,bz=x+math.cos(angle)*3,z+math.sin(angle)*3
   local a,b={ax-ux*.24,.03,az-uz*.24},{ax+ux*.24,.03,az+uz*.24}
   local c,d={bx+ux*.65,2.4,bz+uz*.65},{bx-ux*.65,2.4,bz-uz*.65}
   G.face(a,b,c,d,'forestBark',.94)
   G.face(b,{bx+ux*.65,0,bz+uz*.65},c,c,'forestBark',.83)
   G.face({bx-ux*.65,0,bz-uz*.65},a,d,d,'forestBark',.88)
  end
 end
 for ring=1,5 do local rr=radius*ring/6
  for i=0,n-1 do local a,b=i*2*math.pi/n,(i+1)*2*math.pi/n
   local function point(angle,r)local u,v=math.cos(angle)*r,math.sin(angle)*r;return{x+u,cut(u,v)+.025,z+v}end
   G.face(point(a,rr),point(b,rr),point(b,rr-.065),point(a,rr-.065),'wood',.80)
  end
 end
 for i=0,2 do local a=variant+i*2.2
  local u,v=math.cos(a)*radius,math.sin(a)*radius
  G.beam({x+u*.58,cut(u*.58,v*.58)+.025,z+v*.58},{x+u*.94,cut(u*.94,v*.94)+.025,z+v*.94},.035,'wood',.72)
 end
 return G.out
end
-- Complete source cells only; a model never claims a partial tree at a seam.
local function matches(map,x,z,rows)
 for j,row in ipairs(rows)do for i,t in ipairs(row)do if map:tileAt(x+i-1,z+j-1)~=t then return false end end end
 return true
end
local hedge={{84,85},{86,87}}
local stump={{2,3},{18,19}}
local tree={{4,5,6,7},{35,21,22,23},{36,37,38,39},{0,53,54,48}}
local function avoidEvents(map,x,z,pad)
 for _,list in ipairs({map.def.warps or{},map.def.signs or{},map.def.objects or{}})do
  for _,e in ipairs(list)do if e.x and e.y then
   local ex,ez=e.x*16+8,e.y*16+8
   if math.abs(ex-x)<pad and math.abs(ez-z)<pad then return false end
  end end
 end
 return true
end
local function approach(map,x,z)
 -- A blocked source shrub can host a small amenity facing adjacent plain ground.
 -- Both approach cells must be open; tall grass, water and source stairs excluded.
 for _,d in ipairs({{0,1,0},{1,0,-math.pi/2},{0,-1,math.pi},{-1,0,math.pi/2}})do
  local ok=true
  for step=1,2 do local cx,cz=x+d[1]*step,z+d[2]*step
   local tile=map:tileAt(cx*2,cz*2+1)
   if not map:isWalkableCell(cx,cz)or(tile~=48 and tile~=52)then ok=false end
  end
  if ok then return d[3]end
 end
end
local function amenities(S,map,candidates)
 local themes={
  SAFARI_ZONE_CENTER={'rangerBoard','bench','waterStation','bin','supplies'},
  SAFARI_ZONE_EAST={'lookout','rangerBoard','habitatLog','bench','waterStation'},
  SAFARI_ZONE_NORTH={'rangerBoard','lookout','bench','supplies','bin'},
  SAFARI_ZONE_WEST={'fieldDesk','rangerBoard','bench','habitatLog','waterStation'},
 }
 local used={};local houses=S.safariBuildings or{};local theme=themes[map.id]
 for n,kind in ipairs(theme)do
  local best,score,angle
  for _,p in ipairs(candidates)do if not used[p]and avoidEvents(map,p.x,p.z,32)then
   local a=approach(map,p.tx/2,p.tz/2)
   if a then
    local spacing=true;for _,f in ipairs(S.safariAmenities)do if (f.x-p.x)^2+(f.z-p.z)^2<48^2 then spacing=false end end
    if spacing then
     local dist=1e9
     for _,h in ipairs(houses)do local dx,dz=p.x-(h.x0+h.x1)/2,p.z-h.z1;dist=math.min(dist,dx*dx+dz*dz)end
     -- Rest supplies cluster near lodges. Observation/habitat features spread out.
     local s=kind=='rangerBoard'or kind=='supplies'or kind=='waterStation'or kind=='bin'
     local value=s and -dist or (p.x*13+p.z*19+n*157)%1009
     if not score or value>score then best,score,angle=p,value,a end
    end
   end
  end end
  if best then
   used[best]=true;best.amenity=true
   append(S,V.require('SafariFixtures').place(kind,n,best.x,best.z,angle))
   S.safariAmenities[#S.safariAmenities+1]={kind=kind,x=best.x,z=best.z,angle=angle,tx=best.tx,tz=best.tz,bounds={best.x-7,best.z-7,best.x+7,best.z+7}}
  end
 end
 return used
end
function M.build(S,map)
 if not M.enabled(map)then return false end
 S.outdoor=true;S.safariClaims={};S.safariAmenities={};S.safariTrees={};S.safariRockCount=0;S.safariPlanting={};S.safariBanks={};S.safariAprons={};S.safariGroves={}
 V.require('SafariArchitecture').build(S,map)
 local W,H=map.def.width*4,map.def.height*4;local shrubs={}
 for z=0,H-2,2 do for x=0,W-2,2 do
  if clear(S,x,z,2,2)and matches(map,x,z,hedge)and not map:isWalkableCell(x/2,z/2)then
   shrubs[#shrubs+1]={tx=x,tz=z,x=x*8+8,z=z*8+8}
  end
 end end
 local used=amenities(S,map,shrubs)
 for _,p in ipairs(shrubs)do
  claim(S,p.tx,p.tz,2,2,p.amenity and 'amenity'or 'hedge')
  if not used[p]then
   local L=V.require('SafariLandscape');local kind=L.shrubKind(map,p,W,H)
   local variant=math.floor(V.require('SurfaceCraft').hash(p.tx,p.tz,1127)*4)
   if kind=='hedge'then S.roundStamps[#S.roundStamps+1]=V.require('SafariVegetation').stamp(kind,variant,p.x,p.z)
   else L.plant(S,kind,variant,p.x,p.z)end
  end
 end
 -- Mature trees use their exact original 32px owner, with varied tropical crowns.
 for z=0,H-4,2 do for x=0,W-4,2 do
  if clear(S,x,z,4,4)and matches(map,x,z,tree)then
   local variant=(x/4*7+z/4*3)%4;local kind=(x/4+z/4)%3==0 and 'palm'or 'broadleaf'
   if map.id=='SAFARI_ZONE_EAST'then kind='palm'end
   S.roundStamps[#S.roundStamps+1]=V.require('SafariVegetation').stamp(kind,variant,x*8+16,z*8+16)
   S.safariTrees[#S.safariTrees+1]={kind=kind,tx=x,tz=z}
   claim(S,x,z,4,4,'tree')
  end
 end end
 for z=0,H-2,2 do for x=0,W-2,2 do
  if clear(S,x,z,2,2)and matches(map,x,z,stump)and not map:isWalkableCell(x/2,z/2)then
   append(S,M.stump(x*8+8,z*8+8,(x+z)%3));claim(S,x,z,2,2,'stump')
  end
 end end
 local G=V.require('CityMesh').new({.5/128,.5/48})
 V.require('SafariAccess').build(S,map,G,W,H)
 local rims={[14]=true,[15]=true,[29]=true,[31]=true,[45]=true,[47]=true,[61]=true,[62]=true,[63]=true,[72]=true,[73]=true,[74]=true,[77]=true,[78]=true}
 for z=0,H-1 do for x=0,W-1 do local k=key(x,z);local t=S.tileAt[k];local s=S.shapeAt[k]
  if not S.skip[k]and s and s.class=='ground'and(t==80 or t==81 or t==82 or t==83)then
   local cx,cz=x*8+4,z*8+4;local angle=({[80]=0,[81]=math.pi,[82]=math.pi/2,[83]=-math.pi/2})[t]
   local c,ss=math.cos(angle),math.sin(angle)
   local function pt(u,v)return{cx+u*c-v*ss,.08,cz+u*ss+v*c}end
   G.face(pt(-.5,-2.6),pt(.5,-2.6),pt(.5,.4),pt(-.5,.4),'oak',1.12)
   G.face(pt(-2.3,.2),pt(2.3,.2),pt(0,2.7),pt(0,2.7),'oak',1.12)
  elseif not S.skip[k]and s and rims[t]and s.class~='water'and not map:isWalkableCell(math.floor(x/2),math.floor(z/2))then
   -- All source collision remains occupied, but it reads as an eroded bank:
   -- broad low outcrops between occasional taller stones, never picket rows.
   V.require('SafariLandscape').bank(G,S,map,x,z)
   local seed=x*7+z*3;local hash=V.require('SurfaceCraft').hash(x,z,111)
   local height=hash>.80 and 4.0+hash*1.5 or 1.2+hash*2.0
   local width=6.1+hash*1.0;local depth=5.0+(1-hash)*2.1
   if hash>.84 then rock(G,x*8+4,z*8+4,width*.83,depth*.83,height+1.6,seed)end
   if hash<.08 then rock(G,x*8+6.55,z*8+1.35,2.2,2.1,1.05,seed+6)end
   claim(S,x,z,1,1,'rock');S.safariRockCount=S.safariRockCount+1

  end
 end end
 V.require('SafariWetlands').build(S,map,G,W,H)
 append(S,G.out);V.require('SafariLandscape').perimeter(S,map,W,H);V.require('SafariArchitecture').exit(S,map)
 return true
end
-- Only the original traversable ledge/platform/stair tiles receive this finish.
-- Heights remain the engine's source heights, including hop-down ledges.
function M.groundMaterial(tile)
 if tile==64 or tile==65 or tile==88 or tile==89 or tile==90 or tile==91 then return 'wood'end
 -- Source 52/55/57/92..95 are grass/detail tiles, not raised stone.
 if tile==30 or tile==46 then return 'safariStone'end
 return 'forestFloor'
end
return M
