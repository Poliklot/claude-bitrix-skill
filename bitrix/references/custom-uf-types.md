# Кастомные UF-типы — core-first справочник

> Reference для Bitrix-скилла. Загружай, когда задача связана с `OnUserTypeBuildList`, кастомными UF-типами, `Bitrix\Main\UserField\Types\BaseType`, HL-backed UF-типами или рендером пользовательских полей через системные компоненты.

## Что подтверждено в текущем core

- D7-базовый класс — `Bitrix\Main\UserField\Types\BaseType`.
- Базовые D7-типы (`string`, `integer`, `double`, `date`, `datetime`, `boolean`, `enum`, `file`) уже построены поверх `BaseType`.
- Legacy-обёртки (`CUserTypeString`, `CUserTypeFile` и т.д.) делегируют в D7-типы.
- UF-тип регистрируется через событие `main:OnUserTypeBuildList`.

---

## Минимальный паттерн кастомного типа

```php
use Bitrix\Main\EventManager;

EventManager::getInstance()->addEventHandler(
    'main',
    'OnUserTypeBuildList',
    ['\\MyVendor\\MyModule\\UserField\\MyCustomType', 'getUserTypeDescription']
);
```

```php
namespace MyVendor\MyModule\UserField;

use Bitrix\Main\Application;
use Bitrix\Main\ORM\Fields\StringField;
use Bitrix\Main\UserField\Types\BaseType;
use CUserTypeManager;

class MyCustomType extends BaseType
{
    public const USER_TYPE_ID = 'my_custom_type';
    public const RENDER_COMPONENT = 'bitrix:system.field.edit';

    protected static function getDescription(): array
    {
        return [
            'DESCRIPTION' => 'Мой UF-тип',
            'BASE_TYPE' => CUserTypeManager::BASE_TYPE_STRING,
        ];
    }

    public static function getDbColumnType(): string
    {
        $connection = Application::getConnection();
        return $connection->getSqlHelper()->getColumnTypeByField(new StringField('x'));
    }

    public static function prepareSettings(array $userField): array
    {
        return [
            'DEFAULT_VALUE' => is_array($userField['SETTINGS'])
                ? ($userField['SETTINGS']['DEFAULT_VALUE'] ?? '')
                : '',
        ];
    }

    public static function checkFields(array $userField, $value): array
    {
        return [];
    }

    public static function onBeforeSave(array $userField, $value)
    {
        return is_scalar($value) ? (string)$value : '';
    }
}
```

### Почему именно так

- `getUserTypeDescription()` уже приходит из `BaseType`, если заданы `USER_TYPE_ID`, `RENDER_COMPONENT` и `getDescription()`.
- `BASE_TYPE` в текущем core задаётся в `getDescription()`, а не как обязательная константа класса.
- Единственный действительно абстрактный метод `BaseType` — `getDbColumnType()`.

---

## Что у `BaseType` делает сам core

`BaseType` уже предоставляет:

- `renderView()`
- `renderEdit()`
- `renderEditForm()`
- `renderAdminListView()`
- `renderAdminListEdit()`
- `renderFilter()`
- `renderText()`
- `getDefaultValue()`

Все они работают через `APPLICATION->IncludeComponent(...)` и системные field-компоненты.

Это значит, что переопределять `renderEditForm()` и `renderAdminListView()` нужно только когда реально нужен кастомный HTML.

---

## Какие хуки реально стоит считать опциональными

В текущем core для D7 UF-типа полезны, но не обязательны:

- `prepareSettings(array $userField): array`
- `checkFields(array $userField, $value): array`
- `onBeforeSave(array $userField, $value)`
- `renderEditForm(...)`
- `renderAdminListView(...)`
- `getFilterData(...)`
- `getEntityField(...)`
- `getEntityReferences(...)`
- `onSearchIndex(array $userField)`

Не нужно объявлять их как "обязательные" по умолчанию.

---

## HL-backed тип `hlblock`

В текущем core тип `hlblock` реализован классом `CUserTypeHlblock`:

- `USER_TYPE_ID = 'hlblock'`
- `BASE_TYPE = int`
- `RENDER_COMPONENT = bitrix:highloadblock.field.element`
- `getEntityReferences()` автоматически добавляет `<FIELD_NAME>_REF`

Это важный ориентир, если нужно реализовать свой тип со ссылочной логикой: смотри на `highloadblock/classes/general/cusertypehlblock.php`, а не придумывай свою семантику `_REF`.

---

## Про файлы

Для файлового UF-типа в текущем core опорный пример — `Bitrix\Main\UserField\Types\FileType`.

Что у него реально подтверждено:

- `BASE_TYPE = file` приходит через `getDescription()`;
- колонка хранит `int` (`b_file.ID`);
- `onBeforeSave()` поддерживает и старый механизм массива файла, и новые registries;
- `onSearchIndex()` уже реализован в core;
- логика удаления и валидации сложнее, чем "если пусто, просто вернуть false".

Если нужен свой файловый тип, безопаснее отталкиваться от `FileType`, а не писать упрощённую версию "по памяти".

---

## Gotchas

- В D7-паттерне не переопределяй `getUserTypeDescription()` без необходимости: у `BaseType` уже есть нормальная базовая реализация.
- Не объявляй `BASE_TYPE` как самостоятельную "обязательную" константу. Для текущего core надёжнее задавать `BASE_TYPE` через `getDescription()`.
- Не рассчитывай на универсальный `onDelete()` для кастомного UF-типа: в текущем core это не общий контракт `BaseType`.
- Если тип должен участвовать в ORM-связях, смотри на `getEntityField()` и `getEntityReferences()`.
- Для HL-ссылок ориентируйся на `CUserTypeHlblock`, для directory-свойств — на `CIBlockPropertyDirectory`: это два разных механизма.
