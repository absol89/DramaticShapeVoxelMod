-- TEST127: colorless water depth after reflections, before actors.
-- The reflective pass detaches depth and cannot write it. Without this sheet,
-- even correctly submerged actors are painted whole over the finished water.
local V=...;local M={};local shader
M.SOURCE=[[
#ifdef GL_ES
precision highp float;
#endif
#ifdef VERTEX
uniform mat4 vp,model;
uniform vec3 curve;
vec4 position(mat4 ignored,vec4 p){
 p=model*p;
 vec2 d=p.xz-curve.xy;p.y-=dot(d,d)*curve.z;
 return vp*p;
}
#endif
#ifdef PIXEL
vec4 effect(vec4 color,Image tex,vec2 tc,vec2 sc){
 if(Texel(tex,tc).a<.5)discard;
 return vec4(0.0);
}
#endif
]]
function M.draw(draws)
 local g=love.graphics;local R=V.require('Voxel3D')
 if not(R.vp and g.setColorMask)then return false end
 if shader==nil then
  local ok,s=pcall(g.newShader,M.SOURCE);shader=ok and s or false
 end
 if not shader then return false end
 g.push('all')
 local ok=pcall(function()
  g.setShader(shader);g.setColorMask(false,false,false,false)
  g.setDepthMode('lequal',true);g.setMeshCullMode('none')
  shader:send('vp','row',R.vp)
  shader:send('curve',{R.curveX or 0,R.curveZ or 0,R.curveK or 0})
  for _,d in ipairs(draws or{})do
   local custom=(V.require('CommunityVisuals').customRoads()
    and V.require('DecorAtlas').texelScale(d[2])>1)
    or V.require('SafariMaterials').texelScale(d[2])
   if custom and d[1] and d[2] then
    d[1]:setTexture(d[2])
    shader:send('model','row',d[3]or V.require('Mat4').identity())
    g.draw(d[1])
   end
  end
 end)
 g.pop()
 return ok
end
return M
