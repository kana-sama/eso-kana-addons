local K=KanaStatSources
local T={};K.Tooltip=T
local Bridge={};Bridge.__index=Bridge
function Bridge:Reset()
    self.active=nil;self.stat=nil;if self.view then self.view:Clear()end
end
function Bridge:Clear()
    if self.tooltip then self.api.ClearTooltipImmediately(self.tooltip)end
    self:Reset()
end
function Bridge:Hide()
    -- ClearTooltip preserves lines and geometry until its fade timeline hides
    -- the control. Stop live refreshes now; release the view only on OnHide.
    self.active=nil;self.stat=nil
    if self.tooltip then self.api.ClearTooltip(self.tooltip)end
end
function Bridge:Show(control,keepLayout)
    local api=self.api
    local entry=control and control.statEntry
    local key=entry and K.Stats.KeyForId(api,entry.statType)
    local description=entry and api.ZO_STAT_TOOLTIP_DESCRIPTIONS[entry.statType]
    if not key or not description then self:Clear();return false end
    local breakdown,language=self.getBreakdown(key)
    if not breakdown then self:Clear();return false end
    local name=api.GetString('SI_DERIVEDSTATS',entry.statType)
    local title=api.SI_STAT_NAME_FORMAT and api.zo_strformat(api.SI_STAT_NAME_FORMAT,name) or name
    local displayValue=entry.GetDisplayValue and entry:GetDisplayValue() or (breakdown.available and K.Stats.Number(breakdown.total,language) or '')
    description=api.zo_strformat(description,displayValue)
    if not keepLayout then api.InitializeTooltip(self.tooltip,control,entry.tooltipAnchorSide,-5)end
    self.active=control;self.stat=key
    self.view:Render(breakdown,language or 'en',{width=api.GuiRoot:GetWidth(),height=api.GuiRoot:GetHeight(),title=title,description=description,keepLayout=keepLayout})
    if not self.hooked[control] then
        self.hooked[control]=true
        api.ZO_PostHookHandler(control,'OnMouseWheel',function(_,delta)if self.active==control then self.view:Scroll(delta)end end)
        api.ZO_PostHookHandler(control,'OnEffectivelyHidden',function()if self.active==control then self:Clear()end end)
    end
    return true
end
function Bridge:Refresh()
    if self.active then self:Show(self.active,true)end
end
function T.Install(api,getBreakdown)
    if api.KanaStatSourcesTooltipBridge then return api.KanaStatSourcesTooltipBridge end
    local b=setmetatable({api=api,getBreakdown=getBreakdown,diagnostics={},hooked=setmetatable({},{__mode='k'})},Bridge)
    if not api.WINDOW_MANAGER or not api.WINDOW_MANAGER.CreateControlFromVirtual or not api.ZO_PreHook or not api.ZO_PostHookHandler or not api.InitializeTooltip or not api.ClearTooltip or not api.ClearTooltipImmediately or not api.ZO_STAT_TOOLTIP_DESCRIPTIONS or not api.ZO_StatsEntry_OnMouseEnter or not api.ZO_StatsEntry_OnMouseExit then b.diagnostics[1]={reason='native keyboard tooltip hooks unavailable'};return b end
    -- InformationTooltip is shared with map pins and other UI. A private
    -- native tooltip owns every constraint, content control and animation.
    b.tooltip=api.WINDOW_MANAGER:CreateControlFromVirtual(K.name..'Tooltip',api.GuiRoot,'ZO_BaseTooltip')
    b.view=K.Table.New(api,b.tooltip)
    api.ZO_PostHookHandler(b.tooltip,'OnCleared',function()b:Reset()end)
    api.ZO_PostHookHandler(b.tooltip,'OnHide',function()b:Reset()end)
    -- Native description and sources share one measured content block.
    api.ZO_PreHook('ZO_StatsEntry_OnMouseEnter',function(control)return b:Show(control,false)end)
    api.ZO_PreHook('ZO_StatsEntry_OnMouseExit',function(control)
        if b.active==control then b:Hide();return true end
        return false
    end)
    api.KanaStatSourcesTooltipBridge=b
    return b
end
