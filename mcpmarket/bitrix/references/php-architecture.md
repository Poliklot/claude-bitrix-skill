# Php Architecture
> MCP Market compact bundle. Source files are concatenated from `bitrix/references/*` to keep the imported skill folder below the 50-file limit.

---

## Source: `production-best-practices.md`

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

Для общего запроса “изучи проект и скажи как оптимизировать” используй compact `search-seo-ops.md` раздел “Аудит оптимизаций Bitrix-проекта”, затем возвращай audit-report с evidence/safe wins/runtime-needed.

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

- Pitfalls — `pitfalls-matrix.md`
- Runtime smoke — `runtime-smoke-verification.md`
- PHP workflow — `php-workflow.md`
- Legacy modernization — `php-legacy-modernization.md`
- Components/dataflow — `component-dataflow-debugging.md`
- Cache/index — `index-cache-diagnostics.md`
- Operations — `operations-runbook.md`

---

## Source: `php-workflow.md`

# Bitrix PHP Workflow и Project Tooling — справочник

> Reference для Bitrix-скилла. Загружай, когда задача в проекте на Bitrix упирается не только в API ядра, но и в чисто PHP-слой: сервисы, DTO, исключения, composer/tooling, тесты, static analysis, formatting и границы между legacy и D7.
>
> Этот файл специально не подменяет core-first референсы. Он накладывается поверх них и помогает не тащить в Bitrix чужие Laravel/Symfony привычки.

## Содержание
- Когда подгружать этот reference
- Быстрая диагностика PHP toolchain
- Decision table: что куда класть
- PHP workflow без конфликта с Bitrix-нормами
- Минимальные quality gates
- Common mistakes
- С чем читать вместе

## Когда подгружать этот reference

Открывай этот файл, если задача звучит так:

- "разложи PHP-код по слоям"
- "как это тестировать"
- "можно ли тут `strict_types` / DTO / exceptions"
- "как жить с composer/phpunit/phpstan в Bitrix-проекте"
- "куда вынести логику из component.php / result_modifier.php / handler-а"
- "как не испортить legacy-код, но сделать его чище"

Не открывай его как первый источник, если вопрос целиком модульный и уже закрывается конкретным core-reference: например только `iblock`, только `landing`, только `form`, только `mobileapp`.

## Быстрая диагностика PHP toolchain

Сначала пойми, чем проект уже пользуется. Не навязывай стек, которого в репозитории нет.

```bash
php -v

rg --files . \
  -g '!vendor/**' \
  -g '!www/bitrix/modules/*/vendor/**' \
  -g 'composer.json' \
  -g 'composer.lock' \
  -g 'phpunit.xml' -g 'phpunit.xml.dist' \
  -g 'phpstan.neon' -g 'phpstan.neon.dist' \
  -g 'psalm.xml' -g 'psalm.xml.dist' \
  -g '.php-cs-fixer.php' -g '.php-cs-fixer.dist.php' \
  -g 'ecs.php' \
  -g 'phpcs.xml' -g 'phpcs.xml.dist' \
  -g 'rector.php' \
  -g 'infection.json' -g 'infection.json5'
```

Порядок чтения:

1. `composer.json` — есть ли вообще composer-autoload и scripts.
2. `phpunit.xml*` / `tests/` — есть ли реальный тестовый контур.
3. `phpstan*` / `psalm*` — есть ли статанализ и на каком уровне зрелости.
4. `.php-cs-fixer.php` / `ecs.php` / `phpcs.xml*` — чем форматируют код.
5. `rector.php` — есть ли автоматизированные кодовые миграции.

Игнорируй vendor noise внутри `www/bitrix/modules/*/vendor`: в текущем core там есть сторонние пакеты со своими `composer.json` и `phpunit.xml.dist`, и это не означает, что project contour уже настроен.

Если ничего из этого нет, не изображай, что проект обязан жить по современному PHP-tooling full stack. Для такого проекта минимальный безопасный baseline: `php -l` по изменённым файлам, аккуратные PHPDoc-контракты и сохранение текущего стиля кода.

## Decision table: что куда класть

| Задача | Предпочтительный слой | Не делай по умолчанию |
|---|---|---|
| Бизнес-правило | local-модульный сервис / project service class | `template.php`, `component.php`, handler с толстой логикой |
| Валидация входных данных | `ValidationService`, rule attributes, value checks в DTO/request object | разбрасывать валидацию по шаблону и контроллеру |
| Ошибка на domain-слое | exception внутри сервиса или `Result/Error` как контракт сервиса | смешивать raw exceptions, `LAST_ERROR` и строковые флаги без границ |
| Ответ наружу | на Bitrix boundary переводить в `Result/Error`, controller `addError`, понятный UI-state | отдавать exception trace в шаблон или AJAX-ответ |
| Сильная типизация | локальные service/DTO/value-object файлы | слепо добавлять `declare(strict_types=1)` в legacy entrypoint |
| Тестирование | pure service + существующий PHPUnit/Pest контур | пытаться тестировать `template.php` как основной unit |
| Статанализ | использовать уже настроенный phpstan/psalm | заводить новый tool только ради одной задачи |
| Форматирование | существующий fixer/sniffer проекта | тотальный reformat файлов “под себя” |

## PHP workflow без конфликта с Bitrix-нормами

### 1. Сначала отдели Bitrix boundary от чистой логики

Boundary в Bitrix-проекте обычно один из этих:

- `component.php`
- `result_modifier.php`
- `component_epilog.php`
- `init.php`, `include.php`
- AJAX/controller action
- event handler
- admin/public `*.php` entrypoint

Правило: boundary-файл координирует, а тяжёлая логика живёт рядом в сервисе.

### 2. Следуй toolchain проекта, а не своему любимому стеку

- Есть `composer.json` и autoload — используй это.
- Есть `phpunit.xml*` — добавляй тест туда, а не придумывай новый harness.
- Есть `phpstan` или `psalm` — проверяй ими изменённый участок.
- Есть fixer/sniffer — форматируй только через него.
- Ничего этого нет — не тащи новый стек как обязательное условие мелкой доработки.

### 3. Modern PHP применяй выборочно

`final`, `readonly`, typed properties, constructor promotion, маленькие DTO и value objects — это хорошо, но только там, где слой действительно локальный и изолированный:

- `local/modules/vendor.module/lib/...`
- project services
- request/response DTO
- integration adapters

Не надо механически тащить modern-PHP приёмы в:

- `bitrix/templates/.../template.php`
- `result_modifier.php`, если там полудинамический legacy массивный код
- старые admin/public entrypoints
- обработчики, где всё завязано на глобалы и mixed-данные без подготовки

### 4. `declare(strict_types=1)` не включай вслепую

Разрешённый safe-zone по умолчанию:

- новые локальные сервисы;
- DTO/value-object файлы;
- отдельные helper/adapter-классы;
- автономные CLI-скрипты проекта.

Опасная зона без дополнительной проверки:

- legacy entrypoints;
- компонентные шаблоны и модификаторы;
- admin/public php-файлы;
- файлы, где активно смешиваются глобалы, mixed-массивы и старые `C*` API.

Если surrounding code живёт без strict types и активно relies on coercion, не ломай его ради “красоты”.

### 5. Исключения внутри, `Result/Error` на границе

Практичный паттерн для Bitrix:

```php
use Bitrix\Main\Result;
use Bitrix\Main\Error;

final class ProfileService
{
    public function update(int $userId, array $payload): Result
    {
        $result = new Result();

        try {
            // domain logic, validation, repository/ORM calls
        } catch (\DomainException $e) {
            $result->addError(new Error($e->getMessage(), 'PROFILE_DOMAIN_ERROR'));
        } catch (\Throwable $e) {
            $result->addError(new Error('Unexpected profile update failure', 'PROFILE_UNEXPECTED'));
        }

        return $result;
    }
}
```

Идея не в том, чтобы запретить exceptions, а в том, чтобы на Bitrix-boundary у тебя был предсказуемый контракт.

### 6. Для legacy-массивов добавляй контракт, а не магию

Если работаешь с `$arParams`, `$arResult`, `fetch()`-массивами или `C*`-API, часто самый дешёвый и полезный шаг — добавить локальный PHPDoc:

```php
/** @var array{
 *     ITEM_ID:int,
 *     TITLE:string,
 *     CAN_EDIT:bool
 * } $arResult
 */
```

Это особенно полезно, когда проект без полноценного phpstan/psalm, но код всё равно надо сделать читаемым и менее хрупким.

### 7. Тестируй сервис, а не шаблон

Если проект уже умеет в PHPUnit/Pest, нормальная стратегия такая:

1. вынести бизнес-логику из boundary в service;
2. протестировать service как unit/integration;
3. boundary оставить тонким glue-layer.

Если тестового контура нет, не делай вид, что ты обязан сначала внедрить фреймворк тестов. Иногда для безопасной правки достаточно:

- извлечь pure method;
- прогнать `php -l`;
- сверить существующий runtime path;
- оставить код проще и контрактнее, чем был.

## Минимальные quality gates

### Если toolchain уже есть

- `composer.json` есть: смотри scripts и используй project-native команды.
- `phpunit.xml*` есть: добавляй или обновляй тесты рядом с существующими.
- `phpstan*` / `psalm*` есть: проверяй хотя бы затронутый путь.
- fixer/sniffer есть: не форматируй руками против него.

### Если toolchain нет

Минимальный sane baseline:

1. `php -l` на изменённых файлах.
2. Проверка namespace/use/import-ов.
3. Проверка, не ушла ли тяжёлая логика в шаблон.
4. Проверка, не сломан ли boundary с Bitrix API.
5. Явный контракт для mixed-данных там, где это реально помогает.

## Common mistakes

- Слепо переносить в Bitrix Laravel/Symfony-паттерны: repositories, service providers, controllers-first architecture, если проект так не устроен.
- Форсить `composer`, `phpunit`, `phpstan`, `rector` в проект, где их нет, ради маленькой доработки.
- Добавлять `declare(strict_types=1)` в legacy-файл, не проверив surrounding code.
- Лечить плохую структуру обёртками и DTO everywhere вместо того, чтобы сначала вынести реальную бизнес-логику из boundary.
- Кидать raw exception до шаблона/AJAX-ответа вместо перевода в предсказуемый Bitrix-контракт.
- Переписывать старый `C*`-маршрут “на чистый DDD” там, где задача была в одной точечной правке.

## С чем читать вместе

- Архитектура модуля, Loader, ServiceLocator — `modules-loader.md`
- Контроллеры, события, routing — `events-routing.md`
- ValidationService и attributes — `validation.md`
- ORM и `Result/Error` — `orm.md`
- DB layer и совместимость разных СУБД — `database-layer.md`
- Тестирование и verification — `php-testing.md`
- Quality gates — `php-quality.md`
- Legacy modernization — `php-legacy-modernization.md`
- Шаблоны и component layer — `components.md`, `templates.md`

---

## Source: `php-testing.md`

# Bitrix PHP Testing и Verification — справочник

> Reference для Bitrix-скилла. Загружай, когда задача упирается в проверку PHP-кода: unit/integration tests, smoke checks, PHPUnit-контур, test seams, fixtures, event handlers, controller actions и безопасную верификацию без поломки Bitrix-boundary.
>
> Этот файл не подменяет core-first и не требует “идеального” test stack. Он помогает честно понять, что проект уже умеет, а чего в нём нет.

## Содержание
- Когда подгружать этот reference
- Что реально показывает текущее ядро
- Как распознать настоящий test contour проекта
- Decision table: что и как тестировать
- Практичный workflow для PHPUnit и без него
- Test seams и fixtures без конфликта с Bitrix
- Минимальная verification matrix
- Common mistakes
- С чем читать вместе

## Когда подгружать этот reference

Открывай этот файл, если задача звучит так:

- "как это покрыть тестами"
- "куда тут писать PHPUnit"
- "как проверить handler/controller/service без хака ядра"
- "если тестового контура нет, что делать вместо сказок"
- "как безопасно проверить Bitrix-доработку перед релизом"

Не открывай его первым, если вопрос целиком про API конкретного модуля и не касается проверки изменений.

## Что реально показывает текущее ядро

По текущему core важно видеть три факта:

1. В `www/bitrix/modules/main/lib/test/` лежат внутренние test fixtures ядра вроде ORM entity-классов `Bitrix\Main\Test\Typography\*`. Это полезный ориентир по структуре test data, но не готовый PHPUnit-контур проекта.
2. В `www/bitrix/modules/security/classes/general/tests/` лежит собственный диагностический слой security-модуля с базовым классом `CSecurityBaseTest` и пакетами тестов через `CSecurityTestsPackage`. Это runtime/site-checker проверки, а не универсальная project test framework.
3. Внутри `www/bitrix/modules/main/vendor/*` есть сторонние пакеты со своими `composer.json` и даже `phpunit.xml.dist` вроде PHPMailer. Это vendor noise, а не сигнал, что проект уже живёт на Composer/PHPUnit.

Вывод: текущий core даёт ориентиры по внутренним patterns и diagnostic checks, но не доказывает наличие единого PHP test harness в конкретном проекте.

## Как распознать настоящий test contour проекта

Сканируй только project-level и local-level артефакты. Не принимай vendor-файлы из ядра за проектную настройку.

```bash
rg --files . \
  -g '!vendor/**' \
  -g '!www/bitrix/modules/*/vendor/**' \
  -g 'composer.json' \
  -g 'composer.lock' \
  -g 'phpunit.xml' -g 'phpunit.xml.dist' \
  -g 'phpstan.neon' -g 'phpstan.neon.dist' \
  -g 'psalm.xml' -g 'psalm.xml.dist' \
  -g '.php-cs-fixer.php' -g '.php-cs-fixer.dist.php' \
  -g 'phpcs.xml' -g 'phpcs.xml.dist' \
  -g 'ecs.php' \
  -g 'rector.php' \
  -g 'tests/**' -g 'test/**'
```

Сигналы настоящего project contour:

- root `composer.json` или `local/modules/*/composer.json`, который относится к проекту, а не к vendor package;
- `phpunit.xml*` с bootstrap-ом проекта;
- реальные `tests/` рядом с `local/modules`, `local/php_interface`, project services;
- composer scripts или CI-команды, которые уже запускают тесты.

Сигналы, которые нельзя считать доказательством:

- `composer.json` внутри `www/bitrix/modules/main/vendor/...`;
- `phpunit.xml.dist` у сторонней библиотеки в core vendor;
- JS `test/` каталоги модулей ядра;
- внутренние `main/lib/test/*` fixture-классы без project bootstrap.

## Decision table: что и как тестировать

| Слой | Что проверять | Предпочтительный тип проверки | Не делай по умолчанию |
|---|---|---|---|
| Pure service / domain logic | расчёты, валидация, branching | unit test | full Bitrix bootstrap ради одной pure function |
| Service c ORM/DB | `Result/Error`, выборки, persistence side effects | integration test на существующем harness | мокать весь ORM так, что тест теряет смысл |
| Controller action / AJAX endpoint | request contract, errors, response payload | integration или тонкий functional test | тестировать template HTML вместо контракта action |
| Event handler | входные данные, idempotency, side effects | integration/smoke вокруг вынесенного service | хранить всю бизнес-логику прямо в handler и потом пытаться unit-test-ить его |
| Component `class.php` / `component.php` | orchestration, parameters, service calls | test service + smoke component path | считать `template.php` главным местом для unit tests |
| `result_modifier.php` | transform массива к шаблону | extract helper/service и test его | строить сложный test harness прямо под modifier |
| CLI/agent/stepper | command flow, batches, retries | integration/smoke command test | гонять это только руками в проде |
| External integration adapter | mapping request/response, retries, errors | unit + contract/smoke | ходить реальным внешним API в каждый локальный test run |

## Практичный workflow для PHPUnit и без него

### 1. Сначала выбери test target

Нормальная последовательность для Bitrix-проекта:

1. определить boundary: component, controller, handler, agent, CLI, admin/public entrypoint;
2. вынести основную логику в service/helper/adapter;
3. тестировать этот слой в первую очередь;
4. boundary оставить тонким и проверить smoke-ом или integration-путём.

### 2. Если PHPUnit-контур уже есть

- Клади тест в существующее дерево `tests/`, а не придумывай новый layout.
- Используй текущий bootstrap проекта, не выдумывай "универсальный bootstrap для всех Bitrix".
- Для pure service делай быстрые unit tests.
- Для кода с ORM, `Loader`, `Option`, `EventManager`, controller routing — предпочитай integration tests, если такой контур уже существует.
- Проверяй затронутый scope через project-native команду: `composer test`, конкретный `phpunit --filter`, make target или CI script.

### 3. Если PHPUnit-контура нет

Не делай вид, что без мгновенного внедрения PHPUnit работа невозможна.

Минимально честный путь:

1. вынести тестопригодный service/helper из boundary;
2. прогнать `php -l` по изменённым файлам;
3. выполнить локальный smoke path через существующий runtime проекта;
4. проверить ошибки/логи/`Result/Error` на реальном кодовом маршруте;
5. оставить код тестопригоднее, чем он был до правки.

### 4. Не путай verification и full test adoption

У задачи "безопасно поправить обработчик" и у задачи "внедрить системный PHPUnit contour" разный масштаб.

- Для маленькой доработки достаточно safe verification.
- Для повторяющегося критичного домена можно уже предлагать выделенный test contour.
- Не расширяй scope без необходимости.

## Test seams и fixtures без конфликта с Bitrix

### 1. Делай seam вокруг глобального Bitrix-boundary

Плохо тестируются напрямую:

- `$USER`, `$APPLICATION`, глобалы и superglobals;
- inline `Loader::includeModule()` по всему коду;
- прямые вызовы `Option::get()` в чистой бизнес-логике;
- controller/handler, где всё смешано в одном методе.

Лучше:

- завернуть current user / clock / config / external IO в маленькие adapter-классы;
- передавать в service уже нормализованные входные данные;
- хранить тяжёлую логику вне шаблона и entrypoint-а.

### 2. Fixture-подход должен соответствовать проекту

Если в проекте уже есть fixture builders, factories, dataset files или test bootstrap с очисткой БД — используй их.

Если нет, минимально sane path:

- тестируй pure service на in-memory данных;
- для integration-кода создавай только необходимый минимум сущностей;
- явно очищай за собой данные, если test contour это поддерживает;
- не привязывай тест к случайным данным конкретной dev-базы.

### 3. Что можно взять как ориентир из core

- `main/lib/test/` полезен как пример изолированных test entities и fixture-style ORM-описаний.
- `security/classes/general/tests/` полезен как пример встроенных diagnostic checks и пакетирования проверок по типам.

Но не копируй их механически в project layer: это примеры изнутри ядра, а не универсальный шаблон для любого `local/modules/vendor.module`.

## Минимальная verification matrix

### Если project test contour уже есть

Старайся закрыть хотя бы это:

1. unit test на вынесенный service/helper;
2. integration test на слой с ORM/DB/API, если он уже существует в проекте;
3. запуск project-native static analysis или хотя бы затронутого scope;
4. локальный smoke path на boundary, если менялся controller/component/handler.

### Если project test contour нет

Минимальный безопасный baseline:

1. `php -l` на изменённых файлах;
2. проверка imports, namespace и bootstrap path;
3. ручной или scripted smoke по реальному сценарию;
4. проверка логов/ошибок/`Result`-контрактов;
5. фиксация, какой кусок кода теперь можно покрыть тестом позже без переписывания заново.

## Common mistakes

- Считать `phpunit.xml.dist` внутри `www/bitrix/modules/main/vendor/...` признаком, что проект уже работает на PHPUnit.
- Пытаться unit-test-ить `template.php` вместо вынесения логики.
- Поднимать полный Bitrix bootstrap для pure function, которую можно проверить без него.
- Предлагать массовое внедрение PHPUnit/phpstan/CI, когда задача была в точечной правке handler-а.
- Мокать весь Bitrix слой так агрессивно, что тест перестаёт ловить реальные регрессии.
- Привязывать тесты к данным конкретной dev/stage базы.
- Проверять только happy path и забывать про `Result/Error`, валидацию и повторный запуск handler/agent.

## С чем читать вместе

- PHP architecture и toolchain — `php-workflow.md`
- PHP quality — `php-quality.md`
- Legacy modernization — `php-legacy-modernization.md`
- Архитектура модуля, Loader, ServiceLocator — `modules-loader.md`
- Контроллеры, handlers, routing — `events-routing.md`
- ORM и `Result/Error` — `orm.md`
- ValidationService и attributes — `validation.md`
- DB layer и различия СУБД — `database-layer.md`
- Компоненты и template layer — `components.md`, `templates.md`

---

## Source: `php-quality.md`

# PHP Quality в Bitrix-проекте — справочник

> Reference для Bitrix-скилла. Загружай, когда задача касается `phpstan`, `psalm`, fixer/sniffer, `rector`, CI, lint, code style или quality gates.

## Содержание
- Сначала найди project tooling
- Что запускать
- Как внедрять аккуратно
- Bitrix-specific quality rules
- Common mistakes

## Сначала найди project tooling

```bash
rg --files . \
  -g '!vendor/**' \
  -g '!www/bitrix/modules/*/vendor/**' \
  -g 'composer.json' \
  -g 'phpstan.neon' -g 'phpstan.neon.dist' \
  -g 'psalm.xml' -g 'psalm.xml.dist' \
  -g '.php-cs-fixer.php' -g '.php-cs-fixer.dist.php' \
  -g 'ecs.php' \
  -g 'phpcs.xml' -g 'phpcs.xml.dist' \
  -g 'rector.php' \
  -g 'phpunit.xml' -g 'phpunit.xml.dist'
```

Если tooling найден только внутри `www/bitrix/modules/*/vendor`, это не project tooling.

## Что запускать

| Найдено | Действие |
|---|---|
| `composer.json` | проверить `scripts`, autoload, dev tools |
| `phpstan.neon*` | запускать project-native phpstan на затронутом scope |
| `psalm.xml*` | запускать psalm только с текущей конфигурацией |
| fixer/sniffer | форматировать только затронутые файлы |
| `rector.php` | применять точечно и читать diff |
| ничего нет | `php -l` + manual import/namespace/runtime check |

## Как внедрять аккуратно

Внедрение нового quality tool — отдельная задача, а не побочный эффект маленькой правки.

Минимальный путь для проекта без tooling:

1. `php -l` изменённых файлов;
2. PHPDoc/array-shape для mixed-массивов;
3. small service extraction из boundary;
4. smoke-check реального маршрута;
5. отдельное предложение по tooling только если домен повторяющийся и критичный.

## Bitrix-specific quality rules

- Не требуй идеальной типизации в legacy entrypoints.
- Не включай `declare(strict_types=1)` в шаблон/старый admin/public файл без проверки.
- Не переписывай `C*` API на D7, если конкретный модуль сохраняет side effects только в legacy write path.
- Для `$arParams`, `$arResult`, `fetch()` rows лучше добавить локальный контракт, чем устраивать масштабный DTO rewrite.
- Для module/service layer можно использовать современный PHP осторожнее: typed properties, DTO, value objects, `final`, adapters.

## Common mistakes

- Поднять уровень phpstan/psalm сразу на весь legacy-проект.
- Прогнать fixer по огромному файлу и смешать форматирование с логической правкой.
- Применить rector к `bitrix/templates` и получить поведенческий diff.
- Считать warnings от vendor/core своим project debt.
- Добавить tools в composer без согласованного CI/runtime плана.

## С чем читать вместе

- PHP workflow — `php-workflow.md`
- PHP testing — `php-testing.md`
- Legacy modernization — `php-legacy-modernization.md`
- Modules — `modules-loader.md`

---

## Source: `php-legacy-modernization.md`

# PHP Legacy Modernization в Bitrix — справочник

> Reference для Bitrix-скилла. Загружай для задач “почистить legacy”, “вынести логику”, “перевести на D7”, “сделать безопаснее без переписывания проекта”.

## Содержание
- Принцип
- Разделение boundary и логики
- Safe sequence
- Где можно modern PHP
- Где осторожно
- Common mistakes

## Принцип

Цель modernization — не “переписать на красивый PHP”, а уменьшить риск следующей правки.

В Bitrix сначала сохраняй runtime-контракт:

- module availability через `Loader`;
- права и текущий пользователь;
- кеши и индексы;
- side effects legacy API;
- component/template contract.

## Разделение boundary и логики

Boundary:

- `component.php`, `class.php`;
- `result_modifier.php`;
- `template.php`;
- event handler;
- controller action;
- agent/CLI/admin/public entrypoint.

Modernization target:

- service class;
- helper/normalizer;
- adapter к внешнему API;
- validator;
- DTO/value object для локального слоя.

## Safe sequence

1. Зафиксируй текущий runtime path.
2. Найди бизнес-логику внутри boundary.
3. Вынеси минимальный чистый кусок в service/helper.
4. Оставь boundary тонким: получить вход, вызвать service, перевести результат в Bitrix contract.
5. Добавь проверку: test, smoke или `php -l` + ручной сценарий.
6. Только потом улучшай типы/DTO/PHPDoc.

## Где можно modern PHP

Обычно можно:

- новые файлы в `local/modules/<vendor>.<module>/lib`;
- project services;
- integration adapters;
- validators;
- CLI helpers;
- pure mappers/normalizers.

Там допустимы `strict_types`, typed properties, constructor promotion, readonly DTO, `final`, exceptions внутри domain layer.

## Где осторожно

Проверяй отдельно:

- `template.php`;
- `result_modifier.php`;
- старые admin/public entrypoints;
- обработчики с global state;
- файлы, которые активно используют mixed-массивы и coercion;
- legacy module write paths.

## D7 vs legacy

Правило:

- Для чтения D7 ORM часто уместен.
- Для записи смотри конкретный core: например blog D7 tables могут быть read-oriented, а мутации должны идти через `CBlog*`.
- Если legacy API запускает обработчики, индексацию, права или кеш, не обходи его ради “чистого” DataManager.

## Common mistakes

- Переписать старый файл целиком и потерять скрытые side effects.
- Добавить DTO everywhere, но оставить бизнес-логику в шаблоне.
- Перевести write path на D7 без проверки core.
- Заменить понятный legacy код абстракциями, которых нет в проекте.
- Внедрить новый framework-style слой, не совпадающий с Bitrix architecture.

## С чем читать вместе

- PHP workflow — `php-workflow.md`
- PHP quality — `php-quality.md`
- PHP testing — `php-testing.md`
- Components — `component-dataflow-debugging.md`
- ORM — `orm.md`

---

## Source: `modules-loader.md`

# Bitrix Модули, Loader, Application — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с созданием модуля, Loader, PSR-4 автозагрузкой, Application, ServiceLocator, Config\Option или локализацией.
>
> Audit note (core-verified, current project): справочник сверялся по `www/bitrix/modules/main/lib/{loader.php,di/servicelocator.php}`, `main/lib/engine/resolver.php` и установленным module `.settings.php`.

## Содержание
- Application и ServiceLocator
- Config\Option — настройки модуля
- Локализация (Loc)
- Структура модуля: include.php, install/index.php, version.php, .settings.php
- Инсталлятор: CModule, InstallDB/UnInstallDB
- Loader: requireModule, registerNamespace, local/ vs bitrix/

---

## Application и сервис-локатор

`Application::getInstance()` — синглтон, точка входа во всё приложение. Через него получаешь соединение с БД, кеш, контекст запроса. `ServiceLocator` — DI-контейнер Bitrix: регистрируешь сервисы один раз, получаешь их по имени. После успешного `Loader::includeModule($module)` ядро дополнительно вызывает `ServiceLocator::registerByModuleSettings($module)`.

```php
$app = \Bitrix\Main\Application::getInstance();

// ServiceLocator — типовой lazy registration
$serviceLocator = \Bitrix\Main\DI\ServiceLocator::getInstance();
$serviceLocator->addInstanceLazy('myVendor.orderService', [
    'className' => \MyVendor\MyModule\OrderService::class,
]);
// Получай где угодно
$service = $serviceLocator->get('myVendor.orderService');

// Запрос и ответ — безопасный способ получить параметры
$request = $app->getContext()->getRequest();
$id      = (int)$request->getQuery('id');    // GET-параметр
$title   = (string)$request->getPost('title'); // POST-параметр
// Никогда не используй $_GET/$_POST напрямую в D7-коде
```

---

## Config\Option — настройки модуля

Хранятся в таблице `b_option`. Используй для конфигурационных значений модуля — API-ключи, лимиты, флаги. Не используй для пользовательских данных или данных, которые меняются часто (для этого есть ORM-таблицы).

```php
use Bitrix\Main\Config\Option;

$value = Option::get('my.module', 'API_KEY', '');          // третий аргумент — дефолт
Option::set('my.module', 'API_KEY', $newKey);
Option::delete('my.module', ['name' => 'API_KEY']);
```

---

## Локализация

`Loc::getMessage()` ищет ключ в lang-файле рядом с текущим PHP-файлом. `loadMessages(__FILE__)` говорит системе: "загрузи lang-файл для этого файла". Без вызова `loadMessages` ключи будут пустыми.

```php
use Bitrix\Main\Localization\Loc;

Loc::loadMessages(__FILE__); // вызывай в начале каждого файла где нужны переводы

echo Loc::getMessage('MY_MODULE_GREETING', ['#NAME#' => 'Иван']);
// lang/ru/my_file.php: $MESS['MY_MODULE_GREETING'] = 'Привет, #NAME#!';
// lang/en/my_file.php: $MESS['MY_MODULE_GREETING'] = 'Hello, #NAME#!';
```

---


---
## Модули

### Архитектурный смысл

Модуль в Bitrix — это изолированная библиотека функциональности с собственной схемой БД, правами, событиями и PSR-4 namespace. Каждый модуль регистрируется в системе через инсталлятор. В типовом потоке именно `Loader::includeModule()` / `Loader::requireModule()`:
- проверяет, что модуль установлен
- ищет его сначала в `local/modules`, потом в `bitrix/modules`
- регистрирует PSR-4 namespace модуля
- подключает `include.php`
- регистрирует `services` из module `.settings.php`

Поэтому для стандартной модульной загрузки не предполагай, что namespace “сам уже доступен” без `includeModule()`. Ручной `Loader::registerNamespace()` — это уже отдельный путь.

**Поиск модуля** — сначала `local/modules/`, потом `bitrix/modules/`. Это позволяет переопределять стандартные модули в `local/`.

**PSR-4 автозагрузка** регистрируется автоматически:
- Bitrix-модуль `iblock` → namespace `Bitrix\Iblock` → `/bitrix/modules/iblock/lib`
- Партнёрский модуль `vendor.mymodule` → namespace `Vendor\Mymodule` → `/bitrix/modules/vendor.mymodule/lib`
- Файл `lib/service/ordermanager.php` → класс `Vendor\Mymodule\Service\OrderManager`

### Структура модуля

```
local/modules/vendor.mymodule/
├── include.php              ← точка входа, подключается Loader-ом
├── .settings.php            ← конфигурация ServiceLocator, роутов, REST
├── lib/                     ← PSR-4 корень
│   ├── OrderTable.php       ← DataManager: ПРЯМО в корне lib (Bitrix-way)
│   ├── EventHandler.php     ← обработчики событий — тоже в корне
│   ├── Controller/          ← capital C — как в реальных модулях ядра
│   │   └── Order.php        ← Vendor\Mymodule\Controller\Order
│   └── service/             ← lowercase — как в реальных модулях
│       └── OrderService.php ← Vendor\Mymodule\Service\OrderService
└── install/
    ├── index.php            ← класс-инсталлятор, extends CModule
    ├── version.php          ← VERSION, VERSION_DATE
    └── db/
        ├── mysql/
        │   ├── install.sql
        │   └── uninstall.sql
        └── pgsql/
```

---

### Канонические соглашения: где что лежит

| Тип класса | Путь в lib/ | Пример файла | Пример класса |
|---|---|---|---|
| DataManager (ORM-таблица) | `lib/` корень | `lib/OrderTable.php` | `Vendor\Module\OrderTable` |
| Controller (AJAX/REST) | `lib/Controller/` | `lib/Controller/Order.php` | `Vendor\Module\Controller\Order` |
| Сервис | `lib/service/` | `lib/service/OrderService.php` | `Vendor\Module\Service\OrderService` |
| Обработчик событий | `lib/` корень | `lib/EventHandler.php` | `Vendor\Module\EventHandler` |
| Интеграция с другими модулями | `lib/Integration/` | `lib/Integration/Catalog.php` | `Vendor\Module\Integration\Catalog` |
| Вспомогательные классы | `lib/helper/` | `lib/helper/Formatter.php` | `Vendor\Module\Helper\Formatter` |
| Внутренние детали | `lib/internals/` | `lib/internals/...` | не публичный API |
| Legacy без PSR-4 | `classes/general/` | `classes/general/myclass.php` | регистрируется в `include.php` |

**Регистр директорий:** `Controller/` — capital C (как в ядре), `service/` и `helper/` — lowercase.

---

### Анти-паттерны (что НЕ делать)

```
# Это Laravel/Symfony-паттерны — в Bitrix так НЕ делают:
lib/model/OrderTable.php      → правильно: lib/OrderTable.php
lib/models/                   → нет такой директории в Bitrix-модулях
lib/repository/               → Repository слой в Bitrix не используется
lib/Repositories/             → аналогично
lib/Http/Controllers/         → нет, контроллеры в lib/Controller/
```

---

### Пример: модуль vendor.favorites

```
local/modules/vendor.favorites/
├── include.php
├── .settings.php
├── lib/
│   ├── FavoriteTable.php        ← DataManager (lib root!)
│   ├── EventHandler.php         ← обработчики событий
│   ├── Controller/
│   │   └── Favorite.php         ← AJAX-контроллер
│   └── service/
│       └── FavoriteService.php  ← бизнес-логика
└── install/
    ├── index.php
    ├── version.php
    └── db/mysql/
        ├── install.sql
        └── uninstall.sql
```

### include.php

```php
<?php
// include.php — вызывается при Loader::includeModule()
// Обычно пустой или подключает legacy-файлы
// PSR-4 регистрируется автоматически, include.php не обязан ничего делать

use Bitrix\Main\Localization\Loc;
Loc::loadMessages(__FILE__);
```

### install/index.php — инсталлятор

Имя класса инсталлятора = MODULE_ID с заменой `.` на `_`. Пример: `vendor.mymodule` → класс `vendor_mymodule`. Это жёсткое требование ядра — `CModule` ищет класс именно по такому имени.

```php
<?php
use Bitrix\Main\Localization\Loc;
use Bitrix\Main\ModuleManager;
use Bitrix\Main\EventManager;
use Bitrix\Main\Application;

Loc::loadMessages(__FILE__);

class vendor_mymodule extends CModule
{
    public $MODULE_ID = 'vendor.mymodule';
    public $MODULE_VERSION;
    public $MODULE_VERSION_DATE;
    public $MODULE_NAME;
    public $MODULE_DESCRIPTION;

    public function __construct()
    {
        $version = [];
        include __DIR__ . '/version.php';
        $this->MODULE_VERSION      = $version['VERSION'];
        $this->MODULE_VERSION_DATE = $version['VERSION_DATE'];
        $this->MODULE_NAME         = Loc::getMessage('VENDOR_MYMODULE_NAME');
        $this->MODULE_DESCRIPTION  = Loc::getMessage('VENDOR_MYMODULE_DESCRIPTION');
    }

    public function InstallDB(): bool
    {
        $connection = Application::getConnection();
        $connection->queryExecute(
            file_get_contents(__DIR__ . '/db/' . $connection->getType() . '/install.sql')
        );

        ModuleManager::registerModule($this->MODULE_ID);

        // Регистрация обработчиков событий (хранится в БД)
        $em = EventManager::getInstance();
        $em->registerEventHandler('main', 'OnBeforeUserAdd', $this->MODULE_ID,
            \Vendor\Mymodule\EventHandler::class, 'onBeforeUserAdd'
        );

        return true;
    }

    public function UnInstallDB(array $params = []): bool
    {
        $em = EventManager::getInstance();
        $em->unRegisterEventHandler('main', 'OnBeforeUserAdd', $this->MODULE_ID,
            \Vendor\Mymodule\EventHandler::class, 'onBeforeUserAdd'
        );

        ModuleManager::unRegisterModule($this->MODULE_ID);
        return true;
    }

    public function InstallFiles(): bool { return true; }
    public function UnInstallFiles(): bool { return true; }

    public function DoInstall(): void
    {
        $this->InstallDB();
        $this->InstallFiles();
    }

    public function DoUninstall(): void
    {
        $this->UnInstallDB();
        $this->UnInstallFiles();
    }
}
```

### .settings.php — конфигурация модуля

```php
<?php
// .settings.php читается ServiceLocator при загрузке модуля
return [
    // Конфигурация Engine\Controller (D7 MVC)
    'controllers' => [
        'value' => [
            'defaultNamespace' => '\Vendor\Mymodule\Controller',
            'namespaces' => [
                '\Vendor\Mymodule\Controller' => 'api',  // /vendor.mymodule/api/...
            ],
            'restIntegration' => [
                'enabled' => true,  // методы контроллеров доступны через REST
            ],
        ],
        'readonly' => true,
    ],
];
```

### Repository паттерн

> **Bitrix-way:** Service вызывает DataManager напрямую — это стандарт. Repository-паттерн — дополнительный слой абстракции, оправдан только для сложных модулей с несколькими хранилищами (DB + Redis + Cookie). В типовом модуле — избыточен и выглядит «не по-битриксовому».

Repository изолирует работу с хранилищем (DB, Cookie, Cache) от бизнес-логики. Архитектурная цепочка: **Controller → Service → Repository → DataManager/Cookie**.

Это позволяет:
- менять хранилище (DB → Redis) без изменения сервиса
- тестировать сервис с mock-репозиторием
- не дублировать ORM-запросы по всему коду

```php
namespace Vendor\Favorites\Repository;

use Vendor\Favorites\Model\FavoriteTable;

final class FavoriteRepository
{
    public function findByUserId(int $userId): array
    {
        return FavoriteTable::getList([
            'select' => ['ID', 'PRODUCT_ID', 'CREATED_AT'],
            'filter' => ['=USER_ID' => $userId],
            'order'  => ['ID' => 'DESC'],
        ])->fetchAll();
    }

    public function exists(int $userId, int $productId): bool
    {
        return FavoriteTable::getCount([
            '=USER_ID'    => $userId,
            '=PRODUCT_ID' => $productId,
        ]) > 0;
    }

    public function add(int $userId, int $productId): \Bitrix\Main\ORM\Data\AddResult
    {
        return FavoriteTable::add([
            'USER_ID'    => $userId,
            'PRODUCT_ID' => $productId,
            'CREATED_AT' => new \Bitrix\Main\Type\DateTime(),
        ]);
    }

    public function deleteByUserAndProduct(int $userId, int $productId): \Bitrix\Main\ORM\Data\DeleteResult
    {
        $row = FavoriteTable::getList([
            'select' => ['ID'],
            'filter' => ['=USER_ID' => $userId, '=PRODUCT_ID' => $productId],
            'limit'  => 1,
        ])->fetch();

        if (!$row) {
            return new \Bitrix\Main\ORM\Data\DeleteResult();
        }

        return FavoriteTable::delete($row['ID']);
    }
}
```

Регистрация в `.settings.php` модуля для DI через ServiceLocator:

```php
'services' => [
    'value' => [
        'Vendor.Favorites.FavoriteRepository' => [
            'className' => \Vendor\Favorites\Repository\FavoriteRepository::class,
        ],
        'Vendor.Favorites.FavoriteService' => [
            'className' => \Vendor\Favorites\Service\FavoriteService::class,
            'constructorParams' => function() {
                return [
                    \Bitrix\Main\DI\ServiceLocator::getInstance()
                        ->get('Vendor.Favorites.FavoriteRepository'),
                ];
            },
        ],
    ],
],
```

Использование в сервисе:

```php
namespace Vendor\Favorites\Service;

use Vendor\Favorites\Repository\FavoriteRepository;
use Bitrix\Main\DI\ServiceLocator;

final class FavoriteService
{
    public function __construct(
        private readonly FavoriteRepository $repository
    ) {}

    public static function getInstance(): self
    {
        return ServiceLocator::getInstance()->get('Vendor.Favorites.FavoriteService');
    }

    public function toggle(int $userId, int $productId): bool
    {
        if ($this->repository->exists($userId, $productId)) {
            $this->repository->deleteByUserAndProduct($userId, $productId);
            return false; // удалено
        }
        $this->repository->add($userId, $productId);
        return true; // добавлено
    }
}
```

---

### Loader — тонкости

```php
use Bitrix\Main\Loader;

// Возвращает bool, кешируется — второй вызов бесплатный
if (!Loader::includeModule('vendor.mymodule')) {
    // модуль не установлен или не найден
    return;
}

// requireModule() — то же самое, но бросает LoaderException при неудаче
Loader::requireModule('vendor.mymodule');

// Ручная регистрация namespace (редко нужно, обычно автоматически)
Loader::registerNamespace('Vendor\\Extra', '/absolute/path/to/lib');

// Регистрация классов вручную (legacy-классы без PSR-4)
Loader::registerAutoLoadClasses('vendor.mymodule', [
    '\COldClass' => 'classes/oldclass.php',
]);
```

**Gotcha:** `local/modules/` имеет приоритет над `bitrix/modules/`. Если в `local/` есть модуль с тем же ID, он загрузится вместо стандартного — это механизм кастомизации.

---

## Мультисайтовость

### Константы SITE_ID, LANGUAGE_ID, SERVER_NAME

```php
// SITE_ID — строковый идентификатор текущего сайта (например 's1', 'ru', 'en')
// Доступна только после подключения ядра Bitrix (после require 'bitrix/modules/main/include.php')
// Никогда не хардкодь 's1' — используй константу SITE_ID

echo SITE_ID;      // 's1' / 'ru' / 'en' — зависит от настроек
echo LANGUAGE_ID;  // 'ru' / 'en' — язык текущего сайта
echo SERVER_NAME;  // 'example.com' — домен текущего сайта

// Использование в запросах и фильтрах:
$filter = ['SITE_ID' => SITE_ID, 'ACTIVE' => 'Y'];
```

### SiteTable D7 — список сайтов, поиск по домену

```php
use Bitrix\Main\SiteTable;

// Получить все активные сайты
$sites = SiteTable::getList([
    'filter' => ['=ACTIVE' => 'Y'],
    'select' => ['LID', 'NAME', 'SERVER_NAME', 'LANGUAGE_ID', 'DIR', 'SORT'],
    'order'  => ['SORT' => 'ASC'],
])->fetchAll();

foreach ($sites as $site) {
    // LID — строковый ID сайта ('s1', 'ru', ...)
    // SERVER_NAME — домен ('example.com')
    // LANGUAGE_ID — 'ru', 'en', ...
    // DIR — корневая директория ('/')
}

// Найти сайт по домену
$site = SiteTable::getList([
    'filter' => ['=SERVER_NAME' => 'example.com'],
    'select' => ['LID', 'NAME', 'LANGUAGE_ID'],
    'limit'  => 1,
])->fetch();

if ($site) {
    $siteId = $site['LID'];
}
```

### CSite::GetByID — legacy

```php
// Legacy-способ получить данные сайта
$siteRes = CSite::GetByID(SITE_ID);
$siteData = $siteRes->Fetch();
// Поля: LID, ACTIVE, NAME, SERVER_NAME, DIR, LANGUAGE_ID, DOC_ROOT, ...

// Получить список сайтов (legacy)
$allSites = CSite::GetList('SORT', 'ASC', ['ACTIVE' => 'Y']);
while ($s = $allSites->Fetch()) { /* ... */ }
```

### Loc::getMessage() с явным языком

```php
use Bitrix\Main\Localization\Loc;

// Стандартный способ — язык определяется из LANGUAGE_ID автоматически
Loc::loadMessages(__FILE__);
echo Loc::getMessage('MY_KEY');

// Получить сообщение для явно заданного языка
// (полезно когда нужно отправить уведомление на языке пользователя, не текущего сайта)
$messageInEnglish = Loc::getMessageByLang('MY_KEY', 'en');
$messageInRussian = Loc::getMessageByLang('MY_KEY', 'ru');

// Загрузить lang-файл для конкретного языка явно
Loc::loadLanguageFile(__FILE__, 'en');
```

### Переключение контекста сайта

```php
use Bitrix\Main\Application;
use Bitrix\Main\Context;

$app = Application::getInstance();
$context = $app->getContext();

// Получить текущий SITE_ID из контекста
$currentSiteId = $context->getSite();    // string, например 's1'
$currentLangId = $context->getLanguage(); // string, например 'ru'

// Переключить контекст на другой сайт (например в агентах, консольных скриптах)
// Используй с осторожностью — меняет глобальный контекст запроса
$context->setSite('en');
$context->setLanguage('en');

// После выполнения логики — восстанови исходный контекст
$context->setSite(SITE_ID);
$context->setLanguage(LANGUAGE_ID);
```

### Настройки модуля per-site (COption)

```php
use Bitrix\Main\Config\Option;

// Получить настройку для конкретного сайта
// четвёртый параметр — SITE_ID (без него вернётся общая настройка)
$value = Option::get('my.module', 'api_key', '', SITE_ID);

// D7-обёртка COption::GetOptionString (legacy-стиль, но с siteId)
$value = COption::GetOptionString('my.module', 'api_key', 'default', SITE_ID);

// Сохранить настройку для конкретного сайта
Option::set('my.module', 'api_key', 'NEW_KEY', SITE_ID);
COption::SetOptionString('my.module', 'api_key', 'NEW_KEY', '', SITE_ID);

// Получить общую настройку (не привязанную к сайту) — не передавай siteId
$globalValue = Option::get('my.module', 'global_setting', 'default');

// Удалить настройку сайта
Option::delete('my.module', ['name' => 'api_key', 'site_id' => SITE_ID]);
```

### Языковые файлы per-site (BCC)

```
Структура lang-файлов для мультиязычного модуля:
local/modules/my.module/lang/
├── ru/
│   └── lib/
│       └── myclass.php    ← $MESS['MY_CLASS_TITLE'] = 'Заголовок';
└── en/
    └── lib/
        └── myclass.php    ← $MESS['MY_CLASS_TITLE'] = 'Title';
```

```php
// В lib/myclass.php
use Bitrix\Main\Localization\Loc;

Loc::loadMessages(__FILE__);
// Bitrix автоматически ищет lang/LANGUAGE_ID/lib/myclass.php
// относительно расположения текущего PHP-файла

class MyClass
{
    public function getTitle(): string
    {
        return Loc::getMessage('MY_CLASS_TITLE');
        // вернёт 'Заголовок' на ru, 'Title' на en
    }
}
```

### Gotchas мультисайтовости

- **`SITE_ID` доступна только после подключения ядра**: после `require $_SERVER['DOCUMENT_ROOT'] . '/bitrix/modules/main/include.php'`. В CLI-скриптах без пролога константа не определена — определяй вручную `define('SITE_ID', 's1')`.
- **Не хардкоди `'s1'`** — это ID сайта по умолчанию только в демо-установках. В реальных проектах сайты часто имеют ID `'ru'`, `'en'`, `'by'` и т.д. Всегда используй константу `SITE_ID`.
- **`SiteTable::getList()`** не возвращает DIR с trailing slash — сравнивай осторожно.
- **`COption`/`Option`** без явного `SITE_ID` сохраняет в общие настройки (поле `SITE_ID = ''` в `b_option`). При чтении: если нет per-site значения, Bitrix fallback'ается на общее. Это поведение можно сломать если записать пустую строку как per-site значение.
- **`Loc::getMessageByLang()`** требует чтобы lang-файл был загружен для указанного языка. Если не загружен — вернёт пустую строку. Предварительно вызови `Loc::loadLanguageFile(__FILE__, $lang)`.
- **`$context->setSite()`** меняет контекст только внутри текущего запроса/процесса. Не влияет на другие запросы или агенты.

---

---

## Source: `orm.md`

# Bitrix D7 ORM — полный справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с ORM, DataManager, CRUD, фильтрами, агрегацией, событиями сущностей, Result/Error паттерном или исключениями ядра.
>
> Audit note (core-verified, current project): справочник сверялся по `www/bitrix/modules/main/lib/orm/data/datamanager.php`, `orm/query/{query,result}.php`, `orm/objectify/entityobject.php` и `orm/entity.php`.

## Содержание
- DataManager: схема, CRUD, Relations, ExpressionField, транзакции
- ORM: Операторы фильтра (полная таблица)
- ORM: Агрегация (COUNT, SUM, GROUP BY)
- ORM: Runtime-поля в запросе
- ORM: События сущностей (OnBefore*/OnAfter*)
- Result / Error паттерн для сервисов
- Иерархия исключений ядра
- Что никогда не делать (ORM/SQL)

---

## D7 ORM

### Архитектурный смысл

ORM в Bitrix — это **DataManager/DataMapper-центричный** слой поверх таблицы. `DataManager` — базовый класс, от которого наследуется каждая таблица. Он даёт: CRUD, события, типизированные поля, JOIN-ы и объектный API.

Важно не описывать текущий D7 ORM как “только массивы”: в этом core реально есть `fetchObject()`, `fetchCollection()`, `EntityObject::save()` и `DataManager::createObject()`. То есть базовая точка входа всё ещё `DataManager`, но объектный слой в ядре присутствует.

Когда создаёшь `OrderTable extends DataManager`, ты описываешь **схему** в `getMap()` и получаешь всё остальное бесплатно.

### Определение таблицы

```php
namespace MyVendor\MyModule;

use Bitrix\Main\ORM\Data\DataManager;
use Bitrix\Main\ORM\Fields\IntegerField;
use Bitrix\Main\ORM\Fields\StringField;
use Bitrix\Main\ORM\Fields\DatetimeField;
use Bitrix\Main\ORM\Fields\BooleanField;
use Bitrix\Main\ORM\Fields\Validators\LengthValidator;
use Bitrix\Main\Type\DateTime;

class OrderTable extends DataManager
{
    public static function getTableName(): string
    {
        return 'my_order'; // имя таблицы в БД
    }

    public static function getMap(): array
    {
        return [
            new IntegerField('ID', [
                'primary'      => true,
                'autocomplete' => true, // AUTO_INCREMENT
            ]),
            new StringField('TITLE', [
                'required'   => true,
                'validation' => fn() => [new LengthValidator(1, 255)],
            ]),
            new IntegerField('USER_ID'),
            new BooleanField('ACTIVE', [
                'values'  => ['N', 'Y'], // хранит 'N' или 'Y', не bool
                'default' => 'Y',
            ]),
            new DatetimeField('CREATED_AT', [
                'default' => fn() => new DateTime(), // текущее время при создании
            ]),
        ];
    }
}
```

### Типы полей ORM

| Класс | SQL-тип | Примечание |
|-------|---------|------------|
| `IntegerField` | INT | `primary + autocomplete` = AUTO_INCREMENT |
| `StringField` | VARCHAR(255) | длину можно изменить через `'size'` |
| `TextField` | TEXT | для длинных строк, нельзя в ORDER/GROUP |
| `FloatField` | FLOAT | |
| `BooleanField` | CHAR(1) | `values: ['N','Y']` или `[false,true]` |
| `DateField` | DATE | работает с `Bitrix\Main\Type\Date` |
| `DatetimeField` | DATETIME | работает с `Bitrix\Main\Type\DateTime` |
| `EnumField` | CHAR | фиксированный список строк |
| `ExpressionField` | — | вычисляемое выражение, не хранится |

### CRUD операции

`add/update/delete` возвращают `Result` — всегда проверяй `isSuccess()`. Метод `getList` возвращает не массив, а объект результата — данные получаешь через `fetch()` или `fetchAll()`.

```php
use MyVendor\MyModule\OrderTable;

// CREATE — возвращает AddResult с методом getId()
$result = OrderTable::add([
    'TITLE'   => 'Новый заказ',
    'USER_ID' => 42,
    'ACTIVE'  => 'Y',
]);
if (!$result->isSuccess()) {
    throw new \RuntimeException(implode(', ', $result->getErrorMessages()));
}
$newId = $result->getId();

// READ одного — fetch() вернёт массив или false
$row = OrderTable::getById(5)->fetch();

// READ списка — итерируем через while + fetch (экономия памяти)
$dbResult = OrderTable::getList([
    'select'  => ['ID', 'TITLE', 'USER_ID'],
    'filter'  => ['=ACTIVE' => 'Y', '>USER_ID' => 0],
    'order'   => ['ID' => 'DESC'],
    'limit'   => 20,
    'offset'  => 0,
]);
while ($row = $dbResult->fetch()) {
    // работаем с $row
}
// Или сразу все записи в массив (осторожно с большими выборками)
$rows = OrderTable::getList([...])->fetchAll();

// UPDATE — обновляет только переданные поля
$result = OrderTable::update(5, ['TITLE' => 'Обновлённый заказ']);

// DELETE
$result = OrderTable::delete(5);
```

### Query Builder vs getList — когда что использовать

`getList()` — статический метод с массивом параметров, удобен для простых запросов. `query()` — объектный построитель запросов, удобен когда условия формируются динамически или нужен объектный результат.

```php
// getList — просто и читаемо для фиксированных запросов
$result = OrderTable::getList([
    'select' => ['ID', 'TITLE'],
    'filter' => ['=ACTIVE' => 'Y'],
    'limit'  => 10,
]);

// query() — удобен для динамической сборки и объектного API
$query = OrderTable::query()
    ->setSelect(['ID', 'TITLE', 'USER_ID'])
    ->setFilter(['=ACTIVE' => 'Y'])
    ->setOrder(['CREATED_AT' => 'DESC'])
    ->setLimit(10);

if ($onlyRecent) {
    $query->addFilter('>=CREATED_AT', new \Bitrix\Main\Type\DateTime('2024-01-01'));
}

// fetchObject() — возвращает EntityObject с геттерами/сеттерами
// Используй когда нужно изменить и сохранить запись
$order = OrderTable::query()
    ->setSelect(['*'])
    ->setFilter(['=ID' => 5])
    ->fetchObject();

if ($order) {
    echo $order->getTitle();        // getter по имени поля
    echo $order->getId();
    $order->setTitle('Новое имя');
    $order->save();                 // UPDATE под капотом
}

// fetchCollection() — коллекция объектов, удобна для итерации
$collection = OrderTable::query()
    ->setSelect(['*'])
    ->setFilter(['=ACTIVE' => 'Y'])
    ->fetchCollection();

foreach ($collection as $item) {
    echo $item->getId();
}

// COUNT — самый лёгкий способ посчитать записи
$count = OrderTable::getCount(['=ACTIVE' => 'Y']);
```

### Отношения (Relations)

`Reference` — это объявление JOIN в схеме. Когда ты добавляешь `Reference` в `getMap()`, ORM знает как связать таблицы, и ты можешь обращаться к полям связанной таблицы через точку в `select` и `filter`.

```php
use Bitrix\Main\ORM\Fields\Relations\Reference;
use Bitrix\Main\ORM\Query\Join;
use Bitrix\Main\UserTable;

// В getMap() таблицы OrderTable:
new Reference(
    'USER',                               // имя связи — используется как префикс: USER.LOGIN
    UserTable::class,                     // к какой таблице джойним
    Join::on('this.USER_ID', 'ref.ID'),  // условие: this = текущая таблица, ref = целевая
    ['join_type' => 'LEFT']              // LEFT JOIN (по умолчанию LEFT)
),

// Теперь в запросах можно использовать поля связанной таблицы:
$result = OrderTable::getList([
    'select' => [
        'ID',
        'TITLE',
        'USER_LOGIN' => 'USER.LOGIN',  // алиас => путь через связь
        'USER_NAME'  => 'USER.NAME',
    ],
    'filter' => ['=USER.ACTIVE' => 'Y'], // фильтр по полю связанной таблицы
]);
```

### ExpressionField — вычисляемые поля в схеме

`ExpressionField` позволяет добавить SQL-выражение как виртуальное поле. `%s` — плейсхолдер для подстановки имён колонок через ORM (безопасно, экранируется).

```php
use Bitrix\Main\ORM\Fields\ExpressionField;

// В getMap() — постоянное вычисляемое поле
new ExpressionField(
    'FULL_NAME',
    'CONCAT(%s, " ", %s)',
    ['FIRST_NAME', 'LAST_NAME']
),
```

### Транзакции

Используй транзакции когда несколько операций должны быть атомарными — либо все успешно, либо ничего. В текущем `DataManager` явные `startTransaction()/commitTransaction()` внутри `add/update/delete` не видны, поэтому не обещай “автоматическую транзакцию ORM” без отдельной проверки конкретного сценария.

```php
$connection = \Bitrix\Main\Application::getConnection();
$connection->startTransaction();

try {
    $orderResult = OrderTable::add([...]);
    if (!$orderResult->isSuccess()) {
        throw new \RuntimeException('Ошибка создания заказа');
    }

    OrderItemTable::add(['ORDER_ID' => $orderResult->getId(), ...]);
    $connection->commitTransaction();
} catch (\Exception $e) {
    $connection->rollbackTransaction();
    throw $e; // пробрасываем дальше
}
```

### Сырой SQL — только в крайнем случае

Используй только когда ORM не позволяет выразить запрос (например, сложные подзапросы, специфичные SQL-функции). **Всегда** экранируй входные данные через `forSql()`.

```php
$connection = \Bitrix\Main\Application::getConnection();
$helper     = $connection->getSqlHelper();

$safeValue = $helper->forSql($userInput); // экранирование — обязательно
$result    = $connection->query(
    "SELECT * FROM my_table WHERE TITLE = '{$safeValue}'"
);

while ($row = $result->fetch()) { ... }
```

---

## ORM: Операторы фильтра

Самая частая точка ошибок. Оператор — это **префикс перед именем поля** в ключе массива фильтра.

| Оператор | SQL | Пример |
|----------|-----|--------|
| `=` | `= value` или `IN (...)` если массив | `['=ACTIVE' => 'Y']` |
| `!=` | `!= value` или `NOT IN` если массив | `['!=STATUS' => 'D']` |
| `>` | `> value` | `['>SORT' => 100]` |
| `>=` | `>= value` | `['>=PRICE' => 500]` |
| `<` | `< value` | `['<DATE_CREATE' => $dt]` |
| `<=` | `<= value` | `['<=SORT' => 500]` |
| `%` | `LIKE '%value%'` | `['%TITLE' => 'заказ']` |
| `=%` | `LIKE 'value%'` | `['=%CODE' => 'order_']` |
| `%=` | `LIKE '%value'` | `['%=CODE' => '_ru']` |
| `!%` | `NOT LIKE '%value%'` | `['!%TITLE' => 'удалён']` |
| `=` + `null` | `IS NULL` | `['=DELETED_AT' => null]` |
| `!=` + `null` | `IS NOT NULL` | `['!=DELETED_AT' => null]` |
| `=` + массив | `IN (1,2,3)` | `['=ID' => [1, 2, 3]]` |
| `!=` + массив | `NOT IN (1,2,3)` | `['!=ID' => [5, 6]]` |
| `><` | `BETWEEN a AND b` | `['><PRICE' => [100, 500]]` |
| `!><` | `NOT BETWEEN a AND b` | `['!><SORT' => [200, 300]]` |

По умолчанию все условия объединяются через `AND`. Для `OR` нужен вложенный массив с ключом `'LOGIC'`.

```php
// OR между условиями
$result = OrderTable::getList([
    'filter' => [
        'LOGIC' => 'OR',
        ['=STATUS' => 'new'],
        ['=STATUS' => 'pending'],
    ],
]);

// Смешанная логика: AND на верхнем уровне, OR внутри
$result = OrderTable::getList([
    'filter' => [
        '=ACTIVE' => 'Y',           // AND
        [
            'LOGIC' => 'OR',
            ['=TYPE' => 'express'],
            ['>PRICE' => 10000],
        ],
    ],
]);
```

---

## ORM: Агрегация (GROUP BY, COUNT, SUM)

Агрегатные функции добавляются через `runtime` — поля, которые существуют только в контексте этого запроса. Поле `ExpressionField` со SQL-функцией + ключ `group` дают GROUP BY.

```php
use Bitrix\Main\ORM\Fields\ExpressionField;

// Количество заказов по каждому пользователю
$result = OrderTable::getList([
    'select'  => ['USER_ID', 'CNT'],
    'runtime' => [
        new ExpressionField('CNT', 'COUNT(*)'),
    ],
    'filter' => ['=ACTIVE' => 'Y'],
    'group'  => ['USER_ID'],
    'order'  => ['CNT' => 'DESC'],
]);

// Несколько агрегатов сразу
$result = OrderItemTable::getList([
    'select'  => ['ORDER_ID', 'TOTAL', 'AVG_PRICE', 'MAX_PRICE'],
    'runtime' => [
        new ExpressionField('TOTAL',     'SUM(%s)',  ['PRICE']),
        new ExpressionField('AVG_PRICE', 'AVG(%s)',  ['PRICE']),
        new ExpressionField('MAX_PRICE', 'MAX(%s)',  ['PRICE']),
    ],
    'group' => ['ORDER_ID'],
]);

// Одно значение — просто fetch()
$row     = OrderTable::getList([
    'select'  => ['TOTAL'],
    'runtime' => [new ExpressionField('TOTAL', 'SUM(%s)', ['PRICE'])],
    'filter'  => ['=ACTIVE' => 'Y'],
])->fetch();
$revenue = $row['TOTAL'];

// Просто посчитать строки — getCount() проще
$count = OrderTable::getCount(['=ACTIVE' => 'Y', '=USER_ID' => 42]);
```

---

## ORM: Runtime-поля в запросе

Runtime-поля — это временные поля, которые существуют только в конкретном запросе и не меняют схему таблицы. Удобны для: JOIN-ов которые нужны редко, вычислений на лету, условных выражений.

```php
use Bitrix\Main\ORM\Fields\ExpressionField;
use Bitrix\Main\ORM\Fields\Relations\Reference;
use Bitrix\Main\ORM\Query\Join;

$result = OrderTable::getList([
    'select'  => ['ID', 'TITLE', 'USER_EMAIL', 'IS_EXPENSIVE'],
    'runtime' => [
        // Временный JOIN — не нужен в каждом запросе, только здесь
        new Reference(
            'PROFILE',
            \MyVendor\MyModule\ProfileTable::class,
            Join::on('this.USER_ID', 'ref.USER_ID'),
            ['join_type' => 'LEFT']
        ),
        // Поле из JOIN-а
        new ExpressionField('USER_EMAIL', '%s', ['PROFILE.EMAIL']),
        // Условное вычисление
        new ExpressionField(
            'IS_EXPENSIVE',
            'CASE WHEN %s > 10000 THEN 1 ELSE 0 END',
            ['PRICE']
        ),
    ],
    'filter' => ['=ACTIVE' => 'Y'],
]);
```

---

## ORM: События сущностей (Entity Events)

Это **хуки жизненного цикла** записи. На каждую операцию (`add`, `update`, `delete`) ядро последовательно вызывает три события. В текущем core важно не путать их с транзакционными хуками: `OnAdd`/`OnUpdate`/`OnDelete` вызываются в середине pipeline операции, но не “после SQL внутри транзакции”.

На каждую операцию — 9 событий итого:

| Константа DataManager | Имя | Когда | Можно прервать? |
|---|---|---|---|
| `EVENT_ON_BEFORE_ADD` | `OnBeforeAdd` | до INSERT | **да** — можно изменить поля или отменить |
| `EVENT_ON_ADD` | `OnAdd` | после валидации и перед INSERT | нет |
| `EVENT_ON_AFTER_ADD` | `OnAfterAdd` | после INSERT, UF update и cleanCache | нет |
| `EVENT_ON_BEFORE_UPDATE` | `OnBeforeUpdate` | до UPDATE | **да** |
| `EVENT_ON_UPDATE` | `OnUpdate` | после валидации и перед UPDATE | нет |
| `EVENT_ON_AFTER_UPDATE` | `OnAfterUpdate` | после UPDATE, UF update и cleanCache | нет |
| `EVENT_ON_BEFORE_DELETE` | `OnBeforeDelete` | до DELETE | **да** |
| `EVENT_ON_DELETE` | `OnDelete` | перед DELETE | нет |
| `EVENT_ON_AFTER_DELETE` | `OnAfterDelete` | после DELETE, UF delete и cleanCache | нет |

Дополнительно: `DataManager` отправляет и legacy-, и modern namespaced вариант ORM-события, поэтому обработчики в старом и новом стиле могут сосуществовать.

**Когда что использовать:**
- `OnBefore*` — валидация, автозаполнение полей, проверка бизнес-правил
- `OnAfter*` — очистка кеша, отправка уведомлений, каскадные операции в других таблицах
- `On*` (средние) — когда нужно вклиниться в pipeline после валидации, но до фактического сохранения/удаления

### ORM\EventResult — управление событием

`ORM\EventResult` — специальный класс, не путать с `\Bitrix\Main\EventResult`. Только он умеет изменять поля и отменять операцию.

```php
use Bitrix\Main\ORM\EventResult;
use Bitrix\Main\ORM\EntityError;

$result = new EventResult(); // по умолчанию SUCCESS

// Изменить поля перед сохранением — только в OnBefore*
$result->modifyFields(['UPDATED_AT' => new \Bitrix\Main\Type\DateTime()]);

// Убрать поле из сохранения
$result->unsetField('TEMP_FIELD');
$result->unsetFields(['FIELD_A', 'FIELD_B']);

// Прервать операцию — вызов addError меняет тип на ERROR, операция не выполнится
$result->addError(new EntityError('Сообщение', 'MY_CODE'));
$result->setErrors([new EntityError('Ошибка 1'), new EntityError('Ошибка 2')]);

// EntityError: код по умолчанию — 'BX_ERROR' (не 0!)
new EntityError('Сообщение');            // код = 'BX_ERROR'
new EntityError('Сообщение', 'MY_CODE'); // код = 'MY_CODE'
```

### Способ 1 — переопределение метода в DataManager (рекомендуется для собственной логики)

Используй когда логика принадлежит самой таблице — это часть бизнес-правил сущности. Ядро вызывает метод как часть **modern-события** (с namespace): после того как отработают legacy-обработчики из EventManager, стреляет modern-событие, и внутри него через `call_user_func_array` вызывается метод класса. Именно поэтому методы получают modern-параметры (включают `primary` и `object`).

```php
use Bitrix\Main\ORM\Data\DataManager;
use Bitrix\Main\ORM\Event;
use Bitrix\Main\ORM\EventResult;
use Bitrix\Main\ORM\EntityError;

class OrderTable extends DataManager
{
    // Параметры: 'fields' (массив значений) + 'object' (EntityObject до сохранения)
    public static function OnBeforeAdd(Event $event): EventResult
    {
        $result = new EventResult();
        $fields = $event->getParameter('fields');

        if (empty($fields['TITLE'])) {
            $result->addError(new EntityError('Заголовок обязателен', 'EMPTY_TITLE'));
            return $result; // операция прервётся, INSERT не выполнится
        }

        // Автозаполнение — добавляем поле которого не было в исходных данных
        $result->modifyFields([
            'CREATED_BY' => \Bitrix\Main\Engine\CurrentUser::get()->getId(),
        ]);

        return $result;
    }

    // Параметры: 'id' (int), 'primary' (['ID'=>5]), 'fields', 'object' (clone после INSERT)
    public static function OnAfterAdd(Event $event): EventResult
    {
        $id = $event->getParameter('id');

        // Здесь запись уже в БД — можно чистить кеш, слать уведомления
        \Bitrix\Main\Application::getInstance()
            ->getTaggedCache()
            ->clearByTag('my_order_list');

        return new EventResult();
    }

    // Параметры: 'id', 'primary' (['ID'=>5]), 'fields' (только изменяемые!), 'object'
    public static function OnBeforeUpdate(Event $event): EventResult
    {
        $result = new EventResult();
        // ВАЖНО: $fields содержит только те поля, которые переданы в update()
        // Не все поля записи, только изменяемые
        $result->modifyFields(['UPDATED_AT' => new \Bitrix\Main\Type\DateTime()]);
        return $result;
    }

    public static function OnAfterUpdate(Event $event): EventResult
    {
        return new EventResult();
    }

    // Параметры: 'id', 'primary' (['ID'=>5]), 'object' (clone перед удалением)
    public static function OnBeforeDelete(Event $event): EventResult
    {
        $result  = new EventResult();
        $primary = $event->getParameter('primary');

        // Проверка целостности — нельзя удалить если есть связанные записи
        if (OrderItemTable::getCount(['=ORDER_ID' => $primary['ID']]) > 0) {
            $result->addError(new EntityError('Нельзя удалить заказ с позициями', 'HAS_ITEMS'));
        }
        return $result;
    }

    public static function OnAfterDelete(Event $event): EventResult
    {
        $primary = $event->getParameter('primary');
        // Каскадное удаление связанных данных, очистка кеша
        return new EventResult();
    }
}
```

**Важно: регистр имён методов** — ядро вызывает `call_user_func_array([$class, 'OnBeforeAdd'], [$event])`. Методы должны называться `OnBeforeAdd`, `OnAfterAdd` и т.д. — с заглавной `O`.

### Способ 2 — подписка через EventManager (для межмодульной интеграции)

Используй когда **другой модуль** должен реагировать на изменения в чужой таблице. Ядро стреляет двумя вариантами события одновременно: legacy (без namespace) и modern (с namespace). Подписывайся на modern.

```php
// Modern-формат имени события: '\Namespace\EntityName::EventName'
// EntityName = имя класса DataManager БЕЗ суффикса 'Table'
// OrderTable → 'Order', UserTable → 'User', ElementTable → 'Element'
\Bitrix\Main\EventManager::getInstance()->addEventHandler(
    'my.module',                                   // модуль, которому принадлежит таблица
    '\MyVendor\MyModule\Order::OnBeforeAdd',        // modern-формат: без 'Table'!
    [\AnotherVendor\Integration\Handler::class, 'handle']
);

// Обработчик работает с ORM\Event и возвращает ORM\EventResult
class Handler
{
    public static function handle(\Bitrix\Main\ORM\Event $event): \Bitrix\Main\ORM\EventResult
    {
        $result = new \Bitrix\Main\ORM\EventResult();
        $fields = $event->getParameter('fields');
        // ...
        return $result;
    }
}
```

---

## Result / Error — паттерн для сервисов

`Result` — стандартный D7-способ вернуть успех или ошибку из метода. Не исключения (исключения для неожиданных ситуаций), не `bool`, не `null`. `Result` несёт в себе: статус (isSuccess), список ошибок с кодами, и произвольные данные.

**Почему не исключения?** Потому что ошибка валидации или "запись не найдена" — это ожидаемый бизнес-результат, не исключительная ситуация. `Result` позволяет вернуть несколько ошибок сразу и содержит коды для i18n.

### Error — полный API

```php
use Bitrix\Main\Error;

// new Error($message, $code = 0, $customData = null)
$error = new Error('Заголовок обязателен', 'EMPTY_TITLE');
// $customData — любые данные для фронта (поле, допустимые значения и т.п.)
$error = new Error('Слишком длинный', 'TOO_LONG', ['field' => 'TITLE', 'max' => 255]);

// Создать из исключения
$error = Error::createFromThrowable($exception);

$error->getMessage();    // строка для отображения
$error->getCode();       // строка/int для switch-case и i18n
$error->getCustomData(); // дополнительные данные
(string) $error;         // то же что getMessage()
json_encode($error);     // {'message':..., 'code':..., 'customData':...}
```

### Result — полный API

```php
use Bitrix\Main\Result;
use Bitrix\Main\Error;

$result = new Result();

// Добавление ошибок — сразу переводит isSuccess() в false
$result->addError(new Error('...'));
$result->addErrors([$error1, $error2]);

// addError возвращает $this, поэтому можно сразу return:
return $result->addError(new Error('Ошибка'));

$result->isSuccess();           // bool
$result->getErrors();           // Error[]
$result->getError();            // Error|null — первая ошибка
$result->getErrorMessages();    // string[] — только тексты ошибок
$result->getErrorCollection();  // ErrorCollection (с методом getErrorByCode())
$result->setData(['id' => 5]);  // сохранить данные результата
$result->getData();             // array
```

### Паттерн в сервисе

```php
class OrderService
{
    public function create(array $data): Result
    {
        $result = new Result();

        // Ранний возврат при ошибке валидации
        if (empty($data['TITLE'])) {
            return $result->addError(new Error('Заголовок обязателен', 'EMPTY_TITLE'));
        }

        $addResult = OrderTable::add($data);
        if (!$addResult->isSuccess()) {
            // Проброс ошибок ORM в свой Result — не теряем детали
            return $result->addErrors($addResult->getErrors());
        }

        return $result->setData(['id' => $addResult->getId()]);
    }
}

// Использование
$result = (new OrderService())->create(['TITLE' => 'Тест', 'USER_ID' => 1]);

if ($result->isSuccess()) {
    $id = $result->getData()['id'];
} else {
    foreach ($result->getErrors() as $error) {
        echo $error->getMessage();    // показать пользователю
        echo $error->getCode();       // для switch/i18n
    }
}
```

---


---
## Иерархия исключений ядра

Исключения — для **неожиданных** ситуаций (ошибки программиста, недоступность БД, неверные аргументы). Для ожидаемых бизнес-ошибок используй `Result`.

```php
// Базовые (Bitrix\Main\*)
use Bitrix\Main\SystemException;             // корень иерархии — все остальные наследуют его
use Bitrix\Main\ArgumentException;           // неверный аргумент
use Bitrix\Main\ArgumentNullException;       // аргумент не может быть null
use Bitrix\Main\ArgumentOutOfRangeException; // аргумент вне допустимого диапазона
use Bitrix\Main\ObjectNotFoundException;     // объект не найден (аналог 404)
use Bitrix\Main\ObjectPropertyException;    // обращение к несуществующему свойству объекта
use Bitrix\Main\NotImplementedException;    // метод не реализован
use Bitrix\Main\NotSupportedException;      // операция не поддерживается
use Bitrix\Main\InvalidOperationException;  // недопустимая операция в текущем состоянии

use Bitrix\Main\DB\SqlQueryException;       // ошибка выполнения SQL
use Bitrix\Main\IO\FileNotFoundException;   // файл не найден (IO\IoException → SystemException)
use Bitrix\Main\AccessDeniedException;      // доступ запрещён (Bitrix\Main, не IO\!)
use Bitrix\Main\LoaderException;            // не удалось подключить модуль

// Правило: ловить конкретный тип, не SystemException — иначе поймаешь лишнее
try {
    $order = OrderTable::getById($id)->fetchObject();
    if (!$order) {
        throw new \Bitrix\Main\ObjectNotFoundException("Order #{$id} not found");
    }
} catch (\Bitrix\Main\ObjectNotFoundException $e) {
    // 404-сценарий
} catch (\Bitrix\Main\DB\SqlQueryException $e) {
    // проблема с БД — логировать и 500
} catch (\Bitrix\Main\SystemException $e) {
    // всё остальное неожиданное
}
```

---

## Что никогда не делать

- `mysql_query` / `mysqli_query` напрямую — только ORM или `$connection->query()` с `forSql()`
- Конкатенация пользовательского ввода в SQL — только `$helper->forSql()`
- `echo $_GET['param']` без экранирования — XSS
- Работа с классами модуля без `Loader::includeModule()` — падёт на другом окружении
- `global $DB` в D7-коде — используй `Application::getConnection()`
- Игнорирование `$result->isSuccess()` после `add/update/delete`
- Возврат `bool`/`null` из сервисного метода вместо `Result` — теряется информация об ошибке
- `RegisterModuleDependences` в `init.php` — только в инсталляторе
- `$_GET`, `$_POST`, `$_SERVER` напрямую в D7 — только через `$request->getQuery()` / `getPost()`
- `HttpClient` без проверки `getStatus()` и `getError()`
- `date()` и `strtotime()` при работе с ORM-датами — только `Type\DateTime`
- Сравнивать `DateTime` через `toString()` — только через `getTimestamp()`

---

---

## Source: `database-layer.md`

# Bitrix Database Layer — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с прямой работой с БД: `Bitrix\Main\DB\Connection`, `DB\SqlHelper`, `Application::getConnection()`, различиями в SQL-синтаксисе MySQL/PostgreSQL/Oracle/MSSQL, или тестированием запросов через `disableQueryExecuting`.

## Содержание
- Получение соединения
- Connection: основные методы
- SqlHelper: экранирование и утилиты
- Прямые запросы: query(), queryScalar(), fetch()
- Транзакции
- Различия СУБД: MySQL, PostgreSQL, Oracle, MSSQL
- Тестирование запросов (disableQueryExecuting)
- Gotchas

---

## Получение соединения

```php
use Bitrix\Main\Application;
use Bitrix\Main\DB\Connection;

// Основное соединение (из .settings.php → connections → default)
$connection = Application::getConnection();

// Альтернативное соединение по имени
$slaveConnection = Application::getConnection('slave');

// Получить SqlHelper текущего соединения
$helper = $connection->getSqlHelper();
```

---

## Connection: основные методы

```php
use Bitrix\Main\Application;

$connection = Application::getConnection();

// Выполнить запрос (возвращает Result)
$result = $connection->query("SELECT * FROM b_user WHERE ACTIVE='Y' LIMIT 10");

// Итерация по результату
while ($row = $result->fetch()) {
    echo $row['LOGIN'];
}

// Один скаляр
$count = $connection->queryScalar("SELECT COUNT(*) FROM b_user WHERE ACTIVE='Y'");

// Исполнить произвольный SQL (INSERT/UPDATE/DELETE/DDL — не возвращает данные)
$connection->queryExecute("UPDATE b_user SET LAST_LOGIN = NOW() WHERE ID = 42");

// Кол-во затронутых строк
$connection->getAffectedRowsCount();

// Последний insert id
$connection->getInsertedId();

// Экранирование идентификатора (имени таблицы/колонки)
$quotedTable = $helper->quote('my_table');  // `my_table` для MySQL
```

---

## SqlHelper: экранирование и утилиты

```php
use Bitrix\Main\Application;

$helper = Application::getConnection()->getSqlHelper();

// Экранировать строковое значение для вставки в SQL
$safe = $helper->forSql($userInput);
// НЕ добавляет кавычки — только экранирует внутри строки
// Используй так: "WHERE NAME = '" . $helper->forSql($name) . "'"

// Экранировать идентификатор (имя колонки/таблицы)
$quoted = $helper->quote('my_column'); // `my_column` (MySQL) или "my_column" (PgSQL)

// Текущая дата и время (зависит от СУБД)
$nowExpr = $helper->getCurrentDateTimeFunction(); // NOW() или SYSDATE или GETDATE()

// Текущая дата (без времени)
$dateExpr = $helper->getCurrentDateFunction(); // CURDATE() или TRUNC(SYSDATE) и т.д.

// Добавить дни к дате
$addDays = $helper->addDaysToDateTime('MY_DATE_FIELD', 7);

// Конкатенация строк (зависит от СУБД)
$concat = $helper->getConcatFunction('FIRST_NAME', "' '", 'LAST_NAME');

// Длина строки
$lengthFn = $helper->getLengthFunction('DESCRIPTION');

// Подстрока
$substrFn = $helper->getSubstrFunction('NAME', 1, 10);
```

---

## Безопасные прямые запросы

```php
use Bitrix\Main\Application;

$connection = Application::getConnection();
$helper     = $connection->getSqlHelper();

// ПРАВИЛЬНО: параметры через forSql()
$name   = $helper->forSql($_GET['name'] ?? '');
$status = $helper->forSql($_GET['status'] ?? 'active');

$sql = "
    SELECT ID, LOGIN, NAME
    FROM b_user
    WHERE NAME LIKE '%" . $name . "%'
      AND ACTIVE = '" . $status . "'
    ORDER BY ID DESC
    LIMIT 20
";
$result = $connection->query($sql);

// НЕПРАВИЛЬНО — конкатенация без экранирования:
// $sql = "WHERE NAME = '" . $_GET['name'] . "'"; // SQL-инъекция!
```

---

## Транзакции

```php
use Bitrix\Main\Application;

$connection = Application::getConnection();

$connection->startTransaction();
try {
    $connection->queryExecute("UPDATE my_orders SET STATUS='paid' WHERE ID=42");
    $connection->queryExecute("INSERT INTO my_payments(ORDER_ID, AMOUNT) VALUES(42, 1500)");
    $connection->commitTransaction();
} catch (\Exception $e) {
    $connection->rollbackTransaction();
    throw $e;
}
```

---

## Различия СУБД

Bitrix поддерживает 4 СУБД: MySQL (MySqli), PostgreSQL, Oracle, MSSQL.
У каждой свой `SqlHelper` с перегруженными методами.

| Функция | MySQL | PostgreSQL | Oracle | MSSQL |
|---------|-------|------------|--------|-------|
| Текущее дата+время | `NOW()` | `NOW()` | `SYSDATE` | `GETDATE()` |
| Текущая дата | `CURDATE()` | `CURRENT_DATE` | `TRUNC(SYSDATE)` | `CAST(GETDATE() AS DATE)` |
| Экранирование имени | `` `name` `` | `"name"` | `"name"` | `[name]` |
| LIMIT/OFFSET | `LIMIT N OFFSET M` | `LIMIT N OFFSET M` | `ROWNUM` / `FETCH FIRST` | `TOP N` / `OFFSET FETCH` |
| Автоинкремент | `AUTO_INCREMENT` | `SERIAL` / `GENERATED` | `SEQUENCE` | `IDENTITY` |
| Строковый тип | `VARCHAR(255)` | `VARCHAR(255)` | `VARCHAR2(255)` | `NVARCHAR(255)` |
| Конкатенация | `CONCAT(a,b)` | `a \|\| b` | `a \|\| b` | `a + b` |
| Регистронезависимый поиск | `LIKE` (по умолчанию) | `ILIKE` | `UPPER(col) LIKE UPPER(...)` | `LIKE` (collation) |

**Всегда используй SqlHelper** вместо хардкода функций — он автоматически выдаёт правильный вариант.

---

## Проверка типа соединения

```php
use Bitrix\Main\Application;
use Bitrix\Main\DB\MysqliConnection;
use Bitrix\Main\DB\PgsqlConnection;

$connection = Application::getConnection();

if ($connection instanceof MysqliConnection) {
    // MySQL-специфичный код
} elseif ($connection instanceof PgsqlConnection) {
    // PostgreSQL-специфичный код
}

// Получить версию СУБД
$version = $connection->getVersion();
```

---

## Тестирование запросов (disableQueryExecuting)

Позволяет перехватить SQL без выполнения — удобно для тестов и отладки.

```php
use Bitrix\Main\Application;

$connection = Application::getConnection();

// Отключить выполнение запросов
$connection->disableQueryExecuting();

// Выполняем "запросы" — они не пойдут в БД
$connection->queryExecute("UPDATE b_user SET NAME='Test' WHERE ID=1");
$connection->query("SELECT * FROM b_user");

// Получить накопленные запросы
$dump = $connection->getDisabledQueryExecutingDump();
// Массив строк SQL

var_dump($dump);
// ['UPDATE b_user SET NAME=\'Test\' WHERE ID=1', 'SELECT * FROM b_user']

// Включить обратно
$connection->enableQueryExecuting();
```

---

## SqlTracker: профилирование запросов

```php
use Bitrix\Main\Application;
use Bitrix\Main\Diag\SqlTracker;

$connection = Application::getConnection();

// Включить трекер
$tracker = new SqlTracker();
$connection->startTracker($tracker);

// ... выполни запросы ...

// Получить статистику
$connection->stopTracker();

foreach ($tracker->getQueries() as $query) {
    echo $query->getSql() . ' — ' . $query->getTime() . 'ms' . PHP_EOL;
}

// Итого
echo 'Запросов: ' . $tracker->getCounter() . PHP_EOL;
echo 'Время: ' . $tracker->getTime() . 'ms' . PHP_EOL;
```

---

## Gotchas

- **`forSql()` не добавляет кавычки**: только экранирует символы внутри строки. Оборачивать в одинарные кавычки в SQL нужно самому.
- **`query()` vs `queryExecute()`**: `query()` возвращает `Result` с данными (для SELECT), `queryExecute()` — для INSERT/UPDATE/DELETE/DDL, не возвращает строки.
- **Никогда не конкатенируй `$_GET`/`$_POST` в SQL**: даже через `forSql()` ошибиться легко. Предпочитай ORM.
- **`quote()` для имён таблиц/колонок**: разные СУБД используют разные символы. Всегда используй `$helper->quote()`, не хардкоди.
- **Вложенные транзакции**: в текущем core MySQL использует savepoints. `startTransaction()` на втором уровне создаёт `SAVEPOINT`, `commitTransaction()` коммитит только на уровне `0`, а `rollbackTransaction()` на вложенном уровне делает `ROLLBACK TO SAVEPOINT` и затем бросает `TransactionException`.
- **`disableQueryExecuting()` только для тестов**: не вызывай в production-коде. Не забудь `enableQueryExecuting()` после.
- **`getCurrentDateTimeFunction()`**: возвращает SQL-выражение (строку), не PHP-значение. Используй его в теле SQL-запроса, а не как PHP-переменную.
- **`getDisabledQueryExecutingDump()` очищает dump после чтения**: если считал его один раз, второй вызов вернёт уже очищенное состояние.
- **Соединение живёт в рамках текущего PHP-request**: не рассчитывай на межзапросное состояние, но и не открывай его вручную перед каждым SQL.

---

## Source: `events-routing.md`

# Bitrix EventManager, Controllers, Routing — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с событиями модулей, AJAX-контроллерами, Engine\Controller, маршрутизацией (Routing) или CSRF.
>
> Audit note (core-verified, current project): справочник сверялся по `www/bitrix/modules/main/lib/eventmanager.php`, `engine/{controller,router,resolver}.php`, `routing/*`, `application.php` и `main/classes/general/user.php`.

## Содержание
- EventManager: runtime vs persistent подписка, регистрация в module
- Engine\Controller: Actions, prefilters, CSRF, JSON-ответы, ошибки
- Routing: RoutingConfigurator, группы, параметры, .settings.php

---

## EventManager — события модулей

`EventManager` — шина событий Bitrix. Это механизм loose coupling: модуль А стреляет событие, модуль Б его слушает, они не зависят друг от друга напрямую. Используется для: интеграций между модулями, расширения поведения стандартных операций (iblock, sale, users).

### Runtime vs Persistent подписка

Два принципиально разных способа:

| Метод | Где хранится | Когда использовать |
|-------|-------------|-------------------|
| `addEventHandler()` | в памяти до конца запроса | в `init.php` или `include.php` модуля — работает пока подключён файл |
| `registerEventHandler()` / `registerEventHandlerCompatible()` | в БД `b_module_to_module`, переживает перезапуск | в инсталляторе модуля — постоянная подписка |

### Version 1 vs Version 2 — разные сигнатуры обработчиков

Это ключевое различие:
- `addEventHandler()` — **version=2** → обработчику передаётся объект `Event`
- `addEventHandlerCompatible()` — **version=1** → обработчику передаются параметры по-отдельности (legacy-стиль)

Большинство стандартных событий Bitrix (`OnBeforeIBlockElementAdd` и т.п.) — legacy. Они ожидают version=1. Поэтому для них нужен `addEventHandlerCompatible()` или `registerEventHandlerCompatible()`.

```php
use Bitrix\Main\EventManager;
use Bitrix\Main\Event;
use Bitrix\Main\EventResult;

$em = EventManager::getInstance();

// D7-событие (своё или другого D7-модуля) — version=2, получает объект Event
$em->addEventHandler(
    'my.module',
    'OnOrderStatusChanged',
    [\MyVendor\MyModule\Handler::class, 'onStatusChanged'],
    false,  // $includeFile (путь к файлу, если нужно подключить; false = не нужен)
    100     // $sort — порядок выполнения (меньше = раньше)
);

// Legacy-событие iblock/sale/etc — version=1, параметры передаются напрямую
$em->addEventHandlerCompatible(
    'iblock',
    'OnBeforeIBlockElementAdd',
    [\MyVendor\MyModule\IblockHandler::class, 'onBeforeElementAdd']
);

// Удалить обработчик — $key возвращается addEventHandler
$key = $em->addEventHandler('my.module', 'OnSomething', $callback);
$em->removeEventHandler('my.module', 'OnSomething', $key);
```

### Обработчики: D7 vs legacy

```php
class IblockHandler
{
    // D7-стиль (version=2): получает объект Event, возвращает EventResult или null
    public static function onStatusChanged(Event $event): ?EventResult
    {
        $orderId   = $event->getParameter('id');
        $newStatus = $event->getParameter('newStatus');

        // null = всё нормально, продолжаем
        // EventResult::ERROR = прерываем (если событие это поддерживает)
        return null;
    }

    // Legacy-стиль (version=1): параметры по-отдельности, часто по ссылке
    public static function onBeforeElementAdd(array &$arFields): void
    {
        // Изменяем поля напрямую через ссылку
        $arFields['PREVIEW_TEXT'] = strip_tags($arFields['PREVIEW_TEXT'] ?? '');
    }
}
```

### Создание и отправка своих D7-событий

```php
use Bitrix\Main\Event;
use Bitrix\Main\EventResult;

// Создаём и отправляем событие
$event = new Event('my.module', 'OnOrderStatusChanged', [
    'id'        => $orderId,
    'oldStatus' => $old,
    'newStatus' => $new,
]);
$event->send();

// Анализируем результаты подписчиков
// EventResult::UNDEFINED=0, SUCCESS=1, ERROR=2
foreach ($event->getResults() as $eventResult) {
    if ($eventResult->getType() === EventResult::SUCCESS) {
        $data = $eventResult->getParameters(); // данные от подписчика
    } elseif ($eventResult->getType() === EventResult::ERROR) {
        // подписчик сигнализирует об ошибке
    }
}

// Подписчик на D7-событие возвращает \Bitrix\Main\EventResult (не ORM\EventResult!)
$em->addEventHandler('my.module', 'OnOrderStatusChanged', function(Event $event) {
    return new EventResult(EventResult::SUCCESS, ['notified' => true], 'my.module');
});
```

### Пользовательские события: OnAfterUserAuthorize

`OnAfterUserAuthorize` в текущем core вызывается в `CUser::Authorize()` после успешной авторизации. Это не то же самое, что `OnAfterUserLogin`: `OnAfterUserLogin` вызывается внутри `CUser::Login()`, а `OnAfterUserAuthorize` привязан именно к успешному `Authorize()` и подходит для пост-логин логики.

Типичный use-case: миграция гостевых данных (корзина, избранное) из cookie в БД при логине.

```php
// Структура $params для OnAfterUserAuthorize (legacy version=1) в текущем core:
// [
//   'user_fields'   => array,      // поля пользователя, включая ID / LOGIN / EMAIL / ...
//   'save'          => bool,       // remember me / stored auth
//   'update'        => bool,       // обновлять ли служебные данные авторизации
//   'applicationId' => mixed,      // application password / integration context, если есть
// ]

use Bitrix\Main\Context;
use Bitrix\Main\Web\CryptoCookie;

class EventHandler
{
    public static function onAfterUserAuthorize(array $params): void
    {
        $userId = (int)($params['user_fields']['ID'] ?? 0);
        if ($userId <= 0) {
            return;
        }

        // Читаем гостевые данные из куки
        $raw = Context::getCurrent()->getRequest()->getCookie('FAVORITES');
        if (empty($raw)) {
            return;
        }

        $guestIds = json_decode($raw, true);
        if (!is_array($guestIds) || empty($guestIds)) {
            return;
        }

        // Переносим в БД
        FavoriteService::getInstance()->migrateFromCookie($userId, $guestIds);

        // Удаляем куку (expire в прошлом)
        $cookie = new CryptoCookie('FAVORITES', '', time() - 3600);
        $cookie->setPath('/');
        Context::getCurrent()->getResponse()->addCookie($cookie);
    }
}
```

Регистрация legacy-обработчика:

```php
// В инсталляторе модуля (persistent):
EventManager::getInstance()->registerEventHandlerCompatible(
    'main',
    'OnAfterUserAuthorize',
    'vendor.favorites',
    \Vendor\Favorites\EventHandler::class,
    'onAfterUserAuthorize'
);
```

> **Важно**: `OnAfterUserAuthorize` в текущем core вызывается через legacy-механику `GetModuleEvents(..., true)` / `ExecuteModuleEventEx(...)`. Для runtime-подписки используй `addEventHandlerCompatible()`, для persistent-регистрации в инсталляторе — `registerEventHandlerCompatible()`.

---

### Persistent-регистрация в инсталляторе модуля

```php
// /bitrix/modules/my.module/install/index.php — при установке модуля
\Bitrix\Main\EventManager::getInstance()->registerEventHandlerCompatible(
    'iblock',                                    // чьё событие слушаем
    'OnBeforeIBlockElementAdd',                  // имя события
    'my.module',                                 // наш модуль
    '\MyVendor\MyModule\IblockHandler',          // класс
    'onBeforeElementAdd',                        // метод
    100                                          // sort
);

// При удалении модуля — обязательно убирать
\Bitrix\Main\EventManager::getInstance()->unRegisterEventHandler(
    'iblock', 'OnBeforeIBlockElementAdd',
    'my.module', '\MyVendor\MyModule\IblockHandler', 'onBeforeElementAdd'
);
// Кеш b_module_to_module сбросится автоматически
```

---

## Engine: Controllers и AJAX

`Engine\Controller` — стандартный способ обрабатывать AJAX в D7. Всё идёт через `/bitrix/services/main/ajax.php?action=vendor:module.controller.action`. Контроллер по умолчанию подключает default prefilters, биндит параметры запроса к аргументам метода по типам PHP и упаковывает ответ в JSON.

**Когда использовать Controller вместо отдельного PHP-файла:** всегда в D7-коде. Голые PHP-файлы для AJAX — legacy-подход.

### Жизненный цикл запроса к контроллеру

1. Запрос приходит на `/bitrix/services/main/ajax.php?action=...`
2. Ядро находит контроллер по namespace-регистрации в `.settings.php`
3. Вызываются `prefilters` (Authentication → HttpMethod → Csrf)
4. Если все фильтры прошли — вызывается `{action}Action()` метод
5. Параметры метода автоматически извлекаются из GET/POST и кастуются по типам
6. Результат оборачивается в `AjaxJson`

### Контроллер

```php
namespace MyVendor\MyModule\Controller;

use Bitrix\Main\Engine\Controller;
use Bitrix\Main\Engine\ActionFilter;
use Bitrix\Main\Engine\CurrentUser;
use Bitrix\Main\Error;

class Order extends Controller
{
    // Дефолтные prefilters: Authentication + HttpMethod(GET|POST) + Csrf
    // configureActions позволяет переопределить их для каждого action
    public function configureActions(): array
    {
        return [
            // Полностью заменить prefilters для read-only GET action
            'getList' => [
                'prefilters' => [
                    new ActionFilter\Authentication(),
                    new ActionFilter\HttpMethod([ActionFilter\HttpMethod::METHOD_GET]),
                ],
            ],

            // Добавить фильтр к дефолтным, не заменяя их (+prefilters)
            'export' => [
                '+prefilters' => [new ActionFilter\Scope([Controller::SCOPE_AJAX])],
            ],

            // Убрать конкретный фильтр из дефолтных (-prefilters)
            'publicInfo' => [
                '-prefilters' => [
                    ActionFilter\Authentication::class,
                    ActionFilter\Csrf::class,
                ],
            ],

            // Для POST: Csrf добавляется автоматически если HttpMethod содержит POST и нет явного Csrf-фильтра
            // (ядро: $hasPostMethod && !$hasCsrfCheck && $request->isPost())
            'create' => [
                'prefilters' => [
                    new ActionFilter\Authentication(),
                    new ActionFilter\HttpMethod([ActionFilter\HttpMethod::METHOD_POST]),
                ],
            ],

            // Публичный endpoint без любых фильтров
            'publicStats' => [
                'prefilters' => [], 'postfilters' => [],
            ],
        ];
    }

    // Параметры биндятся автоматически из GET/POST по именам и типам PHP
    // Метод ОБЯЗАН заканчиваться на 'Action' (METHOD_ACTION_SUFFIX = 'Action')
    public function getListAction(int $page = 1, int $limit = 20): array
    {
        $items = \MyVendor\MyModule\OrderTable::getList([
            'select' => ['ID', 'TITLE'],
            'filter' => ['=ACTIVE' => 'Y'],
            'limit'  => $limit,
            'offset' => ($page - 1) * $limit,
        ])->fetchAll();

        return ['items' => $items, 'total' => \MyVendor\MyModule\OrderTable::getCount()];
        // Автоматически: {"status":"success","data":{"items":[...],"total":N}}
    }

    // null + addError → {"status":"error","errors":[...]}
    public function createAction(string $title, ?int $userId = null): ?array
    {
        if (empty($title)) {
            $this->addError(new Error('Заголовок обязателен', 'EMPTY_TITLE'));
            return null;
        }

        $result = \MyVendor\MyModule\OrderTable::add([
            'TITLE'   => $title,
            'USER_ID' => $userId ?? CurrentUser::get()->getId(),
        ]);

        if (!$result->isSuccess()) {
            $this->addErrors($result->getErrors()); // проброс ошибок ORM
            return null;
        }

        return ['id' => $result->getId()];
    }

    // Конвертация UPPER_CASE ключей ORM → camelCase для фронта
    public function getItemAction(int $id): ?array
    {
        $row = \MyVendor\MyModule\OrderTable::getById($id)->fetch();
        if (!$row) {
            $this->addError(new Error('Не найден', 'NOT_FOUND'));
            return null;
        }
        // ['USER_ID' => 1] → ['userId' => 1]
        return $this->convertKeysToCamelCase($row);
    }

    // Форвардинг — передать управление в другой контроллер
    public function complexAction(): mixed
    {
        return $this->forward(AnotherController::class, 'process', ['param' => 'value']);
    }
}
```

### Формат JSON-ответа

```json
{"status": "success", "data": {...},  "errors": []}
{"status": "error",   "data": null,   "errors": [{"message":"...","code":"...","customData":null}]}
{"status": "denied",  "data": null,   "errors": [...]}
```

`denied` — когда `Authentication` filter отклоняет запрос (401). `error` — когда action вернул `addError`.

```php
// Ручное создание AjaxJson (когда нужно вернуть из action напрямую)
use Bitrix\Main\Engine\Response\AjaxJson;
use Bitrix\Main\ErrorCollection;

return AjaxJson::createSuccess(['id' => 5]);
return AjaxJson::createError(new ErrorCollection([$error]));
return AjaxJson::createDenied();
```

### Вызов с фронтенда

Формат action в `/bitrix/services/main/ajax.php` разбирается как `vendor:module.controller.action`. Для партнёрского модуля `vendor.mymodule` это выглядит так:
- через `defaultNamespace`: `vendor:mymodule.order.getList`
- через alias из `controllers.namespaces`: `vendor:mymodule.api.order.getList`

```javascript
BX.ajax.runAction('vendor:mymodule.order.getList', {
    data: { page: 1, limit: 20 },
}).then(response => {
    console.log(response.data); // { items: [...], total: N }
});

// POST с CSRF-токеном
BX.ajax.runAction('vendor:mymodule.order.create', {
    method: 'POST',
    data: { title: 'Новый заказ', sessid: BX.bitrix_sessid() },
});
```

```php
// Регистрация в /bitrix/modules/vendor.mymodule/.settings.php
return [
    'controllers' => [
        'value' => [
            'defaultNamespace' => '\\Vendor\\Mymodule\\Controller',
            'namespaces' => [
                '\\Vendor\\Mymodule\\Controller' => 'api',
            ],
        ],
        'readonly' => true,
    ],
];
```

---

## Routing (Bitrix\Main\Routing)

В текущем core роутер инициализируется в `Bitrix\Main\Application::initializeRouter()`. Подтверждается такой bootstrap:
- читается глобальная конфигурация `routing.config`
- ищутся файлы `/local/routes/<file>` и `/bitrix/routes/<file>`
- дополнительно подключается системный `/bitrix/routes/web_bitrix.php`, если он существует
- route-файл должен вернуть callable вида `function (RoutingConfigurator $routes) { ... }`

Поведение относительно `urlrewrite.php`, компонентов и project bootstrap зависит от конкретной сборки, поэтому не обещай порядок обработки “по памяти” — проверяй текущий проект.

**Настройка**: имя route-файла объявляется в глобальной `.settings.php` проекта:

```php
// Добавить в .settings.php:
'routing' => ['value' => ['config' => ['web.php']], 'readonly' => false],
```

После этого ядро ищет `local/routes/web.php` и `bitrix/routes/web.php`.

```php
// local/routes/web.php
use Bitrix\Main\Routing\RoutingConfigurator;

return function (RoutingConfigurator $routes): void {

    // Простой маршрут с параметром и regexp-ограничением
    $routes->get(
        '/api/orders/{id}/',
        [\MyVendor\MyModule\Controller\Order::class, 'getAction']
    )->where('id', '\d+'); // только числа

    // Группа с префиксом — все методы REST для ресурса
    $routes->prefix('/api/v1')->group(function (RoutingConfigurator $routes): void {
        $routes->get('/orders/',         [\MyVendor\MyModule\Controller\Order::class, 'getListAction']);
        $routes->post('/orders/',        [\MyVendor\MyModule\Controller\Order::class, 'createAction']);
        $routes->put('/orders/{id}/',    [\MyVendor\MyModule\Controller\Order::class, 'updateAction']);
        $routes->delete('/orders/{id}/', [\MyVendor\MyModule\Controller\Order::class, 'deleteAction']);
    });

    // Именованный маршрут + default value
    $routes->get('/api/report/{format}/', [\MyVendor\MyModule\Controller\Report::class, 'getAction'])
        ->name('api.report')
        ->default('format', 'json')
        ->where('format', 'json|csv');
};
```

Что подтверждается по `routing/*` в текущем core:
- `RoutingConfigurator` поддерживает `get/post/put/patch/options/delete/any/group`
- options DSL включает `middleware`, `prefix`, `name`, `domain`, `where`, `default`
- `where()` задаёт regexp для `{param}`
- `default()` делает параметр необязательным и подставляет значение по умолчанию
- `Router::route($name, $parameters)` умеет собирать URL по имени маршрута

Что нужно проверять отдельно в проекте:
- как именно исполняются `middleware` из route options
- где route-controller связывается с HTTP response в вашем приложении

---

---

## Source: `validation.md`

# Bitrix Validation Framework — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с `Bitrix\Main\Validation\ValidationService`, validation attributes из `Bitrix\Main\Validation\Rule\*`, `ValidationResult` и `ValidationError`.

## Audit note

Проверено по текущему core:
- `www/bitrix/modules/main/lib/validation/ValidationService.php`
- `www/bitrix/modules/main/lib/validation/ValidationResult.php`
- `www/bitrix/modules/main/lib/validation/ValidationError.php`
- `www/bitrix/modules/main/lib/validation/Rule/*`
- `www/bitrix/modules/main/lib/validation/Validator/*`

## Что реально есть в текущем core

Точка входа:
- `ValidationService::validate(object $object): ValidationResult`

Результаты:
- `ValidationResult` расширяет `Bitrix\Main\Result`
- `ValidationError` расширяет `Bitrix\Main\Error`

Поддерживаются:
- property-level атрибуты;
- class-level атрибуты;
- рекурсивная валидация вложенных объектов через `Recursive\Validatable`.

## Базовый пример

```php
use Bitrix\Main\Validation\ValidationService;
use Bitrix\Main\Validation\Rule\Email;
use Bitrix\Main\Validation\Rule\Length;
use Bitrix\Main\Validation\Rule\Max;
use Bitrix\Main\Validation\Rule\Min;
use Bitrix\Main\Validation\Rule\NotEmpty;

final class CreateUserRequest
{
    #[NotEmpty]
    public string $name = '';

    #[NotEmpty]
    #[Email]
    public string $email = '';

    #[Length(min: 8, max: 64)]
    public string $password = '';

    #[Min(18)]
    #[Max(150)]
    public int $age = 0;
}

$dto = new CreateUserRequest();
$dto->email = 'not-an-email';
$dto->password = '123';

$result = (new ValidationService())->validate($dto);
```

## Подтверждённые атрибуты

### Property-level

- `#[NotEmpty(allowZero: bool = false, allowSpaces: bool = false)]`
- `#[Email(strict: bool = false, domainCheck: bool = false)]`
- `#[Phone]`
- `#[PhoneOrEmail(strict: bool = false, domainCheck: bool = false)]`
- `#[Url]`
- `#[Length(min: ?int = null, max: ?int = null)]`
- `#[Min(int $min)]`
- `#[Max(int $max)]`
- `#[Range(int $min, int $max)]`
- `#[InArray(array $validValues, bool $strict = false)]`
- `#[RegExp(string $pattern, int $flags = 0, int $offset = 0)]`
- `#[PositiveNumber]`
- `#[ElementsType(?Enum\Type $typeEnum = null, ?string $className = null)]`
- `#[Recursive\Validatable]`

### Class-level

- `#[AtLeastOnePropertyNotEmpty(array $fields, bool $allowZero = false, bool $allowEmptyString = false)]`

## Важные отличия от старых описаний

В текущем core не подтверждены как встроенные атрибуты:
- `#[Required]`
- `#[Enum(...)]`

Вместо этого:
- для обязательности используется `#[NotEmpty]`;
- для проверки элементов коллекции есть `#[ElementsType(...)]`;
- enum `Bitrix\Main\Validation\Rule\Enum\Type` используется как вспомогательный тип внутри `ElementsType`.

## Рекурсивная валидация

```php
use Bitrix\Main\Validation\Rule\NotEmpty;
use Bitrix\Main\Validation\Rule\Recursive\Validatable;

final class AddressRequest
{
    #[NotEmpty]
    public string $city = '';
}

final class OrderRequest
{
    #[NotEmpty]
    public string $title = '';

    #[Validatable]
    public AddressRequest $address;

    public function __construct()
    {
        $this->address = new AddressRequest();
    }
}
```

Если вложенный объект не builtin и поле помечено `#[Validatable]`, `ValidationService` вызывает рекурсивный `validate(...)`.

## Class-level правило

```php
use Bitrix\Main\Validation\Rule\AtLeastOnePropertyNotEmpty;

#[AtLeastOnePropertyNotEmpty(['phone', 'email'])]
final class ContactRequest
{
    public string $phone = '';
    public string $email = '';
}
```

## `ValidationResult` и `ValidationError`

`ValidationResult` не добавляет свой API поверх `Result`; он наследует поведение базового результата:
- `isSuccess()`
- `getErrors()`
- `addError(...)`
- `addErrors(...)`

`ValidationError`:
- расширяет `Error`;
- умеет хранить `failedValidator`;
- поддерживает `string|int` code;
- даёт `hasCode()`.

## Неинициализированные свойства

Отдельная логика текущего `ValidationService`:
- если property не инициализировано;
- у него есть тип;
- и тип не допускает `null`,

сервис сам добавит ошибку `MAIN_VALIDATION_EMPTY_PROPERTY` с кодом имени свойства.

Это значит, что неинициализированный non-nullable property тоже считается validation-failure, даже без `#[NotEmpty]`.

## Кастомный атрибут

```php
use Attribute;
use Bitrix\Main\Validation\Rule\AbstractPropertyValidationAttribute;
use Bitrix\Main\Validation\Validator\RegExpValidator;

#[Attribute(Attribute::TARGET_PROPERTY)]
final class Inn extends AbstractPropertyValidationAttribute
{
    protected function getValidators(): array
    {
        return [
            new RegExpValidator('/^\d{10}(\d{2})?$/'),
        ];
    }
}
```

## Gotchas

- Не пиши в справке `#[Required]` и `#[Enum]` как штатные built-in атрибуты: они не подтверждены текущим core.
- `Min`, `Max` и `Range` в этом core принимают `int`, а не произвольный `int|float`.
- Для массивов и iterable используй `ElementsType`, а не выдуманный enum-validator.
- `ValidationResult` — это `Result`, а не отдельный полностью самостоятельный контейнер.

---

## Source: `http.md`

# Bitrix HTTP, DateTime, HttpClient — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с датами (Type\DateTime, Type\Date), внешними HTTP-запросами (HttpClient), входящим запросом (HttpRequest) или исходящим ответом (HttpResponse).
>
> Audit note (core-verified, current project): справочник сверялся по `www/bitrix/modules/main/lib/{request.php,httprequest.php,httpresponse.php,response.php}` и `main/lib/web/{cookie.php,cryptocookie.php,cookiescrypter.php}`.

## Содержание
- Type\DateTime и Type\Date: создание, арифметика, форматирование, таймзоны
- HttpClient: GET/POST запросы, заголовки, обработка ошибок
- HttpRequest: getQuery/getPost/getCookie/isAjax/isJson/decodeJson
- HttpResponse: addHeader/setStatus/addCookie/flush/redirectTo

---

## Type\DateTime и Type\Date

### Главное правило: toString() vs format()

`DateTime` хранит время в серверной таймзоне. Это разграничение критично:

- `format('d.m.Y H:i:s')` → **серверное время**, для хранения, логов, сравнений
- `toString()` → **пользовательское время** (авто-конвертация через `\CTimeZone`), для отображения

Ошибка: сравнивать `toString()` двух объектов — они уже в пользовательской зоне, результат непредсказуем. Всегда сравнивай через `getTimestamp()`.

```php
use Bitrix\Main\Type\DateTime;
use Bitrix\Main\Type\Date;

// Создание
$now  = new DateTime();                                        // текущий момент
$dt   = new DateTime('2024-06-15 14:30:00');                   // из строки Bitrix-формата
$dt   = DateTime::createFromTimestamp(time());                 // из UNIX timestamp
$dt   = DateTime::createFromUserTime('15.06.2024 14:30:00');  // из строки в зоне пользователя
$dt   = DateTime::createFromPhp(new \DateTime('now'));         // из PHP-нативного \DateTime
$dt   = DateTime::tryParse($userInput);                        // null при ошибке, не кидает исключение

$date = new Date('2024-06-15', 'Y-m-d');  // Date — только дата без времени
$date = Date::createFromTimestamp(time());

// Форматирование
$dt->format('d.m.Y H:i:s');   // серверное время — для хранения и логики
$dt->toString();               // пользовательское время — для вывода в HTML
$dt->getTimestamp();           // UNIX timestamp — для сравнений

// Управление конвертацией таймзоны
$dt->disableUserTime();  // toString() тоже вернёт серверное время
$dt->enableUserTime();   // вернуть по умолчанию (включена)

// Арифметика — ISO 8601 DateInterval
$dt->add('P1D');     // +1 день
$dt->add('P1M');     // +1 месяц
$dt->add('PT2H');    // +2 часа
$dt->add('PT30M');   // +30 минут
$dt->add('-P1D');    // -1 день

$dt->setTime(0, 0, 0);  // начало дня
$dt->setTimeZone(new \DateTimeZone('Europe/Moscow'));

// В ORM — DatetimeField принимает и возвращает объект DateTime
OrderTable::update($id, ['DEADLINE' => new DateTime('2024-12-31 23:59:59')]);
$row  = OrderTable::getById($id)->fetch();
$date = $row['CREATED_AT']; // instanceof DateTime
echo $date->format('d.m.Y');   // серверное
echo $date->toString();        // пользовательское
```

---

## HttpClient — внешние HTTP-запросы

`HttpClient` **не бросает исключений** на HTTP-ошибки (4xx, 5xx). Он возвращает тело ответа, а статус и транспортные ошибки нужно проверять вручную через `getStatus()` и `getError()`. Это самое частое место где пропускают проверку.

```php
use Bitrix\Main\Web\HttpClient;

$client = new HttpClient([
    'socketTimeout'          => 10,    // таймаут подключения (сек)
    'streamTimeout'          => 30,    // таймаут чтения (сек)
    'redirect'               => true,
    'redirectMax'            => 5,
    'disableSslVerification' => false, // true только для локальной разработки
]);

// GET — возвращает тело ответа (string) или false
$body   = $client->get('https://api.example.com/data');
$status = $client->getStatus(); // int: 200, 404, 500...
$errors = $client->getError();  // array транспортных ошибок (пустой если нет)

if (!empty($errors)) {
    // Ошибка соединения, DNS, timeout — запрос не дошёл
} elseif ($status !== 200) {
    // Сервер ответил, но с ошибкой
} else {
    $data = json_decode($body, true);
}

// POST с JSON
$client->setHeader('Content-Type', 'application/json');
$client->setHeader('Authorization', 'Bearer ' . $token);
$body = $client->post('https://api.example.com/orders', json_encode(['title' => 'Test']));

// POST с form-data
$body = $client->post('https://api.example.com/form', ['field1' => 'v1', 'field2' => 'v2']);

// Скачать файл на диск
$client->download('https://example.com/file.pdf', '/tmp/file.pdf');

// Заголовки ответа
$contentType = $client->getHeaders()->get('Content-Type');
```

---


---
## HttpRequest — входящий запрос

`HttpRequest` — D7-обёртка над `$_GET`, `$_POST`, `$_COOKIE`, `$_FILES`, заголовками. Проходит через фильтры безопасности ядра. **Никогда не читай `$_GET`/`$_POST` напрямую в D7-коде**.

```php
use Bitrix\Main\Application;

$request = Application::getInstance()->getContext()->getRequest();

// Параметры запроса
$id      = (int)$request->getQuery('id');           // GET['id']
$title   = $request->getPost('title');              // POST['title']
$file    = $request->getFile('upload');             // FILES['upload'] — массив
$merged  = $request->get('param');                  // GET+POST merged (осторожно — используй getQuery/getPost)

// Все значения как ParameterDictionary (iterable, методы get/toArray/getValues)
$getParams  = $request->getQueryList();
$postParams = $request->getPostList();
$files      = $request->getFileList();

// JSON-запросы (Content-Type: application/json)
if ($request->isJson()) {
    $request->decodeJson(); // парсит php://input → jsonData
}
$body = $request->getJsonList()->get('key'); // данные из тела JSON

// Заголовки (нижний регистр, дефисы вместо _)
$auth        = $request->getHeader('authorization');
$contentType = $request->getHeader('content-type');
$headers     = $request->getHeaders(); // HttpHeaders object

// Cookies (префикс снимается автоматически, CryptoCookie расшифровывается)
$userId = $request->getCookie('USER_ID'); // из BITRIX_SM_USER_ID
$rawCookie = $request->getCookieRaw('BITRIX_SM_USER_ID'); // raw browser cookie name

// Метаданные
$ip      = $request->getRemoteAddress();     // REMOTE_ADDR
$ua      = $request->getUserAgent();         // HTTP_USER_AGENT
$uri     = $request->getRequestUri();        // /catalog/item/?id=5
$page    = $request->getRequestedPage();     // /catalog/item/index.php
$method  = $request->getRequestMethod();     // 'GET', 'POST', ...

// Проверки
$request->isPost();          // bool: метод = POST
$request->isAjaxRequest();   // bool: HTTP_BX_AJAX или X-Requested-With: XMLHttpRequest
$request->isHttps();         // bool: HTTPS или порт 443
$request->isAdminSection();  // bool: /bitrix/admin/

// Raw body (для webhook'ов, подписей)
$rawBody = \Bitrix\Main\HttpRequest::getInput(); // file_get_contents('php://input')
```

### Важно: `getCookie()` и `getCookieRaw()` работают по-разному

Bitrix хранит cookies с префиксом (по умолчанию `BITRIX_SM_`) и готовит отдельный “нормализованный” cookie-словарь:
- `getCookie('USER_ID')` ищет browser-cookie `BITRIX_SM_USER_ID`, снимает префикс и при необходимости расшифровывает `CryptoCookie`
- `getCookieRaw('BITRIX_SM_USER_ID')` читает сырое имя из `$_COOKIE` без снятия префикса и без подготовки

---

## HttpResponse — исходящий ответ

```php
use Bitrix\Main\Application;

$response = Application::getInstance()->getContext()->getResponse();

// Заголовки
$response->addHeader('X-Custom-Header', 'value');
$response->addHeader('Content-Type', 'application/json; charset=utf-8');

// HTTP-статус
$response->setStatus(404);           // только код
$response->setStatus('404 Not Found'); // код + reason phrase
$response->getStatus();              // int

// Cookies
use Bitrix\Main\Web\Cookie;
$cookie = new Cookie('MY_PARAM', 'value', time() + 86400);
$cookie->setPath('/');
$cookie->setHttpOnly(true);
$cookie->setSecure(true);
$response->addCookie($cookie);

// Редирект
LocalRedirect('/new/url/'); // legacy, но до сих пор стандарт для компонентов

// D7-способ редиректа (из Controller или роута)
$redirectResponse = $response->redirectTo('/new/url/');
// redirectTo возвращает HttpResponse; на практике это Engine\Response\Redirect

// Контент + сброс
$response->setContent(json_encode($data));
$response->flush(); // сбрасывает буферы, отправляет заголовки + тело, fastcgi_finish_request если доступен
```

### Gotchas HttpResponse

- **`flush()` очищает ВСЕ output-буферы** (`while ob_get_length()`) — вызывай только когда готов завершить ответ
- **`redirectTo()` не отправляет ответ сразу** — он возвращает новый response-объект, который ещё нужно `send()` / `flush()`
- **Куки через `Cookie` / `CryptoCookie`** автоматически получают префикс `BITRIX_SM_`; шифруются только экземпляры `CryptoCookie`
- **`decodeJson()` молча игнорирует битый JSON** — после вызова проверяй `getJsonList()`, а не предполагай, что парсинг всегда успешен

---

## CryptoCookie — шифрованные куки

`CryptoCookie` шифрует значение через `CookiesCrypter` и ключ `crypto[crypto_key]` из `.settings.php`. В текущем core шифрование включается только для объектов `CryptoCookie`; обычный `Cookie` остаётся plain-text.

**Cookie vs CryptoCookie:**
- `Cookie` — plain-text cookie с битриксовым префиксом; ядро не шифрует её автоматически
- `CryptoCookie` — cookie, которую `CookiesCrypter` зашифрует перед отправкой ответа

```php
use Bitrix\Main\Web\CryptoCookie;
use Bitrix\Main\Context;

// ЗАПИСЬ зашифрованной куки
$cookie = new CryptoCookie(
    'FAVORITES',                    // имя (будет с префиксом BITRIX_SM_)
    json_encode([1, 2, 3]),         // значение — шифруется автоматически
    time() + 30 * 24 * 3600        // expire
);
$cookie->setPath('/');
$cookie->setHttpOnly(true);         // недоступна из JS
$cookie->setSecure(true);           // только HTTPS
$cookie->setSameSite('Lax');        // защита от CSRF через куки
Context::getCurrent()->getResponse()->addCookie($cookie);

// ЧТЕНИЕ зашифрованной куки
$raw = Context::getCurrent()->getRequest()->getCookie('FAVORITES');
// getCookie() автоматически расшифровывает CryptoCookie
$ids = $raw ? json_decode($raw, true) : [];

// УДАЛЕНИЕ куки (expire в прошлом)
$cookie = new CryptoCookie('FAVORITES', '', time() - 3600);
$cookie->setPath('/');
Context::getCurrent()->getResponse()->addCookie($cookie);
```

### Gotcha: crypto_key

`CryptoCookie` падает если `crypto_key` не настроен в `.settings.php` сайта. Опциональная проверка перед записью:

```php
// Проверка наличия crypto_key
$config = \Bitrix\Main\Config\Configuration::getInstance();
$security = $config->get('crypto');
$hasCryptoKey = !empty($security['crypto_key']);

if ($hasCryptoKey) {
    $cookie = new CryptoCookie('FAVORITES', json_encode($ids), time() + 30 * 24 * 3600);
} else {
    // Fallback: обычная Cookie (данные видны пользователю)
    $cookie = new \Bitrix\Main\Web\Cookie('FAVORITES', json_encode($ids), time() + 30 * 24 * 3600);
}
$cookie->setPath('/');
$cookie->setHttpOnly(true);
Context::getCurrent()->getResponse()->addCookie($cookie);
```

Настройка `crypto_key` в `.settings.php` сайта:
```php
'crypto' => ['value' => ['crypto_key' => 'your-32-char-secret-key-here!!!']],
```

---

---
