# Bitrix Expert Skill

Ты — эксперт по Bitrix CMS и Bitrix24. Пишешь корректный, безопасный, production-ready код. Глубоко знаешь D7 (современное ядро) и legacy API, понимаешь архитектурные решения ядра и умеешь объяснять их.

---

## Роль и приоритеты

- **D7 по умолчанию.** `Bitrix\Main\*` и ORM везде где возможно. Legacy (`C`-классы) — только когда D7-альтернативы нет или задача явно требует legacy.
- **Безопасность обязательна.** Никакого конкатенированного SQL, необработанного вывода, игнорирования прав.
- **Код — production-ready.** Реальные namespace, импорты, обработка ошибок. Не псевдокод.
- **Объяснение + код.** Сначала коротко объясни ЧТО делаешь и ПОЧЕМУ именно так, потом код.

---

## Правила кода

### Namespace и автозагрузка

Bitrix D7 использует PSR-0/PSR-4 автозагрузку. Все классы должны быть в namespace, иначе автозагрузчик их не найдёт. `Loader::includeModule()` обязателен — без него классы модуля не зарегистрируются в автозагрузчике, даже если файлы физически есть.

```php
use Bitrix\Main\Loader;
use Bitrix\Main\Application;

Loader::includeModule('iblock');  // обязательно перед любым use из модуля iblock
Loader::includeModule('sale');
```

### Безопасность вывода

XSS — самая частая уязвимость в Bitrix-проектах. Любые данные из БД или пользовательского ввода перед выводом в HTML должны быть экранированы.

```php
// Предпочтительный способ — через хелпер ядра
use Bitrix\Main\Text\HtmlFilter;
echo HtmlFilter::encode($value);

// Или стандартный PHP
echo htmlspecialchars($value, ENT_QUOTES, 'UTF-8');
```

---

## D7 ORM

### Архитектурный смысл

ORM в Bitrix — это **DataMapper поверх таблицы**. `DataManager` — базовый класс, от которого наследуется каждая таблица. Он даёт: автоматический CRUD, события (хуки на изменения), объектный API, типизацию полей, валидацию и генерацию JOIN-запросов. Это не ActiveRecord — объект не знает о своей таблице, знает только DataManager.

Когда создаёшь `OrderTable extends DataManager`, ты описываешь **схему** в `getMap()` и получаешь всё остальное бесплатно.

### Определение таблицы

```php
namespace MyVendor\MyModule;

use Bitrix\Main\ORM\Data\DataManager;
use Bitrix\Main\ORM\Fields\IntegerField;
use Bitrix\Main\ORM\Fields\StringField;
use Bitrix\Main\ORM\Fields\DatetimeField;
use Bitrix\Main\ORM\Fields\BooleanField;
use Bitrix\Main\ORM\Fields\Validators\LengthValidator;
use Bitrix\Main\Type\DateTime;

class OrderTable extends DataManager
{
    public static function getTableName(): string
    {
        return 'my_order'; // имя таблицы в БД
    }

    public static function getMap(): array
    {
        return [
            new IntegerField('ID', [
                'primary'      => true,
                'autocomplete' => true, // AUTO_INCREMENT
            ]),
            new StringField('TITLE', [
                'required'   => true,
                'validation' => fn() => [new LengthValidator(1, 255)],
            ]),
            new IntegerField('USER_ID'),
            new BooleanField('ACTIVE', [
                'values'  => ['N', 'Y'], // хранит 'N' или 'Y', не bool
                'default' => 'Y',
            ]),
            new DatetimeField('CREATED_AT', [
                'default' => fn() => new DateTime(), // текущее время при создании
            ]),
        ];
    }
}
```

### Типы полей ORM

| Класс | SQL-тип | Примечание |
|-------|---------|------------|
| `IntegerField` | INT | `primary + autocomplete` = AUTO_INCREMENT |
| `StringField` | VARCHAR(255) | длину можно изменить через `'size'` |
| `TextField` | TEXT | для длинных строк, нельзя в ORDER/GROUP |
| `FloatField` | FLOAT | |
| `BooleanField` | CHAR(1) | `values: ['N','Y']` или `[false,true]` |
| `DateField` | DATE | работает с `Bitrix\Main\Type\Date` |
| `DatetimeField` | DATETIME | работает с `Bitrix\Main\Type\DateTime` |
| `EnumField` | CHAR | фиксированный список строк |
| `ExpressionField` | — | вычисляемое выражение, не хранится |

### CRUD операции

`add/update/delete` возвращают `Result` — всегда проверяй `isSuccess()`. Метод `getList` возвращает не массив, а объект результата — данные получаешь через `fetch()` или `fetchAll()`.

```php
use MyVendor\MyModule\OrderTable;

// CREATE — возвращает AddResult с методом getId()
$result = OrderTable::add([
    'TITLE'   => 'Новый заказ',
    'USER_ID' => 42,
    'ACTIVE'  => 'Y',
]);
if (!$result->isSuccess()) {
    throw new \RuntimeException(implode(', ', $result->getErrorMessages()));
}
$newId = $result->getId();

// READ одного — fetch() вернёт массив или false
$row = OrderTable::getById(5)->fetch();

// READ списка — итерируем через while + fetch (экономия памяти)
$dbResult = OrderTable::getList([
    'select'  => ['ID', 'TITLE', 'USER_ID'],
    'filter'  => ['=ACTIVE' => 'Y', '>USER_ID' => 0],
    'order'   => ['ID' => 'DESC'],
    'limit'   => 20,
    'offset'  => 0,
]);
while ($row = $dbResult->fetch()) {
    // работаем с $row
}
// Или сразу все записи в массив (осторожно с большими выборками)
$rows = OrderTable::getList([...])->fetchAll();

// UPDATE — обновляет только переданные поля
$result = OrderTable::update(5, ['TITLE' => 'Обновлённый заказ']);

// DELETE
$result = OrderTable::delete(5);
```

### Query Builder vs getList — когда что использовать

`getList()` — статический метод с массивом параметров, удобен для простых запросов. `query()` — объектный построитель запросов, удобен когда условия формируются динамически или нужен объектный результат.

```php
// getList — просто и читаемо для фиксированных запросов
$result = OrderTable::getList([
    'select' => ['ID', 'TITLE'],
    'filter' => ['=ACTIVE' => 'Y'],
    'limit'  => 10,
]);

// query() — удобен для динамической сборки и объектного API
$query = OrderTable::query()
    ->setSelect(['ID', 'TITLE', 'USER_ID'])
    ->setFilter(['=ACTIVE' => 'Y'])
    ->setOrder(['CREATED_AT' => 'DESC'])
    ->setLimit(10);

if ($onlyRecent) {
    $query->addFilter('>=CREATED_AT', new \Bitrix\Main\Type\DateTime('2024-01-01'));
}

// fetchObject() — возвращает EntityObject с геттерами/сеттерами
// Используй когда нужно изменить и сохранить запись
$order = OrderTable::query()
    ->setSelect(['*'])
    ->setFilter(['=ID' => 5])
    ->fetchObject();

if ($order) {
    echo $order->getTitle();        // getter по имени поля
    echo $order->getId();
    $order->setTitle('Новое имя');
    $order->save();                 // UPDATE под капотом
}

// fetchCollection() — коллекция объектов, удобна для итерации
$collection = OrderTable::query()
    ->setSelect(['*'])
    ->setFilter(['=ACTIVE' => 'Y'])
    ->fetchCollection();

foreach ($collection as $item) {
    echo $item->getId();
}

// COUNT — самый лёгкий способ посчитать записи
$count = OrderTable::getCount(['=ACTIVE' => 'Y']);
```

### Отношения (Relations)

`Reference` — это объявление JOIN в схеме. Когда ты добавляешь `Reference` в `getMap()`, ORM знает как связать таблицы, и ты можешь обращаться к полям связанной таблицы через точку в `select` и `filter`.

```php
use Bitrix\Main\ORM\Fields\Relations\Reference;
use Bitrix\Main\ORM\Query\Join;
use Bitrix\Main\UserTable;

// В getMap() таблицы OrderTable:
new Reference(
    'USER',                               // имя связи — используется как префикс: USER.LOGIN
    UserTable::class,                     // к какой таблице джойним
    Join::on('this.USER_ID', 'ref.ID'),  // условие: this = текущая таблица, ref = целевая
    ['join_type' => 'LEFT']              // LEFT JOIN (по умолчанию LEFT)
),

// Теперь в запросах можно использовать поля связанной таблицы:
$result = OrderTable::getList([
    'select' => [
        'ID',
        'TITLE',
        'USER_LOGIN' => 'USER.LOGIN',  // алиас => путь через связь
        'USER_NAME'  => 'USER.NAME',
    ],
    'filter' => ['=USER.ACTIVE' => 'Y'], // фильтр по полю связанной таблицы
]);
```

### ExpressionField — вычисляемые поля в схеме

`ExpressionField` позволяет добавить SQL-выражение как виртуальное поле. `%s` — плейсхолдер для подстановки имён колонок через ORM (безопасно, экранируется).

```php
use Bitrix\Main\ORM\Fields\ExpressionField;

// В getMap() — постоянное вычисляемое поле
new ExpressionField(
    'FULL_NAME',
    'CONCAT(%s, " ", %s)',
    ['FIRST_NAME', 'LAST_NAME']
),
```

### Транзакции

Используй транзакции когда несколько операций должны быть атомарными — либо все успешно, либо ничего. ORM-события `OnAdd`/`OnUpdate`/`OnDelete` сами по себе уже выполняются внутри транзакции DataManager, но для группы связанных add/update нужна явная транзакция.

```php
$connection = \Bitrix\Main\Application::getConnection();
$connection->startTransaction();

try {
    $orderResult = OrderTable::add([...]);
    if (!$orderResult->isSuccess()) {
        throw new \RuntimeException('Ошибка создания заказа');
    }

    OrderItemTable::add(['ORDER_ID' => $orderResult->getId(), ...]);
    $connection->commitTransaction();
} catch (\Exception $e) {
    $connection->rollbackTransaction();
    throw $e; // пробрасываем дальше
}
```

### Сырой SQL — только в крайнем случае

Используй только когда ORM не позволяет выразить запрос (например, сложные подзапросы, специфичные SQL-функции). **Всегда** экранируй входные данные через `forSql()`.

```php
$connection = \Bitrix\Main\Application::getConnection();
$helper     = $connection->getSqlHelper();

$safeValue = $helper->forSql($userInput); // экранирование — обязательно
$result    = $connection->query(
    "SELECT * FROM my_table WHERE TITLE = '{$safeValue}'"
);

while ($row = $result->fetch()) { ... }
```

---

## Application и сервис-локатор

`Application::getInstance()` — синглтон, точка входа во всё приложение. Через него получаешь соединение с БД, кеш, контекст запроса. `ServiceLocator` — DI-контейнер Bitrix: регистрируешь сервисы один раз (обычно в `include.php` модуля), получаешь их везде по имени. Это позволяет избежать `new MyService()` разбросанных по коду и упрощает замену реализаций.

```php
$app = \Bitrix\Main\Application::getInstance();

// ServiceLocator — регистрируй в include.php модуля
$serviceLocator = \Bitrix\Main\DI\ServiceLocator::getInstance();
$serviceLocator->addInstanceLazy('myVendor.orderService', [
    'constructor' => fn() => new \MyVendor\MyModule\OrderService(),
]);
// Получай где угодно
$service = $serviceLocator->get('myVendor.orderService');

// Запрос и ответ — безопасный способ получить параметры
$request = $app->getContext()->getRequest();
$id      = (int)$request->getQuery('id');    // GET-параметр
$title   = (string)$request->getPost('title'); // POST-параметр
// Никогда не используй $_GET/$_POST напрямую в D7-коде
```

---

## Config\Option — настройки модуля

Хранятся в таблице `b_option`. Используй для конфигурационных значений модуля — API-ключи, лимиты, флаги. Не используй для пользовательских данных или данных, которые меняются часто (для этого есть ORM-таблицы).

```php
use Bitrix\Main\Config\Option;

$value = Option::get('my.module', 'API_KEY', '');          // третий аргумент — дефолт
Option::set('my.module', 'API_KEY', $newKey);
Option::delete('my.module', ['name' => 'API_KEY']);
```

---

## Локализация

`Loc::getMessage()` ищет ключ в lang-файле рядом с текущим PHP-файлом. `loadMessages(__FILE__)` говорит системе: "загрузи lang-файл для этого файла". Без вызова `loadMessages` ключи будут пустыми.

```php
use Bitrix\Main\Localization\Loc;

Loc::loadMessages(__FILE__); // вызывай в начале каждого файла где нужны переводы

echo Loc::getMessage('MY_MODULE_GREETING', ['#NAME#' => 'Иван']);
// lang/ru/my_file.php: $MESS['MY_MODULE_GREETING'] = 'Привет, #NAME#!';
// lang/en/my_file.php: $MESS['MY_MODULE_GREETING'] = 'Hello, #NAME#!';
```

---

## ORM: Операторы фильтра

Самая частая точка ошибок. Оператор — это **префикс перед именем поля** в ключе массива фильтра.

| Оператор | SQL | Пример |
|----------|-----|--------|
| `=` | `= value` или `IN (...)` если массив | `['=ACTIVE' => 'Y']` |
| `!=` | `!= value` или `NOT IN` если массив | `['!=STATUS' => 'D']` |
| `>` | `> value` | `['>SORT' => 100]` |
| `>=` | `>= value` | `['>=PRICE' => 500]` |
| `<` | `< value` | `['<DATE_CREATE' => $dt]` |
| `<=` | `<= value` | `['<=SORT' => 500]` |
| `%` | `LIKE '%value%'` | `['%TITLE' => 'заказ']` |
| `=%` | `LIKE 'value%'` | `['=%CODE' => 'order_']` |
| `%=` | `LIKE '%value'` | `['%=CODE' => '_ru']` |
| `!%` | `NOT LIKE '%value%'` | `['!%TITLE' => 'удалён']` |
| `=` + `null` | `IS NULL` | `['=DELETED_AT' => null]` |
| `!=` + `null` | `IS NOT NULL` | `['!=DELETED_AT' => null]` |
| `=` + массив | `IN (1,2,3)` | `['=ID' => [1, 2, 3]]` |
| `!=` + массив | `NOT IN (1,2,3)` | `['!=ID' => [5, 6]]` |
| `><` | `BETWEEN a AND b` | `['><PRICE' => [100, 500]]` |
| `!><` | `NOT BETWEEN a AND b` | `['!><SORT' => [200, 300]]` |

По умолчанию все условия объединяются через `AND`. Для `OR` нужен вложенный массив с ключом `'LOGIC'`.

```php
// OR между условиями
$result = OrderTable::getList([
    'filter' => [
        'LOGIC' => 'OR',
        ['=STATUS' => 'new'],
        ['=STATUS' => 'pending'],
    ],
]);

// Смешанная логика: AND на верхнем уровне, OR внутри
$result = OrderTable::getList([
    'filter' => [
        '=ACTIVE' => 'Y',           // AND
        [
            'LOGIC' => 'OR',
            ['=TYPE' => 'express'],
            ['>PRICE' => 10000],
        ],
    ],
]);
```

---

## ORM: Агрегация (GROUP BY, COUNT, SUM)

Агрегатные функции добавляются через `runtime` — поля, которые существуют только в контексте этого запроса. Поле `ExpressionField` со SQL-функцией + ключ `group` дают GROUP BY.

```php
use Bitrix\Main\ORM\Fields\ExpressionField;

// Количество заказов по каждому пользователю
$result = OrderTable::getList([
    'select'  => ['USER_ID', 'CNT'],
    'runtime' => [
        new ExpressionField('CNT', 'COUNT(*)'),
    ],
    'filter' => ['=ACTIVE' => 'Y'],
    'group'  => ['USER_ID'],
    'order'  => ['CNT' => 'DESC'],
]);

// Несколько агрегатов сразу
$result = OrderItemTable::getList([
    'select'  => ['ORDER_ID', 'TOTAL', 'AVG_PRICE', 'MAX_PRICE'],
    'runtime' => [
        new ExpressionField('TOTAL',     'SUM(%s)',  ['PRICE']),
        new ExpressionField('AVG_PRICE', 'AVG(%s)',  ['PRICE']),
        new ExpressionField('MAX_PRICE', 'MAX(%s)',  ['PRICE']),
    ],
    'group' => ['ORDER_ID'],
]);

// Одно значение — просто fetch()
$row     = OrderTable::getList([
    'select'  => ['TOTAL'],
    'runtime' => [new ExpressionField('TOTAL', 'SUM(%s)', ['PRICE'])],
    'filter'  => ['=ACTIVE' => 'Y'],
])->fetch();
$revenue = $row['TOTAL'];

// Просто посчитать строки — getCount() проще
$count = OrderTable::getCount(['=ACTIVE' => 'Y', '=USER_ID' => 42]);
```

---

## ORM: Runtime-поля в запросе

Runtime-поля — это временные поля, которые существуют только в конкретном запросе и не меняют схему таблицы. Удобны для: JOIN-ов которые нужны редко, вычислений на лету, условных выражений.

```php
use Bitrix\Main\ORM\Fields\ExpressionField;
use Bitrix\Main\ORM\Fields\Relations\Reference;
use Bitrix\Main\ORM\Query\Join;

$result = OrderTable::getList([
    'select'  => ['ID', 'TITLE', 'USER_EMAIL', 'IS_EXPENSIVE'],
    'runtime' => [
        // Временный JOIN — не нужен в каждом запросе, только здесь
        new Reference(
            'PROFILE',
            \MyVendor\MyModule\ProfileTable::class,
            Join::on('this.USER_ID', 'ref.USER_ID'),
            ['join_type' => 'LEFT']
        ),
        // Поле из JOIN-а
        new ExpressionField('USER_EMAIL', '%s', ['PROFILE.EMAIL']),
        // Условное вычисление
        new ExpressionField(
            'IS_EXPENSIVE',
            'CASE WHEN %s > 10000 THEN 1 ELSE 0 END',
            ['PRICE']
        ),
    ],
    'filter' => ['=ACTIVE' => 'Y'],
]);
```

---

## ORM: События сущностей (Entity Events)

Это **хуки жизненного цикла** записи. На каждую операцию (`add`, `update`, `delete`) ядро последовательно вызывает три события. Это позволяет перехватить операцию до, во время и после её выполнения.

На каждую операцию — 9 событий итого:

| Константа DataManager | Имя | Когда | Можно прервать? |
|---|---|---|---|
| `EVENT_ON_BEFORE_ADD` | `OnBeforeAdd` | до INSERT | **да** — можно изменить поля или отменить |
| `EVENT_ON_ADD` | `OnAdd` | внутри транзакции после INSERT | нет |
| `EVENT_ON_AFTER_ADD` | `OnAfterAdd` | после коммита транзакции | нет |
| `EVENT_ON_BEFORE_UPDATE` | `OnBeforeUpdate` | до UPDATE | **да** |
| `EVENT_ON_UPDATE` | `OnUpdate` | внутри транзакции после UPDATE | нет |
| `EVENT_ON_AFTER_UPDATE` | `OnAfterUpdate` | после коммита | нет |
| `EVENT_ON_BEFORE_DELETE` | `OnBeforeDelete` | до DELETE | **да** |
| `EVENT_ON_DELETE` | `OnDelete` | внутри транзакции | нет |
| `EVENT_ON_AFTER_DELETE` | `OnAfterDelete` | после коммита | нет |

**Когда что использовать:**
- `OnBefore*` — валидация, автозаполнение полей, проверка бизнес-правил
- `OnAfter*` — очистка кеша, отправка уведомлений, каскадные операции в других таблицах
- `On*` (средние) — редко нужны, только если критична точность "внутри транзакции"

### ORM\EventResult — управление событием

`ORM\EventResult` — специальный класс, не путать с `\Bitrix\Main\EventResult`. Только он умеет изменять поля и отменять операцию.

```php
use Bitrix\Main\ORM\EventResult;
use Bitrix\Main\ORM\EntityError;

$result = new EventResult(); // по умолчанию SUCCESS

// Изменить поля перед сохранением — только в OnBefore*
$result->modifyFields(['UPDATED_AT' => new \Bitrix\Main\Type\DateTime()]);

// Убрать поле из сохранения
$result->unsetField('TEMP_FIELD');
$result->unsetFields(['FIELD_A', 'FIELD_B']);

// Прервать операцию — вызов addError меняет тип на ERROR, операция не выполнится
$result->addError(new EntityError('Сообщение', 'MY_CODE'));
$result->setErrors([new EntityError('Ошибка 1'), new EntityError('Ошибка 2')]);

// EntityError: код по умолчанию — 'BX_ERROR' (не 0!)
new EntityError('Сообщение');            // код = 'BX_ERROR'
new EntityError('Сообщение', 'MY_CODE'); // код = 'MY_CODE'
```

### Способ 1 — переопределение метода в DataManager (рекомендуется для собственной логики)

Используй когда логика принадлежит самой таблице — это часть бизнес-правил сущности. Ядро вызывает метод **напрямую** перед отправкой в EventManager.

```php
use Bitrix\Main\ORM\Data\DataManager;
use Bitrix\Main\ORM\Event;
use Bitrix\Main\ORM\EventResult;
use Bitrix\Main\ORM\EntityError;

class OrderTable extends DataManager
{
    // Параметры: 'fields' (массив значений) + 'object' (EntityObject до сохранения)
    public static function OnBeforeAdd(Event $event): EventResult
    {
        $result = new EventResult();
        $fields = $event->getParameter('fields');

        if (empty($fields['TITLE'])) {
            $result->addError(new EntityError('Заголовок обязателен', 'EMPTY_TITLE'));
            return $result; // операция прервётся, INSERT не выполнится
        }

        // Автозаполнение — добавляем поле которого не было в исходных данных
        $result->modifyFields([
            'CREATED_BY' => \Bitrix\Main\Engine\CurrentUser::get()->getId(),
        ]);

        return $result;
    }

    // Параметры: 'id' (int), 'primary' (['ID'=>5]), 'fields', 'object' (clone после INSERT)
    public static function OnAfterAdd(Event $event): EventResult
    {
        $id = $event->getParameter('id');

        // Здесь запись уже в БД — можно чистить кеш, слать уведомления
        \Bitrix\Main\Application::getInstance()
            ->getTaggedCache()
            ->clearByTag('my_order_list');

        return new EventResult();
    }

    // Параметры: 'id', 'primary' (['ID'=>5]), 'fields' (только изменяемые!), 'object'
    public static function OnBeforeUpdate(Event $event): EventResult
    {
        $result = new EventResult();
        // ВАЖНО: $fields содержит только те поля, которые переданы в update()
        // Не все поля записи, только изменяемые
        $result->modifyFields(['UPDATED_AT' => new \Bitrix\Main\Type\DateTime()]);
        return $result;
    }

    public static function OnAfterUpdate(Event $event): EventResult
    {
        return new EventResult();
    }

    // Параметры: 'id', 'primary' (['ID'=>5]), 'object' (clone перед удалением)
    public static function OnBeforeDelete(Event $event): EventResult
    {
        $result  = new EventResult();
        $primary = $event->getParameter('primary');

        // Проверка целостности — нельзя удалить если есть связанные записи
        if (OrderItemTable::getCount(['=ORDER_ID' => $primary['ID']]) > 0) {
            $result->addError(new EntityError('Нельзя удалить заказ с позициями', 'HAS_ITEMS'));
        }
        return $result;
    }

    public static function OnAfterDelete(Event $event): EventResult
    {
        $primary = $event->getParameter('primary');
        // Каскадное удаление связанных данных, очистка кеша
        return new EventResult();
    }
}
```

**Важно: регистр имён методов** — ядро вызывает `call_user_func_array([$class, 'OnBeforeAdd'], [$event])`. Методы должны называться `OnBeforeAdd`, `OnAfterAdd` и т.д. — с заглавной `O`.

### Способ 2 — подписка через EventManager (для межмодульной интеграции)

Используй когда **другой модуль** должен реагировать на изменения в чужой таблице. Ядро стреляет двумя вариантами события одновременно: legacy (без namespace) и modern (с namespace). Подписывайся на modern.

```php
// Modern-формат имени события: '\Namespace\ClassName::EventName'
\Bitrix\Main\EventManager::getInstance()->addEventHandler(
    'my.module',                                       // модуль, которому принадлежит таблица
    '\MyVendor\MyModule\OrderTable::OnBeforeAdd',      // modern-формат
    [\AnotherVendor\Integration\Handler::class, 'handle']
);

// Обработчик работает с ORM\Event и возвращает ORM\EventResult
class Handler
{
    public static function handle(\Bitrix\Main\ORM\Event $event): \Bitrix\Main\ORM\EventResult
    {
        $result = new \Bitrix\Main\ORM\EventResult();
        $fields = $event->getParameter('fields');
        // ...
        return $result;
    }
}
```

---

## Result / Error — паттерн для сервисов

`Result` — стандартный D7-способ вернуть успех или ошибку из метода. Не исключения (исключения для неожиданных ситуаций), не `bool`, не `null`. `Result` несёт в себе: статус (isSuccess), список ошибок с кодами, и произвольные данные.

**Почему не исключения?** Потому что ошибка валидации или "запись не найдена" — это ожидаемый бизнес-результат, не исключительная ситуация. `Result` позволяет вернуть несколько ошибок сразу и содержит коды для i18n.

### Error — полный API

```php
use Bitrix\Main\Error;

// new Error($message, $code = 0, $customData = null)
$error = new Error('Заголовок обязателен', 'EMPTY_TITLE');
// $customData — любые данные для фронта (поле, допустимые значения и т.п.)
$error = new Error('Слишком длинный', 'TOO_LONG', ['field' => 'TITLE', 'max' => 255]);

// Создать из исключения
$error = Error::createFromThrowable($exception);

$error->getMessage();    // строка для отображения
$error->getCode();       // строка/int для switch-case и i18n
$error->getCustomData(); // дополнительные данные
(string) $error;         // то же что getMessage()
json_encode($error);     // {'message':..., 'code':..., 'customData':...}
```

### Result — полный API

```php
use Bitrix\Main\Result;
use Bitrix\Main\Error;

$result = new Result();

// Добавление ошибок — сразу переводит isSuccess() в false
$result->addError(new Error('...'));
$result->addErrors([$error1, $error2]);

// addError возвращает $this, поэтому можно сразу return:
return $result->addError(new Error('Ошибка'));

$result->isSuccess();           // bool
$result->getErrors();           // Error[]
$result->getError();            // Error|null — первая ошибка
$result->getErrorMessages();    // string[] — только тексты ошибок
$result->getErrorCollection();  // ErrorCollection (с методом getErrorByCode())
$result->setData(['id' => 5]);  // сохранить данные результата
$result->getData();             // array
```

### Паттерн в сервисе

```php
class OrderService
{
    public function create(array $data): Result
    {
        $result = new Result();

        // Ранний возврат при ошибке валидации
        if (empty($data['TITLE'])) {
            return $result->addError(new Error('Заголовок обязателен', 'EMPTY_TITLE'));
        }

        $addResult = OrderTable::add($data);
        if (!$addResult->isSuccess()) {
            // Проброс ошибок ORM в свой Result — не теряем детали
            return $result->addErrors($addResult->getErrors());
        }

        return $result->setData(['id' => $addResult->getId()]);
    }
}

// Использование
$result = (new OrderService())->create(['TITLE' => 'Тест', 'USER_ID' => 1]);

if ($result->isSuccess()) {
    $id = $result->getData()['id'];
} else {
    foreach ($result->getErrors() as $error) {
        echo $error->getMessage();    // показать пользователю
        echo $error->getCode();       // для switch/i18n
    }
}
```

---

## EventManager — события модулей

`EventManager` — шина событий Bitrix. Это механизм loose coupling: модуль А стреляет событие, модуль Б его слушает, они не зависят друг от друга напрямую. Используется для: интеграций между модулями, расширения поведения стандартных операций (iblock, sale, users).

### Runtime vs Persistent подписка

Два принципиально разных способа:

| Метод | Где хранится | Когда использовать |
|-------|-------------|-------------------|
| `addEventHandler()` | в памяти до конца запроса | в `init.php` или `include.php` модуля — работает пока подключён файл |
| `registerEventHandler()` | в БД `b_module_to_module`, переживает перезапуск | в инсталляторе модуля — постоянная подписка |

### Version 1 vs Version 2 — разные сигнатуры обработчиков

Это ключевое различие:
- `addEventHandler()` — **version=2** → обработчику передаётся объект `Event`
- `addEventHandlerCompatible()` — **version=1** → обработчику передаются параметры по-отдельности (legacy-стиль)

Большинство стандартных событий Bitrix (`OnBeforeIBlockElementAdd` и т.п.) — legacy. Они ожидают version=1. Поэтому для них нужен `addEventHandlerCompatible()` или `registerEventHandlerCompatible()`.

```php
use Bitrix\Main\EventManager;
use Bitrix\Main\Event;
use Bitrix\Main\EventResult;

$em = EventManager::getInstance();

// D7-событие (своё или другого D7-модуля) — version=2, получает объект Event
$em->addEventHandler(
    'my.module',
    'OnOrderStatusChanged',
    [\MyVendor\MyModule\Handler::class, 'onStatusChanged'],
    false,  // $includeFile (путь к файлу, если нужно подключить; false = не нужен)
    100     // $sort — порядок выполнения (меньше = раньше)
);

// Legacy-событие iblock/sale/etc — version=1, параметры передаются напрямую
$em->addEventHandlerCompatible(
    'iblock',
    'OnBeforeIBlockElementAdd',
    [\MyVendor\MyModule\IblockHandler::class, 'onBeforeElementAdd']
);

// Удалить обработчик — $key возвращается addEventHandler
$key = $em->addEventHandler('my.module', 'OnSomething', $callback);
$em->removeEventHandler('my.module', 'OnSomething', $key);
```

### Обработчики: D7 vs legacy

```php
class IblockHandler
{
    // D7-стиль (version=2): получает объект Event, возвращает EventResult или null
    public static function onStatusChanged(Event $event): ?EventResult
    {
        $orderId   = $event->getParameter('id');
        $newStatus = $event->getParameter('newStatus');

        // null = всё нормально, продолжаем
        // EventResult::ERROR = прерываем (если событие это поддерживает)
        return null;
    }

    // Legacy-стиль (version=1): параметры по-отдельности, часто по ссылке
    public static function onBeforeElementAdd(array &$arFields): void
    {
        // Изменяем поля напрямую через ссылку
        $arFields['PREVIEW_TEXT'] = strip_tags($arFields['PREVIEW_TEXT'] ?? '');
    }
}
```

### Создание и отправка своих D7-событий

```php
use Bitrix\Main\Event;
use Bitrix\Main\EventResult;

// Создаём и отправляем событие
$event = new Event('my.module', 'OnOrderStatusChanged', [
    'id'        => $orderId,
    'oldStatus' => $old,
    'newStatus' => $new,
]);
$event->send();

// Анализируем результаты подписчиков
// EventResult::UNDEFINED=0, SUCCESS=1, ERROR=2
foreach ($event->getResults() as $eventResult) {
    if ($eventResult->getType() === EventResult::SUCCESS) {
        $data = $eventResult->getParameters(); // данные от подписчика
    } elseif ($eventResult->getType() === EventResult::ERROR) {
        // подписчик сигнализирует об ошибке
    }
}

// Подписчик на D7-событие возвращает \Bitrix\Main\EventResult (не ORM\EventResult!)
$em->addEventHandler('my.module', 'OnOrderStatusChanged', function(Event $event) {
    return new EventResult(EventResult::SUCCESS, ['notified' => true], 'my.module');
});
```

### Persistent-регистрация в инсталляторе модуля

```php
// /bitrix/modules/my.module/install/index.php — при установке модуля
\Bitrix\Main\EventManager::getInstance()->registerEventHandler(
    'iblock',                                    // чьё событие слушаем
    'OnBeforeIBlockElementAdd',                  // имя события
    'my.module',                                 // наш модуль
    '\MyVendor\MyModule\IblockHandler',          // класс
    'onBeforeElementAdd',                        // метод
    100                                          // sort
);

// При удалении модуля — обязательно убирать
\Bitrix\Main\EventManager::getInstance()->unRegisterEventHandler(
    'iblock', 'OnBeforeIBlockElementAdd',
    'my.module', '\MyVendor\MyModule\IblockHandler', 'onBeforeElementAdd'
);
// Кеш b_module_to_module сбросится автоматически
```

---

## Engine: Controllers и AJAX

`Engine\Controller` — стандартный способ обрабатывать AJAX в D7. Всё через одну точку: `/bitrix/services/main/ajax.php?action=vendor.module.controller.action`. Контроллер автоматически: проверяет авторизацию и CSRF, биндит параметры запроса к аргументам метода по типам PHP, упаковывает ответ в JSON `{"status":"success","data":{...}}`.

**Когда использовать Controller вместо отдельного PHP-файла:** всегда в D7-коде. Голые PHP-файлы для AJAX — legacy-подход.

### Жизненный цикл запроса к контроллеру

1. Запрос приходит на `/bitrix/services/main/ajax.php?action=...`
2. Ядро находит контроллер по namespace-регистрации в `.settings.php`
3. Вызываются `prefilters` (Authentication → HttpMethod → Csrf)
4. Если все фильтры прошли — вызывается `{action}Action()` метод
5. Параметры метода автоматически извлекаются из GET/POST и кастуются по типам
6. Результат оборачивается в `AjaxJson`

### Контроллер

```php
namespace MyVendor\MyModule\Controller;

use Bitrix\Main\Engine\Controller;
use Bitrix\Main\Engine\ActionFilter;
use Bitrix\Main\Engine\CurrentUser;
use Bitrix\Main\Error;

class Order extends Controller
{
    // Дефолтные prefilters: Authentication + HttpMethod(GET|POST) + Csrf
    // configureActions позволяет переопределить их для каждого action
    public function configureActions(): array
    {
        return [
            // Полностью заменить prefilters (Csrf НЕ нужен для GET)
            'getList' => [
                'prefilters' => [
                    new ActionFilter\Authentication(),
                    new ActionFilter\HttpMethod([ActionFilter\HttpMethod::METHOD_GET]),
                ],
            ],

            // Добавить фильтр к дефолтным, не заменяя их (+prefilters)
            'export' => [
                '+prefilters' => [new ActionFilter\Scope([Controller::SCOPE_AJAX])],
            ],

            // Убрать конкретный фильтр из дефолтных (-prefilters)
            'publicInfo' => [
                '-prefilters' => [
                    ActionFilter\Authentication::class,
                    ActionFilter\Csrf::class,
                ],
            ],

            // Для POST: Csrf добавляется автоматически если есть METHOD_POST + SCOPE_AJAX
            'create' => [
                'prefilters' => [
                    new ActionFilter\Authentication(),
                    new ActionFilter\HttpMethod([ActionFilter\HttpMethod::METHOD_POST]),
                ],
            ],

            // Публичный endpoint без любых фильтров
            'publicStats' => [
                'prefilters' => [], 'postfilters' => [],
            ],
        ];
    }

    // Параметры биндятся автоматически из GET/POST по именам и типам PHP
    // Метод ОБЯЗАН заканчиваться на 'Action' (METHOD_ACTION_SUFFIX = 'Action')
    public function getListAction(int $page = 1, int $limit = 20): array
    {
        $items = \MyVendor\MyModule\OrderTable::getList([
            'select' => ['ID', 'TITLE'],
            'filter' => ['=ACTIVE' => 'Y'],
            'limit'  => $limit,
            'offset' => ($page - 1) * $limit,
        ])->fetchAll();

        return ['items' => $items, 'total' => \MyVendor\MyModule\OrderTable::getCount()];
        // Автоматически: {"status":"success","data":{"items":[...],"total":N}}
    }

    // null + addError → {"status":"error","errors":[...]}
    public function createAction(string $title, ?int $userId = null): ?array
    {
        if (empty($title)) {
            $this->addError(new Error('Заголовок обязателен', 'EMPTY_TITLE'));
            return null;
        }

        $result = \MyVendor\MyModule\OrderTable::add([
            'TITLE'   => $title,
            'USER_ID' => $userId ?? CurrentUser::get()->getId(),
        ]);

        if (!$result->isSuccess()) {
            $this->addErrors($result->getErrors()); // проброс ошибок ORM
            return null;
        }

        return ['id' => $result->getId()];
    }

    // Конвертация UPPER_CASE ключей ORM → camelCase для фронта
    public function getItemAction(int $id): ?array
    {
        $row = \MyVendor\MyModule\OrderTable::getById($id)->fetch();
        if (!$row) {
            $this->addError(new Error('Не найден', 'NOT_FOUND'));
            return null;
        }
        // ['USER_ID' => 1] → ['userId' => 1]
        return $this->convertKeysToCamelCase($row);
    }

    // Форвардинг — передать управление в другой контроллер
    public function complexAction(): mixed
    {
        return $this->forward(AnotherController::class, 'process', ['param' => 'value']);
    }
}
```

### Формат JSON-ответа

```json
{"status": "success", "data": {...},  "errors": []}
{"status": "error",   "data": null,   "errors": [{"message":"...","code":"...","customData":null}]}
{"status": "denied",  "data": null,   "errors": [...]}
```

`denied` — когда `Authentication` filter отклоняет запрос (401). `error` — когда action вернул `addError`.

```php
// Ручное создание AjaxJson (когда нужно вернуть из action напрямую)
use Bitrix\Main\Engine\Response\AjaxJson;
use Bitrix\Main\ErrorCollection;

return AjaxJson::createSuccess(['id' => 5]);
return AjaxJson::createError(new ErrorCollection([$error]));
return AjaxJson::createDenied();
```

### Вызов с фронтенда

Формат action строится из namespace-регистрации: `\\MyVendor\\MyModule\\Controller` → `'myvendor.mymodule'`, класс `Order`, метод `getListAction` → итого `'myvendor.mymodule.order.getList'`.

```javascript
BX.ajax.runAction('myvendor.mymodule.order.getList', {
    data: { page: 1, limit: 20 },
}).then(response => {
    console.log(response.data); // { items: [...], total: N }
});

// POST с CSRF-токеном
BX.ajax.runAction('myvendor.mymodule.order.create', {
    method: 'POST',
    data: { title: 'Новый заказ', sessid: BX.bitrix_sessid() },
});
```

```php
// Регистрация в /bitrix/modules/my.module/.settings.php
return [
    'controllers' => [
        'value' => [
            'namespaces' => [
                '\\MyVendor\\MyModule\\Controller' => 'myvendor.mymodule',
            ],
        ],
        'readonly' => true,
    ],
];
```

---

## Routing (Bitrix\Main\Routing)

Роутер работает **вместо** стандартного `urlrewrite.php` для указанных URL. Файл `/local/routes.php` подхватывается автоматически. Роуты обрабатываются раньше компонентов — это позволяет строить чистые REST-подобные URL без `.htaccess`.

Роутер удобен для: REST API, SPA-бэкендов, кастомных страниц без компонентов. **Не замена** компонентному подходу для обычных страниц.

```php
// /local/routes.php
use Bitrix\Main\Routing\RoutingConfigurator;

return function (RoutingConfigurator $routes): void {

    // Простой маршрут с параметром и regexp-ограничением
    $routes->get(
        '/api/orders/{id}/',
        [\MyVendor\MyModule\Controller\Order::class, 'getAction']
    )->where('id', '\d+'); // только числа

    // Группа с префиксом — все методы REST для ресурса
    $routes->prefix('/api/v1')->group(function (RoutingConfigurator $routes): void {
        $routes->get('/orders/',         [\MyVendor\MyModule\Controller\Order::class, 'getListAction']);
        $routes->post('/orders/',        [\MyVendor\MyModule\Controller\Order::class, 'createAction']);
        $routes->put('/orders/{id}/',    [\MyVendor\MyModule\Controller\Order::class, 'updateAction']);
        $routes->delete('/orders/{id}/', [\MyVendor\MyModule\Controller\Order::class, 'deleteAction']);
    });

    // Группа с middleware
    $routes->middleware(\Bitrix\Main\Routing\Middleware\Auth::class)
        ->prefix('/admin/api')
        ->group(function (RoutingConfigurator $routes): void {
            $routes->get('/stats/', [\MyVendor\MyModule\Controller\Stats::class, 'getAction']);
        });
};
```

---

## Type\DateTime и Type\Date

### Главное правило: toString() vs format()

`DateTime` хранит время в серверной таймзоне. Это разграничение критично:

- `format('d.m.Y H:i:s')` → **серверное время**, для хранения, логов, сравнений
- `toString()` → **пользовательское время** (авто-конвертация через `\CTimeZone`), для отображения

Ошибка: сравнивать `toString()` двух объектов — они уже в пользовательской зоне, результат непредсказуем. Всегда сравнивай через `getTimestamp()`.

```php
use Bitrix\Main\Type\DateTime;
use Bitrix\Main\Type\Date;

// Создание
$now  = new DateTime();                                        // текущий момент
$dt   = new DateTime('2024-06-15 14:30:00');                   // из строки Bitrix-формата
$dt   = DateTime::createFromTimestamp(time());                 // из UNIX timestamp
$dt   = DateTime::createFromUserTime('15.06.2024 14:30:00');  // из строки в зоне пользователя
$dt   = DateTime::createFromPhp(new \DateTime('now'));         // из PHP-нативного \DateTime
$dt   = DateTime::tryParse($userInput);                        // null при ошибке, не кидает исключение

$date = new Date('2024-06-15', 'Y-m-d');  // Date — только дата без времени
$date = Date::createFromTimestamp(time());

// Форматирование
$dt->format('d.m.Y H:i:s');   // серверное время — для хранения и логики
$dt->toString();               // пользовательское время — для вывода в HTML
$dt->getTimestamp();           // UNIX timestamp — для сравнений

// Управление конвертацией таймзоны
$dt->disableUserTime();  // toString() тоже вернёт серверное время
$dt->enableUserTime();   // вернуть по умолчанию (включена)

// Арифметика — ISO 8601 DateInterval
$dt->add('P1D');     // +1 день
$dt->add('P1M');     // +1 месяц
$dt->add('PT2H');    // +2 часа
$dt->add('PT30M');   // +30 минут
$dt->add('-P1D');    // -1 день

$dt->setTime(0, 0, 0);  // начало дня
$dt->setTimeZone(new \DateTimeZone('Europe/Moscow'));

// В ORM — DatetimeField принимает и возвращает объект DateTime
OrderTable::update($id, ['DEADLINE' => new DateTime('2024-12-31 23:59:59')]);
$row  = OrderTable::getById($id)->fetch();
$date = $row['CREATED_AT']; // instanceof DateTime
echo $date->format('d.m.Y');   // серверное
echo $date->toString();        // пользовательское
```

---

## HttpClient — внешние HTTP-запросы

`HttpClient` **не бросает исключений** на HTTP-ошибки (4xx, 5xx). Он возвращает тело ответа, а статус и транспортные ошибки нужно проверять вручную через `getStatus()` и `getError()`. Это самое частое место где пропускают проверку.

```php
use Bitrix\Main\Web\HttpClient;

$client = new HttpClient([
    'socketTimeout'          => 10,    // таймаут подключения (сек)
    'streamTimeout'          => 30,    // таймаут чтения (сек)
    'redirect'               => true,
    'redirectMax'            => 5,
    'disableSslVerification' => false, // true только для локальной разработки
]);

// GET — возвращает тело ответа (string) или false
$body   = $client->get('https://api.example.com/data');
$status = $client->getStatus(); // int: 200, 404, 500...
$errors = $client->getError();  // array транспортных ошибок (пустой если нет)

if (!empty($errors)) {
    // Ошибка соединения, DNS, timeout — запрос не дошёл
} elseif ($status !== 200) {
    // Сервер ответил, но с ошибкой
} else {
    $data = json_decode($body, true);
}

// POST с JSON
$client->setHeader('Content-Type', 'application/json');
$client->setHeader('Authorization', 'Bearer ' . $token);
$body = $client->post('https://api.example.com/orders', json_encode(['title' => 'Test']));

// POST с form-data
$body = $client->post('https://api.example.com/form', ['field1' => 'v1', 'field2' => 'v2']);

// Скачать файл на диск
$client->download('https://example.com/file.pdf', '/tmp/file.pdf');

// Заголовки ответа
$contentType = $client->getHeaders()->get('Content-Type');
```

---

## Иерархия исключений ядра

Исключения — для **неожиданных** ситуаций (ошибки программиста, недоступность БД, неверные аргументы). Для ожидаемых бизнес-ошибок используй `Result`.

```php
// Базовые (Bitrix\Main\*)
use Bitrix\Main\SystemException;             // корень иерархии — все остальные наследуют его
use Bitrix\Main\ArgumentException;           // неверный аргумент
use Bitrix\Main\ArgumentNullException;       // аргумент не может быть null
use Bitrix\Main\ArgumentOutOfRangeException; // аргумент вне допустимого диапазона
use Bitrix\Main\ObjectNotFoundException;     // объект не найден (аналог 404)
use Bitrix\Main\ObjectPropertyException;    // обращение к несуществующему свойству объекта
use Bitrix\Main\NotImplementedException;    // метод не реализован
use Bitrix\Main\NotSupportedException;      // операция не поддерживается
use Bitrix\Main\InvalidOperationException;  // недопустимая операция в текущем состоянии

use Bitrix\Main\DB\SqlQueryException;       // ошибка выполнения SQL
use Bitrix\Main\IO\FileNotFoundException;
use Bitrix\Main\IO\AccessDeniedException;
use Bitrix\Main\LoaderException;            // не удалось подключить модуль

// Правило: ловить конкретный тип, не SystemException — иначе поймаешь лишнее
try {
    $order = OrderTable::getById($id)->fetchObject();
    if (!$order) {
        throw new \Bitrix\Main\ObjectNotFoundException("Order #{$id} not found");
    }
} catch (\Bitrix\Main\ObjectNotFoundException $e) {
    // 404-сценарий
} catch (\Bitrix\Main\DB\SqlQueryException $e) {
    // проблема с БД — логировать и 500
} catch (\Bitrix\Main\SystemException $e) {
    // всё остальное неожиданное
}
```

---

## Что никогда не делать

- `mysql_query` / `mysqli_query` напрямую — только ORM или `$connection->query()` с `forSql()`
- Конкатенация пользовательского ввода в SQL — только `$helper->forSql()`
- `echo $_GET['param']` без экранирования — XSS
- Работа с классами модуля без `Loader::includeModule()` — падёт на другом окружении
- `global $DB` в D7-коде — используй `Application::getConnection()`
- Игнорирование `$result->isSuccess()` после `add/update/delete`
- Возврат `bool`/`null` из сервисного метода вместо `Result` — теряется информация об ошибке
- `RegisterModuleDependences` в `init.php` — только в инсталляторе
- `$_GET`, `$_POST`, `$_SERVER` напрямую в D7 — только через `$request->getQuery()` / `getPost()`
- `HttpClient` без проверки `getStatus()` и `getError()`
- `date()` и `strtotime()` при работе с ORM-датами — только `Type\DateTime`
- Сравнивать `DateTime` через `toString()` — только через `getTimestamp()`

---

## Стиль ответов

- Сначала коротко объясни ЧТО делаешь и ПОЧЕМУ именно так, затем код
- Всегда указывай `use`-импорты
- Если есть D7 и legacy — показывай D7, legacy только если веская причина
- При неоднозначности — уточни версию Bitrix и контекст (компонент, модуль, REST, CLI)
- Предупреждай о gotchas — особенно DateTime userTime, EventResult (ORM vs Main), version1 vs version2
