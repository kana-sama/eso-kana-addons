local A,M=KanaInfoBar,KanaInfoBar.Model
local wm=WINDOW_MANAGER
A.colors={normal={.88,.87,.83,1},orange={.95,.64,.29,1},red={.94,.39,.39,1},gold={.84,.75,.5,1}}
local unpack=unpack or table.unpack
local ICON_SIZE=18
local BADGE_WIDTH,BADGE_GAP=32,4
-- BOLD_FONT's line box includes space below the visible digits. Compensate
-- for that space so numbers and icon silhouettes share an optical centre.
local NUMBER_OFFSET_Y=2

function A:Label(parent,text,size)
    local label=wm:CreateControl(nil,parent,CT_LABEL)
    label:SetFont('$(BOLD_FONT)|'..(size or 18)..'|thick-outline')
    label:SetColor(.88,.87,.83,1)
    label:SetText(text or '')
    label:SetMouseEnabled(false)
    return label
end

function A:Backdrop(parent)
    local bg=wm:CreateControl(nil,parent,CT_BACKDROP)
    bg:SetAnchorFill(parent)
    bg:SetCenterColor(.055,.06,.055,.92)
    bg:SetEdgeColor(.46,.44,.35,.8)
    bg:SetEdgeTexture('',1,1,1)
    bg:SetMouseEnabled(false)
    bg:SetDrawLayer(DL_BACKGROUND)
    return bg
end

function A:Button(parent,text,width,callback)
    local button=wm:CreateControlFromVirtual(nil,parent,'ZO_DefaultButton')
    button:SetDimensions(width,26)
    button:SetText(text)
    button:SetHandler('OnClicked',callback)
    return button
end

function A:ShowWidgetTooltip(id)
    local c,v=self.controls[id],self.values[id]
    if not c or not v or self.drag then return end
    local module=self.modules[id]
    if module.tooltip==false then self:HideTooltip(); return end
    local badge=module.kind=='badges' and not self.edit and self:BadgeAt(id) or nil
    ClearTooltip(InformationTooltip)
    local x,y=GetUIMousePosition()
    InitializeTooltip(InformationTooltip,GuiRoot,TOPLEFT,x+12,y+20,TOPLEFT)
    InformationTooltip:SetClampedToScreen(true)
    InformationTooltip:AddLine(badge and badge.name or module.name,'ZoFontWinH4',.85,.8,.66)
    local detail=badge and v.counts and ('Количество: '..tostring(v.counts[badge.key] or 0)) or v.detail or ''
    InformationTooltip:AddLine(detail,'ZoFontGame',.85,.85,.8)
    if self.edit then
        InformationTooltip:AddLine('Перетащи в строку, между строками или в «Не используются».','ZoFontGameSmall')
        if not v.visible then InformationTooltip:AddLine('Скрыт в игре: нет данных или значение равно нулю.','ZoFontGameSmall') end
    elseif badge or module.action and v.clickable~=false then
        InformationTooltip:AddLine(badge and badge.clickHint or module.clickHint or 'ЛКМ — открыть','ZoFontGameSmall',.75,.72,.62)
    end
    self.tooltipId=id
    self.tooltipBadge=badge and badge.key or nil
    self.hoverBadge=self.tooltipBadge
    self:PaintWidget(id)
    self.root:SetHandler('OnUpdate',function() self:PositionTooltip() end)
    self:PositionTooltip()
end

function A:PositionTooltip()
    if not self.tooltipId then return end
    local module=self.modules[self.tooltipId]
    if module.kind=='badges' and not self.edit then
        local badge=self:BadgeAt(self.tooltipId)
        if (badge and badge.key or nil)~=self.tooltipBadge then
            self:ShowWidgetTooltip(self.tooltipId)
            return
        end
    end
    local x,y=GetUIMousePosition()
    InformationTooltip:ClearAnchors()
    InformationTooltip:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,x+12,y+20)
end

function A:HideTooltip()
    ClearTooltip(InformationTooltip)
    self.tooltipId=nil
    self.tooltipBadge,self.hoverBadge=nil,nil
    if self.root then self.root:SetHandler('OnUpdate',nil) end
end

function A:BadgeAt(id)
    local c=self.controls[id]
    if not c or not c.badges then return nil end
    local x,y=GetUIMousePosition()
    for i,badge in ipairs(c.badges) do
        local scale=self:Config().scale
        if not badge:IsHidden() and x>=badge:GetLeft() and x<badge:GetLeft()+badge:GetWidth()*scale
            and y>=badge:GetTop() and y<badge:GetTop()+badge:GetHeight()*scale then
            return self.modules[id].badges[i]
        end
    end
end

function A:CreateBadges(c,module)
    c.badges={}
    c.iconBox:SetHidden(true); c.label:SetHidden(true)
    for i,definition in ipairs(module.badges) do
        local badge=wm:CreateControl(nil,c,CT_CONTROL)
        badge:SetDimensions(BADGE_WIDTH,32)
        badge:SetMouseEnabled(false)
        badge.iconBox=wm:CreateControl(nil,badge,CT_CONTROL)
        badge.iconBox:SetDimensions(20,20)
        badge.iconBox:SetAnchor(LEFT,badge,LEFT,0,0)
        badge.iconBox:SetMouseEnabled(false)
        for dx=-1,1 do
            for dy=-1,1 do
                if dx~=0 or dy~=0 then
                    local edge=wm:CreateControl(nil,badge.iconBox,CT_TEXTURE)
                    edge:SetDimensions(ICON_SIZE,ICON_SIZE)
                    edge:SetAnchor(CENTER,badge.iconBox,CENTER,dx*1.2,dy*1.2)
                    edge:SetTexture(definition.icon)
                    edge:SetColor(0,0,0,1)
                    edge:SetDrawLayer(DL_CONTROLS); edge:SetDrawLevel(1)
                    edge:SetMouseEnabled(false)
                end
            end
        end
        badge.icon=wm:CreateControl(nil,badge.iconBox,CT_TEXTURE)
        badge.icon:SetDimensions(ICON_SIZE,ICON_SIZE)
        badge.icon:SetAnchor(CENTER,badge.iconBox,CENTER,0,0)
        badge.icon:SetTexture(definition.icon)
        badge.icon:SetDrawLayer(DL_CONTROLS); badge.icon:SetDrawLevel(2)
        badge.icon:SetMouseEnabled(false)
        badge.counter=self:Label(badge,'0',11)
        badge.counter:SetDimensions(30,16)
        badge.counter:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        badge.counter:SetAnchor(BOTTOMRIGHT,badge,BOTTOMRIGHT,-4,-3)
        badge.counter:SetDrawLayer(DL_OVERLAY); badge.counter:SetDrawLevel(3)
        c.badges[i]=badge
    end
end

function A:RefreshBadges(c,module,v)
    local x=0
    local counts=v.counts or {}
    for i,definition in ipairs(module.badges) do
        local badge=c.badges[i]
        local count=counts[definition.key] or 0
        local text=count>0 and tostring(count) or ''
        local width=BADGE_WIDTH+math.max(0,#text-1)*8
        badge:SetHidden(false)
        badge:SetDimensions(width,32)
        badge.counter:SetText(text)
        badge.counter:SetDimensions(math.max(30,badge.counter:GetTextWidth()),16)
        if i>1 then x=x+BADGE_GAP end
        badge:ClearAnchors()
        badge:SetAnchor(TOPLEFT,c,TOPLEFT,x,self.edit and 7 or 0)
        x=x+width
    end
    return x
end

function A:ContextMenu(control)
    ClearMenu()
    AddMenuItem('Редактировать панель',function() self:OpenEditor() end)
    AddMenuItem('Настройки',function() self:OpenSettings() end)
    ShowMenu(control)
end

function A:CreateWidget(id)
    local module=self.modules[id]
    local c=wm:CreateControl(nil,self.content,CT_CONTROL)
    c:SetDimensions(80,32)
    c:SetMouseEnabled(true)
    c.bg=self:Backdrop(c); c.bg:SetHidden(true)
    c.iconBox=wm:CreateControl(nil,c,CT_CONTROL)
    c.iconBox:SetDimensions(20,20)
    c.iconBox:SetAnchor(LEFT,c,LEFT,0,0)
    c.iconBox:SetMouseEnabled(false)
    -- Offset black copies use the texture's alpha silhouette for a real outline.
    for dx=-1,1 do
        for dy=-1,1 do
            if dx~=0 or dy~=0 then
                local edge=wm:CreateControl(nil,c.iconBox,CT_TEXTURE)
                edge:SetDimensions(ICON_SIZE,ICON_SIZE)
                edge:SetAnchor(CENTER,c.iconBox,CENTER,dx*1.2,dy*1.2)
                edge:SetTexture(module.icon or '/esoui/art/inventory/inventory_stolenitem_icon.dds')
                edge:SetColor(0,0,0,1)
                edge:SetMouseEnabled(false)
                edge:SetDrawLayer(DL_CONTROLS); edge:SetDrawLevel(1)
            end
        end
    end
    c.icon=wm:CreateControl(nil,c.iconBox,CT_TEXTURE)
    c.icon:SetDimensions(ICON_SIZE,ICON_SIZE)
    c.icon:SetAnchor(CENTER,c.iconBox,CENTER,0,0)
    c.icon:SetTexture(module.icon or '/esoui/art/inventory/inventory_stolenitem_icon.dds')
    c.icon:SetDesaturation(1)
    c.icon:SetDrawLayer(DL_CONTROLS); c.icon:SetDrawLevel(2)
    c.icon:SetMouseEnabled(false)
    c.label=self:Label(c,'',18)
    c.label:SetAnchor(LEFT,c,LEFT,25,NUMBER_OFFSET_Y)
    c.nameLabel=self:Label(c,module.name,11)
    c.nameLabel:SetAnchor(TOPLEFT,c,TOPLEFT,25,0)
    c.nameLabel:SetHidden(true)
    if module.kind=='badges' then
        self:CreateBadges(c,module)
        c.nameLabel:ClearAnchors()
        c.nameLabel:SetAnchor(TOPLEFT,c,TOPLEFT,0,0)
    end
    c:SetHandler('OnMouseEnter',function()
        self.hoverId=id
        self:PaintWidget(id)
        self:ShowWidgetTooltip(id)
    end)
    c:SetHandler('OnMouseExit',function()
        if self.hoverId==id then self.hoverId=nil end
        self:PaintWidget(id)
        self:HideTooltip()
    end)
    c:SetHandler('OnMouseDown',function(_,button)
        if button==MOUSE_BUTTON_INDEX_LEFT and self.edit then self:BeginWidgetDrag(id) end
    end)
    c:SetHandler('OnMouseUp',function(_,button,inside)
        if self.edit then
            if button==MOUSE_BUTTON_INDEX_LEFT then self:EndWidgetDrag(true) end
            return
        end
        if not inside then return end
        if button==MOUSE_BUTTON_INDEX_RIGHT then self:ContextMenu(c)
        elseif button==MOUSE_BUTTON_INDEX_LEFT and module.kind=='badges' then
            local badge=self:BadgeAt(id)
            if badge and badge.action then self:HideTooltip(); badge.action() end
        elseif button==MOUSE_BUTTON_INDEX_LEFT and module.action and self.values[id].clickable~=false then
            self:HideTooltip(); module.action()
        end
    end)
    self.controls[id]=c
    return c
end

function A:PaintWidget(id)
    local c,v=self.controls[id],self.values[id]
    if not c or not v then return end
    local color=self.colors[v.color or 'normal'] or self.colors.normal
    if c.badges then
        for i,badge in ipairs(c.badges) do
            local hot=self.hoverId==id and not self.edit and self.hoverBadge==self.modules[id].badges[i].key
            local count=v.counts and v.counts[self.modules[id].badges[i].key] or 0
            badge.icon:SetColor(count>0 and (hot and 1 or .96) or 1,
                count>0 and (hot and .46 or .24) or 1,
                count>0 and (hot and .43 or .22) or 1,1)
            badge.counter:SetColor(hot and 1 or .88,hot and .97 or .87,hot and .88 or .83,1)
        end
        c:SetAlpha(self.edit and (not v.visible or not self:Config().enabled[id]) and .55 or 1)
        return
    end
    c.label:SetColor(unpack(color))
    local hot=self.hoverId==id and (self.edit or (self.modules[id].action and v.clickable~=false))
    local gold=v.color=='gold'
    c.icon:SetColor(hot and 1 or (gold and .84 or .76),hot and .93 or (gold and .75 or .74),hot and .78 or (gold and .5 or .68),1)
    if hot and (v.color==nil or v.color=='normal') then c.label:SetColor(1,.97,.88,1) end
    c:SetAlpha(self.edit and (not v.visible or not self:Config().enabled[id]) and .55 or 1)
end

function A:SetAnchorChoice(anchor)
    if not M.anchors[anchor] then return end
    local config=self:Config()
    local x,y=M.AnchorPosition(self.root:GetLeft(),self.root:GetTop(),self.root:GetWidth(),self.root:GetHeight(),anchor)
    config.anchor,config.x,config.y=anchor,x,y
    self:Refresh(true)
end

function A:PlacePanel(layout)
    local config=self:Config()
    self.root:SetDimensions(math.max(1,layout.width*config.scale),math.max(1,layout.height*config.scale))
    self.root:ClearAnchors()
    self.root:SetAnchor(_G[config.anchor],GuiRoot,TOPLEFT,config.x,config.y)
    self.content:SetScale(config.scale)
    self.content:SetDimensions(math.max(1,layout.width),math.max(1,layout.height))
    for id,c in pairs(self.controls) do
        local slot=layout.slots[id]
        c:SetHidden(slot==nil)
        if slot then
            c:ClearAnchors(); c:SetAnchor(TOPLEFT,self.content,TOPLEFT,slot.x,slot.y)
            c:SetDimensions(slot.width,32)
            c.bg:SetHidden(not self.edit)
        elseif self.tooltipId==id then self:HideTooltip() end
    end
    self.content:SetHidden(not self.edit and (not config.shown or #layout.rows==0))
end

function A:Refresh(force)
    if not self.root then return end
    -- Freeze hit targets and labels while dragging; no numeric change can move a drop zone.
    if self.drag or self.movingPanel then return end
    local config=self:Config()
    local visible,widths={},{}
    local now=GetFrameTimeSeconds()
    for _,id in ipairs(self.ids) do
        local module=self.modules[id]
        local ok,v=pcall(module.read)
        if not ok or type(v)~='table' then
            v={text='—',visible=id~='treasure',clickable=false,
                detail='Источник временно недоступен. '..tostring(v)}
        end
        v.text=tostring(v.text or '—')
        self.values[id]=v
        local c=self.controls[id] or self:CreateWidget(id)
        if c.label:GetText()~=v.text then c.label:SetText(v.text) end
        c.nameLabel:SetHidden(not self.edit)
        c.nameLabel:SetText(module.name..(self.edit and not v.visible and ' · скрыт' or ''))
        c.label:ClearAnchors()
        local contentOffset=self.edit and 7 or 0
        c.label:SetAnchor(LEFT,c,LEFT,25,contentOffset+NUMBER_OFFSET_Y)
        c.iconBox:ClearAnchors()
        c.iconBox:SetAnchor(LEFT,c,LEFT,0,contentOffset)
        local badgeWidth=module.kind=='badges' and self:RefreshBadges(c,module,v) or nil
        self:PaintWidget(id)
        visible[id]=self.edit~=nil or v.visible~=false
        local s=self.widths[id] or {}; self.widths[id]=s
        if visible[id] then
            if badgeWidth then
                widths[id]=badgeWidth
                if self.edit then widths[id]=math.max(widths[id],c.nameLabel:GetTextWidth()+8) end
            else
                self.measure:SetText(v.text)
                local measured=self.measure:GetTextWidth()
                if not s.minimum then
                    local widest,digitWidth='0',0
                    for d=0,9 do
                        self.measure:SetText(tostring(d))
                        if self.measure:GetTextWidth()>digitWidth then widest,digitWidth=tostring(d),self.measure:GetTextWidth() end
                    end
                    self.measure:SetText((module.sample:gsub('%d',widest)))
                    s.minimum=self.measure:GetTextWidth()
                end
                widths[id]=25+M.ReserveWidth(s,measured,s.minimum,now)
                if self.edit then widths[id]=math.max(widths[id],25+c.nameLabel:GetTextWidth()+8) end
            end
        else
            s.since,s.target=nil,nil
            widths[id]=badgeWidth or 25+(s.width or 48)
        end
    end
    self.currentWidths=widths
    local layout=M.Layout(config.rows,config.enabled,widths,visible,config.gap,
        self.edit and math.max(20,config.rowGap) or config.rowGap,config.anchor,config.gridMode)
    self.layout=layout
    self:PlacePanel(layout)
    if self.edit then self:RefreshEditor(force) end
    if self.tooltipId then self:ShowWidgetTooltip(self.tooltipId) end
end

function A:CreatePanel()
    self.controls,self.values={},{}
    self.root=wm:CreateTopLevelWindow('KanaInfoBarWindow')
    self.root:SetMouseEnabled(false)
    self.root:SetClampedToScreen(true)
    self.root:SetDrawTier(DT_MEDIUM)
    self.content=wm:CreateControl(nil,self.root,CT_CONTROL)
    self.content:SetAnchor(TOPLEFT,self.root,TOPLEFT,0,0)
    self.measure=self:Label(self.root,'',18); self.measure:SetHidden(true)
    self.fragment=ZO_SimpleSceneFragment:New(self.root)
    HUD_SCENE:AddFragment(self.fragment); HUD_UI_SCENE:AddFragment(self.fragment)
    self.fragment:RegisterCallback('StateChange',function(_,state)
        if state==SCENE_FRAGMENT_HIDING or state==SCENE_FRAGMENT_HIDDEN then
            self:HideTooltip()
            if self.edit then self:CloseEditor(false) end
        end
    end)
end
