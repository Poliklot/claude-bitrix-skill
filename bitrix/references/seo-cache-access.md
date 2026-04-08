# SEO, Кеш, Индексация, Доступ

> Audit note: ниже сверено с текущим core `main` + `seo`. В этой версии подтверждены `Bitrix\Seo\Sitemap\Job::findJob/addJob/markToRegenerate`, `Bitrix\Seo\RobotsFile`, `Bitrix\Seo\Sitemap\Internals\SitemapTable`, а для composite-сброса подтверждён `Bitrix\Main\Composite\Page`, не `Engine::clearByUrl()/clearAll()`.

## 1. Сброс кеша

### Виды кеша в Bitrix

| Вид | Где хранится | Класс |
|-----|-------------|-------|
| Файловый кеш компонентов | `/bitrix/cache/` | `\Bitrix\Main\Data\Cache` |
| Managed cache (ORM, таблицы) | `/bitrix/managed_cache/` | `\Bitrix\Main\Data\ManagedCache` |
| Статический HTML (composite) | `/bitrix/html_pages/` | `\Bitrix\Main\Composite\Page` |
| HTML-кеш страниц | `/bitrix/html_pages/` | управляется ядром |

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

Composite cache хранит финальный HTML в `/bitrix/html_pages/`. Сбрасывается:

```php
use Bitrix\Main\Composite\Page;

// Полный сброс HTML-кеша всего сайта
$page = Page::getInstance();
$page->deleteAll();

// Точечный сброс — через конкретный объект Page, когда известен cache key/URI.
// В текущем core НЕ подтверждены методы Engine::clearByUrl() / Engine::clearAll().
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
