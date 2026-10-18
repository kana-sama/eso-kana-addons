# Kana Armor Penetration Bar Implementation Plan

> Execute inline with superpowers:executing-plans; use TDD and one final
> independent review. The user's «Займись этим» authorizes implementation
> of the design already discussed. Do not add another permission loop.

**Goal:** расчётная шкала личного пробития для всего запрошенного PvE.
**Architecture:** чистая модель, снимок API, независимый HUD, LAM, lifecycle.
**Tech Stack:** Lua 5.1, ESO API 101051, LibAddonMenu-2.0.
**Spec:** `docs/superpowers/specs/2026-10-18-kana-penetration-design.md`.

## Global constraints

- Существующие аддоны не менять; только запись в общем README.
- Работать в текущем чистом jj checkout, чтобы аддон был доступен ESO.
- Новый аддон: один коммит со всеми этапами; использовать jj, без push.
- Все профили расчётные, знак `≈`; неизвестное сопротивление `?`.
- Личное пробитие и снижение сопротивления не смешивать.

## Review focus

1. Публичный данж/логово не получают профиль группового данжа.
2. Эффекты старой цели не переживают смену reticleover.
3. Дубли Breach не складываются, чужие эффекты не отбрасываются.
4. Нулевая броня, неизвестный профиль и невалидные числа не дают NaN/inf.
5. Сцены скрывают HUD, освобождают таймер; уменьшенный экран не теряет полосу.

## Task 1: Расчёт и источники

Files: `KanaPenetration/Model.lua`, `Observer.lua`, `tests/model.lua`,
`tests/observer.lua`, `tests/run.lua`.

Interfaces: Model.Profile(context, settings) -> base, source;
Model.Calculate(base, penetration, reduction) -> result;
Model.Effects(effects, lookup, settings, forceOfNature) -> reductions, bonus;
Observer.New(api):Capture(settings) -> snapshot or nil.

- [x] Написать тесты 7000/9278=75.4473%, нулевой брони, неизвестного профиля,
  9100/18200 для контекстов, дублей/истечения, разных типов, FON.
- [x] `lua KanaPenetration/tests/run.lua model`: ожидаем отказ до реализации.
- [x] Реализовать Model и Observer, используя проверенные сигнатуры API.
- [x] Запустить model + observer, ожидать ноль ошибок.

## Task 2: HUD и настройки

Files: `View.lua`, `Settings.lua`, `Core.lua`, `KanaPenetration.addon`,
`tests/harness.lua`, `tests/integration.lua`.

Interfaces: View.New(settings, russian) -> view; view:Render(snapshot),
view:Layout(), view:SetMoving(bool). Core.Initialize wires observer/view.

- [x] Написать интеграционный стенд с настоящей моделью и моками ESO только
  на границе; проверить события, сцены, таймер, переключение оружия,
  drag/persistence, разные сопротивления и уменьшение экрана.
- [x] Запустить и увидеть отказ до реализации HUD.
- [x] Создать минимальные штатные controls и настройки на персонажа.
- [x] Пройти интеграционные тесты.

## Task 3: Завершение

Files: `KanaPenetration/README.md`, общий `README.md`.

- [x] Документировать точную семантику, покрытие, оценки и один клиентский
  набор проверок; добавить описание в общий README.
- [x] Независимое ревью по requesting-code-review, устранить существенные
  замечания с регрессионными тестами.
- [x] Параллельно полный набор нового аддона, luac всех Lua и whitespace
  `jj diff --git`. Отдельно Lua 5.1, если доступен локальный интерпретатор.
- [x] Проверить `jj status`, `jj diff`; один scoped commit KanaPenetration.

## Execution ledger

- Initial: clean jj change rqnzsplx; current checkout reused, no existing
  behavior removed. Plan/spec authority is the user's approved in-chat scope.
- Pre-flight: Observer produces snapshot consumed by View; Core owns scene
  root and polling; rows keep their own visibility beneath scene root.
- Ruling: Force of Nature returns a range for invisible statuses, not a
  false exact count. LibCombat SpecialDebuffs confirms the reticle API gap.
  No full combat history or ambiguous name-based unit identity is added.
- Task 1: complete, initial RED then GREEN model/observer suites. Real
  debuff aliases retain configured strength rather than dummy defaults.
- Task 2: complete, initial RED then GREEN 16 HUD integration tests. CLI
  Lua 5.4 harness supplies Lua 5.1's global unpack, production remains 5.1.
- Final independent review: one P2 fixed. Nearby dungeon/raid entrance POI
  is not current instance membership. Added failing exterior-entrance and
  misleading-public-POI regressions, then removed compass-based inference.
  33 model and 21 observer tests pass after fix. No deferred minor findings.
- Ruling on review boundaries: native font layout, scaled drag and screen
  clamping remain ESO smoke checks. No evidence requires a separate polling
  path for attackability changes without reticle events; current lifecycle
  uses reticle/player activation/hotbar changes and polls eligible targets.
- Final validation: 70 tests passed on official Lua 5.1.5; all 10 Lua files
  parse with luac 5.1; manifest paths resolve; jj git-format diff whitespace
  clean; zero deleted existing lines. All validation commands exit 0.
  ESO rendering and real third-party debuff visibility remain untested.
