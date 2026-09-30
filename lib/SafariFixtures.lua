-- Compact reserve amenities. All templates fit a single existing blocked cell.
local V=...;local M={}
local function ring(G,x,y,z,r,mat)
 for i=0,15 do local a,b=i*math.pi/8,(i+1)*math.pi/8
  G.face({x+math.cos(a)*r,y,z+math.sin(a)*r},{x+math.cos(b)*r,y,z+math.sin(b)*r},{x+math.cos(b)*(r-.2),y,z+math.sin(b)*(r-.2)},{x+math.cos(a)*(r-.2),y,z+math.sin(a)*(r-.2)},mat,.95)
 end
end
function M.model(kind,variant)
 local G=V.require('CityMesh').new({.5/128,.5/48})
 if kind=='rangerBoard'then
  for _,x in ipairs({-5,5})do G.box(x-.5,0,-1,x+.5,14,0,'wood',.9)end
  G.box(-5.8,6,-1.25,5.8,13.8,.5,'oak',.94)
  G.box(-5,6.8,.51,5,13,.6,'sage',.97)
  G.text('SAFARI',0,11.1,.63,.31,'cream')
  -- A raised miniature trail diagram, ponds and marked ranger destination.
  G.beam({-3.8,8,.7},{-.5,9,.7},.22,'cream',1)
  G.beam({-.5,9,.7},{2,8,.7},.22,'cream',1)
  G.beam({2,8,.7},{3.7,10.5,.7},.22,'cream',1)
  G.box(-3.5,9.7,.65,-1.6,10.6,.72,'blue',.9)
  G.box(2.7,9.4,.65,3.6,10.3,.8,'gold',1)
  G.face({-6.5,14.2,-2.5},{6.5,14.2,-2.5},{6.5,15.7,-.4},{-6.5,15.7,-.4},'wood',.94)
  G.face({-6.5,15.7,-.4},{6.5,15.7,-.4},{6.5,14.2,1.7},{-6.5,14.2,1.7},'wood',.85)
 elseif kind=='bench'then
  for _,x in ipairs({-4.5,4.5})do
   for _,z in ipairs({-1.8,1.8})do G.box(x-.4,0,z-.4,x+.4,4,z+.4,'wood',.87)end
   G.box(x-.3,3,-2.3,x+.3,8,-1.7,'wood',.9)
   G.beam({x,1,-1.6},{x,3,1.5},.4,'oak',.9)
  end
  for z=-2,1.7,1.2 do G.box(-6,3.6,z,6,4.1,z+.9,'oak',.9+(z%2)*.035)end
  for y=5,7.5,1.2 do G.box(-6,y,-2.3,6,y+.85,-1.7,'wood',1)end
  for _,x in ipairs({-5.4,5.4})do G.box(x-.25,4,-1.8,x+.25,5.8,1.6,'wood',.9);G.box(x-.6,5.8,-2,x+.6,6.1,2,'oak',1)end
 elseif kind=='bin'then
  G.box(-2.5,.15,-2.5,2.5,6.8,2.5,'dark',.88)
  for x=-2.5,2.2,1.15 do G.box(x,0,-2.6,x+.8,6.7,-2.45,'wood',.95);G.box(x,0,2.45,x+.8,6.7,2.6,'wood',.92)end
  G.box(-2.8,6.6,-2.8,2.8,7.2,2.8,'sage',.98)
  G.box(-1.6,7.21,-1.3,1.6,7.3,1.3,'dark',.65)
  G.box(-1.5,3.3,2.61,1.5,4.8,2.65,'cream',.9)
 elseif kind=='waterStation'then
  G.box(-4,0,-3,4,.45,3,'slate',.97)
  G.box(-1.6,.45,-1.6,1.6,7,1.6,'wood',.95)
  G.box(-.4,7,-.4,.4,10,.4,'dark',.9)
  G.box(-.45,8.8,0,.45,9.3,2.2,'dark',.96)
  G.box(-.4,8.4,1.5,.4,9.1,2.2,'dark',.96)
  G.box(-2.8,.45,1.2,2.8,1.7,3.6,'slate',.85)
  G.box(-2.25,1.71,1.7,2.25,1.75,3.1,'blue',.94)
  G.box(-2,5,-1.9,2,6.4,-1.65,'cream',.96)
 elseif kind=='lookout'then
  G.box(-3.5,0,-3.5,3.5,.6,3.5,'slate',.94)
  G.box(-.5,.6,-.5,.5,9,.5,'wood',.92)
  G.beam({-3,1,0},{0,6,0},.5,'dark',.95);G.beam({3,1,0},{0,6,0},.5,'dark',.95)
  G.box(-2.6,8.6,-1,2.6,9.2,1,'dark',1)
  for _,x in ipairs({-1.8,1.8})do
   G.box(x-.8,9,-2,x+.8,10.8,2.3,'wood',.92)
   G.box(x-.85,9.05,2.3,x+.85,10.75,2.6,'dark',.9)
   G.box(x-.55,9.35,2.61,x+.55,10.45,2.65,'glass',.95)
  end
 elseif kind=='supplies'then
  for i=0,1 do local x=-4+i*6
   G.box(x-2,.1,-2.5,x+2,4.4+i*1.2,2.5,'oak',.88+i*.1)
   for _,z in ipairs({-2.56,2.51})do
    for y=1,4,1.1 do G.box(x-2,y,z,x+2,y+.13,z+.08,'wood',.7)end
    G.beam({x-1.7,.6,z},{x+1.7,4+i,z},.45,'wood',.85)
   end
   for _,xx in ipairs({x-1.6,x+1.3})do G.box(xx,.1,-2.6,xx+.3,4.4+i*1.2,2.6,'dark',.8)end
  end
  for r=.7,1.7,.3 do ring(G,-3,4.55,0,r,'cream')end
 elseif kind=='fieldDesk'then
  for _,x in ipairs({-4.7,4.7})do for _,z in ipairs({-2.3,2.3})do G.box(x-.4,0,z-.4,x+.4,5.5,z+.4,'wood',.86)end end
  for z=-3,2.9,1.4 do G.box(-6,5.5,z,6,6,z+1.15,'oak',.93)end
  G.box(-3.5,6.02,-1.8,1.5,6.1,1.8,'cream',.9)
  G.box(-2.5,6.11,-.8,.5,6.14,.5,'sage',1)
  G.box(2.5,6,-1.4,4,7.1,.4,'dark',.9)
  G.box(2.8,7.11,-1.1,3.7,7.16,0,'glass',.95)
  G.box(-4,6,2,-1,6.6,2.6,'wood',1)
 elseif kind=='habitatLog'then
  -- Split, weathered log with concentric end rings; useful cover, no flowers.
  local n=10
  for i=0,n-1 do local a,b=i*2*math.pi/n,(i+1)*2*math.pi/n
   G.face({-6,2.5+math.cos(a)*2.3,math.sin(a)*2.3},{6,2.5+math.cos(a)*2.3,math.sin(a)*2.3},{6,2.5+math.cos(b)*2.3,math.sin(b)*2.3},{-6,2.5+math.cos(b)*2.3,math.sin(b)*2.3},'forestBark',.85+i*.013)
   G.face({6,2.5,0},{6,2.5+math.cos(b)*2.3,math.sin(b)*2.3},{6,2.5+math.cos(a)*2.3,math.sin(a)*2.3},{6,2.5,0},'oak',.9)
  end
  G.beam({-2,3,0},{-1,6,-1.8},.7,'forestBark',.9)
 end
 -- Fixed local footprint, rotate the entire object towards its usable approach.
 return G.out
end
function M.place(kind,variant,x,z,angle)
 local c,s=math.cos(angle),math.sin(angle);local out=M.model(kind,variant)
 for _,q in ipairs(out)do for i=1,4 do local p=q[i];local u,v=p[1],p[3];q[i]={x+u*c-v*s,p[2],z+u*s+v*c} end end
 return out
end
return M
