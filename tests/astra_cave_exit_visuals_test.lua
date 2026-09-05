-- Optional real-map regression: generated data belongs to the engine and is
-- supplied by the caller, never bundled in this source checkout.
local root=os.getenv('ASTRA_CANDIDATE') or '.'
local engine=assert(os.getenv('ASTRA_ENGINE'),'ASTRA_ENGINE required')
local generated=assert(os.getenv('ASTRA_GENERATED'),'ASTRA_GENERATED required')
package.path=engine..'/?.lua;'..package.path
local Map=require('src.world.Map')
local maps=dofile(generated..'/maps.lua');local tilesets=dofile(generated..'/tilesets.lua')
local M=assert(loadfile(root..'/lib/CaveExitVisuals.lua'))({})
local n=0;local function ok(v,m)n=n+1;assert(v,m)end
local fake={getDimensions=function()return 128,40 end,getPixel=function(_,x,y)local c=((x+y)%4)/3;return c,c,c,1 end}
local count,total=0,0
local expected={MT_MOON_1F=1,VICTORY_ROAD_1F=1,VICTORY_ROAD_2F=1,DIGLETTS_CAVE_ROUTE_2=1,DIGLETTS_CAVE_ROUTE_11=1,CERULEAN_CAVE_1F=1,SEAFOAM_ISLANDS_1F=2}
local function serial(v)if type(v)~='table'then return tostring(v)end local k={};for key in pairs(v)do k[#k+1]=key end;table.sort(k,function(a,b)return tostring(a)<tostring(b)end);local o={};for _,key in ipairs(k)do o[#o+1]=tostring(key)..'='..serial(v[key])end;return'{'..table.concat(o,',')..'}'end
for id,def in pairs(maps)do
 local map=Map.new(def,tilesets[def.tileset]);local before=serial(map)
 local ps=M.placements(map);ok(#ps==(expected[id] or 0),id..' exact placement count')
 local S={objectQuads={}};local emitted=M.build(S,map,fake,16)
 ok(emitted==#S.objectQuads,id..' correct emitted count')
 ok(serial(map)==before,id..' no map, collision or warp mutation')
 for _,p in ipairs(ps)do
  count=count+1
  -- The exported outside map actually contains an inbound link to this
  -- cave, and the cave's LAST_MAP destination index lands back outside.
  local outdoor=false
  for _,out in pairs(maps)do if Map.isOutside(out)then
   local ow=out.warps and out.warps[p.destWarp]
   if ow and ow.destMap==id then outdoor=true end
  end end
  ok(outdoor,id..' reciprocal outdoor destination exists')
 end
 local roles={}
 for _,q in ipairs(S.objectQuads)do
  total=total+1;roles[q.caveExitRole]=true
  local inside=false
  for _,p in ipairs(ps)do
   local x0,z0=p.x*16,p.z*16;local x1=x0+(p.face=='south' and p.width*16 or 16);local z1=z0+(p.face=='east' and p.width*16 or 16)
   local valid=true
   for _,v in ipairs({q[1],q[2],q[3],q[4]})do
    valid=valid and v[1]>=x0 and v[1]<=x1 and v[3]>=z0 and v[3]<=z1 and v[2]>=0 and v[2]<=24
    for _,a in ipairs(v)do ok(a==a and math.abs(a)<1e8,'finite')end
   end
   if valid then
    inside=true
    if q.caveExitRole=='daylight' then
     for i=1,4 do
      local depth=p.face=='south' and q[i][3]-z0 or q[i][1]-x0
      ok(depth>=8 and depth<=13,'daylight recessed but clear of neighboring wall facets')
     end
     ok(q.shade>=4,'daylight survives cave palette and ambient attenuation')
    end
   end
  end
  ok(inside,id..' geometry confined to authored mouth cells')
  local u,v={},{};for a=1,3 do u[a]=q[2][a]-q[1][a];v[a]=q[4][a]-q[1][a]end
  local cross={u[2]*v[3]-u[3]*v[2],u[3]*v[1]-u[1]*v[3],u[1]*v[2]-u[2]*v[1]}
  ok(cross[1]^2+cross[2]^2+cross[3]^2>0,'nondegenerate quad')
  for _,uv in ipairs(q.uv)do ok(uv[1]>0 and uv[1]<1 and uv[2]>0 and uv[2]<1,'atlas-safe UV')end
 end
 if #ps>0 then
  for _,role in ipairs({'daylight','lit-floor','ceiling','roof','inner-west','inner-east','lintel'})do ok(roles[role],id..' '..role)end
  -- Alter either the artwork or the destination: the feature fails closed.
  local original=map.tileAt;map.tileAt=function()return 32 end
  ok(#M.placements(map)==0,'changed art not claimed');map.tileAt=original
  local warpAt=map.warpAtCell;map.warpAtCell=function()return{def={destMap='MT_MOON_B2F',destWarp=1}}end
  ok(#M.placements(map)==0,'interior link not claimed');map.warpAtCell=warpAt
  ok(M.build({objectQuads={}},map,nil,16)==0,'missing atlas fallback')
 end
end
ok(count==8,'all eight outdoor mouths')
print(string.format('PASS cave exits: %d checks, %d mouths, %d bounded quads; real maps, mocked atlas.',n,count,total))
