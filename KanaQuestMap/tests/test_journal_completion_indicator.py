from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "PC/Overlay.lua").read_text()


def test_keyboard_journal_uses_the_selected_quest_id():
    assert 'SecurePostHook(journal, "RefreshDetails"' in SOURCE
    assert "GetJournalQuestId(questData.questIndex)" in SOURCE


def test_indicator_uses_libquestdata_completion_and_only_repeatables():
    assert "LibQuestData.completed_quests[questId]" in SOURCE
    assert "GetJournalQuestRepeatType(questData.questIndex)" in SOURCE
    assert "QUEST_REPEAT_NOT_REPEATABLE" in SOURCE


def test_indicator_is_anchored_to_the_native_repeatable_label():
    assert 'GetNamedChild("RepeatableText")' in SOURCE
    assert "icon:SetAnchor(LEFT, repeatableText, RIGHT" in SOURCE


if __name__ == "__main__":
    test_keyboard_journal_uses_the_selected_quest_id()
    test_indicator_uses_libquestdata_completion_and_only_repeatables()
    test_indicator_is_anchored_to_the_native_repeatable_label()
    print("PASS: journal completion indicator")
