# Bitrix Безопасность — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с защитой от XSS, SQL-инъекций, CSRF, проверкой прав доступа, аутентификацией или работой с текущим пользователем.
>
> Audit note (core-verified, current project): справочник сверялся по `www/bitrix/modules/main/lib/text/htmlfilter.php`, `engine/actionfilter/{csrf,authentication}.php`, `main/tools.php`, `main/classes/general/user.php` и `iblock/classes/general/iblock.php`.

## Содержание
- XSS: HtmlFilter::encode(), htmlspecialchars, контекстное экранирование
- SQL-инъекции: ORM как защита, forSql() для raw SQL
- CSRF: bitrix_sessid_post(), check_bitrix_sessid(), ActionFilter\Csrf
- Текущий пользователь: CurrentUser (D7), глобальный $USER (legacy)
- Проверка прав: IsAdmin, CanDoOperation, CIBlock::GetPermission
- ActionFilter: Authentication, Csrf, HttpMethod в Controllers
- Общие gotchas безопасности

---

## XSS — экранирование вывода

Любые данные из БД, параметров запроса или пользовательского ввода **обязательно** экранировать перед выводом в HTML.

```php
use Bitrix\Main\Text\HtmlFilter;

// D7-способ — предпочтительный
// HtmlFilter::encode() — это просто htmlspecialchars($str, ENT_COMPAT, 'UTF-8')
echo HtmlFilter::encode($value);

// PHP-способ — эквивалентен, допустим
echo htmlspecialchars($value, ENT_QUOTES, 'UTF-8');

// Экранирование для атрибутов HTML — ENT_QUOTES важен
echo '<input value="' . HtmlFilter::encode($value) . '">';

// Для URL — только urlencode(), не htmlspecialchars
echo '<a href="/page/?q=' . urlencode($searchQuery) . '">';

// Для JSON в JS-контексте — json_encode защищает от XSS
echo '<script>var data = ' . json_encode($data, JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_HEX_AMP) . ';</script>';
```

### Что НЕ является защитой от XSS

```php
// НЕ защищает: strip_tags не убирает атрибуты с JS
echo strip_tags($value); // уязвимо: <img onerror="alert(1)" src="x">

// НЕ защищает: addslashes — только для строк в JS, не для HTML
echo addslashes($value); // не экранирует < > &

// НЕПРАВИЛЬНО: ENT_COMPAT не закрывает одинарные кавычки
echo htmlspecialchars($value, ENT_COMPAT); // уязвимо в атрибутах с '
// ПРАВИЛЬНО:
echo htmlspecialchars($value, ENT_QUOTES, 'UTF-8');
```

## SQL-инъекции — ORM как основная защита

ORM DataManager полностью защищает от SQL-инъекций — параметры передаются через подготовленные выражения.

```php
// БЕЗОПАСНО: ORM экранирует всё автоматически
$result = OrderTable::getList([
    'filter' => ['=TITLE' => $userInput, '%DESCRIPTION' => $searchQuery],
]);

// БЕЗОПАСНО: getById принимает только скалярный тип
$row = OrderTable::getById((int)$_GET['id'])->fetch();

// БЕЗОПАСНО: add/update экранируют значения полей
OrderTable::add(['TITLE' => $userInput]);
```

### Raw SQL — только через forSql()

```php
$connection = \Bitrix\Main\Application::getConnection();
$helper = $connection->getSqlHelper();

// ВСЕГДА экранируй через forSql() перед подстановкой в SQL
$safeTitle = $helper->forSql($userInput);  // добавляет экранирование спецсимволов
$safeId    = (int)$id;                      // числа — просто привести к int

$result = $connection->query(
    "SELECT * FROM my_table WHERE TITLE = '{$safeTitle}' AND ID = {$safeId}"
);

// forSql() не добавляет кавычки — только экранирует содержимое
// Кавычки добавляешь сам: '{$safeTitle}'

// НИКОГДА так:
$connection->query("SELECT * FROM t WHERE ID = " . $_GET['id']); // уязвимость!
$connection->query("SELECT * FROM t WHERE TITLE = '" . $title . "'"); // уязвимость!
```

---

## CSRF — защита форм и AJAX

### Legacy-формы: `bitrix_sessid_post()`

```php
// В шаблоне формы: вставляет скрытый input с токеном
<form method="POST">
    <?= bitrix_sessid_post() ?>
    <!-- Выводит: <input type="hidden" name="sessid" value="TOKEN"> -->
    <input type="text" name="title">
    <button type="submit">Сохранить</button>
</form>

// Проверка на стороне сервера
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!check_bitrix_sessid()) {
        // Неверный CSRF-токен
        ShowError('Неверный токен сессии');
        return;
    }
    // ...обрабатывай форму...
}

// Вспомогательные функции
bitrix_sessid();             // возвращает текущий токен (string)
bitrix_sessid_get();         // возвращает строку 'sessid=TOKEN' (для URL)
check_bitrix_sessid();       // bool: проверяет POST/GET параметр 'sessid' ИЛИ заголовок X-Bitrix-Csrf-Token
check_bitrix_sessid('csrf'); // проверяет параметр с другим именем
```

### D7 Controllers: `ActionFilter\Csrf`

В текущем core у `Engine\Controller` default prefilters уже включают `Authentication + HttpMethod(GET|POST) + Csrf`. Дополнительная автоподстановка `Csrf` есть ещё и в том случае, когда ты переопределил `prefilters`, оставил POST-метод, но сам не добавил `Csrf`.

```php
use Bitrix\Main\Engine\Controller;
use Bitrix\Main\Engine\ActionFilter;

class OrderController extends Controller
{
    public function configureActions(): array
    {
        return [
            // Явный CSRF-фильтр — работает только в SCOPE_AJAX
            'create' => [
                'prefilters' => [
                    new ActionFilter\Authentication(),
                    new ActionFilter\Csrf(),      // проверяет 'sessid' в запросе
                    new ActionFilter\HttpMethod(['POST']),
                ],
            ],
            // Отключить CSRF для webhook (например, внешние вызовы).
            // Важно: здесь ты заменяешь default prefilters, поэтому добавляй нужные HttpMethod/Auth явно.
            'webhook' => [
                'prefilters' => [
                    new ActionFilter\Csrf(false), // false = отключить проверку
                    new ActionFilter\HttpMethod(['POST']),
                ],
            ],
        ];
    }

    public function createAction(string $title): ?array
    {
        return ['id' => 42];
    }

    public function webhookAction(): ?array
    {
        return ['ok' => true];
    }
}
```

### CSRF в AJAX из JS

```javascript
// Получить токен для AJAX запроса
const sessid = BX.bitrix_sessid(); // глобальная функция Bitrix JS

// Или из мета-тега (добавляется ядром автоматически)
const sessid = BX('bx-' + BX.message('bitrix_sessid_key'));

// Передать в fetch
fetch('/bitrix/services/main/ajax.php?action=mymodule.order.create', {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
        'X-Bitrix-Csrf-Token': BX.bitrix_sessid(),  // заголовок — check_bitrix_sessid() его принимает
    },
    body: JSON.stringify({ sessid: BX.bitrix_sessid(), title: 'Test' }),
});
```

---

## Текущий пользователь

### D7: `Engine\CurrentUser` (предпочтительно в сервисах и контроллерах)

```php
use Bitrix\Main\Engine\CurrentUser;

$user = CurrentUser::get(); // никогда не возвращает null

$user->getId();             // int|string|null — null если не авторизован
$user->getLogin();          // string|null
$user->getEmail();          // string|null
$user->getFullName();       // string|null
$user->getFirstName();
$user->getLastName();
$user->getUserGroups();     // array с ID групп ['1', '4', '13']
$user->isAdmin();           // bool
$user->canDoOperation('название_операции'); // bool

// Проверка авторизации
if ($user->getId()) {
    // пользователь авторизован
}
```

### Legacy: глобальный `$USER` (обязателен в компонентах и шаблонах)

```php
global $USER;

// Всегда проверяй что объект существует перед вызовом методов
if (is_object($USER) && $USER->IsAuthorized()) {
    $userId  = (int)$USER->GetID();
    $login   = $USER->GetLogin();
    $email   = $USER->GetEmail();
    $groups  = $USER->GetUserGroupArray();  // array ID групп ['1', '4', '13']
    $isAdmin = $USER->IsAdmin();            // bool
}

// Проверка операции (права в модуле 'main')
if ($USER->CanDoOperation('edit_php')) { ... }
if ($USER->CanDoOperation('view_all')) { ... }

// Получить ID текущего пользователя безопасно
$userId = is_object($USER) ? (int)$USER->GetID() : 0;
```

---

## Проверка прав доступа

### Права доступа к инфоблоку

```php
// CIBlock::GetPermission возвращает: 'D' (Deny), 'R' (Read), 'W' (Write), 'X' (Full)
// CIBlockRights::PUBLIC_READ = 'R', ::EDIT_ACCESS = 'W', ::FULL_ACCESS = 'X'

$permission = CIBlock::GetPermission($iblockId);

if ($permission < 'R') {
    // нет доступа даже на чтение
    ShowError('Нет доступа к инфоблоку');
    return;
}

if ($permission >= 'W') {
    // есть права на редактирование
}

// В GetList автоматически с CHECK_PERMISSIONS
$res = CIBlockElement::GetList(
    [],
    [
        'IBLOCK_ID'        => $iblockId,
        'ACTIVE'           => 'Y',
        'CHECK_PERMISSIONS' => 'Y',    // фильтрует по правам текущего пользователя
        'MIN_PERMISSION'   => 'R',     // минимальный требуемый уровень
    ]
);
```

### Проверка прав на модуль (`$APPLICATION->GetGroupRight`)

```php
global $APPLICATION;

// Права текущего пользователя на модуль
$right = $APPLICATION->GetGroupRight('iblock'); // 'D', 'R', 'W' или 'X'
if ($right < 'W') {
    ShowError('Недостаточно прав');
    return;
}

// Проверка прав для конкретного пользователя
// В компонентах admin-панели — стандартная проверка:
if (!$USER->CanDoOperation('edit_iblock') && $APPLICATION->GetGroupRight('iblock') < 'W') {
    $APPLICATION->AuthForm("Доступ запрещён");
}
```

### Проверка в AdminSection

```php
// Стандартный паттерн для страниц /bitrix/admin/
require_once($_SERVER['DOCUMENT_ROOT'] . '/bitrix/modules/main/include/prolog_admin_before.php');

// После подключения пролога $USER и $APPLICATION доступны глобально
\Bitrix\Main\Loader::includeModule('my.module');

$right = $APPLICATION->GetGroupRight('my.module'); // читает из таблицы прав
if ($right === 'D') {
    $APPLICATION->AuthForm('Доступ запрещён');
}

require_once($_SERVER['DOCUMENT_ROOT'] . '/bitrix/modules/main/include/prolog_admin_after.php');
```

### ActionFilter\Authentication — защита Controller-экшенов

```php
// Добавь в configureActions() чтобы требовать авторизацию
'prefilters' => [
    new ActionFilter\Authentication(),
    // Authentication(true) — перенаправляет на форму логина для non-AJAX запросов
    // Authentication(false) — только 401 ответ без редиректа (по умолчанию)
],
```

---

## Шифрование и хеширование паролей

```php
// НЕ используй md5/sha1 для паролей
// В текущем core хеширование делает \Bitrix\Main\Security\Password::hash()

use Bitrix\Main\Security\Password;

$hashedPassword = Password::hash($plainPassword);

// Но в прикладном коде обычно лучше не хешировать пароль вручную:
// CUser::Add / CUser::Update / ChangePassword сами используют Password::hash()
// Проверку делай через стандартные потоки авторизации, а не прямым сравнением хеша
```

---

## Gotchas безопасности

- **`HtmlFilter::encode()` использует `ENT_COMPAT`** по умолчанию (не `ENT_QUOTES`) — экранирует `"` но не `'`. Для атрибутов с одинарными кавычками передай флаг явно: `HtmlFilter::encode($v, ENT_QUOTES)`
- **`check_bitrix_sessid()` принимает токен из двух мест**: POST/GET параметр `sessid` ИЛИ заголовок `X-Bitrix-Csrf-Token`. Если шлёшь через заголовок — в теле параметр не нужен.
- **`ActionFilter\Csrf` работает только в `SCOPE_AJAX`** (проверено в `listAllowedScopes()`). В `SCOPE_REST` или `SCOPE_DEFAULT` фильтр пропускается — нужен отдельный механизм защиты.
- **`CIBlock::GetPermission()` кешируется в статике** внутри запроса — повторные вызовы с теми же `$IBLOCK_ID` и группами не идут в БД.
- **Права 'D' < 'R' < 'W' < 'X'** — сравнение строк работает корректно для этих букв в ASCII. `$p < 'R'` значит нет чтения.
- **`CurrentUser::get()` никогда не возвращает null** — возвращает объект у которого `getId()` вернёт `null`. Всегда проверяй `$user->getId()` а не наличие объекта.
- **`$USER->IsAdmin()`** возвращает `true` только если пользователь в группе с ID=1 (администраторы) — обычные `bitrix_admin` операции этого не дают.
- **Не полагайся на `$_SESSION`** напрямую для хранения прав — используй только механизмы Bitrix (`$USER`, `$APPLICATION->GetGroupRight`).

---

## Composite Cache + личные данные (bx-dynamic)

### Архитектура Composite

Bitrix Composite — механизм кеширования полной страницы с выделением «динамических» (персональных) блоков:
- **Статическая часть** кешируется целиком на диск/nginx как HTML.
- **Динамические блоки** (`bx-dynamic`) вырезаются и подгружаются отдельным AJAX-запросом.
- Результат: авторизованные пользователи получают кешированную основу страницы, а персональные данные (корзина, имя, лайки) подгружаются асинхронно.

### CBitrixComponent::setFrameMode(true)

```php
// В component.php компонента-«оболочки» (статический блок)
// Включает composite-режим: компонент участвует в composite-кешировании
if ($this->startResultCache()) {
    // Весь код внутри кешируется
    $this->arResult['ITEMS'] = $this->getItems();
    $this->includeComponentTemplate();
    $this->endResultCache();
}

// Включить frame-режим (composite) для компонента
$this->setFrameMode(true);
// После этого компонент получит <div id="bx_..."> обёртку
// которую composite-движок умеет вырезать и подставлять
```

### Правильный паттерн: оболочка + динамический блок

```php
// template.php статического компонента (каталог, список новостей)
// Весь шаблон кешируется. Внутри — вызов персонального компонента:

/** @var CBitrixComponentTemplate $this */
/** @var array $arResult */

// Подключить "личный" компонент как динамический блок
// APPLICATION->IncludeComponent с setFrameMode обеспечивает bx-dynamic
$APPLICATION->IncludeComponent(
    'vendor:user.cart.mini',   // персональный компонент (корзина, избранное, etc.)
    '',
    [
        'CACHE_TYPE' => 'N',   // НИКОГДА не кешировать персональный компонент
    ],
    $component,                // родительский компонент
    ['HIDE_ICONS' => 'Y']      // параметры для dynamic-блока
);
```

```php
// component.php персонального компонента (bx-dynamic блок)
// Этот компонент НЕ должен использовать кеш — он всегда персональный

global $USER;

// Включить режим dynamic-frame (компонент будет подгружаться через AJAX)
$this->setFrameMode(true);

// Получить персональные данные
$this->arResult['USER_ID']    = is_object($USER) ? (int)$USER->GetID() : 0;
$this->arResult['CART_COUNT'] = $this->getCartCount($this->arResult['USER_ID']);
$this->arResult['USER_NAME']  = is_object($USER) ? $USER->GetFirstName() : '';

// Без кеша — данные всегда актуальные
$this->includeComponentTemplate();
```

### CCompositeHelper::Init()

```php
// CCompositeHelper::Init() вызывается ядром автоматически при загрузке страницы
// Что он делает:
// 1. Определяет, включён ли composite для текущего сайта (настройки в /bitrix/admin/)
// 2. Проверяет, подходит ли страница для composite (не POST, не ajax, нет ?clear_cache=Y)
// 3. Если страница в кеше — отдаёт HTML из кеша немедленно, без выполнения PHP
// 4. Если не в кеше — запускает обычный цикл выполнения и сохраняет результат

// Явная инициализация (редко нужна — обычно делается ядром автоматически):
\CCompositeHelper::Init([
    'CACHE_TIME' => 3600,         // TTL кеша в секундах
    'CACHE_TYPE' => 'A',          // A = авто, N = не кешировать, Y = всегда
]);

// Проверить, работает ли composite сейчас
$isComposite = \CCompositeHelper::IsEnabled(); // bool
```

### setFrameMode + SetCacheProperty

```php
// setFrameMode(true) без SetCacheProperty не даёт эффекта в шаблоне!
// Нужно явно объявить какие свойства arResult участвуют в кеше

// В component.php:
$this->setFrameMode(true);

// Кешировать только эти ключи arResult (остальные будут переданы в dynamic-режим)
$frame = $this->createFrame()->begin(); // создать frame-объект

$this->arResult['CACHED_DATA'] = $this->getCachedData();   // кешируется
$this->arResult['USER_SPECIFIC'] = null;                    // не кешируется — заполнится dynamic

$frame->end(); // закрыть frame — всё что внутри begin/end кешируется
$this->includeComponentTemplate();
```

### JS: BX.message / BX.userOptions для персональных данных

```javascript
// Передать персональные данные в JS без пробива кеша (в шаблоне компонента)
// BX.message() — глобальный JS-словарь, заполняется через PHP

// В PHP шаблоне dynamic-компонента (не кешируется):
?>
<script>
BX.message({
    'USER_ID':    <?= (int)$arResult['USER_ID'] ?>,
    'USER_NAME':  '<?= CUtil::JSEscape($arResult['USER_NAME']) ?>',
    'CART_COUNT': <?= (int)$arResult['CART_COUNT'] ?>,
});
</script>
<?php

// В JS-коде:
// Получить данные
const userId    = BX.message('USER_ID');
const cartCount = BX.message('CART_COUNT');

// BX.userOptions — хранение пользовательских настроек (persistentные)
// Сохранить настройку
BX.userOptions.save('mymodule', 'sidebar_open', 'Y');

// Получить настройку
const sidebarState = BX.userOptions.get('mymodule', 'sidebar_open', 'N'); // 'N' — default
```

### CSP-заголовки: добавление через Response

```php
use Bitrix\Main\Application;

$response = Application::getInstance()->getResponse();

// Добавить заголовок Content-Security-Policy
$response->addHeader(
    'Content-Security-Policy',
    "default-src 'self'; " .
    "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://cdn.bitrix24.com; " .
    "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; " .
    "img-src 'self' data: https:; " .
    "font-src 'self' https://fonts.gstatic.com; " .
    "connect-src 'self' wss: https:; " .  // wss: для WebSocket (Push&Pull)
    "frame-ancestors 'self'; " .
    "base-uri 'self'"
);

// Добавить X-Frame-Options (защита от clickjacking)
$response->addHeader('X-Frame-Options', 'SAMEORIGIN');

// Добавить X-Content-Type-Options (защита от MIME-sniffing)
$response->addHeader('X-Content-Type-Options', 'nosniff');

// Referrer-Policy
$response->addHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
```

### Типичная CSP-политика для Bitrix-сайта

```
Content-Security-Policy:
  default-src 'self';
  script-src  'self' 'unsafe-inline' 'unsafe-eval'
              https://api-maps.yandex.ru
              https://mc.yandex.ru
              https://www.googletagmanager.com
              https://www.google-analytics.com;
  style-src   'self' 'unsafe-inline'
              https://fonts.googleapis.com;
  img-src     'self' data: blob:
              https://mc.yandex.ru
              https://www.google-analytics.com;
  font-src    'self' data:
              https://fonts.gstatic.com;
  connect-src 'self' wss: https:;
  frame-src   'self' https://www.youtube.com https://vk.com;
  frame-ancestors 'self';
  base-uri    'self';
  form-action 'self';
```

> `'unsafe-inline'` и `'unsafe-eval'` обязательны для Bitrix — ядро и большинство компонентов используют inline-скрипты. Убрать их можно только при полном отказе от стандартных компонентов.

### Gotchas Composite + CSP

- **Composite не работает для авторизованных пользователей без dynamic-блоков**: если на странице есть персональные данные прямо в кешируемом шаблоне (имя пользователя, корзина) — composite либо отключится автоматически, либо покажет чужие данные. Выноси всё персональное в отдельный компонент с `setFrameMode(true)` и `CACHE_TYPE = 'N'`.
- **`setFrameMode(true)` без `$this->createFrame()->begin()/end()`** не разделяет кешируемую и динамическую части — весь компонент уйдёт в dynamic (то есть никакого кеша не будет). Оборачивай кешируемую часть в `begin/end`.
- **`$APPLICATION->IncludeComponent()` внутри кешируемого шаблона** — dynamic-подкомпонент корректно выделяется только если вызов находится внутри уже запущенного composite-frame. Вне frame вызов выполнится синхронно без dynamic-механики.
- **Не добавляй заголовки после вывода**: `$response->addHeader()` нужно вызывать до любого вывода (`echo`, `?>`). После начала вывода в composite-режиме заголовки могут не примениться.
- **CSP `connect-src`** должен включать `wss:` (WebSocket) если используется Push&Pull — иначе браузер заблокирует WebSocket-соединение.
- **`BX.message()`** сбрасывается при каждой загрузке страницы. Для persistentного хранения используй `BX.userOptions` (сохраняет на сервере в `b_user_option`) или `localStorage`.
- **Composite и AJAX-компоненты**: компонент вызванный через `$APPLICATION->IncludeComponent()` внутри `bitrix:ajax.updater` не участвует в composite — это разные механизмы. Не смешивай их.
