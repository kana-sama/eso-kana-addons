GetCVar = function() return 'ru' end
EVENT_MANAGER = {RegisterForEvent = function() end}
EVENT_ADD_ON_LOADED = 1
dofile('KanaSkillExp/Selection.lua')
dofile('KanaSkillExp/KanaSkillExp.lua')
local addon = KanaSkillExp
assert(type(addon.ApplyDisplay) == 'function', 'manual display must supplement the native display')
TOPLEFT, BOTTOMLEFT = 'TOPLEFT', 'BOTTOMLEFT'
GuiRoot = {}
local function control()
    return {
        SetHidden = function(self, value) self.hidden = value end,
        IsHidden = function(self) return self.hidden end,
        ClearAnchors = function(self) self.anchor = nil end,
        SetAnchor = function(self, ...) self.anchor = {...} end,
        SetMovable = function(self, value) self.movable = value end,
    }
end
SkillExp = {config = {formShown = true, formPos = {x = 10, y = 20}, showBackBar = true,
    showSkillLines = true, trackSkillLineXP = true, hideNonLevelable = true}}
addon.form, addon.originalForm = control(), control()
addon.saved = {entries = {{kind = 'ability', id = 1}}, manualOnly = false}
local nativeToggles = 0
addon.originalToggle = function()
    nativeToggles = nativeToggles + 1
    addon.originalForm:SetHidden(not addon.originalForm:IsHidden())
    SkillExp.config.formShown = not addon.originalForm:IsHidden()
end
addon:ApplyDisplay()
assert(not addon.originalForm.hidden and not addon.form.hidden,
    'default mode must show native and selected skills together')
assert(addon.form.anchor[2] == addon.originalForm and not addon.form.movable,
    'supplement must follow the native window position and height')
addon.saved.manualOnly = true
addon:ApplyDisplay()
assert(addon.originalForm.hidden and not addon.form.hidden and addon.form.movable,
    'manual-only option must allow the fixed selection without destroying native functionality')
assert(addon.form.anchor[2] == GuiRoot, 'manual-only window must be independently anchored')
addon.saved.manualOnly = false
addon:ApplyDisplay()
assert(not addon.originalForm.hidden and nativeToggles == 1,
    'returning to native mode must invoke its toggle to refresh hidden stale data')
assert(SkillExp.config.showBackBar and SkillExp.config.showSkillLines
    and SkillExp.config.trackSkillLineXP and SkillExp.config.hideNonLevelable,
    'switching display modes must preserve all original options')
SkillExp.config.formShown = false
addon:ApplyDisplay()
assert(addon.form.hidden and addon.originalForm.hidden,
    'closing the tracker must hide both renderers')
addon.saved.manualOnly = true
addon:ApplyDisplay()
assert(addon.form.hidden and addon.originalForm.hidden and not SkillExp.config.formShown,
    'switching modes while closed must not reopen the tracker')
SkillExp.config.formShown = true
addon.saved.manualOnly = false
addon.saved.entries = {}
addon:ApplyDisplay()
assert(not addon.originalForm.hidden and addon.form.hidden,
    'an empty manual supplement must not add an empty-state block to the native tracker')
addon.saved.manualOnly = true
addon:ApplyDisplay()
assert(not addon.form.hidden and addon.originalForm.hidden,
    'manual-only mode must retain the empty-state instructions')
print('PASS: additive default, manual-only mode, native refresh, shared visibility and settings preservation')
