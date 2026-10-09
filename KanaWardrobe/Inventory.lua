local KW = KanaWardrobe
local Inventory = {}; KW.Inventory=Inventory
local Instance={}; Instance.__index=Instance
local function validUid(uid) return type(uid)=="string" and uid~="" and uid~="0" end
function Inventory.New(api, emit)
    return setmetatable({api=api or _G,emit=emit or function() end,version=0,guildBankReady=false},Instance)
end
function Instance:NowMs() return self.api.GetFrameTimeMilliseconds() end
function Instance:SetGuildBankReady(ready) self.guildBankReady=ready end
function Instance:ReadSlot(bag, slot)
    local raw=self.api.GetItemUniqueId(bag,slot)
    if raw==nil then return nil end
    local uid=self.api.Id64ToString(raw)
    if not validUid(uid) then return nil end
    return {bagId=bag,slotIndex=slot,uid=uid,link=self.api.GetItemLink(bag,slot)}
end
function Instance:AvailableBags()
    local api=self.api
    local bags={api.BAG_WORN,api.BAG_BACKPACK}
    if api.IsBankOpen() then
        local bag=api.GetBankingBag()
        if bag~=nil then bags[#bags+1]=bag end
        if bag==api.BAG_BANK then bags[#bags+1]=api.BAG_SUBSCRIBER_BANK end
    end
    if api.IsGuildBankOpen and api.IsGuildBankOpen() and self.guildBankReady then
        bags[#bags+1]=api.BAG_GUILDBANK
    elseif api.IsGuildBankOpen and not api.IsGuildBankOpen() then self.guildBankReady=false end
    return bags
end
function Instance:Metadata(link, location, includeSets)
    local api=self.api
    local valid=type(link)=="string" and link~="" and api.GetItemLinkItemId(link)>0
    local m={valid=valid,physicalAvailable=false,staticEquipable=false,equipableNow=false,
        availableToEquip=false,bindingRequired=false,itemId=0,uniqueEquipped=false,
        equipType=api.EQUIP_TYPE_INVALID,weaponType=api.WEAPONTYPE_NONE,
        setId=0,familyId=0,setName="",perfected=false,mythic=false,twoHanded=false,weight=1,max=0,bonuses={}}
    if not valid then return m end
    m.itemId=api.GetItemLinkItemId(link)
    m.uniqueEquipped=api.IsItemLinkUniqueEquipped(link)==true
    m.equipType=api.GetItemLinkEquipType(link)
    m.weaponType=api.GetItemLinkWeaponType(link)
    -- These restrictions do not depend on the currently worn set. In particular,
    -- an incoming mythic remains plannable while another mythic is still worn.
    m.staticEquipable=m.equipType~=api.EQUIP_TYPE_INVALID
        and api.GetItemLinkActorCategory(link)==api.GAMEPLAY_ACTOR_CATEGORY_PLAYER
        and api.GetItemLinkRequiredLevel(link)<=api.GetUnitLevel("player")
        and api.GetItemLinkRequiredChampionPoints(link)<=api.GetPlayerChampionPointsEarned()
    m.twoHanded=m.equipType==api.EQUIP_TYPE_TWO_HAND
    m.weight=m.twoHanded and 2 or 1
    m.mythic=api.GetItemLinkDisplayQuality(link)==api.ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE
    if includeSets~=false then
        m.armorType=api.GetItemLinkArmorType and api.GetItemLinkArmorType(link) or 0
        -- Same nominal armor value as the native item tooltip; includes local
        -- Reinforced/Nirnhoned. Shields contribute only on their weapon bar.
        m.armorRating=api.GetItemLinkArmorRating and api.GetItemLinkArmorRating(link,false) or 0
        if api.GetItemLinkEnchantInfo then
            local _,name,description=api.GetItemLinkEnchantInfo(link)
            if description and description~="" then
                -- Use the explicit charge API: the EnchantInfo boolean is
                -- documented as hasCharges but native AddEnchant treats it
                -- as hasEnchant, including passive armor/jewelry glyphs.
                local hasCharges=m.weaponType~=api.WEAPONTYPE_NONE
                if api.DoesItemLinkHaveEnchantCharges then hasCharges=api.DoesItemLinkHaveEnchantCharges(link)end
                m.enchant={name=name,description=description,hasCharges=hasCharges==true,
                    language=api.GetCVar and api.GetCVar("language.2") or "en"}
            end
        end
        if api.GetItemLinkTraitInfo then
            local id,description=api.GetItemLinkTraitInfo(link)
            if id and id~=api.ITEM_TRAIT_TYPE_NONE and description~="" then
                m.trait={id=id,name=api.GetString("SI_ITEMTRAITTYPE",id),description=description,
                    language=api.GetCVar and api.GetCVar("language.2") or "en"}
            end
        end
        local hasSet,name,count,_,max,setId=api.GetItemLinkSetInfo(link,false)
        if hasSet then
            m.setId=setId; m.setName=name; m.max=max
            local normal=api.GetItemSetUnperfectedSetId(setId)
            m.perfected=normal~=nil and normal>0
            m.familyId=m.perfected and normal or setId
            for index=1,count do
                local required,description,perfected=api.GetItemLinkSetBonusInfo(link,false,index)
                m.bonuses[#m.bonuses+1]={required=required,description=description,perfected=perfected==true}
            end
        end
    end
    if location then
        m.physicalAvailable=location.bagId==api.BAG_WORN or location.bagId==api.BAG_BACKPACK
        m.equipableNow=api.IsEquipable(location.bagId,location.slotIndex)==true
        m.bindingRequired=api.ZO_InventorySlot_WillItemBecomeBoundOnEquip(location.bagId,location.slotIndex)==true
    end
    m.availableToEquip=m.physicalAvailable and m.staticEquipable
    return m
end
-- false: identity only; "equipment": live equip constraints; nil: full set metadata.
function Instance:Capture(includeMetadata)
    local api=self.api
    local state={worn={},byUid={},slotAvailability={},freeSlots=api.GetNumBagFreeSlots(api.BAG_BACKPACK)}
    local signature={tostring(state.freeSlots)}
    local backupLocked=api.GetUnitLevel("player")<api.GetWeaponSwapUnlockedLevel()
    for _,slot in ipairs(KW.Slots.Order) do
        local locked=backupLocked and (slot==api.EQUIP_SLOT_BACKUP_MAIN or slot==api.EQUIP_SLOT_BACKUP_OFF)
        state.slotAvailability[slot]={available=not locked,reason=locked and "weaponBarLocked" or nil}
    end
    signature[#signature+1]="backupLocked:"..tostring(backupLocked)
    local scanned={}
    for _, bag in ipairs(self:AvailableBags()) do
        if not scanned[bag] then
            scanned[bag]=true
            for slot in api.ZO_IterateBagSlots(bag) do
                local location=self:ReadSlot(bag,slot)
                if location and not state.byUid[location.uid] then
                    if includeMetadata~=false then
                        location.metadata=self:Metadata(location.link,location,includeMetadata~="equipment")
                        location.availableToEquip=location.metadata.availableToEquip
                    end
                    state.byUid[location.uid]=location
                    signature[#signature+1]=tostring(bag)..":"..tostring(slot)..":"..location.uid..":"..location.link
                end
            end
        end
    end
    state.worn=KW.Slots.FromWorn(function(slot) return self:ReadSlot(api.BAG_WORN,slot) end)
    table.sort(signature)
    local key=table.concat(signature,"\n")
    if key~=self.signature then self.signature=key; self.version=self.version+1 end
    state.version=self.version
    return state
end
function Instance:Resolve(uid, equipOnly, includeMetadata)
    if not validUid(uid) then return nil end
    local api=self.api
    for _,bag in ipairs(self:AvailableBags()) do
        if not equipOnly or bag==api.BAG_WORN or bag==api.BAG_BACKPACK then
            for slot in api.ZO_IterateBagSlots(bag) do
                local location=self:ReadSlot(bag,slot)
                if location and location.uid==uid then
                    if includeMetadata~=false then
                        location.metadata=self:Metadata(location.link,location,includeMetadata~="equipment")
                        location.availableToEquip=location.metadata.availableToEquip
                    end
                    return location
                end
            end
        end
    end
end
function Instance:Describe(link, uid)
    local location=validUid(uid) and self:Resolve(uid) or nil
    return self:Metadata(location and location.link or link,location)
end
function Instance:Refresh()
    local state=self:Capture(false)
    self.emit("InventoryChanged",state)
    return state
end
function Instance:Request(step)
    local api=self.api
    if type(step)~="table" or not KW.Slots.IsSupported(step.equipSlot) or not validUid(step.uid) then
        return false,KW.Problem("invalidStep")
    end
    if api.IsUnitInCombat("player") then return false,KW.Problem("inCombat") end
    if api.IsBlockActive() then return false,KW.Problem("blocking") end
    if step.kind=="equip" then
        local location=self:Resolve(step.uid,true,"equipment")
        if not location then return false,KW.Problem("itemMissing",{uid=step.uid}) end
        if not location.availableToEquip then return false,KW.Problem("notEquipable",{uid=step.uid}) end
        -- Automatic execution never bypasses the native bind confirmation. The
        -- player can equip the item manually, accepting the standard dialog.
        if api.ZO_InventorySlot_WillItemBecomeBoundOnEquip(location.bagId,location.slotIndex) then
            return false,KW.Problem("bindingConfirmationRequired",{uid=step.uid})
        end
        local equipable,reason=api.IsEquipable(location.bagId,location.slotIndex)
        if not equipable and not step.orderedAfter then return false,KW.Problem("notEquipable",{uid=step.uid,reason=reason}) end
        api.RequestEquipItem(location.bagId,location.slotIndex,api.BAG_WORN,step.equipSlot)
        return true
    elseif step.kind=="unequip" then
        local current=self:ReadSlot(api.BAG_WORN,step.equipSlot)
        if not current or current.uid~=step.uid then return false,KW.Problem("sourceChanged",{uid=step.uid}) end
        if api.GetNumBagFreeSlots(api.BAG_BACKPACK)<1 then return false,KW.Problem("bagFull") end
        if step.bagSlot~=nil then
            if type(step.bagSlot)~="number" or step.bagSlot<0 or step.bagSlot%1~=0
                or type(api.GetBagSize)~="function" or step.bagSlot>=api.GetBagSize(api.BAG_BACKPACK)
                or self:ReadSlot(api.BAG_BACKPACK,step.bagSlot) then return false,KW.Problem("bagFull") end
            if type(api.CallSecureProtected)=="function" then
                local accepted=api.CallSecureProtected("RequestMoveItem",api.BAG_WORN,step.equipSlot,api.BAG_BACKPACK,step.bagSlot,1)
                if accepted==false then return false,KW.Problem("requestRejected",{uid=step.uid}) end
            else return false,KW.Problem("invalidStep") end
        else api.RequestUnequipItem(api.BAG_WORN,step.equipSlot) end
        return true
    end
    return false,KW.Problem("invalidStep")
end

-- Lock operations accept only the still-accessible, exact instance at this slot.
-- A remembered bank location is not authority after the bank closes.
local function currentLockLocation(self, location)
    if type(location)~="table" or not validUid(location.uid) then return nil end
    -- Validate this physical slot and its accessibility, not every item in every
    -- bag. A stale UID or closed bank must still fail before any lock mutation.
    for _,bag in ipairs(self:AvailableBags()) do
        if bag==location.bagId then
            local current=self:ReadSlot(bag,location.slotIndex)
            if current and current.uid==location.uid then return current end
            return nil
        end
    end
end
function Instance:CanLock(location)
    local current=currentLockLocation(self,location)
    return current~=nil and type(self.api.CanItemBePlayerLocked)=="function"
        and self.api.CanItemBePlayerLocked(current.bagId,current.slotIndex)==true
end
function Instance:IsLocked(location)
    local current=currentLockLocation(self,location)
    return current~=nil and type(self.api.IsItemPlayerLocked)=="function"
        and self.api.IsItemPlayerLocked(current.bagId,current.slotIndex)==true
end
function Instance:SetLocked(location, locked)
    -- Protection never owns the shared flag and therefore never clears it.
    if locked~=true then return false end
    local current=currentLockLocation(self,location)
    if not current or type(self.api.SetItemIsPlayerLocked)~="function" then return false end
    if self:IsLocked(current) then return true end
    if not self:CanLock(current) then return false end
    current=currentLockLocation(self,current)
    if not current then return false end
    self.api.SetItemIsPlayerLocked(current.bagId,current.slotIndex,true)
    local after=self:Resolve(current.uid,false,false)
    return after~=nil and self:IsLocked(after)
end
