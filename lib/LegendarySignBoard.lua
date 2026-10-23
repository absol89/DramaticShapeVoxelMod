-- TEST39: Legendary Kanto wayfinder sign, redesigned.
-- Two timber posts on stone footings carry a framed board under a little
-- shingled roof. The cream enamel face has a blue header band, a round
-- Poke Ball badge and smooth stroke lettering (instead of 3x5 blocks).
-- Pure geometry: `emit(a,b,c,d,tone,shade,textured)` receives four points and
-- one of the sign swatches (dark/body/light wood, paper/ink/accent/red face).
-- The board stays inside its own 16-unit cell; collision is the original cell.
local M={REVISION='wayfinder-board-39'}
local cos,sin,pi,min,max,sqrt=math.cos,math.sin,math.pi,math.min,math.max,math.sqrt
-- Stroke font on a 4x6 grid (x 0..4, y 0..6, baseline 0).
local F={
 A={{{0,0},{0,4},{2,6},{4,4},{4,0}},{{0,2.6},{4,2.6}}},
 B={{{0,0},{0,6},{3,6},{4,5},{4,4},{3,3.2},{0,3.2}},{{3,3.2},{4,2.2},{4,1},{3,0},{0,0}}},
 C={{{4,5},{3,6},{1,6},{0,5},{0,1},{1,0},{3,0},{4,1}}},
 D={{{0,0},{0,6},{2.5,6},{4,4.5},{4,1.5},{2.5,0},{0,0}}},
 E={{{4,6},{0,6},{0,0},{4,0}},{{0,3.1},{3,3.1}}},
 F={{{4,6},{0,6},{0,0}},{{0,3.1},{3,3.1}}},
 G={{{4,5},{3,6},{1,6},{0,5},{0,1},{1,0},{3,0},{4,1},{4,2.8},{2.2,2.8}}},
 H={{{0,0},{0,6}},{{4,0},{4,6}},{{0,3.1},{4,3.1}}},
 I={{{1,6},{3,6}},{{2,6},{2,0}},{{1,0},{3,0}}},
 J={{{4,6},{4,1},{3,0},{1,0},{0,1}}},
 K={{{0,0},{0,6}},{{4,6},{0,2.2}},{{1.4,3.6},{4,0}}},
 L={{{0,6},{0,0},{4,0}}},
 M={{{0,0},{0,6},{2,3},{4,6},{4,0}}},
 N={{{0,0},{0,6},{4,0},{4,6}}},
 O={{{1,0},{0,1},{0,5},{1,6},{3,6},{4,5},{4,1},{3,0},{1,0}}},
 P={{{0,0},{0,6},{3,6},{4,5},{4,4},{3,3},{0,3}}},
 Q={{{1,0},{0,1},{0,5},{1,6},{3,6},{4,5},{4,1},{3,0},{1,0}},{{2.6,1.4},{4.2,-.4}}},
 R={{{0,0},{0,6},{3,6},{4,5},{4,4},{3,3},{0,3}},{{2,3},{4,0}}},
 S={{{4,5},{3,6},{1,6},{0,5},{0,4},{1,3.1},{3,3.1},{4,2.1},{4,1},{3,0},{1,0},{0,1}}},
 T={{{0,6},{4,6}},{{2,6},{2,0}}},
 U={{{0,6},{0,1},{1,0},{3,0},{4,1},{4,6}}},
 V={{{0,6},{2,0},{4,6}}},
 W={{{0,6},{1,0},{2,3.6},{3,0},{4,6}}},
 X={{{0,6},{4,0}},{{4,6},{0,0}}},
 Y={{{0,6},{2,3},{4,6}},{{2,3},{2,0}}},
 Z={{{0,6},{4,6},{0,0},{4,0}}},
 ['0']={{{1,0},{0,1},{0,5},{1,6},{3,6},{4,5},{4,1},{3,0},{1,0}},{{.6,1},{3.4,5}}},
 ['1']={{{1,4.8},{2.2,6},{2.2,0}},{{1,0},{3.4,0}}},
 ['2']={{{0,5},{1,6},{3,6},{4,5},{4,4},{0,0},{4,0}}},
 ['3']={{{0,5},{1,6},{3,6},{4,5},{4,4},{3,3.1},{1.6,3.1}},{{3,3.1},{4,2.2},{4,1},{3,0},{1,0},{0,1}}},
 ['4']={{{3,0},{3,6},{0,2},{4,2}}},
 ['5']={{{4,6},{0,6},{0,3.4},{3,3.4},{4,2.4},{4,1},{3,0},{1,0},{0,1}}},
 ['6']={{{3.6,6},{1.6,6},{0,4},{0,1},{1,0},{3,0},{4,1},{4,2.4},{3,3.4},{0,3.4}}},
 ['7']={{{0,6},{4,6},{1.4,0}}},
 ['8']={{{1,3.1},{0,4},{0,5},{1,6},{3,6},{4,5},{4,4},{3,3.1},{1,3.1},{0,2.1},{0,1},{1,0},{3,0},{4,1},{4,2.1},{3,3.1}}},
 ['9']={{{4,3},{1,3},{0,4},{0,5},{1,6},{3,6},{4,5},{4,2},{2.4,0},{.4,0}}},
}
M.font=F
local ADV,SPACE=5.3,3.2
function M.width(word,size)
 local u=0
 for i=1,#word do local ch=word:sub(i,i);u=u+(F[ch]and ADV or SPACE)end
 return (u-1.3)*size
end
function M.new(emit)
 local B={}
 -- Wood box with the requested tones on each side.
 local function box(x0,y0,z0,x1,y1,z1,top)
  emit({x0,y0,z1},{x1,y0,z1},{x1,y1,z1},{x0,y1,z1},'body',.96,true)
  emit({x1,y0,z0},{x0,y0,z0},{x0,y1,z0},{x1,y1,z0},'dark',.74,true)
  emit({x0,y1,z0},{x1,y1,z0},{x1,y1,z1},{x0,y1,z1},top or'light',1.0,false)
  emit({x0,y0,z0},{x0,y0,z1},{x0,y1,z1},{x0,y1,z0},'dark',.82,false)
  emit({x1,y0,z1},{x1,y0,z0},{x1,y1,z0},{x1,y1,z1},'body',.88,false)
 end
 B.box=box
 local function flat(x0,y0,x1,y1,z,tone,shade)emit({x0,y0,z},{x1,y0,z},{x1,y1,z},{x0,y1,z},tone,shade or 1,false)end
 -- A flat stroke segment on the plane z (front-facing).
 local function stroke(ax,ay,bx,by,w,z,tone)
  local dx,dy=bx-ax,by-ay;local l=sqrt(dx*dx+dy*dy)
  if l<1e-4 then dx,dy,l=1,0,1 end
  local nx,ny=-dy/l*w/2,dx/l*w/2;local ex,ey=dx/l*w/2,dy/l*w/2
  -- Extend each segment by half its width so joints close cleanly.
  ax,ay,bx,by=ax-ex,ay-ey,bx+ex,by+ey
  emit({ax+nx,ay+ny,z},{ax-nx,ay-ny,z},{bx-nx,by-ny,z},{bx+nx,by+ny,z},tone,.95,false)
 end
 local function word(text,cx,y,size,weight,z,tone)
  local x=cx-M.width(text,size)/2
  for i=1,#text do local ch=text:sub(i,i);local g=F[ch]
   if g then
    for _,line in ipairs(g)do
     for j=1,#line-1 do local a,b=line[j],line[j+1]
      stroke(x+a[1]*size,y+a[2]*size,x+b[1]*size,y+b[2]*size,weight,z,tone)
     end
    end
    x=x+ADV*size
   else x=x+SPACE*size end
  end
 end
 B.word=word
 local function disc(cx,cy,r,z,tone,a0,a1,n)
  n=n or 16
  for i=0,n-1 do local a=a0+(a1-a0)*i/n;local b=a0+(a1-a0)*(i+1)/n
   emit({cx,cy,z},{cx+r*cos(a),cy+r*sin(a),z},{cx+r*cos(b),cy+r*sin(b),z},{cx+r*cos(b),cy+r*sin(b),z},tone,1,false)
  end
 end
 local function pokeball(cx,cy,r,z)
  disc(cx,cy,r+.22,z,'ink',0,2*pi,20)
  disc(cx,cy,r,z+.01,'red',0,pi,12)
  disc(cx,cy,r,z+.01,'paper',pi,2*pi,12)
  flat(cx-r,cy-r*.12,cx+r,cy+r*.12,z+.02,'ink',.92)
  disc(cx,cy,r*.36,z+.03,'ink',0,2*pi,12)
  disc(cx,cy,r*.22,z+.04,'paper',0,2*pi,12)
 end
 -- The whole sign; (x,z) is the board centre, front face toward +z.
 function B.sign(x,z,label1,label2)
  local W,HALF=14.6,7.3
  local front=z-1.0
  -- Stone footings and two square posts.
  for _,px in ipairs({x-5.9,x+5.9})do
   emit({px-1.15,0,z-.55},{px+1.15,0,z-.55},{px+1.15,1.1,z-.55},{px-1.15,1.1,z-.55},'dark',.72,false)
   box(px-1.15,0,z-3.0,px+1.15,1.1,z-.55,'dark')
   box(px-.72,1.1,z-2.5,px+.72,15.2,z-1.05)
   box(px-.95,15.2,z-2.72,px+.95,15.75,z-.83,'light')
  end
  -- Board: thick frame, raised bevel and enamel face.
  local b0,b1=5.2,13.6
  box(x-HALF,b0,z-2.6,x+HALF,b1,z-1.3)                     -- back panel
  box(x-HALF,b1-.75,z-2.75,x+HALF,b1,z-.82)                -- top rail
  box(x-HALF,b0,z-2.75,x+HALF,b0+.75,z-.82)                -- bottom rail
  box(x-HALF,b0+.75,z-2.75,x-HALF+.75,b1-.75,z-.82)        -- left stile
  box(x+HALF-.75,b0+.75,z-2.75,x+HALF,b1-.75,z-.82)        -- right stile
  -- Inner bevel strip.
  local l,r,bo,t=x-HALF+.75,x+HALF-.75,b0+.75,b1-.75
  emit({l,bo,z-.82},{r,bo,z-.82},{r-.35,bo+.35,front},{l+.35,bo+.35,front},'light',.95,false)
  emit({l+.35,t-.35,front},{r-.35,t-.35,front},{r,t,z-.82},{l,t,z-.82},'dark',.8,false)
  emit({l,t,z-.82},{l,bo,z-.82},{l+.35,bo+.35,front},{l+.35,t-.35,front},'body',.85,false)
  emit({r,bo,z-.82},{r,t,z-.82},{r-.35,t-.35,front},{r-.35,bo+.35,front},'body',.92,false)
  -- Enamel face with a blue header band and fine paper pinstripe.
  local fl,fr,fb,ft=l+.35,r-.35,bo+.35,t-.35
  flat(fl,fb,fr,ft,front,'paper',1)
  flat(fl,ft-1.35,fr,ft,front+.02,'accent',1)
  flat(fl+.25,ft-1.6,fr-.25,ft-1.45,front+.02,'accent',1)
  flat(fl,fb,fr,fb+.32,front+.02,'accent',1)
  -- Header: "KANTO" in small paper letters.
  word('KANTO',(fl+fr)/2+.9,ft-1.12,.14,.17,front+.03,'paper')
  -- Badge.
  local bx,by=fl+1.75,(fb+ft-1.4)/2
  pokeball(bx,by,1.18,front+.03)
  -- Lettering, fitted to the space right of the badge.
  local tl,tr=bx+1.75,fr-.45;local avail=tr-tl;local cx=(tl+tr)/2
  local function fit(text,want)
   if not text or text=='' then return 0 end
   return min(want,avail/max(.01,M.width(text,1)))
  end
  local ct,cb=ft-1.75,fb+.5
  if label2 and label2~='' then
   local s1,s2=fit(label1,.36),fit(label2,.28);local gap=.55
   local total=6*s1+gap+6*s2;local top=(ct+cb)/2+total/2
   word(label1,cx,top-6*s1,s1,max(.2,s1*.6),front+.035,'ink')
   word(label2,cx,top-6*s1-gap-6*s2,s2,max(.18,s2*.62),front+.035,'ink')
  else
   local s1=fit(label1,.46)
   word(label1,cx,(ct+cb)/2-3*s1,s1,max(.2,s1*.6),front+.035,'ink')
  end
  -- Brass screw heads.
  for _,p in ipairs({{l+.4,bo+.4},{r-.4,bo+.4},{l+.4,t-.4},{r-.4,t-.4}})do
   disc(p[1],p[2],.2,z-.79,'light',0,2*pi,6)
  end
  -- Little shingled roof over the board.
  local ry,rz0,rz1,rp=b1+.35,z-3.6,z+.35,b1+2.3
  local mz=(rz0+rz1)/2
  emit({x-HALF-.8,ry,rz1},{x+HALF+.8,ry,rz1},{x+HALF+.8,rp,mz},{x-HALF-.8,rp,mz},'dark',.86,true)
  emit({x+HALF+.8,ry,rz0},{x-HALF-.8,ry,rz0},{x-HALF-.8,rp,mz},{x+HALF+.8,rp,mz},'dark',.7,true)
  for k=1,3 do local f=k/4;local yy=ry+(rp-ry)*f;local zz=rz1+(mz-rz1)*f
   emit({x-HALF-.8,yy-.02,zz},{x+HALF+.8,yy-.02,zz},{x+HALF+.8,yy+.16,zz-.28},{x-HALF-.8,yy+.16,zz-.28},'body',.78,false)
  end
  emit({x-HALF-.8,ry,rz0},{x-HALF-.8,ry,rz1},{x-HALF-.8,rp,mz},{x-HALF-.8,rp,mz},'body',.8,false)
  emit({x+HALF+.8,ry,rz1},{x+HALF+.8,ry,rz0},{x+HALF+.8,rp,mz},{x+HALF+.8,rp,mz},'body',.8,false)
  box(x-HALF-.9,rp-.12,mz-.3,x+HALF+.9,rp+.3,mz+.3,'light')  -- ridge
  box(x-HALF-.2,b1,z-2.75,x+HALF+.2,ry,z-.82)                  -- fascia
 end
 return B
end
return M
