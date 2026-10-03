local KW = KanaWardrobe
local Slots = {}
KW.Slots = Slots
Slots.Order = {
    EQUIP_SLOT_HEAD, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_CHEST, EQUIP_SLOT_HAND,
    EQUIP_SLOT_WAIST, EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET, EQUIP_SLOT_NECK,
    EQUIP_SLOT_RING1, EQUIP_SLOT_RING2, EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND,
    EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_BACKUP_OFF,
}
Slots.Front = {main=EQUIP_SLOT_MAIN_HAND, off=EQUIP_SLOT_OFF_HAND}
Slots.Back = {main=EQUIP_SLOT_BACKUP_MAIN, off=EQUIP_SLOT_BACKUP_OFF}
local supported = {}
for _, slot in ipairs(Slots.Order) do supported[slot] = true end
function Slots.IsSupported(slot) return supported[slot] == true end
function Slots.Copy(map) return KW.Copy(map or {}) end
function Slots.Equal(a, b)
    for _, slot in ipairs(Slots.Order) do
        local x, y = a and a[slot], b and b[slot]
        if (x == nil) ~= (y == nil) then return false end
        if x and (x.kind ~= y.kind or (x.kind == "item" and x.uid ~= y.uid)) then return false end
    end
    return true
end
function Slots.FromWorn(readSlot)
    local snapshot = {}
    for _, slot in ipairs(Slots.Order) do
        local value = readSlot(slot)
        if value and value.uid and value.uid ~= "0" and value.uid ~= "" then
            snapshot[slot] = {kind="item", uid=value.uid, link=value.link or ""}
        else snapshot[slot] = {kind="empty"} end
    end
    return snapshot
end
