-- Original landmark geometry inspired by the layered Pokemon-town aesthetic.
-- No imported Terrarium implementation or artwork. All entrances use map warps.
local M={}
function M.build(s,face,box,beam)
 local x0,x1,z0,z1=s.x0,s.x1,s.z0,s.z1
 local W,D=x1-x0,z1-z0;local cx=(x0+x1)/2
 local center=s.style=='center';local mart=s.style=='mart'
 local accent=center and 'red' or mart and 'blue' or 'slate'
 local H=center and 30 or mart and 29 or 35
 local doors=s.doors or {{x=cx}};local doorH=23
 local function panel(a,b,c,d,z,mat,tone,glow)
  face({a,b,z},{c,b,z},{c,d,z},{a,d,z},mat,tone or 1,glow)
 end
 local function disc(x,y,z,r,mat,tone)
  for i=0,23 do
   local a,b=i*math.pi/12,(i+1)*math.pi/12
   face({x,y,z},{x+r*math.cos(a),y+r*math.sin(a),z},{x+r*math.cos(b),y+r*math.sin(b),z},{x+r*math.cos(b),y+r*math.sin(b),z},mat,tone or 1)
  end
 end
 local function ball(x,y,z,r)
  disc(x,y,z,r+.65,'white');disc(x,y,z+.09,r,'dark')
  for i=0,23 do
   local a,b=i*math.pi/12,(i+1)*math.pi/12
   local rr=r-.65
   face({x,y,z+.18},{x+rr*math.cos(a),y+rr*math.sin(a),z+.18},{x+rr*math.cos(b),y+rr*math.sin(b),z+.18},{x+rr*math.cos(b),y+rr*math.sin(b),z+.18},i<12 and 'red' or 'white',1)
  end
  panel(x-r+.65,y-.65,x+r-.65,y+.65,z+.23,'dark')
  disc(x,y,z+.30,r*.31,'dark');disc(x,y,z+.39,r*.20,'white')
 end
 local font={M={'101','111','111','101','101'},A={'010','101','111','101','101'},R={'110','101','110','101','101'},T={'111','010','010','010','010'},G={'111','100','101','101','111'},Y={'101','101','010','010','010'},P={'110','101','110','100','100'},C={'111','100','100','100','111'}}
 local function label(str,x,y,z,scale)
  local left=x-(#str*4-1)*scale/2
  for i=1,#str do for row,bits in ipairs(font[str:sub(i,i)])do for col=1,3 do
   if bits:sub(col,col)=='1' then
    local xx,yy=left+((i-1)*4+col-1)*scale,y+(5-row)*scale
    panel(xx,yy,xx+scale*.88,yy+scale*.88,z,'white',1)
   end
  end end end
 end
 -- Explicit openings on every elevation; no solid wall behind glass/doors.
 local front={}
 for _,d in ipairs(doors)do front[#front+1]={u=d.x,w=d.w or 14,b=0,t=doorH,door=true}end
 local intervals={{x0+4,x1-4}}
 for _,d in ipairs(doors)do
  local next={};local l,r=d.x-(d.w or 14)/2-3,d.x+(d.w or 14)/2+3
  for _,v in ipairs(intervals)do
   if l>v[1] then next[#next+1]={v[1],math.min(l,v[2])}end
   if r<v[2] then next[#next+1]={math.max(r,v[1]),v[2]}end
  end
  intervals=next
 end
 for _,v in ipairs(intervals)do
  local width=v[2]-v[1]
  if width>=6 then front[#front+1]={u=(v[1]+v[2])/2,w=width,b=7,t=22,shop=mart}end
 end
 local function elevation(axis,plane,sign,low,high,openings)
  local function p(u,y,n)return axis==3 and {u,y,plane+sign*(n or 0)} or {plane+sign*(n or 0),y,u}end
  local function quad(a,b,c,d,n,mat,tone,glow)
   local aa,bb,cc,dd=p(a,b,n),p(c,b,n),p(c,d,n),p(a,d,n)
   if (axis==1 and sign==1)or(axis==3 and sign==-1)then aa,bb,cc,dd=dd,cc,bb,aa end
   face(aa,bb,cc,dd,mat,tone,glow)
  end
  local function block(a,b,c,d,n0,n1,mat,tone)
   if axis==3 then box(a,b,plane+math.min(sign*n0,sign*n1),c,d,plane+math.max(sign*n0,sign*n1),mat,tone)
   else box(plane+math.min(sign*n0,sign*n1),b,a,plane+math.max(sign*n0,sign*n1),d,c,mat,tone)end
  end
  -- Large plaster panels over a stone plinth, with shallow articulated joints.
  local cuts={low,high};for _,o in ipairs(openings)do cuts[#cuts+1]=o.u-o.w/2;cuts[#cuts+1]=o.u+o.w/2 end
  table.sort(cuts)
  for i=1,#cuts-1 do
   local a,c=cuts[i],cuts[i+1];local mid=(a+c)/2
   if c-a>.001 then
    local hole
    for _,o in ipairs(openings)do if mid>o.u-o.w/2 and mid<o.u+o.w/2 then hole=o;break end end
    for y=0,H-.01,4 do
     local t=math.min(y+4,H)
     local mat=y<4 and 'stone' or 'white'
     if not hole or t<=hole.b or y>=hole.t then
      quad(a,y,c,t,0,mat,.96)
      if y>=4 then block(a,y,c,math.min(t,y+.1),0,.12,'mortar',.82)end
     else
      if y<hole.b then quad(a,y,c,hole.b,0,mat,.96)end
      if t>hole.t then quad(a,hole.t,c,t,0,mat,.96)end
     end
    end
   end
  end
  for _,o in ipairs(openings)do
   local l,r=o.u-o.w/2,o.u+o.w/2
   block(l-.65,o.b,l+.25,o.t+.65,-1,.9,accent,1)
   block(r-.25,o.b,r+.65,o.t+.65,-1,.9,accent,1)
   block(l,o.t-.25,r,o.t+.65,-1,.9,accent,1)
   -- Blue lower pane plus warm interior visible behind mullions.
   quad(l+.25,o.b+.3,r-.25,o.t-.3,-.9,'glass',.90,true)
   if o.door then
    block(o.u-.3,.5,o.u+.3,o.t,-.8,.7,'stone',1)
    block(l,.5,r,2,-.8,.6,'slate',1)
    for _,sg in ipairs({-1,1})do block(o.u+sg*1.8-.15,9,o.u+sg*1.8+.15,13,.75,1.15,'gold',1)end
    block(l-.5,0,r+.5,.65,-.2,1.2,'stone',1)
   else
    block(l-.7,o.b-.7,r+.7,o.b+.3,-1,1.5,'stone',1)
    local n=math.max(1,math.floor(o.w/9))
    for i=1,n-1 do local u=l+o.w*i/n;block(u-.22,o.b,u+.22,o.t,-.8,.55,'white',1)end
    block(l,o.t-4,r,o.t-3.6,-.8,.55,'white',1)
    if o.shop then
     -- Shelves and original small goods sit within the recessed display.
     for y=o.b+3,o.t-5,5 do
      block(l+.6,y,r-.6,y+.35,-.6,-.1,'oak',.9)
      for u=l+1.5,r-1.2,2.6 do
       local k=math.floor((u-l)/2.6+y)%3
       block(u-.65,y+.4,u+.65,y+2.2,-.55,-.15,k==0 and 'red' or k==1 and 'blue' or 'green',1)
       block(u-.5,y+1.1,u+.5,y+1.6,-.14,-.07,'white',1)
      end
     end
    end
   end
  end
  for _,u in ipairs({low+.8,high-.8})do
   block(u-.8,1,u+.8,H,.02,.95,'stone',1)
   block(u-1,4,u+1,5,.05,1.1,accent,.94)
   block(u-1,H-2,u+1,H,.05,1.1,accent,1)
  end
 end
 elevation(3,z1,1,x0,x1,front)
 local rear={};local n=math.max(1,math.floor(W/18))
 for i=1,n do rear[#rear+1]={u=x0+W*i/(n+1),w=math.min(10,W/(n+1)-2),b=12,t=23}end
 elevation(3,z0,-1,x0,x1,rear)
 for _,sign in ipairs({-1,1})do
  local windows={};local n=math.max(1,math.floor(D/18))
  for i=1,n do windows[#windows+1]={u=z0+D*i/(n+1),w=math.min(11,D/(n+1)-2),b=9,t=22,shop=mart}end
  elevation(1,sign<0 and x0 or x1,sign,z0,z1,windows)
 end
 -- Thick continuous cornice and wraparound colored fascia.
 box(x0-1,H-1,z0-1,x1+1,H+.2,z1+1,'stone',1)
 box(x0-1.5,H+.2,z0-1.5,x1+1.5,H+2,z1+1.5,accent,1)
 -- Broad roof ridge runs ACROSS the facade. Faceted profile avoids cottage gables.
 local profile=center and {{0,0},{.10,5},{.27,10},{.73,10},{.90,5},{1,0}}
  or mart and {{0,0},{.15,6},{.85,6},{1,0}} or {{0,0},{.5,10},{1,0}}
 local rz0,rz1=z0-2,z1+2
 for j=1,#profile-1 do
  local a,b=profile[j],profile[j+1]
  local za,zb=rz0+(rz1-rz0)*a[1],rz0+(rz1-rz0)*b[1]
  local ya,yb=H+2+a[2],H+2+b[2]
  local rows=math.max(1,math.ceil(math.sqrt((zb-za)^2+(yb-ya)^2)/3.5))
  for i=0,rows-1 do
   local t,u=i/rows,(i+1)/rows
   local zz,zzz=za+(zb-za)*t,za+(zb-za)*u
   local yy,yyy=ya+(yb-ya)*t,yb==ya and ya or ya+(yb-ya)*u
   face({x0-2,yy,zz},{x1+2,yy,zz},{x1+2,yyy,zzz},{x0-2,yyy,zzz},accent,.96+(i%2)*.025)
   -- Raised standing seams, closed ends and white roof edge molding.
   for x=x0-1,x1+1,6 do beam({x,yy+.10,zz},{x,yyy+.10,zzz},.22,accent)end
  end
  for _,x in ipairs({x0-2,x1+2})do
   face({x,H+1,za},{x,ya,za},{x,yb,zb},{x,H+1,zb},accent,.83)
   beam({x,ya+.1,za},{x,yb+.1,zb},.8,'white')
  end
 end
 -- Skylights sit on the flat upper roof, with framed raised glass.
 if center then
  for _,x in ipairs({x0+W*.22,x0+W*.78})do
   local zz=z0+D*.46;local half=math.min(4,W*.08)
   box(x-half-.45,H+12.1,zz-3.5,x+half+.45,H+12.65,zz+3.5,'stone',1)
   face({x-half,H+12.7,zz-3},{x+half,H+12.7,zz-3},{x+half,H+12.7,zz+3},{x-half,H+12.7,zz+3},'glass',.9,true)
   box(x-.15,H+12.71,zz-3,x+.15,H+12.95,zz+3,'white',1)
  end
 end
 -- Drainpipes attach to rear corners, with wall mounting bands.
 for _,x in ipairs({x0-1,x1+1})do
  box(x-.25,2,z0+.8,x+.25,H,z0+1.4,'slate',.9)
  for y=5,H-1,9 do box(x-.4,y,z0+.7,x+.4,y+.5,z0+1.5,'stone',1)end
 end
 -- Commercial entrance bay, with clear threshold and no path-blocking pillars.
 for _,d in ipairs(doors)do
  local half=(d.w or 14)/2+2
  local l,r=math.max(x0,d.x-half),math.min(x1,d.x+half)
  box(l-1,0,z1+.1,l,doorH+3,z1+2,'stone',1)
  box(r,0,z1+.1,r+1,doorH+3,z1+2,'stone',1)
  box(l-1,doorH+1,z1+.1,r+1,doorH+3,z1+4.3,accent,1)
  box(l-1,doorH+.4,z1+3.9,r+1,doorH+1,z1+4.5,'white',1)
  for _,x in ipairs({l-.5,r+.5})do
   box(x-.55,15,z1+2,x+.55,20,z1+2.65,'slate',1)
   panel(x-.35,15.5,x+.35,19.5,z1+2.7,'glass',1,true)
  end
  -- Recessed ceiling light.
  face({l+2,doorH+.35,z1+1},{r-2,doorH+.35,z1+1},{r-2,doorH+.35,z1+3},{l+2,doorH+.35,z1+3},'glass',1,true)
 end
 if center then
  -- Raised central portal and unmistakable Pokeball crest.
  local entrance=doors[1] and doors[1].x or cx
  local radius=math.min(6.6,W*.14)
  local y=H+6
  box(entrance-radius-2,H-5,z1+.4,entrance+radius+2,y+2,z1+2,'red',1)
  box(entrance-radius-2,H-5,z1+2.05,entrance+radius+2,H-4.2,z1+2.4,'white',1)
  ball(entrance,y,z1+2.5,radius)
  -- Recessed red identity panels at either end of the frontage.
  for _,x in ipairs({x0+3,x1-3})do
   box(x-1.3,9,z1+.8,x+1.3,22,z1+1.1,'red',1)
   panel(x-.3,16,x+.3,20,z1+1.15,'white')
   panel(x-1,17.5,x+1,18.5,z1+1.16,'white')
  end
 elseif mart then
  -- Wraparound blue canopy gives the shop depth even from the side.
  box(x0-1,24,z1+.1,x1+1,25.5,z1+3.4,'blue',1)
  box(x0-1,23.5,z1+3.4,x1+1,24,z1+3.65,'white',1)
  for _,x in ipairs({x0-2,x1})do box(x,24,z0,x+2,25.5,z1+3.4,'blue',1)end
  local sw=math.min(W-7,31)
  box(cx-sw/2,H-1,z1+1.6,cx+sw/2,H+7,z1+2.4,'navy',1)
  box(cx-sw/2-.6,H-1.6,z1+1.45,cx+sw/2+.6,H+7.6,z1+1.6,'white',1)
  label('MART',cx,H+.2,z1+2.5,math.min(1.15,(sw-2)/15))
  -- Two roof ventilators, kept well behind the storefront.
  for _,x in ipairs({x0+W*.28,x0+W*.72})do
   box(x-2,H+8,z0+D*.35-2,x+2,H+10,z0+D*.35+2,'stone',1)
   box(x-2.5,H+10,z0+D*.35-2.5,x+2.5,H+10.6,z0+D*.35+2.5,'slate',1)
  end
 else
  -- Gym: industrial ribs, high badge and steel entry framing.
  for _,sign in ipairs({-1,1})do for z=z0+5,z1-3,10 do
   local x=sign<0 and x0-1 or x1
   box(x,3,z,x+1,H,z+1.2,'slate',.95)
  end end
  box(cx-12,H-3,z1+1.2,cx+12,H+6,z1+2,'navy',1)
  label('GYM',cx,H-1.5,z1+2.1,1.1)
  local bx,by=cx,H+11
  face({bx-2,by+4,z1+1},{bx+1,by+4,z1+1},{bx-1,by,z1+1},{bx-4,by,z1+1},'gold',1)
  face({bx-1,by+1,z1+1},{bx+3,by+1,z1+1},{bx-1,by-4,z1+1},{bx-1,by-4,z1+1},'gold',1)
 end
 -- Planters live under windows and never span the actual doorway.
 for _,o in ipairs(front)do if not o.door and o.w>=7 then
  local l,r=o.u-o.w*.38,o.u+o.w*.38
  box(l,1,z1+.5,r,4,z1+2.7,'stone',1)
  box(l+.4,4,z1+.8,r-.4,4.2,z1+2.4,'dark',.8)
  for x=l+.8,r-.5,1.8 do
   box(x-.65,4.2,z1+1,x+.65,6,z1+2.2,'green',1)
   box(x-.3,6,z1+1.3,x+.3,6.5,z1+1.9,center and 'flower' or 'gold',1)
  end
 end end
end
return M
