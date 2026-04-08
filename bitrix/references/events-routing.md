# Bitrix EventManager, Controllers, Routing — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с событиями модулей, AJAX-контроллерами, Engine\Controller, маршрутизацией (Routing) или CSRF.
>
> Audit note (core-verified, current project): справочник сверялся по `www/bitrix/modules/main/lib/eventmanager.php`, `engine/{controller,router,resolver}.php`, `routing/*`, `application.php` и `main/classes/general/user.php`.

## Содержание
- EventManager: runtime vs persistent подписка, регистрация в module
- Engine\Controller: Actions, prefilters, CSRF, JSON-ответы, ошибки
- Routing: RoutingConfigurator, группы, параметры, .settings.php

---

## EventManager — события модулей

`EventManager` — шина событий Bitrix. Это механизм loose coupling: модуль А стреляет событие, модуль Б его слушает, они не зависят друг от друга напрямую. Используется для: интеграций между модулями, расширения поведения стандартных операций (iblock, sale, users).

### Runtime vs Persistent подписка

Два принципиально разных способа:

| Метод | Где хранится | Когда использовать |
|-------|-------------|-------------------|
| `addEventHandler()` | в памяти до конца запроса | в `init.php` или `include.php` модуля — работает пока подключён файл |
| `registerEventHandler()` / `registerEventHandlerCompatible()` | в БД `b_module_to_module`, переживает перезапуск | в инсталляторе модуля — постоянная подписка |

### Version 1 vs Version 2 — разные сигнатуры обработчиков

Это ключевое различие:
- `addEventHandler()` — **version=2** → обработчику передаётся объект `Event`
- `addEventHandlerCompatible()` — **version=1** → обработчику передаются параметры по-отдельности (legacy-стиль)

Большинство стандартных событий Bitrix (`OnBeforeIBlockElementAdd` и т.п.) — legacy. Они ожидают version=1. Поэтому для них нужен `addEventHandlerCompatible()` или `registerEventHandlerCompatible()`.

```php
use Bitrix\Main\EventManager;
use Bitrix\Main\Event;
use Bitrix\Main\EventResult;

$em = EventManager::getInstance();

// D7-событие (своё или другого D7-модуля) — version=2, получает объект Event
$em->addEventHandler(
    'my.module',
    'OnOrderStatusChanged',
    [\MyVendor\MyModule\Handler::class, 'onStatusChanged'],
    false,  // $includeFile (путь к файлу, если нужно подключить; false = не нужен)
    100     // $sort — порядок выполнения (меньше = раньше)
);

// Legacy-событие iblock/sale/etc — version=1, параметры передаются напрямую
$em->addEventHandlerCompatible(
    'iblock',
    'OnBeforeIBlockElementAdd',
    [\MyVendor\MyModule\IblockHandler::class, 'onBeforeElementAdd']
);

// Удалить обработчик — $key возвращается addEventHandler
$key = $em->addEventHandler('my.module', 'OnSomething', $callback);
$em->removeEventHandler('my.module', 'OnSomething', $key);
```

### Обработчики: D7 vs legacy

```php
class IblockHandler
{
    // D7-стиль (version=2): получает объект Event, возвращает EventResult или null
    public static function onStatusChanged(Event $event): ?EventResult
    {
        $orderId   = $event->getParameter('id');
        $newStatus = $event->getParameter('newStatus');

        // null = всё нормально, продолжаем
        // EventResult::ERROR = прерываем (если событие это поддерживает)
        return null;
    }

    // Legacy-стиль (version=1): параметры по-отдельности, часто по ссылке
    public static function onBeforeElementAdd(array &$arFields): void
    {
        // Изменяем поля напрямую через ссылку
        $arFields['PREVIEW_TEXT'] = strip_tags($arFields['PREVIEW_TEXT'] ?? '');
    }
}
```

### Создание и отправка своих D7-событий

```php
use Bitrix\Main\Event;
use Bitrix\Main\EventResult;

// Создаём и отправляем событие
$event = new Event('my.module', 'OnOrderStatusChanged', [
    'id'        => $orderId,
    'oldStatus' => $old,
    'newStatus' => $new,
]);
$event->send();

// Анализируем результаты подписчиков
// EventResult::UNDEFINED=0, SUCCESS=1, ERROR=2
foreach ($event->getResults() as $eventResult) {
    if ($eventResult->getType() === EventResult::SUCCESS) {
        $data = $eventResult->getParameters(); // данные от подписчика
    } elseif ($eventResult->getType() === EventResult::ERROR) {
        // подписчик сигнализирует об ошибке
    }
}

// Подписчик на D7-событие возвращает \Bitrix\Main\EventResult (не ORM\EventResult!)
$em->addEventHandler('my.module', 'OnOrderStatusChanged', function(Event $event) {
    return new EventResult(EventResult::SUCCESS, ['notified' => true], 'my.module');
});
```

### Пользовательские события: OnAfterUserAuthorize

`OnAfterUserAuthorize` в текущем core вызывается в `CUser::Authorize()` после успешной авторизации. Это не то же самое, что `OnAfterUserLogin`: `OnAfterUserLogin` вызывается внутри `CUser::Login()`, а `OnAfterUserAuthorize` привязан именно к успешному `Authorize()` и подходит для пост-логин логики.

Типичный use-case: миграция гостевых данных (корзина, избранное) из cookie в БД при логине.

```php
// Структура $params для OnAfterUserAuthorize (legacy version=1) в текущем core:
// [
//   'user_fields'   => array,      // поля пользователя, включая ID / LOGIN / EMAIL / ...
//   'save'          => bool,       // remember me / stored auth
//   'update'        => bool,       // обновлять ли служебные данные авторизации
//   'applicationId' => mixed,      // application password / integration context, если есть
// ]

use Bitrix\Main\Context;
use Bitrix\Main\Web\CryptoCookie;

class EventHandler
{
    public static function onAfterUserAuthorize(array $params): void
    {
        $userId = (int)($params['user_fields']['ID'] ?? 0);
        if ($userId <= 0) {
            return;
        }

        // Читаем гостевые данные из куки
        $raw = Context::getCurrent()->getRequest()->getCookie('FAVORITES');
        if (empty($raw)) {
            return;
        }

        $guestIds = json_decode($raw, true);
        if (!is_array($guestIds) || empty($guestIds)) {
            return;
        }

        // Переносим в БД
        FavoriteService::getInstance()->migrateFromCookie($userId, $guestIds);

        // Удаляем куку (expire в прошлом)
        $cookie = new CryptoCookie('FAVORITES', '', time() - 3600);
        $cookie->setPath('/');
        Context::getCurrent()->getResponse()->addCookie($cookie);
    }
}
```

Регистрация legacy-обработчика:

```php
// В инсталляторе модуля (persistent):
EventManager::getInstance()->registerEventHandlerCompatible(
    'main',
    'OnAfterUserAuthorize',
    'vendor.favorites',
    \Vendor\Favorites\EventHandler::class,
    'onAfterUserAuthorize'
);
```

> **Важно**: `OnAfterUserAuthorize` в текущем core вызывается через legacy-механику `GetModuleEvents(..., true)` / `ExecuteModuleEventEx(...)`. Для runtime-подписки используй `addEventHandlerCompatible()`, для persistent-регистрации в инсталляторе — `registerEventHandlerCompatible()`.

---

### Persistent-регистрация в инсталляторе модуля

```php
// /bitrix/modules/my.module/install/index.php — при установке модуля
\Bitrix\Main\EventManager::getInstance()->registerEventHandlerCompatible(
    'iblock',                                    // чьё событие слушаем
    'OnBeforeIBlockElementAdd',                  // имя события
    'my.module',                                 // наш модуль
    '\MyVendor\MyModule\IblockHandler',          // класс
    'onBeforeElementAdd',                        // метод
    100                                          // sort
);

// При удалении модуля — обязательно убирать
\Bitrix\Main\EventManager::getInstance()->unRegisterEventHandler(
    'iblock', 'OnBeforeIBlockElementAdd',
    'my.module', '\MyVendor\MyModule\IblockHandler', 'onBeforeElementAdd'
);
// Кеш b_module_to_module сбросится автоматически
```

---

## Engine: Controllers и AJAX

`Engine\Controller` — стандартный способ обрабатывать AJAX в D7. Всё идёт через `/bitrix/services/main/ajax.php?action=vendor:module.controller.action`. Контроллер по умолчанию подключает default prefilters, биндит параметры запроса к аргументам метода по типам PHP и упаковывает ответ в JSON.

**Когда использовать Controller вместо отдельного PHP-файла:** всегда в D7-коде. Голые PHP-файлы для AJAX — legacy-подход.

### Жизненный цикл запроса к контроллеру

1. Запрос приходит на `/bitrix/services/main/ajax.php?action=...`
2. Ядро находит контроллер по namespace-регистрации в `.settings.php`
3. Вызываются `prefilters` (Authentication → HttpMethod → Csrf)
4. Если все фильтры прошли — вызывается `{action}Action()` метод
5. Параметры метода автоматически извлекаются из GET/POST и кастуются по типам
6. Результат оборачивается в `AjaxJson`

### Контроллер

```php
namespace MyVendor\MyModule\Controller;

use Bitrix\Main\Engine\Controller;
use Bitrix\Main\Engine\ActionFilter;
use Bitrix\Main\Engine\CurrentUser;
use Bitrix\Main\Error;

class Order extends Controller
{
    // Дефолтные prefilters: Authentication + HttpMethod(GET|POST) + Csrf
    // configureActions позволяет переопределить их для каждого action
    public function configureActions(): array
    {
        return [
            // Полностью заменить prefilters для read-only GET action
            'getList' => [
                'prefilters' => [
                    new ActionFilter\Authentication(),
                    new ActionFilter\HttpMethod([ActionFilter\HttpMethod::METHOD_GET]),
                ],
            ],

            // Добавить фильтр к дефолтным, не заменяя их (+prefilters)
            'export' => [
                '+prefilters' => [new ActionFilter\Scope([Controller::SCOPE_AJAX])],
            ],

            // Убрать конкретный фильтр из дефолтных (-prefilters)
            'publicInfo' => [
                '-prefilters' => [
                    ActionFilter\Authentication::class,
                    ActionFilter\Csrf::class,
                ],
            ],

            // Для POST: Csrf добавляется автоматически если HttpMethod содержит POST и нет явного Csrf-фильтра
            // (ядро: $hasPostMethod && !$hasCsrfCheck && $request->isPost())
            'create' => [
                'prefilters' => [
                    new ActionFilter\Authentication(),
                    new ActionFilter\HttpMethod([ActionFilter\HttpMethod::METHOD_POST]),
                ],
            ],

            // Публичный endpoint без любых фильтров
            'publicStats' => [
                'prefilters' => [], 'postfilters' => [],
            ],
        ];
    }

    // Параметры биндятся автоматически из GET/POST по именам и типам PHP
    // Метод ОБЯЗАН заканчиваться на 'Action' (METHOD_ACTION_SUFFIX = 'Action')
    public function getListAction(int $page = 1, int $limit = 20): array
    {
        $items = \MyVendor\MyModule\OrderTable::getList([
            'select' => ['ID', 'TITLE'],
            'filter' => ['=ACTIVE' => 'Y'],
            'limit'  => $limit,
            'offset' => ($page - 1) * $limit,
        ])->fetchAll();

        return ['items' => $items, 'total' => \MyVendor\MyModule\OrderTable::getCount()];
        // Автоматически: {"status":"success","data":{"items":[...],"total":N}}
    }

    // null + addError → {"status":"error","errors":[...]}
    public function createAction(string $title, ?int $userId = null): ?array
    {
        if (empty($title)) {
            $this->addError(new Error('Заголовок обязателен', 'EMPTY_TITLE'));
            return null;
        }

        $result = \MyVendor\MyModule\OrderTable::add([
            'TITLE'   => $title,
            'USER_ID' => $userId ?? CurrentUser::get()->getId(),
        ]);

        if (!$result->isSuccess()) {
            $this->addErrors($result->getErrors()); // проброс ошибок ORM
            return null;
        }

        return ['id' => $result->getId()];
    }

    // Конвертация UPPER_CASE ключей ORM → camelCase для фронта
    public function getItemAction(int $id): ?array
    {
        $row = \MyVendor\MyModule\OrderTable::getById($id)->fetch();
        if (!$row) {
            $this->addError(new Error('Не найден', 'NOT_FOUND'));
            return null;
        }
        // ['USER_ID' => 1] → ['userId' => 1]
        return $this->convertKeysToCamelCase($row);
    }

    // Форвардинг — передать управление в другой контроллер
    public function complexAction(): mixed
    {
        return $this->forward(AnotherController::class, 'process', ['param' => 'value']);
    }
}
```

### Формат JSON-ответа

```json
{"status": "success", "data": {...},  "errors": []}
{"status": "error",   "data": null,   "errors": [{"message":"...","code":"...","customData":null}]}
{"status": "denied",  "data": null,   "errors": [...]}
```

`denied` — когда `Authentication` filter отклоняет запрос (401). `error` — когда action вернул `addError`.

```php
// Ручное создание AjaxJson (когда нужно вернуть из action напрямую)
use Bitrix\Main\Engine\Response\AjaxJson;
use Bitrix\Main\ErrorCollection;

return AjaxJson::createSuccess(['id' => 5]);
return AjaxJson::createError(new ErrorCollection([$error]));
return AjaxJson::createDenied();
```

### Вызов с фронтенда

Формат action в `/bitrix/services/main/ajax.php` разбирается как `vendor:module.controller.action`. Для партнёрского модуля `vendor.mymodule` это выглядит так:
- через `defaultNamespace`: `vendor:mymodule.order.getList`
- через alias из `controllers.namespaces`: `vendor:mymodule.api.order.getList`

```javascript
BX.ajax.runAction('vendor:mymodule.order.getList', {
    data: { page: 1, limit: 20 },
}).then(response => {
    console.log(response.data); // { items: [...], total: N }
});

// POST с CSRF-токеном
BX.ajax.runAction('vendor:mymodule.order.create', {
    method: 'POST',
    data: { title: 'Новый заказ', sessid: BX.bitrix_sessid() },
});
```

```php
// Регистрация в /bitrix/modules/vendor.mymodule/.settings.php
return [
    'controllers' => [
        'value' => [
            'defaultNamespace' => '\\Vendor\\Mymodule\\Controller',
            'namespaces' => [
                '\\Vendor\\Mymodule\\Controller' => 'api',
            ],
        ],
        'readonly' => true,
    ],
];
```

---

## Routing (Bitrix\Main\Routing)

В текущем core роутер инициализируется в `Bitrix\Main\Application::initializeRouter()`. Подтверждается такой bootstrap:
- читается глобальная конфигурация `routing.config`
- ищутся файлы `/local/routes/<file>` и `/bitrix/routes/<file>`
- дополнительно подключается системный `/bitrix/routes/web_bitrix.php`, если он существует
- route-файл должен вернуть callable вида `function (RoutingConfigurator $routes) { ... }`

Поведение относительно `urlrewrite.php`, компонентов и project bootstrap зависит от конкретной сборки, поэтому не обещай порядок обработки “по памяти” — проверяй текущий проект.

**Настройка**: имя route-файла объявляется в глобальной `.settings.php` проекта:

```php
// Добавить в .settings.php:
'routing' => ['value' => ['config' => ['web.php']], 'readonly' => false],
```

После этого ядро ищет `local/routes/web.php` и `bitrix/routes/web.php`.

```php
// local/routes/web.php
use Bitrix\Main\Routing\RoutingConfigurator;

return function (RoutingConfigurator $routes): void {

    // Простой маршрут с параметром и regexp-ограничением
    $routes->get(
        '/api/orders/{id}/',
        [\MyVendor\MyModule\Controller\Order::class, 'getAction']
    )->where('id', '\d+'); // только числа

    // Группа с префиксом — все методы REST для ресурса
    $routes->prefix('/api/v1')->group(function (RoutingConfigurator $routes): void {
        $routes->get('/orders/',         [\MyVendor\MyModule\Controller\Order::class, 'getListAction']);
        $routes->post('/orders/',        [\MyVendor\MyModule\Controller\Order::class, 'createAction']);
        $routes->put('/orders/{id}/',    [\MyVendor\MyModule\Controller\Order::class, 'updateAction']);
        $routes->delete('/orders/{id}/', [\MyVendor\MyModule\Controller\Order::class, 'deleteAction']);
    });

    // Именованный маршрут + default value
    $routes->get('/api/report/{format}/', [\MyVendor\MyModule\Controller\Report::class, 'getAction'])
        ->name('api.report')
        ->default('format', 'json')
        ->where('format', 'json|csv');
};
```

Что подтверждается по `routing/*` в текущем core:
- `RoutingConfigurator` поддерживает `get/post/put/patch/options/delete/any/group`
- options DSL включает `middleware`, `prefix`, `name`, `domain`, `where`, `default`
- `where()` задаёт regexp для `{param}`
- `default()` делает параметр необязательным и подставляет значение по умолчанию
- `Router::route($name, $parameters)` умеет собирать URL по имени маршрута

Что нужно проверять отдельно в проекте:
- как именно исполняются `middleware` из route options
- где route-controller связывается с HTTP response в вашем приложении

---
