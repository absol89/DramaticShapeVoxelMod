local V=...;local M={}
function M.model(s)
 if s.map=='LAVENDER_TOWN'then return nil end -- TEST15 is the approved reference.
 if s.kind=='gym'then return V.require('KantoExteriorMaterials').apply(V.require('KantoGymArchitecture').model(s),s)end
 local c=V.require('KantoBuildingStyles').resolve(s)
 if not c or s.x1-s.x0<25 or s.z1-s.z0<14 then return nil end
 local mesh=V.require('KantoServiceBuildings').model(s,c)or V.require('KantoRegionalBuildings').model(s,c)
 return V.require('KantoExteriorMaterials').apply(mesh,s)
end
return M
