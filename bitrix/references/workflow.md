# Bitrix Бизнес-процессы (Bizproc / Workflow) — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с бизнес-процессами, CBPRuntime, кастомными активностями, запуском BP из кода или управлением статусами.
>
> Audit note: в текущем проверенном core модуль `bizproc` в `www/bitrix/modules` не найден. Этот файл сейчас отложен и не должен использоваться как основной маршрут, пока модуль не установлен и не подтверждён в ядре.

## Содержание
- Архитектура: CBPRuntime, IBPActivity, Document
- Запуск БП из кода
- CBPDocument::GetDocumentType()
- Создание кастомного действия (IBPActivity)
- Кастомное условие (IBPCondition)
- Статусы БП
- Получить запущенные БП для документа
- Завершить/остановить БП
- Автозапуск через событие инфоблока
- Gotchas

---

## Архитектура

**CBPRuntime** — движок выполнения бизнес-процессов. Управляет жизненным циклом: запуск, приостановка (при ожидании задачи), возобновление, завершение.

**IBPActivity** — интерфейс активности (действия). Каждый шаг процесса — это активность. Базовый класс — `CBPActivity`.

**IBPWorkflowDocument** — интерфейс документа. Каждая сущность, с которой работает BP, должна реализовывать этот интерфейс через класс-документ.

**$documentType** — тройка `[MODULE_ID, DOCUMENT_CLASS, DOCUMENT_ID_PREFIX]`:
```php
// Для элементов инфоблока
$documentType = ['iblock', 'Bitrix\\Iblock\\Integration\\Bizproc\\Document\\Element', 'iblock_5'];
//                MODULE_ID   DOCUMENT_CLASS                                            DOCUMENT_ID_PREFIX
// iblock_5 = инфоблок с ID=5
// DocumentId (конкретный элемент) = 'iblock_5|' . $elementId
```

---

## Запуск БП из кода

```php
use Bitrix\Main\Loader;

Loader::includeModule('bizproc');
Loader::includeModule('iblock');

// ID шаблона БП (b_bp_workflow_template.ID)
$templateId = 10;

// Тип документа — инфоблок 5
$documentType = [
    'iblock',
    'Bitrix\\Iblock\\Integration\\Bizproc\\Document\\Element',
    'iblock_5',
];

// ID документа — конкретный элемент
$documentId = 'iblock_5|' . $elementId;

// Параметры запуска (соответствуют параметрам шаблона)
$startParams = [
    'TargetUser'    => 'user_' . $userId,  // ID пользователя с префиксом
    'Comment'       => 'Запущено из кода',
    'ApproveStatus' => 'waiting',
];

$errors = [];
$runtime = CBPRuntime::GetRuntime(true); // true = инициализировать если не запущен
$runtime->StartWorkflow(
    $templateId,
    $documentType,
    $documentId,
    $startParams,
    $errors,
    []  // дополнительные параметры (eventData)
);

if (!empty($errors)) {
    foreach ($errors as $error) {
        // ['code' => ..., 'message' => '...', 'file' => '...']
        error_log('BP error: ' . $error['message']);
    }
}

// Получить все шаблоны для типа документа
$templates = CBPWorkflowTemplateLoader::GetList(
    ['ID' => 'ASC'],
    ['DOCUMENT_TYPE' => $documentType],
    false, false,
    ['ID', 'NAME', 'AUTO_EXECUTE']
);
while ($tmpl = $templates->Fetch()) {
    // AUTO_EXECUTE: 0=вручную, 1=при добавлении, 2=при редактировании, 3=оба
}
```

---

## CBPDocument::GetDocumentType()

```php
Loader::includeModule('bizproc');
Loader::includeModule('iblock');

// Получить documentType для конкретного элемента инфоблока
$iblockId = 5;
$elementId = 100;

$documentType = CBPDocument::GetDocumentType(
    'iblock',                                                           // module_id
    'Bitrix\\Iblock\\Integration\\Bizproc\\Document\\Element',         // documentClass
    'iblock_' . $iblockId . '|' . $elementId                          // documentId
);
// вернёт: ['iblock', 'Bitrix\\Iblock\\...', 'iblock_5']

// Получить список типов документов модуля
$types = CBPDocument::GetDocumentTypes('iblock');
// array типов для всех инфоблоков: [['MODULE_ID', 'CLASS', 'PREFIX', 'NAME'], ...]

// Получить данные документа через Document API
$docData = CBPDocument::GetDocument(
    'iblock',
    'Bitrix\\Iblock\\Integration\\Bizproc\\Document\\Element',
    'iblock_5|100'
);
// ассоциативный массив полей элемента с типами документа
```

---

## Создание кастомного действия (IBPActivity)

```php
// Файл: local/modules/vendor.mymodule/lib/activity/sendnotification.php
// Namespace: Vendor\Mymodule\Activity\SendNotification
// Регистрация: в install/index.php через CBPActivity::RegisterActivity()

namespace Vendor\Mymodule\Activity;

use CBPActivity;
use CBPActivityExecutionStatus;
use CBPActivityExecutionResult;
use CBPRuntime;

class SendNotification extends CBPActivity
{
    public function __construct(string $name)
    {
        parent::__construct($name);
        $this->arProperties = [
            'Title'   => '',       // обязательное свойство — название в конструкторе
            'UserId'  => null,     // ID получателя
            'Message' => '',       // текст уведомления
        ];
    }

    // Основной метод выполнения — вызывается движком
    public function Execute(): int
    {
        // Получить значение свойства (может содержать placeholder типа {=Variable:varName})
        $userId = (int)CBPRuntime::GetRuntime()->ResolveProperty(
            $this,
            $this->UserId
        );
        $message = $this->ResolveValue($this->Message);

        if ($userId > 0) {
            // Отправить внутреннее уведомление Bitrix
            \CIMNotify::Add([
                'FROM_USER_ID' => 0,
                'TO_USER_ID'   => $userId,
                'NOTIFY_TYPE'  => IM_NOTIFY_SYSTEM,
                'NOTIFY_MODULE'=> 'vendor.mymodule',
                'NOTIFY_EVENT' => 'bp_notification',
                'NOTIFY_MESSAGE' => htmlspecialchars($message),
            ]);
        }

        // Завершить активность — перейти к следующему шагу
        $this->SetStatus(CBPActivityExecutionStatus::Closed);
        return CBPActivityExecutionResult::Succeed;
    }

    // Описание свойств для UI конструктора БП
    public static function GetPropertiesDialogValues(
        string $documentType,
        string $activityName,
        array  &$workflowTemplate,
        array  &$workflowParameters,
        array  &$workflowVariables,
        array  $currentValues,
        array  &$errors
    ): bool {
        $errors = [];

        // Получить значения из формы конструктора
        $userId  = trim($currentValues['UserId'] ?? '');
        $message = trim($currentValues['Message'] ?? '');

        if (empty($userId)) {
            $errors[] = [
                'code'    => 0,
                'parameter' => 'UserId',
                'message' => 'Не указан получатель',
            ];
        }

        if (!empty($errors)) {
            return false;
        }

        // Сохранить значения в шаблон
        $props = ['UserId' => $userId, 'Message' => $message];
        static::SetActivityPropertiesInTemplate($activityName, $props, $workflowTemplate);

        return true;
    }

    // HTML диалог настройки в конструкторе
    public static function GetPropertiesDialog(
        string $documentType,
        string $activityName,
        array  $workflowTemplate,
        array  $workflowParameters,
        array  $workflowVariables,
        array  $currentValues = []
    ): string {
        $currentActivity = null;
        static::GetCurrentActivityPropertiesFromTemplate(
            $activityName, $workflowTemplate, $currentActivity
        );

        $userId  = $currentActivity['UserId']  ?? '';
        $message = $currentActivity['Message'] ?? '';

        return '<table>
            <tr>
                <td>Получатель:</td>
                <td><input type="text" name="UserId" value="' . htmlspecialchars($userId) . '"></td>
            </tr>
            <tr>
                <td>Сообщение:</td>
                <td><textarea name="Message">' . htmlspecialchars($message) . '</textarea></td>
            </tr>
        </table>';
    }
}
```

### Регистрация кастомного действия

```php
// В install/index.php модуля в методе InstallDB()
\CBPActivity::RegisterActivity(
    'SendNotification',                         // уникальное имя
    \Vendor\Mymodule\Activity\SendNotification::class,  // полное имя класса
    'vendor.mymodule'                           // module_id
);

// Удаление при деинсталляции
\CBPActivity::UnregisterActivity('SendNotification');
```

---

## Кастомное условие (IBPCondition)

```php
// Кастомное условие для ветвления в конструкторе БП
namespace Vendor\Mymodule\Condition;

class OrderStatusCondition
{
    // Метод, который вычисляет условие — возвращает bool
    public static function Evaluate(
        string $documentType,
        string $operatorType,
        mixed  $leftValue,
        mixed  $rightValue
    ): bool {
        // $leftValue — поле документа (например, значение STATUS)
        // $operatorType — тип сравнения ('equal', 'not_equal', etc.)
        // $rightValue — значение для сравнения из настроек условия

        return match ($operatorType) {
            'equal'     => $leftValue === $rightValue,
            'not_equal' => $leftValue !== $rightValue,
            'in'        => in_array($leftValue, (array)$rightValue),
            default     => false,
        };
    }
}

// Регистрация типа условия (в install/index.php):
\CBPCondition::RegisterType(
    'OrderStatus',
    \Vendor\Mymodule\Condition\OrderStatusCondition::class,
    'Evaluate',
    'vendor.mymodule'
);
```

---

## Статусы БП

```php
Loader::includeModule('bizproc');

// Константы CBPWorkflowStatus:
// CBPWorkflowStatus::Created    = 0  — создан, не запущен
// CBPWorkflowStatus::Running    = 1  — выполняется
// CBPWorkflowStatus::Suspended  = 2  — приостановлен (ждёт задачу/таймер)
// CBPWorkflowStatus::Terminated = 3  — принудительно остановлен
// CBPWorkflowStatus::Completed  = 4  — завершён успешно
// CBPWorkflowStatus::Faulted    = 5  — завершён с ошибкой

// Получить статус конкретного экземпляра БП
$workflowId = 'abc123-...'; // GUID из b_bp_workflow_state

$state = CBPStateService::GetWorkflowState($workflowId);
// ['WORKFLOW_ID' => '...', 'STATE' => 1, 'TITLE' => '...', 'MODIFIED' => '...']

$statusCode = (int)$state['STATE'];
if ($statusCode === CBPWorkflowStatus::Running) {
    // BP в процессе выполнения
}
```

---

## Получить запущенные БП для документа

```php
Loader::includeModule('bizproc');

$documentType = [
    'iblock',
    'Bitrix\\Iblock\\Integration\\Bizproc\\Document\\Element',
    'iblock_5',
];
$documentId = 'iblock_5|100';

// Получить все БП для документа
$workflows = CBPStateService::GetWorkflows($documentType, $documentId);
// array: [['WORKFLOW_ID' => '...', 'STATE' => 1, 'TEMPLATE_ID' => 10, ...], ...]

foreach ($workflows as $wf) {
    echo $wf['WORKFLOW_ID'] . ': ' . $wf['STATE'];
}

// Получить только активные (Running или Suspended)
$activeWorkflows = CBPStateService::GetWorkflows(
    $documentType,
    $documentId,
    [CBPWorkflowStatus::Running, CBPWorkflowStatus::Suspended]
);

// Получить задачи (Tasks) активных БП для пользователя
$tasks = CBPTaskService::GetUserTasks($userId, $documentType);
while ($task = $tasks->Fetch()) {
    // ['ID' => ..., 'WORKFLOW_ID' => '...', 'NAME' => '...', 'STATUS' => 0, ...]
}
```

---

## Завершить/остановить БП

```php
Loader::includeModule('bizproc');

$workflowId = 'abc123-...'; // GUID экземпляра

$runtime = CBPRuntime::GetRuntime(true);

// Принудительно завершить (Terminate) — статус → Terminated
$errors = [];
$runtime->TerminateWorkflow($workflowId, null, $errors);

if (!empty($errors)) {
    foreach ($errors as $err) {
        error_log('Terminate error: ' . $err['message']);
    }
}

// Завершить с кастомным сообщением (причина завершения)
$runtime->TerminateWorkflow($workflowId, 'Отменён администратором', $errors);

// Приостановить (Suspend) — только если BP поддерживает
// CBPRuntime не имеет метода Suspend напрямую — управляется через активность CBPDelayActivity
// Для принудительной остановки используй TerminateWorkflow

// Очистить завершённые БП (обслуживание)
CBPStateService::DeleteWorkflows(['STATE' => CBPWorkflowStatus::Completed]);
```

---

## Автозапуск через событие инфоблока

```php
// Шаблон БП с AUTO_EXECUTE = 1 запускается автоматически при добавлении элемента.
// Под капотом ядро вешает обработчик на OnAfterIBlockElementAdd.

// Ручная имитация автозапуска (если нужен контроль):
use Bitrix\Main\EventManager;

EventManager::getInstance()->addEventHandler(
    'iblock',
    'OnAfterIBlockElementAdd',
    function(array &$fields) {
        if ((int)$fields['IBLOCK_ID'] !== 5) {
            return;
        }

        if (!\Bitrix\Main\Loader::includeModule('bizproc')) {
            return;
        }

        $documentType = [
            'iblock',
            'Bitrix\\Iblock\\Integration\\Bizproc\\Document\\Element',
            'iblock_5',
        ];
        $documentId = 'iblock_5|' . (int)$fields['ID'];

        // Запустить все шаблоны с AUTO_EXECUTE=1 для этого инфоблока
        CBPDocument::AutoStartWorkflows(
            $documentType,
            $documentId,
            CBPDocumentEventType::Create, // Create / Edit
            []
        );
    }
);
```

---

## Gotchas

- **`Loader::includeModule('bizproc')`** обязателен. Без него `CBPRuntime`, `CBPStateService`, `CBPDocument` и все активности не определены.
- **`$documentType` — тройка, не строка**: `['iblock', 'Bitrix\\Iblock\\...', 'iblock_5']`. Неправильный формат — тихая ошибка при запуске без исключения.
- **`$documentId` — строка `'iblock_5|100'`**, не число. Первая часть = `$documentType[2]`, вторая = ID элемента через `|`.
- **Документ должен реализовывать `IBPWorkflowDocument`**: для стандартных инфоблоков это `Bitrix\Iblock\Integration\Bizproc\Document\Element`. Для кастомных сущностей нужно реализовывать интерфейс самостоятельно.
- **`CBPRuntime::GetRuntime(true)`** — вызывай с `true` (инициализация). Без аргумента или с `false` вернёт runtime который может быть не готов, и `StartWorkflow` упадёт.
- **Ошибки не исключения**: `StartWorkflow()` и `TerminateWorkflow()` пишут ошибки в переданный по ссылке `$errors[]`. Всегда проверяй этот массив.
- **Шаблон БП привязан к типу документа**: шаблон для `iblock_5` не будет виден/работать для `iblock_6`. Это намеренное поведение — `DOCUMENT_TYPE[2]` должен совпадать.
- **`CBPActivity::RegisterActivity()`** нужно вызывать при каждой установке модуля — данные хранятся в `b_bp_activity`. При деинсталляции — `UnregisterActivity()`.
- **Задачи BP (`CBPTaskService`)** не удаляются автоматически при `TerminateWorkflow` — их нужно закрывать отдельно или они остаются "висящими" в `b_bp_task`.
- **`AUTO_EXECUTE`** в шаблоне: `0` = вручную, `1` = при добавлении, `2` = при редактировании, `3` = оба. Значение `3` = бинарный OR: `1|2`.
- **Производительность**: не запускай BP синхронно в массовых операциях — каждый `StartWorkflow()` делает несколько запросов к БД. Используй очереди или агенты.
