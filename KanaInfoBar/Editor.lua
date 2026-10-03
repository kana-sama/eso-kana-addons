local A,M=KanaInfoBar,KanaInfoBar.Model
local wm=WINDOW_MANAGER

function A:OpenEditor()
    if self.edit then return end
    local function open()
        if self.edit or not SCENE_MANAGER:IsShowing('hudui') then return end
        -- ZO_SavedVars is an interface backed by __index, not an enumerable
        -- settings table. Read each setting through the interface before copying.
        local config={}
        for _,key in ipairs(self.configKeys) do config[key]=M.Copy(self.sv[key]) end
        self.edit={config=config}
        self:HideTooltip()
        SCENE_MANAGER:SetInUIMode(true)
        self:CreateEditorControls()
        self.editorUI:SetHidden(false)
        KEYBIND_STRIP:AddKeybindButtonGroup(self.editorKeys)
        self:Refresh(true)
    end
    if SCENE_MANAGER:IsShowing('hudui') then open()
    else SCENE_MANAGER:CallWhen('hudui',SCENE_SHOWN,open); SCENE_MANAGER:Show('hudui') end
end

function A:CloseEditor(save)
    if not self.edit then return end
    self:EndWidgetDrag(false)
    self:EndPanelDrag(false)
    if save then
        local c=self.edit.config
        for _,key in ipairs(self.configKeys) do
            self.sv[key]=M.Copy(c[key])
        end
    end
    self.edit=nil
    self:HideTooltip()
    self.editorUI:SetHidden(true)
    for _,zone in ipairs(self.zoneControls) do zone:SetHidden(true) end
    self.capture:SetHidden(true)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.editorKeys)
    self:Refresh(true)
end

function A:CancelEditAction()
    if self.drag then self:EndWidgetDrag(false)
    elseif self.movingPanel then self:EndPanelDrag(false)
    else self:CloseEditor(false) end
end

function A:CreateEditorControls()
    if self.editorUI then return end
    self.editorUI=wm:CreateControl(nil,self.content,CT_CONTROL)
    self.editorUI:SetDimensions(420,90)
    self:Backdrop(self.editorUI)
    self.editorUI:SetDrawLayer(DL_OVERLAY)
    local handle=self:Button(self.editorUI,'Переместить панель',185,function() end)
    handle:SetAnchor(TOPLEFT,self.editorUI,TOPLEFT,8,6)
    handle:SetHandler('OnMouseDown',function(_,button)
        if button==MOUSE_BUTTON_INDEX_LEFT then self:BeginPanelDrag() end
    end)
    handle:SetHandler('OnMouseUp',function() self:EndPanelDrag(true) end)
    local done=self:Button(self.editorUI,'Готово',90,function() self:CloseEditor(true) end)
    done:SetAnchor(TOPRIGHT,self.editorUI,TOPRIGHT,-100,6)
    local cancel=self:Button(self.editorUI,'Отмена',90,function() self:CloseEditor(false) end)
    cancel:SetAnchor(TOPRIGHT,self.editorUI,TOPRIGHT,-6,6)
    self.anchorButton=self:Button(self.editorUI,'Якорь',400,function(button)
        ClearMenu()
        for i,key in ipairs(M.anchorOrder) do
            local anchor=key
            AddMenuItem(M.anchorNames[i],function() self:SetAnchorChoice(anchor) end)
        end
        ShowMenu(button)
    end)
    self.anchorButton:SetAnchor(TOPLEFT,self.editorUI,TOPLEFT,8,35)
    self.editorHint=self:Label(self.editorUI,'Перетащи виджет в строку или в область «+».',13)
    self.editorHint:SetAnchor(TOPLEFT,self.editorUI,TOPLEFT,10,66)
    self.trayLabel=self:Label(self.editorUI,'Не используются — перетащи сюда, чтобы отключить',13)
    self.trayLabel:SetAnchor(TOPLEFT,self.editorUI,TOPLEFT,10,92)
    self.zoneControls={}
    self.capture=wm:CreateTopLevelWindow('KanaInfoBarDragCapture')
    self.capture:SetAnchorFill(GuiRoot)
    self.capture:SetMouseEnabled(true)
    self.capture:SetDrawTier(DT_HIGH)
    self.capture:SetHidden(true)
    self.capture:SetHandler('OnMouseUp',function(_,button)
        if button==MOUSE_BUTTON_INDEX_LEFT then
            if self.drag then self:EndWidgetDrag(true) else self:EndPanelDrag(true) end
        else self:CancelEditAction() end
    end)
    self.capture:SetHandler('OnUpdate',function() self:UpdateDrag() end)
    self.ghost=wm:CreateControl(nil,self.capture,CT_CONTROL)
    self:Backdrop(self.ghost)
    self.ghost:SetAlpha(.8)
    self.ghostLabel=self:Label(self.ghost,'',16)
    self.ghostLabel:SetAnchor(CENTER,self.ghost,CENTER,0,0)
    self.marker=wm:CreateControl(nil,self.capture,CT_BACKDROP)
    self.marker:SetCenterColor(.92,.78,.42,.7)
    self.marker:SetEdgeColor(.95,.83,.53,1)
    self.marker:SetEdgeTexture('',1,1,1)
    self.marker:SetHidden(true)
    self.editorKeys={alignment=KEYBIND_STRIP_ALIGN_RIGHT,
        {name='Отмена',keybind='UI_SHORTCUT_NEGATIVE',callback=function() self:CancelEditAction() end}}
    -- UI_SHORTCUT_EXIT is used by some keyboard scene/input configurations.
    ZO_PreHook('ZO_KeybindStrip_HandleKeybind',function(key)
        if self.edit and (key=='UI_SHORTCUT_NEGATIVE' or key=='UI_SHORTCUT_EXIT') then
            self:CancelEditAction(); return true
        end
    end)
end

function A:RefreshEditor()
    local c,layout=self:Config(),self.layout
    local a=M.anchors[c.anchor]
    local toolWidth=math.max(420,layout.width)
    local toolX=(layout.width-toolWidth)*a.x
    -- Keep the toolbar reachable near either screen edge without moving the HUD.
    toolX=math.max(-self.root:GetLeft()/c.scale,math.min(toolX,
        (GuiRoot:GetWidth()-self.root:GetLeft())/c.scale-toolWidth))
    local trayRows,usedWidth,row=1,0,1
    self.traySlots={}
    for _,id in ipairs(self.ids) do
        if not c.enabled[id] then
            local width=self.currentWidths[id]
            if usedWidth>0 and usedWidth+width>toolWidth-20 then
                row,usedWidth=row+1,0
            end
            self.traySlots[id]={x=10+usedWidth,y=114+(row-1)*38,width=width}
            usedWidth=usedWidth+width+10
        end
    end
    trayRows=row
    local toolHeight=120+trayRows*38
    local toolY=layout.height+28
    if self.root:GetTop()+(toolY+toolHeight)*c.scale>GuiRoot:GetHeight()-8 then toolY=-toolHeight-28 end
    toolY=math.max(-self.root:GetTop()/c.scale,toolY)
    self.editorUI:ClearAnchors()
    self.editorUI:SetAnchor(TOPLEFT,self.content,TOPLEFT,toolX,toolY)
    self.editorUI:SetDimensions(toolWidth,toolHeight)
    for i,key in ipairs(M.anchorOrder) do
        if key==c.anchor then self.anchorButton:SetText('Якорь: '..M.anchorNames[i]) end
    end
    self.trayBounds={x=toolX,y=toolY+88,width=toolWidth,height=toolHeight-88}
    for id,slot in pairs(self.traySlots) do
        local control=self.controls[id]
        slot.x,slot.y=slot.x+toolX,slot.y+toolY
        control:ClearAnchors(); control:SetAnchor(TOPLEFT,self.content,TOPLEFT,slot.x,slot.y)
        control:SetDimensions(slot.width,32); control:SetHidden(false); control.bg:SetHidden(false)
    end
    self.dropZones={}
    local zoneWidth=math.max(layout.width,150)
    local zoneX=(layout.width-zoneWidth)*a.x
    for i,rowData in ipairs(layout.rows) do
        self.dropZones[#self.dropZones+1]={kind='new',row=rowData.index,x=zoneX,y=rowData.y-17,width=zoneWidth,height=14}
    end
    self.dropZones[#self.dropZones+1]={kind='new',row=#c.rows+1,x=zoneX,y=layout.height+3,width=zoneWidth,height=16}
    if #layout.rows==0 then self.dropZones[1].y=0 end
    for i,zone in ipairs(self.dropZones) do
        local control=self.zoneControls[i]
        if not control then
            control=wm:CreateControl(nil,self.content,CT_CONTROL)
            control.bg=self:Backdrop(control)
            control.bg:SetCenterColor(.28,.24,.12,.32)
            control.label=self:Label(control,'+ Новая строка',11)
            control.label:SetAnchor(CENTER,control,CENTER,0,0)
            self.zoneControls[i]=control
        end
        control:ClearAnchors(); control:SetAnchor(TOPLEFT,self.content,TOPLEFT,zone.x,zone.y)
        control:SetDimensions(zone.width,zone.height); control:SetHidden(false)
    end
    for i=#self.dropZones+1,#self.zoneControls do self.zoneControls[i]:SetHidden(true) end
end

function A:BeginWidgetDrag(id)
    if not self.edit then return end
    self:HideTooltip()
    local x,y=GetUIMousePosition()
    self.drag={id=id,startX=x,startY=y,active=false}
    self.capture:SetHidden(false)
    self.ghost:SetHidden(true); self.marker:SetHidden(true)
end

local function Inside(x,y,box)
    return x>=box.x and y>=box.y and x<=box.x+box.width and y<=box.y+box.height
end

function A:FindDropTarget(x,y)
    if Inside(x,y,self.trayBounds) then return {kind='disable',box=self.trayBounds} end
    for _,zone in ipairs(self.dropZones) do
        if Inside(x,y,zone) then return {kind='new',row=zone.row,index=1,box=zone} end
    end
    local c=self:Config()
    for _,row in ipairs(self.layout.rows) do
        if y>=row.y and y<=row.y+32 and x>=math.min(0,row.x)-12 and x<=math.max(self.layout.width,row.width)+12 then
            local index=#c.rows[row.index]+1
            local markerX=row.x+row.width
            for _,id in ipairs(row.ids) do
                local slot=self.layout.slots[id]
                if x<slot.x+slot.width/2 then
                    for n,value in ipairs(c.rows[row.index]) do if value==id then index=n; break end end
                    markerX=slot.x-4
                    break
                end
            end
            return {kind='insert',row=row.index,index=index,box={x=markerX,y=row.y,width=3,height=32}}
        end
    end
end

function A:UpdateDrag()
    local x,y=GetUIMousePosition()
    if self.movingPanel then
        local move=self.movingPanel
        local c=self:Config()
        c.x,c.y=move.anchorX+x-move.x,move.anchorY+y-move.y
        self.root:ClearAnchors(); self.root:SetAnchor(_G[c.anchor],GuiRoot,TOPLEFT,c.x,c.y)
        return
    end
    local drag=self.drag
    if not drag then return end
    if not drag.active and (x-drag.startX)^2+(y-drag.startY)^2<16 then return end
    drag.active=true
    local c=self:Config()
    self.ghost:SetHidden(false)
    self.ghost:SetDimensions(math.max(140,self.currentWidths[drag.id]*c.scale),32*c.scale)
    self.ghost:ClearAnchors(); self.ghost:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,x+14,y+14)
    self.ghostLabel:SetText(self.modules[drag.id].name)
    local lx,ly=(x-self.root:GetLeft())/c.scale,(y-self.root:GetTop())/c.scale
    drag.target=self:FindDropTarget(lx,ly)
    self.marker:SetHidden(drag.target==nil)
    if drag.target then
        local box=drag.target.box
        self.marker:ClearAnchors()
        self.marker:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,self.root:GetLeft()+box.x*c.scale,self.root:GetTop()+box.y*c.scale)
        self.marker:SetDimensions(box.width*c.scale,box.height*c.scale)
    end
end

function A:EndWidgetDrag(apply)
    local drag=self.drag
    if not drag then return end
    if apply then self:UpdateDrag() end
    if apply and drag.active and drag.target then
        local target,c=drag.target,self:Config()
        if target.kind=='disable' then c.enabled[drag.id]=false
        else M.Move(c,drag.id,target.row,target.index,target.kind=='new') end
    end
    self.drag=nil
    self.capture:SetHidden(true)
    self.ghost:SetHidden(true); self.marker:SetHidden(true)
    self:Refresh(true)
end

function A:BeginPanelDrag()
    if not self.edit then return end
    self:HideTooltip()
    local x,y=GetUIMousePosition()
    local c=self:Config()
    self.movingPanel={x=x,y=y,anchorX=c.x,anchorY=c.y}
    self.capture:SetHidden(false)
    self.ghost:SetHidden(true); self.marker:SetHidden(true)
end

function A:EndPanelDrag(apply)
    local move=self.movingPanel
    if not move then return end
    local c=self:Config()
    if not apply then c.x,c.y=move.anchorX,move.anchorY
    else c.x,c.y=M.AnchorPosition(self.root:GetLeft(),self.root:GetTop(),self.root:GetWidth(),self.root:GetHeight(),c.anchor) end
    self.movingPanel=nil
    self.capture:SetHidden(true)
    self:Refresh(true)
end
