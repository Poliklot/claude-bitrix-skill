# Bitrix Access RBAC — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с D7-доступами на базе `Bitrix\Main\Access\*`: `PermissionDictionary`, `RoleDictionary`, `BaseAccessController`, `AbstractRule`, `AccessPermissionTable`, `AccessRoleTable`.
>
> Audit note: проверено по текущему core `main/lib/access/*`.

## Содержание
- Архитектура RBAC
- `PermissionDictionary`
- `RoleDictionary`
- `BaseAccessController`
- `AbstractRule`
- `AccessPermissionTable` / `AccessRoleTable`
- Naming convention rule/filter factory
- Gotchas

---

## Архитектура RBAC

Текущий D7-access слой строится вокруг четырёх сущностей:

- **Permission** — строковый код права
- **Role** — роль, которой потом сопоставляют значения permission
- **AccessibleUser** — модель пользователя, умеющая вернуть роли, access-codes и значение permission
- **AccessController** — orchestration-слой, который грузит пользователя/элемент и запускает rule/filter factory

Схема:

```text
AccessibleUser
    └── getPermission(permissionId)

BaseAccessController
    ├── check()
    ├── checkByItemId()
    ├── batchCheck()
    └── getEntityFilter()

RuleControllerFactory
    └── \Vendor\Module\Access\Rule\<Action>Rule

FilterControllerFactory
    └── \Vendor\Module\Access\Filter\<Action>Filter
```

---

## `PermissionDictionary`

В текущем core `PermissionDictionary` не требует `getPermissions()`. Базовый класс уже умеет:

- `getList()`
- `getPermission($permissionId)`
- `getTitle($permissionId)`
- `getType($permissionId)`

Минимальный словарь выглядит так:

```php
namespace MyVendor\MyModule\Access\Permission;

use Bitrix\Main\Access\Permission\PermissionDictionary;

class MyPermissionDictionary extends PermissionDictionary
{
    public const ITEM_VIEW   = 'item.view';
    public const ITEM_EDIT   = 'item.edit';
    public const ITEM_DELETE = 'item.delete';
    public const REPORT_MODE = 'report.mode';

    public static function getType($permissionId): string
    {
        return match ($permissionId) {
            self::REPORT_MODE => self::TYPE_VARIABLES,
            default => self::TYPE_TOGGLER,
        };
    }
}
```

Подтверждённые типы:

- `TYPE_TOGGLER`
- `TYPE_VARIABLES`
- `TYPE_MULTIVARIABLES`
- `TYPE_DEPENDENT_VARIABLES`

Подтверждённые значения:

```php
PermissionDictionary::VALUE_NO  = 0;
PermissionDictionary::VALUE_YES = 1;
```

`getList()` строится по константам класса, поэтому локализация обычно идёт через `Loc::loadMessages()` и имена констант.

---

## `RoleDictionary`

В текущем core `RoleDictionary` не даёт универсальный метод `getRoles()`. Подтверждён только базовый helper:

```php
use Bitrix\Main\Access\Role\RoleDictionary;

class MyRoleDictionary extends RoleDictionary
{
    public const ROLE_ADMIN  = 'MY_MODULE_ADMIN';
    public const ROLE_EDITOR = 'MY_MODULE_EDITOR';
    public const ROLE_VIEWER = 'MY_MODULE_VIEWER';
}

$title = MyRoleDictionary::getRoleName(MyRoleDictionary::ROLE_ADMIN);
```

Практический вывод:

- роли в reference лучше описывать через константы + локализацию
- хранение и CRUD ролей зависят уже от твоих конкретных таблиц/сервисов модуля

---

## `BaseAccessController`

`BaseAccessController` уже реализует основной runtime:

- `getInstance($userId)`
- `can($userId, $action, $itemId = null, $params = null)`
- `checkByItemId(...)`
- `check(...)`
- `batchCheck(...)`
- `getEntityFilter(...)`

От наследника требуются только две вещи:

```php
namespace MyVendor\MyModule\Access;

use Bitrix\Main\Access\AccessibleItem;
use Bitrix\Main\Access\BaseAccessController;
use Bitrix\Main\Access\User\AccessibleUser;

class MyAccessController extends BaseAccessController
{
    protected function loadItem(int $itemId = null): ?AccessibleItem
    {
        return $itemId ? MyItemModel::createFromId($itemId) : MyItemModel::createNew();
    }

    protected function loadUser(int $userId): AccessibleUser
    {
        return MyUserModel::createFromId($userId);
    }
}
```

Использование:

```php
if (!MyAccessController::can($USER->GetID(), 'item_view', $itemId))
{
    ShowError('Недостаточно прав');
    return;
}

$controller = MyAccessController::getInstance((int)$USER->GetID());
$canEdit = $controller->checkByItemId('item_edit', $itemId);
```

---

## `AbstractRule`

Правило в текущем core получает `AccessibleController` в конструкторе, а внутри уже имеет `$this->user`.

```php
namespace MyVendor\MyModule\Access\Rule;

use Bitrix\Main\Access\AccessibleItem;
use Bitrix\Main\Access\Rule\AbstractRule;
use MyVendor\MyModule\Access\Permission\MyPermissionDictionary;

class ItemEditRule extends AbstractRule
{
    public function execute(AccessibleItem $item = null, $params = null): bool
    {
        if ($this->user->isAdmin())
        {
            return true;
        }

        $permission = $this->user->getPermission(MyPermissionDictionary::ITEM_EDIT);

        return $permission !== null && $permission >= MyPermissionDictionary::VALUE_YES;
    }
}
```

Подтверждённая сигнатура:

```php
abstract public function execute(AccessibleItem $item = null, $params = null): bool;
```

---

## `AccessPermissionTable` / `AccessRoleTable`

Обе таблицы в `main` — абстрактные базовые классы. Их нельзя использовать как готовые таблицы “из коробки” без собственного наследника с `getTableName()`.

### Роли

```php
namespace MyVendor\MyModule\Access\Role;

use Bitrix\Main\Access\Role\AccessRoleTable;

class MyAccessRoleTable extends AccessRoleTable
{
    public static function getTableName()
    {
        return 'b_my_module_role';
    }
}
```

### Права роли

```php
namespace MyVendor\MyModule\Access\Permission;

use Bitrix\Main\Access\Permission\AccessPermissionTable;

class MyAccessPermissionTable extends AccessPermissionTable
{
    public static function getTableName()
    {
        return 'b_my_module_permission';
    }
}
```

После этого уже можно делать обычный ORM-CRUD:

```php
MyAccessPermissionTable::add([
    'ROLE_ID' => 10,
    'PERMISSION_ID' => MyPermissionDictionary::ITEM_EDIT,
    'VALUE' => MyPermissionDictionary::VALUE_YES,
]);
```

Важно: `AccessPermissionTable` в текущем core сам валидирует иерархию permission-path. Если родительское permission выключено (`VALUE_NO`), дочерние значения могут быть автоматически зажаты вниз.

---

## Naming convention rule/filter factory

`BaseAccessController` по умолчанию использует:

- `RuleControllerFactory`
- `FilterControllerFactory`

Имена классов собираются автоматически из action:

```text
Controller namespace: MyVendor\MyModule\Access
Action: item_edit

Rule class:   MyVendor\MyModule\Access\Rule\ItemEditRule
Filter class: MyVendor\MyModule\Access\Filter\ItemEditFilter
```

То есть action `my_item_delete` превратится в `Rule\MyItemDeleteRule`.

Если такого класса нет, `check()` завершится `UnknownActionException`.

---

## Gotchas

- `PermissionDictionary::getList()` строится по константам класса. Не выдумывай отдельный обязательный `getPermissions()` — он не является core-contract текущего `main`.
- `RoleDictionary` в базовом виде умеет только `getRoleName()`. Полный “список ролей” — ответственность конкретного модуля.
- `AccessPermissionTable` и `AccessRoleTable` абстрактные. Для реального хранения прав нужен собственный наследник с `getTableName()`.
- `BaseAccessController::can()` кеширует экземпляр контроллера по `userId`. Если в этом же запросе ты поменял роли/права и хочешь свежую проверку, создавай новый controller осознанно.
- `AbstractRule::$this->user->isAdmin()` проверяет суперадмина Bitrix, а не произвольную бизнес-роль модуля.
- `$item` в `execute()` может быть `null`. Rule должна это корректно переживать.
- Для массовых выборок полезен `getEntityFilter()`, но фильтр появится только если для action существует соответствующий `Filter\<Action>Filter`.
