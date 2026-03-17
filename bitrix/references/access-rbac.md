# Bitrix Access RBAC — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с контролем доступа на основе ролей: `Bitrix\Main\Access\Permission\PermissionDictionary`, `Role\RoleDictionary`, `BaseAccessController`, `AccessibleController`, таблицами прав `AccessPermissionTable`, `AccessRoleTable`.

## Содержание
- Архитектура RBAC в Bitrix D7
- PermissionDictionary: определение прав
- RoleDictionary: определение ролей
- AccessController: реализация контроллера доступа
- Rule: правила проверки
- Таблицы: AccessPermissionTable, AccessRoleTable
- Примеры: полный цикл настройки RBAC
- Gotchas

---

## Архитектура

Bitrix D7 предлагает RBAC-фреймворк в `Bitrix\Main\Access\*`.

**Основные концепции:**
- **Permission** — конкретное право (что можно делать: `view`, `edit`, `delete`)
- **Role** — набор прав с заданными значениями
- **AccessController** — проверяет может ли пользователь выполнить действие
- **Rule** — логика проверки конкретного действия

```
User → has Roles → Role имеет Permissions → Permission проверяется через Rule
```

---

## PermissionDictionary: определение прав

```php
namespace MyVendor\MyModule\Access\Permission;

use Bitrix\Main\Access\Permission\PermissionDictionary;

class MyPermissionDictionary extends PermissionDictionary
{
    // Константы прав — используй строки, уникальные в модуле
    public const MY_ITEM_VIEW   = 'my_item_view';
    public const MY_ITEM_EDIT   = 'my_item_edit';
    public const MY_ITEM_DELETE = 'my_item_delete';
    public const MY_REPORT_VIEW = 'my_report_view';

    // Описание прав для UI
    public static function getPermissions(): array
    {
        return [
            [
                'id'    => self::MY_ITEM_VIEW,
                'title' => 'Просмотр элементов',
                'type'  => self::TYPE_TOGGLER,  // включено/выключено
            ],
            [
                'id'    => self::MY_ITEM_EDIT,
                'title' => 'Редактирование элементов',
                'type'  => self::TYPE_TOGGLER,
            ],
            [
                'id'    => self::MY_ITEM_DELETE,
                'title' => 'Удаление элементов',
                'type'  => self::TYPE_TOGGLER,
            ],
            [
                'id'    => self::MY_REPORT_VIEW,
                'title' => 'Просмотр отчётов',
                'type'  => self::TYPE_VARIABLES, // список значений
                'items' => [
                    ['id' => 'all',  'title' => 'Все отчёты'],
                    ['id' => 'own',  'title' => 'Только свои'],
                    ['id' => 'none', 'title' => 'Запрещено'],
                ],
            ],
        ];
    }
}
```

**Типы прав:**

| Константа | Описание |
|-----------|----------|
| `TYPE_TOGGLER` | Вкл/Выкл (VALUE_YES / VALUE_NO) |
| `TYPE_VARIABLES` | Выбор одного из списка значений |
| `TYPE_MULTIVARIABLES` | Выбор нескольких из списка |
| `TYPE_DEPENDENT_VARIABLES` | Зависимые переменные |

**Предопределённые значения:**
```php
PermissionDictionary::VALUE_NO  = 0; // запрещено
PermissionDictionary::VALUE_YES = 1; // разрешено
```

---

## RoleDictionary: определение ролей

```php
namespace MyVendor\MyModule\Access\Role;

use Bitrix\Main\Access\Role\RoleDictionary;

class MyRoleDictionary extends RoleDictionary
{
    public const ROLE_ADMIN  = 'my_module_admin';
    public const ROLE_EDITOR = 'my_module_editor';
    public const ROLE_VIEWER = 'my_module_viewer';

    public static function getRoles(): array
    {
        return [
            [
                'id'    => self::ROLE_ADMIN,
                'title' => 'Администратор модуля',
            ],
            [
                'id'    => self::ROLE_EDITOR,
                'title' => 'Редактор',
            ],
            [
                'id'    => self::ROLE_VIEWER,
                'title' => 'Наблюдатель',
            ],
        ];
    }
}
```

---

## Rule: логика проверки действия

Каждому действию соответствует `Rule`-класс. Он получает пользователя и параметры, возвращает `bool`.

```php
namespace MyVendor\MyModule\Access\Rule;

use Bitrix\Main\Access\Rule\AbstractRule;
use Bitrix\Main\Access\AccessibleItem;
use MyVendor\MyModule\Access\Permission\MyPermissionDictionary;

class MyItemViewRule extends AbstractRule
{
    public function execute(?AccessibleItem $item = null, $params = null): bool
    {
        // Суперадмин всегда может
        if ($this->user->isAdmin()) {
            return true;
        }

        // Проверить право MY_ITEM_VIEW
        $permission = $this->user->getPermission(
            MyPermissionDictionary::MY_ITEM_VIEW
        );

        return $permission >= MyPermissionDictionary::VALUE_YES;
    }
}

class MyItemEditRule extends AbstractRule
{
    public function execute(?AccessibleItem $item = null, $params = null): bool
    {
        if ($this->user->isAdmin()) {
            return true;
        }

        $permission = $this->user->getPermission(
            MyPermissionDictionary::MY_ITEM_EDIT
        );

        // Дополнительно: проверить владельца элемента
        if ($permission < MyPermissionDictionary::VALUE_YES) {
            return false;
        }

        // Если элемент передан — проверить принадлежность
        if ($item !== null && $item->getOwnerId() !== $this->user->getUserId()) {
            return false;
        }

        return true;
    }
}
```

---

## BaseAccessController: основной контроллер

```php
namespace MyVendor\MyModule\Access;

use Bitrix\Main\Access\BaseAccessController;
use Bitrix\Main\Access\AccessibleItem;
use MyVendor\MyModule\Access\Rule\MyItemViewRule;
use MyVendor\MyModule\Access\Rule\MyItemEditRule;
use MyVendor\MyModule\Access\Rule\MyItemDeleteRule;

class MyAccessController extends BaseAccessController
{
    // Маппинг действий на Rule-классы
    protected function getRules(): array
    {
        return [
            'view'   => MyItemViewRule::class,
            'edit'   => MyItemEditRule::class,
            'delete' => MyItemDeleteRule::class,
        ];
    }

    protected function loadUser(int $userId): \Bitrix\Main\Access\User\AccessibleUser
    {
        return new MyAccessUser($userId);
    }
}
```

---

## Использование контроллера

```php
use MyVendor\MyModule\Access\MyAccessController;

$userId = $USER->GetID();

// Статическая проверка (singleton по userId)
if (!MyAccessController::can($userId, 'view')) {
    ShowError('Недостаточно прав');
    return;
}

// С элементом
$item = MyItemTable::getById($itemId)->fetchObject();
if (!MyAccessController::can($userId, 'edit', $itemId)) {
    ShowError('Нельзя редактировать этот элемент');
    return;
}

// Через экземпляр (больше контроля)
$controller = MyAccessController::getInstance($userId);
$canDelete  = $controller->checkByItemId('delete', $itemId);
```

---

## Таблицы хранения прав

```php
use Bitrix\Main\Access\Permission\AccessPermissionTable;
use Bitrix\Main\Access\Role\AccessRoleTable;

// Сохранить права для роли
AccessPermissionTable::add([
    'MODULE_ID'     => 'my.module',
    'ROLE_ID'       => 'my_module_editor',
    'PERMISSION_ID' => 'my_item_edit',
    'VALUE'         => 1,
]);

// Получить права роли
$permissions = AccessPermissionTable::getList([
    'filter' => [
        '=MODULE_ID' => 'my.module',
        '=ROLE_ID'   => 'my_module_editor',
    ],
])->fetchAll();

// Удалить права роли
AccessPermissionTable::deleteByFilter([
    '=MODULE_ID' => 'my.module',
    '=ROLE_ID'   => 'my_module_editor',
]);
```

---

## Инициализация прав по умолчанию (при установке модуля)

```php
// В install/index.php или updater
use Bitrix\Main\Access\Permission\AccessPermissionTable;
use MyVendor\MyModule\Access\Permission\MyPermissionDictionary;
use MyVendor\MyModule\Access\Role\MyRoleDictionary;

// Дать администратору все права
foreach (MyPermissionDictionary::getPermissions() as $permission) {
    AccessPermissionTable::add([
        'MODULE_ID'     => 'my.module',
        'ROLE_ID'       => MyRoleDictionary::ROLE_ADMIN,
        'PERMISSION_ID' => $permission['id'],
        'VALUE'         => MyPermissionDictionary::VALUE_YES,
    ]);
}
```

---

## Gotchas

- **`BaseAccessController::can()` — singleton**: контроллер кешируется по `userId`. Если права изменились в этом же запросе — кеш не сбрасывается. Используй `new MyAccessController($userId)` для свежей проверки.
- **`AbstractRule::$this->user->isAdmin()`**: проверяет является ли пользователь суперадмином Bitrix (группа 1). Всегда проверяй это первым.
- **Загрузка пользователя**: `loadUser()` вызывается один раз при создании контроллера. Реализуй `MyAccessUser` корректно — он должен загружать роли пользователя из БД.
- **`TYPE_TOGGLER` не равен `bool`**: значение хранится как `int` (0 = нет, 1 = да). Сравнивай через `>= VALUE_YES`, не через `=== true`.
- **Таблица `AccessPermissionTable` мультимодульная**: указывай `MODULE_ID` при всех операциях — иначе получишь права всех модулей.
- **Rule без элемента**: `$item` в `execute()` может быть `null` — при проверке действия без конкретного объекта.
