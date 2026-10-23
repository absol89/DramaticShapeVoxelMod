-- TEST22: shared face corners, identical triangles. Only tree meshes use this.
-- One bounded reusable map avoids rebuilding thousands of index tables per
-- map. The ordinary table overload is also used by Voxel3D on older hosts.
local T = {}
local lastCount, lastMap
local supported = true

function T.bind(mesh, count, M)
  if not supported or not mesh.setVertexMap then return false end
  if lastCount ~= count then
    local indices = {}
    for base = 0, count - 4, 4 do
      local at = base / 4 * 6
      indices[at + 1], indices[at + 2], indices[at + 3] = base + 1, base + 2, base + 3
      indices[at + 4], indices[at + 5], indices[at + 6] = base + 1, base + 3, base + 4
      if base % 256 == 0 then M.treeBuildYield(true) end
    end
    lastCount, lastMap = count, indices
  end
  local ok = pcall(M.Timings.call, "mesh_write", mesh.setVertexMap, mesh, lastMap)
  if not ok then
    supported, lastCount, lastMap = false, nil, nil
  end
  M.treeBuildYield(true)
  return ok
end

-- Capability fallback expands one bounded section. Preserve the exact two
-- triangles, including UV/shade bytes; handle cache chunks split mid-face.
function T.expand(record, yieldFn)
  local chunks, faces, carry, total = {}, {}, "", 0
  for _, chunk in ipairs(record.chunks or {}) do
    local bytes = carry .. chunk
    local offset = 1
    while #bytes - offset + 1 >= 96 do
      local a = bytes:sub(offset, offset + 23)
      local b = bytes:sub(offset + 24, offset + 47)
      local c = bytes:sub(offset + 48, offset + 71)
      local d = bytes:sub(offset + 72, offset + 95)
      faces[#faces + 1] = a .. b .. c .. a .. c .. d
      total, offset = total + 4, offset + 96
      if #faces == 512 then
        chunks[#chunks + 1], faces = table.concat(faces), {}
        yieldFn(true)
      end
    end
    carry = bytes:sub(offset)
  end
  if #carry ~= 0 or total ~= record.n then return nil end
  if #faces > 0 then chunks[#chunks + 1] = table.concat(faces) end
  return { n = record.n / 4 * 6, chunks = chunks }
end

return T
