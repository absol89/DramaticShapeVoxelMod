# BODY/RING release check - 2026-10-25

Branch legendary-update-1.11.2; release base 39ff49d with existing uncommitted
TEST267 and BODY/RING work preserved. No engine production changes, version
bump, commit, tag or push in this check.

## Finding and fix

The SDK OFF integration uncovered a real cancellation regression: FULL now
queues both BODY and RING, but cancelSpeculative(false) only cancelled RING.
The remaining BODY continued speculative work after RAM precache was switched
OFF. Cancellation now visits its speculative BODY too, retaining BODY jobs
promoted to visible/current use. The existing test failed 20/22 before the fix;
it now passes 26/26 with extra shared-visible-BODY and repeat-cancellation checks.

Two older test fixtures also needed adaptation: scheduler FULL requests now
queue two jobs and start with BODY's bootstrap deadline; the RAM settings test
needed its LoadTimings stub and the new BODY-before-RING preload order.
Production scheduling deadlines were not changed to satisfy these tests.

## Results

LuaJIT 2.1 through the existing Lupa runtime; separate processes for SDK suites
because the harness terminates with os.exit:

- mesh_partition_test: 569 checks, including FULL = BODY + RING, masks, trees,
  shared allocation, empty rings and neighborhood priority.
- voxel_mesh_disk_format_test: 47 checks; compatibility and retired FULL policy.
- voxel_mesh_disk_storage_test: 7 checks.
- astra_cave_exit_visuals_test: 13,271 checks, eight actual Yellow map mouths,
  mocked atlas. No player save used or written.
- voxel_build_budget_test: 35 checks; shared pump deadline, yielding and errors.
- voxel_transition_gate_test: pass.
- legendary_world_off_test: 30 checks.
- item_ball_setting: pass, including profile/persistence/render ownership.
- ram_precache_off_test: 23/23.
- ram_precache_setting_test: 32/32.
- ram_precache_off_integration_test: 26/26, actual SDK mod loading and hooks.
- All 346 production Lua files compile.
- TEST267 donor probes: color/cull integration 4,558 checks/48 matrix frames;
  depth/water 885; culling geometry 300 cases; handoff 23; shadow 213.

The nested Python subprocess runner failed SDK discovery before the mod export.
Direct engine-root PowerShell runs with relative DS_MOD_PATH loaded the mod and
passed twice. Both the failed nested log and direct passing log are retained;
this runner limitation is not counted as a successful nested run.

Evidence: engine workspace tmp/body-ring-release-check-20261025 contains per-test
logs, summary.json and before/after live file inventories. Existing donor probes
adapt only scratch fixtures for composite rendering, as documented previously.
No new native/device render or performance claim; tests use synthetic graphics.
Prior inspected Yellow captures remain under tmp/battleart-streaming.

## Live deployment and release limit

All 12 changed production files match the requested live mod after line-ending
normalization. Eleven were already current; only lib/ChunkMesher.lua needed
copying. The previous file hash matched the October 23 deployment manifest.
Verified backup/deployment manifest: engine workspace tmp/
body-ring-release-check-20261025/live-backup-20261025-223915.
No assets, manifest, player settings, saves or caches were overwritten/deleted.
Restart the game before playtesting. Preserve existing BODY caches; new RING
products still require generation when absent. Passing these tests does not
establish Android/iOS memory pressure, frame pacing or GPU compatibility.
User device playtesting remains the release gate; leave changes uncommitted.
