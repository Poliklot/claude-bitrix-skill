# Changelog

Формат: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), версионирование: [Semantic Versioning](https://semver.org/).

## [Unreleased]

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

[Unreleased]: https://github.com/Poliklot/bitrix-agent-skill/compare/v1.6.0...HEAD
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
