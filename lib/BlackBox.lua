-- TEST217: RETIRED. BlackBox was a diagnostic panel used to find the Vermilion /
-- Route 11 crash (TEST210-216). The crash fixes it pointed to live on in
-- MemoryBudget.lua, TextureDiet.lua, DecorAtlas.lua and VoxelMeshDisk.lua.
-- This empty module stays so that anything still calling it does nothing:
-- no panel, no file writes, no wrapped functions. To bring the panel back,
-- restore the TEST216 version of this file.
local M={REVISION='blackbox-retired-217'}
function M.install()end
function M.dispose()end
function M.update()end
function M.draw()end
function M.context()return nil end
return M
