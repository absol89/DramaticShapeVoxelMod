-- Legendary Poké Ball presentation settings for normal Battle Art fights.
local V = ...
local ModSetting = V.require("ModSetting")
local P = {}

-- Battle Art remains the first-run/default presentation. LEGENDARY replaces
-- only the capture prop and its 2D ball-bearing overlays; battle rules stay
-- entirely with the engine.
P.enabled = ModSetting.new("legendaryPokeballs", "LEGENDARY POKEBALL SYSTEM",
  {false,true},{"BATTLE ART","LEGENDARY"}, 1)

P.size = ModSetting.new("pokeballSize","BALL SIZE",
  {0.35,0.50,0.65,0.80,0.85,0.90,0.95,1.00,1.05,1.10,1.15,1.20,1.25,1.30,1.35,1.40},
  {"0.35X","0.50X","0.65X","0.80X","0.85X","0.90X","0.95X","1.00X",
   "1.05X","1.10X","1.15X","1.20X","1.25X","1.30X","1.35X","1.40X"}, 10)

P.suction = ModSetting.new("pokeballSuction","SUCTION FX",
  {true,false},{"ON","OFF"})

-- TEST73: capture presentation controls. PRESET gives quick sane looks;
-- CUSTOM makes the three component rows authoritative.
P.preset = ModSetting.new("pokeballCapturePreset","CAPTURE FX PRESET",
  {"CLASSIC","ANIME","CINEMATIC","EPIC","CUSTOM"},
  {"CLASSIC","ANIME","CINEMATIC","EPIC","CUSTOM"}, 3)

P.beam = ModSetting.new("pokeballBeam","BEAM STRENGTH",
  {0,0.55,1.00,1.45,1.90},{"OFF","LOW","MEDIUM","HIGH","EPIC"}, 3)
P.streamers = ModSetting.new("pokeballStreamers","STREAMERS",
  {0,0.45,0.80,1.00},{"OFF","LOW","MEDIUM","HIGH"}, 3)
P.stars = ModSetting.new("pokeballStars","STARS",
  {0,0.45,0.75,1.00},{"OFF","LOW","MEDIUM","HIGH"}, 3)

-- TEST74: second-stage capture choreography controls.
P.pokemonGlow = ModSetting.new("pokeballPokemonGlow","POKEMON GLOW",
  {0,0.55,1.00,1.45},{"OFF","LOW","MEDIUM","HIGH"}, 3)
P.suctionParticles = ModSetting.new("pokeballSuctionParticles","SUCTION PARTICLES",
  {0,0.45,0.75,1.00},{"OFF","LOW","MEDIUM","HIGH"}, 3)
P.captureSpeed = ModSetting.new("pokeballCaptureSpeed","CAPTURE SPEED",
  {0.34,0.50,0.72},{"FAST","NORMAL","CINEMATIC"}, 2)
P.openTime = ModSetting.new("pokeballOpenTime","BALL OPEN TIME",
  {0.00,0.10,0.24},{"SHORT","NORMAL","LONG"}, 2)
P.fxScale = ModSetting.new("pokeballFxScale","FX SCALE",
  {0.50,0.75,1.00,1.25},{"50%","75%","100%","125%"}, 3)

function P.active()
  return P.enabled:get() == true
end

function P.scale()
  local v=P.size:get()
  return tonumber(v) or 1.10
end

function P.suctionEnabled()
  return P.suction:get() ~= false
end

local PRESETS = {
  CLASSIC   = { beam=0.55, streamers=0.25, stars=0.35 },
  ANIME     = { beam=1.25, streamers=0.55, stars=0.55 },
  CINEMATIC = { beam=1.55, streamers=0.80, stars=0.72 },
  EPIC      = { beam=1.90, streamers=1.00, stars=1.00 },
}
local function profile()
  local k=P.preset:get() or "CINEMATIC"
  if k=="CUSTOM" then
    return {
      beam=tonumber(P.beam:get()) or 1,
      streamers=tonumber(P.streamers:get()) or 1,
      stars=tonumber(P.stars:get()) or 1,
    }
  end
  return PRESETS[k] or PRESETS.CINEMATIC
end
function P.beamMult() return profile().beam end
function P.streamerMult() return profile().streamers end
function P.starMult() return profile().stars end
function P.pokemonGlowMult() return tonumber(P.pokemonGlow:get()) or 1 end
function P.suctionParticleMult() return tonumber(P.suctionParticles:get()) or 1 end
function P.captureDuration() return tonumber(P.captureSpeed:get()) or 0.50 end
function P.openHold() return tonumber(P.openTime:get()) or 0.10 end
function P.fxScaleMult() return tonumber(P.fxScale:get()) or 1 end

return P
