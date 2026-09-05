-- Source-faithful LOBBY round tabletop: level symmetric rim and one centered pedestal.
local H=dofile('tests/astra_fixture.lua')
local root=os.getenv('ASTRA_CANDIDATE') or '.'
local atlas=os.getenv('ASTRA_LOBBY_ATLAS') or assert(os.getenv('ASTRA_FULL_ATLASES'),'set ASTRA_LOBBY_ATLAS or ASTRA_FULL_ATLASES')..'/lobby.rgba'
local data,w,h=H.atlas(atlas)
local emit,m,sp=H.building(root,'lobby_round_table',data,w,h,nil,true,'LOBBY')
local n,top,pedestal,checks=0,0,0,0
local function ok(v,msg)checks=checks+1;assert(v,msg)end
local function color(x,y,z)local i=m.at(x,y,z);return i and sp.col[i]end
ok(m.ytop==7,'source facade is eight pixels high')
ok(m.W==32 and m.zmin==0 and m.zmax==31,'exact four-tile square footprint')
local seen,first={}
local function key(x,y,z)return x..','..y..','..z end
for y=0,m.ytop do for z=0,31 do for x=0,31 do
 local i=m.at(x,y,z)
 if i then
  n=n+1;first=first or {x,y,z};seen[key(x,y,z)]={x,y,z}
  ok(sp.inside[i],'all donors are furniture source artwork')
  local tile=math.floor(sp.ay[i]/8)*(w/8)+math.floor(sp.ax[i]/8)
  ok(tile~=55,'shared floor tile must never supply table material')
  ok(color(31-x,y,z)==sp.col[i],'left/right shape and palette symmetric')
  ok(color(x,y,31-z)==sp.col[i],'front/back shape and palette symmetric')
  if y<6 then
   pedestal=pedestal+1;ok(x>=8 and x<=23 and z>=8 and z<=23,'pedestal centered inside overhang')
  else
   ok(m.at(x,13-y,z)~=nil,'both tabletop layers have same footprint')
  end
  if y==7 then top=top+1 end
 end
end end end
ok(n==2472 and top==912 and pedestal==648,'authored geometry count')
for z=0,31 do for x=0,31 do
 local c=color(x,7,z)
 if c then
  local edge=not color(x-1,7,z) or not color(x+1,7,z) or not color(x,7,z-1) or not color(x,7,z+1)
  if edge then ok(c==3,'continuous black outer edge') end
  if c==1 then
   for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
    local q=color(x+d[1],7,z+d[2]);ok(q==0 or q==1,'white padding separates field from outer rim')
   end
  end
 end
end end
-- No floating or detached slices anywhere in the finished table.
local queue={first};seen[key(unpack(first))]=nil;local head=1
while head<=#queue do
 local p=queue[head];head=head+1
 for _,d in ipairs({{-1,0,0},{1,0,0},{0,-1,0},{0,1,0},{0,0,-1},{0,0,1}})do
  local k=key(p[1]+d[1],p[2]+d[2],p[3]+d[3]);local q=seen[k]
  if q then seen[k]=nil;queue[#queue+1]=q end
 end
end
ok(#queue==n and next(seen)==nil,'single connected furniture body')
local q=emit(m,sp,w,h);ok(q.voxels==n and #q==748,'mesh budget')
local _,zero=H.triangles(H.mesh(q));ok(zero==0,'no degenerate triangles')
for _,bad in ipairs({{-1,0},{0,0},{32,7},{15,32}})do
 local good,why=pcall(function()
  H.building(root,'lobby_round_table',data,w,h,nil,true,'LOBBY',function(spec)
   for _,t in ipairs(spec.buildings.LOBBY)do if t.id=='lobby_round_table'then t.parts[1].sample=bad end end
  end)
 end)
 ok(not good and tostring(why):find('flat donor must belong',1,true),'invalid/floor donor rejected')
end
print(('PASS round table: %d geometry/source checks, %d voxels/%d quads, one connected symmetric body.'):format(checks,n,#q))
