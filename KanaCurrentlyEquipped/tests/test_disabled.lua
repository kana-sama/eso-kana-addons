local hooks = 0
EVENT_ADD_ON_LOADED = 1
EVENT_MANAGER = {RegisterForEvent = function(_, _, _, callback) _G.loaded = callback end,
    UnregisterForEvent = function() end}
ZO_SavedVars = {NewAccountWide = function(_, name, version, namespace, defaults)
    assert(name == 'KanaCurrentlyEquippedSV' and version == 1 and namespace == nil)
    assert(defaults.inventoryOnly)
    return {inventoryOnly = false}
end}
LibAddonMenu2 = {RegisterAddonPanel = function() end, RegisterOptionControls = function() end}
SCENE_MANAGER = {GetScene = function() error('inventory scene must not be hooked') end}
ZO_PostHook = function() hooks = hooks + 1 end
CEFrame = {hidden = false, SetHidden = function(self, value) self.hidden = value end}
CurrentlyEquipped = {show_UI = true, UpdateUI = function() CEFrame:SetHidden(false) end}

dofile('KanaCurrentlyEquipped/KanaCurrentlyEquipped.lua')
loaded(nil, 'KanaCurrentlyEquipped')
assert(hooks == 0 and not CEFrame.hidden)
KanaCurrentlyEquipped.ApplyVisibility()
assert(not CEFrame.hidden)
CurrentlyEquipped.UpdateUI()
assert(not CEFrame.hidden)
print('PASS: disabled extension leaves CurrentlyEquipped visibility untouched')
