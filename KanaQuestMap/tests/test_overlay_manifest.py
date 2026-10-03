from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = (ROOT / "KanaQuestMap.addon").read_text()


def test_manifest_loads_kana_overlay_after_upstream_questmap():
    assert "## DependsOn: QuestMap" in MANIFEST
    assert "Overlay.lua" in MANIFEST
    assert "PC/Overlay.lua" in MANIFEST
    assert "console/Overlay.lua" in MANIFEST
    assert "Init.lua" not in MANIFEST
    assert "PC/Main.lua" not in MANIFEST
    assert "console/Main.lua" not in MANIFEST


def test_overlay_owns_kana_state_without_replacing_questmap():
    source = (ROOT / "Overlay.lua").read_text()
    assert "KanaQuestMap = KanaQuestMap or {}" in source
    assert "QuestMap = {}" not in source
    assert '"KanaQuestMap_SavedVariables"' in source
    assert "_G.QuestMap_SavedVariables" in source
    assert "MigrateForkSettings" in source


if __name__ == "__main__":
    test_manifest_loads_kana_overlay_after_upstream_questmap()
    test_overlay_owns_kana_state_without_replacing_questmap()
    print("PASS: overlay manifest")
