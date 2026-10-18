-- Breaks caught: filtering the wrong tier, keeping a stale registered callback,
-- swallowing awards, ignoring the live toggle, or enabling disabled tracking.
local listeners, calls = {}, {}
EVENT_ADD_ON_LOADED, EVENT_ACHIEVEMENT_UPDATED, EVENT_ACHIEVEMENT_AWARDED = 1, 2, 3
EVENT_MANAGER = {}
function EVENT_MANAGER:RegisterForEvent(name, event, handler)
    listeners[name] = listeners[name] or {}
    -- ESO refuses duplicate namespace/event registrations; it does not replace.
    if listeners[name][event] then return false end
    listeners[name][event] = handler
    return true
end
function EVENT_MANAGER:UnregisterForEvent(name, event)
    if listeners[name] then listeners[name][event] = nil end
end
local function fire(name, event, ...)
    local callback = listeners[name] and listeners[name][event]
    if callback then return callback(event, ...) end
end
local nextId = {[10]=50, [50]=100}
function GetNextAchievementInLine(id) return nextId[id] or 0 end
local saved, controls = {}, nil
ZO_SavedVars = {}
function ZO_SavedVars:NewAccountWide(name, version, namespace, defaults)
    assert(name == "KanaReminderzOptions" and version == 1,
        "existing saved-variable file and version must be retained")
    for key, value in pairs(defaults) do
        if saved[key] == nil then saved[key] = value end
    end
    return saved
end
LibAddonMenu2 = {}
function LibAddonMenu2:RegisterAddonPanel(_, panel)
    assert(panel.name:find("Reminderz", 1, true)
        and panel.displayName:find("progress filter", 1, true))
end
function LibAddonMenu2:RegisterOptionControls(_, options) controls = options end
function d(message) error('Unexpected diagnostic: '..message) end
Reminderz = {name="Reminderz", settings={trackAchievements=true}}
local function original(event, id, extra)
    calls[#calls+1] = {event=event, id=id, extra=extra}
    return 'original-return'
end
local awards = 0
function Reminderz.EVENT_ACHIEVEMENT_AWARDED() awards=awards+1 end
Reminderz.EVENT_ACHIEVEMENT_UPDATED = original
EVENT_MANAGER:RegisterForEvent('Reminderz', EVENT_ACHIEVEMENT_UPDATED, original)
EVENT_MANAGER:RegisterForEvent('Reminderz', EVENT_ACHIEVEMENT_AWARDED, Reminderz.EVENT_ACHIEVEMENT_AWARDED)
local file = io.open('KanaReminderz.lua', 'r')
if file then file:close(); dofile('KanaReminderz.lua') end
assert(listeners.KanaReminderz, 'KanaReminderz extension is not implemented')
fire('KanaReminderz', EVENT_ADD_ON_LOADED, 'OtherAddon')
assert(Reminderz.EVENT_ACHIEVEMENT_UPDATED == original)
fire('KanaReminderz', EVENT_ADD_ON_LOADED, 'KanaReminderz')
local toggle = controls and controls[1]
assert(toggle and toggle.type == 'checkbox', 'Expected the modification toggle')
assert(toggle.getFunc() == true, 'The requested modification should start enabled')
fire('Reminderz', EVENT_ACHIEVEMENT_UPDATED, 10)
fire('Reminderz', EVENT_ACHIEVEMENT_UPDATED, 50)
assert(fire('Reminderz', EVENT_ACHIEVEMENT_UPDATED, 100, 'payload') == 'original-return')
assert(#calls == 1 and calls[1].id == 100 and calls[1].extra == 'payload',
    'Only the highest tier should print, even before lower tiers are complete')
assert(Reminderz.EVENT_ACHIEVEMENT_AWARDED ~= nil)
fire('Reminderz', EVENT_ACHIEVEMENT_AWARDED, 'A', 1, 10, 'link')
assert(awards == 1, 'Achievement awards must remain enabled')
fire('Reminderz', EVENT_ACHIEVEMENT_UPDATED, 777)
assert(#calls == 2 and calls[2].id == 777, 'Unrelated achievements must pass through')
toggle.setFunc(false)
calls = {}
for _, id in ipairs({10,50,100}) do fire('Reminderz', EVENT_ACHIEVEMENT_UPDATED, id) end
assert(#calls == 3, 'Switching off must restore all original updates immediately')
toggle.setFunc(true)
EVENT_MANAGER:UnregisterForEvent('Reminderz', EVENT_ACHIEVEMENT_UPDATED)
EVENT_MANAGER:RegisterForEvent('Reminderz', EVENT_ACHIEVEMENT_UPDATED, Reminderz.EVENT_ACHIEVEMENT_UPDATED)
calls = {}
fire('Reminderz', EVENT_ACHIEVEMENT_UPDATED, 50)
fire('Reminderz', EVENT_ACHIEVEMENT_UPDATED, 100)
assert(#calls == 1 and calls[1].id == 100, 'Reminderz tracking toggle must retain the filter')
-- A fresh initialization while Reminderz tracking is disabled must not register it.
listeners, calls, controls = {}, {}, nil
Reminderz.EVENT_ACHIEVEMENT_UPDATED = original
Reminderz.settings.trackAchievements = false
saved.onlyHighestTier = true
saved.onlyCurrentTier = false -- old option must migrate without losing an explicit false
KanaReminderz = nil
dofile('KanaReminderz.lua')
fire('KanaReminderz', EVENT_ADD_ON_LOADED, 'KanaReminderz')
assert(not (listeners.Reminderz and listeners.Reminderz[EVENT_ACHIEVEMENT_UPDATED]))
assert(controls[1].getFunc() == false, 'Saved toggle state must survive initialization')
print('PASS chain tiers, independent achievements, awards, live toggle, callback registration and disabled tracking')
