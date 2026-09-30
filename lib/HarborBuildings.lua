-- Additive Vermilion architecture, after Better Buildings' in-place repairs.
-- Only complete blank side/rear wall patches qualify; fronts/doors stay authored.
local M={}
local unpack=table.unpack or unpack
local function bounds(q)
 local lo,hi={1e9,1e9,1e9},{-1e9,-1e9,-1e9}
 for i=1,4 do for a=1,3 do lo[a]=math.min(lo[a],q[i][a]);hi[a]=math.max(hi[a],q[i][a])end end
 return lo,hi
end
-- Clip overlapping coplanar rectangles instead of relying on draw order.
local function separate(quads,first)
 local planes,out={},{}
 for i=#quads,first,-1 do
  local q=quads[i];local lo,hi=bounds(q);local axis
  for a=1,3 do if hi[a]-lo[a]<1e-7 then axis=a;break end end
  if axis then
   local a,b=axis==1 and 2 or 1,axis==3 and 2 or 3
   local key=axis..':'..string.format('%.6f',lo[axis])
   local occupied=planes[key] or {};planes[key]=occupied
   local pieces={{lo[a],lo[b],hi[a],hi[b]}}
   for _,cut in ipairs(occupied)do
    local nextPieces={}
    for _,r in ipairs(pieces)do
     local l,d,u,t=math.max(r[1],cut[1]),math.max(r[2],cut[2]),math.min(r[3],cut[3]),math.min(r[4],cut[4])
     if u-l>1e-7 and t-d>1e-7 then
      for _,v in ipairs({{r[1],r[2],l,r[4]},{u,r[2],r[3],r[4]},{l,r[2],u,d},{l,t,u,r[4]}})do
       if v[3]-v[1]>1e-7 and v[4]-v[2]>1e-7 then nextPieces[#nextPieces+1]=v end
      end
     else nextPieces[#nextPieces+1]=r end
    end
    pieces=nextPieces;if #pieces==0 then break end
   end
   for _,r in ipairs(pieces)do
    local n={shade=q.shade,harborMaterial=q.harborMaterial,own=q.own}
    for j=1,4 do
     n[j]={q[j][1],q[j][2],q[j][3]}
     n[j][a]=math.abs(q[j][a]-lo[a])<1e-7 and r[1] or r[3]
     n[j][b]=math.abs(q[j][b]-lo[b])<1e-7 and r[2] or r[4]
    end
    out[#out+1]=n;occupied[#occupied+1]=r
   end
  else out[#out+1]=q end
 end
 for i=#quads,first,-1 do quads[i]=nil end
 for _,q in ipairs(out)do quads[#quads+1]=q end
end
function M.build(S,map,data)
 if map.id~='VERMILION_CITY' then return end
 local firstDetail=#S.objectQuads+1
 local replacements={}
 M.roofReplacements={}
 local w=map.tileset.imageWidth or 128;local h=map.tileset.imageHeight or 48
 for _,building in ipairs(S.harborBuildings or {})do
  local groups={};local centerX,centerZ=0,0;local count=0
  for i=building.first,building.last do local q=S.objectQuads[i]
   for j=1,4 do centerX=centerX+q[j][1];centerZ=centerZ+q[j][3];count=count+1 end
  end
  centerX,centerZ=centerX/math.max(count,1),centerZ/math.max(count,1)
  for i=building.first,building.last do
   local q=S.objectQuads[i];local lo,hi=bounds(q)
   local axis=hi[1]-lo[1]<.001 and 1 or hi[3]-lo[3]<.001 and 3
   -- South/front elevations retain their doors, signs and glazing.
   if axis and hi[2]>lo[2] and (axis==1 or lo[3]<centerZ) and q.uv then
    local u0,v0,u1,v1=1e9,1e9,-1e9,-1e9
    for j=1,4 do u0=math.min(u0,q.uv[j][1]);u1=math.max(u1,q.uv[j][1]);v0=math.min(v0,q.uv[j][2]);v1=math.max(v1,q.uv[j][2])end
    if ((u1-u0)*w<=1.01 and (v1-v0)*h<=1.01) or (building.authoredSides and hi[2]<=(building.wallHeight or 0)+.01) then
     local a=axis==1 and 3 or 1;local k=axis..':'..lo[axis]
     local g=groups[k] or {axis=axis,plane=lo[axis],lo=1e9,hi=-1e9,top=0,bottom=1e9,rects={}}
     g.lo=math.min(g.lo,lo[a]);g.hi=math.max(g.hi,hi[a]);g.top=math.max(g.top,hi[2]);g.bottom=math.min(g.bottom,lo[2])
     g.rects[#g.rects+1]={lo[a],lo[2],hi[a],hi[2],i};groups[k]=g
    end
   end
  end
  local keys={};for k in pairs(groups)do keys[#keys+1]=k end;table.sort(keys)
  local emitted=0
  for _,key in ipairs(keys)do local g=groups[key]
   local hidden=false
   for _,other in pairs(groups)do
    if other~=g and other.axis==g.axis and other.lo<=g.lo+.5 and other.hi>=g.hi-.5 then
     local center=g.axis==1 and centerX or centerZ
     if (g.plane<center and other.plane<g.plane and other.plane>=g.plane-2)
       or (g.plane>=center and other.plane>g.plane and other.plane<=g.plane+2) then hidden=true end
    end
   end
   local sign=g.plane<(g.axis==1 and centerX or centerZ) and -1 or 1
   local function covered(a,b,c,d)
    for y=b+.1,d,.8 do for u=a+.1,c,.8 do
     local found=false
     for _,r in ipairs(g.rects)do if u>=r[1] and u<=r[3] and y>=r[2] and y<=r[4] then found=true;break end end
     if not found then return false end
    end end
    return true
   end
   local function point(u,y,n)
    n=.35+n*1.5 -- separate trim from the original wall depth
    return g.axis==1 and {g.plane+sign*n,y,u} or {u,y,g.plane+sign*n}
   end
   local function face(p,mat,t)
    if emitted>=6000 then return end
    local q={point(unpack(p[1])),point(unpack(p[2])),point(unpack(p[3])),point(unpack(p[4]))}
    -- Matching handedness of the local u/y/out coordinate basis.
    if (g.axis==1 and sign==1) or (g.axis==3 and sign==-1) then q={q[4],q[3],q[2],q[1]}end
    q.shade=t or 1;q.harborMaterial=mat;q.own=true
    S.objectQuads[#S.objectQuads+1]=q;emitted=emitted+1
   end
   local function box(a,b,c,d,n0,n1,mat,t)
    face({{a,b,n1},{c,b,n1},{c,d,n1},{a,d,n1}},mat,t)
    -- Wall-mounted details have no visible back face; omit internal overlap.
    face({{a,d,n1},{c,d,n1},{c,d,n0},{a,d,n0}},mat,(t or 1)*1.06)
    face({{a,b,n0},{c,b,n0},{c,b,n1},{a,b,n1}},mat,(t or 1)*.72)
    face({{a,b,n0},{a,b,n1},{a,d,n1},{a,d,n0}},mat,(t or 1)*.83)
    face({{c,b,n1},{c,b,n0},{c,d,n0},{c,d,n1}},mat,(t or 1)*.90)
   end
   local bottom=math.max(.3,g.bottom)
   local top=math.min(building.wallHeight or 64,math.floor(g.top-2))
   while top>=16 and not covered(g.lo+.5,math.max(3,bottom+.1),g.hi-.5,top) do top=top-1 end
   if not hidden and g.hi-g.lo>=20 and top>=16 and emitted<4800 then
    -- Remove only the covered rectangle of the original blank wall.
    for _,r in ipairs(g.rects)do
     local q=S.objectQuads[r[5]];local a=g.axis==1 and 3 or 1
     local l,b,u,t=math.max(r[1],g.lo+.1),math.max(r[2],bottom),math.min(r[3],g.hi-.1),math.min(r[4],top)
     if u>l and t>b then
      local pieces={}
      for _,v in ipairs({{r[1],r[2],l,r[4]},{u,r[2],r[3],r[4]},{l,r[2],u,b},{l,t,u,r[4]}})do
       if v[3]>v[1]+1e-7 and v[4]>v[2]+1e-7 then
        local n={};for key,value in pairs(q)do if type(key)~='number' then n[key]=value end end
        n.uv={};if type(q.shade)=='table' then n.shade={} end
        for j=1,4 do
         n[j]={q[j][1],q[j][2],q[j][3]}
         n[j][a]=math.abs(q[j][a]-r[1])<1e-7 and v[1] or v[3]
         n[j][2]=math.abs(q[j][2]-r[2])<1e-7 and v[2] or v[4]
         local fx,fy=(n[j][a]-r[1])/(r[3]-r[1]),(n[j][2]-r[2])/(r[4]-r[2])
         local uu,vv,shade=0,0,0
         for k=1,4 do
          local wt=(math.abs(q[k][a]-r[1])<1e-7 and 1-fx or fx)*(math.abs(q[k][2]-r[2])<1e-7 and 1-fy or fy)
          uu=uu+q.uv[k][1]*wt;vv=vv+q.uv[k][2]*wt
          if type(q.shade)=='table' then shade=shade+q.shade[k]*wt end
         end
         n.uv[j]={uu,vv};if type(q.shade)=='table' then n.shade[j]=shade end
        end
        pieces[#pieces+1]=n
       end
      end
      replacements[r[5]]=pieces
     end
    end
    -- Continuous backing closes clapboard gaps after removing the old patch.
    face({{g.lo+.1,bottom,.005},{g.hi-.1,bottom,.005},{g.hi-.1,top,.005},{g.lo+.1,top,.005}},'cream',.70)
    -- Broad clapboard courses, with actual overlapping lower lips.
    for y=math.max(3,bottom),top-1,3.5 do
     local hi=math.min(top,y+3.38)
     box(g.lo+.15,y,g.hi-.15,hi,.025,.16,'cream',.77+(math.floor(y/2.5)%3)*.025)
    end
    if bottom<2.85 then box(g.lo+.1,bottom,g.hi-.1,2.85,.02,.35,'stone',.61) end
    box(g.lo+.1,top-.4,g.hi-.1,top+.5,.03,.65,'wood',.80)
    for _,u in ipairs({g.lo+.4,g.hi-.4})do box(u-.35,2.8,u+.35,top,.12,.40,'cream',.95)end
    -- Two or three framed bays rather than filling the whole elevation.
    local bays=math.min(3,math.floor((g.hi-g.lo)/20))
    local floors=top>=40 and 2 or 1
    for floor=1,floors do
    for i=1,bays do
     local u=g.lo+(g.hi-g.lo)*i/(bays+1);local b=math.max(bottom+3, floors==2 and (floor==1 and 7 or top-17) or top*.36);local d=math.min(top-3,b+10)
     if d-b>=6 and covered(u-5,b-1,u+5,d+1) then
      box(u-4.7,b-.5,u+4.7,d+.5,.18,.43,'wood',.65)
      -- Dark reveal, inset glowing panes, cream frame, projecting sill.
      box(u-4.2,b,u+4.2,d,.43,.46,'metal',.92)
      local lit=(i+math.floor(g.plane))%3~=0
      face({{u-3.55,b+.6,.48},{u+3.55,b+.6,.48},{u+3.55,d-.6,.48},{u-3.55,d-.6,.48}},lit and 'glass' or 'metal',lit and 65 or 1.35)
      box(u-4.2,b,u-3.65,d,.45,.70,'cream',.95);box(u+3.65,b,u+4.2,d,.45,.70,'cream',.95)
      box(u-3.65,d-.55,u+3.65,d,.45,.76,'cream',.95)
      box(u-.18,b+.3,u+.18,d-.3,.5,.65,'cream',.90)
      box(u-3.65,(b+d)/2-.17,u+3.65,(b+d)/2+.17,.5,.72,'cream',.90)
      box(u-4.8,b-.4,u+4.8,b+.25,.25,1,'stone',.83)
      -- Timber shutters with spaced slats, attached to the wall.
      for _,side in ipairs({-1,1})do
       local a=side<0 and u-6.5 or u+4.55
       if a>g.lo+.8 and a+1.95<g.hi-.8 then
        box(a,b,a+1.95,d,.20,.40,'wood',.73)
        for y=b+.5,d-.3,1.25 do box(a+.15,y,a+1.8,y+.25,.43,.56,'wood',.95)end
       end
      end
     end
    end
    end -- floor
   end
  end
  if data then M.roof(S,building,data,w,h) end
 end
 separate(S.objectQuads,firstDetail)
 local result={}
 for i,q in ipairs(S.objectQuads)do
  local pieces=M.roofReplacements[i] or replacements[i]
  if pieces then for _,p in ipairs(pieces)do result[#result+1]=p end
  else result[#result+1]=q end
 end
 S.objectQuads=result
 M.roofReplacements=nil
end
-- Use the source atlas to identify the yellow harbor roof only. Landmark
-- red/blue roofs and all facade art keep their authored materials.
function M.roof(S,building,data,w,h)
 local candidates={};local lo={1e9,1e9,1e9};local hi={-1e9,-1e9,-1e9}
 local wall=building.wallHeight
 if not wall or not data.getPixel then return end
 for index=building.first,building.last do
  local q=S.objectQuads[index];local a,b=bounds(q)
  if q.uv and a[2]>=wall-.01 and b[1]-a[1]>.01 and b[3]-a[3]>.01 then
   local u,v=0,0
   for j=1,4 do u=u+q.uv[j][1]/4;v=v+q.uv[j][2]/4 end
   local r,g,blue=data:getPixel(math.max(0,math.min(w-1,math.floor(u*w))),math.max(0,math.min(h-1,math.floor(v*h))))
   -- Better Buildings 1.19's Vermilion civic roof band. Fail closed for
   -- another atlas layout; yellow gym equipment must never become clay.
   local sourceY=math.floor(v*h)
   if w==128 and h==1992 and sourceY>=1696 and sourceY<1728
      and r>.28 and g>.22 and blue<g*.72 and r>g*.85 then
    candidates[#candidates+1]=index
    for axis=1,3 do lo[axis]=math.min(lo[axis],a[axis]);hi[axis]=math.max(hi[axis],b[axis]) end
   end
  end
 end
 if #candidates==0 then return end
 local added=0
 for _,index in ipairs(candidates) do
  local q=S.objectQuads[index]
  local function length(a,b)
   local n=0;for k=1,3 do n=n+(a[k]-b[k])^2 end;return math.sqrt(n)
  end
  local nx=math.max(1,math.ceil(length(q[1],q[2])/5))
  local ny=math.max(1,math.ceil(length(q[1],q[4])/4))
  -- Bound the total detail independently of unusually large custom maps.
  if added+nx*ny*2>2400 then nx,ny=1,1 end
  local function vertex(u,v)
   local p={};for a=1,3 do p[a]=q[1][a]*(1-u)*(1-v)+q[2][a]*u*(1-v)+q[3][a]*u*v+q[4][a]*(1-u)*v end;return p
  end
  local pieces={}
  local function tile(u0,v0,u1,v1,tone)
   local p={vertex(u0,v0),vertex(u1,v0),vertex(u1,v1),vertex(u0,v1),own=true,harborMaterial='roof'}
   local base=type(q.shade)=='table' and math.abs(q.shade[1]) or math.abs(q.shade or 1)
   p.shade=base*tone;pieces[#pieces+1]=p;added=added+1
  end
  for y=0,ny-1 do for x=0,nx-1 do
   local u0,u1=x/nx,(x+1)/nx;local v0,v1=y/ny,(y+1)/ny
   local p=vertex((u0+u1)/2,(v0+v1)/2)
   local tone=.88+((math.floor(p[1]/5)+math.floor(p[3]/4)*3)%5)*.035
   local seam=v1-(v1-v0)*.075
   tile(u0,v0,u1,seam,tone);tile(u0,seam,u1,v1,.58)
  end end
  M.roofReplacements[index]=pieces
 end
 local function face(a,b,c,d,mat,tone)
  S.objectQuads[#S.objectQuads+1]={a,b,c,d,own=true,harborMaterial=mat,shade=tone}
 end
 local function box(x0,y0,z0,x1,y1,z1,mat,tone)
  face({x0,y1,z0},{x0,y1,z1},{x1,y1,z1},{x1,y1,z0},mat,tone)
  face({x0,y0,z1},{x1,y0,z1},{x1,y1,z1},{x0,y1,z1},mat,tone*.85)
  face({x1,y0,z0},{x0,y0,z0},{x0,y1,z0},{x1,y1,z0},mat,tone*.70)
  face({x0,y0,z0},{x0,y0,z1},{x0,y1,z1},{x0,y1,z0},mat,tone*.78)
  face({x1,y0,z1},{x1,y0,z0},{x1,y1,z0},{x1,y1,z1},mat,tone*.9)
 end
 local ridge=(lo[3]+hi[3])/2
 -- Low caps and one chimney alter the skyline without moving the roof,
 -- building footprint, door or any collision cell.
 if hi[1]-lo[1]>=24 and hi[3]-lo[3]>=16 then
  for x=lo[1]+1,hi[1]-3,6 do
   box(x,hi[2]-.5,ridge-1,math.min(x+5.8,hi[1]-1),hi[2]+.7,ridge+1,'roof',1.10)
  end
  local cx=lo[1]+(hi[1]-lo[1])*.24
  box(cx-2.8,hi[2]-4,ridge-2.8,cx+2.8,hi[2]+9,ridge+2.8,'stone',.78)
  for y=hi[2]-2,hi[2]+7,3 do
   box(cx-2.95,y,ridge-2.95,cx+2.95,y+.3,ridge+2.95,'cream',.68)
  end
  box(cx-3.6,hi[2]+8.5,ridge-3.6,cx+3.6,hi[2]+10,ridge+3.6,'stone',.96)
  box(cx-2.3,hi[2]+10.05,ridge-2.3,cx+2.3,hi[2]+10.12,ridge+2.3,'metal',.62)
 end
end

return M
