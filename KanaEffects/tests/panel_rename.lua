-- The mutations named below must break these behavior tests: preview-order,
-- geometry padding, close routing, ID regeneration and graph replacement.
for _,path in ipairs({'localization/en.lua','localization/ru.lua','catalog/data/Families.lua','catalog/data/Categories.lua','catalog/Selectors.lua','catalog/Catalog.lua','catalog/data/Presets.lua','effects/History.lua','model/Schema.lua','effects/Store.lua','rules/Rules.lua','widgets/Projector.lua','widgets/Layout.lua','Runtime.lua','editor/Session.lua','editor/Demo.lua','editor/Picker.lua','editor/HiddenList.lua','editor/Inspector.lua','editor/SetEditor.lua','editor/Editor.lua'}) do
    local file=io.open(TEST_ROOT..'/'..path,'r'); if file then file:close(); dofile(TEST_ROOT..'/'..path) end
end
local A,F=TestSupport.Assert,TestSupport.Fixtures
local function setup(profile,api,suppliedCatalog)
    assert(KanaEffects.Editor and KanaEffects.Editor.New,'missing Editor.New')
    profile=profile or F.Profile(); local saved=KanaEffects.Schema.CopyProfile(profile); local writes=0
    local storage={Load=function() return KanaEffects.Schema.CopyProfile(saved),{} end,Write=function(_,p) writes=writes+1; saved=KanaEffects.Schema.CopyProfile(p); return true,{} end}
    local session=KanaEffects.Session.New(storage); local store=KanaEffects.Store.New(); local queue={}
    local catalog=suppliedCatalog or {Resolve=function(_,s) return {name='Effect '..s.id,icon='actual-'..s.id..'.dds',kind='buff',pair=false,availableLevels={minor=true,major=true}} end,
        ValidateSelector=function() return true end,Describe=function(_,id) return {abilityId=id,name='Effect '..id,icon='actual-'..id..'.dds',categories={},origin='unknown'} end,
        Search=function() return {},0 end}
    local anchorCallbacks={}
    local references={screen={x=0,y=0,width=2387,height=1845},actionBar={x=600,y=1300,width=700,height=80},resources={x=400,y=1200,width=250,height=90},targetFrame={x=900,y=80,width=400,height=60}}
    local anchors={GetReferenceRect=function(_,id) return references[id] end,Observe=function(_,fn) anchorCallbacks[#anchorCallbacks+1]=fn; return function() end end}
    local renderer={Render=function() end,SetCallbacks=function() end,SetVisible=function() end,SetEditorOverlay=function() end,ReleaseWidget=function() end,Dispose=function() end}
    local sources={Start=function() end,Reconfigure=function() end,Stop=function() end}
    local metrics={MeasureText=function(_,t,n) return #t*n/2,n end}
    local clock={Now=function() return 10 end}
    local runtime=KanaEffects.Runtime.New({schema=KanaEffects.Schema,catalog=catalog,store=store,sources=sources,rules=KanaEffects.Rules,projector=KanaEffects.Projector,layout=KanaEffects.Layout,renderer=renderer,anchors=anchors,fontMetrics=metrics,clock=clock,defer=function(fn) local q={fn=fn}; queue[#queue+1]=q; return function() q.cancel=true end end})
    local function flush() local q=queue; queue={}; for _,v in ipairs(q) do if not v.cancel then v.fn() end end end
    runtime:Start(profile); flush()
    local history=KanaEffects.History.New()
    local picker=KanaEffects.Picker.New(catalog,history,store,session,api)
    local hidden=KanaEffects.HiddenList.New(catalog,session,picker,api)
    local editor=KanaEffects.Editor.New(session,runtime,picker,anchors,{store=store,catalog=catalog,hiddenList=hidden,api=api,clock=clock})
    return {history=history,references=references,reflow=function() for _,fn in ipairs(anchorCallbacks) do fn() end end,editor=editor,session=session,runtime=runtime,picker=picker,hidden=hidden,store=store,flush=flush,saved=function() return saved end,writes=function() return writes end}
end

local function referencedProfile()
    local p=F.Profile(); p.widgets[1].name='Named panel'
    local other=F.Widget('other'); other.type='grid'; other.slots={}; other.rules.expression='on_panel("Named panel")'; p.widgets[2]=other
    p.sets={{id='s',name='Set',predicate={op='expression',source='on_panel("Named panel") and is_buff()'},includeSets={},excludeSets={}}}
    return p
end
Tests.referenced_panel_rename_requires_confirm_and_cancel_keeps_name_and_code=function()
    local c=setup(referencedProfile(),TestSupport.EditorNative.New()); c.editor:Open(); c.editor:Select('widget-a')
    A.False(c.editor.inspector:Set('name','Renamed')); A.Equal(c.session:ReadDraft().widgets[1].name,'Named panel'); A.False(c.session:IsDirty())
    A.True(c.editor.renameRequest~=nil); A.True(c.editor.renameForm.open)
    local text={}; for _,row in pairs(c.editor.renameForm.rows) do if row.generation==c.editor.renameForm.generation and row.kind=='text' then text[#text+1]=row.label:GetText() end end
    text=table.concat(text,'\n'); A.True(text:find(string.format(c.editor.labels.renamePanelHint,'Named panel','Renamed'),1,true)~=nil)
    A.True(text:find('Set',1,true)~=nil); A.False(text:find('(widget-a)',1,true)~=nil); A.False(text:find('(s)',1,true)~=nil)
    c.editor:ResolvePanelRename(false)
    A.Equal(c.session:ReadDraft().widgets[2].rules.expression,'on_panel("Named panel")'); A.Equal(c.session:ReadDraft().sets[1].predicate.source,'on_panel("Named panel") and is_buff()')
    A.False(c.session:IsDirty()); c.editor:Cancel()
end
Tests.confirmed_panel_rename_notifies_only_atomic_refs_and_outer_cancel_restores_profile=function()
    local c=setup(referencedProfile(),TestSupport.EditorNative.New()); c.editor:Open(); c.editor:Select('widget-a')
    local seen=0; c.session:Subscribe(function(p) if p then seen=seen+1; A.Equal(p.widgets[1].name,'Renamed'); A.Equal(p.widgets[2].rules.expression,'on_panel("Renamed")'); A.Equal(p.sets[1].predicate.source,'on_panel("Renamed") and is_buff()') end end)
    A.False(c.editor.inspector:Set('name','Renamed')); A.True(c.editor:ResolvePanelRename(true)); A.Equal(seen,1)
    c.editor:Cancel(); A.Equal(c.saved().widgets[1].name,'Named panel'); A.Equal(c.writes(),0)
end
Tests.unreferenced_panel_rename_is_immediate=function()
    local c=setup(nil,TestSupport.EditorNative.New()); c.editor:Open(); c.editor:Select('widget-a')
    A.True(c.editor.inspector:Set('name','Renamed')); A.Equal(c.session:ReadDraft().widgets[1].name,'Renamed'); A.Equal(c.editor.renameRequest,nil)
    c.editor:Cancel()
end
Tests.panel_rename_rewrites_closed_and_invalid_unsaved_buffers_without_committing_them=function()
    local c=setup(referencedProfile(),TestSupport.EditorNative.New()); c.editor:Open(); c.editor:Select('widget-a')
    c.editor.inspector.expressionBuffers.other='on_panel("Named panel") and ('
    c.editor.setEditor.expressionBuffers.s='on_panel("Named panel") or is_debuff()'
    A.False(c.editor.inspector:Set('name','Renamed')); A.True(c.editor:ResolvePanelRename(true))
    A.Equal(c.editor.inspector.expressionBuffers.other,'on_panel("Renamed") and (')
    A.Equal(c.editor.setEditor.expressionBuffers.s,'on_panel("Renamed") or is_debuff()')
    A.Equal(c.session:ReadDraft().widgets[2].rules.expression,'on_panel("Renamed")'); A.False(c.editor:Save()); A.Equal(c.writes(),0)
    c.editor:Cancel()
end
Tests.unsaved_buffer_reference_alone_triggers_panel_rename_confirmation=function()
    local p=F.Profile(); p.sets={{id='s',name='Set',predicate={op='expression',source='is_buff()'},includeSets={},excludeSets={}}}
    local c=setup(p,TestSupport.EditorNative.New()); c.editor:Open(); c.editor:Select('widget-a')
    c.editor.setEditor.expressionBuffers.s='on_panel("Effects")'
    A.False(c.editor.inspector:Set('name','Renamed')); A.True(c.editor.renameRequest~=nil); A.False(c.session:IsDirty())
    c.editor:ResolvePanelRename(false); A.Equal(c.editor.setEditor.expressionBuffers.s,'on_panel("Effects")'); c.editor:Cancel()
end
Tests.panel_rename_stale_confirmation_cannot_change_newer_draft_or_reopened_session=function()
    local c=setup(referencedProfile(),TestSupport.EditorNative.New()); c.editor:Open(); c.editor:Select('widget-a')
    c.editor.inspector:Set('name','Renamed'); local request=c.editor.renameRequest
    A.True(c.editor:PatchWidget('other',{anchor={x=123}})); A.False(c.editor:ResolvePanelRename(true,request)); A.Equal(c.session:ReadDraft().widgets[1].name,'Named panel')
    c.editor:Select('widget-a'); c.editor.inspector:Set('name','Renamed'); request=c.editor.renameRequest
    c.editor:Cancel(); c.editor:Open(); A.False(c.editor:ResolvePanelRename(true,request)); A.Equal(c.session:ReadDraft().widgets[1].name,'Named panel'); c.editor:Cancel()
end
Tests.outer_save_pauses_for_panel_rename_confirmation_and_preserves_buffer_code=function()
    local c=setup(referencedProfile(),TestSupport.EditorNative.New()); c.editor:Open(); c.editor:Select('widget-a')
    c.editor.setEditor.expressionBuffers.s='on_panel("Named panel") or is_debuff()'
    for _,row in pairs(c.editor.inspector.form.rows) do if row.generation==c.editor.inspector.form.generation and row.kind=='edit' and row.sourceValue=='Named panel' then row.input:SetText('Renamed') end end
    A.False(c.editor:Save()); A.Equal(c.writes(),0); A.True(c.editor.renameRequest~=nil)
    local generation=c.session.generation; A.False(c.editor:Save()); A.Equal(c.session.generation,generation); A.Equal(c.writes(),0); A.True(c.editor:IsOpen())
    A.True(c.editor:ResolvePanelRename(true)); A.Equal(c.editor.setEditor.expressionBuffers.s,'on_panel("Renamed") or is_debuff()')
    A.True(c.editor:Save()); A.Equal(c.saved().widgets[1].name,'Renamed'); A.Equal(c.saved().sets[1].predicate.source,'on_panel("Renamed") or is_debuff()'); A.Equal(c.writes(),1)
end

Tests.native_panel_name_typing_waits_for_commit_then_cancel_restores_display=function()
    local c=setup(referencedProfile(),TestSupport.EditorNative.New()); c.editor:Open(); c.editor:Select('widget-a')
    local input
    for _,row in pairs(c.editor.inspector.form.rows) do if row.generation==c.editor.inspector.form.generation and row.kind=='edit' and row.sourceValue=='Named panel' then input=row.input end end
    assert(input,'name input missing'); input:TakeFocus(); input:SetText('Renamed')
    if input.handlers.OnTextChanged then input.handlers.OnTextChanged(input) end
    A.Equal(c.editor.renameRequest,nil); A.False(c.session:IsDirty())
    input.handlers.OnEnter(input); A.True(c.editor.renameRequest~=nil); A.False(c.session:IsDirty()); A.Equal(input:GetText(),'Named panel')
    c.editor:RequestClose(); A.Equal(c.editor.renameRequest,nil); A.True(c.editor.inspector:IsOpen()); A.Equal(input:GetText(),'Named panel'); c.editor:Cancel()
end
Tests.unclosed_panel_literal_remains_intact_with_visible_correction_hint=function()
    local c=setup(referencedProfile(),TestSupport.EditorNative.New()); c.editor:Open(); c.editor:Select('widget-a')
    c.editor.inspector.expressionBuffers.other='on_panel("Named panel'
    c.editor.inspector:Set('name','Renamed'); A.True(c.editor:ResolvePanelRename(true))
    A.Equal(c.editor.inspector.expressionBuffers.other,'on_panel("Named panel')
    c.editor:Select('other'); c.editor.inspector.tab='effects'; c.editor.inspector:Refresh()
    A.True(c.editor.inspector.form.error:GetText():find(c.editor.labels.renameUnfinishedHint,1,true)~=nil)
    A.False(c.editor:Save()); A.Equal(c.writes(),0); c.editor:Cancel()
end
Tests.old_confirmation_cannot_cancel_a_new_panel_rename_request=function()
    local c=setup(referencedProfile(),TestSupport.EditorNative.New()); c.editor:Open(); c.editor:Select('widget-a')
    c.editor.inspector:Set('name','First'); local first=c.editor.renameRequest; c.editor:ResolvePanelRename(false)
    c.editor.inspector:Set('name','Second'); A.False(c.editor:ResolvePanelRename(true,first)); A.True(c.editor.renameRequest~=nil)
    A.True(c.editor:ResolvePanelRename(true)); A.Equal(c.session:ReadDraft().widgets[1].name,'Second'); c.editor:Cancel()
end

Tests.session_panel_rename_rejects_stale_name_and_rewrites_patch_references_atomically=function()
    local c=setup(referencedProfile()); c.editor:Open()
    local ok,diag=c.session:Apply({type='widget.rename',widgetId='widget-a',name='Renamed',previousName='Stale'})
    A.False(ok); A.Diagnostic(diag,'stale_rename'); A.False(c.session:IsDirty())
    A.True(c.session:Apply({type='widget.patch',widgetId='widget-a',patch={name='Patched'}}))
    local p=c.session:ReadDraft(); A.Equal(p.widgets[1].name,'Patched'); A.Equal(p.widgets[2].rules.expression,'on_panel("Patched")'); A.Equal(p.sets[1].predicate.source,'on_panel("Patched") and is_buff()')
    c.editor:Cancel()
end
Tests.panel_name_focus_loss_opens_one_confirmation_without_extra_typing_prompts=function()
    local c=setup(referencedProfile(),TestSupport.EditorNative.New()); c.editor:Open(); c.editor:Select('widget-a')
    local input
    for _,row in pairs(c.editor.inspector.form.rows) do if row.generation==c.editor.inspector.form.generation and row.kind=='edit' and row.sourceValue=='Named panel' then input=row.input end end
    input:TakeFocus(); input:SetText('Renamed'); input:LoseFocus(); local request=c.editor.renameRequest
    A.True(request~=nil); A.False(c.editor:Save()); A.Equal(c.editor.renameRequest,request); A.True(c.editor:ResolvePanelRename(true)); A.Equal(c.session:ReadDraft().widgets[1].name,'Renamed'); c.editor:Cancel()
end

Tests.stale_pending_name_and_code_callbacks_cannot_touch_reopened_draft=function()
    local c=setup(referencedProfile(),TestSupport.EditorNative.New()); c.editor:Open(); c.editor:Select('widget-a')
    c.editor.inspector.expressionBuffers.other='on_panel("Named panel") or is_debuff()'
    c.editor.setEditor.expressionBuffers.s='on_panel("Named panel") or is_debuff()'
    for _,row in pairs(c.editor.inspector.form.rows) do if row.generation==c.editor.inspector.form.generation and row.kind=='edit' and row.sourceValue=='Named panel' then row.input:SetText('Renamed') end end
    local edits=c.editor.inspector:GetPendingEdits(); local sets=c.editor.setEditor:GetPendingEdits()
    c.editor:Cancel(); c.editor:Open(); c.editor:Select('widget-a')
    for _,edit in ipairs(edits) do A.False(edit.callback(edit.value)) end
    for _,edit in ipairs(sets) do A.False(edit.callback(edit.value)) end
    A.False(c.session:IsDirty()); A.Equal(c.editor.renameRequest,nil); c.editor:Cancel()
end
