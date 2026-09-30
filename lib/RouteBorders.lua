-- Conservative source-art detection for flat striped route edging.
-- Uses the original atlas and resolved shapes, never changes gameplay tiles.
local M={}
M.maps={ROUTE_11=true,ROUTE_17=true,PALLET_TOWN=true,VIRIDIAN_CITY=true,PEWTER_CITY=true,CERULEAN_CITY=true,FUCHSIA_CITY=true,SAFFRON_CITY=true}
function M.striped(data,tile,perRow)
 if not data or not data.getPixel then return false end
 local ox,oy=tile%perRow*8,math.floor(tile/perRow)*8
 local w,h=data:getDimensions();if ox+8>w or oy+8>h then return false end
 local p={};local light,dark=0,0
 for y=0,7 do p[y]={};for x=0,7 do
  local r,g,b,a=data:getPixel(ox+x,oy+y)
  if a and a<.9 then return false end
  if math.max(r,g,b)-math.min(r,g,b)>.12 then return false end
  local v=(r+g+b)/3;p[y][x]=v
  if v>.70 then light=light+1 end;if v<.30 then dark=dark+1 end
 end end
 if light<8 or dark<8 then return false end
 -- Both horizontal and vertical runs; dotted ground fails the line test.
 for axis=1,2 do
  local lines=0;local low,high=1,0
  for a=0,7 do local lo,hi,sum=1,0,0
   for b=0,7 do local v=axis==1 and p[a][b] or p[b][a];lo=math.min(lo,v);hi=math.max(hi,v);sum=sum+v end
   if hi-lo<.12 then lines=lines+1;low=math.min(low,sum/8);high=math.max(high,sum/8)end
  end
  if lines>=6 and high-low>.45 then return true end
 end
 return false
end
function M.detect(S,map,data,perRow)
 local out,checked={},{}
 if not M.maps[map.id] then return out end
 for k,s in pairs(S.shapeAt)do
  if s.class=='ground' and s.flat and not S.skip[k] then
   local tile=S.tileAt[k]
   if type(tile)=='number' and checked[tile]==nil then checked[tile]=M.striped(data,tile,perRow)end
   if checked[tile] then
    for _,d in ipairs({-1,1,-4096,4096})do
     local n=S.shapeAt[k+d];local t=S.tileAt[k+d]
     if n and n.class=='ground' and (t==35 or t==57 or (map.id~='ROUTE_11' and t~=44 and t~=48 and t~=60)) then out[tile]=true;break end
    end
   end
  end
 end
 return out
end
return M
