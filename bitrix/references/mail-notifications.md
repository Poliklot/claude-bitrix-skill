# Почтовые события и уведомления

> Reference для Bitrix-скилла. Загружай когда задача связана с `CEvent`, `Bitrix\Main\Mail\Event`, шаблонами почтовых событий или перехватом отправки. Если задача уже про SMS-провайдера, ограничения, callback-и, sender management или REST-интеграцию, дополнительно загружай `messageservice.md`: это отдельный модульный слой, а не просто расширение mail-событий.
>
> Audit note: проверено по текущему core `main/lib/mail/event.php`, `main/classes/general/event.php`.

## Архитектура

В текущем core цепочка такая:

1. **Тип события** (`b_event_type`) — описание полей и типа доставки
2. **Шаблон сообщения** (`b_event_message`) — текст, тема, сайты
3. **Очередь** (`b_event`) — запись на отправку

`Bitrix\Main\Mail\Event::send()` пишет в очередь.  
`Bitrix\Main\Mail\Event::sendImmediate()` отправляет сразу.

Legacy-обёртка:

- `CEvent::Send()` -> возвращает ID записи в очереди или `false`
- `CEvent::SendImmediate()` -> возвращает строковый статус отправки

---

## Создание типа почтового события

```php
use Bitrix\Main\Mail\Internal\EventTypeTable;

$exists = EventTypeTable::getList([
    'filter' => [
        '=EVENT_NAME' => 'MY_MODULE_ORDER_NEW',
        '=LID' => 'ru',
    ],
])->fetch();

if (!$exists)
{
    CEventType::Add([
        'EVENT_NAME' => 'MY_MODULE_ORDER_NEW',
        'LID' => 'ru', // язык, не SITE_ID
        'NAME' => 'Новый заказ',
        'DESCRIPTION' => "Поля:\n#ORDER_ID#\n#EMAIL#\n#TOTAL#",
        'SORT' => 100,
        'EVENT_TYPE' => EventTypeTable::TYPE_EMAIL, // или TYPE_SMS
    ]);
}
```

---

## Создание шаблона письма

```php
$eventMessage = new CEventMessage();

$messageId = $eventMessage->Add([
    'EVENT_NAME' => 'MY_MODULE_ORDER_NEW',
    'LID' => ['s1'],
    'ACTIVE' => 'Y',
    'EMAIL_FROM' => '#EMAIL_FROM#',
    'EMAIL_TO' => '#EMAIL#',
    'SUBJECT' => 'Ваш заказ #ORDER_ID# принят',
    'MESSAGE' => "Здравствуйте!\nЗаказ №#ORDER_ID# на сумму #TOTAL# принят.",
    'BODY_TYPE' => 'text',
]);
```

---

## Отправка события

### Через очередь

```php
use Bitrix\Main\Mail\Event;

$result = Event::send([
    'EVENT_NAME' => 'MY_MODULE_ORDER_NEW',
    'LID' => SITE_ID,
    'FIELDS' => [
        'ORDER_ID' => $orderId,
        'EMAIL' => $email,
        'TOTAL' => $total,
    ],
]);

if (!$result->isSuccess())
{
    // ошибки записи в очередь
}
```

### Немедленно

```php
use Bitrix\Main\Mail\Event;

$sendResult = Event::sendImmediate([
    'EVENT_NAME' => 'MY_MODULE_ORDER_NEW',
    'LID' => SITE_ID,
    'FIELDS' => [
        'ORDER_ID' => $orderId,
        'EMAIL' => $email,
    ],
]);
```

Подтверждённые статусы `sendImmediate()`:

- `Event::SEND_RESULT_SUCCESS` = `'Y'`
- `Event::SEND_RESULT_ERROR` = `'F'`
- `Event::SEND_RESULT_PARTLY` = `'P'`
- `Event::SEND_RESULT_TEMPLATE_NOT_FOUND` = `'0'`
- `Event::SEND_RESULT_NONE` = `'N'`

### Legacy API

```php
$queueId = CEvent::Send(
    'MY_MODULE_ORDER_NEW',
    SITE_ID,
    [
        'ORDER_ID' => $orderId,
        'EMAIL' => $email,
    ]
);
```

`$queueId` здесь будет ID записи в очереди или `false`.

---

## Отправка с вложением

```php
use Bitrix\Main\Mail\Event;

Event::send([
    'EVENT_NAME' => 'MY_MODULE_ORDER_NEW',
    'LID' => SITE_ID,
    'FIELDS' => [
        'ORDER_ID' => $orderId,
        'EMAIL' => $email,
    ],
    'FILE' => [
        $fileId,
        '/path/to/file.pdf',
    ],
]);
```

---

## Прямое письмо без события

```php
use Bitrix\Main\Mail\Mail;

Mail::send([
    'TO' => 'user@example.com',
    'FROM' => 'noreply@example.com',
    'SUBJECT' => 'Тема письма',
    'BODY' => '<b>HTML-тело</b>',
    'CONTENT_TYPE' => 'html',
    'CHARSET' => 'UTF-8',
    'HEADER' => ['X-Custom-Header: value'],
]);
```

---

## `OnBeforeEventSend`

Регистрация:

```php
use Bitrix\Main\EventManager;

EventManager::getInstance()->addEventHandler(
    'main',
    'OnBeforeEventSend',
    [MyModule\EventHandler::class, 'onBeforeEventSend']
);
```

Обработчик:

```php
class EventHandler
{
    public static function onBeforeEventSend(
        array &$fields,
        array &$eventMessage,
        $context,
        array &$result
    )
    {
        $fields['EXTRA_INFO'] = '...';

        if (($fields['EMAIL'] ?? '') === 'blocked@example.com')
        {
            return false;
        }

        return null;
    }
}
```

Что подтверждено по текущему core:

- обработчик вызывается с `(&$arFields, &$eventMessage, $context, &$arResult)`
- если обработчик вернул `false`, текущий шаблон пропускается через `continue 2`
- `StopException` существует, но она ловится уже на этапе compile/send и не является единственным способом остановить отправку

---

## SMS-события

```php
use Bitrix\Main\Mail\Internal\EventTypeTable;

CEventType::Add([
    'EVENT_NAME' => 'MY_SMS_STATUS',
    'LID' => 'ru',
    'NAME' => 'SMS: смена статуса',
    'DESCRIPTION' => '#PHONE#, #ORDER_ID#',
    'EVENT_TYPE' => EventTypeTable::TYPE_SMS,
]);
```

Дальше создаётся обычный `CEventMessage`, а отправка идёт через тот же `Event::send(...)`.

Но это только слой event-type/event-message. Если вопрос про:

- выбор SMS-провайдера;
- sender ID и from list;
- лимиты и ограничения;
- status callback / result URL;
- REST-методы по сообщениям;

то реальная точка входа уже `messageservice`, а не только `main/mail`.

---

## Очередь и история

```php
use Bitrix\Main\Mail\Internal\EventTable;

$result = EventTable::getList([
    'filter' => ['=SUCCESS' => 'N'],
    'order' => ['DATE_INSERT' => 'ASC'],
    'limit' => 50,
]);

while ($row = $result->fetch())
{
    // $row['EVENT_NAME'], $row['DATE_INSERT'], $row['C_FIELDS']
}
```

---

## Gotchas

- В `CEventType::Add()` поле `LID` — это язык (`ru`, `en`), а в `CEventMessage::Add()` `LID` — это массив `SITE_ID`.
- `Event::send()` возвращает `AddResult`, а `CEvent::Send()` — ID очереди или `false`.
- `Event::sendImmediate()` возвращает строковый статус, а не bool.
- `OnBeforeEventSend` в текущем core реально может отменить шаблон через `return false`; не пиши в reference обратное.
- Если шаблон не найден, `sendImmediate()` вернёт `'0'`, а не `false`.
- `CEvent::Send()` только кладёт событие в очередь. Письмо уйдёт, когда отработает mail-event manager/агент.
