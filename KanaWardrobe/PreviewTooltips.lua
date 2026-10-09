local KW=KanaWardrobe
local Tooltips={};KW.PreviewTooltips=Tooltips
local Instance={};Instance.__index=Instance
local nextId=0
local unpack=unpack or table.unpack
local FONT,GAP="ZoFontHeader",16
local YELLOW,WHITE={201/255,195/255,164/255,1},{1,1,1,1}
function Tooltips.New()
    nextId=nextId+1
    return setmetatable({generation=0,labels={},name="KanaWardrobeSources"..nextId},Instance)
end
local function clear(tooltip)
    (ClearTooltipImmediately or ClearTooltip)(tooltip)
end
function Instance:Hide()
    self.generation=self.generation+1
    if self.tooltip and self.tooltip:GetOwner()==self.owner then
        clear(self.tooltip)
    end
    if self.body then self.body:SetHidden(true)end
    self.tooltip=nil;self.owner=nil
end
function Instance:ContainsMouse()
    return self.tooltip and self.tooltip:GetOwner()==self.owner and not self.tooltip:IsHidden() and MouseIsOver(self.tooltip)
end
function Instance:Leave(owner)
    if self.owner~=owner then return end
    local generation=self.generation
    local function check()
        if self.generation~=generation then return end
        if MouseIsOver(owner) or self:ContainsMouse()then zo_callLater(check,120)
        else self:Hide()end
    end
    zo_callLater(check,120)
end
function Instance:Open(tooltip,owner)
    self.tooltip=tooltip;self.owner=owner
    -- Native tooltip placement/clamping handles screen edges. Keep it beside
    -- the hovered row so entering a scrollable breakdown is a short movement.
    local right=GuiRoot:GetRight()-owner:GetRight()
    if right>=520*owner:GetScale()then InitializeTooltip(tooltip,owner,TOPLEFT,10,0,TOPRIGHT)
    else InitializeTooltip(tooltip,owner,TOPRIGHT,-10,0,TOPLEFT)end
end
local function linksFor(data)
    local links,seen={},{}
    if data.link and data.link~="" then links[1]=data.link;seen[data.link]=true end
    for _,origin in ipairs(data.sources or {})do
        local source=origin.source or {};local link=source.link
        if link and link~="" and not seen[link] and (not data.bar or origin[data.bar])then
            seen[link]=true;links[#links+1]=link
        end
    end
    return links
end
function Instance:ShowItem(owner,data)
    local links=linksFor(data)
    if #links==0 then return end
    self:Open(ItemTooltip,owner)
    ItemTooltip:SetLink(links[1])
    if #links>1 then
        local ru=GetCVar and GetCVar("language.2")=="ru"
        ItemTooltip:AddLine(ru and "Предметы-источники:" or "Source items:","ZoFontGameBold")
        for _,link in ipairs(links)do ItemTooltip:AddLine(link,"ZoFontGame")end
    end
end
function Instance:EnsureBody()
    if self.body then return end
    local wm=WINDOW_MANAGER
    -- InformationTooltip also serves repair buttons, map pins and other UI.
    -- As in KanaStatSources, own the native tooltip and all of its sizing.
    self.root=wm:CreateControlFromVirtual(self.name.."TopLevel",GuiRoot,"TooltipTopLevel")
    self.breakdownTooltip=wm:CreateControlFromVirtual(self.name.."Tooltip",self.root,"ZO_BaseTooltip")
    self.body=wm:CreateControl(self.name,self.breakdownTooltip,CT_CONTROL)
    self.body:SetMouseEnabled(true)
    self.measure=wm:CreateControl(nil,self.body,CT_LABEL)
    self.measure:SetFont(FONT);self.measure:SetHidden(true)
    self.scroll=wm:CreateControlFromVirtual(self.name.."Scroll",self.body,"ZO_ScrollContainer")
    self.scroll:SetAnchor(TOPLEFT,self.body,TOPLEFT,0,0)
    self.scroll:SetAnchor(BOTTOMRIGHT,self.body,BOTTOMRIGHT,0,0)
    self.child=self.scroll:GetNamedChild("Scroll"):GetNamedChild("Child")
    self.child:SetResizeToFitDescendents(false)
    local viewport=self.scroll:GetNamedChild("Scroll")
    self.child:ClearAnchors()
    self.child:SetAnchor(TOPLEFT,viewport,TOPLEFT,0,0)
    self.child:SetAnchor(TOPRIGHT,viewport,TOPRIGHT,-12,0)
    self.body:SetHandler("OnMouseWheel",function(_,delta)ZO_Scroll_OnMouseWheel(self.scroll,delta)end)
    if ZO_PostHookHandler then
        local function hideBody()self.body:SetHidden(true)end
        ZO_PostHookHandler(self.breakdownTooltip,"OnCleared",hideBody)
        ZO_PostHookHandler(self.breakdownTooltip,"OnHide",hideBody)
    end
end
function Instance:Measure(value,width)
    -- Measure text independently of the visible label's previous layout.
    -- GetTextDimensions and native control dimensions are logical UI units.
    self.measure:SetDimensions(width or 0,10000);self.measure:SetText(value)
    local w,h=self.measure:GetTextDimensions()
    return math.ceil(w),math.ceil(h)
end
function Instance:Label(value,x,y,width,font,align,color)
    self.used=self.used+1
    local label=self.labels[self.used]
    if not label then
        label=WINDOW_MANAGER:CreateControl(nil,self.child,CT_LABEL)
        self.labels[self.used]=label;label:SetMouseEnabled(false)
    end
    label:SetHidden(false);label:ClearAnchors()
    local _,height=self:Measure(value,width)
    label:SetFont(font or "ZoFontGame");label:SetDimensions(width,height)
    label:SetColor(unpack(color or WHITE))
    label:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT);label:SetText(value)
    label:SetAnchor(TOPLEFT,self.child,TOPLEFT,x,y)
    return height
end
function Instance:ShowBreakdowns(owner,sections)
    self:EnsureBody()
    local tooltip=self.breakdownTooltip
    self:Open(tooltip,owner)
    self.used=0
    for _,label in ipairs(self.labels)do label:SetHidden(true)end
    self.body:SetHidden(false)
    local paddingWidth,paddingHeight=tooltip:GetResizeToFitPadding()
    local maxWidth=math.max(1,GuiRoot:GetWidth()-64-paddingWidth)
    local y=0
    -- Exactly two columns: item name and its contribution. Bar differences
    -- stay within the value cell, using the same format as the preset summary.
    local rows={}
    local nameWidth,valueWidth=0,0
    for _,data in ipairs(sections)do
        for _,entry in ipairs(data.rows)do
            rows[#rows+1]=entry
            local nw=self:Measure(entry.name)
            local vw=self:Measure(entry.value)
            nameWidth=math.max(nameWidth,nw+2)
            valueWidth=math.max(valueWidth,vw+2)
        end
    end
    -- A short table fills the body. Reserve scrollbar space only when its
    -- content actually exceeds the available height, then reflow once.
    local natural=nameWidth+GAP+valueWidth
    local maxHeight=math.max(1,GuiRoot:GetHeight()-140-paddingHeight)
    local viewport=self.scroll:GetNamedChild("Scroll")
    local function layout(overflow)
        local barWidth=overflow and ZO_SCROLL_BAR_WIDTH or 0
        local padding=overflow and 12 or 0
        viewport:ClearAnchors()
        viewport:SetAnchor(TOPLEFT,self.scroll,TOPLEFT,0,0)
        viewport:SetAnchor(BOTTOMRIGHT,self.scroll,BOTTOMRIGHT,-barWidth,0)
        self.child:ClearAnchors()
        self.child:SetAnchor(TOPLEFT,viewport,TOPLEFT,0,0)
        self.child:SetAnchor(TOPRIGHT,viewport,TOPRIGHT,-padding,0)
        local width=math.min(natural+barWidth+padding,maxWidth)
        self.body:SetDimensions(width,1)
        local inner=math.max(1,width-barWidth-padding)
        local valueCell=math.min(valueWidth,math.max(1,inner-GAP-1))
        local nameCell=math.max(1,inner-valueCell-GAP)
        self.used=0;y=0
        for _,entry in ipairs(rows)do
            local nameHeight=self:Label(entry.name,0,y,nameCell,FONT,TEXT_ALIGN_LEFT,YELLOW)
            local valueHeight=self:Label(entry.value,inner-valueCell,y,valueCell,FONT,TEXT_ALIGN_RIGHT,WHITE)
            local valueLabel=self.labels[self.used]
            valueLabel:ClearAnchors()
            valueLabel:SetAnchor(TOPRIGHT,self.child,TOPRIGHT,0,y)
            local h=math.max(nameHeight,valueHeight)
            y=y+h+6
        end
        y=math.max(0,y-6)
        return width
    end
    local width=layout(false)
    local overflow=y>maxHeight
    if overflow then width=layout(true)end
    self.scroll:GetNamedChild("ScrollBar"):SetHidden(not overflow)
    self.child:SetHeight(y)
    self.body:SetDimensions(width,math.min(y,maxHeight))
    local tooltipWidth,tooltipHeight=width+paddingWidth,math.min(y,maxHeight)+paddingHeight
    tooltip:SetDimensionConstraints(tooltipWidth,tooltipHeight,tooltipWidth,tooltipHeight)
    tooltip:SetDimensions(tooltipWidth,tooltipHeight)
    tooltip:AddControl(self.body)
    -- Like ESO's native tooltip containers, anchor to the cell supplied by
    -- AddControl. Without this, the body renders at the screen origin and the
    -- tooltip backdrop cannot enclose it. Rebind after every ClearLines/reuse.
    self.body:ClearAnchors()
    self.body:SetAnchor(CENTER)
    ZO_Scroll_ResetToTop(self.scroll)
end
function Instance:Show(owner,data)
    self:Hide()
    if not data then return end
    if data.kind=="item" then self:ShowItem(owner,data)
    elseif data.kind=="breakdown" then self:ShowBreakdowns(owner,{data})
    elseif data.kind=="breakdowns" and #data.sections>0 then self:ShowBreakdowns(owner,data.sections)end
end
