# Safari scenery, original statues, and interior texture repairs

## Changes
- Wider Safari Center rear gatehouse with opaque double doors and enclosed roof, guarded by the original pair of exits.
- Original monster statues rebuilt from their source atlas silhouettes with solid voxel sides/backs and original active-palette colors. Desktop inventory: 94 placements across six tileset families.
- Beveled feet/caps and recessed panels on 65 tall GYM/PLATEAU statue pedestals.
- Tall olive scrub, branches and dry grass replacing 376 exact blocked Safari hedge cells.
- Safari-only muted ground/detail palette and matching distant underlay; Center uses outdoor visual lighting/sky without changing engine map classification.
- HOUSE maps/windows and school blackboard, Red's room windows, Center high windows, LOBBY notices/pictures, and upstairs route-gate window bands are projected onto vertical faces; plain material covers wall tops/sides.
- Atlas-safe UV subdivision for legacy rising/descending stair faces in all directions.
- Mesh cache revision 33. Upstream cave materials, ship rendering and facade entrances retained.

Horizons textures and its olive foreground foliage remain in the separate Horizons mod. No ROM data, generated imported sprite sheets, private saves or native runtime fixtures are included.

## Validation on this PR checkout
- safari_wall_regression_test.lua: shared wall patterns, source UV isolation, idempotence, gate exit guards, foliage bounds, and legacy north/east/west stair directions.
- world_underlay_nature_test.lua: 5 checks.
- museum_fossils_test.lua: bounded skeleton/case geometry, exact placement/fallback and unchanged source maps.
- astra_hanging_scrolls_test.lua: 9,469 checks including real-map fixtures for Oak and Dojo.
- building_facade_culling_test.lua: 18 checks.
- astra_facade_entrances_test.lua: 93,055 checks using local generated map/atlas fixtures.
- Lua syntax checks and git diff --check pass.
- building_canopy_regression_test.lua could not run: tests/harness.lua is absent from this repository.

## Earlier desktop candidate evidence
Native still comparisons cover the gatehouse, statue families/pedestals, Safari foliage/ground, house walls and stairs. The structural audit checked 169 maps, 3,624 stair faces and 626 upright wall-art faces, with unchanged blocks/collision/warp definitions. Separate checks covered the 94 statue placements, 376 foliage footprints, both Safari exits and all five Mansion statue switches.

Those captures and the 169-map audit were made on the desktop candidate before porting onto current upstream. They are not a native walkthrough of every map or an exact-head upstream engine test. Quest performance and native testing of this upstream port remain outstanding. Largest measured foliage mesh: North 122,604 vertices; Center 83,564, East 73,868, West 83,264.
