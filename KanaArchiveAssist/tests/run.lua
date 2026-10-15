local S=dofile('KanaArchiveAssist/tests/support.lua')
_G.KAATest=S
local suites={'storage','capture','model','support','learning','metrics','grades','view','ui','controller'}
for _,name in ipairs(arg[1] and {arg[1]} or suites) do
 local ok,err=pcall(dofile,'KanaArchiveAssist/tests/test_'..name..'.lua')
 if not ok then S.failed=S.failed+1;print('FAIL: '..name..': '..tostring(err)) end
end
S.finish()
