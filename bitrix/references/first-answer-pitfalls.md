# Анти-паттерны первого ответа

Загружай этот файл вместе с [developer-primitives.md](developer-primitives.md) и [developer-cards.md](developer-cards.md), когда вопрос выглядит простым или бытовым. Цель — перед ответом отсеять типовые неправильные стартовые реакции агента. Если нужен быстрый project evidence, бери команды из [core-grep-cookbook.md](core-grep-cookbook.md). После отсечения анти-паттерна структурируй ответ по [answer-contracts.md](answer-contracts.md).

Правило: если запрос попал в один из пунктов ниже, **не начинай** с анти-паттерна. Сначала дай Bitrix-native путь и где проверить его в проекте.

## Быстрый стоп-лист

| Если пользователь спрашивает | Не начинай с | Сначала делай |
|---|---|---|
| “Как вставить meta/title/description/canonical?” | Ручной `<meta>`/`<title>` в каждом PHP-файле. | `ShowHead`/`ShowTitle`, свойства страницы/раздела, SEO-параметры компонента, `SetTitle`/`SetPageProperty`. |
| “Как подключить CSS/JS?” | Echo `<link>`/`<script>` или правка ядра. | `Asset::addCss/addJs/addString`, файлы шаблона компонента, `ShowHead`/`ShowBodyScripts`. |
| “Как сделать редактируемый текст?” | Хардкод строки в `template.php`. | `IncludeFile`, включаемая область, свойство страницы, инфоблок. |
| “Как править компонент?” | Правка `www/bitrix/modules/*/components`. | Найти вызов `IncludeComponent`, параметры и шаблон в `local/templates/.../components`. |
| “Куда положить блок/include/компонент?” | Универсальная `/include`-схема или жёсткое правило “только header/footer/index”. | Найти public root, active template и project convention; выбрать page/layout/include/template/service по `project-layout-and-includes.md`. |
| “Куда вынести `IBLOCK_ID`/настройку?” | Автоматически добавить `.env`/Composer, lookup только по `CODE` или silent `null`. | Классифицировать value, сохранить existing convention, validate type; stable key + scope + migration/registry по `project-configuration.md`. |
| “Как получить пользователя?” | `$_SESSION`/cookie. | `$USER`, группы/права, project auth wrapper. |
| “Как получить GET/POST?” | Сырые `$_REQUEST` без фильтрации. | `Context::getCurrent()->getRequest()`, CSRF для POST. |
| “Как добавить параметр к URL?” | Конкатенация `$_SERVER['REQUEST_URI']`. | `GetCurPageParam`, project URL builder, учёт SEF/pagination. |
| “Как подключить iblock/sale/catalog?” | Вызов API без проверки. | `Loader::includeModule(...)` и проверка `www/bitrix/modules/<module>`. |
| “Как сделать 404?” | `echo '404'`, редирект на главную. | `CHTTP::SetStatus`, `ERROR_404`, проектный `404.php`, routing policy. |
| “Как сделать redirect?” | HTML/echo до редиректа, невалидированный внешний URL. | `LocalRedirect`, project redirect service, защита от open redirect. |
| “Как вывести картинку/превью?” | Только HTML `width/height`, ручной путь из `/upload`. | `CFile::GetPath`, `CFile::ResizeImageGet`, project image service. |
| “Как вывести свойство инфоблока?” | Прямой SQL в property tables. | Параметры компонента, `$arResult`, `iblock` API/ORM, `result_modifier`. |
| “Почему не обновляется вывод?” | “Выключи весь кеш”. | Найти слой: component cache, managed/tagged cache, composite static HTML (`/bitrix/html_pages/`, `X-Bitrix-Composite`), dynamic area, cache keys. |
| “Изучи проект и скажи как оптимизировать” | Redis/CDN/composite/global cache clear без evidence. | Открыть `project-optimization-audit.md`, собрать факты проекта и выдать audit-report: уже оптимизировано, недоработки, safe wins, runtime/perfmon-needed. |
| “Как отправить письмо?” | Нативный `mail()` как основной путь. | Почтовые события/шаблоны, `CEvent::Send`, `Main\Mail\Event::send`, webform/project service. |
| “Как сделать ajax?” | Самодельный endpoint без `prolog_before`, sessid, JSON policy. | Проверить project ajax/controller pattern, `bitrix_sessid`, response format, composite. |
| “Как добавить обработчик события?” | Регистрировать анонимный код в случайном шаблоне. | `EventManager`, `local/php_interface`/local module, idempotent install/uninstall. |
| “Как поменять данные заказа/корзины/остатков?” | Прямой SQL. | API `sale`/`catalog`, side effects, события, пересчёты, наличие модулей. |

## Жёсткие правила

1. **Не правь ядро первым вариантом.** Любая постоянная кастомизация должна идти в `local/`, проектный шаблон, локальный модуль или миграцию.
2. **Не предлагай чистый PHP вместо Bitrix API**, если есть штатный механизм (`Asset`, `IncludeFile`, `CFile`, `Loader`, `Context`, компоненты, почтовые события).
3. **Не делай прямой SQL первым ответом** для инфоблоков, пользователей, заказов, корзин, цен, остатков, SEO и настроек компонентов.
4. **Не отключай кеш глобально первым ответом.** Сначала определить слой кеша: компонентный, managed/tagged, composite static HTML, dynamic area, браузерный, CDN/proxy. Помни: `setFrameMode(true)` — голосование за composite, а не dynamic boundary.
5. **Не смешивай разные сущности:** browser title, H1, meta description; section/page properties; component params; iblock SEO templates.
6. **Не обещай наличие модуля.** `sale`, `catalog`, `currency`, `bizproc`, `pull`, `socialnet` активны только после проверки в локальном core.
7. **Не делай “админский клик-путь” единственным решением**, если нужна воспроизводимая разработка: миграция, install step, CLI, сервис.
8. **Не отвечай длинной архитектурой на короткий бытовой вопрос.** Дай короткий правильный путь, затем “где проверить”.
9. **Не навязывай структуру/config stack.** `/include`, `.env`, Composer, numeric constants и autodefine — только после проверки project convention, scope, validation, error и invalidation contract.

## Формат хорошего первого ответа

Для бытового вопроса отвечай так:

```text
В Битриксе это обычно делается не [анти-паттерн], а через [штатный механизм].
Проверь в проекте: [2–4 места/grep].
Минимальный пример: [короткий код].
Учти: [1–3 side effects].
```

## Мини-примеры

### Meta title

Плохо: “добавь `<meta name="title">` в header.php”.

Хорошо: “Проверь `ShowHead()`/`ShowTitle()`. Browser title задавай свойством `title` или SEO-параметром компонента; meta description — `SetPageProperty('description', ...)` или свойствами страницы/раздела.”

### CSS

Плохо: “echo '<link rel=stylesheet ...>' в template.php”.

Хорошо: “Используй `Asset::getInstance()->addCss(...)` или `style.css`/`script.js` шаблона компонента.”

### Кеш

Плохо: “поставь `CACHE_TYPE => N` везде”.

Хорошо: “Проверь ключи кеша, `CACHE_GROUPS`, `setResultCacheKeys`, tagged cache, `/bitrix/html_pages/`, `X-Bitrix-Composite` и `createFrame`/`FrameHelper`; отключай кеш только точечно для диагностики.”
