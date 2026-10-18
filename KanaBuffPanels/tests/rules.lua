loadModule('Rules')
local Rules = KanaBuffPanels.Rules
local function normalize(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')):lower() end
local function new(saved) return Rules.New(saved or {}, normalize) end

function Tests.priority_and_unhide_preserve_destination()
    local r = new()
    local id = assert(r:AddPanel('Food'))
    eq(r:Destination('ability:42'), 'default')
    assert(r:Assign('ability:42', id)); eq(r:Destination('ability:42'), id)
    r:Hide('ability:42', 'Food buff'); eq(r:Destination('ability:42'), 'hidden')
    r:Unhide('ability:42'); eq(r:Destination('ability:42'), id)
    assert(r:Assign('ability:42', nil)); eq(r:Destination('ability:42'), 'default')
end
function Tests.panel_names_are_trimmed_and_unique()
    local saved = {}; local r = new(saved)
    local id = assert(r:AddPanel('  Food  ')); eq(saved.panels[id].name, 'Food')
    eq(r:AddPanel('food'), nil); eq(r:AddPanel(' \t '), nil)
    local other = assert(r:AddPanel('Short'))
    eq(r:RenamePanel(other, 'FOOD'), false)
    assert(r:RenamePanel(id, 'Meals')); eq(saved.panels[id].name, 'Meals')
    assert(r:Assign('ability:42', id)); eq(r:RenamePanel(999, 'Missing'), false)
    eq(r:Destination('ability:42'), id)
end
function Tests.delete_clears_assignments_but_keeps_hidden_and_ids()
    local r = new(); local id = assert(r:AddPanel('Food'))
    r:Assign('ability:42', id); r:Hide('ability:42', 'Food buff')
    assert(r:RemovePanel(id)); eq(r:Destination('ability:42'), 'hidden')
    r:Unhide('ability:42'); eq(r:Destination('ability:42'), 'default')
    assert(r:AddPanel('Food') > id)
    eq(r:Assign('ability:42', id), false)
end
function Tests.identity_uses_separate_namespaces_and_valid_ids()
    eq(Rules.EffectKey({abilityId=42}), 'ability:42')
    eq(Rules.EffectKey({isArtificial=true,effectId=42,abilityId=42}), 'artificial:42')
    eq(Rules.EffectKey({isArtificial=true,effectId=0}), 'artificial:0')
    for _, data in ipairs({{}, {abilityId=0}, {abilityId=-1}, {abilityId='42'}, {abilityId=1.5}, {isArtificial=true,abilityId=42}}) do
        eq(Rules.EffectKey(data), nil)
    end
end
function Tests.zero_artificial_id_survives_saved_rule_validation()
    local saved = {};local r = new(saved);local id = assert(r:AddPanel('Account'))
    assert(r:Assign('artificial:0', id));assert(r:Hide('artificial:0', 'ESO Plus'))
    r = new(saved);eq(r:Destination('artificial:0'), 'hidden')
    r:Unhide('artificial:0');eq(r:Destination('artificial:0'), id)
    for _,key in ipairs({'ability:0','artificial:-1','artificial:0.5'}) do
        eq(r:Assign(key, id), false);eq(r:Hide(key, 'Invalid'), false)
    end
    for _,value in ipairs({-1,0.5,'0',math.huge}) do
        eq(Rules.EffectKey({isArtificial=true,effectId=value}), nil)
    end
end
function Tests.reload_preserves_valid_records_and_repairs_missing_tables()
    local saved = {panels={[7]={name='Food'},broken=false},nextPanelId=2,
        assignments={['ability:42']=7,['ability:43']=999}, hidden={['ability:44']={name='Same'}}}
    local r = new(saved)
    eq(r:Destination('ability:42'), 7); eq(r:Destination('ability:43'), 'default')
    eq(r:Destination('ability:44'), 'hidden'); assert(r:AddPanel('New') > 7)
    new(saved); eq(r:Destination('ability:42'), 7)
    local bad = {panels=false,assignments='bad',hidden=1}
    new(bad); eq(type(bad.panels), 'table'); eq(type(bad.hidden), 'table')
end
function Tests.same_label_does_not_merge_different_effects()
    local saved = {}; local r = new(saved)
    r:Hide('ability:1', 'Same'); r:Hide('ability:2', 'Same')
    r:Unhide('ability:1'); eq(r:Destination('ability:2'), 'hidden')
    eq(r:Destination(nil), 'default'); eq(r:Assign(nil, nil), false)
end
function Tests.saved_proxy_does_not_need_top_level_iteration()
    local backing = {}; local proxy = setmetatable({}, {__index=backing,__newindex=backing})
    local r = new(proxy); local id = assert(r:AddPanel('Food'))
    r:Assign('ability:1', id); eq(backing.assignments['ability:1'], id)
end
