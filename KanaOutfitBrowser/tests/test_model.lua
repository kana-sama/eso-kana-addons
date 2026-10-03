local modelPath = "KanaOutfitBrowser/Model.lua"
local chunk, loadError = loadfile(modelPath)
assert(chunk, "KanaOutfitBrowser model is missing: " .. tostring(loadError))
chunk()

local KOB = assert(KanaOutfitBrowser, "KanaOutfitBrowser namespace is missing")
assert(KOB.Model and KOB.Model.New, "KanaOutfitBrowser.Model.New is missing")

local tests = {}

local function test(name, body)
    tests[#tests + 1] = { name = name, body = body }
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertTrue(value, message)
    if not value then
        error(message or "expected a truthy value", 2)
    end
end

local function variant(styleKey, name, weight)
    return {
        key = styleKey .. ":" .. weight,
        styleKey = styleKey,
        name = name,
        weight = weight,
        slots = {},
        missingSlots = {},
        knownCount = 7,
        partCount = 7,
    }
end

local function standardVariants()
    return {
        variant("dunmer", "Dunmer", 3),
        variant("breton", "Breton", 2),
        variant("dunmer", "Dunmer", 1),
        variant("breton", "Breton", 1),
        variant("dunmer", "Dunmer", 2),
        variant("breton", "Breton", 3),
    }
end

local function openModel(variants, accountPrefs, characterPrefs)
    accountPrefs = accountPrefs or { favorites = {}, hidden = {} }
    characterPrefs = characterPrefs or { preferredWeight = 1, showHidden = false }
    local model = KOB.Model.New(variants, accountPrefs, characterPrefs)
    model:Open()
    return model, accountPrefs, characterPrefs
end

local function styleRows(model)
    local result = {}
    for _, row in ipairs(model:GetRows()) do
        if row.kind == "style" then
            result[#result + 1] = row
        end
    end
    return result
end

local function flatKeys(model)
    local result = {}
    for _, row in ipairs(styleRows(model)) do
        for weight = 1, 4 do
            if row.variants[weight] then
                result[#result + 1] = row.variants[weight].key
            end
        end
    end
    return result
end

local function assertKeys(actual, expected, message)
    assertEqual(#actual, #expected, (message or "key count") .. " count")
    for index, expectedKey in ipairs(expected) do
        assertEqual(actual[index], expectedKey, (message or "keys") .. " at " .. index)
    end
end

local function countHeaders(model)
    local count = 0
    for _, row in ipairs(model:GetRows()) do
        if row.kind == "header" then
            count = count + 1
        end
    end
    return count
end

test("horizontal crosses row boundary and vertical preserves the column", function()
    local model = openModel(standardVariants())

    assertTrue(model:Select("breton:3"))
    assertTrue(model:MoveHorizontal(1))
    assertEqual(model:GetSelected().key, "dunmer:1")

    assertTrue(model:Select("breton:3"))
    assertTrue(model:MoveVertical(1))
    assertEqual(model:GetSelected().key, "dunmer:3")

    assertTrue(model:MoveHorizontal(-1))
    assertEqual(model:GetSelected().key, "dunmer:2")
    assertEqual(select(1, model:GetPosition()), 5)
    assertEqual(select(2, model:GetPosition()), 6)
end)

test("favorite partition is deferred, per variant, and never duplicates a key", function()
    local model, account = openModel(standardVariants())
    assertEqual(countHeaders(model), 0)
    assertTrue(model:Select("dunmer:1"))
    assertTrue(model:ToggleFavorite())
    assertTrue(account.favorites["dunmer:1"])
    assertKeys(flatKeys(model), {
        "breton:1", "breton:2", "breton:3",
        "dunmer:1", "dunmer:2", "dunmer:3",
    }, "live favorite must not reorder")

    model:Open()
    assertEqual(countHeaders(model), 2)
    assertKeys(flatKeys(model), {
        "dunmer:1",
        "breton:1", "breton:2", "breton:3",
        "dunmer:2", "dunmer:3",
    }, "next open favorite partition")

    local rows = styleRows(model)
    assertEqual(rows[1].styleKey, "dunmer")
    assertTrue(rows[1].variants[1] ~= nil)
    assertEqual(rows[1].variants[2], nil)
    assertEqual(rows[1].variants[3], nil)
    assertEqual(rows[3].styleKey, "dunmer")
    assertEqual(rows[3].variants[1], nil)
    assertTrue(rows[3].variants[2] ~= nil)
    assertTrue(rows[3].variants[3] ~= nil)

    local seen = {}
    for _, key in ipairs(flatKeys(model)) do
        assertEqual(seen[key], nil, "duplicate visible variant " .. key)
        seen[key] = true
    end

    assertTrue(model:ToggleFavorite())
    assertEqual(account.favorites["dunmer:1"], nil)
    assertKeys(flatKeys(model), {
        "dunmer:1",
        "breton:1", "breton:2", "breton:3",
        "dunmer:2", "dunmer:3",
    }, "favorite removal must remain deferred")

    model:Open()
    assertEqual(countHeaders(model), 0)
    assertKeys(flatKeys(model), {
        "breton:1", "breton:2", "breton:3",
        "dunmer:1", "dunmer:2", "dunmer:3",
    })
end)

test("disabling hidden display chooses the next survivor in previous order", function()
    local account = {
        favorites = {},
        hidden = { ["breton:1"] = true, ["breton:2"] = true },
    }
    local character = {
        selectedKey = "breton:2",
        preferredWeight = 2,
        showHidden = true,
    }
    local model = openModel({
        variant("breton", "Breton", 1),
        variant("breton", "Breton", 2),
        variant("breton", "Breton", 3),
        variant("dunmer", "Dunmer", 1),
    }, account, character)

    assertKeys(flatKeys(model), { "breton:1", "breton:2", "breton:3", "dunmer:1" })
    assertTrue(model:SetShowHidden(false))
    assertEqual(model:GetSelected().key, "breton:3",
        "old numeric index would incorrectly select dunmer:1")
    assertKeys(flatKeys(model), { "breton:3", "dunmer:1" })
    assertEqual(character.selectedKey, "breton:3")
end)

test("hiding selects the next old-order survivor, then previous, then empty", function()
    local model, account = openModel({
        variant("breton", "Breton", 1),
        variant("breton", "Breton", 2),
        variant("breton", "Breton", 3),
    })

    model:Select("breton:2")
    assertTrue(model:ToggleHidden())
    assertTrue(account.hidden["breton:2"])
    assertEqual(model:GetSelected().key, "breton:3")

    assertTrue(model:ToggleHidden())
    assertEqual(model:GetSelected().key, "breton:1")

    assertTrue(model:ToggleHidden())
    assertEqual(model:GetSelected(), nil)
    assertEqual(select(1, model:GetPosition()), 0)
    assertEqual(select(2, model:GetPosition()), 0)
    assertEqual(#model:GetRows(), 0)
    assertEqual(model:MoveHorizontal(1), false)
    assertEqual(model:MoveVertical(1), false)
    assertEqual(model:ToggleFavorite(), false)
    assertEqual(model:ToggleHidden(), false)
end)

test("show-hidden keeps a newly hidden selection selected", function()
    local model, account = openModel({ variant("breton", "Breton", 2) }, nil, {
        preferredWeight = 2,
        showHidden = true,
    })
    assertEqual(model:GetSelected().key, "breton:2")
    assertTrue(model:ToggleHidden())
    assertTrue(account.hidden["breton:2"])
    assertEqual(model:GetSelected().key, "breton:2")
    assertEqual(select(1, model:GetPosition()), 1)
    assertEqual(select(2, model:GetPosition()), 1)
end)

test("vertical fallback and unified rows preserve the preferred weight", function()
    local model, _, character = openModel({
        variant("a", "A", 3),
        variant("b", "B", 1),
        variant("c", "C", 4),
        variant("d", "D", 3),
    }, nil, {
        selectedKey = "a:3",
        preferredWeight = 3,
        showHidden = false,
    })

    assertTrue(model:MoveVertical(1))
    assertEqual(model:GetSelected().key, "b:1")
    assertEqual(character.preferredWeight, 3)
    assertTrue(model:MoveVertical(1))
    assertEqual(model:GetSelected().key, "c:4")
    assertEqual(character.preferredWeight, 3)
    assertTrue(model:MoveVertical(1))
    assertEqual(model:GetSelected().key, "d:3")
    assertEqual(character.preferredWeight, 3)

    assertTrue(model:MoveVertical(-1))
    local rows = styleRows(model)
    assertTrue(model:SelectRow(rows[2]))
    assertEqual(model:GetSelected().key, "b:1")
    assertEqual(character.preferredWeight, 3)
end)

test("explicit and horizontal selection update only real armor preferences", function()
    local model, _, character = openModel({
        variant("a", "A", 1),
        variant("b", "B", 4),
        variant("c", "C", 2),
    }, nil, {
        preferredWeight = 3,
        showHidden = false,
    })

    assertEqual(model:Select("a:1"), false,
        "the key is already selected even though the explicit click updates preference")
    assertEqual(character.preferredWeight, 1)
    assertTrue(model:MoveHorizontal(1))
    assertEqual(model:GetSelected().key, "b:4")
    assertEqual(character.preferredWeight, 1)
    assertTrue(model:MoveHorizontal(1))
    assertEqual(model:GetSelected().key, "c:2")
    assertEqual(character.preferredWeight, 2)
    assertEqual(model:MoveHorizontal(1), false)
end)

test("same localized names sort and restore by stable keys", function()
    local character = {
        selectedKey = "zeta:2",
        preferredWeight = 2,
        showHidden = false,
    }
    local model = openModel({
        variant("zeta", "Same name", 2),
        variant("alpha", "Same name", 1),
    }, nil, character)

    assertKeys(flatKeys(model), { "alpha:1", "zeta:2" })
    assertEqual(model:GetSelected().key, "zeta:2")
    assertEqual(character.selectedKey, "zeta:2")
    assertEqual(model:Select("missing:key"), false)
    assertEqual(model:GetSelected().key, "zeta:2")
end)

test("hidden and favorite flags remain independent", function()
    local account = {
        favorites = { ["breton:2"] = true },
        hidden = { ["breton:2"] = true },
    }
    local character = { preferredWeight = 2, showHidden = false }
    local model = openModel({
        variant("breton", "Breton", 2),
        variant("dunmer", "Dunmer", 1),
    }, account, character)

    assertKeys(flatKeys(model), { "dunmer:1" })
    assertTrue(account.favorites["breton:2"])
    assertTrue(account.hidden["breton:2"])

    assertTrue(model:SetShowHidden(true))
    assertTrue(model:Select("breton:2"))
    assertTrue(model:ToggleFavorite())
    assertEqual(account.favorites["breton:2"], nil)
    assertTrue(account.hidden["breton:2"])
    assertTrue(model:ToggleHidden())
    assertEqual(account.hidden["breton:2"], nil)
    assertEqual(account.favorites["breton:2"], nil)
end)

test("unified variants are one step and empty catalogs are inert", function()
    local model = openModel({
        variant("a", "A", 3),
        variant("unified", "Unified", 4),
        variant("z", "Z", 1),
    })
    assertKeys(flatKeys(model), { "a:3", "unified:4", "z:1" })
    model:Select("a:3")
    model:MoveHorizontal(1)
    assertEqual(model:GetSelected().key, "unified:4")
    model:MoveHorizontal(1)
    assertEqual(model:GetSelected().key, "z:1")

    local empty = openModel({})
    assertEqual(empty:GetSelected(), nil)
    assertEqual(#empty:GetRows(), 0)
    assertEqual(select(1, empty:GetPosition()), 0)
    assertEqual(select(2, empty:GetPosition()), 0)
    assertEqual(empty:Select("anything"), false)
end)

test("missing saved keys fall back without pruning durable preferences", function()
    local account = {
        favorites = { ["missing:1"] = true },
        hidden = { ["missing:2"] = true },
    }
    local character = {
        selectedKey = "missing:3",
        preferredWeight = 3,
        showHidden = false,
    }
    local model = openModel({ variant("known", "Known", 1) }, account, character)

    assertEqual(model:GetSelected().key, "known:1")
    assertEqual(character.selectedKey, "known:1")
    assertEqual(character.preferredWeight, 3,
        "automatic restore fallback must not overwrite the preferred weight")
    assertTrue(account.favorites["missing:1"])
    assertTrue(account.hidden["missing:2"])
    assertEqual(countHeaders(model), 0,
        "unknown favorite keys must not create empty groups")
end)

test("catalog refresh preserves the open favorite snapshot and refreshes records", function()
    local model, account = openModel({
        variant("breton", "Breton", 1),
        variant("dunmer", "Dunmer", 1),
    })
    model:Select("dunmer:1")
    model:ToggleFavorite()
    assertTrue(account.favorites["dunmer:1"])

    local refreshedDunmer = variant("dunmer", "Dunmer", 1)
    refreshedDunmer.partCount = 6
    local refreshedSelection = model:RefreshCatalog({
        refreshedDunmer,
        variant("altmer", "Altmer", 1),
        variant("breton", "Breton", 1),
    })

    assertEqual(countHeaders(model), 0,
        "a favorite marked after Open must not move during refresh")
    assertKeys(flatKeys(model), { "altmer:1", "breton:1", "dunmer:1" })
    assertEqual(model:GetSelected(), refreshedDunmer,
        "surviving keys must resolve to the refreshed record object")
    assertEqual(refreshedSelection, refreshedDunmer,
        "refresh returns the current record so preview can reapply unchanged keys")

    model:Open()
    assertEqual(countHeaders(model), 2)
    assertKeys(flatKeys(model), { "dunmer:1", "altmer:1", "breton:1" })
end)

test("catalog refresh reconciles a removed selection in previous order", function()
    local model = openModel({
        variant("a", "A", 1),
        variant("b", "B", 1),
        variant("c", "C", 1),
        variant("d", "D", 1),
    })

    model:Select("b:1")
    model:RefreshCatalog({
        variant("a", "A", 1),
        variant("c", "C", 1),
        variant("d", "D", 1),
    })
    assertEqual(model:GetSelected().key, "c:1", "next old-order survivor wins")

    model:Select("d:1")
    model:RefreshCatalog({
        variant("a", "A", 1),
        variant("c", "C", 1),
    })
    assertEqual(model:GetSelected().key, "c:1", "previous survivor is the fallback")

    model:RefreshCatalog({ variant("new", "New", 1) })
    assertEqual(model:GetSelected().key, "new:1",
        "a new first entry is used only when no old-order survivor remains")
end)

test("catalog refresh can reveal an open-snapshot favorite that was previously missing", function()
    local account = {
        favorites = { ["returning:2"] = true },
        hidden = {},
    }
    local model = openModel({ variant("known", "Known", 1) }, account)
    assertEqual(countHeaders(model), 0)

    model:RefreshCatalog({
        variant("known", "Known", 1),
        variant("returning", "Returning", 2),
    })
    assertEqual(countHeaders(model), 2)
    assertKeys(flatKeys(model), { "returning:2", "known:1" })
end)

test("catalog refresh to empty clears selection without changing preference", function()
    local model, _, character = openModel({ variant("known", "Known", 3) }, nil, {
        selectedKey = "known:3",
        preferredWeight = 3,
        showHidden = false,
    })

    local refreshedSelection = model:RefreshCatalog({})
    assertEqual(refreshedSelection, nil)
    assertEqual(model:GetSelected(), nil)
    assertEqual(#model:GetRows(), 0)
    assertEqual(select(1, model:GetPosition()), 0)
    assertEqual(select(2, model:GetPosition()), 0)
    assertEqual(character.preferredWeight, 3)
end)

local passed = 0
for _, case in ipairs(tests) do
    local ok, failure = pcall(case.body)
    if not ok then
        io.stderr:write("FAIL: " .. case.name .. "\n" .. tostring(failure) .. "\n")
        os.exit(1)
    end
    passed = passed + 1
    io.write("PASS: " .. case.name .. "\n")
end

io.write(string.format("%d model tests passed\n", passed))
