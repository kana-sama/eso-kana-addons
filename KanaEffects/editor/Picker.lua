-- One selector provider/window for every editor destination. Native primitives
-- are injected; all model reads use the public Catalog/History/Store contracts.
local Picker={}; Picker.__index=Picker; KanaEffects.Picker=Picker
local sequence=0
local sections={named=true,common=true,active=true,recent=true}
local function copy(v) if type(v)~='table' then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
local function key(item) return KanaEffects.Selectors.Key(item.selector)..':'..table.concat(item.unitTags or {},',') end
local function text(v) return tostring(v or '') end
local function locale(api) local language=api and (api.language or (api.GetCVar and api.GetCVar('language.2'))) or 'en'; return (KanaEffects.Localization[language] or KanaEffects.Localization.en).picker end
local function pages(provider,method,query,filter)
    local rows,total=provider[method](provider,query,filter,0,1000)
    while #rows<total do
        local page=provider[method](provider,query,filter,#rows,1000)
        if #page==0 then break end
        for _,item in ipairs(page) do rows[#rows+1]=item end
    end
    return rows
end
local function restoreFocus(options,api)
    local origin=options and options.initiator
    if not origin or type(origin.IsControlHidden)~='function' or origin:IsControlHidden() or (options.canRestoreFocus and not options.canRestoreFocus()) then return end
    if type(origin.TakeFocus)=='function' then origin:TakeFocus()
    elseif api and api.windowManager and type(api.windowManager.SetFocusByName)=='function' and type(origin.GetName)=='function' then
        local name=origin:GetName(); if name and name~='' then api.windowManager:SetFocusByName(name) end
    end
end
local function anchor(api,c,parent,x,y,w,h)
    c:ClearAnchors(); c:SetAnchor(api.constants.TOPLEFT,parent,api.constants.TOPLEFT,x,y); c:SetDimensions(w,h)
end
local function label(api,parent,name,font)
    local c=api.controls.CreateControl(name,parent,api.constants.CT_LABEL); c:SetFont(font or 'ZoFontGame')
    c:SetColor(unpack(Picker.NativeColors(api).normal)); return c
end
function Picker.SetButtonText(control,title)
    -- ButtonControl has no GetText; retain the same string used by its label.
    control.kanaTitle=title; control:SetText(title)
end
function Picker.NativeColors(api)
    if api.kanaNativeColors then return api.kanaNativeColors end
    local colors={}; local c=api.constants
    local roles={normal='NORMAL',selected='SELECTED',highlight='HIGHLIGHT',disabled='DISABLED',error='FAILED'}
    for role,suffix in pairs(roles) do
        colors[role]={assert(api.GetInterfaceColor,'native interface colors unavailable')(c.INTERFACE_COLOR_TYPE_TEXT_COLORS,c['INTERFACE_TEXT_COLOR_'..suffix])}
    end
    api.kanaNativeColors=colors; return colors
end
function Picker.StyleButton(control,role,selected,enabled)
    control.kanaRole=role or control.kanaRole or 'secondary'; control.kanaSelected=selected==true
    if enabled~=nil then control.kanaEnabled=enabled; control:SetEnabled(enabled) end
    local api=control.kanaApi; local colors=Picker.NativeColors(api); local c=api.constants
    local active=control.kanaSelected or control.kanaRole=='primary'
    local color=control.kanaRole=='destructive' and colors.error or active and colors.selected or colors.normal
    control:SetNormalFontColor(unpack(color)); control:SetMouseOverFontColor(unpack(colors.highlight))
    control:SetPressedFontColor(unpack(colors.selected)); control:SetDisabledFontColor(unpack(colors.disabled))
    control:SetState(control.kanaEnabled==false and c.BSTATE_DISABLED or control.kanaSelected and c.BSTATE_PRESSED or c.BSTATE_NORMAL,control.kanaSelected)
end
local function button(api,parent,name,title,callback)
    -- Native PC template owns textures, bevel, pressed offset, font and sound.
    local c=api.controls.CreateControlFromVirtual(name,parent,'ZO_DefaultButton'); c.kanaApi=api
    Picker.SetButtonText(c,title)
    c:SetHandler('OnClicked',callback); Picker.StyleButton(c); return c
end
-- Compatibility name; this is the stock textured window, never a solid fill.
function Picker.PanelFill(api,parent,name)
    local fill=api.controls.CreateControlFromVirtual(name,parent,'ZO_DefaultBackdrop')
    fill:SetDrawLayer(api.constants.DL_BACKGROUND)
    fill:SetMouseEnabled(false); fill:SetHidden(false); return fill
end
local TAB_ICONS={main='character',effects='skills',layout='inventory',style='collections',anchor='map',code='journal',references='social',
    named='skills',common='inventory',active='character',recent='journal'}
function Picker.HideTabTooltip(control)
    local api=control.kanaApi
    if api and api.kanaTabTooltipOwner==control then
        local tooltip=api.informationTooltip
        if tooltip and tooltip:GetOwner()==control and api.ClearTooltipImmediately then api.ClearTooltipImmediately(tooltip) end
        api.kanaTabTooltipOwner=nil
    end
end
-- Diagram/anchor choices use a native click target without text-button caps.
function Picker.SelectionButton(api,parent,name)
    local c=api.controls.CreateControlFromVirtual(name,parent,'ZO_ButtonBehaviorClickSound'); c.kanaApi=api
    c.kanaSelection=api.controls.CreateControlFromVirtual(name..'Selection',c,'ZO_SelectionFrameBackdrop')
    c.kanaSelection:SetAnchorFill(c); c.kanaSelection:SetMouseEnabled(false); c.kanaSelection:SetDrawLayer(api.constants.DL_OVERLAY)
    return c
end
function Picker.StyleSelectionButton(c,selected,enabled)
    Picker.StyleTab(c,selected,enabled)
    c.kanaSelection:SetEdgeColor(unpack(Picker.NativeColors(c.kanaApi).selected)); c.kanaSelection:SetHidden(not selected)
end
function Picker.StyleTab(control,selected,enabled)
    local c=control.kanaApi.constants; control.kanaSelected=selected==true
    if enabled~=nil then control.kanaEnabled=enabled; control:SetEnabled(enabled) end
    control:SetState(control.kanaEnabled==false and c.BSTATE_DISABLED or selected and c.BSTATE_PRESSED or c.BSTATE_NORMAL,selected==true)
end
function Picker.IconTab(api,parent,name,id,title,callback)
    -- MenuBarButtonTemplate1 is a Control requiring a menu-bar object. A native
    -- Button uses the same verified stock icon assets without fake OnClicked.
    local icon=assert(TAB_ICONS[id],'unknown tab icon: '..tostring(id))
    local c=api.controls.CreateControlFromVirtual(name,parent,'ZO_ButtonBehaviorClickSound')
    c.kanaApi=api; c.kanaTitle=title; c.kanaIconTab=true
    local prefix='EsoUI/Art/MainMenu/menuBar_'..icon
    c:SetNormalTexture(prefix..'_up.dds'); c:SetPressedTexture(prefix..'_down.dds')
    c:SetMouseOverTexture(prefix..'_over.dds'); c:SetDisabledTexture(prefix..'_disabled.dds')
    c:SetHandler('OnClicked',callback)
    c:SetHandler('OnMouseEnter',function()
        if c:IsControlHidden() or c.kanaEnabled==false then return end
        if api.informationTooltip and api.InitializeTooltip and api.SetTooltipText then
            api.kanaTabTooltipOwner=c
            api.InitializeTooltip(api.informationTooltip,c,api.constants.BOTTOM,0,-6,api.constants.TOP)
            api.SetTooltipText(api.informationTooltip,c.kanaTitle)
        end
    end)
    c:SetHandler('OnMouseExit',function() Picker.HideTabTooltip(c) end)
    c:SetHandler('OnEffectivelyHidden',function() Picker.HideTabTooltip(c) end)
    Picker.StyleTab(c,false,true); return c
end
-- Shared small native panel for picker/hidden library, with a declared pooled row.
-- This is a KanaEffects composition helper, not an engine API.
function Picker.CreatePanel(api,name,title,handlers)
    if not api or not api.controls or not api.controls.CreateControlFromVirtual or not api.ScrollList then return nil end
    local v={api=api,handlers=handlers,labels=locale(api)}
    v.root=api.controls.CreateTopLevelWindow(name); v.root:SetHidden(true); v.root:SetMouseEnabled(true); v.root:SetDrawTier(api.constants.DT_HIGH)
    v.fill=Picker.PanelFill(api,v.root,name..'Fill')
    v.backdrop=v.fill
    v.title=label(api,v.root,name..'Title','ZoFontWinH2'); v.title:SetText(title)
    v.title:SetWrapMode(api.constants.TEXT_WRAP_MODE_ELLIPSIS); v.title:SetMaxLineCount(1)
    v.close=api.controls.CreateControlFromVirtual(name..'Close',v.root,'ZO_CloseButton'); v.close:SetHandler('OnClicked',handlers.close)
    v.searchBackdrop=api.controls.CreateControlFromVirtual(name..'SearchBackdrop',v.root,'ZO_SingleLineEditBackdrop_Keyboard')
    v.search=api.controls.CreateControlFromVirtual(name..'Search',v.searchBackdrop,'ZO_DefaultEditForBackdrop')
    v.search:SetMaxInputChars(160); v.search:SetSelectAllOnFocus(true)
    function v:BindInput()
        local generation=handlers.generation()
        local function current() return generation==handlers.generation() end
        self.close:SetHandler('OnClicked',function() if current() then handlers.close() end end)
        self.search:SetHandler('OnTextChanged',function(edit) if current() then handlers.search(edit:GetText()) end end)
        self.search:SetHandler('OnEnter',function() if current() then handlers.enter() end end)
        self.search:SetHandler('OnEscape',function(edit) if current() then edit:LoseFocus(); handlers.escape() end end)
        self.search:SetHandler('OnKeyDown',function(_,keyCode)
            if not current() then return end
            if keyCode==api.constants.KEY_DOWNARROW then handlers.move(1) elseif keyCode==api.constants.KEY_UPARROW then handlers.move(-1) end
        end)
    end
    v.hint=label(api,v.root,name..'Hint','ZoFontGameSmall'); v.hint:SetText(v.labels.searchHint)
    v.notice=label(api,v.root,name..'Notice','ZoFontGameSmall')
    v.action=label(api,v.root,name..'Action','ZoFontGameSmall')
    v.measure=label(api,v.root,name..'Measure','ZoFontGameBold'); v.measure:SetHidden(true)
    if api.Scroll then
        v.detailScroll=api.controls.CreateControlFromVirtual(name..'DetailScroll',v.root,'ZO_ScrollContainer')
        v.detailContent=v.detailScroll:GetNamedChild('Scroll'):GetNamedChild('Child'); v.detailContent:SetResizeToFitDescendents(false)
    end
    v.detail=label(api,v.detailContent or v.root,name..'Detail','ZoFontGameSmall')
    v.list=api.controls.CreateControlFromVirtual(name..'List',v.root,'ZO_ScrollList')
    local function reset(row)
        row:SetHandler('OnMouseUp',nil); row:SetHandler('OnMouseEnter',nil); row:SetHandler('OnMouseExit',nil)
        row:GetNamedChild('Icon'):SetTexture(''); row:GetNamedChild('Name'):SetText(''); row:GetNamedChild('Detail'):SetText('')
        row:GetNamedChild('Name'):SetColor(unpack(Picker.NativeColors(api).normal))
        row:GetNamedChild('Detail'):SetColor(unpack(Picker.NativeColors(api).normal))
        row:SetAlpha(1); row:SetHidden(true)
    end
    api.ScrollList.AddDataType(v.list,1,'KanaEffectsPickerRow',58,function(row,item)
        reset(row); row:SetHidden(false); row:SetMouseEnabled(true)
        row:GetNamedChild('Icon'):SetTexture(item.icon or ''); row:GetNamedChild('Name'):SetText(item.name~='' and item.name or v.labels.unknown)
        row:GetNamedChild('Detail'):SetText(handlers.describe(item)); row:SetAlpha(item.selectable==false and 0.45 or 1)
        if handlers.isSelected(item) then row:GetNamedChild('Name'):SetColor(unpack(Picker.NativeColors(api).selected)) end
        local generation=handlers.generation()
        row:SetHandler('OnMouseUp',function(_,mouseButton,inside) if mouseButton==1 and inside and generation==handlers.generation() then handlers.choose(item) end end)
        row:SetHandler('OnMouseEnter',function() if generation==handlers.generation() then handlers.inspect(item) end end)
        row:SetHandler('OnMouseExit',function() if generation==handlers.generation() then handlers.inspect(nil) end end)
    end,nil,nil,reset)
    function v:SetItems(items)
        api.ScrollList.Clear(self.list); local data=api.ScrollList.GetDataList(self.list)
        for _,item in ipairs(items) do data[#data+1]=api.ScrollList.CreateDataEntry(1,item) end
        api.ScrollList.Commit(self.list)
    end
    function v:ButtonRows(buttons,y)
        local x=18; local lastHeight=0
        for _,control in ipairs(buttons) do
            self.measure:SetDimensions(10000,32); self.measure:SetText(control.kanaTitle)
            local measured=self.measure.GetTextDimensions and self.measure:GetTextDimensions() or 140
            local width=math.min(self.width-36,measured+24)
            if x>18 and x+width>self.width-18 then x=18; y=y+34 end
            anchor(api,control,self.root,x,y,width,28); x=x+width+6; lastHeight=34
        end
        return y+lastHeight
    end
    function v:LayoutBody(listTop)
        self.listTop=listTop or self.listTop or 118
        local width,height=self.width,self.height; if not width then return end
        local detailHeight=0; local detailText=self.detail:GetText()
        if detailText~='' then
            self.detail:SetDimensions(math.max(1,width-60),10000)
            local _,measured=0,48; if self.detail.GetTextDimensions then _,measured=self.detail:GetTextDimensions() end
            detailHeight=math.min(math.max(24,measured+4),math.max(24,math.min(180,math.floor(height*0.3))))
            if self.detailContent then
                self.detailContent:SetDimensions(width-60,measured+4)
                anchor(api,self.detail,self.detailContent,0,0,width-60,measured+4)
            end
        end
        local detailTop=height-42-detailHeight
        anchor(api,self.list,self.root,18,self.listTop,width-36,math.max(1,detailTop-self.listTop-(detailHeight>0 and 8 or 0)))
        anchor(api,self.notice,self.root,24,self.listTop+8,width-48,40)
        local detailControl=self.detailScroll or self.detail
        detailControl:SetHidden(detailHeight==0)
        anchor(api,detailControl,self.root,18,detailTop,width-36,detailHeight)
        if self.detailScroll then api.Scroll.UpdateScrollBar(self.detailScroll) end
        local actionWidth=width-36-(self.clear and not self.clear:IsControlHidden() and 148 or 0)
        anchor(api,self.action,self.root,18,height-30,math.max(1,actionWidth),24)
    end
    function v:SetDetail(text)
        self.detail:SetText(text or ''); self:LayoutBody()
    end
    function v:Place(options)
        local vw,vh=api.controls.GuiRoot:GetDimensions(); local width,height=math.max(1,math.min(790,vw-24)),math.max(1,math.min(700,vh-24))
        local origin=options and options.initiator
        local x=origin and origin.GetLeft and origin:GetLeft() or (vw-width)/2
        local y=origin and origin.GetTop and origin:GetTop() or (vh-height)/2
        x=math.max(0,math.min(x,vw-width)); y=math.max(0,math.min(y,vh-height))
        anchor(api,self.root,api.controls.GuiRoot,x,y,width,height); anchor(api,self.backdrop,self.root,0,0,width,height)
        anchor(api,self.close,self.root,width-36,18,20,20)
        self.title:SetDimensions(10000,32); local titleWidth=self.title:GetTextDimensions()
        local headerBottom=44; local titleSpace=width-68
        if self.tabs then
            local iconsWidth=4*36-4; local available=width-68-iconsWidth-12
            local sameRow=available>=math.min(140,titleWidth)
            titleSpace=sameRow and math.min(titleWidth,available) or width-68
            local tx,ty=sameRow and 18+titleSpace+12 or 18,sameRow and 12 or 48
            for _,id in ipairs({'named','common','active','recent'}) do
                if tx+32>width-18 then tx=18; ty=ty+36 end
                anchor(api,self.tabs[id],self.root,tx,ty,32,32); tx=tx+36
            end
            headerBottom=math.max(headerBottom,ty+32)
        end
        anchor(api,self.title,self.root,18,12,math.max(1,titleSpace),32)
        anchor(api,self.searchBackdrop,self.root,18,headerBottom+8,width-36,36); anchor(api,self.hint,self.root,18,headerBottom+46,width-36,20)
        self.filtersTop=headerBottom+72
        self.width,self.height=width,height; self:LayoutBody()
    end
    return v
end
Picker.Copy=copy -- DTO copying for the companion library, never controls/callbacks.
Picker.Locale=locale
Picker.RestoreFocus=restoreFocus
Picker.Anchor=anchor
Picker.Button=button
function Picker.New(catalog,history,store,session,api)
    sequence=sequence+1
    local self=setmetatable({catalog=catalog,history=history,store=store,session=session,api=api,cache={},cacheOrder={},items={},generation=0,
        section='named',level='pair',group='common',query='',name='KanaEffectsPicker'..sequence,labels=locale(api)},Picker)
    self.unsubscribeSession=session:Subscribe(function(draft) if not draft then self:Close() end end)
    return self
end
function Picker:IsOpen() return self.options~=nil end
function Picker:_CancelPending()
    if self.pending then self.api.eventManager:UnregisterForUpdate(self.name..'Search'); self.pending=nil end
    self.searchGeneration=(self.searchGeneration or 0)+1
end
function Picker:_Queue(query,invalidate)
    self.query=query; if invalidate then self.cache={}; self.cacheOrder={} end
    -- Source bursts coalesce without postponing an already scheduled search.
    if invalidate and self.pending then return end
    self:_CancelPending()
    if not self:IsOpen() then return end
    if not self.api or not self.api.eventManager then self:_Refresh(); return end
    local generation,searchGeneration=self.generation,self.searchGeneration; self.pending=true
    self.api.eventManager:RegisterForUpdate(self.name..'Search',150,function()
        if self.generation~=generation or self.searchGeneration~=searchGeneration or not self:IsOpen() or self.disposed then return end
        self:_CancelPending(); self:_Refresh()
    end)
end
function Picker:_Tags()
    local tags={player=true,reticleover=true}
    local c=self.api and self.api.constants or {}; local first,last=c.BOSS_RANK_ITERATION_BEGIN,c.BOSS_RANK_ITERATION_END
    if type(first)=='number' and type(last)=='number' and first>=1 and last>=first and last<math.huge and first%1==0 and last%1==0 then for i=first,last do tags['boss'..i]=true end end
    local draft=self.session:ReadDraft(); for _,w in ipairs(draft and draft.widgets or {}) do tags[w.unitTag]=true end
    for _,item in ipairs(pages(self.history,'Query','',{})) do for _,tag in ipairs(item.unitTags or {}) do tags[tag]=true end end
    local result={}; for tag in pairs(tags) do result[#result+1]=tag end; table.sort(result); return result
end
function Picker:_Active(query)
    local items={}; local normalize=self.api and self.api.NormalizeName or string.lower; query=normalize(query)
    local now=self.api and self.api.Now and self.api.Now()
    local recents={}
    for _,row in ipairs(pages(self.history,'Query','',{})) do recents[key(row)]=row end
    for _,tag in ipairs(self:_Tags()) do
        for _,obs in ipairs(self.store:ReadUnit(tag)) do
            if obs.synthetic==false and (obs.lifetime~='finite' or not now or (obs.endTime and obs.endTime>now)) then
                local meta=obs.catalog; local exact=string.match(query,'^%d+$') and tonumber(query)
                local selector=KanaEffects.Selectors.FromObservation(obs)
                local matches=exact and exact==selector.id or (not exact and (query=='' or string.find(normalize(meta.name or ''),query,1,true)))
                if not exact and not matches then for _,alias in ipairs(meta.aliases or {}) do if string.find(normalize(alias),query,1,true) then matches=true; break end end end
                if matches then
                    local recent=recents[KanaEffects.Selectors.Key(selector)..':'..tag]
                    items[#items+1]={selector=selector,name=meta.name or '',icon=meta.icon or '',selectable=(meta.name or '')~='' and (meta.icon or '')~='',
                    abilityIds={obs.abilityId},unitTags={tag},lastSeen=recent and recent.lastSeen or obs.observedAt,
                    lastSeenClock=recent and recent.lastSeenClock or 'session-frame-seconds',recentProvenance=recent and recent.provenance,
                    provenance=(meta.provenance or 'unknown')..';observed-scope:'..tag,
                    lifetime=obs.lifetime,remaining=now and obs.endTime and math.max(0,obs.endTime-now) or nil,source='active'} end
            end
        end
    end
    table.sort(items,function(a,b) return key(a)<key(b) end); return items
end
function Picker:_Build()
    local cacheKey=self.section..'\0'..self.level..'\0'..self.group..'\0'..self.query
    if (self.section=='active' or self.query~='') and self.api and self.api.Now then cacheKey=cacheKey..'\0'..tostring(self.api.Now()) end
    if self.cache[cacheKey] then return copy(self.cache[cacheKey]) end
    local items,seen={},{}
    local function append(rows,source)
        for _,item in ipairs(rows) do
            if item.selector.kind~='family' or self.query=='' or item.selector.level==self.level then
            item=copy(item); item.source=item.source or source
            if item.name=='' or ((item.selector.kind=='ability' or item.selector.kind=='artificial') and item.icon=='') then item.selectable=false; item.reason=item.reason or self.labels.unknown end
            if item.selector.kind=='category' and item.selector.id=='food' then item.name=self.labels.anyFood end
            if item.selector.kind=='family' and item.selector.level=='pair' then item.name=item.name..' · '..self.labels.pair end
            local id=key(item)
            if not seen[id] then seen[id]=item; items[#items+1]=item
            elseif item.source=='active' and seen[id].source~='active' then
                local previous=seen[id]
                previous.name=item.name; previous.icon=item.icon; previous.selectable=item.selectable; previous.reason=item.reason
                previous.recentProvenance=previous.provenance
                previous.provenance=item.provenance; previous.remaining=item.remaining; previous.lifetime=item.lifetime; previous.source=item.source
                if previous.lastSeen==nil then previous.lastSeen=item.lastSeen; previous.lastSeenClock=item.lastSeenClock end
            end
            end
        end
    end
    -- A typed search spans every provider, independent of the selected tab.
    if self.query~='' then
        append(pages(self.history,'Query',self.query,{}),'recent'); append(self:_Active(self.query),'active')
        append(pages(self.catalog,'Search',self.query,{}),'catalog')
        local normalize=self.api and self.api.NormalizeName or string.lower
        for _,translated in pairs(KanaEffects.Localization) do
            if string.find(normalize(translated.picker.anyFood),normalize(self.query),1,true) then
                append(pages(self.catalog,'Search','',{kind='category',category='food'}),'catalog'); break
            end
        end
        if #items==0 and string.match(self.query,'^%d+$') then items[1]={selector={kind='ability',id=tonumber(self.query)},name=self.labels.unknown,icon='',selectable=false,reason=self.labels.unknown,abilityIds={tonumber(self.query)},unitTags={},source='catalog',provenance='unknown'} end
    elseif self.section=='named' then append(pages(self.catalog,'Search','',{kind='family',level=self.level,group=self.group}),'catalog')
    elseif self.section=='common' then
        local rows=pages(self.catalog,'Search','',{})
        for _,item in ipairs(rows) do if item.selector.kind=='category' or item.selector.kind=='ability' or item.selector.kind=='artificial' then append({item},'catalog') end end
    elseif self.section=='recent' then append(pages(self.history,'Query','',{}),'recent')
    elseif self.section=='active' then append(self:_Active(''),'active') end
    self.cache[cacheKey]=copy(items); self.cacheOrder[#self.cacheOrder+1]=cacheKey
    if #self.cacheOrder>16 then self.cache[table.remove(self.cacheOrder,1)]=nil end
    return items
end
function Picker:GetItems() return copy(self.items) end
function Picker:DescribeItem(item,full)
    if not item then return '' end
    local parts={}; local selector=item.selector or {}
    if full then
        parts[#parts+1]=item.name
        if selector.kind=='artificial' and KanaEffects.Tooltip and KanaEffects.Tooltip.Compose then
            local _,_,body=KanaEffects.Tooltip.Compose({name=item.name,selector=selector},self.api)
            if body and body~='' then parts[#parts+1]=body end
        end
        local describe=KanaEffects.Tooltip and KanaEffects.Tooltip.AbilityDescription
        local seen={}
        for _,id in ipairs(item.abilityIds or {}) do
            local description=describe and describe(self.api,id)
            if description and not seen[description] then
                seen[description]=true
                local name=self.api and self.api.GetAbilityName and self.api.GetAbilityName(id)
                if #(item.abilityIds or {})>1 and name and name~='' then description=name..'\n'..description end
                parts[#parts+1]=description
            end
        end
        if item.selectable==false then parts[#parts+1]=self.labels.unavailable end
        return table.concat(parts,'\n\n')
    end
    if selector.kind=='ability' then parts[#parts+1]='ID '..tostring(selector.id)
    elseif selector.kind=='artificial' then parts[#parts+1]=(self.labels.artificialId or 'ID')..' '..tostring(selector.id)
    elseif selector.kind=='family' then parts[#parts+1]=self.labels[selector.level] end
    for _,tag in ipairs(item.unitTags or {}) do
        local source=tag=='player' and self.labels.player or tag=='reticleover' and self.labels.target
        local boss=string.match(tag,'^boss(%d+)$'); if boss then source=self.labels.boss..' '..boss end
        if source then parts[#parts+1]=source end
    end
    if item.source=='recent' then parts[#parts+1]=self.labels.recent end
    return table.concat(parts,' · ')
end
function Picker:_PlaceFilters()
    local view=self.view; if not view then return end
    local y=view.filtersTop or 116
    local showLevels=self.section=='named' or self.query~=''; local showGroups=self.section=='named' and self.query==''
    local levels={}; for _,id in ipairs({'pair','minor','major'}) do local b=view.levels[id]; b:SetHidden(not showLevels); Picker.StyleButton(b,'secondary',id==self.level); levels[#levels+1]=b end
    if showLevels then y=view:ButtonRows(levels,y) end
    local groups={}; for _,id in ipairs({'common','pvpRare'}) do local b=view.groups[id]; b:SetHidden(not showGroups); Picker.StyleButton(b,'secondary',id==self.group); groups[#groups+1]=b end
    if showGroups then y=view:ButtonRows(groups,y) end
    view:LayoutBody(y+6)
end
function Picker:_Refresh()
    if not self:IsOpen() then return end
    local previous=self.items[self.selected or 0]; local wanted=previous and key(previous) or (self.options.currentSelector and KanaEffects.Selectors.Key(self.options.currentSelector))
    self.items=self:_Build(); self.selected=nil
    for i,item in ipairs(self.items) do if item.selectable then if not self.selected then self.selected=i end; if key(item)==wanted or KanaEffects.Selectors.Key(item.selector)==wanted then self.selected=i end end end
    if self.view then
        self.view:SetItems(self.items); self.view:SetDetail(self:DescribeItem(self.items[self.selected or 0],true))
        self.view.notice:SetText(#self.items==0 and self.labels.noResults or ''); self.view.notice:SetHidden(#self.items>0)
        for name,b in pairs(self.view.tabs) do Picker.StyleTab(b,name==self.section) end
        self:_PlaceFilters()
    end
end
function Picker:SetQuery(query)
    self:_CancelPending(); self.query=text(query); self:_Refresh()
end
function Picker:SetSection(section) assert(sections[section],'Unknown picker section'); self.section=section; self:_Refresh() end
function Picker:SetLevel(level) assert(level=='pair' or level=='minor' or level=='major','Unknown family level'); self.level=level; self:_Refresh() end
function Picker:SetGroup(group) assert(group=='common' or group=='pvpRare','Unknown picker group'); self.group=group; self:_Refresh() end
function Picker:MoveSelection(direction)
    if not self:IsOpen() then return end
    local index=(self.selected or (direction>0 and 0 or #self.items+1))+direction
    while self.items[index] and not self.items[index].selectable do index=index+direction end
    if self.items[index] then self.selected=index; if self.view then
        self.view:SetDetail(self:DescribeItem(self.items[index],true))
        self.api.ScrollList.RefreshVisible(self.view.list)
        if self.api.ScrollList.ScrollDataIntoView then self.api.ScrollList.ScrollDataIntoView(self.view.list,index,nil,true) end
    end end
end
function Picker:_Finish(cancel)
    if not self:IsOpen() then return end
    local options=self.options; self.options=nil; self.generation=self.generation+1; self:_CancelPending()
    if self.unsubscribeStore then self.unsubscribeStore(); self.unsubscribeStore=nil end
    if self.view then self.view.search:LoseFocus(); self.view.root:SetHidden(true); self.view:SetItems({}) end
    self.items={}; self.cache={}; self.cacheOrder={}; self.selected=nil
    if not self.disposed then restoreFocus(options,self.api) end
    if cancel and options.onCancel then options.onCancel() end
    return options
end
function Picker:Choose(index)
    if self.pending then
        -- Typed Enter applies the newest text immediately; clicks on stale rows
        -- wait until the displayed search result has caught up.
        if index then return false end
        self:_CancelPending(); self:_Refresh()
    end
    local item=self.items[index or self.selected or 0]
    if not self:IsOpen() or not item or not item.selectable then return false end
    local selector=copy(item.selector)
    -- History/active metadata remains usable even when API no longer knows an
    -- observed ID. Curated family/category availability is always catalog-owned.
    if selector.kind~='ability' and not self.catalog:ValidateSelector(selector) then return false end
    local callback=self.options.onChoose; local options=self:_Finish(false)
    if callback then callback(selector) end
    return options~=nil
end
function Picker:ClearSelection()
    if not self:IsOpen() or not self.options.onClear then return false end
    local callback=self.options.onClear; self:_Finish(false); callback(); return true
end
function Picker:Escape()
    if not self:IsOpen() then return false end
    local router=self.options.onEscape; if router then router() else self:Close() end; return true
end
function Picker:Open(options)
    assert(not self.disposed,'Picker disposed'); assert(type(options)=='table','Picker options required')
    assert(self.session:ReadDraft(),'Begin editing first')
    self:Close(); self.options=options; self.generation=self.generation+1; self.cache={}; self.cacheOrder={}; self.query=''; self.selected=nil
    if not self.view then
        local function choose(item) for i,current in ipairs(self.items) do if item==current then return self:Choose(i) end end end
        self.view=Picker.CreatePanel(self.api,self.name,self.labels.title,{close=function() self:Close() end,search=function(q) self:_Queue(q) end,
            enter=function() self:Choose() end,escape=function() self:Escape() end,move=function(d) self:MoveSelection(d) end,
            choose=choose,inspect=function(item) if self.view then self.view:SetDetail(self:DescribeItem(item or self.items[self.selected or 0],true)) end end,
            describe=function(item) return self:DescribeItem(item) end,isSelected=function(item) return self.items[self.selected or 0]==item end,generation=function() return self.generation end})
        if self.view then
            self.view.tabs={}; self.view.levels={}; self.view.groups={}
            for i,section in ipairs({'named','common','active','recent'}) do
                local id=section; self.view.tabs[id]=Picker.IconTab(self.api,self.view.root,self.name..id,id,self.labels[id],function() self:SetSection(id) end)
            end
            for _,level in ipairs({'pair','minor','major'}) do local id=level; self.view.levels[id]=button(self.api,self.view.root,self.name..id,self.labels[id],function() self:SetLevel(id) end) end
            for _,group in ipairs({'common','pvpRare'}) do local id=group; self.view.groups[id]=button(self.api,self.view.root,self.name..'Group'..id,self.labels[id=='common' and 'commonGroup' or 'pvpRare'],function() self:SetGroup(id) end) end
            self.view.clear=button(self.api,self.view.root,self.name..'Clear',self.labels.clear,function() self:ClearSelection() end)
        end
    end
    self.unsubscribeStore=self.store:Subscribe(function() self:_Queue(self.query,true) end)
    if self.view then
        self.view:Place(options); local width=self.view.width
        self.view.action:SetText(self.labels.enterHint)
        anchor(self.api,self.view.clear,self.view.root,width-158,self.view.height-30,140,24); self.view.clear:SetHidden(not options.onClear)
        local generation=self.generation
        self.view.clear:SetHandler('OnClicked',function() if generation==self.generation then self:ClearSelection() end end)
        self.view:BindInput()
        self.view.search:SetText('',true); self.view.root:SetHidden(false); self.view.root:BringWindowToTop(); self.view.search:TakeFocus()
    end
    self:_Refresh()
end
function Picker:Close() self:_Finish(true) end
function Picker:Dispose()
    if self.disposed then return end; self.disposed=true; self:Close(); self.unsubscribeSession()
    if self.view then
        self.view.search:SetHandler('OnTextChanged',nil); self.view.search:SetHandler('OnEscape',nil); self.view.search:SetHandler('OnEnter',nil); self.view.search:SetHandler('OnKeyDown',nil)
        self.view.root:SetHidden(true)
    end
end
