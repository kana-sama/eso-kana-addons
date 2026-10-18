local addon = KanaCombatBookmarks
local NAME = 'KanaCombatBookmarks'

function addon.Mark()
    if addon.adapter then return addon.adapter:Mark() end
    return nil, 'unavailable'
end

function addon.Initialize(a)
    if addon.adapter then return end
    addon.Settings.Initialize(a)
    if not a.CMX or not a.CMX.db or not a.CMX.currentdata
        or not a.LibCombat or type(a.LibCombat.RegisterForCombatEvent) ~= 'function'
        or not a.CombatMetricsFightData or type(a.CombatMetricsFightData.Save) ~= 'function' then
        a.ZO_AlertNoSuppression(a.UI_ALERT_CATEGORY_ALERT, nil, 'KanaCombatBookmarks: Combat Metrics недоступен.')
        return
    end
    local adapter = addon.Integration.Install(a)
    local view = addon.Settings.Enabled('log', a) and addon.LogView.New(a, adapter) or nil
    addon.adapter, addon.view = adapter, view
    if view then
        adapter.onChanged = function()
            if view.refreshPending then return end
            view.refreshPending = true
            -- CMX updates its report before our FIGHTSUMMARY callback attaches metadata.
            -- Defer the second update; the bookmark binding never traverses the log.
            a.zo_callLater(function()
                view.refreshPending = false
                if view:Install() and not view.panel:IsHidden() then view.panel:Update() end
            end, 1)
        end
        local report = a.CombatMetrics_Report
        if report then
            a.ZO_PreHookHandler(report, 'OnShow', function() view:Install() end)
            view:Install() -- CMX initializes its report lazily; retry on first show.
        end
    end
end

if not addon.registered then
    addon.registered = true
    ZO_CreateStringId('SI_BINDING_NAME_KANA_COMBAT_BOOKMARK', 'Поставить закладку в Combat Metrics')
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, function(_, name)
        if name ~= NAME then return end
        EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
        addon.Initialize(_G)
    end)
end
