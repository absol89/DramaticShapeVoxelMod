local major, calls = 12, 0
local renderer = { "Metal", "3.1", "Apple", "Apple GPU" }
love = setmetatable({
  getVersion = function() return major, 0, 0 end,
  graphics = { getRendererInfo = function()
    calls = calls + 1
    return unpack(renderer)
  end },
}, { __index = function(_, key)
  if key == "system" then error("love.system is blocked for mods") end
end })

-- Load the real detector and backdrop transform without GPU dependencies.
local Orientation = assert(loadfile("lib/Voxel3D.lua"))({ require = function(name)
  if name == "Mat4" then return assert(loadfile("lib/Mat4.lua"))() end
  return {}
end })
assert(Orientation.metalRenderer(), "LOVE 12 Metal needs correction")
major, calls = 11, 0
assert(not Orientation.metalRenderer(), "LOVE 11 Metal must stay unchanged")
assert(calls == 0, "runtime must be checked before querying the renderer")
major = 12
renderer = { "OpenGL ES", "3.0", "Qualcomm", "Adreno" }
assert(not Orientation.metalRenderer(), "LOVE 12 GLES alone needs no correction")
renderer = { "OpenGL", "4.6", "NVIDIA", "GPU" }
assert(not Orientation.metalRenderer(), "LOVE 12 OpenGL needs no correction")
renderer = { "OpenGL ES", "3.0", "Apple", "A-series" }
assert(Orientation.metalRenderer(), "LOVE 12 Apple compatibility path was missed")
major = 11
assert(not Orientation.metalRenderer(), "LOVE 11 Apple GLES must stay unchanged")
major = "12"
assert(not Orientation.metalRenderer(), "malformed runtime must fail closed")
love.getVersion = nil
assert(not Orientation.metalRenderer(), "missing runtime must fail closed")
love.getVersion = function() error("unavailable") end
assert(not Orientation.metalRenderer(), "failed runtime query must fail closed")
love.getVersion = function() return 12 end
love.graphics.getRendererInfo = function() error("unavailable") end
assert(not Orientation.metalRenderer(), "failed renderer query must fail closed")
love.graphics.getRendererInfo = nil
assert(not Orientation.metalRenderer(), "missing renderer must fail closed")

local x, y, sx, sy = Orientation.backdropTransform(800, 600, -20, -30, 2, true)
assert(x == -20 and y == 1170 and sx == 2 and sy == -2)
x, y, sx, sy = Orientation.backdropTransform(800, 600, -20, -30, 2, false)
assert(x == -20 and y == -30 and sx == 2 and sy == 2)
print("renderer orientation regression: ok")
