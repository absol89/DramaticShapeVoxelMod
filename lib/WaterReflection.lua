-- Clip mirrored actors to the water half-space using the shared projection.
-- External model providers already consume Voxel3D.vp, so no importer shader
-- patch is needed. X/Y/W rows stay exact: only near/depth clipping changes.
local V=...;local M={}
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<1e12 end
function M.projection(vp,plane)
 if type(vp)~='table'or not finite(plane)then return nil end
 for i=1,16 do if not finite(vp[i])then return nil end end
 local inv=V.require('WaterBackdrop').inverse(vp);if not inv then return nil end
 local p={0,-1,0,plane};local clip={}
 for c=1,4 do clip[c]=p[1]*inv[c]+p[2]*inv[4+c]+p[3]*inv[8+c]+p[4]*inv[12+c] end
 local corner={clip[1]>=0 and 1 or -1,clip[2]>=0 and 1 or -1,1,1};local q={}
 for r=0,3 do q[r+1]=inv[r*4+1]*corner[1]+inv[r*4+2]*corner[2]+inv[r*4+3]+inv[r*4+4] end
 local dot=-q[2]+plane*q[4]
 if not finite(dot)or dot<=1e-8 then return nil end
 local out={};for i=1,16 do out[i]=vp[i]end
 for c=1,4 do out[8+c]=p[c]*2/dot-vp[12+c];if not finite(out[8+c])then return nil end end
 return out
end
return M
