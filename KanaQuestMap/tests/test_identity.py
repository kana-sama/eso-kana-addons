from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_overlay_has_its_own_manifest_and_runtime_name():
    manifest = ROOT / "KanaQuestMap.addon"
    assert manifest.is_file(), "KanaQuestMap.addon must exist"
    assert "## Title: KanaQuestMap" in manifest.read_text()

    overlay = (ROOT / "Overlay.lua").read_text()
    assert 'Addon.name = "KanaQuestMap"' in overlay
    assert 'KanaQuestMap_SavedVariables' in overlay
    assert '## DependsOn: QuestMap' in manifest.read_text()


if __name__ == "__main__":
    test_overlay_has_its_own_manifest_and_runtime_name()
    print("PASS: overlay identity")
