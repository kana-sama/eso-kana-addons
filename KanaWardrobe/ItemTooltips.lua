local KW = KanaWardrobe
local ItemTooltips = {}; KW.ItemTooltips = ItemTooltips
local Instance = {}; Instance.__index = Instance
local unpackArgs = unpack or table.unpack

local function pack(...) return {n=select("#", ...), ...} end
local function plain(text)
    -- Repository names reject markup; also protect character names and old data.
    return tostring(text or ""):gsub("|", "")
end

function ItemTooltips.New(repo, inventory)
    return setmetatable({repo=repo, inventory=inventory, api=inventory.api or _G,
        controls={}, refreshing=false}, Instance)
end

function Instance:Forget(tooltip)
    local state = tooltip.kanaWardrobeMembership
    state.generation = state.generation + 1
    state.context = nil
end

function Instance:Layout(tooltip, method, args)
    local bag, slot
    if method == "SetWornItem" then
        slot, bag = args[1], args[2]
        if bag == nil then bag = self.api.BAG_WORN end
    else
        bag, slot = args[1], args[2]
    end
    local state = tooltip.kanaWardrobeMembership
    state.generation = state.generation + 1
    state.context = nil
    if bag == nil or slot == nil then return end
    local location = self.inventory:ReadSlot(bag, slot)
    if not location then return end
    state.context = {generation=state.generation, bagId=bag, slotIndex=slot,
        uid=location.uid, method=method, args=args}

    local names, seen = {}, {}
    for _, member in ipairs(self.repo:Memberships(location.uid, "all")) do
        local key = member.characterId .. ":" .. member.presetId
        if not seen[key] then
            seen[key] = true
            local name = plain(member.name)
            if member.characterId ~= self.repo.characterId then
                name = string.format(KW.Text("TOOLTIP_OTHER_CHARACTER"), name, plain(member.characterName))
            end
            names[#names+1] = name
        end
    end
    if #names == 0 then return end
    -- AddLine uses the native tooltip width and automatic multiline layout.
    -- No truncation, bespoke tooltip, or item-link based identity cache.
    tooltip:AddLine(string.format(KW.Text("TOOLTIP_PRESETS"), table.concat(names, ", ")),
        "ZoFontGame", 0.8, 0.8, 0.8, self.api.LEFT, self.api.MODIFY_TEXT_TYPE_NONE,
        self.api.TEXT_ALIGN_LEFT, true)
end

function Instance:Attach()
    local api = self.api
    if not api.ZO_PostHook or not api.ZO_PostHookHandler then return false end
    for _, name in ipairs({"ItemTooltip", "PopupTooltip", "ComparativeTooltip1", "ComparativeTooltip2"}) do
        local tooltip = api[name]
        if tooltip and not self.controls[tooltip] then
            self.controls[tooltip] = true
            tooltip.kanaWardrobeMembership = {generation=0}
            api.ZO_PostHookHandler(tooltip, "OnCleared", function(control) self:Forget(control) end)
            api.ZO_PostHookHandler(tooltip, "OnHide", function(control) self:Forget(control) end)
            -- inventoryslot.lua: inventory, all banks, sell/repair, equipment,
            -- and enchanting-result rows. Methods without an instance context
            -- (chat/store/trader links etc.) only clear via native OnCleared.
            for _, method in ipairs({"SetBagItem", "SetWornItem", "SetItemUsingEnchantment"}) do
                if type(tooltip[method]) == "function" then
                    -- Native tooltip controls are userdata. SecurePostHook only
                    -- accepts tables; ZO_PostHook supports control methods.
                    -- These hooks format tooltips only, never item actions or
                    -- the inventory methods that invoke protected operations.
                    api.ZO_PostHook(tooltip, method, function(control, ...)
                        self:Layout(control, method, pack(...))
                    end)
                end
            end
        end
    end
    return true
end

function Instance:Invalidate()
    if self.refreshing then return end
    self.refreshing = true
    local ok, problem = pcall(function()
        for tooltip in pairs(self.controls) do
            local state = tooltip.kanaWardrobeMembership
            local context = state.context
            if context and context.generation == state.generation and not tooltip:IsHidden() then
                -- Recheck the physical slot before replay: it may have been
                -- emptied/recycled while a preset change was being emitted.
                local current = self.inventory:ReadSlot(context.bagId, context.slotIndex)
                if not current or current.uid ~= context.uid then self:Forget(tooltip) end
                -- Rebuild the captured native layout through its CURRENT hook
                -- chain, retaining other addons and every original argument.
                -- Clear first, so updates/removal never append over an old block.
                tooltip:ClearLines()
                tooltip[context.method](tooltip, unpackArgs(context.args, 1, context.args.n))
            end
        end
    end)
    self.refreshing = false
    if not ok then error(problem) end
end
