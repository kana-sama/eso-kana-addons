local Addon = KanaTargetEffectsInspect
local View = {}
View.__index = View
Addon.View = View

function View.New()
    local self = setmetatable({}, View)
    self.root = WINDOW_MANAGER:CreateTopLevelWindow('KanaTargetEffectsInspectWindow')
    self.root:SetAnchorFill(GuiRoot)
    self.root:SetMouseEnabled(false)
    self.root:SetDrawTier(DT_LOW)
    self.root:SetHidden(true)
    self.content = WINDOW_MANAGER:CreateControl('KanaTargetEffectsInspectContent', self.root, CT_CONTROL)
    self.content:SetAnchorFill(self.root)
    self.content:SetMouseEnabled(false)
    self.content:SetHidden(true)
    self.pool = ZO_ControlPool:New('ZO_BuffDebuffIcon', self.content, 'Effect')
    self.pool:SetCustomFactoryBehavior(function(control)
        control:SetHandler('OnMouseEnter', function()
            if not control.data then return end
            InitializeTooltip(InformationTooltip, control, BOTTOM)
            InformationTooltip:AddLine(zo_strformat(SI_ABILITY_TOOLTIP_NAME, control.data.buffName), 'ZoFontWinH4')
            InformationTooltip:AddVerticalPadding(6)
            InformationTooltip:AddLine(GetCVar('language.2') == 'ru'
                and 'Снимок при включении курсора' or 'Snapshot taken when the cursor was enabled')
        end)
        control:SetHandler('OnMouseExit', function() self:ClearTooltip(control) end)
    end)
    self.pool:SetCustomResetBehavior(function(control)
        self:ClearTooltip(control)
        control.blinkAnimation:Stop()
        control.cooldown:ResetCooldown()
        control.cooldown:SetHidden(true)
        control:SetAlpha(1)
        control.data = nil
    end)
    self.fragment = ZO_SimpleSceneFragment:New(self.root)
    HUD_UI_SCENE:AddFragment(self.fragment)
    return self
end

function View:ClearTooltip(control)
    if InformationTooltip:GetOwner() == control then ClearTooltip(InformationTooltip) end
end

function View:GetPools()
    return {activeObjects = self.pool:GetActiveObjects()}, {activeObjects = {}}
end

function View:Show(snapshot)
    self:Hide()
    self.style = snapshot.style
    for _, entry in ipairs(snapshot.icons) do
        local control = self.pool:AcquireObject()
        control:SetScale(1)
        ApplyTemplateToControl(control, ZO_GetPlatformTemplate('ZO_BuffDebuffIcon'))
        -- GetScreenRect and anchors use UI coordinates; measure instead of assuming a HUD scale.
        local scale = entry.width / control:GetWidth()
        control:SetDimensions(entry.width / scale, entry.height / scale)
        control:SetScale(scale)
        control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, entry.left - GuiRoot:GetLeft(), entry.top - GuiRoot:GetTop())
        control.data = entry.data
        control.showCooldown = entry.showCooldown
        control:SetMouseEnabled(true)
        self.style:SetupIcon(control)
    end
    self:Update()
    self.content:SetHidden(false)
end

function View:Update()
    if self.style then self.style:UpdateDurations(self) end
end

function View:Hide()
    self.content:SetHidden(true)
    self.pool:ReleaseAllObjects()
    self.style = nil
end
