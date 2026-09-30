-- Snapshot before water/characters, including a packed 24-bit depth image.
-- Standard RGBA8 canvases keep this usable on the existing mobile backend.
local V=...;local M={};local shader
M.PACK_SOURCE=[[
#ifdef GL_ES
precision highp float;
#endif
uniform LOVE_HIGHP_OR_MEDIUMP Image sourceDepth;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
 float d=clamp(Texel(sourceDepth,uv).r,0.0,1.0);
 float v=floor(d*16777215.0+.5);
 float r=floor(v/65536.0);v-=r*65536.0;
 float g=floor(v/256.0);float b=v-g*256.0;
 return vec4(r,g,b,255.0)/255.0;
}
]]
function M.inverse(m)
 local a={}
 for r=1,4 do a[r]={};for c=1,4 do a[r][c]=m[(r-1)*4+c];a[r][c+4]=r==c and 1 or 0 end end
 for c=1,4 do
  local pivot=c;for r=c+1,4 do if math.abs(a[r][c])>math.abs(a[pivot][c])then pivot=r end end
  if math.abs(a[pivot][c])<1e-12 then return nil end
  a[c],a[pivot]=a[pivot],a[c];local d=a[c][c]
  for j=1,8 do a[c][j]=a[c][j]/d end
  for r=1,4 do if r~=c then local k=a[r][c];for j=1,8 do a[r][j]=a[r][j]-k*a[c][j]end end end
 end
 local out={};for r=1,4 do for c=1,4 do out[#out+1]=a[r][c+4]end end;return out
end
function M.capture(slot,canvas,restore)
 local g=love.graphics
 if shader==nil then local ok,s=pcall(g.newShader,M.PACK_SOURCE);shader=ok and s or false end
 if not shader then return nil end
 for _,name in ipairs({'underColor','underDepth'})do
  if not slot[name] then
   local ok,c=V.require('PixelCanvas').new(name=='underColor' and math.max(1,math.ceil(slot.w/2)) or slot.w,
     name=='underColor' and math.max(1,math.ceil(slot.h/2)) or slot.h)
   if not (ok and c)then return nil end
   c:setFilter(name=='underColor' and 'linear' or 'nearest',name=='underColor' and 'linear' or 'nearest');c:setWrap('clamp','clamp');slot[name]=c
  end
 end
 g.push('all')
 local ok=pcall(function()
  g.origin();g.setScissor();g.setStencilTest();g.setDepthMode();g.setShader();g.setColor(1,1,1,1)
  g.setBlendMode('replace','premultiplied');g.setCanvas(slot.underColor);g.clear(0,0,0,0);g.draw(canvas,0,0,0,math.max(1,math.ceil(slot.w/2))/slot.w,math.max(1,math.ceil(slot.h/2))/slot.h)
  g.setCanvas(slot.underDepth);g.clear(1,1,1,1);g.setShader(shader);shader:send('sourceDepth',slot.depth);g.draw(canvas)
 end)
 g.pop();local restored=pcall(g.setCanvas,restore)
 if not ok or not restored then return nil end
 return slot.underColor,slot.underDepth
end
return M
