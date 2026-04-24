# Operations Runbook без магазина — справочник

> Reference для Bitrix-скилла. Загружай для задач эксплуатации: переносы между стендами, агенты/cron, stepper, импорты, резервное копирование, perf diagnostics, обновления core, права и сопровождение.

## Содержание
- Code-first подход
- Перед изменениями
- Agents/cron/stepper
- Импорты и повторный запуск
- Перенос между стендами
- Обновления core
- Производительность
- Backup/monitoring
- Common mistakes

## Code-first подход

Для эксплуатационных задач предпочитай воспроизводимое изменение:

- migration/install step;
- CLI command;
- agent/stepper;
- module option change через код;
- documented rollback.

Админские клики годятся как диагностика, но не как единственный delivery path.

## Перед изменениями

Проверь:

1. какие модули реально установлены;
2. какие данные будут изменены;
3. есть ли backup/rollback;
4. затронуты ли кеши/индексы/права;
5. нужен ли maintenance window;
6. можно ли запустить операцию повторно без дублей.

## Agents/cron/stepper

| Сценарий | Выбор |
|---|---|
| короткая регулярная задача | agent |
| тяжёлая пакетная миграция | stepper |
| системный cron проекта | CLI command/script |
| повторяемый импорт | idempotent job + log + resume state |
| обновление ядра/модуля | update step + rollback note |

Проверяй `update-stepper.md`, `cache-infra.md`, `perfmon.md`.

## Импорты и повторный запуск

Хороший импорт:

- имеет external id;
- идемпотентен;
- пишет лог ошибок;
- умеет batching;
- не держит всё в памяти;
- обновляет индексы/кеши после завершения;
- различает validation error и transport/runtime error.

## Перенос между стендами

Проверь:

- module versions;
- site ids and languages;
- templates and wizard assets;
- iblock types/ids vs XML_ID/API_CODE;
- HL block names/table names;
- user groups and rights;
- files and clouds `HANDLER_ID`;
- agents and options;
- urlrewrite/SEF;
- search/SEO rebuild needs.

## Обновления core

Перед обновлением:

1. зафиксировать версию модулей;
2. найти project overrides стандартных компонентов;
3. проверить, какие stock templates копировались;
4. снять список custom event handlers;
5. проверить PHP version compatibility;
6. после обновления пройти smoke matrix.

## Производительность

Смотри:

- perfmon SQL/hit/cache reports;
- N+1 in components/templates;
- repeated `Loader::includeModule`/option calls in loops;
- ORM runtime fields and indexes;
- cache keys and personalization;
- heavy logic in template;
- AJAX split for dynamic blocks.

## Backup/monitoring

В текущем core есть:

- `bitrixcloud` для backup/monitoring policy;
- `clouds` для внешних bucket-ов;
- `security` checks;
- `perfmon` diagnostics.

Не путай `bitrixcloud` monitoring/backup с обычным file storage из `clouds`.

## Common mistakes

- Делать одноразовый скрипт без повторного запуска и rollback.
- Хардкодить внутренние IDs вместо XML_ID/code/table names.
- Не очищать кеш/индексы после массовой операции.
- Переносить файлы без учёта `clouds` and `HANDLER_ID`.
- Обновлять core и не сверять copied templates со stock changes.

## С чем читать вместе

- Update stepper — [update-stepper.md](update-stepper.md)
- Cache/perf — [cache-infra.md](cache-infra.md), [perfmon.md](perfmon.md)
- Import/export — [import-export.md](import-export.md)
- Cloud files — [clouds.md](clouds.md)
- Bitrix Cloud — [bitrixcloud.md](bitrixcloud.md)
- Security — [security.md](security.md)
