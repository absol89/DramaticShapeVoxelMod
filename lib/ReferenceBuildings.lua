-- Complete Vermilion presentation meshes. Map blocks, warps, and collisions
-- remain engine-owned. Unsupported atlas/placements retain installed geometry.
local V=...
local P=V.require('ReferencePalette')
local M={}
local function bounds(quads,first,last)
 local a,b={1e9,1e9,1e9},{-1e9,-1e9,-1e9}
 for i=first,last do for j=1,4 do for k=1,3 do
  local n=quads[i][j][k];a[k]=math.min(a[k],n);b[k]=math.max(b[k],n)
 end end end
 return a,b
end
function M.compatible(map,data)
 if not map or map.id~='VERMILION_CITY' or not map.tileset or map.tileset.imageWidth~=128 or map.tileset.imageHeight~=1992 or not data then return false end
 for _,name in ipairs({'terra','cream','blue','white'}) do
  local p=P[name];local r,g,b=data:getPixel(p[1],p[2])
  if math.abs(r-p[3])>.006 or math.abs(g-p[4])>.006 or math.abs(b-p[5])>.006 then return false end
 end
 return true
end
-- Shared mesh constructor also used by the offline visual review tool.
function M.model(spec)
 local out={};local x0,x1,z0,z1=spec.x0,spec.x1,spec.z0,spec.z1
 local W,D=x1-x0,z1-z0;local cx=(x0+x1)/2
 local style=spec.style or 'cottage'
 local civic=style=='mart' or style=='center' or style=='gym'
 local tall=style=='townhouse' or style=='club'
 local eave=civic and 36 or tall and 43 or 35
 local rise=math.min(style=='club' and 25 or 23,W*.38)
 local wall=style=='cottage' and 'cream' or style=='bluehouse' and 'blue' or style=='townhouse' and 'white' or style=='club' and 'cream' or 'white'
 wall=spec.wall or wall
 local hipped=style=='townhouse' or style=='center'
 local trim=spec.trim or 'white'
 local roof=style=='bluehouse' and 'blue' or style=='townhouse' and 'slate' or 'terra'
 roof=spec.roof or roof
 local doors=spec.doors or {{x=cx}}
 local function face(a,b,c,d,mat,tone,glow)
  local p=P[mat];assert(p,'unknown material '..tostring(mat))
  local uv={(p[1]+.5)/128,(p[2]+.5)/1992}
  local shade=(tone or 1)+(glow and 64 or 0)
  if not glow then
   shade={}
   for i,p in ipairs({a,b,c,d})do
    shade[i]=(tone or 1)*(.82+.18*math.min(1,math.max(0,p[2])/7))
   end
  end
  out[#out+1]={a,b,c,d,uv={uv,uv,uv,uv},shade=shade,referenceGlass=glow or nil,own=true,referenceMaterial=mat}
 end
 local function box(a,b,c,d,e,f,mat,tone)
  if d-a<.001 or e-b<.001 or f-c<.001 then return end
  tone=tone or 1
  face({a,e,c},{a,e,f},{d,e,f},{d,e,c},mat,tone)
  face({a,b,f},{d,b,f},{d,e,f},{a,e,f},mat,tone*.92)
  face({d,b,c},{a,b,c},{a,e,c},{d,e,c},mat,tone*.8)
  face({a,b,c},{a,b,f},{a,e,f},{a,e,c},mat,tone*.83)
  face({d,b,f},{d,b,c},{d,e,c},{d,e,f},mat,tone*.96)
  face({a,b,c},{d,b,c},{d,b,f},{a,b,f},mat,tone*.65)
 end
 local function beam(a,b,width,mat)
  local dx,dy,dz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
  local len=math.sqrt(dx*dx+dy*dy+dz*dz)
  local u={-dy/len*width/2,dx/len*width/2,0}
  if math.abs(dx)+math.abs(dy)<.001 then u={width/2,0,0} end
  local v={0,0,width/2};if math.abs(dz)>len*.99 then v={0,width/2,0} end
  local pts={}
  for i,p in ipairs({a,b})do for j,s in ipairs({{-1,-1},{1,-1},{1,1},{-1,1}})do
   pts[(i-1)*4+j]={p[1]+u[1]*s[1]+v[1]*s[2],p[2]+u[2]*s[1]+v[2]*s[2],p[3]+u[3]*s[1]+v[3]*s[2]}
  end end
  for j=1,4 do local k=j%4+1;face(pts[j],pts[k],pts[k+4],pts[j+4],mat,.95) end
  face(pts[4],pts[3],pts[2],pts[1],mat,.9);face(pts[5],pts[6],pts[7],pts[8],mat,1)
 end
 if civic then
  V.require('LegendaryLandmarks').build(spec,face,box,beam)
  return out
 end
 local function rectsMinus(a,b,c,d,holes)
  local pieces={{a,b,c,d}}
  for _,h in ipairs(holes)do
   local next={}
   for _,r in ipairs(pieces)do
    local l,t,u,v=math.max(r[1],h[1]),math.max(r[2],h[2]),math.min(r[3],h[3]),math.min(r[4],h[4])
    if u>l and v>t then
     for _,p in ipairs({{r[1],r[2],l,r[4]},{u,r[2],r[3],r[4]},{l,r[2],u,t},{l,v,u,r[4]}})do if p[3]>p[1]+.001 and p[4]>p[2]+.001 then next[#next+1]=p end end
    else next[#next+1]=r end
   end
   pieces=next
  end
  return pieces
 end
 local function elevation(axis,plane,sign,low,high,openings,gable)
  local function p(u,y,n) return axis==3 and {u,y,plane+sign*(n or 0)} or {plane+sign*(n or 0),y,u} end
  local function panel(a,b,c,d,mat,tone,n)
   local aa,bb,cc,dd=p(a,b,n),p(c,b,n),p(c,d,n),p(a,d,n)
   if (axis==1 and sign==1) or (axis==3 and sign==-1) then aa,bb,cc,dd=dd,cc,bb,aa end
   face(aa,bb,cc,dd,mat,tone)
  end
  local function block(a,b,c,d,n0,n1,mat,tone)
   if axis==3 then box(a,b,plane+math.min(sign*n0,sign*n1),c,d,plane+math.max(sign*n0,sign*n1),mat,tone)
   else box(plane+math.min(sign*n0,sign*n1),b,a,plane+math.max(sign*n0,sign*n1),d,c,mat,tone) end
  end
  local holes={};for _,o in ipairs(openings)do holes[#holes+1]={o.u-o.w/2,o.y,o.u+o.w/2,o.y+o.h} end
  -- Course faces occupy disjoint ranges; shallow lips create real shadow.
  local top=eave+(gable and rise or 0)
  for y=0,top-.001,3 do
   local y1=math.min(y+3,top);local l,r=low,high
   if y1>eave then
    local inset=(y1-eave)/rise*(high-low)/2;l,r=low+inset,high-inset
   end
   if gable and y>=eave and y<top then
    local oldInset=(y-eave)/rise*(high-low)/2
    local oldL,oldR=low+oldInset,high-oldInset
    local function tri(a,b,c)
     if (axis==1 and sign==1) or (axis==3 and sign==-1) then a,c=c,a end
     face(a,b,c,c,wall,.97)
    end
    tri(p(oldL,y),p(l,y),p(l,y1))
    tri(p(r,y),p(oldR,y),p(r,y1))
   end
   if r>l+.001 then
    for _,q in ipairs(rectsMinus(l,y,r,y1,holes))do
     local mat=y<6 and 'stone' or wall
     panel(q[1],q[2],q[3],q[4],mat,.94+(math.floor(y/2)%3)*.025,0)
     if y>=6 then
      block(q[1],q[2],q[3],math.min(q[4],q[2]+.18),0,.18,mat,.80)
     end
    end
   end
  end
  for _,u in ipairs({low+.7,high-.7})do block(u-.6,4,u+.6,eave+.1,.05,.65,trim,1) end
  for _,q in ipairs(rectsMinus(low,5.4,high,6.2,holes))do
   block(q[1],q[2],q[3],q[4],.05,.8,'mortar',.95)
  end
  for _,u in ipairs({low+1,high-1})do
   for yy=7,eave-3,4 do block(u-1,yy,u+1,yy+2.3,.08,.82,'stone',.99)end
  end
  block(low,eave-1,high,eave,.05,.85,'white',1)
  for _,o in ipairs(openings)do
   local l,r,b,t=o.u-o.w/2,o.u+o.w/2,o.y,o.y+o.h
   local bay=not o.door and o.y<eave and o.shutters and axis==3 and sign==1
   local depth=bay and 1.8 or 0
   local originalP=p;local originalBlock=block
   if bay then
    -- Glazed side returns connect the opening to the projecting front frame.
    for _,u in ipairs({l,r})do
     face(originalP(u,b,-.6),originalP(u,b,depth),originalP(u,t,depth),originalP(u,t,-.6),'glass',.83,true)
    end
    block(l-1,t+.7,r+1,t+1.5,-.6,depth+.8,roof,.95)
    block(l-1,b-.9,r+1,b-.5,-.6,depth+.8,'stone',1)
    p=function(u,y,n)return originalP(u,y,(n or 0)+depth)end
    block=function(a,b,c,d,n0,n1,mat,tone)return originalBlock(a,b,c,d,n0+depth,n1+depth,mat,tone)end
   end
   local frame=o.door and 'white' or trim
   -- Actual recess: wall courses were cut out, not painted behind the glass.
   block(l-.7,b-.5,l+.35,t+.7,-.6,.65,frame,1)
   block(r-.35,b-.5,r+.7,t+.7,-.6,.65,frame,1)
   block(l+.35,t-.35,r-.35,t+.7,-.6,.65,frame,1)
   local mat=o.door and (style=='club' and 'green' or 'navy') or 'glass'
   local aa,bb,cc,dd=p(l+.35,b,-.7),p(r-.35,b,-.7),p(r-.35,t-.35,-.7),p(l+.35,t-.35,-.7)
   if (axis==1 and sign==1) or (axis==3 and sign==-1)then aa,bb,cc,dd=dd,cc,bb,aa end
   face(aa,bb,cc,dd,mat,.9,not o.door and o.lit~=false)
   if o.door then
    block(l+1.5,b+2,r-1.5,b+9,-.65,-.4,'blue',.9)
    block(l+1.5,b+11,r-1.5,t-3,-.65,-.4,'blue',1)
    block(r-2.8,b+10,r-1.8,b+11,-.4,.2,'gold',1)
    block(l-1,0,r+1,1,-.2,1.4,'stone',1)
   else
    block(o.u-.22,b,o.u+.22,t,-.6,.4,'white',1)
    block(l+.35,b+o.h*.5-.22,r-.35,b+o.h*.5+.22,-.6,.4,'white',1)
    block(l-.9,b-.65,r+.9,b+.15,-.4,1.3,'mortar',1)
    if o.shutters then
     for _,side in ipairs({-1,1})do
      local u=side<0 and l-3 or r+1
      block(u,b,u+2,t,.1,.65,spec.shutters or 'blue',.85)
      for yy=b+.6,t-.3,1.5 do block(u+.2,yy,u+1.8,yy+.22,.65,.8,'navy',1) end
     end
    end
   end
   p=originalP;block=originalBlock
  end
  if gable then
   beam(p(low-.5,eave+.4,.8),p((low+high)/2,eave+rise+.4,.8),1.4,'white')
   beam(p((low+high)/2,eave+rise+.4,.8),p(high+.5,eave+.4,.8),1.4,'white')
  end
 end
 local front={};local attic={};local doorW=14;local doorH=25
 for _,d in ipairs(doors)do front[#front+1]={u=d.x,y=0,w=d.w or doorW,h=doorH,door=true} end
 -- Allocate front windows only in uninterrupted wall spans beside doors.
 local spaces=rectsMinus(x0+5,0,x1-5,1,(function()local h={};for _,d in ipairs(doors)do local pad=(d.w or doorW)/2+5;h[#h+1]={d.x-pad,0,d.x+pad,1}end;return h end)())
 for _,span in ipairs(spaces)do
  local width=span[3]-span[1]
  if width>=10 then
   local n=math.max(1,math.floor(width/18))
   for i=1,n do front[#front+1]={u=span[1]+width*(i-.5)/n,y=11,w=math.min(12,width/n-3),h=12,shutters=not civic} end
  end
 end
 if rise>19 and not hipped then front[#front+1]={u=cx,y=eave+4,w=9,h=10,shutters=true} end
 elevation(3,z1,1,x0,x1,front,rise>0 and not hipped)
 local back={};for i=1,math.max(1,math.floor(W/24))do back[#back+1]={u=x0+W*i/(math.max(1,math.floor(W/24))+1),y=12,w=9,h=12,lit=i%2==1} end
 elevation(3,z0,-1,x0,x1,back,rise>0 and not hipped)
 for _,side in ipairs({-1,1})do
  local windows={};local n=math.max(1,math.floor(D/22))
  for i=1,n do windows[#windows+1]={u=z0+D*i/(n+1),y=12,w=10,h=12,shutters=not civic,lit=(i+side)%3~=0} end
  elevation(1,side<0 and x0 or x1,side,z0,z1,windows,false)
 end
 -- Roof tiles are the roof surface itself. Staggered joints and overlap lips
 -- are geometry with no second coincident roof hiding underneath.
 if rise>0 then
  local over=1.8;local rz0,rz1=z0-over,z1+over
  if hipped then
   local a,b=x0-over,x1+over
   local za,zb=z0+D*.30,z1-D*.30
   local E,T=eave,eave+rise
   local slopes={
    {{a,E,rz0},{cx,T,za},{cx,T,zb},{a,E,rz1}},
    {{cx,T,za},{b,E,rz0},{b,E,rz1},{cx,T,zb}},
    {{a,E,rz0},{b,E,rz0},{cx,T,za}},
    {{cx,T,zb},{b,E,rz1},{a,E,rz1}},
   }
   local function clip(poly,axis,value,greater)
    local out={}
    for i,p in ipairs(poly)do
     local q=poly[i%#poly+1]
     local inside=greater and p[axis]>=value or not greater and p[axis]<=value
     local nextInside=greater and q[axis]>=value or not greater and q[axis]<=value
     if inside then out[#out+1]=p end
     if inside~=nextInside then
      local t=(value-p[axis])/(q[axis]-p[axis]);local v={}
      for k=1,3 do v[k]=p[k]+(q[k]-p[k])*t end
      out[#out+1]=v
     end
    end
    return out
   end
   local function polygon(poly,mat,tone,lift)
    for i=2,#poly-1 do
     local q={};for j,k in ipairs({1,i,i+1})do local p=poly[k];q[j]={p[1],p[2]+lift,p[3]}end
     local u,v=q[2],q[3];local a=q[1]
     local cross=(u[1]-a[1])*(v[3]-a[3])-(u[3]-a[3])*(v[1]-a[1])
     if math.abs(cross)>.00001 then face(q[1],q[2],q[3],q[3],mat,tone)end
    end
   end
   for _,poly in ipairs(slopes)do
    polygon(poly,roof,.65,-.06)
    for z=rz0,rz1-.01,3.5 do for x=a,b-.01,5 do
     local p=clip(poly,1,x,true);p=clip(p,1,math.min(x+4.91,b),false)
     p=clip(p,3,z,true);p=clip(p,3,math.min(z+3.42,rz1),false)
     if #p>=3 then polygon(p,roof,.9+((math.floor(x/5)+math.floor(z/3.5)*3)%5)*.019,.1)end
    end end
   end
   box(a-.3,eave-.65,rz0,a+.3,eave+.1,rz1,'slate',.85)
   box(b-.3,eave-.65,rz0,b+.3,eave+.1,rz1,'slate',.85)
  else
  for _,side in ipairs({-1,1})do
   local edge=side<0 and x0-over or x1+over
   local function pt(t,z,lift)
    local fall=t
    if hipped then
     local zfall=math.max(0,1-math.min(z-rz0,rz1-z)/(D*.30))
     fall=math.max(t,zfall)
    end
    return {cx+(edge-cx)*t,eave+rise*(1-fall)+(lift or 0),z}
   end
   -- Continuous underlay closes views through tile joints at grazing angles.
   -- Separated from tile faces by .26 units, never a coplanar overlay.
   face(pt(0,rz0,-.08),pt(1,rz0,-.08),pt(1,rz1,-.08),pt(0,rz1,-.08),roof,.68)
   local rows=math.ceil(math.sqrt((W/2+over)^2+rise^2)/3.1)
   for row=0,rows-1 do
    local a,b=row/rows,(row+1)/rows
    local offset=row%2==0 and 0 or 2.5
    for z=rz0-offset,rz1-.001,5 do
     local l,r=math.max(rz0,z),math.min(rz1,z+4.88)
     if r>l then
      local tone=.94+((row*7+math.floor(z/5)*3)%5)*.012
      local mat=roof=='terra' and (row+math.floor(z/5))%11==0 and 'tile' or roof
      local aa,bb,cc,dd=pt(a,l,.18),pt(b,l,.18),pt(b,r,.18),pt(a,r,.18)
      if side==1 then aa,bb,cc,dd=dd,cc,bb,aa end
      face(aa,bb,cc,dd,mat,tone)
      face(pt(b,l,-.04),pt(b,r,-.04),pt(b,r,.18),pt(b,l,.18),roof,.67)
      -- Thin dark joint closes the .12 gap; it is disjoint from tile face.
      local rr=math.min(rz1,z+5)
      if rr>r then face(pt(a,r,0),pt(b,r,0),pt(b,rr,0),pt(a,rr,0),'terra',.58) end
     end
    end
   end
   box(edge-.55,eave-1.3,rz0,edge+.55,eave+.1,rz1,'white',.96)
   box(edge-.7,eave-1.6,rz0,edge+.7,eave-1.3,rz1,'slate',.85)
  end
  end -- gable / hip
  local cap0=hipped and z0+D*.3 or rz0
  local cap1=hipped and z1-D*.3 or rz1
  for z=cap0,cap1-.01,4 do
   local zz=math.min(z+3.85,cap1)
   face({cx-1.1,eave+rise-.7,z},{cx,eave+rise+.6,z},{cx,eave+rise+.6,zz},{cx-1.1,eave+rise-.7,zz},roof,1.12)
   face({cx,eave+rise+.6,z},{cx+1.1,eave+rise-.7,z},{cx+1.1,eave+rise-.7,zz},{cx,eave+rise+.6,zz},roof,.95)
  end
  -- Chimney intersects the roof deliberately below the surface.
  local chx=cx-W*.19;local chz=z0+D*.32;local foot=eave+rise*.55
  box(chx-2.5,foot,chz-2.5,chx+2.5,eave+rise+7,chz+2.5,'mortar',.95)
  for y=foot,eave+rise+6,2.2 do
   for k=0,1 do
    local a=chx-2.5+k*2.5
    box(a+.1,y+.12,chz+2.51,a+2.35,math.min(y+2,eave+rise+7),chz+2.68,'terra',.85+(k%2)*.1)
   end
  end
  box(chx-3.2,eave+rise+7,chz-3.2,chx+3.2,eave+rise+8.2,chz+3.2,'stone',1)
  box(chx-1.7,eave+rise+8.21,chz-1.7,chx+1.7,eave+rise+8.25,chz+1.7,'dark',.8)
 else
  box(x0,eave,z0,x1,eave+.6,z1,'slate',.95)
  for _,x in ipairs({x0,x1-1})do box(x,eave,z0,x+1,eave+3,z1,'white',1) end
  for _,z in ipairs({z0,z1-1})do box(x0,eave,z,x1,eave+3,z+1,'white',1) end
  box(x0+8,eave+.7,z0+7,x0+20,eave+3.5,z0+18,'stone',.9)
  for x=x0+9,x0+19,2 do box(x,eave+3.5,z0+8,x+.6,eave+3.65,z0+17,'dark',1) end
 end
 -- Front dormer on hipped buildings; its cheeks intersect the main roof.
 if hipped then
  local zz=z1-3;local base=eave+4;local top=eave+16
  box(cx-7,base,zz-7,cx+7,top,zz,'white',.95)
  face({cx-4,base+2,zz+.05},{cx+4,base+2,zz+.05},{cx+4,top-2,zz+.05},{cx-4,top-2,zz+.05},'glass',.9,true)
  box(cx-.25,base+2,zz+.08,cx+.25,top-2,zz+.45,'white',1)
  box(cx-4,base+7,zz+.08,cx+4,base+7.4,zz+.45,'white',1)
  face({cx-7,top,zz},{cx+7,top,zz},{cx,top+6,zz},{cx,top+6,zz},wall,1)
  for _,sign in ipairs({-1,1})do
   face({cx,top+6,zz-8},{cx+sign*8,top,zz-8},{cx+sign*8,top,zz+1},{cx,top+6,zz+1},roof,1)
   beam({cx+sign*8,top,zz+1.1},{cx,top+6,zz+1.1},.85,'white')
  end
 end
 -- Entrance canopies stay over the existing threshold; no pillars occupy it.
 for _,d in ipairs(doors)do
  local canopy=(d.w or doorW)/2+3
  local l,r=d.x-canopy,d.x+canopy;local f=z1+4.5
  local y=doorH+3
  for x=l,r-.01,2 do
   local mat=style=='mart' and (math.floor((x-l)/2)%2==0 and 'blue' or 'white') or roof
   face({x,y+2,z1-.1},{math.min(x+1.94,r),y+2,z1-.1},{math.min(x+1.94,r),y,f},{x,y,f},mat,1)
   face({x,y-.8,f},{math.min(x+1.94,r),y-.8,f},{math.min(x+1.94,r),y,f},{x,y,f},mat,.8)
  end
  beam({l+1,y-3.5,z1+.3},{l+1,y-.6,f-.5},.65,'wood')
  beam({r-1,y-3.5,z1+.3},{r-1,y-.6,f-.5},.65,'wood')
  if style=='club' then
   for _,x in ipairs({l+.3,r-.3})do
    box(x-.65,0,z1+2.4,x+.65,y-.4,z1+3.7,'white',1)
    box(x-.95,0,z1+2.1,x+.95,3,z1+4,'stone',1)
    box(x-.95,y-2,z1+2.1,x+.95,y-.3,z1+4,'white',1)
   end
   box(l-1,y-.7,f,r+1,y+.3,f+.6,'white',1)
  end
  -- Bracket lantern beside, not inside, the doorway.
  local lx=d.x+(d.w or doorW)/2+2
  box(lx-.3,18,z1+.1,lx+.3,24,z1+.8,'dark',1)
  box(lx-1.1,19,z1+.8,lx+1.1,22.7,z1+2.6,'dark',.9)
  face({lx-.7,19.5,z1+2.65},{lx+.7,19.5,z1+2.65},{lx+.7,22.1,z1+2.65},{lx-.7,22.1,z1+2.65},'gold',1,true)
  box(lx-1.4,22.7,z1+.5,lx+1.4,23.2,z1+2.9,'slate',1)
 end
 -- Shallow window boxes are mounted above the pavement and outside doors.
 for _,o in ipairs(front)do if not o.door and o.y<eave then
  local l,r=o.u-o.w/2-.5,o.u+o.w/2+.5
  box(l,6,z1+1.9,r,8,z1+4.3,'terra',1)
  box(l+.3,8.05,z1+.8,r-.3,8.2,z1+4.0,'dark',.8)
  for x=l+.65,r-.4,1.65 do
   local k=math.floor((x-l)*3);local y=9.2+(k%4)*.38
   box(x-.85,8.2,z1+2.5,x+.7,y,z1+3.85,k%2==0 and 'leaf' or 'green',.91)
   if k%3~=0 then
    box(x-.5,y-.1,z1+2.9,x+.5,y+.25,z1+3.5,'flower',1)
    box(x-.18,y+.25,z1+3.1,x+.18,y+.55,z1+3.35,'gold',.95)
   else
    box(x-.35,7,z1+4.2,x+.25,8.9,z1+4.65,'green',.88)
    box(x-.55,7.7,z1+4.1,x+.5,8.3,z1+4.6,'leaf',.95)
   end
  end
 end end
 if style=='townhouse' or style=='club' then
  for _,x in ipairs({x0+2,cx,x1-2})do
   local blocked=false;for _,d in ipairs(doors)do if math.abs(x-d.x)<9 then blocked=true end end
   if not blocked then box(x-.65,4,z1+.2,x+.65,eave,z1+.85,'wood',.82)end
  end
  box(x0,eave-3,z1+.3,x1,eave-1.8,z1+.9,'wood',.85)
 end
 -- Gable tie and paired brackets visually anchor the roof to the walls.
 if not hipped then
  box(x0-.6,eave-1.5,z1+.5,x1+.6,eave-.7,z1+1.15,'white',1)
  for _,x in ipairs({x0+2,x1-2})do beam({x,eave-5,z1+.3},{x,eave-.9,z1+2},.7,'wood')end
 end
 -- Gutters feed a rear corner downpipe, clear of entrances.
 for _,xx in ipairs({x0-.65,x1+.65})do
  box(xx-.28,2,z0+.8,xx+.28,eave-.5,z0+1.5,'slate',.9)
  for yy=7,eave-2,11 do box(xx-.42,yy,z0+.7,xx+.42,yy+.5,z0+1.6,'stone',1)end
 end
 -- Landmark signs are geometry, so their identity survives any atlas reuse.
 if civic or style=='club' then
  local sy=style=='mart' and 29 or eave-5
  local sw=style=='gym' and math.min(W-8,34) or 22
  box(cx-sw/2,sy,z1+.7,cx+sw/2,sy+7,z1+1.4,style=='center' and 'red' or 'navy',1)
  if style=='center' then
   box(cx-1,sy+1,z1+1.45,cx+1,sy+6,z1+1.6,'white',1)
   box(cx-3,sy+2.5,z1+1.45,cx+3,sy+4.5,z1+1.6,'white',1)
  else
   -- 3x5 block lettering: short readable identity at gameplay scale.
   local font={M={'101','111','111','101','101'},A={'010','101','111','101','101'},R={'110','101','110','101','101'},T={'111','010','010','010','010'},G={'111','100','101','101','111'},Y={'101','101','010','010','010'},C={'111','100','100','100','111'},L={'100','100','100','100','111'},U={'101','101','101','101','111'},B={'110','101','110','101','110'}}
   local label=style=='mart' and 'MART' or style=='gym' and 'GYM' or 'CLUB'
   local scale=.8;local start=cx-(#label*4-1)*scale/2
   for i=1,#label do local glyph=font[label:sub(i,i)]
    for row=1,5 do for col=1,3 do if glyph[row]:sub(col,col)=='1' then
     local xx=start+((i-1)*4+col-1)*scale;local yy=sy+1+(5-row)*scale
     face({xx,yy,z1+1.45},{xx+scale*.9,yy,z1+1.45},{xx+scale*.9,yy+scale*.9,z1+1.45},{xx,yy+scale*.9,z1+1.45},'white',1)
    end end end
   end
  end
 end
 -- A small ridge lookout distinguishes the fan club's waterfront hall.
 if style=='club' then
  local zz=z0+D*.5;local y=eave+rise
  box(cx-5,y-3,zz-5,cx+5,y+6,zz+5,'white',1)
  box(cx-.25,y+9,zz-.25,cx+.25,y+19,zz+.25,'wood',1)
  face({cx+.3,y+18,zz},{cx+7,y+17,zz},{cx+.3,y+14,zz},{cx+.3,y+14,zz},'blue',1)
  face({cx-3,y,zz+5.1},{cx+3,y,zz+5.1},{cx+3,y+4,zz+5.1},{cx-3,y+4,zz+5.1},'glass',.9,true)
  for _,s in ipairs({-1,1})do
   face({cx,y+11,zz-6},{cx+s*7,y+6,zz-6},{cx+s*7,y+6,zz+6},{cx,y+11,zz+6},roof,1)
  end
 end
 return out
end
function M.build(S,map,data)
 if not M.compatible(map,data) then return false end
 local replace={};local built=0
 for _,b in ipairs(S.harborBuildings or {})do
  local a,c=bounds(S.objectQuads,b.first,b.last)
  local W,D=c[1]-a[1],c[3]-a[3]
  if W>=30 and W<=180 and D>=18 and D<=140 and c[2]>=24 then
   local doors={};local dest=''
   for _,warp in ipairs((map.def or {}).warps or {})do
    local x,z=tonumber(warp.x),tonumber(warp.y)
    if x and z then x,z=x*16+8,z*16+8
     if x>a[1]+7 and x<c[1]-7 and z>=b.tileZ and z<=b.tileZ+b.tileH+16 then
      local exists=false;for _,d in ipairs(doors)do if math.abs(d.x-x)<1 then exists=true end end
      if not exists then doors[#doors+1]={x=x};dest=tostring(warp.destMap or '') end
     end
    end
   end
   -- Enterable houses use real warps. Authored non-enterable houses get
   -- windows but no invented door or warp.
   if (#doors>0 or b.authoredSides) and #doors<=2 then
    table.sort(doors,function(a,b)return a.x<b.x end)
    if #doors==2 and doors[2].x-doors[1].x<=16.1 then
     doors={{x=(doors[1].x+doors[2].x)/2,w=doors[2].x-doors[1].x+14}}
    end
    local style
    if dest:find('MART') then style='mart'
    elseif dest:find('POKECENTER') then style='center'
    elseif dest:find('GYM') then style='gym'
    elseif dest:find('FAN_CLUB') then style='club'
    elseif dest:find('OLD_ROD') or dest:find('FISHING') then style='cottage'
    elseif dest:find('TRADE') then style='bluehouse'
    elseif dest:find('PIDGEY') then style='townhouse'
    else local n=(math.floor(a[1]/16)+math.floor(a[3]/16))%3
     style=n==0 and 'bluehouse' or n==1 and 'townhouse' or 'cottage'
    end
    local spec={x0=a[1]+1,x1=c[1]-1,z0=a[3]+1,z1=c[3]-(b.frontEave or 0),doors=doors,style=style}
    local mesh=M.model(spec)
    replace[b.first]=mesh;for i=b.first+1,b.last do replace[i]=false end
    built=built+1
   end
  end
 end
 if built>0 then
  local out={};for i,q in ipairs(S.objectQuads)do
   if replace[i]==nil then out[#out+1]=q
   elseif replace[i] then for _,v in ipairs(replace[i])do out[#out+1]=v end end
  end
  S.objectQuads=out
 end
 S.referenceBuildingCount=built
 return built>0
end
return M
