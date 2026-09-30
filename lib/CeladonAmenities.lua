-- Static, cell-clipped park furniture. No extra lights or particle systems.
local V=...;local C=V.require('SurfaceCraft');local M={}
local font={C={'111','100','100','100','111'},E={'111','100','110','100','111'},L={'100','100','100','100','111'},A={'010','101','111','101','101'},D={'110','101','101','101','110'},O={'111','101','101','101','111'},N={'101','111','111','111','101'},G={'111','100','101','101','111'},R={'110','101','110','101','101'},S={'111','100','111','001','111'}}
function M.build(x,z,h,f,emit)
 local G=C.builder(x,z,emit);local a,b=f.cx,f.cz
 if f.kind=='bin' then
  G.box(a-1.3,b-1.3,a+1.3,b+1.3,h+.1,h+4.6,'shadow',.6)
  for i=0,3 do
   local t=-1.2+i*.65
   G.box(a+t,b-1.4,a+t+.45,b+1.4,h+.5,h+4.1,'wood',.85)
   G.box(a-1.4,b+t,a+1.4,b+t+.45,h+.5,h+4.1,'wood',.82)
  end
  -- Dark bands and an inset open top.
  for _,y in ipairs({h+.4,h+3.8})do
   for _,r in ipairs({{-1.5,-1.5,1.5,-1.22},{-1.5,1.22,1.5,1.5},{-1.5,-1.22,-1.22,1.22},{1.22,-1.22,1.5,1.22}})do G.box(a+r[1],b+r[2],a+r[3],b+r[4],y,y+.4,'shadow',.56)end
  end
  for _,r in ipairs({{-1.6,-1.6,1.6,-.8},{-1.6,.8,1.6,1.6},{-1.6,-.8,-.8,.8},{.8,-.8,1.6,.8}})do G.box(a+r[1],b+r[2],a+r[3],b+r[4],h+4.6,h+4.9,'shadow',.62)end
 elseif f.kind=='gardenSign' then
  for _,dx in ipairs({-4.4,4.4})do G.box(a+dx-.2,b-.25,a+dx+.2,b+.25,h+.15,h+7.8,'wood',.8)end
  G.box(a-5.6,b-.38,a+5.6,b+.38,h+4,h+9,'wood',.78)
  G.box(a-5.25,b-.42,a+5.25,b+.42,h+4.35,h+8.65,'canopy',.55)
  for _,side in ipairs({-1,1})do
   for line,text in ipairs({'CELADON','GARDENS'})do
    local size=.28;local start=a-(#text*4-1)*size/2
    for k=1,#text do for row,bits in ipairs(font[text:sub(k,k)])do for col=1,3 do if bits:sub(col,col)=='1' then
     local px=start+((k-1)*4+col-1)*size;local y=h+8.15-(line-1)*1.9-(row-1)*size
     if side<0 then px=2*a-px-size end
     local zz=b+side*.435
     local q={{px,y,zz},{px+size,y,zz},{px+size,y-size,zz},{px,y-size,zz}}
     G.face(q,'flowerWhite',.95);G.face({q[4],q[3],q[2],q[1]},'flowerWhite',.95)
    end end end end
   end
  end
 elseif f.kind=='fountain' then
  -- Taller fluted pedestal and a visibly hollow, bevelled basin.
  G.box(a-1.5,b-1.5,a+1.5,b+1.5,h+.1,h+.55,'stone',.94)
  G.box(a-1.15,b-1.15,a+1.15,b+1.15,h+.55,h+.95,'body',.92)
  G.box(a-.75,b-.75,a+.75,b+.75,h+.95,h+5.8,'stone',.98)
  for _,dx in ipairs({-.82,.66})do G.box(a+dx,b-.82,a+dx+.16,b+.82,h+1.15,h+5.55,'body',.98)end
  local function p(t,r,y)return {a+math.cos(t)*r,h+y,b+math.sin(t)*r}end
  for i=0,11 do
   local u,v=i*math.pi/6,(i+1)*math.pi/6
   G.face({p(u,.8,5.65),p(v,.8,5.65),p(v,1.65,6.35),p(u,1.65,6.35)},'body',.87)
   G.face({p(u,1.65,6.35),p(v,1.65,6.35),p(v,1.25,6.42),p(u,1.25,6.42)},'body',1.16)
   G.face({p(u,1.25,6.42),p(v,1.25,6.42),p(v,.5,5.94),p(u,.5,5.94)},'stone',.83)
   G.face({{a,h+5.94,b},p(u,.5,5.94),p(v,.5,5.94)},'shadow',.62)
  end
  -- Raised spout and push button; the fountain remains a decorative prop.
  G.box(a+.72,b-.22,a+1,b+.22,h+6.05,h+7.2,'body',1.14)
  G.box(a+.15,b-.2,a+1,b+.2,h+7.0,h+7.25,'body',1.2)
  G.box(a+.14,b-.16,a+.4,b+.16,h+6.83,h+7.05,'shadow',.7)
  G.box(a-.18,b-.83,a+.18,b-.74,h+4.85,h+5.2,'shadow',.7)

 end
end
return M
