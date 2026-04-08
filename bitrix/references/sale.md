# Модуль Sale — заказы, корзина, оплата, доставка

```php
use Bitrix\Main\Loader;
Loader::includeModule('sale');
Loader::includeModule('catalog'); // для работы с товарами
```

> Audit note: в текущем проверенном core модули `sale` и `catalog` в `www/bitrix/modules` не найдены. Этот файл сейчас отложен до установки магазинного core и не должен быть активным маршрутом в текущей фазе проекта.

## Архитектура Sale D7

```
Order (заказ)
├── Basket (корзина)
│   └── BasketItem[] (позиции)
├── PropertyCollection (свойства заказа — ФИО, адрес, телефон)
├── ShipmentCollection
│   └── Shipment[] (отправления)
│       └── ShipmentItemCollection → ShipmentItem[]
└── PaymentCollection
    └── Payment[] (оплаты)
```

---

## Корзина

### Добавить товар в корзину текущего пользователя

```php
use Bitrix\Sale\Basket;
use Bitrix\Sale\BasketItem;
use Bitrix\Main\Context;

$basket = Basket::loadItemsForFUser(
    \CSaleBasket::GetBasketUserID(), // fuser_id текущего посетителя
    SITE_ID
);

// Проверить, есть ли товар уже в корзине
$existingItem = null;
foreach ($basket as $item) {
    if ($item->getField('PRODUCT_ID') == $productId) {
        $existingItem = $item;
        break;
    }
}

if ($existingItem) {
    // Увеличить количество
    $existingItem->setField('QUANTITY', $existingItem->getQuantity() + $quantity);
} else {
    // Новая позиция
    $item = $basket->createItem('catalog', $productId);
    $item->setFields([
        'QUANTITY'   => $quantity,
        'CURRENCY'   => \Bitrix\Currency\CurrencyManager::getBaseCurrency(),
        'LID'        => SITE_ID,
        'PRODUCT_ID' => $productId,
        'NAME'       => $productName,
        'PRICE'      => $price,
        'PRODUCT_PROVIDER_CLASS' => '\CCatalogProductProvider',
    ]);
}

$result = $basket->save();
if (!$result->isSuccess()) {
    // обработка ошибок
}
```

### Получить корзину

```php
$fUserId = \CSaleBasket::GetBasketUserID();
$basket  = Basket::loadItemsForFUser($fUserId, SITE_ID);

$total   = $basket->getPrice();    // итоговая сумма с учётом скидок
$weight  = $basket->getWeight();   // вес

foreach ($basket as $item) {
    $productId = $item->getProductId();
    $name      = $item->getField('NAME');
    $quantity  = $item->getQuantity();
    $price     = $item->getPrice();       // цена за единицу
    $finalPrice = $item->getFinalPrice(); // с учётом скидок
}
```

### Удалить позицию из корзины

```php
foreach ($basket as $item) {
    if ($item->getProductId() == $productId) {
        $item->delete();
        break;
    }
}
$basket->save();
```

---

## Заказы

### Создать заказ из корзины

```php
use Bitrix\Sale\Order;
use Bitrix\Sale\Basket;
use Bitrix\Sale\Delivery;
use Bitrix\Sale\PaySystem;

$userId = (int)$GLOBALS['USER']->GetID();

// 1. Создать заказ
$order = Order::create(SITE_ID, $userId);
$order->setPersonTypeId(1); // 1 — физ.лицо, 2 — юр.лицо (зависит от настроек)

// 2. Привязать корзину
$basket = Basket::loadItemsForFUser(\CSaleBasket::GetBasketUserID(), SITE_ID);
$order->setBasket($basket);

// 3. Свойства заказа (ФИО, телефон, адрес и т.д.)
$propertyCollection = $order->getPropertyCollection();
foreach ($propertyCollection as $prop) {
    $code = $prop->getField('CODE');
    if ($code === 'NAME') {
        $prop->setValue('Иван Иванов');
    } elseif ($code === 'EMAIL') {
        $prop->setValue('ivan@example.com');
    } elseif ($code === 'PHONE') {
        $prop->setValue('+79991234567');
    }
}

// 4. Доставка
$shipmentCollection = $order->getShipmentCollection();
$shipment = $shipmentCollection->createItem();

$deliveryService = Delivery\Services\Manager::getById(1); // ID службы доставки
$shipment->setFields([
    'DELIVERY_ID'   => $deliveryService['ID'],
    'DELIVERY_NAME' => $deliveryService['NAME'],
    'CURRENCY'      => $order->getCurrency(),
    'PRICE_DELIVERY'=> 300.00,
]);

// Перенести позиции корзины в отправление
$shipmentItemCollection = $shipment->getShipmentItemCollection();
foreach ($basket as $basketItem) {
    $shipmentItem = $shipmentItemCollection->createItem($basketItem);
    $shipmentItem->setQuantity($basketItem->getQuantity());
}

// 5. Оплата
$paymentCollection = $order->getPaymentCollection();
$payment = $paymentCollection->createItem();

$paySystemService = PaySystem\Manager::getById(1); // ID платёжной системы
$payment->setFields([
    'PAY_SYSTEM_ID'   => $paySystemService['ID'],
    'PAY_SYSTEM_NAME' => $paySystemService['NAME'],
    'SUM'             => $order->getPrice(),
    'CURRENCY'        => $order->getCurrency(),
]);

// 6. Сохранить
$result = $order->save();
if ($result->isSuccess()) {
    $orderId = $order->getId();
} else {
    $errors = $result->getErrorMessages();
}
```

### Получить заказ

```php
use Bitrix\Sale\Order;

$order = Order::load($orderId);

if ($order) {
    $userId   = $order->getUserId();
    $status   = $order->getField('STATUS_ID');   // N, P, F и т.д.
    $price    = $order->getPrice();              // сумма
    $currency = $order->getCurrency();
    $paid     = $order->isPaid();                // bool
    $canceled = $order->isCanceled();            // bool

    // Свойства
    $propCollection = $order->getPropertyCollection();
    $email = $propCollection->getUserEmail();    // специальный метод
    $name  = $propCollection->getPayerName();
    $phone = $propCollection->getPhone();
}
```

### Список заказов через ORM

```php
use Bitrix\Sale\Internals\OrderTable;

$result = OrderTable::getList([
    'select' => ['ID', 'USER_ID', 'PRICE', 'CURRENCY', 'STATUS_ID', 'DATE_INSERT'],
    'filter' => [
        '=USER_ID'   => $userId,
        '=STATUS_ID' => ['N', 'P'],   // новые и оплаченные
    ],
    'order'  => ['DATE_INSERT' => 'DESC'],
    'limit'  => 20,
]);
while ($row = $result->fetch()) { ... }
```

### Изменить статус заказа

```php
use Bitrix\Sale\Order;

$order = Order::load($orderId);
$order->setField('STATUS_ID', 'F'); // F = завершён
$result = $order->save();
```

### Отменить заказ

```php
$order = Order::load($orderId);
$order->setField('CANCELED', 'Y');
$order->setField('REASON_CANCELED', 'Отказ клиента');
$order->save();
```

---

## Оплата (Payment)

### Отметить платёж как оплаченный

```php
use Bitrix\Sale\Order;

$order = Order::load($orderId);
$paymentCollection = $order->getPaymentCollection();

foreach ($paymentCollection as $payment) {
    if (!$payment->isPaid()) {
        $result = $payment->setPaid('Y');
        if ($result->isSuccess()) {
            $order->save();
        }
    }
}
```

### Статусы Payment

| Метод | Описание |
|-------|---------|
| `$payment->isPaid()` | оплачен |
| `$payment->getSum()` | сумма платежа |
| `$payment->getField('PAY_SYSTEM_ID')` | ID платёжной системы |
| `$payment->getField('DATE_PAID')` | дата оплаты |

---

## Скидки и купоны

### Применить купон к заказу

```php
use Bitrix\Sale\DiscountCouponsManager;

// Добавить купон (привязывается к fuser)
$result = DiscountCouponsManager::add($couponCode);
if (!$result) {
    // неверный купон
}

// Применяется автоматически при расчёте заказа через Order::refreshData()
```

### Проверить купон вручную

```php
use Bitrix\Sale\Discount\Discount;

$couponInfo = \CSaleDiscount::GetCoupon($couponCode, SITE_ID);
// $couponInfo['ID'], ['DISCOUNT_ID'], ['TYPE'] (1=один раз, 2=многократно, 3=на одного)
```

---

## События Sale

Регистрация в `include.php` модуля:

```php
use Bitrix\Main\EventManager;

// Перед сохранением заказа
EventManager::getInstance()->addEventHandler('sale', 'OnSaleOrderBeforeSaved', [\My\Handler::class, 'onBeforeSave']);

// После сохранения заказа
EventManager::getInstance()->addEventHandler('sale', 'OnSaleOrderSaved', [\My\Handler::class, 'onSaved']);

// Смена статуса
EventManager::getInstance()->addEventHandler('sale', 'OnSaleStatusOrder', [\My\Handler::class, 'onStatus']);

// Оплата
EventManager::getInstance()->addEventHandler('sale', 'OnSalePaymentPaid', [\My\Handler::class, 'onPaid']);
```

```php
// Обработчик
class Handler
{
    public static function onSaved(\Bitrix\Main\Event $event): void
    {
        /** @var \Bitrix\Sale\Order $order */
        $order  = $event->getParameter('ENTITY');
        $isNew  = $event->getParameter('IS_NEW');   // bool — новый заказ?
        $values = $event->getParameter('VALUES');    // изменённые поля

        $orderId = $order->getId();
    }
}
```

### Ключевые события

| Событие | Когда |
|---------|-------|
| `OnSaleOrderBeforeSaved` | перед сохранением (можно отменить) |
| `OnSaleOrderSaved` | после сохранения |
| `OnSaleStatusOrder` | смена статуса заказа |
| `OnSalePaymentPaid` | заказ отмечен как оплаченный |
| `OnSaleBasketItemSaved` | сохранение позиции корзины |
| `OnSaleShipmentSaved` | сохранение отправления |

---

## Legacy API (встречается в старых проектах)

```php
// Получить список заказов пользователя
$res = CSaleOrder::GetList(
    ['ID' => 'DESC'],
    ['USER_ID' => $userId, 'STATUS_ID' => 'N'],
    false,
    ['nPageSize' => 20]
);
while ($order = $res->GetNext()) {
    echo $order['ID'] . ' — ' . $order['PRICE'];
}

// Изменить статус
CSaleOrder::StatusOrder($orderId, 'F');

// Отменить
CSaleOrder::CancelOrder($orderId, 'Y', 'Причина');
```

---

## Gotchas

- `Order::create` не сохраняет — нужен явный `$order->save()`
- При добавлении товара в корзину обязательно указывай `PRODUCT_PROVIDER_CLASS` — без него не будет проверки остатков и расчёта скидок
- `$basket->getPrice()` возвращает цену **с учётом скидок** — только после `$order->doFinalAction(true)` пересчитываются скидки заказа
- `isPaid()` на Order проверяет **все** платежи. Если один из нескольких платежей не оплачен — `isPaid()` = false
- `PersonType` (физ/юр. лицо) влияет на набор свойств заказа — всегда проверяй какие типы настроены на сайте
