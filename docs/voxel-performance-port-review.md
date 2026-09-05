# Gen2 performance patch review and 1.10.2 adaptation

Reviewed 2026-09-04 against `voxel_performance_fix_gen2_v1.5.0`,
BattleArtGen2's `port/gen1recomp-GSC` (manifest 2.0.9), and this repository's
`1.10.2-fixes` at `9306b7f`. The relevant Gen2 files are identical between
the inspected port branch and its local `main`; neither was modified.

## Safety review

Read the complete source (`main.lua`), manifest, README and changelog before
execution. No apparent malicious behavior: no network access, shell/process
execution, credential access, file writes/deletes, downloaded code, or
obfuscated payloads. The source only looks up dependency exports and replaces
in-memory rendering/budget functions. Its `engine_internals` permission and
global monkey patches nevertheless make compatibility review necessary.
This is a static review of these local files, not a guarantee about other builds.
The external patch was not installed or executed.

## Why it can reduce hitches

| Mechanism in the external patch | 1.10.2 decision |
| --- | --- |
| Presents the world as stack top when Gen2's stack is empty, avoiding an erroneous 30 ms covered-world slice | Not ported. Gen1 pushes its overworld onto the stack; its existing visibility check is appropriate. The Gen2 port's comparison treats an empty stack as covered when a world exists. |
| Queues a smaller BODY before FULL | Already implemented in `VoxelScene.prefetch`; `ChunkMesher.request` promotes the current BODY ahead of FULL. Kept intact. |
| Caps visible BODY work at 6.5 ms and FULL work at 4.75 ms | Adapted inside `ChunkMesher.pump`, using the actual job slot/priority rather than recognizing budget values in a wrapper. |
| Checks the deadline every four ticks instead of every 32 | Adapted as a per-slice option in `BuildBudget.begin`; the original build-coroutine identity guard is retained. |
| Delays newly drawable neighbors | Not ported: global accessors are not a safe visibility boundary for this version. |

The external patch's reported 30–55 ms hitches are claims from its supplied
documentation, not measurements reproduced here. Coarse polling can overshoot
a nominal budget; checking more frequently limits that overshoot when loops
cooperate. The deterministic test models 1 ms iterations: a 4.75 ms slice
yields at iteration 8 with four-call polling, instead of waiting for 32.

## Native scheduling changes

- Current/prioritized BODY: 6.5 ms per pump.
- Other foreground jobs (including distance-prioritized neighbors): 4.75 ms.
- Speculative/idle jobs: unchanged 5 ms.
- Covered jobs: unchanged 30 ms with default 32-call polling.
- All visible pumped work uses four-call polling. Direct/synchronous users and
  unrelated coroutines remain unable to yield against somebody else's budget.
- One deadline covers the entire pump, even if several short jobs complete.
  This avoids a weakness of externally capping each `begin` while leaving the
  pump's original outer 12 ms deadline intact.

No changes to geometry, assets, cache formats, main.lua, save data, rendering
accessors, or the existing battle-shadow fix.

## Why neighbor staging was excluded

The patch's `ChunkMesher.pair` wrapper returns only terrain and water. In 1.10.2
the additional returns carry visual-object color/shadow sidecars, including
signs. Dropping these would regress rendering. Its global `TerrainAtlas.forMap`
wrapper can also deny atlases to non-overworld consumers such as alternate
battle arenas. Meanwhile 1.10.2 draws some neighbor decorations through other
paths, so suppressing terrain alone would not consistently stage the scene.
Its exposed-map set also outlives cache eviction, so revisits are not necessarily
staggered. A safe implementation would need coordinated scene-local terrain,
water, decorations, shadows and atlas activation, plus seam/battle tests.

## Validation and limits

94 checks passed under the bundled LÖVE/LuaJIT runtime:

- 35 new deterministic budget/scheduler checks, including shared deadlines,
  BODY priority, completion, failure cleanup and unrelated-coroutine safety.
- 18 Stadium model bridge checks.
- 25 BattleScene visual-sidecar checks.
- 16 building/canopy regression checks using the actual geometry code.

The deliberate failed-job test prints one expected warning. `git diff --check`
also passes. No live installation or in-game FPS/visual benchmark was performed.
Smaller slices trade build completion speed for responsiveness; terrain may
take more frames to appear. Individual non-yielding operations (including GPU
uploads) can still exceed a slice. Before release, test cold starts, door warps,
seam crossings, populated routes, covered transitions and cache rebuilds on
desktop and a slower/mobile target. Neighbor first-draw spikes are not addressed
by this conservative adaptation.
