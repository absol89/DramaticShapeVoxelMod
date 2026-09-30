-- Safari-only timber lodges. Door axes come from the actual warp records.
local V=...;local M={}
local function lantern(G,x,y,z)
 G.box(x-.75,y,z-.55,x+.75,y+2.8,z+.55,'dark',.9)
 G.box(x-.5,y+.45,z-.6,x+.5,y+2.35,z+.6,'gold',1.08)
 for _,xx in ipairs({x-.52,x+.52})do G.box(xx-.07,y+.3,z-.67,xx+.07,y+2.5,z+.67,'wood',.85)end
 G.box(x-.54,y+1.4,z-.66,x+.54,y+1.52,z+.66,'wood',.88)
 G.box(x-1,y+2.8,z-.8,x+1,y+3.15,z+.8,'wood',.86)
end
function M.house(s)
 local G=V.require('CityMesh').new(s.uv)
 local x0,x1,z0,z1=s.x0,s.x1,s.z0,s.z1;local mid=(x0+x1)/2
 local H=22;local peak=32;local secret=s.destination:find('SECRET')~=nil
 local wall=secret and 'sage' or 'cream'
 -- Short staggered timber boards, shallow overlap, nail pairs and subtle
 -- wear on all four walls. Selected rest/secret wall palettes stay intact.
 local hash=V.require('SurfaceCraft').hash
 G.box(x0+.12,0,z0+.12,x1-.12,H,z1-.12,'wood',.76)
 for course=0,7 do local y=2+course*2.35
  for side=0,3 do
   local lo,hi=(side<2 and x0 or z0),(side<2 and x1 or z1)
   local step=9.4;local offset=(course%2)*4.7
   for start=lo-offset,hi,step do local a,b=math.max(lo,start),math.min(hi,start+step-.12)
    if b>a then
     local tone=.86+hash(start,course,side+111)*.14
     local function board(aa,bb,yy,hh,depth,mat,t)
      if side==0 then G.box(aa,yy,z1-.3,bb,yy+hh,z1+depth,mat,t)
      elseif side==1 then G.box(aa,yy,z0-depth,bb,yy+hh,z0+.3,mat,t)
      elseif side==2 then G.box(x0-depth,yy,aa,x0+.3,yy+hh,bb,mat,t)
      else G.box(x1-.3,yy,aa,x1+depth,yy+hh,bb,mat,t)end
     end
     board(a,b,y,2.15,.09,wall,tone)
     -- Small grain lines and end fasteners catch light without a pixel pattern.
     local inset=.3+(b-a)*.13
     if b-a>2 then
      board(a+inset,b-.4,y+.63,.045,.105,'oak',.89)
      board(a+.6,b-inset,y+1.55,.032,.106,wall,.77)
      for _,u in ipairs({a+.25,b-.25})do board(u,u+.095,y+.35,.10,.125,'dark',.81)end
     end
    end
   end
  end
 end
 for _,x in ipairs({x0,x1,mid})do
  if x~=mid then G.box(x-.65,0,z0-.4,x+.65,H+1,z0+.8,'wood',.9)end
  G.box(x-.65,0,z1-.7,x+.65,H+1,z1+.6,'wood',.9)
 end
 G.box(x0-.5,.1,z0-.5,x1+.5,1.5,z1+.5,'slate',.96)
 G.box(x0-.7,H-1,z0-.7,x1+.7,H,z1+.7,'oak',.95)
 -- Individually varied shingle faces share the lodge's native mesh. Shallow
 -- overlap adds roof relief without loose objects or per-stone path geometry.
 for side=0,1 do
  local left=side==0 and x0-1.6 or mid;local right=side==0 and mid or x1+1.6
  local function roofY(x)return side==0 and H+1+(peak-H-1)*(x-left)/(right-left)or peak-(peak-H-1)*(x-left)/(right-left)end
  for j=0,6 do
   local xa,xb=left+(right-left)*j/7,left+(right-left)*(j+1)/7
   local ya,yb=roofY(xa),roofY(xb)
   G.face({xa,ya,z0-1.4},{xa,ya,z1+1.4},{xb,yb,z1+1.4},{xb,yb,z0-1.4},'wood',.74)
   for start=z0-1.4-(j%2)*2.3,z1+1.4,4.6 do
    local za,zb=math.max(z0-1.4,start),math.min(z1+1.4,start+4.48)
    if zb>za then
     local lift=.10+hash(j,start,side+113)*.06;local tone=.86+hash(j,start,side+119)*.15
     local xaa,xbb=xa+.04,xb-.04;local yaa,ybb=roofY(xaa)+lift,roofY(xbb)+lift
     G.face({xaa,yaa,za},{xaa,yaa,zb},{xbb,ybb,zb},{xbb,ybb,za},'sage',tone)
     local ex,ey=side==0 and xaa or xbb,side==0 and yaa or ybb
     G.face({ex,ey-.16,za},{ex,ey-.16,zb},{ex,ey,zb},{ex,ey,za},'wood',.82)
    end
   end
  end
 end
 G.beam({mid,peak+.1,z0-1.6},{mid,peak+.1,z1+1.6},1.2,'wood',.9)
 for _,z in ipairs({z0-1.4,z1+1.4})do
  G.face({x0,H,z},{x1,H,z},{mid,peak,z},{mid,peak,z},'wood',.88)
  G.beam({x0-1.6,H+1,z},{mid,peak,z},.8,'oak',1)
  G.beam({mid,peak,z},{x1+1.6,H+1,z},.8,'oak',1)
 end
 -- Authored entrance positions are kept; trims/windows cannot cover the door.
 local door=s.doors[1]or {x=mid,w=14};local dx,dw=door.x,door.w
 G.box(dx-dw/2,0,z1+.07,dx+dw/2,16,z1+.3,'dark',.8)
 G.box(dx-dw/2+.9,.3,z1+.32,dx+dw/2-.9,15,z1+.5,'oak',.96)
 for _,x in ipairs({dx-dw/2,dx+dw/2})do G.box(x-.55,0,z1+.1,x+.55,16.8,z1+.85,'wood',1)end
 G.box(dx-dw/2-.55,16,z1+.1,dx+dw/2+.55,17,z1+.85,'wood',1)
 -- Recessed door panels, rails, strap hinges and a brass pull.
 for _,offset in ipairs({-dw*.23,dw*.23})do
  for _,y in ipairs({2,8.8})do
   G.box(dx+offset-dw*.17,y,z1+.51,dx+offset+dw*.17,y+4.9,z1+.56,'wood',.84)
   G.box(dx+offset-dw*.14,y+.27,z1+.57,dx+offset+dw*.14,y+4.65,z1+.59,'oak',.95)
  end
 end
 G.box(dx-.15,.5,z1+.61,dx+.15,14.8,z1+.68,'wood',.74)
 for _,y in ipairs({3.1,12.2})do
  G.box(dx-dw/2+1,y,z1+.62,dx-dw/2+3.5,y+.35,z1+.70,'dark',.88)
 end
 G.box(dx+dw*.23,7,z1+.65,dx+dw*.23+.7,8,z1+1,'gold',1)
 for _,x in ipairs({x0+8,x1-8})do if math.abs(x-dx)>dw/2+5 then
  G.box(x-4,7,z1+.08,x+4,15,z1+.25,'dark',.8)
  G.box(x-3.2,7.8,z1+.27,x+3.2,14.2,z1+.3,'glass',.98)
  G.box(x-.25,7.5,z1+.32,x+.25,14.5,z1+.65,'wood',1)
  G.box(x-3.5,10.7,z1+.32,x+3.5,11.2,z1+.65,'wood',.95)
  for _,xx in ipairs({x-5.3,x+4.3})do for y=7,14,1.4 do G.box(xx,y,z1+.1,xx+1,y+.9,z1+.8,'green',.84)end end
  G.box(x-4.5,6.5,z1+.1,x+4.5,7,z1+1,'oak',1)
  for _,xx in ipairs({x-3.8,x+3.4})do G.box(xx,7.1,z1+.35,xx+.4,14.9,z1+.76,'oak',1)end
  G.box(x-4,14.5,z1+.1,x+4,15.3,z1+.9,'oak',1)
  G.box(x-3,11.3,z1+.315,x-.4,11.5,z1+.325,'cream',.91)
 end end
 -- Roofed threshold is within the original facade/eave, with no path posts.
 G.box(dx-9,18,z1+.1,dx+9,18.7,z1+1.5,'wood',.9)
 local label=secret and 'SECRET HOUSE' or 'REST HOUSE'
 -- Gable vent sits above the sign, with a framed ridge and hood.
 for y=28,30,.6 do G.box(mid-2.7,y,z1+1.43,mid+2.7,y+.19,z1+1.6,'dark',.79)end
 G.box(mid-16.4,22.9,z1+1.45,mid+16.4,27.7,z1+1.85,'oak',.98)
 G.box(mid-16,23.2,z1+1.5,mid+16,27.4,z1+2,'dark',.85)
 G.text(label,mid,24,z1+2.02,.48,'cream')
 lantern(G,x0+2,14,z1+1);lantern(G,x1-2,14,z1+1)
 -- Side braces, ventilation, and raised sill details stay within the source lot.
 for _,x in ipairs({x0-.08,x1+.08})do
  for z=z0+3,z1-3,5 do G.beam({x,3,z},{x,12,z+3},.55,'wood',.85)end
 end
 return G.out
end
function M.build(S,map)
 local replace={};S.safariBuildings={}
 for _,b in ipairs(S.cityBuildings or {})do if b.id=='safari_rest_house'and b.last>=b.first then
  local doors,dest=V.require('CityBuildings').doors(map,b)
  if #doors>0 then
   -- Exact source lot, including the existing shallow front eave.
   local spec={x0=b.tileX+1,x1=b.tileX+b.tileW-1,z0=b.tileZ+1,z1=b.tileZ+b.tileH-3,doors=doors,destination=dest,uv={.5/128,.5/48}}
   replace[b.first]=M.house(spec);for i=b.first+1,b.last do replace[i]=false end
   S.safariBuildings[#S.safariBuildings+1]=spec
  end
 end end
 local out={};for i,q in ipairs(S.objectQuads)do if replace[i]==nil then out[#out+1]=q elseif replace[i]then for _,p in ipairs(replace[i])do out[#out+1]=p end end end;S.objectQuads=out
end
function M.exit(S,map)
 if map.id~='SAFARI_ZONE_CENTER'then return end
 local found=0;for _,w in ipairs(map.def.warps or{})do if w.destMap=='SAFARI_ZONE_GATE'and w.y==25 and(w.x==14 or w.x==15)then found=found+1 end end
 if found~=2 then return end
 local G=V.require('CityMesh').new({.5/128,.5/48})
 -- Two real warp lanes stay open under a broad ranger arch, beyond the edge.
 for _,x in ipairs({208,272})do
  G.box(x-4,0,416,x+4,28,430,'wood',.9)
  G.box(x-5,0,415,x+5,3,431,'slate',.96)
  G.beam({x,19,420},{x<240 and x+9 or x-9,28,420},1.8,'oak',.95)
 end
 G.box(204,27,417,276,30,425,'wood',.94)
 G.face({200,30,414},{280,30,414},{280,35,422},{200,35,422},'sage',.9)
 G.face({200,35,422},{280,35,422},{280,30,430},{200,30,430},'sage',.8)
 -- TEST113: roof courses, ridge cap and joinery stay outside the open warp lanes.
 for _,side in ipairs({-1,1})do
  for row=0,3 do local za=422+side*row*2;local zb=422+side*(row+1)*2
   local ya=35-row*1.25+.035;local yb=35-(row+1)*1.25+.035
   for col=0,9 do local x=200+col*8;local tone=.86+((row*3+col)%4)*.018
    G.face({x,ya,za},{x+7.94,ya,za},{x+7.94,yb,zb},{x,yb,zb},'sage',tone)
    G.beam({x,yb,zb},{x+7.94,yb,zb},.085,'slate',.94)
   end
  end
  G.beam({199.9,30,422+side*8},{280.1,30,422+side*8},.65,'wood',1.0)
 end
 G.beam({200,35.14,422},{280,35.14,422},.55,'slate',1.08)
 for _,x in ipairs({208,272})do
  G.box(x-4.08,5,415.93,x+4.08,5.8,416.11,'dark',.9)
  G.box(x-4.08,22,415.93,x+4.08,22.8,416.11,'dark',.9)
  for j=0,2 do
   local xx=x-2.3+j*2.2
   G.beam({xx,6,415.97},{xx+.18,21,415.97},.045,'oak',.98)
  end
 end
 G.box(223,23,416,257,28,417,'dark',.9)
 -- Text is mirrored in X to face north, towards the player inside Safari.
 local T=V.require('CityMesh').new({.5/128,.5/48});T.text('EXIT',240,24,415.98,.6,'cream')
 for _,q in ipairs(T.out)do for i=1,4 do q[i][1]=480-q[i][1]end;q[1],q[4]=q[4],q[1];q[2],q[3]=q[3],q[2];G.out[#G.out+1]=q end
 for _,q in ipairs(G.out)do S.objectQuads[#S.objectQuads+1]=q end
 S.safariExit=true
end
return M
