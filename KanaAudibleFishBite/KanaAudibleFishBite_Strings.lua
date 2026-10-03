local localizedStrings = {
  ["ru"] = {
    SOUND_SETTINGS = "Настройки звука",
    SOUND_FILE = "Звук поклёвки",
    SOUND_FILE_INFO = "Этот звук воспроизводится, когда рыба клюёт. По умолчанию — звук бонуса к карманной краже.",
  },
  ["en"] = {
    SOUND_SETTINGS = "Sound Settings",
    SOUND_FILE = "Sound File",
    SOUND_FILE_INFO = "This is the sound that will be played when you have a fish on the line."
  },
}

function KanaAudibleFishBite:GetStrings()
  local lang = GetCVar("language.2")
  return localizedStrings[lang] or localizedStrings["en"]
end
