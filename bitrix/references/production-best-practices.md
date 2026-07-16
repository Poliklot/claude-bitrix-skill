# Production Best Practices в Bitrix — core-first правила разработки

> Reference для Bitrix-скилла. Загружай, когда задача звучит как “как правильно сделать”, “best practices”, “как не сломать ядро”, “куда класть код”, “как проектировать доработку”, “как сделать production-ready”, “на что ориентироваться разработчикам”. Этот файл не заменяет модульные references: он задаёт cross-cutting правила, а конкретные API подтверждай в `catalog.md`, `sale.md`, `iblocks.md`, `components.md`, `rest.md` и других файлах.

## Принцип

Bitrix best practice — это не абстрактная “чистая архитектура”, а update-safe разработка поверх живого ядра:

1. **Не править vendor/core**: `www/bitrix/modules/*`, stock component code и ядро считаются source для чтения, а не местом кастомизации.
2. **Подтверждать контракт кодом**: сначала `www/bitrix/modules/<module>`, потом `local/*`, затем решение.
3. **Сохранять side effects**: rights, cache, search index, events, sale/catalog lifecycle, agents, statistics.
4. **Делать изменения воспроизводимыми**: migration/install step/CLI/agent/service вместо “кликнули в админке и забыли”.
5. **Держать boundary тонким**: `component.php`, `template.php`, event handler, controller, agent — вход/выход; логика — в сервисе.
6. **Проверять runtime path**: кодовая правка без smoke на реальном маршруте не доказывает production readiness.

## Truth stack перед любой задачей

Порядок:

```bash
find www/bitrix/modules -maxdepth 1 -mindepth 1 -type d | sort
sed -n '1,40p' www/bitrix/modules/<module>/install/version.php
find www/bitrix/modules/<module>/install/components/bitrix -maxdepth 2 -type f | sort
find local/components local/templates bitrix/templates www/bitrix/templates -maxdepth 5 -type f 2>/dev/null | sort
rg -n 'AddEventHandler|EventManager::getInstance\(\)->addEventHandler|On[A-Z][A-Za-z0-9_]+' local bitrix/templates www/bitrix/templates 2>/dev/null
```

Если модуль отсутствует — не предлагай его API как основной путь. Если есть copied template — сравнивай со stock template перед изменением. Если `local/*` нет — это факт, но остаются `bitrix/templates`, `www/bitrix/templates` и wizard assets.

## Где держать код

Для public page/layout/include решений дополнительно открывай [project-layout-and-includes.md](project-layout-and-includes.md): `header.php`/`footer.php`/`.section.php` и `/include` — проектные соглашения, а не универсальная схема.

| Что меняется | Предпочтительный слой | Не делай |
|---|---|---|
| Business rule | service/helper в `local/modules/<vendor>.<module>/lib` или project service | толстая логика в `template.php` |
| Data schema/options | migration/install step/idempotent CLI | ручная настройка без фиксации |
| Component view | copied template + минимальный `result_modifier.php` | правка stock component в `www/bitrix/modules` |
| Component data preparation | service/repository + params/cache contract | SQL в шаблоне |
| Event reaction | тонкий handler → service | handler с сотнями строк и скрытыми globals |
| Long operation | Stepper/agent/CLI with resume state | heavy loop в HTTP request |
| Integration | adapter + log + retry/idempotency | inline cURL в шаблоне/handler-е |
| Admin operation | admin action/controller + rights + sessid | публичный файл без доступа/CSRF |
| REST/API | Engine controller / existing REST layer | самодельный endpoint без auth/rate/error contract |

## Update-safe кастомизация

### Нельзя править

- `www/bitrix/modules/*`;
- stock `install/components/bitrix/*`;
- ядровые JS/CSS modules;
- generated/upload/runtime files как постоянный delivery path.

### Можно и нужно

- `local/modules/<vendor>.<module>/` для бизнес-логики;
- `local/components/<vendor>/<component>/` для собственных компонентов;
- copied templates в `local/templates/<template>/components/bitrix/<component>/<template>/`;
- event handlers в контролируемом module/bootstrap слое;
- migrations/install steps для структуры и options;
- CLI/agents/steppers для batch/runtime задач.

### Для copied template всегда фиксируй

1. откуда скопировано: module/component/template;
2. версия core на момент копирования;
3. что изменено;
4. какие `$arParams`/`$arResult` используются;
5. как сверять после обновления ядра.

## D7 vs legacy

Правило: D7 — default для чтения и service-layer, legacy — не стыдно, если конкретный модуль сохраняет side effects только через legacy API.

| Сценарий | Предпочтение | Почему |
|---|---|---|
| Simple read from table | D7 ORM/DataManager | typed filter/select, runtime fields |
| IBlock element write | проверять `iblocks.md`: часто `CIBlockElement`/core helper | events, property handling, search/cache |
| Catalog product/price/stock write | catalog API/model/provider, не raw SQL | availability, price cache, SKU/stock side effects |
| Sale basket/order/payment/shipment | sale entity lifecycle + `save()`/manager APIs | discounts, status, account number, events |
| Legacy module blog/forum/vote | `C*` API по core reference | D7 слой может быть неполным или read-oriented |
| HL block CRUD | D7 entity class from `compileEntity` | HL построен под ORM |
| Admin grid/filter | standard admin/grid APIs | UI state, sorting, pagination, actions |

Не обходи API прямым SQL для бизнес-сущностей, если у API есть rights/cache/events/index side effects.

## Boundary-first архитектура

Boundary в Bitrix:

- `component.php`, `class.php`;
- `result_modifier.php`, `component_epilog.php`, `template.php`;
- AJAX/controller action;
- REST method;
- event handler;
- agent/stepper/CLI;
- admin/public entrypoint.

Production pattern:

```text
Boundary → input normalization → service → repository/API adapter → Result/Error → boundary response
```

Boundary обязан:

- проверить module availability;
- проверить права/CSRF/sessid, если меняет данные;
- нормализовать вход;
- вызвать сервис;
- перевести результат в Bitrix UI/API contract;
- не держать тяжёлую бизнес-логику.

## Данные и изменения структуры

### Идентификаторы

- Для переносимых сущностей используй `XML_ID`, `CODE`, `API_CODE`, symbolic names, HL table name.
- Не хардкодь numeric IDs без runtime lookup.
- Для 1С/CommerceML критичны `XML_ID`, `CML2_LINK`, external IDs, price type/currency/store mapping.
- Для `.env`, `Option`, numeric IDs и stable-key registry открывай [project-configuration.md](project-configuration.md): классифицируй value, проверяй scope/uniqueness, missing/duplicate, type validation, cache/invalidation и secret boundary.

### Idempotency

Любой import/migration/CLI должен безопасно переживать повторный запуск:

- find-or-create by external key;
- compare-before-update;
- transaction or checkpoint where possible;
- batch limit;
- log error rows;
- rollback/restore note.

### Изменения данных

Перед прямым изменением реальных данных проговаривай:

```text
Операция:
Объект:
Что изменится:
Побочные эффекты:
Обратимость:
Проверка после:
```

## Cache/index/rbac side effects

После любой meaningful правки думай о слоях:

| Слой | Когда затрагивается |
|---|---|
| Component cache | component params/result changed, list/detail output |
| Tagged cache | iblock/catalog/HL dependent pages |
| Managed cache | module options, ORM metadata, rights, config |
| Composite/static cache | public pages with mixed guest/personal blocks; verify `setFrameMode` vote, `createFrame` dynamic boundary, `/bitrix/html_pages/`, `X-Bitrix-Composite` |
| Search index | content/title/body/url/rules changed |
| SEO artifacts | SEF, canonical, sitemap, robots, meta |
| Rights/session | user groups, access rules, auth/session changes |
| Sale/catalog runtime | basket/order/product/stock/discount lifecycle |

Не отвечай “почистить весь кеш” как финальное решение. Сначала найди слой и причину.

## Performance baseline

Для общего запроса “изучи проект и скажи как оптимизировать” сначала открывай [project-optimization-audit.md](project-optimization-audit.md): он задаёт формат аудита, grep-профиль, ранжирование и границы runtime/perfmon evidence.

Проверяй:

- N+1 queries in templates/result modifiers;
- repeated `Loader::includeModule`, `Option::get`, rights checks in loops;
- heavy component cache disabled by accident;
- personalized data in shared cache;
- missing stable sort with pagination;
- large import without batch/resume;
- full-table ORM select without `limit`;
- REST `batch`/pagination/error handling;
- sale/catalog recalculation in loops;
- agents running in hit mode instead of cron for heavy tasks.

Production fix обычно:

1. narrow select/filter;
2. batch/preload related data;
3. correct cache key/tag;
4. move heavy work to agent/stepper/CLI;
5. add smoke/perf evidence.

## Shop-specific правила

### Catalog/product/SKU

- Product visibility is not only `ACTIVE`: check section chain, site binding, rights, price, stock, `AVAILABLE`, component filter, cache and SKU relation.
- Offer data lives separately; card/list may show product while purchase path uses offer.
- `catalog.*` public components can physically live under `iblock`; that does not prove `catalog` module exists.
- Do not update price/stock by raw SQL.

### Sale/order

- Basket/order/payment/shipment are lifecycle entities, not just table rows.
- Order changes must preserve discounts, status history, properties, payments, shipments, events and account number logic.
- Checkout problems are diagnosed from basket → order builder → properties → delivery/payment restrictions → save → mail/events.
- Do not mutate `b_sale_*` directly unless writing a narrowly documented repair script with backup and side-effect plan.

### 1С/CommerceML

- `catalog.import.1c`, `catalog.export.1c`, `sale.export.1c` are CommerceML route.
- `webservice.sale` is sale statistics SOAP, not order exchange.
- StoreAssist is onboarding/checklist, not exchange engine.
- Never connect production 1С or real credentials for smoke without explicit confirmation.

### REST/webservice

- Confirm REST methods at runtime with `methods`, `method.get`, scopes and installed module controllers.
- REST event delivery depends on app/webhook/event binding layer; inspect `b_rest_*` and logs before blaming sale/catalog.
- SOAP endpoints may expose auth/test surfaces; review access and logging.

## Security baseline

- For state-changing HTTP/admin/AJAX actions require auth, rights and `sessid`/CSRF check.
- Do not log passwords, webhook tokens, 1С credentials, payment data or personal data.
- Do not expose `/bitrix/tools/*` or custom endpoints without access review.
- Respect file access and `clouds` handler; `CFile` path does not mean public access is safe.
- For user/session tasks read `session-auth.md`, `access-rbac.md`, `security.md`.

## Verification matrix

| Изменение | Минимальная проверка |
|---|---|
| PHP file | `php -l` or project-native test/static analysis |
| Component/template | guest + authorized smoke, cache on/off if relevant |
| IBlock/HL | data exists, rights/site binding, component output, cache/index |
| Search/SEO | index/sitemap/canonical/robots only if touched |
| Sale/catalog | product/list/card/basket/checkout/order lifecycle smoke |
| 1С exchange | checkauth/init/file/import or export smoke with fixture |
| REST | method discovery, scope, auth, event delivery/log |
| Agent/stepper/import | dry run/batch/resume/idempotency/log |
| Admin action | rights, sessid, error UI, rollback |

## Common anti-patterns

- “Почистить весь кеш” вместо диагностики слоя.
- Править ядро или stock component вместо copied template/local module.
- Писать SQL в `template.php`.
- Хардкодить IDs и site-specific values без lookup.
- Менять order/basket/payment/shipment direct SQL.
- Переписывать legacy на D7 без проверки side effects.
- Добавлять new tooling/framework ради одной маленькой правки.
- Делать long import в web request.
- Смешивать бизнес-логику, HTML, внешние API и кеш в одном файле.
- Обещать runtime correctness без smoke на живом маршруте.

## С чем читать вместе

- Pitfalls — [pitfalls-matrix.md](pitfalls-matrix.md)
- Runtime smoke — [runtime-smoke-verification.md](runtime-smoke-verification.md)
- PHP workflow — [php-workflow.md](php-workflow.md)
- Legacy modernization — [php-legacy-modernization.md](php-legacy-modernization.md)
- Components/dataflow — [component-dataflow-debugging.md](component-dataflow-debugging.md)
- Cache/index — [index-cache-diagnostics.md](index-cache-diagnostics.md)
- Operations — [operations-runbook.md](operations-runbook.md)
