# План создания Bitrix-скилла для Claude Code

## Цель

Создать скилл (`bitrix.md`), который позволит Claude Code глубоко знать ядро Bitrix (D7 и legacy)
и уверенно решать любые задачи: от написания компонентов до работы с ORM, событиями, кешированием
и REST API. Скилл должен быть самодостаточным — подключил и используешь без дополнительного контекста.

---

## Структура репозитория

```
bitrix-agent-skill/
├── bitrix/                     ← сам скилл (в гите)
│   ├── SKILL.md                ← entry point < 300 строк (frontmatter + навигация)
│   └── references/             ← тематические файлы, грузятся по требованию
│       ├── orm.md              ← DataManager, фильтры, события, Result/Error
│       ├── events-routing.md   ← EventManager, Controller, Routing
│       ├── modules-loader.md   ← Модули, Loader, Application, Config
│       ├── components.md       ← Компоненты, шаблоны, кеш в компонентах
│       ├── cache-infra.md      ← Cache, TaggedCache, CAgent, IO
│       ├── http.md             ← DateTime, HttpClient, HttpRequest, HttpResponse
│       └── iblocks.md          ← Инфоблоки legacy+D7, HL-блоки
├── PLAN.md                     ← этот файл (в гите)
├── .gitignore                  ← исключает research/, examples/, bitrix.md
├── research/                   ← изучение файлов ядра (не в гите)
└── examples/                   ← тестовые задачи и проверка скилла (не в гите)
```

### Установка скилла

```bash
cp -r bitrix/ ~/.claude/skills/bitrix
```

Затем в любом проекте с Bitrix:
```
/bitrix <задача>
```

### Принцип progressive disclosure (агентские скиллы agentskills.io)
- **SKILL.md** (~300 строк) — всегда загружается при активации скилла
- **references/*.md** — загружаются только когда задача требует конкретной темы
- Агент читает только нужный reference-файл, не весь контекст сразу

---

## Фазы разработки

### Фаза 1 — Скелет скилла ✅
- [x] Создать `bitrix.md` с базовой структурой и разделами
- [x] Описать роль, тон, стиль ответов
- [x] Добавить первичные инструкции по D7 ORM

### Фаза 2 — Ядро D7 ✅
- [x] ORM: операторы фильтра (полная таблица + логика AND/OR)
- [x] ORM: агрегация (COUNT, SUM, AVG, MIN, MAX + GROUP BY)
- [x] ORM: runtime-поля в запросе
- [x] ORM: события сущностей (onBeforeAdd/Update/Delete + onAfter*)
- [x] Result / Error — паттерн для сервисов
- [x] EventManager — подписка, D7-события, регистрация в модуле
- [x] Engine\Controller — Actions, prefilters, CSRF, AJAX-ответы
- [x] Routing — RoutingConfigurator, группы, параметры
- [x] Type\DateTime и Type\Date — создание, арифметика, таймзоны
- [x] HttpClient — GET/POST, заголовки, ошибки
- [x] Иерархия исключений ядра

### Фаза 3 — Модули и компоненты ✅
- [x] Структура модуля: `include.php`, `install/index.php`, `install/version.php`, `.settings.php`
- [x] Инсталлятор: `CModule`, `ModuleManager::registerModule()`, `InstallDB/UnInstallDB`
- [x] `Loader`: PSR-4 автозагрузка, `local/` vs `bitrix/`, `requireModule()`, `registerNamespace()`
- [x] Компоненты: `.parameters.php`, `.description.php`, `class.php`, шаблоны
- [x] `CBitrixComponent`: жизненный цикл, `onPrepareComponentParams`, `executeComponent`
- [x] Кеширование: `startResultCache/endResultCache/abortResultCache`, тегированный кеш, `arResultCacheKeys`
- [x] Шаблоны: доступные переменные, `setFrameMode`, `AddEditAction`, `GetEditAreaId`
- [x] `CComponentEngine`: URL-роутинг `#VAR#`-шаблоны, `addGreedyPart`, `guessComponentPath`
- [x] `~KEY` в arParams (raw vs экранированные значения)

### Фаза 4 — Инфраструктурные паттерны ✅
- [x] Кеширование: `Bitrix\Main\Data\Cache` — два режима (data/output), полный API, gotchas
- [x] Тегированный кеш: `TaggedCache` — startTagCache/registerTag/clearByTag, b_cache_tag
- [x] Агенты: `CAgent` (D7-обёртки нет!) — AddAgent, паттерн функции, IS_PERIOD, gotchas
- [x] Файловая система: `Bitrix\Main\IO` — File, Directory, Path, исключения
- [x] HTTP: `HttpRequest` — getQuery/getPost/getCookie/isAjax/isJson/decodeJson
- [x] HTTP: `HttpResponse` — addHeader/setStatus/addCookie/flush/redirectTo

### Фаза 5 — Инфоблоки ✅
- [x] Legacy API: `CIBlock`, `CIBlockElement`, `CIBlockSection`
- [x] D7 ORM для инфоблоков: `IblockTable::compileEntity`, API_CODE, `\Iblock\Elements\{Code}Table`
- [x] Свойства: типы (S/N/F/E/G/L), `PropertyTable`, `ElementPropertyTable`, множественные
- [x] Высоконагруженные инфоблоки (HL Blocks): `HighloadBlockTable::compileEntity`, UTM-таблицы
- [x] События инфоблоков, gotchas (VERSION 1/2, fetch vs fetchObject, API_CODE)

### Фаза 5.5 — Реструктуризация в agentskills.io формат ✅
- [x] Разбивка монолитного bitrix.md (2600 строк) на SKILL.md + references/
- [x] SKILL.md < 300 строк: frontmatter, роль, правила, quick-ref, навигация
- [x] 7 reference-файлов: orm, events-routing, modules-loader, components, cache-infra, http, iblocks
- [x] Обновлён .gitignore (bitrix.md исключён, bitrix/ в гите)
- [x] Обновлён PLAN.md со структурой и принципом progressive disclosure

### Фаза 6 — Безопасность и лучшие практики ✅
- [x] XSS: `HtmlFilter::encode()` (ENT_COMPAT по умолчанию!), `htmlspecialchars`, URL/JS-контексты
- [x] SQL-инъекции: ORM как защита, `forSql()` для raw SQL, что НЕ является защитой
- [x] CSRF: `bitrix_sessid_post()`, `check_bitrix_sessid()`, `ActionFilter\Csrf` (только SCOPE_AJAX!)
- [x] Текущий пользователь: `CurrentUser::get()` (D7), глобальный `$USER` (legacy)
- [x] Права доступа: `CIBlock::GetPermission()` (D/R/W/X), `$APPLICATION->GetGroupRight()`, `CanDoOperation()`
- [x] `ActionFilter\Authentication` в Controllers
- [x] Gotchas: ENT_COMPAT vs ENT_QUOTES, Csrf только в SCOPE_AJAX, CurrentUser никогда не null

### Фаза 7 — REST API и внешние интеграции ✅
- [x] Регистрация методов через `OnRestServiceBuildDescription`, `CRestUtil::GLOBAL_SCOPE`
- [x] Сигнатура callback: `($params, $start, $server)`, пагинация (`next`/`total`)
- [x] `RestException` — коды ошибок, HTTP-статусы
- [x] Исходящие REST-события: `CRestUtil::EVENTS`, структура, `event.bind`
- [x] Входящий Webhook — URL-шаблон, вызов через curl
- [x] `Bitrix\Main\Web\HttpClient` для вызова внешнего REST API с OAuth-токеном
- [x] Обновление OAuth refresh_token

### Фаза 8 — Admin UI ✅
- [x] CAdminList, CAdminForm, CAdminTabControl, фильтры, групповые действия
- [x] Кастомные UF-типы через OnUserTypeBuildList + BaseType
- [x] Admin menu.php + права + InstallFiles

### Фаза 9 — Тестирование скилла
- [ ] Набор реальных задач в `examples/` разной сложности (создание модуля, компонент, iblock CRUD, HL-блок)
- [ ] Проверка качества ответов скилла с Claude Haiku (самый строгий тест)
- [ ] Итеративное уточнение инструкций по наблюдению за поведением агента

---

## Фаза 10–15 — Расширение покрытия (roadmap)

> Задачи из анализа реальных вакансий, корпоративных и блог-проектов, интернет-магазинов.

### Фаза 10 — SEF / ЧПУ ✅
- [x] `references/sef-urls.md` — urlrewrite.php, UrlRewriter D7, SEF_MODE, SEF_RULE
- [x] CComponentEngine: guessComponentPath, makePathFromTemplate
- [x] Пример: travels/?type=russia → travels/russia/ с 301-редиректом
- [x] Безопасная сборка фильтра из GET (белый список)

### Фаза 11 — SEO, кеш, доступ ✅
- [x] `references/seo-cache-access.md` — сброс кеша (файловый/managed/HTML), noindex, sitemap, robots.txt, AuthForm

### Фаза 12 — Критичные модули (приоритет: каждый проект)
- [ ] `references/sale.md` — Sale: корзина, заказы, оплата, доставка, скидки, купоны, события
- [ ] `references/mail-notifications.md` — CEventType, CEventMessage, CEvent::Send, SMS-провайдеры
- [ ] `references/catalog.md` — Цены, прайс-листы, SKU/offers, склады, остатки, скидки каталога

### Фаза 13 — Частые задачи (приоритет: большинство проектов)
- [ ] `references/templates.md` — Структура шаблона сайта, Asset D7, $APPLICATION в header/footer, composite + шаблоны
- [ ] `references/users.md` — CUser::Add/Login, UserTable D7, UF пользователей, восстановление пароля, CurrentUser
- [ ] `references/webforms.md` — Веб-формы: CForm, CFormResult, AJAX-версия, форма на инфоблоке
- [ ] Дополнить `references/cache-infra.md` — CFile::SaveFile/ResizeImage, загрузка $_FILES в D7, CFile::MakeFileArray

### Фаза 14 — Специализированные интеграции
- [ ] `references/crm.md` — CRM лиды/сделки/контакты/компании: PHP API + REST, UF CRM, события, CCrmDeal::GetList
- [ ] `references/1c-exchange.md` — CommerceML: этапы, события OnIBlockImport*, отладка, права, ручной запуск
- [ ] `references/search.md` — CSearch::Search/Index/DeleteIndex, событие OnSearch, переиндексация, морфология
- [ ] `references/import-export.md` — CSV/Excel импорт инфоблока, многошаговый импорт, CFile::MakeFileArray из URL, экспорт потоком

### Фаза 15 — Корпоративные сайты и блоги
- [ ] `references/blog-socialnet.md` — CBlogPost, комментарии (forum D7), лайки/рейтинги, рабочие группы, живая лента, подписки
- [ ] `references/push-pull.md` — Bitrix Pull&Push: отправка события из PHP, BX.PULL.subscribe, WebSocket/SSE/LongPolling, отладка
- [ ] `references/workflow.md` — Бизнес-процессы: CBPRuntime::StartWorkflow, кастомное действие IBPActivity, кастомное условие

### Фаза 16 — Расширения существующих файлов
- [ ] Дополнить `references/modules-loader.md` — Мультисайтовость: SITE_ID/LANGUAGE_ID, SiteTable, CSite, Loc с языком
- [ ] Дополнить `references/rest.md` — Placement API Bitrix24, iframe-приложения, OnAppInstall, локальное vs маркетплейс приложение
- [ ] Дополнить `references/security.md` — Composite cache + личные данные (bx-dynamic), CSP-заголовки

---

## Итого план расширения

| Фаза | Новых файлов | Правок существующих |
|------|-------------|-------------------|
| 12 | 3 | — |
| 13 | 3 | 1 |
| 14 | 4 | — |
| 15 | 3 | — |
| 16 | — | 3 |
| **Итого** | **13** | **4** |

Итоговый размер: **~26 reference-файлов** (сейчас 13)

---

## Принципы написания скилла

1. **Конкретность** — примеры кода лучше абстрактных описаний
2. **D7 по умолчанию** — legacy только когда нет D7-альтернативы
3. **Безопасность** — каждый паттерн должен быть безопасным
4. **Краткость** — скилл должен быть плотным, не энциклопедией
5. **Актуальность** — ориентир на Bitrix CMS 23+ / Bitrix24 2024+

---

## Установка скилла (когда будет готов)

```bash
cp bitrix.md ~/.claude/skills/bitrix.md
```

Затем в любом проекте с Bitrix:

```
/bitrix <задача>
```
