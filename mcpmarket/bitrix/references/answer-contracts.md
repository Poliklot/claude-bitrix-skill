# Контракты первого ответа

Открывай после `developer-primitives.md`, `first-answer-pitfalls.md` и `developer-cards.md`, когда нужно выдать не просто правильный Bitrix-примитив, а правильный формат ответа. Для project evidence используй `core-grep-cookbook.md`.

## Универсальный шаблон

```text
В Битриксе это обычно делается через [штатный механизм], а не через [анти-паттерн].
Проверь в проекте: [2–4 файла/параметра/grep].
Минимальный пример: [короткий код, если нужен].
Учти: [1–3 side effects].
```

Если проекта нет под рукой:

```text
Если есть доступ к проекту, сначала проверь: [paths/grep].
Без проверки ядра я бы начал с [Bitrix-native route], а не с [anti-pattern].
```

## Типы ответа

| Ситуация | Формат |
|---|---|
| “Как сделать X?” | Short how-to: механизм → где проверить → пример → side effects. |
| “Почему X не работает?” | Debug chain: источник → params → project layer → cache/index/rights/logs. |
| “Куда править?” | Layer answer: page/component params/template in `local`/local module/migration; не `www/bitrix/modules`. |
| “Напиши код” | Code answer: module facts, `use`, checks, escaping/filtering, cache/CSRF caveats. |
| “Есть ли sale/catalog/1C?” | Module-dependent: проверить module dir/version + `Loader`; если нет — deferred/fallback. |
| “Поменяй данные/права/контент” | Confirmation block from `SKILL.md` before direct data mutation. |
| “Изучи проект и оптимизации” | Optimization audit: что уже оптимизировано → недоработки → safe wins → runtime/perfmon-needed → что не трогать вслепую. |

## Частые контракты

- **Meta/title/head:** начать с `ShowHead()` + `ShowTitle()`, page/section properties, component SEO params, `SetTitle`, `SetPageProperty`; не с ручного `<meta>`.
- **CSS/JS:** `Asset::addCss/addJs/addString`, `template_styles.css`, `script.js`, `ShowHead`/`ShowBodyScripts`; не echo из случайного компонента.
- **Components:** найти `IncludeComponent`, params, template in `local/templates/.../components`; HTML — `template.php`, data — `result_modifier`/class, page effects — `component_epilog`.
- **Iblock property:** проверить `PROPERTY_CODE`, `FIELD_CODE`, `DISPLAY_PROPERTIES`, `$arResult`, `result_modifier`; не SQL.
- **Cache/composite:** назвать слой: component cache, `CACHE_GROUPS`, `setResultCacheKeys`, tagged cache, composite frame; не “выключи весь кеш”.
- **Project optimization audit:** использовать compact `search-seo-ops.md` + `core-grep-cookbook.md`; не начинать с Redis/CDN/global clear без evidence.
- **Forms/mail/ajax:** request via `Context`, validation, `check_bitrix_sessid`; mail events/templates; project ajax/controller pattern, JSON, auth; не `mail()`/endpoint without sessid.
- **Sale/catalog:** сначала `catalog`/`sale`/`currency` module check; API only, учесть events/recalc/discount/reserve/payment/shipment side effects.
- **1С/CommerceML:** проверить `checkauth → init → file → import`, cookies/session, temp files, XML_ID/CML2_LINK, logs; не “просто загрузи XML”.

## Good first answer checklist

- Bitrix-native mechanism named.
- Bad first step explicitly avoided.
- 2–4 project checks or grep paths.
- Minimal code only when useful.
- Side effects named.
- Optional module not assumed.
- Short question stays short.
