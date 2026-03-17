# Навык Bitrix для Claude Code

Навык Claude Code для разработки на 1C-Bitrix CMS. Охватывает D7 и legacy API: ORM, компоненты, инфоблоки, HL-блоки, кеширование, события, REST, интернет-магазин и многое другое.

## Установка

```bash
cp -r bitrix/ ~/.claude/skills/bitrix
```

Затем в любом проекте на Bitrix:

```
/bitrix <ваша задача>
```

## Как это работает

Навык следует формату progressive disclosure от [agentskills.io](https://agentskills.io):

- **`bitrix/SKILL.md`** — точка входа, загружается при каждом вызове (~200 строк): роль, базовые правила, quick reference, таблица навигации
- **`bitrix/references/*.md`** — тематические файлы, загружаются по необходимости, когда задача требует конкретной темы

Агент читает только релевантный reference-файл, а не весь контекст сразу.

## Покрытие

| Файл справки | Темы |
|--------------|------|
| `orm.md` | DataManager, CRUD, связи, фильтры, агрегация, runtime fields, ORM events, Result/Error |
| `events-routing.md` | EventManager, Engine\Controller, AJAX, роутинг, CSRF |
| `modules-loader.md` | Структура модуля, Loader, PSR-4, Application, ServiceLocator, Config\Option, Loc |
| `components.md` | CBitrixComponent, шаблоны, кеш компонента, CComponentEngine |
| `cache-infra.md` | Data\Cache, TaggedCache, CAgent, IO\File/Directory/Path |
| `http.md` | Type\DateTime, HttpClient, HttpRequest, HttpResponse |
| `iblocks.md` | Инфоблоки legacy + D7 ORM, свойства, HL-блоки, события инфоблоков |
| `iblock-hl-relations.md` | Связи инфоблоков и HL: directory (UF_XML_ID), HL-поля в UF, `_REF` в ORM, AbstractOrmRepository |
| `custom-uf-types.md` | Кастомные UF-типы (BaseType, onBeforeSave, загрузка файлов), ACF-подходы через HL (Repeater, Group, Flexible Content, глубокая вложенность) |
| `sale.md` | Интернет-магазин: Order, Basket, BasketItem, Payment, Shipment, скидки, купоны, события sale |
| `catalog.md` | Торговый каталог: PriceTable, ProductTable, StoreProductTable, SKU/ТП, типы цен, скидки каталога |
| `blog-socialnet.md` | Блог и соцсеть: CBlogPost, CBlogComment, CBlogTag, CSocNetGroup, живая лента, лайки, рейтинги |
| `push-pull.md` | Push&Pull: Event::add, CPullChannel, BX.PULL.subscribe, WebSocket/SSE/LongPolling, отладка |
| `workflow.md` | Бизнес-процессы: CBPRuntime::StartWorkflow, кастомный IBPActivity, IBPCondition, TerminateWorkflow |
| `subscribe.md` | Рассылки: CSender, CSubscribe, CSubscription, CPosting, CSending, Subscribe/UnSubscribe |
| `security.md` | XSS, SQL injection, CSRF, контроль доступа, CurrentUser, ActionFilter |
| `rest.md` | REST-методы, OnRestServiceBuildDescription, REST-события, Webhook, OAuth |
| `admin-ui.md` | Админ-страницы, CAdminList, CAdminForm, CAdminTabControl, кастомные UF-типы в админке |
| `entities-migrations.md` | Создание инфоблоков/типов/свойств, групп, пользователей, прав доступа, SQL-миграции |
| `sef-urls.md` | ЧПУ (SEF), urlrewrite.php, UrlRewriter D7, SEF_MODE/SEF_RULE, CComponentEngine |
| `seo-cache-access.md` | Очистка кеша, noindex, sitemap, robots.txt, контроль доступа к страницам |
| `mail-notifications.md` | CEventType, CEventMessage, Mail\Event::send, SMS-провайдеры |
| `users.md` | UserTable D7, CUser::Add/Login/Update, группы пользователей, UF-поля, восстановление пароля |
| `templates.md` | Структура шаблона сайта, Asset D7, $APPLICATION в header/footer, композитный кеш |
| `webforms.md` | CForm, CFormResult, AJAX-форма через Controller, валидация |
| `search.md` | CSearch::Index/DeleteIndex/ReIndexAll, BeforeIndex, OnSearch, регистрация модуля |
| `import-export.md` | Импорт CSV/URL, многошаговый импорт, CFile::SaveFile/MakeFileArray/ResizeImageGet, потоковый экспорт |
| `grid-admin-modern.md` | Современный Grid UI: Grid, Settings, Options, ComponentParams, processRequest, getOrmFilter, bitrix:main.ui.grid |
| `update-stepper.md` | Stepper (итеративные обновления), bindClass, CLI команды (UpdateCommand, make/*, orm/annotate) |
| `validation.md` | ValidationService, PHP 8 Attributes (#[NotEmpty], #[Email], #[Length], #[Min], #[Max] и др.) |
| `session-auth.md` | Session (ArrayAccess, enableLazyStart, isActive), KernelSession, CompositeSessionManager, Authentication\Policy |
| `database-layer.md` | DB\Connection, SqlHelper (quote, forSql, getCurrentDateTimeFunction), различия MySQL/PgSQL/Oracle/MSSQL |
| `access-rbac.md` | Access\Permission\PermissionDictionary, RoleDictionary, BaseAccessController, Rule, RBAC |
| `file-upload-modern.md` | FileUploader\FieldFileUploaderController, UploaderController, Configuration, UploadedFilesRegistry |
| `numerator.md` | Numerator, NumberGeneratorFactory, NumeratorTable, шаблоны нумерации документов |
| `userconsent.md` | UserConsent\Consent::addByContext, Agreement, DataProvider, GDPR-согласие |

## Требования

- Claude Code
- 1C-Bitrix CMS 23+

## Лицензия

MIT. Подробности в [LICENSE](LICENSE).
