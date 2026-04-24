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
| Composite/static HTML | публичные страницы, персональные блоки | `templates.md` |
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

- Cache primitives — [cache-infra.md](cache-infra.md)
- Components/templates — [components.md](components.md), [templates.md](templates.md)
- Search — [search.md](search.md)
- SEO — [seo-cache-access.md](seo-cache-access.md)
- Operations — [operations-runbook.md](operations-runbook.md)
