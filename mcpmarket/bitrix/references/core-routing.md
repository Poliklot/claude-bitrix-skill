# Core Routing
> MCP Market compact bundle. Source files are concatenated from `bitrix/references/*` to keep the imported skill folder below the 50-file limit.

---

## Source: `core-audit-matrix.md`

# Core Audit Matrix — active core, shop-core и deferred zones

> Reference для Bitrix-скилла. Загружай, когда нужно понять, что реально установлено в текущем core, какие домены активны, какие условны и куда вести задачу. Матрица теперь поддерживает две подтверждённые фазы: non-commerce core и отдельный shop-core для интернет-магазина/1С. Для полного списка 49 модулей shop-core, версий, coverage status и очереди доаудита смотри `shop-core-module-inventory.md`.

## 0. Фазовый принцип

Bitrix skill остаётся **core-first**, а не “версией по памяти”. Есть два подтверждённых truth layer:

1. **Non-commerce checkout** — активны контентные/системные модули, commerce был deferred.
2. **Shop-core checkout** `/Users/igormajorov/Downloads/Telegram Desktop/bitrix-shop-core` — подтверждены 49 модулей; deep baseline готов для `catalog`, `sale`, `currency`, standard shop components, shop marketing/analytics, shop automation/bizproc, `bitrix.eshop`, pagination и 1С/CommerceML components, а полный coverage status вынесен в `shop-core-module-inventory.md`.

В каждом новом пользовательском проекте сначала проверяй локальный `www/bitrix/modules`. Нельзя переносить активность `sale/catalog` из shop-core на другой проект без проверки. Cross-cutting слой для разработки и проверки: `production-best-practices.md`, `pitfalls-matrix.md`, `runtime-smoke-verification.md`.

## 1. Быстрые проверки

```bash
find www/bitrix/modules -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort

for m in main iblock currency catalog sale bizproc pull socialnet; do
  if test -f "www/bitrix/modules/$m/install/version.php"; then
    echo "--- $m ---" && sed -n '1,40p' "www/bitrix/modules/$m/install/version.php"
  elif test -f "www/bitrix/modules/$m/classes/general/version.php"; then
    echo "--- $m ---" && sed -n '1,20p' "www/bitrix/modules/$m/classes/general/version.php"
  else
    echo "MISS $m"
  fi
done
```

Для `main` не требуй обычный `install/version.php`: в проверенном shop-core версия лежит в `www/bitrix/modules/main/classes/general/version.php` (`SM_VERSION 26.150.0`).

## 2. Подтверждённый shop-core

Полный inventory всех 49 модулей, counts по components/admin/lib/classes и очередность uncovered зон хранится в `shop-core-module-inventory.md`. Ниже — краткий shop-critical срез.

Shop-core facts:

| Модуль | Версия | Статус | Reference |
|---|---:|---|---|
| `main` | `26.150.0` | active | `modules-loader.md`, `session-auth.md`, `database-layer.md`, `pagination.md` |
| `iblock` | `25.300.0` | active | `iblocks.md`, `entities-migrations.md`, `shop-standard-components.md` для `catalog.*` |
| `currency` | `26.0.0` | active shop | `currency.md` |
| `catalog` | `25.550.0` | active shop | `catalog.md`, `shop-standard-components.md` |
| `sale` | `26.0.0` | active shop | `sale.md`, `shop-standard-components.md` |
| `bitrix.eshop` | `25.0.0` | active shop solution | `shop-standard-components.md`, `commerce-workflows.md`, `shop-task-matrix.md` |
| `storeassist` | `24.0.0` | active shop assistant | `commerce-1c-integration.md`, `commerce-workflows.md` |
| `pull` | `25.300.0` | active realtime/transport in shop-core | `shop-automation-bizproc.md`, `push-pull.md` after local confirmation |
| `bizproc` | `26.200.0` | active workflow/automation in shop-core | `shop-automation-bizproc.md`, `workflow.md` after local confirmation |
| `bizprocdesigner`/`workflow`/`lists` | confirmed | active automation/list-process layer | `shop-automation-bizproc.md`, `workflow.md` |
| `sender` | `26.0.0` | active shop marketing | `shop-marketing-analytics.md`, `mail-notifications.md`, `messageservice.md` |
| `mail` | `26.100.200` | active shop marketing channel | `shop-marketing-analytics.md`, `mail-notifications.md` |
| `messageservice` | `25.200.100` | active shop SMS/provider channel | `shop-marketing-analytics.md`, `messageservice.md` |
| `subscribe` | `25.0.0` | active legacy subscriptions | `shop-marketing-analytics.md`, `subscribe.md` |
| `advertising`/`abtest`/`conversion`/`report`/`statistic` | confirmed | active analytics/ads layer | `shop-marketing-analytics.md` |
| `webservice` | `26.0.0` | active SOAP/WSDL integration extras | `shop-integrations-webservice.md`, `http.md` |
| `rest` sale/catalog hooks | `26.0.0` + module handlers | active apps/webhooks/events/placements | `shop-integrations-webservice.md`, `rest.md` |

Shop-core содержит exchange components:

- `catalog.import.1c`
- `catalog.export.1c`
- `sale.export.1c`

Admin entrypoints:

- `/bitrix/admin/1c_import.php`
- `/bitrix/admin/1c_exchange.php`
- `/bitrix/admin/1c_admin.php`
- `/bitrix/admin/sale_exchange_log.php`

## 3. Активные non-commerce модули

| Модуль | Статус | Основной reference | Что проверять первым |
|---|---|---|---|
| `main` | active | `modules-loader.md`, `orm.md`, `session-auth.md`, `database-layer.md`, `access-rbac.md`, `pagination.md` | `lib/`, `classes/general`, компоненты `main.*`, user/session/cache/ORM/navigation |
| `iblock` | active | `iblocks.md`, `iblock-hl-relations.md`, `entities-migrations.md` | components, properties, sections, UF, legacy + D7 |
| `highloadblock` | active | `highloadblock.md` | dynamic ORM, rights, UI selector |
| `form` | active | `webforms.md` | form/result/status/validators/handlers/CRM link |
| `blog` | active | `blog-socialnet.md` | `CBlog*` write path, D7 read-only tables |
| `forum` | active | `forum.md` | `CForum*`, forum components, permissions |
| `vote` | active | `vote.md` | `CVote*`, channels/questions/answers |
| `subscribe` | active | `subscribe.md`, `mail-notifications.md` | rubrics, subscriptions, postings |
| `search` | active | `search.md`, `index-cache-diagnostics.md` | `CSearch`, title search, `BeforeIndex`, rights |
| `seo` | active | `seo-cache-access.md` | sitemap, robots/noindex, canonical, OpenGraph |
| `landing` | active | `landing.md` | Site/Landing/Block/Hook/Rights, mutator mode |
| `bitrix.sitecorporate` | active | `sitecorporate.md` | wizard shell, public skeleton, stock components |
| `fileman` | active | `fileman.md` | editor, address/map/video fields |
| `location` | active | `location.md` | address/location services, formats, widgets |
| `messageservice` | active | `messageservice.md` | SMS providers, limits, callbacks |
| `socialservices` | active | `socialservices.md` | OAuth providers, user links |
| `rest` | active | `rest.md` | REST methods/events/webhooks/OAuth |
| `security` | active | `security.md` | WAF, OTP/MFA, redirect/IP rules |
| `perfmon` | active | `perfmon.md` | SQL/hit/cache diagnostics |
| `clouds` | active | `clouds.md` | external storage, `HANDLER_ID`, resize/src |
| `bitrixcloud` | active | `bitrixcloud.md` | backup policy, monitoring |
| `mobileapp` | active | `mobileapp.md` | admin mobile, JN/native components |
| `b24connector` | active | `b24connector.md` | portal binding, buttons, site restrictions |
| `translate` | active | `translate.md` | lang files, phrase index, import/export |
| `photogallery` | active | `photogallery.md` | gallery root, albums, upload, comments |
| `ui` | active | `grid-admin-modern.md`, `file-upload-modern.md` | grid/filter/uploader/entity selector |

## 4. Shop task routing

| Домен | Активируется когда | Читать |
|---|---|---|
| Товары/SKU/цены/остатки | `catalog` + `currency` есть | `catalog.md`, `shop-standard-components.md`, `currency.md`, `shop-task-matrix.md` |
| Корзина/order/checkout | `sale` + `catalog` + `currency` есть | `sale.md`, `shop-standard-components.md`, `commerce-workflows.md` |
| 1С/CommerceML | `catalog.import.1c` или `sale.export.1c` есть | `commerce-1c-integration.md` |
| Store documents | `catalog.store.document.*` есть | `catalog.md`, `commerce-workflows.md` |
| Bizproc/order automation | `bizproc` есть | `shop-automation-bizproc.md`, `workflow.md`, `sale.md` |
| Lists/process automation | `lists` + `bizproc` есть | `shop-automation-bizproc.md`, `iblocks.md` |
| Pull/realtime shop UI | `pull` есть | `shop-automation-bizproc.md`, `push-pull.md`, конкретный component |
| Eshop wizard/template | `bitrix.eshop` есть | `shop-standard-components.md`, `commerce-workflows.md`, `templates.md` |
| Маркетинг/аналитика магазина | `sender`, `messageservice`, `subscribe`, `advertising`, `abtest`, `conversion`, `report` или `statistic` есть | `shop-marketing-analytics.md`, `mail-notifications.md`, `messageservice.md`, `subscribe.md` |
| Webservice/REST integrations | `webservice`, `rest`, `webservice.sale`, `webservice.statistic`, sale/catalog REST есть | `shop-integrations-webservice.md`, `rest.md`, `http.md` |
| Production-safe план / best practices | любая архитектурная или delivery-задача | `production-best-practices.md`, затем domain reference |
| Подводные камни / symptom routing | любой production incident или “почему сломалось” | `pitfalls-matrix.md`, затем domain reference |
| Runtime smoke / “можно считать покрытым” | нужна runtime-доказательность | `runtime-smoke-verification.md`, затем domain reference |

## 5. Условные и отложенные домены

| Домен | Когда deferred | Что делать |
|---|---|---|
| `catalog` | нет `www/bitrix/modules/catalog` | не обещать цены/SKU/остатки; `catalog.*` из `iblock` считать только component-family без commerce API |
| `sale` | нет `www/bitrix/modules/sale` | не обещать basket/order/payment/delivery |
| `currency` | нет `www/bitrix/modules/currency` | не рассчитывать цены как полноценный commerce |
| `bizproc` | нет модуля | держать `workflow.md` как deferred |
| `pull` | нет модуля | не строить realtime/push route |
| `socialnet` | нет модуля | использовать только `blog`-часть `blog-socialnet.md` |
| 1С exchange | нет `catalog.import.1c`/`sale.export.1c` | описывать только generic import/export, не CommerceML route; `webservice.sale` не считать 1С exchange |

## 6. Ловушки

- Наличие `catalog.*` components внутри `iblock` или шаблонов не доказывает установленный `catalog` module.
- Наличие shop-core в одном checkout не доказывает commerce-модули в другом проекте.
- Parent product и offer — разные product IDs; цена/остаток часто живут на offer.
- `currency` обязателен для корректного понимания catalog prices и sale sums.
- `sale` side effects нельзя заменить SQL-правкой: order history, reservation, payment, shipment, cashbox, exchange.
- 1С exchange success на `file` не означает успешный import: проверяй `mode=import`, session state, tables, logs.
- Vendor-файлы внутри `www/bitrix/modules/*/vendor` не являются project tooling.
- Пагинация не сводится к `PAGEN_1`: legacy `NavNum` может породить `PAGEN_2+`, D7 использует строковый id `PageNavigation`, а `nTopCount` — это limit без полноценного NavString.
- `sender.subscribe`, `subscribe.form/edit` и `catalog.product.subscribe*` — разные подсистемы подписок, не заменяй одну другой.
- `workflow` legacy и `bizproc` workflow engine — разные подсистемы; `iblock` не должен быть одновременно `WORKFLOW=Y` и `BIZPROC=Y`.
- `bizproc` в shop-core не доказывает наличие sale-order robots: для заказов проверяй provider/CRM/custom module.

## 7. Покрытие reference-файлами

| Зона | Статус покрытия | Файлы |
|---|---|---|
| Core/modules/components | full-route | `core-audit-matrix.md`, `standard-components-noncommerce.md` |
| Diagnostics | full-route | `diagnostic-visibility.md`, `pagination.md`, `index-cache-diagnostics.md`, `component-dataflow-debugging.md`, `pitfalls-matrix.md` |
| PHP architecture/testing/quality | full-route | `production-best-practices.md`, `php-workflow.md`, `php-testing.md`, `php-quality.md`, `php-legacy-modernization.md` |
| Content modules | active | `iblocks.md`, `highloadblock.md`, `webforms.md`, `blog-socialnet.md`, `forum.md`, `vote.md`, `subscribe.md` |
| Search/SEO/cache | active | `search.md`, `seo-cache-access.md`, `cache-infra.md`, `index-cache-diagnostics.md` |
| Admin/ops/аудит оптимизаций | active | `admin-ui.md`, `grid-admin-modern.md`, `pagination.md`, `project-optimization-audit.md` (compact in `search-seo-ops.md`), `operations-runbook.md`, `perfmon.md`, `update-stepper.md` |
| Commerce/shop | active after local module confirmation | `shop-task-matrix.md`, `shop-standard-components.md`, `shop-marketing-analytics.md`, `shop-automation-bizproc.md`, `catalog.md`, `sale.md`, `currency.md`, `commerce-workflows.md` |
| 1С/CommerceML | active after component confirmation | `commerce-1c-integration.md` |
| Full shop-core inventory | routing map | `shop-core-module-inventory.md` |
| Runtime smoke evidence | verification plan, not yet runtime pass | `runtime-smoke-verification.md` |

## 8. Как обновлять матрицу

После установки новых модулей:

1. повторно снять список `www/bitrix/modules`;
2. проверить version files;
3. найти components and stock templates;
4. проверить admin entrypoints;
5. обновить эту матрицу, `SKILL.md`, `README.md`, `CHANGELOG.md`, `VERSION`;
6. снять deferred-флаг только для реально появившегося модуля.

---

## Source: `shop-core-module-inventory.md`

# Shop-core module inventory — полный снимок модулей интернет-магазина

> Reference для Bitrix-скилла. Загружай, когда нужно понять, какие модули реально есть в shop-core, что уже покрыто reference-слоем, что связано с интернет-магазином/1С, а что требует отдельного глубокого аудита перед обещаниями пользователю.

## Audit note

Truth layer: `/Users/igormajorov/Downloads/Telegram Desktop/bitrix-shop-core/www/bitrix/modules`.

Снимок сделан по 49 директориям модулей. Для каждого модуля проверялись:
- `install/version.php` или, для `main`, `classes/general/version.php`;
- `install/components/bitrix/*`;
- `admin/*.php`;
- наличие `lib/*.php`, `classes/*.php`, install/db files;
- shop/1С-сигналы в названиях components/admin entrypoints: `catalog`, `sale`, `1c`, `exchange`, `order`, `basket`, `payment`, `delivery`, `store`, `sender`, `report`, `statistic`, `conversion`, `abtest`, `advertising`, `bizproc`, `workflow`.

Этот файл — **inventory**, а не замена глубоким references. После добавления `shop-core-tail-modules.md` хвостовые модули закрыты как code-first routes, но без runtime smoke.

## Главное

Полный shop-core — это не только `catalog + sale + currency`.

В нём есть несколько слоёв:

1. **Runtime магазина** — `main`, `iblock`, `catalog`, `sale`, `currency`, `location`, `ui`, `highloadblock`.
2. **Shop solution / bootstrap** — `bitrix.eshop`, `storeassist`.
3. **1С / exchange** — `catalog.import.1c`, `catalog.export.1c`, `sale.export.1c`, sale/catalog admin endpoints, `storeassist_1c_*`; `webservice.sale` отдельно покрыт как SOAP/statistics, не CommerceML.
4. **Маркетинг и коммуникации** — `sender`, `mail`, `messageservice`, `subscribe`, `advertising`, `abtest`.
5. **Analytics / reports** — `report`, `statistic`, `conversion`, `perfmon`, `seo`.
6. **Automation** — `bizproc`, `bizprocdesigner`, `workflow`, `lists`, частично `pull`.
7. **Content/front adjacent** — `landing`, `bitrix.sitecorporate`, `form`, `blog`, `forum`, `vote`, `photogallery`, `search`.
8. **Platform/integration/safety** — `rest`, `b24connector`, `clouds`, `bitrixcloud`, `security`, `fileman`, `socialservices`, `mobileapp`, `translate`, `webservice`.

## Coverage status legend

- `covered` — уже есть отдельный reference или устойчивый слой в текущем skill.
- `covered-partial` — есть общий reference, но shop-specific часть не выделена полностью.
- `needs deep audit` — модуль есть в shop-core, но отдельный core-first reference ещё не сделан; после `shop-core-tail-modules.md` таких модулей в inventory не должно оставаться.
- `deferred per project` — даже если модуль есть в shop-core, в другом проекте активировать только после проверки `www/bitrix/modules/<module>`.

## Полная таблица модулей shop-core

| Модуль | Версия | Components | Admin | Shop/1С relevance | Coverage | Читать сейчас | Следующий шаг |
|---|---:|---:|---:|---|---|---|---|
| `abtest` | `26.0.0` | 0 | 5 | A/B тесты, отчёты, связка с conversion | covered | `shop-marketing-analytics.md` | держать вместе с conversion diagnostics |
| `advertising` | `24.200.0` | 2 | 14 | баннеры/реклама, public components `advertising.banner*` | covered | `shop-marketing-analytics.md` | держать связанным с eShop banner calls |
| `b24connector` | `25.0.0` | 2 | 9 | CRM/forms/widgets bridge, косвенно shop leads | covered | `b24connector.md`, `shop-core-tail-modules.md`, `rest.md` | shop lead/forms сценарии проверять по локальному connector route |
| `bitrix.eshop` | `25.0.0` | 3 | 1 | готовое eShop-решение, public/templates/demo data | covered | `shop-standard-components.md`, `commerce-workflows.md`, `templates.md` | держать wizard/templates связанными с shop components |
| `bitrix.sitecorporate` | `26.0.0` | 3 | 0 | corporate wizard, местами `furniture.catalog.*` | covered | `sitecorporate.md` | держать как non-shop с conditional catalog |
| `bitrixcloud` | `25.100.0` | 4 | 5 | backup/monitoring для shop runtime | covered | `bitrixcloud.md`, `operations-runbook.md` | нет срочного shop deep dive |
| `bizproc` | `26.200.0` | 49 | 8 | automation/robots/tasks, workflow engine | covered | `shop-automation-bizproc.md`, `workflow.md` | не обещать sale-order robots без provider-а |
| `bizprocdesigner` | `26.0.0` | 2 | 4 | редактор workflow templates | covered | `shop-automation-bizproc.md`, `workflow.md` | нет срочного shop deep dive |
| `blog` | `26.400.0` | 35 | 6 | комментарии/контент вокруг витрины | covered | `blog-socialnet.md` | нет срочного shop deep dive |
| `calendar` | `25.170.0` | 16 | 3 | mail/calendar side-channel, не core shop | covered | `shop-core-tail-modules.md` | соседний sync/resource/livefeed route; не checkout engine |
| `catalog` | `25.550.0` | 62 | 44 | товары, SKU, цены, склады, 1С catalog exchange | covered | `catalog.md`, `shop-standard-components.md`, `commerce-1c-integration.md`, `shop-integrations-webservice.md` | product subscription/report side effects см. `shop-marketing-analytics.md`; REST hooks см. `shop-integrations-webservice.md` |
| `clouds` | `25.100.0` | 0 | 8 | external file storage для catalog images/imports | covered | `clouds.md`, `file-upload-modern.md` | нет срочного shop deep dive |
| `conversion` | `25.0.0` | 0 | 4 | конверсия магазина, связка с A/B/statistic | covered | `shop-marketing-analytics.md` | держать вместе с A/B/statistic diagnostics |
| `currency` | `26.0.0` | 3 | 6 | валюты/курсы/форматирование денег | covered | `currency.md` | нет срочного shop deep dive |
| `fileman` | `25.200.200` | 11 | 37 | editor/files/maps, вспомогательно для витрины | covered | `fileman.md`, `templates.md` | нет срочного shop deep dive |
| `form` | `26.0.0` | 6 | 17 | формы, CRM bridge, заявки/лиды | covered | `webforms.md`, `b24connector.md` | проверить shop lead forms при задаче |
| `forum` | `26.0.0` | 34 | 20 | comments/discussions, не core checkout | covered | `forum.md` | нет срочного shop deep dive |
| `highloadblock` | `25.100.0` | 3 | 10 | directory props, refs, auxiliary product data | covered | `highloadblock.md`, `iblock-hl-relations.md` | нет срочного shop deep dive |
| `iblock` | `25.300.0` | 55 | 29 | основа public `catalog.*` components, properties/sections | covered | `iblocks.md`, `pagination.md`, `shop-standard-components.md` | нет срочного shop deep dive |
| `idea` | `25.0.0` | 13 | 0 | идеи/feedback/statistic, не core shop | covered | `shop-core-tail-modules.md` | feedback route; не CRM/sale engine |
| `landing` | `26.200.0` | 59 | 5 | landing pages, catalog carousel blocks | covered | `landing.md`, `shop-core-tail-modules.md`, `catalog.md` | catalog blocks are presentation/connectors, not product truth |
| `learning` | `25.0.0` | 15 | 23 | обучение, не core shop | covered | `shop-core-tail-modules.md` | education route; не CommerceML/shop sale без локальной связки |
| `lists` | `25.600.100` | 19 | 0 | processes/lists, связка с bizproc/iblock | covered | `shop-automation-bizproc.md`, `workflow.md` | нет срочного shop deep dive |
| `location` | `25.400.0` | 0 | 0 | адреса и locations для доставки/checkout | covered | `location.md`, `sale.md` | нет срочного shop deep dive |
| `mail` | `26.100.200` | 18 | 14 | mailbox/client/signatures, sender/mail pipeline | covered | `mail-notifications.md`, `shop-marketing-analytics.md` | нет срочного shop deep dive |
| `main` | `26.150.0` | 82 | 112 | runtime, users, sessions, cache, pagination, mail helpers | covered | `modules-loader.md`, `pagination.md`, `session-auth.md` | нет срочного shop deep dive |
| `messageservice` | `25.200.100` | 2 | 2 | SMS providers, sender limits/config | covered | `messageservice.md`, `mail-notifications.md`, `shop-marketing-analytics.md` | нет срочного shop deep dive |
| `mobileapp` | `25.0.100` | 15 | 2 | mobile/admin mobile, sale mobile components используют `sale` | covered | `mobileapp.md`, `shop-core-tail-modules.md`, `sale.md` | sale mobile order components remain in `sale` |
| `perfmon` | `25.300.0` | 0 | 22 | performance diagnostics для магазина | covered | `perfmon.md`, `operations-runbook.md` | нет срочного shop deep dive |
| `photogallery` | `25.100.0` | 17 | 0 | galleries, не core shop | covered | `photogallery.md` | нет срочного shop deep dive |
| `pull` | `25.300.0` | 1 | 0 | realtime/push, counters/watches/transport | covered | `shop-automation-bizproc.md`, `push-pull.md` | runtime server config по задаче |
| `report` | `25.100.0` | 19 | 0 | report builder / visualconstructor | covered | `shop-marketing-analytics.md` | domain-specific helper class по задаче |
| `rest` | `26.0.0` | 42 | 2 | webhooks/OAuth/apps, внешние shop integrations | covered | `rest.md`, `shop-integrations-webservice.md`, `http.md` | runtime scopes/events проверять через `methods`/`method.get` |
| `sale` | `26.0.0` | 78 | 172 | basket/order/checkout/payment/delivery/discounts/1С | covered | `sale.md`, `shop-standard-components.md`, `commerce-workflows.md`, `commerce-1c-integration.md`, `shop-marketing-analytics.md`, `shop-automation-bizproc.md`, `shop-integrations-webservice.md` | order robots требуют provider/CRM/custom module проверки; REST/webservice см. integration reference |
| `search` | `25.200.0` | 6 | 9 | product search/index | covered | `search.md`, `index-cache-diagnostics.md` | нет срочного shop deep dive |
| `security` | `25.0.0` | 3 | 25 | WAF/OTP/security hardening for exchange/admin | covered | `security.md` | проверить 1С security toggles в exchange audit |
| `sender` | `26.0.0` | 65 | 13 | campaigns, triggers, templates, contact segments | covered | `shop-marketing-analytics.md`, `mail-notifications.md`, `messageservice.md` | нет срочного shop deep dive |
| `seo` | `25.100.400` | 2 | 15 | SEO, meta, sitemap, catalog SEO side effects | covered | `seo-cache-access.md`, `catalog.md` | нет срочного shop deep dive |
| `socialservices` | `26.0.0` | 3 | 0 | OAuth/social login | covered | `socialservices.md`, `users.md` | нет срочного shop deep dive |
| `statistic` | `26.0.0` | 1 | 66 | traffic/statistics, reports/conversion | covered | `shop-marketing-analytics.md` | следить за runtime/perf side effects |
| `storeassist` | `24.0.0` | 0 | 15 | shop setup assistant, 1С onboarding pages | covered | `storeassist.md`, `commerce-1c-integration.md` | держать связанным с 1С diagnostics |
| `subscribe` | `25.0.0` | 5 | 12 | legacy subscriptions/mailings | covered | `subscribe.md`, `mail-notifications.md`, `shop-marketing-analytics.md` | нет срочного shop deep dive |
| `support` | `26.0.0` | 5 | 27 | support/tickets/coupons, не core shop | covered | `shop-core-tail-modules.md` | ticket/SLA route; order link только если есть project glue |
| `translate` | `25.100.0` | 2 | 6 | localization/lang files | covered | `translate.md` | нет срочного shop deep dive |
| `ui` | `26.150.0` | 16 | 0 | grid/filter/entity selector/uploader UI | covered | `grid-admin-modern.md`, `file-upload-modern.md` | нет срочного shop deep dive |
| `vote` | `26.0.0` | 11 | 15 | polls/votes | covered | `vote.md` | нет срочного shop deep dive |
| `webservice` | `26.0.0` | 5 | 0 | `webservice.sale`, `webservice.statistic`, SOAP/WSDL, stssync | covered | `shop-integrations-webservice.md`, `http.md`, `sale.md`, `shop-marketing-analytics.md` | не путать с CommerceML/1С exchange |
| `wiki` | `25.0.0` | 9 | 0 | wiki/content, not core shop | covered | `shop-core-tail-modules.md` | content/social route; not shop KB без локального route |
| `workflow` | `26.0.0` | 0 | 10 | legacy workflow, statuses/history/files | covered | `shop-automation-bizproc.md`, `workflow.md` | нет срочного shop deep dive |

## Shop-critical modules already deep enough for baseline

### `catalog` 25.550.0

Confirmed signals:
- components: `catalog.import.1c`, `catalog.export.1c`, `catalog.product.grid`, `catalog.productcard.*`, `catalog.store.*`, `catalog.store.document.*`, `catalog.report.store_*`, `catalog.product.subscribe*`, `catalog.viewed.products`;
- admin: `1c_import.php`, `1c_admin.php`, `cat_catalog_*`, `cat_store_*`, `cat_discount_*`, coupon pages;
- reference coverage: `catalog.md`, `currency.md`, `commerce-1c-integration.md`, `commerce-workflows.md`, `shop-integrations-webservice.md` для REST.

Baseline is good for product/SKU/price/store/1С import-export tasks. Component-by-component storefront/admin map for `catalog.section`, `catalog.smart.filter`, compare, viewed/recommended and reports is covered by `shop-standard-components.md`; marketing/report side effects are routed through `shop-marketing-analytics.md`; catalog REST/controllers/events/placement are routed through `shop-integrations-webservice.md`.

### `sale` 26.0.0

Confirmed signals:
- components: `sale.basket.*`, `sale.basket.order.ajax`, `sale.order.ajax`, `sale.order.checkout`, `sale.personal.*`, `sale.export.1c`, `sale.delivery.*`, `sale.discount.coupon.mail`, `sale.bigdata.*.mail`, `sale.mobile.order.*`;
- admin: `1c_exchange.php`, `order_*`, `delivery_*`, `pay_system_*`, `cashbox_*`, `discount_*`, `exchange_log.php`, reports;
- reference coverage: `sale.md`, `commerce-workflows.md`, `commerce-1c-integration.md`, `shop-integrations-webservice.md` для REST/webservice.

Baseline is good for basket/order/payment/shipment/delivery/discount/1С order exchange tasks. Basket/order/personal/payment/delivery component routing is covered by `shop-standard-components.md`; marketing side effects are routed through `shop-marketing-analytics.md`; automation/bizproc routing is covered by `shop-automation-bizproc.md`; sale REST/webservice integration extras are covered by `shop-integrations-webservice.md`, but sale-order robots still require a confirmed provider/CRM/custom module.

### `currency` 26.0.0

Confirmed signals:
- components: `currency.field.money`, `currency.money.input`, `currency.rates`;
- admin: currency/rate/classifier pages;
- reference coverage: `currency.md`.

Good enough for catalog prices and sale sums.

## Ordered code-first modules completed

### Completed. Shop standard components

Covered by `shop-standard-components.md`:
- iblock-hosted catalog components: `catalog`, `catalog.section`, `catalog.element`, `catalog.smart.filter`, `catalog.compare.*`, `catalog.search`, `catalog.top`, `catalog.sections.top`;
- sale components: `sale.basket.*`, `sale.basket.order.ajax`, `sale.order.ajax`, `sale.order.checkout`, `sale.personal.*`, `sale.order.payment*`, `sale.store.choose`;
- catalog module components: `catalog.product.grid`, `catalog.productcard.*`, `catalog.store.*`, `catalog.report.store_*`;
- `bitrix.eshop` wizard/template component calls and own `eshop.*` components.

### Completed. Marketing/analytics

Covered by `shop-marketing-analytics.md`:
- `sender` 26.0.0;
- `mail` 26.100.200;
- `messageservice` 25.200.100;
- `subscribe` 25.0.0;
- `advertising` 24.200.0;
- `abtest` 26.0.0;
- `conversion` 25.0.0;
- `report` 25.100.0;
- `statistic` 26.0.0;
- eShop/public hooks and sale-side sender/statistic connectors.

### Completed. Automation

Covered by `shop-automation-bizproc.md`:
- `bizproc` 26.200.0;
- `bizprocdesigner` 26.0.0;
- `workflow` 26.0.0;
- `lists` 25.600.100;
- `pull` 25.300.0 where realtime effects matter;
- iblock/list process routing and sale-order automation boundary.

### Completed. Webservice/integration extras

Covered by `shop-integrations-webservice.md`:
- `webservice` 26.0.0, `webservice.server`, `webservice.checkauth`, `webservice.sale`, `webservice.statistic`, `stssync.server`;
- SOAP/WSDL descriptors, tools/endpoints and security boundaries;
- `rest` 26.0.0 apps/webhooks/events/placements/auth/batch/method discovery;
- sale REST controllers/events and explicit pay_system/delivery/cashbox scopes;
- catalog REST controllers/events and `CATALOG_EXTERNAL_PRODUCT` placement;
- B24 sale exchange/integration boundary vs 1С CommerceML.

## Do not overclaim

- Do not say “все shop-core модули runtime-проверены” until runtime-smoke is done. Standard shop components are covered by `shop-standard-components.md`, marketing/analytics by `shop-marketing-analytics.md`, automation by `shop-automation-bizproc.md`, webservice/REST by `shop-integrations-webservice.md`, tail modules by `shop-core-tail-modules.md`; production guidance and smoke format live in `production-best-practices.md`, `pitfalls-matrix.md`, `runtime-smoke-verification.md`.
- Do not activate `bizproc`, `bizprocdesigner`, `workflow`, `lists`, `pull`, `sender`, `report`, `statistic`, `abtest`, `conversion`, `advertising`, `webservice` in another project unless the module exists locally.
- Do not infer `sale/catalog` from `iblock` components alone: `iblock` ships `catalog.*` public components even when the `catalog` module may be missing in another checkout.
- Do not use this inventory as API documentation by itself. For tail modules use `shop-core-tail-modules.md`; for runtime claims use `runtime-smoke-verification.md`.

## Ordered roadmap from this inventory

1. Tail modules — `shop-core-tail-modules.md` covers `calendar`, `idea`, `learning`, `support`, `wiki` plus shop-specific `b24connector`, `landing`, `mobileapp` routes.
2. Docker/runtime smoke — because current coverage is code-first and still needs DB/runtime fixtures; use `runtime-smoke-verification.md` as the evidence format.
2. Deferred per-project modules only when a task needs them.

---

## Source: `noncommerce-task-matrix.md`

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
| performance diagnostics / аудит оптимизаций | `project-optimization-audit.md` (compact in `search-seo-ops.md`), `perfmon.md`, `operations-runbook.md` |
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

---

## Source: `shop-task-matrix.md`

# Shop task matrix — routing интернет-магазина

> Используй этот файл как быстрый роутер для задач по интернет-магазину. Truth layer для нового этапа: shop-core `/Users/igormajorov/Downloads/Telegram Desktop/bitrix-shop-core` с 49 подтверждёнными модулями. Полный inventory и coverage status смотри в `shop-core-module-inventory.md`.

## 1. Быстрый routing

| Запрос пользователя | Сначала читать | Затем |
|---|---|---|
| “Все ли модули магазина/1С покрыты?” | `shop-core-module-inventory.md`, `runtime-smoke-verification.md` | `core-audit-matrix.md`, затем нужный deep-reference; code-first coverage ≠ runtime pass |
| Товары, свойства, разделы, SKU | `catalog.md`, `shop-standard-components.md`, `iblocks.md` | `commerce-1c-integration.md`, если есть 1С/XML_ID |
| Цена не та / не показывается | `catalog.md`, `currency.md` | `sale.md`, `search-seo-ops` bundles для кеша |
| Остатки, склады, доступность | `catalog.md`, `shop-standard-components.md` | `sale.md` для reservation/order effects |
| Корзина не работает | `shop-standard-components.md`, `sale.md`, `catalog.md` | `components.md`, `events-routing.md` |
| Checkout / оформление заказа | `shop-standard-components.md`, `sale.md` | `users.md`, `validation.md`, `templates.md` |
| Оплата / callback | `sale.md` | `http.md`, `events-routing.md`, cashbox section в `sale.md` |
| Доставка / locations | `shop-standard-components.md`, `sale.md`, `location.md` | `components.md`, `validation.md` |
| Скидки / купоны | `sale.md`, `catalog.md` | `currency.md` |
| 1С выгрузка товаров | `commerce-1c-integration.md`, `catalog.md` | `currency.md`, `cache-infra.md` |
| Заказы в 1С | `commerce-1c-integration.md`, `sale.md` | `http.md`, `operations-runbook.md` |
| StoreAssist / мастер настройки 1С | `storeassist.md`, `shop-standard-components.md`, `shop-core-module-inventory.md` | `commerce-1c-integration.md` для реального exchange |
| Рассылки, follow-up, маркетинг | `shop-marketing-analytics.md` | `mail-notifications.md`, `messageservice.md`, `sale.md` |
| Форма подписки / отписка | `shop-marketing-analytics.md`, `subscribe.md` | `userconsent.md`, `mail-notifications.md` |
| SMS / message provider / лимиты | `shop-marketing-analytics.md`, `messageservice.md` | REST/provider config, `mail-notifications.md` |
| Баннеры, A/B, conversion, reports, statistic | `shop-marketing-analytics.md` | `templates.md`, `seo-cache-access.md`, `perfmon.md` |
| Автоматизация заказа / роботы | `shop-automation-bizproc.md`, `sale.md` | проверить локальный order provider/CRM/custom module перед обещанием sale robots |
| Бизнес-процесс / задание / шаблон не стартует | `shop-automation-bizproc.md`, `workflow.md` | `iblocks.md`, `lists` section, permissions |
| Процессы в списках | `shop-automation-bizproc.md`, `workflow.md`, `iblocks.md` | list rights, `BIZPROC=Y`, `CLists::isBpFeatureEnabled` |
| Realtime / pull / push в автоматизации | `shop-automation-bizproc.md`, `push-pull.md` | pull server config, channels/watches |
| `webservice.sale` / SOAP order stats | `shop-integrations-webservice.md`, `sale.md` | это не 1С и не order CRUD; проверить WSDL, sale rights, date/status filters |
| `webservice.statistic` / SOAP traffic stats | `shop-integrations-webservice.md`, `shop-marketing-analytics.md` | `statistic` rights, traffic tables, `STAT_LIST_TOP_SIZE` |
| REST sale/catalog app hooks, webhooks, placements | `shop-integrations-webservice.md`, `rest.md` | `methods`/`method.get`, scopes, `b_rest_event`, `b_rest_placement` |
| “В админке есть, на сайте нет” для товара | `shop-standard-components.md`, `catalog.md`, `diagnostic-visibility.md` | `index-cache-diagnostics.md`, `component-dataflow-debugging.md` |
| Вторая страница каталога пустая, lazy load сломан | `pagination.md`, `shop-standard-components.md`, `catalog.md`, `component-dataflow-debugging.md` | `sef-urls.md`, `cache-infra.md` |
| Производительность каталога | `catalog.md`, `perfmon.md`, `cache-infra.md` | `search.md`, `seo-cache-access.md` |
| Production-safe план доработки магазина | `production-best-practices.md`, `shop-task-matrix.md` | конкретные `catalog.md`/`sale.md`/`commerce-1c-integration.md`/`shop-integrations-webservice.md` |
| Подводные камни checkout/order/1С/REST | `pitfalls-matrix.md` | затем профильный shop reference |
| Runtime smoke магазина | `runtime-smoke-verification.md` | `catalog.md`, `sale.md`, `commerce-1c-integration.md`, `shop-integrations-webservice.md` |

## 2. Минимальная проверка shop-core

```bash
for m in main iblock currency catalog sale; do
  if test -f "www/bitrix/modules/$m/install/version.php"; then
    sed -n '1,40p' "www/bitrix/modules/$m/install/version.php"
  elif test -f "www/bitrix/modules/$m/classes/general/version.php"; then
    sed -n '1,20p' "www/bitrix/modules/$m/classes/general/version.php"
  else
    echo "MISS $m"
  fi
done
```

Если `catalog`, `sale` или `currency` отсутствуют, возвращайся к non-commerce маршруту и не веди задачу как магазинную.

## 3. Диагностические цепочки

### Товар есть в админке, но не виден на сайте

1. `iblock`: element active, section active, site binding, dates, rights.
2. `catalog`: product row, type, offer relation, price, currency, availability.
3. `component`: open `shop-standard-components.md`, then params, filter, selected price types, offers props.
4. `template`: `result_modifier.php`, скрытие пустых props, JS SKU switcher.
5. `cache`: component/tagged/managed, facet/search index, composite.
6. `seo`: SEF/urlrewrite/canonical, 404 handling.

### Товар виден, но не покупается

1. Product/offer ID: добавляется parent или offer?
2. Price exists and accessible for user group.
3. Currency valid and formatted.
4. Quantity/availability/can buy zero/reservation.
5. Catalog provider returns item data for basket.
6. Sale basket event handlers and AJAX response.

### Checkout падает

1. Basket is not empty and refreshed.
2. Person type and mandatory order properties.
3. Delivery restrictions and location.
4. Payment restrictions and currency.
5. Discounts/coupons recalculation.
6. `Order::save()` errors.
7. Component AJAX template and JS (`shop-standard-components.md` → stock template/project override).

### 1С обмен падает

1. Which flow: catalog import, catalog export, sale export/import.
2. `checkauth` response and cookie persistence.
3. `init` response: zip, file limit, sessid.
4. `file`: upload/chunk/temp dir permissions.
5. `import`: XML parsing, session state, last entry.
6. Mapping: XML_ID, CML2_LINK, price type, store.
7. Logs: `b_sale_exchange_log`, temp files, PHP/Apache errors.
8. Side effects: cache, indexes, order status/reservation.

## 4. Smoke fixtures для будущего теста

Полный формат runtime verification смотри в `runtime-smoke-verification.md`; ниже только короткий shop-набор.

Минимальный sandbox-набор:

- один раздел каталога;
- один простой товар;
- один товар с двумя offers;
- базовая цена в `RUB`;
- один склад и остаток;
- один тестовый пользователь;
- одна корзина;
- один заказ с доставкой и оплатой;
- один CommerceML import fixture;
- один order export/import fixture.

## 5. Safety rules

- Production data changes require explicit confirmation.
- No real 1С, payments, delivery services, cashbox without confirmation.
- Prefer migrations/CLI/fixtures over admin clicks.
- Any exchange test must have cleanup and rollback.
- Never trust memory over `www/bitrix` code.

---

## Source: `diagnostic-visibility.md`

# Visibility Diagnostics: “в админке есть, на сайте нет” — справочник

> Reference для Bitrix-скилла. Загружай для задач “не видно на сайте”, “в админке есть”, “компонент ничего не выводит”, “у одного пользователя видно, у другого нет”.

## Содержание
- Диагностическая цепочка
- Быстрые команды
- Типовые причины
- Модульные маршруты
- Что нельзя делать
- С чем читать вместе

## Диагностическая цепочка

Иди от источника данных к браузеру:

1. Модуль и компонент реально установлены.
2. Данные существуют и активны.
3. Сайт, язык, права и группы пользователя совпадают.
4. Компонент получает правильные параметры.
5. Выборка не отфильтровала данные.
6. `result_modifier.php` не выкинул нужные поля.
7. `template.php` реально выводит эти данные.
8. Кеш компонента/тегированный кеш не отдаёт старое состояние.
9. Страница не скрыта SEO/robots/noindex/canonical logic.
10. Клиентский JS/AJAX не перерисовывает пустое состояние.

## Быстрые команды

```bash
find www/bitrix/modules -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort

find local/components bitrix/templates www/bitrix/templates -path '*result_modifier.php' -o -path '*component_epilog.php' -o -path '*template.php'

rg -n 'CACHE_TYPE|CACHE_TIME|CACHE_TAG|clearByTag|clearTaggedCache|StartTagCache|EndTagCache|setResultCacheKeys|AbortResultCache' local bitrix/templates www/bitrix/templates www/bitrix/modules

rg -n 'ACTIVE|ACTIVE_FROM|ACTIVE_TO|SITE_ID|LID|GROUP_ID|PERMISSION|RIGHT|CHECK_PERMISSIONS|noindex|canonical|robots' local bitrix/templates www/bitrix/templates www/bitrix/modules
```

Если `local/*` отсутствует, сразу переходи к `bitrix/templates`, `www/bitrix/templates` и stock templates в `www/bitrix/modules/*/install/components/bitrix`.

## Типовые причины

| Симптом | Проверить |
|---|---|
| В админке есть, на публичке пусто | `ACTIVE`, даты активности, site binding, section active chain, права |
| У админа видно, у гостя нет | группы пользователя, `CHECK_PERMISSIONS`, inherited rights, component params |
| После правки не меняется | component cache, tagged cache, managed cache, composite/static cache |
| В списке нет, детальная открывается | фильтр списка, section filter, `pagination.md`, sort, `INCLUDE_SUBSECTIONS` |
| В поиске нет | search index, module `search`, `BeforeIndex`, rights, site, URL function |
| SEO/URL странный | `urlrewrite.php`, SEF params, canonical, redirects, robots/noindex |
| Файл не открывается | `clouds`, `HANDLER_ID`, secure file access, `CFile` path, rights |
| Форма отправляется, но результата нет | form status, validators, handlers, permissions, CRM link |

## Модульные маршруты

- IBlock/HL: сначала `iblocks.md`, `highloadblock.md`, потом кеш и права.
- Forms: `webforms.md`, затем status/validator/handler/secure files.
- Blog/forum/vote: legacy API и standard component template layer.
- Search/SEO: `search.md`, `seo-cache-access.md`, `index-cache-diagnostics.md`.
- File/address/media: `fileman.md`, `location.md`, `clouds.md`.
- Security: WAF/MFA/redirect/IP restrictions can affect visibility and access.

## Что нельзя делать

- Не говорить “почистите весь кеш” как единственный ответ.
- Не менять шаблон, пока не проверен входной `$arResult`.
- Не считать отсутствие `local/*` отсутствием кастомизации: stock templates и wizard templates всё ещё влияют на вывод.
- Не путать физическое наличие `catalog.*` компонента в `iblock` с установленным модулем `catalog`.
- Не отключать права/кеш/SEO без понимания побочных эффектов.

## С чем читать вместе

- Component/data flow — `component-dataflow-debugging.md`
- Cache/index — `index-cache-diagnostics.md`
- Components/templates — `components.md`, `templates.md`
- Search/SEO — `search.md`, `seo-cache-access.md`
- Security/access — `security.md`, `access-rbac.md`

---

## Source: `index-cache-diagnostics.md`

# Cache и Index Diagnostics — справочник

> Reference для Bitrix-скилла. Загружай, когда задача связана с устаревшим выводом, поиском, SEO, тегированным кешем, индексами, импортом или “после изменения данные не обновились”.

## Содержание
- Карта кешей и индексов
- Порядок диагностики
- Что проверять по доменам
- Verification после правки
- Common mistakes

## Карта кешей и индексов

| Слой | Где проявляется | Reference |
|---|---|---|
| Component cache | стандартные компоненты, `$arParams['CACHE_*']` | `components.md` |
| Tagged cache | инфоблоки, HL, связанные данные | `cache-infra.md`, `iblocks.md` |
| Managed cache | options, ORM metadata, module state | `cache-infra.md`, `modules-loader.md` |
| Composite/static HTML | публичные страницы, персональные блоки, `/bitrix/html_pages/`, `X-Bitrix-Composite` | `components-admin-ui.md`, `search-seo-ops.md`, `users-security.md` |
| Search index | `CSearch`, `search.page`, `search.title` | `search.md` |
| SEO artifacts | sitemap, robots, canonical, OpenGraph | `seo-cache-access.md` |
| Landing cache | landing blocks/pages/hooks | `landing.md` |

## Порядок диагностики

1. Определи, какие данные менялись: element, section, UF, form result, blog post, file, landing block, user, option.
2. Найди компонент или endpoint, который отдаёт публичный результат.
3. Проверь, кешируется ли результат и какие cache keys/tag-и используются.
4. Проверь, нужно ли переиндексировать поиск или SEO artifacts.
5. Проверь права и site binding, чтобы не перепутать кеш с access problem.
6. После исправления обнови только нужный слой, а не весь сайт без причины.

## Что проверять по доменам

| Домен | После изменения думать о |
|---|---|
| IBlock elements/sections | component cache, tagged cache, search index, sitemap/URL |
| HL blocks | ORM cache, component cache, dependent iblock/UF references |
| Web forms | result permissions, form cache, status handlers, mail events |
| Blog/forum/vote | legacy write API side effects, search index, template cache |
| Search | `CSearch::Index`, `CSearch::DeleteIndex`, `CSearch::ReIndexAll`, `BeforeIndex` |
| SEO | sitemap rebuild, robots/noindex, canonical duplicates |
| Landing | block hooks, mutator mode, page publication, landing cache |
| Files/clouds | `HANDLER_ID`, delayed resize, external `SRC`, file access |
| Users/access | group membership, session cache, permission cache |

## Verification после правки

Минимальный набор:

1. проверить изменённый runtime path без кеша или с точечной инвалидацией;
2. проверить повторный запрос с включённым кешем;
3. проверить гостя и авторизованного пользователя, если данные персональные;
4. проверить search/SEO только если задача меняла индексируемые данные;
5. зафиксировать, какой кеш или индекс был причиной.

## Common mistakes

- Сбрасывать весь кеш вместо определения слоя.
- Обновлять данные через D7 ORM, когда конкретный legacy-модуль ожидает `C*` write API side effects.
- Забывать search reindex после массового импорта.
- Кешировать персональные данные в общем component cache.
- Считать SEO-дубль проблемой шаблона, когда причина в SEF/canonical/urlrewrite.

## С чем читать вместе

- Cache primitives — `cache-infra.md`
- Components/templates — `components.md`, `templates.md`
- Search — `search.md`
- SEO — `seo-cache-access.md`
- Operations — `operations-runbook.md`

---

## Source: `component-dataflow-debugging.md`

# Component и Data Flow Debugging — справочник

> Reference для Bitrix-скилла. Загружай для задач по стандартным компонентам, шаблонам, `result_modifier.php`, `component_epilog.php`, AJAX и трассировке данных от API до HTML.
>
> Если симптом связан со второй страницей, `PAGEN_N`, `NavNum`, `PageNavigation`, lazy load или `main.pagenavigation`, дополнительно загружай `pagination.md`. Если симптом в интернет-магазине (`catalog.section`, `catalog.element`, `smart.filter`, basket, checkout, personal order), дополнительно загружай `shop-standard-components.md`.

## Содержание
- Truth layers
- Путь данных
- Где менять код
- Диагностические команды
- Red flags
- С чем читать вместе

## Truth layers

Порядок проверки:

1. `www/bitrix/modules/<module>/install/components/bitrix/<component>/`
2. `local/components/<vendor>/<component>/`, если есть
3. `local/templates/<template>/components/bitrix/<component>/<template>/`, если есть
4. `bitrix/templates/<template>/components/bitrix/<component>/<template>/`
5. `www/bitrix/templates/*/components/bitrix/...`
6. wizard public/template assets

Если `local/*` отсутствует, не останавливайся: stock templates и `bitrix/templates/*` становятся следующим живым слоем.

## Путь данных

1. `.parameters.php` задаёт контракт параметров.
2. `component.php` / `class.php` собирает данные и управляет кешем.
3. `result_modifier.php` изменяет `$arResult` до шаблона.
4. `template.php` отвечает за вывод и минимальную view-логику.
5. `component_epilog.php` делает поздние эффекты: meta, breadcrumbs, assets, deferred work.
6. JS/AJAX может заменить HTML после загрузки.

## Где менять код

| Что нужно | Слой |
|---|---|
| Изменить внешний вид | copied template |
| Подготовить поля для view | `result_modifier.php` или service до него |
| Добавить meta/breadcrumbs/canonical | `component_epilog.php` или page layer |
| Изменить бизнес-правило | service/module layer |
| Поменять выборку | component params, service, repository/ORM/legacy API |
| Добавить AJAX endpoint | controller/action route, не inline chaos в шаблоне |
| Починить кеш | component cache keys, tagged cache, `setResultCacheKeys` |

## Диагностические команды

```bash
find www/bitrix/modules -path '*/install/components/bitrix/<component>' -type d

find local/components bitrix/templates www/bitrix/templates -path '*<component>*' -type f

rg -n 'result_modifier|component_epilog|setResultCacheKeys|AbortResultCache|StartResultCache|includeComponentTemplate|ajax|BX.ajax' local bitrix/templates www/bitrix/templates www/bitrix/modules
```

Заменяй `<component>` на реальное имя, например `form.result.new`, `blog.post`, `search.page`.

## Red flags

- Толстая бизнес-логика в `template.php`.
- SQL или внешнее API прямо из шаблона.
- `result_modifier.php` меняет данные без учёта кеша.
- `component_epilog.php` используется для тяжёлых запросов вместо поздних page effects.
- Копия шаблона оторвана от stock variant и не сверена после обновления core.
- AJAX endpoint живёт в случайном PHP-файле без CSRF/access checks.

## С чем читать вместе

- Components — `components.md`
- Templates — `templates.md`
- Standard non-commerce components — `standard-components-noncommerce.md`
- Events/routing — `events-routing.md`
- PHP workflow — `php-workflow.md`

---

## Source: `standard-components-noncommerce.md`

# Standard Components без магазина — справочник

> Reference для Bitrix-скилла. Загружай для задач по stock components и templates текущего core без `catalog`/`sale`.

## Содержание
- Принцип
- Активные component families
- Особая ловушка `catalog.*`
- Где искать template variants
- Что менять
- С чем читать вместе

## Принцип

Стандартный компонент — это контракт. Перед доработкой прочитай его из текущего core:

1. `.parameters.php`;
2. `component.php` или `class.php`;
3. stock `templates/*`;
4. вложенные components в комплексном шаблоне;
5. `result_modifier.php` и `component_epilog.php`, если есть.

## Активные component families

| Семейство | Модуль-владелец | Reference |
|---|---|---|
| `main.*` | `main` | `components.md`, `templates.md`, `users.md`, `grid-admin-modern.md` |
| `iblock.*` | `iblock` | `iblocks.md`, `entities-migrations.md` |
| `highloadblock.*` | `highloadblock` | `highloadblock.md` |
| `form`, `form.result.*` | `form` | `webforms.md` |
| `blog.*` | `blog` | `blog-socialnet.md` |
| `forum.*` | `forum` | `forum.md` |
| `voting.*`, `vote.*` | `vote` | `vote.md` |
| `search.*` | `search` | `search.md` |
| `landing.*` | `landing` | `landing.md` |
| `b24connector.*` | `b24connector` | `b24connector.md` |
| `bitrixcloud.mobile.*` | `bitrixcloud` | `bitrixcloud.md` |
| `messageservice.*` | `messageservice` | `messageservice.md` |
| `fileman.*`, maps/editor fields | `fileman` | `fileman.md`, `location.md` |

## Особая ловушка `catalog.*`

В текущем core `catalog.*` directories есть внутри:

```text
www/bitrix/modules/iblock/install/components/bitrix/catalog*
```

Это означает наличие iblock-based public components, но не наличие модуля `catalog`.

Правило:

- можно разбирать `catalog.section`/`catalog.element` как стандартный компонент из `iblock`;
- нельзя обещать торговый каталог, цены, SKU, остатки, корзину, заказ и checkout без модулей `catalog`/`sale`;
- если пользователь просит магазинную задачу, фиксируй deferred status.

## Где искать template variants

```bash
find www/bitrix/modules/<module>/install/components/bitrix/<component>/templates -maxdepth 2 -type f

find bitrix/templates www/bitrix/templates local/templates -path '*components/bitrix/<component>*' -type f
```

Если `local/templates` отсутствует, смотри `bitrix/templates/.default`, `bitrix/templates/furniture_gray`, `bitrix/templates/landing24` и wizard templates.

## Что менять

| Задача | Слой |
|---|---|
| внешний HTML | copy template |
| подготовка данных | `result_modifier.php` или service |
| meta/breadcrumbs/canonical | `component_epilog.php` |
| параметры выборки | component params и API-layer |
| бизнес-правило | service/module layer |
| кеш | component cache + tagged cache |
| AJAX | controller/action с CSRF/access checks |

## С чем читать вместе

- Components/data flow — `component-dataflow-debugging.md`
- Templates — `templates.md`
- Web forms — `webforms.md`
- Blog/forum/vote — `blog-socialnet.md`, `forum.md`, `vote.md`
- Search/SEO — `search.md`, `seo-cache-access.md`

---

## Source: `pitfalls-matrix.md`

# Bitrix Pitfalls Matrix — типовые ловушки и диагностика

> Reference для Bitrix-скилла. Загружай, когда пользователь спрашивает о подводных камнях, “почему сломалось”, “в админке есть, а на сайте нет”, “после импорта/обновления/обмена всё странно”, “как не наступить на грабли”. Это routing matrix: конкретные API проверяй в модульных reference-файлах.

## Как пользоваться

1. Найди symptom row.
2. Пройди diagnostic chain слева направо.
3. Открой указанные module references.
4. Не предлагай fix, пока не подтверждён слой поломки.

## Общая цепочка диагностики

```text
module installed → data exists → site/language/rights → component params/filter/sort/pagination → template/result_modifier → component/tagged/composite cache → SQL/ORM/N+1/images/assets → index/SEO → JS/AJAX → runtime events/agents/integrations
```

Если симптом магазинный, добавь:

```text
catalog product → offer/SKU → price/currency → stock/store → basket availability → discounts → checkout restrictions → order save → payment/shipment → external exchange/events
```

## Content / visibility

| Симптом | Главные проверки | Частые причины | Читать |
|---|---|---|---|
| В админке есть, на сайте нет | `ACTIVE`, dates, site binding, section chain, rights, component filter, cache | inactive parent section, wrong `IBLOCK_ID`, `CHECK_PERMISSIONS`, stale component cache | `diagnostic-visibility.md`, `iblocks.md`, `components.md` |
| У админа видно, у гостя нет | groups, inherited rights, component params, composite cache | output cached under admin, missing anonymous rights, personal block cached publicly | `access-rbac.md`, `cache-infra.md`, `templates.md` |
| В списке нет, детальная открывается | list filter, section filter, pagination, sort, `INCLUDE_SUBSECTIONS` | unstable sort, wrong section, `PAGEN_N` conflict | `pagination.md`, `component-dataflow-debugging.md` |
| После правки ничего не меняется | component/tagged/managed/composite cache | cleared wrong cache layer, `result_modifier.php` not in cache key, composite static area | `index-cache-diagnostics.md`, `cache-infra.md` |
| Данные есть в `$arResult`, но нет HTML | template condition, JS replacement, CSS hidden, copied template drift | custom template dropped field, ajax rerender empty state | `component-dataflow-debugging.md`, `templates.md` |

## Components/templates

| Симптом | Главные проверки | Частые причины | Читать |
|---|---|---|---|
| Правка stock component исчезла после обновления | location of edited file | edited `www/bitrix/modules/*/install/components` | `production-best-practices.md`, `components.md` |
| Custom template сломался после обновления ядра | compare copied template vs stock template | copied template frozen on old core contract | `templates.md`, `component-dataflow-debugging.md` |
| AJAX работает без прав/CSRF | endpoint path, auth, sessid | inline PHP endpoint, no `check_bitrix_sessid`, no rights | `events-routing.md`, `security.md`, `http.md` |
| Пагинация дублирует элементы | stable sort, count, `NavNum`, ajax params | same `PAGEN_N`, no deterministic sort, changed filter between pages | `pagination.md` |
| Lazy load отдаёт пусто | ajax payload, component params, page number, cache key | missing original filter/section/site/user context | `pagination.md`, `components.md` |

## IBlock / HL / UF

| Симптом | Главные проверки | Частые причины | Читать |
|---|---|---|---|
| Свойство не сохраняется | property code/type, multiplicity, API path | wrong property format, missing file array, direct SQL | `iblocks.md`, `custom-uf-types.md` |
| HL entity не находится | table name, compiled entity, UF metadata cache | wrong HL name, managed cache, migrated numeric ID | `highloadblock.md`, `iblock-hl-relations.md` |
| Импорт плодит дубли | external key, XML_ID/CODE, idempotency | find by name, no external ID, no transaction/checkpoint | `import-export.md`, `operations-runbook.md` |
| После массовой загрузки поиск пустой | search index, `BeforeIndex`, module rights | imported via path without index side effects | `search.md`, `index-cache-diagnostics.md` |
| SEF detail URL ведёт не туда | `DETAIL_PAGE_URL`, `urlrewrite.php`, section code, canonical | mixed old/new URL templates | `sef-urls.md`, `seo-cache-access.md` |

## Catalog / product / SKU

| Симптом | Главные проверки | Частые причины | Читать |
|---|---|---|---|
| Товар есть, но не виден | product active, section active chain, site binding, rights, component filter, cache | no active section, wrong catalog iblock, stale cache | `catalog.md`, `shop-standard-components.md`, `diagnostic-visibility.md` |
| Товар виден, но нельзя купить | price, currency, stock, `AVAILABLE`, offer selection, sale module, basket props | no price for group, zero stock, offer not selected, `CAN_BUY_ZERO` mismatch | `catalog.md`, `sale.md`, `commerce-workflows.md` |
| SKU/offer сломал карточку | offers iblock, `CML2_LINK`, offer props, selected offer id | product has no purchasable offer, deleted link property, template expects old SKU tree | `catalog.md`, `shop-standard-components.md` |
| Цена не обновилась | price type, currency, group rights, component price codes, cache | import wrote wrong price type, old component cache, base price mismatch | `catalog.md`, `currency.md`, `index-cache-diagnostics.md` |
| Остаток не совпадает | `b_catalog_product`, store stock, reservation, shipment/order lifecycle | total quantity vs store quantity, reserved quantity not considered | `catalog.md`, `sale.md` |
| Smart filter пустой/ломает URL | property index, section, filter params, SEF | index not rebuilt, wrong `FILTER_NAME`, property not enabled | `shop-standard-components.md`, `iblocks.md` |

## Basket / checkout / order

| Симптом | Главные проверки | Частые причины | Читать |
|---|---|---|---|
| Add to basket не работает | product availability, offer id, basket props, site/fuser, AJAX response | adding product instead of offer, missing props, stale JS | `sale.md`, `catalog.md`, `shop-standard-components.md` |
| Корзина пустая после добавления | FUSER/session/site, basket storage, cache/composite | guest/session issue, site mismatch, personal block cached | `sale.md`, `session-auth.md`, `cache-infra.md` |
| Checkout не показывает доставку | location, person type, delivery restrictions, basket dimensions/price | wrong location code, restrictions by payment/price/site | `sale.md`, `commerce-workflows.md`, `location.md` |
| Checkout не показывает оплату | person type, payment restrictions, pay system active/site/currency | pay system not bound, currency mismatch | `sale.md`, `currency.md` |
| Заказ создаётся без письма | mail event, status/event handlers, queue, template, site | mail disabled, wrong event name/site, handler error | `sale.md`, `mail-notifications.md` |
| Заказ создан, но статус/отгрузка неверны | order lifecycle, payment/shipment save, event handlers | direct field update, missing shipment collection logic | `sale.md`, `commerce-workflows.md` |
| Скидка не применялась | coupon manager, user group, basket refresh, compatible discount layer | coupon not initialized, old basket state, group rights | `sale.md`, `catalog.md` |

## 1С / CommerceML

| Симптом | Главные проверки | Частые причины | Читать |
|---|---|---|---|
| 1С не проходит `checkauth` | credentials, site, exchange option, session/cookie | wrong user/group rights, WAF/session issue | `commerce-1c-integration.md`, `session-auth.md`, `security.md` |
| `file` step грузит, `import` падает | temp dir, chunk/zip, XML validity, memory/time | broken XML, large file, old temp chunks | `commerce-1c-integration.md`, `operations-runbook.md` |
| Товары продублировались | XML_ID mapping, iblock mapping, external IDs | import matched by name/code, missing old XML_ID | `commerce-1c-integration.md`, `catalog.md` |
| Цены/остатки не обновились после обмена | price type/store mapping, offer mapping, import mode | wrong price type from 1С, store disabled, offer not linked | `commerce-1c-integration.md`, `catalog.md`, `currency.md` |
| Заказы не уходят в 1С | `sale.export.1c`, status filter, date filter, permissions | wrong export params, order not eligible, custom handler conflict | `commerce-1c-integration.md`, `sale.md` |
| StoreAssist “не обменялся” | module role | StoreAssist is checklist/onboarding, not exchange engine | `storeassist.md`, `commerce-1c-integration.md` |

## REST / webservice / integrations

| Симптом | Главные проверки | Частые причины | Читать |
|---|---|---|---|
| REST method not found | module installed, scope, `methods`, `method.get`, controller route | method version mismatch, module disabled, wrong scope | `rest.md`, `shop-integrations-webservice.md` |
| REST event не прилетел | app binding, event table, offline events, auth, sale/catalog event fired | event not registered, order changed through path without event, webhook disabled | `shop-integrations-webservice.md`, `rest.md`, `sale.md` |
| External payment/delivery/cashbox app disappeared | app uninstall cleanup, handler tables | `onRestAppDelete` cleanup removed handlers | `shop-integrations-webservice.md`, `sale.md` |
| `webservice.sale` не даёт заказы | service contract | it returns aggregate sale statistics, not order CRUD | `shop-integrations-webservice.md`, `sale.md` |
| `webservice.statistic` пустой | statistic module/tables/options | no legacy statistic data, traffic not collected | `shop-integrations-webservice.md`, `shop-marketing-analytics.md` |
| SOAP endpoint leaks auth/test | endpoint access/logging | public test/checkauth exposure | `shop-integrations-webservice.md`, `security.md` |

## Search / SEO / cache

| Симптом | Главные проверки | Частые причины | Читать |
|---|---|---|---|
| В поиске нет нового элемента | index, `BeforeIndex`, rights/site/url | write path skipped indexing, rights filter hides result | `search.md`, `index-cache-diagnostics.md` |
| SEO дубль страниц | SEF/urlrewrite/canonical/sort/filter pages | pagination/filter canonical missing/wrong | `seo-cache-access.md`, `sef-urls.md`, `pagination.md` |
| Sitemap не обновился | sitemap generation, site, iblock/SEO options | URL template mismatch, generation not rerun | `seo-cache-access.md` |
| Composite shows wrong personal data | dynamic areas (`createFrame`/`FrameHelper`), component cache key, auth state, `/bitrix/html_pages/` | personal block in static cache or shared component cache | `components-admin-ui.md`, `search-seo-ops.md`, `users-security.md` |

## Users / auth / rights

| Симптом | Главные проверки | Частые причины | Читать |
|---|---|---|---|
| Пользователь авторизован, но “нет доступа” | group membership, operations/tasks, inherited rights | stale session/groups, wrong task/operation | `users.md`, `access-rbac.md`, `session-auth.md` |
| После смены прав эффект не виден | session/cache, managed cache, user group reload | cached auth state | `session-auth.md`, `access-rbac.md`, `cache-infra.md` |
| Social login не работает | provider settings, callback URL, site, SSL | wrong redirect/callback, disabled provider | `socialservices.md` |
| OTP/WAF блокирует сценарий | security module rules, IP restrictions, redirects | security setting mistaken for app bug | `security.md` |

## Mail / SMS / marketing

| Симптом | Главные проверки | Частые причины | Читать |
|---|---|---|---|
| Письмо не ушло | event type/template/site, mail queue, SMTP, handler errors | wrong event/site, disabled template, queue not processed | `mail-notifications.md` |
| SMS не ушла | provider, limits, phone normalization, queue/logs | provider inactive, bad phone format, rate/limit | `messageservice.md`, `shop-marketing-analytics.md` |
| Sender не отправляет | segment, consent, posting queue, agents | no contacts in segment, unsubscribe/consent, agent not running | `shop-marketing-analytics.md` |
| Баннер/клик не считается | advertising component, statistic/conversion hooks | statistic disabled, wrong banner contract | `shop-marketing-analytics.md` |

## Automation / agents / realtime

| Симптом | Главные проверки | Частые причины | Читать |
|---|---|---|---|
| Agent не запускается | hit vs cron mode, schedule, module installed | agents disabled, long task in hit mode | `operations-runbook.md`, `update-stepper.md` |
| Stepper завис | state/checkpoint, batch size, error log | no resume state, memory/time limit | `update-stepper.md`, `operations-runbook.md` |
| Bizproc task не появился | provider/document type, template state, user rights | no provider for entity, template inactive, user mismatch | `shop-automation-bizproc.md` |
| Pull/realtime не обновляет | pull server config, channel/watch, JS init | pull not configured, no watch, websocket fallback issue | `shop-automation-bizproc.md`, `push-pull.md` |

## Release / update pitfalls

| Симптом | Главные проверки | Частые причины | Читать |
|---|---|---|---|
| После обновления ядра сломалась витрина | copied templates vs stock, component params, JS assets | stock contract changed, old copied template | `production-best-practices.md`, `components.md`, `templates.md` |
| После переноса стенда всё “почти работает” | module versions, site ids, iblock IDs/XML_ID, options, agents, files/clouds | numeric IDs differ, missing options/files | `operations-runbook.md`, `entities-migrations.md` |
| CI зелёный, runtime сломан | smoke route missing | only lint/tests, no Bitrix runtime check | `runtime-smoke-verification.md`, `php-testing.md` |

## Что нельзя делать

- Не фиксить симптом без определения слоя.
- Не менять права/кеш/SQL “наугад”.
- Не считать админскую видимость доказательством публичной видимости.
- Не считать successful import доказательством корректной карточки/checkout.
- Не считать созданный order доказательством корректной оплаты/доставки/обмена.
- Не обещать “всё покрыто” без runtime smoke evidence.

## С чем читать вместе

- Best practices — `production-best-practices.md`
- Runtime smoke — `runtime-smoke-verification.md`
- Visibility — `diagnostic-visibility.md`
- Component dataflow — `component-dataflow-debugging.md`
- Cache/index — `index-cache-diagnostics.md`
- Shop routing — `shop-task-matrix.md`

---

## Source: `runtime-smoke-verification.md`

# Runtime Smoke Verification — Bitrix/shop-core проверка на живом маршруте

> Reference для Bitrix-скилла. Загружай, когда задача требует доказать, что решение работает в runtime: Docker/sandbox, fixtures, ручные smoke-сценарии, release verification, “можно ли считать покрытым”. Этот файл фиксирует проверочный слой; он не подменяет code-first audit и не разрешает использовать production secrets/data без подтверждения.

## Статус

Текущий reference-слой даёт сильное **code-first** покрытие. Runtime smoke — отдельная фаза. До её выполнения нельзя говорить:

- “весь core полностью проверен в runtime”;
- “checkout/exchange/REST точно работает в этом проекте”;
- “можно подключать production 1С/платежи/доставки”.

Правильная формулировка: “контракт подтверждён по core; runtime нужно проверить на sandbox/fixtures”.

## Sandbox safety

Нельзя использовать без явного подтверждения:

- production DB dump с персональными данными;
- реальные 1С credentials;
- реальные платежные/кассовые/доставочные credentials;
- реальные SMS/email рассылки;
- production webhooks/tokens;
- публичное открытие SOAP/checkauth/test endpoints.

Для smoke нужны:

- isolated Docker/VM/local sandbox;
- test DB or sanitized dump;
- test site id and admin user;
- test catalog/offers/prices/stores;
- fake/test payment, delivery, SMS/email adapters;
- CommerceML fixtures;
- logs and rollback/reset plan.

## Docker execution plan

Docker-слой — это harness, а не поставка proprietary Bitrix core. Не коммитить ядро, license keys, DB dumps, `upload/`, реальные CommerceML XML, cookies/session ids и secrets.

Минимальная структура sandbox: `docker-compose.yml`, `.env.example`, локальный `www/`, синтетические `fixtures/`, `smoke/` scripts и `evidence/` без PII/secrets. Минимальные сервисы: `php`/`web`, `db`, `mailhog`/stub, fake SMS/payment/delivery endpoints, optional browser для screenshots.

Перед smoke зафиксировать `docker compose ps`, `php -v`, `php -m`, DB version и список `www/bitrix/modules`. Evidence сохранять как commands + fixture names + module versions + expected/actual + logs/screenshots.

## Порядок запуска smoke-прохода

Порядок: preflight → fixture import → read-only smoke → write-mode smoke только в sandbox → second request/cache pass → evidence pack → reference feedback. Не смешивать read-only и write-mode: если безопасного write sandbox нет, сценарий фиксируется как `blocked`, а не как pass.

## Пакет 1: каталог → SKU/цены/остатки → корзина/заказ

Первый runtime smoke-пакет доказывает минимальный shop path: товар виден, offer выбирается, цена/остаток корректны, товар добавляется в корзину, заказ сохраняется в test mode.

Prerequisites: `main`, `iblock`, `catalog`, `currency`, `sale`; sandbox site/template; test user или guest-only path; fake delivery/payment; mail/SMS stub; rollback/reset plan.

Fixtures: active section, visible simple product, inactive product, product without price, product with zero stock, product with two offers and `CML2_LINK`, store stock, test user, test delivery, test pay system.

Scenarios:

| ID | Что проверить | Pass |
|---|---|---|
| P1-01 | module/PHP/DB/site/template preflight | обязательные modules найдены, версии зафиксированы |
| P1-02 | public catalog list/detail | active виден, inactive скрыт |
| P1-03 | price/currency/stock | цена/валюта/zero-stock поведение соответствуют настройкам |
| P1-04 | SKU/offer selection | добавляется offer, а не parent product |
| P1-05 | guest basket | корзина сохраняется после reload, site/FUSER понятны |
| P1-06 | auth basket | test user видит корректную цену и корзину |
| P1-07 | checkout/order save | заказ создан в test mode, payment/shipment collections есть |
| P1-08 | second request/cache pass | кеш/composite не скрывает товар и не смешивает корзины |

Evidence: `Scenario`, sandbox URL/CLI, modules/versions, fixture names, user mode, steps, expected/actual, HTTP/CLI output, cache state, logs, rollback/reset, verdict `pass/fail/blocked`, follow-up reference changes.

Evidence convention: `evidence/YYYY-MM-DD-p1-shop-path/00-preflight.md`, `P1-01-modules.md` … `P1-08-cache-pass.md`, `summary.md`. Минимальные env: `SMOKE_BASE_URL`, `SMOKE_PUBLIC_ROOT`, `SMOKE_EVIDENCE_DIR`. Write-mode (`P1-05`–`P1-07`) запускать только при подтверждённом sandbox/reset plan. Если URL каталога/корзины/checkout неизвестны, найти их через `IncludeComponent`, `urlrewrite.php` и templates; не угадывать universal paths.

Готовые шаблоны: `assets/runtime-smoke/sandbox-preflight.template.md`, `scenario-result.template.md`, `evidence-summary.template.md`. Skeleton создаётся через `python3 scripts/init_runtime_evidence.py --package P1 --output evidence/YYYY-MM-DD-p1-shop-path`, полный набор P1–P4 — через `python3 scripts/init_runtime_evidence.py --all --output evidence/YYYY-MM-DD-runtime-smoke-all`; preflight можно собрать read-only helper-ом `python3 scripts/bitrix_runtime_preflight.py --public-root www --base-url "$SMOKE_BASE_URL"`. После заполнения запускать `python3 scripts/validate_runtime_evidence.py evidence/YYYY-MM-DD-p1-shop-path --package P1`. Если sandbox отсутствует, ориентироваться на `examples/runtime-smoke/blocked-p1`: это пример честного `blocked`, а не runtime pass.

## Пакеты 2–4: следующий runtime smoke

| Пакет | Цель | Минимальные сценарии |
|---|---|---|
| P2 CommerceML | проверить sandbox 1С-flow без production credentials | `checkauth`, `init`, `file`, catalog `import`, repeated import idempotency, broken XML negative, order export, non-eligible order exclusion |
| P3 REST/webservice | развести REST, SOAP/WSDL и CommerceML | method discovery, missing scope negative, sale event, catalog event, placement if needed, `webservice.sale`, `webservice.statistic` |
| P4 marketing/automation/realtime | проверить побочные shop-маршруты без реальных коммуникаций | sender segment, subscribe/unsubscribe, MailHog/stub mail, SMS fake provider, banner/click, conversion/report/statistic, bizproc/list task, pull/realtime |

Каждый сценарий запускать только после module check. Если нет safe sandbox, stub-а или test fixture — ставить `blocked`, не fake pass.

## Минимальный preflight

```bash
pwd
python3 scripts/bitrix_runtime_preflight.py --public-root www --base-url http://localhost
find www/bitrix/modules -maxdepth 1 -mindepth 1 -type d | sort
for m in main iblock currency catalog sale rest webservice statistic sender mail messageservice bizproc lists pull; do
  test -f "www/bitrix/modules/$m/install/version.php" && sed -n '1,40p' "www/bitrix/modules/$m/install/version.php"
done
find local bitrix/templates www/bitrix/templates -maxdepth 4 -type f 2>/dev/null | sort | head -200
```

Runtime facts to capture:

| Fact | Why |
|---|---|
| PHP version/extensions | Bitrix/runtime compatibility |
| DB type/version/charset | imports, indexes, ORM behavior |
| Site IDs/languages/templates | component routing and mail/SEO |
| Installed modules/versions | active/deferred route |
| Agent mode hit/cron | background tasks |
| Mail/SMS transport mode | no accidental real sends |
| Payment/delivery/cashbox mode | no real transaction |
| Composite/cache mode | public smoke validity: `X-Bitrix-Composite`, `?ncc=1`, `/bitrix/html_pages/`, dynamic areas |

## Fixture set

### Catalog fixture

- product iblock;
- offers iblock with `CML2_LINK`;
- product with active section;
- one inactive product;
- one product without price;
- one product with price but zero stock;
- one product with purchasable offer;
- one product with multiple offers;
- price types and currencies;
- at least one store and store stock;
- smart filter properties.

### Sale fixture

- guest basket scenario;
- authorized user basket scenario;
- person type;
- order properties;
- delivery service test/stub;
- pay system test/stub;
- discount/coupon;
- order status lifecycle;
- shipment/payment collections.

### 1С/CommerceML fixture

- `checkauth/init/file/import` catalog import XML;
- offer package with price/stock;
- order export fixture;
- large/chunked XML case if supported by sandbox;
- broken XML negative case;
- repeated import idempotency case.

### REST/webservice fixture

- incoming webhook/app test auth;
- method discovery check;
- sale order event binding;
- catalog product/price event binding;
- placement registration if relevant;
- `webservice.sale` SOAP statistics call;
- `webservice.statistic` call when statistic data exists;
- negative auth/scope case.

### Marketing/automation fixture

- sender contact/list/segment;
- sender subscribe form;
- SMS provider stub;
- advertising banner/click;
- A/B test simple page switch;
- conversion/report/statistic smoke;
- bizproc template/task;
- lists process;
- pull watch/realtime event.

## Smoke сценарии

### 1. Public catalog visibility

Expected evidence:

- product visible in list;
- product visible in detail;
- inactive product hidden;
- guest vs authorized behavior documented;
- component cache verified after first and second request;
- composite static HTML and dynamic areas verified by `X-Bitrix-Composite`, `?ncc=1`, guest/auth user checks.

Diagnostic chain:

```text
iblock data → section active chain → rights/site binding → component params/filter → pagination/sort → template → component/tagged cache → composite static HTML/dynamic areas
```

### 2. Offer/price/stock purchaseability

Expected evidence:

- product without price not purchasable;
- product with zero stock behavior matches settings;
- selected offer adds to basket;
- wrong product-vs-offer add is detected;
- price/currency formatting correct.

### 3. Basket and checkout

Expected evidence:

- add to basket works for guest and authorized user;
- basket persists through page reload/session;
- delivery and payment are shown according to restrictions;
- order properties validate;
- order can be saved in test mode;
- order email/event behavior verified without real sends.

### 4. Order lifecycle

Expected evidence:

- order created;
- payment collection exists;
- shipment collection exists;
- status changes via API path;
- discount/coupon result recorded;
- no direct SQL mutation required;
- events/logs captured.

### 5. CommerceML catalog import

Expected evidence:

- `checkauth` returns expected session/cookie contract;
- `init` returns import settings;
- `file` uploads fixture;
- `import` creates/updates product/offer/price/stock;
- repeated import does not duplicate entities;
- broken fixture produces controlled error.

### 6. CommerceML order export

Expected evidence:

- eligible test order appears in export;
- filters by status/date/site/person type match settings;
- exported XML has expected order/payment/shipment fields;
- non-eligible order is excluded.

### 7. REST event and method smoke

Expected evidence:

- `methods`/`method.get` confirm needed methods;
- app/webhook has required scopes;
- event binding exists;
- sale/catalog entity change triggers expected event;
- delivery retries/offline behavior is understood;
- negative missing-scope case fails safely.

### 8. `webservice.sale` / `webservice.statistic`

Expected evidence:

- WSDL/SOAP endpoint reachable only in allowed sandbox context;
- `webservice.sale` returns statistics/livefeed contract, not order CRUD;
- `webservice.statistic` result matches available statistic data;
- auth/test endpoint exposure is reviewed.

### 9. Marketing/analytics

Expected evidence:

- sender segment resolves contacts;
- posting/subscription flow works in test mode;
- mail/SMS are stubbed or captured;
- banner/click/conversion/report/statistic counters behave as expected;
- no real customer communication sent.

### 10. Automation/realtime

Expected evidence:

- bizproc template starts for controlled entity;
- task appears for expected user;
- lists process route works;
- pull/watch event reaches client or fallback path is documented;
- agents/stepper mode is captured.

## Verification output format

For every scenario capture:

```text
Scenario:
Modules/versions:
Input fixture:
Steps:
Expected:
Actual:
Logs/screenshots:
Cache/index actions:
Rollback/reset:
Verdict: pass/fail/blocked
Follow-up reference changes:
```

## Minimal smoke matrix for release confidence

| Area | Minimum pass condition |
|---|---|
| Core modules | versions captured, required modules installed |
| Component visibility | list/detail visible with cache behavior understood |
| Pagination/lazy | no duplicate/empty page with stable sort |
| Catalog | product/offer/price/stock fixture works |
| Basket | guest/auth add-to-basket works |
| Checkout | test order saved with delivery/payment |
| 1С import | fixture import idempotent |
| 1С export | test order exported when eligible |
| REST | method discovery + one event delivery |
| Webservice | sale/statistic SOAP contract verified or blocked reason captured |
| Marketing | one safe test channel captured/stubbed |
| Automation | one bizproc/list/pull scenario captured |
| Ops | agents/cache/logs/rollback documented |

## When smoke is blocked

Do not fake pass. Record:

- missing module;
- missing DB dump;
- no test credentials;
- no safe email/SMS/payment stub;
- PHP/DB incompatibility;
- endpoint inaccessible;
- legal/privacy blocker;
- missing fixture.

Then update skill answer as “code contract known, runtime verification blocked by X”.

## Common mistakes

- Running smoke on production data.
- Calling real payment/SMS/delivery services.
- Treating one successful import as full 1С coverage.
- Treating order creation as payment/shipment/export coverage.
- Forgetting second request with cache enabled.
- Ignoring guest vs authorized behavior.
- Not saving negative cases.
- Not feeding runtime findings back into reference files.

## С чем читать вместе

- Production best practices — `production-best-practices.md`
- Pitfalls — `pitfalls-matrix.md`
- Shop inventory — `shop-core-module-inventory.md`
- Shop tasks — `shop-task-matrix.md`
- Catalog — `catalog.md`
- Sale — `sale.md`
- 1С — `commerce-1c-integration.md`
- REST/webservice — `shop-integrations-webservice.md`
- Testing — `php-testing.md`
