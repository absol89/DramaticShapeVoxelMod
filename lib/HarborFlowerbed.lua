local V=...
local C=V and V.require('SurfaceCraft') or assert(loadfile('lib/SurfaceCraft.lua'))()
local M={}
function M.build(x,z,h,f,emit)
 local G=C.builder(x,z,emit)
 local function p(u,v,y)
  if f.edge=='n' then return {f.cx+u,h+y,f.cz-4+v}
  elseif f.edge=='s' then return {f.cx+u,h+y,f.cz+4-v}
  elseif f.edge=='w' then return {f.cx-4+v,h+y,f.cz+u}
  else return {f.cx+4-v,h+y,f.cz+u}end
 end
 local function face(t,m,tone)
  local r={};for _,v in ipairs(t)do r[#r+1]=p(v[1],v[2],v[3])end
  G.face(r,m,tone)
 end
 -- Twenty units long, with clipped corners and an uneven front edge.
 local outline={{-10,1.4},{-8.8,.35},{8.5,.35},{10,1.7},{9.6,4.45},{7.3,5.3},{3.6,5.0},{0,5.55},{-3.8,5.15},{-7.8,5.4},{-10,4.1}}
 local inner={}
 for i,a in ipairs(outline)do inner[i]={a[1]*.94,2.8+(a[2]-2.8)*.79,.62}end
 face(inner,'shadow',.65)
 for i,a in ipairs(outline)do
  local j=i%#outline+1;local b=outline[j];local c,d=inner[i],inner[j]
  local len=math.sqrt((b[1]-a[1])^2+(b[2]-a[2])^2);local n=math.ceil(len/2)
  for k=0,n-1 do
   local t0,t1=k/n+.015,(k+1)/n-.015
   local function mix(q,r,t,y)return {q[1]+(r[1]-q[1])*t,q[2]+(r[2]-q[2])*t,y}end
   local top=.85+C.hash(f.seed,i*20+k,4201)*.18
   face({mix(a,b,t0,top),mix(a,b,t1,top),mix(c,d,t1,top),mix(c,d,t0,top)},'body',.85+(k%3)*.06)
   face({mix(a,b,t0,.24),mix(a,b,t1,.24),mix(a,b,t1,top),mix(a,b,t0,top)},'sand',.78)
  end
 end
 -- Low mounds and flower clumps at varied heights; no tall repeated plants.
 for j=0,9 do
  local u=-8.2+j*1.8;local v=1.55+(j%2)*1.7
  local height=1.45+C.hash(f.seed,j,4202)*.7
  for k=0,3 do
   local a=k*math.pi/2+j*.6;local dx,dz=math.cos(a),math.sin(a)
   face({{u,v,.63},{u+dx*.6-dz*.48,v+dz*.6+dx*.48,height},{u+dx*1.3,v+dz*1.3,.9},{u+dx*.6+dz*.48,v+dz*.6-dx*.48,height}},'leaf',.78+(j%3)*.1)
  end
  for k=0,1 do
   local cu,cv=u+(k-.5)*.7,v+(k-.5)*.6
   local y=height+.55+C.hash(j,k,f.seed)*.8
   local r=.48+(j%3)*.06
   face({{cu-.04,cv,.7},{cu+.04,cv,.7},{cu+.04,cv,y},{cu-.04,cv,y}},'leaf',.85)
   for n=0,4 do
    local a=n*math.pi*.4
    face({{cu,cv,y},{cu+math.cos(a-.4)*r,cv+math.sin(a-.4)*r,y+.07},{cu+math.cos(a)*r*1.45,cv+math.sin(a)*r*1.45,y+.2},{cu+math.cos(a+.4)*r,cv+math.sin(a+.4)*r,y+.07}},j%4==0 and 'light' or 'petal',.92+(j%3)*.08)
   end
   face({{cu-.12,cv-.12,y+.22},{cu+.12,cv-.12,y+.22},{cu+.12,cv+.12,y+.22},{cu-.12,cv+.12,y+.22}},'sand',1.05)
  end
 end
 -- Small angular stones embedded in exposed soil, with moss on selected tops.
 for j=0,3 do
  local u=-6.5+j*4.3;local v=3.8-(j%2)*2.4
  face({{u-.55,v-.35,.65},{u+.5,v-.3,.65},{u+.35,v+.35,1.15},{u-.35,v+.4,1.1}},'body',.8)
  face({{u-.35,v+.4,1.1},{u+.35,v+.35,1.15},{u+.15,v+.05,1.3},{u-.25,v-.1,1.25}},j%2==0 and 'moss' or 'body',.86)
 end
end
return M
