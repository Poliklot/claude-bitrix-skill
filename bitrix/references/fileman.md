# Fileman, HTML Editor, карты и media UI (модуль fileman)

> Audit note: ниже сверено с текущим `www/bitrix/modules/fileman` версии `25.0.0`. Подтверждены D7-части `\Bitrix\Fileman\Controller\HtmlEditorAjax`, `\Bitrix\Fileman\UserField\Address`, `Geo`, `UserField\Types\AddressType`, legacy-слой `properties.php` с типами `map_google`, `map_yandex`, `video`, а также стандартные компоненты `bitrix:fileman.field.address`, `bitrix:fileman.light_editor`, `bitrix:map.google.*`, `bitrix:map.yandex.*`, `bitrix:pdf.viewer`, `bitrix:player`, `bitrix:mobile.player`.

## Для чего использовать

`fileman` в этом core — это не только “редактор файлов в админке”. Практически модуль нужен для:

- HTML editor и связанного AJAX/controller слоя
- пользовательских полей `address` и `geo`
- map/property user types для инфоблоков
- viewer/player-компонентов
- map UI через Google/Yandex компоненты

Если задача касается:

- редактора контента
- карты в инфоблоке
- адресного userfield
- PDF/video/media viewer

то проверяй именно `fileman`.

---

## Address и Geo user fields

Подтверждены:

- `\Bitrix\Fileman\UserField\Address`
- `\Bitrix\Fileman\UserField\Geo`
- `\Bitrix\Fileman\UserField\Types\AddressType`
- компонент `bitrix:fileman.field.address`

Для `AddressType` подтверждены:

- `USER_TYPE_ID = 'address'`
- `RENDER_COMPONENT = 'bitrix:fileman.field.address'`
- `getApiKey`
- `prepareSettings`
- `onBeforeSave`
- `renderEditForm`
- `renderView`
- `renderText`

```php
use Bitrix\Fileman\UserField\Address;
use Bitrix\Main\Loader;

Loader::includeModule('fileman');
Loader::includeModule('location');

$description = Address::getUserTypeDescription();
```

Что важно:

- `address`-поле из `fileman` жёстко связано с модулем `location`
- `Geo` в текущем core помечен как `@deprecated`
- если задача про адресный userfield, почти всегда смотри сразу `fileman` + `location`

---

## Google/Yandex map property types

В `properties.php` подтверждены legacy user type property:

- `CIBlockPropertyMapGoogle`
- `CIBlockPropertyMapYandex`
- `CIBlockPropertyVideo`

Их регистрация подтверждена в `install/index.php` через зависимости:

- `OnIBlockPropertyBuildList`
- `OnUserTypeBuildList` для video user type

Это означает:

- карта в инфоблоке здесь обычно legacy-property, а не современный D7 userfield
- если “карта в свойстве не рендерится”, открывай `fileman/properties.php`, а не только шаблон компонента инфоблока

---

## Стандартные компоненты

Подтверждены:

- `bitrix:fileman.field.address`
- `bitrix:fileman.light_editor`
- `bitrix:map.google.system`
- `bitrix:map.google.search`
- `bitrix:map.google.view`
- `bitrix:map.yandex.system`
- `bitrix:map.yandex.search`
- `bitrix:map.yandex.view`
- `bitrix:pdf.viewer`
- `bitrix:player`
- `bitrix:mobile.player`

Пример обычного map-route:

```php
$APPLICATION->IncludeComponent(
    'bitrix:map.google.view',
    '',
    [
        'INIT_MAP_TYPE' => 'ROADMAP',
        'MAP_DATA' => serialize([
            'google_lat' => 55.751244,
            'google_lon' => 37.618423,
            'google_scale' => 12,
            'PLACEMARKS' => [],
        ]),
        'MAP_WIDTH' => '100%',
        'MAP_HEIGHT' => '400',
    ]
);
```

Если задача про viewer/player, сначала смотри контракт готового компонента, а не пиши свой JS-виджет с нуля.

---

## HTML editor и AJAX

Подтверждён controller:

- `\Bitrix\Fileman\Controller\HtmlEditorAjax::getVideoOembedAction`

Это штатный путь для задач, где редактору нужно получить oEmbed по video source.

Также модуль содержит большой legacy-слой в:

- `classes/general/html_editor.php`
- `classes/general/light_editor.php`
- `classes/general/medialib.php`
- `classes/general/fileman_utils.php`

Практическое правило:

- если задача про сам редактор, смотри legacy `classes/general/*`
- если задача про AJAX endpoint редактора, смотри D7 controller в `lib/controller/*`

---

## Что важно помнить

- `fileman` — смешанный модуль: часть задач идёт через D7, часть по-прежнему сидит на старом legacy-слое.
- Для `address`-поля отдельно проверь ключи карты и настройки `fileman`/`bitrix24`, потому что `AddressType::getApiKey()` берёт их из module options.
- `Geo` user field в текущем core deprecated, поэтому не расширяй его без крайней необходимости.
- Карты в инфоблоках и адресные userfield-ы — это разные контуры внутри одного модуля; не смешивай `properties.php` и `UserField\Types\AddressType`.
