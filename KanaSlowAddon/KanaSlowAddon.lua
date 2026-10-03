KanaSlowAddonGlobal = {}
-- local reference for performance (especially for the OnUpdate method which is called every frame)
local KanaSlowAddon = KanaSlowAddonGlobal
KanaSlowAddon.oldText = ZO_InteractWindowTargetAreaBodyText.SetText
KanaSlowAddon.oldOption = INTERACTION.PopulateChatterOption
KanaSlowAddon.oldquest = INTERACTION.ShowQuestRewards
KanaSlowAddon.start_time = 0
KanaSlowAddon.options = {}
KanaSlowAddon.quest = -1

function KanaSlowAddon.Cancel()
    EVENT_MANAGER:UnregisterForUpdate("KanaSlowAddon")
    KanaSlowAddon.COMPLETE_TEXT = nil
    KanaSlowAddon.options = {}
    KanaSlowAddon.quest = -1
end

function KanaSlowAddon.Finish()
    local text = KanaSlowAddon.COMPLETE_TEXT
    if not text then return false end
    local options, quest = KanaSlowAddon.options, KanaSlowAddon.quest
    KanaSlowAddon.Cancel()
    KanaSlowAddon.oldText(ZO_InteractWindowTargetAreaBodyText, text)
    if quest >= 0 then KanaSlowAddon.oldquest(INTERACTION, quest) end
    for _, option in ipairs(options) do
        KanaSlowAddon.oldOption(unpack(option, 1, option.n))
    end
    return true
end

local function SpeakerKey()
    local name = GetUnitName("interact")
    if not name or name == "" then return nil end
    return GetCVar("language.2") .. ":" .. name, name
end

function KanaSlowAddon.ToggleSpeaker()
    if ZO_InteractWindow:IsHidden() then
        d("KanaSlowAddon: открой диалог, затем введи /kslow.")
        return
    end
    local key, name = SpeakerKey()
    if not key then
        d("KanaSlowAddon: не удалось определить собеседника.")
        return
    end
    local fast = KanaSlowAddon.preferences.fastSpeakers
    fast[key] = not fast[key] or nil
    if fast[key] then KanaSlowAddon.Finish() end
    d("KanaSlowAddon: " .. name .. (fast[key] and " — мгновенный текст." or " — медленный текст."))
end

function KanaSlowAddon.match_height()
	local str = ZO_InteractWindowTargetAreaBodyText:GetText()
	while KanaSlowAddon.height > ZO_InteractWindowTargetAreaBodyText:GetTextHeight() do
		str = str .. "\n"
		KanaSlowAddon.oldText(ZO_InteractWindowTargetAreaBodyText, str)
	end
end

-- overwrite the set text function,
-- we save the given string and split it into its characters
ZO_InteractWindowTargetAreaBodyText.SetText = function (self, bodyText)
    KanaSlowAddon.Cancel()
    local key = SpeakerKey()
    if not KanaSlowAddon.settings or bodyText == "" or bodyText:sub(1, 1) == "<"
        or (key and KanaSlowAddon.preferences.fastSpeakers[key]) then
        return KanaSlowAddon.oldText(self, bodyText)
    end
	KanaSlowAddon.COMPLETE_TEXT = bodyText
	KanaSlowAddon.COMPLETE_CHARS = {}
	-- split COMPLETE_TEXT into its characters
	-- there are some utf-8 encoded characters and the string library isn't utf-8 save
	-- so i have to write my own split function
	local char
	local i = 1
	local len = zo_strlen(KanaSlowAddon.COMPLETE_TEXT)
	while i <= len do
		-- the first byte tells us how many bytes the character is long
		char = string.byte(KanaSlowAddon.COMPLETE_TEXT, i)
		if char > 240 then
			table.insert(KanaSlowAddon.COMPLETE_CHARS, string.sub(KanaSlowAddon.COMPLETE_TEXT, i, i+3))
			i = i + 4
		elseif char > 225 then
			table.insert(KanaSlowAddon.COMPLETE_CHARS, string.sub(KanaSlowAddon.COMPLETE_TEXT, i, i+2))
			i = i + 3
		elseif char > 192 then
			table.insert(KanaSlowAddon.COMPLETE_CHARS, string.sub(KanaSlowAddon.COMPLETE_TEXT, i, i+1))
			i = i + 2
		else
			table.insert(KanaSlowAddon.COMPLETE_CHARS, string.sub(KanaSlowAddon.COMPLETE_TEXT, i, i))
			i = i + 1
		end
	end
	KanaSlowAddon.text_length = #KanaSlowAddon.COMPLETE_CHARS
	KanaSlowAddon.start_time = GetFrameTimeMilliseconds() + KanaSlowAddon.settings.start_delay
	KanaSlowAddon.quest = -1
	KanaSlowAddon.options = {}
	-- get the height of the finished text
	KanaSlowAddon.oldText(self, bodyText)
	KanaSlowAddon.height = self:GetTextHeight() 
	-- set the dialog field to an empty text
	KanaSlowAddon.oldText(self, " ")
	-- this function will add a bunch of line breaks, so that the empty text's height fits the complete text's height
	KanaSlowAddon.match_height()
	-- we have to fade in text, so add the OnUpdate handler
	EVENT_MANAGER:RegisterForUpdate("KanaSlowAddon", 0, KanaSlowAddon.OnUpdate)

end

local instantDisplayTypes = {
	[CHATTER_START_BANK] = true,
	[CHATTER_START_SHOP] = true,
	[CHATTER_START_STABLE] = true,
	[CHATTER_START_TRADINGHOUSE] = true,
}

-- overwrite the dialog answer options
-- they are added after the text is complete
INTERACTION.PopulateChatterOption = function (...)
    local optionType = select(5, ...)
    if instantDisplayTypes[optionType] then KanaSlowAddon.Finish() end
    if not KanaSlowAddon.COMPLETE_TEXT then
        return KanaSlowAddon.oldOption(...)
    end
    table.insert(KanaSlowAddon.options, {n = select("#", ...), ...})
end

INTERACTION.ShowQuestRewards = function (self, journalQuestIndex)
    if not KanaSlowAddon.COMPLETE_TEXT then
        return KanaSlowAddon.oldquest(self, journalQuestIndex)
    end
    KanaSlowAddon.quest = journalQuestIndex
end

-- called every frame while there is text to be faded in
function KanaSlowAddon.OnUpdate()
	if not KanaSlowAddon.COMPLETE_TEXT then return end
	local time = GetFrameTimeMilliseconds()
	-- calculate how many characters are to be displayed
	local offset = 1.0 * (time - KanaSlowAddon.start_time) / KanaSlowAddon.settings.speed
	local length = zo_floor(offset)
	if length <= 0 then
		return
	end
	-- calculate how many caracters are completely faded in
	local white_length = zo_min(length - KanaSlowAddon.settings.animation_length, KanaSlowAddon.text_length )--zo_max(, 0)
    if white_length >= KanaSlowAddon.text_length then
        KanaSlowAddon.Finish()
        return
    end
	local length = zo_min(length, KanaSlowAddon.text_length)
	-- how many characters are fading in
	local current_animation_length = length - white_length
	local white_text = ""
	-- add the completely faded in characters to the displayed text
	if white_length > 0 then
		white_text = table.concat(KanaSlowAddon.COMPLETE_CHARS, nil, 1, white_length )
	end
	-- list for the displayed text
	local text = {}
	table.insert(text, white_text)
	-- add the characters that are currently fading in
	local maxR, maxG, maxB = ZO_InteractWindowTargetAreaBodyText:GetColor()
	local minR, minG, minB = 0, 0, 0
	if DialogColors then
		minR, minG, minB = ZO_InteractWindowTopBG:GetColor()
	end
	local r, g, b, lambda
	for i = 1,KanaSlowAddon.settings.animation_length do
		if white_length+i > 0 and white_length+i <= length then
			-- value between 0 and 1 depending on how far this character is colored
			lambda = (KanaSlowAddon.settings.animation_length - i) / KanaSlowAddon.settings.animation_length
			-- linearly interpolating the color values
			r = zo_min(255 * (lambda * maxR + (1 - lambda) * minR))
			g = zo_min(255 * (lambda * maxG + (1 - lambda) * minG))
			b = zo_min(255 * (lambda * maxB + (1 - lambda) * minB))
			-- add the color formated character to the buffer
			table.insert(text, string.format("|c%02x%02x%02x%s|r", r, g, b, KanaSlowAddon.COMPLETE_CHARS[white_length+i] ) )
		end
	end
	-- create a text from the white text and the colored characters
	text = table.concat(text)
	-- add the text to the dialog box
	KanaSlowAddon.oldText( ZO_InteractWindowTargetAreaBodyText, text )
	-- match colored text's height to the finished text's height
	KanaSlowAddon.match_height()
end

function KanaSlowAddon.Skip()
    return KanaSlowAddon.Finish()
end
-- clicking on the name of the person you are talking to will skip the dialog animation
ZO_InteractWindowTargetAreaTitle:SetMouseEnabled(true)
ZO_InteractWindowTargetAreaTitle:SetHandler("OnMouseUp", KanaSlowAddon.Skip )

function KanaSlowAddon.OnAddonLoaded( _, addon )
	if addon ~= "KanaSlowAddon" then
		return
	end
	-- some hacks to fix the conflict with Wykkyds Quest Tracker
	if LWF3 then
		LWF3.UI.ShouldBeHidden = function()
			if not ZO_MainMenuCategoryBar:IsHidden() then return true end
			if not ZO_OptionsWindow:IsHidden() then return true end
			if not ZO_SharedTreeUnderlay:IsHidden() then return true end
			-- quest tracker compability
			--if not ZO_ChatterOption1:IsHidden() then return true end
			if not ZO_InteractWindow:IsHidden() then return true end
			
			if not STORE_WINDOW["container"]:IsHidden() then return true end
			--if not STABLE["control"]:IsHidden() then return true end
			if not SMITHING["control"]:IsHidden() then return true end
			if not LOCK_PICK["control"]:IsHidden() then return true end
			if not KEYBIND_STRIP["control"]:IsHidden() then return true end
			return false
		end
	end
	if LWF4 then
		LWF4.UI.ShouldBeHidden = function()
			if not ZO_MainMenuCategoryBar:IsHidden() then return true end
			if not ZO_OptionsWindow:IsHidden() then return true end
			if not ZO_SharedTreeUnderlay:IsHidden() then return true end
			-- quest tracker compability
			--if not ZO_ChatterOption1:IsHidden() then return true end
			if not ZO_InteractWindow:IsHidden() then return true end
			
			if not STORE_WINDOW["container"]:IsHidden() then return true end
			--if not STABLE["control"]:IsHidden() then return true end
			if not SMITHING["control"]:IsHidden() then return true end
			if not LOCK_PICK["control"]:IsHidden() then return true end
			if not KEYBIND_STRIP["control"]:IsHidden() then return true end
			return false
		end
	end
	-- load saved settings
	KanaSlowAddon.settings = ZO_SavedVars:New("KanaSlowAddon_SavedVariables", 2, "settings", {start_delay = 5, speed = 30, animation_length = 20})
    KanaSlowAddon.preferences = ZO_SavedVars:NewAccountWide("KanaSlowAddon_SavedVariables", 1, "preferences", {fastSpeakers = {}})
    SLASH_COMMANDS["/kslow"] = KanaSlowAddon.ToggleSpeaker
    if not KanaSlowAddon.actionHooked then
        ZO_PreHook(INTERACT_WINDOW, "SelectChatterOptionByIndex", function(_, index)
            if index == 1 and not ZO_InteractWindow:IsHidden() then
                return KanaSlowAddon.Finish()
            end
            return false
        end)
        KanaSlowAddon.actionHooked = true
    end
    EVENT_MANAGER:RegisterForEvent("KanaSlowAddon", EVENT_CHATTER_END, KanaSlowAddon.Cancel)
	-- initialize the options menu
	KanaSlowAddonGlobal.InitOptions()
end

EVENT_MANAGER:RegisterForEvent("KanaSlowAddon", EVENT_ADD_ON_LOADED , KanaSlowAddon.OnAddonLoaded)
