# PHP Quality в Bitrix-проекте — справочник

> Reference для Bitrix-скилла. Загружай, когда задача касается `phpstan`, `psalm`, fixer/sniffer, `rector`, CI, lint, code style или quality gates.

## Содержание
- Сначала найди project tooling
- Что запускать
- Как внедрять аккуратно
- Bitrix-specific quality rules
- Common mistakes

## Сначала найди project tooling

```bash
rg --files . \
  -g '!vendor/**' \
  -g '!www/bitrix/modules/*/vendor/**' \
  -g 'composer.json' \
  -g 'phpstan.neon' -g 'phpstan.neon.dist' \
  -g 'psalm.xml' -g 'psalm.xml.dist' \
  -g '.php-cs-fixer.php' -g '.php-cs-fixer.dist.php' \
  -g 'ecs.php' \
  -g 'phpcs.xml' -g 'phpcs.xml.dist' \
  -g 'rector.php' \
  -g 'phpunit.xml' -g 'phpunit.xml.dist'
```

Если tooling найден только внутри `www/bitrix/modules/*/vendor`, это не project tooling.

## Что запускать

| Найдено | Действие |
|---|---|
| `composer.json` | проверить `scripts`, autoload, dev tools |
| `phpstan.neon*` | запускать project-native phpstan на затронутом scope |
| `psalm.xml*` | запускать psalm только с текущей конфигурацией |
| fixer/sniffer | форматировать только затронутые файлы |
| `rector.php` | применять точечно и читать diff |
| ничего нет | `php -l` + manual import/namespace/runtime check |

## Как внедрять аккуратно

Внедрение нового quality tool — отдельная задача, а не побочный эффект маленькой правки.

Минимальный путь для проекта без tooling:

1. `php -l` изменённых файлов;
2. PHPDoc/array-shape для mixed-массивов;
3. small service extraction из boundary;
4. smoke-check реального маршрута;
5. отдельное предложение по tooling только если домен повторяющийся и критичный.

## Bitrix-specific quality rules

- Не требуй идеальной типизации в legacy entrypoints.
- Не включай `declare(strict_types=1)` в шаблон/старый admin/public файл без проверки.
- Не переписывай `C*` API на D7, если конкретный модуль сохраняет side effects только в legacy write path.
- Для `$arParams`, `$arResult`, `fetch()` rows лучше добавить локальный контракт, чем устраивать масштабный DTO rewrite.
- Для module/service layer можно использовать современный PHP осторожнее: typed properties, DTO, value objects, `final`, adapters.

## Common mistakes

- Поднять уровень phpstan/psalm сразу на весь legacy-проект.
- Прогнать fixer по огромному файлу и смешать форматирование с логической правкой.
- Применить rector к `bitrix/templates` и получить поведенческий diff.
- Считать warnings от vendor/core своим project debt.
- Добавить tools в composer без согласованного CI/runtime плана.

## С чем читать вместе

- PHP workflow — [php-workflow.md](php-workflow.md)
- PHP testing — [php-testing.md](php-testing.md)
- Legacy modernization — [php-legacy-modernization.md](php-legacy-modernization.md)
- Modules — [modules-loader.md](modules-loader.md)
