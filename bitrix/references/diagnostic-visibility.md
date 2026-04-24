# Visibility Diagnostics: “в админке есть, на сайте нет” — справочник

> Reference для Bitrix-скилла. Загружай для задач “не видно на сайте”, “в админке есть”, “компонент ничего не выводит”, “у одного пользователя видно, у другого нет”.

## Содержание
- Диагностическая цепочка
- Быстрые команды
- Типовые причины
- Модульные маршруты
- Что нельзя делать
- С чем читать вместе

## Диагностическая цепочка

Иди от источника данных к браузеру:

1. Модуль и компонент реально установлены.
2. Данные существуют и активны.
3. Сайт, язык, права и группы пользователя совпадают.
4. Компонент получает правильные параметры.
5. Выборка не отфильтровала данные.
6. `result_modifier.php` не выкинул нужные поля.
7. `template.php` реально выводит эти данные.
8. Кеш компонента/тегированный кеш не отдаёт старое состояние.
9. Страница не скрыта SEO/robots/noindex/canonical logic.
10. Клиентский JS/AJAX не перерисовывает пустое состояние.

## Быстрые команды

```bash
find www/bitrix/modules -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort

find local/components bitrix/templates www/bitrix/templates -path '*result_modifier.php' -o -path '*component_epilog.php' -o -path '*template.php'

rg -n 'CACHE_TYPE|CACHE_TIME|CACHE_TAG|clearByTag|clearTaggedCache|StartTagCache|EndTagCache|setResultCacheKeys|AbortResultCache' local bitrix/templates www/bitrix/templates www/bitrix/modules

rg -n 'ACTIVE|ACTIVE_FROM|ACTIVE_TO|SITE_ID|LID|GROUP_ID|PERMISSION|RIGHT|CHECK_PERMISSIONS|noindex|canonical|robots' local bitrix/templates www/bitrix/templates www/bitrix/modules
```

Если `local/*` отсутствует, сразу переходи к `bitrix/templates`, `www/bitrix/templates` и stock templates в `www/bitrix/modules/*/install/components/bitrix`.

## Типовые причины

| Симптом | Проверить |
|---|---|
| В админке есть, на публичке пусто | `ACTIVE`, даты активности, site binding, section active chain, права |
| У админа видно, у гостя нет | группы пользователя, `CHECK_PERMISSIONS`, inherited rights, component params |
| После правки не меняется | component cache, tagged cache, managed cache, composite/static cache |
| В списке нет, детальная открывается | фильтр списка, section filter, pagination, sort, `INCLUDE_SUBSECTIONS` |
| В поиске нет | search index, module `search`, `BeforeIndex`, rights, site, URL function |
| SEO/URL странный | `urlrewrite.php`, SEF params, canonical, redirects, robots/noindex |
| Файл не открывается | `clouds`, `HANDLER_ID`, secure file access, `CFile` path, rights |
| Форма отправляется, но результата нет | form status, validators, handlers, permissions, CRM link |

## Модульные маршруты

- IBlock/HL: сначала `iblocks.md`, `highloadblock.md`, потом кеш и права.
- Forms: `webforms.md`, затем status/validator/handler/secure files.
- Blog/forum/vote: legacy API и standard component template layer.
- Search/SEO: `search.md`, `seo-cache-access.md`, `index-cache-diagnostics.md`.
- File/address/media: `fileman.md`, `location.md`, `clouds.md`.
- Security: WAF/MFA/redirect/IP restrictions can affect visibility and access.

## Что нельзя делать

- Не говорить “почистите весь кеш” как единственный ответ.
- Не менять шаблон, пока не проверен входной `$arResult`.
- Не считать отсутствие `local/*` отсутствием кастомизации: stock templates и wizard templates всё ещё влияют на вывод.
- Не путать физическое наличие `catalog.*` компонента в `iblock` с установленным модулем `catalog`.
- Не отключать права/кеш/SEO без понимания побочных эффектов.

## С чем читать вместе

- Component/data flow — [component-dataflow-debugging.md](component-dataflow-debugging.md)
- Cache/index — [index-cache-diagnostics.md](index-cache-diagnostics.md)
- Components/templates — [components.md](components.md), [templates.md](templates.md)
- Search/SEO — [search.md](search.md), [seo-cache-access.md](seo-cache-access.md)
- Security/access — [security.md](security.md), [access-rbac.md](access-rbac.md)
