# Bitrix Session + Authentication — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с сессиями (`Bitrix\Main\Session\Session`, `KernelSession`, `CompositeSessionManager`), action-фильтрами авторизации/CSRF или конфигурацией обработчиков сессий.
>
> Audit note: проверено по текущему core `main/lib/session/*`, `main/lib/engine/actionfilter/*`, `main/lib/authentication/policy/*`.

## Содержание
- Архитектура сессий
- `Session`: основные методы
- `KernelSession` и `KernelSessionProxy`
- `CompositeSessionManager`
- `SessionConfigurationResolver`
- Action-фильтры авторизации
- `Bitrix\Main\Authentication\Policy`
- Gotchas

---

## Архитектура сессий

В текущем core публичная D7-сессия получается через `Application::getInstance()->getSession()` и реализуется классом `Bitrix\Main\Session\Session`.

**Реальная схема выглядит так:**

```text
Application::getInstance()->getSession()
    └── Session

SessionConfigurationResolver
    ├── mode=default   -> Session + KernelSessionProxy
    └── mode=separated -> Session + KernelSession

CompositeSessionManager
    └── координирует kernel/general session и умеет regenerateId()
```

`KernelSession` не является наследником `Session` и не является singleton.

---

## `Session`: основные методы

```php
use Bitrix\Main\Application;

$session = Application::getInstance()->getSession();

// ArrayAccess
$session['cart'] = ['product_id' => 42, 'qty' => 1];
$item = $session['cart'] ?? null;
unset($session['cart']);

// Статус
$session->isActive();      // bool
$session->isAccessible();  // bool
$session->isStarted();     // bool

// ID / имя
$session->getId();         // string
$session->getName();       // обычно PHPSESSID
// setId()/setName() допустимы только до старта активной session

// Lazy start
$session->enableLazyStart();
$session->disableLazyStart();

// Явный старт / сохранение / очистка
$session->start();
$session->save();
$session->clear();
$session->destroy();

// Ротация session id
$session->regenerateId();
```

> В текущем core метод называется именно `regenerateId()`. `migrate()` не подтверждён.

---

## Полный пример

```php
use Bitrix\Main\Application;

$session = Application::getInstance()->getSession();

if ($session->isAccessible())
{
    if (!isset($session['draft_form']))
    {
        $session['draft_form'] = [];
    }

    $draft = $session['draft_form'];
    $draft['name'] = 'Иван';
    $session['draft_form'] = $draft;
}
```

---

## `KernelSession` и `KernelSessionProxy`

`KernelSession` в текущем core хранит kernel-данные через cookie-handler и используется как внутренний слой авторизации/служебной сессии.

```php
use Bitrix\Main\Session\KernelSession;

$kernelSession = new KernelSession(3600);
$kernelSession->start();

$kernelSession['my_flag'] = 'Y';
$kernelSession->save();
```

Что важно:

- в `mode=default` resolver создаёт не прямой `KernelSession`, а `KernelSessionProxy`, оборачивающий обычный `Session`
- в `mode=separated` resolver создаёт отдельный `KernelSession`
- `KernelSession::getInstance()` в текущем core не подтверждён

Не трогай kernel session без необходимости: это чувствительный слой авторизации.

---

## `CompositeSessionManager`

`CompositeSessionManager` получает две `SessionInterface`: kernel и general.

```php
use Bitrix\Main\Session\CompositeSessionManager;

$manager = new CompositeSessionManager($kernelSession, $generalSession);

$manager->start();
$manager->regenerateId();
$manager->clear();
$manager->destroy();
```

Особенность текущего core:

- `regenerateId()` вызывает ротацию kernel session всегда
- general session ротируется только если kernel session не является `KernelSessionProxy`

---

## `SessionConfigurationResolver`

Resolver читает `session` из `.settings.php` и собирает нужные обработчики.

```php
'session' => [
    'value' => [
        'mode' => 'default', // или 'separated'
        'lifetime' => 3600,
        'handlers' => [
            'general' => [
                'type' => 'file', // file, database, redis, memcache, array, null, save_handler.php.ini
            ],
        ],
    ],
],
```

Подтверждённые типы general-handler в текущем core:

- `file`
- `database`
- `redis`
- `memcache`
- `array`
- `null`
- `save_handler.php.ini`

Для `mode=separated` есть жёсткое ограничение:

```php
'session' => [
    'value' => [
        'mode' => 'separated',
        'handlers' => [
            'general' => ['type' => 'redis'],
            'kernel' => 'encrypted_cookies',
        ],
    ],
],
```

> В текущем resolver не подтверждён generic-формат вида `'type' => 'custom', 'class' => ...`. Не придумывай такой контракт без дополнительной проверки.

---

## Action-фильтры авторизации

### `ActionFilter\Authentication`

```php
use Bitrix\Main\Engine\Controller;
use Bitrix\Main\Engine\ActionFilter;

class DemoController extends Controller
{
    public function configureActions(): array
    {
        return [
            'secure' => [
                'prefilters' => [
                    new ActionFilter\Authentication(),
                ],
            ],
        ];
    }
}
```

В текущем core:

- по умолчанию фильтр отдаёт `401`
- если передать `new ActionFilter\Authentication(true)`, то для не-AJAX запроса делает `LocalRedirect(.../auth/?backurl=...)`

### `ActionFilter\Csrf`

```php
use Bitrix\Main\Engine\ActionFilter;

new ActionFilter\Csrf();
```

Используй его для AJAX/D7-controller сценариев. Для обычных форм на сайте по-прежнему нужен `bitrix_sessid_post()` и `check_bitrix_sessid()`.

---

## `Bitrix\Main\Authentication\Policy`

В текущем core namespace `Bitrix\Main\Authentication\Policy` существует, но это не интерфейс `Policy`.

Подтверждённые базовые классы:

- `Bitrix\Main\Authentication\Policy\Rule`
- `Bitrix\Main\Authentication\Policy\RulesCollection`
- `BooleanRule`, `GreaterRule`, `LesserRule`, `IpMaskRule`, `WeakPassword`

Пример работы с preset-коллекцией:

```php
use Bitrix\Main\Authentication\Policy\RulesCollection;

$policy = RulesCollection::createByPreset(RulesCollection::PRESET_MIDDLE);

$sessionTimeout = $policy->getSessionTimeout();
$values = $policy->getValues();
```

Это advanced-layer для security-policy и админских сценариев, а не обычный интерфейс “проверить авторизацию пользователя”.

---

## Gotchas

- `isAccessible()` и `isActive()` — не одно и то же: `isActive()` про факт старта, `isAccessible()` про возможность безопасно открыть session при текущих заголовках.
- После успешной авторизации или смены security-контекста используй `regenerateId()`, а не несуществующий `migrate()`.
- `KernelSession` и general `Session` могут жить раздельно; не делай вывод, что `$_SESSION` всегда отражает всё состояние авторизации.
- В separated mode kernel handler должен быть именно `'encrypted_cookies'`. Любая другая строка приведёт к `NotSupportedException`.
- Не меняй kernel session вручную без явной причины: легко сломать авторизацию и служебные флаги.
- Если нужно только проверить авторизацию в controller, почти всегда достаточно `ActionFilter\Authentication`, а не прямой работы с session internals.
