# Component и Data Flow Debugging — справочник

> Reference для Bitrix-скилла. Загружай для задач по стандартным компонентам, шаблонам, `result_modifier.php`, `component_epilog.php`, AJAX и трассировке данных от API до HTML.

## Содержание
- Truth layers
- Путь данных
- Где менять код
- Диагностические команды
- Red flags
- С чем читать вместе

## Truth layers

Порядок проверки:

1. `www/bitrix/modules/<module>/install/components/bitrix/<component>/`
2. `local/components/<vendor>/<component>/`, если есть
3. `local/templates/<template>/components/bitrix/<component>/<template>/`, если есть
4. `bitrix/templates/<template>/components/bitrix/<component>/<template>/`
5. `www/bitrix/templates/*/components/bitrix/...`
6. wizard public/template assets

Если `local/*` отсутствует, не останавливайся: stock templates и `bitrix/templates/*` становятся следующим живым слоем.

## Путь данных

1. `.parameters.php` задаёт контракт параметров.
2. `component.php` / `class.php` собирает данные и управляет кешем.
3. `result_modifier.php` изменяет `$arResult` до шаблона.
4. `template.php` отвечает за вывод и минимальную view-логику.
5. `component_epilog.php` делает поздние эффекты: meta, breadcrumbs, assets, deferred work.
6. JS/AJAX может заменить HTML после загрузки.

## Где менять код

| Что нужно | Слой |
|---|---|
| Изменить внешний вид | copied template |
| Подготовить поля для view | `result_modifier.php` или service до него |
| Добавить meta/breadcrumbs/canonical | `component_epilog.php` или page layer |
| Изменить бизнес-правило | service/module layer |
| Поменять выборку | component params, service, repository/ORM/legacy API |
| Добавить AJAX endpoint | controller/action route, не inline chaos в шаблоне |
| Починить кеш | component cache keys, tagged cache, `setResultCacheKeys` |

## Диагностические команды

```bash
find www/bitrix/modules -path '*/install/components/bitrix/<component>' -type d

find local/components bitrix/templates www/bitrix/templates -path '*<component>*' -type f

rg -n 'result_modifier|component_epilog|setResultCacheKeys|AbortResultCache|StartResultCache|includeComponentTemplate|ajax|BX.ajax' local bitrix/templates www/bitrix/templates www/bitrix/modules
```

Заменяй `<component>` на реальное имя, например `form.result.new`, `blog.post`, `search.page`.

## Red flags

- Толстая бизнес-логика в `template.php`.
- SQL или внешнее API прямо из шаблона.
- `result_modifier.php` меняет данные без учёта кеша.
- `component_epilog.php` используется для тяжёлых запросов вместо поздних page effects.
- Копия шаблона оторвана от stock variant и не сверена после обновления core.
- AJAX endpoint живёт в случайном PHP-файле без CSRF/access checks.

## С чем читать вместе

- Components — [components.md](components.md)
- Templates — [templates.md](templates.md)
- Standard non-commerce components — [standard-components-noncommerce.md](standard-components-noncommerce.md)
- Events/routing — [events-routing.md](events-routing.md)
- PHP workflow — [php-workflow.md](php-workflow.md)
