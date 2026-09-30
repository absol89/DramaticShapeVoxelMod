-- Small ornamental water surfaces: quiet teal, independent of animated ROM
-- water palettes. Uses the spare bottom strip of the existing city path donor.
local M={}
function M.draw(g)
 for y=0,15 do for x=0,127 do
  local ripple=math.sin(x*.14+y*.85)*.010+math.sin(x*.045-y*.61)*.008
  g.setColor(.22+ripple,.37+ripple,.39+ripple,1)
  g.rectangle('fill',x,496+y,1,1)
 end end
end
return M
