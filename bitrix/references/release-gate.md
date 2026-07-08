# Release gate для бытового Bitrix-слоя

Открывай перед пушем, тегом, GitHub release или публикацией MCP Market-версии, когда изменения затрагивают бытовой слой: [behavior-routing.md](behavior-routing.md), [project-intake.md](project-intake.md), [task-playbooks.md](task-playbooks.md), [reference-map.md](reference-map.md), [developer-primitives.md](developer-primitives.md), [developer-cards.md](developer-cards.md), [first-answer-pitfalls.md](first-answer-pitfalls.md), [answer-contracts.md](answer-contracts.md), [core-grep-cookbook.md](core-grep-cookbook.md), [eval-prompts.md](eval-prompts.md) или навигацию в `SKILL.md`.

Цель: релизить только тогда, когда skill валиден локально и в CI, compact-версия не раздута, changelog/версия/PLAN синхронизированы, runtime evidence не содержит secrets, а бытовые prompt не проваливаются в чистый PHP/SQL/правку ядра.

## Стоп-условия

Не релизить, если есть хотя бы один пункт:

- `quick_validate.py` падает на `bitrix/` или `mcpmarket/bitrix/`, а repo-local fallback `scripts/validate_skill.py` тоже не проходит;
- `git diff --check` находит whitespace/error;
- MCP Market folder содержит `> 50` файлов;
- changelog не описывает новый reference/поведение;
- `bitrix/VERSION` не имеет секции в `CHANGELOG.md`, `PLAN.md` не упоминает текущую версию или `[Unreleased]` сравнивается не от последнего тега;
- runtime smoke templates, `scripts/init_runtime_evidence.py` или `scripts/validate_runtime_evidence.py` отсутствуют после изменений runtime smoke слоя;
- `scripts/bitrix_runtime_preflight.py`, `Makefile`, `.github/workflows/validate.yml` или sample blocked evidence отсутствуют после изменений release/evidence workflow;
- optimization evidence templates, `scripts/init_optimization_evidence.py`, `scripts/validate_optimization_evidence.py` или sample candidate pack отсутствуют после изменений optimization audit слоя;
- бытовой regression даёт `fail > 0`;
- в ответах eval есть первый шаг из [first-answer-pitfalls.md](first-answer-pitfalls.md);
- compact-версия не содержит новый critical reference или ссылку на него из `mcpmarket/bitrix/SKILL.md`;
- frontmatter `description` не покрывает новый важный trigger.

## Минимальные команды

Запускать из корня репозитория:

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

Ожидание:

- `python3 scripts/validate_skill.py` → `All validation checks passed.`;
- `make validate` → проходит repo-local validation, sample blocked evidence и shell syntax check;
- `python3 scripts/init_runtime_evidence.py ...` → создаёт `summary.md`, `00-preflight.md` и scenario files;
- `python3 scripts/init_runtime_evidence.py --all ...` → создаёт подкаталоги `p1-shop-path`, `p2-commerceml`, `p3-rest-webservice`, `p4-marketing-automation`;
- `python3 scripts/init_optimization_evidence.py ...` → создаёт `summary.md`, `00-runtime-metrics.md` и `OPT-001-finding.md`;
- `python3 scripts/bitrix_runtime_preflight.py ...` → печатает Markdown-фрагмент preflight без secrets;
- `python3 scripts/validate_runtime_evidence.py ...` → `Runtime evidence validation passed.`, если в релиз входит runtime evidence pack;
- `python3 scripts/validate_optimization_evidence.py ...` → `Optimization evidence validation passed.`, если в релиз входит optimization audit evidence pack;
- оба `quick_validate.py` → `Skill is valid!`;
- `git diff --check` без вывода;
- `find ... | wc -l` ≤ `50`;
- `git status -sb` показывает только ожидаемые файлы.

Если `quick_validate.py` недоступен из-за локального окружения, например `ModuleNotFoundError: No module named 'yaml'`, не чинить это правкой skill-а. Зафиксировать причину как environment issue и использовать `scripts/validate_skill.py` как обязательный fallback: он проверяет frontmatter, `agents/openai.yaml`, MCP Market file-count, внутренние markdown-ссылки, синхронизацию critical references, runtime smoke templates/validator, eval prompt coverage, forbidden markers и `git diff --check` без сторонних Python-пакетов.

## Optimization evidence gate

Если изменения включают audit findings по оптимизациям или утверждение “исправлено/подтверждено”, дополнительно проверить optimization evidence pack:

```bash
python3 scripts/init_optimization_evidence.py --output evidence/YYYY-MM-DD-optimization-audit --finding-count 5
python3 scripts/bitrix_static_optimization_audit.py /path/to/project --output evidence/YYYY-MM-DD-optimization-audit/static-audit.md
python3 scripts/validate_optimization_evidence.py evidence/YYYY-MM-DD-optimization-audit
python3 scripts/validate_optimization_evidence.py examples/optimization-evidence/sample-candidate
```

Валидатор должен подтвердить:

- есть `summary.md`;
- есть rows `OPT-001` и далее с verdict `candidate/confirmed/blocked/fixed/accepted-risk`;
- есть отдельные finding files;
- есть разделы `Static audit`, `Runtime/perfmon`, `Safe wins`, `Blocked/runtime-needed`;
- явные secrets/tokens/cookies не найдены.

`candidate` или `blocked` — допустимый finding, но не runtime/perfmon pass. В changelog/reference писать “candidate requires perfmon evidence” или “blocked by sandbox”, а не “ускорено”.

## Runtime evidence gate

Если изменения включают runtime smoke evidence или утверждение “проверено в runtime”, дополнительно проверить evidence pack:

```bash
python3 scripts/init_runtime_evidence.py --package P1 --output evidence/YYYY-MM-DD-p1-shop-path
python3 scripts/bitrix_runtime_preflight.py --public-root www --base-url http://localhost > evidence/YYYY-MM-DD-p1-shop-path/00-preflight.md
python3 scripts/init_runtime_evidence.py --all --output evidence/YYYY-MM-DD-runtime-smoke-all
python3 scripts/validate_runtime_evidence.py evidence/YYYY-MM-DD-p1-shop-path --package P1
```

Для пакетов `P2–P4` указывать соответствующий `--package`. Валидатор должен подтвердить:

- есть `summary.md`;
- есть строки обязательных scenarios и verdict `pass/fail/blocked`;
- есть отдельные scenario files;
- есть rows по core modules;
- явные secrets/tokens/cookies не найдены.
- sample blocked pack проходит: `python3 scripts/validate_runtime_evidence.py examples/runtime-smoke/blocked-p1 --package P1`.

Если проверка `blocked`, это допустимый runtime finding, но не runtime pass. В changelog/reference писать “runtime verification blocked by X”, а не “проверено”.

## Link/readability sanity

Проверить хотя бы изменённую поверхность:

```bash
grep -R "behavior-routing\\|project-intake\\|reference-map\\|developer-primitives\\|first-answer-pitfalls\\|developer-cards\\|answer-contracts\\|core-grep-cookbook\\|eval-prompts\\|release-gate" -n \
  bitrix/SKILL.md mcpmarket/bitrix/SKILL.md \
  bitrix/references/developer-primitives.md \
  bitrix/references/developer-cards.md \
  bitrix/references/first-answer-pitfalls.md \
  bitrix/references/answer-contracts.md \
  bitrix/references/core-grep-cookbook.md \
  bitrix/references/eval-prompts.md \
  mcpmarket/bitrix/references/developer-primitives.md \
  mcpmarket/bitrix/references/developer-cards.md \
  mcpmarket/bitrix/references/first-answer-pitfalls.md \
  mcpmarket/bitrix/references/answer-contracts.md \
  mcpmarket/bitrix/references/core-grep-cookbook.md \
  mcpmarket/bitrix/references/eval-prompts.md
```

Если добавлен новый reference, он должен быть:

1. создан в `bitrix/references/`;
2. создан или осознанно сжат в `mcpmarket/bitrix/references/`;
3. подключён в `bitrix/SKILL.md`;
4. подключён в `mcpmarket/bitrix/SKILL.md`;
5. упомянут в `CHANGELOG.md`;
6. не ломать MCP Market лимит 50 файлов.

## Бытовой regression gate

Перед релизом бытового слоя прогнать минимум 15 prompt из [eval-prompts.md](eval-prompts.md). Выбирать разные домены, а не 15 meta/head вариантов.

Рекомендуемый минимальный набор:

| ID | Домен |
|---|---|
| B001 | meta/title/head |
| B004 | CSS/Asset |
| B007 | IncludeFile/editable content |
| B009 | breadcrumbs |
| B011 | current user |
| B013 | request GET |
| B016 | Loader/module include |
| B018 | 404 |
| B021 | images/CFile |
| B023 | iblock property |
| B025 | cache |
| B028 | mail |
| B030 | ajax |
| B031 | events |
| B043 | catalog price after module check |
| B046 | 1C/CommerceML |
| B053 | runtime smoke boundary |
| B057 | evidence validator |
| B060 | optimization audit report |
| B061 | DB/ORM/N+1 optimization |
| B062 | shop/filter optimization |
| B063 | agents/imports optimization |
| B064 | frontend/assets optimization |
| B065 | update-safe admin customization |
| B066 | admin form tab customization |
| B067 | admin list group action/context button |
| B068 | admin menu section |
| B069 | module admin page placement |

Оценка:

- `pass`: правильные references, нет bad first step, ответ следует [answer-contracts.md](answer-contracts.md);
- `warn`: маршрут верный, но не хватает project checks/side effects;
- `fail`: чистый PHP/SQL/правка ядра/глобальный cache-off/выдуманный API/обещан optional module без check.

Релизный порог:

```text
prompts_checked >= 15
fail = 0
warn <= 3
```

Если `warn > 3`, не блокировать релиз автоматически, но усилить reference, из-за которого ответы общие.

## Evidence table

Перед финальным “готово релизить” держать краткую таблицу:

| Check | Result |
|---|---|
| repo-local validate_skill | pass/fail |
| quick_validate bitrix | pass/fail |
| quick_validate mcpmarket/bitrix | pass/fail |
| git diff --check | pass/fail |
| MCP Market file count | N/50 |
| changelog updated | yes/no |
| full/compact references synced | yes/no |
| eval prompts checked | N |
| eval fail | N |
| eval warn | N |

## Changelog/version gate

Перед релизом:

1. Все изменения описаны в `## [Unreleased]`.
2. Если готовится версия, перенести bullets из `Unreleased` в `## [X.Y.Z] — YYYY-MM-DD`.
3. Обновить `bitrix/VERSION`, frontmatter `metadata.version` в `bitrix/SKILL.md` и `mcpmarket/bitrix/SKILL.md`, если релиз меняет версию.
4. Не менять версию без соответствующего changelog.

## MCP Market compact gate

Проверить:

- в `mcpmarket/bitrix/` нет lifecycle scripts (`update.sh`, installers, uninstallers);
- новый reference либо compact, либо включён в существующий bundle;
- file count ≤ 50;
- compact `SKILL.md` явно говорит, когда читать новый reference;
- full-only ссылки внутри compact-файлов не используются как обязательный маршрут для MCP Market.

## Git/release safety

- Не коммитить и не пушить без явного запроса пользователя.
- Перед `git add` показать scope через `git status -sb` и/или `git diff --stat`.
- В commit message указать поведенческий слой, например `Add Bitrix everyday answer release gate`.
- Перед тегом убедиться, что рабочее дерево чистое после commit.
- GitHub release публиковать только после успешного push/tag и если пользователь явно попросил релиз.

## Хороший финальный отчёт

Финальный отчёт после gate:

```text
Проверил release gate:
- validate full/compact: OK
- diff-check: OK
- MCP Market files: N/50
- eval: checked N, fail 0, warn M
- changelog/version: OK

Готово к commit/push/release.
```

Если что-то не пройдено, не писать “готово”; назвать блокер и следующий фикс.
