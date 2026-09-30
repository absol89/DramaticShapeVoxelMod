-- Shared luxury entrance joinery for the native Casino and Prize Room shells.
-- Coordinates follow the shell: +Z faces the room, -Z recesses past the exit.
-- No collision, warp, atlas, material-setting or per-frame animation ownership.
local M={}
function M.add(box,quad,cx,prize)
 local left,right=cx-16,cx+16
 local function face(x,y,z,w,h,col,shade)
  quad({x,y,z},{x+w,y,z},{x+w,y+h,z},{x,y+h,z},col,shade)
 end
 local function rail(x,y,z,w,h,t,col)
  box(x,y,z,w,t,.22,col);box(x,y+h-t,z,w,t,.22,col)
  box(x,y+t,z,t,h-2*t,.22,col);box(x+w-t,y+t,z,t,h-2*t,.22,col)
 end
 local function diamond(x,y,z,w,h,col)
  quad({x-w,y,z},{x,y-h,z},{x+w,y,z},{x,y+h,z},col,1)
 end
 local function rod(x,y,z,h,r,col)
  for i=0,11 do
   local a,b=i*math.pi/6,(i+1)*math.pi/6
   quad({x+r*math.cos(a),y,z+r*math.sin(a)},
    {x+r*math.cos(b),y,z+r*math.sin(b)},
    {x+r*math.cos(b),y+h,z+r*math.sin(b)},
    {x+r*math.cos(a),y+h,z+r*math.sin(a)},col,.86+.12*math.sin(a))
   quad({x,y+h,z},{x+r*math.cos(a),y+h,z+r*math.sin(a)},
    {x+r*math.cos(b),y+h,z+r*math.sin(b)},{x,y+h,z},col,1)
  end
 end
 -- Continuous backing closes the old black/gray void. All leaf/hardware
 -- geometry remains behind the map edge, after both source warp cells.
 box(left-.1,0,-4.1,32.2,35.7,1,8)
 for side=0,1 do
  local x=left+.22+side*16
  box(x,.28,-3.25,15.56,34.85,.45,16)
  rail(x+.26,.65,-2.75,15.04,33.95,.45,3)
  rail(x+.85,1.3,-2.47,13.86,32.65,.16,4)
  -- Recessed panels use sloped bevels and adjacent grain strips. They do not
  -- stack coplanar decal planes, so the wood remains stable while orbiting.
  local function panel(y,h)
   local a,b=x+1.45,x+14.11;local low,high=y,y+h
   local inset=.58;local outer,inner=-2.35,-2.68
   quad({a,low,outer},{b,low,outer},{b-inset,low+inset,inner},{a+inset,low+inset,inner},3,.9)
   quad({b,low,outer},{b,high,outer},{b-inset,high-inset,inner},{b-inset,low+inset,inner},3,.78)
   quad({b,high,outer},{a,high,outer},{a+inset,high-inset,inner},{b-inset,high-inset,inner},4,1)
   quad({a,high,outer},{a,low,outer},{a+inset,low+inset,inner},{a+inset,high-inset,inner},3,.84)
   local width=b-a-2*inset
   for n=0,8 do
    local xx=a+inset+width*n/9;local span=width/9
    face(xx,low+inset,inner,span-.045,h-2*inset,16,.92+((n*3+side)%5)*.027)
    face(xx+span-.045,low+inset,inner,.045,h-2*inset,16,.78)
   end
  end
  panel(3.1,8.3);panel(13.5,18.6)
  -- Fine brass stringing and a compact fan motif over each raised panel.
  box(x+1.4,11.95,-2.32,12.75,.4,.32,3)
  box(x+1.8,12.36,-2.2,11.95,.12,.18,4)
  local mx=x+7.78
  diamond(mx,25.2,-2.45,3.1,4.25,3)
  diamond(mx,25.2,-2.24,2.62,3.64,8)
  diamond(mx,25.2,-2.03,.75,1.35,4)
  for _,sign in ipairs({-1,1})do
   for j=1,3 do
    local a={mx+sign*.32,22,-2.01}
    local b={mx+sign*(.9+j*.66),25.8+j*.55,-2.01}
    quad(a,b,{b[1]+.13,b[2],b[3]},{a[1]+.13,a[2],a[3]},3,1)
   end
  end
  -- Bronze kick plates, hinge caps and substantial round pull handles.
  box(x+1.45,1.55,-2.29,12.66,.75,.2,3)
  box(x+1.7,1.85,-2.05,12.16,.12,.14,4)
  local hinge=side==0 and x+.55 or x+14.5
  for _,y in ipairs({5,17,29})do rod(hinge,y,-2.18,1.6,.23,3)end
  local hx=side==0 and x+13.9 or x+1.66
  box(hx-.65,13.6,-2.05,1.3,7.1,.28,3)
  box(hx-.43,13.9,-1.7,.86,6.5,.16,8)
  for _,y in ipairs({14.7,19.2})do box(hx-.32,y,-1.52,.64,.55,.9,4)end
  rod(hx,14.85,-.59,4.7,.27,4)
 end
 -- Deep jambs show the recess; pilasters stay outside the full 32-unit exit.
 local p=prize and 2.3 or 3.3
 for side,x in ipairs({left-p,right})do
  box(x,0,-3.7,p,36.1,5.3,8)
  box(x+.17,.3,1.66,p-.34,34.7,.5,3)
  box(x+.43,1.2,2.23,p-.86,32.9,.28,1)
  for j=1,(prize and 2 or 3)do
   local xx=x+.5+(j-.5)*(p-1)/(prize and 2 or 3)
   box(xx,3.2,2.58,.16,29,.2,4)
  end
  box(x-(side==1 and .3 or 0),.05,1.48,p+.3,1.8,1.5,3)
  box(x-.3,34.1,1.48,p+.6,1.6,1.5,3)
  box(x-.48,35.85,1.2,p+.96,.55,2.1,4)
 end
 box(left-p-.5,35.8,-.2,32+2*p+1,1,3.7,3)
 box(left-p-.9,36.95,.25,32+2*p+1.8,.55,3.3,4)
 -- Warm transom with an Art Deco fan, scaled down for the companion room.
 local w=prize and 25 or 31;local h=prize and 4.8 or 6.3
 box(cx-w/2,37.65,.9,w,h,1.6,8)
 rail(cx-w/2,37.65,2.56,w,h,.35,3)
 face(cx-w/2+.7,38.35,2.65,w-1.4,h-1.4,5,.9)
 for j=-4,4 do
  local x=cx+j*(w-3)/9;local top=38.55+h-1.6-math.abs(j)*.35
  quad({cx+(j<0 and -.18 or .18),38.5,2.85},{x,top,2.85},
   {x+.22,top,2.85},{cx+(j<0 and .04 or .40),38.5,2.85},4,1)
 end
 diamond(cx,39.1,3.05,.95,1.05,7)
 box(cx-w/2-.45,37.3,.55,w+.9,.4,2.8,3)
 box(cx-w/2-.65,38+h,.55,w+1.3,.5,2.8,3)
 -- Small warm glass lanterns fit the existing blank strips beside the door.
 for _,x in ipairs({left-p-3.3,right+p+1.4})do
  box(x,23,1.5,1.9,7.5,.7,8)
  box(x+.3,24,2.3,1.3,5.5,.85,11)
  for _,xx in ipairs({x+.14,x+1.56})do box(xx,23.8,3.2,.2,5.9,.22,3)end
  box(x-.16,23.5,2.1,2.22,.4,1.6,3)
  box(x-.16,29.75,2.1,2.22,.4,1.6,4)
 end
 -- Threshold is recessed beyond the original visible carpet/warp marker.
 box(left,.02,-3.95,32,.12,1.9,3)
end
return M
