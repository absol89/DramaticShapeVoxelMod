-- Real CAVERN source, public stair pass, and unchanged legacy ladder shells.
local root=os.getenv('ASTRA_CANDIDATE')or'.'
local baseline=os.getenv('ASTRA_REMAINING_BASELINE')or'../artifacts/battle-art-astra-remaining-pass/baseline-mod'
local T=dofile(root..'/tests/astra_stair_fixture.lua');local H,F=T.H,T.F
local data,aw,ah=H.atlas(os.getenv('ASTRA_CAVE_ATLAS')or'../artifacts/battle-art-astra-stairs/private/cavern.rgba')
local a,b=T.runtime(root,data),T.runtime(baseline,data)
local n=0
local function ok(v,m)n=n+1;assert(v,m)end
local function eq(x,y,m)ok(x==y,m..': '..tostring(x)..' ~= '..tostring(y))end
local function same(x,y,m)
 eq(type(x),type(y),m)
 if type(x)~='table'then eq(x,y,m);return end
 for k,v in pairs(x)do same(v,y[k],m..'.'..tostring(k))end
 for k in pairs(y)do ok(x[k]~=nil,m..' extra '..tostring(k))end
end
local steps=a.module('CaveSteps')
local count,flights,landings,wet,claims,quads=0,0,0,0,0,0
local maps={}
for id,d in pairs(F.maps)do if d.tileset=='CAVERN'then maps[#maps+1]=id end end;table.sort(maps)
for _,id in ipairs(maps)do
 local map=F.Map.new(F.maps[id],F.tilesets.CAVERN)
 local old,new=b.render(map),a.render(map)
 local wanted={};local legacy={}
 for _,q in ipairs(new.objectQuads)do if not q.caveStepRole then legacy[#legacy+1]=q end end
 same(legacy,old.objectQuads,id..' all77 ladder and pre-existing stair geometry/UV/shade exact')
 local shapesA,shapesB=a.shapes.forMap(map),b.shapes.forMap(map)
 same(shapesA,shapesB,id..' every original tile pin retained')
 for cz=0,map.heightCells-1 do for cx=0,map.widthCells-1 do
  local source=map:tileAt(cx*2,cz*2)==21 and map:tileAt(cx*2+1,cz*2)==22
    and map:tileAt(cx*2,cz*2+1)==21 and map:tileAt(cx*2+1,cz*2+1)==22
  eq(steps.match(map,cx,cz)~=nil,source and not map:warpAtCell(cx,cz),id..' exact nonwarp source match')
  if source then
   count=count+1
   local south=map:cellTile(cx,cz+1)
   local landing=south==5 or south==41
   if landing then landings=landings+1 else flights=flights+1 end
   if south==20 then wet=wet+1 end
   local lo=landing and 6 or 0
   local hi,actualLo=steps.levels(map,cx,cz);eq(hi,6,'north shelf6');eq(actualLo,lo,'actual south landing')
   for z=0,1 do for x=0,1 do local k=F.key(cx*2+x,cz*2+z);wanted[k]=true;claims=claims+1
    eq(new.skip[k],true,'complete step claim');eq(new.ground[k],false,'ordinary floor remains beneath shell')
   end end
   local S=a.render(map,{cx*2,cx*2+1,cz*2,cz*2+1})
   eq(#S.objectQuads,landing and 20 or 26,'bounded surface count');quads=quads+#S.objectQuads
   local area={};local top={}
   for _,q in ipairs(S.objectQuads)do
    local role=q.caveStepRole;ok(role~=nil,'only step geometry in exact cell')
    local mins,maxs={1e9,1e9,1e9},{-1e9,-1e9,-1e9}
    for i=1,4 do for axis=1,3 do local v=q[i][axis]
     ok(v==v and math.abs(v)<1e8,'finite vertex');mins[axis]=math.min(mins[axis],v);maxs[axis]=math.max(maxs[axis],v)
    end end
    local dx,dy,dz=maxs[1]-mins[1],maxs[2]-mins[2],maxs[3]-mins[3]
    ok(mins[1]>=cx*16 and maxs[1]<=cx*16+16 and mins[3]>=cz*16 and maxs[3]<=cz*16+16,'within original cell')
    ok(mins[2]>=0 and maxs[2]<=6,'no raised obstruction or false pit')
    for _,axis in ipairs({1,3})do
     ok(maxs[axis]-mins[axis]<=8,'world curve span8')
     ok(math.floor((mins[axis]+1e-7)/8)==math.floor((maxs[axis]-1e-7)/8)or maxs[axis]==mins[axis],'no8px lattice crossing')
    end
    local u,v={},{};for axis=1,3 do u[axis]=q[2][axis]-q[1][axis];v[axis]=q[4][axis]-q[1][axis]end
    local cross={u[2]*v[3]-u[3]*v[2],u[3]*v[1]-u[1]*v[3],u[1]*v[2]-u[2]*v[1]}
    local ar=math.sqrt(cross[1]^2+cross[2]^2+cross[3]^2);ok(ar>0,'nondegenerate surface')
    area[role]=(area[role]or 0)+ar
    local normal=role=='tread'and{2,-1}or role=='west'and{1,-1}or role=='east'and{1,1}or role=='north'and{3,-1}or{3,1}
    ok(cross[normal[1]]*normal[2]>0,'established top-Y and outward side winding')
    for _,uv in ipairs(q.uv)do
     local ax,ay=math.floor(uv[1]*aw),math.floor(uv[2]*ah)
     local tile=math.floor(ay/8)*16+math.floor(ax/8)
     ok(tile==21 or tile==22,'source step art only, never neighboring floor')

    end
    if role=='riser'then
     local u,v=0,0;for _,uv in ipairs(q.uv)do u=u+uv[1]/4;v=v+uv[2]/4 end
     eq(data:getPixel(math.floor(u*aw),math.floor(v*ah)),0,'black original riser row')
    end
    if role=='tread'then
     local z0=mins[3]-cz*16;local expected=landing and 6 or 6-1.5*math.floor(z0/4)
     eq(mins[2],expected,'source band tread height')
     for z=math.floor(z0),math.floor(maxs[3]-cz*16)-1 do for x=math.floor(mins[1]-cx*16),math.floor(maxs[1]-cx*16)-1 do
      local k=z*16+x;ok(not top[k],'one exposed top per contact');top[k]=expected
      eq(steps.support(map,cx*16+x+.5,cz*16+z+.5),expected,'support lies exactly on rendered tread')
     end end
    end
   end
   eq(area.tread,256,'entire16x16 accessible footprint covered')
   eq(area.riser or 0,landing and 0 or 96,'only exposed tread risers')
   eq(area.north,96,'closed north boundary')
   eq(area.south or 0,landing and 96 or 0,'landing joins south at6')
   eq(area.west,landing and 96 or 60,'continuous west shell');eq(area.east,area.west,'east/west volume symmetric')
  else
   eq(a.scene.groundAt(map,cx,cz),b.scene.groundAt(map,cx,cz),id..' nonstep actor datum preserved')
  end
 end end
 for k,v in pairs(new.skip)do if not wanted[k]then eq(v,old.skip[k],id..' no unrelated claims')end end
 for k,v in pairs(old.skip)do eq(new.skip[k],v,id..' old claims retained')end
 for k,v in pairs(new.ground)do if not wanted[k]then eq(v,old.ground[k],id..' old floor flags retained')end end
 -- Dynamic near misses and an invented warp decline the opt-in matcher.
 local original=map.tileAt
 local sample
 for cz=0,map.heightCells-1 do for cx=0,map.widthCells-1 do if steps.match(map,cx,cz)then sample={cx,cz};break end end;if sample then break end end
 if sample then
  local cx,cz=sample[1],sample[2]
  map.tileAt=function(self,x,z)if x==cx*2+1 and z==cz*2+1 then return 32 end;return original(self,x,z)end
  eq(steps.match(map,cx,cz),nil,'one-tile mismatch declines')
  map.tileAt=original;local warp=map.warpAtCell
  map.warpAtCell=function(self,x,z)if x==cx and z==cz then return{}end;return warp(self,x,z)end
  eq(steps.match(map,cx,cz),nil,'actual warp never becomes traversed steps')
  map.warpAtCell=warp
 end
end
eq(count,49,'all source placements');eq(flights,44,'descending flights');eq(landings,5,'raised landings');eq(wet,9,'water-side source foot placements');eq(claims,196,'exact source ownership')
print(n..' cave step geometry/placement checks passed; '..flights..' flights + '..landings..' landings, '..claims..' claims, '..quads..' total quads; all77 ladders exact')