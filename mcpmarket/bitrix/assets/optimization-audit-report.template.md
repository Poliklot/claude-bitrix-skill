# Bitrix optimization audit report

> Read-only отчёт по оптимизациям проекта. Не хранить secrets, cookies, tokens, персональные данные, production XML/дампы и приватные payloads. Static findings не равны runtime/perfmon pass.

- Дата:
- Агент/оператор:
- Project root:
- Public root:
- Branch/commit:
- Runtime scope: not checked / read-only / staging / sandbox
- Static audit command:
- Runtime/perfmon evidence directory:
- Optimization evidence pack: `evidence/YYYY-MM-DD-optimization-audit` (см. `scripts/init_optimization_evidence.py`)

## Краткий вывод

- 

## Что уже оптимизировано

| Слой | Evidence | Комментарий |
|---|---|---|
| Component cache | | |
| Tagged/managed cache | | |
| Composite/static HTML | | |
| SQL/ORM/preload | | |
| Images/assets/frontend | | |
| Agents/cron/stepper/imports | | |
| Search/facet/SEO indexes | | |
| Shop/catalog/sale | | |

## Ошибки и недоработки оптимизаций

| Priority | Место | Проблема | Почему важно | Что сделать | Проверка |
|---|---|---|---|---|---|
| P0/P1/P2/P3 | | | | | |

Если finding переносится в evidence pack, используй ID `OPT-001`, `OPT-002`, ... и verdict `candidate/confirmed/blocked/fixed/accepted-risk`.

## Быстрые safe wins

1. 

## Требует runtime/perfmon evidence

| Кандидат | Какая метрика нужна | Как собрать | Blocker |
|---|---|---|---|
| | `perfmon_hit/sql/cache/comp`, `EXPLAIN`, `X-Bitrix-Composite`, browser network | | |

## Что не трогать вслепую

- Redis/Memcached/CDN без доказанного bottleneck.
- Composite без проверки персонализации.
- DB indexes без `EXPLAIN`/perfmon.
- Full cache clear/reindex/import на production без окна и rollback.
- Raw SQL по `b_sale_*`/`b_catalog_*`/business tables без repair plan.

## Evidence details

### Static audit

```text
[вставить ключевой вывод scripts/bitrix_static_optimization_audit.py]
```

### Runtime/perfmon

- `perfmon_hit_list.php`:
- `perfmon_sql_list.php`:
- `perfmon_cache_list.php`:
- `perfmon_comp_list.php`:
- `perfmon_explain.php` / DB `EXPLAIN`:
- `X-Bitrix-Composite` / `?ncc=1`:
- Browser network/web-vitals:

## Follow-up

- [ ] Обновить `BITRIX_PROJECT_CONTEXT.md` секцию “Кеши и оптимизации”.
- [ ] Создать issues/tasks для P0/P1.
- [ ] Повторить static audit после исправлений.
- [ ] Повторить runtime/perfmon проверку на staging/sandbox.
