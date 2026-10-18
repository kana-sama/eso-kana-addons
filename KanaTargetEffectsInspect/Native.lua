KanaTargetEffectsInspect = {displayName = '|cFF0000Kana|r Target Effects Inspect'}
local Native = {}
KanaTargetEffectsInspect.Native = Native

function Native.Capture(container)
    if container:GetControl():IsControlHidden() then return nil end
    local snapshot = {icons = {}, style = container.styleObject}
    for _, pool in ipairs({container:GetPools()}) do
        if not pool.container:IsControlHidden() then
            for _, control in pairs(pool.activeObjects) do
                if not control:IsControlHidden() and control.data then
                    local left, top, right, bottom = control:GetScreenRect()
                    if right > left and bottom > top then
                        local data = {}
                        -- Native pools reuse both controls and their associated records.
                        for key, value in pairs(control.data) do
                            local kind = type(value)
                            if kind == 'number' or kind == 'string' or kind == 'boolean' then data[key] = value end
                        end
                        snapshot.icons[#snapshot.icons + 1] = {
                            data = data, left = left, top = top, width = right - left, height = bottom - top,
                            showCooldown = control.showCooldown,
                        }
                    end
                end
            end
        end
    end
    if #snapshot.icons > 0 then return snapshot end
end

function Native.Bind(container, changed, suppress)
    assert(container and type(container.GetPools) == 'function' and type(container.GetControl) == 'function'
        and type(container.Update) == 'function' and type(container.RefreshContainerVisibility) == 'function',
        'native target effect container unavailable')
    local buffs, debuffs = container:GetPools()
    assert(buffs and debuffs and buffs.container and debuffs.container
        and buffs.activeObjects and debuffs.activeObjects, 'native target effect pools unavailable')
    assert(container.styleObject and type(container.styleObject.SetupIcon) == 'function'
        and type(container.styleObject.UpdateDurations) == 'function', 'native effect style unavailable')

    local refresh, update = container.RefreshContainerVisibility, container.Update
    container.RefreshContainerVisibility = function(object, ...)
        refresh(object, ...)
        if suppress() then
            buffs.container:SetHidden(true)
            debuffs.container:SetHidden(true)
        end
    end
    container.Update = function(object, ...)
        update(object, ...)
        -- Native OnUpdate normally refreshes visibility immediately after Update.
        object:RefreshContainerVisibility()
        changed()
    end
end
