# Исследование интерфейса эффектов ESO

> Примечание к редакции 2: начальная фиксированная схема панелей заменена конструктором виджетов. Актуальные правила — в SPEC.md, дополнительное сравнение классификаций — в widgets-and-sets.md.


Проверено 3 октября 2026. Поиск не доказывает, что аналога нигде не существует. Ниже — наиболее близкие найденные решения и конкретные пробелы относительно запроса.

## Сравнение готовых решений

«Есть» означает заявленную автором возможность, а не проверку установленного аддона в ESO. «Не подтверждено» не означает техническую невозможность.

| Кандидат | Скрытие и отдельные панели | Постоянная сетка | Минорный и мажорный в одной ячейке | Главный пробел |
| --- | --- | --- | --- | --- |
| Srendarr | Есть blacklist/whitelist, распределение по рамкам, отдельно длинные, короткие, major/minor, эффекты цели | Готовая таблица семейств не подтверждена | Не подтверждено | Отличный обычный трекер, но требование постоянных семейств остаётся |
| LUI Extended | Есть короткие, длинные и prominent-панели; контекстные действия | Искомая сетка не подтверждена | Не подтверждено | Большой UI-комбайн; старое consolidation нельзя считать доказательством нынешнего поведения |
| Bandits UI | Есть фильтры, дополнительные панели и отдельные widgets | Можно разместить widgets вручную; готовая карта семейств не подтверждена | Не подтверждено | Настройка отдельных индикаторов вместо готовой системы |
| Hyper Tools | Конструктор индикаторов, групп и условий, просмотр событий/эффектов | Можно собрать вручную | Возможна композиция индикаторов, готовый пресет не найден | Требует авторинга большого набора трекеров |
| Quantum’s Aura Tools | Библиотека наблюдённых эффектов, Ignore/восстановление, слои | Есть grid с фиксированными ячейками при выключенном fill | Параллельные слои дают основу; готовая реализация пары не подтверждена | Beta, автор указывает English client only; интеграция со штатным редактором не подтверждена |
| Group Buff Panels | Панели выбранных эффектов на участниках группы | Таблицы групповых аптаймов | Другая задача | Не замена личного и целевого интерфейса |

Во всех строках поддержка именно **нового штатного HUD editor**, а также удобный просмотр пропавшей из reticleover цели, не подтверждены. Настройка собственных координат аддона не равна интеграции со штатным редактором.

## Точные источники

- [Srendarr](https://www.esoui.com/downloads/info655-Srendarr-AuraBuffDebuffTracker.html): Addon Info → SRENDARR: Advanced Aura Tracking → списки возможностей; искать `Separate different effect types`, `Assign important effects`, `blacklist`. Есть распределение конкретных ID по рамкам. Это не доказательство закреплённых мест каждого семейства.
- [LUI Extended](https://www.esoui.com/downloads/info818-LuiExtended.html): описание Buff & Debuff Tracking; changelog 7.0.0.0 — действия правой кнопкой; 6.2.2 — удаление старых опций Consolidating Major/Minor. Исторический пункт не используется как доказательство отсутствия всех новых способов группировки.
- [Bandits UI](https://www.esoui.com/downloads/info1643-BanditsUserInterface.html): описание и changelog, искать `custom buffs panel`, `widgets`, `Long buffs`. Размещение отдельных widgets не подтверждает автоматическую карту всех семейств.
- [Hyper Tools](https://www.esoui.com/downloads/info3057-HyperTools.html): описание после Version → Icon Trackers / Progress Bar Trackers / Conditions / Effect Viewer. Конструктор позволяет собрать многое, но готовый профиль под все шесть требований не найден.
- [Quantum’s Aura Tools README](https://github.com/quantumfate/quantum-aura-tools#readme): Features → Parallel layers, Grid layout; Effect Aggregator → Ignore, Freeze view, English client only. На момент чтения raw README обозначен v0.2.0-beta8. [DESIGN.md](https://github.com/quantumfate/quantum-aura-tools/blob/main/DESIGN.md), Group grid layout: постоянный cells mapping, фиксированный размер и отключаемое уплотнение. DESIGN помечен pre-implementation, поэтому описание реально заявленных возможностей берётся прежде всего из README. Аддон не установлен и не испытан нами.
- [Group Buff Panels](https://www.esoui.com/downloads/info4226-GroupBuffPanels.html): Profiles, Panel Positioning, Editing the Supported Effects List. Предназначен для контроля бафов участников группы.

## Выбор направления

1. **Самостоятельный KanaEffects — рекомендуемый проект.** Готовая раскладка, русские названия из API, простое распределение «таблица / короткие / боковая / скрыто». Потребует собственной поддержки каталога и адаптеров.
2. **Srendarr плюс небольшой Kana-модуль таблицы.** Можно использовать зрелый трекер для остальных панелей, но останутся два места настройки, два набора фильтров и отдельная работа с целью.
3. **Пресет или расширение Quantum’s Aura Tools.** Наиболее близкая техническая основа. Сначала нужен короткий практический аудит русского клиента, слоёв пары и интеграции с HUD editor. Для пользователя, который хочет сразу играть, конструктор может оказаться лишней сложностью.

Не следует переносить или форкать большой чужой код только ради экономии нескольких функций. Источники изучены для проверки возможностей, сторонний код в репозиторий не скопирован.

## Подтверждённые точки ESO API

Читалась актуальная ветка `live` официального зеркала esoui/esoui: commit `6639eb2adecc0480557d9068579319919a0c3fe6`, дата 2026-09-28. Это проверка исходников, не тест игрового клиента.

| Возможность | Точный участок |
| --- | --- |
| Собственные панели в редакторе | [hudmanager.lua](https://github.com/esoui/esoui/blob/6639eb2adecc0480557d9068579319919a0c3fe6/esoui/ingame/hud/hudmanager.lua#L323), `RegisterKeyboardElement`; `ZO_HUDManager_Element:Initialize` проверяет первичный anchor и отсутствие второго |
| Перечень элементов редактора | [hudeditor_keyboard.lua](https://github.com/esoui/esoui/blob/6639eb2adecc0480557d9068579319919a0c3fe6/esoui/ingame/hud/keyboard/hudeditor_keyboard.lua), `PopulateElementControls`, `hudElementRef` используется менеджером для геометрии |
| Штатные панели бафов зарегистрированы в редакторе | [buffdebuff.lua](https://github.com/esoui/esoui/blob/6639eb2adecc0480557d9068579319919a0c3fe6/esoui/ingame/buffdebuff/buffdebuff.lua#L326), регистрация selfContainerControl и ниже targetContainerControl |
| Целевая панель наследует видимость рамки цели | [buffdebuff.lua](https://github.com/esoui/esoui/blob/6639eb2adecc0480557d9068579319919a0c3fe6/esoui/ingame/buffdebuff/buffdebuff.lua#L384), `OnTargetFrameCreated`: anchor к Caption и `SetParent(targetFrameControl)` |
| Чтение эффектов | [ESOUIDocumentation.txt](https://github.com/esoui/esoui/blob/6639eb2adecc0480557d9068579319919a0c3fe6/ESOUIDocumentation.txt#L13130), `GetNumBuffs`, `GetUnitBuffInfo`: effectType — возврат 8, abilityId — 11, castByPlayer — 13 |
| Обновления | Тот же API-файл, `EVENT_EFFECT_CHANGED`, `EVENT_EFFECTS_FULL_UPDATE`, `EVENT_RETICLE_TARGET_CHANGED` |
| Реальный масштаб | Тот же API-файл, `GetUIGlobalScale`; сверять с `GuiRoot:GetDimensions` и размером рендера |

Из наличия регистрации следует техническая возможность интеграции, но ещё надо проверить порядок загрузки, editor reference controls, сохранение и восстановление координат. Прямое наследование скрываемой рамки цели использовать нельзя, если нужен доступный курсору снимок.

## Локальная среда

Из `../UserSettings.txt`: FullscreenWidth 2560, FullscreenHeight 1440, CustomUIScale 0.80432397, UseCustomUIScale.2 1. Пользователь подтвердил 2.5K на Apple Studio Display. Физические 5K монитора не используются как игровое рабочее разрешение макета. Коэффициент ползунка — исходное предположение макета, а не доказанный коэффициент UI→пиксели на Retina.

Текущий KanaAuras состоит из специализированных индикаторов. Его файлы не изменены. Предыдущие сведения о старой универсальной allowlist-версии не описывают нынешний каталог файлов.
