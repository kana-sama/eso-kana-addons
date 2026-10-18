# Kana Lazy Set Crafter Auto Hide Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan.

**Goal:** Начальная видимость по очереди и ручная кнопка Set Crafter у станка.
**Architecture:** Один Lua-модуль над существующим окном, отдельная штатная
группа кнопок, замена только входного события зависимости.
**Tech Stack:** ESO Lua, native keybind strip, Lua behavioral harness, Jujutsu.
**Spec:** `docs/superpowers/specs/2026-10-18-kana-lazy-set-crafter-auto-hide-design.md`.

## Global Constraints

- `KanaLazySetCrafterAutoHide`, `DolgubonsLazySetCrafter>=3080`, API `101050 101051`.
- Существующая рабочая копия Jujutsu чистая, `@` — отдельный изменяемый
  потомок `main`; работать здесь, не создавать дополнительный checkout.
- Сохранить ручное управление, внутренний UI и настройки зависимости.
- Все файлы нового аддона и документация — один коммит, без push.

## Review Focus

- Повторный вход на консолидированном станке не сбрасывает ручной выбор.
- Исходные настройки автопоказа не перекрывают правило очереди.
- Кнопка исчезает вне сцен крафта и не дублируется при повторном показе.
- Чужие обработчики и исходный обработчик выхода остаются действующими.
- Отсутствие зависимости не приводит к частичной установке перехвата.

## Task 1: Надстройка и регрессионный стенд

**Files:** `KanaLazySetCrafterAutoHide/KanaLazySetCrafterAutoHide.lua`,
`KanaLazySetCrafterAutoHide/KanaLazySetCrafterAutoHide.addon`, `KanaLazySetCrafterAutoHide/tests/test.lua`,
`KanaLazySetCrafterAutoHide/README.md`, корневой `README.md`.
**Interfaces:** `KanaLazySetCrafterAutoHide.Initialize(api)` устанавливает интеграцию;
внешние точки взаимодействия — события, сцены и существующий `close`.

- [x] Написать тесты наблюдаемого поведения из спеки и Review Focus.
- [x] Запустить `lua KanaLazySetCrafterAutoHide/tests/test.lua`: подтвердить отсутствие
  требуемого поведения до реализации.
- [x] Реализовать начальную видимость, кнопку и безопасную инициализацию.
- [x] Обновить README с поведением, зависимостью и единым клиентским сценарием.
- [x] Выполнить независимые проверки параллельно: весь набор нового аддона,
  `luac -p` всех новых Lua-файлов, whitespace по `jj diff --git`.
- [x] Проверить изменения, пройти независимое ревью, исправить реальные
  замечания с регрессионными тестами.
- [x] После `jj status` и `jj diff` создать один коммит `KanaLazySetCrafterAutoHide: ...`.

## Результат выполнения

28 тестов успешны, включая три проверки с установленным `SetCrafter.lua`.
Синтаксис двух Lua-файлов, пути манифеста и whitespace diff проверены.
Независимое ревью выявило пропуск геймпадных сцен рецептов; воспроизведено
тестом (27 passed, 1 failed), исправлено (28 passed, 0 failed).
Проверка отрисовки и ввода в ESO остаётся клиентской.
