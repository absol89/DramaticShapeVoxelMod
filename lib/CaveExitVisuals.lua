-- Authored flat cave mouths only. LAST_MAP is checked against the exact
-- exported warp and source tile33 footprint; ladders and interior links keep
-- their existing geometry. The shell lives wholly in the warp cells, never
-- cuts the surrounding maze walls, and does not change gameplay data.
local M = {}
local profiles = {
 {map='MT_MOON_1F',x=14,z=35,width=2,face='south',destWarp=2},
 {map='VICTORY_ROAD_1F',x=8,z=17,width=2,face='south',destWarp=3},
 {map='VICTORY_ROAD_2F',x=29,z=7,width=2,face='east',destWarp=4},
 {map='DIGLETTS_CAVE_ROUTE_2',x=2,z=7,width=2,face='south',destWarp=1},
 {map='DIGLETTS_CAVE_ROUTE_11',x=2,z=7,width=2,face='south',destWarp=5},
 {map='CERULEAN_CAVE_1F',x=24,z=17,width=2,face='south',destWarp=7},
 {map='SEAFOAM_ISLANDS_1F',x=4,z=17,width=2,face='south',destWarp=1},
 {map='SEAFOAM_ISLANDS_1F',x=26,z=17,width=2,face='south',destWarp=2},
}
local function matches(map,p)
 if not (map and map.def and map.def.tileset=='CAVERN' and map.id==p.map) then return false end
 for i=0,p.width-1 do
  local cx,cz=p.x+(p.face=='south' and i or 0),p.z+(p.face=='east' and i or 0)
  if not map:inBounds(cx,cz) then return false end
  local warp=map:warpAtCell(cx,cz);local w=warp and warp.def
  if not w or w.destMap~='LAST_MAP' or w.destWarp~=p.destWarp then return false end
  for z=0,1 do for x=0,1 do if map:tileAt(cx*2+x,cz*2+z)~=33 then return false end end end
 end
 return true
end
function M.placements(map)
 local out={};for _,p in ipairs(profiles) do if matches(map,p) then out[#out+1]=p end end;return out
end
local function donors(data,perRow)
 -- The existing cave atlas supplies its own rock and daylight colour. Only
 -- opaque texels from the rock drawing are eligible; no generated texture.
 local dark,light,bestD,bestL=nil,nil,math.huge,-math.huge
 for _,tile in ipairs({2,3,12}) do for y=0,7 do for x=0,7 do
  local px,py=tile%perRow*8+x,math.floor(tile/perRow)*8+y
  local r,g,b,a=data:getPixel(px,py)
  if a>.99 then local lum=r*.2126+g*.7152+b*.0722
   if lum<bestD then bestD=lum;dark={px+.5,py+.5} end
   if lum>bestL then bestL=lum;light={px+.5,py+.5} end
  end
 end end end
 return dark,light
end
function M.build(S,map,data,perRow)
 local placements=M.placements(map)
 if #placements==0 or not data then return 0 end
 local dark,light=donors(data,perRow);if not dark or not light then return 0 end
 local aw,ah=data:getDimensions();local emitted=0
 for _,p in ipairs(placements) do
  local width=p.width*16
  local function point(x,y,z)
   if p.face=='east' then return {p.x*16+z,y,p.z*16+width-x} end
   return {p.x*16+x,y,p.z*16+z}
  end
  local function quad(a,b,c,d,donor,shade,role)
   local uv={donor[1]/aw,donor[2]/ah}
   local q={point(unpack(a)),point(unpack(b)),point(unpack(c)),point(unpack(d)),
    uv={uv,uv,uv,uv},shade=shade,caveExitRole=role}
   S.objectQuads[#S.objectQuads+1]=q;emitted=emitted+1
  end
  -- Tessellate each plane on <=8px spans like the surrounding world, so the
  -- existing curved-world vertex transform cannot bow a whole doorway.
  local function plane(axis,value,a0,a1,b0,b1,donor,shade,role,reverse)
   for a=a0,a1-1e-6,8 do for b=b0,b1-1e-6,8 do
    local an,bn=math.min(a+8,a1),math.min(b+8,b1)
    local function pt(u,v) if axis==1 then return {value,u,v} elseif axis==2 then return {u,value,v} else return {u,v,value} end end
    local v1,v2,v3,v4=pt(a,b),pt(an,b),pt(an,bn),pt(a,bn)
    if reverse then quad(v4,v3,v2,v1,donor,shade,role) else quad(v1,v2,v3,v4,donor,shade,role) end
   end end
  end
  -- Hollow rock returns: two narrow jambs and a three-pixel lintel. No
  -- opaque face covers the entrance plane. Daylight is recessed 12px, ahead of the existing rock facets.
  plane(1,0,0,24,0,16,dark,.8,'outer-west',true)
  plane(1,2,0,21,0,16,light,.40,'inner-west')
  plane(1,width,0,24,0,16,dark,.75,'outer-east')
  plane(1,width-2,0,21,0,16,light,.35,'inner-east',true)
  plane(2,24,0,width,0,16,light,.60,'roof')
  plane(2,21,2,width-2,0,16,dark,.65,'ceiling',true)
  plane(3,0,0,2,0,24,light,.55,'jamb-west',true)
  plane(3,0,width-2,width,0,24,light,.50,'jamb-east',true)
  plane(3,0,2,width-2,21,24,light,.65,'lintel',true)
  -- The cave palette and ambient term darken white rock substantially.
  -- A local high vertex tone makes only the distant opening read as light;
  -- no shader, atlas, global lighting or gameplay state is changed.
  plane(3,12,2,width-2,.08,21,light,8,'daylight',true)
  plane(2,.08,2,width-2,0,8,light,.50,'lit-floor')
  plane(2,.08,2,width-2,8,12,light,1.4,'lit-floor')
 end
 return emitted
end
return M
