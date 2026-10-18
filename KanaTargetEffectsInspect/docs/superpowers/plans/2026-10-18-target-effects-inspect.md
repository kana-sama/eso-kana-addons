# Kana Target Effects Inspect Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Пользователь запросил непрерывную реализацию без промежуточных согласований.

**Goal:** Читать иконки последней цели в режиме курсора, сохраняя штатную панель в обычном режиме.

**Architecture:** Копирование данных и геометрии готовых штатных иконок перед включением курсора; отдельный пул нативных иконок в `hudui`. Наблюдатель штатного контейнера и callbacks сцен восстанавливают обычное отображение на выходе.

**Tech Stack:** ESO API 101051, Lua 5.1, нативные сцены, шаблоны и пулы.

**Spec:** `../specs/2026-10-18-target-effects-inspect-design.md`.

## Global Constraints

- Имя `KanaTargetEffectsInspect`; заголовок `|cFF0000Kana|r Target Effects Inspect`.
- Не менять контейнер персонажа, общие пулы и настройки ESO; без команд и SavedVariables.
- Один изменяемый коммит нового аддона; только `jj`, без push.
- Продолжить в текущей чистой рабочей копии Jujutsu, где уже находится спецификация.

## Review Focus

- Потеря цели между включением UI mode и показом `hudui`: снимок должен захватываться заранее.
- Открытие меню из HUD тоже включает UI mode: снимок в меню не появляется.
- Пулы переиспользуют данные и контролы: снимок не меняется вместе с источником.
- Масштаб HUD меняет экранную геометрию: иконки остаются на тех же местах.
- Ошибка интеграции: штатные группы снова видны, чужой tooltip не закрывается.

## Task 1: Снимок и жизненный цикл

**Files:** `Native.lua`, `View.lua`, `Core.lua`, `tests/harness.lua`, `tests/integration.lua`, `tests/run.py`.

**Interfaces:** `Native.Capture(container)` возвращает копию данных/геометрии или nil; `Native.Bind(container, changed, suppress)` сохраняет штатные вызовы. `View.New()` создаёт собственный пул; `Show(snapshot)`, `Hide()`, `Update()` управляют только снимком. `Addon.Initialize(name)` подключает сцены/события один раз.

- [x] Написать тесты захвата, обоих порядков потери цели, очистки старой цели, меню, масштабирования, нулевого таймера, переиспользования и отказа API.
- [x] Запустить `python3 KanaTargetEffectsInspect/tests/run.py`, убедиться в падении из-за отсутствующей реализации.
- [x] Реализовать модули. Уход HUD в `hudui` сохраняет иконки до смены текущей сцены. Prehook `SCENE_MANAGER:SetInUIMode(true)` покрывает прямой вызов; `EVENT_GAME_CAMERA_UI_MODE_CHANGED` служит дополнительным входом. Оригинальные методы не подавляются.
- [x] Запустить набор, исправить выявленные нарушения поведения.

## Task 2: Выпуск

**Files:** `KanaTargetEffectsInspect.addon`, `README.md`, `DEVELOPMENT.md`, индекс `../README.md`.

- [x] Добавить манифест и короткий русский README с пользой игроку.
- [x] Провести отдельное ревью реализации и исправить существенные замечания с регрессионными тестами.
- [x] Параллельно проверить полный набор аддона, Lua 5.1 syntax и пробелы в `jj diff --git`; проверить соседний KanaBuffPanels для общей границы интеграции.
- [x] После проверки `jj status` и `jj diff` включить реализацию в исходный коммит `xslsrrntovtyrmuxwnnkmywkollwzkws` через scoped `jj squash --into`.

## Execution ledger

- Решение: выполнить без review gates по прямому запросу пользователя. Служебные helpers навыка используют Git; учёт и проверки выполняются вручную через Jujutsu.
- Pre-flight: View и Native используют snapshot с `icons`, `style`; Core соединяет оба модуля. Пулы снимка отделены от исходных.

- Task 1: complete. Первый RED: 0/15; GREEN: 15/15. Затем отдельные RED для реальной клавиши курсора и позднего camera event: 15 passed, 2 failed; после исправления 17/17. Финальный набор с проверкой манифеста и отказа API: 20/20, exit 0.
- Final review: независимый reviewer нашёл P1 в порядке `OnToggleHUDUIBinding`; подтверждено по штатным исходникам и исправлено через `LeavingHUD`. Других подтверждённых замечаний нет. Отрисовка, hit testing и реальная геометрия отложены до клиента — это обязательная граница локальных проверок.
- Task 2: complete. Новый аддон: 20 passed; KanaBuffPanels: 58 passed; Lua 5.1 syntax: 5 passed; diff whitespace: OK. Все команды завершились с кодом 0.
