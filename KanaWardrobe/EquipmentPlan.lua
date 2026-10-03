local KW = KanaWardrobe
local Slots = KW.Slots
local Planner = {}; KW.EquipmentPlan = Planner

local function problem(code, details) return nil, KW.Problem(code, details) end
local function uid(value) return value and value.kind == "item" and value.uid or nil end
local function validValue(value)
    return type(value) == "table" and (value.kind == "empty" or
        (value.kind == "item" and type(value.uid) == "string" and value.uid ~= "" and value.uid ~= "0"))
end
local function metadata(state, id) return id and state.byUid[id] and state.byUid[id].metadata end
local function isTwoHanded(m) return m and (m.twoHanded or m.equipType == EQUIP_TYPE_TWO_HAND) end
local function sameUnique(a, b)
    return a and b and a.uniqueEquipped and b.uniqueEquipped
        and type(a.itemId) == "number" and a.itemId > 0 and a.itemId == b.itemId
end
local function compatible(m, slot)
    local t = m.equipType
    local armor = {
        [EQUIP_SLOT_HEAD]=EQUIP_TYPE_HEAD, [EQUIP_SLOT_SHOULDERS]=EQUIP_TYPE_SHOULDERS,
        [EQUIP_SLOT_CHEST]=EQUIP_TYPE_CHEST, [EQUIP_SLOT_HAND]=EQUIP_TYPE_HAND,
        [EQUIP_SLOT_WAIST]=EQUIP_TYPE_WAIST, [EQUIP_SLOT_LEGS]=EQUIP_TYPE_LEGS,
        [EQUIP_SLOT_FEET]=EQUIP_TYPE_FEET, [EQUIP_SLOT_NECK]=EQUIP_TYPE_NECK,
        [EQUIP_SLOT_RING1]=EQUIP_TYPE_RING, [EQUIP_SLOT_RING2]=EQUIP_TYPE_RING,
    }
    if armor[slot] then return t == armor[slot] end
    if slot == Slots.Front.main or slot == Slots.Back.main then
        return t == EQUIP_TYPE_ONE_HAND or t == EQUIP_TYPE_TWO_HAND or
            (EQUIP_TYPE_MAIN_HAND ~= nil and t == EQUIP_TYPE_MAIN_HAND)
    end
    return not isTwoHanded(m) and (t == EQUIP_TYPE_ONE_HAND or t == EQUIP_TYPE_OFF_HAND)
end

local function serializeExtras(extras)
    local parts = {}
    -- Length prefixes keep consent keys unambiguous even for unusual UID text.
    -- Bag addresses and display links intentionally do not define consent.
    for _, extra in ipairs(extras) do
        for _, field in ipairs({extra.uid, tostring(extra.fromSlot), tostring(extra.toSlot), extra.reason}) do
            parts[#parts+1] = tostring(#field) .. ":" .. field
        end
    end
    return table.concat(parts, "|")
end

-- Simulate only one-slot requests. No equip request is allowed to implicitly
-- clear another slot: weapon/mythic blockers must already have been removed.
-- Sources in worn always pass through the backpack. A direct replacement
-- needs one spare cell unless fullBagEquipSwap was explicitly verified.
local function simulate(state, target, initialFree, capabilities, makeBatches)
    local worn, bag, wanted, steps = {}, {}, {}, {}
    for _, slot in ipairs(Slots.Order) do worn[slot] = uid(state.worn[slot]); wanted[slot] = uid(target[slot]) end
    for id, location in pairs(state.byUid) do if location.bagId == BAG_BACKPACK then bag[id] = true end end
    local free = initialFree
    local function ready(id, slot, view)
        view = view or worn
        local m = metadata(state, id)
        if m.mythic then
            for _, existing in pairs(view) do
                if existing ~= id and metadata(state, existing).mythic then return false end
            end
        end
        if m.uniqueEquipped then
            for _, existing in pairs(view) do
                if existing ~= id and sameUnique(m, metadata(state, existing)) then return false end
            end
        end
        for _, bar in ipairs({Slots.Front, Slots.Back}) do
            if slot == bar.main and isTwoHanded(m) and view[bar.off] then return false end
            if slot == bar.off and isTwoHanded(metadata(state, view[bar.main])) then return false end
        end
        return true
    end
    local batch, batchId = nil, 0
    local function append(step)
        if makeBatches then
            -- Every request must be valid in the state BEFORE the batch, even
            -- if the server acknowledges its siblings in a different order.
            -- Do not spend space or reuse items released by a pending move.
            local cost = step.kind == "unequip" and 1 or
                (worn[step.equipSlot] and capabilities.fullBagEquipSwap ~= true and 1 or 0)
            -- RequestUnequipItem chooses a free bag cell internally. Until its
            -- acknowledgement, another removal may choose that very same cell.
            local fits = batch and step.kind ~= 'unequip' and not batch.removal
                and not batch.touched[step.equipSlot] and batch.free >= cost
            if fits and step.kind == "equip" then
                fits = batch.bag[step.uid] and ready(step.uid, step.equipSlot, batch.worn)
            end
            if not fits then
                batchId = batchId + 1
                batch = {worn=KW.Copy(worn), bag=KW.Copy(bag), free=free, touched={}}
            end
            step.batchId = batchId; step.spaceCost = cost
            batch.free = batch.free - cost
            batch.touched[step.equipSlot] = true
            batch.bag[step.uid] = nil
            batch.removal = step.kind == 'unequip'
        end
        steps[#steps+1] = step
    end
    for _ = 1, 100 do
        local complete = true
        for _, slot in ipairs(Slots.Order) do if worn[slot] ~= wanted[slot] then complete = false; break end end
        if complete then return steps end
        local moved = false
        -- An equip into an empty slot creates space. Exhaust these before
        -- replacements or removals, so a full backpack can still make progress.
        for _, emptyOnly in ipairs({true, false}) do
            for _, slot in ipairs(Slots.Order) do
                local id, old = wanted[slot], worn[slot]
                local buffer = capabilities.fullBagEquipSwap == true and 0 or 1
                if id and id ~= old and bag[id] and (not emptyOnly or not old)
                    and (not old or free >= buffer) and ready(id, slot) then
                    append({kind="equip", uid=id, equipSlot=slot})
                    bag[id] = nil
                    if old then bag[old] = true else free = free + 1 end
                    worn[slot] = id; moved = true; break
                end
            end
            if moved then break end
        end
        if not moved and free >= 1 then
            -- Prefer an item needed elsewhere: this breaks cycles and avoids
            -- filling the temporary cell with unrelated explicit removals.
            for _, neededOnly in ipairs({true, false}) do
                for _, slot in ipairs(Slots.Order) do
                    local id = worn[slot]
                    local needed = false
                    if id then for _, finalId in pairs(wanted) do if id == finalId then needed = true; break end end end
                    if id and id ~= wanted[slot] and (not neededOnly or needed) then
                        append({kind="unequip", uid=id, equipSlot=slot})
                        worn[slot] = nil; bag[id] = true; free = free - 1; moved = true; break
                    end
                end
                if moved then break end
            end
        end
        if not moved then return nil end
    end
    return nil
end

function Planner.Build(state, intent, mode, capabilities)
    capabilities = capabilities or {}
    if mode ~= "apply" and mode ~= "prepareEdit" and mode ~= "restore" then return problem("invalidMode") end
    if type(state) ~= "table" or type(state.worn) ~= "table" or type(state.byUid) ~= "table"
        or type(state.freeSlots) ~= "number" or state.freeSlots < 0 or state.freeSlots % 1 ~= 0
        or type(intent) ~= "table" then return problem("invalidState") end
    local before, target, normalized, explicitUids = {}, {}, {}, {}
    local sourceSlots = {}
    for _, slot in ipairs(Slots.Order) do
        local value = state.worn[slot]
        if not validValue(value) then return problem("invalidSnapshot", {slot=slot}) end
        before[slot] = KW.Copy(value); target[slot] = KW.Copy(value)
        local id = uid(value)
        if id then
            local location = state.byUid[id]
            if sourceSlots[id] or not location or location.bagId ~= BAG_WORN or location.slotIndex ~= slot
                or not location.metadata or location.metadata.valid == false then return problem("invalidState", {uid=id}) end
            sourceSlots[id] = slot
        end
        if mode == "restore" and intent[slot] == nil then return problem("invalidSnapshot", {slot=slot}) end
    end
    for slot, value in pairs(intent) do
        if not Slots.IsSupported(slot) or not validValue(value) then return problem("invalidIntent", {slot=slot}) end
        local id = uid(value)
        if id then
            if explicitUids[id] then return problem("duplicateUid", {uid=id}) end
            explicitUids[id] = slot
            local location = state.byUid[id]
            if not location or (location.bagId ~= BAG_WORN and location.bagId ~= BAG_BACKPACK) then
                return problem("itemMissing", {uid=id, slot=slot})
            end
            local m = location.metadata
            if not m or m.valid == false then return problem("invalidItem", {uid=id}) end
            -- staticEquipable excludes level/CP/actor restrictions; equipableNow
            -- may be false solely because a blocker is still worn, so ignore it.
            local eligible = m.staticEquipable
            if eligible == nil then eligible = m.availableToEquip end
            -- An unchanged worn instance receives no equip request. Preserve it
            -- even when new equip requests are currently statically forbidden.
            if eligible == false and sourceSlots[id] ~= slot then return problem("notEquipable", {uid=id, slot=slot}) end
            if not compatible(m, slot) then return problem("incompatibleSlot", {uid=id, slot=slot}) end
            if m.bindingRequired and sourceSlots[id] ~= slot then
                return problem("bindingConfirmationRequired", {uid=id, slot=slot})
            end
            target[slot] = {kind="item", uid=id, link=location.link or value.link or ""}
        else target[slot] = {kind="empty"} end
        normalized[slot] = KW.Copy(value)
    end
    local extraBySlot = {}
    local function clearExtra(slot, reason, toSlot)
        local value = target[slot]
        if uid(value) then
            extraBySlot[slot] = {uid=value.uid, link=value.link or "", fromSlot=slot, toSlot=toSlot, reason=reason}
            target[slot] = {kind="empty"}
        end
    end
    for id, toSlot in pairs(explicitUids) do
        local fromSlot = sourceSlots[id]
        if fromSlot and fromSlot ~= toSlot and intent[fromSlot] == nil then clearExtra(fromSlot, "sourceMove", toSlot) end
    end
    for _, bar in ipairs({Slots.Front, Slots.Back}) do
        if isTwoHanded(metadata(state, uid(target[bar.main]))) and uid(target[bar.off]) then
            if intent[bar.main] and intent[bar.off] then return problem("weaponConflict", {main=bar.main, off=bar.off}) end
            if intent[bar.main] then clearExtra(bar.off, "twoHanded")
            elseif intent[bar.off] then clearExtra(bar.main, "twoHanded")
            else return problem("weaponConflict", {main=bar.main, off=bar.off}) end
        end
    end
    local explicitMythic, finalMythics = nil, {}
    for _, slot in ipairs(Slots.Order) do
        local id = uid(target[slot]); local m = metadata(state, id)
        if m and m.mythic then
            finalMythics[#finalMythics+1] = slot
            if intent[slot] then
                if explicitMythic then return problem("mythicConflict", {slots={explicitMythic,slot}}) end
                explicitMythic = slot
            end
        end
    end
    if #finalMythics > 1 then
        if not explicitMythic then return problem("mythicConflict", {slots=finalMythics}) end
        for _, slot in ipairs(finalMythics) do if slot ~= explicitMythic then clearExtra(slot, "mythic") end end
    end
    -- The native unique-equipped flag applies to distinct instances of the
    -- same base item ID. Do not invent broader groups across different IDs.
    local uniqueGroups = {}
    for _, slot in ipairs(Slots.Order) do
        local m = metadata(state, uid(target[slot]))
        if m and m.uniqueEquipped and type(m.itemId) == "number" and m.itemId > 0 then
            local group = uniqueGroups[m.itemId] or {}; uniqueGroups[m.itemId] = group
            group[#group+1] = slot
        end
    end
    for itemId, group in pairs(uniqueGroups) do
        if #group > 1 then
            local explicit
            for _, slot in ipairs(group) do
                if intent[slot] then
                    if explicit then return problem("uniqueEquippedConflict", {itemId=itemId, slots=group}) end
                    explicit = slot
                end
            end
            if not explicit then return problem("uniqueEquippedConflict", {itemId=itemId, slots=group}) end
            for _, slot in ipairs(group) do if slot ~= explicit then clearExtra(slot, "uniqueEquipped") end end
        end
    end
    local finalUids, extras = {}, {}
    for _, slot in ipairs(Slots.Order) do
        local id = uid(target[slot])
        -- Extras may modify ignored slots. Validate availability against the
        -- complete target, after every source/conflict decision has been made.
        local availability = state.slotAvailability and state.slotAvailability[slot]
        if availability and availability.available == false and id ~= uid(before[slot]) then
            return problem(availability.reason or "slotUnavailable", {slot=slot})
        end
        if id then
            local m = metadata(state, id)
            if not m or m.valid ~= true then return problem("invalidItem", {uid=id, slot=slot}) end
            if not compatible(m, slot) then return problem("incompatibleSlot", {uid=id, slot=slot}) end
            if finalUids[id] then return problem("duplicateUid", {uid=id}) end
            finalUids[id] = true
        end
        if extraBySlot[slot] then extras[#extras+1] = extraBySlot[slot] end
    end
    -- At most 14 removals can consume initial free space. Trying capacities
    -- computes the minimum for this deterministic safe scheduling strategy;
    -- it is not a claim about optimal unknown in-client exchange operations.
    local steps, requiredFree
    for free = 0, #Slots.Order + 1 do
        steps = simulate(state, target, free, capabilities)
        if steps then requiredFree = free; break end
    end
    if not steps then return problem("unplannable") end
    if requiredFree > state.freeSlots then
        return problem("insufficientSpace", {requiredFree=requiredFree, freeSlots=state.freeSlots,
            additionalSlots=requiredFree-state.freeSlots})
    end
    -- Minimum required space is a preflight result. Actual free space decides
    -- how many independent moves can be sent before the next acknowledgement.
    steps = simulate(state, target, state.freeSlots, capabilities, true)
    return {intent=normalized, before=before, target=target, steps=steps, extras=extras,
        extraKey=serializeExtras(extras), requiredFree=requiredFree, mode=mode}
end

function Planner.Revalidate(plan, state, capabilities)
    if type(plan) ~= "table" then return problem("invalidPlan") end
    -- The session compares extraKey and reopens consent if it changed. Even if
    -- consent remains valid, always use these freshly built steps and before.
    return Planner.Build(state, plan.intent, plan.mode, capabilities)
end
