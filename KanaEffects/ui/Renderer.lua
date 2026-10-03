-- Pooled native cells. Layout is authoritative; editor chrome never alters it.
local Renderer = {}
KanaEffects.Renderer = Renderer
local COLORS = {minor={145/255,210/255,235/255,1}, major={244/255,211/255,137/255,1}, timer={1,1,1,1}, ordinary={227/255,235/255,233/255,1}}
local EDGE = 'EsoUI/Art/Miscellaneous/borderedInsetTransparent_white_edgeFile.dds'
local function hasTimer(state) return state and state.kind=='finite' end
local function key(widget, entry, line) return #widget..':'..widget..#entry..':'..entry..':'..line end
local function text(label, value, diagnostics)
    if label._kanaText ~= value then
        if diagnostics then diagnostics:Count("text_writes"); if label._kanaTimer then diagnostics:Count("timer_text_writes") end end
        label:SetText(value); label._kanaText=value
    end
end
local function signature(style,m,rect,pair)
    return table.concat({style.mode,style.timerFontSize,style.nameFontSize,m.iconWidth,m.timerColumnWidth,m.timerLineHeight,
        m.contentGap,m.rightInset or 0,m.nameColumnWidth,m.nameLineHeight,rect.x,rect.y,rect.width,rect.height,tostring(pair)},'|')
end
function Renderer.New(parent, controls, scheduler, diagnostics)
    local self=setmetatable({diagnostics=diagnostics,controls=controls,scheduler=scheduler,widgets={},free={},freeOutlines={},freeMarkers={},visible=true,sceneVisible=true,callbacks={}}, {__index=Renderer})
    self.content=controls:Create('control',parent); self.content:SetHidden(false)
    self.chrome=controls:Create('control',self.content); self.chrome:SetHidden(false)
    if diagnostics then diagnostics:Count('controls_created',2) end
    self.unsubscribeVisibility=controls:ObserveVisibility(self.content,function(visible)
        self.sceneVisible=visible; if not visible then self:_ExitHovers() end; scheduler:SetVisible(self.visible and visible)
    end)
    self.tick=function(now) scheduler:Advance(now) end
    self.unsubscribeActivity=scheduler:SubscribeActivity(function(active) controls:SetTimerDriver(active and self.tick or nil) end)
    return self
end
function Renderer:_Acquire()
    local cell=table.remove(self.free)
    if cell then return cell end
    if self.diagnostics then self.diagnostics:Count('controls_created',5); self.diagnostics:Count('cells_created') end
    local controls=self.controls; cell={root=controls:Create('control',self.content), timers={}}
    cell.background=controls:Create('backdrop',cell.root)
    cell.icon=controls:Create('texture',cell.root)
    cell.debuff=controls:Create('backdrop',cell.root); controls:SetDrawOrder(cell.debuff,'border')
    cell.debuff:SetEdgeTexture(EDGE,128,16,2,0); cell.debuff:SetInsets(2,2,-2,-2)
    cell.debuff:SetCenterColor(0,0,0,0); cell.debuff:SetEdgeColor(0.85,0.55,0.49,1)
    local timer=controls:Create('label',cell.root); cell.timers[1]=timer
    timer._kanaTimer=true
    timer:SetVerticalAlignment(controls.api.constants.TEXT_ALIGN_CENTER)
    cell.jobs={}; return cell
end
function Renderer:_Release(cell)
    self:_ExitHover(cell)
    self:_PreviewOrder(cell,false)
    cell.currentEntry=nil; cell.currentWidget=nil; cell.handlersBound=false; cell.hoverToken=nil
    for _,job in pairs(cell.jobs) do self.scheduler:Unwatch(job.key) end
    cell.jobs={}; cell.geometry=nil; cell.timerGeometry=nil; cell.root._kanaTooltipSide=nil
    local all={cell.root,cell.background,cell.icon,cell.debuff,cell.timers[1]}
    if cell.name then all[#all+1]=cell.name end
    if cell.badge then all[#all+1]=cell.badge end
    for _,c in ipairs(all) do self.controls:Reset(c); c._kanaText=nil; c._kanaDrawX=nil; c._kanaDrawY=nil end
    cell.icon:SetTexture(''); cell.icon:SetTextureCoords(0,1,0,1); cell.icon:SetColor(1,1,1,1); cell.icon:SetDesaturation(0)
    for _,label in ipairs(cell.timers) do text(label,'',self.diagnostics); label:SetColor(unpack(COLORS.timer)) end
    if cell.name then text(cell.name,'',self.diagnostics) end
    if cell.badge then text(cell.badge,'',self.diagnostics); cell.badge._kanaGeometry=nil end
    self.free[#self.free+1]=cell
end
function Renderer:_Geometry(cell,widget,entry,rect,m)
    local hash=signature(widget.style,m,rect,entry.pair)
    if cell.geometry==hash then return end
    cell.geometry=hash; cell.timerGeometry=nil
    local controls=self.controls; local mode=widget.style.mode; local icon=m.iconWidth
    cell.root._kanaTooltipSide=(mode=='list' or mode=='right') and 'left' or nil
    controls:Rect(cell.root,rect)
    cell.root._kanaDrawX,cell.root._kanaDrawY=rect.x,rect.y
    local iconRect=KanaEffects.Layout.IconRect(widget.style,rect,m)
    local ix,iy=iconRect.x-rect.x,iconRect.y-rect.y
    cell.iconRect={x=ix,y=iy,width=icon,height=icon}
    controls:Rect(cell.icon,cell.iconRect,cell.root)
    controls:Rect(cell.debuff,{x=ix,y=iy,width=icon,height=icon},cell.root)
    controls:Rect(cell.background,{x=0,y=0,width=rect.width,height=rect.height},cell.root)
    cell.background:SetCenterColor(0.04,0.08,0.1,0.46); cell.background:SetEdgeColor(0,0,0,0)
    for _,label in ipairs(cell.timers) do
        label:SetFont(controls:FontDescriptor(widget.style.timerFontSize,'timer'))
        label:SetHorizontalAlignment(controls.api.constants[(mode=='over' or mode=='under') and 'TEXT_ALIGN_CENTER' or 'TEXT_ALIGN_RIGHT'])
    end
    if mode=='list' then
        if not cell.name then if self.diagnostics then self.diagnostics:Count('controls_created') end; cell.name=controls:Create('label',cell.root) end
        controls:Rect(cell.name,{x=icon+m.contentGap,y=(rect.height-m.nameLineHeight)/2,width=m.nameColumnWidth,height=m.nameLineHeight},cell.root)
        cell.name:SetFont(controls:FontDescriptor(widget.style.nameFontSize,'name')); cell.name:SetWrapMode(controls.api.constants.TEXT_WRAP_MODE_ELLIPSIS)
        cell.name:SetMaxLineCount(1); cell.name:SetHorizontalAlignment(controls.api.constants.TEXT_ALIGN_LEFT); cell.name:SetColor(unpack(COLORS.ordinary))
    end
end
-- One timer uses fixed geometry for every pair state. Only a style/layout
-- change invalidates these anchors; countdown and presence changes do not.
function Renderer:_TimerGeometry(cell,widget,rect,m)
    if cell.timerGeometry then return end
    cell.timerGeometry=true
    local mode=widget.style.mode; local icon=m.iconWidth
    local x,y=icon+m.contentGap,(rect.height-m.timerLineHeight)/2
    if mode=='over' then x=(rect.width-m.timerColumnWidth)/2
    elseif mode=='under' then x,y=(rect.width-m.timerColumnWidth)/2,icon+m.contentGap
    elseif mode=='list' then x=rect.width-m.timerColumnWidth-(m.rightInset or 0) end
    self.controls:Rect(cell.timers[1],{x=x,y=y,width=m.timerColumnWidth,height=m.timerLineHeight},cell.root)
end
function Renderer:_ExitHover(cell)
    if not cell.hovered then return end
    cell.hovered=false
    if not self.disposed and self.callbacks.onExit then self.callbacks.onExit(cell.currentWidget,cell.currentEntry,cell.root) end
end
function Renderer:_ExitHovers()
    for _,state in pairs(self.widgets) do for _,cell in pairs(state.cells) do self:_ExitHover(cell) end end
end
function Renderer:_Hover(cell,widgetId,entry)
    local previous=cell.currentEntry
    cell.currentWidget=widgetId; cell.currentEntry=entry; cell.root:SetMouseEnabled(true)
    if cell.hovered and previous~=entry and self.callbacks.onEnter then self.callbacks.onEnter(widgetId,entry,cell.root,cell.icon) end
    if cell.handlersBound then return end
    cell.handlersBound=true; local token={}; cell.hoverToken=token
    cell.root:SetHandler('OnMouseEnter',function(control)
        if not self.disposed and cell.currentEntry and cell.hoverToken==token then
            cell.hovered=true
            if self.callbacks.onEnter then self.callbacks.onEnter(cell.currentWidget,cell.currentEntry,control,cell.icon) end
        end
    end)
    cell.root:SetHandler('OnMouseExit',function() if cell.hoverToken==token then self:_ExitHover(cell) end end)
    cell.root:SetHandler('OnMouseUp',function(control,button,inside)
        if button~=self.controls.api.constants.MOUSE_BUTTON_INDEX_RIGHT or not inside or not self:IsVisible() or
            cell.hoverToken~=token or not cell.currentEntry or control:IsControlHidden() then return end
        if self.callbacks.onCellContext then
            self:_ExitHover(cell)
            if self:IsVisible() and cell.hoverToken==token and cell.currentEntry and self.callbacks.onCellContext then
                self.callbacks.onCellContext(cell.currentWidget,cell.currentEntry,control)
            end
        end
    end)
end
function Renderer:_Badge(cell,widget,entry,m)
    local show=entry.selector and entry.selector.kind=='category' and entry.count>1
    if show then
        if not cell.badge then
            if self.diagnostics then self.diagnostics:Count('controls_created') end
            cell.badge=self.controls:Create('label',cell.root)
            cell.badge:SetHorizontalAlignment(self.controls.api.constants.TEXT_ALIGN_LEFT)
            cell.badge:SetVerticalAlignment(self.controls.api.constants.TEXT_ALIGN_CENTER); cell.badge:SetColor(unpack(COLORS.ordinary))
        end
        local icon=cell.iconRect
        local geometry=table.concat({icon.x,icon.y,icon.width,m.timerLineHeight,widget.style.timerFontSize},'|')
        if cell.badge._kanaGeometry~=geometry then
            cell.badge._kanaGeometry=geometry
            self.controls:Rect(cell.badge,{x=icon.x,y=icon.y,width=icon.width,height=math.min(m.timerLineHeight,icon.height/2)},cell.root)
            cell.badge:SetFont(self.controls:FontDescriptor(math.min(widget.style.timerFontSize,icon.height/3),'timer'))
        end
        text(cell.badge,tostring(entry.count),self.diagnostics); cell.badge:SetHidden(false)
    elseif cell.badge then cell.badge:SetHidden(true) end
end
function Renderer:_BindTimer(cell,widget,entry,index,state,level,frozenAt)
    local label=cell.timers[index]; local job=cell.jobs[index]
    label:SetHidden(not hasTimer(state))
    label:SetColor(unpack(COLORS[level] or COLORS.timer)); label:SetAlpha(1)
    if not hasTimer(state) then
        if job then self.scheduler:Unwatch(job.key); cell.jobs[index]=nil end
        text(label,'',self.diagnostics)
        return
    end
    if frozenAt then
        if job then self.scheduler:Unwatch(job.key); cell.jobs[index]=nil end
        text(label,(KanaEffects.Timers.Format(state,frozenAt)),self.diagnostics); return
    end
    if job and job.kind==state.kind and job.endTime==state.endTime then return end
    local watchKey=key(widget.id,entry.key,index)
    job={key=watchKey,kind=state.kind,endTime=state.endTime}; cell.jobs[index]=job
    if self.diagnostics then self.diagnostics:Count('timer_watches'); if state.kind=='finite' then self.diagnostics:Count('timer_jobs_created') end end
    self.scheduler:Watch(watchKey,state,function(value)
        if not self.disposed and cell.jobs[index]==job then text(label,value,self.diagnostics) end
    end,function()
        if not self.disposed and cell.jobs[index]==job and self.callbacks.onExpired then self.callbacks.onExpired(widget.id,entry.key) end
    end)
end
function Renderer:Render(widget,entries,layout,display)
    local frozenAt=display and display.frozenAt
    if self.disposed then return end
    local state=self.widgets[widget.id]
    if not state then state={cells={},outlines={},editor=false}; self.widgets[widget.id]=state end
    state.widget=widget; state.layout=layout
    local byKey={}; for _,entry in ipairs(entries) do byKey[entry.key]=entry end
    local visibleBounds
    for _,placement in ipairs(layout.placements) do
        local entry=byKey[placement.key]
        if placement.visible and entry and entry.active then
            local rect=placement.rect
            if not visibleBounds then visibleBounds={left=rect.x,top=rect.y,right=rect.x+rect.width,bottom=rect.y+rect.height}
            else
                visibleBounds.left=math.min(visibleBounds.left,rect.x); visibleBounds.top=math.min(visibleBounds.top,rect.y)
                visibleBounds.right=math.max(visibleBounds.right,rect.x+rect.width); visibleBounds.bottom=math.max(visibleBounds.bottom,rect.y+rect.height)
            end
        end
    end
    if display and display.snapshot and visibleBounds then
        if not state.snapshotLabel then state.snapshotLabel=table.remove(self.freeMarkers); if not state.snapshotLabel then state.snapshotLabel=self.controls:Create('label',self.content); if self.diagnostics then self.diagnostics:Count('controls_created') end end end
        local label=state.snapshotLabel
        label:SetFont(self.controls:FontDescriptor(widget.style.nameFontSize,'name')); label:SetColor(unpack(COLORS.ordinary))
        label:SetWrapMode(self.controls.api.constants.TEXT_WRAP_MODE_ELLIPSIS); label:SetMaxLineCount(1)
        label:SetHorizontalAlignment(self.controls.api.constants.TEXT_ALIGN_CENTER)
        local height=layout.measurement.snapshotLineHeight or layout.measurement.nameLineHeight
        local visibleWidth=visibleBounds.right-visibleBounds.left
        local width=math.min(360,math.max(visibleWidth,240))
        local x,y=visibleBounds.left+(visibleWidth-width)/2,visibleBounds.top-height
        local viewport=layout.viewport
        if viewport then
            width=math.min(width,viewport.width)
            local center=visibleBounds.left+visibleWidth/2
            local right=viewport.x+viewport.width
            if center>viewport.x and center<right then
                -- Keep the name over the effects even near a screen edge;
                -- native ellipsis absorbs the narrower symmetric space.
                width=math.min(width,2*math.min(center-viewport.x,right-center))
                x=center-width/2
            else
                x=math.max(viewport.x,math.min(center-width/2,right-width))
            end
            y=math.max(viewport.y,math.min(y,viewport.y+viewport.height-height))
        end
        state.snapshotRect={x=x,y=y,width=width,height=height}
        self.controls:Rect(label,state.snapshotRect)
        label._kanaDrawX,label._kanaDrawY=x,y
        text(label,display.snapshot.title,self.diagnostics); label:SetHidden(false)
    elseif state.snapshotLabel then state.snapshotLabel:SetHidden(true) end
    local keep={}
    for _,placement in ipairs(layout.placements) do
        local entry=byKey[placement.key]
        if entry and placement.visible then
            keep[entry.key]=true
            local cell=state.cells[entry.key]; if not cell then cell=self:_Acquire(); state.cells[entry.key]=cell end
            self:_Geometry(cell,widget,entry,placement.rect,layout.measurement)
            self:_Hover(cell,widget.id,entry); self:_Badge(cell,widget,entry,layout.measurement)
            cell.root:SetHidden(false); cell.root:SetAlpha(entry.active and 1 or widget.layout.ghostAlpha)
            cell.icon:SetHidden(false); cell.icon:SetTexture(entry.icon); cell.icon:SetColor(1,1,1,1); cell.icon:SetDesaturation(entry.active and 0 or 1)
            cell.debuff:SetHidden(entry.kind~='debuff')
            local timer,level=KanaEffects.Timers.Select(entry)
            self:_TimerGeometry(cell,widget,placement.rect,layout.measurement)
            cell.background:SetHidden(widget.style.mode~='right' and widget.style.mode~='list')
            if cell.name then cell.name:SetHidden(widget.style.mode~='list'); if widget.style.mode=='list' then text(cell.name,entry.name,self.diagnostics) end end
            self:_BindTimer(cell,widget,entry,1,timer,level,frozenAt)
        end
    end
    for entryKey,cell in pairs(state.cells) do if not keep[entryKey] then self:_Release(cell); state.cells[entryKey]=nil end end
    self:_Chrome(state)
    if self.gesturePreview and self.gesturePreview.widgetId==widget.id then self:_PreviewPositions(state,self.gesturePreview) end
end
-- Only native root anchors change during move/slot preview. All labels and
-- icons remain pooled children, so there is no projection or per-frame rebuild.
function Renderer:_PreviewPosition(control,x,y)
    if control._kanaDrawX==x and control._kanaDrawY==y then return end
    local api=self.controls.api
    control:ClearAnchors(); control:SetAnchor(api.constants.TOPLEFT,api.controls.GuiRoot,api.constants.TOPLEFT,x,y)
    control._kanaDrawX,control._kanaDrawY=x,y
end
function Renderer:_PreviewOrder(cell,raised)
    if not raised then
        if cell.previewOrder then
            for control in pairs(cell.previewOrder) do self.controls:SetDrawOrder(control) end
            cell.previewOrder=nil
        end
        return
    end
    local tiers=cell.previewOrder or {}; cell.previewOrder=tiers
    local all={cell.root,cell.background,cell.icon,cell.debuff,cell.timers[1]}
    if cell.name then all[#all+1]=cell.name end
    if cell.badge then all[#all+1]=cell.badge end
    for _,control in ipairs(all) do
        if tiers[control]==nil then
            tiers[control]=true
            -- Promotion uses a separate negative band in the same background
            -- layer, so even the top dragged border stays below stock HUD.
            self.controls:SetDrawOrder(control,nil,true)
        end
    end
end
function Renderer:_PreviewPositions(state,preview)
    local move=preview and preview.kind=='move'
    local dx,dy=preview and preview.dx or 0,preview and preview.dy or 0
    for i,placement in ipairs(state.layout.placements) do
        local cell=state.cells[placement.key]; local rect=placement.rect
        local selected=preview and preview.kind=='slot' and placement.row==preview.row and placement.column==preview.column
        local offset=move or selected
        if cell then
            self:_PreviewOrder(cell,selected)
            self:_PreviewPosition(cell.root,rect.x+(offset and dx or 0),rect.y+(offset and dy or 0))
        end
        if state.outlines[i] then self:_PreviewPosition(state.outlines[i],rect.x+(move and dx or 0),rect.y+(move and dy or 0)) end
    end
    if state.snapshotLabel then
        local rect=state.snapshotRect
        self:_PreviewPosition(state.snapshotLabel,rect.x+(move and dx or 0),rect.y+(move and dy or 0))
    end
end
function Renderer:SetGesturePreview(preview)
    if self.disposed then return end
    local previous=self.gesturePreview
    if previous and (not preview or previous.widgetId~=preview.widgetId) then
        local state=self.widgets[previous.widgetId]; if state then self:_PreviewPositions(state,nil) end
    end
    self.gesturePreview=preview
    local state=preview and self.widgets[preview.widgetId]
    if state then self:_PreviewPositions(state,preview) end
end
function Renderer:_Chrome(state)
    local used=0
    if state.editor then
        for _,placement in ipairs(state.layout.placements) do
            used=used+1; local outline=state.outlines[used]
            if not outline then
                outline=table.remove(self.freeOutlines); if not outline then outline=self.controls:Create('backdrop',self.chrome); if self.diagnostics then self.diagnostics:Count('controls_created') end end; state.outlines[used]=outline
                self.controls:SetDrawOrder(outline,'border')
                outline:SetEdgeTexture(EDGE,128,16,1,0); outline:SetInsets(1,1,-1,-1); outline:SetCenterColor(0,0,0,0)
            end
            outline:SetEdgeColor(0.57,0.82,0.75,state.selected and 0.85 or 0.35)
            local rect=placement.rect; local geometry=table.concat({rect.x,rect.y,rect.width,rect.height},'|')
            if outline._kanaGeometry~=geometry then
                self.controls:Rect(outline,rect); outline._kanaGeometry=geometry; outline._kanaDrawX,outline._kanaDrawY=rect.x,rect.y
            end
            outline:SetHidden(false)
        end
    end
    for i=used+1,#state.outlines do state.outlines[i]:SetHidden(true) end
end
function Renderer:SetEditorOverlay(widgetId,selected)
    if self.disposed then return end
    local state=self.widgets[widgetId]; if state then state.editor=selected~=nil; state.selected=selected==true; self:_Chrome(state) end
end
function Renderer:SetCallbacks(callbacks) if not self.disposed then self.callbacks=callbacks or {} end end
function Renderer:IsVisible() return not self.disposed and self.visible and self.sceneVisible end
function Renderer:SetVisible(visible)
    if self.disposed then return end
    self.visible=visible==true; if not self.visible then self:_ExitHovers() end; self.content:SetHidden(not self.visible); self.scheduler:SetVisible(self.visible and self.sceneVisible)
end
function Renderer:ReleaseWidget(widgetId)
    local state=self.widgets[widgetId]; if not state then return end
    for _,cell in pairs(state.cells) do self:_Release(cell) end
    for _,outline in ipairs(state.outlines) do
        self.controls:Reset(outline); outline._kanaGeometry=nil; self.freeOutlines[#self.freeOutlines+1]=outline
    end
    if state.snapshotLabel then self.controls:Reset(state.snapshotLabel); state.snapshotLabel._kanaText=nil; self.freeMarkers[#self.freeMarkers+1]=state.snapshotLabel end
    self.widgets[widgetId]=nil
end
function Renderer:Dispose()
    if self.disposed then return end
    self.disposed=true; self.callbacks={}
    for widgetId in pairs(self.widgets) do self:ReleaseWidget(widgetId) end
    self.unsubscribeActivity(); self.unsubscribeVisibility(); self.controls:SetTimerDriver(nil)
    self.controls:Dispose(); self.free={}; self.freeOutlines={}
end
