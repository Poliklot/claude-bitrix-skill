# Bitrix Admin UI — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с созданием или изменением страниц в битриксовой админке: списки, формы редактирования, фильтры, групповые действия, меню, права, кастомные типы пользовательских полей.

## Audit note

Проверено по текущему core:
- `www/bitrix/modules/main/interface/admin_list.php`
- `www/bitrix/modules/main/interface/admin_form.php`
- `www/bitrix/modules/main/interface/admin_filter.php`
- `www/bitrix/modules/main/interface/admin_tabcontrol.php`
- `www/bitrix/modules/main/interface/admin_lib.php`
- `www/bitrix/modules/main/include/prolog_admin_*.php`

Главный вывод: админский UI в этом core по-прежнему опирается прежде всего на legacy-слой из `main/interface/*`, а не на какой-то единый новый D7 admin framework.

## Содержание
- Анатомия admin-страницы: prolog/epilog
- CAdminList — список с сортировкой, фильтром, пагинацией
- CAdminSorting, CAdminResult, CAdminFilter
- CAdminListRow — поля строки, действия
- Групповые действия (GroupAction)
- CAdminContextMenu — кнопки контекстного меню
- Форма редактирования: CAdminTabControl vs CAdminForm
- Admin-меню модуля (menu.php)
- Права доступа модуля
- Кастомные типы пользовательских полей (OnUserTypeBuildList)
- Gotchas

---

## Анатомия admin-страницы

Каждая страница в `/bitrix/admin/` состоит из двух частей:

```
prolog_admin_before.php  ← инициализация: сессия, авторизация, константы
  [ваш PHP: данные, actions, объекты CAdminList / CAdminTabControl]
prolog_admin_after.php   ← вывод шапки, JS, CSS
  [ваш PHP+HTML: форма, фильтр, таблица]
epilog_admin.php         ← вывод подвала
```

```php
<?php
require_once $_SERVER['DOCUMENT_ROOT'] . '/bitrix/modules/main/include/prolog_admin_before.php';

// Проверка прав
$right = $APPLICATION->GetGroupRight('my.module'); // 'D','R','W','X' или ''
if ($right === 'D') {
    $APPLICATION->AuthForm('Доступ запрещён');
}

// ... ваша логика (объекты, actions, фильтр) ...

require_once $_SERVER['DOCUMENT_ROOT'] . '/bitrix/modules/main/include/prolog_admin_after.php';

// ... HTML/PHP разметка ...

require_once $_SERVER['DOCUMENT_ROOT'] . '/bitrix/modules/main/include/epilog_admin.php';
?>
```

---

## Страница-список: полный шаблон

```php
<?php
require_once $_SERVER['DOCUMENT_ROOT'] . '/bitrix/modules/main/include/prolog_admin_before.php';

use Vendor\MyModule\MyTable;
use Bitrix\Main\Loader;

Loader::requireModule('my.module');
IncludeModuleLangFile(__FILE__);

$right = $APPLICATION->GetGroupRight('my.module');
if ($right === 'D') $APPLICATION->AuthForm(GetMessage('ACCESS_DENIED'));

// ── 1. Сортировка ──────────────────────────────────────────────────────────
$tableId = 'tbl_mymodule_items';
$oSort   = new CAdminSorting($tableId, 'ID', 'desc');
// new CAdminSorting($tableId, $defaultBy, $defaultOrder, $byParamName='by', $orderParamName='order')
// Читает GET-параметры by/order, кеширует в сессии

$lAdmin = new CAdminList($tableId, $oSort);

// ── 2. Фильтр ──────────────────────────────────────────────────────────────
// ВАЖНО: имена переменных фильтра — глобальные (global $$f внутри InitFilter)
$arFilterFields = ['find_id', 'find_name', 'find_active', 'find_date_from', 'find_date_to'];
$lAdmin->InitFilter($arFilterFields);
// После вызова доступны глобальные переменные: $find_id, $find_name и т.д.
foreach ($arFilterFields as $f) global $$f;

// ── 3. Групповые действия ──────────────────────────────────────────────────
if (($arIDs = $lAdmin->GroupAction()) && $right >= 'W' && check_bitrix_sessid()) {
    if ($_REQUEST['action_target'] === 'selected') {
        // "применить ко всем отфильтрованным"
        $arIDs = MyTable::getList(['select' => ['ID'], 'filter' => $arFilter])->fetchColumn();
    }
    foreach ($arIDs as $id) {
        $id = (int)$id;
        if (!$id) continue;
        switch ($_REQUEST['action']) {
            case 'delete':
                $r = MyTable::delete($id);
                if (!$r->isSuccess()) {
                    $lAdmin->AddGroupError(implode(', ', $r->getErrorMessages()), $id);
                }
                break;
            case 'activate':
                MyTable::update($id, ['ACTIVE' => 'Y']);
                break;
        }
    }
}

// ── 4. Инлайн-редактирование одной строки ─────────────────────────────────
if ($lAdmin->EditAction() && $right >= 'W' && check_bitrix_sessid()) {
    foreach ($lAdmin->GetEditFields() as $id => $arFields) {
        $id = (int)$id;
        $r = MyTable::update($id, [
            'NAME'   => trim($arFields['NAME'] ?? ''),
            'ACTIVE' => $arFields['ACTIVE'] ?? 'N',
        ]);
        if (!$r->isSuccess()) {
            $lAdmin->AddUpdateError(implode(', ', $r->getErrorMessages()), $id);
        }
    }
}

// ── 5. Составить фильтр для запроса ───────────────────────────────────────
$arFilter = [];
if ($find_id)         $arFilter['=ID']    = (int)$find_id;
if ($find_name)       $arFilter['%NAME']  = $find_name;
if ($find_active)     $arFilter['=ACTIVE'] = $find_active;
if ($find_date_from)  $arFilter['>=DATE_CREATE'] = $find_date_from;
if ($find_date_to)    $arFilter['<=DATE_CREATE']  = $find_date_to;

// ── 6. Запрос к БД ────────────────────────────────────────────────────────
global $by, $order; // установлены CAdminSorting
$dbResult = MyTable::getList([
    'select' => ['ID', 'NAME', 'ACTIVE', 'DATE_CREATE', 'PRICE'],
    'filter' => $arFilter,
    'order'  => [$by ?: 'ID' => strtoupper($order ?: 'DESC')],
]);

// Обернуть в CAdminResult для пагинации
$rsData = new CAdminResult($dbResult, $tableId);
$rsData->NavStart(20); // 20 записей на страницу

$lAdmin->NavText($rsData->GetNavPrint(GetMessage('MY_MODULE_PAGES')));

// ── 7. Заголовки колонок ───────────────────────────────────────────────────
$lAdmin->AddHeaders([
    ['id' => 'ID',          'content' => 'ID',           'sort' => 'ID',          'default' => true],
    ['id' => 'NAME',        'content' => 'Название',     'sort' => 'NAME',        'default' => true],
    ['id' => 'ACTIVE',      'content' => 'Активность',   'sort' => 'ACTIVE',      'default' => true],
    ['id' => 'DATE_CREATE', 'content' => 'Дата',         'sort' => 'DATE_CREATE', 'default' => true],
    ['id' => 'PRICE',       'content' => 'Цена',         'sort' => 'PRICE',       'default' => true, 'align' => 'right'],
    ['id' => 'ACTIONS',     'content' => '',             'default' => true],
]);

// ── 8. Строки ──────────────────────────────────────────────────────────────
$editUrl = '/bitrix/admin/mymodule_item_edit.php?lang=' . LANGUAGE_ID;

while ($res = $rsData->getNext()) {
    $id = (int)$res['ID'];

    // AddRow($id, $arRes, $editLink, $editTitle)
    $row = &$lAdmin->AddRow($id, $res, $editUrl . '&ID=' . $id, 'Редактировать');

    // Простое HTML-поле (view only)
    $row->AddViewField('NAME', '<a href="' . $editUrl . '&ID=' . $id . '">' . htmlspecialcharsEx($res['NAME']) . '</a>');

    // Текстовое поле + inline edit
    $row->AddField('ACTIVE', ($res['ACTIVE'] === 'Y' ? 'Да' : 'Нет'));
    $row->AddSelectField('ACTIVE', ['Y' => 'Да', 'N' => 'Нет']);

    $row->AddField('DATE_CREATE', htmlspecialcharsEx($res['DATE_CREATE']));
    $row->AddField('PRICE', htmlspecialcharsEx($res['PRICE']));

    // Действия строки (выпадающее меню)
    if ($right >= 'W') {
        $row->AddActions([
            [
                'ICON'   => 'edit',
                'TEXT'   => 'Редактировать',
                'ACTION' => "window.location='" . $editUrl . '&ID=' . $id . "'",
                'DEFAULT' => true, // двойной клик по строке
            ],
            [
                'ICON'   => 'delete',
                'TEXT'   => 'Удалить',
                'ACTION' => "if(confirm('Удалить запись?')) window.location='/bitrix/admin/mymodule_item_list.php?action=delete&ID={$id}&" . bitrix_sessid_get() . "'",
            ],
        ]);
    }
}

// ── 9. Подвал, групповые действия, контекстное меню ───────────────────────
$lAdmin->AddFooter([
    ['title' => 'Всего выбрано', 'value' => $rsData->SelectedRowsCount()],
    ['counter' => true, 'title' => 'Отмечено', 'value' => '0'],
]);

if ($right >= 'W') {
    $lAdmin->AddGroupActionTable([
        'delete'   => 'Удалить',
        'activate' => 'Активировать',
    ]);
}

$lAdmin->AddAdminContextMenu([
    [
        'TEXT'  => 'Добавить',
        'TITLE' => 'Новая запись',
        'LINK'  => $editUrl,
        'ICON'  => 'btn_new',
    ],
]);

$lAdmin->CheckListMode(); // обрабатывает экспорт в Excel и настройку колонок

// ── 10. Вывод ──────────────────────────────────────────────────────────────
$APPLICATION->SetTitle('Список записей');
require_once $_SERVER['DOCUMENT_ROOT'] . '/bitrix/modules/main/include/prolog_admin_after.php';
?>

<form name="form1" method="GET" action="<?= $APPLICATION->GetCurPage() ?>">
<?php
// Фильтр
$oFilter = new CAdminFilter($tableId . '_filter', [
    'ID',
    'Название',
    'Активность',
    'Дата создания',
]);
$oFilter->Begin();
?>
<tr>
    <td>ID:</td>
    <td><input type="text" name="find_id" size="20" value="<?= htmlspecialcharsbx($find_id) ?>"></td>
</tr>
<tr>
    <td>Название:</td>
    <td><input type="text" name="find_name" size="40" value="<?= htmlspecialcharsbx($find_name) ?>"></td>
</tr>
<tr>
    <td>Активность:</td>
    <td><?= SelectBoxFromArray('find_active', ['Y' => 'Да', 'N' => 'Нет'], $find_active, 'Все') ?></td>
</tr>
<tr>
    <td>Дата создания:</td>
    <td><?= CalendarPeriod('find_date_from', htmlspecialcharsbx($find_date_from), 'find_date_to', htmlspecialcharsbx($find_date_to), 'form1', 'Y') ?></td>
</tr>
<?php
$oFilter->Buttons(['table_id' => $tableId, 'url' => $APPLICATION->GetCurPage(), 'form' => 'form1']);
$oFilter->End();
?>
</form>

<?php
$lAdmin->DisplayList();

require_once $_SERVER['DOCUMENT_ROOT'] . '/bitrix/modules/main/include/epilog_admin.php';
?>
```

---

## Страница редактирования: CAdminTabControl (raw HTML)

Используй `CAdminTabControl` когда нужен полный контроль над HTML полей.

```php
<?php
require_once $_SERVER['DOCUMENT_ROOT'] . '/bitrix/modules/main/include/prolog_admin_before.php';

use Vendor\MyModule\MyTable;
use Bitrix\Main\Loader;

Loader::requireModule('my.module');
IncludeModuleLangFile(__FILE__);

$right = $APPLICATION->GetGroupRight('my.module');
if ($right === 'D') $APPLICATION->AuthForm('Доступ запрещён');

// ── Определить табы ────────────────────────────────────────────────────────
$aTabs = [
    ['DIV' => 'edit1', 'TAB' => 'Основное', 'ICON' => 'main_user_edit', 'TITLE' => 'Основные поля'],
    ['DIV' => 'edit2', 'TAB' => 'Дополнительно', 'ICON' => 'main_user_edit', 'TITLE' => 'Доп. настройки'],
];
$tabControl = new CAdminTabControl('tabControl', $aTabs);
$message = null;

// ── Сохранение ────────────────────────────────────────────────────────────
$ID = (int)($_REQUEST['ID'] ?? 0);

if (
    (!empty($_REQUEST['save']) || !empty($_REQUEST['apply']))
    && $_SERVER['REQUEST_METHOD'] === 'POST'
    && $right >= 'W'
    && check_bitrix_sessid()
) {
    $arFields = [
        'NAME'    => trim($_POST['NAME'] ?? ''),
        'PRICE'   => (float)($_POST['PRICE'] ?? 0),
        'ACTIVE'  => isset($_POST['ACTIVE']) ? 'Y' : 'N',
        'SORT'    => (int)($_POST['SORT'] ?? 500),
        'SECTION_ID' => (int)($_POST['SECTION_ID'] ?? 0),
    ];

    if (empty($arFields['NAME'])) {
        $message = new CAdminMessage('Название обязательно');
    } else {
        $r = $ID > 0
            ? MyTable::update($ID, $arFields)
            : MyTable::add($arFields);

        if ($r->isSuccess()) {
            $newId = $ID > 0 ? $ID : $r->getId();
            if (!empty($_REQUEST['save'])) {
                LocalRedirect('/bitrix/admin/mymodule_item_list.php?lang=' . LANGUAGE_ID);
            }
            LocalRedirect('/bitrix/admin/mymodule_item_edit.php?lang=' . LANGUAGE_ID . '&ID=' . $newId . '&' . $tabControl->ActiveTabParam());
        } else {
            $message = new CAdminMessage(implode(', ', $r->getErrorMessages()));
        }
    }
}

// ── Загрузить запись ───────────────────────────────────────────────────────
if ($ID > 0) {
    $res = MyTable::getById($ID)->fetch();
    if (!$res) {
        $message = new CAdminMessage("Запись #$ID не найдена");
        $ID = 0;
    }
    $APPLICATION->SetTitle("Редактирование записи #$ID");
} else {
    $res = ['NAME' => '', 'PRICE' => 0, 'ACTIVE' => 'Y', 'SORT' => 500, 'SECTION_ID' => 0];
    $APPLICATION->SetTitle('Новая запись');
}

// Если была ошибка POST — восстановить из формы
if (isset($bVarsFromForm) && $bVarsFromForm) {
    $res = array_intersect_key($_POST, $res);
}

require_once $_SERVER['DOCUMENT_ROOT'] . '/bitrix/modules/main/include/prolog_admin_after.php';

// ── Контекстное меню ──────────────────────────────────────────────────────
$aMenu = [
    ['TEXT' => 'К списку', 'LINK' => '/bitrix/admin/mymodule_item_list.php?lang=' . LANGUAGE_ID, 'ICON' => 'btn_list'],
];
if ($ID > 0 && $right >= 'W') {
    $aMenu[] = [
        'TEXT'   => 'Удалить',
        'LINK'   => "javascript:if(confirm('Удалить?')) window.location='/bitrix/admin/mymodule_item_list.php?action=delete&ID={$ID}&" . bitrix_sessid_get() . "'",
        'ICON'   => 'btn_delete',
    ];
}
(new CAdminContextMenu($aMenu))->Show();

if ($message) echo $message->Show();
?>

<form method="POST" action="<?= $APPLICATION->GetCurPage() ?>" name="post_form">
<?= bitrix_sessid_post() ?>
<input type="hidden" name="ID" value="<?= $ID ?>">
<input type="hidden" name="lang" value="<?= LANGUAGE_ID ?>">

<?php $tabControl->Begin(); ?>

<?php
// ── Таб 1: Основное ────────────────────────────────────────────────────────
$tabControl->BeginNextTab();
?>
<tr class="adm-detail-required-field">
    <td width="40%">Название:</td>
    <td><input type="text" name="NAME" size="50" maxlength="255" value="<?= htmlspecialcharsbx($res['NAME']) ?>"></td>
</tr>
<tr>
    <td>Цена:</td>
    <td><input type="text" name="PRICE" size="15" value="<?= htmlspecialcharsbx($res['PRICE']) ?>"></td>
</tr>
<tr>
    <td>Активность:</td>
    <td><input type="checkbox" name="ACTIVE" value="Y" <?= $res['ACTIVE'] === 'Y' ? 'checked' : '' ?>></td>
</tr>
<tr>
    <td>Сортировка:</td>
    <td><input type="text" name="SORT" size="5" value="<?= (int)$res['SORT'] ?>"></td>
</tr>

<?php
// ── Таб 2: Дополнительно ───────────────────────────────────────────────────
$tabControl->BeginNextTab();
?>
<tr>
    <td>Раздел ID:</td>
    <td><input type="text" name="SECTION_ID" size="10" value="<?= (int)$res['SECTION_ID'] ?>"></td>
</tr>

<?php
$tabControl->EndTab();
$tabControl->Buttons([
    'disabled' => $right < 'W',
    'back_url' => '/bitrix/admin/mymodule_item_list.php?lang=' . LANGUAGE_ID,
]);
$tabControl->End();
?>
</form>
<?php $tabControl->ShowWarnings('post_form', $message); ?>

<?php require_once $_SERVER['DOCUMENT_ROOT'] . '/bitrix/modules/main/include/epilog_admin.php'; ?>
```

---

## Страница редактирования: CAdminForm (высокоуровневый API)

`CAdminForm extends CAdminTabControl` добавляет удобные методы для стандартных полей. Используй вместо raw HTML когда структура полей стандартная.

```php
$aTabs = [['DIV' => 'edit1', 'TAB' => 'Основное', 'ICON' => 'main_user_edit', 'TITLE' => 'Поля']];
$tabControl = new CAdminForm('myform', $aTabs);

$tabControl->Begin(['FORM_ATTRIBUTES' => 'enctype="multipart/form-data"']);
$tabControl->BeginNextFormTab();

// Текстовое поле
// AddEditField($id, $label, $required, $arParams, $value)
$tabControl->AddEditField('NAME', 'Название', true, ['size' => 50, 'maxlength' => 255], $res['NAME']);

// Выпадающий список
// AddDropDownField($id, $label, $required, $arSelect, $value, $arParams)
$tabControl->AddDropDownField('ACTIVE', 'Активность', false, ['Y' => 'Да', 'N' => 'Нет'], $res['ACTIVE']);

// Текстовая область
// AddTextField($id, $label, $value, $arParams, $required)
$tabControl->AddTextField('DESCRIPTION', 'Описание', $res['DESCRIPTION'], ['rows' => 5, 'cols' => 60]);

// Чекбокс
// AddCheckBoxField($id, $label, $required, $value, $checked, $arParams)
$tabControl->AddCheckBoxField('IS_FEATURED', 'Рекомендуемый', false, 'Y', $res['IS_FEATURED'] === 'Y');

// Поле даты с календарём
// AddCalendarField($id, $label, $value, $required)
$tabControl->AddCalendarField('DATE_ACTIVE_FROM', 'Активен с', $res['DATE_ACTIVE_FROM']);

// Файл
// AddFileField($id, $label, $value, $arParams, $required)
$tabControl->AddFileField('PREVIEW_PICTURE', 'Превью', $res['PREVIEW_PICTURE']);

// Только просмотр (нет input)
// AddViewField($id, $label, $html, $required)
$tabControl->AddViewField('DATE_CREATE', 'Дата создания', htmlspecialcharsEx($res['DATE_CREATE']));

// Разделитель / заголовок секции
$tabControl->AddSection('sec1', 'Дополнительные поля');

$tabControl->Buttons([
    'disabled' => $right < 'W',
    'back_url'  => '/bitrix/admin/mymodule_item_list.php?lang=' . LANGUAGE_ID,
]);
$tabControl->End();
```

---

## Методы CAdminTabControl — быстрая таблица

| Метод | Описание |
|-------|----------|
| `Begin($arParams)` | Открывает `<form>` (для CAdminForm); у CAdminTabControl — нет формы, пиши HTML сам |
| `BeginNextTab()` | Переключиться на следующий таб (raw HTML) |
| `BeginNextFormTab()` | Переключиться на следующий таб (CAdminForm) |
| `EndTab()` | Закрыть текущий таб |
| `Buttons($arParams)` | Кнопки Сохранить/Применить/Отмена. `disabled` — отключить; `back_url` — куда после отмены |
| `End()` | Закрыть вкладочный блок |
| `ShowWarnings($formName, $message)` | Показать сообщения об ошибках (передать объект CAdminMessage) |
| `ActiveTabParam()` | URL-параметр для сохранения активного таба после redirect |

---

## Admin-меню модуля

Файл `local/modules/vendor.mymodule/admin/menu.php` — возвращает `$aMenu`.

```
local/modules/vendor.mymodule/
└── admin/
    └── menu.php    ← регистрируется автоматически при установке модуля
```

```php
<?php
// local/modules/vendor.mymodule/admin/menu.php
IncludeModuleLangFile(__FILE__);

$right = $APPLICATION->GetGroupRight('vendor.mymodule');
if ($right === 'D') return false; // скрыть меню если нет прав

$aMenu = [
    'parent_menu' => 'global_menu_services', // куда прицепить: global_menu_services | global_menu_store | ...
    'section'     => 'vendor_mymodule',       // уникальный ID секции
    'sort'        => 100,
    'module_id'   => 'vendor.mymodule',
    'text'        => GetMessage('MY_MODULE_MENU'),
    'title'       => GetMessage('MY_MODULE_MENU_TITLE'),
    'icon'        => 'main_menu_icon',          // CSS-класс иконки
    'page_icon'   => 'main_page_icon',
    'items_id'    => 'menu_vendor_mymodule',
    'items' => [
        [
            'text'     => GetMessage('MY_MODULE_ITEMS_LIST'),
            'url'      => 'mymodule_item_list.php?lang=' . LANGUAGE_ID,
            'title'    => GetMessage('MY_MODULE_ITEMS_LIST_TITLE'),
            'items_id' => 'menu_mymodule_items',
            'more_url' => ['mymodule_item_edit.php'], // страницы, при которых пункт остаётся активным
        ],
    ],
];

// Пункт настроек — только для W и выше
if ($right >= 'W') {
    $aMenu['items'][] = [
        'text'  => 'Настройки',
        'url'   => 'mymodule_settings.php?lang=' . LANGUAGE_ID,
        'title' => 'Настройки модуля',
    ];
}

return $aMenu;
?>
```

### Доступные `parent_menu` (куда вставлять)

| Значение | Раздел |
|----------|--------|
| `global_menu_content` | Контент |
| `global_menu_services` | Сервисы |
| `global_menu_store` | Интернет-магазин |
| `global_menu_crm` | CRM |
| `global_menu_marketing` | Маркетинг |
| `global_menu_settings` | Настройки |

---

## Права доступа модуля

```php
// install/index.php — регистрация прав в InstallDB
ModuleManager::registerModule($this->MODULE_ID);

// Получение уровня прав для текущего пользователя:
$right = $APPLICATION->GetGroupRight('my.module');
// Возможные значения: 'D' (нет доступа), 'R' (чтение), 'W' (запись), 'X' (полный)
// Сравнение: $right >= 'W' — есть права на запись
// 'D' < 'R' < 'W' < 'X' — ASCII-сравнение работает корректно

// Проверка в admin-странице:
if ($right === 'D') {
    $APPLICATION->AuthForm('Доступ запрещён'); // редирект на форму входа
}

// Разграничение в коде:
if ($right >= 'W') { /* редактирование */ }
if ($right === 'X') { /* полный доступ, например настройки */ }
```

---

## Кастомные типы пользовательских полей

Пользовательские поля (UF_*) для HL-блоков, профилей пользователей, инфоблоков.

### Новый D7 способ (BaseType)

```php
// local/modules/vendor.mymodule/lib/UserField/ColorType.php
namespace Vendor\MyModule\UserField;

use Bitrix\Main\UserField\Types\BaseType;

class ColorType extends BaseType
{
    // USER_TYPE_ID — уникальный идентификатор типа
    protected const USER_TYPE_ID = 'vendor_color';

    // Тип колонки в БД: varchar(255) | int | double | text | datetime | date | char
    public static function getDbColumnType(): string
    {
        return 'varchar(255)';
    }

    // Метаданные типа — что показывается в списке типов при создании поля
    protected static function getDescription(): array
    {
        return [
            'DESCRIPTION'     => 'Цвет (HEX)',
            'BASE_TYPE'       => 'string', // string | int | double | datetime | date | file | enum
        ];
    }

    // HTML для просмотра значения в публичной части и в списке
    public static function renderAdminListView(array $userField, ?array $additionalParameters): string
    {
        $value = $userField['VALUE'] ?? '';
        if (!$value) return '';
        $safe = htmlspecialcharsEx($value);
        return '<span style="display:inline-block;width:16px;height:16px;background:' . $safe . ';border:1px solid #ccc;vertical-align:middle;"></span> ' . $safe;
    }

    // HTML input для редактирования в форме (edit form)
    public static function renderEditForm(array $userField, ?array $additionalParameters): string
    {
        $fieldName  = htmlspecialcharsbx($userField['FIELD_NAME']);
        $value      = htmlspecialcharsbx($userField['VALUE'] ?? '');
        $attributes = $userField['MULTIPLE'] === 'Y' ? ' multiple' : '';

        return '<input type="text" name="' . $fieldName . '" value="' . $value . '" placeholder="#RRGGBB"' . $attributes . ' pattern="^#[0-9A-Fa-f]{6}$">';
    }

    // HTML input для инлайн-редактирования в списке
    public static function renderAdminListEdit(array $userField, ?array $additionalParameters)
    {
        return self::renderEditForm($userField, $additionalParameters);
    }

    // HTML для фильтра в списке
    public static function renderFilter(array $userField, ?array $additionalParameters): string
    {
        $fieldName = 'find_' . htmlspecialcharsbx($userField['FIELD_NAME']);
        $value     = htmlspecialcharsbx($additionalParameters['VALUE'] ?? '');
        return '<input type="text" name="' . $fieldName . '" value="' . $value . '" placeholder="#RRGGBB" size="15">';
    }

    // HTML настроек типа (в форме создания поля)
    public static function renderSettings($userField, ?array $additionalParameters, $varsFromForm): string
    {
        // Можно добавить специфичные настройки — например, палитра цветов
        return '';
    }

    // Валидация значения при сохранении
    public static function checkFields(array $userField, $value): array
    {
        $errors = [];
        if (!empty($value) && !preg_match('/^#[0-9A-Fa-f]{6}$/', $value)) {
            $errors[] = ['id' => $userField['FIELD_NAME'], 'text' => 'Некорректный формат HEX-цвета'];
        }
        return $errors; // пустой массив = нет ошибок
    }

    // Подготовка настроек (нормализация) при сохранении типа
    public static function prepareSettings($userField): array
    {
        return $userField['SETTINGS'] ?? [];
    }
}
```

### Регистрация через событие

```php
// local/modules/vendor.mymodule/include.php
use Bitrix\Main\EventManager;

EventManager::getInstance()->addEventHandler(
    'main',
    'OnUserTypeBuildList',
    ['\\Vendor\\MyModule\\UserField\\ColorType', 'getUserTypeDescription']
);
```

`getUserTypeDescription()` унаследован из `BaseType` и возвращает корректный массив. Движок вызывает это событие при первом обращении к типам — метод должен быть дёшевым.

### Легаси-способ (CUserTypeString-стиль, совместимость)

Если нужно поддерживать старые версии Bitrix или не использовать BaseType:

```php
class CUserTypeMyColor
{
    const USER_TYPE_ID = 'my_color';

    public static function getUserTypeDescription(): array
    {
        return [
            'USER_TYPE_ID' => self::USER_TYPE_ID,
            'CLASS_NAME'   => __CLASS__,
            'DESCRIPTION'  => 'Мой цвет',
            'BASE_TYPE'    => 'string',
        ];
    }

    public static function getDbColumnType(): string { return 'varchar(255)'; }

    // Метод вызывается CUserTypeManager
    public function getEditFormHtml(array $userField, array $additionalParameters): string
    {
        return '<input type="text" name="' . htmlspecialcharsbx($userField['FIELD_NAME']) . '" value="' . htmlspecialcharsbx($userField['VALUE'] ?? '') . '">';
    }

    public function getAdminListViewHtml(array $userField, array $additionalParameters): string
    {
        return htmlspecialcharsEx($userField['VALUE'] ?? '');
    }

    public function getAdminListEditHtml(array $userField, array $additionalParameters): string
    {
        return $this->getEditFormHtml($userField, $additionalParameters);
    }

    public function getFilterHtml(array $userField, array $additionalParameters): string
    {
        return '<input type="text" name="find_' . htmlspecialcharsbx($userField['FIELD_NAME']) . '" value="' . htmlspecialcharsbx($additionalParameters['VALUE'] ?? '') . '">';
    }

    public function getSettingsHtml(array $userField, array $additionalParameters, $varsFromForm): string { return ''; }
    public function prepareSettings(array $userField): array { return []; }
    public function checkFields(array $userField, $value): array { return []; }
}
```

### Создание поля UF_* программно

```php
// В InstallDB инсталлятора или миграции
global $USER_FIELD_MANAGER;

$hlId = /* ID вашего HL-блока */;

$userTypeManager = new CUserTypeEntity();
$userTypeManager->Add([
    'ENTITY_ID'          => 'HLBLOCK_' . $hlId,  // или 'USER', 'IBLOCK_ELEMENT_{ID}'
    'FIELD_NAME'         => 'UF_COLOR',
    'USER_TYPE_ID'       => 'vendor_color',        // ваш кастомный тип
    'SORT'               => 100,
    'MULTIPLE'           => 'N',
    'MANDATORY'          => 'N',
    'SHOW_FILTER'        => 'Y',
    'SHOW_IN_LIST'       => 'Y',
    'EDIT_IN_LIST'       => 'Y',
    'IS_SEARCHABLE'      => 'N',
    'SETTINGS'           => [],
    'EDIT_FORM_LABEL'    => ['ru' => 'Цвет', 'en' => 'Color'],
    'LIST_COLUMN_LABEL'  => ['ru' => 'Цвет', 'en' => 'Color'],
    'LIST_FILTER_LABEL'  => ['ru' => 'Цвет', 'en' => 'Color'],
]);
```

### Стандартные USER_TYPE_ID

| ID | Тип | DB column |
|----|-----|-----------|
| `string` | Строка | varchar(255) |
| `integer` | Целое | int |
| `double` | Число с дробью | double |
| `boolean` | Да/Нет | char(1) |
| `datetime` | Дата и время | datetime |
| `date` | Дата | date |
| `string_formatted` | Форматированный текст | text |
| `url` | Ссылка | varchar(2000) |
| `file` | Файл | int (FK → b_file) |
| `enumeration` | Список (enum) | int (FK → b_user_field_enum) |
| `iblock_element` | Элемент ИБ | int |
| `iblock_section` | Раздел ИБ | int |

---

## CAdminMessage — сообщения

```php
// Ошибка из строки
$message = new CAdminMessage('Произошла ошибка: неверный формат');

// Ошибка из исключения (GetException)
if ($e = $APPLICATION->GetException()) {
    $message = new CAdminMessage('Ошибка сохранения', $e);
}

// Вывод в HTML
echo $message->Show();

// Или через ShowWarnings (после tabControl->End())
$tabControl->ShowWarnings('post_form', $message);
```

---

## Структура admin-файлов в модуле

```
local/modules/vendor.mymodule/
├── admin/
│   └── menu.php                        ← пункт меню
├── install/
│   ├── admin/
│   │   ├── mymodule_item_list.php      ← симлинк/require к admin/
│   │   └── mymodule_item_edit.php      ← копируется в /bitrix/admin/ при установке
│   └── index.php                        ← InstallFiles() копирует файлы
└── lib/
    └── UserField/
        └── ColorType.php               ← кастомный UF-тип
```

Копирование admin-файлов при установке:

```php
// install/index.php
public function InstallFiles(): bool
{
    CopyDirFiles(
        __DIR__ . '/admin',
        $_SERVER['DOCUMENT_ROOT'] . '/bitrix/admin',
        true, // rewrite
        false // не рекурсивно
    );
    return true;
}

public function UnInstallFiles(): bool
{
    DeleteDirFiles(__DIR__ . '/admin', $_SERVER['DOCUMENT_ROOT'] . '/bitrix/admin');
    return true;
}
```

---

## Gotchas

- **Имена переменных фильтра глобальные** — `InitFilter(['find_id', 'find_name'])` создаёт `global $find_id, $find_name`. Без `global $$f` в своём коде они недоступны. Всегда делай `foreach ($arFilterFields as $f) global $$f;` после `InitFilter`.
- **`check_bitrix_sessid()` обязателен** перед любым изменением данных через POST. Без него — уязвимость CSRF. Всегда пиши `check_bitrix_sessid()` в условии сохранения.
- **`CAdminResult::NavStart()`** — вызывать до `AddHeaders` и цикла по строкам. Без вызова пагинация не работает.
- **`global $by, $order`** — эти глобальные переменные устанавливает `CAdminSorting`. Используй их в ORM `order` параметре после инициализации `CAdminSorting`.
- **`$row->AddField()` vs `$row->AddViewField()`** — `AddField(id, viewText, editValue)` добавляет и view, и edit (inline); `AddViewField(id, html)` — только view, не участвует в инлайн-редактировании.
- **`AddSelectField` / `AddInputField`** — добавляют только edit-вариант поля, без view. Нужен `AddField` или `AddViewField` для отображения.
- **Inline edit** — чтобы строка была редактируемой, вызови хотя бы один `Add*Field` с edit-вариантом и обработай `$lAdmin->EditAction()` и `$lAdmin->GetEditFields()`.
- **`CAdminForm` vs `CAdminTabControl`** — `CAdminForm` сам открывает буферизацию в конструкторе (`ob_start()`) и рендерит форму в `Show()`. Если используешь `CAdminTabControl` — пиши `<form>` сам.
- **`OnUserTypeBuildList`** вызывается при каждом обращении к типам через `CUserTypeManager::GetUserType()`. Handler должен только возвращать описание, без запросов в БД.
- **`CUserTypeEntity::Add`** vs `CUserTypeManager`** — создание поля через `CUserTypeEntity`, чтение значений через `CUserTypeManager`. Это разные классы.
- **Файлы в `/bitrix/admin/`** — именно туда копируются страницы при установке модуля. Без копирования `menu.php` будет ссылаться на несуществующие URL. `InstallFiles()` / `UnInstallFiles()` обязательны.
- **`htmlspecialcharsbx` vs `htmlspecialcharsEx`** — первая для атрибутов (value="..."), вторая для HTML-контента. Обе защищают от XSS. Не используй прямой вывод данных из БД без экранирования.
