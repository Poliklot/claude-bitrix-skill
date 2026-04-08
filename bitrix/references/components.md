# Bitrix Компоненты — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с компонентами, CBitrixComponent, шаблонами, кешированием в компонентах, CComponentEngine или Edit Area.
>
> Audit note: ниже сверено с текущим `main/classes/general/component.php`. В этой версии класс компонента действительно ищется через diff `get_declared_classes()` после `include_once(class.php)`, а `startResultCache()` сам открывает tag cache при `BX_COMP_MANAGED_CACHE`.

## Содержание
- Структура компонента: .parameters.php, .description.php, class.php, шаблоны
- CBitrixComponent: жизненный цикл, onPrepareComponentParams, executeComponent
- Кеширование: startResultCache/endResultCache/abortResultCache, тегированный кеш
- Шаблоны: переменные, setFrameMode, AddEditAction, GetEditAreaId
- CComponentEngine: URL-роутинг, #VAR#-шаблоны, addGreedyPart
- ~KEY в arParams

---

## Компоненты

### Архитектурный смысл

Компонент в Bitrix — это **MVC-юнит**: модель (логика в `class.php`), вид (шаблон в `templates/`), параметры (`.parameters.php`). Компонент изолирован, переиспользуем, кешируем.

**Два подхода:**
- **Современный (`class.php`)** — определяет класс, расширяющий `CBitrixComponent`. Переопределяемые методы, автозагрузка, тестируемость.
- **Legacy (`component.php`)** — процедурный файл. Используется если `class.php` отсутствует.

Если `class.php` существует и содержит подкласс `CBitrixComponent`, Bitrix создаёт его экземпляр. Поиск идёт через `get_declared_classes()` после `include_once`: ядро перебирает новые классы, берёт подходящий подкласс `CBitrixComponent`, а если позже встретит более специфический наследник, может заменить ранее выбранный.

### Имя и путь компонента

```
bitrix:news.list
├── namespace: bitrix
├── name: news.list
└── path: /bitrix/news.list → bitrix/components/bitrix/news.list/
```

Поиск компонента: `local/components/` → `bitrix/components/`. Правило:
```
namespace:name.subname → /namespace/name.subname/
```

### Структура компонента

```
bitrix/components/vendor/my.component/
├── .description.php         ← мета-информация, иконка, путь в дереве
├── .parameters.php          ← описание параметров (для визуального редактора)
├── class.php                ← D7-класс компонента (рекомендуется)
├── component.php            ← legacy-режим (если нет class.php)
├── lang/
│   ├── ru/
│   │   └── class.php        ← переводы
│   └── en/
└── templates/
    ├── .default/            ← шаблон по умолчанию
    │   ├── template.php     ← HTML-шаблон
    │   ├── script.js
    │   ├── style.css
    │   ├── .parameters.php  ← параметры специфичные для шаблона
    │   └── lang/
    └── my_template/         ← кастомный шаблон (переопределяется в local/)
```

### .description.php

```php
<?php
if (!defined('B_PROLOG_INCLUDED') || B_PROLOG_INCLUDED !== true) die();

$arComponentDescription = [
    'NAME'        => GetMessage('MY_COMPONENT_NAME'),
    'DESCRIPTION' => GetMessage('MY_COMPONENT_DESC'),
    'ICON'        => '/images/icon.png',
    'SORT'        => 20,
    'CACHE_PATH'  => 'Y',  // компонент поддерживает кеш по пути
    'PATH'        => [
        'ID'    => 'content',
        'CHILD' => ['ID' => 'my_group'],
    ],
];
```

### .parameters.php

```php
<?php
if (!defined('B_PROLOG_INCLUDED') || B_PROLOG_INCLUDED !== true) die();
/** @var array $arCurrentValues */

$arComponentParameters = [
    'GROUPS' => [
        'SETTINGS' => ['NAME' => 'Настройки'],
    ],
    'PARAMETERS' => [
        'IBLOCK_ID' => [
            'PARENT'  => 'SETTINGS',
            'NAME'    => 'ID инфоблока',
            'TYPE'    => 'STRING',
            'DEFAULT' => '',
        ],
        'CACHE_TIME' => ['DEFAULT' => 3600],  // стандартный параметр кеша
    ],
];
```

### class.php — современный компонент

```php
<?php
if (!defined('B_PROLOG_INCLUDED') || B_PROLOG_INCLUDED !== true) die();

use Bitrix\Main\Loader;
use Bitrix\Main\Localization\Loc;

Loader::includeModule('iblock');

class MyVendorComponent extends CBitrixComponent
{
    /**
     * Вызывается ДО executeComponent(). Нормализует входные параметры.
     * ВАЖНО: параметры автоматически HTML-экранируются после этого метода.
     * Для raw-значений используй $this->arParams['~KEY'].
     */
    public function onPrepareComponentParams($arParams): array
    {
        $arParams['IBLOCK_ID'] = (int)($arParams['IBLOCK_ID'] ?? 0);
        $arParams['CACHE_TIME'] = (int)($arParams['CACHE_TIME'] ?? 3600);
        return $arParams;
    }

    /**
     * Основная точка входа. По умолчанию вызывает __includeComponent() → component.php.
     * При наличии class.php лучше переопределить этот метод.
     */
    public function executeComponent(): mixed
    {
        // Кеширование
        if ($this->startResultCache($this->arParams['CACHE_TIME'])) {
            $this->arResult = $this->getData();

            // Управление кешем через теги (BX_COMP_MANAGED_CACHE)
            global $CACHE_MANAGER;
            $CACHE_MANAGER->RegisterTag('iblock_id_' . $this->arParams['IBLOCK_ID']);
        }

        // includeComponentTemplate() вызывает endResultCache() автоматически
        $this->includeComponentTemplate();

        return $this->arResult;
    }

    private function getData(): array
    {
        // логика выборки...
        return ['ITEMS' => []];
    }

    /**
     * Ключи параметров, которые войдут в signedParameters.
     * Нужно для безопасной передачи ID инфоблока в AJAX-запросах.
     */
    protected function listKeysSignedParameters(): array
    {
        return ['IBLOCK_ID'];
    }
}
```

### Кеширование компонентов — детали

Кеш компонента управляется тремя параметрами, которые Bitrix обрабатывает автоматически:
- `CACHE_TYPE`: `Y` = всегда кешировать, `N` = никогда, `A` = по системной настройке
- `CACHE_TIME`: время жизни в секундах
- Ключ кеша = `SITE_ID + LANGUAGE_ID + TEMPLATE_ID + component_name + template_name + all_params + timezone_offset`

```php
// Паттерн кеширования
public function executeComponent(): mixed
{
    // startResultCache() возвращает true при CACHE MISS (нужно выполнить)
    // и false при CACHE HIT (arResult уже восстановлен из кеша)
    if ($this->startResultCache()) {
        // Тут выполняется только при cache miss
        $userId = $this->request->getQuery('user_id');
        if (!$userId) {
            // КРИТИЧНО: если выходим досрочно — обязателен abortResultCache()
            // иначе незакрытый кеш сохранится как пустой
            $this->abortResultCache();
            return null;
        }

        $this->arResult = $this->loadData();
    }

    // includeComponentTemplate() автоматически вызывает endResultCache()
    // Кешируются: arResult, CSS/JS, NavNum, дочерние компоненты
    $this->includeComponentTemplate();

    return $this->arResult;
}

// Инвалидация кеша конкретного компонента
CBitrixComponent::clearComponentCache('vendor:my.component', SITE_ID);

// Тегированный кеш (управляемый кеш):
// После изменения инфоблока с ID=5 инвалидирует все компоненты с тегом
BXClearCache(true, '/bitrix/cache/...'); // низкоуровнево
// Через CACHE_MANAGER (если BX_COMP_MANAGED_CACHE defined):
global $CACHE_MANAGER;
$CACHE_MANAGER->ClearByTag('iblock_id_5');
```

**Gotcha: `arParams['~KEY']`** — после `onPrepareComponentParams()` и `__prepareComponentParams()` все строковые параметры HTML-экранируются. Raw-значение доступно через `$this->arParams['~IBLOCK_ID']`. Это сделано для безопасности шаблонов.

**Gotcha: `arResultCacheKeys`** — после шаблона Bitrix урежет `arResult` до перечисленных ключей и уже этот сокращённый набор сохранит в кеш. Сам шаблон при этом ещё видит полный `arResult`.

```php
// Кешируем только часть arResult
$this->arResultCacheKeys = ['ITEMS', 'TOTAL_COUNT'];
// CURRENT_USER и другие personalised-данные не кешируются
```

### Шаблон компонента

```php
<?php
// templates/.default/template.php
if (!defined('B_PROLOG_INCLUDED') || B_PROLOG_INCLUDED !== true) die();

/**
 * @var CBitrixComponentTemplate $this
 * @var array $arParams       параметры компонента (HTML-экранированы)
 * @var array $arResult       результат компонента
 * @var CBitrixComponent $component  объект компонента
 * @var CMain $APPLICATION
 * @var CUser $USER
 */

// Включает composite caching (статические блоки)
$this->setFrameMode(true);
?>
<div class="my-list">
    <?php foreach ($arResult['ITEMS'] as $item): ?>
        <?php
        // Кнопки редактирования/удаления в режиме правки
        $this->AddEditAction($item['ID'], $item['EDIT_LINK'], 'Редактировать');
        $this->AddDeleteAction($item['ID'], $item['DELETE_LINK'], 'Удалить', ['CONFIRM' => 'Удалить?']);
        ?>
        <div id="<?= $this->GetEditAreaId($item['ID']) ?>">
            <?= htmlspecialcharsEx($item['NAME']) ?>
        </div>
    <?php endforeach ?>
</div>
```

### Подключение компонента на странице

```php
<?php
// В .php-файле страницы (внутри шаблона сайта)
$APPLICATION->IncludeComponent(
    'vendor:my.component',  // имя компонента
    '',                     // имя шаблона ('' = .default)
    [                       // параметры
        'IBLOCK_ID'  => 5,
        'CACHE_TIME' => 3600,
    ],
    false                   // родительский компонент или false
);

// Из другого компонента (class.php)
$this->includeComponent(
    'bitrix:news.list',
    '.default',
    ['IBLOCK_ID' => $this->arParams['IBLOCK_ID']],
    $this  // передаём себя как родителя для наследования CSS/JS
);
```

### CComponentEngine — URL-роутинг в компонентах

`CComponentEngine` используется внутри компонента для определения текущей "страницы" по URL. Это Legacy-механизм, альтернатива D7-роутингу для компонентов.

```php
// В component.php или executeComponent()
$arUrlTemplates = [
    'list'   => 'catalog/',
    'section'=> 'catalog/#SECTION_CODE#/',
    'detail' => 'catalog/#SECTION_CODE#/#ELEMENT_CODE#/',
];

$arVariables = [];
$componentPage = CComponentEngine::parseComponentPath(
    $arParams['SEF_FOLDER'],  // базовый путь, например '/catalog/'
    $arUrlTemplates,
    $arVariables              // сюда запишутся SECTION_CODE и ELEMENT_CODE
    // 4й аргумент = requestURL, если false — берётся текущий
);

// $componentPage = 'detail' если URL = /catalog/phones/iphone-15/
// $arVariables['SECTION_CODE'] = 'phones'
// $arVariables['ELEMENT_CODE'] = 'iphone-15'

// Для URL с несколькими сегментами (путь категорий) пометить переменную "жадной"
$engine = new CComponentEngine($this);
$engine->addGreedyPart('SECTION_CODE');  // SECTION_CODE может содержать /
$componentPage = $engine->guessComponentPath($folder, $arUrlTemplates, $arVariables);
```

---
