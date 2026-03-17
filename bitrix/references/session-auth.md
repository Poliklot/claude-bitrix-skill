# Bitrix Session + Authentication — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с сессиями (`Bitrix\Main\Session\Session`, `KernelSession`, `CompositeSessionManager`), политиками аутентификации (`Bitrix\Main\Authentication\Policy`), или настройкой обработчиков сессий.

## Содержание
- Архитектура сессий D7
- Session: основные методы (ArrayAccess, isActive, enableLazyStart)
- KernelSession vs Session
- CompositeSessionManager
- SessionConfigurationResolver
- Политики аутентификации (Authentication\Policy)
- Примеры: чтение/запись, lazy start, кастомный handler
- Gotchas

---

## Архитектура

В Bitrix D7 сессия — это объект `Session`, который реализует `ArrayAccess` и `SessionInterface`. Получить его можно через `Application::getInstance()->getSession()`.

**Иерархия:**
```
Application::getSession()
    └── Session (реализует ArrayAccess, SessionInterface)
         ├── KernelSession (ядро Bitrix — хранит авторизацию, SESSID)
         └── CompositeSessionManager (для composite cache, управляет несколькими хранилищами)
```

---

## Session: основные методы

```php
use Bitrix\Main\Application;

$session = Application::getInstance()->getSession();

// Чтение / запись (ArrayAccess)
$session['my_key'] = 'some value';
$value = $session['my_key'];
unset($session['my_key']);
isset($session['my_key']); // bool

// Статус
$session->isActive();       // bool — сессия стартована
$session->isAccessible();   // bool — можно читать/писать

// ID сессии
$session->getId();          // string — текущий session_id()

// Lazy start (сессия не стартует до первого обращения)
$session->enableLazyStart();
$session->disableLazyStart();

// Явный старт
$session->start(); // если не lazy

// Миграция (новый session_id, защита от session fixation)
$session->migrate(bool $deleteOldSession = true);
```

---

## Полный пример: работа с сессией

```php
use Bitrix\Main\Application;

$app     = Application::getInstance();
$session = $app->getSession();

// Проверить что сессия доступна перед работой
if ($session->isAccessible()) {
    // Хранить данные корзины
    if (!isset($session['cart'])) {
        $session['cart'] = [];
    }

    $cart = $session['cart'];
    $cart[] = ['product_id' => 42, 'qty' => 1];
    $session['cart'] = $cart;
}
```

---

## KernelSession

`KernelSession` — специальный объект ядра для хранения данных авторизации. Недоступен напрямую через `getSession()` — это внутренний компонент.

```php
// KernelSession хранит:
// - данные авторизации пользователя (USER_ID, GROUPS и т.д.)
// - BITRIX_SM_* параметры

// Доступ через глобальный объект $USER (legacy) или через KernelSession напрямую:
use Bitrix\Main\Session\KernelSession;
// KernelSession::getInstance() — singleton
// Используется внутренне модулем main для авторизации
```

---

## CompositeSessionManager

Управляет несколькими хранилищами сессий одновременно (например, для composite cache).

```php
use Bitrix\Main\Session\CompositeSessionManager;

// Получить из Application — обычно не нужно напрямую
// CompositeSessionManager создаётся автоматически в Application::getInstance()

// В конфигурации (.settings.php) можно задать несколько обработчиков:
// 'session' => [
//     'value' => [
//         'mode' => 'default',
//         'handlers' => [
//             'general' => ['type' => 'file'],
//             'kernel'  => ['type' => 'database'],
//         ],
//     ],
// ],
```

---

## SessionConfigurationResolver

Разбирает конфигурацию `.settings.php` для создания нужного `SessionHandler`.

```php
// Настройка в bitrix/.settings.php:
'session' => [
    'value' => [
        'mode'    => 'default', // или 'separated'
        'lifetime' => 3600,
        'handlers' => [
            'general' => [
                'type' => 'file',         // 'file', 'database', 'memcache', 'redis'
            ],
        ],
    ],
],
```

**Режимы `mode`:**
- `default` — единое хранилище для ядра и приложения
- `separated` — раздельные хранилища для `KernelSession` и `Session`

---

## Кастомный SessionHandler

```php
namespace MyVendor\MyModule\Session;

use SessionHandlerInterface;

class RedisSessionHandler implements SessionHandlerInterface
{
    private \Redis $redis;

    public function __construct(string $host, int $port = 6379)
    {
        $this->redis = new \Redis();
        $this->redis->connect($host, $port);
    }

    public function open(string $savePath, string $sessionName): bool
    {
        return true;
    }

    public function close(): bool
    {
        return true;
    }

    public function read(string $id): string|false
    {
        return $this->redis->get("session:{$id}") ?: '';
    }

    public function write(string $id, string $data): bool
    {
        return $this->redis->setex("session:{$id}", 3600, $data);
    }

    public function destroy(string $id): bool
    {
        $this->redis->del("session:{$id}");
        return true;
    }

    public function gc(int $maxLifetime): int|false
    {
        return 0; // Redis TTL управляет устареванием
    }
}
```

Регистрация в `.settings.php`:

```php
'session' => [
    'value' => [
        'mode' => 'default',
        'handlers' => [
            'general' => [
                'type'   => 'custom',
                'class'  => \MyVendor\MyModule\Session\RedisSessionHandler::class,
                'params' => ['host' => '127.0.0.1'],
            ],
        ],
    ],
],
```

---

## Политики аутентификации (Authentication\Policy)

`Bitrix\Main\Authentication\Policy\Policy` — интерфейс для политик проверки авторизации.

```php
use Bitrix\Main\Authentication\Policy\Policy;

// Встроенные политики находятся в main/lib/authentication/policy/
// Обычно используются в рамках сложных сценариев OAuth/SSO
// Для стандартных проверок используй $USER->IsAuthorized() или ActionFilter\Authentication
```

**Стандартная проверка авторизации в Controller:**

```php
use Bitrix\Main\Engine\Controller;
use Bitrix\Main\Engine\ActionFilter;

class MyController extends Controller
{
    public function configureActions(): array
    {
        return [
            'doSomething' => [
                'prefilters' => [
                    new ActionFilter\Authentication(), // 401 если не авторизован
                ],
            ],
        ];
    }
}
```

**Проверка в компоненте:**

```php
global $USER;
if (!$USER->IsAuthorized()) {
    LocalRedirect(SITE_DIR . 'auth/?backurl=' . urlencode($APPLICATION->GetCurPage()));
}
```

---

## Gotchas

- **`session['key']` vs `$_SESSION['key']`**: в D7-коде всегда используй объект `Session`, не `$_SESSION` напрямую. В некоторых режимах они могут указывать на разные хранилища.
- **`isAccessible()` vs `isActive()`**: `isActive()` = сессия стартована. `isAccessible()` = можно безопасно читать/писать (учитывает lazy start и composite cache).
- **Lazy start**: если включён `enableLazyStart()`, сессия не стартует при каждом запросе — только при обращении к данным. Это важно для производительности на публичных страницах.
- **`migrate()`**: вызывай после авторизации пользователя для защиты от session fixation attack.
- **`CompositeSessionManager`**: в composite cache режиме ядро Bitrix может открыть сессию несколько раз. Не закрывай сессию вручную в компонентах.
- **Сериализация объектов**: `Session` хранит данные через `serialize()`. Не храни объекты без реализации `__sleep()`/`__wakeup()`, особенно ORM-объекты.
- **`KernelSession`**: менять напрямую опасно — это может сломать авторизацию пользователя.
