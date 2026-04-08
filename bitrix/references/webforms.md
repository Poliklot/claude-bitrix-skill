# Веб-формы и обратная связь

> Reference для Bitrix-скилла. Загружай когда задача связана с модулем `form`, результатами веб-форм или простыми формами обратной связи на инфоблоке.
>
> Audit note: проверено по текущему core `form/classes/general/*`, `form/classes/mysql/*`.

```php
use Bitrix\Main\Loader;

Loader::includeModule('form');
```

## Два подхода к формам в Bitrix

| Подход | Когда использовать |
|--------|--------------------|
| **Модуль `form`** (`CForm`, `CFormResult`) | Нужны вопросы, статусы, права, повторные отправки, админский интерфейс результатов |
| **Простая форма на инфоблоке** | Нужен лёгкий сбор заявок без сложного form-workflow |

---

## Модуль `form`

### Получить список форм

```php
$res = CForm::GetList(
    $by = 's_sort',
    $order = 'asc',
    $arFilter = ['ACTIVE' => 'Y']
);

while ($form = $res->Fetch())
{
    // $form['ID'], $form['NAME'], $form['SID']
}
```

### Получить структуру формы по ID

```php
$arForm = $arQuestions = $arAnswers = $arDropDown = $arMultiSelect = [];

$formId = CForm::GetDataByID(
    $WEB_FORM_ID,
    $arForm,
    $arQuestions,
    $arAnswers,
    $arDropDown,
    $arMultiSelect,
    'N', // additional
    'N'  // active
);
```

Это основной способ получить:

- данные формы
- список вопросов
- варианты ответов
- dropdown/multiselect карты

### Сохранить результат формы

```php
global $strError;

$arrValues = $_POST;

$resultId = CFormResult::Add(
    $WEB_FORM_ID,
    $arrValues,
    'Y',   // проверять права
    false  // USER_ID; false = текущий пользователь
);

if ((int)$resultId <= 0)
{
    $error = $strError;
}
else
{
    CFormResult::Mail($resultId);
}
```

> В текущем core подтверждён метод `CFormResult::Mail($RESULT_ID, $TEMPLATE_ID = false)`. `SendMail()` не подтверждён.

### Получить список результатов формы

```php
$isFiltered = null;

$res = CFormResult::GetList(
    $formId,
    $by = 's_timestamp',
    $order = 'desc',
    $arFilter = [
        'STATUS_ID' => 1,
    ],
    $isFiltered,
    'Y',
    false
);

while ($row = $res->Fetch())
{
    $arrRES = [];
    $arrANSWER = [];

    $values = CFormResult::GetDataByID(
        $row['ID'],
        [],        // список SID полей; [] = все
        $arrRES,
        $arrANSWER
    );

    // $arrRES    — данные результата
    // $arrANSWER — ответы по SID
    // $values    — агрегированный массив значений
}
```

> `CFormResult::GetListEx(...)` в текущем core не подтверждён. Используй `CFormResult::GetList(...)`.

### Получить один результат

```php
$resultDb = CFormResult::GetByID($resultId);
$result = $resultDb->Fetch();
```

Если нужно сразу получить и значения вопросов, используй `CFormResult::GetDataByID(...)`.

---

## Простая форма на инфоблоке

Если форма небольшая и нет смысла тянуть модуль `form`, часто проще писать в инфоблок.

```php
use Bitrix\Main\Application;
use Bitrix\Main\Loader;

Loader::includeModule('iblock');

$request = Application::getInstance()->getContext()->getRequest();

if ($request->isPost() && check_bitrix_sessid())
{
    $name = htmlspecialchars($request->getPost('name') ?? '', ENT_QUOTES, 'UTF-8');
    $email = trim((string)($request->getPost('email') ?? ''));
    $message = htmlspecialchars($request->getPost('message') ?? '', ENT_QUOTES, 'UTF-8');

    if ($name === '' || !filter_var($email, FILTER_VALIDATE_EMAIL))
    {
        $error = 'Заполните обязательные поля';
    }
    else
    {
        $el = new CIBlockElement();
        $elementId = $el->Add([
            'IBLOCK_ID' => FEEDBACK_IBLOCK_ID,
            'NAME' => $name . ' ' . date('d.m.Y H:i'),
            'ACTIVE' => 'Y',
            'PROPERTY_VALUES' => [
                'NAME' => $name,
                'EMAIL' => $email,
                'MESSAGE' => $message,
                'IP' => $request->getServer()->get('REMOTE_ADDR'),
            ],
        ]);

        if ($elementId)
        {
            \Bitrix\Main\Mail\Event::send([
                'EVENT_NAME' => 'FEEDBACK_NEW',
                'LID' => SITE_ID,
                'FIELDS' => [
                    'NAME' => $name,
                    'EMAIL' => $email,
                    'MESSAGE' => $message,
                ],
            ]);

            $success = true;
        }
        else
        {
            $error = $el->LAST_ERROR;
        }
    }
}
```

### HTML-форма с CSRF-защитой

```html
<form method="POST" action="">
    <?php echo bitrix_sessid_post(); ?>
    <input type="text" name="name" required>
    <input type="email" name="email" required>
    <textarea name="message"></textarea>
    <button type="submit">Отправить</button>
</form>
```

---

## AJAX-форма через D7 Controller

```php
namespace MyVendor\MyModule\Controller;

use Bitrix\Main\Engine\Controller;
use Bitrix\Main\Engine\ActionFilter;
use Bitrix\Main\Error;
use Bitrix\Main\Loader;

class Feedback extends Controller
{
    public function configureActions(): array
    {
        return [
            'send' => [
                'prefilters' => [
                    new ActionFilter\HttpMethod(['POST']),
                    new ActionFilter\Csrf(),
                ],
            ],
        ];
    }

    public function sendAction(string $name, string $email, string $message): ?array
    {
        if ($name === '')
        {
            $this->addError(new Error('Имя обязательно', 'EMPTY_NAME'));
            return null;
        }

        if (!filter_var($email, FILTER_VALIDATE_EMAIL))
        {
            $this->addError(new Error('Неверный email', 'BAD_EMAIL'));
            return null;
        }

        Loader::includeModule('iblock');

        $el = new \CIBlockElement();
        $id = $el->Add([
            'IBLOCK_ID' => FEEDBACK_IBLOCK_ID,
            'NAME' => $name,
            'PROPERTY_VALUES' => [
                'EMAIL' => $email,
                'MESSAGE' => $message,
            ],
        ]);

        if (!$id)
        {
            $this->addError(new Error($el->LAST_ERROR));
            return null;
        }

        \Bitrix\Main\Mail\Event::send([
            'EVENT_NAME' => 'FEEDBACK_NEW',
            'LID' => SITE_ID,
            'FIELDS' => compact('name', 'email', 'message'),
        ]);

        return ['id' => $id];
    }
}
```

JS:

```javascript
BX.ajax.runAction('myvendor.mymodule.feedback.send', {
    data: {
        sessid: BX.bitrix_sessid(),
        name: document.getElementById('name').value,
        email: document.getElementById('email').value,
        message: document.getElementById('message').value,
    }
}).then(function(response) {
    console.log('ID:', response.data.id);
}).catch(function(response) {
    console.error(response.errors);
});
```

---

## Gotchas

- `CFormResult::GetDataByID()` в текущем core принимает не один `$resultId`, а `($RESULT_ID, $arrFIELD_SID, &$arrRES, &$arrANSWER)`.
- `CFormResult::Mail()` подтверждён; `CFormResult::SendMail()` и `GetListEx()` в текущем core не подтверждены.
- `$strError` у `CFormResult::Add()` legacy-глобальный. Если читаешь ошибку, не забудь `global $strError`.
- `check_bitrix_sessid()` обязателен для обычных POST-форм, даже если форма “простая”.
- Для AJAX controller сценариев используй `ActionFilter\Csrf`, а не только ручной `sessid`.
- Если задача не требует статусов, прав и сложной админки формы, инфоблок часто проще и дешевле по сопровождению.
