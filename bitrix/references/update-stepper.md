# Bitrix Update Stepper + CLI — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с итеративными обновлениями данных (`Bitrix\Main\Update\Stepper`), миграционными скриптами в апдейтерах, или с CLI-командами Bitrix (Symfony Console): `UpdateCommand`, `make/*`, `orm/annotate`.

## Содержание
- Stepper: архитектура и смысл
- Реализация абстрактного класса Stepper
- Привязка к агенту: `Stepper::bindClass()`
- Выполнение итераций: метод `execute()`
- Прогресс и состояние
- CLI-команды (Symfony Console)
- Gotchas

---

## Stepper: архитектура

`Stepper` — абстрактный класс для **итеративных обновлений данных** в рамках лимита времени. Используется в updater-скриптах (`/bitrix/modules/mymodule/updaters/*.php`) когда нужно обновить большую таблицу не за один запрос, а порциями — чтобы не превысить лимит времени выполнения.

**Принцип работы:**
1. `Stepper::bindClass($class, $moduleId)` — регистрирует задачу как агент в системе
2. Агент вызывает статический метод `$class::doStep()` снова и снова
3. Каждый вызов `doStep()` вызывает `execute()` — твой код обрабатывает порцию данных
4. Если время `>= THRESHOLD_TIME (20с)` — `doStep()` сохраняет состояние и завершает итерацию
5. Когда `execute()` вернёт `FINISH_EXECUTION` — агент удаляется

---

## Реализация Stepper

```php
namespace MyVendor\MyModule\Update;

use Bitrix\Main\Update\Stepper;
use Bitrix\Main\Config\Option;
use MyVendor\MyModule\OldDataTable;
use MyVendor\MyModule\NewDataTable;

class DataMigrationStepper extends Stepper
{
    // Обязательно: ID модуля для хранения состояния
    protected static $moduleId = 'my.module';

    /**
     * Метод выполняется в каждой итерации.
     * $this->outerParams — данные из предыдущей итерации (состояние).
     *
     * @return bool CONTINUE_EXECUTION или FINISH_EXECUTION
     */
    public function execute(array &$option): bool
    {
        // Читаем смещение из состояния
        $lastId = (int)($option['lastId'] ?? 0);
        $batchSize = 100;

        // Выбираем порцию данных
        $result = OldDataTable::getList([
            'filter' => ['>ID' => $lastId],
            'order'  => ['ID' => 'ASC'],
            'limit'  => $batchSize,
            'select' => ['ID', 'DATA'],
        ]);

        $rows = $result->fetchAll();

        if (empty($rows)) {
            // Данных больше нет — завершаем
            return static::FINISH_EXECUTION;
        }

        foreach ($rows as $row) {
            // Обрабатываем каждую запись
            NewDataTable::add([
                'OLD_ID' => $row['ID'],
                'DATA'   => strtoupper($row['DATA']),
            ]);
            $lastId = $row['ID'];
        }

        // Сохраняем состояние для следующей итерации
        $option['lastId'] = $lastId;

        // Прогресс (опционально — для UI)
        $option['steps'] = ($option['steps'] ?? 0) + count($rows);
        $option['count'] = ($option['count'] ?? 0) + count($rows);

        return static::CONTINUE_EXECUTION;
    }
}
```

---

## Привязка к агенту: bindClass()

В updater-скрипте (`/bitrix/modules/my.module/updaters/updater_20250101.php`):

```php
// Простой вариант
\Bitrix\Main\Update\Stepper::bindClass(
    'MyVendor\\MyModule\\Update\\DataMigrationStepper',
    'my.module'
);

// С параметрами (передаются в $option при первом вызове)
\Bitrix\Main\Update\Stepper::bindClass(
    'MyVendor\\MyModule\\Update\\DataMigrationStepper',
    'my.module',
    [
        'lastId' => 0,
        'steps'  => 0,
        'count'  => 0,
        'title'  => 'Миграция данных MyModule',
    ]
);
```

**Как вызывается из updater-файла:**

```php
// /bitrix/modules/my.module/updaters/updater_20250101.php
if ($updater->CanUpdateDatabase())
{
    \Bitrix\Main\Update\Stepper::bindClass(
        \MyVendor\MyModule\Update\DataMigrationStepper::class,
        'my.module'
    );
}
```

---

## Метод bind() (альтернативный shortcut)

Если реализуешь статический `bind()` в своём классе — удобнее:

```php
class DataMigrationStepper extends Stepper
{
    protected static $moduleId = 'my.module';

    public static function bind(array $initialParams = []): void
    {
        static::bindClass(static::class, static::$moduleId, array_merge(
            ['lastId' => 0, 'steps' => 0, 'count' => 0],
            $initialParams
        ));
    }

    public function execute(array &$option): bool
    {
        // ...
    }
}

// В updater-файле:
\MyVendor\MyModule\Update\DataMigrationStepper::bind();
```

---

## Прогресс и состояние

Stepper хранит состояние через `Config\Option` в категории `"main.stepper.{$moduleId}"`:

```php
use Bitrix\Main\Config\Option;

// Получить текущий прогресс вручную
$option = Option::get('main.stepper.my.module', DataMigrationStepper::class);
if ($option !== '') {
    $state = unserialize($option, ['allowed_classes' => false]);
    // ['lastId' => 500, 'steps' => 500, 'count' => 500, 'title' => '...']
}

// Сбросить/удалить задачу вручную
Option::delete('main.stepper.my.module', ['name' => DataMigrationStepper::class]);
```

---

## CLI-команды Bitrix (Symfony Console)

Bitrix поставляется с CLI через Symfony Console. Entrypoint: `php bitrix/bin/console`.

### Доступные группы команд

```bash
# Обновление (запуск Stepper вручную)
php bitrix/bin/console update

# Генерация кода
php bitrix/bin/console make:controller    # создать Controller
php bitrix/bin/console make:table         # создать DataManager (таблицу)

# ORM-аннотации
php bitrix/bin/console orm:annotate       # сгенерировать PHPDoc-аннотации для ORM-классов
```

### Пример: make:table

```bash
php bitrix/bin/console make:table MyVendor\\MyModule\\MyNewTable
```

Генерирует файл `local/modules/my.module/lib/mynewdatatable.php` с заготовкой DataManager.

### Пример: orm:annotate

```bash
php bitrix/bin/console orm:annotate --module=my.module
```

Добавляет `@property` PHPDoc к классам ORM, что улучшает подсказки в IDE.

### Реализация собственной команды

```php
namespace MyVendor\MyModule\Cli;

use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\Console\Input\InputArgument;

class ImportCommand extends Command
{
    protected static $defaultName = 'my-module:import';

    protected function configure(): void
    {
        $this->setDescription('Импорт данных из CSV')
             ->addArgument('file', InputArgument::REQUIRED, 'Путь к CSV-файлу');
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $file = $input->getArgument('file');
        $output->writeln("Импортируем: {$file}");
        // ... логика импорта ...
        return Command::SUCCESS;
    }
}
```

Регистрация команды в `local/modules/my.module/lib/cli/`:

```php
// В include.php модуля или через ServiceLocator:
// Команды регистрируются автоматически если находятся в правильном namespace
// и модуль зарегистрирован как CLI-модуль
```

---

## Gotchas

- **`THRESHOLD_TIME = 20.0`**: итерация прерывается после 20 секунд. Размер батча должен укладываться в это время с запасом.
- **`bindClass()` регистрирует агент**: если вызвать дважды — создадутся два агента для одного класса. Проверяй наличие перед привязкой или используй `Option::get()`.
- **`$option` передаётся по ссылке**: изменения в `execute()` автоматически сохраняются между итерациями.
- **Stepper не работает без `$moduleId`**: состояние хранится в опциях модуля. Если модуль не установлен — агент не будет запускаться.
- **Не изменяй структуру таблиц в Stepper**: класс предназначен только для обновления данных, не DDL. Для DDL используй `$updater->addTablesFromFile()`.
- **CLI `orm:annotate`**: требует установленных модулей. Запускать из корня сайта с правильными настройками в `bitrix/.settings.php`.
- **`DELAY_COEFFICIENT = 0.5`**: реальный порог — `THRESHOLD_TIME * DELAY_COEFFICIENT = 10с`. Запас на сохранение состояния.
