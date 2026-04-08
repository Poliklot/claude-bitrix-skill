# Bitrix Stepper + CLI — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с пошаговыми обновлениями данных через `Bitrix\Main\Update\Stepper` или с реальными CLI-командами текущего core.

## Audit note

Проверено по текущему core:
- `www/bitrix/modules/main/lib/update/stepper.php`
- `www/bitrix/bitrix.php`
- `www/bitrix/modules/main/lib/cli/command/*`

Ниже только то, что подтверждается этим ядром.

## Stepper: когда использовать

`Stepper` нужен для долгих обновлений данных порциями через агент. В docblock текущего класса прямо зафиксировано ограничение: используй его для задач, где не меняется схема БД.

Типовые случаи:
- переиндексация или пересчёт существующих записей;
- заполнение новых полей у большого объёма данных;
- перенос или нормализация содержимого без `ALTER TABLE`.

Не тащи `Stepper` в роль универсальной миграционной системы для DDL. Для изменений таблиц в core нет отдельного встроенного migration-framework.

## Базовый контракт

```php
namespace Vendor\Module\Update;

use Bitrix\Main\Update\Stepper;

final class DataFixStepper extends Stepper
{
    protected static $moduleId = 'vendor.module';

    public static function getTitle(): string
    {
        return 'Исправление данных Vendor.Module';
    }

    public function execute(array &$option): bool
    {
        $lastId = (int)($option['lastId'] ?? 0);
        $limit = 100;

        $rows = MyTable::getList([
            'filter' => ['>ID' => $lastId],
            'order' => ['ID' => 'ASC'],
            'limit' => $limit,
            'select' => ['ID', 'NAME'],
        ])->fetchAll();

        if (!$rows)
        {
            return self::FINISH_EXECUTION;
        }

        foreach ($rows as $row)
        {
            // Обновляем порцию данных.
            $lastId = (int)$row['ID'];
        }

        $option['lastId'] = $lastId;
        $option['steps'] = (int)($option['steps'] ?? 0) + count($rows);
        $option['count'] = (int)($option['count'] ?? 0) + count($rows);

        return self::CONTINUE_EXECUTION;
    }
}
```

Подтверждённые детали из core:
- `execute(array &$option)` должен вернуть `Stepper::CONTINUE_EXECUTION` или `Stepper::FINISH_EXECUTION`;
- прогресс и служебные данные хранятся в `Option` под категорией `main.stepper.<moduleId>`;
- `steps`, `count`, `title`, `lastTime`, `totalTime`, `thresholdTime`, `delayCoefficient` реально используются ядром.

## bind() и bindClass()

В текущем core сигнатуры такие:

```php
public static function bind($delay = 300, $withArguments = [])
public static function bindClass($className, $moduleId, $delay = 300, $withArguments = [])
```

Это важно: третий аргумент `bindClass()` — не массив параметров, а именно задержка в секундах.

```php
use Vendor\Module\Update\DataFixStepper;

// Вариант через shortcut текущего класса.
DataFixStepper::bind(300, [42, 'full']);

// Вариант через общий helper.
\Bitrix\Main\Update\Stepper::bindClass(
    DataFixStepper::class,
    'vendor.module',
    300,
    [42, 'full']
);
```

Аргументы сериализуются в строку вызова агента через `makeArguments()`. В базовой реализации надёжно поддерживаются строки и числа.

## outerParams и execAgent()

`bind()` и `bindClass()` передают `$withArguments` в `execAgent(...)`, а затем в `$this->outerParams`.

```php
public function execute(array &$option): bool
{
    [$tenantId, $mode] = $this->getOuterParams() + [0, 'default'];

    // ...
}
```

`execAgent()` в текущем core:
- поднимает состояние из `Option::get("main.stepper.<moduleId>", $className)`;
- вызывает `execute($option)`;
- при `CONTINUE_EXECUTION` сохраняет состояние и возвращает следующую строку агента;
- при `FINISH_EXECUTION` удаляет состояние через `Option::delete(...)` и возвращает пустую строку.

Если шаг работал дольше `thresholdTime` (по умолчанию `20.0`), ядро увеличивает период следующего запуска через глобальный `$pPERIOD`.

## Прогресс

Реальный ключ хранения:

```php
use Bitrix\Main\Config\Option;

$raw = Option::get('main.stepper.vendor.module', DataFixStepper::class);
if ($raw !== '')
{
    $state = unserialize($raw, ['allowed_classes' => false]);
}
```

Пример полезных полей:
- `steps`
- `count`
- `title`
- `lastId`
- `lastTime`
- `totalTime`
- `thresholdTime`
- `delayCoefficient`

Для UI ядро использует `Stepper::getHtml(...)` и `Stepper::checkRequest()`.

## CLI в текущем core

В этом проекте точка входа CLI подтверждена как:

```bash
php www/bitrix/bitrix.php <command>
```

Не пиши в reference, что здесь гарантированно есть `bitrix/bin/console`: в текущем snapshot найден именно `www/bitrix/bitrix.php`.

Подтверждённые команды из `main/lib/cli/command/*`:
- `make:controller`
- `make:component`
- `make:tablet`
- `orm:annotate`
- `update:languages`
- `update:modules`
- `update:versions`
- `messenger:consume-messages`
- `dev:locator-codes`
- `dev:module-skeleton`

Примеры:

```bash
php www/bitrix/bitrix.php make:controller entity partner.module
php www/bitrix/bitrix.php make:tablet my_table partner.module
php www/bitrix/bitrix.php orm:annotate
```

`make:tablet`, а не `make:table`.

## Gotchas

- Не передавай массив третьим аргументом в `bindClass()`: это `delay`, а не `withArguments`.
- Не описывай `Stepper` как инструмент для изменения схемы БД. В самом core написано обратное.
- Если нужно передать сложные структуры, переопредели `makeArguments()` и аккуратно восстанавливай их в `getOuterParams()`.
- `bind(0, ...)` и `bindClass(..., 0, ...)` могут запустить шаг немедленно через `execAgent()` до постановки агента.
- CLI-команды нужно привязывать к реальному entrypoint проекта. В этом core это `www/bitrix/bitrix.php`.
