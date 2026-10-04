local A = {}
TestSupport.Assert = A
function A.Equal(actual, expected, message)
    assert(actual == expected, (message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
function A.True(value, message) assert(value == true, message or "expected true") end
function A.False(value, message) assert(value == false, message or "expected false") end
function A.Diagnostic(diagnostics, code, path)
    for _, diagnostic in ipairs(diagnostics) do
        if diagnostic.code == code and (not path or diagnostic.path == path) then return diagnostic end
    end
    error("missing diagnostic " .. code .. " at " .. tostring(path))
end
function A.Throws(callback, fragment)
    local ok, err = pcall(callback)
    assert(not ok, "expected error")
    if fragment then assert(string.find(tostring(err), fragment, 1, true), tostring(err)) end
end
