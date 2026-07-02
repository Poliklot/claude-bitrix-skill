# Task playbooks

Открывай после `behavior-routing.md` и `project-intake.md`, когда пользователь ждёт конкретное решение, патч или next action. Playbook = найти → понять слой → изменить → проверить.

## Universal flow

```text
1. Найти факт проекта: file, component call, param, module, template.
2. Pick change layer: page property / component params / template / result_modifier / local module / migration.
3. Make minimal patch or give exact next action.
4. Verify side effects: cache, rights, SEO, SEF, composite, events, agents.
```

## Common playbooks

| Task | Find | Change layer | Verify |
|---|---|---|---|
| meta title/description/canonical | `ShowHead`, `ShowTitle`, `SetPageProperty`, `SET_*META*`, `component_epilog` | page/section property, component SEO params, `component_epilog`; not manual meta | component cache, composite, SEO inheritance |
| CSS/JS/head string | `Asset::getInstance`, `addCss`, `addJs`, `addString`, `ShowBodyScripts`, `script.js` | template asset, component `style.css`/`script.js`, Asset | order, duplicates, ajax/composite |
| component/template edit | `IncludeComponent(`, `local/templates/*/components` | params, `template.php`, `result_modifier.php`, `component_epilog.php`, local component/service | cache, `setResultCacheKeys`, ajax mode |
| iblock property missing | `PROPERTY_CODE`, `FIELD_CODE`, `DISPLAY_PROPERTIES`, `PROPERTIES`, `result_modifier` | component params or result modifier; API/ORM after `Loader` | cache, rights, active/date, multiple property, escaping |
| admin has data, site not | `IBLOCK_ID`, filters, sort, pagination, rights/site binding, `result_modifier`, cache | source/params/template/cache/index layer | full chain source → params → template → cache/index |
| 404/redirect | `CHTTP::SetStatus`, `ERROR_404`, `SET_STATUS_404`, `SHOW_404`, `LocalRedirect`, `urlrewrite` | project `404.php`, component strict params, redirect service | HTTP status, SEO, loops, composite |
| form mail | `CEvent::Send`, `Main\\Mail\\Event::send`, `EVENT_NAME`, `SITE_ID`, `CForm`, `check_bitrix_sessid` | form handler/webform/project mail service | event template, site binding, queue/agents/logs |
| ajax | `BX.ajax`, `runComponentAction`, `ajax.php`, `Controller`, `JsonResponse`, `bitrix_sessid` | component action, D7 controller, legacy endpoint with prolog/sessid | CSRF, auth, JSON headers, composite |
| cache/personalization/composite | `CACHE_TYPE`, `CACHE_GROUPS`, `StartResultCache`, `setResultCacheKeys`, `TaggedCache`, `/bitrix/html_pages/`, `X-Bitrix-Composite`, `setFrameMode`, `createFrame` | cache key, managed tag, `setFrameMode` vote/adaptation, `AutomaticArea`/frame type, dynamic boundary, second request/cache pass | no global cache-off first; no `setFrameMode=true` as dynamic |
| аудит оптимизаций проекта | `IncludeComponent`, cache params, `GetList/getList`, `ResizeImageGet`, `Asset`, `CAgent`, `Stepper`, `Composite`, `clearCache` | audit report: existing optimizations, broken/unsafe optimizations, safe wins, runtime/perfmon-needed items | no Redis/CDN/composite/global clear without evidence |
| shop/catalog/sale | module check for `catalog`, `sale`, `currency` | catalog/sale/currency API, shop component params | events, recalc, discounts, reserves, order errors |
| 1C/CommerceML | `catalog.import.1c`, `sale.export.1c`, `checkauth`, `mode=file`, `mode=import`, `XML_ID`, `CML2_LINK` | exchange settings/logs/import flow | upload is not import success |
| custom logic | `local/modules`, `ServiceLocator`, `EventManager`, autoload | local module/service/migration/event/controller | idempotency, rollback, tooling, smoke |

## Answer format

```text
Проверил: [факт проекта/path].
Причина/слой: [why].
Делаю/предлагаю: [patch or next action].
Проверить после: [cache/status/page/test].
Риски: [side effects].
```
