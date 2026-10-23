-- Sculpted civic symbols, batched into their host building above walk clearance.
local M={};local pi=math.pi
local function disk(K,x,y,z,r,mat,n)
 n=n or 32
 for i=0,n-1 do local a,b=i*2*pi/n,(i+1)*2*pi/n
  K.face({x,y,z},{x+r*math.cos(a),y+r*math.sin(a),z},{x+r*math.cos(b),y+r*math.sin(b),z},{x+r*math.cos(b),y+r*math.sin(b),z},mat,1)
 end
end
local function rim(K,x,y,z,r,inner,mat)
 for i=0,31 do local a,b=i*pi/16,(i+1)*pi/16
  local function p(t,rr,zz)return{x+rr*math.cos(t),y+rr*math.sin(t),zz}end
  K.face(p(a,r,z),p(b,r,z),p(b,inner,z+.13),p(a,inner,z+.13),mat,1.12)
  K.face(p(a,r,z-.55),p(b,r,z-.55),p(b,r,z),p(a,r,z),mat,.8)
 end
end
function M.center(K,x,y,z,r,frame)
 frame=frame or'ktBronze'
 K.box(x-r*.65,y-r-2.1,z-.8,x+r*.65,y-r+.4,z-.32,frame,1)
 rim(K,x,y,z,r+.65,r-.08,frame)
 disk(K,x,y,z+.05,r,'dark')
 for i=0,31 do local a,b=i*pi/16,(i+1)*pi/16;local rr=r-.55
  K.face({x,y,z+.19},{x+rr*math.cos(a),y+rr*math.sin(a),z+.19},{x+rr*math.cos(b),y+rr*math.sin(b),z+.19},{x+rr*math.cos(b),y+rr*math.sin(b),z+.19},i<16 and'red'or'extrim',1.03)
 end
 K.box(x-r+.53,y-.42,z+.20,x+r-.53,y+.42,z+.42,'dark',1)
 disk(K,x,y,z+.44,r*.31,'dark');disk(K,x,y,z+.50,r*.20,'extrim')
end
function M.mart(K,x,y,z,r,accent,frame)
 accent=accent or'ktMarine';frame=frame or'ktBronze'
 -- Large enamel shopping tote with a raised handle and small ball clasp.
 K.box(x-r*.63,y-r-1.9,z-.65,x+r*.63,y-r+.15,z-.3,frame,1)
 K.box(x-r*.93,y-r*.86,z-.3,x+r*.93,y+r*.53,z+.35,frame,1.06)
 K.box(x-r*.81,y-r*.73,z+.36,x+r*.81,y+r*.42,z+.59,accent,1)
 for i=0,15 do local a,b=i*pi/16,(i+1)*pi/16
  K.beam({x+math.cos(a)*r*.49,y+r*.38+math.sin(a)*r*.50,z+.22},{x+math.cos(b)*r*.49,y+r*.38+math.sin(b)*r*.50,z+.22},.66,frame,1)
 end
 disk(K,x,y-r*.12,z+.62,r*.34,'extrim');disk(K,x,y-r*.12,z+.69,r*.23,accent)
 K.box(x-r*.31,y-r*.12-.14,z+.72,x+r*.31,y-r*.12+.14,z+.80,'extrim',1)
 disk(K,x,y-r*.12,z+.82,r*.10,'extrim')
end
function M.research(K,x,y,z,r)
 -- Orbital instrument crest, attached to the lab's facade.
 disk(K,x,y,z,r,'ktBasalt');rim(K,x,y,z+.1,r+.4,r-.2,'ktBronze')
 for j=0,2 do local angle=j*pi/3
  for i=0,23 do local a,b=i*pi/12,(i+1)*pi/12
   local function pt(t)local u,v=math.cos(t)*r*.78,math.sin(t)*r*.31;return{x+u*math.cos(angle)-v*math.sin(angle),y+u*math.sin(angle)+v*math.cos(angle),z+.25}end
   K.beam(pt(a),pt(b),.22,'ktPearl',1)
  end
 end
 disk(K,x,y,z+.45,r*.17,'gold')
end
return M
