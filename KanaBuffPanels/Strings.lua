local ru = GetCVar("language.2") == "ru"
local en = {
    orientation = "Orientation", growth = "Growth", timerPosition = "Timer", hide = "Hide", move = "Move to panel", standard = "Default",
    panels = "Panels", panel = "Panel", name = "Name", create = "Create", rename = "Rename", delete = "Delete",
    hidden = "Hidden effects", search = "Search by name or ID", effect = "Effect", show = "Show",
    guide = "Create a panel here, then right-click a character effect to move it or hide it. Position, orientation, growth and timer placement are set in the game's HUD editor. Panels follow the game's Buffs & Debuffs visibility settings.",
    deleteTip = "Effects assigned to this panel return to the default panel. Hidden effects stay hidden.",
    emptyName = "Enter a panel name.", duplicateName = "A panel with this name already exists.", missingPanel = "This panel no longer exists.",
    unavailable = "Integration unavailable; the default effect UI is active. Details: ",
}
local russian = {
    orientation = "Ориентация", growth = "Рост", timerPosition = "Таймер", hide = "Скрыть", move = "Переместить на панель", standard = "Стандартная",
    panels = "Панели", panel = "Панель", name = "Имя", create = "Создать", rename = "Переименовать", delete = "Удалить",
    hidden = "Скрытые эффекты", search = "Поиск по имени или ID", effect = "Эффект", show = "Показать",
    guide = "Создайте панель здесь, затем нажмите ПКМ по эффекту своего персонажа, чтобы перенести или скрыть его. Положение, ориентация, рост и размещение таймера настраиваются в штатном редакторе интерфейса. Панели используют штатные настройки видимости эффектов.",
    deleteTip = "Назначенные этой панели эффекты вернутся на стандартную. Скрытые эффекты останутся скрытыми.",
    emptyName = "Введите имя панели.", duplicateName = "Панель с таким именем уже существует.", missingPanel = "Эта панель больше не существует.",
    unavailable = "Интеграция недоступна; работает штатное отображение эффектов. Причина: ",
}
KanaBuffPanels.Strings = ru and russian or en
KanaBuffPanels.displayName = "|cFF0000Kana|r |cFFFFFFBuff Panels|r"
local enums = {
    SI_KBP_ORIENTATION = ru and {"Строка", "Колонка"} or {"Row", "Column"},
    SI_KBP_HORIZONTAL = ru and {"Вправо", "Влево", "От центра"} or {"Right", "Left", "From center"},
    SI_KBP_VERTICAL = ru and {"Вниз", "Вверх", "От центра"} or {"Down", "Up", "From center"},
    SI_KBP_TIMER_POSITION = ru and {"Снизу", "Слева", "Справа", "Внутри"} or {"Below", "Left", "Right", "Inside"},
}
for prefix, values in pairs(enums) do
    for index, value in ipairs(values) do ZO_CreateStringId(prefix .. index, value) end
end
