-- All real cave warp ladders, source claims and preserved gameplay support.
local root=rawget(_G,'ASTRA_STAIRS_TEST_ROOT')or os.getenv('ASTRA_CANDIDATE')or'.'
local baseline=os.getenv('ASTRA_STAIRS_BASELINE')or'../artifacts/battle-art-astra-stairs/baseline-mod'
local T=dofile(root..'/tests/astra_stair_fixture.lua');local H,F=T.H,T.F
local data,aw,ah=H.atlas(os.getenv('ASTRA_CAVE_ATLAS')or'../artifacts/battle-art-astra-stairs/cave-audit/private/cavern.rgba')
local before,after=T.runtime(baseline,data),T.runtime(root,data)
-- A20 traversed shelf steps have their own live geometry/support regression.
-- This historical scope retains the old49-cell datum without changing pins.
after.spec.tilesets.CAVERN.cave_steps=nil
local checks=0
local function ok(v,msg)checks=checks+1;if not v then error('FAIL '..msg,0)end end
local function eq(a,b,msg)ok(a==b,msg..' expected '..tostring(b)..' got '..tostring(a))end
local function same(a,b,msg)
 eq(type(a),type(b),msg..' type');if type(a)~='table'then eq(a,b,msg);return end
 for k,v in pairs(a)do same(v,b[k],msg..'.'..tostring(k))end
 for k in pairs(b)do ok(a[k]~=nil,msg..' no extra '..tostring(k))end
end

local cave=after.module('CaveLadders')
local function copy(v)if type(v)~='table'then return v end;local o={};for k,x in pairs(v)do o[k]=copy(x)end;return o end
local wanted=copy(before.spec.tilesets.CAVERN);wanted.stair_e=nil;wanted.stair_down_e=nil;wanted.ladder_up={10,11,26,27};wanted.ladder_down={8,9,24,25}
same(after.spec.tilesets.CAVERN,wanted,'only two exact cave source pools change from stairs to ladder classes')
same(after.spec.maps,before.spec.maps,'all prior map overrides retained')
local kinds={[10]='ladder_up',[8]='ladder_down'};local grids={ladder_up={{10,11},{26,27}},ladder_down={{8,9},{24,25}}}
local dirs={{0,-1},{1,0},{0,1},{-1,0}}
local maps,up,down,shelf,claims,raised,low=0,0,0,0,0,0,0
for id,def in pairs(F.maps)do if def.tileset=='CAVERN'then
 maps=maps+1;local map=F.Map.new(def,F.tilesets.CAVERN);local oldShapes,newShapes=before.shapes.forMap(map),after.shapes.forMap(map)
 local a,b=after.render(map),before.render(map)
 same(a.tileAt,b.tileAt,'original cave source map retained');same(a.skip,b.skip,'all old stair claims retained, no extra claims');same(a.ground,b.ground,'upward ground synthesis retained; downward holes never gain floor fill')
 local found=0;local exact={}
 for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do
  local tile=map:tileAt(x*2,z*2);local kind=kinds[tile];local warp=map.warpAt[z*map.widthCells+x]
  eq(after.scene.groundAt(map,x,z),before.scene.groundAt(map,x,z),'all cave actor/battle support preserved')
  if kind then
   found=found+1;if kind=='ladder_up'then up=up+1 else down=down+1 end
   ok(warp and warp.def.destMap,'every selected ladder is a real warp');eq(after.scene.groundAt(map,x,z),0,'warp actor stays at its existing ground datum')
   for dz=0,1 do for dx=0,1 do local k=F.key(x*2+dx,z*2+dz);local tt=map:tileAt(x*2+dx,z*2+dz)
    eq(tt,grids[kind][dz+1][dx+1],'complete original2x2 ladder grid');eq(newShapes[tt].class,kind,'exact new ladder class');eq(newShapes[tt].art,'stair','dedicated ladder still uses warp support convention');eq(newShapes[tt].h,16,'rock-band visual height retained')
    ok(a.skip[k],'all four original art tiles claimed exactly once');exact[k]=true;claims=claims+1
    if kind=='ladder_up'then eq(a.ground[k],false,'UP retains synthesized ground')else eq(a.ground[k],nil,'DOWN hole must have no synthesized floor')end
   end end
   if kind=='ladder_down'then
    local anyZero,anyShelf=false,false
    for _,d in ipairs(dirs)do local xx,zz=x+d[1],z+d[2]
     if map:inBounds(xx,zz)and map:isWalkableCell(xx,zz)then local h=before.scene.groundAt(map,xx,zz);if h==0 then anyZero=true elseif h==6 then anyShelf=true end end
    end
    local want=not anyZero and anyShelf and 6 or 0;local h,t=cave.rim(map,x,z);eq(h,want,'mouth follows all actual walkable approach datums, including neighboring ladders')
    local ds=newShapes[t];ok(ds and(ds.class=='ground'or ds.class=='ledge')and ds.h==h,'rim donor is genuine matching-height floor, never another ladder print')
    if h==6 then raised=raised+1 else low=low+1 end
   end
  elseif tile==21 then
   shelf=shelf+1;eq(warp,nil,'shelf treads are not warp ladders');eq(newShapes[tile].class,'ledge','north-south shelf family retained');eq(after.scene.groundAt(map,x,z),6,'existing shelf support unchanged')
  end
 end end
 for k in pairs(a.skip)do ok(exact[k],'no shelf, drop hole, surrounding rock or floor claimed by ladder pass')end
 for k,s in pairs(b.shapeAt)do local aShape=a.shapeAt[k];if not exact[k]then same(aShape,s,'every non-ladder source shape exact')end end
 eq(#b.objectQuads,found*21,'original sideways21-quad flights reproduced')
 ok(#a.objectQuads>=found*20 and #a.objectQuads<=found*256,'new visible rails/shaft remain a bounded per-cell cost')
 for _,o in ipairs(def.objects or{})do eq(after.scene.groundAt(map,o.x,o.y),before.scene.groundAt(map,o.x,o.y),'every real cave NPC/item support unchanged')end
end end
eq(maps,19,'all actual cave maps checked');eq(up,40,'all upward warps');eq(down,37,'all downward warps');eq(shelf,49,'all non-warp shelf steps kept');eq(claims,308,'exact77 original cells/308 source tiles');eq(raised,8,'only eight shelf-only mouths rise to6');eq(low,29,'29 mouths stay at0, including adjacent mixed pair')
print(('%d cave ladder placement/support checks passed;40 up,37 down,308 exact claims;8 rims at6/29 at0;49 shelf steps and all actor pins retained'):format(checks))
