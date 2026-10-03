local Fake = dofile(ROOT .. "/tests/support/fake_eso.lua")
local function setup()
    local kw=Fake.Load()
    assert(kw.Slots and kw.Presets and kw.Inventory, "Missing production foundation methods")
    return kw,Fake.New()
end
local function item(uid,link) return {kind="item",uid=uid,link=link or "same-link"} end
local function save(repo,name,uid)
    local p=repo:NewDraft(); p.name=name; p.slots[EQUIP_SLOT_RING1]=item(uid)
    return assert(repo:Save(p,0))
end
return {
    duplicate_preserves_optional_parts_and_is_independent=function()
        local kw=setup();local r=kw.Presets.New({},"EU","a","1","One")
        local parts={equipment={[11]=item('ring'),[12]={kind='empty'}},
            abilities={skills={['50:active:152']={kind='active',purchased=false}},
                bars={werewolf={[2]={kind='empty'}}}},attributes={health=0,magicka=0,stamina=64}}
        for _,only in ipairs({'all','equipment','abilities','attributes'})do
            local p={id=r:NewDraft().id,name=only}
            for domain,value in pairs(parts)do if only=='all' or only==domain then p[domain]=kw.Copy(value)end end
            p=assert(r:Save(p,0));local copy=assert(r:Duplicate(p.id,p.revision))
            assert(copy.id~=p.id and copy.name~=p.name and copy.revision==1)
            local stored=r.character.presets[copy.id]
            for domain in pairs(parts)do assert((stored[domain]~=nil)==(only=='all' or only==domain))end
            assert(kw.BuildModel.Matches(stored,r.character.presets[p.id]))
            if copy.abilities then
                copy.slots=nil;copy.abilities.bars.werewolf[2]={kind='skill',skillKey='50:active:152',expectedMorph=2}
                assert(r:Save(copy,copy.revision))
                assert(r:Get(p.id).abilities.bars.werewolf[2].kind=='empty')
            end
        end
        assert(#r:List()==8)
    end,
    duplicate_names_fit_unicode_limit_and_avoid_collisions=function()
        local kw=setup();kw.Strings.COPY='копия'
        local r=kw.Presets.New({},"EU","a","1","One")
        local p=save(r,string.rep('Я',48),'ring')
        local a=assert(r:Duplicate(p.id,p.revision));local b=assert(r:Duplicate(p.id,p.revision))
        assert(a.name==string.rep('Я',40)..' (копия)')
        assert(b.name==string.rep('Я',38)..' (копия 2)')
        assert(kw.Presets.NormalizeName(a.name) and kw.Presets.NormalizeName(b.name))
        local n=#r:List();local copy,err=r:Duplicate(p.id,p.revision+1)
        assert(not copy and err.code=='revisionConflict' and #r:List()==n)
        assert(r:Delete(p.id,p.revision));copy,err=r:Duplicate(p.id,p.revision)
        assert(not copy and err.code=='presetMissing' and #r:List()==n-1)
    end,
    repository_runtime_equipment_alias_is_detached_from_saved_schema=function()
        local kw=setup();local saved={};local r=kw.Presets.New(saved,"EU","a","1","One")
        local p=save(r,"Alias","ring");assert(p.slots==p.equipment)
        local stored=r.character.presets[p.id];assert(stored.slots==nil and stored.equipment[11].uid=="ring")
        p.slots[11].uid="changed";assert(stored.equipment[11].uid=="ring")
        local q=assert(r:SaveQuick({[11]=item("quick")}));assert(q.slots==q.equipment)
        assert(r.character.quickPreset.slots==nil and #r:Memberships("quick","current")==1)
    end,
    preview_metadata_reads_localized_armor_enchant_and_trait_only_when_requested=function()
        local kw,api=setup();local calls=0
        api.GetItemLinkArmorType=function()calls=calls+1;return 2 end
        api.GetItemLinkArmorRating=function(link,condition)assert(link=="ring" and condition==false);calls=calls+1;return 1234 end
        api.GetItemLinkEnchantInfo=function()calls=calls+1;return true,"Stamina","Adds 100 stamina." end
        api.DoesItemLinkHaveEnchantCharges=function()return false end
        api.GetItemLinkTraitInfo=function()calls=calls+1;return 7,"Gain 9% experience." end
        api.GetString=function(key,id)assert(key=="SI_ITEMTRAITTYPE" and id==7);return "Training" end
        local inventory=kw.Inventory.New(api)
        local m=inventory:Metadata("ring",nil,false);assert(calls==0 and m.enchant==nil)
        m=inventory:Metadata("ring",nil)
        assert(calls==4 and m.armorType==2 and m.armorRating==1234)
        assert(m.enchant.name=="Stamina" and m.enchant.description=="Adds 100 stamina.")
        assert(not m.enchant.hasCharges,"EnchantInfo true must not turn passive glyphs into weapon procs")
        assert(m.trait.id==7 and m.trait.name=="Training" and m.trait.description=="Gain 9% experience.")
        api.GetItemLinkEnchantInfo=function()return false,"Stamina","Adds 100 stamina." end
        assert(inventory:Metadata("ring",nil).enchant,"a nonempty description is usable regardless of the ambiguous boolean")
        api.DoesItemLinkHaveEnchantCharges=function()return true end
        assert(inventory:Metadata("ring",nil).enchant.hasCharges)
    end,
    equipment_snapshot_skips_set_descriptions_but_keeps_constraints=function()
        local kw,api=setup();api.bags[BAG_BACKPACK][1]=item("ring")
        local calls=0;local original=api.GetItemLinkSetInfo
        api.GetItemLinkSetInfo=function(...)calls=calls+1;return original(...)end
        local inventory=kw.Inventory.New(api)
        local state=inventory:Capture("equipment")
        assert(calls==0,"equipment planning must not build set tooltips")
        assert(state.byUid.ring.metadata.valid and state.byUid.ring.metadata.itemId>0)
        inventory:Capture();assert(calls>0,"full metadata remains available for previews")
    end,
    three_states_and_copy=function()
        local kw=setup(); local S=kw.Slots
        assert(not S.Equal({}, {[0]={kind="empty"}}))
        assert(not S.Equal({[0]=item("a")}, {[0]=item("b")}))
        local original={[0]=item("a")}; local copy=S.Copy(original); copy[0].uid="b"
        assert(original[0].uid=="a")
        local worn=S.FromWorn(function(slot) if slot==11 then return item("ring") end end)
        local n=0; for _ in pairs(worn) do n=n+1 end
        assert(n==14 and worn[11].uid=="ring" and worn[20].kind=="empty")
    end,
    identity_follows_bag_moves=function()
        local kw,api=setup(); local repo=kw.Presets.New({},"EU","@a","1","One")
        save(repo,"A","ring-1"); save(repo,"B","ring-1")
        api.bags[1][3]=item("ring-1"); api.bags[1][4]=item("ring-2")
        local inventory=kw.Inventory.New(api)
        assert(inventory:Resolve("ring-1",true).slotIndex==3)
        api.bags[1][19]=api.bags[1][3]; api.bags[1][3]=nil
        assert(inventory:Resolve("ring-1",true).slotIndex==19)
        assert(#repo:Memberships("ring-1","current")==2)
        assert(#repo:Memberships("ring-2","current")==0)
        api.bags[1][19].link="upgraded-link"
        assert(inventory:Resolve("ring-1",true).link=="upgraded-link")
    end,
    repositories_isolate_world_and_account_and_characters=function()
        local kw=setup(); local saved={}; local events={}
        local a=kw.Presets.New(saved,"EU","@a","1","One",function(e) events[#events+1]=e end)
        local p=save(a,"A","ring"); local q=save(a,"B","ring")
        local b=kw.Presets.New(saved,"EU","@a","2","Two"); save(b,"Other","ring")
        local c=kw.Presets.New(saved,"NA","@a","1","One"); save(c,"NA","ring")
        local d=kw.Presets.New(saved,"EU","@b","1","One"); save(d,"Account","ring")
        assert(#a:Memberships("ring","all")==3)
        assert(#a:Memberships("ring","current")==2)
        assert(a:Delete(p.id,p.revision)); assert(#a:Memberships("ring","current")==1)
        assert(a:Get(q.id).name=="B" and #events==3)
        local copy=a:Get(q.id); copy.slots[11].uid="bad"; assert(a:Get(q.id).slots[11].uid=="ring")
    end,
    drafts_revisions_and_links=function()
        local kw=setup(); local r=kw.Presets.New({},"EU","a","1","One")
        local p=r:NewDraft(); local q=r:NewDraft()
        assert(p.id~=q.id and p.revision==0 and #r:List()==0)
        p.slots[11]=item("u","old"); p=assert(r:Save(p,0))
        assert(r:NewDraft().name~=p.name)
        p.slots[11].link="new"; local updated=assert(r:Save(p,p.revision)); assert(updated.revision==2)
        assert(r:Get(p.id).slots[11].link=="new")
        local result,err=r:Save(p,p.revision); assert(not result and err.code=="revisionConflict")
    end,
    names_are_unicode_unique_plain_single_lines=function()
        local kw=setup(); local r=kw.Presets.New({},"EU","a","1","One")
        local p=r:NewDraft(); p.name=string.rep("Я",48); p.slots[EQUIP_SLOT_HEAD]={kind="empty"}; assert(r:Save(p,0))
        for _,name in ipairs({string.rep("Я",49),"","   ","|cffffffbad","|H1:item"}) do
            local q=r:NewDraft(); q.name=name; assert(not r:Save(q,0))
        end
        local q=r:NewDraft(); q.name="  Один\nдва  "; q.slots[EQUIP_SLOT_HEAD]={kind="empty"}; q=assert(r:Save(q,0)); assert(q.name=="Один два")
        local z=r:NewDraft(); z.name="ОДИН ДВА"; local result,err=r:Save(z,0)
        assert(not result and err.code=="duplicateName")
    end,
    invalid_ids_and_closed_bank_are_not_available=function()
        local kw,api=setup(); api.bags[1][0]=item("0"); api.bags[1][1]={link="x"}
        api.bags[2][7]=item("bank"); api.bags[6][9]=item("plus")
        local i=kw.Inventory.New(api); assert(not i:Resolve("0")); assert(not i:Resolve(nil))
        api.bankOpen=true; assert(i:Resolve("bank")); assert(i:Resolve("plus")); assert(not i:Resolve("bank",true))
        api.bankOpen=false; assert(not i:Resolve("bank")); assert(not i:Resolve("plus"))
        local r=kw.Presets.New({},"EU","a","1","One"); local p=r:NewDraft(); p.slots[11]=item("0")
        assert(not r:Save(p,0)); assert(#r:Memberships("0","all")==0)
    end,
    metadata_uses_named_mythic_and_two_hand_counts=function()
        local kw,api=setup(); api.bags[1][1]=item("great","great-link")
        api.descriptions["great-link"]={equipType=EQUIP_TYPE_TWO_HAND,quality=ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE,
            setId=200,familyId=100,setName="Set",max=5,bonuses={{required=2,description="Bonus",perfected=true}}}
        local i=kw.Inventory.New(api); local m=i:Capture().byUid.great.metadata
        assert(m.valid and m.availableToEquip and m.mythic and m.perfected and m.twoHanded)
        assert(m.weight==2 and m.familyId==100 and m.setName=="Set" and m.max==5)
        assert(m.bonuses[1].required==2 and m.bonuses[1].perfected)
        assert(not i:Describe("",nil).valid)
    end,
    transient_mythic_conflict_does_not_hide_planner_eligibility=function()
        local kw,api=setup(); local i=kw.Inventory.New(api)
        api.bags[0][1]=item("old","old-mythic"); api.bags[1][5]=item("new","new-mythic")
        api.descriptions["old-mythic"]={quality=ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE,equipType=EQUIP_TYPE_NECK}
        api.descriptions["new-mythic"]={quality=ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE,equipType=EQUIP_TYPE_RING}
        api.IsEquipable=function(bag,slot)
            return not (bag==1 and slot==5 and api.bags[0][1]~=nil), "mythicConflict"
        end
        local location=i:Capture().byUid.new; local m=location.metadata
        assert(m.physicalAvailable==true and m.staticEquipable==true)
        assert(m.equipableNow==false and m.availableToEquip==true and location.availableToEquip==true)
        local step={kind="equip",uid="new",equipSlot=11}
        local ok,problem=i:Request(step)
        assert(not ok and problem.code=="notEquipable" and #api.requests==0)
        api.bags[0][1]=nil
        assert(i:Capture().byUid.new.metadata.equipableNow==true)
        assert(i:Request(step) and #api.requests==1)
    end,
    static_eligibility_rejects_level_cp_actor_and_invalid_type=function()
        local kw,api=setup(); local i=kw.Inventory.New(api)
        api.bags[1][5]=item("candidate","candidate-link")
        api.level=10; api.championPoints=100
        local variants={
            {requiredLevel=11}, {requiredChampionPoints=101},
            {actorCategory=999}, {equipType=EQUIP_TYPE_INVALID},
        }
        for _,requirements in ipairs(variants) do
            api.descriptions["candidate-link"]=requirements
            local m=i:Capture().byUid.candidate.metadata
            assert(m.physicalAvailable==true and m.staticEquipable==false and m.availableToEquip==false)
            assert(not i:Request({kind="equip",uid="candidate",equipSlot=11}))
        end
        assert(#api.requests==0)
        api.descriptions["candidate-link"]={requiredLevel=10,requiredChampionPoints=100}
        assert(i:Capture().byUid.candidate.metadata.staticEquipable==true)
    end,
    binding_requirement_is_visible_before_any_request=function()
        local kw,api=setup(); local i=kw.Inventory.New(api)
        api.bags[1][5]=item("new","new-link"); api.bags[1][5].willBind=true
        local m=i:Capture().byUid.new.metadata
        assert(m.bindingRequired==true and m.availableToEquip==true and m.staticEquipable==true)
        assert(#api.requests==0)
        api.bags[1][5].willBind=false
        assert(i:Capture().byUid.new.metadata.bindingRequired==false)
        api.bags[2][0]=item("bank"); api.bankOpen=true
        local bank=i:Capture().byUid.bank.metadata
        assert(bank.physicalAvailable==false and bank.staticEquipable==true and bank.availableToEquip==false)
    end,
    backup_slot_availability_uses_static_level_only=function()
        local kw,api=setup(); local i=kw.Inventory.New(api); api.level=14
        local state=i:Capture()
        assert(state.slotAvailability and state.slotAvailability[20].available==false)
        assert(state.slotAvailability[20].reason=="weaponBarLocked" and state.slotAvailability[21].available==false)
        assert(state.slotAvailability[4].available==true)
        api.level=15
        api.IsLockedWeaponSlot=function() return true end
        state=i:Capture()
        assert(state.slotAvailability[20].available==true and state.slotAvailability[21].available==true)
    end,
    unique_equipment_metadata_preserves_native_flag_and_base_item_id=function()
        local kw,api=setup(); local i=kw.Inventory.New(api)
        api.descriptions.unique={itemId=321,uniqueEquipped=true}
        local m=i:Describe("unique")
        assert(m.uniqueEquipped==true and m.itemId==321)
        assert(i:Describe("ordinary").uniqueEquipped==false)
    end,
    requests_revalidate_uid_and_refuse_binding_or_combat=function()
        local kw,api=setup(); local i=kw.Inventory.New(api)
        api.bags[1][19]=item("ring"); assert(i:Request({kind="equip",uid="ring",equipSlot=11}))
        assert(api.requests[1][2]==1 and api.requests[1][3]==19 and api.requests[1][4]==0 and api.requests[1][5]==11)
        api.combat=true; assert(not i:Request({kind="equip",uid="ring",equipSlot=11})); api.combat=false
        api.bags[1][19].willBind=true; assert(not i:Request({kind="equip",uid="ring",equipSlot=11}))
        assert(#api.requests==1)
        api.bags[0][11]=item("other")
        assert(not i:Request({kind="unequip",uid="ring",equipSlot=11})); assert(#api.requests==1)
        assert(i:NowMs()==100)
    end,
    bank_switch_and_guild_readiness_discard_cached_locations=function()
        local kw,api=setup(); local i=kw.Inventory.New(api)
        api.bags[2][0]=item("personal"); api.bags[3][0]=item("guild")
        api.bags[8]={[0]=item("house")}; api.bankOpen=true
        assert(i:Resolve("personal")); api.bankBag=8
        assert(not i:Resolve("personal") and i:Resolve("house"))
        api.bankOpen=false; api.guildOpen=true
        api.IsGuildBankOpen=function() return api.guildOpen end
        assert(not i:Resolve("guild")); i:SetGuildBankReady(true); assert(i:Resolve("guild"))
        i:SetGuildBankReady(false); assert(not i:Resolve("guild"))
        i:SetGuildBankReady(true); api.guildOpen=false; assert(not i:Resolve("guild"))
        api.guildOpen=true; assert(not i:Resolve("guild"))
    end,
    inventory_snapshot_is_detached_and_uid_serialization_is_exact=function()
        local kw,api=setup(); local raw={id="18446744073709551614"}
        api.bags[1][4]={uid=raw,link="x"}
        api.Id64ToString=function(value) return value.id end
        local i=kw.Inventory.New(api); local first=i:Capture()
        assert(first.byUid[raw.id].slotIndex==4)
        first.byUid[raw.id].link="changed"; first.byUid[raw.id].metadata.weight=99
        local second=i:Capture()
        assert(second.byUid[raw.id].link=="x" and second.byUid[raw.id].metadata.weight==1)
        assert(first.version==second.version)
        api.bags[1][20]=api.bags[1][4]; api.bags[1][4]=nil
        assert(i:Capture().version>second.version)
    end,
    stale_delete_does_not_change_order_or_membership=function()
        local kw=setup(); local repo=kw.Presets.New({},"EU","a","1","One")
        local first=save(repo,"First","ring"); local second=save(repo,"Second","ring")
        first.name="Renamed"; first=assert(repo:Save(first,1))
        local result,problem=repo:Delete(first.id,1)
        assert(not result and problem.code=="revisionConflict")
        local list=repo:List(); assert(list[1].id==first.id and list[2].id==second.id)
        assert(repo:Delete(first.id,2)); assert(repo:Delete(second.id,1))
        assert(#repo:Memberships("ring","all")==0)
    end,
    core_clock_and_events_cancel_pending_callbacks=function()
        local kw=setup(); local e=kw.Core.NewEvents(); local n=0
        local h=e:Subscribe("change",function(value) n=n+value end)
        e:Emit("change",3); e:Unsubscribe(h); e:Emit("change",10); assert(n==3)
        local timers={}; local manager={}
        function manager:RegisterForUpdate(name,delay,callback) timers[name]={delay=delay,callback=callback} end
        function manager:UnregisterForUpdate(name) timers[name]=nil end
        local c=kw.Core.NewClock({EVENT_MANAGER=manager,GetFrameTimeMilliseconds=function() return 1500 end})
        local handle=c:Schedule(250,function() n=n+1 end)
        assert(timers[handle].delay==250 and c:NowMs()==1500)
        timers[handle].callback(); assert(n==4 and not timers[handle])
        handle=c:Schedule(500,function() n=n+10 end); c:Cancel(handle); assert(not timers[handle] and n==4)
    end,
    unequip_and_fresh_equip_request_use_current_source=function()
        local kw,api=setup(); local i=kw.Inventory.New(api)
        api.bags[1][3]=item("ring"); i:Capture()
        api.bags[1][19]=api.bags[1][3]; api.bags[1][3]=item("different")
        assert(i:Request({kind="equip",uid="ring",equipSlot=11})); assert(api.requests[1][3]==19)
        api.bags[0][11]=item("ring"); api.free=0
        local ok,err=i:Request({kind="unequip",uid="ring",equipSlot=11}); assert(not ok and err.code=="bagFull")
        api.free=1; assert(i:Request({kind="unequip",uid="ring",equipSlot=11}))
        assert(api.requests[2][1]=="unequip" and api.requests[2][2]==0 and api.requests[2][3]==11)
    end,
}
