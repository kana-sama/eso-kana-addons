-- Borrowed Session/Runtime/Editor. Stable proxy registrations live until reload.
local NativeHUD={}; NativeHUD.__index=NativeHUD; KanaEffects.NativeHUD=NativeHUD
local function find(p,id) for _,w in ipairs(p.widgets) do if w.id==id then return w end end end
local function stable(id) return (string.gsub(id,'.',function(c) return string.format('%02x',string.byte(c)) end)) end
function NativeHUD.New(api,anchors,session)
    return setmetatable({api=api,anchors=anchors,session=session,records={},callbacks={}},NativeHUD)
end
function NativeHUD:IsEditing() return not self.disposed and (self.editing==true or (self.api.NativeHUDEditorPending and self.api.NativeHUDEditorPending()==true))==true end
function NativeHUD:_Refresh(id)
    local record=self.records[id]; if not record or self.disposed then return end
    local view=self.runtime:GetView(id)
    local previousValid=record.valid
    record.valid=view~=nil
    if view and view.widget then record.title=view.widget.name end
    if not view then record.control:SetHidden(true); return previousValid~=record.valid end
    local rect=view.layout.rect
    local m=view.layout.measurement or {}
    record.control:SetDimensions(math.max(rect.width,m.cellWidth or 1),math.max(rect.height,m.cellHeight or 1)); record.control:SetHidden(false)
    local screen=self.anchors:GetReferenceRect('screen'); local added=false
    if not record.element then
        record.control:ClearAnchors(); record.control:SetAnchor(self.api.constants.TOPLEFT,self.api.controls.GuiRoot,self.api.constants.TOPLEFT,rect.x-screen.x,rect.y-screen.y)
        record.element=self.api.hudManager:RegisterKeyboardElement(record.control,function() return record.title end,{isValid=function() return not self.disposed and record.valid end},{})
        added=true
    end
    self.applying=true
    record.element:ApplyOffset(rect.x-screen.x,rect.y-screen.y,false)
    self.applying=false
    return added or previousValid~=record.valid
end
function NativeHUD:_Offsets(element)
    if self.disposed or self.applying or not self:IsEditing() or self.editor:IsOpen() then return end
    local id,record
    for key,r in pairs(self.records) do if r.element==element then id,record=key,r; break end end
    if not record or not record.valid then return end
    if self.session:ReadDraft() then return end -- never borrow someone else's draft
    local profile=self.session:Begin(); local widget=find(profile,id)
    if not widget then self.session:Cancel(); return end
    local view=self.runtime:GetView(id); local control=record.control
    local rect={x=control:GetLeft(),y=control:GetTop(),width=view.layout.rect.width,height=view.layout.rect.height}
    local anchor=KanaEffects.Layout.Reanchor(widget.anchor,rect,widget.anchor.pointX,widget.anchor.pointY,self.anchors:GetReferenceRect(widget.anchor.relativeTo))
    local ok,diag=self.session:Apply({type='widget.patch',widgetId=id,patch={anchor=anchor}})
    local candidate=self.session:ReadDraft()
    if ok then ok,diag=self.session:Save() end
    if ok then self.runtime:ApplyConfig(candidate)
    else self.session:Cancel(); if self.api.LocalMessage then self.api.LocalMessage('KanaEffects: не удалось сохранить позицию штатного HUD.') end end
end
function NativeHUD:Bind(runtime,editor,root)
    self.runtime,self.editor,self.root=runtime,editor,root
    local api=self.api; local manager=api.hudManager
    self.unsubscribeViews=runtime:SubscribeViews(function(id)
        if self:_Refresh(id) and api.capabilities.nativeHudRebuild then manager:RebuildAllElements() end
    end)
    if manager and api.capabilities.nativeHudCallbacks then
        for _,name in ipairs({'SavedVarsReady','PropagateSettings','RebuildAllElements'}) do
            local callback=function() for id in pairs(self.records) do self:_Refresh(id) end end
            manager:RegisterCallback(name,callback); self.callbacks[#self.callbacks+1]={owner=manager,name=name,callback=callback}
        end
        local callback=function(element) self:_Offsets(element) end
        manager:RegisterCallback('OffsetsChanged',callback); self.callbacks[#self.callbacks+1]={owner=manager,name='OffsetsChanged',callback=callback}
    end
    local scene=api.hudEditorScene
    if scene and scene.RegisterCallback then
        local callback=function(_,state)
            if self.disposed then return end
            if state==api.constants.SCENE_SHOWING or state==api.constants.SCENE_SHOWN then
                self.editing=true
                if editor:IsOpen() then editor.cursorOwned=nil; editor:Cancel() end
            elseif state==api.constants.SCENE_HIDDEN then self.editing=false end
        end
        scene:RegisterCallback('StateChange',callback); self.callbacks[#self.callbacks+1]={owner=scene,name='StateChange',callback=callback}
        if scene.GetState then local state=scene:GetState(); self.editing=state==api.constants.SCENE_SHOWING or state==api.constants.SCENE_SHOWN end
    end
end
function NativeHUD:Sync(profile)
    if self.disposed then return {} end
    local diagnostics={}; local api=self.api
    if not api.capabilities.nativeHudRegistration or not api.hudManager then
        return {{code='native_hud_unavailable',message='Штатный редактор HUD недоступен; используйте /ke.'}}
    end
    if not self.loaded then
        self.loaded=true
        for _,widget in ipairs(profile.widgets) do
            local control=api.controls.CreateControl('KanaEffectsWidget'..stable(widget.id),self.root,api.constants.CT_CONTROL)
            control:SetMouseEnabled(false); control:SetHidden(false)
            control:SetAnchor(api.constants.TOPLEFT,api.controls.GuiRoot,api.constants.TOPLEFT,0,0)
            control:SetDimensions(1,1); control.hudElementRef=control
            local record={control=control,valid=true,title=widget.name}; self.records[widget.id]=record
            self:_Refresh(widget.id)
        end
        if api.capabilities.nativeHudRebuild then api.hudManager:RebuildAllElements() end
    else
        local present={}; for _,w in ipairs(profile.widgets) do present[w.id]=true end
        local changed=false
        for id,r in pairs(self.records) do if not present[id] then r.valid=false; r.control:SetHidden(true); changed=true end end
        for id in pairs(present) do if not self.records[id] then changed=true end end
        if changed then
            diagnostics[1]={code='native_hud_reload_required',message='Состав штатного редактора HUD обновится после /reloadui. Редактор /ke работает сразу.'}
            if not self.noticed and api.LocalMessage then self.noticed=true; api.LocalMessage('KanaEffects: '..diagnostics[1].message) end
        end
    end
    return diagnostics
end
function NativeHUD:Dispose()
    if self.disposed then return end; self.disposed=true; self.editing=false
    if self.unsubscribeViews then self.unsubscribeViews() end
    for _,r in pairs(self.records) do r.valid=false; r.control:SetHidden(true) end
    for _,c in ipairs(self.callbacks) do c.owner:UnregisterCallback(c.name,c.callback) end; self.callbacks={}
    if self.api.capabilities.nativeHudRebuild then self.api.hudManager:RebuildAllElements() end
end
