-- Voxel world mode: the 3D pass -- shader, depth buffer and camera.
--
-- World space is world PIXELS, so every coordinate the 2D paths already
-- compute drops straight in with no unit conversion:
--
--   +X  map east   (world-pixel x)
--   +Y  up         (0 is the ground plane)
--   +Z  map south  (world-pixel y)
--
-- A character at rest faces +Z, i.e. toward a camera parked to the south,
-- which is what "facing down" means in the 2D game -- and a character card
-- is drawn in exactly that pose, leaning back rather than yawing.
--
-- The camera orbits the view centre at Voxel.angle: 0 is straight down
-- (what the flat 2D view already is) and 50 degrees leans toward the
-- horizon. Distance and field of view are tied to Voxel.FOCAL, which is the
-- same constant Tilt projects with, so a given angle frames the world
-- identically in both modes -- switching between them changes the geometry,
-- not the framing.
--
-- Every GPU object is pcall-guarded and `available()` reports the result:
-- headless test runs and any driver without depth-canvas support fall back
-- to the existing tilt/flat paths rather than erroring.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local Mat4 = V.require("Mat4")
local Voxel = V.require("VoxelState")
local ShadowMap = V.require("ShadowMap")
local Shadows = V.require("Shadows")
local VoxelGrid = V.require("VoxelGrid")
local WorldCurve = V.require("WorldCurve")
local Sky = V.require("Sky")
local DayNight = V.require("DayNight")
local GlassMask = V.require("GlassMask")
local PixelCanvas = V.require("PixelCanvas")
local TowerStone = V.require("TowerStone")

local AtmosphereCamera = V.require("AtmosphereCamera")
local Voxel3D = {}

-- Vertex format shared by terrain chunks and character models: a position,
-- the map-canvas / sprite-sheet pixel it samples, and a per-vertex darken
-- factor that gives a face its angle to the sun without a normal or a
-- light uniform. Cast shadows are a separate thing entirely -- see
-- ShadowMap, which the pixel shader below samples on top of this.
Voxel3D.FORMAT = {
  { "VertexPosition", "float", 3 },
  { "VertexTexCoord", "float", 2 },
  { "VertexShade", "float", 1 },
}

-- Face shading by direction id: top faces stay
-- full brightness, sides step down so an extruded block reads as solid
-- instead of a flat sticker, and the faces turned away from the sun are
-- darkest. The sun hangs in the SOUTHEAST (see ShadowMap), so south and
-- east are the lit flanks and north and west the shaded ones -- east and
-- west used to share one value back when the sun sat due northwest and the
-- two were symmetric about it.
--
-- This is still worth baking even now that the shadow pass throws real
-- shadows: a face turned away from the sun is dark because of its ANGLE,
-- which no shadow map measures, and the two compound the way they should
-- -- an away-facing wall that is also occluded goes darker still.
Voxel3D.FACE_SHADE = {
  [1] = 0.84,   -- +X east (toward the sun)
  [2] = 0.72,   -- -X west (away)
  [3] = 1.00,   -- +Y up
  [4] = 0.55,   -- -Y down
  [5] = 0.90,   -- +Z south (toward the camera, and toward the sun)
  [6] = 0.68,   -- -Z north (away)
}

local SHADER = [[
  // TEST28: settled foliage snow, using existing surfaces and lighting.
  // TEST37: pixel stage only. Declared in both stages these took the vertex
  // stage's highp and the pixel stage's mediump default, and GLSL ES requires
  // a uniform's precision to match across stages: a strict driver refuses to
  // link the scene shader and Voxel stays 2D (the TEST23A eye-uniform bug).
#ifdef PIXEL
  uniform float treeSnow;
  uniform float treeAutumn;
  uniform vec2 seasonalPineRegion;
  uniform float sightFloor; // TEST140: battle cutaway never opens the floor
  uniform float scenicHideOn;
  uniform LOVE_HIGHP_OR_MEDIUMP vec4 scenicHideRect;
#endif
  varying float weatherDistance;
  varying float vShade;
  varying float vReferenceMaterial;
  varying float vWorldTree;
  varying float vTropic; // TEST147: evergreen tropical leaf/core (98/99)
  varying float vDockWarm;
  varying float vMasonry;
  varying float vLantern; // TEST21: explicit pane tag, no atlas-wide glow
  varying float vFacadeBack;
  varying vec3 vSun;          // this fragment's place in the sun's view
  varying vec3 vModelSun;     // optional Stadium model-shadow view
  varying LOVE_HIGHP_OR_MEDIUMP vec3 vFoliageRay;
  uniform LOVE_HIGHP_OR_MEDIUMP vec2 reflectionClip; // enabled, uncurved water plane relative to eye
  varying float vFog;         // distance/height haze from Viridian Forest
#ifdef VOXEL_GRID
  // model space, one unit per voxel -- see VoxelGrid. Precision matters
  // here in a way it does not for a colour: the seam is the FRACTIONAL
  // part of a coordinate that runs to a few thousand across a big route,
  // so a mediump varying would quantise the fraction away entirely.
  varying LOVE_HIGHP_OR_MEDIUMP vec3 vGrid;
#endif
#ifdef VERTEX
  uniform mat4 vp;
  uniform mat4 model;
  uniform mat4 sunModel;      // where the SUN sees this vertex (see below)
  uniform mat4 sunVP;         // world -> the shadow map's unit cube
  uniform mat4 modelSunVP;    // Stadium-local world -> its shadow unit cube
  uniform vec3 modelSunOrigin;// map-world origin of Stadium's local arena
  uniform LOVE_HIGHP_OR_MEDIUMP vec3 eye;
  uniform float pull;
  uniform float worldTreePhase; // TEST23: only native route/city crown tags
  uniform vec3 curve;         // xy = the focus in world XZ, z = k; 0 = off
  uniform vec4 fogInfo;       // density, start, heightK; density 0 = clear
  attribute float VertexShade;
  vec4 position(mat4 transform_projection, vec4 vertex_position) {
    // Existing six-float layout: only dock pane shades carry a +64 tag.
    // Decode before ordinary daylight shading; negative facade tags stay intact.
    float referenceTag=step(4096.0,abs(VertexShade));
    float referenceIndex=floor(max(0.0,abs(VertexShade)-4096.0)/128.0);
    vReferenceMaterial=referenceTag*(referenceIndex+1.0);
    vWorldTree=step(94.5,vReferenceMaterial)*(1.0-step(97.5,vReferenceMaterial));
    // TEST147: tropical leaf/core render as forest leaf/core (21/22) but are
    // flagged so the autumn crown tint leaves palms and ferns green.
    vTropic=step(97.5,vReferenceMaterial)*(1.0-step(99.5,vReferenceMaterial));
    if (vTropic>0.5) vReferenceMaterial-=77.0;
    float materialShade=abs(VertexShade)-referenceTag*(4096.0+referenceIndex*128.0);
    vMasonry=step(256.0,materialShade);
    float dock=step(128.0,materialShade)*(1.0-vMasonry);
    float level=floor(max(0.0,materialShade-128.0)/4.0)*dock;
    vDockWarm=level/15.0;
    vLantern=step(64.0,materialShade)*(1.0-step(128.0,materialShade));
    vShade=abs(materialShade)-256.0*vMasonry-(128.0+level*4.0)*dock-64.0*vLantern;
#ifdef VOXEL_GRID
    // MODEL space, deliberately: every mesh here is built a unit per
    // voxel in its own frame, so the seams ride the model however it is
    // posed rather than the world's grid sliding across a leaning sprite
    vGrid = vertex_position.xyz;
#endif
    vec4 w = model * vertex_position;
    // Appended native-crown tags reuse the approved forest materials below.
    // Small shader motion requires no rebuilt vertices or extra mesh draws.
    if (vReferenceMaterial > 94.5 && vReferenceMaterial < 96.5) {
      float wave=sin(worldTreePhase+w.x*.073+w.z*.057);
      w.x+=wave*.16;
      w.z+=cos(worldTreePhase+w.z*.061-w.x*.049)*.10;
      vReferenceMaterial-=74.0; // 95/96 -> leaf/core 21/22
    } else if (vWorldTree>0.5) { vReferenceMaterial=20.0; }
    // TEST169: League leaf crowns and conifers (128/129) stir in the breeze;
    // clipped hedges (127) stay put.
    if (vReferenceMaterial > 127.5 && vReferenceMaterial < 129.5) {
      float gust=.75+.25*sin(worldTreePhase*.37+w.x*.011);
      w.x+=sin(worldTreePhase*1.20+w.x*.045+w.z*.031+w.y*.06)*.20*gust;
      w.z+=cos(worldTreePhase*.95+w.z*.041-w.x*.027+w.y*.05)*.14*gust;
    }
    vFoliageRay = w.xyz - eye;
    weatherDistance = max(0.0, length(w.xyz-eye)-300.0);
    // All four vertices of a marked facade lie on one Z plane, so this is
    // constant across its fragments. Work it out here where `eye` belongs;
    // the pixel stage only needs the yes/no result.
    vFacadeBack = step(VertexShade, -0.0001) * step(eye.z, w.z - 0.0001);
    // The shadow lookup runs off `sunModel`, not `model`. For terrain the
    // two are the same matrix, but a character is drawn as a slab LEANING
    // back by the camera's pitch -- a trick played on the viewer, which
    // the sun never saw: it lit the upright card. Looking up with the
    // leaned position asks whether the sun reached a place the figure is
    // not, and since the lean tips the body north and shadows now fall
    // north, every sprite's own card fell across its front. Looking up
    // with the card's position asks the question the sun actually
    // answered. (The pull below is excluded for the same reason: it is a
    // depth trick aimed at the camera's own buffer.)
    vSun = (sunVP * (sunModel * vertex_position)).xyz;
    // Stadium owns and completes its live model shadow map before requesting
    // our environment. Translate this map-world receiver into Stadium's
    // arena-local coordinates and sample that finished map as a second light
    // layer; no cross-mod render-target or shader handoff is required.
    vModelSun = (modelSunVP * vec4(w.xyz - modelSunOrigin, 1.0)).xyz;
    // Work out haze on the flat world, before the optional presentation
    // curve.  Viridian's fog therefore stays planted in the map instead of
    // bending with the camera trick.
    vFog = 0.0;
    if (fogInfo.x > 0.0) {
      float fogRun = max(0.0, length(w.xyz - eye) - fogInfo.y);
      vFog = (1.0 - exp(-fogInfo.x * fogRun))
             * exp(-max(w.y, 0.0) * fogInfo.z);
    }
    // The curved world (see WorldCurve): drop every vertex by the square
    // of how far its column stands from the camera's focus. Applied AFTER
    // the shadow lookup above and clear of the wireframe's model space, so
    // both are worked out on the flat world and the bend carries them
    // along -- which is why neither has to know this exists. Along Y only,
    // so a column moves as one piece: the world tips away and the
    // buildings standing on it stay upright.
    if (curve.z > 0.0) {
      vec2 cd = w.xz - curve.xy;
      w.y -= dot(cd, cd) * curve.z;
    }
    // camera-ward pull: move the vertex along ITS OWN ray to the eye.
    // This is a pure depth bias -- the projection of a point moved along
    // its eye ray is bit-identical, so there is no screen drift at all.
    // (An earlier CPU version translated along the central view axis,
    // which preserved only the screen centre and made off-centre sprites
    // and grass swim against the ground while the camera scrolled.)
    if (pull > 0.0) {
      w.xyz += normalize(eye - w.xyz) * pull;
    }
    return vp * w;
  }
#endif
#ifdef PIXEL
  // TEST181/182: FULL PRECISION FOR THE PROCEDURAL FINISHES, and only them.
  // LOVE's GLSL ES pixel stage defaults to half precision. Every procedural
  // finish hashes the world position, and half precision holds a position
  // of 700 to the nearest half unit: the hash collapses into bands along
  // the axes (Route 2's loam drew as planks and sleepers, the lawns a grid
  // of flowers). The finish functions (forestSoilHash .. referenceSurface,
  // below) are declared between LG_PRECISE_ON and LG_PRECISE_OFF, so their
  // parameters, locals and results are full precision on GLSL ES when the
  // GPU offers it; the atlas texturing, lighting, shadows, fog and water
  // around them stay half precision (TEST181 made the whole stage full
  // precision, and the routes slowed). Desktop GL ignores precision.
#if defined(GL_ES) && defined(GL_FRAGMENT_PRECISION_HIGH) && !defined(LG_FAST_PRECISION)
#define LG_PRECISE_ON precision highp float;
#define LG_PRECISE_OFF precision mediump float;
#else
#define LG_PRECISE_ON
#define LG_PRECISE_OFF
#endif
  uniform Image sunMap;
  uniform float sunDark;      // how far into black a shadow goes; 0 = off
  uniform float sunBias;
  uniform vec2 sunTexel;
  uniform Image modelSunMap;
  uniform float modelSunDark;
  uniform float modelSunBias;
  uniform vec2 modelSunTexel;

  // the two-channel pack ShadowMap writes: high byte, then low
  float sunDepth(vec2 uv) {
    vec4 c = Texel(sunMap, uv);
    return c.r + c.g * (1.0 / 255.0);
  }

  // 1.0 in full sun, 1.0 - sunDark in full shadow. Four taps half a texel
  // out on the diagonals: a 2x2 box filter, which is what turns the
  // shadow map's texel staircase into a one-pixel soft edge.
  float sunlight(vec3 p) {
    if (sunDark <= 0.0) return 1.0;
    // outside the sun's frustum nothing was recorded, so nothing occludes
    if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0 || p.z > 1.0) {
      return 1.0;
    }
    // Ease the shadows off at the frustum's rim. The map covers the ground
    // the camera can see out to a cap, and past the low rungs -- 75 degrees
    // especially -- the horizon is further than any box worth paying for.
    // Without this the covered region simply ENDS, drawing a hard line
    // across the middle distance where every shadow stops at once; with it
    // the far field just loses them, which reads as distance.
    vec2 e = min(p.xy, 1.0 - p.xy);
    float edge = smoothstep(0.0, 0.06, min(e.x, e.y));
    if (edge <= 0.0) return 1.0;
    // TEST18: bilinear receiver-plane PCF for tagged building surfaces only.
    // Correct depth at each sampled texel, reducing roof-edge staircase/acne
    // without changing the terrain/interior shadow or adding a shadow pass.
    // (TEST165: not the League finishes, ids 100+: their large flat faces
    // took light-leak streaks from it; the plain four-tap filter is clean.)
    if(vReferenceMaterial>51.5 && vReferenceMaterial<99.5) {
      vec3 dx=dFdx(p),dy=dFdy(p);
      float det=dx.x*dy.y-dx.y*dy.x;
      vec2 grad=abs(det)>.00000001?vec2(dy.y*dx.z-dx.y*dy.z,dx.x*dy.z-dy.x*dx.z)/det:vec2(0);
      vec2 q=p.xy/sunTexel-vec2(.5),f=fract(q),uv=(floor(q)+vec2(.5))*sunTexel;
      vec2 a=uv,b=uv+vec2(sunTexel.x,0),c=uv+vec2(0,sunTexel.y),d=uv+sunTexel;
      float limit=max(sunBias*4.0,.0002);
      float aa=step(p.z+clamp(dot(grad,a-p.xy),-limit,limit)-sunBias,sunDepth(a));
      float bb=step(p.z+clamp(dot(grad,b-p.xy),-limit,limit)-sunBias,sunDepth(b));
      float cc=step(p.z+clamp(dot(grad,c-p.xy),-limit,limit)-sunBias,sunDepth(c));
      float dd=step(p.z+clamp(dot(grad,d-p.xy),-limit,limit)-sunBias,sunDepth(d));
      float lit=mix(mix(aa,bb,f.x),mix(cc,dd,f.x),f.y);
      return 1.0-sunDark*edge*(1.0-lit);
    }
    float z = p.z - sunBias;
    float lit = step(z, sunDepth(p.xy + sunTexel * vec2(-0.5, -0.5)))
              + step(z, sunDepth(p.xy + sunTexel * vec2( 0.5, -0.5)))
              + step(z, sunDepth(p.xy + sunTexel * vec2(-0.5,  0.5)))
              + step(z, sunDepth(p.xy + sunTexel * vec2( 0.5,  0.5)));
    return 1.0 - sunDark * edge * (1.0 - lit * 0.25);
  }

  float modelSunDepth(vec2 uv) {
    vec4 c = Texel(modelSunMap, uv);
    return c.r + c.g * (1.0 / 255.0);
  }

  float modelSunlight(vec3 p) {
    if (modelSunDark <= 0.0) return 1.0;
    if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0 || p.z > 1.0) {
      return 1.0;
    }
    float z = p.z - modelSunBias;
    float lit = step(z, modelSunDepth(p.xy + modelSunTexel * vec2(-0.5, -0.5)))
              + step(z, modelSunDepth(p.xy + modelSunTexel * vec2( 0.5, -0.5)))
              + step(z, modelSunDepth(p.xy + modelSunTexel * vec2(-0.5,  0.5)))
              + step(z, modelSunDepth(p.xy + modelSunTexel * vec2( 0.5,  0.5)));
    return 1.0 - modelSunDark * (1.0 - lit * 0.25);
  }

#ifdef VOXEL_GRID
  uniform float gridDark;     // how far toward black a seam pulls; 0 = off
  uniform float gridWidth;    // seam width, in display pixels

  // How much of this fragment a voxel seam covers, 0 to 1.
  float voxelSeam(vec3 p) {
    // how much of `p` this fragment spans on screen, per axis: the
    // conversion from model units to display pixels, measured rather than
    // derived, so it holds under any camera pitch or zoom
    vec3 w = fwidth(p);
    vec3 d = abs(fract(p + 0.5) - 0.5);      // distance to the nearest plane
    // The axis a face does not vary along is that face's own normal, and
    // its distance is a constant zero -- take it at face value and every
    // face floods solid. Push those axes out of reach instead of dividing
    // by their zero.
    vec3 live = step(1e-4, w);
    vec3 px = d / max(w, vec3(1e-6)) + (1.0 - live) * 1e6;
    float near = min(min(px.x, px.y), px.z);
    // Fade out where a voxel is too small to hold a line. Survey zoom
    // draws a world pixel at about a display pixel, and a wall seen nearly
    // edge-on squashes one to nothing at any zoom -- either way the seams
    // land closer together than they are wide, and drawn anyway they stop
    // being a wireframe and become a flat 45% dimming of the whole scene.
    // The tightest axis decides, which is the honest test of whether the
    // grid can be resolved at all.
    float span = 1.0 / max(max(w.x, max(w.y, w.z)), 1e-6);
    float fade = clamp((span - 2.0) * 0.5, 0.0, 1.0);
    // the textbook antialiased line: solid within the half-width, fading
    // over the one pixel outside it
    return fade * clamp(gridWidth * 0.5 + 0.5 - near, 0.0, 1.0);
  }
#endif

  uniform vec3 ghostColor;    // the flat silhouette colour
  uniform float ghost;        // 0 = shade normally, 1 = flatten to it
  uniform float towerStoneOn;
  uniform vec4 towerStoneRegion;
  uniform vec3 towerStoneTint;
  uniform float towerStoneQuiet;
  uniform vec3 towerStoneHoned;
  uniform float effectSurface; // scoped translucent VFX; zero for normal world
  uniform float lightOn;      // 1 = scene lighting, 0 = texture true-colour
  uniform float weatherHaze;
  uniform vec3 weatherHazeColor;
  uniform vec3 weatherMul;
  uniform vec3 weatherAdd;
  uniform vec3 dayTint;       // the hour's light on the world; 1,1,1 = noon
  uniform vec3 fogColor;      // what the active map haze is made of
  uniform Image glassMask;    // opaque where the atlas texel is window glass
  uniform vec2 glassSize;     // the mask's dimensions: tc -> atlas texels
  // TEST75: camera-relative, unshadowed local breath illumination.
  uniform vec4 fireLightA;
  uniform vec4 fireLightB;
  uniform float fireLightPower;
  float breathLight() {
    vec3 segment=fireLightB.xyz-fireLightA.xyz;
    float along=clamp(dot(vFoliageRay-fireLightA.xyz,segment)/max(dot(segment,segment),0.001),0.0,1.0);
    vec3 delta=vFoliageRay-mix(fireLightA.xyz,fireLightB.xyz,along);
    float radius=mix(fireLightA.w,fireLightB.w,along);
    float f=max(0.0,1.0-length(delta)/max(radius,0.001));
    return f*f*fireLightPower;
  }
  uniform LOVE_HIGHP_OR_MEDIUMP vec3 eye; // pixel-stage world material coordinates
  uniform float battleWaterOn; // TEST24: scoped to staged water meshes only
  uniform float battleWaterPhase;
  uniform float indoorPoolOn;
  uniform float streetLampOn;
  uniform vec3 streetLampA;
  uniform vec3 streetLampB;
  uniform vec3 streetLampC;
  uniform vec3 streetLampD;
  float streetPool(vec3 center) {
    vec3 d=vFoliageRay-center;
    // TEST20: broader soft pools, still only the existing four Lavender lamps.
    float falloff=1.0-smoothstep(0.0,30.0,length(d.xz));
    return falloff*falloff*(1.0-smoothstep(1.0,9.0,abs(d.y)));
  }
  uniform Image worldTreeBark;
  uniform Image worldTreeLeaves;
  uniform float worldTreeTextures;
  uniform float casinoPhase; // smooth marquee chase; only new neon material IDs
  uniform float glassNight;   // 0 = daylight .. 1 = the lamps are on
  uniform float roomNight;    // TEST179: the clock's night, 0..1, for the painted window views indoors
  uniform float glassPhase;   // the glint's phase: advances with TRAVEL
  uniform float glassGlint;   // and its strength: 0 while standing still
  uniform float glassOn;      // 0 for sprite-sheet draws (see Voxel3D.glass)

  // BATTLE-FOLIAGE1: used only for explicitly scoped tree mesh draws.
  uniform float foliageCutOn;
  uniform float foliageNativeOnly; // TEST95: native trees within mixed terrain
  uniform vec3 foliageTargetA; // camera-relative, matching vFoliageRay
  uniform vec3 foliageTargetB;
  uniform float foliageRadius;
  float foliageOpening(vec3 ray, vec3 target) {
    float length2 = dot(target, target);
    if (length2 < 1.0) return 0.0;
    float t = dot(ray, target) / length2;
    // Never cut scenery behind the subject, or behind the camera.
    if (t <= 0.0 || t >= 1.0) return 0.0;
    float width = 3.0 + foliageRadius * t;
    float offAxis = length(ray - target * t) / width;
    float edge = 1.0 - smoothstep(0.68, 1.0, offAxis);
    return edge * (1.0 - smoothstep(0.88, 1.0, t));
  }
  float foliageThreshold(vec2 pixel) {
    // Stable ordered coverage: only the soft rim is stippled. The centre
    // is fully clear even through many overlapping leaf cards; no blend
    // sorting or transparent geometry writing depth over the Pokemon.
    vec2 p = mod(floor(pixel), 4.0);
    vec2 lo = mod(p, 2.0);
    vec2 hi = floor(p / 2.0);
    float a = 2.0 * lo.x + 3.0 * lo.y - 4.0 * lo.x * lo.y;
    float b = 2.0 * hi.x + 3.0 * hi.y - 4.0 * hi.x * hi.y;
    return (4.0 * a + b + 0.5) / 16.0;
  }
  // TEST93: moss, humus and sparse settled leaves in world coordinates.
  // The existing floor stays flat. Small detail fades before it can shimmer
  // in the distance; no animated input, screen noise, atlas or extra pass.
  // Smooth, non-periodic value noise; the grid is only an interpolation
  // domain. Warped coordinates and mixed scales avoid a woven/tiled surface.
  // TEST94: bounded arithmetic retains variation without the large
  // sine-hash multiplier that loses fractional bits on lower precision GPUs.
  LG_PRECISE_ON
  float forestSoilHash(vec2 p) {
    vec2 k=mod(p,61.0);
    k=mod(k*k+vec2(17.0,29.0),61.0);
    float n=mod(k.x*13.0+k.y*7.0,61.0);
    return mod(n*n+19.0,61.0)/61.0;
  }
  float forestSoilNoise(vec2 p) {
    vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
    vec4 n=vec4(forestSoilHash(i),forestSoilHash(i+vec2(1,0)),
      forestSoilHash(i+vec2(0,1)),forestSoilHash(i+vec2(1,1)));
    return mix(mix(n.x,n.y,f.x),mix(n.z,n.w,f.x),f.y);
  }
  vec3 forestFloorSurface(vec3 pos) {
    vec2 p=pos.xz;
    vec2 warped=p+vec2(sin(p.y*.17+p.x*.07),sin(p.x*.13-p.y*.09))*2.7;
    float broad=forestSoilNoise(warped*.047);
    float middle=forestSoilNoise(warped*.31);
    float moss=smoothstep(.10,.62,broad+(middle-.5)*.22);
    vec3 earth=vec3(.350,.370,.200);
    vec3 green=vec3(.420,.580,.260);
    vec3 base=mix(earth,green,moss);
    float closeDetail=1.0-smoothstep(64.0,220.0,length(pos-eye));
    base+=vec3((middle-.5)*.052);
    if(closeDetail<.001) return clamp(base,0.0,1.0);
    float fine=forestSoilNoise(warped*3.7)-.5;
    float fibre=forestSoilNoise(warped*vec2(2.6,1.3))-.5;
    base+=vec3((fine*.090+fibre*.065*moss)*closeDetail);
    // Each sparse leaf fits inside its jittered cell, so floor() introduces
    // neither a visible grid nor a discontinuity at cell boundaries.
    vec2 cell=floor(p/4.8);
    float h=forestSoilHash(cell);
    float j=fract(h*17.13+.37);
    vec2 q=p-cell*4.8-vec2(2.4+(h-.5)*1.1,2.4+(j-.5)*1.1);
    float angle=h*6.2831853;
    q=mat2(cos(angle),-sin(angle),sin(angle),cos(angle))*q;
    float shape=abs(q.x)/.78+q.y*q.y/.085;
    float leaf=(1.0-smoothstep(.70,1.0,shape))*step(.86,h)*closeDetail;
    float rib=(1.0-smoothstep(.012,.045,abs(q.y)))*.030;
    vec3 litter=vec3(.365,.291,.168)+vec3((j-.5)*.025-rib);
    return clamp(mix(base,litter,leaf*.82),0.0,1.0);
  }
  // Forest-floor diffuse fill follows the current day/night tint. Keep
  // 48% of the original shadow/AO response; daylight maximum stays unchanged.
  vec3 forestFloorLighting(vec3 surface,vec3 shaded,vec3 tint) {
    return surface*tint*.52+shaded*.48;
  }
  // TEST124: submerged Cinnabar silt, sampled across world coordinates.
  // Low contrast mineral patches and fine grains have no repeating tile edge.
  vec3 waterBedSurface(vec3 pos) {
    vec2 p=pos.xz;
    vec2 warped=p+vec2(sin(p.y*.061),sin(p.x*.049))*3.1;
    float sediment=forestSoilNoise(warped*.057);
    float gravel=forestSoilNoise(warped*.39);
    float detail=1.0-smoothstep(.30,1.2,length(fwidth(p)));
    float grain=forestSoilNoise(warped*2.3)-.5;
    vec3 silt=mix(vec3(.255,.28,.255),vec3(.345,.355,.29),sediment);
    return silt+vec3((gravel-.5)*.035+grain*.026*detail);
  }
  // Surface multiplier preserves selected atlas colors on stone boundaries
  // and the Tower. World-stable detail fades before the camera can alias it.
  // TEST177: the surface's normal, worked out ONCE per fragment in effect()
  // from the full-precision world ray (vFoliageRay), before any branch.
  // The finishes below used to take it from their own position argument --
  // mediump on phones, where the derivatives' cross product underflows near
  // the camera: the normal came out zero or huge, the graze term's
  // pow(1 - |dot|) went negative and returned NaN, and every reference
  // finish (the rooms, the dungeons, the routes, the cave mouths) drew
  // BLACK close to the camera.
  LOVE_HIGHP_OR_MEDIUMP vec3 refNormal=vec3(0.0,1.0,0.0);
  float exteriorAtlasCraft(vec3 pos) {
    vec3 normal=abs(refNormal);
    vec2 uv=normal.y>max(normal.x,normal.z)?pos.xz:(normal.x>normal.z?pos.zy:pos.xy);
    float px=max(length(dFdx(uv)),length(dFdy(uv)));
    float fine=1.0-smoothstep(.12,.65,px);
    float n=forestSoilNoise(uv*.56);
    float grain=(forestSoilNoise(uv*4.2)-.5)*fine;
    float fleck=(forestSoilHash(floor(uv*6.0))-.5)*fine;
    return .93+n*.12+grain*.20+fleck*.12;
  }
  // TEST18 exterior surfaces. Stable world coordinates, derivative-filtered
  // grain, continuous joints and restrained weathering. No textures or pass.
  vec3 exteriorSurface(float mat,vec3 pos) {
    vec3 base=vec3(.5);float kind=0.0;
    if (mat < 52.5) { base=vec3(0.8,0.77,0.66);kind=0.0; }
    else if (mat < 53.5) { base=vec3(0.7,0.59,0.44);kind=0.0; }
    else if (mat < 54.5) { base=vec3(0.64,0.6,0.51);kind=1.0; }
    else if (mat < 55.5) { base=vec3(0.24,0.275,0.28);kind=1.0; }
    else if (mat < 56.5) { base=vec3(0.81,0.82,0.75);kind=0.0; }
    else if (mat < 57.5) { base=vec3(0.55,0.66,0.57);kind=0.0; }
    else if (mat < 58.5) { base=vec3(0.43,0.31,0.22);kind=2.0; }
    else if (mat < 59.5) { base=vec3(0.3,0.49,0.43);kind=4.0; }
    else if (mat < 60.5) { base=vec3(0.57,0.32,0.25);kind=3.0; }
    else if (mat < 61.5) { base=vec3(0.28,0.43,0.59);kind=5.0; }
    else if (mat < 62.5) { base=vec3(0.67,0.76,0.79);kind=0.0; }
    else if (mat < 63.5) { base=vec3(0.46,0.34,0.3);kind=6.0; }
    else if (mat < 64.5) { base=vec3(0.18,0.22,0.28);kind=7.0; }
    else if (mat < 65.5) { base=vec3(0.42,0.48,0.53);kind=4.0; }
    else if (mat < 66.5) { base=vec3(0.58,0.46,0.28);kind=4.0; }
    else if (mat < 67.5) { base=vec3(0.42,0.35,0.56);kind=0.0; }
    else if (mat < 68.5) { base=vec3(0.23,0.56,0.64);kind=8.0; }
    else if (mat < 69.5) { base=vec3(0.565,0.445,0.515);kind=0.0; }
    else if (mat < 70.5) { base=vec3(0.7,0.64,0.65);kind=0.0; }
    else if (mat < 71.5) { base=vec3(0.255,0.195,0.235);kind=2.0; }
    else if (mat < 72.5) { base=vec3(0.49,0.465,0.49);kind=1.0; }
    else if (mat < 73.5) { base=vec3(0.245,0.255,0.305);kind=3.0; }
    else if (mat < 74.5) { base=vec3(0.34,0.245,0.205);kind=2.0; }
    else if (mat < 75.5) { base=vec3(0.23,0.39,0.57);kind=5.0; }
    else if (mat < 76.5) { base=vec3(0.91,0.84,0.62);kind=5.0; }
    else if (mat < 77.5) { base=vec3(0.88,0.86,0.76);kind=5.0; }
    else if (mat < 78.5) { base=vec3(0.35,0.25,0.18);kind=2.0; }
    else if (mat < 79.5) { base=vec3(0.59,0.43,0.28);kind=2.0; }
    else if (mat < 80.5) { base=vec3(0.47,0.5,0.49);kind=1.0; }
    else if (mat < 81.5) { base=vec3(0.64,0.66,0.63);kind=1.0; }
    else if (mat < 82.5) { base=vec3(0.27,0.32,0.35);kind=3.0; }
    else if (mat < 83.5) { base=vec3(0.49,0.24,0.19);kind=3.0; }
    else if (mat < 84.5) { base=vec3(0.56,0.29,0.22);kind=3.0; }
    else if (mat < 85.5) { base=vec3(0.18,0.34,0.21);kind=3.0; }
    else if (mat < 86.5) { base=vec3(0.13,0.24,0.39);kind=5.0; }
    else if (mat < 87.5) { base=vec3(0.64,0.2,0.18);kind=5.0; }
    else if (mat < 88.5) { base=vec3(0.14,0.14,0.17);kind=4.0; }
    else if (mat < 89.5) { base=vec3(0.97,0.83,0.47);kind=4.0; }
    else if (mat < 90.5) { base=vec3(0.27,0.42,0.58);kind=8.0; }
    else if (mat < 91.5) { base=vec3(0.52,0.53,0.49);kind=9.0; }
    else if (mat < 92.5) { base=vec3(0.3,0.27,0.34);kind=1.0; }
    else if (mat < 93.5) { base=vec3(0.88,0.86,0.76);kind=0.0; }

    vec3 normal=abs(refNormal);
    vec2 uv=normal.y>max(normal.x,normal.z)?pos.xz:(normal.x>normal.z?pos.zy:pos.xy);
    float pixel=max(length(dFdx(uv)),length(dFdy(uv)));
    float fine=1.0-smoothstep(.12,.65,pixel);
    float medium=1.0-smoothstep(.65,2.2,pixel);
    float broad=forestSoilNoise(uv*.21);
    float grit=(forestSoilNoise(uv*4.7)-.5)*fine;
    float speck=(forestSoilHash(floor(uv*7.0))-.5)*fine;
    float damp=(1.0-smoothstep(1.0,9.0,pos.y))*(.025+.07*broad);
    if(kind<.5) {
      // Limewash/stucco: trowel clouds, aggregate, tiny recessed pores.
      float trowel=forestSoilNoise(uv*vec2(.67,.29));
      base*=.94+.12*broad+.065*(trowel-.5)+grit*.12+speck*.075-damp;
      base-=vec3(.04)*smoothstep(.32,.46,speck)*fine;
    } else if(kind<1.5 || kind>8.5) {
      // Staggered ashlar: every vertical seam meets its horizontal course.
      vec2 q=uv/vec2(8.0,4.0);float row=floor(q.y);q.x+=mod(row,2.0)*.5;
      vec2 cell=floor(q),f=fract(q),edge=min(f,1.0-f)*vec2(8,4);
      float d=min(edge.x,edge.y),aa=max(.025,pixel*.65);
      float joint=1.0-smoothstep(.055,.055+aa,d);
      float bevel=1.0-smoothstep(.10,.33+aa,d);
      float block=forestSoilHash(cell);
      base*=.84+block*.27+(broad-.5)*.14+grit*.18+speck*.10-damp;
      base=mix(base,base*.60,joint*medium);
      base+=vec3(.05)*(bevel-joint)*medium;
      if(kind>8.5) {
        float erosion=forestSoilNoise(uv*.45+vec2(broad*2.0,0));
        float stain=smoothstep(.51,.77,erosion)*(.14+.13*(1.0-smoothstep(5.0,30.0,pos.y)));
        base*=1.0-stain;
        base=mix(base,base*vec3(.71,.80,.68),damp*1.6);
        float fault=abs(sin(uv.x*1.7+forestSoilNoise(uv*.7)*7.0));
        base*=1.0-(1.0-smoothstep(.015,.07+pixel,fault))*.21*medium*step(.67,erosion);
      }
    } else if(kind<2.5 || (kind>4.5 && kind<5.5)) {
      // Timber and painted siding: long fibres follow boards, with knots.
      float row=floor(uv.y/3.0);float rnd=forestSoilHash(vec2(row,4));
      vec2 q=vec2(uv.x*.18,uv.y*3.1+sin(uv.x*.14+row)*.45);
      float fibre=forestSoilNoise(q);
      float ring=sin(uv.y*15.0+fibre*5.0+sin(uv.x*.31+row)*.7);
      float seam=1.0-smoothstep(.025,.10+pixel*.65,min(fract(uv.y/3.0),1.0-fract(uv.y/3.0))*3.0);
      float end=1.0-smoothstep(.025,.09+pixel*.65,min(fract((uv.x+rnd*15.0)/21.0),1.0-fract((uv.x+rnd*15.0)/21.0))*21.0);
      float strength=kind<2.5?1.0:.48;
      base*=.90+rnd*.15+(fibre-.5)*.20*strength+ring*.035*fine*strength+speck*.065-damp;
      base*=1.0-medium*(seam*.22+end*.09);
      float knot=length(vec2((mod(uv.x+rnd*23.0,31.0)-15.5)*.6,(fract(uv.y/3.0)-.52)*6.0));
      base*=1.0-(1.0-smoothstep(.18,1.0,knot))*.22*strength*medium;
    } else if(kind<3.5) {
      // Slate and clay: fine lamination and mineral flecks within real tiles.
      vec2 q=pos.xz;float n=forestSoilNoise(q*vec2(.8,2.6));
      base*=.90+.17*broad+(n-.5)*.13*medium+grit*.18+speck*.10;
    } else if(kind<4.5) {
      // Brushed metal/copper: subtle longitudinal scratches and patina.
      float brush=forestSoilNoise(uv*vec2(.22,8.0));
      base*=.93+broad*.12+(brush-.5)*.12*fine;
      float patina=smoothstep(.57,.82,forestSoilNoise(uv*.48));
      base*=1.0-patina*.13*medium;
    } else if(kind<6.5) {
      vec2 q=uv/vec2(5.2,2.35);q.x+=mod(floor(q.y),2.0)*.5;
      vec2 f=fract(q),edge=min(f,1.0-f)*vec2(5.2,2.35);
      float d=min(edge.x,edge.y),aa=max(.025,pixel*.6);
      float joint=1.0-smoothstep(.075,.075+aa,d);
      float rim=1.0-smoothstep(.14,.30+aa,d);
      base*=.79+.32*forestSoilHash(floor(q))+grit*.20+speck*.11;
      base=mix(base,vec3(.39,.365,.31),joint*medium*.87);
      base+=vec3(.035)*(rim-joint)*medium;
    } else if(kind<7.5) {
      float vein=sin(uv.x*.76+uv.y*.31+forestSoilNoise(uv*.33)*7.5);
      base*=.91+broad*.16+grit*.10;
      base+=vec3(.07,.075,.082)*smoothstep(.91,.99,vein)*medium;
    } else {
      // Pane reflections retain a quiet gradient, also visible in unlit rooms.
      float sky=smoothstep(-.5,.8,sin(uv.x*.14+uv.y*.11));
      base*=.75+.28*sky;
      base+=vec3(.09,.11,.12)*pow(max(0.0,sin(uv.x*.26+uv.y*.18)),12.0)*medium;
    }
    return clamp(base,vec3(.018),vec3(.98));
  }

  // TEST164: League road finishes (append-only ids 100..110). World-space,
  // derivative filtered, no atlas. Marble, granite ashlar, crimson lacquer,
  // gold, bronze, limestone/granite paving, lawn, carpet, rock, verde plinth.
  float lgHash(vec2 p) {
    vec3 p3=fract(vec3(p.xyx)*.1031);
    p3+=dot(p3,p3.yzx+33.33);
    return fract((p3.x+p3.y)*p3.z);
  }
  float lgNoise(vec2 p) {
    vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(lgHash(i),lgHash(i+vec2(1.0,0.0)),f.x),
               mix(lgHash(i+vec2(0.0,1.0)),lgHash(i+vec2(1.0,1.0)),f.x),f.y);
  }
  float lgFbm(vec2 p) {
    return .50*lgNoise(p)+.30*lgNoise(p*2.03+vec2(7.1,1.3))+.20*lgNoise(p*4.11+vec2(3.7,9.2));
  }
  // TEST169: 3D value noise for the flora (crowns are faceted solids: a
  // planar projection would seam at every facet).
  float lgHash3(vec3 p) {
    p=fract(p*.1031);
    p+=dot(p,p.zyx+31.32);
    return fract((p.x+p.y)*p.z);
  }
  float lgNoise3(vec3 p) {
    vec3 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
    float a=mix(lgHash3(i),lgHash3(i+vec3(1,0,0)),f.x);
    float b=mix(lgHash3(i+vec3(0,1,0)),lgHash3(i+vec3(1,1,0)),f.x);
    float c=mix(lgHash3(i+vec3(0,0,1)),lgHash3(i+vec3(1,0,1)),f.x);
    float d=mix(lgHash3(i+vec3(0,1,1)),lgHash3(i+vec3(1,1,1)),f.x);
    return mix(mix(a,b,f.y),mix(c,d,f.y),f.z);
  }
  // TEST165: a thin line that FADES when the pixel outgrows it, instead of
  // widening into a dark band (the scene renders well below screen size).
  // TEST202: box-filtered. The pixel covers `pixel` units centred at d;
  // the line is the band |x|<w round its edge (d is folded, d>=0). The
  // result is the share of the pixel the line really covers, so a line
  // thinner than a pixel greys it evenly instead of popping on and off as
  // the camera moves (the shimmer on tile grout, boards and veins). Lines
  // the pixel resolves look as before.
  float lgLine(float d,float w,float pixel) {
    float p=max(pixel,.0001);
    float h=p*.5;
    return clamp(min(d+h,w)-max(d-h,-w),0.0,p)/p;
  }
  // Polished stone veining: thin dark lines along a domain-warped field.
  float lgVein(vec2 uv,float scale,float width,float pixel) {
    vec2 q=uv*scale;
    float warp=lgFbm(q*.9)*5.0+lgNoise(q*2.7)*.9;
    float v=abs(sin(q.x*1.3+q.y*.7+warp));
    return lgLine(v,width,pixel*scale*1.6);
  }
  // TEST173: THE TOWN INTERIORS' FINISHES (ReferenceMaterials in*, shader
  // materials 143..171). World-space and derivative filtered like the
  // League's. 143-146 floorboards and parquet, 147-151 tile, checker,
  // terrazzo, tatami, flagstone, 152-155 wool pile (rugs, upholstery),
  // 156-158 wallpapers, 159 brick, 160 book spines, 161 shop goods,
  // 162 red lacquer, 163 white enamel, 164 leather, 165 brushed steel.
  // 166-171 give off their own light (see effect()): screens, lamp shades,
  // aquarium water, paper screens, the view through a window, light panels.
  // vShade picks a variant on the self-lit ones (they ignore the light).
  vec3 inBoards(vec2 uv,vec3 pos,float topFace,float pixel,vec3 c0,vec3 c1,float bw,float fineR,float medR) {
    // floors: boards run east-west; walls: boards stand upright
    float a=mix(uv.x,pos.z,topFace),l=mix(uv.y,pos.x,topFace);
    float bi=floor(a/bw),fa=fract(a/bw);
    float bl=22.0+lgHash(vec2(bi,9.0))*30.0;float off=lgHash(vec2(bi,3.0))*bl;
    float li=floor((l+off)/bl),fl=fract((l+off)/bl);
    float tone=lgHash(vec2(bi,li)+vec2(4.0,1.0));
    vec3 col=mix(c0,c1,tone);
    float g=lgNoise(vec2(l*.11+li*7.0,a*1.6+bi*13.0));
    col*=.90+.15*(.5+.5*sin(g*17.0+a*1.3))*medR;
    col*=1.0+(lgNoise(vec2(l*.55,a*5.5))-.5)*.12*fineR;
    float j1=lgLine(min(fa,1.0-fa)*bw,.09,pixel);
    float j2=lgLine(min(fl,1.0-fl)*bl,.09,pixel);
    return mix(col,c0*.38,max(j1,j2)*.8);
  }
  vec3 inPile(vec2 uv,float fineR,vec3 c) {
    float m=lgFbm(uv*.09);
    vec3 col=c*(.84+.30*m);
    col*=1.0+(lgNoise(uv*1.9)-.5)*.16*fineR+(lgNoise(uv*4.3+vec2(3.0,1.0))-.5)*.10*fineR;
    return col;
  }
  // TEST174: THE DUNGEONS' FINISHES (ReferenceMaterials dn*, shader
  // materials 172..178): the Tower's honed stone in its three finishes
  // (smoke black, storm white, pearl white, all amethyst), the Tower's
  // painted vault, charred timber, office carpet tiles, rusted iron.
  vec3 dungeonSurface(float m,vec3 pos,vec2 uv,float topFace,float pixel,float fineR,float medR,float graze) {
    vec3 col=vec3(.5);
    if (m<174.5) {
      // coursed ashlar on the walls, big slabs underfoot; joints chiselled,
      // faces honed (a soft sheen at a low angle), the amethyst cast
      vec3 c0,c1,cj,cv;
      if (m<172.5) { c0=vec3(.15,.11,.20);c1=vec3(.25,.19,.31);cj=vec3(.06,.04,.08);cv=vec3(.36,.26,.46); }
      else if (m<173.5) { c0=vec3(.58,.54,.66);c1=vec3(.72,.68,.80);cj=vec3(.36,.32,.44);cv=vec3(.46,.40,.56); }
      else { c0=vec3(.78,.74,.86);c1=vec3(.90,.87,.95);cj=vec3(.58,.53,.67);cv=vec3(.66,.58,.78); }
      vec2 dim=topFace>.5?vec2(24.0,24.0):vec2(16.0,8.0);
      vec2 q=uv/dim;float row=floor(q.y);q.x+=mod(row,2.0)*.5+lgHash(vec2(row,3.0))*.2*(1.0-topFace);
      vec2 ci=floor(q),f=fract(q);vec2 e=min(f,1.0-f)*dim;float d=min(e.x,e.y);
      float h=lgHash(ci+vec2(4.0,9.0));
      col=mix(c0,c1,h*.8+.2*lgNoise(uv*.07));
      col*=.90+.16*lgFbm(uv*.18+ci*1.7)*medR;
      // a vein or two through the pale stones, specks in the dark
      float vein=pow(1.0-abs(2.0*lgNoise(uv*.05+ci*.3+vec2(lgNoise(uv*.11)*1.6))-1.0),18.0);
      col=mix(col,cv,vein*(m<172.5?.25:.55)*medR);
      col+=vec3(.06,.05,.08)*step(.985,lgHash(floor(uv*1.5)))*fineR*(m<172.5?1.0:.4);
      // chiselled joint: a dark line with a bright lip above it
      col=mix(col,cj,lgLine(d,.32,pixel)*.95);
      col+=cv*.18*lgLine(abs(e.y-.9),.25,pixel)*(1.0-topFace)*medR;
      col+=vec3(.16,.13,.20)*graze*(m<172.5?.9:.6);
    } else if (m<175.5) {
      // the vault: deep violet plaster, a faint cloud, gilt stars
      col=mix(vec3(.13,.07,.20),vec3(.27,.15,.36),lgNoise(uv*.025)*.7+lgNoise(uv*.09)*.3);
      vec2 sq=uv/6.0;vec2 si=floor(sq);
      float st=(1.0-smoothstep(.06,.16+pixel*.08,length(fract(sq)-vec2(.5))))*step(.93,lgHash(si+vec2(7.0,1.0)));
      col=mix(col,vec3(.95,.78,.38),st*medR);
      col+=vec3(.10,.06,.14)*graze;
    } else if (m<176.5) {
      // charred timber: alligatored char, grey ash in the cracks
      vec2 q=uv*vec2(.10,.22);vec2 ci=floor(q);vec2 f=fract(q);
      vec2 o=vec2(lgHash(ci+vec2(1.0,2.0)),lgHash(ci+vec2(5.0,3.0)))*.3;
      vec2 g=abs(f-.5-o*.5);float d=min(.5-g.x,.5-g.y);
      col=vec3(.07,.055,.045)*(.80+.40*lgNoise(uv*.8));
      col=mix(col,vec3(.24,.21,.19),lgLine(d*4.0,.22,pixel*.6)*.5);
      col+=vec3(.10,.08,.06)*smoothstep(.6,.9,lgNoise(uv*.12))*.6;
      col+=vec3(.05)*graze;
    } else if (m<177.5) {
      // office carpet tiles, the pile turned on alternate tiles
      vec2 q=pos.xz/24.0;vec2 ci=floor(q),f=fract(q);
      bool turn=mod(ci.x+ci.y,2.0)>.5;
      float rib=.5+.5*sin((turn?f.x:f.y)*24.0*3.1);
      col=mix(vec3(.28,.31,.38),vec3(.34,.38,.46),lgHash(ci+vec2(2.0,2.0))*.5+.25);
      col*=.94+.08*rib*fineR+.06*lgNoise(pos.xz*.6)*fineR;
      vec2 e=min(f,1.0-f)*24.0;
      col=mix(col,col*.72,lgLine(min(e.x,e.y),.25,pixel));
      if (topFace<.5) col=vec3(.30,.33,.40);
    } else if (m>180.5) {
      if (m<181.5) {
        // tread plate: 48-unit sheets, raised bars in a herringbone, grime
        // in the low ground, the bars' tops worn bright where feet go
        vec2 q=uv/48.0;vec2 ci=floor(q),f=fract(q);vec2 e=min(f,1.0-f)*48.0;float d=min(e.x,e.y);
        col=vec3(.30,.32,.34)*(.88+.14*lgNoise(uv*.04+ci*2.3));
        vec2 g=uv/5.0;vec2 gi=floor(g);vec2 gf=fract(g)-.5;
        float sg=mod(gi.x+gi.y,2.0)>.5?1.0:-1.0;
        vec2 r=vec2(gf.x+sg*gf.y,gf.y-sg*gf.x)*.7071;
        float bd=length(vec2(max(abs(r.x)-.22,0.0),r.y));
        float bar=1.0-smoothstep(.06,.10+pixel*.12,bd);
        col=mix(col,vec3(.50,.52,.55)+vec3(.12)*graze,bar*medR*topFace);
        col*=1.0-.22*smoothstep(.55,.85,lgNoise(uv*.025+vec2(7.0,3.0)));
        col+=vec3(.08,.05,.02)*smoothstep(.7,.95,lgNoise(uv*.07+vec2(1.0,9.0)));
        col=mix(col,vec3(.10,.10,.11),lgLine(d,.35,pixel)*.9);
        vec2 rv=abs(fract(uv/12.0)-.5)*12.0;
        float riv=(1.0-smoothstep(.45,.75+pixel*.3,length(vec2(min(e.x,e.y)-2.0,rv.x*step(e.y,e.x)+rv.y*step(e.x,e.y)))));
        col=mix(col,vec3(.55,.56,.58),riv*medR);
        col+=vec3(.10,.10,.11)*graze;
      } else if (m<182.5) {
        // hazard stripes, yellow and black at forty-five degrees, scuffed
        float s=fract((pos.x+pos.z+pos.y)/9.0);
        float edge=lgLine(min(abs(s-.5),min(s,1.0-s))*9.0,.4,pixel);
        col=s<.5?vec3(.88,.66,.08):vec3(.07,.07,.07);
        col=mix(col,vec3(.42,.40,.36),smoothstep(.6,.9,lgNoise(uv*.3))*.5*fineR);
        col=mix(col,col*.8,edge*.3);
        col+=vec3(.08)*graze;
      } else if (m<183.5) {
        // painted block: 16 by 8 courses, a utility grey-green gone dull,
        // rust and grime streaked down from the joints
        vec2 q=uv/vec2(16.0,8.0);float row=floor(q.y);q.x+=mod(row,2.0)*.5;
        vec2 f=fract(q);vec2 e=min(f,1.0-f)*vec2(16.0,8.0);float d=min(e.x,e.y);
        col=mix(vec3(.50,.56,.52),vec3(.58,.64,.60),lgHash(floor(q)+vec2(3.0,8.0))*.5+.25*lgNoise(uv*.05));
        col*=.94+.08*lgNoise(uv*.9)*fineR;
        float streak=smoothstep(.55,.95,lgNoise(vec2(uv.x*.35,uv.y*.02)))*(1.0-topFace);
        col=mix(col,vec3(.30,.26,.20),streak*.45);
        col=mix(col,vec3(.36,.40,.37),lgLine(d,.35,pixel)*.8);
        col+=vec3(.08)*graze;
        if (topFace>.5) col=vec3(.40,.44,.41)*(.9+.1*lgNoise(uv*.2));
      } else if (m<184.5) {
        // TEST175: neon and bulbs (self-lit; vShade picks the colour)
        float v=vShade;
        col=v<1.5?vec3(1.0,.16,.20):v<2.5?vec3(1.0,.70,.26):v<3.5?vec3(.30,.95,1.0):v<4.5?vec3(1.0,.90,.70)
           :v<5.5?vec3(.78,.42,1.0):v<6.5?vec3(.42,1.0,.52):v<7.5?vec3(1.0,.45,.78):vec3(.40,.58,1.0);
        col*=.92+.08*sin(casinoPhase*2.0+pos.x*.11+pos.z*.07);
      } else if (m<185.5) {
        // TEST175: the lair's floor: black graphite tiles, a fine grout,
        // red inlay lines on a 64-unit grid, a hard polish
        vec2 q=pos.xz/16.0;vec2 f=fract(q);vec2 e=min(f,1.0-f)*16.0;float d=min(e.x,e.y);
        col=mix(vec3(.075,.078,.088),vec3(.13,.13,.15),lgHash(floor(q)+vec2(6.0,2.0))*.6+.2*lgNoise(pos.xz*.05));
        col=mix(col,vec3(.20,.20,.23),lgLine(d,.22,pixel)*.8);
        vec2 r=abs(fract(pos.xz/64.0+.5)-.5)*64.0;
        col=mix(col,vec3(.62,.06,.08),lgLine(min(r.x,r.y),.45,pixel)*.85);
        col+=vec3(.16,.15,.18)*graze;
        col+=vec3(.06)*pow(.5+.5*sin(pos.x*.03+pos.z*.045+lgNoise(pos.xz*.01)*2.0),16.0);
        if (topFace<.5) col=vec3(.10,.10,.12);
      } else {
        // TEST175: gunmetal panelling: 24-unit panels, a seam a third up,
        // rivets along the seams, a brushed sheen
        vec2 q=uv/vec2(24.0,18.0);vec2 f=fract(q);vec2 e=min(f,1.0-f)*vec2(24.0,18.0);float d=min(e.x,e.y);
        col=mix(vec3(.17,.18,.21),vec3(.24,.25,.29),lgHash(floor(q)+vec2(9.0,4.0))*.5+.25);
        col*=.94+.08*lgNoise(vec2(uv.x*.15,uv.y*3.0))*fineR;
        col=mix(col,vec3(.06,.06,.07),lgLine(d,.30,pixel)*.9);
        vec2 rv=abs(fract(uv/4.0)-.5)*4.0;
        float riv=(1.0-smoothstep(.35,.6+pixel*.3,length(vec2(min(e.x,e.y)-1.6,(e.x<e.y?rv.y:rv.x)))));
        col=mix(col,vec3(.42,.43,.47),riv*medR);
        col+=vec3(.12,.12,.14)*graze;
        if (topFace>.5) col=vec3(.12,.12,.14)*(.9+.1*lgNoise(uv*.2));
      }
    } else if (m>178.5) {
      // polished granite (179 grey, 180 black): fine speckle, a polish
      bool dk=m>179.5;
      vec2 q=uv*2.4;
      float s1=lgHash(floor(q)),s2=lgHash(floor(q*1.7)+vec2(3.0,1.0));
      col=dk?vec3(.10,.10,.12):vec3(.50,.50,.54);
      col*=.92+.12*lgNoise(uv*.3);
      col=mix(col,dk?vec3(.30,.30,.34):vec3(.20,.20,.22),step(.80,s1)*fineR*.8);
      col=mix(col,dk?vec3(.02,.02,.03):vec3(.78,.78,.80),step(.86,s2)*fineR*.7);
      col+=(dk?vec3(.20,.20,.24):vec3(.18,.18,.20))*graze;
      col+=vec3(.05)*pow(.5+.5*sin(uv.x*.08+uv.y*.05),14.0);
    } else {
      // rusted iron: blotched rust over dark metal, a little pitting
      float n=lgFbm(uv*.35)+.35*lgNoise(uv*2.2);
      col=mix(vec3(.16,.12,.11),vec3(.46,.24,.12),smoothstep(.35,.85,n));
      col=mix(col,vec3(.62,.36,.16),smoothstep(.75,.95,lgNoise(uv*.9))*.6);
      col*=1.0-.25*step(.94,lgHash(floor(uv*3.0)))*fineR;
      col+=vec3(.08,.06,.05)*graze;
    }
    return col;
  }
  // TEST176: THE ROUTES' OWN GROUND (ReferenceMaterials rt*, shader
  // materials 187..197), THEIR GRASS (tg*, 198..215, see routeTint) and THE
  // CAVE MOUTHS' NATURAL ROCK (rk*, 216..222). World-space, derivative
  // filtered, no atlas: each route's path reads as its own country.
  // A scattered stone field, one stone per cell at a jittered spot:
  // x = coverage, y = the stone's own hash, z = the shadow ring around it.
  // TEST190: the routes' noise from a texture (RouteNoise.lua): one
  // bilinear read at the smoothed lattice position is the same blend
  // lgNoise does from four arithmetic hashes. Only the route finishes
  // (rtPebble, rtCrack, routeSurface, routeTint) use these.
  uniform Image routeNoise;
  uniform float routeNoiseReady;
  float rtHash(vec2 i) { if (routeNoiseReady < .5) return lgHash(i); return Texel(routeNoise,(i+.5)*(1.0/1024.0)).r; }
  float rtNoise(vec2 p) {
    if (routeNoiseReady < .5) return lgNoise(p);
    vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
    return Texel(routeNoise,(i+.5+f)*(1.0/1024.0)).r;
  }
  float rtFbm(vec2 p) {
    return .50*rtNoise(p)+.30*rtNoise(p*2.03+vec2(7.1,1.3))+.20*rtNoise(p*4.11+vec2(3.7,9.2));
  }
  vec3 rtPebble(vec2 p,float cell,float dens,float rad,float pixel) {
    vec2 q=p/cell;vec2 ci=floor(q);vec2 f=q-ci;
    float h=rtHash(ci+vec2(17.0,3.0));
    vec2 c=.30+.40*vec2(rtHash(ci+vec2(5.0,11.0)),rtHash(ci+vec2(2.0,7.0)));
    float r=rad*(.55+.45*rtHash(ci+vec2(9.0,1.0)));
    vec2 d=(f-c)*cell;float a=h*6.2832;
    d=vec2(d.x*cos(a)-d.y*sin(a),d.x*sin(a)+d.y*cos(a));
    float e=length(d*vec2(1.0,1.20+.55*h));
    float aa=max(pixel*.8,.02);
    float on=step(rtHash(ci+vec2(3.0,19.0)),dens);
    float cov=on*(1.0-smoothstep(r-aa,r+aa,e));
    float rim=on*(1.0-smoothstep(r,r*1.5+aa,e))*(1.0-cov);
    return vec3(cov,h,rim);
  }
  // hairline cracks along the ridges of a warped noise
  float rtCrack(vec2 p,float s,float w,float pixel) {
    float v=abs(rtNoise(p*s+vec2(rtNoise(p*s*.47+vec2(3.0,8.0))*1.7))-.5);
    // only in patches, and broken along their length: short hairlines,
    // not long contours
    float patchy=smoothstep(.52,.72,rtNoise(p*s*.35+vec2(11.0,5.0)))*smoothstep(.30,.55,rtNoise(p*s*2.3+vec2(7.0,1.0)));
    return lgLine(v/(s*2.2),w,pixel)*patchy;
  }
  vec3 routeSurface(float m,vec3 pos,vec2 uv,float topFace,float pixel,float fineR,float medR,float graze) {
    vec2 p=pos.xz;
    float big=rtFbm(p*.045),mid=rtNoise(p*.21),grit=rtNoise(p*2.3)-.5;
    vec3 col=vec3(.5);
    if (m<187.5) {
      // 187 the country lane (Routes 1, 22): packed tan earth, damp
      // hollows, grit and small stones trodden in, the odd hairline crack
      col=mix(vec3(.55,.44,.30),vec3(.67,.56,.40),big);
      col=mix(col,vec3(.43,.34,.24),smoothstep(.60,.82,rtFbm(p*.028+vec2(4.0,9.0)))*.7);
      col*=.94+.10*mid+.10*grit*fineR;
      vec3 pb=rtPebble(p,2.3,.42,.34,pixel);
      col=mix(col,col*.72,pb.z*.6*medR);
      col=mix(col,mix(vec3(.60,.57,.52),vec3(.74,.68,.58),pb.y)*(.92+.10*grit),pb.x*medR);
      col=mix(col,col*.70,rtCrack(p,.16,.05,pixel)*.5*medR);
      col+=vec3(.05,.04,.03)*graze;
      if (topFace<.5) col=mix(vec3(.40,.32,.23),vec3(.50,.40,.28),mid)*(.9+.2*grit*fineR);
    } else if (m<188.5) {
      // 188 the forest track (Route 2): dark loam under fallen leaves
      col=mix(vec3(.20,.14,.09),vec3(.31,.23,.15),big)*(.92+.14*mid+.12*grit*fineR);
      for (int k=0;k<2;k++) {
        float cs=k==0?1.5:1.1;vec2 o=k==0?vec2(0.0):vec2(.37,.71);
        vec2 q=(p+o*cs)/cs;vec2 ci=floor(q);vec2 f=q-ci-.5;
        float h=rtHash(ci+vec2(float(k)*7.0+1.0,3.0));
        float a=h*6.2832;vec2 d=vec2(f.x*cos(a)-f.y*sin(a),f.x*sin(a)+f.y*cos(a))*cs;
        float len=.40+.24*rtHash(ci+vec2(2.0,9.0+float(k)));
        float e=length(vec2(d.x/len,d.y/(len*.42)));
        float on=step(rtHash(ci+vec2(8.0,float(k)+4.0)),k==0?.46:.30);
        float leaf=on*(1.0-smoothstep(.86,1.0+pixel/len,e));
        vec3 lc=h<.3?vec3(.50,.31,.14):h<.55?vec3(.60,.48,.22):h<.8?vec3(.38,.25,.15):vec3(.33,.38,.17);
        lc*=.85+.30*rtHash(ci+vec2(4.0,4.0));
        lc*=1.0-.25*lgLine(abs(d.y),.03,pixel)*step(abs(d.x),len*.85);
        col=mix(col,lc,leaf*medR*.95);
      }
      // twigs and moss specks
      col=mix(col,vec3(.16,.11,.07),lgLine(abs(rtNoise(p*vec2(.9,.25)+vec2(1.0,6.0))-.5),.02,pixel*.4)*.6*fineR);
      col=mix(col,vec3(.30,.40,.16),step(.97,rtHash(floor(p*2.4)))*.5*fineR);
      col=mix(vec3(.30,.21,.13)*(.9+.2*big),col,medR);
      col+=vec3(.04,.03,.02)*graze;
      if (topFace<.5) col=vec3(.27,.19,.12)*(.85+.25*rtNoise(vec2(uv.x*4.0,uv.y*.3)));
    } else if (m<189.5) {
      // 189 scree (Route 3): grey gravel, a few larger stones, lichen
      col=vec3(.30,.29,.28);
      vec3 g1=rtPebble(p,.95,.95,.42,pixel);
      vec3 g2=rtPebble(p+vec2(.47,.31),.95,.80,.36,pixel);
      vec3 c1=mix(vec3(.52,.51,.49),vec3(.66,.63,.58),g1.y);c1=mix(c1,vec3(.46,.49,.54),step(.75,g1.y));
      vec3 c2=mix(vec3(.58,.56,.52),vec3(.70,.68,.64),g2.y);
      col=mix(col,c2,g2.x);col=mix(col,c1,g1.x);
      col=mix(vec3(.53,.52,.49)*(.9+.2*big),col,fineR);
      vec3 st=rtPebble(p,3.4,.22,.75,pixel);
      col=mix(col,col*.62,st.z*medR);col=mix(col,vec3(.60,.59,.56)*(.85+.3*st.y),st.x*medR);
      col*=.94+.12*big;
      col+=vec3(.06)*graze;
      if (topFace<.5) {
        col=mix(vec3(.44,.44,.43),vec3(.58,.57,.54),rtFbm(uv*.35));
        col=mix(col,vec3(.66,.68,.48),smoothstep(.70,.85,rtNoise(uv*.9+vec2(3.0,1.0)))*.6);
        col*=1.0-.2*rtCrack(uv,.3,.04,pixel);
      }
    } else if (m<190.5) {
      // 190 red mountain earth (Route 4): ochre-red, dusty, stony, cracked
      col=mix(vec3(.56,.34,.24),vec3(.69,.46,.33),big);
      col=mix(col,vec3(.74,.58,.44),smoothstep(.55,.85,rtFbm(p*.06+vec2(7.0,2.0)))*.5);
      col*=.93+.10*mid+.12*grit*fineR;
      vec3 pb=rtPebble(p,1.9,.45,.30,pixel);
      col=mix(col,col*.70,pb.z*.6*medR);
      col=mix(col,mix(vec3(.78,.66,.52),vec3(.50,.30,.22),pb.y),pb.x*medR);
      col=mix(col,col*.62,rtCrack(p,.22,.05,pixel)*.6*medR);
      col+=vec3(.06,.03,.02)*graze;
      if (topFace<.5) {
        float s=pos.y*1.4+rtNoise(uv*.2)*2.0;
        col=mix(vec3(.50,.27,.17),vec3(.66,.40,.26),.5+.5*sin(s))*(.9+.15*rtNoise(uv*.8));
      }
    } else if (m<191.5) {
      // 191 sandstone flags (Routes 5-8, 16): the slabs are geometry; the
      // stone is warm, mottled, faintly bedded, with the odd iron spot
      col=mix(vec3(.70,.60,.45),vec3(.80,.70,.54),big);
      col*=.93+.10*rtNoise(p*.6)+.08*grit*fineR;
      col=mix(col,col*vec3(.92,.86,.80),smoothstep(.4,1.0,sin(p.x*.9+rtNoise(p*.3)*3.0))*.25*medR);
      col=mix(col,vec3(.55,.38,.24),step(.985,rtHash(floor(p*2.0)))*.5*fineR);
      col+=vec3(.08,.07,.05)*graze;
      if (topFace<.5) col*=.86;
    } else if (m<192.5) {
      // 192 crushed slate (Routes 9, 10): blue-grey flakes in a paler grit,
      // tones shifting flake to flake, a sheen at a low angle
      col=vec3(.36,.38,.42);
      vec2 q=p*vec2(1.25,.85);vec2 ci=floor(q);vec2 f=fract(q)-.5;
      float h=rtHash(ci+vec2(3.0,8.0));
      float dm=abs(f.x+f.y*(h-.5))+abs(f.y-f.x*(h-.5)*.6);
      float fl=1.0-smoothstep(.33,.40+pixel*1.2,dm);
      vec3 fc=mix(vec3(.40,.44,.50),vec3(.56,.59,.64),h);fc=mix(fc,vec3(.50,.47,.52),step(.82,h));
      fc=mix(fc,vec3(.32,.36,.42),step(h,.18));
      col=mix(col,fc,fl*(.55+.45*fineR));
      col=mix(col,col*.80,(1.0-fl)*fineR*.5);
      col*=.90+.18*big+.06*rtNoise(p*.6);
      col+=vec3(.12,.13,.16)*graze;
      if (topFace<.5) {
        col=mix(vec3(.26,.28,.33),vec3(.37,.40,.45),.5+.5*sin(pos.y*3.1+rtNoise(uv*.3)*2.0));
        col+=vec3(.10,.11,.13)*graze;
      }
    } else if (m<193.5) {
      // 193 beach sand (Routes 13, 18-21): wind ripples, shell flecks
      col=mix(vec3(.78,.70,.52),vec3(.88,.81,.63),big);
      float rip=sin(dot(p,vec2(.86,.50))*1.35+rtNoise(p*.12)*5.0+rtNoise(p*.5)*1.2);
      col*=1.0+.06*rip*medR;
      col*=.95+.08*grit*fineR+.05*mid;
      vec3 sh=rtPebble(p,1.3,.20,.12,pixel);
      col=mix(col,mix(vec3(.97,.94,.89),vec3(.93,.77,.73),step(.6,sh.y)),sh.x*fineR*.9);
      col=mix(col,vec3(.66,.58,.42),smoothstep(.70,.86,rtFbm(p*.05+vec2(2.0,5.0)))*.35);
      col+=vec3(.08,.07,.05)*graze;
      if (topFace<.5) col*=.82;
    } else if (m<195.5) {
      // 194/195 the boardwalk (Route 12): sea-weathered planks gone silver,
      // brown where the weather has not reached; grain along x (194) or z
      vec2 g=m<194.5?p:p.yx;
      if (topFace<.5) g=uv;
      float fib=rtNoise(vec2(g.x*.12,g.y*7.0));
      col=mix(vec3(.50,.48,.44),vec3(.66,.63,.57),fib*.7+.3*rtNoise(vec2(g.x*.03,g.y*.8)));
      col=mix(col,col*vec3(.86,.76,.64),smoothstep(.55,.85,rtNoise(vec2(g.x*.05,g.y*.5)+vec2(3.0,1.0))));
      col*=1.0-.22*lgLine(abs(fract(g.y*1.3+rtNoise(vec2(g.x*.08,g.y))*.6)-.5),.04,pixel*1.3)*medR;
      col*=1.0-.30*lgLine(abs(rtNoise(vec2(g.x*.05,g.y*3.0)+vec2(9.0,2.0))-.5),.015,pixel*.2)*fineR;
      col+=vec3(.10,.10,.11)*graze;
    } else if (m<196.5) {
      // 196 the prairie track (Routes 14, 15): dry dust over cracked
      // hardpan, straw strands; standing tufts are straw
      col=mix(vec3(.70,.60,.40),vec3(.80,.70,.48),big);
      col*=.94+.08*mid+.10*grit*fineR;
      col=mix(col,col*.70,rtCrack(p,.30,.05,pixel)*.55*medR);
      col=mix(col,col*.72,rtCrack(p+vec2(13.0,7.0),.55,.035,pixel)*.35*fineR);
      col=mix(col,vec3(.86,.76,.46),smoothstep(.78,.92,rtNoise(vec2(p.x*2.0+p.y*.4,p.y*.25)))*.5*fineR);
      col+=vec3(.06,.05,.03)*graze;
      if (topFace<.5) col=mix(vec3(.62,.54,.30),vec3(.88,.78,.46),rtNoise(uv*vec2(.6,2.2)));
    } else {
      // 197 crushed shell (Routes 24, 25): pale fragments, a nacre glint
      col=mix(vec3(.70,.68,.62),vec3(.80,.78,.72),big);
      vec3 s1=rtPebble(p,.7,.85,.26,pixel);
      vec3 sc=s1.y<.3?vec3(.88,.86,.82):s1.y<.55?vec3(.84,.74,.70):s1.y<.8?vec3(.70,.72,.75):vec3(.80,.76,.62);
      col=mix(col,col*.80,s1.z*.6);
      col=mix(col,sc,s1.x);
      col=mix(vec3(.76,.74,.69)*(.94+.10*big),col,fineR);
      col*=.96+.06*mid;
      col+=vec3(.10)*graze;
      col+=vec3(.25)*step(.996,rtHash(floor(p*6.0)))*fineR*(.5+.5*sin(dot(pos-eye,vec3(.9,.3,.7))*.5));
    }
    return col;
  }
  // The cave mouths' rock, one geology per cave (216..222).
  vec3 caveRockSurface(float m,vec3 pos,vec2 uv,float topFace,float pixel,float fineR,float medR,float graze) {
    vec3 col=vec3(.5);
    vec3 vd=normalize(pos-eye);
    if (m<216.5) {
      // 216 Mt. Moon: speckled grey granite, rain streaks, moonstone glints
      col=mix(vec3(.42,.42,.45),vec3(.57,.57,.59),lgFbm(uv*.12));
      col*=.92+.10*lgNoise(uv*.5);
      float s1=lgHash(floor(uv*2.6)),s2=lgHash(floor(uv*2.1)+vec2(3.0,7.0));
      col=mix(col,vec3(.18,.18,.20),step(.84,s1)*fineR*.8);
      col=mix(col,vec3(.80,.80,.82),step(.88,s2)*fineR*.6);
      col*=1.0-.14*smoothstep(.5,.9,lgNoise(vec2(uv.x*.4,pos.y*.04)))*(1.0-topFace);
      float gl=step(.992,lgHash(floor(pos.xz*1.7+pos.y*1.3)));
      float tw=pow(max(0.0,sin(dot(vd,vec3(13.1,7.7,9.3))+lgHash(floor(pos.xz*1.7))*6.28)),6.0);
      col+=vec3(.55,.70,1.0)*gl*tw*fineR*.9;
      col+=vec3(.06,.06,.08)*graze;
    } else if (m<217.5) {
      // 217 Rock Tunnel: red sandstone in strata, a pale band here and there
      float y=pos.y+lgNoise(pos.xz*.06)*3.0+lgNoise(uv*.25)*.6;
      float band=fract(y/2.6);float bi=floor(y/2.6);
      float hb=lgHash(vec2(bi,4.0));
      vec3 c0=hb<.25?vec3(.56,.28,.18):hb<.5?vec3(.68,.40,.25):hb<.8?vec3(.62,.34,.21):vec3(.80,.64,.46);
      col=c0*(.90+.14*lgNoise(uv*.6)+.08*(lgNoise(uv*3.0)-.5)*fineR);
      col=mix(col,col*.62,lgLine(min(band,1.0-band)*2.6,.12,pixel)*.7*(1.0-topFace));
      if (topFace>.5) col=mix(vec3(.60,.33,.21),vec3(.72,.46,.30),lgFbm(pos.xz*.15))*(.92+.10*lgNoise(pos.xz*2.0)*fineR);
      col+=vec3(.08,.04,.03)*graze;
    } else if (m<218.5) {
      // 218 Cerulean Cave: wet blue-black slate, cyan veins, a sheen
      float y=pos.y+lgNoise(uv*.08)*4.0;
      col=mix(vec3(.13,.16,.25),vec3(.24,.30,.42),lgFbm(uv*.10));
      col*=.90+.16*(.5+.5*sin(y*2.2))*(1.0-topFace)+.08*lgNoise(uv*1.4)*fineR;
      col=mix(col,vec3(.35,.85,.95),lgVein(uv,.08,.06,pixel)*.55*medR);
      col+=vec3(.20,.28,.40)*graze*1.4;
      col+=vec3(.10,.14,.20)*pow(.5+.5*sin(uv.x*.15+uv.y*.21+lgNoise(uv*.04)*3.0),12.0);
    } else if (m<219.5) {
      // 219 Seafoam: frosted ice-rock, blue in its cracks, sparkling
      col=mix(vec3(.58,.72,.84),vec3(.82,.90,.96),lgFbm(uv*.09));
      col=mix(col,vec3(.25,.45,.68),rtCrack(uv,.14,.08,pixel)*.7*medR);
      col=mix(col,vec3(.34,.56,.78),smoothstep(.55,.85,lgNoise(uv*.05+vec2(5.0,1.0)))*.35);
      col=mix(col,vec3(.93,.96,1.0),topFace*.6);
      float sp=step(.985,lgHash(floor(pos.xz*2.3+pos.y*1.7)))
        *pow(max(0.0,sin(dot(vd,vec3(11.0,5.0,8.0))+lgHash(floor(pos.xz*2.3))*6.28)),8.0);
      col+=vec3(.60,.75,.90)*sp*fineR;
      col+=vec3(.25,.32,.40)*graze*1.2;
    } else if (m<220.5) {
      // 220 Diglett's Cave: banded clay and earth, stones, root threads
      float y=pos.y+lgNoise(uv*.1)*2.5;
      col=mix(vec3(.42,.30,.18),vec3(.58,.44,.28),lgFbm(uv*.12));
      col=mix(col,vec3(.66,.52,.34),smoothstep(.3,.9,sin(y*1.1))*.25*(1.0-topFace));
      vec3 pb=rtPebble(uv,1.8,.35,.32,pixel);
      col=mix(col,col*.70,pb.z*.5*medR);col=mix(col,vec3(.60,.56,.50)*(.8+.3*pb.y),pb.x*medR);
      col=mix(col,vec3(.22,.15,.09),lgLine(abs(lgNoise(uv*vec2(.3,.08))-.5),.03,pixel*.3)*.6*medR);
      col+=vec3(.06,.05,.03)*graze;
    } else if (m<221.5) {
      // 221 moss cushions on the rock
      col=mix(vec3(.20,.32,.12),vec3(.34,.48,.18),lgFbm(pos.xz*.3+pos.y*.2));
      col*=.85+.30*lgNoise(pos.xz*2.6+pos.y)*fineR;
      col+=vec3(.20,.24,.08)*step(.93,lgHash(floor(pos.xz*3.3+pos.y*2.0)))*fineR;
      col+=vec3(.08,.10,.04)*graze;
    } else {
      // 222 crystal and glowing fungus (self-lit; vShade picks the colour:
      // 1 cyan, 2 magenta, 3 moonstone, 4 ice, 5 amber, 6 violet, 7 green,
      // 8 gold)
      float v=vShade;
      vec3 c=v<1.5?vec3(.35,.95,1.0):v<2.5?vec3(1.0,.42,.92):v<3.5?vec3(.80,.88,1.0):v<4.5?vec3(.55,.80,1.0)
        :v<5.5?vec3(1.0,.70,.30):v<6.5?vec3(.72,.48,1.0):v<7.5?vec3(.55,1.0,.45):vec3(1.0,.85,.40);
      col=c*(.55+.35*lgNoise(uv*.7))+mix(c,vec3(1.0),.6)*graze*1.2;
      col*=.90+.10*sin(casinoPhase*1.3+pos.y*.4+pos.x*.2);
    }
    return col;
  }
  // TEST176: the routes' grass. The atlas turf and tall-grass texels are
  // re-coloured per route (198..215: a lawn id and a blade id per biome).
  // A gain on the texel keeps its art; a slow world field mixes two moods
  // of the same country; lawns (never blades) carry its wild flowers.
  vec3 routeTint(float m,vec3 pos,vec3 c) {
    float k=m-198.0;float biome=floor(k*.5+.01);float blade=k-biome*2.0;
    vec2 p=pos.xz;
    float pixel=max(length(dFdx(p)),length(dFdy(p)));
    vec3 nr=abs(refNormal);
    float top=step(max(nr.x,nr.z),nr.y)*(1.0-step(.5,blade));
    // (TEST182: two octaves, not three -- the lawn is most of a route's
    // pixels, and the third octave was below the texel anyway)
    float f=.62*rtNoise(p*.018)+.38*rtNoise(p*.0365+vec2(7.1,1.3)),n=rtNoise(p*.07);
    vec3 gA=vec3(1.0),gB=vec3(1.0),f1=vec3(1.0),f2=vec3(1.0);float fd=0.0;
    if (biome<.5) {        // meadow (Route 1): spring green, dandelions, daisies
      gA=vec3(1.10,1.08,.86);gB=vec3(1.24,1.10,.78);f1=vec3(1.0,.86,.20);f2=vec3(.97,.97,.92);fd=.10;
    } else if (biome<1.5) { // lush (Route 2): deep emerald, clover
      gA=vec3(.80,.98,.98);gB=vec3(.70,.90,.92);f1=vec3(.96,.96,.98);f2=vec3(.86,.62,.88);fd=.05;
    } else if (biome<2.5) { // dry upland (Routes 3, 4): olive and straw
      gA=vec3(1.30,1.06,.70);gB=vec3(1.75,1.15,.66);f1=vec3(.95,.80,.30);f2=vec3(.80,.55,.85);fd=.03;
    } else if (biome<3.5) { // park (Routes 5-8, 16): rich even green, mown
      gA=vec3(.92,1.06,.90);gB=vec3(.86,1.00,.86);
    } else if (biome<4.5) { // highland (Route 9): cool green and heather
      gA=vec3(.90,.96,1.06);gB=vec3(1.30,.78,1.45);f1=vec3(.82,.48,.80);f2=vec3(.92,.70,.92);fd=.14;
    } else if (biome<5.5) { // coast (12, 13, 18-21): pale salt grass, sand
      gA=vec3(1.05,1.05,1.00);gB=vec3(1.30,1.16,.92);f1=vec3(.95,.92,.98);f2=vec3(.95,.80,.55);fd=.04;
    } else if (biome<6.5) { // prairie (14, 15): golden green
      gA=vec3(1.18,1.06,.76);gB=vec3(1.45,1.14,.66);f1=vec3(.98,.60,.25);f2=vec3(.95,.85,.40);fd=.05;
    } else if (biome<7.5) { // cape (24, 25): bright fresh green, white clover
      gA=vec3(1.06,1.14,.92);gB=vec3(.96,1.12,.98);f1=vec3(.98,.98,.96);f2=vec3(.62,.72,1.0);fd=.12;
    } else {                // wild (22): dark and unkempt, dead patches
      gA=vec3(.82,.90,.84);gB=vec3(1.30,1.00,.70);f1=vec3(.88,.30,.30);f2=vec3(.95,.90,.60);fd=.03;
    }
    vec3 col=c*mix(gA,gB,smoothstep(.35,.75,f+.25*(n-.5)));
    if (biome>2.5 && biome<3.5) col*=1.0+.07*clamp(sin(p.y*.3927)*4.0,-1.0,1.0)*(1.0-blade);
    if (biome>4.5 && biome<5.5) col=mix(col,vec3(.80,.72,.54)*(.9+.2*n),smoothstep(.62,.78,rtFbm(p*.035+vec2(9.0,2.0)))*.75*top);
    if (biome>1.5 && biome<2.5) col=mix(col,vec3(.56,.46,.31)*(.9+.2*n),smoothstep(.66,.80,rtFbm(p*.04+vec2(1.0,6.0)))*.65*top);
    if (fd>0.0 && top>.5 && pixel<.35) {
      vec2 q=p/1.7;vec2 ci=floor(q);vec2 fq=q-ci;
      float h=rtHash(ci+vec2(31.0,7.0));
      float dens=fd*(.3+1.7*smoothstep(.3,.8,rtNoise(p*.04+vec2(2.0,8.0))));
      // (TEST182: only a cell that holds a flower does the rest)
      if (h<dens) {
        vec2 cc=.25+.5*vec2(rtHash(ci+vec2(3.0,1.0)),rtHash(ci+vec2(6.0,5.0)));
        float d=length((fq-cc)*1.7);
        float r=.20+.10*rtHash(ci+vec2(1.0,9.0));
        float aa=max(pixel,.02);
        float on=1.0-smoothstep(r-aa,r+aa,d);
        vec3 fc=rtHash(ci+vec2(4.0,2.0))<.6?f1:f2;
        fc=mix(fc,vec3(1.0,.90,.40),(1.0-smoothstep(0.0,r*.45,d))*.5);
        col=mix(col,fc*.95,on*(1.0-smoothstep(.12,.35,pixel)));
      }
    }
    return col;
  }
// TEST96: muted submerged mosaic. Small soft light patches belong on
// the bed; the water surface never carries a bright outlined web.
vec3 indoorPoolBed(vec2 q, float t) {
  vec2 cell=floor(q/4.0), f=fract(q/4.0);
  vec2 edge=min(f,1.0-f)*4.0;
  float pixel=max(max(fwidth(q.x),fwidth(q.y)),.025);
  float joint=(1.0-smoothstep(.045,.045+pixel,min(edge.x,edge.y)))
              *(1.0-smoothstep(.9,2.2,pixel));
  float tone=sin(dot(cell,vec2(1.73,2.41)))*.009;
  vec3 bed=vec3(.19,.38,.40)+vec3(tone);
  bed=mix(bed,vec3(.14,.27,.29),joint*.42);
  float light=sin(q.x*.31+q.y*.13+t*.35)*sin(q.y*.38-q.x*.17-t*.25);
  bed+=vec3(.009,.020,.019)*smoothstep(.25,.95,light);
  return bed;
}

  vec3 interiorSurface(float m,vec3 pos,vec2 uv,float topFace,float pixel,vec3 nrm) {
    float fineR=1.0-smoothstep(.05,.24,pixel);
    float medR=1.0-smoothstep(.45,2.0,pixel);
    vec3 vd=normalize(pos-eye);
    vec3 nU=nrm/max(length(nrm),1e-6);
    float graze=pow(clamp(1.0-abs(dot(vd,nU)),0.0,1.0),3.0);
    vec3 col=vec3(.5);
#ifdef LG_STRIP_ROOMS
    // TEST184 PERF PROBE only: the rooms' and dungeons' finishes compiled
    // out (the routes' ground and the cave mouths stay)
    if (m>215.5) return caveRockSurface(m,pos,uv,topFace,pixel,fineR,medR,graze);
    if (m>186.5) return routeSurface(m,pos,uv,topFace,pixel,fineR,medR,graze);
    return vec3(.55,.53,.50);
#endif
    if (m>222.5 && m<223.5) {
      // Matte acoustic panels: neutral cool white, no large sweeping veins.
      col=vec3(.84,.88,.90)+vec3((lgNoise(uv*1.8)-.5)*.012*fineR);
    } else if (m>223.5 && m<224.5) {
      col=indoorPoolBed(uv,casinoPhase);
    } else if (m<146.5) {
      if (m<143.5) col=inBoards(uv,pos,topFace,pixel,vec3(.46,.29,.14),vec3(.70,.49,.26),4.6,fineR,medR);
      else if (m<144.5) col=inBoards(uv,pos,topFace,pixel,vec3(.20,.11,.06),vec3(.36,.22,.12),4.6,fineR,medR);
      else if (m<145.5) col=inBoards(uv,pos,topFace,pixel,vec3(.66,.56,.42),vec3(.84,.76,.62),5.4,fineR,medR);
      else {
        // parquet: basket weave, three slats to a square, alternating
        vec2 q=pos.xz/9.0;vec2 ci=floor(q),cf=fract(q);
        bool along=mod(ci.x+ci.y,2.0)<.5;
        float a=along?cf.y:cf.x;float l=along?cf.x:cf.y;
        float si=floor(a*3.0);float sf=fract(a*3.0);
        float tone=lgHash(ci*3.0+vec2(si,si*1.7));
        col=mix(vec3(.38,.22,.10),vec3(.60,.39,.20),tone);
        col*=.90+.14*(.5+.5*sin(lgNoise(vec2(l*9.0,si+ci.x*3.0))*14.0+l*20.0))*medR;
        float j=max(lgLine(min(sf,1.0-sf)*3.0,.07,pixel),lgLine(min(min(cf.x,1.0-cf.x),min(cf.y,1.0-cf.y))*9.0,.10,pixel));
        col=mix(col,vec3(.14,.08,.04),j*.8);
        if (topFace<.5) col=inBoards(uv,pos,topFace,pixel,vec3(.30,.17,.08),vec3(.50,.32,.16),4.6,fineR,medR);
      }
      // a varnished floor gives back the room at a low angle
      col+=vec3(.10,.09,.08)*graze*topFace;
      col+=vec3(.05,.045,.04)*pow(.5+.5*sin(pos.x*.045+pos.z*.06+lgNoise(pos.xz*.02)*3.0),10.0)*topFace;
    } else if (m<151.5) {
      if (m<147.5) {
        // glazed white tile, 8 units, grey grout
        vec2 q=uv/8.0;vec2 f=fract(q);vec2 e=min(f,1.0-f)*8.0;float d=min(e.x,e.y);
        float h=lgHash(floor(q)+vec2(2.0,5.0));
        col=vec3(.90,.91,.92)*(.95+.07*h);
        col=mix(col,vec3(.60,.62,.64),lgLine(d,.22,pixel)*.9);
        col+=vec3(.14)*graze+vec3(.06)*pow(.5+.5*sin(uv.x*.07+uv.y*.05),12.0);
      } else if (m<148.5) {
        // black and white checker
        vec2 q=uv/8.0;vec2 f=fract(q);vec2 e=min(f,1.0-f)*8.0;float d=min(e.x,e.y);
        bool b=mod(floor(q.x)+floor(q.y),2.0)<.5;
        col=b?vec3(.10,.10,.12):vec3(.88,.87,.84);
        col*=.96+.06*lgNoise(uv*.4);
        col=mix(col,vec3(.42,.42,.42),lgLine(d,.12,pixel)*.6);
        col+=vec3(.12)*graze;
      } else if (m<149.5) {
        // terrazzo: chips in a warm ground, brass strips
        col=vec3(.80,.77,.71)*(.95+.08*lgNoise(uv*.05));
        vec2 q=uv*.55;vec2 ci=floor(q);vec2 cf=fract(q)-.5;
        float h=lgHash(ci+vec2(1.0,7.0));
        vec2 o=(vec2(lgHash(ci+vec2(3.0,3.0)),lgHash(ci+vec2(8.0,2.0)))-.5)*.5;
        float chip=1.0-smoothstep(.14,.22+pixel*.3,length(cf-o));
        vec3 cc=h<.35?vec3(.95,.94,.90):(h<.6?vec3(.42,.40,.38):(h<.8?vec3(.62,.36,.26):vec3(.20,.20,.22)));
        col=mix(col,cc,chip*step(.25,h)*fineR*.85+chip*step(.25,h)*(1.0-fineR)*.25);
        vec2 s=fract(uv/32.0);vec2 se=min(s,1.0-s)*32.0;
        col=mix(col,vec3(.78,.62,.30),lgLine(min(se.x,se.y),.18,pixel)*.85);
        col+=vec3(.12)*graze;
      } else if (m<150.5) {
        // tatami: mats 16 by 32, turned on alternate rows; straw weave and
        // a dark cloth border down the long edges
        vec2 q=pos.xz;float row=floor(q.y/16.0);
        bool turn=mod(row,2.0)>.5;
        vec2 l=turn?vec2(q.x+8.0,q.y):q;
        float mx=fract(l.x/32.0)*32.0,mz=fract(l.y/16.0)*16.0;
        col=vec3(.73,.69,.44)*(.92+.10*lgNoise(vec2(floor(l.x/32.0),row)*3.0));
        float weave=.5+.5*sin(mx*5.2);
        col*=.92+.10*weave*fineR;
        float edge=min(mz,16.0-mz);
        col=mix(col,vec3(.12,.16,.10),1.0-smoothstep(1.0,1.3+pixel,edge));
        col=mix(col,col*.7,lgLine(min(mx,32.0-mx),.12,pixel));
        if (topFace<.5) col=vec3(.73,.69,.44);
      } else {
        // flagstones
        vec2 dim=vec2(18.0,13.0);
        vec2 q=uv/dim;float row=floor(q.y);q.x+=mod(row,2.0)*.45+lgHash(vec2(row,4.0))*.3;
        vec2 ci=floor(q),f=fract(q);vec2 e=min(f,1.0-f)*dim;float d=min(e.x,e.y);
        float h=lgHash(ci+vec2(5.0,2.0));
        col=mix(vec3(.46,.44,.40),vec3(.62,.58,.52),h);
        col*=.88+.20*lgFbm(uv*.25+ci*2.0);
        col=mix(col,vec3(.22,.21,.20),lgLine(d,.35,pixel)*.85);
      }
    } else if (m<155.5) {
      vec3 c=m<152.5?vec3(.62,.12,.12):(m<153.5?vec3(.16,.27,.52):(m<154.5?vec3(.20,.40,.24):vec3(.76,.56,.20)));
      col=inPile(uv,fineR,c);
    } else if (m<158.5) {
      // wallpapers (uv.x runs along the wall)
      if (m<156.5) {
        col=vec3(.93,.87,.74)*(.97+.05*lgNoise(uv*.08));
        float sx=fract(uv.x/7.0)*7.0;
        float st=max(lgLine(abs(sx-1.2),.22,pixel),lgLine(abs(sx-2.1),.12,pixel));
        col=mix(col,vec3(.78,.47,.50),st*.75);
        vec2 sq=vec2(fract(uv.x/7.0)-.65,fract(uv.y/7.0+floor(uv.x/7.0)*.5)-.5)*7.0;
        float bud=1.0-smoothstep(.45,.70+pixel*.5,length(sq));
        float leaf=1.0-smoothstep(.30,.50+pixel*.5,length(sq-vec2(.6,-.7)));
        col=mix(col,vec3(.80,.35,.40),bud*.8*medR);
        col=mix(col,vec3(.42,.56,.36),leaf*.7*medR);
      } else if (m<157.5) {
        col=vec3(.56,.64,.52)*(.97+.05*lgNoise(uv*.08));
        vec2 dq=uv/vec2(9.0,12.0);dq.x+=mod(floor(dq.y),2.0)*.5;
        vec2 df=abs(fract(dq)-.5);
        float ogee=abs(df.x*1.4+df.y*df.y*1.6-.42);
        col=mix(col,vec3(.68,.75,.62),(1.0-smoothstep(.05,.10+pixel*.06,ogee))*.8*medR);
        float c=1.0-smoothstep(.06,.11+pixel*.06,length(df));
        col=mix(col,vec3(.72,.66,.40),c*.8*medR);
      } else {
        col=vec3(.40,.55,.72)*(.97+.05*lgNoise(uv*.08));
        float sx=fract(uv.x/10.0)*10.0;
        col=mix(col,vec3(.84,.89,.94),lgLine(abs(sx-5.0),.14,pixel)*.8);
        vec2 ad=abs((fract(uv/10.0)-.5)*10.0);
        float motif=max(1.0-smoothstep(.75,.95+pixel*.4,ad.x+ad.y*2.4),1.0-smoothstep(.75,.95+pixel*.4,ad.y+ad.x*2.4));
        col=mix(col,vec3(.92,.94,.96),motif*.85*medR);
      }
    } else if (m<159.5) {
      // interior brick, running bond, pale mortar
      vec2 dim=vec2(8.0,3.4);
      vec2 q=uv/dim;float row=floor(q.y);q.x+=mod(row,2.0)*.5;
      vec2 ci=floor(q),f=fract(q);vec2 e=min(f,1.0-f)*dim;float d=min(e.x,e.y);
      float h=lgHash(ci+vec2(9.0,1.0));
      col=mix(vec3(.46,.20,.13),vec3(.66,.34,.22),h);
      col=mix(col,vec3(.32,.14,.10),step(.85,lgHash(ci+vec2(2.0,6.0)))*.6);
      col*=.88+.20*lgNoise(uv*.9+ci*3.0);
      col=mix(col,vec3(.74,.70,.62),lgLine(d,.28,pixel)*.9);
      if (topFace>.5) col=vec3(.62,.30,.20);
    } else if (m<161.5) {
      // book spines (160) or shop goods (161) on shelves eight units apart:
      // each shelf's row stands from y=8k, tops ragged, the back dark
      float ly=mod(pos.y,8.0);
      float x=uv.x;
      if (topFace>.5) x=pos.x+pos.z;
      if (m<160.5) {
        float w=1.25;float bi=floor(x/w);float bf=fract(x/w);
        float h=lgHash(vec2(bi,floor(pos.y/8.0))+vec2(3.0,7.0));
        float top=4.6+h*2.4;
        float hue=lgHash(vec2(bi*1.7,floor(pos.y/8.0)+4.0));
        vec3 c=hue<.18?vec3(.55,.10,.10):(hue<.34?vec3(.12,.20,.42):(hue<.48?vec3(.14,.34,.20):(hue<.60?vec3(.46,.30,.16):(hue<.70?vec3(.86,.80,.64):(hue<.80?vec3(.36,.10,.22):(hue<.90?vec3(.12,.40,.42):vec3(.70,.52,.18)))))));
        col=c*(.82+.30*smoothstep(0.0,.5,bf)*(1.0-smoothstep(.55,1.0,bf)));
        float band=max(lgLine(abs(ly-1.4),.18,pixel),lgLine(abs(ly-(top-1.1)),.18,pixel));
        col=mix(col,vec3(.90,.72,.30),band*step(.4,h)*.8*medR);
        col=mix(col,c*.55,lgLine(min(bf,1.0-bf)*w,.06,pixel)*.8);
        if (ly>top||ly<.5||step(.94,lgHash(vec2(bi,9.0+floor(pos.y/8.0))))>.5) col=vec3(.08,.06,.05);
      } else {
        float w=3.2;float bi=floor(x/w);float bf=fract(x/w)*w;
        float row=floor(pos.y/8.0);
        float h=lgHash(vec2(bi,row)+vec2(5.0,1.0));
        float kind=lgHash(vec2(bi*.7,row+3.0));
        vec3 c=kind<.2?vec3(.80,.16,.16):(kind<.4?vec3(.20,.42,.80):(kind<.55?vec3(.95,.80,.20):(kind<.7?vec3(.30,.70,.36):(kind<.85?vec3(.60,.30,.70):vec3(.92,.92,.90)))));
        col=vec3(.10,.09,.09);
        if (h<.5) {
          // a carton with its label
          float top=4.2+h*3.0;
          if (ly<top&&bf>.25&&bf<w-.25) {
            col=c*(.92+.08*lgNoise(vec2(bi,ly)));
            float lab=step(top*.35,ly)*step(ly,top*.65)*step(.6,bf)*step(bf,w-.6);
            col=mix(col,vec3(.95,.95,.92),lab*medR);
          }
        } else {
          // two bottles with caps
          float bx=mod(bf,w*.5)-w*.25;float top=4.6+(h-.5)*3.0;
          float r=.62;
          float body=step(abs(bx),r)*step(ly,top-1.0);
          float neck=step(abs(bx),r*.42)*step(ly,top)*step(top-1.0,ly);
          float cap=neck*step(top-.5,ly);
          if (body+neck>.5) {
            col=c*(.70+.45*(1.0-abs(bx)/r));
            col=mix(col,vec3(.95,.92,.80),cap);
            col=mix(col,vec3(.95,.95,.92),step(top*.3,ly)*step(ly,top*.55)*body*.8*medR);
          }
        }
        if (ly<.4) col=vec3(.08,.07,.07);
      }
    } else if (m<165.5) {
      if (m<162.5) {
        col=vec3(.66,.07,.08)*(.92+.10*lgNoise(uv*.05));
        col+=vec3(.30,.16,.16)*pow(.5+.5*sin(uv.x*.11+uv.y*.23+lgNoise(uv*.03)*2.0),14.0);
        col+=vec3(.20,.12,.12)*graze;
      } else if (m<163.5) {
        col=vec3(.90,.90,.88)*(.97+.04*lgNoise(uv*.06));
        col+=vec3(.10)*pow(.5+.5*sin(uv.x*.09+uv.y*.19),16.0)+vec3(.10,.11,.12)*graze;
        col-=vec3(.06,.06,.05)*(1.0-topFace)*(1.0-smoothstep(0.0,6.0,pos.y));
      } else if (m<164.5) {
        col=vec3(.34,.19,.11)*(.90+.18*lgFbm(uv*.2));
        vec2 dq=uv/4.0;dq.x+=mod(floor(dq.y),2.0)*.5;
        vec2 df=fract(dq)-.5;
        float btn=1.0-smoothstep(.06,.12+pixel*.25,length(df));
        float crease=lgLine(abs(abs(df.x)+abs(df.y)-.5),.03,pixel*.25);
        col*=1.0-(1.0-topFace)*(btn*.45+crease*.25)*medR;
        col+=vec3(.10,.07,.05)*graze+vec3(.05,.035,.02)*pow(.5+.5*sin(uv.x*.2+uv.y*.3),10.0);
      } else {
        float b=.5+.5*sin(pos.y*.6+(pos.x+pos.z)*.21+lgNoise(uv*.05)*2.4);
        col=mix(vec3(.46,.49,.53),vec3(.80,.83,.87),b);
        col*=.95+.08*(lgNoise(vec2(uv.x*7.0,uv.y*.2))-.5)*fineR;
        col+=vec3(.08)*graze;
      }
    } else if (m>215.5) {
      // TEST176: the cave mouths' rock
      col=caveRockSurface(m,pos,uv,topFace,pixel,fineR,medR,graze);
    } else if (m>186.5) {
      // TEST176: the routes' ground
      col=routeSurface(m,pos,uv,topFace,pixel,fineR,medR,graze);
    } else if (m>171.5) {
      // TEST174: the dungeons
      col=dungeonSurface(m,pos,uv,topFace,pixel,fineR,medR,graze);
    } else {
      // the self-lit finishes
      float t=casinoPhase;
      if (m<166.5) {
        // a screen: scanlines, rows of text or a picture, a slow roll
        float v=vShade;
        vec2 s=uv;
        float scan=.88+.12*sin(s.y*9.0);
        if (v<1.5) {
          col=vec3(.06,.16,.22);
          float row=floor(s.y/1.3);float rx=fract(s.y/1.3);
          float len=lgHash(vec2(row,floor(t*2.0/6.2832)))*.8+.2;
          float txt=step(rx,.55)*step(.2,rx)*step(fract(s.x*.13+row*.37),len)*step(.3,lgHash(vec2(floor(s.x*1.6),row)));
          col=mix(col,vec3(.45,.95,.85),txt*.85);
        } else if (v<2.5) {
          float a=lgNoise(s*.25+vec2(sin(t)*1.5,cos(t)*1.2));
          col=mix(vec3(.15,.35,.80),vec3(.95,.60,.25),smoothstep(.3,.7,a));
          col=mix(col,vec3(.30,.75,.30),smoothstep(.55,.8,lgNoise(s*.4+vec2(5.0+cos(t)*.8,sin(t)*.8))));
        } else {
          col=vec3(.05,.20,.08)+vec3(.20,.80,.30)*lgLine(abs(fract(s.x*.25+s.y*.1)-.5),.05,pixel*.25);
          col+=vec3(.6,1.0,.6)*(1.0-smoothstep(.3,.6,length(fract(s*.1+vec2(t*0.15915494,0.0))-.5)))*.4;
        }
        col*=scan*(.94+.06*sin(t*7.0));
      } else if (m<167.5) {
        // a lit shade: warm, cool or rosy, brighter at its middle
        vec3 c=vShade<1.5?vec3(1.0,.80,.52):(vShade<2.5?vec3(.90,.96,1.0):vec3(1.0,.68,.70));
        col=c*(.82+.12*lgNoise(uv*.5)+.10*(1.0-graze));
      } else if (m<168.5) {
        // aquarium water: deep below, bright under the surface, caustics
        float y=pos.y;
        col=mix(vec3(.02,.20,.30),vec3(.12,.55,.62),smoothstep(0.0,40.0,y));
        vec2 cq=vec2(uv.x,uv.y)*.12+vec2(sin(t),cos(t))*.6;
        float ca=lgNoise(cq),cb=lgNoise(cq*1.7-vec2(cos(t),sin(t))*.5+ca*1.3);
        float web=pow(1.0-abs(2.0*cb-1.0),6.0);
        col+=vec3(.20,.45,.40)*web*smoothstep(-5.0,30.0,y);
        float ray=pow(.5+.5*sin(uv.x*.18+sin(t)*.6),6.0)*smoothstep(0.0,40.0,y);
        col+=vec3(.10,.22,.22)*ray;
        vec2 bq=vec2(uv.x*.6,uv.y*.6-t*0.95492966);vec2 bi=floor(bq);
        float bh=lgHash(vec2(bi.x,3.0));
        float bub=(1.0-smoothstep(.12,.22+pixel*.5,length(fract(bq)-vec2(.5,.5))))*step(.82,bh)*step(.5,lgHash(vec2(bi.x,mod(bi.y,6.0))));
        col+=vec3(.35,.55,.55)*bub*medR;
      } else if (m<169.5) {
        // shoji: paper lit from behind in a lattice of thin bars
        vec2 g=vec2(uv.x/4.0,uv.y/5.0);vec2 f=fract(g);vec2 e=min(f,1.0-f)*vec2(4.0,5.0);
        col=vec3(1.0,.92,.74)*(.90+.10*lgNoise(uv*.7));
        col*=.94+.06*smoothstep(.2,.8,lgNoise(uv*2.2))*fineR;
        col=mix(col,vec3(.24,.15,.08),lgLine(min(e.x,e.y),.22,pixel));
      } else if (m<170.5) {
        // a window's view, painted along the view ray (at infinity):
        // 1 garden, 2 sea, 3 city, 4 mountains, 5 forest; +8 by night
        float v=vShade;bool night=v>7.5;if(night)v-=8.0;
        if (roomNight>0.5) night=true;   // TEST179: a painted view follows the clock
        // the picture sits a little way behind the glass: its horizon at
        // y=24 (every window frames it), a touch of parallax with the eye
        float h=(pos.y-24.0)/34.0+vd.y*.10;float az=uv.x/34.0+(vd.x+vd.z)*.12;
        vec3 skyTop=night?vec3(.02,.03,.09):vec3(.36,.58,.86);
        vec3 skyLow=night?vec3(.06,.07,.16):vec3(.78,.86,.94);
        col=mix(skyLow,skyTop,smoothstep(-.05,.45,h));
        if (!night) {
          float cl=lgNoise(vec2(az*3.0+sin(t)*.04,h*9.0))*.6+lgNoise(vec2(az*7.0,h*20.0))*.4;
          col=mix(col,vec3(.98,.98,1.0),smoothstep(.55,.75,cl)*smoothstep(.0,.15,h)*.85);
        } else {
          vec2 sq=vec2(az*60.0,h*60.0);vec2 si=floor(sq);
          col+=vec3(.8,.85,1.0)*(1.0-smoothstep(.05,.18,length(fract(sq)-.5)))*step(.94,lgHash(si))*step(.02,h);
        }
        float hz=-.02;
        float sil=-1.0;vec3 sc=night?vec3(.03,.04,.06):vec3(.30,.48,.30);
        if (v<1.5) { sil=hz+.05+.05*lgNoise(vec2(az*4.0,1.0))+.06*pow(lgNoise(vec2(az*22.0,2.0)),3.0); }
        else if (v<2.5) {
          sil=hz;
          if (h<hz) { col=mix(night?vec3(.02,.05,.10):vec3(.18,.42,.62),night?vec3(.05,.09,.18):vec3(.55,.72,.84),smoothstep(-.4,hz,h));
            col+=vec3(.25)*pow(lgNoise(vec2(az*40.0+sin(t)*.3,h*200.0)),8.0)*(night?.3:1.0); }
          sil=-1.0;
        }
        else if (v<3.5) { float bw=floor(az*14.0);sil=hz+.04+.16*lgHash(vec2(bw,7.0));sc=night?vec3(.05,.05,.08):vec3(.52,.56,.62); }
        else if (v<4.5) { sil=hz+.08+.14*lgFbm(vec2(az*3.0,4.0))+.04*lgNoise(vec2(az*20.0,1.0));sc=night?vec3(.03,.03,.05):vec3(.48,.50,.56); }
        else { sil=hz+.10+.07*lgNoise(vec2(az*8.0,1.0))+.05*pow(abs(sin(az*60.0)),.5);sc=night?vec3(.02,.04,.03):vec3(.16,.34,.18); }
        if (h<sil) {
          col=sc*(.85+.2*lgNoise(vec2(az*30.0,h*30.0)));
          if (v>2.5&&v<3.5) {
            vec2 wq=vec2(az*140.0,h*90.0);vec2 wi=floor(wq);vec2 wf=fract(wq);
            float lit=step(.15,wf.x)*step(wf.x,.75)*step(.2,wf.y)*step(wf.y,.7);
            col=mix(col,night?vec3(1.0,.82,.45):vec3(.70,.80,.90),lit*step(.55,lgHash(wi))*(night?1.0:.5));
          }
          if (v<1.5||v>4.5) col=mix(col,sc*1.35,smoothstep(.4,.9,lgNoise(vec2(az*50.0,h*80.0)))*.5);
        }
        if (h<hz-.12&&v<1.5) col=night?vec3(.02,.04,.02):vec3(.36,.56,.28)*(.9+.2*lgNoise(vec2(az*20.0,h*40.0)));
      } else {
        // a backlit panel: diffuser cells, cool white
        vec2 g=fract(uv/4.0);vec2 e=min(g,1.0-g)*4.0;
        col=vec3(.96,.98,1.0)*(.92+.08*lgNoise(uv*.3));
        col*=1.0-.12*lgLine(min(e.x,e.y),.12,pixel);
      }
    }
    return clamp(col,vec3(.006),vec3(1.0));
  }
  vec3 leagueSurface(float matIn,vec3 pos) {
    // TEST165: ids 111..121 are the same finishes as shadowless detail,
    // 122 is fluted marble (pilaster shafts).
    // TEST166: 123 gravel, 124 pool mosaic, 125 marble ashlar, 126 flower
    // carpet (ReferenceMaterials lgGravel/lgPool/lgAshlar/lgBloom).
    float mat=matIn; bool fluted=false; float extra=0.0;
    if (mat>122.5) { extra=mat-122.0; mat=100.0; }
    else if (mat>121.5) { fluted=true; mat=100.0; } else if (mat>110.5) { mat-=11.0; }
    vec3 nrm=abs(refNormal);
    float px3=length(fwidth(pos));   // TEST169: world size of this pixel
    float topFace=step(max(nrm.x,nrm.z),nrm.y);
    vec2 side=nrm.x>nrm.z?pos.zy:pos.xy;
    vec2 uv=mix(side,pos.xz,topFace);
    float pixel=max(length(dFdx(uv)),length(dFdy(uv)));
    // TEST173: the town interiors' finishes
    if (matIn>142.5) return interiorSurface(matIn,pos,uv,topFace,pixel,nrm);
#ifdef LG_STRIP_LEAGUE
    // TEST187: the Kanto-outdoors shader has no League finishes (a neutral
    // stone if one ever reaches it)
    return vec3(.55,.53,.50);
#endif
    // TEST169: THE LEAGUE'S FLORA -- 127 clipped foliage (hedges, topiary),
    // 128 free-grown leaf crowns, 129 conifer needles, 130 meadow, 131 bark.
    // Crowns read as clusters of leaves: a billowed 3D field (no projection
    // seams on a faceted crown) gives each cluster a rounded body, a rim lit
    // from the sun's side and a dark crease where it meets the next, at a
    // size that survives the reduced render; leaf-scale grain inside it
    // fades with distance instead of shimmering.
    if (matIn>126.5 && matIn<129.5) {
      bool needles=matIn>128.5;
      bool clipped=matIn<127.5;
      // clusters: the nearest of a jittered 3D lattice of cluster centres
      // (2x2x2 neighbourhood), each a rounded mass lit from the sun's side
      // with a dark crease where it meets the next
      float sc=needles?.56:(clipped?1.30:.31);
      vec3 q=pos*sc;
      if (needles) q.y*=.42; else q.y*=1.15;
      vec3 b0=floor(q-.5);
      float f1=9.0,f2=9.0;vec3 off=vec3(0.0,1.0,0.0);
      for (int i=0;i<8;i++) {
        vec3 c=b0+vec3(mod(float(i),2.0),mod(floor(float(i)/2.0),2.0),floor(float(i)/4.0));
        float hc=lgHash3(c);
        vec3 fp=c+.18+.64*vec3(hc,fract(hc*13.37+.31),fract(hc*71.13+.57));
        vec3 dv=q-fp;float dd=dot(dv,dv);
        if (dd<f1) { f2=f1;f1=dd;off=dv; } else if (dd<f2) { f2=dd; }
      }
      f1=sqrt(f1);f2=sqrt(f2);
      float form=1.0-smoothstep(.45,1.4,px3*sc);
      // each cluster: bright on its upper, sunward side, deepening beneath
      // where it tucks under the next -- painted leaf masses, not scales
      float sd=dot(normalize(off+vec3(0.0,.0001,0.0)),vec3(.36,.82,.44));
      float lit=smoothstep(-.55,.80,sd);
      float dome=1.0-smoothstep(.20,1.0,f1);
      float under=(1.0-smoothstep(.0,.32,f2-f1))*(1.0-lit);
      // which crown: a broad world field picks each tree's own green
      float hue=lgNoise(pos.xz*.019+vec2(4.0,1.0));
      float hue2=lgNoise(pos.xz*.071+vec2(9.0,3.0));
      vec3 leaf;
      if (needles) {
        leaf=mix(vec3(.105,.235,.130),vec3(.190,.345,.170),smoothstep(.25,.80,hue));
        leaf=mix(leaf,vec3(.14,.27,.20),smoothstep(.65,.95,hue2)*.45);
      } else {
        leaf=mix(vec3(.160,.345,.115),vec3(.250,.460,.140),smoothstep(.15,.55,hue));
        leaf=mix(leaf,vec3(.340,.480,.145),smoothstep(.62,.92,hue)*.75);
        leaf=mix(leaf,vec3(.160,.335,.175),smoothstep(.70,.95,hue2)*.40);
        if (clipped) leaf=mix(leaf,vec3(.18,.37,.12),.55);
      }
      float relief=(.60+.50*lit*(.55+.45*dome))*(1.0-.32*under);
      if (clipped) relief=mix(.92,relief,.55);   // a clipped face: fine, even leaf
      vec3 col=leaf*mix(.88,relief,form);
      // sunlit cluster tops warm toward yellow-green; the undersides cool
      col=mix(col,col*vec3(1.14,1.10,.80),lit*dome*.45*form);
      col=mix(col,col*vec3(.82,.93,1.06),(1.0-lit)*.40*form);
      // leaf grain: small leaves or needle sprays, close up only
      float grain=1.0-smoothstep(.06,.30,px3);
      if (grain>.001) {
        vec3 g=needles?pos*vec3(3.4,1.2,3.4):pos*2.7;
        float n=lgNoise3(g);
        col*=1.0+(n-.5)*.36*grain;
      }
      return clamp(col,vec3(.01),vec3(.9));
    }
    if (matIn>129.5 && matIn<130.5) {
      // lgMeadow: the wild sward on the ledges and down the valley --
      // tussocks with dark roots, sun-dried and lush drifts, moss in the
      // hollows, wildflowers close up; bare earth and stone on steep ground.
      vec2 w=pos.xz+vec2(lgNoise(pos.xz*.05),lgNoise(pos.xz*.05+9.0))*14.0;
      float big=lgNoise(w*.012);
      float mid=lgNoise(w*.045+vec2(3.0,5.0));
      vec3 lush=vec3(.205,.405,.130),sun=vec3(.390,.470,.150),dry=vec3(.480,.455,.210),deep=vec3(.140,.300,.120);
      vec3 g=mix(lush,sun,smoothstep(.35,.75,big));
      g=mix(g,dry,smoothstep(.62,.88,mid)*.55);
      g=mix(g,deep,smoothstep(.55,.85,lgNoise(w*.09+vec2(7.0,1.0)))*.50);
      float near=1.0-smoothstep(.25,1.3,px3);
      float fine=1.0-smoothstep(.05,.25,px3);
      float tus=lgNoise(w*.42)*.6+lgNoise(w*1.1+vec2(4.0,4.0))*.4;
      g*=mix(.95,.80+.32*tus,near);
      if (fine>.001) {
        float bl=lgNoise(vec2(w.x*3.3+w.y*.9,w.y*3.1-w.x*.7));
        g*=1.0+(bl-.5)*.30*fine;
        vec2 fc=floor(w/1.7);vec2 ff=fract(w/1.7)-.5;
        float fh=lgHash(fc+vec2(3.0,7.0));
        vec2 off=vec2(lgHash(fc+vec2(1.0,9.0)),lgHash(fc+vec2(8.0,2.0)))-.5;
        float r=length(ff-off*.6);
        float bloom=(1.0-smoothstep(.07,.13,r))*step(.80,fh)*fine;
        vec3 fcol=fh>.95?vec3(.95,.93,.88):(fh>.90?vec3(.98,.82,.24):(fh>.85?vec3(.62,.42,.82):vec3(.92,.55,.70)));
        g=mix(g,fcol,bloom*.9);
      }
      // steep ground: earth and rock break through the grass
      float steep=1.0-smoothstep(.55,.85,nrm.y/max(length(nrm),1e-6));
      vec3 earth=mix(vec3(.36,.30,.22),vec3(.48,.46,.42),lgNoise(w*.21));
      g=mix(g,earth,steep*smoothstep(.35,.65,lgNoise(w*.08+vec2(2.0,2.0)))*.85);
      return clamp(g,vec3(.02),vec3(.9));
    }
    if (matIn>130.5 && matIn<131.5) {
      // lgBark: plated pine/broadleaf bark -- warm plates split by dark
      // vertical fissures, a little grey lichen.
      float n=lgNoise3(pos*vec3(1.05,.26,1.05));
      float n2=lgNoise3(pos*vec3(2.3,.55,2.3)+vec3(4.0,1.0,7.0));
      float fiss=1.0-smoothstep(.05,.16+px3*.5,abs(n-.5));
      vec3 plate=mix(vec3(.40,.26,.17),vec3(.52,.36,.24),n2);
      vec3 col=mix(plate,vec3(.13,.09,.07),fiss*(1.0-smoothstep(.3,1.2,px3))*.85);
      col=mix(col,vec3(.55,.56,.50),smoothstep(.72,.90,lgNoise3(pos*.7+vec3(2.0,9.0,4.0)))*.35);
      return clamp(col,vec3(.02),vec3(.9));
    }
    // TEST172: THE LEAGUE ROOMS' FINISHES (ReferenceMaterials 132..142):
    // 132 glacial ice, 133 ice crystal (self-lit), 134 obsidian, 135 dojo
    // wood, 136 lava (self-lit), 137 gothic slate, 138 silver, 139 stained
    // glass (self-lit), 140 the night sky, 141 snow, 142 plum damask.
    if (matIn>131.5) {
      float fineR=1.0-smoothstep(.05,.24,pixel);
      float medR=1.0-smoothstep(.45,2.0,pixel);
      float broadR=lgNoise(uv*.045);
      vec3 vd=normalize(pos-eye);
      vec3 nU=nrm/max(length(nrm),1e-6);
      vec3 col=vec3(.5);
      if (matIn<132.5) {
        // lgIce: a deep blue body seen INTO the ice -- fractures and bubbles
        // at depth slide against the surface as the eye moves -- frost in
        // drifts, and a cold polish that brightens at grazing angles.
        vec2 vt=nrm.x>nrm.z?vd.zy:vd.xy;
        vt=mix(vt,vd.xz,topFace);
        float cosV=max(abs(dot(vd,nU)),.28);
        vec2 pv=vt/cosV;
        float body=lgFbm(uv*.035+vec2(3.0,1.0));
        col=mix(vec3(.10,.27,.45),vec3(.46,.72,.88),smoothstep(.20,.90,body));
        float c1=lgVein(uv+pv*2.6,.16,.035,pixel)*medR;
        float c2=lgVein(uv+pv*6.5+vec2(17.0,5.0),.26,.04,pixel)*fineR;
        col=mix(col,vec3(.86,.95,1.0),c1*.38);
        col=mix(col,vec3(.66,.86,.97),c2*.26);
        col=mix(col,vec3(.16,.36,.58),smoothstep(.55,.85,lgFbm(uv*.06+pv*.08+vec2(9.0,4.0)))*.45);
        vec2 bq=(uv+pv*1.6)*.9;vec2 bi=floor(bq),bf=fract(bq)-.5;
        float bh=lgHash(bi+vec2(3.0,8.0));
        float bub=(1.0-smoothstep(.05,.12+pixel*.3,length(bf-(vec2(lgHash(bi+vec2(1.0,2.0)),lgHash(bi+vec2(5.0,4.0)))-.5)*.6)))*step(.86,bh)*fineR;
        col+=vec3(.20,.24,.26)*bub;
        float frost=smoothstep(.55,.80,lgFbm(uv*.11+vec2(7.0,2.0)));
        col=mix(col,vec3(.88,.94,.98),frost*.45);
        float polish=pow(.5+.5*sin(dot(pos.xz,vec2(.045,.031))+uv.y*.02+broadR*3.0),10.0);
        col+=vec3(.16,.20,.22)*polish*topFace;
        col+=vec3(.22,.28,.32)*pow(clamp(1.0-cosV,0.0,1.0),3.0);
        col*=.97+.06*(lgNoise(uv*2.3)-.5)*fineR;
      } else if (matIn<133.5) {
        // lgCrystal: faceted ice crystal lit from within -- striations up
        // the shaft, every facet its own tone, a slow breathing glow.
        float facet=fract(dot(nU,vec3(1.7,2.9,1.3))*3.1);
        float inner=lgNoise3(pos*vec3(.35,.09,.35));
        float pulse=.86+.14*sin(casinoPhase+pos.y*.08+pos.x*.05);
        col=mix(vec3(.34,.78,1.0),vec3(.86,.99,1.0),.30+.40*facet+.25*inner);
        col=mix(col,vec3(.95,1.0,1.0),smoothstep(.62,.80,lgNoise3(pos*vec3(.6,.15,.6)+vec3(3.0,1.0,2.0)))*.35*medR);
        col*=pulse;
        col+=vec3(.25,.35,.40)*pow(clamp(1.0-abs(dot(vd,nU)),0.0,1.0),3.0);
      } else if (matIn<134.5) {
        // lgObsidian: black volcanic glass. Broad mirror bands, a violet and
        // ember sheen, faint conchoidal ripples; slabs on the floor.
        float band=.5+.5*sin(pos.y*.42+(pos.x+pos.z)*.16+broadR*2.6);
        col=vec3(.040,.038,.052)*(.85+.30*broadR);
        col+=vec3(.26,.22,.34)*pow(band,14.0);
        col+=vec3(.20,.06,.04)*pow(.5+.5*sin(pos.y*.31-(pos.x-pos.z)*.11+broadR*4.0),20.0);
        float rip=lgLine(abs(fract(lgFbm(uv*.12)*7.0)-.5),.04,pixel*.5);
        col+=vec3(.05,.05,.07)*rip*medR;
        vec2 sq=fract(uv/16.0);vec2 se=min(sq,1.0-sq)*16.0;
        float joint=lgLine(min(se.x,se.y),.10,pixel)*topFace;
        col=mix(col,vec3(.55,.38,.14),joint*.75);
      } else if (matIn<135.5) {
        // lgWood: dojo boards -- planks along the floor, posts and wall
        // boards grain upward; each board its own tone, knots, worn polish.
        float a=mix(uv.x,pos.x,topFace),l=mix(uv.y,pos.z,topFace);
        float bw=5.5;float bi=floor(a/bw);float fa=fract(a/bw);
        float bl=26.0+lgHash(vec2(bi,9.0))*30.0;float off=lgHash(vec2(bi,3.0))*bl;
        float li=floor((l+off)/bl);float fl=fract((l+off)/bl);
        float tone=lgHash(vec2(bi,li)+vec2(4.0,1.0));
        col=mix(vec3(.40,.25,.14),vec3(.63,.43,.24),tone);
        col=mix(col,vec3(.33,.19,.10),step(.86,lgHash(vec2(li,bi)+vec2(7.0,5.0)))*.6);
        float g=lgNoise(vec2(a*1.6+bi*13.0,l*.10+li*7.0));
        float ring=.5+.5*sin(g*22.0+a*1.3);
        col*=.86+.18*ring*medR+.04*(broadR-.5);
        col*=1.0+(lgNoise(vec2(a*6.0,l*.6))-.5)*.16*fineR;
        vec2 kp=vec2(fa-.5,fract(l/9.0+bi*.37)-.5);
        float knot=(1.0-smoothstep(.06,.14,length(kp*vec2(1.0,2.2))))*step(.82,lgHash(vec2(bi,floor(l/9.0+bi*.37))));
        col=mix(col,vec3(.22,.12,.06),knot*.75*medR);
        float j1=lgLine(min(fa,1.0-fa)*bw,.10,pixel);
        float j2=lgLine(min(fl,1.0-fl)*bl,.10,pixel);
        col=mix(col,vec3(.12,.07,.04),max(j1,j2)*.85);
        col+=vec3(.07,.05,.03)*pow(.5+.5*sin(pos.x*.05+pos.z*.07+broadR*2.0),8.0)*topFace;
      } else if (matIn<136.5) {
        // lgLava: molten rock under a breaking crust. The cracks run gold
        // to white, the crust plates glow red at their edges, and the whole
        // surface breathes (casinoPhase is a smooth clock).
        vec2 w=pos.xz*.045+vec2(lgNoise(pos.xz*.02),lgNoise(pos.xz*.02+5.0))*1.6;
        vec2 ci=floor(w),cf=fract(w);
        float f1=9.0,f2=9.0;
        for (int i=0;i<9;i++) {
          vec2 o=vec2(mod(float(i),3.0)-1.0,floor(float(i)/3.0)-1.0);
          vec2 c=ci+o;
          vec2 pnt=o+vec2(lgHash(c+vec2(2.0,7.0)),lgHash(c+vec2(9.0,1.0)))*.8+.1-cf;
          float dd=dot(pnt,pnt);
          if (dd<f1) { f2=f1;f1=dd; } else if (dd<f2) { f2=dd; }
        }
        float edge=sqrt(f2)-sqrt(f1);
        float crack=1.0-smoothstep(.0,.22,edge);
        float breath=.80+.20*sin(casinoPhase+lgNoise(pos.xz*.03)*6.283);
        float flow=.5+.5*sin(casinoPhase*2.0+pos.x*.06-pos.z*.04+lgNoise(pos.xz*.08)*4.0);
        vec3 crust=mix(vec3(.10,.04,.03),vec3(.26,.07,.03),smoothstep(.05,.30,crack+.15*flow));
        vec3 melt=mix(vec3(1.0,.32,.04),vec3(1.0,.86,.40),crack*crack);
        col=mix(crust,melt*breath,crack);
        col+=vec3(.30,.06,.0)*(1.0-smoothstep(.0,.6,edge))*breath;
      } else if (matIn<137.5) {
        // lgSlate: dark gothic stone. Coursed blocks on walls, flags on the
        // floor; violet-grey stones, bevelled lit arrises, sunk joints, damp
        // creeping up from the floor.
        vec2 dim=mix(vec2(14.0,7.0),vec2(16.0,16.0),topFace);
        vec2 q=uv/dim;float row=floor(q.y);q.x+=mod(row,2.0)*.5+lgHash(vec2(row,2.0))*.25;
        vec2 cell=floor(q),f=fract(q);vec2 e=min(f,1.0-f)*dim;float d=min(e.x,e.y);
        float h=lgHash(cell+vec2(6.0,3.0));
        col=mix(vec3(.21,.21,.26),vec3(.33,.32,.38),h);
        col=mix(col,vec3(.27,.24,.32),step(.80,lgHash(cell+vec2(1.0,9.0)))*.6);
        col*=.86+.24*lgFbm(uv*.35+cell*3.1);
        col*=1.0+(lgNoise(uv*3.3)-.5)*.20*fineR;
        float side01=1.0-topFace;
        float lip=(1.0-smoothstep(.10,.55+pixel,(1.0-f.y)*dim.y))*side01*step(.3,d);
        col+=vec3(.07,.07,.08)*lip*medR;
        float jt=lgLine(d,.16,pixel);
        col=mix(col,vec3(.07,.07,.08),jt*.85);
        float damp=(1.0-smoothstep(0.0,12.0,pos.y))*side01*smoothstep(.35,.65,lgFbm(uv*.09));
        col*=1.0-.30*damp;
        col=mix(col,vec3(.22,.26,.20),smoothstep(.70,.85,lgFbm(uv*.21+vec2(4.0,4.0)))*.25*(1.0-smoothstep(0.0,20.0,pos.y)));
      } else if (matIn<138.5) {
        // lgSilver: polished silver; broad cool mirror bands.
        float band=.5+.5*sin(pos.y*.55+(pos.x-pos.z)*.21+broadR*2.5);
        col=mix(vec3(.40,.43,.49),vec3(.93,.95,.99),band);
        col+=vec3(.12,.13,.15)*pow(band,9.0);
        col*=.96+.06*(lgNoise(vec2(uv.x*4.0,uv.y*.3))-.5)*fineR;
      } else if (matIn<139.5) {
        // lgAmethyst: leaded stained glass in violets and night blues, lit
        // from behind; a jewel of gold or rose here and there.
        vec2 q=uv/3.2;vec2 qi=floor(q+.5*vec2(mod(floor(q.y),2.0),0.0));
        vec2 dq=abs(fract(q)-.5);
        float lead=lgLine(abs(dq.x+dq.y-.5),.06,pixel/3.2*1.5);
        float h=lgHash(qi+vec2(3.0,11.0));
        col=mix(vec3(.36,.12,.62),vec3(.20,.18,.70),smoothstep(.2,.8,h));
        col=mix(col,vec3(.70,.20,.62),step(.82,h));
        col=mix(col,vec3(.95,.72,.30),step(.95,h));
        col*=.80+.35*lgNoise(uv*.6+qi);
        if (vShade>2.0) col=mix(vec3(.46,.20,.80),vec3(.85,.62,1.0),lgNoise3(pos*.8)*.6+.4*pow(clamp(1.0-abs(dot(vd,nU)),0.0,1.0),2.0));
        else col=mix(col,vec3(.03,.02,.04),lead*.92);
      } else if (matIn<140.5) {
        // lgNight: the sky, painted along the view ray so it stands at
        // infinity: navy to black, a violet horizon, the Milky Way, two
        // layers of twinkling stars. vShade picks the sky: <1.5 clear,
        // 1.5..2.5 aurora green on the horizon, >2.5 storm clouds.
        float h=vd.y;
        col=mix(vec3(.040,.055,.130),vec3(.006,.010,.032),smoothstep(-.05,.75,h));
        col+=vec3(.10,.06,.17)*exp(-abs(h)*5.0);
        float mw=dot(vd,normalize(vec3(.35,.55,.76)));
        float band=exp(-mw*mw*26.0);
        col+=vec3(.10,.09,.15)*band*(.45+.9*lgNoise3(vd*9.0))*smoothstep(-.05,.25,h);
        vec3 s1=vd*190.0;vec3 c1=floor(s1);float h1=lgHash3(c1);
        vec3 o1=vec3(lgHash3(c1+3.1),lgHash3(c1+7.7),lgHash3(c1+1.3))*.6+.2;
        float r1=length(fract(s1)-o1);
        float tw=.65+.35*sin(casinoPhase*3.0+h1*61.0);
        float st=(1.0-smoothstep(.04,.16,r1))*step(.955,h1)*tw;
        vec3 s2=vd*70.0;vec3 c2=floor(s2);float h2=lgHash3(c2+9.0);
        vec3 o2=vec3(lgHash3(c2+2.2),lgHash3(c2+5.5),lgHash3(c2+8.8))*.6+.2;
        float r2=length(fract(s2)-o2);
        float st2=(1.0-smoothstep(.03,.12,r2))*step(.985,h2)*(.75+.25*sin(casinoPhase*2.0+h2*40.0));
        float above=smoothstep(-.02,.10,h);
        col+=(vec3(.80,.86,1.0)*st*.85+vec3(1.0,.95,.85)*st2*1.4)*above;
        if (vShade>1.5 && vShade<2.5) {
          col+=vec3(.02,.16,.10)*exp(-abs(h)*2.6);
          col+=vec3(.05,.02,.10)*exp(-abs(h)*1.2);
        }
        if (vShade>2.5) {
          float cl=lgNoise3(vd*3.0+vec3(2.0,7.0,1.0))*.6+lgNoise3(vd*7.5)*.4;
          float cover=smoothstep(.36,.66,cl);
          vec3 cloud=mix(vec3(.05,.04,.07),vec3(.16,.12,.17),lgNoise3(vd*12.0))*(.7+.6*smoothstep(.5,.9,cl));
          col=mix(col,cloud,cover*.92);
          col+=vec3(.24,.06,.02)*exp(-abs(h+.05)*7.0);
        }
        col*=.25+.75*smoothstep(-.40,-.02,h);
      } else if (matIn<141.5) {
        // lgSnow: wind-packed powder, blue in its hollows, glittering.
        float n=lgFbm(uv*.09+vec2(2.0,6.0));
        col=mix(vec3(.70,.80,.92),vec3(.95,.97,1.0),smoothstep(.25,.75,n));
        col*=.95+.08*lgNoise(uv*1.4);
        vec2 gq=uv*1.6;vec2 gi=floor(gq);float gh=lgHash(gi+vec2(5.0,2.0));
        float gl=(1.0-smoothstep(.04,.10+pixel,length(fract(gq)-.5)))*step(.93,gh);
        col+=vec3(.6,.7,.8)*gl*fineR*(.5+.5*sin(casinoPhase*4.0+gh*50.0));
      } else {
        // lgPlum: a purple damask with a quiet woven lattice.
        col=vec3(.27,.07,.32)*(.88+.20*broadR);
        vec2 dq=uv/5.0;dq.x+=mod(floor(dq.y),2.0)*.5;
        vec2 df=abs(fract(dq)-.5);
        float lattice=lgLine(abs(df.x+df.y-.36),.035,pixel*.2*1.4);
        col*=1.0-lattice*.18*medR;
        col+=vec3(.05,.015,.06)*pow(max(0.0,sin(uv.y*.35+uv.x*.06)),6.0);
      }
      return clamp(col,vec3(.008),vec3(1.0));
    }
    float fine=1.0-smoothstep(.05,.24,pixel);
    float medium=1.0-smoothstep(.45,2.0,pixel);
    float broad=lgNoise(uv*.045);
    float speck=(lgHash(floor(uv*7.0))-.5)*fine;
    vec3 base;
    if (mat<100.5) {
      // lgMarble: warm statuary white, soft grey veins and a faint gold drift.
      base=vec3(.905,.885,.845)*(.965+.07*broad)+vec3(speck*.025);
      float v1=lgVein(uv,.085,.045,pixel)*medium;
      float v2=lgVein(uv+vec2(31.0,17.0),.21,.06,pixel)*fine;
      base=mix(base,vec3(.60,.60,.64),v1*.55);
      base=mix(base,vec3(.74,.72,.70),v2*.35);
      base+=vec3(.040,.028,.000)*smoothstep(.62,.90,lgNoise(uv*.11+vec2(5.0,2.0)))*medium;
    } else if (mat<101.5) {
      // lgGranite (TEST169): coursed, rock-faced granite. Courses of three
      // heights, blocks of varied length per course, each stone its own
      // colour (grey, buff, blue-grey, the odd rosy one); a pillowed face
      // with a lit upper arris and a deep lower shadow; recessed mortar;
      // rain streaks down the face, damp and moss along the foot and in
      // the joints, lichen rosettes -- detail sized to survive the
      // reduced render, finer grain only close up.
      float yy=uv.y;float band=floor(yy/13.0);float rr=yy-band*13.0;
      float c0=rr<5.0?0.0:(rr<8.5?1.0:2.0);
      float ch=c0<.5?5.0:(c0<1.5?3.5:4.5);
      float cy0=band*13.0+(c0<.5?0.0:(c0<1.5?5.0:8.5));
      float course=band*3.0+c0;
      float fy=(yy-cy0)/ch;
      float bl=6.5+3.5*floor(lgHash(vec2(course,3.0))*3.0);
      float bx=(uv.x+lgHash(vec2(course,7.0))*bl)/bl;
      float fx=fract(bx);
      vec2 cell=vec2(floor(bx),course);
      float d=min(min(fx,1.0-fx)*bl,min(fy,1.0-fy)*ch);
      float block=lgHash(cell+vec2(3.0,11.0));
      float block2=lgHash(cell+vec2(17.0,5.0));
      vec3 stone=mix(vec3(.585,.570,.545),vec3(.660,.600,.505),smoothstep(.50,.85,block));
      stone=mix(stone,vec3(.505,.535,.565),smoothstep(.55,.90,block2)*.85);
      stone=mix(stone,vec3(.650,.545,.515),step(.92,block)*.75);
      stone*=.80+.26*lgHash(cell+vec2(5.0,1.0))+.08*(broad-.5);
      float pillow=smoothstep(0.0,1.7,d);
      float rough=lgFbm(uv*.75+cell*3.7);
      base=stone*(.74+.30*pillow)*(.84+.30*rough);
      base*=1.0+(lgNoise(uv*3.1+cell*5.0)-.5)*.24*fine;
      base=mix(base,vec3(.16,.155,.15),step(.88,lgHash(floor(uv*4.0)+cell))*fine*.20);
      base=mix(base,vec3(.88,.86,.82),step(.95,lgHash(floor(uv*5.0)+cell*1.7))*fine*.16);
      float side01=1.0-topFace;
      float lipTop=(1.0-smoothstep(.10,.60+pixel,(1.0-fy)*ch))*side01*step(.25,d);
      float lipBot=(1.0-smoothstep(.10,.80+pixel,fy*ch))*side01;
      base+=vec3(.11,.105,.095)*lipTop*medium;
      base*=1.0-.36*lipBot*medium;
      // weathering
      float wx=uv.x+lgNoise(vec2(uv.y*.05,uv.x*.02))*6.0;
      float streak=lgNoise(vec2(wx*.85,yy*.022));
      base*=1.0-smoothstep(.52,.92,streak)*.26*side01;
      float h0=pos.y,h1=pos.y+11.0,h2=pos.y+19.5;
      float hb=h0>-.6?h0:(h1>-.6?h1:h2);
      float foot=(1.0-smoothstep(0.0,5.5,hb))*side01;
      float mossN=lgFbm(uv*.21+vec2(3.0,8.0));
      float moss=clamp(foot*smoothstep(.30,.62,mossN)*1.3,0.0,1.0);
      // lichen rosettes, sparse, pale green-grey and the odd orange
      vec2 lq=uv/2.3;vec2 li=floor(lq),lf=fract(lq)-.5;
      float lh=lgHash(li+vec2(13.0,2.0));
      float lr=length(lf-(vec2(lgHash(li+vec2(2.0,5.0)),lgHash(li+vec2(6.0,1.0)))-.5)*.5);
      lr*=.80+.45*lgNoise(uv*1.9+li*3.0);
      float lich=(1.0-smoothstep(.08+lh*.08,.18+lh*.08+pixel*.3,lr))*step(.90,lh)*medium*side01;
      base=mix(base,lh>.975?vec3(.72,.50,.22):vec3(.64,.67,.54),lich*.55);
      float joint=lgLine(d,.17,pixel);
      vec3 mortar=mix(vec3(.30,.285,.265),vec3(.20,.26,.14),clamp(foot*1.6+smoothstep(.55,.75,mossN)*.5,0.0,1.0));
      base=mix(base,mortar,joint*.80);
      base=mix(base,mix(vec3(.20,.30,.11),vec3(.30,.38,.15),rough),moss*.85);
    } else if (mat<102.5) {
      // lgCrimson: lacquered panel with a quiet woven damask lattice.
      base=vec3(.50,.065,.085)*(.90+.18*broad);
      vec2 dq=uv/5.0;dq.x+=mod(floor(dq.y),2.0)*.5;
      vec2 df=abs(fract(dq)-.5);
      float lattice=lgLine(abs(df.x+df.y-.36),.035,pixel*.2*1.4);
      base*=1.0-lattice*.16*medium;
      base+=vec3(.06,.012,.012)*pow(max(0.0,sin(uv.y*.35+uv.x*.06)),6.0);
      base*=.97+.05*(lgNoise(vec2(uv.x*3.0,uv.y*.15))-.5)*fine;
    } else if (mat<103.5) {
      // lgGold: polished gold; broad mirror bands stand in for reflection.
      float band=.5+.5*sin(pos.y*.55+(pos.x+pos.z)*.21+broad*2.5);
      base=mix(vec3(.58,.38,.10),vec3(1.0,.84,.42),band);
      base+=vec3(.12,.10,.06)*pow(band,9.0);
      base*=.96+.06*(lgNoise(vec2(uv.x*4.0,uv.y*.3))-.5)*fine;
    } else if (mat<104.5) {
      // lgBronze: cast bronze, warm highlights and verdigris in the hollows.
      // a soft vertical sheen sweeps across the cast metal
      float band=.5+.5*sin(pos.y*.19+(pos.x-pos.z)*.06+broad*2.2);
      float sheen=pow(band,3.0);
      base=mix(vec3(.24,.15,.075),vec3(.62,.42,.20),.25+band*.55+.20*broad);
      base+=vec3(.30,.22,.10)*sheen;
      base*=.95+.09*(lgNoise(vec2(uv.x*5.0,uv.y*.35))-.5)*fine;
      float pat=smoothstep(.64,.86,lgFbm(uv*.30+vec2(9.0,4.0)));
      base=mix(base,vec3(.30,.46,.38),pat*.28);
      base+=vec3(speck*.04);
    } else if (mat<106.5) {
      // lgPaveLight / lgPaveDark: one 8-unit slab per source tile.
      bool dark=mat>105.5;
      vec2 cell=floor(uv/8.0),f=fract(uv/8.0),edge=min(f,1.0-f)*8.0;
      float d=min(edge.x,edge.y),aa=max(.03,pixel*.7);
      float joint=lgLine(d,.11,pixel);
      float slab=lgHash(cell+vec2(dark?17.0:5.0,2.0));
      if (dark) {
        base=vec3(.255,.270,.315)*(.88+.20*slab);
        base=mix(base,vec3(.85,.84,.80),step(.955,lgHash(floor(uv*6.0)+vec2(13.0,3.0)))*fine*.75);
        base=mix(base,vec3(.80,.62,.30),step(.985,lgHash(floor(uv*4.0)+vec2(2.0,29.0)))*fine*.8);
        base*=1.0-lgVein(uv+cell*13.0,.12,.05,pixel)*.25*medium;
      } else {
        base=vec3(.865,.835,.770)*(.92+.12*slab+.06*(broad-.5));
        base=mix(base,vec3(.70,.66,.60),step(.94,lgHash(floor(uv*5.0)+vec2(7.0,1.0)))*fine*.5);
        base*=1.0-lgVein(uv+cell*7.0,.10,.05,pixel)*.12*medium;
      }
      base=mix(base,base*.42,joint);
      base+=vec3(.045)*max(1.0-smoothstep(.2,.6+aa,d)-joint,0.0)*medium;
    } else if (mat<107.5) {
      // lgLawn (TEST169): a fine mown sward. Mowing stripes, sun-warmed and
      // deep-green drifts, clover patches, a tufted nap with dark roots
      // between the tufts, blades and the odd daisy or buttercup close up.
      float stripe=step(.5,fract(pos.x/16.0));
      base=mix(vec3(.235,.440,.140),vec3(.305,.530,.175),stripe);
      base*=.88+.22*broad;
      base=mix(base,vec3(.38,.53,.18),smoothstep(.60,.86,lgNoise(uv*.065+vec2(5.0,1.0)))*.40);
      base=mix(base,vec3(.15,.37,.12),smoothstep(.58,.86,lgNoise(uv*.10+vec2(1.0,9.0)))*.42);
      float clover=smoothstep(.62,.80,lgNoise(uv*.38+vec2(8.0,3.0)));
      base=mix(base,vec3(.20,.42,.15),clover*.55*medium);
      float tuft=lgNoise(uv*1.15)*.6+lgNoise(uv*2.7+vec2(4.0,4.0))*.4;
      base*=mix(.96,.84+.26*tuft,medium);
      float blade=lgNoise(vec2(uv.x*4.6+uv.y*1.2,uv.y*4.2-uv.x*.8));
      base*=1.0+(blade-.5)*.30*fine+speck*.16;
      vec2 fc=floor(uv/1.9);vec2 ff=fract(uv/1.9)-.5;
      float fh=lgHash(fc+vec2(4.0,6.0));
      float fr=length(ff-(vec2(lgHash(fc+vec2(1.0,3.0)),lgHash(fc+vec2(7.0,7.0)))-.5)*.6);
      float flower=(1.0-smoothstep(.06,.11,fr))*step(.93,fh)*fine;
      vec3 fcol=fh>.955?vec3(.98,.84,.25):vec3(.96,.95,.90);
      base=mix(base,fcol,flower*.9);
      base=mix(base,vec3(.98,.80,.20),(1.0-smoothstep(.0,.04,fr))*step(.93,fh)*step(fh,.955)*fine);
    } else if (mat<108.5) {
      // lgCarpet: crimson velvet with a woven nap and a centre medallion row.
      base=vec3(.56,.055,.075)*(.92+.10*broad);
      float weave=sin(uv.x*6.3)*sin(uv.y*6.3);
      base*=1.0+weave*.05*fine;
      vec2 m=fract(uv/16.0)-.5;
      float diamond=abs(m.x)+abs(m.y);
      base=mix(base,vec3(.86,.62,.26),(1.0-smoothstep(.10,.10+pixel*.06+.012,abs(diamond-.30)))*medium*.65);
      base*=.96+.08*(lgNoise(uv*1.7)-.5)*fine;
    } else if (mat<109.5) {
      // lgRock: weathered granite boulder with lichen.
      base=vec3(.560,.530,.495)*(.84+.24*lgFbm(uv*.21));
      base=mix(base,vec3(.22,.21,.21),step(.87,lgHash(floor(uv*6.0)))*fine*.6);
      float strata=abs(sin(pos.y*.9+lgNoise(uv*.4)*3.0));
      base*=1.0-(1.0-smoothstep(.02,.12+pixel,strata))*.18*medium;
      float lichen=smoothstep(.60,.78,lgFbm(uv*.33+vec2(11.0,2.0)));
      base=mix(base,vec3(.62,.66,.40),lichen*.45);
    } else {
      // lgVerde: polished verde antique for plinths and bases.
      base=vec3(.110,.170,.150)*(.85+.25*broad);
      base=mix(base,vec3(.78,.82,.78),lgVein(uv,.16,.035,pixel)*.55*medium);
      base=mix(base,vec3(.30,.42,.36),lgVein(uv+vec2(9.0,3.0),.33,.05,pixel)*.30*fine);
    }
    if (extra>0.5) {
      if (extra<1.5) {
        // lgGravel: raked crushed limestone with rounded pebbles.
        base=vec3(.80,.755,.675)*(.93+.10*broad)*(.95+.08*lgNoise(uv*.3));
        vec2 gq=uv*2.2;vec2 gi=floor(gq),gf=fract(gq);
        vec2 cp=vec2(lgHash(gi+vec2(3.1,1.7)),lgHash(gi+vec2(7.7,4.3)))*.56+.22;
        float dd=length(gf-cp);
        float h=lgHash(gi);
        float peb=1.0-smoothstep(.24,.36,dd);
        base*=1.0+((h-.5)*.30*peb+speck*.12)*fine;
        base*=1.0-(smoothstep(.30,.36,dd)*(1.0-smoothstep(.36,.44,dd)))*.22*fine;
        base*=1.0-.05*abs(sin(uv.x*1.6+lgNoise(uv*.2)*2.0))*medium;
      } else if (extra<2.5) {
        // lgPool: glazed mosaic -- aqua tiles, deep-blue lattice, gold studs.
        vec2 t=uv/1.1;vec2 ti=floor(t),tf=fract(t);
        float h=lgHash(ti+vec2(19.0,4.0));
        base=mix(vec3(.10,.44,.56),vec3(.20,.62,.70),h)*(.92+.12*broad);
        vec2 m=abs(fract(uv/8.8)-.5);
        float dia=lgLine(abs(m.x+m.y-.25),.05,pixel/8.8*1.6);
        base=mix(base,vec3(.04,.17,.40),dia*.9);
        float stud=1.0-smoothstep(.035,.035+pixel/8.8*1.6+.01,length(m));
        base=mix(base,vec3(.95,.76,.32),stud*medium);
        float tg=min(min(tf.x,1.0-tf.x),min(tf.y,1.0-tf.y))*1.1;
        base=mix(base,vec3(.82,.86,.84),lgLine(tg,.06,pixel)*.55);
      } else if (extra<3.5) {
        // lgAshlar: the statuary marble laid as large courses with fine,
        // slightly V-cut joints and a lit edge above each joint.
        vec2 q=uv/vec2(16.0,8.0);float row=floor(q.y);q.x+=mod(row,2.0)*.5;
        vec2 f=fract(q),edge=min(f,1.0-f)*vec2(16.0,8.0);
        float d=min(edge.x,edge.y);
        float bh=lgHash(floor(q)+vec2(2.0,9.0));
        base*=.95+.09*bh;
        base=mix(base,base*vec3(1.0,.985,.95),step(.72,bh)*.6);
        // drafted margin: a finely tooled band just inside every joint
        float margin=(1.0-smoothstep(.55,.70+pixel,d))*(1.0-smoothstep(.0,.16,d));
        base*=1.0-.035*margin*medium;
        float jt=lgLine(d,.14,pixel);
        float lit=(1.0-smoothstep(.12,.50+pixel,(1.0-f.y)*8.0))*(1.0-topFace);
        float shd=(1.0-smoothstep(.12,.60+pixel,f.y*8.0))*(1.0-topFace);
        base+=vec3(.045)*lit*medium;
        base*=1.0-.07*shd*medium;
        base=mix(base,vec3(.40,.38,.37),jt*.80);
      } else {
        // lgBloom: a planted flower carpet. Foliage with dense blossoms in
        // a two-colour palette chosen per bed; far away it settles into
        // the mixed colour instead of shimmering.
        vec3 leafy=vec3(.18,.40,.13)*(.82+.35*lgNoise(uv*1.7));
        float pal=lgHash(floor(pos.xz/16.0)+vec2(5.0,9.0));
        vec3 A=vec3(.80,.08,.12),B=vec3(.98,.80,.22);
        if (pal>.25) { A=vec3(.95,.93,.88); B=vec3(.86,.12,.30); }
        if (pal>.50) { A=vec3(.52,.24,.78); B=vec3(.98,.86,.40); }
        if (pal>.75) { A=vec3(.98,.55,.18); B=vec3(.95,.93,.88); }
        vec2 bq=uv*2.6;vec2 bi=floor(bq),bf=fract(bq);
        float hh=lgHash(bi+vec2(1.0,8.0));
        vec2 cp=vec2(lgHash(bi+vec2(1.3,2.0)),lgHash(bi+vec2(5.1,3.0)))*.5+.25;
        float r=length(bf-cp);
        float petal=(1.0-smoothstep(.25,.36,r))*step(.10,hh);
        vec3 col=hh<.58?A:B;
        vec3 near=mix(leafy,col*(.85+.25*lgHash(bi+vec2(9.0,2.0))),petal);
        near=mix(near,vec3(1.0,.88,.35),(1.0-smoothstep(.0,.07,r))*petal*.8);
        vec3 far=mix(leafy,(A+B)*.5,.66);
        float nf=1.0-smoothstep(.12,.42,pixel);
        base=mix(far,near,nf);
      }
    }
    if (fluted && topFace<0.5) {
      float ff=fract(side.x/1.5);
      float fw=clamp(pixel*1.4,0.0,1.0);
      float groove=pow(sin(3.14159*ff),1.4);
      float fillet=1.0-smoothstep(0.0,0.09+fw*.2,min(ff,1.0-ff));
      base*=mix(1.0-.30*groove+.10*fillet,0.86,fw);
    }
    return clamp(base,vec3(.015),vec3(.99));
  }

  vec3 referenceSurface(float mat,vec3 pos,vec2 leafUV) {
    if(mat>99.5)return leagueSurface(mat,pos);
    if(mat>51.5)return exteriorSurface(mat,pos);
    // TEST16 Kanto-only finishes; no changes to any pre-existing material.
    if(mat>34.5 && mat<51.5) {
      vec3 base=vec3(.80,.77,.66);
      if(mat>35.5) base=vec3(0.7,0.59,0.44); // ktOchre
      if(mat>36.5) base=vec3(0.64,0.6,0.51); // ktSandstone
      if(mat>37.5) base=vec3(0.24,0.275,0.28); // ktBasalt
      if(mat>38.5) base=vec3(0.81,0.82,0.75); // ktPlaster
      if(mat>39.5) base=vec3(0.55,0.66,0.57); // ktSage
      if(mat>40.5) base=vec3(0.43,0.31,0.22); // ktCedar
      if(mat>41.5) base=vec3(0.3,0.49,0.43); // ktCopper
      if(mat>42.5) base=vec3(0.57,0.32,0.25); // ktTerracotta
      if(mat>43.5) base=vec3(0.28,0.43,0.59); // ktMarine
      if(mat>44.5) base=vec3(0.67,0.76,0.79); // ktPearl
      if(mat>45.5) base=vec3(0.46,0.34,0.3); // ktBrick
      if(mat>46.5) base=vec3(0.18,0.22,0.28); // ktObsidian
      if(mat>47.5) base=vec3(0.42,0.48,0.53); // ktSteel
      if(mat>48.5) base=vec3(0.58,0.46,0.28); // ktBronze
      if(mat>49.5) base=vec3(0.42,0.35,0.56); // ktViolet
      if(mat>50.5) base=vec3(0.23,0.56,0.64); // ktGlass
      float h=pos.x+pos.z;
      float detail=1.0-smoothstep(.22,1.2,length(fwidth(pos)));
      vec2 uv=vec2(h,pos.y);
      float grain=(forestSoilNoise(uv*2.2)-.5)*.024*detail;
      float broad=(forestSoilNoise(uv*.19)-.5)*.044;
      base+=vec3(grain+broad);
      if((mat>36.5 && mat<38.5)||(mat>45.5 && mat<47.5)) {
        vec2 blockUV=vec2(h/(mat<38.5?7.5:9.0),pos.y/(mat<38.5?3.4:4.0));
        blockUV.x+=mod(floor(blockUV.y),2.0)*.5;
        vec2 edge=min(fract(blockUV),1.0-fract(blockUV));
        vec2 aa=max(fwidth(blockUV),vec2(.003));
        float joint=1.0-smoothstep(.018-aa.x,.018+aa.x,edge.x)*smoothstep(.020-aa.y,.020+aa.y,edge.y);
        base-=vec3(.035)*joint;
      }
      if(mat>40.5 && mat<41.5) {
        float fibre=sin(h*5.3+sin(pos.y*.29)*.7);
        base-=vec3(.03,.025,.019)*smoothstep(.62,.99,fibre)*detail;
      }
      if(mat>41.5 && mat<42.5) base+=vec3(-.015,.018,.008)*(forestSoilNoise(pos.xz*.3)-.5);
      if(mat>50.5) {
        // Broad, static glass value shifts; structural ribs supply real depth.
        base+=vec3(.035,.05,.055)*sin(h*.10+pos.y*.14);
      }
      return clamp(base,0.0,1.0);
    }
    // Lavender-only finishes, appended after all existing material IDs.
    // World-space detail is static, derivative filtered and needs no atlas.
    if (mat>28.5 && mat<34.5) {
      vec3 base=vec3(.565,.445,.515);
      if(mat>29.5) base=vec3(.70,.64,.65);
      if(mat>30.5) base=vec3(.255,.195,.235);
      if(mat>31.5) base=vec3(.49,.465,.49);
      if(mat>32.5) base=vec3(.245,.255,.305);
      if(mat>33.5) base=vec3(.34,.245,.205);
      float h=pos.x+pos.z;
      float detail=1.0-smoothstep(.22,1.2,length(fwidth(pos)));
      vec2 surfaceUV=vec2(h,pos.y);
      float broad=forestSoilNoise(surfaceUV*.17)-.5;
      float grain=forestSoilNoise(surfaceUV*2.7)-.5;
      base+=vec3(broad*.065+grain*.026*detail);
      if((mat>30.5 && mat<31.5)||mat>33.5) {
        // Dark oak: long grain, fine split fibres, gently varied boards.
        float fibre=sin(h*5.6+sin(pos.y*.27)*.7);
        base-=vec3(.030,.024,.027)*smoothstep(.68,.98,fibre)*detail;
        base+=vec3(.018,.012,.009)*sin(h*1.6+sin(pos.y*.11));
      }
      if(mat>31.5 && mat<32.5) {
        vec2 uv=vec2(h/6.8,pos.y/3.5);
        uv.x+=mod(floor(uv.y),2.0)*.5;
        vec2 edge=min(fract(uv),1.0-fract(uv));
        vec2 aa=max(fwidth(uv),vec2(.003));
        float joint=1.0-smoothstep(.022-aa.x,.022+aa.x,edge.x)
                    *smoothstep(.028-aa.y,.028+aa.y,edge.y);
        base-=vec3(.042)*joint;
      }
      if(mat>32.5 && mat<33.5) {
        // Geometry supplies staggered slate edges. Fine mineral grain stays
        // continuous so a second texture grid cannot fight those edges.
        base+=vec3(.012)*sin(pos.z*3.1+pos.x*.43)*detail;
      }
      return clamp(base,0.0,1.0);
    }
    if(mat>27.5 && mat<28.5) return waterBedSurface(pos);
    // TEST122 appends IDs; every pre-existing material retains its index.
    if (mat>23.5 && mat<27.5) {
      if(mat<24.5) return vec3(1.0,.095,.32);
      if(mat<25.5) return vec3(.075,.79,1.0);
      if(mat<26.5) return vec3(1.0,.56,.10);
      return vec3(1.0,.69,.24);
    }
    if (mat>22.5) return forestFloorSurface(pos);
    // TEST92: forest-only materials use continuous world-space grain. The
    // previous 19 material IDs and their shading are unchanged.
    if (mat > 19.5) {
      if (vWorldTree>0.5 && worldTreeTextures>0.5) {
        if (mat<20.5) return Texel(worldTreeBark,fract(vec2((pos.x+pos.z)*.12,pos.y*.055))).rgb;
        // Reuse the approved textured leaf spray on the connected crown mass.
        // Two fixed samples give close detail without alpha overdraw or per-leaf work.
        vec2 q=vec2(pos.x*.37+pos.z*.23,pos.y*.46-pos.z*.19);
        q+=vec2(sin(pos.y*.71+pos.z*.61),sin(pos.x*.81-pos.z*.43))*.34;
        vec4 a=Texel(worldTreeLeaves,fract(q));
        vec2 r=vec2(q.x*.68+q.y*.73,-q.x*.73+q.y*.68)*1.43;
        vec4 b=Texel(worldTreeLeaves,fract(r+vec2(.47,.29)));
        vec3 leaf=mix(vec3(.11,.27,.065),a.rgb,a.a*.88);
        leaf=mix(leaf,b.rgb,b.a*.78);
        if(mat<21.5) leaf*=1.09;
        return leaf;
      }
      if (mat < 20.5) {
        float ridge=sin((pos.x+pos.z)*5.1+sin(pos.y*.61)*.7);
        float groove=smoothstep(.61,.97,ridge)*.10;
        float grain=sin(pos.y*2.1+pos.x*1.7)*sin(pos.z*3.3+pos.y*.3)*.018;
        return clamp(vec3(.33,.255,.17)+grain-groove,0.0,1.0);
      }
      vec3 leaf=mat < 21.5 ? vec3(.255,.445,.175) : vec3(.21,.385,.135);
      if (mat < 21.5) {
        float edge=abs(leafUV.x-.5)*2.0;
        float midrib=1.0-smoothstep(.018,.047,abs(leafUV.x-.5));
        float veins=pow(max(0.0,sin(leafUV.y*43.0-edge*13.0)),10.0)*.018;
        leaf+=vec3(.022,.03,.010)*(1.0-edge)-vec3(midrib*.035+veins);
      }
      float patches=sin(pos.x*.79+sin(pos.z*.53))*sin(pos.y*.67+pos.z*.41)*.022;
      float fine=sin(pos.x*4.3+pos.y*2.2)*sin(pos.z*3.7-pos.y*1.9)*.007;
      return clamp(leaf+vec3(patches+fine),0.0,1.0);
    }
    vec3 base=vec3(.5);
    if (mat < 1.5) base=vec3(0.230,0.390,0.570);
    else if (mat < 2.5) base=vec3(0.910,0.840,0.620);
    else if (mat < 3.5) base=vec3(0.140,0.140,0.170);
    else if (mat < 4.5) base=vec3(0.840,0.360,0.430);
    else if (mat < 5.5) base=vec3(0.270,0.420,0.580);
    else if (mat < 6.5) base=vec3(0.970,0.830,0.470);
    else if (mat < 7.5) base=vec3(0.180,0.340,0.210);
    else if (mat < 8.5) base=vec3(0.360,0.520,0.270);
    else if (mat < 9.5) base=vec3(0.640,0.660,0.630);
    else if (mat < 10.5) base=vec3(0.130,0.240,0.390);
    else if (mat < 11.5) base=vec3(0.590,0.430,0.280);
    else if (mat < 12.5) base=vec3(0.640,0.200,0.180);
    else if (mat < 13.5) base=vec3(0.550,0.610,0.480);
    else if (mat < 14.5) base=vec3(0.270,0.320,0.350);
    else if (mat < 15.5) base=vec3(0.470,0.500,0.490);
    else if (mat < 16.5) base=vec3(0.490,0.240,0.190);
    else if (mat < 17.5) base=vec3(0.560,0.290,0.220);
    else if (mat < 18.5) base=vec3(0.880,0.860,0.760);
    else if (mat < 19.5) base=vec3(0.350,0.250,0.180);
    // Broad world-space variation: no screen-space noise or moving grain.
    float grain=sin(pos.x*.27+pos.z*.19+sin(pos.y*.22))*0.014;
    float wear=sin(pos.x*.071+pos.z*.083)*sin(pos.y*.15)*0.012;
    if (mat<2.5 || abs(mat-11.0)<.4 || mat>17.5) base+=vec3(grain+wear);
    if (abs(mat-9.0)<.4 || abs(mat-15.0)<.4) {
      float course=floor(pos.y/3.0);
      float joint=step(.94,fract((pos.x+pos.z+mod(course,2.0)*3.5)/7.0));
      base*=1.0-joint*.08;
      base+=vec3(wear);
    }
    if (mat>15.5 && mat<17.5) base+=vec3(wear*.7);
    return clamp(base,0.0,1.0);
  }
  LG_PRECISE_OFF
// TEST125: uneven flow bends and breaks the crests across the water.
// Smooth, band-limited detail; all time rates repeat at the existing 40pi wrap.
float gardenHash(vec2 p) {
  vec3 h=fract(vec3(p.xyx)*vec3(.1031,.1030,.0973));
  h+=dot(h,h.yzx+33.33);
  return fract((h.x+h.y)*h.z);
}
float gardenNoise(vec2 p) {
  vec2 i=floor(p),f=fract(p);f=f*f*f*(f*(f*6.0-15.0)+10.0);
  return mix(mix(gardenHash(i),gardenHash(i+vec2(1,0)),f.x),
             mix(gardenHash(i+vec2(0,1)),gardenHash(i+vec2(1,1)),f.x),f.y);
}

// A soft reflection of this room's actual two ceiling-light lanes.
// Cerulean's accepted 5x7 layout has shell bounds (0,16)..(160,224),
// with six 28-unit-target panel columns and six 36-unit-target rows.
// Match InteriorGyms' panel layout, without another canvas or scene pass.
vec3 indoorPoolLight(vec3 pos,vec3 view,float t) {
  vec3 n=normalize(vec3(.014*sin(pos.x*.13+pos.z*.08+t*.35),1.0,
                        .012*sin(pos.z*.19-pos.x*.05-t*.45)));
  vec3 r=reflect(view,n);
  vec2 q=pos.xz+r.xz*((64.0-.9-.35-pos.y)/max(r.y,.08));
  float row=floor((q.y-16.0)/(208.0/6.0));
  float z=16.0+(row+.5)*(208.0/6.0);
  float dx=min(abs(q.x-160.0/12.0),abs(q.x-160.0*11.0/12.0));
  float aa=clamp(length(fwidth(q)),.3,3.0);
  float bar=(1.0-smoothstep(.55,.9+aa,dx))
           *(1.0-smoothstep(8.0,8.5+aa,abs(q.y-z)));
  bar*=step(0.0,row)*step(row,5.0)*smoothstep(.08,.15,r.y);
  float grazing=pow(clamp(1.0-abs(view.y),0.0,1.0),3.0);
  return vec3(.80,.91,.96)*bar*(.18+.35*grazing);
}

// TEST96: quiet water, with a refracted bed in the low-cost fallback.
// The reflective path replaces this bed hint with the actual captured basin.
vec3 indoorPoolColor(LOVE_HIGHP_OR_MEDIUMP vec3 pos, vec3 view, float t) {
  vec2 bedUV=pos.xz+clamp(view.xz/max(abs(view.y),.35),vec2(-2.0),vec2(2.0))*7.5;
  bedUV+=vec2(sin(pos.z*.15+t*.35),sin(pos.x*.18-t*.45))*.30;
  float grazing=pow(clamp(1.0-abs(view.y),0.0,1.0),3.0);
  vec3 bed=indoorPoolBed(bedUV,t)*vec3(.70,.94,.98);
  vec3 body=mix(bed,vec3(.105,.29,.33),.26+grazing*.48);
  float ripple=sin(pos.x*.13+pos.z*.08+t*.35)*sin(pos.z*.19-pos.x*.05-t*.45);
  return body+vec3(.004,.009,.011)*ripple;
}

float gardenRipple(vec2 q, float t) {
  vec2 drift=vec2(cos(t*.10),sin(t*.10))*3.0;
  float flow=gardenNoise(q*.034+drift);
  float crossFlow=gardenNoise(q*.049+vec2(-drift.y,drift.x)+vec2(13.4,7.8));
  vec2 bent=q+(vec2(flow,crossFlow)-.5)*26.0;
  vec2 span=fwidth(bent);
  vec3 fade=1.0-smoothstep(vec3(.65),vec3(2.2),vec3(
    dot(span,vec2(.24,.07)),dot(span,vec2(.08,.37)),length(span)*.32));
  float fine=gardenNoise(bent*.19+drift*1.5)*2.0-1.0;
  return .50*fade.x*(.4+.6*crossFlow)*sin(dot(bent,vec2(.24,.07))+t*.85)
       + .30*fade.y*sin(dot(bent,vec2(-.08,.37))-t*1.25+flow*5.0)
       + .20*fade.z*fine;
}

  // TEST100: LÖVE declares this entry point before our source, while the
  // GLES default is mediump. Match that public signature explicitly; the
  // procedural finish helpers keep their separately scoped highp default.
  mediump vec4 effect(mediump vec4 color, Image tex, mediump vec2 tc, mediump vec2 sc) {
    // TEST177: the surface normal for every reference finish (see refNormal).
    // In uniform control flow, ahead of any discard. The derivatives are
    // scaled up before the cross product and the result divided by its
    // largest component before it is normalised, so nothing underflows
    // even where the float is half precision.
    {
      LOVE_HIGHP_OR_MEDIUMP vec3 rdx = dFdx(vFoliageRay) * 8.0;
      LOVE_HIGHP_OR_MEDIUMP vec3 rdy = dFdy(vFoliageRay) * 8.0;
      LOVE_HIGHP_OR_MEDIUMP vec3 rn = cross(rdx, rdy);
      LOVE_HIGHP_OR_MEDIUMP float rm = max(max(abs(rn.x), abs(rn.y)), abs(rn.z));
      refNormal = rm > 0.0 ? normalize(rn / rm) : vec3(0.0, 1.0, 0.0);
    }
    if (reflectionClip.x > 0.5 && vFoliageRay.y > reflectionClip.y) discard;
    // Only the observer's own building, in the isolated scenic pass. Keep
    // ground/water beneath it and every surrounding building unchanged.
    if (scenicHideOn > 0.5) {
      vec3 here = vFoliageRay + eye;
      if (here.y > 0.5 && here.x >= scenicHideRect.x && here.z >= scenicHideRect.y
          && here.x <= scenicHideRect.z && here.z <= scenicHideRect.w) discard;
    }
    if (foliageCutOn > 0.5 && (foliageNativeOnly < 0.5
        || (vReferenceMaterial > 19.5 && vReferenceMaterial < 22.5)
        || (vReferenceMaterial > 94.5 && vReferenceMaterial < 97.5))) {
      float opening = max(foliageOpening(vFoliageRay, foliageTargetA),
                          foliageOpening(vFoliageRay, foliageTargetB));
      // A camera inside a native crown needs a broad near-field opening,
      // not just two peepholes. Limit it to geometry ahead of the eye and
      // nearer than both subjects; retain the forest behind the Pokemon.
      if (foliageNativeOnly > 0.5
          && dot(vFoliageRay,foliageTargetA+foliageTargetB)>0.0) {
        float distance=length(vFoliageRay);
        float subjectDistance=max(1.0,min(length(foliageTargetA),length(foliageTargetB)));
        float nearOpening=(1.0-smoothstep(32.0,40.0,distance))
          *(1.0-smoothstep(.75,.95,distance/subjectDistance));
        opening=max(opening,nearOpening);
      }
      // TEST140: keep the arena floor and low ground intact; only rock,
      // walls, ceilings and props above it open toward the camera.
      if (vFoliageRay.y + eye.y < sightFloor) opening = 0.0;
      if (opening > foliageThreshold(sc)) discard;
    }

    // Enterable overworld buildings carry their south/front skin as a
    // one-sided surface. During a door transition the camera can briefly
    // stand north of that skin; discard its back instead of filling the
    // lens with mirrored facade/door art. Genuine rear and side walls keep
    // ordinary positive shade values and remain double-sided.
    if (vFacadeBack > 0.5) discard;
    // Native forest UVs describe veins; ROM atlas alpha must not cut holes.
    // TEST176: the routes' grass (198..215) keeps its atlas texel to tint.
    bool routeGrass = vReferenceMaterial>197.5 && vReferenceMaterial<215.5;
    vec4 p = !routeGrass && ((vReferenceMaterial>19.5 && vReferenceMaterial<93.5) || vReferenceMaterial>99.5) ? vec4(1.0) : Texel(tex, tc);
    // Effects carry continuous coverage, independently of their emissive RGB.
    // Keep this ahead of the world sprite cutout and all scene illumination.
    if (effectSurface > 0.5) return p * color;
    // sprite sheets key GB OBJ color 0 to alpha 0; discarding rather than
    // blending keeps those texels out of the depth buffer, so a model never
    // carves a transparent hole out of whatever stands behind it
    if (p.a < 0.5) discard;
#ifndef LG_PROBE_LITE
    // TEST189: PerfProbe's per-family FLAT steps compile one family of
    // finishes out at a time (LG_FLAT_*); no define, no change.
    if (vReferenceMaterial>93.5 && vReferenceMaterial<99.5) {
#ifndef LG_FLAT_TINT
      p.rgb*=exteriorAtlasCraft(vFoliageRay+eye);
#endif
    } else if (routeGrass) {
#ifndef LG_FLAT_TINT
      p.rgb=routeTint(vReferenceMaterial,vFoliageRay+eye,p.rgb);
#endif
    } else if (vReferenceMaterial>0.5) {
#ifdef LG_FLAT_FOREST
      if (vReferenceMaterial<28.5) p.rgb=vec3(.55,.55,.5); else
#endif
#ifdef LG_FLAT_TOWN
      if (vReferenceMaterial>28.5 && vReferenceMaterial<51.5) p.rgb=vec3(.55,.55,.5); else
#endif
#ifdef LG_FLAT_EXTERIOR
      if (vReferenceMaterial>51.5 && vReferenceMaterial<93.5) p.rgb=vec3(.55,.55,.5); else
#endif
#ifdef LG_FLAT_HIGH
      if (vReferenceMaterial>99.5) p.rgb=vec3(.55,.55,.5); else
#endif
      p.rgb=referenceSurface(vReferenceMaterial,vFoliageRay+eye,tc);
    }
#else
    // TEST184 PERF PROBE only: no procedural finishes at all (flat colour)
    if (vReferenceMaterial>0.5) p.rgb=vec3(.55,.55,.5);
#endif
    // Explicit native foliage IDs, or the first two pine tiles of the
    // seasonal atlas during its outdoor draw only. No color-key guessing:
    // bark, ornaments, bulbs, characters and buildings never enter this path.
    bool nativePine = vReferenceMaterial > 20.5 && vReferenceMaterial < 22.5;
    bool leagueFoliage = vReferenceMaterial > 126.5 && vReferenceMaterial < 129.5;
    bool seasonalPine = seasonalPineRegion.x > 0.0 && tc.x < seasonalPineRegion.x
                     && tc.y < seasonalPineRegion.y && vReferenceMaterial < 0.5;
    if (treeAutumn > 0.5 && nativePine && vTropic < 0.5) {
      // TEST136: one dominant color per crown, not leaf-scale camouflage.
      // A low-frequency world field (about one crown across) chooses gold,
      // orange or red, so neighbouring trees differ while each crown reads
      // as a single mass. Fixed world coordinates keep colors still in wind.
      vec3 pos=vFoliageRay+eye;
      float crown=.5+.30*sin(pos.x*.115+sin(pos.z*.083)*1.9)
                    +.20*sin(pos.z*.137-pos.x*.051+1.3);
      // Small in-crown drift only between adjacent palette colors.
      float drift=.07*sin(pos.x*.61+pos.y*.47)*sin(pos.z*.53-pos.y*.39);
      float t=clamp(crown+drift,0.0,1.0);
      // A few late crowns keep a yellow-green cast, then gold, orange, red.
      vec3 fall=mix(vec3(.47,.47,.14),vec3(.62,.46,.12),smoothstep(.04,.18,t));
      fall=mix(fall,vec3(.66,.32,.08),smoothstep(.24,.50,t));
      fall=mix(fall,vec3(.55,.15,.07),smoothstep(.58,.84,t));
      // Sunlit outer faces stay bright; inner/under faces deepen to rust.
      float lit=smoothstep(.70,1.0,vShade);
      fall=mix(fall*vec3(.80,.66,.58),fall,.45+.55*lit);
      // Keep the leaf texture as gentle relief rather than dark veining.
      float leafL=dot(p.rgb,vec3(.2126,.7152,.0722));
      float detail=clamp(.50+leafL*1.70,.50,1.26);
      p.rgb=fall*detail;
    }
    if (treeSnow > 0.5 && (nativePine || seasonalPine || leagueFoliage)) {
      vec3 pos = vFoliageRay + eye;
      float drifts = .5 + .25*sin(pos.x*.37+pos.z*.23)
                         + .25*sin(pos.y*.43-pos.z*.31);
      // Face light already encodes crown form. Retain shaded green pockets
      // below snow-covered crowns; broad stable patches avoid sparkling.
      float cover = smoothstep(.73,.92,vShade) * (.72+.28*drifts);
      vec3 powder = vec3(.91,.955,.98) * (.96+.04*drifts);
      p.rgb = mix(p.rgb,powder,cover);
    }
    // One common finish for Tower stone, limited to the wall atlas region.
    if (towerStoneOn > 0.5 && tc.x > towerStoneRegion.x && tc.y >= towerStoneRegion.y
        && tc.x < towerStoneRegion.z && tc.y < towerStoneRegion.w) {
      // Honed overhead stone: retain its grain but restrain bright veins.
      // Veined black walls and honed purple trim use one amethyst palette.
      float quiet = towerStoneQuiet;
      if (quiet < 0.001) {
        // Calm only the newly carved upper-wall band; the main slab stays
        // untouched. World height keeps every wall orientation consistent.
        quiet = 0.65 * smoothstep(53.7, 55.5, (vFoliageRay + eye).y);
      }
      p.rgb = mix(p.rgb, towerStoneHoned, quiet) * towerStoneTint;
    }
    // UNLIT is an exact texture pass, not merely a zero-weight blend with
    // the lit result. Some GLSL drivers still evaluate both sides of mix(),
    // including the shadow lookup, and have shown pieces of that result on
    // battle cards even when lightOn was zero. Returning here guarantees an
    // UNLIT card cannot receive face light, the day tint, voxel seams, glass
    // or any cast/self shadow.
    if (lightOn < 0.5) {
      return vec4(mix(p.rgb, ghostColor, ghost), 1.0) * color;
    }
#ifdef UNLIT_ONLY
    // A separately compiled card shader. Unlike a uniform branch in the
    // scene shader, this program contains no live day/shadow calculation for
    // a driver to evaluate or fold incorrectly. Ghost remains for hit flashes.
    return vec4(mix(p.rgb, ghostColor, ghost), 1.0) * color;
#endif
    // Low-cost battle fallback when reflective water is OFF or unavailable.
    // World coordinates keep the material continuous across tile/neighbor seams.
    if (battleWaterOn > 0.5) {
      vec2 waterPos = (vFoliageRay + eye).xz;
      float broad = .5 + .25*sin(waterPos.x*.027 + waterPos.y*.013)
                       + .25*cos(waterPos.y*.033 - waterPos.x*.009);
      float ripple = gardenRipple(waterPos,battleWaterPhase);
      p.rgb = mix(vec3(.13,.25,.34), vec3(.22,.37,.45), broad)
            + vec3(.040,.075,.100)*ripple
            + vec3(.030,.058,.076)*smoothstep(.36,.88,ripple);
      if (indoorPoolOn > .5) {
        vec3 ray=vFoliageRay/max(length(vFoliageRay),.001);
        p.rgb=indoorPoolColor(vec3(waterPos.x,0.0,waterPos.y),ray,battleWaterPhase)
             +indoorPoolLight(vFoliageRay+eye,ray,battleWaterPhase);
      }
    }
    // the hour's tint multiplies like the sun terms do: it is LIGHT, the
    // same warm or moonlit cast on every surface, not a palette swap
    // TEST170: League crowns (127..129) are painted in two tones, the way
    // a stylised tree is: a warm, sunlit side and a cool, deep shaded side
    // meeting at a soft terminator (the crown's own per-vertex light and
    // the cast shadows decide which), so each crown reads as a solid, round
    // mass instead of one flat dark green. Edges turned away from the eye
    // catch a rim of light through the leaves, which lifts every crown off
    // whatever stands behind it; after dark the moon silvers the lit side.
    float sunL = sunlight(vSun);
    vec3 litRgb = p.rgb * vShade * sunL
                * modelSunlight(vModelSun) * dayTint;
    // TEST172: the League rooms' self-lit finishes -- ice crystal (133),
    // lava (136), stained glass (139) and the night sky (140) -- give off
    // their own light: neither the sun's shadow nor the hour dims them.
    if (vReferenceMaterial > 132.5 && vReferenceMaterial < 140.5) {
      float m = vReferenceMaterial;
      float em = m < 133.5 ? .78 : ((m > 135.5 && m < 136.5) ? 1.0 : ((m > 138.5 && m < 139.5) ? .72 : (m > 139.5 ? 1.0 : 0.0)));
      vec3 selfLit = p.rgb * (m > 139.5 ? 1.0 : clamp(vShade, .30, 1.80));
      litRgb = mix(litRgb, selfLit, em);
    }
    // TEST173: the interiors' screens, lamp shades, aquarium water, paper
    // screens, window views and light panels (166..171) are their own light
    // TEST176: and the cave mouths' crystals and glowing fungi (222)
    if ((vReferenceMaterial > 165.5 && vReferenceMaterial < 171.5) || (vReferenceMaterial > 183.5 && vReferenceMaterial < 184.5)
        || (vReferenceMaterial > 221.5 && vReferenceMaterial < 222.5)) {
      float m = vReferenceMaterial;
      float em = (m > 167.5 && m < 168.5) ? .85 : ((m > 168.5 && m < 169.5) ? .70 : 1.0);
      litRgb = mix(litRgb, p.rgb, em);
    }
    if (vReferenceMaterial > 126.5 && vReferenceMaterial < 129.5) {
      float amt = vShade * mix(1.0, sunL, .80);
      float band = smoothstep(.56, .84, amt);
      vec3 litC = p.rgb * vec3(1.20,1.15,.84) * (1.02 + .22*amt);
      vec3 shdC = p.rgb * vec3(.60,.74,.96) * (.62 + .30*amt);
      vec3 fl = mix(shdC, litC, band) * modelSunlight(vModelSun) * dayTint;
      vec3 fn = refNormal;
      float rim = pow(clamp(1.0 - abs(dot(fn, normalize(vFoliageRay))), 0.0, 1.0), 2.4);
      fl += p.rgb * vec3(1.0,1.06,.72) * rim * (.20 + .40*band) * dayTint * (1.0 - .45*glassNight);
      fl += vec3(.050,.078,.130) * glassNight * (band*.85 + rim*.55);
      fl += p.rgb * dayTint * (.05 + .05*glassNight);
      litRgb = fl;
    }
    if(vReferenceMaterial>22.5 && vReferenceMaterial<23.5)
      litRgb=forestFloorLighting(p.rgb,litRgb,dayTint);
    vec3 rgb = litRgb;
    if(vMasonry>0.5){
      vec3 world=vFoliageRay+eye;
      rgb*=exteriorAtlasCraft(world);
    }
    rgb+=p.rgb*vec3(.95,.53,.18)*vDockWarm*glassNight;
    if (fireLightPower > 0.001) {
      rgb += p.rgb * vec3(1.65,0.90,0.23) * breathLight();
    }
    if (streetLampOn > 0.001) {
      rgb *= mix(vec3(1.0),vec3(0.88,0.91,0.97),streetLampOn);
      float pool=min(1.0,streetPool(streetLampA)+streetPool(streetLampB)
        +streetPool(streetLampC)+streetPool(streetLampD));
      rgb += p.rgb * vec3(0.88,0.55,0.24) * pool * streetLampOn;
    }
#ifdef VOXEL_GRID
    // darken what is there rather than painting a colour, so a seam across
    // dark grass and one across a white roof each stay in their own palette
    // Submerged mineral surfaces have no voxel wireframe; other settings stay.
    float bed=step(27.5,vReferenceMaterial)*(1.0-step(28.5,vReferenceMaterial));
    // TEST165: League finishes are not voxels (TEST176: the routes' grass
    // is still the atlas turf, and keeps its seams)
    bed=max(bed,step(99.5,vReferenceMaterial)*(1.0-step(197.5,vReferenceMaterial)*(1.0-step(215.5,vReferenceMaterial))));
    rgb *= 1.0 - gridDark * (1.0-battleWaterOn) * (1.0-bed) * voxelSeam(vGrid);
#endif
    // WINDOW GLASS, marked per atlas texel by the mask (see GlassMask).
    // By day a thin diagonal glint crosses the panes WHILE THE VIEW MOVES
    // -- the phase is fed by the camera's own travel and the strength dies
    // within a beat of standing still, because a reflection is something
    // the viewpoint does: still camera, still glass. It lifts the texel
    // toward sky-white and leaves the art visible through it. After dark
    // the pane is LIT: the texel's own shine pattern carried into a warm
    // lamp colour, replacing the shaded answer above -- so a lit window
    // ignores the sun, every shadow and the hour's tint, exactly as a
    // window with a lamp behind it does.
    // glassOn gates the whole thing per DRAW: the mask is shaped like the
    // tileset atlas, and only meshes textured FROM that atlas may consult
    // it -- a character samples its own sprite sheet, whose coordinates
    // land on the mask's pane rectangles by accident and would stripe the
    // cast with lamplight at night.
    // TEST20: native leaf UVs span 0..1 for veins, not the tileset atlas.
    // Sampling the window mask at those UVs paints gold speckles at night
    // and moving glass glints by day. Explicit lantern tags remain separate.
    bool leafCoordinates = vWorldTree>0.5 || (vReferenceMaterial>20.5 && vReferenceMaterial<21.5);
    float atlasGlass = (leafCoordinates || (vReferenceMaterial>51.5 && vReferenceMaterial<93.5) || vReferenceMaterial>99.5) ? 0.0 : Texel(glassMask, tc).a;
    float glass = max(atlasGlass, vLantern) * glassOn * (1.0-battleWaterOn);
    if (glass > 0.0) {
      // the sweep lives in the PANE's own space (atlas texels), not the
      // screen's: a pattern anchored to the screen has the world sliding
      // through it at zoom speed whenever the camera pans, which strobed --
      // worst where the pan and the phase ran opposite ways. Anchored to
      // the glass, panning moves nothing; only the phase does, a fraction
      // of a texel per step, the same in every walking direction.
      float sweep = sin(tc.x * glassSize.x * 0.8 - glassPhase);
      float glint = pow(max(sweep, 0.0), 20.0) * 0.55 * glassGlint;
      vec3 pane = mix(rgb, vec3(0.93, 0.97, 1.0), glint * glass);
      float shine = dot(p.rgb, vec3(0.299, 0.587, 0.114));
      vec3 lamp = vec3(1.0, 0.84, 0.5) * (0.5 + 0.55 * shine);
      rgb = mix(pane, lamp, glassNight * glass);
    }
    // Physical tubes stay luminous without the warm window-glass recolor.
    // Their steady colored casing and pale core retain legible lettering.
    if(vReferenceMaterial>23.5 && vReferenceMaterial<27.5) {
      float core=clamp((vShade-1.0)*1.54,0.0,1.0);
      vec3 tube=mix(p.rgb,vec3(1.0,.96,.86),core*.76);
      float chase=1.0;
      if(vReferenceMaterial>26.5) {
        vec3 world=vFoliageRay+eye;
        chase=.64+.36*smoothstep(-.25,.80,sin(world.x*.32+world.z*.13-casinoPhase));
      }
      rgb=mix(litRgb,tube*chase,.50+.50*clamp(glassNight,0.0,1.0));
    }
    // Haze is air between the camera and the finished surface, so it lands
    // after lighting, shadows, seams and glass but before the ghost overlay.
    rgb = mix(rgb, fogColor, vFog);
    // The hidden player is a SHAPE, not a dimmed picture of itself. Tinting
    // through `color` could only multiply the sprite's own pixels, which
    // darkens each one by its own amount and keeps the character's internal
    // detail; replacing the colour outright is what makes it read as one
    // solid silhouette. Last in the chain, so neither the sun nor a voxel
    // seam can mottle it.
    rgb = clamp(rgb * weatherMul + weatherAdd, 0.0, 1.0);
    rgb = mix(rgb, weatherHazeColor, min(0.28, 1.0-exp(-weatherHaze*weatherDistance)));
    rgb = mix(rgb, ghostColor, ghost);
    return vec4(rgb, 1.0) * color;
  }
#endif
]]

-- TEST105: retain the complete known-working source as the fallback.
-- Only the small bark formula differs; no derivatives, new uniforms or passes.
local BARK_OLD = [[
        float ridge=sin((pos.x+pos.z)*5.1+sin(pos.y*.61)*.7);
        float groove=smoothstep(.61,.97,ridge)*.10;
        float grain=sin(pos.y*2.1+pos.x*1.7)*sin(pos.z*3.3+pos.y*.3)*.018;
        return clamp(vec3(.33,.255,.17)+grain-groove,0.0,1.0);
]]
local BARK_NEW = [[
        float along=pos.x*.83+pos.z*.71;
        float ridge=sin(along*3.7+sin(pos.y*.075)*.22);
        float groove=smoothstep(.72,.98,ridge)*.042;
        float grain=sin(along*13.1+pos.y*.04)*.012;
        return clamp(vec3(.33,.255,.17)+grain-groove,0.0,1.0);
]]
local barkStart,barkEnd=SHADER:find(BARK_OLD,1,true)
local DETAIL_SHADER=barkStart and (SHADER:sub(1,barkStart-1)..BARK_NEW..SHADER:sub(barkEnd+1))or SHADER
-- Preserve the working TEST33 shader source exactly. Log driver failures
-- once per attempted variant; the existing shader cache prevents frame spam.
local function reportShaderFailure(prefix,variant,err)
 local mode=prefix:find("VOXEL_GRID",1,true) and "grid"
   or prefix:find("UNLIT_ONLY",1,true) and "unlit" or "scene"
 local logger=V.mod and V.mod.log
 if logger and logger.error then
  pcall(logger.error,logger,"TEST37 Voxel shader %s/%s rejected: %s",
    mode,variant,tostring(err))
 end
end
-- TEST37/TEST93: last resort, the current scene shader minus the TEST28
-- tree snow/autumn uniforms and block. Their sends are pcall'd and simply do
-- nothing there, so a driver that refuses the seasonal foliage code still
-- gets the full 3D world instead of a 2D fallback.
local LEGACY_SHADER,LEGACY_DETAIL
do
 local foliageStart=SHADER:find("    // Explicit native foliage IDs, or the first two pine tiles",1,true)
 local tail="      p.rgb = mix(p.rgb,powder,cover);\n    }\n"
 local snowLine=foliageStart and SHADER:find(tail,foliageStart,true)
 if foliageStart and snowLine then
  local foliageEnd=snowLine+#tail-1
  LEGACY_SHADER=SHADER:sub(1,foliageStart-1)..SHADER:sub(foliageEnd+1)
  -- The PIXEL block also owns scenic-hide and sight-floor uniforms. Keep
  -- those (and their stage precision) when removing seasonal declarations.
  for _,decl in ipairs({"  uniform float treeSnow;\n",
    "  uniform float treeAutumn;\n","  uniform vec2 seasonalPineRegion;\n"})do
   local a,b=LEGACY_SHADER:find(decl,1,true)
   if a then LEGACY_SHADER=LEGACY_SHADER:sub(1,a-1)..LEGACY_SHADER:sub(b+1)end
  end
  local a,b=LEGACY_SHADER:find(BARK_OLD,1,true)
  LEGACY_DETAIL=a and (LEGACY_SHADER:sub(1,a-1)..BARK_NEW..LEGACY_SHADER:sub(b+1))or LEGACY_SHADER
 end
end
Voxel3D.LEGACY_SHADER=LEGACY_SHADER
Voxel3D.LEGACY_DETAIL=LEGACY_DETAIL
Voxel3D.shaderVariant={}
local function compileSceneShader(prefix)
 local attempts={{"detail",DETAIL_SHADER},{"fallback",SHADER},
   {"legacy-detail",LEGACY_DETAIL},{"legacy",LEGACY_SHADER}}
 local seen={}
 for _,a in ipairs(attempts)do
  local name,src=a[1],a[2]
  if src and not seen[src]then
   seen[src]=true
   local ok,sh=pcall(love.graphics.newShader,prefix..src)
   if ok and sh then Voxel3D.shaderVariant[prefix]=name;return sh end
   reportShaderFailure(prefix,name,sh)
  end
 end
 return false
end

-- Three compilations of SHADER: the plain scene, the same thing with the
-- voxel wireframe compiled in, and a card-only true-colour variant. The
-- wireframe needs shader derivatives
-- (fwidth), the one piece of this a driver can refuse, so it is a separate
-- build rather than a branch -- a refusal costs the grid and nothing else.
-- Each entry is nil = untried, false = unavailable.
local shaders = { [false] = nil, [true] = nil }
local unlitShader = nil       -- nil = untried, false = unavailable
local backdropShader = nil    -- optional soft focus for low-res flat plates
local effectLightOn = 1
local activeShader = nil      -- the shader draws are currently sent to
local sceneShader = nil       -- the lit variant this pass opened with
local flattenColor = nil      -- tightly scoped hit-flash state for shader swaps
local flattenAmount = 0

-- Scene canvases, one per NAMED SLOT. There are exactly two callers and
-- they want different sizes -- the free-roam pass renders at the window's
-- pixel dimensions, the overworld battle at the GB's 160x144 -- and a
-- single cached canvas made every battle entry and exit reallocate one.
-- A slot reallocates only when its OWN size changes, which is a window
-- resize, so the pair is stable for a session.
local slots = {}
local canvas, canvasW, canvasH = nil, 0, 0   -- the slot this pass bound
local held = nil                             -- and the whole record for it
local active = false

-- TEST266 ISOLATION BUILD: keep an owned depth attachment for ordinary
-- occlusion, but do not make it a sampled texture. Water OFF in earlier
-- builds still used a readable depth texture; it did not test this path.
-- Set true before the next beginScene to restore TEST265's depth policy.
-- This is a diagnostic switch, not a confirmed fix for the handheld crash.
Voxel3D.SAMPLED_DEPTH = false

-- A READABLE depth canvas, so a later pass in the same frame can ask the
-- buffer questions rather than only write to it -- which is the whole of
-- what makes screen-space reflections possible (see Water).
--
-- `depth = true` in the target list, which is what this used to bind,
-- allocates an internal depth buffer that is written and tested and can
-- never be sampled. An explicit canvas is the same buffer with a texture
-- handle on it, and costs the same memory.
--
-- nil where the driver will not make one -- every depth format is optional
-- in GLES and a canvas is the only honest test of any of them, so this asks
-- for several in order of preference: 24 bits, the same 24 riding a stencil
-- (a pairing some mobile drivers will texture when the bare format they
-- refuse), 32-bit float, and 16 as the floor every GLES3 device can read.
-- Refused all four, beginScene falls straight back to the internal buffer,
-- which is exactly the old behaviour minus the reflections.
local DEPTH_FORMATS = { "depth24", "depth24stencil8", "depth32f", "depth16" }

local function newDepth(w, h)
  if not (love.graphics and love.graphics.newCanvas) then return nil end
  local readable = Voxel3D.SAMPLED_DEPTH ~= false
  local c = nil
  for _, format in ipairs(DEPTH_FORMATS) do
    -- This is attached to the scene canvas and sampled by Water. Both are
    -- created through PixelCanvas so Android gives them the same low DPI.
    local ok, made = PixelCanvas.new(w, h,
                                     { format = format, readable = readable })
    if ok and made then c = made break end
  end
  if not c then return nil end
  -- A non-readable Canvas is a depth renderbuffer. Keep it explicitly owned
  -- (rather than a temporary depth=true attachment) across canvas switches,
  -- and never call texture filtering/sampling methods on it.
  if not readable then return c end
  -- nearest: a depth is a distance, and a blend of two of them is a
  -- distance to nothing. The march wants the texel it landed on.
  pcall(c.setFilter, c, "nearest", "nearest")
  pcall(c.setWrap, c, "clamp", "clamp")
  -- and no compare mode: with one set, Texel returns a 0/1 shadow verdict
  -- instead of the depth, which is not what any reader here wants
  pcall(c.setDepthSampleMode, c)
  return c
end

-- The bound target for the slot this pass holds: the colour canvas plus
-- either the readable depth canvas or the internal buffer.
local function depthTarget()
  if held and held.depth then
    return { held.canvas, depthstencil = held.depth }
  end
  return { canvas, depth = true }
end

local function sampledSceneDepth()
  if held and held.sampledDepth ~= false then return held.depth end
end

-- Every GPU object one slot owns. The mirror is the copy of the frame the
-- water pass reads (see beginWater); it is only ever made if something asks
-- for one, so a session that never sees a lake never pays for it.
local function releaseSlot(slotHeld)
  for _, key in ipairs({ "canvas", "depth", "mirror", "cast", "castDepth", "underColor", "underDepth" }) do
    local obj = slotHeld[key]
    if obj and obj.release then pcall(obj.release, obj) end
    slotHeld[key] = nil
  end
end

local IDENTITY = Mat4.identity()

-- Whether the driver admits to supporting derivatives. Only a hint --
-- the compile below is the real test -- but it saves building a shader
-- that was never going to work, and it is how LOVE reports the ES2
-- extension the grid rides on.
local function derivativesOK()
  if not (love.graphics and love.graphics.getSupported) then return false end
  local ok, caps = pcall(love.graphics.getSupported)
  return ok and caps and caps.shaderderivatives == true
end

-- The scene shader. `grid` asks for the wireframe variant, and nil comes
-- back when that one will not build -- callers then fall back to the plain
-- one rather than losing the whole 3D pass.
-- TEST183: SHADER PRECISION (PERFORMANCE). FULL runs the procedural
-- finishes in full precision on a phone (no grids or planks on the routes);
-- FAST leaves them at the GPU's half precision (TEST180's cost, and its
-- look). A change drops the compiled shaders; the next frame rebuilds them.
local okSetting, ModSetting = pcall(V.require, "ModSetting")
Voxel3D.precisionSetting = okSetting and ModSetting.new("legendaryShaderPrecision", "SHADER PRECISION",
  { "full", "fast" }, { "FULL", "FAST" }, 1) or nil
local liteShader = nil
-- TEST189: the probe's variants (see probeShaderFor), declared here so the
-- precision switch below can release them
local probeShaders = {}
local function releaseProbeShaders()
  for k, sh in pairs(probeShaders) do
    if sh and sh.release then pcall(sh.release, sh) end
    probeShaders[k] = nil
  end
end
local compiledPrecision = nil
local function precisionPrefix()
  local fast = false
  if Voxel3D.precisionSetting then
    local ok, v = pcall(Voxel3D.precisionSetting.get, Voxel3D.precisionSetting)
    fast = ok and v == "fast"
  end
  if compiledPrecision ~= nil and compiledPrecision ~= fast then
    for k, sh in pairs(shaders) do
      if sh and sh.release then pcall(sh.release, sh) end
      shaders[k] = nil
    end
    if unlitShader and unlitShader.release then pcall(unlitShader.release, unlitShader) end
    unlitShader = nil
    if liteShader and liteShader.release then pcall(liteShader.release, liteShader) end
    liteShader = nil
    releaseProbeShaders()
  end
  compiledPrecision = fast
  return fast and "#define LG_FAST_PRECISION 1\n" or ""
end
-- TEST184: PerfProbe's FLAT SURFACES step. A separate compilation with the
-- finishes compiled out, used only while V.perfProbe.lite is set.
Voxel3D.shaderProfile = nil
-- TEST189: the probe's variants, keyed "profile|defines"; released with the
-- other caches on a precision change and on invalidate.
local function profileDefines(profile)
  if profile == "kanto" and Voxel3D.SPLIT_SHADER ~= false then
    return "#define LG_STRIP_LEAGUE 1\n#define LG_STRIP_ROOMS 1\n"
  end
  return ""
end
function Voxel3D.probeShaderFor(variant, profile)
  local pp = precisionPrefix()
  local key = tostring(profile == "kanto" and Voxel3D.SPLIT_SHADER ~= false and "kanto" or "full")
              .. "|" .. tostring(variant)
  if probeShaders[key] == nil then
    local defs = ""
    for name in tostring(variant):gmatch("[%w_]+") do defs = defs .. "#define " .. name .. " 1\n" end
    probeShaders[key] = compileSceneShader(pp .. profileDefines(profile) .. defs) or false
  end
  return probeShaders[key] or nil
end
-- Compile the next not-yet-built variant; true while there is more to do.
function Voxel3D.precompileProbe(variants, profile)
  local pp = precisionPrefix()
  for _, v in ipairs(variants or {}) do
    local key = tostring(profile == "kanto" and Voxel3D.SPLIT_SHADER ~= false and "kanto" or "full")
                .. "|" .. tostring(v)
    if probeShaders[key] == nil then
      if not Voxel3D.probeShaderFor(v, profile) then
        error("Probe shader failed: " .. tostring(v))
      end
      return true
    elseif probeShaders[key] == false then
      error("Probe shader failed: " .. tostring(v))
    end
  end
  return false
end

function Voxel3D.shader(grid)
  grid = grid and true or false
  local pp = precisionPrefix()
  local probe = V.perfProbe
  -- TEST189: a probe step's compile-time variant (probe.variant, a list of
  -- defines), on top of the profile in force, so it is compared like with
  -- like. Cached per profile + variant in probeShaders; compiled ahead of
  -- the measurement by Voxel3D.precompileProbe.
  if probe and (probe.variant or probe.lite) then
    local sh = Voxel3D.probeShaderFor(probe.variant or "LG_PROBE_LITE", Voxel3D.shaderProfile)
    if sh then return sh end
  end
  -- TEST187: out of doors in Kanto (VoxelScene sets the profile per frame)
  -- the scene shader is compiled without the League's and the rooms'
  -- finishes, which no map there uses: a smaller program, more of it in
  -- flight at once on a phone's GPU. The probe's step forces it anywhere.
  if (probe and probe.strip) or (Voxel3D.shaderProfile == "kanto" and Voxel3D.SPLIT_SHADER ~= false) then
    local key = grid and "kanto_grid" or "kanto"
    if shaders[key] == nil then
      if grid and not derivativesOK() then
        shaders[key] = false
      else
        shaders[key] = compileSceneShader(pp .. "#define LG_STRIP_LEAGUE 1\n#define LG_STRIP_ROOMS 1\n"
          .. (grid and "#define VOXEL_GRID 1\n" or "")) or false
      end
    end
    if shaders[key] then return shaders[key] end
  end
  if shaders[grid] == nil then
    if grid and not derivativesOK() then
      shaders[grid] = false
    else
      shaders[grid] = compileSceneShader(pp .. (grid and "#define VOXEL_GRID 1\n" or ""))
    end
  end
  return shaders[grid] or nil
end

-- A card-only compilation with lighting removed at compile time. It keeps the
-- scene vertex transform, so cards retain perspective, depth and placement;
-- only their pixel colour is an exact copy of the authored texture.
function Voxel3D.unlitShader()
  local pp = precisionPrefix()
  if unlitShader == nil then
    unlitShader = compileSceneShader(pp .. "#define UNLIT_ONLY 1\n")
  end
  return unlitShader or nil
end

-- A small source-space Gaussian blur for illustrated battle plates. The
-- source images are intentionally only 800x800; blurring in SOURCE texels
-- means the softness grows with their enlargement and conceals that native
-- resolution, while remaining subtle at 1:1. Compilation refusal is harmless:
-- backdrop() simply keeps LOVE's ordinary linear-filtered draw.
local BACKDROP_BLUR = [[
#ifdef PIXEL
  uniform vec2 texel;
  uniform float radius;
#endif

  vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vec4 clip = transform_projection * vertex_position;
    clip.z = clip.w;
    return clip;
  }

  vec4 effect(vec4 color, Image image, vec2 uv, vec2 screen) {
    vec2 d = texel * radius;
    vec4 sum = Texel(image, uv) * 4.0;
    sum += Texel(image, uv + vec2( d.x, 0.0)) * 2.0;
    sum += Texel(image, uv + vec2(-d.x, 0.0)) * 2.0;
    sum += Texel(image, uv + vec2(0.0,  d.y)) * 2.0;
    sum += Texel(image, uv + vec2(0.0, -d.y)) * 2.0;
    sum += Texel(image, uv + vec2( d.x,  d.y));
    sum += Texel(image, uv + vec2(-d.x,  d.y));
    sum += Texel(image, uv + vec2( d.x, -d.y));
    sum += Texel(image, uv + vec2(-d.x, -d.y));
    return color * (sum / 16.0);
  }
]]

Voxel3D.BACKDROP_BLUR_RADIUS = 0.70

function Voxel3D.backdropShader()
  if backdropShader == nil then
    local ok, sh = pcall(love.graphics.newShader, BACKDROP_BLUR)
    backdropShader = ok and sh or false
  end
  return backdropShader or nil
end

-- LÖVE 12's affected renderer path presents Image texture coordinates upside-down
-- here (the same backend family that needs the HUD canvas workaround). Keep
-- platform discovery inside the still-permitted graphics API: love.system is
-- unavailable to sandboxed mods in the next engine release.
function Voxel3D.metalRenderer()
  -- A renderer/device mentioning Metal is not enough: LÖVE 11 keeps the
  -- original canvas behavior. getVersion remains available to sandboxed mods.
  if not (love and love.getVersion) then return false end
  local versionOK, major = pcall(love.getVersion)
  if not versionOK or type(major) ~= "number" or major < 12 then
    return false
  end
  if not (love and love.graphics and love.graphics.getRendererInfo) then
    return false
  end
  local ok, name, version, vendor, device =
    pcall(love.graphics.getRendererInfo)
  if not ok then return false end
  local info = table.concat({ tostring(name), tostring(version),
                              tostring(vendor), tostring(device) }, " "):lower()
  -- LÖVE may report either Metal directly or its OpenGL ES compatibility
  -- renderer with an Apple vendor/device string.
  return info:find("metal", 1, true) ~= nil
      or (info:find("apple", 1, true) ~= nil
          and info:find("opengl es", 1, true) ~= nil)
end

-- Whether the 3D path can run at all. False on a headless test run (no
-- love.graphics), without shader support, or where a depth canvas cannot be
-- created -- every caller treats that as "stay on the 2D path".
function Voxel3D.available()
  if not (love.graphics and love.graphics.newCanvas
          and love.graphics.setDepthMode) then
    return false
  end
  return Voxel3D.shader() ~= nil
end

-- Build a mesh in the shared format. `verts` is the LOVE vertex list and
-- `map` the triangle index list. Returns nil when meshes are unavailable,
-- which the callers treat the same way they treat a missing model. The
-- optional second result explains failure to transactional room builders.
function Voxel3D.newMesh(verts, map)
  if #verts == 0 then return nil, "empty vertex stream" end
  local ok, mesh = pcall(love.graphics.newMesh, Voxel3D.FORMAT, verts,
                         "triangles", "static")
  if not ok or not mesh then return nil, "mesh allocation failed: " .. tostring(mesh) end
  if map and #map > 0 then
    local indexed, err = pcall(mesh.setVertexMap, mesh, map)
    if not indexed then
      pcall(mesh.release, mesh)
      return nil, "mesh index upload failed: " .. tostring(err)
    end
  end
  return mesh
end

-- The quad corner offsets and UV corners for one face direction, in the
-- order the vertex map below stitches into two triangles. Corners are unit
-- offsets from the voxel's (x, y, z) minimum corner.
Voxel3D.FACE_CORNERS = {
  [1] = { { 1, 0, 0 }, { 1, 0, 1 }, { 1, 1, 1 }, { 1, 1, 0 } },  -- +X
  [2] = { { 0, 0, 1 }, { 0, 0, 0 }, { 0, 1, 0 }, { 0, 1, 1 } },  -- -X
  [3] = { { 0, 1, 0 }, { 1, 1, 0 }, { 1, 1, 1 }, { 0, 1, 1 } },  -- +Y
  [4] = { { 0, 0, 1 }, { 1, 0, 1 }, { 1, 0, 0 }, { 0, 0, 0 } },  -- -Y
  [5] = { { 0, 0, 1 }, { 1, 0, 1 }, { 1, 1, 1 }, { 0, 1, 1 } },  -- +Z
  [6] = { { 1, 0, 0 }, { 0, 0, 0 }, { 0, 1, 0 }, { 1, 1, 0 } },  -- -Z
}

-- Append the six indices of quad `n` (0-based) to a triangle index list.
function Voxel3D.pushQuad(map, n)
  local b = n * 4
  map[#map + 1] = b + 1
  map[#map + 1] = b + 2
  map[#map + 1] = b + 3
  map[#map + 1] = b + 1
  map[#map + 1] = b + 3
  map[#map + 1] = b + 4
end

-- ---------------------------------------------------------------- camera --

-- An explicit camera, replacing the orbit below for as long as it is set:
-- { eye = {x,y,z}, focus = {x,y,z}, fov = radians, curve = k or nil,
--   up = {x,y,z} or nil }.
--
-- The orbit is the free-roam camera and it is described entirely by ONE
-- number, the pitch, because that is all a camera following the player over
-- their own map ever needs. A staged shot -- the overworld battle's
-- over-the-shoulder rig (see BattleCam) -- is a placed camera: it has a yaw,
-- it does not sit above its focus, and its framing comes from the arena
-- rather than from the view size. Rather than widen the orbit into
-- something that could express both and be the wrong shape for each, a
-- caller with a camera of its own simply hands it over.
--
-- Everything downstream is unchanged by this: the shader uniforms, project()
-- and the overlay all read Voxel3D.vp / Voxel3D.eye, which are set the same
-- way either way.
Voxel3D.camera = nil

-- One-frame additive camera input from a Voxel Companion extension. The
-- host retains the base rig and applies only finite, bounded deltas. A fresh
-- value is supplied for every rendered frame, including a zero result.
Voxel3D.companionCameraDelta = nil

local function finiteDelta(value)
  value = tonumber(value)
  if not value or value ~= value or value == math.huge or value == -math.huge then
    return 0
  end
  return value
end

function Voxel3D.setCompanionCameraDelta(delta)
  if type(delta) ~= "table" then
    Voxel3D.companionCameraDelta = nil
    return
  end
  local position = type(delta.positionDelta) == "table" and delta.positionDelta or {}
  local rotation = type(delta.rotationDelta) == "table" and delta.rotationDelta or {}
  Voxel3D.companionCameraDelta = {
    positionDelta = {
      x = math.max(-32, math.min(32, finiteDelta(position.x))),
      y = math.max(-32, math.min(32, finiteDelta(position.y))),
      z = math.max(-32, math.min(32, finiteDelta(position.z))),
    },
    rotationDelta = {
      yaw = math.max(-0.5, math.min(0.5, finiteDelta(rotation.yaw))),
      pitch = math.max(-0.5, math.min(0.5, finiteDelta(rotation.pitch))),
      roll = math.max(-0.5, math.min(0.5, finiteDelta(rotation.roll))),
    },
    fovDelta = finiteDelta(delta.fovDelta),
  }
end

local function normalize3(value, fallback)
  local x, y, z = value[1] or 0, value[2] or 0, value[3] or 0
  local length = math.sqrt(x * x + y * y + z * z)
  if length < 1e-6 then return fallback[1], fallback[2], fallback[3] end
  return x / length, y / length, z / length
end

local function cross3(ax, ay, az, bx, by, bz)
  return ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
end

local function rotateAxis(x, y, z, ax, ay, az, angle)
  if math.abs(angle) < 1e-9 then return x, y, z end
  local c, s = math.cos(angle), math.sin(angle)
  local dot = x * ax + y * ay + z * az
  local cx, cy, cz = cross3(ax, ay, az, x, y, z)
  return x * c + cx * s + ax * dot * (1 - c),
         y * c + cy * s + ay * dot * (1 - c),
         z * c + cz * s + az * dot * (1 - c)
end

local function cameraWithDelta(camera)
  local delta = Voxel3D.companionCameraDelta
  if not delta then return camera end
  local eye, focus = camera.eye, camera.focus
  if not (type(eye) == "table" and type(focus) == "table") then return camera end
  local px, py, pz = delta.positionDelta.x, delta.positionDelta.y,
    delta.positionDelta.z
  local ex, ey, ez = eye[1] + px, eye[2] + py, eye[3] + pz
  local dx, dy, dz = focus[1] - eye[1], focus[2] - eye[2], focus[3] - eye[3]
  local distance = math.max(1e-3, math.sqrt(dx * dx + dy * dy + dz * dz))
  dx, dy, dz = dx / distance, dy / distance, dz / distance

  local rotation = delta.rotationDelta
  dx, dy, dz = rotateAxis(dx, dy, dz, 0, 1, 0, rotation.yaw)
  local rx, ry, rz = cross3(dx, dy, dz, 0, 1, 0)
  rx, ry, rz = normalize3({ rx, ry, rz }, { 1, 0, 0 })
  local baseUp = camera.up or { 0, 1, 0 }
  local ux, uy, uz = normalize3(baseUp, { 0, 1, 0 })
  dx, dy, dz = rotateAxis(dx, dy, dz, rx, ry, rz, rotation.pitch)
  ux, uy, uz = rotateAxis(ux, uy, uz, rx, ry, rz, rotation.pitch)

  ux, uy, uz = rotateAxis(ux, uy, uz, dx, dy, dz, rotation.roll)

  -- Voxel Companion API v1 defines both base FOV and additive FOV in radians.
  local baseFov = finiteDelta(camera.fov)
  if baseFov <= 0 then baseFov = math.rad(65) end
  local fovDelta = delta.fovDelta
  local fov = math.max(math.rad(20), math.min(math.rad(120),
    baseFov + math.max(-math.rad(30),
      math.min(math.rad(30), fovDelta))))
  return {
    eye = { ex, ey, ez },
    focus = { ex + dx * distance, ey + dy * distance, ez + dz * distance },
    up = { ux, uy, uz },
    fov = fov,
    curve = camera.curve,
  }
end

-- ------- which way, and how steeply, this camera looks
--
-- Two facts about the view direction, set alongside the eye and the focus
-- because they ARE the eye and the focus, and read by anything that has to
-- reason about the camera's ATTITUDE rather than about a point in front of
-- it:
--
--   lookFlat   the view direction flattened onto the ground plane and
--              normalized -- "the way the horizon lies from here", which is
--              what a reflection leans toward at the steeper rungs (Water).
--   descent    how far below horizontal the view runs, as a sine: 0 looking
--              level, 1 looking straight down. It is the number that says
--              whether there is a horizon in frame at all, and it answers
--              the same way for the orbit and for a placed battle camera --
--              which is why this is derived from the two vectors rather than
--              read off Voxel.angle, a rung the battle camera does not have.
--
-- A camera looking exactly straight down has no horizontal direction at all,
-- and lookFlat then keeps whatever it last held rather than becoming a zero
-- vector nothing downstream could normalize.
Voxel3D.lookFlat = { 0, 0, -1 }
Voxel3D.descent = 0

local function setLook(eye, focus)
  local dx = focus[1] - eye[1]
  local dy = focus[2] - eye[2]
  local dz = focus[3] - eye[3]
  local len = math.sqrt(dx * dx + dy * dy + dz * dz)
  if len < 1e-6 then return end
  Voxel3D.descent = math.max(0, math.min(1, -dy / len))
  local flat = math.sqrt(dx * dx + dz * dz)
  if flat < 1e-6 then return end
  Voxel3D.lookFlat = { dx / flat, 0, dz / flat }
end

-- View and projection for a `vw` x `vh` world-pixel view centred on
-- (cx, cy) in world pixels. Returns the combined matrix.
function Voxel3D.viewProjection(cx, cy, vw, vh)
  Voxel3D.atmosphereCameraCandidate=nil
  local cam = Voxel3D.camera
  local externalEye=cam and (cam.view or cam.proj or cam.eyeIndex~=nil or cam.stereo==true)
  local cameraMode=Voxel.isFirstPerson() and 'first_person' or (Voxel.isThirdPerson() and 'third_person' or 'diorama')
  if cam then
    cam = cameraWithDelta(cam)
    local eye, focus = cam.eye, cam.focus
    Voxel3D.eye = eye
    -- kept beside the eye for horizonY: where the sky's pale end goes is a
    -- question about which way this camera looks, and only these two answer it
    Voxel3D.focus = focus
    setLook(eye, focus)
    local dx = eye[1] - focus[1]
    local dy = eye[2] - focus[2]
    local dz = eye[3] - focus[3]
    local dist = math.max(1, math.sqrt(dx * dx + dy * dy + dz * dz))
    -- kept for the passes that measure an ANGLE against this camera rather
    -- than a position: the water's reflected sun is sized in radians, and
    -- radians per canvas pixel is exactly this over the frame height
    Voxel3D.fovY = cam.fov
    local proj = Mat4.perspective(cam.fov, vw / vh,
                                  math.max(1, dist * 0.05), dist * 4 + 4096)
    -- the same clip-space Y flip the orbit needs, for the same reason: we
    -- bypass LOVE's transform_projection and canvas coordinates run Y down
    proj = Mat4.mul(Mat4.scale(1, -1, 1), proj)
    -- world up by default, so the horizon stays level -- a placed camera
    -- that rolled with its own pitch would tip the whole arena. A caller
    -- may hand its own up: the first-person BLEND does, because its far
    -- end is the orbit, whose up leans with the pitch -- world up at the
    -- orbit's steep end degenerates against a straight-down view.
    if not externalEye then Voxel3D.atmosphereCameraCandidate=AtmosphereCamera.build(eye,focus,cam.up or {0,1,0},math.max(1,dist*.05),dist*4+4096,cam.fov,cameraMode) end
    return Mat4.mul(proj, Mat4.lookAt(eye, focus, cam.up or { 0, 1, 0 }))
  end

  local a = Voxel.angle
  local focal = Voxel.FOCAL
  local dist = focal * vh
  -- the FOV that makes a straight-down camera at `dist` frame exactly `vh`
  -- world pixels, which is the framing the flat view already has
  local fov = 2 * math.atan(1 / (2 * focal))
  Voxel3D.fovY = fov

  local focus = { cx, 0, cy }
  local eye = { cx, dist * math.cos(a), cy + dist * math.sin(a) }
  -- exposed for camera-facing billboards (VoxelScene yaws sprites at it)
  Voxel3D.eye = eye
  Voxel3D.focus = focus
  setLook(eye, focus)
  -- perpendicular to the view direction in the YZ plane: north is screen-up
  -- when looking straight down, +Y is screen-up when looking level. Never
  -- parallel to the view direction, so there is no degenerate a = 0 case.
  local up = { 0, math.sin(a), -math.cos(a) }

  local proj = Mat4.perspective(fov, vw / vh,
                                math.max(1, dist * 0.05), dist * 4 + 4096)
  -- Flip clip-space Y. Mat4.perspective emits textbook GL clip space with
  -- +Y up, but we bypass LOVE's own transform_projection, and LOVE's canvas
  -- coordinates run Y DOWN -- so without this the entire scene composites
  -- vertically mirrored: north at the bottom and buildings extruding
  -- downward. Winding flips with it, which is free here because the pass
  -- draws with culling off.
  proj = Mat4.mul(Mat4.scale(1, -1, 1), proj)
  Voxel3D.atmosphereCameraCandidate=AtmosphereCamera.build(eye,focus,up,math.max(1,dist*.05),dist*4+4096,fov,cameraMode)
  return Mat4.mul(proj, Mat4.lookAt(eye, focus, up))
end

-- ------- the horizon
--
-- Where the ground plane's vanishing line lands, in canvas pixels down from the
-- top edge, or nil when this camera has no horizon to find.
--
-- Not a fraction picked by eye. A direction ALONG the ground is a point at
-- infinity, and putting one through the same matrix the geometry is drawn with
-- gives the line every ground plane in the scene converges on -- so the sky's
-- pale end meets the horizon at any pitch, fov, window shape or zoom, and rides
-- the camera tween instead of having to be retuned against it.
--
-- The world CURVE is not in it, and cannot be: it bends distant ground down in
-- the vertex shader, so the ground's apparent edge sits BELOW this line by
-- however much the bend took. What shows in between is the haze the sky's fill
-- already is, which is what a curved-away horizon should look like.
--
-- nil in two cases, both meaning "no horizon in this frame": a camera looking
-- straight down, whose forward direction has no horizontal part to send to
-- infinity, and one whose vanishing line is behind it.
function Voxel3D.horizonY(h)
  local m, eye, focus = Voxel3D.vp, Voxel3D.eye, Voxel3D.focus
  if not (m and eye and focus and h and h > 0) then return nil end
  local dx = focus[1] - eye[1]
  local dz = focus[3] - eye[3]
  local len = math.sqrt(dx * dx + dz * dz)
  if len < 1e-6 then return nil end
  dx, dz = dx / len, dz / len
  -- a DIRECTION, so its w is zero and the matrix's translation column drops
  -- out; the clip-space Y flip is already baked into m, so this comes out in
  -- canvas coordinates rather than needing one
  local y = m[5] * dx + m[7] * dz
  local w = m[13] * dx + m[15] * dz
  if w <= 1e-6 then return nil end
  return (y / w * 0.5 + 0.5) * h
end

-- ------- the hour's light
--
-- What the scene shader multiplies every surface by (see dayTint in the
-- shader). Set per pass by whoever knows what map is being drawn --
-- VoxelScene for free-roam, BattleScene for the arena -- because "is this
-- outdoors" is the map's question, not this pass's. Neutral until somebody
-- answers it, so a caller that never does draws exactly what it always drew.
Voxel3D.tint = { 1, 1, 1 }

-- The window-glass pass, set the same way and for the same reason: the
-- MASK belongs to the map's tileset (GlassMask.texture) and how lit the
-- panes are belongs to the hour and to being outdoors at all
-- (DayNight.windowLight). nil / 0 -- the defaults -- draw no glass effect.
Voxel3D.glassMask = nil
Voxel3D.glassNight = 0
Voxel3D.roomNight = 0

-- the glint, fed by the camera's TRAVEL rather than by a clock (see
-- VoxelScene.glintStep): the phase is radians already wrapped to 2pi, and
-- the strength is 0 whenever the view has been still for a beat
Voxel3D.glassPhase = 0
Voxel3D.glassGlint = 0

-- nil on ordinary maps; VoxelScene assigns the approved forest atmosphere
-- only while the N64 Memory Viridian option is active.
Voxel3D.fog = nil

-- The sun or moon disc's place on this camera's canvas, or nil when the
-- body is set, on the southern half of the sky, or behind the camera.
--
-- The direction comes from DayNight (true bearing, squashed elevation) and
-- goes through the SAME matrix the geometry is drawn with, as a point at
-- infinity -- exactly how horizonY finds the vanishing line. So the disc's
-- azimuth is honest: it stands over the point on the horizon its shadows
-- point away from, at every pitch, fov, window shape and zoom.
--
-- Must run after beginScene has set Voxel3D.vp for this frame's camera.
function Voxel3D.skyBody(w, h)
  local m = Voxel3D.vp
  local b = m and DayNight.body()
  if not b then return nil end
  local x = m[1] * b.dx + m[2] * b.dy + m[3] * b.dz
  local y = m[5] * b.dx + m[6] * b.dy + m[7] * b.dz
  local ww = m[13] * b.dx + m[14] * b.dy + m[15] * b.dz
  if ww <= 1e-6 then return nil end
  local amt, color = DayNight.glow()
  return {
    x = (x / ww * 0.5 + 0.5) * w,
    y = (y / ww * 0.5 + 0.5) * h,
    moon = b.moon,
    glowAmt = amt,
    glowColor = color,
  }
end

-- ----------------------------------------------------------------- scene --

-- Begin the 3D pass into a `w` x `h` pixel canvas centred on world
-- (cx, cy), covering `vw` x `vh` world pixels. Returns false when the pass
-- could not start, in which case the caller must not call endScene.
-- `sky` is an optional {r, g, b, a} in 0..1 to clear the void to, for the
-- pitch where the horizon is in frame (VoxelScene.skyFor). nil leaves the
-- void transparent, which is what every rung below it wants.
-- `slot` names which cached canvas to render into (see `slots` above);
-- omitted is the free-roam world pass.
function Voxel3D.beginScene(w, h, cx, cy, vw, vh, sky, slot, modelShadow, borrowed)
  -- PARADE SWITCHES (diagnostic): SCENE DEPTH and CULL HANDOFF rows
  do
    local okPS, PS = pcall(V.require, "ParadeSwitches")
    if okPS and type(PS) == "table" and PS.apply then pcall(PS.apply, Voxel3D) end
  end
  -- the overworld is the one caller with neither a slot nor a borrowed target
  -- (through the table: the beacon is defined further down this file)
  if slot == nil and borrowed == nil and Voxel3D._cullBeaconTick then
    pcall(Voxel3D._cullBeaconTick)
  end
  Voxel3D.atmosphereCameraCandidate=nil
  if not (borrowed and borrowed.scenic) then
    Sky.resetDeferredBody()
    Sky.allowDeferredBody = not borrowed and sky and sky.bands ~= nil
  end
  -- the wireframe variant when the player has it on AND it built; either
  -- answer falls through to the plain scene rather than to no scene
  local grid = VoxelGrid.enabled()
  local sh = grid and Voxel3D.shader(true) or nil
  if not sh then
    grid, sh = false, Voxel3D.shader()
  end
  if not sh then return false end
  -- Hosted passes borrow the already-bound color/depth attachments. Never
  -- allocate, clear, or release a provider-owned target.
  if borrowed then
    canvas, canvasW, canvasH = borrowed.color, w, h
  else
    local name = slot or "world"
    local slotHeld = slots[name]
    local sampledDepth = Voxel3D.SAMPLED_DEPTH ~= false
    if not (slotHeld and slotHeld.w == w and slotHeld.h == h
        and slotHeld.sampledDepth == sampledDepth) then
      local ok, c = PixelCanvas.new(w, h)
      if not ok then return false end
      c:setFilter("nearest", "nearest")
      if slotHeld then releaseSlot(slotHeld) end
      -- the depth canvas is sized with its colour, so a window resize
      -- reallocates the pair together and they can never disagree
      slotHeld = { canvas = c, w = w, h = h, depth = newDepth(w, h),
                   sampledDepth = sampledDepth }
      slots[name] = slotHeld
    end
    held = slotHeld
    canvas, canvasW, canvasH = held.canvas, w, h
    -- a depth buffer is what makes occlusion real: walk behind a building and
    -- the building wins, with no y-sorting anywhere
    local ok = pcall(love.graphics.setCanvas, depthTarget())
    if not ok and held.depth then
      -- the readable canvas would not bind; fall back to the internal buffer
      -- for the rest of this session rather than losing the whole 3D pass
      pcall(held.depth.release, held.depth)
      held.depth = nil
      ok = pcall(love.graphics.setCanvas, depthTarget())
    end
    if not ok then
      pcall(love.graphics.setCanvas)
      return false
    end
  end
  -- Ahead of the clear, because the sky's bands are placed off the ground
  -- plane's vanishing line and that is a property of this matrix.
  Voxel3D.vp = borrowed and borrowed.vp or Voxel3D.viewProjection(cx, cy, vw, vh)
  -- This frame's pixels per WORLD pixel: the size a diorama pixel is on
  -- screen. The sky's dither grid is cut to it, and so is the water's --
  -- one number, so the two break up on the same checkerboard.
  Voxel3D.cell = w / math.max(1, vw or w)
  -- and where the sky's bottom edge lands, which is what the reflection
  -- reads its bands against (see Water). nil when nothing painted bands.
  Voxel3D.skyEdge = (sky and sky.bands)
                    and Sky.region(h, Voxel3D.horizonY(h)) or nil
  if borrowed then
    -- Preserve both the host background and battler depth.
  elseif sky then
    love.graphics.clear(sky[1], sky[2], sky[3], sky[4] or 1, true, true)
    -- The sky goes down here, in the one window in this function where a
    -- rectangle is just a rectangle: the depth mode and the scene shader are
    -- both set below. Sky.paint puts them aside anyway -- beginScene is not the
    -- only thing that has ever left a shader bound.
    --
    -- w / vw is this frame's pixels per WORLD pixel, which is the size a diorama
    -- pixel is on screen: the sky's dither grid is cut to that, so its squares
    -- are the same size as the world's own and follow every resize and zoom.
    -- The banded sky also hangs the hour's sun or moon (skyBody projects it
    -- through this very camera); a flat sky has no bands and hangs nothing.
    Sky.paint(w, h, sky, Voxel3D.horizonY(h), Voxel3D.cell,
              sky.bands and Voxel3D.skyBody(w, h) or nil)
  else
    love.graphics.clear(0, 0, 0, 0, true, true)
  end
  love.graphics.setDepthMode("lequal", true)
  -- models mirror on X for right-facing and alternate walk steps, which
  -- flips winding; hidden faces are already culled at build time, so there
  -- is nothing to gain from backface culling and a real bug to avoid
  love.graphics.setMeshCullMode("none")
  love.graphics.setShader(sh)
  TowerStone.clear(sh)
  love.graphics.setColor(1, 1, 1, 1)
  pcall(sh.send, sh, "vp", "row", Voxel3D.vp)
  Voxel3D.reflectionPlane = nil
  pcall(sh.send, sh, "reflectionClip", {0,0})
  pcall(sh.send, sh, "eye", Voxel3D.eye)
  -- the sun's frame, filled by ShadowMap just before this pass opened.
  -- Sent unconditionally: the sampler is declared either way, and leaving
  -- one unbound is a driver-dependent crash rather than a fallback.
  local map = not borrowed and ShadowMap.active()
  pcall(sh.send, sh, "sunVP", "row", map and ShadowMap.uvVP or IDENTITY)
  local tex = ShadowMap.texture()
  if tex then pcall(sh.send, sh, "sunMap", tex) end
  pcall(sh.send, sh, "sunDark", map and Voxel3D.SHADOW_ALPHA or 0)
  pcall(sh.send, sh, "sunBias", ShadowMap.bias)
  local texel = 1 / ShadowMap.res
  pcall(sh.send, sh, "sunTexel", { texel, texel })
  local external = type(modelShadow) == "table" and modelShadow or nil
  pcall(sh.send, sh, "modelSunVP", "row",
    external and external.sunVP or IDENTITY)
  pcall(sh.send, sh, "modelSunOrigin",
    external and external.origin or { 0, 0, 0 })
  if external and external.map then
    pcall(sh.send, sh, "modelSunMap", external.map)
  elseif tex then
    pcall(sh.send, sh, "modelSunMap", tex)
  end
  pcall(sh.send, sh, "modelSunDark",
    external and not Shadows.off() and (tonumber(external.sunDark) or 0) or 0)
  pcall(sh.send, sh, "modelSunBias",
    external and (tonumber(external.sunBias) or 0) or 0)
  pcall(sh.send, sh, "modelSunTexel",
    external and external.sunTexel or { 1, 1 })
  if grid then
    pcall(sh.send, sh, "gridDark", VoxelGrid.DARK)
    pcall(sh.send, sh, "gridWidth", VoxelGrid.width())
  end
  -- ordinary shading until the silhouette pass asks for otherwise. Sent
  -- every frame rather than once, because a scene that opened mid-ghost --
  -- a driver hiccup between beginGhost and endGhost -- would otherwise
  -- start out flattening everything it drew.
  pcall(sh.send, sh, "ghost", 0)
  pcall(sh.send, sh, "ghostColor", Voxel3D.GHOST_COLOR)
  flattenColor, flattenAmount = nil, 0
  -- Ordinary geometry receives the complete scene light. A tightly scoped
  -- sprite pass may switch this off, but every new scene starts lit so an
  -- interrupted frame cannot leak UNLIT into the next one.
  effectLightOn = 1
  pcall(sh.send, sh, "effectSurface", 0)
  pcall(sh.send, sh, "lightOn", 1)
  -- the hour's light, as the caller last set it (see Voxel3D.tint)
  pcall(sh.send, sh, "dayTint", Voxel3D.tint or { 1, 1, 1 })
  local weather = (not borrowed and sky and V.companion and V.companion.atmosphereSnapshot)
    and V.companion:atmosphereSnapshot() or {}
  pcall(sh.send, sh, "weatherHaze", weather.haze and weather.haze.density or 0)
  pcall(sh.send, sh, "weatherHazeColor", weather.haze and weather.haze.color or {0,0,0})
  pcall(sh.send, sh, "weatherMul", weather.tint and weather.tint.multiplier or {1,1,1})
  pcall(sh.send, sh, "weatherAdd", weather.tint and weather.tint.additive or {0,0,0})
  local fog = Voxel3D.fog
  pcall(sh.send, sh, "fogColor", (fog and fog.color) or { 0, 0, 0 })
  pcall(sh.send, sh, "fogInfo", fog and
        { fog.density or 0, fog.start or 0, fog.heightK or 0, 0 }
        or { 0, 0, 0, 0 })
  -- the window glass: the tileset's mask (or the blank -- the sampler is
  -- declared either way, and unbound is a driver-dependent crash), how lit
  -- the panes are, and the movement-fed glint as the caller last set it
  local mask = Voxel3D.glassMask or GlassMask.blank()
  if mask then
    pcall(sh.send, sh, "glassMask", mask)
    local ok, mw, mh = pcall(mask.getDimensions, mask)
    pcall(sh.send, sh, "glassSize", { ok and mw or 1, ok and mh or 1 })
  end
  pcall(sh.send, sh, "glassNight", Voxel3D.glassNight or 0)
  pcall(sh.send, sh, "roomNight", Voxel3D.roomNight or 0)
  local neonTime=love.timer and love.timer.getTime and love.timer.getTime() or 0
  pcall(sh.send,sh,"casinoPhase",(neonTime*1.25)%(2*math.pi))
  pcall(sh.send,sh,"worldTreePhase",(neonTime*.85)%(2*math.pi))
  V.require("WorldTreeMaterials").bind(sh)
  -- TEST190: the routes' noise texture (sampler declared either way)
  V.require("RouteNoise").bind(sh)
  local winterOK, winter, autumn = pcall(function()
    local settings = V.require("SeasonalDecor").Settings
    return settings.get("holiday") == "christmas" and settings.get("groundSnow") == "full",
      V.require("AutumnGround").active()
  end)
  pcall(sh.send,sh,"treeSnow",winterOK and winter and 1 or 0)
  pcall(sh.send,sh,"treeAutumn",winterOK and autumn and 1 or 0)
  pcall(sh.send,sh,"seasonalPineRegion",{0,0})
  local fire=slot=="battle" and Voxel3D.battleFireLight or nil
  local fireEye=Voxel3D.eye or {0,0,0}
  pcall(sh.send,sh,"fireLightPower",fire and fire.strength or 0)
  for _,item in ipairs({{"fireLightA",fire and fire.a},{"fireLightB",fire and fire.b}}) do
    local p=item[2]
    pcall(sh.send,sh,item[1],p and {p[1]-fireEye[1],p[2]-fireEye[2],p[3]-fireEye[3],p[4]} or {0,0,0,1})
  end
  local lamps=Voxel3D.streetLamps
  pcall(sh.send,sh,"streetLampOn",lamps and (Voxel3D.glassNight or 0) or 0)
  if lamps then
    for i,name in ipairs({"streetLampA","streetLampB","streetLampC","streetLampD"}) do
      local p=lamps[i];local e=Voxel3D.eye or {0,0,0}
      pcall(sh.send,sh,name,{p[1]-e[1],p[2]-e[2],p[3]-e[3]})
    end
  end
  pcall(sh.send, sh, "glassPhase", Voxel3D.glassPhase or 0)
  pcall(sh.send, sh, "glassGlint", Voxel3D.glassGlint or 0)
  -- on until a sprite pass says otherwise, reset per frame like `ghost`
  pcall(sh.send, sh, "battleWaterOn", 0)
  pcall(sh.send, sh, "indoorPoolOn", 0)
  pcall(sh.send, sh, "glassOn", 1)
  -- the curved world bends about the camera's focus, so the horizon keeps
  -- a fixed distance ahead of the player rather than sitting on the map.
  -- A placed camera may decline it outright (Voxel3D.camera.curve = 0).
  local placed = Voxel3D.camera
  Voxel3D.curveK = (placed and placed.curve) or WorldCurve.k(vh)
  Voxel3D.curveX, Voxel3D.curveZ = cx, cy
  pcall(sh.send, sh, "curve", { cx, cy, Voxel3D.curveK })
  -- clip w at the focus point, the reference depth project() reports scale
  -- against (so scale == 1 for anything standing at the view centre)
  local m = Voxel3D.vp
  Voxel3D.focusW = m[13] * cx + m[14] * 0 + m[15] * cy + m[16]
  sceneShader = sh
  activeShader = sh
  Voxel3D.scenicHide = nil
  pcall(sh.send, sh, "scenicHideOn", 0)
  pcall(sh.send, sh, "foliageCutOn", 0)
  pcall(sh.send, sh, "foliageNativeOnly", 0)
  pcall(sh.send, sh, "sightFloor", -100000)
  Voxel3D.sightline = nil
  active = true
  return true
end

-- Depth handling for the character pass. Gen 1 draws sprites over the
-- background unconditionally, so characters render with the depth test
-- forced to pass (still writing depth: the grass mesh drawn after them
-- tests against it to overdraw feet). "test" restores normal occlusion.
function Voxel3D.depth(mode)
  if not active then return end
  pcall(love.graphics.setDepthMode, mode == "always" and "always" or "lequal",
        true)
end

-- ------------------------------------------------ the player's own ghost --

-- The silhouette's colour, and how solid it is.
--
-- ONE flat grey rather than a dimmed copy of the sprite, so the shape reads
-- at a glance instead of competing with whatever is showing through it --
-- and translucent rather than opaque, so it stays a hint of where the
-- player is rather than a hole punched in the building. The wall it is
-- seen through still shows, which is what keeps it reading as "behind
-- that" instead of "in front of it".
Voxel3D.GHOST_COLOR = { 0.26, 0.26, 0.28 }
Voxel3D.GHOST_ALPHA = 0.5

-- Draw a character AGAIN wherever the ordinary draw LOST the depth test.
--
-- Honest occlusion is the point of this mode -- walk behind the Mart and the
-- Mart is genuinely in front of you -- but a player who cannot see their own
-- character has lost track of where they are standing, which the flat game
-- never allowed. So the figure is drawn a second time with the test
-- INVERTED: "greater" passes exactly where "lequal" failed, and LOVE hands
-- the compare straight to glDepthFunc, so the two are true complements.
-- Every texel of the sprite is therefore drawn once and once only -- solid
-- where it is visible, translucent where it is not -- with no seam where
-- they meet and no double-blending anywhere.
--
-- Nothing is drawn at all when nothing is in the way, and no code here ever
-- asks whether the player is occluded: the depth buffer already knows, and
-- the test is the question.
--
-- Depth WRITES are off. This pass is behind the scenery by definition, and
-- writing would file the hidden figure's depth in front of the building
-- hiding it -- the grass pass at the end of the frame reads that buffer.
--
-- The caller redraws through the ordinary character path, so the ghost keeps
-- the same mesh, matrix and camera-ward PULL as the real draw. The pull
-- matching is what keeps the leaning-over-a-near-wall case out of here: pull
-- already won that fight for the solid draw, so this pass finds nothing left
-- to paint and a character merely standing close to a wall does not shimmer
-- a ghost over it.
function Voxel3D.beginGhost()
  if not active then return end
  pcall(love.graphics.setDepthMode, "greater", false)
  love.graphics.setColor(1, 1, 1, Voxel3D.GHOST_ALPHA)
  if activeShader then
    pcall(activeShader.send, activeShader, "ghostColor", Voxel3D.GHOST_COLOR)
    pcall(activeShader.send, activeShader, "ghost", 1)
  end
end

-- Flatten whatever is drawn next to one solid colour, or nil to stop.
--
-- The same `ghost` path the silhouette uses, WITHOUT beginGhost's inverted
-- depth test and half alpha -- this is for something drawn normally that
-- simply wants to come out one colour, which is what a hit flash on a sprite
-- is. beginScene resets the uniform every frame, so a pass that forgets to
-- clear it cannot leak into the next one.
-- `amount` is how far toward that colour, 0..1; omitted is all the way.
-- Anything short of 1 leaves the sprite's own shading showing through, which
-- is the difference between a hit flash and a white cut-out.
function Voxel3D.flatten(color, amount)
  if not (active and activeShader) then return end
  local sh = activeShader
  if color then
    flattenColor = color
    flattenAmount = math.max(0, math.min(1, amount or 1))
    pcall(sh.send, sh, "ghostColor", flattenColor)
    pcall(sh.send, sh, "ghost", flattenAmount)
  else
    flattenColor, flattenAmount = nil, 0
    pcall(sh.send, sh, "ghost", 0)
  end
end

-- ------------------------------------------------------- the water pass --
--
-- A reflective surface has to READ the frame it is being drawn into: the
-- colour of what is standing around it and the depth that says where. Both
-- are attachments of the target this pass is bound to, and a texture cannot
-- be sampled while it is one -- so for the length of the water draw the
-- frame is taken apart:
--
--   the COLOUR is copied to a mirror canvas, which is a texture like any
--   other and is what the reflection samples.
--
--   the DEPTH is simply detached. The water shader does the test itself
--   against the texture (see Water), which is the same comparison the
--   hardware would have made -- what it gives up is depth WRITES, and water
--   is flat, never overlaps itself, and has nothing drawn under it later.
--
-- `paint`, when given, is called with the MIRROR bound and the scene shader
-- set, to add things that must be REFLECTED without being composited yet.
--
-- The characters are the whole reason it exists. Gen 1 draws people over
-- the world and water is world, so the cast has to composite AFTER the
-- water -- but a reflection can only contain what was drawn BEFORE it, and
-- a lake with everyone standing beside it and nobody in it reads as glass.
-- Painting them into the mirror alone settles both: they are in the picture
-- the water reflects and not yet in the picture the water is drawn into.
--
-- They go down depth-TESTED and depth-WRITE-FREE. Tested, so a figure behind
-- a building is behind it in the reflection too; write-free because the very
-- next thing to read that buffer is the water's own depth test, and a cast
-- that had written to it would punch itself out of the water it is standing
-- beside.
--
-- Returns the two textures, or nil when there is nothing to hand over: no
-- readable depth canvas on this driver, or no pass open. A caller that gets
-- nil draws its water like ordinary terrain, which is what this mode always
-- did.
--
-- MUST be paired with endWater, which puts the frame back together.
-- TEST7 capture must precede curved water's depth prepass and all cast copies.
function Voxel3D.captureUnderwater()
  if not (active and canvas and sampledSceneDepth()) then return nil end
  -- The caller selects planted water (town or Safari atlas). Safari's native
  -- ponds own this independently of the unrelated road option.
  return V.require('WaterBackdrop').capture(held,canvas,depthTarget())
end

-- A full-screen atmosphere pass can read opaque depth only while it is
-- detached. The caller never receives the private render targets.
function Voxel3D.drawDepthOverlay(shader, configure)
  if not (active and canvas and sampledSceneDepth() and held.canvas==canvas) then return false end
  local g=love.graphics
  g.push("all")
  local ok,err=pcall(function()
    g.setCanvas(canvas)
    g.origin();g.setScissor();g.setStencilTest();g.setDepthMode()
    g.setBlendMode("alpha","alphamultiply");g.setColor(1,1,1,1)
    g.setShader(shader)
    shader:send("sceneDepth",held.depth)
    configure(shader)
    g.rectangle("fill",0,0,held.w,held.h)
  end)
  g.pop()
  local restored=pcall(g.setCanvas,depthTarget())
  return ok and restored,err
end

function Voxel3D.beginWater(paint)
  if not (active and canvas and sampledSceneDepth()) then return nil end
  if not held.mirror then
    -- Must match both the scene colour canvas and its readable depth target
    -- in physical pixels; see PixelCanvas and newDepth above.
    local ok, c = PixelCanvas.new(held.w, held.h)
    if not (ok and c) then return nil end
    pcall(c.setFilter, c, "nearest", "nearest")
    pcall(c.setWrap, c, "clamp", "clamp")
    held.mirror = c
  end
  love.graphics.setShader()
  -- the frame's own depth rides along, so the paint below can test against
  -- it; the copy underneath switches the test off rather than detaching it
  local ok = pcall(love.graphics.setCanvas,
                   { held.mirror, depthstencil = held.depth })
  if not ok then
    pcall(love.graphics.setCanvas, depthTarget())
    return nil
  end
  love.graphics.setDepthMode("always", false)
  -- COLOUR only. The last two arguments are what keep the depth buffer the
  -- frame's rather than this canvas's: cleared here, the water's own depth
  -- test a few lines later would find nothing in front of anything and every
  -- lake would draw straight through the buildings standing in it.
  love.graphics.clear(0, 0, 0, 0, false, false)
  -- premultiplied over a cleared target is a straight copy: every channel
  -- lands exactly as it stood, including the alpha, so the mirror is the
  -- frame rather than the frame composited against something
  love.graphics.setBlendMode("alpha", "premultiplied")
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(canvas)
  love.graphics.setBlendMode("alpha")
  if paint and activeShader then
    love.graphics.setDepthMode("lequal", false)
    love.graphics.setShader(activeShader)
    pcall(paint)
    love.graphics.setShader()
  end
  love.graphics.setDepthMode()
  -- and back to the scene canvas WITHOUT its depth: that texture is about
  -- to be read
  if not pcall(love.graphics.setCanvas, canvas) then
    pcall(love.graphics.setCanvas, depthTarget())
    return nil
  end
  return held.mirror, held.depth
end

-- ------- the cast's PLANAR reflection
--
-- The other way to get people into the water, and the one that works at the
-- camera this game is played at.
--
-- beginWater paints the cast into the reflection COPY, where the screen-space
-- march has to go and find it. That works when a ray reaches them, and at a
-- steep camera it largely does not: the horizon lean aims rays at the
-- distance, and a sprite is not in the depth buffer anyway, so what a ray
-- does find is smeared along whatever terrain stands behind the sprite.
--
-- This is the other half. The cast is drawn a SECOND time, reflected in the
-- water plane, into a canvas of its own, and the water shader samples that
-- canvas at each fragment's own screen position -- which is the right place
-- to look, because the reflection was drawn to exactly the place a mirror
-- would put it. There is no offset to tune and no correspondence to keep in
-- step.
--
-- The reflecting is done by VoxelScene, in WORLD space, one card at a time.
-- Not by mirroring the camera, which is the obvious way and is wrong here: a
-- character is a billboard leaning back to face the camera, so a mirrored
-- camera catches it leaning away and lands a foreshortened sliver in the
-- water. See billboardMatrix, where the position is reflected and the card
-- is flipped about its own feet instead.
--
-- Masking is free. The water shader runs on water fragments and nothing
-- else, so the reflection is confined to water exactly, with no stencil --
-- which matters, because DEPTH_FORMATS prefers a depth buffer with no
-- stencil in it and most drivers hand one over.
--
-- TEST129: mirrored 3D parts need their OWN depth buffer. Scene depth is
-- neither cleared nor reused. A water-plane near clip excludes submerged
-- original geometry instead of reflecting it upward through the real body.
function Voxel3D.beginCast(plane)
  if not (active and canvas and held) then return nil end
  local clipped = V.require("WaterReflection").projection(Voxel3D.vp, plane)
  if not clipped then return nil end
  if not held.cast then
    local ok, c = PixelCanvas.new(held.w, held.h)
    if not (ok and c) then return nil end
    pcall(c.setFilter, c, "nearest", "nearest")
    pcall(c.setWrap, c, "clamp", "clamp")
    held.cast = c
  end
  if held.castDepth == nil then held.castDepth = newDepth(held.w, held.h) or false end
  if not held.castDepth then return nil end
  if not pcall(love.graphics.setCanvas, {held.cast, depthstencil=held.castDepth}) then
    pcall(held.castDepth.release, held.castDepth)
    held.castDepth = false
    pcall(love.graphics.setCanvas, depthTarget())
    return nil
  end
  held.castVP = Voxel3D.vp
  Voxel3D.vp, Voxel3D.reflectionPlane = clipped, plane
  for _,sh in ipairs({activeShader,sceneShader}) do
    pcall(sh.send, sh, "vp", "row", clipped)
    pcall(sh.send, sh, "reflectionClip", {1,plane-(Voxel3D.eye and Voxel3D.eye[2] or 0)})
  end
  love.graphics.clear(0, 0, 0, 0, true, true)
  love.graphics.setDepthMode("lequal", true)
  return held.cast
end

-- Always restore projection and scene depth, including callback failure.
function Voxel3D.endCast()
  if not active then return end
  if held and held.castVP then Voxel3D.vp=held.castVP;held.castVP=nil end
  Voxel3D.reflectionPlane = nil
  for _,sh in ipairs({activeShader,sceneShader}) do
    pcall(sh.send, sh, "vp", "row", Voxel3D.vp)
    pcall(sh.send, sh, "reflectionClip", {0,0})
  end
  pcall(love.graphics.setCanvas, depthTarget())
  pcall(love.graphics.setDepthMode, "lequal", true)
  love.graphics.setColor(1, 1, 1, 1)
  if activeShader then love.graphics.setShader(activeShader) end
end

-- Put the frame back: depth reattached, depth test and the scene shader as
-- the pass had them. Safe to call after a beginWater that returned nil.
function Voxel3D.endWater()
  if not active then return end
  pcall(love.graphics.setCanvas, depthTarget())
  pcall(love.graphics.setDepthMode, "lequal", true)
  love.graphics.setColor(1, 1, 1, 1)
  if activeShader then love.graphics.setShader(activeShader) end
end

-- Whether a reflective water pass can run in this frame at all -- there is
-- a depth texture to read. Callers use it to choose between the water
-- shader and an ordinary terrain draw before they start moving canvases.
function Voxel3D.depthReadable()
  return (active and sampledSceneDepth()) and true or false
end

-- Whether what is drawn next carries the voxel wireframe. false for the
-- length of a draw, true to put it back.
--
-- The wireframe reads a mesh's OWN model space and darkens its integer
-- planes (see VoxelGrid), which is only a wireframe because every mesh in
-- this mode is built ONE UNIT PER VOXEL: terrain in world pixels, a
-- character card in the sprite's own pixels. A mesh whose model space does
-- not mean that gets no wireframe out of the same shader -- it gets
-- whichever of its integer planes happen to fall inside it, which is a
-- stray line rather than a seam.
--
-- So this is not a style switch. It is how a mesh that is not on the voxel
-- grid says so, and the alternative -- rescaling such a mesh until its
-- units happen to be voxels -- would change what it IS to satisfy a
-- shading pass.
--
-- Sent rather than branched because the plain scene shader has no such
-- uniform, and the send simply does not take there -- which is right: with
-- no wireframe compiled in there is nothing to suppress.
function Voxel3D.seams(on)
  if not (active and activeShader) then return end
  pcall(activeShader.send, activeShader, "gridDark",
        on and VoxelGrid.DARK or 0)
end

-- Additive light geometry for the Legendary capture beam, trails and stars.
-- Keep depth testing enabled so the effects still sit inside the world, but
-- disable depth writes so a transparent glow cannot punch holes in geometry
-- drawn later in the pass. Passing nil restores the ordinary scene state.
function Voxel3D.blend(mode)
  if not active then return end
  if mode == "add" then
    pcall(love.graphics.setBlendMode, "add", "alphamultiply")
    pcall(love.graphics.setDepthMode, "lequal", false)
  else
    pcall(love.graphics.setBlendMode, "alpha", "alphamultiply")
    pcall(love.graphics.setDepthMode, "lequal", true)
  end
end

-- Opt-in VFX scope. Never change world cutout or the legacy blend API.
-- Both alpha and additive effects test scene depth without writing it.
-- Restore the bound shader AND our Lua shader pointer, including on errors.
local effectScopeShader
function Voxel3D.withEffect(mode, draw)
  if not (active and activeShader) then return false end
  assert(mode == "alpha" or mode == "add", "invalid effect blend mode")
  local g = love.graphics
  local previousShader, previousScope = activeShader, effectScopeShader
  local previousLight = effectLightOn
  g.push("all")
  local usedShader
  local ok, err = pcall(function()
    Voxel3D.lighting(false)
    usedShader = activeShader
    -- A failed uniform bind must fail the scope, not silently draw cutouts.
    usedShader:send("effectSurface", 1)
    effectScopeShader = usedShader
    g.setBlendMode(mode, "alphamultiply")
    g.setDepthMode("lequal", false)
    if g.setMeshCullMode then g.setMeshCullMode("none") end
    draw()
  end)
  if usedShader then
    pcall(usedShader.send, usedShader, "effectSurface", previousScope == usedShader and 1 or 0)
  end
  effectScopeShader = previousScope
  activeShader = previousShader
  effectLightOn = previousLight
  if previousShader then pcall(previousShader.send, previousShader, "lightOn", previousLight) end
  g.pop()
  if not ok then error(err, 0) end
  return true
end

-- Whether what is drawn next may consult the glass mask. false for the
-- length of a sprite-sheet pass, true to put it back.
--
-- Same shape as seams(), for the same reason: the mask means "this ATLAS
-- texel is window glass", so it is only an answer for meshes textured from
-- the tileset atlas. A sprite sheet's coordinates land wherever they land
-- on it, and at night that painted lamplight stripes down whoever was
-- standing in the wrong part of their own sheet.
function Voxel3D.glassMaskNow(mask)
  Voxel3D.glassMask=mask
  if not (active and activeShader) then return end
  local m=mask or GlassMask.blank()
  if m then pcall(activeShader.send,activeShader,"glassMask",m); local ok,w,h=pcall(m.getDimensions,m); pcall(activeShader.send,activeShader,"glassSize",{ok and w or 1,ok and h or 1}) end
end

-- Shared water-only fallback for roaming and battles; ordinary terrain is untouched.
function Voxel3D.drawBattleWater(mesh, texture, model, indoorPool)
  if not mesh then return end
  if not (active and activeShader) or (not indoorPool and not V.require("CommunityVisuals").customRoads()) then
    return Voxel3D.draw(mesh, texture, model)
  end
  local sh = activeShader
  local now = love.timer and love.timer.getTime and love.timer.getTime() or 0
  pcall(sh.send, sh, "battleWaterPhase", now % (40 * math.pi))
  pcall(sh.send, sh, "battleWaterOn", 1)
  pcall(sh.send, sh, "indoorPoolOn", indoorPool and 1 or 0)
  local ok, err = pcall(Voxel3D.draw, mesh, texture, model)
  -- Restore even if a draw fails: the following Pokemon must keep their colors.
  pcall(sh.send, sh, "battleWaterOn", 0)
  pcall(sh.send, sh, "indoorPoolOn", 0)
  if not ok then error(err, 0) end
end

function Voxel3D.glass(on)
  if not (active and activeShader) then return end
  pcall(activeShader.send, activeShader, "glassOn", on and 1 or 0)
end

function Voxel3D.endGhost()
  if not active then return end
  pcall(love.graphics.setDepthMode, "lequal", true)
  love.graphics.setColor(1, 1, 1, 1)
  -- back to ordinary shading before anything else draws; leaving it set
  -- would flatten the grass pass that follows into one grey sheet
  if activeShader then
    pcall(activeShader.send, activeShader, "ghost", 0)
  end
end

-- -------------------------------------------------------------- shadows --

-- The sun. One direction, shared by everything that needs to know where
-- the light comes from: the shadow map, the flat fallback below, and the
-- baked contact shading in ChunkMesher. Both shears are negative, which
-- hangs it in the SOUTHEAST and throws every shadow northwest -- up and to
-- the left on screen.
Voxel3D.SHADOW_KX = ShadowMap.KX   -- west drift per pixel of height
Voxel3D.SHADOW_KZ = ShadowMap.KZ   -- north drift per pixel of height
Voxel3D.SHADOW_EPS = 0.25     -- float above the ground to dodge z-fighting
Voxel3D.SHADOW_ALPHA = 0.40   -- how far into black a shadowed surface goes

-- Whether real shadows are running this frame. False headless and on any
-- driver the sun pass could not start on, which is when VoxelScene falls
-- back to the flat decals below.
function Voxel3D.shadowsActive()
  return ShadowMap.active()
end

-- The upright card a character presents to the sun: its 16x16 sprite quad
-- (corners (0,0,0)..(16,16,0), feet at y = 0) standing on the middle of
-- the cell whose top-left is world (px, py), feet at height `y`.
--
-- This is the caster the shadow pass draws -- deliberately NOT the leaning
-- slab the camera sees. The slab tips back by the camera's pitch to read
-- face-on, which is a trick played on the viewer; letting the sun see it
-- too would shrink every shadow to nothing as the camera flattened toward
-- top-down. The sun sees the figure standing up, at every tilt.
--
-- The z-flatten matters when this is used the other way round, as the
-- lookup transform a lit slab reads its own shadowing with (Voxel3D.draw's
-- `sunModel`): it collapses the slab's side relief onto the card plane, so
-- every vertex asks about the exact surface the sun recorded rather than
-- one a few pixels behind it, and a figure cannot fringe itself. On the
-- caster itself it is a no-op -- that quad is already flat.
function Voxel3D.casterMatrix(px, py, y, mirror)
  return Mat4.caster(px, py, y, mirror)
end

-- FALLBACK ONLY (no shadow map: headless, or a driver that cannot make the
-- canvas). Character drop shadows as decals -- the sprite frame squashed
-- flat onto its ground plane and drawn translucent black. It can only ever
-- paint the floor, which is the whole reason ShadowMap exists.
--
-- Flattening is measured from the ground plane, so a hop slides the whole
-- shadow along the sun line while it stays glued to the ground -- the
-- classic jump-shadow tell.
function Voxel3D.shadowMatrix(px, py, gh, lift, mirror)
  local card = Voxel3D.casterMatrix(px, py, gh + (lift or 0), mirror)
  -- flatten about the ground plane: y' = 0, x/z shear by height above it
  local squash = { 1, Voxel3D.SHADOW_KX, 0, 0,
                   0, 0,                 0, 0,
                   0, Voxel3D.SHADOW_KZ, 1, 0,
                   0, 0,                 0, 1 }
  local m = Mat4.mul(squash, Mat4.mul(Mat4.translate(0, -gh, 0), card))
  return Mat4.mul(Mat4.translate(0, gh + Voxel3D.SHADOW_EPS, 0), m)
end

-- The decal pass draws between terrain and characters: depth-tested so a
-- building still hides a shadow behind it, but NOT depth-writing -- the
-- grass tufts drawn at the end of the frame must keep beating the ground
-- plane, and one quad per entity has no self-overlap to guard against.
function Voxel3D.beginShadows()
  if not active then return end
  pcall(love.graphics.setDepthMode, "lequal", false)
  love.graphics.setColor(0, 0, 0, Voxel3D.SHADOW_ALPHA)
end

function Voxel3D.endShadows()
  if not active then return end
  pcall(love.graphics.setDepthMode, "lequal", true)
  love.graphics.setColor(1, 1, 1, 1)
end

-- Draw one mesh with `model` (a Mat4) applied. Texture may be nil to keep
-- whatever the mesh already carries. `pull` moves every vertex toward the
-- eye along its own ray (see the shader) -- the artifact-free depth bias
-- the character and grass passes ride in front of the terrain.
--
-- `sunModel` is where the SHADOW PASS put this same geometry, and defaults
-- to `model` because for everything but a character the two are one matrix.
-- A character is drawn leaning and cast upright, so it must hand over the
-- upright transform or it reads its own shadow as falling on itself.
-- Scoped by the seasonal runtime, including its error path. Ordinary atlas
-- coordinates can never accidentally select pine tiles in a later draw.
local NO_PINE_REGION = {0,0}
function Voxel3D.seasonalFoliage(region)
  if active and activeShader then
    pcall(activeShader.send,activeShader,"seasonalPineRegion",region or NO_PINE_REGION)
  end
end

-- TEST184: `ranges` (from drawCulled) draws only those vertex runs
--
-- CULL HANDOFF (independent renderer review, after TEST266). drawCulled
-- passes its runs as Voxel3D.draw's sixth argument, but a wrapper of
-- Voxel3D.draw that forwards only five (the Legendary Collection's grass and
-- flower modules before their TEST81 patch, which are installed in front of
-- every draw) dropped them -- and every map, route and neighbour was then
-- drawn WHOLE each frame, culling off. drawCulled now also leaves its runs
-- here for the duration of the call; the draw underneath takes them when the
-- argument went missing on the way, for the same mesh only.
local cullHandoff = { mesh = nil, ranges = nil }
Voxel3D.cullHandoffStats = { recovered = 0, draws = 0 }
-- PARADE SWITCHES (diagnostic): false = TEST264's drawCulled exactly -- the
-- runs go only as Voxel3D.draw's sixth argument, and a five-argument wrapper
-- drops them (that map is then drawn whole). Set by ParadeSwitches.
Voxel3D.CULL_HANDOFF = true

-- CULL HANDOFF 2: a marker in the device log, so a bug report can show which
-- build ran. Log lines only; nothing here changes what is drawn.
--   loaded  once, when this file loads
--   alive   on the first overworld frame, then every 10 s of overworld:
--           culled draws in that time, how many arrived without their runs
--           and were rescued, and whether something wraps Voxel3D.draw
--           (the Collection's grass/flower module does, while it is active)
--   gap     any overworld frame-to-frame gap of 0.25-5 s, with the camera
--           of the frame before it (a GPU hang stalls the game ~0.3-0.45 s)
Voxel3D.CULL_HANDOFF_BUILD = "test267cull1"
local beacon = { last = nil, alive = nil, recovered = 0, draws = 0 }
local baseDraw -- Voxel3D.draw as this file defines it, set just below it
local function beaconLog(msg)
  msg = (tostring(msg):gsub("%%", ""))
  local ok, L = pcall(require, "src.core.Logger")
  if ok and type(L) == "table" and type(L.info) == "function"
      and pcall(L.info, msg) then
    return
  end
  pcall(print, msg)
end
local function drawOwner()
  if baseDraw == nil or Voxel3D.draw == baseDraw then return "not wrapped" end
  local where = "source unknown"
  local dbg = rawget(_G, "debug")
  if type(dbg) == "table" and type(dbg.getinfo) == "function" then
    local ok, info = pcall(dbg.getinfo, Voxel3D.draw, "S")
    if ok and type(info) == "table" then
      where = tostring(info.short_src or "?") .. ":" .. tostring(info.linedefined or "?")
    end
  end
  return "wrapped by " .. where
end
local function cameraNote()
  local mode = "orbit"
  pcall(function()
    if Voxel.isFirstPerson() then mode = "1ST"
    elseif Voxel.isThirdPerson() then mode = "3RD" end
  end)
  local e, f = Voxel3D.eye, Voxel3D.focus
  if type(e) == "table" and type(f) == "table"
      and tonumber(e[1]) and tonumber(e[2]) and tonumber(e[3])
      and tonumber(f[1]) and tonumber(f[2]) and tonumber(f[3]) then
    local dx, dy, dz = e[1] - f[1], e[2] - f[2], e[3] - f[3]
    return string.format("%s, eye-to-focus %.0f px, eye (%.0f, %.0f, %.0f)",
      mode, math.sqrt(dx * dx + dy * dy + dz * dz), e[1], e[2], e[3])
  end
  return mode
end
local function beaconTick()
  local okT, now = pcall(love.timer.getTime)
  if not okT or type(now) ~= "number" then return end
  local st, B = Voxel3D.cullHandoffStats, Voxel3D.CULL_HANDOFF_BUILD
  if beacon.last then
    local gap = now - beacon.last
    if gap >= 0.25 and gap <= 5 then
      beaconLog(string.format("[CULL-HANDOFF] %s frame gap %.2f s; camera %s",
        B, gap, cameraNote()))
    end
  end
  beacon.last = now
  if beacon.alive == nil or now - beacon.alive >= 10 then
    local span = beacon.alive and string.format("%.1f s", now - beacon.alive)
      or "first overworld frame"
    beaconLog(string.format(
      "[CULL-HANDOFF] %s alive (%s): %d culled draws, %d rescued (total rescued %d); Voxel3D.draw %s",
      B, span, st.draws - beacon.draws, st.recovered - beacon.recovered,
      st.recovered, drawOwner()))
    beacon.alive, beacon.recovered, beacon.draws = now, st.recovered, st.draws
  end
end
Voxel3D._cullBeaconTick = beaconTick -- beginScene calls it through here
beaconLog("[CULL-HANDOFF] " .. Voxel3D.CULL_HANDOFF_BUILD
  .. " loaded: Voxel3D culling handoff on")

local function submit(mesh, ranges)
  if not ranges then return love.graphics.draw(mesh) end
  local ok, err = pcall(function()
    for i = 1, #ranges, 2 do
      mesh:setDrawRange(ranges[i], ranges[i + 1])
      love.graphics.draw(mesh)
    end
  end)
  pcall(mesh.setDrawRange, mesh)
  if not ok then error(err, 0) end
end
function Voxel3D.draw(mesh, texture, model, pull, sunModel, ranges)
  local parts = V.require("MeshParts").parts(mesh)
  if parts then
    for _, part in ipairs(parts) do Voxel3D.draw(part, texture, model, pull, sunModel) end
    return
  end
  if not (active and mesh) then return end
  if ranges == nil and cullHandoff.mesh ~= nil and cullHandoff.mesh == mesh then
    ranges = cullHandoff.ranges
    Voxel3D.cullHandoffStats.recovered = Voxel3D.cullHandoffStats.recovered + 1
  end
  -- the variant beginScene actually bound, not whichever one is default:
  -- sending a uniform to the other shader would go nowhere
  local sh = activeShader
  if not sh then return end
  if texture then mesh:setTexture(texture) end
  -- LOVE defaults matrix uniforms to column-major; Mat4 is row-major
  pcall(sh.send, sh, "model", "row", model or IDENTITY)
  pcall(sh.send, sh, "sunModel", "row", sunModel or model or IDENTITY)
  pcall(sh.send, sh, "pull", pull or 0)
  if TowerStone.apply(sh,texture) then
    local ok,err=pcall(submit,mesh,ranges)
    TowerStone.clear(sh)
    if not ok then error(err)end
  else submit(mesh,ranges)end
end
baseDraw = Voxel3D.draw

-- ------- TEST184: drawing only the part of a big mesh the camera can see
--
-- The terrain meshes are one mesh per map, and the scene drew all of every
-- one of them every frame: the whole town plus every connected route, most
-- of it behind or beside the camera. On a phone that vertex work was about
-- half the outdoor frame. ChunkMesher's uploads leave a coarse index here
-- (meshIndex[mesh]: a box per block of `bv` vertices); drawCulled tests the
-- boxes against the camera and draws only the runs of blocks in view, with
-- setDrawRange. The mesher writes the ground row by row and the objects
-- sorted by cell, so a block is a narrow band of the map and most of a big
-- map falls away. A mesh without an index draws whole, as before.
Voxel3D.meshIndex = setmetatable({}, { __mode = "k" })
Voxel3D.CULL = true
Voxel3D.CULL_PAD = 3          -- world px: sway, the pull, rounding
Voxel3D.cullStats = { drawn = 0, total = 0 }
local SUPER = 16              -- blocks per coarse box

local function finalizeIndex(idx)
  local n = idx.nb
  idx.sx0, idx.sy0, idx.sz0, idx.sx1, idx.sy1, idx.sz1 = {}, {}, {}, {}, {}, {}
  local ns = math.ceil(n / SUPER)
  for s = 1, ns do
    local a, b = (s - 1) * SUPER + 1, math.min(n, s * SUPER)
    local x0, y0, z0, x1, y1, z1 = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
    for k = a, b do
      if idx.x0[k] <= idx.x1[k] then
        if idx.x0[k] < x0 then x0 = idx.x0[k] end
        if idx.y0[k] < y0 then y0 = idx.y0[k] end
        if idx.z0[k] < z0 then z0 = idx.z0[k] end
        if idx.x1[k] > x1 then x1 = idx.x1[k] end
        if idx.y1[k] > y1 then y1 = idx.y1[k] end
        if idx.z1[k] > z1 then z1 = idx.z1[k] end
      end
    end
    idx.sx0[s], idx.sy0[s], idx.sz0[s] = x0, y0, z0
    idx.sx1[s], idx.sy1[s], idx.sz1[s] = x1, y1, z1
  end
  idx.ns, idx.finalN = ns, n
end

-- Conservative: false only when all eight corners are outside one plane of
-- the clip volume (left, right, bottom, top, or behind the eye). The curve
-- drops a column by k*d^2 from the focus, so the box's floor is lowered by
-- the most it can drop and its top by the least.
local function boxVisible(vp, k, fx, fz, x0, y0, z0, x1, y1, z1)
  local pad = Voxel3D.CULL_PAD
  x0, y0, z0, x1, y1, z1 = x0 - pad, y0 - pad, z0 - pad, x1 + pad, y1 + pad, z1 + pad
  if k ~= 0 then
    local ax, bx = x0 - fx, x1 - fx
    local az, bz = z0 - fz, z1 - fz
    local mx = math.max(ax * ax, bx * bx)
    local mz = math.max(az * az, bz * bz)
    local nx = (ax <= 0 and bx >= 0) and 0 or math.min(ax * ax, bx * bx)
    local nz = (az <= 0 and bz >= 0) and 0 or math.min(az * az, bz * bz)
    local dmax, dmin = mx + mz, nx + nz
    if k > 0 then y0, y1 = y0 - k * dmax, y1 - k * dmin
    else y0, y1 = y0 - k * dmin, y1 - k * dmax end
  end
  local a1, a2, a3, a4 = vp[1], vp[2], vp[3], vp[4]
  local b1, b2, b3, b4 = vp[5], vp[6], vp[7], vp[8]
  local d1, d2, d3, d4 = vp[13], vp[14], vp[15], vp[16]
  local L, R, B, T, N = true, true, true, true, true
  for i = 0, 7 do
    local x = (i % 2 == 0) and x0 or x1
    local y = (i % 4 < 2) and y0 or y1
    local z = (i < 4) and z0 or z1
    local cx = a1 * x + a2 * y + a3 * z + a4
    local cy = b1 * x + b2 * y + b3 * z + b4
    local cw = d1 * x + d2 * y + d3 * z + d4
    if cx >= -cw then L = false end
    if cx <= cw then R = false end
    if cy >= -cw then B = false end
    if cy <= cw then T = false end
    if cw > 0 then N = false end
    if not (L or R or B or T or N) then return true end
  end
  return not (L or R or B or T or N)
end

-- The runs of visible blocks, { start, count, start, count, ... } in
-- 1-based vertices; cached until the camera, the curve or the offset moves.
local function visibleRanges(mesh, idx, ox, oz)
  local vp = Voxel3D.vp
  local k = Voxel3D.curveK or 0
  local fx, fz = (Voxel3D.curveX or 0) - ox, (Voxel3D.curveZ or 0) - oz
  local c = idx.cache
  if c and c.ox == ox and c.oz == oz and c.k == k and c.fx == fx and c.fz == fz
      and c.n == idx.nb then
    local same = true
    for i = 1, 16 do if c.vp[i] ~= vp[i] then same = false break end end
    if same then return c.ranges, c.drawn, c.total end
  end
  if idx.finalN ~= idx.nb then finalizeIndex(idx) end
  -- the camera's matrix with the model's translation folded in, so the
  -- boxes are tested in the mesh's own coordinates
  local m = {}
  for r = 0, 3 do
    local p, q, w4 = vp[r * 4 + 1], vp[r * 4 + 3], vp[r * 4 + 4]
    m[r * 4 + 1], m[r * 4 + 2], m[r * 4 + 3] = p, vp[r * 4 + 2], q
    m[r * 4 + 4] = w4 + p * ox + q * oz
  end
  local total = idx.verts or (idx.nb * idx.bv)
  local ok, vc = pcall(mesh.getVertexCount, mesh)
  if ok and vc then total = vc end
  local ranges, drawn = {}, 0
  local runStart, runEnd = nil, nil
  local bv = idx.bv
  local x0, y0, z0, x1, y1, z1 = idx.x0, idx.y0, idx.z0, idx.x1, idx.y1, idx.z1
  for s = 1, idx.ns do
    local sx0 = idx.sx0[s]
    local superIn = sx0 <= idx.sx1[s] and boxVisible(m, k, fx, fz, sx0, idx.sy0[s], idx.sz0[s],
                                                     idx.sx1[s], idx.sy1[s], idx.sz1[s])
    local a, b = (s - 1) * SUPER + 1, math.min(idx.nb, s * SUPER)
    for blk = a, b do
      local inView = superIn and x0[blk] <= x1[blk]
        and boxVisible(m, k, fx, fz, x0[blk], y0[blk], z0[blk], x1[blk], y1[blk], z1[blk])
      if inView then
        local first = (blk - 1) * bv + 1
        local last = math.min(total, blk * bv)
        if runEnd and runEnd + 1 == first then runEnd = last
        else
          if runStart then ranges[#ranges + 1] = runStart; ranges[#ranges + 1] = runEnd - runStart + 1 end
          runStart, runEnd = first, last
        end
      end
    end
  end
  if runStart then ranges[#ranges + 1] = runStart; ranges[#ranges + 1] = runEnd - runStart + 1 end
  -- vertices past the last indexed block (should be none): draw them
  local indexed = idx.nb * bv
  if total > indexed then
    ranges[#ranges + 1] = indexed + 1; ranges[#ranges + 1] = total - indexed
  end
  for i = 2, #ranges, 2 do drawn = drawn + ranges[i] end
  local vpCopy = {}
  for i = 1, 16 do vpCopy[i] = vp[i] end
  idx.cache = { ox = ox, oz = oz, k = k, fx = fx, fz = fz, n = idx.nb, vp = vpCopy,
                ranges = ranges, drawn = drawn, total = total }
  return ranges, drawn, total
end

-- TEST187: is any of this indexed mesh in view? true when it cannot tell.
function Voxel3D.meshVisible(mesh, ox, oz)
  local idx = mesh and Voxel3D.meshIndex[mesh]
  local okCount, count = pcall(function() return mesh:getVertexCount() end)
  if not (okCount and idx and idx.verts == count) then return true end
  if not (idx and idx.nb and idx.nb > 0 and not idx.bad and (idx.pending or 0) == 0
          and Voxel3D.CULL and Voxel3D.vp) then return true end
  local probe = V.perfProbe
  if probe and probe.noCull then return true end
  local ok, ranges = pcall(visibleRanges, mesh, idx, ox or 0, oz or 0)
  if not ok then return true end
  return #ranges > 0
end

-- TEST267: one range scope shared by the native culler and ParadeCull's
-- faster plane culler. A five-argument Collection wrapper can drop `ranges`,
-- but the draw underneath recovers these exact runs once. Do not also split
-- the mesh into ParadeCull spans: a span draw would recover the ENTIRE set
-- again, multiplying the GPU work by the number of spans.
function Voxel3D.drawRanges(mesh, texture, model, pull, sunModel, ranges)
  if Voxel3D.CULL_HANDOFF == false then
    return Voxel3D.draw(mesh, texture, model, pull, sunModel, ranges)
  end
  local prevMesh, prevRanges = cullHandoff.mesh, cullHandoff.ranges
  cullHandoff.mesh, cullHandoff.ranges = mesh, ranges
  Voxel3D.cullHandoffStats.draws = Voxel3D.cullHandoffStats.draws + 1
  local ok, err = pcall(Voxel3D.draw, mesh, texture, model, pull, sunModel, ranges)
  cullHandoff.mesh, cullHandoff.ranges = prevMesh, prevRanges
  if not ok then error(err, 0) end
end

-- Voxel3D.draw for a big indexed mesh: only its runs in view. ox, oz is
-- the model's translation (the neighbours'); model is passed on unchanged.
function Voxel3D.drawCulled(mesh, texture, model, pull, sunModel, ox, oz)
  local parts = V.require("MeshParts").parts(mesh)
  if parts then
    for _, part in ipairs(parts) do Voxel3D.drawCulled(part, texture, model, pull, sunModel, ox, oz) end
    return
  end
  local idx = mesh and Voxel3D.meshIndex[mesh]
  local probe = V.perfProbe
  local okCount, vertexCount = pcall(function() return mesh:getVertexCount() end)
  if not (okCount and idx and idx.verts == vertexCount and idx and idx.nb and idx.nb > 0 and not idx.bad and (idx.pending or 0) == 0
          and Voxel3D.CULL
          and Voxel3D.vp and mesh.setDrawRange) or (probe and probe.noCull) then
    if mesh and idx then
      local ok, vc = pcall(mesh.getVertexCount, mesh)
      if ok and vc then
        Voxel3D.cullStats.drawn = Voxel3D.cullStats.drawn + vc
        Voxel3D.cullStats.total = Voxel3D.cullStats.total + vc
      end
    end
    return Voxel3D.draw(mesh, texture, model, pull, sunModel)
  end
  local okR, ranges, drawn = pcall(visibleRanges, mesh, idx, ox or 0, oz or 0)
  if not okR then
    idx.bad = true
    return Voxel3D.draw(mesh, texture, model, pull, sunModel)
  end
  local c = idx.cache
  Voxel3D.cullStats.drawn = Voxel3D.cullStats.drawn + (drawn or 0)
  Voxel3D.cullStats.total = Voxel3D.cullStats.total + ((c and c.total) or 0)
  if #ranges == 0 then return end
  return Voxel3D.drawRanges(mesh, texture, model, pull, sunModel, ranges)
end

-- BattleScene owns this short-lived scope; overworld calls have no target.
local battleFoliageTargets
function Voxel3D.battleFoliage(arena, groundY)
  battleFoliageTargets = nil
  local eye = Voxel3D.eye
  if not (arena and arena.player and arena.enemy and eye) then return end
  local function relative(p)
    return {p[1]-eye[1], (groundY or 0)+14-eye[2], p[2]-eye[3]}
  end
  battleFoliageTargets = {relative(arena.player), relative(arena.enemy)}
end

-- Trees only: stones, terrain, characters, balls and shadows use draw().
-- Reset even when a draw fails so the cutaway cannot leak to later passes.
function Voxel3D.drawFoliage(mesh, texture, model, pull, sunModel, nativeOnly)
  local targets, sh = battleFoliageTargets, activeShader
  if not (targets and active and sh and mesh) then
    return Voxel3D.draw(mesh, texture, model, pull, sunModel)
  end
  pcall(sh.send, sh, "foliageTargetA", targets[1])
  pcall(sh.send, sh, "foliageTargetB", targets[2])
  pcall(sh.send, sh, "foliageRadius", 26)
  pcall(sh.send, sh, "foliageNativeOnly", nativeOnly and 1 or 0)
  pcall(sh.send, sh, "foliageCutOn", 1)
  local ok, err = pcall(Voxel3D.draw, mesh, texture, model, pull, sunModel)
  pcall(sh.send, sh, "foliageCutOn", 0)
  pcall(sh.send, sh, "foliageNativeOnly", 0)
  -- A battle-wide sightline (TEST140) outlives this scoped tree cut.
  if Voxel3D.sightline then Voxel3D.applySightline(sh) end
  if not ok then error(err, 0) end
end

-- TEST140: battle-wide sightline cutaway. While on, every scenery draw
-- (terrain, cave rock and ceiling, buildings, props, effects) opens a soft
-- cone from the camera to each Pokemon, using the same stippled opening the
-- forest trees already use. The arena floor is protected. BattleScene turns
-- it off before the actors draw, so trainers and Pokemon are never cut.
local function sendSightline(sh, on)
  if not sh then return end
  local sl = Voxel3D.sightline
  if on and sl then
    pcall(sh.send, sh, "foliageTargetA", sl.a)
    pcall(sh.send, sh, "foliageTargetB", sl.b)
    pcall(sh.send, sh, "foliageRadius", sl.radius)
    pcall(sh.send, sh, "foliageNativeOnly", 0)
    pcall(sh.send, sh, "sightFloor", sl.floor)
    pcall(sh.send, sh, "foliageCutOn", 1)
  else
    pcall(sh.send, sh, "foliageCutOn", 0)
    pcall(sh.send, sh, "foliageNativeOnly", 0)
    pcall(sh.send, sh, "sightFloor", -100000)
  end
end
function Voxel3D.applySightline(sh)
  sendSightline(sh or activeShader, Voxel3D.sightline ~= nil)
end
function Voxel3D.battleSightline(arena, groundY, radius)
  local eye = Voxel3D.eye
  if arena and arena.player and arena.enemy and eye and active then
    local g = groundY or 0
    local function relative(p)
      return {p[1]-eye[1], g+12-eye[2], p[2]-eye[3]}
    end
    Voxel3D.sightline = { a = relative(arena.player), b = relative(arena.enemy),
      radius = radius or 30, floor = g + 3.5 }
  else
    Voxel3D.sightline = nil
  end
  local on = Voxel3D.sightline ~= nil
  sendSightline(sceneShader, on)
  if activeShader ~= sceneShader then sendSightline(activeShader, on) end
  local okFlat, flat = pcall(Voxel3D.unlitShader)
  if okFlat and flat and flat ~= sceneShader then sendSightline(flat, on) end
end

-- TEST95: native forest crowns/trunks share the terrain mesh. Restrict the
-- existing sightline cutaway by material; floor, rocks and actors stay solid.
-- Keep targets and uniforms local to this draw, including the error path.
function Voxel3D.drawForestBattleTerrain(mesh, texture, model, arena, groundY)
  -- TEST49 merge: the battle-wide scope already opens all blocking scenery.
  -- Do not narrow it back to trees within a mixed terrain mesh.
  if Voxel3D.sightline then return Voxel3D.draw(mesh, texture, model) end
  local previous = battleFoliageTargets
  Voxel3D.battleFoliage(arena, groundY)
  local ok, err = pcall(Voxel3D.drawFoliage, mesh, texture, model, nil, nil, true)
  battleFoliageTargets = previous
  if not ok then error(err, 0) end
end

-- TEST135: distance haze for one tightly scoped draw (the painted horizon),
-- or restore the scene's own fog when called without an argument. Uses the
-- existing fog uniforms only; no new shader inputs.
function Voxel3D.haze(color, density, start, heightK)
  if not (active and activeShader) then return end
  local fog = Voxel3D.fog
  if color then
    pcall(activeShader.send, activeShader, "fogColor", color)
    pcall(activeShader.send, activeShader, "fogInfo",
          { density or 0, start or 0, heightK or 0, 0 })
  else
    pcall(activeShader.send, activeShader, "fogColor",
          (fog and fog.color) or { 0, 0, 0 })
    pcall(activeShader.send, activeShader, "fogInfo", fog and
          { fog.density or 0, fog.start or 0, fog.heightK or 0, 0 }
          or { 0, 0, 0, 0 })
  end
end

-- Override the hour tint for one tightly scoped draw, or restore the scene
-- tint when called without an argument. Other lighting uniforms are untouched.
function Voxel3D.dayTint(tint)
  if not (active and activeShader) then return end
  pcall(activeShader.send, activeShader, "dayTint",
        tint or Voxel3D.tint or { 1, 1, 1 })
end

-- Draw the next geometry with or without the scene's complete lighting.
-- Unlike dayTint(), disabling this also bypasses the shadow-map lookup and
-- per-face shade, which is what a genuinely UNLIT texture requires.
function Voxel3D.lighting(on)
  if not (active and activeShader) then return end
  effectLightOn = on == false and 0 or 1
  if on == false then
    local flat = Voxel3D.unlitShader()
    if flat then
      -- Only the vertex uniforms the flat program still consumes. Per-draw
      -- model/pull values are sent by Voxel3D.draw immediately afterward.
      pcall(flat.send, flat, "vp", "row", Voxel3D.vp)
      pcall(flat.send, flat, "reflectionClip",
        {Voxel3D.reflectionPlane and 1 or 0,
         (Voxel3D.reflectionPlane or 0)-(Voxel3D.eye and Voxel3D.eye[2] or 0)})
      pcall(flat.send, flat, "eye", Voxel3D.eye)
      pcall(flat.send, flat, "scenicHideOn", Voxel3D.scenicHide and 1 or 0)
      if Voxel3D.scenicHide then pcall(flat.send, flat, "scenicHideRect", Voxel3D.scenicHide) end
      pcall(flat.send, flat, "curve",
            { Voxel3D.curveX or 0, Voxel3D.curveZ or 0,
              Voxel3D.curveK or 0 })
      pcall(flat.send, flat, "ghost", flattenAmount)
      pcall(flat.send, flat, "ghostColor",
            flattenColor or Voxel3D.GHOST_COLOR)
      love.graphics.setShader(flat)
      activeShader = flat
      return
    end
    -- Compilation refusal costs only the dedicated program. Retain the
    -- uniform path as a compatibility fallback.
    pcall(activeShader.send, activeShader, "lightOn", 0)
    return
  end

  if sceneShader then
    love.graphics.setShader(sceneShader)
    activeShader = sceneShader
  end
  pcall(activeShader.send, activeShader, "lightOn", 1)
end

-- A CSS-style `cover` rectangle for a plate: fill BOTH axes and centre its
-- horizontal overflow. `topOffset` selects how many SOURCE-image pixels to
-- crop from the top, clamped to the vertical overflow so it can never uncover
-- the canvas. Zero preserves the original top-preferred presentation.
function Voxel3D.coverRect(iw, ih, cw, ch, topOffset)
  if not (iw and ih and cw and ch and iw > 0 and ih > 0
          and cw > 0 and ch > 0) then return nil end
  local scale = math.max(cw / iw, ch / ih)
  local available = math.max(0, ih - ch / scale)
  local crop = math.max(0, math.min(available, tonumber(topOffset) or 0))
  return (cw - iw * scale) / 2, -crop * scale, scale, crop
end

-- Keep Metal's correction downstream of all screen-space placement. Apple's
-- canvas path presents the image upside-down, so the negative scale cancels
-- that backend flip around the complete image height. In particular, `y`
-- remains the SAME top-origin crop calculated above; the user setting must
-- never be negated or measured from the bottom on iOS.
function Voxel3D.backdropTransform(iw, ih, x, y, scale, metal)
  if metal then return x, y + ih * scale, scale, -scale end
  return x, y, scale, scale
end

-- Paint an opaque 2D plate behind later scene geometry. The image uses a
-- top-anchored "cover" fit so mixed source dimensions fill the ENTIRE battle
-- viewport without letterboxing: portrait crops the sides, ultrawide keeps
-- the top and crops only the lower foreground. Depth stays cleared: Pokemon cards drawn afterward still
-- use their ordinary projected positions and depth relationship.
function Voxel3D.backdrop(image, topOffset)
  if not (active and image and image.getDimensions) then return false end
  local ok, iw, ih = pcall(image.getDimensions, image)
  if not ok or not (iw and ih and iw > 0 and ih > 0) then return false end
  local x, y, scale = Voxel3D.coverRect(
    iw, ih, canvasW, canvasH, topOffset)
  if not scale then return false end
  local blur = Voxel3D.backdropShader()
  love.graphics.setShader(blur)
  if blur then
    pcall(blur.send, blur, "texel", { 1 / iw, 1 / ih })
    pcall(blur.send, blur, "radius", Voxel3D.BACKDROP_BLUR_RADIUS)
  end
  love.graphics.setDepthMode()
  love.graphics.setColor(1, 1, 1, 1)
  -- One full-height plate has a simple, exact centre-independent Metal flip.
  -- Applying it after cover/crop avoids asymmetric-band and inverted-offset
  -- mistakes on iOS.
  local dx, dy, sx, sy = Voxel3D.backdropTransform(
    iw, ih, x, y, scale, Voxel3D.metalRenderer())
  love.graphics.draw(image, dx, dy, 0, sx, sy)
  love.graphics.setDepthMode("lequal", true)
  if sceneShader then
    love.graphics.setShader(sceneShader)
    activeShader = sceneShader
  end
  return true
end

-- Project a world point to canvas pixels: returns (x, y, scale), or nil
-- when the point is behind the camera. `scale` is how much bigger a thing
-- at that depth appears than one at the focus point, so a caller can size
-- with it -- or ignore it and draw unscaled, which is what tilt mode's
-- billboards do.
--
-- This is what lets the overworld's FX closures (the "!" bubble, the heal
-- machine, the Fly bird, the fishing rod) draw in voxel mode completely
-- unchanged: they stay ordinary 2D draws, anchored to wherever their ground
-- point lands under the same camera the 3D pass used.
function Voxel3D.project(wx, wy, wz)
  local m = Voxel3D.vp
  if not m then return nil end
  -- the same drop the vertex shader applies, or every FX anchored to a
  -- ground point floats off its own feet the moment that ground bends
  wy = wy - WorldCurve.drop(Voxel3D.curveK or 0, Voxel3D.curveX or 0,
                            Voxel3D.curveZ or 0, wx, wz)
  local cx = m[1] * wx + m[2] * wy + m[3] * wz + m[4]
  local cy = m[5] * wx + m[6] * wy + m[7] * wz + m[8]
  local cw = m[13] * wx + m[14] * wy + m[15] * wz + m[16]
  if cw <= 1e-6 then return nil end
  -- viewProjection already flipped clip-space Y into LOVE's Y-down canvas
  -- convention, so both axes map the same way here -- no second flip
  local x = (cx / cw * 0.5 + 0.5) * canvasW
  local y = (cy / cw * 0.5 + 0.5) * canvasH
  -- ...and the WINDOW depth of that point, fourth, for an overlay that has
  -- to know whether the scene stands in front of it. Same expression the
  -- water's own occlusion test uses on its self depth, so a value from here
  -- compares directly against a sample of depthTexture below.
  local cz = m[9] * wx + m[10] * wy + m[11] * wz + m[12]
  return x, y, (Voxel3D.focusW or cw) / cw, (cz / cw) * 0.5 + 0.5
end

-- The frame's depth texture, or nil where the driver gave us none.
--
-- It outlives the pass: endScene unbinds the canvas, it does not release the
-- attachment, so an overlay composited afterwards can still test against the
-- depth the pass wrote. beginOverlay binding the COLOUR canvas alone is what
-- makes the texture readable at all -- a target cannot be sampled while it is
-- attached, which is the same constraint beginWater takes the frame apart for.
function Voxel3D.depthTexture()
  return sampledSceneDepth()
end

-- Re-bind the scene canvas for ordinary 2D drawing (no depth test), so
-- screen-space overlays can be composited into the same image the 3D pass
-- just filled. Pairs with endScene, which unbinds it.
function Voxel3D.beginOverlay()
  if not canvas then return false end
  love.graphics.setShader()
  love.graphics.setDepthMode()
  local ok = pcall(love.graphics.setCanvas, canvas)
  if not ok then return false end
  love.graphics.setColor(1, 1, 1, 1)
  return true
end

-- Close the overlay begun by beginOverlay.
function Voxel3D.endOverlay()
  love.graphics.setCanvas()
  active, activeShader, sceneShader = false, nil, nil
end

-- End the pass and hand back the rendered canvas.
function Voxel3D.endScene()
  -- Map-local lamps are configured by the next world pass. Do not carry
  -- Lavender lighting into a battle or a companion-owned scene.
  Voxel3D.streetLamps = nil
  Voxel3D.battleFireLight = nil
  if not active then return nil end
  love.graphics.setShader()
  love.graphics.setDepthMode()
  love.graphics.setMeshCullMode("none")
  love.graphics.setCanvas()
  active, activeShader, sceneShader = false, nil, nil
  return canvas
end

-- Native scenery in a caller-owned target. Only legal between world passes:
-- never recursively render gameplay, borrow its depth, or replace its camera.
function Voxel3D.captureScenic(options, paint)
  if active then return false, "Scenic capture requested during an active scene" end
  local g=love.graphics
  local public={};for k,v in pairs(Voxel3D)do public[k]=v end
  local oldCanvas,oldW,oldH,oldHeld=canvas,canvasW,canvasH,held
  local oldActive,oldShader,oldScene=active,activeShader,sceneShader
  local oldFlat,oldAmount,oldLight=flattenColor,flattenAmount,effectLightOn
  local previous={g.getCanvas()}
  g.push("all")
  local ok,err=pcall(function()
    local w,h=options.width,options.height
    g.setCanvas({options.canvas,depth=true});g.origin();g.setScissor();g.setStencilTest()
    g.setShader();g.setDepthMode();g.setBlendMode("alpha");g.setColor(1,1,1,1)
    g.clear(options.sky[1],options.sky[2],options.sky[3],1,true,true)
    held=nil -- no access to the main world's readable depth/reflection targets
    Voxel3D.eye=options.eye;Voxel3D.focus=options.focus
    Voxel3D.camera={curve=0};Voxel3D.fovY=options.fov
    setLook(options.eye,options.focus)
    Voxel3D.tint=DayNight.tint(true);Voxel3D.fog=nil
    Voxel3D.glassMask=options.glassMask;Voxel3D.glassNight=DayNight.windowLight()
    Voxel3D.glassPhase=0;Voxel3D.glassGlint=0
    Voxel3D.streetLamps=nil;Voxel3D.battleFireLight=nil
    Voxel3D.companionCameraDelta=nil
    if options.configure then options.configure() end
    if not Voxel3D.beginScene(w,h,options.eye[1],options.eye[3],w,h,options.sky,
      "scenic",nil,{color=options.canvas,vp=options.vp,scenic=true})then
      error("Native scenic shader unavailable")
    end
    -- Paint the same sky bands/body used outside, without companion capture.
    local defer=Sky.allowDeferredBody;Sky.allowDeferredBody=false
    local painted,why=pcall(Sky.paint,w,h,options.sky,Voxel3D.horizonY(h),1,
      Voxel3D.skyBody(w,h))
    Sky.allowDeferredBody=defer
    if not painted then error(why)end
    Voxel3D.scenicHide=options.hide
    if options.hide then
      sceneShader:send("scenicHideOn",1)
      sceneShader:send("scenicHideRect",options.hide)
    end
    paint()
  end)
  -- Uniforms are shared GPU state, not covered by love.graphics.push/pop.
  for _,sh in pairs({sceneShader,activeShader,unlitShader})do
    if sh then pcall(sh.send,sh,"scenicHideOn",0)end
  end
  for k in pairs(Voxel3D)do if public[k]==nil then Voxel3D[k]=nil end end
  for k,v in pairs(public)do Voxel3D[k]=v end
  canvas,canvasW,canvasH,held=oldCanvas,oldW,oldH,oldHeld
  active,activeShader,sceneShader=oldActive,oldShader,oldScene
  flattenColor,flattenAmount,effectLightOn=oldFlat,oldAmount,oldLight
  g.pop()
  local restored,restoreError=pcall(g.setCanvas,unpack(previous))
  return ok and restored,not ok and err or not restored and restoreError or nil
end

-- TEST144: hide everything above y=.5 inside an xz rectangle {x0,z0,x1,z1}
-- for the draws that follow, in the live pass (nil turns it off). The
-- Celadon rooftop uses it so the store's own city model (its rooftop
-- pavilion and terrace) cannot poke up through the authored roof deck.
function Voxel3D.setScenicHide(rect)
  Voxel3D.scenicHide = rect
  for _, sh in pairs({ sceneShader, activeShader, unlitShader }) do
    if sh then
      pcall(sh.send, sh, "scenicHideOn", rect and 1 or 0)
      if rect then pcall(sh.send, sh, "scenicHideRect", rect) end
    end
  end
end

function Voxel3D.canvas()
  return canvas
end

-- The bound canvas's pixel size, for a pass that has to work in screen
-- coordinates (the water's reflection marches in them).
function Voxel3D.size()
  return canvasW, canvasH
end

-- Drop the GPU objects (window resize, hot reload).
function Voxel3D.invalidate()
  Voxel3D.shaderProfile = nil
  for _, key in ipairs({"kanto", "kanto_grid"}) do
    local sh = shaders[key]
    if sh and sh.release then pcall(sh.release, sh) end
    shaders[key] = nil
  end
  if liteShader and liteShader.release then pcall(liteShader.release, liteShader) end
  liteShader = nil
  releaseProbeShaders()
  Voxel3D.companionCameraDelta = nil
  for name, slotHeld in pairs(slots) do
    releaseSlot(slotHeld)
    slots[name] = nil
  end
  canvas, canvasW, canvasH = nil, 0, 0
  held = nil
  ShadowMap.invalidate()
  -- the sky is part of this pass and holds a shader of its own
  Sky.invalidate()
  -- and so does the water, for the same reason
  V.require("Water").invalidate()
  -- and the glass masks are textures of this context too
  GlassMask.invalidate()
end

return Voxel3D
