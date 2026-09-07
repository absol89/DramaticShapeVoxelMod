# RAM PRECACHE MB: OFF and iOS crash audit

2026-09-06. Local working-tree changes; no release or push.

## OFF behaviour

OFF now has the same meaning on every platform:

- No title-menu cache backend probe, cache enumeration, or RAM preload screen.
- No persistent voxel-cache reads during gameplay. A missing session record
  causes live generation, even when a matching persistent record exists.
- Generated compressed records are retained in session RAM. A disk backend is
  not required for this RAM layer. Uploaded live meshes retain their existing
  cache/eviction behaviour.
- No predictive destination generation or atlas warming. Selecting OFF cancels
  the active speculative job unless the live renderer has promoted it.
- Current terrain and the neighbours required by the live scene still generate
  cooperatively. Their requests are not speculative loading.
- Switching OFF discards disk-preloaded records while retaining records generated
  this session, including ones the user explicitly saved earlier.
- Manual PRECACHE and CACHE -> SAVE remain explicit persistence actions. Merely
  entering the title or pause menu with OFF does not bind/probe cache storage.

The iOS/Metal special case that translated OFF into FULL was removed. OFF also
now disables the previous on-demand disk fallback and predictive warmer, rather
than just hiding the Continue loading screen.

Session RAM can still grow as new areas are visited. OFF is not a memory ceiling
and does not reduce the vertex count or native memory footprint of live meshes.

## API and garbage-collection scan

Searched production `main.lua` and `lib/*.lua`, separately from engine code and
test/driver scripts. Useful repeatable searches from this repository root:

```powershell
rg -n 'love\s*\.\s*system|collectgarbage|getOS|ffi\.gc' main.lua lib -g '*.lua'
rg -n 'preload|prefetch|warmAtlas|beginSession|ramPlan|readBytes' main.lua lib -g '*.lua'
```

The `love.system` matches in the active mod are explanatory comments, not
executed calls. Renderer/platform checks already use allowed graphics APIs or
the engine's Platform module. Engine source has direct `love.system` calls, but
engine code runs outside the mod sandbox; those are not evidence of a forbidden
mod access.

One direct unguarded `collectgarbage("collect")` existed in
`VoxelPrecacheScreen.finish`. It is now guarded. The two existing guarded sites
in `VoxelCacheRamScreen` and `VoxelMeshDisk` now also perform lookup/invocation
inside the protected closure. A missing or rejected API cannot abort completion.
No collector stop/restart manipulation was found in these production modules.

These full collections occur at explicit cache/preload lifecycle points, not
ordinary map traversal. Guarding them catches Lua errors, not an operating-system
memory termination or a native renderer fault. No supplied iOS crash log identifies
either as the reported cause.

## Map evidence

User report: Pallet Town was safe; Route 1 and a separate Celadon save crashed.
No iOS crash report or exact visual settings were supplied.

Read-only local audit used extracted **Yellow** map data and its overworld atlas,
the current mod, actual `Structures` and `ChunkMesher` code, ordinary connection
masks, and a counting sink which checks finite vertex positions. This avoids
allocating/uploading GPU meshes. All three maps completed without a geometry
exception in both default and Legendary settings. This is not an iOS reproduction.

Default visual settings, current-map FULL terrain only:

| Map | Blocks | NPC records | Sign records | Cut-tree cells | Terrain quads | Raw terrain vertices | Grass quads |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Pallet Town | 10 × 9 | 3 | 4 | 0 | 137,186 | 18.84 MiB | 464 |
| Route 1 | 10 × 18 | 2 | 1 | 0 | 214,428 | 29.45 MiB | 12,064 |
| Celadon City | 25 × 18 | 9 | 9 | 2 | 578,973 | 79.51 MiB | 0 |

Raw bytes are calculated as six vertices × six 32-bit floats per quad, matching
the production packed format. They exclude the BODY variant, connected maps,
grass/flowers, textures, render targets, shadows, Lua structures, cache buffers
and any driver-side copies. These are component estimates, not process-memory
measurements. Lua heap growth observed during Celadon default geometry was about
143 MiB in this run; GC timing makes that number variable, and it is not peak RSS.

The Route 1 audit contains ordinary round trees, tall grass, ledges and one sign;
there are no cut-tree source cells or water/building classes in its body. Cut
trees therefore do not explain both maps by themselves. Celadon is substantially
heavier in building/object quads. Shared tree geometry, cumulative connected-map
memory, and generation/upload transient allocations are stronger leads than a
Route 1-only authored object.

With Legendary options enabled, static-terrain byte counts are smaller because
custom trees are drawn separately. Those numbers must not be interpreted as the
total cost of Legendary visuals; their separate model/texture draws were not
measured here.

The most useful next evidence is the affected device's crash/termination report
and exact visual settings. A memory termination versus a native graphics fault
would point the next investigation in different directions. The source audit
alone does not prove the crash cause or that the OFF change fixes it.

## Verification

Engine-root tests with `DS_MOD_PATH=dev/DramaticShapeVoxelMod`:

- `ram_precache_setting_test.lua`: 30 checks, including identical OFF budget on iOS.
- `ram_precache_off_test.lua`: 19 checks, using storage spies and a deterministic
  test codec around the real record serialization. Covers no-backend RAM,
  generated-record reuse, ignored disk records, no listing/reads, explicit SAVE,
  switching modes, ownership spans, and missing GC.
- `ram_precache_off_integration_test.lua`: 22 checks through the loaded mod's title
  hooks and gameplay update, predictive cancellation/promotion, and rejected GC.
- The six restoration suites still pass: 202 checks.

Mod-root build-budget and storage-binding tests also pass: 35 + 6 checks.
Lua syntax and Git whitespace checks pass. No iOS/GPU gameplay test was performed.
