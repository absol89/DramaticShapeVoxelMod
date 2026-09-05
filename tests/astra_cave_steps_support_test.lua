-- Position-dependent cave contact through actual Player/NPC interpolation,
-- captured scene poses, shadow/reflection consumers and battle eligibility.
local root=os.getenv('ASTRA_CANDIDATE')or'.'
local baseline=os.getenv('ASTRA_REMAINING_BASELINE')or'../artifacts/battle-art-astra-remaining-pass/baseline-mod'
local H=dofile(root..'/tests/astra_fixture.lua');local F=dofile(root..'/tests/astra_scene_fixture.lua')
local a,b=F.runtime(root),F.runtime(baseline)
local n=0
local function ok(v,m)n=n+1;assert(v,m)end
local function eq(x,y,m)ok(x==y,m..': '..tostring(x)..' ~= '..tostring(y))end
local function same(x,y,m)
 eq(type(x),type(y),m)
 if type(x)~='table'then eq(x,y,m);return end
 for k,v in pairs(x)do same(v,y[k],m..'.'..tostring(k))end
 for k in pairs(y)do ok(x[k]~=nil,m..' extra '..tostring(k))end
end
local draws,shadows={},{}
local mesh={}
local modules={TileShape=a.shapes,ModSetting={new=function()return{get=function()return true end}end},
 Mat4=assert(loadfile(root..'/lib/Mat4.lua'))(),
 VoxelState={angle=math.pi/2},
 Water={CAST_RAISE=0},
 SpriteBillboards={mesh=function()return mesh end,shadowQuad=function()return mesh end},
 Voxel3D={draw=function(m,tex,matrix)draws[#draws+1]={mesh=m,matrix=matrix}end,
  casterMatrix=function(px,py,y)return{px,py,y}end,shadowMatrix=function(px,py,y)return{px,py,y}end,
  glass=function()end,seams=function()end},
 FirstPerson={cardBlend=function()return 0 end,hidePlayer=function()return false end,signature=function()return''end},
 RenderDistance={point=function()return true end,neighbor=function()return true end},
 ShadowMap={discard=function()end,available=function()return true end,stale=function()return true end,begin=function()return true end,
  draw=function(m,tex,matrix)if m then shadows[#shadows+1]={mesh=m,matrix=matrix}end end,
  snug=function(m)return m end,sprites=function()end,finish=function()end,KX=0,KZ=0},
 CharacterRenderers={all=function()end,revision=function()return 0 end,first=function()return nil end},
 CavePerimeter={draw=function()end},
 CommunityFlora={shadowSignature=function()return''end,castShadows=function()end},
 ChunkMesher={flowers=function()end,figures=function()return{}end},
}
local V={data=function()return a.spec end}
function V.require(name)
 if modules[name]then return modules[name]end
 if name=='CaveSteps'or name=='BattleArena'or name=='VoxelScene'or name=='ShipHull'then modules[name]=assert(loadfile(root..'/lib/'..name..'.lua'))(V);return modules[name]end
 return{}
end
local scene=V.require('VoxelScene');local steps=V.require('CaveSteps');local arena=V.require('BattleArena')
local oldArena=assert(loadfile(baseline..'/lib/BattleArena.lua'))({require=function(name)
 if name=='VoxelScene'then return b.scene end;return{}end,data=function()return b.spec end})
local poses=H.upvalue(scene.render,'posesOf')
local Player=require('src.world.Player');local NPC=require('src.world.NPC')
local Collision=require('src.world.Collision')
Collision.load({field=dofile(assert(os.getenv('ASTRA_GENERATED'))..'/field.lua')})
local sprite={def={id='contact-fixture',image='contact-fixture'},resolveImage=function()return'contact-fixture'end}
local function entity(class,x,z,dir)
 return setmetatable({sprite=sprite,def={name='STEP_TEST'},cellX=x,cellY=z,px=x*16,py=z*16,
  facing=dir,moving=false,progress=0,stepFlip=false,turnTimer=0,turnArmed=false,stepFrames=16},class)
end
local function expected(map,wx,wz)
 local cx,cz=math.floor(wx/16),math.floor(wz/16)
 if steps.match(map,cx,cz)then
  local south=map:cellTile(cx,cz+1)
  return(south==5 or south==41)and 6 or 6-1.5*math.floor((wz-cz*16)/4)
 end
 return b.scene.groundAt(map,cx,cz)
end
local traversals,frames,cells,eligibilityChanges=0,0,0,0
local snapshots={}
for id,d in pairs(F.maps)do if d.tileset=='CAVERN'then
 local map=F.Map.new(d,F.tilesets.CAVERN);local oldShapes=b.shapes.forMap(map)
 -- Preserve map, warp, collision and source data before/after all rendering.
 local savedTiles,savedWalk,savedWater,savedWarp={},{},{},{}
 for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do
  local k=z*map.widthCells+x;savedTiles[k]=map:cellTile(x,z);savedWalk[k]=map:isWalkableCell(x,z);savedWater[k]=map:isWaterCell(x,z);savedWarp[k]=map:warpAtCell(x,z)
  local matched=steps.match(map,x,z)
  for _,surf in ipairs({false,true})do
   local was,now=oldArena.openCell(map,x,z,surf),arena.openCell(map,x,z,surf)
   local want=was;if matched then want=false end
   eq(now,want,id..' only step stage eligibility changes')
   eq(arena.openCell(map,x,z,surf,true),was,'explicit authored stage retains old eligibility')
   if was~=now then eligibilityChanges=eligibilityChanges+1 end
  end
  if matched then
   cells=cells+1
   eq(scene.groundAt(map,x,z),expected(map,x*16+8,z*16+8),'cell-only battle support is actual central tread')
   for _,class in ipairs({Player,NPC})do for _,dir in ipairs({'up','down'})do for _,length in ipairs({8,16})do
    local delta=dir=='down'and 1 or -1
    local e=entity(class,x,z-delta,dir);e.stepFrames=length
    local oldE=entity(class,x,z-delta,dir);oldE.stepFrames=length
    local allowed=Collision.canMove(map,{e},e,dir)
    -- Two actual engine interpolation steps, with collision checked at
    -- both endpoints. Water remains blocked on foot and is tested below.
    if allowed then
     for leg=1,2 do
      local permitted=Collision.canMove(map,{e},e,dir)
      if permitted then
       for _,walker in ipairs({e,oldE})do walker.targetX=walker.cellX;walker.targetY=walker.cellY+delta;walker.progress=0;walker.moving=true end
       traversals=traversals+1
       for frame=0,length do
        local want=expected(map,e.px+8,e.py+8)
        local p=poses({map=map,entities={e},player=e},function()end)[1]
        eq(p.gh,want,'player/NPC feet exactly on tread or adjoining floor')
        eq(p.px,e.px,'pixel X unmodified');eq(p.py,e.py,'pixel Z unmodified');eq(p.lift,0,'no artificial hop')
        eq(scene.groundAt(map,e.cellX,e.cellY,e.px,e.py),want,'rendered support agrees independently')
        local gh=p.gh
        local ghost=poses({map=map,entities={},ghosts={{map=map,npc=e,ox=160,oy=-32}}},function()end)[1]
        eq(ghost.gh,gh,'ghost uses unshifted map contact');eq(ghost.px,e.px+160,'ghost X offset exact');eq(ghost.py,e.py-32,'ghost Z offset exact')
        if frame<length then class.update(e,map,{e});class.update(oldE,map,{oldE})end
        same(e,oldE,'rendering cannot change movement/cell/progress state')
        frames=frames+1
       end
      end
     end
    end
   end end end
   if map:cellTile(x,z+1)==20 then
    local foot=entity(Player,x,z,'down')
    eq(Collision.canMove(map,{foot},foot,'down'),false,'water foot retains ordinary collision')
    eq(scene.groundAt(map,x,z,foot.px,(z+1)*16),0,'rendered water contact0, no terrain depression')
   end
  else
   eq(scene.groundAt(map,x,z),b.scene.groundAt(map,x,z),'all other original actor support')
  end
 end end
 for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do local k=z*map.widthCells+x
  eq(map:cellTile(x,z),savedTiles[k],'source tile remains exact')
  eq(map:isWalkableCell(x,z),savedWalk[k],'walk collision exact')
  eq(map:isWaterCell(x,z),savedWater[k],'surf flag exact')
  eq(map:warpAtCell(x,z),savedWarp[k],'warp identity exact')
 end end
end end
eq(cells,49,'all source cells traversed/considered')
eq(eligibilityChanges,98,'only49 cells in two automatic arena modes')
-- Position-aware battle ray samples, while manual placement coordinates stay exact.
local map=F.Map.new(F.maps.SEAFOAM_ISLANDS_B2F,F.tilesets.CAVERN)
local heightAt=H.upvalue(H.upvalue(arena.clearance,'lineClear'),'heightAt')
for z=0,15 do eq(heightAt(map,25*16+8,5*16+z+.5),6-1.5*math.floor(z/4),'battle visibility ray follows real tread')end
same(arena.at(25,5,'narrow'),oldArena.at(25,5,'narrow'),'manual battle framing untouched')
-- Execute each actual render consumer at all four heights.
local drawEntity=scene.drawEntity
local cast=H.upvalue(scene.render,'castShadows')
for _,h in ipairs({6,4.5,3,1.5})do
 local p={sprite=sprite,px=400,py=80,gh=h,lift=0,facing='down',phase=0,flip=false}
 local state={map=map,entities={},player={px=400,py=80},neighbors={}}
 draws={};drawEntity(sprite,p.px,p.py,p.facing,p.phase,p.flip,p.gh,nil,0)
 eq(#draws,1,'one solid character');eq(draws[1].matrix[8],h,'solid transform rests on tread')
 draws={};H.upvalue(scene.render,'drawGhost')(p)
 eq(draws[1].matrix[8],h,'occlusion silhouette rests on same tread')
 draws={};H.upvalue(scene.render,'drawShadow')(sprite,p.px,p.py,p.facing,p.phase,p.flip,p.gh,0)
 eq(draws[1].matrix[3],h,'fallback blob shadow uses exact tread')
 shadows={};cast(state,nil,{}, {p},0,0,160,144,function()end,nil,{},{},{})
 eq(#shadows,0,'current upstream suppresses outdoor sun maps in caves; fallback contact tested above')
 draws={};H.upvalue(scene.render,'drawCast')(state,{p},function()end)
 eq(draws[1].matrix[8],h,'world cast uses exact tread')
 -- Current upstream reflects the camera in Voxel3D, not actor matrices.
 -- The shared drawCast contact is checked above; GPU reflection needs playtest.
end
-- The non-CAVERN gate must preserve every other map's arena eligibility.
for id,d in pairs(F.maps)do if d.tileset~='CAVERN'then
 local m=F.Map.new(d,F.tilesets[d.tileset])
 for z=0,m.heightCells-1 do for x=0,m.widthCells-1 do for _,surf in ipairs({false,true})do
  eq(arena.openCell(m,x,z,surf),oldArena.openCell(m,x,z,surf),'all non-cave arena eligibility unchanged')
 end end end
end end
print(n..' cave step support/traversal checks passed; '..cells..' cells, '..traversals..' real Player/NPC steps, '..frames..' frame contacts; source/input/warps exact')