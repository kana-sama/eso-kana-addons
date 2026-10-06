# KanaStatSources Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Добавить в штатные тултипы всех основных характеристик таблицу источников с согласованным итогом, формулу критического шанса и команду диагностического дампа.

**Architecture:** Отдельные сборщики создают сериализуемый снимок персонажа. Провайдеры преобразуют снимок в подтверждённые вклады и диагностические кандидаты; чистая модель считает строки, проценты и остаток. Таблица и штатные хуки отображают результат, а дамп сохраняет исходные данные и расчёт.

**Tech Stack:** Lua 5.1, ESO API 101051, штатные контролы клавиатурного интерфейса, SavedVariables. Обязательных сторонних библиотек нет. Локальные тесты: Lua 5.4.9 и проверенный `lupa.lua51` из `/tmp/kana-cooldown-test-deps`.

**Spec:** [2026-10-06-kana-stat-sources-design.md](../specs/2026-10-06-kana-stat-sources-design.md), согласована пользователем в чате 2026-10-06 после коммита `b50f38d`.

## Global Constraints

- Аддон располагается в `eso-kana-addons/KanaStatSources/`. Его ресурсные пути учитывают эту папку.
- Пользователь выбрал все основные характеристики. Окно «Дополнительные характеристики» в этот объём не входит.
- Поддерживается интерфейс клавиатуры и мыши, показанный на скриншоте пользователя; интерфейс геймпада не входит в первую версию.
- Обязательные зависимости от Combat Metrics, LibCombat или LibSets не нужны.
- Значение с `STAT_BONUS_OPTION_DONT_APPLY_BONUS` не объявляется «чистой базой» без подтверждения его смысла для соответствующей характеристики.
- `Неизвестно = эталонный итог − сумма видимых вкладов`.
- Отрицательная разница не обрезается до нуля и не скрывается.
- Аддон не снимает предметы, не переключает панели и не сбрасывает навыки или атрибуты ради измерения вклада.
- Хранятся последние десять снимков, чтобы можно было сравнить состояния.
- Автоматические тесты не считаются подтверждением живого UI.
- Производственные файлы должны загружаться в Lua 5.1: без `goto`, битовых операторов Lua 5.3, `utf8` и обязательного `table.unpack`.
- Изменять только новый аддон, соответствующую запись корневого README и документы этой задачи; коммиты ограничивать явным списком файлов.

## Review Focus

1. Один баф в нескольких слотах или через навык и эффект: подтверждённый бонус учитывается один раз, правила стаков сохраняются — тесты задачи 5.
2. Частично недоступный API, `nil`, `NaN` и бесконечность: остальные категории продолжают работать, отсутствие данных не становится подтверждённым нулём — задачи 1 и 2.
3. Постоянный бонус перед условным текстом с длительностью: учитывать только однозначный постоянный фрагмент, сохранить условный хвост в кандидатах — задача 3.
4. Неподдержанный язык и русская десятичная запятая: исходные имена сохраняются, подписи имеют английский fallback, формула воспроизводит округлённый процент — задачи 1 и 7.
5. Маленький экран, большой UI scale, 80 строк и длинные имена UTF-8: итог доступен, все источники достижимы прокруткой, цифры не перекрываются — задача 7.

---

## Рабочая среда и файлы

Все команды далее выполняются из корня `eso-kana-addons`. До исполнения
проверить текущие `git status`, корень репозитория и приложенные worktrees.
Изоляцию выбирать по `superpowers:using-git-worktrees`, учитывая, что аддон
нужно оставить в доступной ESO папке. Нельзя переключать или сбрасывать
пользовательский checkout. Состояние при составлении плана: чистый checkout,
detached HEAD после коммита спецификации.

| Файл в `KanaStatSources/` | Ответственность |
| --- | --- |
| `Core.lua`, `Stats.lua` | Namespace, безопасное копирование, реестр 15 характеристик, RU/EN подписи |
| `Model.lua`, `Critical.lua` | Арифметика, проценты, остаток и математическая формула критического шанса |
| `Snapshot.lua` | Безопасные обращения к API, поколения, кеш исходных категорий, снимок |
| `capture/Equipment.lua`, `capture/Build.lua`, `capture/Effects.lua` | Чтение экипировки; навыков, CP и атрибутов; эффектов и окружения |
| `Descriptions.lua`, `Rules.lua` | Строгий разбор текста, реестр условий и групп применения |
| `sources/Base.lua`, `sources/Equipment.lua`, `sources/Skills.lua`, `sources/Champion.lua`, `sources/Effects.lua` | Вклады отдельных категорий и причины исключения |
| `Dump.lua` | Сериализуемый диагностический отчёт и десять сохранённых снимков |
| `Table.lua`, `Tooltip.lua` | Таблица с ограничением размера и подключение к штатным тултипам |
| `App.lua`, `KanaStatSources.addon` | События, команда, загрузка и связывание компонентов |
| `README.md`, `docs/research.md`, `docs/client-validation.md` | Использование, доказательства правил, проверка в ESO |
| `tests/support.lua`, `tests/run.lua`, `tests/run51.py` | Общие фикстуры и запуск одного и того же набора в Lua 5.4 и 5.1 |
| `tests/test_*.lua`, `tests/fixtures/*.lua` | Содержательные регрессии и явно помеченные синтетические снимки |

Дополнительно изменить только `eso-kana-addons/README.md`: добавить описание
нового аддона и команды. По итогам каждого этапа фиксировать выполненные
checkbox в этом плане.

## Общие контракты

Namespace: глобальная таблица `KanaStatSources`, локальный alias `KSS`.
Модули публикуют таблицы внутри неё, а не отдельные глобальные функции.

`StatKey`: `maxHealth`, `maxMagicka`, `maxStamina`, `healthRecovery`,
`magickaRecovery`, `staminaRecovery`, `weaponDamage`, `spellDamage`,
`weaponCritical`, `spellCritical`, `physicalPenetration`, `spellPenetration`,
`physicalResistance`, `spellResistance`, `criticalResistance`.
`Stats.List(api)` связывает их с ровно 15 ID из спецификации.

`Snapshot` содержит `schemaVersion=1`, `meta`, `context`, `stats`,
`attributes`, `equipment`, `sets`, `skills`, `bars`, `champion`, `effects`,
`advancedStats`, `criticalSamples`, `preview`, `capabilities`, `errors`,
`categoryStatus`, `generation`, `consistent`. Неполная категория остаётся
явно помеченной; прочитанные элементы сохраняются. `stats[key]` содержит
`id`, `total`, `withoutBonus` и признак доступности каждого значения.

`Contribution` содержит `key`, `sourceKey`, `category`, `label`, `stat`,
`operation`, `amount`, `active`, `evidence`, `ruleId` и исходный `source`.
Операции: `flat`, `effectiveFlat`, `percent`, `criticalChance`.
Процент содержит `group`, `scope`; scope задаёт набор исходных категорий
или предыдущих групп. `effectiveFlat` — подтверждённый конечный вклад,
к которому нельзя повторно применять множитель без отдельного правила.
Один источник для нескольких характеристик даёт несколько записей
с разными `stat` и ключами. `criticalChance` означает прибавку в процентных
пунктах, которую модель переводит в рейтинг по проверенной калибровке.

`Diagnostic` содержит `sourceKey`, `category`, `reason`, `source`,
`ruleId`, `stat` при его известности. Провайдер возвращает две таблицы:
`contributions, diagnostics`. Неизвестный условный текст не становится
автоматически активным процентом или плоским бонусом.

`Policies[statKey]` — сериализуемое описание порядка процентных групп,
их областей применения и требуемого покрытия базы. В модели тестируется
синтетическая политика; игровые политики добавляются только с доказательством
в `docs/research.md`. Равенство рассчитанной суммы и итога не доказывает
верность правила само по себе.

`Breakdowns[statKey]` содержит `rows`, `total`, `explained`, `unknown`,
`rawUnknown`, `critical`, `preview`, `diagnostics`, `consistent`.
`row.value` — именно видимое числовое значение; суммы считать по нему.
Для процента row дополнительно хранит `base`, `amount`, `group`.
`preview` отделён от действующего `total`.

`TestSupport` определяется в задаче 1 и публикуется как `T` только в тестах:
`T.snapshot(totals)`, `T.flat(key, stat, amount)`,
`T.percent(key, stat, amount, group, scope)`, `T.eq(actual, expected)`,
`T.near(actual, expected, epsilon)`, `T.sumRows(breakdown)`.
Каждый `test_*.lua` возвращает таблицу именованных функций; runner вызывает
их и печатает `N passed; 0 failed`, иначе завершает процесс с ненулевым кодом.

## Task 1: Проверяемая модель итогов и критического шанса

**Files:** создать `Core.lua`, `Stats.lua`, `Model.lua`, `Critical.lua`,
пустой интерфейс реестра `Rules.lua`, `tests/support.lua`, `tests/run.lua`,
`tests/run51.py`, `tests/test_model.lua`, `tests/test_critical.lua`.

**Interfaces:**
- `Core.CopySerializable(value) -> value, diagnostics`;
- `Stats.List(api) -> StatDefinition[]`, `Stats.KeyForId(api, id) -> StatKey|nil`;
- `Critical.Calibrate(samples, rating) -> calibration`;
- `Critical.RatingForChance(deltaPercent, calibration) -> number|nil, reason`;
- `Model.Build(snapshot, contributions, diagnostics, policies) -> Breakdowns`;
- `Rules.Policies`, `Rules.Register(rule)`, `Rules.Resolve(source, snapshot) -> contributions, diagnostics`.

- [x] **Step 1: Написать падающие `test_model` и `test_critical`.**
  Проверить ровно 15 характеристик; положительный и отрицательный остаток;
  дедупликацию по key; неподтверждённую базу процентов; отсутствие мутаций
  входа; отклонение `NaN`, infinity и нечисловых вкладов. Синтетические
  проценты 10% и 20% одной базы 12000 дают 3600, а следующая группа 5%
  от 15600 даёт 780. Эти числа являются проверкой арифметики, не ESO-формулами.
  Минимальные проверяемые assertions:
  ```lua
  local s = T.snapshot({maxHealth = 100})
  local b = KSS.Model.Build(s, {T.flat('known', 'maxHealth', 120)}, {}, {})
  T.eq(b.maxHealth.unknown, -20)
  T.eq(T.sumRows(b.maxHealth), 100)
  local c = KSS.Critical.Calibrate({
      {rating=0, chance=0}, {rating=1, chance=0.005},
      {rating=100, chance=0.5}, {rating=1000, chance=5}}, 1000)
  T.eq(c.verified, true)
  T.near(c.pointsPerPercent, 200, 1e-8)
  T.eq(KSS.Critical.RatingForChance(5, c), 1000)
  ```
  Добавить пробы со смещением, подтверждённым cap, нелинейной функцией,
  нулевым рейтингом и округлением до одной десятичной в RU/EN.
- [x] **Step 2: Запустить `lua KanaStatSources/tests/run.lua model` и `lua KanaStatSources/tests/run.lua critical`.** Ожидается FAIL из-за отсутствующих модулей или нужных функций.
- [x] **Step 3: Реализовать указанные интерфейсы.** Форматировать вклады до
  расчёта видимого остатка; сохранять rawUnknown отдельно. Общая база
  аддитивных процентов фиксируется до применения всей группы. Неверифицированные
  группы дают кандидатов. Порядок строк брать из спецификации. Критический
  коэффициент и cap проверять по пробам, никогда не обрезать исходный рейтинг.
  Уточнять точность коэффициента до совпадения показанного округлённого процента;
  при непроверенной формуле сохранять результат API и пометку из спецификации.
- [x] **Step 4: Повторить обе команды.** Ожидается `0 failed` и exit 0.
- [x] **Step 5: Запустить тот же набор в Lua 5.1.** Команда:
  `PYTHONPATH=/tmp/kana-cooldown-test-deps python3 KanaStatSources/tests/run51.py`.
  Runner должен создавать отдельный LuaRuntime на тестовый файл и проверять
  синтаксис производственных файлов через Lua 5.1 `loadstring`. Ожидается `0 failed`.
- [x] **Step 6: Проверить `git diff --check` и закоммитить только файлы задачи:** `feat: add stat source reconciliation and critical formulas`.

## Task 2: Безопасный снимок персонажа и все исходные категории

**Files:** создать `Snapshot.lua`, `capture/Equipment.lua`, `capture/Build.lua`,
`capture/Effects.lua`, `tests/test_snapshot.lua`, `tests/fixtures/capture.lua`.

**Interfaces:**
- `Snapshot.New(api) -> collector`;
- `collector:Invalidate(category)`; категории `stats`, `equipment`, `build`, `effects`, `all`;
- `collector:Capture(full) -> Snapshot`; `full=true` добавляет все дополнительные характеристики;
- `CaptureEquipment.Read(api) -> data, errors` с полями `equipment`, `sets`;
- `CaptureBuild.Read(api) -> data, errors` с полями `attributes`, `skills`, `bars`, `champion`;
- `CaptureEffects.Read(api) -> data, errors` с полями `context`, `effects`.

- [x] **Step 1: Написать `test_snapshot`.** Стабильный снимок содержит все
  категории, обе конфигурации панелей, 13 возвращаемых полей бафа и сохранённые
  описания. Нет вызовов переключения оружия, ресета или снятия предметов.
  Сбой одного API оставляет прочитанные элементы и error, а не обнуляет категорию.
  Смена панели между началом и концом вызывает один повтор; повторная смена
  даёт `consistent=false`. Незаполненные менеджеры навыков/CP и созданные навыки
  сохраняются как доступные сведения либо явная причина недоступности.
  ```lua
  local collector = KSS.Snapshot.New(T.captureApi())
  local s = collector:Capture(true)
  T.eq(s.schemaVersion, 1)
  T.eq(s.consistent, true)
  T.eq(s.bars.back[3].abilityId, 203)
  T.eq(s.effects[1].castByPlayer, false)
  T.eq(T.captureApiMutationCalls, 0)
  ```
  `T.captureApi()` и счётчик определить в новой фикстуре задачи.
- [x] **Step 2: `lua KanaStatSources/tests/run.lua snapshot`.** Ожидается FAIL.
- [x] **Step 3: Реализовать сборщики.** Использовать реестр Stats, числовые
  API предметов, `GetItemLinkTraitInfo`, `GetItemLinkEnchantInfo`,
  `GetItemLinkSetInfo`/`GetItemLinkSetBonusInfo`, оба набора слотов оружия,
  `GetAttributeSpentPoints`, `GetAttributeDerivedStatPerPointValue`,
  `GetSlotBoundId`, данные изученных навыков и CP, `GetUnitBuffInfo`
  и `GetAbilityDescription`. Штатные менеджеры использовать только для чтения
  и не сохранять в снимке native/control/function/id64 userdata.
  Пробы критики: 0, 1, 100, 1000, текущий рейтинг и текущий рейтинг + 1000,
  без повторов. Сравнивать generation, активную панель и подпись быстрых
  stats/effects/equipment в начале и конце. Полный scan навыков и CP
  кешируется; инвалидировать его на изменения build.
- [x] **Step 4: Повторить тест.** Ожидается `0 failed`; проверить отдельно
  nil/nonfinite итог, устаревшие пробы, потерю части предметов и `full=false`.
- [x] **Step 5: Запустить общий Lua 5.1 runner.** Ожидается `0 failed`.
- [x] **Step 6: Проверить diff и scoped commit:** `feat: capture character stat inputs safely`.

## Task 3: База, атрибуты, предметы и сеты без двойного учёта

**Files:** создать `Descriptions.lua`, `sources/Base.lua`, `sources/Equipment.lua`,
`docs/research.md`, `tests/test_descriptions.lua`, `tests/test_equipment.lua`,
`tests/test_base.lua`, `tests/fixtures/equipment.lua`; дополнить `Rules.lua`.

**Interfaces:**
- `Descriptions.Parse(text, language, kind) -> clauses, unparsed`;
  clause имеет `stats`, `operation`, `amount`, `condition`, `raw`, `confirmed`;
- `Sources.Base.Build(snapshot) -> contributions, diagnostics`;
- `Sources.Equipment.Build(snapshot) -> contributions, diagnostics`;
- `Rules.Resolve` и `Rules.Policies` сохраняют интерфейсы задачи 1.

- [x] **Step 1: Зафиксировать доказательства исходных величин.** В
  `docs/research.md` записать проверенную сигнатуру
  `GetAttributeDerivedStatPerPointValue(attribute, stat)`, её использование
  в штатном предпросмотре и точные ссылки для каждого правила базового значения.
  Различить номинальный и уже масштабированный вклад атрибутов. Проверить
  смысл безбонусного значения для базы по текущим первичным данным; при
  отсутствии доказательства оставить именно базу кандидатом. Из итогового
  остатка базовые значения не выводить. Неподдержанное масштабирование
  исключает соответствующее правило, но не остальные предметы.
- [x] **Step 2: Написать падающие тесты трёх модулей.** RU/EN, цветовые коды,
  NBSP/узкие NBSP, `1 096`, `1,096`, `7,5%`; не считать «2 предмета»,
  «10 секунд» и вероятность proc величиной стата. Постоянный префикс с
  условным хвостом возвращает два независимых результата. Два одноимённых
  предмета имеют разные ключи; сетовый порог — один ключ. Infused не усиливает
  повторно готовое описание зачарования, Reinforced/Nirnhoned не усиливают
  повторно готовую броню. Учитывать состояние брони, щит на действующей панели,
  двуручное оружие и обычные/совершенные пороги. Атрибуты используют число
  потраченных очков и прочитанный perPoint, а не черновик.
  ```lua
  local clauses, tail = KSS.Descriptions.Parse(
      'Adds 1096 Maximum Magicka. When you deal damage, gain 300 for 10 seconds.',
      'en', 'set')
  T.eq(clauses[1].amount, 1096)
  T.eq(clauses[1].stats[1], 'maxMagicka')
  T.eq(tail ~= '', true)
  ```
- [x] **Step 3: Запустить группы `descriptions`, `base`, `equipment`.** Ожидается FAIL.
- [x] **Step 4: Реализовать интерфейсы.** Парсер сообщает величину, но не
  доказывает активность источника. Свойства по ID: Healthy/Arcane/Robust/Triune,
  Protective, Prosperous, Precise, Sharpened, Defending, Impenetrable;
  Divines передаёт усиление провайдеру Мундуса. Локальные свойства оружия
  учитывать через готовую силу API, а не вторым процентом. Заряжаемые
  зачарования считать активными только по подтверждённому эффекту/правилу.
  Сеты опирать на действующие количества API, а не суммарное число обеих
  панелей; семейство совершенного/обычного сета определить API.
  Процентные и особые сеты без правила остаются кандидатами.
- [x] **Step 5: Повторить три группы и Lua 5.1 runner.** Ожидается `0 failed`;
  все подтверждённые строки имеют evidence, не синтетическое доказательство.
- [x] **Step 6: Проверить diff и scoped commit:** `feat: explain attributes equipment and set bonuses`.

## Task 4: Изученные навыки и действующие CP

**Files:** создать `sources/Skills.lua`, `sources/Champion.lua`,
`tests/test_skills.lua`, `tests/test_champion.lua`, `tests/fixtures/build.lua`;
дополнить `Rules.lua`, `docs/research.md`.

**Interfaces:** `Sources.Skills.Build(snapshot)` и
`Sources.Champion.Build(snapshot) -> contributions, diagnostics`.
Используют Snapshot, Descriptions, Rules, Contribution задачи 1.

- [x] **Step 1: Написать падающие тесты.** Неизученная пассивка, чужой ранг,
  отключённая линия подкласса и навык на второй панели не активны. Для
  правил с количеством предметов/навыков/оружием использовать текущий контекст.
  В CP различать saved points и pending points, полную ступень и неполную,
  passive и slottable, slotted и unslotted. Синтетическая звезда с шагом
  10 и прибавкой 20 при 19 очках даёт 20, при 20 — 40; она не утверждает
  игровые величины. Неустановленная slottable даёт кандидата без числового вклада.
- [x] **Step 2: Запустить группы `skills`, `champion`.** Ожидается FAIL.
- [x] **Step 3: Реализовать провайдеры и проверенные правила.** Простой
  постоянный flat бонус изученной пассивки/активной CP распознаётся строго.
  Процент, эффект от наличия навыка на панели, бонус за каждый предмет брони,
  оружейная специализация и подкласс требуют зарегистрированного условия.
  Для CP использовать current bonus text/API с текущими сохранёнными очками,
  а не число «за ступень» из полного описания. Неизвестную ступень не угадывать.
  Правила для расовых, броневых, оружейных и классовых источников получают
  ID, версию данных и первичную ссылку в research. Навык, дающий тот же
  именованный баф, ссылается на канонический sourceKey эффекта.
- [x] **Step 4: Повторить обе группы.** Ожидается `0 failed`, включая
  потерю доступности навыка при смене подкласса и чужой язык описания.
- [x] **Step 5: Общий Lua 5.1 runner.** Ожидается `0 failed`.
- [x] **Step 6: Scoped commit:** `feat: explain active skill passives and champion bonuses`.

## Task 5: Еда, Мундус, бафы, дебафы и процентные политики

**Files:** создать `sources/Effects.lua`, `tests/test_effects.lua`,
`tests/fixtures/effects.lua`; дополнить `Rules.lua`, `docs/research.md`.

**Interfaces:** `Sources.Effects.Build(snapshot) -> contributions, diagnostics`.
`Rules.Resolve` принимает источник effect с ID, описанием, стаками,
контекстом и доступным признаком castByPlayer; policy остаётся plain data.

- [x] **Step 1: Написать падающие тесты.** Одно ID в нескольких баф-слотах
  не удваивается; разные стаки обрабатывает явное правило. Одноимённые
  Major/Minor учитываются по ID/правилу совместимости. Еда и Мундус не
  учитываются одновременно в своей категории и как общий баф. Divines
  не применяется повторно, если API-описание уже усилено. Плоская еда
  влияет только на названные ресурсы; неизвестный эффект остаётся в дампе.
  Истёкший временный баф не действует, постоянный баф с endTime=0 не
  исключается. Чужой баф может действовать на игрока без castByPlayer=true.
- [x] **Step 2: `lua KanaStatSources/tests/run.lua effects`.** Ожидается FAIL.
- [x] **Step 3: Реализовать провайдер и правила.** Еда/напитки и Мундус
  определяются по проверенным ID/семействам эффектов, а не случайному
  числу в названии. Простые текущие плоские бонусы используют строгие описания;
  стандартные бафы силы, восстановления, сопротивления, критического
  шанса и максимальных ресурсов получают правила по ID. Для процентов
  документировать сумму внутри группы, последовательность групп и scope;
  не умножать все уже готовые native вклады. Временные оружейные
  зачарования, особые сетовые proc, проклятия и окружение учитывать только
  при известном действии. Неизвестные условия диагностировать.
- [x] **Step 4: Повторить effects и model.** Ожидается `0 failed`; заменить
  активную панель в фикстуре и проверить изменение только соответствующих
  вкладов. Потеря эффекта убирает строку и меняет остаток относительно нового итога.
- [x] **Step 5: Общий Lua 5.1 runner.** Ожидается `0 failed`.
- [x] **Step 6: Scoped commit:** `feat: explain food mundus and active stat modifiers`.

## Task 6: Диагностический дамп и сохранение десяти снимков

**Files:** создать `Dump.lua`, `tests/test_dump.lua`.

**Interfaces:**
- `Dump.Build(snapshot, breakdowns, contributions, diagnostics) -> report`;
- `Dump.Append(saved, report) -> id`, где saved имеет `schemaVersion`, `nextDumpId`, `dumps`;
- `Dump.Storage(api) -> saved` с глобальной SavedVariable `KanaStatSourcesSaved`.

- [x] **Step 1: Написать `test_dump`.** Все поля из раздела дампа спецификации
  присутствуют или явно обозначены недоступными; полный исходный текст
  сохранён. Дамп содержит кандидатов и ошибки, raw/visible residual,
  critical samples, обе конфигурации панелей и только действующий итог.
  Старый снимок не меняется после мутации кеша. После 11 добавлений
  остаются ID 2–11; ID не переиспользуется. Полная запись допускается без STATS.
  ```lua
  local saved = {schemaVersion=1, nextDumpId=1, dumps={}}
  for n=1,11 do KSS.Dump.Append(saved, {marker=n}) end
  T.eq(#saved.dumps, 10)
  T.eq(saved.dumps[1].id, 2)
  T.eq(saved.dumps[10].id, 11)
  ```
- [x] **Step 2: `lua KanaStatSources/tests/run.lua dump`.** Ожидается FAIL.
- [x] **Step 3: Реализовать интерфейсы.** Для схемы и истории использовать
  простые таблицы SavedVariables; не создавать аккаунт/персонажные вложенные
  уровни, которые противоречат согласованному `KanaStatSourcesSaved.dumps`.
  Все записи содержат время, персонажа, версии, язык и consistent.
  Нативные ссылки/циклы не сериализовать; причины фиксировать.
  Неподдержанную будущую версию схемы не перетирать молча.
- [x] **Step 4: Повторить dump.** Ожидается `0 failed`; проверить запись
  частично неудачного снимка и сохранение пустых категорий со статусом.
- [x] **Step 5: Общий Lua 5.1 runner.** Ожидается `0 failed`.
- [x] **Step 6: Scoped commit:** `feat: save diagnostic character stat snapshots`.

## Task 7: Читаемая таблица и штатные тултипы

**Files:** создать `Table.lua`, `Tooltip.lua`, `tests/test_table.lua`,
`tests/test_tooltip.lua`, `tests/fixtures/controls.lua`.

**Interfaces:**
- `Table.New(api, tooltip) -> view`;
- `view:Render(statBreakdown, language, bounds)`;
- `view:Scroll(delta)`, `view:Clear()`;
- `Tooltip.Install(api, getBreakdown) -> bridge`;
- `bridge:Refresh()`, `bridge:Clear()`;
- `getBreakdown(statKey) -> breakdown` предоставляется App из задачи 8.

- [x] **Step 1: Написать падающие тесты.** Хук вызывается после оригинального
  `ZO_StatsEntry_OnMouseEnter(control)` и использует `control.statEntry.statType`.
  Оригинальные заголовок/описание и handler-возвраты сохраняются. Все 15 ID
  открывают свой расчёт; второе наведение не дублирует блок. OnMouseExit,
  OnCleared и скрытие окна очищают таблицу; тултип другого экрана не показывает
  старые строки. Иконка Мундуса не переназначается. Предпросмотр отделён от
  total. Для 80 длинных UTF-8 строк при высоте 480 и UI scale 1.5 размер
  ограничен экраном, итог виден, прокрутка достигает последнего источника.
  После 100 Refresh число созданных контролов не растёт. Неподдержанный
  язык использует английские подписи и исходное имя предмета.
- [x] **Step 2: Запустить `table`, `tooltip`.** Ожидается FAIL.
- [x] **Step 3: Реализовать view.** Создать один собственный блок в
  InformationTooltip через AddControl. Заголовки «Источник», «Бонус»,
  «Вклад в итог», тело с переносом и числом справа, постоянный footer
  с итогом и критической формулой. Ограничить тело по GuiRoot и scale,
  переиспользовать строки; внутреннюю прокрутку двигать OnMouseWheel
  исходного stat-control. Ограничение высоты не меняет breakdown.
- [x] **Step 4: Реализовать bridge.** PostHook только подтверждённых
  `ZO_StatsEntry_OnMouseEnter`/`ZO_StatsEntry_OnMouseExit`; очистка через
  дополнительный OnCleared. Не подменять InitializeTooltip, ClearTooltip
  или общее форматирование всех информационных тултипов. Хуки устанавливаются
  один раз после загрузки; отсутствие конкретного hook отражается в диагностике.
  Refresh открытого тултипа сохраняет корректный штатный заголовок и описание.
- [x] **Step 5: Повторить две группы и Lua 5.1 runner.** Ожидается `0 failed`.
- [x] **Step 6: Scoped commit:** `feat: show scrollable stat source tables in native tooltips`.

## Task 8: Работающий аддон, события, команда и итоговая проверка

**Files:** создать `App.lua`, `KanaStatSources.addon`, `README.md`,
`docs/client-validation.md`, `tests/test_app.lua`,
`tests/fixtures/complete_build.lua`; изменить корневой `README.md`.

**Interfaces:**
- `App.New(api, saved) -> app`;
- `app:Explain(snapshot) -> breakdowns, contributions, diagnostics`;
- `app:GetBreakdown(statKey) -> breakdown`;
- `app:Invalidate(category)`, `app:Dump() -> dumpId`, `app:Start()`.

- [x] **Step 1: Написать падающий app-test, загружающий файлы в порядке
  настоящего manifest и вызывающий EVENT_ADD_ON_LOADED.** Проверить, что
  чужое имя аддона игнорируется, Start не дублируется, slash-команда доступна
  до открытия STATS и вызывает full capture; обычный hover не добавляет дамп.
  Каждая категория источников даёт ненулевую объяснённую строку в совокупности
  фикстур. У всех 15 характеристик сумма видимых строк равна total.
  Изменение оружия, еды, CP, атрибутов и навыков инвалидирует нужные категории
  и обновляет открытый тултип. Несогласованный снимок даёт текущий total и
  неизвестный остаток без смеси старых вкладов. Незарегистрированный необязательный
  event не мешает запуску. Сбой провайдера не ломает другие источники.
- [x] **Step 2: `lua KanaStatSources/tests/run.lua app`.** Ожидается FAIL.
- [x] **Step 3: Реализовать app и manifest.** Title `KanaStatSources`,
  Author `Kana`, Version `1.0.0`, AddOnVersion `10000`, APIVersion `101051`,
  SavedVariables `KanaStatSourcesSaved`. Порядок: Core, Stats, Rules,
  Descriptions, Critical, Model, capture/*, Snapshot, sources/*, Dump,
  Table, Tooltip, App. Инициализация по собственному имени аддона.
  Для player-фильтра зарегистрировать доступные EVENT_STATS_UPDATED,
  EVENT_EFFECT_CHANGED, EVENT_ACTIVE_WEAPON_PAIR_CHANGED,
  EVENT_INVENTORY_SINGLE_SLOT_UPDATE/FULL_UPDATE,
  EVENT_ATTRIBUTE_UPGRADE_UPDATED, EVENT_CHAMPION_PURCHASE_RESULT,
  EVENT_CHAMPION_POINT_GAINED, EVENT_SKILLS_FULL_UPDATE,
  EVENT_SKILL_RANK_UPDATE, EVENT_ABILITY_PROGRESSION_RANK_UPDATE,
  EVENT_SKILL_LINE_ADDED, EVENT_HOTBAR_SLOT_UPDATED,
  EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, EVENT_LEVEL_UPDATE,
  EVENT_PLAYER_ACTIVATED. Имена events сверить по текущей документации;
  неподдержанные не регистрировать. Тяжёлые scans не запускать каждый кадр:
  coalesce обновления на 100 ms только при открытом нашем тултипе;
  preview и изменение статов перепроверять без полного scan build.
- [x] **Step 4: Подключить `/kanastats dump` и написать документацию.**
  Команда сообщает ID, `live/SavedVariables/KanaStatSources.lua` и необходимость
  `/reloadui` или выхода для записи на диск. Другой аргумент показывает краткую
  справку. README перечисляет поддержанный объём и способ анализа остатка;
  client-validation содержит действия из спецификации без утверждения,
  что они уже выполнены. Добавить новый аддон в корневой список.
- [x] **Step 5: Прогнать конечные проверки.**
  ```bash
  lua KanaStatSources/tests/run.lua
  PYTHONPATH=/tmp/kana-cooldown-test-deps python3 KanaStatSources/tests/run51.py
  lua KanaTTC/tests/test_tooltips.lua
  git diff --check
  ```
  Ожидается 0 failed/exit 0; manifest-test проверяет существование всех
  подключённых файлов, отсутствие product tests в manifest и правильные
  ресурсные пути. Повторять suites только после изменений или найденной ошибки.
- [x] **Step 6: Проверить спецификацию по реализации и review focus.**
  Проверить источники всех категорий и evidence правил, отсутствие изменения
  билда, дублирования native бонусов и скрытых отрицательных остатков.
  Независимый review выполняется по выбранному пользователем способу исполнения.
  Внести необходимые исправления и повторить затронутые проверки.
- [x] **Step 7: Scoped commit:** `feat: wire KanaStatSources runtime and diagnostic command`.
- [ ] **Step 8: Проверить клиент, если доступен, и сдать результат.**
  После `/reloadui` пройти `docs/client-validation.md`. При отсутствии
  доступного живого клиента оставить этот пункт незавершённым и явно назвать
  проверку UI/сохранения дампа непроверенной. Локальный аддон и прошедшие
  автоматические проверки можно передать пользователю для этой проверки.
  Сообщить папку, команду, остаточные ограничения покрытия и коммиты;
  не публиковать и не отправлять изменения на remote без авторизации.

## Опорные ссылки для исполнителя

- [Штатный обработчик тултипа и критического отображения](https://github.com/esoui/esoui/blob/live/esoui/ingame/stats/keyboard/zo_statentry_keyboard.lua): `ZO_StatsEntry_OnMouseEnter` и `ZO_StatsEntry_OnMouseExit`.
- [Штатные атрибуты и предпросмотр](https://github.com/esoui/esoui/blob/live/esoui/ingame/stats/zo_stats_common.lua): `GetAttributeDerivedStatPerPointValue(attributeType, STAT_TYPES[attributeType])`.
- [Текущая документация ESO API](https://github.com/esoui/esoui/blob/live/ESOUIDocumentation.txt).
- Локальные `KanaTTC/KanaTTC.lua`, `KanaTTC/tests/test_tooltips.lua`:
  дополнительные контролы и правильная очистка tooltip cells.
- Локальные `KanaWardrobe/Inventory.lua`, `KanaWardrobe/EffectModel.lua`,
  `KanaWardrobe/SkillState.lua`: чтение metadata и причины не учитывать
  готовый glyph/armor modifier дважды. Прочитать как reference, не создавать
  runtime-зависимость и не переносить неподходящие preview-расчёты целиком.
- Локальный `LibCombat/LibCombat.lua`: reference для чтения сохранённых CP,
  обеих панелей и полей эффектов; не копировать весь библиотечный код.

## Самопроверка плана

- Объём 15 статов, клавиатурный UI, локализация и предпросмотр: задачи 1, 7, 8.
- Источники, условия, проценты, активная панель и недопущение дублей: задачи 2–5.
- Итог/остаток, округление, рейтинг и формула: задача 1, end-to-end задача 8.
- Полный релевантный дамп, недоступные API, согласованность и история: задачи 2, 6, 8.
- Размер тултипа, прокрутка, очистка и отсутствие per-frame scans: задачи 7, 8.
- Автоматическая и отдельная живая проверка: задачи 1–8.

Дальнейшая реализация начинается после проверки этого плана пользователем
и выбора способа исполнения, согласно writing-plans. Рекомендуемый способ:
native execution в этой сессии, поскольку восемь задач используют общий
контракт снимка и модели, а частое переключение исполнителей не даёт
существенного выигрыша для последовательной интеграции.

## Результат выполнения 2026-10-06

Реализация и независимое ревью завершены; замечания исправлены с RED→GREEN регрессиями. Итог: 76 tests в Lua5.4 и Lua5.1, TTC186, diff check. Клиентская проверка остаётся открытой. Фикстуры провайдеров объединены рядом с тестами и в complete_build.lua; неподтверждённые условные ID-взаимодействия оставлены кандидатами и Unknown согласно fallback пользователя. Подробности и решения: KanaStatSources/docs/validation.md.
