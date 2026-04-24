# Core Audit Matrix без магазина — справочник

> Reference для Bitrix-скилла. Загружай, когда нужно понять, что реально установлено в текущем core, какие домены активны, какие условны, и куда вести задачу без `catalog`/`sale`.
>
> Матрица основана на текущем checkout `www/bitrix` и должна обновляться после установки новых модулей.

## Содержание
- Быстрые проверки
- Активные модули текущего core
- Условные и отложенные домены
- Ловушки текущего core
- Покрытие reference-файлами
- Как обновлять матрицу

## Быстрые проверки

```bash
find www/bitrix/modules -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort

find www/bitrix/modules -maxdepth 3 -path '*/install/version.php' -print | sort

find www/bitrix/modules -path '*/install/components/bitrix/*/.parameters.php' -print \
  | sed 's#.*/install/components/bitrix/##; s#/.parameters.php##' \
  | sort
```

Для `main` не требуй `www/bitrix/modules/main/install/version.php`: в текущем core у него есть `classes/general/version.php`, а не обычный `install/version.php`.

## Активные модули текущего core

| Модуль | Статус | Основной reference | Что проверять первым |
|---|---|---|---|
| `main` | active | `modules-loader.md`, `orm.md`, `session-auth.md`, `database-layer.md`, `access-rbac.md` | `lib/`, `classes/general`, компоненты `main.*`, user/session/cache/ORM |
| `iblock` | active | `iblocks.md`, `iblock-hl-relations.md`, `entities-migrations.md` | `install/components/bitrix`, properties, sections, UF, legacy + D7 |
| `highloadblock` | active | `highloadblock.md` | dynamic ORM, rights, UI selector, relation to iblock directory |
| `form` | active | `webforms.md`, `standard-components-noncommerce.md` | form/result/status/validators/handlers/CRM link, stock templates |
| `blog` | active | `blog-socialnet.md`, `standard-components-noncommerce.md` | `CBlog*` write path, D7 read-only tables, templates, search reindex |
| `forum` | active | `forum.md`, `standard-components-noncommerce.md` | `CForum*`, forum components, permissions, topic/message flow |
| `vote` | active | `vote.md`, `standard-components-noncommerce.md` | `CVote*`, channels/questions/answers, `voting.*` components |
| `subscribe` | active | `subscribe.md`, `mail-notifications.md` | rubrics, subscriptions, postings, templates |
| `search` | active | `search.md`, `index-cache-diagnostics.md` | `CSearch`, title search, `BeforeIndex`, URL generation, rights |
| `seo` | active | `seo-cache-access.md`, `index-cache-diagnostics.md` | sitemap, robots/noindex, canonical, OpenGraph, SEO admin tools |
| `landing` | active | `landing.md`, `standard-components-noncommerce.md` | Site/Landing/Block/Hook/Rights, mutator mode, templates |
| `bitrix.sitecorporate` | active | `sitecorporate.md`, `standard-components-noncommerce.md` | wizard shell, `corp_furniture`, public skeleton, stock `furniture.*` |
| `fileman` | active | `fileman.md`, `templates.md` | editor, address/map/video fields, visual assets |
| `location` | active | `location.md`, `fileman.md` | address/location services, formats, widgets |
| `messageservice` | active | `messageservice.md`, `mail-notifications.md` | SMS providers, limits, callbacks, REST |
| `socialservices` | active | `socialservices.md`, `users.md` | OAuth providers, user links, auth flow |
| `rest` | active | `rest.md`, `events-routing.md` | REST methods/events/webhooks/OAuth |
| `security` | active | `security.md`, `diagnostic-visibility.md` | WAF, OTP/MFA, redirect/IP rules, scanner/checker |
| `perfmon` | active | `perfmon.md`, `operations-runbook.md` | SQL/hit/cache diagnostics, schema/index insights |
| `clouds` | active | `clouds.md`, `file-upload-modern.md` | external storage, `HANDLER_ID`, resize/src/MakeFileArray |
| `bitrixcloud` | active | `bitrixcloud.md`, `operations-runbook.md` | backup policy, monitoring, mobile inspector |
| `mobileapp` | active | `mobileapp.md`, `standard-components-noncommerce.md` | admin mobile, JN/native components, push settings |
| `b24connector` | active | `b24connector.md` | remote portal binding, buttons, openline info, site restrictions |
| `translate` | active | `translate.md` | lang files, phrase index, CSV import/export, UI |
| `photogallery` | active | `photogallery.md`, `blog-socialnet.md`, `forum.md` | gallery root section, albums, upload, comments |
| `ui` | active | `grid-admin-modern.md`, `file-upload-modern.md` | grid/filter/uploader/entity selector |

## Условные и отложенные домены

| Домен | Почему отложен | Что делать в ответе |
|---|---|---|
| `catalog` module | модуля `www/bitrix/modules/catalog` нет | не вести задачу в торговый каталог; если вопрос про `catalog.*` component, проверить владельца компонента |
| `sale` module | модуля `www/bitrix/modules/sale` нет | не обещать корзину/заказ/оплаты/доставку |
| `bizproc` | модуля нет | держать `workflow.md` как deferred |
| `pull` | модуля нет | не строить realtime/push route на `pull` |
| `socialnet` | модуля нет | использовать только условную часть `blog-socialnet.md` после подтверждения |

## Ловушки текущего core

- `catalog.*` стандартные компоненты физически лежат в `www/bitrix/modules/iblock/install/components/bitrix`, но это не доказывает наличие модуля `catalog`.
- `corp_furniture` wizard может ссылаться на `bitrix:catalog`, но это skeleton решения, а не подтверждение установленного магазинного core.
- Отсутствие `www/local` означает, что следующий слой истины — stock component templates, `bitrix/templates/*` и wizard assets.
- Vendor-файлы внутри `www/bitrix/modules/main/vendor/*` не являются project tooling.
- Наличие JS test directories в core не означает, что PHP test contour проекта настроен.

## Покрытие reference-файлами

| Зона | Статус покрытия | Файлы |
|---|---|---|
| Core/modules/components | full-route | `core-audit-matrix.md`, `standard-components-noncommerce.md` |
| Diagnostics | full-route | `diagnostic-visibility.md`, `index-cache-diagnostics.md`, `component-dataflow-debugging.md` |
| PHP architecture/testing/quality | full-route | `php-workflow.md`, `php-testing.md`, `php-quality.md`, `php-legacy-modernization.md` |
| Content modules | active | `iblocks.md`, `highloadblock.md`, `webforms.md`, `blog-socialnet.md`, `forum.md`, `vote.md`, `subscribe.md` |
| Search/SEO/cache | active | `search.md`, `seo-cache-access.md`, `cache-infra.md`, `index-cache-diagnostics.md` |
| Admin/ops | active | `admin-ui.md`, `operations-runbook.md`, `perfmon.md`, `update-stepper.md` |
| Commerce | deferred | `catalog.md`, `sale.md`, `commerce-workflows.md` |

## Как обновлять матрицу

После установки новых модулей:

1. повторно снять список `www/bitrix/modules`;
2. проверить `install/version.php` или модульный аналог версии;
3. найти компоненты и stock templates;
4. обновить эту матрицу и `SKILL.md`;
5. снять deferred-флаг только для реально появившегося модуля.
