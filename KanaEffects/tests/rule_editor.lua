for _,path in ipairs({'localization/en.lua','localization/ru.lua','catalog/Selectors.lua','catalog/data/Presets.lua',
    'model/Schema.lua','rules/Rules.lua','effects/Store.lua','editor/Session.lua','editor/Picker.lua','editor/Inspector.lua','editor/SetEditor.lua','editor/Editor.lua'}) do dofile(TEST_ROOT..'/'..path) end
local A,F=TestSupport.Assert,TestSupport.Fixtures
local codeRow
local function chooseSet(sets,name)
    for _,row in pairs(sets.form.rows) do if row.generation==sets.form.generation and row.combo and row.label.text==sets.labels.set then
        for _,item in ipairs(row.combo.items) do if item.name==name then item.callback(); return end end
    end end
    error('Set choice missing: '..name)
end
local function setup(predicate)
    local p=F.Profile(); p.sets={{id='a',name='A',predicate=predicate or KanaEffects.Presets.SupportPredicate(),includeSets={},excludeSets={}}}
    local writes=0; local saved; local storage={Load=function() return p,{} end,Write=function(_,profile) saved=profile; writes=writes+1; return true,{} end}
    local session=KanaEffects.Session.New(storage); session:Begin()
    local api=TestSupport.EditorNative.New(); local editor={open=true,generation=1}
    editor.IsOpen=KanaEffects.Editor.IsOpen
    local sets=KanaEffects.SetEditor.New(editor,session,{}, {Resolve=function() return {name='Effect'} end},KanaEffects.Store.New(),api)
    function editor:Apply(command)
        local ok,diag=session:Apply(command); if ok then sets:Refresh() end; return ok,diag
    end
    function editor:RequestClose() sets:Close() end
    editor._NewId=KanaEffects.Editor._NewId; editor.session=session; editor.inspector={}; editor.setEditor=sets; editor.Save=KanaEffects.Editor.Save
    editor.runtime={ApplyConfig=function() return true,{} end}
    function editor:_Finish() self.open=false; self.generation=self.generation+1; sets:Close() end
    function editor:Report(ok) return ok end
    sets:Open()
    return sets,session,api,function() return writes end,editor,function() return saved end
end
Tests.rule_editor_hidden_invalid_buffer_blocks_toolbar_save_and_returns_to_error=function()
    local sets,session,_,writes,editor=setup()
    A.True(session:Apply({type='set.put',set={id='b',name='B',predicate={op='and',args={}},includeSets={},excludeSets={}}}))
    sets:Refresh(); local input=codeRow(sets.form).input
    input:SetText('is_buff('); input.handlers.OnTextChanged(input); input.handlers.OnFocusLost(input)
    chooseSet(sets,'B'); A.Equal(codeRow(sets.form).input:GetText(),'true')
    A.False(editor:Save()); A.Equal(writes(),0); A.True(editor.open)
    A.Equal(sets.selected,'a'); A.Equal(codeRow(sets.form).input:GetText(),'is_buff('); assert(sets.form.error.text~='')
    input=codeRow(sets.form).input; input:SetText('is_buff()'); input.handlers.OnTextChanged(input)
    chooseSet(sets,'B')
    A.True(editor:Save()); A.Equal(writes(),1)
end
Tests.rule_editor_all_retained_valid_buffers_are_committed_before_save=function()
    local sets,session,_,writes,editor,saved=setup()
    A.True(session:Apply({type='set.put',set={id='b',name='B',predicate={op='and',args={}},includeSets={},excludeSets={}}}))
    local input=codeRow(sets.form).input; input:SetText('is_buff()'); input.handlers.OnTextChanged(input)
    sets.selected='b'; sets:Refresh(); input=codeRow(sets.form).input; input:SetText('is_debuff()'); input.handlers.OnTextChanged(input)
    A.True(editor:Save()); A.Equal(writes(),1)
    A.Equal(saved().sets[1].predicate.source,'is_buff()'); A.Equal(saved().sets[2].predicate.source,'is_debuff()')
end
Tests.rule_editor_returned_buffer_apply_compares_with_saved_rule_not_displayed_draft=function()
    local sets,session=setup(); local input=codeRow(sets.form).input
    input:SetText('is_debuff()'); input.handlers.OnTextChanged(input); sets:Refresh()
    A.Equal(codeRow(sets.form).input:GetText(),'is_debuff()')
    A.True(sets:SaveSelected()); A.Equal(session:ReadDraft().sets[1].predicate.source,'is_debuff()')
end
Tests.rule_editor_unchanged_legacy_beyond_expression_budgets_remains_saveable=function()
    local nested={op='and',args={}}; for i=1,25 do nested={op='not',arg=nested} end
    local wide={op='or',args={}}; for i=1,150 do wide.args[i]={op='selector',selector={kind='ability',id=i}} end
    for _,legacy in ipairs({nested,wide}) do
        local sets,session,_,writes,editor,saved=setup(legacy)
        local source=KanaEffects.Rules.PredicateExpression(legacy)
        A.Equal(KanaEffects.Rules.ParseExpression(source),nil)
        A.Equal(codeRow(sets.form).input:GetText(),source); A.False(session:IsDirty())
        A.True(sets.form:CommitEdits()); A.False(session:IsDirty()); A.True(editor:Save()); A.Equal(writes(),1)
        A.Equal(KanaEffects.Rules.PredicateExpression(saved().sets[1].predicate),source)
        A.Equal(saved().sets[1].predicate.op,legacy.op)
    end
end
Tests.rule_editor_changed_oversized_legacy_rule_obeys_limits_until_reverted=function()
    local legacy={op='and',args={}}; for i=1,25 do legacy={op='not',arg=legacy} end
    local sets,session,_,writes,editor=setup(legacy); local source=KanaEffects.Rules.PredicateExpression(legacy)
    local input=codeRow(sets.form).input; input:SetText(source..' '); input.handlers.OnTextChanged(input)
    A.False(editor:Save()); A.Equal(writes(),0); A.False(session:IsDirty())
    input:SetText(source); input.handlers.OnTextChanged(input); A.True(editor:Save()); A.Equal(writes(),1)
end
codeRow=function(form)
    for _,row in pairs(form.rows) do if row.generation==form.generation and row.kind=='code' then return row end end
    error('Missing multiline rule editor')
end
Tests.rule_editor_converts_existing_ast_without_mutating_profile_and_shows_reference=function()
    local sets,session=setup(); local row=codeRow(sets.form)
    A.True(row.input.multiLine); A.True(row.input.newLine); A.True(row.input.maxChars>=16384)
    A.Equal(row.input:GetText(),KanaEffects.Rules.PredicateExpression(session:ReadDraft().sets[1].predicate))
    A.False(session:IsDirty()); A.Equal(session:ReadDraft().sets[1].predicate.op,'and')
    A.Equal(sets.form.navigation,nil)
    A.True(sets:OpenHelp()); local help=''; local groups=0
    for index=1,6 do
        sets.help.section=index; sets.help:Refresh()
        for _,r in pairs(sets.help.form.rows) do if r.generation==sets.help.form.generation then
            if r.kind=='document' then help=help..r.signature.text..r.description.text end
            if r.kind=='group' then groups=groups+1 end
        end end
    end
    A.Equal(groups,6); assert(help:find('total_duration()',1,true)); assert(help:find('Category.Food',1,true)); assert(help:find('boolean',1,true)); assert(help:find('element_of(',1,true))
    A.True(sets.help.form.root~=sets.form.root)
    sets:Dispose(); A.False(sets.help:IsOpen())
end
Tests.rule_editor_errors_preserve_last_valid_preview_and_block_save_commit=function()
    local sets,session=setup(); local row=codeRow(sets.form); local old=KanaEffects.Rules.PredicateExpression(session:ReadDraft().sets[1].predicate)
    row.input:SetText('is_buff() and'); row.input.handlers.OnTextChanged(row.input)
    A.Equal(sets.form:GetPendingEdits(),nil); A.False(sets.form:CommitEdits()); assert(sets.form.error.text~='')
    A.Equal(KanaEffects.Rules.PredicateExpression(session:ReadDraft().sets[1].predicate),old)
    sets:Refresh(); row=codeRow(sets.form); A.Equal(row.input:GetText(),'is_buff() and')
    row.input:SetText('is_buff()\nand total_duration() > 300'); row.input.handlers.OnTextChanged(row.input)
    A.True(sets:SaveSelected()); A.Equal(session:ReadDraft().sets[1].predicate.op,'expression')
    local r=assert(KanaEffects.Rules.Compile(session:ReadDraft().sets,60)); A.True(r:Matches('a',F.Observation(100,{fullDuration=400})))
    A.False(r:Matches('a',F.Observation(100,{fullDuration=200})))
    sets:Close(); sets:Open(); A.Equal(codeRow(sets.form).input:GetText(),'is_buff()\nand total_duration() > 300')
end
Tests.rule_editor_full_expression_preserves_legacy_reference_semantics_on_migration=function()
    local sets,session=setup()
    A.True(session:Apply({type='set.put',set={id='b',name='B',predicate={op='selector',selector={kind='ability',id=200}},includeSets={},excludeSets={}}}))
    A.True(sets:ToggleReference('a','includeSets','b'))
    local p=session:ReadDraft(); local source=KanaEffects.Rules.SetExpression(p.sets[1],p.sets)
    assert(source:find('element_of("B")',1,true))
    A.True(sets:SetExpression('a','('..source..') and not ability(300)'))
    p=session:ReadDraft(); A.Equal(#p.sets[1].includeSets,0); A.Equal(#p.sets[1].excludeSets,0)
    local r=assert(KanaEffects.Rules.Compile(p.sets,60)); A.True(r:Matches('a',F.Observation(200)))
    A.False(r:Matches('a',F.Observation(300)))
end
Tests.rule_editor_save_applies_name_and_code_to_outer_draft_only=function()
    local sets,session,_,writes=setup(); local input=codeRow(sets.form).input
    sets.nameInput:SetText('Long buffs'); sets.nameInput.handlers.OnTextChanged(sets.nameInput)
    input:SetText('is_buff() and total_duration() > 300'); input.handlers.OnTextChanged(input); input.handlers.OnFocusLost(input)
    A.True(sets:Check()); A.False(session:IsDirty()); A.True(sets:HasPendingChanges())
    A.True(sets:SaveSelected()); A.Equal(writes(),0); A.Equal(session:ReadDraft().sets[1].name,'Long buffs')
    A.Equal(session:ReadDraft().sets[1].predicate.source,'is_buff() and total_duration() > 300')
    A.False(sets:HasPendingChanges()); session:Cancel(); A.Equal(writes(),0)
end
Tests.rule_editor_closed_invalid_buffer_survives_reopen_and_blocks_outer_save=function()
    local sets,session,_,writes,editor=setup(); local input=codeRow(sets.form).input
    input:SetText('element_of("Missing")'); input.handlers.OnTextChanged(input)
    A.False(sets:Check()); A.False(session:IsDirty()); sets:Close(); A.True(sets:HasPendingChanges())
    A.False(editor:Save()); A.Equal(writes(),0); A.True(sets:IsOpen())
    A.Equal(codeRow(sets.form).input:GetText(),'element_of("Missing")')
end
Tests.rule_editor_selector_creates_unique_names_and_exposes_only_new_workflow=function()
    local sets,session=setup()
    chooseSet(sets,'Добавить новый...'); A.Equal(#session:ReadDraft().sets,2)
    chooseSet(sets,'Добавить новый...'); local p=session:ReadDraft(); A.Equal(#p.sets,3); A.True(p.sets[2].name~=p.sets[3].name)
    local kinds={}; local buttons={}
    for _,row in pairs(sets.form.rows) do if row.generation==sets.form.generation then
        kinds[row.kind]=(kinds[row.kind] or 0)+1
        if row.kind=='actions' then for _,button in ipairs(row.buttons) do buttons[#buttons+1]=button.kanaTitle end end
    end end
    A.Equal(kinds.choice,1); A.Equal(kinds.code,1); A.Equal(kinds.check,nil); A.Equal(kinds.segments,nil)
    A.Equal(table.concat(buttons,','),'Проверить,Удалить,Сохранить')
end
Tests.rule_editor_name_and_invalid_rule_buffers_survive_switch_and_stale_callbacks=function()
    local sets,session=setup(); A.True(session:Apply({type='set.put',set={id='b',name='B',predicate={op='and',args={}},includeSets={},excludeSets={}}}))
    sets:Refresh(); local input=codeRow(sets.form).input; local stale=input.handlers.OnTextChanged
    input:SetText('is_buff('); input.handlers.OnTextChanged(input)
    sets.nameInput:SetText('Pending A'); sets.nameInput.handlers.OnTextChanged(sets.nameInput)
    chooseSet(sets,'B'); stale(input); chooseSet(sets,'A')
    A.Equal(sets.nameInput:GetText(),'Pending A'); A.Equal(codeRow(sets.form).input:GetText(),'is_buff(')
end
Tests.rule_editor_pending_reference_survives_another_pending_set_rename=function()
    local sets,session,_,writes,editor,saved=setup()
    A.True(session:Apply({type='set.put',set={id='b',name='B',predicate={op='and',args={}},includeSets={},excludeSets={}}}))
    sets:Refresh(); sets.nameInput:SetText('Renamed A'); sets.nameInput.handlers.OnTextChanged(sets.nameInput)
    chooseSet(sets,'B'); local input=codeRow(sets.form).input
    input:SetText('element_of("A") and is_buff()'); input.handlers.OnTextChanged(input)
    A.True(editor:Save()); A.Equal(writes(),1)
    A.Equal(saved().sets[1].name,'Renamed A')
    A.Equal(saved().sets[2].predicate.source,'element_of("Renamed A") and is_buff()')
end
Tests.rule_editor_deleted_set_buffers_do_not_attach_to_reused_id=function()
    local sets,session=setup(); A.True(sets:Create()); local id=sets.selected
    local input=codeRow(sets.form).input; input:SetText('is_buff('); input.handlers.OnTextChanged(input)
    sets.nameInput:SetText('Stale name'); sets.nameInput.handlers.OnTextChanged(sets.nameInput)
    A.True(sets:Delete(id)); A.Equal(sets.expressionBuffers[id],nil); A.Equal(sets.nameBuffers[id],nil)
    A.True(sets:Create()); A.Equal(sets.selected,id)
    A.Equal(codeRow(sets.form).input:GetText(),'true'); A.Equal(sets.nameInput:GetText(),sets.labels.newSet)
end
Tests.rule_editor_rebases_only_matching_id_among_same_name_references=function()
    local sets,session=setup()
    A.True(session:Apply({type='set.put',set={id='b',name='A',predicate={op='and',args={}},includeSets={},excludeSets={}}}))
    sets:Refresh()
    sets.expressionBuffers.b='element_of("A", "a") and not element_of("A", "b")'
    local draft=session:ReadDraft(); draft.sets[1].name='Renamed A'; sets:RebaseReferences(draft)
    A.Equal(sets.expressionBuffers.b,'element_of("Renamed A", "a") and not element_of("A", "b")')
end
