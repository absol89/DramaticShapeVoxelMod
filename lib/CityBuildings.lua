local V=...
local M={}
local Rules=V.require('CityBuildingRules')
local Inventory=V.require('BuildingInventory')
local function bounds(qs,first,last)
 local a,b={1e9,1e9,1e9},{-1e9,-1e9,-1e9}
 for i=first,last do local q=qs[i];if q then for j=1,4 do for k=1,3 do a[k]=math.min(a[k],q[j][k]);b[k]=math.max(b[k],q[j][k])end end end end
 return a,b
end
local function donor(map,data)
 if not data or type(data.getPixel)~='function' then return nil end
 local w,h=map.tileset.imageWidth,map.tileset.imageHeight
 if not w or not h or w<1 or h<1 then return nil end
 -- An opaque sample is only an alpha carrier; color comes from our materials.
 for y=0,math.min(h-1,63)do for x=0,math.min(w-1,127)do
  local r,g,b,a=data:getPixel(x,y)
  if a==nil or a>=.99 then return {(x+.5)/w,(y+.5)/h}end
 end end
 return nil
end
local function hint(map,b)
 local best,dist=nil,1e9
 for _,r in ipairs(Inventory)do if r.map==map.id then
  local d=math.abs(r.x-b.tileX)+math.abs(r.z-b.tileZ)
  if d<dist and d<=24 then best,dist=r,d end
 end end
 return best
end
local function merge(doors)
 table.sort(doors,function(a,b)if a.side==b.side then return a.u<b.u end;return a.side<b.side end)
 local out={}
 for _,d in ipairs(doors)do
  local p=out[#out]
  if p and p.side==d.side and d.u-p.last<=16.1 then
   local l=p.u-p.w/2;local r=d.u+7;p.u=(l+r)/2;p.x=p.u;p.w=r-l;p.last=d.u
  else out[#out+1]={side=d.side,u=d.u,x=d.u,w=14,last=d.u}end
 end
 return out
end
function M.doors(map,b)
 local doors={};local dest=''
 for _,w in ipairs((map.def or {}).warps or {})do
  local x,z=tonumber(w.x),tonumber(w.y)
  if x and z then
   x,z=x*16+8,z*16+8
   local left,right,top,bottom=b.tileX,b.tileX+b.tileW,b.tileZ,b.tileZ+b.tileH
   local side,u
   if x>=left+7 and x<=right-7 and z>=top-16 and z<=bottom+16 then
    side=z<top+1 and 'back' or 'front';u=x
   elseif z>=top and z<=bottom and math.abs(x-left)<=8.1 then side='west';u=z
   elseif z>=top and z<=bottom and math.abs(x-right)<=8.1 then side='east';u=z end
   if side then doors[#doors+1]={side=side,u=u};dest=tostring(w.destMap or dest)end
  end
 end
 return merge(doors),dest
end
function M.spec(map,b,qs,uv)
 local a,c=bounds(qs,b.first,b.last)
 if c[1]<a[1] then return nil end
 local W,D=c[1]-a[1],c[3]-a[3]
 if W<24 or D<12 or W>400 or D>200 or c[2]<12 then return nil end
 local doors,dest=M.doors(map,b);local entry=hint(map,b)
 if dest=='' and entry then dest=entry.destination end
 local identity=b.id
 if entry and entry.source=='B18' and map.id=='PEWTER_CITY' then identity='museum_wing' end
 if dest=='' and entry and map.id:find('ROUTE_') and ({B13=true,B14=true,B15=true,B27=true})[entry.source] then identity='gate' end
 local kind=Rules.classify(map.id,dest,identity)
 if kind=='tower' or kind=='tower_claim' then return nil end
 local x0,x1,z0,z1=a[1]+1,c[1]-1,a[3]+1,c[3]-(b.frontEave or 0)
 if x1-x0<20 or z1-z0<10 then return nil end
 -- Preserve the exact along-wall warp coordinate. A shallow model may need
 -- its wall extended within the authored footprint to contain a side door.
 for _,d in ipairs(doors)do
  local lo,hi=d.u-d.w/2-1,d.u+d.w/2+1
  if d.side=='west' or d.side=='east' then z0=math.min(z0,lo);z1=math.max(z1,hi)
  else x0=math.min(x0,lo);x1=math.max(x1,hi)end
  d.x=d.u
 end
 return {x0=x0,x1=x1,z0=z0,z1=z1,kind=kind,map=map.id,doors=doors,destination=dest,uv=uv,template=b.id}
end
function M.model(s)
 local ordinary={house=true,scenery_house=true,player_house=true,rival_house=true,rest_house=true,club=true}
 local frontOnly=true;for _,d in ipairs(s.doors)do if d.side~='front' then frontOnly=false end end
 if ((ordinary[s.kind] and frontOnly) or s.kind=='center' or s.kind=='mart') and frontOnly then
  local r=Rules.region(s.map)
  local style=s.kind=='center' and 'center' or s.kind=='mart' and 'mart' or s.kind=='club' and 'club' or s.kind=='rival_house' and 'bluehouse' or 'cottage'
  local spec={x0=s.x0,x1=s.x1,z0=s.z0,z1=s.z1,style=style,doors=s.doors,wall=r.wall,trim=s.map=='FUCHSIA_CITY' and 'wood' or 'white',shutters=s.map=='FUCHSIA_CITY' and 'wood' or s.map=='VIRIDIAN_CITY' and 'green' or 'blue',roof=s.kind=='rival_house' and 'blue' or r.roof}
  local out=V.require('ReferenceBuildings').model(spec)
  V.require('HouseGardenDetail').append(out,s)
  for _,q in ipairs(out)do q.uv={s.uv,s.uv,s.uv,s.uv}end
  return out
 end
 return V.require('CityArchitecture').model(s)
end
local function league(S,map,uv)
 if map.id~='INDIGO_PLATEAU' or map.tileset.id~='PLATEAU' then return end
 local rows=V.require('LeagueProfile');local key=function(x,z)return (z+64)*4096+x+64 end
 local tw,th=map.def.width*4,map.def.height*4
 for tz=0,th-#rows do for tx=0,tw-#rows[1] do
  local match=true
  for r,row in ipairs(rows)do for c,tile in ipairs(row)do if S.tileAt[key(tx+c-1,tz+r-1)]~=tile then match=false;break end end;if not match then break end end
  if match then
   local b={tileX=tx*8,tileZ=tz*8,tileW=#rows[1]*8,tileH=#rows*8}
   local doors=M.doors(map,b)
   if #doors==0 then return end
   local spec={x0=b.tileX,x1=b.tileX+b.tileW,z0=b.tileZ,z1=b.tileZ+b.tileH,kind='league',map=map.id,doors=doors,uv=uv}
   for _,q in ipairs(M.model(spec))do S.objectQuads[#S.objectQuads+1]=q end
   for r,row in ipairs(rows)do for c in ipairs(row)do
    local k=key(tx+c-1,tz+r-1);S.skip[k]=true;S.ground[k]=35;S.shapeAt[k]={class='building',h=0,art='building',flat=false,authored=true}
   end end
   S.legendaryBuildingAudit[#S.legendaryBuildingAudit+1]={kind='league',status='replaced',template='league_central_hall'}
   return
  end
 end end
end
function M.build(S,map,data)
 if not S.outdoor or not map or not map.tileset or map.id=='VERMILION_CITY' then return false end
 if map.tileset.id~='OVERWORLD' and map.tileset.id~='FOREST' and map.tileset.id~='PLATEAU' then return false end
 local uv=donor(map,data);if not uv then return false end
 local replace={};local extra={};local n=0;S.legendaryBuildingAudit={}
 for _,b in ipairs(S.cityBuildings or {})do
  local kind=Rules.classify(map.id,'',b.id)
  if b.bbTower then
   local q=V.require('CityArchitecture').towerDetail({x0=b.tileX,z0=b.tileZ,depth=b.towerDepth or b.tileH,uv=uv})
   for _,p in ipairs(q)do extra[#extra+1]=p end
   S.legendaryBuildingAudit[#S.legendaryBuildingAudit+1]={kind='tower',template=b.id,status='original tower enhanced'}
  elseif kind~='tower' and kind~='tower_claim' and not b.claimOnly and b.last>=b.first then
   local spec=M.spec(map,b,S.objectQuads,uv)
   if spec then
    replace[b.first]=M.model(spec);for i=b.first+1,b.last do replace[i]=false end
    n=n+1;S.legendaryBuildingAudit[#S.legendaryBuildingAudit+1]={kind=spec.kind,destination=spec.destination,template=b.id,status='replaced',doors=#spec.doors}
   else S.legendaryBuildingAudit[#S.legendaryBuildingAudit+1]={template=b.id,status='retained: unsupported footprint'}end
  end
 end
 local out={};for i,q in ipairs(S.objectQuads)do
  if replace[i]==nil then out[#out+1]=q elseif replace[i] then for _,p in ipairs(replace[i])do out[#out+1]=p end end
 end
 for _,q in ipairs(extra)do out[#out+1]=q end
 S.objectQuads=out
 league(S,map,uv)
 S.legendaryBuildingCount=n
 return n>0 or #extra>0
end
return M
