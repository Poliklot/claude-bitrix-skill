# Bitrix Numerator — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с нумерацией документов: `Bitrix\Main\Numerator\Numerator`, `NumberGeneratorFactory`, шаблонами нумерации (префикс, дата, порядковый номер), таблицами `NumeratorTable`, `NumeratorSequenceTable`.

## Содержание
- Архитектура Numerator
- Создание и настройка нумератора
- Шаблон нумерации (теги)
- Генерация номера
- NumeratorTable: хранение конфигурации
- NumeratorSequenceTable: последовательности
- Интерфейсы: UserConfigurable, DynamicConfigurable, Sequenceable
- Gotchas

---

## Архитектура

`Numerator` — генератор уникальных номеров для документов (заказы, счета, акты).

**Ключевые компоненты:**
- `Numerator` — главный класс, создаётся через `Numerator::create()`
- `NumberGeneratorFactory` — фабрика генераторов (DATE, SEQUENCE, RANDOM и др.)
- `NumeratorTable` — хранит конфигурацию нумераторов
- `NumeratorSequenceTable` — хранит текущие значения последовательностей

**Шаблон нумерации** — строка с тегами, например `{PREFIX}{YEAR}{MONTH}{NUMBER}`.

---

## Создание нумератора

```php
use Bitrix\Main\Numerator\Numerator;
use Bitrix\Main\Numerator\Model\NumeratorTable;

// Создать нумератор с шаблоном
$numerator = Numerator::create()
    ->setType('MY_MODULE_ORDER')              // тип документа (уникальный в модуле)
    ->setTemplate('{PREFIX}-{YEAR}{MONTH}-{NUMBER}')  // шаблон
    ->setName('Нумератор заказов');

// Сохранить в БД (получить/создать ID)
$result = NumeratorTable::add([
    'NAME'     => 'Нумератор заказов',
    'TYPE'     => 'MY_MODULE_ORDER',
    'TEMPLATE' => '{PREFIX}-{YEAR}{MONTH}-{NUMBER}',
    'CONFIG'   => serialize([
        'PREFIX' => ['value' => 'ORD'],
        'NUMBER' => ['start' => 1, 'step' => 1, 'periodicReset' => 'MONTHLY'],
    ]),
]);
$numeratorId = $result->getId();
```

---

## Загрузка нумератора из БД

```php
use Bitrix\Main\Numerator\Numerator;
use Bitrix\Main\Numerator\Model\NumeratorTable;

// По ID
$row = NumeratorTable::getById($numeratorId)->fetch();
if ($row) {
    $numerator = Numerator::create()
        ->setId($row['ID'])
        ->setName($row['NAME'])
        ->setType($row['TYPE'])
        ->setTemplate($row['TEMPLATE']);
}

// Или через getById самого класса
$numerator = Numerator::load($numeratorId); // если метод реализован в вашей версии
```

---

## Генерация номера

```php
use Bitrix\Main\Numerator\Numerator;

// Простой вариант — получить следующий номер
$numerator = /* загруженный нумератор */;
$number = $numerator->getNumber(); // строка: "ORD-202503-0042"

// С параметрами (для динамических тегов)
$number = $numerator->getNumber([
    'userId'    => $USER->GetID(),
    'createdAt' => new \Bitrix\Main\Type\DateTime(),
]);
```

---

## Теги шаблона нумерации

| Тег | Описание | Пример |
|-----|----------|--------|
| `{PREFIX}` | Произвольный префикс | `ORD` |
| `{YEAR}` | Год (4 цифры) | `2025` |
| `{YEAR2}` | Год (2 цифры) | `25` |
| `{MONTH}` | Месяц (2 цифры) | `03` |
| `{DAY}` | День (2 цифры) | `17` |
| `{HOUR}` | Час (2 цифры) | `14` |
| `{NUMBER}` | Порядковый номер (с настройками) | `0042` |
| `{RANDOM}` | Случайный номер | `8f4a2c` |

**Пример составного шаблона:**
```
{PREFIX}-{YEAR}{MONTH}-{NUMBER}  →  ORD-202503-0042
ACT/{YEAR}/{NUMBER}               →  ACT/2025/0001
INV-{YEAR2}{MONTH}{DAY}-{RANDOM}  →  INV-250317-a3f2
```

---

## NumeratorTable: работа с хранилищем

```php
use Bitrix\Main\Numerator\Model\NumeratorTable;

// Получить все нумераторы типа
$list = NumeratorTable::getList([
    'filter' => ['=TYPE' => 'MY_MODULE_ORDER'],
    'select' => ['ID', 'NAME', 'TEMPLATE', 'CONFIG'],
])->fetchAll();

// Обновить шаблон
NumeratorTable::update($numeratorId, [
    'TEMPLATE' => '{PREFIX}/{YEAR}-{NUMBER}',
]);

// Удалить нумератор (осторожно!)
NumeratorTable::delete($numeratorId);
```

---

## NumeratorSequenceTable: управление последовательностью

```php
use Bitrix\Main\Numerator\Model\NumeratorSequenceTable;

// Посмотреть текущее значение последовательности
$seq = NumeratorSequenceTable::getList([
    'filter' => [
        '=NUMERATOR_ID' => $numeratorId,
        '=PERIOD'       => '2025-03', // формат зависит от настройки periodicReset
    ],
])->fetch();

// Сбросить последовательность вручную (например, в начале года)
if ($seq) {
    NumeratorSequenceTable::update($seq['ID'], ['VALUE' => 0]);
}
```

---

## Интерфейсы генераторов

Встроенные генераторы реализуют различные интерфейсы:

```php
use Bitrix\Main\Numerator\Generator\Contract\UserConfigurable;
use Bitrix\Main\Numerator\Generator\Contract\DynamicConfigurable;
use Bitrix\Main\Numerator\Generator\Contract\Sequenceable;

// UserConfigurable — имеет настройки для пользователя (PREFIX, START и т.д.)
// DynamicConfigurable — настройки зависят от контекста (дата, userId)
// Sequenceable — поддерживает последовательный счётчик с периодическим сбросом
```

**Периодический сброс счётчика (periodicReset для NUMBER):**

| Значение | Описание |
|----------|----------|
| `NEVER` | Никогда не сбрасывать |
| `YEARLY` | Сброс в начале каждого года |
| `MONTHLY` | Сброс в начале каждого месяца |
| `DAILY` | Сброс каждый день |

---

## Полный пример: нумерация заказов в модуле

```php
namespace MyVendor\MyModule\Service;

use Bitrix\Main\Numerator\Numerator;
use Bitrix\Main\Numerator\Model\NumeratorTable;
use Bitrix\Main\Config\Option;

class OrderNumeratorService
{
    private const MODULE_ID = 'my.module';
    private const OPTION_KEY = 'order_numerator_id';

    public static function getOrCreateNumerator(): ?Numerator
    {
        $numeratorId = (int)Option::get(self::MODULE_ID, self::OPTION_KEY, 0);

        if ($numeratorId <= 0) {
            $result = NumeratorTable::add([
                'NAME'     => 'Нумерация заказов',
                'TYPE'     => 'MY_MODULE_ORDER',
                'TEMPLATE' => 'ORD-{YEAR}{MONTH}-{NUMBER}',
                'CONFIG'   => serialize([
                    'NUMBER' => [
                        'start'         => 1,
                        'step'          => 1,
                        'periodicReset' => 'YEARLY',
                        'padding'       => 4, // ведущие нули: 0042
                    ],
                ]),
            ]);

            if (!$result->isSuccess()) {
                return null;
            }

            $numeratorId = $result->getId();
            Option::set(self::MODULE_ID, self::OPTION_KEY, $numeratorId);
        }

        // Загрузить нумератор
        $row = NumeratorTable::getById($numeratorId)->fetch();
        if (!$row) {
            return null;
        }

        return Numerator::create()
            ->setId($row['ID'])
            ->setName($row['NAME'])
            ->setType($row['TYPE'])
            ->setTemplate($row['TEMPLATE']);
    }

    public static function generateNumber(): string
    {
        $numerator = static::getOrCreateNumerator();
        if ($numerator === null) {
            return 'ORD-' . date('YmdHis'); // fallback
        }

        return $numerator->getNumber();
    }
}

// Использование:
$orderNumber = OrderNumeratorService::generateNumber(); // "ORD-202503-0001"
```

---

## Gotchas

- **`getNumber()` атомарен**: внутри используется `SELECT ... FOR UPDATE` или аналог для защиты от дублирования при параллельных запросах.
- **CONFIG сериализован**: поле `CONFIG` в `NumeratorTable` хранит `serialize()` массива. При чтении и записи не забывай `serialize()`/`unserialize()`.
- **Тип (TYPE) уникален**: один тип документа — один нумератор. При попытке создать второй с тем же TYPE — поведение зависит от реализации (может создать второй или вернуть ошибку).
- **Периодический сброс**: `NumeratorSequenceTable` хранит одну строку на период (год/месяц). При сбросе в начале года создаётся новая строка — старые данные сохраняются.
- **`Numerator::create()` без сохранения**: `create()` создаёт объект в памяти. `NumeratorTable::add()` — сохраняет в БД. Это разные операции.
- **Нет автоматической транзакции**: если обновление последовательности упало на середине — номер может быть пропущен. Это нормально для нумераторов (не используй для финансовых документов без дополнительной проверки).
