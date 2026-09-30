-- Scoped high-resolution reserve stone. One cached atlas per live Safari map.
-- No new shader, material ID or terrain subdivision; source water keeps animating.
local V=...;local M={};local entries={};local tileImages={}
local scales=setmetatable({},{__mode='k'})
-- Read the actual atlas owner per draw, including connected maps and scale-1 GPUs.
function M.texelScale(texture)return scales[texture]end
-- Smooth periodic value noise, evaluated only when the two shared patches bake.
-- Four world cells share a patch: seams no longer outline every eight-pixel tile.
local function noise(x,y,period,salt)
 local C=V.require('SurfaceCraft');local ix,iy=math.floor(x),math.floor(y)
 local a,b=x-ix,y-iy;a=a*a*(3-2*a);b=b*b*(3-2*b)
 local function v(i,j)return C.hash(i%period,j%period,salt)end
 return(v(ix,iy)*(1-a)+v(ix+1,iy)*a)*(1-b)+(v(ix,iy+1)*(1-a)+v(ix+1,iy+1)*a)*b
end
function M.pixel(x,y,variant)
 local C=V.require('SurfaceCraft');x=x%64;y=y%64
 local broad=noise(x/16,y/16,4,1111)-.5
 local grain=(C.hash(x,y,1117)-.5)*.045
 local mineral=noise(x/4,y/4,16,1113)-.5
 local vein=noise(x/8,y/8,8,1119)
 local crack=math.max(0,1-math.abs(vein-.48)*95)*math.max(0,noise(x/16,y/16,4,1123)-.46)*.3
 local chip=C.hash(x,y,1129)>.974 and .038 or 0
 local wear=broad*.13+mineral*.09+grain-crack+chip
 local r,g,b=.49,.467,.382
 if variant=='side'then r,g,b=.365,.358,.294;wear=wear*.85 end
 return r+wear,g+wear,b+wear,1
end
function M.uv(u0,u1,v0,v1,x,z)
 local du,dv=(u1-u0)/4,(v1-v0)/4
 local u,v=u0+(x%4)*du,v0+(z%4)*dv
 return{{u,v},{u+du,v},{u+du,v+dv},{u,v+dv}}
end
function M.sideUV(u0,u1,v0,v1,q,axis,a,y0)
 local uv={};local du,dv=(u1-u0)/4,(v1-v0)/4
 for i,p in ipairs(q)do
  uv[i]={u0+((a/8)%4+(p[axis]-a)/8)*du,v0+((y0/8)%4+(p[2]-y0)/8)*dv}
 end
 return uv
end
local function release(x)if x then scales[x]=nil;if x.release then pcall(x.release,x)end end end
-- A Safari-only distant meadow replaces the unrelated rectangular field art.
-- Shared with the existing backdrop draw; mountains and sky are untouched.
function M.distantGround()
 if tileImages.distant then return tileImages.distant end
 local ok,img=pcall(function()
  local data=love.image.newImageData(128,128)
  for y=0,127 do for x=0,127 do
   local v=(noise(x/32,y/32,4,1133)-.5)*.055+(noise(x/4,y/4,32,1139)-.5)*.018
   data:setPixel(x,y,.245+v,.325+v,.175+v,1)
  end end
  local tex=love.graphics.newImage(data);data:release()
  tex:setWrap('repeat','repeat');tex:setFilter('linear','linear');return tex
 end)
 if ok then tileImages.distant=img;return img end
end
function M.setLive(live)
 for id,e in pairs(entries)do if not live[id]then release(e.image);entries[id]=nil end end
 if not next(entries)then for k,t in pairs(tileImages)do release(t);tileImages[k]=nil end end
end
function M.invalidate()M.setLive({})end
local function tileImage(kind)
 if tileImages[kind]then return tileImages[kind]end
 local data=love.image.newImageData(64,64)
 for y=0,63 do for x=0,63 do data:setPixel(x,y,M.pixel(x,y,kind))end end
 local img=love.graphics.newImage(data);img:setFilter('linear','linear');data:release();tileImages[kind]=img;return img
end
function M.apply(map,base)
 if not V.require('SafariReserve').enabled(map)then return base end
 local g=love.graphics;local w,h=base:getDimensions();local e=entries[map.id]
 local scale=8;local limit=g.getSystemLimits().texturesize or 2048
 while scale>1 and(w*scale>limit or h*scale>limit)do scale=scale/2 end
 if w*scale>limit or h*scale>limit then return base end
 local tick=math.floor(love.timer.getTime()*8)
 if e and e.base==base and e.tick==tick then return e.image end
 local previous=g.getCanvas();local pushed=false;local canvas
 local ok,result=pcall(function()
  if e and e.w==w*scale and e.h==h*scale then canvas=e.image
  else if e then release(e.image)end;entries[map.id]=nil;canvas=g.newCanvas(w*scale,h*scale,{dpiscale=1})end
  g.push('all');pushed=true;g.setCanvas(canvas);g.origin();g.setShader();g.setScissor();g.setDepthMode();g.setStencilTest()
  g.setBlendMode('replace','premultiplied');g.setColor(1,1,1,1);g.clear(0,0,0,0);g.draw(base,0,0,0,scale,scale)
  local perRow=map.tileset.tilesPerRow or 16
  for _,tile in ipairs({30,46})do g.draw(tileImage('top'),tile%perRow*8*scale,math.floor(tile/perRow)*8*scale,0,scale/8,scale/8)end
  -- Tile 47 is a claimed rim on Legendary Safari; use its private region on risers.
  g.draw(tileImage('side'),47%perRow*8*scale,math.floor(47/perRow)*8*scale,0,scale/8,scale/8)
  g.setCanvas(previous);g.pop();pushed=false;canvas:setFilter('nearest','nearest')
  return {image=canvas,base=base,tick=tick,w=w*scale,h=h*scale}
 end)
 if pushed then pcall(g.setCanvas,previous);pcall(g.pop)end
 if not ok then release(canvas);entries[map.id]=nil;return base end
 entries[map.id]=result;scales[result.image]=scale;return result.image
end
return M
