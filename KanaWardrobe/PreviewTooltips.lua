local KW=KanaWardrobe
local Tooltips={};KW.PreviewTooltips=Tooltips
local Instance={};Instance.__index=Instance
local nextId=0
function Tooltips.New()
    nextId=nextId+1
    return setmetatable({generation=0,labels={},name="KanaWardrobeSources"..nextId},Instance)
end
local function clear(tooltip)
    (ClearTooltipImmediately or ClearTooltip)(tooltip)
end
function Instance:Hide()
    self.generation=self.generation+1
    if self.tooltip and self.tooltip:GetOwner()==self.owner then clear(self.tooltip)end
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
    self.body=wm:CreateControl(self.name,InformationTooltip,CT_CONTROL)
    self.body:SetMouseEnabled(true)
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
end
function Instance:Label(value,x,y,width,font,align)
    self.used=self.used+1
    local label=self.labels[self.used]
    if not label then
        label=WINDOW_MANAGER:CreateControl(nil,self.child,CT_LABEL)
        self.labels[self.used]=label;label:SetMouseEnabled(false)
    end
    label:SetHidden(false);label:ClearAnchors()
    label:SetFont(font or "ZoFontGame");label:SetDimensions(width,0)
    label:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT);label:SetText(value)
    label:SetAnchor(TOPLEFT,self.child,TOPLEFT,x,y)
    return label:GetHeight()/label:GetScale()
end
function Instance:ShowBreakdowns(owner,sections)
    self:EnsureBody()
    self:Open(InformationTooltip,owner)
    self.used=0
    for _,label in ipairs(self.labels)do label:SetHidden(true)end
    self.body:SetHidden(false)
    local scale=self.body:GetScale()
    local width=math.min(500,GuiRoot:GetWidth()/scale-64)
    -- Resolve the native viewport before measuring text. It can be narrower
    -- than the body, and must be the common basis for both table columns.
    self.body:SetDimensions(width,1)
    local inner=self.child:GetWidth()/self.child:GetScale()
    local y=0
    -- Exactly two columns: item name and its contribution. Bar differences
    -- stay within the value cell, using the same format as the preset summary.
    local rows={}
    local valueWidth=0
    for _,data in ipairs(sections)do
        for _,entry in ipairs(data.rows)do
            rows[#rows+1]=entry
            -- A zero-width native label measures the full unwrapped string;
            -- a pooled/constrained label can under-report the value column.
            self:Label(entry.value,0,0,0)
            valueWidth=math.max(valueWidth,math.ceil(self.labels[self.used]:GetTextWidth())+2)
        end
    end
    -- Reuse these labels for the actual rows; measuring must not add UI text.
    for _,label in ipairs(self.labels)do label:SetHidden(true)end
    self.used=0
    valueWidth=math.min(valueWidth,inner*0.45)
    local nameWidth=inner-valueWidth-16
    for _,entry in ipairs(rows)do
        self:Label(entry.name,0,y,nameWidth)
        local nameLabel=self.labels[self.used]
        self:Label(entry.value,inner-valueWidth,y,valueWidth,nil,TEXT_ALIGN_RIGHT)
        local valueLabel=self.labels[self.used]
        valueLabel:ClearAnchors()
        valueLabel:SetAnchor(TOPRIGHT,self.child,TOPRIGHT,0,y)
        -- Keep a real gap even if the host changes the viewport width. The
        -- full item name wraps within this cell; values stay right-aligned.
        nameLabel:SetAnchor(TOPRIGHT,valueLabel,TOPLEFT,-16,0)
        local h=math.max(nameLabel:GetHeight()/nameLabel:GetScale(),valueLabel:GetHeight()/valueLabel:GetScale())
        y=y+h+6
    end
    y=math.max(0,y-6)
    self.child:SetHeight(y)
    self.body:SetDimensions(width,math.min(y,GuiRoot:GetHeight()/scale-140))
    InformationTooltip:AddControl(self.body)
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
