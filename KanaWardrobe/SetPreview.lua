local KW = KanaWardrobe
local Preview = {}
local Instance = {}
Instance.__index = Instance
KW.SetPreview = Preview
local nextId = 0
local CARD_WIDTH, GAP, PADDING = 320, 12, 10
local MAX_CARD_WIDTH = 420
local SCREEN_MARGIN = 8

local function text(key, fallback)
    return KW.Strings[key] or fallback
end

local function countText(front, back, maximum)
    if front == back then return string.format("%d/%d", front, maximum) end
    return string.format("I: %d/%d   II: %d/%d", front, maximum, back, maximum)
end

local function barName(front)
    return front and text("SUMMARY_FRONT","Main bar") or text("SUMMARY_BACK","Backup bar")
end

-- Render only preset-relevant set information, never a representative item's layout.
local function addPresetSet(tooltip, itemLink, equipped, extraData)
    local card = tooltip.presetSet
    if not card then return end
    if card.lines then
        local section=tooltip:AcquireSection(tooltip:GetStyle("bodySection"))
        section:AddLine(card.title,tooltip:GetStyle("bodyHeader"))
        for _,line in ipairs(card.lines)do section:AddLine(line,tooltip:GetStyle("bodyDescription"))end
        tooltip:AddSection(section)
        return
    end
    local suppression, refId = ITEM_BONUS_SUPPRESSION_TYPE_NONE, 0
    if extraData and extraData.showSuppression then
        suppression, refId = GetItemSetSuppressionInfo(card.setId)
    end
    local suppressed = suppression ~= ITEM_BONUS_SUPPRESSION_TYPE_NONE
    local section = tooltip:AcquireSection(tooltip:GetStyle("bodySection"))
    local heading=card.setName or ""
    if card.front==card.back then heading=heading.."  |cB9B397"..countText(card.front,card.back,card.max).."|r"end
    section:AddLine(heading, tooltip:GetStyle("bodyHeader"))
    if card.front~=card.back then
        section:AddLine(barName(true).." "..card.front.."/"..card.max.."  ·  "..barName(false).." "..card.back.."/"..card.max,
            tooltip:GetStyle("bodyDescription"))
    end
    if suppressed and GetItemBonusSuppressionName then
        section:AddLine(GetItemBonusSuppressionName(suppression,refId),tooltip:GetStyle("requirementFail"))
    end
    if card.perfected then
        section:AddLine(text("PERFECTED_PARTS", "Perfected parts") .. ": " ..
            countText(card.perfectedFront, card.perfectedBack, card.max), tooltip:GetStyle("bodyDescription"))
    end
    if #card.missingUids > 0 then
        section:AddLine(text("SET_ITEMS_MISSING", "Some preset items are unavailable in the backpack or worn slots."),
            tooltip:GetStyle("requirementFail"))
    end
    for _, bonus in ipairs(card.bonuses) do
        local style = "inactiveBonus"
        if bonus.activeFront or bonus.activeBack then
            style = suppressed and "itemBonusSuppressedDescription" or "activeBonus"
        end
        local prefix = ""
        if bonus.activeFront~=bonus.activeBack then
            prefix=barName(bonus.activeFront)..": "
        end
        section:AddLine(prefix .. bonus.description, tooltip:GetStyle(style), tooltip:GetStyle("bodyDescription"))
    end
    tooltip:AddSection(section)
    tooltip:AddSetRestrictions(card.setId)
    return suppression, refId
end

local function ownStyles()
    local styles = {}
    for name, style in pairs(ZO_TOOLTIP_STYLES) do
        -- Only override fields on individual styles. Nested values include
        -- ZO_ColorDef instances: recursively copying them strips their methods
        -- and breaks native condition/charge bars (UnpackRGBA).
        if type(style) == "table" then
            local owned = {}
            for key, value in pairs(style) do owned[key] = value end
            styles[name] = owned
        else
            styles[name] = style
        end
    end
    -- ESO's Lua layout uses gamepad styles by default; keep the section structure
    -- and color definitions but use readable keyboard fonts in our own namespace.
    for _, style in pairs(styles) do
        if type(style) == "table" then
            if style.fontFace then style.fontFace = "$(MEDIUM_FONT)" end
            if style.fontSize then style.fontSize = 18 end
        end
    end
    styles.tooltip.width = CARD_WIDTH - PADDING * 2
    styles.tooltip.fontFace = "$(MEDIUM_FONT)"
    styles.tooltip.fontSize = 18
    if styles.title then styles.title.fontSize = 20 end
    -- Native bodySection has 30 px above each section and 10 between lines.
    -- Those gamepad spacings are not suitable for a dense keyboard summary.
    styles.bodySection.customSpacing=0
    styles.bodySection.childSpacing=3
    styles.bodySection.paddingTop=0
    styles.bodySection.paddingBottom=0
    styles.bodyHeader.uppercase=false
    styles.bodyHeader.fontSize=20
    styles.bodyHeader.customSpacing=0
    styles.overviewSection={}
    for key,value in pairs(styles.bodySection)do styles.overviewSection[key]=value end
    styles.overviewSection.customSpacing=12
    styles.overviewSection.childSpacing=2
    return styles
end

function Preview.New(parent)
    nextId = nextId + 1
    local self = setmetatable({cards={}, generation=0,name="KanaWardrobeSetPreview" .. nextId}, Instance)
    local wm = WINDOW_MANAGER
    -- GuiRoot is an anchor, not a renderable window for ordinary controls.
    -- The standalone preview needs its own TopLevelControl; embedded previews
    -- can inherit the existing window of their explicit parent.
    if parent and parent ~= GuiRoot then
        self.control = wm:CreateControl(self.name, parent, CT_CONTROL)
    else
        self.control = wm:CreateTopLevelWindow(self.name)
    end
    self.control:SetDrawTier(DT_HIGH)
    self.control:SetMouseEnabled(false)
    self.control:SetClampedToScreen(true)
    self.control:SetHidden(true)
    self.styles = ownStyles()
    local background=wm:CreateControl(self.name.."Background",self.control,CT_BACKDROP)
    background:SetAnchor(TOPLEFT,self.control,TOPLEFT,0,0)
    background:SetAnchor(BOTTOMRIGHT,self.control,BOTTOMRIGHT,0,0)
    background:SetCenterColor(0.025,0.025,0.03,0.97)
    background:SetEdgeColor(0.35,0.32,0.25,1)
    background:SetMouseEnabled(false)
    self.background=background
    self.headingDivider=wm:CreateControl(self.name.."HeadingDivider",self.control,CT_TEXTURE)
    self.headingDivider:SetColor(0.57,0.53,0.39,0.65)
    self.headingDivider:SetDrawLayer(DL_CONTROLS)
    self.headingDivider:SetMouseEnabled(false);self.headingDivider:SetHidden(true)
    self.title = wm:CreateControl(self.name .. "Title", self.control, CT_LABEL)
    self.title:SetAnchor(TOPLEFT, self.control, TOPLEFT, PADDING, PADDING)
    self.title:SetFont("ZoFontWinH4")
    self.title:SetText(text("PRESET_SETS", "Preset sets"))
    self.closeButton=wm:CreateControlFromVirtual(self.name.."Close",self.control,"ZO_CloseButton")
    self.closeButton:SetAnchor(TOPRIGHT,self.control,TOPRIGHT,-8,8)
    self.closeButton:SetDimensions(28,28)
    self.closeButton:SetHandler("OnClicked",function()self:Close()end)
    self.closeButton:SetHidden(true)
    self.message = wm:CreateControl(self.name .. "Message", self.control, CT_LABEL)
    self.message:SetAnchor(TOPLEFT, self.title, BOTTOMLEFT, 0, 4)
    self.message:SetFont("ZoFontGame")
    self.scroll = wm:CreateControlFromVirtual(self.name .. "Scroll", self.control, "ZO_ScrollContainer")
    -- Only cards and the scrollbar receive input. Blank cells of the layout must
    -- not block the inventory underneath this floating preview.
    self.scroll:GetNamedChild("Scroll"):SetMouseEnabled(false)
    self.child = self.scroll:GetNamedChild("Scroll"):GetNamedChild("Child")
    self.child:SetResizeToFitDescendents(false)
    return self
end

function Instance:CreateBlock(name,styles)
    local wm = WINDOW_MANAGER
    local control = wm:CreateControl(name, self.child, CT_CONTROL)
    control:SetMouseEnabled(true)
    control:SetHandler("OnMouseWheel", function(_, delta) ZO_Scroll_OnMouseWheel(self.scroll, delta) end)
    local tooltip = wm:CreateControlFromVirtual(name .. "Tooltip", control, "ZO_Tooltip")
    tooltip:SetAnchor(TOPLEFT, control, TOPLEFT, PADDING, PADDING)
    ZO_Tooltip:Initialize(tooltip, styles, "tooltip")
    tooltip:SetClearOnHidden(false)
    return {control=control,tooltip=tooltip}
end
function Instance:AcquireCard(index)
    if not self.cards[index] then
        self.cards[index]=self:CreateBlock(self.name.."Card"..index,self.styles)
    end
    return self.cards[index]
end
local function traitText(entry)
    if entry.front==entry.back then return entry.name..": "..entry.front end
    local parts={}
    if entry.front>0 then parts[#parts+1]=barName(true).." "..entry.front end
    if entry.back>0 then parts[#parts+1]=barName(false).." "..entry.back end
    return entry.name..": "..table.concat(parts," · ")
end
local function enchantLines(summary)
    local common,front,back={},{},{}
    for _,entry in ipairs(summary.enchants or {})do
        local f,b=entry.descriptionFront,entry.descriptionBack
        if f and f==b then common[#common+1]=f
        else
            if f then front[#front+1]=f end
            if b then back[#back+1]=b end
        end
    end
    return common,front,back
end
function Instance:LayoutOverview(summary,width)
    if not self.overview then
        self.overviewStyles=ownStyles()
        self.overview=self:CreateBlock(self.name.."Overview",self.overviewStyles)
    end
    self.overviewStyles.tooltip.width=width-PADDING*2
    local block=self.overview;local tooltip=block.tooltip
    block.control:SetWidth(width);block.control:ClearAnchors()
    block.control:SetAnchor(TOPLEFT,self.child,TOPLEFT,0,0)
    tooltip:Reset()
    local armor={}
    for _,kind in ipairs({ARMORTYPE_LIGHT or 1,ARMORTYPE_MEDIUM or 2,ARMORTYPE_HEAVY or 3})do
        local n=(summary.armor or {})[kind]
        if n and n>0 then armor[#armor+1]=string.format("%s: %d",GetString("SI_ARMORTYPE",kind),n)end
    end
    local hasContent=false
    local function section(title,lines)
        if #lines==0 then return end
        local part=tooltip:AcquireSection(tooltip:GetStyle(hasContent and "overviewSection" or "bodySection"))
        part:AddLine(title,tooltip:GetStyle("bodyHeader"))
        for _,line in ipairs(lines)do part:AddLine(line,tooltip:GetStyle("bodyDescription"))end
        tooltip:AddSection(part)
        hasContent=true
    end
    if summary.overviewLines then
        section(text("SUMMARY_COMPOSITION","Composition"),summary.overviewLines)
    else
        if #armor>0 then section(text("SUMMARY_ARMOR","Armor"),{table.concat(armor,"   ·   ")})end
        local common,front,back=enchantLines(summary)
        section(text("SUMMARY_ENCHANTS","Enchantments"),common)
        section(text("SUMMARY_ENCHANTS","Enchantments").." · "..barName(true),front)
        section(text("SUMMARY_ENCHANTS","Enchantments").." · "..barName(false),back)
        local traits={}
        for _,entry in ipairs(summary.traits or {})do traits[#traits+1]=traitText(entry)end
        section(text("SUMMARY_TRAITS","Traits").." · "..text("SUMMARY_ITEMS","items"),traits)
    end
    block.control:SetHidden(not hasContent)
    local height=hasContent and tooltip:GetHeight()/self.control:GetScale()+PADDING*2 or 0
    block.control:SetHeight(height)
    return height
end

function Instance:SetLayoutChangedCallback(callback)
    self.onLayoutChanged=callback
end
function Instance:SetCloseCallback(callback)
    self.onClose=callback
end
function Instance:SetSafeArea(bounds)
    self.safeAreaSet=true
    local key=bounds and table.concat({bounds.x,bounds.y,bounds.width,bounds.height,bounds.scale},":") or "unavailable"
    if self.safeAreaKey==key then return end
    self.safeAreaKey=key
    self.safeArea=bounds and {x=bounds.x,y=bounds.y,width=bounds.width,height=bounds.height,scale=bounds.scale} or nil
    if self.visible and self.summary then self:Refresh(self.summary)end
end
function Instance:Close()
    if self.onClose then self.onClose()end
    self:Hide()
end

function Instance:Show(anchor, summary, boundary)
    self.generation=self.generation+1
    local opening = not self.visible
    self.anchor = anchor
    self.panelMode = boundary~=nil
    self.boundary = boundary or anchor
    self.visible = true
    self.control:SetHidden(false)
    self:Refresh(summary)
    ZO_Scroll_ResetToTop(self.scroll)
    -- Animate only opening. Moving between rows or refreshing geometry must
    -- not blank out an already readable description or restart its fade.
    if opening and not self.control:IsHidden() and ZO_AlphaAnimation then
        self.appearance = self.appearance or ZO_AlphaAnimation:New(self.control)
        self.appearance:FadeIn(0,160,ZO_ALPHA_ANIMATION_OPTION_FORCE_ALPHA)
    end
end

function Instance:Hide()
    self.generation=self.generation+1
    if self.appearance then
        self.appearance:Stop(ZO_ALPHA_ANIMATION_OPTION_PREVENT_CALLBACK)
        self.control:SetAlpha(1)
    end
    self.visible = false
    self.control:SetHidden(true)
    for _, card in ipairs(self.cards) do
        card.tooltip:Reset()
        card.tooltip.presetSet = nil
        card.control:SetHidden(true)
    end
    if self.overview then self.overview.control:SetHidden(true)end
    if self.effectView then self.effectView:Hide()end
    self.summary = nil
    if self.onLayoutChanged then self.onLayoutChanged()end
end

-- The list controller owns the hover timers and calls this during
-- delayed close, so crossing the small gap does not dismiss the cards.
function Instance:ContainsMouse()
    if not self.visible then return false end
    if self.effectView and self.effectView.tooltips and self.effectView.tooltips:ContainsMouse()then return true end
    if self.panelMode and MouseIsOver(self.control)then return true end
    if self.effectView and not self.effectView.control:IsHidden() and MouseIsOver(self.effectView.control)then return true end
    if self.overview and not self.overview.control:IsHidden() and MouseIsOver(self.overview.control)then return true end
    for index = 1, #(self.displayCards or {}) do
        if MouseIsOver(self.cards[index].control) then return true end
    end
    return MouseIsOver(self.scroll:GetNamedChild("ScrollBar"))
end

function Instance:Refresh(summary)
    self.summary = summary
    if summary.effects or summary.description then return self:RefreshEffects(summary)end
    self.closeButton:SetHidden(true)
    self.background:SetHidden(false);self.headingDivider:SetHidden(true)
    if self.surface then self.surface:SetHidden(true)end
    self.title:SetFont("ZoFontWinH4");self.control:SetDrawTier(DT_HIGH)
    if self.effectView then self.effectView:Hide()end
    local models=summary.sets
    self.displayCards=models
    -- Geometry getters include control scale. Layout dimensions and anchor
    -- offsets use local units, as in ESO's own scroll thumb sizing.
    local scale = self.control:GetScale()
    local screenWidth, screenHeight = GuiRoot:GetWidth() / scale, GuiRoot:GetHeight() / scale
    local screenLeft, screenTop = GuiRoot:GetLeft(), GuiRoot:GetTop()
    local anchor = self.anchor or GuiRoot
    local boundary = self.boundary or anchor
    local anchorLeft = ((boundary:GetLeft() or screenLeft) - screenLeft) / scale
    local anchorRight = ((boundary:GetRight() or screenLeft) - screenLeft) / scale
    local gutter = ZO_SCROLL_BAR_WIDTH
    local hasOverview=summary.overviewLines~=nil or next(summary.armor or {})~=nil or #(summary.enchants or {})>0 or #(summary.traits or {})>0
    local blockCount=math.max(1,#models+(hasOverview and 1 or 0))
    local rightSpace = screenWidth - SCREEN_MARGIN - anchorRight - GAP
    local leftSpace = anchorLeft - GAP - SCREEN_MARGIN
    local onRight = rightSpace >= CARD_WIDTH + gutter or rightSpace >= leftSpace
    local widthAvailable = math.max(1,onRight and rightSpace or leftSpace)
    -- If neither side can contain even a readable column, clamp a single
    -- column to the screen. Otherwise use every available column before scroll.
    if widthAvailable<CARD_WIDTH+gutter then widthAvailable=math.min(CARD_WIDTH+gutter,screenWidth-SCREEN_MARGIN*2)end
    local columns=math.min(blockCount,math.max(1,math.floor((widthAvailable-gutter+GAP)/(CARD_WIDTH+GAP))))
    self.title:SetText(summary.name and summary.name~="" and summary.name or text("PRESET_SUMMARY","Preset summary"))
    local message = ""
    if summary.complete == false then message = text("SET_DATA_UNAVAILABLE", "Set information is unavailable.")
    elseif #summary.sets == 0 then message = text("NO_PRESET_SETS", "This preset has no set items.")
    elseif summary.availableToEquip == false then message = text("SET_ITEMS_MISSING", "Some preset items cannot currently be equipped.") end
    self.message:SetText(message)
    self.message:SetHidden(message == "")
    local function layout(columnCount,cardWidth)
        local width=columnCount*cardWidth+(columnCount-1)*GAP+gutter
        self.styles.tooltip.width=cardWidth-PADDING*2
        self.title:SetWidth(width-PADDING*2)
        self.message:SetWidth(width-PADDING*2)
        local headerHeight = self.title:GetHeight() / scale + PADDING*2
        if message ~= "" then headerHeight = headerHeight + 4 + self.message:GetHeight() / scale end
        self.scroll:ClearAnchors()
        self.scroll:SetAnchor(TOPLEFT, self.control, TOPLEFT, 0, headerHeight)
        self.scroll:SetAnchor(BOTTOMRIGHT, self.control, BOTTOMRIGHT, 0, 0)
        -- Independent column heights prevent a tall set from leaving empty rows
        -- beneath every shorter block. Keep the overview first in reading order.
        local heights={}
        for col=1,columnCount do heights[col]=0 end
        local overviewHeight=self:LayoutOverview(summary,cardWidth)
        if overviewHeight>0 then heights[1]=overviewHeight+GAP end
        for index, model in ipairs(models) do
            local col=1
            for candidate=2,columnCount do if heights[candidate]<heights[col]then col=candidate end end
            local card = self:AcquireCard(index)
            card.control:SetHidden(false)
            card.control:SetWidth(cardWidth)
            card.control:ClearAnchors()
            card.control:SetAnchor(TOPLEFT, self.child, TOPLEFT, (col-1)*(cardWidth+GAP), heights[col])
            card.tooltip:Reset()
            card.tooltip.presetSet = model
            card.tooltip.suppression,card.tooltip.suppressionRef = addPresetSet(card.tooltip,nil,false,{showSuppression=true})
            local cardHeight = card.tooltip:GetHeight() / scale + PADDING * 2
            card.control:SetHeight(cardHeight)
            heights[col]=heights[col]+cardHeight+GAP
        end
        for index = #models + 1, #self.cards do
            self.cards[index].tooltip:Reset()
            self.cards[index].tooltip.presetSet = nil
            self.cards[index].control:SetHidden(true)
        end
        local contentHeight=0
        for _,value in ipairs(heights)do contentHeight=math.max(contentHeight,value-GAP)end
        self.child:SetDimensions(width-gutter,math.max(1,contentHeight))
        return width,contentHeight+headerHeight,headerHeight
    end
    local function fullColumnWidth(n)return (widthAvailable-gutter-(n-1)*GAP)/n end
    local cardWidth=math.min(MAX_CARD_WIDTH,fullColumnWidth(columns))
    local width,requiredHeight,headerHeight=layout(columns,cardWidth)
    local limit=screenHeight-SCREEN_MARGIN*2
    -- Long descriptions can need more width than the usual reading column.
    -- Try the remaining horizontal space and fewer/wider columns before scroll.
    if requiredHeight>limit then
        local best={columns=columns,cardWidth=cardWidth,height=requiredHeight}
        for n=columns,1,-1 do
            local candidateWidth=fullColumnWidth(n)
            local _,candidateHeight=layout(n,candidateWidth)
            if candidateHeight<best.height then best={columns=n,cardWidth=candidateWidth,height=candidateHeight}end
            if candidateHeight<=limit then break end
        end
        width,requiredHeight,headerHeight=layout(best.columns,best.cardWidth)
    end
    local height=math.min(limit,math.max(80,requiredHeight))
    self.needsScroll=requiredHeight>height
    local left=onRight and (anchorRight+GAP) or (anchorLeft-GAP-width)
    left=math.max(SCREEN_MARGIN,math.min(left,screenWidth-SCREEN_MARGIN-width))
    -- Clamp using the final content height, so a short preview stays beside its row.
    local top = math.max(SCREEN_MARGIN, math.min(((anchor:GetTop() or screenTop) - screenTop) / scale,
        screenHeight - SCREEN_MARGIN - height))
    self.control:ClearAnchors()
    self.control:SetDimensions(width, height)
    self.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
end

function Instance:RefreshEffects(summary)
    self.background:SetHidden(true)
    self.surface=self.surface or KW.SoftPanel.New(self.control,self.name.."Surface")
    self.surface:SetHidden(false)
    self.headingDivider:SetHidden(false)
    self.control:SetDrawTier(DT_MEDIUM)
    self.title:SetFont("ZoFontHeader4")
    if self.title.SetMaxLineCount then self.title:SetMaxLineCount(2)end
    if self.message.SetMaxLineCount then self.message:SetMaxLineCount(1)end
    self.closeButton:SetHidden(false)
    for _,card in ipairs(self.cards)do card.control:SetHidden(true)end
    if self.overview then self.overview.control:SetHidden(true)end
    self.displayCards={}
    local language=GetCVar and GetCVar("language.2") or "en"
    local data=summary.effects and KW.EffectModel.Present(summary,language)
        or {metrics={},sets={},rows={},details={},barGroups={},specials={}}
    data.description=summary.description
    if not self.effectView then self.effectView=KW.SummaryView.New(self.child,self.name.."Effects",self.scroll)end
    local scale=self.control:GetScale()
    local sw,sh=GuiRoot:GetWidth()/scale,GuiRoot:GetHeight()/scale
    local sx,sy=GuiRoot:GetLeft(),GuiRoot:GetTop()
    local area=self.safeArea
    if (summary.description and not self.safeAreaSet)
        or (self.safeAreaSet and (not area or area.width<96 or area.height<80))then
        self.geometryHidden=true;self.control:SetHidden(true)
        if self.appearance then self.appearance:Stop(ZO_ALPHA_ANIMATION_OPTION_PREVENT_CALLBACK)end
        if self.effectView then self.effectView:Hide()end
        return
    end
    self.geometryHidden=nil;self.control:SetHidden(false)
    local anchor=self.anchor or GuiRoot;local boundary=self.boundary or anchor
    local al,ar=(boundary:GetLeft()-sx)/scale,(boundary:GetRight()-sx)/scale
    local gap=self.panelMode and 36 or GAP
    local right,left=sw-ar-gap-SCREEN_MARGIN,al-gap-SCREEN_MARGIN
    local onRight=self.panelMode or right>=720 or right>=left
    local available=onRight and right or left
    -- This panel has its own bounded surface, with a clear gap before the bag.
    -- Narrow spaces wrap/scroll; they must never fall back across the bag.
    if self.panelMode and not self.safeAreaSet then
        local bagLeft=KW.UI and KW.UI.InventoryLeftEdge and KW.UI.InventoryLeftEdge()
        if not bagLeft and ZO_PlayerInventory and not ZO_PlayerInventory:IsHidden()then bagLeft=ZO_PlayerInventory:GetLeft()end
        if bagLeft then available=math.min(available,(bagLeft-sx)/scale-ar-gap-24)end
    elseif available<320 then available=sw-2*SCREEN_MARGIN end
    local width=math.max(96,math.min(1140,available))
    if area then width=math.min(1140,area.width*area.scale/scale)end
    self.title:SetWidth(width-52);self.title:SetText((zo_strupper or string.upper)(summary.name or text("PRESET_SUMMARY","Preset summary")))
    self.title:ClearAnchors();self.title:SetAnchor(TOPLEFT,self.control,TOPLEFT,16,10)
    local message=""
    if summary.complete==false then message=message..(message~="" and " · " or "")..text("SET_DATA_UNAVAILABLE","Incomplete data")
    elseif summary.availableToEquip==false then message=message..(message~="" and " · " or "")..text("SET_ITEMS_MISSING","Some items are unavailable")end
    self.message:SetWidth(width-32);self.message:SetText(message);self.message:SetHidden(message=="")
    local dividerY=math.max(47,15+self.title:GetHeight()/scale)
    self.headingDivider:ClearAnchors()
    self.headingDivider:SetAnchor(TOPLEFT,self.control,TOPLEFT,16,dividerY)
    self.headingDivider:SetDimensions(width-ZO_SCROLL_BAR_WIDTH-32,1)
    local header=dividerY+16
    self.message:ClearAnchors();self.message:SetAnchor(TOPLEFT,self.control,TOPLEFT,16,header)
    if message~="" then header=header+self.message:GetHeight()/scale+8 end
    if area and header+13>=area.height*area.scale/scale then
        self.geometryHidden=true;self.control:SetHidden(true)
        if self.appearance then self.appearance:Stop(ZO_ALPHA_ANIMATION_OPTION_PREVENT_CALLBACK)end
        self.effectView:Hide();return
    end
    self.scroll:ClearAnchors()
    self.scroll:SetAnchor(TOPLEFT,self.control,TOPLEFT,0,header)
    self.scroll:SetAnchor(BOTTOMRIGHT,self.control,BOTTOMRIGHT,0,-12)
    local contentWidth=width-ZO_SCROLL_BAR_WIDTH
    local contentHeight=self.effectView:Layout(data,contentWidth,language)
    self.child:SetDimensions(contentWidth,contentHeight)
    local needed=header+contentHeight+12
    local panelTop=area and area.y*area.scale/scale or math.max(SCREEN_MARGIN,(boundary:GetTop()-sy)/scale)
    local height
    if area then height=math.min(area.height*area.scale/scale,needed)
    elseif self.panelMode then
        height=math.max(1,math.min(sh-64-panelTop,needed))
    else height=math.min(sh-2*SCREEN_MARGIN,needed)end
    self.needsScroll=needed>height
    local x=onRight and ar+gap or al-gap-width
    x=math.max(SCREEN_MARGIN,math.min(x,sw-SCREEN_MARGIN-width))
    local y=self.panelMode and panelTop or math.max(SCREEN_MARGIN,math.min((anchor:GetTop()-sy)/scale,sh-SCREEN_MARGIN-height))
    if area then x=area.x*area.scale/scale;y=panelTop end
    self.control:ClearAnchors();self.control:SetDimensions(width,height)
    self.control:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,x,y)
    self.surface:Layout(width,height)
    if self.onLayoutChanged then self.onLayoutChanged()end
end

-- Core may expose this via /kw previewtest only while KW.Debug == true.
-- Supply a real five-piece SetCardModel for the bonus descriptions.
function Instance:ShowDiagnostic(anchor, model)
    if KW.Debug ~= true then return false end
    local summary = {sets={}, complete=true, availableToEquip=true}
    for _, count in ipairs({3, 5}) do
        local card = KW.Copy(model)
        card.front, card.back = count, count
        card.perfectedFront, card.perfectedBack = count, count
        for _, bonus in ipairs(card.bonuses) do
            bonus.activeFront, bonus.activeBack = count >= bonus.required, count >= bonus.required
        end
        summary.sets[#summary.sets + 1] = card
    end
    self:Show(anchor, summary)
    return true
end
