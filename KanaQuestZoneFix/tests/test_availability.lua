-- Run from eso-kana-addons: lua KanaQuestZoneFix/tests/test_availability.lua
LibQuestData = {completed_quests = {}, quest_series_type = {quest_type_guild_fighter=1, quest_type_guild_mage=2, quest_type_guild_thief=3, quest_type_guild_dark=4}}
LibQuestData_Internal = {}
dofile('LibQuestData/data/LibQuestData_QuestTables.lua')
dofile('LibQuestData/LibQuestData_Filters.lua')
local completed, active = {}, {}
function HasCompletedQuest(id) return completed[id] == true end
function HasQuest(id) return active[id] == true end
local filters = LibQuestData_Internal
local original = filters.show_breadcrumb_quest
local function patch() dofile('KanaQuestZoneFix/LibQuestDataPatch.lua') end
patch()
assert(filters:show_breadcrumb_quest(3595))
assert(filters:show_breadcrumb_quest(3598))
completed[3598] = true
assert(not filters:show_breadcrumb_quest(3595), '3595 remains available after completing alternative 3598')
assert(filters:show_breadcrumb_quest(3598), 'completed quest must remain accessible')
completed = {[3595] = true}
assert(not filters:show_breadcrumb_quest(3598), 'reverse branch remains available')
assert(filters:show_breadcrumb_quest(3595))
-- LQD marks alternatives synthetically completed: never use that as proof.
completed = {}
LibQuestData.completed_quests[3598] = true
assert(filters:show_breadcrumb_quest(3595), 'synthetic completion blocks quest')
completed[3598] = true
active[3595] = true
assert(filters:show_breadcrumb_quest(3595), 'active quest must remain accessible')
active = {}
patch()
assert(not filters:show_breadcrumb_quest(3595))
completed = {}
-- Existing breadcrumb rules remain effective.
LibQuestData.completed_quests[4028] = true
assert(filters:show_breadcrumb_quest(4026) == original(filters, 4026))
assert(filters:show_breadcrumb_quest(999999) == original(filters, 999999))
-- A one-way implication is not proof of a mutually exclusive choice.
LibQuestData.conditional_quest_list[999991] = {999992}
completed[999992] = true
assert(filters:show_breadcrumb_quest(999991))
-- New reciprocal pairs in the maintained library are picked up automatically.
LibQuestData.conditional_quest_list[999992] = {999991}
assert(not filters:show_breadcrumb_quest(999991))
LibQuestData.conditional_quest_list = nil
assert(filters:show_breadcrumb_quest(3595) == original(filters, 3595))
LibQuestData, LibQuestData_Internal = nil, nil
patch()
print('PASS: alternative branches, real versus synthetic completion, active quests, original filters, absent data/library')
