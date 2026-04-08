# Changelog

Формат: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), версионирование: [Semantic Versioning](https://semver.org/).

## [Unreleased]

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

[Unreleased]: https://github.com/Poliklot/claude-bitrix-skill/compare/v1.3.11...HEAD
[1.3.11]: https://github.com/Poliklot/claude-bitrix-skill/compare/v1.3.10...v1.3.11
[1.3.10]: https://github.com/Poliklot/claude-bitrix-skill/compare/v1.3.9...v1.3.10
[1.3.9]: https://github.com/Poliklot/claude-bitrix-skill/compare/v1.3.8...v1.3.9
[1.3.8]: https://github.com/Poliklot/claude-bitrix-skill/compare/v1.3.7...v1.3.8
[1.3.7]: https://github.com/Poliklot/claude-bitrix-skill/compare/v1.3.6...v1.3.7
[1.3.6]: https://github.com/Poliklot/claude-bitrix-skill/compare/v1.1.0...v1.3.6
[1.1.0]: https://github.com/Poliklot/claude-bitrix-skill/releases/tag/v1.1.0
[1.0.0]: https://github.com/Poliklot/claude-bitrix-skill/releases/tag/v1.0.0
