-- Static architecture primitives. Walls are cut around apertures; details are
-- separated in depth. All source portals and gameplay records remain read-only.
local V=...;local M={};local abs,min,max=math.abs,math.min,math.max
function M.new(s)
 local G=V.require('CityMesh').new(s.uv);local K={G=G,s=s}
 K.box=G.box;K.face=G.face;K.beam=G.beam
 function K.elevation(side,lo,hi,plane,H,profile)
  local E={side=side,lo=lo,hi=hi,H=H,openings={}}
  local ax=(side=='front'or side=='back')and 3 or 1;local sign=(side=='front'or side=='east')and 1 or -1
  E.ax=ax
  function E.p(u,y,n)return ax==3 and {u,y,plane+sign*(n or 0)}or{plane+sign*(n or 0),y,u}end
  function E.poly(points,n,mat,tone,glow)
   for i=2,#points-1 do
    local a,b,c=points[1],points[i],points[i+1]
    if abs((b[1]-a[1])*(c[2]-a[2])-(b[2]-a[2])*(c[1]-a[1]))>.00001 then
     local aa,bb,cc=E.p(a[1],a[2],n),E.p(b[1],b[2],n),E.p(c[1],c[2],n)
     if(ax==1 and sign==1)or(ax==3 and sign==-1)then aa,cc=cc,aa end
     G.face(aa,bb,cc,cc,mat,tone,glow)
    end
   end
  end
  function E.panel(l,b,r,t,n,mat,tone,glow)
   if r-l<.0001 or t-b<.0001 then return end
   local a,c,d,e=E.p(l,b,n),E.p(r,b,n),E.p(r,t,n),E.p(l,t,n)
   if(ax==1 and sign==1)or(ax==3 and sign==-1)then a,c,d,e=e,d,c,a end
   G.face(a,c,d,e,mat,tone,glow)
  end
  function E.box(l,b,r,t,n0,n1,mat,tone)
   if ax==3 then G.box(l,b,plane+min(sign*n0,sign*n1),r,t,plane+max(sign*n0,sign*n1),mat,tone)
   else G.box(plane+min(sign*n0,sign*n1),b,l,plane+max(sign*n0,sign*n1),t,r,mat,tone)end
  end
  function E.beam(u,y,v,z,n,w,mat,tone)G.beam(E.p(u,y,n),E.p(v,z,n),w,mat,tone)end
  function E.open(u,w,b,t,shape,door)
   local o={u=u,w=w,b=b,t=t,door=door,points={}}
   local rise=shape=='round'and min(w*.45,5.8)or shape=='segment'and 2.8 or 0
   o.spring=t-rise
   local n=rise>0 and 10 or 1
   for i=0,n do local f=i/n;local v=2*f-1
    o.points[#o.points+1]={u-w/2+w*f,t-rise+rise*math.sqrt(max(0,1-v*v))}
   end
   E.openings[#E.openings+1]=o;return o
  end
  local function top(o,u)
   for i=1,#o.points-1 do local a,b=o.points[i],o.points[i+1]
    if u<=b[1]+.0001 then return a[2]+(b[2]-a[2])*(u-a[1])/(b[1]-a[1])end
   end;return o.t
  end
  function E.walls(wall,base)
   local cuts={lo,hi};for _,o in ipairs(E.openings)do for _,p in ipairs(o.points)do cuts[#cuts+1]=p[1]end end
   if profile then for _,p in ipairs(profile)do cuts[#cuts+1]=lo+(hi-lo)*p[1]end end
   table.sort(cuts);table.sort(E.openings,function(a,b)return a.b<b.b end)
   local function ceiling(u)
    if not profile then return H end
    local t=(u-lo)/(hi-lo)
    for i=1,#profile-1 do local a,b=profile[i],profile[i+1];if t<=b[1]+.00001 then return H+a[2]+(b[2]-a[2])*(t-a[1])/(b[1]-a[1])end end
    return H
   end
   local function fill(a,c,b,d,e,f)
    for _,band in ipairs({{0,5.8,base},{5.8,H+50,wall}})do
     local bb,dd,ee,ff=max(b,band[1]),max(d,band[1]),min(e,band[2]),min(f,band[2])
     if ee>=bb and ff>=dd then E.poly({{a,bb},{c,dd},{c,ff},{a,ee}},0,band[3],.98)end
    end
   end
   for i=1,#cuts-1 do local a,c=cuts[i],cuts[i+1];local mid=(a+c)/2
    if c-a>.00001 then
     local b,d=0,0
     for _,o in ipairs(E.openings)do if mid>o.u-o.w/2 and mid<o.u+o.w/2 then fill(a,c,b,d,o.b,o.b);b,d=top(o,a),top(o,c)end end
     fill(a,c,b,d,ceiling(a),ceiling(c))
    end
   end
  end
  function E.frame(o,mat,width)
   local l,r,b=o.u-o.w/2,o.u+o.w/2,o.b;local w=width or .65
   E.box(l-w,b,l+.22,o.spring,-.8,.54,mat,1.1)
   E.box(r-.22,b,r+w,o.spring,-.8,.54,mat,1.1)
   for i=1,#o.points-1 do local a,c=o.points[i],o.points[i+1]
    G.face(E.p(a[1],a[2],-.8),E.p(c[1],c[2],-.8),E.p(c[1],c[2],.52),E.p(a[1],a[2],.52),mat,.85)
    E.beam(a[1],a[2]+.10,c[1],c[2]+.10,.44,w,mat,1.09)
   end
   if not o.door then E.box(l-.6,b-.5,r+.6,b+.13,-.75,.80,mat,1.12)end
  end
  function E.pane(o,mat,glow,n)
   for i=1,#o.points-1 do local a,b=o.points[i],o.points[i+1]
    E.poly({{a[1],o.b+.08},{b[1],o.b+.08},{b[1],b[2]},{a[1],a[2]}},n or -.86,mat,.94,glow)
   end
  end
  function E.lantern(u,y,mat,modern)
   local deep=side=='front'and 1.65 or .81
   E.box(u-.6,y-.35,u+.6,y+4.5,.1,deep,'dark',.86)
   E.panel(u-.40,y+.1,u+.40,y+4.1,deep+.03,'glass',.92,true)
   E.box(u-.72,y+4.5,u+.72,y+4.85,.05,deep+.05,mat,1)
   if not modern then E.beam(u-.45,y+2,u+.45,y+2,deep+.08,.12,mat,1)end
  end
  return E
 end
 function K.ring(x,y,z,r,w,mat,plane,n)
  n=n or 24;local function pt(a)
   if plane=='xz'then return{x+math.cos(a)*r,y,z+math.sin(a)*r}end
   if plane=='yz'then return{x,y+math.sin(a)*r,z+math.cos(a)*r}end
   return{x+math.cos(a)*r,y+math.sin(a)*r,z}
  end
  for i=0,n-1 do G.beam(pt(i*2*math.pi/n),pt((i+1)*2*math.pi/n),w,mat,1)end
 end
 function K.leaf(a,b,w,mat)
  -- Front-facing folded leaves: four disjoint triangles meet at the raised rib.
  local dx,dy,dz=b[1]-a[1],b[2]-a[2],b[3]-a[3];local len=math.sqrt(dx*dx+dy*dy);if len<.01 then len=1 end
  local l={a[1]+dx*.5-dy/len*w,a[2]+dy*.5+dx/len*w,a[3]+dz*.5}
  local r={a[1]+dx*.5+dy/len*w,a[2]+dy*.5-dx/len*w,a[3]+dz*.5}
  local c={a[1]+dx*.5,a[2]+dy*.5,a[3]+dz*.5+.28}
  G.face(a,l,c,c,mat,.9);G.face(l,b,c,c,mat,.9)
  G.face(a,c,r,r,mat,1.08);G.face(r,c,b,b,mat,1.08)
 end
 function K.roof(poly,mat,tiled,glow)
  local function clip(ps,axis,val,above)
   local out={};for i,a in ipairs(ps)do local b=ps[i%#ps+1]
    local ina=above and a[axis]>=val or not above and a[axis]<=val
    local inb=above and b[axis]>=val or not above and b[axis]<=val
    if ina then out[#out+1]=a end
    if ina~=inb then local t=(val-a[axis])/(b[axis]-a[axis]);out[#out+1]={a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t}end
   end;return out
  end
  local function polygon(ps,lift,tone)
   for i=2,#ps-1 do local a,b,c=ps[1],ps[i],ps[i+1]
    if abs((b[1]-a[1])*(c[3]-a[3])-(b[3]-a[3])*(c[1]-a[1]))>.000001 then
     local aa,bb,cc={a[1],a[2]+lift,a[3]},{b[1],b[2]+lift,b[3]},{c[1],c[2]+lift,c[3]}
     G.face(aa,bb,cc,cc,mat,tone,glow)
    end
   end
  end
  polygon(poly,0,tiled and .77 or 1)
  if not tiled then return end
  local minx,maxx,minz,maxz=1e9,-1e9,1e9,-1e9
  for _,p in ipairs(poly)do minx=min(minx,p[1]);maxx=max(maxx,p[1]);minz=min(minz,p[3]);maxz=max(maxz,p[3])end
  for x=minx,maxx-.001,4.2 do local row=math.floor((x-minx)/4.2);local offset=row%2*3
   for z=minz-offset,maxz-.001,6 do
    local ps=clip(poly,1,x,true);ps=clip(ps,1,min(x+4.09,maxx),false);ps=clip(ps,3,max(z,minz),true);ps=clip(ps,3,min(z+5.88,maxz),false)
    if #ps>=3 then
     polygon(ps,.17,.96+(row+math.floor(z/6))%5*.015)
     local bottom=1e9;for _,p in ipairs(ps)do bottom=min(bottom,p[2])end
     for i,a in ipairs(ps)do local b=ps[i%#ps+1]
      if abs(a[2]-bottom)<.0001 and abs(b[2]-bottom)<.0001 and abs(a[1]-b[1])+abs(a[3]-b[3])>.001 then
       G.face({a[1],a[2]+.02,a[3]},{b[1],b[2]+.02,b[3]},{b[1],b[2]+.17,b[3]},{a[1],a[2]+.17,a[3]},mat,.80)
      end
     end
    end
   end
  end
 end
 function K.profileRoof(profile,H,mat,tile,over)
  over=over or .7;local x0,x1,z0,z1=s.x0-over,s.x1+over,s.z0-over,s.z1+over
  for i=1,#profile-1 do local a,b=profile[i],profile[i+1]
   local xa,xb=x0+(x1-x0)*a[1],x0+(x1-x0)*b[1]
   K.roof({{xa,H+a[2],z0},{xb,H+b[2],z0},{xb,H+b[2],z1},{xa,H+a[2],z1}},mat,tile)
  end
 end
 function K.hip(H,rise,mat,tile)
  local a,b,c,d=s.x0-.7,s.x1+.7,s.z0-.7,s.z1+.7;local cx=(a+b)/2;local inset=(d-c)*.26
  for _,x in ipairs({a,b})do K.roof({{x,H,c},{x,H,d},{cx,H+rise,d-inset},{cx,H+rise,c+inset}},mat,tile)end
  K.roof({{a,H,c},{b,H,c},{cx,H+rise,c+inset}},mat,tile)
  K.roof({{b,H,d},{a,H,d},{cx,H+rise,d-inset}},mat,tile)
  G.beam({cx,H+rise+.25,c+inset},{cx,H+rise+.25,d-inset},.6,mat,1.1)
 end
 return K
end
return M
