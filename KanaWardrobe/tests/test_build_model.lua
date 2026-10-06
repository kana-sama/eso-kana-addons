local Fake=dofile(ROOT..'/tests/support/fake_eso.lua')
local function setup() return Fake.Load({'Core.lua','Slots.lua','lang/en.lua','BuildModel.lua','Presets.lua'}) end
local function gear(uid) return {[11]={kind='item',uid=uid,link='ring'}} end
return {
    multi_component_patch_commits_once_or_leaves_the_preset_unchanged=function()
        local k=setup();local r=k.Presets.New({},'EU','a','1','One')
        local p=assert(r:PatchComponents(nil,{
            equipment={op='replace',value=gear('a')},
            attributes={op='replace',value={health=0,magicka=0,stamina=64}},
        },'Parts'))
        local bad,problem=r:PatchComponents(p.id,{
            equipment={op='remove'},attributes={op='replace',value={health=-1,magicka=0,stamina=64}},
        },p.name,p.revision)
        assert(not bad and problem and r:Get(p.id).equipment and r:Get(p.id).revision==p.revision)
        local barriers,events=0,0
        r.emit=function()events=events+1;assert(barriers==1 and not r:Get(p.id).equipment)end
        local stored=assert(r:PatchComponents(p.id,{
            equipment={op='remove'},attributes={op='replace',value={health=64,magicka=0,stamina=0}},
        },p.name,p.revision,function(value)
            barriers=barriers+1;assert(not value.equipment and value.attributes.health==64)
            assert(r:Get(p.id).revision==p.revision+1)
        end))
        assert(stored.revision==p.revision+1 and barriers==1 and events==1)
    end,
    werewolf_slots_are_optional_constraints_and_survive_storage=function()
        local k=setup();local ref={kind='skill',skillKey='50:active:152',expectedMorph=2}
        local wanted={abilities={bars={werewolf={[2]=ref,[4]={kind='empty'}}}}}
        local normalized=assert(k.BuildModel.Normalize(wanted));assert(k.BuildModel.HasParts(normalized))
        local actual={abilities={bars={werewolf={[1]={kind='empty'},[2]=ref,[4]={kind='empty'}}}}}
        assert(k.BuildModel.Matches(actual,normalized))
        actual.abilities.bars.werewolf[4]=ref
        local diff=k.BuildModel.Differences(actual,normalized)
        assert(#diff==1 and diff[1].bar=='werewolf' and diff[1].slot==4)
        local selected=k.BuildModel.Select(actual,{bars={werewolf={[2]=true,[4]=false}}})
        assert(selected.abilities.bars.werewolf[2] and not selected.abilities.bars.werewolf[4])
        assert(not k.BuildModel.Select(actual,{bars={}}).abilities)
    end,
    differences_only_include_requested_changes_not_unselected_state=function()
        local k=setup();local target={equipment=gear('wanted'),attributes={health=1,magicka=2,stamina=3},
            abilities={skills={['1:passive:2']={kind='passive',rank=1}},bars={front={[2]={kind='empty'}}}}}
        local actual={equipment=gear('other'),attributes={health=1,magicka=0,stamina=3,unspentAtCapture=5},
            abilities={skills={['1:passive:2']={kind='passive',rank=0},['1:active:3']={kind='active',purchased=true,morph=2}},
                bars={front={[1]={kind='empty'},[2]={kind='skill',skillKey='1:active:3',expectedMorph=2}},back={[1]={kind='empty'}}}}}
        local d=k.BuildModel.Differences(actual,target)
        assert(#d==4)
        assert(d[1].domain=='equipment' and d[1].slot==11 and d[1].expected.uid=='wanted' and d[1].actual.uid=='other')
        assert(d[2].domain=='attributes' and d[2].field=='magicka' and d[2].expected==2 and d[2].actual==0)
        assert(d[3].domain=='skills' and d[3].key=='1:passive:2')
        assert(d[4].domain=='bars' and d[4].slot==2 and d[4].bar=='front')
        assert(#k.BuildModel.Differences(actual,{attributes={health=1,magicka=0,stamina=3,unspentAtCapture=1}})==0)
        assert(#k.BuildModel.Differences(actual,{equipment=gear('other')})==0)
        d[3].expected.rank=10;assert(target.abilities.skills['1:passive:2'].rank==1)
    end,
    quick_slots_alias_preserves_saved_components_and_overrides_stale_equipment=function()
        local kw=setup()
        local repo=kw.Presets.New({},'EU','a','1','One')
        local initial={
            equipment=gear('a'),
            attributes={health=1,magicka=0,stamina=0},
            abilities={skills={['1:active:2']={kind='active',purchased=false}}},
        }
        assert(repo:SaveQuick(initial))
        local saved=assert(repo:SaveQuick({slots=gear('b')}))
        assert(saved.attributes.health==1)
        assert(saved.abilities.skills['1:active:2'].purchased==false)
        saved=assert(repo:SaveQuick({slots=gear('c'),equipment=gear('stale')}))
        assert(saved.equipment[11].uid=='c' and saved.attributes.health==1)
        assert(saved.abilities.skills['1:active:2'].purchased==false)
        saved=assert(repo:SaveQuick({equipment=gear('d')}))
        assert(saved.attributes==nil and saved.abilities==nil)
    end,
    bar_references_reject_zero_line_and_ability_ids=function()
        local kw=setup()
        for _,key in ipairs({'0:active:2','1:active:0','0:crafted:2','1:crafted:0'}) do
            local build={abilities={bars={front={[1]={kind='skill',skillKey=key,expectedMorph=0}}}}}
            assert(not kw.BuildModel.Normalize(build),key)
        end
    end,
    fixture_requests_require_explicit_confirmation_and_reload_is_detached=function()
        local kw=setup()
        local F=dofile(ROOT..'/tests/support/build_fixture.lua')
        local f=F.New()
        local r=f:Request('skills',{key='1:active:2'})
        assert(r.status=='pending' and #f.requests.skills==1 and #f.requests.attributes==0)
        f:Confirm(r,{ok=true})
        assert(r.status=='confirmed')
        local n=0
        f.clock:Schedule(5,function()n=n+1 end)
        f:Advance(4)
        assert(n==0)
        f:Advance(1)
        assert(n==1)
        f.journal.phase='pending'
        local reload=f:Reload()
        reload.journal.phase='done'
        assert(f.journal.phase=='pending')
    end,
    legacy_slots_migrate_without_new_parts=function()
        local kw=setup()
        local p=assert(kw.BuildModel.Normalize({slots=gear('ring-A')}))
        assert(p.equipment[11].uid=='ring-A' and p.abilities==nil and p.attributes==nil and p.slots==nil)
    end,
    gear_update_preserves_abilities_and_attributes=function()
        local kw=setup()
        local r=kw.Presets.New({},'EU','a','1','One')
        local p=r:NewDraft()
        p.slots=nil
        p.equipment=gear('a')
        p.attributes={health=0,magicka=20,stamina=0}
        p.abilities={skills={['1:active:2']={kind='active',purchased=false}}}
        p=assert(r:Save(p,0))
        p.slots=gear('b')
        p=assert(r:Save(p,1))
        assert(p.equipment[11].uid=='b' and p.attributes.magicka==20 and p.abilities.skills['1:active:2'].purchased==false)
        p.slots=nil
        p.attributes=nil
        p=assert(r:Save(p,2))
        assert(p.attributes==nil)
    end,
    historical_empty_records_survive_migration_in_order=function()
        local kw=setup()
        local saved={schemaVersion=1,servers={EU={accounts={a={characters={['1']={order={'p'},presets={p={id='p',name='P',revision=4,slots={}}}}}}}}}}
        local r=kw.Presets.New(saved,'EU','a','1','One')
        assert(#r:List()==1 and r:List()[1].revision==4 and next(r:List()[1].equipment)==nil and r.character.presets.p.slots==nil)
    end,
    missing_attributes_differ_from_explicit_zero_triple=function()
        local kw=setup()
        local actual={attributes={health=1,magicka=0,stamina=0}}
        assert(kw.BuildModel.Matches(actual,{attributes=nil}))
        assert(not kw.BuildModel.Matches(actual,{attributes={health=0,magicka=0,stamina=0}}))
    end,
    account_migration_and_quick_membership=function()
        local kw=setup()
        local saved={schemaVersion=1,servers={EU={accounts={a={characters={['2']={name='Two',order={'p'},presets={p={id='p',name='P',revision=1,slots=gear('a')}},quickPreset={id='__quick__',name='Q',revision=1,slots=gear('b')}}}}}}}}
        local r=kw.Presets.New(saved,'EU','a','1','One')
        assert(saved.schemaVersion==2)
        local other=r.characters['2']
        assert(other.presets.p.slots==nil and other.quickPreset.slots==nil)
        assert(#r:Memberships('b','all')==1)
        local p=assert(r:SaveQuick(gear('c')))
        assert(p.slots==p.equipment and r.character.quickPreset.slots==nil)
    end,
    validation_and_partial_merge_selection=function()
        local kw=setup()
        local M=kw.BuildModel
        for _,v in ipairs({-1,0.5,math.huge}) do assert(not M.Normalize({attributes={health=v,magicka=0,stamina=0}})) end
        assert(not M.Normalize({abilities={skills={['1:active:2']={kind='active',purchased=true,morph=3}}}}))
        assert(not M.Normalize({abilities={skills={['1:passive:2']={kind='passive',rank=-1}}}}))
        local base={
            equipment=gear('a'),
            attributes={health=1,magicka=2,stamina=3},
            abilities={
                skills={['1:active:2']={kind='active',purchased=false}},
                bars={front={[1]={kind='empty'}}},
            },
        }
        local selected=M.Select(base,{
            equipment={[11]=false},
            skills={['1:active:2']=true},
            bars={front={[1]=true}},
            attributes=true,
        })
        assert(selected.equipment==nil and selected.abilities.skills['1:active:2'].purchased==false)
        local merged=M.Merge(base,{equipment=gear('b')})
        assert(merged.equipment[11].uid=='b' and merged.attributes.health==1 and base.equipment[11].uid=='a')
        assert(M.Matches(merged,selected))
    end,
    quick_legacy_write_preserves_optional_components_and_canonical_can_remove=function()
        local kw=setup()
        local r=kw.Presets.New({},'EU','a','1','One')
        local p=assert(r:SaveQuick({equipment=gear('a'),attributes={health=0,magicka=0,stamina=0}}))
        assert(p.attributes.health==0)
        p=assert(r:SaveQuick(gear('b')))
        assert(p.attributes.stamina==0)
        p=assert(r:SaveQuick({equipment=gear('c')}))
        assert(p.attributes==nil and #r:Memberships('b','all')==0 and #r:Memberships('c','all')==1)
    end,
    attributes_information_is_not_application_target=function()
        local kw=setup()
        assert(kw.BuildModel.Matches({attributes={health=0,magicka=0,stamina=0,unspentAtCapture=3}},{attributes={health=0,magicka=0,stamina=0,unspentAtCapture=1}}))
    end,
    legacy_empty_new_saves_rejected_but_updates_preserve_other_parts=function()
        local kw=setup()
        local r=kw.Presets.New({},'EU','a','1','One')
        assert(not r:Save(r:NewDraft(),0))
        assert(not r:SaveQuick({}))
        local p=r:NewDraft()
        p.slots=nil
        p.attributes={health=0,magicka=0,stamina=0}
        p=assert(r:Save(p,0))
        p.slots={}
        p=assert(r:Save(p,1))
        assert(p.attributes.health==0)
        assert(r:SaveQuick({attributes={health=0,magicka=0,stamina=0}}))
        assert(r:SaveQuick({}).attributes.health==0)
    end,
    empty_canonical_presets_rejected=function()
        local kw=setup()
        local r=kw.Presets.New({},'EU','a','1','One')
        local p=r:NewDraft()
        p.slots=nil
        p.equipment={}
        assert(not r:Save(p,0))
    end,
}
