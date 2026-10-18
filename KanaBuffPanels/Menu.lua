local Addon = KanaBuffPanels
Addon.Menu = {}

function Addon.Menu.Bind(control, rules, onChanged)
    if control.kbpMenuBound then return end
    control.kbpMenuBound = true
    local previous = control:GetHandler("OnMouseUp")
    control:SetHandler("OnMouseUp", function(self, button, upInside, ...)
        if previous then previous(self, button, upInside, ...) end
        if button ~= MOUSE_BUTTON_INDEX_RIGHT or not upInside
            or not self.kbpOwner or not self.kbpOwner.active then return end
        local key = Addon.Rules.EffectKey(self.data)
        if not key then return end
        -- Capture the effect, never the pooled control, in action callbacks.
        local name = zo_strformat(SI_ABILITY_TOOLTIP_NAME, self.data.buffName or key)
        local strings = Addon.Strings
        ClearMenu()
        AddCustomMenuItem(strings.hide, function()
            rules:Hide(key, name)
            onChanged()
        end)
        local entries = {{label = strings.standard, callback = function()
            rules:Assign(key, nil)
            onChanged()
        end}}
        local ids = {}
        for id in pairs(rules.saved.panels) do ids[#ids + 1] = id end
        table.sort(ids, function(a, b)
            return LocaleAwareToLower(rules.saved.panels[a].name) < LocaleAwareToLower(rules.saved.panels[b].name)
        end)
        for _, id in ipairs(ids) do
            entries[#entries + 1] = {label = rules.saved.panels[id].name, callback = function()
                if rules:Assign(key, id) then onChanged() end
            end}
        end
        AddCustomSubMenuItem(strings.move, entries)
        ShowMenu(self)
    end)
end
