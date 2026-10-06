local K=KanaStatSources
local T={};K.Tooltip=T
local Bridge={};Bridge.__index=Bridge
function Bridge:Clear() self.active=nil;self.stat=nil;if self.view then self.view:Clear()end end
function Bridge:Refresh() local active=self.active;if active then self.api.ZO_StatsEntry_OnMouseEnter(active)end end
function T.Install(api,getBreakdown)
    if api.KanaStatSourcesTooltipBridge then return api.KanaStatSourcesTooltipBridge end
    local b=setmetatable({api=api,getBreakdown=getBreakdown,diagnostics={},hooked=setmetatable({},{__mode='k'})},Bridge)
    if not api.InformationTooltip or not api.ZO_PostHook or not api.ZO_PostHookHandler or not api.ZO_StatsEntry_OnMouseEnter or not api.ZO_StatsEntry_OnMouseExit then b.diagnostics[1]={reason='native keyboard tooltip hooks unavailable'};return b end
    b.view=K.Table.New(api,api.InformationTooltip)
    api.ZO_PostHookHandler(api.InformationTooltip,'OnCleared',function()b:Clear()end)
    api.ZO_PostHook('ZO_StatsEntry_OnMouseEnter',function(control)
        local key=control.statEntry and K.Stats.KeyForId(api,control.statEntry.statType)
        if not key then b:Clear();return end
        local breakdown,language=getBreakdown(key)
        if not breakdown then b:Clear();return end
        b.active=control;b.stat=key
        local scale=api.GetUIGlobalScale and api.GetUIGlobalScale() or 1
        b.view:Render(breakdown,language or 'en',{width=api.GuiRoot:GetWidth()*scale,height=api.GuiRoot:GetHeight()*scale,scale=scale,nativeHeight=api.InformationTooltip:GetHeight()})
        if not b.hooked[control] then
            b.hooked[control]=true
            api.ZO_PostHookHandler(control,'OnMouseWheel',function(_,delta)if b.active==control then b.view:Scroll(delta)end end)
            api.ZO_PostHookHandler(control,'OnEffectivelyHidden',function()if b.active==control then b:Clear()end end)
        end
    end)
    api.ZO_PostHook('ZO_StatsEntry_OnMouseExit',function()b:Clear()end)
    api.KanaStatSourcesTooltipBridge=b
    return b
end
