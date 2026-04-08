# Bitrix Numerator — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с нумерацией документов через `Bitrix\Main\Numerator\Numerator`, `NumberGeneratorFactory`, `NumeratorTable` и `NumeratorSequenceTable`.

## Audit note

Проверено по текущему core:
- `www/bitrix/modules/main/lib/numerator/numerator.php`
- `www/bitrix/modules/main/lib/numerator/numbergeneratorfactory.php`
- `www/bitrix/modules/main/lib/numerator/model/numerator.php`
- `www/bitrix/modules/main/lib/numerator/model/numeratorsequence.php`
- `www/bitrix/modules/main/lib/numerator/generator/*`

Это реальный модульный слой текущего `main`, а не внешняя библиотека.

## Что есть в этом core

Основные классы:
- `Bitrix\Main\Numerator\Numerator`
- `Bitrix\Main\Numerator\NumberGeneratorFactory`
- `Bitrix\Main\Numerator\Model\NumeratorTable`
- `Bitrix\Main\Numerator\Model\NumeratorSequenceTable`

Встроенные генераторы:
- `SequentNumberGenerator`
- `DateNumberGenerator`
- `RandomNumberGenerator`
- `PrefixNumberGenerator`

В `NumberGeneratorFactory` генераторы собираются из core и могут расширяться событием `main:onNumberGeneratorsClassesCollect`.

## Важное отличие от старых описаний

В текущем core:
- следующий номер получают через `Numerator::getNext(...)`, а не `getNumber()`;
- preview идёт через `previewNextNumber(...)`;
- конфиг хранится в поле `SETTINGS`, а не `CONFIG`;
- таблица нумераторов называется `b_numerator`, а последовательностей `b_numerator_sequence`;
- есть `load($id, $source = null)` и `loadByCode($code, $source = null)`.

## Как создавать и сохранять

У `Numerator::create()` конструктор пустой. Публичных chain-методов `setName()/setType()/setTemplate()` в текущем core нет. Рабочий путь — подготовить конфиг и вызвать `setConfig(...)`, затем `save()`.

```php
use Bitrix\Main\Numerator\Generator\SequentNumberGenerator;
use Bitrix\Main\Numerator\Numerator;

$numerator = Numerator::create();

$result = $numerator->setConfig([
    Numerator::getType() => [
        'name' => 'Нумерация заказов',
        'type' => Numerator::NUMERATOR_DEFAULT_TYPE,
        'template' => '{PREFIX}-{YEAR}{MONTH}-{NUMBER}',
        'code' => 'orders',
    ],
    SequentNumberGenerator::getType() => [
        'start' => 1,
        'step' => 1,
        'length' => 6,
        'padString' => '0',
        'periodicBy' => SequentNumberGenerator::MONTH,
    ],
]);

if (!$result->isSuccess())
{
    throw new \RuntimeException(implode('; ', $result->getErrorMessages()));
}

$saveResult = $numerator->save();
if (!$saveResult->isSuccess())
{
    throw new \RuntimeException(implode('; ', $saveResult->getErrorMessages()));
}

$numeratorId = (int)$saveResult->getId();
```

## Загрузка

```php
use Bitrix\Main\Numerator\Numerator;

$numerator = Numerator::load($numeratorId);
$byCode = Numerator::loadByCode('orders');
```

Если нумератор не найден или конфиг невалиден, вернётся `null`.

Второй аргумент `load(..., $source)` можно использовать как:
- dynamic config для `DynamicConfigurable` генераторов;
- hash-source для последовательности, если объект реализует `Hashable`.

## Генерация номера

```php
if (!$numerator)
{
    throw new \RuntimeException('Numerator not found');
}

$next = $numerator->getNext();
$preview = $numerator->previewNextNumber();
```

Для последовательного генератора:
- `getNext()` реально увеличивает счётчик;
- `previewNextNumber()` только считает следующий видимый номер;
- `previewNextSequentialNumber()` возвращает только следующее числовое значение счётчика;
- `setNextSequentialNumber(...)` позволяет принудительно сдвинуть последовательность.

## Хеш и независимые последовательности

Последовательность в текущем core может вестись независимо по хешу.

```php
$nextForCompany42 = $numerator->getNext('COMPANY_42');
$nextForCompany64 = $numerator->getNext('COMPANY_64');
```

`NumeratorSequenceTable` хранит ключ как:
- `KEY = md5($numberHash)`
- `TEXT_KEY = mb_substr($numberHash, 0, 50)`

## Таблицы

### `NumeratorTable`

`Bitrix\Main\Numerator\Model\NumeratorTable` работает с таблицей `b_numerator`.

Реальные поля:
- `ID`
- `NAME`
- `TEMPLATE`
- `SETTINGS`
- `TYPE`
- `CREATED_AT`
- `CREATED_BY`
- `UPDATED_AT`
- `UPDATED_BY`
- `CODE`

`CODE`:
- nullable;
- должен быть уникальным;
- если передан, обязан быть непустой строкой.

Полезные методы:
- `getList(...)`
- `getById(...)`
- `getNumeratorList($type, $sort)`
- `loadSettings($numeratorId)`
- `saveNumerator($numeratorId, $fields)`
- `getIdByCode($code)`

### `NumeratorSequenceTable`

`Bitrix\Main\Numerator\Model\NumeratorSequenceTable` работает с таблицей `b_numerator_sequence`.

Реальные поля:
- `NUMERATOR_ID`
- `KEY`
- `TEXT_KEY`
- `NEXT_NUMBER`
- `LAST_INVOCATION_TIME`

Полезные методы:
- `getSettings($numeratorId, $numberHash)`
- `setSettings($numeratorId, $numberHash, $defaultNumber, $lastInvocationTime)`
- `updateSettings($numeratorId, $numberHash, $fields, $whereNextNumber = null)`
- `deleteByNumeratorId($id)`

## Периодичность последовательности

В `SequentNumberGenerator` подтверждены значения:
- `SequentNumberGenerator::DAY`
- `SequentNumberGenerator::MONTH`
- `SequentNumberGenerator::YEAR`
- пустое значение для режима без периодического сброса

Не подменяй их псевдо-значениями вроде `DAILY`, `MONTHLY`, `YEARLY`: в этом core используются именно `day`, `month`, `year`.

## Шаблон и встроенные слова

Конкретный набор слов зависит от подключённых генераторов, но в текущем core подтверждены:
- `{NUMBER}`
- `{DAY}`
- `{MONTH}`
- `{YEAR}`
- `{RANDOM}`
- `{PREFIX}`

Для получения доступных слов безопаснее использовать:

```php
use Bitrix\Main\Numerator\Numerator;

$words = Numerator::getTemplateWordsForType();
$settings = Numerator::getSettingsFields(Numerator::NUMERATOR_DEFAULT_TYPE);
```

## Обновление и удаление

```php
use Bitrix\Main\Numerator\Numerator;

$updateResult = Numerator::update($numeratorId, [
    Numerator::getType() => [
        'idFromDb' => $numeratorId,
        'name' => 'Обновлённый нумератор',
        'type' => Numerator::NUMERATOR_DEFAULT_TYPE,
        'template' => '{PREFIX}-{YEAR}-{NUMBER}',
        'code' => 'orders',
    ],
]);

$deleteResult = Numerator::delete($numeratorId);
```

`delete($id)` дополнительно чистит связанные записи последовательностей через `NumeratorSequenceTable::deleteByNumeratorId(...)`.

## Gotchas

- Не используй `getNumber()`: в текущем core рабочий метод называется `getNext()`.
- Не пиши в примерах поле `CONFIG`: в таблице хранится `SETTINGS`, причём через JSON.
- Не строй конфиг через несуществующие public chain-методы `setType()/setTemplate()/setName()`.
- Не подменяй периодичность значениями `YEARLY`/`MONTHLY`/`DAILY`: ядро использует `year`/`month`/`day`.
- Если нужен preview без инкремента, используй `previewNextNumber()`, а не `getNext()`.
