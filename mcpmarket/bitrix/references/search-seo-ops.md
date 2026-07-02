# Search Seo Ops
> MCP Market compact bundle. Source files are concatenated from `bitrix/references/*` to keep the imported skill folder below the 50-file limit.

---

## Source: `search.md`

# Поиск (модуль search)

> Audit note: ниже сверено с текущим `www/bitrix/modules/search`. Подтверждены события `BeforeIndex`, `OnSearch`, `OnSearchGetURL` и типовой порядок `Search(...) -> NavStart(...) -> GetNext()`. Детальный контракт `NavStart`, `PAGEN_N` и `GetNavPrint` смотри в `pagination.md`.

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

## AJAX-подсказки и быстрый поиск: CSearchTitle + search.suggest.input

В текущем core подтверждены:

- `CSearchTitle::Search`
- стандартный компонент `bitrix:search.suggest.input`
- шаблоны `bitrix:search.form` и `bitrix:search.page`, которые уже используют `bitrix:search.suggest.input`

```php
$searchTitle = new CSearchTitle();
$searchTitle->Search(
    $phrase,
    10,
    ['SITE_ID' => SITE_ID]
);

while ($item = $searchTitle->GetNext()) {
    echo $item['NAME'] . PHP_EOL;
}
```

Если задача звучит как:

- “сделать быстрый AJAX-поиск”
- “вывести подсказки под строкой поиска”
- “почему suggest не отдаёт URL”

то сначала проверь:

1. `bitrix:search.suggest.input`
2. `CSearchTitle::Search`
3. событие `OnSearchGetURL`
4. индексацию сущности и её `SITE_ID`

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

`OnSearch` и `OnSearchGetURL` — разные этапы: первый добавляет query-параметры к URL выдачи, второй может подменить сам URL результата при `Fetch()/GetNext()`, в том числе для `CSearchTitle`.

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

---

## Source: `seo-cache-access.md`

# SEO, Кеш, Индексация, Доступ

> Audit note: ниже сверено с текущим core `main` + `seo`. В этой версии подтверждены `Bitrix\Seo\Sitemap\Job::findJob/addJob/markToRegenerate`, `Bitrix\Seo\RobotsFile`, `Bitrix\Seo\Sitemap\Internals\SitemapTable`, а для composite-сброса подтверждён `Bitrix\Main\Composite\Page`, не `Engine::clearByUrl()/clearAll()`.

## 1. Сброс кеша

### Виды кеша в Bitrix

| Вид | Где хранится | Класс |
|-----|-------------|-------|
| Файловый кеш компонентов | `/bitrix/cache/` | `\Bitrix\Main\Data\Cache` |
| Managed cache (ORM, таблицы) | `/bitrix/managed_cache/` | `\Bitrix\Main\Data\ManagedCache` |
| Статический HTML (composite) | `/bitrix/html_pages/` или configured storage | canonical `\Bitrix\Main\Composite\Page`; legacy alias `\Bitrix\Main\Data\StaticHtmlCache` |

### Сброс файлового кеша (D7)

```php
use Bitrix\Main\Data\Cache;

// Сбросить конкретную запись (по uniqueId + initDir)
$cache = Cache::createInstance();
$cache->clean('my_unique_key', '/my_dir');

// Сбросить всю директорию кеша
$cache->cleanDir('/catalog');          // только /bitrix/cache/catalog/
$cache->cleanDir(false, 'cache');      // весь /bitrix/cache/

// Через TaggedCache (предпочтительно при работе с инфоблоками)
use Bitrix\Main\Application;
$taggedCache = Application::getInstance()->getTaggedCache();
$taggedCache->clearByTag('iblock_id_5');   // сброс всего кеша с тегом iblock_id_5
$taggedCache->clearByTag('catalog');       // кастомный тег

// Статический метод (deprecated, но ещё встречается в legacy)
Cache::clearCache(false, '/catalog');      // false = не полный сброс
Cache::clearCache(true);                   // полный сброс /bitrix/cache/
```

### Сброс managed cache

```php
use Bitrix\Main\Application;
$managedCache = Application::getInstance()->getManagedCache();

$managedCache->clean('b_iblock_element');           // конкретная запись
$managedCache->cleanDir('b_iblock_element');        // вся директория таблицы
$managedCache->cleanAll();                          // весь managed cache
```

### Сброс HTML/composite кеша страниц

Composite cache хранит финальный HTML в `/bitrix/html_pages/`. В compact-версии полный `composite-cache.md` сжат в этот файл, `components-admin-ui.md` и `users-security.md`. Сброс: сначала проверь локальный core; для `main` 26.150.0 canonical-класс — `Bitrix\Main\Composite\Page`.

```php
use Bitrix\Main\Composite\Page;

// Полный сброс HTML-кеша всего сайта в текущем подтверждённом core
$page = Page::getInstance();
$page->deleteAll();

// Compatibility alias в этом core, встречается в legacy-коде:
\Bitrix\Main\Data\StaticHtmlCache::getInstance()->deleteAll();

// Точечный сброс — только через подтверждённый локальным core объект/ключ.
// Не обещай Engine::clearByUrl() / Engine::clearAll(), если их нет в установленной версии.
```

Сброс из shell (CLI) или деплой-скрипта:

```bash
# Сбросить весь кеш файловый + managed
php -r "
define('NO_KEEP_STATISTIC', true);
define('NOT_CHECK_PERMISSIONS', true);
\$_SERVER['DOCUMENT_ROOT'] = '/var/www/html';
require_once '/var/www/html/bitrix/modules/main/include/prolog_before.php';
\Bitrix\Main\Data\Cache::clearCache(true);
echo 'Done';
"
```

### Принудительный сброс кеша на одном запросе (для авторизованных)

Bitrix поддерживает параметр `?clear_cache=Y` — если пользователь имеет право `cache_control`, текущий запрос игнорирует кеш:

```php
// В шаблоне сайта или include.php — это уже делает ядро автоматически.
// Вручную включить для текущего хита:
use Bitrix\Main\Data\Cache;
Cache::setClearCache(true);           // только этот хит

// Для всей сессии (пока не сбросить вручную):
Cache::setClearCacheSession(true);
// Сбросить сессионный флаг:
Cache::setClearCacheSession(false);
```

> **Gotcha:** `setClearCache`/`setClearCacheSession` работают только для пользователей с правом `cache_control` (обычно администраторы).

---

## 2. Скрытие страниц из индексации (noindex, robots)

### meta robots через $APPLICATION

```php
// В .php-файле страницы или компоненте, ДО вывода <head>
global $APPLICATION;

// Полное скрытие из индекса
$APPLICATION->SetPageProperty('robots', 'noindex, nofollow');

// Только не сохранять в индексе, ссылки всё же проходить
$APPLICATION->SetPageProperty('robots', 'noindex, follow');

// Страница индексируется, но не следовать ссылкам
$APPLICATION->SetPageProperty('robots', 'index, nofollow');

// Canonical URL
$APPLICATION->SetPageProperty('canonical', 'https://example.com/catalog/item/');
```

`ShowHead()` в шаблоне автоматически выведет эти мета-теги:
```php
// В header.php шаблона:
$APPLICATION->ShowHead(); // → <meta name="robots" content="noindex, nofollow">
                          //    <link rel="canonical" href="...">
```

### OpenGraph и Schema.org

В текущем core подтверждены методы:

- `$APPLICATION->SetPageProperty(...)`
- `$APPLICATION->AddHeadString(...)`
- `$APPLICATION->ShowHead()`

Практический путь для OG/JSON-LD здесь такой:

```php
global $APPLICATION;

$APPLICATION->SetPageProperty('canonical', 'https://example.com/blog/post/');
$APPLICATION->AddHeadString(
    '<meta property="og:title" content="' . htmlspecialcharsbx($title) . '">',
    true
);
$APPLICATION->AddHeadString(
    '<meta property="og:description" content="' . htmlspecialcharsbx($description) . '">',
    true
);
$APPLICATION->AddHeadString(
    '<meta property="og:image" content="' . htmlspecialcharsbx($imageUrl) . '">',
    true
);

$jsonLd = \Bitrix\Main\Web\Json::encode([
    '@context' => 'https://schema.org',
    '@type' => 'Article',
    'headline' => $title,
    'description' => $description,
    'image' => [$imageUrl],
    'url' => $canonicalUrl,
]);

$APPLICATION->AddHeadString(
    '<script type="application/ld+json">' . $jsonLd . '</script>',
    true
);
```

Это закрывает типовые задачи:

- OpenGraph для карточки/статьи
- JSON-LD schema.org
- canonical + robots в одном месте

Для `landing`-страниц дополнительно сверяй hooks модуля `landing`, а не только шаблон сайта.

### SetDirProperty — для целых разделов

```php
// Файл .section.php в директории /private/ или через код
$APPLICATION->SetDirProperty('robots', 'noindex, nofollow', '/private/');
```

Третий аргумент можно не передавать: тогда свойство применяется к текущей директории. Сам метод `SetDirProperty($propertyId, $value, $path = false)` в текущем core подтверждён.

### Через `.section.php` файл раздела

Создать файл `/catalog/ajax/.section.php`:
```php
<?php
$APPLICATION->SetDirProperty('robots', 'noindex, nofollow');
```
Все страницы в этой директории получат noindex автоматически.

### noindex-тег в HTML (для фрагментов)

Если нужно скрыть только фрагмент текста (Яндекс понимает):
```html
<!--noindex-->Текст, который не надо индексировать<!--/noindex-->
```

---

## 3. Sitemap

Bitrix управляет sitemap через модуль `seo`. Данные хранятся в таблице `b_seo_sitemap`.

### ORM для Sitemap

```php
use Bitrix\Main\Loader;
use Bitrix\Seo\Sitemap\Internals\SitemapTable;

Loader::includeModule('seo');

// Список всех sitemap
$result = SitemapTable::getList([
    'select' => ['ID', 'NAME', 'SITE_ID', 'ACTIVE', 'DATE_RUN'],
    'filter' => ['=ACTIVE' => 'Y'],
]);
while ($row = $result->fetch()) {
    echo $row['NAME'] . ' — ' . $row['DATE_RUN'] . "\n";
}

// Добавить sitemap
$settings = SitemapTable::prepareSettings([
    'FILE_MASK'  => '*.php,*.html',      // маска файлов
    'DIR'        => ['/' => 'Y'],        // включить корневой раздел
    'FILE'       => [],
    'IBLOCK_LIST'    => [5 => '/catalog/'],  // URL инфоблока
    'IBLOCK_ELEMENT' => [5 => 'Y'],          // включить элементы
    'IBLOCK_SECTION' => [5 => 'Y'],          // включить разделы
]);

$addResult = SitemapTable::add([
    'SITE_ID'  => 's1',
    'ACTIVE'   => 'Y',
    'NAME'     => 'Main sitemap',
    'SETTINGS' => serialize($settings),
]);

if (!$addResult->isSuccess()) {
    // обработка ошибок
}

// Удалить sitemap со всеми связанными данными
SitemapTable::fullDelete($mapId);
```

### Запуск генерации sitemap через Job

```php
use Bitrix\Seo\Sitemap\Job;

Loader::includeModule('seo');

$job = Job::findJob($sitemapId) ?: Job::addJob($sitemapId);

if (!$job) {
    throw new \RuntimeException('Не удалось зарегистрировать job для sitemap');
}

// Проверить статус текущей job
$jobData = $job->getData();
$status = $jobData['status'];
// Job::STATUS_REGISTER — ожидает запуска
// Job::STATUS_PROCESS  — идёт генерация
// Job::STATUS_FINISH   — готово
// Job::STATUS_ERROR    — ошибка

// Выполнить один шаг генерации синхронно
$result = $job->doStep();

// Поставить sitemap на фоновую регенерацию через агент
Job::markToRegenerate($sitemapId);
```

### Проверить существование sitemap.xml

```php
use Bitrix\Main\IO\File;
use Bitrix\Main\Application;

$docRoot = Application::getDocumentRoot();
$sitemapPath = $docRoot . '/sitemap.xml';

if (File::isFileExists($sitemapPath)) {
    $file = new File($sitemapPath);
    echo 'Sitemap exists, size: ' . $file->getSize() . ' bytes';
    echo 'Modified: ' . date('Y-m-d H:i:s', $file->getModificationTime());
} else {
    echo 'Sitemap not found';
}
```

### Добавить ссылку на Sitemap в robots.txt

```php
use Bitrix\Seo\RobotsFile;
use Bitrix\Main\Loader;

Loader::includeModule('seo');

$robots = new RobotsFile('s1');
$robots->addRule(
    ['Sitemap', 'https://example.com/sitemap.xml'],
    '*'  // секция User-Agent
);
// Метод addRule с флагом $bCheckUnique = true (по умолчанию) — не создаст дубликат
```

---

## 4. robots.txt

### Чтение и управление через D7

```php
use Bitrix\Seo\RobotsFile;
use Bitrix\Main\Loader;

Loader::includeModule('seo');

$robots = new RobotsFile('s1');  // s1 — SITE_ID

// Получить правила для секции
$disallowRules = $robots->getRules('Disallow', '*');
// → [['Disallow', '/admin/'], ['Disallow', '/bitrix/'], ...]

// Добавить правило (с проверкой дублей по умолчанию)
$robots->addRule(['Disallow', '/private/'], '*');
$robots->addRule(['Disallow', '/ajax/'], 'Googlebot');
$robots->addRule(['Allow', '/'], '*');

// Добавить ссылку на sitemap
$robots->addRule(['Sitemap', 'https://example.com/sitemap.xml'], '*');
```

### Прямое редактирование файла

robots.txt — обычный файл в корне сайта:

```php
use Bitrix\Main\IO\File;
use Bitrix\Main\Application;

$path = Application::getDocumentRoot() . '/robots.txt';
$file = new File($path);

// Читать
$content = $file->getContents();

// Перезаписать
$file->putContents("User-agent: *\nDisallow: /bitrix/\nDisallow: /upload/\nAllow: /\n\nSitemap: https://example.com/sitemap.xml\n");
```

> **Gotcha:** `RobotsFile` работает только с секциями `User-Agent:`. Если нужен нестандартный формат — пиши напрямую через `IO\File`.

---

## 5. Защита страниц авторизацией

### Базовая проверка — `$USER->IsAuthorized()`

```php
// В .php-файле страницы или component.php
global $USER, $APPLICATION;

if (!$USER->IsAuthorized()) {
    // Вариант 1: показать форму авторизации и остановить выполнение
    $APPLICATION->AuthForm('Для просмотра необходима авторизация');
    // AuthForm() делает die() внутри по умолчанию

    // Вариант 2: редирект на страницу входа
    // LocalRedirect('/login/?backurl=' . urlencode($APPLICATION->GetCurPage()));
}
```

### `AuthForm` — параметры

```php
$APPLICATION->AuthForm(
    $message,         // строка или массив с ключами TYPE/MESSAGE
    $show_prolog,     // bool, показывать prolog.php шаблона (default: true)
    $show_epilog,     // bool, показывать epilog.php (default: true)
    $not_show_links,  // 'Y'/'N', скрыть ссылки на регистрацию (default: 'N')
    $do_die           // bool, вызвать die() после вывода формы (default: true)
);
```

### Проверка группы пользователя

```php
global $USER;

if (!$USER->IsAuthorized()) {
    $APPLICATION->AuthForm('Необходима авторизация');
}

// Проверить принадлежность к группам (ID групп)
$allowedGroups = [5, 8]; // ID групп "Редакторы", "Менеджеры"
$userGroups = $USER->GetUserGroupArray();
$hasAccess = !empty(array_intersect($allowedGroups, $userGroups));

if (!$hasAccess) {
    // 403
    $APPLICATION->SetStatus('403 Forbidden');
    include $_SERVER['DOCUMENT_ROOT'] . '/403.php';
    die();
}
```

### Проверка прав Bitrix (CheckAccess / CanDoOperation)

```php
global $USER;

// Проверить системную операцию
if (!$USER->CanDoOperation('edit_php')) {
    // нет прав на редактирование PHP
}

// Проверить право на модуль
if (!\CMain::GetGroupRight('iblock') >= 'W') {
    // нет прав на запись в инфоблоки
}
```

### Защита на уровне компонента

```php
// В component.php
global $USER;

if (!$USER->IsAuthorized()) {
    $this->arResult['IS_AUTHORIZED'] = false;
    // Редирект или показ заглушки — в шаблоне
    return;
}

if (!$USER->IsAdmin() && !in_array(5, $USER->GetUserGroupArray())) {
    // нет нужной группы
    ShowError(GetMessage('ACCESS_DENIED'));
    return;
}
```

### Защита через `.access.php` (rights на уровне файловой системы)

Создать файл `/secret/.access.php`:
```php
<?php
$PERM = [
    'G2'  => 'R',   // группа 2 (все авторизованные) — чтение
    'G1'  => 'D',   // группа 1 (анонимные) — запрет
];
```

Битрикс автоматически проверяет файл `.access.php` в директории и выдаёт 403 незарегистрированным пользователям.

### Редирект на страницу авторизации с сохранением backurl

```php
global $USER, $APPLICATION;

if (!$USER->IsAuthorized()) {
    $backUrl = $APPLICATION->GetCurPageParam('', [], false);
    LocalRedirect(SITE_DIR . 'login/?backurl=' . urlencode($backUrl));
    die();
}
```

### После авторизации — возврат на backurl

```php
// В компоненте system.auth.login или обработчике формы:
$backUrl = $request->getQuery('backurl') ?? '/';
// Validate — backurl должен быть относительным (защита от open redirect)
if (!preg_match('#^/#', $backUrl)) {
    $backUrl = '/';
}
LocalRedirect($backUrl);
```

---

## Сводная таблица: что где настраивается

| Задача | Способ |
|--------|--------|
| Сбросить кеш компонента | `Cache::cleanDir('/my_dir')` или `TaggedCache::clearByTag()` |
| Сбросить кеш всего сайта | `Cache::clearCache(true)` |
| Сбросить HTML-кеш | `Bitrix\Main\Composite\Page::getInstance()->deleteAll()` |
| Скрыть страницу из поиска | `$APPLICATION->SetPageProperty('robots', 'noindex')` |
| Скрыть раздел целиком | `.section.php` с `SetDirProperty` |
| Добавить Sitemap запись | `SitemapTable::add(...)` |
| Запустить генерацию XML | `Job::findJob()/addJob()` + `doStep()` или `markToRegenerate()` |
| Управлять robots.txt | `new RobotsFile('s1')` + `addRule()` |
| Защитить страницу auth | `$USER->IsAuthorized()` + `AuthForm()` |
| Защитить раздел ФС | `.access.php` с массивом `$PERM` |

---

## Source: `cache-infra.md`

# Bitrix Кеширование, Агенты, Файловая система — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с кешированием (Data\Cache), тегированным кешем (TaggedCache), агентами (CAgent) или файловой системой (IO). Если задача про “Композитный сайт”, `/bitrix/html_pages/`, `X-Bitrix-Composite`, `setFrameMode` или dynamic areas — смотри также compact-разделы в `components-admin-ui.md` и `users-security.md`.

## Содержание
- Data\Cache: два режима (data/output), полный API, gotchas
- Composite/static HTML: отдельный слой поверх component/data cache
- Data\TaggedCache: startTagCache/registerTag/clearByTag
- CAgent: AddAgent, IS_PERIOD, паттерн функции, gotchas
- IO\File, IO\Directory, IO\Path — безопасная работа с ФС

---

## Кеширование (Data\Cache)

`Cache` — основной D7-механизм кеширования. В текущем core `baseDir` по умолчанию равен `'cache'`, а реальный корень строится через `Application::getPersonalRoot()`. На типовой установке это даёт путь вида `/bitrix/cache/`, но не захардкоживай его без проверки проекта. Ключ кеша формируется как `md5($uniqueString)` и путь строится через `Cache::getPath($uniqueString)`.

**Движки**: `files` (по умолчанию), `redis`, `memcached`, `memcache`, `apc`/`apcu`, кастомный через `class_name` в конфиге.

### Два режима: output-кеш и data-кеш

Это принципиальное различие — перепутать их значит получить баг с пустым контентом.

**Режим 1 — data-кеш** (только переменные, без HTML-буферизации):

```php
use Bitrix\Main\Application;

$cache   = Application::getInstance()->getCache();
$ttl     = 3600;          // секунды
$cacheId = 'orders_' . $userId;
$cacheDir = '/my_module/orders'; // относительный путь внутри /bitrix/cache/

$cache->noOutput(); // ОБЯЗАТЕЛЬНО: отключает ob_start() и авто-вывод

if ($cache->startDataCache($ttl, $cacheId, $cacheDir)) {
    // кеш-промах: вычисляем и сохраняем
    $data = OrderTable::getList([...])->fetchAll();
    $cache->endDataCache($data); // $data сохраняется в VARS
} else {
    // кеш-попадание: данные уже в кеше
    $data = $cache->getVars();
}
```

**Режим 2 — output-кеш** (HTML-буферизация + vars):

```php
$cache = Application::getInstance()->getCache();

if ($cache->startDataCache($ttl, $cacheId, $cacheDir)) {
    // кеш-промах: startDataCache() сам вызвал ob_start() внутри себя
    $data = compute();
    echo renderHtml($data);           // попадает в буфер
    $cache->endDataCache(['data' => $data]); // сохраняет HTML + vars
} else {
    // кеш-попадание: HTML уже выведен автоматически (через output())
    $data = $cache->getVars()['data']; // vars тоже доступны
}
```

**Принудительно сбросить конкретную запись**:
```php
$cache->clean($cacheId, $cacheDir);   // удалить одну запись
$cache->cleanDir($cacheDir);          // удалить всю директорию
```

### Полный API Cache

```php
$cache = \Bitrix\Main\Data\Cache::createInstance(); // factory-метод

// Управление режимом
$cache->noOutput();             // отключить буферизацию (вызвать ДО startDataCache)
$cache->forceRewriting(true);   // принудительно перезаписать кеш

// Жизненный цикл
$hit = $cache->initCache($ttl, $cacheId, $cacheDir, $baseDir = 'cache');
// true  = кеш найден, $cache->getVars() и $cache->output() доступны
// false = кеш устарел/нет

$started = $cache->startDataCache($ttl, $cacheId, $cacheDir);
// false = кеш найден, контент уже выведен (output())
// true  = кеш-промах, буфер запущен (если noOutput не вызван)

$cache->endDataCache($vars);    // сохранить буфер + vars; $vars — любой сериализуемый тип
$cache->abortDataCache();       // прервать без сохранения; при output-mode буфер будет выведен, а не записан в кеш

$cache->getVars();              // данные из кеша (после initCache/startDataCache=false)
$cache->output();               // вывести HTML из кеша (только если hasOutput=true)

// Статика
Cache::shouldClearCache();      // admin нажал "Сбросить кеш"? → bool
Cache::getPath($cacheId);       // путь к файлу кеша: 'ab/abcde...hash.php'
```

### Gotchas кеша

- **`noOutput()` забыли** → `ob_start()` запустится, следующий `ob_get_contents()` в другом месте вернёт не то
- **TTL = 0** → `startDataCache()` вернёт `true`, но запись в кеш не стартует: `isStarted` не поднимется и `endDataCache()` потом ничего не запишет. Это удобно для отладки, но не считай такой запуск полноценным cache-session
- **`endDataCache` без `startDataCache`** → тихий no-op (ядро проверяет `$this->isStarted`)
- **`$baseDir`** — обычно `'cache'`. Менять нет смысла в 99% случаев
- **`$initDir` = false** → ядро подставляет `'default'` — все кеши смешаются в одной папке. Всегда задавай уникальный путь

---

## Composite/static HTML cache — отдельный слой

Composite cache не является `Data\Cache`: он хранит финальный HTML страницы через `Bitrix\Main\Composite\Page` в `/bitrix/html_pages/` или другом backend-е и может отдаваться без запуска PHP. `Bitrix\Main\Data\StaticHtmlCache` в `main` 26.150.0 — compatibility alias к `Composite\Page`.

Короткое правило диагностики:

```text
component/data cache отвечает за данные и output компонента;
composite отвечает за уже собранный HTML страницы;
browser/CDN отвечает за внешний HTTP-кеш.
```

Не лечи composite-проблему только `Cache::cleanDir()`, и не лечи component-result проблему только очисткой `/bitrix/html_pages/`. Сначала назови слой. Для общего performance-аудита смотри compact-раздел “Аудит оптимизаций Bitrix-проекта” ниже.

Проверяй `X-Bitrix-Composite`, `/bitrix/html_pages/`, `?ncc=1`, `COMPOSITE_FRAME_*`, `AutomaticArea`, `setFrameMode` как голосование/adaptation flag и `createFrame`/`FrameHelper` как dynamic boundary.

---

## Тегированный кеш (Data\TaggedCache)

Тегированный кеш связывает файлы кеша с произвольными тегами в таблице `b_cache_tag`. При инвалидации по тегу ядро находит все затронутые директории и удаляет кеш в них. Используй когда нужна точечная инвалидация (например, "сбросить все кеши, которые зависят от элемента iblock 42").

Тегированный кеш всегда работает в паре с обычным `Cache`. Данные хранятся там же (файлы/Redis), теги — только в БД.

```php
use Bitrix\Main\Application;

$app         = Application::getInstance();
$cache       = $app->getCache();
$taggedCache = $app->getTaggedCache(); // singleton на запрос

$cacheDir = '/my_module/products';
$cacheId  = 'product_' . $productId;

$cache->noOutput();
if ($cache->startDataCache(3600, $cacheId, $cacheDir)) {
    $taggedCache->startTagCache($cacheDir); // начинаем регистрацию тегов

    $product = \Bitrix\Iblock\ElementTable::getById($productId)->fetch();
    $sections = getSections($productId);

    // Регистрируем теги — кеш будет инвалидирован если любой из них сбросить
    $taggedCache->registerTag('iblock_id_' . CATALOG_IBLOCK_ID);  // сброс всего каталога
    $taggedCache->registerTag('iblock_id_el_' . $productId);       // сброс конкретного товара

    $taggedCache->endTagCache(); // сохраняем теги в b_cache_tag
    $cache->endDataCache(['product' => $product, 'sections' => $sections]);
} else {
    $data    = $cache->getVars();
    $product = $data['product'];
    $sections = $data['sections'];
}

// Инвалидация — можно вызывать из обработчика события OnAfterIBlockElementUpdate:
$app->getTaggedCache()->clearByTag('iblock_id_el_' . $productId);

// Сбросить все кеши в директории (удалит файлы и записи в b_cache_tag):
$app->getTaggedCache()->clearByTag(true); // все теги кроме persistent ('*')
```

### API TaggedCache

```php
$tc = Application::getInstance()->getTaggedCache();

$tc->startTagCache($relativePath);  // начать фрейм; $relativePath = initDir из Cache
$tc->registerTag($tag);             // добавить тег к текущему фрейму (и всем вложенным)
$tc->endTagCache();                 // сохранить все теги в БД
$tc->abortTagCache();               // отменить фрейм без сохранения

$tc->clearByTag($tag);              // инвалидировать всё с этим тегом
$tc->clearByTag(true);              // инвалидировать всё (кроме помеченных '*')
$tc->deleteAllTags();               // truncate b_cache_tag (ядерный сброс всего)
```

### Стандартные теги Bitrix (iblock)

Bitrix сам регистрирует теги при работе с инфоблоком:

| Тег | Что инвалидирует |
|-----|-----------------|
| `iblock_id_N` | все кеши инфоблока N |
| `iblock_id_el_N` | кеши конкретного элемента N |
| `iblock_id_sec_N` | кеши конкретного раздела N |
| `CATALOG_N` | кеши каталога |

### Gotchas тегированного кеша

- **`startTagCache` и `startDataCache` — разные `initDir`** — тегированный кеш использует путь из `startTagCache` для поиска файлов. Это должен быть тот же путь, что передаёшь в `startDataCache`/`initCache`
- **`clearByTag` удаляет ВСЮ директорию**, не отдельные файлы. Поэтому `$cacheDir` должен быть достаточно специфичным — не `/` и не `/my_module`
- **Теги пишутся в master БД** (`useMasterOnly(true)`) — это защита от проблем с репликой, но увеличивает нагрузку. Не злоупотребляй количеством тегов на один запрос (лимит 200)
- **`abortTagCache` при ошибке** — при ошибке внутри обвязки тегов лучше явно вызвать `abortTagCache()`, чтобы снять текущий фрейм из `cacheStack`

---

## Агенты (CAgent)

D7-обёртки над агентами нет — используется legacy-класс `CAgent` из `b_agent`. Ядро выполняет агенты через `CAgent::CheckAgents()` / `CAgent::ExecuteAgents()` и реально делает `eval()` строки из поля `NAME`.

**Как работают**: ядро выбирает активные записи с `NEXT_EXEC <= NOW()`, временно лочит их через `DATE_CHECK`, выполняет `eval($agent['NAME'])`, а затем:
- если результат пустая строка, запись удаляется;
- если вернулась строка, она записывается обратно в `NAME`;
- `NEXT_EXEC` считается по-разному для `IS_PERIOD='Y'` и `IS_PERIOD='N'`.

```php
// Регистрация агента (обычно в InstallDB инсталлятора модуля)
\CAgent::AddAgent(
    '\MyVendor\MyModule\Agent::run();', // строка для eval — именно так, с ;
    'my.module',                         // MODULE_ID
    'N',                                 // IS_PERIOD: 'N' = интервальный, 'Y' = периодический
    3600,                                // AGENT_INTERVAL: секунды между запусками
    '',                                  // DATE_CHECK: дата начала ('' = с текущего момента)
    'Y',                                 // ACTIVE
    '',                                  // NEXT_EXEC: '' = запустить как можно скорее
    100,                                 // SORT
    false,                               // USER_ID: false = системный
    false                                // $existError: false = не ошибка если уже существует
);

// Удалить (обычно в UnInstallDB)
\CAgent::RemoveAgent('\MyVendor\MyModule\Agent::run();', 'my.module');

// Удалить все агенты модуля
\CAgent::RemoveModuleAgents('my.module');
```

**Функция агента — обязательный паттерн**:

```php
namespace MyVendor\MyModule;

class Agent
{
    // Метод ДОЛЖЕН быть public static и возвращать строку вызова себя (для повтора)
    // или пустую строку (чтобы деактивироваться)
    public static function run(): string
    {
        try {
            // Ограничение по времени — агент не должен выполняться дольше ~30 сек
            // иначе он заблокирует следующий HTTP-запрос
            static::processChunk();
        } catch (\Throwable $e) {
            // Логируем но НЕ пробрасываем — так агент завершит цикл предсказуемо
            \Bitrix\Main\Diag\Debug::writeToFile($e->getMessage(), '', '/bitrix/my_module_agent.log');
        }

        // Возврат строки = агент повторится через AGENT_INTERVAL секунд
        return '\MyVendor\MyModule\Agent::run();';
    }
}
```

### IS_PERIOD = 'N' vs 'Y'

| Значение | Поведение |
|----------|-----------|
| `'N'` | Следующий запуск считается от текущего момента выполнения. Дрейф накапливается |
| `'Y'` | Следующий запуск считается от предыдущего `NEXT_EXEC`. Это ближе к фиксированному расписанию |

Для фиксированного периодического расписания выбирай `IS_PERIOD = 'Y'`.

### Gotchas агентов

- **Агент не запускается при нулевом трафике** — если проект не переведён на cron-режим агентов, без трафика запусков не будет. В текущем core для cron есть `/bitrix/modules/main/tools/cron_events.php`
- **Функция, а не метод в NAME** — ядро делает `eval()`. Пиши именно строку с `;` на конце: `\Ns\Class::method();`
- **`MODULE_ID` не пустой** — если в записи агента указан `MODULE_ID` и это не `main`, ядро само делает `CModule::IncludeModule($moduleId)` до `eval()`. Внутри метода вручную подключай модуль только если код живёт вне обычного модульного контекста
- **Не кидай исключения наружу** — ядро логирует `Throwable`, но такой агент не завершает нормальный цикл обновления записи. Практически это всё равно плохой сценарий: агент зависнет до следующей попытки после lock-window
- **LOCK_TIME = 600 сек** — параллельный запуск одного агента блокируется на 10 минут

---

## Файловая система (IO)

`Bitrix\Main\IO` — обёртка над файловой системой с нормализацией путей, кодировками (UTF-8 логические / cp1251 физические на Windows) и безопасностью (блокирует `..`, `null byte`, Unicode-спуфинг Right-to-Left).

**Все пути — абсолютные**. Используй `Application::getDocumentRoot()` как базу.

```php
use Bitrix\Main\Application;
use Bitrix\Main\IO\File;
use Bitrix\Main\IO\Directory;
use Bitrix\Main\IO\Path;
use Bitrix\Main\IO\FileNotFoundException;

$root = Application::getDocumentRoot(); // '/var/www/html'

// === File — работа с файлами ===

// Статические хелперы (самый простой способ)
$exists   = File::isFileExists($root . '/local/php_interface/init.php');
$content  = File::getFileContents($root . '/local/config/settings.json');
File::putFileContents($root . '/local/logs/errors.log', $text);
File::putFileContents($root . '/local/logs/errors.log', $text, File::APPEND);
File::deleteFile($root . '/tmp/old_file.tmp');

// Объектный API
$file = new File($root . '/local/files/report.csv');

if ($file->isExists()) {
    echo $file->getSize();           // int/float байт
    echo $file->getModificationTime(); // unix timestamp
    echo $file->getContentType();    // 'text/csv' через finfo
}

$file->putContents($csvData);           // перезапись; создаст директорию если нет
$file->putContents($more, File::APPEND); // дозапись
$file->delete();

// Низкоуровневый доступ (для больших файлов)
$fp = $file->open('r');   // 'r', 'w', 'a' и т.д. (ядро добавляет 'b' автоматически)
// ... работа с $fp через fread/fwrite ...
$file->close();

// === Directory — работа с директориями ===

$dir = new Directory($root . '/local/cache/my_module');

if (!$dir->isExists()) {
    $dir->create(); // mkdir -p с BX_DIR_PERMISSIONS
}

// Создать поддиректорию
$subDir = $dir->createSubdirectory('2024');

// Список содержимого
foreach ($dir->getChildren() as $entry) {
    if ($entry instanceof File) {
        echo $entry->getName() . ': ' . $entry->getSize() . "\n";
    } elseif ($entry instanceof Directory) {
        echo '[DIR] ' . $entry->getName() . "\n";
    }
}

$dir->delete();                          // рекурсивное удаление

// Статика
Directory::createDirectory($path);       // mkdir -p
Directory::deleteDirectory($path);       // rm -rf
Directory::isDirectoryExists($path);     // bool

// === Path — манипуляции с путями ===

Path::combine($root, '/local', 'files/', 'doc.pdf');
// → '/var/www/html/local/files/doc.pdf' (normalize внутри)

Path::normalize('/var/www/../www/html/./test');  // → '/var/www/html/test'
Path::validate('/var/www/html/file.txt');         // true — безопасный путь
Path::validateFilename('my_file (1).pdf');        // true — безопасное имя файла
Path::getName('/var/www/html/file.txt');           // → 'file.txt'
Path::getExtension('/var/www/html/file.txt');      // → 'txt'
Path::getDirectory('/var/www/html/file.txt');      // → '/var/www/html'

// Относительный → абсолютный
Path::convertRelativeToAbsolute('/local/config.php');
// → DOCUMENT_ROOT . '/local/config.php'
```

### Исключения IO

```php
try {
    $content = (new File($path))->getContents();
} catch (\Bitrix\Main\IO\FileNotFoundException $e) {
    // файл не найден ($e->getPath() — путь)
} catch (\Bitrix\Main\IO\FileOpenException $e) {
    // не удалось открыть
} catch (\Bitrix\Main\IO\FileDeleteException $e) {
    // не удалось удалить
} catch (\Bitrix\Main\IO\InvalidPathException $e) {
    // путь содержит недопустимые символы или ../ за пределами корня
}
```

### Gotchas IO

- **`isSystem()` = true** — путь, начинающийся с `/bitrix/`, `/local/`, загрузочного dir (`upload/`). Это не исключение — просто маркер для проверки прав
- **`putContents` создаёт директорию автоматически** — не нужно делать mkdir вручную
- **`getChildren()` кидает `FileNotFoundException`** если директория не существует — проверяй `isExists()` перед вызовом
- **Windows**: пути хранятся в UTF-8 (logical), физически конвертируются в cp1251. В коде всегда работай с UTF-8 путями
- **Не используй `file_get_contents` / `file_put_contents` напрямую** — IO-классы корректно обрабатывают кодировки и создают промежуточные директории

---

---

## Source: `update-stepper.md`

# Bitrix Stepper + CLI — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с пошаговыми обновлениями данных через `Bitrix\Main\Update\Stepper` или с реальными CLI-командами текущего core.

## Audit note

Проверено по текущему core:
- `www/bitrix/modules/main/lib/update/stepper.php`
- `www/bitrix/bitrix.php`
- `www/bitrix/modules/main/lib/cli/command/*`

Ниже только то, что подтверждается этим ядром.

## Stepper: когда использовать

`Stepper` нужен для долгих обновлений данных порциями через агент. В docblock текущего класса прямо зафиксировано ограничение: используй его для задач, где не меняется схема БД.

Типовые случаи:
- переиндексация или пересчёт существующих записей;
- заполнение новых полей у большого объёма данных;
- перенос или нормализация содержимого без `ALTER TABLE`.

Не тащи `Stepper` в роль универсальной миграционной системы для DDL. Для изменений таблиц в core нет отдельного встроенного migration-framework.

## Базовый контракт

```php
namespace Vendor\Module\Update;

use Bitrix\Main\Update\Stepper;

final class DataFixStepper extends Stepper
{
    protected static $moduleId = 'vendor.module';

    public static function getTitle(): string
    {
        return 'Исправление данных Vendor.Module';
    }

    public function execute(array &$option): bool
    {
        $lastId = (int)($option['lastId'] ?? 0);
        $limit = 100;

        $rows = MyTable::getList([
            'filter' => ['>ID' => $lastId],
            'order' => ['ID' => 'ASC'],
            'limit' => $limit,
            'select' => ['ID', 'NAME'],
        ])->fetchAll();

        if (!$rows)
        {
            return self::FINISH_EXECUTION;
        }

        foreach ($rows as $row)
        {
            // Обновляем порцию данных.
            $lastId = (int)$row['ID'];
        }

        $option['lastId'] = $lastId;
        $option['steps'] = (int)($option['steps'] ?? 0) + count($rows);
        $option['count'] = (int)($option['count'] ?? 0) + count($rows);

        return self::CONTINUE_EXECUTION;
    }
}
```

Подтверждённые детали из core:
- `execute(array &$option)` должен вернуть `Stepper::CONTINUE_EXECUTION` или `Stepper::FINISH_EXECUTION`;
- прогресс и служебные данные хранятся в `Option` под категорией `main.stepper.<moduleId>`;
- `steps`, `count`, `title`, `lastTime`, `totalTime`, `thresholdTime`, `delayCoefficient` реально используются ядром.

## bind() и bindClass()

В текущем core сигнатуры такие:

```php
public static function bind($delay = 300, $withArguments = [])
public static function bindClass($className, $moduleId, $delay = 300, $withArguments = [])
```

Это важно: третий аргумент `bindClass()` — не массив параметров, а именно задержка в секундах.

```php
use Vendor\Module\Update\DataFixStepper;

// Вариант через shortcut текущего класса.
DataFixStepper::bind(300, [42, 'full']);

// Вариант через общий helper.
\Bitrix\Main\Update\Stepper::bindClass(
    DataFixStepper::class,
    'vendor.module',
    300,
    [42, 'full']
);
```

Аргументы сериализуются в строку вызова агента через `makeArguments()`. В базовой реализации надёжно поддерживаются строки и числа.

## outerParams и execAgent()

`bind()` и `bindClass()` передают `$withArguments` в `execAgent(...)`, а затем в `$this->outerParams`.

```php
public function execute(array &$option): bool
{
    [$tenantId, $mode] = $this->getOuterParams() + [0, 'default'];

    // ...
}
```

`execAgent()` в текущем core:
- поднимает состояние из `Option::get("main.stepper.<moduleId>", $className)`;
- вызывает `execute($option)`;
- при `CONTINUE_EXECUTION` сохраняет состояние и возвращает следующую строку агента;
- при `FINISH_EXECUTION` удаляет состояние через `Option::delete(...)` и возвращает пустую строку.

Если шаг работал дольше `thresholdTime` (по умолчанию `20.0`), ядро увеличивает период следующего запуска через глобальный `$pPERIOD`.

## Прогресс

Реальный ключ хранения:

```php
use Bitrix\Main\Config\Option;

$raw = Option::get('main.stepper.vendor.module', DataFixStepper::class);
if ($raw !== '')
{
    $state = unserialize($raw, ['allowed_classes' => false]);
}
```

Пример полезных полей:
- `steps`
- `count`
- `title`
- `lastId`
- `lastTime`
- `totalTime`
- `thresholdTime`
- `delayCoefficient`

Для UI ядро использует `Stepper::getHtml(...)` и `Stepper::checkRequest()`.

## CLI в текущем core

В этом проекте точка входа CLI подтверждена как:

```bash
php www/bitrix/bitrix.php <command>
```

Не пиши в reference, что здесь гарантированно есть `bitrix/bin/console`: в текущем snapshot найден именно `www/bitrix/bitrix.php`.

Подтверждённые команды из `main/lib/cli/command/*`:
- `make:controller`
- `make:component`
- `make:tablet`
- `orm:annotate`
- `update:languages`
- `update:modules`
- `update:versions`
- `messenger:consume-messages`
- `dev:locator-codes`
- `dev:module-skeleton`

Примеры:

```bash
php www/bitrix/bitrix.php make:controller entity partner.module
php www/bitrix/bitrix.php make:tablet my_table partner.module
php www/bitrix/bitrix.php orm:annotate
```

`make:tablet`, а не `make:table`.

## Gotchas

- Не передавай массив третьим аргументом в `bindClass()`: это `delay`, а не `withArguments`.
- Не описывай `Stepper` как инструмент для изменения схемы БД. В самом core написано обратное.
- Если нужно передать сложные структуры, переопредели `makeArguments()` и аккуратно восстанавливай их в `getOuterParams()`.
- `bind(0, ...)` и `bindClass(..., 0, ...)` могут запустить шаг немедленно через `execAgent()` до постановки агента.
- CLI-команды нужно привязывать к реальному entrypoint проекта. В этом core это `www/bitrix/bitrix.php`.

---


## Source: `project-optimization-audit.md`

# Аудит оптимизаций Bitrix-проекта — compact

Открывай, когда пользователь просит “изучи проект и скажи как оптимизировать”, “какие оптимизации уже есть”, “найди тормоза”, “проверь кеши/производительность”. Это сквозной маршрут поверх `cache-infra`, `composite-cache`, `perfmon`, components/templates, operations и commerce references.

## Формат ответа

```text
1. Что уже оптимизировано и где evidence.
2. Какие оптимизации есть, но опасны или неполны.
3. Где bottlenecks: SQL/ORM/N+1, component/template, cache/composite, images/assets, agents/imports, frontend, shop.
4. Быстрые safe wins.
5. Что требует runtime/perfmon evidence.
6. Что нельзя менять вслепую.
```

## Быстрый read-only профиль

```bash
rg -n 'IncludeComponent\(|CACHE_TYPE|CACHE_TIME|CACHE_GROUPS|StartResultCache|AbortResultCache|setResultCacheKeys|RegisterTag|clearByTag|TaggedCache|Composite|createFrame|CIBlockElement::GetList|CIBlockSection::GetList|::getList\(|DataManager::getList|ResizeImageGet|Asset::getInstance|addCss|addJs|CAgent::AddAgent|Stepper|cron|import|exchange|clearCache|cleanDir' \
  . --glob '*.php' --glob '*.js' --glob '!upload/**' --glob '!bitrix/cache/**' --glob '!www/bitrix/cache/**'
```

```bash
rg -n 'foreach\s*\(|while\s*\(|Option::get|Loader::includeModule|GetUserGroupArray|IsAuthorized|GetList|::getList|ResizeImageGet' \
  local/templates bitrix/templates www/bitrix/templates local/components \
  --glob 'template.php' --glob 'result_modifier.php' --glob 'component_epilog.php'
```

## Карта оптимизаций

| Слой | Evidence | Риск ошибки |
|---|---|---|
| Component cache | `CACHE_TYPE/TIME/GROUPS`, `StartResultCache` | общий cache key, `CACHE_TYPE=N` без причины, забытый `CACHE_GROUPS` |
| Tagged/managed cache | `TaggedCache`, `RegisterTag`, `clearByTag` | слишком широкий `cleanDir/cleanAll`, разные `cacheDir` |
| Composite | `setFrameMode`, `createFrame`, `X-Bitrix-Composite` | персональные данные в static HTML, `setFrameMode(true)` принят за dynamic boundary |
| SQL/ORM | `GetList/getList`, perfmon SQL | N+1, select `*`, нет `limit`, full scan |
| Templates/frontend | `template.php`, `Asset`, images | тяжёлая логика в шаблоне, дубли assets, resize без стратегии |
| Agents/imports | `CAgent`, `Stepper`, imports | hit-mode, нет batch/resume/log, полный cache clear после импорта |
| Shop/catalog/sale | catalog/sale components/API | raw SQL, скидки/остатки/корзина в циклах, facet/search не обновлён |

## Runtime/perfmon evidence

Используй `perfmon_hit_list.php`, `perfmon_sql_list.php`, `perfmon_cache_list.php`, `perfmon_comp_list.php`, `perfmon_explain.php`, headers `X-Bitrix-Composite`, `?ncc=1`, browser network. Без runtime evidence формулируй как “кандидат на оптимизацию”, а не “точно тормозит”.

## Не советовать первым шагом

- Redis/Memcached/CDN без доказательства bottleneck.
- Глобальный cache clear или отключение кеша.
- Composite без проверки персонализации.
- DB index без `EXPLAIN`/perfmon.
- Полный reindex/rebuild на production без окна и rollback.

---

## Source: `perfmon.md`

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
- Для тяжёлых инфоблоков и компонентных страниц сочетай `perfmon` с `cache-infra.md`, `components.md` и `iblocks.md`.

---

## Source: `operations-runbook.md`

# Operations Runbook без магазина — справочник

> Reference для Bitrix-скилла. Загружай для задач эксплуатации: переносы между стендами, агенты/cron, stepper, импорты, резервное копирование, perf diagnostics, обновления core, права и сопровождение.

## Содержание
- Code-first подход
- Перед изменениями
- Agents/cron/stepper
- Импорты и повторный запуск
- Перенос между стендами
- Обновления core
- Производительность
- Backup/monitoring
- Common mistakes

## Code-first подход

Для эксплуатационных задач предпочитай воспроизводимое изменение:

- migration/install step;
- CLI command;
- agent/stepper;
- module option change через код;
- documented rollback.

Админские клики годятся как диагностика, но не как единственный delivery path.

## Перед изменениями

Проверь:

1. какие модули реально установлены;
2. какие данные будут изменены;
3. есть ли backup/rollback;
4. затронуты ли кеши/индексы/права;
5. нужен ли maintenance window;
6. можно ли запустить операцию повторно без дублей.

## Agents/cron/stepper

| Сценарий | Выбор |
|---|---|
| короткая регулярная задача | agent |
| тяжёлая пакетная миграция | stepper |
| системный cron проекта | CLI command/script |
| повторяемый импорт | idempotent job + log + resume state |
| обновление ядра/модуля | update step + rollback note |

Проверяй `update-stepper.md`, `cache-infra.md`, `perfmon.md`.

## Импорты и повторный запуск

Хороший импорт:

- имеет external id;
- идемпотентен;
- пишет лог ошибок;
- умеет batching;
- не держит всё в памяти;
- обновляет индексы/кеши после завершения;
- различает validation error и transport/runtime error.

## Перенос между стендами

Проверь:

- module versions;
- site ids and languages;
- templates and wizard assets;
- iblock types/ids vs XML_ID/API_CODE;
- HL block names/table names;
- user groups and rights;
- files and clouds `HANDLER_ID`;
- agents and options;
- urlrewrite/SEF;
- search/SEO rebuild needs.

## Обновления core

Перед обновлением:

1. зафиксировать версию модулей;
2. найти project overrides стандартных компонентов;
3. проверить, какие stock templates копировались;
4. снять список custom event handlers;
5. проверить PHP version compatibility;
6. после обновления пройти smoke matrix.

## Производительность

Смотри:

- perfmon SQL/hit/cache reports;
- N+1 in components/templates;
- repeated `Loader::includeModule`/option calls in loops;
- ORM runtime fields and indexes;
- cache keys and personalization;
- heavy logic in template;
- AJAX split for dynamic blocks.

## Backup/monitoring

В текущем core есть:

- `bitrixcloud` для backup/monitoring policy;
- `clouds` для внешних bucket-ов;
- `security` checks;
- `perfmon` diagnostics.

Не путай `bitrixcloud` monitoring/backup с обычным file storage из `clouds`.

## Common mistakes

- Делать одноразовый скрипт без повторного запуска и rollback.
- Хардкодить внутренние IDs вместо XML_ID/code/table names.
- Не очищать кеш/индексы после массовой операции.
- Переносить файлы без учёта `clouds` and `HANDLER_ID`.
- Обновлять core и не сверять copied templates со stock changes.

## С чем читать вместе

- Update stepper — `update-stepper.md`
- Cache/perf — `cache-infra.md`, `perfmon.md`
- Import/export — `import-export.md`
- Cloud files — `clouds.md`
- Bitrix Cloud — `bitrixcloud.md`
- Security — `security.md`

---
