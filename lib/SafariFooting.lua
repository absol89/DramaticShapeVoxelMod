-- Presentation support is local to each participant in a voxel Safari battle.
-- Keep the camera origin and all native encounter/catch rules untouched.
local V=...;local M={}
function M.ground(battle,arena,side,fallback,map)
 if not(battle and battle.safari and arena)then return fallback end
 map=arena.map or map
 if not map or not V.require('SafariReserve').enabled(map)then return fallback end
 if V.require('UiBackplates').arenaFill:get()~='OFF'then return fallback end
 local p=arena[side];local c=arena[side..'Cell']
 if not p then return fallback end
 local cx,cz=c and c[1]or math.floor(p[1]/16),c and c[2]or math.floor(p[2]/16)
 local ok,h=pcall(V.require('VoxelScene').groundAt,map,cx,cz,p[1]-8,p[2]-8)
 if ok and type(h)=='number'and h==h and math.abs(h)<10000 then return h end
 return fallback
end
-- Restrict bind-hover correction to the land species demonstrated in the
-- supplied Safari reviews. No guess about unreviewed levitating/swimming rigs.
function M.standing(battle,arena,side,map)
 if not(battle and battle.safari and arena)then return false end
 map=arena.map or map
 if not map or not V.require('SafariReserve').enabled(map)
   or V.require('UiBackplates').arenaFill:get()~='OFF'then return false end
 local species=V.require('BattleArt').speciesFor
 if type(species)~='function'or not battle[side]then return false end
 local id=species(battle[side])
 if type(id)~='number'then
  local d=battle.data and battle.data.pokemon and battle.data.pokemon[id]
  id=d and tonumber(d.dex or d.index)
 end
 return id==29 or id==111 or id==128
end
function M.unhover(model,metrics,root,cap)
 local floor,height=tonumber(metrics.floor),tonumber(metrics.height)
 if not(floor and height and floor==floor and height==height and height>0 and math.abs(floor)<1e7 and height<1e7)then return model end
 root=tonumber(root)or 1;if root<=0 then return model end
 local hover=math.min(math.max(floor,0),height*(cap or .5))/root
 if hover==0 then return model end
 -- Model-space offset, independent of the posed feet: native idle, hops and
 -- recoil retain their motion. This also handles shrinking capture matrices.
 return V.require('Mat4').mul(model,V.require('Mat4').translate(0,-hover,0))
end
function M.placements(provider,arena,ground,textures,battle)
 local support=M.ground(battle,arena,'enemy',ground)
 local out=provider.placements(arena,support,textures,battle)
 -- The legacy Stadium 1 adapter owns its matrix function and raw root units.
 -- Keep its data/assets and settings untouched; correct the returned matrix.
 if provider.legendaryStadium1Adapter and type(out)=='table'then
  local p=out.enemy;local mon=p and p.mon;local metrics=mon and mon.model
  if p and p.modelMatrix and metrics and M.standing(battle,arena,'enemy')then
   p.modelMatrix=M.unhover(p.modelMatrix,metrics,metrics.rootScale,mon.HOVER_CAP)
  end
 end
 return V.require('WaterFooting').legacy(out,provider,arena,support,battle)
end
return M
