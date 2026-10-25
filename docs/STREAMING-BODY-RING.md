# Shared BODY and border RING � 2026-10-23

Travel profiling found expensive cache-hit decoding/uploads as well as genuine
missing variants. A cache hit avoids generation, but does not avoid decompressing
vertices and allocating/uploading a GPU mesh after neighborhood eviction.

PotatoVoxel's disjoint BODY/RING and crossing priorities fit Battle Art's existing
terrain format. Architecture reference: Nexhas28/potato_voxel main a4675f9017c78a3a00bbefe389f1bc33ec4c1394
and release v1.9.6. This adapts ownership/scheduling; no upstream assets or renderer
were imported. Worker decoding is not part of this change.

## Implementation

- A map's BODY is shared between neighbor and current-map rendering. The former
  FULL slot now owns only RING geometry. MeshParts provides a stable, non-owning
  view for terrain, water and suppressible visual streams. Actual draw paths
  expand the view; only mesher slots release GPU objects.
- Geometry partitioning preserves old FULL as the union of BODY and RING,
  including masks, owned props, boundary faces and expanded tree crowns.
- Current BODY and directly connected neighbor BODY precede current RING and
  distant scenery. Existing bounded neighborhood eviction remains.
- Physical ring-terrain records use distinct keys. Existing BODY records remain
  usable; old FULL files remain on disk for rollback but are not preloaded into
  compressed RAM. Completeness requires BODY + RING + auxiliary products.
- Victory Road 1F's complete cave exit shell moves 12 pixels south, into the
  decorative border, to clear the visible Strength approach. Its original shape,
  source warp cells and gameplay collision remain intact. Only this map's terrain
  fingerprint gains a new revision marker.

## Evidence and limits

Read-only Route 2 cache headers showed BODY and FULL each held 6,839,040 terrain
vertices (164,136,960 decoded bytes each). Two vertex streams therefore cost
roughly 313 MiB before water, textures or driver overhead. Sharing removes the
BODY duplication; this is a header calculation, not an Android memory benchmark.
Large Battle Art meshes still require main-thread GPU work and finite retention
can still cause uploads after revisiting a distant map.

Validation: LuaJIT compiles all 346 production files. Mesh partition regression
569 checks; cache-format 47; storage 7; Legendary OFF 30; optional item balls and
transition gate pass. Real Yellow map cave regression passes 13,271 checks covering all eight mouths,
finite geometry, UVs, warp/collision preservation and the whole-model offset.
Donor synthetic culling/depth/shadow integration probes also pass; their timings
are not device performance measurements.

Scratch evidence is under the engine workspace tmp/battleart-streaming: cache
headers, test runners, donor-validation.log, isolated Yellow render driver,
matched viewpoint metadata and before/after PNGs. Images are intentionally not
tracked. The fixture uses its own portable options/storage and reads the user's
import cache; it never loads or writes player progress. Android/GLES and real
Strength movement remain user playtests. No engine production files changed.
