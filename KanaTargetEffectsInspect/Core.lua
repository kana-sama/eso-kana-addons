local Addon = KanaTargetEffectsInspect
local NAME = 'KanaTargetEffectsInspect'
local Controller = {}
Controller.__index = Controller

function Controller:Fail(reason)
    self.disabled = true
    self.active, self.armed, self.pending, self.cache = false, false, nil, nil
    if self.view then pcall(self.view.Hide, self.view) end
    if self.container then
        self.container.isDirty = true
        pcall(self.container.RefreshContainerVisibility, self.container)
    end
    if not self.warned then
        self.warned = true
        d(Addon.displayName .. ': ' .. (GetCVar('language.2') == 'ru'
            and 'просмотр эффектов недоступен: ' or 'effect inspection unavailable: ') .. tostring(reason))
    end
end

function Controller:Safe(method, ...)
    if self.disabled then return end
    local ok, err = pcall(method, self, ...)
    if not ok then self:Fail(err) end
end

function Controller:Reset()
    self.active, self.armed, self.pending, self.cache = false, false, nil, nil
    self.view:Hide()
    self.container.isDirty = true
    self.container:RefreshContainerVisibility()
end

function Controller:CanPrepare()
    local nextScene = SCENE_MANAGER:GetNextScene()
    return SCENE_MANAGER:GetCurrentScene() == HUD_SCENE
        and (not nextScene or nextScene == HUD_UI_SCENE)
        and not IsInGamepadPreferredMode() and IsGameCameraActive()
end

function Controller:Capture()
    if not self.active and not self.armed and not IsGameCameraUIModeActive() and self:CanPrepare() then
        self.cache = DoesUnitExist('reticleover') and Addon.Native.Capture(self.container) or nil
    end
end

function Controller:Prepare(inUIMode)
    if not inUIMode or IsGameCameraUIModeActive() or not self:CanPrepare() then return end
    -- Runs BEFORE SetGameCameraUIMode can invalidate reticleover or hide its frame.
    self.pending = DoesUnitExist('reticleover') and Addon.Native.Capture(self.container) or nil
    self.armed = true
end

function Controller:CameraChanged()
    if not IsGameCameraUIModeActive() then
        self:Reset()
    elseif not self.armed and not self.active and self:CanPrepare() then
        -- Also supports camera-mode changes which bypass the scene manager's method.
        self.pending, self.armed = self.cache, true
    end
end

function Controller:Begin()
    local snapshot = self.armed and self.pending
    self.pending, self.armed, self.cache = nil, false, nil
    if not snapshot or IsInGamepadPreferredMode() or not IsGameCameraUIModeActive() then return end
    self.active = true
    self.view:Show(snapshot)
    self.container:RefreshContainerVisibility()
end

function Controller:LeavingHUD()
    if SCENE_MANAGER:GetNextScene() ~= HUD_UI_SCENE then
        self:Reset()
    elseif IsGameCameraUIModeActive() then
        self:CameraChanged()
    else
        -- The cursor binding calls Show(hudui). Its pre-show hook enables UI mode
        -- only after currentScene changes, so save the visible target here.
        self:Prepare(true)
    end
end

function Addon.Initialize(addonName)
    if addonName ~= NAME or Addon.initialized then return end
    Addon.initialized = true
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    local self = setmetatable({}, Controller)
    Addon.instance = self
    self:Safe(function()
        assert(HUD_SCENE and HUD_UI_SCENE and SCENE_MANAGER and type(SCENE_MANAGER.SetInUIMode) == 'function',
            'HUD scenes unavailable')
        assert(type(IsGameCameraUIModeActive) == 'function' and type(ZO_PreHook) == 'function', 'cursor API unavailable')
        self.container = BUFF_DEBUFF and BUFF_DEBUFF.containerObjectsByUnitTag
            and BUFF_DEBUFF.containerObjectsByUnitTag.reticleover
        Addon.Native.Bind(self.container, function() self:Safe(self.Capture) end,
            function() return self.active and not self.disabled end)
        self.view = Addon.View.New()
        self.view.content:SetHandler('OnUpdate', function() self:Safe(function() self.view:Update() end) end)
        ZO_PreHook(SCENE_MANAGER, 'SetInUIMode', function(_, value) self:Safe(self.Prepare, value) end)
        HUD_SCENE:RegisterCallback('StateChange', function(_, state)
            if state == SCENE_HIDING then self:Safe(self.LeavingHUD) end
        end)
        HUD_UI_SCENE:RegisterCallback('StateChange', function(_, state)
            if state == SCENE_SHOWING then self:Safe(self.Begin)
            elseif state == SCENE_HIDING or state == SCENE_HIDDEN then self:Safe(self.Reset) end
        end)
        EVENT_MANAGER:RegisterForEvent(NAME, EVENT_GAME_CAMERA_UI_MODE_CHANGED, function() self:Safe(self.CameraChanged) end)
        EVENT_MANAGER:RegisterForEvent(NAME, EVENT_RETICLE_TARGET_CHANGED, function()
            if not self.armed and not self.active and not IsGameCameraUIModeActive() and not DoesUnitExist('reticleover') then
                self.cache = nil
            end
        end)
        for _, event in ipairs({EVENT_PLAYER_DEACTIVATED, EVENT_PLAYER_ACTIVATED,
            EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, EVENT_SCREEN_RESIZED}) do
            EVENT_MANAGER:RegisterForEvent(NAME, event, function() self:Safe(self.Reset) end)
        end
        self:Capture()
    end)
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, function(_, name) Addon.Initialize(name) end)
