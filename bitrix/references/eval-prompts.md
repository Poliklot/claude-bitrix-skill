# Eval-набор бытовых Bitrix-запросов

Используй этот файл при доработке скилла и перед релизом бытового слоя. Цель — проверить, что агент выбирает Bitrix-native маршрут, не начинает с анти-паттерна и открывает правильные references.

## Как прогонять вручную

Для каждого prompt оцени ответ по 3 критериям:

1. **Route:** агент открыл/использовал правильный reference (`developer-primitives.md`, `first-answer-pitfalls.md`, `developer-cards.md` и доменный файл).
2. **No bad first step:** агент не начал с запрещённого анти-паттерна.
3. **Useful answer:** ответ коротко следует [answer-contracts.md](answer-contracts.md): даёт штатный механизм, где проверить в проекте, минимальный пример или grep из [core-grep-cookbook.md](core-grep-cookbook.md), и 1–3 side effects.

Оценка:

- `pass` — все 3 критерия выполнены.
- `warn` — ответ правильный, но слишком общий или не указал где проверить.
- `fail` — ответ начал с чистого PHP/SQL/правки ядра/глобального отключения кеша или придумал API.

Минимальный regression gate перед релизом: прогнать 15 любых prompt из разных доменов, `fail = 0`; полный pre-release checklist — в [release-gate.md](release-gate.md).

## Core prompts

| ID | Prompt | Expected references | Must say | Must not say first |
|---|---|---|---|---|
| B001 | Как в PHP поставить meta title в Битриксе? | `developer-primitives`, `first-answer-pitfalls`, `developer-cards`, `templates`, `seo-cache-access` | `ShowHead`/`ShowTitle`, `SetPageProperty('title')`, свойства страницы/SEO компонента, проверить `header.php` | “вставь `<meta name="title">` руками” |
| B002 | Где менять meta description для страницы? | `developer-primitives`, `developer-cards`, `templates`, `seo-cache-access` | свойства страницы/раздела, `SetPageProperty('description')`, SEO инфоблока/компонента | ручной meta в каждом файле |
| B003 | Как добавить canonical на детальной странице каталога? | `developer-primitives`, `developer-cards`, `shop-standard-components` если commerce подтверждён, `seo-cache-access` | `SetPageProperty('canonical')`, `SET_CANONICAL_URL`, проверить компонент и `component_epilog` | правка ядра catalog component |
| B004 | Как подключить CSS в шаблоне сайта? | `developer-primitives`, `first-answer-pitfalls`, `developer-cards`, `templates` | `Asset::addCss`, `template_styles.css`, `ShowHead` | echo `<link>` из компонента |
| B005 | Как подключить JS в компоненте? | `developer-primitives`, `developer-cards`, `templates`, `components` | `Asset::addJs` или `script.js` шаблона компонента, проверить `ShowBodyScripts` | inline script без причины |
| B006 | Как добавить OpenGraph meta? | `developer-primitives`, `developer-cards`, `seo-cache-access` | `AddHeadString`/`Asset::addString`, экранирование, `ShowHead` | ручной echo в середине body |
| B007 | Как сделать редактируемый текст в футере? | `developer-primitives`, `developer-cards`, `templates` | `IncludeFile`, include area, `SITE_DIR`, права | хардкод строки в шаблоне |
| B008 | Как вывести включаемую область? | `developer-primitives`, `developer-cards`, `templates` | `$APPLICATION->IncludeFile(...)`, MODE/html/text, права | создать свой mini-CMS |
| B009 | Как добавить хлебную крошку? | `developer-primitives`, `developer-cards`, `templates`, `components` | `AddChainItem`, `bitrix:breadcrumb`, параметры `ADD_*_CHAIN` | ручной HTML breadcrumbs |
| B010 | Почему хлебные крошки дублируются? | `developer-cards`, `components`, `shop-standard-components` if relevant | проверить `ADD_SECTIONS_CHAIN`, `ADD_ELEMENT_CHAIN`, `AddChainItem`, `component_epilog` | “очисти весь кеш” как первый ответ |
| B011 | Как получить текущего пользователя? | `developer-primitives`, `first-answer-pitfalls`, `developer-cards`, `users`, `access-rbac` | `global $USER`, `IsAuthorized`, `GetID`, права/группы | читать `$_SESSION` напрямую |
| B012 | Как показать блок только авторизованным? | `developer-cards`, `users`, `access-rbac`, `cache-infra` | `$USER->IsAuthorized()`, composite/personalized cache caveat | закешировать персональный HTML без frame |
| B013 | Как получить GET-параметр? | `developer-primitives`, `developer-cards`, `http`, `security` | `Context::getCurrent()->getRequest()`, фильтрация | сырой `$_REQUEST` без фильтрации |
| B014 | Как обработать POST-форму? | `developer-cards`, `security`, `webforms`, `http` | request, `check_bitrix_sessid`, validation, webform/project form layer | POST без CSRF |
| B015 | Как добавить параметр к текущему URL? | `developer-primitives`, `developer-cards`, `sef-urls`, `pagination` | `GetCurPageParam`, исключить старый параметр, SEF/canonical caveat | конкатенация `REQUEST_URI` |
| B016 | Как подключить модуль iblock? | `developer-primitives`, `developer-cards`, `modules-loader`, `iblocks` | `Loader::includeModule('iblock')`, обработать false, проверить module dir | сразу `CIBlockElement::GetList` без include |
| B017 | Как понять, установлен ли sale? | `developer-cards`, `core-audit-matrix`, `shop-task-matrix` | проверить `www/bitrix/modules/sale/install/version.php`, `Loader::includeModule('sale')` | обещать sale API без проверки |
| B018 | Как сделать 404 в компоненте? | `developer-cards`, `sef-urls`, `components`, `seo-cache-access` | `CHTTP::SetStatus`, `ERROR_404`, проектный `404.php`, strict checks | `echo '404'` |
| B019 | Страница не найдена, но отдаёт 200 — что делать? | `developer-cards`, `seo-cache-access`, `sef-urls`, `components` | проверить status, `ERROR_404`, component not found handling, routing | редирект на главную как универсальное решение |
| B020 | Как сделать редирект после отправки формы? | `developer-cards`, `http`, `security` | `LocalRedirect`, до вывода, validate URL, sessid | echo JS redirect первым вариантом |
| B021 | Как вывести картинку элемента инфоблока? | `developer-cards`, `iblocks`, `file-upload-modern` | `CFile::GetPath`/`ResizeImageGet`, `PREVIEW_PICTURE`/`DETAIL_PICTURE` | ручной `/upload/...` без проверки |
| B022 | Как сделать превью картинки? | `developer-cards`, `file-upload-modern`, `clouds` | `CFile::ResizeImageGet`, resize cache, dimensions | HTML width/height как resize |
| B023 | Как вывести свойство инфоблока в шаблоне? | `developer-cards`, `iblocks`, `components` | `PROPERTY_CODE`, `$arResult['PROPERTIES']`/`DISPLAY_PROPERTIES`, `result_modifier` | SQL в property table |
| B024 | Почему свойство инфоблока пустое в шаблоне? | `developer-cards`, `iblocks`, `component-dataflow-debugging` | проверить параметры компонента, код свойства, кеш, result_modifier | “свойства всегда есть в arResult” |
| B025 | Почему изменения в компоненте не видны? | `developer-cards`, `cache-infra`, `component-dataflow-debugging`, `composite-cache` | component cache, template cache, managed/tagged cache, composite static HTML, `X-Bitrix-Composite`, second request/cache pass | выключить весь кеш первым ответом |
| B026 | Как кешировать свой компонент? | `developer-cards`, `components`, `cache-infra`, `composite-cache` | `StartResultCache`, `AbortResultCache`, `setResultCacheKeys`, cache keys, отличие component cache от composite | кешировать USER_ID без caveat |
| B027 | Почему пользователь видит данные другого пользователя? | `developer-cards`, `cache-infra`, `security`, `composite-cache` | персонализация, `CACHE_GROUPS`, component cache key, `createFrame`/`FrameHelper`, `/bitrix/html_pages/`, очистка утечки | “очисти кеш” без root cause |
| B028 | Как отправить письмо? | `developer-cards`, `mail-notifications`, `webforms` | почтовое событие/шаблон, `CEvent::Send`/`Main\Mail\Event::send` | `mail()` как основной путь |
| B029 | Форма не отправляет письмо — где смотреть? | `developer-cards`, `webforms`, `mail-notifications`, `operations-runbook` | event name, template, SITE_ID, queue/agents, logs | “SMTP сломан” без проверки Bitrix events |
| B030 | Как сделать AJAX в компоненте? | `developer-cards`, `components`, `http`, `security` | project ajax pattern, sessid, JSON response, composite | endpoint без prolog/sessid |
| B031 | Как добавить обработчик события? | `developer-cards`, `events-routing`, `modules-loader` | `EventManager`, local module/php_interface, idempotent install | код в template.php |
| B032 | Где писать кастомный класс? | `production-best-practices`, `modules-loader`, `php-workflow` | `local/modules`/project namespace, composer if present, autoload | правка ядра/main classes |
| B033 | Как добавить агента? | `operations-runbook`, `update-stepper`, `modules-loader` | `CAgent`/project scheduler, idempotency, logging | cron без учёта Bitrix agents |
| B034 | Как очистить кеш после обновления инфоблока? | `cache-infra`, `iblocks`, `events-routing` | tagged cache/managed cache, precise invalidation | удалить весь `/bitrix/cache` первым вариантом |
| B035 | Как получить путь к ресурсу шаблона компонента? | `templates`, `components` | `$this->GetFolder()`, document root for server path | несуществующий `$this->GetTemplatePath()` без проверки |
| B036 | Как добавить кнопку в админке списка? | `admin-ui`, `grid-admin-modern` | modern grid/admin UI pattern, rights, modules | inline HTML hack без прав |
| B037 | Как сделать пагинацию списка? | `pagination`, `components`, `iblocks` | `PageNavigation` or `NavStart`, unique nav id, count/stable sort | ручной `LIMIT` без nav state |
| B038 | Почему вторая страница каталога пустая? | `pagination`, `shop-standard-components`, `component-dataflow-debugging` | filter/count/sort/cache/nav id, smart filter params | “увеличь page size” без диагностики |
| B039 | Как получить текущий сайт/SITE_ID? | `developer-primitives`, `modules-loader`, `templates` | `SITE_ID`, `SITE_DIR`, context/site caveat | hardcode `/` или домен |
| B040 | Как добавить lang-фразу? | `developer-cards`, `translate`, `modules-loader` | `Loc::getMessage`, lang files, `loadMessages` if needed | hardcoded Russian in reusable module |
| B041 | Как добавить пользовательское поле? | `custom-uf-types`, `iblock-hl-relations`, `entities-migrations` | UF API/migration, entity id, type, settings | вручную менять DB table |
| B042 | Как сделать HL-блок справочник? | `highloadblock`, `custom-uf-types`, `entities-migrations` | module check, HL API, migrations, rights | raw table without HL entity |
| B043 | Как обновить цену товара? | `shop-task-matrix`, `catalog`, `currency` after module check | catalog API, price type/currency, side effects | SQL в price tables |
| B044 | Как поменять статус заказа? | `sale`, `commerce-workflows` after module check | sale API/order save, events, payments/shipments side effects | SQL в order table |
| B045 | Как списать остаток? | `catalog`, `sale`, `commerce-workflows` after module check | catalog/store API, documents/reservation policy | прямой UPDATE количества |
| B046 | Как настроить обмен 1С? | `commerce-1c-integration`, `operations-runbook` after module check | checkauth/init/file/import flow, logs, XML_ID/CML2_LINK | “просто загрузи XML” |
| B047 | Почему товар из 1С есть в админке, но не на сайте? | `pitfalls-matrix`, `diagnostic-visibility`, `commerce-1c-integration`, `catalog` | active/date/site binding/section/price/stock/permissions/cache | “очисти кеш” only |
| B048 | Как добавить REST webhook? | `rest`, `http`, `security` | app/webhook scopes, auth, events, permissions | store token in public template |
| B049 | Как сделать robots noindex для страницы? | `seo-cache-access`, `developer-cards` | `SetPageProperty('robots','noindex, nofollow')`, `ShowHead`, page/component layer | hardcoded meta everywhere |
| B050 | Как проверить, можно ли идти в catalog/sale? | `core-audit-matrix`, `shop-task-matrix`, `shop-core-module-inventory` | inspect modules `catalog`, `sale`, `currency`, versions, components | assume shop because `catalog.*` template exists |
| B051 | Сделай аудит проекта и обнови BITRIX_PROJECT_CONTEXT.md | `behavior-routing`, `project-intake`, `core-grep-cookbook`, `BITRIX_PROJECT_CONTEXT.template` | запустить быстрый аудит из корня проекта, собрать public root/modules/templates/local/events/tooling, создать/обновить файл без secrets | начать с общих советов без чтения проекта |
| B052 | В проекте уже есть BITRIX_PROJECT_CONTEXT.md — что читать перед правкой? | `project-intake`, `answer-contracts`, `core-grep-cookbook` | сначала `AGENTS.md`, затем `BITRIX_PROJECT_CONTEXT.md`, потом перепроверить рискованные факты в текущем коде | верить снимку проекта вслепую |
| B053 | Можно ли считать магазинный маршрут runtime-проверенным? | `runtime-smoke-verification`, `shop-task-matrix`, `release-gate` | code-first ≠ runtime pass; нужны P1–P4 evidence и `validate_runtime_evidence.py` | сказать “да, покрыто справочником” |
| B054 | Запусти P1 smoke, но безопасного write sandbox нет | `runtime-smoke-verification`, `shop-task-matrix` | read-only можно, P1-05–P1-07 отметить `blocked`; не fake pass | запускать заказ/оплату на production |
| B055 | Нужно проверить CommerceML без production 1С | `runtime-smoke-verification`, `commerce-1c-integration` | использовать P2 fixtures/stub, запрет real credentials, blocked если нет sandbox endpoint | подключить реальную 1С |
| B056 | REST webhook есть, но scopes неизвестны | `runtime-smoke-verification`, `shop-integrations-webservice`, `rest` | P3 method discovery, missing-scope negative, masked tokens | сохранить токен в evidence |
| B057 | Evidence pack готов, как проверить перед релизом? | `release-gate`, `runtime-smoke-verification` | `python3 scripts/validate_runtime_evidence.py ... --package P1`, проверить summary/scenarios/secrets | принять папку без validation |
| B058 | Как правильно подготовить компонент к композитному кешу? | `components`, `templates`, `composite-cache` | `setFrameMode(true)` = голосование, персональные части через `createFrame`, dynamic areas не вкладывать, verification по headers | сказать что `setFrameMode(true)` делает компонент динамическим |
| B059 | Корзина/имя пользователя моргает или показывает чужие данные при композите | `developer-cards`, `security`, `composite-cache`, `cache-infra` | dynamic area с безопасной заглушкой, `CACHE_TYPE=N` для персонального блока, проверить guest/user A/user B, `X-Bitrix-Composite` | просто очистить весь кеш |
| B060 | Изучи Bitrix-проект и скажи, как его можно оптимизировать и какие оптимизации уже сломаны | `project-optimization-audit`, `core-grep-cookbook`, `perfmon`, `cache-infra`, `components` | audit-report: что уже оптимизировано, ошибки cache/composite/N+1/images/agents, safe wins, что требует runtime/perfmon evidence | сразу советовать Redis/CDN/очистку всего кеша без чтения проекта |

## Expected answer skeletons

### Short “how to” answer

```text
В Битриксе это обычно делается через [штатный механизм], а не через [анти-паттерн].
Проверь: [paths/params/grep].
Минимальный пример:
[code]
Учти: [side effects].
```

### Debug answer

```text
Иди по цепочке: [source] → [component params] → [template/result_modifier] → [cache/index/rights].
Проверки:
[commands/paths]
Не начинай с [bad first step], пока не проверены [facts].
```

### Module-dependent answer

```text
Сначала подтвердить модуль в `www/bitrix/modules/<module>` и `Loader::includeModule(...)`.
Если модуль есть: [API route].
Если нет: [fallback/deferred].
```
