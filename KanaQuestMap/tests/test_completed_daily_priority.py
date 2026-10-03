from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_completed_daily_overrides_daily_flag_but_not_active_quest_flag():
    source = (ROOT / "Overlay.lua").read_text()
    started = "if LQD.started_quests[questId] then"
    completion = "elseif LQD.completed_quests[questId] and LQD:get_quest_repeat(questId) > QUEST_REPEAT_NOT_REPEATABLE then"
    assert started in source
    assert completion in source
    assert source.index(started) < source.index(completion)


if __name__ == "__main__":
    test_completed_daily_overrides_daily_flag_but_not_active_quest_flag()
    print("PASS: completed daily priority")
