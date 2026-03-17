# Bitrix Modern Grid UI — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с современным Grid-интерфейсом в админке: `Bitrix\Main\Grid\Grid`, `Grid\Settings`, `Grid\Options`, `Grid\Component\ComponentParams`, компонент `bitrix:main.ui.grid`.

## Содержание
- Архитектура: Grid vs legacy CAdminList
- Settings и Options
- Полный паттерн: processRequest → getOrmFilter → getOrmParams → setRawRows → IncludeComponent
- Колонки: определение, типы, сортировка
- Фильтр: интеграция с Bitrix\Main\Filter\Filter
- Пагинация
- Панель действий (Panel)
- Экспорт
- Gotchas

---

## Архитектура

`Grid` — объектная замена legacy `CAdminList`. Работает с компонентом `bitrix:main.ui.grid`.

**Ключевое отличие от CAdminList:**
- Grid принимает `\Traversable` из ORM (`getList()`) напрямую через `setRawRows()`
- Фильтр ORM строится через `getOrmFilter()` — возвращает массив для `DataManager::getList(['filter' => ...])`
- Параметры запроса (order, limit, offset) строятся через `getOrmParams()`
- Настройки колонок, порядок, видимость хранятся в `Options` (в сессии/опциях)

---

## Settings и Options

```php
use Bitrix\Main\Grid\Settings;
use Bitrix\Main\Grid\Options;

// Settings — конфигурация экземпляра грида
$settings = new Settings([
    'ID' => 'my_module_list', // уникальный идентификатор грида
]);

// Options — пользовательские настройки (порядок/видимость колонок, pageSize)
$gridOptions = new Options($settings->getId());
$columns = $gridOptions->getUsedColumns(); // выбранные колонки
$pageSize = $gridOptions->getNavParams()['nPageSize'] ?? 20;
```

---

## Определение грида (расширение абстрактного класса)

```php
namespace MyVendor\MyModule\Grid;

use Bitrix\Main\Grid\Grid;
use Bitrix\Main\Grid\Column\Column;
use Bitrix\Main\Grid\Settings;

class ItemGrid extends Grid
{
    protected function getColumns(): array
    {
        return [
            Column::create('ID')
                ->setName('ID')
                ->setSort('ID')         // поле для сортировки
                ->setDefaultSort('ASC')
                ->setWidth(60),

            Column::create('TITLE')
                ->setName('Название')
                ->setSort('TITLE')
                ->setDefault(true),    // колонка видна по умолчанию

            Column::create('ACTIVE')
                ->setName('Активна')
                ->setDefault(true),

            Column::create('CREATED_AT')
                ->setName('Дата создания')
                ->setSort('CREATED_AT')
                ->setDefault(false),   // скрыта по умолчанию
        ];
    }
}
```

---

## Полный паттерн в компоненте (component.php)

```php
use Bitrix\Main\Grid\Settings;
use Bitrix\Main\Grid\Component\ComponentParams;
use MyVendor\MyModule\Grid\ItemGrid;
use MyVendor\MyModule\ItemTable;

// 1. Создать Settings и Grid
$settings = new Settings(['ID' => 'my_module_items']);
$grid = new ItemGrid($settings);

// 2. Обработать текущий запрос (сортировка, пагинация, смена видимости колонок)
$grid->processRequest();

// 3. Построить фильтр для ORM
// getOrmFilter() возвращает null если фильтр не задан — проверяй!
$ormFilter = $grid->getOrmFilter() ?? [];

// 4. Задать кол-во записей для пагинации
if ($grid->getPagination() !== null) {
    $count = ItemTable::getCount($ormFilter);
    $grid->getPagination()->setRecordCount($count);
}

// 5. Получить ORM-параметры (order, limit, offset)
// getOrmParams() возвращает ['order' => [...], 'limit' => N, 'offset' => N]
$ormParams = $grid->getOrmParams();

// 6. Заполнить строки — ПОСЛЕ processRequest()
$rows = ItemTable::getList(array_merge(
    ['select' => ['ID', 'TITLE', 'ACTIVE', 'CREATED_AT']],
    ['filter' => $ormFilter],
    $ormParams,
));
$grid->setRawRows($rows); // принимает \Traversable (Result из ORM)

// 7. Рендер компонента
$APPLICATION->IncludeComponent(
    'bitrix:main.ui.grid',
    '',
    ComponentParams::get($grid, [
        'AJAX_MODE'             => 'Y',
        'AJAX_OPTION_JUMP'      => 'N',
        'SHOW_CHECK_ALL_BUTTO' => 'Y',
    ])
);
```

---

## Фильтр: интеграция с Bitrix\Main\Filter\Filter

Grid не включает фильтр — это отдельный объект `Bitrix\Main\Filter\Filter`.

```php
use Bitrix\Main\Filter\Filter;
use Bitrix\Main\Filter\Settings as FilterSettings;
use Bitrix\Main\Filter\Field;

// Определить поля фильтра
$filterSettings = new FilterSettings([
    'ID'   => 'my_module_filter', // должен совпадать с ID грида для связи
    'FIELDS' => [
        new Field('TITLE', [
            'name'    => 'Название',
            'type'    => 'string',
            'default' => true,
        ]),
        new Field('ACTIVE', [
            'name'    => 'Активна',
            'type'    => 'list',
            'items'   => ['Y' => 'Да', 'N' => 'Нет'],
            'default' => true,
        ]),
        new Field('CREATED_AT', [
            'name' => 'Дата создания',
            'type' => 'date',
        ]),
    ],
]);

$filter = new Filter($filterSettings);
$grid->setFilter($filter); // связать фильтр с гридом

// После processRequest() фильтр ORM доступен через:
$ormFilter = $grid->getOrmFilter() ?? [];
```

---

## Пагинация

```php
use Bitrix\Main\UI\PageNavigation;

// Пагинация создаётся автоматически, если передан параметр PAGINATION
// Или задаётся вручную:
$nav = new PageNavigation('page-my-grid');
$nav->allowAllRecords(false)
    ->setPageSize(20)
    ->initFromUri();

$grid->setPagination($nav);
```

---

## Панель массовых действий (Panel)

```php
use Bitrix\Main\Grid\Panel\Panel;
use Bitrix\Main\Grid\Panel\Action;

$panel = new Panel();
$panel->setActions([
    (new Action())->setId('delete')
        ->setTitle('Удалить')
        ->setClassName('grid-button-delete'),
]);

$grid->setPanel($panel);
```

---

## Форматирование строк (шаблон компонента)

В шаблоне `bitrix:main.ui.grid` переопределяй строки через `ROWS`:

```php
// В component.php перед IncludeComponent:
$grid->setRawRows($queryResult);

// Либо в шаблоне template.php через $arResult['ROWS']:
// Каждая строка — массив ['id' => ..., 'columns' => ['COL' => 'html'], 'actions' => [...]]
```

Или форматируй на лету через `RowAssembler`:

```php
use Bitrix\Main\Grid\Row\Assembler\RowAssembler;

// Кастомный assembler — реализуй метод buildRows()
// Передаётся в $grid->setRowAssembler(new MyRowAssembler())
```

---

## Gotchas

- **`Grid` — абстрактный класс**: нельзя использовать напрямую, нужно наследоваться и реализовать `getColumns()`.
- **`getOrmFilter()` может вернуть `null`**: если пользователь не задал фильтр. Всегда используй `?? []`.
- **`setRawRows()` вызывать ПОСЛЕ `processRequest()`**: иначе обработчики пагинации/сортировки не применятся.
- **ID грида уникален**: если два грида на странице с одинаковым ID — конфликт настроек колонок в Options.
- **`getOrmParams()` возвращает `order`, `limit`, `offset`**: если GridOptions не содержит сортировки — `order` будет `[]`. Всегда предусматривай fallback.
- **Колонка с `setSort()`**: поле сортировки должно существовать в ORM-маппинге таблицы, иначе ORM выбросит исключение.
- **Экспорт в CSV**: grid поддерживает экспорт через `grid->getExport()`, но требует отдельной настройки `ExportController`.
- **Отличие от legacy**: `CAdminList` работает с массивами; `Grid` — с `\Traversable` (ORM Result). Смешивать нельзя.
