# Bitrix Push & Pull — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с real-time уведомлениями, Push&Pull, WebSocket, отправкой событий из PHP в браузер или настройкой каналов.
>
> Audit note: в текущем проверенном core модуль `pull` в `www/bitrix/modules` не найден. Этот файл сейчас отложен и не должен быть основным маршрутом, пока модуль не установлен и не подтверждён в ядре.

## Содержание
- Архитектура Push&Pull
- Отправка события из PHP: Event::add()
- Отправка нескольким пользователям
- Broadcast на канал (CPullChannel)
- JS-сторона: BX.PULL.subscribe, getStatus, reconnect
- Регистрация канала и онлайн-статус
- Отладка
- Gotchas

---

## Архитектура Push & Pull

Bitrix Push&Pull — система доставки событий из PHP-кода в браузер в реальном времени.

**Транспорты** (выбираются автоматически по приоритету):
1. **WebSocket** — постоянное соединение, наименьшая задержка. Требует Push-сервер (nginx + модуль).
2. **SSE (Server-Sent Events)** — однонаправленный стриминг. Fallback при недоступности WS.
3. **Long Polling** — периодические HTTP-запросы. Работает всегда, самый надёжный fallback.

**Каналы** — именованные очереди событий. Каждый пользователь слушает свой персональный канал. Broadcast-каналы позволяют слать события группе пользователей.

**Поток данных:**
```
PHP: \Bitrix\Pull\Event::add($userId, $payload)
  → запись в b_pull_stack (MySQL) или Redis
  → Push-сервер / long-polling polling endpoint читает стек
  → доставляет в браузер через WS/SSE/LP
  → BX.PULL.subscribe callback вызывается в JS
```

---

## Отправка события из PHP

```php
use Bitrix\Main\Loader;

Loader::includeModule('pull');

// Отправить событие конкретному пользователю
\Bitrix\Pull\Event::add($userId, [
    'module_id' => 'vendor.mymodule',   // ваш модуль-отправитель
    'command'   => 'order_status_changed', // произвольная строка, обрабатывается на JS
    'params'    => [                    // данные события — только простой массив
        'order_id' => 123,
        'status'   => 'shipped',
        'message'  => 'Заказ отправлен',
    ],
    'extra'     => \CPullStack::AddByUser($userId), // необязательно, дополнительные мета
]);

// Минимальный вариант
\Bitrix\Pull\Event::add($userId, [
    'module_id' => 'vendor.mymodule',
    'command'   => 'ping',
    'params'    => ['ts' => time()],
]);
```

### Отправка нескольким пользователям

```php
Loader::includeModule('pull');

// Массив userId — разошлёт каждому в его персональный канал
$userIds = [1, 5, 12, 47];

\Bitrix\Pull\Event::add($userIds, [
    'module_id' => 'vendor.mymodule',
    'command'   => 'new_message',
    'params'    => [
        'from_user_id' => $senderId,
        'text'         => 'Привет всем!',
        'chat_id'      => $chatId,
    ],
]);

// Через CPullStack напрямую (legacy-способ, аналогичен Event::add)
CPullStack::AddByUsers($userIds, [
    'module_id' => 'vendor.mymodule',
    'command'   => 'new_message',
    'params'    => ['text' => 'Привет'],
]);
```

---

## Broadcast на канал (CPullChannel)

```php
Loader::includeModule('pull');

// Создать публичный канал (broadcast)
$channelId = 'my_custom_channel_' . $someEntityId;

// Подписать пользователя на канал
CPullChannel::AddUserToDemoChannel($userId, $channelId);

// Отправить событие в канал (получат все подписанные пользователи)
CPullStack::AddByChannel($channelId, [
    'module_id' => 'vendor.mymodule',
    'command'   => 'channel_event',
    'params'    => ['data' => 'payload'],
]);

// Получить ID канала пользователя (для передачи на клиент)
$channelToken = CPullChannel::GetChannelToken($userId);

// Зарегистрировать канал в системе (необходимо для публичных каналов)
CPullChannel::Register(
    $userId,        // владелец
    $channelId,     // уникальный ID
    3600,           // TTL в секундах
    false           // false = приватный, true = публичный
);
```

---

## JS-сторона

### Подписка на события

```javascript
// Убедись, что BX.PULL инициализирован (загружается с ядром Bitrix)
// В компоненте подключи расширение: \Bitrix\Main\UI\Extension::load('pull.client');

BX.PULL.subscribe({
    moduleId: 'vendor.mymodule',    // module_id из PHP Event::add
    callback: function(data) {
        // data.command   — строка команды
        // data.params    — объект с параметрами
        // data.extra     — дополнительные мета-данные

        if (data.command === 'order_status_changed') {
            console.log('Статус заказа:', data.params.status);
            // обновить UI
        }

        if (data.command === 'new_message') {
            BX.onCustomEvent('onNewMessage', [data.params]);
        }
    }
});

// Подписка с явным указанием типа события (D7 Pull Client)
BX.PULL.subscribe({
    type: BX.PullClient.SubscriptionType.Server, // Server | Shared | Online
    moduleId: 'vendor.mymodule',
    callback: function(data) { /* ... */ }
});
```

### Статус соединения и управление

```javascript
// Получить текущий статус соединения
const status = BX.PULL.getStatus();
// Возможные значения: 'online', 'offline', 'connecting', 'unknown'

// Принудительное переподключение (например, после восстановления сети)
BX.PULL.reconnect();

// Проверить, подключён ли Pull
if (BX.PULL.isConnected()) {
    console.log('Pull подключён');
}

// Событие смены статуса
BX.PULL.subscribe({
    type: BX.PullClient.SubscriptionType.Status,
    callback: function(data) {
        // data.status: 'online' | 'offline' | 'connecting'
        if (data.status === 'offline') {
            // показать индикатор отсутствия соединения
        }
    }
});

// Событие онлайн-статуса других пользователей
BX.PULL.subscribe({
    type: BX.PullClient.SubscriptionType.Online,
    callback: function(data) {
        // data.userId   — ID пользователя
        // data.online   — true/false
        console.log('User', data.userId, 'is', data.online ? 'online' : 'offline');
    }
});
```

---

## Регистрация канала и управление онлайн-статусом

```php
Loader::includeModule('pull');

// Онлайн-статус: обновить время последней активности пользователя
CPullOnline::SetOnline($userId, SITE_ID);

// Получить онлайн-пользователей сайта
$onlineUsers = CPullOnline::GetOnlineUsers(SITE_ID);
// array: [['USER_ID' => 1, 'LAST_SEEN' => timestamp], ...]

// Проверить онлайн-статус конкретного пользователя
$isOnline = CPullOnline::IsOnline($userId, SITE_ID);
// bool — онлайн если активен в последние ~60 секунд

// Зарегистрировать обработчик Pull-команд в модуле (в install/index.php)
// Bitrix вызовет OnPullEvent когда придёт событие для модуля
EventManager::getInstance()->registerEventHandler(
    'pull', 'OnPullEvent',
    'vendor.mymodule',
    \Vendor\Mymodule\PullHandler::class,
    'onPullEvent'
);
```

```php
// Пример обработчика OnPullEvent
namespace Vendor\Mymodule;

class PullHandler
{
    public static function onPullEvent(string $moduleId, string $command, array $params): void
    {
        if ($moduleId !== 'vendor.mymodule') {
            return;
        }
        // обработать команду от клиента (если используется двусторонняя связь)
    }
}
```

---

## Подключение расширения в PHP-компоненте

```php
// В component.php или template/template.php — подключить Pull JS-клиент
\Bitrix\Main\UI\Extension::load('pull.client');

// Или через Asset Manager (legacy)
\CJSCore::Init(['pull', 'pull_status', 'pull_client']);

// Передать токен канала в JS через CUtil::InitJSCore()
// (токен генерируется автоматически для авторизованных пользователей)
```

---

## Отладка

### Параметр `?LISTEN_JS_REVISION` в URL

Добавь `?LISTEN_JS_REVISION=1` к любому URL Bitrix-страницы чтобы увидеть в консоли браузера:
- текущую JS-ревизию Pull-клиента
- параметры соединения (транспорт, канал, сервер)

### Chrome DevTools — что смотреть

**Network → WS (WebSocket)**:
- ищи соединение с путём `/bitrix/tools/pull/?CHANNEL=...`
- в Frames вкладке видны все входящие и исходящие frames в реальном времени

**Network → EventStream (SSE)**:
- при SSE-транспорте ищи `GET /bitrix/tools/pull/?type=sse&...`
- в EventStream вкладке — поток событий

**Network → XHR (Long Polling)**:
- запросы к `/bitrix/tools/pull/?type=json&...`
- каждый запрос держится открытым, пока не придут данные или таймаут

**Консоль**:
```javascript
// Получить диагностику Pull-соединения
BX.PULL.getDebugInfo();

// Включить verbose-логирование
BX.PULL.setLogLevel(BX.PullClient.LogLevel.DEBUG);
```

### Отладка стека событий в PHP

```php
Loader::includeModule('pull');

// Посмотреть что лежит в стеке для пользователя (не потреблять)
$stack = CPullStack::GetStack($userId);
// array необработанных событий

// Очистить стек пользователя (осторожно в production!)
CPullStack::ClearStack($userId);

// Проверить активные каналы
$channels = CPullChannel::GetUserChannels($userId);
var_dump($channels);
```

---

## Gotchas

- **`Loader::includeModule('pull')`** обязателен перед любым использованием `\Bitrix\Pull\Event`, `CPullStack`, `CPullChannel`, `CPullOnline`. Без него классы не определены.
- **`EVENT_ID` vs `command`**: в PHP-вызове `Event::add()` поле называется `command`, не `event_id`. В JS-подписке `BX.PULL.subscribe` тоже `callback` получает `data.command`. Не путай с `EVENT_ID` из `CSocNetLog`.
- **Данные `params` должны быть простым массивом**: без объектов PHP, без вложенных классов, только скалярные значения и массивы. Данные сериализуются через `json_encode` — PHP-объекты потеряют тип.
- **Ограничение размера события**: максимальный размер `params` — около 64 КБ. При превышении событие молча отбрасывается. Для больших данных передавай только ID и загружай данные отдельным AJAX.
- **Long Polling включён всегда** как fallback — даже без Push-сервера Push&Pull работает. Push-сервер только ускоряет доставку.
- **`BX.PULL.subscribe()` без `type`** по умолчанию подписывается на `SubscriptionType.Server` — серверные события. Для онлайн-статуса используй явно `SubscriptionType.Online`.
- **Авторизованные vs анонимные**: Push&Pull работает только для авторизованных пользователей. Для анонимных нужны отдельные публичные каналы через `CPullChannel::Register()` с `$public = true`.
- **Токен канала не статичный**: он ротируется. Не кешируй токен на клиенте — получай через JS-инициализацию Bitrix.
- **В `\Bitrix\Pull\Event::add()` первый параметр** может быть `int` (один userId) или `int[]` (массив). Строки не принимаются — только целые числа.
- **SSE и Long Polling держат соединение** — не вызывай `Event::add()` в цикле с тысячами пользователей синхронно. Используй фоновые задачи (агенты, очереди) для массовой рассылки.
