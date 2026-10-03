-- LibQuestData 2.79 places Lep Seclusa's Upstart Emperor in Mournhold.
-- Remove only this misplaced pin; coordinates in Lep Seclusa are unknown.
-- OptionalDependsOn ensures the library's data files have already loaded.
local locations = LibQuestData_QuestLocationData
local rows = locations and locations['deshaan/mournhold_base_0']
if rows then
    for i = #rows, 1, -1 do
        if rows[i][5] == 7237 then
            table.remove(rows, i)
        end
    end
end

-- Reciprocal conditional entries describe alternative quest branches.
-- Extend the existing availability filter used by KanaZoneGoals and map addons.
local lib, filters = LibQuestData, LibQuestData_Internal
if lib and filters and type(filters.show_breadcrumb_quest) == 'function' then
    local originalShowBreadcrumbQuest = filters.show_breadcrumb_quest
    function filters:show_breadcrumb_quest(questId)
        local show = originalShowBreadcrumbQuest(self, questId)
        if HasCompletedQuest(questId) or HasQuest(questId) then return show end
        local alternatives = lib.conditional_quest_list or {}
        for _, otherId in pairs(alternatives[questId] or {}) do
            for _, reverseId in pairs(alternatives[otherId] or {}) do
                -- completed_quests includes synthetic completions for alternatives;
                -- only the game's completion state proves a branch was chosen.
                if reverseId == questId and HasCompletedQuest(otherId) then
                    return false
                end
            end
        end
        return show
    end
end
