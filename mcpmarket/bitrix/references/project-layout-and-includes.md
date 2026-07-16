# Структура публичной части и include-области

Открывай для вопросов “куда положить код”, “где подключить компонент”, “как сделать редактируемый блок”, `header.php`/`footer.php`/`index.php`/`.section.php`. Это эвристики: сначала найди public root, active template и project convention.

## Project-first

```bash
find . -maxdepth 5 -type f \( -name header.php -o -name footer.php -o -name '.section.php' \) -print
rg -n 'SITE_TEMPLATE_PATH|IncludeComponent\(|IncludeFile\(|main\.include|ShowViewContent|SetViewTarget|AddViewContent' \
  . --glob '*.php' --glob '!upload/**' --glob '!bitrix/cache/**' --glob '!www/bitrix/cache/**'
find local/templates bitrix/templates www/bitrix/templates -path '*components/*' -type f 2>/dev/null | sort
```

Наличие папки в `local/templates` не доказывает, что шаблон активен: назначение может зависеть от сайта/условия.

## Карта слоёв

| Задача | Слой |
|---|---|
| page title/meta | свойства страницы/раздела, component SEO params, `component_epilog.php` |
| глобальная оболочка | active `header.php`/`footer.php` |
| content страницы | page `index.php` + фактический component/include |
| редактируемый HTML | project `IncludeFile`/`bitrix:main.include`, property или iblock |
| HTML компонента | copied template в active site template |
| подготовка данных | лёгкий `result_modifier.php`; запросы/правила — component/service |
| reusable logic | local module/service/custom component |
| personal global block | correct cache key + composite dynamic boundary |

Страница подключает header/footer через `$_SERVER['DOCUMENT_ROOT']`, не через filesystem-root `/bitrix/header.php`.

`.section.php` обычно задаёт `$sSectionName` и `$arDirProperties`. Не смешивай их с `SetTitle`, `SetPageProperty` и SEO-параметрами компонента; при конфликте проверь порядок, deferred output, component/composite cache.

## Компоненты и templates

Пути содержат отдельные namespace/component segments:

```text
local/templates/<site-template>/components/<namespace>/<component>/<template>/
local/components/<namespace>/<component>/templates/<template>/
bitrix/templates/<site-template>/components/<namespace>/<component>/<template>/
<public-root>/bitrix/components/<namespace>/<component>/templates/<template>/
<public-root>/bitrix/modules/<module>/install/components/<namespace>/<component>/templates/<template>/
```

Для `bitrix:news.list` правильно `components/bitrix/news.list/...`, не `components/bitrix.news.list/...`.

Фактический runtime stock template сначала сверяй в `<public-root>/bitrix/components`; `modules/<module>/install/components` — provenance/source установленной версии.

Перед copied template найди фактический component call/active template, прочитай `.parameters.php`, class/component и stock template текущей версии. Копируй только template; изменение выборки/правила делай через params/custom component/service, не копией ядрового `component.php`.

`catalog.*` public components внутри `iblock` не доказывают установленный commerce core. Цены/SKU/остатки требуют проверки `catalog`/`sale`/`currency`.

## Include и delayed areas

Не объявляй `/include` обязательным путём. Возможны root include, template-local includes, module views или project builder.

Для `bitrix:main.include` проверь installed `.parameters.php`, `AREA_FILE_SHOW`, фактический `PATH`, `SITE_DIR`, edit permissions, cache/composite и отсутствие тяжёлой логики/secrets.

Для позднего контента используй существующий project pattern:

- `SetViewTarget` / `EndViewTarget` + `ShowViewContent`;
- `AddViewContent` + `ShowViewContent`;
- page/component property;
- composite dynamic area для personal HTML.

Не вводи `$GLOBALS['SHOW_*']` как default API.

## Verify

- guest + authorized при rights/personalization;
- first + second request при cache/composite;
- edit mode для include;
- `SITE_ID`/`SITE_DIR`/language/multisite;
- escaping и отсутствие writes в template/include;
- project-owned layer, не core;
- stock comparison/provenance copied template.

Связанные compact references: `project-intake.md`, `project-configuration.md`, `components-admin-ui.md`, `search-seo-ops.md`, `php-architecture.md`.
