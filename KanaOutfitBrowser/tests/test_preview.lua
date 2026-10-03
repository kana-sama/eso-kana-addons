-- Real client rejected both native wrapper and direct native input handler.
KanaOutfitBrowser = {}
dofile('KanaOutfitBrowser/Preview.lua')
local status, message
local preview = KanaOutfitBrowser.Preview.New(function(s, text) status, message = s, text end)
local function rejected() error('private staging must not be invoked') end
ZO_OutfitManipulator = { UpdatePreviews = rejected }
ZO_OutfitSlotManipulator = { UpdatePreview = rejected }
local button = { handlers = { OnClicked = rejected }, outfitSlotManipulators = {} }
function button:SetHandler(event, handler) self.handlers[event] = handler end
preview:BindControl(button)
assert(button.handlers.OnClicked == nil and button.outfitSlotManipulators == nil)
preview:BindControl(button, 'OnKeyUp')
assert(button.handlers.OnKeyUp == nil)
local ok, reason = preview:Open()
assert(ok == false and status == 'unavailable' and message == reason)
assert(preview:Select({ slots = { [0] = { collectibleId = 1598 } } }) == false)
assert(preview:VerifyAfterInput() == false)
assert(button.handlers.OnClicked == nil and button.handlers.OnKeyUp == nil)
preview:Close()
preview:Close()
print('PASS rejected preview stays unavailable and cannot rearm native input handlers')
