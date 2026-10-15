"""Aggregate the production Lua simulation; stdlib only, no fitting or fixture editing."""
import argparse
import csv
import math
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('files', nargs='+', type=Path)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
rows = []
for path in args.files:
    part = list(csv.DictReader(path.open()))
    if not part or len(part) % 120 or any(r.get('protocol') != '2' for r in part):
        raise SystemExit(f'{path}: need complete run/type rows of visible-glyph protocol 2')
    rows += part
keys = {'scenario', 'mode'}
for r in rows:
    for key in r.keys() - keys:
        r[key] = float(r[key])
        if not math.isfinite(r[key]):
            raise SystemExit('non-finite metric')
expected = {(s, seed, 'mixed') for s in ('stable', 'context', 'stacks', 'cycle', 'equal', 'drift', 'skew') for seed in (73, 271, 2027, 8191)}
expected |= {('stable', 101, mode) for mode in ('two', 'three')}
actual = {(r['scenario'], r['seed'], r['mode']) for r in rows}
if actual != expected or len(rows) != 30 * 120:
    raise SystemExit('need exactly 28 seeded experiments and two offer-count controls')
for key in actual:
    subset = [r for r in rows if (r['scenario'], r['seed'], r['mode']) == key]
    if {(r['run'], r['type']) for r in subset} != {(run, t) for run in range(1, 61) for t in (0, 1)}:
        raise SystemExit('missing or duplicate run/type')

def collect(scenario='stable', first=1, last=60, mode='mixed', buff=None):
    selected = [r for r in rows if r['scenario'] == scenario and r['mode'] == mode and first <= r['run'] <= last and (buff is None or r['type'] == buff)]
    return {key: sum(r[key] for r in selected) for key in rows[0].keys() - keys}

def ratio(data, n, d):
    return data[n] / data[d] if data[d] else 0

def percent(data, n, d):
    return f'{100 * ratio(data, n, d):.1f}%' if data[d] else '—'

out = ['# KanaArchiveAssist: симуляция темпа обучения', '',
       'Воспроизводимая проверка фактической продуктовой Lua-модели v3. Это синтетические предпочтения на реальном каталоге IDs, а не измерение точности на пользовательских ранах.', '',
       '## Протокол', '',
       '- 111 способностей: 54 строфы и 57 видений из установленного ArchiveHelper на 2026-10-15. Четыре аватарные строфы допускаются после трёх соответствующих частей. Каталог — тестовая копия; точные серверные веса выпадения неизвестны.',
       '- 60 ранов по две полные арки: 20 выборов строф и 10 видений. Видения и стаки накапливаются из собственных выборов симулированного пользователя и сбрасываются между ранами. Дополнительные источники и перебросы не моделируются.',
       '- Обычный режим: 70% предложений из трёх вариантов, 30% из двух; случайно выбирается по одному перку из доступных offense/defense/utility buckets. Это допущение, а не измеренная частота. Отдельно проверены только пары и только тройки.',
       '- Учитель задаёт персональную склонность для каждого ID; решения случайны по softmax плюс 10% равномерных экспериментов. Контекст содержит пороги, насыщение и совместное действие видений, которые не полностью совпадают с признаками обучаемой модели.',
       '- Seed 17 использован в исследовательском прототипе. Seeds73,271,2027,8191: 28 экспериментов; два контроля seed 101 — всего 30 экспериментов, 1800 ранов, 54000 выборов. Эти же сценарии использовались при сравнении версий алгоритма: это воспроизводимый стенд, не слепое испытание на неизвестном распределении.',
       '- Каждый прогноз сделан до записи соответствующего выбора. Первые два рана модель обновляется после каждого выбора, затем между ранами; это консервативное приближение к более частому игровому обновлению. Разогрев и трудные переходные участки не исключены.',
       '- Калибровка экспертов использует последнюю четверть целых прошлых ранов, исключённых из проверочных fit, с временным отсечением. После выбора весов эксперты обучаются на всей прошлой истории. Новые тестовые выборы в калибровку ещё не попадают.', '',
       '## Что измеряется', '',
       '**Метка** — любая информация о знакомом перке, включая жёлтую линию. **Зелёный вариант** — предложение с хотя бы одним реально показанным зелёным шевроном; это отдельный, более строгий показатель применимости совета. **Удачный совет** — выбор одного из вариантов с наибольшим видимым зелёным grade, чья истинная склонность отстаёт от лучшей не более чем на 0,3. При одинаковых видимых метках результат усредняется по ним; скрытый score не используется. Для сравнения случайный выбор оценивается на тех же предложениях.', '',
       'Высокая доля меток не означает высокую точность. У неизвестных перков меток нет. Истинная склонность известна только симулятору; процент удачных советов не является прогнозом персональной точности аддона.', '',
       '## Начало обучения', '',
       'Каждая строка — среднее по четырём seeds за указанный день, а не накопленная точность с первого дня. Количество ранов в день меняет календарную шкалу; модель стареет по обучающим ранам, а не календарю.', '']
for pace in (1, 2):
    out += [f'### {pace} ран(а) в день', '', '| День | Строфы с меткой | Видения с меткой | Предложения с зелёным | Удачный совет | Случайный выбор |', '| --- | ---: | ---: | ---: | ---: | ---: |']
    for day in (1, 3, 7, 14, 30):
        first, last = (day - 1) * pace + 1, day * pace
        d = collect(first=first, last=last)
        verses = collect(first=first, last=last, buff=0)
        visions = collect(first=first, last=last, buff=1)
        out.append(f'| {day} | {percent(verses,"shown","slots")} | {percent(visions,"shown","slots")} | {percent(d,"picks","offers")} | {percent(d,"hits","picks")} | {percent(d,"randomHits","picks")} |')
    out.append('')
out += ['## Разные предпочтения: последние семь из 60 ранов', '',
        '| Сценарий | Метки | Предложения с зелёным | Удачный совет | Случайный выбор | Ложные направления / все метки |',
        '| --- | ---: | ---: | ---: | ---: | ---: |']
names = {'stable': 'Общая привычка', 'context': 'Смена выбора из-за видений', 'stacks': 'Видения и повторные стаки', 'cycle': 'Сильные циклы между перками', 'equal': 'Полное безразличие', 'drift': 'Разворот привычек после 30-го рана', 'skew': 'Редкие предложения'}
for scenario, title in names.items():
    d = collect(scenario, 54, 60)
    false = 100 * (d['opposite'] + d['spurious']) / max(1, d['shown'])
    out.append(f'| {title} | {percent(d,"shown","slots")} | {percent(d,"picks","offers")} | {percent(d,"hits","picks")} | {percent(d,"randomHits","picks")} | {false:.1f}% |')
out += ['', 'Ложным направлением здесь считается знак, противоположный роли в известной истинной модели, либо стрелка там, где истинная роль нейтральна. Это строгая проверка, в том числе у границ градаций. В случае безразличия все варианты одинаково хороши, поэтому 100% удачных советов ничего не доказывают; важна доля лишних стрелок.', '',
        '## Качество вероятностного прогноза', '',
        'NLL — средняя отрицательная логарифмическая вероятность реального следующего выбора; меньше лучше. Базовый контроль — тот же регуляризованный общий рейтинг без контекстных коэффициентов. Результат включает все предложения и не зависит от того, был ли зелёный вариант.', '',
        '| Сценарий, раны 31–60 | Смесь | Общий рейтинг |', '| --- | ---: | ---: |']
for scenario, title in names.items():
    d = collect(scenario, 31, 60)
    out.append(f'| {title} | {ratio(d,"nll","n"):.4f} | {ratio(d,"baseNll","n"):.4f} |')
out += ['', '### Переход после смены привычек', '', '| Раны | Предложения с зелёным | Удачный совет | Случайный выбор |', '| --- | ---: | ---: | ---: |']
for first, last in ((31, 40), (41, 50), (51, 60)):
    d = collect('drift', first, last)
    out.append(f'| {first}–{last} | {percent(d,"picks","offers")} | {percent(d,"hits","picks")} | {percent(d,"randomHits","picks")} |')
out += ['', '### Полностью два или три варианта, раны 24–30', '', '| Режим | Метки | Предложения с зелёным | Удачный совет | Случайный выбор |', '| --- | ---: | ---: | ---: | ---: |']
for mode in ('two', 'three'):
    d = collect(first=24, last=30, mode=mode)
    out.append(f'| {mode} | {percent(d,"shown","slots")} | {percent(d,"picks","offers")} | {percent(d,"hits","picks")} | {percent(d,"randomHits","picks")} |')
# Predefined pragmatic checks; diagnostics never drop failed scenarios.
day3 = collect(first=3, last=3)
week = collect(first=1, last=7)
late = collect(first=15, last=30)
equal = collect('equal', 31, 60)
checks = [
    ('К третьему рану метка есть минимум у половины вариантов', ratio(day3,'shown','slots') >= .5),
    ('За первые 7 ранов зелёный совет есть минимум в четверти предложений, его сожаление минимум на 20% меньше случайного выбора', week['picks'] >= .25 * week['offers'] and ratio(week,'regret','picks') <= .8 * ratio(week,'randomRegret','picks')),
    ('На ранах 15–30 обычного сценария NLL не хуже общего рейтинга более чем на 0,03', ratio(late,'nll','n') <= ratio(late,'baseNll','n') + .03),
    ('На полном безразличии после 30 ранов стрелки занимают менее 25% меток', ratio(equal,'directions','shown') < .25),
]
out += ['', '## Критерии проверки', '']
for title, ok in checks:
    out.append(f'- {"PASS" if ok else "FAIL"}: {title}.')
out += ['', '## Ограничения', '',
        'Предложения, любимые способности и сила контекстных эффектов могут отличаться от настоящей игры. Это сценарный прогноз скорости обучения, не гарантия срока или точности. Особенно сложны редкие нетранзитивные пары, полностью новая синергия и резкая смена привычек; отдельный профиль помогает разделять разные задачи. Ранние стрелки предварительные. Жёлтая линия означает отсутствие различия в текущей оценке, а не доказанное равенство.', '',
        'CLI-симуляция не проверяет события, доверенность вызовов, расположение, отрисовку и задержки в ESO. Для этого нужна клиентская приёмка.', '',
        '## Воспроизведение', '',
        'Сохранённые сырые итоги 3600 строк находятся в `fixtures/simulation-results.csv`. Восстановить этот отчёт без повторного обучения: `python3 KanaArchiveAssist/tests/simulation_report.py KanaArchiveAssist/tests/fixtures/simulation-results.csv --output KanaArchiveAssist/tests/simulation-report.md`.', '',
        'Из корня репозитория запустить `benchmark.lua <scenario> <seed> mixed` в отдельный CSV для каждой пары из 7 сценариев и 4 seeds, затем `stable 101 two` и `stable 101 three`. Все 30 CSV передать `python3 KanaArchiveAssist/tests/simulation_report.py /tmp/kaa-final-*.csv --output KanaArchiveAssist/tests/simulation-report.md`. Протокол 2 использует только видимые шевроны при оценке советов.', '']
args.output.write_text('\n'.join(out))
for title, ok in checks:
    print(f'{"PASS" if ok else "FAIL"}: {title}')
print(f'30 experiments, 54000 choices; report: {args.output}')
raise SystemExit(0 if all(ok for _, ok in checks) else 1)
