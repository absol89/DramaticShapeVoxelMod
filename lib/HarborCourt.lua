local V=...
local C=V and V.require('SurfaceCraft') or assert(loadfile('lib/SurfaceCraft.lua'))()
local M={}
function M.bin(x,z,h,b,emit)
 local G=C.builder(x,z,emit);local a,c=b.x,b.z
 -- Dark recessed body, timber slats, metal foot and a rim around an open mouth.
 G.box(a-1.25,c-1.25,a+1.25,c+1.25,h+.2,h+.6,'shadow',.55)
 G.box(a-1.15,c-1.15,a+1.15,c+1.15,h+.6,h+5.5,'shadow',.45)
 for j=0,3 do local t=-1.16+j*.6
  G.box(a+t,c-1.32,a+t+.46,c-1.16,h+.8,h+5.25,'wood',.86+j*.03)
  G.box(a+t,c+1.16,a+t+.46,c+1.32,h+.8,h+5.25,'wood',.86+j*.03)
  G.box(a-1.32,c+t,a-1.16,c+t+.46,h+.8,h+5.25,'wood',.86+j*.03)
  G.box(a+1.16,c+t,a+1.32,c+t+.46,h+.8,h+5.25,'wood',.86+j*.03)
 end
 for _,y in ipairs({1.0,4.65})do
  G.box(a-1.39,c-1.39,a+1.39,c-1.27,h+y,h+y+.22,'shadow',.65)
  G.box(a-1.39,c+1.27,a+1.39,c+1.39,h+y,h+y+.22,'shadow',.65)
 end
 G.flat(a-1.15,c-1.15,a+1.15,c+1.15,h+5.51,'shadow',.23)
 for _,q in ipairs({{-1.45,-1.45,1.45,-.98},{-1.45,.98,1.45,1.45},{-1.45,-.98,-.98,.98},{.98,-.98,1.45,.98}})do
  G.box(a+q[1],c+q[2],a+q[3],c+q[4],h+5.55,h+6.2,'shadow',.7)
 end
end
function M.garden(x,z,h,emit,edges)
 local G=C.builder(x,z,emit)
 for _,e in ipairs({'n','s','e','w'})do if edges and edges[e] then
  for j=0,3 do
   local a,b,c,d
   if e=='n' then a,b,c,d=x+j*2+.04,z,x+j*2+1.96,z+.42
   elseif e=='s' then a,b,c,d=x+j*2+.04,z+7.58,x+j*2+1.96,z+8
   elseif e=='w' then a,b,c,d=x,z+j*2+.04,x+.42,z+j*2+1.96
   else a,b,c,d=x+7.58,z+j*2+.04,x+8,z+j*2+1.96 end
   G.box(a,b,c,d,h+.15,h+.53,'body',.87+j*.035)
  end
 end end
 -- Broad color variation, darker soil beneath plant clusters.
 for j=0,3 do for i=0,3 do
  local a,b=x+i*2,z+j*2
  G.flat(a,b,a+2,b+2,h+.26,'moss',.64+C.field(a*.09,b*.09,4501)*.42)
 end end
 local function bloom(a,b,y,r,mat,phase)
  G.blade(a,b,h+.35,y-h-.35,.07,.03,phase,'leaf',.82)
  for k=0,4 do local t=k*math.pi*.4+phase
   G.face({{a,y,b},{a+math.cos(t-.4)*r*.62,y+.1,b+math.sin(t-.4)*r*.62},
    {a+math.cos(t)*r,y+.23,b+math.sin(t)*r},{a+math.cos(t+.4)*r*.62,y+.1,b+math.sin(t+.4)*r*.62}},mat,1.0)
  end
  G.flat(a-.13,b-.13,a+.13,b+.13,y+.25,'sand',1.05)
 end
 local patch=C.field((x+4)/22,(z+4)/22,4601)
 for j=0,1 do if C.hash(x,z,4510+j)>(patch>.53 and .02 or .52) then
  local a=x+1.8+j*3.0+C.hash(x,z+j,4502)*1.4
  local b=z+1.8+(j%2)*3.0+C.hash(x+j,z,4503)*1.4
  for k=0,7 do
   local u,v=k*math.pi/4,(k+1)*math.pi/4
   G.face({{a,h+.28,b},{a+math.cos(u)*1.65,h+.28,b+math.sin(u)*1.45},{a+math.cos(v)*1.65,h+.28,b+math.sin(v)*1.45}},'shadow',.55)
  end
  local high=1.8+C.hash(x+j,z,4504)*.9
  for k=0,5 do
   local t=k*math.pi/3+j;local dx,dz=math.cos(t),math.sin(t)
   local root={a,h+.3,b};local mid={a+dx*.6,h+high,b+dz*.6}
   local tip={a+dx*1.6,h+.8,b+dz*1.6}
   local left={mid[1]-dz*.5,mid[2]-.25,mid[3]+dx*.5}
   local right={mid[1]+dz*.5,mid[2]-.25,mid[3]-dx*.5}
   for _,poly in ipairs({{root,left,mid},{left,tip,mid},{tip,right,mid},{right,root,mid}})do
    G.face(poly,'leaf',.78+(k%3)*.09)
   end
  end
  for k=0,2 do
   local t=k*2.1+j
   bloom(a+math.cos(t)*.75,b+math.sin(t)*.75,h+high+.8+C.hash(x+k,z+j,4505)*.8,.7+(k%2)*.15,
    C.field(x/20,z/20,4602)>.6 and 'light' or 'petal',t)
  end
 end end
 -- Occasional low shrub or stone breaks up the flower rhythm.
 local seed=C.hash(x,z,4506)
 if seed>.78 then
  for k=0,4 do local t=k*1.256
   G.blade(x+4,z+4,h+.3,3.2+C.hash(x+k,z,4507)*1.2,.5,.8,t,'leaf',.7+k*.04)
  end
 elseif seed<.2 then
  G.box(x+3.2,z+3.5,x+4.7,z+4.6,h+.25,h+.95,'body',.83)
  G.flat(x+3.3,z+3.6,x+4.2,z+4.5,h+.96,'moss',.81)
 end
end
return M
