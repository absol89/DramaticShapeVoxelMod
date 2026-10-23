-- TEST235 ENDING: JIGGLYPUFF'S MARKER DOODLES (original line art).
--
-- Silly, friendly marker drawings for sleeping faces: a curly mustache,
-- swirly cheeks, round glasses, a unibrow, cat whiskers, a star, a heart, a
-- monocle. Each design is a list of strokes (polylines) in FACE UNITS: the
-- origin is midway between the eyes, x to the face's own left as a viewer
-- sees it (+x of the model), y up, one unit = half the distance between the
-- eyes. The eyes sit at (-1,0) and (1,0), the nose tip near (0,-.95), the
-- mouth near (0,-1.65), the brows near y=.95, the cheeks near (+-1.5,-.9).
--
-- Pure data and pure functions (no LOVE): ParadeEnding builds ONE mesh from
-- all the designs (ribbons a little wrapped round the head), and draws each
-- design's run of it with a face's own matrix, a stroke at a time.
local D={REVISION='parade-doodles-235b'}
local sin,cos,pi,sqrt,max,min,abs=math.sin,math.cos,math.pi,math.sqrt,math.max,math.min,math.abs

D.WIDTH=.24        -- the marker's line, in face units (bold: read at dusk)
D.THIN=.15         -- a swirl's line: thinner, so its turns stay apart
D.WRAP=.17         -- how far the drawing bends back round the head (z=-WRAP*(x^2+.55y^2))
D.WRAP_MAX=1.25    -- (never further back than this)

local function arc(cx,cy,r,a0,a1,n,ry)
 local P={}
 for k=0,n do
  local a=a0+(a1-a0)*k/n
  P[#P+1]=cx+cos(a)*r;P[#P+1]=cy+sin(a)*(ry or r)
 end
 return P
end
local function spiral(cx,cy,r0,r1,turns,n,dir)
 local P={}
 for k=0,n do
  local u=k/n
  local a=(dir or 1)*u*turns*2*pi
  local r=r0+(r1-r0)*u
  P[#P+1]=cx+cos(a)*r;P[#P+1]=cy+sin(a)*r
 end
 return P
end
local function mirror(P)
 local Q={}
 for i=1,#P,2 do Q[i]=-P[i];Q[i+1]=P[i+1]end
 Q.w=P.w
 return Q
end
local function shift(P,dx,dy,s)
 local Q={}
 s=s or 1
 for i=1,#P,2 do Q[i]=P[i]*s+dx;Q[i+1]=P[i+1]*s+dy end
 return Q
end
-- a smooth curve through control points (Catmull-Rom), n points a span
local function curve(C,n)
 local P={}
 local m=#C/2
 local function pt(i)i=max(1,min(m,i));return C[2*i-1],C[2*i]end
 for i=1,m-1 do
  local x0,y0=pt(i-1);local x1,y1=pt(i);local x2,y2=pt(i+1);local x3,y3=pt(i+2)
  for k=(i==1 and 0 or 1),n do
   local t=k/n;local t2,t3=t*t,t*t*t
   P[#P+1]=.5*((2*x1)+(-x0+x2)*t+(2*x0-5*x1+4*x2-x3)*t2+(-x0+3*x1-3*x2+x3)*t3)
   P[#P+1]=.5*((2*y1)+(-y0+y2)*t+(2*y0-5*y1+4*y2-y3)*t2+(-y0+3*y1-3*y2+y3)*t3)
  end
 end
 return P
end
D._curve,D._arc,D._spiral=curve,arc,spiral

------------------------------------------------------------------ the designs
local designs={}
D.designs=designs
local order={}
D.order=order
local function design(name,strokes,info)
 local d={name=name,strokes=strokes}
 for k,v in pairs(info or{})do d[k]=v end
 designs[name]=d
 order[#order+1]=name
 return d
end

-- 1. THE CURLY MUSTACHE: a handlebar under the nose, its ends curled up
do
 -- (its curls wide enough that the line round them leaves a hole: a small
 -- curl closes up into a blob at a distance)
 local half=curve({0,-1.18, .36,-1.06, .80,-1.18, 1.18,-1.20, 1.52,-1.02, 1.52,-.66, 1.20,-.62, 1.16,-.90},5)
 local under=curve({0,-1.34, .42,-1.42, .86,-1.40, 1.22,-1.26},5)
 design('mustache',{mirror(half),half,mirror(under),under},{label='a curly mustache'})
end
-- 2. SWIRLY CHEEKS
do
 -- (a turn and a quarter, wide, in a thinner line: its turns stay apart --
 -- tighter, the line fills them in and it reads as a smudge)
 local s=spiral(1.12,-.82,.12,.64,1.3,40,1)
 s.w=D.THIN
 design('swirls',{mirror(s),s},{label='swirly cheeks'})
end
-- 3. ROUND GLASSES
do
 local L=arc(-1.02,.02,.66,0,2*pi,26)
 local R=arc(1.02,.02,.66,pi,3*pi,26)
 local bridge=curve({-.38,.10, 0,.26, .38,.10},5)
 local tl={-1.66,.12, -2.05,.26}
 local tr={1.66,.12, 2.05,.26}
 design('glasses',{L,bridge,R,tl,tr},{label='round glasses'})
end
-- 4. THE UNIBROW (bold: drawn twice, a hair apart)
do
 local a=curve({-1.85,.78, -1.2,1.06, -.55,1.00, 0,.88, .55,1.00, 1.2,1.06, 1.85,.78},4)
 local b=curve({-1.75,.90, -1.15,1.16, -.5,1.10, 0,.99, .5,1.10, 1.15,1.16, 1.75,.90},4)
 design('unibrow',{a,b},{label='a unibrow'})
end
-- 5. CAT WHISKERS and a little cat nose and mouth
do
 local nose={-.26,-.86, .26,-.86, 0,-1.10, -.26,-.86}
 local mouth=curve({-.55,-1.36, -.28,-1.52, 0,-1.32, .28,-1.52, .55,-1.36},4)
 local w={}
 for k,dy in ipairs({.32,0,-.32})do
  local y0=-1.05+dy*.35
  w[#w+1]={.85,y0, 2.35,y0+dy*1.1}
 end
 local S={nose,mouth}
 for _,p in ipairs(w)do S[#S+1]=mirror(p)end
 for _,p in ipairs(w)do S[#S+1]=p end
 design('whiskers',S,{label='cat whiskers'})
end
-- 6. A STAR on the cheek
do
 local P={}
 for k=0,5 do
  local a=pi/2+k*4*pi/5
  P[#P+1]=1.12+cos(a)*.62;P[#P+1]=-.88+sin(a)*.62
 end
 design('star',{P},{label='a star'})
end
-- 7. A HEART on the cheek
do
 -- (a quarter bigger than first drawn, about its middle: it reads)
 local raw={-1.12,-1.25, -1.55,-.88, -1.47,-.56, -1.25,-.52, -1.12,-.68, -.99,-.52, -.77,-.56, -.69,-.88, -1.12,-1.25}
 for k=1,#raw,2 do raw[k]=-1.12+(raw[k]+1.12)*1.25;raw[k+1]=-.88+(raw[k+1]+.88)*1.25 end
 local h=curve(raw,4)
 design('heart',{h},{label='a heart'})
end
-- 8. THE MONOCLE AND A CHAIN, with the curly mustache
do
 local m=arc(1.02,.02,.70,pi*.5,pi*2.5,26)
 local chain=curve({1.62,-.40, 1.86,-.86, 1.78,-1.40, 2.02,-1.90},5)
 local M=designs.mustache.strokes
 design('monocle',{m,chain,M[1],M[2]},{label='a monocle and a mustache'})
end
-- 9. GLASSES AND A MUSTACHE (the professor's)
do
 local G=designs.glasses.strokes
 local M=designs.mustache.strokes
 design('disguise',{G[1],G[2],G[3],G[4],G[5],M[1],M[2]},{label='glasses and a mustache'})
end
-- 10. A UNIBROW AND SWIRLS (the rival's)
do
 local U=designs.unibrow.strokes
 -- (the swirls on the cheeks, as 'swirls': over the eyes a thin line is
 -- lost in the eyes' own dark outlines)
 local s=spiral(1.08,-.96,.12,.58,1.3,40,1)
 s.w=D.THIN
 design('dizzy',{U[1],U[2],mirror(s),s},{label='a unibrow and swirly cheeks'})
end

-- who gets what (the parade's own people by sprite; the player; the
-- partner); anyone else takes the next of SPARE in turn
D.FOR={SPRITE_OAK='disguise',SPRITE_BLUE='dizzy',SPRITE_MOM='whiskers',PLAYER='monocle',PARTNER='swirls'}
D.SPARE={'star','heart','glasses','mustache','unibrow','whiskers'}

------------------------------------------------------------------ geometry
-- how far a design's strokes run (face units), each stroke's and in all
function D.lengths(d)
 local tot,each=0,{}
 for i,P in ipairs(d.strokes)do
  local L=0
  for k=1,#P-3,2 do L=L+sqrt((P[k+2]-P[k])^2+(P[k+3]-P[k+1])^2)end
  each[i]=L;tot=tot+L
 end
 return tot,each
end
-- the face surface a little bent back round the head
function D.wrapZ(x,y)
 return -min(D.WRAP_MAX,D.WRAP*(x*x+.55*y*y))
end
-- the ribbons of every design as one vertex list in Voxel3D's format
-- ({x,y,z,u,v,shade}) and its index map; per design the run of indices and,
-- per stroke, how many indices it ends at (so a stroke at a time can be
-- drawn, and the pen point of a partly drawn one found)
function D.build()
 local verts,map={},{}
 local runs={}
 for _,name in ipairs(order)do
  local d=designs[name]
  local first=#map+1
  local ends={}
  local segs={}
  for si,P in ipairs(d.strokes)do
   -- (a stroke may carry its own width: a swirl's is thinner)
   local W=(P.w or D.WIDTH)*.5
   for k=1,#P-3,2 do
    local ax,ay,bx,by=P[k],P[k+1],P[k+2],P[k+3]
    local dx,dy=bx-ax,by-ay
    local l=sqrt(dx*dx+dy*dy)
    if l>1e-6 then
     dx,dy=dx/l,dy/l
     -- (ends pushed out half a width: the joins have no gaps)
     local ex,ey=ax-dx*W,ay-dy*W
     local fx,fy=bx+dx*W,by+dy*W
     local nx,ny=-dy*W,dx*W
     local n=#verts
     local c={{ex+nx,ey+ny},{fx+nx,fy+ny},{fx-nx,fy-ny},{ex-nx,ey-ny}}
     for j=1,4 do
      local x,y=c[j][1],c[j][2]
      verts[n+j]={x,y,D.wrapZ(x,y),.5,.5,1}
     end
     map[#map+1]=n+1;map[#map+1]=n+2;map[#map+1]=n+3
     map[#map+1]=n+1;map[#map+1]=n+3;map[#map+1]=n+4
     segs[#segs+1]={ax,ay,bx,by,l,si}
    end
   end
   ends[si]=#map-first+1
  end
  local tot=0
  for _,s in ipairs(segs)do tot=tot+s[5]end
  runs[name]={first=first,count=#map-first+1,ends=ends,segs=segs,length=tot,strokes=#d.strokes}
 end
 return verts,map,runs
end
-- how much of a design is drawn at progress u (0..1, by length along the
-- pen's path, with a short lift between strokes): the index count to draw
-- (whole segments), the pen point (face units) and the stroke it is on
D.LIFT=.35         -- a pen lift between strokes, in face units of travel
function D.progress(run,u)
 -- (all of it at the end, whatever the sums' rounding)
 if u>=1 then
  local s=run.segs[#run.segs]
  if s then return #run.segs*6,s[3],s[4],s[6]end
 end
 local total=run.length+D.LIFT*max(0,run.strokes-1)
 local want=max(0,min(1,u))*total
 local acc,count=0,0
 local px,py,stroke=nil,nil,1
 local lastStroke=nil
 for i,s in ipairs(run.segs)do
  if lastStroke and s[6]~=lastStroke then acc=acc+D.LIFT end
  lastStroke=s[6]
  if acc+s[5]<=want+1e-9 then
   acc=acc+s[5];count=i*6;px,py,stroke=s[3],s[4],s[6]
  else
   local f=(want-acc)/s[5]
   if f>0 then px,py,stroke=s[1]+(s[3]-s[1])*f,s[2]+(s[4]-s[2])*f,s[6]end
   break
  end
 end
 if not px then local s=run.segs[1];if s then px,py=s[1],s[2]end end
 return count,px or 0,py or 0,stroke
end
-- the design for a sleeper (kind: a sprite, 'PLAYER' or 'PARTNER'); `used`
-- counts the spares given so far
function D.pick(kind,used)
 local d=D.FOR[kind]
 if d and designs[d]then return d end
 local k=((used or 0)%#D.SPARE)+1
 return D.SPARE[k]
end
return D
