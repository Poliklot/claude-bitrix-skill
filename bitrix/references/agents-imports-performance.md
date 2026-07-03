# Agents/imports/cron/stepper performance — справочник

> Загружай при задачах “агенты грузят сайт”, “импорт тормозит”, “обмен 1С долгий”, “нужно вынести задачу в cron/stepper”, “массовая операция падает по таймауту”. Для общего аудита сначала [project-optimization-audit.md](project-optimization-audit.md), для stepper — [update-stepper.md](update-stepper.md), для операций — [operations-runbook.md](operations-runbook.md), для импорта — [import-export.md](import-export.md), [commerce-1c-integration.md](commerce-1c-integration.md).

## Принцип

Тяжёлые операции не должны жить в пользовательском HTTP-хите:

```text
HTTP/admin action → enqueue/state → agent/cron/stepper/CLI → batch → checkpoint/log → targeted cache/index invalidation
```

## Быстрый grep

```bash
rg -n 'CAgent::AddAgent|CAgent::RemoveAgent|CheckAgents|agents_use_crontab|Stepper|bindClass|execAgent|cron|set_time_limit|ignore_user_abort|import|exchange|CommerceML|checkauth|mode=import|XML_ID|CML2_LINK|clearCache|clearByTag|ReIndexAll' \
  local local/php_interface bitrix/php_interface www/bitrix/php_interface local/modules --glob '*.php'
```

## Agents vs cron vs stepper vs CLI

| Сценарий | Выбор | Почему |
|---|---|---|
| короткая регулярная задача | agent/cron | минимальный state |
| тяжёлая пакетная операция | stepper/CLI | batch, progress, resume |
| импорт/обмен | idempotent job + log + checkpoint | повторный запуск без дублей |
| admin-triggered mass update | enqueue + stepper | не держать HTTP |
| deploy/rebuild | CLI command/script | воспроизводимость |

## Красные флаги

- agent делает полный проход по всем элементам без limit;
- import запускается через public/admin HTTP и держит соединение;
- нет external id / idempotency / compare-before-update;
- нет checkpoint/resume state;
- errors пишутся только в echo/HTML;
- после каждой строки чистится весь cache/search index;
- `set_time_limit(0)` используется как “архитектура”.

## Batch pattern

```text
find next batch by >lastId or queue table
process <= N rows
save checkpoint: lastId/count/errors/time
register next step if remains
invalidate affected tags once per batch/end
write log with correlation id
```

## Cache/index после массовых операций

После импорта/массовой правки:

- component/tagged cache — по affected iblock/entity tags;
- managed cache — только если менялись options/schema/metadata;
- composite HTML — по затронутым public pages или full only if justified;
- search/facet/SEO — batch rebuild, не полный production rebuild без окна.

## 1С/CommerceML

Для 1С отдельно проверяй:

- flow `checkauth → init → file → import`;
- chunk/zip/temp files;
- cookies/session/sessid;
- `XML_ID`, `CML2_LINK`, duplicate policy;
- exchange logs;
- cache/index invalidation после successful import, а не после upload.

## Формат finding

```text
Evidence: local/php_interface/init.php:80 agent processes all iblock elements without limit
Impact: hit-mode может грузить публичные запросы
Fix: batch stepper/CLI with checkpoint + cron
Verify: runtime duration, agent mode, logs, repeated run safety
```
