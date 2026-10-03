KanaOutfitBrowser = KanaOutfitBrowser or {}
local KOB = KanaOutfitBrowser
KOB.Preview = {}
local Preview = {}
Preview.__index = Preview

-- Both addon-call and direct-native-input experiments were rejected by the
-- real ESO client. Do not reinstall those handlers or retry private staging.
local REASON = "ESO отклонила оба способа примерки полного сета.\nПоказан текущий облик персонажа, а не выбранный сет."

function KOB.Preview.New(onStatus)
    return setmetatable({ onStatus = onStatus }, Preview)
end

function Preview:BindControl(control, eventName)
    control:SetHandler(eventName or "OnClicked", nil)
    control.outfitSlotManipulators = nil
end

function Preview:Open()
    if self.onStatus then self.onStatus("unavailable", REASON) end
    return false, REASON
end

function Preview:Select() return false end
function Preview:VerifyAfterInput() return false end
function Preview:Close() end
