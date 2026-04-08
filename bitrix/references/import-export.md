# Импорт / экспорт и работа с файлами

## CFile — работа с файлами Bitrix

По умолчанию Bitrix хранит метаданные файлов в `b_file`, а физические файлы — в `upload/`. Но в текущем core есть события `OnFileSave` и `OnMakeFileArray`, поэтому внешнее хранилище тоже возможно. `CFile` остаётся корректной точкой входа для сохранения, получения и изменения файлов.

---

### CFile::SaveFile — сохранить файл в БД

```php
// $arFile — массив в формате $_FILES (или аналогичный)
$arFile = [
    'name'     => 'photo.jpg',      // оригинальное имя
    'tmp_name' => '/tmp/phpXXX',    // физический путь к временному файлу
    'type'     => 'image/jpeg',     // MIME-тип
    'size'     => 204800,           // размер в байтах
    'error'    => 0,
];

$fileId = CFile::SaveFile($arFile, 'my_module');   // обычно int ID, но при delete-only сценарии может вернуть строку "NULL"
if (!$fileId) {
    // ошибка сохранения
}
```

`$strSavePath` — поддиректория внутри `upload/`. Выбирай по смыслу: `'iblock'`, `'my.module'`, `'user'`.

#### Сохранить загруженный файл из $_FILES

```php
use Bitrix\Main\Application;

$request = Application::getInstance()->getContext()->getRequest();

// Получить через D7 (рекомендуется)
$uploadedFile = $request->getFile('image');  // эквивалент $_FILES['image']

if ($uploadedFile && $uploadedFile['error'] === UPLOAD_ERR_OK) {
    // Проверить тип — белый список
    $allowed = ['image/jpeg', 'image/png', 'image/webp'];
    if (!in_array($uploadedFile['type'], $allowed, true)) {
        throw new \RuntimeException('Недопустимый тип файла');
    }

    $fileId = CFile::SaveFile($uploadedFile, 'my_module');
}
```

> **Gotcha:** `$request->getFile('name')` возвращает тот же массив что и `$_FILES['name']`, но через D7-обёртку. Используй его вместо `$_FILES` напрямую.

---

### CFile::MakeFileArray — получить массив-дескриптор файла

Принимает ID, путь или URL. Возвращает массив в формате `$_FILES` или `false/null`.

```php
// По ID из b_file (например, из поля инфоблока)
$arFile = CFile::MakeFileArray(123);

// По локальному пути (относительно DOCUMENT_ROOT или абсолютный)
$arFile = CFile::MakeFileArray('/local/import/photo.jpg');

// По URL — скачивает через HttpClient во временный файл
$arFile = CFile::MakeFileArray('https://example.com/image.jpg');

if ($arFile) {
    $newFileId = CFile::SaveFile($arFile, 'my_module');
}
```

**Возвращаемый массив:**
```php
[
    'name'        => 'photo.jpg',      // оригинальное имя
    'tmp_name'    => '/path/to/file',  // физический путь
    'type'        => 'image/jpeg',
    'size'        => 204800,
    'description' => '',
]
```

> Для `http/https` ядро создаёт `HttpClient`, вызывает `setPrivateIp(false)` и блокирует приватные IP. Для `php://` и `phar://` действует отдельный запрет, кроме `php://input`.

---

### CFile::GetFileArray — получить данные файла из БД

```php
$arFile = CFile::GetFileArray($fileId);
// [
//   'ID'           => 123,
//   'FILE_NAME'    => 'abc123.jpg',
//   'ORIGINAL_NAME'=> 'photo.jpg',
//   'SUBDIR'       => 'iblock/abc',
//   'SRC'          => '/upload/iblock/abc/abc123.jpg',
//   'CONTENT_TYPE' => 'image/jpeg',
//   'FILE_SIZE'    => 204800,
//   'HEIGHT'       => 800,
//   'WIDTH'        => 600,
// ]
```

---

### CFile::ResizeImageGet — получить превью

Возвращает массив с данными уже отресайзенного изображения (берёт из кеша или создаёт):

```php
$arSize = ['width' => 300, 'height' => 200];

// BX_RESIZE_IMAGE_PROPORTIONAL — вписать пропорционально (по умолчанию)
// BX_RESIZE_IMAGE_EXACT         — точный crop
// BX_RESIZE_IMAGE_PROPORTIONAL_ALT — пропорционально по большей стороне

$arResized = CFile::ResizeImageGet(
    $fileId,                           // int или массив от GetFileArray
    $arSize,
    BX_RESIZE_IMAGE_PROPORTIONAL
);

if ($arResized) {
    // $arResized['src']    — '/upload/resize_cache/.../photo.jpg'
    // $arResized['width']  — реальная ширина
    // $arResized['height'] — реальная высота
    echo '<img src="' . htmlspecialchars($arResized['src']) . '"
               width="' . $arResized['width'] . '"
               height="' . $arResized['height'] . '">';
}
```

### CFile::ResizeImage — изменить размер перед сохранением

Модифицирует `$arFile['tmp_name']` на месте (временный файл):

```php
$arFile = CFile::MakeFileArray('/local/import/big.jpg');
if ($arFile) {
    $resized = CFile::ResizeImage($arFile, ['width' => 800, 'height' => 600], BX_RESIZE_IMAGE_PROPORTIONAL);
    if ($resized) {
        $fileId = CFile::SaveFile($arFile, 'my_module');
    }
}
```

### CFile::Delete — удалить файл

```php
CFile::Delete($fileId);  // удаляет из b_file и физически с диска
```

---

## Импорт из CSV

### Простой одношаговый импорт

```php
use Bitrix\Main\Application;
use Bitrix\Main\Loader;

Loader::includeModule('iblock');

$filePath = $_SERVER['DOCUMENT_ROOT'] . '/local/import/products.csv';

if (!file_exists($filePath)) {
    throw new \RuntimeException('Файл не найден');
}

$handle = fopen($filePath, 'r');
$header = fgetcsv($handle, 0, ';');  // первая строка — заголовки
// $header = ['NAME', 'PRICE', 'ARTICLE', 'SECTION_CODE']

// Белый список допустимых столбцов
$allowed = array_flip(['NAME', 'PRICE', 'ARTICLE', 'SECTION_CODE']);
$header = array_map(
    fn($col) => isset($allowed[$col]) ? $col : null,
    $header
);

while (($row = fgetcsv($handle, 0, ';')) !== false) {
    $data = array_combine($header, $row);
    $data = array_filter($data, fn($v, $k) => $k !== null, ARRAY_FILTER_USE_BOTH);

    $el = new \CIBlockElement();
    $result = $el->Add([
        'IBLOCK_ID'  => CATALOG_IBLOCK_ID,
        'NAME'       => trim($data['NAME']),
        'ACTIVE'     => 'Y',
        'PROPERTY_VALUES' => [
            'ARTICLE' => trim($data['ARTICLE'] ?? ''),
            'PRICE'   => (float)str_replace(',', '.', $data['PRICE'] ?? '0'),
        ],
    ]);

    if (!$result) {
        error_log('Ошибка импорта: ' . $el->LAST_ERROR . ' | строка: ' . implode(';', $row));
    }
}

fclose($handle);
```

---

### Многошаговый импорт (через сессию)

Для больших файлов — обрабатывать пачками по N строк, хранить позицию в сессии:

```php
// Шаг 1: загрузка файла (разовый POST)
// Шаг 2-N: обработка пачек (повторяющиеся AJAX-запросы)
// Шаг финал: очистка сессии

use Bitrix\Main\Application;

$request = Application::getInstance()->getContext()->getRequest();
$session = Application::getInstance()->getSession();

$BATCH_SIZE = 50;

// --- Загрузка файла (шаг 1) ---
if ($request->isPost() && $request->getPost('action') === 'upload') {
    $uploadedFile = $request->getFile('csv_file');

    if (!$uploadedFile || $uploadedFile['error'] !== UPLOAD_ERR_OK) {
        echo json_encode(['error' => 'Ошибка загрузки файла']);
        die();
    }

    // Сохранить во временную директорию (не в b_file — нужен физический путь)
    $tmpPath = sys_get_temp_dir() . '/import_' . md5(uniqid('', true)) . '.csv';
    move_uploaded_file($uploadedFile['tmp_name'], $tmpPath);

    // Подсчитать строк (для прогресса)
    $totalLines = max(0, (int)shell_exec('wc -l < ' . escapeshellarg($tmpPath)) - 1); // -1 заголовок

    $session->set('import_file',   $tmpPath);
    $session->set('import_offset', 0);
    $session->set('import_total',  $totalLines);

    echo json_encode(['total' => $totalLines, 'processed' => 0]);
    die();
}

// --- Обработка пачки (шаги 2-N) ---
if ($request->isPost() && $request->getPost('action') === 'process') {
    $tmpPath = $session->get('import_file');
    $offset  = (int)$session->get('import_offset');
    $total   = (int)$session->get('import_total');

    if (!$tmpPath || !file_exists($tmpPath)) {
        echo json_encode(['error' => 'Сессия импорта не найдена']);
        die();
    }

    $handle = fopen($tmpPath, 'r');
    $header = fgetcsv($handle, 0, ';');

    // Перемотать к нужной строке
    for ($i = 0; $i < $offset; $i++) {
        fgetcsv($handle, 0, ';');
    }

    $processed = 0;
    $errors    = [];

    for ($i = 0; $i < $BATCH_SIZE; $i++) {
        $row = fgetcsv($handle, 0, ';');
        if ($row === false) {
            break;
        }

        $data = array_combine($header, $row);

        // ... сохранить элемент (аналогично одношаговому) ...
        $processed++;
    }

    fclose($handle);

    $newOffset = $offset + $processed;
    $session->set('import_offset', $newOffset);

    $done = $newOffset >= $total;

    if ($done) {
        unlink($tmpPath);
        $session->remove('import_file');
        $session->remove('import_offset');
        $session->remove('import_total');
    }

    echo json_encode([
        'processed' => $newOffset,
        'total'     => $total,
        'done'      => $done,
        'errors'    => $errors,
    ]);
    die();
}
```

#### JS-клиент для многошагового импорта

```javascript
async function runImport(file) {
    // Шаг 1: загрузить файл
    const form = new FormData();
    form.append('sessid', BX.bitrix_sessid());
    form.append('action', 'upload');
    form.append('csv_file', file);

    let resp = await fetch('/local/import/handler.php', { method: 'POST', body: form });
    let data = await resp.json();

    // Шаги 2-N: пакетная обработка
    while (!data.done) {
        const body = new URLSearchParams({
            sessid: BX.bitrix_sessid(),
            action: 'process',
        });
        resp = await fetch('/local/import/handler.php', { method: 'POST', body });
        data = await resp.json();

        const progress = Math.round(data.processed / data.total * 100);
        document.getElementById('progress').textContent = progress + '%';
    }

    alert('Импорт завершён. Обработано: ' + data.processed);
}
```

---

## Импорт изображений из URL

Типичная задача при импорте товаров: загрузить картинку по URL и прикрепить к элементу.

```php
use Bitrix\Main\Loader;
Loader::includeModule('iblock');

foreach ($products as $product) {
    $picFileId = false;

    if (!empty($product['IMAGE_URL'])) {
        // MakeFileArray скачивает URL через HttpClient
        $arFile = CFile::MakeFileArray($product['IMAGE_URL']);
        if ($arFile) {
            // Опциональный ресайз перед сохранением
            CFile::ResizeImage($arFile, ['width' => 800, 'height' => 800], BX_RESIZE_IMAGE_PROPORTIONAL);

            $picFileId = CFile::SaveFile($arFile, 'iblock');
        }
    }

    $el = new \CIBlockElement();
    $el->Add([
        'IBLOCK_ID'        => CATALOG_IBLOCK_ID,
        'NAME'             => $product['NAME'],
        'PREVIEW_PICTURE'  => $picFileId ?: false,
        'DETAIL_PICTURE'   => $picFileId ?: false,
        'ACTIVE'           => 'Y',
    ]);
}
```

---

## Экспорт в CSV (потоковый)

Потоковый экспорт не накапливает данные в памяти — сразу пишет в вывод:

```php
use Bitrix\Main\Loader;
use Bitrix\Main\Application;

Loader::includeModule('iblock');

// Отключить буферизацию вывода
while (ob_get_level()) {
    ob_end_clean();
}

$response = Application::getInstance()->getContext()->getResponse();
$response->addHeader('Content-Type', 'text/csv; charset=utf-8');
$response->addHeader('Content-Disposition', 'attachment; filename="export_' . date('Y-m-d') . '.csv"');
$response->flush('');  // отправить заголовки

// BOM для корректного открытия в Excel
echo "\xEF\xBB\xBF";

$out = fopen('php://output', 'w');
fputcsv($out, ['ID', 'Название', 'Артикул', 'Цена'], ';');

$res = \CIBlockElement::GetList(
    ['ID' => 'ASC'],
    ['IBLOCK_ID' => CATALOG_IBLOCK_ID, 'ACTIVE' => 'Y'],
    false,
    false,
    ['ID', 'NAME', 'PROPERTY_ARTICLE', 'PROPERTY_PRICE']
);

while ($el = $res->GetNext()) {
    fputcsv($out, [
        $el['ID'],
        $el['NAME'],
        $el['PROPERTY_ARTICLE_VALUE'] ?? '',
        $el['PROPERTY_PRICE_VALUE'] ?? '',
    ], ';');

    if (connection_aborted()) {
        break;
    }
}

fclose($out);
die();
```

---

## Gotchas

- `CFile::SaveFile` сохраняет файл физически в `upload/`, возвращает `false` при ошибке — всегда проверяй
- `CFile::MakeFileArray` при передаче URL скачивает файл во временную директорию — при ошибке сети возвращает `null`
- `CFile::ResizeImage` изменяет `$arFile['tmp_name']` на месте — оригинал теряется. Если нужен оригинал, скопируй сначала
- `BX_RESIZE_IMAGE_EXACT` = точный crop по центру; `BX_RESIZE_IMAGE_PROPORTIONAL` = вписать в рамку (поля пустые)
- В CSV-экспорте добавляй UTF-8 BOM `\xEF\xBB\xBF` — Excel иначе не откроет кириллицу корректно
- При многошаговом импорте храни файл вне `upload/` (в `sys_get_temp_dir()`), иначе он попадёт в БД
- `fgetcsv` зависит от локали — если возникают проблемы с кодировкой, используй `mb_convert_encoding`
- `connection_aborted()` в цикле экспорта позволяет корректно завершить если пользователь закрыл браузер
