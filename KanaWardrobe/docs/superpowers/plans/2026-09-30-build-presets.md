# KanaWardrobe Build Presets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Один необязательный пресет экипировки, навыков с двумя панелями и цельного распределения атрибутов; редактор текущего компонента и общий полный квиксейв/квиклоад на трёх родных страницах.

**Architecture:** Три части билда имеют независимые данные. Полный Apply/QuickLoad использует одну предварительную проверку всех включённых частей и последовательный журнал. Редактор принадлежит только компоненту текущей страницы и сохраняет остальные части; ухода с переносом draft нет. Навыки/панели и атрибуты подтверждаются отдельными серверными запросами. Существующий исполнитель экипировки и расчёт эффектов сохраняются.

**Tech Stack:** ESO Lua/XML, документированное API и штатные менеджеры/контролы; существующий Lua harness `tests/run.lua`. Новых обязательных библиотек нет.

**Spec:** `docs/superpowers/specs/2026-09-30-build-presets-design.md`.

## Global Constraints

- Один пресет имеет три части: `equipment`, `abilities` с `skills`/`bars`, `attributes`; отсутствие части означает «не менять».
- Атрибуты выбираются целиком одним переключателем; сохраняются три абсолютных неотрицательных целых значения, включая нули.
- Новые заработанные очки атрибутов остаются свободными; сохранённая тройка не масштабируется.
- Не меняем выбранные ветки подклассов. Не добавляем CP, Мундус, проклятия, спутника, быстрые слоты, стили навыков или переписывание скриптов начертания.
- Управляем прежними 14 слотами вещей и двумя обычными панелями игрока по шесть слотов.
- Нехватка очков навыков или атрибутов отменяет применение до любого реального изменения.
- Обычная галочка включает состояние в сохранение; сама ничего не покупает, не назначает и не снимает.
- Галочки вещей/навыков/слотов панелей — внутри правого верхнего угла иконки, без изменения её родных размеров и положения.
- Список остаётся частью родного фона: инвентарь и персонаж расширяются вправо, навыки — влево; вертикальные градиенты не растягиваются.
- Описание — одна компактная страница без вкладок; уход курсора не закрывает, постоянный крестик закрывает.
- Не переписываем защищённые штатные функции использования/перемещения предметов и действия основной кнопки инвентаря.
- Не редактировать никакие другие аддоны, особенно Wizard’s Wardrobe. Сохранить все нынешние незакоммиченные изменения KanaWardrobe.
- Поддержка новых компонентов определяется доступностью родных API/менеджеров; при их отсутствии экипировка продолжает работать, новый компонент сообщает о недоступности.
- Не увеличивать `ZO_SavedVars` version с 1: это отдельное от внутреннего `schemaVersion` значение, изменение которого может сбросить настройки.
- Реальные операции и геометрию принимаем только после проверки в ESO; Lua mocks не воспроизводят защищённость стека.

## Review Focus

1. Родные `OnHidden` и диалоги ухода остаются штатными: переход завершает текущий editor без переноса draft и Send. Owned cleanup не допускает dirty auto-send; чужие pending edits не удаляются — задачи 3, 7, 8.
2. Родная покупка сама пытается заполнить панель: незаданный пустой слот не должен получить новый навык без согласия — задачи 3 и 5.
3. Уровень/ветки и разные бюджеты изменяются после сохранения: новые свободные атрибуты, стоимость подкласса и Class Mastery должны считаться отдельно — задачи 3–5.
4. Предмет переопределяет ульту, а отключение навыка затрагивает специальную панель: итог проверяется на уровне целого билда, без скрытого удаления — задачи 5 и 6.
5. Позднее событие без ID запроса и возврат штатного режима к немедленной покупке могут вызвать повторную отправку: требуется сверка фактического состояния и подавление собственных повторов — задачи 6–8.

## Исходная точка, типы и зависимости

Рабочая база — **нынешнее дерево файлов**, не только HEAD: предыдущие изменения кода ещё не закоммичены. На 2026-09-30 `lua tests/run.lua all` подтвердил **290 passed; 0 failed**. Этот результат не подтверждает возможность новых серверных операций.

Перед созданием изолированного рабочего дерева сохранить проверенную текущую версию KanaWardrobe отдельным базовым коммитом, просматривая только пути этого репозитория. Нельзя начать от старого HEAD и потерять текущие `EffectModel.lua`, `SummaryView.lua`, `SoftPanel.lua`, `PreviewTooltips.lua`, ассеты, тесты и правки исполнителя. Не использовать `reset`, `clean`, `stash` с удалением работы.

Общие типы (все сериализуемы; функции, контролы и родные объекты в SavedVariables не попадают):

- `EquipmentMap`: прежняя карта `{[equipSlot]={kind="item",uid,link}|{kind="empty"}}`.
- `SkillKey`: строка `lineId:kind:id`, где `kind=active|passive|crafted`; активный `id` — progression ID, пассивный — устойчивый ID базовой способности, crafted — crafted ability ID.
- `SkillState`: `{kind="active",purchased=false}` либо `{kind="active",purchased=true,morph=0|1|2}`; пассивка `{kind="passive",rank=N}`. Автовыдаваемые неизменяемые способности не включаются как продаваемые. Ключи `crafted` используются только в назначениях панелей; состояние их скриптов и покупок не включается в карту `skills`.
- `BarMap`: `{front={[1..6]=BarRef},back={[1..6]=BarRef}}`; `BarRef={kind="empty"}` или `{kind="skill",skillKey,expectedMorph}`. Логические слоты 1–6 переводятся в родные индексы через API, не смешиваются с equipSlot.
- `Attributes`: `{health=N,magicka=N,stamina=N,unspentAtCapture=N?}`; последнее поле — информация снимка, не цель применения.
- `Build`: `{equipment=EquipmentMap?,abilities={skills={[SkillKey]=SkillState}?,bars=BarMap?}?,attributes=Attributes?}`.
- `BuildSnapshot`: полный `Build` плюс `{budgets={skills=N,mastery={[lineId]=N},attributes=N},catalogueRevision=N}`; доступность/стоимость берётся из актуального каталога адаптера.
- `Selection`: `{equipment={[slot]=bool},skills={[SkillKey]=bool},bars={front={[1..6]=bool},back={[1..6]=bool}},attributes=bool}`.
- `Problem`: существующее `{code,details}`; новые коды локализуются через `KW.Text`/`Dialogs.Problem`.
- `BuildPlan`: `{target=BuildSnapshot,equipmentPlan,skillRequest?,attributeRequest?,extras={},fingerprint}`; `extras` имеет устойчивые ключи и конкретные позиции/названия.

Репозиторий возвращает нормализованный `Build` и временный совместимый `.slots`-вид экипировки для старых читателей. В SavedVariables хранится только канонический `equipment`; дублирование двух независимых карт запрещено. Запись через старый вызов `Repo:Save({slots=...})` сохраняет остальные части уже существующего пресета.

Зависимости: **1 → 2 → {3, 4} → 5 → 6 → 7 → 8 → 9 → 10 → 11 → 12**. Адаптеры в задачах 3 и 4 можно выполнять параллельно после задачи 2, если выбран такой способ исполнения. Они не меняют общие Core/manifest/Session; интеграция принадлежит задачам 7–9. Сборка UI и описание идут после стабильного редактора текущего компонента.

## Карта файлов

| Файл | Ответственность |
|---|---|
| `BuildCapabilities.lua` | Доступность API и проверка предпосылок интеграции |
| `BuildModel.lua` | Схема, сравнение, нормализация, маски и выбор сохраняемого |
| `SkillState.lua` | Каталог навыков, устойчивые ключи, ранги/морфы и бюджеты |
| `SkillAdapter.lua` | Родной черновик навыков/панелей, подготовка и отправка пакета |
| `AttributeAdapter.lua` | Тройка и бюджет атрибутов, спиннеры, дельты/запрос |
| `BuildPlanner.lua` | Проверка целого билда, зависимости и согласие |
| `BuildRunner.lua` | Последовательность подтверждений навыки → атрибуты → вещи |
| `BuildDraft.lua` | Draft и выбор только текущего компонента, без переноса между страницами |
| `BuildJournal.lua` | Журналы версий 1/2, подтверждённые фазы и восстановление |
| `PageAdapters.lua` | Геометрия и lifecycle трёх родных страниц |
| `SelectionOverlay.lua` | Общая галочка внутри иконки, включая pooled controls |
| `BuildDescription.lua` | Сохранённые атрибуты, панели и сетки иконок для описания |
| `Presets.lua`, `Session.lua`, `Core.lua` | Встраивание новых компонентов в нынешние контракты |
| `UI.lua`, `UI.xml`, `Dialogs.lua` | Общий список, действия редактора и подтверждения |
| `SetPreview.lua`, `SummaryView.lua` | Одна страница описания и постоянный крестик |
| `SetModel.lua`, `Protection.lua`, `InventoryFilters.lua`, `ItemTooltips.lua` | Адаптация чтения нормализованной экипировки, сохранение прежнего поведения |

### Task 1: Проверить путь нативных запросов до расширения системы

**Files:** Create `BuildCapabilities.lua`, `tests/test_build_capabilities.lua`; Modify `Core.lua`, `KanaWardrobe.txt`, `docs/client-validation.md`.

**Interfaces:** `KW.BuildCapabilities.Read(api) -> {skills=bool,attributes=bool,problems={}}`. Диагностика возвращает наличие нужных функций/менеджеров и фактическую версию API; сама не меняет билд.

- [ ] **Step 1:** Добавить `capabilities_missing_respec_api_preserves_equipment` и `capabilities_read_never_sends_requests`:
  ```lua
  api.StartAttributeRespecFromUI=nil
  local c=KW.BuildCapabilities.Read(api)
  assert(not c.attributes and c.skills)
  assert(#api.requests==0 and #api.skillRequests==0 and #api.attributeRequests==0)
  ```
- [ ] **Step 2:** `lua tests/run.lua build_capabilities` → FAIL из-за отсутствующего модуля.
- [ ] **Step 3:** Реализовать чтение capabilities. В диагностике перечислить `StartSkillRespecFromUI`, `PrepareSkillPointAllocationRequest`, `SendSkillPointAllocationRequest`, `SendAttributePointAllocationRequest`, getters атрибутов и родные менеджеры; не менять распределение на загрузке аддона.
- [ ] **Step 4:** Клиентский gate уже подтвердил raw attributes из inventory, native skill entry → event FULL/Gold + manager readiness на следующем tick → один пакет и точный обратный пакет с 12 назначениями, `result=0`, `verified=true`. Сырой skill пакет без entry получил result14 и исключён. Entry открывает Skills; неизменность исходной сцены не требуется. Обратные attributes подтверждены косвенно очищением журнала, отдельный отчёт не предоставлен. Batch skills=2/attributes=1 вошёл без Send; Skills→Stats→Inventory→Skills вернул оба режима в 0 и показал native cancel dialogs даже без edits. Пользователь принял раздельный editor вместо общего переносимого draft. **Остался уже запрошенный `/kw probe reset`** с проверкой очистки диагностического batch; после этого gate завершён. Полная UI/page/build матрица относится к Task12 и не требует повторять дорогие manual morph probes. Никаких вызовов на загрузке, защищённых wrappers или подавления штатных callbacks.
- [ ] **Step 5:** `lua tests/run.lua build_capabilities`, `lua tests/run.lua integration` → 0 failed. Коммит только перечисленных файлов: `test: verify native build allocation capabilities`.

### Task 2: Ввести три компонента и миграцию без потери экипировки

**Files:** Create `BuildModel.lua`, `tests/support/build_fixture.lua`, `tests/test_build_model.lua`; Modify `Presets.lua`, `tests/test_foundation.lua`, `KanaWardrobe.txt`.

**Interfaces:** `KW.BuildModel.Normalize(preset) -> preset|nil,Problem?`; `Select(build,selection) -> Build`; `Matches(actual,target) -> bool`; `Merge(actual,partial) -> Build`; `Equipment(preset) -> EquipmentMap`. `Repo:Get/List/Save/NewDraft` сохраняют прежние сигнатуры; `Repo:SaveQuick(build)` принимает новый Build и распознаёт прежний вход EquipmentMap. Fixture `BuildFake.New()` предоставляет `api`, раздельные очереди запросов, часы, каталог, явное подтверждение/ошибки и перезагрузку сохранённого журнала.

- [ ] **Step 1:** Написать `legacy_slots_migrate_without_new_parts`, `gear_update_preserves_abilities_and_attributes`, `missing_attributes_differ_from_explicit_zero_triple`:
  ```lua
  assert(KW.BuildModel.Matches(actual,{attributes=nil}))
  assert(not KW.BuildModel.Matches(actual,{attributes={health=0,magicka=0,stamina=0}}))
  local migrated=assert(KW.BuildModel.Normalize(legacy))
  assert(migrated.equipment[EQUIP_SLOT_RING1].uid=="ring-A")
  assert(migrated.abilities==nil and migrated.attributes==nil)
  ```
- [ ] **Step 2:** `lua tests/run.lua build_model` → ожидаемый FAIL новых контрактов.
- [ ] **Step 3:** Реализовать внутреннюю схему 2 без изменения ZO_SavedVars version; миграцию всех персонажей аккаунта, анонимного пресета и membership index. Зафиксировать false/zero против nil. Проверять ранги/морфы и целочисленные атрибуты; пустой пресет не сохраняется. Новый component patch задачи 7 различает preserve от remove; удаление не выводится из отсутствующего поля или старого `.slots` вызова.
- [ ] **Step 4:** `lua tests/run.lua build_model`, `lua tests/run.lua foundation`, `lua tests/run.lua filters`, `lua tests/run.lua tooltips` → 0 failed; отдельно проверить lock/membership старого квиксейва и отсутствие дубля `.slots` в сохранённом контейнере.
- [ ] **Step 5:** Коммит файлов задачи: `feat: add optional build components and migrate presets`.

### Task 3: Каталог и штатный черновик навыков с панелями

**Files:** Create `SkillState.lua`, `SkillAdapter.lua`, `tests/test_skill_adapter.lua`; Extend `tests/support/build_fixture.lua` только нативными skill mocks. Общие Core/manifest здесь не менять.

**Interfaces:** `KW.SkillState.Read(api) -> catalogue` с `byKey`, доступностью, рангами, morph unlock и стоимостью; `KW.SkillAdapter.New(api,events,clock?) -> adapter`; `adapter:Capture() -> abilities,budgets,catalogueRevision`; `Prepare(current,target,catalogue) -> request|nil,Problem?`; `MountDraft(abilities,changed) -> true|nil,Problem?`; `CaptureDraft() -> abilities`; `UnmountDraft()`, `DiscardDraft()`; `Submit(request) -> true|nil,Problem?` (true означает async accepted, не server success); `GetSubmissionState() -> {phase,problem?}`, `CancelSubmission()`; `Matches(target) -> bool`. Mount не отправляет запросы, Submit не активирует чужие черновики. Adapter владеет bounded ENTRY 5 секунд: один Start, event FULL/Gold и manager readiness на следующем tick, exact captured actual и pending/cast/session guards, затем один Send. Coordinator владеет журналом whole-apply и result+actual ожиданием 15 секунд после Send. Bars-only не входит в FULL.

- [ ] **Step 1:** Тесты `skill_keys_survive_list_reordering`, `passive_target_is_purchased_rank_not_xp`, `subclass_cost_and_mastery_are_separate`, `mount_draft_does_not_autopurchase_or_autofill`, `unavailable_crafted_scripts_are_not_changed`:
  ```lua
  assert(request.pointDelta==4) -- два изменения по 2 очка в чужой ветке
  assert(request.masteryDelta[masteryLine]==1)
  assert(#api.skillRequests==0) -- после MountDraft
  assert(adapter:CaptureDraft().bars.front[2].kind=="empty")
  ```
- [ ] **Step 2:** `lua tests/run.lua skill_adapter` → FAIL отсутствующих адаптеров.
- [ ] **Step 3:** Реализовать логические слоты 1–6 через native assignable indices. В редакторе переключать только собственный режим на batch, сначала возвращать очки выбранных уменьшений, потом собирать покупки/ранги/морфы и точные назначения. Восстановить нежелательное автозаполнение родного менеджера к рассчитанной карте панелей. Подавлять обратное чтение при собственной гидратации; не менять ветки/скрипты/XP. Bar-only пакет не вводит полный respec. Owned discard использует native ResetRespecState/ResetInterface и callbacks allocator/bar pending. Только для собственного текущего компонента, с отказом чужих pending на входе, разрешено синхронно очистить manager.isDirty до/после reset; проверить отсутствие всех pending перед PURCHASE_ONLY. Неопределённая очистка оставляет FULL с ошибкой и frozen hydration, без auto-send. ApplyChanges нельзя использовать для discard (безусловный Send). Тестировать source-shaped cleanup, чужой pending, dirty reset и отсутствие позднего auto-save; private доступ шире этого не разрешён.
- [ ] **Step 4:** `lua tests/run.lua skill_adapter` → 0 failed; включить один навык на двух барах, один морф на двух барах, explicit unpurchase, locked backup bar, auto-granted и Cryptcanon override. Отдельно проверить native userdata и запрет покупки при чужом pending state.
- [ ] **Step 5:** Коммит файлов задачи: `feat: adapt native skill drafts and action bars`.

### Task 4: Цельные атрибуты и их отдельный черновик

**Files:** Create `AttributeAdapter.lua`, `tests/test_attribute_adapter.lua`; Extend `tests/support/build_fixture.lua` только stats mocks. Общие Core/manifest здесь не менять.

**Interfaces:** `KW.AttributeAdapter.New(api,events) -> adapter`; `Capture() -> Attributes,budget`; `Prepare(current,target,budget) -> {target,deltas,remaining}|nil,Problem?`; `MountDraft(attributes,changed)`, `CaptureDraft() -> Attributes`, `UnmountDraft()`, `DiscardDraft()`, `Submit(request) -> true|nil,Problem?`, `Matches(target) -> bool`.

- [ ] **Step 1:** Тесты `absolute_targets_produce_signed_deltas`, `zero_triple_returns_points`, `level_up_leaves_extra_points_unspent`, `attrs_budget_never_uses_skill_points`, `stats_mount_never_calls_purchase`:
  ```lua
  local q=assert(adapter:Prepare({health=10,magicka=20,stamina=34},
      {health=0,magicka=0,stamina=64},66))
  assert(q.deltas.health==-10 and q.deltas.magicka==-20 and q.deltas.stamina==30)
  assert(q.remaining==2)
  assert(#api.attributeRequests==0)
  ```
- [ ] **Step 2:** `lua tests/run.lua attribute_adapter` → FAIL нового модуля.
- [ ] **Step 3:** Читать бюджет как сумму трёх spent getters и `GetAttributeUnspentPoints()`. Работать с `STATS.attributeControls[type].pointLimitedSpinner` в FULL batch mode; `SetAddedPointsByTotalPoints` принимает абсолютную цель, а `addedPoints`/`GetAllocatedPoints` в запросе — дельты. Hydrate сначала уменьшаемые значения, затем увеличиваемые. Не вызывать `STATS:PurchaseAttributes()`, который может сменить сцену.
- [ ] **Step 4:** `lua tests/run.lua attribute_adapter` → 0 failed; дополнительно отклонить отрицательные/дробные значения, сумму 65 при бюджете 64, и принять 0/0/0. Проверить own discard/reset и отсутствие отправки; draft не переносится в другую сцену.
- [ ] **Step 5:** Коммит файлов задачи: `feat: adapt whole attribute allocation drafts`.

### Task 5: Предварительная проверка и согласие на зависимости

**Files:** Create `BuildPlanner.lua`, `tests/test_build_planner.lua`; Modify `Dialogs.lua`, `lang/ru.lua`, `lang/en.lua`.

**Interfaces:** `KW.BuildPlanner.Build(snapshot,preset,catalogue,capabilities) -> BuildPlan|nil,Problem?`; `Revalidate(plan,snapshot,catalogue) -> BuildPlan|nil,Problem?`. Consumes BuildModel, SkillAdapter.Prepare, AttributeAdapter.Prepare и прежний `EquipmentPlan.Build`. `extras` содержит тип, SkillKey/UID, категорию/слот, before/after и устойчивый ключ согласия.

- [ ] **Step 1:** Тесты `skills_deficit_blocks_every_domain`, `attributes_deficit_blocks_every_domain`, `unselected_bar_clear_requires_specific_consent`, `morph_change_lists_all_affected_unselected_slots`, `override_ultimate_uses_target_equipment`:
  ```lua
  local p,err=planner.Build(snapshot,tooExpensive,catalogue,caps)
  assert(p==nil and err.code=="insufficientSkillPoints" and err.details.deficit==2)
  assert(#api.requests==0 and #api.skillRequests==0 and #api.attributeRequests==0)
  assert(plan.extras[1].bar=="front" and plan.extras[1].slot==3)
  ```
- [ ] **Step 2:** `lua tests/run.lua build_planner` → FAIL нового планировщика.
- [ ] **Step 3:** Слить только заданные позиции с текущим билдом. Не продавать незаданные навыки ради бюджета. Проверять ожидаемые морфы, ульту, прогресс, доступность веток и оба бюджета. Добавлять зависимые очищения special bars в подтверждение, даже если такие бары не являются сохраняемой частью. Если ревизия/зависимости изменились, старое согласие не подходит.
- [ ] **Step 4:** `lua tests/run.lua build_planner` → 0 failed; добавить отказ для одного progression с разными морфами, unpurchased бар-only, изменившегося бюджета/подкласса и ручного движения UID после согласия. Согласие не делает недоступный навык доступным.
- [ ] **Step 5:** Коммит файлов задачи: `feat: preflight complete builds and confirm dependencies`.

### Task 6: Последовательное применение без повторных запросов

**Files:** Create `BuildRunner.lua`, `tests/test_build_runner.lua`; Modify `EquipmentRunner.lua` только если нужен дополнительный callback, с сохранением его нынешних тестов.

**Interfaces:** `KW.BuildRunner.New(skillAdapter,attributeAdapter,equipmentRunner,events,clock) -> runner`; `Start(plan,onProgress,onDone) -> true|nil,Problem?`; `IsBusy() -> bool`; `Stop(reason)`. Результат `{status="applied"|"failed"|"paused",phase,confirmed={},actual,problem?,pending?}`. Consumes adapters Submit/Matches; equipment Runner.Start; clock NowMs/Schedule/Cancel.

- [ ] **Step 1:** Тесты `attributes_start_only_after_verified_skills`, `gear_starts_only_after_verified_attributes`, `late_success_event_does_not_confirm_wrong_target`, `native_reset_does_not_echo_submission`, `noop_has_no_respec`:
  ```lua
  runner:Start(plan,progress,done)
  assert(#api.skillRequests==0) -- async entry accepted, packet ещё не отправлен
  fixture:EmitSkillEntryFullGold(); clock:Advance(100)
  assert(#api.skillRequests==1 and #api.attributeRequests==0 and #api.requests==0)
  fixture:EmitSkillSuccessWithoutChangingActual()
  assert(#api.attributeRequests==0)
  fixture:ConfirmSkills()
  assert(#api.attributeRequests==1 and #api.requests==0)
  ```
- [ ] **Step 2:** `lua tests/run.lua build_runner` → FAIL нового исполнителя.
- [ ] **Step 3:** Один активный phase token, подписки на соответствующие события и проверка реального целевого состояния. Навыки → атрибуты → вещи; пропуск неизменных фаз. Adapter skill ENTRY ограничен 5 секундами и не считается отправленным пакетом; true Submit означает async accepted. Coordinator ждёт result+actual до 15 секунд после фактического Send, читая GetSubmissionState и отменяя только собственную незавершённую entry при Stop; повторного Start/Send нет. Сверку можно повторять таймером, отправку нельзя. Собственная гидратация заморожена при подтверждении, чтобы native reset не включил auto-save. После каждой фазы перечитать состояние и доступность оставшихся действий.
- [ ] **Step 4:** `lua tests/run.lua build_runner`, `lua tests/run.lua runner` → 0 failed; проверить ошибку атрибутов после skills success, бой между фазами, отключённое оружие/ультимейт, таймаут с поздним фактическим успехом и единственную отправку. Все timers/subscriptions сняты после terminal result.
- [ ] **Step 5:** Коммит файлов задачи: `feat: coordinate verified build application phases`.

### Task 7: Редактор текущего компонента, три завершения и полный квиксейв

**Files:** Create `BuildDraft.lua`, `tests/test_build_editor.lua`; Modify `Session.lua`, `Core.lua`, `Presets.lua`, `Protection.lua`, `KanaWardrobe.txt`, `tests/test_editor.lua`, `tests/test_integration.lua`.

**Interfaces:** `KW.BuildDraft.New(original,preset,page) -> draft` владеет только component для inventory→equipment, skills→abilities, stats→attributes. `SetValue(domain,key,value)`, `SetSelected(domain,key,bool)`, `SetAttributesEnabled(bool)` отклоняют чужой domain; `GetBuild() -> Build` возвращает весь эксперимент текущей части, `GetSelection() -> Selection`, `GetPresetBuild() -> Build` — выбранную часть. Добавить `Repo:PatchComponent(id,component,patch,name,expectedRevision) -> preset|nil,Problem?`, где component=`equipment|abilities|attributes`; patch=nil сохраняет часть, `{op="replace",value=Component}` заменяет, `{op="remove"}` явно удаляет. Для new preset id=nil и expectedRevision=nil; для existing требуется текущая revision, конфликт отказывает без записи. Name меняется независимо. После merge отвергать полностью пустой пресет; неотмеченная целиком текущая часть даёт remove, не скрытую потерю остальных. Legacy `Repo:Save({slots=...})` продолжает сохранять другие компоненты. `Session.New` получает необязательный девятый services; старые восемь сохраняются. `BeginNew(page?)`, `BeginEdit(id,allowMissing,page?)`, Apply/Save/Cancel/QuickSave/QuickLoad сохраняют прежние вызовы; `SaveAndApply()` добавляется. GetView содержит page/component/selection/draft/attributesEnabled, старую gear `.selected` сохраняет.

- [ ] **Step 1:** Тесты `save_current_component_preserves_other_parts`, `nil_patch_preserves_explicit_remove_deletes`, `save_discards_current_native_draft_without_reverse_respec`, `gear_save_restores_only_gear`, `save_apply_confirms_current_unselected_experiment_only`, `new_preset_contains_only_current_part`, `empty_after_merge_is_rejected`, `quick_capture_includes_explicit_zeros_and_all_three_parts`, `attributes_checkbox_controls_whole_component`. Проверить снятие attributes checkbox у смешанного пресета: attributes удалены, equipment/abilities остаются; у единственной части отказ пустого результата.
- [ ] **Step 2:** `lua tests/run.lua build_editor` → FAIL новых действий.
- [ ] **Step 3:** Снимок current component до preview, проверка его полного эксперимента до мутации. Batch включён только для соответствующего editor. Save пишет selected component+name, отбрасывает own native draft, gear восстанавливает только в gear editor; Cancel не пишет и делает такой же own discard. SaveAndApply сначала сохраняет selected component+UID protection, затем подтверждает весь current component incl unselected edits; остальные actual components не применяет. Ошибка server оставляет запись и явное исправляемое состояние. QuickSave всегда захватывает все actual parts и запрещён при собственном/чужом editor; full Apply/QuickLoad сохраняет whole-budget preflight всех included parts.
- [ ] **Step 4:** `lua tests/run.lua build_editor`, `lua tests/run.lua editor`, `lua tests/run.lua integration`, `lua tests/run.lua foundation` → 0 failed. Проверить patch preserve/remove, legacy gear writes, name, revision conflict, unresolved current references, чужие pending, полный current experiment budget и отсутствие вызовов других adapters при SaveAndApply.
- [ ] **Step 5:** Коммит файлов задачи: `feat: edit preset components and preserve other parts`.

### Task 8: Журнал текущего редактора, выход страницы и ограниченное восстановление

**Files:** Create `BuildJournal.lua`, `tests/test_build_recovery.lua`; Modify `Session.lua`, `Core.lua`, `SkillAdapter.lua`, `AttributeAdapter.lua`, `tests/test_editor.lua`.

**Interfaces:** `KW.BuildJournal.Read(savedJournal,repo) -> journal|nil,Problem?`; `Write(savedCharacter,journal)`; `Reconcile(journal,actual) -> {confirmed,remaining,unresolved}`. Version2 различает operation=`editor|apply`: editor хранит page/component/original/target/draft/selection только своей части; apply хранит полный original/target и подтверждённые фазы. Version1 сохраняет equipment recovery. `Session:SwitchPage(nextPage) -> true|nil,Problem?` выполняет уход через текущий exit/discard/continue lifecycle, не переносит draft. `Recover(action,expectedKey)` сначала сверяет actual, автоматической гидратации/Send нет.

- [ ] **Step 1:** Тесты `all_six_page_transitions_end_current_editor_without_submission`, `native_continue_keeps_original_page_editor`, `page_leave_does_not_clear_foreign_pending`, `owned_dirty_cleanup_never_autosends`, `reload_after_skills_before_attributes_reconciles_actual`, `legacy_journal_remains_equipment_only`, `blocked_recovery_has_reason_without_retry_loop`, `late_attribute_success_finishes_exact_target`. После успешного ухода view idle/new page, прежний draft не монтируется; Continue остаётся на исходной странице; skills/attrs Send=0 при уходе.
- [ ] **Step 2:** `lua tests/run.lua build_recovery` → FAIL журнала/выходов.
- [ ] **Step 3:** Сохранять own journal до native mutation. Page leave заканчивает editor, native discard/continue допускается; не перехватывать/подавлять OnHidden/ConfirmHide и не восстанавливать draft на новой странице. Gear сохраняет прежний Save/Cancel/Continue. Owned cleanup соблюдает Task3 синхронный dirty/reset контракт; чужие edits не очищать. После reload сверять actual и предлагать component recovery отдельно от whole-apply recovery; no auto-send/no auto-mount. Cooldown не оставляет фиктивный active request.
- [ ] **Step 4:** `lua tests/run.lua build_recovery`, `lua tests/run.lua editor`, `lua tests/run.lua integration` → 0 failed. Проверить reload committing/save-before-send, repeated recovery, повреждённый журнал, новые points/skills, каждый page exit и отсутствие общего carry. Uncertain cleanup остаётся frozen FULL/error без auto-save.
- [ ] **Step 5:** Коммит файлов задачи: `feat: journal component editors and native page exits`.

### Task 9: Один список на трёх штатных страницах

**Files:** Create `PageAdapters.lua`, `tests/test_build_pages.lua`; Modify `UI.lua`, `UI.xml`, `Core.lua`, `Dialogs.lua`, `KanaWardrobe.txt`, `lang/ru.lua`, `lang/en.lua`, `tests/test_ui.lua`, `tests/test_dialog_layout.lua`.

**Interfaces:** `KW.PageAdapters.New(api) -> pages`; `pages:Get(page) -> {scene,root,side,background}`; `Mount(page,session)`, `Unmount(page)`, `Bounds(page) -> {list,description}`, `SetBackgroundExpanded(page,bool)`. UI остаётся одним контроллером с shared preset data/order/Quick snapshot и командами Session. Список общий по данным; active editor ограничен текущим компонентом, сессия между страницами не переносится.

- [ ] **Step 1:** Тесты `all_pages_share_order_quickslot_and_editor_commands`, `native_background_width_is_restored_per_scene`, `stats_advanced_panel_does_not_overlap_presets`, `save_apply_buttons_remain_present_while_busy`:
  ```lua
  assert(modelInventory.rows[1].id==modelStats.rows[1].id)
  assert(modelSkills.quickId==modelStats.quickId)
  assert(before.nativeSlotAnchors==after.nativeSlotAnchors)
  assert(buttons.save:IsHidden()==false and buttons.saveAndApply:IsHidden()==false)
  ```
- [ ] **Step 2:** `lua tests/run.lua build_pages` → FAIL новой привязки страниц.
- [ ] **Step 3:** Inventory: `ZO_Character` / `ZO_SharedWideLeftPanelBackground`; skills: `ZO_Skills` / `ZO_SharedRightBackground`; stats: `ZO_StatsPanel` / `ZO_SharedStatsBackground`. Менять только необходимую ширину фона, восстанавливать при уходе; bounds учитывать родные текстуры и advanced stats, не двигать native roots. Quick-кнопки остаются на месте, недоступны пока editor активен. Добавить постоянное SaveAndApply и один `attributesEnabled` переключатель в существующем редакторе без дополнительной строки у трёх спиннеров. Совпадение слева проверяет все заданные части; новый пресет остаётся в конце.
- [ ] **Step 4:** `lua tests/run.lua build_pages`, `lua tests/run.lua ui`, `lua tests/run.lua dialog_layout`, `lua tests/run.lua geometry` → 0 failed. Инициализация нескольких сцен, банковская сцена и восстановление общих фонов не должны оставлять расширение для чужих окон.
- [ ] **Step 5:** Коммит файлов задачи: `feat: show shared preset controls on three native pages`.

### Task 10: Галочки внутри иконок без изменения геометрии

**Files:** Create `SelectionOverlay.lua`, `tests/test_selection_overlays.lua`; Modify `UI.lua`, `PageAdapters.lua`, `tests/test_geometry.lua`, `tests/support/geometry_controls.lua`.

**Interfaces:** `KW.SelectionOverlay.New(parent,resolveKey,onToggle) -> overlay`; `Bind(control,resolveKey)`, `SetSelected(bool)`, `SetEnabled(bool)`, `Destroy()`. resolveKey читает актуальный native row/slot; onToggle вызывает только Session selection action. Размер 18×18, anchor TOPRIGHT внутри icon с отступом 1.

- [ ] **Step 1:** Тесты `overlay_inside_every_equipment_icon`, `pooled_skill_row_uses_current_key`, `checkbox_click_does_not_equip_purchase_or_drag`, `editing_does_not_move_jewellery_or_weapons`:
  ```lua
  assert(check:GetRight()<=icon:GetRight() and check:GetTop()>=icon:GetTop())
  fixture:ReuseRow("skill-A","skill-B"); fixture:ClickCheckbox()
  assert(selection.skills["skill-B"] and not selection.skills["skill-A"])
  assert(#api.requests==0 and #api.skillRequests==0)
  ```
- [ ] **Step 2:** `lua tests/run.lua selection_overlays` → FAIL отсутствующего overlay.
- [ ] **Step 3:** Штатная золотая галочка, небольшое тёмное основание, без зелёной рамки. Выбор читается при click по текущему ключу, а не захваченному ключу pooled row. Во время активного редактора лёгкая проверка ключа на собственном overlay обновляет повторно используемые строки; не сканировать инвентарь/каталог на кадре. Не оборачивать native purchase/action functions. Удалить вертикальные сдвиги `SetEditorLayout`, прежние внешние anchors. Вне редактора убрать overlays и transient updates.
- [ ] **Step 4:** `lua tests/run.lua selection_overlays`, `lua tests/run.lua geometry`, `lua tests/run.lua ui` → 0 failed; проверить empty icons, ults, hidden/reused rows, масштаб UI и прямой drag по свободной части иконки.
- [ ] **Step 5:** Коммит файлов задачи: `fix: place preset selection inside native icons`.

### Task 11: Одна компактная страница описания, включая атрибуты и навыки

**Files:** Create `BuildDescription.lua`, `tests/test_build_description.lua`; Modify `SetPreview.lua`, `SummaryView.lua`, `UI.lua`, `SetModel.lua`, `KanaWardrobe.txt`, `tests/test_sets.lua`, `tests/test_tooltips.lua`, `tests/test_geometry.lua`.

**Interfaces:** `KW.BuildDescription.Build(preset,catalogue) -> {attributes?,bars?,enabled={},disabled={},equipmentSummary?}`; `Layout(data,width) -> height` в SummaryView. Экипировка идёт через существующий SetModel/EffectModel. Preview получает `Close()`, сохраняет существующие Show/Hide, и больше не скрывается из UI.Leave.

- [ ] **Step 1:** Тесты `description_has_one_page_and_omits_absent_components`, `enabled_and_disabled_are_icons_with_native_tooltips`, `attributes_zero_values_are_points_not_resource_bonuses`, `pointer_leave_does_not_close`, `close_invalidates_pending_hover`:
  ```lua
  local d=KW.BuildDescription.Build(preset,catalogue)
  assert(#d.enabled==2 and #d.disabled==1 and d.tabs==nil)
  assert(d.attributes.health==0 and d.attributes.stamina==64)
  ui:Leave(); assert(not preview.control:IsHidden())
  preview:Close(); clock:Advance(1000); assert(preview.control:IsHidden())
  ```
- [ ] **Step 2:** `lua tests/run.lua build_description` → FAIL нового описания.
- [ ] **Step 3:** Постоянный header/title/крестик и один scroll body. Порядок блоков — spec §9. Skills grid: квадратные иконки 28×28 с зазором 4; две полосы по шесть назначений, 32×32 и зазор 4, рядом при достаточной ширине или друг под другом при узкой. Native tooltips показывают сохранённый морф/ранг, inactive state и unresolved reason. Атрибуты имеют подпись «Очки атрибутов», цвета/иконки ресурсов и все три числа; не суммируются со сводкой бонусов вещей. Не создавать пустую колонку под короткие блоки. Задержка hover и существующая мягкая анимация сохраняются; Close отменяет token отложенного Show.
- [ ] **Step 4:** `lua tests/run.lua build_description`, `lua tests/run.lua sets`, `lua tests/run.lua effects`, `lua tests/run.lua tooltips`, `lua tests/run.lua geometry` → 0 failed. Сохранить жирные названия сетов, зелёную/жёлтую полноту, пары `[5/5 | 3/5]`, одну десятичную цифру, `/s`, категорию бонусов урона без заголовка и двухколоночные особые эффекты. Ordinary breakdown содержит только item name/value, без totals/headers/set names.
- [ ] **Step 5:** Коммит файлов задачи: `feat: show compact complete preset descriptions without tabs`.

### Task 12: Финальная интеграция и приёмка в ESO

**Files:** Modify `Core.lua`, `KanaWardrobe.txt`, `docs/client-validation.md`, `tests/test_integration.lua`; дополнить профильные тесты только для найденных дефектов. Не менять соседние аддоны.

**Interfaces:** Core один раз создаёт adapters/planner/runner/draft services, затем Session/UI. Events обозначают домен и actual revision. Feature unavailable блокирует только пресеты, требующие недоступную часть; gear-only остаётся рабочим.

- [ ] **Step 1:** Добавить `complete_preset_runs_from_each_page`, `unsupported_new_api_keeps_legacy_inventory_working`, `native_use_and_bank_actions_keep_original_identity`, `complete_noop_has_no_wait_and_no_requests`:
  ```lua
  assert(session:Apply(preset.id)); fixture:ConfirmAllPhases()
  assert(KW.BuildModel.Matches(fixture:Capture(),preset))
  assert(session:GetView().state=="idle" and not runner:IsBusy())
  assert(api.ZO_InventorySlot_DiscoverSlotActionsFromActionList==nativeDiscover)
  assert(api.ZO_InventorySlotActions.DoPrimaryAction==nativeDoPrimaryAction)
  ```
- [ ] **Step 2:** `lua tests/run.lua integration` → FAIL отсутствующей полной wiring, затем реализовать её в Core и manifest в порядке зависимости из карты файлов. Не повышать минимальный API молча; использовать feature detection из задачи 1.
- [ ] **Step 3:** `lua tests/run.lua all` → 0 failed. Проверить синтаксис всех изменённых Lua: `rg --files -g '*.lua' -g '!tests/**' -0 | xargs -0 -n1 luac -p`; `git diff --check` → пустой вывод. Зафиксировать итоговый счёт тестов, не подменять его базовыми 290.
- [ ] **Step 4:** В ESO после `/reloadui` пройти spec §12: создание каждого из трёх видов пресета, смешанный пресет и все три завершения; уходы со всех страниц завершают только current editor через native discard/continue, без переноса draft/Send/потери чужих edits; full quick capture/load; дефициты обоих бюджетов; кулдауны и бой; missing item/morph; fixed ult; reload между фазами. Проверить обычное использование предметов и банк в обе стороны.
- [ ] **Step 5:** Визуально принять каждую страницу и общее описание на текущем масштабе пользователя, затем в уменьшенном окне/другом UI scale: галочки внутри рамок, корневые слоты не сдвинуты, фон не растянут по вертикали, список/описание/родные области не перекрыты. Native tooltips и маленькие иконки читаемы. Не объявлять это пройденным по geometry mocks.
- [ ] **Step 6:** Независимый обзор всего изменения по пунктам Review Focus и сохранению прежних требований; исправить конкретные замечания и повторить затронутые проверки. Коммит финальной интеграции только её файлов: `feat: integrate complete build presets across native pages`.

## Исполнение и границы параллельности

Рекомендация: отдельный исполнитель и отдельная проверка для каждой задачи, с общими контрактами из этого документа. Это даёт свежий контекст, не заставляя одного агента удерживать всё расширение; задачи 3 и 4 независимы после данных. Центральный planner/runner/session и родные переходы нельзя одновременно менять нескольким исполнителям. Общие Core/manifest обновляет текущий интегратор задачи, не параллельные адаптеры.

Первым обязательным рубежом является реальная проверка протокола в задаче 1. Реальная мутация и inverse skills уже подтверждены; gate закрывается после диагностического reset. UI не строится на опровергнутом общем cross-page draft; его segmentation принята пользователем, а remaining full matrix находится в Task12. Последний рубеж — независимая проверка и клиентская приёмка; сам факт прохождения Lua-тестов не достаточен.

Этот документ фиксирует принятую пользователем сегментацию и порядок уже согласованной работы; изменение документа не является реализацией editor или доказательством приёмки Task12. Исполнители соблюдают назначенные области файлов и отдельную независимую проверку. Предыдущие изменения кода не откатываются и не заменяются чистой копией старого коммита.
