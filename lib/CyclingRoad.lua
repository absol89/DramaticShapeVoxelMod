-- Route 17's riding surface. Existing water, signs, ledges and collision remain.
local V=...;local C=V.require('SurfaceCraft');local M={}
function M.build(x,z,h,plan,emit)
 local G=C.builder(x,z,emit);local tx,tz=math.floor(x/8),math.floor(z/8)
 local left,right=tx,tx
 local span=plan.roadSpan or plan.isPath
 for i=1,48 do if span(tx-i,tz)then left=tx-i else break end end
 for i=1,48 do if span(tx+i,tz)then right=tx+i else break end end
 local lo,hi=left*8,(right+1)*8;local width=hi-lo
 G.flat(x,z,x+8,z+8,h+.12,'stonePaving',.96)
 -- Hatching outlines the exact occupied original sign cell. The surrounding
 -- authored riding cells retain their unobstructed asphalt and lane markings.
 for _,island in ipairs(plan.signIslands or {})do
  if island.x+16>=x and island.x<=x+8 and island.z+16>=z and island.z<=z+8 then
   local a,b=island.x,island.z
   G.flat(a,b,a+16,b+16,h+.16,'pavingBand',.8)
   for _,u in ipairs({a+.5,a+15.2})do G.flat(u,b+.5,u+.3,b+15.5,h+.17,'cityBorder',1)end
   for _,v in ipairs({b+.5,b+15.2})do G.flat(a+.5,v,a+15.5,v+.3,h+.17,'cityBorder',1)end
   for i=0,3 do
    local c=b+2+i*3
    G.face({{a+2,h+.17,c},{a+5.7,h+.17,c+1.8},{a+5.7,h+.17,c+2.25},{a+2,h+.17,c+.45}},'cityBorder',.94)
   end
  end
 end
 -- Continuous edge paint; aggregate grain comes from the existing atlas panel.
 for _,u in ipairs({lo+1.1,hi-1.4})do G.flat(u,z,u+.3,z+8,h+.14,'cityBorder',1.04)end
 if width>=24 then
  local middle=(lo+hi)/2
  local dash=math.floor(z/24)*24
  for p=dash,dash+24,24 do G.flat(middle-.12,p+4,middle+.12,p+15,h+.145,'cityBorder',.92)end
 end
 -- Bicycle pavement emblem every 128 world units on sufficiently wide lanes.
 if width>=24 then
  local cx=(lo+hi)/2;local cz=math.floor((z+16)/128)*128+32
  if cz+5>=z and cz-5<=z+8 then
   for _,wheel in ipairs({-4,4})do for j=0,11 do
    local a,b=j*math.pi/6,(j+1)*math.pi/6
    G.face({{cx+wheel+math.cos(a)*1.65,h+.15,cz+math.sin(a)*1.65},{cx+wheel+math.cos(b)*1.65,h+.15,cz+math.sin(b)*1.65},{cx+wheel+math.cos(b)*1.32,h+.15,cz+math.sin(b)*1.32},{cx+wheel+math.cos(a)*1.32,h+.15,cz+math.sin(a)*1.32}},'cityBorder',.9)
   end end
   local function line(ax,az,bx,bz)
    local dx,dz=bx-ax,bz-az;local l=math.sqrt(dx*dx+dz*dz);local u,v=-dz/l*.16,dx/l*.16
    G.face({{cx+ax+u,h+.15,cz+az+v},{cx+bx+u,h+.15,cz+bz+v},{cx+bx-u,h+.15,cz+bz-v},{cx+ax-u,h+.15,cz+az-v}},'cityBorder',.9)
   end
   line(-4,0,-1,-2.8);line(-1,-2.8,0,0);line(0,0,-4,0);line(0,0,2.3,-2.8);line(2.3,-2.8,-1,-2.8);line(2.3,-2.8,4,0);line(2.3,-2.8,2,-4);line(2,-4,3.4,-4)
  end
 end
end
function M.keepWaterPlants(x,z)
 return C.field((x+4)/56,(z+4)/72,8817)>.65
end
return M
