# Bitrix Кеширование, Агенты, Файловая система — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с кешированием (Data\Cache), тегированным кешем (TaggedCache), агентами (CAgent) или файловой системой (IO).

## Содержание
- Data\Cache: два режима (data/output), полный API, gotchas
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
