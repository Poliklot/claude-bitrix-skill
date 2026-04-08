# Bitrix Modern Grid UI — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с `Bitrix\Main\Grid\Grid`, `Settings`, `Options`, `Component\ComponentParams` и компонентом `bitrix:main.ui.grid`.

## Audit note

Проверено по текущему core:
- `www/bitrix/modules/main/lib/grid/grid.php`
- `www/bitrix/modules/main/lib/grid/settings.php`
- `www/bitrix/modules/main/lib/grid/options.php`
- `www/bitrix/modules/main/lib/grid/component/componentparams.php`
- `www/bitrix/modules/main/lib/grid/column/*`
- `www/bitrix/modules/main/lib/grid/panel/*`

Ниже только тот контракт, который реально подтверждён этим core.

## Главное отличие от старого reference

В текущем core:
- `Grid` абстрактный, его нельзя инстанцировать напрямую;
- `createColumns()` должен вернуть `Bitrix\Main\Grid\Column\Columns`, а не массив;
- `Columns` собирается из `Column\DataProvider`, а не из произвольного списка `Column::create(...)`;
- `Panel` не настраивается через `setActions()`: он работает через `DataProvider`;
- `Filter\Field` нельзя создать как `new Field('TITLE', [...])`: конструктору нужен `DataProvider`.

## Базовый паттерн

```php
use Bitrix\Main\Grid\Column\Columns;
use Bitrix\Main\Grid\Grid;
use Bitrix\Main\Grid\Settings;
use Bitrix\Main\Grid\Component\ComponentParams;

$settings = new Settings([
    'ID' => 'my_module_items',
]);

$grid = new ItemGrid($settings);
$grid->processRequest();

$ormFilter = $grid->getOrmFilter() ?? [];
$ormParams = $grid->getOrmParams();

if ($grid->getPagination() !== null)
{
    $grid->getPagination()->setRecordCount(
        ItemTable::getCount($ormFilter)
    );
}

$grid->setRawRows(
    ItemTable::getList(array_merge(
        ['select' => ['ID', 'TITLE', 'ACTIVE']],
        $ormParams
    ))
);

$APPLICATION->IncludeComponent(
    'bitrix:main.ui.grid',
    '',
    ComponentParams::get($grid, [
        'AJAX_MODE' => 'Y',
    ])
);
```

## Как правильно определить колонки

В текущем API `Grid::createColumns()` должен вернуть `Columns`. `Columns` принимает `Column\DataProvider`.

```php
namespace Vendor\Module\Grid;

use Bitrix\Main\Grid\Column\Column;
use Bitrix\Main\Grid\Column\Columns;
use Bitrix\Main\Grid\Column\DataProvider;
use Bitrix\Main\Grid\Grid;

final class ItemColumnsProvider extends DataProvider
{
    public function prepareColumns(): array
    {
        return $this->createColumns([
            'ID' => [
                'name' => 'ID',
                'sort' => 'ID',
                'default' => true,
                'width' => 80,
            ],
            'TITLE' => [
                'name' => 'Название',
                'sort' => 'TITLE',
                'default' => true,
            ],
            'ACTIVE' => [
                'name' => 'Активность',
                'sort' => 'ACTIVE',
                'default' => true,
                'necessary' => true,
            ],
        ]);
    }
}

final class ItemGrid extends Grid
{
    protected function createColumns(): Columns
    {
        return new Columns(
            new ItemColumnsProvider($this->getSettings())
        );
    }
}
```

Если нужен прямой `Column`, в этом core он создаётся через `new Column($id, $params)`. Не обещай chain-конструктор `Column::create(...)`, пока не подтвердил его локально.

## Что делает `getOrmParams()`

Подтверждённый состав:
- `select` из видимых и necessary-колонок;
- `order` из `Options::getSorting(...)`;
- `filter`, если есть `Filter`;
- `limit`/`offset`, если есть `PageNavigation`.

То есть `getOrmParams()` уже включает ORM-friendly параметры для `DataManager::getList(...)`.

## Pagination и Options

`Options` в текущем core наследуется от `CGridOptions` и даёт, среди прочего:
- `getSorting(...)`
- `GetVisibleColumns()`
- `getNavParams()`
- `setPageSize(...)`
- `getExpandedRows()`
- `setExpandedRows(...)`

`Settings` подтверждает:
- `MODE_HTML`
- `MODE_EXCEL`
- `getID()`
- `isHtmlMode()`
- `isExcelMode()`

## Filter

`Grid` сам фильтр не строит. `getOrmFilter()` работает только если `createFilter()` вернул объект `Bitrix\Main\Filter\Filter`.

В текущем core `Bitrix\Main\Filter\Field` требует `DataProvider` первым аргументом, поэтому универсальный “короткий” пример вида

```php
new Field('TITLE', [...])
```

для этого ядра неверен.

Практическое правило:
- если фильтр уже есть в модуле или проекте, ориентируйся на его `DataProvider`;
- если фильтра нет, не придумывай shortcut API, которого нет в этом core.

## Panel

`Bitrix\Main\Grid\Panel\Panel` в текущем core строится через `Panel\Action\DataProvider`, а не через `setActions(...)`.

Подтверждённый контракт:
- `new Panel(DataProvider ...$providers)`
- `getControls()`
- `processRequest(...)`

Если тебе нужна массовая action-panel, ищи или пиши provider, а не вызывай несуществующий fluent API.

## Gotchas

- Не инстанцируй `new Grid(...)`: класс абстрактный.
- Не возвращай из `createColumns()` массив: нужен объект `Columns`.
- Не обещай `Column::create(...)` и `Panel::setActions(...)`, пока не подтвердил их локально.
- `setRawRows()` действительно принимает `iterable`, но сохраняет строки во внутренний массив, так что это не “ленивая” обёртка.
- `getOrmFilter()` может вернуть `null` и это штатный сценарий.
