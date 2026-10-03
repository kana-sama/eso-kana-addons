from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_started_quest_overrides_special_libquestdata_categories():
    source = (ROOT / "Overlay.lua").read_text()
    assert "if LQD.started_quests[questId] then" in source
    assert "pinType = QuestMap.PIN_TYPE_QUEST_STARTED" in source


if __name__ == "__main__":
    test_started_quest_overrides_special_libquestdata_categories()
    print("PASS: started quest priority")
