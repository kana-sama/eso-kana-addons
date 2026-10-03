from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "PC/OverlaySettings.lua").read_text()


def test_settings_offer_blacklist_input_and_add_action():
    assert 'name = "Чёрный список заданий"' in SOURCE
    assert '"Название или #ID"' in SOURCE
    assert "Addon:AddBlacklistedQuest" in SOURCE
    blacklist_start = SOURCE.index('name = "Чёрный список заданий"')
    blacklist_section = SOURCE[blacklist_start:]
    assert 'type = "editbox"' not in blacklist_section
    assert 'type = "button"' not in blacklist_section


def test_settings_list_supports_removal_without_temporary_visibility():
    assert "Addon:RemoveBlacklistedQuest" in SOURCE
    assert "Addon:SetBlacklistedQuestVisible" not in SOURCE
    assert "ZO_CheckButton_SetToggleFunction" not in SOURCE


def test_blacklist_uses_storage_separate_from_manual_hiding():
    blacklist = (ROOT / "Overlay.lua").read_text()
    assert "blacklistedQuests" in blacklist
    assert "return self.settings.blacklistedQuests[questId] ~= nil" in blacklist


def test_blacklist_settings_do_not_load_questmap_settings_copy():
    manifest = (ROOT / "KanaQuestMap.addon").read_text()
    assert "PC/Settings.lua" not in manifest


def test_each_blacklist_row_and_delete_button_has_a_unique_name():
    assert '"KanaQuestMapBlacklistRow" .. rowIndex' in SOURCE
    assert '"KanaQuestMapBlacklistDelete" .. rowIndex' in SOURCE


def test_list_initializes_when_older_libaddonmenu_skips_create_func():
    assert "local function InitializeBlacklistList(listControl)" in SOURCE
    refresh_start = SOURCE.index("local function RefreshBlacklistRows(listControl)")
    refresh_body = SOURCE.index("InitializeBlacklistList(listControl)", refresh_start)
    assert refresh_body > refresh_start


def test_panel_controls_created_initializes_custom_blacklist_controls():
    assert 'reference = "KanaQuestMapBlacklistInputControl"' in SOURCE
    assert 'reference = "KanaQuestMapBlacklistListControl"' in SOURCE
    assert "RefreshBlacklistInput(KanaQuestMapBlacklistInputControl)" in SOURCE
    assert "RefreshBlacklistRows(KanaQuestMapBlacklistListControl)" in SOURCE


if __name__ == "__main__":
    test_settings_offer_blacklist_input_and_add_action()
    test_settings_list_supports_removal_without_temporary_visibility()
    test_blacklist_uses_storage_separate_from_manual_hiding()
    test_blacklist_settings_do_not_load_questmap_settings_copy()
    test_each_blacklist_row_and_delete_button_has_a_unique_name()
    test_list_initializes_when_older_libaddonmenu_skips_create_func()
    test_panel_controls_created_initializes_custom_blacklist_controls()
    print("PASS: blacklist settings")
