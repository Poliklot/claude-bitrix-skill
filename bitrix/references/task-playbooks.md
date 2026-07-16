# Практические playbooks для Bitrix-задач

Открывай после [behavior-routing.md](behavior-routing.md) и [project-intake.md](project-intake.md), когда пользователь ждёт не справку, а конкретное решение, патч или next action. Playbook — это короткий маршрут: **найти → понять слой → изменить → проверить**.

Не используй playbooks как замену доменным references. Если маршрут упирается в конкретный модуль, после первых проверок открой профильный reference.

## Универсальная схема

```text
1. Найти факт проекта: файл, component call, параметр, module, шаблон.
2. Назвать слой изменения: page property / component params / template / result_modifier / local module / migration.
3. Сделать минимальный patch или дать точный next action.
4. Проверить side effects: cache, rights, SEO, SEF, composite, events, agents.
```

Если проект доступен, в ответе должен быть хотя бы один конкретный путь к файлу или зафиксированное отсутствие нужного слоя.

## 1. Поменять meta title / description / canonical

**Найти:**

```bash
rg -n 'ShowHead|ShowTitle|SetTitle|SetPageProperty|SET_BROWSER_TITLE|SET_META_DESCRIPTION|SET_CANONICAL_URL|component_epilog' \
  local bitrix/templates www/bitrix/templates --glob '*.php'
```

**Решить:**

- если `header.php` содержит `ShowHead()`/`ShowTitle()` — не вставлять meta руками;
- browser title — page property `title` или component SEO param;
- H1 — `SetTitle`;
- description/canonical/robots — `SetPageProperty`;
- для детальной компонента — component params или `component_epilog.php`.

**Патчить:** страницу, `.section.php`, component params, `component_epilog.php` или SEO-настройки компонента; не `www/bitrix/modules`.

**Проверить:** кеш компонента, composite, SEO-наследование, canonical duplicates.

## 2. Подключить CSS/JS или head string

**Найти:**

```bash
rg -n 'Asset::getInstance|addCss|addJs|addString|ShowHead|ShowBodyScripts|template_styles.css|script.js' \
  local bitrix/templates www/bitrix/templates --glob '*.php' --glob '*.css' --glob '*.js'
```

**Решить:**

- site-level asset → template `header.php`/init/template assets;
- component asset → `style.css` / `script.js` шаблона компонента или `Asset`;
- произвольный meta/script in head → `Asset::addString` / `AddHeadString`.

**Проверить:** порядок подключения, дубль CSS/JS, ajax/composite, `ShowBodyScripts()`.

## 3. Найти где править компонент

**Найти:**

```bash
rg -n 'IncludeComponent\(' . --glob '*.php' --glob '!upload/**' --glob '!bitrix/cache/**' --glob '!www/bitrix/cache/**'
find local/templates bitrix/templates -path '*components/bitrix*' -type f 2>/dev/null | sort
```

**Решить слой:**

- параметры — в фактическом `IncludeComponent`;
- HTML — `template.php`;
- подготовка вывода — `result_modifier.php`;
- page effects/meta/404/breadcrumbs — `component_epilog.php`;
- тяжёлая логика — component class/service/local module.

**Проверить:** component cache, `setResultCacheKeys`, ajax mode, composite frames.

## 4. Свойство инфоблока не выводится

**Найти:**

```bash
rg -n 'PROPERTY_CODE|FIELD_CODE|DISPLAY_PROPERTIES|PROPERTIES|result_modifier|CIBlockElement|ElementTable' \
  local bitrix/templates www/bitrix/templates --glob '*.php'
```

**Решить:**

1. Проверить, передаётся ли код свойства в `PROPERTY_CODE`.
2. Проверить фактический `$arResult['PROPERTIES']` / `DISPLAY_PROPERTIES`.
3. Проверить `result_modifier.php`, где свойство могли удалить/переименовать.
4. Если пишем код — `Loader::includeModule('iblock')` и API/ORM, не SQL.

**Проверить:** кеш компонента, активность элемента/раздела, права, множественность, тип свойства, escaping.

## 5. “В админке есть, на сайте нет”

**Найти цепочку:**

```bash
rg -n 'IBLOCK_ID|FILTER_NAME|PROPERTY_CODE|CACHE_TYPE|CACHE_GROUPS|ACTIVE_DATE|CHECK_DATES|INCLUDE_SUBSECTIONS|PAGEN_|SORT_|result_modifier' \
  local bitrix/templates www/bitrix/templates --glob '*.php'
```

**Диагностировать:**

1. source: инфоблок/HL/form/search/catalog;
2. site binding / активность / даты / права;
3. component params: filter, sort, pagination, `PROPERTY_CODE`;
4. `result_modifier.php`;
5. template conditions;
6. component/tagged/composite cache;
7. search/SEO index, если вывод зависит от индекса.

**Не делать:** “очисти весь кеш” как единственное решение.

## 6. 404 отдаёт 200 или редирект не там

**Найти:**

```bash
rg -n 'CHTTP::SetStatus|ERROR_404|SET_STATUS_404|SHOW_404|LocalRedirect|SEF_MODE|SEF_FOLDER|urlrewrite|404.php' \
  . --glob '*.php' --glob '!upload/**' --glob '!bitrix/cache/**'
```

**Решить:**

- 404 — status + `ERROR_404` + project `404.php` + component strict params;
- redirect — `LocalRedirect` до вывода, validate external URLs;
- SEF — `urlrewrite.php`, component `SEF_URL_TEMPLATES`.

**Проверить:** HTTP status, canonical/SEO, redirect loops, composite/static cache.

## 7. Форма не отправляет письмо

**Найти:**

```bash
rg -n 'CEvent::Send|CEvent::SendImmediate|Main\\Mail\\Event::send|EVENT_NAME|MESSAGE_ID|SITE_ID|CForm|FORM_ID|form.result|check_bitrix_sessid|bitrix_sessid' \
  local bitrix/templates www/bitrix/templates www/bitrix/modules/form --glob '*.php'
```

**Диагностировать:**

1. request method + CSRF;
2. validation;
3. event name и fields;
4. mail template active/site binding;
5. queue/agents;
6. project mail service/logs.

**Не делать:** начинать с `mail()` или “SMTP сломан” без проверки Bitrix event layer.

## 8. AJAX в компоненте

**Найти:**

```bash
rg -n 'BX\\.ajax|runComponentAction|signedParameters|ajax\\.php|prolog_before|Controller|ActionFilter|JsonResponse|bitrix_sessid|check_bitrix_sessid' \
  local bitrix/templates www/bitrix/templates --glob '*.php' --glob '*.js'
```

**Решить:**

- если проект уже использует component action — продолжить этот путь;
- если D7 controller — соблюдать filters/auth/JSON contract;
- если legacy endpoint — `prolog_before.php`, sessid, auth, JSON response.

**Проверить:** CSRF, permissions, composite/ajax mode, response headers.

## 9. Кеш мешает или персональные данные смешались

**Найти:**

```bash
rg -n 'StartResultCache|AbortResultCache|setResultCacheKeys|CACHE_TYPE|CACHE_TIME|CACHE_GROUPS|RegisterTag|clearByTag|TaggedCache|Composite|StaticHtmlCache|Composite\\Page|AutomaticArea|COMPOSITE_FRAME_MODE|COMPOSITE_FRAME_TYPE|createFrame|FrameHelper|markNonCacheable|USER->IsAuthorized|GetID\\(' \
  local bitrix/templates www/bitrix/templates www/bitrix/modules --glob '*.php'
```

**Решить:**

- component cache params/key;
- `CACHE_GROUPS` для прав;
- `setResultCacheKeys` для данных в `component_epilog`;
- tagged/managed cache для зависимых данных;
- composite layer: `setFrameMode` как голосование/adaptation flag, `AutomaticArea`/`COMPOSITE_FRAME_*`, `createFrame`/`FrameHelper` как dynamic boundary;
- `/bitrix/html_pages/` и `X-Bitrix-Composite` для second request/cache pass.

**Не делать:** глобально отключать кеш без layer diagnosis; не считать `setFrameMode(true)` динамическим блоком. Для composite открывай `composite-cache.md`.


## 10. Аудит оптимизаций проекта

**Открыть:** [project-optimization-audit.md](project-optimization-audit.md), затем `perfmon.md`, `cache-infra.md`, `composite-cache.md`, `components.md`, `templates.md`, `operations-runbook.md` и доменные references.

**Найти:**

```bash
rg -n 'IncludeComponent\(|CACHE_TYPE|CACHE_TIME|CACHE_GROUPS|StartResultCache|setResultCacheKeys|CIBlockElement::GetList|::getList\(|ResizeImageGet|Asset::getInstance|CAgent::AddAgent|Stepper|setFrameMode|createFrame|Composite|clearCache|cleanDir|clearByTag' \
  . --glob '*.php' --glob '*.js' --glob '!upload/**' --glob '!bitrix/cache/**' --glob '!www/bitrix/cache/**'
```

**Отчёт:**

1. что уже оптимизировано: component/tagged/managed/composite cache, pagination/lazy, images, agents/stepper, frontend assets;
2. где оптимизации опасны: персональные данные в кеше, `CACHE_TYPE=N` без причины, общий cache key, N+1, full-table selects, global cache clear;
3. safe wins: preload вместо N+1, точечные cache tags, корректный `CACHE_GROUPS`, dynamic area для персональных блоков, batching imports;
4. что требует runtime/perfmon: DB indexes, slow SQL, hot pages, frontend weight, CDN/browser cache.

**Не делать:** не обещать ускорение без evidence; не советовать Redis/CDN/composite/global clear как первый шаг.

## 11. Shop/catalog/sale задача

**Сначала module check:**

```bash
for m in catalog sale currency; do test -f "www/bitrix/modules/$m/install/version.php" && echo "FOUND $m" || echo "MISSING $m"; done
```

**Если modules есть:**

- product/offer/price/stock → `catalog` API/reference;
- basket/order/payment/shipment/discount → `sale` API/reference;
- money/currency formatting → `currency`;
- public UI → `shop-standard-components`.

**Проверить:** events, recalculation, discounts, reserves, store documents, order save errors, exchange side effects.

**Не делать:** прямой SQL в price/order/basket/stock tables.

## 12. 1С / CommerceML обмен

**Найти:**

```bash
rg -n 'catalog\\.import\\.1c|catalog\\.export\\.1c|sale\\.export\\.1c|BX_CML2|CML2_LINK|XML_ID|checkauth|mode=init|mode=file|mode=import|1c_exchange|CommerceML' \
  . --glob '*.php' --glob '!upload/**' --glob '!bitrix/cache/**'
```

**Диагностировать:**

1. flow `checkauth → init → file → import`;
2. session/cookies/sessid;
3. temp files/chunk/zip;
4. XML_ID/CML2_LINK;
5. logs and last import errors;
6. product active/site/price/stock visibility after import.

**Не делать:** считать успешный upload XML успешным импортом.

## 13. Где писать кастомную логику

**Найти project conventions:**

```bash
find local local/modules -maxdepth 4 -type f \( -name '*.php' -o -name 'composer.json' \) 2>/dev/null | sort | head -n 120
rg -n 'namespace |ServiceLocator|EventManager::getInstance|Loader::registerAutoLoadClasses|class .*Service|class .*Repository' local local/modules --glob '*.php'
```

**Выбрать слой:**

- одноразовая настройка данных → migration/install step;
- бизнес-логика → service/local module;
- реакция на событие → event handler with idempotent install/uninstall;
- вывод компонента → result_modifier/template;
- endpoint → controller/component action.

**Проверить:** project tooling, autoload, rollback, idempotency, tests/smoke.

## 14. Разместить page/include/global block

**Открыть:** [project-layout-and-includes.md](project-layout-and-includes.md), затем `project-intake.md`, `templates.md`, `components.md`.

**Найти:**

```bash
find . -maxdepth 5 -type f \( -name header.php -o -name footer.php -o -name '.section.php' \) -print
rg -n 'SITE_TEMPLATE_PATH|IncludeComponent\(|IncludeFile\(|main\.include|SetViewTarget|ShowViewContent|AddViewContent' \
  . --glob '*.php' --glob '!upload/**' --glob '!bitrix/cache/**' --glob '!www/bitrix/cache/**'
```

**Решить:**

- project page content → page/section entrypoint;
- global layout → подтверждённый active template;
- editor fragment → project include/property/iblock convention;
- component HTML → copied template;
- query/business rule → component/service;
- delayed/personal block → project view target/composite dynamic boundary.

**Не делать:** не навязывать `/include`, `main` template или rigid placement; не копировать stock component logic ради HTML.

**Проверить:** active template, `SITE_ID`/`SITE_DIR`, edit mode, first/second cache pass, guest/authorized, stock-template provenance.

## 15. Настроить `.env`/`Option`/entity ID

**Открыть:** [project-configuration.md](project-configuration.md), затем `production-best-practices.md`, `entities-migrations.md` и доменный reference.

**Найти:**

```bash
find . -maxdepth 4 -type f \( -name '.env.example' -o -name composer.json -o -name constants.php -o -name init.php \) -print
rg -l 'Dotenv|\$_ENV|\$_SERVER|getenv\(|Option::get|COption::GetOption|IBLOCK_ID|FORM_ID|HLBLOCK_ID' \
  local . --glob '*.php' --glob '*.example' --glob '!bitrix/**' --glob '!www/bitrix/**' --glob '!vendor/**'
```

Discovery должен вывести только filenames. Выбранные файлы проверять локально и точечно; не переносить совпавшие config-строки в transcript/evidence без редактирования secrets.

**Решить:**

1. classify: secret/deployment option/admin option/entity reference/content;
2. preserve current config/bootstrap convention;
3. validate string→type and required/range/host policy;
4. for entity: stable key + sufficient scope + migration/registry, exactly one row;
5. define protected cache invalidation and safe public error.

**Не делать:** не добавлять Dotenv автоматически, не считать numeric ID secret, не lookup-ить только по `CODE`, не передавать `null`/`0`, не делать anonymous cache reset.

**Проверить:** dev/stage/prod, multisite, missing/duplicate, entity type/code/site, secret leaks, cache refresh and smoke.

## Ответ после playbook

Формат:

```text
Проверил: [факт проекта/path].
Причина/слой: [why].
Делаю/предлагаю: [patch or next action].
Проверить после: [cache/status/page/test].
Риски: [side effects].
```
