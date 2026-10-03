-- Explicit loader: this pure model never loads the manifest or WIP UI/Core.
local function model()
    local kw={}
    local env={KanaWardrobe=kw,assert=assert,type=type,pairs=pairs,ipairs=ipairs,next=next,
        tonumber=tonumber,tostring=tostring,pcall=pcall,table=table,math=math}
    local chunk=loadfile(ROOT..'/BuildDescription.lua','t',env)
    if chunk then chunk() end
    assert(kw.BuildDescription and kw.BuildDescription.Build,'Missing BuildDescription.Build')
    return kw.BuildDescription
end

-- Source-shaped cached getters only. Allocator/current progression access for
-- normal skills is forbidden, so saved-versus-current mistakes fail loudly.
local function record(kind,indices,variants,extra)
    local native={}
    function native:GetIndices() return table.unpack(indices) end
    function native:GetMorphData(morph) assert(kind=='active');return variants[morph] end
    function native:GetRankData(rank) assert(kind=='passive');return variants[rank] end
    function native:GetCurrentProgressionData() assert(kind=='crafted');return variants[1] end
    function native:GetPointAllocator() error('description accessed mutable allocator') end
    local r={kind=kind,native=native,available=true,mutable=kind~='crafted',lineId=10,
        state=kind=='active' and {kind=kind,purchased=true,morph=1} or {kind=kind,rank=1}}
    for key,value in pairs(extra or {}) do r[key]=value end
    return r
end
local function progression(name,icon,id)
    return {GetName=function() return name end,GetIcon=function() return icon end,
        GetAbilityId=function() return id end}
end
local function readonly(value)
    if type(value)~='table' then return value end
    local backing={}
    for key,v in pairs(value) do backing[key]=readonly(v) end
    return setmetatable({}, {__index=backing,__pairs=function()return next,backing,nil end,
        __newindex=function()error('description mutated input')end})
end

local function withUI(callback)
    local Fake=dofile(ROOT..'/tests/support/fake_eso.lua')
    local previous={WINDOW_MANAGER,KanaWardrobePanel,zo_callLater,MouseIsOver}
    WINDOW_MANAGER=nil;KanaWardrobePanel=nil
    local timers={};zo_callLater=function(fn)timers[#timers+1]=fn end;MouseIsOver=function()return true end
    local ok,err=pcall(function()
        local kw=Fake.Load({'Core.lua','Slots.lua','lang/en.lua','BuildModel.lua','BuildDescription.lua','Presets.lua','Inventory.lua','SetModel.lua','Dialogs.lua','UI.lua'})
        local inventory=kw.Inventory.New(Fake.New());local state=inventory:Capture(false)
        local repo=kw.Presets.New({},'EU','@a','1','One')
        local session={view={state='idle',isEditor=false,selected={},missing={}}}
        function session:GetView()return self.view end
        local preview={shown=0,hidden=true}
        function preview:Show(_,summary)self.summary=summary;self.hidden=false;self.shown=self.shown+1 end
        function preview:Hide()self.hidden=true end
        function preview:ContainsMouse()return false end
        function preview:SetCloseCallback(fn)self.close=fn end
        function preview:Close()if self.close then self.close()end;self:Hide()end
        local captures=0;local catalogue={available=true,byKey={}}
        local ui=kw.UI.New(repo,session,preview,inventory,{captureActual=function()captures=captures+1;return {equipment={},equipmentState=state},catalogue end})
        ui.visible=true
        local function drain()local pending=timers;timers={};for _,fn in ipairs(pending)do fn()end end
        callback(kw,ui,repo,session,preview,drain,function()return captures end,catalogue)
    end)
    WINDOW_MANAGER,KanaWardrobePanel,zo_callLater,MouseIsOver=table.unpack(previous,1,4)
    if not ok then error(err)end
end

return {
 third_bar_only_appears_with_a_selected_werewolf_slot=function()
    for _,bars in ipairs({{}, {werewolf={}}, {front={[1]={kind='empty'}}}})do
        assert(not model().Build({abilities={bars=bars}}).bars.werewolf)
    end
    local d=model().Build({abilities={bars={werewolf={[3]={kind='empty'}}}}})
    assert(#d.bars.werewolf==6 and d.bars.werewolf[3].kind=='empty' and d.bars.werewolf[1].kind=='unchanged')
 end,
 description_ui_retains_one_catalogue_capture_and_omits_absent_gear=function()
    withUI(function(kw,ui,repo,session,preview,drain,captures,catalogue)
        local p=repo:NewDraft();p.name='Points';p.equipment=nil;p.slots=nil;p.attributes={health=0,magicka=0,stamina=64}
        p=assert(repo:Save(p,0));ui:Refresh()
        local d=ui:Summary(p)
        assert(d.description and d.description.attributes.stamina==64,'UI failed to consume approved pure description')
        assert(d.effects==nil and d.description.equipmentSummary==nil,'attrs-only UI invented a gear block')
        ui:Summary(p);assert(captures()==1,'description performed an extra canonical/catalogue capture')
        assert(ui.descriptionCatalogue==catalogue,'runtime catalogue was copied or dropped')
    end)
 end,
 description_pointer_leave_is_sticky_and_close_cancels_pending_hover=function()
    withUI(function(kw,ui,repo,session,preview,drain)
        local p=repo:NewDraft();p.name='Points';p.attributes={health=1,magicka=2,stamina=3};p=assert(repo:Save(p,0))
        ui:Refresh();local row=ui.model.rows[1]
        ui:Hover(row,{});drain();assert(preview.shown==1 and not preview.hidden)
        MouseIsOver=function()return false end
        ui:Leave();drain();assert(not preview.hidden,'pointer leave dismissed sticky description')
        MouseIsOver=function()return true end
        ui:Hover(row,{});preview:Close();drain()
        assert(preview.hidden and preview.shown==1,'Close did not invalidate pending UI hover')
        ui:Hover(row,{});ui:OnSceneHidden('inventory');drain()
        assert(preview.hidden and preview.shown==1,'page hide left a pending hover')
    end)
 end,
 description_omits_absent_components_and_catalogue_only_skills=function()
    local d=model().Build({}, {available=true,byKey={
        ['10:active:1']={kind='active',mutable=true,state={kind='active',purchased=true,morph=1}},
    }})
    assert(d.attributes==nil and d.bars==nil and d.equipmentSummary==nil)
    assert(#d.enabled==0 and #d.disabled==0 and d.tabs==nil)
 end,
 attributes_keep_absolute_zero_points_and_detach_saved_values=function()
    local preset={attributes={health=0,magicka=0,stamina=64,unspentAtCapture=7}}
    local d=model().Build(preset)
    assert(d.attributes.health==0 and d.attributes.magicka==0 and d.attributes.stamina==64)
    d.attributes.health=20
    assert(preset.attributes.health==0 and preset.attributes.unspentAtCapture==7)
 end,
 equipment_summary_preserves_canonical_uid_map_without_stat_math=function()
    local preset={equipment={[0]={kind='item',uid='42',link='saved-link'},[4]={kind='empty'}}}
    local d=model().Build(preset)
    assert(d.equipmentSummary[0].uid=='42' and d.equipmentSummary[0].link=='saved-link')
    assert(d.equipmentSummary[4].kind=='empty' and d.equipmentSummary[1]==nil)
    d.equipmentSummary[0].uid='other';assert(preset.equipment[0].uid=='42')
 end,
 enabled_and_disabled_use_saved_progression_and_only_explicit_refs=function()
    local savedMorph=progression('Saved morph','saved-morph.dds',102)
    local savedRank=progression('Saved rank','saved-rank.dds',202)
    local base=progression('Base','base.dds',100)
    local rank1=progression('Passive I','rank1.dds',201)
    local catalogue={available=true,byKey={
        ['10:active:1']=record('active',{2,1,1},{[0]=base,[2]=savedMorph}),
        ['10:passive:2']=record('passive',{2,1,2},{rank1,savedRank}),
        ['10:active:3']=record('active',{2,1,3},{[0]=base}),
        ['10:passive:4']=record('passive',{2,1,4},{rank1}),
        ['10:active:5']=record('active',{2,1,5},{[0]=base},{autoGrant=true,mutable=false}),
    }}
    local preset={abilities={skills={
        ['10:active:1']={kind='active',purchased=true,morph=2},
        ['10:passive:2']={kind='passive',rank=2},
        ['10:active:3']={kind='active',purchased=false},
        ['10:passive:4']={kind='passive',rank=0},
    }}}
    local d=model().Build(readonly(preset),readonly(catalogue))
    assert(#d.enabled==2 and #d.disabled==2)
    assert(d.enabled[1].name=='Saved morph' and d.enabled[1].icon=='saved-morph.dds')
    assert(d.enabled[1].state.morph==2 and d.enabled[1].tooltip.morph==2)
    assert(d.enabled[2].name=='Saved rank' and d.enabled[2].tooltip.rank==2)
    assert(d.disabled[1].state.purchased==false and d.disabled[1].tooltip.morph==0)
    assert(d.disabled[2].state.rank==0 and d.disabled[2].tooltip.rank==1)
    for _,entry in ipairs(d.disabled) do assert(entry.tooltip.inactive==true) end
    for _,entry in ipairs(d.enabled) do
        assert(entry.available and not entry.tooltip.inactive and entry.tooltip.progression)
        assert(entry.tooltip.showSkillPointCost==false and entry.tooltip.showUpgradeText==false)
        assert(entry.tooltip.showAdvised==false and entry.tooltip.showBadMorph==false)
    end
    d.enabled[1].state.morph=0;assert(preset.abilities.skills['10:active:1'].morph==2)
 end,
 skill_grid_sorts_native_categories_lines_and_order_including_mastery=function()
    local variants={[1]=progression('A','a.dds',1)}
    local catalogue={available=true,byKey={}}
    local skills={}
    for _,v in ipairs({{'10:passive:1',{2,1,1},false}, {'20:passive:1',{1,2,1},false},
        {'30:passive:1',{1,1,2},true}, {'40:passive:1',{1,1,1},false}}) do
        catalogue.byKey[v[1]]=record('passive',v[2],variants,{mastery=v[3],lineId=tonumber(v[1]:match('^(%d+)'))})
        skills[v[1]]={kind='passive',rank=1}
    end
    local d=model().Build({abilities={skills=skills}},catalogue)
    assert(d.enabled[1].skillKey=='40:passive:1' and d.enabled[2].skillKey=='30:passive:1')
    assert(d.enabled[3].skillKey=='20:passive:1' and d.enabled[4].skillKey=='10:passive:1')
    assert(d.enabled[2].mastery==true and d.enabled[2].state.rank==1)
 end,
 bars_keep_twelve_positions_partial_unchanged_and_explicit_empty=function()
    local saved=progression('Bar morph','bar-morph.dds',102)
    local catalogue={available=true,byKey={['10:active:1']=record('active',{1,1,1},{[2]=saved})}}
    local preset={abilities={bars={front={[1]={kind='skill',skillKey='10:active:1',expectedMorph=2},[6]={kind='empty'}},
        back={[2]={kind='empty'},[6]={kind='skill',skillKey='10:active:1',expectedMorph=2}}}}}
    local d=model().Build(readonly(preset),readonly(catalogue))
    assert(#d.bars.front==6 and #d.bars.back==6 and #d.enabled==0)
    assert(d.bars.front[1].skillKey=='10:active:1' and d.bars.front[1].expectedMorph==2)
    assert(d.bars.front[1].tooltip.morph==2 and d.bars.front[1].name=='Bar morph')
    assert(d.bars.front[2].kind=='unchanged' and d.bars.front[6].kind=='empty')
    assert(d.bars.back[1].kind=='unchanged' and d.bars.back[2].kind=='empty')
    assert(d.bars.back[6].kind=='skill' and d.bars.back[6].slot==6)
    assert(d.bars.front[1].state==nil) -- no invented purchase/current-state fallback
 end,
 a_partial_single_bar_never_invents_a_second_saved_bar=function()
    local d=model().Build({abilities={bars={front={[3]={kind='empty'}}}}})
    assert(#d.bars.front==6 and #d.bars.back==6)
    assert(d.bars.front[3].kind=='empty' and d.bars.back[3].kind=='unchanged')
 end,
 missing_and_unavailable_saved_keys_remain_with_concrete_reasons=function()
    local skills={['99:active:2']={kind='active',purchased=true,morph=1},
        ['88:active:1']={kind='active',purchased=false}}
    local bars={back={[6]={kind='skill',skillKey='99:active:2',expectedMorph=1}}}
    local d=model().Build({abilities={skills=skills,bars=bars}},{available=true,byKey={}})
    assert(#d.enabled==1 and #d.disabled==1)
    for _,entry in ipairs({d.enabled[1],d.disabled[1],d.bars.back[6]}) do
        assert(entry.available==false and entry.icon==nil and entry.name==entry.skillKey)
        assert(entry.unresolvedReason.details.reason=='missingSkill')
        assert(entry.unresolvedReason.details.skillKey==entry.skillKey)
    end
    d=model().Build({abilities={skills=skills}}, {available=false,byKey={},problem={code='buildCapabilityUnavailable',details={name='SKILLS_DATA_MANAGER'}}})
    assert(d.enabled[1].unresolvedReason.details.reason=='missingCatalogue')
    assert(d.enabled[1].unresolvedReason.details.name=='SKILLS_DATA_MANAGER')
 end,
 saved_progression_failure_never_uses_current_native_variant=function()
    local catalogue={available=true,byKey={
        ['10:active:1']=record('active',{1,1,1},{[1]=progression('Current','current.dds',101)}),
        ['10:passive:2']=record('passive',{1,1,2},{progression('Current','current.dds',201)}),
        ['10:active:3']=record('active',{1,1,3},{[0]=progression('Unavailable','u.dds',300)},{available=false}),
    }}
    local d=model().Build({abilities={skills={['10:active:1']={kind='active',purchased=true,morph=2},
        ['10:passive:2']={kind='passive',rank=3},['10:active:3']={kind='active',purchased=false}}}},catalogue)
    assert(d.enabled[1].unresolvedReason.details.reason=='missingProgression')
    assert(d.enabled[2].unresolvedReason.details.reason=='missingProgression')
    assert(d.disabled[1].unresolvedReason.details.reason=='lineUnavailable' and d.disabled[1].icon==nil)
 end,
 crafted_bar_uses_current_configured_metadata_without_script_targets=function()
    local p=progression('Configured crafted ability','crafted.dds',701)
    local catalogue={available=true,byKey={['10:crafted:7']=record('crafted',{1,1,7},{p},{craftedReady=true})}}
    local preset={abilities={bars={front={[5]={kind='skill',skillKey='10:crafted:7'}}}}}
    local d=model().Build(preset,catalogue)
    local entry=d.bars.front[5]
    assert(entry.available and entry.name=='Configured crafted ability' and entry.icon=='crafted.dds')
    assert(entry.tooltip.kind=='crafted' and entry.tooltip.abilityId==701 and entry.state==nil)
    assert(entry.tooltip.morph==nil and entry.tooltip.rank==nil and #d.enabled==0 and #d.disabled==0)
    catalogue.byKey['10:crafted:7'].craftedReady=false
    entry=model().Build(preset,catalogue).bars.front[5]
    assert(entry.available==false and entry.unresolvedReason.details.reason=='craftedNotReady')
 end,
 unresolved_grid_uses_stable_key_fallback_and_preserves_disabled_mastery=function()
    local d=model().Build({abilities={skills={
        ['9:passive:1']={kind='passive',rank=2},['8:passive:1']={kind='passive',rank=1},
        ['10:passive:1']={kind='passive',rank=0},
    }}},{available=true,byKey={['10:passive:1']=record('passive',{1,1,1},
        {progression('Mastery I','mastery.dds',101)},{mastery=true})}})
    assert(d.enabled[1].skillKey=='8:passive:1' and d.enabled[2].skillKey=='9:passive:1')
    assert(d.disabled[1].mastery and d.disabled[1].state.rank==0 and d.disabled[1].tooltip.inactive)
 end,
 bar_ref_keeps_saved_morph_even_when_explicit_skill_is_off=function()
    local variants={[0]=progression('Off base','base.dds',100),[2]=progression('Assigned morph','morph.dds',102)}
    local preset={abilities={skills={['10:active:1']={kind='active',purchased=false}},
        bars={front={[1]={kind='skill',skillKey='10:active:1',expectedMorph=2}}}}}
    local d=model().Build(preset,{available=true,byKey={['10:active:1']=record('active',{1,1,1},variants)}})
    assert(d.disabled[1].tooltip.morph==0 and d.disabled[1].name=='Off base')
    assert(d.bars.front[1].tooltip.morph==2 and d.bars.front[1].name=='Assigned morph')
    assert(d.bars.front[1].state.purchased==false and d.bars.front[1].tooltip.inactive)
 end,
 getter_failure_and_missing_icon_remain_visible_unresolved_metadata=function()
    local variants={[0]=progression('Known','known.dds',100)}
    local throwing=record('active',{1,1,1},variants)
    throwing.native.GetMorphData=function()error('stale progression')end
    local noIcon=record('active',{1,1,2},{[0]=progression('Missing icon',nil,200)})
    local d=model().Build({abilities={skills={['10:active:1']={kind='active',purchased=true,morph=0},
        ['10:active:2']={kind='active',purchased=true,morph=0}}}},
        {available=true,byKey={['10:active:1']=throwing,['10:active:2']=noIcon}})
    assert(#d.enabled==2 and d.enabled[1].unresolvedReason.details.reason=='missingProgression')
    assert(d.enabled[2].unresolvedReason.details.reason=='missingMetadata')
    assert(d.enabled[1].tooltip.progression==nil and d.enabled[2].icon==nil)
 end,
}
