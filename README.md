# Battle Art Voxel Fork

Battle Art Voxel Fork turns the overworld of the [Pokémon Gen 1 Recompilation Project](https://github.com/bryanthaboi/pokemon-gen1-recomp-project) into a 3D voxel diorama and stages battles inside that world. It also provides configurable static and animated battle sprites, arena backdrops, trainer art, first-person exploration, water reflections, lighting, and compatibility hooks for other presentation mods.

Version 1.9.0 supports Pokémon Red, Blue, and Yellow on Gen1Recomp `0.1.69` through current pre-2.0 releases. It is intentionally declared as a Gen 1 mod; Pokémon Gold uses different engine modules and needs a real port rather than a manifest change. See the [Gen 1 and Gen 2 differences and porting guide](docs/GEN1_GEN2_DIFFERENCES.md).

## Highlights

- Extruded terrain, buildings, foliage, figures, depth-buffered occlusion, cast shadows, and optional tilt-shift and world curvature.
- Voxel water with waves and sky reflections; FULL reflections also include visible shoreline, trees, buildings, and characters.
- First-person free look and analog movement while retaining the engine's collision, encounter, warp, ledge, and script behavior.
- Battles staged over the current map with an over-the-shoulder camera, parallax, depth of field, configurable HUDs, and optional Gen 6-style backdrops.
- Static or animated Pokémon art from Gen 1 through Gen 5 collections, trainer portraits, player intro art, native shiny detection, and safe ROM fallback.
- Compatibility with [Stadium Battle FX](https://github.com/anxiousintrovert/StadiumBattleFX) attack effects, Gen 3 Battle UI, the [Stadium 2 Importer](https://github.com/Deftones565/gen1recomp-mod-stadium2-importer), and Kanto First Person.
- Two performance paths: persistent disk precaching on legacy engines and sandbox-safe bounded mesh streaming on current engines.

## Engine compatibility

| Gen1Recomp version | Support | Mesh behavior | Persistent precache |
| --- | --- | --- | --- |
| `0.1.69–0.1.83` | Supported | Legacy filesystem/FFI mesh path | Available from the title and pause menus |
| `0.1.84+` | Supported | Packed `ByteData` meshes held in session memory | Unavailable; the sandbox blocks the required raw filesystem and FFI access |
| Earlier than `0.1.69` | Unsupported | Missing APIs used by Battle Art 1.9.0 | Not a supported configuration |

The `0.1.83` boundary is inclusive: persistent BAVC precaching works through `0.1.83`. Starting with `0.1.84`, the mod hides the `PRECACHE` and `CACHE` actions and uses the newer sandbox-compatible path automatically. This is expected behavior, not an incomplete installation.

Some older engine builds exposed enough filesystem functionality for the cache backend itself, but Battle Art 1.9.0 as a whole requires APIs introduced in `0.1.69`. Those older builds are therefore not advertised as supported merely because they can write a cache file.

On recent engines, `R.DIST: MEDIUM` is the default. It bounds connected-map work to 32 Gen 1 cells (512 world pixels) while the current map remains complete. `SHORT`, `FAR`, and `FULL` are available for lower-end hardware, wider views, or comparison.

The manifest accepts the development build identifier and stable versions in the range `>=0.1.69 <2.0.0`.

## Installation

1. Install a supported Gen1Recomp build and import Pokémon Red, Blue, or Yellow.
2. Download a package from [Releases](https://github.com/absol89/DramaticShapeVoxelMod/releases), or clone this repository.
3. Put the mod folder in the game's `mods` directory. A normal Windows installation uses `%APPDATA%\pokemon-love2d\mods\BATTLE_ART_VOXEL_FORK`.
4. Enable **BATTLE ART VOXEL FORK** in the Mod Manager or in a profile.
5. Optionally import or add battle-art PNGs as described below. Missing art always falls back to the ROM.

The mod conflicts with the original Dramatic Shape, Dramaless Shape, and Potato Voxel renderers because they compete for the same world presentation.

## Feature sets

### Voxel overworld

The renderer turns map blocks into a perspective diorama instead of flattening them into a single plane. Terrain, water, structures, grass, flowers, authored figures, NPCs, and overworld Pokémon retain their normal game state while the mod changes how they are presented.

Key visual controls include:

| Option | Choices | Purpose |
| --- | --- | --- |
| `VOXEL` | `OFF`, `FULL`, `15`, `35`, `50`, `75`, `1ST`, `3RD (EXPERIMENTAL)` | Flat view, complete diorama preset, pitched orbit cameras, first person, or experimental third person |
| `V-GRID` | `OFF`, `ON` | One-pixel voxel wireframe |
| `T-SHIFT` | `OFF`, `1`, `2`, `3` | Miniature depth blur |
| `V-CURVE` | `OFF`, `1`, `2`, `3` | Curves the distant world toward the horizon |
| `SHADOWS` | `ON`, `OFF` | Cast or fallback sprite shadows |
| `AA` | `OFF`, `2X`, `4X` | Supersampled edge smoothing; the most expensive visual option |
| `R.DIST` | `SHORT`, `MEDIUM`, `FAR`, `FULL` | Limits adjacent-map rendering work |
| `DAYTIME` | `SYNC`, `DAY`, `NIGHT`, `DUSK`, `DAWN`, `CYCLE` | Controls outdoor lighting and sky time |
| `LEGENDARY PILLARS` | `BATTLE ART`, `SEPARATE`, `BOTTOM LINK`, `TOP INTERLOCK` | Selects the original or community granite pillar layout |
| `WALL & LEDGE COLOR` | `GRANITE`, `RED BRICK`, `SANDSTONE`, `SLATE` | Selects Legendary masonry material |
| `TREES` | `BATTLE ART`, `LEGENDARY VISUALS` | Selects the original or community S/M/L/XL tree family |

`WORLD FILL` controls empty space below and outside the world:

- `CYAN` is the default classic underlay.
- `BLACK` uses the dark `#181818` underlay.
- `OFF/KFP` draws no underlay, allowing Kanto First Person to own that space.
- `NATURE` uses the cyan underlay and adds biome-aware trees or rocks; selected
  forest, Safari-house and Seafoam void maps use black and stay clear.

With `NATURE`, transparent nature billboards populate 16×16 world cells beyond
the loaded map and its connected neighbors where the map's fill profile allows
them. Towns, forests,
and leafy routes continue with trees; Safari/open-field routes use broadleaf
trees; rocky routes (including Route 23) and cavern maps use rock pillars.
Their variant and 100%/150%/200% size are randomized deterministically, so they do not
flicker when the camera moves. Authored ROM cells always remain unobstructed.

### Water and sky

The sky keeps the active `DAYTIME` palette but blends its colors continuously
from zenith to horizon, including twilight glow and the shader fallback.

`WATER` has three levels:

- `OFF` disables the voxel water pass.
- `SKY` draws pixel-height waves reflecting the current sky, sun or moon, and staged battlers.
- `FULL` adds screen-space reflections of visible shoreline, trees, and buildings.

The outdoor sky, shadows, flat-world tint, and water share the same clock. Gen 6 battle backdrops snapshot the current dawn/day/dusk/night period when a battle starts, so a time change cannot abruptly replace the backdrop during that battle.

### First- and third-person modes

Choose `VOXEL: 1ST` to enter the player's viewpoint. Look with the mouse, right stick, or a touch drag; move with WASD, the left stick, or the touch D-pad. Mouse left click acts as A and right click as B while pointer capture is active.

`VOXEL: 3RD (EXPERIMENTAL)` uses the same free-look and free-movement rig with the camera pulled back behind the player. Moving between `1ST` and `3RD` slides the eye along that camera boom instead of cutting between unrelated views.

Both free-camera modes still ask the Gen 1 engine about collision and run its landing pipeline for every crossed cell. Warps, encounters, ledges, gates, and scripts therefore remain engine-owned. Selecting an orbit or flat `VOXEL` mode restores ordinary grid movement.

### Staged battles and arenas

`3D-BTL` stages battles on nearby clear ground in the current map. It is enabled by default and does not require the free-roam `VOXEL` camera to be pitched.

Presentation controls include:

| Option | Choices | Purpose |
| --- | --- | --- |
| `STANDING TRAINER` | `STOCK`, `LEGENDARY` | Lets a compatible 3D-player provider keep the trainer in the staged arena |
| `ARENA FILL` | `OFF`, `WHITE`, `GEN6`, `PNG`, `BLUE` | Voxel level, flat Battle Art arena, or Stadium's blue arena |
| `STADIUM CIRCLE` | `ON`, `OFF`, `HALF` | Independently selects full, hidden, or two-thirds-radius Stadium ground circles when supported |
| `BG Y-OFFSET` | `0` to `400` (default `100`) | Vertically crops a selected backdrop |
| `BOSS BG` | `ON`, `OFF` | Allows special boss backdrops |
| `SPRITE LIGHT` | `SHADED`, `UNLIT` | Lets battle cards receive world lighting or preserve source colors |
| `HUD COLOR` | `COLOR`, `INVERTED` | Dark or light HUD glyph treatment while retaining HP colors |
| `TEXTBOX FILL` | `WHITE`, `HALF`, `BLACK`, `OFF` | Controls the native text and menu paper independently of the arena |

`ARENA FILL: GEN6` selects backgrounds using map location, encounter type, surfing/fishing state, boss state, and the time captured at battle entry.

### Battle art

`BATTLE ART` controls Pokémon sprite ownership:

- `STATIC` reads ordinary species PNGs.
- `ANIMATED` reads the selected animated front set and compatible animated/static back set.
- `ROM` bypasses imported Pokémon art.

Front collections can be selected from Gen 1 through Gen 5. Gen 1 animated-mode fronts are single-frame compatibility PNGs; Gen 2–5 fronts are atlases. Back collections also expose Gen 1 through Gen 5: Gen 3 and Gen 5 can animate, while Gen 1, Gen 2, and Gen 4 use static PNGs.

Additional controls choose player front/back presentation, player-card mirroring, automatic/world/original-UI back placement, opponent trainer generations, and static or five-pose player trainer introductions.

`DUPLICATE FIX` separates sprite ownership from other mods:

- `BATTLE ART` makes this mod own normal and shiny battle sprites. It evaluates the Gen 2 DV shiny formula itself and routes qualifying Pokémon to matching shiny assets without relying on Crystal or another shiny mod's API.
- `MODDED` yields Pokémon battler-picture ownership to another Pokémon sprite provider or the ROM while retaining Battle Art's arena and camera features. It does not control move or attack-effect sprites.

Ditto Transform is tracked independently, so transformed art follows the species currently being presented. Missing, malformed, or unreadable assets fail open to the original ROM sprite instead of aborting the battle.

### UI and mod compatibility

- Gen 3 Battle UI automatically receives the HUD, text/menu, and panel surfaces when its revamped battle UI option is enabled. Unsupported scripted phases retain the native presentation.
- The older Gen 1 Modern UI adapter is recognized when its experimental battle UI option is enabled.
- [Stadium Battle FX](https://github.com/anxiousintrovert/StadiumBattleFX) can retain its Stadium move effects and announcer while Battle Art owns the staged arena, cards, and camera. Keep `3D-BTL: ON`; no `DUPLICATE FIX` setting is required because its attack-effect sprites are not Pokémon battler pictures.
- The [Stadium 2 Importer](https://github.com/Deftones565/gen1recomp-mod-stadium2-importer) can provide Stadium 3D models through the staged-battle compatibility interface. This is the supported Stadium model path; it is separate from [Stadium Battle FX](https://github.com/anxiousintrovert/StadiumBattleFX), which supplies attack-effect sprites.
- Effects mods can inspect the same read-only staged-battle descriptor rather than importing Battle Art internals.
- `OFF/KFP` leaves the world underlay to Kanto First Person.
- `MODDED` leaves Pokémon battler-picture drawing to another Pokémon sprite provider or the ROM.

## Persistent precache on `0.1.69–0.1.83`

On legacy engines, the title menu's `PRECACHE` action opens a cancellable **GENERATE PRECACHE** task. It creates reusable terrain, water, connected-map body, and auxiliary geometry after content mods have patched maps and tilesets. Running it again resumes from valid records instead of rebuilding them.

The files are written only below:

```text
mod-derived/BATTLE_ART_VOXEL_FORK/static-mesh-cache-v2
```

The cache does not store runtime NPCs, spawned overworld Pokémon, or temporary script changes. Live map changes are meshed in RAM; returning to the canonical layout reuses the disk record. A human-readable `static-cache-exclusions.tsv` records intentionally excluded runtime objects and noncanonical geometry.

If generation ends as `INCOMPLETE`, inspect
`mod-derived/BATTLE_ART_VOXEL_FORK/precache-failures.tsv`. It is regenerated
for each run and lists the failing map and slot, the logical cache key, the
actual legacy `.bavc` path, the failure stage, and the storage/encoder error.

BAVC is a versioned, fingerprinted, LZ4-compressed geometry container. Corrupt or truncated records safely fall back to cooperative mesh generation. Cache size depends on the imported ROM and installed content and can reach hundreds of MiB. The directory is disposable: deleting it only makes the mod regenerate those meshes. The pause-menu `CACHE` action can save or drop accumulated legacy-engine RAM cache work.

## Sandboxed mesh streaming on `0.1.84+`

Current engines do not grant content mods the raw filesystem and FFI access used by the persistent cache. Battle Art instead packs mesh vertices into bounded `ByteData` buffers, uploads them through the supported API, keeps only the current session's useful meshes in memory, and releases map meshes as they become unnecessary.

There is no precache button in this mode. Use `R.DIST` to trade connected-world breadth for loading time and memory use; `MEDIUM` is the recommended default. All supported voxel, camera, battle, battle-art, backdrop, and compatibility features remain available.

## Controls

The hotkeys work in free roam and mirror rows in the Options menu:

| Key | Option |
| --- | --- |
| `3` | Cycle `OFF`, `15`, `35`, `50`, `75`, `1ST`, and experimental `3RD` (`FULL` remains an Options-menu preset) |
| `5` | Toggle `V-GRID` |
| `6` | Cycle `T-SHIFT` |
| `7` | Cycle `V-CURVE` |
| `8` | Toggle `3D-BTL` |
| `9` | Cycle `WATER` |

The `Y-CONTROL INVERT` option reverses vertical look input in 1ST/3RD only;
it is OFF by default and does not affect overhead camera controls.

Battle Art suppresses the engine's flat `TILT` and full-screen `GBC FX` while installed because those passes conflict with the 3D renderer. Uninstalling the mod restores their normal rows and saved values.

## Bring your own battle art

Local battle PNGs are ignored by Git. The repository supplies folder contracts and importer tools, while a missing file always falls back to ROM art.

| Purpose | Folder |
| --- | --- |
| Static species fronts | `assets/battle/front-static/` |
| Gen 1 single-frame and Gen 2–5 animated fronts | `assets/battle/front-animated/gen1/` through `gen5/` |
| Static species backs | `assets/battle/back-static/gen1/` through `gen5/` |
| Animated Emerald and Black/White backs | `assets/battle/back-animated/gen3/` and `gen5/` |

Use lowercase species filenames such as `pikachu.png`, `caterpie.png`, `farfetchd.png`, and `mr-mime.png`. The Nidoran files are `nidoran-f.png` and `nidoran-m.png`. Place shiny variants in the corresponding documented `shiny` folder. Each battle-art directory contains a README describing its exact file and atlas contract.

Static PNGs are used at native resolution. Existing alpha is preserved. For an opaque source image, the border-connected corner color is keyed transparent while enclosed matching pixels remain intact. Enemy fronts face left; player fronts can be mirrored by the mod; authored back art should face right.

The `tools` directory includes importers for Crystal, Emerald, Platinum, Black/White, extended Gen 2–5 species sets, shiny collections, static illustrations, and animated atlases. These scripts prepare local art without committing it.

- `tools/package_mod.ps1` creates a local test package including your ignored battle PNGs.
- `tools/package_clean_mod.ps1` creates a shareable package that preserves the folder contracts and tools but excludes local battle PNGs.

## Integration API for mod authors

Replacement UIs can wrap `battle.presentation.suppress_native.v1`. A consumer receives the API version, source ID, requested `hud`, `text`, or `panels` surface, and the current battle when available. Return exactly `true` only when the consumer draws the complete requested surface; absent, failing, or false consumers leave Battle Art's native surface enabled.

The exported descriptor is available at:

```lua
mod.find("BATTLE_ART_VOXEL_FORK").exports.battlePresentation
```

Effects and presentation mods can inspect staged battle placement through:

```lua
local stage = mod.find("BATTLE_ART_VOXEL_FORK").exports.battleStage
local state = stage and stage.state(battle)
```

API version 1 is observational and read-only. A staged session reports `staged = true`; `ready` becomes true when the first projected shot exists. Ready state includes copied player/enemy anchors, sprite placement, animation scale, layer transform, and ownership declarations for the arena, battlers, trainers, camera, HUD, transitions, and animation projection. Consumers can align effects or yield competing presentation without retaining live internal tables.

### Optional Stadium 2 models

When `STADIUM2_IMPORTER` exposes its scene-neutral model API v2, its two
provider toggles select the Pokemon art automatically. With both `STADIUM 2
MODELS` and `STADIUM 2 BATTLE` on, Battle Art replaces Pokemon cards in the
staged voxel arena with independently owned model instances. Turning either
importer option off releases those instances and restores Battle Art sprites.
Battle Art reads these options but does not rewrite them.

Models use Battle Art's camera, depth target, placement, day tint, timing and
shadow map. Battle Art continues to own terrain, trainers, HUD, menus, attack
overlays and battle logic. Trainer portraits always remain cards. If the
provider is absent or disabled, a model cannot load, or a side fails to update,
draw or cast a shadow, that side retains its Battle Art card fallback.

When the importer owns its complete Stadium battle scene, Battle Art registers
`exports.scene` environment and background providers. `ARENA FILL: OFF` uses
the captured voxel battle level through Stadium's live camera, so zoom, orbit,
models and attack anchors remain one composition. `WHITE`, `GEN6`, and `PNG`
replace the arena, while `BLUE` selects the importer's native blue background.
`STADIUM CIRCLE` independently draws the imported ground platform at full or
two-thirds radius, or hides it. The row is absent and inert without a compatible
Stadium scene. Stadium models cast into the voxel terrain shadow map whether
or not the circle is visible. With a flat WHITE, GEN6, PNG, or BLUE plate and
the circle hidden or reduced, an invisible ground plane receives only the
model-shadow pixels beyond the visible platform so the models remain planted
without a clipped shadow or an additional platform. Missing
optional artwork safely falls through to Stadium.

`INTERFACE SPRITES: BATTLE ART` uses the selected regular-form front outside
battles independently of `DUPLICATE FIX`. The title and Gen 1 summary screen
play supported animated generations with their authored frame timing and
true-color palette, including compatible atlases returned by another sprite
provider in clean builds. The summary's HP gauge remains the engine's native
shaped, palette-aware tile bar. Interfaces that accept only a static path retain
ROM art for atlas-based generations rather than drawing an undecoded sheet.

For Stadium 3D models, use the [Stadium 2 Importer](https://github.com/Deftones565/gen1recomp-mod-stadium2-importer), which integrates through this staged-battle interface. [Stadium Battle FX](https://github.com/anxiousintrovert/StadiumBattleFX) replaces attack effects instead of Pokémon battler pictures, so it does not require `DUPLICATE FIX: MODDED`.

## Gen 2 status

Battle Art 1.9.0 is Gen 1 only. The renderer, shaders, asset resolvers, shiny predicate, battle-art formats, and presentation API are reusable, but the current boot sequence directly wraps Gen 1 world, map, battle, UI, script, and input modules. Gold exposes separate stacks that must be mapped and tested deliberately.

The [Gen 1 and Gen 2 differences and porting guide](docs/GEN1_GEN2_DIFFERENCES.md) lists the confirmed blockers, reusable portions, and a staged porting plan for anyone working on Gen 2 support.
