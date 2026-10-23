-- TEST23 uses the former tree generator's exact baked bark/leaf images.
-- Tiny persistent textures; no atlas rebuild or per-frame pixel generation.
local V=...
local M={}
local bark,leaves,attempted
function M.bind(shader)
 if not attempted then
  attempted=true
  local root=(V.path or 'mods/BATTLE_ART_VOXEL_FORK')..'/assets/legendary/'
  local ok,a,b=pcall(function()
   local x=love.graphics.newImage(root..'world-tree-bark.png')
   bark=x -- retain/release a partial allocation if the second image fails
   local y=love.graphics.newImage(root..'world-tree-leaves.png');leaves=y
   for _,img in ipairs({x,y})do img:setFilter('nearest','nearest');img:setWrap('repeat','repeat')end
   return x,y
  end)
  if ok then bark,leaves=a,b
  else
   if bark and bark.release then pcall(bark.release,bark)end
   if leaves and leaves.release then pcall(leaves.release,leaves)end
   bark,leaves=nil,nil
  end
 end
 pcall(shader.send,shader,'worldTreeTextures',bark and leaves and 1 or 0)
 -- Supply valid samplers even when native procedural materials are used.
 local a,b=bark,leaves
 if not (a and b)then a=V.require('GlassMask').blank();b=a end
 if a and b then
  pcall(shader.send,shader,'worldTreeBark',a)
  pcall(shader.send,shader,'worldTreeLeaves',b)
 end
end
return M
