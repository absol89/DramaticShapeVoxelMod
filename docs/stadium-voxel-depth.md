# Stadium and voxel depth integration

Ported from the BattleArtGen2 investigation on 2026-09-05.

The old environment provider flattened the voxel scene to a color canvas,
then let Stadium draw its circles and models. Stadium's depth attachment did
not contain voxel depth, so foreground trees could not occlude those draws.
Changing their draw order or enabling depth testing on that separate target
cannot restore the missing depth information.

For ARENA FILL OFF, StadiumBackground now submits the classic circles followed
by opaque/additive model passes through BattleScene's existing actor callback,
while its voxel color and depth attachments are still bound. Stadium-local
geometry is translated by the arena midpoint and ground height; the shadow
lookup uses the inverse translation. The provider reports model ownership to
prevent a duplicate draw over the resolved color canvas. Claimed models still
cast through Stadium's shadow hook. Native trainer presentation stays with
the importer.

The circle is lifted slightly above the depth-writing voxel floor. HALF radius
and temporary stage/graphics state are restored even when drawing fails.
Rendering failures release ownership for the importer's normal fallback.

Attack capture, Stadium Battle FX, and animation alignment are unchanged in
this port. The environment provider returns the original importer marks.
Never substitute supersampled target-pixel coordinates for logical marks:
the importer subtracts a logical letterbox to derive attack anchors. That
mistake caused effects to shift toward the bottom-right in the Gen 2 work.

Verification: stadium_circle_depth_test exercises submission inside the live
voxel callback, model transforms/ownership, ON/HALF/OFF, logical dimensions at
4x sampling, and failure cleanup. Existing provider/model/sidecar tests cover
the surrounding integration. These are headless checks, not GPU verification.
Manual checks should cover a foreground tree across a circle and model, both
attack systems, AA OFF/4X, and native trainer transitions.
