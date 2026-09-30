-- TEST86: the approved Celadon shallow cobble geometry is the generic paved-path baseline.
-- Reuse its restrained bevels and clipping; retain each map's existing stone atlas.
local V=...
local loader=V or {require=function(name)return assert(loadfile('lib/'..name..'.lua'))()end}
local P
if V then P=V.require('CeladonPaving')
else P=assert(loadfile('lib/CeladonPaving.lua'))(loader)end
local M={}
function M.build(x,z,h,edges,emit)
 P.build(x,z,h,function(q,material,tone)
  emit(q,material=='pavingBand' and 'dark' or 'body',tone)
 end,'stonePaving',edges)
end
return M
