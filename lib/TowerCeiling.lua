-- TEST12: quiet honed-stone barrel vault, supported by the wall cornice.
local V=...
local R=V.require('Voxel3D')
local Stone=V.require('TowerStone')
local Assets=require('src.render.Assets')
local M={tint={Stone.tint[1],Stone.tint[2],Stone.tint[3],1}}
local cache={}
function M.enabled(map)
 return map and map.tileset and map.tileset.id=='CEMETERY'
  and tostring(map.id or ''):match('^POKEMON_TOWER_[1-7]F$')~=nil
  and V.require('CommunityVisuals').customTower()
end
function M.layout(map)
 local shape=V.require('TileShape').forMap(map)
 local sw=map.tileset.imageWidth or 128
 return {width=(map.widthCells or map.def.width*2)*16,
  depth=(map.heightCells or map.def.height*2)*16,
  height=shape.classes and shape.classes.wall and shape.classes.wall.h or 64,
  wallX=sw,atlasWidth=sw+2048+1024,atlasHeight=math.max(map.tileset.imageHeight or 48,4096)}
end
function M.surface(b,x,z)
 -- Ends meet the cornice; the shallow crown remains below the wall cap.
 return b.height-5+4.3*math.sin(math.pi*x/b.width)
end
function M.geometry(b,ribs)
 local vs,ix={},{}
 local span=math.max(b.width,b.depth)+192
 local function quad(a,c,d,e,shade)
  local n=#vs
  for _,p in ipairs({a,c,d,e})do
   -- Same 96-unit render-ring margin and isotropic scale as the wall.
   local u=(b.wallX+.5+(p[1]+96)/span*2047)/b.atlasWidth
   local v=(.5+(p[3]+96)/span*2047)/b.atlasHeight
   vs[#vs+1]={p[1],p[2],p[3],u,v,shade}
  end
  for _,i in ipairs({1,2,3,1,3,4})do ix[#ix+1]=n+i end
 end
 local function p(x,z,drop)return{x,M.surface(b,x,z)-(drop or 0),z}end
 if not ribs then
  for z=0,b.depth-1,32 do for x=0,b.width-1,8 do
   local X,Z=math.min(x+8,b.width),math.min(z+32,b.depth)
   quad(p(x,z),p(X,z),p(X,Z),p(x,Z),.88)
  end end
 else
  -- Every second 32-unit wall pilaster supports an arch. Wide bevels make
  -- the structure readable at gameplay distance without luminous panel grids.
  local section={{-3.6,0},{-2.8,1.5},{-1.7,2.6},{1.7,2.6},{2.8,1.5},{3.6,0}}
  local tones={.70,.82,1.00,.90,.76}
  for z=32,b.depth-8,64 do for x=0,b.width-1,8 do
   local X=math.min(x+8,b.width)
   for j=1,#section-1 do
    local a,c=section[j],section[j+1]
    quad(p(x,z+a[1],a[2]),p(X,z+a[1],a[2]),
      p(X,z+c[1],c[2]),p(x,z+c[1],c[2]),tones[j])
   end
  end end
 end
 return vs,ix
end
local function release(x)if x and x.release then pcall(x.release,x)end end
function M.invalidate()
 for _,slot in pairs(cache)do release(slot.mesh);release(slot.ribs)end
 cache={}
end
function M.draw(map,atlas)
 if not M.enabled(map)or not atlas then return false end
 -- TEST174: the authored Tower floors (InteriorRooms) raise their own vault
 do local okI,own=pcall(function()return V.require('InteriorRooms').accepts(map)end)
  if okI and own then return false end end
 local b=M.layout(map)
 if not R.eye or R.eye[2]>=b.height-7.6 then return false end
 local slot=cache[map.id]
 if not slot or slot.width~=b.width or slot.depth~=b.depth or slot.height~=b.height
  or slot.atlasWidth~=b.atlasWidth or slot.atlasHeight~=b.atlasHeight then
  if slot then release(slot.mesh);release(slot.ribs);cache[map.id]=nil end
  b.mesh=R.newMesh(M.geometry(b,false))
  local ok,result=pcall(R.newMesh,M.geometry(b,true))
  if not ok then release(b.mesh);error(result)end
  b.ribs=result;cache[map.id]=b;slot=b
 end
 if not slot.mesh or not slot.ribs then return false end
 R.glass(false)
 love.graphics.push('all');love.graphics.setColor(1,1,1,1)
 local ok,err=pcall(function()
  Stone.drawVault(R,slot.mesh,atlas,.80)
  Stone.drawVault(R,slot.ribs,atlas,.72)
 end)
 love.graphics.pop()
 if not ok then error(err)end
 return true
end
Assets.register(M.invalidate)
return M
