# Бытовые Bitrix-примитивы

Загружай первым для коротких вопросов “как в PHP сделать X в Битриксе”. Сначала найди Bitrix-примитив, а не предлагай чистый PHP/HTML. Для готовых маршрутов ответа открывай [developer-cards.md](developer-cards.md); для отсечения плохого первого варианта — [first-answer-pitfalls.md](first-answer-pitfalls.md); для быстрых project grep-проверок — [core-grep-cookbook.md](core-grep-cookbook.md); для page/include — [project-layout-and-includes.md](project-layout-and-includes.md); для config/ID — [project-configuration.md](project-configuration.md); для формата ответа — [answer-contracts.md](answer-contracts.md).

## Sources

Ориентир: официальная документация `CMain`, D7 `Asset`, `Loader`, `Context`, `CFile`:

- <https://dev.1c-bitrix.ru/api_help/main/reference/cmain/>
- <https://dev.1c-bitrix.ru/api_d7/bitrix/main/page/asset/index.php>
- <https://dev.1c-bitrix.ru/api_d7/bitrix/main/loader/includemodule.php>
- <https://dev.1c-bitrix.ru/api_d7/bitrix/main/context/index.php>
- <https://dev.1c-bitrix.ru/api_help/main/reference/cfile/resizeimageget.php>

## Быстрый маршрутизатор

| Вопрос | Базовый ответ |
|---|---|
| meta title/description/robots/canonical | Проверить `header.php`: `$APPLICATION->ShowHead()` и `<title><?php $APPLICATION->ShowTitle(); ?></title>`. Значения брать из свойств страницы/раздела, SEO-настроек компонента или `$APPLICATION->SetTitle(...)` / `$APPLICATION->SetPageProperty(...)`. Не вставлять meta руками первым шагом. |
| browser `<title>` | Свойство страницы `title`, `SET_BROWSER_TITLE`/`BROWSER_TITLE` или `$APPLICATION->SetPageProperty('title', '...')`; H1/заголовок страницы — `$APPLICATION->SetTitle(...)`. |
| CSS/JS | `Bitrix\Main\Page\Asset::getInstance()->addCss(...)` / `addJs(...)`, либо `template_styles.css`/`script.js` компонента. |
| строка в `<head>` | `$APPLICATION->AddHeadString(...)` или `Asset::addString(...)`; выводится через `ShowHead()`. |
| счётчик/виджет перед `</body>` | Проверить `footer.php`, `ShowBodyScripts()` и проектный `ShowViewContent`; не echo из случайного компонента. |
| хлебные крошки | `$APPLICATION->AddChainItem(...)`; вывод — `bitrix:breadcrumb` или проектный `GetNavChain()` / `ShowNavChain()`. |
| URL/query | `$APPLICATION->GetCurPage()`, `GetCurDir()`, `GetCurPageParam(...)`; не собирать query руками без нужды. |
| request | `Bitrix\Main\Context::getCurrent()->getRequest()` и фильтрация значений. |
| текущий пользователь | `global $USER; $USER->IsAuthorized(); $USER->GetID();` или проектный wrapper. |
| подключить модуль | `Loader::includeModule('iblock')` с обработкой отсутствия модуля. |
| редактируемый текст | `$APPLICATION->IncludeFile(...)`, включаемые области, свойства страницы или инфоблок. |
| компонент | `$APPLICATION->IncludeComponent(...)`; сначала найти фактический вызов и шаблон в `local/templates/.../components/...`. |
| куда положить блок | Найти active template/page convention; выбрать page/header-footer/include/component/service, не считать `/include` универсальным. |
| куда вынести entity ID | Existing config convention; stable key + migration/registry, numeric env/option только с validation и entity check. |
| 404/редирект | Проверить `404.php`, `CHTTP::SetStatus`, `ERROR_404`, `LocalRedirect`, routing/cache policy. |
| картинка | `CFile::ResizeImageGet(...)` / project image service, а не только HTML width/height. |
| перевод | `Bitrix\Main\Localization\Loc::getMessage(...)` и lang-файлы. |
| админ-панель | `$APPLICATION->ShowPanel()` после `<body>`. |

## Meta/title/head

```php
<head>
    <?php $APPLICATION->ShowHead(); ?>
    <title><?php $APPLICATION->ShowTitle(); ?></title>
</head>
```

- `ShowHead()` выводит накопленные meta, CSS/JS и строки из `AddHeadString(...)` / Asset.
- `<title>` обычно выводится отдельно через `ShowTitle()`; не путай browser title с нестандартным `<meta name="title">`.
- `ShowTitle()` работает через отложенные функции, поэтому компонент может задать заголовок после пролога.
- Часто код не нужен: значение идёт из админки, `.section.php`, SEO-свойств инфоблока/компонента.

```php
global $APPLICATION;

$APPLICATION->SetTitle('Заголовок страницы');
$APPLICATION->SetPageProperty('title', 'Title для вкладки браузера');
$APPLICATION->SetPageProperty('description', 'Описание страницы');
$APPLICATION->SetPageProperty('keywords', 'ключевые, слова');
$APPLICATION->SetPageProperty('robots', 'index, follow');
$APPLICATION->SetPageProperty('canonical', 'https://example.com/page/');
```

Для стандартных компонентов сначала проверяй `SET_TITLE`, `SET_BROWSER_TITLE`, `SET_META_KEYWORDS`, `SET_META_DESCRIPTION`, `SET_CANONICAL_URL`, `BROWSER_TITLE`, `META_KEYWORDS`, `META_DESCRIPTION`.

## Мини-паттерны

```php
use Bitrix\Main\Page\Asset;
Asset::getInstance()->addCss(SITE_TEMPLATE_PATH . '/css/custom.css');
Asset::getInstance()->addJs(SITE_TEMPLATE_PATH . '/js/custom.js');
Asset::getInstance()->addString('<meta property="og:type" content="website">', true);
```

```php
$APPLICATION->IncludeFile(SITE_DIR . 'include/footer_text.php', [], ['MODE' => 'html', 'NAME' => 'Текст']);
```

```php
use Bitrix\Main\Context;
$request = Context::getCurrent()->getRequest();
$q = trim((string)$request->getQuery('q'));
```

```php
use Bitrix\Main\Loader;
if (!Loader::includeModule('iblock')) { throw new \RuntimeException('Module iblock is not installed'); }
```

```php
$image = CFile::ResizeImageGet($fileId, ['width' => 320, 'height' => 240], BX_RESIZE_IMAGE_PROPORTIONAL, true);
```

Поиск:

```bash
rg -n 'ShowHead|ShowTitle|SetTitle|SetPageProperty|AddHeadString|ShowBodyScripts|ShowPanel|AddChainItem|IncludeFile|IncludeComponent|GetCurPageParam|Asset::getInstance|Context::getCurrent|ResizeImageGet|Loc::getMessage' local bitrix/templates www/bitrix/templates www/bitrix/modules
```

Анти-паттерны: не вставлять meta руками в каждый PHP-файл; не править `www/bitrix/*` как кастомизацию; не смешивать browser title/H1/meta description; не использовать голый SQL для SEO/контента.
