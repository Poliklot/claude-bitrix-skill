#!/usr/bin/env python3
"""Read-only static optimization audit for Bitrix projects.

The script intentionally uses only Python stdlib and conservative regexes. It does
not execute project PHP code and does not read runtime cache/upload payloads.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable


DEFAULT_EXCLUDES = {
    ".git",
    ".idea",
    ".vscode",
    "node_modules",
    "vendor",
    "upload",
    "cache",
    "managed_cache",
    "stack_cache",
    "html_pages",
    "tmp",
    "logs",
}

TEXT_EXTENSIONS = {".php", ".phtml", ".inc", ".js", ".css", ".html", ".htm", ".sh", ".sql"}
MAX_FILE_SIZE = 1_000_000


@dataclass
class Evidence:
    file: str
    line: int
    text: str


@dataclass
class Finding:
    kind: str  # optimized | risk | runtime
    priority: str
    category: str
    title: str
    reason: str
    fix: str
    evidence: list[Evidence]


@dataclass
class Rule:
    kind: str
    priority: str
    category: str
    title: str
    reason: str
    fix: str
    pattern: re.Pattern[str]
    include_ext: set[str] | None = None
    path_hint: re.Pattern[str] | None = None


RULES: list[Rule] = [
    Rule(
        "optimized",
        "P3",
        "component-cache",
        "Найден component cache в параметрах/коде компонента",
        "В проекте уже есть признаки кеширования компонентов.",
        "Проверить, что cache key учитывает filter/sort/page/site/groups и не смешивает персональные данные.",
        re.compile(r"CACHE_TYPE\s*['\"]?\s*=>\s*['\"](?:A|Y)['\"]|StartResultCache\s*\("),
        {".php", ".phtml", ".inc"},
    ),
    Rule(
        "risk",
        "P1",
        "component-cache",
        "Component cache отключён или обнулён",
        "`CACHE_TYPE=N` или `CACHE_TIME=0` часто оставляют тяжёлые страницы без кеша.",
        "Подтвердить причину; если персонализация — вынести персональный блок, если нет — включить корректный cache key/tag.",
        re.compile(r"CACHE_TYPE\s*['\"]?\s*=>\s*['\"]N['\"]|CACHE_TIME\s*['\"]?\s*=>\s*(?:0|['\"]0['\"])", re.I),
        {".php", ".phtml", ".inc"},
    ),
    Rule(
        "risk",
        "P1",
        "component-cache",
        "Отключён учёт групп в cache params",
        "`CACHE_GROUPS=N` опасен, если вывод зависит от прав или групп пользователя.",
        "Проверить зависимость вывода от прав; включить `CACHE_GROUPS=Y` или добавить безопасный персональный boundary.",
        re.compile(r"CACHE_GROUPS\s*['\"]?\s*=>\s*['\"]N['\"]", re.I),
        {".php", ".phtml", ".inc"},
    ),
    Rule(
        "optimized",
        "P3",
        "tagged-managed-cache",
        "Найден tagged/managed cache",
        "Проект использует точечную инвалидацию или managed cache.",
        "Проверить совпадение `cacheDir` у data/tagged cache и отсутствие слишком широкого clear.",
        re.compile(r"TaggedCache|RegisterTag|startTagCache|clearByTag|getManagedCache\s*\("),
        {".php", ".phtml", ".inc"},
    ),
    Rule(
        "risk",
        "P1",
        "cache-invalidation",
        "Найден широкий cache clear",
        "Глобальная очистка кеша может маскировать проблему и создавать нагрузку.",
        "Заменить на targeted tag/cacheDir/page invalidation после подтверждения зависимостей.",
        re.compile(r"clearCache\s*\(\s*true|cleanAll\s*\(|deleteAll\s*\(|clearByTag\s*\(\s*true|cleanDir\s*\(\s*(?:false|['\"]/['\"])", re.I),
        {".php", ".phtml", ".inc"},
    ),
    Rule(
        "optimized",
        "P3",
        "composite",
        "Найдены признаки composite/dynamic areas",
        "Проект использует composite compatibility или dynamic boundaries.",
        "Проверить `X-Bitrix-Composite`, `?ncc=1`, guest/user A/user B и dynamic block ids.",
        re.compile(r"setFrameMode\s*\(|createFrame\s*\(|FrameHelper|Composite\\\\Page|StaticHtmlCache|COMPOSITE_FRAME_"),
        {".php", ".phtml", ".inc"},
    ),
    Rule(
        "risk",
        "P0",
        "composite-personalization",
        "Персонализация рядом с composite/cache",
        "Файл содержит признаки пользователя/корзины/цен рядом с кешем или composite; есть риск общего HTML/кеша.",
        "Проверить static HTML, component cache key и dynamic area; персональные блоки вынести в `createFrame()` + безопасный cache policy.",
        re.compile(r"(USER->IsAuthorized|USER->GetID|GetUserGroupArray|FUSER|Basket|basket|cart|personal|price|PRICE|USER_ID).*(setFrameMode|createFrame|CACHE_TYPE|StartResultCache|Composite)|(?:setFrameMode|createFrame|CACHE_TYPE|StartResultCache|Composite).*(USER->IsAuthorized|USER->GetID|GetUserGroupArray|FUSER|Basket|basket|cart|personal|price|PRICE|USER_ID)", re.I),
        {".php", ".phtml", ".inc"},
    ),
    Rule(
        "risk",
        "P1",
        "sql-n-plus-one",
        "DB/API-запрос в шаблоне или result_modifier",
        "`GetList`/ORM/SQL в view-boundary часто приводит к N+1 и сложному кешированию.",
        "Собрать ids, preload одним запросом в component/service, передать готовый map в шаблон.",
        re.compile(r"CIBlockElement::GetList|CIBlockSection::GetList|CUser::GetList|::getList\s*\(|DataManager::getList|->Query\s*\(|SqlQuery|query\s*\("),
        {".php", ".phtml", ".inc"},
        re.compile(r"(template\.php|result_modifier\.php|component_epilog\.php)$"),
    ),
    Rule(
        "risk",
        "P1",
        "sql-n-plus-one",
        "Возможный N+1: цикл и запросы в одном файле",
        "Цикл и `GetList/getList` в одном boundary-файле — кандидат на повторные запросы.",
        "Проверить количество SQL через perfmon; заменить на batch preload/map by id.",
        re.compile(r"foreach\s*\(|while\s*\(|CIBlockElement::GetList|CIBlockSection::GetList|::getList\s*\(|DataManager::getList"),
        {".php", ".phtml", ".inc"},
        re.compile(r"(template\.php|result_modifier\.php|component_epilog\.php)$"),
    ),
    Rule(
        "risk",
        "P1",
        "sql-n-plus-one",
        "Выбор всех полей/свойств",
        "`select *` или выбор всех свойств на списках утяжеляет SQL и память.",
        "Сузить `select`/`FIELD_CODE`/`PROPERTY_CODE` до фактически используемых полей.",
        re.compile(r"['\"]select['\"]\s*=>\s*\[\s*['\"]\*['\"]|SELECT\s+\*|PROPERTY_CODE\s*['\"]?\s*=>\s*\[\s*['\"]\*['\"]", re.I),
        {".php", ".phtml", ".inc"},
    ),
    Rule(
        "risk",
        "P0",
        "shop-side-effects",
        "Raw SQL по catalog/sale таблицам",
        "Прямое изменение `b_sale_*`/`b_catalog_*` обходит события, пересчёты, скидки и резервы.",
        "Использовать catalog/sale API или оформить repair-script с backup, side-effect plan и runtime verification.",
        re.compile(r"(?:INSERT|UPDATE|DELETE)\s+[^;]*(?:b_sale_|b_catalog_)|(?:b_sale_|b_catalog_)[A-Za-z0-9_]*", re.I),
        {".php", ".phtml", ".inc", ".sql"},
    ),
    Rule(
        "optimized",
        "P3",
        "images-assets",
        "Найден resize/image helper",
        "Проект использует resize/cache для изображений.",
        "Проверить размеры, повторное использование, lazy/srcset/webp и cloud handler.",
        re.compile(r"ResizeImageGet|ResizeImageFile|upload/resize_cache|srcset|loading=['\"]lazy['\"]|webp", re.I),
        {".php", ".phtml", ".inc", ".html", ".htm"},
    ),
    Rule(
        "risk",
        "P2",
        "images-assets",
        "Картинки без lazy loading/srcset",
        "Много `<img>` без lazy/srcset может утяжелять списки и карточки.",
        "Проверить LCP/CLS; добавить реальные размеры, lazy для внеэкранных изображений и проектный resize service.",
        re.compile(r"<img\b(?![^>]*(?:loading=|srcset=))", re.I),
        {".php", ".phtml", ".html", ".htm"},
    ),
    Rule(
        "optimized",
        "P3",
        "frontend-assets",
        "Найден Bitrix Asset layer",
        "Проект подключает ресурсы через Bitrix asset pipeline.",
        "Проверить дубли, область подключения и `ShowHead`/`ShowBodyScripts`.",
        re.compile(r"Asset::getInstance\s*\(|addCss\s*\(|addJs\s*\(|template_styles\.css|script\.js"),
        {".php", ".phtml", ".inc"},
    ),
    Rule(
        "risk",
        "P2",
        "frontend-assets",
        "Ручные script/link в PHP-шаблонах",
        "Ручное подключение ресурсов может дублироваться и ломать порядок/composite/ajax.",
        "Перенести в `Asset` или assets компонента, если это не осознанный внешний embed.",
        re.compile(r"<script\b|<link\b[^>]+stylesheet", re.I),
        {".php", ".phtml", ".inc"},
    ),
    Rule(
        "optimized",
        "P3",
        "agents-imports",
        "Найден agent/stepper/CLI слой",
        "В проекте есть признаки вынесения фоновой работы из HTTP.",
        "Проверить hit-mode vs cron, batch limit, resume state и logs.",
        re.compile(r"CAgent::AddAgent|Stepper|bindClass|cron|php\s+.*bitrix\.php", re.I),
        {".php", ".phtml", ".inc", ".sh", ".md"},
    ),
    Rule(
        "risk",
        "P1",
        "agents-imports",
        "Тяжёлый import/exchange в HTTP/boundary-коде",
        "Импорты и обмены без batching/resume могут грузить HTTP и ломать повторный запуск.",
        "Вынести в stepper/agent/CLI, добавить external id, checkpoint, limit и targeted invalidation.",
        re.compile(r"import|exchange|CommerceML|mode=import|checkauth|XML_ID|CML2_LINK|while\s*\(|set_time_limit\s*\(\s*0", re.I),
        {".php", ".phtml", ".inc"},
    ),
]


def should_skip(path: Path, root: Path) -> bool:
    rel_parts = path.relative_to(root).parts
    if any(part in DEFAULT_EXCLUDES for part in rel_parts):
        return True
    if path.suffix.lower() not in TEXT_EXTENSIONS:
        return True
    try:
        return path.stat().st_size > MAX_FILE_SIZE
    except OSError:
        return True


def iter_files(root: Path) -> Iterable[Path]:
    for path in root.rglob("*"):
        if path.is_file() and not should_skip(path, root):
            yield path


def read_lines(path: Path) -> list[str]:
    try:
        return path.read_text(encoding="utf-8", errors="ignore").splitlines()
    except OSError:
        return []


def scan_rule(rule: Rule, files: list[Path], root: Path, max_evidence: int) -> Finding | None:
    evidence: list[Evidence] = []
    for path in files:
        if rule.include_ext and path.suffix.lower() not in rule.include_ext:
            continue
        rel = path.relative_to(root).as_posix()
        if rule.path_hint and not rule.path_hint.search(rel):
            continue
        for index, line in enumerate(read_lines(path), start=1):
            if rule.pattern.search(line):
                evidence.append(Evidence(rel, index, line.strip()[:220]))
                if len(evidence) >= max_evidence:
                    break
        if len(evidence) >= max_evidence:
            break
    if not evidence:
        return None
    return Finding(rule.kind, rule.priority, rule.category, rule.title, rule.reason, rule.fix, evidence)


def postprocess_n_plus_one(findings: list[Finding]) -> None:
    """Downgrade simple cycle/query same-file rule when only one side was found.

    Regex-based line scanning cannot prove N+1. Keep it as runtime-needed if the
    evidence list does not show both loop and query tokens.
    """
    for finding in findings:
        if finding.title != "Возможный N+1: цикл и запросы в одном файле":
            continue
        by_file: dict[str, set[str]] = {}
        for ev in finding.evidence:
            flags = by_file.setdefault(ev.file, set())
            if re.search(r"foreach\s*\(|while\s*\(", ev.text):
                flags.add("loop")
            if re.search(r"GetList|::getList|DataManager::getList", ev.text):
                flags.add("query")
        suspicious = {file for file, flags in by_file.items() if {"loop", "query"}.issubset(flags)}
        if not suspicious:
            finding.kind = "runtime"
            finding.priority = "P2"
            finding.reason = "В boundary-файлах есть циклы или запросы; нужен perfmon/ручная проверка, чтобы подтвердить N+1."
        else:
            finding.evidence = [ev for ev in finding.evidence if ev.file in suspicious]


def build_findings(root: Path, max_evidence: int) -> tuple[list[Finding], int]:
    files = list(iter_files(root))
    findings = [finding for rule in RULES if (finding := scan_rule(rule, files, root, max_evidence))]
    postprocess_n_plus_one(findings)
    return findings, len(files)


def finding_to_json(finding: Finding) -> dict[str, object]:
    return asdict(finding)


def markdown_table(findings: list[Finding], kind: str) -> str:
    rows = ["| Priority | Category | Finding | Evidence | Next action |", "|---|---|---|---|---|"]
    selected = [finding for finding in findings if finding.kind == kind]
    if not selected:
        rows.append("| — | — | Не найдено статическим сканированием | — | Проверить вручную/через runtime evidence |")
        return "\n".join(rows)
    for finding in selected:
        ev = finding.evidence[0]
        evidence = f"`{ev.file}:{ev.line}`"
        rows.append(
            f"| {finding.priority} | {finding.category} | {finding.title} | {evidence} | {finding.fix} |"
        )
    return "\n".join(rows)


def evidence_details(findings: list[Finding]) -> str:
    chunks: list[str] = []
    for finding in findings:
        chunks.append(f"### {finding.priority} · {finding.category} · {finding.title}")
        chunks.append("")
        chunks.append(f"- Тип: `{finding.kind}`")
        chunks.append(f"- Почему важно: {finding.reason}")
        chunks.append(f"- Что сделать: {finding.fix}")
        chunks.append("- Evidence:")
        for ev in finding.evidence:
            chunks.append(f"  - `{ev.file}:{ev.line}` — `{ev.text}`")
        chunks.append("")
    return "\n".join(chunks).rstrip()


def render_markdown(root: Path, findings: list[Finding], files_scanned: int) -> str:
    generated_at = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")
    risk_count = sum(1 for f in findings if f.kind == "risk")
    optimized_count = sum(1 for f in findings if f.kind == "optimized")
    runtime_count = sum(1 for f in findings if f.kind == "runtime")
    lines = [
        "# Static Bitrix optimization audit",
        "",
        "> Read-only статический аудит. Не является runtime/perfmon pass: regex-находки нужно проверять на стенде.",
        "",
        f"- Generated at: `{generated_at}`",
        f"- Project root: `{root}`",
        f"- Files scanned: `{files_scanned}`",
        f"- Optimized signals: `{optimized_count}`",
        f"- Risk findings: `{risk_count}`",
        f"- Runtime-needed candidates: `{runtime_count}`",
        "",
        "## Что уже оптимизировано",
        "",
        markdown_table(findings, "optimized"),
        "",
        "## Ошибки и недоработки оптимизаций",
        "",
        markdown_table(findings, "risk"),
        "",
        "## Требует runtime/perfmon evidence",
        "",
        markdown_table(findings, "runtime"),
        "",
        "## Быстрые safe wins",
        "",
        "1. Проверить P0/P1 findings и убрать персональные данные из общего cache/composite.",
        "2. Для N+1 candidates собрать ids и preload одним запросом, затем проверить SQL count/time.",
        "3. Заменить широкий cache clear на targeted tag/cacheDir/page invalidation.",
        "4. Для images/assets проверить lazy/srcset/real resize и дубли подключений.",
        "",
        "## Что не трогать вслепую",
        "",
        "- Redis/CDN/composite включение без evidence bottleneck.",
        "- DB indexes без `EXPLAIN`/perfmon и оценки write-side effects.",
        "- Полный reindex/cache clear/import на production без окна и rollback.",
        "- Raw SQL по `b_sale_*`/`b_catalog_*` без repair plan.",
        "",
        "## Evidence details",
        "",
        evidence_details(findings) if findings else "Статических находок нет.",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Read-only static Bitrix optimization audit")
    parser.add_argument("root", nargs="?", default=".", type=Path, help="Bitrix project/repository root")
    parser.add_argument("--format", choices=("markdown", "json"), default="markdown")
    parser.add_argument("--output", type=Path, help="Write report to file instead of stdout")
    parser.add_argument("--max-evidence", type=int, default=8, help="Max evidence rows per rule")
    args = parser.parse_args()

    root = args.root.resolve()
    if not root.exists() or not root.is_dir():
        print(f"ERROR: root directory not found: {root}", file=sys.stderr)
        return 2
    if args.max_evidence < 1:
        print("ERROR: --max-evidence must be >= 1", file=sys.stderr)
        return 2

    findings, files_scanned = build_findings(root, args.max_evidence)
    if args.format == "json":
        payload = {
            "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
            "root": str(root),
            "files_scanned": files_scanned,
            "findings": [finding_to_json(finding) for finding in findings],
        }
        output = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    else:
        output = render_markdown(root, findings, files_scanned)

    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output, encoding="utf-8")
    else:
        print(output, end="")
    return 0


if __name__ == "__main__":
    sys.exit(main())
