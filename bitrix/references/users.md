# Пользователи (CUser / UserTable)

> Reference для Bitrix-скилла. Загружай когда задача связана с `CUser`, `Bitrix\Main\UserTable`, текущим пользователем или пользовательскими UF-полями.
>
> Audit note: проверено по текущему core `main/classes/general/user.php`, `main/lib/user.php`, `main/lib/engine/currentuser.php`.

## Текущий пользователь

```php
global $USER; // объект CUser, всегда доступен в контексте сайта

// Основные проверки
$USER->IsAuthorized(); // bool — авторизован ли
$USER->IsAdmin();      // bool — системный администратор
$USER->GetID();        // int — ID, 0 если не авторизован
$USER->GetLogin();     // string — логин
$USER->GetEmail();     // string — email
$USER->GetFullName();  // string — "Имя Фамилия"

// Группы
$groups = $USER->GetUserGroupArray(); // [1, 5, 8] — массив ID групп

// D7-обёртка (без глобальных переменных)
use Bitrix\Main\Engine\CurrentUser;
$currentUser = CurrentUser::get();
$id    = $currentUser->getId();
$login = $currentUser->getLogin();
$email = $currentUser->getEmail();
$isAdmin = $currentUser->isAdmin();
```

---

## D7 ORM: UserTable

```php
use Bitrix\Main\UserTable;

// Поиск пользователей
$result = UserTable::getList([
    'select' => ['ID', 'LOGIN', 'EMAIL', 'NAME', 'LAST_NAME', 'ACTIVE', 'LAST_LOGIN'],
    'filter' => [
        '=ACTIVE' => 'Y',
        '%EMAIL'  => '@example.com',   // LIKE
    ],
    'order'  => ['DATE_REGISTER' => 'DESC'],
    'limit'  => 50,
]);
while ($row = $result->fetch()) { ... }

// Один пользователь по ID
$user = UserTable::getById($userId)->fetch();

// Один пользователь по email
$user = UserTable::getRow([
    'filter' => ['=EMAIL' => 'user@example.com'],
    'select' => ['ID', 'LOGIN', 'NAME', 'LAST_NAME', 'ACTIVE'],
]);

// Пользователи определённой группы (через relation)
$result = UserTable::getList([
    'select' => ['ID', 'LOGIN', 'EMAIL'],
    'filter' => ['=GROUPS.GROUP_ID' => 5],  // OneToMany GROUPS → UserGroupTable
]);
```

### Все поля UserTable (основные)

| Поле | Тип | Описание |
|------|-----|---------|
| `ID` | int | — |
| `LOGIN` | string | логин |
| `EMAIL` | string | email |
| `NAME` / `LAST_NAME` / `SECOND_NAME` | string | имя |
| `ACTIVE` | bool (Y/N) | активен |
| `BLOCKED` | bool (Y/N) | заблокирован |
| `DATE_REGISTER` | datetime | дата регистрации |
| `LAST_LOGIN` | datetime | последний вход |
| `PERSONAL_PHONE` / `PERSONAL_MOBILE` | string | телефоны |
| `PERSONAL_BIRTHDAY` | date | день рождения |
| `PERSONAL_GENDER` | string | `M`/`F`/`` |
| `PERSONAL_PHOTO` | int | ID файла в b_file |
| `LANGUAGE_ID` | string | язык интерфейса |
| `IS_ONLINE` | expr | `Y`/`N` — онлайн ли (active < 15 мин) |

---

## Создание пользователя

```php
$obUser = new CUser();
$userId = $obUser->Add([
    'LOGIN'      => 'ivan_petrov',
    'EMAIL'      => 'ivan@example.com',
    'PASSWORD'   => 'SecurePass123!',
    'CONFIRM_PASSWORD' => 'SecurePass123!',
    'NAME'       => 'Иван',
    'LAST_NAME'  => 'Петров',
    'ACTIVE'     => 'Y',
    'GROUP_ID'   => [5, 8],  // ID групп, ЗАМЕНЯЕТ все группы
    'PERSONAL_PHONE' => '+79991234567',
    'LANGUAGE_ID'    => 'ru',
]);

if (!$userId) {
    $error = $obUser->LAST_ERROR; // строка с ошибкой
}
```

> **Gotcha:** `PASSWORD` хешируется внутри `Add()` через `Password::hash()` — передавай открытый пароль, не хеш.

---

## Обновление пользователя

```php
$obUser = new CUser();
$result = $obUser->Update($userId, [
    'NAME'            => 'Иван',
    'LAST_NAME'       => 'Петров',
    'PERSONAL_MOBILE' => '+79991234567',
    'EMAIL'           => 'new@example.com',
]);

if (!$result) {
    $error = $obUser->LAST_ERROR;
}

// Сменить пароль
$obUser->Update($userId, [
    'PASSWORD'         => 'NewPassword456!',
    'CONFIRM_PASSWORD' => 'NewPassword456!',
]);
```

---

## Авторизация пользователя

```php
global $USER;

// Авторизация по логину/паролю
$result = $USER->Login('ivan_petrov', 'SecurePass123!', 'Y'); // 'Y' = запомнить

if ($result !== true) {
    // $result — массив ['MESSAGE' => '...', 'TYPE' => 'ERROR']
    $error = $result['MESSAGE'];
}

// Авторизовать пользователя по ID (без пароля — только для доверенного кода)
$USER->Authorize($userId);

// Выйти
$USER->Logout();
```

> **Gotcha:** `Login()` возвращает `true` при успехе и массив с ошибкой при неудаче — не bool.

---

## Восстановление пароля

```php
// Отправить письмо с новым паролем / ссылкой на смену
$result = CUser::SendPassword(
    'ivan_petrov',     // логин
    'ivan@example.com', // email (должен совпасть с пользователем)
    SITE_ID            // сайт
);

if ($result['TYPE'] === 'OK') {
    // письмо отправлено
} else {
    $error = $result['MESSAGE'];
}
```

---

## Пользовательские поля (UF) пользователя

UF-сущность пользователя: `USER`.

### Читать UF-поля

```php
// Через CUser::GetByID (возвращает все поля включая UF_*)
$res = CUser::GetByID($userId);
$user = $res->Fetch();
// $user['UF_DEPARTMENT'], $user['UF_CUSTOM_FIELD']

// Для сложных UF-сценариев safest-path:
// читать через CUser::GetByID() или USER_FIELD_MANAGER
global $USER_FIELD_MANAGER;
$ufValues = $USER_FIELD_MANAGER->GetUserFields('USER', $userId, LANGUAGE_ID);
// $ufValues['UF_MY_FIELD']['VALUE']
```

### Обновить UF-поля

```php
global $USER_FIELD_MANAGER;

// Вариант 1: через CUser::Update (передать UF в массиве)
$obUser = new CUser();
$obUser->Update($userId, [
    'UF_DEPARTMENT' => 5,
    'UF_BIO'        => 'Текст...',
]);

// Вариант 2: напрямую через USER_FIELD_MANAGER
$USER_FIELD_MANAGER->Update('USER', $userId, [
    'UF_DEPARTMENT' => 5,
]);
```

### Создать UF-поле для пользователей

```php
$oUserTypeEntity = new CUserTypeEntity();
$oUserTypeEntity->Add([
    'ENTITY_ID'         => 'USER',
    'FIELD_NAME'        => 'UF_TELEGRAM',
    'USER_TYPE_ID'      => 'string',
    'SORT'              => 100,
    'MULTIPLE'          => 'N',
    'MANDATORY'         => 'N',
    'SHOW_FILTER'       => 'I',
    'SHOW_IN_LIST'      => 'Y',
    'EDIT_IN_LIST'      => 'Y',
    'EDIT_FORM_LABEL'   => ['ru' => 'Telegram', 'en' => 'Telegram'],
    'LIST_COLUMN_LABEL' => ['ru' => 'Telegram', 'en' => 'Telegram'],
]);
```

---

## Группы пользователей

```php
// Назначить группы (ЗАМЕНЯЕТ все существующие)
CUser::SetUserGroup($userId, [5, 8, 14]);

// Добавить в группу (сохранив остальные)
$currentGroups = $USER->GetUserGroupArray();
if (!in_array(5, $currentGroups)) {
    CUser::SetUserGroup($userId, array_merge($currentGroups, [5]));
}

// Проверить группу у произвольного пользователя
$res = CUser::GetByID($userId);
$user = $res->Fetch();
// группы в отдельном запросе:
$groupRes = CUser::GetUserGroup($userId); // устаревший способ
// Через UserTable D7:
$result = \Bitrix\Main\UserGroupTable::getList([
    'filter' => ['=USER_ID' => $userId],
    'select' => ['GROUP_ID'],
]);
$groupIds = array_column($result->fetchAll(), 'GROUP_ID');
```

---

## Поиск пользователей (legacy)

```php
// Legacy GetList — все ещё широко используется
$res = CUser::GetList(
    $sort = 'ID',
    $order = 'ASC',
    $arFilter = [
        'ACTIVE'      => 'Y',
        'GROUPS_ID'   => [5],          // пользователи из группы 5
        'NAME_SEARCH' => 'Иван',       // поиск по имени
    ],
    $arParams = [
        'SELECT' => ['UF_DEPARTMENT'], // добавить UF-поля в выборку
        'NAV_PARAMS' => ['nPageSize' => 20],
    ]
);
while ($user = $res->Fetch()) { ... }
```

---

## События пользователя

```php
use Bitrix\Main\EventManager;
use Bitrix\Main\Application;

$em = EventManager::getInstance();

// OnBeforeUserAdd / OnBeforeUserUpdate — legacy-события main.
// Чтобы изменить $arFields по ссылке или отменить операцию — нужен addEventHandlerCompatible.
// addEventHandler оборачивает параметры в Event-объект и ссылка теряется.
$em->addEventHandlerCompatible('main', 'OnBeforeUserAdd',
    ['\MyVendor\MyModule\UserHandler', 'onBeforeAdd']);

class UserHandler
{
    // $arFields — по ссылке: можно читать и изменять
    public static function onBeforeAdd(array &$arFields): void
    {
        // Нормализация
        $arFields['EMAIL'] = mb_strtolower(trim($arFields['EMAIL'] ?? ''));

        // Отмена операции: ThrowException, ядро проверит GetException() после события
        if (empty($arFields['EMAIL'])) {
            global $APPLICATION;
            $APPLICATION->ThrowException('Email обязателен');
        }
    }

    // OnAfterUserAdd — читаем результат, arFields['ID'] = ID нового пользователя
    public static function onAfterAdd(array &$arFields): void
    {
        $userId = (int)$arFields['ID'];
        // отправить welcome-письмо и т.д.
    }
}

// OnAfterUserAdd через addEventHandler тоже работает если не нужна ссылка
$em->addEventHandler('main', 'OnAfterUserAdd', function(\Bitrix\Main\Event $event) {
    $fields = $event->getParameter('arFields');
    $userId = (int)($fields['ID'] ?? 0);
    // логика после добавления
});

// После авторизации
$em->addEventHandler('main', 'OnUserLoginComplete', function(\Bitrix\Main\Event $event) {
    $userId = (int)$event->getParameter('USER_ID');
});
```

> **Gotcha:** `OnBeforeUserAdd` / `OnBeforeUserUpdate` — legacy-события `main`. Если нужно изменить `$arFields` или отменить операцию через `ThrowException` — обязательно `addEventHandlerCompatible`. `addEventHandler` (D7-обёртка) передаёт параметры как копию внутри `Event`-объекта, ссылка на массив теряется.

---

## Gotchas

- `GROUP_ID` в `CUser::Add` **заменяет** все группы. Не передавай если не хочешь сбросить группы
- `CUser::SetUserGroup` тоже **заменяет** все группы — сначала считай текущие
- Для произвольных UF-полей safest-path — `CUser::GetByID` или `USER_FIELD_MANAGER->GetUserFields`. Не обещай вслепую одинаковое поведение всех UF через `UserTable::getList`
- `$USER->IsAdmin()` — только системный администратор (группа 1). Для проверки других групп используй `GetUserGroupArray()`
- `CUser::GetByID` возвращает db_result, надо вызвать `->Fetch()`
- Пароль в `Add/Update` всегда открытый — ядро само хеширует через `Password::hash()`
