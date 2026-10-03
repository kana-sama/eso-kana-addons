from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_blacklisted_quest_never_reaches_pin_creation():
    source = (ROOT / "Overlay.lua").read_text()
    guard = source.index("Addon:IsQuestBlacklisted(pinTag.id)")
    pin_creation = source.index("OriginalCreatePin", guard)
    assert guard < pin_creation


if __name__ == "__main__":
    test_blacklisted_quest_never_reaches_pin_creation()
    print("PASS: blacklist pin suppression")
