-- Pointer gestures own temporary display changes, never inventory drag or draft state.
local Gestures={}; Gestures.__index=Gestures; KanaEffects.Gestures=Gestures
local P,I=KanaEffects.Picker,KanaEffects.Inspector; local serial=0
local function inside(rect,x,y) return rect and x>=rect.x and y>=rect.y and x<rect.x+rect.width and y<rect.y+rect.height end
local function finite(n) return type(n)=='number' and n==n and math.abs(n)~=math.huge end
local SNAP_ENTER,SNAP_RELEASE=10,16
local resizeDirections={left={-1,0},right={1,0},top={0,-1},bottom={0,1},topLeft={-1,-1},topRight={1,-1},bottomLeft={-1,1},bottomRight={1,1}}
local function snap(value,latched)
    local active=math.abs(value)<=(latched and SNAP_RELEASE or SNAP_ENTER)
    return active and 0 or value,active
end
function Gestures.New(session,editor,runtime,coordinates,api)
    serial=serial+1
    local self=setmetatable({session=session,editor=editor,runtime=runtime,coordinates=coordinates,api=api,name='KanaEffectsGestures'..serial},Gestures)
    if api and api.controls.CreateTopLevelWindow then
        self.tracker=api.controls.CreateTopLevelWindow(self.name); self.tracker:SetMouseEnabled(false); self.tracker:SetHidden(true)
        P.Anchor(api,self.tracker,api.controls.GuiRoot,0,0,1,1)
        self.tracker:SetHandler('OnEffectivelyHidden',function() self:Cancel() end)
    end
    self.unsubscribe=session:Subscribe(function() if self.active then self:Cancel() end end)
    return self
end
function Gestures:_Position()
    local x,y=self.coordinates.Position(); if finite(x) and finite(y) then return x,y end
end
function Gestures:_Widget(id)
    local draft=self.session:ReadDraft(); return draft and I.Find(draft.widgets,id)
end
function Gestures:_Track()
    local api=self.api
    if self.tracker then self.tracker:SetHidden(false) end
    -- A native update registration does not depend on the visibility/extent of
    -- an otherwise empty tracker window. It exists only for this gesture.
    if api and api.eventManager and api.eventManager.RegisterForUpdate then
        local generation=self.generation
        api.eventManager:RegisterForUpdate(self.name,0,function() if self.active and generation==self.generation then self:Update() end end)
    end
    if not api or not api.eventManager or not api.eventManager.RegisterForEvent then return end
    local generation=self.generation
    local function register(event,callback)
        local code=api.constants[event]; if code then api.eventManager:RegisterForEvent(self.name,code,function(...)
            if self.active and generation==self.generation then callback(...) end
        end) end
    end
    register('EVENT_GLOBAL_MOUSE_UP',function(_,button,ctrl,alt)
        -- A canceled Release consumes its mark; global delivery must retain it
        -- for the source control's subsequent mouse-up/click fallback.
        if button==1 and self:Release(alt) then self.finished=true end
    end)
    register('EVENT_GAME_FOCUS_CHANGED',function(_,focused) if not focused then self:CaptureLost() end end)
    register('EVENT_PLAYER_DEACTIVATED',function() self:CaptureLost() end)
end
function Gestures:_Stop()
    self.active=nil; self.preview=nil; self.generation=(self.generation or 0)+1
    if self.tracker then self.tracker:SetHandler('OnUpdate',nil); self.tracker:SetHidden(true) end
    if self.api and self.api.eventManager and self.api.eventManager.UnregisterForUpdate then self.api.eventManager:UnregisterForUpdate(self.name) end
    if self.api and self.api.eventManager and self.api.eventManager.UnregisterForEvent then
        for _,event in ipairs({'EVENT_GLOBAL_MOUSE_UP','EVENT_GAME_FOCUS_CHANGED','EVENT_PLAYER_DEACTIVATED'}) do
            local code=self.api.constants[event]; if code then self.api.eventManager:UnregisterForEvent(self.name,code) end
        end
    end
    self.editor:SetGesturePreview(nil)
end
function Gestures:_Begin(kind,id,row,column)
    if self.disposed or not self.editor:IsOpen() then return false end
    self:Cancel(); self.finished=nil
    local widget=self:_Widget(id); local view=self.runtime:GetView(id); local overlay=self.editor:GetOverlay(id); local x,y=self:_Position()
    if not widget or not view or not overlay or not x then return false end
    self.generation=(self.generation or 0)+1
    self.active={kind=kind,id=id,widget=P.Copy(widget),rect=P.Copy(overlay.serviceRect or overlay.rect),measurement=P.Copy(view.layout.measurement),entryCount=#view.entries,x=x,y=y,row=row,column=column}
    if kind=='move' then self.active.snapX=math.abs(widget.anchor.x)<=SNAP_ENTER; self.active.snapY=math.abs(widget.anchor.y)<=SNAP_ENTER end
    -- Draft changes cancel the gesture, so only IDs/types need retaining for
    -- hit-test ordering. Do not copy the entire profile on every pointer frame.
    self.active.targets={}
    for _,target in ipairs(self.session:ReadDraft().widgets) do self.active.targets[#self.active.targets+1]={id=target.id,type=target.type} end
    self:_Track(); return true
end
function Gestures:BeginMove(id) return self:_Begin('move',id) end
function Gestures:BeginResize(id,edge)
    local w=self:_Widget(id); if not w then return false end
    edge=edge or (w.type=='table' and 'bottomRight' or w.layout.fixedAxis=='rows' and 'bottom' or 'right')
    local direction=resizeDirections[edge]; if not direction then return false end
    if w.type=='grid' and ((w.layout.fixedAxis=='columns' and direction[2]~=0) or (w.layout.fixedAxis=='rows' and direction[1]~=0)) then return false end
    local started=self:_Begin('resize',id)
    if started then self.active.resizeX,self.active.resizeY=direction[1],direction[2] end
    return started
end
function Gestures:BeginSlot(id,row,column)
    local widget=self:_Widget(id); local view=self.runtime:GetView(id); local overlay=self.editor:GetOverlay(id); local x,y=self:_Position()
    if not widget or widget.type~='table' or not view or not x or not widget.slots[row] or not widget.slots[row][column] then return false end
    for _,p in ipairs(overlay and overlay.placements or {}) do if p.row==row and p.column==column then
        -- Icon transfer is distinct from the rest of a timer/name cell.
        local iconRect=KanaEffects.Layout.IconRect(widget.style,p.rect,view.layout.measurement)
        if inside(iconRect,x,y) then
            local ok=self:_Begin('slot',id,row,column)
            if ok then self.active.cell=P.Copy(p.rect); self.active.selector=P.Copy(widget.slots[row][column]) end
            return ok
        end
    end end
    return false
end
function Gestures:HitTest(x,y)
    local targets=self.active and self.active.targets
    if not targets then local draft=self.session:ReadDraft(); targets=draft and draft.widgets end
    if not targets then return end
    -- Reverse profile order follows native sibling creation/draw order.
    for index=#targets,1,-1 do local w=targets[index]
        local hit,placement=self.editor:HitTestPlacement(w.id,x,y)
        if hit then
            if w.type=='table' and placement then return {widgetId=w.id,row=placement.row,column=placement.column},placement.rect end
            return
        end
    end
end
function Gestures:Update()
    local a=self.active; if not a then return false end
    if self.runtime.IsDisplayVisible and not self.runtime:IsDisplayVisible() then self:CaptureLost(); return false end
    local x,y=self:_Position(); if not x then self:CaptureLost(); return false end
    local dx,dy=x-a.x,y-a.y
    if not a.dragging and dx*dx+dy*dy<16 then return false end
    if a.lastX==x and a.lastY==y then return false end
    a.lastX,a.lastY=x,y
    a.dragging=true
    local preview={kind=a.kind,widgetId=a.id,dx=dx,dy=dy,sourceRect=a.rect,row=a.row,column=a.column}
    if a.kind=='slot' then
        preview.rect={x=a.cell.x+dx,y=a.cell.y+dy,width=a.cell.width,height=a.cell.height}
        preview.sourceCell=a.cell
        preview.selector=P.Copy(a.selector); preview.target,preview.targetRect=self:HitTest(x,y)
    elseif a.kind=='move' then
        -- Pointer displacement remains relative to the original grab point;
        -- magnetic display motion must never become the next raw drag origin.
        preview.rawDx,preview.rawDy=dx,dy
        local offsetX,offsetY
        offsetX,a.snapX=snap(a.widget.anchor.x+dx,a.snapX)
        offsetY,a.snapY=snap(a.widget.anchor.y+dy,a.snapY)
        dx,dy=offsetX-a.widget.anchor.x,offsetY-a.widget.anchor.y
        preview.dx,preview.dy=dx,dy
        preview.rect={x=a.rect.x+dx,y=a.rect.y+dy,width=a.rect.width,height=a.rect.height}
        preview.patch={anchor={x=offsetX,y=offsetY}}
    else
        local w,m=a.widget,a.measurement; local gap=w.layout.gap
        local sx,sy=a.resizeX,a.resizeY
        -- Quantize displacement from the original grab point, independently of
        -- the handle's small offset from the edge and the live preview geometry.
        local columns=math.max(1,math.floor((a.rect.width+sx*dx+gap)/(m.cellWidth+gap)+0.5))
        local rows=math.max(1,math.floor((a.rect.height+sy*dy+gap)/(m.cellHeight+gap)+0.5))
        local patch={layout={}}; local count
        if w.type=='grid' then
            count=w.layout.fixedAxis=='rows' and rows or columns
            patch.layout.count=count
            if w.layout.fixedAxis=='rows' then columns=math.max(1,math.ceil(a.entryCount/rows))
            else rows=math.max(1,math.ceil(a.entryCount/columns)) end
        else patch.layout.columns=columns; patch.layout.rows=rows end
        local width=columns*m.cellWidth+(columns-1)*gap
        local height=rows*m.cellHeight+(rows-1)*gap
        local dw,dh=width-a.rect.width,height-a.rect.height
        local left=sx<0 and -dw or 0; local top=sy<0 and -dh or 0
        -- Auto-growth follows the configured anchor on the grid's other axis.
        if w.type=='grid' then
            if sx==0 then left=-w.anchor.pointX*dw end
            if sy==0 then top=-w.anchor.pointY*dh end
        end
        patch.anchor={x=w.anchor.x+left+w.anchor.pointX*dw,y=w.anchor.y+top+w.anchor.pointY*dh}
        if w.type=='grid' then
            if sx==0 then patch.anchor.x=w.anchor.x end
            if sy==0 then patch.anchor.y=w.anchor.y end
        end
        preview.columns,preview.rows,preview.count=columns,rows,count; preview.patch=patch
        preview.rect={x=a.rect.x+left,y=a.rect.y+top,width=width,height=height}
        if self.preview and self.preview.columns==columns and self.preview.rows==rows and self.preview.count==count then return false end
    end
    self.preview=preview; self.editor:SetGesturePreview(preview); return true
end
function Gestures:GetPreview() return self.preview and P.Copy(self.preview) or nil end
function Gestures:Release(copy)
    local a=self.active; if not a then local result=self.finished==true; self.finished=nil; return result end
    self:Update(); a=self.active; if not a then local result=self.finished==true; self.finished=nil; return result end
    local dragged=a.dragging==true; local preview=self.preview
    self:_Stop(); self.finished=dragged
    if dragged and preview then
        if a.kind=='slot' then
            if preview.target then self.editor:Apply({type='slot.transfer',from={widgetId=a.id,row=a.row,column=a.column},to=preview.target,copy=copy==true}) end
        else self.editor:PatchWidget(a.id,preview.patch) end
    end
    return dragged
end
function Gestures:Cancel()
    if not self.active then return false end; self:_Stop(); self.finished=true; return true
end
function Gestures:CaptureLost() return self:Cancel() end
function Gestures:Handlers()
    local function down(kind,id,control,button)
        self.finished=nil
        if button~=1 then return false end
        if kind=='resize' then return self:BeginResize(id) end
        self:BeginMove(id); return false
    end
    local function up(id,control,button,inside,ctrl,alt) return button==1 and self:Release(alt) or false end
    return {
        onCellMouseDown=function(id,row,column,control,button) self.finished=nil; if button==1 then self:BeginSlot(id,row,column) end; return false end,
        onCellMouseUp=function(id,row,column,control,button,inside,ctrl,alt) return button==1 and self:Release(alt) or false end,
        onAnchorMouseDown=function(...) return down('move',...) end,onAnchorMouseUp=up,
        onFrameMouseDown=function(...) return down('move',...) end,onFrameMouseUp=up,
        onResizeMouseDown=function(id,control,button,ctrl,alt,shift,command,edge) self.finished=nil; return button==1 and self:BeginResize(id,edge) or false end,onResizeMouseUp=up,
    }
end
function Gestures:Dispose()
    if self.disposed then return end; self:Cancel(); self.disposed=true; self.finished=nil; self.unsubscribe()
    if self.tracker then self.tracker:SetHandler('OnEffectivelyHidden',nil); self.tracker:SetHandler('OnUpdate',nil); self.tracker:SetHidden(true) end
end
