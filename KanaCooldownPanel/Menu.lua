local addon = KanaCooldownPanel

local function KeyForControl(control)
    if not control or control.slotType ~= ABILITY_SLOT_TYPE_ACTIONBAR then return end
    local slot = control.slotNum
    if type(slot) ~= 'number' or slot <= ACTION_BAR_FIRST_NORMAL_SLOT_INDEX
        or slot > ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 5 then return end
    return addon:GetSkillKey(slot, control.hotbarCategory)
end

function addon:InstallMenu()
    local ru = GetCVar('language.2') == 'ru'
    local options = {
        {'hidden', ru and 'Не показывать в панели кулдаунов' or 'Hide from cooldown panel'},
        {'uptimeUnimportant', ru and 'Аптайм не важен' or 'Uptime is not important'},
    }
    ZO_PreHook('ShowMenu', function(control)
        local key = KeyForControl(control)
        if not key then return end
        for _, option in ipairs(options) do
            local flag, text = option[1], option[2]
            local index
            index = AddMenuItem(text, function()
                local preferences = addon.skills[key]
                if not preferences then
                    preferences = {}
                    addon.skills[key] = preferences
                end
                preferences[flag] = not preferences[flag]
                UpdateMenuItemState(index, preferences[flag])
                addon:Refresh()
            end, MENU_ADD_OPTION_CHECKBOX)
            UpdateMenuItemState(index, addon.skills[key] and addon.skills[key][flag] == true or false)
        end
    end)
    -- ESO omits its entire menu for restricted (e.g. werewolf) action slots.
    -- Allow preferences there without adding the prohibited remove action.
    ZO_PreHook('ZO_AbilitySlot_OnSlotClicked', function(control, button)
        if button == MOUSE_BUTTON_INDEX_RIGHT and KeyForControl(control)
            and IsActionSlotRestricted(control.slotNum, control.hotbarCategory) then
            ClearMenu()
            ShowMenu(control)
            return true
        end
    end)
end
