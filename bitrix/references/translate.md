# Локализация, языковые файлы и переводческий UI (модуль translate)

> Audit note: ниже сверено с текущим `www/bitrix/modules/translate` версии `25.0.0`. Подтверждены `\Bitrix\Translate\File`, `Filter`, `Settings`, `Permission`, UI-панель `\Bitrix\Translate\Ui\Panel`, CLI-команда `translate:index`, controller-слой `Index\Collector`, `Editor\File`, `Import\Csv`, `Export\Csv`, а также стандартные компоненты `bitrix:translate.list` и `bitrix:translate.edit`.

## Зачем модуль нужен в этом core

`translate` здесь нужен не только для “редактирования lang-файлов в админке”. Это отдельный рабочий контур для:

- индексации языковых файлов и фраз;
- поиска по переводам;
- импорта и экспорта переводов в CSV;
- UI-редактирования lang-файлов;
- контроля прав на просмотр, запись и редактирование исходников;
- работы с `.settings.php` внутри `lang/`-деревьев;
- построения публичной translate-панели.

Если задача звучит как:

- “почему перевод не находится в translate UI”
- “как переиндексировать lang-файлы”
- “как импортировать/выгрузить переводы CSV”
- “как править lang-файлы безопасно”

то первым маршрутом должен быть именно `translate`, а не только `Loc::getMessage()` и ручное редактирование PHP-файлов.

## Базовые классы

### `\Bitrix\Translate\File`

Это главный объект для lang-файла. Подтверждены фабрики:

- `instantiateByPath(string $path)`
- `instantiateByIndex(Index\FileIndex $fileIndex)`
- `instantiateByIoFile(Main\IO\File $fileIn)`

Подтверждены важные методы:

- `getLangId()`
- `setLangId(string $languageId)`
- `getSourceEncoding()`
- `setSourceEncoding(string $encoding)`
- `getOperatingEncoding()`
- `setOperatingEncoding(string $encoding)`
- `lint(...)`
- `load()`
- `loadTokens()`
- `save()`
- `removeEmptyParents()`
- `backup()`
- `getFileIndex()`
- `updatePhraseIndex()`
- `deletePhraseIndex()`
- `getPhraseIndexCollection()`
- `sortPhrases()`
- `getPhrases()`
- `getCodes()`
- `getEnclosure(string $phraseId)`
- `countExcess(self $ethalon)`
- `countDeficiency(self $ethalon)`

Пример:

```php
use Bitrix\Main\Loader;
use Bitrix\Translate\File;

Loader::includeModule('translate');

$file = File::instantiateByPath(
    $_SERVER['DOCUMENT_ROOT'] . '/bitrix/modules/main/lang/ru/lib/application.php'
);

if ($file->load())
{
    $value = $file['MAIN_SOME_CODE'] ?? null;
    $file['MAIN_SOME_CODE'] = 'Новое значение';

    if ($file->lint())
    {
        $file->save();
        $file->updatePhraseIndex();
    }
}
```

### `\Bitrix\Translate\Settings`

Это работа с `.settings.php` в `lang/`.

Подтверждены:

- `Settings::FILE_NAME = '.settings.php'`
- `Settings::OPTION_LANGUAGES = 'languages'`
- `instantiateByPath(string $fullPath)`
- `getOption(string $langPath, string $optionType)`
- `getOptions(string $langPath = '')`
- `load()`
- `save()`

### `\Bitrix\Translate\Filter`

Это transport/storage-объект для процессов модуля. Подтверждены параметры:

- `langId`
- `pathId`
- `nextPathId`
- `nextLangPathId`
- `fileId`
- `nextFileId`
- `path`
- `tabId`
- `recursively`

Подтверждены методы:

- `__construct($param = null)`
- `store()`
- `restore(int $id)`
- `getTabId(bool $increment = true)`

Вывод: translate-процессы реально держат прогресс и фильтры в `$_SESSION`, а не в каком-то скрытом хранилище.

## Права

Подтверждён `\Bitrix\Translate\Permission` со значениями:

- `SOURCE = 'X'`
- `WRITE = 'W'`
- `READ = 'R'`
- `DENY = 'D'`

И методами:

- `isAllowPath(string $path)`
- `canEditSource($checkUser)`
- `isAdmin($checkUser)`
- `canView($checkUser)`
- `canEdit($checkUser)`

Если пользователь “видит translate, но не может сохранить”, первым делом смотри этот класс и модульные права `translate`.

## UI и стандартные компоненты

Подтверждены стандартные компоненты:

- `bitrix:translate.list`
- `bitrix:translate.edit`

Подтверждена UI-панель:

- `\Bitrix\Translate\Ui\Panel::onPanelCreate()`
- `\Bitrix\Translate\Ui\Panel::showLoadedFiles()`

В инсталляторе модуль реально вешает:

- `main:OnPanelCreate` -> `\Bitrix\Translate\Ui\Panel::onPanelCreate`

## Controller-слой и фоновые процессы

### Индексация

Подтверждён `\Bitrix\Translate\Controller\Index\Collector` с action-константами:

- `collectLangPath`
- `collectPath`
- `collectFile`
- `collectPhrase`
- `purge`
- `cancel`

И методом:

- `cancelAction()`

### Редактор файлов

Подтверждён `\Bitrix\Translate\Controller\Editor\File` с action-ами:

- `save`
- `saveSource`
- `cleanEthalon`
- `wipeEmpty`
- `cancel`

И важный нюанс:

- `saveSource` требует не только `WRITE`, но и `SOURCE` permission;
- для `save` и `saveSource` отдельно навешан `HttpMethod(POST)`.

### CSV import/export

Подтверждён `\Bitrix\Translate\Controller\Import\Csv`:

- `uploadAction()`
- `importAction()`
- `indexAction()`
- `cancelAction($tabId)`
- `purgeAction($tabId)`
- `finalizeAction()`

Подтверждены режимы update:

- `METHOD_ADD_UPDATE`
- `METHOD_UPDATE_ONLY`
- `METHOD_ADD_ONLY`

Подтверждён `\Bitrix\Translate\Controller\Export\Csv`:

- `exportAction($tabId, $path = '')`
- `clearAction($tabId)`
- `purgeAction($tabId)`
- `cancelAction($tabId)`
- `downloadAction(int $tabId, string $type)`

И важный нюанс:

- у `downloadAction(...)` в конфигурации снимается стандартный `Csrf` prefilter;
- многие операции в import/export опираются на `tabId` и сохранённый `Filter`.

## CLI

Подтверждена команда:

- `translate:index`

Из `\Bitrix\Translate\Cli\IndexCommand`.

Поддерживается опция:

- `--path` / `-p`

По умолчанию индексируется:

- `/bitrix/modules`

Имя команды подтверждено как `translate:index`, но конкретный CLI entrypoint зависит от того, как в проекте поднята консоль `main`. Поэтому безопасный шаблон вызова такой:

```bash
php <console-entrypoint> translate:index --path=/local/modules
```

Команда проходит по:

- `PathLangCollection`
- `PathIndexCollection`
- `FileIndexCollection`
- `PhraseIndexCollection`

## События и служебный контур

В инсталляторе подтверждены:

- агент `\Bitrix\Translate\Index\Internals\PhraseFts::checkTables();`
- `perfmon:OnGetTableSchema`
- `main:OnAfterLanguageAdd`
- `main:\Bitrix\Main\Localization\Language::OnAfterAdd`
- `main:\Bitrix\Main\Localization\Language::OnAfterDelete`
- `main:OnLanguageDelete`

## Что это меняет для скилла

Если задача про локализацию, сначала различай три уровня:

1. обычный `Loc::getMessage()` и lang-файлы;
2. модуль `translate` как UI/индекс/import-export слой;
3. проектные локализационные соглашения в `local/`.

Правильный маршрут обычно такой:

- проверка lang-файла через `\Bitrix\Translate\File`;
- если нужен поиск/массовая операция — translate index;
- если нужна выгрузка/загрузка — `Import\Csv` / `Export\Csv`;
- если задача права/панель/доступ — `Permission` и `Ui\Panel`.

## Gotchas

- `translate` не равен просто `Loc::getMessage()`: UI, CSV и индекс фраз живут отдельным модулем.
- Многие процессы держат прогресс в `$_SESSION` через `Filter`, поэтому проблемы “процесс не продолжился” нужно искать не только в JS, но и в session state.
- После программного изменения lang-файла не забывай про `updatePhraseIndex()`, если задача затрагивает поиск/translate UI.
- `saveSource` и обычное `save` — не одно и то же: у них разные permission-level.
- Если панель/редактор “есть у админа, но нет у редактора”, смотри `Permission` и модульные права `translate`, а не только компонент.
