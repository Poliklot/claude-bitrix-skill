# План создания Bitrix-скилла для Claude Code

## Цель

Создать скилл (`bitrix.md`), который позволит Claude Code глубоко знать ядро Bitrix (D7 и legacy)
и уверенно решать любые задачи: от написания компонентов до работы с ORM, событиями, кешированием
и REST API. Скилл должен быть самодостаточным — подключил и используешь без дополнительного контекста.

---

## Структура репозитория

```
bitrix-agent-skill/
├── bitrix.md          ← сам скилл (единственное, что в гите)
├── PLAN.md            ← этот файл (в гите)
├── .gitignore         ← исключает research/ и examples/
├── research/          ← изучение файлов ядра (не в гите)
└── examples/          ← тестовые задачи и проверка скилла (не в гите)
```

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

### Фаза 5 — Инфоблоки
- [ ] Legacy API: `CIBlock`, `CIBlockElement`, `CIBlockSection`
- [ ] D7 ORM для инфоблоков: `Iblock\ElementTable`, фильтры, select
- [ ] Свойства: типы, множественные, сложные (файл, список, привязка)
- [ ] Высоконагруженные инфоблоки (HL Blocks): `Bitrix\Highloadblock`

### Фаза 6 — Безопасность и лучшие практики
- [ ] XSS: `htmlspecialchars`, `Application::getHtmlEncoder()`
- [ ] SQL-инъекции: только ORM и подготовленные запросы
- [ ] CSRF: `bitrix_sessid_post()`
- [ ] Права доступа: `CUser`, `CGroup`, проверка прав на модуль/элемент

### Фаза 7 — REST API и внешние интеграции
- [ ] Регистрация методов через `CModule`, `AddRestMethod`
- [ ] Webhook и приложения в Bitrix24
- [ ] `Bitrix\Main\Web\HttpClient` для внешних запросов

### Фаза 8 — Тестирование скилла
- [ ] Набор реальных задач в `examples/` разной сложности
- [ ] Проверка качества ответов скилла
- [ ] Итеративное уточнение инструкций

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
