local Fake = {}
function Fake.Install()
    GetCriticalStrikeChance=function(rating)return rating/219.12 end
    local constants = {
        VERTEX_POINTS_TOPLEFT=1,VERTEX_POINTS_TOPRIGHT=2,VERTEX_POINTS_BOTTOMLEFT=4,VERTEX_POINTS_BOTTOMRIGHT=8,
        EQUIP_SLOT_HEAD=0, EQUIP_SLOT_NECK=1, EQUIP_SLOT_CHEST=2, EQUIP_SLOT_SHOULDERS=3,
        EQUIP_SLOT_MAIN_HAND=4, EQUIP_SLOT_OFF_HAND=5, EQUIP_SLOT_WAIST=6, EQUIP_SLOT_LEGS=8,
        EQUIP_SLOT_FEET=9, EQUIP_SLOT_RING1=11, EQUIP_SLOT_RING2=12, EQUIP_SLOT_HAND=16,
        EQUIP_SLOT_BACKUP_MAIN=20, EQUIP_SLOT_BACKUP_OFF=21,
        BAG_WORN=0, BAG_BACKPACK=1, BAG_BANK=2, BAG_GUILDBANK=3, BAG_SUBSCRIBER_BANK=6,
        EQUIP_TYPE_INVALID=0, EQUIP_TYPE_HEAD=1, EQUIP_TYPE_NECK=2, EQUIP_TYPE_CHEST=3,
        EQUIP_TYPE_SHOULDERS=4, EQUIP_TYPE_ONE_HAND=5, EQUIP_TYPE_TWO_HAND=6,
        EQUIP_TYPE_OFF_HAND=7, EQUIP_TYPE_WAIST=8, EQUIP_TYPE_LEGS=9, EQUIP_TYPE_FEET=10,
        EQUIP_TYPE_RING=12, EQUIP_TYPE_HAND=13, WEAPONTYPE_NONE=0,
        GAMEPLAY_ACTOR_CATEGORY_PLAYER=0, ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE=99,
    }
    for key, value in pairs(constants) do _G[key] = value end
    ZoUTF8StringLength = function(text)
        local _, length = text:gsub("[^\128-\191]", "")
        return length
    end
    zo_strlower = function(text)
        local upper, lower = "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ", "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"
        for i = 1, #upper, 2 do text = text:gsub(upper:sub(i, i+1), lower:sub(i, i+1)) end
        return string.lower(text)
    end
end
-- ESO controls are userdata with Lua-readable/writable fields, not tables.
-- A closed file gives the harness a real userdata without an open resource.
function Fake.Control(fields)
    local control=assert(io.tmpfile())
    control:close()
    debug.setmetatable(control,{__index=fields,__newindex=fields})
    return control
end
function Fake.New()
    local api = { bags = {[0]={}, [1]={}, [2]={}, [3]={}, [6]={}}, descriptions={}, requests={}, now=100, free=10 }
    setmetatable(api, {__index=_G})
    -- Dispatch/registration stub only: Lua cannot reproduce ESO's trust flags.
    -- Tests inspect captured originals to reject manual native-method wrappers.
    api.securePostHooks={}
    function api.SecurePostHook(object,name,callback)
        assert(type(object)=="table","SecurePostHook: table expected, got "..type(object))
        local original=assert(object[name])
        local function pack(...)return {n=select('#',...),...}end
        local wrapper=function(...)
            local result=pack(original(...))
            callback(...)
            return (unpack or table.unpack)(result,1,result.n)
        end
        api.securePostHooks[#api.securePostHooks+1]={object=object,name=name,original=original,wrapper=wrapper}
        object[name]=wrapper
    end
    local function item(bag, slot) return (api.bags[bag] or {})[slot] or {} end
    function api.ZO_IterateBagSlots(bag)
        local slots = {}; for slot in pairs(api.bags[bag] or {}) do slots[#slots+1] = slot end
        table.sort(slots); local i=0
        return function() i=i+1; return slots[i] end
    end
    function api.GetItemUniqueId(bag, slot) return item(bag,slot).uid end
    function api.Id64ToString(uid) return tostring(uid) end
    function api.GetItemLink(bag,slot) return item(bag,slot).link or "" end
    function api.IsBankOpen() return api.bankOpen or false end
    function api.GetBankingBag() return api.bankBag or BAG_BANK end
    function api.GetNumBagFreeSlots() return api.free end
    function api.GetFrameTimeMilliseconds() return api.now end
    function api.IsUnitInCombat() return api.combat or false end
    function api.IsBlockActive() return api.blocking or false end
    function api.IsEquipable(bag,slot) return not item(bag,slot).unusable, "unusable" end
    function api.GetItemActorCategory() return GAMEPLAY_ACTOR_CATEGORY_PLAYER end
    function api.ZO_InventorySlot_WillItemBecomeBoundOnEquip(bag,slot) return item(bag,slot).willBind end
    function api.RequestEquipItem(bag,slot,worn,target) api.requests[#api.requests+1]={"equip",bag,slot,worn,target} end
    function api.RequestUnequipItem(bag,slot) api.requests[#api.requests+1]={"unequip",bag,slot} end
    local function desc(link) return api.descriptions[link] or {} end
    function api.GetItemLinkItemId(link) return link ~= "" and (desc(link).itemId or 123) or 0 end
    function api.IsItemLinkUniqueEquipped(link) return desc(link).uniqueEquipped==true end
    function api.GetItemLinkEquipType(link) return desc(link).equipType or EQUIP_TYPE_RING end
    function api.GetItemLinkWeaponType(link) return desc(link).weaponType or WEAPONTYPE_NONE end
    function api.GetItemLinkActorCategory(link) return desc(link).actorCategory or GAMEPLAY_ACTOR_CATEGORY_PLAYER end
    function api.GetItemLinkRequiredLevel(link) return desc(link).requiredLevel or 0 end
    function api.GetItemLinkRequiredChampionPoints(link) return desc(link).requiredChampionPoints or 0 end
    function api.GetUnitLevel() return api.level or 50 end
    function api.GetWeaponSwapUnlockedLevel() return 15 end
    function api.GetPlayerChampionPointsEarned() return api.championPoints or 160 end
    function api.GetItemLinkDisplayQuality(link) return desc(link).quality or 1 end
    function api.GetItemLinkSetInfo(link)
        local d=desc(link); return d.setId~=nil,d.setName or "",#(d.bonuses or {}),88,d.max or 0,d.setId or 0,77
    end
    function api.GetItemSetUnperfectedSetId(id)
        for _,d in pairs(api.descriptions) do if d.setId==id then return d.familyId or 0 end end
        return 0
    end
    function api.GetItemLinkSetBonusInfo(link, equipped, index)
        local b=desc(link).bonuses[index]; return b.required,b.description,b.perfected or false
    end
    return api
end
function Fake.Load(files)
    Fake.Install()
    KanaWardrobe = nil
    for _, file in ipairs(files or {"Core.lua", "SoftPanel.lua", "Slots.lua", "lang/en.lua", "BuildModel.lua", "Presets.lua", "Inventory.lua"}) do
        if file=="Presets.lua" and not KanaWardrobe.BuildModel then dofile(ROOT .. "/BuildModel.lua") end
        local path=ROOT .. "/" .. file
        local f=io.open(path,"r")
        if f then f:close(); dofile(path) end
    end
    return KanaWardrobe or {}
end
return Fake
