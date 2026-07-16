# Режимы поведения

Открывай в начале задачи, если неясно, какой слой нужен. Цель — не грузить все bundles и не превращать простой вопрос в лекцию.

Главное правило: если доступен проект и вопрос практический, сначала прочитать `BITRIX_PROJECT_CONTEXT.md` при наличии, затем получить факт проекта через `project-intake.md` или `core-grep-cookbook.md`, потом отвечать.

## Решение

1. Есть Bitrix-маркер (`/bitrix`, `/local`, `CIBlock*`, `ShowHead`, `IncludeComponent`, `sale`, `catalog`, `1C`, `Битрикс`) → skill применим.
2. Пользователь пишет “у нас”, “в проекте”, “найди”, “почини”, “почему не работает” → `BITRIX_PROJECT_CONTEXT.md` при наличии, затем `project-intake.md`, затем `task-playbooks.md` для типовых маршрутов.
3. Короткое “как сделать X” → `developer-primitives` + `first-answer-pitfalls` + `developer-cards` + `answer-contracts`.
4. Симптом отладки → `core-grep-cookbook` + релевантный compact bundle.
5. `sale`/`catalog`/`1C` → сначала module check, затем commerce bundle.
6. “Как правильно/best practices/куда класть” → production sections в `php-architecture`/`core-routing`.
7. `header.php`/`footer.php`/`.section.php`/include → `project-layout-and-includes`.
8. `.env`/`Option`/ID/dev-stage drift → `project-configuration`.
9. Release/publish → `release-gate`.

## Режимы

| Режим | Триггер | Что загрузить | Что выдать |
|---|---|---|---|
| Бытовой ответ | meta/title, CSS/JS, includes, breadcrumbs, request, user, image, iblock property, cache, mail | primitives, pitfalls, cards, contracts; grep по проекту, если repo доступен | Механизм, проверки проекта, минимальный пример, side effects. |
| Проектная правка | “найди где”, “почини”, “у нас” | project-intake, task-playbooks, core-grep, domain bundle | Конкретный file/layer, причина, patch или next action. |
| Диагностическая цепочка | “не выводится”, “не обновляется”, “404 200”, “письмо не уходит” | core-grep + diagnostics/domain bundle | Source → params → template/result → cache/rights/index/logs. |
| Component/template | IncludeComponent, template, `$arResult` | components-admin-ui | Params/template/result_modifier/component_epilog/local component. |
| Структура/include | public root, `.section.php`, header/footer/index, `main.include`, “куда положить” | project-layout-and-includes + project-intake | Active layer, placement, convention, cache/edit/multisite checks. |
| Конфигурация/ID | `.env`, `Option`, constants, `IBLOCK_ID`, dev/stage/prod | project-configuration + php/content bundles | Value class, source, validation, stable-key scope, error/cache contract. |
| Production practice | “как правильно”, architecture, safe customization | php-architecture/core-routing | local module/service/migration/event, verification. |
| Зависит от модуля | iblock/form/catalog/sale/currency/rest/bizproc/pull | module check + domain bundle | API route, если модуль есть; fallback/deferred, если отсутствует. |
| Shop/1C | SKU, prices, stocks, basket, order, CommerceML | commerce-shop после module check | API-only route с recalculation/events/exchange side effects. |
| Изменение данных | direct DB/content/rights/file/admin change | SKILL confirmation block | Спросить подтверждение до mutation. |
| Release | push/tag/release/MCP Market | release-gate/eval-prompts | Validate, eval, file count, changelog/version sync. |

## Не делать

- Отвечать общей теорией, когда доступны факты проекта.
- Загружать много bundles до выбора режима.
- Давать длинную архитектурную лекцию на короткий бытовой вопрос.
- Начинать с чистого PHP/SQL/core edit.
- Предполагать наличие optional modules.
- Советовать global cache-off до диагностики слоя кеша.
