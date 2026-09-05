-- Source-aware cave rails, rung gaps and open downward shafts.
local root=rawget(_G,'ASTRA_STAIRS_TEST_ROOT')or os.getenv('ASTRA_CANDIDATE')or'.'
local baseline=os.getenv('ASTRA_STAIRS_BASELINE')or'../artifacts/battle-art-astra-stairs/baseline-mod'
local T=dofile(root..'/tests/astra_stair_fixture.lua');local H,F=T.H,T.F
local data,aw,ah=H.atlas(os.getenv('ASTRA_CAVE_ATLAS')or'../artifacts/battle-art-astra-stairs/cave-audit/private/cavern.rgba')
local before,after=T.runtime(baseline,data),T.runtime(root,data)
local checks=0
local function ok(v,msg)checks=checks+1;if not v then error('FAIL '..msg,0)end end
local function eq(a,b,msg)ok(a==b,msg..' expected '..tostring(b)..' got '..tostring(a))end
local function same(a,b,msg)
 eq(type(a),type(b),msg..' type');if type(a)~='table'then eq(a,b,msg);return end
 for k,v in pairs(a)do same(v,b[k],msg..'.'..tostring(k))end
 for k in pairs(b)do ok(a[k]~=nil,msg..' no extra '..tostring(k))end
end

local map=F.Map.new(F.maps.SEAFOAM_ISLANDS_B2F,F.tilesets.CAVERN);local cave=after.module('CaveLadders')
local samples={{id='up',cx=5,cz=3,down=false,rim=0,vox=176},{id='down-ground',cx=5,cz=13,down=true,rim=0,vox=180},{id='down-shelf',cx=25,cz=3,down=true,rim=6,vox=228}}
local function key(x,y,z)return x..','..y..','..z end
local function faceKey(axis,at,a,b,sign)return table.concat({axis,at,a,b,sign},',')end
local dirs={{1,-1},{1,1},{2,-1},{2,1},{3,-1},{3,1}}
for _,c in ipairs(samples)do
 local S=after.render(map,{c.cx*2,c.cx*2+1,c.cz*2,c.cz*2+1});local mx,mz=c.cx*16,c.cz*16
 local expected={};local cells={};local expectedFaces={};local rungY=c.down and{[-11]=10,[-7]=7,[-3]=4}or{[2]=10,[6]=7,[10]=4,[14]=1}
 local bottom,top=c.down and -16 or 0,c.down and c.rim+2 or 16;local z0=c.down and 3 or 6
 for y=bottom,top-1 do for z=z0,z0+1 do for x=3,12 do
  local rail=x==3 or x==4 or x==11 or x==12;local row=rungY[y];local rung=not rail and row~=nil
  if rail or rung then
   local sx,sy=x,row
   if rail then if x==3 or x==12 then sx,sy=3,4 else sy=c.down and(y< -8 and 9 or 2)or(y<4 and 11 or(y<8 and 9 or 2))end end
   local tile=map:tileAt(c.cx*2+math.floor(sx/8),c.cz*2+math.floor(sy/8));local ax=(tile%16)*8+sx%8;local ay=math.floor(tile/16)*8+sy%8
   local v={x=x,y=y,z=z,ax=ax,ay=ay,role=rail and'rail'or'rung'};expected[key(x,y,z)]=v;cells[#cells+1]=v
  end
 end end end
 eq(#cells,c.vox,'only two narrow rails and source-count crossbars are solid')
 for _,p in ipairs(cells)do for _,d in ipairs(dirs)do
  local q={p.x,p.y,p.z};q[d[1]]=q[d[1]]+d[2]
  if not expected[key(q[1],q[2],q[3])]then
   local axis,sign=d[1],d[2];local coords={p.x,p.y,p.z};local at=coords[axis]+(sign>0 and 1 or 0);local a,b
   if axis==1 then a,b=p.z,p.y elseif axis==2 then a,b=p.x,p.z else a,b=p.x,p.y end
   expectedFaces[faceKey(axis,at,a,b,sign)]=p
  end
 end end
 local actualFaces={};local roleArea={};local realRim,donor=cave.rim(map,c.cx,c.cz)
 if c.down then eq(realRim,c.rim,'selected shaft mouth datum')end
 for _,q in ipairs(S.objectQuads)do
  local p={};local mins={math.huge,math.huge,math.huge};local maxs={-math.huge,-math.huge,-math.huge}
  for i=1,4 do p[i]={q[i][1]-mx,q[i][2],q[i][3]-mz};for a=1,3 do local v=p[i][a];ok(v==v and math.abs(v)<1e5,'finite vertices');mins[a]=math.min(mins[a],v);maxs[a]=math.max(maxs[a],v)end end
  local axis
  for a=1,3 do
   if mins[a]==maxs[a]then ok(not axis,'quad has one planar axis');axis=a
   else ok(maxs[a]-mins[a]<=8,'every face span respects curvature size');eq(math.floor((mins[a]+1e-6)/8),math.floor((maxs[a]-1e-6)/8),'every face splits at8px lattice')end
  end
  ok(axis~=nil,'axis-aligned source geometry');local u,v={},{}
  for a=1,3 do u[a]=p[2][a]-p[1][a];v[a]=p[3][a]-p[1][a]end
  local normal={u[2]*v[3]-u[3]*v[2],u[3]*v[1]-u[1]*v[3],u[1]*v[2]-u[2]*v[1]}
  ok(math.abs(normal[axis])>0,'nondegenerate first triangle');local _,zero=H.triangles(H.mesh({q}));eq(zero,0,'both submitted triangles have area')
  -- Existing renderer top-Y convention is opposite physical cross-product;
  -- X/Z use physical winding. Preserve that explicit shared contract.
  local sign=normal[axis]>0 and 1 or -1;if axis==2 then sign=-sign end
  local ax,ay=math.floor(q.uv[1][1]*aw),math.floor(q.uv[1][2]*ah)
  for i=1,4 do eq(math.floor(q.uv[i][1]*aw),ax,'one source texel per surface');eq(math.floor(q.uv[i][2]*ah),ay,'no texture seam or floor bleed')end
  ok(ax>=0 and ax<aw and ay>=0 and ay<ah,'source donor inside atlas')
  local role=q.caveLadderRole;ok(role~=nil,'each independent surface names its source role')
  local amin,amax,bmin,bmax
  if axis==1 then amin,amax,bmin,bmax=mins[3],maxs[3],mins[2],maxs[2]elseif axis==2 then amin,amax,bmin,bmax=mins[1],maxs[1],mins[3],maxs[3]else amin,amax,bmin,bmax=mins[1],maxs[1],mins[2],maxs[2]end
  local area=(amax-amin)*(bmax-bmin);roleArea[role]=(roleArea[role]or 0)+area
  if role=='rail'or role=='rung'then
   for b=bmin,bmax-1 do for a=amin,amax-1 do
    local k=faceKey(axis,mins[axis],a,b,sign);ok(not actualFaces[k],'no duplicate exposed rail/rung surfaces');local want=expectedFaces[k];ok(want,'no inward, internal or gap-filling rail/rung face')
    eq(ax,want.ax,'exact original rail/bar source X');eq(ay,want.ay,'exact original rail/bar source row retains dim lower bars');eq(role,want.role,'source role remains on its own primitive');actualFaces[k]=true
   end end
  else
   ok(c.down,'UP contains no pit or hidden background slab')
   if role=='rim'or role=='rim-outer'then
    eq(ax,(donor%16)*8+3,'rim samples genuine neighboring floor');eq(ay,math.floor(donor/16)*8+3,'rim never repeats ladder source art')
    if role=='rim'then eq(axis,2,'rim is horizontal');eq(mins[2],c.rim,'rim matches approach floor');eq(sign,1,'rim faces up by renderer convention')
     ok(maxs[1]<=2 or mins[1]>=14 or maxs[3]<=2 or mins[3]>=14,'no cap covers the shaft opening')
    else ok(c.rim==6 and mins[2]==0 and maxs[2]<=6,'raised rim outer apron joins old floor0')end
   else
    local tile=map:tileAt(c.cx*2,c.cz*2);eq(ax,(tile%16)*8+3,'shaft uses original black outline donor');eq(ay,math.floor(tile/16)*8+4,'shaft never samples rung white or floor')
    local roles={['shaft-west']={1,2,1},['shaft-east']={1,14,-1},['shaft-north']={3,2,1},['shaft-south']={3,14,-1},['shaft-bottom']={2,-16,1}}
    local want=roles[role];ok(want,'known cavity surface');eq(axis,want[1],'shaft wall axis');eq(mins[axis],want[2],'shaft boundary closed at expected plane');eq(sign,want[3],'shaft wall faces into opening / bottom faces up')
   end
  end
 end
 for k in pairs(expectedFaces)do ok(actualFaces[k],'every exposed rail/rung face exists; shell has no holes')end
 if c.down then
  eq(roleArea.rim,112,'exact narrow16x16 frame around12x12 opening');eq(roleArea['shaft-bottom'],144,'one complete closed black bottom')
  for _,role in ipairs({'shaft-west','shaft-east','shaft-north','shaft-south'})do eq(roleArea[role],12*(16+c.rim),'shaft side closes full mouth-to-bottom span')end
  eq(roleArea['rim-outer']or 0,64*c.rim,'raised frame joins its underlying datum without open sides')
  for y=-15,c.rim+1 do ok(not expected[key(8,y,8)],'actor/entry center remains entirely clear')end
 end
 for y=bottom,top-1 do if not rungY[y]then for x=5,10 do ok(not expected[key(x,y,z0)],'every intended rung gap is open')end end end
 print(('%s: %d quads,%d rail/bar voxels; source-only rails and%d bars; exact closed shell,8px splits; rim%d'):format(c.id,#S.objectQuads,#cells,c.down and 3 or 4,c.down and c.rim or 0))
end
print(('%d cave ladder geometry/source/shaft checks passed'):format(checks))
