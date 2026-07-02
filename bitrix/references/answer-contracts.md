# Контракты первого ответа для бытовых Bitrix-задач

Открывай после [developer-primitives.md](developer-primitives.md), [first-answer-pitfalls.md](first-answer-pitfalls.md) и [developer-cards.md](developer-cards.md), когда нужно не просто знать правильный Bitrix-примитив, а выдать ответ в правильной форме. Для проверки по проекту используй [core-grep-cookbook.md](core-grep-cookbook.md).

Цель: короткий вопрос разработчика должен получать короткий Bitrix-native ответ, а не длинную архитектуру, чистый PHP, ручной SQL или правку ядра.

## Универсальный контракт

Первый ответ на бытовой вопрос строить так:

```text
В Битриксе это обычно делается через [штатный механизм], а не через [анти-паттерн].
Проверь в проекте: [2–4 конкретных места или grep из core-grep-cookbook].
Минимальный пример:
[короткий код, если нужен]
Учти: [1–3 side effects].
```

Если доступа к проекту нет, не притворяйся, что проверил:

```text
Если есть доступ к проекту, сначала проверь: [paths/grep].
Без проверки ядра я бы начал с [Bitrix-native route], а не с [анти-паттерн].
```

Если доступ к проекту есть, не отвечай абстрактно: сначала найди факт через grep/core, затем дай вывод.

## Выбор типа ответа

| Ситуация | Формат |
|---|---|
| “Как сделать X?” | **Short how-to**: штатный механизм → где проверить → минимальный пример → side effects. |
| “Почему X не работает?” | **Debug chain**: источник данных → параметры компонента → result/template → cache/index/rights → что проверить командами. |
| “Куда править?” | **Layer answer**: страница/параметры компонента/шаблон в `local`/local module/migration; явно сказать “не `www/bitrix/modules`”. |
| “Напиши код” | **Code answer**: сначала факты по module/project, потом production-ready snippet с `use`, checks, errors, escaping. |
| “Есть ли sale/catalog/1C?” | **Module-dependent answer**: сначала module check; если нет — не обещать API. |
| “Поменяй данные/права/контент” | **Confirmation answer**: перед прямым изменением данных дать блок подтверждения из `SKILL.md`. |
| “Как правильно/лучшие практики?” | **Practice answer**: открыть production/pitfalls reference, не ограничиваться кликом в админке. |

## Short how-to

Используй для вопросов: “как поставить meta”, “как подключить CSS”, “как вывести свойство”, “как добавить крошку”, “как получить GET”.

Шаблон:

- `В Битриксе это обычно делается через [API/компонент], а не через [bad first step].`
- `Проверь: [файл/параметр/grep 1], [файл/параметр/grep 2].`
- `Минимально:` затем короткий PHP snippet, если нужен.
- `Учти: [cache/rights/SEO/composite/CSRF].`

Ограничение: не больше 4 смысловых блоков, если пользователь задал простой вопрос и не просил подробную архитектуру.

## Project-confirmed answer

Когда проект доступен:

1. Выполнить минимальный grep из [core-grep-cookbook.md](core-grep-cookbook.md).
2. Назвать найденный файл/параметр.
3. Дать действие только в найденном слое.

Шаблон:

```text
Проверил проект: [файл/параметр] уже/не содержит [факт].
Поэтому правильный путь: [что менять].
Не трогай: [ядро/SQL/ручной meta/etc].
Side effects: [кеш/SEO/права].
```

Не писать “обычно” как финальный вывод, если есть конкретный факт проекта.

## Debug chain

Используй для симптомов “в админке есть, на сайте нет”, “не обновляется”, “вторая страница пустая”, “письмо не уходит”, “404 отдаёт 200”.

Шаблон:

```text
Иди по цепочке:
1. Источник: [инфоблок/форма/компонент/роутинг].
2. Параметры: [PROPERTY_CODE, SET_*, CACHE_*, SEF_*].
3. Project layer: [result_modifier/template/component_epilog/local module].
4. Runtime: [cache/index/rights/composite/agents/logs].

Проверки:
[2–5 grep/path commands]

Не начинай с [bad first step], пока не проверены [facts].
```

## Module-dependent answer

Используй для `iblock`, `highloadblock`, `form`, `catalog`, `sale`, `currency`, `rest`, `bizproc`, `pull`, `socialnet`.

Шаблон:

Сначала подтвердить модуль:

```bash
test -f www/bitrix/modules/<module>/install/version.php && sed -n '1,40p' www/bitrix/modules/<module>/install/version.php
```

В коде:

```php
use Bitrix\Main\Loader;

if (!Loader::includeModule('<module>')) {
    throw new \RuntimeException('Module <module> is not installed');
}
```

Если модуль есть: [API route].
Если модуля нет: [fallback/deferred], не использовать API этого модуля.

## Implementation answer

Когда пользователь просит готовый код:

- дать реальные namespaces/imports;
- проверить модуль через `Loader`;
- фильтровать request;
- экранировать вывод;
- учитывать кеш/права/CSRF;
- не писать тяжёлые запросы в `template.php`/`component_epilog.php`, если можно подготовить данные раньше;
- для постоянной логики предпочитать `local/modules`, сервис, обработчик события, миграцию или component class.

Мини-форма:

```text
Слой изменения: [template/result_modifier/component/local module/migration].
Почему здесь: [кратко].
Код:
[snippet]
Проверить: [команда/страница/кеш].
```

## Контракты по частым доменам

### Meta/title/head

Первый ответ:

```text
В Битриксе meta/title обычно не вставляют руками в PHP-файл. Проверь `header.php`: там должны быть `$APPLICATION->ShowHead()` и `<title><?php $APPLICATION->ShowTitle(); ?></title>`.
```

Дальше выбрать:

- browser title: `SetPageProperty('title', ...)` или SEO-параметр компонента;
- H1/page title: `SetTitle(...)`;
- description/robots/canonical: `SetPageProperty('description'|'robots'|'canonical', ...)`;
- component SEO: `SET_BROWSER_TITLE`, `SET_META_DESCRIPTION`, `SET_CANONICAL_URL`, `component_epilog.php`.

Не говорить первым шагом: “добавь `<meta name="title">`”.

### CSS/JS/head string

Первый ответ: `Asset::getInstance()->addCss/addJs/addString`, `template_styles.css`, `script.js`, `ShowHead`, `ShowBodyScripts`.

Не говорить первым шагом: echo `<script>`/`<link>` из случайного компонента.

### Компоненты и шаблоны

Первый ответ: найти фактический `IncludeComponent`, параметры и шаблон в `local/templates/.../components/...`.

Разделение:

- HTML — `template.php`;
- подготовка данных — `result_modifier.php` или component class;
- page effects — `component_epilog.php`;
- постоянная бизнес-логика — local module/service.

Не править `www/bitrix/modules/*/components` как кастомизацию.

### Iblock property

Первый ответ: проверить `PROPERTY_CODE`, `FIELD_CODE`, `DISPLAY_PROPERTIES`, фактический `$arResult`, `result_modifier.php`.

Не говорить первым шагом: SQL в `b_iblock_element_property`.

### Cache/composite

Первый ответ: назвать слой кеша, а не “выключи весь кеш”.

Проверить: `CACHE_TYPE`, `CACHE_TIME`, `CACHE_GROUPS`, `StartResultCache`, `setResultCacheKeys`, managed/tagged cache, `/bitrix/html_pages/`, `X-Bitrix-Composite`, `setFrameMode` как голосование, `createFrame`/`FrameHelper` как dynamic boundary, personalized HTML.

### Project optimization audit

Первый ответ: “сначала сниму карту фактических оптимизаций и bottlenecks”, а не “включите кеш/Redis/CDN”. Открыть `project-optimization-audit.md`.

Формат ответа:

```text
Что уже оптимизировано: [evidence]
Недоработки/ошибки: [priority, file, impact]
Safe wins: [low-risk fixes]
Нужно runtime/perfmon: [metrics required]
Не трогать вслепую: [cache/index/data risks]
```

Проверить: component/tagged/managed/composite cache, SQL/ORM/N+1, template heavy logic, images/assets, agents/imports/stepper, search/facet/SEO indexes, shop/sale side effects.

Не говорить первым шагом: “поставьте Redis”, “очистите весь кеш”, “добавьте индекс”, “включите composite” без evidence.

### Forms/mail/ajax

Первый ответ:

- формы: `Context::getCurrent()->getRequest()`, validation, `check_bitrix_sessid`;
- почта: почтовые события/шаблоны, `CEvent::Send` или `Main\Mail\Event::send`;
- ajax: project pattern, component action/controller, `bitrix_sessid`, JSON response.

Не говорить первым шагом: `mail()` или endpoint без prolog/sessid.

### Sale/catalog/stock/order

Первый ответ: module check для `catalog`, `sale`, `currency`.

Если модуль подтверждён — использовать API `sale`/`catalog` и учитывать пересчёты, события, скидки, резервы, оплаты/доставки. Не SQL.

### 1С / CommerceML

Первый ответ: проверить components/modules и flow `checkauth → init → file → import`, cookies/session, temp files, XML_ID/CML2_LINK, logs.

Не говорить первым шагом: “просто загрузи XML”.

## Что считать хорошим ответом

Хороший первый ответ:

- коротко называет Bitrix-native механизм;
- явно отсекает плохой старт;
- даёт 2–4 места проверки;
- содержит минимальный код только если он нужен;
- предупреждает о side effects;
- не обещает module/API без core check;
- не превращает бытовой вопрос в длинную лекцию.

Плохой первый ответ:

- предлагает чистый PHP/HTML там, где есть Bitrix API;
- начинает с прямого SQL;
- советует править `www/bitrix`;
- предлагает глобально отключить кеш;
- не различает H1/browser title/meta description;
- не говорит, где проверить фактический проектный слой.
