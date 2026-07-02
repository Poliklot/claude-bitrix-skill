# Бытовые Bitrix-карточки

Загружай после [developer-primitives.md](developer-primitives.md) и [first-answer-pitfalls.md](first-answer-pitfalls.md), когда вопрос короткий и похож на “как в PHP/шаблоне/компоненте сделать X”. Формат каждой карточки: **Запрос → Не делай → Делай → Где проверить → Побочные эффекты**. Для готовых read-only команд “где проверить в проекте” используй [core-grep-cookbook.md](core-grep-cookbook.md). Для формата первого ответа используй [answer-contracts.md](answer-contracts.md).

Цель: быстро дать Bitrix-native ответ и не уходить в чистый PHP, SQL или правку ядра там, где есть штатный механизм.

## 1. Meta title / description / canonical / robots

**Запрос:** “как вставить meta title”, “где поменять description”, “как добавить canonical/robots”.

**Не делай:** не печатай `<meta>` руками в каждом PHP-файле и не правь `www/bitrix/*` как кастомизацию.

**Делай:** проверь `header.php`: там должны быть `$APPLICATION->ShowHead()` и `<title><?php $APPLICATION->ShowTitle(); ?></title>`. Значения обычно идут из свойств страницы/раздела, SEO-настроек инфоблока/компонента или задаются так:

```php
$APPLICATION->SetTitle('H1 или заголовок страницы');
$APPLICATION->SetPageProperty('title', 'Browser title');
$APPLICATION->SetPageProperty('description', 'Meta description');
$APPLICATION->SetPageProperty('robots', 'index, follow');
$APPLICATION->SetPageProperty('canonical', 'https://example.com/page/');
```

**Где проверить:** `local/templates/*/header.php`, `.section.php`, файл страницы, параметры компонента `SET_BROWSER_TITLE`, `SET_META_DESCRIPTION`, `SET_CANONICAL_URL`, `component_epilog.php`.

**Побочные эффекты:** кеш компонента, composite, SEO-наследование инфоблока, разница между H1/`SetTitle` и browser title/`SetPageProperty('title')`.

## 2. CSS / JS / строка в head

**Запрос:** “как подключить css/js”, “как добавить og meta”, “куда вставить script”.

**Не делай:** не вставляй `<link>`/`<script>` echo-ом из случайного компонента, если проект использует Asset.

**Делай:** используй D7 Asset или файлы шаблона компонента:

```php
use Bitrix\Main\Page\Asset;

Asset::getInstance()->addCss(SITE_TEMPLATE_PATH . '/css/custom.css');
Asset::getInstance()->addJs(SITE_TEMPLATE_PATH . '/js/custom.js');
Asset::getInstance()->addString('<meta property="og:type" content="website">', true);
```

**Где проверить:** `header.php` (`ShowHead`), `footer.php` (`ShowBodyScripts`), `template_styles.css`, `style.css`, `script.js`, `Asset::getInstance` в проекте.

**Побочные эффекты:** порядок подключения, дедупликация Asset, composite/ajax, попадание скрипта в head или body.

## 3. Редактируемый текст / include area

**Запрос:** “как вставить текст, который сможет править контентщик”, “как сделать включаемую область”.

**Не делай:** не хардкодь контент в PHP-шаблоне, если он должен редактироваться из админки.

**Делай:** используй `IncludeFile`, включаемые области, свойства страницы или инфоблок:

```php
$APPLICATION->IncludeFile(
    SITE_DIR . 'include/footer_text.php',
    [],
    ['MODE' => 'html', 'NAME' => 'Текст в подвале']
);
```

**Где проверить:** `include/`, `local/templates/*/include`, публичные страницы, права на файл/папку, панель редактирования.

**Побочные эффекты:** права на запись, кеш шаблона/компонента, разные сайты/SITE_DIR, переводимость.

## 4. Компонент и шаблон компонента

**Запрос:** “как вывести список/новости/форму”, “куда править верстку компонента”.

**Не делай:** не правь стандартный компонент в `www/bitrix/modules/*`; не копируй весь компонент, если достаточно шаблона.

**Делай:** найди фактический `$APPLICATION->IncludeComponent(...)`, проверь параметры и скопированный шаблон в `local/templates/<tpl>/components/bitrix/<component>/<template>/`. Логику данных — в `result_modifier.php`/`component.php`, page effects — в `component_epilog.php`, HTML — в `template.php`.

**Где проверить:** вызов компонента на странице, `local/templates/*/components`, stock component в `www/bitrix/modules/*/install/components/bitrix/*`.

**Побочные эффекты:** кеш компонента, `setResultCacheKeys`, ajax mode, composite frames, параметры компонента в админке.

## 5. Хлебные крошки

**Запрос:** “как добавить пункт в breadcrumbs”, “почему крошки не те”.

**Не делай:** не собирай HTML-крошки вручную, если проект использует `bitrix:breadcrumb`.

**Делай:** добавь пункт через `$APPLICATION->AddChainItem('Название', '/url/')` или настрой параметры стандартного компонента/инфоблока (`ADD_SECTIONS_CHAIN`, `ADD_ELEMENT_CHAIN`).

**Где проверить:** компонент `bitrix:breadcrumb`, `AddChainItem`, `GetNavChain`, параметры catalog/news компонента, `component_epilog.php`.

**Побочные эффекты:** порядок вызова, кеш компонента, ЧПУ, дубли с автоматическими разделами.

## 6. Текущий пользователь и права

**Запрос:** “как узнать авторизован ли пользователь”, “получить ID текущего пользователя”, “показать блок только админу”.

**Не делай:** не лезь напрямую в `$_SESSION` и не доверяй клиентским параметрам роли.

**Делай:** используй `$USER` или проектный auth-wrapper:

```php
global $USER;

if ($USER->IsAuthorized()) {
    $userId = (int)$USER->GetID();
}
```

**Где проверить:** `global $USER`, группы пользователя, `access-rbac.md`, проектные helpers.

**Побочные эффекты:** composite cache/персонализация, права групп, разные сайты, кеширование HTML для разных пользователей.

## 7. Request / GET / POST

**Запрос:** “как получить параметр из URL/POST”, “как обработать форму”.

**Не делай:** не используй сырые `$_REQUEST` без фильтрации и CSRF, если пишешь новый код.

**Делай:** используй D7 request:

```php
use Bitrix\Main\Context;

$request = Context::getCurrent()->getRequest();
$q = trim((string)$request->getQuery('q'));
```

Для форм проверь `check_bitrix_sessid()` / `bitrix_sessid_post()` и существующий form/ajax слой.

**Где проверить:** `Context::getCurrent`, `getRequest`, `check_bitrix_sessid`, ajax handlers, controller/action code.

**Побочные эффекты:** CSRF, XSS, кеш GET-страниц, ajax response format.

## 8. URL / query string / ссылки текущей страницы

**Запрос:** “как добавить параметр к текущему URL”, “как получить текущую страницу”.

**Не делай:** не конкатенируй `$_SERVER['REQUEST_URI'] . '&x=y'` руками.

**Делай:** используй `$APPLICATION->GetCurPage()`, `GetCurDir()`, `GetCurPageParam(...)` или проектный URL builder.

**Где проверить:** `GetCurPageParam`, SEF/ЧПУ, `urlrewrite.php`, параметры компонента.

**Побочные эффекты:** дубли URL, canonical, пагинация `PAGEN_N`, фильтры, кеш ключи.

## 9. Подключение модуля

**Запрос:** “почему не работает CIBlockElement”, “как подключить iblock/sale/catalog”.

**Не делай:** не вызывай API модуля без проверки, что модуль установлен и подключён.

**Делай:**

```php
use Bitrix\Main\Loader;

if (!Loader::includeModule('iblock')) {
    throw new \RuntimeException('Module iblock is not installed');
}
```

**Где проверить:** `www/bitrix/modules/<module>/install/version.php`, `Loader::includeModule`, project bootstrap.

**Побочные эффекты:** optional modules (`sale`, `catalog`, `currency`) могут отсутствовать; не заменяй их похожим API.

## 10. 404

**Запрос:** “как отдать 404”, “страница не найдена, но статус 200”.

**Не делай:** не делай просто `echo '404'` или редирект на главную как универсальное решение.

**Делай:** проверь проектный `404.php`, `CHTTP::SetStatus('404 Not Found')`, `ERROR_404`, подключение header/footer и правила роутинга.

**Где проверить:** `/404.php`, `.htaccess`/nginx rewrite, `urlrewrite.php`, компонентные параметры strict check, `LocalRedirect`.

**Побочные эффекты:** SEO, кеш, composite, неправильный статус для поисковиков, кастомный роутер.

## 11. Редирект

**Запрос:** “как сделать redirect”, “после сохранения перекинуть”.

**Не делай:** не выводи HTML до редиректа и не собирай абсолютный URL без проверки сайта/домена.

**Делай:** используй `LocalRedirect($url)` или проектный redirect service. Для внешних URL проверь безопасность open redirect.

**Где проверить:** `LocalRedirect`, `SITE_DIR`, canonical policy, form handlers, controllers.

**Побочные эффекты:** headers already sent, бесконечные циклы, SEO 301/302, сохранение query string.

## 12. Картинка / resize / файл

**Запрос:** “как вывести картинку инфоблока”, “как сделать превью”.

**Не делай:** не выводи только HTML `width/height`, если нужен реальный resize и кешированная картинка.

**Делай:** используй `CFile::GetPath(...)`, `CFile::ResizeImageGet(...)` или проектный image service:

```php
$image = CFile::ResizeImageGet(
    $fileId,
    ['width' => 320, 'height' => 240],
    BX_RESIZE_IMAGE_PROPORTIONAL,
    true
);
```

**Где проверить:** `PREVIEW_PICTURE`, `DETAIL_PICTURE`, UF file fields, `upload/resize_cache`, project image helpers.

**Побочные эффекты:** права на файл, lazy loading, retina, webp, кеш resize, внешние storage/clouds.

## 13. Инфоблок: вывести свойство/элемент

**Запрос:** “как вывести свойство элемента”, “почему PROPERTY_* пустой”.

**Не делай:** не лезь прямым SQL в `b_iblock_element_property` и не предполагай, что свойство уже есть в `$arResult`.

**Делай:** проверь параметры компонента `PROPERTY_CODE`, `FIELD_CODE`, `DISPLAY_PROPERTIES`; для своего кода подключи `iblock` и используй API/ORM. В шаблоне сначала смотри фактический `$arResult`.

**Где проверить:** вызов компонента, `result_modifier.php`, `component_epilog.php`, настройки инфоблока, код свойства, множественность.

**Побочные эффекты:** кеш компонента, права доступа, активность элемента/раздела, разные типы свойств, HTML escaping.

## 14. Кеш компонента и composite

**Запрос:** “почему изменения не видны”, “почему второй пользователь видит чужие данные”, “как кешировать компонент”, “как работает композитный кеш”.

**Не делай:** не отключай весь кеш сайта как первый ответ, не кешируй персональные данные без dynamic area/ключей и не называй `setFrameMode(true)` динамическим блоком.

**Делай:** разведи слои: `CACHE_TYPE`, `CACHE_TIME`, `CACHE_GROUPS`, `StartResultCache`, `AbortResultCache`, `setResultCacheKeys`, tagged/managed cache, затем composite static HTML (`/bitrix/html_pages/`, `X-Bitrix-Composite`) и dynamic boundary (`createFrame`/`FrameHelper`).

**Где проверить:** параметры компонента, `component.php`, `template.php`, `result_modifier.php`, `component_epilog.php`, `cache-infra.md`, `components.md`, `composite-cache.md`.

**Побочные эффекты:** права групп, персонализация, managed cache tags, composite second request/cache pass, ajax lazy blocks, browser/CDN cache.

## 15. Аудит оптимизаций проекта

**Запрос:** “изучи проект и скажи как оптимизировать”, “какие оптимизации уже есть”, “почему сайт тормозит”, “проверь кеши и производительность”.

**Не делай:** не начинай с Redis/CDN/composite/global cache clear и не обещай ускорение без evidence.

**Делай:** открой `project-optimization-audit.md`; собери карту component/tagged/managed/composite cache, SQL/ORM/N+1, тяжёлых шаблонов, images/assets, agents/imports/stepper, search/facet/SEO и shop side effects.

**Где проверить:** `project-optimization-audit.md`, `perfmon.md`, `core-grep-cookbook.md`, `cache-infra.md`, `operations-runbook.md`, `components.md`, `templates.md`, доменный reference.

**Побочные эффекты:** права, персонализация, индексы, бизнес-логика catalog/sale, import windows, browser/CDN cache, runtime evidence.

## 16. Почтовое событие / форма обратной связи

**Запрос:** “как отправить письмо”, “форма не отправляет письмо”.

**Не делай:** не советуй `mail()` как основной путь в Bitrix-проекте.

**Делай:** проверь почтовые события/шаблоны, `CEvent::Send` / `Bitrix\Main\Mail\Event::send`, модуль `form`/webforms или проектный mail service.

**Где проверить:** админка почтовых событий, `mail-notifications.md`, `webforms.md`, event name, site ID, почтовый шаблон, агенты/очередь.

**Побочные эффекты:** SITE_ID, charset, спам-фильтры, очередь/агенты, обязательные поля шаблона.

## 17. AJAX в компоненте / controller action

**Запрос:** “как сделать AJAX в компоненте”, “куда повесить ajax.php”, “как вернуть JSON”.

**Не делай:** не создавай endpoint без `prolog_before.php`, проверки `sessid`, прав и единого JSON-контракта; не обходи уже принятый project ajax pattern.

**Делай:** сначала найди, какой маршрут уже используется: `BX.ajax`, `runComponentAction`, D7 controller/action или legacy endpoint. Для нового кода предпочитай component action/controller с фильтрами, а для legacy — минимальный endpoint с `prolog_before.php`, `check_bitrix_sessid()`, auth/rights check и JSON response.

**Где проверить:** `BX.ajax`, `runComponentAction`, `signedParameters`, `Controller`, `ActionFilter`, `JsonResponse`, `ajax.php`, `prolog_before.php`, `bitrix_sessid` в шаблонах и JS.

**Побочные эффекты:** CSRF, права доступа, composite/ajax mode, кешируемые параметры компонента, response headers.

## 18. Обработчик события

**Запрос:** “как добавить обработчик события”, “куда повесить OnAfterIBlockElementUpdate”, “как реагировать на заказ/элемент”.

**Не делай:** не регистрируй бизнес-логику в случайном `template.php` и не делай анонимный невоспроизводимый код без install/uninstall.

**Делай:** используй `Bitrix\Main\EventManager`, `local/php_interface` только для простого legacy-проекта или local module/install step для постоянного решения. Регистрацию делай идемпотентной, обработчик — тонким, с вызовом service-класса.

**Где проверить:** `local/php_interface/init.php`, `local/modules/*/install/index.php`, `EventManager::getInstance()->addEventHandler`, `RegisterModuleDependences`, доменный модуль события.

**Побочные эффекты:** повторная регистрация, порядок обработчиков, права/контекст агента, транзакции, тяжелые операции в runtime.

## 19. Catalog/sale/currency data changes

**Запрос:** “как обновить цену товара”, “как поменять статус заказа”, “как списать остаток”.

**Не делай:** не меняй цены, заказы, корзины, оплаты, отгрузки или остатки прямым SQL.

**Делай:** сначала подтверди модули `catalog`, `sale`, `currency` в `www/bitrix/modules` и через `Loader::includeModule(...)`. Если модули есть, используй API соответствующего слоя: catalog price/product/store APIs для цены/остатков, sale order/payment/shipment APIs для заказа. Если модуля нет — не обещай commerce route.

**Где проверить:** `www/bitrix/modules/catalog/install/version.php`, `www/bitrix/modules/sale/install/version.php`, `www/bitrix/modules/currency/install/version.php`, project services/import handlers, exchange logs.

**Побочные эффекты:** пересчёты, скидки, резервы, складские документы, история заказа, оплаты/доставки, события, 1С/REST exchange.

## 20. 1С / CommerceML обмен

**Запрос:** “как настроить обмен 1С”, “почему товар из 1С есть в админке, но не на сайте”, “импорт XML прошёл, но данные не появились”.

**Не делай:** не считай успешную загрузку XML успешным импортом и не своди обмен к “просто положить файл”.

**Делай:** проверь наличие `catalog.import.1c`, `catalog.export.1c`, `sale.export.1c` и flow `checkauth → init → file → import`. Разбирай cookies/session, `sessid`, temp files/chunk/zip, `XML_ID`, `CML2_LINK`, логи обмена и post-import видимость товара.

**Где проверить:** component calls, `/bitrix/admin/1c_import.php`, `/bitrix/admin/1c_exchange.php`, `sale_exchange_log`, `XML_ID`, `CML2_LINK`, настройки активность/раздел/site/цена/остаток.

**Побочные эффекты:** дубли товаров/offers, price type/currency, остатки/резервы, активность разделов, кеш/индекс, права, расписание обмена.
