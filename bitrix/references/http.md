# Bitrix HTTP, DateTime, HttpClient — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с датами (Type\DateTime, Type\Date), внешними HTTP-запросами (HttpClient), входящим запросом (HttpRequest) или исходящим ответом (HttpResponse).

## Содержание
- Type\DateTime и Type\Date: создание, арифметика, форматирование, таймзоны
- HttpClient: GET/POST запросы, заголовки, обработка ошибок
- HttpRequest: getQuery/getPost/getCookie/isAjax/isJson/decodeJson
- HttpResponse: addHeader/setStatus/addCookie/flush/redirectTo

---

## Type\DateTime и Type\Date

### Главное правило: toString() vs format()

`DateTime` хранит время в серверной таймзоне. Это разграничение критично:

- `format('d.m.Y H:i:s')` → **серверное время**, для хранения, логов, сравнений
- `toString()` → **пользовательское время** (авто-конвертация через `\CTimeZone`), для отображения

Ошибка: сравнивать `toString()` двух объектов — они уже в пользовательской зоне, результат непредсказуем. Всегда сравнивай через `getTimestamp()`.

```php
use Bitrix\Main\Type\DateTime;
use Bitrix\Main\Type\Date;

// Создание
$now  = new DateTime();                                        // текущий момент
$dt   = new DateTime('2024-06-15 14:30:00');                   // из строки Bitrix-формата
$dt   = DateTime::createFromTimestamp(time());                 // из UNIX timestamp
$dt   = DateTime::createFromUserTime('15.06.2024 14:30:00');  // из строки в зоне пользователя
$dt   = DateTime::createFromPhp(new \DateTime('now'));         // из PHP-нативного \DateTime
$dt   = DateTime::tryParse($userInput);                        // null при ошибке, не кидает исключение

$date = new Date('2024-06-15', 'Y-m-d');  // Date — только дата без времени
$date = Date::createFromTimestamp(time());

// Форматирование
$dt->format('d.m.Y H:i:s');   // серверное время — для хранения и логики
$dt->toString();               // пользовательское время — для вывода в HTML
$dt->getTimestamp();           // UNIX timestamp — для сравнений

// Управление конвертацией таймзоны
$dt->disableUserTime();  // toString() тоже вернёт серверное время
$dt->enableUserTime();   // вернуть по умолчанию (включена)

// Арифметика — ISO 8601 DateInterval
$dt->add('P1D');     // +1 день
$dt->add('P1M');     // +1 месяц
$dt->add('PT2H');    // +2 часа
$dt->add('PT30M');   // +30 минут
$dt->add('-P1D');    // -1 день

$dt->setTime(0, 0, 0);  // начало дня
$dt->setTimeZone(new \DateTimeZone('Europe/Moscow'));

// В ORM — DatetimeField принимает и возвращает объект DateTime
OrderTable::update($id, ['DEADLINE' => new DateTime('2024-12-31 23:59:59')]);
$row  = OrderTable::getById($id)->fetch();
$date = $row['CREATED_AT']; // instanceof DateTime
echo $date->format('d.m.Y');   // серверное
echo $date->toString();        // пользовательское
```

---

## HttpClient — внешние HTTP-запросы

`HttpClient` **не бросает исключений** на HTTP-ошибки (4xx, 5xx). Он возвращает тело ответа, а статус и транспортные ошибки нужно проверять вручную через `getStatus()` и `getError()`. Это самое частое место где пропускают проверку.

```php
use Bitrix\Main\Web\HttpClient;

$client = new HttpClient([
    'socketTimeout'          => 10,    // таймаут подключения (сек)
    'streamTimeout'          => 30,    // таймаут чтения (сек)
    'redirect'               => true,
    'redirectMax'            => 5,
    'disableSslVerification' => false, // true только для локальной разработки
]);

// GET — возвращает тело ответа (string) или false
$body   = $client->get('https://api.example.com/data');
$status = $client->getStatus(); // int: 200, 404, 500...
$errors = $client->getError();  // array транспортных ошибок (пустой если нет)

if (!empty($errors)) {
    // Ошибка соединения, DNS, timeout — запрос не дошёл
} elseif ($status !== 200) {
    // Сервер ответил, но с ошибкой
} else {
    $data = json_decode($body, true);
}

// POST с JSON
$client->setHeader('Content-Type', 'application/json');
$client->setHeader('Authorization', 'Bearer ' . $token);
$body = $client->post('https://api.example.com/orders', json_encode(['title' => 'Test']));

// POST с form-data
$body = $client->post('https://api.example.com/form', ['field1' => 'v1', 'field2' => 'v2']);

// Скачать файл на диск
$client->download('https://example.com/file.pdf', '/tmp/file.pdf');

// Заголовки ответа
$contentType = $client->getHeaders()->get('Content-Type');
```

---


---
## HttpRequest — входящий запрос

`HttpRequest` — D7-обёртка над `$_GET`, `$_POST`, `$_COOKIE`, `$_FILES`, заголовками. Проходит через фильтры безопасности ядра. **Никогда не читай `$_GET`/`$_POST` напрямую в D7-коде**.

```php
use Bitrix\Main\Application;

$request = Application::getInstance()->getContext()->getRequest();

// Параметры запроса
$id      = (int)$request->getQuery('id');           // GET['id']
$title   = $request->getPost('title');              // POST['title']
$file    = $request->getFile('upload');             // FILES['upload'] — массив
$merged  = $request->get('param');                  // GET+POST merged (осторожно — используй getQuery/getPost)

// Все значения как ParameterDictionary (iterable, методы get/toArray/getValues)
$getParams  = $request->getQueryList();
$postParams = $request->getPostList();
$files      = $request->getFileList();

// JSON-запросы (Content-Type: application/json)
if ($request->isJson()) {
    $request->decodeJson(); // парсит php://input → jsonData
}
$body = $request->getJsonList()->get('key'); // данные из тела JSON

// Заголовки (нижний регистр, дефисы вместо _)
$auth        = $request->getHeader('authorization');
$contentType = $request->getHeader('content-type');
$headers     = $request->getHeaders(); // HttpHeaders object

// Cookies (BITRIX_SM_ prefix снимается автоматически, содержимое расшифровывается)
$userId = $request->getCookie('USER_ID'); // из BITRIX_SM_USER_ID
$rawCookie = $request->getCookieRaw('USER_ID'); // без расшифровки

// Метаданные
$ip      = $request->getRemoteAddress();     // REMOTE_ADDR
$ua      = $request->getUserAgent();         // HTTP_USER_AGENT
$uri     = $request->getRequestUri();        // /catalog/item/?id=5
$page    = $request->getRequestedPage();     // /catalog/item/index.php
$method  = $request->getRequestMethod();     // 'GET', 'POST', ...

// Проверки
$request->isPost();          // bool: метод = POST
$request->isAjaxRequest();   // bool: HTTP_BX_AJAX или X-Requested-With: XMLHttpRequest
$request->isHttps();         // bool: HTTPS или порт 443
$request->isAdminSection();  // bool: /bitrix/admin/

// Raw body (для webhook'ов, подписей)
$rawBody = \Bitrix\Main\HttpRequest::getInput(); // file_get_contents('php://input')
```

### Важно: `getCookie()` снимает префикс

Bitrix хранит cookies с префиксом (по умолчанию `BITRIX_SM_`). `getCookie('USER_ID')` ищет в браузере куку `BITRIX_SM_USER_ID` и возвращает её значение без префикса. `getCookieRaw()` работает с RAW именами без обработки.

---

## HttpResponse — исходящий ответ

```php
use Bitrix\Main\Application;

$response = Application::getInstance()->getContext()->getResponse();

// Заголовки
$response->addHeader('X-Custom-Header', 'value');
$response->addHeader('Content-Type', 'application/json; charset=utf-8');

// HTTP-статус
$response->setStatus(404);           // только код
$response->setStatus('404 Not Found'); // код + reason phrase
$response->getStatus();              // int

// Cookies
use Bitrix\Main\Web\Cookie;
$cookie = new Cookie('MY_PARAM', 'value', time() + 86400);
$cookie->setPath('/');
$cookie->setHttpOnly(true);
$cookie->setSecure(true);
$response->addCookie($cookie);

// Редирект
LocalRedirect('/new/url/'); // legacy, но до сих пор стандарт для компонентов

// D7-способ редиректа (из Controller или роута)
$redirectResponse = $response->redirectTo('/new/url/');
// redirectTo возвращает новый объект Engine\Response\Redirect

// Контент + сброс
$response->setContent(json_encode($data));
$response->flush(); // сбрасывает буферы, отправляет заголовки + тело, fastcgi_finish_request если доступен
```

### Gotchas HttpResponse

- **`flush()` очищает ВСЕ output-буферы** (`while ob_get_length()`) — вызывай только когда готов завершить ответ
- **`redirectTo()` не делает редирект сразу** — возвращает объект `Redirect`. Его нужно передать фреймворку (из `Controller::run()`) или вызвать `$redirect->flush()`
- **Куки через `addCookie`** автоматически получают префикс `BITRIX_SM_` при отправке, шифруются если настроено
- **`Content-Type` по умолчанию** — Bitrix выставляет `text/html; charset=utf-8`. Для JSON API обязательно переопредели

---

## CryptoCookie — шифрованные куки

`CryptoCookie` шифрует значение AES-256 через `crypto_key` из `.settings.php`. В отличие от обычной `Cookie` (plaintext, только подписывается), `CryptoCookie` скрывает содержимое от пользователя — обязательна для хранения пользовательских данных в браузере (корзина гостя, избранное, данные сессии).

**Cookie vs CryptoCookie:**
- `Cookie` — plaintext-значение, подписывается, но **не шифруется** — пользователь видит содержимое
- `CryptoCookie` — шифруется AES-256 через `crypto_key` из `.settings.php` — содержимое скрыто

```php
use Bitrix\Main\Web\CryptoCookie;
use Bitrix\Main\Context;

// ЗАПИСЬ зашифрованной куки
$cookie = new CryptoCookie(
    'FAVORITES',                    // имя (будет с префиксом BITRIX_SM_)
    json_encode([1, 2, 3]),         // значение — шифруется автоматически
    time() + 30 * 24 * 3600        // expire
);
$cookie->setPath('/');
$cookie->setHttpOnly(true);         // недоступна из JS
$cookie->setSecure(true);           // только HTTPS
$cookie->setSameSite('Lax');        // защита от CSRF через куки
Context::getCurrent()->getResponse()->addCookie($cookie);

// ЧТЕНИЕ зашифрованной куки
$raw = Context::getCurrent()->getRequest()->getCookie('FAVORITES');
// getCookie() автоматически расшифровывает CryptoCookie
$ids = $raw ? json_decode($raw, true) : [];

// УДАЛЕНИЕ куки (expire в прошлом)
$cookie = new CryptoCookie('FAVORITES', '', time() - 3600);
$cookie->setPath('/');
Context::getCurrent()->getResponse()->addCookie($cookie);
```

### Gotcha: crypto_key

`CryptoCookie` падает если `crypto_key` не настроен в `.settings.php` сайта. Опциональная проверка перед записью:

```php
// Проверка наличия crypto_key
$config = \Bitrix\Main\Config\Configuration::getInstance();
$security = $config->get('crypto');
$hasCryptoKey = !empty($security['crypto_key']);

if ($hasCryptoKey) {
    $cookie = new CryptoCookie('FAVORITES', json_encode($ids), time() + 30 * 24 * 3600);
} else {
    // Fallback: обычная Cookie (данные видны пользователю)
    $cookie = new \Bitrix\Main\Web\Cookie('FAVORITES', json_encode($ids), time() + 30 * 24 * 3600);
}
$cookie->setPath('/');
$cookie->setHttpOnly(true);
Context::getCurrent()->getResponse()->addCookie($cookie);
```

Настройка `crypto_key` в `.settings.php` сайта:
```php
'crypto' => ['value' => ['crypto_key' => 'your-32-char-secret-key-here!!!']],
```

---

---
