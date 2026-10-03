local KW=KanaWardrobe
local View={};KW.SummaryView=View
local Instance={};Instance.__index=Instance
local PAD,GAP,ROW=16,24,26
local function text(key,en,ru)
    return KW.Strings[key] or (GetCVar and GetCVar("language.2")=="ru" and ru or en)
end
local function colored(value,color)return color and ("|c"..color..value.."|r") or value end
local function separateDamage(entries)
    local ordinary,damage={},{}
    for _,entry in ipairs(entries)do
        local target=entry.category=="damage" and damage or ordinary
        target[#target+1]=entry
    end
    return ordinary,damage
end
function View.New(parent,name,scroll)
    local self=setmetatable({parent=parent,name=name,controls={},pools={},counts={},scroll=scroll},Instance)
    self.control=WINDOW_MANAGER:CreateControl(name,parent,CT_CONTROL)
    self.control:SetMouseEnabled(true)
    self.control:SetHandler("OnMouseWheel",function(_,delta)ZO_Scroll_OnMouseWheel(scroll,delta)end)
    self.tooltips=KW.PreviewTooltips and KW.PreviewTooltips.New()
    return self
end
function Instance:Acquire(kind)
    self.counts[kind]=(self.counts[kind] or 0)+1
    local index=self.counts[kind]
    local pool=self.pools[kind] or {};self.pools[kind]=pool
    local c=pool[index]
    if not c then
        c={kind=kind,control=WINDOW_MANAGER:CreateControl(nil,self.control,kind)}
        pool[index]=c;self.controls[#self.controls+1]=c
        c.control:SetMouseEnabled(false)
    end
    c.control:SetMouseEnabled(false)
    c.control:SetAlpha(1)
    if c.control.SetColor then c.control:SetColor(1,1,1,1)end
    c.control:SetHandler("OnMouseEnter",nil);c.control:SetHandler("OnMouseExit",nil)
    c.control:SetHandler("OnMouseWheel",nil)
    c.control:SetHidden(false);c.control:ClearAnchors()
    return c.control
end
function Instance:Bind(control,data)
    if not self.tooltips or not data then return end
    control:SetMouseEnabled(true)
    control:SetHandler("OnMouseEnter",function()self:HideSkillTooltip();self.tooltips:Show(control,data)end)
    control:SetHandler("OnMouseExit",function()self.tooltips:Leave(control)end)
    control:SetHandler("OnMouseWheel",function(_,delta)self.tooltips:Hide();ZO_Scroll_OnMouseWheel(self.scroll,delta)end)
end
function Instance:Hide()
    self:HideSkillTooltip()
    if self.tooltips then self.tooltips:Hide()end
    self.control:SetHidden(true)
end
function Instance:HideSkillTooltip()
    local tooltip=self.skillTooltip
    if tooltip and tooltip:GetOwner()==self.skillOwner then
        (ClearTooltipImmediately or ClearTooltip)(tooltip)
    end
    self.skillTooltip=nil;self.skillOwner=nil
end

function Instance:ShowSavedTooltip(control,entry,assignment)
    self:HideSkillTooltip()
    if self.tooltips then self.tooltips:Hide()end
    local tooltip=entry.kind=='points' and InformationTooltip or SkillTooltip or InformationTooltip
    if not tooltip then return end
    InitializeTooltip(tooltip,control,TOPLEFT,5,-5,TOPRIGHT)
    self.skillTooltip=tooltip;self.skillOwner=control
    local target=entry.tooltip or {}
    if entry.available then
        if target.kind=='crafted' or (assignment and not entry.state)then
            local id=target.abilityId or target.progression:GetAbilityId()
            tooltip:SetAbilityId(id)
        elseif target.kind=='active' then
            tooltip:SetActiveSkill(entry.category,entry.lineIndex,entry.skillIndex,target.morph,
                entry.state.purchased,false,false,0,false,false,false,false)
        elseif target.kind=='passive' then
            tooltip:SetPassiveSkill(entry.category,entry.lineIndex,entry.skillIndex,target.rank,
                entry.state.rank,0,false)
        end
    else
        tooltip:AddLine(entry.name or "","ZoFontGameBold")
    end
    local explanation
    if entry.kind=='unchanged' then explanation=text('DESCRIPTION_UNCHANGED','Do not change this slot','Не менять этот слот')
    elseif entry.kind=='empty' then explanation=text('DESCRIPTION_CLEAR','Clear this slot','Очистить этот слот')
    elseif target.inactive then explanation=text('DESCRIPTION_DISABLED','Disabled in this preset','Выключен в этом пресете')
    elseif assignment then explanation=text('DESCRIPTION_ASSIGNED','Assigned in this preset','Назначен в этом пресете')
    else explanation=text('DESCRIPTION_ENABLED','Enabled in this preset','Включён в этом пресете')end
    if entry.kind~='points' then tooltip:AddLine(explanation,"ZoFontGame")end
    if entry.unresolvedReason then
        local reason=entry.unresolvedReason.details or {}
        local reasons={
            missingCatalogue={'Skill catalogue unavailable','Каталог навыков недоступен'},
            missingSkill={'Saved skill not found','Сохранённый навык не найден'},
            lineUnavailable={'Skill line unavailable','Ветка навыка недоступна'},
            immutableSkill={'This skill cannot be changed','Этот навык нельзя изменить'},
            missingProgression={'Saved variant unavailable','Сохранённый вариант недоступен'},
            missingMetadata={'Skill data unavailable','Данные навыка недоступны'},
            craftedNotReady={'Crafted ability unavailable','Навык начертания недоступен'},
        }
        local wording=reasons[reason.reason] or {'Skill unavailable','Навык недоступен'}
        tooltip:AddLine(text('DESCRIPTION_REASON_'..(reason.reason or ''),wording[1],wording[2])
            ..(reason.name and ': '..reason.name or ''),"ZoFontGame")
    end
end

function Instance:SkillIcon(entry,x,y,size,assignment)
    local icon=self:Acquire(CT_TEXTURE)
    local texture=entry.icon or "EsoUI/Art/Icons/icon_missing.dds"
    if entry.kind=='empty' then texture="EsoUI/Art/ActionBar/abilityFrame64_up.dds"
    elseif entry.kind=='unchanged' then texture="EsoUI/Art/ActionBar/abilityInset.dds"end
    icon:SetTexture(texture);icon:SetColor(1,1,1,1)
    icon:SetAlpha(entry.tooltip and entry.tooltip.inactive and .45 or 1)
    icon:SetDimensions(size,size);icon:SetAnchor(TOPLEFT,self.control,TOPLEFT,x,y)
    -- Keep decoration in the texture layer; native skill slots receive mouse
    -- input on a control above it. Otherwise the full-size scroll/content
    -- control can win hit testing over a background-layer texture.
    local hit=self:Acquire(CT_CONTROL)
    hit:SetDimensions(size,size);hit:SetAnchor(TOPLEFT,self.control,TOPLEFT,x,y)
    hit:SetDrawLayer(DL_CONTROLS);hit:SetDrawLevel(1)
    hit:SetMouseEnabled(true);icon.hitTarget=hit
    hit:SetHandler('OnMouseEnter',function()self:ShowSavedTooltip(hit,entry,assignment)end)
    hit:SetHandler('OnMouseExit',function()if self.skillOwner==hit then self:HideSkillTooltip()end end)
    hit:SetHandler('OnMouseWheel',function(_,delta)self:HideSkillTooltip();ZO_Scroll_OnMouseWheel(self.scroll,delta)end)
    local number=entry.state and entry.state.kind=='passive' and entry.state.rank
    local marker=entry.kind=='empty' and '×' or entry.kind=='unchanged' and '—' or number and tostring(number)
    if marker then
        local label=self:Acquire(CT_LABEL);label:SetFont('ZoFontGameSmall')
        label:SetText(marker);label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        label:SetWidth(size);label:SetAnchor(TOPLEFT,self.control,TOPLEFT,x,y+size-18)
    end
    local list=assignment and self.barIcons or self.skillIcons;list[#list+1]=icon
end

-- Saved allocations are absolute counts, including zero, aligned as one group.
-- Measure controls before placing them; pooled widths must not constrain text.
function Instance:PrepareAttributes(attributes,inner)
    if not attributes then return nil,0 end
    local resources={
        {'health','FF6666','EsoUI/Art/CharacterWindow/characterWindow_healthIcon.dds'},
        {'magicka','66AAFF','EsoUI/Art/CharacterWindow/characterWindow_magickaIcon.dds'},
        {'stamina','66CC66','EsoUI/Art/CharacterWindow/characterWindow_staminaIcon.dds'},
    }
    local entries,total={},0
    for index,resource in ipairs(resources)do
        local label=self:Acquire(CT_LABEL)
        label:SetFont('ZoFontGame');label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        label:SetDimensions(0,0);label:SetText(tostring(attributes[resource[1]]))
        local width=math.ceil(label:GetTextWidth())+2
        label:SetWidth(width)
        label:SetColor(tonumber(resource[2]:sub(1,2),16)/255,tonumber(resource[2]:sub(3,4),16)/255,tonumber(resource[2]:sub(5,6),16)/255,1)
        entries[index]={label=label,icon=resource[3],width=26+width}
        total=total+entries[index].width+(index>1 and 16 or 0)
    end
    local gap,iconSize=16,22
    if total>inner then
        gap=6
        local textWidth=total-2*16-3*26
        iconSize=math.max(0,math.min(22,math.floor((inner-textWidth-2*gap)/3)-4))
        total=2*gap
        for _,entry in ipairs(entries)do
            entry.width=entry.width-26+iconSize+4
            total=total+entry.width
        end
    end
    for _,entry in ipairs(entries)do entry.iconSize=iconSize;entry.gap=gap end
    return entries,total
end
function Instance:LayoutAttributes(attributes,entries,total,y,inner)
    if not entries then return 0 end
    local x,height=PAD+inner-total,ROW
    for _,entry in ipairs(entries)do
        local icon=self:Acquire(CT_TEXTURE)
        icon:SetTexture(entry.icon);icon:SetColor(1,1,1,1)
        icon:SetDimensions(entry.iconSize,entry.iconSize);icon:SetAnchor(TOPLEFT,self.control,TOPLEFT,x,y+2+(22-entry.iconSize)/2)
        entry.label:SetAnchor(TOPLEFT,self.control,TOPLEFT,x+entry.iconSize+4,y+2)
        if attributes.unspentAtCapture~=nil then
            local points={name=text('DESCRIPTION_UNSPENT','Unspent points at capture','Свободные очки при сохранении')..': '..attributes.unspentAtCapture,
                kind='points',available=false}
            icon:SetMouseEnabled(true);icon:SetHandler('OnMouseEnter',function()self:ShowSavedTooltip(icon,points,false)end)
            icon:SetHandler('OnMouseExit',function()self:HideSkillTooltip()end)
        end
        height=math.max(height,entry.label:GetHeight()/self.control:GetScale()+2)
        x=x+entry.width+entry.gap
    end
    return height
end

function Instance:LayoutSkills(description,y,inner)
    if not description then return y,false end
    local visible=false
    if description.bars then
        visible=true
        y=y+self:Label(text('DESCRIPTION_BARS','Bars','Панели'),PAD,y,inner,'ZoFontGameBold')+4
        local size=math.min(32,inner)
        local stride=size+4
        local barWidth=6*size+5*4
        local x,top,bottom=PAD,y,y
        for _,bar in ipairs({'front','back','werewolf'})do
            if description.bars[bar] then
                if x>PAD and x+barWidth>PAD+inner then x=PAD;top=bottom+8 end
                local ix,iy=x,top
                for _,entry in ipairs(description.bars[bar])do
                    if ix>x and ix+size>PAD+inner then ix=x;iy=iy+stride end
                    self:SkillIcon(entry,ix,iy,size,true);ix=ix+stride
                end
                bottom=math.max(bottom,iy+size)
                x=x+barWidth+GAP
            end
        end
        y=bottom+12
    end
    for _,group in ipairs({{'enabled','DESCRIPTION_ENABLED_TALENTS','Enabled talents','Включённые таланты'},
        {'disabled','DESCRIPTION_DISABLED_TALENTS','Disabled talents','Выключенные таланты'}})do
        local entries=description[group[1]] or {}
        if #entries>0 then
            visible=true
            y=y+self:Label(text(group[2],group[3],group[4]),PAD,y,inner,'ZoFontGameBold')+4
            local x,index,rowHeight=PAD,1,0
            while index<=#entries do
                -- BuildDescription already orders skills by native skill line.
                -- Each branch is atomic. On exceptionally narrow surfaces,
                -- size its icons uniformly so even a long branch stays intact.
                local first=entries[index]
                local last=index
                while entries[last+1] and entries[last+1].category==first.category
                    and (entries[last+1].lineId or entries[last+1].lineIndex)==(first.lineId or first.lineIndex)do
                    last=last+1
                end
                local count=last-index+1
                local iconGap=math.min(2,math.max(0,(inner-count)/math.max(1,count-1)))
                local size=math.min(28,(inner-(count-1)*iconGap)/count)
                local stride=size+iconGap
                local groupWidth=count*size+(count-1)*iconGap
                if x>PAD then
                    x=x+10
                    if x+groupWidth>PAD+inner then x=PAD;y=y+rowHeight+8;rowHeight=0 end
                end
                for i=index,last do
                    self:SkillIcon(entries[i],x,y,size,false);x=x+stride
                end
                -- Reserve the same 12-unit branch gap even when a narrow
                -- branch uses a smaller internal gap.
                x=x+2-iconGap
                rowHeight=math.max(rowHeight,size)
                index=last+1
            end
            y=y+rowHeight+12
        end
    end
    return y,visible
end
function Instance:Label(value,x,y,width,font,align,tooltip)
    local c=self:Acquire(CT_LABEL)
    c:SetFont(font or "ZoFontGame")
    c:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT)
    c:SetWidth(width);c:SetText(value)
    c:SetAnchor(TOPLEFT,self.control,TOPLEFT,x,y)
    self:Bind(c,tooltip)
    return c:GetHeight()/self.control:GetScale()
end
function Instance:KeyValue(name,value,x,y,width,valueFont,gap,tooltip)
    local c=self:Acquire(CT_LABEL)
    c:SetFont(valueFont or "ZoFontGame")
    c:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    c:SetDimensions(0,0);c:SetText(value)
    -- Measure rendered text (including bar pairs), not a fixed numeric column.
    -- Keep a little rounding room and a real gap before the right-aligned value.
    local valueWidth=math.min(width*0.45,math.ceil(c:GetTextWidth())+2)
    c:SetWidth(valueWidth)
    c:SetAnchor(TOPLEFT,self.control,TOPLEFT,x+width-valueWidth,y)
    local height=math.max(ROW,c:GetHeight()/self.control:GetScale(),
        self:Label("|cC9C3A4"..name.."|r",x,y,width-valueWidth-gap,"ZoFontHeader"))
    if tooltip and self.tooltips then
        local row=self:Acquire(CT_CONTROL)
        row:SetDimensions(width,height);row:SetAnchor(TOPLEFT,self.control,TOPLEFT,x,y)
        self:Bind(row,tooltip)
    end
    return height
end
function Instance:Rule(y,width)
    local c=self:Acquire(CT_TEXTURE)
    c:SetTexture(nil)
    c:SetColor(0.57,0.53,0.39,0.4)
    c:SetDimensions(width,1);c:SetAnchor(TOPLEFT,self.control,TOPLEFT,PAD,y)
end
-- Keep each paragraph intact and preserve the source order down the left
-- column, then down the right. Choose the break by rendered height, not count.
function Instance:TextColumns(entries,top,width,tooltips)
    local columns=width>=600 and 2 or 1
    local columnWidth=(width-(columns-1)*GAP)/columns
    local labels,prefix={}, {0}
    for i,value in ipairs(entries)do
        local c=self:Acquire(CT_LABEL)
        c:SetFont("ZoFontGame");c:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        c:SetWidth(columnWidth);c:SetText("|cD5D1C1"..value.."|r")
        self:Bind(c,tooltips and tooltips[i])
        local h=c:GetHeight()/self.control:GetScale()
        labels[i]={control=c,height=h}
        prefix[i+1]=prefix[i]+h+8
    end
    local split,total=#entries,prefix[#entries+1]
    if columns==2 and #entries>1 then
        local best=math.huge
        for i=1,#entries-1 do
            local height=math.max(prefix[i+1],total-prefix[i+1])
            if height<=best then best=height;split=i end
        end
    end
    local x,y,bottom=PAD,top,top
    for i,label in ipairs(labels)do
        if i==split+1 then x=PAD+columnWidth+GAP;y=top end
        label.control:SetAnchor(TOPLEFT,self.control,TOPLEFT,x,y)
        y=y+label.height+8;bottom=math.max(bottom,y)
    end
    return bottom
end
function Instance:Layout(data,width,language)
    self:HideSkillTooltip()
    if self.tooltips then self.tooltips:Hide()end
    self.counts={};self.data=data
    for _,c in ipairs(self.controls)do c.control:SetHidden(true)end
    self.control:SetHidden(false);self.control:ClearAnchors()
    self.control:SetAnchor(TOPLEFT,self.parent,TOPLEFT,0,0)
    self.control:SetWidth(width)
    local inner=width-2*PAD
    local y=4
    self.sections={}
    self.skillIcons={};self.barIcons={}
    local attributes=data.description and data.description.attributes
    local points,pointsWidth=self:PrepareAttributes(attributes,inner)
    -- Reserve the right edge on the first line. Subsequent metric lines may
    -- use the full width; on very narrow panels keep the allocation together.
    local inlinePoints=points and pointsWidth+120<=inner
    local metricEdge=PAD+inner-(inlinePoints and pointsWidth+24 or 0)
    local summaryTop=y
    -- Size each icon/value group to its content. One fixed gap separates
    -- every group; longer values never stretch the space after other groups.
    local x,height=PAD,ROW
    local iconSize,iconGap,metricGap=26,4,20
    local metrics,resourceWidth,resourceCount={},0,0
    for _,m in ipairs(data.metrics)do
        local value=m.value and colored(m.value,m.color) or ""
        if m.recovery then value=value..(value~="" and "  " or "")..colored(m.recovery,m.color)end
        local label=self:Acquire(CT_LABEL)
        label:SetFont("ZoFontGame");label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        label:SetDimensions(0,0);label:SetText(value)
        local textWidth=math.ceil(label:GetTextWidth())
        local w=math.min(inner,iconSize+iconGap+textWidth)
        local resource=m.key=='health' or m.key=='stamina' or m.key=='magicka'
        metrics[#metrics+1]={metric=m,label=label,width=w,resource=resource}
        if resource then
            resourceWidth=resourceWidth+w+(resourceCount>0 and metricGap or 0)
            resourceCount=resourceCount+1
        end
    end
    local resourcesPlaced,resourceTop,resourceX=false
    local resourceGap=resourceWidth>inner and 8 or metricGap
    local resourceCell=resourceWidth>inner and (inner-resourceGap*(resourceCount-1))/math.max(1,resourceCount)or nil
    for _,entry in ipairs(metrics)do
        local m,label,w=entry.metric,entry.label,entry.width
        local size=iconSize
        if entry.resource and not resourcesPlaced then
            -- Health, stamina and magicka are one visual unit. Measure the
            -- entire group before deciding whether to move it to a new row.
            if x+resourceWidth>metricEdge and (x>PAD or (inlinePoints and y==summaryTop))then
                y=y+height+6;x=PAD;height=ROW;metricEdge=PAD+inner
            end
            resourcesPlaced=true;resourceTop=y;resourceX=x
        end
        if entry.resource and resourceCell then
            -- At narrow widths keep all resources on the same baseline and
            -- wrap their values inside equal columns instead of stranding mana.
            y=resourceTop;x=resourceX;w=resourceCell
            size=math.min(iconSize,math.max(0,math.floor(w/3)))
        elseif not entry.resource and x+w>metricEdge and (x>PAD or (inlinePoints and y==summaryTop)) then
            y=y+height+6;x=PAD;height=ROW;metricEdge=PAD+inner
        end
        local icon=self:Acquire(CT_TEXTURE)
        icon:SetTexture(m.icon);icon:SetColor(1,1,1,1)
        icon:SetDimensions(size,size);icon:SetAnchor(TOPLEFT,self.control,TOPLEFT,x,y)
        label:SetWidth(math.max(1,w-size-iconGap))
        label:SetAnchor(TOPLEFT,self.control,TOPLEFT,x+size+iconGap,y+2)
        local sections={}
        if m.tooltip then sections[#sections+1]=m.tooltip end
        if m.recoveryTooltip then sections[#sections+1]=m.recoveryTooltip end
        if #sections>0 then
            local tooltip={kind="breakdowns",sections=sections}
            self:Bind(label,tooltip);self:Bind(icon,tooltip)
        end
        height=math.max(height,label:GetHeight()/self.control:GetScale()+2)
        x=x+w+(entry.resource and resourceGap or metricGap)
        if entry.resource then resourceX=x end
    end
    local hasSummary=#data.metrics>0 or points~=nil
    if #data.metrics>0 then y=y+height+6 end
    if points then
        local pointY=inlinePoints and summaryTop or y
        local pointHeight=self:LayoutAttributes(attributes,points,pointsWidth,pointY,inner)
        y=math.max(y,pointY+pointHeight+6)
    end
    self.sections.metricsBottom=y
    if hasSummary then self:Rule(y+2,inner);y=y+14 end
    local hasSkills
    y,hasSkills=self:LayoutSkills(data.description,y,inner)
    if hasSkills and (#data.sets>0 or #data.rows>0 or #data.details>0
        or #(data.barGroups or {})>0 or #(data.specials or {})>0)then
        self:Rule(y,inner);y=y+12
    end
    -- Set names and counts share real column boundaries, not padded strings.
    local columns=inner>=720 and 2 or 1
    local cellWidth=(inner-(columns-1)*GAP)/columns
    self.sections.setsTop=y
    for i=1,#data.sets,columns do
        local h=ROW
        for col=1,columns do
            local item=data.sets[i+col-1]
            if item then
                local x=PAD+(col-1)*(cellWidth+GAP)
                h=math.max(h,self:KeyValue(item.name,item.value,x,y,cellWidth,nil,8,item.tooltip))
            end
        end
        y=y+h+2
    end
    if #data.sets>0 then y=y+8 end
    local function divider()
        self:Rule(y,inner);y=y+12
    end
    local function rows(entries)
        local perColumn=math.ceil(#entries/columns)
        for row=1,perColumn do
            local h=ROW
            for col=1,columns do
                local entry=entries[(col-1)*perColumn+row]
                if entry then
                    local x=PAD+(col-1)*(cellWidth+GAP)
                    h=math.max(h,self:KeyValue(entry.name,entry.value,x,y,cellWidth,"ZoFontHeader",12,entry.tooltip))
                end
            end
            y=y+h+2
        end
        if #entries>0 then y=y+8 end
    end
    self.sections.effectsTop=y
    local ordinary,damage=separateDamage(data.rows)
    if #ordinary>0 then divider();rows(ordinary)end
    self.sections.damageTop=y
    if #damage>0 then divider();rows(damage)end
    self.sections.detailsTop=y
    if #data.details>0 then
        divider()
        y=self:TextColumns(data.details,y,inner,data.detailSources)
    end
    local groups={}
    for _,group in ipairs(data.barGroups or {})do
        if #group.rows>0 or #group.details>0 then
            groups[#groups+1]=group
        end
    end
    self.sections.barsTop=y
    if #groups>0 then
        divider()
        -- Each weapon bar owns a column. Measure both from the same top and
        -- place the next section below the taller one, including wrapped text.
        local barColumns=inner>=600 and 2 or 1
        local barWidth=(inner-(barColumns-1)*GAP)/barColumns
        local top,bottom=y,y
        for i,group in ipairs(groups)do
            if barColumns==1 and i>1 then y=bottom;divider();top=y end
            local column=barColumns==2 and group.bar=="back" and 1 or 0
            local x=PAD+column*(barWidth+GAP)
            local cy=top+self:Label(group.title,x,top,barWidth,"ZoFontGameBold")+6
            local ordinary,damage=separateDamage(group.rows)
            local function barRows(entries)
             for _,entry in ipairs(entries)do
                local h=self:KeyValue(entry.name,entry.value,x,cy,barWidth,"ZoFontHeader",12,entry.tooltip)
                cy=cy+h+2
             end
            end
            barRows(ordinary)
            if #damage>0 then
                if #ordinary>0 then cy=cy+6 end
                barRows(damage)
            end
            if #group.rows>0 and #group.details>0 then cy=cy+4 end
            for i,value in ipairs(group.details)do
                cy=cy+self:Label("|cD5D1C1"..value.."|r",x,cy,barWidth,nil,nil,group.detailSources and group.detailSources[i])+8
            end
            bottom=math.max(bottom,cy)
        end
        y=bottom+8
    end
    -- Each compound effect retains its own source heading and separator, but
    -- its paragraphs flow into columns just like the ordinary special effects.
    self.sections.specialsTop=y
    for _,entry in ipairs(data.specials or {})do
        divider()
        y=y+self:Label(entry.title,PAD,y,inner,"ZoFontGameBold",nil,entry.tooltip)+6
        local paragraphs,tooltips={},{}
        for paragraph in entry.description:gmatch("[^\r\n]+")do
            paragraph=paragraph:gsub("^%s+",""):gsub("%s+$","")
            if paragraph~="" then paragraphs[#paragraphs+1]=paragraph;tooltips[#paragraphs]=entry.tooltip end
        end
        y=self:TextColumns(paragraphs,y,inner,tooltips)
    end
    self.control:SetHeight(y+4)
    return y+4
end
