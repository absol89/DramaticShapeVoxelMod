-- Route value-noise data: cached once, sampled linearly in numeric space.
local V = ...
local M = {}
local image, attempted
local options = {linear = true, mipmaps = false}
local function configure(img)
  local ok = pcall(function()
    img:setFilter('linear', 'linear')
    img:setWrap('repeat', 'repeat')
  end)
  if ok then return img end
  if img.release then pcall(img.release, img) end
end
local function build()
  local data
  local ok, img = pcall(function()
    data = love.image.newImageData(1024, 1024)
    local s = 190
    data:mapPixel(function()
      s = (s * 16807) % 2147483647
      local v = math.floor(s / 2147483647 * 256) / 255
      return v, v, v, 1
    end)
    return love.graphics.newImage(data, options)
  end)
  if data and data.release then pcall(data.release, data) end
  return ok and img or nil
end
function M.image()
  if not attempted then
    attempted = true
    local root = (V.path or 'mods/BATTLE_ART_VOXEL_FORK') .. '/assets/legendary/'
    local ok, img = pcall(love.graphics.newImage, root .. 'route-noise.png', options)
    if ok and img then image = configure(img) end
    if not image then
      img = build()
      if img then image = configure(img) end
    end
  end
  return image
end
function M.bind(shader)
  -- Probe variants can compile the sampler out completely.
  if shader.hasUniform and not shader:hasUniform('routeNoiseReady') then return end
  local img = M.image()
  local ready = img and pcall(shader.send, shader, 'routeNoise', img)
  pcall(shader.send, shader, 'routeNoiseReady', ready and 1 or 0)
end
return M
