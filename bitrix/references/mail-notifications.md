# Почтовые события и уведомления

## Архитектура

Bitrix использует трёхуровневую систему:
1. **Тип события** (`b_event_type`) — описание: имя события, список `#ПОЛЕЙ#`
2. **Шаблон письма** (`b_event_message`) — тема, текст, кому/от кого, привязка к типу
3. **Очередь отправки** (`b_event`) — запись-задание, обрабатывается агентом `CEvent::CheckEvents()`

`CEvent::Send` → пишет в очередь → агент отправляет по шаблону.
`CEvent::SendImmediate` → отправляет немедленно, без очереди.

---

## Создание типа почтового события

Регистрируется один раз (обычно при установке модуля в `InstallDB`):

```php
use Bitrix\Main\Mail\Internal\EventTypeTable;

// Проверить, не существует ли уже
$exists = EventTypeTable::getList([
    'filter' => ['=EVENT_NAME' => 'MY_MODULE_ORDER_NEW', '=LID' => 'ru'],
])->fetch();

if (!$exists) {
    CEventType::Add([
        'EVENT_NAME'  => 'MY_MODULE_ORDER_NEW',  // уникальный код события
        'LID'         => 'ru',                   // язык (не SITE_ID!)
        'NAME'        => 'Новый заказ',
        'DESCRIPTION' => "Поля:\n#ORDER_ID# — номер заказа\n#USER_NAME# — имя покупателя\n#TOTAL# — сумма\n#EMAIL# — email",
        'SORT'        => 100,
        'EVENT_TYPE'  => EventTypeTable::TYPE_EMAIL, // или TYPE_SMS
    ]);
}
```

> **Gotcha:** `LID` — это код языка (`ru`, `en`), а не `SITE_ID` (`s1`). Одно событие может иметь несколько записей по языкам.

---

## Создание шаблона письма

```php
$obEventMessage = new CEventMessage();
$messageId = $obEventMessage->Add([
    'EVENT_NAME' => 'MY_MODULE_ORDER_NEW',
    'LID'        => ['s1'],          // массив SITE_ID
    'ACTIVE'     => 'Y',
    'EMAIL_FROM' => '#EMAIL_FROM#',  // макрос настроек сайта
    'EMAIL_TO'   => '#EMAIL#',       // макрос из полей события
    'SUBJECT'    => 'Ваш заказ #ORDER_ID# принят',
    'MESSAGE'    => "Здравствуйте, #USER_NAME#!\n\nВаш заказ №#ORDER_ID# на сумму #TOTAL# руб. принят.\n\n#SITE_NAME#",
    'BODY_TYPE'  => 'text',          // 'text' или 'html'
    'BCC'        => '',
    'REPLY_TO'   => '',
]);

if (!$messageId) {
    // $obEventMessage->LAST_ERROR
}
```

---

## Отправка события из кода

### Через очередь (рекомендуется — не блокирует запрос)

```php
use Bitrix\Main\Mail\Event;

$result = Event::send([
    'EVENT_NAME'  => 'MY_MODULE_ORDER_NEW',
    'LID'         => SITE_ID,          // текущий сайт
    'FIELDS'      => [
        'ORDER_ID'  => $orderId,
        'USER_NAME' => $userName,
        'TOTAL'     => number_format($total, 2, '.', ' '),
        'EMAIL'     => $userEmail,
    ],
]);

if (!$result->isSuccess()) {
    // обработка ошибки
}
```

### Немедленная отправка (без очереди, блокирует запрос)

```php
$sendResult = Event::sendImmediate([
    'EVENT_NAME' => 'MY_MODULE_ORDER_NEW',
    'LID'        => SITE_ID,
    'FIELDS'     => [
        'ORDER_ID' => $orderId,
        'EMAIL'    => $userEmail,
    ],
]);

// Константы результата:
// Event::SEND_RESULT_SUCCESS ('Y')           — все шаблоны отправлены
// Event::SEND_RESULT_ERROR ('F')             — ошибка
// Event::SEND_RESULT_PARTLY ('P')            — отправлено частично
// Event::SEND_RESULT_TEMPLATE_NOT_FOUND ('0')— нет активных шаблонов
// Event::SEND_RESULT_NONE ('N')              — пропущено (OnBeforeEventSend вернул false)
```

### Legacy-обёртка (встречается в старом коде)

```php
// Эквивалентно Event::send(), но устаревший синтаксис
CEvent::Send(
    'MY_MODULE_ORDER_NEW',    // EVENT_NAME
    SITE_ID,                  // LID
    ['ORDER_ID' => $id, 'EMAIL' => $email]  // поля
);
```

---

## Отправка с вложением

```php
use Bitrix\Main\Mail\Event;

Event::send([
    'EVENT_NAME' => 'MY_MODULE_ORDER_NEW',
    'LID'        => SITE_ID,
    'FIELDS'     => ['ORDER_ID' => $orderId, 'EMAIL' => $email],
    'FILE'       => [
        $fileId,                // ID файла из таблицы b_file
        '/path/to/file.pdf',    // путь к файлу на сервере
    ],
]);
```

---

## Отправка прямого письма (без события и шаблона)

```php
use Bitrix\Main\Mail\Mail;

Mail::send([
    'TO'           => 'user@example.com',
    'FROM'         => 'noreply@example.com',
    'SUBJECT'      => 'Тема письма',
    'BODY'         => '<b>HTML-тело</b>',
    'CONTENT_TYPE' => 'html',   // 'html' или 'text'
    'CHARSET'      => 'UTF-8',
    'HEADER'       => ['X-Custom-Header: value'],
]);
```

---

## Перехват события перед отправкой

```php
// В include.php модуля
use Bitrix\Main\EventManager;

EventManager::getInstance()->addEventHandler('main', 'OnBeforeEventSend', [
    MyModule\EventHandler::class, 'onBeforeEventSend'
]);
```

```php
// В классе-обработчике
class EventHandler
{
    public static function onBeforeEventSend(
        array &$fields,        // поля #ШАБЛОНА#
        array &$eventMessage,  // данные шаблона (EMAIL_TO, SUBJECT и т.д.)
        $context,
        array &$result
    ): void
    {
        // Добавить/изменить поле
        $fields['EXTRA_INFO'] = '...';

        // Отменить отправку (return false не работает — нужно throw или изменить $result)
        // Для отмены используй StopException:
        // throw new \Bitrix\Main\Mail\StopException();
    }
}
```

---

## SMS-уведомления

Bitrix поддерживает SMS через провайдеров (Smsmanager, SMSc, SMSPILOT и т.д.).
Тип события `EventTypeTable::TYPE_SMS` создаёт SMS-событие.

```php
use Bitrix\Main\Mail\Internal\EventTypeTable;

// Создать тип SMS-события
CEventType::Add([
    'EVENT_NAME'  => 'MY_SMS_ORDER_STATUS',
    'LID'         => 'ru',
    'NAME'        => 'SMS: смена статуса заказа',
    'DESCRIPTION' => '#PHONE# — номер телефона, #ORDER_ID# — заказ',
    'EVENT_TYPE'  => EventTypeTable::TYPE_SMS,
]);

// Шаблон SMS (поле MESSAGE = текст SMS)
$obEventMessage = new CEventMessage();
$obEventMessage->Add([
    'EVENT_NAME' => 'MY_SMS_ORDER_STATUS',
    'LID'        => ['s1'],
    'ACTIVE'     => 'Y',
    'EMAIL_FROM' => '',
    'EMAIL_TO'   => '#PHONE#',
    'SUBJECT'    => '',
    'MESSAGE'    => 'Заказ №#ORDER_ID# готов к выдаче.',
    'BODY_TYPE'  => 'text',
]);

// Отправка SMS — через ту же Event::send
use Bitrix\Main\Mail\Event;
Event::send([
    'EVENT_NAME' => 'MY_SMS_ORDER_STATUS',
    'LID'        => SITE_ID,
    'FIELDS'     => ['PHONE' => '+79991234567', 'ORDER_ID' => 42],
]);
```

> Провайдер SMS выбирается в настройках сайта: Настройки → Настройки продукта → SMS. Bitrix автоматически использует нужный адаптер.

---

## D7 ORM: чтение очереди и истории

```php
use Bitrix\Main\Mail\Internal\EventTable;

// Непрочитанные события в очереди
$result = EventTable::getList([
    'filter' => ['=SUCCESS' => 'N'],
    'order'  => ['DATE_INSERT' => 'ASC'],
    'limit'  => 50,
]);
while ($row = $result->fetch()) {
    // $row['EVENT_NAME'], $row['C_FIELDS'] (сериализованный массив), $row['DATE_INSERT']
}
```

---

## Удаление типа события при деинсталляции модуля

```php
// В UninstallDB
use Bitrix\Main\Mail\Internal\EventTypeTable;

$res = EventTypeTable::getList([
    'filter' => ['=EVENT_NAME' => 'MY_MODULE_ORDER_NEW'],
]);
while ($row = $res->fetch()) {
    EventTypeTable::delete($row['ID']);
}
```

---

## Gotchas

- `LID` в `CEventType::Add` — **язык** (`ru`/`en`), в `CEventMessage::Add` — **SITE_ID** (`s1`)
- Если шаблон не найден — `Event::sendImmediate` вернёт `'0'` (SEND_RESULT_TEMPLATE_NOT_FOUND), не false
- `CEvent::Send` пишет в очередь — письмо уйдёт только когда агент `CEvent::CheckEvents()` отработает (каждые 5 минут по умолчанию)
- В SUBJECT/MESSAGE можно использовать PHP-код если в шаблоне установить `MESSAGE_PHP = 'Y'`
- `#EMAIL_FROM#` — подставляет значение настройки "E-mail сайта" из `COption::GetOptionString('main', 'email_from')`
