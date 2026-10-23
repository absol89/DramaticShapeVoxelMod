-- Retag only generated building meshes; terrain, interiors and atlas untouched.
local V=...;local M={REVISION='legendary-exterior-craft-18'}
local names={['ktLime']='exktLime',['ktOchre']='exktOchre',['ktSandstone']='exktSandstone',['ktBasalt']='exktBasalt',['ktPlaster']='exktPlaster',['ktSage']='exktSage',['ktCedar']='exktCedar',['ktCopper']='exktCopper',['ktTerracotta']='exktTerracotta',['ktMarine']='exktMarine',['ktPearl']='exktPearl',['ktBrick']='exktBrick',['ktObsidian']='exktObsidian',['ktSteel']='exktSteel',['ktBronze']='exktBronze',['ktViolet']='exktViolet',['ktGlass']='exktGlass',['lvMauve']='exlvMauve',['lvPlaster']='exlvPlaster',['lvTimber']='exlvTimber',['lvStone']='exlvStone',['lvSlate']='exlvSlate',['lvWalnut']='exlvWalnut',['blue']='exblue',['cream']='excream',['white']='exwhite',['wood']='exwood',['oak']='exoak',['stone']='exstone',['mortar']='exmortar',['slate']='exslate',['terra']='exterra',['tile']='extile',['green']='exgreen',['navy']='exnavy',['red']='exred',['dark']='exdark',['gold']='exgold',['glass']='exglass'}
function M.apply(mesh,s)
 if not mesh then return mesh end
 if s and s.map and s.map~='LAVENDER_TOWN'and not V.require('KantoBuildingStyles').maps[s.map]then return mesh end
 for _,q in ipairs(mesh)do
  local mat=q.referenceMaterial
  if mat and mat:sub(1,2)~='ex'then
   local name=names[mat]
   if s and s.kind=='ruined_mansion'and(mat=='mortar'or mat=='stone')then name='exruin'end
   -- Civic plaster and carved trim must not acquire house siding.
   if mat=='white'and s and s.kind~='house'and s.kind~='scenery_house'and s.kind~='player_house'and s.kind~='rival_house'then name='extrim'end
   if name then q.referenceMaterial=name end
  end
 end
 return mesh
end
return M
