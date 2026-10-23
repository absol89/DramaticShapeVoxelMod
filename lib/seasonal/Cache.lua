-- Installation-scoped cache through Recomp's public API. Never reads/writes
-- another mod's files. Cached data is parsed, never executed as Lua.
local mod,G=...
local M={};M.__index=M
local MAGIC='LSD7a\n';local LIMIT=32*1024*1024;local MAX_BATCH=60000
local unpack=unpack or table.unpack
local ffi;pcall(function()ffi=require('ffi')end)
local function release(v)if v and v.release then pcall(v.release,v)end end
local function hex(s)return(s:gsub('.',function(c)return string.format('%02x',c:byte())end))end
local function digest(s)return hex(love.data.hash('sha256',s))end
local function decompress(s,limit)
 assert(type(s)=='string'and #s>=4,'invalid compressed data')
 -- LÖVE LZ4 stores the raw byte size as a little-endian uint32 header.
 local a,b,c,d=s:byte(1,4);local size=a+b*256+c*65536+d*16777216
 assert(size<=limit,'expanded cache size limit')
 return love.data.decompress('string','lz4',s)
end
local function encode(value)
 local out={};local nodes=0
 local function add(v,depth)
  assert(depth<48,'cache nesting limit');nodes=nodes+1;if nodes%1024==0 then G.checkpoint()end
  local t=type(v)
  if t=='number'then assert(v==v and math.abs(v)<1e12,'invalid cache number');out[#out+1]='n'..string.format('%.17g',v)..'\n'
  elseif t=='string'then out[#out+1]='s'..#v..':'..v
  elseif t=='boolean'then out[#out+1]=v and 't'or 'f'
  elseif t=='table'then
   out[#out+1]='{';local keys={};for k in pairs(v)do assert(type(k)=='number'or type(k)=='string','invalid cache key');keys[#keys+1]=k end
   table.sort(keys,function(a,b)if type(a)==type(b)then return a<b end;return type(a)<type(b)end)
   for _,k in ipairs(keys)do add(k,depth+1);add(v[k],depth+1)end
   out[#out+1]='}'
  elseif t=='nil'then out[#out+1]='0'else error('unsupported cache value '..t)end
 end
 add(value,0);return table.concat(out)
end
local function decode(bytes)
 local p,nodes=1,0
 local function read(depth)
  assert(depth<48 and p<=#bytes,'invalid cache structure');nodes=nodes+1;assert(nodes<2000000,'cache node limit')
  if nodes%1024==0 then G.checkpoint()end
  local kind=bytes:sub(p,p);p=p+1
  if kind=='n'then
   local e=assert(bytes:find('\n',p,true));assert(e-p<32,'invalid number')
   local n=assert(tonumber(bytes:sub(p,e-1)));assert(n==n and math.abs(n)<1e12,'invalid number');p=e+1;return n
  elseif kind=='s'then
   local e=assert(bytes:find(':',p,true));assert(e-p<10,'invalid length')
   local n=assert(tonumber(bytes:sub(p,e-1)));assert(n>=0 and n%1==0 and e+n<=#bytes,'invalid string')
   local s=bytes:sub(e+1,e+n);p=e+n+1;return s
  elseif kind=='t'then return true elseif kind=='f'then return false elseif kind=='0'then return nil
  elseif kind=='{'then
   local out={}
   while bytes:sub(p,p)~='}'do
    local k=read(depth+1);assert(type(k)=='number'or type(k)=='string','invalid key');assert(out[k]==nil,'duplicate key')
    out[k]=read(depth+1)
   end
   p=p+1;return out
  end
  error('invalid cache tag')
 end
 local result=read(0);assert(p==#bytes+1,'trailing cache data');return result
end
-- Session memory layer. Android sandboxes can block the mod's file writes;
-- without this every return to a town rebuilt its snow and displays from
-- scratch. Entries are the same verified, compressed blobs written to disk,
-- kept least-recently-used under a fixed byte budget and shared by all maps.
local MEMORY_LIMIT=40*1024*1024
local memory,memoryOrder,memoryBytes={},{},0
local function forget(slot)
 if memory[slot]then memoryBytes=memoryBytes-#memory[slot];memory[slot]=nil
  for i,v in ipairs(memoryOrder)do if v==slot then table.remove(memoryOrder,i);break end end
 end
end
local function remember(slot,bytes)
 if type(bytes)~='string'or #bytes>MEMORY_LIMIT/2 then return end
 forget(slot)
 memory[slot]=bytes;memoryBytes=memoryBytes+#bytes;memoryOrder[#memoryOrder+1]=slot
 while memoryBytes>MEMORY_LIMIT and #memoryOrder>1 do
  local old=table.remove(memoryOrder,1);memoryBytes=memoryBytes-#(memory[old]or '');memory[old]=nil
 end
end
local function recall(slot)
 local bytes=memory[slot]
 if bytes then
  for i,v in ipairs(memoryOrder)do if v==slot then table.remove(memoryOrder,i);break end end
  memoryOrder[#memoryOrder+1]=slot
 end
 return bytes
end
function M.memoryStats()return memoryBytes,#memoryOrder end
function M.clearMemory()memory,memoryOrder,memoryBytes={},{},0 end
function M.new()
 local self=setmetatable({hits=0,misses=0,writes=0},M)
 local d=love and love.data;local c=mod.cache
 self.available=c and type(c.read)=='function'and type(c.write)=='function'and d and d.pack and d.hash and d.compress and d.decompress and d.newByteData and true or false
 if self.available then
  local ok,stamp=pcall(function()
   local parts={MAGIC,d.pack('string','=I4',16909060)} -- native float byte order
   for _,name in ipairs({'Geometry','Models','Scene','HostBridge','Placement','Snow','PillarSnow','Runtime','Cache','Native'})do parts[#parts+1]=assert(mod:read('lib/'..name..'.lua'))end
   return digest(table.concat(parts))
  end)
  if ok then self.stamp=stamp else self.available=false;self.error=tostring(stamp)end
 end
 return self
end
function M:cancel()
 for _,b in ipairs(self.staged or {})do release(b.mesh)end
 self.staged=nil
end
function M:key(value)
 if not self.available then return end
 local ok,result=pcall(function()return digest(self.stamp..encode(value))end)
 if ok then return result end
 self.error=tostring(result)
end
function M:slot(map,theme,kind)
 return digest(tostring(map)):sub(1,24)..'-'..theme..'-'..kind
end
function M:snowKey(value)
 if not self.available then return end
 local ok,key=pcall(function()
  local stable={};for k,v in pairs(value)do stable[k]=v end
  stable.faces={}
  -- Host pillar cells and some builders iterate hash tables. Fresh Lua states
  -- can enumerate identical surfaces differently; face order is not geometry.
  for i,face in ipairs(value.faces)do
   stable.faces[i]=encode(face);if i%64==0 then G.checkpoint()end
  end
  table.sort(stable.faces)
  return self:key(stable)
 end)
 if ok then return key end
 self.error=tostring(key)
end
local function part(s)return #s..'\n'..s end
local function partReader(payload)
 local p=1
 return function()
  if p>#payload then return nil end
  local e=assert(payload:find('\n',p,true));assert(e-p<=9,'invalid part length')
  local n=assert(tonumber(payload:sub(p,e-1)));assert(n>=0 and n%1==0 and n<=LIMIT and e+n<=#payload,'invalid part')
  local data=payload:sub(e+1,e+n);p=e+n+1;return data
 end
end
function M:load(slot,key)
 if not self.available or not key then return end
 self:cancel();self.staged={}
 local ok,result=pcall(function()
  local bytes=recall(slot)
  if not bytes then
   if mod.cache.info then local info=mod.cache:info(slot);if not info then return end;assert(info.size<=LIMIT,'oversize cache')end
   bytes=mod.cache:read(slot);if not bytes then return end
  end
  assert(type(bytes)=='string'and #bytes<=LIMIT,'invalid cache file')
  if bytes:sub(1,#MAGIC)~=MAGIC or bytes:sub(#MAGIC+1,#MAGIC+64)~=key then return end
  local hash=bytes:sub(#MAGIC+65,#MAGIC+128);local payload=bytes:sub(#MAGIC+129)
  assert(digest(payload)==hash,'cache checksum mismatch')
  local nextPart=partReader(payload);local meta=decode(decompress(assert(nextPart()),16*1024*1024))
  assert(type(meta)=='table'and type(meta.batches)=='table'and #meta.batches<=256 and type(meta.stats)=='table','invalid metadata')
  for _,b in ipairs(meta.batches)do
   assert(b.count>0 and b.count<=MAX_BATCH and b.count%3==0,'invalid mesh size')
   assert(b.kind=='decor'or b.kind=='glow'or b.kind=='ground'or b.kind=='caps'or b.kind=='pillars','invalid mesh kind')
   assert(type(b.group)=='number'and b.group>=0 and b.group<=4 and b.group%1==0,'invalid glow group')
   if b.kind=='glow'then assert(b.group>=1,'invalid glow group')end
   local raw=decompress(assert(nextPart()),b.count*24);assert(#raw==b.count*24,'mesh byte count mismatch')
   local data=love.data.newByteData(raw)
   local made,mesh=pcall(love.graphics.newMesh,G.FORMAT,data,'triangles','static');release(data);assert(made,mesh)
   self.staged[#self.staged+1]={mesh=mesh,kind=b.kind,group=b.group};G.checkpoint()
  end
  assert(nextPart()==nil,'extra cache batches')
  return{stats=meta.stats,batches=self.staged}
 end)
 if ok and result then self.staged=nil;self.hits=self.hits+1;return result end
 self:cancel();self.misses=self.misses+1
 if not ok then
  self.error=tostring(result);forget(slot)
  if mod.cache.delete then pcall(mod.cache.delete,mod.cache,slot)end
 end
end
function M:begin(slot,key)
 if not self.available or not key then return end
 return {slot=slot,key=key,parts={},batches={},bytes=0}
end
function M:append(writer,vertices,kind,group)
 if not writer or writer.failed then return end
 local ok,err=pcall(function()
  -- Fixed chunks cap both compression and direct GPU upload work on warm loads.
  for first=1,#vertices,MAX_BATCH do
   local last=math.min(#vertices,first+MAX_BATCH-1);local count=last-first+1
   local raw
   if ffi then
    local floats=ffi.new('float[?]',count*6);local n=0
    for i=first,last do for j=1,6 do floats[n]=vertices[i][j];n=n+1 end;if i%512==0 then G.checkpoint()end end
    raw=ffi.string(floats,count*24)
   else
    local packed={}
    for a=first,last,96 do
     local values={};local b=math.min(last,a+95)
     for i=a,b do local v=vertices[i];for j=1,6 do values[#values+1]=v[j]end end
     packed[#packed+1]=love.data.pack('string','='..string.rep('f',#values),unpack(values));G.checkpoint()
    end
    raw=table.concat(packed)
   end
   local zipped=love.data.compress('string','lz4',raw)
   writer.bytes=writer.bytes+#zipped;assert(writer.bytes<LIMIT-1024*1024 and #writer.batches<256,'cache entry limit')
   writer.parts[#writer.parts+1]=part(zipped)
   writer.batches[#writer.batches+1]={kind=kind,group=group or 0,count=count}
   G.checkpoint()
  end
 end)
 if not ok then writer.failed=true;writer.parts={};self.error=tostring(err)end
end
function M:save(writer,stats)
 if not writer or writer.failed then return false end
 local writing=false
 local ok,err=pcall(function()
  local encoded=encode({batches=writer.batches,stats=stats});assert(#encoded<=16*1024*1024,'cache metadata limit')
  local meta=love.data.compress('string','lz4',encoded)
  local payload=part(meta)..table.concat(writer.parts);assert(#payload<LIMIT-256,'cache entry limit')
  local bytes=MAGIC..writer.key..digest(payload)..payload
  remember(writer.slot,bytes)
  -- Disk is optional: after one refused write, keep using memory only.
  if not self.writeBlocked then
   writing=true;local worked,why=mod.cache:write(writer.slot,bytes)
   if not worked then self.writeBlocked=true;self.error=tostring(why or 'cache write failed')end
  end
 end)
 writer.parts={}
 if ok then self.writes=self.writes+1;return true end
 self.error=tostring(err);if writing then self.writeBlocked=true end;return false
end
-- Drop a slot that can never match again (an older layout of this cache).
function M:remove(slot)
 forget(slot)
 if self.available and mod.cache.delete then pcall(mod.cache.delete,mod.cache,slot)end
end
-- Exposed only for format/round-trip checks in the developer kit.
M.encode=encode;M.decode=decode
return M
