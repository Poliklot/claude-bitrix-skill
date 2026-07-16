# Режимы поведения Bitrix skill

Открывай этот файл в начале задачи, если неясно, какой слой skill нужен: бытовой ответ, диагностика, патч, production-архитектура, shop/1C или release-gate. Цель — не грузить всё подряд и не превращать простой вопрос в лекцию.

Главное правило: **если доступен проект, сначала получить факт проекта, потом отвечать**. Исключение — пользователь явно просит общую справку без привязки к проекту.

## Решение за 30 секунд

1. Есть ли в задаче Bitrix-маркер (`/bitrix`, `/local`, `CIBlock*`, `ShowHead`, `IncludeComponent`, `sale`, `catalog`, `1C`, `Битрикс`)? Если да — skill применим.
2. Есть ли доступ к репозиторию проекта? Если да — для практической задачи сначала прочитать `BITRIX_PROJECT_CONTEXT.md` при наличии, затем открыть [project-intake.md](project-intake.md) или взять узкий grep из [core-grep-cookbook.md](core-grep-cookbook.md), затем для типового маршрута открыть [task-playbooks.md](task-playbooks.md).
3. Вопрос короткий “как сделать X”? Открыть бытовой слой: [developer-primitives.md](developer-primitives.md), [first-answer-pitfalls.md](first-answer-pitfalls.md), [developer-cards.md](developer-cards.md), [answer-contracts.md](answer-contracts.md).
4. Вопрос “почему не работает”? Открыть debug/domain reference и идти по цепочке source → params → template/result → cache/rights/index.
5. Вопрос про `sale`/`catalog`/`1C`? Сначала module check, потом shop/1C reference.
6. Вопрос “как правильно/куда класть/лучшие практики”? Открыть production layer.
7. Вопрос про `header.php`/`footer.php`/`.section.php`/include? Открыть [project-layout-and-includes.md](project-layout-and-includes.md).
8. Вопрос про `.env`/`Option`/ID/разные стенды? Открыть [project-configuration.md](project-configuration.md).
9. Вопрос “релизим/пушим”? Открыть [release-gate.md](release-gate.md).

## Режимы

| Режим | Триггеры | Что открыть | Что выдать |
|---|---|---|---|
| Бытовой ответ | “как в PHP”, meta/title, CSS/JS, IncludeFile, breadcrumbs, request, user, image, iblock property, cache, mail | `developer-primitives`, `first-answer-pitfalls`, `developer-cards`, `answer-contracts`; при проекте — `core-grep-cookbook` | Короткий Bitrix-native ответ: механизм, где проверить, минимальный пример, side effects. |
| Проектная правка | “найди где”, “почини”, “почему у нас”, “в этом проекте” | `project-intake`, `task-playbooks`, затем узкий domain reference | Конкретный файл/параметр, причина, патч или next action. |
| Диагностическая цепочка | “не выводится”, “в админке есть, на сайте нет”, “404 отдаёт 200”, “письмо не уходит” | `core-grep-cookbook`, domain diagnostics | Проверки по цепочке и вероятная точка отказа; не начинать с cache-off. |
| Component/template | `IncludeComponent`, шаблон, `$arResult`, `result_modifier`, `component_epilog` | `components`, `templates`, `component-dataflow-debugging`, `core-grep-cookbook` | Где править: params/template/result_modifier/component_epilog/local component. |
| Структура/include | public root, `.section.php`, `header.php`, `footer.php`, `index.php`, `main.include`, `IncludeFile`, “куда положить” | `project-layout-and-includes`, `project-intake`, `templates`, `components` | Фактический active layer, placement, project convention, cache/edit/multisite checks. |
| Конфигурация/ID | `.env`, `Option`, constants, `IBLOCK_ID`, `FORM_ID`, dev/stage/prod | `project-configuration`, `project-intake`, `production-best-practices`, domain reference | Класс значения, источник, validation, stable-key scope, missing/duplicate/cache contract. |
| Production practice | “как правильно”, “архитектура”, “куда класть”, “best practices”, “не сломать обновления” | `production-best-practices`, `pitfalls-matrix`, `php-workflow`, domain reference | Решение через local module/service/migration/event, side effects, verification. |
| Зависит от модуля | `iblock`, `highloadblock`, `form`, `sale`, `catalog`, `currency`, `rest`, `bizproc`, `pull` | Module version check, then relevant reference | Если module есть — API route; если нет — ограничение/fallback. |
| Shop/1C | товары, SKU, цены, остатки, заказ, корзина, доставка, оплата, 1С, CommerceML | `shop-task-matrix`, `catalog`, `sale`, `currency`, `commerce-1c-integration` after checks | API-only route, side effects: events, recalculation, stock, discounts, exchange. |
| Опасные данные | Прямое изменение БД/контента/прав/файлов/админки | `SKILL.md` confirmation block | Сначала подтверждение операции, объекта, изменений и обратимости. |
| Skill/release | Обновить skill, release, MCP Market, publish | `release-gate`, `eval-prompts` | Validate, eval, file count, changelog/version sync. |

## Project-first правило

Если пользователь спрашивает о реальном проекте, не отвечай “обычно в Битриксе” как финал. Сделай минимум:

```text
1. Найти public root / template / component call.
2. Проверить локальный слой `local/*`.
3. Проверить наличие нужного module.
4. Назвать найденный файл или честно сказать, что не найден.
```

После этого ответ:

```text
В этом проекте найдено: [fact].
Править нужно: [file/layer].
Не нужно: [anti-pattern].
Проверить после: [cache/page/test].
```

## Когда не грузить весь skill

- Короткий вопрос про meta/CSS/request/user/image → бытовой слой + 1 grep, не shop/production.
- Вопрос про `sale` без подтверждённого модуля → module check, не весь commerce bundle.
- Вопрос про “как правильно” без конкретного module → production layer, не все domain references.
- Вопрос “где поменять верстку компонента” → components/templates/dataflow, не iblocks/sale.
- Вопрос “куда положить блок” → project layout + факты active template, не универсальная `/include`-схема.
- Вопрос “куда вынести ID” → project configuration + migration/stable key, не автоматический `.env`/Composer.
- Вопрос “форма не шлёт письмо” → webforms/mail/agents/logs, не SEO/catalog.

## Ответные формы

Используй [answer-contracts.md](answer-contracts.md) как формат. Важное:

- простой вопрос — не больше 4 смысловых блоков;
- debug — цепочка проверок;
- project task — сначала найденный факт;
- code task — production-ready snippet;
- optional module — сначала module check;
- data mutation — подтверждение.

## Ошибки поведения

Избегай:

- отвечать общей теорией при доступном проекте;
- открывать 5–10 reference-файлов до понимания режима;
- давать длинную лекцию на вопрос “куда вставить title”;
- предлагать чистый PHP/SQL/правку ядра первым вариантом;
- обещать наличие `catalog`/`sale`/`currency`/`bizproc` без проверки;
- говорить “очисти весь кеш” до диагностики слоя кеша;
- давать “кликни в админке” как единственный путь, если нужна воспроизводимая разработка.
