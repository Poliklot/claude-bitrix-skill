# Non-Commerce Task Matrix — справочник

> Reference для Bitrix-скилла. Загружай, когда нужно быстро сопоставить типовую или нетиповую задачу без интернет-магазина с правильными reference-файлами.

## Содержание
- Контент и структура
- Компоненты и фронт
- Поиск, SEO, кеш
- Пользователи и доступ
- Формы, уведомления, подписки
- Интеграции и эксплуатация
- PHP/project quality
- Production practices / pitfalls / runtime

## Контент и структура

| Задача | Читать |
|---|---|
| создать/изменить инфоблок | `iblocks.md`, `entities-migrations.md` |
| добавить свойства и UF | `iblocks.md`, `custom-uf-types.md` |
| связать iblock и HL | `iblock-hl-relations.md`, `highloadblock.md` |
| импортировать CSV/XML/JSON | `import-export.md`, `operations-runbook.md` |
| обновить файлы и картинки | `import-export.md`, `file-upload-modern.md`, `clouds.md` |
| сделать миграцию структуры | `entities-migrations.md`, `operations-runbook.md` |
| “в админке есть, на сайте нет” | `diagnostic-visibility.md`, `component-dataflow-debugging.md` |
| выбрать `.env`/`Option`/constants или убрать numeric IDs | `project-configuration.md`, `entities-migrations.md`, затем domain reference |

## Компоненты и фронт

| Задача | Читать |
|---|---|
| доработать стандартный компонент | `standard-components-noncommerce.md`, `component-dataflow-debugging.md` |
| изменить шаблон без правки ядра | `components.md`, `templates.md` |
| вынести логику из шаблона | `php-workflow.md`, `php-legacy-modernization.md` |
| настроить `result_modifier.php` | `component-dataflow-debugging.md` |
| добавить breadcrumbs/meta | `component-dataflow-debugging.md`, `seo-cache-access.md` |
| исправить пустую/дублирующую вторую страницу | `pagination.md`, `component-dataflow-debugging.md`, `iblocks.md` |
| настроить `PageNavigation`, `PAGEN_N` или “Показать ещё” | `pagination.md`, `components.md`, `grid-admin-modern.md` |
| сделать AJAX endpoint | `events-routing.md`, `security.md` |
| проверить отсутствие `local/*` | `core-audit-matrix.md`, `standard-components-noncommerce.md` |
| решить, где разместить page/include/global block | `project-layout-and-includes.md`, `templates.md`, `components.md` |

## Поиск, SEO, кеш

| Задача | Читать |
|---|---|
| товар/страница не в поиске | `search.md`, `index-cache-diagnostics.md` |
| настроить быстрый поиск | `search.md`, `events-routing.md` |
| canonical/noindex/robots | `seo-cache-access.md` |
| sitemap | `seo-cache-access.md`, `operations-runbook.md` |
| очистка кеша после изменений | `cache-infra.md`, `index-cache-diagnostics.md` |
| диагностика дублей URL | `sef-urls.md`, `seo-cache-access.md` |

## Пользователи и доступ

| Задача | Читать |
|---|---|
| регистрация/авторизация | `users.md`, `session-auth.md` |
| восстановление пароля | `users.md`, `mail-notifications.md` |
| группы и права | `access-rbac.md`, `users.md` |
| социальная авторизация | `socialservices.md`, `users.md` |
| GDPR-согласие | `userconsent.md` |
| ограничение контента по правам | `access-rbac.md`, `diagnostic-visibility.md` |

## Формы, уведомления, подписки

| Задача | Читать |
|---|---|
| веб-форма | `webforms.md`, `standard-components-noncommerce.md` |
| custom validator | `webforms.md`, `validation.md` |
| форма отправляется, письма нет | `webforms.md`, `mail-notifications.md` |
| SMS/Telegram-like route | `messageservice.md`, `rest.md` |
| подписки и рассылки | `subscribe.md`, `mail-notifications.md` |
| secure file access in form | `webforms.md`, `file-upload-modern.md` |

## Интеграции и эксплуатация

| Задача | Читать |
|---|---|
| REST webhook/method | `rest.md`, `events-routing.md` |
| Bitrix24 connector | `b24connector.md`, `socialservices.md` |
| external file storage | `clouds.md` |
| backup/monitoring | `bitrixcloud.md`, `operations-runbook.md` |
| performance diagnostics | `perfmon.md`, `operations-runbook.md` |
| перенос стендов | `operations-runbook.md`, `entities-migrations.md` |
| agents/cron/stepper | `update-stepper.md`, `operations-runbook.md` |

## PHP/project quality

| Задача | Читать |
|---|---|
| разложить PHP-код по слоям | `php-workflow.md`, `modules-loader.md` |
| покрыть проверками | `php-testing.md` |
| настроить/использовать phpstan/psalm/fixer | `php-quality.md` |
| модернизировать legacy | `php-legacy-modernization.md` |
| не сломать Bitrix-boundary | `php-workflow.md`, `component-dataflow-debugging.md` |
| проверить vendor noise | `php-testing.md`, `php-quality.md` |
| спроектировать production-safe доработку | `production-best-practices.md`, затем domain reference |
| понять, куда класть код | `production-best-practices.md`, `php-workflow.md`, `modules-loader.md` |
| определить config/bootstrap/stable-key registry | `project-configuration.md`, `production-best-practices.md`, `entities-migrations.md` |

## Production practices / pitfalls / runtime

| Задача | Читать |
|---|---|
| “как правильно сделать” | `production-best-practices.md`, затем профильный reference |
| “какие подводные камни” | `pitfalls-matrix.md`, затем профильный reference |
| “можно считать production-ready?” | `runtime-smoke-verification.md`, `php-testing.md`, профильный reference |
| release/update checklist | `production-best-practices.md`, `operations-runbook.md`, `pitfalls-matrix.md` |
| smoke без готового PHPUnit | `runtime-smoke-verification.md`, `php-testing.md`, `operations-runbook.md` |

## Commerce boundary

Этот файл остаётся роутером именно для задач **без интернет-магазина**. Если в проекте подтверждены `catalog`, `sale` и `currency`, для магазинных задач переходи в `shop-task-matrix.md`, `catalog.md`, `sale.md`, `currency.md`, `commerce-workflows.md` и `commerce-1c-integration.md`. Если модулей нет — commerce остаётся deferred и не должен подменяться `iblock`-компонентами.
