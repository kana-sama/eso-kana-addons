-- Owned native tooltip, measured from styled content and attached to its icon.
-- API101051: Label:GetTextDimensions26230 (UI units), Tooltip:SetOwner26961.
-- Font aliases: esoui/fontdefs/keyboard/defaultfontdefs_keyboard.xml.
local Tooltip={}; Tooltip.__index=Tooltip; KanaEffects.Tooltip=Tooltip
local sequence=0
local function clean(text)
    if type(text)~='string' then return '' end
    return (text:gsub('^%s+',''):gsub('%s+$',''))
end
-- Let ESO handle localized sentence casing and grammatical suffixes. Lua's
-- byte-oriented upper/sub cannot capitalize Russian; stripping markup would
-- also discard native highlighted values, links and inline icons.
local function sentence(api,text,isName)
    text=clean(text)
    if text~='' and api and api.zo_strformat then
        local ok,formatted=pcall(api.zo_strformat,'<<C:1>>',text)
        if ok and type(formatted)=='string' and formatted~='' then return formatted end
    end
    return isName and text:gsub('%^.*$','') or text
end
-- Respect native inline color/texture/link tokens and UTF-8 while truncating.
local function prefix(text,limit)
    local i,last,color=1,0,false
    while i<=#text and i<=limit do
        local token=text:sub(i,i+1); local finish
        if token=='|c' and text:sub(i+2,i+7):match('^%x%x%x%x%x%x$') then finish=i+7
        elseif token=='|r' then finish=i+1
        elseif token=='|t' or token=='|u' then
            local _,lastTag=text:find(token,i+2,true); finish=lastTag or #text
        elseif token=='|H' then
            local _,first=text:find('|h',i+2,true); local _,lastTag
            if first then _,lastTag=text:find('|h',first+1,true) end
            finish=lastTag or #text
        else
            local byte=text:byte(i); local length=byte<128 and 1 or byte>=240 and 4 or byte>=224 and 3 or byte>=192 and 2 or 1
            finish=i+length-1
        end
        if finish>limit then break end
        if token=='|c' then color=true elseif token=='|r' then color=false end
        last=finish; i=finish+1
    end
    return text:sub(1,last)..(color and '|r' or '')
end
local function bounded(text)
    return #text>32768 and prefix(text,32765)..'…' or text
end
function Tooltip.AbilityDescription(api,id,caster)
    if not api or not api.GetAbilityDescription or type(id)~='number' or id<=0 or id%1~=0 then return nil end
    local ok,value=pcall(api.GetAbilityDescription,id,nil,caster)
    value=ok and clean(value) or ''
    if value=='' or value=='?' or value=='—' then return nil end
    return value
end
-- Character Effects uses GetAbilityEffectDescription(buffSlot) for the player
-- (native zo_stats_gamepad.lua:1619–1623). A slot is neither an ability ID nor
-- the enumeration index. Validate it against the live player before querying;
-- history/demo/other-unit rows must never borrow a current player's prose.
local function effectReader(api)
    local live
    return function(rows)
        if not api or not api.GetAbilityEffectDescription or not api.GetNumBuffs or not api.GetUnitBuffInfo then return nil end
        for _,row in ipairs(rows or {}) do
            local slot=row.effectSlot
            if not row.synthetic and row.unit and row.unit.tag=='player' and type(slot)=='number' and slot>0 and slot%1==0 then
                if not live then
                    live={}
                    local ok,count=pcall(api.GetNumBuffs,'player')
                    if ok and type(count)=='number' and count>=0 and count<100000 then
                        for index=1,count do
                            local valid,_,beginTime,_,currentSlot,_,_,_,_,_,_,id=pcall(api.GetUnitBuffInfo,'player',index)
                            if valid and currentSlot then live[currentSlot]={id=id,startTime=beginTime} end
                        end
                    end
                end
                local current=live[slot]
                if current and current.id==row.abilityId and (row.startTime==nil or current.startTime==row.startTime) then
                    local ok,value=pcall(api.GetAbilityEffectDescription,slot)
                    value=ok and clean(value) or ''
                    if value~='' and value~='?' and value~='—' then return value end
                end
            end
        end
    end
end
function Tooltip.Compose(entry,api)
    local title=sentence(api,entry.name,true); local lines={title}; local candidates,seen={},{}
    for index,row in ipairs(entry.contributors or {}) do
        local identity=row.artificialEffectId and 'artificial:'..row.artificialEffectId or row.abilityId
        if identity and not seen[identity] then
            local candidate={id=row.abilityId,artificialEffectId=row.artificialEffectId,observations={row},name=sentence(api,(row.catalog or {}).name,true),
                caster=row.castBy=='self' and 'player' or nil,level=(row.catalog or {}).level,index=index}
            seen[identity]=candidate; candidates[#candidates+1]=candidate
        elseif identity then
            local observations=seen[identity].observations; observations[#observations+1]=row
        end
    end
    local selector=entry.selector or {}
    if #candidates==0 and selector.kind=='ability' then candidates[1]={id=selector.id,index=1,name=title} end
    if #candidates==0 and selector.kind=='artificial' then candidates[1]={artificialEffectId=selector.id,index=1,name=title} end
    if #candidates==0 and selector.kind=='family' then
        -- Inactive pair slots still have real, versioned representative IDs.
        local data=KanaEffects.CatalogData and KanaEffects.CatalogData.Families
        if data and api and api.GetAPIVersion and api.GetAPIVersion()==data.apiVersion then
            for _,family in ipairs(data.rows) do if family.id==selector.id then
                for index,level in ipairs({'minor','major'}) do local d=family.levels[level]
                    if d and d.representativeId and (selector.level=='pair' or selector.level==level) then
                        local name=api.GetAbilityName and api.GetAbilityName(d.representativeId) or ''
                        candidates[#candidates+1]={id=d.representativeId,name=sentence(api,name,true),level=level,index=index}
                    end
                end
                break
            end end
        end
    end
    local rank={minor=1,major=2}
    table.sort(candidates,function(a,b) local x,y=rank[a.level] or 3,rank[b.level] or 3; return x<y or x==y and a.index<b.index end)
    local readEffect=effectReader(api)
    for _,candidate in ipairs(candidates) do
        local description
        if candidate.artificialEffectId and api.GetArtificialEffectTooltipText then
            local ok,value=pcall(api.GetArtificialEffectTooltipText,candidate.artificialEffectId)
            description=ok and clean(value) or nil
            if description=='' or description=='?' or description=='—' then description=nil end
        else description=readEffect(candidate.observations) or Tooltip.AbilityDescription(api,candidate.id,candidate.caster) end
        if description then description=sentence(api,description) end
        if description and description~=title then
            local body=description
            if (#candidates>1 or selector.kind~='ability') and candidate.name~='' and candidate.name~=title then body=candidate.name..'\n'..description end
            lines[#lines+1]=body
        end
    end
    local body=bounded(table.concat(lines,'\n\n',2))
    title=bounded(title)
    return title..(body~='' and '\n\n'..body or ''),title,body
end
function Tooltip.New(api)
    sequence=sequence+1; return setmetatable({api=api,name='KanaEffectsCell'..sequence},Tooltip)
end
-- Compact keyboard effect heading: bold18 with the same thin shadow as the
-- native18 body. ZoFontTooltipTitle is bold22 and visibly oversized here.
local TITLE_FONT,BODY_FONT='ZoFontGameBold','ZoFontGame'
local PADDING,GAP,MARGIN,MAX_WIDTH=32,8,8,420
local function clamp(value,low,high) return math.max(low,math.min(value,high)) end
function Tooltip:_NaturalWidth()
    local label=self.measure; local width=0
    for _,line in ipairs({{self.title,TITLE_FONT},{self.body,BODY_FONT}}) do
        if line[1]~='' then
            label:SetFont(line[2]); label:SetDimensions(0,0); label:SetText(line[1])
            local measured=label:GetTextDimensions(); width=math.max(width,measured)
        end
    end
    return math.ceil(width+PADDING)
end
function Tooltip:_Measure(title,body,width)
    local c,k=self.control,self.api.constants
    local inset=PADDING/2; local contentWidth=math.max(1,width-PADDING)
    local y=inset
    -- ZO_BaseTooltip BG is AnchorFill. Its engine AddLine layout and trailing
    -- ResizeToFitPadding do not expose the text origin. Own the two native
    -- labels instead: measured content plus equal insets IS the visible frame.
    for index,line in ipairs({{self.titleLabel,title},{self.bodyLabel,body}}) do
        local label,value=line[1],line[2]
        label:SetHidden(value=='')
        if value~='' then
            if index==2 and title~='' then y=y+6 end
            label:SetDimensions(contentWidth,0); label:SetText(value)
            local _,height=label:GetTextDimensions()
            label:ClearAnchors(); label:SetAnchor(k.TOPLEFT,c,k.TOPLEFT,inset,y)
            label:SetDimensions(contentWidth,height); y=y+height
        else label:SetText(''); label:SetDimensions(contentWidth,0) end
    end
    local height=y+inset
    c:SetDimensionConstraints(width,height,width,height); c:SetDimensions(width,height)
    return width,height
end
function Tooltip:_Fit(maxWidth,maxHeight)
    local width=math.max(1,math.min(MAX_WIDTH,maxWidth,self.naturalWidth))
    if self.fitWidth==width and self.fitHeightLimit==maxHeight then return self.fitWidth,self.fitHeight end
    local title,body=self.title,self.body
    local _,height=self:_Measure(title,body,width)
    if height>maxHeight then
        -- Preserve the complete title when it fits and spend the remaining room
        -- on prose. The bounded source limits each binary search to16 steps.
        local _,titleHeight=self:_Measure(title,'',width)
        local fitBody=body~='' and titleHeight<maxHeight
        local original=fitBody and body or title
        local low,high,best=0,#original,''
        while low<=high do
            local middle=math.floor((low+high)/2); local candidate=prefix(original,middle)..'…'
            local _,candidateHeight=self:_Measure(fitBody and title or candidate,fitBody and candidate or '',width)
            if candidateHeight<=maxHeight then best=candidate; low=middle+1 else high=middle-1 end
        end
        if fitBody then body=best else title,body=best~='' and best or '…','' end
        _,height=self:_Measure(title,body,width)
    end
    height=math.min(height,maxHeight)
    self.control:SetDimensionConstraints(width,height,width,height); self.control:SetDimensions(width,height)
    self.fitWidth,self.fitHeight,self.fitHeightLimit=width,height,maxHeight
    self.truncated=title~=self.title or body~=self.body
    return width,self.fitHeight
end
function Tooltip:_Position()
    if not self.owner then return end
    if self.owner.IsControlHidden and self.owner:IsControlHidden() then self:Exit(nil,nil,self.owner); return end
    local api=self.api; local screen=api.controls.GuiRoot; local anchor=self.anchor
    -- Native screen edges include control scale, while dimensions and anchor
    -- offsets are UI units. ESO's dynamic tooltip anchors likewise convert
    -- GetScreenRect through GetScale (tooltips.lua:175-184). Normalize every
    -- rectangle into THIS tooltip's units; owner/icon may inherit other scales.
    local scale=self.control:GetScale()
    if not scale or scale<=0 then return end
    local function rect(control)
        local l,t,r,b=control:GetScreenRect()
        if not l or not t or not r or not b then return end
        return l/scale,t/scale,(r-l)/scale,(b-t)/scale
    end
    local left,top,width,height=rect(screen)
    local ax,ay,aw,ah=rect(anchor)
    if not width or width<=0 or height<=0 or not ax then return end
    -- Native ownership stays with the icon; exclusion includes its whole effect
    -- cell, so a list name or right-side timer cannot sit under the tooltip.
    local bx,by,bw,bh=ax,ay,aw,ah
    if self.owner~=anchor then
        local ox,oy,ow,oh=rect(self.owner)
        if not ox then return end
        bx,by=math.min(ax,ox),math.min(ay,oy)
        bw,bh=math.max(ax+aw,ox+ow)-bx,math.max(ay+ah,oy+oh)-by
    end
    local preferredSide=self.owner._kanaTooltipSide or 'right'
    local stamp=table.concat({ax,ay,aw,ah,bx,by,bw,bh,left,top,width,height,scale,preferredSide},':')
    if stamp==self.positionStamp then return end
    self.positionStamp=stamp
    local viewport=table.concat({width,height,scale},':')
    local minX,minY,maxX,maxY=left+MARGIN,top+MARGIN,left+width-MARGIN,top+height-MARGIN
    local fullWidth,fullHeight=math.max(1,maxX-minX),math.max(1,maxY-minY)
    if self.viewport~=viewport or not self.preferred then
        self.viewport=viewport; self.fitWidth=nil; self.naturalWidth=self:_NaturalWidth()
        local w,h=self:_Fit(fullWidth,fullHeight); self.preferred={width=w,height=h}
        self.root:ClearAnchors(); self.root:SetAnchor(api.constants.TOPLEFT,screen,api.constants.TOPLEFT,0,0); self.root:SetDimensions(width,height)
    end
    local candidates={
        {side='right',width=maxX-(bx+bw+GAP),height=fullHeight},
        {side='left',width=bx-GAP-minX,height=fullHeight},
        {side='below',width=fullWidth,height=maxY-(by+bh+GAP)},
        {side='above',width=fullWidth,height=by-GAP-minY},
    }
    if preferredSide=='left' then candidates[1],candidates[2]=candidates[2],candidates[1] end
    local best
    for _,candidate in ipairs(candidates) do
        if candidate.width>=self.preferred.width and candidate.height>=self.preferred.height then best=candidate; break end
    end
    if not best then
        local area=0
        for _,candidate in ipairs(candidates) do
            local score=math.min(candidate.width,self.naturalWidth,MAX_WIDTH)*candidate.height
            if candidate.width>=PADDING+20 and candidate.height>=PADDING+24 and score>area then best,area=candidate,score end
        end
    end
    -- If the icon itself fills the viewport, there is no non-overlapping fit.
    best=best or {side='fallback',width=fullWidth,height=fullHeight}
    local w,h=self:_Fit(math.max(1,best.width),math.max(1,best.height)); local x,y
    if best.side=='right' then x,y=math.max(minX,bx+bw+GAP),clamp(by+(bh-h)/2,minY,maxY-h)
    elseif best.side=='left' then x,y=math.min(maxX-w,bx-GAP-w),clamp(by+(bh-h)/2,minY,maxY-h)
    elseif best.side=='below' then x,y=clamp(bx+(bw-w)/2,minX,maxX-w),math.max(minY,by+bh+GAP)
    elseif best.side=='above' then x,y=clamp(bx+(bw-w)/2,minX,maxX-w),math.min(maxY-h,by-GAP-h)
    else x,y=minX,minY end
    self.control:SetOwner(anchor,api.constants.TOPLEFT,x-ax,y-ay,api.constants.TOPLEFT)
end
function Tooltip:Enter(widgetId,entry,control,icon)
    if self.disposed then return end
    local api=self.api
    if not api.InitializeTooltip or not api.ClearTooltipImmediately or not api.controls.CreateControlFromVirtual or not api.controls.CreateControl then return end
    local text,title,body=Tooltip.Compose(entry,api)
    if text=='' then if self.owner then self:Exit(nil,nil,self.owner) end; return end
    if not self.control then
        self.root=api.controls.CreateTopLevelWindow(self.name..'TooltipTopLevel'); self.root:SetMouseEnabled(false); self.root:SetDrawTier(api.constants.DT_HIGH)
        self.control=api.controls.CreateControlFromVirtual(self.name..'Tooltip',self.root,'ZO_BaseTooltip'); self.control:SetMouseEnabled(false)
        self.control:SetResizeToFitDescendents(false); self.control:SetResizeToFitPadding(0,0)
        self.control:SetClampedToScreen(true); self.control:SetClampedToScreenInsets(0,0,0,0); self.control:SetAutoRectClipChildren(true)
        self.measure=api.controls.CreateControl(self.name..'TooltipMeasure',self.root,api.constants.CT_LABEL); self.measure:SetHidden(true)
        self.titleLabel=api.controls.CreateControl(self.name..'TooltipTitle',self.control,api.constants.CT_LABEL)
        self.bodyLabel=api.controls.CreateControl(self.name..'TooltipBody',self.control,api.constants.CT_LABEL)
        self.titleLabel:SetMouseEnabled(false); self.titleLabel:SetFont(TITLE_FONT); self.titleLabel:SetColor(1,1,1,1)
        self.titleLabel:SetHorizontalAlignment(api.constants.TEXT_ALIGN_CENTER)
        self.bodyLabel:SetMouseEnabled(false); self.bodyLabel:SetFont(BODY_FONT); self.bodyLabel:SetColor(0.77,0.76,0.72,1)
        self.bodyLabel:SetHorizontalAlignment(api.constants.TEXT_ALIGN_LEFT)
    end
    local changed=text~=self.text
    local anchor=icon or control
    if changed or self.anchor~=anchor or self.owner~=control then self.positionStamp=nil end
    self.owner,self.anchor,self.widgetId=control,anchor,widgetId
    self.text,self.title,self.body=text,title,body
    if changed then self.preferred=nil; self.fitWidth=nil end
    if self.root:IsControlHidden() or changed then api.InitializeTooltip(self.control,anchor,api.constants.TOPLEFT,0,0,api.constants.TOPLEFT) end
    self.root:SetHidden(false); self:_Position()
    if self.owner then self.root:SetHandler('OnUpdate',function() if not self.disposed then self:_Position() end end) end
end
function Tooltip:Exit(_,_,control)
    if self.owner~=control then return end
    self.owner=nil; self.anchor=nil; self.positionStamp=nil
    -- ClearTooltipImmediately clears native lines, so reopening must repopulate.
    self.preferred=nil; self.fitWidth=nil
    if self.root then self.root:SetHandler('OnUpdate',nil); self.root:SetHidden(true) end
    if self.control then self.api.ClearTooltipImmediately(self.control) end
end
function Tooltip:Dispose()
    if self.disposed then return end
    if self.owner then self:Exit(nil,nil,self.owner) end
    self.disposed=true
    if self.root then self.root:SetHandler('OnUpdate',nil); self.root:SetHidden(true) end
end
