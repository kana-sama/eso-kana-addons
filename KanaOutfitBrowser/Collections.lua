-- Extend the existing keyboard Collections group; its native menu owns tab clicks.
KanaOutfitBrowser = KanaOutfitBrowser or {}
local Collections = {}
KanaOutfitBrowser.Collections = Collections

local GROUP_NAME = "collectionsSceneGroup"
local SCENE_NAME = "kanaOutfitBrowser"
ZO_CreateStringId("SI_KANA_OUTFIT_BROWSER_COLLECTIONS_TAB", "Сеты нарядов")

function Collections.Register(scene)
    local menu = MAIN_MENU_KEYBOARD
    local info = menu and menu.sceneGroupInfo and menu.sceneGroupInfo[GROUP_NAME]
    local group = SCENE_MANAGER and SCENE_MANAGER:GetSceneGroup(GROUP_NAME)
    if not scene or not info or not group or not info.menuBarIconData
        or not info.sceneGroupBarFragment or not menu.categoryInfo[info.category] then
        return false, "Не удалось подключить вкладку к меню коллекций."
    end

    local icons = info.menuBarIconData
    local insertionIndex = #icons + 1
    for index, icon in ipairs(icons) do
        if icon.descriptor == SCENE_NAME then
            return true
        end
        if icon.descriptor == "outfitStylesBook" then
            insertionIndex = index + 1
        end
    end

    -- AddRawScene is the same native path used by MainMenu_Keyboard:AddSceneGroup.
    -- Reusing the existing bar fragment preserves every other Collections tab.
    if not group:HasScene(SCENE_NAME) then
        group:AddScene(SCENE_NAME)
    end
    menu:AddRawScene(SCENE_NAME, info.category, menu.categoryInfo[info.category], GROUP_NAME)
    scene:AddFragment(info.sceneGroupBarFragment)
    scene:AddFragment(TITLE_FRAGMENT)
    scene:AddFragment(COLLECTIONS_TITLE_FRAGMENT)
    table.insert(icons, insertionIndex, {
        categoryName = SI_KANA_OUTFIT_BROWSER_COLLECTIONS_TAB,
        descriptor = SCENE_NAME,
        normal = "EsoUI/Art/Inventory/inventory_tabIcon_armor_up.dds",
        pressed = "EsoUI/Art/Inventory/inventory_tabIcon_armor_down.dds",
        highlight = "EsoUI/Art/Inventory/inventory_tabIcon_armor_over.dds",
    })

    -- Usually registered at addon load, but support registration while visible too.
    if menu.sceneShowGroupName == GROUP_NAME and menu:IsShowing() then
        menu:SetupSceneGroupBar(info.category, GROUP_NAME)
    end
    return true
end
