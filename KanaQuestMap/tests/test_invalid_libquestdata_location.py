from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_filters_only_the_false_fair_warning_pin_in_davons_watch():
    source = (ROOT / "Overlay.lua").read_text()
    assert '"stonefalls/davonswatch_base_0"' in source
    assert '"stonefalls/stonefalls_base_0"' in source
    assert "[4493] = true" in source
    assert "OriginalGetQuestList" in source
    assert "return filtered" in source


if __name__ == "__main__":
    test_filters_only_the_false_fair_warning_pin_in_davons_watch()
    print("PASS: invalid LibQuestData location filter")
