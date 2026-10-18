-- Move ESO's existing Duration label; its content and visibility remain native.
local TimerLayout = {}
KanaBuffPanels.TimerLayout = TimerLayout

function TimerLayout.HasDuration(control)
    local data = control.data
    return data and type(data.duration) == "number" and data.duration > 0 and not data.permanent or false
end

function TimerLayout.Restore(control)
    local original = control.kbpDurationLayout
    if not original then return end
    local label = control.duration
    label:ClearAnchors()
    label:SetWidth(original.width)
    label:SetHorizontalAlignment(original.horizontalAlignment)
    for _, anchor in ipairs(original.anchors) do label:SetAnchor(unpack(anchor)) end
    control.kbpDurationLayout = nil
end

function TimerLayout.Apply(control, position, metrics)
    if position == 1 or not TimerLayout.HasDuration(control) then
        TimerLayout.Restore(control)
        return
    end
    local label = control.duration
    if not control.kbpDurationLayout then
        local original = {width = label:GetWidth(), horizontalAlignment = label:GetHorizontalAlignment(), anchors = {}}
        for index = 0, 1 do
            local valid, point, relativeTo, relativePoint, x, y = label:GetAnchor(index)
            if valid then original.anchors[#original.anchors + 1] = {point, relativeTo, relativePoint, x, y} end
        end
        control.kbpDurationLayout = original
    end
    label:ClearAnchors()
    label:SetWidth(metrics.labelWidth)
    if position == 2 then
        label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        label:SetAnchor(RIGHT, control, LEFT, -metrics.gap, 0)
    elseif position == 3 then
        label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        label:SetAnchor(LEFT, control, RIGHT, metrics.gap, 0)
    else
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetAnchor(CENTER, control, CENTER, 0, 0)
    end
end
