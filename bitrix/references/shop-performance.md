# Catalog/sale/shop performance — справочник

> Загружай при задачах “каталог тормозит”, “медленная карточка товара”, “фильтр/фасет медленный”, “корзина/скидки тормозят”, “sale/catalog performance”. Используй только после module check `catalog`, `sale`, `currency`. Для общего аудита сначала [project-optimization-audit.md](project-optimization-audit.md), для контрактов — [catalog.md](catalog.md), [sale.md](sale.md), [shop-standard-components.md](shop-standard-components.md).

## Принцип

Shop performance нельзя оптимизировать в отрыве от side effects:

```text
product/offers/prices/stock → component params/cache/facet → basket/discount/order lifecycle → composite/personal blocks
```

Не меняй `b_catalog_*`/`b_sale_*` прямым SQL ради скорости.

## Быстрый grep

```bash
rg -n 'catalog\.section|catalog\.element|catalog\.smart\.filter|sale\.basket|sale\.order|PRICE_CODE|OFFERS_|SKU|CML2_LINK|AVAILABLE|QUANTITY|DISCOUNT|Basket|Order|Sale\\|Catalog\\|CACHE_TYPE|CACHE_GROUPS|FACET|Facet|clearByTag' \
  local bitrix/templates www/bitrix/templates local/components --glob '*.php'
```

## Catalog list/detail

Проверяй:

- component params: `CACHE_TYPE`, `CACHE_TIME`, `CACHE_GROUPS`, `IBLOCK_ID`, filters;
- `PROPERTY_CODE`, `OFFERS_PROPERTY_CODE`, `PRICE_CODE` — не тащить лишнее;
- stable sort + pagination;
- SKU/offers preload;
- image resize/lazy;
- `catalog.smart.filter` и facet index;
- composite: цены/корзина/избранное/регион не должны замораживаться в static HTML.

## Prices/stock/offers

Красные флаги:

- цена/остаток/доступность пересчитываются в template loop;
- offers грузятся по одному товару;
- user/group/region-specific price попала в общий component/composite cache;
- фильтр по складам/ценам не синхронизирован с cache key;
- `AVAILABLE` трактуется как единственная видимость товара.

## Facet/search/filter

Для медленного фильтра:

1. подтвердить `catalog` module и используемый filter component;
2. проверить facet index status/rebuild policy;
3. проверить `FILTER_NAME` и свойства в фильтре;
4. проверить component cache/facet/search index;
5. runtime: perfmon SQL + page hit time.

Не запускай полный rebuild на production без окна.

## Basket/sale

Красные флаги:

- basket/order/discount calls в цикле вывода карточек;
- персональная корзина/цены в static composite HTML;
- raw SQL по `b_sale_*`;
- пересчёт скидок запускается много раз за один request;
- AJAX cart endpoint без cache/session/composite проверки.

## Safe wins

- Сузить component select/property lists.
- Вынести персональные blocks в dynamic area + `CACHE_TYPE=N` для маленького блока.
- Preload offers/prices/stock одним слоем вместо per-item calls.
- Проверить facet/search indexes перед изменением логики.
- Перенести тяжёлые import/recalculation в stepper/CLI.

## Формат finding

```text
Evidence: catalog.section params тянут все `PROPERTY_CODE` и offers на листинге
Impact: большой `$arResult`, SQL/memory и HTML weight
Fix: оставить только нужные свойства, lazy detail-only данные, проверить cache/facet
Verify: perfmon component/sql, page size, visual parity
```
