# Сообщения, SMS-провайдеры и ограничения (модуль messageservice)

> Audit note: ниже сверено с текущим `www/bitrix/modules/messageservice` версии `24.900.100`. Подтверждены `\Bitrix\MessageService\Message`, `Sender\SmsManager`, абстракции `Sender\Base` и `BaseConfigurable`, `Restriction\RestrictionManager`, `RestService`, controller `\Bitrix\MessageService\Controller\Sender`, internal ORM-таблицы сообщений и ограничений, стандартные компоненты `bitrix:messageservice.config.sender.sms` и `bitrix:messageservice.config.sender.limits`, а также callback-tools `tools/callback_*.php`.

## Для чего использовать

`messageservice` в этом core нужен для:

- работы с SMS и внешними message providers
- отправки сообщений через конкретного sender-а
- ограничений и лимитов отправки
- REST-интеграции своих провайдеров
- callback/result URL от провайдера

Если задача звучит как:

- “какой SMS-провайдер сейчас активен”
- “почему SMS не отправляется”
- “как добавить своего sender-а”
- “как обновить статус сообщения по callback”

то это отдельный рабочий контур, а не просто кусок `mail-notifications.md`.

---

## SmsManager

Подтверждены ключевые методы:

- `getSenders`
- `getSenderSelectList`
- `getSenderInfoList`
- `getSenderById`
- `getDefaultSender`
- `getUsableSender`
- `canUse`
- `getManageUrl`
- `getRegisteredSenderList`

```php
use Bitrix\Main\Loader;
use Bitrix\MessageService\Sender\SmsManager;

Loader::includeModule('messageservice');

$senderInfo = SmsManager::getSenderInfoList();
$sender = SmsManager::getUsableSender();
```

Практическое правило:

- не выбирай sender вручную по памяти, если `SmsManager` уже умеет найти usable/default provider
- сначала смотри `canUse()`, потом `getFromList()` и только потом идёшь в реальную отправку

---

## Message и отправка

Подтверждены:

- `Message::loadById`
- `Message::loadByExternalId`
- `Message::createFromFields`
- `Message::send`
- `Message::sendDirectly`
- `Message::checkFields`

```php
use Bitrix\Main\Loader;
use Bitrix\MessageService\Message;
use Bitrix\MessageService\MessageType;
use Bitrix\MessageService\Sender\SmsManager;

Loader::includeModule('messageservice');

$sender = SmsManager::getUsableSender();

$message = Message::createFromFields([
    'TYPE' => MessageType::SMS,
    'MESSAGE_FROM' => $sender ? $sender->getDefaultFrom() : '',
    'MESSAGE_TO' => '+79990000000',
    'MESSAGE_BODY' => 'Bitrix test',
], $sender);

$result = $message->sendDirectly();
```

Отличие по смыслу:

- `send()` — сохраняет сообщение в модульный storage
- `sendDirectly()` — сразу отправляет через sender и возвращает `Sender\Result\SendMessage`

---

## Sender Base / BaseConfigurable

Подтверждено, что provider-контракт строится вокруг:

- `Sender\Base`
- `Sender\BaseConfigurable`

У `Base` подтверждены обязательные методы:

- `getId`
- `getName`
- `getShortName`
- `canUse`
- `getFromList`
- `sendMessage`

Это важно, если задача про свой кастомный sender или диагностику конкретного провайдера.

В текущем core подтверждены провайдеры из `lib/sender/sms/*`, включая:

- `SmsRu`
- `Twilio`
- `Twilio2`
- `SmsAssistentBy`
- `SmsLineBy`
- `SmsEdnaru`
- `Ednaru`
- `EdnaruImHpx`
- `ISmsCenter`
- `Rest`
- `Dummy`
- `DummyHttp`

---

## Ограничения и лимиты

Подтверждены:

- `Restriction\RestrictionManager::canUse`
- `Restriction\RestrictionManager::enableRestrictions`
- `Restriction\RestrictionManager::disableRestrictions`
- `Restriction\RestrictionManager::isCanSendMessage`

А также отдельные ограничения:

- `SmsPerUser`
- `SmsPerPhone`
- `PhonePerUser`
- `UserPerPhone`
- `IpPerUser`
- `IpPerPhone`
- `SmsPerIp`

Практически это значит:

- если сообщение “иногда не уходит”, проверь не только провайдера, но и restriction layer
- если пользователь просит “включить лимиты на отправку”, сначала смотри `RestrictionManager` и `Sender\Limitation`

---

## REST и callbacks

Подтверждён `\Bitrix\MessageService\RestService` со scope `messageservice` и методами:

- `messageservice.sender.add`
- `messageservice.sender.update`
- `messageservice.sender.delete`
- `messageservice.sender.list`
- `messageservice.message.status.update`
- `messageservice.message.status.get`

Подтверждён controller:

- `\Bitrix\MessageService\Controller\Sender::getTemplatesAction`

И подтверждены callback-интеграции в `tools/`:

- `callback_smsru.php`
- `callback_twilio.php`
- `callback_ismscenter.php`
- и другие `callback_*`

Если нужна интеграция со своим провайдером:

1. сначала проверь, решается ли это через REST sender-контракт
2. потом смотри callback path в `tools/`
3. только после этого пиши свой транспортный код

---

## Стандартные компоненты и admin UI

Подтверждены:

- `bitrix:messageservice.config.sender.sms`
- `bitrix:messageservice.config.sender.limits`

Первый работает с configurable sender-ом и его template/config page, второй — с лимитами по sender/from.

Это хороший маршрут для задач:

- “покажи настройки sender-а”
- “редактируй лимиты отправки в админке”

---

## Gotchas

- `mail` и `messageservice` — разные контуры. Email-шаблон не делает модуль SMS автоматически “правильным”.
- Прежде чем отправлять сообщение, проверь три вещи: `sender->canUse()`, корректный `from`, restriction/limitation layer.
- Для callback/result URL не выдумывай свои endpoint-ы, если у модуля уже есть штатные `tools/callback_*`.
- Если задача про шаблоны провайдера, смотри `Controller\Sender::getTemplatesAction` и `isTemplatesBased()`, а не только UI.
