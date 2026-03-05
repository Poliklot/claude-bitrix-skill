# SEF URLs / ЧПУ в Bitrix

## Как работает urlrewrite

При каждом запросе Bitrix подключает `/bitrix/modules/main/include/urlrewrite.php`, который:
1. Загружает массив `$arUrlRewrite` из корневого `urlrewrite.php` сайта
2. Итерирует правила (уже отсортированы по приоритету)
3. Для каждого правила: `preg_match(CONDITION, $requestUri)`
4. При совпадении:
   - Если RULE пуст — редиректит на PATH
   - Если RULE есть — `preg_replace(CONDITION, PATH.'?'.RULE, URI)` → `parse_str` → заполняет `$_GET`
5. Включает найденный PHP-файл и прекращает обработку

### Формат записи в `urlrewrite.php`

```php
// Корневой /urlrewrite.php сайта
$arUrlRewrite = [
    [
        'CONDITION' => '#^/travels/([^/]+?)/?(\?.*)?$#',  // регулярка для preg_match
        'RULE'      => 'type=$1&$2',                       // шаблон для preg_replace
        'ID'        => 'travels.type',                     // произвольный идентификатор
        'PATH'      => '/travels/index.php',               // файл-обработчик
        'SORT'      => 100,                                // меньше = выше приоритет
    ],
];
```

**Backreferences в RULE:** `$1`, `$2` … соответствуют скобочным группам в CONDITION.

**Итоговый URL:** `preg_replace(CONDITION, PATH.'?'.RULE, $requestUri)`
Пример: `/travels/russia/` → `/travels/index.php?type=russia&`

### Переменные в SEF_RULE

| Суффикс переменной | Regex в CONDITION | Пример |
|---------------------|-------------------|--------|
| обычная (`#TYPE#`) | `([^/]+?)` | совпадает с одним сегментом пути |
| `_PATH` (`#SECTION_PATH#`) | `(.+?)` | совпадает с несколькими сегментами |

---

## D7 API: `\Bitrix\Main\UrlRewriter`

```php
use Bitrix\Main\UrlRewriter;

// Добавить правило (не добавляет дубликат по CONDITION)
UrlRewriter::add('s1', [
    'CONDITION' => '#^/travels/([^/]+?)/?(\?.*)?$#',
    'RULE'      => 'type=$1&$2',
    'ID'        => 'travels.type',
    'PATH'      => '/travels/index.php',
    'SORT'      => 100,
]);

// Обновить существующее правило
UrlRewriter::update('s1', [
    'CONDITION' => '#^/travels/([^/]+?)/?(\?.*)?$#',  // ключ поиска
], [
    'RULE' => 'type=$1&$2',
    'SORT' => 50,
]);

// Удалить правило
UrlRewriter::delete('s1', ['CONDITION' => '#^/travels/([^/]+?)/?(\?.*)?$#']);

// Переиндексировать из компонентов (пересоздать urlrewrite.php)
UrlRewriter::reindexFile('s1');
```

Первый параметр — `SITE_ID` ('s1', 's2' и т.д.).

После `add/delete` правила автоматически пересортировываются: сначала по SORT, затем по убыванию длины CONDITION (более специфичные — выше).

---

## Компонент с SEF_MODE=Y

```php
// /travels/index.php
$APPLICATION->IncludeComponent(
    'bitrix:catalog.section',
    'travels',
    [
        'SEF_MODE'   => 'Y',
        'SEF_FOLDER' => '/travels/',           // базовый URL-путь
        'SEF_RULE'   => 'travels/#TYPE#/',     // шаблон → CONDITION+RULE в urlrewrite
        // остальные параметры компонента
        'IBLOCK_ID'  => 5,
    ]
);
```

**Как Bitrix генерирует urlrewrite-запись из SEF_RULE:**

`UrlRewriterRuleMaker::process('travels/#TYPE#/')` создаёт:
- `CONDITION` = `#^/travels/([^/]+?)\??(.*)#`
- `RULE` = `TYPE=$1&$2`
- `PATH` = `/travels/index.php`

Запись автоматически добавляется/обновляется в `urlrewrite.php` при первом вызове компонента в режиме SEF.

### Чтение SEF-параметров внутри компонента

```php
// В component.php или template.php
$sefFolder = $this->arParams['SEF_FOLDER']; // '/travels/'

// CComponentEngine разбирает текущий URL относительно SEF_FOLDER
$componentEngine = new CComponentEngine($this);
$variables = [];
$defaultPage = 'list';
$urlTemplates = [
    'list'   => '',
    'detail' => '#TYPE#/#CODE#/',
];
$page = $componentEngine->guessComponentPath(
    $sefFolder,
    $urlTemplates,
    $variables
);
// $variables['TYPE'], $variables['CODE'] — разобранные из URL
```

---

## Практика: перевод `travels/?type=russia` → `travels/russia/`

### 1. Добавляем новое SEF-правило

```php
use Bitrix\Main\UrlRewriter;

// Новый красивый URL
UrlRewriter::add('s1', [
    'CONDITION' => '#^/travels/([^/]+?)/?(\?.*)?$#',
    'RULE'      => 'type=$1&$2',
    'ID'        => 'travels.sef',
    'PATH'      => '/travels/index.php',
    'SORT'      => 100,
]);
```

### 2. Редирект со старых URL (301)

В `/travels/index.php` или в компоненте — до `IncludeComponent`:

```php
use Bitrix\Main\Application;
use Bitrix\Main\Web\HttpClient;

$request = Application::getInstance()->getContext()->getRequest();
$type = $request->getQuery('type');

// Если пришли по старому URL (?type=...) — редиректим на ЧПУ
if ($type !== null && !preg_match('#^/travels/[^/?]+/#', $request->getRequestUri())) {
    $response = Application::getInstance()->getContext()->getResponse();
    $response->redirect('/travels/' . rawurlencode($type) . '/', true); // true = 301
    $response->flush('');
    die();
}
```

### 3. Компонент принимает тип из URL

```php
$APPLICATION->IncludeComponent(
    'my:travels.list',
    '',
    [
        'SEF_MODE'   => 'Y',
        'SEF_FOLDER' => '/travels/',
        'SEF_RULE'   => 'travels/#TYPE#/',
        'IBLOCK_ID'  => 5,
    ]
);
```

Внутри `component.php` переменная `$arResult['TYPE']` = `russia` берётся из `$_GET['TYPE']`, который заполнил urlrewrite.

---

## Сортировка и фильтрация элементов инфоблока

Типовой паттерн: GET-параметры → arFilter/arOrder в компоненте. Фильтрация всегда на стороне сервера через `CIBlockElement::GetList` или ORM.

### Параметры фильтра из URL

```
/catalog/?PRICE_FROM=1000&PRICE_TO=5000&BRAND=nike&SORT=PRICE&ORDER=ASC
```

### Компонент: безопасная сборка фильтра

```php
// В component.php
use Bitrix\Main\Application;

$request = Application::getInstance()->getContext()->getRequest();

// Белый список допустимых GET-параметров фильтра
$allowedProps = ['BRAND', 'COLOR', 'SIZE'];
$arFilter = [
    'IBLOCK_ID' => $this->arParams['IBLOCK_ID'],
    'ACTIVE'    => 'Y',
];

// Числовой диапазон цены
$priceFrom = (int)$request->getQuery('PRICE_FROM');
$priceTo   = (int)$request->getQuery('PRICE_TO');
if ($priceFrom > 0) {
    $arFilter['>=CATALOG_PRICE_1'] = $priceFrom;
}
if ($priceTo > 0) {
    $arFilter['<=CATALOG_PRICE_1'] = $priceTo;
}

// Свойства из белого списка
foreach ($allowedProps as $propCode) {
    $val = $request->getQuery($propCode);
    if ($val !== null && $val !== '') {
        $arFilter['PROPERTY_' . $propCode] = $val;
    }
}

// Сортировка из белого списка
$allowedSort  = ['NAME', 'PRICE', 'SORT', 'DATE_CREATE'];
$allowedOrder = ['ASC', 'DESC'];
$sortField = strtoupper($request->getQuery('SORT') ?? 'SORT');
$sortOrder = strtoupper($request->getQuery('ORDER') ?? 'ASC');

if (!in_array($sortField, $allowedSort, true))  { $sortField = 'SORT'; }
if (!in_array($sortOrder, $allowedOrder, true)) { $sortOrder = 'ASC'; }

$arSort = [$sortField => $sortOrder];

// Запрос
$res = CIBlockElement::GetList(
    $arSort,
    $arFilter,
    false,
    ['nPageSize' => 20, 'iNumPage' => max(1, (int)$request->getQuery('PAGEN_1'))],
    ['ID', 'NAME', 'PROPERTY_BRAND', 'PROPERTY_COLOR']
);
```

**Gotchas:**
- Никогда не передавай `$_GET`/`$_POST` напрямую в arFilter — только через белый список
- `CATALOG_PRICE_1` — цена прайс-листа с ID=1; для других прайс-листов меняй цифру
- Пагинация Bitrix: `PAGEN_1` — номер страницы для первого компонента постранички на странице

### SEF + фильтр вместе

Если нужны и ЧПУ-сегменты, и GET-фильтр:

```
/catalog/russia/?COLOR=red&SORT=PRICE
```

urlrewrite разбирает `/catalog/russia/` → `TYPE=russia`, затем Bitrix добавляет GET-параметры `COLOR` и `SORT` из строки запроса — они доступны одновременно.

---

## CComponentEngine: детальные страницы

```php
// Несколько шаблонов URL в одном компоненте
$urlTemplates = [
    'list'   => '',                    // /catalog/
    'section'=> '#SECTION_CODE#/',     // /catalog/chairs/
    'detail' => '#SECTION_CODE#/#CODE#/', // /catalog/chairs/item-slug/
];

$variables = [];
$page = $componentEngine->guessComponentPath(
    '/catalog/',
    $urlTemplates,
    $variables
);
// $page = 'detail', $variables = ['SECTION_CODE' => 'chairs', 'CODE' => 'item-slug']

// Генерация URL обратно
$detailUrl = $componentEngine->makePathFromTemplate(
    '/catalog/#SECTION_CODE#/#CODE#/',
    ['SECTION_CODE' => 'chairs', 'CODE' => 'item-slug']
);
// → '/catalog/chairs/item-slug/'
```

---

## Программная работа с urlrewrite.php напрямую

Когда нужно массово перезаписать правила (например, в миграции):

```php
use Bitrix\Main\IO\File;

$siteId = 's1';
$urlRewriteFile = Application::getInstance()->getDocumentRoot()
    . BX_PERSONAL_ROOT . '/urlrewrite.php'; // обычно /bitrix/urlrewrite.php

// Читаем текущие правила
$arUrlRewrite = [];
if (file_exists($urlRewriteFile)) {
    include $urlRewriteFile;
}

// Добавляем своё
$arUrlRewrite[] = [
    'CONDITION' => '#^/travels/([^/]+?)/?(\?.*)?$#',
    'RULE'      => 'type=$1&$2',
    'ID'        => 'travels.sef',
    'PATH'      => '/travels/index.php',
    'SORT'      => 100,
];

// Сортируем: сначала по SORT, потом по убыванию длины CONDITION
usort($arUrlRewrite, function($a, $b) {
    if ($a['SORT'] !== $b['SORT']) return $a['SORT'] <=> $b['SORT'];
    return strlen($b['CONDITION']) <=> strlen($a['CONDITION']);
});

// Записываем обратно (как это делает UrlRewriter::saveRules)
File::putFileContents(
    $urlRewriteFile,
    "<?php\n\$arUrlRewrite=" . var_export($arUrlRewrite, true) . ";\n"
);
```

> **Gotcha:** после ручной правки `urlrewrite.php` нужно сбросить кеш страниц или дождаться следующего запроса — файл читается при каждом хите, кеша нет.
