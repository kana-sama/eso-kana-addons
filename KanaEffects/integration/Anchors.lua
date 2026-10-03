-- Sole owner of verified stock-control geometry and retained UI references.
-- All coordinates already use GuiRoot UI units; never multiply UI scale again.
local Anchors = {}
KanaEffects.Anchors = Anchors
local nextOwner = 0
function Anchors.New(api)
    nextOwner = nextOwner + 1
    local owner = {api=api, last={}, diagnostics={}, observers={}, nextObserver=0, events={}, nativeCallbacks={}, targetCallbacks={}, name='KanaEffectsAnchors'..nextOwner}
    return setmetatable(owner, {__index=Anchors})
end
local function rect(control)
    if not control then return nil end
    local width,height=control:GetDimensions(); local x,y=control:GetLeft(),control:GetTop()
    local function valid(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
    if not valid(x) or not valid(y) or not valid(width) or not valid(height) then return nil end
    if width<=0 or height<=0 then return nil end
    return {x=x,y=y,width=width,height=height}
end
local function copy(r) return {x=r.x,y=r.y,width=r.width,height=r.height} end
function Anchors:GetReferenceRect(referenceId)
    local c=self.api.controls; local value
    if referenceId=='screen' then value=rect(c.GuiRoot)
    elseif referenceId=='targetFrame' then value=rect(self.api.GetTargetFrameControl and self.api.GetTargetFrameControl() or c.ZO_TargetUnitFramereticleover)
    elseif referenceId=='actionBar' then value=rect(c.ZO_ActionBar1)
    elseif referenceId=='resources' then
        for _,name in ipairs({'ZO_PlayerAttributeHealth','ZO_PlayerAttributeMagicka','ZO_PlayerAttributeStamina'}) do
            local r=rect(c[name]); if r then
                if not value then value=r else
                    local right,bottom=math.max(value.x+value.width,r.x+r.width),math.max(value.y+value.height,r.y+r.height)
                    value.x,value.y=math.min(value.x,r.x),math.min(value.y,r.y); value.width,value.height=right-value.x,bottom-value.y
                end
            end
        end
    else error('unsupported reference: '..tostring(referenceId)) end
    if value then self.last[referenceId]=copy(value); self.diagnostics[referenceId]=nil; return value end
    self.diagnostics[referenceId]={code='reference_unavailable',referenceId=referenceId,message='Опора недоступна; сохранена последняя позиция.'}
    -- An unseen missing reference falls back to the screen, preserving saved
    -- offsets. Once seen its original UI-unit rectangle remains authoritative.
    return copy(self.last[referenceId] or assert(rect(c.GuiRoot),'GuiRoot unavailable'))
end
function Anchors:GetDiagnostics()
    local list={}; for _,r in pairs(self.diagnostics) do local v={}; for k,x in pairs(r) do v[k]=x end; list[#list+1]=v end; return list
end
function Anchors:Observe(onChanged)
    assert(type(onChanged) == 'function', 'Observe expects callback')
    self.nextObserver = self.nextObserver + 1
    local id = self.nextObserver; self.observers[id] = onChanged
    if not next(self.events) and not next(self.nativeCallbacks) and not next(self.targetCallbacks) then
        local constants, manager = self.api.constants, self.api.eventManager
        local function notify()
            -- Snapshot registrations so a callback may safely unsubscribe itself
            -- or another observer; removed callbacks cannot run afterward.
            local snapshot={}; for key,callback in pairs(self.observers) do snapshot[key]=callback end
            for key,callback in pairs(snapshot) do if self.observers[key] == callback then callback() end end
        end
        local function subscribe(event, callback)
            if event and manager then
                manager:RegisterForEvent(self.name,event,callback); self.events[event]=true
            end
        end
        local hud=self.api.hudManager
        if hud and hud.RegisterCallback and hud.UnregisterCallback then
            hud:RegisterCallback('OffsetsChanged',notify); self.nativeCallbacks[notify]=true
        end
        local callbacks=self.api.callbackManager
        if callbacks and callbacks.RegisterCallback and callbacks.UnregisterCallback then
            callbacks:RegisterCallback('TargetFrameCreated',notify); self.targetCallbacks[notify]=true
        end
        subscribe(constants.EVENT_SCREEN_RESIZED, notify)
        subscribe(constants.EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, notify)
        subscribe(constants.EVENT_INTERFACE_SETTING_CHANGED, function(_,system,setting)
            if system == constants.SETTING_TYPE_UI and setting ~= nil
                and (setting == constants.UI_SETTING_CUSTOM_SCALE or setting == constants.UI_SETTING_USE_CUSTOM_SCALE
                    or setting == constants.UI_SETTING_GAMEPAD_CUSTOM_SCALE or setting == constants.UI_SETTING_USE_GAMEPAD_CUSTOM_SCALE)
                then notify() end
        end)
    end
    local active = true
    return function()
        if not active then return end
        active=false; self.observers[id]=nil
        if not next(self.observers) then
            for event in pairs(self.events) do self.api.eventManager:UnregisterForEvent(self.name,event) end
            self.events={}
            for fn in pairs(self.nativeCallbacks) do self.api.hudManager:UnregisterCallback('OffsetsChanged',fn) end
            self.nativeCallbacks={}
            for fn in pairs(self.targetCallbacks) do self.api.callbackManager:UnregisterCallback('TargetFrameCreated',fn) end
            self.targetCallbacks={}
        end
    end
end
