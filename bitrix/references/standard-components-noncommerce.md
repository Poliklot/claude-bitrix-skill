# Standard Components без магазина — справочник

> Reference для Bitrix-скилла. Загружай для задач по stock components и templates текущего core без `catalog`/`sale`.

## Содержание
- Принцип
- Активные component families
- Особая ловушка `catalog.*`
- Где искать template variants
- Что менять
- С чем читать вместе

## Принцип

Стандартный компонент — это контракт. Перед доработкой прочитай его из текущего core:

1. `.parameters.php`;
2. `component.php` или `class.php`;
3. stock `templates/*`;
4. вложенные components в комплексном шаблоне;
5. `result_modifier.php` и `component_epilog.php`, если есть.

## Активные component families

| Семейство | Модуль-владелец | Reference |
|---|---|---|
| `main.*` | `main` | `components.md`, `templates.md`, `users.md`, `grid-admin-modern.md` |
| `iblock.*` | `iblock` | `iblocks.md`, `entities-migrations.md` |
| `highloadblock.*` | `highloadblock` | `highloadblock.md` |
| `form`, `form.result.*` | `form` | `webforms.md` |
| `blog.*` | `blog` | `blog-socialnet.md` |
| `forum.*` | `forum` | `forum.md` |
| `voting.*`, `vote.*` | `vote` | `vote.md` |
| `search.*` | `search` | `search.md` |
| `landing.*` | `landing` | `landing.md` |
| `b24connector.*` | `b24connector` | `b24connector.md` |
| `bitrixcloud.mobile.*` | `bitrixcloud` | `bitrixcloud.md` |
| `messageservice.*` | `messageservice` | `messageservice.md` |
| `fileman.*`, maps/editor fields | `fileman` | `fileman.md`, `location.md` |

## Особая ловушка `catalog.*`

В текущем core `catalog.*` directories есть внутри:

```text
www/bitrix/modules/iblock/install/components/bitrix/catalog*
```

Это означает наличие iblock-based public components, но не наличие модуля `catalog`.

Правило:

- можно разбирать `catalog.section`/`catalog.element` как стандартный компонент из `iblock`;
- нельзя обещать торговый каталог, цены, SKU, остатки, корзину, заказ и checkout без модулей `catalog`/`sale`;
- если пользователь просит магазинную задачу, фиксируй deferred status.

## Где искать template variants

```bash
find www/bitrix/modules/<module>/install/components/bitrix/<component>/templates -maxdepth 2 -type f

find bitrix/templates www/bitrix/templates local/templates -path '*components/bitrix/<component>*' -type f
```

Если `local/templates` отсутствует, смотри `bitrix/templates/.default`, `bitrix/templates/furniture_gray`, `bitrix/templates/landing24` и wizard templates.

## Что менять

| Задача | Слой |
|---|---|
| внешний HTML | copy template |
| подготовка данных | `result_modifier.php` или service |
| meta/breadcrumbs/canonical | `component_epilog.php` |
| параметры выборки | component params и API-layer |
| бизнес-правило | service/module layer |
| кеш | component cache + tagged cache |
| AJAX | controller/action с CSRF/access checks |

## С чем читать вместе

- Components/data flow — [component-dataflow-debugging.md](component-dataflow-debugging.md)
- Templates — [templates.md](templates.md)
- Web forms — [webforms.md](webforms.md)
- Blog/forum/vote — [blog-socialnet.md](blog-socialnet.md), [forum.md](forum.md), [vote.md](vote.md)
- Search/SEO — [search.md](search.md), [seo-cache-access.md](seo-cache-access.md)
