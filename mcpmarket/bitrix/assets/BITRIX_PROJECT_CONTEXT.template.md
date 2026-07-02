# BITRIX_PROJECT_CONTEXT.md

> Файл создаётся агентом в корне конкретного Bitrix-проекта после полного аудита проекта. Это не справочник по Bitrix, а проверенный снимок текущего проекта. Не хранить secrets, cookies, tokens, пароли, персональные данные, production XML/дампы и ключи лицензий.

## Паспорт проекта

- Дата аудита:
- Аудитор/агент:
- Ветка/commit:
- Public root:
- Тип проекта: `1C-Bitrix CMS` / `boxed Bitrix24` / другое:
- Окружение: local / staging / production / unknown:
- Проверка runtime: not checked / Docker sandbox / staging / production read-only:

## Как читать этот файл

1. Сначала прочитать `AGENTS.md` и пользовательские инструкции.
2. Затем прочитать этот файл.
3. Если задача рискованная или данные могли измениться, перепроверить факты в коде, а не верить снимку вслепую.
4. После значимого аудита или изменения проекта обновить этот файл.

## Public root и структура

- Public root:
- `www/bitrix` exists: yes/no/path
- `local/` exists: yes/no/path
- `local/modules`:
- `local/components`:
- `local/templates`:
- `bitrix/templates` / `www/bitrix/templates`:
- `upload/` политика:
- Особые entrypoints:

## Модули и версии

| Module | Status | Version | Version file | Notes |
|---|---|---:|---|---|
| `main` | found/missing | | | |
| `iblock` | found/missing | | | |
| `highloadblock` | found/missing | | | |
| `catalog` | found/missing | | | |
| `sale` | found/missing | | | |
| `currency` | found/missing | | | |
| `rest` | found/missing | | | |
| `bizproc` | found/missing | | | |
| `pull` | found/missing | | | |
| `webservice` | found/missing | | | |

## Шаблоны, head и assets

- Активные site templates:
- `header.php`:
- `footer.php`:
- `ShowHead()` найден: yes/no/path
- `ShowTitle()` найден: yes/no/path
- `ShowBodyScripts()` найден: yes/no/path
- Asset layer: `Asset::getInstance()` / legacy / custom:
- Ручные meta/head вставки:
- Composite/cache особенности (`setFrameMode`, `createFrame`, `/bitrix/html_pages/`, `X-Bitrix-Composite`, dynamic blocks):

## Кеши и оптимизации

- Политика component cache:
- Политика tagged/managed cache:
- Статус composite (`setFrameMode`, `createFrame`, `/bitrix/html_pages/`, `X-Bitrix-Composite`):
- Известные персональные/dynamic blocks:
- SQL/ORM/N+1 hotspots:
- Политика изображений/resize/lazy:
- Политика frontend assets:
- Agents/cron/stepper/import performance notes:
- Статус `perfmon`/runtime evidence:
- Safe optimization candidates:
- Риски оптимизаций / открытые вопросы:

## Компоненты и шаблоны компонентов

| Page/route | Component | Template | Override path | Notes |
|---|---|---|---|---|
| | | | | |

- Где искать public pages:
- Где искать copied templates:
- AJAX/lazy routes:
- Pagination conventions:

## Интернет-магазин

- Shop route status: active/deferred/absent
- Catalog iblock IDs/XML_ID:
- Offers iblock IDs/XML_ID:
- Price types:
- Stores/stock mode:
- Basket component/page:
- Checkout/order component/page:
- Personal area/order history:
- Payment systems mode:
- Delivery services mode:
- Discounts/coupons:
- Known side effects:

## 1С / CommerceML

- Exchange status: active/deferred/absent
- Endpoints/pages:
- `catalog.import.1c` settings:
- `catalog.export.1c` settings:
- `sale.export.1c` settings:
- XML_ID/CML2_LINK policy:
- Temp/upload paths:
- Logs:
- Test fixtures available:
- Production 1С credentials present in repo: must be no

## REST/webservice/integrations

- REST status:
- Webhooks/apps:
- Required scopes:
- Sale/catalog REST events:
- Placements:
- SOAP/WSDL/webservice endpoints:
- External services/stubs:
- Secrets policy:

## Events, agents, steppers

| Layer | File/class | Event/agent | Side effects | Notes |
|---|---|---|---|---|
| | | | | |

- `local/php_interface`:
- custom modules:
- agents mode: hit/cron/unknown
- steppers:
- queue/background jobs:

## Tooling и качество

- `composer.json`:
- PHPUnit:
- phpstan/psalm:
- fixer/sniffer:
- rector:
- CI:
- Project PHP version:
- DB version/charset:

## Кеш, поиск, SEO, routing

- Managed/tagged cache:
- Composite (`/bitrix/html_pages/`, headers, invalidation, dynamic areas):
- Search indexing:
- SEO/meta source:
- `urlrewrite.php`:
- `404.php`:
- Redirects/canonical:
- Known cache reset commands:

## Риски и запреты проекта

- Не трогать без подтверждения:
- Данные с побочными эффектами:
- Production-only integrations:
- Места, где нельзя править core:
- Known fragile code:

## Открытые вопросы

- [ ]

## Источники фактов

Сохранять только безопасные команды/пути, без secrets и PII.

```text
[command/path checked]
```
