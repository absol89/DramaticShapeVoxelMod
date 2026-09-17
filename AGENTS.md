# Battle Art: contributor and game-testing guide

## Start here

This is the Battle Art voxel/presentation mod. A visual bug is visually verified
only after inspecting the running game or its rendered screenshots at the
reported location. Passing Lua tests alone is insufficient.

1. Read this file, root `PROJECT_HANDOFF.md`, and relevant `README.md` sections.
   The root handoff is newest first; `docs/PROJECT_HANDOFF.md` contains additional
   history. Distinguish historical reports from current checkout evidence.
2. Inspect the branch, `git status --short`, and actual affected files. Preserve
   user edits. Continue the user's Legendary-Additions work on its existing
   branch unless instructed otherwise; do not switch branches blindly.
3. Record the game, save/fixture, map, cell, facing, camera, options, companions,
   trigger, defect, and expected result. Reproduce before changing code.
4. Make a focused fix, repeat the same scene, and inspect neighboring geometry.
   Keep commands, logs, and before/after images in a dedicated scratch directory.

## Ownership and compatibility

- Battle Art owns scene order, terrain, camera, lighting, depth, battle
  presentation, and its effects. Build on its existing architecture.
- Stadium importers, player/NPC assets, Colosseum UI, and Battle Cinematics remain
  separate companions. Use exported provider APIs. Do not copy private assets
  or runtimes, read private files, inspect debug upvalues, assume shared globals,
  or replace protected engine callbacks to bypass integration problems.
- Preserve engine gameplay, collision, warps, stats, catch odds, inventory, and
  input behavior. Pokemon size and voxel geometry changes are presentation work.
  Test-only driver teleports do not justify changing production gameplay.
- Preserve stock sprites/UI and feature defaults when providers or Legendary
  options are disabled/unavailable. Avoid shader-state leaks between draws.
- Preserve TEST366-style granite pillars, recessed warm side lanterns, charcoal
  trim, non-emissive granite tops, and Separate/Bottom Link/Top Interlock layouts.
  Wall/ledge colors must not recolor pillars. Retain staggered masonry, timber
  bridges/fences, approved trees, landscaping, and smooth sky blending.
- Preserve Legendary Pokeballs, capture effects, 3D smoke, standing selected
  trainer, naming-screen compatibility, and 2D fallback.
- Cave-opening fixes target opening geometry, not global wall height or collision.
  Keep unaffected slopes and walls intact.
- Historical setups include engine 0.2.53 and later reports. Read the actual
  engine version and current manifest rather than pinning a historical version
  as current. Preserve supported fallbacks and test the user's build when present.
- Keep companion patches in their own packages. Record missing source rather
  than substituting an unrelated mod. Do not commit ROMs, imported model packs,
  user artwork, generated caches, or test captures. Preserve asset exclusions,
  manifest identity, and install layout. Do not bump versions or publish casually.

## Paths and preflight

| Path | Role |
| --- | --- |
| `D:\gen1recomp` | Engine source root, including `main.lua`, `conf.lua`, `src`, and `tests/drivers/util.lua`. Run source commands here. |
| `D:\gen1recomp\dev\DramaticShapeVoxelMod` | Authoritative mod checkout, with its own Git repository. |
| `D:\gen1recomp\mods\BATTLE_ART_VOXEL_FORK` | Engine-facing mod folder. On 2026-09-15 this was a junction to the checkout above. Verify each session. |
| `D:\Games\gen1recomp-win64` | Current packaged Windows install. The directory and `gen1recomp.exe` were verified on 2026-09-15. Window inventory also observed running instances from this executable; package contents/capabilities must still be checked separately. |
| `D:\gen1recomp\tmp\battle-art-repro\<case>\<run>` | Suggested scratch directory for drivers, logs, and screenshots. Use a fresh run directory. |

The manifest ID is `BATTLE_ART_VOXEL_FORK`; directory and display names need not
match. Editing `dev` affects a packaged install only if its installed mod points
there or you deliberately deploy the changes. Booting an old copy proves nothing
about a fix.

```powershell
$engineRoot = 'D:\gen1recomp'
$modRoot = Join-Path $engineRoot 'dev\DramaticShapeVoxelMod'
$packageRoot = 'D:\Games\gen1recomp-win64'
git -C $modRoot status --short
git -C $modRoot branch --show-current
Get-Item (Join-Path $engineRoot 'mods\BATTLE_ART_VOXEL_FORK') |
    Select-Object FullName, LinkType, Target
Get-Content (Join-Path $modRoot 'manifest.json')
Get-Command love, lovec, luajit -ErrorAction SilentlyContinue
if (Test-Path -LiteralPath $packageRoot) {
    Get-ChildItem -LiteralPath $packageRoot -Force
}
```

Verify in Mod Manager and loaded-mod diagnostics that this ID is enabled for
Yellow without errors or conflicting voxel mods. If the loaded code differs,
inspect source and save-directory mod copies; see engine
`src/mods/LauncherMods.lua` and shadow-copy regression tests. Never replace an
existing junction or installed package blindly.

For the shared stateful reproduction sequence, see the engine [shared reproduction workflow](../../AGENTS.md#shared-reproduction-workflow). This guide supplies the generation-specific recipe.

## Game selection, saves, and reproducibility

- Yellow must be imported in the selected runtime's data root. If needed, import
  the user's existing ROM through the launcher. Do not download ROMs or assume
  source Red data is Yellow. `src/import/CacheFs.lua` mounts the selected cache.
- `--game=yellow` selects the game and skips the launcher, not the title/Continue
  flow. `--slot=2` selects a slot in the normal launch path. Use equals syntax
  with LÖVE: separated game arguments can be mistaken for the application path.
- The driver branch selects `POKEPORT_VERSION`, then the launch game, then Red.
  Explicitly set Yellow. This branch bypasses normal launch-slot handling;
  driver plus `--slot=2` is not proof that slot 2 was loaded.
- `U.teleport` creates an overworld state over the current in-memory save. At
  initial boot this is a new-game skeleton, not a restored Continue save. This
  is useful for terrain fixtures, not automatically for progression bugs.
- For party, story flags, follower, battle, or progression bugs, use a copied
  known save and normal Continue, or explicitly restore a documented fixture
  through current engine APIs. Record all fixture mutations. Do not blindly
  mash `U.newGame`: title choices depend on whether a save exists.
- Locate persistence first. `portable.txt` selects portable persistence beside
  the game/source; otherwise LÖVE uses its identity directory, normally
  `%APPDATA%\LOVE\pokemon-love2d`. Verify from the developer console using
  `love.filesystem.getSaveDirectory()` and
  `require("src.core.SaveData").portableBaseDir()`.
- `POKEPORT_IDENTITY` changes LÖVE's identity but does not override portable mode.
  A fresh identity may lack ROM caches and mod options. Do not claim isolation
  without verifying actual persistence, cache, and mod paths.
- Back up the selected save/slot and options before stateful reproduction;
  preferably work on a disposable copy. Use `--no-sync` for normal local test
  launches. Never save a teleported test state over player progress. Options
  persist separately from progress. Default Yellow progress is `save_yellow.lua`,
  but slots change paths; consult `SaveData.saveFilename("yellow")`.

## Route A: source engine with automated setup

Use an installed compatible LÖVE runtime with working directory `D:\gen1recomp`.
`lovec.exe` is useful for logs. Pass the engine root, not the mod directory: the
mod is not a standalone game.

`main.lua` reads `POKEPORT_DRIVER` using `loadfile`; the file returns a function
that receives `game` and runs as a frame-stepped coroutine. Returning quits the
game. A driver error logs `driver error:` and exits 1. Keep yielding to leave a
live window for Computer Use.

### Example: reach the Lavender sign-floor issue

Create `repro.lua` in the run directory using the following template. The object
is at `(9,3)`; `(9,5)` is a candidate viewing position, not a verified walkability
fixture. Check the active map and framing and adjust to a valid nearby cell.
Teleport success does not prove a cell is walkable.

```lua
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local P = require("src.render.Pipelines")
  local V = require("src.core.GameVersion")
  assert(V.get() == "yellow", "Expected Yellow")
  assert(game.data.maps.LAVENDER_TOWN, "Missing target map")
  assert(game.mods and game.mods.exports
    and game.mods.exports.BATTLE_ART_VOXEL_FORK, "Battle Art not loaded")
  local dir = assert(os.getenv("SHOT_DIR"), "Set SHOT_DIR")
  local speed = math.max(1, math.floor(tonumber(os.getenv("POKEPORT_SPEED")) or 1))
  local function settle() U.wait(90 * speed) end
  local function shot(name)
    assert(U.shot(game, dir .. "/" .. name .. ".png"), "Capture missing")
  end

  U.teleport(game, "LAVENDER_TOWN", 9, 5, "up")
  P.setLevel("tiltshift", 0)
  P.setLevel("voxel", 0)
  settle()
  local ow = game.stack:top()
  assert(ow.map and ow.map.id == "LAVENDER_TOWN", "Wrong live map")
  U.log("version", V.get(), "player", ow.map.id,
    ow.player.cellX, ow.player.cellY, ow.player.facing)
  shot("lavender_flat")

  -- Resolve the label: numeric camera levels changed over the mod's history.
  local target
  for level = 0, P.maxLevel("voxel") do
    if P.levelLabel("voxel", level) == "35" then target = level end
  end
  assert(target, "35-degree camera unavailable; inspect pipeline labels")
  P.setLevel("voxel", target)
  settle()
  shot("lavender_v35")
  U.log("READY_FOR_INSPECTION", P.levelLabel("voxel", P.level("voxel")))
  while true do U.wait(60) end -- keep live for Computer Use; close after inspection
end
```

Launch from a dedicated PowerShell session. Set `$loveExe` to a discovered
runtime. The placeholder is not an assumed installed path. Create SHOT_DIR
first: `U.shot` has a Unix-style mkdir fallback unsuitable as a Windows setup
step. The wait is a starting point; inspect the loading veil and allow more
frames if geometry is still building.

```powershell
$engineRoot = 'D:\gen1recomp'
$runDir = Join-Path $engineRoot 'tmp\battle-art-repro\lavender\before-01'
$loveExe = 'C:\REPLACE_WITH_DISCOVERED_LOVE_DIRECTORY\lovec.exe'
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
# Save the Lua template as $runDir\repro.lua first.
if (-not (Test-Path -LiteralPath $loveExe)) { throw 'Locate LÖVE first' }
$env:POKEPORT_VERSION = 'yellow'
$env:POKEPORT_DEV = '1'
$env:POKEPORT_SPEED = '1'
$env:POKEPORT_DRIVER = Join-Path $runDir 'repro.lua'
$env:SHOT_DIR = $runDir.Replace('\', '/')
$gameProcess = Start-Process -FilePath $loveExe -WorkingDirectory $engineRoot `
    -ArgumentList @($engineRoot, '--game=yellow', '--developer', '--no-sync') `
    -RedirectStandardOutput (Join-Path $runDir 'stdout.log') `
    -RedirectStandardError (Join-Path $runDir 'stderr.log') -PassThru
$gameProcess.Id
```

The game window is intentionally visible. Inspect logs/window state instead of
launching duplicate instances during slow cache generation. Close only the test
instance after inspection. Restore previous environment values afterward, or
close the dedicated shell. Inspect and clear inherited autopilot, import, arena,
or launch variables from unrelated experiments before starting; otherwise a
normal launch can silently inherit a driver or the wrong state.

### Batch alternative: existing voxel survey

Using the same source launch setup, replace the driver and set:

```powershell
$env:POKEPORT_DRIVER = 'dev/DramaticShapeVoxelMod/tests/voxel_survey.lua'
$env:SURVEY_MAP = 'LAVENDER_TOWN'
$env:SURVEY_SPOTS = '9,5,up@sign-front; 7,5,right@sign-side'
$env:SURVEY_LEVELS = '2,3,4'
```

Check these candidate viewpoints against the active map. The survey returns
and auto-quits. Inspect its images with an image-viewing tool; filenames and
successful exit are not visual evidence.

Read the actual driver before trusting `tools/voxel-survey.md`. The old guide
assumes levels 1/2/3 are 15/35/50 degrees. The audited `lib/VoxelState.lua` has
FULL before those, making them 2/3/4. Runtime `Pipelines.levelLabel` is the
reference. The driver captures a flat reference only for the FIRST spot,
despite broader wording in the old guide. Run one spot at a time or adapt a
scratch driver if every viewpoint needs a flat reference. It disables tilt-shift
and changes pipelines without the options hotkey. Verify current nonempty image
files: this survey logs capture requests without verifying disk writes.

## Route B: packaged game and developer console

1. Verify `D:\Games\gen1recomp-win64` exists and list executables and archives.
   Determine whether it has a fused game executable or a standalone LÖVE runtime
   plus `.love` archive. Do not guess an executable name or assume an older
   package includes source driver helpers or current flags.
2. Verify the installed mod/version, companions, Yellow import, and persistence
   root. For changed code, use an authorized test copy, verified checkout link,
   or deliberate deployment with this repository's packaging tools. Avoid
   incidentally overwriting the player's install.
3. Launch the discovered fused executable with `--game=yellow --developer
   --no-sync` and the intended `--slot=N`, using the package working directory.
   For standalone LÖVE, pass the actual game directory/archive first. Unsupported
   flags require the package's supported launcher/developer workflow; record
   the limitation rather than claiming source behavior was tested.
4. Through Computer Use, select Continue for the copied known save. Wait for
   the overworld and record party/story prerequisites.
5. Open the Gen 1 console with backtick. Execute commands individually:

   ```text
   mods
   warp LAVENDER_TOWN 9 5
   ```

   Syntax is `warp MAP [x y]`, in cells, defaulting to 5,5. Close the console
   with backtick: it pauses world updates. Verify the resulting map and view.
   Set facing through observed movement or a fixture with explicit facing.
6. Perform the original trigger normally. Teleport nearby on the approach map
   and walk across the real door/route boundary for transition bugs; teleporting
   directly to the destination bypasses what needs testing.

The console builds text from keypresses in `src/dev/Console.lua`, not normal
`love.textinput`. Paste/Unicode text injection may fail. Inspect the input buffer
and use supported individual key events when necessary, or a source driver for
long commands. Verify backtick and underscore on the current keyboard layout;
never repeatedly submit an unseen command.

## Computer Use: inspect the actual game window

Read the available Windows Computer Use skill's current `SKILL.md`, guidance,
API, and confirmation instructions. In environments exposing `node_repl` and
`@oai/sky`, initialize in that JavaScript session:

```javascript
if (!globalThis.sky) {
  const { sky } = await import("@oai/sky");
  globalThis.sky = sky;
}
```

Discover windows in the next call:

```javascript
globalThis.windows = await sky.list_windows();
nodeRepl.write(JSON.stringify(windows, null, 2));
```

Select exactly one returned game window by its observed app/executable and
title. Store that returned object as `globalThis.gameWindow`; never guess
handles or choose the first vague match. Capture and inspect:

```javascript
globalThis.state = await sky.get_window_state({ window: gameWindow });
globalThis.gameWindow = state.window;
```

Screenshots display automatically. After inspecting the observation, perform
one action, then immediately refresh. For example, a verified movement key:

```javascript
await sky.press_key({ window: gameWindow, key: "Left" });
globalThis.state = await sky.get_window_state({ window: gameWindow });
globalThis.gameWindow = state.window;
```

Follow this observe/action loop for each UI step. Reobserve after failed input,
state changes, or focus changes; do not reuse stale coordinates, indexes, or
screenshot IDs. LÖVE often has little accessibility text, so inspect images.

Current defaults: arrows/WASD move; Z/Return/Space is Game Boy A; X/Backspace is
B; Escape/keypad Enter is Start; Tab is Select. Physical A means left, not the
Game Boy A button. Bindings can differ: inspect Controls or `src/core/Input.lua`.
Voxel hotkey 3 may persist options; record and restore settings. F5 reloads mods
in developer mode, but restart for final comparisons after cache-sensitive edits.

A browser-only CUA session cannot be assumed to control this native game.
Discover the Windows runtime/tools before declaring Computer Use unavailable.
If Windows interaction or LÖVE is unavailable, still prepare the fixture and
run available checks, then report the exact blocker. Inspected driver captures
can verify appearance; they do not prove keyboard, focus, or movement behavior.
Never fabricate a visual pass.

## Coordinates and the worked acceptance case

Engine cells are zero-based 16x16 pixels. Source tiles are 8x8 pixels. Map blocks
contain 4x4 tiles / 2x2 cells. A map's width/height in blocks gives cell bounds
`0..width*2-1` and `0..height*2-1`. Inspect `game.data.maps[mapId]`, active generated
map data, and flat references. Tilted screen pixels are not world coordinates.

The root handoff documents:

- Map `LAVENDER_TOWN`, defective sign floor at cell `(9,3)`, source tiles
  x18..19/y6..7.
- Expected plain, non-checkered grass beneath the Silph Scope sign in both
  Battle Art and Legendary city-ground modes.
- Preserve the sign billboard and nearby lavender-grey path/checker network.
- Preserve the approved 12x12 `pokemon_tower_top` flower region on `ROUTE_10`.
  It is a separate feature on a different map, not the defective square.

Set and record CITY GROUND through the actual options UI or a verified current
option API: the generic driver does not select it. Capture both modes, OFF/flat,
relevant camera angles, and multiple nearby views. Inspect the Route 10 approach
and seam for collateral changes. This is a documented historical reproduction
target, not proof the current build still has the bug or that these candidate
viewpoints have been live-tested.

## Tests, troubleshooting, and completion

Run relevant existing tests from the engine root. Select the mod path explicitly:

```powershell
Set-Location 'D:\gen1recomp'
$env:DS_MOD_PATH = 'dev/DramaticShapeVoxelMod'
luajit dev/DramaticShapeVoxelMod/tests/battle_art_voxel_fork_test.lua
python dev/DramaticShapeVoxelMod/tools/check_luajit_compile.py
git -C dev/DramaticShapeVoxelMod diff --check
```

Use discovered runtimes. The compile helper requires Lupa's `luajit21` backend;
another Lua version does not prove LuaJIT compatibility. Targeted tests may have
additional data/path requirements. Mocked SDK tests do not exercise the real GPU.
Shared terrain changes require another map using the tileset and an unrelated
busy interior such as `OAKS_LAB`. Battle changes require relevant battle/capture,
return-to-world, naming, companion-on/off, and 2D-fallback checks.

| Symptom | Next check |
| --- | --- |
| Red boots | Inherited POKEPORT_VERSION, launch arguments, and active GameVersion.get(). |
| Importer stays open | Yellow readiness in the selected cache/persistence root. |
| Stock/old world | Enabled mod ID, loader errors, resolved junction, duplicate/shadow copy, actual runtime. |
| Wrong map/position | Active version, map ID, bounds, cells versus tiles, player state. |
| Immediate exit | stdout/stderr: driver returned or failed before its inspection loop. |
| Missing images | Existing writable SHOT_DIR, actual draw frames, file timestamps and image contents. |
| Wrong camera | Runtime labels; old survey numeric levels are stale. |
| No movement | Console/menu, focus, loading veil, bindings, held buttons; driver helpers must release input. |
| Reload differs from restart | Cache identity/invalidation; do not indiscriminately delete player caches. |
| Native control fails | Windows tool availability and target selection; report exact failure and alternative checks. |

Finish with this evidence record:

```text
Case / expected result:
Engine executable or source revision / mod revision and uncommitted edits:
Game / imported data / copied save or fresh fixture / slot:
Loaded mod ID and resolved path / companions / relevant options:
Map / object cell / viewing cells / facing / camera labels:
Exact driver and launch command / actions after teleport:
Before/after image paths / inspected visual findings:
Tests and results / neighboring geometry and fallback checks:
Not verified / blockers / remaining risk:
Cleanup: test process closed, environment/options restored, player save untouched:
```

After implementation, update root `PROJECT_HANDOFF.md` with evidence and remaining
work. Label checks accurately: static inspection, LuaJIT compile, mocked test,
rendered capture inspected, or live Computer Use gameplay. Windows evidence is
not Android evidence. This guide was checked against source on 2026-09-15; no
live game run was performed during that documentation audit.
