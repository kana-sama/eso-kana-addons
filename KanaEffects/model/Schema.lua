-- Pure profile validation. This module never reads client globals.
local Schema = {}
KanaEffects.Schema = Schema
local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end
local function integer(value) return finite(value) and value >= 1 and value % 1 == 0 end
local function artificialId(value) return finite(value) and value >= 0 and value % 1 == 0 end
local function nonempty(value) return type(value) == "string" and #value > 0 end
local function enums(values)
    local set = {}; for _, value in ipairs(values) do set[value] = true end
    return function(value) return set[value] == true end
end
local function keys(text)
    local result = {}; for key in string.gmatch(text, "%S+") do result[key] = true end; return result
end

function Schema.Validate(profile)
    local diagnostics = {}
    local function add(code, path, message)
        diagnostics[#diagnostics + 1] = { code = code, path = path, message = message }
    end
    -- Preflight before recursive DTO validation: cycles, metatables and runtime values
    -- cannot enter SavedVariables. Shared subtrees are fine, recursion cycles are not.
    local active = {}
    local function walk(value, path)
        local kind = type(value)
        if kind == "table" then
            if active[value] then add("cycle", path, "Cyclic profile table"); return end
            if getmetatable(value) then add("invalid_type", path, "Metatables are runtime data"); return end
            active[value] = true
            for key, child in pairs(value) do
                if type(key) ~= "string" and type(key) ~= "number" then
                    add("invalid_type", path, "Only string or numeric table keys are serializable")
                else
                    walk(child, path .. "[" .. tostring(key) .. "]")
                end
            end
            active[value] = nil
        elseif kind ~= "string" and kind ~= "number" and kind ~= "boolean" and kind ~= "nil" then
            add("invalid_type", path, "Runtime values cannot be persisted")
        end
    end
    walk(profile, "profile")
    if #diagnostics > 0 then return false, diagnostics end

    local function object(value, path, allowed)
        if type(value) ~= "table" then add("invalid_type", path, "Expected table"); return false end
        for key in pairs(value) do
            if not allowed[key] then
                local field = path == "" and tostring(key) or path .. "." .. tostring(key)
                add("unknown_field", field, "Field is outside profile schema")
            end
        end
        return true
    end
    local function check(value, path, predicate, code)
        if not predicate(value) then add(code or "invalid_value", path, "Invalid profile value") end
    end
    local function number(value, path, minimum, maximum, whole)
        check(value, path, function(v)
            return finite(v) and (not minimum or v >= minimum) and (not maximum or v <= maximum) and (not whole or v % 1 == 0)
        end, "invalid_number")
    end
    local function list(value, path, visitor)
        if type(value) ~= "table" then add("invalid_type", path, "Expected dense list"); return end
        local count, largest = 0, 0
        for index in pairs(value) do
            if not integer(index) then add("invalid_list", path, "List keys must be positive integers"); return end
            count = count + 1; largest = math.max(largest, index)
        end
        if count ~= largest then add("invalid_list", path, "List must not have holes"); return end
        for index = 1, count do visitor(value[index], path .. "[" .. index .. "]") end
    end
    local function strings(value, path)
        list(value, path, function(v, p) check(v, p, nonempty) end)
    end
    local function selector(value, path)
        if not object(value, path, keys("kind id level")) then return end
        check(value.kind, path .. ".kind", enums({"ability", "artificial", "family", "category"}))
        if value.kind == "ability" then check(value.id, path .. ".id", integer, "invalid_number")
        elseif value.kind == "artificial" then check(value.id, path .. ".id", artificialId, "invalid_number")
        else check(value.id, path .. ".id", nonempty) end
        if value.kind == "family" then
            check(value.level, path .. ".level", enums({"pair", "minor", "major"}))
        elseif value.level ~= nil then add("unknown_field", path .. ".level", "Only family selectors have a level") end
    end
    local facetEnums = {
        kind = enums({"buff", "debuff", "unknown"}),
        lifetime = enums({"short", "long", "permanent", "toggle", "unknown"}),
        named = function(v) return type(v) == "boolean" end,
        category = nonempty, origin = enums({"skill", "set", "enchant", "unknown"}),
        castBy = enums({"self", "other", "unknown"}),
    }
    local predicate
    predicate = function(value, path)
        if type(value) ~= "table" then add("invalid_type", path, "Expected predicate"); return end
        if value.op == 'expression' then
            object(value,path,keys('op source'))
            check(value.source,path..'.source',function(v) return type(v)=='string' and #v>0 and #v<=16384 end)
        elseif value.op == "and" or value.op == "or" then
            object(value, path, keys("op args")); list(value.args, path .. ".args", predicate)
        elseif value.op == "not" then
            object(value, path, keys("op arg")); predicate(value.arg, path .. ".arg")
        elseif value.op == "selector" then
            object(value, path, keys("op selector")); selector(value.selector, path .. ".selector")
        elseif value.op == "facet" then
            object(value, path, keys("op field values"))
            local validator = facetEnums[value.field]
            if not validator then add("invalid_value", path .. ".field", "Unknown facet")
            else list(value.values, path .. ".values", function(v, p) check(v, p, validator) end) end
        else add("invalid_value", path .. ".op", "Unknown predicate operator") end
    end
    local function identity(value, path, used)
        check(value.id, path .. ".id", nonempty)
        check(value.name, path .. ".name", function(v) return type(v) == "string" end)
        if nonempty(value.id) then
            if used[value.id] then add("duplicate_id", path .. ".id", "Stable ID must be unique") end
            used[value.id] = true
        end
    end
    local widgetIds, setIds = {}, {}
    local function widget(value, path)
        if not object(value, path, keys("id name type unitTag layout anchor style slots rules")) then return end
        identity(value, path, widgetIds)
        check(value.type, path .. ".type", enums({"table", "grid"})); check(value.unitTag, path .. ".unitTag", nonempty)
        local layout = value.layout
        if object(layout, path .. ".layout", keys("columns rows fixedAxis count gap absent ghostAlpha align")) then
            for _, key in ipairs({"columns", "rows", "count"}) do number(layout[key], path .. ".layout." .. key, 1, nil, true) end
            check(layout.fixedAxis, path .. ".layout.fixedAxis", enums({"columns", "rows"}))
            if layout.align~=nil then check(layout.align,path..".layout.align",enums({"start","center","end"})) end
            number(layout.gap, path .. ".layout.gap", 0)
            check(layout.absent, path .. ".layout.absent", enums({"hidden", "ghost"}))
            number(layout.ghostAlpha, path .. ".layout.ghostAlpha", 0, 1)
        end
        local anchor = value.anchor
        if object(anchor, path .. ".anchor", keys("pointX pointY relativeTo relativePointX relativePointY x y")) then
            for _, key in ipairs({"pointX", "pointY", "relativePointX", "relativePointY"}) do
                check(anchor[key], path .. ".anchor." .. key, enums({0, 0.5, 1}))
            end
            check(anchor.relativeTo, path .. ".anchor.relativeTo", enums({"screen", "actionBar", "resources", "targetFrame"}))
            number(anchor.x, path .. ".anchor.x"); number(anchor.y, path .. ".anchor.y")
        end
        local style = value.style
        if object(style, path .. ".style", keys("mode iconSize timerFontSize nameFontSize rowWidth")) then
            check(style.mode, path .. ".style.mode", enums({"over", "under", "right", "list"}))
            for _, key in ipairs({"iconSize", "timerFontSize", "nameFontSize", "rowWidth"}) do
                check(style[key], path .. ".style." .. key, function(v) return finite(v) and v > 0 end, "invalid_number")
            end
        end
        if type(value.slots) ~= "table" then add("invalid_type", path .. ".slots", "Expected sparse slots")
        else
            for row, columns in pairs(value.slots) do
                local rowPath = path .. ".slots[" .. tostring(row) .. "]"
                check(row, rowPath, integer, "invalid_number")
                if type(columns) ~= "table" then add("invalid_type", rowPath, "Expected sparse columns")
                else
                    for column, selected in pairs(columns) do
                        local slotPath = rowPath .. "[" .. tostring(column) .. "]"
                        check(column, slotPath, integer, "invalid_number"); selector(selected, slotPath)
                    end
                end
            end
        end
        local rules = value.rules
        if object(rules, path .. ".rules", keys("includeSets excludeSets named mergePairs expression")) then
            strings(rules.includeSets, path .. ".rules.includeSets"); strings(rules.excludeSets, path .. ".rules.excludeSets")
            check(rules.named, path .. ".rules.named", enums({"any", "only", "exclude"}))
            if rules.expression~=nil then check(rules.expression,path..".rules.expression",function(v) return type(v)=='string' end) end
            check(rules.mergePairs, path .. ".rules.mergePairs", function(v) return type(v) == "boolean" end)
        end
    end
    if object(profile, "", keys("schemaVersion widgets sets hidden longThreshold editor")) then
        check(profile.schemaVersion, "schemaVersion", function(v) return v == 1 end)
        list(profile.widgets, "widgets", widget)
        list(profile.sets, "sets", function(value, path)
            if not object(value, path, keys("id name predicate includeSets excludeSets")) then return end
            identity(value, path, setIds)
            if value.predicate ~= nil then predicate(value.predicate, path .. ".predicate") end
            strings(value.includeSets, path .. ".includeSets"); strings(value.excludeSets, path .. ".excludeSets")
        end)
        list(profile.hidden, "hidden", selector)
        check(profile.longThreshold, "longThreshold", function(v) return finite(v) and v > 0 end, "invalid_number")
        if object(profile.editor, "editor", keys("toolbarX toolbarY")) then
            number(profile.editor.toolbarX, "editor.toolbarX"); number(profile.editor.toolbarY, "editor.toolbarY")
        end
    end
    return #diagnostics == 0, diagnostics
end

function Schema.CopyProfile(profile)
    local valid, diagnostics = Schema.Validate(profile)
    if not valid then error("Invalid profile: " .. diagnostics[1].code .. " at " .. diagnostics[1].path, 2) end
    local function copy(value)
        if type(value) ~= "table" then return value end
        local result = {}; for key, child in pairs(value) do result[key] = copy(child) end; return result
    end
    return copy(profile)
end
