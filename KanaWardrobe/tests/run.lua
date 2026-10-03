local source = debug.getinfo(1, "S").source:sub(2)
ROOT = source:match("^(.*)/tests/run%.lua$") or "."
local group = arg[1] or "all"
assert(group:match("^[%w_]+$"), "Invalid test group")
local function quote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local files = {}
if group == "all" then
    local pipe = assert(io.popen("find " .. quote(ROOT .. "/tests") .. " -maxdepth 1 -name 'test_*.lua' -type f | sort"))
    for path in pipe:lines() do files[#files + 1] = path end
    pipe:close()
else files[1] = ROOT .. "/tests/test_" .. group .. ".lua" end
local passed, failed = 0, 0
for _, path in ipairs(files) do
    local ok, tests = pcall(dofile, path)
    if not ok then
        failed = failed + 1
        print("FAIL loading " .. path .. ": " .. tostring(tests))
    else
        local names = {}
        for name in pairs(tests) do names[#names + 1] = name end
        table.sort(names)
        for _, name in ipairs(names) do
            local success, err = pcall(tests[name])
            if success then passed = passed + 1; print("PASS " .. name)
            else failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(err)) end
        end
    end
end
print(string.format("%d passed; %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
