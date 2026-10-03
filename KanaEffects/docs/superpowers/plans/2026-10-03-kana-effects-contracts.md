# KanaEffects: контракты реализации v1

Приложение к [плану](2026-10-03-kana-effects-implementation.md). Дата: 3 октября 2026. Это соглашения для будущего Lua-кода, а не утверждение, что модули уже существуют. Менять общие контракты может только координатор после проверки потребителей.

## Модули и единицы

Все модули находятся в единственном глобальном `KanaEffects`; файлы загружаются по манифесту, без `require` в клиенте. Чистые модули не читают глобальные ESO API. Время в модели — секунды монотонных часов клиента, передаваемые параметром; профиль не содержит время активных эффектов. Приведение clocks проверяет API-проба. Координаты/размеры — UI-единицы GuiRoot; Retina и коэффициент из UserSettings не умножаются вручную вторично.

Идентификаторы виджетов/наборов — неизменные строки, не отображаемые имена. Индексы строки/колонки — от 1. Множество `Set<T>` — Lua-таблица `[key]=true`, список `T[]` — плотный массив. Все DTO передаются как неизменяемые снимки, если метод явно не относится к store/draft.

## Типы

```lua
-- Обозначение union в комментариях, не синтаксис Lua:
Selector = { kind = 'ability', id = integer }
        or { kind = 'family', id = string, level = 'pair'|'minor'|'major' }
        or { kind = 'category', id = string }

CatalogEntry = {
    abilityId = integer, name = string, icon = string, aliases = string[],
    familyId = string|nil, level = 'minor'|'major'|nil,
    categories = Set<string>, origin = 'skill'|'set'|'enchant'|'unknown',
    apiVersion = integer, provenance = string, verified = boolean
}
-- Каталог семейств отдельно задаёт поддерживаемые уровни, representative IDs,
-- порядок PvE/PvP и проверенный значок. Нет подразумеваемого Major у любого Minor.

UnitRef = { tag = 'player'|'reticleover'|'boss1'|...,
            generation = integer, unitId = integer|nil, name = string }
-- UnitKey сериализует tag + generation. effectSlot не является buffIndex.
Observation = {
    key = string, unit = UnitRef, abilityId = integer, effectSlot = integer,
    kind = 'buff'|'debuff'|'unknown', startTime = number|nil, endTime = number|nil,
    lifetime = 'finite'|'permanent'|'toggle'|'unknown', fullDuration = number|nil,
    stacks = integer, castBy = 'self'|'other'|'unknown',
    sourceType = integer|nil, catalog = CatalogEntry,
    observedAt = number, synthetic = boolean
}
-- key = UnitKey + effectSlot; при переиспользовании слота сверять abilityId.
-- Существуют только доступные API наблюдения, никаких вымышленных caster IDs.
Delta = { revision = integer, units = Set<UnitKey>, abilities = Set<integer>,
          families = Set<string>, categories = Set<string>, membershipChanged = boolean }

Predicate = { op='and'|'or', args=Predicate[] }
         or { op='not', arg=Predicate }
         or { op='facet', field='kind'|'lifetime'|'named'|'category'|'origin'|'castBy',
                         values=(string|boolean)[] }
         or { op='selector', selector=Selector }
-- lifetime predicate: short|long|permanent|toggle|unknown. short < threshold;
-- long >= threshold; finite class uses fullDuration, not endTime-now.
-- named predicate: boolean. category values use CatalogEntry.categories.
SetDef = { id=string, name=string, predicate=Predicate|nil,
           includeSets=string[], excludeSets=string[] }
-- base = Eval(predicate) OR union(includeSets); nil predicate = false.
-- result = base AND NOT union(excludeSets). Empty AND=true, empty OR=false.
-- Graph of includeSets + excludeSets must be acyclic; unknown refs are errors.

Widget = {
    id=string, name=string, type='table'|'grid', unitTag=string,
    layout={ columns=integer, rows=integer, fixedAxis='columns'|'rows', count=integer,
             gap=number, absent='hidden'|'ghost', ghostAlpha=number },
    anchor={ pointX=0|0.5|1, pointY=0|0.5|1,
             relativeTo='screen'|'actionBar'|'resources'|'targetFrame',
             relativePointX=0|0.5|1, relativePointY=0|0.5|1, x=number, y=number },
    style={ mode='over'|'under'|'right'|'list', iconSize=number,
            timerFontSize=number, nameFontSize=number, rowWidth=number },
    slots={ [row]={ [column]=Selector } }, -- sparse; includes out-of-bounds assignments
    rules={ includeSets=string[], excludeSets=string[],
            named='any'|'only'|'exclude', mergePairs=boolean }
}
Profile = { schemaVersion=1, widgets=Widget[], sets=SetDef[], hidden=Selector[],
            longThreshold=60, editor={toolbarX=number,toolbarY=number} }
-- Profile excludes synthetic records, live observations, snapshots, cached controls.

TimerState = { kind='finite', endTime=number }
          or { kind='permanent' }
          or { kind='unknown', knownUntil=number|nil }
          or { kind='missing' }
Entry = {
    key=string, selector=Selector, unit=UnitRef, active=boolean,
    name=string, icon=string, kind='buff'|'debuff'|'unknown',
    pair=boolean, minor=TimerState|nil, major=TimerState|nil, single=TimerState|nil,
    count=integer, contributors=Observation[], uncertain=boolean,
    row=integer|nil, column=integer|nil, hiddenInGrids=boolean
}
Rect = { x=number, y=number, width=number, height=number }
Measurement = { cellWidth=number, cellHeight=number, iconWidth=number,
                timerColumnWidth=number, timerLineHeight=number }
Placement = { key=string, rect=Rect, visible=boolean, row=integer, column=integer }
LayoutResult = { rect=Rect, measurement=Measurement, placements=Placement[],
                 logicalCount=integer, overflow={left=boolean,right=boolean,top=boolean,bottom=boolean} }
Diagnostic = { code=string, path=string, message=string }
DisplayMetadata = { name=string, icon=string, kind='buff'|'debuff'|'unknown',
                    pair=boolean, availableLevels=Set<string> }
PickerItem = { selector=Selector, name=string, icon=string, selectable=boolean,
               reason=string|nil, abilityIds=integer[], unitTags=string[],
               lastSeen=number|nil }
SearchFilter = { kind='ability'|'family'|'category'|nil, category=string|nil,
                 unitTag=string|nil, level='pair'|'minor'|'major'|nil }
Reason = { matched=boolean, code=string, label=string, children=Reason[] }
```

## Семантические инварианты

1. Сначала принадлежность к набору на уровне наблюдений, затем исключения виджета и hidden, затем свёртка Minor/Major. Явная таблица обходит правила грида и hidden. Не складывать Minor игрока с Major цели.
2. Для одинаковой ауры несколько наблюдаемых применений дают union активности. Если есть достоверно бессрочное — permanent; иначе при неизвестном конце — unknown с knownUntil для подсказки; иначе самый поздний конечный конец. После удаления одного применения другое остаётся.
3. Для category-селектора: один представитель с count; ближайший конечный конец, если есть; иначе permanent при всех достоверно бессрочных, иначе unknown. uncertain отмечает наличие неизвестности. Tooltip перечисляет членов. Исчезновение ближайшего не удаляет всю категорию.
4. Отсутствующий уровень пары сохраняет строку. Minor сверху голубым, Major снизу золотым. Видимых I/II нет во всех четырёх стилях.
5. Grid включения — union, исключения — union с приоритетом исключения; результат не зависит от порядка виджетов. Порядок Entries: фиксированный ранг каталога, затем стабильный firstSeen для некаталогизированных, abilityId как tie-breaker; таймер не ключ сортировки.
6. SourceType не доказывает конкретного заклинателя. CastBy неизвестен, пока API не даёт факта. GetAbilityBuffType получает проверенный caster context; recipient unit tag нельзя молча выдать за caster.
7. Generation назначается на смене наблюдаемой сущности. Просто подписать позднее событие текущей generation недостаточно: сравнить доступный unitId; при неоднозначности перечитать текущую цель, не применять непроверенный diff.
8. Истёкшие finite observations не дают active Entry даже если API ещё не прислал remove; Projector проверяет endTime относительно now. Timers onExpire однократно инвалидирует нужный widget/entry через Renderer callback.
9. Save/Cancel меняет конфигурацию, но не откатывает время и поток настоящих событий. Закрытие теста восстанавливает самый свежий live store.

## API модулей

Сигнатуры `Module.New(...)` создают объект, остальные через `:`. Статические чистые функции отмечены точкой. callback не вызывается после Dispose/Unsubscribe.

| Модуль | Контракт |
| --- | --- |
| EsoApi | `Build() -> api`; table of verified native functions/events/controls, `Now() -> seconds`, `NormalizeName(text) -> string`; production API calls isolated here, exact native signatures recorded in T01 probe |
| Schema | `Validate(profile) -> boolean, Diagnostic[]`; `CopyProfile(profile) -> Profile` |
| Catalog | `New(api, versionedData) -> catalog`; `Describe(abilityId, casterContext) -> CatalogEntry`; `Resolve(selector) -> DisplayMetadata`; `Search(query, filter: SearchFilter, offset, limit) -> PickerItem[], total`; `ValidateSelector(selector) -> boolean, Diagnostic?` |
| Selectors | `Key(selector) -> string`; `Matches(selector, observation) -> boolean` |
| Store | `New() -> store`; `Upsert(observation) -> Delta`; `Remove(unitRef, effectSlot, abilityId) -> Delta`; `ReplaceUnit(unitRef, observations) -> Delta`; `ReadUnit(unitTag) -> Observation[]`; `Snapshot(unitTag, capturedAt) -> {unit, capturedAt, observations}`; `Subscribe(callback(delta)) -> unsubscribe` |
| Sources | `New(api, catalog, store, history) -> sources`; `Start(unitTags)`; `Reconfigure(unitTags)`; `Stop()`; only owner of subscriptions and initial scans |
| History | `New(capacity=1000) -> history`; `Observe(observation)`; `Query(query, filter: SearchFilter, offset, limit) -> PickerItem[], total`; `Export()/Import(data)` for bounded real recents; synthetic records ignored |
| Rules | `Compile(setDefs, longThreshold) -> compiled|nil, Diagnostic[]`; `compiled:Matches(setId, observation) -> boolean`; `compiled:Explain(setId, observation) -> Reason`; `compiled:AffectedSets(delta) -> Set<setId>` |
| Projector | `BuildWidget(widget, profile, compiled, store, catalog, now) -> Entry[]`; `AffectedWidgets(profile, compiled, delta) -> Set<widgetId>` |
| Layout | `Measure(style, fontMetrics) -> Measurement`; `Place(widget, entries, referenceRect, viewportRect, measurement) -> LayoutResult`; `Reanchor(anchor, oldRect, newPointX, newPointY, referenceRect) -> anchor`; `Center(anchor, rect, referenceRect, axis) -> anchor` |
| Timers | `Format(timerState, now) -> text, nextChangeAt|nil`; `New(clock) -> scheduler`; `Watch(key, timerState, onText(text), onExpire())`; `Unwatch(key)`; `Advance(now)`; `Dispose()` |
| Renderer | `New(parent, controls, scheduler) -> renderer`; `Render(widget, entries, layout)`; `SetCallbacks({onExpired(widgetId, entryKey)})`; `SetEditorOverlay(widgetId, selected)`; `SetVisible(visible)`; `ReleaseWidget(widgetId)`; `Dispose()` |
| Storage | `New(api, defaultsProvider() -> Profile) -> storage`; `Load() -> Profile, Diagnostic[]`; `Write(profile) -> boolean, Diagnostic[]`; `LoadHistory()/WriteHistory(data)` kept separate from profile |
| Session | `New(storage) -> session`; `Begin() -> draft`; `Apply(command) -> boolean, Diagnostic[]`; `ReadDraft() -> Profile`; `Save() -> boolean, Diagnostic[]`; `Cancel()`; `IsDirty() -> boolean`; `Subscribe(callback(draft)) -> unsubscribe` |
| Demo | `Build(count, seed, catalog, now) -> Observation[]`; count 50/100/250 or ordinary fixture; every record synthetic=true |
| Runtime | `New(deps) -> runtime`; `Start(profile)`; `ApplyConfig(profile)`; `Preview(profile, provider)`; `EndPreview()`; `SetVisible(visible)`; `Dispose()`; provider is live store or separate demo store |
| Picker | `New(catalog, history, store, session) -> picker`; `Open({purpose, currentSelector?, onChoose(selector), onCancel()})`; `Close()` |
| Editor | `New(session, runtime, picker, anchors) -> editor`; `Open()`; `Select(widgetId)`; `RequestClose()`; `Dispose()`; dialogs and keyboard focus owned here |
| Anchors | `New(api) -> anchors`; `GetReferenceRect(referenceId) -> Rect`; `Observe(onChanged) -> unsubscribe`; native integration resolves public controls, never reparents content under target frame |
| NativeHUD | `New(api, anchors, session) -> adapter`; `Sync(profile) -> Diagnostic[]`; `Dispose()`; owns native callbacks and capability fallbacks |
| TargetView | `New(store, clock) -> targetView`; `Capture() -> snapshot`; `GetSnapshot()`; `ResumeLive()`; UI binding can display live or marked snapshot, never overwrite store |
| Diagnostics | `New() -> metrics`; `Count(name, amount)`; `BeginCapture(label)`; `EndCapture() -> report`; no continuous profiler by default |

`deps` in Runtime consists of `{catalog, store, rules, projector, layout, renderer, anchors, fontMetrics, clock, diagnostics?}`: constructed in Bootstrap, no module loads another implicitly. Controls/fontMetrics/clock/api are adapters; tests provide fakes. Clock implements `clock:Now() -> seconds`. Diagnostics optional until T15; absent instrumentation must not affect behavior. Native callback ownership and per-module unsubscribe are mandatory. T06 создаёт минимальный Anchors со screen reference; T13 расширяет тот же модуль, не создаёт второго владельца координат.

## Editor commands

`Session:Apply(command)` accepts a closed list; no arbitrary mutator functions across modules:

- `{type='widget.add', widget}` / `{type='widget.delete', widgetId}` / `{type='widget.duplicate', widgetId, newId}`.
- `{type='widget.patch', widgetId, patch}`: allowed name/type/unitTag/style/layout/anchor/rules fields only; unknown field is Diagnostic.
- `{type='slot.assign', widgetId, row, column, selector}` / `{type='slot.clear', widgetId, row, column}`.
- `{type='slot.transfer', from={widgetId,row,column}, to={widgetId,row,column}, copy=boolean}`: default swap, Alt-copy preserves source and replaces destination; same source/destination is no-op.
- `{type='set.put', set}` / `{type='set.delete', setId}`: deletion with live refs rejected with referencing widget/set names until user removes/replaces refs.
- `{type='hidden.add', selector}` / `{type='hidden.remove', selector}` / `{type='hidden.clear'}`.
- `{type='profile.threshold', seconds}` / `{type='editor.toolbar', x, y}`.

Drag previews in memory and commits one command on release; Escape/pointer cancellation reverts only active gesture. Resize never rewrites slot coordinates or deletes out-of-bounds assignments. Duplicate creates deep copy and unique ID. Invalid edit leaves prior draft and rendered preview intact.

TargetView подписан на store и хранит последний достоверный live snapshot до очистки reticleover. При Capture сохраняются время исходного наблюдения и время открытия просмотра; старый снимок не получает новую дату достоверности. Замороженные таймеры вычисляются на время исходного наблюдения.

Переключение widget.type table/grid сохраняет и slots, и rules в draft: при возвращении раскладка восстанавливается. Невидимые настройки режима не удаляются.
