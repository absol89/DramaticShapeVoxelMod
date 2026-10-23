-- TEST18: local building vocabulary. Deliberately separate from the approved
-- gym kit: regional houses can evolve without altering any gym geometry.
local V=...;local M={};local min,max,abs=math.min,math.max,math.abs
function M.new(s,c)
 local K=V.require('KantoArchitectureKit').new(s);local G=K.G
 local R={K=K,G=G,volumes={}};local family=c.name
 function R.split(preferred)
  local W=s.x1-s.x0
  for _,f in ipairs({preferred,.64,.36,.72,.28,.56,.44})do
   local x=s.x0+W*f;local safe=x-s.x0>=18 and s.x1-x>=18
   for _,d in ipairs(s.doors or{})do if(d.side or'front')=='front'or d.side=='back'then
    if abs(x-(d.u or d.x))<(d.w or 14)/2+3 then safe=false end
   end end
   if safe then return x end
  end
 end
 local function clear(E,l,r,b,t,margin)
  for _,o in ipairs(E.openings)do
   if r>o.u-o.w/2-(margin or 0)and l<o.u+o.w/2+(margin or 0)and t>o.b and b<o.t then return false end
  end;return true
 end
 -- Cut decorative courses at apertures instead of laying boards over glass.
 local function course(E,y,thick,mat,n)
  local spans={{E.lo+.85,E.hi-.85}}
  for _,o in ipairs(E.openings)do if y+thick>o.b-.6 and y<o.t+.7 then
   local out={};local l,r=o.u-o.w/2-.85,o.u+o.w/2+.85
   for _,a in ipairs(spans)do
    if a[1]<l then out[#out+1]={a[1],min(a[2],l)}end
    if a[2]>r then out[#out+1]={max(a[1],r),a[2]}end
   end;spans=out
  end end
  for _,a in ipairs(spans)do if a[2]-a[1]>.2 then E.box(a[1],y,a[2],y+thick,.04,n,mat,1.05)end end
 end
 local function decorate(E,v)
  local lo,hi,H=E.lo,E.hi,E.H;local trim=v.trim or c.trim
  local wood=family=='woodland'or family=='reserve'
  for _,o in ipairs(E.openings)do
   local u,w,b,t=o.u,o.w,o.b,o.t;local l,r=u-w/2,u+w/2
   E.frame(o,trim,family=='quarry'and 1.05 or .54)
   if o.door then
    -- Door leaves are recessed. Source warp coordinates and collision remain
    -- untouched, including doors on rear/side elevations and merged portals.
    E.pane(o,(c.clinic or c.shop or c.lab)and 'glass'or 'ktCedar',c.clinic or c.shop or c.lab,-.88)
    E.box(l+.3,.2,r-.3,3.8,-.82,-.56,trim,1)
    if not(c.clinic or c.shop or c.lab)then
     E.panel(l+1.2,13.2,r-1.2,23.4,-.53,'glass',.84,true)
     if family=='reserve'then
      for x=l+2.5,r-1.5,2.6 do E.box(x-.1,13.3,x+.1,23.4,-.48,-.15,trim,.9)end
      E.box(l+1.1,18.5,r-1.1,18.75,-.48,-.12,trim,1)
     else E.box(u-.16,13.2,u+.16,23.4,-.5,-.10,trim,1)end
     E.box(l+1.1,5,r-1.1,5.5,-.5,-.1,trim,1.15)
     E.box(l+1.1,11.5,r-1.1,12,-.5,-.1,trim,1.15)
    else
     E.box(u-.18,0,u+.18,26,-.65,.20,trim,1)
     E.box(l+.2,7.8,r-.2,8.2,-.5,.13,trim,1)
    end
    E.box(r-2.3,10,r-1.9,13,-.1,.49,'ktBronze',1.05)
    E.box(l+.15,0,r-.15,.28,-.8,.65,v.base or c.base,1)
    local canopy=family=='reserve'and 'lvSlate'or family=='woodland'and 'green'or c.clinic and 'red'or c.shop and 'navy'or trim
    E.box(l-.8,28.0,r+.8,28.55,.08,E.side=='front'and 2.25 or .84,canopy,1.1)
    if E.side=='front'then
     E.box(l-.8,28.55,r+.8,28.83,.08,2.35,trim,1.04)
     for _,x in ipairs({l-1.9,r+1.9})do if x>lo+1 and x<hi-1 then E.lantern(x,17,trim,family=='metropolitan')end end
    end
   else
    local shop=c.kind=='mart'and E.side=='front'
    E.pane(o,shop and'ktGlass'or'glass',true)
    if shop then
     for _,y in ipairs({b+3.2,b+8.4})do if y+2.8<t then
      E.box(l+.6,y,r-.6,y+.28,-.55,-.06,'ktCedar',1)
      for x=l+1.7,r-1.1,3.3 do
       local k=math.floor(x+y)%3;local mat=k==0 and'red'or k==1 and'ktMarine'or'green'
       E.box(x-.64,y+.29,x+.64,y+2.35,-.47,-.13,mat,1.1)
       E.box(x-.45,y+1.0,x+.45,y+1.50,-.12,-.06,'extrim',1)
      end
     end end
    end
    if family=='reserve'then
     for x=l+2.4,r-.5,2.8 do E.box(x-.09,b,x+.09,t,-.66,.18,trim,1)end
     for y=b+3,t-.5,3 do E.box(l+.15,y,r-.15,y+.16,-.64,.22,trim,1)end
     E.box(l-.6,t+.7,r+.6,t+1.18,.07,.83,'lvSlate',.93)
    elseif family=='metropolitan'or family=='volcanic'then
     local n=max(2,math.floor(w/5))
     for i=1,n-1 do local x=l+w*i/n;E.box(x-.11,b,x+.11,t,-.70,.20,trim,1)end
     E.box(l+.2,b+1.7,r-.2,b+1.95,-.67,.23,trim,.9)
    elseif family=='waterfront'then
     for _,f in ipairs({-.25,.25})do E.box(u+w*f-.12,b,u+w*f+.12,t,-.68,.19,trim,.94)end
     E.box(l-.6,t+.65,r+.6,t+1.15,.07,.82,trim,1.13)
    else
     E.box(u-.14,b,u+.14,t,-.70,.20,trim,1)
     E.box(l+.2,b+(t-b)*.5,r-.2,b+(t-b)*.5+.24,-.66,.25,trim,1)
    end
    if family=='village'or family=='woodland'or(family=='volcanic'and not c.lab)then
     local mat=family=='village'and(c.shutters or 'sage')or family=='woodland'and 'ktCedar'or 'ktSteel'
     for _,x in ipairs({l-2.4,r+.7})do if x>lo+.6 and x+1.6<hi-.6 then
      E.box(x,b,x+1.55,t,.07,.30,mat,.85)
      for y=b+.5,t-.3,1.7 do E.box(x+.1,y,x+1.45,y+.22,.32,.58,mat,1.15)end
     end end
    end
    if family=='quarry'then
     E.box(l-1.25,t+.65,r+1.25,t+2.15,.05,.87,'ktBasalt',1.10)
     for _,x in ipairs({l-.75,r+.75})do E.box(x-.25,b-1,x+.25,b-.25,.06,.75,'ktBasalt',.95)end
    elseif family=='garden'and E.side=='front'and not c.shop and b<24 then
     E.box(l+.4,b-2.1,r-.4,b-.85,.14,1.35,'ktBrick',.95)
     -- Three different leaf pairs on a stem; one small existing sill box.
     for j=0,2 do local x=l+1.8+(r-l-3.6)*j/2;local h=1.5+(j%2)*.65
      E.beam(x,b-.8,x+.4,b+h,1.02,.10,'wood',1)
      for k=0,2 do local yy=b-.3+k*h*.28;local sg=(j+k)%2==0 and 1 or-1
       local aa=E.p(x+.12,yy,1.07);local tip=E.p(x+sg*(.8+k*.12),yy+.5,1.28)
       K.leaf(aa,tip,.27,k%2==0 and'leaf'or'green')
      end
     end

    end
   end
  end
  if family=='village'then
   for y=7,H-2,2.3 do course(E,y,.16,v.wall or c.wall,.23)end
  elseif family=='woodland'then
   for y=7,H-2,3.1 do course(E,y,.24,'ktCedar',.29)end
  elseif family=='quarry'then
   -- Continuous bonded ashlar now lives in the material. The old partial
   -- strips stopped beside apertures and read as disconnected pencil marks.
   course(E,6.2,.36,'ktBasalt',.38)
  elseif family=='volcanic'then
   for x=lo+2,hi-1,4.2 do if clear(E,x-.08,x+.08,6,H-1,.7)then E.box(x-.08,6,x+.08,H-1,.05,.20,'ktSteel',.91)end end
  end
  if wood then
   for x=lo+1.1,hi-.7,11.5 do if clear(E,x-.6,x+.6,5.8,H-.7,.7)then
    E.box(x-.50,5.8,x+.50,H-.7,.08,.75,trim,1.04)
    if H>=34 then E.beam(x,H-4.5,min(hi-.8,x+3.2),H-.7,.54,.45,trim,1)end
   end end
   E.box(lo+.5,H-1.6,hi-.5,H-.55,.04,.75,trim,1)
  end
  for _,x in ipairs({lo+.55,hi-.55})do
   if clear(E,x-.44,x+.44,5.8,H-.1,.4)then E.box(x-.44,5.8,x+.44,H-.1,.04,.60,trim,.96)end
  end
  if family=='garden'then
   for y=28,H-2,23 do E.box(lo+.15,y,hi-.15,y+.7,.06,.75,'ktLime',1.1)end
  elseif family=='metropolitan'then
   E.box(lo+.2,H-1,hi-.2,H-.3,.05,.80,'ktSteel',1.08)
  end
 end
 function R.volume(v)
  local vs={x0=v.x0 or s.x0,x1=v.x1 or s.x1,z0=v.z0 or s.z0,z1=v.z1 or s.z1,uv=s.uv}
  local T=V.require('KantoArchitectureKit').new(vs);local H=v.h
  local profile=v.profile;v.bounds=vs;v.elevations={}
  for _,a in ipairs({{'front',vs.x0,vs.x1,vs.z1},{'back',vs.x0,vs.x1,vs.z0},{'west',vs.z0,vs.z1,vs.x0},{'east',vs.z0,vs.z1,vs.x1}})do
   local side,lo,hi,plane=a[1],a[2],a[3],a[4]
   local orig=side=='front'and s.z1 or side=='back'and s.z0 or side=='west'and s.x0 or s.x1
   local exterior=abs(plane-orig)<.001
   local wallHeight=H
   if profile and side=='west'then wallHeight=H+profile[1][2]
   elseif profile and side=='east'then wallHeight=H+profile[#profile][2]end
   local E=T.elevation(side,lo,hi,plane,wallHeight,(side=='front'or side=='back')and profile or nil);v.elevations[side]=E
   if side=='front'and #(s.doors or{})==0 then
    -- Several scenery rows touch back-to-front. Keep attached window boxes
    -- inside the available margin instead of intruding into the next house.
    local point,block=E.p,E.box
    E.p=function(u,y,n)return point(u,y,n and(n>0 and n*.42 or n)or 0)end
    E.box=function(l,b,r,t,n0,n1,mat,tone)
     return block(l,b,r,t,n0>0 and n0*.42 or n0,n1>0 and n1*.42 or n1,mat,tone)
    end
   end
   if exterior then
    for _,d in ipairs(s.doors or{})do if(d.side or'front')==side then
     local u,w=d.u or d.x,d.w or 14
     if u-w/2>=lo and u+w/2<=hi then E.open(u,w,0,26,'rect',true)end
    end end
    local levels=v.levels or(H>44 and {{9,21},{34,H-7}}or{{10,22}})
    for _,level in ipairs(levels)do
     local spans={{lo+3.5,hi-3.5}}
     for _,o in ipairs(E.openings)do if o.door and level[1]<27 then
      local out={};local l,r=o.u-o.w/2-3.6,o.u+o.w/2+3.6
      for _,a in ipairs(spans)do if a[1]<l then out[#out+1]={a[1],min(a[2],l)}end;if a[2]>r then out[#out+1]={max(a[1],r),a[2]}end end
      spans=out
     end end
     for _,a in ipairs(spans)do local width=a[2]-a[1]
      if width>=7 then
       local nominal=v.window or((family=='metropolitan'or c.shop or c.lab)and 25 or family=='reserve'and 18 or 15)
       local n=max(1,math.floor((width+3)/(nominal+4)))
       for i=1,n do local u=a[1]+width*(i-.5)/n;local w=min(nominal,width/n-2)
        E.open(u,w,level[1],min(level[2],H-3),'rect')
       end
      end
     end
    end
   end
   if not exterior and v.windowAbove and v.windowAbove<H-6 then
    local w=min(22,hi-lo-9);local o=E.open((lo+hi)/2,w,v.windowAbove,H-4,'rect')
    E.frame(o,v.trim or c.trim,.55);E.pane(o,'glass',true)
    E.box(o.u-.14,o.b,o.u+.14,o.t,-.7,.2,v.trim or c.trim,1)
   end
   E.walls(v.wall or c.wall,v.base or c.base)
   if exterior then decorate(E,v)end
   if profile and (side=='front'or side=='back')then
    for i=1,#profile-1 do local a,b=profile[i],profile[i+1]
     E.beam(lo+(hi-lo)*a[1],H+a[2]-.35,lo+(hi-lo)*b[1],H+b[2]-.35,.40,.50,v.trim or c.trim,1.06)
    end
    if (family=='woodland'or family=='reserve')and #profile>2 and profile[2][2]>profile[1][2]then
     local u=(lo+hi)/2;local peak=0;for _,p in ipairs(profile)do peak=max(peak,p[2])end
     E.box(u-.32,H-.3,u+.32,H+peak-.6,.04,.44,v.trim or c.trim,1)
     for _,sg in ipairs({-1,1})do E.beam(u,H+.6,u+sg*(hi-lo)*.27,H+peak*.42,.35,.5,v.trim or c.trim,1)end
    end
   end
  end
  -- Extrapolate slopes over the eaves, rather than stretching the roof away
  -- from its wall profile (which leaves triangular cracks at gable ends).
  if profile then
   local W=vs.x1-vs.x0;local over=.70
   for i=1,#profile-1 do local a,b=profile[i],profile[i+1]
    if b[1]>a[1]then
    local xa,xb=vs.x0+W*a[1],vs.x0+W*b[1];local ya,yb=H+a[2],H+b[2];local slope=(yb-ya)/(xb-xa)
    if i==1 then xa=xa-over;ya=ya-slope*over end
    if i==#profile-1 then xb=xb+over;yb=yb+slope*over end
    local glazed=v.roofGlazing and v.roofGlazing[i]
    T.roof({{xa,ya+.08,vs.z0-over},{xb,yb+.08,vs.z0-over},{xb,yb+.08,vs.z1+over},{xa,ya+.08,vs.z1+over}},glazed and 'ktGlass'or(v.roof or c.roof),not glazed and v.tile~=false)
    end
   end
  elseif v.hip then T.hip(H,v.hip,v.roof or c.roof,true)
  else
   T.box(vs.x0-.30,H-.35,vs.z0-.30,vs.x1+.30,H+.25,vs.z1+.30,v.roof or c.roof,1)
   local height=v.parapet or 2.6
   for _,x in ipairs({vs.x0,vs.x1-.7})do T.box(x,H+.25,vs.z0,x+.7,H+height,vs.z1,v.trim or c.trim,1)end
   for _,z in ipairs({vs.z0,vs.z1-.7})do T.box(vs.x0,H+.25,z,vs.x1,H+height,z+.7,v.trim or c.trim,1)end
  end
  for _,q in ipairs(T.G.out)do G.out[#G.out+1]=q end
  R.volumes[#R.volumes+1]=v;return v
 end
 function R.chimney(v,mat)
  local a=v.bounds;local x=a.x0+(a.x1-a.x0)*.70;local z=a.z0+(a.z1-a.z0)*.32
  local h=v.h;for _,p in ipairs(v.profile or{})do h=max(h,v.h+p[2])end
  K.box(x-1.65,v.h,z-1.65,x+1.65,h+4,z+1.65,mat or 'ktBrick',.94)
  for y=h-2,h+3,1.65 do K.box(x-1.72,y,z-1.72,x+1.72,y+.18,z+1.72,'ktSandstone',1)end
  K.box(x-2.1,h+4,z-2.1,x+2.1,h+4.55,z+2.1,'ktBasalt',1.1)
  K.box(x-.9,h+4.58,z-.9,x+.9,h+4.72,z+.9,'dark',.6)
 end
 function R.roofHeight(v,x)
  local a=v.bounds;local t=(x-a.x0)/(a.x1-a.x0);local p=v.profile
  if not p then return v.h+.25 end
  for i=1,#p-1 do local l,r=p[i],p[i+1]
   if t<=r[1]or i==#p-1 then return v.h+l[2]+(r[2]-l[2])*(t-l[1])/(r[1]-l[1])+.25 end
  end
 end
 function R.terrace(v,mat,pergola)
  local a=v.bounds;local y=v.h+.32;local x0,x1,z0,z1=a.x0+1.5,a.x1-1.5,a.z0+1.5,a.z1-1.5
  if x1-x0<9 or z1-z0<9 then return end
  local function rail(a,b)
   K.beam({a[1],y+4.3,a[2]},{b[1],y+4.3,b[2]},.65,mat,1)
   local dx,dz=b[1]-a[1],b[2]-a[2];local len=math.sqrt(dx*dx+dz*dz);local n=max(1,math.floor(len/4.3))
   for i=0,n do local x,z=a[1]+dx*i/n,a[2]+dz*i/n;K.box(x-.18,y,z-.18,x+.18,y+4.3,z+.18,mat,.95)end
  end
  rail({x0,z1},{x1,z1});rail({x0,z0},{x1,z0});rail({x0,z0},{x0,z1});rail({x1,z0},{x1,z1})
  if pergola then
   local back=z0+(z1-z0)*.48;local top=y+10
   for _,x in ipairs({x0+1.2,x1-1.2})do for _,z in ipairs({z0+1.2,back})do K.box(x-.45,y,z-.45,x+.45,top,z+.45,mat,1)end end
   for _,x in ipairs({x0+1.2,x1-1.2})do K.box(x-.34,top,z0+.6,x+.34,top+.55,back+.6,mat,1)end
   for z=z0+1,back,3 do K.box(x0+.5,top+.65,z-.44,x1-.5,top+1.30,z+.44,mat,1.1)end
  end
  -- A compact bench and table make the retained terrace read as occupied.
  if x1-x0>14 and z1-z0>15 then
   local x,z=(x0+x1)/2,z0+(z1-z0)*.30
   K.box(x-3.7,y+2,z-1,x+3.7,y+2.5,z+1,'ktCedar',1)
   for _,xx in ipairs({x-2.7,x+2.7})do K.box(xx-.28,y,z-.65,xx+.28,y+2,z+.65,mat,.9)end
   K.box(x-3.7,y+2.5,z-.95,x+3.7,y+4.6,z-.60,mat,1)
   K.box(x-2.3,y+2.4,z+4,x+2.3,y+2.8,z+7,'ktCedar',1)
   K.box(x-.3,y,z+5.2,x+.3,y+2.4,z+5.8,mat,.9)
  end
  if family=='garden'or family=='waterfront'then
   for _,x in ipairs({x0+2.0,x1-2.0})do
    local z=z1-2.3
    K.box(x-1.2,y,z-1.2,x+1.2,y+1.8,z+1.2,family=='garden'and 'ktBrick'or 'ktPearl',1)
    K.box(x-1.3,y+1.8,z-1.3,x+1.3,y+2.1,z+1.3,mat,1.08)
    K.box(x-.95,y+2.13,z-.95,x+.95,y+2.24,z+.95,'dark',.7)
    for i=0,5 do
     local angle=i*math.pi/3;local dx,dz=math.cos(angle),math.sin(angle)
     K.leaf({x,y+2.3,z},{x+dx*1.9,y+3.8+(i%2)*.7,z+dz*1.5},.85,i%2==0 and 'leaf'or 'green')
    end
   end
  end
 end
 function R.sign()
  if not c.label then return end
  local u=(s.x0+s.x1)/2
  for _,d in ipairs(s.doors or{})do if(d.side or'front')=='front'then u=d.u or d.x;break end end
  local scale=min(.68,(s.x1-s.x0-8)/max(1,#c.label*4));local width=(#c.label*4-1)*scale+2.2
  u=max(s.x0+width/2+1,min(s.x1-width/2-1,u))
  local y=29.35;local mat=c.clinic and 'red'or c.shop and 'navy'or family=='quarry'and 'ktBasalt'or c.trim
  K.box(u-width/2,y,s.z1+.24,u+width/2,y+4.25,s.z1+.78,mat,.98)
  G.text(c.label,u,y+.53,s.z1+.88,scale,'white')
 end
 return R
end
return M
