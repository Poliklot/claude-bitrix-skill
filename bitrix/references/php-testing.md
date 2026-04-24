# Bitrix PHP Testing и Verification — справочник

> Reference для Bitrix-скилла. Загружай, когда задача упирается в проверку PHP-кода: unit/integration tests, smoke checks, PHPUnit-контур, test seams, fixtures, event handlers, controller actions и безопасную верификацию без поломки Bitrix-boundary.
>
> Этот файл не подменяет core-first и не требует “идеального” test stack. Он помогает честно понять, что проект уже умеет, а чего в нём нет.

## Содержание
- Когда подгружать этот reference
- Что реально показывает текущее ядро
- Как распознать настоящий test contour проекта
- Decision table: что и как тестировать
- Практичный workflow для PHPUnit и без него
- Test seams и fixtures без конфликта с Bitrix
- Минимальная verification matrix
- Common mistakes
- С чем читать вместе

## Когда подгружать этот reference

Открывай этот файл, если задача звучит так:

- "как это покрыть тестами"
- "куда тут писать PHPUnit"
- "как проверить handler/controller/service без хака ядра"
- "если тестового контура нет, что делать вместо сказок"
- "как безопасно проверить Bitrix-доработку перед релизом"

Не открывай его первым, если вопрос целиком про API конкретного модуля и не касается проверки изменений.

## Что реально показывает текущее ядро

По текущему core важно видеть три факта:

1. В `www/bitrix/modules/main/lib/test/` лежат внутренние test fixtures ядра вроде ORM entity-классов `Bitrix\Main\Test\Typography\*`. Это полезный ориентир по структуре test data, но не готовый PHPUnit-контур проекта.
2. В `www/bitrix/modules/security/classes/general/tests/` лежит собственный диагностический слой security-модуля с базовым классом `CSecurityBaseTest` и пакетами тестов через `CSecurityTestsPackage`. Это runtime/site-checker проверки, а не универсальная project test framework.
3. Внутри `www/bitrix/modules/main/vendor/*` есть сторонние пакеты со своими `composer.json` и даже `phpunit.xml.dist` вроде PHPMailer. Это vendor noise, а не сигнал, что проект уже живёт на Composer/PHPUnit.

Вывод: текущий core даёт ориентиры по внутренним patterns и diagnostic checks, но не доказывает наличие единого PHP test harness в конкретном проекте.

## Как распознать настоящий test contour проекта

Сканируй только project-level и local-level артефакты. Не принимай vendor-файлы из ядра за проектную настройку.

```bash
rg --files . \
  -g '!vendor/**' \
  -g '!www/bitrix/modules/*/vendor/**' \
  -g 'composer.json' \
  -g 'composer.lock' \
  -g 'phpunit.xml' -g 'phpunit.xml.dist' \
  -g 'phpstan.neon' -g 'phpstan.neon.dist' \
  -g 'psalm.xml' -g 'psalm.xml.dist' \
  -g '.php-cs-fixer.php' -g '.php-cs-fixer.dist.php' \
  -g 'phpcs.xml' -g 'phpcs.xml.dist' \
  -g 'ecs.php' \
  -g 'rector.php' \
  -g 'tests/**' -g 'test/**'
```

Сигналы настоящего project contour:

- root `composer.json` или `local/modules/*/composer.json`, который относится к проекту, а не к vendor package;
- `phpunit.xml*` с bootstrap-ом проекта;
- реальные `tests/` рядом с `local/modules`, `local/php_interface`, project services;
- composer scripts или CI-команды, которые уже запускают тесты.

Сигналы, которые нельзя считать доказательством:

- `composer.json` внутри `www/bitrix/modules/main/vendor/...`;
- `phpunit.xml.dist` у сторонней библиотеки в core vendor;
- JS `test/` каталоги модулей ядра;
- внутренние `main/lib/test/*` fixture-классы без project bootstrap.

## Decision table: что и как тестировать

| Слой | Что проверять | Предпочтительный тип проверки | Не делай по умолчанию |
|---|---|---|---|
| Pure service / domain logic | расчёты, валидация, branching | unit test | full Bitrix bootstrap ради одной pure function |
| Service c ORM/DB | `Result/Error`, выборки, persistence side effects | integration test на существующем harness | мокать весь ORM так, что тест теряет смысл |
| Controller action / AJAX endpoint | request contract, errors, response payload | integration или тонкий functional test | тестировать template HTML вместо контракта action |
| Event handler | входные данные, idempotency, side effects | integration/smoke вокруг вынесенного service | хранить всю бизнес-логику прямо в handler и потом пытаться unit-test-ить его |
| Component `class.php` / `component.php` | orchestration, parameters, service calls | test service + smoke component path | считать `template.php` главным местом для unit tests |
| `result_modifier.php` | transform массива к шаблону | extract helper/service и test его | строить сложный test harness прямо под modifier |
| CLI/agent/stepper | command flow, batches, retries | integration/smoke command test | гонять это только руками в проде |
| External integration adapter | mapping request/response, retries, errors | unit + contract/smoke | ходить реальным внешним API в каждый локальный test run |

## Практичный workflow для PHPUnit и без него

### 1. Сначала выбери test target

Нормальная последовательность для Bitrix-проекта:

1. определить boundary: component, controller, handler, agent, CLI, admin/public entrypoint;
2. вынести основную логику в service/helper/adapter;
3. тестировать этот слой в первую очередь;
4. boundary оставить тонким и проверить smoke-ом или integration-путём.

### 2. Если PHPUnit-контур уже есть

- Клади тест в существующее дерево `tests/`, а не придумывай новый layout.
- Используй текущий bootstrap проекта, не выдумывай "универсальный bootstrap для всех Bitrix".
- Для pure service делай быстрые unit tests.
- Для кода с ORM, `Loader`, `Option`, `EventManager`, controller routing — предпочитай integration tests, если такой контур уже существует.
- Проверяй затронутый scope через project-native команду: `composer test`, конкретный `phpunit --filter`, make target или CI script.

### 3. Если PHPUnit-контура нет

Не делай вид, что без мгновенного внедрения PHPUnit работа невозможна.

Минимально честный путь:

1. вынести тестопригодный service/helper из boundary;
2. прогнать `php -l` по изменённым файлам;
3. выполнить локальный smoke path через существующий runtime проекта;
4. проверить ошибки/логи/`Result/Error` на реальном кодовом маршруте;
5. оставить код тестопригоднее, чем он был до правки.

### 4. Не путай verification и full test adoption

У задачи "безопасно поправить обработчик" и у задачи "внедрить системный PHPUnit contour" разный масштаб.

- Для маленькой доработки достаточно safe verification.
- Для повторяющегося критичного домена можно уже предлагать выделенный test contour.
- Не расширяй scope без необходимости.

## Test seams и fixtures без конфликта с Bitrix

### 1. Делай seam вокруг глобального Bitrix-boundary

Плохо тестируются напрямую:

- `$USER`, `$APPLICATION`, глобалы и superglobals;
- inline `Loader::includeModule()` по всему коду;
- прямые вызовы `Option::get()` в чистой бизнес-логике;
- controller/handler, где всё смешано в одном методе.

Лучше:

- завернуть current user / clock / config / external IO в маленькие adapter-классы;
- передавать в service уже нормализованные входные данные;
- хранить тяжёлую логику вне шаблона и entrypoint-а.

### 2. Fixture-подход должен соответствовать проекту

Если в проекте уже есть fixture builders, factories, dataset files или test bootstrap с очисткой БД — используй их.

Если нет, минимально sane path:

- тестируй pure service на in-memory данных;
- для integration-кода создавай только необходимый минимум сущностей;
- явно очищай за собой данные, если test contour это поддерживает;
- не привязывай тест к случайным данным конкретной dev-базы.

### 3. Что можно взять как ориентир из core

- `main/lib/test/` полезен как пример изолированных test entities и fixture-style ORM-описаний.
- `security/classes/general/tests/` полезен как пример встроенных diagnostic checks и пакетирования проверок по типам.

Но не копируй их механически в project layer: это примеры изнутри ядра, а не универсальный шаблон для любого `local/modules/vendor.module`.

## Минимальная verification matrix

### Если project test contour уже есть

Старайся закрыть хотя бы это:

1. unit test на вынесенный service/helper;
2. integration test на слой с ORM/DB/API, если он уже существует в проекте;
3. запуск project-native static analysis или хотя бы затронутого scope;
4. локальный smoke path на boundary, если менялся controller/component/handler.

### Если project test contour нет

Минимальный безопасный baseline:

1. `php -l` на изменённых файлах;
2. проверка imports, namespace и bootstrap path;
3. ручной или scripted smoke по реальному сценарию;
4. проверка логов/ошибок/`Result`-контрактов;
5. фиксация, какой кусок кода теперь можно покрыть тестом позже без переписывания заново.

## Common mistakes

- Считать `phpunit.xml.dist` внутри `www/bitrix/modules/main/vendor/...` признаком, что проект уже работает на PHPUnit.
- Пытаться unit-test-ить `template.php` вместо вынесения логики.
- Поднимать полный Bitrix bootstrap для pure function, которую можно проверить без него.
- Предлагать массовое внедрение PHPUnit/phpstan/CI, когда задача была в точечной правке handler-а.
- Мокать весь Bitrix слой так агрессивно, что тест перестаёт ловить реальные регрессии.
- Привязывать тесты к данным конкретной dev/stage базы.
- Проверять только happy path и забывать про `Result/Error`, валидацию и повторный запуск handler/agent.

## С чем читать вместе

- PHP architecture и toolchain — [php-workflow.md](php-workflow.md)
- PHP quality — [php-quality.md](php-quality.md)
- Legacy modernization — [php-legacy-modernization.md](php-legacy-modernization.md)
- Архитектура модуля, Loader, ServiceLocator — [modules-loader.md](modules-loader.md)
- Контроллеры, handlers, routing — [events-routing.md](events-routing.md)
- ORM и `Result/Error` — [orm.md](orm.md)
- ValidationService и attributes — [validation.md](validation.md)
- DB layer и различия СУБД — [database-layer.md](database-layer.md)
- Компоненты и template layer — [components.md](components.md), [templates.md](templates.md)
