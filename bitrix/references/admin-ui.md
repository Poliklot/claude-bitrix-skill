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
- Update-safe стратегия кастомизации админки
- События админки: `OnAdmin*`, `OnBuildGlobalMenu`
- Сохранение состояния между обновлениями
- Чеклист перед обновлением и релизом
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


## Update-safe стратегия кастомизации админки

Главное правило: **не править ядро и существующие страницы ядра ради кастомизации админки**. В Bitrix административный UI исторически расширяется через собственные admin-страницы, `CAdmin*`-классы, модульное меню и события главного модуля. Форумные сниппеты полезны как навигация по старым сценариям, но финальное решение нужно сверять с локальным core: какой класс вызывает событие, какие параметры реально передаются, где хранится состояние и как страница подключает prolog/epilog.

### Приоритет источников: core → docs/forums → core

1. **Сначала core проекта.** Открой реальные файлы установленного проекта: `www/bitrix/modules/main/interface/*`, `www/bitrix/modules/main/include/prolog_admin_*.php`, целевую admin-страницу модуля (`www/bitrix/modules/<module>/admin/*.php`) и её wrapper в `/bitrix/admin/*.php`.
2. **Потом официальные docs и форумы.** Docs дают имена событий и базовые сигнатуры; форумы часто показывают рабочие edge cases (`OnAdminTabControlBegin`, `admin_header.php`, кастомные формы инфоблоков), но в них много устаревших или слишком жёстких решений.
3. **Затем снова core.** Перед внедрением проверь в текущем ядре точное место вызова события, имена `$table_id`, `DIV`, `form name`, `REQUEST`-параметров, права и `sessid`.

Полезные core-grep команды из корня Bitrix-проекта:

```bash
# Где ядро вызывает ключевые события админки
rg "OnAdminListDisplay|OnAdminTabControlBegin|OnAdminContextMenuShow|OnBuildGlobalMenu" www/bitrix/modules/main www/bitrix/modules/*/admin

# Как устроены CAdmin* классы текущего main
sed -n '1,220p' www/bitrix/modules/main/interface/admin_list.php
sed -n '1,220p' www/bitrix/modules/main/interface/admin_tabcontrol.php
sed -n '1,220p' www/bitrix/modules/main/interface/admin_form.php
sed -n '1,220p' www/bitrix/modules/main/interface/admin_lib.php

# Какие admin-страницы реально есть и какие wrapper-файлы торчат в /bitrix/admin
find www/bitrix/modules -maxdepth 5 -path '*/admin/*.php' -type f | sort | head -200
find www/bitrix/admin -maxdepth 1 -type f | sort | head -200

# Где проект уже расширяет админку
rg "OnAdmin|OnBuildGlobalMenu|CAdminList|CAdminTabControl|CAdminForm|admin_header|admin_footer" local bitrix/php_interface -g '*.php'
```

### Карта решений: какой способ выбрать

| Задача | Правильный первый путь | Когда подходит | Риски |
|---|---|---|---|
| Сделать свой backoffice-раздел | свой модуль в `local/modules/vendor.module`, wrapper в `/bitrix/admin/vendor_module_*.php`, логика в `local/modules/vendor.module/admin/` | новая сущность, интеграция, отчёт, импорт, служебная таблица | не коллизить с именами core; не класть бизнес-логику в wrapper |
| Добавить пункт меню | `admin/menu.php` своего модуля; для cross-cutting — `OnBuildGlobalMenu` | собственный раздел или изменение уже собранного меню | права и `more_url`; динамическое меню не должно делать тяжёлые запросы |
| Добавить кнопку в контекстной панели | `OnAdminContextMenuShow` или `$lAdmin->AddAdminContextMenu()` на своей странице | кнопка сверху страницы | событие получает только массив кнопок, не объект формы/списка |
| Добавить массовое действие в список | `OnAdminListDisplay` + отдельная обработка POST до вывода | legacy `CAdminList` страницы | UI-часть и обработка action должны быть разделены; нужен `check_bitrix_sessid()` |
| Добавить вкладку/поля в форму | `OnAdminTabControlBegin` или штатные настройки формы конкретного модуля | legacy `CAdminTabControl` формы | `CONTENT` должен быть совместим с HTML таблицы формы; не ломать стандартные поля |
| Настроить видимость полей элемента инфоблока для редакторов | сначала штатная “шестерёнка” формы / настройки инфоблока; код — только если штатного слоя мало | UX формы, порядок полей, предустановки | per-user/per-iblock state; нельзя сбрасывать настройки всем без миграции |
| Полностью заменить форму инфоблока | “Файл с формой редактирования элемента” только как крайний вариант | нужен радикально другой UX | высокая цена сопровождения: приходится повторять куски core формы |
| Добавить свой UF-тип | `OnUserTypeBuildList` + класс типа в модуле | повторяемое поле для HL/USER/IBLOCK_ELEMENT | обработчик должен быть лёгким; не делать запросы в БД при регистрации типа |
| Modern `main.ui.grid` | route из `grid-admin-modern.md` после проверки `Bitrix\Main\Grid\Grid`, `Settings`, `Options`, `ComponentParams` в текущем core | новые D7/grid страницы | API чувствителен к версии; не переносить примеры из другого core без проверки |

Не подменяй legacy и modern слои по памяти: если страница построена на `CAdminList`, расширяй её как `CAdminList`; если на `bitrix:main.ui.grid`, сначала сверяй `Bitrix\Main\Grid` API текущего ядра.

### Что безопасно переживает обновления

1. **Код в `/local`**: `local/modules/vendor.module`, `local/php_interface/init.php`, `local/components`, `local/templates`. Это основной слой проектной кастомизации.
2. **Минимальные wrapper-файлы в `/bitrix/admin` с уникальными именами**: например `vendor_module_items.php`, которые только подключают файл из `/local/modules/vendor.module/admin/`. Они не являются правкой существующего core-файла и обычно не затрагиваются обновлениями, если имя не конфликтует с ядром.
3. **Persistent event registration** в `b_module_to_module` через `registerEventHandlerCompatible()` в инсталляторе модуля. Это переживает перезапуск и не зависит от того, подключился ли `init.php` раньше целевой страницы.
4. **Настройки модуля и миграции**: `Option`, собственные таблицы, HL/UF через install/migration слой. Все изменения должны быть идемпотентными.
5. **Пользовательские настройки UI**: сохранённые колонки, сортировки, фильтры, active tab, настройки форм. Они привязаны к стабильным ID (`table_id`, `grid_id`, `tabControl id`, `form id`, `filter id`).

Что ломается при обновлениях или переносах:

- правка файлов `www/bitrix/modules/*` и существующих `/bitrix/admin/*.php`;
- копирование больших кусков core admin-страницы в проект без слоя сравнения с новой версией;
- CSS/JS “спрятать вкладку/кнопку” через глобальный `admin_header.php` вместо server-side события;
- изменение `table_id`/`grid_id` после релиза без миграции состояния;
- обработчики, которые исполняются на каждой admin-странице и не проверяют `GetCurPage()`/модуль/права;
- прямой SQL в таблицы UI-настроек и core-сущностей без подтверждения контракта текущего ядра.

### Базовая структура update-safe admin-модуля

```text
local/modules/vendor.mymodule/
├── include.php
├── install/
│   ├── index.php
│   ├── version.php
│   └── admin/
│       ├── vendor_mymodule_items.php      ← tiny wrapper, копируется в /bitrix/admin
│       └── vendor_mymodule_item_edit.php  ← tiny wrapper, копируется в /bitrix/admin
├── admin/
│   ├── menu.php                           ← меню модуля
│   ├── items.php                          ← реальная страница списка
│   └── item_edit.php                      ← реальная форма
└── lib/
    ├── Admin/EventHandler.php
    ├── Access/Permission.php
    └── Entity/ItemTable.php
```

Wrapper должен быть максимально тупым:

```php
<?php
// /bitrix/admin/vendor_mymodule_items.php
require $_SERVER['DOCUMENT_ROOT'] . '/local/modules/vendor.mymodule/admin/items.php';
```

Реальная страница живёт в `/local/modules/.../admin/items.php`, где уже подключаются admin prolog/epilog, модуль, права и UI. Так обновление ядра не перезаписывает вашу логику, а code review видит весь backoffice-код в модуле.

---

## События админки: `OnAdmin*`, `OnBuildGlobalMenu`

Официальный список событий main подтверждает, что административный слой расширяется событиями:

- `OnAdminContextMenuShow` — вызывается при `CAdminContextMenu::Show()`, параметр `array &$items`.
- `OnAdminListDisplay` — вызывается при `CAdminList::Display()`, параметр `object &$list`.
- `OnAdminTabControlBegin` — вызывается при `CAdminTabControl::Begin()`, параметр `&$form`.
- `OnBuildGlobalMenu` — вызывается при построении меню административной части, параметры `&$aGlobalMenu`, `&$aModuleMenu`.

Для этих событий используй **legacy-compatible регистрацию**, потому что обработчики получают параметры по-отдельности и часто по ссылке.

### Runtime vs persistent регистрация

| Способ | Где писать | Когда использовать |
|---|---|---|
| `EventManager::getInstance()->addEventHandlerCompatible(...)` | `local/php_interface/init.php` или `include.php` модуля | быстрый проектный glue-code, который должен работать сразу |
| `EventManager::getInstance()->registerEventHandlerCompatible(...)` | `InstallDB()` модуля | продуктовый модуль, переносимый между окружениями |
| `EventManager::getInstance()->unRegisterEventHandler(...)` / compatible-вариант по доступности core | `UnInstallDB()` | чистое удаление persistent handler |

Минимальный persistent-паттерн:

```php
// local/modules/vendor.mymodule/install/index.php
use Bitrix\Main\EventManager;
use Bitrix\Main\ModuleManager;

class vendor_mymodule extends CModule
{
    public $MODULE_ID = 'vendor.mymodule';

    public function InstallDB(): bool
    {
        ModuleManager::registerModule($this->MODULE_ID);

        $em = EventManager::getInstance();
        $em->registerEventHandlerCompatible(
            'main',
            'OnAdminListDisplay',
            $this->MODULE_ID,
            \Vendor\MyModule\Admin\EventHandler::class,
            'onAdminListDisplay'
        );
        $em->registerEventHandlerCompatible(
            'main',
            'OnAdminTabControlBegin',
            $this->MODULE_ID,
            \Vendor\MyModule\Admin\EventHandler::class,
            'onAdminTabControlBegin'
        );
        $em->registerEventHandlerCompatible(
            'main',
            'OnAdminContextMenuShow',
            $this->MODULE_ID,
            \Vendor\MyModule\Admin\EventHandler::class,
            'onAdminContextMenuShow'
        );
        $em->registerEventHandlerCompatible(
            'main',
            'OnBuildGlobalMenu',
            $this->MODULE_ID,
            \Vendor\MyModule\Admin\EventHandler::class,
            'onBuildGlobalMenu'
        );

        return true;
    }

    public function UnInstallDB(): bool
    {
        $em = EventManager::getInstance();
        $handlers = [
            'OnAdminListDisplay' => 'onAdminListDisplay',
            'OnAdminTabControlBegin' => 'onAdminTabControlBegin',
            'OnAdminContextMenuShow' => 'onAdminContextMenuShow',
            'OnBuildGlobalMenu' => 'onBuildGlobalMenu',
        ];
        foreach ($handlers as $eventName => $method) {
            $em->unRegisterEventHandler(
                'main',
                $eventName,
                $this->MODULE_ID,
                \Vendor\MyModule\Admin\EventHandler::class,
                $method
            );
        }

        ModuleManager::unRegisterModule($this->MODULE_ID);
        return true;
    }
}
```

> В `UnInstallDB()` не копируй этот пример вслепую: в старых core имя метода снятия compatible-регистрации и точная сигнатура могут отличаться. Перед релизом проверь `www/bitrix/modules/main/lib/eventmanager.php`. Главное требование — инсталлятор должен быть идемпотентным: повторная установка не должна плодить дубли обработчиков.

Лучше держать обработчики в классе:

```php
// local/modules/vendor.mymodule/lib/Admin/EventHandler.php
namespace Vendor\MyModule\Admin;

use Bitrix\Main\Application;
use Bitrix\Main\Context;
use Bitrix\Main\Loader;

final class EventHandler
{
    private const MODULE_ID = 'vendor.mymodule';

    private static function isAdminPage(string $page): bool
    {
        global $APPLICATION;
        return $APPLICATION->GetCurPage() === $page || $APPLICATION->GetCurPage(true) === $page;
    }

    private static function canWrite(): bool
    {
        global $APPLICATION;
        return $APPLICATION->GetGroupRight(self::MODULE_ID) >= 'W';
    }
}
```

### `OnAdminListDisplay`: добавить массовое действие и действие строки

Событие изменяет объект `CAdminList` **в момент вывода**. Поэтому:

- в самом `OnAdminListDisplay` можно добавить action в `$list->arActions` или пройти по rows, если они уже доступны в текущем core;
- реальную обработку POST лучше делать раньше (`OnBeforeProlog`, собственная admin-страница или контроллер), до HTML-вывода;
- обязательно проверять страницу, `table_id`, права, `check_bitrix_sessid()` и ID.

```php
namespace Vendor\MyModule\Admin;

use Bitrix\Main\EventManager;
use Bitrix\Main\Loader;
use Vendor\MyModule\Entity\ItemTable;

final class EventHandler
{
    private const MODULE_ID = 'vendor.mymodule';
    private const LIST_PAGE = '/bitrix/admin/vendor_mymodule_items.php';
    private const TABLE_ID = 'tbl_vendor_mymodule_items';

    public static function onAdminListDisplay(\CAdminList &$list): void
    {
        global $APPLICATION;

        if ($APPLICATION->GetCurPage() !== self::LIST_PAGE || $list->table_id !== self::TABLE_ID) {
            return;
        }
        if ($APPLICATION->GetGroupRight(self::MODULE_ID) < 'W') {
            return;
        }

        // UI: добавить пункт в выпадающий список массовых действий.
        $list->arActions['vendor_archive'] = 'Архивировать';
    }

    public static function onBeforePrologProcessAdminAction(): void
    {
        global $APPLICATION;

        if ($APPLICATION->GetCurPage() !== self::LIST_PAGE) {
            return;
        }
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            return;
        }
        if (($_POST['action'] ?? '') !== 'vendor_archive') {
            return;
        }
        if ($APPLICATION->GetGroupRight(self::MODULE_ID) < 'W' || !check_bitrix_sessid()) {
            return;
        }
        if (!Loader::includeModule(self::MODULE_ID)) {
            return;
        }

        $ids = array_map('intval', (array)($_POST['ID'] ?? []));
        $ids = array_filter($ids);

        foreach ($ids as $id) {
            ItemTable::update($id, ['ARCHIVED' => 'Y']);
        }
    }
}

// runtime-регистрация, если это project glue-code:
EventManager::getInstance()->addEventHandlerCompatible(
    'main',
    'OnAdminListDisplay',
    [EventHandler::class, 'onAdminListDisplay']
);
EventManager::getInstance()->addEventHandlerCompatible(
    'main',
    'OnBeforeProlog',
    [EventHandler::class, 'onBeforePrologProcessAdminAction']
);
```

Если список твой, чаще проще и надёжнее не через событие, а прямо на странице:

```php
$lAdmin->AddGroupActionTable([
    'delete' => 'Удалить',
    'vendor_archive' => 'Архивировать',
]);
```

Событие нужно, когда расширяешь **чужую** legacy-страницу или хочешь вынести extension point в отдельный модуль.

### `OnAdminTabControlBegin`: добавить вкладку в существующую форму

Событие вызывается при `CAdminTabControl::Begin()` и даёт ссылку на объект формы. В docs подтверждён доступ к `$form->tabs`. Используй его точечно:

```php
final class EventHandler
{
    private const MODULE_ID = 'vendor.mymodule';

    public static function onAdminTabControlBegin(\CAdminTabControl &$form): void
    {
        global $APPLICATION;

        if ($APPLICATION->GetCurPage() !== '/bitrix/admin/iblock_element_edit.php') {
            return;
        }
        if ((int)($_REQUEST['IBLOCK_ID'] ?? 0) !== 12) {
            return;
        }
        if ($APPLICATION->GetGroupRight(self::MODULE_ID) < 'R') {
            return;
        }

        $elementId = (int)($_REQUEST['ID'] ?? 0);
        $safeValue = htmlspecialcharsbx(self::loadAdminComment($elementId));

        $form->tabs[] = [
            'DIV' => 'vendor_mymodule_extra',
            'TAB' => 'Дополнительно',
            'ICON' => 'main_user_edit',
            'TITLE' => 'Проектные поля',
            'CONTENT' => '
                <tr>
                    <td width="40%">Комментарий модератора:</td>
                    <td><input type="text" name="VENDOR_ADMIN_COMMENT" value="' . $safeValue . '" size="60"></td>
                </tr>',
        ];
    }

    private static function loadAdminComment(int $elementId): string
    {
        // Только быстрый read. Тяжёлые вычисления вынеси заранее или кешируй.
        return '';
    }
}
```

Сохранение поля делай отдельным обработчиком (`OnBeforeIBlockElementUpdate`, `OnAfterIBlockElementUpdate`, собственная обработка формы или файл “перед сохранением” для инфоблока), а не внутри `OnAdminTabControlBegin`: это событие про UI-render, не про mutation.

Удалять вкладки через `unset($form->tabs[$key])` можно только после проверки:

- точной страницы;
- `IBLOCK_ID`/модуля/контекста;
- `DIV` вкладки в текущем core;
- прав текущего пользователя;
- отсутствия side effects у модуля, который эту вкладку добавил.

Форумные решения часто предлагают `admin_header.php` + CSS `display:none`. Это годится только как временная диагностика. Production-решение — server-side событие или штатная настройка формы.

### `OnAdminContextMenuShow`: добавить кнопку на панель

Событие получает массив кнопок `&$items`, а не список и не форму:

```php
final class EventHandler
{
    public static function onAdminContextMenuShow(array &$items): void
    {
        global $APPLICATION;

        if ($APPLICATION->GetCurPage(true) !== '/bitrix/admin/index.php') {
            return;
        }
        if ($APPLICATION->GetGroupRight('vendor.mymodule') < 'R') {
            return;
        }

        $items[] = [
            'TEXT' => 'Отчёт интеграции',
            'TITLE' => 'Открыть служебный отчёт интеграции',
            'LINK' => 'vendor_mymodule_report.php?lang=' . LANGUAGE_ID,
            'ICON' => 'btn_view',
        ];
    }
}
```

Для своей страницы обычно достаточно `$lAdmin->AddAdminContextMenu(...)` или `new CAdminContextMenu($aMenu)->Show()`. Событие оставляй для расширения чужих страниц.

### `OnBuildGlobalMenu`: меню и разделы админки

Если у модуля есть `admin/menu.php`, сначала используй его: это штатный и читаемый путь. `OnBuildGlobalMenu` нужен, когда пункт зависит от другого модуля, от проекта, от динамической структуры или когда нужно модифицировать уже собранное меню.

```php
final class EventHandler
{
    public static function onBuildGlobalMenu(array &$aGlobalMenu, array &$aModuleMenu): void
    {
        global $APPLICATION;

        if ($APPLICATION->GetGroupRight('vendor.mymodule') === 'D') {
            return;
        }

        $aModuleMenu[] = [
            'parent_menu' => 'global_menu_services',
            'section' => 'vendor_mymodule',
            'sort' => 250,
            'module_id' => 'vendor.mymodule',
            'text' => 'Проектный backoffice',
            'title' => 'Проектный backoffice',
            'url' => 'vendor_mymodule_items.php?lang=' . LANGUAGE_ID,
            'icon' => 'main_menu_icon',
            'page_icon' => 'main_page_icon',
            'items_id' => 'menu_vendor_mymodule',
            'more_url' => [
                'vendor_mymodule_items.php',
                'vendor_mymodule_item_edit.php',
            ],
            'items' => [],
        ];
    }
}
```

Не делай в `OnBuildGlobalMenu` тяжёлую аналитику, внешние HTTP-запросы или длинные SQL: меню строится часто, и плохой обработчик замедлит всю админку.

---

## Сохранение состояния между обновлениями

В админке есть несколько разных “состояний”. Их нельзя смешивать.

| Тип состояния | Где возникает | Что ломает его | Как сохранить |
|---|---|---|---|
| Код кастомизации | `/local/modules`, `local/php_interface`, wrapper в `/bitrix/admin` | правка core, конфликт имён, копипаст core-страницы | хранить логику в `/local`, wrapper делать минимальным, имена префиксовать vendor/module |
| Состояние списка | `CAdminList`, `CAdminSorting`, `CGridOptions`, modern `main.ui.grid` | смена `table_id`/`grid_id`, переименование колонок без алиасов | стабильные ID, добавлять колонки эволюционно, старые ID не переиспользовать под другой смысл |
| Состояние фильтра | `CAdminFilter`, `main.ui.filter`, GET/session/user options | смена имён `find_*`, `filter_id`, типов полей | не переименовывать без migration path; новые поля добавлять как новые `find_*` |
| Активная вкладка формы | `CAdminTabControl::ActiveTabParam()` | смена id tab control или `DIV` вкладки | стабильный id `$tabControl = new CAdminTabControl('...', ...)`, стабильные `DIV` |
| Настройки формы инфоблока | “шестерёнка”, настройки типа/инфоблока, custom form files | массовый reset user options, замена формы | сначала штатная настройка, затем точечная миграция; не перетирать per-user без согласования |
| Настройки модуля | `Option`, собственные таблицы, HL/UF | неидемпотентный install/update, raw SQL без проверки | versioned migrations/update steps, backup, rollback plan |

### Стабильные идентификаторы

Для своей страницы зафиксируй ID как контракт:

```php
final class AdminIds
{
    public const ITEMS_TABLE = 'tbl_vendor_mymodule_items';
    public const ITEMS_FILTER = 'tbl_vendor_mymodule_items_filter';
    public const ITEM_EDIT_TABS = 'vendor_mymodule_item_edit_tabs';
    public const MODERN_GRID = 'vendor_mymodule_items_grid';
}
```

Используй их везде:

```php
$oSort = new CAdminSorting(AdminIds::ITEMS_TABLE, 'ID', 'desc');
$lAdmin = new CAdminList(AdminIds::ITEMS_TABLE, $oSort);
$oFilter = new CAdminFilter(AdminIds::ITEMS_FILTER, ['ID', 'Название']);
$tabControl = new CAdminTabControl(AdminIds::ITEM_EDIT_TABS, $aTabs);
```

Нельзя после релиза “красиво переименовать” `tbl_vendor_mymodule_items` в `tbl_vendor_items`: пользователи потеряют сохранённые колонки, сортировки, размеры страниц и фильтры. Если переименование неизбежно, оформи это как миграцию состояния после проверки того, где текущий core хранит user options.

### Колонки и фильтры: эволюция без сброса

- Добавлять новую колонку — безопасно, если `id` новый и не конфликтует.
- Менять `content`/label — обычно безопасно: ID остаётся прежним.
- Менять смысл существующего `id` — опасно: сохранённые фильтры/сортировки начнут работать иначе.
- Удалять колонку — лучше через deprecation: сначала оставить hidden/не default, затем убрать после релиза и smoke.
- Для фильтров имена `find_*` считать публичным контрактом страницы.

### Обновления ядра и кастомные страницы

Перед обновлением Bitrix или релизом модуля проверь:

```bash
# Не трогали ли core/admin файлы напрямую
git diff -- www/bitrix/modules www/bitrix/admin bitrix/modules bitrix/admin

# Нет ли проектных правок в опасных admin_header/admin_footer
rg "admin_header|admin_footer|display:\s*none|OnAdmin" local bitrix/php_interface -g '*.php' -g '*.css' -g '*.js'

# Стабильны ли идентификаторы списков/форм
rg "new CAdminList|new CAdminSorting|new CAdminFilter|new CAdminTabControl|GRID_ID|grid_id|table_id" local bitrix/php_interface -g '*.php'
```

Если в проекте нет git на production, делай read-only snapshot: список изменённых файлов, checksums своих wrappers и `rg` по `OnAdmin*`. Не начинай обновление, пока не понятно, какие файлы в `/bitrix/admin` являются custom wrapper, а какие принадлежат ядру.

---

## Чеклист перед изменением админки

1. **Контекст**: это своя страница, существующая legacy `CAdmin*` страница или modern `main.ui.grid`?
2. **Модуль**: подтверждён ли модуль через `Loader::includeModule(...)` и наличие `www/bitrix/modules/<module>`?
3. **Права**: какой уровень нужен — `R`, `W`, `X`; где проверяется `$APPLICATION->GetGroupRight(...)`?
4. **CSRF**: все POST/GET mutation actions проверяют `check_bitrix_sessid()` или `bitrix_sessid_get()`?
5. **Состояние UI**: зафиксированы ли `table_id`, `filter_id`, `grid_id`, `tabControl id`, `DIV` вкладок?
6. **Место кода**: логика в `/local/modules`, а не в core; wrapper минимальный; имена файлов префиксованы vendor/module.
7. **Событие**: handler ограничен страницей, table/form id, `IBLOCK_ID` или module context; не исполняется на всей админке без причины.
8. **Производительность**: обработчик меню/табов/списка не делает тяжёлые запросы на каждом render.
9. **Экранирование**: весь HTML из БД/REQUEST проходит `htmlspecialcharsbx()`/`htmlspecialcharsEx()`.
10. **Совместимость**: если пример взят с форума, он перепроверен по текущему core и переписан в `/local`/module style.
11. **Rollback**: есть способ отключить handler, удалить wrapper, вернуть option/migration.
12. **Smoke**: проверены list view, filter apply/reset, sort, pagination, inline edit, group action, edit save/apply/cancel, права R/W/D, session expiry.

### Smoke-матрица для admin UI

| Сценарий | Что проверить |
|---|---|
| Пользователь без доступа | пункт меню скрыт или `AuthForm('Доступ запрещён')`; прямой URL не отдаёт данные |
| Пользователь `R` | видит список/форму read-only; кнопки save/delete/group action disabled/hidden |
| Пользователь `W` | может сохранить, применить, удалить, выполнить group action; есть `sessid` |
| Фильтр | apply/reset, пустые значения, спецсимволы, дата from/to, сохранение между переходами |
| Сортировка/пагинация | стабильный `order`, нет дублей/пропусков на страницах, page size сохраняется |
| Inline edit | валидные значения сохраняются, ошибки через `AddUpdateError`, XSS не появляется |
| Group action | `selected` и “для всех отфильтрованных” не трогают лишнее; ошибки через `AddGroupError` |
| Форма | save/apply/back, active tab после apply, обязательные поля, ошибка POST восстанавливает значения |
| Обновление | после обновления ядра wrapper на месте, handlers зарегистрированы один раз, UI state не сброшен |

### Источники для перепроверки

- Official docs: [`OnAdminListDisplay`](https://dev.1c-bitrix.ru/api_help/main/events/onadminlistdisplay.php), [`OnAdminTabControlBegin`](https://dev.1c-bitrix.ru/api_help/main/events/onadmintabcontrolbegin.php), [`OnAdminContextMenuShow`](https://dev.1c-bitrix.ru/api_help/main/events/onadmincontextmenushow.php), [`OnBuildGlobalMenu`](https://dev.1c-bitrix.ru/api_help/main/events/onbuildglobalmenu.php).
- Official docs: [`CAdminList`](https://dev.1c-bitrix.ru/api_help/main/general/admin.section/classes/cadminlist/index.php), [`CAdminTabControl`](https://dev.1c-bitrix.ru/api_help/main/general/admin.section/classes/cadmintabcontrol/index.php), [`CAdminTabControl::Buttons`](https://dev.1c-bitrix.ru/api_help/main/general/admin.section/classes/cadmintabcontrol/buttons.php), [`CAdminTabControl::ActiveTabParam`](https://dev.1c-bitrix.ru/api_help/main/general/admin.section/classes/cadmintabcontrol/activetabparam.php).
- Official learning: [размещение модуля в административном меню](https://dev.1c-bitrix.ru/learning/course/index.php?COURSE_ID=101&LESSON_ID=3434), [пользовательские формы редактирования элементов](https://dev.1c-bitrix.ru/learning/course/index.php?COURSE_ID=43&LESSON_ID=5258), [настройка форм элементов и разделов](https://dev.1c-bitrix.ru/learning/course/?COURSE_ID=34&LESSON_ID=1883&LESSON_PATH=3905.4477.9921.1883).
- Forum triangulation: темы про удаление вкладки “Реклама” и подключение JS в админку показывают типичные соблазны (`admin_header.php`, CSS hide, правка `/bitrix/admin/file.php`) и более правильный маршрут через `OnAdminTabControlBegin`/`OnAdmin*`. Используй их только как подсказку, затем снова проверяй core.

## Gotchas

- **Имена переменных фильтра глобальные** — `InitFilter(['find_id', 'find_name'])` создаёт `global $find_id, $find_name`. Без `global $$f` в своём коде они недоступны. Всегда делай `foreach ($arFilterFields as $f) global $$f;` после `InitFilter`.
- **`check_bitrix_sessid()` обязателен** перед любым изменением данных через POST. Без него — уязвимость CSRF. Всегда пиши `check_bitrix_sessid()` в условии сохранения.
- **`CAdminResult::NavStart()`** — вызывать до `AddHeaders` и цикла по строкам. Без вызова пагинация не работает. Для `PAGEN_N`/`SIZEN_N`, session page size и modern `PageNavigation` смотри `pagination.md`.
- **`global $by, $order`** — эти глобальные переменные устанавливает `CAdminSorting`. Используй их в ORM `order` параметре после инициализации `CAdminSorting`.
- **`$row->AddField()` vs `$row->AddViewField()`** — `AddField(id, viewText, editValue)` добавляет и view, и edit (inline); `AddViewField(id, html)` — только view, не участвует в инлайн-редактировании.
- **`AddSelectField` / `AddInputField`** — добавляют только edit-вариант поля, без view. Нужен `AddField` или `AddViewField` для отображения.
- **Inline edit** — чтобы строка была редактируемой, вызови хотя бы один `Add*Field` с edit-вариантом и обработай `$lAdmin->EditAction()` и `$lAdmin->GetEditFields()`.
- **`CAdminForm` vs `CAdminTabControl`** — `CAdminForm` сам открывает буферизацию в конструкторе (`ob_start()`) и рендерит форму в `Show()`. Если используешь `CAdminTabControl` — пиши `<form>` сам.
- **`OnUserTypeBuildList`** вызывается при каждом обращении к типам через `CUserTypeManager::GetUserType()`. Handler должен только возвращать описание, без запросов в БД.
- **`CUserTypeEntity::Add` vs `CUserTypeManager`** — создание поля через `CUserTypeEntity`, чтение значений через `CUserTypeManager`. Это разные классы.
- **Файлы в `/bitrix/admin/`** — именно туда копируются страницы при установке модуля. Без копирования `menu.php` будет ссылаться на несуществующие URL. `InstallFiles()` / `UnInstallFiles()` обязательны.
- **`htmlspecialcharsbx` vs `htmlspecialcharsEx`** — первая для атрибутов (value="..."), вторая для HTML-контента. Обе защищают от XSS. Не используй прямой вывод данных из БД без экранирования.
