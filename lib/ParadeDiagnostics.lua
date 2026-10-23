-- Optional on-device diagnostics. Normal parade presentation is clean.
local V=...
local M={}
M.setting=V.require('ModSetting').new('paradeDiagnostics','PARADE DIAGNOSTICS',
 {'off','on'},{'OFF','ON'})
function M.enabled()return M.setting:get()=='on'end
return M
