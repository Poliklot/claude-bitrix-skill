# Bitrix D7 ORM — полный справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с ORM, DataManager, CRUD, фильтрами, агрегацией, событиями сущностей, Result/Error паттерном или исключениями ядра.
>
> Audit note (core-verified, current project): справочник сверялся по `www/bitrix/modules/main/lib/orm/data/datamanager.php`, `orm/query/{query,result}.php`, `orm/objectify/entityobject.php` и `orm/entity.php`.

## Содержание
- DataManager: схема, CRUD, Relations, ExpressionField, транзакции
- ORM: Операторы фильтра (полная таблица)
- ORM: Агрегация (COUNT, SUM, GROUP BY)
- ORM: Runtime-поля в запросе
- ORM: События сущностей (OnBefore*/OnAfter*)
- Result / Error паттерн для сервисов
- Иерархия исключений ядра
- Что никогда не делать (ORM/SQL)

---

## D7 ORM

### Архитектурный смысл

ORM в Bitrix — это **DataManager/DataMapper-центричный** слой поверх таблицы. `DataManager` — базовый класс, от которого наследуется каждая таблица. Он даёт: CRUD, события, типизированные поля, JOIN-ы и объектный API.

Важно не описывать текущий D7 ORM как “только массивы”: в этом core реально есть `fetchObject()`, `fetchCollection()`, `EntityObject::save()` и `DataManager::createObject()`. То есть базовая точка входа всё ещё `DataManager`, но объектный слой в ядре присутствует.

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

Используй транзакции когда несколько операций должны быть атомарными — либо все успешно, либо ничего. В текущем `DataManager` явные `startTransaction()/commitTransaction()` внутри `add/update/delete` не видны, поэтому не обещай “автоматическую транзакцию ORM” без отдельной проверки конкретного сценария.

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

Это **хуки жизненного цикла** записи. На каждую операцию (`add`, `update`, `delete`) ядро последовательно вызывает три события. В текущем core важно не путать их с транзакционными хуками: `OnAdd`/`OnUpdate`/`OnDelete` вызываются в середине pipeline операции, но не “после SQL внутри транзакции”.

На каждую операцию — 9 событий итого:

| Константа DataManager | Имя | Когда | Можно прервать? |
|---|---|---|---|
| `EVENT_ON_BEFORE_ADD` | `OnBeforeAdd` | до INSERT | **да** — можно изменить поля или отменить |
| `EVENT_ON_ADD` | `OnAdd` | после валидации и перед INSERT | нет |
| `EVENT_ON_AFTER_ADD` | `OnAfterAdd` | после INSERT, UF update и cleanCache | нет |
| `EVENT_ON_BEFORE_UPDATE` | `OnBeforeUpdate` | до UPDATE | **да** |
| `EVENT_ON_UPDATE` | `OnUpdate` | после валидации и перед UPDATE | нет |
| `EVENT_ON_AFTER_UPDATE` | `OnAfterUpdate` | после UPDATE, UF update и cleanCache | нет |
| `EVENT_ON_BEFORE_DELETE` | `OnBeforeDelete` | до DELETE | **да** |
| `EVENT_ON_DELETE` | `OnDelete` | перед DELETE | нет |
| `EVENT_ON_AFTER_DELETE` | `OnAfterDelete` | после DELETE, UF delete и cleanCache | нет |

Дополнительно: `DataManager` отправляет и legacy-, и modern namespaced вариант ORM-события, поэтому обработчики в старом и новом стиле могут сосуществовать.

**Когда что использовать:**
- `OnBefore*` — валидация, автозаполнение полей, проверка бизнес-правил
- `OnAfter*` — очистка кеша, отправка уведомлений, каскадные операции в других таблицах
- `On*` (средние) — когда нужно вклиниться в pipeline после валидации, но до фактического сохранения/удаления

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

Используй когда логика принадлежит самой таблице — это часть бизнес-правил сущности. Ядро вызывает метод как часть **modern-события** (с namespace): после того как отработают legacy-обработчики из EventManager, стреляет modern-событие, и внутри него через `call_user_func_array` вызывается метод класса. Именно поэтому методы получают modern-параметры (включают `primary` и `object`).

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
// Modern-формат имени события: '\Namespace\EntityName::EventName'
// EntityName = имя класса DataManager БЕЗ суффикса 'Table'
// OrderTable → 'Order', UserTable → 'User', ElementTable → 'Element'
\Bitrix\Main\EventManager::getInstance()->addEventHandler(
    'my.module',                                   // модуль, которому принадлежит таблица
    '\MyVendor\MyModule\Order::OnBeforeAdd',        // modern-формат: без 'Table'!
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
use Bitrix\Main\IO\FileNotFoundException;   // файл не найден (IO\IoException → SystemException)
use Bitrix\Main\AccessDeniedException;      // доступ запрещён (Bitrix\Main, не IO\!)
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
