for _,path in ipairs({'catalog/Selectors.lua','rules/Rules.lua','widgets/Projector.lua'}) do dofile(TEST_ROOT..'/'..path) end
local A,F=TestSupport.Assert,TestSupport.Fixtures
local function panel(id,name,expression,tag)
    local w=F.Widget(id); w.name=name; w.type='grid'; w.unitTag=tag or 'player'; w.rules.expression=expression; return w
end
local function namedSet(id,name,source,includes)
    return {id=id,name=name,predicate={op='expression',source=source},includeSets=includes or {},excludeSets={}}
end
local function compile(widgets,sets,hidden)
    local c,d=KanaEffects.Rules.Compile(sets or {},60,widgets,hidden or {})
    assert(c,d and d[1] and d[1].message); A.Equal(#d,0,'panel reference warnings must not reject configuration'); return c
end
Tests.panel_reference_uses_actual_source_admission_without_a_rendered_view=function()
    local target=panel('target','Support','is_permanent()')
    local consumer=panel('consumer','Combat','on_panel("Support")')
    local c=compile({target,consumer}); local o=F.Observation(100,{lifetime='permanent'})
    A.True(c:MatchesWidget('consumer',o)); o.lifetime='finite'; A.False(c:MatchesWidget('consumer',o))
    target.unitTag='reticleover'; c=compile({target,consumer}); o.lifetime='permanent'; A.False(c:MatchesWidget('consumer',o))
    A.False(KanaEffects.Projector.Decide(o,target,{hidden={}},c),'different recipient cannot enter referenced panel')
end
Tests.panel_reference_table_pairs_sparse_bounds_and_global_hide_match_projector=function()
    local target=F.Widget('target'); target.name='Fixed'; target.layout.rows=1; target.layout.columns=1
    target.slots={[1]={[1]={kind='family',id='resolve',level='pair'}},[2]={[1]=F.Selector(200)}}
    local consumer=panel('consumer','Other','on_panel("Fixed")')
    local hidden={F.Selector(100)}; local c=compile({target,consumer},{},hidden)
    local o=F.Observation(100); o.catalog.familyId='resolve'; o.catalog.level='minor'
    A.True(c:MatchesWidget('consumer',o),'explicit pair slot bypasses global hiding')
    o.catalog.level='major'; A.True(c:MatchesWidget('consumer',o))
    o.catalog.familyId=nil; o.abilityId=200; A.False(c:MatchesWidget('consumer',o),'out of bounds assignments do not admit effects')
    target=panel('target','Fixed','true'); c=compile({target,consumer},{},hidden); o.abilityId=100
    A.False(c:MatchesWidget('consumer',o),'hidden effect is not admitted by the target grid')
    A.False(KanaEffects.Projector.Decide(o,consumer,{hidden=hidden},c),'consumer still applies its own global hiding')
end
Tests.panel_reference_missing_and_ambiguous_are_false_calls_with_nonfatal_warnings=function()
    local w=panel('c','Consumer','on_panel("Absent") or is_buff()')
    local c=compile({w}); A.True(c:MatchesWidget('c',F.Observation(1,{kind='buff'})))
    A.False(c:MatchesWidget('c',F.Observation(1,{kind='debuff'})))
    A.Equal(c:PanelDiagnostics('c')[1].code,'unknown_panel')
    w.rules.expression='on_panel("Duplicate")'
    c=compile({w,panel('a','Duplicate','false'),panel('b','Duplicate','false')})
    A.False(c:MatchesWidget('c',F.Observation(1))); A.Equal(c:PanelDiagnostics('c')[1].code,'ambiguous_panel')
    local diagnostics=c:PanelDiagnostics('c'); diagnostics[1].code='tampered'; A.Equal(c:PanelDiagnostics('c')[1].code,'ambiguous_panel')
end
Tests.panel_reference_cycles_disable_each_cyclic_call_but_preserve_other_branches=function()
    local a=panel('a','A','on_panel("B") or is_buff()'); local b=panel('b','B','on_panel("A")')
    local c=compile({a,b}); local o=F.Observation(1,{kind='debuff'})
    A.False(c:MatchesWidget('a',o)); A.False(c:MatchesWidget('b',o)); A.Equal(c:PanelDiagnostics('a')[1].code,'panel_cycle')
    o.kind='buff'; A.True(c:MatchesWidget('a',o)); A.False(c:MatchesWidget('b',o))
    a.rules.expression='on_panel("A")'; c=compile({a}); A.False(c:MatchesWidget('a',o))
end
Tests.panel_reference_set_panel_cycles_and_transitive_consumers_are_diagnosed=function()
    local sets={namedSet('s','Shared','on_panel("Target")'),namedSet('outer','Outer','element_of("Shared")')}
    local target=panel('t','Target','element_of("Outer")'); local consumer=panel('c','Consumer','element_of("Shared")')
    local c=compile({target,consumer},sets); local o=F.Observation(1)
    A.False(c:MatchesWidget('t',o)); A.False(c:MatchesWidget('c',o)); A.False(c:Matches('s',o))
    A.Equal(c:PanelDiagnostics('t')[1].code,'panel_cycle'); A.Equal(c:PanelDiagnostics('c')[1].code,'panel_cycle')
    sets[1].predicate.source='on_panel("Gone")'; c=compile({target,consumer},sets)
    A.Equal(c:PanelDiagnostics('t')[1].code,'unknown_panel'); A.Equal(c:PanelDiagnostics('c')[1].code,'unknown_panel')
end
Tests.panel_reference_legacy_sets_and_named_policy_use_same_admission=function()
    local target=panel('t','Target',nil); target.rules.includeSets={'s'}; target.rules.excludeSets={}; target.rules.named='only'
    local consumer=panel('c','Consumer','on_panel("Target")')
    local c=compile({target,consumer},{namedSet('s','Any','true')}); local o=F.Observation(1)
    A.False(c:MatchesWidget('c',o)); o.catalog.familyId='resolve'; o.catalog.level='minor'; A.True(c:MatchesWidget('c',o))
    target.rules.excludeSets={'s'}; c=compile({target,consumer},{namedSet('s','Any','true')}); A.False(c:MatchesWidget('c',o))
end
Tests.panel_reference_rename_uses_literal_spans_and_preserves_set_references=function()
    local source='on_panel(\'A\\" B\') and element_of("A\\\" B") and kind() == "A\\\" B"'
    local rewritten=KanaEffects.Rules.RewritePanelReferences(source,'A" B','C\\D"')
    A.Equal(rewritten,'on_panel("C\\\\D\\\"") and element_of("A\\\" B") and kind() == "A\\\" B"')
    A.Equal(KanaEffects.Rules.RewritePanelReferences('on_panel(', 'A','B'),'on_panel(')
    local profile={widgets={panel('t','Target','true'),panel('c','Consumer','on_panel("Target")')},sets={namedSet('s','Set','on_panel("Target")')}}
    local owners=KanaEffects.Rules.PanelReferenceOwners(profile,'t'); A.Equal(#owners,2)
    KanaEffects.Rules.RenamePanelReferences(profile,'Target','Renamed'); A.Equal(profile.widgets[2].rules.expression,'on_panel("Renamed")')
    A.Equal(profile.sets[1].predicate.source,'on_panel("Renamed")')
end
Tests.panel_reference_diamond_admission_is_memoized_and_compile_bindings_are_isolated=function()
    local panels={panel('a','A','true')}
    for i=1,16 do panels[#panels+1]=panel('w'..i,'Panel'..i,'on_panel("A")') end
    local parts={}; for i=1,16 do parts[#parts+1]='on_panel("Panel'..i..'")' end
    panels[#panels+1]=panel('root','Root',table.concat(parts,' and '))
    local c=compile(panels); local original=KanaEffects.Projector.Decide; local counts={}
    KanaEffects.Projector.Decide=function(o,w,...) counts[w.id]=(counts[w.id] or 0)+1; return original(o,w,...) end
    local ok,value=pcall(c.MatchesWidget,c,'root',F.Observation(1)); KanaEffects.Projector.Decide=original
    A.True(ok,tostring(value)); A.True(value); A.Equal(counts.a,1)
    local bad=compile({panel('root','Root',panels[#panels].rules.expression)})
    A.False(bad:MatchesWidget('root',F.Observation(1))); A.True(c:MatchesWidget('root',F.Observation(1)))
end
Tests.panel_reference_parser_rejects_nonliteral_empty_or_extra_arguments=function()
    for _,source in ipairs({'on_panel()','on_panel("")','on_panel(1)','on_panel("A", "id")','on_panel(kind())'}) do A.Equal(KanaEffects.Rules.ParseExpression(source),nil) end
end
Tests.panel_reference_rename_incomplete_buffers_only_rewrites_safe_literal_calls=function()
    local R=KanaEffects.Rules
    local source='on_panel("Old") and (broken + element_of("Old") -- on_panel("Old")\n or on_panel(\'Old\') or kind() == "on_panel(\\\"Old\\\")"'
    local expected='on_panel("New") and (broken + element_of("Old") -- on_panel("Old")\n or on_panel("New") or kind() == "on_panel(\\\"Old\\\")"'
    A.Equal(R.RewritePanelReferences(source,'Old','New'),expected)
    A.Equal(R.RewritePanelReferences('on_panel("Old") or "unterminated on_panel(\'Old\')','Old','New'),'on_panel("New") or "unterminated on_panel(\'Old\')')
    A.Equal(R.RewritePanelReferences('--[[on_panel("Old")]] on_panel("Old") + on_panel("Old", "extra")','Old','New'),'--[[on_panel("Old")]] on_panel("New") + on_panel("Old", "extra")')
    A.Equal(R.RewritePanelReferences('x.on_panel("Old") + xon_panel("Old")','Old','New'),'x.on_panel("Old") + xon_panel("Old")')
end
Tests.panel_reference_ignores_unused_table_rules_and_copies_admission_inputs=function()
    local target=F.Widget('t'); target.name='Target'; target.rules.expression='on_panel("Target")'
    local consumer=panel('c','Consumer','on_panel("Target")')
    local c=compile({target,consumer}); local o=F.Observation(100)
    A.Equal(#c:PanelDiagnostics('t'),0); A.True(c:MatchesWidget('c',o))
    target.slots={}; target.unitTag='reticleover'
    A.True(c:MatchesWidget('c',o),'compiled routing is an independent snapshot')
    o.abilityId=999; A.False(c:MatchesWidget('c',o),'memoization never persists across observations')
end
Tests.panel_reference_cycles_include_legacy_exclusion_edges_and_all_scc_calls=function()
    local target=panel('t','Target',nil); target.rules.includeSets={'any'}; target.rules.excludeSets={'shared'}
    local observer=panel('o','Observer','element_of("Shared")')
    local sets={namedSet('any','Any','true'),namedSet('shared','Shared','on_panel("Target")')}
    local c=compile({target,observer},sets); local o=F.Observation(100)
    A.True(KanaEffects.Projector.Decide(o,target,{hidden={}},c))
    A.False(c:MatchesWidget('o',o)); A.Equal(c:PanelDiagnostics('o')[1].code,'panel_cycle')
    local a=panel('a','A','on_panel("B") or on_panel("C")')
    local b=panel('b','B','on_panel("C")'); local d=panel('d','C','on_panel("A")')
    c=compile({a,b,d}); A.False(c:MatchesWidget('a',o)); A.False(c:MatchesWidget('b',o)); A.False(c:MatchesWidget('d',o))
end
Tests.on_panel_positive_contract_and_explicit_negation=function()
    local target=panel('target','Support','is_permanent()')
    local present=panel('yes','Present','on_panel("Support")')
    local absent=panel('no','Absent','not on_panel("Support")')
    local c=compile({target,present,absent}); local o=F.Observation(100,{lifetime='permanent'})
    A.True(c:MatchesWidget('yes',o)); A.False(c:MatchesWidget('no',o))
    o.lifetime='finite'; A.False(c:MatchesWidget('yes',o)); A.True(c:MatchesWidget('no',o))
    c=compile({present,absent}); A.False(c:MatchesWidget('yes',o)); A.True(c:MatchesWidget('no',o))
    A.Equal(c:PanelDiagnostics('yes')[1].code,'unknown_panel')
end
Tests.old_panel_call_normalizes_only_function_tokens=function()
    local p={widgets={panel('a','not_on_panel("X")','not_on_panel("X") or kind() == \'not_on_panel("X")\'')},sets={namedSet('s','Shared','not not_on_panel("X")')}}
    KanaEffects.Rules.NormalizePanelFunctions(p)
    A.Equal(p.widgets[1].rules.expression,'on_panel("X") or kind() == \'not_on_panel("X")\'')
    A.Equal(p.widgets[1].name,'not_on_panel("X")'); A.Equal(p.sets[1].predicate.source,'not on_panel("X")')
    KanaEffects.Rules.NormalizePanelFunctions(p); A.Equal(p.sets[1].predicate.source,'not on_panel("X")')
    A.Equal(KanaEffects.Rules.ParseExpression('not_on_panel("X")'),nil,'old spelling is migration-only')
end
