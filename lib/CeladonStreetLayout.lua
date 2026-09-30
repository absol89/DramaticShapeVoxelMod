-- Material zones follow actual building, water and doorway locations.
local M={}
function M.new(map,S,key)
 local cache={};local dirs={{'w',-1,0},{'e',1,0},{'n',0,-1},{'s',0,1}}
 local function style(x,z)
  local k=key(x,z);if cache[k] then return cache[k]end
  local result='roseBrick';local frontage=false;local water=false
  for dz=-2,2 do for dx=-2,2 do
   local s=S.shapeAt[key(x+dx,z+dz)]
   if s then
    if s.class=='water' then water=true end
    if s.class=='building' and math.abs(dx)+math.abs(dz)<=2 then frontage=true end
   end
  end end
  for _,w in ipairs(map.def.warps or {})do
   if (w.destMap=='GAME_CORNER' or w.destMap=='GAME_CORNER_PRIZE_ROOM') and math.abs(x-(w.x*2+1))<12 and math.abs(z-(w.y*2+1))<5 then result='wineBrick'end
  end
  if water or frontage then result='stonePaving'end
  cache[k]=result;return result
 end
 local function cell(x,z)
  local s=style(x,z);local edges={}
  if s~='stonePaving' then
   for _,d in ipairs(dirs)do
    local near=S.shapeAt[key(x+d[2],z+d[3])]
    if style(x+d[2],z+d[3])=='stonePaving' or (near and (near.art=='grass' or near.class=='water'))then edges[d[1]]=true end
   end
  end
  return s,edges
 end
 return {cell=cell}
end
return M
