-- Configuration transaction controller and native floating toolbar/canvas chrome.
local Editor={}; Editor.__index=Editor; KanaEffects.Editor=Editor
local P=KanaEffects.Picker; local I=KanaEffects.Inspector; local serial=0
function Editor.New(session,runtime,picker,anchors,deps)
    serial=serial+1; deps=deps or {}
    local self=setmetatable({session=session,runtime=runtime,picker=picker,anchors=anchors,api=deps.api,contextItems=deps.contextItems,catalog=deps.catalog,store=deps.store,clock=deps.clock,hiddenList=deps.hiddenList,nativeHud=deps.nativeHud,name='KanaEffectsEditor'..serial,overlays={},nativeOverlays={},generation=0,labels=I.Labels(deps.api)},Editor)
    self.inspector=I.New(self,session,anchors,deps.api); self.setEditor=KanaEffects.SetEditor.New(self,session,picker,deps.catalog,deps.store,deps.api)
    self.unsubscribe=session:Subscribe(function(draft)
        if not self.open or self.closing then return end
        if not draft then self:_Finish(); return end
        local ok,diag=self.runtime:Preview(draft,self.provider or self.store)
        if not ok then self:Report(false,diag); return end
        self.inspector:RebaseReferences(draft); if self.setEditor.RebaseReferences then self.setEditor:RebaseReferences(draft) end
        self:_Chrome(draft); self.inspector:Refresh(); self.setEditor:Refresh(); self:_Toolbar(draft)
    end)
    self.unsubscribeViews=runtime:SubscribeViews(function(id,view)
        if self.open then self:_View(id,view) end
    end)
    self.unsubscribeAnchors=anchors:Observe(function()
        if self.open then self:_Toolbar(self.session:ReadDraft()); if self.inspector.form then self.inspector.form:Place() end; if self.setEditor.form then self.setEditor.form:Place() end; if self.setEditor.help and self.setEditor.help.form then self.setEditor.help.form:Place() end end
    end)
    local scene=deps.api and deps.api.hudEditorScene
    if scene and scene.RegisterCallback then
        self.sceneCallback=function(_,newState) if newState==deps.api.constants.SCENE_SHOWING and self.open then self.cursorOwned=nil; self:Cancel() end end
        scene:RegisterCallback('StateChange',self.sceneCallback)
    end
    return self
end
function Editor:IsOpen() return self.open==true end
function Editor:Report(ok,diagnostics)
    if ok then self.message=nil else
        local messages={}; for _,diag in ipairs(diagnostics or {}) do
            local text=self.labels.errors[diag.code] or diag.message or self.labels.invalidConfig
            if diag.code=='set_in_use' then
                -- Names/IDs originate in the current draft; no diagnostic string parsing.
                local refs={}; local p=self.session:ReadDraft(); local id=self.setEditor and self.setEditor.selected
                for _,list in ipairs({p and p.widgets or {},p and p.sets or {}}) do for _,v in ipairs(list) do for _,field in ipairs({'includeSets','excludeSets'}) do
                    if I.Contains((v.rules or v)[field],id) then refs[#refs+1]=v.name end
                end end end
                if #refs>0 then text=text..' '..table.concat(refs,', ') end
            end
            messages[#messages+1]=text
        end
        self.message=#messages>0 and table.concat(messages,'\n') or self.labels.invalidConfig
    end
    if self.toolbar and self.open then local draft=self.session:ReadDraft(); if draft then self:_Toolbar(draft) end end
    if self.inspector.form then self.inspector.form:Message(self.message) end
    if self.setEditor.form then self.setEditor.form:Message(self.message) end
    return ok,diagnostics
end
function Editor:Apply(command)
    if not self:IsOpen() or self.disposed then return false,{} end
    local ok,diag=self.session:Apply(command); return self:Report(ok,diag)
end
function Editor:PatchWidget(id,patch) return self:Apply({type='widget.patch',widgetId=id,patch=patch}) end
function Editor:_NewId(prefix,list)
    local n=1; while I.Find(list,prefix..n) do n=n+1 end; return prefix..n
end
function Editor:AddWidget(kind)
    local p=self.session:ReadDraft(); if not p then return false end
    local id=self:_NewId('widget-',p.widgets)
    local w={id=id,name=self.labels.newWidget,type=kind or 'table',unitTag='player',
        layout={columns=6,rows=3,fixedAxis='columns',align=kind=='grid' and 'start' or nil,count=6,gap=4,absent='ghost',ghostAlpha=0.3},
        anchor={pointX=0.5,pointY=0.5,relativeTo='screen',relativePointX=0.5,relativePointY=0.5,x=0,y=0},
        style={mode='over',iconSize=48,timerFontSize=16,nameFontSize=16,rowWidth=240},slots={},rules={includeSets={},excludeSets={},named='any',mergePairs=true}}
    local ok,diag=self:Apply({type='widget.add',widget=w}); if ok then self:Select(id) end; return ok,diag
end
function Editor:DuplicateWidget(id)
    local p=self.session:ReadDraft(); if not p then return false end; local newId=self:_NewId('widget-',p.widgets)
    local ok,diag=self:Apply({type='widget.duplicate',widgetId=id,newId=newId}); if ok then self:Select(newId) end; return ok,diag
end
function Editor:DeleteWidget(id)
    local ok,diag=self:Apply({type='widget.delete',widgetId=id})
    if ok and self.selected==id then self.selected=nil; self.inspector:Close() end; return ok,diag
end
function Editor:_Chrome(draft)
    local alive={}; for _,w in ipairs(draft.widgets) do alive[w.id]=true; self.runtime:SetEditorOverlay(w.id,w.id==self.selected); local v=self.runtime:GetView(w.id); if v then self:_View(w.id,v) end end
    for id in pairs(self.overlays) do if not alive[id] then self:_View(id,nil) end end
end
function Editor:GetOverlay(id) return self.overlays[id] and P.Copy(self.overlays[id]) or nil end
function Editor:HitTestPlacement(id,x,y)
    local overlay=self.overlays[id]; if not overlay then return false end
    local function inside(r) return r and x>=r.x and y>=r.y and x<r.x+r.width and y<r.y+r.height end
    if inside(overlay.serviceRect) then return true end
    for _,placement in ipairs(overlay.placements) do if inside(placement.rect) then return true,P.Copy(placement) end end
    return false
end
function Editor:_View(id,view)
    if not view then self.overlays[id]=nil; local n=self.nativeOverlays[id]; if n then n.binding=(n.binding or 0)+1; n.root:SetHidden(true) end; return end
    if not view.layout then return end
    local gesture=self.gesturePreview
    if gesture and gesture.widgetId==id and gesture.kind=='resize' then view=self.runtime:SetGesturePreview(gesture) or view end
    local selected=id==self.selected
    if view.editorOverlay~=selected then self.runtime:SetEditorOverlay(id,selected); return end
    local l=view.layout; local overlay={widgetId=id,rect=P.Copy(l.rect),placements=P.Copy(l.placements),empty=view.widget.type=='grid' and #view.entries==0,overflow=P.Copy(l.overflow)}
    if overlay.empty then
        -- Empty grids expose their configured capacity without manufacturing
        -- entries. The configured anchor remains the runtime zero-content point.
        local w,m=view.widget,l.measurement; local columns=w.layout.fixedAxis=='columns' and w.layout.count or 1; local rows=w.layout.fixedAxis=='rows' and w.layout.count or 1
        local width=columns*m.cellWidth+(columns-1)*w.layout.gap; local height=rows*m.cellHeight+(rows-1)*w.layout.gap
        overlay.serviceRect={x=l.rect.x-w.anchor.pointX*width,y=l.rect.y-w.anchor.pointY*height,width=width,height=height}
    end
    self.overlays[id]=overlay
    if self.api and self.api.controls.CreateControlFromVirtual then
        self:_NativeView(id,view,overlay)
        if gesture and gesture.widgetId==id and gesture.kind=='move' then P.Anchor(self.api,self.nativeOverlays[id].root,self.api.controls.GuiRoot,gesture.dx,gesture.dy,1,1) end
    end
end
local resizePoints={{'left',0,0.5},{'right',1,0.5},{'top',0.5,0},{'bottom',0.5,1},{'topLeft',0,0},{'topRight',1,0},{'bottomLeft',0,1},{'bottomRight',1,1}}
local function chromeBlock(api,parent,name)
    local c=api.controls.CreateControl(name,parent,api.constants.CT_BACKDROP)
    local color=P.NativeColors(api).selected
    c:SetCenterColor(color[1],color[2],color[3],0.9); c:SetEdgeColor(color[1],color[2],color[3],0.9); c:SetDrawLayer(api.constants.DL_OVERLAY); c:SetMouseEnabled(false)
    return c
end
function Editor:_ResizeHandleBounds(id,n,rect)
    local api=self.api; local vw,vh=api.controls.GuiRoot:GetDimensions()
    local preview=self.gesturePreview; local moving=preview and preview.widgetId==id and preview.kind=='move'
    local vx,vy=moving and -preview.dx or 0,moving and -preview.dy or 0
    local boxes={}
    for _,point in ipairs(resizePoints) do if n.resizeVisible[point[1]] then
        local hx,hy=rect.x+point[2]*rect.width-4,rect.y+point[3]*rect.height-4
        P.Anchor(api,n.resizeHandles[point[1]],n.root,hx,hy,8,8)
        boxes[#boxes+1]={x=hx,y=hy}
    end end
    local ax,ay=n.anchorX,n.anchorY
    local function overlaps(x,y)
        for _,b in ipairs(boxes) do if x-10<b.x+8 and x+10>b.x and y-10<b.y+8 and y+10>b.y then return true end end
        return false
    end
    if overlaps(ax,ay) then
        local dx=ax<=rect.x+rect.width/2 and -24 or 24
        local dy=ay<=rect.y+rect.height/2 and -24 or 24
        local left,right=math.min(ax-24,rect.x-18),math.max(ax+24,rect.x+rect.width+18)
        local top,bottom=math.min(ay-24,rect.y-18),math.max(ay+24,rect.y+rect.height+18)
        local candidates={{dx<0 and left or right,ay},{ax,dy<0 and top or bottom},{dx<0 and right or left,ay},{ax,dy<0 and bottom or top}}
        local chosen
        for _,p in ipairs(candidates) do
            p[1]=math.max(vx+10,math.min(p[1],vx+vw-10)); p[2]=math.max(vy+10,math.min(p[2],vy+vh-10))
            if p[1]-10>=vx and p[1]+10<=vx+vw and p[2]-10>=vy and p[2]+10<=vy+vh and not overlaps(p[1],p[2]) then chosen=p; break end
        end
        -- Offscreen panels retain their true position; only the anchor grip moves.
        chosen=chosen or candidates[1]; ax,ay=chosen[1],chosen[2]
    end
    P.Anchor(api,n.anchorHandle,n.root,ax-10,ay-10,20,20)
end
function Editor:_DashedBounds(id,n,rect)
    local api=self.api; local vw,vh=api.controls.GuiRoot:GetDimensions(); local used=0
    local preview=self.gesturePreview; local moving=preview and preview.widgetId==id and preview.kind=='move'
    local vx,vy=moving and -preview.dx or 0,moving and -preview.dy or 0
    local function dash(x,y,w,h)
        used=used+1; local c=n.dashes[used]
        if not c then c=chromeBlock(api,n.root,self.name..'Dash'..id..used); n.dashes[used]=c end
        P.Anchor(api,c,n.root,x,y,w,h); c:SetHidden(false)
    end
    -- Clip only the generated strokes, never the widget's true bounds. This
    -- keeps huge or off-screen widgets bounded by the visible viewport.
    for _,y in ipairs({rect.y,rect.y+rect.height-1}) do if y>=vy and y<vy+vh then
        local start,finish=math.max(vx,rect.x),math.min(vx+vw,rect.x+rect.width)
        local first=start-(start-rect.x)%12
        for index=0,math.ceil((finish-start)/12) do local x=first+index*12; local left=math.max(start,x); local right=math.min(finish,x+6)
            if right>left then dash(left,y,right-left,1) end
        end
    end end
    for _,x in ipairs({rect.x,rect.x+rect.width-1}) do if x>=vx and x<vx+vw then
        local start,finish=math.max(vy,rect.y),math.min(vy+vh,rect.y+rect.height)
        local first=start-(start-rect.y)%12
        for index=0,math.ceil((finish-start)/12) do local y=first+index*12; local top=math.max(start,y); local bottom=math.min(finish,y+6)
            if bottom>top then dash(x,top,1,bottom-top) end
        end
    end end
    for index=used+1,#n.dashes do n.dashes[index]:SetHidden(true) end
end
function Editor:OpenWidgetContext(id,control,entry)
    if not self.open or self.disposed or not self.api or not self.api.ContextMenu then return false end
    local view=self.runtime:GetView(id); if not view then return false end
    if self.gesture then self.gesture:Cancel() end
    self.contextGeneration=(self.contextGeneration or 0)+1
    local generation,contextGeneration,canvasGeneration=self.generation,self.contextGeneration,self.canvasGeneration
    local items={{label=self.labels.contextEdit or self.labels.edit,callback=function() self:Select(id) end}}
    if entry and self.contextItems then for _,item in ipairs(self.contextItems(id,P.Copy(entry)) or {}) do items[#items+1]=item end end
    for _,item in ipairs(items) do local callback=item.callback
        item.callback=function()
            if self.open and not self.disposed and self.generation==generation and self.contextGeneration==contextGeneration and self.canvasGeneration==canvasGeneration and I.Find(self.session:ReadDraft().widgets,id) then callback() end
        end
    end
    self.api.ContextMenu(control,items); return true
end
function Editor:_NativeView(id,view,overlay)
    local api=self.api; local n=self.nativeOverlays[id]
    if not n then
        n={root=api.controls.CreateTopLevelWindow(self.name..'Widget'..id),cells={},frames={},resizeHandles={},resizeVisible={},dashes={}}; self.nativeOverlays[id]=n
        n.root:SetMouseEnabled(false); n.root:SetDrawLayer(api.constants.DL_OVERLAY)
        n.root:SetHandler('OnEffectivelyHidden',function() if self.gesture then self.gesture:Cancel() end end)
        for index=1,4 do n.frames[index]=api.controls.CreateControl(self.name..'Frame'..id..index,n.root,api.constants.CT_CONTROL); n.frames[index]:SetMouseEnabled(true) end
        for _,point in ipairs(resizePoints) do
            local handle=chromeBlock(api,n.root,self.name..'Resize'..id..point[1]); handle:SetMouseEnabled(true); handle:SetDrawLevel(3); n.resizeHandles[point[1]]=handle
        end
        n.anchorHandle=api.controls.CreateControl(self.name..'Anchor'..id,n.root,api.constants.CT_BACKDROP)
        n.anchorHandle:SetCenterColor(0,0,0,0.85); n.anchorHandle:SetEdgeColor(0,0,0,0.85); n.anchorHandle:SetMouseEnabled(true); n.anchorHandle:SetDrawLayer(api.constants.DL_OVERLAY); n.anchorHandle:SetDrawLevel(4)
        -- A small native line-art anchor, independent of font glyph coverage.
        local strokes={{8,2,4,1},{7,3,1,3},{12,3,1,3},{8,6,4,1},{9,7,2,10},{5,9,10,2},{3,12,2,3},{15,12,2,3},{5,15,3,2},{12,15,3,2},{8,17,4,1}}
        for index,r in ipairs(strokes) do local c=chromeBlock(api,n.anchorHandle,self.name..'AnchorStroke'..id..index); c:SetDrawLevel(5); P.Anchor(api,c,n.anchorHandle,r[1],r[2],r[3],r[4]) end
        n.service=api.controls.CreateControl(self.name..'Empty'..id,n.root,api.constants.CT_CONTROL); n.service:SetMouseEnabled(true)
    end
    n.binding=(n.binding or 0)+1
    local binding,generation,canvasGeneration=n.binding,self.generation,self.canvasGeneration
    local function current() return self.open and binding==n.binding and generation==self.generation and canvasGeneration==self.canvasGeneration end
    local rect=overlay.serviceRect or overlay.rect
    P.Anchor(api,n.root,api.controls.GuiRoot,0,0,1,1); n.root:SetHidden(false)
    local function bind(control,kind,edge)
        control:SetHandler('OnMouseDown',function(c,button,ctrl,alt,shift,command) if current() then self:_Canvas('on'..kind..'MouseDown',id,c,button,ctrl,alt,shift,command,edge) end end)
        control:SetHandler('OnMouseUp',function(c,button,inside,ctrl,alt,shift,command)
            if not current() then return end
            if button==(api.constants.MOUSE_BUTTON_INDEX_RIGHT or 2) then if inside then self:OpenWidgetContext(id,c) end; return end
            if self:_Canvas('on'..kind..'MouseUp',id,c,button,inside,ctrl,alt,shift,command) then return end
            if inside and button==1 then self:Select(id) end
        end)
    end
    local a=view.widget.anchor
    n.anchorX,n.anchorY=overlay.rect.x+overlay.rect.width*a.pointX,overlay.rect.y+overlay.rect.height*a.pointY
    P.Anchor(api,n.anchorHandle,n.root,n.anchorX-10,n.anchorY-10,20,20)
    bind(n.anchorHandle,'Anchor'); bind(n.service,'Frame')
    -- Four disjoint outside strips leave cell interiors available for transfer.
    local strips={{rect.x-4,rect.y-4,rect.width+8,4},{rect.x-4,rect.y+rect.height,rect.width+8,4},{rect.x-4,rect.y,4,rect.height},{rect.x+rect.width,rect.y,4,rect.height}}
    for index,frame in ipairs(n.frames) do local r=strips[index]; P.Anchor(api,frame,n.root,r[1],r[2],r[3],r[4]); frame:SetHidden(false); bind(frame,'Frame') end
    for _,point in ipairs(resizePoints) do
        local name=point[1]; local handle=n.resizeHandles[name]
        local shown=view.widget.type=='table' or (view.widget.layout.fixedAxis=='columns' and (name=='left' or name=='right')) or (view.widget.layout.fixedAxis=='rows' and (name=='top' or name=='bottom'))
        handle:SetHidden(not shown); n.resizeVisible[name]=shown
        if shown then bind(handle,'Resize',name)
        else handle:SetHandler('OnMouseDown',nil); handle:SetHandler('OnMouseUp',nil) end
    end
    self:_ResizeHandleBounds(id,n,rect)
    n.service:SetHidden(not overlay.empty); if overlay.empty then P.Anchor(api,n.service,n.root,rect.x,rect.y,rect.width,rect.height) end
    self:_DashedBounds(id,n,rect)
    local entries={}; for _,entry in ipairs(view.entries) do entries[entry.key]=entry end
    for _,cell in pairs(n.cells) do cell:SetHidden(true); cell:SetHandler('OnMouseDown',nil); cell:SetHandler('OnMouseUp',nil) end
    for index,placement in ipairs(overlay.placements) do
        local cell=n.cells[index]
        if not cell then cell=api.controls.CreateControl(self.name..'Hit'..id..index,n.root,api.constants.CT_CONTROL); cell:SetMouseEnabled(true); n.cells[index]=cell end
        local row,column,entry=placement.row,placement.column,entries[placement.key]
        P.Anchor(api,cell,n.root,placement.rect.x,placement.rect.y,placement.rect.width,placement.rect.height); cell:SetHidden(false)
        cell:SetHandler('OnMouseDown',function(control,button,ctrl,alt,shift,command) if current() then self:_Canvas('onCellMouseDown',id,row,column,control,button,ctrl,alt,shift,command) end end)
        cell:SetHandler('OnMouseUp',function(control,button,inside,ctrl,alt,shift,command)
            if not current() then return end
            if button==(api.constants.MOUSE_BUTTON_INDEX_RIGHT or 2) then if inside then self:OpenWidgetContext(id,control,entry) end; return end
            if self:_Canvas('onCellMouseUp',id,row,column,control,button,inside,ctrl,alt,shift,command) or not inside then return end
            if button==1 then self:Select(id); if view.widget.type=='table' then self:OpenSlot(id,row,column,cell) end end
        end)
    end
end
function Editor:SetGrowthAnchor(id,x,y)
    if not self.open then return false end
    local widget=I.Find(self.session:ReadDraft().widgets,id); local view=self.runtime:GetView(id)
    if not widget or widget.type~='grid' or not view then return false end
    if self.gesture then self.gesture:Cancel() end
    return self:PatchWidget(id,{anchor=KanaEffects.Layout.Reanchor(widget.anchor,view.layout.rect,x,y,self.anchors:GetReferenceRect(widget.anchor.relativeTo))})
end
function Editor:Select(id)
    if not self:IsOpen() or not I.Find(self.session:ReadDraft().widgets,id) then return false end
    self.selected=id; self.inspector:Open(id); local draft=self.session:ReadDraft(); self:_Chrome(draft); self:_Toolbar(draft); return true
end
function Editor:OpenSlot(id,row,column,initiator)
    if not self:IsOpen() then return false end
    local w=I.Find(self.session:ReadDraft().widgets,id); if not w or w.type~='table' then return false end
    local generation=self.generation; local function current() return self.open and not self.disposed and self.generation==generation end
    self.picker:Open({purpose='slot',currentSelector=w.slots[row] and w.slots[row][column],initiator=initiator,
        onEscape=function() self:RequestClose() end,canRestoreFocus=current,
        onChoose=function(selector) if current() then return self:Apply({type='slot.assign',widgetId=id,row=row,column=column,selector=selector}) end end,
        onClear=function() if current() then return self:Apply({type='slot.clear',widgetId=id,row=row,column=column}) end end}); return true
end
function Editor:_CloseAuxiliary()
    self.picker:Close(); if self.hiddenList then self.hiddenList:Close() end; self.setEditor:Close()
    self.testMenu=false; if self.testForm then self.testForm:Hide() end
end
function Editor:OpenSets(id) if self.open then self:_CloseAuxiliary(); if id then self.setEditor.selected=id end; self.setEditor:Open() end end
function Editor:OpenHidden()
    if self.open and self.hiddenList then self:_CloseAuxiliary(); self.hiddenList:Open({onEscape=function() self:RequestClose() end,canRestoreFocus=function() return self.open and not self.disposed end}) end
end
function Editor:SetTest(count)
    if not self.open then return false end
    if count==nil or count=='live' then self.provider=nil; self.testCount=nil
    else
        local tags,seen={'player','reticleover'},{player=true,reticleover=true}
        for _,widget in ipairs(self.session:ReadDraft().widgets) do
            if not seen[widget.unitTag] then seen[widget.unitTag]=true; tags[#tags+1]=widget.unitTag end
        end
        local ok,observations=pcall(KanaEffects.Demo.Build,count,17,self.catalog,self.clock and self.clock:Now() or (self.api and self.api.Now() or 0),tags)
        if not ok then return self:Report(false,{{code='demo_unavailable'}}) end
        local store=KanaEffects.Store.New(); for _,o in ipairs(observations) do store:Upsert(o) end; self.provider=store; self.testCount=count
    end
    local ok,diag=self.runtime:Preview(self.session:ReadDraft(),self.provider or self.store); self:_Chrome(self.session:ReadDraft()); self:_Toolbar(self.session:ReadDraft()); return self:Report(ok,diag)
end
-- Native button font from ZO_DefaultButton; the shared measuring label has
-- ample width, one line and never participates in canvas geometry.
function Editor:_ButtonWidth(text)
    local api=self.api
    if not self.buttonMeasure then
        self.buttonMeasure=I.Label(api,api.controls.GuiRoot,self.name..'ButtonMeasure','ZoFontGameBold')
        self.buttonMeasure:SetDimensions(10000,40); self.buttonMeasure:SetMaxLineCount(1); self.buttonMeasure:SetHidden(true)
    end
    self.buttonMeasure:SetText(text)
    local width=self.buttonMeasure:GetTextDimensions()
    return math.max(80,width+24)
end
function Editor:_Toolbar(draft)
    if not self.api or not self.api.controls.CreateControlFromVirtual then return end
    local api,l=self.api,self.labels
    if not self.toolbar then
        local v={}; self.toolbar=v; v.root=api.controls.CreateTopLevelWindow(self.name..'Toolbar'); v.root:SetMouseEnabled(true); v.root:SetDrawTier(api.constants.DT_HIGH); v.root:SetMovable(true); v.root:SetClampedToScreen(true)
        v.fill=P.PanelFill(api,v.root,self.name..'ToolbarFill')
        v.background=api.controls.CreateControlFromVirtual(self.name..'ToolbarBackground',v.root,'ZO_DefaultBackdrop'); v.background:SetHidden(true)
        v.grip=I.Label(api,v.root,self.name..'Grip','ZoFontWinH3'); v.grip:SetText('KanaEffects'); v.grip:SetColor(unpack(P.NativeColors(api).normal)); v.grip:SetMouseEnabled(true)
        v.grip:SetHandler('OnMouseDown',function(_,button) if button==1 and self.open then v.root:StartMoving() end end)
        v.grip:SetHandler('OnMouseUp',function(_,button) if button==1 then v.root:StopMovingOrResizing(); if self.open then self:Apply({type='editor.toolbar',x=v.root:GetLeft(),y=v.root:GetTop()}) end end end)
        v.buttons={}; v.buttonTexts={}; local actions={{l.cancel,function() self:Cancel() end},{l.save,function() self:Save() end},{l.test,function() self:OpenTestMenu() end},{l.addWidget,function() self:AddWidget() end},{l.sets,function() self:OpenSets() end},{l.hiddenLibrary,function() self:OpenHidden() end}}
        for index,action in ipairs(actions) do v.buttonTexts[index]=action[1]; local fn=action[2]; v.buttons[index]=P.Button(api,v.root,self.name..'Toolbar'..index,action[1],function() if self.open then fn() end end) end
        v.widgetChoice=api.controls.CreateControlFromVirtual(self.name..'WidgetChoice',v.root,'ZO_ComboBox'); v.widgetCombo=api.ComboBox(v.widgetChoice); v.widgetCombo:SetSortsItems(false)
        v.message=I.Label(api,v.root,self.name..'Message','ZoFontGameSmall'); v.message:SetColor(unpack(P.NativeColors(api).error))
    end
    local v=self.toolbar; local vw,vh=api.controls.GuiRoot:GetDimensions()
    P.StyleButton(v.buttons[2],'primary',false,self.session:IsDirty()); v.buttonTexts[3]=self.testCount and l.test..': '..tostring(self.testCount) or l.test
    v.buttonTexts[6]=l.hiddenLibrary..' '..#draft.hidden
    P.SetButtonText(v.buttons[3],v.buttonTexts[3]); P.SetButtonText(v.buttons[6],v.buttonTexts[6])
    local natural=140; for _,title in ipairs(v.buttonTexts) do natural=natural+self:_ButtonWidth(title)+6 end
    local width=math.max(1,math.min(natural+12,vw-24))
    local positions={}; local bx,by=140,10
    for index,b in ipairs(v.buttons) do
        local bw=math.min(self:_ButtonWidth(v.buttonTexts[index]),math.max(1,width-24))
        if bx+bw>width-12 then bx,by=12,by+38 end
        positions[index]={x=bx,y=by,width=bw}; bx=bx+bw+6
    end
    local selectorY=by+42; local messageHeight=self.message and 30 or 0; local height=selectorY+44+messageHeight
    local x=math.max(0,math.min(draft.editor.toolbarX,vw-width)); local y=math.max(0,math.min(draft.editor.toolbarY,vh-height))
    P.Anchor(api,v.root,api.controls.GuiRoot,x,y,width,height); P.Anchor(api,v.background,v.root,0,0,width,height); P.Anchor(api,v.fill,v.root,0,0,width,height); P.Anchor(api,v.grip,v.root,12,13,124,30)
    for index,b in ipairs(v.buttons) do local r=positions[index]; P.Anchor(api,b,v.root,r.x,r.y,r.width,32) end
    P.Anchor(api,v.widgetChoice,v.root,12,selectorY,width-24,32)
    v.widgetCombo:ClearItems(); local generation=self.generation
    for _,widget in ipairs(draft.widgets) do local id=widget.id
        local entry=v.widgetCombo:CreateItemEntry(widget.name,function() if self.open and generation==self.generation then self:Select(id) end end)
        v.widgetCombo:AddItem(entry,api.constants.ZO_COMBOBOX_SUPPRESS_UPDATE)
        if id==self.selected then v.widgetCombo:SelectItem(entry,true) end
    end
    if not self.selected then v.widgetCombo:SetSelectedItem(l.selectWidget) end
    P.Anchor(api,v.message,v.root,12,height-26,width-24,24); v.message:SetText(self.message or ''); v.message:SetHidden(not self.message); v.root:SetHidden(false)

end
function Editor:OpenTestMenu()
    if not self.open then return end; self:_CloseAuxiliary()
    if not self.testForm then self.testForm=I.Form.New(self.api,self.name..'Tests',self.labels.test,390,420,function() self:RequestClose() end) end
    self.testMenu=true
    local f=self.testForm; if f then
        f.onClose=function() self.testMenu=false; f:Hide() end; f:Show(); f:Begin()
        for _,entry in ipairs({{'live',self.labels.live},{'ordinary',self.labels.ordinary},{50,'50'},{100,'100'},{250,'250'}}) do local value=entry[1]; f:Button(entry[2],function() self:SetTest(value); self.testMenu=false; f:Hide() end) end
        f:End()
    end
end
function Editor:SetGesturePreview(preview)
    local previous=self.gesturePreview
    self.gesturePreview=preview and P.Copy(preview) or nil
    local view=self.runtime:SetGesturePreview(preview)
    if previous and (not preview or previous.widgetId~=preview.widgetId or previous.kind~=preview.kind) and self.open then
        self:_View(previous.widgetId,self.runtime:GetView(previous.widgetId))
    end
    if preview then
        if preview.kind=='resize' and view then self:_View(preview.widgetId,view)
        elseif preview.kind=='move' and self.api then
            local native=self.nativeOverlays[preview.widgetId]
            if native then
                P.Anchor(self.api,native.root,self.api.controls.GuiRoot,preview.dx,preview.dy,1,1)
                local overlay=self.overlays[preview.widgetId]; if overlay then
                    self:_DashedBounds(preview.widgetId,native,overlay.serviceRect or overlay.rect)
                    self:_ResizeHandleBounds(preview.widgetId,native,overlay.serviceRect or overlay.rect)
                end
            end
        end
    end
    if not self.api or not self.api.controls.CreateControl then return end
    local api=self.api
    if not preview then if self.gestureChrome then for _,control in pairs(self.gestureChrome) do control:SetHidden(true) end end; return end
    if not self.gestureChrome then
        self.gestureChrome={}
        for _,key in ipairs({'ghost','target'}) do
            local c=api.controls.CreateControl(self.name..'Gesture'..key,api.controls.GuiRoot,api.constants.CT_BACKDROP)
            c:SetMouseEnabled(false); c:SetDrawLayer(api.constants.DL_OVERLAY); c:SetEdgeTexture('EsoUI/Art/Miscellaneous/borderedInsetTransparent_white_edgeFile.dds',128,16,2,0); c:SetInsets(2,2,-2,-2); local color=P.NativeColors(api).selected; c:SetCenterColor(color[1],color[2],color[3],key=='ghost' and 0.16 or 0.32); c:SetEdgeColor(color[1],color[2],color[3],0.85); self.gestureChrome[key]=c
        end
    end
    for _,key in ipairs({'ghost','target'}) do local c=self.gestureChrome[key]; local r=key=='ghost' and preview.kind=='slot' and preview.rect or key=='target' and preview.targetRect or nil
        if r then P.Anchor(api,c,api.controls.GuiRoot,r.x,r.y,r.width,r.height) end; c:SetHidden(not r)
    end
end
function Editor:SetCanvasHandlers(handlers)
    self.canvasHandlers=handlers; self.canvasGeneration=(self.canvasGeneration or 0)+1
    if self.open then self:_Chrome(self.session:ReadDraft()) end
end
function Editor:_Canvas(event,...)
    local handler=self.canvasHandlers and self.canvasHandlers[event]
    return handler and handler(...)==true or false
end
function Editor:SetGestureController(controller)
    if self.gesture==controller then return end
    if self.gesture then self.gesture:Cancel(); self:SetCanvasHandlers(nil) end
    self.gesture=controller
end
function Editor:Open()
    if self.disposed or (self.nativeHud and self.nativeHud:IsEditing()) then return false end; if self.open then return true end
    self.open=true; self.generation=self.generation+1; self.message=nil; self.provider=nil; self.selected=nil
    local ok=pcall(function()
        local mode=self.api and self.api.EditorUIMode
        if mode and not mode.IsActive() then
            self.cursorOwned=mode.SetActive(true)==true
            if not mode.IsActive() then error(self.labels.openFailed) end
        end
        if self.api and self.api.PushActionLayerByName then self.api.PushActionLayerByName('KanaEffectsEditor'); self.layerPushed=true end
        local draft=self.session:Begin(); local accepted,diag=self.runtime:Preview(draft,self.store); if not accepted then error(self.labels.invalidConfig) end
        self:_Chrome(draft); self:_Toolbar(draft)
    end)
    if not ok then self:Cancel(); if self.api and self.api.LocalMessage then self.api.LocalMessage(self.labels.openFailed) end; return false end
    return true
end
function Editor:RequestClose()
    if not self.open then return false end
    if self.setEditor.help and self.setEditor.help:IsOpen() then
        if self.setEditor.help.form:CloseDropdown() then return true end
        self.setEditor.help:Close(); return true
    end
    if self.toolbar and self.toolbar.widgetCombo:IsDropdownVisible() then self.toolbar.widgetCombo:HideDropdown(); return true end
    if self.gesture and self.gesture:Cancel() then return true end
    if self.picker:IsOpen() then self.picker:Close(); return true end
    for _,owner in ipairs({self.inspector,self.setEditor}) do if owner.form and owner:IsOpen() and owner.form:CloseDropdown() then return true end end
    if self.hiddenList and self.hiddenList:IsOpen() then self.hiddenList:Close(); return true end
    if self.closePrompt then self:ResolveClose('continue'); return true end
    if self.testMenu then self.testMenu=false; if self.testForm then self.testForm:Hide() end; return true end
    if self.setEditor:IsOpen() then self.setEditor:Close(); return true end
    if self.inspector:IsOpen() then self.inspector:Close(); return true end
    if not self.session:IsDirty() and not self.inspector:HasPendingChanges() and not (self.setEditor.HasPendingChanges and self.setEditor:HasPendingChanges()) then self:Cancel(); return true end
    self.closePrompt=true
    if not self.prompt then self.prompt=I.Form.New(self.api,self.name..'ClosePrompt',self.labels.unsaved,460,360,function() self:RequestClose() end) end
    if self.prompt then
        self.prompt.onClose=function() self:ResolveClose('continue') end; self.prompt:Show(); self.prompt:Begin(); self.prompt:Notice(self.labels.unsavedHint)
        self.prompt:Button(self.labels.save,function() self:ResolveClose('save') end); self.prompt:Button(self.labels.discard,function() self:ResolveClose('discard') end); self.prompt:Button(self.labels.continue,function() self:ResolveClose('continue') end); self.prompt:End()
    end
    return true
end
function Editor:ResolveClose(choice)
    self.closePrompt=false; if self.prompt then self.prompt:Hide() end
    if choice=='save' then return self:Save() elseif choice=='discard' then self:Cancel(); return true end; return true
end
function Editor:Save()
    if not self.open then return false end
    local pending={}
    for _,owner in ipairs({self.inspector,self.setEditor}) do if owner.GetPendingEdits or (owner.form and owner:IsOpen()) then
        local edits
        if owner.GetPendingEdits then edits=owner:GetPendingEdits() else edits=owner.form:GetPendingEdits() end
        if not edits then return false end
        for _,edit in ipairs(edits) do pending[#pending+1]=edit end
    end end
    -- A command synchronously refreshes every form. Capture all staged values
    -- first so that refresh cannot discard another valid field before Save.
    for _,edit in ipairs(pending) do if edit.callback(edit.value)==false then return false end end
    local candidate=self.session:ReadDraft(); self.closing=true
    local ok,diag=self.session:Save(); self.closing=false
    if not ok then return self:Report(false,diag) end
    -- Session closes synchronously. Apply accepted saved config before EndPreview.
    local applied,issues=self.runtime:ApplyConfig(candidate); self:_Finish(); return self:Report(applied,issues)
end
function Editor:Cancel()
    if not self.open then return end
    self.closing=true; self.session:Cancel(); self.closing=false; self:_Finish()
end
function Editor:_Finish()
    if not self.open then return end; self.open=false; self.generation=self.generation+1
    if self.layerPushed then self.layerPushed=false; self.api.RemoveActionLayerByName('KanaEffectsEditor') end
    if self.gesture and self.gesture.Cancel then self.gesture:Cancel() end
    self.picker:Close(); if self.hiddenList then self.hiddenList:Close() end; self.inspector:Close(); self.setEditor:Close()
    self.inspector:ResetDraft(); if self.setEditor.ResetDraft then self.setEditor:ResetDraft() end
    if self.setEditor.help then self.setEditor.help:Close() end
    if self.prompt then self.prompt:Hide() end; if self.testForm then self.testForm:Hide() end
    self.closePrompt=false; self.testMenu=false; self.provider=nil; self.testCount=nil; self.selected=nil; self.canvasGeneration=(self.canvasGeneration or 0)+1
    if self.toolbar then self.toolbar.widgetCombo:HideDropdown(); self.toolbar.widgetCombo:ClearItems(); self.toolbar.root:StopMovingOrResizing(); self.toolbar.root:SetHidden(true) end
    self:SetGesturePreview(nil)
    for _,n in pairs(self.nativeOverlays) do
        for _,control in ipairs(n.frames) do control:SetHandler('OnMouseDown',nil); control:SetHandler('OnMouseUp',nil) end
        for _,control in pairs(n.resizeHandles) do control:SetHandler('OnMouseDown',nil); control:SetHandler('OnMouseUp',nil) end
        n.service:SetHandler('OnMouseDown',nil); n.service:SetHandler('OnMouseUp',nil)
        n.anchorHandle:SetHandler('OnMouseDown',nil); n.anchorHandle:SetHandler('OnMouseUp',nil)
        n.root:SetHidden(true); for _,c in pairs(n.cells) do c:SetHandler('OnMouseDown',nil); c:SetHandler('OnMouseUp',nil) end
    end
    self.overlays={}; self.runtime:EndPreview()
    if self.cursorOwned then
        self.cursorOwned=nil; local mode=self.api.EditorUIMode
        if mode.CanRestore() then mode.SetActive(false) end
    end
end
function Editor:Dispose()
    if self.disposed then return end; self:Cancel(); self.disposed=true; self.unsubscribe(); self.unsubscribeViews(); self.unsubscribeAnchors()
    if self.sceneCallback then self.api.hudEditorScene:UnregisterCallback('StateChange',self.sceneCallback) end
    self:SetGestureController(nil); self:SetCanvasHandlers(nil); self:SetGesturePreview(nil);
    for _,n in pairs(self.nativeOverlays) do n.root:SetHandler('OnEffectivelyHidden',nil) end
    self.inspector:Dispose(); self.setEditor:Dispose(); if self.prompt then self.prompt:Dispose() end; if self.testForm then self.testForm:Dispose() end
    if self.toolbar then self.toolbar.grip:SetHandler('OnMouseDown',nil); self.toolbar.grip:SetHandler('OnMouseUp',nil); for _,b in ipairs(self.toolbar.buttons) do b:SetHandler('OnClicked',nil) end end
end
function KanaEffects.HandleEditorEscape()
    local app=KanaEffects.application; return app and app.editor and app.editor:RequestClose() or false
end
