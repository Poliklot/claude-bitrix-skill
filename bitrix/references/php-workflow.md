# Bitrix PHP Workflow и Project Tooling — справочник

> Reference для Bitrix-скилла. Загружай, когда задача в проекте на Bitrix упирается не только в API ядра, но и в чисто PHP-слой: сервисы, DTO, исключения, composer/tooling, тесты, static analysis, formatting и границы между legacy и D7.
>
> Этот файл специально не подменяет core-first референсы. Он накладывается поверх них и помогает не тащить в Bitrix чужие Laravel/Symfony привычки.

## Содержание
- Когда подгружать этот reference
- Быстрая диагностика PHP toolchain
- Decision table: что куда класть
- PHP workflow без конфликта с Bitrix-нормами
- Минимальные quality gates
- Common mistakes
- С чем читать вместе

## Когда подгружать этот reference

Открывай этот файл, если задача звучит так:

- "разложи PHP-код по слоям"
- "как это тестировать"
- "можно ли тут `strict_types` / DTO / exceptions"
- "как жить с composer/phpunit/phpstan в Bitrix-проекте"
- "куда вынести логику из component.php / result_modifier.php / handler-а"
- "как не испортить legacy-код, но сделать его чище"

Не открывай его как первый источник, если вопрос целиком модульный и уже закрывается конкретным core-reference: например только `iblock`, только `landing`, только `form`, только `mobileapp`.

## Быстрая диагностика PHP toolchain

Сначала пойми, чем проект уже пользуется. Не навязывай стек, которого в репозитории нет.

```bash
php -v

rg --files \
  -g 'composer.json' \
  -g 'composer.lock' \
  -g 'phpunit.xml' -g 'phpunit.xml.dist' \
  -g 'phpstan.neon' -g 'phpstan.neon.dist' \
  -g 'psalm.xml' -g 'psalm.xml.dist' \
  -g '.php-cs-fixer.php' -g '.php-cs-fixer.dist.php' \
  -g 'ecs.php' \
  -g 'phpcs.xml' -g 'phpcs.xml.dist' \
  -g 'rector.php' \
  -g 'infection.json' -g 'infection.json5'
```

Порядок чтения:

1. `composer.json` — есть ли вообще composer-autoload и scripts.
2. `phpunit.xml*` / `tests/` — есть ли реальный тестовый контур.
3. `phpstan*` / `psalm*` — есть ли статанализ и на каком уровне зрелости.
4. `.php-cs-fixer.php` / `ecs.php` / `phpcs.xml*` — чем форматируют код.
5. `rector.php` — есть ли автоматизированные кодовые миграции.

Если ничего из этого нет, не изображай, что проект обязан жить по современному PHP-tooling full stack. Для такого проекта минимальный безопасный baseline: `php -l` по изменённым файлам, аккуратные PHPDoc-контракты и сохранение текущего стиля кода.

## Decision table: что куда класть

| Задача | Предпочтительный слой | Не делай по умолчанию |
|---|---|---|
| Бизнес-правило | local-модульный сервис / project service class | `template.php`, `component.php`, handler с толстой логикой |
| Валидация входных данных | `ValidationService`, rule attributes, value checks в DTO/request object | разбрасывать валидацию по шаблону и контроллеру |
| Ошибка на domain-слое | exception внутри сервиса или `Result/Error` как контракт сервиса | смешивать raw exceptions, `LAST_ERROR` и строковые флаги без границ |
| Ответ наружу | на Bitrix boundary переводить в `Result/Error`, controller `addError`, понятный UI-state | отдавать exception trace в шаблон или AJAX-ответ |
| Сильная типизация | локальные service/DTO/value-object файлы | слепо добавлять `declare(strict_types=1)` в legacy entrypoint |
| Тестирование | pure service + существующий PHPUnit/Pest контур | пытаться тестировать `template.php` как основной unit |
| Статанализ | использовать уже настроенный phpstan/psalm | заводить новый tool только ради одной задачи |
| Форматирование | существующий fixer/sniffer проекта | тотальный reformat файлов “под себя” |

## PHP workflow без конфликта с Bitrix-нормами

### 1. Сначала отдели Bitrix boundary от чистой логики

Boundary в Bitrix-проекте обычно один из этих:

- `component.php`
- `result_modifier.php`
- `component_epilog.php`
- `init.php`, `include.php`
- AJAX/controller action
- event handler
- admin/public `*.php` entrypoint

Правило: boundary-файл координирует, а тяжёлая логика живёт рядом в сервисе.

### 2. Следуй toolchain проекта, а не своему любимому стеку

- Есть `composer.json` и autoload — используй это.
- Есть `phpunit.xml*` — добавляй тест туда, а не придумывай новый harness.
- Есть `phpstan` или `psalm` — проверяй ими изменённый участок.
- Есть fixer/sniffer — форматируй только через него.
- Ничего этого нет — не тащи новый стек как обязательное условие мелкой доработки.

### 3. Modern PHP применяй выборочно

`final`, `readonly`, typed properties, constructor promotion, маленькие DTO и value objects — это хорошо, но только там, где слой действительно локальный и изолированный:

- `local/modules/vendor.module/lib/...`
- project services
- request/response DTO
- integration adapters

Не надо механически тащить modern-PHP приёмы в:

- `bitrix/templates/.../template.php`
- `result_modifier.php`, если там полудинамический legacy массивный код
- старые admin/public entrypoints
- обработчики, где всё завязано на глобалы и mixed-данные без подготовки

### 4. `declare(strict_types=1)` не включай вслепую

Разрешённый safe-zone по умолчанию:

- новые локальные сервисы;
- DTO/value-object файлы;
- отдельные helper/adapter-классы;
- автономные CLI-скрипты проекта.

Опасная зона без дополнительной проверки:

- legacy entrypoints;
- компонентные шаблоны и модификаторы;
- admin/public php-файлы;
- файлы, где активно смешиваются глобалы, mixed-массивы и старые `C*` API.

Если surrounding code живёт без strict types и активно relies on coercion, не ломай его ради “красоты”.

### 5. Исключения внутри, `Result/Error` на границе

Практичный паттерн для Bitrix:

```php
use Bitrix\Main\Result;
use Bitrix\Main\Error;

final class ProfileService
{
    public function update(int $userId, array $payload): Result
    {
        $result = new Result();

        try {
            // domain logic, validation, repository/ORM calls
        } catch (\DomainException $e) {
            $result->addError(new Error($e->getMessage(), 'PROFILE_DOMAIN_ERROR'));
        } catch (\Throwable $e) {
            $result->addError(new Error('Unexpected profile update failure', 'PROFILE_UNEXPECTED'));
        }

        return $result;
    }
}
```

Идея не в том, чтобы запретить exceptions, а в том, чтобы на Bitrix-boundary у тебя был предсказуемый контракт.

### 6. Для legacy-массивов добавляй контракт, а не магию

Если работаешь с `$arParams`, `$arResult`, `fetch()`-массивами или `C*`-API, часто самый дешёвый и полезный шаг — добавить локальный PHPDoc:

```php
/** @var array{
 *     ITEM_ID:int,
 *     TITLE:string,
 *     CAN_EDIT:bool
 * } $arResult
 */
```

Это особенно полезно, когда проект без полноценного phpstan/psalm, но код всё равно надо сделать читаемым и менее хрупким.

### 7. Тестируй сервис, а не шаблон

Если проект уже умеет в PHPUnit/Pest, нормальная стратегия такая:

1. вынести бизнес-логику из boundary в service;
2. протестировать service как unit/integration;
3. boundary оставить тонким glue-layer.

Если тестового контура нет, не делай вид, что ты обязан сначала внедрить фреймворк тестов. Иногда для безопасной правки достаточно:

- извлечь pure method;
- прогнать `php -l`;
- сверить существующий runtime path;
- оставить код проще и контрактнее, чем был.

## Минимальные quality gates

### Если toolchain уже есть

- `composer.json` есть: смотри scripts и используй project-native команды.
- `phpunit.xml*` есть: добавляй или обновляй тесты рядом с существующими.
- `phpstan*` / `psalm*` есть: проверяй хотя бы затронутый путь.
- fixer/sniffer есть: не форматируй руками против него.

### Если toolchain нет

Минимальный sane baseline:

1. `php -l` на изменённых файлах.
2. Проверка namespace/use/import-ов.
3. Проверка, не ушла ли тяжёлая логика в шаблон.
4. Проверка, не сломан ли boundary с Bitrix API.
5. Явный контракт для mixed-данных там, где это реально помогает.

## Common mistakes

- Слепо переносить в Bitrix Laravel/Symfony-паттерны: repositories, service providers, controllers-first architecture, если проект так не устроен.
- Форсить `composer`, `phpunit`, `phpstan`, `rector` в проект, где их нет, ради маленькой доработки.
- Добавлять `declare(strict_types=1)` в legacy-файл, не проверив surrounding code.
- Лечить плохую структуру обёртками и DTO everywhere вместо того, чтобы сначала вынести реальную бизнес-логику из boundary.
- Кидать raw exception до шаблона/AJAX-ответа вместо перевода в предсказуемый Bitrix-контракт.
- Переписывать старый `C*`-маршрут “на чистый DDD” там, где задача была в одной точечной правке.

## С чем читать вместе

- Архитектура модуля, Loader, ServiceLocator — [modules-loader.md](modules-loader.md)
- Контроллеры, события, routing — [events-routing.md](events-routing.md)
- ValidationService и attributes — [validation.md](validation.md)
- ORM и `Result/Error` — [orm.md](orm.md)
- DB layer и совместимость разных СУБД — [database-layer.md](database-layer.md)
- Шаблоны и component layer — [components.md](components.md), [templates.md](templates.md)
