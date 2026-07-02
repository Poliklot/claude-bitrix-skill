# Аудит оптимизаций Bitrix-проекта — справочник

> Reference для Bitrix-скилла. Загружай, когда пользователь просит “изучи проект и скажи как оптимизировать”, “найди тормоза”, “какие оптимизации уже есть”, “почему кеш/композит/агенты не помогают”, “проверь производительность”, “составь план ускорения сайта” или “аудит кешей и оптимизаций”. Этот файл задаёт сквозной audit-playbook; для деталей открывай [cache-infra.md](cache-infra.md), [composite-cache.md](composite-cache.md), [perfmon.md](perfmon.md), [components.md](components.md), [templates.md](templates.md), [iblocks.md](iblocks.md), [catalog.md](catalog.md), [sale.md](sale.md), [operations-runbook.md](operations-runbook.md), [seo-cache-access.md](seo-cache-access.md), [pagination.md](pagination.md) и [database-layer.md](database-layer.md).

## Core audit note

Baseline для этого слоя сверен по локальному core `main` 26.150.0 и `perfmon`:

| Core area | Что подтверждать в проекте |
|---|---|
| `Bitrix\Main\Data\Cache`, `CPHPCache` | data/output cache, `baseDir`, `cacheId`, `cacheDir`, TTL, `noOutput`, `cleanDir` |
| `Bitrix\Main\Data\TaggedCache`, managed cache | tag registration, iblock/catalog tags, точечная инвалидация, `b_cache_tag` |
| `CBitrixComponent`, `CBitrixComponentTemplate` | `StartResultCache`, `CACHE_TYPE/TIME/GROUPS`, `setResultCacheKeys`, `setFrameMode`, `createFrame` |
| `Bitrix\Main\Composite\Page`, `AutomaticArea`, `BufferArea` | static HTML, `/bitrix/html_pages/`, dynamic areas, `X-Bitrix-Composite`, `ncc` |
| `perfmon` | SQL/hit/cache/component reports, EXPLAIN/index admin pages |
| `CFile`, image helpers, `clouds` | resize cache, external storage, upload/cache behavior |
| agents/stepper/CLI | тяжёлые операции вне HTTP, batching, resume state |

Если версия core отличается, сначала подтверди локальные классы/админ-страницы. Не обещай оптимизацию, которую нельзя проверить в установленном ядре или проектном коде.

---

## 1. Цель ответа программисту

На запрос “изучи проект и скажи как его можно оптимизировать” отвечай не списком общих советов, а **аудиторским отчётом по фактам проекта**:

```text
1. Что уже оптимизировано и где это видно.
2. Какие оптимизации есть, но реализованы опасно или неполно.
3. Где вероятные bottlenecks: SQL, component/template, cache, composite, images, agents/imports, frontend, shop.
4. Быстрые safe wins без изменения бизнес-логики.
5. Оптимизации, которые требуют runtime/perfmon evidence.
6. Что нельзя менять вслепую.
7. Конкретные файлы/команды проверки.
```

Не начинай с “включите кеш” или “поставьте Redis”. Сначала докажи слой проблемы.

---

## 2. Read-only маршрут аудита

Минимальный порядок:

1. Прочитать `AGENTS.md` и `BITRIX_PROJECT_CONTEXT.md`, если есть.
2. Найти public root и версии модулей.
3. Определить тип проекта: content, corporate, landing, shop, REST-heavy, import-heavy.
4. Снять карту компонентов/шаблонов/cache params.
5. Снять карту custom services/events/agents/steppers/imports.
6. Снять карту composite/cache/index/SEO/image/frontend оптимизаций.
7. Если есть runtime доступ — сопоставить с `perfmon`, логами, headers и slow endpoints.
8. Сформировать отчёт: evidence → impact → safe fix → verification.

Команды должны быть read-only, если пользователь не попросил исправлять.

---

## 3. Быстрый grep-профиль оптимизаций

Запускать из корня проекта, адаптируя `www/`/public root:

```bash
# Components and cache params
rg -n 'IncludeComponent\(|CACHE_TYPE|CACHE_TIME|CACHE_GROUPS|StartResultCache|AbortResultCache|setResultCacheKeys|clearComponentCache|ClearCache' \
  . --glob '*.php' --glob '!upload/**' --glob '!bitrix/cache/**' --glob '!www/bitrix/cache/**'
```

```bash
# Composite and personalization
rg -n 'setFrameMode|COMPOSITE_FRAME_MODE|COMPOSITE_FRAME_TYPE|createFrame|FrameHelper|StaticHtmlCache|Composite\\Page|AutomaticArea|markNonCacheable|USER->IsAuthorized|GetID\(|GetUserGroupArray|FUSER|basket|cart|personal|price' \
  local bitrix/templates www/bitrix/templates --glob '*.php' --glob '*.js'
```

```bash
# SQL/ORM/N+1 candidates in boundary/template code
rg -n 'CIBlockElement::GetList|CIBlockSection::GetList|CUser::GetList|CSale|Catalog\\|Sale\\|DataManager::getList|::getList\(|query\(|SqlQuery|->Query\(|foreach\s*\(|while\s*\(' \
  local bitrix/templates www/bitrix/templates local/components --glob '*.php'
```

```bash
# Heavy logic in templates/result modifiers
rg -n 'GetList|::getList|foreach|while|curl_|file_get_contents|ResizeImageGet|Option::get|Loader::includeModule|IsAuthorized|GetUserGroupArray|AddEventHandler|EventManager' \
  local/templates bitrix/templates www/bitrix/templates local/components --glob 'template.php' --glob 'result_modifier.php' --glob 'component_epilog.php'
```

```bash
# Agents, cron, steppers, imports
rg -n 'CAgent::AddAgent|CAgent::RemoveAgent|Agent|Stepper|bindClass|execAgent|cron|import|exchange|CommerceML|checkauth|init|file|Run\(' \
  local local/php_interface bitrix/php_interface www/bitrix/php_interface --glob '*.php'
```

```bash
# Images/assets/frontend weight
rg -n 'ResizeImageGet|MakeFileArray|CFile::GetPath|upload/resize_cache|addCss|addJs|Asset::getInstance|AddHeadString|<script|<link|loading="lazy"|srcset|webp' \
  local bitrix/templates www/bitrix/templates --glob '*.php' --glob '*.js' --glob '*.css'
```

```bash
# Cache invalidation and dangerous global clears
rg -n 'clearCache\(|clearComponentCache|cleanDir\(|cleanAll\(|clearByTag\(|deleteAll\(|StaticHtmlCache|Composite\\Page|BX_COMP_MANAGED_CACHE|RegisterTag' \
  local bitrix/templates www/bitrix/templates local/components local/modules --glob '*.php'
```

---

## 4. Карта “что уже оптимизировано”

Ищи и фиксируй в отчёте:

| Оптимизация | Признаки в коде/проекте | Что проверить |
|---|---|---|
| Component cache | `CACHE_TYPE=A/Y`, `CACHE_TIME`, `StartResultCache` | cache key учитывает фильтр, сортировку, страницу, пользователя/группы где нужно |
| Tagged cache | `RegisterTag`, `TaggedCache`, iblock/catalog tags | теги регистрируются в той же `cacheDir`, инвалидация точечная |
| Managed cache | `Application::getManagedCache`, module options/ORM metadata | нет глобального `cleanAll()` как штатного действия |
| Composite | `setFrameMode`, `createFrame`, `/bitrix/html_pages/`, headers | персональные блоки вынесены в dynamic areas, second request pass пройден |
| Pagination/lazy | `PAGEN_N`, `NavStart`, `PageNavigation`, AJAX “load more” | stable sort, unique nav id, cache key включает page/sort/filter |
| Images | `CFile::ResizeImageGet`, resize cache, lazy, srcset/webp | нет resize в цикле без cache, размеры реальные, cloud handler учтён |
| Frontend assets | `Asset::addCss/addJs`, bundles, deferred scripts | нет дублей, тяжёлый JS не грузится на всех страницах |
| Agents/stepper/CLI | `CAgent`, `Stepper`, cron/CLI command | тяжёлые задачи не выполняются в hit-mode, есть batching/resume/log |
| Search/facet/SEO | search/facet indexes, sitemap jobs | индекс обновляется после изменений, не rebuild everything без причины |
| Shop caches | catalog/sale cache, facet, prices/stocks | не ломает скидки/остатки/корзину, нет raw SQL для lifecycle сущностей |

Фраза “оптимизация есть” допустима только с указанием файла/параметра/команды подтверждения.

---

## 5. Типовые ошибки оптимизаций

### Component cache

Красные флаги:

- `CACHE_TYPE => 'N'` без комментария и без объективной причины;
- `CACHE_TIME => 0` как постоянная настройка;
- общий cache key для разных фильтров, сортировок, регионов, групп пользователя;
- `CACHE_GROUPS => 'N'` на контенте, зависящем от прав;
- персональные данные попали в `$arResult` и кешируются общим ключом;
- `setResultCacheKeys()` забыли для данных, которые нужны в `component_epilog.php`;
- `AbortResultCache()` не вызывается при пустом/ошибочном результате.

Safe fix pattern:

```text
уточнить arParams/filter/sort/page → стабилизировать cache key → добавить tagged invalidation → проверить first/second hit
```

### Tagged/managed cache

Красные флаги:

- `startTagCache($dir)` и `startDataCache(..., $cacheDir)` используют разные директории;
- `clearByTag()` или `cleanDir()` чистят слишком широкую область;
- после импорта вызывается полный сброс всего кеша вместо tags affected сущностей;
- custom cache не документирует, от каких таблиц/инфоблоков зависит.

### Composite

Красные флаги:

- `setFrameMode(true)` считают dynamic boundary;
- корзина/имя/цены/регион лежат в static HTML;
- `CACHE_TYPE=N` поставили, но dynamic area не создали;
- одинаковые dynamic ids;
- нет проверки guest/user A/user B и `X-Bitrix-Composite`.

Для деталей всегда открывай [composite-cache.md](composite-cache.md).

### SQL/ORM/N+1

Красные флаги:

- `CIBlockElement::GetList()` или ORM `getList()` внутри `foreach` шаблона;
- выбор `*`/всех свойств на списковой странице;
- нет `limit`, `select`, `filter` по индексируемым полям;
- сортировка по неиндексированному/вычисляемому полю на больших таблицах;
- runtime fields без понимания SQL;
- repeated rights/group checks в циклах.

Safe fix pattern:

```text
собрать ids → одним запросом preload → map by id → вывести из памяти → проверить SQL count/time
```

### Templates/frontend

Красные флаги:

- тяжёлая бизнес-логика в `template.php`;
- `ResizeImageGet()` многократно вызывается для одних и тех же файлов без нормального размера/кеша;
- inline `<script>`/`<style>` зависят от пользователя и ломают composite;
- JS/CSS подключаются на всех страницах через `header.php`, хотя нужны одному компоненту;
- нет lazy loading для списков изображений.

### Agents/imports/cron

Красные флаги:

- тяжёлый импорт запускается HTTP-хитом;
- agent делает полный проход без batch limit;
- нет idempotency/external id/resume state;
- после импорта полный cache clear вместо targeted tags;
- лог не различает validation/transport/runtime ошибки.

### Shop/catalog/sale

Красные флаги:

- пересчёт цен/скидок/остатков внутри циклов вывода;
- raw SQL по `b_catalog_*`/`b_sale_*`;
- `catalog.section` тащит лишние свойства/картинки/offers;
- фасет/search index не обновлён после массовых изменений;
- корзина/персональные цены попали в composite static HTML.

---

## 6. Runtime/perfmon evidence

Если есть доступ к стенду, проси или собирай evidence:

| Evidence | Что даёт |
|---|---|
| `X-Bitrix-Composite` headers, `?ncc=1`, second hit | composite работает или маскирует проблему |
| `perfmon_hit_list.php` | самые тяжёлые страницы/хиты |
| `perfmon_sql_list.php` | медленные SQL и повторяющиеся запросы |
| `perfmon_cache_list.php` | эффективность кеша |
| `perfmon_comp_list.php` | тяжёлые компоненты |
| `perfmon_explain.php` / DB `EXPLAIN` | missing index / full scan |
| access logs / application logs | hot URLs, bots, repeated AJAX |
| browser network/lighthouse/web-vitals | frontend/assets bottlenecks |

Без runtime evidence формулируй как “кандидат на оптимизацию”, а не “точно тормозит”.

---

## 7. Ранжирование рекомендаций

В отчёте дели рекомендации:

| Приоритет | Значение | Примеры |
|---|---|---|
| P0 | риск утечки/некорректных данных | персональные данные в composite/component cache |
| P1 | сильный performance win с низким риском | включить корректный component cache, убрать N+1, добавить preload |
| P2 | требует runtime/perfmon проверки | DB index, facet rebuild, CDN/browser cache |
| P3 | cleanup/долг | убрать дубли assets, документировать cache tags |

Для каждого пункта указывай:

```text
Evidence: файл/строка/команда/метрика
Impact: что замедляет или ломает
Fix: минимальное изменение
Risk: что может сломаться
Verify: как проверить после
```

---

## 8. Формат итогового ответа

```text
## Краткий вывод
[2–4 пункта]

## Что уже оптимизировано
- [слой] — evidence: [file/params]

## Ошибки и недоработки оптимизаций
| Приоритет | Место | Проблема | Почему важно | Что сделать | Проверка |

## Быстрые safe wins
1. ...

## Требует runtime/perfmon
1. ...

## Что не трогать вслепую
- ...

## Команды/файлы для следующего прохода
- [bash/rg commands]
- [paths]
```

Если пользователь просит сразу править — сначала согласуй рискованные write/data операции. Code-only правки в репозитории можно готовить патчем, но production cache clear/import/reindex — только после подтверждения.

---

## 9. Что нельзя советовать как первый шаг

- “Отключите весь кеш”.
- “Поставьте Redis/Memcached” без доказательства cache backend bottleneck.
- “Перепишите всё на ORM” или “перепишите всё на SQL”.
- “Очистите `/bitrix/cache` и `/bitrix/html_pages` cron-ом”.
- “Добавьте индекс” без `EXPLAIN`/perfmon/понимания writes.
- “Включите composite” без проверки персонализации.
- “Перенесите тяжёлый код в AJAX” без cache/security/SEO/UX проверки.
- “Запустите полный reindex/rebuild на production” без окна и rollback.

---

## 10. С чем читать вместе

- Кеши и инвалидация — [cache-infra.md](cache-infra.md)
- Composite/static HTML — [composite-cache.md](composite-cache.md)
- Component lifecycle/cache — [components.md](components.md), [templates.md](templates.md)
- Видимость данных и индексы — [index-cache-diagnostics.md](index-cache-diagnostics.md), [seo-cache-access.md](seo-cache-access.md)
- SQL/ORM — [database-layer.md](database-layer.md), [orm.md](orm.md), [iblocks.md](iblocks.md)
- Performance diagnostics — [perfmon.md](perfmon.md)
- Agents/imports/operations — [operations-runbook.md](operations-runbook.md), [update-stepper.md](update-stepper.md), [import-export.md](import-export.md)
- Shop performance — [catalog.md](catalog.md), [sale.md](sale.md), [shop-standard-components.md](shop-standard-components.md)
- Runtime proof — [runtime-smoke-verification.md](runtime-smoke-verification.md)
