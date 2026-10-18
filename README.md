Советую ставить аддоны через [ESO Addon Manager](https://github.com/arviceblot/eso-addons). Он сам качает данные для TTC и HM, качает зависимости аддонов, позволяет их обновлять.

Свои аддоны из этого репозитория размещайте в `AddOns/eso-kana-addons/`:
пути к их ресурсам учитывают эту папку. Команды вида `lua Kana…/tests/…`
запускайте из корня `eso-kana-addons`; тесты с отдельными инструкциями
запускайте из указанной в них папки.

# Внешние аддоны

## AetherChat <sup>[esoui](https://www.esoui.com/downloads/info4798-AetherChat.html)</sup>
Чат аля мессенджер.

### Kana AetherChat Patch
Исправляет управление и отображение AetherChat; подробности — в [README надстройки](KanaAetherChat/README.md).

## BountyTimeDisplay <sup>[esoui](https://www.esoui.com/downloads/info2857-BountyTimeDisplay.html)</sup>
Считает и показывает через какое время награда за голову будет полностью снята.

## Calamath's BookFont Stylist <sup>[esoui](https://www.esoui.com/downloads/info2505-CalamathsBookFontStylist.html)</sup>
Позволяет менять шрифт в книгах/свитках.

## Character Knowledge <sup>[esoui](https://www.esoui.com/downloads/info2938-CharacterKnowledgeMotifRecipeandFurnishingPlanTracker.html)</sup>
Рисует табличку со всеми исследованиями. Так же чеклист всех рецептов.

## Code's Combat Alerts <sup>[esoui](https://www.esoui.com/downloads/info1855-CodesCombatAlerts.html)</sup>
Таймеры на кик/додж/босс под важные атаки боссов.

## Combat Metrics <sup>[esoui](https://www.esoui.com/downloads/info1360-CombatMetrics.html)</sup>
Анализ/логи боев, дпс-метр.

### [Kana CombatMetrics: bookmarks](KanaCombatBookmarks/README.md)
Добавляет закладки в подробный боевой лог CombatMetrics.

## Combat Metronome <sup>[esoui](https://www.esoui.com/downloads/info2373-CombatMetronomeGCDTracker.html)</sup>
Рисует GCD шкалу с учетом пинга.

### [Kana CombatMetronome: radial cooldown](KanaCooldownMetronome/README.md)
Показывает откат CombatMetronome кольцом вокруг прицела, включая зону пинга.

## CrutchAlerts <sup>[esoui](https://www.esoui.com/downloads/info3137-CrutchAlerts.html)</sup>
Еще таймеры разных атак боссов.

## Calamath's Shortcut Pie Menu <sup>[esoui](https://www.esoui.com/downloads/info3088-CShortcutPieMenu.html)</sup>
Добавляет кастомные круговые панели для кастомных команд (телепорт к дому, открыть книгу, перезагрузить интерфейс, вызвать какую-то команду из аддона).

## Currently Equipped <sup>[esoui](https://www.esoui.com/downloads/info3524-CurrentlyEquipped--EquippedSetDisplay.html)</sup>
Позволяет рисовать панель

### [Kana CurrentlyEquipped: visibility fix](KanaCurrentlyEquipped/README.md)
Показывает панель CurrentlyEquipped только при открытом инвентаре.

## Dolgubon's Lazy Set Crafter <sup>[esoui](https://www.esoui.com/downloads/info1697-DolgubonsLazySetCrafter.html)</sup>
Создание снаряжения по очереди.

### [Kana Lazy Set Crafter: auto hide](KanaLazySetCrafterAutoHide/README.md)
При входе на станок открывает окно только с непустой очередью. Кнопка снизу позволяет вручную показать или скрыть его в любой момент.

## Dolgubon's Lazy Writ Crafter <sup>[esoui](https://www.esoui.com/downloads/info1346-DolgubonsLazyWritCrafter.html)</sup>
Автоматически берет, делает и сдает ремесленные дейлики.

## Dustman <sup>[esoui](https://www.esoui.com/downloads/info97-Dustman.html)</sup>
Запоминает какие предметы ты пометил как хлам и отмечает автоматически. Позволяет продавать весь хлам.

## NameLanguageNinja <sup>[esoui](https://www.esoui.com/downloads/info2667-NameLanguageNinja-Translationassistant.html)</sup>
Показывает английские названия для навыков и шмоток.

## Harven's Improved Skills Window <sup>[esoui](https://www.esoui.com/downloads/info489-HarvensImprovedSkillsWindow.html)</sup>
Позволяет видеть все морфы на панели навыков.

### [Kana Harven's Improved Skills Window: translations](KanaSkillTranslations/README.md)
Показывает переводы названий и описаний навыков в подсказках сравнения морфов.

## HarvestMap <sup>[esoui](https://www.esoui.com/downloads/info57-HarvestMap.html)</sup>
Метки известных точек спавна ресурсов на карте и в мире. Так же стоит поставить [HarvestMap-Data](https://www.esoui.com/downloads/info3034-HarvestMap-Data.html) в котором уже база данных меток. ESO Addon Manager умеет эти данные обновлять.

## HarvestRoute <sup>[esoui](https://www.esoui.com/downloads/info57-HarvestMap.html)</sup>
Позволяет строить маршруты сбора ресов.

## Quest Map <sup>[esoui](https://www.esoui.com/downloads/info1022-QuestMap.html)</sup>
Показывает метки квестов на карте.

### [Kana QuestMap: quest details](KanaQuestMap/README.md)
Добавляет сведения о заданиях и исправления карты QuestMap.

## Reminderz <sup>[esoui](https://www.esoui.com/downloads/info3248-Reminderz-Onscreenremindersforfood....html)</sup>
Кричит что забыл поесть, показывает в чатике прогресс достижений.

### [Kana Reminderz: progress filter](KanaReminderz/README.md)
Показывает прогресс только последней ступени серии достижений.

## SkillExp <sup>[esoui](https://www.esoui.com/downloads/info4445-SkillExp.html)</sup>
Трекер прокачки навыков.

### [Kana SkillExp: manual tracker](KanaSkillExp/README.md)
Позволяет выбирать навыки для отслеживания через контекстное меню.

## Rare Fish Tracker <sup>[esoui](https://www.esoui.com/downloads/info665-RareFishTracker.html)</sup>
Показывает каких рыбов осталось словить в локации на ачивку. KanaZoneGoals использует данные отсюда.

## Research Assistant <sup>[esoui](https://www.esoui.com/downloads/info111-ResearchAssistant.html)</sup>
Показывает метки на шмотках об исследовании, позволяет не хранить дубли.

## Show Global Cooldown <sup>[esoui](https://www.esoui.com/downloads/info1625-ShowGlobalCooldown.html)</sup>
Рисует анимацию ГКД на панели.

## Tamriel Trade Centre <sup>[esoui](https://www.esoui.com/downloads/info1245-TamrielTradeCentre.html)</sup>
Показывает аукционные цены.

### [Kana Tamriel Trade Centre: price summary](KanaTTC/README.md)
Показывает компактную таблицу цен и продаж в подсказке предмета.

## The Questing Guide
Показывает список сюжетных квестов по дополнениям. Используется как зависимость в ряде аддонов.

## Map Pins <sup>[esoui](https://www.esoui.com/downloads/info1881-MapPins.html)</sup>
Добавляет на карту метки с книгами, шардами, ивентами, неоткрытыми локациями.

# Мои аддоны или форки

## Kana Archive Helper: achievement hints
Помечает строфы и видения, которые продвигают незавершённые достижения Бесконечного архива.

## Kana Archive Assist
Помечает строфы и видения в Бесконечном архиве на основе ваших прошлых выборов.

## Kana Back Bar Reminder
Подсвечивает края экрана и прицел, когда активна запасная панель оружия.

## Kana Fishing Bite Alert
Предупреждает о поклёвке на рыбалке звуком и надписью.

## [Kana HUD: Arcanist](KanaArcanistHUD/README.md)
Показывает вокруг прицела накопленные Знаки арканиста.

## [Kana HUD: Dragonknight](KanaDragonknightHUD/README.md)
Показывает у прицела «Кипящую ярость» и стаки «Теплового шока» на цели.

## [Kana HUD: Werewolf](KanaAuras/README.md)
Показывает в форме вервольфа голод, ярость и запас формы.

## Kana Blade of Woe: no protection
Позволяет убивать Клинком Горя даже если включена защита от убийства мирных жителей.

## Kana Buff Panels
Разносит штатные эффекты персонажа по отдельным панелям и скрывает ненужные, сохраняя привычные иконки и таймеры ESO.

## [Kana World Map Colors](KanaColorMap/README.md)
Раскрашивает области на общей карте Тамриэля и подчёркивает их границы.

## [Kana Cooldown Panel](KanaCooldownPanel/README.md)
Показывает таймеры навыков обеих панелей оружия и предупреждает о пропущенных важных эффектах.

## [Kana Craftable Set Collection](KanaCraftedSetCollections/README.md)
Добавляет крафтовые сеты в коллекцию наборов ESO для поиска и просмотра бонусов.

## [Kana Outfit Sets](KanaOutfitBrowser/README.md)
Добавляет в коллекцию стилей нарядов список сетов, которые можно скрывать и отмечать любимыми.

## [Kana Effects](KanaEffects/README.md)
Позволяет собрать собственные панели эффектов для боя.

## [Kana Enemy Markers](KanaEnemyMark/README.md)
Помечает красными стрелками врагов, с которыми вы сражаетесь.

## [Kana Treasure Launder Guard](KanaLaunderGuard/README.md)
Запрашивает подтверждение перед отмыванием краденых сокровищ.

## [Kana Litany of Blood](KanaLitanyOfBlood/README.md)
Зачёркивает уже убитые цели в книге «Литания крови».

## Lead List <sup>[esoui](https://www.esoui.com/downloads/info4159-LeadList.html)</sup>
Показывает список найденных зацепок c фильтрами.

### [Kana LeadList: search tools](KanaLeadList/README.md)
Дополняет список зацепок фильтрами, подсказками наград и быстрым лоцированием.

## [Kana Widgets](KanaInfoBar/README.md)
Собирает в одной панели пинг, FPS, DPS, состояние инвентаря и снаряжения, уведомления и цену краденого.

## [Kana Dialogue: no repeat](KanaNoRepeat/README.md)
Скрывает кнопку «Повторить» в диалогах ESO.

## [Kana LibQuestData: quest fixes](KanaQuestZoneFix/README.md)
Исправляет зоны, точки и доступность отдельных заданий.

## [Kana Player Ping](KanaPlayerPing/README.md)
Показывает пульсирующие кольца вокруг вашего значка на карте.

## Kana Armor Penetration Bar
Показывает под здоровьем цели шкалу вашего пробития относительно её сопротивления.

## [Kana Season One Travel](KanaSeasonOneTravel/README.md)
Добавляет на карту вкладку с событиями и переходом к ближайшим святилищам.

## Kana Dialogue: slow text
Плавно раскрывает текст реплик в диалогах ESO.

## [Kana Wardrobe](KanaWardrobe/README.md)
Управляет пресетами экипировки, навыков, атрибутов и внешнего вида.

## [Kana Stat Sources](KanaStatSources/README.md)
Показывает источники характеристик персонажа.

## [Kana Trifecta Tracker](KanaTrifecta/README.md)
Показывает время, смерти группы и боссов при попытке трифекты.

## [Kana Daily Writ Recipes](KanaWritRecipes/README.md)
Помечает рецепты для ежедневных заказов снабжения.

## [Kana Zone Completion](KanaZoneGoals/README.md)
Добавляет на карту дополнительные цели для исследования области.
