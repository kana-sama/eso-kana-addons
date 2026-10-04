local F = {}
TestSupport.Fixtures = F
function F.Selector(id) return { kind = "ability", id = id or 100 } end
function F.Widget(id)
    return { id = id or "widget-a", name = "Effects", type = "table", unitTag = "player",
        layout = { columns = 6, rows = 3, fixedAxis = "columns", count = 6, gap = 4, absent = "ghost", ghostAlpha = 0.3 },
        anchor = { pointX = 0, pointY = 0, relativeTo = "screen", relativePointX = 0, relativePointY = 0, x = 20, y = 40 },
        style = { mode = "right", iconSize = 32, timerFontSize = 16, nameFontSize = 16, rowWidth = 160 },
        slots = { [1] = { [1] = F.Selector(100) }, [3] = { [6] = F.Selector(200) } },
        rules = { includeSets = {}, excludeSets = {}, named = "any", mergePairs = true } }
end
function F.Profile()
    return { schemaVersion = 1, widgets = { F.Widget() }, sets = {}, hidden = {}, longThreshold = 60,
        editor = { toolbarX = 10, toolbarY = 20 } }
end
function F.Unit(tag, generation)
    return { tag = tag or "player", generation = generation or 1, unitId = 7, name = "Unit" }
end
function F.Observation(id, overrides)
    local result = { key = "player:1:1", unit = F.Unit(), abilityId = id or 100, effectSlot = 1,
        kind = "buff", startTime = 10, endTime = 70, lifetime = "finite", fullDuration = 60,
        stacks = 1, castBy = "self", observedAt = 10, synthetic = true,
        catalog = { abilityId = id or 100, name = "Fixture", icon = "fixture.dds", aliases = {},
            categories = {}, origin = "unknown", apiVersion = 0, provenance = "test fixture", verified = false } }
    for key, value in pairs(overrides or {}) do result[key] = value end
    return result
end
