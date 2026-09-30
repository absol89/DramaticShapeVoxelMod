-- TEST23: bake a bounded light influence into existing dock vertex shades.
local M={}
function M.wrap(push,tx,tz,h,isWood,isWater)
 local lamps={}
 for z=tz-3,tz+3 do for x=tx-3,tx+3 do if isWood(x,z) then
  for _,e in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
   if isWater(x+e[1],z+e[2]) then
    local cross=e[1]~=0;local along=cross and z or x
    local ending=cross and (not isWood(x,z-1) or not isWood(x,z+1))
      or not cross and (not isWood(x-1,z) or not isWood(x+1,z))
    if ending or along%4==0 then
     lamps[#lamps+1]={x*8+4+e[1]*2.5,z*8+4+e[2]*2.5}
    end
   end
  end
 end end end
 return function(c,uv,shade)
  local out={}
  for i,v in ipairs(c)do
   local s=type(shade)=='table' and shade[i] or shade
   if s>=64 then out[i]=s else
    local light=0
    for _,p in ipairs(lamps)do
     local d=math.sqrt((v[1]-p[1])^2+(v[3]-p[2])^2)
     local f=math.max(0,1-d/18)
     light=light+f*f*math.max(0,1-math.abs(v[2]-h)/18)
    end
    local level=math.floor(math.min(1,light)*15+.5)
    out[i]=128+level*4+math.max(0,math.min(3.95,s))
   end
  end
  return push(c,uv,out)
 end
end
function M.masonry(push)
 return function(c,uv,shade)
  local out={};for i=1,4 do local s=type(shade)=='table' and shade[i] or shade;out[i]=256+math.max(0,math.min(3.95,s))end
  return push(c,uv,out)
 end
end
return M
