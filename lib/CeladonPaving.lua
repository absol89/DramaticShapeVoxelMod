-- Coplanar stone frames and charcoal keylines; no stacked faces or brick cubes.
local V=...;local C=V.require('SurfaceCraft');local Cells=V.require('CobbleCells');local M={}
function M.build(x,z,h,emit,style,edges)
 local G=C.builder(x,z,emit);style=style or 'roseBrick';edges=edges or {}
 local a,b,c,d=x,z,x+8,z+8
 local width=edges.frameWidth or (style=='stonePaving' and .55 or 1.2)
 local function frame(a,b,c,d)G.flat(a,b,c,d,h+.16,edges.frameMaterial or 'stonePaving',1.10)end
 local line=.18
 if edges.w then frame(a,b,a+width,d);a=a+width;G.flat(a,b,a+line,d,h+.16,'pavingBand',1);a=a+line end
 if edges.e then frame(c-width,b,c,d);c=c-width;G.flat(c-line,b,c,d,h+.16,'pavingBand',1);c=c-line end
 if edges.n then frame(a,b,c,b+width);b=b+width;G.flat(a,b,c,b+line,h+.16,'pavingBand',1);b=b+line end
 if edges.s then frame(a,d-width,c,d);d=d-width;G.flat(a,d-line,c,d,h+.16,'pavingBand',1);d=d-line end
 -- Material regions clip whole world-aligned pavers, retaining clean borders.
 local function clipped(q,mat,tone)
  -- SurfaceCraft clips to the terrain cell; this additional clip is to its inset.
  local function clip(p,axis,edge,sign)
   local out={};local u=p[#p];if not u then return out end
   local du=(u[axis]-edge)*sign
   for _,v in ipairs(p)do
    local dv=(v[axis]-edge)*sign
    if (du<=0)~=(dv<=0)then local t=du/(du-dv);out[#out+1]={u[1]+(v[1]-u[1])*t,u[2]+(v[2]-u[2])*t,u[3]+(v[3]-u[3])*t}end
    if dv<=0 then out[#out+1]=v end;u,du=v,dv
   end
   return out
  end
  q=clip(clip(clip(clip(q,1,a,-1),1,c,1),3,b,-1),3,d,1)
  G.face(q,mat,tone)
 end
 local function flat(x0,z0,x1,z1,y,mat,tone)clipped({{x0,y,z0},{x1,y,z0},{x1,y,z1},{x0,y,z1}},mat,tone)end
 flat(a,b,c,d,h-.025,'pavingBand',.85)
 local function paver(px,pz,w,l,seed)
  local gap=.055;local bevel=.075;local top=h+.20
  local x0,z0,x1,z1=px+gap,pz+gap,px+w-gap,pz+l-gap
  local t=.92+C.hash(px,pz,seed)*.15
  flat(x0+bevel,z0+bevel,x1-bevel,z1-bevel,top,style,t)
  local outer={{x0,h+.06,z0},{x1,h+.06,z0},{x1,h+.06,z1},{x0,h+.06,z1}}
  local inner={{x0+bevel,top,z0+bevel},{x1-bevel,top,z0+bevel},{x1-bevel,top,z1-bevel},{x0+bevel,top,z1-bevel}}
  for j=1,4 do local k=j%4+1;clipped({outer[j],outer[k],inner[k],inner[j]},style,t*(j==1 and .88 or j==2 and 1.02 or .94))end
 end
 if style=='stonePaving' then
  -- Organic cells share the old cobble outlines, with one top and a shallow
  -- bevel only. No upright stone skirts, chip overlays, or joint foliage mesh.
  for row=math.floor(z/4.3)-1,math.floor((z+8)/4.3)+1 do
   for col=math.floor(x/4.8)-2,math.floor((x+8)/4.8)+1 do
    local poly,cx,cz=Cells.territory(col,row)
    local inner,outer={},{};local t=.86+C.hash(col,row,8601)*.28
    local top=h+.18+C.hash(col,row,8602)*.02
    for i,v in ipairs(poly)do
     local dx,dz=v[1]-cx,v[2]-cz;local len=math.max(.001,math.sqrt(dx*dx+dz*dz))
     local ko=math.max(0,1-.07/len);local ki=math.max(0,1-.17/len)
     outer[i]={cx+dx*ko,h+.06,cz+dz*ko}
     inner[i]={cx+dx*ki,top,cz+dz*ki}
    end
    clipped(inner,style,t)
    for j=1,#poly do local k=j%#poly+1
     local dx,dz=poly[k][1]-poly[j][1],poly[k][2]-poly[j][2]
     local light=.91+.08*(dx-dz)/math.max(.001,math.sqrt(dx*dx+dz*dz))
     clipped({outer[j],outer[k],inner[k],inner[j]},style,t*light)
    end
   end
  end
 elseif style=='wineBrick' then
  for row=math.floor(z/2),math.floor((z+8-.001)/2)do
   local shift=(row%2)*2
   for col=math.floor((x-shift)/4),math.floor((x+8-shift-.001)/4)do paver(col*4+shift,row*2,4,2,8302)end
  end
 else
  -- Herringbone dominoes: each 2x2 grid cell belongs to one 4x2 paver.
  for v=math.floor(z/2)-1,math.floor((z+8)/2)do for u=math.floor(x/2)-1,math.floor((x+8)/2)do
   local k=(u-v)%4
   if k==0 then paver(u*2,v*2,4,2,8303)
   elseif k==2 then paver(u*2,(v-1)*2,2,4,8304)end
  end end
 end
end
return M
