local H=dofile('tests/astra_fixture.lua')
local baseline=assert(os.getenv('ASTRA_BASELINE'))
local data,w,h=H.atlas(assert(os.getenv('ASTRA_ATLAS')))
local function measure(root,id)
  love={timer={getTime=os.clock}}
  local Budget=assert(loadfile(root..'/lib/BuildBudget.lua'))()
  local emit,model,sp=H.building(root,id,data,w,h,Budget,true)
  local co=coroutine.create(function() return emit(model,sp,w,h) end)
  local peak,slices,total=0,0,0
  while coroutine.status(co)~='dead' do
    Budget.begin(co,.002)
    local begin=os.clock()
    local ok,value=coroutine.resume(co)
    local duration=os.clock()-begin
    Budget.finish(); assert(ok,value)
    peak=math.max(peak,duration);total=total+duration;slices=slices+1
  end
  return peak*1000,total*1000,slices
end
local function median(t) table.sort(t); return t[math.ceil(#t/2)] end
for _,id in ipairs({'gabled_house','pokemon_tower'}) do
  local a,b,at,bt={},{},{},{}
  for i=1,5 do
    collectgarbage('collect')
    if i%2==1 then a[i],at[i]=measure(baseline,id); b[i],bt[i]=measure('.',id)
    else b[i],bt[i]=measure('.',id); a[i],at[i]=measure(baseline,id) end
  end
  print(('%s: median peak CPU slice %.3f -> %.3f ms; median total emit CPU %.3f -> %.3f ms (5 runs, requested slice 2 ms)'):format(id,median(a),median(b),median(at),median(bt)))
end
