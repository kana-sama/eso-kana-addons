return function()
    local api={}
    for i,d in ipairs(KanaStatSources.Stats.Definitions) do api[d[2]]=i end
    api.STAT_BONUS_OPTION_APPLY_BONUS=1;api.STAT_BONUS_OPTION_DONT_APPLY_BONUS=0
    api.BAG_WORN=0;api.EQUIP_SLOT_ITERATION_BEGIN=0;api.EQUIP_SLOT_ITERATION_END=1
    api.ATTRIBUTE_HEALTH=1;api.ATTRIBUTE_MAGICKA=2;api.ATTRIBUTE_STAMINA=3
    api.HOTBAR_CATEGORY_PRIMARY=0;api.HOTBAR_CATEGORY_BACKUP=1;api.HOTBAR_CATEGORY_CHAMPION=2
    api.GetAPIVersion=function()return 101051 end
    api.GetCVar=function()return 'ru' end
    api.GetCurrentCharacterId=function()return '123' end
    api.GetUnitName=function()return 'Test Player' end
    api.GetUnitLevel=function()return 50 end
    api.GetUnitChampionPoints=function()return 160 end
    api.GetPlayerStat=function(id,bonus)return id*100+bonus end
    api.GetCriticalStrikeChance=function(r)return r/200 end
    api.GetActiveWeaponPairInfo=function()return 1,false end
    api.GetItemLink=function(_,slot)return 'item:'..slot end
    api.GetItemLinkName=function(link)return link end
    api.GetItemLinkItemId=function()return 42 end
    api.GetItemLinkSetInfo=function()return true,'Set',1,2,5,100,0 end
    api.GetItemLinkSetBonusInfo=function()return 2,'Adds 1096 Maximum Magicka',false end
    api.GetItemLinkArmorRating=function()return 100 end
    api.GetItemLinkWeaponPower=function()return 0 end
    api.GetItemLinkTraitInfo=function()return 0,'' end
    api.GetItemLinkEnchantInfo=function()return false,'Enchantment','Adds 100 Maximum Health' end
    api.GetAttributeSpentPoints=function(a)return a==1 and 10 or 0 end
    api.GetAttributeDerivedStatPerPointValue=function()return 120 end
    api.GetSlotBoundId=function(slot,bar)return bar*100+slot end
    api.GetAbilityName=function(id)return 'Ability '..id end
    api.GetAbilityDescription=function(id)return 'Description '..id end
    api.GetNumBuffs=function()return 1 end
    api.GetUnitBuffInfo=function()return 'Buff',0,0,1,1,'icon','',1,1,1,1001,false,false end
    api.GetGameTimeMilliseconds=function()return 1000 end
    api.GetTimeStamp=function()return 100 end
    api.GetNumSkillTypes=function()return 0 end
    api.GetNumChampionDisciplines=function()return 0 end
    api.GetNumAdvancedStatCategories=function()return 0 end
    return api
end
