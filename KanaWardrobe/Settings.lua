KanaWardrobe = KanaWardrobe or {}
local KW = KanaWardrobe
KW.Settings = {}

function KW.Settings.Register(runtime)
    local lam = runtime.api.LibAddonMenu2 or LibAddonMenu2
    if not lam then return end
    local russian = runtime.api.GetCVar and runtime.api.GetCVar("language.2") == "ru"
    local panelId = "KanaWardrobeSettings"
    lam:RegisterAddonPanel(panelId, {
        type = "panel",
        name = "|cFF0000Kana|r |cFFFFFFWardrobe|r",
        displayName = "|cFF0000Kana|r |cFFFFFFWardrobe|r",
        author = "Kana",
        version = "0.1.0",
    })
    lam:RegisterOptionControls(panelId, {
        {type = "button", name = russian and "Показать состояние" or "Show status", func = function()
            if runtime.api.d then runtime.api.d(KW.Core.Status(runtime)) end
        end},
        {type = "button", name = russian and "Показать отчёт производительности" or "Show performance report", func = function()
            KW.ProbeReport.Show(runtime.repo.character.performanceReport or "No page timing recorded yet.")
        end},
        {type = "button", name = russian and "Показать возможности API" or "Show API capabilities", func = function()
            if runtime.api.d then runtime.api.d(KW.Core.BuildCapabilitiesStatus(runtime)) end
        end},
    })
end
