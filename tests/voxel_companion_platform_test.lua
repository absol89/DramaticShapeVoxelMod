-- VoxelCompanion must not touch the sandbox-blocked love.system namespace.
local f=assert(io.open("lib/VoxelCompanion.lua","rb"))
local source=f:read("*a");f:close()
local first=assert(source:find("local function platformName()",1,true))
local last=assert(source:find("\nlocal function face",first,true))
local api={}
local blocked=setmetatable({}, {
  __index=function(_,key)
    if key=="system" then error("love.system is not available to mods") end
  end,
})
local chunk=assert(loadstring(source:sub(first,last-1).."\nreturn platformName"))
setfenv(chunk,setmetatable({love=blocked,Voxel3D=api},{__index=_G}))
local platform=chunk()
api.metalRenderer=function()return true end
assert(platform()=="IOS","LÖVE 12 Metal renderer identifies iOS")
api.metalRenderer=function()return false end
assert(platform()=="UNKNOWN","other sandboxed platforms use neutral metadata")
print("Voxel Companion platform detection avoids love.system: passed")
