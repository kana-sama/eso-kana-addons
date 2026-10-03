-- Event-driven orchestration. Every dependency is constructed by Bootstrap.
local Runtime={}; Runtime.__index=Runtime; KanaEffects.Runtime=Runtime
local function copy(value)
    if type(value)~='table' then return value end
    local result={}; for k,v in pairs(value) do result[k]=copy(v) end; return result
end
local function signature(style)
    return table.concat({style.mode,style.iconSize,style.timerFontSize,style.nameFontSize,style.rowWidth},'|')
end
local function geometry(entries)
    local parts={}; for _,e in ipairs(entries) do parts[#parts+1]=#e.key..':'..e.key..':'..tostring(e.active) end
    return table.concat(parts,'|')
end
local function delta() return {units={},unitIdentityChanged={},abilities={},artificialEffects={},families={},categories={},membershipChanged=false} end
function Runtime.New(deps)
    return setmetatable({deps=deps,dirty={},views={},measurements={},observers={},nextObserver=0,visible=true,generation=0},Runtime)
end
function Runtime:_Notify(id)
    local callbacks={}; for key,fn in pairs(self.observers) do callbacks[key]=fn end
    local generation=self.generation
    for key,fn in pairs(callbacks) do
        if self.disposed or generation~=self.generation then break end
        if self.observers[key]==fn then fn(id,self:GetView(id)) end
    end
end
function Runtime:GetView(id)
    if self.disposed then return nil end
    local view=self.views[id]; if not view then return nil end
    return copy({widget=view.widget,entries=view.entries,layout=view.layout,editorOverlay=view.editorOverlay,snapshot=view.snapshot})
end
function Runtime:SubscribeViews(callback)
    if self.disposed then return function() end end
    assert(type(callback)=='function','SubscribeViews expects callback')
    self.nextObserver=self.nextObserver+1; local id=self.nextObserver; self.observers[id]=callback
    return function() self.observers[id]=nil end
end
function Runtime:SetEditorOverlay(id,selected)
    if self.disposed then return end
    assert(selected==nil or type(selected)=='boolean','overlay expects true/false/nil')
    local view=self.views[id]; if not view then return end
    if view.editorOverlay==selected then return end
    view.editorOverlay=selected; self.deps.renderer:SetEditorOverlay(id,selected); self:_Notify(id)
end
local function displayFor(view)
    return view.snapshot and {frozenAt=view.snapshot.observedAt,snapshot=view.snapshot} or nil
end
local function overflowing(layout)
    for _,value in pairs(layout.overflow) do if value then return true end end
    return false
end
local function visibleCells(layout,widget,preview,viewport)
    local m,gap=layout.measurement,widget.layout.gap; local x,y=layout.rect.x+preview.dx,layout.rect.y+preview.dy
    -- This stamp is only a cache boundary. Layout.Place remains the authority
    -- for clipping, growth order, cell rectangles and retained assignments.
    local parts={math.floor((viewport.x-x-m.cellWidth)/(m.cellWidth+gap)),math.ceil((viewport.x+viewport.width-x)/(m.cellWidth+gap)),
        math.floor((viewport.y-y-m.cellHeight)/(m.cellHeight+gap)),math.ceil((viewport.y+viewport.height-y)/(m.cellHeight+gap))}
    if widget.type=='grid' and widget.layout.align=='center' then
        local partial=layout.logicalCount%widget.layout.count
        if partial>0 then
            local offset=(widget.layout.count-partial)/2
            -- Centered partial lines may cross a viewport edge half a cell
            -- before the full lines. Retain their clipping boundary as well.
            if widget.layout.fixedAxis=='rows' then
                local start=y+offset*(m.cellHeight+gap)
                parts[#parts+1]=math.floor((viewport.y-start-m.cellHeight)/(m.cellHeight+gap)); parts[#parts+1]=math.ceil((viewport.y+viewport.height-start)/(m.cellHeight+gap))
            else
                local start=x+offset*(m.cellWidth+gap)
                parts[#parts+1]=math.floor((viewport.x-start-m.cellWidth)/(m.cellWidth+gap)); parts[#parts+1]=math.ceil((viewport.x+viewport.width-start)/(m.cellWidth+gap))
            end
        end
    end
    return table.concat(parts,':')
end
-- A gesture changes the renderer only. GetView, projection and the Session
-- retain canonical state until the single command emitted at mouse release.
function Runtime:SetGesturePreview(preview)
    if self.disposed then return end
    local previous=self.gesturePreview; local renderer=self.deps.renderer
    if not preview then
        local temporary=self.gestureView
        self.gesturePreview=nil; self.gestureView=nil; self.gestureSource=nil; self.gestureLayout=nil; self.gestureRange=nil; self.gestureOffset=nil
        if renderer.SetGesturePreview then renderer:SetGesturePreview(nil) end
        local view=previous and temporary and self.views[previous.widgetId]
        if view then renderer:Render(view.widget,view.entries,view.layout,displayFor(view)) end
        return
    end
    if previous and (previous.widgetId~=preview.widgetId or previous.kind~=preview.kind) then self:SetGesturePreview(nil) end
    local view=self.views[preview.widgetId]; if not view then return end
    self.gesturePreview=copy(preview)
    if preview.kind=='move' and overflowing(view.layout) then
        local deps=self.deps; local viewport=deps.anchors:GetReferenceRect('screen'); local range=visibleCells(view.layout,view.widget,preview,viewport)
        if not self.gestureView or self.gestureRange~=range or self.gestureSource~=view.entries or self.gestureLayout~=view.layout then
            if renderer.SetGesturePreview then renderer:SetGesturePreview(nil) end
            local widget=copy(view.widget); widget.anchor.x=widget.anchor.x+preview.dx; widget.anchor.y=widget.anchor.y+preview.dy
            local layout=deps.layout.Place(widget,view.entries,deps.anchors:GetReferenceRect(widget.anchor.relativeTo),viewport,view.layout.measurement)
            self.gestureView={widget=widget,entries=view.entries,layout=layout,snapshot=view.snapshot,editorOverlay=view.editorOverlay}
            self.gestureRange=range; self.gestureSource=view.entries; self.gestureLayout=view.layout; self.gestureOffset={x=preview.dx,y=preview.dy}
            renderer:Render(widget,view.entries,layout,displayFor(view))
        end
        local translated={kind='move',widgetId=preview.widgetId,dx=preview.dx-self.gestureOffset.x,dy=preview.dy-self.gestureOffset.y}
        if renderer.SetGesturePreview then renderer:SetGesturePreview(translated) end
        return
    end
    if preview.kind~='resize' then
        if renderer.SetGesturePreview then renderer:SetGesturePreview(preview) end
        return
    end
    local temporary=self.gestureView
    if temporary and self.gestureSource==view.entries and self.gestureLayout==view.layout
        and temporary.widget.layout.rows==preview.rows and temporary.widget.layout.columns==preview.columns
        and (preview.patch.layout.count==nil or temporary.widget.layout.count==preview.patch.layout.count)
        and temporary.widget.anchor.x==preview.patch.anchor.x and temporary.widget.anchor.y==preview.patch.anchor.y then return temporary end
    local widget=copy(view.widget)
    for field,values in pairs(preview.patch) do for key,value in pairs(values) do widget[field][key]=value end end
    local deps=self.deps
    local layout=deps.layout.Place(widget,view.entries,deps.anchors:GetReferenceRect(widget.anchor.relativeTo),deps.anchors:GetReferenceRect('screen'),view.layout.measurement)
    temporary={widget=widget,entries=view.entries,layout=layout,snapshot=view.snapshot,editorOverlay=view.editorOverlay}
    self.gestureView=temporary; self.gestureSource=view.entries; self.gestureLayout=view.layout
    renderer:Render(widget,view.entries,layout,displayFor(view))
    return temporary
end
function Runtime:_Schedule()
    if self.disposed or self.pending or not self.started then return end
    local token={}; self.pending=token
    token.cancel=self.deps.defer(function()
        if self.disposed or self.pending~=token then return end
        self.pending=nil; self:_Flush()
    end)
end
function Runtime:_DirtyAll()
    for _,w in ipairs(self.profile.widgets) do self.dirty[w.id]=true end
    self:_Schedule()
end
function Runtime:_Change(change)
    if self.disposed then return end
    self.change=self.change or delta()
    for _,field in ipairs({'units','unitIdentityChanged','abilities','artificialEffects','families','categories'}) do
        for key,present in pairs(change[field] or {}) do if present then self.change[field][key]=true end end
    end
    self.change.membershipChanged=self.change.membershipChanged or change.membershipChanged==true
    self:_Schedule()
end
function Runtime:_Flush()
    if self.disposed then return end
    local deps=self.deps; local generation=self.generation
    local dirty=self.dirty; self.dirty={}
    if self.change then
        for id in pairs(deps.projector.AffectedWidgets(self.profile,self.compiled,self.change)) do dirty[id]=true end
        self.change=nil
    end
    local now=deps.clock:Now(); local viewport
    for _,widget in ipairs(self.profile.widgets) do
        if self.disposed or generation~=self.generation then return end
        if dirty[widget.id] then
            local provider,display,projectionTime=self.provider,nil,now
            if widget.unitTag=='reticleover' and deps.targetView and self.provider==deps.store then
                local snapshot=deps.targetView:GetSnapshot()
                if snapshot then
                    provider=deps.targetView:Provider(); projectionTime=snapshot.observedAt
                    display={frozenAt=projectionTime,snapshot=snapshot}
                end
            end
            if deps.diagnostics then deps.diagnostics:Count("widget_builds") end
            local entries=deps.projector.BuildWidget(widget,self.profile,self.compiled,provider,self.previewCatalog or deps.catalog,projectionTime)
            if display then for _,entry in ipairs(entries) do entry.snapshot={observedAt=display.snapshot.observedAt,openedAt=display.snapshot.openedAt,title=display.snapshot.title} end end
            local view=self.views[widget.id] or {}; local stamp=geometry(entries)
            local measurement=self.measurements[signature(widget.style)]
            if not measurement then
                if deps.diagnostics then deps.diagnostics:Count("measurements") end
                measurement=deps.layout.Measure(widget.style,deps.fontMetrics); self.measurements[signature(widget.style)]=measurement end
            local result=view.layout
            if not result or view.geometry~=stamp then
                if deps.diagnostics then deps.diagnostics:Count("layouts") end
                viewport=viewport or deps.anchors:GetReferenceRect('screen')
                result=deps.layout.Place(widget,entries,deps.anchors:GetReferenceRect(widget.anchor.relativeTo),viewport,measurement)
            end
            view.snapshot=display and {observedAt=display.snapshot.observedAt,openedAt=display.snapshot.openedAt,title=display.snapshot.title} or nil
            view.widget=widget; view.entries=entries; view.layout=result; view.geometry=stamp; self.views[widget.id]=view
            deps.renderer:Render(widget,entries,result,display)
            if self.gesturePreview and self.gesturePreview.widgetId==widget.id then self:SetGesturePreview(self.gesturePreview) end
            if self.disposed or generation~=self.generation then return end
            self:_Notify(widget.id)
        end
    end
end
function Runtime:_Validate(profile)
    local valid,diagnostics=self.deps.schema.Validate(profile); if not valid then return nil,nil,diagnostics end
    local compiled; compiled,diagnostics=self.deps.rules.Compile(profile.sets,profile.longThreshold,profile.widgets)
    if not compiled then return nil,nil,diagnostics end
    return self.deps.schema.CopyProfile(profile),compiled,diagnostics
end
function Runtime:_Tags()
    local tags=copy(self.deps.historyUnitTags or {})
    for _,profile in ipairs({self.applied,self.profile}) do
        for _,widget in ipairs(profile.widgets) do tags[widget.unitTag]=true end
    end
    return tags
end
function Runtime:_Use(profile,compiled,provider)
    self:SetGesturePreview(nil)
    self.generation=self.generation+1; local generation=self.generation
    if self.unsubscribeProvider then self.unsubscribeProvider(); self.unsubscribeProvider=nil end
    local keep,measurements={},{}
    for _,w in ipairs(profile.widgets) do keep[w.id]=true; measurements[signature(w.style)]=self.measurements[signature(w.style)] end
    local retired={}; for id in pairs(self.views) do if not keep[id] then retired[#retired+1]=id end end
    self.profile=profile; self.compiled=compiled; self.provider=provider
    self.measurements=measurements; self.change=nil; self.dirty={}
    for _,id in ipairs(retired) do
        self.deps.renderer:ReleaseWidget(id); self.views[id]=nil; self:_Notify(id)
        if self.disposed or self.generation~=generation then return end
    end
    for _,view in pairs(self.views) do view.geometry=nil end
    if provider~=self.deps.store and provider.Subscribe then
        self.unsubscribeProvider=provider:Subscribe(function(change) if self.generation==generation and self.provider==provider then self:_Change(change) end end)
    end
    self.deps.sources:Reconfigure(self:_Tags()); self:_DirtyAll()
end
function Runtime:Start(profile)
    if self.disposed then return false,{{code='disposed',path='',message='Runtime disposed'}} end
    if self.started then return self:ApplyConfig(profile) end
    local clean,compiled,diagnostics=self:_Validate(profile); if not clean then return false,diagnostics end
    self.started=true; self.applied=clean; self.appliedCompiled=compiled
    self.unsubscribeStore=self.deps.store:Subscribe(function(change)
        if self.provider==self.deps.store then self:_Change(change) end
    end)
    self.unsubscribeAnchors=self.deps.anchors:Observe(function()
        if self.disposed then return end
        self.measurements={}; for _,view in pairs(self.views) do view.geometry=nil end; self:_DirtyAll()
    end)
    if self.deps.targetView then self.unsubscribeTarget=self.deps.targetView:Subscribe(function()
        for _,w in ipairs(self.profile.widgets) do if w.unitTag=='reticleover' then self.dirty[w.id]=true end end; self:_Schedule()
    end) end
    local hover=self.deps.hoverCallbacks or {}
    self.deps.renderer:SetCallbacks({onEnter=hover.onEnter,onExit=hover.onExit,onCellContext=hover.onCellContext,onExpired=function(id)
        if self.disposed or not self.views[id] then return end
        self.dirty[id]=true; self:_Schedule()
    end})
    self:_Use(clean,compiled,self.deps.store); return true,diagnostics
end
function Runtime:ApplyConfig(profile)
    if not self.started then return self:Start(profile) end
    if self.disposed then return false,{{code='disposed',path='',message='Runtime disposed'}} end
    local clean,compiled,diagnostics=self:_Validate(profile); if not clean then return false,diagnostics end
    self.applied=clean; self.appliedCompiled=compiled
    if not self.preview then self:_Use(clean,compiled,self.deps.store) else self.deps.sources:Reconfigure(self:_Tags()) end
    return true,diagnostics
end
function Runtime:Preview(profile,provider,catalog)
    if self.disposed or not self.started then return false,{{code='not_running',path='',message='Runtime not running'}} end
    local clean,compiled,diagnostics=self:_Validate(profile); if not clean then return false,diagnostics end
    self.preview=true; self.previewCatalog=catalog; self:_Use(clean,compiled,provider or self.deps.store); return true,diagnostics
end
function Runtime:EndPreview()
    if self.disposed or not self.started then return end
    self:SetGesturePreview(nil)
    for id,view in pairs(self.views) do view.editorOverlay=nil; self.deps.renderer:SetEditorOverlay(id,nil) end
    self.preview=false; self.previewCatalog=nil; self:_Use(self.applied,self.appliedCompiled,self.deps.store)
end
function Runtime:SetVisible(visible)
    if self.disposed then return end
    self.visible=visible==true; self.deps.renderer:SetVisible(self.visible)
    if self.visible and self.started then self:_DirtyAll() end
end
function Runtime:IsDisplayVisible()
    return not self.disposed and self.visible and (not self.deps.renderer.IsVisible or self.deps.renderer:IsVisible())
end
function Runtime:Dispose()
    if self.disposed then return end
    self.disposed=true; self.generation=self.generation+1
    if self.pending and self.pending.cancel then self.pending.cancel() end; self.pending=nil
    for _,field in ipairs({'unsubscribeStore','unsubscribeAnchors','unsubscribeProvider','unsubscribeTarget'}) do if self[field] then self[field](); self[field]=nil end end
    self.deps.sources:Stop(); self.deps.renderer:Dispose()
    self.views={}; self.observers={}; self.dirty={}; self.change=nil; self.measurements={}
end
