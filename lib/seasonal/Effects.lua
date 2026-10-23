-- Shared particle topology. TEST26: the per-frame CPU rebuild that lived here
-- (24k-65k new vertex rows, 30 times a second) is replaced by Particles.lua,
-- which animates one static mesh on the GPU. Flakes and embers use a plain
-- 20-face icosahedron; at their size (0.1-0.5 units) extra rounding is
-- invisible from every Battle Art camera.
local G=...
local M={}
local phi=(1+math.sqrt(5))/2
local points={{-1,phi,0},{1,phi,0},{-1,-phi,0},{1,-phi,0},{0,-1,phi},{0,1,phi},
 {0,-1,-phi},{0,1,-phi},{phi,0,-1},{phi,0,1},{-phi,0,-1},{-phi,0,1}}
local faces={{1,12,6},{1,6,2},{1,2,8},{1,8,11},{1,11,12},{2,6,10},{6,12,5},{12,11,3},
 {11,8,7},{8,2,9},{4,10,5},{4,5,3},{4,3,7},{4,7,9},{4,9,10},{5,10,6},{3,5,12},{7,3,11},{9,7,8},{10,9,2}}
for _,p in ipairs(points)do local l=math.sqrt(p[1]^2+p[2]^2+p[3]^2);for k=1,3 do p[k]=p[k]/l end end
M.points=points;M.faces=faces
M.particleVertices=#faces*3
-- Flat two-sided card for petals and leaves (no culling in Battle Art).
M.cardPoints={{-1,0,0},{0,0,1.5},{1,0,0},{0,0,-1.1}}
M.cardFaces={{1,2,3},{1,3,4}}
-- Bat: body plus two wings; the 4th value is how far the vertex flaps.
M.batPoints={{0,0,.9,0},{0,.08,-.9,0},{-1.25,0,.15,.45},{-2.7,0,-.35,1},{1.25,0,.15,.45},{2.7,0,-.35,1},{0,.45,.55,0}}
M.batFaces={{1,3,2},{3,4,2},{1,2,5},{5,2,6},{1,7,2}}
-- GLSL-portable hash mirrored on the CPU fallback.
function M.hash(a,b,c)local x=math.sin(a*12.9898+(b or 0)*78.233+(c or 0)*37.719)*43758.5453;return x-math.floor(x)end
return M
