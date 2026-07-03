# Commerce Shop
> MCP Market compact bundle. Source files are concatenated from `bitrix/references/*` to keep the imported skill folder below the 50-file limit.

---

## Source: `catalog.md`

# Торговый каталог — `catalog` 25.550.0

> Truth layer: shop-core `/Users/igormajorov/Downloads/Telegram Desktop/bitrix-shop-core`, модуль `catalog` версии `25.550.0` (`install/version.php`, дата `2026-02-17`). Для catalog REST controllers/events/placements открывай `shop-integrations-webservice.md`. В этом core `catalog`, `sale`, `currency`, `bitrix.eshop`, `pull`, `bizproc`, `storeassist` реально присутствуют. Этот файл больше не deferred для shop-core-аудита, но в каждом клиентском проекте всё равно сначала проверяй `www/bitrix/modules/catalog`.

## 0. Обязательная проверка перед catalog-задачей

```bash
test -d www/bitrix/modules/catalog && sed -n '1,40p' www/bitrix/modules/catalog/install/version.php
find www/bitrix/modules/catalog/install/components/bitrix -maxdepth 1 -type d | sort
find local/components bitrix/templates local/templates -maxdepth 4 -type d 2>/dev/null | rg 'catalog|sale'
```

```php
use Bitrix\Main\Loader;

foreach (['iblock', 'currency', 'catalog'] as $module) {
    if (!Loader::includeModule($module)) {
        throw new \RuntimeException("Module {$module} is not installed");
    }
}
```

Проверенный shop-core содержит стандартные catalog-компоненты: `catalog.import.1c`, `catalog.export.1c`, `catalog.product.grid`, `catalog.productcard.*`, `catalog.store.*`, `catalog.store.document.*`, `catalog.report.store_*`, `catalog.product.subscribe*`, `catalog.viewed.products`, `currency.field.money`, `currency.money.input`, `currency.rates`. Для public `bitrix:catalog`, `catalog.section`, `catalog.element`, `catalog.smart.filter`, compare и eShop wizard/templates дополнительно открывай `shop-standard-components.md`, потому что эти витринные `catalog.*` лежат в `iblock`. Для маркетинговых подписок и рассылок помни: `catalog.product.subscribe*` — product availability notification, а `sender.subscribe`/`subscribe.*` описаны отдельно в `shop-marketing-analytics.md`. Для product/list business processes открывай `shop-automation-bizproc.md` и проверяй `iblock` `BIZPROC` flag.

## 1. Модель данных catalog

Catalog живёт поверх `iblock`, но коммерческие данные лежат в собственных таблицах:

| Слой | Таблицы / файлы | Что проверять |
|---|---|---|
| Привязка catalog к ИБ | `b_catalog_iblock`, `Bitrix\Catalog\CatalogIblockTable`, `CCatalogSKU` | `PRODUCT_IBLOCK_ID`, offers iblock, `SKU_PROPERTY_ID`, `YANDEX_EXPORT` |
| Товар | `b_catalog_product`, `Bitrix\Catalog\ProductTable`, `Bitrix\Catalog\Model\Product` | тип товара, количество, резерв, вес, VAT, quantity trace |
| Цена | `b_catalog_price`, `Bitrix\Catalog\PriceTable`, `Bitrix\Catalog\Model\Price` | тип цены, валюта, quantity range, base price |
| Тип цены | `b_catalog_group`, `b_catalog_group_lang`, `Bitrix\Catalog\GroupTable` | базовая цена, права групп, язык/название |
| SKU/offers | `CCatalogSKU`, `Bitrix\Catalog\Product\Sku`, свойство `CML2_LINK` | связь offer → product, отдельные цены/остатки offer |
| Остатки | `b_catalog_store`, `b_catalog_store_product`, `StoreTable`, `StoreProductTable` | складской остаток vs общий `QUANTITY` |
| Складские документы | `b_catalog_store_docs`, `b_catalog_docs_element`, `Storedocument*Table` | приход/расход/перемещение, batch, barcode |
| Единицы | `b_catalog_measure`, `b_catalog_measure_ratio`, `MeasureTable`, `MeasureRatioTable` | базовая единица, коэффициент продажи |
| НДС | `b_catalog_vat`, `VatTable` | ставка, включённость в цену |
| Скидки catalog | `b_catalog_discount*`, `Discount*` | legacy/catalog discounts, связь с sale discounts |
| Доступ | `b_catalog_role`, `b_catalog_permission` | catalog RBAC отдельно от iblock rights |

Не путай `iblock`-активность (`ACTIVE`, `ACTIVE_FROM/TO`, права разделов) с коммерческой доступностью (`QUANTITY`, `CAN_BUY_ZERO`, `AVAILABLE`, `SUBSCRIBE`, складские остатки).

## 2. Товар, offer и тип продукта

В этом core есть D7-слой `Bitrix\Catalog\ProductTable`, `Bitrix\Catalog\Model\Product`, `Bitrix\Catalog\Product\Sku`, но стандартные компоненты и старые обмены всё ещё часто идут через legacy `CCatalogProduct`, `CCatalogSKU`, `CIBlockElement`.

```php
use Bitrix\Catalog\ProductTable;

$product = ProductTable::getRow([
    'select' => ['ID', 'TYPE', 'QUANTITY', 'QUANTITY_RESERVED', 'AVAILABLE', 'CAN_BUY_ZERO', 'WEIGHT'],
    'filter' => ['=ID' => $productId],
]);
```

Типы не хардкодь по памяти: проверяй константы в `ProductTable` текущего ядра. Для диагностики SKU сначала найди offers-ИБ:

```php
$skuInfo = \CCatalogSKU::GetInfoByProductIBlock($productIblockId);
if ($skuInfo) {
    $offersIblockId = (int)$skuInfo['IBLOCK_ID'];
    $skuPropertyId = (int)$skuInfo['SKU_PROPERTY_ID'];
}
```

Для 1С-связки критичны `XML_ID`, external IDs и свойство offer → product. В шаблонах sale встречается фильтрация свойства `CML2_LINK`, поэтому не удаляй/не переименовывай это свойство без аудита обмена.

## 3. Цены и типы цен

Цены требуют модуля `currency`; валюта лежит в `b_catalog_currency*`, сами цены — в `b_catalog_price`.

```php
use Bitrix\Catalog\PriceTable;
use Bitrix\Catalog\GroupTable;

$prices = PriceTable::getList([
    'select' => ['ID', 'PRODUCT_ID', 'CATALOG_GROUP_ID', 'PRICE', 'CURRENCY', 'QUANTITY_FROM', 'QUANTITY_TO'],
    'filter' => ['=PRODUCT_ID' => $productId],
    'order' => ['CATALOG_GROUP_ID' => 'ASC', 'QUANTITY_FROM' => 'ASC'],
]);

$priceTypes = GroupTable::getList([
    'select' => ['ID', 'NAME', 'BASE', 'SORT'],
    'order' => ['SORT' => 'ASC'],
]);
```

Для витрины не показывай “первую попавшуюся” цену. Проверяй:

1. какие `CATALOG_GROUP_ID` переданы в компонент;
2. права группы пользователя на тип цены (`b_catalog_group2group`, `b_catalog_product2group`);
3. quantity range;
4. валюту и форматирование;
5. скидки `sale`/`catalog`, если цена выводится через компонент.

Для записи цены предпочитай D7 `PriceTable::add/update`, но перед боевым изменением проговаривай обратимость и чисть зависимые кеши.

## 4. Остатки, склады и availability

Общий остаток товара: `ProductTable::QUANTITY`. Складские остатки: `StoreProductTable` / `b_catalog_store_product`.

```php
use Bitrix\Catalog\StoreProductTable;

$rows = StoreProductTable::getList([
    'select' => ['STORE_ID', 'PRODUCT_ID', 'AMOUNT', 'STORE_TITLE' => 'STORE.TITLE'],
    'filter' => ['=PRODUCT_ID' => $productId],
]);
```

После ручной правки складского остатка не забывай пересчёт товара:

```php
\CCatalogProduct::recalcQuantityProduct($productId);
```

Для задач “товар виден, но не покупается” проверяй вместе:

- `ACTIVE` элемента и раздела;
- `TYPE` товара: простой/parent SKU/offer;
- цена доступна текущей группе;
- `QUANTITY`, `QUANTITY_RESERVED`, `CAN_BUY_ZERO`, `QUANTITY_TRACE`;
- есть ли активный offer с ценой и остатком;
- не ломает ли `CatalogProvider` добавление в basket;
- кеш catalog-компонента и managed/tagged cache.

## 5. Складские документы, batch, barcode

В shop-core есть `catalog.store.document.*` компоненты и таблицы `b_catalog_store_docs`, `b_catalog_docs_element`, `b_catalog_store_batch`, `b_catalog_store_barcode`, `b_catalog_docs_barcode`. Для задач по складам не своди всё к `QUANTITY`.

Проверяй:

- включён ли складской учёт в настройках catalog;
- тип документа: приход, расход, перемещение, списание;
- contractor (`b_catalog_contractor`);
- batch/barcode, если используются партии или маркировка;
- пересчёт общего остатка и reserved quantity.

## 6. Standard components и admin UI

Для component-by-component карты public/admin магазина сначала открывай `shop-standard-components.md`. Здесь оставлен API-oriented catalog слой.

Подтверждённые component families в shop-core:

- импорт/экспорт: `catalog.import.1c`, `catalog.export.1c`, `catalog.import.hl`;
- карточка/грид товара: `catalog.product.grid`, `catalog.productcard.details`, `catalog.productcard.variation.grid`, `catalog.productcard.variation.details`, `catalog.grid.product.field`;
- склады: `catalog.store.*`, `catalog.store.document.*`, `catalog.productcard.store.amount*`;
- отчёты: `catalog.report.store_*`;
- подписки/viewed/recommended: `catalog.product.subscribe*`, `catalog.viewed.products`, `catalog.bigdata.products`.

Для стандартного компонента всегда читай:

1. `.description.php`;
2. `.parameters.php`;
3. `component.php` / `class.php`;
4. `templates/*`;
5. project override в `local/templates/.../components/bitrix/...`.

Если проблема в page 2, “Показать ещё”, infinite scroll или `PAGEN_<NavNum>` у `catalog.section`, открывай `shop-standard-components.md` и `pagination.md`: stock templates текущего shop-core отправляют следующую страницу через `PAGEN_` + `NavNum` и зависят от актуальных `navParams`, cache key, filter и sort.

## 7. CommerceML и 1С

Catalog-часть обмена подтверждена через `catalog.import.1c` и `catalog.export.1c`. Детали маршрутизируй в `commerce-1c-integration.md`.

Ключевые режимы `catalog.import.1c/component.php`: `mode=checkauth`, `mode=init`, `mode=file`, `mode=import`; сессия `$_SESSION['BX_CML2_IMPORT']`; `sessid` и проверка источника. Для экспорта каталога аналогично смотри `catalog.export.1c`.

## 8. Диагностика типовых catalog-багов

### 1С выгрузила товар, но его нет на сайте

1. Найди элемент по `XML_ID`/external ID в iblock.
2. Проверь `ACTIVE`, section binding, site binding, права.
3. Проверь `b_catalog_product` для element ID.
4. Если это offer — проверь связь `CML2_LINK` / `SKU_PROPERTY_ID`.
5. Проверь цену в нужном `CATALOG_GROUP_ID` и валюту.
6. Проверь остатки и `AVAILABLE`.
7. Пересобери search/facet index и очисти component/tagged cache.

### Цена не обновилась

1. Убедись, что обновлялся product ID нужного offer, а не parent product.
2. Проверь `CATALOG_GROUP_ID`, quantity range и `CURRENCY`.
3. Проверь права текущей группы на тип цены.
4. Проверь, не применена ли скидка sale/catalog.
5. Проверь кеш компонента и managed cache.

### Остаток не совпадает

1. Разведи общий `b_catalog_product.QUANTITY` и складской `b_catalog_store_product.AMOUNT`.
2. Проверь reserved quantity через sale/basket/order.
3. Проверь складские документы, если включён складской учёт.
4. Запусти безопасный пересчёт, а не прямую SQL-правку.

## 9. Что не делать

- Не считать наличие `catalog.*` компонента внутри `iblock` доказательством установленного `catalog` в чужом проекте.
- Не писать цены/остатки прямым SQL, если можно использовать table/model/API и пересчёт.
- Не смешивать parent product и offer: цена/остаток часто живут на offer.
- Не чистить весь `/bitrix/cache` как первый шаг; сначала определи component/tagged/managed/facet/search слой.
- Не подключать production 1С или реальные платежи для smoke без явного подтверждения пользователя.


---

## Source: `sale.md`

# Sale — корзина, заказ, оплата, доставка (`sale` 26.0.0)

> Truth layer: shop-core `/Users/igormajorov/Downloads/Telegram Desktop/bitrix-shop-core`, модуль `sale` версии `26.0.0` (`install/version.php`, дата `2026-01-12`). Для sale REST controllers/events, external pay system/delivery/cashbox handlers and `webservice.sale` SOAP stats открывай `shop-integrations-webservice.md`. В этом core `sale`, `catalog`, `currency`, `pull`, `bizproc`, `sender` присутствуют. В каждом проекте сначала проверяй наличие `www/bitrix/modules/sale` и конкретных компонентов.

## 0. Обязательная проверка перед sale-задачей

```bash
test -d www/bitrix/modules/sale && sed -n '1,40p' www/bitrix/modules/sale/install/version.php
find www/bitrix/modules/sale/install/components/bitrix -maxdepth 1 -type d | sort | rg '^.*/sale\.'
find www/bitrix/modules/sale/lib -maxdepth 2 -type f | sort | sed -n '1,120p'
```

```php
use Bitrix\Main\Loader;

foreach (['sale', 'catalog', 'currency'] as $module) {
    if (!Loader::includeModule($module)) {
        throw new \RuntimeException("Module {$module} is not installed");
    }
}
```


Для задач по стандартным компонентам sale (`sale.basket.*`, `sale.order.ajax`, `sale.order.checkout`, `sale.personal.*`, `sale.order.payment*`, delivery/location/gifts) сначала открывай `shop-standard-components.md`, а этот файл используй для D7 API, lifecycle и side effects корзины/заказа. Для sender-сегментов покупателей, `TargetSaleMailConnector`, follow-up рассылок и sale statistic events открывай `shop-marketing-analytics.md`. Для роботов/БП заказа открывай `shop-automation-bizproc.md`, но не обещай sale-order robots без локального provider-а/CRM/custom module.

## 1. D7 object graph

```text
Order
├── Basket / BasketItem
├── PropertyCollection / PropertyValue
├── ShipmentCollection / Shipment / ShipmentItemCollection
├── PaymentCollection / Payment
├── Discount / OrderDiscount
├── Tax / Location / PersonType
└── Status lifecycle + history/change log
```

Подтверждённые классы/файлы:

- `Bitrix\Sale\Order` — `sale/lib/order.php`;
- `Bitrix\Sale\Basket`, `BasketItem`, `Fuser` — `sale/lib/basket*.php`, `sale/lib/fuser.php`;
- `Shipment`, `ShipmentCollection`, `ShipmentItemCollection` — `sale/lib/shipment*.php`;
- `Payment`, `PaymentCollection` — `sale/lib/payment*.php`;
- `Discount`, `OrderDiscount`, `OrderDiscountManager` — `sale/lib/discount.php`, `orderdiscount*.php`;
- `OrderStatus`, `DeliveryStatus`, `StatusBase` — `sale/lib/*status*.php`;
- `Location\*` — `sale/lib/location/*`;
- `Cashbox\*` — `sale/lib/cashbox/*`;
- exchange/1C — `sale/lib/exchange/*`, `sale/lib/exchange/onec/*`.

## 2. Главные таблицы

| Слой | Таблицы |
|---|---|
| Посетитель/корзина | `b_sale_fuser`, `b_sale_basket`, `b_sale_basket_props`, `b_sale_basket_reservation`, `b_sale_basket_reservation_history` |
| Заказ | `b_sale_order`, `b_sale_order_props*`, `b_sale_order_history`, `b_sale_order_change`, `b_sale_order_entities_custom_fields` |
| Отгрузки | `b_sale_order_delivery`, `b_sale_order_dlv_basket`, `b_sale_order_delivery_req*` |
| Оплаты | `b_sale_order_payment`, `b_sale_order_payment_item`, `b_sale_pay_system_action`, `b_sale_pay_system_err_log` |
| Скидки | `b_sale_discount*`, `b_sale_order_discount`, `b_sale_order_coupons`, `b_sale_order_rules*` |
| Статусы | `b_sale_status`, `b_sale_status_lang`, `b_sale_status_group_task` |
| Локации | `b_sale_location*`, `b_sale_loc_*`, `b_sale_location_group*` |
| Профили | `b_sale_user_props`, `b_sale_user_props_value`, `b_sale_person_type*` |
| 1С/exchange | `b_sale_export`, `b_sale_exchange_log`, `b_sale_synchronizer_log`, `b_sale_bizval_code_1c` |
| Кассы | `b_sale_cashbox*`, `b_sale_check*`, `b_sale_check_related_entities` |

## 3. Корзина

```php
use Bitrix\Sale\Basket;
use Bitrix\Sale\Fuser;

$basket = Basket::loadItemsForFUser(Fuser::getId(), SITE_ID);
$item = $basket->createItem('catalog', $productId);
$item->setFields([
    'QUANTITY' => 1,
    'CURRENCY' => \Bitrix\Currency\CurrencyManager::getBaseCurrency(),
    'LID' => SITE_ID,
    'PRODUCT_PROVIDER_CLASS' => \CCatalogProductProvider::class,
]);

$result = $basket->save();
if (!$result->isSuccess()) {
    throw new \RuntimeException(implode('; ', $result->getErrorMessages()));
}
```

Для production-кода не заполняй `PRICE` вручную без причины: provider/catalog должен пересчитать цену, доступность, вес и скидки. Если создаёшь service-layer, отдели:

- получение/создание `Fuser`;
- добавление item;
- refresh/recalculate;
- сохранение;
- обработку `Result/Error`.

## 4. Создание заказа

```php
use Bitrix\Sale\Order;
use Bitrix\Sale\Basket;
use Bitrix\Sale\Delivery;
use Bitrix\Sale\PaySystem;

$order = Order::create(SITE_ID, $userId);
$order->setPersonTypeId($personTypeId);
$order->setBasket(Basket::loadItemsForFUser(\Bitrix\Sale\Fuser::getId(), SITE_ID));

$propertyCollection = $order->getPropertyCollection();
$email = $propertyCollection->getUserEmail();
if ($email) {
    $email->setValue($userEmail);
}

$shipmentCollection = $order->getShipmentCollection();
$shipment = $shipmentCollection->createItem();
$delivery = Delivery\Services\Manager::getById($deliveryId);
$shipment->setFields([
    'DELIVERY_ID' => $delivery['ID'],
    'DELIVERY_NAME' => $delivery['NAME'],
    'CURRENCY' => $order->getCurrency(),
]);

foreach ($order->getBasket() as $basketItem) {
    $shipmentItem = $shipment->getShipmentItemCollection()->createItem($basketItem);
    $shipmentItem->setQuantity($basketItem->getQuantity());
}

$payment = $order->getPaymentCollection()->createItem();
$paySystem = PaySystem\Manager::getObjectById($paySystemId);
$payment->setFields([
    'PAY_SYSTEM_ID' => $paySystem->getField('ID'),
    'PAY_SYSTEM_NAME' => $paySystem->getField('NAME'),
    'SUM' => $order->getPrice(),
    'CURRENCY' => $order->getCurrency(),
]);

$result = $order->save();
```

Перед сохранением заказа проверь совместимость:

- `PERSON_TYPE_ID` ↔ свойства заказа;
- служба доставки ↔ location/person type/состав корзины;
- платёжная система ↔ person type/site/currency/sum;
- final basket refresh;
- обработчики `sale` events.

## 5. Статусы, оплата, отгрузка

```php
$order = \Bitrix\Sale\Order::load($orderId);
$order->setField('STATUS_ID', 'P');

foreach ($order->getPaymentCollection() as $payment) {
    $payment->setPaid('Y');
}

foreach ($order->getShipmentCollection() as $shipment) {
    if (!$shipment->isSystem()) {
        $shipment->setField('DEDUCTED', 'Y');
    }
}

$result = $order->save();
```

Не меняй `b_sale_order.STATUS_ID`, `PAYED`, `DEDUCTED` прямым SQL: потеряешь events, history, exchange flags, reservation/cashbox side effects.

## 6. Standard components

Подтверждённые storefront/account components:

- корзина: `sale.basket.basket`, `sale.basket.basket.line`, `sale.basket.basket.small`, `sale.basket.order.ajax`;
- оформление: `sale.order.ajax`, `sale.order.checkout`, `sale.order.full`;
- оплата: `sale.order.payment`, `sale.order.payment.change`, `sale.order.payment.receive`, `sale.account.pay`;
- личный кабинет: `sale.personal.order*`, `sale.personal.profile*`, `sale.personal.account`, `sale.personal.section`, `sale.personal.subscribe*`;
- доставка/локации: `sale.ajax.delivery.calculator`, `sale.location.*`, `sale.store.choose`, `sale.delivery.request*`;
- подарки/рекомендации: `sale.gift.*`, `sale.products.gift*`, `sale.recommended.products`;
- 1С: `sale.export.1c`.

Для checkout-багов всегда читай `.parameters.php`, `class.php/component.php`, `templates/*`, затем project template override.

## 7. Events и side effects

Sale-задачи почти всегда имеют побочные эффекты:

- reservation и доступный остаток catalog;
- скидки и купоны;
- почтовые события и sender triggers;
- payment callbacks;
- delivery requests;
- cashbox/check generation;
- exchange log и 1С-синхронизация;
- order history/change log;
- managed cache, personal account pages, basket line AJAX.

При изменении order lifecycle проговаривай, какие side effects нужны, а какие нельзя запускать.

## 8. 1С exchange для заказов

Маршрутизируй в `commerce-1c-integration.md`. В shop-core подтверждены:

- компонент `sale.export.1c`;
- admin entrypoint `/bitrix/admin/1c_exchange.php`;
- `/bitrix/admin/sale_exchange_log.php`;
- `sale/lib/exchange/*`, `sale/lib/exchange/onec/*`;
- таблицы `b_sale_exchange_log`, `b_sale_synchronizer_log`, `b_sale_bizval_code_1c`.

Ключевые режимы `sale.export.1c/component.php`: `mode=checkauth`, `mode=init`, `mode=file`, `mode=import`; сессия `$_SESSION['BX_CML2_EXPORT']`; `secure_1c_exchange`; `sessid`; zip/unzip; `last_xml_entry` для продолжения импорта.

## 9. Диагностика sale-багов

### Товар не добавляется в корзину

1. Проверь catalog product/offer, цену, остаток, provider.
2. Проверь `Fuser::getId()` и site ID.
3. Проверь `PRODUCT_PROVIDER_CLASS` и `MODULE` item.
4. Проверь sale basket component AJAX и CSRF/session.
5. Проверь event handlers, которые валидируют basket item.

### Checkout не создаёт заказ

1. Проверь `PERSON_TYPE_ID` и обязательные свойства.
2. Проверь location и delivery restrictions.
3. Проверь payment system restrictions.
4. Проверь basket refresh и coupons.
5. Проверь ошибки `$result->getErrorMessages()` от `Order::save()`.
6. Проверь component template и AJAX response.

### Заказ создан, но не уходит в 1С

1. Проверь настройки компонента `sale.export.1c` и группы доступа.
2. Проверь `b_sale_exchange_log` / `/bitrix/admin/sale_exchange_log.php`.
3. Проверь `DATE_UPDATE`, статус, оплату/отгрузку и критерии выгрузки.
4. Проверь `secure_1c_exchange`, `sessid`, cookies/session.
5. Проверь временные файлы `upload/1c_exchange` или temp-dir.

## 10. Что не делать

- Не писать заказ/оплату/отгрузку прямым SQL.
- Не создавать заказ без финального refresh basket/order.
- Не считать, что `sale.order.ajax` и `sale.order.checkout` имеют одинаковый контракт: проверяй конкретный component.
- Не подключать real pay systems/delivery/1С для smoke без явного подтверждения.
- Не игнорировать user/person type/site restrictions.


---

## Source: `currency.md`

# Currency — валюты, курсы и денежные поля (`currency` 26.0.0)

> Truth layer: shop-core `/Users/igormajorov/Downloads/Telegram Desktop/bitrix-shop-core`, модуль `currency` версии `26.0.0` (`install/version.php`, дата `2026-02-24`). Используй этот файл для цен catalog, сумм sale, форматирования денег, курсов и UF/property money fields.

## 1. Проверка модуля

```bash
test -d www/bitrix/modules/currency && sed -n '1,60p' www/bitrix/modules/currency/install/version.php
find www/bitrix/modules/currency -maxdepth 3 -type f | sort
```

```php
use Bitrix\Main\Loader;

if (!Loader::includeModule('currency')) {
    throw new \RuntimeException('Module currency is not installed');
}
```

## 2. Подтверждённые классы

`currency/autoload.php` регистрирует:

- legacy: `CCurrency`, `CCurrencyLang`, `CCurrencyRates`;
- D7: `Bitrix\Currency\CurrencyManager`, `CurrencyTable`, `CurrencyLangTable`, `CurrencyRateTable`, `CurrencyClassifier`;
- UI/fields: `Bitrix\Currency\UserField\Money`, components `currency.field.money`, `currency.money.input`, `currency.rates`;
- iblock integration: `lib/integration/iblockmoneyproperty.php`.

## 3. Таблицы

- `b_catalog_currency` — валюта, базовые настройки;
- `b_catalog_currency_lang` — форматирование и названия по языкам;
- `b_catalog_currency_rate` — курсы.

Исторически таблицы имеют префикс `b_catalog_*`, но модуль отдельный: `currency`.

## 4. Читать и форматировать валюты

```php
use Bitrix\Currency\CurrencyManager;
use Bitrix\Currency\CurrencyTable;
use Bitrix\Currency\CurrencyLangTable;

$base = CurrencyManager::getBaseCurrency();

$currencies = CurrencyTable::getList([
    'select' => ['CURRENCY', 'AMOUNT_CNT', 'AMOUNT', 'SORT', 'BASE'],
    'order' => ['SORT' => 'ASC'],
]);

$formats = CurrencyLangTable::getList([
    'select' => ['CURRENCY', 'LID', 'FORMAT_STRING', 'DEC_POINT', 'THOUSANDS_SEP'],
    'filter' => ['=LID' => LANGUAGE_ID],
]);
```

Для вывода суммы используй Bitrix formatting helpers текущего проекта, а не `number_format` руками: формат валюты зависит от языка и настроек `b_catalog_currency_lang`.

## 5. Курсы

```php
use Bitrix\Currency\CurrencyRateTable;

$rate = CurrencyRateTable::getList([
    'select' => ['CURRENCY', 'DATE_RATE', 'RATE_CNT', 'RATE'],
    'filter' => ['=CURRENCY' => 'USD'],
    'order' => ['DATE_RATE' => 'DESC'],
    'limit' => 1,
])->fetch();
```

Legacy `CCurrencyRates` всё ещё используется в старом коде и админке (`currency/general/currency_rate.php`). Если проект уже завязан на legacy API, не переписывай ради переписывания; сначала проверь surrounding code.

## 6. Связка с catalog и sale

Catalog:

- `b_catalog_price.CURRENCY` хранит код валюты цены;
- типы цен не равны валютам;
- quantity range цены может иметь разные суммы в одной валюте;
- при отображении учитываются права на тип цены и формат currency.

Sale:

- order, basket item, payment, shipment имеют currency fields;
- нельзя смешивать currency order и payment без проверки pay system restrictions;
- изменение базовой валюты влияет на расчёты, отчёты и обмены.

## 7. Диагностика

### Цена есть, но отображается странно

1. Проверь `CURRENCY` в `b_catalog_price`.
2. Проверь формат в `b_catalog_currency_lang` для языка сайта.
3. Проверь, не конвертирует ли компонент цену.
4. Проверь скидки sale/catalog и final price.
5. Проверь кеш компонента.

### Курс не применяется

1. Проверь базовую валюту через `CurrencyManager::getBaseCurrency()`.
2. Проверь `b_catalog_currency_rate` на дату.
3. Проверь, кто делает conversion: компонент, кастомный код или импорт.
4. Проверь timezone/date и округление.

## 8. Что не делать

- Не считать валюту равной типу цены.
- Не форматировать деньги руками в шаблоне, если есть currency format.
- Не менять базовую валюту на production без плана миграции цен, заказов, оплат и отчётов.
- Не игнорировать `currency` при catalog/sale задачах: цены и суммы без currency-контекста неполные.


---

## Source: `commerce-workflows.md`

# Магазин, витрина и кросс-доменные workflow

> Truth layer: shop-core `/Users/igormajorov/Downloads/Telegram Desktop/bitrix-shop-core`. Подтверждены `catalog` 25.550.0, `sale` 26.0.0, `currency` 26.0.0, `bitrix.eshop` 25.0.0, `pull`, `bizproc`, `sender`, `storeassist`, компоненты `catalog.import.1c`, `catalog.export.1c`, `sale.export.1c`, storefront components `sale.*`, admin catalog/store/productcard components. Этот файл больше не deferred для shop-core-аудита, но в каждом проекте сначала проверяй наличие модулей.

## 1. Порядок чтения проекта

Для магазинных задач сначала смотри живой код проекта:

1. `www/bitrix/modules/main/classes/general/version.php` или `www/bitrix/modules/<module>/install/version.php`
2. `www/bitrix/modules/catalog/lib/`, `www/bitrix/modules/sale/lib/`, `www/bitrix/modules/currency/lib/`
3. `www/bitrix/modules/<module>/install/components/bitrix/<component>/`
4. `www/bitrix/admin/1c_import.php`, `1c_exchange.php`, `sale_exchange_log.php` и реальные module-admin файлы
5. `local/components/<vendor>/<component>/`
6. `local/templates/<site>/components/bitrix/<component>/`
7. `local/php_interface/`, `local/modules/`, `urlrewrite.php`

Минимальный модульный gate:

```bash
for m in iblock currency catalog sale; do
  test -d "www/bitrix/modules/$m" && echo "OK $m" || echo "MISS $m"
done
```

Если `catalog`, `sale` или `currency` отсутствуют — не веди задачу как полноценный интернет-магазин.

## 2. Карта слоёв магазина

| Слой | Что лежит здесь | Reference |
|---|---|---|
| Контентный | ИБ, разделы, элементы, свойства, UF, файлы, XML_ID | `iblocks.md`, `entities-migrations.md`, `import-export.md` |
| Catalog | товар, offer, цена, тип цены, остаток, склад, measure, VAT | `catalog.md`, `currency.md` |
| Sale | basket, order, shipment, payment, discount, coupon, person type, locations | `sale.md`, `users.md`, `validation.md` |
| 1С / CommerceML | `catalog.import.1c`, `catalog.export.1c`, `sale.export.1c`, `BX_CML2_*` | `commerce-1c-integration.md` |
| Витрина | complex catalog, list/detail, smart filter, SKU JS, basket line, checkout | `components.md`, `templates.md`, `component-dataflow-debugging.md` |
| Индексы/кеш | component/tagged/managed/cache, facet, search, composite, SEO | `cache-infra.md`, `index-cache-diagnostics.md`, `search.md`, `seo-cache-access.md` |
| Ops | agents, cron, stepper, import queues, logs, perf, backup | `operations-runbook.md`, `update-stepper.md`, `perfmon.md` |

## 3. Как выбирать точку изменения

### Модель товара / SKU / свойства

1. Проверить iblock и offers iblock.
2. Проверить `CCatalogSKU::GetInfoByProductIBlock()`.
3. Проверить, где живёт цена/остаток: parent product или offer.
4. Для повторяемого изменения писать migration/install step/CLI, а не клик в админке.
5. Для 1С учитывать `XML_ID` и `CML2_LINK`.

### Цена / валюта / скидка

1. `currency.md`: базовая валюта, формат, курс.
2. `catalog.md`: `b_catalog_price`, `CATALOG_GROUP_ID`, права типа цены.
3. `sale.md`: скидки, купоны, финальный расчёт basket/order.
4. Кеш компонента и managed cache.

### Остатки / склады / доступность

1. Общий `b_catalog_product.QUANTITY`.
2. Складской `b_catalog_store_product.AMOUNT`.
3. Reservation из sale/order/basket.
4. Store documents/batches/barcodes, если включён складской учёт.
5. `CAN_BUY_ZERO`, `QUANTITY_TRACE`, availability.

### Корзина / checkout / заказ

1. `sale.md`: `Fuser`, `Basket`, provider, `Order` object graph.
2. Проверить component: `sale.basket.*`, `sale.order.ajax`, `sale.order.checkout`, `sale.order.full`.
3. Проверить person type, свойства заказа, delivery/payment restrictions.
4. Проверить order save result и event handlers.
5. Проверить side effects: stock reservation, mail, sender, cashbox, exchange.

### Обмен с 1С

1. Определить поток: catalog import, catalog export, sale exchange.
2. Проверить `checkauth → init → file → import`.
3. Проверить session/cookies/sessid/secure exchange.
4. Проверить temp files, zip, chunk upload, PHP limits.
5. Проверить mapping XML_ID/CML2_LINK/price type/store.
6. Проверить post-import indexes/cache.
7. Для orders проверить `b_sale_exchange_log`, критерии выгрузки, обратные документы.

## 4. Diagnostic routes

### “В админке товар есть, на сайте нет”

```text
iblock entity
→ section/site/activity/rights
→ catalog row/type/SKU
→ price/currency/price group rights
→ stock/availability
→ component params/filter/select
→ result_modifier/template/SKU JS
→ component/tagged/facet/search/composite cache
→ SEF/urlrewrite/SEO
```

### “Товар виден, но не покупается”

```text
product vs offer ID
→ catalog provider
→ accessible price
→ stock/reservation/can-buy-zero
→ basket item creation
→ sale events/validators
→ AJAX response/template
```

### “Checkout разваливается”

```text
basket refresh
→ person type
→ required order props
→ location/delivery restrictions
→ payment restrictions
→ discounts/coupons
→ order save errors
→ event handlers
→ mail/payment/cashbox/exchange side effects
```

### “1С выгрузила, но данные не обновились”

```text
checkauth/session
→ init limits/zip
→ file upload/temp dir
→ import XML step
→ XML_ID mapping
→ product/offer/price/store tables
→ custom event handlers
→ indexes/cache
```

## 5. Components map

Catalog/admin:

- `catalog.product.grid`, `catalog.productcard.details`, `catalog.productcard.variation.grid`, `catalog.productcard.store.amount*`;
- `catalog.store.*`, `catalog.store.document.*`;
- `catalog.report.store_*`;
- `catalog.import.1c`, `catalog.export.1c`.

Sale/storefront:

- `sale.basket.basket`, `sale.basket.basket.line`, `sale.basket.basket.small`, `sale.basket.order.ajax`;
- `sale.order.ajax`, `sale.order.checkout`, `sale.order.full`;
- `sale.personal.order*`, `sale.personal.profile*`, `sale.personal.account`, `sale.personal.section`;
- `sale.order.payment*`, `sale.account.pay`, `sale.delivery.request*`, `sale.location.*`;
- `sale.export.1c`.

Currency:

- `currency.field.money`, `currency.money.input`, `currency.rates`.

Всегда читай `.parameters.php`, `component.php/class.php`, `templates/*`, затем project override.

## 6. Что проговаривать в ответе

Для любой кросс-доменной shop-задачи явно укажи:

- какие модули и версии подтверждены;
- product vs offer ID;
- где цена, валюта, остаток и доступность;
- какой компонент и template участвуют;
- какие order/basket side effects есть;
- какие кеши/индексы надо обновить;
- есть ли 1С/CommerceML или внешний sync;
- что можно менять кодом, а что требует подтверждения как data mutation.

## 7. Safety

- Не меняй production catalog/sale данные без подтверждения.
- Не подключай реальную 1С, платежи, доставки, кассы без подтверждения.
- Не делай прямой SQL для order/basket/payment/shipment/product price/stock, если есть API и side effects.
- Не удаляй XML_ID/CML2_LINK без плана миграции обмена.
- Не чисти глобально все кеши первым действием; определи слой.
- Не используй один shop-core как универсальную истину для всех версий: всегда перепроверяй локальный проект.


---

## Source: `commerce-1c-integration.md`

# Commerce + 1С / CommerceML integration

> Truth layer: shop-core `/Users/igormajorov/Downloads/Telegram Desktop/bitrix-shop-core`. Подтверждены модули `catalog` 25.550.0, `sale` 26.0.0, `currency` 26.0.0, компоненты `catalog.import.1c`, `catalog.export.1c`, `sale.export.1c`, admin entrypoints `/bitrix/admin/1c_import.php`, `/bitrix/admin/1c_exchange.php`, `/bitrix/admin/1c_admin.php`, `/bitrix/admin/sale_exchange_log.php`.

Используй этот файл для задач обмена с 1С, CommerceML, выгрузки каталога, импорта товаров/цен/остатков, экспорта/импорта заказов, диагностики `mode=checkauth/init/file/import`. Не путай с `webservice.sale`/`webservice.statistic` SOAP stats и sale/catalog REST app hooks — для них открывай `shop-integrations-webservice.md`.

## 1. Проверка наличия exchange слоя

```bash
for p in \
  www/bitrix/modules/catalog/install/components/bitrix/catalog.import.1c/component.php \
  www/bitrix/modules/catalog/install/components/bitrix/catalog.export.1c/component.php \
  www/bitrix/modules/sale/install/components/bitrix/sale.export.1c/component.php \
  www/bitrix/admin/1c_import.php \
  www/bitrix/admin/1c_exchange.php \
  www/bitrix/admin/sale_exchange_log.php
  do test -f "$p" && echo "OK $p" || echo "MISS $p"; done
```

```bash
find www/bitrix/modules/sale/lib/exchange -maxdepth 3 -type f | sort
rg "BX_CML2_IMPORT|BX_CML2_EXPORT|mode.*checkauth|mode.*init|mode.*file|mode.*import|secure_1c_exchange" www/bitrix/modules/{catalog,sale}
```

## 2. Entry points

| Поток | Entry point / component | Назначение |
|---|---|---|
| Импорт каталога из 1С | `catalog.import.1c` / `/bitrix/admin/1c_import.php` | товары, разделы, свойства, картинки, SKU, цены, остатки по CommerceML |
| Экспорт каталога | `catalog.export.1c` | выгрузка catalog data наружу |
| Обмен заказами | `sale.export.1c` / `/bitrix/admin/1c_exchange.php` | экспорт заказов в 1С и импорт обратных документов/статусов |
| Админка обмена | `/bitrix/admin/1c_admin.php` | настройки/страницы 1С exchange |
| Логи заказов | `/bitrix/admin/sale_exchange_log.php`, `b_sale_exchange_log` | диагностика обмена sale |

`/bitrix/admin/1c_import.php` просто требует `catalog/admin/1c_import.php`; `/bitrix/admin/1c_exchange.php` требует `sale/admin/1c_exchange.php`. Всегда переходи в модульный файл, а не анализируй wrapper как контракт.

## 3. Протокол режимов

Catalog import (`catalog.import.1c/component.php`) подтверждает режимы:

- `mode=checkauth` — авторизация, выдача cookie/session и `sessid`;
- `mode=init` — инициализация, ответ `zip=yes/no`, file limits, подготовка `$_SESSION['BX_CML2_IMPORT']`;
- `mode=file` — приём файла/chunk, запись во временный каталог;
- `mode=import` — распаковка zip или пошаговая обработка XML;
- session state: `BX_CML2_IMPORT`, `TEMP_DIR`, `zip`, `last_zip_entry`, `NS`, maps.

Sale exchange (`sale.export.1c/component.php`) подтверждает режимы:

- `mode=checkauth` — авторизация и `sessid`;
- `mode=init` — `zip=yes/no`, версия, `cmlVersion`, `BX_CML2_EXPORT`;
- `mode=file` — старый и новый формат загрузки;
- `mode=import` — unzip и обработка XML обратных документов;
- session state: `BX_CML2_EXPORT`, `last_zip_entry`, `last_xml_entry`, order prefix;
- option: `sale.secure_1c_exchange` и `check_bitrix_sessid()`.

## 4. Security и access

Проверяй:

1. группа пользователя, под которым ходит 1С;
2. права на catalog/sale exchange;
3. `secure_1c_exchange` и передачу `sessid`;
4. cookies/session: 1С должна сохранять cookie между `checkauth`, `init`, `file`, `import`;
5. `BX_SESSION_ID_CHANGE`, если компонент ругается на смену session ID;
6. `SKIP_SOURCE_CHECK` / source check в catalog import;
7. HTTPS/basic auth/proxy, если exchange идёт через внешний контур.

Никогда не советуй отключить security навсегда. Для диагностики можно временно подтвердить изменение с пользователем, но фиксируй rollback.

## 5. Временные файлы и zip/chunks

Типовые места:

- `upload/1c_exchange/` для sale export/import files;
- temp dir через `CTempFile::GetDirectoryName(...)`;
- `$_SESSION['BX_CML2_IMPORT']['TEMP_DIR']` / `BX_CML2_EXPORT['TEMP_DIR']`;
- zip state: `zip`, `last_zip_entry`;
- XML continuation: `last_xml_entry`.

Для больших файлов проверяй:

- `upload_max_filesize`, `post_max_size`, `max_execution_time`, `max_input_time`, memory;
- права на `upload/`, temp, `bitrix/tmp`;
- повторный chunk и идемпотентность;
- cleanup старых временных файлов;
- zip support (`zip_open`).

## 6. Catalog import: товары, SKU, цены, остатки

Диагностический порядок:

1. Найди XML/CommerceML файл и убедись, что 1С реально отправила нужный узел.
2. Проверь mapping по `XML_ID`: раздел, товар, offer, цена, склад.
3. Для товара проверь `CIBlockElement`, `b_catalog_product`.
4. Для SKU проверь offers-ИБ через `CCatalogSKU::GetInfoByProductIBlock()` и связь `CML2_LINK`/`SKU_PROPERTY_ID`.
5. Для цены проверь `b_catalog_price`, `CATALOG_GROUP_ID`, `CURRENCY`, quantity range.
6. Для остатков проверь `b_catalog_product.QUANTITY` и `b_catalog_store_product.AMOUNT`.
7. Проверь post-import side effects: facet/search index, managed/tagged/component cache.

## 7. Sale exchange: заказы и обратные документы

В shop-core есть `sale/lib/exchange/*`, `sale/lib/exchange/onec/*`, autoload для `Bitrix\Sale\Exchange\OneC\*` и `Bitrix\Sale\Exchange\Entity\*` loaders.

Проверяй:

- `b_sale_order.DATE_UPDATE`, status, paid/deducted/canceled;
- критерии выгрузки и order prefix в `BX_CML2_EXPORT`;
- `b_sale_exchange_log` и `sale_exchange_log.php`;
- `b_sale_synchronizer_log`, если участвует synchronizer;
- business values / `b_sale_bizval_code_1c`;
- import collision classes: order/shipment/payment/profile;
- обратные документы: payment/shipment/status updates.

## 8. Типовые проблемы

### `failure\nSession ID change is active`

Проверь файл включения компонента и рекомендацию компонента: `BX_SESSION_ID_CHANGE` должен быть определён до prolog, если это требуется конкретным exchange route. Не меняй глобально без понимания security impact.

### `checkauth` проходит, `file` или `import` падает

1. 1С не сохраняет cookie/session.
2. Потерян `sessid` при `secure_1c_exchange=Y`.
3. Temp/upload dir недоступен на запись.
4. File size/time limits.
5. Source check/CSRF/proxy режет запрос.

### Товар загружен, но не виден на витрине

1. `ACTIVE`, даты, section/site binding, права.
2. Товар vs offer: цена/остаток могут быть на offer.
3. `b_catalog_product` отсутствует или неверный `TYPE`.
4. Нет доступной цены для группы пользователя.
5. Остаток/availability запрещает покупку.
6. Не обновлён facet/search index или component cache.

### Цена/остаток не обновились

1. Неверный external ID / XML_ID.
2. Обновлён parent product вместо offer.
3. Неверный price type / currency.
4. Складской остаток обновился, общий quantity не пересчитан.
5. Сработал кастомный event handler и откатил/перезаписал значения.

### Заказы не уходят в 1С

1. Неверный exchange user или права.
2. Заказ не попадает в критерии выгрузки.
3. `DATE_UPDATE`/status не меняются ожидаемо.
4. Ошибка в `b_sale_exchange_log`.
5. `secure_1c_exchange` / `sessid` / cookies.
6. Кастомизация `sale.export.1c` или local override.

## 9. Safe verification flow

Перед любым тестом с обменом:

1. Используй sandbox, не production 1С.
2. Сохрани исходные options и настройки компонента.
3. Подготовь маленький CommerceML fixture: один раздел, один товар, один offer, одна цена, один остаток, один заказ.
4. Включи диагностические логи только на время теста.
5. После теста проверь таблицы, файлы, кеши, индексы.
6. Зафиксируй rollback: удалить тестовый товар/заказ/файлы, вернуть options.

## 10. Что не делать

- Не подключать реальную production 1С без подтверждения.
- Не отключать `secure_1c_exchange` как постоянное решение.
- Не удалять `CML2_LINK` и XML_ID-связи.
- Не чистить все товары перед импортом без backup и подтверждения.
- Не считать XML успешным только потому, что `file` вернул success: проверяй `import` и таблицы.


---

## Source: `storeassist.md`

# StoreAssist — мастер интернет-магазина и 1С onboarding

> Reference для Bitrix-скилла. Загружай, когда задача связана с модулем `storeassist`, “Мастером магазина”, пунктами `storeassist_1c_*`, прогрессом настройки магазина, toolbar-задачами в админке или вопросом “это 1С интеграция или просто подсказка мастера?”.

## Audit note

Проверено по shop-core:
- `www/bitrix/modules/storeassist/install/version.php` — `storeassist` 24.0.0
- `www/bitrix/modules/storeassist/include.php`
- `www/bitrix/modules/storeassist/classes/general/storeassist.php`
- `www/bitrix/modules/storeassist/install/index.php`
- `www/bitrix/modules/storeassist/admin/storeassist.php`
- `www/bitrix/modules/storeassist/admin/storeassist_1c_catalog_fill.php`
- `www/bitrix/modules/storeassist/admin/storeassist_1c_unloading.php`
- `www/bitrix/modules/storeassist/admin/storeassist_1c_exchange_realtime.php`
- `www/bitrix/modules/storeassist/admin/storeassist_1c_small_firm.php`
- `www/bitrix/modules/storeassist/tools/storeassist.php`
- `www/bitrix/modules/storeassist/install/js/storeassist/storeassist.js`
- `www/bitrix/modules/storeassist/options.php`
- `www/bitrix/modules/storeassist/lang/ru/admin/storeassist.php`

Ниже только контракт, подтверждённый этим core.

## Главный вывод

`storeassist` — это **мастер/чеклист настройки интернет-магазина**, а не движок обмена с 1С.

Он:
- добавляет пункт “Мастер магазина” в sale settings menu;
- рисует toolbar-задачи на связанных admin-страницах;
- хранит выполненность задач в option `storeassist_settings`;
- показывает справочные/онбординг страницы `storeassist_1c_*`;
- ведёт пользователя в реальные admin pages `catalog`, `sale`, `seo`, `search`, `security`, `bitrixcloud`, `perfmon`;
- ежедневно считает paid finished/paid orders через agent для прогресса.

Он **не**:
- не принимает CommerceML files;
- не реализует `checkauth/init/file/import`;
- не обновляет товары, цены, остатки или заказы;
- не заменяет `catalog.import.1c`, `catalog.export.1c`, `sale.export.1c`.

Если пользователь жалуется на реальный обмен 1С — открывай `commerce-1c-integration.md`, `catalog.md`, `sale.md`. Если вопрос про мастер, чеклист, подсказку или task progress — открывай этот файл.

## Установка и hooks

`install/index.php`:

- `RegisterModule("storeassist")`;
- регистрирует dependency на `main` event `OnPrologAdminTitle` → `CStoreAssist::onPrologAdminTitle`;
- регистрирует dependency на `main` event `OnBuildGlobalMenu` → `CStoreAssist::onBuildGlobalMenu`;
- добавляет daily agent `CStoreAssist::AgentCountDayOrders();` с периодом `86400`;
- копирует:
  - `install/admin` → `/bitrix/admin`;
  - `install/js` → `/bitrix/js`;
  - `install/panel` → `/bitrix/panel`;
  - `install/tools` → `/bitrix/tools`.

`include.php`:

- autoload: `CStoreAssist` → `classes/general/storeassist.php`;
- JS extension `storeassist`:
  - JS `/bitrix/js/storeassist/storeassist.js`;
  - CSS `/bitrix/js/storeassist/css/storeassist.css`;
  - lang `modules/storeassist/lang/<LANG>/jsmessages.php`.

## Права и доступ

Все admin pages проверяют:

```php
$APPLICATION->GetGroupRight("storeassist") >= "R"
```

Для изменения статуса задачи нужен фактически write-доступ: toolbar кнопки рисуются только при `ST_RIGHT >= "W"`, а POST endpoint дополнительно требует `check_bitrix_sessid()`.

Модуль имеет `MODULE_GROUP_RIGHTS = "Y"`, значит права управляются как module rights.

## Основной класс `CStoreAssist`

Подтверждённые методы:

- `setSettingOption($pageId, $isDone)`
- `getSettingOption()`
- `getDocumentationLink($pageId)`
- `onPrologAdminTitle($pageUrl, $pageId = "")`
- `onBuildGlobalMenu(&$arGlobalMenu, &$arModuleMenu)`
- `getProgressPercent()`
- `AgentCountDayOrders()`

### Whitelist задач

`CStoreAssist::$arAllPageId` содержит whitelist допустимых `pageId`. `setSettingOption()` и `getDocumentationLink()` откажут, если `pageId` не в этом списке.

В whitelist есть ключевые shop/1С task ids:

- `currencies`
- `cat_group_admin`
- `cat_measure_list`
- `sale_person_type`
- `sale_buyers`
- `sale_status`
- `cat_store_list`
- `cat_product_list`
- `quantity`
- `cat_store_document_list`
- `order_setting`
- `reserve_setting`
- `storeassist_1c_catalog_fill`
- `1c_integration`
- `storeassist_1c_unloading`
- `1c_exchange`
- `storeassist_1c_exchange_realtime`
- `storeassist_1c_small_firm`
- `sale_pay_system`
- `sale_delivery`
- `sale_delivery_service_list`
- `storeassist_seo_settings`
- `search_reindex`
- `cat_discount_admin`
- `posting_admin`
- `cat_export_setup`
- `sale_order`
- `sale_report`
- `sale_account_admin`
- `sale_basket`
- `sale_personalization`
- `sale_crm`
- `storeassist_crm_client`
- `storeassist_crm_calls`
- `composite`
- `perfmon_panel`
- `security_filter`
- `dump_auto`
- `bitrixcloud_monitoring_admin`
- `security_scanner`
- `security_otp`

## Options

Подтверждённые options:

| Option | Где используется | Смысл |
|---|---|---|
| `storeassist_settings` | `setSettingOption()`, `getSettingOption()` | comma-separated список выполненных `pageId` |
| `partner_name` | `options.php`, lang/support task | партнёр-разработчик проекта |
| `partner_url` | `options.php`, `onPrologAdminTitle()`, support link | URL поддержки партнёра |
| `progress_percent` | `getProgressPercent()`, `AgentCountDayOrders()` | прогресс заказов от 0 до 10 |
| `num_orders` | `AgentCountDayOrders()` | serialized `newDay`/`prevDay` для динамики заказов |

`options.php` валидирует `partner_url` regex-ом на `http/https` URL и сохраняет через `COption::SetOptionString()`.

## AJAX endpoint

`/bitrix/tools/storeassist.php`:

- подключает `prolog_before.php`;
- подключает lang;
- требует `Loader::includeModule('storeassist')`;
- принимает только POST;
- требует `action` и `check_bitrix_sessid()`;
- поддерживает действие `setOption`;
- ждёт `pageId` и `status`;
- вызывает `CStoreAssist::setSettingOption($_POST["pageId"], $_POST["status"])`;
- отвечает JSON через `Bitrix\Main\Web\Json::encode()`.

JS `BX.Storeassist.Admin.setOption(pageId, status)` отправляет:

```js
{
  pageId: pageId,
  status: status,
  action: "setOption",
  sessid: BX.bitrix_sessid()
}
```

## Admin toolbar

`onPrologAdminTitle($pageUrl, $pageId = "")`:

- работает только для `LANGUAGE_ID` `ru` или `ua`;
- требует права `storeassist >= R`;
- если `pageId` не передан, вытаскивает его из имени текущего `.php`;
- проверяет whitelist `$arAllPageId`;
- читает выполненные задачи из `storeassist_settings`;
- подключает JSCore `storeassist`, `fx` и CSS `/bitrix/panel/storeassist/storeassist.css`;
- рисует toolbar с кнопкой назад в `/bitrix/admin/storeassist.php`, статусом done/not done и кнопкой документации;
- при `storeassist >= W` даёт кнопку отметить задачу выполненной/невыполненной.

Диагностика: если toolbar не появился на admin page, проверяй язык, права, event registration, whitelist `pageId`, наличие copied CSS/JS и query `pageid` там, где страница не совпадает с task id.

## Admin menu

`onBuildGlobalMenu()`:

- работает только для `ru` / `ua`;
- требует права `storeassist >= R`;
- добавляет пункт `storeassist.php?lang=<LANGUAGE_ID>` в menu item с `items_id === "menu_sale_settings"`.

Если пункта “Мастер магазина” нет, проверяй:
1. модуль `storeassist` установлен;
2. dependency `main:OnBuildGlobalMenu` зарегистрирован;
3. права группы на модуль;
4. присутствует sale settings menu;
5. язык `ru` или `ua`.

## Структура мастера `storeassist.php`

Главная admin page строит `$arAssistSteps` из трёх секций.

### `MAIN` — настройки, без которых магазин не сможет работать

`BLOCK_1` — основные настройки:
- валюты → `/bitrix/admin/currencies.php`, requires `currency`;
- варианты цен → `cat_group_admin.php`, requires `catalog`;
- единицы измерений → `cat_measure_list.php`, requires `catalog`;
- реквизиты магазина → `sale_report_edit.php`, requires `sale`;
- типы плательщиков → `sale_person_type.php`, requires `sale`;
- покупатели/profile → `sale_buyers.php`, requires `sale`;
- статусы заказов → `sale_status.php`, requires `sale`;
- склады → `cat_store_list.php`, requires `catalog`;
- social/phone replacement → `storeassist_social.php`.

`BLOCK_2` — товары, остатки, цены:
- product list: если найден active catalog iblock типа `catalog`, ведёт в `cat_product_list.php?IBLOCK_ID=...`; иначе в `storeassist_new_items.php`;
- quantity settings → `settings.php?mid=catalog&pageid=quantity`;
- store documents → `cat_store_document_list.php`;
- order behavior → `settings.php?mid=sale&pageid=order_setting`;
- reserve settings → `settings.php?mid=catalog&pageid=reserve_setting`.

`BLOCK_3` — интеграция с 1С:
- `storeassist_1c_catalog_fill.php` — справочная страница первичного заполнения каталога из 1С;
- `1c_admin.php?pageid=1c_integration` — реальная настройка интеграции, requires `sale` in this wizard;
- `storeassist_1c_unloading.php` — справочная страница выгрузки товаров из магазина в 1С;
- `1c_admin.php?pageid=1c_exchange` — настройка обмена заказами, requires `sale`;
- `storeassist_1c_exchange_realtime.php` — справочная страница realtime exchange;
- `storeassist_1c_small_firm.php` — справочная страница “Управление небольшой фирмой”.

Важно: `storeassist_1c_*` pages сами не выполняют exchange. Они показывают текст и ссылку на документацию. Реальная настройка/обмен идут через `sale`/`catalog` admin pages и exchange components.

`BLOCK_4` — payments/delivery:
- `sale_pay_system.php`;
- `sale_delivery_service_list.php` или legacy `sale_delivery.php` в зависимости от option `main/~sale_converted_15`.

`BLOCK_5` — SEO/search:
- `storeassist_seo_settings.php`;
- `seo_robots.php`;
- `seo_sitemap.php`;
- `seo_search_yandex.php`;
- `seo_search_google.php`;
- `search_reindex.php`.

### `WORK` — повседневная работа магазина

- opening/adaptive/checklist;
- discounts and mailings: `cat_discount_admin.php`, `posting_admin.php`;
- marketplaces/export: `cat_export_setup.php`, `sale_ymarket.php`, eBay-related task id;
- orders: `sale_order.php`, `sale_report.php`, `sale_buyers.php`, `sale_account_admin.php`, `sale_basket.php`;
- personalization: `sale_personalization.php`;
- support: `blog_comment.php`, `ticket_desktop.php`;
- CRM: `sale_crm.php`, `storeassist_crm_client.php`, `storeassist_crm_calls.php`.

### `HEALTH` — здоровье магазина

- performance: `site_speed.php`, `bitrixcloud_cdn.php`, `composite.php`, `perfmon_panel.php`;
- security/backups: `security_filter.php`, `dump_auto.php`, `security_scanner.php`, `bitrixcloud_monitoring_admin.php`, `security_otp.php`;
- scale/infra: `scale_graph.php`, `cluster_index.php`, `storeassist_virtual.php`;
- support/info links.

## 1С pages: как трактовать

| Page | Что делает в core | Куда вести реальную диагностику |
|---|---|---|
| `storeassist_1c_catalog_fill.php` | static onboarding text + wizard/docs buttons | `catalog.import.1c`, `commerce-1c-integration.md` |
| `storeassist_1c_unloading.php` | static onboarding text + wizard/docs buttons | `catalog.export.1c`, `commerce-1c-integration.md` |
| `storeassist_1c_exchange_realtime.php` | static text about realtime exchange | сначала `commerce-1c-integration.md`, затем конкретный 1С-side setup |
| `storeassist_1c_small_firm.php` | static text about 1С:УНФ / CommerceML 2.0 | `commerce-1c-integration.md` |
| `1c_admin.php?pageid=1c_integration` | external sale/catalog admin route | `sale.md`, `catalog.md`, `commerce-1c-integration.md` |
| `1c_admin.php?pageid=1c_exchange` | external sale/catalog admin route | `sale.export.1c`, `sale_exchange_log` |

## Agent: progress by orders

`CStoreAssist::AgentCountDayOrders()`:

- runs only if `Loader::includeModule("sale")` succeeds;
- filters orders:
  - `STATUS_ID` in `F`, `P`;
  - `PAYED` = `Y`;
  - `DATE_STATUS` between calculated previous/current day boundaries;
- uses `CSaleOrder::GetList()` and `SelectedRowsCount()`;
- stores option `num_orders` as serialized array with `newDay` and `prevDay`;
- adjusts `progress_percent` between 0 and 10;
- returns its own agent string.

Если прогресс заказов не меняется, проверяй:
1. module agent exists for `storeassist`;
2. `sale` installed;
3. orders match statuses `F`/`P` and `PAYED=Y`;
4. `DATE_STATUS` falls into expected period;
5. options `num_orders` and `progress_percent`.

## Диагностика

### Task completion не сохраняется

Проверь:
1. POST идёт в `/bitrix/tools/storeassist.php`;
2. есть `sessid: BX.bitrix_sessid()`;
3. `check_bitrix_sessid()` проходит;
4. `pageId` есть в `CStoreAssist::$arAllPageId`;
5. `status` строго `Y` или `N`;
6. option `storeassist_settings` обновляется;
7. пользователь имеет право `storeassist >= W` для UI-кнопок.

### “Мастер магазина” не виден в меню

Проверь:
1. `storeassist` installed;
2. module rights `>= R`;
3. language `ru`/`ua`;
4. event `OnBuildGlobalMenu` registered;
5. sale settings menu item `menu_sale_settings` существует.

### Toolbar не появился на странице

Проверь:
1. language `ru`/`ua`;
2. права `storeassist >= R`;
3. `OnPrologAdminTitle` registered;
4. page id в whitelist;
5. если реальная admin page не совпадает с task id — передаётся `pageid` в URL;
6. copied `/bitrix/panel/storeassist/storeassist.css` и JS extension.

### Пользователь думает, что `storeassist_1c_*` выполняет обмен

Объясняй: это onboarding/static pages. Для реального exchange проверяются:
- `catalog.import.1c` / `catalog.export.1c`;
- `sale.export.1c`;
- `/bitrix/admin/1c_admin.php`;
- `/bitrix/admin/1c_exchange.php`;
- `b_sale_exchange_log`, temp files, sessions, `BX_CML2_IMPORT` / `BX_CML2_EXPORT`.

## Что нельзя делать

- Не чинить реальный 1С import/export в `storeassist_1c_*` страницах: там нет exchange engine.
- Не считать `storeassist_settings` бизнес-статусом магазина — это только чеклист мастера.
- Не использовать `AgentCountDayOrders()` как аналитический отчёт продаж: это грубый indicator для progress widget.
- Не открывать внешние doc/help URLs как source of truth, если есть локальный core. Для поведения модуля приоритет у files выше.
- Не активировать `storeassist` route в другом проекте без проверки `www/bitrix/modules/storeassist`.


---

## Source: `shop-standard-components.md`

# Shop standard components — витрина, корзина, checkout, личный кабинет

> Reference для Bitrix-скилла. Загружай, когда задача связана со стандартными компонентами интернет-магазина: `bitrix:catalog`, `catalog.section`, `catalog.element`, `catalog.smart.filter`, compare, basket, checkout/order, personal order pages, admin productcard/store components, viewed/recommended/gifts или когда нужно понять, где реально лежит компонент.

## Audit note

Проверено по shop-core:
- `www/bitrix/modules/iblock/install/components/bitrix/catalog*`
- `www/bitrix/modules/catalog/install/components/bitrix/catalog*`
- `www/bitrix/modules/sale/install/components/bitrix/sale*`
- `www/bitrix/modules/bitrix.eshop/install/components/bitrix/*`
- `www/bitrix/modules/bitrix.eshop/install/wizards/bitrix/eshop/site/*`
- `catalog.section` / `catalog.element` class + ajax + stock templates
- `catalog.smart.filter` component/class/templates
- `sale.basket.basket`, `sale.order.ajax`, `sale.order.checkout`, `sale.personal.order*`
- `catalog.import.1c`, `catalog.export.1c`, `sale.export.1c` component parameters

Ниже только layer map и подтверждённые контракты из этого core. Для deep API товаров/цен/остатков читай `catalog.md`; для basket/order/payment/delivery — `sale.md`; для 1С — `commerce-1c-integration.md`; для pagination/lazy load — `pagination.md`.

## Главный вывод

Витринные `catalog.*` компоненты в этом core находятся в модуле `iblock`.

Это критично:
- наличие `www/bitrix/modules/iblock/install/components/bitrix/catalog.section` **не доказывает** установленный модуль `catalog`;
- полноценная торговая логика всё равно требует `catalog`, `sale`, `currency`;
- для чужого проекта сначала проверяй `www/bitrix/modules/catalog`, `www/bitrix/modules/sale`, `www/bitrix/modules/currency`.

## Component inventory

### `iblock` public catalog components

Подтверждены 18 shop-facing components:

| Component | Files | Templates | Роль |
|---|---|---:|---|
| `catalog` | `.parameters.php`, `component.php` | 3 | комплексный catalog router |
| `catalog.section` | `.parameters.php`, `class.php`, `ajax.php` | 6 | список товаров раздела |
| `catalog.element` | `.parameters.php`, `class.php`, `ajax.php` | 4 | детальная карточка товара |
| `catalog.smart.filter` | `.parameters.php`, `component.php`, `class.php` | 2 | умный фильтр/facet |
| `catalog.compare.list` | `.parameters.php`, `component.php` | 2 | список сравнения |
| `catalog.compare.result` | `.parameters.php`, `component.php` | 2 | таблица сравнения |
| `catalog.filter` | `.parameters.php`, `component.php` | 3 | legacy filter |
| `catalog.search` | `.parameters.php`, `component.php` | 2 | поиск по каталогу |
| `catalog.section.list` | `.parameters.php`, `component.php` | 5 | список разделов |
| `catalog.sections.top` | `.parameters.php`, `component.php` | 1 | top-разделы |
| `catalog.top` | `.parameters.php`, `class.php` | 3 | top products |
| `catalog.item` | `class.php`, `ajax.php` | 3 | item renderer/helper |
| `catalog.main` | `.parameters.php`, `component.php` | 1 | catalog main helper |
| `catalog.brandblock` | `.parameters.php`, `component.php` | 2 | brand block |
| `catalog.comments` | `.parameters.php`, `component.php` | 1 | comments bridge |
| `catalog.link.list` | `.parameters.php`, `component.php` | 1 | linked elements |
| `catalog.socnets.buttons` | `.parameters.php`, `component.php` | 1 | social buttons |
| `catalog.tabs` | `component.php` | 1 | tabs helper |

### `catalog` module components

`catalog` module components в основном отвечают за admin/productcard/store/report/1С/service UI:

- 1С/import/export: `catalog.import.1c`, `catalog.export.1c`, `catalog.import.hl`;
- product grid/card: `catalog.product.grid`, `catalog.productcard.*`, `catalog.grid.product.field`, `catalog.product.search`;
- stores/documents: `catalog.store*`, `catalog.store.document.*`, `catalog.store.entity.*`;
- reports: `catalog.report.store_*`;
- public-ish recommendations/viewed: `catalog.bigdata.products`, `catalog.products.viewed`, `catalog.viewed.products`, `catalog.recommended.products`;
- subscription: `catalog.product.subscribe*`;
- config/admin helpers: `catalog.config.*`, `catalog.seo.detail`, `catalog.set.constructor`.

Exhaustive component directory list in this core:

`catalog.agent.contract.controller`, `catalog.agent.contract.detail`, `catalog.agent.contract.list`, `catalog.bigdata.products`, `catalog.catalog.controller`, `catalog.compilation`, `catalog.config.permissions`, `catalog.config.settings`, `catalog.contractor.list`, `catalog.discsave.info`, `catalog.export.1c`, `catalog.feedback`, `catalog.grid.product.field`, `catalog.image.input`, `catalog.import.1c`, `catalog.import.hl`, `catalog.notfounderror`, `catalog.product.grid`, `catalog.product.search`, `catalog.product.subscribe`, `catalog.product.subscribe.list`, `catalog.productcard.controller`, `catalog.productcard.details`, `catalog.productcard.iblocksectionfield`, `catalog.productcard.reserved.deal.list`, `catalog.productcard.service.grid`, `catalog.productcard.store.amount`, `catalog.productcard.store.amount.details`, `catalog.productcard.store.amount.details.slider`, `catalog.productcard.variation.details`, `catalog.productcard.variation.grid`, `catalog.products.viewed`, `catalog.property.creation.form`, `catalog.recommended.products`, `catalog.report.store_profit.grid`, `catalog.report.store_profit.products.grid`, `catalog.report.store_sale.chart`, `catalog.report.store_sale.chart.stores.grid`, `catalog.report.store_sale.grid`, `catalog.report.store_sale.products.grid`, `catalog.report.store_stock.grid`, `catalog.report.store_stock.products.grid`, `catalog.report.store_stock.salechart`, `catalog.report.store_stock.salechart.stores.grid`, `catalog.seo.detail`, `catalog.set.constructor`, `catalog.show.products.mail`, `catalog.store`, `catalog.store.admin_list`, `catalog.store.amount`, `catalog.store.detail`, `catalog.store.document.control_panel`, `catalog.store.document.controller`, `catalog.store.document.detail`, `catalog.store.document.list`, `catalog.store.document.product.list`, `catalog.store.enablewizard`, `catalog.store.entity.controller`, `catalog.store.entity.details`, `catalog.store.field.config.list`, `catalog.store.list`, `catalog.viewed.products`.

### `sale` module components

Подтверждены ключевые families:

- basket: `sale.basket.basket`, `sale.basket.basket.line`, `sale.basket.basket.small`, `sale.basket.order.ajax`;
- checkout/order: `sale.order.ajax`, `sale.order.checkout`, `sale.order.payment*`, `sale.order.full`;
- personal cabinet: `sale.personal.order*`, `sale.personal.profile*`, `sale.personal.account`, `sale.personal.section`, `sale.personal.subscribe*`;
- delivery/location: `sale.ajax.delivery.calculator`, `sale.delivery.request*`, `sale.location.*`, `sale.store.choose`;
- gifts/recommendations: `sale.gift.*`, `sale.products.gift*`, `sale.recommended.products`, `sale.bestsellers`;
- 1С: `sale.export.1c`;
- mail/bigdata: `sale.bigdata.followup.mail`, `sale.bigdata.personal.mail`, `sale.discount.coupon.mail`;
- mobile admin/order: `sale.mobile.order.*`, `sale.mobile.orders.*`, `sale.mobile.product.list`.

Exhaustive component directory list in this core:

`sale.account.pay`, `sale.admin.page.stub`, `sale.affiliate.account`, `sale.affiliate.instructions`, `sale.affiliate.plans`, `sale.affiliate.register`, `sale.affiliate.report`, `sale.ajax.delivery.calculator`, `sale.basket.basket`, `sale.basket.basket.line`, `sale.basket.basket.small`, `sale.basket.basket.small.mail`, `sale.basket.order.ajax`, `sale.bestsellers`, `sale.bigdata.followup.mail`, `sale.bigdata.personal.mail`, `sale.bsm.site.master`, `sale.bsm.site.master.button`, `sale.business.value.mail`, `sale.crm.site.master`, `sale.delivery.request`, `sale.delivery.request.processed`, `sale.delivery.ruspost.reliability`, `sale.discount.coupon.mail`, `sale.domain.verification.form`, `sale.ebay.categories`, `sale.export.1c`, `sale.facebook.conversion`, `sale.gift.basket`, `sale.gift.main.products`, `sale.gift.product`, `sale.gift.section`, `sale.location.import`, `sale.location.map`, `sale.location.reindex`, `sale.location.selector.search`, `sale.location.selector.steps`, `sale.location.selector.system`, `sale.mobile.order.barcodes`, `sale.mobile.order.deduction`, `sale.mobile.order.detail`, `sale.mobile.order.history`, `sale.mobile.order.stores`, `sale.mobile.order.transact`, `sale.mobile.orders.list`, `sale.mobile.orders.push`, `sale.mobile.product.list`, `sale.notice.product`, `sale.order.ajax`, `sale.order.checkout`, `sale.order.full`, `sale.order.payment`, `sale.order.payment.change`, `sale.order.payment.receive`, `sale.paysystem.registration.robokassa`, `sale.paysystem.settings.robokassa`, `sale.personal.account`, `sale.personal.cc`, `sale.personal.cc.detail`, `sale.personal.cc.list`, `sale.personal.order`, `sale.personal.order.cancel`, `sale.personal.order.detail`, `sale.personal.order.detail.mail`, `sale.personal.order.list`, `sale.personal.profile`, `sale.personal.profile.detail`, `sale.personal.profile.list`, `sale.personal.section`, `sale.personal.subscribe`, `sale.personal.subscribe.cancel`, `sale.personal.subscribe.list`, `sale.prediction.product.detail`, `sale.products.gift`, `sale.products.gift.basket`, `sale.products.gift.section`, `sale.recommended.products`, `sale.store.choose`.

### `bitrix.eshop` solution layer

`bitrix.eshop` 25.0.0 in this core is a solution/wizard layer, not a separate commerce engine.

Confirmed own components:
- `eshop.banner`
- `eshop.facebook.plugin`
- `eshop.socnet.links`

Confirmed wizard/templates reference these components:

`advertising.banner`, `breadcrumb`, `catalog`, `catalog.section`, `catalog.section.list`, `catalog.store`, `catalog.viewed.products`, `eshop.banner`, `eshop.facebook.plugin`, `eshop.socnet.links`, `idea.popup`, `main.feedback`, `main.include`, `main.map`, `menu`, `menu.sections`, `news`, `news.list`, `sale.basket.basket`, `sale.basket.basket.line`, `sale.order.ajax`, `sale.order.payment`, `sale.order.payment.receive`, `sale.personal.order`, `sale.personal.section`, `search.page`, `search.title`, `sender.subscribe`, `socserv.auth.split`, `system.field.edit`.

Gotchas:
- `bitrix.eshop` creates/ships site skeleton, templates, wizard services and demo/public files; runtime commerce behavior still goes through `iblock`, `catalog`, `sale`, `currency`, `sender`, `advertising`, `search` and template code.
- If a project was bootstrapped from eShop wizard, inspect `bitrix/templates/*`, `local/templates/*`, copied public pages and component templates before changing standard component code.
- `eshop_templates_rename.php` is an admin helper for templates; do not treat it as shop runtime.

## Комплексный `bitrix:catalog`

`iblock/install/components/bitrix/catalog` — complex component/router.

Подтверждённые группы параметров:
- `SECTIONS_SETTINGS`
- `LIST_SETTINGS`
- `DETAIL_SETTINGS`
- `FILTER_SETTINGS`
- `COMPARE_SETTINGS`
- `OFFERS_SETTINGS`
- `PRICES`
- `BASKET`
- `GIFTS_SETTINGS`
- `ALSO_BUY_SETTINGS`
- `BIG_DATA_SETTINGS`
- `ANALYTICS_SETTINGS`
- `REVIEW_SETTINGS`
- `SEARCH_SETTINGS`

`component.php` оперирует:
- `FOLDER`
- `URL_TEMPLATES`
- `VARIABLES`
- `ALIASES`

Практика: при задаче по URL/SEF комплексного каталога открывай `sef-urls.md`, `components.md`, `pagination.md` и конкретный child component (`catalog.section`, `catalog.element`, `catalog.smart.filter`).

## `catalog.section`

Файлы:
- `.parameters.php`
- `class.php`
- `ajax.php`
- stock templates: 6

Подтверждённые важные параметры:

| Группа | Параметры |
|---|---|
| Data source | `IBLOCK_TYPE`, `IBLOCK_ID`, `SECTION_ID`, `SECTION_CODE`, `SECTION_CODE_PATH`, `SECTION_ID_VARIABLE`, `INCLUDE_SUBSECTIONS`, `SHOW_ALL_WO_SECTION` |
| Sort/page | `ELEMENT_SORT_FIELD`, `ELEMENT_SORT_ORDER`, `ELEMENT_SORT_FIELD2`, `ELEMENT_SORT_ORDER2`, `PAGE_ELEMENT_COUNT`, `LINE_ELEMENT_COUNT` |
| Select | `PROPERTY_CODE`, `PROPERTY_CODE_MOBILE`, `SECTION_USER_FIELDS`, `BACKGROUND_IMAGE` |
| Prices | `PRICE_CODE`, `USE_PRICE_COUNT`, `SHOW_PRICE_COUNT`, `PRICE_VAT_INCLUDE` |
| Offers | `OFFERS_FIELD_CODE`, `OFFERS_PROPERTY_CODE`, `OFFERS_SORT_FIELD`, `OFFERS_SORT_ORDER`, `OFFERS_LIMIT` |
| Basket action | `BASKET_URL`, `ACTION_VARIABLE`, `PRODUCT_ID_VARIABLE`, `PRODUCT_QUANTITY_VARIABLE`, `PRODUCT_PROPS_VARIABLE`, `USE_PRODUCT_QUANTITY`, `ADD_PROPERTIES_TO_BASKET`, `PRODUCT_PROPERTIES`, `PARTIAL_PRODUCT_PROPERTIES` |
| Filter/compare | `FILTER_NAME`, `COMPARE` |
| SEO/meta | `SET_TITLE`, `SET_BROWSER_TITLE`, `SET_META_KEYWORDS`, `SET_META_DESCRIPTION`, `SET_LAST_MODIFIED`, `BROWSER_TITLE`, `META_KEYWORDS`, `META_DESCRIPTION` |
| JS/runtime | `DISABLE_INIT_JS_IN_COMPONENT`, `COMPATIBLE_MODE`, `AJAX_MODE` |

Core facts:
- `class.php` checks iblock/catalog-related fields and edit links;
- `ajax.php` exists;
- stock templates contain lazy/show-more logic in shop-core templates;
- pagination and lazy load use `PAGEN_<NavNum>` — смотри `pagination.md`.

Gotchas:
- `nTopCount` is not pagination; for page bugs open `pagination.md`.
- Use stable sort with `ID` to avoid duplicates/skips.
- `FILTER_NAME` must point to an actual global filter array; do not pass user input raw.
- Parent product vs offer matters: price/stock/basket often resolve on offer.
- `SHOW_ALL_WO_SECTION` changes visibility when section is missing.

## `catalog.element`

Файлы:
- `.parameters.php`
- `class.php`
- `ajax.php`
- stock templates: 4

Подтверждённые важные параметры:

| Группа | Параметры |
|---|---|
| Element identity | `ELEMENT_ID`, `ELEMENT_CODE`, `SECTION_ID`, `SECTION_CODE`, `SECTION_CODE_PATH`, `CHECK_SECTION_ID_VARIABLE`, `STRICT_SECTION_CHECK` |
| Properties | `PROPERTY_CODE`, `LINK_IBLOCK_TYPE`, `LINK_IBLOCK_ID`, `LINK_PROPERTY_SID`, `LINK_ELEMENTS_URL` |
| Offers | `OFFERS_FIELD_CODE`, `OFFERS_PROPERTY_CODE`, `OFFERS_SORT_FIELD`, `OFFERS_SORT_ORDER`, `OFFERS_LIMIT`, `SHOW_SKU_DESCRIPTION` |
| Prices | `PRICE_CODE`, `USE_PRICE_COUNT`, `SHOW_PRICE_COUNT`, `PRICE_VAT_INCLUDE`, `PRICE_VAT_SHOW_VALUE` |
| Basket action | `BASKET_URL`, `ACTION_VARIABLE`, `PRODUCT_ID_VARIABLE`, `PRODUCT_QUANTITY_VARIABLE`, `PRODUCT_PROPS_VARIABLE`, `USE_PRODUCT_QUANTITY`, `ADD_PROPERTIES_TO_BASKET`, `PRODUCT_PROPERTIES`, `PARTIAL_PRODUCT_PROPERTIES` |
| SEO/meta | `SET_TITLE`, `SET_CANONICAL_URL`, `SET_BROWSER_TITLE`, `SET_META_KEYWORDS`, `SET_META_DESCRIPTION`, `SET_LAST_MODIFIED`, `ADD_ELEMENT_CHAIN`, `ADD_SECTIONS_CHAIN` |
| Gifts/analytics | `USE_GIFTS_DETAIL`, `USE_GIFTS_MAIN_PR_SECTION_LIST`, `ANALYTICS_SETTINGS` |

Core facts:
- `ajax.php` returns status/text style response keys;
- class code references `PRODUCT_ID`, `OFFER_ID`, `CATALOG_GROUP_ID`, `GROUP_ID`, `IBLOCK_ID`, `LID`;
- SKU/offer selection is template+JS-sensitive.

Gotchas:
- If product visible but cannot buy, check offer ID, price group, quantity, catalog provider and basket events in `catalog.md` / `sale.md`.
- If SEO/canonical wrong, check both component params and template overrides.
- If AJAX add-to-basket fails, inspect template JS, `ACTION_VARIABLE`, `PRODUCT_ID_VARIABLE`, `sessid`, and basket response.

## `catalog.smart.filter`

Файлы:
- `.parameters.php`
- `component.php`
- `class.php`
- stock templates: 2

Подтверждённые параметры:
- `IBLOCK_TYPE`
- `IBLOCK_ID`
- `SECTION_ID`
- `SECTION_CODE`
- `SECTION_CODE_PATH`
- `FILTER_NAME`
- `PREFILTER_NAME`
- `PRICE_CODE`
- `CACHE_GROUPS`
- `SAVE_IN_SESSION`
- `XML_EXPORT`
- `SECTION_TITLE`
- `SECTION_DESCRIPTION`
- `SMART_FILTER_PATH`
- `SEF_MODE`
- `SEF_RULE`
- `PAGER_PARAMS_NAME`

Class/component confirmed fields include:
- `CONTROL_ID`
- `CONTROL_NAME`
- `CONTROL_NAME_ALT`
- `HTML_VALUE`
- `HTML_VALUE_ALT`
- `DISPLAY_TYPE`
- `DISPLAY_EXPANDED`
- `FILTER_HINT`
- `PRICE`
- `PROPERTY_TYPE`
- `USER_TYPE`
- `USER_TYPE_SETTINGS`
- `MIN`, `MAX`
- `URL_ID`

Gotchas:
- Smart filter is tightly coupled with section scope and facet/filter indexes. If products disappear after filter, read `diagnostic-visibility.md`, `index-cache-diagnostics.md`, `pagination.md`.
- `SAVE_IN_SESSION` can preserve old filter state.
- `PREFILTER_NAME` is separate from `FILTER_NAME`.
- SEF filter URL issues go to `sef-urls.md`.

## Compare components

### `catalog.compare.list`

Parameters:
- `IBLOCK_TYPE`, `IBLOCK_ID`
- `DETAIL_URL`
- `COMPARE_URL`
- `ACTION_VARIABLE`
- `PRODUCT_ID_VARIABLE`
- `AJAX_MODE`

Component fields include `DELETE_URL`, `DETAIL_PAGE_URL`, `SECTIONS_LIST`, `COUNT`, `STATUS`.

### `catalog.compare.result`

Parameters:
- `IBLOCK_TYPE`, `IBLOCK_ID`
- `FIELD_CODE`, `PROPERTY_CODE`
- `PRICE_CODE`, `USE_PRICE_COUNT`, `SHOW_PRICE_COUNT`, `PRICE_VAT_INCLUDE`
- `OFFERS_FIELD_CODE`, `OFFERS_PROPERTY_CODE`
- `BASKET_URL`, `ACTION_VARIABLE`, `PRODUCT_ID_VARIABLE`, `SECTION_ID_VARIABLE`
- `DISPLAY_ELEMENT_SELECT_BOX`

Gotchas:
- Compare state is usually user/session/browser-state sensitive. Check component params, AJAX mode and template JS.
- Offers compare requires offer fields/properties, not just parent product properties.

## Basket components

### `sale.basket.basket`

Files:
- `.parameters.php`
- `class.php`
- `ajax.php`
- templates: 2

Important params:
- `PATH_TO_ORDER`
- `HIDE_COUPON`
- `COLUMNS_LIST_EXT`
- `COLUMNS_LIST_MOBILE`
- `OFFERS_PROPS`
- `ACTION_VARIABLE`
- `AUTO_CALCULATION`
- `CORRECT_RATIO`
- `COMPATIBLE_MODE`
- `USE_GIFTS`
- `GIFTS_*`
- `USE_PREPAYMENT`
- `SET_TITLE`

Class fields confirm basket states:
- `BASKET_ITEMS`
- `BASKET_REFRESHED`
- `CHANGED_BASKET_ITEMS`
- `DELETED_BASKET_ITEMS`
- `RESTORED_BASKET_ITEMS`
- `MERGED_BASKET_ITEMS`
- `COUPON_LIST`
- `WARNING_MESSAGE`
- `ERROR_MESSAGE`
- `SALE_BASKET_AVAILABLE_QUANTITY`
- `SALE_BASKET_ITEM_WRONG_AVAILABLE_QUANTITY`
- `SALE_BASKET_ITEM_WRONG_PRICE`

Gotchas:
- Basket can refresh/merge/delete items before rendering; do not debug only template.
- Wrong price/quantity warnings usually point to catalog provider, price access, stock or ratio.
- Coupon issues require sale discount/coupon layer.

### `sale.basket.order.ajax`

Legacy checkout component with `component.php` and one template.

Confirmed fields include:
- `BASKET_ITEMS`
- `DELIVERY_ID`, `DELIVERY_PRICE`
- `PAY_SYSTEM_ID`
- `PERSON_TYPE_ID`
- `ORDER_PROPS_ID`
- `ORDER_PRICE`
- `ORDER_WEIGHT`
- `USER_DESCRIPTION`
- `ORDER_ID`, `ORDER_LIST`

Use it as legacy route. For modern checkout prefer checking `sale.order.ajax` / `sale.order.checkout` if present in project.

## Checkout/order components

### `sale.order.ajax`

Files:
- `.parameters.php`
- `class.php`
- `ajax.php`
- templates: 2

Important params:
- `PATH_TO_BASKET`
- `PATH_TO_PERSONAL`
- `PATH_TO_AUTH`
- `PATH_TO_PAYMENT`
- `ALLOW_AUTO_REGISTER`
- `ALLOW_APPEND_ORDER`
- `DISABLE_BASKET_REDIRECT`
- `ONLY_FULL_PAY_FROM_ACCOUNT`
- `SEND_NEW_USER_NOTIFY`
- `DELIVERY_NO_AJAX`
- `DELIVERY_NO_SESSION`
- `DELIVERY_TO_PAYSYSTEM`
- `SHOW_NOT_CALCULATED_DELIVERIES`
- `SPOT_LOCATION_BY_GEOIP`
- `TEMPLATE_LOCATION`
- `USE_PREPAYMENT`
- `USE_PHONE_NORMALIZATION`
- `USER_CONSENT`, `USER_CONSENT_IDS`
- `SHOW_VAT_PRICE`

Class fields confirm:
- auth/registration fields;
- basket positions and discounts;
- delivery/pay system selection;
- location/zip fields;
- final step/order request;
- `ERROR`, `ERROR_SORTED`;
- `ORDER_TOTAL_LEFT_TO_PAY`.

Gotchas:
- Checkout bugs are usually not template-only. Follow: basket refresh → person type → required order props → location → delivery restrictions → payment restrictions → discounts → `Order::save()`.
- `DELIVERY_NO_SESSION` / `DELIVERY_NO_AJAX` can change user-visible behavior.
- Phone normalization/user consent are parameterized.

### `sale.order.checkout`

Files:
- `.parameters.php`
- `class.php`
- `ajax.php`
- templates: 1

Params:
- `SHOW_RETURN_BUTTON`
- `URL_PATH_TO_DETAIL_PRODUCT`

Class/ajax fields confirm a newer checkout flow with:
- `ORDER`, `BASKET`, `PAYMENTS`, `PAY_SYSTEMS`;
- `JSON_DATA`;
- `USER_CONSENT_PROPERTY_DATA`;
- `ACTIONS`, `FIELDS`, `ERRORS` in ajax;
- basket item operations: `DELETE`, `RESTORE`, `QUANTITY`, `NEED_FULL_RECALCULATION`.

Gotchas:
- Treat as separate checkout route, not the same as `sale.order.ajax`.
- AJAX contract matters; inspect template JS before changing server code.

## Personal order components

### `sale.personal.order`

Complex personal orders router.

Params:
- `SEF_MODE`
- `PATH_TO_BASKET`
- `PATH_TO_CATALOG`
- `PATH_TO_PAYMENT`
- `ORDERS_PER_PAGE`
- `NAV_TEMPLATE`
- `DISALLOW_CANCEL`
- `SAVE_IN_SESSION`
- `CACHE_GROUPS`
- `SET_TITLE`

### `sale.personal.order.list`

Params:
- `PATH_TO_DETAIL`
- `PATH_TO_CANCEL`
- `PATH_TO_COPY`
- `PATH_TO_BASKET`
- `PATH_TO_CATALOG`
- `PATH_TO_PAYMENT`
- `ORDERS_PER_PAGE`
- `NAV_TEMPLATE`
- `DISALLOW_CANCEL`
- `SAVE_IN_SESSION`

Fields include `ORDER`, `PAYMENT`, `SHIPMENT`, `BASKET_ITEMS`, `USER_ID`.

### `sale.personal.order.detail`

Params:
- `PATH_TO_LIST`
- `PATH_TO_CANCEL`
- `PATH_TO_COPY`
- `PATH_TO_PAYMENT`
- `PERSON_TYPE_ID`
- `SET_TITLE`

Gotchas:
- Personal cabinet must filter by current user and site; if orders leak/missing, check user binding, permissions and path params.
- `SAVE_IN_SESSION` can affect list state.
- Copy/cancel/payment links must be checked through sale permissions/status restrictions.

## Catalog admin/productcard/store components

These are not public storefront components, but matter for admin tasks.

### Product/card

- `catalog.product.grid` — product grid; confirmed fields: `GRID_ID`, `IBLOCK_ID`, `IBLOCK_SECTION_ID`, `PRODUCT_TYPE`, `SKU_FIELD_NAMES`, `SKU_PRODUCT_MAP`, `NAV_STRING`, `URL_TO_ADD_PRODUCT`.
- `catalog.productcard.details` — card fields; confirmed fields include `ENTITY_ID`, `ENTITY_FIELDS`, `ENTITY_VALUES`, `IBLOCK_ID`, `PRICE`, `PROPERTY_FIELDS`, `SEO`, `SMART_FILTER`, `IS_SIMPLE_PRODUCT`.
- `catalog.productcard.variation.grid/details` — variations/SKU admin UI.

### Store documents

- `catalog.store.document.list` — document grid; fields include `GRID_ID`, `FILTER_ID`, `DOC_TYPE`, `STATUS`, `STORES_FROM`, `STORES_TO`, `WAS_CANCELLED`.
- `catalog.store.document.detail` — document form; fields include `DOCUMENT_ID`, `DOCUMENT_TYPE`, `ELEMENTS`, `PRODUCT_ID`, `STORE_FROM`, `STORE_TO`, `AMOUNT`, `PURCHASING_PRICE`, `BARCODE`, `ERROR_MESSAGE`.

Use `catalog.md` for product/store API and `grid-admin-modern.md` for grid mechanics.

## Viewed/recommended/gifts/bigdata

Confirmed components:
- catalog: `catalog.bigdata.products`, `catalog.products.viewed`, `catalog.viewed.products`, `catalog.recommended.products`;
- sale: `sale.bestsellers`, `sale.gift.*`, `sale.products.gift*`, `sale.recommended.products`, `sale.prediction.product.detail`.

Gotchas:
- Recommendations/gifts depend on catalog + sale + user/basket/order context.
- Cache and personalization can make bugs look non-deterministic.
- For marketing/personalization deep dive, use future `shop-marketing-analytics.md`.

## 1С components quick map

### `catalog.import.1c`

Params confirmed:
- `IBLOCK_TYPE`
- `SITE_LIST`
- `INTERVAL`
- `GROUP_PERMISSIONS`
- `FILE_SIZE_LIMIT`
- `USE_CRC`
- `USE_ZIP`
- `USE_OFFERS`
- `FORCE_OFFERS`
- `SKIP_ROOT_SECTION`
- `SKIP_SOURCE_CHECK`
- `ELEMENT_ACTION`
- `SECTION_ACTION`
- `TRANSLIT`
- `IBLOCK_CACHE_MODE`

Component fields include `STEP`, `TEMP_DIR`, `IBLOCK_ID`, `PRICES_MAP`, `SECTION_MAP`.

### `catalog.export.1c`

Params confirmed:
- `IBLOCK_ID`
- `INTERVAL`
- `GROUP_PERMISSIONS`
- `USE_ZIP`
- `ELEMENTS_PER_STEP`

Component fields include `LAST_ID`, `PROPERTY_MAP`, `PRICES_MAP`, `SECTION_MAP`, `PRODUCT_IBLOCK_ID`.

### `sale.export.1c`

Params confirmed:
- `SITE_LIST`
- `EXPORT_PAYED_ORDERS`
- `EXPORT_ALLOW_DELIVERY_ORDERS`
- `EXPORT_FINAL_ORDERS`
- `FINAL_STATUS_ON_DELIVERY`
- `REPLACE_CURRENCY`
- `GROUP_PERMISSIONS`
- `USE_ZIP`
- `INTERVAL`
- `FILE_SIZE_LIMIT`
- `IMPORT_NEW_ORDERS`
- `CHANGE_STATUS_FROM_1C`

For actual exchange flow, use `commerce-1c-integration.md`.

## Diagnostics by symptom

### Catalog list empty, detail opens

Read in order:
1. `diagnostic-visibility.md` — active/site/permissions/section chain;
2. `catalog.section` params: section/filter/sort/page;
3. `catalog.smart.filter` state and facet/index;
4. `pagination.md` for page/offset/lazy load;
5. `cache-infra.md` / `index-cache-diagnostics.md`.

### Filter changes but products do not

Check:
- `FILTER_NAME` global array;
- `PREFILTER_NAME`;
- `SAVE_IN_SESSION`;
- `SMART_FILTER_PATH` / SEF;
- cache key;
- facet/search index.

### Add to basket fails from list/detail

Check:
- component action variables;
- selected offer ID, not parent ID;
- price group and currency;
- quantity/ratio/stock;
- `ADD_PROPERTIES_TO_BASKET`, `PRODUCT_PROPERTIES`, `PARTIAL_PRODUCT_PROPERTIES`;
- template JS and ajax endpoint;
- sale basket warnings.

### Checkout fails

Check:
1. basket refreshed and not empty;
2. person type;
3. required order properties;
4. location;
5. delivery restrictions;
6. payment restrictions;
7. discounts/coupons;
8. `Order::save()` errors;
9. component AJAX/template.

### Personal order missing

Check:
- current user;
- site `LID`;
- `PATH_TO_*` params;
- `ORDERS_PER_PAGE` and pagination;
- cancel/copy/payment restrictions;
- `SAVE_IN_SESSION`.

## What not to do

- Do not treat `iblock`-hosted `catalog.*` as proof that `catalog` module exists.
- Do not debug every storefront issue from template only; standard components have class/component logic, ajax, cache, sale/catalog side effects.
- Do not mix `sale.order.ajax`, `sale.order.checkout`, and `sale.basket.order.ajax` as one component: they are different flows.
- Do not bypass sale/catalog APIs with SQL for basket/order/price/stock fixes.
- Do not promise exact params for project overrides until checking `local/components` and `local/templates`.
- Do not ignore JS/template variants: many public shop components are template-driven.


---

## Source: `shop-marketing-analytics.md`

# Shop marketing/analytics — sender, mail, SMS, subscribe, ads, A/B, conversion, reports, statistic

> Reference для Bitrix-скилла. Загружай, когда задача связана с маркетингом интернет-магазина: рассылки, подписки, сегменты покупателей, follow-up, email/SMS sender, consent, opens/clicks, UTM, баннеры, A/B тесты, conversion counters, отчёты, legacy statistic или когда пользователь спрашивает, покрыты ли marketing/analytics modules shop-core.

## Audit note

Проверено по shop-core:

- `www/bitrix/modules/sender` — `26.0.0`
- `www/bitrix/modules/mail` — `26.100.200`
- `www/bitrix/modules/messageservice` — `25.200.100`
- `www/bitrix/modules/subscribe` — `25.0.0`
- `www/bitrix/modules/advertising` — `24.200.0`
- `www/bitrix/modules/abtest` — `26.0.0`
- `www/bitrix/modules/conversion` — `25.0.0`
- `www/bitrix/modules/report` — `25.100.0`
- `www/bitrix/modules/statistic` — `26.0.0`
- eShop wizard/public/template calls in `bitrix.eshop`
- sale-side marketing connectors: `sale/lib/senderconnector.php`, `sale/lib/bigdata/targetsalemailconnector.php`, sale statistic events

Ниже только подтверждённый routing/contract layer. Для корзины/заказов читай `sale.md`; для catalog product subscription — `catalog.md`; для стандартных shop components — `shop-standard-components.md`; для email/SMS общих уведомлений — `mail-notifications.md` и `messageservice.md`; для REST/webservice sale/statistic integration extras — `shop-integrations-webservice.md`, затем `rest.md`.

## Главный вывод

Marketing/analytics в shop-core — это не один модуль.

Рабочий стек:

1. `sender` — современный marketing hub: contacts, segments, campaigns/letters, triggers, posting queue, opens/clicks, consent, UTM, stats.
2. `mail` — mailbox/client/sync/log layer и mail event read tracking side-channel.
3. `messageservice` — SMS/WA/message providers, queue, limits/restrictions, REST providers.
4. `subscribe` — legacy subscriptions/postings/rubrics; также отдаёт connector в `sender`.
5. `advertising` — banners/contracts, show/click dynamics, conversion counters.
6. `abtest` — site template/page rewrite A/B tests + conversion context attributes.
7. `conversion` — generic counters/attributes/rates/day context.
8. `report` — report builder/visual constructor and sharing.
9. `statistic` — legacy traffic/session/hit/event/advertising statistics; heavy runtime hooks.

Критично:
- `sender.subscribe` и `subscribe.*` — разные подсистемы;
- catalog product subscription (`b_catalog_subscribe`, option `sale.subscribe_prod`) не равно email marketing subscription;
- conversion/statistic/report не заменяют друг друга;
- для клиентского проекта каждый модуль подтверждай отдельно в `www/bitrix/modules/<module>`.

## Fast routing

| Запрос | Сначала читать | Затем |
|---|---|---|
| “Рассылка не отправляется” | `sender` section ниже | `mail-notifications.md`, agents/cron, `mail` logs |
| “Подписка с формы не работает” | `sender.subscribe` или `subscribe.form/edit` ниже | `userconsent.md`, `mail-notifications.md` |
| “Нужен сегмент покупателей” | `sender` + sale connectors below | `sale.md`, `shop-task-matrix.md` |
| “SMS не ушла / лимиты SMS” | `messageservice` section | `messageservice.md`, REST/provider config |
| “Баннер не показался / клики не считаются” | `advertising` section | `conversion`, cache/template, eShop public includes |
| “A/B тест не переключает шаблон/страницу” | `abtest` section | `conversion`, `templates.md`, `sef-urls.md` |
| “Конверсия пустая” | `conversion` section | `advertising`, `sender`, `abtest`, `sale/statistic` |
| “Отчёт не строится / пустой” | `report` section | helper class, rights, `sale_report_helper` |
| “Статистика тормозит сайт” | `statistic` section | agents cleanup, options, skip groups/IP |

## Component inventory

### `sender` components — 65

Families:

- campaigns/letters: `sender.campaign*`, `sender.letter*`, `sender.template*`;
- contacts/segments: `sender.contact*`, `sender.segment*`, `sender.connector.result.list`;
- triggers/return customer: `sender.trigger*`, `sender.rc*`;
- subscription/public: `sender.subscribe`, `sender.consent`;
- message editors/senders: `sender.mail.*`, `sender.sms.*`, `sender.im.message`, `sender.message.*`, `sender.call.*`;
- ads/toloka/yandex: `sender.ads*`, `sender.master.yandex`, `sender.yandex.toloka*`;
- config/UI/stat: `sender.config.*`, `sender.stats`, `sender.ui.*`, `sender.abuse.*`, `sender.blacklist.*`.

Exhaustive list confirmed:

`sender.abuse.list`, `sender.ads`, `sender.ads.list`, `sender.blacklist`, `sender.blacklist.list`, `sender.call.number`, `sender.call.text.editor`, `sender.campaign`, `sender.campaign.edit`, `sender.campaign.list`, `sender.campaign.selector`, `sender.campaign.stat`, `sender.config.limits`, `sender.config.role`, `sender.config.role.edit`, `sender.config.role.list`, `sender.connector.result.list`, `sender.consent`, `sender.contact`, `sender.contact.edit`, `sender.contact.import`, `sender.contact.list`, `sender.contact.recipient`, `sender.contact.set.list`, `sender.contact.set.selector`, `sender.im.message`, `sender.letter`, `sender.letter.edit`, `sender.letter.list`, `sender.letter.stat`, `sender.letter.time`, `sender.mail.editor`, `sender.mail.link.editor`, `sender.mail.sender`, `sender.master.yandex`, `sender.message.audio`, `sender.message.editor`, `sender.message.tester`, `sender.rc`, `sender.rc.list`, `sender.segment`, `sender.segment.edit`, `sender.segment.list`, `sender.segment.selector`, `sender.sms.sender`, `sender.sms.text.editor`, `sender.start`, `sender.stats`, `sender.subscribe`, `sender.template`, `sender.template.edit`, `sender.template.list`, `sender.template.selector`, `sender.trigger`, `sender.trigger.chain`, `sender.trigger.edit`, `sender.trigger.list`, `sender.trigger.stat`, `sender.ui.button.panel`, `sender.ui.panel.title`, `sender.ui.tile.selector`, `sender.ui.user.selector`, `sender.yandex.toloka`, `sender.yandex.toloka.edit`, `sender.yandex.toloka.list`.

### `mail` components — 18

`mail.addressbook`, `mail.blacklist.list`, `mail.client`, `mail.client.config`, `mail.client.config.dirs`, `mail.client.config.permissions`, `mail.client.home`, `mail.client.massconnect`, `mail.client.message.list`, `mail.client.message.new`, `mail.client.message.view`, `mail.client.sidepanel`, `mail.contact.avatar`, `mail.mailbox.list`, `mail.message.actions`, `mail.uf.message`, `mail.usersignature.edit`, `mail.usersignature.list`.

### `messageservice` components — 2

`messageservice.config.sender.limits`, `messageservice.config.sender.sms`.

### `subscribe` components — 5

`subscribe.edit`, `subscribe.form`, `subscribe.index`, `subscribe.news`, `subscribe.simple`.

### `advertising` components — 2

`advertising.banner`, `advertising.banner.view`.

### `report` components — 19

`report.analytics.base`, `report.analytics.config.control`, `report.analytics.empty`, `report.analytics.feedback`, `report.construct`, `report.filter.field.selector`, `report.list`, `report.view`, `report.visualconstructor.board.base`, `report.visualconstructor.board.controls`, `report.visualconstructor.board.filter`, `report.visualconstructor.board.header`, `report.visualconstructor.config.fields`, `report.visualconstructor.widget.content.grid`, `report.visualconstructor.widget.content.groupeddatagrid`, `report.visualconstructor.widget.content.number`, `report.visualconstructor.widget.content.numberblock`, `report.visualconstructor.widget.form`, `report.visualconstructor.widget.pseudoconfig`.

### No public components

`abtest` and `conversion` have no `install/components/bitrix/*` in this core; they work through admin pages, tables, event handlers and shared counters.

`statistic` has one public component: `statistic.table`.

## DB/table layer

### `sender`

Confirmed table families:

- contacts/lists/segments: `b_sender_contact`, `b_sender_contact_list`, `b_sender_list`, `b_sender_group`, `b_sender_group_connector`, `b_sender_group_data`, `b_sender_group_state`, `b_sender_group_queue`, `b_sender_group_thread`, `b_sender_group_counter`;
- campaigns/letters/messages: `b_sender_mailing`, `b_sender_mailing_chain`, `b_sender_mailing_chain_group`, `b_sender_mailing_group`, `b_sender_mailing_subscription`, `b_sender_mailing_trigger`, `b_sender_message`, `b_sender_message_field`, `b_sender_message_utm`;
- posting/runtime: `b_sender_posting`, `b_sender_posting_recipient`, `b_sender_posting_click`, `b_sender_posting_read`, `b_sender_posting_unsub`, `b_sender_posting_thread`, `b_sender_queue`, `b_sender_timeline_queue`;
- counters/abuse/consent/roles: `b_sender_counter`, `b_sender_counter_daily`, `b_sender_abuse`, `b_sender_agreement`, `b_sender_role*`, `b_sender_permission`;
- files/call log: `b_sender_file`, `b_sender_file_info`, `b_sender_call_log`.

Key DataManager classes confirmed: `ContactTable`, `ListTable`, `GroupTable`, `MailingTable`, `MailingChainTable`, `PostingTable`, `RecipientTable`, `ClickTable`, `ReadTable`, `UnsubTable`, `MessageTable`, `MessageUtmTable`, `TemplateTable`, `CounterTable`, `DailyCounterTable`, access role/permission tables.

### `mail`

Confirmed table families:

- mailboxes/messages: `b_mail_mailbox`, `b_mail_message`, `b_mail_message_uid`, `b_mail_msg_attachment`, `b_mail_mailbox_dir`, `b_mail_mailbox_list_search_index`;
- access/roles: `b_mail_access_role`, `b_mail_access_permission`, `b_mail_access_role_relation`, `b_mail_mailbox_access`, `b_mail_message_access`;
- sync/queues/logs: `b_mail_log`, `b_mail_message_delete_queue`, `b_mail_message_upload_queue`, `b_mail_counter`;
- contacts/settings: `b_mail_contact`, `b_mail_blacklist`, `b_mail_mailservices`, `b_mail_oauth`, `b_mail_user_signature`, `b_mail_user_message`, `b_mail_user_relations`, `b_mail_domain_email`, `b_mail_mass_connect`.

### `messageservice`

Tables: `b_messageservice_channel`, `b_messageservice_message`, `b_messageservice_incoming_message`, `b_messageservice_restriction`, `b_messageservice_template`, `b_messageservice_rest_app`, `b_messageservice_rest_app_lang`.

Options: `clean_up_period` default `14`, `queue_limit` default `5`. Install also sets `disable_international=Y` outside RU/BY regions.

### `subscribe`

Tables: `b_subscription`, `b_subscription_rubric`, `b_list_rubric`, `b_posting`, `b_posting_email`, `b_posting_file`, `b_posting_group`, `b_posting_rubric`.

DataManagers confirmed: `Bitrix\Subscribe\RubricTable`, `SubscriptionTable`. Legacy write path remains `CSubscription`, `CRubric`, `CPosting`, `CPostingTemplate`.

### `advertising`

Core tables include `b_adv_banner`, `b_adv_contract`, `b_adv_type`, plus relation/dynamics tables for sites/pages/country/day/weekday/stat advertising. Core fields on `b_adv_banner` include active/status, type, contract, weight, show/click/visitor limits and counters, date windows, image/code/url, stat event fields, user group and page restrictions.

### `abtest`

Table: `b_abtest`.

It stores test definition/state; switching is event-driven through main site template and file rewrite/page-start hooks.

### `conversion`

Tables: `b_conv_context`, `b_conv_context_attribute`, `b_conv_context_counter_day`, `b_conv_context_entity_item`.

This module stores day counters by context snapshot and attributes. Other modules register counter/rate/attribute handlers into it.

### `report`

Tables: `b_report`, `b_report_sharing`, `b_report_visual_report_dashboard`, `b_report_visual_report_dashboard_row`, `b_report_visual_report_widget`, `b_report_visual_report_widget_config`, `b_report_visual_report_entity`, `b_report_visual_report_entity_config`, `b_report_visual_report_configuration`.

`Bitrix\Report\ReportTable` maps `ID`, `OWNER_ID`, `TITLE`, `DESCRIPTION`, `CREATED_DATE`, `CREATED_BY`, `SETTINGS`, `MARK_DEFAULT`.

### `statistic`

Legacy `b_stat_*` layer: sessions, hits, guests, paths, events, adv, searchers, referers, phrases, city/country, stoplist and dynamic/day tables. This module is runtime-heavy and has many cleanup/optimization options.

## Event handlers and agents

### `sender` events/agents

Install registers:

- main mail tracking: `main.OnMailEventMailRead` → `postingmanager::onMailEventMailRead`, `main.OnMailEventMailClick` → `postingmanager::onMailEventMailClick`;
- subscription mail events: `OnMailEventSubscriptionDisable`, `OnMailEventSubscriptionEnable`, `OnMailEventSubscriptionList` → `Bitrix\Sender\Subscription`;
- sender extension points: `sender.OnConnectorList`, `sender.OnPresetTemplateList`, `sender.OnPresetMailBlockList`, `sender.OnTriggerList`;
- recipient/conversion: `sender.OnAfterRecipientUnsub`, `sender.OnAfterRecipientClick`, `conversion.OnSetDayContextAttributes`, `conversion.OnGetAttributeTypes`, `main.OnBeforeProlog` via `Bitrix\Sender\Internals\ConversionHandler`;
- optional integrations: `voximplant.OnInfoCallResult`, `pull.OnGetDependentModule`, `im.OnGetNotifySchema`, `main.OnAfterFileSave`.

Agents/stepper:

- `Bitrix\Sender\Access\Install\AccessInstaller::installAgent();`
- `Bitrix\Sender\Runtime\Job::actualizeAll();`
- `Bitrix\Sender\Trigger\Manager::activateAllHandlers();`
- `Bitrix\Sender\Install\SetFileInfoStepper`.

Key options:

- `auto_method`: `agent` / `cron`;
- `max_emails_per_hit`, `max_emails_per_cron` default `500`;
- `auto_agent_interval` default `0`;
- `track_mails` default depends on Bitrix24 region;
- `mail_consent`, `~mail_max_consent_requests`.

### `mail` events/agents

Install registers:

- `main.OnMailEventMailRead` → `Bitrix\Mail\Helper\MessageEventManager::onMailEventMailRead`;
- `mail.onMailMessageNew` → calendar ICal manager;
- `calendar.OnAfterCalendarEventDelete` → unbind event;
- `pull.OnGetDependentModule` → `MailPullSchema`;
- `tasks.OnTaskDelete` → secretary cleanup.

Agents:

- `CMailbox::CleanUp();` daily;
- `Bitrix\Mail\Access\Install\AccessInstaller::install();` after install.

Options include `save_src`, `save_attachments`, `sync_old_limit2`, `php_path` and SMTPD manager actions.

### `messageservice` events/agents

Install registers:

- `main.OnAfterEpilog` → `Bitrix\MessageService\Queue::run`;
- REST service descriptors/app lifecycle: `rest.OnRestServiceBuildDescription`, `OnRestAppDelete`, `OnRestAppUpdate`;
- `imconnector` delivery/read statuses for Wazzup.

Agents:

- `Bitrix\MessageService\Queue::cleanUpAgent();`
- `Bitrix\MessageService\IncomingMessage::cleanUpAgent();`

### `subscribe` events/agents

Install registers:

- `main.OnBeforeLangDelete` → `CRubric::OnBeforeLangDelete`;
- `main.OnUserDelete`, `main.OnUserLogout` → `CSubscription`;
- `main.OnGroupDelete` → `CPosting`;
- `sender.OnConnectorList` → `Bitrix\Subscribe\SenderEventHandler::onConnectorListSubscriber`;
- `perfmon.OnGetTableSchema`.

Options:

- `subscribe_section` default `#SITE_DIR#about/`;
- `subscribe_confirm_period` default `60`;
- `subscribe_auto_method`: `agent` / `cron`;
- `subscribe_max_emails_per_hit` default `5`;
- `subscribe_template_method`: `agent` / `cron`;
- `subscribe_template_interval` default `60`;
- `mail_additional_parameters`.

`options.php` manages `CPostingTemplate::Execute();` agent depending on template method.

### `advertising` events/agents

Install registers:

- `main.OnBeforeProlog` → module-level advertising init;
- `main.OnEndBufferContent` → `CAdvBanner::FixShowAll`;
- `main.OnBeforeRestartBuffer` → `CAdvBanner::BeforeRestartBuffer`;
- `conversion.OnGetCounterTypes`, `conversion.OnGetRateTypes` → `Bitrix\Advertising\Internals\ConversionHandlers`;
- `advertising.onBannerClick` → conversion handler.

Agents:

- `CAdvContract::SendInfo();` every 7200 seconds;
- `CAdvBanner::CleanUpDynamics();` daily.

Options: `BANNER_DAYS` default `360`, `COOKIE_DAYS` default `7`, upload subdir and cleanup callbacks.

### `abtest` events

Install registers:

- `main.OnGetCurrentSiteTemplate` → `Bitrix\ABTest\EventHandler::onGetCurrentSiteTemplate`;
- `main.OnFileRewrite` → `onFileRewrite`;
- `main.OnPageStart` → `onPageStart`;
- `main.OnPanelCreate` → `onPanelCreate`;
- `conversion.OnGetAttributeTypes` → `onGetAttributeTypes`;
- `conversion.OnSetDayContextAttributes` → `onConversionSetContextAttributes`.

No public components confirmed.

### `conversion` events

Install registers:

- self events: `OnGetCounterTypes`, `OnGetAttributeTypes`, `OnGetAttributeGroupTypes`, `OnSetDayContextAttributes`;
- `main.OnProlog` → `Bitrix\Conversion\Internals\Handlers::onProlog`.

Other modules (`sender`, `advertising`, `abtest`) plug into these events.

### `report` events

Install registers:

- `report.OnReportDelete` → `Bitrix\Report\Sharing::OnReportDelete`.

### `statistic` events/agents

Install registers:

- `main.OnPageStart` → `CStopList::Check`;
- `main.OnBeforeProlog` → `CStatistics::Keep` and `CStatistics::StartBuffer`;
- `main.OnLocalRedirect` → `CStatistics::Keep`;
- `main.OnEpilog` → `CStatistics::Set404`;
- `main.OnEndBufferContent` → `CStatistics::EndBuffer`;
- `main.OnEventLogGetAuditTypes` → audit types;
- `statistic.OnCityLookup` chain;
- `cluster.OnGetTableList`.

Agents:

- `CStatistics::SetNewDay();`
- `CStatistics::CleanUpStatistics_1();`
- `CStatistics::CleanUpStatistics_2();`
- `CStatistics::CleanUpSessionData();`
- `CStatistics::CleanUpPathCache();`
- optional `SendDailyStatistics();`.

Storage options include retention days for hits/sessions/guests/events/adv/searchers/referers/phrases/cities/countries, skip groups/IP ranges, defence thresholds and auto optimize.

## Standard component contracts

### `sender.subscribe`

Confirmed params:

- `AJAX_MODE`
- `USER_CONSENT`
- `USE_PERSONALIZATION` default `Y`
- `USE_CONFIRMATION` default `Y`
- `SET_TITLE` default `Y`
- `HIDE_MAILINGS` default `N`
- `SHOW_HIDDEN` default `N`
- `CACHE_TIME` default `3600`

Confirmed request/state:

- form action appends/removes `sender_subscription` query param;
- POST fields include `SENDER_SUBSCRIBE_EMAIL`, `SENDER_SUBSCRIBE_RUB_ID`;
- session key `SENDER_SUBSCRIBE_LIST` caches current subscription list;
- cookie `SENDER_SUBSCR_EMAIL` stores email;
- calls `Bitrix\Sender\Subscription::sendEventConfirm()` when confirmation is enabled and `Subscription::add()` when adding immediately;
- result message codes include security/email/success/confirm states.

Gotchas:

- `sender.subscribe` is not `subscribe.form`; it writes to sender contacts/mailings.
- `USER_CONSENT` can block form submission before sender code.
- If `HIDE_MAILINGS=Y`, user may not see selectable mailings but backend still needs active mailing list.
- Cache key is site/component-path dependent; stale rubrics/mailings can be cache, not DB.

### `sender.letter.list`, `sender.contact.list`, `sender.segment.list`, `sender.trigger.list`

These admin/list components are class-based and use `CommonSenderComponent`, `main.ui.grid`, `main.ui.filter`, `GridOptions`, `FilterOptions`, `PageNavigation`, AJAX endpoints and action rights from `Bitrix\Sender\Access\ActionDictionary`.

Confirmed list/action patterns:

- `sender.letter.list/ajax.php` can `send`, `pause`, `resume`, `stop`, `remove` letters through `Bitrix\Sender\Entity\Letter`;
- `sender.contact.list` exposes columns such as email/phone code, type, name, subscribed/unsubscribed, contact set, statistics, consent status;
- filters support subscribed/unsubscribed presets and contact set filtering;
- `sender.stats` uses `Bitrix\Sender\Statistics` for chain list, counters, dynamic counters and efficiency.

Gotchas:

- Do not patch only grid templates for delivery bugs; delivery state lives in posting/recipient queues and letter entity state.
- Pagination state can reset through component AJAX, e.g. letter removal resets `PageNavigation("page-sender-letters")` session var.

### `sender.config.limits`

Confirmed reads:

- `Option::get('sender', 'track_mails')`
- `Option::get('sender', 'mail_consent')`
- `Option::get('sender', 'sending_time')`
- `Option::get('sender', 'sending_start', '09:00')`
- `Option::get('sender', 'sending_end', '18:00')`

Use this component/config layer for send window and tracking/consent UI checks.

### `subscribe.form`

Confirmed params:

- `USE_PERSONALIZATION` default `Y`
- `PAGE` default `COption::GetOptionString('subscribe', 'subscribe_section') . 'subscr_edit.php'`
- `SHOW_HIDDEN` default `N`
- `CACHE_TIME` default `3600`

Confirmed behavior:

- checks `IsModuleInstalled('subscribe')` and includes `subscribe`;
- reads user's existing categories;
- builds `FORM_ACTION` from `PAGE`;
- request email field is `sf_EMAIL`;
- result has `EMAIL` and `RUBRICS`.

### `subscribe.edit`

Confirmed params:

- `AJAX_MODE`
- `SHOW_HIDDEN`
- `ALLOW_ANONYMOUS` from subscribe option;
- `SHOW_AUTH_LINKS` from subscribe option;
- `CACHE_TIME` default `3600`.

Confirmed behavior:

- works with `PostAction` `Add`/`Update`, `ID`, `EMAIL`, `FORMAT`, rubrics and `CONFIRM_CODE`;
- supports `action=unsubscribe` path;
- checks `CSubscription::IsAuthorized($ID)` for editing existing subscription.

### `advertising.banner`

Confirmed params:

- `TYPE` from advertising type list;
- `NOINDEX`;
- `QUANTITY` default `1`;
- `CACHE_TIME` default `0`;
- `DEFAULT_TEMPLATE` from component templates.

`advertising.banner.view` renders concrete banner payload with templates such as `bootstrap`, `bootstrap_v4`, `jssor`, `nivo`, `parallax`; templates check `PROPS.LINK_URL`, `CASUAL_PROPERTIES.URL`, preview mode and media fields.

### `statistic.table`

Confirmed params:

- `CACHE_TIME` default `20`;
- `CACHE_FOR_ADMIN` default `N`.

Confirmed behavior:

- disables cache for admin unless `CACHE_FOR_ADMIN=Y`;
- calls `CTraffic::GetCommonValues([], true)`;
- exposes `STATISTIC`, `TODAY`, `NOW`, `IS_ADMIN`.

### `report.list` / `report.view` / `report.construct`

Confirmed report list behavior:

- requires module `report`;
- expects `REPORT_HELPER_CLASS` (or POST `HELPER_CLASS`);
- calls helper `getOwnerId`;
- exports/imports report rows through `Bitrix\Report\ReportTable`;
- checks rights via `Bitrix\Report\RightsManager`;
- supports sharing through AJAX and `Bitrix\Report\Sharing`.

`report.construct` is a builder UI around selected columns, calculated columns, filters, sort, grouping, result limits, mobile settings and chart config. It is helper-class dependent; never assume a shop report helper exists until checking the caller.

## Shop/eShop integration points

### eShop wizard/public/templates

Confirmed in `bitrix.eshop`:

- public include `include/sender.php` uses `bitrix:sender.subscribe`;
- `sect_sidebar.php`, personal sidebar and template footers include `sender.php`;
- home/bottom public pages use `bitrix:advertising.banner` if `advertising` is installed;
- wizard services create advertising data through `site/services/advertising/index.php`;
- wizard temporarily reads/toggles statistic option `DEFENCE_ON`;
- wizard configures sale product subscription option `sale.subscribe_prod` and subscribe section `#SITE_DIR#personal/subscribe/`;
- subscribe templates are copied from `subscribe/install/php_interface/subscribe/templates/news` when `subscribe` is installed.

### Sale connectors into sender/statistic

Confirmed sale → sender:

- `Bitrix\Sale\SenderConnectorBuyer` extends `Bitrix\Sender\Connector`;
- connector code is `buyer`;
- filters buyers by site `LID`, order count range, paid sum range and last order date range;
- source data uses `BuyerStatistic::getList()` and returns user email/name/user id;
- `Bitrix\Sale\Bigdata\TargetSaleMailConnector` extends sender connector, code `target_sale`, selects products and potential consumers via sale bigdata cloud.

Confirmed sale → statistic:

- paid orders call `CStatEvent::AddByEvents("eStore", "order_paid", ...)`;
- chargeback/cancel flows call statistic events when `statistic` is installed;
- sale product search references `$_SESSION['SESS_SEARCHER_ID']` when statistic exists.

### Catalog/product subscription is separate

Catalog has `b_catalog_subscribe` / `b_catalog_subscribe_access` and product subscribe notifications (`CATALOG_PRODUCT_SUBSCRIBE_NOTIFY*`). Do not merge this with `sender.subscribe` or `subscribe.form`: it is product availability notification, not marketing mailing membership.

## Diagnostics by symptom

### Sender mailing does not send

Check in order:

1. Module exists and options: `auto_method`, `max_emails_per_hit`, `max_emails_per_cron`, `auto_agent_interval`.
2. If `auto_method=agent`, sender agents/runtime jobs exist and agents are executed.
3. If `auto_method=cron`, cron route is configured; do not expect per-hit sending.
4. Letter state in `b_sender_mailing_chain` / `Bitrix\Sender\Entity\Letter`.
5. Posting and recipients in `b_sender_posting`, `b_sender_posting_recipient`.
6. Consent/tracking options: `mail_consent`, `track_mails`, send window.
7. Main mail subsystem and mail event logs.
8. User/contact email validity and blacklist/abuse tables.

### Opens/clicks not tracked

Check:

- `sender.track_mails` option;
- main event handlers `OnMailEventMailRead`, `OnMailEventMailClick`;
- `b_sender_posting_read`, `b_sender_posting_click`;
- mail link editor/UTM settings (`b_sender_message_utm`);
- email clients/proxies can suppress or prefetch opens/clicks;
- consent option can disable tracking in some regions.

### Subscribe form submits but user not subscribed

First identify component:

- `bitrix:sender.subscribe` → sender contacts/mailings;
- `bitrix:subscribe.form` / `subscribe.edit` → legacy subscribe module;
- catalog product subscription → catalog/sale product availability.

For `sender.subscribe`:

1. `check_bitrix_sessid()` and `USER_CONSENT`;
2. valid `SENDER_SUBSCRIBE_EMAIL`;
3. selected/hidden mailing IDs in `SENDER_SUBSCRIBE_RUB_ID`;
4. `USE_CONFIRMATION`: user may be pending confirmation, not absent;
5. session `SENDER_SUBSCRIBE_LIST` and cache;
6. cookie `SENDER_SUBSCR_EMAIL` can prefill stale email.

For `subscribe.edit`:

1. `ALLOW_ANONYMOUS`, `SHOW_AUTH_LINKS`;
2. `CONFIRM_CODE` and `CSubscription::IsAuthorized()`;
3. `action=unsubscribe` or `PostAction=Add/Update`;
4. rubrics in `b_list_rubric` and `b_subscription_rubric`.

### SMS/message not sent

Check:

1. `messageservice` installed;
2. provider configured in `messageservice.config.sender.sms`;
3. queue runs on `main.OnAfterEpilog` (`Bitrix\MessageService\Queue::run`);
4. `queue_limit` option;
5. restrictions: per IP/user/phone limits in `b_messageservice_restriction`;
6. region option `disable_international`;
7. REST app/provider lifecycle if using REST provider;
8. cleanup agents should not remove fresh messages, but verify `clean_up_period`.

### Banner not shown

Check:

1. `advertising` module and `advertising.banner` component are present.
2. Component `TYPE` matches `b_adv_type.SID`.
3. Banner active/status, contract active, site/page/day/country/user group restrictions.
4. Date window and show/click/visitor limits.
5. Weight and `QUANTITY`.
6. Template selection and banner view template.
7. Cache: component default cache is `0`, but page/composite/template can still cache output.
8. Runtime hooks `OnBeforeProlog`, `OnEndBufferContent`, `OnBeforeRestartBuffer` are registered.

### Banner clicks/conversions not counted

Check:

- `FIX_CLICK`, `FIX_SHOW` flags on banner;
- advertising relation to statistic advertising if used;
- `advertising.onBannerClick` event;
- conversion handlers registered for counter/rate types;
- click URL/template does not bypass Bitrix banner click route.

### A/B test does not switch

Check:

1. `abtest` module and `b_abtest` test row.
2. Test enabled/state/site/template/page condition.
3. Event handlers: `OnGetCurrentSiteTemplate`, `OnFileRewrite`, `OnPageStart`.
4. Admin panel handler `OnPanelCreate` if UI state differs from runtime.
5. Conversion handlers for test attribution.
6. Template/page cache and SEF rewrite can hide switching.

### Conversion report empty

Check:

- `conversion` module exists and `main.OnProlog` handler runs;
- context attributes exist in `b_conv_context*`;
- module-specific handlers registered: advertising, sender, abtest;
- correct base currency if money rates matter;
- date range/day context;
- user/session/cookie context can be different in CLI/admin/public.

### Report list/view empty

Check:

1. `REPORT_HELPER_CLASS` passed and class exists.
2. Helper returns correct `OWNER_ID`.
3. `Bitrix\Report\ReportTable` rows in `b_report`.
4. Rights via `RightsManager`.
5. Sharing rows in `b_report_sharing`.
6. Visual constructor tables for dashboards/widgets.
7. Default reports may be created by helper/user option logic; do not assume static fixtures.

### Statistic slows site or writes too much

Check:

- `statistic` event handlers at `OnPageStart`, `OnBeforeProlog`, `OnEndBufferContent`;
- skip groups/IP ranges and `SKIP_STATISTIC_WHAT`;
- defence settings (`DEFENCE_ON`, `DEFENCE_MAX_STACK_HITS`, delays/log);
- retention days and cleanup agents;
- MySQL optimize/index options;
- stoplist and city lookup handlers;
- whether the project really needs legacy statistic instead of lighter analytics.

## Safe implementation rules

- Do not send real mail/SMS/calls in smoke tests without explicit user approval and sandbox recipients.
- Do not directly update `b_sender_*`, `b_subscription*`, `b_messageservice_*`, `b_adv_*`, `b_conv_*`, `b_report*`, `b_stat_*` unless there is no API and the user approved data mutation.
- For new shop segments, prefer sender connectors/services and sale APIs over SQL.
- For forms, keep `sessid`, consent and confirmation flow intact.
- For unsubscribe, never remove only UI state; update the real subscription/unsub tables through module API.
- For reports, do not invent helper classes: inspect existing helper/caller first.
- For statistic, be conservative: it has early runtime hooks and cleanup agents; changes can affect every public hit.

## What not to do

- Do not confuse `sender.subscribe`, `subscribe.form/edit` and catalog product subscription.
- Do not claim `conversion` is a full analytics system; it is a counter/context layer fed by modules.
- Do not claim `statistic` is harmless: it hooks into public request lifecycle and stores many hit/session tables.
- Do not debug sender delivery from template only; check letter/posting/recipient queue, agents/cron, consent and mail logs.
- Do not debug SMS only from sender UI; `messageservice` queue/providers/restrictions are a separate layer.
- Do not activate marketing/analytics route in another project until each target module exists locally.


---

## Source: `shop-automation-bizproc.md`

# Shop automation/bizproc — bizproc, bizprocdesigner, workflow, lists, pull

> Reference для Bitrix-скилла. Загружай, когда задача связана с автоматизацией интернет-магазина/контента: бизнес-процессы, роботы, шаблоны workflow, задания БП, запуск/остановка workflows, процессы в списках, legacy `workflow`, realtime/pull, designer/editor, REST automation или когда пользователь спрашивает, покрыты ли automation modules shop-core.

## Audit note

Проверено по shop-core:

- `www/bitrix/modules/bizproc` — `26.200.0`, `VERSION_DATE` `2026-01-16 16:33:00`
- `www/bitrix/modules/bizprocdesigner` — `26.0.0`, `VERSION_DATE` `2025-12-05 12:00:00`
- `www/bitrix/modules/workflow` — `26.0.0`, `VERSION_DATE` `2026-03-18 14:30:00`
- `www/bitrix/modules/lists` — `25.600.100`, `VERSION_DATE` `2026-02-27 11:09:11`
- `www/bitrix/modules/pull` — `25.300.0`, `VERSION_DATE` `2025-06-25 09:30:00`
- adjacent facts checked in `iblock`, `catalog`, `sale` only for routing/side effects.

Ниже — подтверждённый routing/contract layer. Для корзины/заказов читай `sale.md`; для товарных данных — `catalog.md`; для стандартных shop components — `shop-standard-components.md`; для REST — `rest.md`; для realtime общих деталей — `push-pull.md`.

## Главный вывод

Automation в текущем shop-core — это несколько разных подсистем:

1. `bizproc` — современный workflow engine: templates, states/instances, tasks, tracking, history, automation robots/triggers, scripts, debugger, globals, REST activities/providers.
2. `bizprocdesigner` — UI/editor layer для редактирования workflow templates и роботов; сам runtime не заменяет.
3. `workflow` — legacy документооборот файлов/страниц со статусами, lock/history/preview, admin UI и cleanup agent.
4. `lists` — процессы и списки поверх `iblock` + `bizproc`: list elements, process catalog, livefeed/user processes, rights, REST list CRUD.
5. `pull` — realtime/push transport: channels, stack, watches, push queue, REST and JS client; используется как зависимость UI/notifications, а не как workflow engine.

Критично:

- `workflow` и `bizproc` — разные механизмы; `iblock` запрещает одновременно `WORKFLOW=Y` и `BIZPROC=Y`.
- `bizprocdesigner` нужен для редактора, но не исполняет процессы сам.
- `lists` запускает БП через `BizprocDocument*` над iblock/list element, а не через `sale` order API.
- В проверенном `sale` модуле нет отдельного sale-order business-process document provider уровня `CBPDocument` для заказов; не обещай “роботов заказа” без проверки CRM/проектного модуля.
- `pull` не чинит бизнес-логику БП; он чинит доставку realtime-событий, counters, watches и push.

## Fast routing

| Запрос | Сначала читать | Затем |
|---|---|---|
| “Бизнес-процесс не стартует” | `bizproc` sections below | `iblocks.md`, `lists` section, permissions |
| “Робот/automation не срабатывает” | `bizproc.automation` below | template status, triggers, `b_bp_automation_trigger`, logs |
| “Задание БП висит / нельзя выполнить” | `bizproc.task*` below | `b_bp_task`, `b_bp_task_user`, permissions/delegation |
| “Шаблон не сохраняется в дизайнере” | `bizprocdesigner` below | `bizproc.workflow.edit`, sessid, rights, template table |
| “Процессы в списках не работают” | `lists` below | `iblock` BIZPROC flag, `CLists::isBpFeatureEnabled`, list rights |
| “Legacy workflow страницы/файлы” | `workflow` below | `fileman`, status/group rights, cleanup/history options |
| “Realtime не пришёл / счетчик не обновился” | `pull` below | `push-pull.md`, pull server config, watches/channels |
| “Нужна автоматизация заказа” | сначала `sale.md`, затем этот файл | не обещать sale robots без локального provider-а |

## Component inventory

### `bizproc` components — 49

Families:

- automation/debugger: `bizproc.automation`, `bizproc.automation.robot.button`, `bizproc.automation.scheme`, `bizproc.debugger*`;
- documents/history/log: `bizproc.document`, `bizproc.document.history`, `bizproc.log`, `bizproc.workflow.timeline.slider`;
- workflow start/list/instances/faces/info: `bizproc.workflow.*`;
- tasks: `bizproc.task`, `bizproc.task.list`;
- scripts: `bizproc.script.*`;
- storage/global fields: `bizproc.storage.*`, `bizproc.globalfield.*`;
- process wizard/user processes: `bizproc.template.processes`, `bizproc.user.processes*`, `bizproc.wizards*`;
- UI helpers: `bizproc.interface.filter`, `bizproc.interface.grid`.

Exhaustive list confirmed:

`bizproc.ai.agents`, `bizproc.automation`, `bizproc.automation.robot.button`, `bizproc.automation.scheme`, `bizproc.debugger`, `bizproc.debugger.log`, `bizproc.debugger.session.list`, `bizproc.debugger.start`, `bizproc.document`, `bizproc.document.history`, `bizproc.globalfield.edit`, `bizproc.globalfield.list`, `bizproc.interface.filter`, `bizproc.interface.grid`, `bizproc.log`, `bizproc.script.edit`, `bizproc.script.list`, `bizproc.script.placement`, `bizproc.script.queue.document.list`, `bizproc.script.queue.list`, `bizproc.storage.edit`, `bizproc.storage.field.edit`, `bizproc.storage.field.list`, `bizproc.storage.item.list`, `bizproc.task`, `bizproc.task.list`, `bizproc.template.processes`, `bizproc.user.processes`, `bizproc.user.processes.start`, `bizproc.wizards`, `bizproc.wizards.index`, `bizproc.wizards.list`, `bizproc.wizards.log`, `bizproc.wizards.new`, `bizproc.wizards.setvar`, `bizproc.wizards.start`, `bizproc.wizards.task`, `bizproc.wizards.view`, `bizproc.workflow.faces`, `bizproc.workflow.info`, `bizproc.workflow.instances`, `bizproc.workflow.list`, `bizproc.workflow.livefeed`, `bizproc.workflow.setconstants`, `bizproc.workflow.setparameters`, `bizproc.workflow.setvar`, `bizproc.workflow.start`, `bizproc.workflow.start.list`, `bizproc.workflow.timeline.slider`.

### `bizprocdesigner` components — 2

- `bizproc.workflow.edit` — legacy/compatible workflow template editor wrapper.
- `bizprocdesigner.editor` — modern designer/editor component.

### `lists` components — 19

`lists`, `lists.catalog.processes`, `lists.element.attached.crm`, `lists.element.creation_guide`, `lists.element.edit`, `lists.element.navchain`, `lists.element.preview`, `lists.export.excel`, `lists.field.edit`, `lists.fields`, `lists.file`, `lists.list`, `lists.list.edit`, `lists.lists`, `lists.live.feed`, `lists.lock.status.widget`, `lists.menu`, `lists.sections`, `lists.user.processes`.

### `workflow` components — 0

Legacy module exposes admin pages and `CWorkflow*` API, not public components.

### `pull` components — 1

`pull.request` — AJAX/long-poll request component/init endpoint.

## DB/table layer

### `bizproc`

Core workflow tables:

- templates: `b_bp_workflow_template`, `b_bp_workflow_template_settings`, `b_bp_workflow_template_user_option`, `b_bp_document_type_user_option`, `b_bp_workflow_template_draft`, `b_bp_workflow_template_trigger`, `b_bp_workflow_template_section`, `b_bp_workflow_template_file`;
- runtime state/instances: `b_bp_workflow_state`, `b_bp_workflow_instance`, `b_bp_workflow_state_identify`, `b_bp_workflow_meta`, `b_bp_workflow_filter`, `b_bp_workflow_duration_stat`, `b_bp_workflow_user`, `b_bp_workflow_user_comment`, `b_bp_workflow_result`;
- tasks/search/archive: `b_bp_task`, `b_bp_task_user`, `b_bp_task_search_content`, `b_bp_task_archive`, `b_bp_task_archive_tasks`;
- tracking/history: `b_bp_tracking`, `b_bp_history`;
- REST and scheduler: `b_bp_rest_activity`, `b_bp_rest_provider`, `b_bp_scheduler_event`;
- automation/scripts/storage/debugger/globals: `b_bp_automation_trigger`, `b_bp_script`, `b_bp_script_queue`, `b_bp_script_queue_document`, `b_bp_storage_activity`, `b_bp_storage_type`, `b_bp_storage_field`, `b_bp_storage_record_data`, `b_bp_global_const`, `b_bp_global_var`, `b_bp_debugger_session*`, `b_bp_robot_version_index`, `b_bp_messenger_workflow_start_message`.

Confirmed DataManagers include:

- `WorkflowTemplateTable`, `WorkflowTemplateDraftTable`, `WorkflowTemplateTriggerTable`, `WorkflowTemplateSettingsTable`, `WorkflowTemplateUserOptionTable`, `WorkflowTemplateSectionTable`, `WorkflowTemplateFileTable`;
- `WorkflowStateTable`, `WorkflowInstanceTable`, `WorkflowMetadataTable`, `WorkflowFilterTable`, `WorkflowDurationStatTable`, `WorkflowUserTable`, `WorkflowUserCommentTable`, `ResultTable`;
- `TaskTable`, `TaskUserTable`, `TaskSearchContentTable`, `TaskArchiveTable`, `TaskArchiveTasksTable`;
- `TrackingTable`, `SchedulerEventTable`, `RestActivityTable`, `RestProviderTable`, `TriggerTable`;
- `ScriptTable`, `ScriptQueueTable`, `ScriptQueueDocumentTable`;
- `GlobalConstTable`, `GlobalVarTable`, `ActivityStorageTable`, `StorageTypeTable`, `StorageFieldTable`, `StorageRecordTable`;
- debugger session tables and `RobotVersionIndexTable`.

### `workflow`

Tables:

- `b_workflow_document` — document path/status/lock/body metadata;
- `b_workflow_file` — attached/temp files;
- `b_workflow_log` — document logs;
- `b_workflow_move` — move records;
- `b_workflow_preview` — preview files;
- `b_workflow_status` — statuses;
- `b_workflow_status2group` — status permissions by group.

Legacy APIs confirmed: `CWorkflow`, `CWorkflowStatus`.

### `lists`

Tables:

- `b_lists_permission` — iblock type permissions;
- `b_lists_field` — field settings per iblock/field;
- `b_lists_socnet_group` — socialnetwork group permissions;
- `b_lists_url` — livefeed/list URL config.

The actual list data is still `iblock` data: iblocks, sections, elements, properties and rights. `lists` adds process/list wrappers, permissions, field settings and integrations.

### `pull`

Tables:

- `b_pull_stack` — queued events by channel;
- `b_pull_channel` — user/public channels;
- `b_pull_push` — device tokens/push registration;
- `b_pull_push_queue` — push queue;
- `b_pull_watch` — tag watches/subscriptions.

Confirmed DataManagers: `ChannelTable`, `PushTable`, `WatchTable`.

## Events, agents and options

### `bizproc`

Install registers:

- `iblock.OnAfterIBlockElementDelete` → `CBPVirtualDocument::OnAfterIBlockElementDelete`;
- `main.OnAdminInformerInsertItems` → `CBPAllTaskService::OnAdminInformerInsertItems`;
- REST: `OnRestServiceBuildDescription`, `OnRestAppDelete`, `OnRestAppUpdate` → `Bitrix\Bizproc\RestService`;
- `timeman.OnAfterTMDayStart` → `CBPDocument::onAfterTMDayStart`;
- REST app configuration handlers: import/export/clear/entity through `Bitrix\Bizproc\Integration\Rest\AppConfiguration`;
- `im.OnGetNotifySchema` → `Bitrix\Bizproc\Integration\NotifySchema`;
- forum/socialnetwork comment listeners for workflow comments/views;
- intranet settings provider, CRM category delete guards, AI context messages.

Agents:

- `Bitrix\Bizproc\Infrastructure\Agent\StorageCleanupAgent::runAgent();` daily;
- `Bitrix\Bizproc\Install\Agent\CreateRobotVersionIndex::run();` after install, interval 60;
- options UI can add/remove `CBPTrackingService::ClearOldAgent();`, `Bitrix\Bizproc\Worker\Workflow\ClearFilterAgent::getName()`, `Bitrix\Bizproc\Worker\Task\ClearSearchContentAgent::getName()`.

Options confirmed:

- `SkipNonPublicCustomTypes=Y` on install;
- `log_cleanup_days` default `90`;
- `search_cleanup_days`;
- `employee_compatible_mode`;
- `limit_simultaneous_processes`;
- `limit_while_iterations` default `1000`;
- `log_skip_types`;
- `automation_no_forced_tracking`;
- `enable_getdocument_select`;
- `storage_items_cleanup_days` default `90`;
- `storage_item_data_limit` default `1`;
- `use_gzip_compression`;
- `locked_wi_path`;
- per-site `name_template`.

### `bizprocdesigner`

Install registers:

- `pull.OnGetDependentModule` → `Bitrix\BizprocDesigner\Internal\Integration\Pull\BizprocDesignerPullManager::OnGetDependentModule`;
- `main.OnAfterRegisterModule` → module/service setup handler.

It copies admin/tools/components/js. It has no DB tables of its own in this core.

### `workflow`

Install registers:

- `main.OnPanelCreate` → `CWorkflow::OnPanelCreate`;
- `main.OnChangeFile` → `CWorkflow::OnChangeFile`.

Agent:

- `CWorkflow::CleanUp();`

Options confirmed:

- `USE_HTML_EDIT` default `Y`;
- `HISTORY_SIMPLE_EDITING` default `N`;
- `MAX_LOCK_TIME` default `60`;
- `DAYS_AFTER_PUBLISHING` default `0`;
- `HISTORY_COPIES` default `10`;
- `HISTORY_DAYS` default `-1`;
- `WORKFLOW_ADMIN_GROUP_ID`.

### `lists`

Install registers:

- `iblock.OnAfterIBlockUpdate`, `OnIBlockDelete`, `OnAfterIBlockDelete` → `CLists` cleanup/sync;
- `iblock.CIBlockDocument_OnGetDocumentAdminPage` → `CList::OnGetDocumentAdminPage`;
- `iblock.OnAfterIBlockElementDelete`, property add/update/delete and before element add/update hooks;
- `intranet.OnSharepointCreateProperty`, `OnSharepointCheckAccess`;
- `perfmon.OnGetTableSchema`;
- `search.OnSearchGetURL`;
- socialnetwork livefeed/comment/mention/group handlers;
- REST: `onRestServiceBuildDescription` → `Bitrix\Lists\Rest\RestService`;
- `main.OnGetRatingContentOwner`;
- `socialnetwork.onLogIndexGetContent`;
- `im.OnGetNotifySchema`.

Install also runs `Bitrix\Lists\Importer::installProcesses($defaultLang)` and sets `lists.livefeed_url=/bizproc/processes/`.

Options/defaults:

- `socnet_iblock_type_id` default empty;
- `livefeed_url` default `/bizproc/processes/`;
- `livefeed_iblock_type_id` default `bitrix_processes`.

### `pull`

Install registers:

- `main.OnBeforeProlog` → `/modules/pull/ajax_hit_before.php`;
- `main.OnProlog` → `/modules/pull/ajax_hit.php` and `CPullOptions::OnProlog`;
- `main.OnEpilog` → `CPullOptions::OnEpilog`;
- `main.OnAfterEpilog` → `Bitrix\Pull\Event::onAfterEpilog` and `CPullWatch::DeferredSql`;
- `perfmon.OnGetTableSchema`;
- `main.OnAfterRegisterModule`, `OnAfterUnRegisterModule` → `CPullOptions::ClearCheckCache`;
- `socialnetwork.OnSonetLogCounterClear` → `Bitrix\Pull\MobileCounter`;
- REST: `OnRestServiceBuildDescription`, `onRestCheckAuth`.

Agent:

- `CPullOptions::ClearAgent();` every 30 seconds.

Default options include listener/websocket/publish URLs, `push=Y`, `guest=Y`, `push_message_per_hit=100`, `websocket=Y`, `server_mode=personal`, signature/config timestamps and shared-server settings. `bitrix/php_interface/pull.php` can override defaults.

## Standard component contracts

### `bizproc.automation`

Confirmed params:

- `DOCUMENT_TYPE` complex document type array;
- `DOCUMENT_ID`;
- `DOCUMENT_CATEGORY_ID`;
- `STATUSES_EDIT_URL`;
- `WORKFLOW_EDIT_URL`;
- `CONSTANTS_EDIT_URL`;
- `PARAMETERS_EDIT_URL`;
- `TITLE_VIEW`, `TITLE_EDIT`;
- `API_MODE=Y`;
- `ONE_TEMPLATE_MODE`;
- `TEMPLATE`;
- `IS_TEMPLATES_SCHEME_SUPPORTED`;
- `ACTION=ROBOT_SETTINGS`, `~ROBOT_DATA`, `~CONTEXT_ROBOTS`, `~CONTEXT`.

Behavior:

- requires `bizproc`;
- signs document type/id/category for AJAX;
- returns document fields/user groups/name/statuses/templates/triggers/global variables/log;
- AJAX requires authorized user, POST and `check_bitrix_sessid()`;
- AJAX actions include robot settings and `UPDATE_TEMPLATES`;
- template save goes through `Bitrix\Bizproc\Automation\Engine\Template::save()`.

Gotcha: UI success does not prove runtime start. For runtime check `b_bp_workflow_template`, `b_bp_automation_trigger`, `b_bp_workflow_instance/state`, tracking log and target document type/status.

### `bizproc.workflow.start`

Confirmed params/request:

- `MODULE_ID`, `ENTITY`, `DOCUMENT_TYPE`, `DOCUMENT_ID`;
- `SIGNED_DOCUMENT_TYPE`, `SIGNED_DOCUMENT_ID`;
- `TEMPLATE_ID` / request `workflow_template_id`;
- `AUTO_EXECUTE_TYPE`;
- `ACTION`;
- `SET_TITLE` default `Y`.

Behavior:

- requires `bizproc`;
- unsigned signed document type/id when provided;
- checks `CBPDocument::CanUserOperateDocument` or `CanUserOperateDocumentType` for start;
- loads templates through `CBPDocument::getTemplatesForStart()` / `CBPWorkflowTemplateLoader`;
- validates parameters via `CBPWorkflowTemplateLoader::CheckWorkflowParameters()` / `CBPDocument::StartWorkflowParametersValidate()`;
- starts through `CBPDocument::StartWorkflow()`;
- AJAX actions include `GET_TEMPLATES`, `START_WORKFLOW`, `CHECK_PARAMETERS` and require `check_bitrix_sessid()`.

### `bizproc.task` and `bizproc.task.list`

`bizproc.task`:

- requires `bizproc` and `iblock`;
- params/request: `TASK_ID`, `task_id`, `WORKFLOW_ID`, `DOCUMENT_ID`, `USER_ID`, `TASK_EDIT_URL`, `SET_TITLE`, `SET_NAV_CHAIN`, `POPUP`;
- loads task via `CBPTaskService::GetList()` with `TASK_ID` + `USER_ID`, or by workflow ID and waiting status;
- supports read-only mode for subordinate/admin views;
- comments AJAX requires authorized user, sessid and `bizproc`.

`bizproc.task.list`:

- params: `USER_ID`, `WORKFLOW_ID`, `TASK_EDIT_URL`, `PAGE_ELEMENTS` default `50`, `PAGE_NAVIGATION_TEMPLATE`, `SHOW_TRACKING`, `SET_TITLE`, `SET_NAV_CHAIN`, `COUNTERS_ONLY`;
- grid IDs: `bizproc_task_list`, filter `bizproc_task_list_filter`;
- uses `CGridOptions`, filter/grid columns and task/tracking arrays.

For task bugs check `b_bp_task`, `b_bp_task_user`, `USER_STATUS`, task member, delegation type, workflow state and comments forum binding.

### `bizproc.log` / `bizproc.workflow.instances`

`bizproc.log`:

- params: `ID`/`WORKFLOW_ID`, `COMPONENT_VERSION=2`, `SET_TITLE`, `INLINE_MODE`, `AJAX_MODE`, `NAME_TEMPLATE`, `SET_ADMIN_MODE`;
- checks `CBPStateService::GetWorkflowState()`;
- checks `CBPDocument::CanUserOperateDocument(ViewWorkflow)`;
- grid id includes workflow template id;
- reads tracking by `WORKFLOW_ID` and can show admin details.

`bizproc.workflow.instances`:

- grid id `bizproc_instances`;
- filters by document type group (`*`, `is_locked`, `processes`, `crm`, `disk`, `iblock`) and module/entity/document id;
- uses `Grid\Options`, `Filter\Options`, D7 `PageNavigation`;
- source is `WorkflowInstanceTable` / workflow state joins.

### `bizproc.workflow.edit` / `bizprocdesigner.editor`

`bizproc.workflow.edit`:

- requires `bizproc` + `bizprocdesigner`;
- params: `MODULE_ID`, `ENTITY`, `DOCUMENT_TYPE`, `ID`, `LIST_PAGE_URL`, `EDIT_PAGE_TEMPLATE`, `BACK_URL`;
- loads template from `WorkflowTemplateTable` by ID;
- checks `CBPDocument::CanUserOperateDocumentType` and document type equality;
- save/import/export actions require `check_bitrix_sessid()`;
- save fields include `AUTO_EXECUTE`, `NAME`, `DESCRIPTION`, `TEMPLATE`, `PARAMETERS`, `VARIABLES`, `CONSTANTS`.

`bizprocdesigner.editor`:

- modern editor component;
- derives complex document type from params or template ID;
- checks limits/access before rendering;
- can fill `START_TRIGGER`;
- uses activity searcher from ServiceLocator.

### `bizproc.script.*` and storage components

`bizproc.script.list`:

- takes `DOCUMENT_TYPE_SIGNED`, unsigns to `DOCUMENT_TYPE`;
- grid lists scripts for module/entity/document type through `Script\Manager` and `ScriptTable`;
- uses D7 `PageNavigation` and checks `Manager::canUserCreateScript()`.

`bizproc.script.edit`:

- params `SCRIPT_ID`, `DOCUMENT_TYPE_SIGNED`, `PLACEMENT`, `SET_TITLE`;
- creates/loads scripts through `Bitrix\Bizproc\Script\Manager`;
- AJAX controller requires `bizproc`.

`bizproc.storage.item.list`:

- param/request `storageId`; optional `gridId`;
- requires `bizproc` and `ui` for filter features;
- uses `Storage\Service`, `PageNavigation`, `main.ui.grid` AJAX options;
- columns include `CODE`, `WORKFLOW_ID`, `DOCUMENT_ID`, `TEMPLATE_ID`, creator/date fields.

### `lists` router and process components

`lists` root component:

- routes SEF pages for list/list edit/sections/element/file plus bizproc pages;
- bizproc URL templates include `bizproc_workflow_start`, `bizproc_task`, `bizproc_workflow_admin`, `bizproc_workflow_edit`, `bizproc_workflow_vars`, `bizproc_workflow_constants`;
- stores livefeed URL option when `IBLOCK_TYPE_ID` matches `lists.livefeed_iblock_type_id`;
- if `document_state_id` is present, resolves element ID from `CBPStateService::GetWorkflowState()`.

`lists.list`:

- checks list rights through `CListPermissions` and `CList`;
- detects `PROCESSES` when iblock type equals `lists.livefeed_iblock_type_id`;
- enables bizproc controls when iblock `BIZPROC=Y`, module `bizproc` exists and `CLists::isBpFeatureEnabled()`;
- grid IDs: `lists_list_elements_<IBLOCK_ID>`, filter same;
- AJAX controller uses `main` Engine Controller and action query param.

`lists.element.edit`:

- uses `ElementRight`/`RightParam` services for access;
- detects bizproc with `Loader::includeModule('bizproc')`, `CLists::isBpFeatureEnabled()`, iblock `BIZPROC != N`;
- AJAX actions check `bizproc` before template/process operations;
- routes task/workflow URLs through params such as `BIZPROC_WORKFLOW_START_URL`, `BIZPROC_TASK_URL`, `BIZPROC_LOG_URL`.

`lists.user.processes`:

- uses `lists.livefeed_iblock_type_id`;
- requires `bizproc` and `CLists::isBpFeatureEnabled()`;
- grid/filter `lists_processes`;
- lists elements created by user and attaches current workflow state/comments counts.

### `pull.request`

- if request `AJAX_CALL=Y`, component returns early;
- otherwise may define `BX_PULL_SKIP_INIT` and include template unless `TEMPLATE_HIDE=Y`;
- AJAX init defines `PULL_AJAX_INIT`, `PUBLIC_AJAX_MODE`, `NO_AGENT_STATISTIC`, `DisableEventsCheck`;
- returns `BITRIX_SESSID` on auth/session errors;
- requires valid session for normal pull request handling.

## REST surface

### `bizproc` REST

Confirmed REST methods:

- activities/robots/providers: `bizproc.activity.add/update/delete/log/list`, `bizproc.robot.add/update/delete/list`, `bizproc.provider.add/delete/list`;
- events: `bizproc.event.send`;
- tasks: `bizproc.task.list`, `bizproc.task.complete`, `bizproc.task.delegate`;
- workflows: `bizproc.workflow.start`, `bizproc.workflow.terminate`, `bizproc.workflow.kill`, `bizproc.workflow.instance.list`, alias `bizproc.workflow.instances`;
- templates: `bizproc.workflow.template.list/add/update/delete`;
- placement: activity properties dialog.

REST app delete/update cleans `RestActivityTable` / `RestProviderTable` entries for app client id.

### `lists` REST

Confirmed methods:

- `lists.get.iblock.type.id`;
- `lists.add/get/update/delete`;
- `lists.section.add/get/update/delete`;
- `lists.field.add/get/update/delete`, `lists.field.type.get`;
- `lists.element.add/get/update/delete`, `lists.element.get.file.url`.

REST code applies list/section/element rights via `RightParam`, `IblockRight`, `ElementRight` and exposes `ERROR_BIZPROC` for workflow-dependent failures.

### `pull` REST

Confirmed methods:

- app/channel/events: `pull.application.config.get`, `pull.application.event.add`, `pull.application.push.add`, `pull.watch.extend`;
- channels: `pull.config.get`, `pull.channel.public.get`, `pull.channel.public.list`;
- mobile counters/push config/status methods.

REST throws `SERVER_ERROR` when Pull server is not configured and restricts some methods to app authorization/admin.

## Shop/commerce integration notes

### Sale/order automation

In checked `sale` 26.0.0, direct `bizproc` references are mostly module-packaging / CRM site master dependency metadata, not a confirmed order workflow document provider. Therefore:

- for order lifecycle changes use `sale.md` events/API first;
- if user wants “order robots”, verify local modules/project first: CRM, custom module, or provider implementing `IBPWorkflowDocument`/document type for orders;
- do not create “robots for orders” by writing to `b_bp_*` manually.

### Catalog/iblock/list automation

Confirmed adjacent layer:

- `iblock` has `CIBlockDocument implements IBPWorkflowDocument` and `BIZPROC` flag;
- `iblock` prevents `WORKFLOW=Y` and `BIZPROC=Y` together;
- `catalog` product grid uses `Iblock\Grid\Column\BusinessProcessProvider` for BP columns;
- `lists` wraps iblock elements as process documents through `BizprocDocument` and `BizprocDocumentLists`.

For product/content automation, first determine document type:

- plain iblock element: `['iblock', 'CIBlockDocument', 'iblock_<IBLOCK_ID>']` / document id with element;
- lists process: `lists` `BizprocDocument`/`BizprocDocumentLists` generated complex type;
- custom module: inspect provider/entity class.

## Diagnostics by symptom

### Workflow does not start

Check:

1. Module exists: `bizproc`; for editor also `bizprocdesigner`.
2. Correct complex document type: module/entity/document type and document id.
3. Template active and `AUTO_EXECUTE` matches manual/create/update/event/script scenario.
4. `CBPDocument::CanUserOperateDocument(Type)` grants start.
5. Required parameters/constants are set.
6. `CBPWorkflowTemplateLoader::CheckWorkflowParameters()` errors.
7. `b_bp_workflow_template`, `b_bp_workflow_state`, `b_bp_workflow_instance`.
8. Tracking/log through `bizproc.log` / `b_bp_tracking`.
9. Limit options: simultaneous processes, while iterations.

### Robot or trigger does not fire

Check:

1. Target document type/category/status passed to `bizproc.automation`.
2. Template exists for expected `DOCUMENT_STATUS`.
3. Trigger rows in `b_bp_automation_trigger` and `b_bp_workflow_template_trigger`.
4. Runtime target handler supports this document/status.
5. Conditions/delays in robot template.
6. Tracking can be skipped by `automation_no_forced_tracking` / `log_skip_types`.
7. If UI changes were made through AJAX, verify sessid and `UPDATE_TEMPLATES` result.

### Task is stuck or user cannot complete it

Check:

1. `b_bp_task` row and `b_bp_task_user` membership.
2. `USER_STATUS` and task status are waiting, not already done.
3. Current user vs `USER_ID`; subordinate/admin view may be read-only.
4. Delegation type and target user.
5. Workflow state exists and is not terminated/locked unexpectedly.
6. Comments/forum integration only affects discussion, not task completion.
7. Use `TaskService::doTask()` / `CBPTaskService` APIs, not direct SQL.

### Designer cannot save template

Check:

1. `bizprocdesigner` installed and component `bizproc.workflow.edit`/`bizprocdesigner.editor` exists.
2. User can operate document type.
3. `MODULE_ID`, `ENTITY`, `DOCUMENT_TYPE` match the template row.
4. POST has valid sessid.
5. Template payload has `TEMPLATE`, `PARAMETERS`, `VARIABLES`, `CONSTANTS` arrays.
6. Check `b_bp_workflow_template`, draft/settings tables and PHP errors from activity validation.
7. If realtime editor state is broken, then check `pull` dependency, but not before access/template errors.

### Lists process is missing or cannot start

Check:

1. `lists` + `iblock` + `bizproc` modules exist.
2. Iblock type and iblock id; list data is still iblock data.
3. Iblock `BIZPROC=Y` and not legacy `WORKFLOW=Y`.
4. `CLists::isBpFeatureEnabled($IBLOCK_TYPE_ID)`.
5. User rights via `CListPermissions`, `ElementRight`, `RightParam`.
6. Component routes for `bizproc_workflow_start`, `bizproc_task`, `bizproc_workflow_admin`, `bizproc_workflow_edit`.
7. Template auto-start on create/update if livefeed/process action expects auto-start.

### Legacy workflow blocks file/page edits

Check:

1. Is module `workflow` really used, not `bizproc`?
2. File path/document row in `b_workflow_document`.
3. Status in `b_workflow_status` and group rights in `b_workflow_status2group`.
4. Lock timeout `MAX_LOCK_TIME` and locked user.
5. Cleanup/history options: copies/days/after publishing.
6. `CWorkflow::OnChangeFile` and admin panel hooks.
7. `fileman` editor behavior if `USE_HTML_EDIT=Y`.

### Pull/realtime updates do not arrive

Check:

1. `pull` module installed and event handlers registered.
2. Pull server status/mode/config URL options.
3. `CPullOptions::ClearAgent();` runs.
4. Channel exists in `b_pull_channel`; events in `b_pull_stack`.
5. Watch tag in `b_pull_watch` if using watches.
6. JS client/template includes `pull.request` or modern pull extension.
7. REST app auth restrictions if events come from REST.
8. For general push/pull patterns also open `push-pull.md`.

## Safe implementation rules

- Do not write `b_bp_*`, `b_workflow_*`, `b_lists_*`, `b_pull_*` directly unless no API exists and user approved data mutation.
- Use `CBPDocument`, `CBPWorkflowTemplateLoader`, `WorkflowService`, `TaskService`, `Script\Manager`, `CList`/`CLists`/rights services before SQL.
- For workflow starts always pass correct complex document type and target user parameters.
- For template edits preserve `PARAMETERS`, `VARIABLES`, `CONSTANTS`, `AUTO_EXECUTE`, document type and system code semantics.
- For list processes keep iblock rights/site/group constraints; list UI is not just a grid template.
- For `pull`, do not expose public channels or app push without auth checks and server config validation.
- For smoke tests do not start real customer/order side effects unless explicitly approved; use sandbox docs/list elements.

## What not to do

- Do not claim all shop order automation exists just because `bizproc` is installed.
- Do not confuse `workflow` legacy status workflow with `bizproc` templates/states/tasks.
- Do not fix automation by patching only component templates; check document type, template, runtime state, tasks and tracking.
- Do not use `pull` as a substitute for workflow state or task completion.
- Do not enable both `WORKFLOW` and `BIZPROC` for the same iblock.
- Do not activate automation route in another project until each target module exists locally.


---

## Source: `shop-integrations-webservice.md`

# Shop integrations/webservice — webservice, REST, sale/catalog app hooks

> Reference для Bitrix-скилла. Загружай, когда задача связана с `webservice.sale`, `webservice.statistic`, SOAP/WSDL, REST webhooks/apps/placements, sale/catalog REST API, внешними платежными/доставочными/кассовыми app handlers или когда нужно закрыть integration extras shop-core. Не используй этот файл как замену `commerce-1c-integration.md`: CommerceML/1С живёт в `catalog.import.1c`, `catalog.export.1c`, `sale.export.1c`.

## Audit note

Проверено по shop-core:

- `www/bitrix/modules/webservice` — `26.0.0`, `VERSION_DATE` `2026-03-18 18:00:00`, 5 components, 0 admin pages, 1 `lib` file, 12 legacy class files, no DB tables.
- `www/bitrix/modules/rest` — `26.0.0`, `VERSION_DATE` `2026-01-28 16:35:48`, 42 components, 2 admin pages, 510 `lib` files, REST DB layer present.
- Adjacent confirmed modules: `sale` `26.0.0`, `catalog` `25.550.0`, `statistic` `26.0.0`.
- `webservice.sale` and `webservice.statistic` are **components inside module `webservice`**, not separate modules `webservice.sale` / `webservice.statistic`.

Use this as confirmed routing/contract layer. For order lifecycle read `sale.md`; for product/price/store data read `catalog.md`; for generic REST patterns read `rest.md`; for traffic/statistic internals read `shop-marketing-analytics.md`; for 1С/CommerceML read `commerce-1c-integration.md`.

## Главный вывод

`webservice` in this core is legacy SOAP/WSDL infrastructure plus two dashboard/gadget services:

1. `webservice.server` — generic SOAP endpoint wrapper around `IWebService` implementors.
2. `webservice.checkauth` — SOAP auth helper.
3. `webservice.sale` — sale **statistics/livefeed** SOAP service over order counters, not order CRUD and not 1С exchange.
4. `webservice.statistic` — legacy traffic/statistic SOAP service, not sales analytics by itself.
5. `stssync.server` — SharePoint/Outlook sync endpoint layer with application-password auth.

Modern external integrations in this shop-core mostly use `rest` + module controllers/events:

- `sale` exposes Engine REST controllers for order/payment/shipment/basket/status/properties and explicit REST scopes for pay systems, deliveries, cashboxes and sale events.
- `catalog` exposes Engine REST controllers for products, prices, price types, measures, stores, store products, documents, sections and event bindings for selected catalog entities.
- `rest` owns apps, incoming/outgoing webhooks, event bindings, placements, auth, batch, method discovery and usage/stat tables.

Критично:

- `webservice.sale` ≠ `sale.export.1c` and ≠ order API. It returns aggregate counters and a link to `/bitrix/admin/sale_stat.php`.
- `webservice.statistic` requires module `statistic` and reads legacy traffic tables. It can be empty even when orders exist.
- REST controller method names must be confirmed at runtime with `methods`, `method.get` or the Engine route map before hardcoding; controller/action summaries below are routing hints.
- Do not expose SOAP helpers or test endpoints publicly without access review: `webservice.checkauth` accepts login/password and returns user fields; `webservice.server?test` can execute component test code.

## Fast routing

| Запрос | Сначала читать | Затем |
|---|---|---|
| “`webservice.sale` не работает” | `webservice.sale` section below | `sale.md`, order rights/status/date filters |
| “`webservice.statistic` пустой” | `webservice.statistic` section below | `shop-marketing-analytics.md`, `statistic` tables/options |
| “Нужен WSDL/SOAP endpoint” | `webservice.server` + SOAP classes | `http.md`, access/auth review |
| “REST событие заказа не прилетело” | sale REST events section | `rest.md`, `b_rest_event`, `event.offline.*` |
| “Внешняя доставка/ПС/касса через приложение” | sale explicit REST scopes | handler tables and `onRestAppDelete` cleanup |
| “REST товар/цена/склад” | catalog REST controllers | `catalog.md`, `rest.md`, permissions, pagination |
| “Placement для внешнего товара” | catalog placement section | `placement.*`, `b_rest_placement` |
| “Это 1С?” | usually `commerce-1c-integration.md` | only use this file if task is SOAP/REST, not CommerceML |

## `webservice` module structure

### Components — 5

- `webservice.server` — generic SOAP server component.
- `webservice.checkauth` — auth SOAP service wrapper.
- `webservice.sale` — order statistics livefeed SOAP service.
- `webservice.statistic` — traffic/statistics SOAP service and Windows gadget assets.
- `stssync.server` — SharePoint/Outlook list sync server.

### Legacy classes

Autoloaded from `include.php`:

- XML: `CXMLCreator`.
- SOAP structures: `CSOAPHeader`, `CSOAPBody`, `CSOAPEnvelope`, `CSOAPParameter`, `CSOAPFault`.
- SOAP runtime: `CSOAPCodec`, `CSOAPRequest`, `CSOAPResponse`, `CSOAPClient`, `CSOAPServerResponser`, `CWSSOAPResponser`, `CSOAPServer`.
- WSDL: `CWSDLCreator`.
- Web service wrapper: `CWebServiceDesc`, `IWebService`, `CWebService`.
- SharePoint client: `CSPListsClient`.

Constants registered by `include.php` include SharePoint service path/namespace and SOAP namespace constants such as `BX_SOAP_ENV`, `BX_SOAP_ENC`, `BX_SOAP_SCHEMA_INSTANCE`, `BX_SOAP_SCHEMA_DATA`.

### Install files/endpoints

Install copies:

- components to `/bitrix/components/bitrix/*`;
- tools to `/bitrix/tools/`: `sale_gadget.php`, `stat_gadget.php`, `stssync.php`;
- JS extension `stssync` to `/bitrix/js/webservice/stssync.js`;
- sample `/bitrix/ws/wscauth.php`, `/bitrix/ws/wsadvert.php`, with `.access.php` denying folder by default except those files for group 2 read.

Options: `webservice` default option `DENYALL=N`; options page mainly links the statistic gadget package.

## SOAP core contract

### `webservice.server`

Parameters:

- `WEBSERVICE_NAME` — SOAP service name, e.g. `bitrix.webservice.sale`.
- `WEBSERVICE_MODULE` — module to include before class lookup; can be empty when class is defined by current component.
- `WEBSERVICE_CLASS` — `IWebService` implementor class.
- optional `SOAPSERVER_RESPONSER` array — raw SOAP responders.

Runtime behavior:

1. Design mode shows include areas/template for admin.
2. If `SOAPSERVER_RESPONSER` is passed and request is POST without `directcall`, it creates `CSOAPServer` and processes raw SOAP.
3. Otherwise it includes `WEBSERVICE_MODULE` if class is missing.
4. Calls `CWebService::SetComponentContext($arParams)` and `CWebService::RegisterWebService($WEBSERVICE_CLASS)`.
5. `?wsdl` returns XML WSDL from `CWebService::GetWSDL($WEBSERVICE_NAME)`.
6. `?test` runs `CWebService::TestComponent($WEBSERVICE_NAME)`.
7. POST without `directcall` runs `CWebService::SOAPServerProcessRequest($WEBSERVICE_NAME)`.
8. Other requests render component template/service description.

`IWebService` implementors must provide `GetWebServiceDesc()` returning `CWebServiceDesc` with:

- `wsname`;
- `wsclassname`;
- `wsdlauto`;
- `wsendpoint`;
- `wstargetns`;
- `classes` method descriptors;
- `structTypes` and `classTypes` complex type descriptors.

`CWebService::RegisterWebService()` rejects missing service name/class/namespace/endpoint/classes/struct/class type arrays, builds WSDL through `CWSDLCreator`, registers functions in `CWSSOAPResponser`, and stores descriptors in `$GLOBALS['wsdescs']` / `$GLOBALS['wswraps']`.

## `webservice.checkauth`

Class: `CCheckAuthWS`.

Methods:

- `CheckAuthorization($user, $password)` — calls `CUser::Login($user, $password)` and returns fetched user fields or `CSOAPFault`.
- `GetHTTPUserInfo()` — requires current user to be admin; otherwise calls `$USER->RequiredHTTPAuthBasic()` and returns fault.

Descriptor:

- `wsname`: `bitrix.webservice.checkauth`;
- struct type `CUser` includes fields such as `ID`, `NAME`, `LOGIN`, `EMAIL`, `ACTIVE`, `PASSWORD`, `CHECKWORD`.

Safety notes:

- Treat this as highly sensitive. Do not expose it to anonymous/public networks casually.
- Do not log SOAP request bodies containing passwords.
- The stock test uses hardcoded `admin` / `123456` in sample code; never copy this into production docs or code.

## `webservice.sale`

Class: `CSaleWS`; requires modules `webservice` and `sale`.

This is **order statistics livefeed**, not order CRUD.

Method:

- `GetLiveFeedData($site_id = "", $lang = "en")`.

Auth:

- `CheckAuth()` reads `$APPLICATION->GetGroupRight('sale')`.
- If sale right is `D`, it triggers HTTP Basic auth and returns SOAP fault.
- If sale right is not `W`, it adds status permission filter by current user groups:
  - `STATUS_PERMS_GROUP_ID` = `$USER->GetUserGroupArray()`;
  - `>=STATUS_PERMS_PERM_VIEW` = `Y`.

Data:

- Aggregates `CSaleOrder::GetList()` by periods:
  - before last week;
  - last week;
  - this week;
  - before yesterday;
  - yesterday;
  - today.
- Status buckets:
  - `CREATED` by `DATE`;
  - `PAID` by `DATE_PAYED`;
  - `CANCELED` by `DATE_UPDATE` + `CANCELED=Y`;
  - `ALLOW_DELIVERY` by `DATE_UPDATE` + `ALLOW_DELIVERY=Y`.
- Sums use aggregate `SUM => PRICE`, `COUNT => ID`.
- Currency is `CSaleLang::GetLangCurrency($site_id)` when site is passed; otherwise `CCurrency::GetBaseCurrency()`.

Output struct `LiveFeedData`:

- `TITLE`;
- `MESSAGE` — HTML table string;
- `TEXT_MESSAGE` — text with `#BR#` separators;
- `URL` — admin URL `/bitrix/admin/sale_stat.php?lang=<lang>`.

Observed gotcha in current core:

- In the `site_id` branch the code calls `CSite::GetByID($arFields['SITE_ID'])` while `$arFields` is not defined in this component. Treat site filtering/server-name behavior as suspect until runtime-tested; verify actual output with a real site id.

Diagnostics:

1. Confirm `webservice` and `sale` modules exist.
2. Confirm endpoint includes `bitrix:webservice.sale`, not `sale.export.1c`.
3. Request `?wsdl` first; then POST SOAP.
4. Check sale group rights and order status permissions.
5. Check date fields: created vs paid vs canceled/delivery are different filters.
6. Check site id/currency branch and current `server_name` option.
7. For actual order CRUD use sale REST controllers or Sale API, not `webservice.sale`.

## `webservice.statistic`

Class: `CStatisticWS`; requires modules `webservice` and `statistic`.

Methods:

- `UsersOnline()` — `CUserOnline::GetList()` sessions and guest count.
- `GetCommonValues()` — `CTraffic::GetCommonValues()` plus `ONLINE_LIST`.
- `GetAdv()` — top advertising/adv records through `CAdv::GetList()`.
- `GetEvents()` — event counters through `CStatEventType::GetList()`.
- `GetPhrases()` — search phrases through `CTraffic::GetPhraseList()`.
- `GetRefSites()` — referer sites through `CTraffic::GetRefererList()`.
- `GetSearchers()` — searchers through `CSearcher::GetList()`.
- `GetLiveFeedData($site_id = "", $lang = "en")` — HTML/text dashboard data.

Auth:

- `CheckAuth()` reads `$APPLICATION->GetGroupRight('statistic')` and triggers HTTP Basic auth/fault if right is `D`.

Limits/options:

- Top lists stop at `COption::GetOptionInt('statistic', 'STAT_LIST_TOP_SIZE', 10)`.

Output:

- `GetLiveFeedData()` returns `LiveFeedData` struct with title, HTML table, text and `/bitrix/admin/stat_list.php?lang=<lang>` URL.
- Generic methods return complex structs: `Session`, `Top`, `UsersOnlineList`, `CommonValues`.

Diagnostics:

1. Confirm module `statistic` exists and actually records traffic/events.
2. Confirm statistic right is not `D` for current user/auth context.
3. Check `STAT_LIST_TOP_SIZE` for unexpectedly short lists.
4. If livefeed is empty but orders exist, this is expected: orders are in `webservice.sale`, not `webservice.statistic`.
5. If statistic is heavy/slow, open `shop-marketing-analytics.md`; `statistic` has runtime hit/session hooks and cleanup/optimization options.

## `stssync.server` and `/bitrix/tools/stssync.php`

`stssync.server` supports only SEF mode. Default templates:

- endpoint: `#user_id#/#ap#/_vti_bin/lists.asmx`;
- item redirect: `#user_id#/#ap#/#path#/DispForm.aspx`;
- index redirect: `#user_id#/#ap#/#path#/`.

Endpoint flow:

1. Parse `user_id`, `ap`, `path`.
2. Include module `webservice`.
3. Call `Bitrix\WebService\StsSync::checkAuth($userId, $ap)`.
4. Include `bitrix:webservice.server` with target service params.
5. Final actions and die.

`Bitrix\WebService\StsSync`:

- `getUrl()` builds JS call `BX.StsSync.sync(...)` and loads JS extension `stssync`.
- `checkAuth($userId, $ap)` uses `ApplicationPasswordTable::findPassword()` and accepts only application password with `OutlookApplication::ID` and valid scope; then updates login date/IP and authorizes user.
- `getAuth($type)` generates application password through intranet `OutlookApplication`.

`/bitrix/tools/stssync.php`:

- defines `NOT_CHECK_PERMISSIONS`;
- responds JSON;
- action `stssync_auth` requires authorized user, POST, `check_bitrix_sessid()` and module `webservice`;
- returns generated application password `ap` when available.

Safety:

- Treat `ap` as a credential.
- Do not bypass POST + sessid for `stssync_auth`.
- Do not expose arbitrary service class through `stssync.server` without checking `WEBSERVICE_CLASS` and auth.

## Generic REST module layer

### Components — 42

Important families:

- endpoint/auth: `rest.server`, `rest.authorize`, `rest.token`;
- webhooks/integrations: `rest.hook*`, `rest.integration.*`;
- marketplace/apps: `rest.marketplace*`, `app.layout`, `app.placement`, `rest.app.settings`;
- configuration import/export/install: `rest.configuration*`;
- provider/stat: `rest.provider`, `rest.statistic`;
- tooling: `rest.devops`, `rest.apconnect`, `rest.einvoice.installer`.

### Core REST methods

From `CRestProvider` and API handlers:

- `batch`;
- `scope`, `methods`, `method.get`;
- `server.time`;
- `profile`;
- `app.info`, `feature.get`;
- `app.option.get`, `app.option.set`;
- `user.option.get`, `user.option.set`;
- `events`, `event.bind`, `event.unbind`, `event.get`;
- `event.offline.get`, `event.offline.clear`, `event.offline.error`, `event.offline.list`;
- `event.test`;
- `placement.list`, `placement.bind`, `placement.unbind`, `placement.get`;
- user/userfield type methods through `Bitrix\Rest\Api\User` and `UserFieldType`.

### REST auth and handlers

Install registers:

- `main.OnBeforeProlog` → `CRestEventHandlers::OnBeforeProlog`;
- `rest.OnRestServiceBuildDescription` → base entity/user/placement/event/userfieldtype handlers;
- `rest.onFindMethodDescription` → `Bitrix\Rest\Engine\RestManager::onFindMethodDescription`;
- `rest.onRestCheckAuth` → OAuth fallback when `oauth` module is missing, APAuth, SessionAuth;
- configuration import/export/clear/entity/manifest handlers;
- application/module change hooks for scope manager and marketplace tags;
- IM notify schema and subscription hooks.

### REST DB layer

Core tables confirmed:

- app/auth: `b_rest_app`, `b_rest_app_lang`, `b_rest_ap`, `b_rest_ap_permission`;
- event delivery: `b_rest_event`, `b_rest_event_offline`;
- logs/stat: `b_rest_log`, `b_rest_app_log`, `b_rest_stat_method`, `b_rest_stat_app`, `b_rest_stat`;
- placements: `b_rest_placement`, `b_rest_placement_lang`;
- usage/owner/integration/config: `b_rest_usage_entity`, `b_rest_usage_stat`, `b_rest_owner_entity`, `b_rest_integration`, `b_rest_configuration_storage`, `b_rest_free_app`.

Diagnostics for REST:

1. Check method exists with `methods` or `method.get` before assuming name/signature.
2. Check token scopes via `scope` and app permissions.
3. For outgoing events check `b_rest_event` binding and handler URL.
4. For offline/SQS delivery check `b_rest_event_offline` and `event.offline.*` methods.
5. For placements check `placement.list` + `b_rest_placement`.
6. For batch issues check `batch` length/allowed methods and per-method errors.

## Sale REST surface

### Engine controllers

`sale/.settings.php` enables REST integration:

- default namespace: `\Bitrix\Sale\Controller`;
- additional namespace: `\Bitrix\Sale\Exchange\Integration\Controller` under `integration`;
- `restIntegration.enabled = true`.

Controller/action families confirmed:

- `order`: `getFields`, `get`, `tryModify`, `modify`, `tryAdd`, `add`, `tryUpdate`, `update`, `list`, `delete`, order subresource getters, `import`, `importDelete`.
- `basketitem`: fields, catalog product fields, modify/add/update/delete/list, price/quantity/vat/weight getters.
- `payment`: fields, modify/add/update/delete/get/list, paid/return/account/pay system methods.
- `shipment`: fields, modify/add/update/delete/get/list, shipped/allow-delivery/base-price methods.
- `property`, `propertyvalue`, `propertygroup`, `propertyvariant`, `propertyrelation`.
- `persontype`, `status`, `statuslang`, `profile`, `profilevalue`.
- `paymentitembasket`, `paymentitemshipment`, `shipmentitem`, `shipmentpropertyvalue`.
- `deliveryrequest`, `deliveryservices`, `tracking`, `tradebinding`, `tradeplatform`, `businessvaluepersondomain`, `barcode`, `facebookconversion`, `synchronizer`.

Naming is Engine/REST-controller based; confirm concrete public method names in runtime through REST discovery. Typical pattern is `<module>.<controller>.<action>`, e.g. order controller actions map into sale order methods, but do not hardcode without checking current `method.get`.

Sale controller base has important behavior:

- `processBeforeAction()` checks permission and internalizes request fields through `Bitrix\Sale\Rest\Internalizer` or CRM order internalizer when CRM is installed.
- `processAfterAction()` externalizes output through Sale/CRM externalizer.
- `getNavData()` uses `IRestService::LIST_LIMIT` and `start` offset.
- Order builder defaults can create anonymous user and delete missing client/trade/payment/shipment/property structures in REST import-style operations.

### Explicit sale REST scopes/methods

Install registers `rest.OnRestServiceBuildDescription` handlers:

#### Pay systems — scope `pay_system`

- `sale.paysystem.handler.add/update/delete/list`;
- `sale.paysystem.add/update/delete/list`;
- `sale.paysystem.settings.get/update`;
- `sale.paysystem.settings.invoice.get`;
- `sale.paysystem.settings.payment.get`;
- `sale.paysystem.pay.invoice`;
- `sale.paysystem.pay.payment`.

Cleanup on `rest.onRestAppDelete` deletes pay systems created from app REST handlers and rows in `b_sale_pay_system_rest_handlers` when app is clean-deleted.

#### Delivery — scope `delivery`

- handler: `sale.delivery.handler.add/update/delete/list`;
- service: `sale.delivery.add/update/delete/getList`, `sale.delivery.config.get/update`;
- request: `sale.delivery.request.update/delete/sendmessage`;
- extra services: `sale.delivery.extra.service.add/update/delete/get`.

Handler storage: `b_sale_delivery_rest_handler`. App delete cleanup runs through `Bitrix\Sale\Delivery\Rest\BaseService::onRestAppDelete`.

#### Cashbox — scope `cashbox`

- handlers: `sale.cashbox.handler.add/update/delete/list`;
- cashboxes: `sale.cashbox.add/update/delete/list`;
- settings: `sale.cashbox.settings.get/update`, `sale.cashbox.ofd.settings.get/update`;
- checks: `sale.cashbox.check.apply`;
- OFD: `sale.ofd.list`, `sale.ofd.settings.get`.

Handler storage: `b_sale_cashbox_rest_handler`. App delete cleanup removes matching REST cashboxes and handlers.

### Sale REST events

`Bitrix\Sale\Rest\RestManager::onRestServiceBuildDescription()` registers scope `sale` events:

- `OnSaleOrderSaved` → PHP event `sale.OnSaleOrderSaved`;
- `OnSaleBeforeOrderDelete` → `sale.OnSaleBeforeOrderDelete`;
- `OnPropertyValueEntitySaved` → `sale.OnSalePropertyValueEntitySaved`;
- `OnPaymentEntitySaved` → `sale.OnSalePaymentEntitySaved`;
- `OnShipmentEntitySaved` → `sale.OnSaleShipmentEntitySaved`;
- `OnOrderEntitySaved` → `sale.OnSaleOrderEntitySaved`;
- `OnPropertyValueDeleted` → `sale.OnSalePropertyValueDeleted`;
- `OnPaymentDeleted` → `sale.OnSalePaymentDeleted`;
- `OnShipmentDeleted` → `sale.OnSaleShipmentDeleted`;
- `OnOrderDeleted` → `sale.OnSaleOrderDeleted`.

Event payloads:

- `OnSaleOrderSaved` returns `FIELDS.ID`, `FIELDS.XML_ID`, `FIELDS.ACTION=save` unless import/deleted action or same handler is already executed.
- `OnSaleBeforeOrderDelete` returns `FIELDS.ID`, `FIELDS.XML_ID`, `FIELDS.ACTION=delete` and marks manager action as deleted.
- Entity saved/deleted events return `FIELDS.ID` of entity/order-related entity.
- Unsupported context throws `RestException`.

Diagnostics:

1. Check REST event binding with `event.get` / `b_rest_event`.
2. Check app scope contains `sale` and event is available.
3. If event is suppressed, inspect `Bitrix\Sale\Rest\Synchronization\Manager` action: import/delete and duplicate executed handler can stop event.
4. For delete flow check `OnSaleBeforeOrderDelete` vs post-delete events.
5. For partial entity events check whether event parameters include `ENTITY` or `VALUES.ID`.

## Catalog REST surface

### Engine controllers

`catalog/.settings.php` enables REST integration:

- default namespace: `\Bitrix\Catalog\Controller`;
- `restIntegration.enabled = true`;
- REST event bind classes: `Price`, `Product`, `Measure`, `RoundingRule`, `PriceType`.

Controller/action families confirmed:

- `catalog`: `getFields`, `isOffers`, `list`, `get`, `add`, `update`, `delete`.
- `product`: `configure`, `getFieldsByFilter`, `list`, `get`, `add`, `update`, `delete`, `download`, `addProperty`.
- product subtypes: `product.offer`, `product.service`, `product.sku`.
- `price`, `pricetype`, `pricetypegroup`, `pricetypelang`, `pricetyperights`.
- `measure`, `ratio`, `roundingrule`, `vat`, `extra`.
- `store`, `storeproduct`, `storeselector`.
- `document`, `document.element`, `document.mode`, `documentcontractor`.
- `section`, `productproperty*`, `productimage`, `contractor`, `enum`, `config`, `analytics`.

Catalog controller base:

- uses `Bitrix\Rest\Integration\Controller\Base`;
- creates rest views through `CatalogViewManager`;
- gates operations with `Bitrix\Catalog\Access\AccessController` actions;
- list pagination uses `IRestService::LIST_LIMIT` and `start` offset.

### Catalog REST events and placement

`catalog.install` registers:

- `rest.OnRestServiceBuildDescription` → `Bitrix\Catalog\EventDispatcher\EventDispatcher::onRestServiceBuildDescription`;
- `rest.OnRestAppInstall` → `Bitrix\Catalog\Store\EnableWizard\OnecAppManager::onRestAppInstall`.

Event dispatcher returns scope `catalog`:

- `CRestUtil::EVENTS` from event-bind classes in `.settings.php`;
- placement `CATALOG_EXTERNAL_PRODUCT`.

Confirmed event-bind classes:

- `Bitrix\Catalog\Controller\Product` — maps add/update/delete model events to REST event names like `<module>.<entity>.on.add`, `<module>.<entity>.on.update`, `<module>.<entity>.on.delete`; callback payload includes `FIELDS.ID` and `FIELDS.TYPE`.
- `Bitrix\Catalog\Controller\PriceType` — maps `OnGroupAdd`, `OnGroupUpdate`, `OnGroupDelete` to `catalog.price.type.on.add/update/delete`; payload includes `FIELDS.ID`.
- `Price`, `Measure`, `RoundingRule` also implement `EventBindInterface`; inspect current class `getHandlers()` when exact event name matters.

Placement:

- `CATALOG_EXTERNAL_PRODUCT` is available through `placement.*` APIs and stored in `b_rest_placement`.
- Use this for external product UI/app embedding, not for replacing catalog product storage.

Diagnostics:

1. Confirm app has `catalog` scope and method exists via `method.get`.
2. For list methods check `start`, `IRestService::LIST_LIMIT`, stable order and filters.
3. For product writes check catalog RBAC, iblock rights, price permissions and product type/SKU constraints.
4. For file/download actions check `catalog.product.download` route and file access.
5. For event delivery inspect `b_rest_event` and event-bind class payload.
6. For external product placement inspect `placement.list`, `placement.get`, `b_rest_placement` and user/site constraints.

## B24 sale exchange/integration layer

Do not confuse this with 1С/CommerceML.

In `sale/lib/exchange/integration/*` the core contains B24/CRM integration classes:

- app/oauth/client/token layer;
- controllers under namespace `Bitrix\Sale\Exchange\Integration\Controller` with route prefix `integration`;
- REST remote proxies for CRM activity/company/contact/deal/placement/timeline and sale statistics/statistics provider;
- command/batch services;
- entities/tables: `b_sale_b24integration_bind`, `b_sale_b24integration_relation`, `b_sale_b24integration_token`, `b_sale_b24integration_stat_provider`, `b_sale_b24integration_stat`.

Use it when a task says Bitrix24/CRM app integration, not when it says “1С выгрузка”. For 1С open `commerce-1c-integration.md`.

## Diagnostics by symptom

### WSDL opens but SOAP POST fails

Check:

1. Endpoint includes `bitrix:webservice.server` and correct `WEBSERVICE_NAME`/`WEBSERVICE_CLASS`.
2. Implementor class exists and is subclass of `IWebService`.
3. `GetWebServiceDesc()` returns valid `classes`, `structTypes`, `classTypes` arrays.
4. Request is POST and does not set `directcall`.
5. No unexpected output before SOAP response; component may call `RestartBuffer()`.
6. Auth method does not trigger HTTP Basic challenge for non-browser client unexpectedly.
7. SOAPAction namespace/method matches WSDL.

### `webservice.sale` returns zeros

Check:

1. Orders exist in the date windows used by the component.
2. User has sale rights and status view permissions.
3. Status bucket maps to expected date field (`DATE`, `DATE_PAYED`, `DATE_UPDATE`).
4. Currency/site branch; runtime-test `site_id` because current core has suspicious `$arFields['SITE_ID']` usage.
5. This component is aggregate-only; it will not list orders.

### `webservice.statistic` returns empty data

Check:

1. `statistic` module is installed and traffic/events are collected.
2. Statistic rights are not `D`.
3. `STAT_LIST_TOP_SIZE` is not too small.
4. Filters by `SITE_ID` do not exclude data.
5. Performance: legacy statistic tables can be large; avoid expensive SOAP polling.

### REST app event not delivered

Check:

1. `rest` module installed and event handlers registered.
2. App/token has required scope (`sale`, `catalog`, `pay_system`, `delivery`, `cashbox`).
3. `event.bind` exists in `b_rest_event` for exact event name and handler URL.
4. If offline delivery is used, inspect `b_rest_event_offline`, `event.offline.list/get/error`.
5. For sale events check import/delete duplicate suppression in `RestManager::processEvent()`.
6. For catalog events check the event-bind class actually implements exact event through `getHandlers()`.

### REST delivery/paysystem/cashbox app left stale handlers

Check:

1. `b_sale_pay_system_rest_handlers`, `b_sale_delivery_rest_handler`, `b_sale_cashbox_rest_handler`.
2. `rest.onRestAppDelete` fired with `CLEAN=true`.
3. The app client id matches stored handler `APP_ID`.
4. Existing sale services/cashboxes still reference handler code.
5. Do not delete rows directly unless no cleanup API works and user approved data mutation.

### Catalog REST list misses rows or repeats rows

Check:

1. `start` offset and `IRestService::LIST_LIMIT`.
2. Stable `order` and filter values.
3. Iblock/catalog rights for current REST user/app.
4. Product vs offer vs service type.
5. Price type rights and selected catalog group.
6. For large sync use `batch` carefully and check per-call errors.

## Safe implementation rules

- Prefer REST discovery (`methods`, `method.get`, `scope`) before hardcoding method names/signatures.
- For SOAP services, create explicit `IWebService` implementors and keep descriptors small; do not expose arbitrary classes through `WEBSERVICE_CLASS`.
- Do not put order CRUD into `webservice.sale`; use Sale API or sale REST controllers.
- Do not put 1С/CommerceML logic into `webservice`; use `catalog.import.1c`, `catalog.export.1c`, `sale.export.1c`.
- For external payments/deliveries/cashboxes, use REST handler APIs and preserve app cleanup semantics.
- For event handlers, make idempotency explicit; REST events can retry/offline queue and sale import can suppress duplicates.
- For public endpoints, enforce HTTPS, auth, scopes, CSRF/session where applicable, and avoid logging credentials/tokens.
- Avoid direct SQL writes to `b_rest_*`, `b_sale_*_rest_handler`, order/payment/shipment/product/price/store tables unless no API exists and user explicitly approves data mutation.

## What not to do

- Do not claim `webservice.sale` is a separate module or a full sale API.
- Do not claim `webservice.statistic` provides order analytics.
- Do not confuse B24 sale integration with 1С CommerceML exchange.
- Do not expose `webservice.checkauth` or test SOAP endpoints without access/security review.
- Do not assume REST method names from memory; verify in the current core/runtime.
- Do not treat placement binding as data storage; it only embeds app UI/hooks.


---

## Source: `workflow.md`

# Bitrix Бизнес-процессы (Bizproc / Workflow) — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с бизнес-процессами, CBPRuntime, кастомными активностями, запуском BP из кода или управлением статусами.
>
> Audit note: в shop-core `/Users/igormajorov/Downloads/Telegram Desktop/bitrix-shop-core` модуль `bizproc` подтверждён, версия `26.200.0`. В каждом проекте всё равно сначала проверяй `www/bitrix/modules/bizproc`; без модуля этот файл остаётся условным reference. Для shop automation слоя (`bizproc`, `bizprocdesigner`, legacy `workflow`, `lists`, `pull`) сначала открывай `shop-automation-bizproc.md`, а этот файл используй как общий API-oriented bizproc reference.

## Содержание
- Архитектура: CBPRuntime, IBPActivity, Document
- Запуск БП из кода
- CBPDocument::GetDocumentType()
- Создание кастомного действия (IBPActivity)
- Кастомное условие (IBPCondition)
- Статусы БП
- Получить запущенные БП для документа
- Завершить/остановить БП
- Автозапуск через событие инфоблока
- Gotchas

---

## Архитектура

**CBPRuntime** — движок выполнения бизнес-процессов. Управляет жизненным циклом: запуск, приостановка (при ожидании задачи), возобновление, завершение.

**IBPActivity** — интерфейс активности (действия). Каждый шаг процесса — это активность. Базовый класс — `CBPActivity`.

**IBPWorkflowDocument** — интерфейс документа. Каждая сущность, с которой работает BP, должна реализовывать этот интерфейс через класс-документ.

**$documentType** — тройка `[MODULE_ID, DOCUMENT_CLASS, DOCUMENT_ID_PREFIX]`:
```php
// Для элементов инфоблока
$documentType = ['iblock', 'Bitrix\\Iblock\\Integration\\Bizproc\\Document\\Element', 'iblock_5'];
//                MODULE_ID   DOCUMENT_CLASS                                            DOCUMENT_ID_PREFIX
// iblock_5 = инфоблок с ID=5
// DocumentId (конкретный элемент) = 'iblock_5|' . $elementId
```

---

## Запуск БП из кода

```php
use Bitrix\Main\Loader;

Loader::includeModule('bizproc');
Loader::includeModule('iblock');

// ID шаблона БП (b_bp_workflow_template.ID)
$templateId = 10;

// Тип документа — инфоблок 5
$documentType = [
    'iblock',
    'Bitrix\\Iblock\\Integration\\Bizproc\\Document\\Element',
    'iblock_5',
];

// ID документа — конкретный элемент
$documentId = 'iblock_5|' . $elementId;

// Параметры запуска (соответствуют параметрам шаблона)
$startParams = [
    'TargetUser'    => 'user_' . $userId,  // ID пользователя с префиксом
    'Comment'       => 'Запущено из кода',
    'ApproveStatus' => 'waiting',
];

$errors = [];
$runtime = CBPRuntime::GetRuntime(true); // true = инициализировать если не запущен
$runtime->StartWorkflow(
    $templateId,
    $documentType,
    $documentId,
    $startParams,
    $errors,
    []  // дополнительные параметры (eventData)
);

if (!empty($errors)) {
    foreach ($errors as $error) {
        // ['code' => ..., 'message' => '...', 'file' => '...']
        error_log('BP error: ' . $error['message']);
    }
}

// Получить все шаблоны для типа документа
$templates = CBPWorkflowTemplateLoader::GetList(
    ['ID' => 'ASC'],
    ['DOCUMENT_TYPE' => $documentType],
    false, false,
    ['ID', 'NAME', 'AUTO_EXECUTE']
);
while ($tmpl = $templates->Fetch()) {
    // AUTO_EXECUTE: 0=вручную, 1=при добавлении, 2=при редактировании, 3=оба
}
```

---

## CBPDocument::GetDocumentType()

```php
Loader::includeModule('bizproc');
Loader::includeModule('iblock');

// Получить documentType для конкретного элемента инфоблока
$iblockId = 5;
$elementId = 100;

$documentType = CBPDocument::GetDocumentType(
    'iblock',                                                           // module_id
    'Bitrix\\Iblock\\Integration\\Bizproc\\Document\\Element',         // documentClass
    'iblock_' . $iblockId . '|' . $elementId                          // documentId
);
// вернёт: ['iblock', 'Bitrix\\Iblock\\...', 'iblock_5']

// Получить список типов документов модуля
$types = CBPDocument::GetDocumentTypes('iblock');
// array типов для всех инфоблоков: [['MODULE_ID', 'CLASS', 'PREFIX', 'NAME'], ...]

// Получить данные документа через Document API
$docData = CBPDocument::GetDocument(
    'iblock',
    'Bitrix\\Iblock\\Integration\\Bizproc\\Document\\Element',
    'iblock_5|100'
);
// ассоциативный массив полей элемента с типами документа
```

---

## Создание кастомного действия (IBPActivity)

```php
// Файл: local/modules/vendor.mymodule/lib/activity/sendnotification.php
// Namespace: Vendor\Mymodule\Activity\SendNotification
// Регистрация: в install/index.php через CBPActivity::RegisterActivity()

namespace Vendor\Mymodule\Activity;

use CBPActivity;
use CBPActivityExecutionStatus;
use CBPActivityExecutionResult;
use CBPRuntime;

class SendNotification extends CBPActivity
{
    public function __construct(string $name)
    {
        parent::__construct($name);
        $this->arProperties = [
            'Title'   => '',       // обязательное свойство — название в конструкторе
            'UserId'  => null,     // ID получателя
            'Message' => '',       // текст уведомления
        ];
    }

    // Основной метод выполнения — вызывается движком
    public function Execute(): int
    {
        // Получить значение свойства (может содержать placeholder типа {=Variable:varName})
        $userId = (int)CBPRuntime::GetRuntime()->ResolveProperty(
            $this,
            $this->UserId
        );
        $message = $this->ResolveValue($this->Message);

        if ($userId > 0) {
            // Отправить внутреннее уведомление Bitrix
            \CIMNotify::Add([
                'FROM_USER_ID' => 0,
                'TO_USER_ID'   => $userId,
                'NOTIFY_TYPE'  => IM_NOTIFY_SYSTEM,
                'NOTIFY_MODULE'=> 'vendor.mymodule',
                'NOTIFY_EVENT' => 'bp_notification',
                'NOTIFY_MESSAGE' => htmlspecialchars($message),
            ]);
        }

        // Завершить активность — перейти к следующему шагу
        $this->SetStatus(CBPActivityExecutionStatus::Closed);
        return CBPActivityExecutionResult::Succeed;
    }

    // Описание свойств для UI конструктора БП
    public static function GetPropertiesDialogValues(
        string $documentType,
        string $activityName,
        array  &$workflowTemplate,
        array  &$workflowParameters,
        array  &$workflowVariables,
        array  $currentValues,
        array  &$errors
    ): bool {
        $errors = [];

        // Получить значения из формы конструктора
        $userId  = trim($currentValues['UserId'] ?? '');
        $message = trim($currentValues['Message'] ?? '');

        if (empty($userId)) {
            $errors[] = [
                'code'    => 0,
                'parameter' => 'UserId',
                'message' => 'Не указан получатель',
            ];
        }

        if (!empty($errors)) {
            return false;
        }

        // Сохранить значения в шаблон
        $props = ['UserId' => $userId, 'Message' => $message];
        static::SetActivityPropertiesInTemplate($activityName, $props, $workflowTemplate);

        return true;
    }

    // HTML диалог настройки в конструкторе
    public static function GetPropertiesDialog(
        string $documentType,
        string $activityName,
        array  $workflowTemplate,
        array  $workflowParameters,
        array  $workflowVariables,
        array  $currentValues = []
    ): string {
        $currentActivity = null;
        static::GetCurrentActivityPropertiesFromTemplate(
            $activityName, $workflowTemplate, $currentActivity
        );

        $userId  = $currentActivity['UserId']  ?? '';
        $message = $currentActivity['Message'] ?? '';

        return '<table>
            <tr>
                <td>Получатель:</td>
                <td><input type="text" name="UserId" value="' . htmlspecialchars($userId) . '"></td>
            </tr>
            <tr>
                <td>Сообщение:</td>
                <td><textarea name="Message">' . htmlspecialchars($message) . '</textarea></td>
            </tr>
        </table>';
    }
}
```

### Регистрация кастомного действия

```php
// В install/index.php модуля в методе InstallDB()
\CBPActivity::RegisterActivity(
    'SendNotification',                         // уникальное имя
    \Vendor\Mymodule\Activity\SendNotification::class,  // полное имя класса
    'vendor.mymodule'                           // module_id
);

// Удаление при деинсталляции
\CBPActivity::UnregisterActivity('SendNotification');
```

---

## Кастомное условие (IBPCondition)

```php
// Кастомное условие для ветвления в конструкторе БП
namespace Vendor\Mymodule\Condition;

class OrderStatusCondition
{
    // Метод, который вычисляет условие — возвращает bool
    public static function Evaluate(
        string $documentType,
        string $operatorType,
        mixed  $leftValue,
        mixed  $rightValue
    ): bool {
        // $leftValue — поле документа (например, значение STATUS)
        // $operatorType — тип сравнения ('equal', 'not_equal', etc.)
        // $rightValue — значение для сравнения из настроек условия

        return match ($operatorType) {
            'equal'     => $leftValue === $rightValue,
            'not_equal' => $leftValue !== $rightValue,
            'in'        => in_array($leftValue, (array)$rightValue),
            default     => false,
        };
    }
}

// Регистрация типа условия (в install/index.php):
\CBPCondition::RegisterType(
    'OrderStatus',
    \Vendor\Mymodule\Condition\OrderStatusCondition::class,
    'Evaluate',
    'vendor.mymodule'
);
```

---

## Статусы БП

```php
Loader::includeModule('bizproc');

// Константы CBPWorkflowStatus:
// CBPWorkflowStatus::Created    = 0  — создан, не запущен
// CBPWorkflowStatus::Running    = 1  — выполняется
// CBPWorkflowStatus::Suspended  = 2  — приостановлен (ждёт задачу/таймер)
// CBPWorkflowStatus::Terminated = 3  — принудительно остановлен
// CBPWorkflowStatus::Completed  = 4  — завершён успешно
// CBPWorkflowStatus::Faulted    = 5  — завершён с ошибкой

// Получить статус конкретного экземпляра БП
$workflowId = 'abc123-...'; // GUID из b_bp_workflow_state

$state = CBPStateService::GetWorkflowState($workflowId);
// ['WORKFLOW_ID' => '...', 'STATE' => 1, 'TITLE' => '...', 'MODIFIED' => '...']

$statusCode = (int)$state['STATE'];
if ($statusCode === CBPWorkflowStatus::Running) {
    // BP в процессе выполнения
}
```

---

## Получить запущенные БП для документа

```php
Loader::includeModule('bizproc');

$documentType = [
    'iblock',
    'Bitrix\\Iblock\\Integration\\Bizproc\\Document\\Element',
    'iblock_5',
];
$documentId = 'iblock_5|100';

// Получить все БП для документа
$workflows = CBPStateService::GetWorkflows($documentType, $documentId);
// array: [['WORKFLOW_ID' => '...', 'STATE' => 1, 'TEMPLATE_ID' => 10, ...], ...]

foreach ($workflows as $wf) {
    echo $wf['WORKFLOW_ID'] . ': ' . $wf['STATE'];
}

// Получить только активные (Running или Suspended)
$activeWorkflows = CBPStateService::GetWorkflows(
    $documentType,
    $documentId,
    [CBPWorkflowStatus::Running, CBPWorkflowStatus::Suspended]
);

// Получить задачи (Tasks) активных БП для пользователя
$tasks = CBPTaskService::GetUserTasks($userId, $documentType);
while ($task = $tasks->Fetch()) {
    // ['ID' => ..., 'WORKFLOW_ID' => '...', 'NAME' => '...', 'STATUS' => 0, ...]
}
```

---

## Завершить/остановить БП

```php
Loader::includeModule('bizproc');

$workflowId = 'abc123-...'; // GUID экземпляра

$runtime = CBPRuntime::GetRuntime(true);

// Принудительно завершить (Terminate) — статус → Terminated
$errors = [];
$runtime->TerminateWorkflow($workflowId, null, $errors);

if (!empty($errors)) {
    foreach ($errors as $err) {
        error_log('Terminate error: ' . $err['message']);
    }
}

// Завершить с кастомным сообщением (причина завершения)
$runtime->TerminateWorkflow($workflowId, 'Отменён администратором', $errors);

// Приостановить (Suspend) — только если BP поддерживает
// CBPRuntime не имеет метода Suspend напрямую — управляется через активность CBPDelayActivity
// Для принудительной остановки используй TerminateWorkflow

// Очистить завершённые БП (обслуживание)
CBPStateService::DeleteWorkflows(['STATE' => CBPWorkflowStatus::Completed]);
```

---

## Автозапуск через событие инфоблока

```php
// Шаблон БП с AUTO_EXECUTE = 1 запускается автоматически при добавлении элемента.
// Под капотом ядро вешает обработчик на OnAfterIBlockElementAdd.

// Ручная имитация автозапуска (если нужен контроль):
use Bitrix\Main\EventManager;

EventManager::getInstance()->addEventHandler(
    'iblock',
    'OnAfterIBlockElementAdd',
    function(array &$fields) {
        if ((int)$fields['IBLOCK_ID'] !== 5) {
            return;
        }

        if (!\Bitrix\Main\Loader::includeModule('bizproc')) {
            return;
        }

        $documentType = [
            'iblock',
            'Bitrix\\Iblock\\Integration\\Bizproc\\Document\\Element',
            'iblock_5',
        ];
        $documentId = 'iblock_5|' . (int)$fields['ID'];

        // Запустить все шаблоны с AUTO_EXECUTE=1 для этого инфоблока
        CBPDocument::AutoStartWorkflows(
            $documentType,
            $documentId,
            CBPDocumentEventType::Create, // Create / Edit
            []
        );
    }
);
```

---

## Gotchas

- **`Loader::includeModule('bizproc')`** обязателен. Без него `CBPRuntime`, `CBPStateService`, `CBPDocument` и все активности не определены.
- **`$documentType` — тройка, не строка**: `['iblock', 'Bitrix\\Iblock\\...', 'iblock_5']`. Неправильный формат — тихая ошибка при запуске без исключения.
- **`$documentId` — строка `'iblock_5|100'`**, не число. Первая часть = `$documentType[2]`, вторая = ID элемента через `|`.
- **Документ должен реализовывать `IBPWorkflowDocument`**: для стандартных инфоблоков это `Bitrix\Iblock\Integration\Bizproc\Document\Element`. Для кастомных сущностей нужно реализовывать интерфейс самостоятельно.
- **`CBPRuntime::GetRuntime(true)`** — вызывай с `true` (инициализация). Без аргумента или с `false` вернёт runtime который может быть не готов, и `StartWorkflow` упадёт.
- **Ошибки не исключения**: `StartWorkflow()` и `TerminateWorkflow()` пишут ошибки в переданный по ссылке `$errors[]`. Всегда проверяй этот массив.
- **Шаблон БП привязан к типу документа**: шаблон для `iblock_5` не будет виден/работать для `iblock_6`. Это намеренное поведение — `DOCUMENT_TYPE[2]` должен совпадать.
- **`CBPActivity::RegisterActivity()`** нужно вызывать при каждой установке модуля — данные хранятся в `b_bp_activity`. При деинсталляции — `UnregisterActivity()`.
- **Задачи BP (`CBPTaskService`)** не удаляются автоматически при `TerminateWorkflow` — их нужно закрывать отдельно или они остаются "висящими" в `b_bp_task`.
- **`AUTO_EXECUTE`** в шаблоне: `0` = вручную, `1` = при добавлении, `2` = при редактировании, `3` = оба. Значение `3` = бинарный OR: `1|2`.
- **Производительность**: не запускай BP синхронно в массовых операциях — каждый `StartWorkflow()` делает несколько запросов к БД. Используй очереди или агенты.


---

## Source: `push-pull.md`

# Bitrix Push & Pull — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с real-time уведомлениями, Push&Pull, WebSocket, отправкой событий из PHP в браузер или настройкой каналов.
>
> Audit note: в shop-core `/Users/igormajorov/Downloads/Telegram Desktop/bitrix-shop-core` модуль `pull` подтверждён, версия `25.300.0`. В каждом проекте всё равно сначала проверяй `www/bitrix/modules/pull`; без модуля этот файл остаётся условным reference. Для shop automation/realtime связки сначала открывай `shop-automation-bizproc.md`, а этот файл используй для общего push/pull API и transport diagnostics.

## Содержание
- Архитектура Push&Pull
- Отправка события из PHP: Event::add()
- Отправка нескольким пользователям
- Broadcast на канал (CPullChannel)
- JS-сторона: BX.PULL.subscribe, getStatus, reconnect
- Регистрация канала и онлайн-статус
- Отладка
- Gotchas

---

## Архитектура Push & Pull

Bitrix Push&Pull — система доставки событий из PHP-кода в браузер в реальном времени.

**Транспорты** (выбираются автоматически по приоритету):
1. **WebSocket** — постоянное соединение, наименьшая задержка. Требует Push-сервер (nginx + модуль).
2. **SSE (Server-Sent Events)** — однонаправленный стриминг. Fallback при недоступности WS.
3. **Long Polling** — периодические HTTP-запросы. Работает всегда, самый надёжный fallback.

**Каналы** — именованные очереди событий. Каждый пользователь слушает свой персональный канал. Broadcast-каналы позволяют слать события группе пользователей.

**Поток данных:**
```
PHP: \Bitrix\Pull\Event::add($userId, $payload)
  → запись в b_pull_stack (MySQL) или Redis
  → Push-сервер / long-polling polling endpoint читает стек
  → доставляет в браузер через WS/SSE/LP
  → BX.PULL.subscribe callback вызывается в JS
```

---

## Отправка события из PHP

```php
use Bitrix\Main\Loader;

Loader::includeModule('pull');

// Отправить событие конкретному пользователю
\Bitrix\Pull\Event::add($userId, [
    'module_id' => 'vendor.mymodule',   // ваш модуль-отправитель
    'command'   => 'order_status_changed', // произвольная строка, обрабатывается на JS
    'params'    => [                    // данные события — только простой массив
        'order_id' => 123,
        'status'   => 'shipped',
        'message'  => 'Заказ отправлен',
    ],
    'extra'     => \CPullStack::AddByUser($userId), // необязательно, дополнительные мета
]);

// Минимальный вариант
\Bitrix\Pull\Event::add($userId, [
    'module_id' => 'vendor.mymodule',
    'command'   => 'ping',
    'params'    => ['ts' => time()],
]);
```

### Отправка нескольким пользователям

```php
Loader::includeModule('pull');

// Массив userId — разошлёт каждому в его персональный канал
$userIds = [1, 5, 12, 47];

\Bitrix\Pull\Event::add($userIds, [
    'module_id' => 'vendor.mymodule',
    'command'   => 'new_message',
    'params'    => [
        'from_user_id' => $senderId,
        'text'         => 'Привет всем!',
        'chat_id'      => $chatId,
    ],
]);

// Через CPullStack напрямую (legacy-способ, аналогичен Event::add)
CPullStack::AddByUsers($userIds, [
    'module_id' => 'vendor.mymodule',
    'command'   => 'new_message',
    'params'    => ['text' => 'Привет'],
]);
```

---

## Broadcast на канал (CPullChannel)

```php
Loader::includeModule('pull');

// Создать публичный канал (broadcast)
$channelId = 'my_custom_channel_' . $someEntityId;

// Подписать пользователя на канал
CPullChannel::AddUserToDemoChannel($userId, $channelId);

// Отправить событие в канал (получат все подписанные пользователи)
CPullStack::AddByChannel($channelId, [
    'module_id' => 'vendor.mymodule',
    'command'   => 'channel_event',
    'params'    => ['data' => 'payload'],
]);

// Получить ID канала пользователя (для передачи на клиент)
$channelToken = CPullChannel::GetChannelToken($userId);

// Зарегистрировать канал в системе (необходимо для публичных каналов)
CPullChannel::Register(
    $userId,        // владелец
    $channelId,     // уникальный ID
    3600,           // TTL в секундах
    false           // false = приватный, true = публичный
);
```

---

## JS-сторона

### Подписка на события

```javascript
// Убедись, что BX.PULL инициализирован (загружается с ядром Bitrix)
// В компоненте подключи расширение: \Bitrix\Main\UI\Extension::load('pull.client');

BX.PULL.subscribe({
    moduleId: 'vendor.mymodule',    // module_id из PHP Event::add
    callback: function(data) {
        // data.command   — строка команды
        // data.params    — объект с параметрами
        // data.extra     — дополнительные мета-данные

        if (data.command === 'order_status_changed') {
            console.log('Статус заказа:', data.params.status);
            // обновить UI
        }

        if (data.command === 'new_message') {
            BX.onCustomEvent('onNewMessage', [data.params]);
        }
    }
});

// Подписка с явным указанием типа события (D7 Pull Client)
BX.PULL.subscribe({
    type: BX.PullClient.SubscriptionType.Server, // Server | Shared | Online
    moduleId: 'vendor.mymodule',
    callback: function(data) { /* ... */ }
});
```

### Статус соединения и управление

```javascript
// Получить текущий статус соединения
const status = BX.PULL.getStatus();
// Возможные значения: 'online', 'offline', 'connecting', 'unknown'

// Принудительное переподключение (например, после восстановления сети)
BX.PULL.reconnect();

// Проверить, подключён ли Pull
if (BX.PULL.isConnected()) {
    console.log('Pull подключён');
}

// Событие смены статуса
BX.PULL.subscribe({
    type: BX.PullClient.SubscriptionType.Status,
    callback: function(data) {
        // data.status: 'online' | 'offline' | 'connecting'
        if (data.status === 'offline') {
            // показать индикатор отсутствия соединения
        }
    }
});

// Событие онлайн-статуса других пользователей
BX.PULL.subscribe({
    type: BX.PullClient.SubscriptionType.Online,
    callback: function(data) {
        // data.userId   — ID пользователя
        // data.online   — true/false
        console.log('User', data.userId, 'is', data.online ? 'online' : 'offline');
    }
});
```

---

## Регистрация канала и управление онлайн-статусом

```php
Loader::includeModule('pull');

// Онлайн-статус: обновить время последней активности пользователя
CPullOnline::SetOnline($userId, SITE_ID);

// Получить онлайн-пользователей сайта
$onlineUsers = CPullOnline::GetOnlineUsers(SITE_ID);
// array: [['USER_ID' => 1, 'LAST_SEEN' => timestamp], ...]

// Проверить онлайн-статус конкретного пользователя
$isOnline = CPullOnline::IsOnline($userId, SITE_ID);
// bool — онлайн если активен в последние ~60 секунд

// Зарегистрировать обработчик Pull-команд в модуле (в install/index.php)
// Bitrix вызовет OnPullEvent когда придёт событие для модуля
EventManager::getInstance()->registerEventHandler(
    'pull', 'OnPullEvent',
    'vendor.mymodule',
    \Vendor\Mymodule\PullHandler::class,
    'onPullEvent'
);
```

```php
// Пример обработчика OnPullEvent
namespace Vendor\Mymodule;

class PullHandler
{
    public static function onPullEvent(string $moduleId, string $command, array $params): void
    {
        if ($moduleId !== 'vendor.mymodule') {
            return;
        }
        // обработать команду от клиента (если используется двусторонняя связь)
    }
}
```

---

## Подключение расширения в PHP-компоненте

```php
// В component.php или template/template.php — подключить Pull JS-клиент
\Bitrix\Main\UI\Extension::load('pull.client');

// Или через Asset Manager (legacy)
\CJSCore::Init(['pull', 'pull_status', 'pull_client']);

// Передать токен канала в JS через CUtil::InitJSCore()
// (токен генерируется автоматически для авторизованных пользователей)
```

---

## Отладка

### Параметр `?LISTEN_JS_REVISION` в URL

Добавь `?LISTEN_JS_REVISION=1` к любому URL Bitrix-страницы чтобы увидеть в консоли браузера:
- текущую JS-ревизию Pull-клиента
- параметры соединения (транспорт, канал, сервер)

### Chrome DevTools — что смотреть

**Network → WS (WebSocket)**:
- ищи соединение с путём `/bitrix/tools/pull/?CHANNEL=...`
- в Frames вкладке видны все входящие и исходящие frames в реальном времени

**Network → EventStream (SSE)**:
- при SSE-транспорте ищи `GET /bitrix/tools/pull/?type=sse&...`
- в EventStream вкладке — поток событий

**Network → XHR (Long Polling)**:
- запросы к `/bitrix/tools/pull/?type=json&...`
- каждый запрос держится открытым, пока не придут данные или таймаут

**Консоль**:
```javascript
// Получить диагностику Pull-соединения
BX.PULL.getDebugInfo();

// Включить verbose-логирование
BX.PULL.setLogLevel(BX.PullClient.LogLevel.DEBUG);
```

### Отладка стека событий в PHP

```php
Loader::includeModule('pull');

// Посмотреть что лежит в стеке для пользователя (не потреблять)
$stack = CPullStack::GetStack($userId);
// array необработанных событий

// Очистить стек пользователя (осторожно в production!)
CPullStack::ClearStack($userId);

// Проверить активные каналы
$channels = CPullChannel::GetUserChannels($userId);
var_dump($channels);
```

---

## Gotchas

- **`Loader::includeModule('pull')`** обязателен перед любым использованием `\Bitrix\Pull\Event`, `CPullStack`, `CPullChannel`, `CPullOnline`. Без него классы не определены.
- **`EVENT_ID` vs `command`**: в PHP-вызове `Event::add()` поле называется `command`, не `event_id`. В JS-подписке `BX.PULL.subscribe` тоже `callback` получает `data.command`. Не путай с `EVENT_ID` из `CSocNetLog`.
- **Данные `params` должны быть простым массивом**: без объектов PHP, без вложенных классов, только скалярные значения и массивы. Данные сериализуются через `json_encode` — PHP-объекты потеряют тип.
- **Ограничение размера события**: максимальный размер `params` — около 64 КБ. При превышении событие молча отбрасывается. Для больших данных передавай только ID и загружай данные отдельным AJAX.
- **Long Polling включён всегда** как fallback — даже без Push-сервера Push&Pull работает. Push-сервер только ускоряет доставку.
- **`BX.PULL.subscribe()` без `type`** по умолчанию подписывается на `SubscriptionType.Server` — серверные события. Для онлайн-статуса используй явно `SubscriptionType.Online`.
- **Авторизованные vs анонимные**: Push&Pull работает только для авторизованных пользователей. Для анонимных нужны отдельные публичные каналы через `CPullChannel::Register()` с `$public = true`.
- **Токен канала не статичный**: он ротируется. Не кешируй токен на клиенте — получай через JS-инициализацию Bitrix.
- **В `\Bitrix\Pull\Event::add()` первый параметр** может быть `int` (один userId) или `int[]` (массив). Строки не принимаются — только целые числа.
- **SSE и Long Polling держат соединение** — не вызывай `Event::add()` в цикле с тысячами пользователей синхронно. Используй фоновые задачи (агенты, очереди) для массовой рассылки.


---

## Source: `shop-performance.md`

# Catalog/sale/shop performance — compact

Открывай только после module check `catalog`, `sale`, `currency`. Маршрут: product/offers/prices/stock → component params/cache/facet → basket/discount/order lifecycle → composite/personal blocks.

Grep:

```bash
rg -n 'catalog\.section|catalog\.element|catalog\.smart\.filter|sale\.basket|sale\.order|PRICE_CODE|OFFERS_|SKU|CML2_LINK|AVAILABLE|QUANTITY|DISCOUNT|Basket|Order|Sale\\|Catalog\\|CACHE_TYPE|CACHE_GROUPS|FACET|Facet|clearByTag' local bitrix/templates www/bitrix/templates local/components --glob '*.php'
```

Проверять в catalog list/detail: `CACHE_TYPE/TIME/GROUPS`, `PROPERTY_CODE`, `OFFERS_PROPERTY_CODE`, `PRICE_CODE`, stable sort/pagination, SKU/offers preload, image resize/lazy, `catalog.smart.filter` и facet index, composite для цен/корзины/региона.

Красные флаги: price/stock/discount calls в template loop, offers по одному товару, user/group/region price в общем cache/composite, raw SQL по `b_catalog_*`/`b_sale_*`, полный facet/search rebuild на production без окна.

Safe wins: сузить property/price lists, preload offers/prices/stock, вынести персональные blocks в dynamic area, проверить facet/search indexes, heavy recalculation/import — в stepper/CLI.
