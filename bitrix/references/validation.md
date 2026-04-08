# Bitrix Validation Framework — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с `Bitrix\Main\Validation\ValidationService`, validation attributes из `Bitrix\Main\Validation\Rule\*`, `ValidationResult` и `ValidationError`.

## Audit note

Проверено по текущему core:
- `www/bitrix/modules/main/lib/validation/ValidationService.php`
- `www/bitrix/modules/main/lib/validation/ValidationResult.php`
- `www/bitrix/modules/main/lib/validation/ValidationError.php`
- `www/bitrix/modules/main/lib/validation/Rule/*`
- `www/bitrix/modules/main/lib/validation/Validator/*`

## Что реально есть в текущем core

Точка входа:
- `ValidationService::validate(object $object): ValidationResult`

Результаты:
- `ValidationResult` расширяет `Bitrix\Main\Result`
- `ValidationError` расширяет `Bitrix\Main\Error`

Поддерживаются:
- property-level атрибуты;
- class-level атрибуты;
- рекурсивная валидация вложенных объектов через `Recursive\Validatable`.

## Базовый пример

```php
use Bitrix\Main\Validation\ValidationService;
use Bitrix\Main\Validation\Rule\Email;
use Bitrix\Main\Validation\Rule\Length;
use Bitrix\Main\Validation\Rule\Max;
use Bitrix\Main\Validation\Rule\Min;
use Bitrix\Main\Validation\Rule\NotEmpty;

final class CreateUserRequest
{
    #[NotEmpty]
    public string $name = '';

    #[NotEmpty]
    #[Email]
    public string $email = '';

    #[Length(min: 8, max: 64)]
    public string $password = '';

    #[Min(18)]
    #[Max(150)]
    public int $age = 0;
}

$dto = new CreateUserRequest();
$dto->email = 'not-an-email';
$dto->password = '123';

$result = (new ValidationService())->validate($dto);
```

## Подтверждённые атрибуты

### Property-level

- `#[NotEmpty(allowZero: bool = false, allowSpaces: bool = false)]`
- `#[Email(strict: bool = false, domainCheck: bool = false)]`
- `#[Phone]`
- `#[PhoneOrEmail(strict: bool = false, domainCheck: bool = false)]`
- `#[Url]`
- `#[Length(min: ?int = null, max: ?int = null)]`
- `#[Min(int $min)]`
- `#[Max(int $max)]`
- `#[Range(int $min, int $max)]`
- `#[InArray(array $validValues, bool $strict = false)]`
- `#[RegExp(string $pattern, int $flags = 0, int $offset = 0)]`
- `#[PositiveNumber]`
- `#[ElementsType(?Enum\Type $typeEnum = null, ?string $className = null)]`
- `#[Recursive\Validatable]`

### Class-level

- `#[AtLeastOnePropertyNotEmpty(array $fields, bool $allowZero = false, bool $allowEmptyString = false)]`

## Важные отличия от старых описаний

В текущем core не подтверждены как встроенные атрибуты:
- `#[Required]`
- `#[Enum(...)]`

Вместо этого:
- для обязательности используется `#[NotEmpty]`;
- для проверки элементов коллекции есть `#[ElementsType(...)]`;
- enum `Bitrix\Main\Validation\Rule\Enum\Type` используется как вспомогательный тип внутри `ElementsType`.

## Рекурсивная валидация

```php
use Bitrix\Main\Validation\Rule\NotEmpty;
use Bitrix\Main\Validation\Rule\Recursive\Validatable;

final class AddressRequest
{
    #[NotEmpty]
    public string $city = '';
}

final class OrderRequest
{
    #[NotEmpty]
    public string $title = '';

    #[Validatable]
    public AddressRequest $address;

    public function __construct()
    {
        $this->address = new AddressRequest();
    }
}
```

Если вложенный объект не builtin и поле помечено `#[Validatable]`, `ValidationService` вызывает рекурсивный `validate(...)`.

## Class-level правило

```php
use Bitrix\Main\Validation\Rule\AtLeastOnePropertyNotEmpty;

#[AtLeastOnePropertyNotEmpty(['phone', 'email'])]
final class ContactRequest
{
    public string $phone = '';
    public string $email = '';
}
```

## `ValidationResult` и `ValidationError`

`ValidationResult` не добавляет свой API поверх `Result`; он наследует поведение базового результата:
- `isSuccess()`
- `getErrors()`
- `addError(...)`
- `addErrors(...)`

`ValidationError`:
- расширяет `Error`;
- умеет хранить `failedValidator`;
- поддерживает `string|int` code;
- даёт `hasCode()`.

## Неинициализированные свойства

Отдельная логика текущего `ValidationService`:
- если property не инициализировано;
- у него есть тип;
- и тип не допускает `null`,

сервис сам добавит ошибку `MAIN_VALIDATION_EMPTY_PROPERTY` с кодом имени свойства.

Это значит, что неинициализированный non-nullable property тоже считается validation-failure, даже без `#[NotEmpty]`.

## Кастомный атрибут

```php
use Attribute;
use Bitrix\Main\Validation\Rule\AbstractPropertyValidationAttribute;
use Bitrix\Main\Validation\Validator\RegExpValidator;

#[Attribute(Attribute::TARGET_PROPERTY)]
final class Inn extends AbstractPropertyValidationAttribute
{
    protected function getValidators(): array
    {
        return [
            new RegExpValidator('/^\d{10}(\d{2})?$/'),
        ];
    }
}
```

## Gotchas

- Не пиши в справке `#[Required]` и `#[Enum]` как штатные built-in атрибуты: они не подтверждены текущим core.
- `Min`, `Max` и `Range` в этом core принимают `int`, а не произвольный `int|float`.
- Для массивов и iterable используй `ElementsType`, а не выдуманный enum-validator.
- `ValidationResult` — это `Result`, а не отдельный полностью самостоятельный контейнер.
