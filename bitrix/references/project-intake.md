# Аудит Bitrix-проекта

Открывай, когда задача относится к конкретному репозиторию: “у нас”, “в этом проекте”, “найди где”, “почему не работает”, “почини”, “сделай патч”. Цель — за 1–3 минуты понять структуру Bitrix-проекта и отвечать по фактам, а не по памяти.

Не запускай этот аудит для чисто теоретического вопроса без доступа к проекту.

## Долгоживущий контекст проекта

Если в корне проекта есть `BITRIX_PROJECT_CONTEXT.md`, прочитай его после `AGENTS.md` и пользовательских инструкций, но до нового широкого аудита. Это сохранённый снимок уже изученного проекта, а не абсолютная истина: для рискованных задач, изменений данных, shop/1С, прав, кеша, REST/webservice и обновлений перепроверяй факты в текущем коде.

Если файла нет и ты провёл полный аудит проекта, создай `BITRIX_PROJECT_CONTEXT.md` в корне клиентского проекта по шаблону [../assets/BITRIX_PROJECT_CONTEXT.template.md](../assets/BITRIX_PROJECT_CONTEXT.template.md). Для короткого одноразового вопроса файл можно не создавать; для длинной разработки, серии задач или handoff — создавать обязательно.

В `BITRIX_PROJECT_CONTEXT.md` нельзя записывать secrets, cookies, tokens, пароли, license keys, production XML/дампы, персональные данные и приватные payloads. Файл должен содержать только безопасные факты проекта: public root, modules/versions, шаблоны, компоненты, `local/*`, events/agents, tooling, shop/1С endpoints, runtime/smoke status, риски и открытые вопросы.

## Быстрый аудит

Запускать из корня репозитория. Если команда падает из-за отсутствующей папки — это факт проекта, не ошибка.

```bash
find . -maxdepth 5 -type d -path '*/bitrix/modules/main' -print
find . -maxdepth 4 -type d \( -name local -o -name bitrix \) -print
```

```bash
find www/bitrix/modules -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sed 's#^www/bitrix/modules/##' | sort | head -n 80
```

```bash
find local/templates bitrix/templates www/bitrix/templates -maxdepth 3 \
  \( -name header.php -o -name footer.php -o -name '.section.php' \) -type f 2>/dev/null | sort
```

```bash
rg -n 'ShowHead|ShowTitle|ShowBodyScripts|ShowPanel|IncludeComponent\(' \
  local bitrix/templates www/bitrix/templates --glob '*.php' 2>/dev/null
```

## Что зафиксировать

| Факт | Как искать | Почему важно |
|---|---|---|
| Public root | `*/bitrix/modules/main` | Все Bitrix paths зависят от public root. |
| Слой проекта | `local/`, `local/modules`, `local/components`, `local/templates` | Постоянные правки должны идти сюда, не в core. |
| Активный шаблон | `header.php`, `footer.php`, `SITE_TEMPLATE_PATH`, calls on pages | Для meta/assets/panel/layout. |
| Контракт head | `ShowHead`, `ShowTitle`, `ShowBodyScripts` | Решает бытовые meta/CSS/JS вопросы. |
| Компоненты | `IncludeComponent(` and `local/templates/*/components` | Где править вывод и параметры. |
| Состав модулей | `www/bitrix/modules/*/install/version.php` | Нельзя обещать API отсутствующего модуля. |
| 404/routing | `404.php`, `urlrewrite.php`, `SEF_MODE`, `SET_STATUS_404` | Для status/SEO/SEF diagnostics. |
| Cache/composite | `CACHE_TYPE`, `CACHE_GROUPS`, `StartResultCache`, `setFrameMode`, `createFrame`, `StaticHtmlCache`, `/bitrix/html_pages/`, `X-Bitrix-Composite` | Для “изменения не видны”, second request/cache pass и персонализации. |
| Optimization markers | cache params, `GetList/getList`, heavy templates, `ResizeImageGet`, `Asset`, agents/stepper/imports, `perfmon` | Для audit-report “что уже оптимизировано / что сломано / safe wins”. |
| Tooling | `composer.json`, `phpunit.xml*`, `phpstan*`, `psalm*`, `rector.php` | Не тащить новый PHP-stack, если проектный уже есть. |
| Events/agents | `EventManager`, `addEventHandler`, `CAgent`, `Stepper` | Для кастомной логики и фоновых задач. |

## Module check

Для optional modules:

```bash
for m in iblock highloadblock form search seo catalog sale currency rest bizproc workflow pull socialnet; do
  if test -f "www/bitrix/modules/$m/install/version.php"; then
    echo "FOUND $m"
    sed -n '1,40p' "www/bitrix/modules/$m/install/version.php"
  else
    echo "MISSING $m"
  fi
done
```

Если public root не `www/`, заменить prefix на найденный root.

## Tooling check

```bash
find . -maxdepth 3 \( -name composer.json -o -name 'phpunit.xml*' -o -name 'phpstan*' -o -name 'psalm*' -o -name 'rector.php' -o -name '.php-cs-fixer*' \) -print
```

Не считать `www/bitrix/modules/*/vendor/composer.json` project tooling.

## Формат отчёта

После аудита отвечай кратко:

```text
Нашёл по проекту:
- context file: [BITRIX_PROJECT_CONTEXT.md found/missing/updated]
- public root: [path]
- project layer: [local yes/no, local/modules yes/no, local/components yes/no]
- template/head: [header.php path, ShowHead yes/no, ShowTitle yes/no]
- modules: [relevant found/missing]
- target layer: [page/component/template/local module]

Дальше делаю: [next action].
```

Для простого вопроса не показывай весь отчёт, только релевантные факты:

```text
Проверил: в `local/templates/main/header.php` уже есть `ShowHead()` и `ShowTitle()`.
Значит meta руками вставлять не надо; меняем [page property/component SEO param].
```

## Быстрый аудит для частых задач

### Meta/title/CSS/JS

Проверить:

```bash
rg -n 'ShowHead|ShowTitle|SetTitle|SetPageProperty|AddHeadString|Asset::getInstance|ShowBodyScripts' \
  local bitrix/templates www/bitrix/templates --glob '*.php'
```

Выводить только найденный `header.php`/page/component fact.

### Где править компонент

```bash
rg -n 'IncludeComponent\(' . --glob '*.php' --glob '!upload/**' --glob '!bitrix/cache/**' --glob '!www/bitrix/cache/**'
find local/templates bitrix/templates -path '*components/bitrix*' -type f 2>/dev/null | sort
```

Сначала project template, затем stock component contract.

### “В админке есть, на сайте нет”

Проверить:

1. Module and source entity.
2. Component params (`IBLOCK_ID`, `PROPERTY_CODE`, filters).
3. Rights/site binding/activity/date.
4. `result_modifier.php` / template.
5. Cache/index/composite.

### Shop/1C

Сначала:

```bash
for m in catalog sale currency; do test -f "www/bitrix/modules/$m/install/version.php" && echo "FOUND $m" || echo "MISSING $m"; done
```

Без `catalog`/`sale`/`currency` не вести задачу как полноценный shop-route.

## Когда создавать `BITRIX_PROJECT_CONTEXT.md`

Создавать/обновлять файл после полного изучения проекта, если:

- пользователь просит “изучи проект”, “разбери архитектуру”, “подготовь план доработок”;
- задача будет продолжаться в нескольких шагах или передаваться другому агенту;
- найдены важные module/version facts, shop/1С endpoints, template/component overrides или integration risks;
- после исправления стало понятно, что это постоянный project convention.

Минимальная команда для старта файла:

```bash
test -f BITRIX_PROJECT_CONTEXT.md || cp path/to/bitrix/assets/BITRIX_PROJECT_CONTEXT.template.md BITRIX_PROJECT_CONTEXT.md
```

Если шаблон навыка недоступен, создай файл вручную с теми же разделами: паспорт проекта, public root, modules/versions, templates/head, components, shop, 1С, REST/webservice, events/agents, tooling, cache/SEO/routing, risks, open questions, sources.

## Когда остановиться

Быстрый аудит не должен превращаться в полный разбор всего проекта. Остановиться, когда есть:

- найденный target file/layer;
- подтверждённый или отсутствующий module;
- понятная следующая проверка/patch;
- риски side effects.

Дальше переходить к узкому reference или патчу.
