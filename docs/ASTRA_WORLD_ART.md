# Astra world-art integration

This port reconstructs furniture and scenery from the original tileset pixels.
It addresses floor pixels extruded into furniture, uneven rims and overhangs,
flat equipment and bicycles, stair/ladder orientation, and the S.S. Anne exterior.

## Review map

| Area | Primary files | Result |
| --- | --- | --- |
| Authored furniture | `data/voxel_heights.lua`, `lib/Buildings.lua` | Centered chairs and tables, consistent rims, inset legs, clean material donors; beds, cabinets, workbenches and ship interiors |
| Computers and Bill's equipment | `lib/ComputerCase.lua`, `lib/BillMachine.lua`, `lib/BillPipe.lua` | Volumetric cases and machinery; the metal pipe becomes a tube |
| Bikes and facility plants | `lib/BikeDisplay.lua`, `lib/FacilityPalm.lua` | Open wheels, frames and separated source-based forms |
| S.S. Anne | `lib/ShipExterior.lua`, `lib/ShipHull.lua` | Hull, deck, railings, hollow funnels and a fixed boarding opening; departure-aware drawing |
| Stairs and ladders | `lib/InteriorStairs.lua`, `lib/CaveLadders.lua`, `lib/CaveSteps.lua`, `lib/TileShape.lua`, `lib/Structures.lua` | Authored directions, visible treads/rungs and consistent visual foot support |
| Contacts and rendering | `lib/VoxelScene.lua`, `lib/SpriteBillboards.lua`, `lib/BattleArena.lua` | Scoped seated/item anchors and cave-step support; current character providers retain first refusal |
| Shading and lifetime | `lib/ChunkMesher.lua`, `lib/GranitePillars.lua`, `lib/VoxelMeshDisk.lua` | Continuous detail-face ambient lighting, pillar cache ownership/release fixes and cache revision 30 |
| Reference tooling | `tools/*voxels.py`, `tools/bill_machine.py`, `tools/bill_pipe.py`, `tools/facility_palm.py` | Offline geometry/reference generators, not engine dependencies |

Rooms covered by the cumulative work include Red's house, Oak's lab, Bill's
house, ordinary houses, public interiors, the Cinnabar Mansion and S.S. Anne.
The geometry tests include exact source donors, surface winding, room claims,
actor contacts and preservation checks outside each authored footprint.

## Integration constraints

Base: Absol's `master`, `c3b0ae8a80d7e565e3f08c6f6fe8187e570c8a61`, checked
2026-09-05. The earlier Astra work began at `34ab87535cacb0ec2644f4de65c6bd00d91496b6`;
this is an integrated port, not a replacement of the current upstream tree.

Current Stadium, character-provider, Legendary sign/sapling and cave-perimeter
work is retained. Current upstream's cave sunlight suppression and camera-based
reflections are retained. The approved pillar appearance is retained; its change
is cache tracking and allocation lifetime. Existing build-budget scheduling and
manifest identity/version remain upstream's. Disk revision 30 invalidates old
geometry while retaining the current upstream serialization layout.

Runtime meshes use original tileset material samples. No ROM, generated atlas,
imported model pack, save or companion runtime is included. No engine gameplay,
collision, warp, inventory or input implementation is changed. Visual support
and automatic battle-stage eligibility are intentionally adjusted at the scoped
cave steps; explicit authored battle placement remains unchanged.

## Verification and reproduction

With Python 3 and LuaJIT on PATH, from any directory:

```sh
python tools/run_astra_review.py --output review-results.json
```

The default runs 13 current upstream feature tests and compiles 105 production
Lua files. All passed on this checkout. A separate `luajit tests/astra_pillar_test.lua`
passed 25 cache/lifetime assertions.

The full local art audit ran 60 commands: 58 passed, with two legacy tests failing
identically on the untouched current upstream baseline and this candidate:

- `voxel_seam_ao_test.lua`: the connected-water-edge fixture reports no expected
  corners and 14 shaded corners.
- `legendary_visuals_test.lua`: assumes seven options where upstream now has nine,
  then calls the removed `_source` helper.

These are disclosed failures, not a green full-suite claim. The 13 current
feature tests cover Stadium APIs, character selection/hosting, Legendary
sign/sapling options, camera cycling and build-budget behavior.

To reproduce the art audit, copy `docs/astra-fixtures.example.json`, fill in local
paths to your engine, generated source atlases and historical stage baselines,
then run:

```sh
python tools/run_astra_review.py --fixtures fixture-paths.json --output full-results.json
```

The full runner returns nonzero for any failure, including the two documented
upstream failures. Fixture files are deliberately excluded from source control;
a fresh clone alone cannot reproduce the historical geometry comparisons.
`ASTRA_CURRENT_UPSTREAM` must reference a clean checkout of the base commit above.
The other baseline keys refer to the historical stages named by the tests.
The ship-stool baseline is distinct from the later ship-furniture baseline.

Historical fixture adaptations account for upstream's sapling metadata,
character-provider callbacks and cave sunlight suppression. Terrain geometry is
compared to current upstream. Beach House retention is checked by actual room
claims, source tiles, palm classification and actor contacts rather than stale
whole-file equality. Actual GPU reflections are outside the mocked tests.

## Visual evidence and remaining release validation

The companion `Battle-Art-Complete-Before-and-After.html` is an offline review:
22 stages, 280 comparisons and 474 unique source captures, with per-view evidence labels.
It records the cumulative Astra work through Astra22/cache30, including eight matched cabin-detail views.
It is historical evidence, not a capture of this current-upstream/cache30 port.

Astra21 and Astra22 isolated native Windows runs used Gen1Recomp 0.2.27. Its original audit
passed 59 commands and compiled 104 production Lua files. Ship warps, departure,
boarding/return and Bike Shop interaction paths were exercised there. These
claims do not establish current upstream's target engine 0.2.53 compatibility.

Before marking the PR ready to merge, playtest the integrated checkout on
Gen1Recomp 0.2.53: Red's bedroom, Oak's computers/items, Bill's equipment, house
seating, public stairs, cave ladders/treads, Bike Shop and the S.S. Anne boarding/
departure path. Include Legendary on/off, character-provider fallback, water
reflections and cold-cache/revisit behavior. Quest performance and headset
rendering have not been certified for this port. Historical geometry counts
are not FPS or memory measurements.

## Added cabin detail pass

Ship wall tops are plain white; vertical portholes remain. Mug drawings become
hollow handled cups, and bunks gain raised pillows, blankets and turned edges.
667458 focused checks cover final surfaces and all12 SHIP maps. The base-form
test keeps the current original part prefix; the new test verifies every final
exposed face, including the appended relief layers. Eight matched native0.2.27
views document this addition. No live installation was performed.
