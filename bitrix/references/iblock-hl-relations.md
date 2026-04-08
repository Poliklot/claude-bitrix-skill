# Связь инфоблок ↔ HL-блок

Два совершенно разных механизма. Путают часто. Важно понять какой именно используется в проекте.

---

## Механизм 1 — Свойство инфоблока типа `directory` (USER_TYPE='directory')

**Класс:** `CIBlockPropertyDirectory` (модуль `highloadblock`)

**Что хранит:** строку `UF_XML_ID` HL-записи — **не числовой ID**, а XML-код.

**Настройки свойства:** `USER_TYPE_SETTINGS['TABLE_NAME']` = имя таблицы HL-блока (напр. `b_hlbd_color`).

**Для чего используют:** HL-блок как справочник (цвет, размер, страна и т.п.). HL-блок должен иметь стандартные поля: `UF_XML_ID` (обязательно), `UF_NAME`, `UF_SORT`, `UF_FILE`, `UF_DEF`.

### Чтение через legacy

```php
use Bitrix\Main\Loader;
Loader::includeModule('iblock');
Loader::includeModule('highloadblock');

// $el['PROPERTY_COLOR_VALUE'] = 'red' — это UF_XML_ID HL-записи!
$res = CIBlockElement::GetList(
    ['SORT' => 'ASC'],
    ['IBLOCK_ID' => PRODUCTS_IBLOCK_ID, 'ACTIVE' => 'Y'],
    false, false,
    ['ID', 'NAME', 'PROPERTY_COLOR']
);
while ($el = $res->GetNext()) {
    $xmlId = $el['PROPERTY_COLOR_VALUE'];  // строка 'red', не int!

    // Получить полную HL-запись по UF_XML_ID
    if ($xmlId) {
        $colorRecord = self::getHlRecordByXmlId('b_hlbd_color', $xmlId);
        echo $colorRecord['UF_NAME'];      // 'Красный'
    }
}

// Вспомогательный метод — получить HL-запись по UF_XML_ID
function getHlRecordByXmlId(string $tableName, string $xmlId): ?array
{
    $hlblock = \Bitrix\Highloadblock\HighloadBlockTable::getRow([
        'filter' => ['=TABLE_NAME' => $tableName],
    ]);
    if (!$hlblock) return null;

    $entity = \Bitrix\Highloadblock\HighloadBlockTable::compileEntity($hlblock);
    $dataClass = $entity->getDataClass();

    return $dataClass::getRow([
        'filter' => ['=UF_XML_ID' => $xmlId],
        'select' => ['ID', 'UF_XML_ID', 'UF_NAME', 'UF_FILE', 'UF_SORT'],
    ]);
}
```

### Чтение через D7 ORM (ElementV2Table)

```php
use Bitrix\Iblock\Elements\ElementProductsTable; // API_CODE='products'

$result = ElementProductsTable::getList([
    'select' => ['ID', 'NAME', 'COLOR_XML_ID' => 'COLOR.VALUE'],
    'filter' => ['=ACTIVE' => 'Y'],
]);
while ($row = $result->fetch()) {
    $xmlId = $row['COLOR_XML_ID'];  // UF_XML_ID из b_iblock_element_property.VALUE
    // Отдельный запрос к HL-блоку (join в D7 ORM инфоблоков для directory не автоматический)
}
```

### Фильтрация элементов ИБ по значению directory-свойства

```php
// Legacy — фильтр по UF_XML_ID значению
CIBlockElement::GetList([], [
    'IBLOCK_ID'       => PRODUCTS_IBLOCK_ID,
    'PROPERTY_COLOR'  => 'red',            // значение = UF_XML_ID
], false, false, ['ID', 'NAME']);

// D7 ORM
ElementProductsTable::getList([
    'filter' => ['=COLOR.VALUE' => 'red'],  // VALUE = UF_XML_ID
    'select' => ['ID', 'NAME'],
]);
```

### Массовая загрузка: весь справочник в кеш

```php
// Загрузить весь HL-справочник в память — эффективнее чем N запросов в цикле
function loadDirectoryIndex(string $tableName): array
{
    $hlblock = \Bitrix\Highloadblock\HighloadBlockTable::getRow([
        'filter' => ['=TABLE_NAME' => $tableName],
    ]);
    if (!$hlblock) return [];

    $entity = \Bitrix\Highloadblock\HighloadBlockTable::compileEntity($hlblock);
    $dataClass = $entity->getDataClass();

    $index = [];
    $iterator = $dataClass::getList([
        'select' => ['ID', 'UF_XML_ID', 'UF_NAME', 'UF_FILE', 'UF_SORT'],
        'order'  => ['UF_SORT' => 'ASC'],
    ]);
    while ($row = $iterator->fetch()) {
        $index[$row['UF_XML_ID']] = $row;
    }
    return $index;
}

// Использование
$colors = loadDirectoryIndex('b_hlbd_color');

$res = CIBlockElement::GetList([], ['IBLOCK_ID' => PRODUCTS_IBLOCK_ID], false, false,
    ['ID', 'NAME', 'PROPERTY_COLOR']);
while ($el = $res->GetNext()) {
    $xmlId = $el['PROPERTY_COLOR_VALUE'];
    $color = $colors[$xmlId] ?? null;
    echo $color ? $color['UF_NAME'] : '—';
}
```

---

## Механизм 2 — UF-поле типа `hlblock` (USER_TYPE_ID='hlblock')

**Класс:** `CUserTypeHlblock` (модуль `highloadblock`)

**Что хранит:** числовой `ID` HL-записи (int).

**Где хранится:** зависит от сущности и кратности поля. В текущем core `CUserTypeHlblock` даёт `BASE_TYPE_INT`, а точные таблицы надо смотреть по конкретной сущности: single-value может лежать в основной/UTS-структуре, multiple — в UTM-таблице.

**Настройки:** `SETTINGS['HLBLOCK_ID']` = ID HL-блока, `SETTINGS['HLFIELD_ID']` = ID поля HL для отображения в списке.

**Для чего используют:** произвольные связи сущность → HL-запись, когда нужен `int` ID и/или автоматический `_REF`.

**Регистрация UF:** `ENTITY_ID` зависит от сущности. Не предполагай `'IBLOCK_ELEMENT'` вслепую. Для разделов в текущем core типичный паттерн — `IBLOCK_<IBLOCK_ID>_SECTION`, для HL-сущностей — `HLBLOCK_<ID>`.

> Поле называется `UF_BRAND`, `UF_PRODUCER` и т.д. — с префиксом `UF_`.

### Чтение через legacy

```php
global $USER_FIELD_MANAGER;

// Получить UF-значения элемента ИБ
$ufValues = $USER_FIELD_MANAGER->GetUserFields('IBLOCK_ELEMENT', $elementId, LANGUAGE_ID);
$hlRecordId = $ufValues['UF_BRAND']['VALUE'];  // int — ID HL-записи

// Получить HL-запись по ID
$hlblock = \Bitrix\Highloadblock\HighloadBlockTable::getById($hlblockId)->fetch();
$entity  = \Bitrix\Highloadblock\HighloadBlockTable::compileEntity($hlblock);
$dataClass = $entity->getDataClass();

$brandRecord = $dataClass::getById($hlRecordId)->fetch();
echo $brandRecord['UF_NAME'];
```

### Чтение через D7 ORM — автоматический Reference (_REF)

`CUserTypeHlblock::getEntityReferences()` автоматически добавляет relation `UF_BRAND_REF` в скомпилированную сущность инфоблока. Работает в `ElementV2Table`.

```php
use Bitrix\Iblock\Elements\ElementProductsTable; // VERSION=2, API_CODE='products'

$result = ElementProductsTable::getList([
    'select' => [
        'ID',
        'NAME',
        'UF_BRAND',                         // числовой ID HL-записи
        'BRAND_NAME'  => 'UF_BRAND_REF.UF_NAME',   // JOIN к HL-блоку!
        'BRAND_LOGO'  => 'UF_BRAND_REF.UF_LOGO',   // файл
        'BRAND_XML'   => 'UF_BRAND_REF.UF_XML_ID',
    ],
    'filter' => ['=ACTIVE' => 'Y'],
    'order'  => ['SORT' => 'ASC'],
]);
while ($row = $result->fetch()) {
    echo $row['NAME'] . ' — ' . $row['BRAND_NAME'];
}
```

> **Gotcha:** `UF_BRAND_REF` работает только в `ElementV2Table` (VERSION=2). В legacy ORM (`ElementV1Table`) автоматический reference не добавляется.

### Фильтр по UF_hlblock в D7 ORM

```php
ElementProductsTable::getList([
    'filter' => ['=UF_BRAND' => 5],           // по ID HL-записи
    'select' => ['ID', 'NAME', 'UF_BRAND'],
]);

// Фильтр по полю HL-записи (через _REF)
ElementProductsTable::getList([
    'filter' => ['=UF_BRAND_REF.UF_XML_ID' => 'nike'],
    'select' => ['ID', 'NAME', 'BRAND_NAME' => 'UF_BRAND_REF.UF_NAME'],
]);
```

### Множественное UF-поле типа hlblock

Если `MULTIPLE='Y'` — значения хранятся в UTM-таблице `b_utm_iblock_element.UF_BRAND[]`.

```php
// Через fetchObject + коллекцию
$obj = ElementProductsTable::query()
    ->setSelect(['ID', 'NAME', 'UF_BRANDS'])
    ->setFilter(['=ACTIVE' => 'Y'])
    ->fetchObject();

foreach ($obj->getUfBrands() as $brandId) {
    // каждый $brandId — int ID HL-записи
}

// Через runtime Reference + множественную связь
// Сложнее — проще два запроса
```

---

## Механизм 3 — Числовое/строковое свойство (ручная связь)

Встречается в старых проектах: обычное свойство `TYPE_NUMBER` или `TYPE_STRING`, в котором вручную хранится ID HL-записи. Никакого автоматического join-а нет.

```php
// Чтение
$el = CIBlockElement::GetByID($id)->GetNext();
$hlId = (int)$el['PROPERTY_HL_REF_VALUE'];

// Затем отдельный запрос к HL
$hlblock = \Bitrix\Highloadblock\HighloadBlockTable::getById($hlblockId)->fetch();
$entity  = \Bitrix\Highloadblock\HighloadBlockTable::compileEntity($hlblock);
$dataClass = $entity->getDataClass();
$row = $dataClass::getById($hlId)->fetch();
```

---

## Паттерн AbstractOrmRepository и связь с HL

`AbstractOrmRepository` — кастомный базовый класс, типичный в D7-проектах. Он оборачивает `DataManager::getList()` и предоставляет репозиторный интерфейс.

### Типичная реализация

```php
abstract class AbstractOrmRepository
{
    abstract protected function getDataClass(): string; // вернуть FQN DataManager

    public function findById(int $id): ?array
    {
        return $this->getDataClass()::getById($id)->fetch() ?: null;
    }

    public function findAll(array $filter = [], array $select = ['*'], array $order = ['ID' => 'ASC']): array
    {
        return $this->getDataClass()::getList([
            'filter' => $filter,
            'select' => $select,
            'order'  => $order,
        ])->fetchAll();
    }

    public function findOne(array $filter, array $select = ['*']): ?array
    {
        return $this->getDataClass()::getRow([
            'filter' => $filter,
            'select' => $select,
        ]);
    }
}
```

### Репозиторий инфоблока с HL-связью

Если базовый класс наследует `AbstractOrmRepository` и обёртывает `ElementProductsTable`, подключить HL-поля через `_REF`:

```php
use Bitrix\Iblock\Elements\ElementProductsTable;

class ProductRepository extends AbstractOrmRepository
{
    protected function getDataClass(): string
    {
        return ElementProductsTable::class;
    }

    // Список продуктов с данными HL-бренда (VERSION=2, UF_BRAND поле hlblock-типа)
    public function findActiveWithBrand(array $filter = []): array
    {
        return ElementProductsTable::getList([
            'select' => [
                'ID', 'NAME', 'CODE', 'SORT',
                'PREVIEW_TEXT',
                'UF_BRAND',
                'BRAND_NAME' => 'UF_BRAND_REF.UF_NAME',
                'BRAND_LOGO' => 'UF_BRAND_REF.UF_LOGO',
            ],
            'filter' => array_merge(['=ACTIVE' => 'Y'], $filter),
            'order'  => ['SORT' => 'ASC'],
        ])->fetchAll();
    }

    // Альтернатива: отдельный запрос к HL (если VERSION=1 или нет _REF)
    public function findActiveWithBrandSeparate(): array
    {
        // Шаг 1: элементы
        $elements = ElementProductsTable::getList([
            'select' => ['ID', 'NAME', 'UF_BRAND'],
            'filter' => ['=ACTIVE' => 'Y'],
        ])->fetchAll();

        // Шаг 2: собрать уникальные ID брендов
        $brandIds = array_unique(array_filter(array_column($elements, 'UF_BRAND')));

        if (empty($brandIds)) {
            return $elements;
        }

        // Шаг 3: один запрос к HL
        $hlblock  = \Bitrix\Highloadblock\HighloadBlockTable::getRow(
            ['filter' => ['=NAME' => 'Brands']]
        );
        $entity   = \Bitrix\Highloadblock\HighloadBlockTable::compileEntity($hlblock);
        $dataClass = $entity->getDataClass();

        $brandsIndex = [];
        $iterator = $dataClass::getList([
            'filter' => ['=ID' => $brandIds],
            'select' => ['ID', 'UF_NAME', 'UF_LOGO'],
        ]);
        while ($row = $iterator->fetch()) {
            $brandsIndex[(int)$row['ID']] = $row;
        }

        // Шаг 4: смержить
        foreach ($elements as &$el) {
            $el['BRAND'] = $brandsIndex[(int)($el['UF_BRAND'] ?? 0)] ?? null;
        }
        unset($el);

        return $elements;
    }
}
```

### Репозиторий со связью через directory-свойство

```php
class ProductRepository extends AbstractOrmRepository
{
    protected function getDataClass(): string
    {
        return ElementProductsTable::class;
    }

    // COLOR — свойство типа directory, хранит UF_XML_ID
    public function findActiveWithColor(): array
    {
        // Шаг 1: загрузить весь справочник цветов
        $colorsHlblock = \Bitrix\Highloadblock\HighloadBlockTable::getRow([
            'filter' => ['=TABLE_NAME' => 'b_hlbd_color'],
        ]);
        $colorsEntity = \Bitrix\Highloadblock\HighloadBlockTable::compileEntity($colorsHlblock);
        $colorsClass  = $colorsEntity->getDataClass();

        $colorsIndex = [];
        $iterator = $colorsClass::getList([
            'select' => ['ID', 'UF_XML_ID', 'UF_NAME', 'UF_FILE'],
        ]);
        while ($row = $iterator->fetch()) {
            $colorsIndex[$row['UF_XML_ID']] = $row;
        }

        // Шаг 2: элементы с property COLOR
        $elements = ElementProductsTable::getList([
            'select' => ['ID', 'NAME', 'COLOR_XML_ID' => 'COLOR.VALUE'],
            'filter' => ['=ACTIVE' => 'Y'],
        ])->fetchAll();

        // Шаг 3: смержить
        foreach ($elements as &$el) {
            $xmlId = $el['COLOR_XML_ID'] ?? '';
            $el['COLOR'] = $colorsIndex[$xmlId] ?? null;
        }
        unset($el);

        return $elements;
    }
}
```

---

## ORM Runtime Reference: join HL к ИБ в одном запросе

Когда нет автоматического `_REF` (VERSION=1 или directory-свойство), можно добавить runtime Reference.

### Для UF_BRAND (хранит int ID)

```php
use Bitrix\Main\ORM\Fields\Relations\Reference;
use Bitrix\Main\ORM\Query\Join;
use Bitrix\Highloadblock\HighloadBlockTable;
use Bitrix\Iblock\Elements\ElementProductsTable;

// Компилируем сущность HL
$hlblock   = HighloadBlockTable::getRow(['filter' => ['=NAME' => 'Brands']]);
$hlEntity  = HighloadBlockTable::compileEntity($hlblock);

$result = ElementProductsTable::getList([
    'select' => [
        'ID', 'NAME',
        'BRAND_NAME' => 'BRAND_HL.UF_NAME',
        'BRAND_LOGO' => 'BRAND_HL.UF_LOGO',
    ],
    'runtime' => [
        new Reference(
            'BRAND_HL',
            $hlEntity,
            Join::on('this.UF_BRAND', 'ref.ID'),
            ['join_type' => 'LEFT']
        ),
    ],
    'filter' => ['=ACTIVE' => 'Y'],
]);
```

### Для directory-свойства (хранит UF_XML_ID строку)

```php
$colorsHlblock = HighloadBlockTable::getRow(['filter' => ['=TABLE_NAME' => 'b_hlbd_color']]);
$colorsEntity  = HighloadBlockTable::compileEntity($colorsHlblock);

$result = ElementProductsTable::getList([
    'select' => [
        'ID', 'NAME',
        'COLOR_XML_ID' => 'COLOR.VALUE',
        'COLOR_NAME'   => 'COLOR_HL.UF_NAME',
    ],
    'runtime' => [
        new Reference(
            'COLOR_HL',
            $colorsEntity,
            Join::on('this.COLOR.VALUE', 'ref.UF_XML_ID'),  // string = string
            ['join_type' => 'LEFT']
        ),
    ],
    'filter' => ['=ACTIVE' => 'Y'],
]);
```

> **Gotcha:** runtime Reference на свойство `COLOR.VALUE` работает только если `COLOR` уже является ORM-relation в скомпилированной сущности. Если нет — придётся делать два запроса.

---

## Как определить какой механизм используется в проекте

```php
use Bitrix\Iblock\PropertyTable;

// Проверить тип свойства в ИБ
$prop = PropertyTable::getRow([
    'filter' => ['=IBLOCK_ID' => PRODUCTS_IBLOCK_ID, '=CODE' => 'COLOR'],
    'select' => ['PROPERTY_TYPE', 'USER_TYPE', 'USER_TYPE_SETTINGS', 'LINK_IBLOCK_ID'],
]);

if ($prop) {
    // PROPERTY_TYPE='S', USER_TYPE='directory' → механизм 1
    //   $prop['USER_TYPE_SETTINGS']['TABLE_NAME'] = 'b_hlbd_color'
    //   VALUE хранит UF_XML_ID (строку)

    // PROPERTY_TYPE='E' → это не HL, это привязка к другому ЭЛЕМЕНТУ ИБ
    //   $prop['LINK_IBLOCK_ID'] = ID связанного ИБ
}

// Проверить UF-поля на конкретной UF-enabled сущности
global $USER_FIELD_MANAGER;
$entityId = 'IBLOCK_' . PRODUCTS_IBLOCK_ID . '_SECTION';
$ufs = $USER_FIELD_MANAGER->GetUserFields($entityId, 0, LANGUAGE_ID);
foreach ($ufs as $uf) {
    if ($uf['USER_TYPE_ID'] === 'hlblock') {
        // Механизм 2: UF_* поле
        // $uf['SETTINGS']['HLBLOCK_ID'] — ID HL-блока
        // $uf['FIELD_NAME'] = 'UF_BRAND'
        // VALUE хранит int ID HL-записи
    }
}
```

---

## Краткая таблица сравнения

| | directory (USER_TYPE) | hlblock (UF тип) | ручная (число/строка) |
|---|---|---|---|
| Где определяется | Свойство ИБ | UF-поле сущности | Свойство ИБ |
| Хранит | `UF_XML_ID` (строка) | `ID` (int) | ID или код (любой) |
| ORM-join | только runtime | `_REF` авто (v2) | только runtime |
| Фильтр по значению | `=PROPERTY_CODE => 'xml_id'` | `=UF_FIELD => 42` | `=PROPERTY_CODE => 42` |
| Доступ в legacy | `GetNext()['PROPERTY_CODE_VALUE']` | `USER_FIELD_MANAGER->GetUserFields` | `GetNext()['PROPERTY_CODE_VALUE']` |
| Доступ в D7 ORM | `CODE.VALUE` | `UF_FIELD` + `UF_FIELD_REF.*` | `CODE.VALUE` |

---

## Gotchas

- **directory хранит UF_XML_ID, не ID** — частая ошибка: ищут HL-запись по `ID = $value` вместо `UF_XML_ID = $value`
- **`_REF` добавляется через `CUserTypeHlblock::getEntityReferences()`** — не угадывай имя join-а, смотри реальную compiled entity
- **ENTITY_ID зависит от сущности** — сначала выясни, где живёт UF-поле в конкретном проекте, потом уже читай/пиши его
- **`compileEntity` по TABLE_NAME** — всегда ищи HL-блок через `HighloadBlockTable::getRow(['filter'=>['=TABLE_NAME'=>...]])`, затем `compileEntity` с полученным массивом
- **Runtime Reference на `CODE.VALUE`** — работает только если `CODE` — объявленный relations в скомпилированной сущности; если CODE ещё не в select — join не встроится
- **N+1 в цикле** — никогда не делай запрос к HL внутри foreach элементов. Загружай весь индекс один раз (загрузка всех записей HL), потом смерживай в памяти
- **`HighloadBlockTable::compileEntityId($id)`** возвращает строку `'HLBLOCK_42'` — это ENTITY_ID для UF-полей самого HL-блока, не элементов ИБ
