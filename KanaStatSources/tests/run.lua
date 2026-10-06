local group=arg and arg[1]
assert(not group or group:match('^[%w_]+$'),'invalid test group')
local files={}
if group then files[1]='KanaStatSources/tests/test_'..group..'.lua'
else
    local p=assert(io.popen("rg --files KanaStatSources/tests -g 'test_*.lua' | sort"))
    for f in p:lines() do files[#files+1]=f end;p:close()
end
local passed,failed=0,0
for _,file in ipairs(files) do
    local ok,tests=pcall(dofile,file)
    if not ok then print('FAIL '..file..': '..tostring(tests));failed=failed+1
    else
        local names={};for name in pairs(tests) do names[#names+1]=name end;table.sort(names)
        for _,name in ipairs(names) do
            local success,err=pcall(tests[name])
            if success then passed=passed+1 else failed=failed+1;print('FAIL '..name..': '..tostring(err)) end
        end
    end
end
print(string.format('%d passed; %d failed',passed,failed))
if failed>0 then error('test suite failed') end
