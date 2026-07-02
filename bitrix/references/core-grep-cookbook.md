# Core grep cookbook для Bitrix-проектов

Открывай этот файл, когда нужно быстро подтвердить ответ по живому проекту: “где это задаётся”, “почему не работает”, “какой компонент/шаблон править”, “есть ли модуль”, “где кеш/событие/ajax/почта/404”. Для бытовых вопросов сначала прочитай [developer-primitives.md](developer-primitives.md), [first-answer-pitfalls.md](first-answer-pitfalls.md) и при необходимости [developer-cards.md](developer-cards.md), затем используй cookbook как набор готовых read-only проверок.

## Правила перед grep

1. Команды выполнять из корня репозитория. Если публичный корень не `www/`, сначала найти его по `bitrix/modules/main`.
2. Сначала искать в проектном слое: `local/`, `local/templates`, `local/components`, `local/modules`, `local/php_interface`, затем в `bitrix/templates`, потом в stock core `www/bitrix/modules/*/install/components/bitrix/*`.
3. Не считать наличие шаблона `catalog.*` доказательством установленного `catalog`: сначала проверить `www/bitrix/modules/catalog/install/version.php` и `Loader::includeModule('catalog')`.
4. Не сканировать без нужды `upload/`, `bitrix/cache/`, `bitrix/managed_cache/`, `bitrix/stack_cache/`, vendor-бандлы ядра и большие логи.
5. Если `rg` ругается на отсутствующую папку, это факт структуры проекта: повторить команду только по существующим путям.

## Содержание

- [Быстрый шаблон команды](#быстрый-шаблон-команды)
- [1. Найти публичный корень и установленные модули](#1-найти-публичный-корень-и-установленные-модули)
- [2. Meta/head/title/assets/panel](#2-metaheadtitleassetspanel)
- [3. Найти фактический вызов компонента](#3-найти-фактический-вызов-компонента)
- [4. Параметры компонента и page effects](#4-параметры-компонента-и-page-effects)
- [5. Шаблоны сайта и include areas](#5-шаблоны-сайта-и-include-areas)
- [6. Iblock/HL: свойства, элементы, связи](#6-iblockhl-свойства-элементы-связи)
- [7. Кеш, composite, персонализация](#7-кеш-composite-персонализация)
- [8. Аудит оптимизаций проекта](#8-аудит-оптимизаций-проекта)
- [9. Routing, SEF, 404, redirect](#9-routing-sef-404-redirect)
- [10. Request, пользователь, права, CSRF](#10-request-пользователь-права-csrf)
- [11. Events, handlers, agents, cron/stepper](#11-events-handlers-agents-cronstepper)
- [12. AJAX, controllers, JSON](#12-ajax-controllers-json)
- [13. Почта, webforms, уведомления](#13-почта-webforms-уведомления)
- [14. Search/SEO/index/cache](#14-searchseoindexcache)
- [15. Sale/catalog/currency: только после module check](#15-salecatalogcurrency-только-после-module-check)
- [16. 1С / CommerceML](#16-1с--commerceml)
- [17. Админка, grid, custom UI](#17-админка-grid-custom-ui)
- [18. Логи и runtime hooks](#18-логи-и-runtime-hooks)

## Быстрый шаблон команды

```bash
rg -n --hidden \
  --glob '!upload/**' \
  --glob '!bitrix/cache/**' \
  --glob '!bitrix/managed_cache/**' \
  --glob '!bitrix/stack_cache/**' \
  --glob '!www/bitrix/cache/**' \
  --glob '!www/bitrix/managed_cache/**' \
  --glob '!www/bitrix/stack_cache/**' \
  'PATTERN' local bitrix/templates www/bitrix/templates
```

Для stock contract добавляй `www/bitrix/modules/<module>/install/components/bitrix/<component>/` или `www/bitrix/modules/<module>/lib/`.

## 1. Найти публичный корень и установленные модули

```bash
find . -maxdepth 5 -type d -path '*/bitrix/modules/main' -print
find . -maxdepth 5 -type d -path '*/local' -print
```

```bash
find www/bitrix/modules -maxdepth 1 -mindepth 1 -type d | sort
```

```bash
for m in main iblock highloadblock form search seo fileman catalog sale currency rest bizproc workflow pull; do
  test -f "www/bitrix/modules/$m/install/version.php" && echo "== $m ==" && sed -n '1,40p' "www/bitrix/modules/$m/install/version.php"
done
```

Если у `main` нет `install/version.php`, проверить:

```bash
sed -n '1,80p' www/bitrix/modules/main/classes/general/version.php
```

## 2. Meta/head/title/assets/panel

Используй для вопросов “как поставить title/description/canonical”, “почему meta не выводится”, “куда подключить CSS/JS”.

```bash
rg -n 'ShowHead|ShowTitle|ShowMeta|SetTitle|SetPageProperty|AddHeadString|Asset::getInstance|addCss|addJs|addString|ShowBodyScripts|ShowPanel' \
  local bitrix/templates www/bitrix/templates --glob '*.php'
```

```bash
find local/templates bitrix/templates www/bitrix/templates -maxdepth 3 \
  \( -name header.php -o -name footer.php -o -name '.section.php' \) -type f -print
```

Что сказать по результату:

- если `header.php` содержит `ShowHead()` и `ShowTitle()`, не предлагать ручной `<meta>` первым шагом;
- если нет `ShowBodyScripts()`, JS перед `</body>` может не выводиться штатно;
- если title/description задаёт компонент, искать `SET_BROWSER_TITLE`, `SET_META_DESCRIPTION`, `component_epilog.php`.

## 3. Найти фактический вызов компонента

```bash
rg -n 'IncludeComponent\(' . \
  --glob '*.php' \
  --glob '!upload/**' \
  --glob '!bitrix/cache/**' \
  --glob '!www/bitrix/cache/**'
```

По конкретному компоненту:

```bash
rg -n "IncludeComponent\(['\"]bitrix:(news|catalog|catalog.section|catalog.element|breadcrumb|search.page|form.result.new)" \
  . --glob '*.php' --glob '!upload/**' --glob '!bitrix/cache/**' --glob '!www/bitrix/cache/**'
```

Найти проектный шаблон компонента:

```bash
find local/templates bitrix/templates -path '*components/bitrix*' -type f \
  \( -name template.php -o -name result_modifier.php -o -name component_epilog.php -o -name style.css -o -name script.js \) | sort
```

Найти stock contract:

```bash
find www/bitrix/modules -path '*/install/components/bitrix/*' -type f \
  \( -name '.parameters.php' -o -name 'component.php' -o -name 'class.php' -o -name 'template.php' \) \
  | rg '/(news|catalog|breadcrumb|search|form|sale|system)\.'
```

## 4. Параметры компонента и page effects

```bash
rg -n "SET_TITLE|SET_BROWSER_TITLE|SET_META_KEYWORDS|SET_META_DESCRIPTION|SET_CANONICAL_URL|BROWSER_TITLE|META_KEYWORDS|META_DESCRIPTION|ADD_SECTIONS_CHAIN|ADD_ELEMENT_CHAIN|SET_STATUS_404|SHOW_404|SEF_MODE|SEF_FOLDER|CACHE_TYPE|CACHE_TIME|CACHE_GROUPS|AJAX_MODE|PROPERTY_CODE|FIELD_CODE" \
  . --glob '*.php' --glob '!upload/**' --glob '!bitrix/cache/**' --glob '!www/bitrix/cache/**'
```

```bash
rg -n 'component_epilog|setResultCacheKeys|SetPageProperty|SetTitle|AddChainItem|CHTTP::SetStatus|ERROR_404' \
  local/templates bitrix/templates --glob '*.php'
```

Используй это перед ответами про meta, breadcrumbs, 404, свойства инфоблока и “почему не видно в шаблоне”.

## 5. Шаблоны сайта и include areas

```bash
rg -n 'IncludeFile|AREA_FILE|ShowViewContent|SetViewTarget|EndViewTarget|SITE_TEMPLATE_PATH|SITE_DIR|GetTemplatePath|GetFolder' \
  local bitrix/templates www/bitrix/templates --glob '*.php'
```

```bash
find . -maxdepth 5 -type d \( -name include -o -name includes \) -print
find . -maxdepth 6 -type f -path '*include*' \( -name '*.php' -o -name '*.html' -o -name '*.inc' \) | sort
```

Если текст должен редактироваться контентщиком, сначала проверять `IncludeFile`, включаемые области, свойства страницы и инфоблок, а не хардкод в `template.php`.

## 6. Iblock/HL: свойства, элементы, связи

```bash
rg -n 'CIBlock|CIBlockElement|CIBlockSection|Iblock\\|ElementTable|SectionTable|PropertyTable|PROPERTY_CODE|DISPLAY_PROPERTIES|PROPERTIES|IBLOCK_ID|IBLOCK_TYPE|GetProperty|SetPropertyValues|SetPropertyValuesEx' \
  local bitrix/templates www/bitrix/templates --glob '*.php'
```

```bash
rg -n 'HighloadBlock|HighloadBlockTable|compileEntity|UF_|USER_FIELD|CUserTypeEntity' \
  local bitrix/templates www/bitrix/templates www/bitrix/modules/highloadblock --glob '*.php'
```

Stock iblock components:

```bash
find www/bitrix/modules/iblock/install/components/bitrix -maxdepth 2 -type f \
  \( -name '.parameters.php' -o -name 'component.php' -o -name 'class.php' -o -name 'template.php' \) | sort
```

Что проверить перед ответом:

- перед выводом свойства — `PROPERTY_CODE`, `FIELD_CODE`, `DISPLAY_PROPERTIES`, фактический `$arResult`;
- перед API — `Loader::includeModule('iblock')`;
- перед SQL — есть ли API/ORM и какие side effects у кеша/индексов.

## 7. Кеш, composite, персонализация

```bash
rg -n 'StartResultCache|AbortResultCache|IncludeComponentTemplate|setResultCacheKeys|CACHE_TYPE|CACHE_TIME|CACHE_GROUPS|clearComponentCache|ClearCache|RegisterTag|clearByTag|TaggedCache|managed_cache|CPHPCache' \
  local bitrix/templates www/bitrix/templates www/bitrix/modules --glob '*.php'
```

```bash
rg -n 'Composite|StaticHtmlCache|Composite\\Page|AutomaticArea|COMPOSITE_FRAME_MODE|COMPOSITE_FRAME_TYPE|FrameHelper|Frame|createFrame|startDynamicWithID|finishDynamicWithID|markNonCacheable|begin|end|ShowViewContent|SetViewTarget|CACHE_GROUPS|USER->IsAuthorized|GetID\(' \
  local bitrix/templates www/bitrix/templates --glob '*.php'
```

Правило ответа: не начинать с “выключи весь кеш”. Сначала назвать слой: параметры компонента, ключ кеша, `CACHE_GROUPS`, managed/tagged cache, composite static HTML (`/bitrix/html_pages/`, `X-Bitrix-Composite`, `Composite\Page`), `setFrameMode` vote/adaptation, `AutomaticArea`/`COMPOSITE_FRAME_*`, dynamic boundary (`createFrame`/`FrameHelper`), result cache keys, ajax payload. Для composite деталей открывай `composite-cache.md`.


## 8. Аудит оптимизаций проекта

```bash
rg -n 'IncludeComponent\(|CACHE_TYPE|CACHE_TIME|CACHE_GROUPS|StartResultCache|AbortResultCache|setResultCacheKeys|RegisterTag|clearByTag|TaggedCache|Composite|createFrame|CIBlockElement::GetList|CIBlockSection::GetList|::getList\(|DataManager::getList|ResizeImageGet|Asset::getInstance|addCss|addJs|CAgent::AddAgent|Stepper|cron|import|exchange|clearCache|cleanDir' \
  . --glob '*.php' --glob '*.js' --glob '!upload/**' --glob '!bitrix/cache/**' --glob '!www/bitrix/cache/**'
```

```bash
rg -n 'foreach\s*\(|while\s*\(|Option::get|Loader::includeModule|GetUserGroupArray|IsAuthorized|GetList|::getList|ResizeImageGet' \
  local/templates bitrix/templates www/bitrix/templates local/components \
  --glob 'template.php' --glob 'result_modifier.php' --glob 'component_epilog.php'
```

Правило ответа: для общего “как оптимизировать проект” открывай `project-optimization-audit.md` и возвращай audit-report: что уже оптимизировано, какие оптимизации сломаны/опасны, safe wins, что требует `perfmon`/runtime evidence, что нельзя менять вслепую. Не начинай с Redis/CDN/composite/global clear без evidence.

## 9. Routing, SEF, 404, redirect

```bash
rg -n 'CHTTP::SetStatus|ERROR_404|SET_STATUS_404|SHOW_404|LocalRedirect|GetCurPage|GetCurDir|GetCurPageParam|SEF_MODE|SEF_FOLDER|SEF_URL_TEMPLATES|urlrewrite' \
  . --glob '*.php' --glob '!upload/**' --glob '!bitrix/cache/**' --glob '!www/bitrix/cache/**'
```

```bash
test -f urlrewrite.php && sed -n '1,220p' urlrewrite.php
test -f www/urlrewrite.php && sed -n '1,220p' www/urlrewrite.php
find . -maxdepth 3 -name '404.php' -type f -print
```

Для 404 проверять статус, `ERROR_404`, проектный `404.php`, strict-параметры компонента и кеш. Для redirect — `LocalRedirect`, отсутствие вывода до headers, защиту от open redirect.

## 10. Request, пользователь, права, CSRF

```bash
rg -n 'Context::getCurrent|getRequest\(|\$_REQUEST|\$_GET|\$_POST|check_bitrix_sessid|bitrix_sessid_post|bitrix_sessid_get|sessid|global \$USER|IsAuthorized|GetID\(|GetUserGroupArray|IsAdmin|Authorize' \
  local bitrix/templates www/bitrix/templates --glob '*.php'
```

Если находишь `$_REQUEST`/`$_POST`, не объявляй сразу багом: старый Bitrix-код так часто написан. Для нового ответа всё равно предлагать D7 `Context`, фильтрацию и CSRF для POST.

## 11. Events, handlers, agents, cron/stepper

```bash
rg -n 'EventManager::getInstance|addEventHandler|registerEventHandler|RegisterModuleDependences|UnRegisterModuleDependences|On[A-Z][A-Za-z0-9_]+' \
  local/php_interface local/modules --glob '*.php'
```

```bash
rg -n 'CAgent::AddAgent|CAgent::RemoveAgent|CheckAgents|Agent|Stepper|Option::set|AddMessage2Log|Debug::writeToFile|Logger' \
  local local/modules bitrix/php_interface www/bitrix/php_interface --glob '*.php'
```

Для нового обработчика предпочитать локальный модуль/install step или осознанный `local/php_interface`, а не случайный код в шаблоне.

## 12. AJAX, controllers, JSON

```bash
rg -n 'prolog_before|ajax\.php|BX\.ajax|runComponentAction|signedParameters|bitrix_sessid|check_bitrix_sessid|Json|JsonResponse|Controller|ActionFilter|HttpResponse|Application::getInstance\(\)->getContext\(\)->getResponse' \
  local bitrix/templates www/bitrix/templates --glob '*.php' --glob '*.js'
```

Проверять проектный паттерн: классический endpoint с `prolog_before.php`, component action, D7 controller, формат JSON, CSRF, авторизация, composite/ajax mode.

## 13. Почта, webforms, уведомления

```bash
rg -n 'CEvent::Send|CEvent::SendImmediate|Main\\Mail\\Event::send|Bitrix\\Main\\Mail|mail\(|EVENT_NAME|MESSAGE_ID|LID|SITE_ID|CForm|FORM_ID|webform|form.result|bitrix:form' \
  local bitrix/templates www/bitrix/templates www/bitrix/modules/form www/bitrix/modules/main --glob '*.php'
```

Если задача “форма не отправляет письмо”, проверить event name, почтовый шаблон, `SITE_ID`, обязательные поля, очередь/агенты, project mail service и логи. Не начинать с нативного `mail()`.

## 14. Search/SEO/index/cache

```bash
rg -n 'CSearch|Search\\|UpdateSearch|BeforeIndex|OnSearch|SetPageProperty|SetTitle|SET_META|SET_BROWSER_TITLE|SET_CANONICAL_URL|robots|canonical|sitemap|seo' \
  local bitrix/templates www/bitrix/templates www/bitrix/modules/search www/bitrix/modules/seo --glob '*.php'
```

Для “в админке есть, на сайте нет” идти по цепочке: источник данных → права/site binding → параметры компонента → фильтр/сортировка/пагинация → `result_modifier.php` → шаблон → кеш/индекс/SEO.

## 15. Sale/catalog/currency: только после module check

```bash
for m in catalog sale currency; do
  test -f "www/bitrix/modules/$m/install/version.php" && echo "FOUND $m" || echo "MISSING $m"
done
```

```bash
rg -n 'Bitrix\\Sale|Bitrix\\Catalog|Basket|Order|Payment|Shipment|Discount|Store|Price|Currency|CCatalog|CSale|CPrice|CCatalogProduct|PRODUCT_ID|OFFER_ID|QUANTITY|STORE_ID' \
  local bitrix/templates www/bitrix/templates --glob '*.php'
```

Stock shop components:

```bash
find www/bitrix/modules -path '*/install/components/bitrix/*' -type f \
  \( -name '.parameters.php' -o -name 'component.php' -o -name 'class.php' \) \
  | rg '/(catalog|sale|currency)\.'
```

Не отвечать direct SQL для корзины, заказов, оплат, доставок, цен и остатков: там события, пересчёты, резервы, статусы, скидки, обмены.

## 16. 1С / CommerceML

```bash
find www/bitrix/modules -path '*/install/components/bitrix/*1c*' -type f | sort
```

```bash
rg -n 'catalog\.import\.1c|catalog\.export\.1c|sale\.export\.1c|BX_CML2|CML2_LINK|XML_ID|checkauth|mode=import|mode=file|mode=init|1c_exchange|CommerceML|import_files|zip|sessid' \
  . --glob '*.php' --glob '!upload/**' --glob '!bitrix/cache/**' --glob '!www/bitrix/cache/**'
```

Для диагностики обмена проверять flow `checkauth → init → file → import`, cookies/session, temp files, XML_ID/CML2_LINK, права, размер чанка, zip и exchange logs.

## 17. Админка, grid, custom UI

```bash
rg -n 'AdminList|CAdminList|CAdminFilter|Grid|UI\\Buttons|UI\\Toolbar|ui\.buttons|main\.ui\.grid|main\.ui\.filter|bitrix:main\.ui' \
  local local/modules bitrix/admin www/bitrix/modules --glob '*.php'
```

Если задача про кнопку/колонку/фильтр в админке, проверять права, module admin files, grid id, filter id, actions и sessid.

## 18. Логи и runtime hooks

```bash
rg -n 'AddMessage2Log|Debug::writeToFile|Logger|Monolog|LOG_FILENAME|error_log|Exception|Application::getExceptionHandler' \
  local local/modules bitrix/php_interface www/bitrix/php_interface --glob '*.php'
```

```bash
find local local/modules bitrix/php_interface www/bitrix/php_interface -maxdepth 5 -type f \
  \( -name '*log' -o -name '*.log' -o -name 'dbconn.php' -o -name '.settings.php' \) 2>/dev/null
```

Если часть папок отсутствует, это нормальный факт структуры проекта. Не читать production-логи с персональными данными без необходимости и разрешения.

## Мини-чеклист ответа после grep

В хорошем ответе после использования cookbook есть:

1. **Факт из проекта:** найден файл/параметр/модуль или зафиксировано отсутствие.
2. **Bitrix-native маршрут:** какой API/компонент/шаблон/событие использовать.
3. **Где менять:** конкретный слой (`local/templates/...`, `local/modules/...`, migration/install step, component params).
4. **Что не делать первым:** ручной PHP/SQL/правка ядра/глобальный cache-off, если это анти-паттерн.
5. **Side effects:** кеш, права, индексы, SEF, composite, события, агенты, sale/catalog пересчёты.
