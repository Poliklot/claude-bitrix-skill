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

### Фаза 2 — Ядро D7
Изучить и задокументировать в скилле:
- [ ] `Bitrix\Main\Application` — точка входа, сервис-локатор
- [ ] `Bitrix\Main\ORM` — Entity, Query, DataManager, Relations
- [ ] `Bitrix\Main\DB` — Connection, SqlHelper, транзакции
- [ ] `Bitrix\Main\DI\ServiceLocator` — регистрация сервисов
- [ ] `Bitrix\Main\Config\Option` — настройки модулей
- [ ] `Bitrix\Main\Localization` — локализация и Loc::getMessage

### Фаза 3 — Модули и компоненты
- [ ] Структура модуля: `include.php`, `install/`, event handlers
- [ ] Компоненты: `.parameters.php`, `.description.php`, `class.php`, шаблоны
- [ ] Битрикс-MVC через роутер `Bitrix\Main\Routing`
- [ ] CBitrixComponent vs D7-компоненты

### Фаза 4 — Инфраструктурные паттерны
- [ ] Кеширование: `Bitrix\Main\Data\Cache`, тегированный кеш
- [ ] Агенты: `CAgent`, `Bitrix\Main\Agent`
- [ ] Очереди и события: `Bitrix\Main\EventManager`, обработчики
- [ ] Файловая система: `Bitrix\Main\IO`
- [ ] HTTP: `Bitrix\Main\Web\HttpClient`, `Request`, `Response`

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
