# Bitrix Subscribe — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с email-рассылками, управлением подписками, шаблонами писем или отправкой рассылок через модуль subscribe.

## Содержание
- Архитектура модуля subscribe
- CSender — отправители (FROM email)
- CSubscribe — подписки (рубрики)
- CSubscription — подписчики
- CPosting — рассылки (письма)
- CSending — отправка
- CPostingTemplate — шаблоны писем
- Подписать/отписать пользователя
- Проверить подписку
- Создать рассылку и отправить
- Gotchas

---

## Архитектура

**Иерархия модуля subscribe:**
```
CSender (отправитель FROM)
  └── CSubscribe (рубрика/список рассылки)
        ├── CSubscription (подписчик ↔ рубрика)
        └── CPosting (конкретное письмо-рассылка)
              └── CSending (процесс отправки)
```

- **CSender** — email и имя отправителя (FROM).
- **CSubscribe** — рубрика рассылки (категория). Пользователь подписывается на рубрики.
- **CSubscription** — запись подписчика: email + привязка к рубрикам + статус подтверждения.
- **CPosting** — конкретное письмо: тема, тело, список получателей.
- **CSending** — процесс отправки письма (батчи, статус доставки).
- **CPostingTemplate** — шаблоны HTML/текст для писем.

---

## CSender — отправители

```php
use Bitrix\Main\Loader;

Loader::includeModule('subscribe');

// Получить список отправителей
$senderRes = CSender::GetList(['NAME' => 'ASC'], []);
while ($sender = $senderRes->Fetch()) {
    // ID, NAME, EMAIL, ACTIVE
}

// Получить отправителя по ID
$sender = CSender::GetByID($senderId);

// Добавить отправителя
$newSenderId = CSender::Add([
    'SITE_ID' => SITE_ID,
    'NAME'    => 'Название компании',
    'EMAIL'   => 'noreply@example.com',
    'ACTIVE'  => 'Y',
]);

// Обновить
CSender::Update($senderId, ['NAME' => 'Новое имя']);

// Удалить
CSender::Delete($senderId);
```

---

## CSubscribe — рубрики рассылки

```php
Loader::includeModule('subscribe');

// Получить список рубрик
$rubricRes = CSubscribe::GetList(['SORT' => 'ASC'], ['ACTIVE' => 'Y', 'SITE_ID' => SITE_ID]);
while ($rubric = $rubricRes->Fetch()) {
    // ID, NAME, DESCRIPTION, ACTIVE, SORT, SITE_ID, SENDER_ID, SUBSCR_FORMAT
}

// Получить рубрику по ID
$rubric = CSubscribe::GetByID($rubricId);

// Создать рубрику
$rubricId = CSubscribe::Add([
    'SITE_ID'       => SITE_ID,
    'NAME'          => 'Новости',
    'DESCRIPTION'   => 'Ежемесячная новостная рассылка',
    'ACTIVE'        => 'Y',
    'SORT'          => 100,
    'SENDER_ID'     => $senderId,       // ID отправителя из CSender
    'SUBSCR_FORMAT' => 'html',          // html или text
    'TEMPLATE_ID'   => $templateId,     // шаблон письма по умолчанию
    'AUTO_SEND_TIME'=> '',
    'DAYS_OF_MONTH' => '',
    'DAYS_OF_WEEK'  => '',
    'SEND_TIME'     => '',
]);

// Обновить
CSubscribe::Update($rubricId, ['NAME' => 'Актуальные новости']);

// Удалить
CSubscribe::Delete($rubricId);
```

---

## CSubscription — подписчики

```php
Loader::includeModule('subscribe');

// Получить подписки по email
$subscriptionRes = CSubscription::GetByEmail('user@example.com', SITE_ID);
$subscription = $subscriptionRes->Fetch();
// ID, EMAIL, USER_ID, FORMAT, CONFIRMED, CODE (для ссылки отписки), DATE_INSERT

// Получить подписку по ID
$subscription = CSubscription::GetByID($subscriptionId);

// Получить все рубрики подписчика
$rubricIds = [];
if ($subscription) {
    $rubricRes = CSubscription::GetRubricList($subscription['ID']);
    while ($r = $rubricRes->Fetch()) {
        $rubricIds[] = (int)$r['RUBRIC_ID'];
    }
}

// Получить всех подписчиков рубрики
$subscribers = CSubscription::GetList(
    ['DATE_INSERT' => 'DESC'],
    ['RUBRIC_ID' => $rubricId, 'CONFIRMED' => 'Y', 'ACTIVE' => 'Y'],
    false, false,
    ['ID', 'EMAIL', 'USER_ID', 'FORMAT', 'DATE_INSERT']
);
while ($sub = $subscribers->Fetch()) { /* ... */ }

// Добавить/обновить подписчика вручную
$subscriptionId = CSubscription::Add([
    'SITE_ID'   => SITE_ID,
    'USER_ID'   => $userId,   // 0 если анонимный
    'EMAIL'     => 'user@example.com',
    'FORMAT'    => 'html',
    'CONFIRMED' => 'Y',       // Y = подтверждена, N = ожидает подтверждения
    'ACTIVE'    => 'Y',
    'RID'       => [$rubricId], // массив ID рубрик
]);

// Удалить подписку
CSubscription::Delete($subscriptionId);
```

---

## CSubscribe::Subscribe — подписать пользователя

```php
Loader::includeModule('subscribe');

// Подписать авторизованного пользователя
// CSubscribe::Subscribe($rubricIds, $userId, $email, $format, $siteId, $confirmed)
$result = CSubscribe::Subscribe(
    [$rubricId1, $rubricId2],   // массив ID рубрик
    $userId,                     // ID пользователя (0 для анонимного)
    'user@example.com',          // email
    'html',                      // формат: html или text
    SITE_ID,                     // SITE_ID обязателен
    'Y'                          // Y = сразу подтверждена (без письма-подтверждения)
);
// $result: ID подписки (int) или false при ошибке

// Подписать анонимного (с отправкой письма-подтверждения)
$result = CSubscribe::Subscribe(
    [$rubricId],
    0,
    'anonymous@example.com',
    'html',
    SITE_ID,
    'N'   // N = требует подтверждения по email
);

// Отписать по ID подписки
CSubscribe::UnSubscribe($subscriptionId);

// Отписать по email и рубрике
$sub = CSubscription::GetByEmail('user@example.com', SITE_ID)->Fetch();
if ($sub) {
    CSubscription::Update($sub['ID'], ['ACTIVE' => 'N']);
}
```

---

## CPosting — создание рассылки

```php
Loader::includeModule('subscribe');

// Создать новое письмо-рассылку
$postingId = CPosting::Add([
    'SITE_ID'     => SITE_ID,
    'RUBRIC_ID'   => [$rubricId],    // рубрики-получатели
    'SENDER_ID'   => $senderId,
    'FROM_FIELD'  => '"Компания" <noreply@example.com>',  // если не через senderId
    'SUBJECT'     => 'Новости за неделю',
    'BODY_TYPE'   => 'html',         // html или text
    'BODY'        => '<html><body>
        <h1>Заголовок</h1>
        <p>Текст рассылки</p>
        <a href="#UNSUB_LINK#">Отписаться</a>
    </body></html>',
    'BODY_TYPE_ALT' => 'text',       // альтернативный формат
    'BODY_ALT'      => 'Текст рассылки (текстовая версия). Отписаться: #UNSUB_LINK#',
    'DIRECT_SEND' => 'N',            // N = через очередь CSending
    'TEMPLATE_ID' => 0,
]);

// Обновить рассылку
CPosting::Update($postingId, ['SUBJECT' => 'Обновлённая тема']);

// Удалить
CPosting::Delete($postingId);

// Получить список рассылок
$postings = CPosting::GetList(
    ['DATE_CREATE' => 'DESC'],
    ['SITE_ID' => SITE_ID],
    false, ['nTopCount' => 20],
    ['ID', 'SUBJECT', 'STATUS', 'DATE_CREATE', 'SENT_COUNT']
);
while ($p = $postings->Fetch()) { /* STATUS: N=новая, P=в процессе, Y=отправлена */ }
```

---

## CSending — отправка рассылки

```php
Loader::includeModule('subscribe');

// Инициировать отправку рассылки
// CSending создаёт задачу отправки, реальная отправка идёт через агенты

// Способ 1: через CSending::Add (создать задание на отправку)
$sendingId = CSending::Add([
    'POSTING_ID'   => $postingId,
    'DATE_CREATE'  => date('d.m.Y H:i:s'),
    'DATE_EXECUTE' => date('d.m.Y H:i:s'),  // когда отправить (сейчас или в будущем)
    'STATUS'       => 'W',                   // W=waiting, S=sending, Y=sent, E=error
    'TRACK_CLICK'  => 'Y',
    'TRACK_READ'   => 'Y',
]);

// Способ 2: немедленная отправка через SendMessage (legacy, синхронная)
// Используй только для тестовых отправок — блокирует выполнение
$result = CSending::SendMessage(
    $postingId,
    'recipient@example.com',         // конкретный email или null для всех подписчиков
    [
        '#NAME#'    => 'Иван',        // плейсхолдеры для замены в теле письма
        '#SURNAME#' => 'Иванов',
    ]
);

// Получить статус отправки
$sending = CSending::GetByID($sendingId);
// STATUS: W=ожидание, S=отправляется, Y=отправлено, E=ошибка
// SENT_COUNT — количество отправленных

// Запустить обработку очереди (вызывается агентом автоматически)
CSending::InitAgents();
```

---

## CPostingTemplate — шаблоны писем

```php
Loader::includeModule('subscribe');

// Получить список шаблонов
$templateRes = CPostingTemplate::GetList(['NAME' => 'ASC'], ['SITE_ID' => SITE_ID]);
while ($tmpl = $templateRes->Fetch()) {
    // ID, NAME, SUBJECT, BODY, BODY_TYPE, SITE_ID
}

// Получить шаблон по ID
$template = CPostingTemplate::GetByID($templateId);

// Создать шаблон
$templateId = CPostingTemplate::Add([
    'SITE_ID'   => SITE_ID,
    'NAME'      => 'Базовый HTML-шаблон',
    'SUBJECT'   => 'Рассылка от #DATE#',
    'BODY_TYPE' => 'html',
    'BODY'      => '<!DOCTYPE html><html><body>
        <table width="600" cellpadding="0" cellspacing="0">
            <tr><td>#CONTENT#</td></tr>
            <tr><td><a href="#UNSUB_LINK#">Отписаться</a></td></tr>
        </table>
    </body></html>',
]);

// Плейсхолдеры в теле письма:
// #UNSUB_LINK# — ссылка для отписки (генерируется автоматически)
// #SITE_URL#   — URL сайта
// #DATE#       — дата отправки
// #USER_NAME#  — имя получателя (если USER_ID привязан)
// #EMAIL#      — email получателя
// Кастомные: любые #MY_VAR# — замени через CSending::SendMessage массивом замен
```

---

## Проверить подписку

```php
Loader::includeModule('subscribe');

$email = 'user@example.com';

// Проверить, подписан ли email на хоть одну рубрику сайта
$subRes = CSubscription::GetByEmail($email, SITE_ID);
$subscription = $subRes->Fetch();

if ($subscription && $subscription['CONFIRMED'] === 'Y' && $subscription['ACTIVE'] === 'Y') {
    echo 'Подписан, ID: ' . $subscription['ID'];

    // Получить список рубрик подписчика
    $rubrics = CSubscription::GetRubricList($subscription['ID']);
    while ($r = $rubrics->Fetch()) {
        echo 'Рубрика: ' . $r['RUBRIC_ID'];
    }
} else {
    echo 'Не подписан или ожидает подтверждения';
}

// Проверить подписку на конкретную рубрику
function isSubscribedToRubric(string $email, int $rubricId, string $siteId): bool
{
    $subRes = CSubscription::GetByEmail($email, $siteId);
    $sub = $subRes->Fetch();
    if (!$sub || $sub['CONFIRMED'] !== 'Y' || $sub['ACTIVE'] !== 'Y') {
        return false;
    }

    $rubrics = CSubscription::GetRubricList($sub['ID']);
    while ($r = $rubrics->Fetch()) {
        if ((int)$r['RUBRIC_ID'] === $rubricId) {
            return true;
        }
    }
    return false;
}
```

---

## Ссылка отписки (#UNSUB_LINK#)

```html
<!-- В теле письма (HTML) -->
<a href="#UNSUB_LINK#">Отписаться от рассылки</a>

<!-- В текстовой версии -->
Отписаться: #UNSUB_LINK#
```

```php
// Ссылка генерируется автоматически при отправке через CSending
// Формат: /bitrix/tools/subscribe/unsubscribe.php?code=HASH&...
// HASH — уникальный код подписчика из поля CSubscription.CODE

// Получить код для ручной генерации ссылки отписки
$sub = CSubscription::GetByEmail('user@example.com', SITE_ID)->Fetch();
if ($sub) {
    $unsubUrl = '/bitrix/tools/subscribe/unsubscribe.php?code=' . urlencode($sub['CODE']);
}
```

---

## Полный пример: создать рассылку и поставить в очередь

```php
use Bitrix\Main\Loader;

Loader::includeModule('subscribe');

// 1. Убедиться что рубрика и отправитель существуют
$sender = CSender::GetByID($senderId)->Fetch();
$rubric = CSubscribe::GetByID($rubricId)->Fetch();

if (!$sender || !$rubric || $rubric['ACTIVE'] !== 'Y') {
    throw new \RuntimeException('Отправитель или рубрика недоступны');
}

// 2. Создать письмо
$postingId = CPosting::Add([
    'SITE_ID'    => SITE_ID,
    'RUBRIC_ID'  => [$rubricId],
    'SENDER_ID'  => $senderId,
    'SUBJECT'    => 'Еженедельный дайджест',
    'BODY_TYPE'  => 'html',
    'BODY'       => '<html><body><p>Контент письма</p><a href="#UNSUB_LINK#">Отписаться</a></body></html>',
    'DIRECT_SEND'=> 'N',
]);

if (!$postingId) {
    global $APPLICATION;
    throw new \RuntimeException('Ошибка создания рассылки: ' . $APPLICATION->GetException()->GetString());
}

// 3. Поставить в очередь отправки
$sendingId = CSending::Add([
    'POSTING_ID'   => $postingId,
    'DATE_CREATE'  => date('d.m.Y H:i:s'),
    'DATE_EXECUTE' => date('d.m.Y H:i:s'),
    'STATUS'       => 'W',
    'TRACK_CLICK'  => 'Y',
    'TRACK_READ'   => 'Y',
]);

// Агент /bitrix/modules/subscribe/agent.php подхватит задание и отправит по батчам
```

---

## Gotchas

- **`Loader::includeModule('subscribe')`** обязателен. Без него `CSender`, `CSubscribe`, `CSubscription`, `CPosting`, `CSending` не определены.
- **`SITE_ID` обязателен для рубрик**: рубрики привязаны к сайту. При создании и выборке рубрик всегда передавай `SITE_ID`. Без него рубрика может создаться или не найтись для другого сайта в мультисайтовой установке.
- **Подтверждение подписки `CONFIRMED`**: если создаёшь подписку с `CONFIRMED = 'N'`, пользователь получит письмо-подтверждение. Без клика по ссылке рассылки ему не придут. При подписке из кода (например, при регистрации) ставь `CONFIRMED = 'Y'` явно.
- **`#UNSUB_LINK#`** генерируется только если в теле письма есть именно этот плейсхолдер. Без него ссылки отписки не будет — нарушение антиспам-законодательства.
- **`CSubscription::GetByEmail()`** возвращает `DB::Result`, не массив. Всегда вызывай `->Fetch()`.
- **Массовая отправка — только через агенты**: `CSending::SendMessage()` синхронна и блокирует выполнение. Для реальных рассылок используй `CSending::Add()` — агент отправит по батчам по ~100 писем за итерацию.
- **`CSubscription::GetRubricList()`** принимает `$subscriptionId`, не `$userId` и не email. Сначала получи объект подписки через `GetByEmail()` или `GetByID()`.
- **Дубликаты**: `CSubscribe::Subscribe()` проверяет дубликаты по email + SITE_ID и обновляет существующую подписку, не создаёт вторую. Безопасно вызывать повторно.
- **`CPosting::Add()` поле `RUBRIC_ID`** — массив ID рубрик, не одно число.
- **Статусы `CPosting`**: `N` = новая (не отправлялась), `P` = в процессе, `Y` = отправлена. Повторно отправить рассылку со статусом `Y` нельзя — создай новую через `CPosting::Add()`.
- **Кодировка и MIME**: Bitrix автоматически добавляет `Content-Type: text/html; charset=utf-8` и multipart если есть оба тела (BODY + BODY_ALT). Не добавляй эти заголовки вручную.
