# Compact reference map

Открывай, когда `behavior-routing.md` выбрал режим, но нужно понять, какой compact bundle загрузить. MCP Market-версия хранит укрупнённые bundles вместо полной карты из full `bitrix/references/`.

| Задача | Bundle |
|---|---|
| Режим работы, аудит проекта, `BITRIX_PROJECT_CONTEXT.md` и типовые маршруты правок | `behavior-routing.md`, `project-intake.md`, `../assets/BITRIX_PROJECT_CONTEXT.template.md`, `task-playbooks.md`, `core-grep-cookbook.md` |
| Бытовой ответ: meta/head/assets/includes/request/user/images/cache/mail | `developer-primitives.md`, `first-answer-pitfalls.md`, `developer-cards.md`, `answer-contracts.md` |
| Release/eval бытового слоя | `eval-prompts.md`, `release-gate.md` |
| Core audit, version mismatch, tail modules, task routing, diagnostics, pitfalls, runtime smoke | `core-routing.md`, `version-impact.md`, `shop-core-tail-modules.md` |
| PHP architecture, production practice, modules, ORM, DB, events, validation, HTTP | `php-architecture.md` |
| Iblock/HL/UF/migrations/import-export/SEF | `content-data.md` |
| Components/templates/pagination/admin UI/file uploader | `components-admin-ui.md` |
| Users/RBAC/auth/session/security/socialservices | `users-security.md` |
| Blog/forum/vote/webforms/mail/subscribe | `content-modules.md` |
| Landing/sitecorporate/photogallery/fileman/location/messageservice/clouds/mobileapp/b24connector/translate | `site-cloud-mobile.md`, `shop-core-tail-modules.md` |
| Search/SEO/cache/composite/аудит оптимизаций/update/perf/operations | `search-seo-ops.md`, plus `components-admin-ui.md` for component/template bottlenecks and `users-security.md` for dynamic/personal blocks |
| REST/webhooks/apps/events | `integrations-rest.md` |
| Commerce: catalog/sale/currency/shop components/marketing/bizproc/webservice/1C | `commerce-shop.md` |

## Full-to-compact coverage manifest

Этот manifest нужен для CI-защиты от drift: каждый full reference должен быть либо отдельным compact-файлом, либо входить в один из compact bundles.

| Full reference | Compact coverage |
|---|---|
| `access-rbac.md` | `users-security.md` |
| `admin-ui.md` | `components-admin-ui.md` |
| `agents-imports-performance.md` | `search-seo-ops.md`, `core-routing.md` |
| `answer-contracts.md` | `answer-contracts.md` |
| `b24connector.md` | `site-cloud-mobile.md` |
| `behavior-routing.md` | `behavior-routing.md` |
| `bitrixcloud.md` | `site-cloud-mobile.md` |
| `blog-socialnet.md` | `content-modules.md` |
| `cache-infra.md` | `search-seo-ops.md` |
| `catalog.md` | `commerce-shop.md` |
| `clouds.md` | `site-cloud-mobile.md` |
| `commerce-1c-integration.md` | `commerce-shop.md` |
| `commerce-workflows.md` | `commerce-shop.md` |
| `component-dataflow-debugging.md` | `search-seo-ops.md` |
| `composite-cache.md` | `search-seo-ops.md`, `components-admin-ui.md`, `users-security.md` |
| `components.md` | `components-admin-ui.md` |
| `core-audit-matrix.md` | `core-routing.md` |
| `core-grep-cookbook.md` | `core-grep-cookbook.md` |
| `currency.md` | `commerce-shop.md` |
| `custom-uf-types.md` | `content-data.md` |
| `database-layer.md` | `php-architecture.md` |
| `db-orm-performance.md` | `search-seo-ops.md`, `php-architecture.md` |
| `developer-cards.md` | `developer-cards.md` |
| `developer-primitives.md` | `developer-primitives.md` |
| `diagnostic-visibility.md` | `search-seo-ops.md` |
| `entities-migrations.md` | `content-data.md` |
| `eval-prompts.md` | `eval-prompts.md` |
| `events-routing.md` | `php-architecture.md` |
| `file-upload-modern.md` | `components-admin-ui.md` |
| `fileman.md` | `site-cloud-mobile.md` |
| `first-answer-pitfalls.md` | `first-answer-pitfalls.md` |
| `forum.md` | `content-modules.md` |
| `frontend-assets-performance.md` | `search-seo-ops.md`, `components-admin-ui.md` |
| `grid-admin-modern.md` | `components-admin-ui.md` |
| `highloadblock.md` | `content-data.md` |
| `http.md` | `php-architecture.md` |
| `iblock-hl-relations.md` | `content-data.md` |
| `iblocks.md` | `content-data.md` |
| `import-export.md` | `content-data.md` |
| `index-cache-diagnostics.md` | `search-seo-ops.md` |
| `landing.md` | `site-cloud-mobile.md` |
| `location.md` | `site-cloud-mobile.md` |
| `mail-notifications.md` | `content-modules.md` |
| `messageservice.md` | `site-cloud-mobile.md` |
| `mobileapp.md` | `site-cloud-mobile.md` |
| `modules-loader.md` | `php-architecture.md` |
| `noncommerce-task-matrix.md` | `core-routing.md` |
| `numerator.md` | `components-admin-ui.md` |
| `operations-runbook.md` | `search-seo-ops.md` |
| `orm.md` | `php-architecture.md` |
| `pagination.md` | `components-admin-ui.md` |
| `perfmon.md` | `search-seo-ops.md` |
| `photogallery.md` | `site-cloud-mobile.md` |
| `php-legacy-modernization.md` | `php-architecture.md` |
| `php-quality.md` | `php-architecture.md` |
| `php-testing.md` | `php-architecture.md` |
| `php-workflow.md` | `php-architecture.md` |
| `pitfalls-matrix.md` | `core-routing.md` |
| `production-best-practices.md` | `core-routing.md` |
| `project-intake.md` | `project-intake.md` |
| `project-optimization-audit.md` | `search-seo-ops.md`, `core-grep-cookbook.md`, `developer-cards.md` |
| `push-pull.md` | `commerce-shop.md` |
| `reference-map.md` | `reference-map.md` |
| `release-gate.md` | `release-gate.md` |
| `rest.md` | `integrations-rest.md` |
| `runtime-smoke-verification.md` | `core-routing.md` |
| `sale.md` | `commerce-shop.md` |
| `search.md` | `search-seo-ops.md` |
| `security.md` | `users-security.md` |
| `sef-urls.md` | `content-data.md` |
| `seo-cache-access.md` | `search-seo-ops.md` |
| `session-auth.md` | `users-security.md` |
| `shop-automation-bizproc.md` | `commerce-shop.md` |
| `shop-core-module-inventory.md` | `core-routing.md` |
| `shop-core-tail-modules.md` | `shop-core-tail-modules.md` |
| `shop-integrations-webservice.md` | `commerce-shop.md` |
| `shop-marketing-analytics.md` | `commerce-shop.md` |
| `shop-performance.md` | `commerce-shop.md`, `search-seo-ops.md` |
| `shop-standard-components.md` | `commerce-shop.md` |
| `shop-task-matrix.md` | `core-routing.md` |
| `sitecorporate.md` | `site-cloud-mobile.md` |
| `socialservices.md` | `users-security.md` |
| `standard-components-noncommerce.md` | `components-admin-ui.md` |
| `storeassist.md` | `commerce-shop.md` |
| `subscribe.md` | `content-modules.md` |
| `task-playbooks.md` | `task-playbooks.md` |
| `templates.md` | `components-admin-ui.md` |
| `translate.md` | `site-cloud-mobile.md` |
| `update-stepper.md` | `search-seo-ops.md` |
| `userconsent.md` | `components-admin-ui.md` |
| `users.md` | `users-security.md` |
| `validation.md` | `php-architecture.md` |
| `version-impact.md` | `version-impact.md` |
| `vote.md` | `content-modules.md` |
| `webforms.md` | `content-modules.md` |
| `workflow.md` | `content-modules.md` |

## Compact guardrails

- Если задача про конкретный repo — сначала `BITRIX_PROJECT_CONTEXT.md` при наличии, затем факты проекта, потом ответ.
- Если модуль optional — сначала module check; если версия отличается от baseline — `version-impact.md`.
- Не отвечать прямым SQL/core edit/global cache-off/manual meta первым вариантом; для composite не путать `setFrameMode` vote и `createFrame` dynamic boundary.
- Для shop/1C не использовать commerce route без `catalog`/`sale`/`currency` checks.
- Для подробной полной карты использовать full edition `bitrix/references/reference-map.md`.
