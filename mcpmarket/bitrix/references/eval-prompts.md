# Eval-набор бытовых Bitrix-запросов

Используй при доработке compact-версии. Оцени: правильный route, нет плохого первого шага, есть полезный Bitrix-native ответ по `answer-contracts.md`. Если ответ должен показать “где проверить в проекте”, grep-команды бери из `core-grep-cookbook.md`.

| ID | Prompt | Expected route | Must not start with |
|---|---|---|---|
| B001 | Как в PHP поставить meta title в Битриксе? | `developer-primitives`, `first-answer-pitfalls`, `developer-cards`, `components-admin-ui`, `search-seo-ops` | ручной `<meta name="title">` |
| B002 | Где менять meta description? | primitives/cards + search/seo | meta руками в каждом файле |
| B003 | Как добавить canonical на детальной? | cards + search/seo + commerce if confirmed | правка ядра component |
| B004 | Как подключить CSS? | Asset/cards/components-admin-ui | echo `<link>` |
| B005 | Как подключить JS в компоненте? | Asset/cards/components-admin-ui | random inline script |
| B006 | Как добавить OG meta? | AddHeadString/Asset/search-seo | echo в body |
| B007 | Как сделать редактируемый текст? | IncludeFile/cards | hardcode text |
| B008 | Как вывести включаемую область? | IncludeFile/cards | custom mini-CMS |
| B009 | Как добавить хлебную крошку? | AddChainItem/cards | manual breadcrumbs HTML |
| B010 | Почему крошки дублируются? | cards/components | clear all cache first |
| B011 | Как получить текущего пользователя? | `$USER`/users-security | `$_SESSION` |
| B012 | Показать блок авторизованным | `$USER`, cache caveat | personalized cached HTML |
| B013 | Как получить GET-параметр? | Context request | raw `$_REQUEST` |
| B014 | Как обработать POST? | request + sessid/security | no CSRF |
| B015 | Добавить параметр к URL | `GetCurPageParam` | concat `REQUEST_URI` |
| B016 | Подключить iblock | `Loader::includeModule` | call API before include |
| B017 | Проверить sale | module dir + Loader | assume sale exists |
| B018 | Сделать 404 | `CHTTP::SetStatus`, `ERROR_404`, `404.php` | echo 404 |
| B019 | 404 отдаёт 200 | status/routing/component | redirect home first |
| B020 | Redirect after form | `LocalRedirect`, no output | JS redirect first |
| B021 | Вывести картинку элемента | `CFile::GetPath/ResizeImageGet` | hardcode `/upload` |
| B022 | Сделать превью | `ResizeImageGet` | HTML width/height only |
| B023 | Вывести свойство инфоблока | component params/arResult/API | SQL property table |
| B024 | PROPERTY пустой | params/cache/result_modifier | assume property exists |
| B025 | Изменения не видны | component/managed/tagged cache + `/bitrix/html_pages/` + `X-Bitrix-Composite` + second request/cache pass | disable all cache |
| B026 | Кешировать компонент | cache keys, `StartResultCache`, отличие component cache от composite | cache user-specific data |
| B027 | Чужие данные в кеше | personalization, `CACHE_GROUPS`, `createFrame`/`FrameHelper`, `/bitrix/html_pages/` | clear cache only |
| B028 | Отправить письмо | mail events/templates | PHP `mail()` first |
| B029 | Форма не шлёт письмо | event/template/SITE_ID/agents | “SMTP сломан” first |
| B030 | AJAX в компоненте | project ajax/controller + sessid | endpoint without sessid |
| B031 | Обработчик события | EventManager/local module | code in template |
| B032 | Где писать класс | local module/project namespace | edit core classes |
| B033 | Добавить агента | CAgent/project scheduler | random cron only |
| B034 | Очистить кеш инфоблока | tagged/managed cache | delete all cache first |
| B035 | Путь к ресурсу шаблона | `$this->GetFolder()` | unverified `GetTemplatePath` |
| B036 | Пагинация списка | PageNavigation/NavStart | raw LIMIT only |
| B037 | Вторая страница пустая | filter/count/sort/nav/cache | page size tweak only |
| B038 | Добавить lang-фразу | `Loc::getMessage` | hardcode reusable string |
| B039 | Пользовательское поле | UF API/migration | manual DB change |
| B040 | HL-блок справочник | highloadblock API/migration | raw table only |
| B041 | Обновить цену | catalog API after module check | SQL price update |
| B042 | Статус заказа | sale API after module check | SQL order update |
| B043 | Обмен 1С | checkauth/init/file/import/logs | “just upload XML” |
| B044 | Товар есть в админке, нет на сайте | visibility chain + catalog/1C refs | clear cache only |
| B045 | REST webhook | scopes/auth/permissions | token in public template |
| B046 | Сделай аудит проекта и обнови BITRIX_PROJECT_CONTEXT.md | behavior-routing + project-intake + core-grep + template | общие советы без чтения проекта |
| B047 | В проекте уже есть BITRIX_PROJECT_CONTEXT.md | project-intake + answer-contracts + core-grep | верить снимку проекта вслепую |
| B048 | Можно ли считать магазин runtime-проверенным? | runtime smoke + shop matrix + release gate | “да, покрыто справочником” |
| B049 | P1 smoke без safe write sandbox | runtime smoke | запускать заказ/оплату на production |
| B050 | CommerceML без production 1С | runtime smoke + commerce | подключить реальную 1С |
| B051 | REST webhook scopes неизвестны | runtime smoke + REST/webservice | сохранить токен в evidence |
| B052 | Проверить evidence pack перед релизом | release gate + runtime smoke validator | принять папку без validation |

| B053 | Композитный кеш компонента | `setFrameMode(true)` = vote, `createFrame` = dynamic, headers verification | say setFrameMode makes dynamic |
| B054 | Корзина моргает при композите | dynamic area stub, `CACHE_TYPE=N`, guest/user A/user B | clear all cache only |
| B060 | Аудит оптимизаций проекта | `search-seo-ops` + static helper + evidence pack | Redis/CDN/clear all cache без чтения проекта |
| B061 | N+1 в шаблоне каталога | `search-seo-ops` db-orm + perfmon + preload/map | index/raw SQL first |
| B062 | Каталог/filter тормозит после импорта | `commerce-shop` shop-performance + `search-seo-ops` agents/perfmon | full production rebuild first |
| B063 | Agents/imports грузят сайт | `search-seo-ops` agents-imports + operations/stepper | `set_time_limit(0)` as fix |
| B064 | Тяжёлые images/JS | `search-seo-ops` frontend-assets + components-admin-ui | CDN first |
| B065 | Update-safe кастомизация админки | components-admin-ui + php-architecture/events | edit core/admin files first |
| B066 | Вкладка в форме админки | components-admin-ui + events + content-data if iblock | CSS/admin_header first |
| B067 | Групповое действие/кнопка списка | components-admin-ui + users-security | no sessid/rights |
| B068 | Раздел в меню админки | components-admin-ui + php-architecture/modules | edit `.left.menu.php`/core menu |
| B069 | Где хранить admin-страницы | components-admin-ui + php-architecture/modules | business logic in `/bitrix/admin` |
| B070 | Куда положить global block | project-layout-and-includes + project-intake + components | universal `/include`/rigid placement without project facts |
| B071 | `.section.php` для name/SEO | project-layout-and-includes + components/search-seo | mix `$sSectionName`/properties/SetTitle or manual meta |
| B072 | `.env`/`Option`/constant/lookup для `IBLOCK_ID` | project-configuration + php/content | add Dotenv automatically or lookup only by `CODE` |
| B073 | Query flag для reset registry cache | project-configuration + users-security/search-seo | anonymous cache reset |
| B074 | Изменить выборку stock component | project-layout-and-includes + components-admin-ui + php-architecture | copy core `component.php` into template |

Gate: перед релизом бытового слоя выбрать минимум 15 prompt из разных доменов; `fail = 0`. Полный checklist — `release-gate.md`.
