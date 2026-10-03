local KW = KanaWardrobe
local SetModel = {}
KW.SetModel = SetModel

-- Only passive enchantments with the same text template are additive. Charged
-- weapon effects retain their proc values and duration, even on duplicate weapons.
local function enchantTemplate(effect)
    local description=(effect.description or ""):gsub("|c%x%x%x%x%x%x",""):gsub("|r","")
    if effect.hasCharges then return description,nil end
    description=description:gsub(" "," "):gsub(" "," ")
    local replacements
    repeat description,replacements=description:gsub("([0-9]) ([0-9][0-9][0-9])","%1%2") until replacements==0
    local comma=effect.language=="ru" or effect.language=="fr" or effect.language=="de"
    local values={}
    local template=description:gsub("[0-9][0-9%.,]*",function(raw)
        local suffix=raw:match("[%.,]+$") or ""
        raw=raw:sub(1,#raw-#suffix)
        local number=comma and raw:gsub("%.",""):gsub(",",".") or raw:gsub(",","")
        local value=tonumber(number)
        if not value then return raw..suffix end
        values[#values+1]=value
        return "\1"..suffix
    end)
    if #values==0 then return description,nil end
    return template,values,comma
end
local function totalText(entry,values)
    if not entry.template then return entry.description end
    local i=0
    return (entry.template:gsub("\1",function()
        i=i+1
        local value=string.format("%.6f",values[i]):gsub("0+$",""):gsub("%.$","")
        if entry.decimalComma then value=value:gsub("%.",",")end
        return value
    end))
end

-- This calculation deliberately has no dependency on current worn equipment.
function SetModel.Build(preset, describe)
    local result = {name=preset and preset.name,armor={},enchants={},traits={},sets={}, unavailable={}, complete=true, availableToEquip=true}
    local byFamily,enchants,traits = {},{},{}
    local items={}
    local function group(list,index,effect,frontOnly,backOnly,isTrait)
        if not effect then return end
        local name,description=effect.name or "",effect.description or ""
        local template,values,comma
        if not isTrait then template,values,comma=enchantTemplate(effect) end
        -- Traits describe per-item properties: group the count, not local
        -- multipliers (e.g. Infused) into a fictitious character-wide bonus.
        local key=isTrait and (name~="" and name or tostring(effect.id)) or
            name..":"..tostring(effect.hasCharges==true)..":"..template
        local entry=index[key]
        if not entry then
            entry={name=name,description=description,front=0,back=0,
                hasCharges=effect.hasCharges==true,template=values and template,
                decimalComma=comma,frontValues={},backValues={}}
            index[key]=entry;list[#list+1]=entry
        end
        for _,bar in ipairs({"front","back"})do
            if (bar=="front" and not backOnly) or (bar=="back" and not frontOnly)then
                entry[bar]=entry[bar]+1
                for i,value in ipairs(values or {})do
                    local totals=entry[bar.."Values"];totals[i]=(totals[i] or 0)+value
                end
            end
        end
    end
    for slotIndex, slot in ipairs(KW.Slots.Order) do
        local equipment=preset and (preset.equipment or preset.slots)
        local ref = equipment and equipment[slot]
        if ref and ref.kind == "item" then
            local metadata = describe(ref)
            if not metadata or not metadata.valid then
                result.complete = false
                result.availableToEquip = false
                result.unavailable[#result.unavailable + 1] = {
                    code="setDataUnavailable", slot=slot, uid=ref.uid, link=ref.link,
                }
            else
                local source={slot=slot,uid=ref.uid,link=ref.link,kind="item"}
                items[#items+1]={slot=slot,metadata=metadata,source=source}
                if not metadata.availableToEquip then result.availableToEquip = false end
                local frontOnly = slot == KW.Slots.Front.main or slot == KW.Slots.Front.off
                local backOnly = slot == KW.Slots.Back.main or slot == KW.Slots.Back.off
                -- Shields are weapons here; only the seven body slots count as armor.
                if slotIndex<=7 and metadata.armorType and metadata.armorType>0 then
                    result.armor[metadata.armorType]=(result.armor[metadata.armorType] or 0)+1
                end
                group(result.enchants,enchants,metadata.enchant,frontOnly,backOnly)
                group(result.traits,traits,metadata.trait,frontOnly,backOnly,true)
                if metadata.setId and metadata.setId > 0 then
                    local family = metadata.familyId
                    if not family or family == 0 then family = metadata.setId end
                    local card = byFamily[family]
                    if not card then
                        card = {familyId=family, front=0, back=0, perfectedFront=0,
                            perfectedBack=0, max=metadata.max, bonuses={}, missingUids={}}
                        byFamily[family] = card
                        result.sets[#result.sets + 1] = card
                    end
                    if not card.representativeLink or (metadata.perfected and not card.perfected) then
                        card.representativeLink = ref.link
                        card.representativeSource = source
                        card.setId = metadata.setId
                        card.setName = metadata.setName
                        card.perfected = metadata.perfected == true
                        card.max = metadata.max
                        card.bonuses = KW.Copy(metadata.bonuses or {})
                    end
                    local weight = ((frontOnly or backOnly) and metadata.twoHanded) and 2 or 1
                    if not backOnly then
                        card.front = card.front + weight
                        if metadata.perfected then card.perfectedFront = card.perfectedFront + weight end
                    end
                    if not frontOnly then
                        card.back = card.back + weight
                        if metadata.perfected then card.perfectedBack = card.perfectedBack + weight end
                    end
                    local physicallyAvailable = metadata.physicalAvailable
                    if physicallyAvailable == nil then physicallyAvailable = metadata.availableToEquip end
                    if not physicallyAvailable then
                        card.missingUids[#card.missingUids + 1] = ref.uid
                    end
                end
            end
        end
    end
    for _,entry in ipairs(result.enchants)do
        if entry.front>0 then entry.descriptionFront=totalText(entry,entry.frontValues)end
        if entry.back>0 then entry.descriptionBack=totalText(entry,entry.backValues)end
    end
    for _, card in ipairs(result.sets) do
        for _, bonus in ipairs(card.bonuses) do
            bonus.perfected = bonus.perfected == true
            bonus.activeFront = (bonus.perfected and card.perfectedFront or card.front) >= bonus.required
            bonus.activeBack = (bonus.perfected and card.perfectedBack or card.back) >= bonus.required
        end
    end
    if KW.EffectModel then
        result.effects=KW.EffectModel.Build(items,result.sets)
        -- Keep one bounded sample while the experimental parser is being
        -- validated. Raw API text (including invisible markup) cannot be
        -- reconstructed reliably from a screenshot. No inventory scan or log.
        if KW.runtime and KW.runtime.saved then
            local sample={version=4,items={},sets=KW.Copy(result.sets),effects=KW.Copy(result.effects)}
            for _,item in ipairs(items)do
                local m=item.metadata
                sample.items[#sample.items+1]={slot=item.slot,metadata={
                    armorRating=m.armorRating,enchant=KW.Copy(m.enchant),trait=KW.Copy(m.trait)}}
            end
            KW.runtime.saved.previewSample=sample
        end
    end
    return result
end
