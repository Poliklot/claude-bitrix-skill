# Структура публичной части и включаемые области

> Reference для задач “куда положить код”, “где подключить компонент”, “как сделать редактируемый блок”, “что должно быть в `header.php`/`footer.php`/`index.php`”, “как работает `.section.php`”. Это проектные эвристики, а не универсальная файловая схема: сначала найди фактический public root, активный шаблон и соглашения текущего репозитория.

## Содержание

- [Сначала факт проекта](#сначала-факт-проекта)
- [Карта слоёв](#карта-слоёв)
- [Страница и раздел](#страница-и-раздел)
- [Шаблон сайта](#шаблон-сайта)
- [Компонент и его шаблон](#компонент-и-его-шаблон)
- [Редактируемые фрагменты](#редактируемые-фрагменты)
- [Отложенные области](#отложенные-области)
- [Проверка после изменения](#проверка-после-изменения)

## Сначала факт проекта

Не предполагай, что public root называется `www`, активный шаблон — `main`, а включаемые файлы лежат в `/include`. Проверь:

```bash
find . -maxdepth 3 -type f \( -name 'dbconn.php' -o -name '.settings.php' -o -name 'urlrewrite.php' \) -print
find . -maxdepth 5 -type f \( -name header.php -o -name footer.php -o -name '.section.php' \) -print
find local bitrix/templates www/bitrix/templates -path '*components/*' -type f 2>/dev/null | sort
rg -n 'SITE_TEMPLATE_ID|SITE_TEMPLATE_PATH|IncludeComponent\(|IncludeFile\(|main\.include|ShowViewContent|SetViewTarget|AddViewContent' \
  . --glob '*.php' --glob '!upload/**' --glob '!bitrix/cache/**' --glob '!www/bitrix/cache/**'
```

Зафиксируй:

```text
public root:
активный шаблон или кандидаты:
страница/раздел:
фактический IncludeComponent/IncludeFile:
project include convention:
local override:
stock source и версия модуля:
```

Активный шаблон может зависеть от сайта, условия назначения или запроса. Наличие папки в `local/templates` ещё не доказывает, что она используется.

## Карта слоёв

| Задача | Предпочтительный слой | Не начинать с |
|---|---|---|
| Заголовок/SEO страницы | свойства страницы/раздела, параметры компонента, `component_epilog.php` | ручные `<meta>` в каждой странице |
| Точка входа раздела | `<section>/index.php` + один подходящий комплексный компонент, если его контракт подтверждён | разнесённые list/detail без проверки routing |
| Глобальная оболочка | активный `header.php`/`footer.php` project-owned шаблона в `local/templates` или `bitrix/templates` | правка системного/vendor-шаблона или core без подтверждения ownership |
| Редактируемый фрагмент | принятый проектом `IncludeFile`/`bitrix:main.include`, свойство страницы или инфоблок | текст в stock template/core |
| HTML компонента | copied template в активном шаблоне | копирование всего stock component |
| Подготовка данных к выводу | `result_modifier.php` для лёгкой подготовки; service/component class для запросов и правил | SQL/API write в `template.php` |
| Повторно используемая логика | service/local module/custom component | большой helper в `init.php` без контракта |
| Персональный глобальный блок | component cache key + composite dynamic boundary | общий кешированный HTML пользователя |

Это default-маршрут. Если проект уже использует module view, Twig, собственный page builder или другой контролируемый слой, следуй ему и назови отличие.

## Страница и раздел

Типовая публичная страница подключает системные пролог/эпилог через `DOCUMENT_ROOT`:

```php
<?php
require $_SERVER['DOCUMENT_ROOT'] . '/bitrix/header.php';

$APPLICATION->SetTitle('Заголовок страницы');

// Фактические components/includes страницы.

require $_SERVER['DOCUMENT_ROOT'] . '/bitrix/footer.php';
```

Не используй `require '/bitrix/header.php'`: это filesystem-root, а не document root сайта.

### `.section.php`

В типовом Bitrix-разделе `.section.php` задаёт данные раздела до выполнения его `index.php`:

```php
<?php
$sSectionName = 'О компании';
$arDirProperties = [
    'title' => 'О компании',
    'description' => 'Описание раздела',
];
```

Проверяй проектный файл и наследование, а не обещай одинаковое поведение для всех свойств. Разделяй:

- `$sSectionName` — название раздела/элемент навигационной цепочки;
- `$arDirProperties` — свойства раздела;
- `$APPLICATION->SetTitle()` — заголовок страницы/H1 в зависимости от шаблона;
- `$APPLICATION->SetPageProperty()` — browser title/meta/другое свойство страницы;
- SEO-параметры компонента — могут установить значения позже через отложенный вывод.

Для вопроса “почему значение не применилось” проверь порядок вызовов, параметры `SET_*`, `component_epilog.php`, кеш компонента и composite second pass.

### Простая или комплексная страница

- Несколько независимых блоков главной/лендинга могут быть отдельными простыми компонентами.
- Раздел list/detail с ЧПУ обычно имеет одну точку входа и один подтверждённый комплексный компонент.
- Не выбирай `bitrix:catalog` только по слову “каталог”: `catalog.*` public components могут находиться в `iblock`, но торговые цены/SKU/остатки требуют подтверждённых `catalog`/`sale`/`currency`.

## Шаблон сайта

`header.php` и `footer.php` отвечают за общую оболочку, но конкретное размещение блоков остаётся соглашением проекта.

### Обычно глобальный слой

- `ShowHead()`, `ShowTitle()`, `ShowPanel()`;
- layout, меню, общие контакты, footer navigation;
- site-wide Asset/CSS/JS;
- глобальные modal roots/виджеты, если они действительно нужны на всех страницах.

### Обычно слой страницы/раздела

- основной `bitrix:news`, `bitrix:catalog` или другой content component;
- параметры выборки и фильтра;
- блоки, относящиеся только к странице;
- breadcrumbs, если проект не выводит их централизованно;
- page-specific SEO и assets.

Не превращай таблицу размещения в запрет: сначала найди фактический `header.php`, `footer.php`, page wrapper и проектный layout. Тяжёлый `news.list` в header допустим только после проверки необходимости, cache key, прав и composite-персонализации.

## Компонент и его шаблон

Фактический путь включает отдельные namespace и component name:

```text
local/templates/<site-template>/components/<namespace>/<component>/<template>/
local/components/<namespace>/<component>/templates/<template>/
bitrix/templates/<site-template>/components/<namespace>/<component>/<template>/
<public-root>/bitrix/components/<namespace>/<component>/templates/<template>/
<public-root>/bitrix/modules/<module>/install/components/<namespace>/<component>/templates/<template>/
```

Для `bitrix:news.list` это `components/bitrix/news.list/...`, не `components/bitrix.news.list/...`.

Для фактического runtime stock template сначала проверяй `<public-root>/bitrix/components`; путь `modules/<module>/install/components` используй как provenance/source установленной версии, а не как доказательство исполняемого файла.

Перед созданием copied template:

1. найди фактический `IncludeComponent` и template name;
2. найди active-site-template override;
3. прочитай `.parameters.php`, `class.php`/`component.php` и stock template текущей версии;
4. скопируй только нужный template;
5. зафиксируй source module/version и отличие;
6. не копируй ядровый `component.php` в шаблон.

Если меняется выборка или бизнес-правило, сделай custom component/service либо измени параметры подтверждённого компонента. `template.php` должен рендерить уже подготовленные данные.

## Редактируемые фрагменты

Выбор механизма зависит от владельца данных:

| Контент | Механизм-кандидат |
|---|---|
| Небольшой редакторский HTML-фрагмент | project `IncludeFile`/`bitrix:main.include` convention |
| Title/meta/свойство раздела | свойства страницы/раздела или SEO компонента |
| Повторяемый структурированный список | инфоблок/HL + компонент |
| Глобальная настройка | module/project option с правами и схемой |
| Секрет/credential | environment/secret store, не include и не option по умолчанию |
| Бизнес-логика | service/component, не include-файл |

Для `bitrix:main.include` сначала открой установленный contract `.parameters.php` и template. Проверь:

- `AREA_FILE_SHOW` и реальный способ выбора файла;
- site-relative `PATH` и поддержку `SITE_DIR`;
- edit-mode/permissions;
- язык/сайт;
- кеш/component/composite поведение;
- отсутствие секретов и тяжёлых запросов в fragment.

Нельзя объявлять `/include` обязательным путём для всех проектов. Допустимы `/include`, template-local includes, module views и другие явно принятые соглашения.

## Отложенные области

Когда контент формируется позже места вывода, сначала используй существующий проектный механизм:

- `SetViewTarget()` / `EndViewTarget()` + `ShowViewContent()`;
- `AddViewContent()` + `ShowViewContent()`;
- component/page property с отложенным выводом;
- composite dynamic area для персонального HTML.

Не вводи `$GLOBALS['SHOW_*']` как default coordination API. Глобальный флаг допустим как наследуемый проектный паттерн, но он должен иметь уникальное имя, понятного владельца и проверку порядка выполнения.

Для блока из component template типовой pattern выглядит так:

```php
<?php
$this->SetViewTarget('project_sidebar');
?>
<div class="sidebar-block">...</div>
<?php
$this->EndViewTarget();
```

Место вывода:

```php
<?php $APPLICATION->ShowViewContent('project_sidebar'); ?>
```

Перед применением проверь, что `$this` действительно является template object в текущем context, а target выводится после его заполнения с учётом отложенных функций и кеша.

## Проверка после изменения

Минимум:

1. Открыть страницу гостем и авторизованным пользователем, если есть права/персонализация.
2. Проверить первый и второй запрос при component/composite cache.
3. Проверить edit mode и административную панель для включаемой области.
4. Проверить `SITE_ID`, `SITE_DIR`, язык и второй сайт, если проект multisite.
5. Проверить HTML escaping и отсутствие API/SQL writes в template/include.
6. Проверить, что изменён `local/*` или другой project-owned слой, а не core.
7. Для copied template сравнить с stock source и сохранить provenance/version note.

## С чем читать вместе

- Аудит проекта — [project-intake.md](project-intake.md)
- Конфигурация — [project-configuration.md](project-configuration.md)
- Компоненты — [components.md](components.md)
- Шаблоны — [templates.md](templates.md)
- Data flow — [component-dataflow-debugging.md](component-dataflow-debugging.md)
- Composite — [composite-cache.md](composite-cache.md)
- Production rules — [production-best-practices.md](production-best-practices.md)
