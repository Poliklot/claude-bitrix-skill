# Торговый каталог (модуль Catalog)

```php
use Bitrix\Main\Loader;
Loader::includeModule('catalog');
Loader::includeModule('iblock');
```

> Audit note: в текущем проверенном core модуль `catalog` в `www/bitrix/modules` не найден. Этот файл сейчас отложен до установки магазинного core и не должен быть активным маршрутом в текущей фазе проекта.

## Архитектура

Модуль `catalog` работает поверх инфоблоков:
- **Товар** — элемент инфоблока с типом `D7_PRODUCT_TYPE = 1` (простой) или `6` (с ТП)
- **Торговое предложение (SKU/offer)** — элемент дочернего инфоблока типа `2`
- **Цена** — таблица `b_catalog_price`, связана с товаром по `PRODUCT_ID`
- **Склад** — таблица `b_catalog_store`, остатки в `b_catalog_store_product`

---

## Цены

### Прочитать цену товара

```php
use Bitrix\Catalog\PriceTable;

// Получить все цены товара
$result = PriceTable::getList([
    'select' => ['ID', 'PRODUCT_ID', 'CATALOG_GROUP_ID', 'PRICE', 'CURRENCY', 'QUANTITY_FROM', 'QUANTITY_TO'],
    'filter' => ['=PRODUCT_ID' => $productId],
    'order'  => ['CATALOG_GROUP_ID' => 'ASC'],
]);
while ($row = $result->fetch()) {
    // $row['CATALOG_GROUP_ID'] — ID типа цены (прайс-листа)
    // $row['PRICE'] — цена
    // $row['CURRENCY'] — валюта
}
```

### Получить цену для текущего пользователя (с учётом группы/скидок)

```php
// Массив цен по всем типам для одного товара
$prices = \CCatalogProduct::GetOptimalPrice(
    $productId,
    1,                         // количество
    $USER->GetUserGroupArray(), // группы пользователя
    'N',                       // 'N' — без повторного расчёта
    [],                        // дополнительные параметры
    SITE_ID,
    []
);
// $prices['PRICE']['PRICE'] — итоговая цена
// $prices['PRICE']['DISCOUNT_PRICE'] — цена до скидки
// $prices['PRICE']['PERCENT'] — % скидки
```

### Установить / обновить цену

```php
use Bitrix\Catalog\PriceTable;

// Найти существующую цену
$existing = PriceTable::getList([
    'filter' => ['=PRODUCT_ID' => $productId, '=CATALOG_GROUP_ID' => 1],
])->fetch();

if ($existing) {
    // Обновить
    $result = PriceTable::update($existing['ID'], [
        'PRICE'    => 1500.00,
        'CURRENCY' => 'RUB',
    ]);
} else {
    // Создать
    $result = PriceTable::add([
        'PRODUCT_ID'       => $productId,
        'CATALOG_GROUP_ID' => 1,    // ID прайс-листа
        'PRICE'            => 1500.00,
        'CURRENCY'         => 'RUB',
        'QUANTITY_FROM'    => null, // нет ограничения по количеству
        'QUANTITY_TO'      => null,
    ]);
}

if (!$result->isSuccess()) {
    // обработка ошибок
}
```

### Типы цен (прайс-листы)

```php
use Bitrix\Catalog\GroupTable;

$result = GroupTable::getList([
    'select' => ['ID', 'NAME', 'BASE'],
    'order'  => ['SORT' => 'ASC'],
]);
while ($row = $result->fetch()) {
    // $row['BASE'] == 'Y' — базовый прайс-лист
}
```

---

## Торговые предложения (SKU / Offers)

Торговые предложения — это элементы **дочернего инфоблока** с типом продукта `2`. Связь с родительским товаром через свойство типа `E` (привязка к элементу).

### Получить список ТП для товара

```php
// Найти инфоблок ТП
$offersIblockId = \CCatalogSKU::GetInfoByProductIBlock($productIblockId);
// $offersIblockId['IBLOCK_ID'] — ID инфоблока ТП
// $offersIblockId['SKU_PROPERTY_ID'] — ID свойства-связки

// Получить ТП для конкретного товара
$res = CIBlockElement::GetList(
    ['SORT' => 'ASC'],
    [
        'IBLOCK_ID'                              => $offersIblockId['IBLOCK_ID'],
        'ACTIVE'                                 => 'Y',
        'PROPERTY_' . $offersIblockId['SKU_PROPERTY_ID'] => $productId,
    ],
    false,
    false,
    ['ID', 'NAME', 'PROPERTY_COLOR', 'PROPERTY_SIZE']
);
while ($offer = $res->GetNext()) {
    $offerId = $offer['ID'];
    // Получить цену ТП
    $prices = PriceTable::getList(['filter' => ['=PRODUCT_ID' => $offerId]])->fetch();
}
```

### D7 для инфоблока с API_CODE

```php
// Если инфоблок ТП имеет API_CODE='catalog_offers':
use Bitrix\Iblock\Elements\ElementCatalogOffersTable;

$result = ElementCatalogOffersTable::getList([
    'select' => ['ID', 'NAME', 'COLOR' => 'COLOR.VALUE', 'SIZE' => 'SIZE.VALUE'],
    'filter' => [
        '=ACTIVE' => 'Y',
        '=PARENT_PRODUCT.ID' => $productId, // через reference
    ],
]);
```

---

## Склады и остатки

### Получить остатки на всех складах

```php
use Bitrix\Catalog\StoreProductTable;

$result = StoreProductTable::getList([
    'select' => ['STORE_ID', 'AMOUNT', 'STORE_TITLE' => 'STORE.TITLE'],
    'filter' => ['=PRODUCT_ID' => $productId],
]);
while ($row = $result->fetch()) {
    // $row['STORE_TITLE'] — название склада
    // $row['AMOUNT'] — количество
}
```

### Суммарный остаток

```php
use Bitrix\Catalog\ProductTable;

$product = ProductTable::getRow([
    'select' => ['ID', 'QUANTITY', 'QUANTITY_RESERVED'],
    'filter' => ['=ID' => $productId],
]);
// $product['QUANTITY'] — общий остаток
// $product['QUANTITY'] - $product['QUANTITY_RESERVED'] — доступный
```

### Обновить остаток на складе

```php
use Bitrix\Catalog\StoreProductTable;

$existing = StoreProductTable::getList([
    'filter' => ['=PRODUCT_ID' => $productId, '=STORE_ID' => $storeId],
])->fetch();

if ($existing) {
    StoreProductTable::update($existing['ID'], ['AMOUNT' => $newQuantity]);
} else {
    StoreProductTable::add([
        'PRODUCT_ID' => $productId,
        'STORE_ID'   => $storeId,
        'AMOUNT'     => $newQuantity,
    ]);
}

// Пересчитать общий остаток в b_catalog_product
\CCatalogProduct::recalcQuantityProduct($productId);
```

---

## Типы продуктов

```php
use Bitrix\Catalog\ProductTable;

// Константы типа продукта
ProductTable::TYPE_PRODUCT      // 1 — простой товар
ProductTable::TYPE_SET          // 2 — комплект (устарело)
ProductTable::TYPE_SKU          // 3 — товар с ТП (родительский)
ProductTable::TYPE_OFFER        // 4 — торговое предложение
ProductTable::TYPE_FREE_OFFER   // 5 — свободное ТП
ProductTable::TYPE_EMPTY_SKU    // 6 — товар без ТП (новый тип)
```

### Получить тип товара

```php
use Bitrix\Catalog\ProductTable;

$product = ProductTable::getRow([
    'select' => ['TYPE', 'AVAILABLE'],
    'filter' => ['=ID' => $productId],
]);
// $product['TYPE'] — тип
// $product['AVAILABLE'] == 'Y' — в наличии (по остаткам)
```

---

## Скидки каталога

### Список скидок

```php
use Bitrix\Catalog\DiscountTable;

$result = DiscountTable::getList([
    'select' => ['ID', 'NAME', 'ACTIVE', 'DISCOUNT_TYPE', 'DISCOUNT_VALUE'],
    'filter' => ['=ACTIVE' => 'Y', '=SITE_ID' => SITE_ID],
    'order'  => ['SORT' => 'ASC'],
]);
```

### Применить скидки каталога к ценам (при отображении)

```php
// Инициализировать движок скидок для пользователя
\CCatalogDiscount::SetDiscountGroups($USER->GetUserGroupArray());

// Получить цену с учётом скидок каталога
$discountPrice = \CCatalogProduct::GetOptimalPrice(
    $productId,
    1,
    $USER->GetUserGroupArray(),
    'N',
    [],
    SITE_ID,
    []
);
```

---

## Товар и его свойства — полный набор данных

```php
// Получить элемент инфоблока + данные каталога
$element = CIBlockElement::GetByID($productId)->GetNextElement();
if ($element) {
    $fields     = $element->GetFields();        // стандартные поля
    $properties = $element->GetProperties();    // свойства

    // Данные из catalog
    $catalogData = \CCatalogProduct::GetByID($productId);
    // $catalogData['WEIGHT'], ['WIDTH'], ['HEIGHT'], ['LENGTH'], ['CAN_BUY_ZERO']

    // Цена
    $price = \CPrice::GetBasePrice($productId);
    // $price['PRICE'], $price['CURRENCY']
}
```

---

## Работа с группами покупателей и типами цен

```php
// Список групп покупателей для прайс-листа
use Bitrix\Catalog\GroupAccessTable;

$result = GroupAccessTable::getList([
    'select' => ['GROUP_ID', 'CATALOG_GROUP_ID', 'ACCESS'],
    'filter' => ['=CATALOG_GROUP_ID' => $priceTypeId],
]);
// ACCESS: 'D' — запрет, 'V' — просмотр, 'B' — покупка

// Назначить группу пользователей на тип цены
GroupAccessTable::add([
    'GROUP_ID'         => $userGroupId,     // ID группы пользователей Bitrix
    'CATALOG_GROUP_ID' => $priceTypeId,
    'ACCESS'           => 'B',              // покупка
]);
```

---

## Gotchas

- Функция `\CCatalogProduct::GetOptimalPrice` сама применяет все скидки каталога — не нужно применять их вручную
- `ProductTable::TYPE_SKU` (3) — товар с торговыми предложениями. У него **нет собственной цены** — цены у ТП (`TYPE_OFFER`)
- `QUANTITY` в `ProductTable` — суммарный по всем складам, обновляется через `recalcQuantityProduct`
- `StoreProductTable` работает только если включён складской учёт в настройках каталога
- При импорте товаров всегда вызывай `\CCatalogProduct::recalcQuantityProduct($id)` после обновления остатков на складах
- `CAN_BUY_ZERO = 'Y'` — позволяет добавлять в корзину товар с нулевым остатком
