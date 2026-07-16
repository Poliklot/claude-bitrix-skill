# Конфигурация проекта и стабильные идентификаторы

> Reference для задач про `.env`, `Option`, константы, ID инфоблоков/форм/HL-блоков, различия dev/stage/prod и lookup по символьному ключу. Сначала сохрани существующий project convention; не добавляй новый config stack только ради одного значения.

## Содержание

- [Сначала классифицировать значение](#сначала-классифицировать-значение)
- [Аудит текущего проекта](#аудит-текущего-проекта)
- [Секреты и environment](#секреты-и-environment)
- [Project options](#project-options)
- [Идентификаторы сущностей](#идентификаторы-сущностей)
- [Безопасный registry](#безопасный-registry)
- [Кеш и инвалидация](#кеш-и-инвалидация)
- [Контракт ошибки](#контракт-ошибки)
- [Чеклист](#чеклист)

## Сначала классифицировать значение

| Тип | Примеры | Предпочтительный источник |
|---|---|---|
| Secret | DB password, API token, webhook credential, private key | runtime environment/secret store; локальный `.env` только по deployment convention |
| Deployment config | host, timeout, external base URL, feature endpoint | environment или deployment config с schema/validation |
| Административная настройка сайта | телефон, email, включение функции, лимит | project/module `Option` или отдельная сущность с правами и audit trail |
| Ссылка на бизнес-сущность | iblock, form, HL block, price type, store | stable key (`CODE`, `XML_ID`, `API_CODE`, table name) + migration/registry; numeric ID только после resolution |
| Константа кода | размер batch, имя события, cache namespace | typed config/constant в versioned code |
| Пользовательский контент | текст, список, изображение | page/section property, include area, iblock/HL — по структуре данных |

Не смешивай эти классы. Например, `IBLOCK_ID=12` не становится secret только потому, что записан в `.env`, а API token не становится безопасным, если положен в `Option` без отдельной модели доступа.

## Аудит текущего проекта

```bash
find . -maxdepth 4 -type f \( \
  -name '.env.example' -o -name 'composer.json' -o -name '.settings.php' -o \
  -name 'settings.php' -o -name 'constants.php' -o -name 'init.php' \
\) -print

rg -l 'Dotenv|\$_ENV|\$_SERVER|getenv\(|Option::get|COption::GetOption|define\(|IBLOCK_ID|FORM_ID|HLBLOCK_ID|PRICE_TYPE|STORE_ID' \
  local . --glob '*.php' --glob '*.json' --glob '*.example' \
  --glob '!bitrix/**' --glob '!www/bitrix/**' --glob '!vendor/**' --glob '!upload/**'
```

Первый проход намеренно выводит только имена файлов. Не печатай совпавшие строки массовым `rg -n`: в `define(...)`, fallback `Option::get(...)` или inline config могут находиться credentials. Просматривай выбранные файлы локально и точечно; перед переносом фрагмента в transcript/evidence замени значения secrets на `<redacted>`.

Проверь:

1. какой bootstrap реально загружает config;
2. есть ли project Composer, а не только vendor `composer.json` внутри core;
3. где выполняются validation и type conversion;
4. какие значения различаются между sites/environments;
5. есть ли migration/install contract для связанных сущностей;
6. что происходит при missing/duplicate value;
7. не попадают ли secrets в Git, logs, exception, `BITRIX_PROJECT_CONTEXT.md` или evidence.

## Секреты и environment

Правила:

- production secret должен приходить из согласованного deployment/secret layer;
- `.env` допустим для local/dev или если это явный production convention с закрытыми permissions и rotation policy;
- `.env.example` содержит имена и безопасные placeholders, не реальные credentials;
- `$_ENV`, `$_SERVER` и `getenv()` возвращают строки или отсутствие значения — всегда валидируй и приводи тип;
- не выводи полный config в debug/log/exception;
- не добавляй `vlucas/phpdotenv`, если в проекте нет Composer/config convention и задача не требует этого решения.

Если проект уже использует `vlucas/phpdotenv`, загрузка файла не заменяет schema validation:

```php
$dotenv = Dotenv\Dotenv::createImmutable($_SERVER['DOCUMENT_ROOT']);
$dotenv->safeLoad();

$dotenv->required('EXTERNAL_API_BASE_URL')->notEmpty();
$dotenv->required('EXTERNAL_API_TIMEOUT')->isInteger();
```

`safeLoad()` означает только “не падать из-за отсутствующего файла”. Она не доказывает, что обязательные значения заданы process environment или другим источником.

Для endpoint дополнительно проверяй scheme/host allowlist; для integer — range; для boolean — явный parser, а не `(bool) 'false'`.

## Project options

`Bitrix\Main\Config\Option`/legacy `COption` подходят для настроек, которыми управляет модуль или администратор сайта, если определены:

- module id и option name;
- default;
- site scope при необходимости;
- тип/нормализация;
- права на чтение/изменение;
- install/uninstall/migration path;
- cache/invalidation;
- запрет утечки в публичный HTML/log.

Не используй option как универсальное secret store. Значение может оказаться в DB backup, административном интерфейсе или диагностическом dump. Для credential сначала проверь security/deployment policy.

Типовой boundary:

```php
use Bitrix\Main\Config\Option;

$raw = Option::get('vendor.module', 'request_timeout', '5');
$timeout = filter_var(
    $raw,
    FILTER_VALIDATE_INT,
    ['options' => ['min_range' => 1, 'max_range' => 60]]
);

if ($timeout === false) {
    throw new \RuntimeException('Invalid vendor.module request_timeout');
}
```

На публичном boundary переведи exception в контролируемый `Result/Error` или безопасную деградацию; не показывай внутренний key/value пользователю.

## Идентификаторы сущностей

Numeric ID допустим внутри runtime после resolution, но не как распределённый magic number в страницах и templates.

Предпочитай:

- iblock: `IBLOCK_TYPE_ID + CODE`, при необходимости site binding;
- element/section: `IBLOCK_ID + XML_ID` или `CODE`, если uniqueness подтверждена;
- HL block: table name или другое уникальное project key;
- custom entity: `XML_ID`, `UF_XML_ID`, `API_CODE`, UUID/external key;
- form/price type/store: project registry/migration по стабильному ключу, который реально поддерживает конкретный модуль.

Не обещай глобальную уникальность `CODE`. Всегда добавляй область уникальности и проверяй duplicate rows.

Хороший delivery path:

```text
migration/install step создаёт или находит сущность по stable key
→ registry разрешает stable key в runtime ID
→ component/service получает int ID
→ missing/duplicate становится явной ошибкой
```

`.env` с numeric ID может оставаться существующим project convention, но агент должен:

1. валидировать positive integer;
2. проверить, что сущность с таким ID существует и имеет ожидаемый type/code/site;
3. не переносить значение между стендами вслепую;
4. предложить stable-key registry/migration, если ID drift уже создаёт ошибки.

## Безопасный registry

Минимальный lookup инфоблока должен проверять module, scope, missing и duplicate:

```php
<?php

use Bitrix\Iblock\IblockTable;
use Bitrix\Main\Loader;

function requireIblockId(string $typeId, string $code): int
{
    if (!Loader::includeModule('iblock')) {
        throw new \RuntimeException('Module iblock is not installed');
    }

    $rows = IblockTable::getList([
        'select' => ['ID', 'IBLOCK_TYPE_ID', 'CODE'],
        'filter' => [
            '=IBLOCK_TYPE_ID' => $typeId,
            '=CODE' => $code,
        ],
        'order' => ['ID' => 'ASC'],
        'limit' => 2,
    ])->fetchAll();

    if (count($rows) !== 1) {
        throw new \RuntimeException(sprintf(
            'Expected one iblock for type/code, got %d',
            count($rows)
        ));
    }

    return (int) $rows[0]['ID'];
}
```

Это boundary example, не готовый глобальный helper. В production:

- помести его в project namespace/service;
- не объявляй глобальную функцию;
- не включай module и не делай lookup внутри каждого template loop;
- добавь site/tenant scope, если нужен;
- реши cache/invalidation;
- не включай реальные type/code в публичный error response, если это раскрывает внутреннюю схему.

Не генерируй глобальные PHP constants для всех инфоблоков при каждом hit без необходимости. Такой autodefine-layer должен отдельно решить collisions, multisite scope, cache lifecycle, error contract и наблюдаемость.

## Кеш и инвалидация

Registry cache должен включать в key всё, что определяет результат:

```text
entity type + stable key + site/tenant + language/edition when relevant
```

Инвалидация:

- migration/install step после изменения mapping;
- module/admin action с правами и `sessid`;
- точный managed/tagged cache contract, подтверждённый текущим core;
- deployment command.

Не очищай registry через анонимный query-параметр вида `?clear_project_cache=Y`. Это создаёт cache-flush/DB-load surface. Не советуй “подождать TTL” как единственный способ применить критичную конфигурацию.

## Контракт ошибки

| Ситуация | Поведение |
|---|---|
| Secret отсутствует на bootstrap | fail deployment/healthcheck; не печатать значение |
| Optional integration отключена | явный disabled state, без сетевого вызова |
| Numeric env invalid | validation error до component/API call |
| Entity не найдена | controlled error/blocked migration, не `0`/`null` в API |
| Найден duplicate | остановить resolution и назвать scope conflict |
| Module отсутствует | deferred/fallback, не вызывать его API |
| Config изменён | точная invalidation + smoke |

Публичная страница не обязана показывать raw exception. В service/controller верни `Result/Error`, safe fallback или 503/health failure по проектному контракту; подробности — в защищённый log без secrets.

## Чеклист

- [ ] Найден существующий project config convention.
- [ ] Значение классифицировано: secret, deployment config, option, entity reference, content.
- [ ] Нет нового Composer/package только ради привычного решения без согласования со стеком проекта.
- [ ] Missing, invalid и duplicate обработаны явно.
- [ ] String → int/bool/url преобразование валидируется.
- [ ] Stable key имеет достаточный scope.
- [ ] Numeric ID перепроверен по ожидаемой сущности.
- [ ] Cache key и invalidation определены.
- [ ] Cache reset защищён правами/CLI, а не публичным query flag.
- [ ] Secrets не попадают в Git, logs, exception, context/evidence.
- [ ] Dev/stage/prod и multisite поведение проверены.

## С чем читать вместе

- Production rules — [production-best-practices.md](production-best-practices.md)
- Миграции — [entities-migrations.md](entities-migrations.md)
- Инфоблоки — [iblocks.md](iblocks.md)
- HL — [highloadblock.md](highloadblock.md)
- Modules/options — [modules-loader.md](modules-loader.md)
- Security — [security.md](security.md)
- Структура проекта — [project-layout-and-includes.md](project-layout-and-includes.md)
