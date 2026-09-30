-- TEST17: retain TEST16 wood/lawn; add donor 48 only for opted-in Lavender courtyard.
-- One output canvas per live map, refreshed from the current baseline animation
-- frame. Small wood/lawn patches are shared; no expanded atlas per water frame.
local V=...
local M={}
local entries, patches, failed={},{},{}
local scales=setmetatable({},{__mode='k'})
function M.texelScale(texture)return scales[texture] or 1 end
local function release(object)if object and object.release then pcall(object.release,object)end end
local function discard(id)
 local e=entries[id]
 if e then scales[e.image]=nil;release(e.image);entries[id]=nil end
end
local function patch(lavender,courtyard,roads,coast,harbor,trail,celadon,city)
 local key=(lavender and 'lavender' or 'ordinary')..tostring(courtyard)..tostring(roads)..tostring(coast)..tostring(harbor)..tostring(trail)..tostring(celadon)..tostring(city)
 if patches[key] then return patches[key] end
 local g=love.graphics;local image;local previous=g.getCanvas();local pushed=false
 local ok,result=pcall(function()
  local height=roads and 512 or courtyard and 384 or 256
  local detail=celadon and 2 or 1
  image=g.newCanvas(128*detail,height*detail,{dpiscale=1})
  g.push('all');pushed=true;g.setCanvas(image);g.origin();g.setShader();g.setScissor();g.setDepthMode();g.setStencilTest()
  g.setBlendMode('replace','premultiplied');g.clear(0,0,0,0)
  if detail>1 then g.scale(detail,detail)end
  V.require('SurfaceMaterials').wood(g,0,0,128)
  local palette={lavender and {.26,.355,.20} or {.28,.385,.235},
    lavender and {.56,.37,.70} or {.85,.33,.49},
    lavender and {.235,.355,.20} or {.22,.40,.24},{.95,.77,.39}}
  if city then palette[2]=V.require('CityStreets').themes[city].flower end
  if coast then palette[2]={.94,.65,.42};palette[3]={.34,.47,.29} end
  for i,c in ipairs(palette)do
   g.setColor(c[1],c[2],c[3],1);g.rectangle('fill',(i+3)*16,0,16,16)
  end
  V.require('LawnMaterial').draw(g,0,128,128,lavender and 'LAVENDER_TOWN' or '')
  if courtyard then
   V.require('SurfaceMaterials').stone(g,0,272,128,112,'lavender')
   local stone=V.require('LavenderCourtyard').palette('LAVENDER_TOWN')
   for i,name in ipairs({'dark','shadow','body','light'})do
    local c=stone[name];g.setColor(c[1],c[2],c[3],1);g.rectangle('fill',(i-1)*16,256,16,16)
   end
   for i,c in ipairs(palette)do
    g.setColor(c[1],c[2],c[3],1);g.rectangle('fill',(i+3)*16,256,16,16)
   end
  end
  if roads then
   V.require('SurfaceMaterials').stone(g,0,400,128,112,trail and 'trail' or harbor and 'vermilion' or coast and 'cinnabar' or lavender and 'lavender' or 'stone')
   local colors=lavender and {{.25,.29,.29},{.36,.38,.47},{.52,.54,.64},{.73,.74,.79}}
     or {{.27,.29,.24},{.39,.40,.38},{.59,.60,.55},{.77,.78,.70}}
   if coast then colors={{.18,.21,.21},{.33,.34,.32},{.47,.49,.49},{.70,.61,.45}} end
   -- Populate the complete donor row without decorative colors.
   for i=0,7 do local c=colors[math.min(i+1,4)]
    g.setColor(c[1],c[2],c[3],1);g.rectangle('fill',i*16,384,16,16)
   end
  end
  if roads and city then
   V.require('CityStreets').draw(g,city)
  end
  if roads and celadon then
   V.require('CeladonBrickMaterial').draw(g,detail)
   for i,c in ipairs({{.94,.91,.82},{.64,.43,.78},{.24,.19,.13}})do
    g.setColor(c[1],c[2],c[3],1);g.rectangle('fill',(i+3)*16,384,16,16)
   end
  end
  g.setCanvas(previous);g.pop();pushed=false;image:setFilter('nearest','nearest')
  local function quad(x,y,w,h)return g.newQuad(x*detail,y*detail,w*detail,h*detail,128*detail,height*detail)end
  return {image=image,detail=detail,wood=quad(0,0,128,128),grass=quad(0,128,128,128),
   court=courtyard and quad(0,256,128,128) or nil,
   path=roads and quad(0,384,128,128) or nil}
 end)
 if pushed then pcall(g.setCanvas,previous);pcall(g.pop)end
 if not ok then release(image);error(result)end
 patches[key]=result;return result
end
function M.apply(map,base)
 if not base or not map or not map.tileset then return base end
 local id=map.id
 if map.tileset.id~='OVERWORLD' then return base end
 local CV=V.require('CommunityVisuals')
 local roads=CV.customRoads()
 local lawn
 if CV.isCityGroundMap(map) then lawn=CV.customCityGround() else lawn=CV.customGrass() end
 if not roads and not lawn then discard(id);failed[id]=nil;return base end
 local coast=id=='CINNABAR_ISLAND' and roads
 local harbor=id=='VERMILION_CITY' and roads
 local trail=id=='ROUTE_11' and roads
 local celadon=id=='CELADON_CITY' and roads
 local city=V.require('CityStreets').enabled(id,roads,map.tileset.id) and id or nil
 local lavender=id=='LAVENDER_TOWN'
 local courtyard=lavender and CV.customCityGround()
 local w,h=base:getDimensions();local perRow=map.tileset.tilesPerRow or 16
 local key=tostring(roads)..':'..tostring(lawn)..':'..tostring(lavender)..':'..tostring(courtyard)..':'..w..':'..h..':'..perRow..':'..tostring(coast)..tostring(harbor)..tostring(trail)..tostring(celadon)..tostring(city)
 if failed[id]==key then return base end
 local e=entries[id]
 if e and e.key==key and e.base==base then return e.image end
 local g=love.graphics;local previous=g.getCanvas();local pushed=false;local canvas
 local ok,result=pcall(function()
  local p=patch(lavender,courtyard,roads,coast,harbor,trail,celadon,city)
  local scale=celadon and 32 or 16;local limit=g.getSystemLimits().texturesize or 4096
  while scale>1 and (w*scale>limit or h*scale>limit)do scale=scale/2 end
  assert(w*scale<=limit and h*scale<=limit,'decoration atlas exceeds GPU limit')
  -- Returning the source is safer than advertising scaled UV metadata at 1x.
  assert(scale>1,'no room for decoration atlas')
  if not e or e.width~=w*scale or e.height~=h*scale then
   discard(id);e=nil;canvas=g.newCanvas(w*scale,h*scale,{dpiscale=1})
  else canvas=e.image end
  g.push('all');pushed=true;g.setCanvas(canvas);g.origin();g.setShader();g.setScissor();g.setDepthMode();g.setStencilTest()
  g.setColor(1,1,1,1);g.setBlendMode('replace','premultiplied');g.clear(0,0,0,0)
  g.draw(base,0,0,0,scale,scale)
  if roads then g.draw(p.image,p.wood,60%perRow*8*scale,math.floor(60/perRow)*8*scale,0,scale/(16*p.detail),scale/(16*p.detail))end
  if lawn then g.draw(p.image,p.grass,44%perRow*8*scale,math.floor(44/perRow)*8*scale,0,scale/(16*p.detail),scale/(16*p.detail))end
  if courtyard then g.draw(p.image,p.court,48%perRow*8*scale,math.floor(48/perRow)*8*scale,0,scale/(16*p.detail),scale/(16*p.detail))end
  if roads then
   local tile=courtyard and 35 or 57
   g.draw(p.image,p.path,tile%perRow*8*scale,math.floor(tile/perRow)*8*scale,0,scale/(16*p.detail),scale/(16*p.detail))
  end
  g.setCanvas(previous);g.pop();pushed=false;canvas:setFilter('nearest','nearest')
  scales[canvas]=scale
  entries[id]={image=canvas,base=base,key=key,width=w*scale,height=h*scale}
  return canvas
 end)
 if pushed then pcall(g.setCanvas,previous);pcall(g.pop)end
 if not ok then
  if e and e.image==canvas then discard(id)else release(canvas)end
  failed[id]=key
  print('[Battle Art TEST16] decoration atlas unavailable: '..tostring(result))
  return base
 end
 failed[id]=nil;return result
end
function M.setLive(live)
 for id in pairs(entries)do if not live[id]then discard(id)end end
 for id in pairs(failed)do if not live[id]then failed[id]=nil end end
 if next(entries)==nil then
  for key,p in pairs(patches)do release(p.image);release(p.wood);release(p.grass);release(p.court);release(p.path);patches[key]=nil end
 end
end
return M
