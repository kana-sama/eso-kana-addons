KanaAudibleFishBiteSettingsMenu = ZO_Object:Subclass()

function KanaAudibleFishBiteSettingsMenu:New()
  local obj = ZO_Object.New(self)
  obj:Initialize()
  return obj
end

function KanaAudibleFishBiteSettingsMenu:Initialize()
  self:CreateOptionsMenu()
end

local str = KanaAudibleFishBite:GetStrings()

function KanaAudibleFishBiteSettingsMenu:CreateOptionsMenu()
  local soundVars = KanaAudibleFishBite.soundVars

  local panel = {
    type            = "panel",
    name            = KanaAudibleFishBite.ADDON_TITLE,
    author          = KanaAudibleFishBite.AUTHOR,
    version         = KanaAudibleFishBite.VERSION,
    website         = KanaAudibleFishBite.WEBSITE,
    donation        = KanaAudibleFishBite.DONATION,
    feedback        = KanaAudibleFishBite.FEEDBACK,
    slashCommand    = nil,
    registerForRefresh = true
  }

  local optionsData = {}

  table.insert(optionsData, {
    type = "header",
    name = str.SOUND_SETTINGS,
  })

  table.insert(optionsData, {
    type = 'soundslider',
    name = str.SOUND_FILE,
    tooltip = str.SOUND_FILE_INFO,
    playSound = true,
    showSoundName = true,
    saveSoundIndex = false,
    getFunc = function()
        return soundVars.SoundFile
    end,
    setFunc = function(value)
        soundVars.SoundFile = value
    end,
    default = soundVars.SoundFile,
  })

  self.settingsMenuPanel = LibAddonMenu2:RegisterAddonPanel(KanaAudibleFishBite.ADDON_NAME.."SettingsMenuPanel", panel)
  LibAddonMenu2:RegisterOptionControls(KanaAudibleFishBite.ADDON_NAME.."SettingsMenuPanel", optionsData)
end
