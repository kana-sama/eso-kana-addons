KanaCooldownPanel = {}
local addon = KanaCooldownPanel
local OAKENSOUL_RING_ID = 187658

function addon:GetSkillKey(slot, bar)
    if bar == nil or bar == HOTBAR_CATEGORY_COMPANION then return end
    local slotType = GetSlotType(slot, bar)
    if slotType ~= ACTION_TYPE_ABILITY and slotType ~= ACTION_TYPE_CRAFTED_ABILITY then return end
    local id = GetSlotBoundId(slot, bar)
    if not id or id == 0 then return end
    if slotType == ACTION_TYPE_CRAFTED_ABILITY then return 'crafted:' .. id end

    -- Progression identifies the skill across ranks and morphs, independent of its slot.
    local progression = SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(id)
    if progression then
        local progressionId = progression:GetSkillData():GetProgressionId()
        if progressionId and progressionId > 0 then return 'skill:' .. progressionId end
    end
    return 'ability:' .. id
end

function addon:GetBars()
    local active = GetActiveHotbarCategory()
    local oneRow = IsPlayerInWerewolfForm()
        or GetItemId(BAG_WORN, EQUIP_SLOT_RING1) == OAKENSOUL_RING_ID
        or GetItemId(BAG_WORN, EQUIP_SLOT_RING2) == OAKENSOUL_RING_ID
    -- Temporary bars have no corresponding weapon-swap bar.
    if oneRow or (active ~= HOTBAR_CATEGORY_PRIMARY and active ~= HOTBAR_CATEGORY_BACKUP) then
        return {active}
    end
    local inactive = active == HOTBAR_CATEGORY_PRIMARY and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY
    return {inactive, active}
end

function addon:FormatTime(milliseconds)
    local seconds = milliseconds / 1000
    if seconds < 10 then return string.format('%.1f', math.ceil(seconds * 10) / 10) end
    return tostring(math.ceil(seconds))
end

function addon:GetCellState(slot, bar, combat)
    local key = self:GetSkillKey(slot, bar)
    if not key then return 'skip', '' end
    local preferences = self.skills[key]
    if preferences and preferences.hidden then return 'skip', '' end
    local important = not (preferences and preferences.uptimeUnimportant)
    local remaining = GetActionSlotEffectTimeRemaining(slot, bar) or 0
    if remaining > 0 then
        local state = important and remaining < 2000 and 'soon' or 'active'
        return state, self:FormatTime(remaining)
    end
    if important and combat then return 'missing', '!' end
    return 'skip', ''
end
