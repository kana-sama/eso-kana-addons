-- Native label metrics and screen anchors; product owns content layout.
dofile(TEST_ROOT..'/ui/Tooltip.lua')
local A=TestSupport.Assert
local function setup(width,height)
    local api={constants={TOPLEFT='tl',TOPRIGHT='tr',BOTTOMLEFT='bl',BOTTOMRIGHT='br',TOP='t',DT_HIGH=2,
        CT_LABEL='label',TEXT_ALIGN_CENTER='center',TEXT_ALIGN_LEFT='left'},controls={}}
    local screen={width=width or 1000,height=height or 700,x=0,y=0}; api.controls.GuiRoot=screen
    function screen:GetDimensions() return self.width,self.height end
    function screen:GetLeft() return self.x*(api.scale or 1) end; function screen:GetTop() return self.y*(api.scale or 1) end
    function screen:GetScale() return api.scale or 1 end
    function screen:GetScreenRect() local s=self:GetScale(); return self.x*s,self.y*s,(self.x+self.width)*s,(self.y+self.height)*s end
    api.x,api.y=100,100; api.GetUIMousePosition=function() error('tooltips must never read the cursor') end
    local function plain(text) return text:gsub('|c%x%x%x%x%x%x',''):gsub('|r','') end
    local function metrics(text,width,font)
        text=plain(text); local max,lines=0,0; local char=font=='ZoFontTooltipTitle' and 11 or 9
        for s in (text..'\n'):gmatch('(.-)\n') do
            local n=0; for c in s:gmatch('[%z\1-\127\194-\244][\128-\191]*') do n=n+1 end
            max=math.max(max,n*char); lines=lines+math.max(1,math.ceil(n*char/math.max(1,width or 1000000)))
        end
        return math.min(max,width or 1000000),lines*(font=='ZoFontTooltipTitle' and 24 or (api.lineHeight or 20))
    end
    local function control()
        local c={handlers={},width=0,height=0,x=0,y=0,lines={}}
        function c:SetMouseEnabled(v) self.mouse=v end; function c:SetDrawTier(v) end
        function c:SetHidden(v) self.hidden=v end; function c:IsControlHidden() return self.hidden==true end
        function c:SetHandler(name,fn) self.handlers[name]=fn end
        function c:ClearAnchors() self.anchorTo=nil end
        function c:SetAnchor(point,owner,relative,x,y) self.point,self.anchorTo,self.x,self.y=point,owner,x,y end
        function c:SetDimensions(w,h) self.width,self.height=w,h end
        function c:GetDimensions() return self.width,self.height end
        function c:SetClampedToScreen(v) end; function c:SetClampedToScreenInsets(...) end
        function c:SetAutoRectClipChildren(v) end
        function c:SetResizeToFitPadding(w,h) self.paddingWidth,self.paddingHeight=w,h end
        function c:SetResizeToFitDescendents(value) self.resizeToFit=value end
        function c:SetDimensionConstraints(minw,minh,maxw,maxh) self.minw,self.maxw,self.maxh=minw,maxw,maxh end
        function c:ClearLines() self.text=''; self.height=0; self.lines={} end
        function c:SetOwner(owner,point,x,y,relative)
            self.anchorOwner=owner; self.point=point
            -- Native anchor offsets are UI units; owner screen edges include scale.
            self.x=owner:GetLeft()/self:GetScale()+x; self.y=owner:GetTop()/self:GetScale()+y
            self.ownerWrites=(self.ownerWrites or 0)+1
        end
        function c:GetScale() return (api.scale or 1)*(self.localScale or 1) end
        function c:GetLeft() return (self.anchorTo and self.anchorTo:GetLeft() or 0)+self.x*(api.scale or 1)-((self.point=='tr' or self.point=='br') and self.width*self:GetScale() or 0) end
        function c:GetTop() return (self.anchorTo and self.anchorTo:GetTop() or 0)+self.y*(api.scale or 1)-((self.point=='bl' or self.point=='br') and self.height*self:GetScale() or 0) end
        function c:GetScreenRect() local x,y=self:GetLeft(),self:GetTop(); local s=self:GetScale(); return x,y,x+self.width*s,y+self.height*s end
        function c:SetFont(font) self.font=font end
        function c:SetText(text) self.text=text; api.textWrites=(api.textWrites or 0)+1 end
        function c:SetColor(...) self.color={...} end
        function c:SetHorizontalAlignment(value) self.align=value end
        function c:GetTextDimensions() api.measures=(api.measures or 0)+1; return metrics(self.text,self.width>0 and self.width or nil,self.font) end
        return c
    end
    api.controls.CreateTopLevelWindow=function() return control() end
    api.controls.CreateControlFromVirtual=function() return control() end
    api.controls.CreateControl=function() return control() end
    api.InitializeTooltip=function(c,owner,point,x,y,relative) c:ClearLines(); c:SetOwner(owner,point,x,y,relative); c.hidden=false end
    api.SetTooltipText=function() error('must use separately styled native lines') end
    api.clears=0; api.ClearTooltipImmediately=function(c) api.clears=api.clears+1; c.hidden=true end
    api.GetAbilityDescription=function(id,rank,caster) A.Equal(rank,nil); return 'Restores your health.' end
    local tip=KanaEffects.Tooltip.New(api); local owner=control(); owner.x,owner.y,owner.width,owner.height=100,100,48,48
    local entry={name='Heal',selector={kind='ability',id=123},active=true,contributors={}}
    return tip,api,owner,entry
end
local function renderedLines(tip)
    local lines={}
    for _,label in ipairs({tip.titleLabel,tip.bodyLabel}) do if not label.hidden then lines[#lines+1]=label end end
    return lines
end
local function renderedText(tip)
    local texts={}; for _,label in ipairs(renderedLines(tip)) do texts[#texts+1]=label.text end
    return table.concat(texts,'\n')
end
local function contained(tip,api)
    local c=tip.control; local screen=api.controls.GuiRoot; local w,h=screen:GetDimensions()
    A.True(c:GetLeft()>=screen.x); A.True(c:GetTop()>=screen.y)
    A.True(c:GetLeft()+c.width<=screen.x+w); A.True(c:GetTop()+c.height<=screen.y+h)
end
local function separated(tip,owner)
    local c=tip.control
    assert(c:GetLeft()>=owner.x+owner.width+8 or c:GetLeft()+c.width<=owner.x-8 or
        c:GetTop()>=owner.y+owner.height+8 or c:GetTop()+c.height<=owner.y-8,'tooltip overlaps its icon or lacks gap')
end
Tests.tooltip_is_content_sized_with_centered_native_bold_title_and_intact_color_spans=function()
    local tip,api,owner,e=setup(); api.GetAbilityDescription=function() return 'Restore |cffffff123|r Health.' end
    tip:Enter('w',e,owner); contained(tip,api); separated(tip,owner)
    local title,body=tip.titleLabel,tip.bodyLabel
    A.Equal(title.text,'Heal'); A.Equal(title.font,'ZoFontGameBold'); A.Equal(title.align,'center')
    A.Equal(body.font,'ZoFontGame'); A.Equal(body.text,'Restore |cffffff123|r Health.'); A.Equal(body.align,'left')
    assert(tip.control.width<300 and tip.control.height<110,'short tooltip has excess blank space')
    api.GetAbilityDescription=function() return nil end; tip:Enter('w',e,owner)
    A.Equal(#renderedLines(tip),1); assert(tip.control.width<100 and tip.control.height<70,'title-only tooltip must shrink')
end
Tests.tooltip_uses_actual_icon_anchor_and_flips_at_edges=function()
    for _,p in ipairs({{100,100},{940,100},{940,640},{0,0},{0,640}}) do
        local tip,api,root,e=setup(); local icon={x=p[1],y=p[2],width=48,height=48,GetLeft=root.GetLeft,GetTop=root.GetTop,GetDimensions=root.GetDimensions,GetScale=root.GetScale,GetScreenRect=root.GetScreenRect}
        tip:Enter('w',e,root,icon); A.Equal(tip.control.anchorOwner,icon); contained(tip,api); separated(tip,icon)
    end
end
Tests.tooltip_selects_vertical_space_when_horizontal_sides_cannot_fit=function()
    local tip,api,owner,e=setup(400,300); owner.x,owner.y,owner.width,owner.height=100,100,200,48
    tip:Enter('w',e,owner); contained(tip,api); separated(tip,owner)
    assert(tip.control:GetTop()>=owner.y+owner.height+8,'should use the unobstructed space below the icon')
end
Tests.tooltip_does_not_follow_mouse_or_remeasure_unchanged_hover=function()
    local tip,api,owner,e=setup(); tip:Enter('w',e,owner)
    local writes,measures,x,y=api.textWrites,api.measures,tip.control.x,tip.control.y
    for i=1,10 do api.x,api.y=i*90,i*60; tip.root.handlers.OnUpdate() end
    A.Equal(tip.control.x,x); A.Equal(tip.control.y,y); A.Equal(api.textWrites,writes); A.Equal(api.measures,measures)
    tip:Enter('w',e,owner); A.Equal(api.textWrites,writes)
    owner.x,owner.y=920,610; tip.root.handlers.OnUpdate(); contained(tip,api); separated(tip,owner)
    A.Equal(api.textWrites,writes)
    tip:Exit(nil,nil,{}); A.Equal(api.clears,0)
    local stale=tip.root.handlers.OnUpdate; tip:Exit(nil,nil,owner); A.Equal(api.clears,1); A.Equal(tip.root.handlers.OnUpdate,nil)
    stale(); A.Equal(api.clears,1); tip:Enter('w',e,owner); tip:Dispose(); A.Equal(tip.root.handlers.OnUpdate,nil); A.True(tip.root.hidden)
end
Tests.tooltip_long_description_fits_without_cut_utf8_or_open_color_markup=function()
    local tip,api,owner,e=setup(300,180); owner.x,owner.y=120,65
    api.GetAbilityDescription=function() return string.rep('|cffffffВосстановление здоровья|r. ',200) end
    tip:Enter('w',e,owner); contained(tip,api); separated(tip,owner)
    A.True(tip.truncated); A.True(renderedText(tip):find('Heal',1,true)~=nil); A.True(renderedText(tip):find('…',1,true)~=nil)
    local bytes=renderedText(tip); local i=1; local color=false
    while i<=#bytes do
        if bytes:sub(i,i+1)=='|c' then assert(bytes:sub(i+2,i+7):match('^%x%x%x%x%x%x$')); color=true; i=i+8
        elseif bytes:sub(i,i+1)=='|r' then color=false; i=i+2
        else local b=bytes:byte(i); local n=b<128 and 1 or b>=240 and 4 or b>=224 and 3 or b>=192 and 2 or 0
            A.True(n>0); for j=1,n-1 do local nextByte=bytes:byte(i+j); A.True(nextByte and nextByte>=128 and nextByte<192) end; i=i+n end
    end
    A.False(color)
end
Tests.tooltip_reflows_for_content_viewport_and_owner_geometry_changes=function()
    local tip,api,owner,e=setup(); tip:Enter('w',e,owner)
    local w=tip.control.width; api.GetAbilityDescription=function() return string.rep('Long description. ',2000) end
    tip:Enter('w',e,owner); assert(tip.control.width>w)
    api.controls.GuiRoot.width,api.controls.GuiRoot.height=300,180; tip.root.handlers.OnUpdate(); contained(tip,api); separated(tip,owner)
    api.controls.GuiRoot.width,api.controls.GuiRoot.height=1000,700
    api.GetAbilityDescription=function() return 'Short description.' end
    tip:Enter('w',e,owner); contained(tip,api); A.False(tip.truncated)
    assert(tip.control.width<300); A.Equal(renderedText(tip):find('…',1,true),nil)
end
Tests.tooltip_hidden_owner_and_empty_content_leave_no_hover_polling=function()
    local tip,api,owner,e=setup(); owner.hidden=true
    tip:Enter('w',e,owner); A.Equal(tip.root and tip.root.handlers.OnUpdate,nil)
    owner.hidden=false; api.GetAbilityDescription=function() return '' end; e.name=''
    tip:Enter('w',e,owner); A.Equal(tip.root and tip.root.handlers.OnUpdate,nil); A.Equal(tip.owner,nil)
end

Tests.tooltip_content_is_human_description_without_observation_dump=function()
    local tip,api,owner,e=setup(); e.uncertain=true; e.hiddenInGrids=true; e.snapshot={title='Boss',observedAt=12,openedAt=34}
    e.contributors={{abilityId=123,kind='buff',castBy='self',unit={tag='boss1',name='Boss'},lifetime='unknown',sourceType=7,stacks=1,catalog={name='Heal'}}}
    local value=KanaEffects.Tooltip.Compose(e,api)
    A.True(value:find('Heal',1,true)~=nil); A.True(value:find('Restores your health.',1,true)~=nil)
    for _,bad in ipairs({'123','boss1','12','34','?','ID:','неизвест','Наблюда','источник'}) do A.Equal(value:find(bad,1,true),nil) end
end
Tests.tooltip_pair_descriptions_keep_minor_before_major_without_duplicates=function()
    local _,api=setup(); api.GetAbilityDescription=function(id,rank,caster) A.Equal(caster,nil); return id==1 and 'Small protection.' or 'Large protection.' end
    local e={name='Protection',pair=true,selector={kind='family',id='protection',level='pair'},contributors={
        {abilityId=2,castBy='other',catalog={name='Major Protection',level='major'}},
        {abilityId=1,castBy='unknown',catalog={name='Minor Protection',level='minor'}},
        {abilityId=1,castBy='unknown',catalog={name='Minor Protection',level='minor'}}}}
    for _,row in ipairs(e.contributors) do row.unit={tag='player',name='Player'}; row.lifetime='finite'; row.endTime=60; row.stacks=1 end
    local value=KanaEffects.Tooltip.Compose(e,api); local minor=value:find('Small protection.',1,true); local major=value:find('Large protection.',1,true)
    A.True(minor~=nil and major~=nil and minor<major); A.Equal(value:find('Small protection.',minor+1,true),nil)
end
Tests.tooltip_absent_native_description_does_not_invent_unknown_prose=function()
    local _,api,_,e=setup(); api.GetAbilityDescription=function() return '?' end
    A.Equal(KanaEffects.Tooltip.Compose(e,api),'Heal')
    api.GetAbilityDescription=function() error('unavailable') end; A.Equal(KanaEffects.Tooltip.Compose(e,api),'Heal')
end
Tests.tooltip_uses_only_reported_self_caster_for_native_description=function()
    local _,api,_,e=setup(); local seen={}
    api.GetAbilityDescription=function(id,rank,caster) seen[#seen+1]=caster or 'none'; return 'Useful effect.' end
    e.contributors={{abilityId=123,castBy='self',unit={tag='boss1'},catalog={name='Heal'}}}
    KanaEffects.Tooltip.Compose(e,api); A.Equal(seen[1],'player')
    e.contributors[1].castBy='other'; KanaEffects.Tooltip.Compose(e,api); A.Equal(seen[2],'none')
end
Tests.tooltip_artificial_effect_uses_native_body_without_ability_id=function()
    local tip,api,owner,e=setup(); local calls=0
    api.GetAbilityDescription=function() error('artificial effect has no ability ID') end
    api.GetArtificialEffectTooltipText=function(id) A.Equal(id,7); calls=calls+1; return 'Gain |cffffff10%|r experience.' end
    e.name='ESO Plus'; e.selector={kind='artificial',id=7}
    e.contributors={{artificialEffectId=7,catalog={name='ESO Plus'}}}
    tip:Enter('w',e,owner); A.Equal(calls,1); A.Equal(renderedLines(tip)[2].text,'Gain |cffffff10%|r experience.')
end
Tests.tooltip_keeps_gap_for_partly_clipped_icons_and_offset_viewport=function()
    for _,p in ipairs({{-40,100},{990,100},{100,-40},{100,690}}) do
        local tip,api,owner,e=setup(); owner.x,owner.y=p[1],p[2]
        tip:Enter('w',e,owner); contained(tip,api); separated(tip,owner)
    end
    local tip,api,owner,e=setup(); api.controls.GuiRoot.x,api.controls.GuiRoot.y=50,60; owner.x,owner.y=70,80
    tip:Enter('w',e,owner); contained(tip,api); separated(tip,owner)
end
local function activePlayerEffect(api,entry,id,slot)
    entry.selector={kind='ability',id=id}
    entry.contributors={{abilityId=id,effectSlot=slot,unit={tag='player'},startTime=25,synthetic=false,catalog={name=entry.name}}}
    api.GetNumBuffs=function(tag) A.Equal(tag,'player'); api.buffScans=(api.buffScans or 0)+1; return 1 end
    api.GetUnitBuffInfo=function(tag,index)
        A.Equal(tag,'player'); A.Equal(index,1)
        return entry.name,25,25,slot,0,'effect.dds',nil,1,nil,nil,id
    end
end
Tests.tooltip_live_player_effect_description_precedes_generic_ability_text=function()
    local tip,api,owner,e=setup(); activePlayerEffect(api,e,100,37)
    api.GetAbilityDescription=function() return 'Generic skill text.' end
    api.GetAbilityEffectDescription=function(slot) A.Equal(slot,37); return 'Speed increases by |cffffff15|r%.' end
    tip:Enter('w',e,owner)
    A.Equal(renderedLines(tip)[2].text,'Speed increases by |cffffff15|r%.'); A.Equal(api.buffScans,1)
end
Tests.tooltip_active_effect_body_remains_available_when_ability_description_is_empty=function()
    local tip,api,owner,e=setup(); activePlayerEffect(api,e,999,6)
    api.GetAbilityDescription=function() return '' end
    api.GetAbilityEffectDescription=function(slot) A.Equal(slot,6); return 'Effect description.' end
    tip:Enter('w',e,owner); A.Equal(renderedLines(tip)[2].text,'Effect description.')
end
Tests.tooltip_effect_slot_description_never_reads_target_demo_or_stale_player_slot=function()
    for _,kind in ipairs({'target','demo','reused','reapplied','gone'}) do
        local _,api,_,e=setup(); activePlayerEffect(api,e,100,37)
        local effectReads=0; api.GetAbilityEffectDescription=function() effectReads=effectReads+1; return 'Unrelated player effect.' end
        if kind=='target' then e.contributors[1].unit.tag='reticleover'
        elseif kind=='demo' then e.contributors[1].synthetic=true
        elseif kind=='reused' then e.contributors[1].abilityId=101
        elseif kind=='reapplied' then e.contributors[1].startTime=24
        else api.GetNumBuffs=function() return 0 end end
        local _,_,body=KanaEffects.Tooltip.Compose(e,api); A.Equal(body,'Restores your health.'); A.Equal(effectReads,0)
        if kind=='target' or kind=='demo' then A.Equal(api.buffScans,nil) end
    end
end
Tests.tooltip_effect_description_empty_or_unavailable_falls_back_without_unknown_text=function()
    local _,api,_,e=setup(); activePlayerEffect(api,e,100,37)
    for _,getter in ipairs({function() return '' end,function() return '?' end,function() error('unavailable') end}) do
        api.GetAbilityEffectDescription=getter
        local _,_,body=KanaEffects.Tooltip.Compose(e,api); A.Equal(body,'Restores your health.')
    end
end
Tests.tooltip_pair_effect_descriptions_share_one_live_scan_and_keep_minor_major_order=function()
    local _,api,_,e=setup(); e.name='Pair'; e.selector={kind='family',id='pair',level='pair'}
    e.contributors={{abilityId=100,effectSlot=8,unit={tag='player'},catalog={name='Major',level='major'}},
        {abilityId=200,effectSlot=7,unit={tag='player'},catalog={name='Minor',level='minor'}}}
    api.GetNumBuffs=function() api.buffScans=(api.buffScans or 0)+1; return 2 end
    api.GetUnitBuffInfo=function(_,i) return 'Effect',0,0,9-i,0,'effect.dds',nil,1,nil,nil,i*100 end
    api.GetAbilityEffectDescription=function(slot) return slot==7 and 'Minor body.' or 'Major body.' end
    local _,_,body=KanaEffects.Tooltip.Compose(e,api); A.Equal(body,'Minor\nMinor body.\n\nMajor\nMajor body.'); A.Equal(api.buffScans,1)
end
Tests.tooltip_excludes_entire_effect_row_but_keeps_native_icon_owner=function()
    local tip,api,owner,e=setup(); owner.width=330; owner.height=48
    local icon={x=owner.x,y=owner.y,width=48,height=48,GetLeft=owner.GetLeft,GetTop=owner.GetTop,GetDimensions=owner.GetDimensions,GetScale=owner.GetScale,GetScreenRect=owner.GetScreenRect}
    tip:Enter('w',e,owner,icon); A.Equal(tip.control.anchorOwner,icon); separated(tip,owner); contained(tip,api)
    for _,width in ipairs({550,850}) do owner.width=width; tip.root.handlers.OnUpdate(); separated(tip,owner); contained(tip,api) end
end
Tests.tooltip_duplicate_ability_contributors_can_use_the_valid_live_slot=function()
    local _,api,_,e=setup(); activePlayerEffect(api,e,100,37)
    table.insert(e.contributors,1,{abilityId=100,effectSlot=36,unit={tag='player'},catalog={name=e.name}})
    local reads=0; api.GetAbilityEffectDescription=function(slot) A.Equal(slot,37); reads=reads+1; return 'Current effect.' end
    local _,_,body=KanaEffects.Tooltip.Compose(e,api); A.Equal(body,'Current effect.'); A.Equal(reads,1); A.Equal(api.buffScans,1)
end

Tests.tooltip_formats_localized_names_and_descriptions_before_measuring=function()
    local tip,api,owner,e=setup()
    local raw='восстанавливает |cffffff123|r здоровья.\n|t16:16:effect.dds|t Дополнительный эффект.'
    local formatted='Восстанавливает |cffffff123|r здоровья.\n|t16:16:effect.dds|t Дополнительный эффект.'
    api.zo_strformat=function(format,text)
        A.Equal(format,'<<C:1>>')
        if text=='лечение^n' then return 'Лечение' end
        if text==raw then return formatted end
        return text
    end
    e.name='лечение^n'; api.GetAbilityDescription=function() return raw end
    tip:Enter('w',e,owner)
    A.Equal(tip.title,'Лечение'); A.Equal(tip.body,formatted)
    A.Equal(renderedLines(tip)[1].text,'Лечение'); A.Equal(renderedLines(tip)[2].text,formatted)
    contained(tip,api); separated(tip,owner)
end
Tests.tooltip_formats_applied_and_artificial_effect_prose_with_native_sentence_formatter=function()
    for _,source in ipairs({'player','artificial'}) do
        local tip,api,owner,e=setup()
        local raw='увеличивает скорость на |cffffff15|r%.'
        api.zo_strformat=function(format,text)
            A.Equal(format,'<<C:1>>')
            return text==raw and 'Увеличивает скорость на |cffffff15|r%.' or text
        end
        if source=='player' then
            activePlayerEffect(api,e,100,37)
            api.GetAbilityEffectDescription=function(slot) A.Equal(slot,37); return raw end
        else
            e.selector={kind='artificial',id=7}; e.contributors={}
            api.GetArtificialEffectTooltipText=function(id) A.Equal(id,7); return raw end
        end
        tip:Enter('w',e,owner)
        A.Equal(renderedLines(tip)[2].text,'Увеличивает скорость на |cffffff15|r%.')
    end
end
Tests.tooltip_formats_each_pair_member_before_joining_the_description=function()
    local _,api,_,e=setup(); e.name='защита'; e.selector={kind='family',id='protection',level='pair'}
    e.contributors={{abilityId=1,catalog={name='малая защита^f',level='minor'}},
        {abilityId=2,catalog={name='великая защита^f',level='major'}}}
    local names={['защита']='Защита',['малая защита^f']='Малая защита',['великая защита^f']='Великая защита',
        ['снижает урон на 5%.']='Снижает урон на 5%.',['снижает урон на 10%.']='Снижает урон на 10%.'}
    api.zo_strformat=function(format,text) A.Equal(format,'<<C:1>>'); return names[text] or text end
    api.GetAbilityDescription=function(id) return id==1 and 'снижает урон на 5%.' or 'снижает урон на 10%.' end
    local _,title,body=KanaEffects.Tooltip.Compose(e,api)
    A.Equal(title,'Защита'); A.Equal(body,'Малая защита\nСнижает урон на 5%.\n\nВеликая защита\nСнижает урон на 10%.')
end

Tests.tooltip_title_width_uses_the_compact_native_font_that_is_rendered=function()
    local tip,api,owner,e=setup(); e.name='Protective effect'; api.GetAbilityDescription=function() return '' end
    tip:Enter('w',e,owner)
    -- 17 glyphs at the fixture's native18 font width9, plus32 tooltip padding.
    -- A lingering22px title measurement creates unused horizontal space.
    A.Equal(tip.control.width,185); A.Equal(renderedLines(tip)[1].font,'ZoFontGameBold')
    contained(tip,api); separated(tip,owner)
end

-- Removing centering, row exclusion, or screen-to-UI conversion must break these.
Tests.tooltip_named_row_prefers_left_and_centers_with_row_not_icon=function()
    local tip,api,owner,e=setup(); owner.x,owner.y,owner.width,owner.height=400,250,260,100
    owner._kanaTooltipSide='left'
    local icon=api.controls.CreateControl(); icon.x,icon.y,icon.width,icon.height=400,276,48,48
    tip:Enter('w',e,owner,icon)
    A.Equal(tip.control:GetLeft()+tip.control.width,392)
    A.Equal(tip.control:GetTop()+tip.control.height/2,300)
    contained(tip,api); separated(tip,owner)
end
Tests.tooltip_left_preference_flips_and_center_clamps_at_viewport_edges=function()
    for _,y in ipairs({0,640}) do
        local tip,api,owner,e=setup(); owner.x,owner.y,owner.width=20,y,330; owner._kanaTooltipSide='left'
        tip:Enter('w',e,owner)
        A.Equal(tip.control:GetLeft(),358); contained(tip,api); separated(tip,owner)
        A.Equal(tip.control:GetTop(),y==0 and 8 or 692-tip.control.height)
    end
end
Tests.tooltip_uses_scaled_screen_rect_union_and_ui_anchor_offsets=function()
    for _,scale in ipairs({0.8,1.4}) do
        local tip,api,owner,e=setup(); api.scale=scale
        owner.x,owner.y,owner.width,owner.height=350,250,240,40; owner.localScale=1.5
        local icon=api.controls.CreateControl(); icon.x,icon.y,icon.width,icon.height=340,260,48,48
        -- Native union is [340,250,710,310] UI units, not [340,250,590,298].
        tip:Enter('w',e,owner,icon)
        A.Equal(tip.control.anchorOwner,icon)
        assert(math.abs(tip.control:GetLeft()/scale-718)<0.001,'right tooltip overlaps scaled row')
        assert(math.abs((tip.control:GetTop()/scale+tip.control.height/2)-280)<0.001,'scaled row center differs')
        -- Scale changes during hover must update placement without changing prose.
        api.scale=scale+0.1; tip.root.handlers.OnUpdate()
        assert(math.abs(tip.control:GetLeft()/api.scale-718)<0.001,'scale change moved relative anchor')
        owner._kanaTooltipSide='left'; tip.root.handlers.OnUpdate()
        assert(math.abs(tip.control:GetLeft()/api.scale+tip.control.width-332)<0.001,'left tooltip overlaps protruding icon')
    end
end

Tests.tooltip_title_only_has_balanced_measured_content_insets_and_outer_center=function()
    for _,scale in ipairs({0.8,1,1.4}) do
        local tip,api,owner,e=setup(); api.scale=scale; api.lineHeight=23.5
        owner.x,owner.y,owner.width,owner.height=450,250,330,48; owner._kanaTooltipSide='left'
        api.GetAbilityDescription=function() return '' end
        tip:Enter('w',e,owner)
        local title=assert(tip.titleLabel,'tooltip needs independently measured native content bounds')
        local _,tt,_,tb=title:GetScreenRect(); local _,ot,_,ob=tip.control:GetScreenRect()
        assert(math.abs((tt-ot)/scale-16)<0.001,'title top inset differs')
        assert(math.abs((ob-tb)/scale-16)<0.001,'title bottom inset differs')
        assert(math.abs((ot+ob)/(2*scale)-274)<0.001,'visible outer frame is not vertically centered')
        A.Equal(tip.control.height,title.height+32); A.Equal(#renderedLines(tip),1)
    end
end
Tests.tooltip_wrapped_body_uses_native_content_height_and_no_residual_gap_when_removed=function()
    local tip,api,owner,e=setup(); owner.x,owner.y=500,300
    api.GetAbilityDescription=function() return string.rep('Effect description. ',5) end
    tip:Enter('w',e,owner)
    local title=assert(tip.titleLabel,'title content must have native measured bounds')
    local body=assert(tip.bodyLabel,'body content must have native measured bounds')
    A.True(body.height>20)
    A.Equal(body:GetTop()-(title:GetTop()+title.height),6)
    A.Equal(tip.control:GetTop()+tip.control.height-(body:GetTop()+body.height),16)
    A.Equal(tip.control:GetTop()+tip.control.height/2,324)
    api.GetAbilityDescription=function() return '' end; tip:Enter('w',e,owner)
    A.True(body.hidden); A.Equal(tip.control.height,title.height+32)
    A.Equal(tip.control:GetTop()+tip.control.height/2,324)
end

Tests.tooltip_description_without_title_has_no_heading_gap=function()
    local tip,api,owner,e=setup(); e.name=''; owner.y=300
    tip:Enter('w',e,owner)
    A.True(tip.titleLabel.hidden); A.False(tip.bodyLabel.hidden)
    A.Equal(tip.bodyLabel:GetTop()-tip.control:GetTop(),16)
    A.Equal(tip.control.height,tip.bodyLabel.height+32)
    A.Equal(tip.control:GetTop()+tip.control.height/2,324)
end
