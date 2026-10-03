local Fake=dofile(ROOT.."/tests/support/fake_eso.lua")
local tests={}
local function setup()
    local k=Fake.Load()
    dofile(ROOT.."/EffectModel.lua");dofile(ROOT.."/SetModel.lua")
    return k
end
local function item(slot,enchant,trait)
    return {slot=slot,metadata={enchant=enchant,trait=trait}}
end
local function enchant(description,charge) return {description=description,hasCharges=charge,language="ru"} end
local function trait(id,description) return {id=id,name="Trait",description=description,language="ru"} end
function tests.damage_bonuses_become_four_independent_totals_with_bar_scope()
    local k=setup()
    local e=k.EffectModel.Build({},{{setName="Damage",bonuses={
        {description="(5 предметов) Прямой урон, наносимый монстрам, увеличивается на 15%.",activeFront=true,activeBack=true},
        {description="Урон, наносимый монстрам, увеличивается на 15%.",activeFront=true,activeBack=true},
        {description="Ваши атаки с периодическим уроном, а также атаки с необходимостью поддержания наносят на 15% больше урона.",activeFront=true,activeBack=false},
        {description="Урон, наносимый монстрам, увеличивается на 2,5%.",activeFront=false,activeBack=true},
        {description="Прямой урон, наносимый монстрам, увеличивается на 99%.",activeFront=false,activeBack=false},
    }}})
    assert(e.stats.monsterDirectDamage.front==15 and e.stats.monsterDirectDamage.back==15)
    assert(e.stats.monsterDamage.front==15 and e.stats.monsterDamage.back==17.5)
    assert(e.stats.damageOverTime.front==15 and e.stats.damageOverTime.back==0)
    assert(e.stats.channeledDamage.front==15 and e.stats.channeledDamage.back==0)
    assert(#e.details==0)
    local v=k.EffectModel.Present({armor={},sets={},effects=e},"ru")
    assert(#v.rows==2 and v.rows[2].value=="[ +15% | +17,5% ]")
    for _,row in ipairs(v.rows)do assert(row.category=="damage")end
    assert(#v.barGroups[1].rows==2 and v.barGroups[1].rows[1].name=="Периодический урон")
    assert(v.barGroups[1].rows[2].name=="Потоковый урон")
    for _,row in ipairs(v.barGroups[1].rows)do assert(row.category=="damage")end
end
function tests.damage_extraction_preserves_only_remaining_special_text_and_source()
    local k=setup()
    local rest="Вы получаете постоянный эффект «Малая сила», увеличивающий ваш критический урон на 10%, а урон от ваших обычных и силовых атак уменьшается на 99%.\n\nДополнительный абзац."
    local e=k.EffectModel.Build({},{{setName="Амулет",bonuses={{
        description="(1 предмет) Урон, наносимый монстрам, увеличивается на |cffffff15%|r. "..rest,
        activeFront=true,activeBack=true,
    }}}})
    assert(e.stats.monsterDamage.front==15 and #e.details==1)
    assert(e.details[1].description==rest and e.details[1].source=="Амулет")
    local v=k.EffectModel.Present({armor={},sets={},effects=e},"ru")
    assert(#v.rows==1 and v.rows[1].name=="Урон по монстрам")
    assert(#v.specials==1 and v.specials[1].title=="Амулет" and v.specials[1].description==rest)
end
function tests.conditional_or_temporary_monster_damage_stays_special()
    local k=setup()
    local descriptions={
        "Пока вы скрыты, урон, наносимый монстрам, увеличивается на 15%.",
        "Урон, наносимый монстрам, увеличивается на 15% на 10 секунд.",
        "Прямой урон, наносимый монстрам, увеличивается на 15% при блокировании.",
    }
    local bonuses={}
    for _,d in ipairs(descriptions)do bonuses[#bonuses+1]={description=d,activeFront=true,activeBack=true}end
    local e=k.EffectModel.Build({},{{setName="Conditional",bonuses=bonuses}})
    assert(next(e.stats)==nil and #e.details==3)
    for i,d in ipairs(descriptions)do assert(e.details[i].description==d)end
end
function tests.critical_rating_and_percent_merge_per_bar_using_current_native_conversion()
    local k=setup()
    local original=GetCriticalStrikeChance
    local divisor=100
    GetCriticalStrikeChance=function(value)return value/divisor end
    local ok,err=pcall(function()
        local summary={armor={},sets={},effects={stats={
            critical={front=1000,back=500},criticalChance={front=6.2,back=0}},details={}}}
        local first=k.EffectModel.Present(summary,"ru")
        assert(#first.rows==1 and first.rows[1].name=="Шанс критического удара")
        assert(first.rows[1].value=="[ +16,2% | +5% ]" and #first.barGroups[1].rows==0)
        divisor=200 -- A changed player conversion must take effect on the next hover.
        local second=k.EffectModel.Present(summary,"en")
        assert(#second.rows==1 and second.rows[1].value=="[ +11.2% | +2.5% ]")
        assert(summary.effects.stats.critical.front==1000 and summary.effects.stats.criticalChance.front==6.2)
        summary.effects.stats.critical.back=0
        local exclusive=k.EffectModel.Present(summary,"en")
        assert(#exclusive.rows==0 and #exclusive.barGroups[1].rows==1)
        assert(exclusive.barGroups[1].rows[1].value=="+11.2%")
    end)
    GetCriticalStrikeChance=original
    assert(ok,err)
end
function tests.direct_critical_percentage_is_not_rating_and_critical_damage_stays_separate()
    local k=setup()
    local e=k.EffectModel.Build({
        item(EQUIP_SLOT_HEAD,enchant("Шанс крит. удара +2191,2.")),
        item(EQUIP_SLOT_CHEST,enchant("Шанс критического удара +3%.")),
        item(EQUIP_SLOT_HAND,{description="Adds 2% Critical Chance.",language="en"}),
        item(EQUIP_SLOT_LEGS,{description="Adds 10% Critical Damage.",language="en"}),
    },{})
    assert(e.stats.critical.front==2191.2 and e.stats.criticalChance.front==5)
    local view=k.EffectModel.Present({armor={},sets={},effects=e},"en")
    assert(#view.rows==1 and view.rows[1].value=="+15%")
    assert(#view.details==1 and view.details[1]=="Adds 10% Critical Damage.")
end
function tests.recovery_is_halved_once_for_each_bar_without_changing_raw_totals()
    local k=setup()
    local summary={armor={},sets={},effects={stats={healthRecovery={front=67,back=100}},details={}}}
    for i=1,2 do
        local view=k.EffectModel.Present(summary,"en")
        assert(view.metrics[1].recovery=="[ +33.5/s | +50/s ]")
    end
    assert(summary.effects.stats.healthRecovery.front==67)
end
local function withTraits(fn)
    local definitions={ARMOR_TRAINING=15,ARMOR_INFUSED=16,JEWELRY_INFUSED=33,ARMOR_DIVINES=18,
        WEAPON_PRECISE=3,WEAPON_CHARGED=2,JEWELRY_ROBUST=23,JEWELRY_TRIUNE=30,JEWELRY_BLOODTHIRSTY=31,WEAPON_TRAINING=6}
    local old={}
    for key,id in pairs(definitions) do local name="ITEM_TRAIT_TYPE_"..key;old[name]={_G[name]};_G[name]=id end
    local ok,err=pcall(fn)
    for name,v in pairs(old) do _G[name]=v[1] end
    assert(ok,err)
end
function tests.mixed_glyphs_split_into_shared_stats_and_sum_across_set_and_trait_sources()
    local k=setup()
    withTraits(function()
        local result=k.EffectModel.Build({
            item(EQUIP_SLOT_RING1,enchant("Сила оружия и заклинаний +174.\nВосст. магии +10.")),
            item(EQUIP_SLOT_RING2,enchant("Сила оружия и заклинаний +320.\nВосст. запаса сил +20.")),
            item(EQUIP_SLOT_NECK,nil,trait(23,"Увеличивает максимальный запас сил на 407.")),
        },{{setName="Set",bonuses={{description="(2 предмета) Макс. запас сил +1096.",activeFront=true,activeBack=false}}}})
        assert(result.stats.power.front==494 and result.stats.power.back==494)
        assert(result.stats.magickaRecovery.front==10 and result.stats.staminaRecovery.front==20)
        assert(result.stats.stamina.front==1503 and result.stats.stamina.back==407)
        assert(#result.details==0)
    end)
end
function tests.training_is_a_percent_and_native_infused_value_is_not_boosted_twice()
    local k=setup()
    withTraits(function()
        local e=k.EffectModel.Build({
            item(EQUIP_SLOT_HEAD,enchant("Макс. запас сил +100."),trait(15,"Увеличивает опыт, получаемый за убийства, на 6%.")),
            item(EQUIP_SLOT_CHEST,enchant("Макс. запас сил +220."),trait(16,"Усиливает зачарование этого предмета на 10%.")),
            item(EQUIP_SLOT_MAIN_HAND,nil,trait(6,"Увеличивает опыт, получаемый за убийства, на 9%.")),
        },{})
        assert(e.stats.stamina.front==320 and e.stats.stamina.back==320)
        assert(e.stats.experience.front==15 and e.stats.experience.back==6 and #e.details==0)
    end)
end
function tests.conditional_numbers_and_charged_weapon_damage_are_not_permanent_stats()
    local k=setup()
    local e=k.EffectModel.Build({item(EQUIP_SLOT_MAIN_HAND,enchant("Сила оружия и заклинаний +452 на 5 секунд.",true))},
        {{setName="Proc",bonuses={{description="(5 предметов) Когда вы наносите урон, сила оружия и заклинаний +500.",activeFront=true,activeBack=true}}}})
    assert(not e.stats.power and #e.details==2)
    assert(e.details[1].front and not e.details[1].back)
end
function tests.format_orders_resources_recovery_then_other_stats_and_displays_both_bars()
    local k=setup()
    local e={stats={stamina={front=320,back=200},magickaRecovery={front=10,back=0},experience={front=6,back=6},power={front=494,back=494}},details={}}
    local view=k.EffectModel.Present({armor={[2]=7},sets={{setName="Set",front=5,back=3,max=5}},effects=e},"ru")
    assert(view.metrics[1].value=="7" and view.sets[1].value=="[|c8DD5905/5|r | |cE6C65B3/5|r]")
    assert(view.metrics[2].value=="[ +320 | +200 ]" and view.metrics[3].recovery=="[ +5/s | — ]")
    assert(view.rows[1].value=="+494" and view.rows[2].value=="+6%")
    assert(view.differentBars)
end
function tests.unrecognized_localization_retains_the_complete_description()
    local k=setup();local e=k.EffectModel.Build({item(EQUIP_SLOT_HEAD,enchant("未知の効果 +100 と +200"))},{})
    assert(next(e.stats)==nil and e.details[1].description=="未知の効果 +100 と +200")
end
function tests.passive_english_stats_and_localized_decimals_are_supported()
    local k=setup()
    local e=k.EffectModel.Build({
        item(EQUIP_SLOT_HEAD,{description="Adds 1,000 Maximum Stamina.",language="en"}),
        item(EQUIP_SLOT_CHEST,enchant("Макс. запас сил +200,5.")),
    },{})
    assert(e.stats.stamina.front==1200.5)
end
function tests.triune_uses_named_resources_not_position_in_description()
    local k=setup()
    withTraits(function()
        local e=k.EffectModel.Build({item(EQUIP_SLOT_RING1,nil,trait(30,"Increases Maximum Magicka by 435, Maximum Stamina by 435, and Maximum Health by 478."))},{})
        assert(e.stats.health.front==478 and e.stats.magicka.front==435 and e.stats.stamina.front==435)
    end)
end
function tests.bloodthirsty_sums_strength_without_summing_health_threshold()
    local k=setup()
    withTraits(function()
        local t=trait(31,"Increases your Weapon and Spell Damage against enemies under 90% Health by up to 350.")
        local e=k.EffectModel.Build({item(EQUIP_SLOT_RING1,nil,t),item(EQUIP_SLOT_RING2,nil,t),item(EQUIP_SLOT_NECK,nil,t)},{})
        assert(not e.stats.power and #e.details==1)
        assert(e.details[1].description:find("1050",1,true) and e.details[1].description:find("90%",1,true))
    end)
end
function tests.screen_bonus_text_with_markup_is_aggregated_without_source_labels()
    local k=setup()
    local e=k.EffectModel.Build({
        item(EQUIP_SLOT_RING1,enchant("Сила оружия и заклинаний +|cffffff174|r.\r\nВосст. магии +|cffffff10|r.")),
        item(EQUIP_SLOT_RING2,enchant("Сила оружия и заклинаний +|cffffff160|r.\r\nВосст. запаса сил +|cffffff10|r.")),
    },{{setName="Смертоносный удар",bonuses={
        {description="Сила оружия и заклинаний +|cffffff124|r",activeFront=true,activeBack=true},
        {description="Восст. магии +|cffffff67|r",activeFront=true,activeBack=true},
    }},{setName="Ловчий",bonuses={
        {description="Сила оружия и заклинаний +124",activeFront=true,activeBack=true},
        {description="Пробивание +1435",activeFront=true,activeBack=true},
    }},{setName="Амулет",bonuses={{description="Пробивание +1650",activeFront=true,activeBack=true}}}})
    assert(e.stats.power.front==582 and e.stats.power.back==582)
    assert(e.stats.magickaRecovery.front==77)
    assert(e.stats.penetration and e.stats.penetration.front==3085)
    assert(#e.details==0)
end
function tests.armor_includes_only_each_active_bar_shield_and_native_trait_adjusted_rating()
    local k=setup()
    local e=k.EffectModel.Build({
        {slot=EQUIP_SLOT_CHEST,metadata={armorRating=3000}},
        {slot=EQUIP_SLOT_OFF_HAND,metadata={armorRating=1500}},
        {slot=EQUIP_SLOT_BACKUP_OFF,metadata={armorRating=1800}},
    },{})
    assert(e.armor.front==4500 and e.armor.back==4800)
end
function tests.same_special_effect_has_no_source_and_is_shown_once_across_sets()
    local k=setup()
    local e=k.EffectModel.Build({},{{setName="A",bonuses={{description="Grants Minor Force.",activeFront=true}}},
        {setName="B",bonuses={{description="Grants Minor Force.",activeBack=true}}}})
    assert(#e.details==1 and e.details[1].front and e.details[1].back)
    local view=k.EffectModel.Present({armor={},sets={},effects=e},"ru")
    assert(view.details[1]=="Grants Minor Force.")
end
function tests.native_number_markup_is_not_counted_as_extra_trait_numbers()
    local k=setup()
    withTraits(function()
        local e=k.EffectModel.Build({item(EQUIP_SLOT_HEAD,
            enchant("Сила оружия и заклинаний +|CFFFFFF|u0:0:174|u|R."),
            trait(18,"Усиливает эффекты камней Мундуса на |cffffff|u0:0:8,1|u|r%."))},{})
        assert(e.stats.power.front==174 and e.stats.mundus.front==8.1 and #e.details==0)
    end)
end
function tests.reinforced_is_already_in_native_armor_rating()
    local k=setup();local old=ITEM_TRAIT_TYPE_ARMOR_REINFORCED;ITEM_TRAIT_TYPE_ARMOR_REINFORCED=13
    local e=k.EffectModel.Build({{slot=EQUIP_SLOT_CHEST,metadata={armorRating=1200,
        trait=trait(13,"Increases this item's Armor value by 20%.")}}},{})
    ITEM_TRAIT_TYPE_ARMOR_REINFORCED=old
    assert(e.armor.front==1200 and #e.details==0)
end
function tests.russian_text_accepts_decimal_point_as_well_as_comma()
    local k=setup()
    withTraits(function()
        local e=k.EffectModel.Build({item(EQUIP_SLOT_HEAD,nil,trait(18,"Усиливает эффекты камней Мундуса на |cffffff8.1|r%."))},{})
        assert(math.abs(e.stats.mundus.front-8.1)<0.00001)
    end)
end
function tests.last_native_preview_sample_preserves_raw_markup_and_replaces_previous_sample()
    local k=setup();k.runtime={saved={previewSample={old=true}}}
    local raw="Сила оружия и заклинаний +|cffffff174|r."
    local meta={valid=true,availableToEquip=true,armorType=2,enchant=enchant(raw)}
    k.SetModel.Build({slots={[EQUIP_SLOT_HEAD]={kind="item",uid="a",link="a"}}},function()return meta end)
    local sample=k.runtime.saved.previewSample
    assert(sample.version==4 and #sample.items==1 and sample.items[1].metadata.enchant.description==raw)
    assert(not sample.old)
    meta.enchant.description="changed"
    assert(sample.items[1].metadata.enchant.description==raw)
end
function tests.resource_strip_omits_zero_parts_and_empty_resources_and_uses_per_second_rates()
    local k=setup()
    local view=k.EffectModel.Present({armor={},sets={},effects={stats={
        health={front=0,back=0},healthRecovery={front=0,back=0},
        stamina={front=3702,back=3702},staminaRecovery={front=67,back=67},
        magickaRecovery={front=77,back=77}},details={}}},"ru")
    assert(#view.metrics==2,"health must be entirely omitted")
    assert(view.metrics[1].key=="stamina" and view.metrics[1].value=="+3702" and view.metrics[1].recovery=="+33,5/s")
    assert(view.metrics[2].key=="magicka" and view.metrics[2].value==nil and view.metrics[2].recovery=="+38,5/s")
    assert(#view.rows==0 and #view.details==0,"resource bonuses must only appear at the top")
    view=k.EffectModel.Present({armor={},sets={},effects={stats={health={front=100,back=100}},details={}}},"en")
    assert(#view.metrics==1 and view.metrics[1].value=="+100" and view.metrics[1].recovery==nil)
end
function tests.actual_client_preset_has_one_total_per_stat_and_no_numeric_duplicates_in_details()
    local k=setup()
    withTraits(function()
        local sample=dofile(ROOT.."/tests/fixtures/preset_effects_ru.lua")
        local e=k.EffectModel.Build(sample.items,sample.sets)
        for key,expected in pairs({power=866,penetration=3085,critical=1268,stamina=3702,
            healthRecovery=67,staminaRecovery=87,magickaRecovery=77,mundus=56.7,
            monsterDirectDamage=15,monsterDamage=15,damageOverTime=15,channeledDamage=15})do
            assert(e.stats[key] and math.abs(e.stats[key].front-expected)<0.00001,key)
            assert(math.abs(e.stats[key].back-expected)<0.00001,key)
        end
        assert(e.stats.criticalChance.front==6.2 and e.stats.criticalChance.back==0)
        assert(e.stats.statusChance.front==0 and e.stats.statusChance.back==225)
        local view=k.EffectModel.Present({armor={[2]=7},sets=sample.sets,effects=e},"ru")
        assert(view.metrics[3].value==nil and view.metrics[3].recovery=="+33,5/s")
        assert(view.metrics[4].value=="+3702" and view.metrics[4].recovery=="+43,5/s")
        assert(view.metrics[5].value==nil and view.metrics[5].recovery=="+38,5/s")
        assert(#view.rows==8 and #view.barGroups[1].rows==0 and #view.barGroups[2].rows==1 and #view.details==3)
        local function checkBreakdown(t,value)
            assert(t and t.value==value,"tooltip total differs from the visible effect")
            local f,b=0,0
            for _,row in ipairs(t.rows)do f=f+row.front;b=b+row.back end
            assert(math.abs(f-t.front)<.000001 and math.abs(b-t.back)<.000001,"displayed source values do not add up")
        end
        for _,row in ipairs(view.rows)do checkBreakdown(row.tooltip,row.value)end
        for _,group in ipairs(view.barGroups)do for _,row in ipairs(group.rows)do checkBreakdown(row.tooltip,row.value)end end
        for _,metric in ipairs(view.metrics)do
            if metric.tooltip then checkBreakdown(metric.tooltip,metric.value)end
            if metric.recoveryTooltip then checkBreakdown(metric.recoveryTooltip,metric.recovery)end
        end
        for _,d in ipairs(view.details)do
            assert(not d:find("Пробивание",1,true) and not d:find("Восст.",1,true) and not d:find("Макс.",1,true))
        end
    end)
end
function tests.client_digit_class_must_not_consume_utf8_bytes_for_ve_ghe_short_i()
    -- Client probe replaced B2/B3/B9 continuation bytes with numeric tokens:
    -- these are also Latin-1 superscript digits under the client's classification.
    local nativeGsub=string.gsub
    local extra=string.char(178,179,185)
    local function clientPattern(pattern)
        local result={};local inClass=false;local i=1
        while i<=#pattern do
            local c=pattern:sub(i,i)
            if c=="%" and i<#pattern then
                local cls=pattern:sub(i+1,i+1)
                if cls=="d" then result[#result+1]=inClass and ("0-9"..extra) or ("[0-9"..extra.."]")
                else result[#result+1]="%"..cls end
                i=i+2
            else
                if c=="[" then inClass=true elseif c=="]" then inClass=false end
                result[#result+1]=c;i=i+1
            end
        end
        return table.concat(result)
    end
    string.gsub=function(value,pattern,...)return nativeGsub(value,clientPattern(pattern),...)end
    local ok,err=pcall(tests.actual_client_preset_has_one_total_per_stat_and_no_numeric_duplicates_in_details)
    string.gsub=nativeGsub
    assert(ok,err)
end
function tests.bar_only_effects_are_grouped_and_multi_paragraph_effects_are_kept_whole_at_end()
    local k=setup()
    local long="First paragraph.\n\nSecond paragraph.\n\nFinal paragraph."
    local e={stats={criticalChance={front=6,back=0},statusChance={front=0,back=225},power={front=142,back=61}},details={
        {description=long,source="Mythic set",front=true,back=true},
        {description="Main proc",front=true,back=false},
        {description="Shared proc",front=true,back=true},
        {description="Backup proc",front=false,back=true},
        {description="Only main.\nAnother paragraph.",source="Weapon enchant",front=true,back=false}}}
    local v=k.EffectModel.Present({armor={},sets={},effects=e},"ru")
    assert(#v.rows==1 and v.rows[1].name=="Сила оружия и заклинаний")
    assert(#v.details==1 and v.details[1]=="Shared proc")
    assert(v.barGroups[1].title=="I · Основная" and v.barGroups[2].title=="II · Запасная")
    assert(v.barGroups[1].rows[1].value=="+6%" and v.barGroups[2].rows[1].value=="+225%")
    assert(v.barGroups[1].details[1]=="Main proc" and v.barGroups[2].details[1]=="Backup proc")
    assert(#v.specials==2 and v.specials[1].description==long and v.specials[1].bar==nil)
    assert(v.specials[2].bar=="front" and v.specials[2].description=="Only main.\nAnother paragraph.")
    assert(v.specials[1].title=="Mythic set" and v.specials[2].title=="Weapon enchant · I · Основная")
    assert(e.details[1].description==long,"presentation must not mutate the source effect")
end
function tests.empty_armor_metrics_are_omitted_but_nonzero_backup_armor_is_retained()
    local k=setup()
    local summary={armor={[1]=0,[2]=0,[3]=0},sets={},effects={stats={},details={},armor={front=0,back=0}}}
    assert(#k.EffectModel.Present(summary,"ru").metrics==0)
    summary.armor[1]=2;summary.effects.armor.back=100
    local v=k.EffectModel.Present(summary,"ru")
    assert(#v.metrics==2 and v.metrics[1].value=="2" and v.metrics[2].value=="[ — | 100 ]")
end
function tests.breakdowns_preserve_items_set_provenance_and_exact_displayed_sums()
    local k=setup()
    local preset={name="Sources",slots={
        [EQUIP_SLOT_HEAD]={kind="item",uid="head",link="Head"},
        [EQUIP_SLOT_CHEST]={kind="item",uid="chest",link="Chest"},
        [EQUIP_SLOT_MAIN_HAND]={kind="item",uid="main",link="Main"},
        [EQUIP_SLOT_BACKUP_MAIN]={kind="item",uid="back",link="Back"},
    }}
    local summary=k.SetModel.Build(preset,function(ref)
        local weapon=ref.uid=="main" or ref.uid=="back"
        return {valid=true,availableToEquip=true,armorRating=weapon and 0 or 100,
            setId=10,setName="Set",max=2,bonuses={{required=2,description="Сила оружия и заклинаний +124."}},
            enchant=enchant(weapon and (ref.uid=="main" and "Шанс крит. удара +100." or "Шанс крит. удара +50.") or "Сила оружия и заклинаний +50. Восст. магии +67.")}
    end)
    local v=k.EffectModel.Present(summary,"ru")
    assert(v.sets[1].tooltip.link=="Head")
    local power,crit
    for _,r in ipairs(v.rows)do if r.name=="Сила оружия и заклинаний"then power=r elseif r.name=="Шанс критического удара"then crit=r end end
    assert(power.value=="+224" and #power.tooltip.rows==3)
    local sets=0
    for _,r in ipairs(power.tooltip.rows)do
        assert(r.link and r.source.uid)
        if r.source.kind=="set" then sets=sets+1;assert(r.front==124 and r.name=="Head",
            "set contributions show only the representative item name")end
    end
    assert(sets==1,"a set bonus is one collective contribution, never repeated per piece")
    assert(#crit.tooltip.rows==2 and crit.tooltip.differentBars)
    local tooltips={power.tooltip,crit.tooltip,v.metrics[1].tooltip,v.metrics[2].recoveryTooltip}
    for _,t in ipairs(tooltips)do
        local f,b=0,0
        for _,r in ipairs(t.rows)do f=f+r.front;b=b+r.back end
        assert(math.abs(f-t.front)<.000001 and math.abs(b-t.back)<.000001)
    end
    assert(v.metrics[2].recoveryTooltip.value=="+67/s")
end
function tests.rounded_breakdown_tenths_match_totals_without_merging_distinct_instances()
    local k=setup();local items={}
    for i,slot in ipairs({EQUIP_SLOT_HEAD,EQUIP_SLOT_CHEST,EQUIP_SLOT_LEGS})do
        items[#items+1]={slot=slot,source={uid=tostring(i),link="Same name",slot=slot},metadata={enchant=enchant("Макс. запас сил +0,04.")}}
    end
    local e=k.EffectModel.Build(items,{})
    local t=k.EffectModel.Present({armor={},sets={},effects=e},"ru").metrics[1].tooltip
    assert(#t.rows==3 and t.value=="+0,1")
    local sum=0;for _,r in ipairs(t.rows)do sum=sum+r.front end
    assert(sum==.1 and e.stats.stamina.front==.12)
    local second=k.EffectModel.Present({armor={},sets={},effects=e},"ru").metrics[1].tooltip
    for i,r in ipairs(t.rows)do assert(r.front==second.rows[i].front)end
end
function tests.special_effect_sources_follow_grouping_and_bar_scope()
    local k=setup()
    withTraits(function()
        local items={}
        for i,slot in ipairs({EQUIP_SLOT_RING1,EQUIP_SLOT_RING2})do
            items[#items+1]={slot=slot,source={uid="ring"..i,link="Ring"..i},metadata={trait=trait(ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY,"Увеличивает силу оружия и заклинаний вплоть до 350 в сражениях с противниками с уровнем здоровья ниже 90%.")}}
        end
        items[#items+1]={slot=EQUIP_SLOT_MAIN_HAND,source={uid="weapon",link="Weapon"},metadata={enchant=enchant("Proc",true)}}
        local e=k.EffectModel.Build(items,{{setName="Mythic",representativeLink="Mythic item",bonuses={{required=1,activeFront=true,activeBack=true,
            description="Урон, наносимый монстрам, увеличивается на 15%. First paragraph.\n\nSecond paragraph."}}}})
        local v=k.EffectModel.Present({armor={},sets={},effects=e},"ru")
        assert(#v.detailSources[1].sources==2)
        assert(v.detailSources[1].sources[1].source.link=="Ring1")
        assert(v.barGroups[1].detailSources[1].sources[1].source.link=="Weapon")
        assert(v.specials[1].tooltip.sources[1].source.link=="Mythic item")
        assert(v.specials[1].description=="First paragraph.\n\nSecond paragraph.")
    end)
end
return tests
