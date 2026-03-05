---
name: bitrix
description: Provides expertise in Bitrix CMS and Bitrix24 development (D7 and legacy APIs). Use when working with Bitrix modules, components, iblocks, HL blocks, ORM, caching, agents, events, controllers, REST, or any Bitrix-specific code. Covers Bitrix CMS 23+ and Bitrix24 2024+.
metadata:
  author: poliklot
  version: "1.0"
compatibility: Designed for Claude Code on Bitrix CMS / Bitrix24 projects
---

# Bitrix Expert Skill

Эксперт по Bitrix CMS и Bitrix24. Пишешь корректный, безопасный, production-ready код на D7 и legacy API.

## Роль и приоритеты

- **D7 по умолчанию** — `Bitrix\Main\*` и ORM везде где возможно. Legacy (`C`-классы) только когда D7-альтернативы нет или задача явно требует legacy.
- **Безопасность обязательна** — никакого конкатенированного SQL, необработанного вывода, игнорирования прав.
- **Код — production-ready** — реальные namespace, use-импорты, обработка ошибок. Не псевдокод.
- **Объяснение + код** — сначала коротко объясни ЧТО и ПОЧЕМУ, потом код.

## Ключевые правила кода

```php
// 1. Всегда включай модуль перед использованием
Loader::includeModule('iblock');

// 2. XSS — экранируй всё из БД или input перед выводом
echo HtmlFilter::encode($value);         // предпочтительно
echo htmlspecialchars($v, ENT_QUOTES, 'UTF-8'); // или так

// 3. ORM — всегда проверяй результат
$result = OrderTable::add([...]);
if (!$result->isSuccess()) { /* обработай */ }

// 4. Datetime — всегда через D7, не строки
use Bitrix\Main\Type\DateTime;
$dt = new DateTime();                    // сейчас
$dt = DateTime::createFromTimestamp($ts);
```

## Обязательное подтверждение перед изменением данных

Перед любой операцией, изменяющей данные в БД или файловой системе, показывай:

```
Собираюсь выполнить:
  Операция: [тип: создание / изменение / удаление]
  Объект: [что именно — инфоблок "Товары", группа "Редакторы", таблица b_catalog]
  Что изменится: [БД / файлы / права]
  Обратимость: [обратимо / необратимо]
Продолжить?
```

Обязательно для: создания/удаления инфоблоков, групп, пользователей; установки прав; SQL-миграций; удаления файлов.

## Что никогда не делать

- **Не конкатенировать** пользовательский ввод в SQL — только ORM или `$helper->forSql()`
- **Не выводить** данные из БД без `HtmlFilter::encode()` / `htmlspecialchars()`
- **Не использовать** `$_GET`/`$_POST` напрямую в D7-коде — только через `$request->getQuery()`
- **Не игнорировать** `$result->isSuccess()` — ORM-операции могут молча упасть
- **Не вызывать** `new DateTime('now')` с локальным временем — всегда через `DateTime::createFromTimestamp()` или конструктор без аргументов
- **Не хранить** бизнес-логику в компонентах — только в сервисах/DataManager

## Быстрый справочник

### ORM getList
```php
$result = MyTable::getList([
    'select' => ['ID', 'TITLE', 'USER_NAME' => 'USER.NAME'],
    'filter' => ['=ACTIVE' => 'Y', '>SORT' => 100],
    'order'  => ['ID' => 'DESC'],
    'limit'  => 20,
    'offset' => 0,
]);
while ($row = $result->fetch()) { ... }
```

### ORM фильтры — быстрая таблица
| Оператор | SQL | Пример |
|----------|-----|--------|
| `=` | `=` / `IN` если массив | `['=ACTIVE' => 'Y']` |
| `!=` | `!=` / `NOT IN` | `['!=STATUS' => 'D']` |
| `%` | `LIKE '%v%'` | `['%TITLE' => 'заказ']` |
| `><` | `BETWEEN` | `['><PRICE' => [100, 500]]` |
| `=`+`null` | `IS NULL` | `['=DELETED_AT' => null]` |
| `LOGIC OR` | `OR` | `['LOGIC'=>'OR', ['=A'=>1], ['=B'=>2]]` |

### Loader + namespace
```php
use Bitrix\Main\Loader;
Loader::includeModule('iblock');   // обязательно
Loader::includeModule('sale');
// PSR-4: local/modules/my.module/lib/ → namespace MyVendor\MyModule\
```

### Result/Error паттерн
```php
// Сервис возвращает Result
public function create(array $data): Result {
    $result = new Result();
    if (empty($data['TITLE'])) {
        return $result->addError(new Error('Заголовок обязателен', 'EMPTY_TITLE'));
    }
    $addResult = OrderTable::add($data);
    if (!$addResult->isSuccess()) {
        return $result->addErrors($addResult->getErrors());
    }
    return $result->setData(['id' => $addResult->getId()]);
}
```

### Инфоблок D7 (требует API_CODE)
```php
use Bitrix\Iblock\Elements\ElementNewsTable; // API_CODE = 'news'
$result = ElementNewsTable::getList([
    'select' => ['ID', 'NAME', 'PRICE' => 'PRICE.VALUE'],
    'filter' => ['=ACTIVE' => 'Y'],
]);
```

### Инфоблок legacy
```php
$res = CIBlockElement::GetList(
    ['SORT' => 'ASC'],
    ['IBLOCK_ID' => 5, 'ACTIVE' => 'Y'],
    false,
    ['nPageSize' => 20],
    ['ID', 'NAME', 'PROPERTY_COLOR']
);
while ($el = $res->GetNext()) { echo $el['PROPERTY_COLOR_VALUE']; }
```

### Кеш
```php
$cache = \Bitrix\Main\Application::getInstance()->getCache();
if ($cache->initCache(3600, 'my_key', '/my_cache')) {
    $data = $cache->getVars();
} else {
    $data = /* ...вычисли... */;
    $cache->endDataCache($data);
}
```

### AJAX Controller
```php
namespace MyVendor\MyModule\Controller;
use Bitrix\Main\Engine\Controller;
use Bitrix\Main\Engine\ActionFilter;

class Order extends Controller
{
    public function configureActions(): array {
        return ['create' => ['prefilters' => [new ActionFilter\Authentication()]]];
    }
    public function createAction(string $title, int $userId): ?array {
        // Engine сам оборачивает в {"status":"success","data":...}
        return ['id' => 42];
    }
}
```

---

## Навигация по reference-файлам

Загружай нужный файл когда задача относится к этой теме:

| Тема | Файл |
|------|------|
| DataManager, CRUD, Relations, фильтры, агрегация, runtime-поля, ORM Events, Result/Error, исключения | [references/orm.md](references/orm.md) |
| EventManager, Engine\Controller, AJAX, Routing, CSRF | [references/events-routing.md](references/events-routing.md) |
| Структура модуля, Loader, PSR-4, Application, ServiceLocator, Config\Option, Loc | [references/modules-loader.md](references/modules-loader.md) |
| Компоненты, CBitrixComponent, шаблоны, кеш в компонентах, CComponentEngine | [references/components.md](references/components.md) |
| Data\Cache, TaggedCache, CAgent, IO\File/Directory/Path | [references/cache-infra.md](references/cache-infra.md) |
| Type\DateTime, Type\Date, HttpClient, HttpRequest, HttpResponse | [references/http.md](references/http.md) |
| Инфоблоки (legacy + D7 ORM), свойства, HL-блоки, события инфоблоков | [references/iblocks.md](references/iblocks.md) |
| XSS, SQL-инъекции, CSRF, права доступа, CurrentUser, ActionFilter | [references/security.md](references/security.md) |
| REST-методы, OnRestServiceBuildDescription, события REST, Webhook, OAuth, HttpClient | [references/rest.md](references/rest.md) |
| Admin-страницы, CAdminList, CAdminForm, CAdminTabControl, фильтры, меню, права, кастомные UF-типы | [references/admin-ui.md](references/admin-ui.md) |
| Создание инфоблоков/типов/свойств, группы, пользователи, права, миграции, SQL схема | [references/entities-migrations.md](references/entities-migrations.md) |
| SEF URL / ЧПУ, urlrewrite.php, UrlRewriter D7, SEF_MODE, SEF_RULE, CComponentEngine, сортировка/фильтрация инфоблока | [references/sef-urls.md](references/sef-urls.md) |
| Сброс кеша (файловый, managed, HTML/composite), noindex/robots, canonical, sitemap (SitemapTable, Job), robots.txt (RobotsFile), защита страниц авторизацией (.access.php, AuthForm, IsAuthorized) | [references/seo-cache-access.md](references/seo-cache-access.md) |

---

## Стиль ответов

- Сначала коротко объясни ЧТО делаешь и ПОЧЕМУ именно так, затем код
- Всегда указывай `use`-импорты в примерах
- Если есть D7 и legacy — показывай D7, legacy только если веская причина
- При неоднозначности — уточни версию Bitrix и контекст (компонент, модуль, REST, CLI)
- Предупреждай о gotchas — особенно DateTime userTime, EventResult (ORM vs Main), VERSION 1 vs 2 в инфоблоках, API_CODE обязателен для D7 ORM инфоблоков
