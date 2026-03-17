# Bitrix UserConsent (GDPR) — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с согласием пользователя (GDPR): `Bitrix\Main\UserConsent\Consent::addByContext`, `Agreement`, `AgreementLink`, `DataProvider`, `Policy`, событием `OnUserConsentProviderList`.

## Содержание
- Архитектура UserConsent
- Agreement: настройка соглашений
- Consent::addByContext(): запись согласия
- DataProvider: источники данных
- Policy: политики обработки
- Событие OnUserConsentProviderList
- Интеграция с формами
- Gotchas

---

## Архитектура

Модуль `UserConsent` реализует хранение фактов согласия пользователей с политиками конфиденциальности и обработки данных.

**Ключевые классы:**
- `Agreement` — соглашение (политика, которую пользователь принимает)
- `Consent` — факт согласия (кто, когда, с каким соглашением, по какому IP/URL)
- `DataProvider` — поставщик контекстных данных
- `Policy` — политика обработки данных
- `AgreementLink` — связь соглашения с точкой входа (форма, страница)

**Соглашение создаётся в админке**: `Настройки → Согласия пользователей → Соглашения`.

---

## Agreement: работа с соглашениями

```php
use Bitrix\Main\UserConsent\Agreement;

$agreementId = 1; // ID соглашения из админки

$agreement = new Agreement($agreementId);

// Проверки
$agreement->isExist();    // bool — существует ли соглашение
$agreement->isActive();   // bool — активно ли соглашение

// Данные соглашения
$data = $agreement->getData();
// ['ID' => 1, 'ACTIVE' => 'Y', 'NAME' => 'Политика конф.', 'TEXT' => '...']

// Получить текст для отображения
$label = $agreement->getLabel(); // строка для чекбокса
$url   = $agreement->getUrl();   // ссылка на полный текст

// Рендер чекбокса согласия
$html = $agreement->getCheckBoxHtml('agreement_' . $agreementId);
```

---

## Consent::addByContext(): запись согласия

Основной метод для фиксации согласия. Автоматически захватывает контекст запроса.

```php
use Bitrix\Main\UserConsent\Consent;

/**
 * @param int $agreementId  ID соглашения
 * @param int|null $originatorId  ID источника (например ID формы)
 * @param int|null $originId      ID объекта-источника (ID лида, сделки и т.д.)
 * @param array $params  Дополнительные параметры
 * @return int|null  ID созданной записи или null при ошибке
 */
$consentId = Consent::addByContext(
    $agreementId,    // int: ID соглашения
    null,            // int|null: originatorId
    null,            // int|null: originId
    [
        // Опциональные параметры (берутся из контекста если не переданы)
        'USER_ID' => $USER->GetID(), // ID пользователя (автоматически из $USER если не задан)
        'IP'      => '',             // IP-адрес (автоматически из Request)
        'URL'     => '',             // URL страницы (автоматически из Request)
    ]
);

if ($consentId !== null) {
    // Согласие успешно записано
}
```

**Что захватывается автоматически:**
- `USER_ID` — из глобального `$USER->GetID()` если не передан
- `IP` — из `Context::getCurrent()->getRequest()->getRemoteAddress()`
- `URL` — полный URL текущей страницы (https?://host/path?query), обрезается до 4000 символов
- `USER_AGENT` — из заголовка HTTP-запроса (в некоторых версиях)

---

## Полный пример: форма с согласием

```php
use Bitrix\Main\UserConsent\Consent;
use Bitrix\Main\UserConsent\Agreement;

// В компоненте формы:
$agreementId = (int)\Bitrix\Main\Config\Option::get('my.module', 'agreement_id', 0);

// Проверить активность соглашения
if ($agreementId > 0) {
    $agreement = new Agreement($agreementId);
    if ($agreement->isExist() && $agreement->isActive()) {
        $this->arResult['AGREEMENT'] = [
            'ID'    => $agreementId,
            'LABEL' => $agreement->getLabel(),
            'URL'   => $agreement->getUrl(),
            'HTML'  => $agreement->getCheckBoxHtml('consent_check'),
        ];
    }
}

// При обработке формы (POST):
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $consentChecked = !empty($_POST['consent_check']);

    if (!$consentChecked) {
        // Пользователь не принял соглашение
        $this->arResult['ERRORS'][] = 'Необходимо принять соглашение';
        return;
    }

    // Записать согласие
    Consent::addByContext(
        $agreementId,
        10,                     // originatorId: ID типа формы
        $savedFormResultId,     // originId: ID результата формы
    );
}
```

---

## DataProvider: поставщики данных

`DataProvider` — класс, предоставляющий данные о субъекте для политики обработки.

```php
use Bitrix\Main\UserConsent\DataProvider;

// Встроенные провайдеры:
// - USER: данные авторизованного пользователя
// - CRM_LEAD: данные лида (требует модуль crm)

// Получить список доступных провайдеров
$providers = DataProvider::getList(); // array

// DataProvider используется в Agreement для описания
// что именно обрабатывается: имя, email, телефон, IP и т.д.
```

---

## Событие OnUserConsentProviderList

Позволяет добавить собственные провайдеры данных.

```php
// В /local/php_interface/init.php или в install/index.php модуля:
use Bitrix\Main\EventManager;

EventManager::getInstance()->addEventHandler(
    'main',
    'OnUserConsentProviderList',
    ['\MyVendor\MyModule\UserConsent\MyDataProvider', 'onGetList']
);

// Класс провайдера:
namespace MyVendor\MyModule\UserConsent;

use Bitrix\Main\EventResult;

class MyDataProvider
{
    public static function onGetList(\Bitrix\Main\Event $event): EventResult
    {
        return new EventResult(EventResult::SUCCESS, [
            'MY_MODULE' => [
                'NAME'       => 'Данные модуля My Module',
                'CLASS_NAME' => static::class,
                'FIELDS'     => [
                    'NAME'  => ['NAME' => 'Имя'],
                    'EMAIL' => ['NAME' => 'Email'],
                    'PHONE' => ['NAME' => 'Телефон'],
                ],
            ],
        ]);
    }

    // Метод получения данных субъекта по ID
    public static function getSubjectData(int $subjectId): array
    {
        $row = \MyVendor\MyModule\ClientTable::getById($subjectId)->fetch();
        return $row ?: [];
    }
}
```

---

## Таблица фактов согласия (Internals\ConsentTable)

```php
use Bitrix\Main\UserConsent\Internals\ConsentTable;

// Получить историю согласий пользователя
$history = ConsentTable::getList([
    'filter' => ['=USER_ID' => $userId],
    'select' => ['ID', 'AGREEMENT_ID', 'DATE_INSERT', 'IP', 'URL'],
    'order'  => ['DATE_INSERT' => 'DESC'],
])->fetchAll();

// Проверить наличие согласия
$hasConsent = ConsentTable::getList([
    'filter' => [
        '=USER_ID'      => $userId,
        '=AGREEMENT_ID' => $agreementId,
    ],
    'limit' => 1,
])->fetch() !== false;
```

---

## Gotchas

- **`addByContext()` не проверяет дубли**: каждый вызов создаёт новую запись. Если нужно однократное согласие — проверяй существующее через `ConsentTable::getList()` перед вызовом.
- **Соглашение должно быть активным**: `addByContext()` проверяет `isExist()` и `isActive()`. Если соглашение неактивно — метод вернёт `null`.
- **URL обрезается до 4000 символов**: очень длинные URL (GET-параметры) автоматически обрезаются.
- **`originatorId` и `originId` — произвольные ID**: определяй их семантику сам. Обычно: `originatorId` = тип сущности (ID формы, ID типа запроса), `originId` = ID конкретного объекта (ID результата формы, ID заявки).
- **Соглашение создаётся только в админке**: нет API для создания соглашения программно в стандартном модуле. Используй ID из настроек модуля (`Config\Option`).
- **Модуль main включён всегда**: `UserConsent` входит в ядро, `Loader::includeModule()` не требуется.
