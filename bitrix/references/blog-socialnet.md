# Bitrix Blog & Socialnet — справочник

> Reference для Bitrix-скилла. Загружай когда задача связана с блогами, комментариями, рабочими группами, живой лентой, лайками или рейтингом.
>
> Audit note: в текущем проверенном core подтверждён модуль `blog`, но модуль `socialnet` в `www/bitrix/modules` не найден. В текущей фазе используй как активный маршрут только `CBlog*`-часть этого файла. Секции `CSocNet*`, живая лента и связанные socialnet-сценарии считай условными до появления модуля.

## Содержание
- CBlogPost — создание/получение/удаление постов
- CBlogComment — комментарии
- CBlogUser — блог-пользователь
- CBlogCategory / CBlogPostCategory — теги блога
- CSocNetGroup — рабочие группы, участники, подписки
- CSocNetLogDestination — живая лента (лог активности)
- CLike — лайки
- CRatings — рейтинг
- События модуля blog
- Gotchas

---

## CBlogPost — посты блога

```php
use Bitrix\Main\Loader;

Loader::includeModule('blog');

// Добавить пост
$blogPost = new CBlogPost();
$postId = $blogPost->Add([
    'BLOG_ID'       => 5,          // ID блога
    'AUTHOR_ID'     => $userId,
    'TITLE'         => 'Заголовок поста',
    'DETAIL_TEXT'   => '<p>Текст поста</p>',
    'DATE_PUBLISH'  => date('d.m.Y H:i:s'),
    'PUBLISH_STATUS'=> 'P',        // P = published, D = draft
    'ENABLE_COMMENTS'=> 'Y',
    'ENABLE_TRACKBACK'=> 'N',
    'MICRO'         => 'N',        // Y = микропост (без заголовка)
    'CATEGORY_ID'   => '',
    'KEYWORDS'      => 'php, bitrix, d7',
    'UF_BLOG_POST_FILE' => [],     // прикреплённые файлы (UF-поля)
]);

if (!$postId) {
    global $APPLICATION;
    $exception = $APPLICATION->GetException();
    $error = $exception ? $exception->GetString() : 'Unknown error';
}

// Получить пост по ID
$post = CBlogPost::GetByID($postId);
// Поля: ID, BLOG_ID, AUTHOR_ID, TITLE, DETAIL_TEXT, DATE_PUBLISH,
//        PUBLISH_STATUS, VIEWS, NUM_COMMENTS, ENABLE_COMMENTS, ENABLE_TRACKBACK, KEYWORDS, CATEGORY_ID, ...

// Получить список постов
$postList = CBlogPost::GetList(
    ['DATE_PUBLISH' => 'DESC'],    // сортировка
    [                              // фильтр
        'BLOG_ID'        => 5,
        'PUBLISH_STATUS' => 'P',
        'ACTIVE'         => 'Y',
        '>DATE_PUBLISH'  => ConvertTimeStamp(time() - 86400 * 30, 'FULL'),
    ],
    false,                         // количество (false = без COUNT)
    ['nTopCount' => 20],           // постраничность: ['nPageSize'=>10, 'iNumPage'=>1]
    ['ID', 'TITLE', 'DATE_PUBLISH', 'AUTHOR_ID', 'VIEWS']
);
while ($post = $postList->Fetch()) {
    // обработка
}

// Обновить пост
CBlogPost::Update($postId, [
    'TITLE'  => 'Новый заголовок',
    'DETAIL_TEXT' => '<p>Обновлённый текст</p>',
]);

// Удалить пост
CBlogPost::Delete($postId);
```

---

## CBlogComment — комментарии к посту

```php
Loader::includeModule('blog');

// Добавить комментарий
$blogComment = new CBlogComment();
$commentId = $blogComment->Add([
    'POST_ID'   => $postId,
    'BLOG_ID'   => 5,
    'AUTHOR_ID' => $userId,
    'AUTHOR_EMAIL' => '', // если не авторизован
    'AUTHOR_NAME'  => '',
    'TEXT_TYPE' => 'html',     // html или text
    'POST_TEXT' => '<p>Текст комментария</p>',
    'DATE_CREATE' => date('d.m.Y H:i:s'),
    'PARENT_ID' => 0,          // ID родительского комментария (для вложенности)
]);

// Получить комментарии поста
$commRes = CBlogComment::GetList(
    ['DATE_CREATE' => 'ASC'],
    ['POST_ID' => $postId, 'BLOG_ID' => 5],
    false,
    ['nTopCount' => 50],
    ['ID', 'POST_ID', 'AUTHOR_ID', 'POST_TEXT', 'DATE_CREATE', 'PARENT_ID']
);
while ($comm = $commRes->Fetch()) { /* ... */ }

// Удалить комментарий
CBlogComment::Delete($commentId);

// Количество комментариев бери из поста
$post = CBlogPost::GetByID($postId);
$cnt = (int)($post['NUM_COMMENTS'] ?? 0);
```

---

## CBlogUser — блог-пользователь

```php
Loader::includeModule('blog');

// Получить блог-пользователя по USER_ID
$blogUser = CBlogUser::GetByID($userId, BLOG_BY_USER_ID);

// Создать блог-пользователя (если не существует)
if (!$blogUser) {
    $blogUserId = CBlogUser::Add([
        'USER_ID' => $userId,
        'ALIAS'   => 'user_' . $userId,
    ]);
} else {
    $blogUserId = (int)$blogUser['ID'];
}

// В текущем core подтверждён именно такой явный паттерн:
// GetByID(..., BLOG_BY_USER_ID) -> при отсутствии CBlogUser::Add(...)
```

---

## CBlogCategory / CBlogPostCategory — теги блога

```php
Loader::includeModule('blog');

// Получить список тегов (категорий) блога
$tagRes = CBlogCategory::GetList(
    ['NAME' => 'ASC'],
    ['BLOG_ID' => 5],
    false,
    ['nTopCount' => 30],
    ['ID', 'NAME', 'BLOG_ID']
);
while ($tag = $tagRes->Fetch()) {
    echo $tag['NAME'];
}

// Создать новый тег-категорию
$tagId = CBlogCategory::Add([
    'BLOG_ID' => 5,
    'NAME'    => 'bitrix',
]);

// Привязать тег к посту
CBlogPostCategory::Add([
    'BLOG_ID'     => 5,
    'POST_ID'     => $postId,
    'CATEGORY_ID' => $tagId,
]);

// Получить теги конкретного поста
$postTags = CBlogPostCategory::GetList(
    ['NAME' => 'ASC'],
    ['POST_ID' => $postId, 'BLOG_ID' => 5],
    false,
    false,
    ['CATEGORY_ID', 'NAME']
);
while ($tag = $postTags->Fetch()) {
    echo $tag['NAME'];
}
```

---

## CSocNetGroup — рабочие группы

```php
Loader::includeModule('socialnet');

// Создать рабочую группу
$socNetGroup = new CSocNetGroup();
$groupId = $socNetGroup->Add([
    'SITE_ID'        => SITE_ID,
    'NAME'           => 'Название группы',
    'DESCRIPTION'    => 'Описание группы',
    'OWNER_ID'       => $userId,           // создатель = владелец
    'VISIBLE'        => 'Y',               // Y/N — публичная видимость
    'OPENED'         => 'Y',               // Y = открытая, N = закрытая
    'SUBJECT_ID'     => 1,                 // тематика (ID из CSocNetGroup::GetSubjectList)
    'SPAM_PERMS'     => 'E',               // кто может приглашать: E=все, L=участники, N=никто
    'IMAGE_ID'       => 0,
    'KEYWORDS'       => 'ключевые слова',
    'INITIATE_PERMS' => CSocNetGroup::INITIATE_PERMS_CLOSED, // OPEN/CLOSED/MODERATORS
    'MODERATE_NEW_MESSAGES' => 'N',
    'ALLOW_MESSAGE_PIN'     => 'Y',
]);

if (!$groupId) {
    global $APPLICATION;
    $err = $APPLICATION->GetException();
}

// Получить группу по ID
$groupRes = CSocNetGroup::GetByID($groupId);

// Получить список групп с фильтром
$groupList = CSocNetGroup::GetList(
    ['DATE_CREATE' => 'DESC'],
    ['VISIBLE' => 'Y', 'ACTIVE' => 'Y'],
    false,
    ['nTopCount' => 20],
    ['ID', 'NAME', 'DESCRIPTION', 'OWNER_ID', 'NUMBER_OF_MEMBERS']
);
while ($g = $groupList->Fetch()) { /* ... */ }

// Удалить группу
CSocNetGroup::Delete($groupId);
```

### Участники группы

```php
Loader::includeModule('socialnet');

// Добавить пользователя в группу
$rel = CSocNetUserToGroup::Add([
    'GROUP_ID'  => $groupId,
    'USER_ID'   => $userId,
    'ROLE'      => SONET_ROLES_USER,       // SONET_ROLES_OWNER / SONET_ROLES_MODERATOR / SONET_ROLES_USER
    'INITIATED_BY_TYPE' => SONET_INITIATED_BY_GROUP, // или SONET_INITIATED_BY_USER
    'INITIATED_BY_USER_ID' => $currentUserId,
    'DATE_CREATE' => date('d.m.Y H:i:s'),
]);

// Ожидающий участник (запрос на вступление)
CSocNetUserToGroup::Add([
    'GROUP_ID' => $groupId,
    'USER_ID'  => $userId,
    'ROLE'     => SONET_ROLES_REQUEST,
    'INITIATED_BY_TYPE' => SONET_INITIATED_BY_USER,
    'INITIATED_BY_USER_ID' => $userId,
    'DATE_CREATE' => date('d.m.Y H:i:s'),
]);

// Получить участников группы
$members = CSocNetUserToGroup::GetList(
    ['DATE_CREATE' => 'ASC'],
    ['GROUP_ID' => $groupId, 'ROLE' => SONET_ROLES_USER],
    false, false,
    ['USER_ID', 'ROLE', 'DATE_CREATE']
);
while ($m = $members->Fetch()) { /* ... */ }

// Удалить участника из группы
CSocNetUserToGroup::Delete($groupId, $userId);

// Константы ролей:
// SONET_ROLES_OWNER      = 'A' (владелец)
// SONET_ROLES_MODERATOR  = 'E' (модератор)
// SONET_ROLES_USER       = 'K' (участник)
// SONET_ROLES_REQUEST    = 'R' (запрос)
// SONET_ROLES_BAN        = 'B' (заблокирован)
```

### Подписки на события группы

```php
Loader::includeModule('socialnet');

// Подписать пользователя на событие группы
CSocNetSubscription::Add([
    'USER_ID'      => $userId,
    'EVENT_ID'     => 'BLOG_POST',          // тип события
    'ENTITY_TYPE'  => SONET_ENTITY_GROUP,   // 'G' для группы
    'ENTITY_ID'    => $groupId,
]);

// Отписать
CSocNetSubscription::Delete([
    'USER_ID'     => $userId,
    'EVENT_ID'    => 'BLOG_POST',
    'ENTITY_TYPE' => SONET_ENTITY_GROUP,
    'ENTITY_ID'   => $groupId,
]);
```

---

## CSocNetLogDestination — живая лента

```php
Loader::includeModule('socialnet');

// Добавить запись в живую ленту (лог активности)
$logId = CSocNetLog::Add([
    'ENTITY_TYPE'  => SONET_ENTITY_GROUP,  // 'G' — группа, 'U' — пользователь
    'ENTITY_ID'    => $groupId,
    'EVENT_ID'     => 'blog_post',          // идентификатор типа события
    'LOG_DATE'     => date('d.m.Y H:i:s'),
    'TITLE'        => 'Новый пост',
    'MESSAGE'      => 'Краткое описание',
    'URL'          => '/blog/post/' . $postId . '/',
    'MODULE_ID'    => 'blog',
    'USER_ID'      => $userId,
    'CLASS_NAME'   => 'CBlogPost',
    'METHOD_NAME'  => 'log',
    'PARAMS'       => serialize(['POST_ID' => $postId]),
    'RATING_TYPE_ID'    => 'BLOG_POST',
    'RATING_ENTITY_ID'  => $postId,
]);

// Назначить получателей записи ленты
if ($logId) {
    CSocNetLogDestination::Add([
        'LOG_ID'      => $logId,
        'SOURCE_TYPE' => 'G',              // G = группа
        'SOURCE_ID'   => $groupId,
    ]);

    // Отправить уведомления подписчикам
    CSocNetLog::SendEvent('BLOG_POST', $logId, $userId);
}

// Получить записи ленты для пользователя
$logRes = CSocNetLog::GetList(
    ['LOG_DATE' => 'DESC'],
    ['USER_ID' => $userId],
    false,
    ['nTopCount' => 20],
    ['ID', 'ENTITY_TYPE', 'ENTITY_ID', 'EVENT_ID', 'TITLE', 'LOG_DATE', 'USER_ID']
);
while ($log = $logRes->Fetch()) { /* ... */ }
```

---

## CLike — лайки

```php
Loader::includeModule('socialnet'); // CLike входит в socialnet

// Поставить лайк
$result = CLike::Add([
    'ENTITY_TYPE' => 'BLOG_POST',  // тип сущности
    'ENTITY_ID'   => $postId,
    'USER_ID'     => $userId,
]);
// $result: true при успехе, false если уже лайкнуто

// Убрать лайк
CLike::Delete([
    'ENTITY_TYPE' => 'BLOG_POST',
    'ENTITY_ID'   => $postId,
    'USER_ID'     => $userId,
]);

// Получить количество лайков
$count = CLike::GetCount('BLOG_POST', $postId);
// возвращает int

// Проверить, лайкнул ли пользователь
$hasLike = CLike::CheckForLike('BLOG_POST', $postId, $userId);
// возвращает bool

// Популярные типы ENTITY_TYPE:
// 'BLOG_POST'    — пост блога
// 'BLOG_COMMENT' — комментарий блога
// 'SONET_LOG'    — запись ленты
// 'FORUM_MESSAGE'— сообщение форума
// 'NEWS'         — новость
// 'PHOTO'        — фотография
```

---

## CRatings — рейтинг

```php
Loader::includeModule('socialnet');

// Голосование за сущность
$voteResult = CRatings::Vote([
    'ENTITY_TYPE_ID' => 'BLOG_POST',
    'ENTITY_ID'      => $postId,
    'USER_ID'        => $userId,
    'VALUE'          => 1,           // 1 = положительно, -1 = отрицательно
]);
// $voteResult: ['RESULT_VALUE' => 5, 'VOTES' => 10] или false при ошибке

// Получить средний рейтинг (если доступно в конфигурации типа)
$rating = CRatings::GetEntityRating('BLOG_POST', $postId);
// ['TOTAL_VALUE' => 15, 'VOTES' => 10, 'AVERAGE' => 1.5]

// Получить голос пользователя
$userVote = CRatings::GetUserVote('BLOG_POST', $postId, $userId);
// int: 1, -1 или 0 если не голосовал

// Настройки типа рейтинга (CRatingType) задаются в /bitrix/admin/rating_types.php
// Тип должен быть зарегистрирован через CBitrixComponent или install/index.php
```

---

## События модуля blog

```php
use Bitrix\Main\EventManager;
use Bitrix\Main\Event;
use Bitrix\Main\EventResult;

$em = EventManager::getInstance();

// OnBeforeBlogPostAdd — вызывается перед добавлением поста
// можно изменить данные или отменить добавление
$em->addEventHandler('blog', 'OnBeforeBlogPostAdd', function(array &$fields) {
    // Изменить данные
    $fields['TITLE'] = trim($fields['TITLE']);

    // Отменить добавление — вернуть false
    if (mb_strlen($fields['TITLE']) < 3) {
        return false;
    }

    return true;
});

// OnAfterBlogPostAdd — вызывается после успешного добавления
$em->addEventHandler('blog', 'OnAfterBlogPostAdd', function(int $postId, array $fields) {
    // Отправить уведомление, очистить кеш, etc.
    // $postId — ID добавленного поста
});

// OnBeforeBlogPostUpdate — перед обновлением
$em->addEventHandler('blog', 'OnBeforeBlogPostUpdate', function(int $postId, array &$fields) {
    return true; // false = отмена
});

// OnAfterBlogPostDelete — после удаления
$em->addEventHandler('blog', 'OnAfterBlogPostDelete', function(int $postId) {
    // очистка связанных данных
});

// Регистрация в install/index.php (постоянная, хранится в БД):
EventManager::getInstance()->registerEventHandler(
    'blog', 'OnAfterBlogPostAdd',
    'vendor.mymodule',
    \Vendor\Mymodule\BlogHandler::class,
    'onAfterBlogPostAdd'
);
```

---

## Gotchas

- **`Loader::includeModule('blog')`** обязателен перед любым использованием `CBlogPost`, `CBlogComment`, `CBlogUser`, `CBlogCategory`, `CBlogPostCategory`. Без него классы не будут определены.
- **`Loader::includeModule('socialnet')`** обязателен для `CSocNetGroup`, `CSocNetLog`, `CLike`, `CRatings`, но в текущей фазе эти части reference считай отложенными, потому что модуля `socialnet` в проверенном core нет.
- **D7-переноса почти нет**: `CBlogPost`, `CBlogComment` и весь Blog API — legacy, D7-обёрток нет. `CSocNetGroup` тоже legacy. Используй как есть.
- **Автосоздание `CBlogUser` helper-ом в текущем core не подтверждено**: используй явный паттерн `CBlogUser::GetByID(..., BLOG_BY_USER_ID)` и затем `CBlogUser::Add(...)`.
- **Теги блога в текущем core** хранятся через `CBlogCategory` + связь `CBlogPostCategory`, а у поста видны как `CATEGORY_ID`. Не опирайся на несуществующий `CBlogTag`.
- **`PUBLISH_STATUS`**: `'P'` = опубликован, `'D'` = черновик. Только статус `'P'` виден публично.
- **`CSocNetLog::Add()`** + **`CSocNetLogDestination::Add()`** нужно вызывать вместе — запись лога без назначения получателей не попадёт ни в чью ленту.
- **`CLike::CheckForLike()`** возвращает `bool` — не путай с `GetCount()` (возвращает `int`).
- **`CRatings::Vote()`** бросает исключение если тип рейтинга `ENTITY_TYPE_ID` не зарегистрирован — оборачивай в try/catch.
- **Роли в группах**: константы `SONET_ROLES_*` определены только после `includeModule('socialnet')`.
- **Кеш живой ленты** хранится в managed cache — при добавлении через `CSocNetLog::Add()` он инвалидируется автоматически. Не вызывай `BXClearCache()` вручную для лент.
