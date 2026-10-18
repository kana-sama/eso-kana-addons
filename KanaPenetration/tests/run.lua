-- Run from repository root. Optional argument: model / observer / integration.
local T = {passed = 0, failed = 0}
function T.eq(actual, expected, message)
    assert(actual == expected, (message or '') .. ' expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
function T.near(actual, expected)
    assert(math.abs(actual - expected) < 0.00001, tostring(actual) .. ' ~= ' .. tostring(expected))
end
function T.test(name, body)
    local ok, err = pcall(body)
    if ok then T.passed = T.passed + 1 else T.failed = T.failed + 1; print('FAIL ' .. name .. ': ' .. tostring(err)) end
end
for _, name in ipairs({'model', 'observer', 'integration'}) do
    if not arg[1] or arg[1] == name then
        local entry, err = loadfile('KanaPenetration/tests/' .. name .. '.lua')
        if entry then entry()(T) else T.test(name .. ' suite exists', function() assert(entry, err) end) end
    end
end
print(string.format('%d passed, %d failed', T.passed, T.failed))
if T.failed > 0 then os.exit(1) end
