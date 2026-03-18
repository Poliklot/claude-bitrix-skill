# Bitrix Инфоблоки и HL-блоки — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с инфоблоками (CIBlockElement, CIBlockSection), D7 ORM для инфоблоков (IblockTable::compileEntity, API_CODE), свойствами (PropertyTable), или высоконагруженными блоками (HighloadBlockTable).

## Содержание
- CIBlockElement::GetList — полная сигнатура, фильтры, select, пагинация
- CIBlockElement: Add/Update/Delete/GetByID
- CIBlockSection::GetList, Add
- D7 ORM инфоблоков: compileEntity, API_CODE, class naming
- Доступ к свойствам: одиночные (fetch+алиас), множественные (fetchObject+коллекция)
- PropertyTable: типы (S/N/F/E/G/L), USER_TYPE, PropertyEnumerationTable
- ElementPropertyTable: прямой доступ к значениям
- HL-блоки: compileEntity, UTM-таблицы, CRUD
- Инфоблок события: OnBefore/AfterIBlockElement*
- Gotchas

---

## Инфоблоки — Legacy API

### CIBlockElement::GetList

```php
\Bitrix\Main\Loader::includeModule('iblock');

// Сигнатура:
// GetList($arOrder, $arFilter, $arGroupBy, $arNavStartParams, $arSelectFields)

$res = CIBlockElement::GetList(
    ['SORT' => 'ASC', 'ID' => 'DESC'],    // order
    [
        'IBLOCK_ID'      => 5,             // обязательно
        'ACTIVE'         => 'Y',           // только активные
        '>=SORT'         => 100,           // операторы: =, !=, >, <, >=, <=, %
        'SECTION_ID'     => 10,            // прямые дети раздела (без вложенных)
        'INCLUDE_SUBSECTIONS' => 'Y',      // включить вложенные разделы
        'PROPERTY_COLOR' => 'red',         // значение свойства
        'PROPERTY_SIZE'  => [42, 44],      // массив значений (IN)
    ],
    false,                                 // groupBy: false = нет, [] = COUNT
    ['nPageSize' => 20, 'iNumPage' => 1],  // пагинация; nTopCount = LIMIT без пагинации
    [
        'ID', 'NAME', 'CODE', 'SORT',
        'PREVIEW_TEXT', 'DETAIL_TEXT',
        'PREVIEW_PICTURE', 'DETAIL_PICTURE',
        'DATE_ACTIVE_FROM', 'DATE_ACTIVE_TO',
        'IBLOCK_SECTION_ID', 'XML_ID',
        'PROPERTY_COLOR',                  // конкретное свойство по CODE
        'PROPERTY_123',                    // или по ID
        'PROPERTY_*',                      // все свойства (дорого!)
    ]
);

while ($el = $res->GetNext()) {
    // Скалярное свойство
    echo $el['PROPERTY_COLOR_VALUE'];       // значение
    echo $el['PROPERTY_COLOR_ENUM_ID'];     // ID пункта списка (тип L)
    echo $el['PROPERTY_COLOR_VALUE_ID'];    // ID строки b_iblock_element_property

    // Файловое свойство (TYPE_FILE): VALUE = ID файла
    $fileId = $el['PROPERTY_PHOTO_VALUE'];
    $file = CFile::GetFileArray($fileId);

    // Привязка к элементу (TYPE_ELEMENT): VALUE = ID элемента
    $linkedId = $el['PROPERTY_RELATED_VALUE'];
}

// Только COUNT
$count = CIBlockElement::GetList([], ['IBLOCK_ID' => 5, 'ACTIVE' => 'Y'], false, false, []);
// При groupBy=[] (пустой массив) → возвращает CIBlockResult с полем CNT
$res2 = CIBlockElement::GetList([], ['IBLOCK_ID' => 5], []);
$row = $res2->Fetch();
echo $row['CNT'];
```

### Множественные свойства в GetList

```php
// При MULTIPLE='Y': GetNext() возвращает PROPERTY_CODE_VALUE как массив
$el = $res->GetNext();
foreach ((array)$el['PROPERTY_TAGS_VALUE'] as $tag) {
    echo $tag;
}
// Полный массив данных (все подполя) через GetNextElement
while ($obj = $res->GetNextElement()) {
    $arFields = $obj->GetFields();
    $arProps  = $obj->GetProperties(); // все свойства с полной структурой
    foreach ($arProps['TAGS']['VALUE'] as $val) {
        echo $val;
    }
}
```

### CIBlockElement — Add / Update / Delete / GetByID

```php
$el = new CIBlockElement();

// Add — возвращает int ID или false при ошибке
$id = $el->Add([
    'IBLOCK_ID'       => 5,
    'NAME'            => 'Заголовок',
    'ACTIVE'          => 'Y',
    'SORT'            => 500,
    'CODE'            => 'my-slug',               // символьный код
    'PREVIEW_TEXT'    => 'Краткое описание',
    'PREVIEW_TEXT_TYPE' => 'text',                 // 'text' | 'html'
    'DETAIL_TEXT'     => '<p>Полный текст</p>',
    'DETAIL_TEXT_TYPE' => 'html',
    'IBLOCK_SECTION_ID' => 10,                    // один раздел
    'IBLOCK_SECTION'  => [10, 15],                // несколько разделов
    'PROPERTY_VALUES' => [
        'COLOR'    => 'red',                      // по CODE свойства
        'TAGS'     => ['php', 'bitrix'],           // множественное
        'PHOTO'    => CFile::MakeFileArray('/path/to/file.jpg'), // файл
        'RELATED'  => 42,                         // привязка к элементу (ID)
    ],
]);
if (!$id) {
    echo $el->LAST_ERROR;
}

// Update — возвращает bool
$ok = $el->Update($id, ['NAME' => 'Новое имя', 'ACTIVE' => 'N']);

// Установить значения свойств после Add/Update
CIBlockElement::SetPropertyValuesEx($id, 5, [
    'COLOR' => 'blue',
    'TAGS'  => ['bitrix24', 'd7'],
]);

// GetByID — одиночный элемент
$res = CIBlockElement::GetByID($id);
$arEl = $res->GetNext();   // или ->Fetch() — без урлов

// Delete
CIBlockElement::Delete($id); // удаляет элемент + все свойства + файлы
```

### CIBlockSection — GetList / Add

```php
// Сигнатура: GetList($arOrder, $arFilter, $bIncCnt, $arSelect, $arNavStartParams)
$res = CIBlockSection::GetList(
    ['SORT' => 'ASC', 'LEFT_MARGIN' => 'ASC'],
    [
        'IBLOCK_ID'   => 5,
        'ACTIVE'      => 'Y',
        'GLOBAL_ACTIVE' => 'Y',           // активна вся цепочка родителей
        'SECTION_ID'  => 0,               // корневые разделы (0 = корень)
        // DEPTH_LEVEL, LEFT_MARGIN, RIGHT_MARGIN, CNT
    ],
    true,                                 // bIncCnt — включить ELEMENT_CNT, SECTION_CNT
    ['ID', 'NAME', 'CODE', 'SORT', 'DEPTH_LEVEL',
     'SECTION_PAGE_URL', 'LEFT_MARGIN', 'RIGHT_MARGIN',
     'ELEMENT_CNT',                       // только если bIncCnt=true
    ]
);
while ($sec = $res->GetNext()) {
    echo $sec['NAME'], ' (', $sec['DEPTH_LEVEL'], ')';
}

// Add
$sec = new CIBlockSection();
$secId = $sec->Add([
    'IBLOCK_ID'        => 5,
    'IBLOCK_SECTION_ID' => 0,  // родитель (0 = корень)
    'NAME'             => 'Раздел',
    'CODE'             => 'section-slug',
    'ACTIVE'           => 'Y',
    'SORT'             => 100,
]);
```

---

## Инфоблоки — D7 ORM (`VERSION` 1 или 2)

### Почему D7 ORM для инфоблоков особенный

Bitrix компилирует **персональный класс DataManager** для каждого инфоблока с установленным `API_CODE`. Это происходит через `IblockTable::compileEntity()`. Класс наследует `ElementV1Table` (VERSION=1, общая таблица `b_iblock_element_property`) или `ElementV2Table` (VERSION=2, раздельные таблицы `b_iblock_element_prop_{ID}`).

### Требования и настройка

1. Инфоблок должен иметь заполненное поле **API_CODE** (в разделе настроек инфоблока)
2. Все свойства, доступные в ORM, должны иметь заполненный **CODE** (символьный код)
3. Модуль `iblock` должен быть подключён через `Loader::includeModule`

### Получение класса и базовый запрос

```php
use Bitrix\Main\Loader;
use Bitrix\Iblock\IblockTable;

Loader::includeModule('iblock');

// Вариант 1 — автозагрузка по namespace (если API_CODE = 'news')
// Класс: Bitrix\Iblock\Elements\ElementNewsTable
use Bitrix\Iblock\Elements\ElementNewsTable;

$result = ElementNewsTable::getList([
    'select' => ['ID', 'NAME', 'CODE', 'SORT', 'PREVIEW_TEXT', 'ACTIVE'],
    'filter' => ['=ACTIVE' => 'Y'],
    'order'  => ['SORT' => 'ASC'],
    'limit'  => 20,
]);
while ($row = $result->fetch()) {
    echo $row['ID'], ' — ', $row['NAME'];
}

// Вариант 2 — явная компиляция (если API_CODE неизвестен заранее)
$entity = IblockTable::compileEntity('news'); // 'news' = API_CODE (lowercase)
// IblockTable::compileEntity принимает строку (API_CODE) или объект Iblock
$dataClass = $entity->getDataClass(); // строка с FQN класса
$result = $dataClass::getList([...]);

// Вариант 3 — wakeUp по ID (наиболее правильный D7-способ когда знаешь ID, но не API_CODE)
use Bitrix\Iblock\Iblock;

$entityDataClass = Iblock::wakeUp($iblockId)->getEntityDataClass();
// getEntityDataClass() возвращает FQN класса (строка) или null если нет API_CODE
// Это эквивалент IblockTable::compileEntity(API_CODE)->getDataClass()
// но работает напрямую по ID без предварительного получения API_CODE

// Всегда проверяй результат — null если у инфоблока не задан API_CODE
if ($entityDataClass === null) {
    throw new \RuntimeException("Инфоблок #$iblockId не имеет API_CODE — D7 ORM недоступен");
}

$result = $entityDataClass::getList([
    'select' => ['ID', 'NAME', 'CODE'],
    'filter' => ['=ACTIVE' => 'Y', '=ID' => $productId],
    'limit'  => 1,
]);
$product = $result->fetch();
```

**Namespace и имя класса:**

| API_CODE | Namespace | Класс |
|----------|-----------|-------|
| `news` | `Bitrix\Iblock\Elements` | `ElementNewsTable` |
| `catalog` | `Bitrix\Iblock\Elements` | `ElementCatalogTable` |
| `my_products` | `Bitrix\Iblock\Elements` | `ElementMy_productsTable` |

Формула: `Element` + `ucfirst($apiCode)` + `Table`

### Доступ к свойствам элементов

**Одиночное свойство (MULTIPLE='N'):**

```php
// В select указываем алиас => 'КОД_СВОЙСТВА.VALUE'
$result = ElementNewsTable::getList([
    'select' => [
        'ID', 'NAME',
        'PRICE'        => 'PRICE.VALUE',        // обычное значение
        'PRICE_DESC'   => 'PRICE.DESCRIPTION',  // описание к свойству
        'COLOR_ENUM'   => 'COLOR.ITEM',         // текст пункта списка (тип L)
        'COLOR_ID'     => 'COLOR.ITEM_ID',      // ID пункта списка
    ],
    'filter' => ['=ACTIVE' => 'Y', '>PRICE.VALUE' => 1000],
    'order'  => ['PRICE.VALUE' => 'ASC'],
]);
while ($row = $result->fetch()) {
    echo $row['PRICE'];      // значение свойства PRICE
    echo $row['COLOR_ENUM']; // текст пункта COLOR
}
```

**Множественное свойство (MULTIPLE='Y') — через fetchObject():**

```php
// Для множественных — нельзя использовать fetch(), нужен fetchObject()
$result = ElementNewsTable::getList([
    'select' => ['ID', 'NAME', 'TAGS'],  // TAGS = CODE множественного свойства
    'filter' => ['=ACTIVE' => 'Y'],
]);
while ($obj = $result->fetchObject()) {
    echo $obj->getName();  // геттеры для полей
    $tagsCollection = $obj->getTags(); // коллекция PropertyValue объектов
    foreach ($tagsCollection as $tagValue) {
        echo $tagValue->getValue();
    }
}
```

**Фильтрация по свойству:**

```php
// Точное совпадение значения
ElementNewsTable::getList([
    'filter' => ['=COLOR.VALUE' => 'red'],
]);

// Множественное — через exists (если есть хоть одно такое значение)
ElementNewsTable::getList([
    'filter' => ['=TAGS.VALUE' => 'php'],
]);

// Диапазон числового свойства
ElementNewsTable::getList([
    'filter' => ['>=PRICE.VALUE' => 100, '<=PRICE.VALUE' => 500],
]);

// Привязка к разделу
ElementNewsTable::getList([
    'filter' => ['=IBLOCK_SECTION.CODE' => 'news-section'],
]);
```

### PropertyTable — работа со свойствами инфоблока

```php
use Bitrix\Iblock\PropertyTable;

// Типы свойств:
// PropertyTable::TYPE_STRING  = 'S'  — строка, HTML, дата (через USER_TYPE)
// PropertyTable::TYPE_NUMBER  = 'N'  — число
// PropertyTable::TYPE_FILE    = 'F'  — файл
// PropertyTable::TYPE_ELEMENT = 'E'  — привязка к элементу ИБ
// PropertyTable::TYPE_SECTION = 'G'  — привязка к разделу ИБ
// PropertyTable::TYPE_LIST    = 'L'  — список (enum)

// USER_TYPE для TYPE_STRING:
// PropertyTable::USER_TYPE_DATE     = 'Date'
// PropertyTable::USER_TYPE_DATETIME = 'DateTime'
// PropertyTable::USER_TYPE_HTML     = 'HTML'

// Получить все свойства инфоблока
$res = PropertyTable::getList([
    'select' => ['ID', 'NAME', 'CODE', 'PROPERTY_TYPE', 'MULTIPLE',
                 'USER_TYPE', 'LINK_IBLOCK_ID', 'SORT', 'IS_REQUIRED'],
    'filter' => ['=IBLOCK_ID' => 5, '=ACTIVE' => 'Y'],
    'order'  => ['SORT' => 'ASC'],
]);
while ($prop = $res->fetch()) {
    echo $prop['CODE'], ': ', $prop['PROPERTY_TYPE'];
    if ($prop['PROPERTY_TYPE'] === PropertyTable::TYPE_LIST) {
        // получить пункты списка
        $enums = \Bitrix\Iblock\PropertyEnumerationTable::getList([
            'filter' => ['=PROPERTY_ID' => $prop['ID']],
            'order'  => ['SORT' => 'ASC'],
        ]);
    }
}
```

### ElementPropertyTable — прямой доступ к значениям

```php
use Bitrix\Iblock\ElementPropertyTable;

// b_iblock_element_property — таблица значений VERSION=1 и множественных VERSION=2
$res = ElementPropertyTable::getList([
    'select' => ['IBLOCK_ELEMENT_ID', 'VALUE', 'VALUE_NUM', 'VALUE_ENUM', 'DESCRIPTION'],
    'filter' => [
        '=IBLOCK_PROPERTY_ID' => 42,   // ID свойства
        '=IBLOCK_ELEMENT_ID'  => 100,  // ID элемента
    ],
]);
// VALUE — текстовое значение
// VALUE_NUM — числовое значение (для TYPE_NUMBER, TYPE_FILE, TYPE_ELEMENT, TYPE_SECTION)
// VALUE_ENUM — ID пункта списка (для TYPE_LIST)
```

---

## HL-блоки (Highloadblock)

### Создание и использование HL-блока

```php
use Bitrix\Main\Loader;
use Bitrix\Highloadblock\HighloadBlockTable;

Loader::includeModule('highloadblock');

// Получить класс HL-блока по ID
$hlblock = HighloadBlockTable::getById($hlId)->fetch();
$entity  = HighloadBlockTable::compileEntity($hlblock);
// compileEntity($hlblock) — принимает массив (fetch) или объект, не int!
// Чтобы по ID:
$entity = HighloadBlockTable::compileEntity(
    HighloadBlockTable::getById($hlId)->fetch()
);
$entityClass = $entity->getDataClass(); // строка FQN

// По имени — если NAME='Colors', namespace Bitrix\Highloadblock
// Можно и через: HighloadBlockTable::getList(['filter' => ['=NAME' => 'Colors']])

// CRUD
$result = $entityClass::getList([
    'select' => ['*'],           // UF_* поля
    'filter' => ['=UF_ACTIVE' => 'Y'],
    'order'  => ['UF_SORT' => 'ASC'],
]);
while ($row = $result->fetch()) {
    echo $row['UF_NAME'];
}

// Add
$entityClass::add(['UF_NAME' => 'Красный', 'UF_CODE' => 'red', 'UF_ACTIVE' => 1]);

// Update
$entityClass::update($id, ['UF_ACTIVE' => 0]);

// Delete
$entityClass::delete($id);
```

### Множественные поля HL-блока (UTM-таблицы)

Поле типа "список" с `MULTIPLE='Y'` хранится в отдельной таблице `{TABLE_NAME}_{FIELD_CODE}` (не в основной). Первичный ключ — `ID`, внешний ключ — `OBJECT_ID` (ID записи HL-блока), `VALUE` — значение.

```php
// Если TABLE_NAME='b_hl_colors', поле UF_TAGS (множественное)
// → таблица: b_hl_colors_uf_tags
// Получить через relation (добавляется автоматически):
$obj = $entityClass::getByPrimary($id, [
    'select' => ['ID', 'UF_TAGS'],
])->fetchObject();
foreach ($obj->getUfTags() as $tagItem) {
    echo $tagItem->getValue();
}
```

### Получение класса HL-блока по символьному коду (по NAME)

```php
$hlblocks = HighloadBlockTable::getList([
    'filter' => ['=NAME' => 'Colors'],
])->fetch();
if ($hlblocks) {
    $entity = HighloadBlockTable::compileEntity($hlblocks);
    $entityClass = $entity->getDataClass();
}
```

---

## Инфоблоки — события

Все события инфоблоков (`OnBeforeIBlockElementAdd` и пр.) — **legacy**: параметры передаются по ссылке. Для корректной модификации полей и отмены операции используй `addEventHandlerCompatible`, а не `addEventHandler`.

> `addEventHandler` (version=2) оборачивает параметры в объект `Event` — ссылка теряется, изменения не применяются. `addEventHandlerCompatible` (version=1) передаёт `$arFields` напрямую по ссылке.

```php
use Bitrix\Main\EventManager;

$em = EventManager::getInstance();

// Изменение полей ДО добавления — addEventHandlerCompatible + by-ref
$em->addEventHandlerCompatible(
    'iblock',
    'OnBeforeIBlockElementAdd',
    ['\MyVendor\MyModule\IblockHandler', 'onBeforeAdd']
);

// Действия ПОСЛЕ добавления (кеш, уведомления)
$em->addEventHandlerCompatible(
    'iblock',
    'OnAfterIBlockElementAdd',
    ['\MyVendor\MyModule\IblockHandler', 'onAfterAdd']
);

// Аналогично: OnBeforeIBlockElementUpdate, OnAfterIBlockElementUpdate,
//             OnBeforeIBlockElementDelete, OnAfterIBlockElementDelete
```

```php
namespace MyVendor\MyModule;

use Bitrix\Main\Application;

class IblockHandler
{
    /**
     * OnBefore* — $arFields по ссылке.
     * Отмена операции: global $APPLICATION; $APPLICATION->ThrowException('Ошибка');
     * После ThrowException ядро прочитает GetException() и вернёт false из Add/Update.
     */
    public static function onBeforeAdd(array &$arFields): void
    {
        // Фильтровать только нужный инфоблок
        if ((int)($arFields['IBLOCK_ID'] ?? 0) !== MY_IBLOCK_ID) {
            return;
        }

        // Нормализация полей — работает через ссылку
        $arFields['NAME'] = trim($arFields['NAME'] ?? '');
        $arFields['PREVIEW_TEXT'] = strip_tags($arFields['PREVIEW_TEXT'] ?? '');

        // Отменить добавление
        if (empty($arFields['NAME'])) {
            global $APPLICATION;
            $APPLICATION->ThrowException('Название обязательно');
            return;
        }
    }

    /**
     * OnAfter* — $arFields по ссылке; содержит ['ID'] = ID только что добавленного элемента.
     */
    public static function onAfterAdd(array &$arFields): void
    {
        if ((int)($arFields['IBLOCK_ID'] ?? 0) !== MY_IBLOCK_ID) {
            return;
        }

        $id = (int)($arFields['ID'] ?? 0);
        if (!$id) {
            return;
        }

        // Очистить тегированный кеш инфоблока
        Application::getInstance()->getTaggedCache()
            ->clearByTag('iblock_id_' . MY_IBLOCK_ID);
    }

    /**
     * OnBeforeIBlockElementDelete — $id (int) по ссылке, не массив!
     */
    public static function onBeforeDelete(int &$id): void
    {
        // Проверка перед удалением
        // Отмена: $APPLICATION->ThrowException('...')
    }
}
```

---

## Инфоблоки — Gotchas

- **`compileEntity()` не принимает int** — только строку API_CODE или объект `Iblock`. Для компиляции по ID: сначала `getById()->fetchObject()`, потом передай объект.
- **Без API_CODE — нет D7 ORM**. Поле `API_CODE` обязательно. Если не установлено, `getEntityDataClass()` вернёт null и триггернёт `E_USER_WARNING`.
- **VERSION=1 vs VERSION=2**: v1 — все значения в `b_iblock_element_property`; v2 — одиночные в `b_iblock_element_prop_{ID}`, множественные в `b_iblock_element_prop_m_{ID}`. ORM абстрагирует разницу, но важно для прямых SQL.
- **Множественные свойства в D7 ORM**: нельзя использовать `fetch()` если в select есть множественное свойство — получишь дубли строк. Используй `fetchObject()` + коллекцию.
- **Свойство без CODE** — не попадёт в скомпилированную сущность (цикл по `$property->getCode()` пропускает пустые).
- **`GetNext()` vs `Fetch()` в legacy**: `GetNext()` заменяет спецсимволы HTML, применяет шаблоны URL (`LIST_PAGE_URL`, `DETAIL_PAGE_URL`). `Fetch()` — сырые данные без замен.
- **`SetPropertyValues` vs `SetPropertyValuesEx`**: `SetPropertyValues` устанавливает по массиву `[PROP_ID => value]`; `SetPropertyValuesEx` — по `[PROP_CODE => value]` — предпочтителен.
- **HL-блок: `compileEntity` кеширует класс** в памяти — повторный вызов возвращает уже созданный класс, не пересоздаёт. Безопасно вызывать несколько раз.
- **HL UTM-таблицы**: при переименовании поля физическая таблица не переименовывается — остаётся со старым именем. При удалении поля — таблица удаляется.
- **`SECTION_ID` vs `IBLOCK_SECTION_ID` в GetList**: `SECTION_ID` — фильтрует по разделу (с учётом `INCLUDE_SUBSECTIONS`); в поле результата — `IBLOCK_SECTION_ID`.

---

