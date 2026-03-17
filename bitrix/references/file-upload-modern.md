# Bitrix Modern File Upload — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с современной загрузкой файлов через `Bitrix\Main\FileUploader\FieldFileUploaderController`, `Bitrix\UI\FileUploader\UploaderController`, `UploadedFilesRegistry`, `UploaderFileSigner`.

## Содержание
- Архитектура: FileUploader D7 vs CFile
- FieldFileUploaderController: параметры и использование
- Регистрация контроллера
- Frontend: bitrix:ui.file.input
- Подтверждение загруженных файлов
- Работа с UploaderFileSigner (подписанные ID)
- Gotchas

---

## Архитектура

`FieldFileUploaderController` — D7-замена ручной загрузки через `CFile::SaveFile()` для UF-полей (пользовательских полей).

**Поток загрузки:**
1. Frontend компонент `bitrix:ui.file.input` запрашивает URL для загрузки
2. `FieldFileUploaderController` проверяет авторизацию и возвращает `signedFileId`
3. Файл загружается на сервер, временно хранится в `UploadedFilesRegistry`
4. При сохранении формы `signedFileId` подтверждается и конвертируется в `FILE_ID`

**Зависимости:**
- `Bitrix\Main\FileUploader\FieldFileUploaderController` — контроллер для UF-полей
- `Bitrix\UI\FileUploader\UploaderController` — базовый абстрактный класс (в модуле `ui`)
- `Bitrix\UI\FileUploader\Configuration` — настройки загрузчика
- `Bitrix\Main\UserField\File\UploadedFilesRegistry` — реестр временных файлов
- `Bitrix\Main\UserField\File\UploaderFileSigner` — подписывает/верифицирует fileId

---

## Регистрация контроллера (AJAX endpoint)

Контроллер регистрируется как обработчик в `Router` или через `Engine\Controller`.

```php
namespace MyVendor\MyModule\Controller;

use Bitrix\Main\Engine\Controller;
use Bitrix\Main\FileUploader\FieldFileUploaderController;
use Bitrix\Main\UI\FileUploader\UploaderController;

class FileUpload extends Controller
{
    /**
     * Возвращает конфигурацию загрузчика для frontend.
     * Вызывается при инициализации компонента.
     */
    public function getUploaderAction(string $entityId, string $fieldName): ?array
    {
        $uploader = new FieldFileUploaderController([
            'entityId'  => $entityId,   // идентификатор сущности ('USER', 'MY_ENTITY' и т.д.)
            'fieldName' => $fieldName,  // имя UF-поля ('UF_PHOTO', 'UF_DOCUMENT')
            'multiple'  => false,       // разрешить множественную загрузку
            'cid'       => '',          // component ID (для composite cache)
        ]);

        return $uploader->getConfiguration()->toArray();
    }
}
```

---

## Параметры FieldFileUploaderController

```php
use Bitrix\Main\FileUploader\FieldFileUploaderController;

$controller = new FieldFileUploaderController([
    // Обязательные
    'entityId'  => 'MY_MODULE_ITEM',  // string: идентификатор типа сущности
    'fieldName' => 'UF_ATTACHMENT',   // string: имя UF-поля

    // Опциональные
    'multiple'      => true,    // bool: разрешить загрузку нескольких файлов
    'signedFileId'  => '',      // string: подписанный ID существующего файла (при редактировании)
    'cid'           => '',      // string: component ID (32 hex символа)
    'id'            => 0,       // int: ID существующего объекта (при редактировании)
]);
```

---

## Frontend: компонент bitrix:ui.file.input

В шаблоне компонента:

```php
use Bitrix\Main\FileUploader\FieldFileUploaderController;
use Bitrix\UI\FileUploader\Configuration;

// В PHP-части компонента
$uploadController = new FieldFileUploaderController([
    'entityId'  => 'MY_ITEM',
    'fieldName' => 'UF_FILE',
    'multiple'  => false,
]);

$uploaderConfig = $uploadController->getConfiguration();

// В шаблоне (template.php)
$APPLICATION->IncludeComponent(
    'bitrix:ui.file.input',
    '',
    [
        'INPUT_NAME'   => 'UF_FILE',
        'INPUT_VALUE'  => $arResult['UF_FILE'] ?? 0,  // текущий FILE_ID или 0
        'MULTIPLE'     => 'N',
        'MODULE_ID'    => 'my.module',
        'UPLOADER_CONFIG' => $uploaderConfig->toArray(),
    ]
);
```

---

## Подтверждение файлов при сохранении

```php
use Bitrix\Main\UserField\File\UploadedFilesRegistry;
use Bitrix\Main\UserField\File\UploaderFileSigner;

// При обработке формы (после submit)
$signedFileId = $_POST['UF_FILE'] ?? ''; // подписанный ID от frontend

if (!empty($signedFileId)) {
    // Верифицировать подпись
    $signer = new UploaderFileSigner();

    if ($signer->verify($signedFileId)) {
        // Получить реальный FILE_ID из реестра
        $registry = new UploadedFilesRegistry();
        $fileId   = $registry->confirm($signedFileId);

        if ($fileId > 0) {
            // Сохранить $fileId в UF-поле объекта
            \CUser::Update($userId, ['UF_PHOTO' => $fileId]);
        }
    }
}
```

---

## Собственный UploaderController

Если нужна кастомная логика (проверка размера, типа, квоты):

```php
namespace MyVendor\MyModule\FileUploader;

use Bitrix\UI\FileUploader\UploaderController;
use Bitrix\UI\FileUploader\Configuration;
use Bitrix\UI\FileUploader\UploadResult;
use Bitrix\UI\FileUploader\FileOwnershipCollection;
use CUser;

class ItemFileController extends UploaderController
{
    protected function isAuthorized(): bool
    {
        global $USER;
        return $USER instanceof CUser && $USER->IsAuthorized();
    }

    public function isAvailable(): bool
    {
        return $this->isAuthorized();
    }

    public function getConfiguration(): Configuration
    {
        return (new Configuration())
            ->setMaxFileSize(10 * 1024 * 1024)   // 10 MB
            ->setAllowedFileExtensions(['.jpg', '.png', '.pdf'])
            ->setMultiple(false);
    }

    public function getOwners(array $fileIds, FileOwnershipCollection $collection): void
    {
        // Определить кому принадлежат загруженные файлы
        // для удаления временных файлов при отмене
        foreach ($fileIds as $fileId) {
            $collection->addCurrentUser($fileId);
        }
    }

    public function onUpload(UploadResult $result): void
    {
        // Callback после загрузки — доп. обработка
    }
}
```

---

## Конфигурация Configuration

```php
use Bitrix\UI\FileUploader\Configuration;

$config = (new Configuration())
    ->setMaxFileSize(5 * 1024 * 1024)              // 5 MB
    ->setMaxTotalFileSize(20 * 1024 * 1024)         // 20 MB итого
    ->setAllowedFileExtensions(['.jpg', '.jpeg', '.png', '.gif', '.pdf'])
    ->setMultiple(true)                             // множественная загрузка
    ->setMaxFileCount(5);                           // не более 5 файлов

// В массив для frontend
$array = $config->toArray();
```

---

## Gotchas

- **Модуль `ui` обязателен**: `FieldFileUploaderController` наследует `UploaderController` из `Bitrix\UI\FileUploader\`. Всегда включай `\Bitrix\Main\Loader::includeModule('ui')`.
- **`signedFileId` истекает**: подписанные ID временны. При редактировании передавай `id` + `signedFileId` существующего файла, иначе файл будет удалён как неподтверждённый.
- **`cid` должен быть 32 hex символа**: если передаёшь `cid` — проверяй формат. Неверный `cid` молча игнорируется (контроллер присвоит пустую строку).
- **`UploadedFilesRegistry` — временное хранилище**: файлы в реестре автоматически удаляются через некоторое время если не подтверждены. Всегда вызывай `confirm()` при сохранении.
- **`entityId` и `fieldName` должны совпадать** при инициализации контроллера и при подтверждении — они являются частью подписи.
- **Нет прямой работы с `$_FILES`**: весь поток загрузки управляется через `UploaderController`. Не смешивай с `CFile::MakeFileArray($_FILES[...])`.
