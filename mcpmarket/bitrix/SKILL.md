---
name: bitrix
description: >-
  Core-first Bitrix / 1C-Bitrix / Битрикс / БУС / boxed Bitrix24 expertise. Use when
  a task mentions or a repo contains Bitrix markers: `www/bitrix`, `/bitrix`, `/local`,
  `bitrix/modules`, components/templates, `CIBlock*`, `CUser`, `CModule`, `Loader::includeModule`,
  `Bitrix\Main`, D7, legacy `C*`, инфоблоки/iblock, HL/highloadblock, UF. Use for Bitrix PHP
  inspection, debugging, changes, migrations, integrations, optimization, testing, security and operations;
  for meta title/description, `ShowHead`, `ShowTitle`, assets,
  breadcrumbs, includes, `.section.php`, project layout, `.env`/`Option`, stable entity IDs, current user; for production best practices, pitfalls,
  cache/index/SEO/search/perf optimization audits; and for shop/1C/REST:
  `catalog`, `sale`, `currency`, SKU/offers, prices, stocks, basket/cart, orders, payments, delivery,
  discounts, marketing/mail/SMS, bizproc/workflow, webhooks, sale/catalog REST, 1C/CommerceML. Inspect
  local core and `local/*`; missing optional modules are deferred.
metadata:
  author: poliklot
  version: "1.35.0"
---

# Bitrix Expert Skill — MCP Market Edition

MCP Market compact read-only import; full lifecycle edition lives in `bitrix/`.

Эксперт по 1C-Bitrix CMS. Работаешь **core-first**: сначала проверяешь установленное ядро, стандартные компоненты, stock templates и проектные `local/*`-оверрайды, потом предлагаешь решение. Если в проекте есть `BITRIX_PROJECT_CONTEXT.md`, читай его после `AGENTS.md` как сохранённый снимок проекта.

Эта папка — компактная версия для MCP Market. Она намеренно не содержит `update.sh`, `install.sh`, `uninstall.sh` и 80+ отдельных reference-файлов, потому что MCP Market ограничивает импортируемую skill-папку 50 файлами. Полная lifecycle-версия находится в `bitrix/` основного репозитория.

## Текущая фаза

Активным маршрутом считай только то, что подтверждается реально установленным ядром проекта. Для non-commerce core рабочий слой: `main`, `iblock`, `highloadblock`, `photogallery`, `blog`, `forum`, `vote`, `form`, `landing`, `bitrix.sitecorporate`, `socialservices`, `b24connector`, `mobileapp`, `clouds`, `bitrixcloud`, `security`, `fileman`, `location`, `messageservice`, `translate`, `rest`, `search`, `seo`, `subscribe`, `ui`, `perfmon`, проектные `local/*`-оверрайды.

Если в локальном проекте подтверждены `catalog`, `sale` и `currency`, активируй shop route: товары, SKU/offers, цены, остатки, склады, корзина, checkout, заказы, оплаты, доставки, скидки, marketing/analytics, automation/bizproc, webservice/REST integration extras и 1С/CommerceML. Если модулей нет — не выдумывай commerce API.

## Источник истины

1. `www/bitrix/modules/<module>/install/version.php`
2. `www/bitrix/modules/<module>/lib/`
3. `www/bitrix/modules/<module>/install/components/bitrix/<component>/`
4. `local/components`, `local/templates`, `bitrix/templates`
5. `local/php_interface`, `local/modules`, `urlrewrite.php`

Для `main` допускай `www/bitrix/modules/main/classes/general/version.php`, если `install/version.php` отсутствует.

## Быстрые проверки ядра

```bash
find www/bitrix/modules -maxdepth 1 -mindepth 1 -type d | sort
for m in main iblock currency catalog sale; do
  test -f "www/bitrix/modules/$m/install/version.php" && sed -n '1,40p' "www/bitrix/modules/$m/install/version.php"
done
```

```php
use Bitrix\Main\Loader;

foreach (['iblock'] as $module) {
    if (!Loader::includeModule($module)) {
        throw new \RuntimeException("Module {$module} is not installed");
    }
}
```

## Рабочий алгоритм

1. Сначала выбери режим по [references/behavior-routing.md](references/behavior-routing.md): бытовой ответ, проектная правка, диагностическая цепочка, component/template, production practice, module-dependent, shop/1C, data mutation или release.
2. Если задача про конкретный repo (“у нас”, “найди”, “почини”, “почему не работает”), сначала прочитай `BITRIX_PROJECT_CONTEXT.md`, если он есть в корне проекта, затем пройди [references/project-intake.md](references/project-intake.md) или узкий grep из [references/core-grep-cookbook.md](references/core-grep-cookbook.md). Для структуры/include открой [references/project-layout-and-includes.md](references/project-layout-and-includes.md), для `.env`/`Option`/ID — [references/project-configuration.md](references/project-configuration.md). После полного аудита проекта создай/обнови `BITRIX_PROJECT_CONTEXT.md` по [assets/BITRIX_PROJECT_CONTEXT.template.md](assets/BITRIX_PROJECT_CONTEXT.template.md).
3. Определи домен задачи: project layout/includes, configuration/IDs, content, component, PHP-heavy, search/SEO/cache, ops, shop или 1С.
4. Проверь наличие нужных модулей и стандартных компонентов в конкретном ядре; при version mismatch открой [references/version-impact.md](references/version-impact.md).
5. Посмотри проектные оверрайды и glue-code в `local/`.
6. Для коротких вопросов “как в PHP сделать X” сначала загрузи [references/developer-primitives.md](references/developer-primitives.md), [references/first-answer-pitfalls.md](references/first-answer-pitfalls.md), затем [references/developer-cards.md](references/developer-cards.md) и [references/answer-contracts.md](references/answer-contracts.md); если нужен быстрый grep по проекту — [references/core-grep-cookbook.md](references/core-grep-cookbook.md), затем минимальный релевантный compact bundle из `references/`.
7. Выбери слой изменения: migration, service, event handler, component, template, agent, CLI. Для “best practices”, “подводные камни” или “покрыто/production-ready” сначала читай production/pitfalls/runtime sections в bundles.
8. Проговори side effects: cache, indexes, rights, SEF, background processes, sale/order/exchange effects.
9. Если меняются реальные данные, сначала сделай изменение воспроизводимым и обратимым.

## Подтверждение перед изменением данных

Подтверждение обязательно перед прямыми изменениями в БД, контенте, правах, файловом хранилище или админке, если это не просто подготовка кода в репозитории.

```text
Собираюсь выполнить:
  Операция: [создание / изменение / удаление]
  Объект: [что именно]
  Что изменится: [данные / файлы / права / индексы / кеш]
  Обратимость: [обратимо / необратимо]
Продолжить?
```

## Навигация по compact reference bundles

Если неясно, какой bundle нужен, открой [references/reference-map.md](references/reference-map.md) после выбора режима.

| Домен | Bundle |
|---|---|
| Режимы работы, аудит проекта, сохранённый `BITRIX_PROJECT_CONTEXT.md` и бытовые вопросы разработчика: meta/title/head, CSS/JS, includes, components, breadcrumbs, request/current user, URL, Loader, 404/redirect, images, iblock properties, cache, mail | [references/behavior-routing.md](references/behavior-routing.md), [references/project-intake.md](references/project-intake.md), [assets/BITRIX_PROJECT_CONTEXT.template.md](assets/BITRIX_PROJECT_CONTEXT.template.md), [references/task-playbooks.md](references/task-playbooks.md), [references/developer-primitives.md](references/developer-primitives.md), [references/first-answer-pitfalls.md](references/first-answer-pitfalls.md), [references/developer-cards.md](references/developer-cards.md), answer format — [references/answer-contracts.md](references/answer-contracts.md), grep по проекту — [references/core-grep-cookbook.md](references/core-grep-cookbook.md); quality gate — [references/eval-prompts.md](references/eval-prompts.md), release gate — [references/release-gate.md](references/release-gate.md) |
| Public root/`.section.php`/header/footer/includes и `.env`/`Option`/stable IDs | [references/project-layout-and-includes.md](references/project-layout-and-includes.md), [references/project-configuration.md](references/project-configuration.md), [references/project-intake.md](references/project-intake.md) |
| Audit текущего core, version mismatch, tail modules, full shop-core inventory, non-commerce/shop task routing, visibility/cache/dataflow diagnostics, pitfalls matrix, runtime smoke verification | [references/core-routing.md](references/core-routing.md), [references/version-impact.md](references/version-impact.md), [references/shop-core-tail-modules.md](references/shop-core-tail-modules.md) |
| PHP workflow, testing, quality, production best practices, legacy modernization, modules, ORM, DB, events, validation, HTTP | [references/php-architecture.md](references/php-architecture.md) |
| ИБ, HL, UF, migrations, import/export, SEF | [references/content-data.md](references/content-data.md) |
| Components, templates, pagination, admin UI, modern grid, file uploader, numerators, user consent | [references/components-admin-ui.md](references/components-admin-ui.md) |
| Users, RBAC, auth/session, security, socialservices | [references/users-security.md](references/users-security.md) |
| Blog, forum, vote, webforms, mail, subscribe | [references/content-modules.md](references/content-modules.md) |
| Landing, sitecorporate, photogallery, fileman, location, messageservice, clouds, bitrixcloud, mobileapp, b24connector, translate | [references/site-cloud-mobile.md](references/site-cloud-mobile.md), [references/shop-core-tail-modules.md](references/shop-core-tail-modules.md) |
| Search, SEO, cache/composite infra, аудит оптимизаций, DB/ORM/N+1, frontend/images/assets, agents/imports, update stepper, perfmon, operations | [references/search-seo-ops.md](references/search-seo-ops.md); for component/template bottlenecks also [references/components-admin-ui.md](references/components-admin-ui.md), for composite dynamic/personal blocks also [references/users-security.md](references/users-security.md), for shop/catalog/sale bottlenecks also [references/commerce-shop.md](references/commerce-shop.md) |
| REST integration | [references/integrations-rest.md](references/integrations-rest.md) |
| Commerce/shop: catalog, sale, currency, standard shop components, StoreAssist, marketing/analytics, automation/bizproc, webservice/SOAP, sale/catalog REST, workflow/lists/pull, 1С/CommerceML | [references/commerce-shop.md](references/commerce-shop.md) |

## Content-first эвристики

- Не опирайся на память, если код можно подтвердить в установленном ядре; при отличии версии от baseline используй `version-impact.md`.
- Для “как вставить meta title/description” не предлагай ручной `<meta>` как первый шаг: проверь `$APPLICATION->ShowHead()` и `<title><?php $APPLICATION->ShowTitle(); ?></title>`, затем свойства страницы/раздела, SEO-параметры компонента, `SetTitle`/`SetPageProperty`.
- Не принимай `composer.json` и `phpunit.xml.dist` внутри `www/bitrix/modules/*/vendor` за tooling проекта.
- Для задач “как правильно”, “best practices”, “куда класть код”, “подводные камни” или “можно ли считать покрытым” сначала открывай соответствующий compact bundle: `php-architecture.md` для production practices и `core-routing.md` для pitfalls/runtime smoke.
- Для `header.php`/`footer.php`/`.section.php`/include сначала открывай `project-layout-and-includes.md`; для `.env`/`Option`/numeric ID — `project-configuration.md`. Не навязывай `/include`, Composer или lookup только по `CODE` без project facts.
- Для задач “в админке есть, на сайте нет” иди по цепочке: data source → permissions/site binding → component params → filters → pagination/sort → `result_modifier.php` → template → component/tagged/composite cache → index/SEO.
- Наличие `catalog.*` в `iblock` или templates не доказывает установленный commerce core; для public shop components открывай commerce bundle с `shop-standard-components.md`.
- Для shop-задач сначала подтверждай `catalog`, `sale`, `currency`; затем разделяй product, offer, price, stock, basket, order, marketing/analytics и exchange side effects.
- Для вопросов полного покрытия shop-core сначала смотри inventory bundle и runtime smoke section: standard shop components, marketing/analytics, automation и webservice/REST уже покрыты code-first, но не обещай runtime pass без Docker/runtime проверки.
- Для задач про рассылки, подписки, SMS, баннеры, A/B, conversion, reports или statistic открывай commerce bundle с `shop-marketing-analytics.md`; не смешивай `sender.subscribe`, `subscribe.*` и `catalog.product.subscribe`.
- Для задач про БП, роботов, задания, процессы в списках или realtime открывай commerce bundle с `shop-automation-bizproc.md`; не обещай sale-order robots без локального provider-а/CRM/custom module.
- Для задач про `webservice.sale`, `webservice.statistic`, SOAP/WSDL, REST sale/catalog events, placements или external app handlers открывай commerce bundle с `shop-integrations-webservice.md`; не смешивай это с 1С CommerceML.
- Для 1С задач проверяй `checkauth → init → file → import`, cookies/session, `sessid`, temp files, XML_ID/CML2_LINK и exchange logs.
- Если задача про StoreAssist или `storeassist_1c_*`, помни: это мастер/чеклист и onboarding, а не exchange engine.
- Для пагинации разводи legacy `PAGEN_N`/`NavStart()` и D7 `PageNavigation`: проверяй unique nav id, count/filter, stable sort, cache key, ajax payload и composite second request/cache pass.
- Не меняй order/basket/payment/shipment/catalog price/stock прямым SQL, если есть API и side effects.
- Не подключай production 1С, реальные платежи, доставки или кассы для smoke без явного подтверждения.
- Не говори “весь core полностью production-проверен”, если нет sandbox/fixtures smoke evidence.
