local K = KanaPenetration
local NAME = 'KanaPenetration'

function K:SetPolling(active)
    if active == self.polling then return end
    self.polling = active
    if active then
        EVENT_MANAGER:RegisterForUpdate(NAME, 100, function() self:Refresh() end)
    else
        EVENT_MANAGER:UnregisterForUpdate(NAME)
    end
end

function K:Refresh()
    if self.view.root:IsHidden() then
        self:SetPolling(false)
        self.view:Hide()
        return
    end
    local snapshot = self.saved.enabled and self.observer:Capture(self.saved) or nil
    local fading = self.saved.enabled and not DoesUnitExist('reticleover')
    self.view:Render(snapshot, fading)
    self:SetPolling(snapshot ~= nil and self.view.visible == true)
end

local function Initialize(_, addonName)
    if addonName ~= NAME then return end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    K.saved = ZO_SavedVars:NewCharacterIdSettings('KanaPenetrationSV', 1, nil, K.Defaults)
    K.Normalize(K.saved)
    K.russian = GetCVar('language.2') == 'ru'
    K.observer = K.Observer.New(_G)
    K.view = K.View.New(K.saved, K.russian)
    K.view.root:SetHandler('OnShow', function() K:Refresh() end)
    K.view.root:SetHandler('OnHide', function() K:SetPolling(false); K.view:Hide() end)
    local fragment = ZO_SimpleSceneFragment:New(K.view.root)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    for _, event in ipairs({EVENT_RETICLE_TARGET_CHANGED, EVENT_PLAYER_ACTIVATED,
        EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, EVENT_SCREEN_RESIZED}) do
        EVENT_MANAGER:RegisterForEvent(NAME, event, function() K:Refresh() end)
    end
    K:RegisterSettings()
    K:Refresh()
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, Initialize)
