# Фото-галереи, альбомы, upload и комментарии (модуль photogallery)

> Audit note: ниже сверено с текущим `www/bitrix/modules/photogallery` версии `25.0.0`. Подтверждены инсталлятор модуля, legacy-классы `CPhotogalleryElement`, `CPGalleryInterface`, upload-контур `CPhotoUploader`, а также стандартные компоненты `bitrix:photogallery`, `bitrix:photogallery.user`, `bitrix:photogallery.section`, `bitrix:photogallery.detail`, `bitrix:photogallery.detail.list`, `bitrix:photogallery.detail.list.ex`, `bitrix:photogallery.upload`, `bitrix:photogallery.detail.comment`.

## Для чего использовать

`photogallery` в этом core - отдельный legacy-контур, который нельзя честно сводить к “обычному инфоблоку с картинками”.

Модуль нужен для задач вида:

- пользовательские или общие галереи;
- альбомы как разделы внутри галереи;
- загрузка фотографий с watermark/converters;
- пароль на альбом;
- slideshow, detail list, upload, gallery user routes;
- связка фото с комментариями blog/forum;
- пересчёт веса галереи и служебных UF.

Если задача звучит как:

- “почему фотогалерея не открывается по USER_ALIAS”
- “куда делся оригинал фото”
- “почему пароль на альбом не срабатывает”
- “почему размер галереи не пересчитался”
- “как работает upload в photogallery”

то маршрутом должен быть именно `photogallery`, а не общие `iblock/components`.

## Архитектура модуля

По текущему ядру картина такая:

- модуль почти целиком legacy;
- `lib/` как рабочий API-контур здесь практически пустой;
- основной контракт живёт в `install/components`, `classes/general` и `tools/components_lib.php`;
- логика держится на связке `iblock + section UF + element properties + component routes`.

Практический вывод:

- сначала смотри стандартный photogallery-компонент и `tools/components_lib.php`;
- не пытайся проектировать это как современную D7-сущность, если задача реально идёт через штатный UI.

## Модель данных

В текущем core фактически используются три уровня:

- корневой раздел инфоблока = галерея;
- вложенный раздел = альбом;
- элемент инфоблока = фото.

Подтверждённые служебные поля и свойства:

- `UF_DATE` - дата альбома/галереи;
- `UF_PASSWORD` - пароль альбома;
- `UF_GALLERY_SIZE` - накопленный размер файлов галереи;
- `UF_GALLERY_RECALC` - служебное состояние пересчёта;
- `REAL_PICTURE` - property с оригиналом файла;
- `PROPERTY_BLOG_POST_ID`, `PROPERTY_FORUM_TOPIC_ID` - связка фото с комментариями.

Важно:

- модуль реально завязан на section-UF, а не только на полях раздела/элемента;
- без `REAL_PICTURE` и gallery-UF часть штатной логики работает неполно;
- `gallery.edit` и `section.edit` умеют создавать недостающие UF, но runtime-логика уже предполагает их наличие.

## Инсталлятор и события

Инсталлятор модуля регистрирует зависимости:

- `iblock:OnBeforeIBlockElementDelete` -> `CPhotogalleryElement::OnBeforeIBlockElementDelete`
- `iblock:OnAfterIBlockElementAdd` -> `CPhotogalleryElement::OnAfterIBlockElementAdd`
- `search:BeforeIndex` -> `CRatingsComponentsPhotogallery::BeforeIndex`
- `im:OnGetNotifySchema` -> `CPhotogalleryNotifySchema::OnGetNotifySchema`
- `socialnetwork:OnSocNetGroupDelete` -> `\Bitrix\Photogallery\Integration\Socialnetwork\Group::onSocNetGroupDelete`

Что это значит practically:

- добавление и удаление фото меняет `UF_GALLERY_SIZE`;
- photogallery встроен в search/indexing;
- есть IM notify schema;
- socialnetwork-интеграция в ядре предусмотрена, но в текущем проекте её надо считать deferred, пока модуль `socialnetwork` не подтверждён.

## `CPhotogalleryElement`

Подтверждён legacy-класс `CPhotogalleryElement` в `classes/general/element.php`.

Ключевые методы:

- `CheckElement($ID, &$arElement, &$arSection, &$arGallery)`
- `OnBeforeIBlockElementDelete($ID)`
- `OnRecalcGalleries($ID, $INDEX)`
- `OnAfterRecalcGalleries($IBLOCK_ID, $INDEX)`
- `OnAfterIBlockElementAdd($res)`

Подтверждённое поведение:

- `CheckElement(...)` ищет элемент, его `REAL_PICTURE`, раздел, родительскую галерею и проверяет наличие `UF_GALLERY_SIZE`;
- `OnAfterIBlockElementAdd(...)` увеличивает `UF_GALLERY_SIZE` у галереи на размер файла;
- `OnBeforeIBlockElementDelete(...)` уменьшает `UF_GALLERY_SIZE`;
- пересчёт галереи ведётся через `UF_GALLERY_RECALC`.

Практически это значит:

- если размер галереи “поехал”, ищи не только шаблон, но и lifecycle фото-элемента;
- удаление/добавление фото влияет на section-UF, а не только на элемент.

## `CPGalleryInterface`

Подтверждён основной helper `CPGalleryInterface` в `tools/components_lib.php`.

Ключевые методы:

- `GetGallery($galleryId)`
- `GetSection($id, &$arSection, $params = [])`
- `GetSectionGallery($arSection = [])`
- `GetPermission()`
- `CheckPermission($permission = "D", $arSection = [], $bOutput = true)`
- `GetUserAlias(...)`
- `GetPathWithUserAlias(...)`
- `HandleUserAliases(...)`

Что важно:

- `GetGallery(...)` ищет галерею как корневой раздел по `CODE`;
- `GetSection(...)` возвращает не просто раздел, а готовит `PATH`, `DATE`, `PASSWORD`, `USER_FIELDS`, counts и картинки;
- при несовпадении section и gallery может вернуться `301`, а не просто ошибка;
- `GetPermission()` берёт базовое право через `CIBlock::GetPermission($iblockId)`, но для владельца своей галереи может повысить его до `W`;
- `CheckPermission(...)` умеет парольные альбомы через `UF_PASSWORD` и сессию `$_SESSION['PHOTOGALLERY']['SECTION']`.

### Парольные альбомы

Подтверждено:

- пароль хранится в `UF_PASSWORD`;
- в `section.edit` он кладётся как `md5($_REQUEST["PASSWORD"])`;
- при доступе `CheckPermission(...)` показывает HTML-форму и проверяет пароль через `check_bitrix_sessid()`.

Практическое правило:

- не считай `UF_PASSWORD` plain-text полем;
- если альбом не открывается, проверяй именно hash в UF и сессионный state.

## Стандартные компоненты

Подтверждены компоненты:

- `bitrix:photogallery`
- `bitrix:photogallery.user`
- `bitrix:photogallery.gallery.list`
- `bitrix:photogallery.gallery.edit`
- `bitrix:photogallery.section`
- `bitrix:photogallery.section.list`
- `bitrix:photogallery.section.edit`
- `bitrix:photogallery.section.edit.icon`
- `bitrix:photogallery.detail`
- `bitrix:photogallery.detail.edit`
- `bitrix:photogallery.detail.list`
- `bitrix:photogallery.detail.list.ex`
- `bitrix:photogallery.detail.comment`
- `bitrix:photogallery.upload`
- `bitrix:photogallery.imagerotator`
- `bitrix:photogallery.interface`

### `bitrix:photogallery`

Это комплексный компонент.

Подтверждены SEF-маршруты:

- `section`
- `section_edit`
- `section_edit_icon`
- `index`
- `search`
- `detail`
- `detail_edit`
- `detail_list`
- `detail_slide_show`
- `upload`

Что важно:

- при `SEF_MODE="Y"` компонент реально парсит путь и выставляет `404`, если route не распознан;
- для `ACTION=upload` страница принудительно переводится в `upload`;
- сортировка разделов по умолчанию идёт по `UF_DATE`;
- `USER_ALIAS` и `SECTION_ID/ELEMENT_ID` - базовые переменные маршрута.

### `bitrix:photogallery.section`

Компонент:

- создаёт `CPGalleryInterface`;
- грузит section через `GetSection(...)`;
- может отдавать `301` на каноничный путь;
- строит back/upload/edit/drop ссылки;
- учитывает лимит галереи через `UF_GALLERY_SIZE`.

### `bitrix:photogallery.user`

Компонент:

- работает с `USER_ALIAS`;
- кеширует список галерей пользователя;
- использует root sections инфоблока как галереи пользователя;
- sanitizes alias через regexp `[^a-z0-9_]`.

Практическое правило:

- если alias содержит другие символы, штатный route уже сам их вырежет;
- для диагностики URL-проблем смотри не только rewrite, но и sanitizing внутри компонента.

### `bitrix:photogallery.detail.comment`

Подтверждено:

- `COMMENTS_TYPE` может быть `forum` или `blog`;
- при `COMMENTS_TYPE="blog"` обязателен `BLOG_URL`;
- компонент требует установленный соответствующий модуль;
- photo comment route очищает cache фотогалереи при добавлении комментариев.

Это значит:

- комментарии photo не “встроены сами по себе”;
- для blog/forum сценариев надо параллельно смотреть соответствующий модуль.

## Upload-контур и `CPhotoUploader`

Подтверждён upload helper `CPhotoUploader` в `photogallery.upload/functions.php`.

Ключевые возможности:

- watermark rules из параметров и пользовательского POST;
- поиск шрифта и watermark-файла в файловой системе;
- создание нового альбома при загрузке;
- очистка кешей после upload;
- настройка инфоблока под upload-сценарий.

Особенно важно:

- `adjustIBlock(...)` умеет автоматически создавать file-properties для converters;
- там же создаются moderation properties `PUBLIC_ELEMENT` и `APPROVE_ELEMENT`, если их нет;
- `createAlbum(...)` создаёт новый section и пишет `UF_DATE`.

### Файлы фото

По upload-компоненту подтверждено стандартное разложение:

- `REAL_PICTURE` = оригинал;
- `PREVIEW_PICTURE` = thumbnail/preview;
- `DETAIL_PICTURE` и converter-файлы могут создаваться по настройкам upload-а.

Не путай:

- `REAL_PICTURE` - это не обязательно то же самое, что `DETAIL_PICTURE`;
- часть шаблонов и slideshow берёт размеры и `SRC` именно из `REAL_PICTURE`.

## Интеграция с blog/search/im

Из install step и компонентов подтверждено:

- модуль умеет создавать blog group/blog на установке, если `blog` установлен;
- comment-компонент умеет работать через `blog` или `forum`;
- есть search hook `BeforeIndex`;
- есть notify schema для `im`.

Практический вывод:

- для комментариев и активности photo почти всегда смотри соседний модуль `blog` или `forum`;
- socialnetwork-ветку не активируй в решении, пока сам модуль не подтверждён в текущем core.

## Gotchas

- `photogallery` в этом ядре - legacy и component-first. Не выдумывай для него D7-API, которого тут нет.
- Корневой раздел и вложенный альбом - не одно и то же: права, route и counters завязаны на иерархию разделов.
- `UF_PASSWORD` хранится как hash, а не как открытая строка.
- `UF_GALLERY_SIZE` и `UF_GALLERY_RECALC` - рабочие служебные поля, а не “опциональные метки”.
- `USER_ALIAS` в user-сценариях нормализуется до `[a-z0-9_]`.
- Для photo comments и social-связок обязательно проверяй наличие `blog`/`forum`/`socialnetwork`, а не предполагай их по памяти.
