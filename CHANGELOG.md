# Changelog

Формат: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), версионирование: [Semantic Versioning](https://semver.org/).

## [Unreleased]

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

[Unreleased]: https://github.com/Poliklot/claude-bitrix-skill/compare/v1.3.6...HEAD
[1.3.6]: https://github.com/Poliklot/claude-bitrix-skill/compare/v1.1.0...v1.3.6
[1.1.0]: https://github.com/Poliklot/claude-bitrix-skill/releases/tag/v1.1.0
[1.0.0]: https://github.com/Poliklot/claude-bitrix-skill/releases/tag/v1.0.0
