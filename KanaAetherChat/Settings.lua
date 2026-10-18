KanaAetherChatSettings = {
    defaults = {
        guildChannels = true,
        fragmentShow = true,
        inputLayer = true,
        focusInput = true,
        reliableClose = true,
        closeAfterSlash = true,
        escapeCloses = true,
        scrollPosition = true,
        nativeChatLayout = true,
        lastChannel = true,
    },
}

function KanaAetherChatSettings:GetSaved()
    if not self.saved then
        self.saved = ZO_SavedVars:NewAccountWide("KanaAetherChatSavedVariables", 1, "Patch", self.defaults)
    end
    return self.saved
end

function KanaAetherChatSettings:Get(key)
    return self:GetSaved()[key]
end
