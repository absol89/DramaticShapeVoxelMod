-- Oak's original static starter balls rest on the table without moving
-- actors, changing source definitions, or shifting any other sprite.
local root=os.getenv('ASTRA_CANDIDATE')or'.'
local baseline=assert(os.getenv('ASTRA_PALLET_BASELINE'))
local H=dofile('tests/astra_fixture.lua');local F=dofile('tests/astra_scene_fixture.lua')
local data,aw,ah=H.atlas(assert(os.getenv('ASTRA_PALLET_SPRITE')))
local sprites=dofile(assert(os.getenv('ASTRA_GENERATED'))..'/sprites.lua')
local def=sprites.SPRITE_POKE_BALL
local n=0
local function ok(v,msg)n=n+1;assert(v,msg)end
local function same(a,b,msg)
 ok(type(a)==type(b),msg..' type')
 if type(a)~='table'then ok(a==b,msg);return end
 for k,v in pairs(a)do same(v,b[k],msg..'.'..tostring(k))end
 for k in pairs(b)do ok(a[k]~=nil,msg..' unexpected '..tostring(k))end
end
local function copy(a)if type(a)~='table'then return a end;local b={};for k,v in pairs(a)do b[k]=copy(v)end;return b end
local reads=0;local selected=data
local Assets=require('src.render.Assets')
Assets.image=function()return{getDimensions=function()return aw,ah end}end
Assets.imageData=function()reads=reads+1;return selected end
local draws,shadows={},{}
local function identity()return{1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}end
local voxel={
 newMesh=function(v,i)return{vertices=v,indices=i}end,
 pushQuad=function(out,k)for _,i in ipairs({1,2,3,1,3,4})do out[#out+1]=k*4+i end end,
 draw=function(mesh,tex,matrix)draws[#draws+1]={mesh=mesh,tex=tex,matrix=matrix}end,
 casterMatrix=function(px,py,y)return{px,py,y}end,
 shadowMatrix=function(px,py,y,lift)return{px,py,y,lift}end,
 glass=function()end,seams=function()end,
}
local bill=assert(loadfile(root..'/lib/SpriteBillboards.lua'))({require=function()return voxel end})
local oldbill=assert(loadfile(baseline..'/lib/SpriteBillboards.lua'))({require=function()return voxel end})
local saved=copy(def)
ok(bill.tableAnchor(def)==14,'measured original two-row lower margin')
ok(reads==1,'one source read');ok(bill.tableAnchor(def)==14 and reads==1,'source measurement cached')
local ordinary=bill.mesh(def,0);local grounded=bill.mesh(def,0,14)
same(ordinary,oldbill.mesh(def,0),'default item mesh remains exact A17')
ok(ordinary~=grounded,'visual and ordinary anchors have separate cache entries')
ok(bill.shadowQuad(def,0,14)==grounded,'solid/ghost/shadow share exact contact mesh')
for i,v in ipairs(ordinary.vertices)do
 ok(grounded.vertices[i][1]==v[1]and grounded.vertices[i][2]==v[2]-2 and grounded.vertices[i][3]==v[3],'only visual Y anchor shifts')
 for j=4,6 do ok(grounded.vertices[i][j]==v[j],'original sprite UV/color preserved')end
end
-- Mesh UVs inset the full frame slightly; the actual visible bottom is
-- within0.04px of local zero, versus a two-pixel A17 gap.
local a,b=grounded.vertices[1],grounded.vertices[4]
local bottom=a[2]+((14/ah-a[5])/(b[5]-a[5]))*(b[2]-a[2])
ok(math.abs(bottom)<0.05,'visible source edge touches support plane')
for _,change in ipairs({{anchorX=8},{anchorY=16},{trueColor=true},{walker=true},{frames=2},{frameHeight=32},{frameWidth=32},{id='SPRITE_RED'},{image='custom.png'}})do
 local custom=copy(def);for k,v in pairs(change)do custom[k]=v end
 ok(bill.tableAnchor(custom)==nil,'custom sprite metadata retains its own anchor')
end
local custom=copy(def);custom.anchorY=12
same(bill.mesh(custom,0,14),oldbill.mesh(custom,0),'explicit vertical anchor wins')
-- A same-path image override must match the measured original padding.
for _,kind in ipairs({'lower-pixel','colored','size'})do
 bill.invalidate()
 selected={getDimensions=function()return kind=='size'and 32 or aw,ah end,
  getPixel=function(_,x,y)
   if kind=='lower-pixel'and x==8 and y==15 then return 0,0,0,1 end
   if kind=='colored'and x==8 and y==8 then return 1,0,0,1 end
   return data:getPixel(x,y)
  end}
 ok(bill.tableAnchor(def)==nil,'changed source '..kind..' declines correction')
end
selected=data;bill.invalidate();ok(bill.tableAnchor(def)==14,'asset invalidation remeasures original source')
same(def,saved,'generated sprite definition never mutated')

local r=F.runtime(root)
local modules={
 SpriteBillboards=bill,TileShape=r.shapes,Voxel3D=voxel,
 Mat4=assert(loadfile(root..'/lib/Mat4.lua'))(),
 VoxelState={angle=math.pi/2},
 FirstPerson={cardBlend=function()return 0 end,hidePlayer=function()return false end,signature=function()return''end},
 RenderDistance={point=function()return true end,neighbor=function()return true end},
 ModSetting={new=function()return{get=function()return true end}end},
 ShadowMap={discard=function()end,available=function()return true end,stale=function()return true end,begin=function()return true end,
  draw=function(mesh)if mesh then shadows[#shadows+1]=mesh end end,
  snug=function(m)return m end,sprites=function()end,finish=function()end,KX=0,KZ=0},
 CharacterRenderers={all=function()end,revision=function()return 0 end,first=function()return nil end},
 CavePerimeter={draw=function()end},
 CommunityFlora={shadowSignature=function()return''end,castShadows=function()end},
 ChunkMesher={flowers=function()end,figures=function()return{}end},
}
-- Load the real A20 ship hook; non-dock maps must remain a render no-op.
modules.ShipHull=assert(loadfile(root..'/lib/ShipHull.lua'))({
 require=function(name)return modules[name]or{}end,data=function()return r.spec end})
local scene=assert(loadfile(root..'/lib/VoxelScene.lua'))({require=function(name)return modules[name]or{}end})
local poses=H.upvalue(scene.render,'posesOf')
local map=F.Map.new(F.maps.OAKS_LAB,F.tilesets.DOJO)
local event
for _,d in ipairs(map.def.objects)do if d.name=='OAKSLAB_EEVEE_POKE_BALL'then event=d end end
ok(event~=nil,'actual Yellow starter item event')
local sprite={def=def,resolveImage=function()return'live-sprite-texture'end}
local e={def=event,cellX=event.x,cellY=event.y,px=event.x*16,py=event.y*16,moving=false}
function e:pose()return sprite,self.px,self.py,'down',0,false end
local state={map=map,entities={e},player={px=0,py=0},neighbors={}}
local p=poses(state,function()end)[1]
ok(p.visualAnchorY==14 and p.gh==6 and p.lift==0,'actual static item keeps support6 with visual anchor14')
local ground=scene.groundAt(map,event.x,event.y);ok(ground==6,'table support unchanged')
local beforeEvent=copy(event)
local anchored=copy(p)
-- Do not move any other item, actor, replacement or moving scripted object.
for _,field in ipairs({'map','name','moving','support','position','definition'})do
 local bad=copy(e);bad.pose=e.pose
 local bmap=map
 if field=='map'then bmap=F.Map.new(F.maps.REDS_HOUSE_1F,F.tilesets.REDS_HOUSE_1)
 elseif field=='name'then bad.def=copy(event);bad.def.name='OAKSLAB_POKEDEX1'
 elseif field=='moving'then bad.moving=true
 elseif field=='support'then bad.cellY=4;bad.py=64
 elseif field=='position'then bad.px=bad.px+1
 elseif field=='definition'then bad.def=copy(event);bad.def.movement='WALK'end
 local other=poses({map=bmap,entities={bad},player=state.player},function()end)[1]
 ok(other.visualAnchorY==nil,'ordinary pose/reset retained for '..field)
end
-- Neighbor ghosts use their own map, identity and unshifted source coords.
local ghost=poses({map=F.Map.new(F.maps.PALLET_TOWN,F.tilesets.OVERWORLD),entities={},ghosts={{npc=e,map=map,ox=160,oy=0}},player=state.player},function()end)[1]
ok(ghost.visualAnchorY==14 and ghost.px==e.px+160,'ghost uses own map contact with world translation')
p=poses(state,function()end)[1]
grounded=bill.mesh(def,0,14)
draws={};scene.drawEntity(sprite,p.px,p.py,p.facing,p.phase,p.flip,p.gh,p.colors,p.lift,p.visualAnchorY)
ok(#draws==1 and draws[1].mesh==grounded,'solid draw uses contact mesh')
draws={};H.upvalue(scene.render,'drawGhost')(p)
ok(#draws==1 and draws[1].mesh==grounded,'occlusion silhouette uses contact mesh')
draws={};H.upvalue(scene.render,'drawShadow')(sprite,p.px,p.py,p.facing,p.phase,p.flip,p.gh,p.lift,p.visualAnchorY)
ok(#draws==1 and draws[1].mesh==grounded and draws[1].matrix[3]==6,'fallback shadow uses same contact mesh/support')
local cast=H.upvalue(scene.render,'castShadows')
shadows={};cast(state,nil,{}, {p},0,0,160,144,function()end,nil,{},{},{})
ok(#shadows==1 and shadows[1]==grounded,'sun caster uses contact mesh')
draws={};H.upvalue(scene.render,'drawCast')(state,{p},function()end)
ok(#draws==1 and draws[1].mesh==grounded,'world and reflection cast share contact mesh')
local signature=H.upvalue(cast,'shadowSignature')
local s=signature(state,nil,{}, {p},0,0,160,144)
p.visualAnchorY=nil
ok(signature(state,nil,{}, {p},0,0,160,144)~=s,'shadow cache notices anchor changes')
same(event,beforeEvent,'object event/2D metadata retained')
same(def,saved,'all passes preserve source definition')
print(n..' Oak item contact checks passed; measured2px margin, scoped pose, originalUV/default/custom parity, solid/ghost/sun/blob/reflection consistency')
