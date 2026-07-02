# Диагностика производительности (модуль perfmon)

> Audit note: ниже сверено с текущим `www/bitrix/modules/perfmon`. Подтверждены классы `CPerfomanceSQL`, `CPerfomanceHit`, `CPerfomanceCache`, `CPerfomanceComponent`, `CPerfomanceError`, `CPerfomanceHistory`, `CPerfomanceSchema`, `CPerfomanceTable`, `CPerfomanceKeeper`, а также admin-страницы `perfmon_sql_list.php`, `perfmon_hit_list.php`, `perfmon_cache_list.php`, `perfmon_error_list.php`, `perfmon_history.php`, `perfmon_explain.php`, `perfmon_index_*`, `perfmon_tables.php`.

## Для чего использовать

`perfmon` в текущем core нужен не для “магического ускорения”, а для конкретной диагностики:

- медленные SQL
- тяжёлые хиты
- проблемы кеша
- ошибки и деградации
- индексы таблиц
- структура схемы

---

## Основные классы

Подтверждены:

- `CPerfomanceSQL::GetList`
- `CPerfomanceHit::GetList`
- `CPerfomanceCache::GetList`
- `CPerfomanceComponent::GetList`
- `CPerfomanceError::GetList/Delete`
- `CPerfomanceHistory::GetList/Delete`
- `CPerfomanceSchema::Init`
- `CPerfomanceTableList::GetList`
- `CPerfomanceTable::Init/GetList`

```php
use Bitrix\Main\Loader;

Loader::includeModule('perfmon');

$sqlList = CPerfomanceSQL::GetList(
    ['ID', 'QUERY_TIME', 'QUERY'],
    [],
    ['QUERY_TIME' => 'DESC'],
    false,
    ['nTopCount' => 20]
);

while ($row = $sqlList->Fetch()) {
    echo $row['QUERY_TIME'] . ' ' . $row['QUERY'] . PHP_EOL;
}
```

```php
$hits = CPerfomanceHit::GetList(
    ['DATE_HIT' => 'DESC'],
    [],
    false,
    ['nTopCount' => 20],
    ['ID', 'DATE_HIT', 'SERVER_NAME', 'PAGE', 'HIT_TIME']
);
```

---

## Таблицы, схема и индексы

Подтверждены:

- `CPerfomanceTableList::GetList`
- `CPerfomanceTable::Init`
- `CPerfomanceTable::GetList`
- `CPerfomanceSchema::Init`
- admin-страницы `perfmon_tables.php`, `perfmon_table.php`, `perfmon_index_list.php`, `perfmon_index_detail.php`, `perfmon_index_complete.php`

Это хороший путь, когда задача звучит как:

- “почему таблица распухла”
- “каких индексов не хватает”
- “почему запросы по инфоблоку проседают”

---

## Кеш и компоненты

Подтверждены:

- `CPerfomanceCache::GetList`
- `CPerfomanceComponent::GetList`
- admin `perfmon_cache_list.php`
- admin `perfmon_comp_list.php`

Здесь удобно проверять:

- какие компоненты чаще всего бьют по времени
- где кеш не даёт эффекта
- какие страницы грузят слишком много компонентного кода

---

## Admin UI

Подтверждены ключевые страницы:

- `perfmon_sql_list.php`
- `perfmon_hit_list.php`
- `perfmon_cache_list.php`
- `perfmon_error_list.php`
- `perfmon_history.php`
- `perfmon_explain.php`
- `perfmon_tables.php`

Если пользователь просит “понять, что тормозит”, сначала безопаснее пройти:

1. `perfmon_hit_list.php`
2. `perfmon_sql_list.php`
3. `perfmon_cache_list.php`
4. `perfmon_explain.php`

---

## Gotchas

- `perfmon` полезен именно как диагностический контур. Не обещай, что сам модуль “починит производительность”.
- Сначала подтвердить узкое место, потом уже менять код, кеш или индексы.
- Для общего аудита оптимизаций сначала используй `project-optimization-audit.md`; для тяжёлых инфоблоков и компонентных страниц сочетай `perfmon` с `cache-infra.md`, `components.md` и `iblocks.md`.
