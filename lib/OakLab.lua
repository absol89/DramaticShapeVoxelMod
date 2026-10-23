-- TEST38: Professor Oak's Pokemon Research Laboratory, redesigned from scratch.
-- Same footprint, door and collision as the source map; only the look changes.
--   * A tall white central hall with a front-facing gable, a big Poke Ball in
--     the pediment and a two-line "PROF. OAK'S / POKEMON LAB" plaque.
--   * A west research wing with a white observatory dome, solar array and a
--     satellite dish on its flat roof.
--   * An east greenhouse wing under a ribbed glass roof.
--   * Blue standing-seam roofs, steel-grey trim, stone plinth, tall lab
--     windows that glow at night, planters, lamps and a glass entrance canopy.
local V=...
local M={REVISION='oak-lab-38'}
local pi,min,max,cos,sin=math.pi,math.min,math.max,math.cos,math.sin
-- 5x7 stroke font: each glyph is a list of polylines on a 4x6 grid.
local strokes={
 A={{{0,0},{0,4},{2,6},{4,4},{4,0}},{{0,3},{4,3}}},
 B={{{0,0},{0,6},{3,6},{4,5},{4,4},{3,3},{0,3}},{{3,3},{4,2},{4,1},{3,0},{0,0}}},
 C={{{4,5},{3,6},{1,6},{0,5},{0,1},{1,0},{3,0},{4,1}}},
 E={{{4,6},{0,6},{0,0},{4,0}},{{0,3},{3,3}}},
 F={{{4,6},{0,6},{0,0}},{{0,3},{3,3}}},
 H={{{0,0},{0,6}},{{4,0},{4,6}},{{0,3},{4,3}}},
 K={{{0,0},{0,6}},{{4,6},{0,2}},{{1.4,3.4},{4,0}}},
 L={{{0,6},{0,0},{4,0}}},
 M={{{0,0},{0,6},{2,3},{4,6},{4,0}}},
 N={{{0,0},{0,6},{4,0},{4,6}}},
 O={{{1,0},{0,1},{0,5},{1,6},{3,6},{4,5},{4,1},{3,0},{1,0}}},
 P={{{0,0},{0,6},{3,6},{4,5},{4,4},{3,3},{0,3}}},
 R={{{0,0},{0,6},{3,6},{4,5},{4,4},{3,3},{0,3}},{{2,3},{4,0}}},
 S={{{4,5},{3,6},{1,6},{0,5},{0,4},{1,3},{3,3},{4,2},{4,1},{3,0},{1,0},{0,1}}},
 T={{{0,6},{4,6}},{{2,6},{2,0}}},
 ['.']={{{1.6,0},{2.4,0}}},
 ["'"]={{{2,6},{2,4.6}}},
 [' ']={},
}
function M.text(K,str,cx,y,z,scale,width,mat)
 local adv=5.4;local left=cx-(#str*adv-1.4)*scale/2
 for i=1,#str do local ch=str:sub(i,i);local g=strokes[ch]or{}
  local ox=left+(i-1)*adv*scale
  if ch=='E'and str:sub(i-4,i)=='POKEM'then
   -- The accent on POKeMON: a short raised tick above the E.
   K.beam({ox+1.6*scale,y+6.9*scale,z},{ox+2.8*scale,y+7.7*scale,z},width,mat,1.1)
  end
  for _,line in ipairs(g)do
   for j=1,#line-1 do local a,b=line[j],line[j+1]
    local pa={ox+a[1]*scale,y+a[2]*scale,z};local pb={ox+b[1]*scale,y+b[2]*scale,z}
    if a[1]==b[1]and a[2]==b[2]then pb={pb[1]+width*.5,pb[2],pb[3]}end
    K.beam(pa,pb,width,mat,1.1)
   end
  end
 end
end
local function disc(K,x,y,z,r,a0,a1,mat,tone,n)
 n=n or 24
 for i=0,n-1 do local a=a0+(a1-a0)*i/n;local b=a0+(a1-a0)*(i+1)/n
  K.face({x,y,z},{x+r*cos(a),y+r*sin(a),z},{x+r*cos(b),y+r*sin(b),z},{x+r*cos(b),y+r*sin(b),z},mat,tone or 1)
 end
end
-- A Poke Ball relief facing +z: red top, white bottom, black band and button.
function M.pokeball(K,x,y,z,r)
 disc(K,x,y,z,r+.55,0,2*pi,'ktSteel',1.05,32)
 disc(K,x,y,z+.12,r,0,pi,'red',1.08,20)
 disc(K,x,y,z+.12,r,pi,2*pi,'white',1.05,20)
 K.box(x-r,y-r*.11,z+.1,x+r,y+r*.11,z+.32,'dark',.8)
 disc(K,x,y,z+.34,r*.34,0,2*pi,'dark',.8,20)
 disc(K,x,y,z+.42,r*.22,0,2*pi,'white',1.15,20)
 disc(K,x,y,z+.46,r*.12,0,2*pi,'white',1.3,12)
end
-- Hemispherical dome with a dark observing slit facing south.
local function dome(K,x,y,z,r,mat)
 local rings,seg=6,20
 for i=0,rings-1 do local t0,t1=i/rings*pi/2,(i+1)/rings*pi/2
  for j=0,seg-1 do local a0,a1=j/seg*2*pi,(j+1)/seg*2*pi
   local function p(t,a)return{x+r*cos(t)*sin(a),y+r*sin(t),z+r*cos(t)*cos(a)}end
   local slit=(j==0 or j==seg-1)
   K.face(p(t0,a0),p(t0,a1),p(t1,a1),p(t1,a0),slit and 'dark'or mat,slit and .6 or(.86+.16*sin(t1)))
  end
 end
 -- Slit rails.
 for _,a in ipairs({-2*pi/seg,2*pi/seg})do
  local pts={};for i=0,rings do local t=i/rings*pi/2;pts[#pts+1]={x+(r+.12)*cos(t)*sin(a),y+(r+.12)*sin(t),z+(r+.12)*cos(t)*cos(a)}end
  for i=1,#pts-1 do K.beam(pts[i],pts[i+1],.28,'ktSteel',1.05)end
 end
end
local function cylinder(K,x,y0,y1,z,r,mat,n)
 n=n or 16
 for i=0,n-1 do local a,b=i*2*pi/n,(i+1)*2*pi/n
  K.face({x+r*cos(a),y0,z+r*sin(a)},{x+r*cos(b),y0,z+r*sin(b)},{x+r*cos(b),y1,z+r*sin(b)},{x+r*cos(a),y1,z+r*sin(a)},mat,.88+.12*cos(a-.6))
  K.face({x,y1,z},{x+r*cos(b),y1,z+r*sin(b)},{x+r*cos(a),y1,z+r*sin(a)},{x+r*cos(a),y1,z+r*sin(a)},mat,1.04)
 end
end
-- Parabolic dish on a mast, aimed up toward the southern sky.
local function satellite(K,x,y,z,r)
 cylinder(K,x,y,y+5,z,.45,'ktSteel',8)
 local cx,cy,cz=x,y+6.2,z
 local tilt=.85 -- radians from vertical, facing +z
 local function frame(u,v,d)
  -- dish local axes: n=(0,cos t,sin t) facing up/south, e1=(1,0,0), e2=(0,sin t,-cos t)
  return{cx+u,cy+v*sin(tilt)+d*cos(tilt),cz-v*cos(tilt)+d*sin(tilt)}
 end
 local rings,seg=4,18
 for i=0,rings-1 do local r0,r1=r*i/rings,r*(i+1)/rings
  for j=0,seg-1 do local a0,a1=j/seg*2*pi,(j+1)/seg*2*pi
   local function p(rr,a)return frame(rr*cos(a),rr*sin(a),.18*rr*rr/r)end
   K.face(p(r0,a0),p(r1,a0),p(r1,a1),p(r0,a1),'white',.92+.1*i/rings)
  end
 end
 local feed=frame(0,0,r*.75)
 for _,a in ipairs({0,2*pi/3,4*pi/3})do K.beam(frame(r*.85*cos(a),r*.85*sin(a),.15*r),feed,.16,'ktSteel',1)end
 K.box(feed[1]-.35,feed[2]-.35,feed[3]-.35,feed[1]+.35,feed[2]+.35,feed[3]+.35,'dark',.8)
 K.beam({x,y+4.6,z},frame(0,0,.05),.5,'ktSteel',1)
end
-- Turn a run of emitted quads into night-lit surfaces (window-style glow).
local function glow(out,from,tone)
 for i=from,#out do local q=out[i]
  local t=q.shade;if type(t)=='table'then t=(t[1]+t[2]+t[3]+t[4])/4 end
  q.shade=(tone or t or 1)+64;q.referenceGlass=true
 end
end
local function shrub(K,x,y,z,s,mat)
 for i=0,6 do local a=i*2*pi/7
  K.leaf({x,y,z},{x+cos(a)*1.4*s,y+(1.4+(i%3)*.5)*s,z+sin(a)*1.1*s},.75*s,i%2==0 and(mat or'leaf')or'green')
 end
end
function M.model(s,c)
 local R=V.require('KantoRegionalKit').new(s,setmetatable({name='laboratory',wall='ktPlaster',trim='ktSteel',base='stone',roof='ktMarine',lab=true,label=false},{__index=c}))
 local K=R.K
 local x0,x1,z0,z1=s.x0,s.x1,s.z0,s.z1
 local u=(x0+x1)/2
 for _,d in ipairs(s.doors or{})do if(d.side or'front')=='front'then u=d.u or d.x;break end end
 -- The hall is centred on the source door and keeps 10 units each side of it.
 local hx0,hx1=max(x0+18,u-17),min(x1-18,u+17)
 local HH,WH=38,26
 local hall=R.volume({x0=hx0,x1=hx1,h=HH,wall='ktPlaster',trim='ktSteel',base='stone',roof='ktMarine',
  profile={{0,0},{.5,13},{1,0}},window=10,levels={{9,24}}})
 local west=R.volume({x1=hx0,h=WH,wall='ktPlaster',trim='ktSteel',base='stone',roof='ktSteel',window=11,levels={{7,21}},parapet=2.2})
 local east=R.volume({x0=hx1,h=WH,wall='ktPlaster',trim='ktSteel',base='stone',roof='ktMarine',window=11,levels={{7,21}},
  profile={{0,0},{.5,9},{1,0}},roofGlazing={[1]=true,[2]=true}})
 -- Hall front: cornice band, pediment, Poke Ball and the plaque.
 local E=hall.elevations.front
 E.box(hx0,HH-.7,hx1,HH+.2,.04,1.1,'ktSteel',1.05)
 M.pokeball(K,u,HH+5.4,z1+.35,3.9)
 local pw=min(28,hx1-hx0-5)
 K.box(u-pw/2,29.3,z1+.1,u+pw/2,36.7,z1+.65,'navy',.95)
 K.box(u-pw/2-.35,29.0,z1+.08,u+pw/2+.35,29.3,z1+.85,'ktSteel',1.05)
 K.box(u-pw/2-.35,36.7,z1+.08,u+pw/2+.35,37.0,z1+.85,'ktSteel',1.05)
 local mark=#R.G.out+1
 M.text(K,"PROF. OAK'S",u,33.45,z1+.82,.42,.34,'white')
 M.text(K,'POKEMON LAB',u,29.85,z1+.82,.42,.34,'white')
 glow(R.G.out,mark,1.15)
 -- Glass entrance canopy on steel brackets, clear of the walking cell.
 local cw=9.5
 K.box(u-cw,26.6,z1+.2,u+cw,27.0,z1+4.6,'ktSteel',1.05)
 K.face({u-cw+.3,27.02,z1+.4},{u+cw-.3,27.02,z1+.4},{u+cw-.3,27.02,z1+4.4},{u-cw+.3,27.02,z1+4.4},'ktGlass',1.1)
 for _,x in ipairs({u-cw+1,u+cw-1})do K.beam({x,27,z1+4.3},{x,31.5,z1+.3},.22,'ktSteel',1)end
 -- Fluted pilasters framing the hall.
 for _,x in ipairs({hx0+.2,hx1-1.8})do
  K.box(x,0,z1-.2,x+1.6,HH-.7,z1+.7,'white',1.02)
  K.box(x-.25,0,z1-.25,x+1.85,5.8,z1+.95,'stone',.95)
  for k=0,2 do K.box(x+.25+k*.45,6.5,z1+.7,x+.45+k*.45,HH-2,z1+.82,'ktPearl',.9)end
 end
 -- Wings: cornices, downspouts and planters under the windows.
 for _,v in ipairs({west,east})do
  local b=v.bounds;local F=v.elevations.front
  F.box(b.x0,WH-.6,b.x1,WH+.15,.04,.9,'ktSteel',1.05)
  for _,x in ipairs({b.x0+.9,b.x1-.9})do
   if math.abs(x-hx0)>2 and math.abs(x-hx1)>2 then
    K.box(x-.35,0,z1+.3,x+.35,WH-.5,z1+.95,'ktSteel',.85)
   end
  end
  for _,o in ipairs(F.openings)do if not o.door then
   local l,r=o.u-o.w/2,o.u+o.w/2
   K.box(l-.3,0,z1+.15,r+.3,2.6,z1+2.0,'ktBrick',.95)
   K.box(l-.45,2.6,z1+.05,r+.45,2.95,z1+2.15,'stone',1.05)
   for x=l+1.2,r-1,2.4 do shrub(K,x,2.9,z1+1.1,.75,(math.floor(x)%2==0)and'flower'or'leaf')end
  end end
 end
 -- West roof: observatory dome on a drum, solar array, satellite dish.
 do
  local b=west.bounds;local cx=(b.x0+b.x1)/2;local top=WH+.3
  local dz=z0+(z1-z0)*.62
  cylinder(K,cx,top,top+3.2,dz,7.6,'ktPearl',24)
  K.box(cx-8.2,top+3.2,dz-8.2,cx+8.2,top+3.5,dz+8.2,'ktSteel',1.05)
  dome(K,cx,top+3.5,dz,7.4,'white')
  -- Solar panels in two tilted rows at the back.
  for row=0,1 do local zz=z0+5+row*9
   for x=b.x0+2.5,b.x1-6,6.2 do
    local yb,yt=top+.6,top+3.4
    K.face({x,yb,zz+5},{x+5.6,yb,zz+5},{x+5.6,yt,zz},{x,yt,zz},'navy',1.25)
    for k=1,2 do local xx=x+k*5.6/3;K.beam({xx,yb+.02,zz+5.02},{xx,yt+.02,zz+.02},.12,'ktSteel',1)end
    K.beam({x,yb+1.4,zz+2.5},{x+5.6,yb+1.4,zz+2.5},.12,'ktSteel',1)
    for _,xx in ipairs({x+.4,x+5.2})do K.box(xx-.15,top,zz-.15,xx+.15,yt,zz+.15,'ktSteel',.9)end
   end
  end
  satellite(K,b.x0+4.5,top,dz+11,3.4)
 end
 -- East roof: white glazing ribs, ridge vent and a little rooftop weather station.
 do
  local b=east.bounds;local W=b.x1-b.x0;local mid=(b.x0+b.x1)/2;local over=.7
  for z=b.z0-over,b.z1+over+.01,4.2 do
   K.beam({b.x0-over,WH-.35+.25,z},{mid,WH+9+.3,z},.28,'white',1.1)
   K.beam({mid,WH+9+.3,z},{b.x1+over,WH-.35+.25,z},.28,'white',1.1)
  end
  K.box(mid-1.4,WH+9,b.z0+2,mid+1.4,WH+10.4,b.z1-2,'white',1.05)
  for z=b.z0+4,b.z1-4,6 do K.box(mid-1.5,WH+9.1,z,mid+1.5,WH+10.1,z+2.2,'ktSteel',.85)end
 end
 -- Hall roof: ridge cap, weather vane with anemometer cups at the back.
 do
  local ry=HH+13.3
  K.box(u-.6,ry-.5,z0-.7,u+.6,ry+.25,z1+.7,'ktSteel',1.08)
  local vz=z0+6
  K.box(u-.25,ry,vz-.25,u+.25,ry+8,vz+.25,'ktSteel',1)
  for i=0,2 do local a=i*2*pi/3
   local tip={u+2.2*cos(a),ry+7.4,vz+2.2*sin(a)}
   K.beam({u,ry+7.4,vz},tip,.12,'ktSteel',1)
   K.box(tip[1]-.45,tip[2]-.45,tip[3]-.45,tip[1]+.45,tip[2]+.45,tip[3]+.45,'red',1.05)
  end
  K.beam({u,ry+5.6,vz-2.6},{u,ry+5.6,vz+2.6},.14,'ktSteel',1)
  K.face({u,ry+5.0,vz-2.6},{u,ry+6.4,vz-2.6},{u,ry+5.7,vz-4.4},{u,ry+5.7,vz-4.4},'gold',1.1)
 end
 return R.G.out
end
return M
