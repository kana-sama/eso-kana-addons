from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_kana_settings_are_an_independent_old_lam_safe_panel():
    path = ROOT / "PC" / "OverlaySettings.lua"
    assert path.exists(), "missing KanaQuestMap overlay settings"
    source = path.read_text()
    assert 'RegisterAddonPanel(Addon.name .. "_Options"' in source
    assert 'reference = "KanaQuestMapBlacklistInputControl"' in source
    assert 'reference = "KanaQuestMapBlacklistListControl"' in source
    assert "LAM-PanelControlsCreated" in source
    assert "RefreshBlacklistInput(KanaQuestMapBlacklistInputControl)" in source
    assert "RefreshBlacklistRows(KanaQuestMapBlacklistListControl)" in source


def test_blacklist_settings_use_only_kana_blacklist_api():
    source = (ROOT / "PC" / "OverlaySettings.lua").read_text()
    assert "Addon:AddBlacklistedQuest" in source
    assert "Addon:RemoveBlacklistedQuest" in source
    assert "Addon:GetBlacklistedQuestIds" in source
    assert "QuestMap.settings" not in source


if __name__ == "__main__":
    test_kana_settings_are_an_independent_old_lam_safe_panel()
    test_blacklist_settings_use_only_kana_blacklist_api()
    print("PASS: overlay settings")
