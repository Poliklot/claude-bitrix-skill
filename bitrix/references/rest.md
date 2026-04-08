# Bitrix REST API — core-first справочник

> Reference для Bitrix-скилла. Загружай, когда задача связана с `rest`, `OnRestServiceBuildDescription`, `CRestServer`, исходящими REST-событиями, `event.bind`, placement'ами или серверной регистрацией REST-методов.

## Что подтверждено в текущем core

- Точка входа методов собирается через событие `rest:OnRestServiceBuildDescription`.
- Описание сервисов агрегирует `CRestProvider::getDescription()`.
- Базовый сервер запросов — `CRestServer` из `www/bitrix/modules/rest/classes/general/rest.php`.
- Специальные ключи описания:
  - `CRestUtil::GLOBAL_SCOPE` = `_global`
  - `CRestUtil::EVENTS` = `_events`
  - `CRestUtil::PLACEMENTS` = `_placements`
- Исключения REST — `Bitrix\Rest\RestException`.

---

## Регистрация методов

```php
use Bitrix\Main\EventManager;

EventManager::getInstance()->addEventHandler(
    'rest',
    'OnRestServiceBuildDescription',
    ['\\MyVendor\\MyModule\\RestService', 'onBuildDescription']
);
```

Для постоянной регистрации в install-логике модуля тоже допустим `registerEventHandler(...)`.

---

## Формат описания

```php
use CRestUtil;

class RestService
{
    public static function onBuildDescription(): array
    {
        return [
            'my_scope' => [
                'my.item.list' => [__CLASS__, 'itemList'],
                'my.item.get' => [
                    'callback' => [__CLASS__, 'itemGet'],
                    'options' => [],
                ],
                CRestUtil::EVENTS => [
                    'OnMyItemAdd' => [
                        'my.module',
                        'OnAfterMyItemAdd',
                        [__CLASS__, 'onItemAdd'],
                        [
                            'sendAuth' => true,
                        ],
                    ],
                ],
                CRestUtil::PLACEMENTS => [
                    'MY_WIDGET' => [
                        'private' => true,
                    ],
                ],
            ],
            CRestUtil::GLOBAL_SCOPE => [
                'my.server.time' => [__CLASS__, 'serverTime'],
            ],
        ];
    }
}
```

### Что важно про сборку описания

- `CRestProvider` делает `array_merge_recursive(...)` для всех обработчиков `OnRestServiceBuildDescription`.
- Имена методов и scope затем приводятся к нижнему регистру.
- Ключи внутри `_events` и `_placements` приводятся к верхнему регистру.

---

## Сигнатура callback

Текущий core вызывает callback так:

```php
public static function itemList(array $query, int $start, \CRestServer $server): array
{
    $authData = $server->getAuthData();
    $userId = (int)($authData['user_id'] ?? 0);
    $clientId = (string)($authData['client_id'] ?? '');

    $items = [];
    $total = 0;

    return [
        'items' => $items,
        'total' => $total,
    ];
}
```

### Поведение `CRestServer::processCall()`

- параметр `start` берётся из `$query['start']`, затем удаляется из входного массива;
- callback получает `($query, $start, $server)`;
- если callback вернул массив с `next` и `total`, сервер выносит их на верхний уровень ответа;
- итоговый успешный JSON строится как `['result' => ..., 'next' => ..., 'total' => ...]`.

---

## `CRestServer`: что брать откуда

```php
$server->getAuthData();   // полные auth-данные провайдера
$server->getAuthScope();  // scope из authData['scope']
$server->getClientId();   // CLIENT_ID приложения
$server->getMethod();     // текущее REST-имя метода
$server->getScope();      // найденный scope текущего метода
$server->setStatus(\CRestServer::STATUS_CREATED);
```

### Важная разница: `getAuth()` vs `getAuthData()`

- `getAuthData()` — основной источник auth-метаданных (`user_id`, `client_id`, `scope`, `auth_connector`, `parameters` и т.д.).
- `getAuth()` не равен полному auth payload; туда попадают только параметры, которые auth-провайдер вынес из входного query через `parameters_clear`.

Если нужен `user_id`, в текущем core безопаснее брать его из `getAuthData()`, а не из `getAuth()`.

---

## Ошибки

```php
use Bitrix\Rest\RestException;

throw new RestException(
    'ID обязателен',
    RestException::ERROR_ARGUMENT,
    \CRestServer::STATUS_WRONG_REQUEST
);
```

Подтверждённые коды в core:

- `ERROR_ARGUMENT`
- `ERROR_NOT_FOUND`
- `ERROR_CORE`
- `ERROR_OAUTH`
- `ERROR_METHOD_NOT_FOUND`
- `ERROR_OPERATION_TIME_LIMIT`

Подтверждённые HTTP-статусы в `CRestServer`:

- `STATUS_OK`
- `STATUS_CREATED`
- `STATUS_WRONG_REQUEST`
- `STATUS_UNAUTHORIZED`
- `STATUS_FORBIDDEN`
- `STATUS_NOT_FOUND`
- `STATUS_TO_MANY_REQUESTS`
- `STATUS_INTERNAL`

---

## Исходящие события и `event.bind`

Серверные `_events` в описании метода только объявляют доступные события. Реальная отправка наружу происходит после `event.bind`.

Что проверено в `Bitrix\Rest\Api\Event`:

- `event.bind` требует OAuth-auth type;
- для offline-ивентов нужны права администратора;
- `EVENT` приводится к верхнему регистру;
- `EVENT_TYPE` поддерживает `online` и `offline`;
- для `online` обязателен `HANDLER`;
- для событий с опцией `disableOffline => true` offline-регистрация запрещена.

Пример обработчика исходящего события:

```php
public static function onItemAdd(\Bitrix\Main\Event $event): array
{
    $fields = $event->getParameter('fields');

    return [
        'data' => [
            'FIELDS' => [
                'ID' => $fields['ID'] ?? null,
            ],
        ],
    ];
}
```

---

## Placement и userfieldtype

В текущем core есть отдельный REST API для пользовательских UF-type placements:

- `Bitrix\Rest\Api\UserFieldType`
- scope: `placement`
- placement code: `USERFIELD_TYPE`

Если задача про REST-встраивание UF-типа, сначала смотри `rest/lib/api/userfieldtype.php`, а не общие примеры из памяти.

---

## Gotchas

- `OnRestServiceBuildDescription` вызывается на каждом REST-запросе: handler должен быть лёгким.
- Не полагайся вслепую на `$server->getAuth()['user_id']`: в текущем core надёжнее `$server->getAuthData()['user_id']`.
- `_events` и `_placements` после сборки нормализуются по регистру, поэтому не завязывайся на исходный case.
- `RestException::__construct()` принимает строковый error code, но PHP exception code внутри всё равно приводится к `int`; для логики REST смотри `getErrorCode()`, а не `getCode()`.
- `event.bind` валидирует callback через `HandlerHelper::checkCallback(...)`, поэтому внешний URL надо проверять по реальному app context.
