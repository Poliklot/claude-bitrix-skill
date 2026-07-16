# Аудит Bitrix-проекта

Открывай, когда задача относится к конкретному repo: “у нас”, “в этом проекте”, “найди где”, “почему не работает”, “почини”, “сделай патч”.

## Долгоживущий контекст проекта

Если в корне проекта есть `BITRIX_PROJECT_CONTEXT.md`, прочитай его после `AGENTS.md`, но до широкого аудита. Это сохранённый снимок проекта, не абсолютная истина: для рискованных задач и shop/1С/integration изменений перепроверяй код.

Если файла нет и проведён полный аудит проекта, создай/обнови `BITRIX_PROJECT_CONTEXT.md` в корне клиентского проекта по шаблону [../assets/BITRIX_PROJECT_CONTEXT.template.md](../assets/BITRIX_PROJECT_CONTEXT.template.md). Не записывать secrets, tokens, cookies, license keys, production XML/дампы и персональные данные.

## Быстрый аудит

```bash
find . -maxdepth 5 -type d -path '*/bitrix/modules/main' -print
find . -maxdepth 4 -type d \( -name local -o -name bitrix \) -print
find www/bitrix/modules -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sed 's#^www/bitrix/modules/##' | sort | head -n 80
find local/templates bitrix/templates www/bitrix/templates -maxdepth 3 \( -name header.php -o -name footer.php -o -name '.section.php' \) -type f 2>/dev/null | sort
rg -n 'ShowHead|ShowTitle|ShowBodyScripts|ShowPanel|IncludeComponent\(|IncludeFile\(|main\.include|SetViewTarget|ShowViewContent' local bitrix/templates www/bitrix/templates --glob '*.php' 2>/dev/null
find . -maxdepth 4 -type f \( -name '.env.example' -o -name composer.json -o -name constants.php -o -name init.php \) -print
rg -l 'Dotenv|\$_ENV|\$_SERVER|getenv\(|Option::get|COption::GetOption|IBLOCK_ID|FORM_ID|HLBLOCK_ID' local . --glob '*.php' --glob '*.example' --glob '!bitrix/**' --glob '!www/bitrix/**' --glob '!vendor/**'
```

Config-discovery выводит только filenames: строки могут содержать credentials. Выбранные файлы проверяй локально и точечно; secrets перед transcript/evidence заменяй на `<redacted>`.

Если public root не `www/`, замени prefix на найденный root.

## Что зафиксировать

| Факт | Почему важно |
|---|---|
| public root | От него зависят Bitrix paths. |
| `local/`, `local/modules`, `local/components`, `local/templates` | Слой кастомизации проекта. |
| active template/header/footer | Meta/assets/layout/panel. |
| `ShowHead`, `ShowTitle`, `ShowBodyScripts` | Бытовые ответы про head/assets. |
| `IncludeComponent` calls and local component templates | Где живут вывод и параметры. |
| `.section.php`, includes и delayed areas | Где живут page/section fragments. |
| `.env`/`Option`/constants/entity IDs | Config convention, validation и drift стендов. |
| module inventory | Нельзя обещать API отсутствующего модуля. |
| `404.php`, `urlrewrite.php`, `SEF_*` | Диагностика routing/status. |
| cache/composite markers | Диагностика “изменения не видны”. |
| optimization markers | Кеши, SQL/ORM/N+1, images/assets, agents/imports и `perfmon` для audit-report. |
| composer/phpunit/phpstan/psalm/rector | Сначала использовать tooling проекта. |
| events/agents | Кастомная логика и фоновые задачи. |

## Module check

```bash
for m in iblock highloadblock form search seo catalog sale currency rest bizproc workflow pull socialnet; do
  test -f "www/bitrix/modules/$m/install/version.php" && echo "FOUND $m" || echo "MISSING $m"
done
```

## Формат отчёта

```text
Нашёл по проекту:
- context file: BITRIX_PROJECT_CONTEXT.md found/missing/updated
- public root: [path]
- project layer: [local/local modules/components/templates]
- template/head: [header path, ShowHead yes/no, ShowTitle yes/no]
- modules: [relevant found/missing]
- target layer: [page/component/template/local module]

Дальше делаю: [next action].
```

Для простого вопроса показывай только релевантные факты.

Для layout/include используй `project-layout-and-includes.md`; для `.env`/`Option`/ID — `project-configuration.md`. В context фиксируй источник/schema/status, но не secret values.

## Файл контекста проекта

Создавай/обновляй `BITRIX_PROJECT_CONTEXT.md` после полного изучения проекта, многошаговой работы, handoff или обнаружения важных фактов по modules/templates/shop/1C/integrations. Если шаблон недоступен, создай те же разделы вручную: паспорт проекта, public root, modules/versions, templates/head, components, shop, 1С, REST/webservice, events/agents, tooling, cache/SEO/routing, risks, open questions, sources.

## Когда остановиться

Останови быстрый аудит, когда понятны target file/layer, наличие модуля, следующая проверка/patch и побочные эффекты. Дальше используй узкий bundle или делай патч.
