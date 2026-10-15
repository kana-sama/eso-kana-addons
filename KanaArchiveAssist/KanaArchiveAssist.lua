local K=KanaArchiveAssist
local function OnLoaded(_,name)
 if name~='KanaArchiveAssist' or K.controller then return end
 EVENT_MANAGER:UnregisterForEvent('KanaArchiveAssist',EVENT_ADD_ON_LOADED)
 local saved=ZO_SavedVars:NewAccountWide('KanaArchiveAssistSaved',1,nil,{worlds={}})
 local profiles=K.Profiles.New(saved,GetWorldName(),GetCurrentCharacterId(),zo_strlower)
 K.controller=K.Controller.Install(_G,profiles)
end
EVENT_MANAGER:UnregisterForEvent('KanaArchiveAssist',EVENT_ADD_ON_LOADED)
EVENT_MANAGER:RegisterForEvent('KanaArchiveAssist',EVENT_ADD_ON_LOADED,OnLoaded)
