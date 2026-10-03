# KanaWardrobe Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Создать простой самостоятельный аддон частичных пресетов экипировки с понятным применением, предпросмотром сетов и обратимым редактированием.

**Architecture:** Чистые модели пресетов, сетов и плана перемещений отделены от API ESO. Один исполнитель подтверждает каждый шаг по уникальному ID; одна сессия управляет применением, редактором и восстановлением. Все поверхности используют общий индекс принадлежности вещей, а интерфейс сохраняет штатные действия и фильтры ESO.

**Tech Stack:** ESO Lua/XML, синтаксис Lua 5.1, ZO_SavedVars, штатные сцены/контролы/предметные API; необязательный LibFilters-3.0. Локальные тесты — Lua с подменой API и управляемыми часами, клиентская проверка — ESO keyboard UI.

**Spec:** [Согласуемое устройство и правила](</Users/kana/Documents/Elder Scrolls Online/live/AddOns/docs/superpowers/specs/2026-09-28-kana-wardrobe-design.md>).

**Research:** [Разбор WW 1.23.2 и интерфейсов ESO](</Users/kana/Documents/Elder Scrolls Online/live/AddOns/docs/superpowers/plans/2026-09-28-kana-wardrobe-research.md>). Читать вместе с планом: там точные файлы, функции и причины отличий от WW.

Статус: **реализация разрешена пользователем и ведётся через субагентов**. Фактические результаты автоматических и клиентских проверок фиксируются отдельно в README и docs/client-validation.md.

## Global Constraints

- Самостоятельный `KanaWardrobe`, один глобальный namespace. Не менять WW, другие аддоны, их настройки или SavedVariables.
- 14 слотов: 7 брони, ожерелье, 2 кольца, 4 позиции оружия двух панелей. Яды, костюм/табард, навыки, CP, еда и автосмена по зонам не входят в область работ.
- Отсутствующий ключ — не менять; `{kind="empty"}` — снять; `{kind="item", uid="…", link="…"}` — надеть конкретный экземпляр. Никакой подстановки похожих вещей.
- Необходимые дополнительные изменения незаданных слотов разрешены после одного подтверждения с точными предметами, слотами, панелями, направлением и причиной. Согласие не изменяет пресет.
- В предпросмотре считать **только вещи пресета**, отдельно для основной/запасной панели. Не добавлять вещи текущей экипировки из незаданных слотов.
- Обычное применение использует BAG_WORN/BAG_BACKPACK. Автоматического изъятия из банка нет.
- Сохранённые доступные экземпляры обязательно заблокированы. После удаления последней ссылки блокировку автоматически не снимать.
- Один редактор/операция. Save и Cancel возвращают все 14 исходных слотов. Бой не создаёт очередь неожиданного применения после его окончания.
- Принадлежность показывать в обычных тултипах конкретных вещей. Общий переключатель скрытия доступен в инвентаре, банках и магазине; при любой незавершённой сессии редактора своё скрытие отключено.
- Имена: непустые, до 48 Unicode-символов, уникальны у персонажа; пользовательский текст не интерпретируется как разметка ESO. Порядок списка стабилен.
- Основной интерфейс — keyboard. Не подменять глобальные защищённые API, `GetItemLinkSetInfo`, класс `ZO_Tooltip` или стандартный `ItemTooltip` ради предпросмотра.
- API manifest выбирать по проверенному `GetAPIVersion()` клиента. Lua 5.4 на машине подходит для модельных тестов, но не доказывает совместимость Lua/XML с ESO.
- Не считать запись SavedVariables в памяти гарантией сохранения на диск при аварии. Не вызывать автоматический `/reloadui`.

## Review Focus

1. Смена bag/slot и запоздалое событие после таймаута: не надеть другой экземпляр и не продолжить устаревшую цепочку. Тесты T1/T4.
2. Полная сумка, циклическая перестановка и мифик из незаданного слота: заранее рассчитать временное место и конкретные дополнительные изменения. Тесты T3.
3. Смешанные совершенные/обычные вещи, двуручное оружие и частичный пресет: корректные отдельные счётчики, независимые от надетого сейчас. Тесты T2.
4. Save уже записал пресет, но возврат прервался боем или `/reloadui`: восстановить журнал, не повторить запись и не потерять исходную экипировку. Тесты T6.
5. Переиспользуемые тултипы/списки и сторонние фильтры: не оставить чужую принадлежность, не скрыть одноимённый экземпляр, не сбросить поиск. Тесты T8/T9.

---

## Файлы и границы

Все пути ниже относительны `/Users/kana/Documents/Elder Scrolls Online/live/AddOns`. Новые продуктовые файлы создаются только в `KanaWardrobe/`.

| Файлы | Ответственность |
|---|---|
| `KanaWardrobe.txt`, `Core.lua`, `lang/en.lua`, `lang/ru.lua` | Manifest, namespace, загрузка/события, SavedVariables, строки |
| `Slots.lua`, `Presets.lua` | Порядок 14 слотов, значения/снимки, хранилище и обратный индекс |
| `Inventory.lua` | Единственная граница игровых API вещей: UID, доступные bags, metadata, запросы, часы |
| `EquipmentPlan.lua`, `EquipmentRunner.lua` | Чистый план/дополнительные изменения/место; серии независимых запросов, зависимости и подтверждение |
| `Session.lua` | Координатор Apply/New/Edit/Save/Cancel, журнал и восстановление |
| `SetModel.lua`, `SetPreview.lua` | Подсчёт сетов и собственные полные карточки |
| `Protection.lua`, `ItemTooltips.lua` | Системные замки и названия пресетов в предметных подсказках |
| `InventoryFilters.lua` | Общий фильтр, адаптеры окон, обновление и счётчик |
| `UI.lua`, `UI.xml`, `Dialogs.lua` | Панель, редактор, галочки, кнопки скрытия, подтверждения |
| `tests/run.lua`, `tests/support/fake_eso.lua`, `tests/test_*.lua` | Модельные/интеграционные проверки; не загружать через manifest |
| `README.md`, `docs/client-validation.md` | Пользовательские правила и фактические результаты клиентских проверок |

В каталоге AddOns нет общего Git-репозитория. Не инициализировать его и не включать чужие аддоны в коммиты. На этапе реализации изоляция/учёт изменений выбираются для одного KanaWardrobe; коммиты ниже делать только в его собственном репозитории, если он создан. Документы проектирования уже лежат отдельно в `docs/superpowers/`.

## Общие типы и протокол

Это контракты Lua-таблиц, а не дополнительные классы или библиотека типов.

```text
SlotValue = {kind="empty"} | {kind="item", uid=string, link=string}
SlotMap = {[equipSlot: integer]: SlotValue}            -- допускает пропуски
Snapshot = SlotMap                                   -- все 14 ключей обязательны
Preset = {id:string, name:string, revision:integer, slots:SlotMap}
Membership = {characterId:string, characterName:string, presetId:string, name:string, order:integer}
Location = {bagId:integer, slotIndex:integer, uid:string, link:string}
InventoryState = {worn:Snapshot, byUid:{[string]:Location}, freeSlots:integer, version:integer}
ItemMetadata = {valid:boolean, availableToEquip:boolean, equipType:integer, weaponType:integer,
                setId:integer, familyId:integer, perfected:boolean, mythic:boolean,
                max:integer, bonuses:table}
Problem = {code:string, details:table}                 -- код переводится в UI, не в модели
ExtraChange = {uid:string, link:string, fromSlot:integer, toSlot:integer|nil,
               reason:"twoHanded"|"mythic"|"sourceMove"}
Step = {kind:"equip"|"unequip", uid:string, equipSlot:integer}
Capabilities = {fullBagEquipSwap:boolean}              -- false до проверки в ESO
Plan = {intent:SlotMap, before:Snapshot, target:Snapshot, steps:Step[],
        extras:ExtraChange[], extraKey:string, requiredFree:integer, mode:string}
RunResult = {status:"success"|"failed"|"interrupted"|"uncertain",
             actual:Snapshot, problem:Problem|nil, pending:(Step & {before:Snapshot, expected:Snapshot, batch:Step[]})|nil}
SessionView = {state:string, paused:boolean, kind:string|nil, name:string|nil,
               selected:table, missing:table, saved:boolean, problem:Problem|nil,
               confirmation:{plan:Plan,presetName:string}|nil}
SetSummary = {sets:SetCardModel[]}
SetCardModel = {familyId:integer, representativeLink:string, front:integer, back:integer,
                perfectedFront:integer, perfectedBack:integer, max:integer,
                bonuses:table, missingUids:string[]}
```

`nil`/`"0"` от UID API означают отсутствие вещи. Сериализовать ID только через `Id64ToString`, не через float/`tonumber`. Возвращаемые моделями данные не разделяют изменяемые таблицы с SavedVariables.

Хранилище: `KanaWardrobeSaved`, schemaVersion=1; отдельные сервер/аккаунт, внутри `characters[characterId]={name, order={}, presets={}, hidePresetItems=false, journal=nil}`. Defaults не содержат демонстрационных пресетов. Репозиторий даёт индекс всех персонажей сервера для защиты/тултипов; скрытие использует только текущего.

Внутренний `emit(eventName,payload)` передаётся конструкторам явно, не ищется как глобальная функция. Тестовый `clock` предоставляет `NowMs()`, `Schedule(delayMs,callback)->handle`, `Cancel(handle)`; клиентский адаптер использует то же миллисекундное время и снимаемые регистрации EVENT_MANAGER. `events` предоставляет `Subscribe(eventName,callback)->handle`, `Unsubscribe(handle)`.

Журнал включает version=1, kind, phase, presetId/revision, исходный полный снимок, исходный пресет, выбранные слоты, отсутствующие UID, признак saveCommitted, последний подтверждённый шаг и незавершённый запрос. Снимок записывается до первого запроса. Большие игровые объекты/контролы/функции в SavedVariables не сохранять.

Состояния координатора: `idle`, `confirming`, `applying`, `preparingEdit`, `editing`, `restoring`, `recovery`. `paused` сохраняет текущую фазу. Пока не `idle`, новое Apply/New/Edit не начинается. В `editing` игрок может штатно переодеваться; во время автоматических шагов неожиданное внешнее изменение вызывает остановку.

Команды тестов выполнять из корня AddOns. `lua KanaWardrobe/tests/run.lua <group>` завершает процесс ненулевым кодом при ошибке, показывает имена проверок и итог; `all` запускает весь набор. Ни один тест не вызывает реальный клиент или торговую операцию.

## Task 1: Хранилище, идентичность и изолированный API

**Files:** создать `KanaWardrobe/{KanaWardrobe.txt,Core.lua,Slots.lua,Presets.lua,Inventory.lua,lang/en.lua,lang/ru.lua,tests/run.lua,tests/support/fake_eso.lua,tests/test_foundation.lua}`.

**Interfaces:** `Slots.Copy(map)`, `Slots.Equal(a,b)`, `Slots.FromWorn(readSlot)->Snapshot`; `Presets.New(saved,server,account,characterId,characterName,emit)->repo`; `repo:Get(id)->Preset|nil`, `repo:List()->Preset[]`, `repo:NewDraft()->Preset`, `repo:Save(preset,expectedRevision)->Preset|nil,Problem`, `repo:Delete(id,expectedRevision)`, `repo:Memberships(uid,scope)->Membership[]` (`scope="all"|"current"`). `Inventory.New(api,emit)->inventory`; `inventory:Capture()->InventoryState`, `inventory:Resolve(uid,equipOnly)->Location|nil`, `inventory:Describe(link,uid)->ItemMetadata`, `inventory:Request(step)->boolean,Problem|nil`, `inventory:NowMs()->number`. Репозиторий испускает `PresetsChanged`. NewDraft выделяет ID из монотонного счётчика персонажа, revision=0 и свободное имя «Новый пресет»/«Новый пресет 2»; запись в presets/order появляется только после Save.

- [ ] Написать `test_foundation.lua`: различаются пропуск/empty/item; копия не мутирует оригинал; два одинаковых itemLink с разными UID не совпадают; `nil`/`"0"` исключены из индекса; перемещение bag slot 3→19 меняет `Resolve`, но сохраняет принадлежность. Проверить сервер/персонажа, удаление одной из двух ссылок, обновление link при прежнем UID.

  Ключевой тест `identity_follows_bag_moves`: после перестановки fake bag выполнить `assert(inventory:Resolve("ring-1", true).slotIndex == 19)` и `assert(#repo:Memberships("ring-1", "current") == 2)`.
- [ ] Включить тесты имени: 48 кириллических символов допустимы, 49 нет; пустое/пробелы/дубликат отклоняются; ввод `|c…`, `|H…` и перевод строки не создаёт разметку/вторую строку. Явно выбрать нормализацию: обрезать крайние пробелы, перевод строки заменить пробелом, `|` не принимать; дубликаты проверять после этих правил с `zo_strlower`.
- [ ] Создать runner и fake API, запустить `lua KanaWardrobe/tests/run.lua foundation`; ожидается FAIL на ещё отсутствующих продуктивных методах, а не ошибка загрузки самого теста.
- [ ] Реализовать контракты. `Inventory` сканирует доступные bags через штатный итератор, предпочитает реальные worn/backpack для экипировки, очищает устаревшие сведения при закрытии/смене банка. Нельзя считать кэш закрытого банка доказательством текущей доступности. Metadata содержит equipType/weaponType/setId/семейство/perfected/mythic; мифик определяется именованным API/enum, без числа `6`.
- [ ] Manifest загружает только продуктовые файлы; schema создаётся через `ZO_SavedVars:NewAccountWide` с разделением миров. Добавить `## OptionalDependsOn: LibFilters-3.0`, без зависимости от WW/LibAsync/LibSets. `ZoUTF8StringLength` и `SetMaxInputChars(48)` использовать на клиенте; тестовый адаптер длины поддерживает UTF-8 без глобальной библиотеки `utf8` в продукте.
- [ ] Повторить `foundation`; ожидается PASS. При собственном Git зафиксировать только файлы T1: `feat: add preset storage and equipment identity`.

## Task 2: Сеты и ранний прототип полного тултипа

**Files:** создать `KanaWardrobe/{SetModel.lua,SetPreview.lua,UI.xml,tests/test_sets.lua,docs/client-validation.md}`; обновить manifest.

**Interfaces:** `SetModel.Build(preset,describe)->SetSummary`, где `describe(itemSlotValue)->ItemMetadata` вызывает `inventory:Describe(ref.link,ref.uid)`: ссылка задаёт свойства, UID — доступность именно этого экземпляра. `SetPreview.New(parent)->preview`, `preview:Show(anchor,summary)`, `preview:Hide()`, `preview:Refresh(summary)`. Перечень бонусов каждого SetCardModel содержит required/perfected/description/activeFront/activeBack.

- [ ] Написать тесты `test_sets.lua`: три общих вещи + двуручное оружие основной панели дают front=5/back=3; посторонняя надетая вещь не изменяет результат. Проверить лук/посох/двуручный меч, два одноручных, 6/5, сет из одной вещи, разные сеты обеих панелей, отсутствие сета, явно пустое оружие.

  Ключевой тест `two_handed_counts_only_preset`: `assert(summary.sets[1].front == 5)` и `assert(summary.sets[1].back == 3)` до и после изменения посторонних worn slots.
- [ ] Добавить случай смешанного обычного/совершенного семейства: общий бонус считается по сумме, perfected-бонус — по perfectedFront/perfectedBack; представитель предпочтительно совершенный. Отсутствующая физически вещь учитывается по сохранённому link с missing UID. Если link не даёт достоверных данных, показать «Сведения о сете недоступны», не придуманный нулевой результат.
- [ ] Запустить `lua KanaWardrobe/tests/run.lua sets`; ожидается FAIL на модели. Реализовать подсчёт: броня/украшения идут в обе панели, оружие только в свою; представители и карточки стабильно сортируются по порядку слотов. Не ограничивать счётчик `max`, использовать его только как порог/знаменатель.
- [ ] Реализовать собственные экземпляры tooltip-контролов: `ZO_Tooltip:Initialize(control, ownStyleNamespace, style)` — это mixin, не `ZO_Tooltip:New`. Заменить `AddSet` только у этих экземпляров; сохранить API-контракт возвращаемых suppression type/refId, штатные ограничения сета и остальные секции предмета. Стили клонировать в свой namespace, не мутировать глобальные.
- [ ] Добавить временную диагностическую команду `/kw previewtest` только для отрисовки двух карточек 3/5 и 5/5; в ESO проверить полный предметный текст, пороги/совершенный бонус, отсутствие изменений обычного ItemTooltip. Убрать публичную команду перед выпуском либо оставить только за явным debug-флагом.
- [ ] Запустить `sets`; ожидается PASS. В `docs/client-validation.md` записать реальную версию клиента и результат прототипа со скриншотами. Если Lua-layout не подходит keyboard UI, заменить только SetPreview собственными секциями на тех же API; повторить тот же сценарий. Пока результат не проверен, отметить pending, а не «готово».
- [ ] При собственном Git: `feat: preview preset sets on both weapon bars`.

## Task 3: План перемещений и точное согласие на дополнительные изменения

**Files:** создать `KanaWardrobe/{EquipmentPlan.lua,tests/test_planner.lua}`.

**Interfaces:** `EquipmentPlan.Build(state,intent,mode,capabilities)->Plan|nil,Problem`, `mode="apply"|"prepareEdit"|"restore"`; `EquipmentPlan.Revalidate(plan,state,capabilities)->Plan|nil,Problem`. В режиме restore intent — полный исходный Snapshot. `extraKey` — стабильная сериализация UID/fromSlot/toSlot/reason, не криптографический токен.

- [ ] Написать тесты: заданная броня не затрагивает остальное; отмеченный empty снимает; уже совпавший набор имеет 0 шагов; отсутствующий UID и два одинаковых UID в конечном наборе отклоняются без команд. Два мифика, явно заданные в пресете, — ошибка, а не повод выбрать один.
- [ ] Проверить три extras: двуручное + щит незаданной руки; старый мифик в другом незаданном слоте; источник нужного кольца в незаданном слоте. Например, `extras[1]` для щита содержит его UID, слот/панель, `toSlot=nil`, reason=`twoHanded`; final target имеет пустую руку, intent остаётся неизменённым. Для переноса sourceMove указывается целевой слот, исходный становится пустым.

  Ключевой тест `two_handed_requires_precise_extra`: `assert(#plan.extras == 1)`, `assert(plan.extras[1].uid == "shield-1")`, `assert(plan.extras[1].reason == "twoHanded")`, `assert(plan.intent[EQUIP_SLOT_OFF_HAND] == nil)`.
- [ ] Добавить тесты перестановки колец, оружия между панелями в обоих направлениях, полного цикла, 0 свободных мест, недостатка места при снятии мифика, а также случая, где первое надевание в пустой слот освобождает нужную ячейку. Замена щита на другой UID меняет extraKey; перестановка исходной вещи между ячейками сумки — нет.
- [ ] Запустить `lua KanaWardrobe/tests/run.lua planner`; ожидается FAIL. Реализовать полный target сначала, затем зависимости/симуляцию вместимости. Сначала доступные шаги, освобождающие место; old mythic снимается до нового; источник из worn переносится через сумку; для цикла используется одна временная ячейка. Снимать всё с персонажа запрещено.
- [ ] `requiredFree` — минимальная исходная вместимость для построенного безопасного порядка, не утверждение о математическом оптимуме любых неизвестных игровых обменов. Без подтверждённого fullBagEquipSwap консервативно требовать временное место для обмена в занятый слот. При нехватке Problem содержит число дополнительных ячеек. Типовая совместимость и уровень проверяются заранее; `IsEquipable`/`IsLockedWeaponSlot` не должны отклонять промежуточное ограничение, которое снимается предыдущим шагом, например старым мификом.
- [ ] Повторить `planner`; ожидается PASS. При собственном Git: `feat: plan partial gear changes and conflict consent`.

## Task 4: Быстрые серии запросов с подтверждением зависимостей и ограниченным ожиданием

**Files:** создать `KanaWardrobe/{EquipmentRunner.lua,tests/test_runner.lua}`; дополнить Inventory.lua и client-validation.md.

**Interfaces:** `EquipmentRunner.New(inventory,events,clock)->runner`; `runner:Start(plan,onProgress,onDone)->operationId|nil,Problem`; `runner:Stop(reason)`; `runner:IsBusy()->boolean`. `onProgress` получает operationId/stepId/phase/actual/pending; перед отправкой запроса координатор успевает записать pending в журнал. `onDone(RunResult)` вызывается ровно один раз. `Inventory:Request` единственное место Equip/Unequip API; оно не возвращает «успех экипировки».

- [ ] Создать fake-clock тесты: независимые запросы отправлены до первого подтверждения; зависимые ожидают завершения предыдущей серии; правильный UID подтверждает, другой UID в нужном слоте не подтверждает; уже выполненный шаг не ждёт несуществующего события; новая ячейка источника используется перед каждым запросом.
- [ ] Проверить отсутствие/дубли/перестановку событий, timeout, позднее событие старой операции, повторный клик, бой/смерть/блок и внешнюю смену существенного слота. При таймауте pending сохраняется, новая цепочка сама не запускается, старые callbacks не вызывают Equip. Нет auto-resume после выхода из боя.

  Ключевой тест `timeout_keeps_unconfirmed_request`: после 5001 мс без подтверждения `assert(result.status == "uncertain")`, `assert(result.pending.uid == "weapon-1")`; позднее событие не увеличивает ранее записанное число `api.requests`.
- [ ] Запустить `lua KanaWardrobe/tests/run.lua runner`; ожидается FAIL. Реализовать operationId+stepId, централизованное снятие подписок/таймеров, перечитывание состояния после группы событий и резервный опрос каждые 100 мс. Ожидание серии 5000 мс по `GetFrameTimeMilliseconds`; по истечении — `uncertain` с фактическим снимком. Запрос убрать оружие — один раз, только для оружейных шагов, максимум 3000 мс; при удерживаемом блоке в начале отказ без очереди.
- [ ] До следующего зависимого шага подтвердить целевые UID/пустоту всей серии и связанные освобождения источников; после цепочки сравнить все 14 фактических слотов с plan.target. Не принимать GetItemId>0 за правильный экземпляр. Автоматическая попытка возврата допустима после однозначного обычного сбоя вне боя; при неопределённом запросе или внешнем изменении — recovery, без немедленного повторного Equip/Undress.
- [ ] В ESO проверить заблокированную вещь, полный backpack при замене, кольца, оружие main↔backup, двуручное со щитом, старый/новый мифик в разных слотах. Отдельно Oakensoul и запасную панель, недоступную по уровню/состоянию. Native bind-on-equip подтверждение при ручных действиях не обходить. Capabilities.fullBagEquipSwap включить только после подтверждения конкретного примитива; неподтверждённые варианты требуют scratch slot.
- [ ] Повторить `runner`; ожидается PASS. Записать клиентские наблюдения отдельно от модельных. При собственном Git: `feat: execute and verify equipment operations`.

## Task 5: Обязательная защита сохранённых экземпляров

**Files:** создать `KanaWardrobe/{Protection.lua,tests/test_protection.lua}`; дополнить Inventory.lua.

**Interfaces:** `Protection.New(repo,inventory)->protection`; `protection:Ensure(slots)->boolean,Problem|nil`, `protection:RefreshAccessible()`, `protection:Explain(uid)->Membership[]`. Inventory предоставляет `CanLock(location)`, `IsLocked(location)`, `SetLocked(location,true)` через свой API-адаптер. `Ensure` проверяет наблюдаемый флаг после установки.

- [ ] Тесты: один UID в двух пресетах; удаление одной/последней ссылки никогда не вызывает unlock; чужой ручной замок сохраняется; вещь другого персонажа также защищена; недоступная вещь получает блокировку при появлении в доступной сумке/банке. Ошибка CanLock/подтверждения возвращается до фиксации нового пресета.

  Ключевой тест `last_reference_keeps_lock`: после удаления обеих ссылок `assert(#repo:Memberships("ring-1", "all") == 0)` и `assert(inventory:IsLocked(inventory:Resolve("ring-1", false)))`.
- [ ] Запустить `lua KanaWardrobe/tests/run.lua protection`; ожидается FAIL. Реализовать обход уникальных UID и реагирование на PresetsChanged/изменение доступных bags. Если сторонний аддон снимает замок, выполнить ограниченное восстановление и сообщить конфликт; не делать бесконечный цикл запросов.
- [x] Исправление 2026-09-28: удалить перехват discovery/AddSlotAction. Даже замена одного callback через общий builder нарушает доверенную цепочку UseItem. Штатные функции и callbacks остаются неизменными; защита замков работает по событиям инвентаря.
- [ ] В клиенте проверить использование обычной вещи через keybind и меню после /reloadui, обычную разблокировку и восстановление замка вещи пресета. Автотест проверяет неизменность функции discovery при инициализации, изменениях пресетов/инвентаря и reload; он не моделирует доверие ESO к стеку вызовов.
- [ ] Повторить `protection`; ожидается PASS. При собственном Git: `feat: protect saved preset items`.

## Task 6: Единая сессия применения, редактора и восстановления

**Files:** создать `KanaWardrobe/{Session.lua,tests/test_editor.lua}`; подключить события Core.lua.

**Interfaces:** `Session.New(repo,inventory,planner,runner,protection,savedCharacter,capabilities,emit)->session`; `session:Apply(id)`, `session:BeginEdit(id,allowMissing)`, `session:BeginNew()`, `session:Confirm(extraKey)`, `session:RejectConfirmation()`, `session:SetSelected(slot,value)`, `session:SetName(name)`, `session:ResolveMissing(slot,choice)` (`choice="replace"|"empty"|"omit"`), `session:Save()`, `session:Cancel()`, `session:Pause(reason)`, `session:Resume()`, `session:Recover(action)` (`action="restore"|"restoreAvailable"|"keepCurrent"`), `session:GetView()->SessionView`. Ошибка возвращается как `nil,Problem`; успех принятия команды не означает завершение переодевания.

- [ ] Тесты полного жизненного цикла: новый пресет отмечает занятые слоты; checkbox сам не переодевает; Save читает фактически надетое; Cancel не меняет репозиторий; оба возвращают все 14 слотов и дополнительные согласованные снятия. Ноль выбранных отклоняется, выбранные empty допустимы. Второй Apply/Edit/New не начинает операцию.
- [ ] Проверить подтверждение: до Confirm запросов 0; Reject не меняет вещи; Confirm сверяет revision и заново построенный план; другой extraKey показывает новый диалог. Смена одной bag-ячейки без изменения результата не вызывает лишнего вопроса. Подтверждённые extras не меняют selected/сохранённый intent.
- [ ] Проверить отсутствие вещи: обычный Apply отказ; BeginEdit(id,true) готовит доступную часть и очищает указанные недоступные слоты после полного preflight/согласия. Ghost хранит старый UID/link; Save блокируется до replace/empty/omit, checkbox случайно не превращает пропавшую вещь в пустую запись.
- [ ] Проверить сохранённый журнал в каждой фазе: сбой/бой до Save, после блокировки, после записи пресета и посередине возврата; reload с saveCommitted=true не сохраняет второй раз. Нехватка места на возврат оставляет старый пресет и редактор открытыми. Принудительная смена сцены сохраняет паузу/черновик и bypass скрытия. KeepCurrent требует явного выбора и завершает журнал без обещания возврата.

  Ключевой тест `reload_after_commit_restores_once`: после пересоздания Session и завершения восстановления `assert(repo:Get(id).revision == committedRevision)`, `assert(Slots.Equal(inventory:Capture().worn, original))`, `assert(savedCharacter.journal == nil)`.
- [ ] Запустить `lua KanaWardrobe/tests/run.lua editor`; ожидается FAIL. Реализовать снимок до любых extra changes, durable-в-памяти journal до запроса, preflight восстановления → Ensure locks → commit preset → restore → очистка журнала только по подтверждённому успеху. Для обычного Apply также хранить baseline до окончания операции.
- [ ] После reload предложить восстановление, не отправлять команды автоматически. При timeout сохранить pending: сначала перечитать фактическое состояние, принять позднее подтверждение, если оно наблюдается; повторное восстановление запускается явным действием и из нового плана. Старый запрос нельзя отменить API, поэтому любое позднее несогласованное изменение снова останавливает процесс; не обещать атомарность при внешних действиях/сети.
- [ ] Если исходный UID исчез, обычный restore не выполняет доступную часть молча. Предложить «Восстановить доступные вещи» с перечнем того, что не вернётся; после этого `Recover("restoreAvailable")` строит план только доступных исходных вещей и исходных empty, пропуская недоступные item-слоты. Журнал сохраняется в recovery с перечнем оставшегося. Тест `partial_recovery_keeps_missing_reference` проверяет, что пропавший UID остаётся в original snapshot и полностью успешный возврат не объявлен. «Оставить текущую экипировку» явно завершает сессию; повторное восстановление доступно до этого выбора.
- [ ] Разрешённое закрытие редактора предлагает Save/Cancel/Continue, если штатный путь можно безопасно задержать. Принудительный уход/боевая сцена — Pause. Никакого глобального запрета смены сцены. После восстановления уведомления различают «сохранён» и «отменён», при частичном возврате перечисляют невосстановленные слоты.
- [ ] Повторить `editor`; ожидается PASS. При собственном Git: `feat: add reversible preset editing and recovery`.

## Task 7: Панель пресетов, диалоги и галочки

**Files:** создать `KanaWardrobe/{UI.lua,Dialogs.lua,tests/test_ui.lua}`; дополнить UI.xml, Core.lua, lang/*.lua, client-validation.md.

**Interfaces:** `UI.New(repo,session,preview)->ui`; `ui:Refresh()`, `ui:SetEditorLayout(active)`, `ui:RegisterHideToggle(parent,context,filters)` (filters появится в T9). `Dialogs.ConfirmExtras(plan,presetName,onAccept,onReject)`, `Dialogs.ConfirmDelete(preset,onAccept)`, `Dialogs.EditName(preset,onAccept)`, `Dialogs.CloseEditor(onSave,onCancel,onContinue)`, `Dialogs.Recovery(view,onAction)`, `Dialogs.ConfirmRestoreAvailable(missing,onAccept)`.

- [ ] В тестах viewmodel проверить доступность действий по состоянию, stable order, совпадение нескольких частичных пресетов, missing badge, отсутствие Apply при RMB/ellipsis. Проверить текст extras с itemLink/fromSlot/bar/toSlot/reason; delete имеет имя и предупреждение о сохранённых блокировках, Cancel в безопасном фокусе.

  Ключевой тест `context_menu_does_not_equip`: после RMB строки `assert(#api.requests == 0)`, после отмены extras `assert(Slots.Equal(inventory:Capture().worn, original))`.
- [ ] Запустить `lua KanaWardrobe/tests/run.lua ui`; ожидается FAIL. Реализовать панель справа от надетого, привязанную к inventory scene; условную видимость держать на дочернем контроле, чтобы scene fragment не открывал её самовольно. Ширина 220–260, строки 30–34; кнопка «Новый пресет», меню rename/edit/delete, без дополнительных настроек ради основных действий.
- [ ] Галочки 14–16 с областью клика около 20: броня снаружи, украшения/оружие в дополнительных коротких рядах. Один раз сохранить полные anchors/размеры затронутых штатных контролов, восстанавливать их точно; повторный вход не накапливает смещение. Вывести «Все»/«Ни одного», Save/Cancel, смысл отмеченной пустоты и подпись о возврате.
- [ ] Для ghost слота показать отсутствующую вещь и явные действия «Использовать надетое», «Сохранить пустым», «Не сохранять слот», связанные с ResolveMissing. Показать причины недоступности кнопок, операции «Надеваем…»/«Возвращаем экипировку…», восстановление после reload и предупреждение перед keepCurrent; не выдавать незавершённый возврат за закрытый редактор.
- [ ] Подключить SetPreview: задержка около 180 мс, переход мыши в карточки сохраняет их, вне видимых карточек нет невидимого перехватчика. Карточки 280–340, справа с переносом строк; при нехватке места общая прокрутка и одна колонка. В редакторе hover пресетов не мешает тултипам вещей. Повреждённый/пустой по сетам пресет показывает понятное сообщение.
- [ ] В ESO проверить русский длинный текст, несколько пресетов/совпадений, 1/3/6 сетов, край экрана, доступные масштабы, обе панели оружия, 10 входов/выходов редактора. Совместно с KanaCurrentlyEquipped и KanaInfoBar убрать пересечения, сохранив положение справа; результат приложить в client-validation.md. Временные изменения anchors должны исчезнуть и при аварийном выходе из редактора.
- [ ] Повторить `ui`; ожидается PASS. При собственном Git: `feat: add inventory preset panel and editor controls`.

## Task 8: Принадлежность в обычных предметных подсказках

**Files:** создать `KanaWardrobe/{ItemTooltips.lua,tests/test_tooltips.lua}`; подключить Core.lua.

**Interfaces:** `ItemTooltips.New(repo,inventory)->tooltips`; `tooltips:Attach()`, `tooltips:Invalidate()`. Контекст экземпляра хранится отдельно на tooltip instance: generation/bagId/slotIndex/uid; cached itemLink сам по себе не является контекстом UID.

- [ ] Тесты: все имена без дубликатов в порядке списка; имя другого персонажа; два одинаковых itemLink разных UID; rename/delete при открытом tooltip; переиспользование SetBagItem→SetLink→другая вещь; пустой UID очищает наш блок. Длинный список переносится, не отбрасывается до первого имени.

  Ключевой тест `pooled_tooltip_forgets_previous_uid`: fake tooltip после SetLink одноимённой вещи без UID содержит 0 собственных блоков; после повторного SetBagItem сохранённой вещи — ровно 1 блок с полным списком имён.
- [ ] Запустить `lua KanaWardrobe/tests/run.lua tooltips`; ожидается FAIL. Присоединить узкие post-hooks к известным предметным путям с bag/slot, включая worn/bank/repair; при каждом новом layout/clear/hide сбрасывать собственный контекст. Не добавлять сведения в произвольный SetLink, товар продавца или чужое объявление без достоверного экземпляра.
- [ ] Выводить компактный блок «Пресеты: …» после штатного содержимого, сохраняя другие дополнения. При PresetsChanged перерисовать известный активный layout под reentrancy guard, предварительно перепроверив UID. Не повторять Append поверх старого блока. Привязка UI и membership обновляются независимо от скрытия и активного редактора.
- [ ] Повторить `tooltips`; ожидается PASS. В ESO проверить worn/backpack/банк/ремонт и последовательные наведения вместе с установленными расширениями тултипов. При собственном Git: `feat: show preset membership in item tooltips`.

## Task 9: Общее скрытие в сумке, банках и торговых окнах

**Files:** создать `KanaWardrobe/{InventoryFilters.lua,tests/test_filters.lua}`; подключить UI.lua/Core.lua.

**Interfaces:** `InventoryFilters.New(repo,inventory,session,savedCharacter)->filters`; `filters:SetEnabled(value)`, `filters:IsEnabled()->boolean`, `filters:IsBypassed()->boolean`, `filters:ShouldShow(context,bagId,slotIndex)->boolean`, `filters:Refresh()`, `filters:HiddenCount(context)->integer`. UI-переключатели используют один экземпляр filters.

- [ ] Тесты общей матрицы: backpack; обычный/ESO+ банк withdraw/deposit; house/guild bank обе стороны; NPC sell/repair; fence sell/launder; guildstore sell. Своё скрытие отсекает только UID пресетов текущего персонажа; чужой одноимённый экземпляр и предмет только другого персонажа остаются. BUY/catalog/browse и buyback без UID не сопоставляются по link.
- [ ] Проверить hidden count после штатного поиска, категории, фильтра краденого и стороннего callback; одинаковый UID учитывается один раз. Порядок callback LibFilters не меняет число. Во время preparingEdit/editing/paused/restoring/recovery незавершённого редактора bypass=true, preference не меняется; переключатели всех окон синхронны. Повторная загрузка регистрации не удваивает hooks.

  Ключевой тест `bank_filter_bypasses_during_edit`: для сохранённого кольца `assert(not filters:ShouldShow("bankWithdraw", bag, slot))`; после BeginEdit и паузы `assert(filters:ShouldShow("bankWithdraw", bag, slot))` и `assert(filters:IsEnabled())`. Предварительно включённое preference остаётся true.
- [ ] Запустить `lua KanaWardrobe/tests/run.lua filters`; ожидается FAIL. При LibFilters3 регистрировать свой tag через публичный RegisterFilter для `LF_INVENTORY`, `LF_BANK_WITHDRAW/DEPOSIT`, `LF_GUILDBANK_WITHDRAW/DEPOSIT`, `LF_HOUSE_BANK_WITHDRAW/DEPOSIT`, `LF_VENDOR_SELL/REPAIR`, `LF_FENCE_SELL/LAUNDER`, `LF_GUILDSTORE_SELL`. Нормализовать форму callback через `GetFilterTypeFunctionType`, не предполагать одинаковую форму аргументов. После изменения RequestUpdate, не менять таблицы библиотеки.
- [ ] Без LibFilters использовать instance-обёртку полного `PLAYER_INVENTORY:ShouldAddSlotToList`: сначала оригинальный результат, затем наш предикат для поддерживаемого контекста. Не присваивать `additionalFilter/currentFilter/subFilter`. Для отдельного ремонта фильтровать data list в узкой обёртке `REPAIR_WINDOW:ApplySort` перед штатным sort/commit, с исходными search/condition/cost; не скрывать готовые recycled controls. При LibFilters эти fallback-перехваты для фильтрации не устанавливать.
- [ ] Считать скрытое при обновлении активного контекста, а не увеличивать счётчик из произвольно вызываемого predicate. Для каждого кандидата прогнать полный исходный predicate с локальным reentrancy/count-only bypass нашего фильтра, сохраняя действие остальных. Repair-адаптер использует штатные условия его построителя и остальные зарегистрированные фильтры. Никогда временно не отключать чужие фильтры и не менять глобальное пользовательское preference ради счётчика; объединять частые invalidation в один refresh.
- [ ] Добавить доступную кнопку непосредственно в каждый поддерживаемый банк/магазин, подпись «Скрыть вещи пресетов», состояние и число. Bypass поясняет «При редактировании вещи пресетов показаны». NPC sale/guild deposit могут уже исключать locked items: не обходить штатное правило, не разблокировать ради отображения; такие вещи не прибавляются к нашему hidden count. «Починить всё» остаётся штатным.
- [ ] Повторить `filters`; ожидается PASS. В ESO пройти матрицу окон и смену вкладок, перемещение предмета между сумкой/банком, скролл, очистку поиска, паузу редактора. Отдельно проверяются окружения с LibFilters и без него; библиотеку не устанавливать пользователю молча. При собственном Git: `feat: hide preset items across inventory bank and stores`.

## Task 10: Сборка, сквозная проверка и передача

**Files:** создать `KanaWardrobe/{tests/test_integration.lua,README.md}`; завершить manifest/Core.lua/lang/*.lua/docs/client-validation.md.

**Interfaces:** Core связывает PresetsChanged/InventoryChanged/SessionChanged: обновляет индекс/защиту/список/открытые тултипы/фильтр, объединяя повторные refresh. Диагностика `/kw status` только показывает фазу/проблему/API, не перемещает вещи.

- [ ] Сквозные тесты: создать частичный пресет → Save/restore → Apply с extras → Reject/Confirm → Edit/Save → rename → tooltip/index/filter → delete. Отдельно пропавшая вещь, внешний WW swap, reload после commit, late event в recovery. Проверять итоговые реальные UID fake inventory, количество запросов и сохранённый журнал, а не только вызовы mock-функций.

  Ключевой тест `edit_cancel_restores_confirmed_extras`: после входа через конфликт щита, ручного переодевания и Cancel `assert(Slots.Equal(inventory:Capture().worn, original))`, `assert(repo:Get(id).revision == originalRevision)`, `assert(session:GetView().state == "idle")`.
- [ ] Запустить `lua KanaWardrobe/tests/run.lua integration`; ожидается FAIL на несвязанном сценарии. Подключить недостающие события и обновления, не вводя второго владельца экипировки. После выхода из мира/выгрузки окон снять временные подписки и вернуть штатные anchors. Не скрывать ошибки непрерывным retry.
- [ ] Выполнить `lua KanaWardrobe/tests/run.lua all`; ожидается PASS всего набора. Проверить Lua-файлы через доступный luac и manifest/XML на корректность, отсутствие тестов/временных probe в manifest. Это не заменяет runtime-проверку ESO.
- [ ] Выполнить матрицу живой приёмки из спецификации §12: Apply/Save/Cancel; точные extras; оба оружия/мифик; полная сумка; отсутствие вещи; бой/смерть; вынужденный уход; reload/recovery; карточки/обычные tooltip; скрытие во всех окнах; совместимость с KanaCurrentlyEquipped/KanaInfoBar/WW. Записать для каждого сценария actual/pass/fail/pending и API/version/UI scale. Исправить воспроизведённые дефекты и повторить только затронутые проверки плюс необходимые регрессии.
- [ ] README кратко объясняет три состояния слота, подсчёт только вещей пресета, две панели, дополнительные подтверждения, возврат после Save/Cancel, сохранение замков при удалении, область скрытия и отсутствие автоматического банка. Ограничения: keyboard UI, штатные запрещённые действия, crash persistence, невозможность отменить игровую привязку новой вещи.
- [ ] Зафиксировать финальные результаты: что автоматизировано, что реально проверено в клиенте, что осталось pending. Не объявлять аддон визуально/функционально готовым при незавершённых обязательных клиентских сценариях. При собственном Git: `feat: complete KanaWardrobe integration and acceptance notes`.

## Порядок и критерий окончания

После T1 независимые модули выполняются параллельно отдельными владельцами; зависимости и общие файлы интегрируются последовательно. T6 следует за проверенным движком T3/T4/T5; T7 использует зафиксированный контракт редактора. T10 собирает модули и проверяет полный цикл. Модельные части можно продолжать, пока ожидается доступ к клиентской проверке, но неподтверждённый tooltip/примитив экипировки нельзя объявлять проверенным в игре.

При доступе к ESO сначала проверить две карточки, затем несколько перемещений с возвратом снимка, затем редактор и весь интерфейс. Доступ к приложению при реализации не разрешён, поэтому эти проверки остаются отдельным обязательным этапом; автоматические тесты их не заменяют.

Покрытие требований спецификации: модель/идентичность §§1–3 → T1; UI §4 → T7; сеты §5 → T2; применение §6 → T3/T4/T6; редактор/восстановление §§7–8 → T6/T7; замки §9 → T5; принадлежность/скрытие §10 → T8/T9; техническая интеграция/приёмка §§11–12 → T10. Исправления пользователя о согласии на незаданные слоты, обычных тултипах и банке/магазине включены отдельными проверками.

Пользователь выбрал реализацию через субагентов с ограниченным параллелизмом и последовательной интеграцией. После общей основы независимые владельцы работают над переодеванием, сетами и защитой; общие API меняет один владелец. Редактор и UI собираются после проверки зависимостей. Прогресс и исправления контрактов записываются в журнал; каждый модуль и итоговая сборка проходят независимую проверку.
