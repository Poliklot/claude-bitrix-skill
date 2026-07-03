# Frontend/assets/images performance — справочник

> Загружай при задачах “тяжёлая страница”, “много CSS/JS”, “картинки грузятся долго”, “LCP/CLS”, “оптимизировать шаблон”, “дубли assets”, “lazy/webp/srcset”. Для общего аудита сначала [project-optimization-audit.md](project-optimization-audit.md), для шаблонов — [templates.md](templates.md), для файлов/cloud — [clouds.md](clouds.md), [file-upload-modern.md](file-upload-modern.md).

## Принцип

Frontend-оптимизация в Bitrix должна учитывать PHP-шаблоны, Asset layer, component assets, composite и resize cache:

```text
template/component → Asset/CFile/resize → composite/static HTML → browser/CDN/network
```

Не лечи frontend только CDN-ом: сначала найди, что реально грузится и где подключается.

## Быстрый grep

```bash
rg -n 'Asset::getInstance|addCss|addJs|addString|ShowHead|ShowBodyScripts|template_styles.css|script.js|<script|<link|ResizeImageGet|CFile::GetPath|srcset|loading="lazy"|webp|upload/resize_cache' \
  local bitrix/templates www/bitrix/templates --glob '*.php' --glob '*.js' --glob '*.css'
```

## Asset layer

Правильные признаки:

- site-level CSS/JS подключаются в шаблоне сайта или bundle layer;
- component-specific CSS/JS лежит в `style.css`/`script.js` шаблона компонента или подключается рядом с компонентом;
- `ShowHead()` и `ShowBodyScripts()` реально выводятся;
- нет дублей одного файла на странице;
- AJAX/composite не ломают порядок подключения.

Красные флаги:

- `<script>`/`<link>` руками в случайном `template.php`;
- условные assets по пользователю/региону в static composite HTML;
- весь shop/frontend bundle грузится на каждой странице;
- inline JS содержит персональные данные и кешируется composite.

## Images

Проверяй:

- `CFile::ResizeImageGet`/project image service вместо HTML-only resize;
- реальные `width/height` для CLS;
- `loading="lazy"` для внеэкранных списков;
- `srcset`/retina/webp, если проект это поддерживает;
- `upload/resize_cache` и `clouds` handler;
- повторный resize в цикле на одни и те же файлы.

Плохо:

```php
<img src="<?= CFile::GetPath($id) ?>" width="300" height="200">
```

Лучше:

```php
$image = CFile::ResizeImageGet($id, ['width' => 600, 'height' => 400], BX_RESIZE_IMAGE_PROPORTIONAL, true);
?>
<img src="<?= htmlspecialcharsbx($image['src']) ?>" width="<?= (int)$image['width'] ?>" height="<?= (int)$image['height'] ?>" loading="lazy" alt="">
```

## Composite caveats

- Не клади user-specific JS variables в общий cached `<script>`.
- Dynamic blocks должны обновлять только персональную часть, а не весь тяжёлый список.
- Conditional assets в dynamic area проверяй в Network после composite AJAX.
- Если nginx composite отдаёт HTML без PHP, frontend fix в PHP не сработает до сброса HTML/static cache.

## Browser/CDN cache

CDN/browser cache предлагай после проверки:

- какие URL горячие и тяжёлые;
- cache headers для assets;
- версионирование файлов (`?v=`, build hash, mtime);
- нет ли user-specific response под общим CDN key;
- invalidation strategy.

## Формат finding

```text
Evidence: local/templates/site/components/.../template.php:18 <img> без lazy/srcset и resize
Impact: кандидат на LCP/traffic issue
Fix: project image service / ResizeImageGet + width/height + lazy вне viewport
Verify: browser network, Lighthouse/WebPageTest, визуальная проверка
```
