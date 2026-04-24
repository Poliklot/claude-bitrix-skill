# PHP Legacy Modernization в Bitrix — справочник

> Reference для Bitrix-скилла. Загружай для задач “почистить legacy”, “вынести логику”, “перевести на D7”, “сделать безопаснее без переписывания проекта”.

## Содержание
- Принцип
- Разделение boundary и логики
- Safe sequence
- Где можно modern PHP
- Где осторожно
- Common mistakes

## Принцип

Цель modernization — не “переписать на красивый PHP”, а уменьшить риск следующей правки.

В Bitrix сначала сохраняй runtime-контракт:

- module availability через `Loader`;
- права и текущий пользователь;
- кеши и индексы;
- side effects legacy API;
- component/template contract.

## Разделение boundary и логики

Boundary:

- `component.php`, `class.php`;
- `result_modifier.php`;
- `template.php`;
- event handler;
- controller action;
- agent/CLI/admin/public entrypoint.

Modernization target:

- service class;
- helper/normalizer;
- adapter к внешнему API;
- validator;
- DTO/value object для локального слоя.

## Safe sequence

1. Зафиксируй текущий runtime path.
2. Найди бизнес-логику внутри boundary.
3. Вынеси минимальный чистый кусок в service/helper.
4. Оставь boundary тонким: получить вход, вызвать service, перевести результат в Bitrix contract.
5. Добавь проверку: test, smoke или `php -l` + ручной сценарий.
6. Только потом улучшай типы/DTO/PHPDoc.

## Где можно modern PHP

Обычно можно:

- новые файлы в `local/modules/<vendor>.<module>/lib`;
- project services;
- integration adapters;
- validators;
- CLI helpers;
- pure mappers/normalizers.

Там допустимы `strict_types`, typed properties, constructor promotion, readonly DTO, `final`, exceptions внутри domain layer.

## Где осторожно

Проверяй отдельно:

- `template.php`;
- `result_modifier.php`;
- старые admin/public entrypoints;
- обработчики с global state;
- файлы, которые активно используют mixed-массивы и coercion;
- legacy module write paths.

## D7 vs legacy

Правило:

- Для чтения D7 ORM часто уместен.
- Для записи смотри конкретный core: например blog D7 tables могут быть read-oriented, а мутации должны идти через `CBlog*`.
- Если legacy API запускает обработчики, индексацию, права или кеш, не обходи его ради “чистого” DataManager.

## Common mistakes

- Переписать старый файл целиком и потерять скрытые side effects.
- Добавить DTO everywhere, но оставить бизнес-логику в шаблоне.
- Перевести write path на D7 без проверки core.
- Заменить понятный legacy код абстракциями, которых нет в проекте.
- Внедрить новый framework-style слой, не совпадающий с Bitrix architecture.

## С чем читать вместе

- PHP workflow — [php-workflow.md](php-workflow.md)
- PHP quality — [php-quality.md](php-quality.md)
- PHP testing — [php-testing.md](php-testing.md)
- Components — [component-dataflow-debugging.md](component-dataflow-debugging.md)
- ORM — [orm.md](orm.md)
