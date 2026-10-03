from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def source(path):
    assert path.exists(), f"missing overlay module: {path}"
    return path.read_text()


def test_overlay_filters_only_questmap_pins_and_reclassifies_known_quests():
    PC = source(ROOT / "PC" / "Overlay.lua")
    CONSOLE = source(ROOT / "console" / "Overlay.lua")
    CORE = source(ROOT / "Overlay.lua")
    assert "QuestPinTypes" in CORE
    assert "OriginalCreatePin" in CORE
    assert "Addon:IsQuestBlacklisted(pinTag.id)" in CORE
    assert "LQD.started_quests[questId]" in CORE
    assert "LQD.completed_quests[questId]" in CORE
    assert "QUEST_REPEAT_NOT_REPEATABLE" in CORE
    for module_source in (PC, CONSOLE):
        assert "Addon:InstallMapHooks()" in module_source
        assert "QuestMap:RefreshPins()" in module_source


def test_overlay_filters_known_bad_libquestdata_location_without_mutating_data():
    CORE = source(ROOT / "Overlay.lua")
    assert '"stonefalls/davonswatch_base_0"' in CORE
    assert '"stonefalls/stonefalls_base_0"' in CORE
    assert "OriginalGetQuestList" in CORE
    assert "4493" in CORE


def test_overlay_preserves_optional_chronology_and_keyboard_journal_indicator():
    PC = source(ROOT / "PC" / "Overlay.lua")
    CORE = source(ROOT / "Overlay.lua")
    assert "Chronology:Format" in PC
    assert "ZO_QUEST_JOURNAL_QUESTS_KEYBOARD" in PC
    assert "SecurePostHook" in PC
    assert "function Addon:IsQuestBlacklisted" in CORE
    assert "function Addon:AddBlacklistedQuest" in CORE
    assert "function Addon:RemoveBlacklistedQuest" in CORE


if __name__ == "__main__":
    test_overlay_filters_only_questmap_pins_and_reclassifies_known_quests()
    test_overlay_filters_known_bad_libquestdata_location_without_mutating_data()
    test_overlay_preserves_optional_chronology_and_keyboard_journal_indicator()
    print("PASS: overlay hooks")
