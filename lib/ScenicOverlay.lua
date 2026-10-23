-- Binocular optics and HUD, drawn at a 640x360 logical resolution.
-- One cached mask mesh; no extra render target, stencil buffer or shader.
local M={}
local mask,outline,small,title
local ink={.025,.032,.04,1};local gold={.87,.69,.39,1};local white={.86,.93,.9,1}
function M.release()
 for _,v in ipairs({mask,small,title})do if v and v.release then v:release()end end
 mask,outline,small,title=nil,nil,nil,nil
end
local function optics()
 if mask then return end
 local vs={};local rx,ry,cy=192,130,177
 local left,right=232,408
 local function add(x0,y0,x1,y1,x2,y2)
  for _,p in ipairs({{x0,y0},{x1,y1},{x2,y2}})do vs[#vs+1]={p[1],p[2],0,0,ink[1],ink[2],ink[3],1}end
 end
 local function top(x)
  local q=math.min(math.abs(x-left),math.abs(x-right))/rx
  return q>=1 and cy or cy-ry*math.sqrt(1-q*q)
 end
 local upper,lower={},{}
 for x=left-rx,right+rx,4 do
  local y=top(x);upper[#upper+1]=x;upper[#upper+1]=y
  table.insert(lower,1,cy*2-y);table.insert(lower,1,x)
  if x<right+rx then
   local nx=math.min(right+rx,x+4);local ny=top(nx)
   add(x,0,nx,0,nx,ny);add(x,0,nx,ny,x,y)
   add(x,cy*2-y,nx,cy*2-ny,nx,360);add(x,cy*2-y,nx,360,x,360)
  end
 end
 add(0,0,left-rx,0,left-rx,360);add(0,0,left-rx,360,0,360)
 add(right+rx,0,640,0,640,360);add(right+rx,0,640,360,right+rx,360)
 outline=upper;for _,v in ipairs(lower)do outline[#outline+1]=v end
 outline[#outline+1]=upper[1];outline[#outline+1]=upper[2]
 mask=love.graphics.newMesh(vs,'triangles','static')
end
local function color(c,a)love.graphics.setColor(c[1],c[2],c[3],a or c[4])end
local directions={'N','NE','E','SE','S','SW','W','NW'}
function M.draw(w,h,screen,ready,failed)
 local g=love.graphics;optics()
 if not small then small=g.newFont(11);title=g.newFont(15)end
 g.push('all');g.scale(w/640,h/360)
 -- Feather the inside of the lens rim, then cover everything outside it.
 for _,s in ipairs({{18,.09},{12,.15},{6,.26}})do
  g.setColor(0,0,0,s[2]);g.setLineWidth(s[1]);g.line(outline)
 end
 g.setColor(1,1,1,1);g.draw(mask)
 color(gold,.35);g.setLineWidth(1);g.line(outline)
 g.setFont(small);color(gold);g.print('K A N T O   /   O B S E R V A T O R Y',24,14)
 color(white,.75);g.printf(screen.label,340,14,276,'right')
 g.setColor(.25,.30,.32,1);g.rectangle('fill',24,33,592,1)
 if ready then
  -- Compass ticks travel under a fixed index; the source scene rotates with them.
  local heading=math.deg(screen.yaw)%360
  for n=-6,6 do
   local tick=math.floor(heading/15)*15+n*15
   local x=320+(tick-heading)*2.1
   if x>180 and x<460 then
    color(white,.5);g.setLineWidth(1);g.line(x,80,x,tick%45==0 and 87 or 84)
    if tick%45==0 then color(white,.8);g.printf(directions[(math.floor(tick/45)%8)+1],x-14,65,28,'center')end
   end
  end
  color(gold);g.polygon('fill',317,91,323,91,320,95)
  color(white,.48);g.setLineWidth(1)
  for _,p in ipairs({{299,177,311,177},{329,177,341,177},{320,163,320,169},{320,185,320,191}})do g.line(p)end
  g.circle('line',320,177,2,12)
  g.setColor(.018,.027,.031,.8);g.rectangle('fill',438,257,56,25,6,6)
  g.setFont(title);color(gold);g.printf(string.format('%dx',screen.zoom),438,260,56,'center')
  g.setFont(small);color(white,.8);g.print('MAP VIEW',149,266)
 else
  color(white);g.setFont(title)
  g.printf(failed and 'VIEW UNAVAILABLE' or 'FOCUSING ON THE LANDSCAPE',120,163,400,'center')
  g.setFont(small);color(gold)
  g.printf(failed and 'Press B to return and try again' or 'Preparing the surrounding map',120,189,400,'center')
 end
 -- Clear controller instructions stay outside the optical field.
 g.setFont(small);color(gold);g.print('D-PAD',76,330);color(white);g.print('LOOK',119,330)
 color(gold);g.print('A',280,330);color(white);g.print('ZOOM  2x / 4x / 6x',295,330)
 color(gold);g.print('B',510,330);color(white);g.print('BACK',525,330)
 g.pop()
end
return M
