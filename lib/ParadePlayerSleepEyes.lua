-- Selected Ash model: its eyes are painted into the face atlas, not NPC eye
-- tiles. A cached presentation canvas closes that exact UV patch. It samples
-- nearby skin at the same height to preserve the cap's painted shadow, and
-- adds a curved eyelid. No pack texture, mesh UV or player selection is edited.
local M={REVISION='parade-player-sleep-eyes-241'}
local cache=setmetatable({},{__mode='k'})
local shader=nil
local checked=setmetatable({},{__mode='k'})
local ASH={
 {3942,.22851368,.94234853},{3943,.22210747,.94296113},
 {3956,.22852017,.95251823},{3957,.22949726,.96241625},
 {3981,.22851368,.94234853},{4070,.23214607,.94793060},
}
M.FINGERPRINT=ASH
M.SHADER=[[
vec4 effect(vec4 color, Image atlas, vec2 uv, vec2 screen) {
 vec4 original=Texel(atlas,uv);
 vec2 p=uv*vec2(1536.0,1920.0);
 float cover=smoothstep(337.5,338.5,p.x)*(1.0-smoothstep(364.0,365.0,p.x))
            *smoothstep(1809.0,1810.0,p.y)*(1.0-smoothstep(1850.0,1851.0,p.y));
 vec3 skin=Texel(atlas,vec2(370.5/1536.0,uv.y)).rgb;
 float x=(p.x-351.5)/12.0;
 float curve=1835.0+3.0*(1.0-x*x);
 float lid=(1.0-smoothstep(0.65,1.45,abs(p.y-curve)))
           *(1.0-smoothstep(0.92,1.04,abs(x)));
 vec3 closed=mix(skin,vec3(0.075,0.055,0.055),lid);
 return vec4(mix(original.rgb,closed,cover),original.a)*color;
}
]]
function M.matches(mesh)
 if checked[mesh]~=nil then return checked[mesh]end
 local ok,n=pcall(mesh.getVertexCount,mesh)
 if not ok or n~=4858 or type(mesh.getVertexAttribute)~='function'then checked[mesh]=false;return false end
 for _,v in ipairs(ASH)do
  local good,u,w=pcall(mesh.getVertexAttribute,mesh,v[1],2)
  if not good or type(u)~='number'or type(w)~='number'or math.abs(u-v[2])>.000002 or math.abs(w-v[3])>.000002 then
   checked[mesh]=false;return false
  end
 end
 checked[mesh]=true;return true
end
function M.texture(mesh,tex)
 if not(mesh and tex and M.matches(mesh))then return tex end
 if cache[tex]~=nil then return cache[tex]or tex end
 local g=love and love.graphics
 if not(g and g.newCanvas and g.newShader and g.push and g.pop)then return tex end
 local ok,w,h=pcall(tex.getDimensions,tex)
 if not ok or w~=1536 or h~=1920 then cache[tex]=false;return tex end
 local canvas,pushed
 local good=pcall(function()
  if shader==nil then
   local made,s=pcall(g.newShader,M.SHADER);shader=made and s or false
  end
  if not shader then return end
  canvas=g.newCanvas(w,h,{format='rgba8',readable=true,msaa=0})
  g.push('all');pushed=true
  g.setCanvas(canvas);g.origin();g.setScissor();g.setStencilTest();g.setDepthMode()
  g.setBlendMode('replace','premultiplied');g.setColor(1,1,1,1);g.setShader(shader)
  g.draw(tex,0,0)
 end)
 if pushed then local restored=pcall(g.pop);good=good and restored end
 if not good and canvas then pcall(canvas.release,canvas);canvas=nil end
 if canvas then
  pcall(function()canvas:setFilter(tex:getFilter())end)
  pcall(function()canvas:setWrap(tex:getWrap())end)
 end
 cache[tex]=canvas or false;return canvas or tex
end
function M.clear()
 for _,c in pairs(cache)do if c then pcall(c.release,c)end end
 if shader then pcall(shader.release,shader)end
 cache=setmetatable({},{__mode='k'});checked=setmetatable({},{__mode='k'});shader=nil
end
return M
