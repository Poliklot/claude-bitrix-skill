# Release gate

Открывай перед пушем, тегом, GitHub release или публикацией MCP Market-версии, если изменения затрагивают бытовой слой: `behavior-routing`, `project-intake`, `project-layout-and-includes`, `project-configuration`, `task-playbooks`, `reference-map`, `developer-primitives`, `developer-cards`, `first-answer-pitfalls`, `answer-contracts`, `core-grep-cookbook`, `eval-prompts` или навигацию `SKILL.md`.

## Stop conditions

Не релизить, если:

- `quick_validate.py` падает на `bitrix/` или `mcpmarket/bitrix/`, а repo-local fallback `scripts/validate_skill.py` тоже не проходит;
- `git diff --check` не пустой;
- `mcpmarket/bitrix` содержит больше 50 файлов;
- changelog не отражает новый reference/поведение, `bitrix/VERSION` не имеет секции в `CHANGELOG.md`, `PLAN.md` не упоминает текущую версию;
- runtime smoke templates, `scripts/init_runtime_evidence.py` или `scripts/validate_runtime_evidence.py` отсутствуют после изменений runtime smoke слоя;
- `scripts/bitrix_runtime_preflight.py`, `Makefile`, `.github/workflows/validate.yml` или sample blocked evidence отсутствуют после изменений release/evidence workflow;
- optimization evidence templates, `scripts/init_optimization_evidence.py`, `scripts/validate_optimization_evidence.py` или sample candidate pack отсутствуют после изменений optimization audit слоя;
- бытовой eval даёт `fail > 0`;
- compact `SKILL.md` не ссылается на новый critical reference;
- frontmatter `description` не покрывает новый важный trigger.

## Commands

```bash
make validate
make release-check
python3 scripts/validate_skill.py
python3 scripts/bitrix_runtime_preflight.py --public-root www --base-url http://localhost
python3 scripts/init_runtime_evidence.py --package P1 --output /tmp/bitrix-p1-evidence-check
python3 scripts/init_runtime_evidence.py --all --output /tmp/bitrix-all-evidence-check
python3 scripts/validate_runtime_evidence.py examples/runtime-smoke/blocked-p1 --package P1
python3 scripts/init_optimization_evidence.py --output /tmp/bitrix-optimization-evidence-check --finding-count 2
python3 scripts/validate_optimization_evidence.py examples/optimization-evidence/sample-candidate
python3 scripts/validate_runtime_evidence.py path/to/evidence/YYYY-MM-DD-p1-shop-path --package P1  # если есть runtime evidence pack
python3 /Users/igormajorov/.codex/skills/.system/skill-creator/scripts/quick_validate.py bitrix
python3 /Users/igormajorov/.codex/skills/.system/skill-creator/scripts/quick_validate.py mcpmarket/bitrix
git diff --check
find mcpmarket/bitrix -type f | wc -l
git status -sb
```

Expected:

- `scripts/validate_skill.py`: `All validation checks passed.`;
- `make validate`: repo-local validation, sample blocked evidence и shell syntax check проходят;
- `scripts/init_runtime_evidence.py`: создаёт `summary.md`, `00-preflight.md` и scenario files;
- `scripts/init_runtime_evidence.py --all`: создаёт P1–P4 подкаталоги;
- `scripts/init_optimization_evidence.py`: создаёт `summary.md`, `00-runtime-metrics.md` и `OPT-001-finding.md`;
- `scripts/bitrix_runtime_preflight.py`: печатает Markdown preflight без secrets;
- `scripts/validate_runtime_evidence.py`: `Runtime evidence validation passed.`, если релиз включает runtime evidence pack;
- `scripts/validate_optimization_evidence.py`: `Optimization evidence validation passed.`, если релиз включает optimization audit evidence pack;
- both validates: `Skill is valid!`;
- `git diff --check`: no output;
- file count: `<= 50`;
- status: only intended files.

If `quick_validate.py` fails because the local Python has no `yaml` module, treat that as an environment issue and require `scripts/validate_skill.py` as fallback. It checks frontmatter, `agents/openai.yaml`, MCP file count, internal links, critical-reference sync, runtime smoke templates/validator, eval prompt coverage, forbidden markers and `git diff --check` without third-party packages.

## Optimization evidence gate

Если в релиз входят optimization audit findings или утверждение “исправлено/подтверждено”, запустить:

```bash
python3 scripts/init_optimization_evidence.py --output evidence/YYYY-MM-DD-optimization-audit --finding-count 5
python3 scripts/bitrix_static_optimization_audit.py /path/to/project --output evidence/YYYY-MM-DD-optimization-audit/static-audit.md
python3 scripts/validate_optimization_evidence.py evidence/YYYY-MM-DD-optimization-audit
python3 scripts/validate_optimization_evidence.py examples/optimization-evidence/sample-candidate
```

Структура: `summary.md`, `00-runtime-metrics.md`, `OPT-001-finding.md`. Verdicts: `candidate`, `confirmed`, `blocked`, `fixed`, `accepted-risk`. `candidate/blocked` — не runtime pass.

## Runtime evidence gate

Если в релиз входит runtime evidence pack или утверждение “runtime-проверено”, запустить:

```bash
python3 scripts/init_runtime_evidence.py --package P1 --output evidence/YYYY-MM-DD-p1-shop-path
python3 scripts/bitrix_runtime_preflight.py --public-root www --base-url http://localhost > evidence/YYYY-MM-DD-p1-shop-path/00-preflight.md
python3 scripts/init_runtime_evidence.py --all --output evidence/YYYY-MM-DD-runtime-smoke-all
python3 scripts/validate_runtime_evidence.py evidence/YYYY-MM-DD-p1-shop-path --package P1
python3 scripts/validate_runtime_evidence.py examples/runtime-smoke/blocked-p1 --package P1
```

Для `P2–P4` заменить `--package`. `blocked` — допустимый finding, но не runtime pass; в changelog/reference писать “runtime verification blocked by X”.

## Everyday eval gate

Run at least 15 prompts from `eval-prompts.md` across different domains. Recommended set:

```text
B001, B004, B007, B009, B011, B013, B016, B018,
B021, B023, B025, B028, B030, B031, B043, B046,
B048, B052, B053, B057, B060, B061, B062, B063, B064,
B065, B066, B067, B068, B069, B070, B071, B072, B073, B074
```

Threshold:

```text
prompts_checked >= 15
fail = 0
warn <= 3
```

`pass`: correct route, no bad first step, answer follows `answer-contracts.md`.
`warn`: correct but too generic or missing project checks/side effects.
`fail`: clean PHP/SQL/core edit/global cache-off/fake API/optional module assumed.

## Sync checklist

For every new critical reference:

- full file exists in `bitrix/references/`;
- compact file or compact bundle exists in `mcpmarket/bitrix/references/`;
- full and compact `SKILL.md` link it;
- related references mention it if needed;
- `CHANGELOG.md` mentions it;
- MCP Market file count remains below 50.

## Evidence table

```text
repo-local validate_skill: pass/fail
quick_validate bitrix: pass/fail
quick_validate mcpmarket: pass/fail
git diff --check: pass/fail
MCP Market files: N/50
changelog updated: yes/no
full/compact synced: yes/no
sample blocked evidence: pass/fail
eval checked: N
eval fail: N
eval warn: N
```

## Release safety

- Do not commit, push, tag, or publish release without explicit user request.
- Before commit show `git status -sb` / `git diff --stat`.
- Before tag/release, ensure changelog/version are updated and tree is clean after commit.
