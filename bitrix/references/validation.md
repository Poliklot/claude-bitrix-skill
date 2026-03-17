# Bitrix Validation Framework — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с валидацией данных через `Bitrix\Main\Validation\ValidationService`, PHP 8 Attributes (`#[Required]`, `#[Email]`, `#[Length]` и др.), или с валидаторами из пространства имён `Bitrix\Main\Validation\Rule\`.

## Содержание
- Архитектура ValidationService
- PHP 8 Attributes для валидации
- Все встроенные валидаторы (таблица)
- Примеры: простой DTO, вложенные объекты
- ValidationResult и ValidationError
- Классовые атрибуты (AtLeastOnePropertyNotEmpty)
- Gotchas

---

## Архитектура

`ValidationService` использует PHP 8 Reflection + Attributes для валидации DTO-объектов.

**Ключевые классы:**
- `ValidationService` — точка входа, метод `validate(object $object): ValidationResult`
- `ValidationResult` — результат, содержит список `ValidationError`
- `ValidationError` — ошибка с кодом (именем свойства) и сообщением

**Требования:** PHP 8.0+, использует `ReflectionClass` и `ReflectionProperty`.

---

## Базовый пример

```php
use Bitrix\Main\Validation\ValidationService;
use Bitrix\Main\Validation\Rule\NotEmpty;
use Bitrix\Main\Validation\Rule\Email;
use Bitrix\Main\Validation\Rule\Length;
use Bitrix\Main\Validation\Rule\Min;
use Bitrix\Main\Validation\Rule\Max;

class CreateUserRequest
{
    #[NotEmpty]
    public string $name = '';

    #[NotEmpty]
    #[Email]
    public string $email = '';

    #[NotEmpty]
    #[Length(min: 8, max: 64)]
    public string $password = '';

    #[Min(0)]
    #[Max(150)]
    public int $age = 0;
}

// Использование:
$request = new CreateUserRequest();
$request->name  = '';
$request->email = 'not-an-email';
$request->password = '123';
$request->age  = 200;

$service = new ValidationService();
$result  = $service->validate($request);

if (!$result->isSuccess()) {
    foreach ($result->getErrors() as $error) {
        echo $error->getCode() . ': ' . $error->getMessage() . PHP_EOL;
        // name: Поле не должно быть пустым
        // email: Введите корректный email
        // password: Длина должна быть от 8 до 64 символов
        // age: Значение не должно превышать 150
    }
}
```

---

## Все встроенные Rule-атрибуты (namespace Bitrix\Main\Validation\Rule)

| Атрибут | Параметры | Описание |
|---------|-----------|----------|
| `#[NotEmpty]` | — | Значение не пустое (не `null`, не `''`, не `[]`) |
| `#[Email]` | — | Валидный email |
| `#[Phone]` | — | Валидный телефон |
| `#[PhoneOrEmail]` | — | Телефон или email |
| `#[Url]` | — | Валидный URL |
| `#[Length(min?, max?)]` | `min: int`, `max: int` | Длина строки |
| `#[Min(value)]` | `value: int\|float` | Минимальное числовое значение |
| `#[Max(value)]` | `value: int\|float` | Максимальное числовое значение |
| `#[InArray(values)]` | `values: array` | Значение входит в список |
| `#[RegExp(pattern)]` | `pattern: string` | Соответствие регулярному выражению |
| `#[PositiveNumber]` | — | Положительное число (> 0) |
| `#[Range(min, max)]` | `min`, `max` | Числовое значение в диапазоне |
| `#[Enum(class)]` | `class: string` | Значение является валидным enum-кейсом |

### Классовые атрибуты

| Атрибут | Описание |
|---------|----------|
| `#[AtLeastOnePropertyNotEmpty(['prop1', 'prop2'])]` | Хотя бы одно из указанных свойств должно быть заполнено |

---

## Классовый атрибут: AtLeastOnePropertyNotEmpty

```php
use Bitrix\Main\Validation\Rule\AtLeastOnePropertyNotEmpty;

#[AtLeastOnePropertyNotEmpty(['phone', 'email'])]
class ContactRequest
{
    public string $phone = '';
    public string $email = '';
    public string $name  = 'Иван';
}

$request = new ContactRequest(); // и phone и email пусты
$result  = (new ValidationService())->validate($request);
// Вернёт ошибку: хотя бы одно из полей должно быть заполнено
```

---

## Вложенные объекты (Recursive)

```php
use Bitrix\Main\Validation\Rule\Recursive\Validatable;
use Bitrix\Main\Validation\Rule\NotEmpty;

class AddressRequest
{
    #[NotEmpty]
    public string $city = '';

    #[NotEmpty]
    public string $street = '';
}

class OrderRequest
{
    #[NotEmpty]
    public string $title = '';

    #[Validatable] // рекурсивная валидация вложенного объекта
    public AddressRequest $address;

    public function __construct()
    {
        $this->address = new AddressRequest();
    }
}

$order = new OrderRequest();
$order->title = 'Заказ 1';
// $order->address->city и $order->address->street пусты

$result = (new ValidationService())->validate($order);
// Ошибки: address.city, address.street
```

---

## ValidationResult и ValidationError

```php
use Bitrix\Main\Validation\ValidationResult;
use Bitrix\Main\Validation\ValidationError;

// ValidationResult
$result = (new ValidationService())->validate($dto);

$result->isSuccess();   // bool
$result->getErrors();   // ValidationError[]
$result->addError(new ValidationError('Сообщение', 'field_name'));

// ValidationError
$error = $result->getErrors()[0];
$error->getMessage();   // строка с текстом ошибки
$error->getCode();      // имя свойства (путь: 'address.city' для вложенных)
$error->hasCode();      // bool
```

---

## Интеграция с Controller (Engine)

```php
namespace MyVendor\MyModule\Controller;

use Bitrix\Main\Engine\Controller;
use Bitrix\Main\Error;
use Bitrix\Main\Validation\ValidationService;
use MyVendor\MyModule\Request\CreateItemRequest;

class Item extends Controller
{
    public function createAction(array $fields): ?array
    {
        $request = new CreateItemRequest();
        $request->title  = (string)($fields['title'] ?? '');
        $request->sortOrder = (int)($fields['sort'] ?? 100);

        $validationService = new ValidationService();
        $validationResult  = $validationService->validate($request);

        if (!$validationResult->isSuccess()) {
            foreach ($validationResult->getErrors() as $error) {
                $this->addError(new Error($error->getMessage(), $error->getCode()));
            }
            return null;
        }

        // ...создание записи...
        return ['id' => 42];
    }
}
```

---

## Собственный валидатор (атрибут)

```php
use Attribute;
use Bitrix\Main\Validation\Rule\AbstractPropertyValidationAttribute;
use Bitrix\Main\Validation\ValidationResult;
use Bitrix\Main\Validation\ValidationError;

#[Attribute(Attribute::TARGET_PROPERTY)]
class InnValidator extends AbstractPropertyValidationAttribute
{
    public function validateProperty(mixed $value): ValidationResult
    {
        $result = new ValidationResult();

        $inn = (string)$value;
        if (!preg_match('/^\d{10}(\d{2})?$/', $inn)) {
            $result->addError(new ValidationError('Некорректный ИНН', ''));
        }

        return $result;
    }
}

// Использование:
class CompanyRequest
{
    #[NotEmpty]
    #[InnValidator]
    public string $inn = '';
}
```

---

## Gotchas

- **PHP 8.0+**: `ValidationService` использует PHP 8 Attributes. На PHP 7.x не работает.
- **Свойство должно быть инициализировано**: если свойство объявлено без значения и не задано — `ValidationService` добавит ошибку `MAIN_VALIDATION_EMPTY_PROPERTY`. Используй дефолтные значения или nullable типы.
- **Коды ошибок для вложенных**: для `#[Validatable]` код ошибки формируется как `имяСвойства.кодВнутреннейОшибки` (например `address.city`).
- **`#[NotEmpty]` vs `required` в ORM**: это разные вещи. ORM-валидация в `getMap()` работает при `add()`/`update()`, Validation\Rule — только при явном вызове `ValidationService::validate()`.
- **Собственный атрибут**: реализуй `AbstractPropertyValidationAttribute` для свойств или `AbstractClassValidationAttribute` для классов.
- **Нет автовызова**: `ValidationService::validate()` нужно вызывать явно. Он не интегрирован автоматически в Engine\Controller.
