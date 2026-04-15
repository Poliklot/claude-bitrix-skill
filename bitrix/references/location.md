# Геолокации, адреса и форматы (модуль location)

> Audit note: ниже сверено с текущим `www/bitrix/modules/location` версии `25.100.0`. Подтверждены константы `LOCATION_SEARCH_SCOPE_ALL`, `LOCATION_SEARCH_SCOPE_INTERNAL`, `LOCATION_SEARCH_SCOPE_EXTERNAL`, сервисы `\Bitrix\Location\Service\LocationService`, `AddressService`, `FormatService`, controller-слой `\Bitrix\Location\Controller\Location`, `Address`, `Format`, `RecentAddress`, `Source`, `StaticMap`, а также ORM-таблицы `LocationTable`, `LocationNameTable`, `HierarchyTable`, `AddressTable`, `AddressLinkTable`, `AreaTable`, `LocationFieldTable`, `SourceTable`, `RecentAddressTable`.

## Для чего использовать

`location` в этом core — это не “просто справочник местоположений”, а отдельный D7-контур для:

- поиска и автокомплита адресов
- работы с внутренними и внешними location source
- сохранения адресов как сущностей
- форматов адресов
- связки адресов с другими сущностями

У модуля нет своего стандартного component-layer, поэтому основной путь здесь почти всегда:

1. `install/version.php`
2. `lib/service/*`
3. `lib/controller/*`
4. `lib/model/*`

---

## Поисковые scope

Подтверждены константы из `include.php`:

- `LOCATION_SEARCH_SCOPE_ALL`
- `LOCATION_SEARCH_SCOPE_INTERNAL`
- `LOCATION_SEARCH_SCOPE_EXTERNAL`

Практическое правило:

- если задача про локальную базу адресов Bitrix, сначала смотри `INTERNAL`
- если задача про внешнюю геокодировку/подсказки, чаще нужен `EXTERNAL`
- если поведение “странно смешивается”, проверь, какой scope реально уходит в сервис или controller

---

## LocationService

Подтверждены методы:

- `findById`
- `findByExternalId`
- `findByCoords`
- `autocomplete`
- `findParents`
- `save`
- `delete`

```php
use Bitrix\Location\Service\LocationService;
use Bitrix\Main\Loader;

Loader::includeModule('location');

$location = LocationService::getInstance()->findById(
    123,
    LANGUAGE_ID,
    LOCATION_SEARCH_SCOPE_ALL
);

$suggestions = LocationService::getInstance()->autocomplete([
    'query' => 'Москва',
    'limit' => 10,
], LOCATION_SEARCH_SCOPE_EXTERNAL);
```

Если задача звучит как:

- “найти location по внешнему коду”
- “дать autocomplete адреса”
- “получить родителей location”

то первым делом открывай именно `LocationService`, а не ручные SQL или какие-то старые `CSaleLocation`.

---

## AddressService и форматы

Подтверждены:

- `AddressService::findById`
- `AddressService::findByLinkedEntity`
- `AddressService::save`
- `AddressService::delete`
- `FormatService::findByCode`
- `FormatService::findAll`
- `FormatService::findDefault`

```php
use Bitrix\Location\Service\AddressService;
use Bitrix\Main\Loader;

Loader::includeModule('location');

$addressCollection = AddressService::getInstance()->findByLinkedEntity(
    '42',
    'CRM_COMPANY'
);
```

Это ключевой путь, когда нужно:

- хранить адрес как отдельную сущность
- привязать адреса к своему entity type
- вывести адрес в нужном формате

---

## Controller-слой

Подтверждены `Main\Engine\Controller`:

- `\Bitrix\Location\Controller\Location`
- `\Bitrix\Location\Controller\Address`
- `\Bitrix\Location\Controller\Format`

У `Location` подтверждены action-методы:

- `findByIdAction`
- `autocompleteAction`
- `findParentsAction`
- `findByExternalIdAction`
- `findByCoordsAction`
- `saveAction`
- `deleteAction`

У `Address` подтверждены:

- `findById`
- `saveAction`
- `deleteAction`

У `Format` подтверждены:

- `findByCodeAction`
- `findAllAction`
- `findDefaultAction`

Это хороший маршрут для AJAX-задач и внутреннего UI, когда не хочется вручную собирать endpoint поверх service-слоя.

---

## ORM-таблицы

Подтверждены DataManager-таблицы:

- `\Bitrix\Location\Model\LocationTable`
- `\Bitrix\Location\Model\LocationNameTable`
- `\Bitrix\Location\Model\HierarchyTable`
- `\Bitrix\Location\Model\AddressTable`
- `\Bitrix\Location\Model\AddressLinkTable`
- `\Bitrix\Location\Model\AreaTable`
- `\Bitrix\Location\Model\LocationFieldTable`
- `\Bitrix\Location\Model\SourceTable`
- `\Bitrix\Location\Model\RecentAddressTable`

```php
use Bitrix\Location\Model\LocationTable;
use Bitrix\Main\Loader;

Loader::includeModule('location');

$rows = LocationTable::getList([
    'select' => ['ID', 'CODE', 'EXTERNAL_ID', 'SOURCE_CODE', 'TYPE'],
    'filter' => ['=CODE' => 'moskva'],
    'limit' => 10,
]);
```

Если задача касается миграций, массовой загрузки или аналитических выборок, ORM-слой обычно удобнее controller-методов.

---

## Что важно помнить

- У `location` нет привычного слоя стандартных компонентов, поэтому не ищи решение по шаблонам компонента там, где его нет.
- `EXTERNAL_ID`, `SOURCE_CODE`, `CODE` и внутренний `ID` — это не одно и то же. Ошибки интеграции часто начинаются с их смешения.
- Для адресных UX-задач `location` очень часто идёт в связке с `fileman`-полем `address`, так что при проблемах формы смотри оба модуля.
- Если пользователь говорит “локация не находится”, сначала проверь scope поиска и источник данных, а уже потом кеш и фронт.
