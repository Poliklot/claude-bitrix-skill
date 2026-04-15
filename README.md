# Bitrix Agent Skill

Bitrix Agent Skill для разработки на 1C-Bitrix CMS в `Claude Code` и `Codex`. Текущий audited focus: D7 и legacy API для реально установленного core, включая ORM, компоненты, инфоблоки, блог, форум, голосования, формы, лендинги, соц-авторизацию, `fileman`, `location`, `messageservice`, `translate`, HL-блоки, кеширование, события, REST, поиск, SEO и эксплуатационный контур. Ключевой принцип навыка: сначала читать живое ядро проекта и стандартные компоненты в `www/bitrix`, а не полагаться на память или внешние советы.

## Установка

Навык ставится в домашнюю папку пользователя:

- `Claude Code` — `~/.claude/skills/bitrix`
- `Codex` — `$CODEX_HOME/skills/bitrix` или `~/.codex/skills/bitrix`

### macOS / Linux

Для большинства пользователей нужны только шаги 1 и 2.

1. Установи последнюю release-версию навыка.

```bash
curl -fsSL https://raw.githubusercontent.com/Poliklot/bitrix-agent-skill/master/install.sh | bash
```

2. Разреши Claude запускать апдейтер без лишних запросов на разрешение.

```bash
bash ~/.claude/skills/bitrix/allow-update.sh
```

3. Опционально: установи навык только в нужный контур.

```bash
curl -fsSL https://raw.githubusercontent.com/Poliklot/bitrix-agent-skill/master/install.sh | bash -s -- --claude
curl -fsSL https://raw.githubusercontent.com/Poliklot/bitrix-agent-skill/master/install.sh | bash -s -- --codex
curl -fsSL https://raw.githubusercontent.com/Poliklot/bitrix-agent-skill/master/install.sh | bash -s -- --both
```

4. Опционально: установи конкретную release-версию.

```bash
curl -fsSL https://raw.githubusercontent.com/Poliklot/bitrix-agent-skill/master/install.sh | bash -s -- --version 1.5.0 --claude
```

### Windows (PowerShell)

Для большинства пользователей нужны только шаги 1 и 2.

1. Установи последнюю release-версию навыка.

```powershell
irm https://raw.githubusercontent.com/Poliklot/bitrix-agent-skill/master/install.ps1 | iex
```

2. Разреши Claude запускать апдейтер без лишних запросов на разрешение.

```powershell
powershell -ExecutionPolicy Bypass -File "$HOME\.claude\skills\bitrix\allow-update.ps1"
```

3. Опционально: установи навык только в нужный контур.

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Poliklot/bitrix-agent-skill/master/install.ps1))) -Claude
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Poliklot/bitrix-agent-skill/master/install.ps1))) -Codex
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Poliklot/bitrix-agent-skill/master/install.ps1))) -Both
```

4. Опционально: установи конкретную release-версию.

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Poliklot/bitrix-agent-skill/master/install.ps1))) -Version 1.5.0 -Claude
```

### После установки

В любом проекте на Bitrix просто вызывай:

```bash
/bitrix <ваша задача>
```

Если навык не появился сразу, перезапусти агент один раз.

## Обновление

### macOS / Linux

```bash
bash ~/.claude/skills/bitrix/update.sh
bash ~/.claude/skills/bitrix/update.sh --force
bash ~/.claude/skills/bitrix/update.sh --check
bash ~/.claude/skills/bitrix/update.sh --version 1.5.0

bash "${CODEX_HOME:-$HOME/.codex}/skills/bitrix/update.sh"
bash "${CODEX_HOME:-$HOME/.codex}/skills/bitrix/update.sh" --force
bash "${CODEX_HOME:-$HOME/.codex}/skills/bitrix/update.sh" --check
bash "${CODEX_HOME:-$HOME/.codex}/skills/bitrix/update.sh" --version 1.5.0
```

### Windows (PowerShell)

```powershell
powershell -ExecutionPolicy Bypass -File "$HOME\.claude\skills\bitrix\update.ps1"
powershell -ExecutionPolicy Bypass -File "$HOME\.claude\skills\bitrix\update.ps1" -Force
powershell -ExecutionPolicy Bypass -File "$HOME\.claude\skills\bitrix\update.ps1" -Check
powershell -ExecutionPolicy Bypass -File "$HOME\.claude\skills\bitrix\update.ps1" -Version 1.5.0

$CodexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
powershell -ExecutionPolicy Bypass -File (Join-Path (Join-Path $CodexHome 'skills') 'bitrix\update.ps1')
powershell -ExecutionPolicy Bypass -File (Join-Path (Join-Path $CodexHome 'skills') 'bitrix\update.ps1') -Force
powershell -ExecutionPolicy Bypass -File (Join-Path (Join-Path $CodexHome 'skills') 'bitrix\update.ps1') -Check
powershell -ExecutionPolicy Bypass -File (Join-Path (Join-Path $CodexHome 'skills') 'bitrix\update.ps1') -Version 1.5.0
```

Начиная с версии `1.3.7`, при первом содержательном обращении к `/bitrix` навык должен сначала выполнить такую проверку и, если версия выросла, предложить обновление в явной форме: `Обновилась версия скилла с X до Y. Давай обновим?`

## Версии

### macOS / Linux

```bash
bash ~/.claude/skills/bitrix/versions.sh
bash "${CODEX_HOME:-$HOME/.codex}/skills/bitrix/versions.sh"
```

### Windows (PowerShell)

```powershell
powershell -ExecutionPolicy Bypass -File "$HOME\.claude\skills\bitrix\versions.ps1"

$CodexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
powershell -ExecutionPolicy Bypass -File (Join-Path (Join-Path $CodexHome 'skills') 'bitrix\versions.ps1')
```

## Удаление

### macOS / Linux

```bash
bash ~/.claude/skills/bitrix/uninstall.sh
bash "${CODEX_HOME:-$HOME/.codex}/skills/bitrix/uninstall.sh"
```

### Windows (PowerShell)

```powershell
powershell -ExecutionPolicy Bypass -File "$HOME\.claude\skills\bitrix\uninstall.ps1"

$CodexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
powershell -ExecutionPolicy Bypass -File (Join-Path (Join-Path $CodexHome 'skills') 'bitrix\uninstall.ps1')
```

## Как это работает

Навык следует формату progressive disclosure от [agentskills.io](https://agentskills.io):

- **`bitrix/SKILL.md`** — точка входа: core-first правила, рабочий алгоритм, подтверждение перед изменением данных, маршрутизация по темам
- **`bitrix/references/*.md`** — тематические файлы, загружаются по необходимости, когда задача требует конкретной темы

Агент читает только релевантный reference-файл, а не весь контекст сразу.

## Покрытие

Ниже перечислены все reference-файлы репозитория. Активным маршрутом сейчас считается только то, что подтверждено установленными модулями текущего core. Commerce, Bizproc, Push&Pull и `socialnet` вынесены в условный/отложенный контур.

| Файл справки | Темы |
|--------------|------|
| `orm.md` | DataManager, CRUD, связи, фильтры, агрегация, runtime fields, ORM events, Result/Error |
| `events-routing.md` | EventManager, Engine\Controller, AJAX, роутинг, CSRF |
| `modules-loader.md` | Структура модуля, Loader, PSR-4, Application, ServiceLocator, Config\Option, Loc |
| `components.md` | CBitrixComponent, шаблоны, кеш компонента, CComponentEngine |
| `cache-infra.md` | Data\Cache, TaggedCache, CAgent, IO\File/Directory/Path |
| `fileman.md` | Fileman: HTML editor, address/geo userfields, map/video property types, PDF/player/map компоненты |
| `http.md` | Type\DateTime, HttpClient, HttpRequest, HttpResponse |
| `iblocks.md` | Инфоблоки legacy + D7 ORM, свойства, HL-блоки, события инфоблоков |
| `iblock-hl-relations.md` | Связи инфоблоков и HL: directory (UF_XML_ID), HL-поля в UF, `_REF` в ORM, AbstractOrmRepository |
| `custom-uf-types.md` | Кастомные UF-типы (BaseType, onBeforeSave, загрузка файлов), ACF-подходы через HL (Repeater, Group, Flexible Content, глубокая вложенность) |
| `forum.md` | Форумы: CForumNew, CForumTopic, CForumMessage, права, подписки, стандартные `forum.*` компоненты |
| `vote.md` | Опросы и голосования: CVote, CVoteChannel, CVoteQuestion, CVoteAnswer, `voting.*` компоненты |
| `landing.md` | Лендинги: Site, Landing, Block, Hook, Rights, public URL, `landing.*` компоненты |
| `location.md` | Геолокации и адреса: LocationService, AddressService, FormatService, location controllers, location ORM |
| `socialservices.md` | Соц-авторизация: CSocServAuthManager, провайдеры OAuth, UserLinkTable, AuthFlow, `socserv.*` компоненты |
| `messageservice.md` | MessageService: SMS-провайдеры, Message, SmsManager, ограничения, REST, callback-и, config components |
| `translate.md` | Translate: lang-файлы, индекс фраз, translate UI, CSV import/export, translate:index, права и panel hooks |
| `perfmon.md` | Perfmon: SQL/hit/cache diagnostics, схема, индексы, admin-страницы производительности |
| `sale.md` | Интернет-магазин [deferred]: только при установленном модуле `sale` |
| `catalog.md` | Торговый каталог [deferred]: только при установленном модуле `catalog` |
| `commerce-workflows.md` | Магазинные workflow [deferred]: только после установки магазинного core |
| `blog-socialnet.md` | Блог и комментарии; `socialnet`-часть условная и используется только при подтверждённом модуле |
| `push-pull.md` | Push&Pull [deferred]: только при установленном модуле `pull` |
| `workflow.md` | Бизнес-процессы [deferred]: только при установленном модуле `bizproc` |
| `subscribe.md` | Рассылки: CRubric, CSubscription, CPosting, CPostingTemplate, подписки и выпуски |
| `security.md` | XSS, SQL injection, CSRF, контроль доступа, CurrentUser, ActionFilter |
| `rest.md` | REST-методы, OnRestServiceBuildDescription, REST-события, Webhook, OAuth |
| `admin-ui.md` | Админ-страницы, CAdminList, CAdminForm, CAdminTabControl, кастомные UF-типы в админке |
| `entities-migrations.md` | Создание инфоблоков/типов/свойств, групп, пользователей, прав доступа, SQL-миграции |
| `sef-urls.md` | ЧПУ (SEF), urlrewrite.php, UrlRewriter D7, SEF_MODE/SEF_RULE, CComponentEngine |
| `seo-cache-access.md` | Очистка кеша, noindex, sitemap, robots.txt, canonical, OpenGraph, JSON-LD schema.org |
| `mail-notifications.md` | CEventType, CEventMessage, Mail\Event::send, SMS-провайдеры |
| `users.md` | UserTable D7, CUser::Add/Login/Update, группы пользователей, UF-поля, восстановление пароля |
| `templates.md` | Структура шаблона сайта, Asset D7, $APPLICATION в header/footer, композитный кеш |
| `webforms.md` | CForm, CFormResult, AJAX-форма через Controller, валидация |
| `search.md` | CSearch::Index/DeleteIndex/ReIndexAll, CSearchTitle, BeforeIndex, OnSearch, OnSearchGetURL, быстрый AJAX-поиск |
| `import-export.md` | Импорт CSV/URL, многошаговый импорт, CFile::SaveFile/MakeFileArray/ResizeImageGet, потоковый экспорт |
| `grid-admin-modern.md` | Современный Grid UI: Grid, Settings, Options, ComponentParams, processRequest, getOrmFilter, bitrix:main.ui.grid |
| `update-stepper.md` | Stepper (итеративные обновления), bindClass, CLI команды (`update:*`, `make:*`, `orm:annotate`, `messenger:consume-messages`) |
| `validation.md` | ValidationService, PHP 8 Attributes (#[NotEmpty], #[Email], #[Length], #[Min], #[Max] и др.) |
| `session-auth.md` | Session (ArrayAccess, enableLazyStart, isActive), KernelSession, CompositeSessionManager, SessionConfigurationResolver |
| `database-layer.md` | DB\Connection, SqlHelper (quote, forSql, getCurrentDateTimeFunction), различия MySQL/PgSQL/Oracle/MSSQL |
| `access-rbac.md` | Access\Permission\PermissionDictionary, RoleDictionary, BaseAccessController, Rule, RBAC |
| `file-upload-modern.md` | FileUploader\FieldFileUploaderController, UploaderController, Configuration, UploadedFilesRegistry |
| `numerator.md` | Numerator, NumberGeneratorFactory, NumeratorTable, шаблоны нумерации документов |
| `userconsent.md` | UserConsent\Consent::addByContext, Agreement, DataProvider, GDPR-согласие |

## Требования

- Claude Code или Codex
- 1C-Bitrix CMS 23+

## Лицензия

MIT. Подробности в [LICENSE](LICENSE).
