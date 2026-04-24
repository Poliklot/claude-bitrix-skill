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

## Компоненты и фронт

| Задача | Читать |
|---|---|
| доработать стандартный компонент | `standard-components-noncommerce.md`, `component-dataflow-debugging.md` |
| изменить шаблон без правки ядра | `components.md`, `templates.md` |
| вынести логику из шаблона | `php-workflow.md`, `php-legacy-modernization.md` |
| настроить `result_modifier.php` | `component-dataflow-debugging.md` |
| добавить breadcrumbs/meta | `component-dataflow-debugging.md`, `seo-cache-access.md` |
| сделать AJAX endpoint | `events-routing.md`, `security.md` |
| проверить отсутствие `local/*` | `core-audit-matrix.md`, `standard-components-noncommerce.md` |

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

## Что остаётся deferred

Интернет-магазин, цены, остатки, SKU, корзина, заказ, оплата, доставка, скидки и checkout остаются deferred до установки `catalog` и `sale`.
