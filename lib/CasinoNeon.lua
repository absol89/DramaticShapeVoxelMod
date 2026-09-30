-- TEST122: small physical light tubes, batched into the existing facade mesh.
-- Six sides round the silhouette; a narrow raised core reads at night.
local M={}
function M.line(G,a,b,width,material)
 local dx,dy,dz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
 local len=math.sqrt(dx*dx+dy*dy+dz*dz);if len<.001 then return end
 dx,dy,dz=dx/len,dy/len,dz/len
 local ux,uy,uz=-dy,dx,0;local ul=math.sqrt(ux*ux+uy*uy)
 if ul<.001 then ux,uy,uz,ul=1,0,0,1 end
 ux,uy,uz=ux/ul,uy/ul,uz/ul
 local vx,vy,vz=dy*uz-dz*uy,dz*ux-dx*uz,dx*uy-dy*ux
 local rings={{},{}};local r=width/2
 for k,p in ipairs({a,b})do for i=0,5 do
  local c,s=math.cos(i*math.pi/3),math.sin(i*math.pi/3)
  rings[k][i+1]={p[1]+r*(ux*c+vx*s),p[2]+r*(uy*c+vy*s),p[3]+r*(uz*c+vz*s)}
 end end
 for i=1,6 do local j=i%6+1;G.face(rings[1][i],rings[1][j],rings[2][j],rings[2][i],material,.80)end
 -- End discs also close isolated strokes and corner tube joints.
 for i=2,5 do
  G.face(rings[1][1],rings[1][i+1],rings[1][i],rings[1][i],material,.80)
  G.face(rings[2][1],rings[2][i],rings[2][i+1],rings[2][i+1],material,.80)
 end
end
function M.front(G,a,b,width,material)
 M.line(G,a,b,width,material)
 -- Flush front-facing highlight stays within the round tube's depth envelope.
 local dx,dy=b[1]-a[1],b[2]-a[2];local len=math.sqrt(dx*dx+dy*dy)
 if len<.001 then return end
 local ux,uy=-dy/len*width*.13,dx/len*width*.13
 local z=width*.45
 G.face({a[1]+ux,a[2]+uy,a[3]+z},{a[1]-ux,a[2]-uy,a[3]+z},
  {b[1]-ux,b[2]-uy,b[3]+z},{b[1]+ux,b[2]+uy,b[3]+z},material,1.65)
end
function M.frame(G,l,b,r,t,z,width,material)
 -- Soft clipped corners instead of a square neon box.
 local c=math.min(.75,(t-b)*.18,(r-l)*.08)
 local points={{l+c,b,z},{r-c,b,z},{r,b+c,z},{r,t-c,z},
  {r-c,t,z},{l+c,t,z},{l,t-c,z},{l,b+c,z}}
 for i,a in ipairs(points)do M.front(G,a,points[i%#points+1],width,material)end
end
return M
