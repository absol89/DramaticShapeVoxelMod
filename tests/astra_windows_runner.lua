-- The upstream headless filesystem probes directories by renaming them to
-- themselves on Windows. That fails when another process has the directory
-- open (for example a concurrent renderer), silently discovering zero mods.
-- Use the native read-only attribute query for this test process only.
if package.config:sub(1,1) == "\\" then
  local ffi = require("ffi")
  ffi.cdef("unsigned long __stdcall GetFileAttributesA(const char *lpFileName);")
  local FsIo = require("tests.fs_io")
  FsIo.isDir = function(path)
    local flags = tonumber(ffi.C.GetFileAttributesA(path))
    return flags ~= 4294967295 and bit.band(flags, 16) ~= 0
  end
end
assert(arg[1], "test path required")
dofile(arg[1])
