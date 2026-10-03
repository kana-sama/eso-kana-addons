Советую ставить аддоны через [ESO Addon Manager](https://github.com/arviceblot/eso-addons). Он сам качает данные для TTC и HM, качает зависимости аддонов, позволяет их обновлять.

Свои аддоны из этого репозитория размещайте в `AddOns/eso-kana-addons/`:
пути к их ресурсам учитывают эту папку. Команды вида `lua Kana…/tests/…`
запускайте из корня `eso-kana-addons`; тесты с отдельными инструкциями
запускайте из указанной в них папки.

# Внешние аддоны

## AetherChat <sup>[esoui](https://www.esoui.com/downloads/info4798-AetherChat.html)</sup>
Чат аля мессенджер.

### KanaAetherChat
- ESC закрывает чат.
- хоткей открытия чата (Enter например) открывает с инпутом в фокусе чтобы сразу писать.
- Между сессиями сохраняется последний чат.

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

## Combat Metronome <sup>[esoui](https://www.esoui.com/downloads/info2373-CombatMetronomeGCDTracker.html)</sup>
Рисует GCD шкалу с учетом пинга.

### KanaCooldownMetronome
Позволяет делать шкалу радиальной, чтобы рисовать вокруг прицела.

## CrutchAlerts <sup>[esoui](https://www.esoui.com/downloads/info3137-CrutchAlerts.html)</sup>
Еще таймеры разных атак боссов.

## Calamath's Shortcut Pie Menu <sup>[esoui](https://www.esoui.com/downloads/info3088-CShortcutPieMenu.html)</sup>
Добавляет кастомные круговые панели для кастомных команд (телепорт к дому, открыть книгу, перезагрузить интерфейс, вызвать какую-то команду из аддона).

## Currently Equipped <sup>[esoui](https://www.esoui.com/downloads/info3524-CurrentlyEquipped--EquippedSetDisplay.html)</sup>
Позволяет рисовать панель

### KanaCurrentlyEquipped
Панель рисуется теперь только в инвентаре.

## Dolgubon's Lazy Writ Crafter <sup>[esoui](https://www.esoui.com/downloads/info1346-DolgubonsLazyWritCrafter.html)</sup>
Автоматически берет, делает и сдает ремесленные дейлики.

## Dustman <sup>[esoui](https://www.esoui.com/downloads/info97-Dustman.html)</sup>
Запоминает какие предметы ты пометил как хлам и отмечает автоматически. Позволяет продавать весь хлам.

## NameLanguageNinja <sup>[esoui](https://www.esoui.com/downloads/info2667-NameLanguageNinja-Translationassistant.html)</sup>
Показывает английские названия для навыков и шмоток.

## Harven's Improved Skills Window <sup>[esoui](https://www.esoui.com/downloads/info489-HarvensImprovedSkillsWindow.html)</sup>
Позволяет видеть все морфы на панели навыков.

### KanaSkillTranslations
Добавляет английские названия морфов через NameLanguageNinja.

## HarvestMap <sup>[esoui](https://www.esoui.com/downloads/info57-HarvestMap.html)</sup>
Метки известных точек спавна ресурсов на карте и в мире. Так же стоит поставить [HarvestMap-Data](https://www.esoui.com/downloads/info3034-HarvestMap-Data.html) в котором уже база данных меток. ESO Addon Manager умеет эти данные обновлять.

## HarvestRoute <sup>[esoui](https://www.esoui.com/downloads/info57-HarvestMap.html)</sup>
Позволяет строить маршруты сбора ресов.

## Quest Map <sup>[esoui](https://www.esoui.com/downloads/info1022-QuestMap.html)</sup>
Показывает метки квестов на карте.

### KanaQuestMap
- Показывает инфу о том, из какого дополнения квест.
- Исправляет кучу багов.
- Добавляет черный список квестов в настройки.

## Reminderz <sup>[esoui](https://www.esoui.com/downloads/info3248-Reminderz-Onscreenremindersforfood....html)</sup>
Кричит что забыл поесть, показывает в чатике прогресс достижений.

## SkillExp <sup>[esoui](https://www.esoui.com/downloads/info4445-SkillExp.html)</sup>
Трекер прокачки навыков.

### KanaSkillExp
Позволяет указывать в контекстном меню какие конкретные навыки я хочу трекать.

## Rare Fish Tracker <sup>[esoui](https://www.esoui.com/downloads/info665-RareFishTracker.html)</sup>
Показывает каких рыбов осталось словить в локации на ачивку. KanaZoneGoals использует данные отсюда.

## Research Assistant <sup>[esoui](https://www.esoui.com/downloads/info111-ResearchAssistant.html)</sup>
Показывает метки на шмотках об исследовании, позволяет не хранить дубли.

## Show Global Cooldown <sup>[esoui](https://www.esoui.com/downloads/info1625-ShowGlobalCooldown.html)</sup>
Рисует анимацию ГКД на панели.

## Tamriel Trade Centre <sup>[esoui](https://www.esoui.com/downloads/info1245-TamrielTradeCentre.html)</sup>
Показывает аукционные цены.

## The Questing Guide
Показывает список сюжетных квестов по дополнениям. Используется как зависимость в ряде аддонов.

## Map Pins <sup>[esoui](https://www.esoui.com/downloads/info1881-MapPins.html)</sup>
Добавляет на карту метки с книгами, шардами, ивентами, неоткрытыми локациями.

# Мои аддоны или форки

## KanaAudibleFishBite
Упрощает рыбалку, проигрывает звук и показывает текст что нужно вытащить.

Это форк AudibleFishBite, который обновлен под текущую версию ESO, заменяет звук и рисует текст.

## KanaAuras
Это мои кастомные ауры для арканиста (круг вокруг прицела заполняется) и оборотня (отдельная панель с голодом, яростью и зарядами).

## KanaBladeOfWoe
Позволяет убивать Клинком Горя даже если включена защита от убийства мирных жителей.

## KanaColorMap
Делает зоны на карте мира цветными.

## KanaCooldownPanel
Дублирует таймеры с обоих панели, но в прозрачном не мешающем виде, чтобы можно было поставиь под курсор и все равно видеть персонажа. Так же показывает яркий сигнал что какой-то навык не на таймере. Добавляет контектное меню к навыкам панели чтобы настраивать для каких навыков нужны алерты.

## KanaCraftedSetCollections
Показывает крафтовые сеты в коллекции сетов, чтобы поиском искать какие сеты где можно скрафтить.

## KanaOutfitBrowser
Группирует стили шмоток по сетам, а не по типу, чтобы можно было быстро применять сеты целиком.

## KanaEffects
Позволяет создавать свои панели бафов/дебафов с произвольными фильтрами и стилями.

## KanaEnemyMark
Рисует метки над врагами, которые с тобой в бою. Иногда я не вижу каких-нибудь жуков в земле.

## KanaLaunderGuard
Блокирует отмывание сокровищ. Однажды я отмыл сокровик на несколько десятков тысяч.

## Lead List <sup>[esoui](https://www.esoui.com/downloads/info4159-LeadList.html)</sup>
Показывает список найденных зацепок c фильтрами.

### KanaLeadList
Дополнительные фильтры и настройки.

## KanaInfoBar
Рисует панель на который можно поставить разные виджеты с информацией.
- фпс и пинг
- заполнение сумок
- сколько денег можно заработать если продать все краденое
- прочность снаряжения
- дпс метр
- личные сообщения от AetherChat

## KanaNoRepeat
Скрывает кнопку "повторить" из диалогов. Бесит

## KanaQuestZoneFix
Это фиксы баз данных с квестами.

## KanaPlayerPing
Рисует вечный пинг вокруг персонажа. Чтобы всегда было видно где я.

## KanaReadBook
Добавляет команду для чтения книги по названию.

## KanaSeasonOneTravel
Добавляет на карте вкладку с ключевыми точками первого сезона.

## KanaSlowAddon
Показывает тест в диалогах медленно. /kslow позволяет указать что диалоги этого NPC должны быть моментальными.

## KanaWardrobe
Переключение пресетов шмоток+аттрибутов+навыков.

## KanaWritRecipes
Помечает рецепты, нужные для дейиков.

## KanaZoneGoals
Добавляет кучу новых целей на карте.

## KanaWaypointBeam
Рисует луч света там где метка.
