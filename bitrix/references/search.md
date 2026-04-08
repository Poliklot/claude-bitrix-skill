# Поиск (модуль search)

> Audit note: ниже сверено с текущим `www/bitrix/modules/search`. Подтверждены события `BeforeIndex`, `OnSearch`, `OnSearchGetURL` и типовой порядок `Search(...) -> NavStart(...) -> GetNext()`.

```php
use Bitrix\Main\Loader;
Loader::includeModule('search');
```

## Архитектура

Модуль `search` индексирует контент в таблице `b_search_content`. Каждая единица контента идентифицируется парой `(MODULE_ID, ITEM_ID)`. При индексации событие `BeforeIndex` позволяет трансформировать данные.

---

## Индексация: CSearch::Index

```php
CSearch::Index(
    string $MODULE_ID,    // 'my.module' — идентификатор модуля-источника
    string $ITEM_ID,      // '42' — ID элемента в источнике
    array  $arFields,     // поля индекса (см. ниже)
    bool   $bOverWrite = false,  // true — перезаписать если уже есть
    string $SEARCH_SESS_ID = ''  // сессия переиндексации (для пакетного обновления)
);
```

### Поля $arFields

| Поле | Обязательно | Описание |
|------|-------------|----------|
| `TITLE` | да | Заголовок документа |
| `BODY` | да | Текст для индексации (без HTML-тегов) |
| `URL` | да | URL страницы с документом |
| `SITE_ID` | да | Ассоц. массив `['s1' => '']` или простой `['s1']` |
| `PARAM1` | нет | Группировка первого уровня (напр. тип контента) |
| `PARAM2` | нет | Группировка второго уровня (напр. ID раздела) |
| `TAGS` | нет | Строка тегов через запятую |
| `LAST_MODIFIED` | нет | `\Bitrix\Main\Type\DateTime` — дата изменения |
| `PERMISSIONS` | нет | Массив прав `['G2' => 'R', 'G1' => 'D']` |

```php
use Bitrix\Main\Type\DateTime;

CSearch::Index('my.module', (string)$elementId, [
    'TITLE'         => 'Название новости',
    'BODY'          => strip_tags($content),   // убираем HTML
    'URL'           => '/news/' . $code . '/',
    'SITE_ID'       => [SITE_ID => ''],        // текущий сайт
    'PARAM1'        => 'my.module',            // модуль
    'PARAM2'        => (string)$sectionId,     // раздел
    'TAGS'          => 'новость, важное',
    'LAST_MODIFIED' => new DateTime(),
    'PERMISSIONS'   => ['G2' => 'R'],          // G2 = все авторизованные
], true);
```

> **Gotcha:** `SITE_ID` передаётся как ассоц. массив `['s1' => '']`, а не строка. Если передать строку `'s1'` — ядро само приведёт к `['s1' => '']`.

---

## Удаление из индекса: CSearch::DeleteIndex

```php
// Удалить один элемент
CSearch::DeleteIndex('my.module', (string)$elementId);

// Удалить все элементы модуля
CSearch::DeleteIndex('my.module');

// Удалить по PARAM1 (все элементы раздела)
CSearch::DeleteIndex('my.module', false, 'my.module', (string)$sectionId);

// ITEM_ID поддерживает wildcard с %
CSearch::DeleteIndex('my.module', '42%');
```

---

## Полная переиндексация: CSearch::ReIndexAll

```php
// Быстрая — только добавить новые и обновить изменённые
CSearch::ReIndexAll(false);

// Полная — очистить таблицы и переиндексировать всё
CSearch::ReIndexAll(true);

// Только конкретный модуль
CSearch::ReIndexAll(true, 0, ['MODULE_ID' => 'iblock']);

// Только конкретный сайт
CSearch::ReIndexAll(false, 0, ['SITE_ID' => 's1']);
```

> `ReIndexAll` вызывает события `OnReindex` у всех модулей. Для включения своего модуля нужно зарегистрировать обработчик.

---

## Поиск: CSearch::Search

```php
$obSearch = new CSearch();
$obSearch->Search([
    'QUERY'   => 'поисковый запрос',
    'SITE_ID' => SITE_ID,
    'MODULE'  => 'iblock',           // фильтр по модулю (необязательно)
    'PARAM1'  => 'iblock',           // фильтр по группе
    'PARAM2'  => '5',                // фильтр по подгруппе
]);

if ($obSearch->errorno != 0) {
    // ошибка поиска
    echo $obSearch->error;
} else {
    while ($arResult = $obSearch->GetNext()) {
        // $arResult['TITLE']    — заголовок
        // $arResult['BODY']     — отрывок с подсветкой
        // $arResult['URL']      — ссылка
        // $arResult['MODULE_ID']
        // $arResult['PARAM1'], $arResult['PARAM2']
        // $arResult['RANK']     — релевантность
        echo htmlspecialchars($arResult['TITLE']) . '<br>';
    }
}
```

### Параметры поиска

| Параметр | Описание |
|----------|----------|
| `QUERY` | Поисковая фраза |
| `SITE_ID` | ID сайта |
| `MODULE` | Фильтр по модулю |
| `PARAM1` | Фильтр первого уровня |
| `PARAM2` | Фильтр второго уровня |
| `TAGS` | Поиск по тегам |

### Пагинация

```php
$obSearch = new CSearch();
$obSearch->Search([...]);
$obSearch->NavStart(20, false);    // PAGE_RESULT_COUNT, без "показать всё"

// Страницы
$obSearch->NavPrint('Поиск');      // стандартная навигация Bitrix
$totalCount = $obSearch->GetRecordCount();
```

---

## Событие BeforeIndex — трансформация перед записью в индекс

Позволяет изменить или отфильтровать данные перед индексацией:

```php
// В include.php или install/index.php модуля
use Bitrix\Main\EventManager;

EventManager::getInstance()->addEventHandler(
    'search',
    'BeforeIndex',
    ['\MyVendor\MyModule\SearchHandler', 'onBeforeIndex']
);
```

```php
namespace MyVendor\MyModule;

class SearchHandler
{
    public static function onBeforeIndex(array $arFields): array
    {
        if ($arFields['MODULE_ID'] === 'iblock' && $arFields['PARAM1'] === 'private') {
            $arFields['TAGS'] .= ', private';
        }

        // Можно изменить данные
        $arFields['TAGS'] .= ', дополнительный тег';
        return $arFields;
    }
}
```

> **Gotcha:** В текущем core `BeforeIndex` обрабатывает только массив, который вернул обработчик. `return null/false` не отменяет индексацию автоматически, а просто игнорируется. Если нужно пропустить запись, делай это до вызова `CSearch::Index()`.

---

## Событие OnSearch — дополнительные параметры URL поисковой страницы

```php
// Обработчик возвращает строку для добавления к URL результатов
EventManager::getInstance()->addEventHandler(
    'search',
    'OnSearch',
    function(string $query): string {
        // $query — поисковая строка
        // Вернуть строку query-параметра или ''
        return '';
    }
);
```

## Событие OnSearchGetURL — построение итогового URL результата

```php
EventManager::getInstance()->addEventHandler(
    'search',
    'OnSearchGetURL',
    function(array $row): ?string {
        if ($row['MODULE_ID'] === 'my.module') {
            return '/custom/path/' . $row['ITEM_ID'] . '/';
        }

        return null;
    }
);
```

`OnSearch` и `OnSearchGetURL` — разные этапы: первый добавляет query-параметры к URL выдачи, второй может подменить сам URL результата при `Fetch()/GetNext()`.

---

## Регистрация модуля для ReIndexAll

Чтобы `ReIndexAll` переиндексировал контент вашего модуля, зарегистрируй обработчик `OnReindex`:

```php
// В include.php модуля
EventManager::getInstance()->addEventHandler(
    'search',
    'OnReindex',
    ['\MyVendor\MyModule\SearchReindex', 'onReindex']
);
```

```php
namespace MyVendor\MyModule;

use Bitrix\Main\Loader;
use CSearch;

class SearchReindex
{
    /**
     * Вызывается при ReIndexAll. Должен переиндексировать элементы пакетами.
     * $NS — состояние (текущая позиция переиндексации).
     * Вернуть false если всё переиндексировано, массив $NS для продолжения.
     */
    public static function onReindex(int $max_execution_time, array &$NS): bool|array
    {
        $NS['ID'] = (int)($NS['ID'] ?? 0);
        $limit = 100;

        Loader::includeModule('iblock');
        $res = \CIBlockElement::GetList(
            ['ID' => 'ASC'],
            ['IBLOCK_ID' => MY_IBLOCK_ID, '>ID' => $NS['ID']],
            false,
            ['nPageSize' => $limit],
            ['ID', 'NAME', 'DETAIL_TEXT', 'DETAIL_PAGE_URL']
        );

        $indexed = 0;
        while ($el = $res->GetNext()) {
            CSearch::Index('my.module', (string)$el['ID'], [
                'TITLE'   => $el['NAME'],
                'BODY'    => strip_tags($el['DETAIL_TEXT']),
                'URL'     => $el['DETAIL_PAGE_URL'],
                'SITE_ID' => [SITE_ID => ''],
                'PARAM1'  => 'my.module',
            ], true);
            $NS['ID'] = $el['ID'];
            $indexed++;
        }

        if ($indexed < $limit) {
            return false;  // всё переиндексировано
        }

        return $NS;  // продолжить со следующей порции
    }
}
```

---

## Интеграция с инфоблоком: автоиндексация по событию

Сбрасывать и переиндексировать при сохранении элемента инфоблока:

```php
EventManager::getInstance()->addEventHandler(
    'iblock',
    'OnAfterIBlockElementAdd',
    ['\MyVendor\MyModule\IblockSearchSync', 'reindex']
);
EventManager::getInstance()->addEventHandler(
    'iblock',
    'OnAfterIBlockElementUpdate',
    ['\MyVendor\MyModule\IblockSearchSync', 'reindex']
);
EventManager::getInstance()->addEventHandler(
    'iblock',
    'OnBeforeIBlockElementDelete',
    ['\MyVendor\MyModule\IblockSearchSync', 'delete']
);
```

```php
namespace MyVendor\MyModule;

class IblockSearchSync
{
    public static function reindex(array &$arFields): void
    {
        if ((int)($arFields['IBLOCK_ID'] ?? 0) !== MY_IBLOCK_ID) {
            return;
        }
        $id = (int)$arFields['ID'];
        if (!$id) {
            return;
        }

        $res = \CIBlockElement::GetByID($id);
        if (!($el = $res->GetNext())) {
            return;
        }

        \CSearch::Index('my.module', (string)$id, [
            'TITLE'   => $el['NAME'],
            'BODY'    => strip_tags($el['DETAIL_TEXT'] ?? ''),
            'URL'     => $el['DETAIL_PAGE_URL'],
            'SITE_ID' => [SITE_ID => ''],
            'PARAM1'  => 'my.module',
        ], true);
    }

    public static function delete(int $elementId): void
    {
        \CSearch::DeleteIndex('my.module', (string)$elementId);
    }
}
```

---

## Готовые параметры компонента bitrix:search.title

Для отображения формы и результатов поиска используй стандартный компонент:

```php
$APPLICATION->IncludeComponent('bitrix:search.title', '', [
    'SITE_ID'       => SITE_ID,
    'USE_LANGUAGE_GUESS' => 'Y',
    'USE_SUGGEST'   => 'Y',
    'RESULT_URL'    => '/search/',
]);
```

```php
// На странице результатов: bitrix:search.page
$APPLICATION->IncludeComponent('bitrix:search.page', '', [
    'SITE_ID'         => SITE_ID,
    'USE_SUGGEST'     => 'Y',
    'SHOW_WHEN_EMPTY' => 'Y',
    'USE_LANGUAGE_GUESS' => 'Y',
]);
```

---

## Gotchas

- `CSearch::Index` — работает только если модуль `search` подключён через `Loader::includeModule('search')`
- `BODY` — передавай текст без HTML (`strip_tags`), иначе теги попадут в индекс
- `SITE_ID` может быть строкой `'s1'` — ядро само приведёт к `['s1' => '']`
- `bOverWrite = true` — перезаписывает запись, `false` — добавляет новую (дубли!)
- `DeleteIndex` без `$ITEM_ID` удаляет **весь** индекс модуля — используй осторожно
- `ReIndexAll(true)` — очищает таблицы `TRUNCATE`, очень деструктивно
- Права `PERMISSIONS` `['G1' => 'D']` — группа 1 (все) не видит. `['G2' => 'R']` — авторизованные видят
