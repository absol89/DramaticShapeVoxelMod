-- effect()'s precision qualifiers, which decide whether this mod has water
-- at all on a Mali GPU.
--
-- LOVE forward-declares effect() in its own header, under its own default
-- precision. A definition whose qualifiers differ from that declaration is,
-- to an ES compiler, a second function of the same name. It refuses the
-- pair, the shader does not build, and Water.shader falls back to flat
-- water -- quietly, by design, and indistinguishably from the row being
-- switched off.
--
-- The parameters were pinned for this reason already. THE RETURN TYPE WAS
-- NOT, and that is the whole bug: the pixel stage lifts its float default to
-- highp a few hundred lines above effect(), so a bare return type is a highp
-- one against a mediump-default prototype. Read off a Pixel 9 (Mali-G715)
-- in logcat:
--
--   water shader did not compile: Cannot compile pixel shader code:
--   0:563: S0023: Function 'effect' redeclared with a different
--   precision qualifier on the return type -- lakes draw flat
--
-- Which precision is correct is not knowable from here: LOVE 12 declares it
-- under a different default, where a pin that matches 11 is the mismatch.
-- So both forms are generated and Water.shader tries the pinned one first.

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local root = os.getenv("DS_MOD_PATH") or "mods/BattleArtVoxelFork"

local loaded = {}
local V = {
  mod = {
    id = "BATTLE_ART_VOXEL_FORK",
    options = { get = function() return nil end },
  },
}

local fakes = {
  Sky = {
    ramp = function() return nil, 0 end,
    discRadius = function() return 4 end,
    discShades = function() return { { 255, 255, 255 } } end,
    GLOW_REACH = 0.5, MOON_CRATERS = {},
  },
  DayNight = { body = function() return nil end,
               glow = function() return 0, nil end },
  ShadowMap = { active = function() return nil end,
                texture = function() return nil end,
                uvVP = nil, bias = 0.001, res = 1024 },
  Voxel3D = { FACE_SHADE = { 0.9, 0.8, 1.0, 1.0, 0.85, 0.95 },
              SHADOW_ALPHA = 0.5, tint = { 1, 1, 1 } },
  TerrainAtlas = { _animFrame = function() return 0 end },
}

function V.require(name)
  if fakes[name] then return fakes[name] end
  if loaded[name] then return loaded[name] end
  local chunk = assert(loadfile(root .. "/lib/" .. name .. ".lua"))
  local module = chunk(V)
  loaded[name] = module
  return module
end

local Water = V.require("Water")

-- ------- the return type is qualified by the same define as the params

local pinned = Water._source(false, false, false)
local bare = Water._source(false, false, true)

-- the signature must not carry a hardcoded qualifier anywhere: every slot,
-- the return included, moves together or the pair cannot match a prototype
T.check(pinned:find("EFFECT_PREC vec4 effect(EFFECT_PREC vec4 color", 1, true)
        ~= nil, "the return type and the first parameter share the define")
T.check(pinned:find("vec4 effect(mediump vec4 color", 1, true) == nil,
  "no qualifier is baked into the signature any more")

-- and every parameter, so nothing is left on the stage default by accident
local sig = pinned:match("EFFECT_PREC vec4 effect%b()")
T.check(sig ~= nil, "the signature is found")
local slots = 0
for _ in sig:gmatch("EFFECT_PREC") do slots = slots + 1 end
T.eq(slots, 4, "return plus colour, tc and sc are all qualified together")
T.check(sig:find("Image tex", 1, true) ~= nil,
  "the sampler is left alone, since samplers do not take a float precision")

-- ------- both forms are generated

T.check(pinned:find("#define EFFECT_PREC mediump", 1, true) ~= nil,
  "the pinned form defines the qualifier as mediump")
T.check(bare:find("#define EFFECT_PREC\n", 1, true) ~= nil,
  "and the bare form defines it away entirely")
T.check(bare:find("#define EFFECT_PREC mediump", 1, true) == nil,
  "the bare form is not merely the pinned one with extra text")

-- the two differ ONLY in that define: a fallback that changed anything else
-- would be a second shader to reason about rather than the same one
T.eq(pinned:gsub("#define EFFECT_PREC mediump\n", "#define EFFECT_PREC\n"),
     bare,
     "pinned and bare are the same shader under a different qualifier")

-- ------- the fallback is actually reachable

-- Water.shader must try the bare form when the pinned one is refused, or
-- generating it buys nothing. Driven with a newShader that refuses the
-- pinned source the way a Mali compiler does.
local seen = {}
local realNewShader = love.graphics and love.graphics.newShader
love.graphics = love.graphics or {}
love.graphics.newShader = function(src)
  seen[#seen + 1] = src:find("#define EFFECT_PREC mediump", 1, true)
                    and "pinned" or "bare"
  if seen[#seen] == "pinned" then
    error("S0023: Function 'effect' redeclared with a different precision"
          .. " qualifier on the return type", 0)
  end
  return { send = function() end }
end

Water.invalidate()
local sh = Water.shader(false, false)
T.check(sh ~= nil, "a refusal of the pinned form still yields a shader")
T.same(seen, { "pinned", "bare" },
  "the pinned form is tried first and the bare one only after it is refused")

-- and a driver that refuses BOTH falls back to flat water rather than erroring
love.graphics.newShader = function() error("no", 0) end
Water.invalidate()
T.eq(Water.shader(false, false), nil,
  "refusing both leaves no shader, which is the flat fallback")

love.graphics.newShader = realNewShader
Water.invalidate()

T.finish("water effect precision")
