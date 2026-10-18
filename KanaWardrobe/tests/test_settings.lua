local Fake = dofile(ROOT .. "/tests/support/fake_eso.lua")

return {
 diagnostics_are_available_in_own_settings_and_other_commands_are_removed = function()
  local k = Fake.Load({"Core.lua", "Settings.lua"})
  local panelId, options, messages, reports
  messages, reports = {}, {}
  local api = {
   d = function(message) messages[#messages + 1] = message end,
   GetCVar = function() return "ru" end,
   LibAddonMenu2 = {
    RegisterAddonPanel = function(_, id, panel) panelId = id; assert(panel.name:find("Wardrobe", 1, true)) end,
    RegisterOptionControls = function(_, id, controls) assert(id == panelId); options = controls end,
   },
  }
  local runtime = {api = api, apiVersion = 999999, repo = {character = {performanceReport = "Timing"}}}
  runtime.session = {GetView = function() return {state = "idle"} end}
  k.Dialogs = {Problem = function() return "" end}
  k.BuildCapabilities = {Read = function() return {apiVersion = 999999, skills = true, attributes = true, problems = {}} end}
  k.ProbeReport = {Show = function(value) reports[#reports + 1] = value end}
  k.Settings.Register(runtime)
  assert(panelId == "KanaWardrobeSettings" and #options == 3)
  for _, option in ipairs(options) do assert(option.type == "button"); option.func() end
  assert(messages[1]:find("999999", 1, true) and messages[2]:find("skills=true", 1, true))
  assert(reports[1] == "Timing")
 end,
}
