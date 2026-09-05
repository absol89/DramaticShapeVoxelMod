-- Display bicycles reconstructed as open wheels and thin frame components.
-- Every material is a measured texel from the matching 24x16 source drawing.
local V = ...
local Budget = V.require('BuildBudget')
local Bike = {}
local pi,abs,sqrt=math.pi,math.abs,math.sqrt
local function sub(a,b)return{a[1]-b[1],a[2]-b[2],a[3]-b[3]}end
local function cross(a,b)return{a[2]*b[3]-a[3]*b[2],a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1]}end
local function dot(a,b)return a[1]*b[1]+a[2]*b[2]+a[3]*b[3]end
local function unit(a)local n=sqrt(dot(a,a));assert(n>1e-9);return{a[1]/n,a[2]/n,a[3]/n}end
local function mid(a,b)return{(a[1]+b[1])/2,(a[2]+b[2])/2,(a[3]+b[3])/2}end
local function normal(p)return unit(cross(sub(p[2],p[1]),sub(p[3],p[1])))end
-- Clip planar parts at the same 8px X/Z lattice used by the world curve.
local function clip(poly,axis,bound,positive)
  local out={};local a=poly[#poly]
  for _,b in ipairs(poly)do
    local da=(a[axis]-bound)*(positive and 1 or -1)
    local db=(b[axis]-bound)*(positive and 1 or -1)
    if (da>=-1e-8)~=(db>=-1e-8)then
      local f=(bound-a[axis])/(b[axis]-a[axis]);local p={}
      for k=1,3 do p[k]=a[k]+f*(b[k]-a[k])end;p[axis]=bound;out[#out+1]=p
    end
    if db>=-1e-8 then out[#out+1]=b end;a=b
  end
  local clean={}
  for _,p in ipairs(out)do
    local last=clean[#clean];if not last or dot(sub(p,last),sub(p,last))>1e-14 then clean[#clean+1]=p end
  end
  if #clean>1 and dot(sub(clean[1],clean[#clean]),sub(clean[1],clean[#clean]))<1e-14 then table.remove(clean)end
  return clean
end
function Bike.model(sp,pr,t)
  assert(sp.W==24 and sp.H==16,'complete 24x16 bicycle source required')
  local wall=t.bicycle=='wall';assert(wall or t.bicycle=='floor','bicycle variant')
  local W,faces,components=24,{},{}
  local donors=wall and{{3,8},{4,13},{4,5},{3,5}}or{{8,4},{3,8},{4,13},{12,4}}
  local materials={}
  for j,p in ipairs(donors)do
    local i=p[2]*W+p[1];local want=4-j
    assert(sp.col[i]==want,'measured bicycle material changed: '..j)
    materials[j]=i
  end
  local black,dark,grey,white=unpack(materials)
  local centerZ=wall and 20 or 12
  local current
  local function group(name,fn)
    current={name=name,first=#faces+1};components[#components+1]=current;fn();current.last=#faces
  end
  local function store(poly,source,shade)
    if #poly<3 then return end
    if #poly==4 then
      local a=cross(sub(poly[2],poly[1]),sub(poly[3],poly[1]))
      local b=cross(sub(poly[3],poly[1]),sub(poly[4],poly[1]))
      if dot(a,a)>1e-14 and dot(b,b)>1e-14 and dot(a,b)>0 then
        faces[#faces+1]={poly[1],poly[2],poly[3],poly[4],source=source,shade=shade};return
      end
    end
    for j=2,#poly-1 do
      local a,b,c=poly[1],poly[j],poly[j+1];local n=cross(sub(b,a),sub(c,a))
      if dot(n,n)>1e-14 then faces[#faces+1]={a,b,mid(b,c),c,source=source,shade=shade}end
    end
  end
  local function face(p,source)
    Budget.tick();local n=normal(p)
    local shade=.68+.23*math.max(0,n[2])+.09*math.max(0,n[3])
    local polys={p}
    for _,axis in ipairs({1,3})do
      local lo,hi=math.huge,-math.huge;for _,v in ipairs(p)do lo=math.min(lo,v[axis]);hi=math.max(hi,v[axis])end
      for b=(math.floor(lo/8)+1)*8,hi-1e-8,8 do
        local nexts={}
        for _,poly in ipairs(polys)do
          local min,max=math.huge,-math.huge;for _,v in ipairs(poly)do min=math.min(min,v[axis]);max=math.max(max,v[axis])end
          if min<b-1e-8 and max>b+1e-8 then
            local a,c=clip(poly,axis,b,false),clip(poly,axis,b,true)
            if #a>=3 then nexts[#nexts+1]=a end;if #c>=3 then nexts[#nexts+1]=c end
          else nexts[#nexts+1]=poly end
        end;polys=nexts
      end
    end
    for _,poly in ipairs(polys)do store(poly,source,shade)end
  end
  local function box(x0,y0,z0,x1,y1,z1,source,top)
    face({{x0,y0,z0},{x0,y0,z1},{x0,y1,z1},{x0,y1,z0}},source)
    face({{x1,y0,z1},{x1,y0,z0},{x1,y1,z0},{x1,y1,z1}},source)
    face({{x1,y0,z0},{x0,y0,z0},{x0,y1,z0},{x1,y1,z0}},source)
    face({{x0,y0,z1},{x1,y0,z1},{x1,y1,z1},{x0,y1,z1}},source)
    face({{x0,y0,z0},{x1,y0,z0},{x1,y0,z1},{x0,y0,z1}},source)
    face({{x0,y1,z1},{x1,y1,z1},{x1,y1,z0},{x0,y1,z0}},top or source)
  end
  local function rod(a,b,r,source,sides)
    sides=sides or 6;local axis=unit(sub(b,a));local u=unit(cross(axis,abs(axis[2])>.9 and{1,0,0}or{0,1,0}));local v=cross(axis,u)
    local function p(c,j)
      local q={};local angle=j*2*pi/sides
      for k=1,3 do q[k]=c[k]+r*(u[k]*math.cos(angle)+v[k]*math.sin(angle))end;return q
    end
    for j=0,sides-1 do face({p(a,j),p(a,j+1),p(b,j+1),p(b,j)},source)end
    for j=0,sides-1,2 do
      face({a,p(a,j+2),p(a,j+1),p(a,j)},source)
      face({b,p(b,j),p(b,j+1),p(b,j+2)},source)
    end
  end
  local function wheel(cx)
    local cy,z0,z1=4.5,centerZ-.7,centerZ+.7
    local function p(r,j,z)local a=j*2*pi/12;return{cx+r*math.cos(a),cy+r*math.sin(a),z}end
    group('tire_'..cx,function()
      for j=0,11 do
        face({p(4.5,j,z0),p(4.5,j+1,z0),p(4.5,j+1,z1),p(4.5,j,z1)},black)
        face({p(3.5,j,z1),p(3.5,j+1,z1),p(3.5,j+1,z0),p(3.5,j,z0)},grey)
        face({p(4.5,j,z1),p(4.5,j+1,z1),p(3.5,j+1,z1),p(3.5,j,z1)},black)
        face({p(4.5,j+1,z0),p(4.5,j,z0),p(3.5,j,z0),p(3.5,j+1,z0)},black)
      end
    end)
    group('spokes_'..cx,function()
      for j=0,2 do local a=j*pi/3
        rod({cx-3.5*math.cos(a),cy-3.5*math.sin(a),centerZ},{cx+3.5*math.cos(a),cy+3.5*math.sin(a),centerZ},.10,white,4)
      end
      rod({cx,cy,z0-.15},{cx,cy,z1+.15},.42,grey,6)
    end)
  end
  wheel(4.5);wheel(19.5)
  -- Original front-wheel, crank, steering head and saddle positions determine
  -- the two open frame triangles; only the unseen depth is interpreted.
  local front={4.5,4.5,centerZ};local rear={19.5,4.5,centerZ}
  local crank={12.5,4,centerZ};local head={8.5,11,centerZ};local seat={14,10.5,centerZ}
  group('frame',function()
    for _,ab in ipairs({{head,seat},{head,crank},{seat,crank},{seat,rear},{rear,crank}})do rod(ab[1],ab[2],.36,grey)end
    for _,dz in ipairs({-1,1})do
      rod({head[1],head[2],centerZ+dz*.45},{front[1],front[2],centerZ+dz*.85},.22,dark)
      rod({seat[1],seat[2],centerZ+dz*.35},{rear[1],rear[2],centerZ+dz*.85},.20,dark)
    end
  end)
  group('saddle',function()
    rod(crank,{14,12,centerZ},.25,dark)
    box(12,11.7,centerZ-1.6,16,12.25,centerZ+1.6,black,grey)
    box(12.4,12.25,centerZ-1.25,15.6,12.5,centerZ+1.25,grey,grey)
  end)
  group('handlebars',function()
    rod(head,{8.5,15,centerZ},.28,dark)
    rod({8.5,15,centerZ-2.7},{8.5,15,centerZ+2.7},.22,white)
    for _,dz in ipairs({-1,1})do
      rod({8.5,15,centerZ+dz*2.1},{9.5,15,centerZ+dz*3.0},.27,black)
    end
  end)
  group('crank_pedals',function()
    rod({12.5,4,centerZ-1.35},{12.5,4,centerZ+1.35},.38,dark)
    rod({12.5,4,centerZ+1.35},{11.6,3.2,centerZ+1.35},.16,white,4)
    rod({12.5,4,centerZ-1.35},{13.4,4.8,centerZ-1.35},.16,white,4)
    box(11.1,3,centerZ+1.1,12.1,3.35,centerZ+2.0,black)
    box(12.9,4.65,centerZ-2,13.9,5,centerZ-1.1,black)
  end)
  group('stand',function()
    rod({12.5,4,centerZ+.5},{13.1,.18,centerZ+2.35},.17,dark,4)
  end)
  if wall then group('basket',function()
    -- Open basket, with a raised rim and sparse rails; no opaque card.
    local x0,x1,z0,z1=2,7.8,centerZ-2.4,centerZ+2.4
    box(x0,10.2,z0,x1,10.6,z1,grey,grey)
    for _,y in ipairs({11.8,14.8})do
      box(x0,y,z0,x1,y+.25,z0+.25,white)
      box(x0,y,z1-.25,x1,y+.25,z1,white)
      box(x0,y,z0,x0+.25,y+.25,z1,white)
      box(x1-.25,y,z0,x1,y+.25,z1,white)
    end
    for _,x in ipairs({x0,4,6,x1-.25})do
      box(x,10.6,z0,x+.25,14.8,z0+.25,grey)
      box(x,10.6,z1-.25,x+.25,14.8,z1,grey)
    end
    for _,z in ipairs({centerZ-1.2,centerZ+1.2})do box(x0,10.6,z,x0+.25,14.8,z+.25,grey)end
    rod({7.8,11,centerZ},{8.5,12,centerZ},.23,dark,4)
  end)end
  return{W=24,ytop=15,zmin=wall and 16 or 8,zmax=wall and 23 or 15,at=function()return nil end,
    surfaces=faces,components=components,materials=materials,wheelCenters={{4.5,4.5,centerZ},{19.5,4.5,centerZ}},variant=t.bicycle}
end
return Bike
