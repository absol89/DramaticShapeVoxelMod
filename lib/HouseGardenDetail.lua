-- A restrained finishing pass for the approved cottage/Center/Mart silhouettes.
local V=...;local M={}
function M.append(out,s)
 if not V.require('CityStreets').themes[s.map] or s.map=='ROUTE_17' then return out end
 local G=V.require('CityMesh').new(s.uv);local box=G.box
 local a,b,c,d=s.x0,s.z0,s.x1,s.z1
 local trim=s.map=='FUCHSIA_CITY' and 'wood' or s.map=='VIRIDIAN_CITY' and 'green' or s.map=='PEWTER_CITY' and 'stone' or 'navy'
 -- Shallow corner quoins and a contrasting water table define the foundation.
 for _,x in ipairs({a+.25,c-.95})do
  for y=6,26,5 do box(x,y,d+.08,x+.7,y+1.4,d+.48,'mortar',.91)end
 end
 -- A narrow nameplate above the actual doorway. The approved base model
 -- already supplies a bracket lantern; retain that single clean assembly.
 for _,door in ipairs(s.doors or {})do
  local u=door.u or door.x;local w=door.w or 14
  if u then
   if s.kind~='center' and s.kind~='mart' then
    box(u-2,25.2,d+.22,u+2,26.8,d+.65,trim,.9)
    box(u-1.45,25.6,d+.67,u+1.45,26.3,d+.71,'gold',.9)
   end
  end
 end
 -- Cottage-specific finishing: porch brackets, cornice trim and climbing plants.
 if s.kind~='center' and s.kind~='mart' then
  for _,door in ipairs(s.doors or {})do local u=door.u or door.x
   if u then
    for _,x in ipairs({u-8,u+8})do if x>a+1 and x<c-1 then
     box(x-.18,21.5,d+.15,x+.18,25,d+1.25,'wood',.9)
     box(x-.18,24.5,d+.15,x+.18,24.9,d+2.6,'wood',.95)
    end end
   end
  end
  if s.map=='PALLET_TOWN' then
   box(a+.5,32.4,d+.18,c-.5,32.8,d+.65,'wood',.92)
  elseif s.map=='VIRIDIAN_CITY' or s.map=='FUCHSIA_CITY' then
   for _,x in ipairs({a+1.7,c-1.7})do
    for y=7,19,3 do
     box(x-.12,y,d+.2,x+.12,y+2.2,d+.55,'wood',.9)
     box(x-.55,y+.7,d+.55,x+.55,y+1.4,d+.9,'leaf',1)
    end
   end
  end
 end
 -- Rainwater downpipes at rear corners add useful silhouette detail.
 for _,x in ipairs({a+.5,c-.5})do
  box(x-.22,1.5,b-.5,x+.22,32,b-.08,'dark',.8)
  for y=5,29,8 do box(x-.35,y,b-.55,x+.35,y+.4,b-.03,trim,.9)end
 end
 for _,q in ipairs(G.out)do out[#out+1]=q end
 return out
end
return M
