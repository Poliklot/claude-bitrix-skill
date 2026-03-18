# Bitrix Модули, Loader, Application — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с созданием модуля, Loader, PSR-4 автозагрузкой, Application, ServiceLocator, Config\Option или локализацией.

## Содержание
- Application и ServiceLocator
- Config\Option — настройки модуля
- Локализация (Loc)
- Структура модуля: include.php, install/index.php, version.php, .settings.php
- Инсталлятор: CModule, InstallDB/UnInstallDB
- Loader: requireModule, registerNamespace, local/ vs bitrix/

---

## Application и сервис-локатор

`Application::getInstance()` — синглтон, точка входа во всё приложение. Через него получаешь соединение с БД, кеш, контекст запроса. `ServiceLocator` — DI-контейнер Bitrix: регистрируешь сервисы один раз (обычно в `include.php` модуля), получаешь их везде по имени. Это позволяет избежать `new MyService()` разбросанных по коду и упрощает замену реализаций.

```php
$app = \Bitrix\Main\Application::getInstance();

// ServiceLocator — регистрируй в include.php модуля
$serviceLocator = \Bitrix\Main\DI\ServiceLocator::getInstance();
$serviceLocator->addInstanceLazy('myVendor.orderService', [
    'constructor' => fn() => new \MyVendor\MyModule\OrderService(),
]);
// Получай где угодно
$service = $serviceLocator->get('myVendor.orderService');

// Запрос и ответ — безопасный способ получить параметры
$request = $app->getContext()->getRequest();
$id      = (int)$request->getQuery('id');    // GET-параметр
$title   = (string)$request->getPost('title'); // POST-параметр
// Никогда не используй $_GET/$_POST напрямую в D7-коде
```

---

## Config\Option — настройки модуля

Хранятся в таблице `b_option`. Используй для конфигурационных значений модуля — API-ключи, лимиты, флаги. Не используй для пользовательских данных или данных, которые меняются часто (для этого есть ORM-таблицы).

```php
use Bitrix\Main\Config\Option;

$value = Option::get('my.module', 'API_KEY', '');          // третий аргумент — дефолт
Option::set('my.module', 'API_KEY', $newKey);
Option::delete('my.module', ['name' => 'API_KEY']);
```

---

## Локализация

`Loc::getMessage()` ищет ключ в lang-файле рядом с текущим PHP-файлом. `loadMessages(__FILE__)` говорит системе: "загрузи lang-файл для этого файла". Без вызова `loadMessages` ключи будут пустыми.

```php
use Bitrix\Main\Localization\Loc;

Loc::loadMessages(__FILE__); // вызывай в начале каждого файла где нужны переводы

echo Loc::getMessage('MY_MODULE_GREETING', ['#NAME#' => 'Иван']);
// lang/ru/my_file.php: $MESS['MY_MODULE_GREETING'] = 'Привет, #NAME#!';
// lang/en/my_file.php: $MESS['MY_MODULE_GREETING'] = 'Hello, #NAME#!';
```

---


---
## Модули

### Архитектурный смысл

Модуль в Bitrix — это изолированная библиотека функциональности с собственной схемой БД, правами, событиями и PSR-4 namespace. Каждый модуль регистрируется в системе через инсталлятор. `Loader::includeModule()` — единственная точка входа; без этого вызова классы модуля **не появятся** в автозагрузчике, даже если файлы физически присутствуют.

**Поиск модуля** — сначала `local/modules/`, потом `bitrix/modules/`. Это позволяет переопределять стандартные модули в `local/`.

**PSR-4 автозагрузка** регистрируется автоматически:
- Bitrix-модуль `iblock` → namespace `Bitrix\Iblock` → `/bitrix/modules/iblock/lib`
- Партнёрский модуль `vendor.mymodule` → namespace `Vendor\Mymodule` → `/bitrix/modules/vendor.mymodule/lib`
- Файл `lib/service/ordermanager.php` → класс `Vendor\Mymodule\Service\OrderManager`

### Структура модуля

```
local/modules/vendor.mymodule/
├── include.php              ← точка входа, подключается Loader-ом
├── .settings.php            ← конфигурация ServiceLocator, роутов, REST
├── lib/                     ← PSR-4 корень
│   ├── OrderTable.php       ← DataManager: ПРЯМО в корне lib (Bitrix-way)
│   ├── EventHandler.php     ← обработчики событий — тоже в корне
│   ├── Controller/          ← capital C — как в реальных модулях ядра
│   │   └── Order.php        ← Vendor\Mymodule\Controller\Order
│   └── service/             ← lowercase — как в реальных модулях
│       └── OrderService.php ← Vendor\Mymodule\Service\OrderService
└── install/
    ├── index.php            ← класс-инсталлятор, extends CModule
    ├── version.php          ← VERSION, VERSION_DATE
    └── db/
        ├── mysql/
        │   ├── install.sql
        │   └── uninstall.sql
        └── pgsql/
```

---

### Канонические соглашения: где что лежит

| Тип класса | Путь в lib/ | Пример файла | Пример класса |
|---|---|---|---|
| DataManager (ORM-таблица) | `lib/` корень | `lib/OrderTable.php` | `Vendor\Module\OrderTable` |
| Controller (AJAX/REST) | `lib/Controller/` | `lib/Controller/Order.php` | `Vendor\Module\Controller\Order` |
| Сервис | `lib/service/` | `lib/service/OrderService.php` | `Vendor\Module\Service\OrderService` |
| Обработчик событий | `lib/` корень | `lib/EventHandler.php` | `Vendor\Module\EventHandler` |
| Интеграция с другими модулями | `lib/Integration/` | `lib/Integration/Catalog.php` | `Vendor\Module\Integration\Catalog` |
| Вспомогательные классы | `lib/helper/` | `lib/helper/Formatter.php` | `Vendor\Module\Helper\Formatter` |
| Внутренние детали | `lib/internals/` | `lib/internals/...` | не публичный API |
| Legacy без PSR-4 | `classes/general/` | `classes/general/myclass.php` | регистрируется в `include.php` |

**Регистр директорий:** `Controller/` — capital C (как в ядре), `service/` и `helper/` — lowercase.

---

### Анти-паттерны (что НЕ делать)

```
# Это Laravel/Symfony-паттерны — в Bitrix так НЕ делают:
lib/model/OrderTable.php      → правильно: lib/OrderTable.php
lib/models/                   → нет такой директории в Bitrix-модулях
lib/repository/               → Repository слой в Bitrix не используется
lib/Repositories/             → аналогично
lib/Http/Controllers/         → нет, контроллеры в lib/Controller/
```

---

### Пример: модуль vendor.favorites

```
local/modules/vendor.favorites/
├── include.php
├── .settings.php
├── lib/
│   ├── FavoriteTable.php        ← DataManager (lib root!)
│   ├── EventHandler.php         ← обработчики событий
│   ├── Controller/
│   │   └── Favorite.php         ← AJAX-контроллер
│   └── service/
│       └── FavoriteService.php  ← бизнес-логика
└── install/
    ├── index.php
    ├── version.php
    └── db/mysql/
        ├── install.sql
        └── uninstall.sql
```

### include.php

```php
<?php
// include.php — вызывается при Loader::includeModule()
// Обычно пустой или подключает legacy-файлы
// PSR-4 регистрируется автоматически, include.php не обязан ничего делать

use Bitrix\Main\Localization\Loc;
Loc::loadMessages(__FILE__);
```

### install/index.php — инсталлятор

Имя класса инсталлятора = MODULE_ID с заменой `.` на `_`. Пример: `vendor.mymodule` → класс `vendor_mymodule`. Это жёсткое требование ядра — `CModule` ищет класс именно по такому имени.

```php
<?php
use Bitrix\Main\Localization\Loc;
use Bitrix\Main\ModuleManager;
use Bitrix\Main\EventManager;
use Bitrix\Main\Application;

Loc::loadMessages(__FILE__);

class vendor_mymodule extends CModule
{
    public $MODULE_ID = 'vendor.mymodule';
    public $MODULE_VERSION;
    public $MODULE_VERSION_DATE;
    public $MODULE_NAME;
    public $MODULE_DESCRIPTION;

    public function __construct()
    {
        $version = [];
        include __DIR__ . '/version.php';
        $this->MODULE_VERSION      = $version['VERSION'];
        $this->MODULE_VERSION_DATE = $version['VERSION_DATE'];
        $this->MODULE_NAME         = Loc::getMessage('VENDOR_MYMODULE_NAME');
        $this->MODULE_DESCRIPTION  = Loc::getMessage('VENDOR_MYMODULE_DESCRIPTION');
    }

    public function InstallDB(): bool
    {
        $connection = Application::getConnection();
        $connection->queryExecute(
            file_get_contents(__DIR__ . '/db/' . $connection->getType() . '/install.sql')
        );

        ModuleManager::registerModule($this->MODULE_ID);

        // Регистрация обработчиков событий (хранится в БД)
        $em = EventManager::getInstance();
        $em->registerEventHandler('main', 'OnBeforeUserAdd', $this->MODULE_ID,
            \Vendor\Mymodule\EventHandler::class, 'onBeforeUserAdd'
        );

        return true;
    }

    public function UnInstallDB(array $params = []): bool
    {
        $em = EventManager::getInstance();
        $em->unRegisterEventHandler('main', 'OnBeforeUserAdd', $this->MODULE_ID,
            \Vendor\Mymodule\EventHandler::class, 'onBeforeUserAdd'
        );

        ModuleManager::unRegisterModule($this->MODULE_ID);
        return true;
    }

    public function InstallFiles(): bool { return true; }
    public function UnInstallFiles(): bool { return true; }

    public function DoInstall(): void
    {
        $this->InstallDB();
        $this->InstallFiles();
    }

    public function DoUninstall(): void
    {
        $this->UnInstallDB();
        $this->UnInstallFiles();
    }
}
```

### .settings.php — конфигурация модуля

```php
<?php
// .settings.php читается ServiceLocator при загрузке модуля
return [
    // Конфигурация Engine\Controller (D7 MVC)
    'controllers' => [
        'value' => [
            'defaultNamespace' => '\Vendor\Mymodule\Controller',
            'namespaces' => [
                '\Vendor\Mymodule\Controller' => 'api',  // /vendor.mymodule/api/...
            ],
            'restIntegration' => [
                'enabled' => true,  // методы контроллеров доступны через REST
            ],
        ],
        'readonly' => true,
    ],
];
```

### Repository паттерн

> **Bitrix-way:** Service вызывает DataManager напрямую — это стандарт. Repository-паттерн — дополнительный слой абстракции, оправдан только для сложных модулей с несколькими хранилищами (DB + Redis + Cookie). В типовом модуле — избыточен и выглядит «не по-битриксовому».

Repository изолирует работу с хранилищем (DB, Cookie, Cache) от бизнес-логики. Архитектурная цепочка: **Controller → Service → Repository → DataManager/Cookie**.

Это позволяет:
- менять хранилище (DB → Redis) без изменения сервиса
- тестировать сервис с mock-репозиторием
- не дублировать ORM-запросы по всему коду

```php
namespace Vendor\Favorites\Repository;

use Vendor\Favorites\Model\FavoriteTable;

final class FavoriteRepository
{
    public function findByUserId(int $userId): array
    {
        return FavoriteTable::getList([
            'select' => ['ID', 'PRODUCT_ID', 'CREATED_AT'],
            'filter' => ['=USER_ID' => $userId],
            'order'  => ['ID' => 'DESC'],
        ])->fetchAll();
    }

    public function exists(int $userId, int $productId): bool
    {
        return FavoriteTable::getCount([
            '=USER_ID'    => $userId,
            '=PRODUCT_ID' => $productId,
        ]) > 0;
    }

    public function add(int $userId, int $productId): \Bitrix\Main\ORM\Data\AddResult
    {
        return FavoriteTable::add([
            'USER_ID'    => $userId,
            'PRODUCT_ID' => $productId,
            'CREATED_AT' => new \Bitrix\Main\Type\DateTime(),
        ]);
    }

    public function deleteByUserAndProduct(int $userId, int $productId): \Bitrix\Main\ORM\Data\DeleteResult
    {
        $row = FavoriteTable::getList([
            'select' => ['ID'],
            'filter' => ['=USER_ID' => $userId, '=PRODUCT_ID' => $productId],
            'limit'  => 1,
        ])->fetch();

        if (!$row) {
            return new \Bitrix\Main\ORM\Data\DeleteResult();
        }

        return FavoriteTable::delete($row['ID']);
    }
}
```

Регистрация в `.settings.php` модуля для DI через ServiceLocator:

```php
'services' => [
    'value' => [
        'Vendor.Favorites.FavoriteRepository' => [
            'className' => \Vendor\Favorites\Repository\FavoriteRepository::class,
        ],
        'Vendor.Favorites.FavoriteService' => [
            'className' => \Vendor\Favorites\Service\FavoriteService::class,
            'constructorParams' => function() {
                return [
                    \Bitrix\Main\DI\ServiceLocator::getInstance()
                        ->get('Vendor.Favorites.FavoriteRepository'),
                ];
            },
        ],
    ],
],
```

Использование в сервисе:

```php
namespace Vendor\Favorites\Service;

use Vendor\Favorites\Repository\FavoriteRepository;
use Bitrix\Main\DI\ServiceLocator;

final class FavoriteService
{
    public function __construct(
        private readonly FavoriteRepository $repository
    ) {}

    public static function getInstance(): self
    {
        return ServiceLocator::getInstance()->get('Vendor.Favorites.FavoriteService');
    }

    public function toggle(int $userId, int $productId): bool
    {
        if ($this->repository->exists($userId, $productId)) {
            $this->repository->deleteByUserAndProduct($userId, $productId);
            return false; // удалено
        }
        $this->repository->add($userId, $productId);
        return true; // добавлено
    }
}
```

---

### Loader — тонкости

```php
use Bitrix\Main\Loader;

// Возвращает bool, кешируется — второй вызов бесплатный
if (!Loader::includeModule('vendor.mymodule')) {
    // модуль не установлен или не найден
    return;
}

// requireModule() — то же самое, но бросает LoaderException при неудаче
Loader::requireModule('vendor.mymodule');

// Ручная регистрация namespace (редко нужно, обычно автоматически)
Loader::registerNamespace('Vendor\\Extra', '/absolute/path/to/lib');

// Регистрация классов вручную (legacy-классы без PSR-4)
Loader::registerAutoLoadClasses('vendor.mymodule', [
    '\COldClass' => 'classes/oldclass.php',
]);
```

**Gotcha:** `local/modules/` имеет приоритет над `bitrix/modules/`. Если в `local/` есть модуль с тем же ID, он загрузится вместо стандартного — это механизм кастомизации.

---

## Мультисайтовость

### Константы SITE_ID, LANGUAGE_ID, SERVER_NAME

```php
// SITE_ID — строковый идентификатор текущего сайта (например 's1', 'ru', 'en')
// Доступна только после подключения ядра Bitrix (после require 'bitrix/modules/main/include.php')
// Никогда не хардкодь 's1' — используй константу SITE_ID

echo SITE_ID;      // 's1' / 'ru' / 'en' — зависит от настроек
echo LANGUAGE_ID;  // 'ru' / 'en' — язык текущего сайта
echo SERVER_NAME;  // 'example.com' — домен текущего сайта

// Использование в запросах и фильтрах:
$filter = ['SITE_ID' => SITE_ID, 'ACTIVE' => 'Y'];
```

### SiteTable D7 — список сайтов, поиск по домену

```php
use Bitrix\Main\SiteTable;

// Получить все активные сайты
$sites = SiteTable::getList([
    'filter' => ['=ACTIVE' => 'Y'],
    'select' => ['LID', 'NAME', 'SERVER_NAME', 'LANGUAGE_ID', 'DIR', 'SORT'],
    'order'  => ['SORT' => 'ASC'],
])->fetchAll();

foreach ($sites as $site) {
    // LID — строковый ID сайта ('s1', 'ru', ...)
    // SERVER_NAME — домен ('example.com')
    // LANGUAGE_ID — 'ru', 'en', ...
    // DIR — корневая директория ('/')
}

// Найти сайт по домену
$site = SiteTable::getList([
    'filter' => ['=SERVER_NAME' => 'example.com'],
    'select' => ['LID', 'NAME', 'LANGUAGE_ID'],
    'limit'  => 1,
])->fetch();

if ($site) {
    $siteId = $site['LID'];
}
```

### CSite::GetByID — legacy

```php
// Legacy-способ получить данные сайта
$siteRes = CSite::GetByID(SITE_ID);
$siteData = $siteRes->Fetch();
// Поля: LID, ACTIVE, NAME, SERVER_NAME, DIR, LANGUAGE_ID, DOC_ROOT, ...

// Получить список сайтов (legacy)
$allSites = CSite::GetList('SORT', 'ASC', ['ACTIVE' => 'Y']);
while ($s = $allSites->Fetch()) { /* ... */ }
```

### Loc::getMessage() с явным языком

```php
use Bitrix\Main\Localization\Loc;

// Стандартный способ — язык определяется из LANGUAGE_ID автоматически
Loc::loadMessages(__FILE__);
echo Loc::getMessage('MY_KEY');

// Получить сообщение для явно заданного языка
// (полезно когда нужно отправить уведомление на языке пользователя, не текущего сайта)
$messageInEnglish = Loc::getMessageByLang('MY_KEY', 'en');
$messageInRussian = Loc::getMessageByLang('MY_KEY', 'ru');

// Загрузить lang-файл для конкретного языка явно
Loc::loadLanguageFile(__FILE__, 'en');
```

### Переключение контекста сайта

```php
use Bitrix\Main\Application;
use Bitrix\Main\Context;

$app = Application::getInstance();
$context = $app->getContext();

// Получить текущий SITE_ID из контекста
$currentSiteId = $context->getSite();    // string, например 's1'
$currentLangId = $context->getLanguage(); // string, например 'ru'

// Переключить контекст на другой сайт (например в агентах, консольных скриптах)
// Используй с осторожностью — меняет глобальный контекст запроса
$context->setSite('en');
$context->setLanguage('en');

// После выполнения логики — восстанови исходный контекст
$context->setSite(SITE_ID);
$context->setLanguage(LANGUAGE_ID);
```

### Настройки модуля per-site (COption)

```php
use Bitrix\Main\Config\Option;

// Получить настройку для конкретного сайта
// четвёртый параметр — SITE_ID (без него вернётся общая настройка)
$value = Option::get('my.module', 'api_key', '', SITE_ID);

// D7-обёртка COption::GetOptionString (legacy-стиль, но с siteId)
$value = COption::GetOptionString('my.module', 'api_key', 'default', SITE_ID);

// Сохранить настройку для конкретного сайта
Option::set('my.module', 'api_key', 'NEW_KEY', SITE_ID);
COption::SetOptionString('my.module', 'api_key', 'NEW_KEY', '', SITE_ID);

// Получить общую настройку (не привязанную к сайту) — не передавай siteId
$globalValue = Option::get('my.module', 'global_setting', 'default');

// Удалить настройку сайта
Option::delete('my.module', ['name' => 'api_key', 'site_id' => SITE_ID]);
```

### Языковые файлы per-site (BCC)

```
Структура lang-файлов для мультиязычного модуля:
local/modules/my.module/lang/
├── ru/
│   └── lib/
│       └── myclass.php    ← $MESS['MY_CLASS_TITLE'] = 'Заголовок';
└── en/
    └── lib/
        └── myclass.php    ← $MESS['MY_CLASS_TITLE'] = 'Title';
```

```php
// В lib/myclass.php
use Bitrix\Main\Localization\Loc;

Loc::loadMessages(__FILE__);
// Bitrix автоматически ищет lang/LANGUAGE_ID/lib/myclass.php
// относительно расположения текущего PHP-файла

class MyClass
{
    public function getTitle(): string
    {
        return Loc::getMessage('MY_CLASS_TITLE');
        // вернёт 'Заголовок' на ru, 'Title' на en
    }
}
```

### Gotchas мультисайтовости

- **`SITE_ID` доступна только после подключения ядра**: после `require $_SERVER['DOCUMENT_ROOT'] . '/bitrix/modules/main/include.php'`. В CLI-скриптах без пролога константа не определена — определяй вручную `define('SITE_ID', 's1')`.
- **Не хардкоди `'s1'`** — это ID сайта по умолчанию только в демо-установках. В реальных проектах сайты часто имеют ID `'ru'`, `'en'`, `'by'` и т.д. Всегда используй константу `SITE_ID`.
- **`SiteTable::getList()`** не возвращает DIR с trailing slash — сравнивай осторожно.
- **`COption`/`Option`** без явного `SITE_ID` сохраняет в общие настройки (поле `SITE_ID = ''` в `b_option`). При чтении: если нет per-site значения, Bitrix fallback'ается на общее. Это поведение можно сломать если записать пустую строку как per-site значение.
- **`Loc::getMessageByLang()`** требует чтобы lang-файл был загружен для указанного языка. Если не загружен — вернёт пустую строку. Предварительно вызови `Loc::loadLanguageFile(__FILE__, $lang)`.
- **`$context->setSite()`** меняет контекст только внутри текущего запроса/процесса. Не влияет на другие запросы или агенты.

---

