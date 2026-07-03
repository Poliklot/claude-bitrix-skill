# Optimization evidence summary

> Шаблон evidence pack для аудита оптимизаций Bitrix-проекта. Не коммить сюда secrets, cookies, session ids, production XML/дампы, персональные данные и полный HTML с приватными блоками.

- Дата: YYYY-MM-DD
- Агент/оператор:
- Project/repo:
- Branch/commit:
- Public root:
- Base URL / sandbox:
- Static audit command: `python3 scripts/bitrix_static_optimization_audit.py /path/to/project --output /tmp/bitrix-optimization-audit.md`
- Static audit report: `static-audit.md`
- Runtime/perfmon scope: none / read-only / sandbox write-mode
- Общий verdict: `candidate` / `confirmed` / `blocked` / `fixed`

## Scope

| Слой | Включено | Ограничения |
|---|---|---|
| Component cache | yes/no | |
| Tagged/managed cache | yes/no | |
| Composite/static HTML | yes/no | |
| DB/ORM/N+1 | yes/no | |
| Frontend/assets/images | yes/no | |
| Agents/imports/cron/stepper | yes/no | |
| Shop/catalog/sale | yes/no/not installed | |

## Static audit

| Artifact | Path | Notes |
|---|---|---|
| Markdown report | `static-audit.md` | generated/read-only |
| JSON report | `static-audit.json` | optional |
| Grep notes | `grep-notes.md` | optional |

## Findings

| ID | Priority | Layer | Verdict | Evidence file | Notes |
|---|---|---|---|---|---|
| OPT-001 | P1 | db-orm | candidate | OPT-001-finding.md | подтвердить perfmon SQL count/time |

Allowed verdicts: `candidate`, `confirmed`, `blocked`, `fixed`, `accepted-risk`.

## Runtime/perfmon

| Metric | Before | After | Evidence | Notes |
|---|---:|---:|---|---|
| page hit time | n/a | n/a | 00-runtime-metrics.md | runtime не запускался |
| SQL count/time | n/a | n/a | 00-runtime-metrics.md | |
| component/cache | n/a | n/a | 00-runtime-metrics.md | |
| composite headers | n/a | n/a | 00-runtime-metrics.md | |
| browser network/LCP | n/a | n/a | 00-runtime-metrics.md | |

## Safe wins

1. Сначала закрыть P0/P1 findings с минимальным изменением бизнес-логики.
2. Не включать Redis/CDN/composite/indexes без evidence bottleneck.

## Blocked/runtime-needed

- Runtime/perfmon доступ: available/blocked.
- Что нужно для подтверждения: sandbox, perfmon snapshot, access logs, browser network, fixtures.

## Cleanup

- Secrets removed: yes/no
- Test data removed: yes/no/not applicable
- Follow-up references to update:
  - [ ] `bitrix/references/project-optimization-audit.md`
  - [ ] `bitrix/references/db-orm-performance.md`
  - [ ] `bitrix/references/frontend-assets-performance.md`
  - [ ] `bitrix/references/agents-imports-performance.md`
  - [ ] `bitrix/references/shop-performance.md`
