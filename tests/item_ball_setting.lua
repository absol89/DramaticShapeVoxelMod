-- Production item renderer, provider bridge, settings and preset integration.
local modules, stored = {}, {}
local V={mod={id='BATTLE_ART_VOXEL_FORK',options={get=function(_,key)return stored[key]end}}}
V.require=function(name)return assert(modules[name],name)end
local function load(name)
 modules[name]=assert(loadfile('lib/'..name..'.lua'))(V);return modules[name]
end
local Setting=load('ModSetting')
local Community=load('CommunityVisuals')
local Items=load('ItemPokeballs')
modules.TowerFogSettings={
 details=Setting.new('towerDetails','DETAILS',{'off','subtle','full'}),
 enabled=Setting.new('towerFog','FOG',{'off','on'})}
modules.ForestAtmos={setting=Setting.new('forestFx','FOREST FX',{'off','low'})}
local Preset=load('LegendaryVisualsPreset')
local Bridge=load('CharacterRenderers')
modules.Mat4=assert(loadfile('lib/Mat4.lua'))()
local allocations,draws,shadows=0,0,0
modules.Voxel3D={newMesh=function(vertices,indices)
 allocations=allocations+1;assert(#vertices>0 and #indices>0)
 return {release=function()end}
end,draw=function()draws=draws+1 end}
modules.ShadowMap={draw=function()shadows=shadows+1 end}
love={image={newImageData=function()return{setPixel=function()end,release=function()end}end},
 graphics={newImage=function()return{setFilter=function()end,release=function()end}end}}
local item={spriteId='SPRITE_POKE_BALL',px=16,py=32,groundHeight=4}
assert(Items.setting.label=='ITEM BALL')
assert(Items.setting.labels[1]=='BATTLE ART' and Items.setting.labels[2]=='LEGENDARY VISUALS')
assert(not Items.enabled(),'OFF preset must use sprite')
for _,method in ipairs({'drawEntity','drawReflection','drawShadow'})do
 assert(not Items.draw(item) and not Bridge.first(method,item),'sprite fallback was claimed')
end
assert(allocations==0 and draws==0 and shadows==0,'OFF allocated or rendered a mesh')
Preset.setting:sync('auto')
assert(Items.enabled() and Items.draw(item) and allocations==1 and draws==1)
assert(Bridge.first('drawShadow',item) and shadows==1)
item.reflectionPlane=2;item.reflectionRaise=1
assert(Bridge.first('drawReflection',item) and draws==2)
assert(Items.transform(item,true)[8]==1,'reflection transform changed')
assert(not Items.draw({isPlayer=true,spriteId='SPRITE_POKE_BALL'}))
assert(not Items.draw({spriteId='SPRITE_NPC'}))
Preset.setting:sync('full');assert(Items.enabled())
Preset.setting:sync('custom');Items.setting:sync('default')
assert(not Items.draw(item))
local writes=0
local game={save={options={}},mods={},writeOptions=function()writes=writes+1 end}
Items.setting:row().step(game,1)
assert(Items.enabled() and game.save.options.modOptions.BATTLE_ART_VOXEL_FORK.itemBall=='legendary')
assert(game.mods.modOptions.BATTLE_ART_VOXEL_FORK.itemBall=='legendary' and writes==1)
Preset.setting:sync('off');assert(not Items.enabled())
Preset.setting:sync('custom');assert(Items.enabled(),'preset erased custom choice')
assert(Items.draw(item) and allocations==1,'live toggle rebuilt the ball unnecessarily')
local schema=Items.setting:schema('Item ball presentation')
assert(schema,'mod manager option schema missing')
print('PASS item ball sprite/mesh, world/reflection/shadow, profile, persistence and actor guards')
