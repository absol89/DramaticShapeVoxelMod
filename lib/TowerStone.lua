-- Shared Tower wall/ceiling finish. Scope the tint to registered wall-atlas
-- texels during one draw; characters, graves, floors and other maps keep theirs.
-- TEST13: a visible amethyst palette, rather than an almost-neutral grey tint.
local M={tint={.86,.53,1.00},honed={.30,.16,.46}}
local vaultQuiet=0
local atlases=setmetatable({},{__mode='k'})
function M.register(image,sourceWidth,atlasWidth,atlasHeight)
 if atlases[image]then return end
 atlases[image]={sourceWidth/atlasWidth,0,(sourceWidth+2048)/atlasWidth,2048/atlasHeight}
end
function M.inherit(source,image)
 if image and image~=source and atlases[source]then atlases[image]=atlases[source]end
end
function M.clear(shader)
 pcall(shader.send,shader,'towerStoneOn',0)
 pcall(shader.send,shader,'towerStoneQuiet',0)
end
function M.apply(shader,image)
 local region=image and atlases[image]
 if not region then return false end
 local a=pcall(shader.send,shader,'towerStoneRegion',region)
 local b=pcall(shader.send,shader,'towerStoneTint',M.tint)
 local c=pcall(shader.send,shader,'towerStoneQuiet',vaultQuiet)
 local d=pcall(shader.send,shader,'towerStoneHoned',M.honed)
 if not(a and b and c and d)then M.clear(shader);return false end
 local ok=pcall(shader.send,shader,'towerStoneOn',1)
 if not ok then M.clear(shader)end
 return ok
end
-- Quiet finish is scoped to ceiling draws only, including error paths.
-- Use the live wall image: switching any of the three stones stays coherent.
function M.drawVault(renderer,mesh,image,quiet)
 local previous=vaultQuiet
 vaultQuiet=quiet
 local ok,err=pcall(renderer.draw,mesh,image)
 vaultQuiet=previous
 if not ok then error(err)end
end
return M
