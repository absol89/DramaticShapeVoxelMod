-- Shared deterministic fields and clipped decorative geometry. TEST7.
local M={}
function M.hash(x,z,s)
 local a=((x%65521)*251+(z%65521)*113+((s or 0)%65521)*911)%65521
 a=(a*a*17431+a*127+(x%65521)*17)%65521
 a=(a*a*8191+a*53+(z%65521)*71)%65521
 return a/65521
end
function M.field(x,z,s)
 local a,b=math.floor(x),math.floor(z);local u,v=x-a,z-b
 u=u*u*(3-2*u);v=v*v*(3-2*v)
 local h=M.hash
 return (h(a,b,s)*(1-u)+h(a+1,b,s)*u)*(1-v)+(h(a,b+1,s)*(1-u)+h(a+1,b+1,s)*u)*v
end
local function clip(p,axis,edge,sign)
 local out={};local a=p[#p];if not a then return out end
 local da=(a[axis]-edge)*sign
 for _,b in ipairs(p)do
  local db=(b[axis]-edge)*sign
  if (da<=0)~=(db<=0)then
   local t=da/(da-db);out[#out+1]={a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t}
  end
  if db<=0 then out[#out+1]=b end;a,da=b,db
 end
 return out
end
function M.builder(x,z,emit)
 local G={}
 function G.face(p,s,t)
  p=clip(clip(clip(clip(p,1,x,-1),1,x+8,1),3,z,-1),3,z+8,1)
  for i=2,#p-1 do
   local a,b,c=p[1],p[i],p[i+1]
   local ux,uy,uz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
   local vx,vy,vz=c[1]-a[1],c[2]-a[2],c[3]-a[3]
   if (uy*vz-uz*vy)^2+(uz*vx-ux*vz)^2+(ux*vy-uy*vx)^2>1e-18 then emit({a,b,c,c},s,t or 1)end
  end
 end
 function G.flat(a,b,c,d,y,s,t)G.face({{a,y,b},{c,y,b},{c,y,d},{a,y,d}},s,t)end
 function G.box(a,b,c,d,lo,hi,s,t)
  t=t or 1
  G.flat(a,b,c,d,hi,s,t*1.08)
  G.face({{a,lo,b},{c,lo,b},{c,hi,b},{a,hi,b}},s,t*.86)
  G.face({{c,lo,d},{a,lo,d},{a,hi,d},{c,hi,d}},s,t*.92)
  G.face({{a,lo,d},{a,lo,b},{a,hi,b},{a,hi,d}},s,t*.78)
  G.face({{c,lo,b},{c,lo,d},{c,hi,d},{c,hi,b}},s,t)
 end
 function G.blade(cx,cz,y,height,width,lean,angle,s,t)
  local a,b=math.cos(angle)*width,math.sin(angle)*width
  local tip={cx+math.cos(angle+.8)*lean,y+height,cz+math.sin(angle+.8)*lean}
  local p,q={cx-a,y,cz-b},{cx+a,y,cz+b}
  G.face({p,q,tip},s,t);G.face({q,p,tip},s,t)
 end
 return G
end
return M
