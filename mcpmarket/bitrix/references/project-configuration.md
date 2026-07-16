# Конфигурация и стабильные идентификаторы

Открывай для `.env`, `Option`, констант, ID инфоблоков/форм/HL, dev/stage/prod drift и lookup по stable key. Сначала сохрани существующий project convention; не добавляй config package ради одного значения.

## Классификация

| Тип | Источник-кандидат |
|---|---|
| secret/credential | runtime environment/secret store; `.env` только по deployment convention |
| deployment config | environment/config layer со schema validation |
| admin setting | module/project `Option` с rights/default/scope/migration |
| entity reference | stable key + migration/registry; numeric ID после resolution |
| code constant | typed versioned config/constant |
| content | property/include/iblock/HL по структуре |

`IBLOCK_ID=12` не становится secret в `.env`; API token не становится безопасным в `Option` без security contract.

## Audit

```bash
find . -maxdepth 4 -type f \( -name '.env.example' -o -name composer.json -o -name '.settings.php' -o -name constants.php -o -name init.php \) -print
rg -l 'Dotenv|\$_ENV|\$_SERVER|getenv\(|Option::get|COption::GetOption|define\(|IBLOCK_ID|FORM_ID|HLBLOCK_ID' \
  local . --glob '*.php' --glob '*.example' --glob '!bitrix/**' --glob '!www/bitrix/**' --glob '!vendor/**'
```

Первый проход выводит только filenames: не делай массовый `rg -n`, потому что совпавшие строки могут содержать credentials. Выбранные файлы проверяй локально и точечно; значения secrets в transcript/evidence заменяй на `<redacted>`.

Проверь bootstrap, project Composer vs core vendor noise, validation/types, environment/site scope, migrations, missing/duplicate behavior, cache/invalidation и secret leaks.

## Environment/options

- `.env.example` — keys/safe placeholders, не credentials;
- env values — strings/missing: validate integer ranges, booleans, URLs/hosts;
- `safeLoad()` не подтверждает наличие обязательных values; required schema нужна отдельно;
- не добавляй `vlucas/phpdotenv`, если проект не использует Composer/config convention;
- `Option` требует module/name/default/site scope/type/rights/install path/invalidation;
- не используй `Option` как universal secret store: значение может попасть в DB backup/admin/debug.

Не печатай config/secrets в log, exception, `BITRIX_PROJECT_CONTEXT.md` или evidence.

## Entity registry

Numeric ID разрешён после runtime resolution, но не как magic number в pages/templates.

Stable lookup scope:

- iblock: `IBLOCK_TYPE_ID + CODE`, при необходимости site binding;
- element/section: `IBLOCK_ID + XML_ID/CODE` с подтверждённой uniqueness;
- HL: table name/project key;
- custom entity: `XML_ID`, `UF_XML_ID`, `API_CODE`, UUID/external key.

Не обещай global uniqueness `CODE`. Lookup обязан:

1. проверить module;
2. выбрать достаточный scope;
3. получить максимум две записи;
4. требовать ровно одну;
5. вернуть typed ID;
6. не передавать `0`/`null` в component/API.

Если numeric ID остаётся в env: validate positive int и перепроверь фактическую entity/type/code/site. При drift предложи migration/stable registry.

## Cache/error contract

Cache key включает entity type + stable key + site/tenant/language where relevant. Invalidation — migration/deployment command, protected admin action с rights+sessid или подтверждённый managed/tagged cache contract.

Не делай anonymous `?clear_project_cache=Y`: это cache-flush/DB-load surface.

| Ошибка | Поведение |
|---|---|
| missing secret | fail deployment/healthcheck без вывода value |
| integration disabled | explicit disabled state |
| invalid numeric config | validation error до API/component |
| entity missing/duplicate | controlled error/blocked migration |
| module missing | deferred/fallback |

На public boundary переводи internal exception в `Result/Error`, safe fallback или проектный health/503 contract.

## Gate

- existing convention найден;
- value class определён;
- no unneeded package;
- types/missing/duplicate validated;
- stable key scoped;
- cache/invalidation defined and protected;
- no secrets in Git/log/context/evidence;
- dev/stage/prod + multisite checked.

Связанные compact references: `project-intake.md`, `project-layout-and-includes.md`, `php-architecture.md`, `content-data.md`, `users-security.md`.
