-- Bill's source-aware mechanical chamber: geometry, source ownership and
-- emitted shell. Map/cutscene contracts are covered independently by the
-- placement regression. The generated game atlas remains a private input.
local root=os.getenv("ASTRA_CANDIDATE") or "."
local H=dofile(root.."/tests/astra_fixture.lua")
local inspect=assert(loadfile(root.."/tests/astra_building_contact_test.lua"))("helpers")
local data,w,h=H.atlas(assert(os.getenv("ASTRA_FURNITURE_ATLASES")).."/interior.rgba")
local spec=dofile(root.."/data/voxel_heights.lua")
local checks=0
local function ok(v,msg) checks=checks+1;if not v then error("FAIL "..msg,0)end end
local function eq(a,b,msg) ok(a==b,msg.." (expected "..tostring(b)..", got "..tostring(a)..")")end
local function key(x,y,z)return x..","..y..","..z end
local template
for _,t in ipairs(spec.buildings.INTERIOR)do if t.id=="bill_transporter" then
  ok(not template,"only one machine template");template=t
end end
ok(template and template.machine=="bill_transporter","machine opt-in is explicit")
local modules={BuildBudget={tick=function()end}}
local V={data=function()return spec end}
function V.require(name)
  if not modules[name] then
    ok(name=="BillMachine" or name=="ComputerCase","model only loads intended helpers")
    modules[name]=assert(loadfile(root.."/lib/"..name..".lua"))(V)
  end
  return modules[name]
end
local B=assert(loadfile(root.."/lib/Buildings.lua"))(V)
local sp=H.upvalue(B.build,"read")(template,data,w/8)
local pr=H.upvalue(B.build,"measure")(sp,template)
local model=H.upvalue(B.build,"model")(sp,pr,template)
local quads=H.upvalue(B.build,"emit")(model,sp,w,h)
eq(model.W,32,"original chamber width")
eq(model.ytop+1,32,"existing machine height")
eq(model.zmax,39,"original five-tile drawing footprint limit")
-- Last rows of the annotated top ellipse by source column. These mark a
-- semantic boundary: no vertical casing may carry top-hatch fragments.
local closing={12,14,15,16,16,17,17,18,18,19,19,19,
  20,20,20,20,20,20,20,20,19,19,19,18,18,17,17,16,16,15,14,12}
local occupied,count,topCount,bodyCount={},0,0,0
for y=0,31 do for z=0,39 do for x=0,31 do
  local i=model.at(x,y,z)
  if i then
    occupied[key(x,y,z)]={x,y,z};count=count+1
    ok(z>=8,"no geometry enters the vacated north source row")
    ok(sp.inside[i],"every donor belongs inside the source machine silhouette")
    ok(sp.ax[i]>=0 and sp.ax[i]<w and sp.ay[i]>=0 and sp.ay[i]<h,"atlas UV in range")
    ok(model.at(31-x,y,z)~=nil,"chamber silhouette is centered and mirrors across X")
    local sx,sy=i%32,math.floor(i/32)
    if y>=3 and y<=29 then
      ok(sy>closing[sx+1],"vertical casing source lies below the closing top arc")
    elseif y>=30 then
      ok(sy<=20,"top mechanism uses top-view source art")
    end
    if y==30 then
      topCount=topCount+1
      ok(model.at(x,30,47-z)~=nil,"main lid is round and centered in depth")
    elseif y==20 then bodyCount=bodyCount+1 end
  end
end end end
eq(topCount,812,"complete round lid area")
ok(bodyCount<topCount,"mounting rim overhangs the smaller casing")
ok(model.at(0,30,8)==nil and model.at(31,30,39)==nil,"lid corners do not become a square box")
eq(quads.voxels,count,"emitter sees exactly the modeled volume")
-- Full actor envelope, including the plinth. Bill begins at local(16,32)
-- and walks toward the front; no sprite vertex starts inside the shell.
for x=8,23 do for y=0,17 do
  local rear=model.at(x,y,30)
  ok(rear~=nil and sp.col[rear]==2,"entry recess has a dark rear wall")
  for z=31,39 do eq(model.at(x,y,z),nil,"entry remains open through the floor")end
end end
for center=32,48 do for x=8,23 do for y=0,17 do
  eq(model.at(x,y,center),nil,"original exit trajectory has full sprite clearance")
end end end
-- No disconnected control blocks, hatch covers or unsupported base pieces.
local _,seed=next(occupied);local queue={seed};occupied[key(unpack(seed))]=nil
local dirs={{1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1}}
local head=1
while head<=#queue do
 local p=queue[head];head=head+1
 for _,d in ipairs(dirs)do local k=key(p[1]+d[1],p[2]+d[2],p[3]+d[3])
  if occupied[k]then queue[#queue+1]=occupied[k];occupied[k]=nil end
 end
end
eq(#queue,count,"cap, casing, controls and base form one connected machine")
-- Verify every exposed unit face exactly, including winding and sampled
-- source texels after greedy merging. This catches invisible internal faces,
-- missing entry reveals, flipped surfaces and incorrect UV interpolation.
local axes={{2,3},{1,3},{1,2}}
local function faceKey(a,p,b,c)return a..":"..p..":"..b..":"..c end
local expected={}
for y=0,31 do for z=0,39 do for x=0,31 do
 local i=model.at(x,y,z)
 if i then for a=1,3 do for _,d in ipairs({-1,1})do
  local n={x,y,z};n[a]=n[a]+d
  if model.at(unpack(n))==nil and not(a==2 and d==-1 and y==0)then
   local p={x,y,z}
   expected[faceKey(a,p[a]+(d==1 and 1 or 0),p[axes[a][1]],p[axes[a][2]])]={i,d}
  end
 end end end
end end end
local seen={}
local function finite(v)return type(v)=="number" and v==v and math.abs(v)<math.huge end
for _,q in ipairs(quads)do
 for n=1,4 do
  for a=1,3 do ok(finite(q[n][a]),"finite geometry")end
  for a=1,2 do ok(finite(q.uv[n][a]),"finite source UV")end
  ok(finite(type(q.shade)=="table" and q.shade[n] or q.shade),"finite shading")
 end
 local a,p,b0,b1,c0,c1=inspect.face(q)
 ok(b1>b0 and c1>c0,"positive face area")
 local u,v={},{}
 for n=1,3 do u[n]=q[2][n]-q[1][n];v[n]=q[3][n]-q[1][n]end
 local normal={u[2]*v[3]-u[3]*v[2],u[3]*v[1]-u[1]*v[3],u[1]*v[2]-u[2]*v[1]}
 for b=b0,b1-1 do for c=c0,c1-1 do
  local k=faceKey(a,p,b,c);local e=expected[k]
  ok(e~=nil,"emitted face belongs to exposed shell")
  ok(not seen[k],"no duplicated shell face");seen[k]=true
  -- Buildings' established emitter winds Y faces opposite X/Z faces.
  -- Preserve that existing rendering contract in this model-only change.
  local winding = a==2 and -1 or 1
  ok(normal[a]*e[2]*winding>0,"face winding matches the shared voxel emitter")
  for _,db in ipairs({.25,.75})do for _,dc in ipairs({.25,.75})do
   eq(math.floor(inspect.sample(q,a,b+db,c+dc,1)*w),sp.ax[e[1]],"visible source atlas X")
   eq(math.floor(inspect.sample(q,a,b+db,c+dc,2)*h),sp.ay[e[1]],"visible source atlas Y")
  end end
 end end
end
for k in pairs(expected)do ok(seen[k],"no missing machine shell face")end
print(("%d machine geometry/source checks passed; %d voxels, %d quads, height32"):format(checks,count,#quads))
