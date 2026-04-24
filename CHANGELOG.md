# Changelog

Формат: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), версионирование: [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.14.0] — 2026-04-24

### Added
- `bitrix/references/php-workflow.md` — отдельный reference по PHP-heavy задачам в Bitrix-проекте: service-layer, DTO/value-object границы, exceptions vs `Result/Error`, project toolchain (`composer`, `phpunit`, `phpstan`/`psalm`, fixer/sniffer, `rector`) и минимальные quality gates без конфликта с Bitrix-нормами

### Changed
- `bitrix/SKILL.md` теперь явно маршрутизирует PHP-heavy Bitrix-задачи в новый `php-workflow.md`, учитывает project-tooling-first подход и фиксирует границы для `strict_types`, exceptions и foreign framework patterns
- `README.md` синхронизирован с новым PHP-покрытием и дополнен `php-workflow.md` в матрице reference-файлов

## [1.13.0] — 2026-04-15

### Changed
- `bitrix/references/sitecorporate.md` дополнен реальным wizard template/public слоем и зафиксированным фактом, что `corp_furniture` skeleton местами тянет `bitrix:catalog`, не доказывая наличие магазинного core
- `bitrix/references/blog-socialnet.md` дополнен stock template layer для случая без `www/local`: `micro`, `old_version`, `socialnetwork`, `result_modifier.php`, JS и upload hooks
- `bitrix/references/webforms.md` дополнен stock component/template layer для случая без `www/local`: `intranet`-templates, cache/tags/error-style слой и component-level развилки `form.result.new`
- `bitrix/SKILL.md` теперь явно учитывает checkout без `local/*` и ведёт аудит в stock templates и wizard assets текущего core
- `README.md` синхронизирован с новым покрытием template/public слоя поверх уже проверенного core

## [1.12.0] — 2026-04-15

### Added
- `bitrix/references/sitecorporate.md` — отдельный core-first справочник по модулю `bitrix.sitecorporate`, wizard-решениям `corp_services` / `corp_furniture` и stock `furniture.*` компонентам

### Changed
- `bitrix/references/blog-socialnet.md` переписан под реально установленный `blog`: D7 read-only таблицы, `CBlog*`, mail reply handlers, search reindex и условный `socialnet`-контур
- `bitrix/references/webforms.md` расширен до реального `form`-workflow: статусы, handlers, validators, CRM link, secure file access и стандартные `form.*` компоненты
- `bitrix/SKILL.md` теперь явно маршрутизирует задачи в `sitecorporate.md` и фиксирует core-first ограничения для `blog` и `form`
- `README.md` синхронизирован с новым покрытием текущего core и обновлёнными описаниями `sitecorporate`, `blog` и `form`

## [1.11.0] — 2026-04-15

### Added
- `bitrix/references/mobileapp.md` — отдельный core-first справочник по модулю `mobileapp`
- `bitrix/references/b24connector.md` — отдельный core-first справочник по модулю `b24connector`

### Changed
- `bitrix/SKILL.md` теперь явно считает `mobileapp` и `b24connector` активными модулями текущего core и маршрутизирует задачи в правильные reference-файлы
- `README.md` синхронизирован с новым покрытием текущего core и дополнен `mobileapp.md` и `b24connector.md`

## [1.10.0] — 2026-04-15

### Added
- `bitrix/references/bitrixcloud.md` — отдельный core-first справочник по модулю `bitrixcloud`

### Changed
- `bitrix/references/security.md` расширен до реально установленного модуля `security`: WAF, redirect/IP rules, session hardening, OTP/MFA, recovery codes, antivirus, site checker и xscan
- `bitrix/SKILL.md` теперь явно считает `security` и `bitrixcloud` активными модулями текущего core и маршрутизирует задачи в правильные reference-файлы
- `README.md` синхронизирован с новым покрытием текущего core и дополнен `bitrixcloud.md`

## [1.9.0] — 2026-04-15

### Added
- `bitrix/references/photogallery.md` — отдельный core-first справочник по модулю `photogallery`

### Changed
- `bitrix/SKILL.md` расширен на подтверждённый активный модуль `photogallery` и теперь ведёт gallery/upload/comment-задачи в отдельный маршрут
- `README.md` синхронизирован с новым покрытием текущего core и дополнен новым reference-файлом

## [1.8.0] — 2026-04-15

### Added
- `bitrix/references/highloadblock.md` — отдельный core-first справочник по модулю `highloadblock`
- `bitrix/references/clouds.md` — отдельный core-first справочник по модулю `clouds`

### Changed
- `bitrix/SKILL.md` расширен на подтверждённый активный модуль `clouds`, получил отдельные маршруты для `highloadblock` и `clouds`, а также новые core-first эвристики для HL и внешнего файлового хранения
- `bitrix/references/iblock-hl-relations.md` явно разведён с новым `highloadblock.md`
- `bitrix/references/import-export.md` явно разведён с новым `clouds.md`, чтобы задачи по `HANDLER_ID` и cloud-storage не ехали в общий `CFile`-маршрут
- `README.md` синхронизирован с новым покрытием текущего core и дополнен новыми reference-файлами

## [1.7.0] — 2026-04-15

### Added
- `bitrix/references/location.md` — отдельный core-first справочник по модулю `location`
- `bitrix/references/messageservice.md` — отдельный core-first справочник по модулю `messageservice`
- `bitrix/references/fileman.md` — отдельный core-first справочник по модулю `fileman`
- `bitrix/references/translate.md` — отдельный core-first справочник по модулю `translate`

### Changed
- `bitrix/SKILL.md` расширен на подтверждённые активные модули `fileman`, `location`, `messageservice`, `translate` и теперь маршрутизирует задачи в новые reference-файлы
- `bitrix/references/mail-notifications.md` явно разведён с `messageservice`, чтобы SMS-задачи шли в правильный модульный слой
- `README.md` синхронизирован с новым покрытием текущего core и дополнен новыми reference-файлами

## [1.6.0] — 2026-04-10

### Added
- `bitrix/versions.sh` и `bitrix/versions.ps1` — просмотр доступных release-версий навыка
- `bitrix/uninstall.sh` и `bitrix/uninstall.ps1` — удаление установленной копии навыка для `Claude` и `Codex`
- поддержка установки и обновления конкретной версии через `--version` и `-Version`

### Changed
- `install.sh` и `install.ps1` теперь в первую очередь ставят навык из release/tag-архива, а не из branch tarball
- `bitrix/update.sh` и `bitrix/update.ps1` теперь умеют обновлять и откатывать навык на конкретную release-версию
- `README.md` дополнен полноценным lifecycle: установка, обновление, просмотр версий, удаление и пути с учётом `$CODEX_HOME`

## [1.5.1] — 2026-04-10

### Changed
- `README.md` переведён на новый bootstrap URL репозитория `bitrix-agent-skill`
- changelog compare/release links переведены на новый GitHub slug
- репозиторий после rename зафиксирован как основной, при этом legacy fallback в install/update-скриптах сохранён для мягкой миграции старых установок

## [1.5.0] — 2026-04-10

### Added
- dual-target install/update flow для `Claude Code` и `Codex`
- автоматическое определение текущего и legacy slug репозитория: сначала `bitrix-agent-skill`, затем `claude-bitrix-skill`
- флаги таргетинга installer-ов: `--claude/--codex/--both` и `-Claude/-Codex/-Both`

### Changed
- `README.md` переведён из Claude-only документации в общий формат `Bitrix Agent Skill` для двух агентов
- `bitrix/SKILL.md` обновлён под совместимость с `Claude Code` и `Codex`
- `install.sh`, `install.ps1`, `bitrix/update.sh`, `bitrix/update.ps1` отвязаны от жёсткой привязки к старому slug и готовы к rename репозитория
- PowerShell installer больше не зависит от шаблона архива `claude-bitrix-skill-*`
- `PLAN.md` синхронизирован с текущей версией и rename-safe install/update слоем

## [1.4.1] — 2026-04-10

### Added
- `bitrix/references/forum.md` — отдельный core-first справочник по модулю `forum`
- `bitrix/references/vote.md` — отдельный core-first справочник по модулю `vote`
- `bitrix/references/landing.md` — отдельный core-first справочник по модулю `landing`
- `bitrix/references/socialservices.md` — отдельный core-first справочник по модулю `socialservices`
- `bitrix/references/perfmon.md` — отдельный core-first справочник по модулю `perfmon`

### Changed
- `bitrix/SKILL.md` расширен на подтверждённые модули `forum`, `vote`, `landing`, `socialservices`, `perfmon`
- `bitrix/references/search.md` дополнен подтверждённым fast-search маршрутом через `CSearchTitle` и `bitrix:search.suggest.input`
- `bitrix/references/seo-cache-access.md` дополнен подтверждённым путём для `OpenGraph` и `JSON-LD` через `$APPLICATION->AddHeadString(...)`
- `README.md` синхронизирован с новым покрытием текущего core без partial-зон в блоговом и стандартном контуре

## [1.4.0] — 2026-04-10

### Added
- `install.ps1` — нативная установка навыка на Windows через PowerShell
- `bitrix/update.ps1` — нативное обновление и `-Check` для Windows через PowerShell
- `bitrix/allow-update.ps1` — helper для глобального разрешения автообновления на Windows

### Changed
- `README.md` переписан под три платформы: macOS, Linux и Windows
- `bitrix/allow-update.sh` теперь добавляет разрешения и для bash-, и для PowerShell-апдейтера
- `SKILL.md` учитывает Windows/PowerShell при проверке новой версии навыка

## [1.3.11] — 2026-04-08

### Added
- `bitrix/allow-update.sh` — helper-скрипт, который одной командой добавляет глобальное разрешение на запуск `update.sh` в `~/.claude/settings.json`

### Changed
- `README.md` больше не предлагает руками редактировать проектный `.claude/settings.local.json` для автообновления навыка
- Инструкция по постоянному разрешению на `update.sh` упрощена до одной команды и переведена на глобальный `~/.claude/settings.json`

## [1.3.10] — 2026-04-08

### Added
- GitHub Actions workflow, который на push в `master` автоматически публикует tag и GitHub Release для текущей версии из `bitrix/VERSION`, если их ещё нет

### Changed
- `README.md` дополнен описанием fully-automatic release flow без ручного создания тега и release в GitHub UI
- В README добавлен шаг с постоянным разрешением на запуск `update.sh`, чтобы агент мог держать навык свежим без повторных запросов

## [1.3.9] — 2026-04-08

### Changed
- Выпущен повторный тестовый релиз для проверки предложения обновить навык при появлении новой версии

## [1.3.8] — 2026-04-08

### Changed
- Выпущен тестовый релиз для проверки сценария с предложением обновить навык при появлении новой версии

## [1.3.7] — 2026-04-08

### Added
- `bitrix/update.sh --check` — явная проверка новой версии без немедленного обновления
- Правило в `SKILL.md`: при первом `/bitrix` сначала проверить версию навыка и при наличии новой версии предложить обновление в явной форме

### Changed
- `README.md` дополнен сценарием проверки новой версии без апдейта

## [1.3.6] — 2026-04-08

### Changed
- Завершена полная core-first ревизия всех `bitrix/references/*.md` по реально установленному ядру
- `README.md` и `PLAN.md` синхронизированы с текущим состоянием скилла и его deferred-доменов
- Маршруты `catalog`, `sale`, `commerce-workflows`, `bizproc`, `pull` и `socialnet` зафиксированы как условные до появления соответствующих модулей в core

### Fixed
- Убраны неподтверждённые API и устаревшие формулировки в reference-файлах по `blog`, `search`, `seo`, `session`, `access`, `subscribe`, `grid`, `file uploader`, `validation`, `templates`, `import/export`, `stepper`, `numerator` и связанным подсистемам
- Исправлены описания покрытия в `README.md`, чтобы они соответствовали реальным контрактам текущего ядра

## [1.1.0] — 2026-03-19

### Added
- `bitrix/VERSION` — файл версии, единый источник истины
- `install.sh` — идемпотентный скрипт установки и обновления (bash + curl)
- `bitrix/update.sh` — встроенный обновлятор: один вызов для обновления навыка
- `CHANGELOG.md` — этот файл
- 35 reference-файлов по всем подсистемам Bitrix

### Changed
- Версия в `SKILL.md` frontmatter обновлена до `"1.1"`
- `README.md` — добавлена секция "Обновление", упрощена установка

## [1.0.0] — 2026-02-XX

### Added
- Первый публичный релиз: `SKILL.md`, progressive disclosure архитектура

[Unreleased]: https://github.com/Poliklot/bitrix-agent-skill/compare/v1.14.0...HEAD
[1.14.0]: https://github.com/Poliklot/bitrix-agent-skill/compare/v1.13.0...v1.14.0
[1.13.0]: https://github.com/Poliklot/bitrix-agent-skill/compare/v1.12.0...v1.13.0
[1.12.0]: https://github.com/Poliklot/bitrix-agent-skill/compare/v1.11.0...v1.12.0
[1.11.0]: https://github.com/Poliklot/bitrix-agent-skill/compare/v1.10.0...v1.11.0
[1.10.0]: https://github.com/Poliklot/bitrix-agent-skill/compare/v1.9.0...v1.10.0
[1.9.0]: https://github.com/Poliklot/bitrix-agent-skill/compare/v1.8.0...v1.9.0
[1.8.0]: https://github.com/Poliklot/bitrix-agent-skill/compare/v1.7.0...v1.8.0
[1.7.0]: https://github.com/Poliklot/bitrix-agent-skill/compare/v1.6.0...v1.7.0
[1.6.0]: https://github.com/Poliklot/bitrix-agent-skill/compare/v1.5.1...v1.6.0
[1.5.1]: https://github.com/Poliklot/bitrix-agent-skill/compare/v1.5.0...v1.5.1
[1.5.0]: https://github.com/Poliklot/bitrix-agent-skill/compare/v1.4.1...v1.5.0
[1.4.1]: https://github.com/Poliklot/bitrix-agent-skill/compare/v1.4.0...v1.4.1
[1.4.0]: https://github.com/Poliklot/bitrix-agent-skill/compare/v1.3.11...v1.4.0
[1.3.11]: https://github.com/Poliklot/bitrix-agent-skill/compare/v1.3.10...v1.3.11
[1.3.10]: https://github.com/Poliklot/bitrix-agent-skill/compare/v1.3.9...v1.3.10
[1.3.9]: https://github.com/Poliklot/bitrix-agent-skill/compare/v1.3.8...v1.3.9
[1.3.8]: https://github.com/Poliklot/bitrix-agent-skill/compare/v1.3.7...v1.3.8
[1.3.7]: https://github.com/Poliklot/bitrix-agent-skill/compare/v1.3.6...v1.3.7
[1.3.6]: https://github.com/Poliklot/bitrix-agent-skill/compare/v1.1.0...v1.3.6
[1.1.0]: https://github.com/Poliklot/bitrix-agent-skill/releases/tag/v1.1.0
[1.0.0]: https://github.com/Poliklot/bitrix-agent-skill/releases/tag/v1.0.0
