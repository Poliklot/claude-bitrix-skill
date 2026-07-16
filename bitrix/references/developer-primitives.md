# Бытовые Bitrix-примитивы

Загружай этот файл первым для коротких вопросов разработчика вида “как в PHP сделать X в Битриксе”, прежде чем уходить в глубокую архитектуру. Сначала сопоставь вопрос с готовым Bitrix-примитивом, а не предлагай чистый PHP/HTML. Если нужен готовый ответный маршрут в формате “Запрос → Не делай → Делай → Где проверить → Побочные эффекты”, открой [developer-cards.md](developer-cards.md). Чтобы отсеять плохой первый вариант ответа, открой [first-answer-pitfalls.md](first-answer-pitfalls.md). Если нужно быстро подтвердить проектный факт grep-ом, открой [core-grep-cookbook.md](core-grep-cookbook.md). Для размещения page/include открой [project-layout-and-includes.md](project-layout-and-includes.md), для `.env`/`Option`/ID — [project-configuration.md](project-configuration.md). Чтобы ответ был коротким и правильно структурированным, открой [answer-contracts.md](answer-contracts.md).

## Source notes

Проверяй локальное ядро в клиентском проекте, если оно доступно. Этот quick-reference собран по официальной документации `CMain`, D7 `Asset`, `Loader`, `Context`, `CFile` и по core-first правилам скилла:

- `CMain::ShowHead` / `ShowTitle` / `SetPageProperty` / `SetTitle` / `AddHeadString` / `AddChainItem` / `IncludeFile` / `GetCurPageParam` / `ShowPanel`: <https://dev.1c-bitrix.ru/api_help/main/reference/cmain/>
- D7 `Bitrix\Main\Page\Asset`: <https://dev.1c-bitrix.ru/api_d7/bitrix/main/page/asset/index.php>
- D7 `Bitrix\Main\Loader::includeModule`: <https://dev.1c-bitrix.ru/api_d7/bitrix/main/loader/includemodule.php>
- D7 `Bitrix\Main\Context`: <https://dev.1c-bitrix.ru/api_d7/bitrix/main/context/index.php>
- `CFile::ResizeImageGet`: <https://dev.1c-bitrix.ru/api_help/main/reference/cfile/resizeimageget.php>

## Быстрый маршрутизатор

| Вопрос пользователя | Базовый Bitrix-ответ |
|---|---|
| “Как вставить meta title / description / robots / canonical?” | Не вставлять руками в каждый PHP-файл. Проверить `header.php`: `$APPLICATION->ShowHead()` и `<title><?php $APPLICATION->ShowTitle(); ?></title>`. Значения брать из свойств страницы/раздела, SEO-настроек компонента или задавать через `$APPLICATION->SetTitle(...)` / `$APPLICATION->SetPageProperty(...)`. |
| “Где поменять `<title>`?” | Для browser title: свойство страницы `title`, SEO-параметр компонента `SET_BROWSER_TITLE`/`BROWSER_TITLE` или `$APPLICATION->SetPageProperty('title', '...')`; для заголовка страницы/H1 — `$APPLICATION->SetTitle('...')` и место, где шаблон выводит `$APPLICATION->ShowTitle(false)` или `ShowTitle()`. |
| “Как подключить CSS/JS?” | Через `Bitrix\Main\Page\Asset::getInstance()->addCss(...)` / `addJs(...)`, либо в `template_styles.css`/`script.js` шаблона компонента. Не дублировать `<link>`/`<script>` вручную, если есть Asset. |
| “Как добавить произвольную строку в `<head>`?” | Через `$APPLICATION->AddHeadString(...)` или `Asset::addString(...)`; выводит `$APPLICATION->ShowHead()`. |
| “Как вставить счётчик/виджет перед `</body>`?” | Сначала проверить `footer.php`: есть ли `$APPLICATION->ShowBodyScripts()`. Для JS предпочитай Asset/расширение, а не рандомный echo в компоненте. Если проект уже использует `ShowViewContent`, следуй проектному паттерну. |
| “Как добавить хлебные крошки?” | `$APPLICATION->AddChainItem(...)`; выводить стандартным `bitrix:breadcrumb` или проектным `$APPLICATION->GetNavChain()` / `ShowNavChain()` только если проект так уже делает. |
| “Как получить текущий URL или добавить query-параметр?” | Для текущего пути — `$APPLICATION->GetCurPage()` / `GetCurDir()`. Для URL с изменёнными параметрами — `$APPLICATION->GetCurPageParam(...)`; не собирать query string руками без нужды. |
| “Как получить request/GET/POST?” | В D7 — `Context::getCurrent()->getRequest()`. В старом проектном коде могут быть `$_REQUEST`/`$_GET`, но для нового кода предпочитай D7 request и фильтрацию значений. |
| “Как получить текущего пользователя?” | Через `global $USER; $USER->IsAuthorized(); $USER->GetID();` или D7/project-specific wrapper. Не полагайся на `$_SESSION['SESS_AUTH']` напрямую. |
| “Как подключить модуль?” | `use Bitrix\Main\Loader; if (!Loader::includeModule('iblock')) { ... }`; не использовать API модуля без проверки наличия. |
| “Как вставить редактируемый кусок текста?” | Для контентного текста — `$APPLICATION->IncludeFile(...)` / включаемые области / свойства страницы / инфоблок, а не захардкоженный PHP в шаблоне. |
| “Как подключить компонент?” | `$APPLICATION->IncludeComponent(...)`; перед правкой сначала найти фактический вызов на странице и скопированный шаблон компонента в `local/templates/.../components/...`. |
| “Куда положить блок или компонент?” | Сначала найти active template/page convention; затем выбрать page, header/footer, include, component template или service по [project-layout-and-includes.md](project-layout-and-includes.md), не объявлять `/include` универсальным. |
| “Куда вынести `IBLOCK_ID`/`FORM_ID`?” | Сначала определить existing config convention; предпочитать stable key + migration/registry, а numeric env/option валидировать и перепроверять по entity. См. [project-configuration.md](project-configuration.md). |
| “Как сделать 404?” | Не просто echo “404”. Проверить проектный `404.php`, `CHTTP::SetStatus('404 Not Found')`, `ERROR_404`, `LocalRedirect`/routing policy и composite/cache side effects. |
| “Как сделать редирект?” | Обычно `LocalRedirect($url)` / project router. Перед редиректом не выводить HTML; учитывать `SITE_DIR`, ЧПУ, canonical/SEO и бесконечные циклы. |
| “Как ресайзить картинку?” | Для файлов Bitrix использовать `CFile::ResizeImageGet(...)` / project image service, а не вручную генерировать `<img width height>` без физического resize/cache. |
| “Как получить фразу/перевод?” | Для модулей/компонентов — `Bitrix\Main\Localization\Loc::getMessage(...)` и lang-файлы, не строковые литералы в шаблоне, если проект локализуемый. |
| “Как показать админ-панель?” | В публичном шаблоне должен быть `$APPLICATION->ShowPanel()` после `<body>`; не делать свою панель/кнопки, если нужна штатная панель правки. |

## Meta/title/head: правильная модель

В типовом шаблоне сайта должен быть один центральный вывод head:

```php
<head>
    <?php $APPLICATION->ShowHead(); ?>
    <title><?php $APPLICATION->ShowTitle(); ?></title>
</head>
```

Что это значит для ответа:

1. `ShowHead()` выводит накопленные head-данные: meta `robots`/`keywords`/`description`, CSS/JS и строки из `AddHeadString(...)` / Asset.
2. `<title>` обычно выводится отдельным `$APPLICATION->ShowTitle()`. Не путай browser title с `<meta name="title">`: такой meta-тег не является стандартной базовой потребностью.
3. `ShowTitle()` использует отложенные функции: компонент может задать заголовок после пролога, поэтому не делай вывод “поздно, невозможно” без проверки шаблона и component epilog.
4. Значения часто задаются не кодом, а из админки: свойства страницы/раздела, SEO-свойства инфоблока/элемента/раздела, параметры стандартного компонента.
5. Если нужно задать из PHP:

```php
global $APPLICATION;

// Заголовок страницы / H1, если шаблон его так выводит
$APPLICATION->SetTitle('Название страницы');

// Browser title, если нужно отделить от H1
$APPLICATION->SetPageProperty('title', 'Title для вкладки браузера');

// Meta-теги, которые попадут в ShowHead()
$APPLICATION->SetPageProperty('description', 'Описание страницы');
$APPLICATION->SetPageProperty('keywords', 'ключевые, слова');
$APPLICATION->SetPageProperty('robots', 'index, follow');
$APPLICATION->SetPageProperty('canonical', 'https://example.com/page/');
```

6. Для стандартных компонентов сначала проверь параметры компонента: `SET_TITLE`, `SET_BROWSER_TITLE`, `SET_META_KEYWORDS`, `SET_META_DESCRIPTION`, `SET_CANONICAL_URL`, поля `BROWSER_TITLE`, `META_KEYWORDS`, `META_DESCRIPTION`.
7. Для кастомного компонента page effects держи в `component_epilog.php` или page layer, а подготовку данных — в `component.php`/`result_modifier.php`. Не делай тяжёлые запросы в `component_epilog.php`.
8. Если пользователь спрашивает “как в PHP вставить meta title”, базовый ответ: “В Битриксе обычно не вставляют руками. Проверь `header.php`: `ShowHead()` + `ShowTitle()`. Дальше задай свойство страницы в админке/SEO компонента или через `$APPLICATION->SetPageProperty('title', ...)` / `SetTitle(...)`.”

## Мини-паттерны

### Asset для CSS/JS

```php
use Bitrix\Main\Page\Asset;

Asset::getInstance()->addCss(SITE_TEMPLATE_PATH . '/css/custom.css');
Asset::getInstance()->addJs(SITE_TEMPLATE_PATH . '/js/custom.js');
Asset::getInstance()->addString('<meta property="og:type" content="website">', true);
```

### IncludeFile для редактируемого текста

```php
<?php
$APPLICATION->IncludeFile(
    SITE_DIR . 'include/footer_text.php',
    [],
    ['MODE' => 'html', 'NAME' => 'Текст в подвале']
);
```

### Request через D7 Context

```php
use Bitrix\Main\Context;

$request = Context::getCurrent()->getRequest();
$q = trim((string)$request->getQuery('q'));
```

### Подключение модуля

```php
use Bitrix\Main\Loader;

if (!Loader::includeModule('iblock')) {
    throw new \RuntimeException('Module iblock is not installed');
}
```

### Картинка из `CFile`

```php
$image = CFile::ResizeImageGet(
    $fileId,
    ['width' => 320, 'height' => 240],
    BX_RESIZE_IMAGE_PROPORTIONAL,
    true
);
$src = $image['src'] ?? '';
```

## Где искать в проекте

```bash
rg -n 'ShowHead|ShowTitle|ShowMeta|SetTitle|SetPageProperty|AddHeadString|ShowBodyScripts|ShowPanel|AddChainItem|IncludeFile|IncludeComponent|GetCurPageParam|Asset::getInstance|Context::getCurrent|ResizeImageGet|Loc::getMessage' local bitrix/templates www/bitrix/templates www/bitrix/modules
```

Проверяй приоритетом:

1. `local/templates/<template>/header.php` и `footer.php`
2. `local/templates/<template>/components/...`
3. `.section.php` и PHP-файл страницы
4. настройки стандартного компонента на странице
5. `local/php_interface`, `local/modules`
6. stock templates/components в `www/bitrix/modules/*/install/components/bitrix/*`

## Типовые анти-паттерны

- Не добавляй `<meta name="description">` напрямую в каждый PHP-файл, если задачу решают свойства страницы/компонента и `ShowHead()`.
- Не правь `www/bitrix/templates` или `www/bitrix/modules` как постоянную кастомизацию; копируй в `local/` или используй project layer.
- Не смешивай browser title, H1 и meta description в один ответ: в Bitrix это разные свойства/выводы.
- Не собирай URL/query, breadcrumbs, file paths, image resize и request handling “голым PHP”, если в проекте уже есть Bitrix API/обёртка.
- Не советуй прямой SQL для контентных, SEO и компонентных настроек.
