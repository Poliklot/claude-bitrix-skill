# Core grep cookbook

Открывай после `developer-primitives.md` / `first-answer-pitfalls.md` / `developer-cards.md`, когда бытовой или debug-ответ нужно подтвердить живым проектом. Команды read-only, запускать из корня repo; если public root не `www/`, сначала найти `*/bitrix/modules/main`.

## Базовые правила

- Сначала `local/`, `local/templates`, `local/components`, `local/modules`, `local/php_interface`; затем `bitrix/templates`; потом stock core `www/bitrix/modules/*/install/components/bitrix/*`.
- Не сканировать без нужды `upload/`, `bitrix/cache/`, `managed_cache`, `stack_cache`.
- Наличие `catalog.*` template не доказывает commerce: проверить `catalog`, `sale`, `currency` в `www/bitrix/modules`.
- Если директории нет, это факт проекта; повтори команду по существующим путям.

## Public root / modules

```bash
find . -maxdepth 5 -type d -path '*/bitrix/modules/main' -print
find www/bitrix/modules -maxdepth 1 -mindepth 1 -type d | sort
for m in main iblock highloadblock form search seo catalog sale currency rest bizproc workflow pull; do
  test -f "www/bitrix/modules/$m/install/version.php" && echo "== $m ==" && sed -n '1,40p' "www/bitrix/modules/$m/install/version.php"
done
```

## Быстрые grep-маршруты

| Задача | Команда / pattern | Что подтвердить |
|---|---|---|
| meta/title/head/assets | `rg -n 'ShowHead|ShowTitle|ShowMeta|SetTitle|SetPageProperty|AddHeadString|Asset::getInstance|addCss|addJs|addString|ShowBodyScripts|ShowPanel' local bitrix/templates www/bitrix/templates --glob '*.php'` | `header.php`, `footer.php`, page/section properties, component SEO params. Не начинать с ручного `<meta>`. |
| header/footer/section | `find local/templates bitrix/templates www/bitrix/templates -maxdepth 3 \( -name header.php -o -name footer.php -o -name '.section.php' \) -type f -print` | Центральный вывод `ShowHead`/`ShowTitle`, `ShowBodyScripts`, `.section.php`. |
| calls to components | `rg -n 'IncludeComponent\(' . --glob '*.php' --glob '!upload/**' --glob '!bitrix/cache/**' --glob '!www/bitrix/cache/**'` | Фактическая страница и параметры компонента. |
| component templates | `find local/templates bitrix/templates -path '*components/bitrix*' -type f \( -name template.php -o -name result_modifier.php -o -name component_epilog.php -o -name style.css -o -name script.js \) | sort` | Где править HTML/data/page effects. |
| stock component contract | `find www/bitrix/modules -path '*/install/components/bitrix/*' -type f \( -name '.parameters.php' -o -name 'component.php' -o -name 'class.php' -o -name 'template.php' \) | rg '/(news|catalog|breadcrumb|search|form|sale|system)\.'` | Какие параметры/API есть в установленном core. |
| component params/page effects | `rg -n 'SET_TITLE|SET_BROWSER_TITLE|SET_META_KEYWORDS|SET_META_DESCRIPTION|SET_CANONICAL_URL|ADD_SECTIONS_CHAIN|ADD_ELEMENT_CHAIN|SET_STATUS_404|SHOW_404|SEF_MODE|CACHE_TYPE|CACHE_GROUPS|PROPERTY_CODE|FIELD_CODE|setResultCacheKeys|component_epilog' . --glob '*.php' --glob '!upload/**' --glob '!bitrix/cache/**'` | SEO, breadcrumbs, 404, properties, cache keys. |
| include areas | `rg -n 'IncludeFile|AREA_FILE|ShowViewContent|SetViewTarget|EndViewTarget|SITE_TEMPLATE_PATH|SITE_DIR|GetFolder' local bitrix/templates www/bitrix/templates --glob '*.php'` | Редактируемые области, view targets, template asset paths. |
| project config/entity IDs | `find . -maxdepth 4 -type f \( -name '.env.example' -o -name composer.json -o -name constants.php -o -name init.php \) -print` then filename-only `rg -l 'Dotenv|\$_ENV|\$_SERVER|getenv\(|Option::get|COption::GetOption|IBLOCK_ID|FORM_ID|HLBLOCK_ID' local . --glob '*.php' --glob '*.example' --glob '!bitrix/**' --glob '!www/bitrix/**' --glob '!vendor/**'` | Existing convention, validation/types, stable-key scope, missing/duplicate, cache invalidation, no secret leaks. Не печатать config lines массово; точечно редактировать secrets как `<redacted>`. Route to `project-configuration.md`. |
| iblock/HL | `rg -n 'CIBlock|CIBlockElement|Iblock\\|ElementTable|SectionTable|PropertyTable|PROPERTY_CODE|DISPLAY_PROPERTIES|IBLOCK_ID|GetProperty|SetPropertyValues|HighloadBlock|UF_|CUserTypeEntity' local bitrix/templates www/bitrix/templates --glob '*.php'` | Module check, property params, `$arResult`, HL/UF API; не SQL первым шагом. |
| cache/composite | `rg -n 'StartResultCache|AbortResultCache|setResultCacheKeys|CACHE_TYPE|CACHE_TIME|CACHE_GROUPS|RegisterTag|clearByTag|TaggedCache|CPHPCache|Composite|StaticHtmlCache|Composite\\Page|AutomaticArea|COMPOSITE_FRAME_MODE|COMPOSITE_FRAME_TYPE|FrameHelper|Frame|createFrame|markNonCacheable' local bitrix/templates www/bitrix/templates www/bitrix/modules --glob '*.php'` | Не “выключить весь кеш”, а слой кеша: component/tagged/managed/composite static HTML (`/bitrix/html_pages/`, `X-Bitrix-Composite`, `Composite\Page`), `AutomaticArea`/`COMPOSITE_FRAME_*`, dynamic area/personalization. |
| аудит оптимизаций проекта | `rg -n 'IncludeComponent\(|CACHE_TYPE|CACHE_TIME|CACHE_GROUPS|StartResultCache|setResultCacheKeys|CIBlockElement::GetList|::getList\(|ResizeImageGet|Asset::getInstance|CAgent::AddAgent|Stepper|Composite|clearCache|cleanDir|clearByTag' . --glob '*.php' --glob '*.js' --glob '!upload/**' --glob '!bitrix/cache/**'` | Собрать карту уже имеющихся оптимизаций и bottlenecks: cache layers, SQL/ORM/N+1, heavy templates, images/assets, agents/imports, search/facet/SEO, shop side effects; не начинать с Redis/CDN/global clear. |
| routing/404/redirect | `rg -n 'CHTTP::SetStatus|ERROR_404|SET_STATUS_404|SHOW_404|LocalRedirect|GetCurPageParam|SEF_MODE|SEF_FOLDER|SEF_URL_TEMPLATES|urlrewrite' . --glob '*.php' --glob '!upload/**' --glob '!bitrix/cache/**'` | Статус, `404.php`, `urlrewrite.php`, SEF, open redirect risk. |
| request/user/CSRF | `rg -n 'Context::getCurrent|getRequest\\(|\\$_REQUEST|\\$_GET|\\$_POST|check_bitrix_sessid|bitrix_sessid_post|global \\$USER|IsAuthorized|GetID\\(|GetUserGroupArray' local bitrix/templates www/bitrix/templates --glob '*.php'` | D7 request, фильтрация, CSRF, `$USER`, composite caveat. |
| events/agents | `rg -n 'EventManager::getInstance|addEventHandler|registerEventHandler|RegisterModuleDependences|On[A-Z][A-Za-z0-9_]+|CAgent::AddAgent|Stepper|AddMessage2Log|Debug::writeToFile' local/php_interface local/modules --glob '*.php'` | Handler layer: local module/php_interface, idempotent install/uninstall. |
| ajax/controllers | `rg -n 'prolog_before|ajax\\.php|BX\\.ajax|runComponentAction|signedParameters|bitrix_sessid|check_bitrix_sessid|JsonResponse|Controller|ActionFilter' local bitrix/templates www/bitrix/templates --glob '*.php' --glob '*.js'` | Project ajax pattern, sessid, auth, JSON, composite. |
| mail/webforms | `rg -n 'CEvent::Send|CEvent::SendImmediate|Main\\\\Mail\\\\Event::send|Bitrix\\\\Main\\\\Mail|mail\\(|EVENT_NAME|MESSAGE_ID|SITE_ID|CForm|FORM_ID|webform|form.result|bitrix:form' local bitrix/templates www/bitrix/templates www/bitrix/modules/form --glob '*.php'` | Mail events/templates/site id/queue; не `mail()` первым вариантом. |
| search/SEO | `rg -n 'CSearch|Search\\\\|UpdateSearch|BeforeIndex|OnSearch|SetPageProperty|SetTitle|SET_META|SET_BROWSER_TITLE|SET_CANONICAL_URL|robots|canonical|sitemap|seo' local bitrix/templates www/bitrix/templates www/bitrix/modules/search www/bitrix/modules/seo --glob '*.php'` | Source → component params → template → cache/index/SEO. |
| sale/catalog/currency | `for m in catalog sale currency; do test -f "www/bitrix/modules/$m/install/version.php" && echo "FOUND $m" || echo "MISSING $m"; done` then `rg -n 'Bitrix\\\\Sale|Bitrix\\\\Catalog|Basket|Order|Payment|Shipment|Store|Price|Currency|CCatalog|CSale|CPrice|PRODUCT_ID|OFFER_ID' local bitrix/templates www/bitrix/templates --glob '*.php'` | Commerce API only after module check; no direct SQL for orders/prices/stocks. |
| 1С/CommerceML | `rg -n 'catalog\\.import\\.1c|catalog\\.export\\.1c|sale\\.export\\.1c|BX_CML2|CML2_LINK|XML_ID|checkauth|mode=import|mode=file|mode=init|1c_exchange|CommerceML' . --glob '*.php' --glob '!upload/**' --glob '!bitrix/cache/**'` | Flow `checkauth → init → file → import`, session/cookies, temp files, XML_ID/CML2_LINK, logs. |
| admin/grid | `rg -n 'AdminList|CAdminList|Grid|UI\\\\Buttons|UI\\\\Toolbar|main\\.ui\\.grid|main\\.ui\\.filter' local local/modules bitrix/admin www/bitrix/modules --glob '*.php'` | Rights, grid/filter id, actions, sessid. |

## Мини-формат ответа после grep

1. Факт из проекта: найден файл/параметр/модуль или зафиксировано отсутствие.
2. Bitrix-native route: API/компонент/шаблон/event/controller.
3. Где менять: `local/templates/...`, `local/modules/...`, migration/install step, component params.
4. Что не делать первым: ручной PHP/SQL/правка ядра/global cache-off.
5. Side effects: cache, rights, indexes, SEF, composite, events, agents, sale/catalog recalculations.
