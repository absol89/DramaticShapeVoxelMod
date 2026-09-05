-- Behavior tests for the optional shared Legendary renderer; no engine or GPU.
local root = os.getenv('ASTRA_MOD_ROOT') or '.'
local checks, failures = 0, 0
local function check(v, s)
  checks = checks + 1
  if not v then failures = failures + 1; print('FAIL ' .. s) end
end
local layout, failUpload = 'separate', false
local created, draws = {}, {}
local Voxel = {
  newMesh = function(vertices, indices)
    if failUpload then return nil end
    local mesh = { vertices=vertices, indices=indices, releases=0 }
    function mesh:release() self.releases=self.releases+1 end
    created[#created+1]=mesh
    return mesh
  end,
  pushQuad = function(indices, n)
    for _, x in ipairs({1,2,3,1,3,4}) do indices[#indices+1]=n*4+x end
  end,
  draw = function(mesh) draws[#draws+1]=mesh end,
  glassMaskNow=function() end, glass=function() end,
}
local modules = { Voxel3D=Voxel, Mat4={translate=function() return {} end},
  CommunityVisuals={layout=function() return layout end,
    pillarColor=function() return 'granite' end,
    customPillars=function() return layout~='default' end} }
local P=assert(loadfile(root..'/lib/GranitePillars.lua'))({
  require=function(name) return assert(modules[name], name) end})
P.textures.granite, P.mask = false, false
local map={id='ASTRA_PILLAR_FIXTURE'}
local cells, bases={}, {}
_G.__bav_granite_pillars={[map.id]=cells}
_G.__bav_granite_pillar_base=bases
local function bk(x,z) return map.id..':'..(x*16+8)..'|'..(z*16+8) end
local function last() return draws[#draws] end
local function low(mesh, axis)
  local n=math.huge
  for _,v in ipairs(mesh.vertices) do n=math.min(n,v[axis]) end
  return n
end
cells['0|0']=true
P.draw(map,0,0)
check(#draws==0, 'unpublished terrain does not invent a pillar at height zero')
bases[bk(0,0)]=4
P.draw(map,0,0)
local first=last()
check(first and math.abs(low(first,2)-4.10)<1e-8, 'first pillar uses published base')
local n=#created
P.draw(map,0,0)
check(#created==n,'stable mesh is reused')
bases[bk(0,0)]=9
P.draw(map,0,0)
local raised=last()
check(raised~=first and math.abs(low(raised,2)-9.10)<1e-8,'height-only edit updates geometry')
check(first.releases==1,'replaced mesh is released once')
cells['0|0'],cells['2|0']=nil,true
bases[bk(2,0)]=9
P.draw(map,0,0)
local moved=last()
check(moved~=raised and low(moved,1)>32,'same-count owner move updates position')
local visible, valid=0,true
for i=1,#moved.indices,3 do
  local a,b,c=moved.vertices[moved.indices[i]],moved.vertices[moved.indices[i+1]],moved.vertices[moved.indices[i+2]]
  if not (a and b and c) then valid=false else
    local ux,uy,uz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
    local vx,vy,vz=c[1]-a[1],c[2]-a[2],c[3]-a[3]
    if (uy*vz-uz*vy)^2+(uz*vx-ux*vz)^2+(ux*vy-uy*vx)^2>1e-16 then visible=visible+1 end
  end
end
check(valid,'indices address uploaded vertices')
check(visible==#moved.indices/3,'no degenerate cap triangles are submitted')
check(visible==192,'all original visible pillar triangles survive')
bases[bk(2,0)]=12
failUpload=true; P.draw(map,0,0); failUpload=false; P.draw(map,0,0)
check(math.abs(low(last(),2)-12.10)<1e-8,'transient upload failure retries')
local final=last()
cells['2|0']=nil
local oldDraws=#draws
P.draw(map,0,0)
check(#draws==oldDraws,'empty ownership draws no stale mesh')
check(final.releases==1,'empty ownership releases former mesh')
cells['1|1'],bases[bk(1,1)]=true,0
P.draw(map,0,0); final=last()
_G.__bav_granite_pillars[map.id]=nil
P.draw(map,0,0)
check(final.releases==1,'removed registry releases mesh')
-- A retained map stays allocated; leaving the terrain neighborhood evicts it.
_G.__bav_granite_pillars[map.id]=cells
P.draw(map,0,0); final=last()
P.setLive({[map.id]=true})
check(final.releases==0,'live neighborhood retains current map')
P.setLive({})
check(final.releases==1 and P.cache[map.id]==nil,'departed map is evicted')
-- A candidate without a published base does not disturb a ready mesh.
P.draw(map,0,0); final=last()
cells['3|3']=true
n=#created; P.draw(map,0,0)
check(#created==n and last()==final,'unpublished neighbor is ignored')
bases[bk(3,3)]=0
P.draw(map,0,0)
check(#created==n+1 and final.releases==1,'late neighbor publication rebuilds once')
P.invalidate()
for _,mesh in ipairs(created) do check(mesh.releases==1,'each created mesh releases exactly once') end
print(('%d checks, %d failures (Astra pillars)'):format(checks,failures))
assert(failures==0,'pillar regressions')
