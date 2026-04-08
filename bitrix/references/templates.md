# Шаблоны сайта

## Audit note

Проверено по текущему core:
- `www/bitrix/modules/main/classes/general/main.php`
- `www/bitrix/modules/main/lib/page/assetlocation.php`
- `www/bitrix/modules/main/classes/general/component_template.php`
- `www/bitrix/modules/main/tools.php`

## Структура шаблона

```
/local/templates/<template_name>/        (или /bitrix/templates/)
├── header.php          ← верхняя часть страницы (до <body> / начало тела)
├── footer.php          ← нижняя часть страницы
├── styles.css          ← основные стили шаблона
├── script.js           ← основные скрипты шаблона
├── .parameters.php     ← настройки шаблона (области, стили)
├── images/             ← картинки шаблона
├── components/         ← кастомизированные шаблоны компонентов
│   └── bitrix/         ← пространство имён компонента
│       └── news.list/  ← имя компонента
│           └── my_tpl/ ← имя шаблона компонента
│               ├── template.php
│               └── style.css
└── areas/              ← динамические области (необязательно)
```

---

## header.php и footer.php

### Типичный `header.php`

```php
<?php
// Получить данные страницы, задать мета-теги до ShowHead()
$APPLICATION->SetTitle('Главная');
?><!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <?php $APPLICATION->ShowHead(); ?>      <!-- robots, keywords, description, canonical, CSS, JS -->
    <title><?php $APPLICATION->ShowTitle(); ?></title>
</head>
<body class="<?php echo SITE_TEMPLATE_ID; ?>">
<?php $APPLICATION->ShowPanel(); ?>         <!-- панель редактирования (для авторизованных) -->
```

### Типичный `footer.php`

```php
<?php $APPLICATION->ShowBodyScripts(); ?>   <!-- JS в конце body -->
</body>
</html>
```

---

## $APPLICATION — работа с шаблоном

### Заголовок и мета

```php
// В PHP-файле страницы или component.php — до вывода
global $APPLICATION;

$APPLICATION->SetTitle('Название страницы');

// Мета-теги (выводятся через ShowHead() в header.php)
$APPLICATION->SetPageProperty('keywords',    'ключевые, слова');
$APPLICATION->SetPageProperty('description', 'Описание страницы');
$APPLICATION->SetPageProperty('robots',      'noindex, nofollow');
$APPLICATION->SetPageProperty('canonical',   'https://example.com/page/');

// Прочитать
$title = $APPLICATION->GetTitle();                  // текущий заголовок
$desc  = $APPLICATION->GetPageProperty('description');
```

### Хлебные крошки

```php
// Добавить элемент в цепочку (в component.php или .php страницы)
$APPLICATION->AddChainItem('Каталог', '/catalog/');
$APPLICATION->AddChainItem('Категория', '/catalog/chairs/');
$APPLICATION->AddChainItem('Товар');  // без URL = текущая страница

// Стандартный способ вывода — компонент bitrix:breadcrumb.
// Важно: GetNavChain() в текущем core возвращает готовую HTML-строку, а не массив элементов.
echo $APPLICATION->GetNavChain();
```

---

## Подключение JS и CSS

### D7 Asset (правильный способ)

```php
use Bitrix\Main\Page\Asset;
use Bitrix\Main\Page\AssetLocation;

$asset = Asset::getInstance();

// Добавить CSS
$asset->addCss('/local/templates/my_tpl/styles/custom.css');

// Добавить JS-файл
$asset->addJs('/local/templates/my_tpl/js/custom.js');

// Инлайн-строка в head (после JS-ядра, по умолчанию)
$asset->addString('<script>var myVar = "value";</script>');

// Указать место вывода
$asset->addString(
    '<script>console.log("after js");</script>',
    false,                           // $unique — не дублировать
    AssetLocation::AFTER_JS          // константа места
);
```

### Константы AssetLocation

| Константа | Где выводится |
|-----------|--------------|
| `BEFORE_CSS` | перед CSS |
| `AFTER_CSS` | после CSS, до JS |
| `AFTER_JS_KERNEL` | после JS-ядра Bitrix (по умолчанию) |
| `AFTER_JS` | в самом конце `<head>` |
| `BODY_END` | перед `</body>` |

### Legacy-способы (встречаются в старом коде)

```php
// В шаблоне или .php файле
$APPLICATION->AddHeadString('<link rel="stylesheet" href="/css/style.css">');
$APPLICATION->AddHeadScript('/js/script.js');

// Из шаблона компонента — через $this
$this->addExternalCss($this->GetFolder() . '/style.css');
$this->addExternalJs($this->GetFolder() . '/script.js');
```

---

## .parameters.php — настройки шаблона

Определяет доступные CSS-стили и области для сайта:

```php
<?php
// /local/templates/my_tpl/.parameters.php

$arTemplateParameters = [];      // параметры, доступные в $arParams шаблона

// Области шаблона (можно включать компоненты программно)
$arAreas = [
    'sidebar' => [
        'name'        => 'Боковая панель',
        'type'        => 'component',
        'component'   => 'bitrix:menu',
        'template'    => 'sidebar',
        'params'      => ['MAX_LEVEL' => 2],
        'separator'   => 'delim',
    ],
];
```

---

## Шаблон компонента

### Расположение

```
/local/templates/<site_tpl>/components/<namespace>/<component>/<template_name>/
/local/components/<namespace>/<component>/templates/<template_name>/   ← приоритет выше
/bitrix/components/<namespace>/<component>/templates/<template_name>/
```

### Доступные переменные в `template.php`

```php
// Переменные, доступные без объявления:
$arResult       // данные из компонента (заполнены в component.php)
$arParams       // параметры компонента (переданы при вызове)
$this           // объект шаблона CBitrixComponentTemplate

// Путь к шаблону компонента
$this->GetFolder()                      // /local/templates/my_tpl/components/...

// Путь к файлам site-template через $APPLICATION
global $APPLICATION;
$APPLICATION->GetTemplatePath('/images/logo.svg');

// Добавить CSS/JS из шаблона компонента
$this->addExternalCss($this->GetFolder() . '/style.css');
$this->addExternalJs($this->GetFolder() . '/script.js');
```

### Переменные окружения в любом шаблоне

```php
SITE_ID           // 's1' — идентификатор сайта
SITE_DIR          // '/' — корень сайта (для мультисайтов может быть '/ru/')
SITE_TEMPLATE_ID  // 'my_tpl' — имя шаблона
SITE_TEMPLATE_PATH // '/local/templates/my_tpl' — путь к шаблону
LANGUAGE_ID       // 'ru' — язык сайта
LANG              // 'ru' — то же самое
```

---

## component_epilog.php и component_prolog.php

Выполняются до/после шаблона компонента, но **вне кешируемого блока**:

```php
// /local/templates/my_tpl/components/bitrix/news.list/my_tpl/component_prolog.php
// Выполняется ВСЕГДА, даже при выдаче из кеша
// Используется для: AddChainItem, SetTitle, SetPageProperty

global $APPLICATION;
if (!empty($arResult['META_TITLE'])) {
    $APPLICATION->SetTitle($arResult['META_TITLE']);
}
```

```php
// component_epilog.php — выполняется после шаблона
// Используется для: SEO-данных, финальных изменений
```

---

## Работа с HTTP-статусом и редиректами

```php
global $APPLICATION;

// Установить HTTP-статус страницы
$APPLICATION->SetStatus('404 Not Found');
$APPLICATION->SetStatus('403 Forbidden');

// Редирект
LocalRedirect('/new-url/');                                   // 302 Found
LocalRedirect('/new-url/', false, '301 Moved Permanently');   // 301
LocalRedirect('/new-url/', true, '302 Found');                // true = skip_security_check

// D7-способ
use Bitrix\Main\Application;
$response = Application::getInstance()->getContext()->getResponse()->redirectTo('/new-url/');
$response->flush('');
```

---

## Composite cache и шаблоны

Composite (статический HTML-кеш) кеширует **весь HTML страницы**. Части, которые не должны кешироваться (корзина, имя пользователя), выносятся в динамические блоки:

```php
// В шаблоне компонента или template.php:
if ($this->__component->StartResultCache()) {
    // кешируемая часть
    ...
    $this->__component->EndResultCache();
} else {
    // при выдаче из composite-кеша эта часть НЕ выполняется
}
```

Компонент в **Frame-режиме** (динамический блок, не кешируется composite):

```php
// В component.php
$this->setFrameMode(true);   // этот компонент всегда рендерится динамически
```

### Что НЕ кешировать composite:
- Корзина, сумма заказов
- Имя авторизованного пользователя
- Персональные данные
- CSRF-токены

---

## Gotchas

- `SetTitle`, `SetPageProperty` надо вызывать **до** того как `ShowHead()` сработает в header.php — т.е. в component_prolog.php, не в template.php
- У `CBitrixComponentTemplate` в текущем core нет подтверждённого `$this->GetTemplatePath(...)`: для URL ресурса шаблона компонента используй `$this->GetFolder() . '/img.png'`
- Если нужен серверный путь к ресурсу шаблона компонента, собирай его явно: `$_SERVER['DOCUMENT_ROOT'] . $this->GetFolder() . '/img.png'`
- `Asset::addCss/addJs` дедублирует по пути — можно вызывать несколько раз без дублей
- В `component_epilog.php` переменная `$arResult` доступна, в `component_prolog.php` — нет (компонент ещё не выполнен)
- `SITE_TEMPLATE_PATH` — URL-путь к шаблону (без хоста), удобен для построения URL ресурсов
