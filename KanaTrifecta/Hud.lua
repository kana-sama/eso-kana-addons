local K=KanaTrifecta
local Hud={};Hud.__index=Hud;K.Hud=Hud
-- Scroll and medal match the approved mockup; the skull uses native ESO art.
K.Art={skull='esoui/art/icons/mapkey/mapkey_groupboss.dds',scroll='eso-kana-addons/KanaTrifecta/textures/hardmode.dds',
 achievements='eso-kana-addons/KanaTrifecta/textures/achievements-'}
function Hud:Color(control,role)
    if role=='title' then control:SetColor(self.api.GetInterfaceColor(self.api.INTERFACE_COLOR_TYPE_CON_COLORS,self.api.CON_APPROPRIATE));return end
    local names={hint='ZO_HINT_TEXT',normal='ZO_SELECTED_TEXT',success='ZO_SUCCEEDED_TEXT',error='ZO_ERROR_COLOR'}
    control:SetColor(self.api[names[role] or names.hint]:UnpackRGBA())
end
function Hud:Label(name,parent,font)
    local a=self.api;local c=a.WINDOW_MANAGER:CreateControl('KanaTrifecta'..name,parent,a.CT_LABEL)
    c:SetFont(font);c:SetHorizontalAlignment(a.TEXT_ALIGN_RIGHT);return c
end
function Hud:LayoutTimerTooltip()
    local a,v=self.api,self.view
    if not v then return end
    local elapsed=v.timer.elapsedMs or (not v.timer.stopped and 0 or nil)
    local limit=v.timer.limitMs
    local overtime=v.timer.colorRole=='error'
    local remainingText=v.timer.text:gsub('^~','')
    local data={{K.Strings.timerLimit,K.FormatDuration(limit)},
        {K.Strings.timerElapsed,K.FormatDuration(elapsed)},
        {overtime and K.Strings.timerOvertime or K.Strings.timerRemaining,remainingText}}
    local nameWidth,valueWidth=0,0
    for i,entry in ipairs(data) do
        local row=self.tooltipRows[i]
        row.label:SetWidth(260);row.value:SetWidth(120)
        row.label:SetText(entry[1]);row.value:SetText(entry[2])
        nameWidth=math.max(nameWidth,row.label:GetTextWidth());valueWidth=math.max(valueWidth,row.value:GetTextWidth())
        self:Color(row.value,i==3 and overtime and 'error' or 'normal')
    end
    local width=nameWidth+32+valueWidth
    local y=0
    for _,row in ipairs(self.tooltipRows) do
        row.label:SetWidth(nameWidth);row.value:SetWidth(valueWidth)
        local height=math.max(20,row.label:GetTextHeight(),row.value:GetTextHeight())
        row.label:SetHeight(height);row.value:SetHeight(height)
        row.label:ClearAnchors();row.label:SetAnchor(a.TOPLEFT,self.tooltipBody,a.TOPLEFT,0,y)
        row.value:ClearAnchors();row.value:SetAnchor(a.TOPRIGHT,self.tooltipBody,a.TOPRIGHT,0,y)
        y=y+height+4
    end
    self.tooltipBody:SetDimensions(width,y-4)
    local padWidth,padHeight=self.timerTooltip:GetResizeToFitPadding()
    self.timerTooltip:SetDimensionConstraints(width+padWidth,y-4+padHeight,width+padWidth,y-4+padHeight)
    self.timerTooltip:SetDimensions(width+padWidth,y-4+padHeight)
end
function Hud:ShowTimerTooltip()
    local a=self.api
    if not self.view or not a.InitializeTooltip then return end
    if not self.timerTooltip then
        self.tooltipRoot=a.WINDOW_MANAGER:CreateControlFromVirtual('KanaTrifectaTimerTooltipTopLevel',a.GuiRoot,'TooltipTopLevel')
        self.timerTooltip=a.WINDOW_MANAGER:CreateControlFromVirtual('KanaTrifectaTimerTooltip',self.tooltipRoot,'ZO_BaseTooltip')
        self.tooltipBody=a.WINDOW_MANAGER:CreateControl('KanaTrifectaTimerTooltipBody',self.timerTooltip,a.CT_CONTROL)
        self.tooltipRows={}
        for i=1,3 do
            local label=self:Label('TimerTooltipLabel'..i,self.tooltipBody,'ZoFontGame')
            label:SetHorizontalAlignment(a.TEXT_ALIGN_LEFT);self:Color(label,'hint')
            self.tooltipRows[i]={label=label,value=self:Label('TimerTooltipValue'..i,self.tooltipBody,'ZoFontGameBold')}
        end
    end
    a.InitializeTooltip(self.timerTooltip,self.timer,a.RIGHT,0,0,a.LEFT)
    self:LayoutTimerTooltip()
    self.timerTooltip:AddControl(self.tooltipBody)
    self.tooltipBody:ClearAnchors();self.tooltipBody:SetAnchor(a.CENTER)
    self.tooltipBody:SetHidden(false);self.tooltipVisible=true
end
function Hud:HideTimerTooltip()
    if self.tooltipVisible and self.timerTooltip then self.api.ClearTooltip(self.timerTooltip) end
    self.tooltipVisible=false
end
function Hud.New(api,onClick,settings)
    local self=setmetatable({api=api,settings=settings or {showBossKillTimes=true},rows={},visible=false,available=false},Hud)
    local wm=api.WINDOW_MANAGER
    self.root=wm:CreateTopLevelWindow('KanaTrifectaHud');self.root:SetDrawTier(api.DT_LOW);self.root:SetMouseEnabled(false);self.root:SetHidden(true)
    self.content=wm:CreateControl('KanaTrifectaContent',self.root,api.CT_CONTROL);self.content:SetAnchorFill();self.content:SetMouseEnabled(false);self.content:SetHidden(true)
    self.title=self:Label('Title',self.content,'ZoFontGameShadow');self:Color(self.title,'title')
    self.timer=self:Label('Timer',self.content,'ZoFontCallout');self.deaths=self:Label('Deaths',self.content,'ZoFontCallout')
    self.skull=wm:CreateControl('KanaTrifectaSkull',self.content,api.CT_TEXTURE);self.skull:SetDimensions(19,19);self.skull:SetTexture(K.Art.skull)
    self.button=wm:CreateControl('KanaTrifectaAchievementsButton',self.content,api.CT_BUTTON);self.button:SetDimensions(24,24)
    -- A 24 px hit target surrounds the 22 px white medal.
    self.medal=wm:CreateControl('KanaTrifectaMedal',self.button,api.CT_TEXTURE);self.medal:SetDimensions(22,22)
    self.medal:SetAnchor(api.TOPLEFT,self.button,api.TOPLEFT,1,1);self.medal:SetTexture(K.Art.achievements..'up.dds')
    self.button:SetMouseEnabled(true);self.button:SetHandler('OnClicked',function() if self.available then onClick() end end)
    self.scroll=wm:CreateControlFromVirtual('KanaTrifectaBossScroll',self.content,'ZO_ScrollContainer')
    self.scrollChild=self.scroll:GetNamedChild('ScrollChild')
    -- Hover feedback remains on the medal; only the timer has a tooltip.
    self.button:SetHandler('OnMouseEnter',function() self.medal:SetTexture(K.Art.achievements..'over.dds') end)
    self.button:SetHandler('OnMouseExit',function() self.medal:SetTexture(K.Art.achievements..'up.dds') end)
    self.button:SetHandler('OnMouseDown',function() if self.available then self.medal:SetTexture(K.Art.achievements..'down.dds') end end)
    self.button:SetHandler('OnMouseUp',function(_,_,inside) self.medal:SetTexture(K.Art.achievements..(inside and 'over.dds' or 'up.dds')) end)
    self.timer:SetMouseEnabled(true)
    self.timer:SetHandler('OnMouseEnter',function() self:ShowTimerTooltip() end)
    self.timer:SetHandler('OnMouseExit',function() self:HideTimerTooltip() end)
    self.fragment=api.ZO_SimpleSceneFragment:New(self.root)
    api.HUD_SCENE:AddFragment(self.fragment);api.HUD_UI_SCENE:AddFragment(self.fragment)
    self.root:SetHandler('OnShow',function() self:Attach(self:ResolveAnchor());if self.view then self:Render(self.view) end end)
    self.root:SetHandler('OnHide',function() self:HideTimerTooltip() end)
    self.root:SetHandler('OnRectChanged',function() if self.view then self:Relayout() end end)
    self:Attach(self:ResolveAnchor())
    return self
end
function Hud:ResolveAnchor()
    local tracker=self.api.FOCUSED_QUEST_TRACKER
    if tracker and tracker.GetTrackerControl then
        local control=tracker:GetTrackerControl()
        if control then return control end
    end
    local wm=self.api.WINDOW_MANAGER
    if wm.GetControlByName then
        return wm:GetControlByName('ZO_FocusedQuestTrackerPanelContainerQuestContainer','')
    end
end
function Hud:Attach(anchor)
    if not anchor then self.anchor=nil;self.content:SetHidden(true);return false end
    if self.anchor~=anchor then
        self.anchor=anchor;self.root:ClearAnchors();self.root:SetAnchor(self.api.TOPRIGHT,anchor,self.api.BOTTOMRIGHT,0,18)
        self.layoutDirty=true
    end
    self.content:SetHidden(not self.visible);return true
end
function Hud:SetVisible(visible)
    self.visible=visible;self.content:SetHidden(not visible or not self.anchor)
    if not visible then self:HideTimerTooltip() end
end
function Hud:SetAchievementsAvailable(available,reason)
    self.available=available;self.unavailableReason=reason;self.button:SetEnabled(true);self.medal:SetAlpha(available and 1 or 0.45)
end
function Hud:Row(index)
    if self.rows[index] then return self.rows[index] end
    local a=self.api;local row={}
    row.label=self:Label('Boss'..index,self.scrollChild,'ZoFontGameShadow')
    row.icon=a.WINDOW_MANAGER:CreateControl('KanaTrifectaHardMode'..index,self.scrollChild,a.CT_TEXTURE)
    row.icon:SetTexture(K.Art.scroll);row.icon:SetDimensions(14,14)
    row.killTime=self:Label('BossKillTime'..index,self.scrollChild,'ZoFontGameShadow')
    self.rows[index]=row;return row
end
function Hud:Relayout(availableWidth,availableHeight)
    if not self.anchor or self.layoutBusy then return end
    self.layoutBusy=true
    local a=self.api
    local width=math.max(80,math.min(320,a.ZO_HUD_TRACKER_MAX_WIDTH or 320,availableWidth or self.anchor:GetRight()))
    local height=math.max(100,availableHeight or (a.GuiRoot:GetHeight()-self.anchor:GetBottom()-26))
    self.width=width
    self.title:SetWidth(width-31);self.title:ClearAnchors();self.title:SetAnchor(a.TOPRIGHT,self.content,a.TOPRIGHT,0,0)
    self.title:SetWidth(math.max(1,math.min(width-31,self.title:GetTextWidth())))
    local titleH=math.max(24,self.title:GetTextHeight());self.title:SetHeight(titleH)
    self.button:ClearAnchors();self.button:SetAnchor(a.RIGHT,self.title,a.LEFT,-6,0)
    self.deaths:SetDimensions(math.max(1,self.deaths:GetTextWidth()),42);self.deaths:ClearAnchors();self.deaths:SetAnchor(a.TOPRIGHT,self.content,a.TOPRIGHT,0,titleH+4)
    self.skull:ClearAnchors();self.skull:SetAnchor(a.RIGHT,self.deaths,a.LEFT,-7,0)
    self.timer:SetDimensions(math.max(120,self.timer:GetTextWidth()),42);self.timer:ClearAnchors();self.timer:SetAnchor(a.TOPRIGHT,self.skull,a.TOPLEFT,-24,-11.5)
    self.listTop=titleH+4+42+5
    local y=0
    for _,row in ipairs(self.rows) do
        if row.data then
            local showTime=not row.killTime:IsHidden()
            -- Reset the empty label's 1 px width before measuring newly recorded text.
            row.killTime:SetWidth(width)
            local timeWidth=showTime and row.killTime:GetTextWidth() or 0
            local reserve=math.max(41,(row.data.hasHardMode and 21 or 0)+(showTime and timeWidth+10 or 0))
            row.label:SetWidth(math.max(1,width-reserve));row.label:ClearAnchors();row.label:SetAnchor(a.TOPRIGHT,self.scrollChild,a.TOPRIGHT,0,y)
            row.label:SetWidth(math.max(1,math.min(math.max(1,width-reserve),row.label:GetTextWidth())))
            local h=math.max(20,row.label:GetTextHeight());row.label:SetHeight(h)
            row.icon:ClearAnchors();row.icon:SetAnchor(a.TOPRIGHT,row.label,a.TOPLEFT,-7,5)
            row.killTime:SetDimensions(math.max(1,timeWidth),h);row.killTime:ClearAnchors()
            row.killTime:SetAnchor(a.TOPRIGHT,row.label,a.TOPLEFT,-(row.data.hasHardMode and 31 or 10),0)
            y=y+h+2
        end
    end
    local barWidth=a.ZO_SCROLL_BAR_WIDTH
    self.scroll:ClearAnchors();self.scroll:SetAnchor(a.TOPRIGHT,self.content,a.TOPRIGHT,barWidth,self.listTop)
    self.scroll:SetDimensions(width+barWidth,math.min(y,math.max(20,height-self.listTop)))
    self.scrollChild:SetDimensions(width,y)
    self.root:SetDimensions(width,self.listTop+self.scroll:GetHeight())
    self.layoutDirty=false;self.layoutBusy=false
end
function Hud:Render(view)
    self.view=view
    if not self:Attach(self:ResolveAnchor()) then return end
    local dirty=self.layoutDirty
    if self.titleText~=view.title then self.titleText=view.title;self.title:SetText(view.title);dirty=true end
    for _,key in ipairs({'timer','deaths'}) do
        if self[key..'Text']~=view[key].text then self[key..'Text']=view[key].text;self[key]:SetText(view[key].text)
            local width=self[key]:GetTextWidth();if self[key..'Width']~=width then self[key..'Width']=width;dirty=true end
        end
        self:Color(self[key],view[key].colorRole)
    end
    self:Color(self.skull,view.deaths.colorRole)
    for i,data in ipairs(view.bossRows) do
        local row=self:Row(i)
        if not row.data or row.data.name~=data.name then row.label:SetText(data.name);dirty=true end
        local killTime=self.settings.showBossKillTimes and data.killTimeText or ''
        if row.killTimeText~=killTime then row.killTimeText=killTime;row.killTime:SetText(killTime);dirty=true end
        row.killTime:SetHidden(killTime=='');self:Color(row.killTime,'hint')
        row.data=data;row.label:SetHidden(false);row.icon:SetHidden(not data.hasHardMode)
        self:Color(row.label,data.colorRole);self:Color(row.icon,data.colorRole)
    end
    for i=#view.bossRows+1,#self.rows do local row=self.rows[i];row.data=nil;row.label:SetHidden(true);row.icon:SetHidden(true);row.killTime:SetHidden(true);dirty=true end
    if dirty then self:Relayout() end
    if self.tooltipVisible then self:LayoutTimerTooltip() end
end

function Hud:Status()
    local anchor=self:ResolveAnchor()
    local fragment=self.fragment.IsShowing and tostring(self.fragment:IsShowing()) or 'unknown'
    local function value(v) return v==nil and '?' or tostring(v) end
    local name=anchor and anchor:GetName() or 'missing'
    local anchorXY=anchor and (value(anchor:GetRight())..','..value(anchor:GetBottom())) or '?'
    return string.format('KanaTrifecta UI v1: eligible=%s; rootHidden=%s; contentHidden=%s; fragmentShowing=%s\nanchor=%s; anchorRightBottom=%s\npanelLeftTop=%s,%s; size=%s,%s; rendered=%s',
        tostring(self.visible),tostring(self.root:IsHidden()),tostring(self.content:IsHidden()),fragment,
        value(name),anchorXY,value(self.root:GetLeft()),value(self.root:GetTop()),
        value(self.root:GetWidth()),value(self.root:GetHeight()),tostring(self.titleText~=nil))
end
