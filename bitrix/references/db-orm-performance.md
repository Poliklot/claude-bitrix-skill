# DB/ORM/IBlock performance — справочник

> Загружай при задачах “медленные SQL”, “N+1”, “тормозит список/деталка”, “оптимизировать `CIBlockElement::GetList`/ORM”, “нужен индекс”, “perfmon SQL”. Для общего аудита сначала [project-optimization-audit.md](project-optimization-audit.md), для API данных — [iblocks.md](iblocks.md), [orm.md](orm.md), [database-layer.md](database-layer.md), для runtime — [perfmon.md](perfmon.md).

## Принцип

Оптимизация DB в Bitrix начинается не с индекса и не с raw SQL, а с цепочки:

```text
hot page → perfmon/SQL evidence → конкретный component/template/service → select/filter/order/limit/cache → preload/batch → EXPLAIN/index только после подтверждения
```

Без runtime evidence формулируй “кандидат на оптимизацию”, а не “точно тормозит”.

## Быстрый grep

```bash
rg -n 'CIBlockElement::GetList|CIBlockSection::GetList|CUser::GetList|::getList\(|DataManager::getList|runtime|ExpressionField|ReferenceField|query\(|SqlQuery|->Query\(|SELECT \*|PROPERTY_CODE|FIELD_CODE|CACHE_TYPE|CACHE_TIME' \
  local local/components local/templates bitrix/templates www/bitrix/templates --glob '*.php'
```

```bash
rg -n 'foreach\s*\(|while\s*\(|GetList|::getList|Option::get|Loader::includeModule|GetUserGroupArray|IsAuthorized' \
  local/templates bitrix/templates www/bitrix/templates local/components \
  --glob 'template.php' --glob 'result_modifier.php' --glob 'component_epilog.php'
```

## IBlock `GetList` checklist

Проверяй:

- `IBLOCK_ID`, `ACTIVE`, `ACTIVE_DATE`, `CHECK_DATES`, site/section filter;
- `SORT` стабильный и индексируемый, особенно с pagination;
- `arSelect`/`FIELD_CODE`/`PROPERTY_CODE` не тащит всё;
- `nTopCount`/`NavStart`/component pagination вместо полного массива;
- `CACHE_TYPE/TIME/GROUPS`, tagged cache и инвалидация;
- свойства нужны в списке или только на detail;
- нет `GetNextElement()->GetProperties()` в цикле без причины.

Плохо:

```php
foreach ($items as $item) {
    $res = CIBlockElement::GetList([], ['ID' => $item['ID']], false, false, ['*']);
}
```

Лучше:

```php
$ids = array_column($items, 'ID');
$rows = [];
$res = CIBlockElement::GetList(
    [],
    ['ID' => $ids, 'IBLOCK_ID' => $iblockId],
    false,
    false,
    ['ID', 'IBLOCK_ID', 'NAME', 'PROPERTY_ARTICLE']
);
while ($row = $res->Fetch()) {
    $rows[(int)$row['ID']] = $row;
}
```

## ORM checklist

Для `DataManager::getList()`:

- всегда задавай узкий `select`;
- задавай `filter` по полям, для которых есть индекс/логичная селективность;
- не сортируй большие выборки по вычисляемому полю без evidence;
- добавляй `limit`/pagination;
- runtime fields проверяй через SQL/EXPLAIN;
- не вызывай `getList()` внутри шаблона/цикла.

```php
$result = ElementTable::getList([
    'select' => ['ID', 'NAME', 'IBLOCK_ID'],
    'filter' => ['=IBLOCK_ID' => $iblockId, '=ACTIVE' => 'Y'],
    'order'  => ['SORT' => 'ASC', 'ID' => 'ASC'],
    'limit'  => 50,
]);
```

## N+1 patterns

Красные флаги:

- `GetList/getList` внутри `foreach`;
- `Option::get`, `Loader::includeModule`, права/группы в каждом элементе;
- `ResizeImageGet` на одни и те же файлы без подготовленного map;
- sale/catalog price/stock/discount calls в цикле карточек;
- template делает data access вместо вывода.

Safe pattern:

```text
collect ids → one query/preload → map by id → render from memory → measure SQL count/time
```

## EXPLAIN и индексы

Индекс предлагай только если есть:

1. конкретный slow SQL или hot page;
2. `EXPLAIN`/perfmon evidence;
3. понимание write-side effects;
4. rollback plan.

Не добавляй индекс “на всякий случай” на production. Для Bitrix core tables сначала проверь штатные индексы и module migrations; для custom tables — migration/install step.

## Формат finding

```text
Evidence: local/templates/.../template.php:42 вызывает GetList внутри foreach
Impact: кандидат на N+1; без perfmon не утверждаем точное время
Fix: перенести в component/service, собрать IDs, preload одним запросом
Verify: perfmon_sql_list до/после, SQL count/time, page output parity
```

## Gotchas

- `CACHE_TYPE=N` может скрывать DB-проблему, но не является её причиной само по себе.
- `select => ['*']` не всегда баг на маленькой админской операции, но красный флаг на public lists.
- Прямой SQL для чтения допустим только как осознанный reporting/repair layer; для business writes — API.
- В Bitrix “быстрее через ORM” и “быстрее через legacy” зависит от конкретного запроса и side effects.
