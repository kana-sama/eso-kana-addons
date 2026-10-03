from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_all_map_tooltips_replace_the_creator_instead_of_appending_to_shared_tooltips():
    for relative_path in ("PC/Overlay.lua", "console/Overlay.lua"):
        source = (ROOT / relative_path).read_text()
        assert "ZO_MapPin.TOOLTIP_CREATORS[_G[pinType]]" in source, relative_path
        assert "originalCreator(pin)" not in source, relative_path
        assert "QuestMap.idName" in source, relative_path
        assert "Chronology:Format(pinTag.id)" in source, relative_path


def test_keyboard_tooltip_is_rebuilt_as_one_quest_name_and_one_chronology_line():
    source = (ROOT / "PC/Overlay.lua").read_text()
    assert 'SetTooltipText(InformationTooltip, pinTag.pinName .. "\\n" .. chronology)' in source
    assert "SetTooltipText(InformationTooltip, pinTag.pinName)" in source


if __name__ == "__main__":
    test_all_map_tooltips_replace_the_creator_instead_of_appending_to_shared_tooltips()
    test_keyboard_tooltip_is_rebuilt_as_one_quest_name_and_one_chronology_line()
    print("PASS: tooltip integration")
