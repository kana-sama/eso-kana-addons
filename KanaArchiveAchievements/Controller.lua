local K = KanaArchiveAchievements
local C = {}
K.Controller = C

function C.Install(api, model, view, settings)
    local self = setmetatable({api = api, model = model, view = view, settings = settings or {
        indicators = true, tooltips = true,
    }}, {__index = C})
    for _, selector in ipairs({api.ENDLESS_DUNGEON_BUFF_SELECTOR_KEYBOARD, api.ENDLESS_DUNGEON_BUFF_SELECTOR_GAMEPAD}) do
        api.SecurePostHook(selector, 'OnShowing', function(object)
            self.active = object
            if self.settings.indicators then view:UpdateIndicators(object, model) end
            if object.selectedBuffControl then self:Highlight(object, object.selectedBuffControl) end
        end)
        api.SecurePostHook(selector, 'SelectBuff', function(object, buff) self:Highlight(object, buff) end)
        api.SecurePostHook(selector, 'RefreshBuffs', function(object)
            if self.active ~= object then return end
            self.abilityId, self.bucketType = nil, nil
            view:Hide()
            if self.settings.indicators then view:UpdateIndicators(object, model) end
            if api.IsInGamepadPreferredMode() and object.selectedBuffControl then self:Highlight(object, object.selectedBuffControl) end
        end)
        api.SecurePostHook(selector, 'SetIsRerolling', function(object, rerolling)
            if rerolling then self:Clear(object) end
        end)
        api.SecurePostHook(selector, 'CommitChoice', function(object) self:Clear(object) end)
        api.SecurePostHook(selector, 'OnHiding', function(object)
            self:Clear(object)
            if self.active == object then self.active = nil end
        end)
    end
    local function refresh()
        local selector = self.active
        if not selector or selector.control:IsHidden() or selector.isRerolling then return end
        if self.settings.indicators then view:UpdateIndicators(selector, model) end
        if self.settings.tooltips and self.abilityId then
            view:Show(selector, model:GetGoals(self.abilityId, self.bucketType), false)
        end
    end
    api.EVENT_MANAGER:RegisterForEvent('KanaArchiveAchievements', api.EVENT_ACHIEVEMENT_UPDATED, refresh)
    api.EVENT_MANAGER:RegisterForEvent('KanaArchiveAchievements', api.EVENT_ACHIEVEMENT_AWARDED, refresh)
    api.EVENT_MANAGER:RegisterForEvent('KanaArchiveAchievements', api.EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
        if self.active then self:Clear(self.active); self.active = nil end
    end)
    api.EVENT_MANAGER:RegisterForEvent('KanaArchiveAchievements', api.EVENT_SCREEN_RESIZED, function() view:Layout() end)
    api.EVENT_MANAGER:RegisterForEvent('KanaArchiveAchievements', api.EVENT_INTERFACE_SETTING_CHANGED, function() view:Layout() end)
    return self
end

function C:Highlight(selector, buff)
    if not buff or selector.control:IsHidden() or selector.isRerolling then return end
    local changed = self.active ~= selector or self.abilityId ~= buff.abilityId or self.bucketType ~= buff.bucketType
    self.active, self.abilityId, self.bucketType = selector, buff.abilityId, buff.bucketType
    if self.settings.tooltips then
        self.view:Show(selector, self.model:GetGoals(buff.abilityId, buff.bucketType), changed)
    end
end

function C:Clear(selector)
    self.view:HideIndicators(selector)
    if self.active == selector then
        self.abilityId, self.bucketType = nil, nil
        self.view:Hide()
    end
end
