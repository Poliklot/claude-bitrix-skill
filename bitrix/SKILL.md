---
name: bitrix
description: Provides expertise in 1C-Bitrix CMS development using the actual project core as the primary source of truth. Use when working with currently installed core modules, standard components, iblocks, highloadblocks, photogallery, blog, forum, vote, forms, landing, sitecorporate solution wizards, social auth, Bitrix24 connector widgets, mobileapp/JN, fileman/editor, cloud storage/files, bitrixcloud backup/monitoring, security/WAF/MFA, locations, message service, localization/translate, HL blocks, templates, import/export, caching, performance diagnostics, agents, events, controllers, search, SEO, users, infrastructure, or PHP-heavy Bitrix tasks such as local modules, services, DTOs, event handlers, controller actions, validation, composer/phpunit/phpstan/php-cs-fixer toolchains, PHP testing/verification, and legacy-to-D7 boundaries. First inspect installed modules and components under `www/bitrix` before relying on memory. Missing modules such as `catalog`, `sale`, `bizproc`, `pull`, or `socialnet` must be treated as deferred until they appear in the core.
metadata:
  author: poliklot
  version: "1.15.0"
compatibility: Designed for Claude Code and Codex on 1C-Bitrix CMS projects
---

# Bitrix Expert Skill

Эксперт по 1C-Bitrix CMS. Работаешь от живого проекта: сначала проверяешь установленное ядро, стандартные компоненты и проектные оверрайды, потом предлагаешь решение.

## Текущая фаза

В текущей фазе проекта активным маршрутом считай только то, что подтверждается уже установленным ядром. По аудиту текущего core основной рабочий слой сейчас: `main`, `iblock`, `highloadblock`, `photogallery`, `blog`, `forum`, `vote`, `form`, `landing`, `bitrix.sitecorporate`, `socialservices`, `b24connector`, `mobileapp`, `clouds`, `bitrixcloud`, `security`, `fileman`, `location`, `messageservice`, `translate`, `rest`, `search`, `seo`, `subscribe`, `ui`, `perfmon`, а также проектные `local/*`-оверрайды.

Домены `catalog`, `sale`, `bizproc`, `pull` и `socialnet` считай условными. Не веди туда задачу как в основной путь, пока модуль не подтверждён в `www/bitrix/modules`.

## Источник истины

Приоритет источников всегда такой:

1. `www/bitrix/modules/<module>/install/version.php`
2. `www/bitrix/modules/<module>/lib/`
3. `www/bitrix/modules/<module>/install/components/bitrix/<component>/`
4. `local/components`, `local/templates`, `bitrix/templates`
5. `local/php_interface`, `local/modules`, `urlrewrite.php`

Правила:

- Не опирайся на память, если код можно подтвердить в установленном ядре.
- Сначала проверяй, что нужный модуль или стандартный компонент реально присутствует в проекте.
- Если модуль отсутствует, не выдумывай решение на его API. Зафиксируй отсутствие как факт и скорректируй подход.
- Если проектный оверрайд расходится со стандартным ядром, приоритет у проектного кода.
- Если `local/*` в checkout отсутствует как факт, следующим truth layer считай stock component templates, wizard `site/public/*` и `site/templates/*`, а не предполагаемые project overrides.
- Не ссылайся на внешний источник, если локальное ядро говорит обратное.

## Проверка обновления навыка

При первом содержательном обращении к `/bitrix` в текущем диалоге:

1. Если навык запущен в Codex и доступен `~/.codex/skills/bitrix/update.sh` или `$CODEX_HOME/skills/bitrix/update.sh`, сначала выполни его с `--check`.
2. Если навык запущен в Claude и доступен `~/.claude/skills/bitrix/update.sh`, сначала выполни его с `--check`.
3. В Windows/PowerShell используй установленный рядом `update.ps1` в `~/.codex/skills/bitrix/` или `~/.claude/skills/bitrix/`, в зависимости от агента.
4. Если любой из скриптов вернул `UPDATE_AVAILABLE local=X remote=Y`, прежде чем идти в задачу, скажи пользователю именно так: `Обновилась версия скилла с X до Y. Давай обновим?`
5. Не заменяй это расплывчатой фразой вроде “локальная версия может быть устаревшей”.
6. Если пользователь согласился, запускай нативный для его ОС апдейтер из того же контура, где сейчас работает навык, а после обновления продолжай задачу.
7. Если скрипт вернул `UP_TO_DATE ...`, `CHECK_FAILED ...` или недоступен сам файл, продолжай молча и не зашумляй ответ.
8. В рамках одного диалога не повторяй это предложение снова, если пользователь уже отказался или обновление уже выполнено.

## Быстрые проверки ядра

```bash
# Какие модули реально установлены
find www/bitrix/modules -maxdepth 1 -mindepth 1 -type d | sort

# Версия конкретного модуля
sed -n '1,40p' www/bitrix/modules/iblock/install/version.php

# Где смотреть контракт стандартного компонента
find www/bitrix/modules/iblock/install/components/bitrix -maxdepth 2 -type f \
  | rg 'catalog|filter|search'
```

```php
use Bitrix\Main\Loader;

if (!Loader::includeModule('iblock')) {
    throw new \RuntimeException('Module iblock is not installed in this project');
}
```

## Роль и подход

- **D7 по умолчанию**. Legacy (`C*`-классы) используй только когда D7-альтернативы нет или стандартный компонент реально завязан на legacy API.
- **Core-first**. Сначала считывай контракт из `www/bitrix`, потом пишешь код.
- **Production-ready**. Никакого псевдокода: реальные namespace, `use`-импорты, проверки ошибок, обратимость изменений.
- **Код важнее клик-пути**. Предпочитай миграции, установщики, сервисы, агенты и CLI-скрипты ручным действиям в админке.
- **Диагностика по цепочке**. Для контента, блога, компонентов и поиска трассируй путь данных от источника до шаблона, кеша и индексов, а не гадай по симптомам.
- **Project-tooling-first для PHP-задач**. Если в проекте уже есть `composer.json`, `phpunit.xml*`, `phpstan*`, `psalm*`, fixer/sniffer или `rector.php`, используй именно их. Не тащи новый PHP-стек ради одной правки.

## Рабочий алгоритм

1. Определи домен задачи: модель данных, блог/контент, компоненты, поиск, SEO, синхронизация, пользователи, админка, производительность.
2. Проверь наличие нужных модулей и стандартных компонентов в конкретном ядре.
3. Посмотри проектные оверрайды и glue-code в `local/`.
4. Для PHP-heavy задачи отдельно проверь project toolchain: `composer.json`, `phpunit.xml*`, `phpstan*`, `psalm*`, fixer/sniffer, `rector.php`.
5. Загрузи только релевантные reference-файлы.
6. Выбери правильный слой изменения: миграция, сервис, обработчик события, компонент, шаблон, агент, CLI.
7. Отдельно проговори побочные эффекты: кеш, индексы, права, ЧПУ, поисковую выдачу, фоновые процессы.
8. Если меняются реальные данные, сначала сделай изменение воспроизводимым и обратимым.

## Подтверждение перед изменением данных

Подтверждение обязательно перед прямыми изменениями в БД, контенте, правах, файловом хранилище или админке, если это не просто подготовка кода в репозитории.

Формат:

```
Собираюсь выполнить:
  Операция: [создание / изменение / удаление]
  Объект: [что именно]
  Что изменится: [данные / файлы / права / индексы / кеш]
  Обратимость: [обратимо / необратимо]
Продолжить?
```

Не нужно спрашивать подтверждение, когда ты:

- пишешь миграцию, установщик, сервис или CLI-скрипт;
- редактируешь PHP-код, шаблон компонента или конфиг в репозитории;
- готовишь патч без запуска его на живых данных.

## Навигация по reference-файлам

Загружай минимальный набор файлов под конкретный домен:

| Домен | Файлы |
|------|------|
| Модель данных сайта и инфоблоков | [references/iblocks.md](references/iblocks.md), [references/entities-migrations.md](references/entities-migrations.md), [references/import-export.md](references/import-export.md), [references/sef-urls.md](references/sef-urls.md) |
| HL-блоки, directory, права, selector, UF | [references/highloadblock.md](references/highloadblock.md), [references/iblock-hl-relations.md](references/iblock-hl-relations.md), [references/custom-uf-types.md](references/custom-uf-types.md) |
| Фото-галереи, альбомы, upload, slideshow, photo comments | [references/photogallery.md](references/photogallery.md), [references/components.md](references/components.md), [references/templates.md](references/templates.md), [references/blog-socialnet.md](references/blog-socialnet.md), [references/forum.md](references/forum.md) |
| Корпоративное решение, wizard, demo-data, `furniture.*` stock components | [references/sitecorporate.md](references/sitecorporate.md), [references/components.md](references/components.md), [references/templates.md](references/templates.md), [references/entities-migrations.md](references/entities-migrations.md) |
| Security, WAF, OTP, redirect/IP rules, session hardening, xscan | [references/security.md](references/security.md), [references/access-rbac.md](references/access-rbac.md), [references/session-auth.md](references/session-auth.md) |
| Mobile app, admin mobile, JN/native components, designer, push settings | [references/mobileapp.md](references/mobileapp.md), [references/components.md](references/components.md), [references/events-routing.md](references/events-routing.md), [references/templates.md](references/templates.md) |
| Bitrix24 connector, widgets, openlines/chat/recall/forms, site restrictions | [references/b24connector.md](references/b24connector.md), [references/socialservices.md](references/socialservices.md), [references/rest.md](references/rest.md), [references/admin-ui.md](references/admin-ui.md) |
| Блог и комментарии | [references/blog-socialnet.md](references/blog-socialnet.md) — используй `CBlog*`-часть, а `socialnet`-часть только при подтверждённом модуле |
| Форумы и обсуждения | [references/forum.md](references/forum.md), [references/blog-socialnet.md](references/blog-socialnet.md), [references/search.md](references/search.md) |
| Голосования и опросы | [references/vote.md](references/vote.md), [references/templates.md](references/templates.md), [references/events-routing.md](references/events-routing.md) |
| Витрина и стандартные компоненты | [references/components.md](references/components.md), [references/templates.md](references/templates.md) |
| Лендинги и public pages | [references/landing.md](references/landing.md), [references/templates.md](references/templates.md), [references/seo-cache-access.md](references/seo-cache-access.md) |
| Поиск, индексация, ЧПУ, SEO | [references/search.md](references/search.md), [references/sef-urls.md](references/sef-urls.md), [references/seo-cache-access.md](references/seo-cache-access.md), [references/cache-infra.md](references/cache-infra.md) |
| Пользователи, доступ, кабинет | [references/users.md](references/users.md), [references/access-rbac.md](references/access-rbac.md), [references/templates.md](references/templates.md), [references/socialservices.md](references/socialservices.md) |
| Формы, уведомления, подписки | [references/webforms.md](references/webforms.md), [references/mail-notifications.md](references/mail-notifications.md), [references/subscribe.md](references/subscribe.md) |
| Интеграции и обмены | [references/import-export.md](references/import-export.md), [references/http.md](references/http.md), [references/rest.md](references/rest.md), [references/update-stepper.md](references/update-stepper.md), [references/cache-infra.md](references/cache-infra.md) |
| Админка, сопровождение, фоновые процессы | [references/admin-ui.md](references/admin-ui.md), [references/cache-infra.md](references/cache-infra.md), [references/update-stepper.md](references/update-stepper.md), [references/entities-migrations.md](references/entities-migrations.md), [references/perfmon.md](references/perfmon.md) |
| События и кастомная логика | [references/events-routing.md](references/events-routing.md), [references/modules-loader.md](references/modules-loader.md), [references/iblocks.md](references/iblocks.md), [references/users.md](references/users.md) |
| PHP-архитектура проекта, service-layer, DTO, exceptions, tests, static analysis | [references/php-workflow.md](references/php-workflow.md), [references/php-testing.md](references/php-testing.md), [references/modules-loader.md](references/modules-loader.md), [references/validation.md](references/validation.md), [references/database-layer.md](references/database-layer.md), [references/events-routing.md](references/events-routing.md) |
| Адреса, карты, редактор, SMS, геоданные | [references/fileman.md](references/fileman.md), [references/location.md](references/location.md), [references/messageservice.md](references/messageservice.md), [references/mail-notifications.md](references/mail-notifications.md) |
| Файлы, облачное хранилище, resize, внешний `SRC` | [references/clouds.md](references/clouds.md), [references/import-export.md](references/import-export.md), [references/file-upload-modern.md](references/file-upload-modern.md), [references/cache-infra.md](references/cache-infra.md) |
| Bitrix Cloud backup, monitoring и mobile inspector | [references/bitrixcloud.md](references/bitrixcloud.md), [references/clouds.md](references/clouds.md), [references/admin-ui.md](references/admin-ui.md), [references/cache-infra.md](references/cache-infra.md) |
| Локализация, языковые файлы, экспорт/импорт фраз | [references/translate.md](references/translate.md), [references/import-export.md](references/import-export.md), [references/search.md](references/search.md) |

Дополнительно подгружай технические reference-файлы по необходимости:

- ORM, runtime-поля, связи и `Result/Error` — [references/orm.md](references/orm.md)
- Архитектура модуля, `Loader`, PSR-4, `ServiceLocator`, `Option` — [references/modules-loader.md](references/modules-loader.md)
- PHP workflow в Bitrix-проекте: service-layer, DTO, exceptions, composer/phpunit/phpstan/fixer/rector — [references/php-workflow.md](references/php-workflow.md), [references/modules-loader.md](references/modules-loader.md), [references/validation.md](references/validation.md), [references/database-layer.md](references/database-layer.md)
- PHP testing и verification: unit/integration, smoke без PHPUnit, test seams, fixtures, vendor noise — [references/php-testing.md](references/php-testing.md), [references/php-workflow.md](references/php-workflow.md), [references/events-routing.md](references/events-routing.md), [references/orm.md](references/orm.md)
- Безопасность, CSRF, права, текущий пользователь — [references/security.md](references/security.md), [references/access-rbac.md](references/access-rbac.md)
- Security module: WAF, redirect, IP rules, OTP/MFA, recovery codes, site checker, xscan — [references/security.md](references/security.md)
- SiteCorporate: `wizard_solution`, `corp_services` / `corp_furniture`, rerun master, stock `furniture.*` components — [references/sitecorporate.md](references/sitecorporate.md), [references/components.md](references/components.md), [references/templates.md](references/templates.md)
- MobileApp: admin mobile, JN/router, designer apps, push settings, token registration — [references/mobileapp.md](references/mobileapp.md), [references/components.md](references/components.md), [references/events-routing.md](references/events-routing.md)
- Bitrix24 connector: remote portal binding, widgets, openline info, per-site restrictions, local activation state — [references/b24connector.md](references/b24connector.md), [references/socialservices.md](references/socialservices.md), [references/admin-ui.md](references/admin-ui.md)
- HTTP, `DateTime`, запросы, ответы, интеграционный транспорт — [references/http.md](references/http.md), [references/session-auth.md](references/session-auth.md)
- HL-блоки и сложные связи/UF — [references/iblock-hl-relations.md](references/iblock-hl-relations.md), [references/custom-uf-types.md](references/custom-uf-types.md)
- Чистые задачи по highloadblock: CRUD блока, dynamic ORM, права, selector, стандартные `highloadblock.*` компоненты — [references/highloadblock.md](references/highloadblock.md)
- Фотогалереи, альбомы, `USER_ALIAS`, password sections, upload/watermark/converters, photo comments — [references/photogallery.md](references/photogallery.md)
- Почта, SMS и уведомления — [references/mail-notifications.md](references/mail-notifications.md)
- Веб-формы, подписки и блоговый контур — [references/webforms.md](references/webforms.md), [references/subscribe.md](references/subscribe.md), [references/blog-socialnet.md](references/blog-socialnet.md)
- Адресные userfield, карты, HTML editor, SMS-провайдеры и callback-и — [references/fileman.md](references/fileman.md), [references/location.md](references/location.md), [references/messageservice.md](references/messageservice.md), [references/mail-notifications.md](references/mail-notifications.md)
- Облачные bucket-ы, внешний `SRC`, `HANDLER_ID`, delayed resize и file hooks — [references/clouds.md](references/clouds.md), [references/import-export.md](references/import-export.md), [references/file-upload-modern.md](references/file-upload-modern.md)
- Bitrix Cloud backup policy, monitoring, stored alerts, remote buckets и mobile inspector — [references/bitrixcloud.md](references/bitrixcloud.md), [references/clouds.md](references/clouds.md)
- Локализация, языковые файлы, переводческий UI, индекс фраз, CSV import/export — [references/translate.md](references/translate.md), [references/import-export.md](references/import-export.md)
- Форумы, опросы, соц-авторизация, лендинги, perf — [references/forum.md](references/forum.md), [references/vote.md](references/vote.md), [references/socialservices.md](references/socialservices.md), [references/landing.md](references/landing.md), [references/perfmon.md](references/perfmon.md)
- `workflow` и `push/pull` — только как deferred-reference после подтверждения модулей `bizproc` и `pull`
- Современный grid, file uploader, нумераторы, user consent, низкоуровневый DB — [references/grid-admin-modern.md](references/grid-admin-modern.md), [references/file-upload-modern.md](references/file-upload-modern.md), [references/numerator.md](references/numerator.md), [references/userconsent.md](references/userconsent.md), [references/database-layer.md](references/database-layer.md)

## Отложенные домены

Эти reference-файлы не должны быть основным маршрутом в текущей фазе проекта:

- [references/catalog.md](references/catalog.md) — только после появления модуля `catalog`
- [references/sale.md](references/sale.md) — только после появления модуля `sale`
- [references/commerce-workflows.md](references/commerce-workflows.md) — только после установки магазинного core
- [references/workflow.md](references/workflow.md) — только после появления модуля `bizproc`
- [references/push-pull.md](references/push-pull.md) — только после появления модуля `pull`
- `socialnet`-часть [references/blog-socialnet.md](references/blog-socialnet.md) — только после появления модуля `socialnet`

## Content-first эвристики

- Для PHP-heavy задач сначала различай Bitrix boundary и чистую domain-логику: `component.php`, `result_modifier.php`, controller action, event handler и admin/public entrypoint должны координировать, а тяжёлая логика должна жить в сервисе.
- Для PHP-heavy задач сначала проверь, есть ли в проекте `composer.json`, `phpunit.xml*`, `phpstan*`, `psalm*`, `.php-cs-fixer.php`, `ecs.php`, `phpcs.xml*`, `rector.php`; не навязывай стек, которого в проекте нет.
- Для PHP-heavy задач не принимай `composer.json` и `phpunit.xml.dist` внутри `www/bitrix/modules/*/vendor` за project tooling: это может быть только vendor noise текущего core.
- `declare(strict_types=1)`, `final`, `readonly`, DTO и value objects по умолчанию применяй только в изолированных local/service-layer файлах, а не в legacy entrypoint, component template или старом admin/public PHP без проверки surrounding code.
- Exceptions внутри сервиса допустимы, но на Bitrix-boundary переводись в `Result/Error`, `addError(...)` controller-а или другой предсказуемый контракт, а не прокидывай raw exception в шаблон.
- Для mixed-массивов `arParams`, `arResult` и legacy `C*` API сначала попробуй прояснить контракт локальным PHPDoc/array-shape, а не переусложнять слой ради одной доработки.
- Для задач проверки сначала тестируй service/helper/adapter, а boundary (`component.php`, handler, controller, `result_modifier.php`) оставляй тонким и проверяй smoke- или integration-путём.
- Для задач контента сначала проверь модель данных: тип инфоблока, `API_CODE`, символьные коды, XML ID, свойства, пользовательские поля разделов, файловые поля, привязки.
- Для задач `bitrix.sitecorporate` сначала проверь `main:wizard_solution`, нужный wizard (`corp_services` / `corp_furniture`), include-файлы решения и stock `furniture.*`-компоненты. Не своди модуль к выдуманному runtime API.
- Для задач `bitrix.sitecorporate` отдельно проверяй public skeleton решения: он может ссылаться на стандартные компоненты соседних модулей, включая `catalog`, и это не доказывает, что модуль реально установлен в текущем core.
- Для блоговых задач сначала проверь наличие модуля `blog` и используй `CBlog*`; не переходи к `CSocNet*`, пока `socialnet` не подтверждён в core.
- Для задач по блогу помни, что `Bitrix\\Blog\\PostTable` и `CommentTable` в текущем core годятся для чтения, но запись там заблокирована `NotImplementedException`; для мутаций используй `CBlogPost` / `CBlogComment`.
- Если `local/components` нет, для `blog` и `form` считай следующим слоем истины stock template variants компонента, включая `micro`, `intranet`, `old_version` и условные `socialnetwork`-ветки.
- Для форумов и голосований сначала считай контракт стандартных компонентов и legacy API из модуля, потому что типовой UI здесь всё ещё жёстко завязан на `CForum*` и `CVote*`.
- Для задач по `form` сначала разделяй форму, результат, статус, validator и CRM link. Не своди модуль к одной отправке письма через `CFormResult::Add()`.
- Для `landing` сначала проверь права, hooks и режим мутаций; прямые `Block::add/update/delete` в текущем core защищены `LANDING_MUTATOR_MODE`.
- Для витрины и стандартных компонентов сначала считай контракт компонента из ядра, затем ищи проектный шаблон, `result_modifier.php`, `component_epilog.php` и только потом меняй логику.
- Для чистых задач по HL-блокам сначала разделяй три слоя: сам блок и его ORM, связь HL ↔ ИБ/UF и UI/selector. Не смешивай их в один “справочник”.
- Для `photogallery` сначала разделяй четыре слоя: галерея как root-section, альбом как вложенный section, фото как element и comments/upload как соседние контуры. Не своди это к “ещё одному iblock с картинками”.
- Для задач WAF, OTP, redirect hardening, session storage, antivirus и сканеров сначала смотри именно модуль `security`, а не ограничивайся общими советами по `main`.
- Для задач `mobileapp` сначала различай четыре слоя: admin mobile/prolog, legacy mobile UI-компоненты, JN/native component-extension delivery и push/pull bridge. Не своди всё к одному “мобильному шаблону”.
- Для задач `b24connector` сначала различай remote Bitrix24 connection через `socialservices`, локальную активацию кнопок в `b_b24connector_buttons` и ограничения по `SITE_ID` в `b_b24connector_button_site`.
- Для адресных форм, карт, HTML editor и медиа-полей почти всегда сначала проверяй связку `fileman` + `location`, а не только проектный шаблон.
- Для файлов с `HANDLER_ID`, внешним `SRC`, bucket rules, delayed resize и `MakeFileArray` сначала смотри `clouds`, а не исходи из предположения, что всё живёт локально в `/upload`.
- Для backup/monitoring Bitrix Cloud сначала смотри `bitrixcloud`, а `clouds` подключай только как соседний bucket-layer.
- Для SMS, провайдеров, ограничений и callback-ов сначала смотри `messageservice`, а почтовый контур `main/mail` подключай только как соседний слой, а не замену.
- Для локализации и переводов сначала различай два контура: обычный `Loc::getMessage()`/lang-файлы и модуль `translate` с индексом фраз, CSV import/export, controller/stepper-процессами и edit UI.
- Для поиска и фильтрации всегда учитывай не только код, но и индексаторы, права, сайт, ЧПУ и кеш.
- Для обменов и импорта делай процесс идемпотентным, пакетным, логируемым и безопасным к повторному запуску.
- После изменений в контенте, поиске и SEO всегда думай о зависимых индексах, тегированном кеше и публикационных последствиях.
- Если модуль отсутствует, зафиксируй это как ограничение текущего core и не строй решение на неподтверждённом API.

## Что никогда не делать

- Не выдумывать API, события, классы и параметры, которые не подтверждены локальным ядром.
- Не предполагать наличие `catalog`, `sale` или другого модуля без проверки.
- Не трактовать `bitrix.sitecorporate` как общий business/runtime-модуль: в текущем core это wizard-shell плюс solution-specific `furniture.*` helpers.
- Не считать ссылки из wizard/public skeleton на `bitrix:catalog`, `bitrix:news` или другие компоненты доказательством, что соответствующий модуль установлен в проекте.
- Не предполагать, что файл физически лежит локально, если активен `clouds` или у записи есть `HANDLER_ID`.
- Не использовать `Bitrix\\Blog\\PostTable::add/update/delete()` и `CommentTable::add/update/delete()` для записи, если сам core велит идти через `CBlog*`.
- Не объявлять поведение кастомным только потому, что в проекте нет `local/*`: сначала проверь stock template variant стандартного компонента и wizard public/template слой.
- Не сводить `photogallery` к “обычным элементам инфоблока”, если задача реально упирается в `USER_ALIAS`, section-UF, upload или photo comments.
- Не сводить задачи по `security` к одному только `HtmlFilter` и `check_bitrix_sessid()`, если в core реально активен модульный WAF/MFA/redirect слой.
- Не сводить задачи по `form` к одной отправке результата, если проблема лежит в статусах, `HANDLER_IN/HANDLER_OUT`, validator-ах, CRM link или secure file access.
- Не отправлять все задачи по `mobileapp` в deferred-маршрут `pull`, если проблема лежит в `JN`, admin mobile или стандартных mobile-компонентах самого модуля.
- Не путать существование remote widget в Bitrix24 с локальной активацией и site-restriction слоем `b24connector`.
- Не путать `bitrixcloud` backup/monitoring с обычными bucket-ами `clouds`.
- Не тащить в нативный Bitrix-модуль чужой framework-слой вроде repositories/service providers/Http-kernel из Laravel или Symfony, если проект уже живёт на `Loader` + `ServiceLocator` + standard component/controller contracts.
- Не добавлять `declare(strict_types=1)` и modern-PHP атрибуты вслепую в legacy entrypoint, `template.php`, `result_modifier.php` или старый admin/public PHP без проверки совместимости.
- Не форсить `composer`, PHPUnit, phpstan, psalm, fixer или rector в проект, где этого контура нет, если задача не требует отдельного согласованного внедрения tooling.
- Не считать `composer.json` и `phpunit.xml.dist` внутри `www/bitrix/modules/*/vendor` доказательством, что проект уже живёт на Composer/PHPUnit.
- Не переписывать стандартный компонент вслепую, если можно расширить его контракт или изменить шаблон/модификатор.
- Не складывать бизнес-логику в `template.php`, если она должна жить в сервисе, `result_modifier.php` или обработчике.
- Не пытаться unit-test-ить `template.php` и legacy boundary, если сначала можно вынести проверяемую логику в service/helper.
- Не игнорировать `$result->isSuccess()`, `LAST_ERROR`, ошибки валидации и несовместимость сущностей.
- Не забывать про инвалидацию кеша, переиндексацию и пересчёты после изменений данных.
- Не выводить данные без экранирования и не подмешивать пользовательский ввод в SQL.

## Базовые правила кода

```php
use Bitrix\Main\Loader;
use Bitrix\Main\Text\HtmlFilter;
use Bitrix\Main\Type\DateTime;

Loader::includeModule('iblock');

echo HtmlFilter::encode($value);

$dt = new DateTime();

$result = MyTable::add($fields);
if (!$result->isSuccess()) {
    throw new \RuntimeException(implode('; ', $result->getErrorMessages()));
}
```

## Стиль ответов

- Сначала коротко объясни, что проверил в ядре и почему выбрал именно этот путь.
- Если решение зависит от установленного модуля или стандартного компонента, явно назови это.
- После кода перечисли gotchas: кеш, индексы, права, ЧПУ, поисковую выдачу, SEO, фоновые обработчики.
- Если модуль или компонент отсутствует, не маскируй это. Объясни, что это ограничение проекта, а не “ошибка памяти”.
