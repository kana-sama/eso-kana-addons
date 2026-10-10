local T=dofile('KanaStatSources/tests/support.lua')
local K=T.load({'Core','Stats','Rules','Critical','Model','capture/Equipment','capture/Build','capture/Effects','Snapshot'})
local makeApi=dofile('KanaStatSources/tests/fixtures/capture.lua')
return {
 savagery_buff_enum_is_captured=function()
    local api=makeApi();api.BUFF_TYPE_MAJOR_SAVAGERY=4
    T.eq(K.Snapshot.New(api):Capture(false).constants.BUFF_TYPE_MAJOR_SAVAGERY,4)
 end,
 item_specific_set_values_are_cached_and_refreshed_with_equipment=function()
    local api=makeApi();local value=58;local calls=0
    api.GetItemLinkSetBonusInfo=function(link,equipped,index)
        if not equipped then calls=calls+1;return 2,'Adds '..value..' Weapon and Spell Damage.',false end
        return 2,'Adds 63 Weapon and Spell Damage.',false
    end
    local collector=K.Snapshot.New(api);local s=collector:Capture(false)
    T.eq(type(s.equipment[1].setBonuses),'table')
    T.eq(s.equipment[1].setBonuses[1].description,'Adds 58 Weapon and Spell Damage.')
    T.eq(calls,2)
    value=67;s=collector:Capture(false);T.eq(calls,2)
    T.eq(s.equipment[1].setBonuses[1].description,'Adds 58 Weapon and Spell Damage.')
    collector:Invalidate('equipment');s=collector:Capture(false);T.eq(calls,4)
    T.eq(s.equipment[1].setBonuses[1].description,'Adds 67 Weapon and Spell Damage.')
 end,
 full_dump_captures_independent_item_and_set_values=function()
    local api=makeApi()
    api.GetItemStatValue=function(bag,slot)T.eq(bag,api.BAG_WORN);return slot==0 and 606 or 0 end
    api.GetItemSetBonusInfo=function(id,index)T.eq(id,100);T.eq(index,1);return 2,'Generic set description',false end
    api.GetItemLinkSetBonusInfo=function(link,equipped,index)
        T.eq(index,1)
        return 2,equipped and 'Adds 63 Weapon and Spell Damage.' or 'Adds 60 Weapon and Spell Damage.',false
    end
    local s=K.Snapshot.New(api):Capture(true)
    T.eq(s.equipmentAudit[1].slot,0);T.eq(s.equipmentAudit[1].statValue,606)
    T.eq(s.equipmentAudit[1].weaponPower,0)
    T.eq(s.equipmentAudit[1].equippedBonuses[1].description,'Adds 63 Weapon and Spell Damage.')
    T.eq(s.equipmentAudit[1].unequippedBonuses[1].description,'Adds 60 Weapon and Spell Damage.')
    T.eq(s.setAudit[100].bonuses[1].description,'Generic set description')
    T.eq(s.sets[100].bonuses[1].description,'Adds 63 Weapon and Spell Damage.')
    T.eq(s.categoryStatus.equipmentAudit,'available')
 end,
 equipment_audit_does_not_run_on_hover=function()
    local api=makeApi();local calls=0
    api.GetItemStatValue=function()calls=calls+1;return 100 end
    local collector=K.Snapshot.New(api)
    local s=collector:Capture(false);collector:Capture(false)
    T.eq(calls,0);T.eq(s.equipmentAudit,nil);T.eq(s.setAudit,nil)
    collector:Capture(true);T.eq(calls,2)
    collector:Capture(false);T.eq(calls,2)
 end,
 unavailable_audit_api_preserves_stats_and_records_failure=function()
    local api=makeApi();api.GetItemStatValue=function()error('item stat unavailable')end
    local s=K.Snapshot.New(api):Capture(true)
    T.eq(s.stats.maxHealth.total,101);T.eq(s.equipmentAudit[1].statValue,nil)
    T.eq(s.categoryStatus.equipmentAudit,'partial')
    local found=false
    for _,e in ipairs(s.errors)do if e.api=='GetItemStatValue' and e.category=='equipmentAudit' then found=true end end
    T.eq(found,true)
 end,
 descriptions_are_not_read_twice=function()
    local api=makeApi();local calls=0;local original=api.GetAbilityDescription
    api.GetAbilityDescription=function(id,...)if id==1001 then calls=calls+1 end;return original(id,...)end
    K.Snapshot.New(api):Capture(false);T.eq(calls,1)
 end,
 equipment_cached_until_changed=function()
    local api=makeApi();local calls=0;local original=api.GetItemLinkEnchantInfo
    api.GetItemLinkEnchantInfo=function(...)calls=calls+1;return original(...)end
    local collector=K.Snapshot.New(api);collector:Capture(false);collector:Capture(false);T.eq(calls,2)
    collector:Invalidate('equipment');collector:Capture(false);T.eq(calls,4)
 end,
 native_current_bonus_refreshes=function()
    local api=makeApi();local collector=K.Snapshot.New(api)
    collector:Capture(false)
    collector.cache.build.data.skills={{id=45572,description='old'}}
    api.GetAbilityDescription=function(id)return id==45572 and 'new' or 'effect'end
    local s=collector:Capture(false);T.eq(s.skills[1].description,'new')
 end,
 private_globals_are_not_enumerated=function()
    local api=makeApi();api.ITEM_TRAIT_TYPE_WEAPON_PRECISE=4;api.EQUIP_SLOT_MAIN_HAND=4
    local originalPairs=pairs
    -- ESO's global table includes inaccessible private functions. Enumerating
    -- their values is forbidden even when the caller never invokes them.
    pairs=function(value)
        if value==api then error("Attempt to access a private function 'PickupStoreItem' from insecure code")end
        return originalPairs(value)
    end
    local ok,result=pcall(function()
        local collector=K.Snapshot.New(api)
        return {collector:Capture(false),collector:Capture(true)}
    end)
    pairs=originalPairs
    T.eq(ok,true)
    for _,s in ipairs(result)do
        T.eq(s.consistent,true);T.eq(s.stats.maxHealth.total,101)
        T.eq(s.constants.ITEM_TRAIT_TYPE_WEAPON_PRECISE,4)
        T.eq(s.constants.EQUIP_SLOT_MAIN_HAND,4)
        T.eq(s.capabilities.GetPlayerStat,true)
        T.eq(s.capabilities.GetNumBuffs,true)
        T.eq(s.capabilities.GetItemLinkWeaponType,false)
        T.eq(s.capabilities.PickupStoreItem,nil)
    end
 end,
 malformed_results=function()
    local api=makeApi();api.GetItemLinkSetInfo=function()return true,'Set',1,2,5,0/0,0 end
    local s=K.Snapshot.New(api):Capture(false)
    T.eq(s.stats.maxHealth.total,101);T.eq(#s.equipment,2);T.eq(next(s.sets),nil);T.eq(s.categoryStatus.equipment,'partial')
    api=makeApi();api.GetNumBuffs=function()return nil end;s=K.Snapshot.New(api):Capture(false)
    T.eq(s.categoryStatus.effects,'partial');local found=false;for _,e in ipairs(s.errors)do if e.api=='GetNumBuffs'then found=true end end;T.eq(found,true)
    api=makeApi();api.GetNumBuffs=function()return math.huge end;s=K.Snapshot.New(api):Capture(false);T.eq(#s.effects,0);T.eq(s.categoryStatus.effects,'partial')
 end,
 collector_isolation=function()
    local original=K.CaptureEquipment.Read;K.CaptureEquipment.Read=function()error('collector failure')end
    local ok,s=pcall(function()return K.Snapshot.New(makeApi()):Capture(true)end);K.CaptureEquipment.Read=original
    T.eq(ok,true);T.eq(s.stats.maxHealth.total,101);T.eq(#s.effects,1);T.eq(s.categoryStatus.equipment,'partial');T.eq(#s.equipment,0)
 end,
 nullable_api=function()
    local api=makeApi();api.GetItemLinkSetInfo=function()return false,'',0,0,0,nil,0 end
    local s=K.Snapshot.New(api):Capture(false);local bad=false;for _,e in ipairs(s.errors)do if e.api=='GetItemLinkSetInfo'then bad=true end end;T.eq(bad,false)
 end,
    captures_character_and_both_bars=function()
        local s=K.Snapshot.New(makeApi()):Capture(true)
        T.eq(s.consistent,true);T.eq(s.schemaVersion,1);T.eq(s.bars.back[3].abilityId,103)
        T.eq(s.effects[1].abilityId,1001);T.eq(s.effects[1].castByPlayer,false)
        T.eq(s.attributes.health.spent,10);T.eq(s.attributes.health.perPoint,120)
        T.eq(s.stats.maxHealth.total,101);T.eq(s.stats.maxHealth.withoutBonus,100)
        T.eq(s.equipment[1].armorRating,100);T.eq(s.meta.characterId,'123')
    end,
    category_error_does_not_erase_others=function()
        local api=makeApi();api.GetItemLinkArmorRating=function()error('unavailable') end
        local s=K.Snapshot.New(api):Capture(true)
        T.eq(s.stats.maxHealth.total,101);T.eq(#s.effects,1)
        assert(#s.errors>0);T.eq(s.equipment[1].armorRating,nil)
    end,
    one_retry_then_mark_unstable=function()
        local api=makeApi();local count=0
        api.GetActiveWeaponPairInfo=function() count=count+1;return count%2+1,false end
        local s=K.Snapshot.New(api):Capture(false)
        T.eq(s.consistent,false);T.eq(count,4)
    end,
    changing_total_is_detected=function()
        local api=makeApi();local n=0
        api.GetPlayerStat=function(id,opt) n=n+1;return n end
        T.eq(K.Snapshot.New(api):Capture(false).consistent,false)
    end,
    missing_api_is_explicit=function()
        local api=makeApi();api.GetPlayerStat=nil
        local s=K.Snapshot.New(api):Capture(false)
        T.eq(s.stats.maxHealth.total,nil);assert(#s.errors>0)
    end,
    build_is_cached_until_invalidated=function()
        local api=makeApi();local calls=0
        api.GetNumSkillTypes=function()calls=calls+1;return 0 end
        local c=K.Snapshot.New(api);c:Capture(false);local cached=c:Capture(false);T.eq(calls,1)
        T.eq(cached.capabilities.GetNumSkillTypes,true)
        T.eq(cached.capabilities.GetNumChampionDisciplines,true)
        c:Invalidate('build');c:Capture(false);T.eq(calls,2)
    end,
}
