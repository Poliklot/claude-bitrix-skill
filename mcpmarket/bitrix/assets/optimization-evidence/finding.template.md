# Optimization finding — OPT-001

- ID: OPT-001
- Priority: P1
- Layer: component-cache / tagged-cache / composite / db-orm / frontend-assets / agents-imports / shop
- Verdict: candidate / confirmed / blocked / fixed / accepted-risk
- Source: static audit / perfmon / grep / manual review
- Owner:

## Evidence

- Static: `path/to/file.php:123` — краткое описание строки без secrets.
- Runtime/perfmon: not checked / `perfmon_sql_list.php` snapshot / browser network / logs.
- Reproduction: read-only steps or sandbox steps.

## Impact

Что замедляет, ломает кеш или создаёт риск некорректных/персональных данных.

## Fix plan

1. Минимальное изменение.
2. Side effects: cache/index/rights/composite/shop lifecycle.
3. Rollback: как откатить.

## Verification

- Static: grep/diff check.
- Runtime: before/after page hit, SQL count/time, `X-Bitrix-Composite`, browser network, visual parity.
- Status: pending / pass / fail / blocked.

## Notes

Не писать “точно тормозит”, если есть только static candidate без runtime evidence.
