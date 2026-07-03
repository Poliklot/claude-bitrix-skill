# Runtime/perfmon metrics

- Date:
- Project/sandbox:
- Base URL:
- User mode: guest / authorized / admin / CLI
- Cache mode: warm / cold / `?ncc=1`
- Data safety: read-only / sandbox write-mode

## Page/hit metrics

| URL/command | Mode | Before | After | Evidence | Notes |
|---|---|---:|---:|---|---|
| `/catalog/` | guest warm | n/a | n/a | perfmon_hit_list / logs | |

## SQL/ORM metrics

| Query/source | Count/time before | Count/time after | Evidence | EXPLAIN/index notes |
|---|---:|---:|---|---|
| component/template | n/a | n/a | perfmon_sql_list | |

## Cache/composite metrics

| Check | Before | After | Evidence | Notes |
|---|---|---|---|---|
| `X-Bitrix-Composite` | n/a | n/a | headers | |
| `?ncc=1` comparison | n/a | n/a | HTML diff/manual | |
| guest/user A/user B | n/a | n/a | screenshots/logs | |

## Frontend metrics

| Metric | Before | After | Evidence | Notes |
|---|---:|---:|---|---|
| transferred bytes | n/a | n/a | browser network | |
| LCP/CLS | n/a | n/a | Lighthouse/WebPageTest | |

## Verdict

- Runtime verdict: candidate / confirmed / blocked / fixed.
- Follow-up: what remains unverified.
