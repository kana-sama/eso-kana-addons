local callbacks = {}
local inventoryScene = { callback = nil }

function inventoryScene:RegisterCallback(name, callback)
    assert(name == "StateChange")
    self.callback = callback
end

SCENE_MANAGER = {
    GetScene = function(_, name)
        assert(name == "inventory")
        return inventoryScene
    end,
}

EVENT_ADD_ON_LOADED = "EVENT_ADD_ON_LOADED"
SCENE_SHOWING = "SCENE_SHOWING"
SCENE_SHOWN = "SCENE_SHOWN"
SCENE_HIDING = "SCENE_HIDING"

EVENT_MANAGER = {
    RegisterForEvent = function(_, _, eventName, callback)
        callbacks[eventName] = callback
    end,
    UnregisterForEvent = function() end,
}

function ZO_PostHook(object, method, callback)
    local original = object[method]
    object[method] = function(...)
        original(...)
        callback(...)
    end
end

CEFrame = {
    hidden = false,
    SetHidden = function(self, hidden)
        self.hidden = hidden
    end,
}

CurrentlyEquipped = {
    show_UI = true,
    UpdateUI = function()
        CEFrame:SetHidden(false)
    end,
    HideUICombat = function()
        CEFrame:SetHidden(false)
    end,
    LayerChange = function()
        CEFrame:SetHidden(false)
    end,
    SaveHideInMenu = function()
        CEFrame:SetHidden(false)
    end,
}

dofile("KanaCurrentlyEquipped/KanaCurrentlyEquipped.lua")
callbacks[EVENT_ADD_ON_LOADED](nil, "KanaCurrentlyEquipped")

assert(CEFrame.hidden, "overlay hides the original display before inventory opens")

inventoryScene.callback(nil, SCENE_SHOWING)
assert(not CEFrame.hidden, "overlay shows the original display while inventory is opening")

inventoryScene.callback(nil, SCENE_HIDING)
assert(CEFrame.hidden, "overlay hides the original display when inventory closes")

for _, method in ipairs({ "UpdateUI", "HideUICombat", "LayerChange", "SaveHideInMenu" }) do
    CurrentlyEquipped[method]()
    assert(CEFrame.hidden, method .. " cannot show the display outside inventory")
end

inventoryScene.callback(nil, SCENE_SHOWN)
CurrentlyEquipped.UpdateUI()
assert(not CEFrame.hidden, "the regular set update remains visible inside inventory")
