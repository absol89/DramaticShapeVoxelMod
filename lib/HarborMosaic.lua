-- Original courtyard stonework. Clipped into the existing visible path cells.
local V=...
local C=V and V.require('SurfaceCraft') or assert(loadfile('lib/SurfaceCraft.lua'))()
local M={}
local function clip(poly,axis,edge,greater)
 local out={};local a=poly[#poly];if not a then return out end
 local ain=greater and a[axis]>=edge or not greater and a[axis]<=edge
 for _,b in ipairs(poly)do
  local bin=greater and b[axis]>=edge or not greater and b[axis]<=edge
  if ain~=bin then local t=(edge-a[axis])/(b[axis]-a[axis]);local p={}
   for k=1,3 do p[k]=a[k]+(b[k]-a[k])*t end;out[#out+1]=p
  end
  if bin then out[#out+1]=b end;a,ain=b,bin
 end
 return out
end
function M.build(x,z,h,plaza,emit)
 local G=C.builder(x,z,emit);local cx,cz,r=plaza.cx,plaza.cz,plaza.radius
 local function p(a,d,y)return {cx+math.cos(a)*d,h+y,cz+math.sin(a)*d}end
 local function circle(radius,y)
  local out={};for i=0,63 do out[#out+1]=p(i*math.pi/32,radius,y)end;return out
 end
 local function ring(inner,outer,count,mat,tone,y,gap)
  for i=0,count-1 do
   local a,b=i*math.pi*2/count,(i+1)*math.pi*2/count
   a=a+(gap or 0);b=b-(gap or 0)
   G.face({p(a,inner,y),p(a,outer,y),p(b,outer,y),p(b,inner,y)},mat,tone+(i%3)*.015)
  end
 end
 local function mosaic(poly,mat,tone)
  -- Broad staggered stone sections. Matching material under the joints keeps
  -- their contrast subtle instead of exposing the dark outline below.
  local backing={}
  for i,v in ipairs(poly)do backing[i]={v[1],v[2]-.015,v[3]}end
  G.face(backing,mat,tone*.91)
  local width,height,gap=6.8,4.8,.035
  for row=math.floor((z-cz)/height),math.floor((z+8-cz)/height)do
   local zz=cz+row*height;local origin=cx+(row%2)*width/2
   for col=math.floor((x-origin)/width),math.floor((x+8-origin)/width)do
    local xx=origin+col*width
    local q=clip(poly,1,xx+gap,true);q=clip(q,1,xx+width-gap,false)
    q=clip(q,3,zz+gap,true);q=clip(q,3,zz+height-gap,false)
    if #q>=3 then G.face(q,mat,tone*(.99+C.hash(col,row,5901)*.02))end
   end
  end
 end
 -- A slate border, radial limestone paving and a fine brick ribbon.
 G.face(circle(r+.95,.30),'sand',.83)
 ring(r+1.15,r+1.85,64,'body',1.02,.34,.003)
 ring(r+.35,r+.95,64,'cinder',1,.34,.004)
 ring(r*.76,r+.10,48,'body',1.02,.34,.006)
 local br=r*.72
 G.face(circle(br+.5,.345),'sand',.78)
 local disk=circle(br-.5,.38)
 mosaic(clip(disk,3,cz-.85,false),'cinder',1.03)
 mosaic(clip(disk,3,cz+.85,true),'body',1.20)
 -- The central button sits over the band with a dark stone surround.
 G.face(circle(br*.29,.40),'sand',.78)
 G.face(circle(br*.20,.43),'body',1.24)
 -- Four pale keystones connect the circular feature to its square terrace.
 for i=0,3 do
  local a=i*math.pi/2
  G.face({p(a-.035,r+2.2,.34),p(a,r+3.5,.34),p(a+.035,r+2.2,.34),p(a,r+1.9,.34)},'body',1.1)
 end
end
return M
