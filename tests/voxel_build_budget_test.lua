-- ROM/GPU-free scheduler regression: deterministic clock, real budget/pump.
local savedLove, savedAssets = love, package.loaded['src.render.Assets']
local now, checks = 0, 0
love = { timer = { getTime = function() return now end } }
package.loaded['src.render.Assets'] = { register = function() end }
local function check(value, message)
  checks = checks + 1
  assert(value, message)
end
local Budget = assert(loadfile('lib/BuildBudget.lua'))()
local function resume(co)
  local ok, err = coroutine.resume(co)
  assert(ok, err)
  return err
end

local iterations = 0
local co = coroutine.create(function()
  for _ = 1, 64 do
    iterations = iterations + 1
    now = now + 0.001
    Budget.tick()
  end
end)
Budget.begin(co, 0.00475, 4)
check(resume(co) == 'budget' and iterations == 8,
  'visible work yields on fourth-call boundaries, not after 32 iterations')
Budget.finish()
Budget.begin(co, 0.030)
check(resume(co) == 'budget' and iterations == 40,
  'covered/default work restores 32-call polling')
Budget.finish()
resume(co)
check(coroutine.status(co) == 'dead', 'finish disables deadline yielding')

local owner = coroutine.create(function() end)
Budget.begin(owner, -1, 4)
for _ = 1, 32 do Budget.tick(); Budget.check() end
local unrelated = coroutine.create(function()
  for _ = 1, 32 do Budget.tick(); Budget.check() end
end)
resume(unrelated)
check(coroutine.status(unrelated) == 'dead',
  'expired budget cannot suspend main thread or unrelated coroutine')
Budget.finish()

local function replaceUpvalue(fn, wanted, replacement)
  for i = 1, 100 do
    local name = debug.getupvalue(fn, i)
    if not name then break end
    if name == wanted then debug.setupvalue(fn, i, replacement); return end
  end
  error('missing scheduler upvalue: ' .. wanted)
end
local function mesher(job)
  local m = assert(loadfile('lib/ChunkMesher.lua'))({
    require = function(name) return name == 'BuildBudget' and Budget or {} end,
  })
  -- Replace GPU geometry only; exercise the actual queue, priorities, deadline,
  -- coroutine lifecycle and failure handling without a ROM or graphics device.
  replaceUpvalue(m.pump, 'runJob', job)
  return m
end
local begun = {}
local originalBegin = Budget.begin
Budget.begin = function(thread, seconds, every)
  begun[#begun + 1] = { seconds, every }
  return originalBegin(thread, seconds, every)
end
local function scenario(body, priority, covered, expected, every)
  now, begun = 0, {}
  local m = mesher(function()
    for _ = 1, 100 do now = now + 0.001; Budget.tick() end
  end)
  m.request({ id = 'TEST' }, body, nil, priority)
  m.pump(covered)
  check(math.abs(begun[1][1] - expected) < 1e-9, 'correct slice class')
  check(begun[1][2] == every, 'correct polling class')
  check(now > expected and now <= expected + every * 0.001,
    'overshoot bounded by synthetic polling interval')
  check(m.pending() == 1, 'yield keeps build queued')
  for _ = 1, 100 do m.pump(covered) end
  check(m.pending() == 0, 'yielded work eventually completes')
end
scenario(true, true, false, 0.0065, 4)
scenario(false, true, false, 0.00475, 4)
scenario(true, 1.5, false, 0.00475, 4)
scenario(true, nil, false, 0.005, 4)
scenario(true, true, true, 0.030, 32)

now, begun = 0, {}
local order = {}
local m = mesher(function(job)
  order[#order + 1] = job.slot
  now = now + 0.001
end)
local map = { id = 'CURRENT' }
m.request(map, true, nil, true)
m.request(map, false, nil, true)
check(m.jobPriority(map.id, true) == 3, 'existing BODY-first promotion retained')
m.pump(false)
check(order[1] == 'body' and order[2] == 'full', 'BODY completes before FULL')
check(begun[2][1] < begun[1][1], 'completed jobs share the same pump deadline')

now, begun = 0, {}
local completed = 0
m = mesher(function() completed = completed + 1; now = now + 0.001 end)
for i = 1, 12 do m.request({ id = tostring(i) }, false, nil, true) end
m.pump(false)
check(completed == 5 and m.pending() == 7,
  'many short jobs cannot each receive a fresh foreground slice')

m = mesher(function() error('intentional budget test failure') end)
m.request(map, false, nil, true)
m.pump(false)
check(m.pending() == 0 and m.takeJobFailure(map.id, false):find('intentional'),
  'failed jobs retain diagnostic and leave the queue')
check(not Budget.expired(), 'failed jobs also clear the active budget')
Budget.begin = originalBegin
love, package.loaded['src.render.Assets'] = savedLove, savedAssets
print(('%d checks passed (voxel build budget)'):format(checks))
