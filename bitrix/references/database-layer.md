# Bitrix Database Layer — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с прямой работой с БД: `Bitrix\Main\DB\Connection`, `DB\SqlHelper`, `Application::getConnection()`, различиями в SQL-синтаксисе MySQL/PostgreSQL/Oracle/MSSQL, или тестированием запросов через `disableQueryExecuting`.

## Содержание
- Получение соединения
- Connection: основные методы
- SqlHelper: экранирование и утилиты
- Прямые запросы: query(), queryScalar(), fetch()
- Транзакции
- Различия СУБД: MySQL, PostgreSQL, Oracle, MSSQL
- Тестирование запросов (disableQueryExecuting)
- Gotchas

---

## Получение соединения

```php
use Bitrix\Main\Application;
use Bitrix\Main\DB\Connection;

// Основное соединение (из .settings.php → connections → default)
$connection = Application::getConnection();

// Альтернативное соединение по имени
$slaveConnection = Application::getConnection('slave');

// Получить SqlHelper текущего соединения
$helper = $connection->getSqlHelper();
```

---

## Connection: основные методы

```php
use Bitrix\Main\Application;

$connection = Application::getConnection();

// Выполнить запрос (возвращает Result)
$result = $connection->query("SELECT * FROM b_user WHERE ACTIVE='Y' LIMIT 10");

// Итерация по результату
while ($row = $result->fetch()) {
    echo $row['LOGIN'];
}

// Один скаляр
$count = $connection->queryScalar("SELECT COUNT(*) FROM b_user WHERE ACTIVE='Y'");

// Исполнить произвольный SQL (INSERT/UPDATE/DELETE/DDL — не возвращает данные)
$connection->queryExecute("UPDATE b_user SET LAST_LOGIN = NOW() WHERE ID = 42");

// Кол-во затронутых строк
$connection->getAffectedRowsCount();

// Последний insert id
$connection->getInsertedId();

// Экранирование идентификатора (имени таблицы/колонки)
$quotedTable = $helper->quote('my_table');  // `my_table` для MySQL
```

---

## SqlHelper: экранирование и утилиты

```php
use Bitrix\Main\Application;

$helper = Application::getConnection()->getSqlHelper();

// Экранировать строковое значение для вставки в SQL
$safe = $helper->forSql($userInput);
// НЕ добавляет кавычки — только экранирует внутри строки
// Используй так: "WHERE NAME = '" . $helper->forSql($name) . "'"

// Экранировать идентификатор (имя колонки/таблицы)
$quoted = $helper->quote('my_column'); // `my_column` (MySQL) или "my_column" (PgSQL)

// Текущая дата и время (зависит от СУБД)
$nowExpr = $helper->getCurrentDateTimeFunction(); // NOW() или SYSDATE или GETDATE()

// Текущая дата (без времени)
$dateExpr = $helper->getCurrentDateFunction(); // CURDATE() или TRUNC(SYSDATE) и т.д.

// Добавить дни к дате
$addDays = $helper->addDaysToDateTime('MY_DATE_FIELD', 7);

// Конкатенация строк (зависит от СУБД)
$concat = $helper->getConcatFunction('FIRST_NAME', "' '", 'LAST_NAME');

// Длина строки
$lengthFn = $helper->getLengthFunction('DESCRIPTION');

// Подстрока
$substrFn = $helper->getSubstrFunction('NAME', 1, 10);
```

---

## Безопасные прямые запросы

```php
use Bitrix\Main\Application;

$connection = Application::getConnection();
$helper     = $connection->getSqlHelper();

// ПРАВИЛЬНО: параметры через forSql()
$name   = $helper->forSql($_GET['name'] ?? '');
$status = $helper->forSql($_GET['status'] ?? 'active');

$sql = "
    SELECT ID, LOGIN, NAME
    FROM b_user
    WHERE NAME LIKE '%" . $name . "%'
      AND ACTIVE = '" . $status . "'
    ORDER BY ID DESC
    LIMIT 20
";
$result = $connection->query($sql);

// НЕПРАВИЛЬНО — конкатенация без экранирования:
// $sql = "WHERE NAME = '" . $_GET['name'] . "'"; // SQL-инъекция!
```

---

## Транзакции

```php
use Bitrix\Main\Application;

$connection = Application::getConnection();

$connection->startTransaction();
try {
    $connection->queryExecute("UPDATE my_orders SET STATUS='paid' WHERE ID=42");
    $connection->queryExecute("INSERT INTO my_payments(ORDER_ID, AMOUNT) VALUES(42, 1500)");
    $connection->commitTransaction();
} catch (\Exception $e) {
    $connection->rollbackTransaction();
    throw $e;
}
```

---

## Различия СУБД

Bitrix поддерживает 4 СУБД: MySQL (MySqli), PostgreSQL, Oracle, MSSQL.
У каждой свой `SqlHelper` с перегруженными методами.

| Функция | MySQL | PostgreSQL | Oracle | MSSQL |
|---------|-------|------------|--------|-------|
| Текущее дата+время | `NOW()` | `NOW()` | `SYSDATE` | `GETDATE()` |
| Текущая дата | `CURDATE()` | `CURRENT_DATE` | `TRUNC(SYSDATE)` | `CAST(GETDATE() AS DATE)` |
| Экранирование имени | `` `name` `` | `"name"` | `"name"` | `[name]` |
| LIMIT/OFFSET | `LIMIT N OFFSET M` | `LIMIT N OFFSET M` | `ROWNUM` / `FETCH FIRST` | `TOP N` / `OFFSET FETCH` |
| Автоинкремент | `AUTO_INCREMENT` | `SERIAL` / `GENERATED` | `SEQUENCE` | `IDENTITY` |
| Строковый тип | `VARCHAR(255)` | `VARCHAR(255)` | `VARCHAR2(255)` | `NVARCHAR(255)` |
| Конкатенация | `CONCAT(a,b)` | `a \|\| b` | `a \|\| b` | `a + b` |
| Регистронезависимый поиск | `LIKE` (по умолчанию) | `ILIKE` | `UPPER(col) LIKE UPPER(...)` | `LIKE` (collation) |

**Всегда используй SqlHelper** вместо хардкода функций — он автоматически выдаёт правильный вариант.

---

## Проверка типа соединения

```php
use Bitrix\Main\Application;
use Bitrix\Main\DB\MysqliConnection;
use Bitrix\Main\DB\PgsqlConnection;

$connection = Application::getConnection();

if ($connection instanceof MysqliConnection) {
    // MySQL-специфичный код
} elseif ($connection instanceof PgsqlConnection) {
    // PostgreSQL-специфичный код
}

// Получить версию СУБД
$version = $connection->getVersion();
```

---

## Тестирование запросов (disableQueryExecuting)

Позволяет перехватить SQL без выполнения — удобно для тестов и отладки.

```php
use Bitrix\Main\Application;

$connection = Application::getConnection();

// Отключить выполнение запросов
$connection->disableQueryExecuting();

// Выполняем "запросы" — они не пойдут в БД
$connection->queryExecute("UPDATE b_user SET NAME='Test' WHERE ID=1");
$connection->query("SELECT * FROM b_user");

// Получить накопленные запросы
$dump = $connection->getDisabledQueryExecutingDump();
// Массив строк SQL

var_dump($dump);
// ['UPDATE b_user SET NAME=\'Test\' WHERE ID=1', 'SELECT * FROM b_user']

// Включить обратно
$connection->enableQueryExecuting();
```

---

## SqlTracker: профилирование запросов

```php
use Bitrix\Main\Application;
use Bitrix\Main\Diag\SqlTracker;

$connection = Application::getConnection();

// Включить трекер
$tracker = new SqlTracker();
$connection->startTracker($tracker);

// ... выполни запросы ...

// Получить статистику
$connection->stopTracker();

foreach ($tracker->getQueries() as $query) {
    echo $query->getSql() . ' — ' . $query->getTime() . 'ms' . PHP_EOL;
}

// Итого
echo 'Запросов: ' . $tracker->getCounter() . PHP_EOL;
echo 'Время: ' . $tracker->getTime() . 'ms' . PHP_EOL;
```

---

## Gotchas

- **`forSql()` не добавляет кавычки**: только экранирует символы внутри строки. Оборачивать в одинарные кавычки в SQL нужно самому.
- **`query()` vs `queryExecute()`**: `query()` возвращает `Result` с данными (для SELECT), `queryExecute()` — для INSERT/UPDATE/DELETE/DDL, не возвращает строки.
- **Никогда не конкатенируй `$_GET`/`$_POST` в SQL**: даже через `forSql()` ошибиться легко. Предпочитай ORM.
- **`quote()` для имён таблиц/колонок**: разные СУБД используют разные символы. Всегда используй `$helper->quote()`, не хардкоди.
- **Вложенные транзакции**: в текущем core MySQL использует savepoints. `startTransaction()` на втором уровне создаёт `SAVEPOINT`, `commitTransaction()` коммитит только на уровне `0`, а `rollbackTransaction()` на вложенном уровне делает `ROLLBACK TO SAVEPOINT` и затем бросает `TransactionException`.
- **`disableQueryExecuting()` только для тестов**: не вызывай в production-коде. Не забудь `enableQueryExecuting()` после.
- **`getCurrentDateTimeFunction()`**: возвращает SQL-выражение (строку), не PHP-значение. Используй его в теле SQL-запроса, а не как PHP-переменную.
- **`getDisabledQueryExecutingDump()` очищает dump после чтения**: если считал его один раз, второй вызов вернёт уже очищенное состояние.
- **Соединение живёт в рамках текущего PHP-request**: не рассчитывай на межзапросное состояние, но и не открывай его вручную перед каждым SQL.
