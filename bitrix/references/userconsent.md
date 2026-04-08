# Bitrix UserConsent — core-first справочник

> Reference для Bitrix-скилла. Загружай, когда задача связана с соглашениями пользователя, записью согласий, `Bitrix\Main\UserConsent\Agreement`, `Consent`, `AgreementLink`, `DataProvider` или REST-методами userconsent.

## Что подтверждено в текущем core

`UserConsent` лежит внутри `main`:

- `Bitrix\Main\UserConsent\Agreement`
- `Bitrix\Main\UserConsent\Consent`
- `Bitrix\Main\UserConsent\DataProvider`
- `Bitrix\Main\UserConsent\Policy`
- `Bitrix\Main\UserConsent\AgreementLink`
- `Bitrix\Main\UserConsent\Rest`
- `Bitrix\Main\UserConsent\Internals\AgreementTable`
- `Bitrix\Main\UserConsent\Internals\ConsentTable`

---

## Agreement

```php
use Bitrix\Main\UserConsent\Agreement;

$agreement = new Agreement($agreementId);

if ($agreement->isExist() && $agreement->isActive()) {
    $data = $agreement->getData();
    $text = $agreement->getText();
    $html = $agreement->getHtml();
    $label = $agreement->getLabel();
    $labelText = $agreement->getLabelText();
    $url = $agreement->getUrl();
}
```

Подтверждённые методы:

- `isExist()`
- `isActive()`
- `getData()`
- `getText()`
- `getHtml()`
- `getLabelText()`
- `getLabel()`
- `getUrl()`

### Что важно

- `getUrl()` возвращает URL только если у соглашения `USE_URL = 'Y'` и URL реально задан.
- `getLabel()` работает с `%...%`-разметкой текста ссылки.
- В текущем core у `Agreement` нет метода `getCheckBoxHtml()`.

---

## `Consent::addByContext()`

```php
use Bitrix\Main\UserConsent\Consent;

$consentId = Consent::addByContext(
    $agreementId,
    $originatorId,
    $originId,
    [
        'USER_ID' => $USER->GetID(),
        'IP' => '203.0.113.10',
        'URL' => 'https://example.test/form/',
        'ITEMS' => [
            ['VALUE' => 'analytics'],
            ['VALUE' => 'marketing'],
        ],
    ]
);
```

Что реально делает метод:

- проверяет, что соглашение существует и активно;
- берёт `USER_ID` из params или из глобального `$USER`;
- берёт `IP` из params или из `Context::getCurrent()->getRequest()->getRemoteAddress()`;
- берёт `URL` из params или собирает из текущего request;
- режет URL до 4000 символов;
- пишет запись в `Internals\ConsentTable`;
- если передан `ITEMS`, добавляет их в `Internals\UserConsentItemTable`.

`addByContext()` возвращает `int|null`.

---

## Проверка существующего согласия

```php
use Bitrix\Main\UserConsent\Internals\ConsentTable;

$row = ConsentTable::getList([
    'filter' => [
        '=AGREEMENT_ID' => $agreementId,
        '=USER_ID' => $userId,
    ],
    'limit' => 1,
])->fetch();

$hasConsent = $row !== false;
```

В текущем core `addByContext()` сам дубликаты не отсекает.

---

## `AgreementLink`

`AgreementLink` нужен, когда соглашение надо безопасно отдать наружу с подписанными replace-параметрами.

```php
use Bitrix\Main\UserConsent\AgreementLink;

$uri = AgreementLink::getUri($agreementId, ['COMPANY' => 'Acme'], '/consent/');
$agreement = AgreementLink::getAgreementFromUriParameters($_GET);
$errors = AgreementLink::getErrors();
```

Под капотом используется `Bitrix\Main\Security\Sign\Signer`.

---

## Два разных события provider-слоя

В текущем core здесь легко ошибиться, потому что событий два и они про разное.

### 1. `OnUserConsentProviderList`

Источник: `Consent::EVENT_NAME_LIST`.

Это список origin/provider-источников для `Consent::getOriginData()` и `Consent::getItems()`.

Форма элемента:

```php
use Bitrix\Main\EventResult;

return new EventResult(EventResult::SUCCESS, [
    [
        'CODE' => 'MY_PROVIDER',
        'NAME' => 'My Provider',
        'DATA' => function ($id) {
            return [
                'NAME' => 'Object name',
                'URL' => '/object/' . (int)$id . '/',
            ];
        },
        'ITEMS' => function ($value) {
            return (string)$value;
        },
    ],
], 'my.module');
```

Минимально обязательны:

- `CODE`
- `NAME`
- `DATA` callable

### 2. `OnUserConsentDataProviderList`

Источник: `DataProvider::EVENT_NAME_LIST`.

Это список data-provider'ов для подстановок в текст соглашения.

Форма элемента:

```php
use Bitrix\Main\EventResult;

return new EventResult(EventResult::SUCCESS, [
    [
        'CODE' => 'MY_DATA',
        'NAME' => 'My data provider',
        'DATA' => function () {
            return [
                'COMPANY_NAME' => 'Acme',
                'EMAIL' => 'legal@example.test',
            ];
        },
        'EDIT_URL' => '/bitrix/admin/my_module_settings.php',
    ],
], 'my.module');
```

Минимально обязательны:

- `CODE`
- `NAME`
- `DATA` как `array` или `callable`

---

## REST в текущем core

`main` сам публикует userconsent REST-методы через `Bitrix\Main\Rest\Handlers`:

- `userconsent.consent.add`
- `userconsent.agreement.list`
- `userconsent.agreement.text`

Реализация лежит в `Bitrix\Main\UserConsent\Rest`.

---

## Gotchas

- Не ищи `Loader::includeModule('userconsent')`: отдельного модуля нет, это часть `main`.
- Не используй `Agreement::getCheckBoxHtml()` — такого метода в текущем core нет.
- `OnUserConsentProviderList` и `OnUserConsentDataProviderList` нельзя смешивать: первый про origin/items, второй про подстановочные данные для текста.
- `Agreement::getUrl()` может вернуть `null`; всегда проверяй это перед рендером ссылки.
- Если нужно одноразовое согласие, сначала проверь `ConsentTable`, потом вызывай `addByContext()`.
