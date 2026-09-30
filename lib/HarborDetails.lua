local V=...
local C=V and V.require('SurfaceCraft') or assert(loadfile('lib/SurfaceCraft.lua'))()
local M={}
local function ring(G,a,b,y,r,w,mat,t)
 for j=0,11 do local u,v=j*math.pi/6,(j+1)*math.pi/6
  G.face({{a+math.cos(u)*r,y,b+math.sin(u)*r},{a+math.cos(v)*r,y,b+math.sin(v)*r},{a+math.cos(v)*(r-w),y,b+math.sin(v)*(r-w)},{a+math.cos(u)*(r-w),y,b+math.sin(u)*(r-w)}},mat,t)
 end
end
function M.keepLilies(x,z,bank,dock)
 return not dock and C.field((x+4)/32,(z+4)/32,4603)>(bank and .43 or .66)
end
function M.shore(x,z,h,e,emit)
 if e.dock then return end
 local G=C.builder(x,z,emit);local patch=C.field((x+4)/24,(z+4)/24,4604)
 for _,d in ipairs({{'w',1,4},{'e',7,4},{'n',4,1},{'s',4,7}})do if e[d[1]] then
  local a,b=x+d[2],z+d[3]
  -- Shallow dark bank stones interrupt the hard water/land seam.
  if patch>.44 then
   G.box(a-.8,b-.55,a+.8,b+.55,h-.55,h+.12,'body',.62)
   G.flat(a-.6,b-.4,a+.45,b+.3,h+.13,'moss',.65)
  end
  if patch>.56 then
   for j=0,5 do
    local u=a+(C.hash(x+j,z,4605)-.5)*1.1
    local v=b+(C.hash(x,z+j,4606)-.5)*1.1
    local high=2.4+C.hash(x+j,z,4607)*2.4
    G.blade(u,v,h-.18,high,.10,.4,j*1.7,'leaf',.82+j*.025)
    if j%3==0 then G.box(u-.09,v-.09,u+.09,v+.09,h+high-.55,h+high-.05,'cinder',.64)end
   end
  end
 end end
end
function M.paving(x,z,h,c,emit)
 local G=C.builder(x,z,emit)
 -- Sparse wear and drainage belong to terrace edges, not the garden crossing.
 if c.inCourt then return end
 for _,d in ipairs({{'w',.9,4},{'e',7.1,4},{'n',4,.9},{'s',4,7.1}})do if c.water and c.water[d[1]] then
  local a,b=x+d[2],z+d[3]
  if C.hash(x,z,4608)>.6 and not c.lamp and not c.bin and not c.bench and not c.dockDetail then
   G.flat(a-.65,b-1.15,a+.65,b+1.15,h+.245,'shadow',.56)
   for j=0,4 do G.flat(a-.55,b-1+j*.43,a+.55,b-.88+j*.43,h+.25,'body',.67)end
  end
  -- Irregular subdued damp patches at exposed waterfront paving.
  if C.field(x/20,z/20,4609)>.54 then
   G.face({{a-.55,h+.237,b-1.9},{a+.5,h+.237,b-1.2},{a+.65,h+.237,b+1.5},{a-.5,h+.237,b+1.9}},'body',.65)
  end
 end end
 if not c.stone and C.hash(x,z,4610)>.8 then
  local a,b=x+2,z+3
  G.face({{a,h+.205,b},{a+.09,h+.205,b-.04},{a+1.3,h+.205,b+1.3},{a+1.22,h+.205,b+1.33}},'shadow',.7)
 end
end
function M.dock(x,z,h,f,emit)
 local G=C.builder(x,z,emit);local a,b=f.x,f.z
 -- Low cast-metal mooring post with a broad head and mounting plate.
 G.box(a-.85,b-.85,a+.85,b+.85,h+.25,h+.52,'shadow',.64)
 G.box(a-.36,b-.36,a+.36,b+.36,h+.52,h+2.75,'shadow',.65)
 G.box(a-.7,b-.6,a+.7,b+.6,h+2.5,h+3.05,'shadow',.8)
 for _,dx in ipairs({-.65,.65})do for _,dz in ipairs({-.65,.65})do
  G.box(a+dx-.07,b+dz-.07,a+dx+.07,b+dz+.07,h+.52,h+.63,'light',.65)
 end end
 -- Flat rope coil beside the post, small enough to remain inside this tile.
 local ca,cb=x+4,z+4
 for j=0,2 do ring(G,ca,cb,h+.31+j*.045,1.55-j*.32,.22,'sand',.78+j*.035)end
 if f.sign then
  local q,r=x+1.25,z+1.25
  G.box(q-.15,r-.15,q+.15,r+.15,h+.25,h+5.5,'wood',.8)
  G.box(q-.95,r-.22,q+.95,r+.22,h+4.1,h+5.55,'wood',.95)
  -- Pale directional arrow; no unreadable generated text.
  G.face({{q-.65,h+4.78,r-.23},{q+.2,h+4.78,r-.23},{q+.2,h+5.0,r-.23},{q-.65,h+5.0,r-.23}},'light',1)
  G.face({{q+.15,h+4.5,r-.23},{q+.7,h+4.9,r-.23},{q+.15,h+5.25,r-.23}},'light',1)
 end
end
function M.anchor(x,z,h,f,emit)
 local G=C.builder(x,z,emit);local a,b=f.x,f.z
 G.box(a-2.5,b-1.8,a+2.5,b+1.8,h+.25,h+.75,'body',.85)
 G.box(a-2.1,b-1.4,a+2.1,b+1.4,h+.75,h+2.1,'body',.94)
 G.box(a-2.3,b-1.55,a+2.3,b+1.55,h+2.1,h+2.45,'sand',.95)
 G.box(a-.2,b-.2,a+.2,b+.2,h+3.1,h+8.7,'shadow',.65)
 G.box(a-1.75,b-.25,a+1.75,b+.25,h+7.0,h+7.4,'shadow',.75)
 -- Ring in a vertical plane, with front, back and side faces.
 for j=0,11 do local u,v=j*math.pi/6,(j+1)*math.pi/6
  local function p(t,r,z0)return {a+math.cos(t)*r,h+9.25+math.sin(t)*r,b+z0}end
  G.face({p(u,.85,-.23),p(v,.85,-.23),p(v,.5,-.23),p(u,.5,-.23)},'shadow',.8)
  G.face({p(u,.5,.23),p(v,.5,.23),p(v,.85,.23),p(u,.85,.23)},'shadow',.8)
  G.face({p(u,.85,-.23),p(u,.85,.23),p(v,.85,.23),p(v,.85,-.23)},'shadow',.7)
 end
 for _,side in ipairs({-1,1})do
  local shape={{0,3.1},{side*1.8,3.7},{side*2.8,5.1},{side*2.1,4.85},{side*2.35,5.6},{side*3.05,4.3},{side*2.45,3.25},{side*.6,2.7}}
  local front,back={},{}
  for _,q in ipairs(shape)do front[#front+1]={a+q[1],h+q[2],b-.25};table.insert(back,1,{a+q[1],h+q[2],b+.25})end
  for i,vtx in ipairs(front)do local nxt=front[i%#front+1]
   G.face({vtx,{vtx[1],vtx[2],b+.25},{nxt[1],nxt[2],b+.25},nxt},'shadow',.62)
  end
  -- Emit individually triangulated arms as narrow connected segments instead of a concave fan.
  for i=1,3 do
   local j=#front-i+1
   G.face({front[i],front[i+1],front[j-1],front[j]},'shadow',.72)
   local q={};for _,vtx in ipairs({front[j],front[j-1],front[i+1],front[i]})do q[#q+1]={vtx[1],vtx[2],b+.25}end
   G.face(q,'shadow',.72)
  end
 end
end
return M
