-- Source-top projection for the full-cell LAB chair; bench stools are separate.
local root=os.getenv('ASTRA_LAB_ROOT')or os.getenv('ASTRA_CANDIDATE')or'.'
local H=dofile('tests/astra_fixture.lua')
local data,w,h=H.atlas(assert(os.getenv('ASTRA_FURNITURE_ATLASES'))..'/lab.rgba')
local emit,m,s=H.building(root,'lab_stool',data,w,h,nil,true,'LAB')
local checks=0
local function ok(v,msg)checks=checks+1;if not v then error('FAIL '..msg,0)end end
local function eq(a,b,msg)ok(a==b,msg..' expected '..tostring(b)..' got '..tostring(a))end
local function color(i)return s.col[assert(i,'expected occupied source texel')]end
local function expected(x,y,z)
 if y==5 then return x>=2 and x<=13 and z>=3 and z<=13 end
 return y>=0 and y<=4 and((x>=3 and x<=4)or(x>=11 and x<=12))and((z>=5 and z<=6)or(z>=10 and z<=11))
end
eq(m.ytop+1,6,'source-derived physical seat height is six')
eq(m.W,16,'chair retains its original one-cell source width')
local count,seat,feet=0,0,0;local palette={[0]=0,[1]=0,[3]=0};local layers={}
for y=0,12 do for z=-1,16 do for x=-1,16 do
 local i=m.at(x,y,z);eq(i~=nil,not not expected(x,y,z),'only a horizontal cushion and four inset2x2 supports occupy the cell')
 if i~=nil then
  count=count+1;layers[y]=(layers[y]or 0)+1;ok(s.inside[i],'all material comes from inside original chair artwork')
  local sx,sy=i%s.W,math.floor(i/s.W)
  ok(sx>=2 and sx<=13 and sy>=2 and sy<=13,'no floor/background or neighboring furniture donors')
  if y==5 then
   seat=seat+1;local d=math.min(x-2,13-x,z-3,13-z);local want=d==0 and 3 or(d<=2 and 0 or 1)
   eq(color(i),want,'one black rim, equal white margins, centered gray cushion')
   palette[color(i)]=palette[color(i)]+1
   eq(color(i),color(m.at(15-x,y,z)),'seat palette mirrors exactly on X')
   eq(color(i),color(m.at(x,y,16-z)),'seat palette mirrors exactly on Z')
  else
   feet=feet+1;eq(sy,13-y,'all support voxels use their exact original elevation row')
   -- The established upright builder walks inward past black outlines
   -- on side surfaces. Keep its own row/material, not a raw facade-index assumption.
   eq(color(i),color(m.at(15-x,y,z)),'support colors retain X symmetry')
   eq(color(i),color(m.at(x,y,16-z)),'support colors retain front/back symmetry')
   ok(m.at(x,y+1,z)~=nil,'every leg joins the seat continuously')
  end
 end
end end end
eq(count,212,'132 cushion voxels plus80 support voxels')
eq(seat,132,'closed twelve-by-eleven cushion');eq(feet,80,'four2x2 posts through five layers')
for y=0,4 do eq(layers[y],16,'no full-depth rails or solid apron below the cushion')end
eq(palette[3],42,'closed one-cell black perimeter');eq(palette[0],60,'equal two-cell white padding');eq(palette[1],30,'centered six-by-five gray field')
for _,p in ipairs({{3,4,5,6},{11,12,5,6},{3,4,10,11},{11,12,10,11}})do
 local ox=p[1]<8 and p[1]-1 or p[2]+1;local oz=p[3]<8 and p[3]-1 or p[4]+1
 for z=p[3],p[4]do ok(m.at(ox,5,z)~=nil,'seat overhangs every outward leg X edge')end
 for x=p[1],p[2]do ok(m.at(x,5,oz)~=nil,'seat overhangs every outward leg Z edge')end
end
local q=emit(m,s,w,h);eq(q.voxels,212,'actual emitted occupancy');eq(#q,220,'bounded chair render cost')
local mesh=H.mesh(q);local _,zero=H.triangles(mesh);eq(zero,0,'no degenerate submitted chair triangles')
for _,v in ipairs(mesh.vertices)do for _,a in ipairs(v)do ok(type(a)=='number'and a==a and math.abs(a)<1e6,'finite chair geometry/UV/shade')end end
-- The original standee treated all occupied source rows as elevation.
local top,bottom=math.huge,-math.huge
for i in pairs(s.inside)do if s.inside[i]then local y=math.floor(i/s.W);top=math.min(top,y);bottom=math.max(bottom,y)end end
eq(bottom-top+1,12,'regression reproduces the twelve-row original upright print')
print(('LAB chair: source standee12 -> seat6;212 voxels,220 quads; centered gray6x5, white2, black1;80 support voxels retain original elevation-row materials'))
print(('%d LAB stool geometry/source checks passed'):format(checks))
