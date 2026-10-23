-- Seasonal display models. TEST26: same designs at the Battle Art camera, with
-- detail sized to what the camera can resolve (templates for repeated parts,
-- no hidden caps, fewer facets on sub-unit pieces), plus new Halloween,
-- Harvest, doorway and lamp-post displays.
local G=...
local M={};local pi=math.pi
local palettes={
 classic={'red','gold','green','warm'},royal={'crimson','gold','ivory','warm'},
 frost={'blue','silver','cyan','white'},woodland={'copper','ivory','green','warm'},
 lavender={'purple','silver','lilac','white'},electric={'gold','blue','red','warm'},
 spooky={'orange','purple','slime','warm'},spectral={'purple','lilac','spirit','violetGlow'},
 harvest={'copper','gold','crimson','warm'},pastel={'pink','mint','lilac','egg'},
 patriot={'red','ivory','blue','gold'}}
function M.palette(name)return palettes[name]or palettes.classic end
-- Closed ring of chained tubes. Joints hide each segment's ends: no caps.
local function ring(g,x,y,z,r,t,mat,n,vertical,sides,shade)
 n=n or 24
 for i=0,n-1 do local a,b=i*2*pi/n,(i+1)*2*pi/n
  local p=vertical and {x+math.cos(a)*r,y+math.sin(a)*r,z}or{x+math.cos(a)*r,y,z+math.sin(a)*r}
  local q=vertical and {x+math.cos(b)*r,y+math.sin(b)*r,z}or{x+math.cos(b)*r,y,z+math.sin(b)*r}
  G.tube(g,p,q,t,mat,sides or 4,nil,shade,false)
 end
end
M.ring=ring
-- Polyline of chained tubes; only the two free ends may be capped.
local function chain(g,points,r,mat,sides,shade)
 for i=2,#points do G.tube(g,points[i-1],points[i],r,mat,sides or 4,nil,shade,false)end
end
M.chain=chain
local function buildBow(g,x,y,z,s,mat)
 for side=-1,1,2 do
  local pts={}
  for i=0,8 do local t=i*2*pi/8;pts[#pts+1]={x+side*(.30+1.05*(1-math.cos(t)))*s,y+math.sin(t)*.64*s,z+math.sin(t)*.13*s}end
  chain(g,pts,.22*s,mat,4)
  G.quad(g,{x+side*.1*s,y,z},{x+side*.6*s,y-.1*s,z+.08*s},{x+side*1.3*s,y-2.1*s,z+.17*s},{x+side*.5*s,y-1.75*s,z+.12*s},mat)
 end
 G.sphere(g,x,y,z+.18*s,.5*s,.38*s,.3*s,mat,6,4)
end
local bows={}
function M.bow(g,x,y,z,s,mat)
 local template=bows[mat]
 if not template then template=G.new();buildBow(template,0,0,0,1,mat);bows[mat]=template end
 G.instance(g,template,x,y,z,s)
end
function M.gift(g,x,y,z,w,h,d,mat,ribbon,seed)
 local q=G.new();G.box(q,0,0,0,w,h,d,mat)
 G.box(q,0,h-.13,0,w+.4,.44,d+.4,mat)
 G.box(q,0,.02,0,w*.14,h+.45,d+.47,ribbon)
 G.box(q,0,.02,0,w+.46,h+.30,d*.13,ribbon)
 M.bow(q,0,h+.50,0,math.min(w,d)*.19,ribbon)
 if seed%2==0 then
  G.box(q,w*.23,h+.24,d*.20,w*.22,.16,d*.19,'ivory',.18)
 end
 G.append(g,G.translate(q,x,y,z,(G.hash(seed,4)-.5)*.7));g.props=g.props+1
end
local function buildOrnament(g,mat,kind)
 G.sphere(g,0,0,0,1,1,1,mat,7,5)
 G.tube(g,{0,.91,0},{0,1.20,0},.24,'gold',5,nil,nil,false)
 if kind%3==0 then ring(g,0,0,0,1.007,.068,'gold',10,false,3)
 elseif kind%3==1 then
  for j=0,3 do local a=j*2*pi/4+.4;G.sphere(g,math.cos(a)*.91,.20,math.sin(a)*.91,.10,.10,.10,'ivory',4,3)end
 end
 g.ornaments=g.ornaments+1
end
local ornaments={}
function M.ornament(g,x,y,z,r,mat,kind)
 local key=mat..':'..(kind%3);local template=ornaments[key]
 if not template then template=G.new();buildOrnament(template,mat,kind);ornaments[key]=template end
 G.instance(g,template,x,y,z,r)
end
function M.tree(opts)
 opts=opts or {};local g=G.new();local H,R=opts.height or 100,opts.radius or 28
 local p=M.palette(opts.palette);local rich=opts.rich~=false;local seed=opts.seed or 1
 local mini=opts.mini
 local function radius(y)return R*math.max(.015,1-(y-H*.07)/(H*.91))^.90 end
 G.disc(g,0,.10,0,R*.94,'crimson',mini and 16 or 32)
 G.tube(g,{0,0,0},{0,H*.95,0},R*.09,'bark',mini and 6 or 10,R*.018)
 -- Irregular branch skirts, with independent needle clusters at their tips.
 local tiers=mini and 7 or rich and 13 or 10
 local count=mini and 20 or 36
 local branches=mini and 7 or rich and 15 or 10
 for j=0,tiers-1 do
  local y=H*.10+j*(H*.81/tiers);local r=radius(y)
  local ytop=math.min(H*.978,y+H*(mini and .19 or .145));local rtop=r*.32
  for i=0,count-1 do
   local a,b=i*2*pi/count,(i+1)*2*pi/count
   local function edge(t,k)
    local noise=G.hash(i+k,j,seed);local rad=r*(.91+noise*.13)
    return {math.cos(t)*rad,y+(noise-.5)*H*.025,math.sin(t)*rad}
   end
   local a0,b0=edge(a,0),edge(b,1)
   local a1={math.cos(a)*rtop,ytop,math.sin(a)*rtop};local b1={math.cos(b)*rtop,ytop,math.sin(b)*rtop}
   G.quad(g,a0,a1,b1,b0,i%4==0 and 'pineLight'or 'pine')
   G.tri(g,{0,y-1.1,0},a0,b0,'pineDark')
  end
  for i=0,branches-1 do
   local a=i*2*pi/branches+j*.57
   local a0={math.cos(a)*r*.22,y+H*.052,math.sin(a)*r*.22}
   local b0={math.cos(a)*r*.97,y+.2,math.sin(a)*r*.97}
   G.tube(g,a0,b0,r*.022,'bark',4,r*.009,nil,false)
   for t=1,mini and 2 or 3 do
    local f=.32+t*.19;local xx,zz=b0[1]*f,b0[3]*f
    G.tube(g,{xx,y+H*.035,zz},{xx+math.cos(a)*r*.28,y+H*.01,zz+math.sin(a)*r*.28},r*.13*(1-t*.13),t%2==0 and 'pineLight'or 'pine',4,.03)
   end
  end
 end
 G.tube(g,{0,H*.86,0},{0,H,0},R*.13,'pineLight',8,.01)
 -- A real cable spirals around the foliage. Bulbs are separate closed meshes.
 local loops=mini and 5 or rich and 8 or 6;local steps=mini and 110 or rich and 240 or 180;local previous
 for i=0,steps do
  local f=i/steps;local y=H*.15+f*H*.80;local a=f*2*pi*loops;local r=radius(y)*1.015+.35
  local pos={math.cos(a)*r,y,math.sin(a)*r}
  if previous then G.tube(g,previous,pos,.11,'black',3,nil,nil,false)end
  G.bulb(g,pos[1],pos[2]-.32,pos[3],math.max(.30,H*.0045),p[(i%4)+1],opts.twinkle)
  previous=pos
 end
 local orn=mini and 36 or rich and 150 or 90
 for i=1,orn do
  local f=(i-.5)/orn;local y=H*.14+f*H*.80;local a=i*2.399963+seed*.2
  local r=radius(y)*1.02;local size=H*(.009+G.hash(i,seed)*.006)*(mini and 1.25 or 1)
  M.ornament(g,math.cos(a)*r,y,math.sin(a)*r,size,p[(i%3)+1],i)
 end
 G.tube(g,{0,H-1,0},{0,H+3,0},.28,'gold',6)
 G.star(g,0,H+H*.034,0,H*.057,'gold')
 local gifts=mini and 4 or rich and 15 or 9
 for i=1,gifts do local a=i*2*pi/gifts;local r=R*(.64+G.hash(i,seed,2)*.30)
  M.gift(g,math.cos(a)*r,.25,math.sin(a)*r,H*(.045+G.hash(i,5)*.026),H*(.037+G.hash(i,7)*.032),H*(.045+G.hash(i,3)*.022),p[(i%3)+1],i%2==0 and 'gold'or 'ivory',i)
 end
 g.props=g.props+1;return g
end
function M.garland(g,a,b,s,palette,twinkle,seed,depthAt)
 local p=M.palette(palette);local dx,dy,dz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
 local len=math.sqrt(dx*dx+dy*dy+dz*dz);local n=math.max(8,math.ceil(len/1.8));local prev
 for i=0,n do local t=i/n
  local point={a[1]+dx*t,a[2]+dy*t-math.sin(t*pi)*s*1.8,a[3]+dz*t}
  if depthAt then point[3]=depthAt(point[1])end
  if prev then G.tube(g,prev,point,s*.38,'pineDark',4,nil,nil,false)end
  for k=-1,1,2 do
   G.tube(g,point,{point[1]+k*s*.8,point[2]-s*.5,point[3]+s*.55},s*.42,i%3==0 and 'pineLight'or 'pine',4,.02)
  end
  if i%2==0 then G.bulb(g,point[1],point[2]-.1,point[3]+s*.6,s*.22,p[(i%4)+1],twinkle)end
  if i%8==3 then M.ornament(g,point[1],point[2]-s*.9,point[3]+s*.3,s*.50,p[(i%3)+1],i)end
  prev=point
 end
 M.bow(g,a[1],a[2],a[3]+.8,s*.7,p[1]);M.bow(g,b[1],b[2],b[3]+.8,s*.7,p[1])
end
function M.wreath(g,x,y,z,r,palette,twinkle)
 local p=M.palette(palette)
 ring(g,x,y,z,r,r*.20,'pineDark',24,true,4)
 for i=0,23 do local a=i*2*pi/24;local px,py=x+math.cos(a)*r,y+math.sin(a)*r
  G.tube(g,{px,py,z},{px+math.cos(a+.6)*r*.35,py+math.sin(a+.6)*r*.35,z+.3},r*.19,i%3==0 and 'pineLight'or 'pine',4,.02)
  if i%3==0 then G.bulb(g,px,py,z+r*.22,r*.07,p[4],twinkle)end
  if i%5==0 then M.ornament(g,px,py,z+r*.2,r*.13,p[(i%3)+1],i)end
 end
 M.bow(g,x,y+r*.89,z+r*.3,r*.35,p[1]);g.props=g.props+1
end
function M.candy(g,x,y,z,h)
 local r=h*.20;local pts={{x,y,z}};local steps=math.ceil(h/1.6);local mats={}
 for i=1,steps do pts[#pts+1]={x,y+(h-r)*i/steps,z}end
 for i=1,10 do local a=i*pi/10;pts[#pts+1]={x+r-r*math.cos(a),y+h-r+r*math.sin(a),z}end
 for i=2,#pts do G.tube(g,pts[i-1],pts[i],h*.045,i%3==0 and 'red'or 'ivory',6,nil,nil,false)end
 g.props=g.props+1
end
function M.lantern(g,x,y,z,s,holiday,glow,flicker)
 local cap=(holiday=='halloween'or holiday=='harvest')and 'black'or 'gold'
 G.box(g,x,y,z,s*1.6,s*.30,s*1.6,cap)
 G.box(g,x,y+s*.28,z,s*1.22,s*1.95,s*1.22,glow or 'glass')
 for dx=-1,1,2 do for dz=-1,1,2 do G.box(g,x+dx*s*.66,y+s*.2,z+dz*s*.66,s*.16,s*2.10,s*.16,cap)end end
 G.box(g,x,y+s*2.3,z,s*1.75,s*.25,s*1.75,cap)
 G.tube(g,{x,y+s*2.54,z},{x,y+s*3.3,z},s*1.05,cap,4,.03)
 ring(g,x,y+s*3.58,z,s*.33,s*.07,cap,8,true,3)
 G.bulb(g,x,y+s*1.25,z,s*.38,glow or 'warm',flicker);g.props=g.props+1
end
function M.snowman(g,x,y,z,s,palette)
 local p=M.palette(palette)
 G.sphere(g,x,y+s*3.6,z,s*3.7,s*3.6,s*3.7,'snow',12,8)
 G.sphere(g,x,y+s*8.2,z,s*2.7,s*2.8,s*2.7,'snow',12,8)
 G.sphere(g,x,y+s*11.8,z,s*2.15,s*2.1,s*2.15,'snow',12,8)
 G.tube(g,{x,y+s*13.7,z},{x,y+s*14,z},s*3,'black',12)
 G.tube(g,{x,y+s*14,z},{x,y+s*16.4,z},s*1.8,'black',12)
 G.tube(g,{x,y+s*14.2,z},{x,y+s*14.7,z},s*1.82,p[1],12,nil,nil,false)
 for _,dx in ipairs({-.72,.72})do G.sphere(g,x+dx*s,y+s*12.25,z+s*1.97,s*.25,s*.25,s*.20,'coal',5,4)end
 G.tube(g,{x,y+s*11.7,z+s*1.97},{x+.12*s,y+s*11.5,z+s*3.7},s*.35,'orange',6,.02)
 ring(g,x,y+s*9.9,z,s*2.1,s*.46,p[1],14,false,5)
 G.box(g,x+s*.9,y+s*7.2,z+s*2.6,s*.78,s*3.2,s*.35,p[1],-.16)
 for i=0,2 do G.sphere(g,x,y+s*(8.4-i*1.7),z+s*(2.7+i*.27),s*.27,s*.27,s*.20,'coal',5,4)end
 for side=-1,1,2 do
  local a={x+side*s*2,y+s*8.6,z};local b={x+side*s*6,y+s*10.7,z+.5*s}
  G.tube(g,a,b,s*.20,'bark',4,.1*s);G.tube(g,{b[1]-side*s,b[2]-.5*s,b[3]},{b[1]-.4*side*s,b[2]+s,b[3]},s*.1,'bark',3)
 end
 g.props=g.props+1
end
-- Jack-o'-lanterns flicker (twinkle groups) when lit; dark pumpkins stay matte.
function M.pumpkin(g,x,y,z,r,lit,seed,mat)
 G.sphere(g,x,y+r*.70,z,r,r*.72,r,mat or 'orange',30,9,nil,10)
 G.tube(g,{x,y+r*1.38,z},{x+r*.12,y+r*1.75,z-r*.06},r*.12,'bark',5,r*.07)
 if lit==nil then return end
 local face=lit and 'warm'or 'black';local emission=lit and 66 or 1
 local detail=r>=2.5 and 2 or 1
 -- Tessellated cut-face relief follows the ribbed shell, so smiles cannot
 -- disappear inside a curved pumpkin when viewed from an oblique angle.
 local function surface(p,offset)
  local v=(p[2]-.70)/.72;local radial=math.sqrt(math.max(.001,1-v*v))
  local lo,hi=0,pi
  for i=1,17 do local a=(lo+hi)/2;local xx=math.cos(a)*radial*(1+.075*math.cos(a*10))
   if xx>p[1]then lo=a else hi=a end
  end
  local a=(lo+hi)/2;local zz=math.sin(a)*radial*(1+.075*math.cos(a*10))
  return{x+p[1]*r,y+p[2]*r,z+(zz+offset)*r}
 end
 local function triangle(a,b,c,mat2,shade,depth,offset)
  if depth==0 then G.tri(g,surface(a,offset),surface(b,offset),surface(c,offset),mat2,shade);return end
  local ab={(a[1]+b[1])/2,(a[2]+b[2])/2};local bc={(b[1]+c[1])/2,(b[2]+c[2])/2};local ca={(c[1]+a[1])/2,(c[2]+a[2])/2}
  triangle(a,ab,ca,mat2,shade,depth-1,offset);triangle(ab,b,bc,mat2,shade,depth-1,offset)
  triangle(ca,bc,c,mat2,shade,depth-1,offset);triangle(ab,bc,ca,mat2,shade,depth-1,offset)
 end
 local off=detail==2 and 0 or .012
 for side=-1,1,2 do
  local u=side*.31
  triangle({u-.18,.85},{u+.18,.85},{u+side*.03,1.13},'black',1,detail,.014+off)
  triangle({u-.14,.88},{u+.14,.88},{u+side*.03,1.095},face,emission,detail,.020+off)
 end
 local smile={{-.56,.62},{-.35,.49},{-.20,.54},{0,.43},{.20,.54},{.35,.49},{.56,.62},{.40,.33},{.20,.26},{0,.23},{-.20,.26},{-.40,.33}}
 for i=1,#smile do local j=i%#smile+1
  triangle({0,.38},smile[i],smile[j],'black',1,detail,.014+off)
  local a={smile[i][1]*.93,.40+(smile[i][2]-.40)*.82};local b={smile[j][1]*.93,.40+(smile[j][2]-.40)*.82}
  triangle({0,.39},a,b,face,emission,detail,.022+off)
 end
 g.props=g.props+1
end
function M.hay(g,x,y,z,w,h,d,seed)
 G.box(g,x,y,z,w,h,d,'hay')
 for _,f in ipairs({-.28,.28})do
  G.box(g,x+w*f,y-.02,z,.32,h+.08,d+.14,'rope')
  G.box(g,x+w*f,y+h+.01,z,.56,.12,d+.35,'rope')
 end
 -- Protruding straw filaments and irregular cut ends.
 for i=1,40 do local yy=y+G.hash(i,seed)*h;local xx=x+(G.hash(seed,i,4)-.5)*w
  local zz=z+d/2+.055
  G.tube(g,{xx,yy,zz},{xx+(G.hash(i,3)-.5)*2,yy+.12,zz+.1+G.hash(i,5)*.5},.045,i%4==0 and 'cream'or 'hay',3)
 end
 for i=1,16 do local xx=x+(G.hash(i,seed,8)-.5)*w;local zz=z+(G.hash(i,seed,9)-.5)*d
  G.tube(g,{xx,y+h,zz},{xx+.15,y+h+.5+G.hash(i,1)*.8,zz+.2},.05,'hay',3)
 end
 g.props=g.props+1
end
function M.web(g,x,y,z,r)
 local n=9
 for i=0,n-1 do local a=i*2*pi/n;G.tube(g,{x,y,z},{x+math.cos(a)*r,y+math.sin(a)*r,z},.035,'web',3)end
 for j=1,5 do for i=0,n-1 do local a,b=i*2*pi/n,(i+1)*2*pi/n;local rr=r*j/5
  local A={x+math.cos(a)*rr,y+math.sin(a)*rr,z};local B={x+math.cos(b)*rr,y+math.sin(b)*rr,z};local C={(A[1]+B[1])*.5,(A[2]+B[2])*.5-.16,z+.08}
  G.tube(g,A,C,.029,'web',3);G.tube(g,C,B,.029,'web',3)
 end end
 G.sphere(g,x+r*.22,y-r*.12,z+.1,.35,.50,.28,'black',6,4)
end
-- Poses use their support as the local origin: pole at x=z=0;
-- seated pelvis centered over z=0, facing outward along +z.
function M.skeleton(g,pose,scale,poleRadius)
 local b=G.new();local bone='ivory';local hug=pose=='hug' or pose=='climb';local sit=pose=='sit'
 scale=scale or 1
 local r=(poleRadius or .85)/scale
 local dz=hug and -(r+2.5) or sit and -1.2 or 0
 local hx=hug and 1.35 or 0
 local function link(a,c,radius)G.tube(b,a,c,radius or .24,bone,5)end
 local function joint(p,radius)G.sphere(b,p[1],p[2],p[3],radius,radius,radius,bone,6,4)end
 link({0,7.2,1.2+dz},{0,14,1.2+dz},.32)
 link({0,14,1.2+dz},{hx,14.7,1.2+dz},.25)
 G.sphere(b,hx,15.9,1.2+dz,1.35,1.55,1.05,bone,10,7)
 G.box(b,hx,14.5,1.8+dz,1.5,.65,.75,bone)
 for _,x in ipairs({-.54,.54})do G.sphere(b,hx+x,16.15,2.12+dz,.40,.47,.10,'coal',6,4)end
 G.tri(b,{hx-.22,15.35,2.23+dz},{hx+.22,15.35,2.23+dz},{hx,15.85,2.23+dz},'coal')
 for i=-2,2 do G.box(b,hx+i*.26,14.5,2.20+dz,.075,.40,.08,'coal')end
 link({-1.3,13.6,1.2+dz},{1.3,13.6,1.2+dz},.26)
 for row=0,3 do
  local y=12.9-row*.88;local w=1.7-row*.17
  for _,side in ipairs({-1,1})do
   link({0,y+.2,1+dz},{side*w,y,1+dz},.18)
   link({side*w,y,1+dz},{side*w*.85,y-.40,2.15+dz},.18)
   link({side*w*.85,y-.40,2.15+dz},{side*.2,y-.45,2.25+dz},.16)
  end
 end
 for _,side in ipairs({-1,1})do
  link({0,8.6,1.2+dz},{side*1.35,8,1.2+dz},.35)
  link({side*1.35,8,1.2+dz},{side*.85,7.1,1.2+dz},.34)
  local hip={side*.85,7.1,1.2+dz}
  local knee=hug and {side*(r+1),side<0 and 5.8 or 6.5,.1}or sit and {side*1.25,7.1,2.9}or{side*1.1,3.8,1.2}
  local foot=hug and {side*.2,side<0 and 4.8 or 5.4,r+.45}or sit and {side*1.35,2.5,3.3}or{side*1.2,.6,1.6}
  link(hip,knee,.30);joint(knee,.38);link(knee,foot,.23)
  link({foot[1]+side*.28,foot[2],foot[3]},knee,.13)
  G.box(b,foot[1],foot[2]-.3,foot[3]+.4,.65,.45,1.3,bone)
  local shoulder={side*1.7,13.4,1.2+dz}
  local elbow=hug and {side*(r+.95),side<0 and 12.3 or 13,.05}or{side*2.5,10.5,1.4+dz}
  local hand=hug and {side*.2,side<0 and 12 or 12.6,r+.4}or sit and {side*1.25,7.7,2.8}or{side*2.9,7.8,1.6}
  joint(shoulder,.4);link(shoulder,elbow,.23);joint(elbow,.30);link(elbow,hand,.18)
  for j=-1,1 do link({hand[1]+j*.18,hand[2],hand[3]},{hand[1]+j*.23,hand[2]-.7,hand[3]+.2},.07)end
 end
 G.instance(g,b,0,0,0,scale)
 g.props=g.props+1
end
-- Standing scarecrow with patched coat, rope belt, straw hands and hat.
function M.scarecrow(g,x,y,z,s,coat,head)
 local q=G.new();coat=coat or 'purple'
 G.tube(q,{0,0,0},{0,31,0},.45,'wood',6)
 G.tube(q,{-10,24,0},{10,24,0},.36,'wood',5)
 G.box(q,0,19,0,8,9,2.6,coat)
 G.box(q,-2,17,0,2.7,4.1,2.2,'crimson',-.16);G.box(q,2,17,0,2.7,4.1,2.2,'crimson',.16)
 G.tube(q,{-4,25,0},{-9,23,0},1.25,coat,6,.90);G.tube(q,{4,25,0},{9,23,0},1.25,coat,6,.9)
 G.box(q,0,21,1.4,8.2,.6,.35,'rope');G.box(q,2,24,1.4,2.1,2.5,.12,'hay')
 for side=-1,1,2 do for k=0,5 do G.tube(q,{side*9,23,0},{side*(12+G.hash(k,2)),22+(k-3)*.48,(k-3)*.17},.065,'hay',3)end end
 if head=='sack'then
  G.sphere(q,0,28.6,0,2.7,3.0,2.5,'husk',10,7)
  for _,dx in ipairs({-.9,.9})do G.sphere(q,dx,29.2,2.25,.45,.45,.15,'black',5,3)end
  G.box(q,0,27.3,2.32,2.0,.25,.12,'black')
 else M.pumpkin(q,0,27,0,3.1,true,9)end
 G.tube(q,{0,31.7,0},{0,32.15,0},4.8,'bark',12)
 G.tube(q,{0,32.15,0},{.7,36.4,0},3,'bark',10,1.5)
 G.append(g,G.translate(q,x,y,z,0,s));g.props=g.props+1
end
function M.halloween(opts)
 local g=G.new();local s=opts.scale or 1
 M.hay(g,-7,0,1,16,8,10,1);M.hay(g,8,0,0,15,8,10,2);M.hay(g,0,8,0,14,8,9,3)
 M.pumpkin(g,-9,8.1,2,3.6,true,1);M.pumpkin(g,2,16.1,0,4.1,true,2);M.pumpkin(g,12,.1,7,4.2,true,3)
 M.pumpkin(g,-14,.1,7,2.8,false,4);M.pumpkin(g,4,.1,8,3.3,true,5)
 M.lantern(g,-2,0,9,1.35,'halloween',nil,true)
 M.scarecrow(g,0,0,-3,1)
 for i=1,28 do local a=i*2.4;local r=12+G.hash(i,4)*9
  local x,z=math.cos(a)*r,math.sin(a)*r
  G.quad(g,{x,.17,z},{x+1.3,.19,z+.2},{x+.9,.3,z+1.1},{x-.1,.18,z+.7},i%2==0 and 'orange'or 'copper')
 end
 return G.translate(g,0,0,0,0,s)
end
-- Rounded or cross headstone with an engraved plate and a low grave mound.
function M.tombstone(g,x,z,s,yaw,kind,seed)
 local q=G.new();local mat=seed%3==0 and 'mossStone'or 'stone'
 local lean=(G.hash(seed,7)-.5)*.10
 if kind=='cross'then
  G.box(q,0,0,0,1.3,7.4,1.0,mat);G.box(q,0,4.6,0,4.4,1.2,1.0,mat)
  G.box(q,0,0,0,3.2,.8,2.2,mat)
 else
  G.box(q,0,0,0,4.4,5.2,1.25,mat)
  G.tube(q,{0,5.2,-.625},{0,5.2,.625},2.2,mat,10,nil,nil,true)
  G.box(q,0,2.5,.64,2.6,1.6,.06,'iron')
  G.box(q,0,4.8,.64,.36,1.5,.06,'iron');G.box(q,0,5.15,.64,1.2,.34,.06,'iron')
  G.box(q,0,0,0,5.4,.6,2.0,mat)
 end
 G.sphere(q,0,-.15,3.2,2.1,.42,2.6,'graveDirt',8,3)
 local out=G.new();G.append(out,q)
 -- Lean the stone slightly; settle the mound flat.
 for _,v in ipairs(out.vertices)do if v[3]<1.4 then v[3]=v[3]+v[2]*lean end end
 G.append(g,G.translate(out,x,0,z,yaw or 0,s));g.props=g.props+1
end
function M.candle(g,x,y,z,s,glow)
 G.tube(g,{x,y,z},{x,y+2.2*s,z},.32*s,'candle',6)
 G.tube(g,{x,y+2.2*s,z},{x,y+2.5*s,z},.04*s,'black',3)
 G.sphere(g,x,y+2.85*s,z,.24*s,.48*s,.24*s,glow or 'warm',5,3,66)
 g.lights=g.lights+1
end
function M.cauldron(g,x,z,s,glow)
 local q=G.new();glow=glow or 'slime'
 -- Firewood with glowing embers under three iron legs.
 for i=0,2 do local a=i*2*pi/3+.3
  G.tube(q,{math.cos(a)*3.6,.35,math.sin(a)*3.6},{-math.cos(a)*1.2,.9,-math.sin(a)*1.2},.45,'deadwood',5)
  G.tube(q,{math.cos(a+.9)*2.9,0,math.sin(a+.9)*2.9},{math.cos(a+.9)*2.2,2.6,math.sin(a+.9)*2.2},.28,'iron',4)
 end
 for i=1,5 do G.sphere(q,(G.hash(i,3)-.5)*2.2,.7,(G.hash(i,9)-.5)*2.2,.42,.30,.42,'warm',5,3,66)end
 G.sphere(q,0,4.6,0,3.4,2.6,3.4,'iron',14,8)
 ring(q,0,6.55,0,2.75,.42,'iron',14,false,5)
 G.disc(q,0,6.40,0,2.65,glow,14)
 for i=1,6 do local a=G.hash(i,11)*2*pi;local r=G.hash(i,13)*2.0
  G.sphere(q,math.cos(a)*r,6.55+G.hash(i,17)*.4,math.sin(a)*r,.38,.30,.38,glow,5,3,66)
 end
 for i=1,3 do G.sphere(q,(G.hash(i,21)-.5)*1.4,7.6+i*1.1,(G.hash(i,23)-.5)*1.4,.30+.1*i,.30+.1*i,.30+.1*i,glow,5,3,65.3)end
 -- Every lit triangle above uses the twinkle/flicker groups.
 G.append(g,G.translate(q,x,0,z,0,s));g.props=g.props+1
end
-- Hovering sheet ghost with a wavy hem; the body glows softly at night.
function M.ghost(g,x,y,z,s,yaw,mat)
 local q=G.new();mat=mat or 'ghost'
 local n=12;local rows={{0,9.2,0},{1.9,8.6},{2.6,6.8},{2.9,4.6},{3.3,2.2},{3.7,.4}}
 local function pt(i,row)
  local a=i*2*pi/n;local rad=rows[row][1];local yy=rows[row][2]
  if row==#rows then yy=yy+math.sin(a*3)*.55 end
  return{math.cos(a)*rad,yy,math.sin(a)*rad}
 end
 for i=0,n-1 do
  G.tri(q,{0,9.6,0},pt(i+1,2),pt(i,2),mat,65.2)
  for row=2,#rows-1 do G.quad(q,pt(i,row),pt(i+1,row),pt(i+1,row+1),pt(i,row+1),mat,65.2)end
 end
 for side=-1,1,2 do
  G.tube(q,{side*2.4,6.4,0},{side*4.6,7.6,1.2},.85,mat,5,.45,65.2)
  G.sphere(q,side*.95,7.4,2.35,.45,.70,.20,'black',6,4)
 end
 G.sphere(q,0,5.9,2.72,.55,.75,.20,'black',6,4)
 G.append(g,G.translate(q,x,y,z,yaw or 0,s));g.props=g.props+1
end
function M.crow(g,x,y,z,s,yaw)
 local q=G.new()
 G.sphere(q,0,.9,0,.85,.8,1.5,'black',8,5)
 G.sphere(q,0,1.75,1.15,.55,.55,.55,'black',8,5)
 G.tri(q,{-.18,1.75,1.6},{.18,1.75,1.6},{0,1.62,2.35},'gold')
 G.quad(q,{-.5,1.0,-1.2},{.5,1.0,-1.2},{.7,.7,-2.6},{-.7,.7,-2.6},'black')
 for side=-1,1,2 do G.sphere(q,side*.26,1.92,1.55,.10,.10,.08,'egg',4,3,65.3)end
 G.append(g,G.translate(q,x,y,z,yaw or 0,s))
end
-- Gnarled bare tree hung with jack-o'-lanterns and lamps, watched by crows.
function M.hauntedTree(opts)
 local g=G.new();local s=opts.scale or 1;local glow=opts.glow or 'warm';local seed=opts.seed or 3
 local tips={}
 local function branch(p,dir,len,r,depth,k)
  local pts={p};local cur=p;local dx,dy,dz=dir[1],dir[2],dir[3]
  local segs=depth>=2 and 3 or 2
  for i=1,segs do
   local wob=(G.hash(k,i,seed)-.5)*.7
   dx,dz=dx*math.cos(wob)-dz*math.sin(wob),dx*math.sin(wob)+dz*math.cos(wob)
   dy=dy*.86-.04*(3-depth)
   local l=len/segs;cur={cur[1]+dx*l,cur[2]+dy*l,cur[3]+dz*l};pts[#pts+1]=cur
  end
  for i=2,#pts do
   local r0=r*(1-(i-2)/segs*.55);local r1=r*(1-(i-1)/segs*.55)
   G.tube(g,pts[i-1],pts[i],r0,'deadwood',depth>=2 and 7 or 5,r1,nil,i==#pts)
  end
  if depth>0 then
   for j=1,depth>=2 and 3 or 2 do
    local a=G.hash(k,j,seed*3)*2*pi
    local nd={dx*.55+math.cos(a)*.6,.45+G.hash(j,k)*.4,dz*.55+math.sin(a)*.6}
    local l=math.sqrt(nd[1]^2+nd[2]^2+nd[3]^2);nd={nd[1]/l,nd[2]/l,nd[3]/l}
    local from=pts[math.max(2,#pts-(j%2))]
    branch(from,nd,len*.62,r*.55,depth-1,k*7+j)
   end
  else tips[#tips+1]={cur[1],cur[2],cur[3]}end
 end
 -- Root flare and mound.
 G.sphere(g,0,0,0,10,1.6,10,'soil',14,5)
 for i=0,4 do local a=i*2*pi/5+.4
  G.tube(g,{math.cos(a)*1.2,1.6,math.sin(a)*1.2},{math.cos(a)*5.5,.1,math.sin(a)*5.5},1.3,'deadwood',5,.35)
 end
 local trunkTop={.8,19,.4}
 G.tube(g,{0,0,0},{.3,10,.1},3.0,'deadwood',9,2.3,nil,false)
 G.tube(g,{.3,10,.1},trunkTop,2.3,'deadwood',9,1.7,nil,false)
 for i=1,4 do local a=i*2*pi/4+.5
  branch(trunkTop,{math.cos(a)*.75,.62,math.sin(a)*.75},17,1.55,2,i)
 end
 -- Hollow knot with an eerie glow.
 G.sphere(g,.25,7.5,2.45,.95,1.3,.25,glow,6,4,66)
 table.sort(tips,function(a,b)return a[2]<b[2]end)
 local hung=0;local spots={}
 for i,t in ipairs(tips)do
  -- Hang only from outer tips, spaced apart, never clumped at the trunk.
  local free=t[2]>18 and(t[1]^2+t[3]^2)>30
  for _,o in ipairs(spots)do if(t[1]-o[1])^2+(t[3]-o[3])^2<20 then free=false;break end end
  if free and hung<9 then
   hung=hung+1;spots[#spots+1]=t
   local drop=3.5+G.hash(i,seed)*3.5;local bottom={t[1],t[2]-drop,t[3]}
   G.tube(g,t,bottom,.07,'rope',3)
   if hung%3==0 then M.lantern(g,bottom[1],bottom[2]-3.4,bottom[3],.95,'halloween',opts.lamp,true)
   else M.pumpkin(g,bottom[1],bottom[2]-2.5,bottom[3],1.45,true,i)end
  end
 end
 local perched=0
 for i=#tips,1,-1 do local t=tips[i]
  if perched<3 and i%3==0 then perched=perched+1;M.crow(g,t[1],t[2]-.3,t[3],.9,G.hash(i,5)*2*pi)end
 end
 return G.translate(g,0,0,0,0,s)
end
-- Full Halloween town centerpiece: haunted tree, graves, hay and cauldron.
function M.hauntedPlaza(opts)
 local g=G.new();local s=opts.scale or 1;local spectral=opts.spectral
 local glow=spectral and 'violetGlow'or 'warm'
 G.append(g,M.hauntedTree{scale=1.0,glow=glow,lamp=spectral and 'spirit'or nil,seed=opts.seed})
 -- Graves ring the tree; each gap between them holds one display.
 local function at(a,r)return math.cos(a)*r,math.sin(a)*r end
 for i=0,5 do local a=.5+i*pi/3;local r=15.5+G.hash(i,2)*1.5;local x,z=at(a,r)
  M.tombstone(g,x,z,.95,math.atan2(x,z),i%3==1 and 'cross'or 'round',i+1)
  local cx,cz=at(a+.16,r+1.6);M.candle(g,cx,0,cz,.9,glow)
 end
 local function gap(k,r)return at(.5+(k+.5)*pi/3,r)end
 local x,z=gap(0,13.5);M.cauldron(g,x,z,.95,spectral and 'spirit'or 'slime')
 x,z=gap(1,13);M.hay(g,x,0,z,9,5,6,4);M.pumpkin(g,x-1.5,5.1,z,2.6,true,11);M.pumpkin(g,x+2.6,5.1,z+.4,1.8,false,12)
 x,z=gap(2,12.5);M.pumpkin(g,x,0,z,2.4,true,13);M.pumpkin(g,x-2.8,0,z-1.6,1.6,true,14)
 x,z=gap(3,12.5);M.lantern(g,x,0,z,1.4,'halloween',spectral and 'spirit'or nil,true)
 x,z=gap(4,13);if spectral then M.ghost(g,x,3.5,z,.95,math.atan2(x,z),'ghost')else M.scarecrow(g,x,0,z,.45,'purple','sack')end
 x,z=gap(5,13);M.pumpkin(g,x,0,z,2.8,false,15);M.pumpkin(g,x+2.4,0,z+2.0,1.7,true,16)
 for i=1,30 do local a=i*2.4;local r=9+G.hash(i,4)*12
  local x,z=math.cos(a)*r,math.sin(a)*r
  G.quad(g,{x,.17,z},{x+1.3,.19,z+.2},{x+.9,.3,z+1.1},{x-.1,.18,z+.7},i%3==0 and 'leafRed'or i%3==1 and 'orange'or 'copper')
 end
 return G.translate(g,0,0,0,0,s)
end
function M.egg(g,x,y,z,r,mat,seed)
 G.sphere(g,x,y+r*1.25,z,r,r*1.26,r,mat,10,7)
 for j=1,2 do ring(g,x,y+r*(.72+j*.42),z,r*(j==2 and .95 or .99),r*.05,seed%2==0 and 'ivory'or 'gold',10,false,3)end
 for i=0,5 do local a=i*2*pi/6;G.sphere(g,x+math.cos(a)*r*1.01,y+r*1.23,z+math.sin(a)*r*1.01,r*.11,r*.11,r*.11,'white',4,3)end
 g.props=g.props+1
end
function M.easter(opts)
 local g=G.new();local p={'pink','mint','lilac','egg','cyan'}
 G.tube(g,{0,0,0},{0,4.8,0},8.5,'wood',20,10)
 for j=0,10 do ring(g,0,.5+j*.43,0,8.6+j*.13,.19,j%2==0 and 'wood'or 'hay',24,false,3)end
 for i=0,23 do local a=i*2*pi/24;G.tube(g,{math.cos(a)*8.5,0,math.sin(a)*8.5},{math.cos(a)*10,5,math.sin(a)*10},.12,'hay',3)end
 local pts={};for i=0,20 do local a=i*pi/20;pts[#pts+1]={math.cos(a)*10,5+math.sin(a)*14,0}end;chain(g,pts,.45,'wood',6)
 for i=1,11 do local a=i*2.4;local r=i==1 and 0 or 5.5;M.egg(g,math.cos(a)*r,3.3,math.sin(a)*r,2.1,p[i%5+1],i)end
 M.bow(g,0,18.2,.6,2,'pink')
 for i=1,9 do local a=i*2.399;local r=12+G.hash(i,6)*7;M.egg(g,math.cos(a)*r,0,math.sin(a)*r,1.8+G.hash(i,2),p[i%5+1],i)end
 -- White rabbit sculpture with separately modeled ears, feet and face.
 G.sphere(g,-14,5,1,3.4,5,3,'ivory',12,8);G.sphere(g,-14,10,2,2.9,2.7,2.5,'ivory',12,8)
 for _,x in ipairs({-15.2,-12.8})do G.sphere(g,x,14.2,1.8,.85,3.5,.68,'ivory',8,6);G.sphere(g,x,14.3,2.4,.39,2.65,.13,'pink',6,5)end
 for _,x in ipairs({-15.15,-12.85})do G.sphere(g,x,10.6,4.23,.23,.28,.18,'black',5,4)end
 G.sphere(g,-14,9.5,4.4,.35,.26,.22,'pink',5,4)
 return g
end
function M.bunting(g,a,b,theme,depthAt)
 local n=math.max(3,math.floor(math.abs(b[1]-a[1])/3.8));local prev=a
 local colors=theme=='july'and{'red','ivory','blue'}or theme=='harvest'and{'leafRed','leafGold','leafOrange'}or{'purple','orange','black'}
 for i=1,n do local t=i/n;local p={a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t-math.sin(t*pi)*2,a[3]+(b[3]-a[3])*t}
  if depthAt then p[3]=depthAt(p[1])end
  G.tube(g,prev,p,.085,'rope',3)
  local tip={(p[1]+prev[1])/2,(p[2]+prev[2])/2-3.8,p[3]+.13}
  G.tri(g,prev,{p[1],p[2],p[3]},tip,colors[(i%3)+1])
  prev=p
 end
end
function M.july(opts)
 local g=G.new()
 G.tube(g,{0,0,0},{0,3.5,0},13,'ivory',24)
 G.tube(g,{0,3.5,0},{0,4.4,0},13.1,'red',24,nil,nil,false)
 G.tube(g,{0,4.4,0},{0,5.3,0},13.1,'blue',24)
 for _,x in ipairs({-9,9})do
  G.tube(g,{x,5,0},{x,44,0},.27,'gold',6)
  G.sphere(g,x,44.6,0,.72,.72,.72,'gold',8,5)
  for j=0,12 do
   for i=0,9 do local xx=x+i*1.22;local yy=42-j*.57;local dz=math.sin(i*.48)*1.1;local dz2=math.sin((i+1)*.48)*1.1
    local m=j%2==0 and 'red'or 'ivory'
    G.quad(g,{xx,yy,dz},{xx+1.22,yy,dz2},{xx+1.22,yy-.57,dz2},{xx,yy-.57,dz},m)
   end
  end
  G.quad(g,{x,42,.08},{x+5.6,42,1.0},{x+5.6,38.05,1.0},{x,38.05,.08},'blue')
  for row=0,3 do for col=0,4 do G.star(g,x+.5+col*1.03,41.5-row*.89,.30+math.sin(col*.5)*.9,.19,'ivory')end end
 end
 M.bunting(g,{-13,19,5},{13,19,5},'july')
 for _,x in ipairs({-7,0,7})do
  G.tube(g,{x,5,4},{x,12,4},2,'blue',12)
  ring(g,x,6,4,2.02,.25,'red',12,false,3);ring(g,x,11,4,2.02,.25,'ivory',12,false,3)
  G.star(g,x,9,6.05,1.05,'gold')
 end
 g.props=g.props+1;return g
end
-- Small waving flag on a staff, used at doors and lamps.
function M.flag(g,x,y,z,h,w,yaw)
 local q=G.new();G.tube(q,{0,0,0},{0,h,0},.14,'gold',4);G.sphere(q,0,h+.3,0,.3,.3,.3,'gold',5,3)
 local rows,cols=7,6;local fh=w*.62
 for j=0,rows-1 do for i=0,cols-1 do
  local x0,x1=i*w/cols,(i+1)*w/cols;local y0=h-.2-j*fh/rows;local y1=y0-fh/rows
  local z0,z1=math.sin(i*.9)*.35,math.sin((i+1)*.9)*.35
  local m=(i<3 and j<4)and 'blue'or(j%2==0 and 'red'or 'ivory')
  G.quad(q,{x0,y0,z0},{x1,y0,z1},{x1,y1,z1},{x0,y1,z0},m)
 end end
 G.append(g,G.translate(q,x,y,z,yaw or 0,1))
end
-- Glowing wire reindeer: a classic light sculpture that reads at night.
function M.reindeer(g,x,z,s,yaw,mat)
 local q=G.new();mat=mat or 'frostGlow';local r=.16;local sh=66
 local function line(pts)for i=2,#pts do G.tube(q,pts[i-1],pts[i],r,mat,3,nil,sh,false)end end
 for _,side in ipairs({-1.2,1.2})do
  local body={}
  for i=0,12 do local a=i*2*pi/12;body[#body+1]={side,8+math.sin(a)*2.2,math.cos(a)*4.6}end
  line(body)
 end
 for _,zz in ipairs({-3.6,3.6})do for _,side in ipairs({-1.2,1.2})do
  line({{side,6.4,zz},{side,3.2,zz*1.05},{side,0,zz*1.08+.4}})
 end end
 line({{0,9.6,3.6},{0,13.6,5.2},{0,14.3,7.4},{0,13.2,8.3}})
 line({{-.8,13.6,5.0},{.8,13.6,5.0}})
 for side=-1,1,2 do
  line({{side*.4,14.4,5.4},{side*1.6,16.8,4.8},{side*2.8,18.5,5.6}})
  line({{side*1.6,16.8,4.8},{side*2.6,17.4,3.6}})
  line({{side*2.2,17.6,5.2},{side*3.3,18.4,4.6}})
 end
 line({{0,10.0,-4.4},{0,11.2,-5.4}})
 G.sphere(q,0,13.3,8.4,.42,.42,.42,'red',5,3,66)
 -- Built nose-along-z; turn it side-on so the camera sees its profile.
 G.append(g,G.translate(q,x,0,z,math.pi/2+(yaw or 0),s));g.props=g.props+1
end
-- Potted, lit mini spruce for a doorstep.
function M.pottedPine(g,x,z,s,palette,twinkle,seed)
 local q=G.new();local p=M.palette(palette)
 G.box(q,0,0,0,3.6,2.8,3.6,p[1]=='red'and 'crimson'or 'wood')
 G.box(q,0,2.4,0,3.9,.5,3.9,'gold')
 G.disc(q,0,2.85,0,1.7,'soil',8)
 G.tube(q,{0,2.6,0},{0,4,0},.35,'bark',4)
 for j=0,3 do local y=3.6+j*1.9;local r=2.4-j*.5
  G.tube(q,{0,y,0},{0,y+2.4,0},r,j%2==0 and 'pine'or 'pineLight',8,.15)
 end
 local pts={}
 for i=0,22 do local f=i/22;local y=4+f*7;local a=f*2*pi*3+(seed or 0);local r=2.3-f*1.9
  pts[#pts+1]={math.cos(a)*r,y,math.sin(a)*r}
  if i%2==0 then G.bulb(q,pts[#pts][1],y-.15,pts[#pts][3],.22,p[(i%4)+1],twinkle)end
 end
 chain(q,pts,.05,'black',3)
 G.star(q,0,11.9,0,.75,'gold')
 G.append(g,G.translate(q,x,0,z,0,s));g.props=g.props+1
end
-- Easter planter: tulips over a nest of eggs.
function M.flowerPot(g,x,z,s,seed)
 local q=G.new();local cols={'pink','lilac','egg','mint'}
 G.tube(q,{0,0,0},{0,2.6,0},1.6,'copper',8,2.1)
 ring(q,0,2.6,0,2.1,.22,'copper',10,false,3)
 G.disc(q,0,2.5,0,1.95,'soil',8)
 for i=1,5 do local a=i*2*pi/5+(seed or 0);local r=1.0
  local top={math.cos(a)*r*1.3,5.4+G.hash(i,seed or 1)*1.2,math.sin(a)*r*1.3}
  G.tube(q,{math.cos(a)*r*.5,2.5,math.sin(a)*r*.5},top,.10,'green',3)
  G.tube(q,top,{top[1],top[2]+1.2,top[3]},.55,cols[i%4+1],5,.75)
 end
 M.egg(q,1.1,2.4,1.3,.55,'pink',1);M.egg(q,-1.2,2.4,1.0,.5,'mint',2)
 G.append(g,G.translate(q,x,0,z,0,s));g.props=g.props+1
end
-- Tied corn shock (harvest), optional pumpkin at its foot.
function M.cornShock(g,x,z,s,seed)
 local q=G.new()
 for i=0,13 do local a=i*2*pi/14+G.hash(i,seed or 1)*.3;local r=1.6+G.hash(i,3)*.5
  local base={math.cos(a)*r,0,math.sin(a)*r};local tie={math.cos(a)*.55,6.2,math.sin(a)*.55}
  local top={math.cos(a)*(1.1+G.hash(i,5)),11+G.hash(i,7)*2.2,math.sin(a)*(1.1+G.hash(i,5))}
  G.tube(q,base,tie,.24,i%3==0 and 'hay'or 'husk',3,nil,nil,false);G.tube(q,tie,top,.24,'husk',3,.08)
  if i%3==1 then G.quad(q,tie,{tie[1]+math.cos(a)*1.4,tie[2]+2.6,tie[3]+math.sin(a)*1.4},{top[1],top[2]-1,top[3]},{tie[1],tie[2]+1,tie[3]},'husk')end
 end
 ring(q,0,6.2,0,.75,.18,'rope',8,false,3)
 G.append(g,G.translate(q,x,0,z,0,s));g.props=g.props+1
end
function M.gourds(g,x,z,s,seed)
 local q=G.new()
 for i=1,4 do local a=i*2.3+(seed or 0);local r=.9+G.hash(i,seed or 1)*1.2
  local m=i%3==0 and 'ivory'or i%3==1 and 'gourd'or 'green'
  G.sphere(q,math.cos(a)*r,.55,math.sin(a)*r,.75,.58,.75,m,8,5,nil,i%2==0 and 6 or nil)
  G.tube(q,{math.cos(a)*r,1.05,math.sin(a)*r},{math.cos(a)*r+.1,1.35,math.sin(a)*r},.09,'bark',3)
 end
 G.append(g,G.translate(q,x,0,z,0,s))
end
function M.appleBasket(g,x,z,s)
 local q=G.new()
 G.tube(q,{0,0,0},{0,2.2,0},1.7,'wood',10,2.2)
 ring(q,0,2.2,0,2.2,.18,'rope',10,false,3)
 local pts={};for i=0,8 do local a=i*pi/8;pts[#pts+1]={math.cos(a)*2.1,2.2+math.sin(a)*2.0,0}end;chain(q,pts,.12,'wood',3)
 for i=1,9 do local a=i*2.4;local r=i==1 and 0 or 1.2
  G.sphere(q,math.cos(a)*r,2.4+(i==1 and .4 or 0),math.sin(a)*r,.62,.58,.62,'apple',6,4)
 end
 G.append(g,G.translate(q,x,0,z,0,s));g.props=g.props+1
end
function M.leafPile(g,x,z,s,seed)
 local q=G.new()
 G.sphere(q,0,0,0,4.0,1.3,3.4,'leafOrange',10,4)
 local mats={'leafRed','leafGold','leafOrange','copper'}
 for i=1,26 do local a=i*2.4+(seed or 0);local r=G.hash(i,seed or 1)*4.8
  local xx,zz=math.cos(a)*r,math.sin(a)*r;local yy=math.max(.15,1.3*(1-(r/4.4)^2))
  G.quad(q,{xx,yy,zz},{xx+.9,yy+.12,zz+.2},{xx+.6,yy+.2,zz+.8},{xx-.1,yy+.08,zz+.5},mats[i%4+1])
 end
 G.append(g,G.translate(q,x,0,z,0,s));g.props=g.props+1
end
function M.wagonWheel(g,x,z,s,yaw)
 local q=G.new()
 ring(q,0,4.2,0,4.0,.38,'wood',14,true,4)
 for i=0,7 do local a=i*pi/4;G.tube(q,{0,4.2,0},{math.cos(a)*3.9,4.2+math.sin(a)*3.9,0},.18,'wood',3)end
 G.tube(q,{0,4.2,-.5},{0,4.2,.5},.7,'iron',6)
 local out=G.translate(q,0,0,0,0,1)
 for _,v in ipairs(out.vertices)do v[3]=v[3]-(v[2])*.25 end -- leans back on its support
 G.append(g,G.translate(out,x,0,z,yaw or 0,s));g.props=g.props+1
end
-- Harvest town centerpiece: a tiered hay-bale market display.
function M.harvestPlaza(opts)
 local g=G.new();local s=opts.scale or 1
 for i=0,5 do local a=i*2*pi/6;M.hay(g,math.cos(a)*7.5-5,0,math.sin(a)*7.5-3,10,5,6,i+1)end
 for i=0,2 do local a=i*2*pi/3+.5;M.hay(g,math.cos(a)*3.5-5,5,math.sin(a)*3.5-3,9,5,6,i+11)end
 M.hay(g,-5,10,-3,9,5,6,21)
 M.pumpkin(g,-5,15,-3,3.4,nil,1)
 M.pumpkin(g,-11,5,1,2.6,nil,2);M.pumpkin(g,1,5,1.5,2.2,nil,3,'gourd');M.pumpkin(g,-3,10,0,2.0,nil,4)
 M.gourds(g,-9,-6,1.3,5);M.gourds(g,2.5,-6.5,1.1,9)
 for i=0,3 do local a=i*pi/2+pi/4;M.cornShock(g,-5+math.cos(a)*15,-3+math.sin(a)*13,1.25,i+1)end
 M.appleBasket(g,6,6,1.1);M.appleBasket(g,-14,6,1.0)
 M.wagonWheel(g,10,-8,1.2,.4)
 M.lantern(g,-1,0,9,1.25,'harvest',nil,true);M.lantern(g,-12,0,-11,1.25,'harvest',nil,true)
 M.leafPile(g,9,9,.9,3)
 for i=1,30 do local a=i*2.4;local r=8+G.hash(i,4)*13
  local x,z=math.cos(a)*r-4,math.sin(a)*r-2
  G.quad(g,{x,.17,z},{x+1.3,.19,z+.2},{x+.9,.3,z+1.1},{x-.1,.18,z+.7},i%3==0 and 'leafRed'or i%3==1 and 'leafGold'or 'leafOrange')
 end
 return G.translate(g,5,0,3,0,s)
end
-- Garland (or a holiday light string) wrapped in a spiral around a deck's top
-- rail. Coordinates are world units; run comes from HostBridge.docks.
function M.dockGarland(g,run,holiday,palette,twinkle)
 local p=M.palette(palette);local y=run.h+6.75
 local function P(along,dy,dx)
  if run.cross then return{run.line+dx,y+dy,along}end
  return{along,y+dy,run.line+dx}
 end
 local len=run.a1-run.a0;local n=math.max(6,math.ceil(len/(holiday=='christmas'and .7 or 1.0)))
 local radius=holiday=='christmas'and .78 or .66
 local bulbs={christmas=p,halloween={'orange','violetGlow','orange','slime'},harvest={'warm','orange','gold','warm'},
  easter={'pink','mint','lilac','egg'},july={'red','white','blue','white'}}
 local colors=bulbs[holiday]or p
 local prev
 for i=0,n do
  local a=run.a0+len*i/n;local ang=(a-run.a0)/3.4*2*pi
  local cy,cx=math.sin(ang),math.cos(ang)
  local pt=P(a,cy*radius,cx*radius)
  if holiday=='christmas'then
   if prev then G.tube(g,prev,pt,.36,'pineDark',4,nil,nil,false)end
   local out=P(a,cy*(radius+.8),cx*(radius+.8))
   G.tube(g,pt,{out[1],out[2]-.3,out[3]},.42,i%3==0 and 'pineLight'or 'pine',4,.02)
   if i%3==0 then local b=P(a,cy*(radius+.55),cx*(radius+.55));G.bulb(g,b[1],b[2]-.15,b[3],.24,colors[(i/3)%4+1],twinkle)end
  else
   if prev then G.tube(g,prev,pt,.06,holiday=='harvest'and 'rope'or 'black',3,nil,nil,false)end
   if i%2==0 then local b=P(a,cy*(radius+.25),cx*(radius+.25));G.bulb(g,b[1],b[2]-.12,b[3],.26,colors[(i/2)%4+1],true)end
  end
  prev=pt
 end
 if holiday=='christmas'then
  -- A red bow on every lantern post, facing the deck.
  local yaw=run.cross and math.atan2(run.inward,0)or math.atan2(0,run.inward)
  for _,a in ipairs(run.posts)do
   local q=G.new();M.bow(q,0,0,0,.95,p[1]=='gold'and 'red'or p[1])
   local at=P(a,-1.1,run.inward*1.3)
   G.append(g,G.translate(q,at[1],at[2],at[3],yaw))
  end
 end
 g.props=g.props+1
end
-- TEST162: swagged garlands / light strings along district railings, with
-- holiday toppers on the posts (bows, jack-o'-lanterns, mini pumpkins).
function M.railGarland(g,segs,posts,holiday,palette,twinkle)
 local p=M.palette(palette)
 local bulbs={christmas=p,halloween={'orange','violetGlow','orange','slime'},harvest={'warm','orange','gold','warm'},
  easter={'pink','mint','lilac','egg'},july={'red','white','blue','white'}}
 local colors=bulbs[holiday]or p
 local xmas=holiday=='christmas'
 for si,sg in ipairs(segs or {})do
  local ax,az,bx,bz,y=sg[1],sg[2],sg[3],sg[4],sg[5]
  local n=8;local prev
  for i=0,n do
   local t=i/n
   local pt={ax+(bx-ax)*t,y+.35-1.25*math.sin(math.pi*t),az+(bz-az)*t}
   if prev then
    if xmas then G.tube(g,prev,pt,.34,(i%2==0)and 'pine'or 'pineDark',4,nil,nil,false)
    else G.tube(g,prev,pt,.06,holiday=='harvest'and 'rope'or 'black',3,nil,nil,false)end
   end
   if i>0 and i<n then
    G.bulb(g,pt[1],pt[2]-(xmas and .42 or .2),pt[3],xmas and .30 or .28,colors[(i+si)%4+1],twinkle)
   end
   prev=pt
  end
 end
 for pi_,pt in ipairs(posts or {})do
  local h=(pt.cx or 0)+(pt.cz or 0)
  if xmas then
   local q=G.new();M.bow(q,0,0,0,.9,p[1]=='gold'and 'red'or p[1])
   G.append(g,G.translate(q,pt.x,pt.y-1.6,pt.z,0))
   if h%4==0 then G.bulb(g,pt.x,pt.y+.9,pt.z,.55,'gold',twinkle)end
  elseif holiday=='halloween'then
   if h%3==0 then M.pumpkin(g,pt.x,pt.y,pt.z,1.35,true,pi_)end
  elseif holiday=='harvest'then
   if h%3==0 then M.pumpkin(g,pt.x,pt.y,pt.z,1.2,false,pi_)end
  else
   if h%3==0 then G.bulb(g,pt.x,pt.y+.6,pt.z,.5,colors[h%4+1],twinkle)end
  end
 end
 g.props=(g.props or 0)+1
end
-- Vegas palm: a tight spiral of lights up the trunk and strands along every
-- frond rib. Follows CinnabarPalms.model's trunk lean/taper and frond curves.
function M.palmLights(g,p,holiday,palette,twinkle)
 local pal=M.palette(palette)
 local trunkColors={christmas={'warm','warm','warm',pal[1]},halloween={'orange','orange','violetGlow','orange'},
  harvest={'warm','orange','warm','gold'},easter={'pink','egg','mint','lilac'},july={'red','white','blue','white'}}
 local frondColors={christmas={'mint','mint','warm'},halloween={'violetGlow','slime','violetGlow'},harvest={'gold','warm','gold'},
  easter={'mint','pink','mint'},july={'white','blue','red'}}
 local tc=trunkColors[holiday]or trunkColors.christmas;local fc=frondColors[holiday]or frondColors.christmas
 local height=p.height or 35;local rot=p.angle or 0;local seed=p.variant or 1;local lean=2.6
 local dx,dz=math.cos(rot),math.sin(rot)
 local function center(t)return p.cx+lean*t*t*dx,(p.h or 0)+.74+height*t,p.cz+lean*t*t*dz end
 local function radius(t)return 1.45-.67*t+.38*(1-t)^7 end
 -- Trunk spiral: one turn per 1.7 units of height, bulb every ~1 unit of wire.
 local turns=height/1.15;local steps=math.floor(turns*8);local prev
 for i=0,steps do
  local t=.03+.93*i/steps;local x,y,z=center(t);local r=radius(t)+.32
  local a=i/steps*turns*2*pi;local pt={x+math.cos(a)*r,y,z+math.sin(a)*r}
  if prev then G.tube(g,prev,pt,.05,'black',3,nil,nil,false)end
  if i%2==0 then G.bulb(g,pt[1],pt[2]-.1,pt[3],.21,tc[(i/2)%#tc+1],twinkle)end
  prev=pt
 end
 local cx,cy,cz=center(1)
 local function frond(angle,length,lift,droop,phase)
  local ux,uz=math.cos(angle),math.sin(angle);local vx,vz=-uz,ux
  local last
  for j=0,6 do
   local t=.08+j*.12;local drift=.42*math.sin(t*pi)*math.sin(phase)
   local pt={cx+ux*length*t+vx*drift,cy+lift*math.sin(t*pi*.82)-droop*t*t+.32,cz+uz*length*t+vz*drift}
   if last then G.tube(g,last,pt,.045,'green',3,nil,nil,false)end
   G.bulb(g,pt[1],pt[2],pt[3],.20,fc[j%#fc+1],twinkle)
   last=pt
  end
 end
 for i=0,8 do
  local angle=rot+i*2.39996323;local length=13.3+1.1*math.sin(i*2.1+seed)
  frond(angle,length,3.1+.8*math.sin(i+seed),3.6+.7*math.cos(i*1.9),i+seed)
 end
 g.props=g.props+1
end
-- Lamp-post dressing. Origin is the pole base; the pole runs up +y.
function M.lampDecor(g,holiday,height,poleRadius,palette,twinkle,seed)
 local r=(poleRadius or .85)+.05;local p=M.palette(palette)
 local band=math.max(6,height*.55)
 if holiday=='christmas'then
  -- Needle garland spiralling down the shaft, a wreath and a bow.
  local pts={}
  for i=0,24 do local f=i/24;local a=f*2*pi*3;local y=1.2+f*(band-1.2)
   pts[#pts+1]={math.cos(a)*(r+.35),y,math.sin(a)*(r+.35)}
  end
  for i=2,#pts do
   G.tube(g,pts[i-1],pts[i],.42,'pineDark',4,nil,nil,false)
   G.tube(g,pts[i],{pts[i][1]*1.6,pts[i][2]-.5,pts[i][3]*1.6},.38,'pine',4,.03)
   if i%2==0 then G.bulb(g,pts[i][1]*1.35,pts[i][2]-.2,pts[i][3]*1.35,.24,p[(i%4)+1],twinkle)end
  end
  M.wreath(g,0,band+2.4,r+.6,2.6,palette,twinkle)
 elseif holiday=='easter'then
  G.tube(g,{0,band,r},{0,band,r+2.4},.12,'gold',4)
  G.tube(g,{0,band,r+2.4},{0,band-2.2,r+2.4},.05,'rope',3)
  local q=G.new();G.tube(q,{0,0,0},{0,1.6,0},1.2,'hay',8,1.7);ring(q,0,1.6,0,1.7,.15,'hay',10,false,3)
  M.egg(q,.5,1.0,.3,.55,'pink',1);M.egg(q,-.6,1.0,-.2,.5,'mint',2);M.egg(q,0,1.1,-.6,.5,'lilac',3)
  M.bow(q,0,1.7,1.7,.5,'pink')
  G.append(g,G.translate(q,0,band-4.2,r+2.4,0,1))
 elseif holiday=='july'then
  M.flag(g,r,band-4,0,7,6,-.5)
  ring(g,0,band-1,0,r+.12,.3,'red',8,false,3);ring(g,0,band-1.8,0,r+.12,.3,'ivory',8,false,3);ring(g,0,band-2.6,0,r+.12,.3,'blue',8,false,3)
 elseif holiday=='harvest'then
  local q=G.new();M.cornShock(q,0,0,.55,seed)
  G.append(g,G.translate(q,0,band-6,r+.3,0,1))
  ring(g,0,band-2.6,0,r+.15,.32,'rope',8,false,3)
  for i=0,9 do local a=i*2*pi/10;local x,z=math.cos(a)*(r+.5),math.sin(a)*(r+.5)
   G.quad(g,{x,band-2.2,z},{x+math.cos(a)*1.2,band-3.0,z+math.sin(a)*1.2},{x+math.cos(a+.5),band-3.6,z+math.sin(a+.5)},{x,band-2.9,z},i%3==0 and 'leafRed'or i%3==1 and 'leafGold'or 'leafOrange')
  end
 end
 g.props=g.props+1
end
-- TEST150: Pumpkin patch and hayride ---------------------------------------
-- 3x5 block letters for hand-painted signs (only the letters these use).
local FONT={
 A={'010','101','111','101','101'},C={'011','100','100','100','011'},D={'110','101','101','101','110'},
 E={'111','100','110','100','111'},H={'101','101','111','101','101'},I={'111','010','010','010','111'},
 K={'1001','1010','1100','1010','1001'},M={'10001','11011','10101','10001','10001'},N={'110','101','101','101','101'},
 P={'110','101','110','100','100'},R={'110','101','110','101','101'},S={'011','100','010','001','110'},
 T={'111','010','010','010','010'},U={'101','101','101','101','111'},Y={'101','101','010','010','010'},
 O={'010','101','101','101','010'},F={'111','100','110','100','100'},W={'10001','10001','10101','11011','10001'},
}
-- Painted lettering standing just proud of a board facing +z.
local function textWidth(text,px)
 local w=0
 for i=1,#text do local glyph=FONT[text:sub(i,i)];w=w+((glyph and #glyph[1]or 3)+1)*px end
 return w-px
end
local function letters(g,text,cx,cy,z,px,mat)
 local x=cx-textWidth(text,px)/2
 for i=1,#text do local glyph=FONT[text:sub(i,i)];local cols=glyph and #glyph[1]or 3
  if glyph then for row=1,5 do for col=1,cols do
   if glyph[row]:sub(col,col)=='1'then
    G.box(g,x+(col-.5)*px,cy+(5-row)*px,z,px,px,.3,mat)
   end
  end end end
  x=x+(cols+1)*px
 end
end
M.textWidth=textWidth
M.letters=letters
-- A field pumpkin (no face): fewer facets than a carved lantern.
local function fieldPumpkin(g,x,y,z,r,mat,seed)
 G.sphere(g,x,y+r*.68,z,r,r*.70,r,mat or 'orange',16,7,nil,8)
 local lean=(G.hash(seed or 1,7)-.5)*.5
 G.tube(g,{x,y+r*1.34,z},{x+r*lean*.4,y+r*1.66,z+r*.08},r*.12,'bark',4,r*.07)
end
-- Fenced patch, centred on the origin, entrance and sign facing +z.
function M.pumpkinPatch(opts)
 local g=G.new();local w,d=opts.w or 96,opts.d or 48;local seed=opts.seed or 1
 local lit=opts.holiday=='halloween';local mini=opts.mini
 local hw,hd=w/2-2,d/2-2
 -- Tilled bed with raised rows and a straw path down the middle.
 G.box(g,0,0,0,w-6,.28,d-6,'soil')
 local rows=math.max(2,math.floor((d-12)/8.5))
 for r=1,rows do
  local z=-hd+5+(r-.5)*((d-10)/rows)
  G.box(g,0,.28,z,w-12,.55,3.4,'soil')
  -- Vine: a wandering stem with broad leaves along the whole row.
  local prev
  for i=0,math.floor((w-14)/2.5)do
   local x=-(w-14)/2+i*2.5;local p={x,.95,z+math.sin(x*.37+r*1.7)*1.1}
   if prev then G.tube(g,prev,p,.16,'green',4,nil,nil,false)end
   if i%2==0 then local a=G.hash(i,r,seed)*6.28;local L=1.3+G.hash(i,r)*.7
    local side=i%4==0 and 1 or -1
    G.quad(g,p,{p[1]+math.cos(a)*L,.9,p[3]+side*L*.9},{p[1]+math.cos(a+.9)*L*1.2,1.05,p[3]+side*L*1.5},{p[1]+math.cos(a+1.6)*L*.6,.95,p[3]+side*L*.7},i%3==0 and 'mint'or 'green')
   end
   prev=p
  end
  -- Pumpkins of every size along the vine; a few carved and glowing.
  local n=math.max(3,math.floor((w-16)/(mini and 9 or 8)))
  for i=1,n do
   local x=-(w-18)/2+(i-.5)*((w-18)/n)+(G.hash(i,r,seed)-.5)*3
   if math.abs(x)>4 or mini then
    local zz=z+(G.hash(r,i,3)-.5)*1.6;local rad=1.2+G.hash(i,r,11)*1.9
    local roll=G.hash(i*3,r,seed+5)
    if lit and roll<.18 then M.pumpkin(g,x,.6,zz,rad,true,i+r*7)
    else fieldPumpkin(g,x,.6,zz,rad,roll>.90 and 'ivory'or roll>.82 and 'gourd'or 'orange',i+r)end
   end
  end
 end
 -- Straw walk from the entrance to the scarecrow.
 if not mini then for z=hd-2,-hd+6,-2.2 do G.box(g,(G.hash(z*3,1)-.5)*.6,.3,z,4.2,.12,1.9,'hay',(G.hash(z,2)-.5)*.2)end end
 -- Split-rail fence with an opening in the front.
 local gate=mini and 10 or 16
 local function post(x,z)G.tube(g,{x,0,z},{x,6.2,z},.42,'bark',5,.36);G.box(g,x,6.1,z,1.0,.35,1.0,'wood')end
 local function rail(a,b)G.tube(g,{a[1],2.4,a[2]},{b[1],2.4,b[2]},.24,'wood',4,nil,nil,false);G.tube(g,{a[1],4.7,a[2]},{b[1],4.7,b[2]},.24,'wood',4,nil,nil,false)end
 local function side(a,b,skip)
  local dx,dz=b[1]-a[1],b[2]-a[2];local L=math.sqrt(dx*dx+dz*dz);local n=math.max(1,math.floor(L/8+.5))
  for i=0,n do local t=i/n;local x,z=a[1]+dx*t,a[2]+dz*t
   if not(skip and math.abs(x)<gate/2-.1)then post(x,z)end
   if i>0 then local t0=(i-1)/n;local x0,z0=a[1]+dx*t0,a[2]+dz*t0
    if not(skip and((x0<gate/2 and x>-gate/2)))then rail({x0,z0},{x,z})end
   end
  end
 end
 side({-hw,-hd},{hw,-hd});side({-hw,-hd},{-hw,hd});side({hw,-hd},{hw,hd})
 -- Front fence in two halves either side of the entrance.
 side({-hw,hd},{-gate/2,hd});side({gate/2,hd},{hw,hd})
 -- Ranch arch over the entrance with a hand-painted sign and lanterns.
 local top=mini and 9.5 or 12.5
 for _,x in ipairs({-gate/2,gate/2})do G.tube(g,{x,0,hd},{x,top+1.4,hd},.62,'bark',6,.52)end
 local text=mini and 'PUMPKINS'or 'PUMPKIN PATCH'
 local px=mini and .5 or .55;local bw=textWidth(text,px)+3
 G.box(g,0,top-1.2,hd+.1,bw,px*5+2.4,.8,'wood')
 G.box(g,0,top-1.45,hd+.05,bw+.6,.35,.95,'deadwood');G.box(g,0,top+px*5+1.0,hd+.05,bw+.6,.35,.95,'deadwood')
 letters(g,text,0,top,hd+.65,px,'orange')
 for _,x in ipairs({-gate/2,gate/2})do
  G.tube(g,{x,top-1.6,hd+.6},{x,top-3.2,hd+.6},.06,'iron',3)
  M.lantern(g,x,top-6.6,hd+.6,1.0,'halloween',nil,true)
 end
 -- Scarecrow keeping watch, corn shocks at the back corners, crows.
 if not mini then
  M.scarecrow(g,0,.3,-hd+7,.42,'green',lit and nil or 'sack')
  M.cornShock(g,-hw+4,-hd+4,.9,seed);M.cornShock(g,hw-4,-hd+4,.85,seed+1)
  M.crow(g,-hw,6.5,-hd+16,.75,.6);M.crow(g,hw,6.5,4,.75,-1.2)
 else M.cornShock(g,-hw+3,-hd+3,.7,seed)end
 -- Hay bales stacked outside by the entrance, pumpkins for sale on top.
 M.hay(g,-gate/2-7,0,hd+4.5,8,3.4,4.6,seed);M.hay(g,-gate/2-7,3.4,hd+4.3,6.4,3.0,4.0,seed+1)
 fieldPumpkin(g,-gate/2-8.5,6.4,hd+4.3,1.6,'orange',3);fieldPumpkin(g,-gate/2-5.6,6.4,hd+4.6,1.2,'ivory',4)
 if lit then M.pumpkin(g,gate/2+5.5,0,hd+4.4,2.2,true,seed+9)else fieldPumpkin(g,gate/2+5.5,0,hd+4.4,2.2,'orange',9)end
 g.props=g.props+1
 return g
end
-- Hay wagon for hayrides: long axis along x, facing +z.
function M.hayride(opts)
 local g=G.new();local seed=opts.seed or 1;local lit=opts.holiday=='halloween'
 local L,Wd,deck=40,16,5.6
 -- Wheels: wooden rims and spokes on iron hubs, axles across.
 for _,x in ipairs({-13,13})do
  for _,z in ipairs({-Wd/2-1.1,Wd/2+1.1})do
   ring(g,x,4.6,z,4.3,.42,'wood',16,true,4)
   ring(g,x,4.6,z,4.55,.16,'iron',16,true,3)
   for i=0,9 do local a=i*pi/5;G.tube(g,{x,4.6,z},{x+math.cos(a)*4.1,4.6+math.sin(a)*4.1,z},.17,'wood',3)end
   G.tube(g,{x,4.6,z-.7},{x,4.6,z+.7},.75,'iron',8)
  end
  G.tube(g,{x,4.6,-Wd/2-1.1},{x,4.6,Wd/2+1.1},.32,'iron',5)
 end
 -- Bed, side boards with slats, and a hitch tongue at the front.
 G.box(g,0,deck,0,L,1.1,Wd,'wood')
 G.box(g,0,deck-.9,0,L-2,.9,Wd-3,'deadwood')
 for _,z in ipairs({-Wd/2+.35,Wd/2-.35})do
  G.box(g,0,deck+1.1,z,L,.5,.7,'wood');G.box(g,0,deck+3.2,z,L,.5,.7,'wood')
  for x=-L/2+.5,L/2-.4,4 do G.box(g,x,deck+1.1,z,.7,2.6,.8,'bark')end
 end
 G.box(g,-L/2+.35,deck+1.1,0,.7,2.6,Wd,'wood')
 G.tube(g,{L/2,deck+.2,0},{L/2+12,1.4,0},.42,'wood',5)
 G.tube(g,{L/2+12,1.4,-3},{L/2+12,1.4,3},.32,'wood',5)
 G.box(g,L/2+12,0,0,2.4,1.1,2.4,'wood')
 -- Hay-bale benches for riders, with pumpkins riding along.
 for _,z in ipairs({-3.6,3.6})do
  for _,x in ipairs({-12,0,12})do M.hay(g,x,deck+1.1,z,9.4,3.0,4.6,seed+x+z)end
 end
 M.hay(g,-15,deck+4.1,-3.6,6,2.6,4.2,seed+3)
 fieldPumpkin(g,-15,deck+6.7,-3.6,1.5,'orange',5)
 if lit then M.pumpkin(g,16.5,deck+1.1,0,1.8,true,seed+2)else fieldPumpkin(g,16.5,deck+1.1,0,1.8,'orange',6)end
 -- Painted HAYRIDE board on the side facing the street.
 G.box(g,0,deck+1.4,Wd/2+.4,20,3.6,.5,'red')
 letters(g,'HAYRIDE',0,deck+1.9,Wd/2+.75,.5,'ivory')
 -- Lantern pole at the front corner, string of lights along both rails.
 G.tube(g,{L/2-1,deck,Wd/2-1},{L/2-1,deck+15,Wd/2-1},.32,'bark',5)
 G.tube(g,{L/2-1,deck+15,Wd/2-1},{L/2+2.5,deck+15,Wd/2-1},.2,'iron',4)
 M.lantern(g,L/2+2.5,deck+10.6,Wd/2-1,1.05,'halloween',nil,true)
 for _,z in ipairs({-Wd/2+.35,Wd/2-.35})do
  local prev
  for i=0,16 do local x=-L/2+1+i*(L-2)/16;local y=deck+5.2-math.sin(i/2*pi)^2*.6
   local p={x,y,z};if prev then G.tube(g,prev,p,.05,'black',3,nil,nil,false)end
   if i%2==1 then G.bulb(g,x,y-.35,z,.32,lit and(i%4==1 and 'orange'or 'warm')or 'warm',true)end
   prev=p
  end
 end
 -- Little step crate at the back and loose straw on the ground.
 G.box(g,-L/2-2.6,0,2,3.4,2.6,3.4,'wood')
 for i=1,10 do local x=(G.hash(i,seed)-.5)*L;local z=(G.hash(seed,i)-.5)*Wd*1.4
  G.box(g,x,.05,z,1.6,.1,.4,'hay',G.hash(i,3)*3)
 end
 g.props=g.props+1
 return g
end

-- TEST154: Festive field pieces ---------------------------------------------
-- Inflatables: smooth puffy bodies that glow softly from inside at night,
-- standing on a skirt with a little blower fan, guy ropes and stakes.
local GLOW=65.15
local function puff(g,x,y,z,rx,ry,rz,mat,lobes)
 G.sphere(g,x,y,z,rx,ry,rz,mat,18,10,GLOW,lobes)
end
local function puffTube(g,a,b,r,mat,r2)G.tube(g,a,b,r,mat,10,r2,GLOW,true)end
local function inflatableBase(g,r,seed)
 G.disc(g,0,.06,0,r,'black',16)
 G.box(g,r*.75,0,r*.55,2.2,1.6,1.8,'black')
 G.tube(g,{r*.75,1.2,r*.55-.9},{r*.4,.6,r*.2},.35,'black',6)
 for i=0,3 do local a=i*pi/2+pi/4+(seed or 0)*.1
  local top={math.cos(a)*r*.55,r*1.25,math.sin(a)*r*.55}
  local stake={math.cos(a)*(r+3.5),0,math.sin(a)*(r+3.5)}
  G.tube(g,top,{stake[1],.5,stake[3]},.06,'white',3)
  G.tube(g,stake,{stake[1],.9,stake[3]},.16,'silver',4)
 end
end
function M.inflatableSnowman(g,x,z,s)
 local q=G.new()
 inflatableBase(q,6.2,1)
 puff(q,0,6.0,0,6.2,6.0,6.2,'snow');puff(q,0,14.4,0,4.7,4.6,4.7,'snow');puff(q,0,21.2,0,3.7,3.6,3.7,'snow')
 for _,dx in ipairs({-1.3,1.3})do G.sphere(q,dx,22.0,3.35,.5,.6,.25,'coal',6,4)end
 G.tube(q,{0,21.0,3.4},{.25,20.6,7.4},.85,'orange',8,.05,GLOW)
 for i=-2,2 do local a=i*.28;G.sphere(q,math.sin(a)*3.0,19.4-math.abs(i)*.0+(-math.cos(a)*.6),math.cos(a)*3.0+.2,.28,.28,.2,'coal',5,3)end
 ring(q,0,18.0,0,3.7,.95,'red',16,false,6,GLOW)
 puffTube(q,{2.2,17.4,3.0},{2.9,12.6,4.2},.9,'red',.8)
 for i=0,2 do G.sphere(q,0,15.5-i*2.6,4.55+i*.35,.48,.48,.3,'coal',6,4)end
 G.tube(q,{0,24.3,0},{0,24.9,0},5.0,'black',16,nil,nil,true)
 G.tube(q,{0,24.9,0},{0,29.4,0},3.1,'black',16,nil,nil,true)
 G.tube(q,{0,25.3,0},{0,26.2,0},3.15,'red',16,nil,GLOW,false)
 for side=-1,1,2 do
  puffTube(q,{side*4.0,15.4,0},{side*8.6,18.6,.6},1.25,'snow',1.1)
  puff(q,side*9.2,19.2,.7,1.5,1.5,1.4,'red')
 end
 G.append(g,G.translate(q,x,0,z,0,s));g.props=g.props+1
end
function M.inflatableSanta(g,x,z,s)
 local q=G.new()
 inflatableBase(q,6.4,2)
 for _,dx in ipairs({-2.4,2.4})do puff(q,dx,1.6,.9,2.0,1.6,2.8,'black');puffTube(q,{dx,2.6,0},{dx,6.2,0},2.0,'red',2.2)end
 puff(q,0,11.4,0,6.6,6.8,6.0,'red')
 ring(q,0,7.0,0,5.6,.9,'white',18,false,6,GLOW)
 G.tube(q,{0,10.3,0},{0,11.9,0},6.25,'black',18,nil,GLOW,false)
 G.box(q,0,10.15,5.95,2.6,1.9,.6,'gold')
 puff(q,0,16.8,4.0,4.2,3.6,2.4,'white')          -- beard
 puff(q,0,20.4,0,3.8,3.7,3.6,'cream')            -- face
 puff(q,0,20.0,3.5,.75,.7,.6,'pink')              -- nose
 for _,dx in ipairs({-1.3,1.3})do G.sphere(q,dx,21.6,3.25,.42,.5,.22,'coal',6,4)end
 puff(q,0,19.4,2.8,2.6,.9,1.2,'white')            -- moustache
 ring(q,0,23.4,0,3.9,1.1,'white',18,false,6,GLOW) -- hat brim
 G.tube(q,{0,23.4,0},{1.6,30.0,-1.0},3.7,'red',14,.6,GLOW,true)
 puff(q,1.9,30.2,-1.1,1.4,1.4,1.4,'white')
 puffTube(q,{-5.6,14.0,0},{-9.4,19.6,.8},1.7,'red',1.4)   -- waving arm
 puff(q,-9.8,20.6,.9,1.5,1.6,1.4,'white')
 puffTube(q,{5.6,13.2,0},{8.4,9.2,1.4},1.7,'red',1.4)
 puff(q,8.6,8.4,1.6,1.5,1.5,1.4,'white')
 G.append(g,G.translate(q,x,0,z,0,s));g.props=g.props+1
end
function M.inflatablePresents(g,x,z,s)
 local q=G.new()
 inflatableBase(q,6.0,3)
 local boxes={{-2.2,0,7.2,'red','gold'},{3.4,0,5.6,'green','red'},{-.2,7.0,5.0,'gold','green'}}
 for i,b in ipairs(boxes)do local bx,by,size=b[1],b[2],b[3]
  -- square inflated boxes: 4-sided tubes with soft glow, ribbons across
  G.tube(q,{bx,by+.2,0},{bx,by+size,0},size*.72,b[4],4,nil,GLOW,true)
  G.tube(q,{bx,by+.15,0},{bx,by+size+.05,0},size*.74,b[5],4,size*.74,GLOW,false)
  G.box(q,bx,by+.1,0,size*1.06,size+.12,size*.22,b[5])
 end
 -- bow on top
 for side=-1,1,2 do puffTube(q,{-.2,12.2,0},{-.2+side*2.6,13.8,.4},1.0,'red',1.4)end
 puff(q,-.2,12.4,0,1.0,.9,1.0,'red')
 G.append(g,G.translate(q,x,0,z,0,s));g.props=g.props+1
end
function M.inflatablePumpkin(g,x,z,s)
 local q=G.new()
 inflatableBase(q,7.0,4)
 M.pumpkin(q,0,0,0,7.2,true,21)
 -- witch hat with a purple band
 G.tube(q,{0,9.6,0},{0,10.2,0},6.2,'black',16,nil,nil,true)
 G.tube(q,{0,10.2,0},{1.4,19.0,-1.2},3.6,'black',14,.3,nil,true)
 G.tube(q,{0,10.25,0},{.15,11.4,-.12},3.5,'purple',14,3.3,GLOW,false)
 G.append(g,G.translate(q,x,0,z,0,s));g.props=g.props+1
end
function M.inflatableGhost(g,x,z,s)
 local q=G.new()
 inflatableBase(q,6.0,5)
 M.ghost(q,0,1.0,0,2.3,0,'ghost')
 G.append(g,G.translate(q,x,0,z,0,s));g.props=g.props+1
end
function M.inflatableCat(g,x,z,s)
 local q=G.new()
 inflatableBase(q,6.4,6)
 puff(q,0,6.6,-.6,5.6,6.4,5.0,'black')
 puff(q,0,15.6,.8,4.4,4.0,4.0,'black')
 for side=-1,1,2 do
  G.tri(q,{side*1.4,18.6,.8},{side*4.2,18.0,.6},{side*3.4,22.2,.4},'black',GLOW)
  G.tri(q,{side*1.9,18.9,1.0},{side*3.7,18.5,.9},{side*3.2,21.2,.8},'pink',GLOW)
  G.sphere(q,side*1.6,16.4,4.35,.9,1.15,.35,'slime',8,5,66)   -- glowing eyes
  G.sphere(q,side*1.6,16.4,4.62,.25,.8,.12,'black',5,3)
  for k=-1,1 do G.tube(q,{side*1.2,14.8,4.6},{side*5.6,14.8+k*.8,4.4},.06,'white',3)end
 end
 G.sphere(q,0,15.2,4.65,.4,.32,.2,'pink',5,3)
 local tail={{-3.8,4.0,-3.6},{-6.4,7.0,-4.4},{-7.2,12.0,-3.8},{-6.0,16.0,-3.2},{-4.2,17.4,-2.4}}
 for i=2,#tail do puffTube(q,tail[i-1],tail[i],1.1-.12*i,'black',1.0-.12*i)end
 ring(q,0,12.8,.8,3.6,.55,'orange',14,false,5,GLOW)
 G.sphere(q,0,12.2,4.4,.9,.9,.6,'gold',8,5,GLOW)
 G.append(g,G.translate(q,x,0,z,0,s));g.props=g.props+1
end
-- Santa's sleigh and a reindeer team, travelling toward +x.
local function solidReindeer(q,x,z,s,seed)
 local r=G.new()
 G.sphere(r,0,7.6,0,5.0,2.9,2.4,'rope',14,8)                 -- body
 G.sphere(r,.6,6.4,0,3.6,1.6,2.0,'cream',12,6)                -- belly
 G.tube(r,{3.6,8.6,0},{5.6,12.6,0},1.35,'rope',8,1.0)          -- neck
 G.sphere(r,6.4,13.4,0,2.0,1.4,1.3,'rope',10,6)                -- head
 G.sphere(r,8.1,12.9,0,.9,.7,.8,'cream',8,5)                   -- muzzle
 G.sphere(r,8.9,13.0,0,.35,.35,.35,'coal',6,4)                 -- nose
 for side=-1,1,2 do
  G.sphere(r,6.9,14.0,side*1.05,.28,.28,.15,'coal',5,3)
  G.tri(r,{5.6,14.4,side*.9},{5.2,15.4,side*2.0},{4.9,14.6,side*1.3},'rope')
  -- antlers
  local a={6.0,14.6,side*.7};local b={5.4,17.8,side*2.0};local c={6.6,20.0,side*3.2}
  G.tube(r,a,b,.24,'ivory',4);G.tube(r,b,c,.2,'ivory',4)
  G.tube(r,b,{3.8,19.0,side*2.4},.18,'ivory',4);G.tube(r,{6.0,18.9,side*2.6},{7.6,19.6,side*2.2},.16,'ivory',4)
 end
 -- galloping legs: fore pair reaching, hind pair pushing
 local step=seed%2==0 and 1 or -1
 for side=-1,1,2 do
  G.tube(r,{3.0,6.6,side*1.2},{5.6+step*.6,2.6,side*1.2},.55,'rope',6,.45)
  G.tube(r,{5.6+step*.6,2.6,side*1.2},{6.6,.9,side*1.2},.42,'rope',6,.32)
  G.tube(r,{-3.0,6.6,side*1.2},{-5.6,3.0,side*1.2},.6,'rope',6,.45)
  G.tube(r,{-5.6,3.0,side*1.2},{-4.8,.3,side*1.2},.42,'rope',6,.32)
 end
 G.sphere(r,-5.0,9.2,0,.9,.7,.6,'cream',6,4)                   -- tail
 -- red harness with gold bells
 do local prev
  for i=0,14 do local a=i*2*pi/14;local p={1.6,7.6+math.cos(a)*3.05,math.sin(a)*2.55}
   if prev then G.tube(r,prev,p,.32,'red',4,nil,nil,false)end;prev=p
  end
 end
 for i=-1,1 do G.sphere(r,1.6,4.7,i*1.3,.42,.42,.42,'gold',6,4,65.3)end
 G.tube(r,{1.6,10.5,0},{-4.0,8.9,0},.28,'red',4)
 G.append(q,G.translate(r,x,0,z,0,s))
end
-- TEST161: a toy-soldier nutcracker, about 22 units tall at s=1, facing +z.
-- Jacket/trouser colours vary by seed; GLOW-free so it reads as painted wood.
local NUT_JACKET={'red','crimson','blue','green','red'}
local NUT_PANTS={'white','blue','black','white','ivory'}
function M.nutcracker(g,x,z,s,seed,yaw)
 seed=seed or 1
 local q=G.new()
 local jacket=NUT_JACKET[seed%#NUT_JACKET+1];local pants=NUT_PANTS[(seed*3)%#NUT_PANTS+1]
 if pants==jacket then pants='white'end
 -- plinth
 G.box(q,0,0,0,6.4,1.2,5.2,'wood');G.box(q,0,1.2,0,6.7,.42,5.5,'gold')
 -- boots and trousers
 for _,dx in ipairs({-1.05,1.05})do
  G.tube(q,{dx,1.6,0},{dx,3.8,0},1.05,'black',8,1.0)
  G.box(q,dx,1.6,.55,1.9,1.0,1.6,'black')
  G.tube(q,{dx,3.8,0},{dx,7.4,0},.92,pants,8,1.0)
 end
 -- body, belt, buttons, epaulettes, cross-sash
 G.tube(q,{0,7.0,0},{0,12.8,0},2.35,jacket,10,2.05)
 G.tube(q,{0,7.4,0},{0,8.3,0},2.42,'black',10,2.38)
 G.box(q,0,7.45,2.25,1.1,.8,.35,'gold')
 for i,yy in ipairs({9.3,10.5,11.7})do G.sphere(q,0,yy,2.18,.28,.28,.2,'gold',6,4)end
 G.box(q,0,9.0,1.95,3.6,.55,.4,'gold',0)
 for _,dx in ipairs({-2.45,2.45})do
  G.sphere(q,dx,12.5,0,1.0,.55,1.0,'gold',8,4)
  G.tube(q,{dx,12.3,0},{dx*1.22,8.6,.7},.78,jacket,8,.7)
  G.tube(q,{dx*1.22,8.8,.7},{dx*1.24,8.2,.75},.82,'gold',8,.82)
  G.sphere(q,dx*1.24,7.75,.8,.72,.72,.72,'cream',8,5)
 end
 -- a sword at the right hand
 G.tube(q,{3.05,6.2,1.1},{3.05,14.2,1.1},.2,'silver',5,.12)
 G.box(q,3.05,8.6,1.1,1.6,.3,.5,'gold')
 -- head: face, big white beard and jaw, moustache, eyes, nose, cheeks, hair
 G.tube(q,{0,12.7,0},{0,13.4,0},1.0,'cream',8)
 G.sphere(q,0,14.9,0,2.05,2.25,2.0,'cream',12,8)
 G.box(q,0,12.9,1.05,3.4,1.75,1.9,'white')
 G.box(q,0,14.15,1.98,2.5,.48,.34,'white')
 for _,dx in ipairs({-.72,.72})do
  G.sphere(q,dx,15.45,1.82,.27,.3,.16,'coal',6,4)
  G.sphere(q,dx*1.9,14.6,1.55,.42,.32,.2,'pink',6,4)
  G.box(q,dx*2.65,15.0,-.2,.7,2.4,2.2,'white')
 end
 G.sphere(q,0,14.85,2.05,.42,.42,.36,'pink',6,4)
 -- shako hat with gold bands, badge and plume
 G.tube(q,{0,16.4,0},{0,20.6,0},2.05,'black',12,2.25)
 G.tube(q,{0,16.35,0},{0,16.95,0},2.12,'gold',12,2.14)
 G.tube(q,{0,20.0,0},{0,20.65,0},2.27,'gold',12,2.28)
 G.sphere(q,0,18.4,2.12,.62,.62,.22,'gold',8,5)
 G.tube(q,{0,20.6,0},{.2,23.0,-.2},.62,'white',6,.24)
 G.tube(q,{0,20.6,0},{-.1,22.2,-.1},.4,'crimson',6,.16)
 G.append(g,G.translate(q,x,0,z,yaw or 0,s or 1));g.props=(g.props or 0)+1
end
-- TEST157: a standing reindeer for the festive yards (faces +x, yaw turns it).
function M.reindeer(g,x,z,s,seed,yaw)
 local q=G.new();solidReindeer(q,0,0,1,seed or 1)
 G.append(g,G.translate(q,x,0,z,yaw or 0,s or 1));g.props=(g.props or 0)+1
end
function M.santaSleigh(opts)
 local g=G.new();local twinkle=true
 -- runners: curled gold blades
 for _,zz in ipairs({-5.2,5.2})do
  local pts={{-13,1.0,zz},{8,1.0,zz},{11.5,2.0,zz},{13.4,4.6,zz},{12.6,7.6,zz},{10.6,8.2,zz},{10.0,6.8,zz}}
  for i=2,#pts do G.tube(g,pts[i-1],pts[i],.42,'gold',6,nil,nil,false)end
  for _,xx in ipairs({-10,-3,4})do G.tube(g,{xx,1.0,zz},{xx,4.2,zz*.86},.32,'gold',5)end
 end
 -- body: low seat box, tall curled back, sweeping dash
 G.box(g,-3.5,4.0,0,17,4.6,10.6,'red')
 G.box(g,-11.6,4.0,0,3.2,11.2,10.6,'red')
 G.box(g,5.6,4.0,0,4.0,6.4,10.0,'red')
 G.box(g,8.4,6.0,0,2.6,6.8,9.2,'red')
 for _,zz in ipairs({-5.35,5.35})do
  G.box(g,-3.5,8.4,zz,17,.5,.5,'gold');G.box(g,-11.6,15.0,zz,3.4,.5,.5,'gold');G.box(g,8.4,12.6,zz,2.8,.5,.5,'gold')
  G.box(g,-3.5,5.8,zz*1.01,12,1.2,.25,'green')
 end
 G.box(g,-11.6,15.0,0,3.4,.5,11.0,'gold')
 G.box(g,-5.0,8.6,0,10,1.2,9.6,'crimson')    -- cushion
 -- Santa seated, reins in hand
 G.sphere(g,-5.4,12.2,0,3.6,3.8,3.4,'red',14,8)
 ring(g,-5.4,9.4,0,3.3,.55,'white',14,false,5)
 G.tube(g,{-5.4,11.3,0},{-5.4,12.3,0},3.55,'black',14,nil,nil,false)
 G.sphere(g,-3.0,14.6,0,2.0,2.4,2.4,'white',10,6)  -- beard
 G.sphere(g,-4.6,16.6,0,2.2,2.2,2.1,'cream',10,6)
 for _,zz in ipairs({-.75,.75})do G.sphere(g,-2.65,17.1,zz,.25,.28,.18,'coal',5,3)end
 G.sphere(g,-2.45,16.4,0,.45,.42,.42,'pink',6,4)
 ring(g,-4.6,18.5,0,2.3,.6,'white',14,false,5)
 G.tube(g,{-4.6,18.5,0},{-6.6,22.2,0},2.2,'red',12,.35,nil,true)
 G.sphere(g,-6.8,22.4,0,.8,.8,.8,'white',6,4)
 for _,zz in ipairs({-2.6,2.6})do
  G.tube(g,{-5.0,13.4,zz*1.15},{-1.6,11.6,zz*.9},.9,'red',6,.8)
  G.sphere(g,-1.2,11.5,zz*.85,.8,.8,.8,'white',6,4)
 end
 -- sack of presents behind him
 G.sphere(g,-10.2,15.6,0,3.0,3.4,3.6,'rope',12,7)
 G.box(g,-10.6,17.6,-1.2,2.4,2.6,2.4,'green');G.box(g,-9.4,18.0,1.4,2.2,2.2,2.2,'blue');G.box(g,-11.0,18.4,1.0,1.8,2.2,1.8,'gold')
 -- the team: three pairs, each harnessed to a central trace
 local team={}
 for i=0,(opts.pairs or 3)-1 do for _,zz in ipairs({-3.2,3.2})do
  local rx=20+i*15;solidReindeer(g,rx,zz,.95,i*2+(zz>0 and 1 or 0));team[#team+1]={rx,zz}
 end end
 G.tube(g,{10.4,5.2,0},{20+((opts.pairs or 3)-1)*15,7.2,0},.22,'gold',4)
 for _,t in ipairs(team)do
  G.tube(g,{-1.2,11.6,t[2]>0 and 2.2 or -2.2},{t[1]+1.5,10.2,t[2]},.07,'black',3)  -- reins
  G.tube(g,{t[1]-3.4,7.4,t[2]},{t[1]-3.4,6.9,0},.15,'red',3)
 end
 -- twinkling lights along the sleigh's gold trim
 for _,zz in ipairs({-5.6,5.6})do for i=0,8 do local xx=-11.5+i*2.4
  G.bulb(g,xx,8.9,zz,.34,i%2==0 and 'warm'or 'red',twinkle)
 end end
 g.props=g.props+1
 return g
end

return M
