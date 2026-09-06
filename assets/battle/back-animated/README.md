# Back animated battle art

Optional animated player-back battle atlases are grouped here by generation.
Local PNG files are ignored by Git. Authored back art faces right and is never
mirrored. GEN 3 and GEN 5 use animated back atlases here. `BACK ART SET`
choices GEN 1, GEN 2 and GEN 4 instead read single-frame PNGs from their
sibling `../back-static` generation folders, with no atlas processing.
Missing selected art retains the ROM back sprite in its original UI layer.
These atlas folders are read only in ANIMATED mode; STATIC uses the selected
generation under `../back-static` instead.

`BACK PLACEMENT` offers AUTO, WORLD, and OG UI. AUTO keeps a valid Gen 5 atlas
in the world and leaves a missing atlas's ROM fallback on OG UI. Forcing OG UI
is supported for comparison, but large atlas frames may crop there.

`PLAYER ANIM` also controls the player-trainer introduction in ANIMATED mode.
PNG reads the ordinary static `../back-static/player.png`; the named choices
below read five-pose strips from this folder:

| Option | Filename |
| --- | --- |
| PNG | `../back-static/player.png` (single static image) |
| GEN 1 | `gen1player.png` |
| GEN 2 | `gen2player.png` |
| GEN 3 | `gen3player.png` |
| GEN 4 | `gen4player.png` |
| GEN 5 | `gen5player.png` |
| ASH | `ashplayer.png` |
| GARY | `garyplayer.png` |
| RED | `redplayer.png` |
| GREEN | `greenplayer.png` |
| ASH FRONT | `ashfrontplayer.png` |
| MISTY FRONT | `mistyfrontplayer.png` |
| BROCK FRONT | `brockfrontplayer.png` |
| BULMA FRONT | `bulmafrontplayer.png` |
| GARY FRONT | `garyfrontplayer.png` |
| ROM | no file; use the engine portrait |

Each named strip is one horizontal row of exactly five equal-width frames.
The recommended 400x80 format is five 80x80 cells. Copy poses into
`tools/player-animation-template-400x80.png`, but remove the coloured guide
dividers in the finished PNG. The first frame holds while the portrait is
stationary; frames two through five play once as the trainer slides left and
then stop. The animation never loops and is never resampled. A missing static
PNG or malformed selected strip falls back to the ROM portrait. Under `BACK PLACEMENT:
AUTO`, player-trainer animation uses OG UI; WORLD and OG UI can override it.
Custom player frames remain 1x on OG UI, while its ROM fallback retains the
engine's intended 2x scale.

GIF decoding is authoring-only. The game reads PNG atlases, extracts every
cell at its native logical resolution, and uses nearest-neighbour filtering.
The importer creates both the atlases and the selected set's shared metadata;
users do not write one Lua file per Pokemon. Run
`python tools/import_animated_sprites.py --set gen5` from the repository root
to generate both Gen 5 fronts and backs.

For Emerald, run `python tools/import_emerald_back_sprites.py --root .`. It
converts all 151 `Spr b 3e` APNGs into `gen3` atlases, generates their shared
Lua metadata, and also copies the corresponding `Spr b 3r` single-frame PNGs
unchanged into `../back-static/gen3`.

## Gen 1 filename exceptions

Most species use their ordinary lowercase name (`pikachu.png`). These four
engine names need the following exact filenames:

| Species | Expected filename | Do not use |
| --- | --- | --- |
| Mr. Mime | `mr-mime.png` | `mrmime.png`, `mr.mime.png` |
| Farfetch’d | `farfetchd.png` | `farfetched.png`, `farfetch-d.png` |
| Nidoran♀ | `nidoran-f.png` | `nidoran.png`, `nidoran-female.png` |
| Nidoran♂ | `nidoran-m.png` | `nidoran.png`, `nidoran-male.png` |

Filenames are lowercase. The same names apply in every battle-art folder.

Opponent trainer pictures, Professor Oak, and Old Man are never animated.
Put `oak.png` and `old-man.png` in `../back-static/`; `player.png` is the
generic fallback used by STATIC-mode `PLAYER ART`.
