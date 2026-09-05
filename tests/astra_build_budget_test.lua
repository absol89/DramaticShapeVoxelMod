-- Deterministic VM-work bound: the deadline must cover every emitter phase.
-- No wall-clock threshold, GPU, engine or private artwork is required.
local H=dofile('tests/astra_fixture.lua')
local baseline=assert(os.getenv('ASTRA_BASELINE'),'ASTRA_BASELINE required')
local function run(root)
  local work=0
  love={timer={getTime=function() return work end}}
  local Budget=assert(loadfile(root..'/lib/BuildBudget.lua'))()
  local B=assert(loadfile(root..'/lib/Buildings.lua'))({
    require=function() return Budget end,data=function() return {} end})
  local emit=H.upvalue(B.build,'emit')
  local model={W=64,ytop=63,zmin=-2,zmax=63,at=function() return 0 end}
  local sp={ax={[0]=0},ay={[0]=0}}
  local co=coroutine.create(function() return emit(model,sp,128,48) end)
  debug.sethook(co,function() work=work+1000 end,'',1000)
  local peak,resumes,result=0,0
  while coroutine.status(co)~='dead' do
    Budget.begin(co,100000)
    local before=work
    local ok,value=coroutine.resume(co)
    Budget.finish()
    assert(ok,value)
    peak=math.max(peak,work-before); resumes=resumes+1; result=value
  end
  debug.sethook(co)
  return peak,resumes,result
end
jit.off()
local oldPeak,oldResumes,old=run(baseline)
local newPeak,newResumes,new=run('.')
assert(new.voxels==old.voxels and new.shell==old.shell and #new==#old,'geometry changed')
assert(newPeak<1000000,'emitter exceeds the bounded row-work allowance')
assert(newPeak<oldPeak/4,'emitter still has an unbounded phase')
print(('Peak uninterrupted VM work: %d -> %d instructions; resumes %d -> %d; geometry unchanged'):format(oldPeak,newPeak,oldResumes,newResumes))
