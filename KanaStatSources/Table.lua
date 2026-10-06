local K=KanaStatSources
local Table={};K.Table=Table
local View={};View.__index=View
local ICON,ICON_GAP,COLUMN_GAP,SECTION_GAP,ROW_GAP=22,6,24,10,3
local function colour(label,api,name,fallback)
    local c=api[name]
    if c then label:SetColor(c:UnpackRGBA()) else label:SetColor((unpack or table.unpack)(fallback)) end
end
function Table.New(api,tooltip)
    local minWidth,_,nativeWidth=tooltip:GetDimensionConstraints()
    local v=setmetatable({api=api,tooltip=tooltip,rows={},offset=0,defaultWidth=math.max(minWidth or 0,nativeWidth and nativeWidth>0 and nativeWidth or 350)},View)
    local function control(parent,kind)return api.WINDOW_MANAGER:CreateControl(nil,parent,kind)end
    v.control=control(tooltip,api.CT_CONTROL);v.control:SetHidden(true)
    local function label(parent,gold)
        local l=control(parent,api.CT_LABEL);l:SetFont('ZoFontHeader')
        colour(l,api,gold and 'ZO_NORMAL_TEXT' or 'ZO_SELECTED_TEXT',gold and {0.77,0.76,0.62,1} or {1,1,1,1})
        return l
    end
    v.makeLabel=label
    v.title=label(v.control,true)
    v.measure=label(v.control);v.measure:SetHidden(true)
    v.measureLine=label(v.control);v.measureLine:SetHidden(true);v.measureLine:SetMaxLineCount(1)
    v.body=control(v.control,api.CT_SCROLL);v.body:SetScrollBounding(api.SCROLL_BOUNDING_CONTAINED)
    v.content=control(v.body,api.CT_CONTROL)
    v.description=label(v.content)
    v.footer=label(v.control,true);v.footer:SetMaxLineCount(1)
    v.footerValue=label(v.control);v.footerValue:SetMaxLineCount(1);v.footerValue:SetHorizontalAlignment(api.TEXT_ALIGN_RIGHT)
    v.hint=label(v.control)
    v.preview=label(v.content,true)
    v.previewValue=label(v.content);v.previewValue:SetHorizontalAlignment(api.TEXT_ALIGN_RIGHT)
    v.body:SetMouseEnabled(true)
    v.body:SetHandler('OnMouseWheel',function(_,delta)v:Scroll(delta)end)
    return v
end
function View:Clear()
    self.control:SetHidden(true);self.inserted=false;self.offset=0;self.layout=nil;self.body:SetVerticalScroll(0)
end
function View:Scroll(delta)
    self.offset=math.max(0,math.min(math.max(0,(self.contentHeight or 0)-(self.bodyHeight or 0)),self.offset-delta*36))
    self.body:SetVerticalScroll(self.offset)
end
function View:Name(row,language)
    local name=row.labelKey and K.Stats.Text(language,row.labelKey) or row.name or (row.source or {}).name or row.label or row.key or ''
    if self.api.zo_strformat then name=self.api.zo_strformat('<<1>>',name) end
    return name
end
function View:Percent(value,language,preserveSmall)
    -- Use the same formatter as ZO_StatEntry_Keyboard:GetDisplayValue for
    -- every critical cell. Its default one fractional digit turns the native
    -- 9.953449% into 10.0%; mixing it with two-digit source cells gave 9.95%.
    if value==0 then value=0 end -- Normalize literal negative zero too.
    local display=value
    if preserveSmall and value~=0 and tonumber(string.format('%.1f',value))==0 then
        -- Preserve a nonzero source that native one-digit formatting would
        -- turn into +/-0.0%. A string argument keeps these extra digits in
        -- zo_strformat; the total continues to use the native numeric path.
        local digits=2
        while digits<15 and math.abs(value)*10^digits<1 do digits=digits+1 end
        display=string.format('%.'..digits..'f',value)
        if tonumber(display)==0 then display=string.format('%.3g',value) end
    end
    if self.api.zo_strformat and self.api.SI_STAT_VALUE_PERCENT then
        return self.api.zo_strformat(self.api.SI_STAT_VALUE_PERCENT,display)
    end
    -- Native grammar expects English separators and performs localization.
    -- Passing -0,002 to it interprets the comma as grouping, yielding -2%.
    if type(display)=='string' then
        if language=='ru' then display=display:gsub('%.',',')end
        return display..'%'
    end
    return K.Stats.Number(value,language,1)..'%'
end
function View:Effect(row,b,language)
    if b.critical then
        if b.critical.verified then
            local rating=K.Core.Finite(row.rawValue) and row.rawValue or row.value
            return self:Percent(rating/b.critical.pointsPerPercent,language,true)
        end
        return K.Stats.Text(language,'unavailable')
    end
    local value=K.Stats.Number(row.value,language)
    if row.operation=='percent' and K.Core.Finite(row.amount) then value=value..' ('..K.Stats.Number(row.amount,language,2)..'%)' end
    return value
end
function View:Measure(text,width,singleLine)
    if text=='' then return 0,0 end
    local probe=singleLine and self.measureLine or self.measure
    -- Measure complete text in a hidden, vertically unconstrained native label.
    -- Reading/resetting a visible label can measure its truncated layout. Native
    -- GetTextDimensions returns UI units; GetStringWidth returns scaled pixels.
    probe:SetDimensions(width or 0,10000);probe:SetText(text)
    local w,h=probe:GetTextDimensions()
    return math.ceil(w),math.ceil(h)
end
function View:NaturalWidth(text)local w=self:Measure(text);return w end
function View:Render(b,language,bounds)
    bounds=bounds or {};local api=self.api
    -- GuiRoot and controls both use logical UI units. Neither previous tooltip
    -- dimensions nor a second UI scale participates in the layout.
    local paddingWidth,paddingHeight=self.tooltip:GetResizeToFitPadding()
    local maxWidth=math.max(1,(bounds.width or api.GuiRoot:GetWidth())-64-paddingWidth)
    local maxHeight=math.max(1,(bounds.height or api.GuiRoot:GetHeight())-64-paddingHeight)
    local title,description=bounds.title or '',bounds.description or ''
    local totalLabel=K.Stats.Text(language,'total')
    local totalValue=b.available and K.Stats.Number(b.total,language) or K.Stats.Text(language,'unavailable')
    if b.critical then
        totalValue=K.Core.Finite(b.critical.chance) and self:Percent(b.critical.chance,language) or K.Stats.Text(language,'unavailable')
    end
    local preview=b.preview and K.Stats.Text(language,'preview') or ''
    local previewValue=b.preview and ('+'..K.Stats.Number(b.preview.amount,language)..' → '..K.Stats.Number(b.preview.total,language)) or ''
    local hint=K.Stats.Text(language,'scroll')
    if self.titleText~=title then self.title:SetText(title);self.titleText=title end
    if self.descriptionText~=description then self.description:SetText(description);self.descriptionText=description end
    self.footer:SetText(totalLabel);self.footerValue:SetText(totalValue)
    self.preview:SetText(preview);self.previewValue:SetText(previewValue);self.hint:SetText(hint)
    local nameWidth=self:NaturalWidth(totalLabel)
    local valueWidth=self:NaturalWidth(totalValue)
    for i,row in ipairs(b.rows or {}) do
        local r=self.rows[i]
        if not r then
            r={labels={self.makeLabel(self.content,true),self.makeLabel(self.content)},icon=api.WINDOW_MANAGER:CreateControl(nil,self.content,api.CT_TEXTURE)}
            r.labels[1]:SetMaxLineCount(1);r.labels[2]:SetMaxLineCount(1);r.labels[2]:SetHorizontalAlignment(api.TEXT_ALIGN_RIGHT)
            r.icon:SetColor(1,1,1,1);self.rows[i]=r
        end
        r.name=self:Name(row,language);r.effect=self:Effect(row,b,language)
        r.labels[1]:SetText(r.name);r.labels[2]:SetText(r.effect)
        nameWidth=math.max(nameWidth,self:NaturalWidth(r.name))
        valueWidth=math.max(valueWidth,self:NaturalWidth(r.effect))
        local icon=row.icon or (row.source or {}).icon
        if icon and icon~='' then r.icon:SetTexture(icon)end
        r.icon:SetHidden(not icon or icon=='')
    end
    -- Fit the longest name, icon, column gap and value with one rounding pixel.
    -- Title and description wrap inside the width required by the two cells.
    -- The native default is a floor; screen bounds are the only upper limit.
    local width=ICON+ICON_GAP+math.ceil(nameWidth)+COLUMN_GAP+math.ceil(valueWidth)+1
    width=math.min(maxWidth,math.max(width,self.defaultWidth-paddingWidth))
    valueWidth=math.min(math.ceil(valueWidth)+1,math.max(1,width-ICON-ICON_GAP-COLUMN_GAP-1))
    nameWidth=math.max(1,width-ICON-ICON_GAP-COLUMN_GAP-valueWidth)
    local old=bounds.keepLayout and self.layout
    -- A changed source width can wrap the title onto more lines. Refit height
    -- for that actual geometry change; unchanged widths keep their viewport.
    if old and old.width~=width then old=nil end
    self.width=width
    local function place(l,parent,x,y,w,h)
        l:ClearAnchors();l:SetDimensions(w,h);l:SetAnchor(api.TOPLEFT,parent,api.TOPLEFT,x,y)
    end
    local function textHeight(l,text,singleLine)
        l:SetHidden(text=='')
        local _,h=self:Measure(text,width,singleLine);return h
    end
    local titleHeight=textHeight(self.title,title)
    local descriptionHeight=textHeight(self.description,description)
    if old and old.width==width then titleHeight=old.titleHeight end
    place(self.title,self.control,0,0,width,titleHeight)
    local headerHeight=titleHeight+(titleHeight>0 and SECTION_GAP or 0)
    -- Description, sources and attribute preview share one scroll viewport.
    -- Long native descriptions or new previews cannot consume the footer or
    -- leave the source list with a zero-height viewport.
    place(self.description,self.content,0,0,width,descriptionHeight)
    local y=descriptionHeight+(descriptionHeight>0 and SECTION_GAP or 0)
    for i=1,#(b.rows or {}) do
        local r=self.rows[i]
        local _,nameHeight=self:Measure(r.name,nameWidth,true)
        local _,valueHeight=self:Measure(r.effect,valueWidth,true)
        local h=math.max(ICON,nameHeight,valueHeight)
        place(r.labels[1],self.content,ICON+ICON_GAP,y,nameWidth,h)
        place(r.labels[2],self.content,width-valueWidth,y,valueWidth,h)
        r.labels[1]:SetHidden(false);r.labels[2]:SetHidden(false)
        place(r.icon,self.content,0,y+(h-ICON)/2,ICON,ICON)
        r.y=y;r.height=h;y=y+h+ROW_GAP
    end
    for i=#(b.rows or {})+1,#self.rows do
        local r=self.rows[i];r.icon:SetHidden(true);for _,l in ipairs(r.labels)do l:SetHidden(true)end
    end
    self.preview:SetHidden(preview=='');self.previewValue:SetHidden(preview=='')
    if preview~='' then
        -- A draft may appear after the outer width was frozen. Its explanatory
        -- text can wrap inside its own two cells; reserve enough width for each
        -- word/number so neither caption nor draft total is truncated.
        local function longestWord(text)
            local w=0;for word in text:gmatch('%S+')do w=math.max(w,self:NaturalWidth(word))end;return w
        end
        local gap=12
        local previewNameWidth=math.min(math.max(longestWord(preview),(width-gap)*0.6),math.max(1,width-gap-longestWord(previewValue)))
        local previewValueWidth=math.max(1,width-previewNameWidth-gap)
        local _,previewNameHeight=self:Measure(preview,previewNameWidth)
        local _,previewValueHeight=self:Measure(previewValue,previewValueWidth)
        local h=math.max(ICON,previewNameHeight,previewValueHeight)
        place(self.preview,self.content,0,y,previewNameWidth,h)
        place(self.previewValue,self.content,width-previewValueWidth,y,previewValueWidth,h)
        y=y+h+ROW_GAP
    end
    self.contentHeight=math.max(0,y-ROW_GAP)
    local _,totalLabelHeight=self:Measure(totalLabel,width-valueWidth-COLUMN_GAP,true)
    local _,totalValueHeight=self:Measure(totalValue,valueWidth,true)
    local totalHeight=math.max(totalLabelHeight,totalValueHeight)
    local footerHeight=totalHeight
    local available=(old and old.height or maxHeight)-headerHeight-footerHeight-SECTION_GAP
    local overflow=self.contentHeight>available
    local hintHeight=textHeight(self.hint,overflow and hint or '')
    -- A refresh can turn a short table into a scrolling one. Keep its fixed
    -- outer size and at least a row of space instead of letting the hint eat
    -- the entire existing viewport.
    if overflow and available-hintHeight-ROW_GAP>=math.min(ICON,self.contentHeight) then
        footerHeight=footerHeight+hintHeight+ROW_GAP;available=available-hintHeight-ROW_GAP
    else hintHeight=0;self.hint:SetHidden(true) end
    self.bodyHeight=math.max(0,old and available or math.min(math.max(ICON,self.contentHeight),available))
    self.height=old and old.height or headerHeight+self.bodyHeight+SECTION_GAP+footerHeight
    self.layout={width=width,nameWidth=nameWidth,valueWidth=valueWidth,titleHeight=titleHeight,height=self.height}
    self.control:SetDimensions(width,self.height)
    place(self.body,self.control,0,headerHeight,width,self.bodyHeight)
    place(self.content,self.body,0,0,width,self.contentHeight)
    local footerY=headerHeight+self.bodyHeight+SECTION_GAP
    place(self.footer,self.control,0,footerY,width-valueWidth-COLUMN_GAP,totalHeight);self.footer:SetHidden(false)
    place(self.footerValue,self.control,width-valueWidth,footerY,valueWidth,totalHeight);self.footerValue:SetHidden(false)
    footerY=footerY+totalHeight+ROW_GAP
    place(self.hint,self.control,0,footerY,width,hintHeight)
    self:Scroll(0);self.control:SetHidden(false)
    local tooltipWidth,tooltipHeight=width+paddingWidth,self.height+paddingHeight
    self.tooltip:SetDimensionConstraints(tooltipWidth,tooltipHeight,tooltipWidth,tooltipHeight)
    self.tooltip:SetDimensions(tooltipWidth,tooltipHeight)
    if not self.inserted then
        self.tooltip:AddControl(self.control);self.control:ClearAnchors();self.control:SetAnchor(api.CENTER);self.inserted=true
    end
end
