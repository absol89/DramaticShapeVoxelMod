-- Yellow Beach House source geometry, floor classification and actual room ownership.
local root=os.getenv('ASTRA_CANDIDATE')or'.';local baseline=assert(os.getenv('ASTRA_FULL_BASELINE'))
local H=dofile('tests/astra_fixture.lua');local F=dofile('tests/astra_scene_fixture.lua')
local before,after=F.runtime(baseline),F.runtime(root);local checks=0
local function ok(v,msg)checks=checks+1;if not v then error('FAIL '..msg,0)end end
local function eq(a,b,msg)ok(a==b,msg..' expected '..tostring(b)..' got '..tostring(a))end
local function same(a,b,msg)
 eq(type(a),type(b),msg..' type');if type(a)~='table'then eq(a,b,msg);return end
 for k,v in pairs(a)do same(v,b[k],msg..'.'..tostring(k))end
 for k in pairs(b)do ok(a[k]~=nil,msg..' no extra '..tostring(k))end
end

local data,w,h=H.atlas(assert(os.getenv('ASTRA_FULL_ATLASES'))..'/beach_house.rgba')
-- Mesher text also changes upstream (opt-in signs/saplings). The actual
-- room claims, palm classifications, source tiles and actor contacts below
-- are the preservation oracle rather than unrelated source-byte equality.
local profile={ground={1,4,17,20},wall={0,6,7,22,23},stool={2,3,18,19},table={38,39,41,42,43,44,54,55,56,57,58,59,60},counter={50,51,66,67},billboard={32,33,64,65},heights={stool=3,table=6,counter=12}}
same(after.spec.tilesets.BEACH_HOUSE,profile,'entire Yellow-only room profile has explicit, narrow source pools')
eq(before.spec.tilesets.BEACH_HOUSE,nil,'missing original room profile reproduced')
same(after.spec.maps,before.spec.maps,'no map scripts or support overrides changed')
local cases={
 {id='beach_stool',tiles={{2,3},{18,19}},n=8,vox=312,quads=106,height=3,pos={{16,4},{22,4},{16,6},{22,6},{16,8},{22,8},{16,10},{22,10}}},
 {id='beach_table',tiles={{38,39,39,41},{54,55,56,57},{44,42,42,43},{60,58,58,59}},n=2,vox=3336,quads=688,height=6,pos={{18,4},{18,8}}},
 {id='beach_pc',tiles={{64,65},{32,33},{66,67},{50,51}},n=1,vox=5904,quads=488,height=23,pos={{26,0}}},
}
local dishLeft={13,12,11,11,11,11,12,13};local templates={}
for _,c in ipairs(cases)do
 local t=assert(F.template(after,'BEACH_HOUSE',c.id));templates[c.id]=t;same(t.tiles,c.tiles,'exact '..c.id..' source grid')
 local emit,m,s=H.building(root,c.id,data,w,h,nil,true,'BEACH_HOUSE');eq(m.ytop+1,c.height,'physical '..c.id..' height')
 local n,seat,dish=0,0,0
 for y=-1,c.height do for z=-1,32 do for x=-1,m.W do local i=m.at(x,y,z);local want=false
  if c.id=='beach_stool'then
   want=(y==2 and x>=2 and x<=13 and z>=3 and z<=13)or(y>=0 and y<=1 and x>=3 and x<=12 and z>=4 and z<=12)
  elseif c.id=='beach_table'then
   local side=(x>=2 and x<=4)or(x>=27 and x<=29)
   want=(y>=3 and y<=5 and x>=0 and x<=31 and z>=0 and z<=31)or(y==2 and side and z>=2 and z<=29)or(y>=0 and y<=1 and side and((z>=2 and z<=5)or(z>=26 and z<=29)))
  else
   local wall=y>=0 and y<=15 and x>=0 and x<=15 and z>=0 and z<=7
   local desk=y>=0 and y<=11 and x>=0 and x<=15 and z>=16 and z<=31
   local terminal=y>=12 and y<=22 and x>=2 and x<=13 and z>=18 and z<=23
   local recess=y>=16 and y<=21 and x>=4 and x<=11 and z==23
   local keys=y==12 and x>=3 and x<=12 and z>=24 and z<=27
   want=wall or desk or(terminal and not recess)or keys
  end
  eq(i~=nil,not not want,'exact '..c.id..' physical shape; empty floor gaps remain empty')
  if i then n=n+1;if c.id=='beach_pc'and z<=7 then eq(i,(3-y%4)*16,'background is retained only in the intentional wall band')else ok(s.inside[i],'source donor belongs to object silhouette '..c.id..' at '..x..','..y..','..z..' source '..(i%s.W)..','..math.floor(i/s.W))end;local sx,sy=i%s.W,math.floor(i/s.W)
   if c.id=='beach_stool'then
    ok(sy==7 or sy==12 or sy==14,'ottoman uses only original padded-seat and base colors')
    local col=y==0 and 2 or 1
    if y==2 then local d=math.min(x-2,13-x,z-3,13-z);col=d==0 and 2 or(d==2 and 0 or 1);seat=seat+1 end
    eq(s.col[i],col,'preserve dark/gray/white source rings without invented black legs')
    eq(s.col[i],s.col[m.at(15-x,y,z)],'ottoman X symmetry');eq(s.col[i],s.col[m.at(x,y,16-z)],'ottoman Z symmetry')
   elseif c.id=='beach_table'then
    ok(sy<=30,'dining table never carries row31 floor pixels')
    if y<3 then eq(sy,30-y,'feet/apron retain the three actual source elevation rows')end
    if y==5 then
     local l=dishLeft[z-11];local isDish=l and x>=l and x<=31-l
     if isDish then dish=dish+1;eq(i,(z-4)*32+x,'one source dish is laid flat exactly once')
     else local d=math.min(x,31-x,z,31-z);eq(s.col[i],d==0 and 3 or(d==1 and 0 or 1),'uniform black edge, white ring and clean tabletop field')end
    end
   else
    if y<=11 and z>=16 then ok(sy<=31,'cabinet source bounds');if sy==31 then eq(s.col[i],3,'last cabinet row is actual black boundary, not floor dither')end end
    if y>=12 and z>=18 and z<=23 then ok(sy<=14,'computer draws only original terminal source rows')end
    if y>=12 and y<=21 and z==18 then eq(s.col[i],0,'computer rear is source-white case, not repeated front display')end
    if y==12 and z>=24 then eq(i,(z-7)*16+x,'keyboard uses exactly its four original rows once')end
   end
  end
 end end end
 eq(n,c.vox,'source-aware '..c.id..' occupancy');if c.id=='beach_stool'then eq(seat,132,'one even padded lid')elseif c.id=='beach_table'then eq(dish,68,'one68-pixel original dish, no repeated print')end
 local q=emit(m,s,w,h);eq(q.voxels,n,'emitted geometry matches occupancy');eq(#q,c.quads,'bounded '..c.id..' render cost');local _,zero=H.triangles(H.mesh(q));eq(zero,0,'no degenerate submitted triangles')
end
local mapCount,claimCount,instances,falseWater=0,0,0,0
for id,def in pairs(F.maps)do if def.tileset=='BEACH_HOUSE'then
 mapCount=mapCount+1;eq(id,'SUMMER_BEACH_HOUSE','only Yellow beach room uses this profile')
 local map=F.Map.new(def,F.tilesets.BEACH_HOUSE);local claims,cellHeight={},{}
 for _,c in ipairs(cases)do
  local t=templates[c.id];local pos=F.matches(t,map);same(pos,c.pos,'exact '..c.id..' real-map placements');eq(#pos,c.n,'intended instance count')
  for _,p in ipairs(pos)do instances=instances+1
   for z=0,#t.tiles-1 do for x=0,#t.tiles[1]-1 do local k=F.key(p[1]+x,p[2]+z);ok(not claims[k],'furniture claims never overlap');claims[k]=true;claimCount=claimCount+1 end end
   if c.id~='beach_pc'then for z=p[2]/2,(p[2]+#t.tiles)/2-1 do for x=p[1]/2,(p[1]+#t.tiles[1])/2-1 do cellHeight[x..':'..z]=c.height end end
   else cellHeight['13:1']=12 end
  end
 end
 local shapes,oldShapes=after.shapes.forMap(map),before.shapes.forMap(map)
 local a,b=F.build(after,map,data,w),F.build(before,map,data,w);same(a.tileAt,b.tileAt,'source map and interaction tiles remain exact')
 local expectedQuads=8*106+2*688+488;eq(#a.objectQuads,expectedQuads,'exactly eleven new authored objects, no duplicate motifs');eq(#b.objectQuads,0,'original generic room reproduced')
 for z=0,def.height*4-1 do for x=0,def.width*4-1 do local k=F.key(x,z);local tile=map:tileAt(x,z);local sh=after.shapes.at(map,shapes,tile,x,z)
  ok(sh.class~='water','no source-art dithering becomes indoor water')
  if before.shapes.at(map,oldShapes,tile,x,z).class=='water'then falseWater=falseWater+1 end
  if claims[k]then ok(a.skip[k]and a.shapeAt[k].class=='building','exact furniture source tiles claimed')else ok(not a.skip[k],'all walls, palms and original floor remain outside authored claims')end
  if tile==4 or tile==20 or tile==1 or tile==17 then eq(sh.class,'ground','exit mat and patterned floor remain flat');eq(sh.h,0,'floor is at actor ground level')end
  if tile==8 or tile==9 or tile==24 or tile==25 or tile>=68 then same(sh,before.shapes.at(map,oldShapes,tile,x,z),'original palm and scenic-prop classifications preserved');ok(not a.skip[k],'retained palms stay on their original unclaimed renderer path')end
 end end
 for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do
  local old=before.scene.groundAt(map,x,z);local want=cellHeight[x..':'..z]or old
  eq(after.scene.groundAt(map,x,z),want,'only intended furniture cells change actor support')
  if map:isWalkableCell(x,z)and not cellHeight[x..':'..z]then eq(after.scene.groundAt(map,x,z),0,'all walking paths outside the intentional seats and furniture remain ground level')end
 end end
 for _,o in ipairs(def.objects or{})do eq(after.scene.groundAt(map,o.x,o.y),before.scene.groundAt(map,o.x,o.y),'both actual NPC supports retained')end
 for k in pairs(map.warpAt)do eq(after.scene.groundAt(map,k%map.widthCells,math.floor(k/map.widthCells)),0,'actual beach exit stays at ground level')end
end end
eq(mapCount,1,'only one missing Yellow tileset room');eq(instances,11,'eight ottomans, two tables, one PC');eq(claimCount,72,'only72 exact furniture source tiles claimed');eq(falseWater,12,'all twelve original false-water tiles reproduced and corrected')
print(('%d Beach House checks passed;11 exact authored objects/72 claims;12 false-water tiles corrected; ground paths/NPCs preserved'):format(checks))
