KanaAudibleFishBite.variableVersion = 1

local defaultSoundVars = {
  SoundFile = SOUNDS.JUSTICE_PICKPOCKET_BONUS,
}

function KanaAudibleFishBite:InitializeSettings()
  KanaAudibleFishBite.soundVars = LibSavedVars
    :NewAccountWide(KanaAudibleFishBite.ADDON_NAME.."_Settings", "Sound_Account", defaultSoundVars)
    :AddCharacterSettingsToggle(KanaAudibleFishBite.ADDON_NAME.."_Settings", "Sound_Character")
    :EnableDefaultsTrimming()
end
