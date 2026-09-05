-- ROM-free contact-AO tests; run from the mod root with LuaJIT.
local checks = 0
local function ok(v, message)
  checks = checks + 1
  if not v then error('FAIL '..message, 0) end
end
local function near(a, b, message)
  ok(type(a)=='number' and math.abs(a-b)<1e-9,
     message..' (expected '..tostring(b)..', got '..tostring(a)..')')
end
local H=dofile('tests/astra_fixture.lua')
local root=os.getenv('ASTRA_CONTACT_ROOT') or '.'
local B=assert(loadfile(root..'/lib/Buildings.lua'))({
  require=function(n) assert(n=='BuildBudget'); return {tick=function() end} end,
  data=function() return {} end,
})
local emit=H.upvalue(B.build,'emit')
local function key(x,y,z) return x..','..y..','..z end
local axes={{2,3},{1,3},{1,2}}
local bases={{0.78,0.78},{0.5,0.95},{0.68,1}}
local function shade(q,i) return type(q.shade)=='table' and q.shade[i] or q.shade end
local function face(q)
  for a=1,3 do if q[1][a]==q[2][a] and q[1][a]==q[3][a] and q[1][a]==q[4][a] then
    local b,c=axes[a][1],axes[a][2]
    local b0,b1,c0,c1=q[1][b],q[1][b],q[1][c],q[1][c]
    for i=2,4 do
      b0,b1=math.min(b0,q[i][b]),math.max(b1,q[i][b])
      c0,c1=math.min(c0,q[i][c]),math.max(c1,q[i][c])
    end
    return a,q[1][a],b0,b1,c0,c1
  end end
  error('non-axis-aligned quad')
end
-- Evaluate the actual 1/2/3 and 1/3/4 submitted triangles, not bilinear shade.
local function sample(q,a,b,c,field)
  local ab,ac=axes[a][1],axes[a][2]
  for _,ids in ipairs({{1,2,3},{1,3,4}}) do
    local p,r,s=q[ids[1]],q[ids[2]],q[ids[3]]
    local den=(r[ac]-s[ac])*(p[ab]-s[ab])+(s[ab]-r[ab])*(p[ac]-s[ac])
    local u=((r[ac]-s[ac])*(b-s[ab])+(s[ab]-r[ab])*(c-s[ac]))/den
    local v=((s[ac]-p[ac])*(b-s[ab])+(p[ab]-s[ab])*(c-s[ac]))/den
    local w=1-u-v
    if u>=-1e-9 and v>=-1e-9 and w>=-1e-9 then
      local function val(i) return field and q.uv[i][field] or shade(q,i) end
      return u*val(ids[1])+v*val(ids[2])+w*val(ids[3])
    end
  end
  error('sample outside quad')
end
local function fk(a,p,b,c) return a..':'..p..':'..b..':'..c end
local function fixture(W,top,D,predicate,label,strip)
  local cells,expected={},{}
  local sp={ax={},ay={}}
  for x=0,W-1 do sp.ax[x],sp.ay[x]=x,0 end
  local count,shell=0,0
  for y=0,top do for z=0,D-1 do for x=0,W-1 do
    if predicate(x,y,z) then cells[key(x,y,z)]=strip and x or 0;count=count+1 end
  end end end
  local function at(x,y,z) return cells[key(x,y,z)] end
  for y=0,top do for z=0,D-1 do for x=0,W-1 do if at(x,y,z)~=nil then
    local exposed=false
    for a=1,3 do for _,d in ipairs({-1,1}) do
      local p={x,y,z};p[a]=p[a]+d
      if at(p[1],p[2],p[3])==nil then
        exposed=true
        if not(a==2 and d==-1 and y==0) then
          local o={x,y,z}
          expected[fk(a,o[a]+(d==1 and 1 or 0),o[axes[a][1]],o[axes[a][2]])]={
            texel=at(x,y,z),base=bases[a][d==1 and 2 or 1]}
        end
      end
    end end
    if exposed then shell=shell+1 end
  end end end end
  local q=emit({W=W,ytop=top,zmin=0,zmax=D-1,at=at},sp,32,8)
  near(q.voxels,count,label..' volume');near(q.shell,shell,label..' shell')
  local seen,samples={},{}
  for _,v in ipairs(q) do
    local a,p,b0,b1,c0,c1=face(v)
    ok(b1>b0 and c1>c0,label..' positive face area')
    for b=b0,b1-1 do for c=c0,c1-1 do
      local k=fk(a,p,b,c);local want=expected[k]
      ok(want~=nil and not seen[k],label..' exact exposed face coverage')
      seen[k],samples[k]=true,{q=v,axis=a}
      near(math.floor(sample(v,a,b+0.5,c+0.5,1)*32),want.texel,label..' source texel')
      near(math.floor(sample(v,a,b+0.5,c+0.5,2)*8),0,label..' source row')
      for _,db in ipairs({0,1}) do for _,dc in ipairs({0,1}) do
        local s=sample(v,a,b+db,c+dc)
        ok(s>=want.base*.76-1e-9 and s<=want.base+1e-9,label..' bounded shade')
      end end
    end end
  end
  for k in pairs(expected) do ok(seen[k],label..' no missing face') end
  return q,samples
end
local function corner(samples,a,p,b,c,db,dc)
  local s=assert(samples[fk(a,p,b,c)],'missing face')
  return sample(s.q,a,b+db,c+dc)
end
if ... == 'helpers' then return {face=face,sample=sample} end
local isolated=fixture(1,0,1,function() return true end,'isolated')
for _,q in ipairs(isolated) do ok(type(q.shade)=='number','isolated cube scalar shade') end
local slab=fixture(8,0,4,function() return true end,'slab',true)
for _,q in ipairs(slab) do ok(type(q.shade)=='number','coplanar slab does not self-shadow') end
local _,pane=fixture(5,5,2,function(x,y,z)
  return y>=1 and (z==0 or x==0 or x==4 or y==1 or y==5)
end,'recess')
near(corner(pane,3,1,1,2,0,0),.76,'pane concavity shaded')
near(corner(pane,3,1,2,3,1,1),1,'pane open center bright')
near(corner(pane,3,2,0,3,0,0),1,'frame outer face bright')
local _,eave=fixture(6,4,2,function(_,y,z) return z==0 or y==4 end,'eave')
near(corner(eave,3,1,2,3,0,1),.84,'wall below projecting roof shaded')
near(corner(eave,3,1,2,3,0,0),1,'wall below contact band bright')
-- Old 8px run endpoints cannot see the obstruction in their interior.
local _,blocked=fixture(8,3,2,function(x,y,z) return z==0 or (x==3 and y==2) end,'merge obstruction',true)
near(corner(blocked,3,1,2,1,1,1),.92,'interior obstruction survives face merging')
near(corner(blocked,3,1,0,1,1,1),1,'distant wall stays bright')
-- Differing edge slopes are bilinear, but one submitted pair of triangles
-- cannot reproduce the original unit-face interpolation inside a merged run.
local _,saddle=fixture(8,4,2,function(x,y,z)
  return z==0 or (z==1 and ((y==0 and (x==0 or x==1)) or (y==2 and (x==1 or x==3))))
end,'non-affine merge')
near(corner(saddle,3,1,1,1,1,.5),.92,'merged triangulation preserves internal edge shade')
local function shape(x,y,z)
  return z==0 or (x==2 and y>=1 and y<=3) or (y==4 and x>=2 and x<=5)
end
local _,left=fixture(8,4,2,shape,'left concavity')
local _,right=fixture(8,4,2,function(x,y,z) return shape(7-x,y,z) end,'right concavity')
for k,s in pairs(left) do
  local a,p,b,c=k:match('^(%d+):(%d+):(%d+):(%d+)$')
  a,p,b,c=tonumber(a),tonumber(p),tonumber(b),tonumber(c)
  local rp,rb=p,b
  if a==1 then rp=8-p else rb=7-b end
  local r=assert(right[fk(a,rp,rb,c)],'missing mirrored face')
  for _,db in ipairs({0,1}) do for _,dc in ipairs({0,1}) do
    near(sample(s.q,a,b+db,c+dc),sample(r.q,a,a==1 and rb+db or 8-(b+db),c+dc),
      'mirrored concavity corner shade')
  end end
end
local function scene(outdoor)
  return {outdoor=outdoor,shapeAt={},skip={},ground={},objectQuads={},
    tileAt=setmetatable({},{__index=function() return 1 end})}
end
local function map(door) return {isDoorTileCell=function(_,x,y) return door and x==0 and y==0 end} end
local template={
  {{0,0,8},{8,0,8},{8,8,8},{0,8,8},uv={},shade={.76,.84,.92,1},facade=true},
  {{8,0,8},{8,0,0},{8,8,0},{8,8,8},uv={},shade={.5928,.6552,.7176,.78}},
}
local entered,scenery,interior=scene(true),scene(true),scene(false)
B.stamp(entered,map(true),template,0,0,2,2,{})
B.stamp(scenery,map(false),template,0,0,2,2,{})
B.stamp(interior,map(true),template,0,0,2,2,{})
for i,want in ipairs({.76,.84,.92,1}) do
  near(template[1].shade[i],want,'template immutable after stamp')
  near(entered.objectQuads[1].shade[i],-want,'facade per-corner negative marker')
  near(scenery.objectQuads[1].shade[i],want,'scenery positive shade')
  near(interior.objectQuads[1].shade[i],want,'interior positive shade')
  near(entered.objectQuads[2].shade[i],template[2].shade[i],'side shade not marked')
end
print(('%d checks passed (Astra building contact shading)'):format(checks))
