# Анти-паттерны первого ответа

Открывай с `developer-primitives.md` и `developer-cards.md` для простых вопросов. Перед ответом отсекай неправильный старт. Если нужен project evidence, используй `core-grep-cookbook.md`. После отсечения анти-паттерна структурируй ответ по `answer-contracts.md`.

| Запрос | Не начинай с | Сначала делай |
|---|---|---|
| meta/title/description/canonical | Ручной `<meta>`/`<title>` в каждом PHP-файле. | `ShowHead`/`ShowTitle`, свойства страницы/раздела, SEO-параметры компонента, `SetTitle`/`SetPageProperty`. |
| CSS/JS | Echo `<link>`/`<script>` или правка ядра. | `Asset::addCss/addJs/addString`, файлы шаблона компонента, `ShowHead`/`ShowBodyScripts`. |
| редактируемый текст | Хардкод в `template.php`. | `IncludeFile`, включаемая область, свойство страницы, инфоблок. |
| компонент | Правка `www/bitrix/modules/*/components`. | Найти `IncludeComponent`, параметры и шаблон в `local/templates/.../components`. |
| текущий пользователь | `$_SESSION`/cookie. | `$USER`, группы/права, project auth wrapper. |
| GET/POST | Сырые `$_REQUEST` без фильтрации. | `Context::getCurrent()->getRequest()`, CSRF для POST. |
| URL/query | Конкатенация `REQUEST_URI`. | `GetCurPageParam`, URL builder, SEF/pagination. |
| module API | Вызов API без проверки. | `Loader::includeModule(...)`, `www/bitrix/modules/<module>`. |
| 404 | `echo '404'` или редирект на главную. | `CHTTP::SetStatus`, `ERROR_404`, `404.php`, routing policy. |
| redirect | HTML до redirect, внешний URL без проверки. | `LocalRedirect`, redirect service, защита от open redirect. |
| image | Только HTML `width/height`, ручной `/upload`. | `CFile::GetPath`, `CFile::ResizeImageGet`, image service. |
| iblock property | SQL в property tables. | Параметры компонента, `$arResult`, iblock API/ORM, `result_modifier`. |
| cache issue | “Выключи весь кеш”. | Компонентный кеш, managed tags, composite/frame, cache keys. |
| аудит оптимизаций | Redis/CDN/composite/global clear без evidence. | Compact `search-seo-ops.md`: audit-report по уже существующим оптимизациям, недоработкам, safe wins и runtime/perfmon-needed. |
| mail/form | Нативный `mail()` как основной путь. | Почтовые события/шаблоны, `CEvent::Send`, `Main\Mail\Event::send`, webform/service. |
| ajax | Самодельный endpoint без sessid/policy. | Project ajax/controller pattern, `bitrix_sessid`, JSON format, composite. |
| events | Анонимный код в шаблоне. | `EventManager`, `local/php_interface`/local module, install/uninstall. |
| sale/catalog data | Прямой SQL. | API `sale`/`catalog`, side effects, события, пересчёты, наличие модулей. |

## Правила

- Не править ядро первым вариантом: постоянная кастомизация — в `local/`, шаблон, локальный модуль или миграцию.
- Не предлагать чистый PHP вместо Bitrix API, если есть `Asset`, `IncludeFile`, `CFile`, `Loader`, `Context`, компоненты, почтовые события.
- Не делать прямой SQL первым ответом для инфоблоков, пользователей, заказов, корзин, цен, остатков, SEO и настроек.
- Не отключать кеш глобально первым ответом: сначала определить слой кеша.
- Не смешивать browser title, H1, meta description, page/section properties, component params и iblock SEO templates.
- Не обещать наличие `sale`, `catalog`, `currency`, `bizproc`, `pull`, `socialnet` без проверки core.
- На короткий вопрос отвечать коротко: штатный механизм, где проверить, минимальный пример, side effects.
