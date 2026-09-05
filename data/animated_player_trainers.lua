-- Player-trainer back animations. Each source is a five-pose horizontal
-- strip. Runtime division by the actual sheet width supports both the current
-- 320-pixel strips (5 x 64) and the normalized template (5 x 80) without
-- resampling any authored pixels. A set can still use explicit `cells` later
-- if it genuinely needs uneven frame boundaries.
local function five(image)
  return {
    image = "assets/battle/back-animated/" .. image,
    autoColumns = 5,
  }
end

return {
  gen1 = five("gen1player.png"),
  gen2 = five("gen2player.png"),
  gen3 = five("gen3player.png"),
  gen4 = five("gen4player.png"),
  gen5 = five("gen5player.png"),
  ash  = five("ashplayer.png"),
  gary = five("garyplayer.png"),
  red  = five("redplayer.png"),
  green = five("greenplayer.png"),
  ash_front   = five("ashfrontplayer.png"),
  misty_front = five("mistyfrontplayer.png"),
  brock_front = five("brockfrontplayer.png"),
  bulma_front = five("bulmafrontplayer.png"),
  gary_front  = five("garyfrontplayer.png"),
}
