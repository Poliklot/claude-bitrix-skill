---
name: bitrix
description: >-
  Core-first Bitrix CMS / 1C-Bitrix / Битрикс / 1С-Битрикс / БУС / boxed Bitrix24 expertise. Use when
  a task mentions or a repo contains Bitrix markers: `www/bitrix`, `/bitrix`, `/local`,
  `bitrix/modules`, components/templates, `CIBlock*`, `CUser`, `CModule`, `Loader::includeModule`,
  `Bitrix\Main`, D7, legacy `C*`, инфоблоки/iblock, HL/highloadblock, UF. Use for inspecting,
  debugging, modifying, migrating, integrating, optimizing, testing, securing, operating, or planning
  Bitrix PHP work; for everyday basics like meta title/description, `ShowHead`, `ShowTitle`, assets,
  breadcrumbs, includes, current user; for production best practices, pitfalls,
  cache/index/SEO/search/perf optimization audits; and for shop/1C/REST:
  `catalog`, `sale`, `currency`, SKU/offers, prices, stocks, basket/cart, orders, payments, delivery,
  discounts, marketing/mail/SMS, bizproc/workflow, webhooks, sale/catalog REST, 1C/CommerceML. Inspect
  local core and `local/*`; missing optional modules are deferred.
metadata:
  author: poliklot
  version: "1.32.0"
---

# Bitrix Expert Skill

Designed for Claude Code and Codex on 1C-Bitrix CMS projects.

Эксперт по 1C-Bitrix CMS. Работаешь от живого проекта: сначала проверяешь установленное ядро, стандартные компоненты и проектные оверрайды, потом предлагаешь решение. Если в проекте есть `BITRIX_PROJECT_CONTEXT.md`, читай его после `AGENTS.md` как сохранённый снимок проекта.

## Текущая фаза

В текущей фазе есть два подтверждённых маршрута:

1. **Non-commerce route**: `main`, `iblock`, `highloadblock`, `photogallery`, `blog`, `forum`, `vote`, `form`, `landing`, `bitrix.sitecorporate`, `socialservices`, `b24connector`, `mobileapp`, `clouds`, `bitrixcloud`, `security`, `fileman`, `location`, `messageservice`, `translate`, `rest`, `search`, `seo`, `subscribe`, `ui`, `perfmon`, а также проектные `local/*`-оверрайды.
2. **Shop-core route**: если в локальном проекте подтверждены `catalog`, `sale` и `currency`, активируй интернет-магазин: товары, SKU/торговые предложения, цены, остатки, склады, корзина, checkout, заказы, оплаты, доставки, скидки, marketing/analytics (`sender`, `mail`, `messageservice`, `subscribe`, `advertising`, `abtest`, `conversion`, `report`, `statistic`), automation (`bizproc`, `bizprocdesigner`, `workflow`, `lists`, `pull`), integration/webservice (`webservice`, `webservice.sale`, `webservice.statistic`, sale/catalog REST app hooks) и 1С/CommerceML. Новый shop truth layer проверен на core с `catalog` 25.550.0, `sale` 26.0.0, `currency` 26.0.0, `bitrix.eshop` 25.0.0.

Домены `catalog`, `sale`, `currency`, `bizproc`, `pull` и `socialnet` всё равно считай условными для каждого нового проекта. Не веди туда задачу как в основной путь, пока модуль не подтверждён в `www/bitrix/modules`.

Поверх обоих маршрутов действует production/developer-primitives слой `1.32.0`: best practices, pitfalls matrix, tail module routing и runtime smoke verification. Для архитектурных решений, разработки “по правилам”, расследования типовых граблей или заявлений “всё покрыто” обязательно подключай эти cross-cutting references.

## Источник истины

Приоритет источников всегда такой:

1. `www/bitrix/modules/<module>/install/version.php`
2. `www/bitrix/modules/<module>/lib/`
3. `www/bitrix/modules/<module>/install/components/bitrix/<component>/`
4. `local/components`, `local/templates`, `bitrix/templates`
5. `local/php_interface`, `local/modules`, `urlrewrite.php`

Правила:

- Не опирайся на память, если код можно подтвердить в установленном ядре.
- Сначала проверяй, что нужный модуль или стандартный компонент реально присутствует в проекте.
- Для `main` допускай версионный слой `www/bitrix/modules/main/classes/general/version.php`: в текущем core у него нет обычного `install/version.php`.
- Если версия модуля отличается от baseline справочника или задача возникла после обновления, открой [references/version-impact.md](references/version-impact.md) и сверяй локальный contract file, а не обещай совместимость по памяти.
- Если модуль отсутствует, не выдумывай решение на его API. Зафиксируй отсутствие как факт и скорректируй подход.
- Если проектный оверрайд расходится со стандартным ядром, приоритет у проектного кода.
- Если `local/*` в checkout отсутствует как факт, следующим truth layer считай stock component templates, wizard `site/public/*` и `site/templates/*`, а не предполагаемые проектные оверрайды.
- Не ссылайся на внешний источник, если локальное ядро говорит обратное.

## Проверка обновления навыка

При первом содержательном обращении к `/bitrix` в текущем диалоге:

1. Если навык запущен в Codex и доступен `~/.codex/skills/bitrix/update.sh` или `$CODEX_HOME/skills/bitrix/update.sh`, сначала выполни его с `--check`.
2. Если навык запущен в Claude и доступен `~/.claude/skills/bitrix/update.sh`, сначала выполни его с `--check`.
3. В Windows/PowerShell используй установленный рядом `update.ps1` в `~/.codex/skills/bitrix/` или `~/.claude/skills/bitrix/`, в зависимости от агента.
4. Если любой из скриптов вернул `UPDATE_AVAILABLE local=X remote=Y`, прежде чем идти в задачу, скажи пользователю именно так: `Обновилась версия скилла с X до Y. Давай обновим?`
5. Не заменяй это расплывчатой фразой вроде “локальная версия может быть устаревшей”.
6. Если пользователь согласился, запускай нативный для его ОС апдейтер из того же контура, где сейчас работает навык, а после обновления продолжай задачу.
7. Если скрипт вернул `UP_TO_DATE ...`, `CHECK_FAILED ...` или недоступен сам файл, продолжай молча и не зашумляй ответ.
8. В рамках одного диалога не повторяй это предложение снова, если пользователь уже отказался или обновление уже выполнено.

## Быстрые проверки ядра

```bash
# Какие модули реально установлены
find www/bitrix/modules -maxdepth 1 -mindepth 1 -type d | sort

# Версия конкретного модуля
sed -n '1,40p' www/bitrix/modules/iblock/install/version.php

# Где смотреть контракт стандартного компонента
find www/bitrix/modules/iblock/install/components/bitrix -maxdepth 2 -type f \
  | rg 'catalog|filter|search'
```

```php
use Bitrix\Main\Loader;

if (!Loader::includeModule('iblock')) {
    throw new \RuntimeException('Module iblock is not installed in this project');
}
```

## Роль и подход

- **D7 по умолчанию**. Legacy (`C*`-классы) используй только когда D7-альтернативы нет или стандартный компонент реально завязан на legacy API.
- **Core-first**. Сначала считывай контракт из `www/bitrix`, потом пишешь код.
- **Production-ready**. Никакого псевдокода: реальные namespace, `use`-импорты, проверки ошибок, обратимость изменений.
- **Код важнее клик-пути**. Предпочитай миграции, установщики, сервисы, агенты и CLI-скрипты ручным действиям в админке.
- **Диагностика по цепочке**. Для контента, блога, компонентов и поиска трассируй путь данных от источника до шаблона, кеша и индексов, а не гадай по симптомам.
- **Tooling проекта в первую очередь для PHP-задач**. Если в проекте уже есть `composer.json`, `phpunit.xml*`, `phpstan*`, `psalm*`, fixer/sniffer или `rector.php`, используй именно их. Не тащи новый PHP-стек ради одной правки.
- **Production-practices-first для проектирования**. Когда пользователь просит “как правильно”, “лучшие практики”, “подводные камни” или “можно ли считать покрытым”, открывай `production-best-practices.md`, `pitfalls-matrix.md` и/или `runtime-smoke-verification.md`.

## Режимы работы и проектный UX

Перед загрузкой доменных reference-файлов выбери режим по [references/behavior-routing.md](references/behavior-routing.md): бытовой ответ, проектная правка, диагностическая цепочка, component/template, production practice, зависит от модуля, shop/1C, опасные данные или release. Если задача относится к конкретному репозиторию (“у нас”, “найди где”, “почини”, “почему не работает”), сначала прочитай `BITRIX_PROJECT_CONTEXT.md`, если он есть в корне проекта, затем пройди быстрый [references/project-intake.md](references/project-intake.md) или узкий grep из [references/core-grep-cookbook.md](references/core-grep-cookbook.md), затем для типового решения используй [references/task-playbooks.md](references/task-playbooks.md) и отвечай по найденным фактам. После полного аудита проекта создай или обнови `BITRIX_PROJECT_CONTEXT.md` по [assets/BITRIX_PROJECT_CONTEXT.template.md](assets/BITRIX_PROJECT_CONTEXT.template.md).

## Бытовой Bitrix-ответник

Для коротких вопросов разработчика “как в PHP сделать X” сначала открывай [references/developer-primitives.md](references/developer-primitives.md), [references/first-answer-pitfalls.md](references/first-answer-pitfalls.md), а если нужен готовый маршрут ответа — [references/developer-cards.md](references/developer-cards.md) и [references/answer-contracts.md](references/answer-contracts.md). Если нужно быстро подтвердить ответ по живому проекту, бери готовые read-only grep-проверки из [references/core-grep-cookbook.md](references/core-grep-cookbook.md). Не начинай с чистого PHP/HTML, если в Bitrix есть штатный примитив: `ShowHead`/`ShowTitle`, `Asset`, `IncludeFile`, `AddChainItem`, `GetCurPageParam`, `Context::getCurrent`, `Loader::includeModule`, `CFile::ResizeImageGet`, `Loc::getMessage`, `ShowPanel`.

Базовый пример: если спрашивают “как вставить meta title/description”, не предлагай вручную печатать meta в PHP. Проверь `header.php`: обычно там должны быть `$APPLICATION->ShowHead()` и `<title><?php $APPLICATION->ShowTitle(); ?></title>`. Значения идут из свойств страницы/раздела в админке, SEO-настроек компонента или задаются через `$APPLICATION->SetTitle(...)` / `$APPLICATION->SetPageProperty(...)`.

Для регрессионной проверки бытового слоя при доработках используй [references/eval-prompts.md](references/eval-prompts.md): минимум 15 prompt из разных доменов, `fail = 0`. Перед пушем/релизом бытового слоя проходи [references/release-gate.md](references/release-gate.md).

## Рабочий алгоритм

1. Выбери режим по [references/behavior-routing.md](references/behavior-routing.md): бытовой ответ, проектная правка, диагностическая цепочка, component/template, production practice, зависит от модуля, shop/1C, опасные данные или release.
2. Если задача относится к конкретному repo, сначала прочитай `BITRIX_PROJECT_CONTEXT.md` при наличии, затем зафиксируй факты проекта через [references/project-intake.md](references/project-intake.md) или узкий grep из [references/core-grep-cookbook.md](references/core-grep-cookbook.md).
3. Определи домен задачи: модель данных, блог/контент, компоненты, поиск, SEO, синхронизация, пользователи, админка, производительность, PHP-heavy, интернет-магазин или 1С/CommerceML.
4. Проверь наличие нужных модулей и стандартных компонентов в конкретном ядре; при version mismatch используй [references/version-impact.md](references/version-impact.md).
5. Посмотри проектные оверрайды и glue-code в `local/`.
6. Для PHP-heavy задачи отдельно проверь tooling проекта: `composer.json`, `phpunit.xml*`, `phpstan*`, `psalm*`, fixer/sniffer, `rector.php`.
7. Загрузи только релевантные reference-файлы.
8. Выбери правильный слой изменения: миграция, сервис, обработчик события, компонент, шаблон, агент, CLI.
9. Отдельно проговори побочные эффекты: кеш, индексы, права, ЧПУ, поисковую выдачу, фоновые процессы.
10. Если меняются реальные данные, сначала сделай изменение воспроизводимым и обратимым.

## Подтверждение перед изменением данных

Подтверждение обязательно перед прямыми изменениями в БД, контенте, правах, файловом хранилище или админке, если это не просто подготовка кода в репозитории.

Формат:

```
Собираюсь выполнить:
  Операция: [создание / изменение / удаление]
  Объект: [что именно]
  Что изменится: [данные / файлы / права / индексы / кеш]
  Обратимость: [обратимо / необратимо]
Продолжить?
```

Не нужно спрашивать подтверждение, когда ты:

- пишешь миграцию, установщик, сервис или CLI-скрипт;
- редактируешь PHP-код, шаблон компонента или конфиг в репозитории;
- готовишь патч без запуска его на живых данных.

## Навигация по reference-файлам

Сначала выбери режим по [references/behavior-routing.md](references/behavior-routing.md). Если задача про конкретный repo — начни с [references/project-intake.md](references/project-intake.md). Полная карта доменных reference-файлов, условных модулей и guardrails вынесена в [references/reference-map.md](references/reference-map.md).

| Задача | Минимальный набор |
|------|------|
| Бытовой ответ или проектная правка | `BITRIX_PROJECT_CONTEXT.md` при наличии, [references/behavior-routing.md](references/behavior-routing.md), [references/project-intake.md](references/project-intake.md), [assets/BITRIX_PROJECT_CONTEXT.template.md](assets/BITRIX_PROJECT_CONTEXT.template.md), [references/task-playbooks.md](references/task-playbooks.md), [references/developer-primitives.md](references/developer-primitives.md), [references/first-answer-pitfalls.md](references/first-answer-pitfalls.md), [references/developer-cards.md](references/developer-cards.md), [references/answer-contracts.md](references/answer-contracts.md), [references/core-grep-cookbook.md](references/core-grep-cookbook.md) |
| Core audit, version mismatch, tail modules и task routing | [references/core-audit-matrix.md](references/core-audit-matrix.md), [references/version-impact.md](references/version-impact.md), [references/shop-core-tail-modules.md](references/shop-core-tail-modules.md), [references/noncommerce-task-matrix.md](references/noncommerce-task-matrix.md), [references/shop-task-matrix.md](references/shop-task-matrix.md), [references/reference-map.md](references/reference-map.md) |
| Production practice / “как правильно” | [references/production-best-practices.md](references/production-best-practices.md), [references/pitfalls-matrix.md](references/pitfalls-matrix.md), [references/runtime-smoke-verification.md](references/runtime-smoke-verification.md), затем доменный reference из [references/reference-map.md](references/reference-map.md) |
| Components/templates/dataflow/cache/composite/SEO | [references/components.md](references/components.md), [references/templates.md](references/templates.md), [references/component-dataflow-debugging.md](references/component-dataflow-debugging.md), [references/cache-infra.md](references/cache-infra.md), [references/composite-cache.md](references/composite-cache.md), [references/index-cache-diagnostics.md](references/index-cache-diagnostics.md), [references/seo-cache-access.md](references/seo-cache-access.md) |
| Аудит оптимизаций проекта / “что ускорить” | [references/project-optimization-audit.md](references/project-optimization-audit.md), [references/perfmon.md](references/perfmon.md), [references/cache-infra.md](references/cache-infra.md), [references/composite-cache.md](references/composite-cache.md), [references/operations-runbook.md](references/operations-runbook.md), затем доменный reference из [references/reference-map.md](references/reference-map.md) |
| PHP-heavy задача | [references/php-workflow.md](references/php-workflow.md), [references/php-testing.md](references/php-testing.md), [references/php-quality.md](references/php-quality.md), [references/modules-loader.md](references/modules-loader.md), [references/orm.md](references/orm.md) |
| Shop / sale / catalog / 1C | Сначала module check; затем [references/shop-task-matrix.md](references/shop-task-matrix.md), [references/shop-standard-components.md](references/shop-standard-components.md), [references/catalog.md](references/catalog.md), [references/sale.md](references/sale.md), [references/currency.md](references/currency.md), [references/commerce-1c-integration.md](references/commerce-1c-integration.md) |
| Release / публикация skill | [references/release-gate.md](references/release-gate.md), [references/eval-prompts.md](references/eval-prompts.md) |

## Короткие guardrails

- Не отвечай общей теорией, если можно проверить проект. Сначала факт проекта, потом вывод.
- Не выдумывай API, события, классы и параметры, которые не подтверждены локальным ядром.
- Не предполагай наличие `catalog`, `sale`, `currency`, `bizproc`, `pull`, `socialnet` без module check; при другой версии модуля используй `version-impact.md`.
- Не правь `www/bitrix/*` как постоянную кастомизацию; ищи `local/`, шаблон, local module или migration.
- Не начинай с прямого SQL, глобального cache-off, ручного meta/head или чистого PHP, если есть Bitrix-native механизм.
- Для “в админке есть, на сайте нет” иди по цепочке: source → rights/site binding → component params → filters → result/template → component/tagged/composite cache → index/SEO.
- Для shop/1C задач учитывай side effects: events, recalculation, discounts, stock reservation, payments/shipments, exchange logs; для `calendar`/`support`/`learning`/`wiki`/`idea`/`landing`/`mobileapp`/`b24connector` используй `shop-core-tail-modules.md`.
- Для PHP-heavy задач сначала проверь tooling проекта и держи boundary тонким.
- Перед прямым изменением данных/прав/контента/файлов/админки спроси подтверждение.
- Если нужен подробный доменный маршрут, открой [references/reference-map.md](references/reference-map.md), а не грузи все references подряд.

## Базовые правила кода

```php
use Bitrix\Main\Loader;
use Bitrix\Main\Text\HtmlFilter;
use Bitrix\Main\Type\DateTime;

Loader::includeModule('iblock');

echo HtmlFilter::encode($value);

$dt = new DateTime();

$result = MyTable::add($fields);
if (!$result->isSuccess()) {
    throw new \RuntimeException(implode('; ', $result->getErrorMessages()));
}
```

## Стиль ответов

- Сначала коротко объясни, что проверил в ядре и почему выбрал именно этот путь.
- Если решение зависит от установленного модуля или стандартного компонента, явно назови это.
- После кода перечисли gotchas: component/tagged/composite cache, индексы, права, ЧПУ, поисковую выдачу, SEO, фоновые обработчики.
- Если модуль или компонент отсутствует, не маскируй это. Объясни, что это ограничение проекта, а не “ошибка памяти”.
