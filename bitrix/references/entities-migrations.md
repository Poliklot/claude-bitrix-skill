# Bitrix Сущности и миграции — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с программным созданием инфоблоков, типов инфоблоков, свойств, групп пользователей, назначением прав или написанием миграций.

## ⚠️ ПРАВИЛО ПОДТВЕРЖДЕНИЯ

**Любое действие, изменяющее данные в БД, требует явного подтверждения пользователя.**

Перед выполнением каждой операции показывай:
```
Собираюсь выполнить:
  [тип операции]: [краткое описание]
  Что изменится: [таблицы/данные]
  Обратимость: [обратимо / необратимо]

Продолжить? (да/нет)
```

Примеры обязательного подтверждения:
- Создание инфоблока/типа/свойства
- Удаление инфоблока, группы, пользователя
- Установка прав доступа (перезаписывает старые)
- Запуск SQL-миграции
- Удаление таблицы или ALTER TABLE

---

## Содержание
- Инфоблок-тип (CIBlockType)
- Создание инфоблока (CIBlock::Add)
- Свойства инфоблока (CIBlockProperty)
- Права на инфоблок (CIBlock::SetPermission)
- Группы пользователей (CGroup)
- Управление пользователями (CUser)
- Права модулей (SetGroupRight)
- Миграции в Bitrix
- Gotchas

---

## Типы инфоблоков (CIBlockType)

Тип — контейнер для группировки инфоблоков (например `catalog`, `content`, `news`).

```php
// Проверяем: тип уже существует?
$existing = CIBlockType::GetByID('catalog');
if ($existing->Fetch()) {
    // тип уже есть — не создавать
}

// Создать тип
$ibt = new CIBlockType();
$id = $ibt->Add([
    'ID'       => 'catalog',     // уникальный строковый ID, только латиница+цифры+_
    'SECTIONS' => 'Y',           // 'Y' = инфоблоки этого типа имеют разделы
    'IN_RSS'   => 'N',
    'SORT'     => 100,
    'LANG'     => [
        'ru' => ['NAME' => 'Каталог', 'ELEMENT_NAME' => 'Товар', 'SECTION_NAME' => 'Раздел'],
        'en' => ['NAME' => 'Catalog', 'ELEMENT_NAME' => 'Product', 'SECTION_NAME' => 'Section'],
    ],
]);
if (!$id) {
    throw new \RuntimeException('CIBlockType::Add error: ' . $ibt->LAST_ERROR);
}
```

---

## Создание инфоблока (CIBlock::Add)

```php
use Bitrix\Main\Loader;
Loader::requireModule('iblock');

// Всегда проверяй существование перед созданием
$existing = \Bitrix\Iblock\IblockTable::getList([
    'filter' => ['=CODE' => 'products'],
    'select' => ['ID'],
])->fetch();
if ($existing) {
    return $existing['ID']; // уже создан
}

$ib = new CIBlock();
$iblockId = $ib->Add([
    // --- Обязательные ---
    'IBLOCK_TYPE_ID' => 'catalog',  // ID типа инфоблока
    'LID'            => ['s1'],     // массив ID сайтов (или строка 's1')
    'NAME'           => 'Товары',
    'CODE'           => 'products', // символьный код (латиница, уникальный)

    // --- Настройки ---
    'ACTIVE'         => 'Y',
    'SORT'           => 100,
    'VERSION'        => 2,          // 1 = старая схема, 2 = раздельные таблицы (рекомендуется)
    'INDEX_ELEMENT'  => 'Y',        // индексировать элементы для поиска
    'INDEX_SECTION'  => 'N',

    // --- API_CODE ---
    // Нужен не всегда, но обязателен для ряда generated DataClass / REST-сценариев.
    // Формат в текущем core: первая буква латинская, далее только буквы и цифры.
    'API_CODE'       => 'products',

    // --- Опционально ---
    'DESCRIPTION'          => '',
    'DESCRIPTION_TYPE'     => 'text', // 'text' | 'html'
    'LIST_PAGE_URL'        => '#SITE_DIR#/catalog/',
    'DETAIL_PAGE_URL'      => '#SITE_DIR#/catalog/#CODE#/',
    'SECTION_PAGE_URL'     => '#SITE_DIR#/catalog/#SECTION_CODE#/',
    'RIGHTS_MODE'          => 'S',  // 'S' = простые права, 'E' = расширенные
    'WORKFLOW'             => 'N',  // устаревший режим документооборота
]);

if (!$iblockId) {
    throw new \RuntimeException('CIBlock::Add error: ' . $ib->LAST_ERROR);
}
```

---

## Свойства инфоблока (CIBlockProperty::Add)

```php
$prop = new CIBlockProperty();

// Строковое свойство
$prop->Add([
    'IBLOCK_ID'     => $iblockId,
    'NAME'          => 'Артикул',
    'CODE'          => 'ARTICLE',        // символьный код, уникальный в рамках ИБ
    'PROPERTY_TYPE' => 'S',             // S=строка, N=число, F=файл, E=элемент, G=раздел, L=список
    'ACTIVE'        => 'Y',
    'SORT'          => 100,
    'MULTIPLE'      => 'N',
    'IS_REQUIRED'   => 'N',
    'SEARCHABLE'    => 'Y',
    'FILTRABLE'     => 'Y',
    'USER_TYPE'     => '',              // '' | 'HTML' | 'DateTime' | 'Date' | 'video' | кастомный
]);

// Числовое свойство
$prop->Add([
    'IBLOCK_ID'     => $iblockId,
    'NAME'          => 'Цена',
    'CODE'          => 'PRICE',
    'PROPERTY_TYPE' => 'N',
    'SORT'          => 200,
]);

// Свойство-список (перечисление)
$listPropId = $prop->Add([
    'IBLOCK_ID'     => $iblockId,
    'NAME'          => 'Цвет',
    'CODE'          => 'COLOR',
    'PROPERTY_TYPE' => 'L',
    'LIST_TYPE'     => 'L',  // 'L'=выпадающий список, 'C'=чекбоксы
    'SORT'          => 300,
]);
// Добавить варианты списка
if ($listPropId) {
    $enum = new CIBlockPropertyEnum();
    foreach (['Красный', 'Синий', 'Зелёный'] as $i => $val) {
        $enum->Add([
            'PROPERTY_ID' => $listPropId,
            'VALUE'       => $val,
            'SORT'        => ($i + 1) * 10,
            'XML_ID'      => mb_strtolower($val),
        ]);
    }
}

// Привязка к элементу другого ИБ
$prop->Add([
    'IBLOCK_ID'       => $iblockId,
    'NAME'            => 'Бренд',
    'CODE'            => 'BRAND',
    'PROPERTY_TYPE'   => 'E',
    'LINK_IBLOCK_ID'  => $brandIblockId,  // ID ИБ, к которому привязка
    'SORT'            => 400,
]);

// Множественное файловое свойство
$prop->Add([
    'IBLOCK_ID'     => $iblockId,
    'NAME'          => 'Галерея',
    'CODE'          => 'GALLERY',
    'PROPERTY_TYPE' => 'F',
    'MULTIPLE'      => 'Y',
    'SORT'          => 500,
]);

if (!$prop->LAST_ERROR) {
    // успех
} else {
    throw new \RuntimeException('CIBlockProperty::Add error: ' . $prop->LAST_ERROR);
}
```

---

## Права на инфоблок (CIBlock::SetPermission)

`SetPermission` **перезаписывает** все права инфоблока. Передавай полный список групп.

```php
// Уровни прав:
// 'R' = чтение
// 'S' = чтение + просмотр детального
// 'E' = чтение + запись элементов
// 'T' = чтение + ограниченная модификация
// 'U' = workflow/документооборотный уровень
// 'W' = запись (редактирование, добавление)
// 'X' = полные права
// Важно: в текущем core "нет доступа" достигается не буквой 'D', а отсутствием записи для группы.

CIBlock::SetPermission($iblockId, [
    1  => 'X',  // группа 1 = Администраторы
    2  => 'R',  // группа 2 = Все (Everyone) — публичное чтение
    // другие группы — просто не указывать
]);

// Получить ID групп по коду:
$rs = CGroup::GetList('', '', ['STRING_ID' => 'MY_EDITORS']);
$editorGroup = $rs->Fetch();
// $editorGroup['ID'] — ID группы

CIBlock::SetPermission($iblockId, [
    1                    => 'X',   // Администраторы
    2                    => 'R',   // Все
    $editorGroup['ID']   => 'W',   // Редакторы
]);
```

---

## Группы пользователей (CGroup)

```php
// Найти группу по строковому коду перед созданием
$existing = CGroup::GetList('', '', ['STRING_ID' => 'CATALOG_EDITORS'])->Fetch();
if ($existing) {
    $groupId = $existing['ID'];
} else {
    // Создать группу
    $group = new CGroup();
    $groupId = $group->Add([
        'NAME'        => 'Редакторы каталога',
        'DESCRIPTION' => 'Могут редактировать товары в каталоге',
        'STRING_ID'   => 'CATALOG_EDITORS',  // уникальный строковый код — удобен для поиска
        'ACTIVE'      => 'Y',
        'C_SORT'      => 100,
    ]);
    if (!$groupId) {
        throw new \RuntimeException('CGroup::Add error: ' . $group->LAST_ERROR);
    }
}

// Изменить группу
$group = new CGroup();
$group->Update($groupId, [
    'NAME' => 'Редакторы каталога и новостей',
]);
```

---

## Управление пользователями (CUser)

```php
// Найти пользователя
$res = CUser::GetList('', '', ['LOGIN' => 'editor@example.ru']);
$user = $res->Fetch();

// Создать пользователя
$user = new CUser();
$userId = $user->Add([
    'LOGIN'          => 'editor',
    'PASSWORD'       => 'SecurePass123!',
    'CONFIRM_PASSWORD' => 'SecurePass123!',
    'EMAIL'          => 'editor@example.ru',
    'NAME'           => 'Иван',
    'LAST_NAME'      => 'Иванов',
    'ACTIVE'         => 'Y',
    'GROUP_ID'       => [$groupId], // сразу назначить группы
]);
if (!$userId) {
    throw new \RuntimeException('CUser::Add error: ' . $user->LAST_ERROR);
}

// Назначить группы пользователю
// ВАЖНО: SetUserGroup ЗАМЕНЯЕТ все группы пользователя (кроме группы 2 = Все)
CUser::SetUserGroup($userId, [
    ['GROUP_ID' => $groupId],
    ['GROUP_ID' => 5],              // ещё одна группа
]);

// Получить группы пользователя
$groups = CUser::GetUserGroup($userId); // возвращает массив ID групп

// Обновить пользователя
$user = new CUser();
$user->Update($userId, [
    'EMAIL' => 'new-email@example.ru',
]);
```

---

## Права модулей для групп (SetGroupRight)

```php
// Установить права модуля для группы пользователей
// $right не универсален для всех модулей.
// В b_module_group хранится строка G_ACCESS, а допустимые значения зависят от модуля.
// Для iblock часто используют R/W/X, но не прошивай это как общий закон Bitrix.

// Глобально для всех сайтов
$APPLICATION->SetGroupRight('iblock', $groupId, 'W');

// Или напрямую:
CMain::SetGroupRight('iblock', $groupId, 'W');

// Для конкретного сайта
CMain::SetGroupRight('iblock', $groupId, 'W', 's1');

// Получить текущий уровень для конкретной группы:
$right = CMain::GetGroupRight('iblock', [$groupId]);

// Или для текущего пользователя:
$right = $APPLICATION->GetGroupRight('iblock');
```

---

## Миграции в Bitrix

### Реальность: в Bitrix нет встроенной системы миграций

Bitrix не имеет встроенного инструмента типа Laravel Artisan Migrate. Используются три подхода:

### Подход 1 — Установщик модуля как миграция (стандартный)

Для создания таблиц и начальных данных при установке модуля:

```php
// install/index.php → InstallDB() + UnInstallDB()
public function InstallDB(): bool
{
    $connection = \Bitrix\Main\Application::getConnection();

    // Создать таблицу через SQL
    if (!$connection->isTableExists('my_module_items')) {
        $connection->queryExecute("
            CREATE TABLE IF NOT EXISTS `my_module_items` (
                `ID` int(11) NOT NULL AUTO_INCREMENT,
                `NAME` varchar(255) NOT NULL DEFAULT '',
                `ACTIVE` char(1) NOT NULL DEFAULT 'Y',
                `SORT` int(11) NOT NULL DEFAULT 500,
                `DATE_CREATE` datetime NOT NULL,
                PRIMARY KEY (`ID`),
                KEY `IDX_ACTIVE` (`ACTIVE`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ");
    }

    // Или через ORM Entity
    MyItemTable::getEntity()->createDbTable();

    \Bitrix\Main\ModuleManager::registerModule($this->MODULE_ID);
    return true;
}
```

### Подход 2 — Скрипты обновления (update/)

Для изменения схемы при обновлении версии модуля:

```
local/modules/vendor.mymodule/
└── install/
    └── db/
        ├── mysql/
        │   ├── install.sql     ← полная схема (для новых установок)
        │   └── uninstall.sql
        └── updates/
            └── v1_1_0.sql      ← только изменения (для обновлений)
```

```php
// В методе DoUpdate() или в событии OnBeforeProlog (через агент)
// Проверяем версию и применяем нужные изменения:

$connection = \Bitrix\Main\Application::getConnection();

// Добавить колонку если не существует
$columns = $connection->query("SHOW COLUMNS FROM `my_module_items` LIKE 'DESCRIPTION'")->fetch();
if (!$columns) {
    $connection->queryExecute("
        ALTER TABLE `my_module_items`
        ADD COLUMN `DESCRIPTION` text NULL AFTER `NAME`
    ");
}

// Добавить индекс если не существует
if (!$connection->isIndexExists('my_module_items', ['SORT'])) {
    $connection->queryExecute("
        CREATE INDEX `IDX_SORT` ON `my_module_items` (`SORT`)
    ");
}

// Удалить колонку
$connection->queryExecute("
    ALTER TABLE `my_module_items` DROP COLUMN IF EXISTS `OLD_FIELD`
");
```

### Подход 3 — Sprint.Migration (популярный пакет)

**Sprint.Migration** (`andreyryabin/sprint.migration`) — де-факто стандарт для миграций в Bitrix. Устанавливается через Composer.

```
local/
└── php_interface/
    └── migrations/
        └── 20240315_120000_CreateCatalogIblock.php
```

```php
// Структура файла миграции
<?php
namespace Sprint\Migration;

class CreateCatalogIblock extends Version
{
    protected $description = 'Создать инфоблок Каталог';

    // Выполнить миграцию
    public function up(): bool
    {
        Loader::includeModule('iblock');

        $ib = new \CIBlock();
        $id = $ib->Add([
            'IBLOCK_TYPE_ID' => 'catalog',
            'LID'            => ['s1'],
            'NAME'           => 'Каталог',
            'CODE'           => 'products',
            'API_CODE'       => 'products',
            'VERSION'        => 2,
            'ACTIVE'         => 'Y',
        ]);

        if (!$id) {
            $this->log('Ошибка: ' . $ib->LAST_ERROR);
            return false;
        }

        $this->log('Инфоблок создан: ID=' . $id);
        return true;
    }

    // Откатить миграцию
    public function down(): bool
    {
        // Найти и удалить
        $res = \Bitrix\Iblock\IblockTable::getList([
            'filter' => ['=CODE' => 'products'],
            'select' => ['ID'],
        ])->fetch();

        if ($res) {
            \CIBlock::Delete($res['ID']);
            $this->log('Инфоблок удалён: ID=' . $res['ID']);
        }
        return true;
    }
}
```

Запуск миграций через консоль (если установлен bitrix-cli):
```bash
php bitrix-cli sprint:migration up
php bitrix-cli sprint:migration down
php bitrix-cli sprint:migration list
```

Или через admin-интерфейс `/bitrix/admin/sprint_migration.php`.

### Проверка схемы через D7 Connection API

```php
$connection = \Bitrix\Main\Application::getConnection();

// Существует ли таблица?
$connection->isTableExists('my_table');       // bool

// Существует ли индекс?
$connection->isIndexExists('my_table', ['SORT', 'ACTIVE']); // bool

// Список полей таблицы: ['NAME' => ['type'=>'varchar', 'length'=>255, ...], ...]
$fields = $connection->getTableFields('my_table');
array_key_exists('DESCRIPTION', $fields);     // проверить наличие колонки

// Выполнить произвольный SQL
$connection->queryExecute("ALTER TABLE `my_table` ADD ...");

// Транзакция
$connection->startTransaction();
try {
    $connection->queryExecute("UPDATE ...");
    $connection->queryExecute("INSERT ...");
    $connection->commitTransaction();
} catch (\Exception $e) {
    $connection->rollbackTransaction();
    throw $e;
}
```

### ORM Entity.createDbTable()

```php
// Создать таблицу из DataManager-класса (полностью по Map)
MyItemTable::getEntity()->createDbTable();

// НЕ поддерживает ALTER — только CREATE.
// Для изменения существующей схемы используй прямой SQL.
```

---

## Полный пример: инфоблок + свойства + права (в InstallDB)

```php
public function InstallDB(): bool
{
    \Bitrix\Main\Loader::requireModule('iblock');

    // 1. Тип инфоблока
    if (!\CIBlockType::GetByID('catalog')->Fetch()) {
        $ibt = new \CIBlockType();
        $ibt->Add([
            'ID'       => 'catalog',
            'SECTIONS' => 'Y',
            'SORT'     => 10,
            'LANG'     => ['ru' => ['NAME' => 'Каталог', 'ELEMENT_NAME' => 'Товар', 'SECTION_NAME' => 'Категория']],
        ]);
    }

    // 2. Инфоблок
    $iblockId = null;
    $existIb = \Bitrix\Iblock\IblockTable::getList(['filter' => ['=CODE' => 'products'], 'select' => ['ID']])->fetch();
    if ($existIb) {
        $iblockId = $existIb['ID'];
    } else {
        $ib = new \CIBlock();
        $iblockId = $ib->Add([
            'IBLOCK_TYPE_ID' => 'catalog',
            'LID'            => ['s1'],
            'NAME'           => 'Товары',
            'CODE'           => 'products',
            'API_CODE'       => 'products',
            'ACTIVE'         => 'Y',
            'VERSION'        => 2,
            'SORT'           => 100,
        ]);
        if (!$iblockId) {
            throw new \RuntimeException($ib->LAST_ERROR);
        }
    }

    // 3. Свойства (только если не созданы)
    $propMap = [
        'ARTICLE'  => ['NAME' => 'Артикул',  'PROPERTY_TYPE' => 'S', 'SORT' => 100],
        'PRICE'    => ['NAME' => 'Цена',     'PROPERTY_TYPE' => 'N', 'SORT' => 200],
        'ACTIVE_FROM' => ['NAME' => 'Активен с', 'PROPERTY_TYPE' => 'S', 'USER_TYPE' => 'DateTime', 'SORT' => 300],
    ];
    foreach ($propMap as $code => $fields) {
        $exists = \Bitrix\Iblock\PropertyTable::getList([
            'filter' => ['=IBLOCK_ID' => $iblockId, '=CODE' => $code],
            'select' => ['ID'],
        ])->fetch();
        if (!$exists) {
            $prop = new \CIBlockProperty();
            $prop->Add(array_merge($fields, ['IBLOCK_ID' => $iblockId, 'CODE' => $code, 'ACTIVE' => 'Y']));
        }
    }

    // 4. Права
    $adminGroup  = 1;
    $allGroup    = 2;
    $editGroupId = \CGroup::GetList('', '', ['STRING_ID' => 'CATALOG_EDITORS'])->Fetch()['ID'] ?? null;

    $perms = [$adminGroup => 'X', $allGroup => 'R'];
    if ($editGroupId) $perms[$editGroupId] = 'W';
    \CIBlock::SetPermission($iblockId, $perms);

    // 5. Права модуля iblock для группы редакторов
    if ($editGroupId) {
        \CMain::SetGroupRight('iblock', $editGroupId, 'W');
    }

    \Bitrix\Main\ModuleManager::registerModule($this->MODULE_ID);
    return true;
}
```

---

## Gotchas

- **`CIBlock::SetPermission` перезаписывает все права** — не "добавляет" к существующим. Всегда передавай полный список групп. Если передать пустой массив — права удалятся у всех.
- **`CUser::SetUserGroup` заменяет все группы** — пользователь выйдет из всех предыдущих групп (кроме группы 2 = Все). Сначала получи текущие группы и объедини: `array_merge(CUser::GetUserGroup($id), [$newGroup])`.
- **`API_CODE` не обязателен для любого ИБ** — но если проект опирается на generated iblock DataClass или REST-связки, лучше задавать его сразу. В текущем core формат проверяется regex `^[a-z][a-z0-9]{0,49}$`, underscore не допускается.
- **`VERSION=2` несовместим с VERSION=1** — при создании нового инфоблока всегда используй `VERSION=2`. Менять версию существующего инфоблока с данными — опасно.
- **`CIBlockPropertyEnum::Add`** — добавлять варианты списка нужно только для `PROPERTY_TYPE='L'`. Получить существующие варианты: `CIBlockPropertyEnum::GetList([], ['PROPERTY_ID' => $propId])`.
- **`createDbTable()` не делает ALTER** — если таблица уже существует, метод бросит SQL-ошибку. Всегда проверяй `isTableExists()` перед вызовом.
- **Sprint.Migration** — при использовании храни конфиг в `local/php_interface/sprint_migration_options.php`. Миграции в git, накатывать на deploy через CI.
- **`isIndexExists`** — принимает точный набор колонок в том же порядке. Составной индекс `['A', 'B']` не найдёт индекс `['B', 'A']`.
- **`GetGroupRight` vs `SetGroupRight`**: первая — для получения прав текущего пользователя, вторая — для установки прав конкретной группы. Разные методы, разные аргументы.
- **Группа `STRING_ID`** — не обязательное поле при создании, но позволяет находить группу без хранения числового ID в коде. Используй осмысленные строковые коды в модулях.
