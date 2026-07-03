#!/usr/bin/env python3
"""Repository-local validation gate for the Bitrix skill.

No third-party packages are required. This intentionally overlaps with
`quick_validate.py`, because local Codex/Claude environments do not always have
PyYAML installed.
"""

from __future__ import annotations

import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import unquote


ROOT = Path(__file__).resolve().parents[1]
FULL_SKILL = ROOT / "bitrix"
MCP_SKILL = ROOT / "mcpmarket" / "bitrix"
MCP_FILE_LIMIT = 50

CRITICAL_REFERENCES = [
    "behavior-routing.md",
    "project-intake.md",
    "task-playbooks.md",
    "reference-map.md",
    "developer-primitives.md",
    "developer-cards.md",
    "first-answer-pitfalls.md",
    "answer-contracts.md",
    "core-grep-cookbook.md",
    "eval-prompts.md",
    "release-gate.md",
]

REQUIRED_DESCRIPTION_TOKENS = [
    "Bitrix",
    "Битрикс",
    "www/bitrix",
    "/local",
    "ShowHead",
    "ShowTitle",
    "catalog",
    "sale",
    "CommerceML",
]

RUNTIME_SMOKE_TEMPLATES = [
    "runtime-smoke/evidence-summary.template.md",
    "runtime-smoke/scenario-result.template.md",
    "runtime-smoke/sandbox-preflight.template.md",
]

OPTIMIZATION_EVIDENCE_TEMPLATES = [
    "optimization-evidence/summary.template.md",
    "optimization-evidence/finding.template.md",
    "optimization-evidence/runtime-metrics.template.md",
]

RECOMMENDED_EVAL_IDS = [
    "B001",
    "B004",
    "B007",
    "B009",
    "B011",
    "B013",
    "B016",
    "B018",
    "B021",
    "B023",
    "B025",
    "B028",
    "B030",
    "B031",
    "B043",
    "B046",
    "B053",
    "B057",
    "B060",
    "B061",
    "B062",
    "B063",
    "B064",
]

REQUIRED_DEVELOPER_CARD_TERMS: list[tuple[str, list[str]]] = [
    ("meta/title", ["meta title", "Meta title"]),
    ("css/js", ["CSS / JS", "CSS/JS"]),
    ("editable content", ["Редактируемый текст", "редактируемый текст"]),
    ("breadcrumbs", ["Хлебные крошки", "breadcrumbs"]),
    ("current user", ["Текущий пользователь", "current user"]),
    ("request", ["Request / GET / POST", "request GET/POST"]),
    ("module include", ["Подключение модуля", "module include"]),
    ("404", ["404"]),
    ("images", ["Картинка / resize", "image resize"]),
    ("iblock property", ["Инфоблок", "iblock property"]),
    ("cache", ["Кеш компонента", "component cache"]),
    ("mail/form", ["Почтовое событие", "mail/form"]),
    ("ajax", ["AJAX"]),
    ("events", ["Обработчик события", "event handler"]),
    ("catalog/sale", ["Catalog/sale/currency", "catalog/sale/currency"]),
    ("1c", ["1С / CommerceML", "1С/CommerceML"]),
]

FORBIDDEN_MARKERS = [
    "developer" + "_" + "wow",
]

REQUIRED_REPO_FILES = [
    ".github/workflows/validate.yml",
    "Makefile",
    "scripts/bitrix_runtime_preflight.py",
    "scripts/bitrix_static_optimization_audit.py",
    "scripts/init_optimization_evidence.py",
    "scripts/validate_optimization_evidence.py",
    "bitrix/assets/optimization-audit-report.template.md",
    "mcpmarket/bitrix/assets/optimization-audit-report.template.md",
    "bitrix/assets/optimization-evidence/summary.template.md",
    "mcpmarket/bitrix/assets/optimization-evidence/summary.template.md",
    "examples/runtime-smoke/blocked-p1/summary.md",
    "examples/optimization-evidence/sample-candidate/summary.md",
]


@dataclass
class Check:
    name: str
    ok: bool
    detail: str = ""


checks: list[Check] = []


def add(name: str, ok: bool, detail: str = "") -> None:
    checks.append(Check(name, ok, detail))


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def extract_frontmatter(path: Path) -> tuple[dict[str, str], str]:
    text = read_text(path)
    match = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    if not match:
        raise ValueError("missing YAML frontmatter")

    frontmatter_text = match.group(1)
    data: dict[str, str] = {}
    current_key: str | None = None
    current_value: list[str] = []

    def flush() -> None:
        nonlocal current_key, current_value
        if current_key is not None:
            data[current_key] = "\n".join(current_value).strip()
        current_key = None
        current_value = []

    for raw_line in frontmatter_text.splitlines():
        if not raw_line.strip():
            continue
        if not raw_line.startswith(" ") and ":" in raw_line:
            flush()
            key, value = raw_line.split(":", 1)
            current_key = key.strip()
            current_value = [value.strip().strip('"').strip("'")]
        elif current_key is not None:
            current_value.append(raw_line.strip())
    flush()

    return data, text


def skill_label(skill_dir: Path) -> str:
    return "mcpmarket/bitrix" if skill_dir == MCP_SKILL else "bitrix"


def validate_skill_frontmatter(skill_dir: Path) -> None:
    label = skill_label(skill_dir)
    path = skill_dir / "SKILL.md"
    try:
        data, text = extract_frontmatter(path)
    except Exception as exc:  # noqa: BLE001 - validation report needs exact error
        add(f"{label} frontmatter", False, str(exc))
        return

    name = data.get("name", "")
    description = data.get("description", "")

    ok = bool(name) and len(name) <= 64 and re.fullmatch(r"[a-z0-9-]+", name) is not None
    add(f"{label} name", ok, name or "missing name")

    missing_tokens = [token for token in REQUIRED_DESCRIPTION_TOKENS if token not in text]
    add(
        f"{label} trigger coverage",
        bool(description) and not missing_tokens,
        "missing: " + ", ".join(missing_tokens) if missing_tokens else "ok",
    )


def parse_simple_yaml_string_value(text: str, key: str) -> str:
    match = re.search(rf"^\s+{re.escape(key)}:\s+\"(.*)\"\s*$", text, re.MULTILINE)
    if not match:
        return ""
    return match.group(1).replace('\\"', '"').replace("\\\\", "\\")


def validate_openai_yaml(skill_dir: Path) -> None:
    label = skill_label(skill_dir)
    path = skill_dir / "agents" / "openai.yaml"
    if not path.exists():
        add(f"{label} openai.yaml", False, "missing agents/openai.yaml")
        return
    text = read_text(path)
    display_name = parse_simple_yaml_string_value(text, "display_name")
    short_description = parse_simple_yaml_string_value(text, "short_description")
    default_prompt = parse_simple_yaml_string_value(text, "default_prompt")

    add(f"{label} openai display_name", bool(display_name), display_name or "missing")
    add(
        f"{label} openai short_description",
        25 <= len(short_description) <= 64,
        f"{len(short_description)} chars",
    )
    add(
        f"{label} openai default_prompt",
        "$bitrix" in default_prompt,
        default_prompt or "missing",
    )


def validate_mcp_file_count() -> None:
    files = [p for p in MCP_SKILL.rglob("*") if p.is_file()]
    add("MCP Market file count", len(files) <= MCP_FILE_LIMIT, f"{len(files)}/{MCP_FILE_LIMIT}")


def iter_markdown_files() -> list[Path]:
    roots = [ROOT / "README.md", ROOT / "CHANGELOG.md"]
    roots.extend(FULL_SKILL.rglob("*.md"))
    roots.extend(MCP_SKILL.rglob("*.md"))
    return [p for p in roots if p.exists()]


def is_external_link(target: str) -> bool:
    return target.startswith(("http://", "https://", "mailto:", "app://", "#"))


def validate_internal_links() -> None:
    missing: list[str] = []
    pattern = re.compile(r"(?<!!)\[[^\]]+\]\(([^)\s]+(?:\s+\"[^\"]+\")?)\)")

    for source in iter_markdown_files():
        text = read_text(source)
        for match in pattern.finditer(text):
            target = match.group(1).split()[0]
            if is_external_link(target):
                continue
            target = unquote(target.split("#", 1)[0])
            if not target:
                continue
            resolved = (source.parent / target).resolve()
            if not resolved.exists():
                missing.append(f"{source.relative_to(ROOT)} -> {target}")

    add("internal markdown links", not missing, "; ".join(missing[:10]) if missing else "ok")


def validate_critical_references() -> None:
    full_skill_md = read_text(FULL_SKILL / "SKILL.md")
    mcp_skill_md = read_text(MCP_SKILL / "SKILL.md")
    changelog = read_text(ROOT / "CHANGELOG.md")

    missing: list[str] = []
    for name in CRITICAL_REFERENCES:
        if not (FULL_SKILL / "references" / name).exists():
            missing.append(f"full missing {name}")
        if not (MCP_SKILL / "references" / name).exists():
            missing.append(f"mcp missing {name}")
        if f"references/{name}" not in full_skill_md:
            missing.append(f"full SKILL.md not linked {name}")
        if f"references/{name}" not in mcp_skill_md:
            missing.append(f"mcp SKILL.md not linked {name}")
        if name not in changelog:
            missing.append(f"CHANGELOG.md not mentioning {name}")

    add("critical references synced", not missing, "; ".join(missing[:10]) if missing else "ok")


def validate_eval_prompts() -> None:
    text = read_text(FULL_SKILL / "references" / "eval-prompts.md")
    ids = sorted(set(re.findall(r"\bB\d{3}\b", text)))
    missing = [prompt_id for prompt_id in RECOMMENDED_EVAL_IDS if prompt_id not in ids]
    add("eval prompt count", len(ids) >= 50, f"{len(ids)} prompt ids")
    add("recommended eval set", not missing, "missing: " + ", ".join(missing) if missing else "ok")
    add("eval bad-first-step column", "Must not say first" in text, "ok" if "Must not say first" in text else "missing")


def validate_developer_card_coverage() -> None:
    full = read_text(FULL_SKILL / "references" / "developer-cards.md")
    compact = read_text(MCP_SKILL / "references" / "developer-cards.md")
    missing_full = [
        label for label, alternatives in REQUIRED_DEVELOPER_CARD_TERMS
        if not any(term in full for term in alternatives)
    ]
    missing_compact = [
        label for label, alternatives in REQUIRED_DEVELOPER_CARD_TERMS
        if not any(term in compact for term in alternatives)
    ]
    missing = []
    if missing_full:
        missing.append("full missing: " + ", ".join(missing_full))
    if missing_compact:
        missing.append("compact missing: " + ", ".join(missing_compact))
    add("developer cards eval coverage", not missing, "; ".join(missing) if missing else "ok")


def validate_runtime_smoke_templates() -> None:
    missing: list[str] = []
    for rel_path in RUNTIME_SMOKE_TEMPLATES:
        full_path = FULL_SKILL / "assets" / rel_path
        compact_path = MCP_SKILL / "assets" / rel_path
        if not full_path.exists():
            missing.append(f"full missing {rel_path}")
        if not compact_path.exists():
            missing.append(f"mcp missing {rel_path}")
        if full_path.exists() and compact_path.exists() and read_text(full_path) != read_text(compact_path):
            missing.append(f"template drift {rel_path}")

    runtime_text = read_text(FULL_SKILL / "references" / "runtime-smoke-verification.md")
    compact_text = read_text(MCP_SKILL / "references" / "core-routing.md")
    for marker in ["P1-01", "P1-08", "P2", "P3", "P4", "evidence"]:
        if marker not in runtime_text:
            missing.append(f"runtime-smoke missing marker {marker}")
        if marker not in compact_text:
            missing.append(f"compact core-routing missing marker {marker}")

    add("runtime smoke templates synced", not missing, "; ".join(missing[:10]) if missing else "ok")


def validate_optimization_evidence_templates() -> None:
    missing: list[str] = []
    for rel_path in OPTIMIZATION_EVIDENCE_TEMPLATES:
        full_path = FULL_SKILL / "assets" / rel_path
        compact_path = MCP_SKILL / "assets" / rel_path
        if not full_path.exists():
            missing.append(f"full missing {rel_path}")
        if not compact_path.exists():
            missing.append(f"mcp missing {rel_path}")
        if full_path.exists() and compact_path.exists() and read_text(full_path) != read_text(compact_path):
            missing.append(f"template drift {rel_path}")

    audit_text = read_text(FULL_SKILL / "references" / "project-optimization-audit.md")
    compact_text = read_text(MCP_SKILL / "references" / "search-seo-ops.md")
    for marker in ["optimization evidence", "validate_optimization_evidence.py", "OPT-001"]:
        if marker not in audit_text:
            missing.append(f"project-optimization-audit missing marker {marker}")
        if marker not in compact_text:
            missing.append(f"compact search-seo-ops missing marker {marker}")

    add("optimization evidence templates synced", not missing, "; ".join(missing[:10]) if missing else "ok")


def validate_runtime_evidence_validator() -> None:
    script = ROOT / "scripts" / "validate_runtime_evidence.py"
    if not script.exists():
        add("runtime evidence validator", False, "missing scripts/validate_runtime_evidence.py")
        return

    with tempfile.TemporaryDirectory() as tmp:
        evidence_dir = Path(tmp)
        summary = evidence_dir / "summary.md"
        rows = "\n".join(
            f"| P1-{index:02d} | pass | P1-{index:02d}-scenario.txt | |"
            for index in range(1, 9)
        )
        summary.write_text(
            "\n".join(
                [
                    "# Runtime smoke evidence summary",
                    "",
                    "## Modules and versions",
                    "| Module | Status | Version | Notes |",
                    "|---|---|---:|---|",
                    "| `main` | found | 26.150.0 | |",
                    "| `iblock` | found | 26.0.0 | |",
                    "| `catalog` | found | 25.550.0 | |",
                    "| `currency` | found | 26.0.0 | |",
                    "| `sale` | found | 26.0.0 | |",
                    "",
                    "## Scenario verdicts",
                    "| Scenario | Verdict | Evidence file | Notes |",
                    "|---|---|---|---|",
                    rows,
                    "",
                ]
            ),
            encoding="utf-8",
        )
        for index in range(1, 9):
            (evidence_dir / f"P1-{index:02d}-scenario.txt").write_text(
                f"Scenario: P1-{index:02d}\nVerdict: pass\n",
                encoding="utf-8",
            )
        result = subprocess.run(
            [sys.executable, str(script), str(evidence_dir), "--package", "P1"],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )

    add(
        "runtime evidence validator",
        result.returncode == 0,
        "ok" if result.returncode == 0 else result.stdout.strip().splitlines()[-1],
    )


def validate_runtime_evidence_initializer() -> None:
    script = ROOT / "scripts" / "init_runtime_evidence.py"
    if not script.exists():
        add("runtime evidence initializer", False, "missing scripts/init_runtime_evidence.py")
        return

    with tempfile.TemporaryDirectory() as tmp:
        output = Path(tmp) / "p1"
        result = subprocess.run(
            [sys.executable, str(script), "--package", "P1", "--output", str(output)],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )
        expected_files = ["summary.md", "00-preflight.md"] + [
            f"P1-{index:02d}-{slug}.md"
            for index, slug in [
                (1, "modules"),
                (2, "catalog-list-detail"),
                (3, "price-stock"),
                (4, "offer-selection"),
                (5, "guest-basket"),
                (6, "auth-basket"),
                (7, "order-save"),
                (8, "cache-pass"),
            ]
        ]
        missing = [name for name in expected_files if not (output / name).exists()]

    add(
        "runtime evidence initializer",
        result.returncode == 0 and not missing,
        "missing: " + ", ".join(missing) if missing else ("ok" if result.returncode == 0 else result.stdout.strip()),
    )

    with tempfile.TemporaryDirectory() as tmp:
        output = Path(tmp) / "all"
        result = subprocess.run(
            [sys.executable, str(script), "--all", "--output", str(output)],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )
        expected_dirs = ["p1-shop-path", "p2-commerceml", "p3-rest-webservice", "p4-marketing-automation"]
        missing_dirs = [name for name in expected_dirs if not (output / name / "summary.md").exists()]

    add(
        "runtime evidence initializer --all",
        result.returncode == 0 and not missing_dirs,
        "missing: " + ", ".join(missing_dirs) if missing_dirs else ("ok" if result.returncode == 0 else result.stdout.strip()),
    )


def validate_optimization_evidence_validator() -> None:
    script = ROOT / "scripts" / "validate_optimization_evidence.py"
    if not script.exists():
        add("optimization evidence validator", False, "missing scripts/validate_optimization_evidence.py")
        return

    with tempfile.TemporaryDirectory() as tmp:
        evidence_dir = Path(tmp)
        (evidence_dir / "summary.md").write_text(
            "\n".join(
                [
                    "# Optimization evidence summary",
                    "",
                    "## Scope",
                    "",
                    "## Static audit",
                    "",
                    "## Findings",
                    "",
                    "| ID | Priority | Layer | Verdict | Evidence file | Notes |",
                    "|---|---|---|---|---|---|",
                    "| OPT-001 | P1 | db-orm | candidate | OPT-001-finding.md | test |",
                    "",
                    "## Runtime/perfmon",
                    "",
                    "## Safe wins",
                    "",
                    "## Blocked/runtime-needed",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        (evidence_dir / "OPT-001-finding.md").write_text(
            "\n".join(
                [
                    "# Optimization finding — OPT-001",
                    "",
                    "## Evidence",
                    "test",
                    "",
                    "## Impact",
                    "test",
                    "",
                    "## Fix plan",
                    "test",
                    "",
                    "## Verification",
                    "test",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        result = subprocess.run(
            [sys.executable, str(script), str(evidence_dir)],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )

    add(
        "optimization evidence validator",
        result.returncode == 0,
        "ok" if result.returncode == 0 else result.stdout.strip().splitlines()[-1],
    )


def validate_optimization_evidence_initializer() -> None:
    script = ROOT / "scripts" / "init_optimization_evidence.py"
    if not script.exists():
        add("optimization evidence initializer", False, "missing scripts/init_optimization_evidence.py")
        return

    with tempfile.TemporaryDirectory() as tmp:
        output = Path(tmp) / "optimization"
        result = subprocess.run(
            [
                sys.executable,
                str(script),
                "--date",
                "2026-07-03",
                "--finding-count",
                "2",
                "--output",
                str(output),
            ],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )
        expected_files = [
            "summary.md",
            "00-runtime-metrics.md",
            "OPT-001-finding.md",
            "OPT-002-finding.md",
            "README.md",
            "static-audit.md",
        ]
        missing = [name for name in expected_files if not (output / name).exists()]

    add(
        "optimization evidence initializer",
        result.returncode == 0 and not missing,
        "missing: " + ", ".join(missing) if missing else ("ok" if result.returncode == 0 else result.stdout.strip()),
    )


def validate_runtime_preflight_helper() -> None:
    script = ROOT / "scripts" / "bitrix_runtime_preflight.py"
    if not script.exists():
        add("runtime preflight helper", False, "missing scripts/bitrix_runtime_preflight.py")
        return

    with tempfile.TemporaryDirectory() as tmp:
        result = subprocess.run(
            [sys.executable, str(script), "--public-root", str(Path(tmp) / "missing")],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )

    ok = result.returncode == 0 and "Verdict: `blocked`" in result.stdout
    output_lines = result.stdout.strip().splitlines()
    add("runtime preflight helper", ok, "ok" if ok else (output_lines[-1] if output_lines else "no output"))


def validate_version_changelog_plan() -> None:
    version_text = read_text(ROOT / "bitrix" / "VERSION").strip()
    semver_ok = re.fullmatch(r"\d+\.\d+\.\d+", version_text) is not None
    add("version semver", semver_ok, version_text)

    changelog = read_text(ROOT / "CHANGELOG.md")
    has_changelog_section = f"## [{version_text}]" in changelog
    add("version changelog section", has_changelog_section, f"## [{version_text}]" if has_changelog_section else "missing")

    plan = read_text(ROOT / "PLAN.md")
    has_plan_version = f"`{version_text}`" in plan or f" {version_text}" in plan
    add("version plan sync", has_plan_version, "ok" if has_plan_version else f"{version_text} not mentioned in PLAN.md")

    unreleased_link = re.search(r"\[Unreleased\]:\s+https://github\.com/Poliklot/bitrix-agent-skill/compare/v([0-9.]+)\.\.\.HEAD", changelog)
    add(
        "unreleased compare base",
        bool(unreleased_link) and unreleased_link.group(1) == version_text,
        unreleased_link.group(1) if unreleased_link else "missing",
    )


def validate_compact_reference_coverage() -> None:
    compact_map = read_text(MCP_SKILL / "references" / "reference-map.md")
    missing: list[str] = []
    full_ref_names = {path.name for path in (FULL_SKILL / "references").glob("*.md")}
    for path in sorted((FULL_SKILL / "references").glob("*.md")):
        if path.name not in compact_map:
            missing.append(path.name)

    compact_refs = {path.name for path in (MCP_SKILL / "references").glob("*.md")}
    referenced_compact = sorted(set(re.findall(r"`([^`]+\.md)`", compact_map)))
    missing_compact = [
        name for name in referenced_compact
        if name not in compact_refs and name not in full_ref_names and not name.startswith("../")
        and "/" not in name
        and not name.startswith("BITRIX_PROJECT_CONTEXT")
    ]
    details: list[str] = []
    if missing:
        details.append("full refs not mapped: " + ", ".join(missing[:10]))
    if missing_compact:
        details.append("compact refs missing: " + ", ".join(missing_compact[:10]))
    add("compact reference coverage", not details, "; ".join(details) if details else "ok")


def validate_required_repo_files() -> None:
    missing = [path for path in REQUIRED_REPO_FILES if not (ROOT / path).exists()]
    add("repo automation files", not missing, "missing: " + ", ".join(missing) if missing else "ok")


def validate_forbidden_markers() -> None:
    matches: list[str] = []
    files = list(FULL_SKILL.rglob("*")) + list(MCP_SKILL.rglob("*")) + [ROOT / "README.md", ROOT / "CHANGELOG.md"]
    for path in files:
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        for marker in FORBIDDEN_MARKERS:
            if marker in text:
                matches.append(str(path.relative_to(ROOT)))
    add("forbidden markers", not matches, ", ".join(sorted(set(matches))) if matches else "ok")


def validate_git_diff_check() -> None:
    result = subprocess.run(
        ["git", "diff", "--check"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    add("git diff --check", result.returncode == 0, result.stdout.strip() or "ok")


def main() -> int:
    validate_required_repo_files()
    validate_version_changelog_plan()
    validate_skill_frontmatter(FULL_SKILL)
    validate_skill_frontmatter(MCP_SKILL)
    validate_openai_yaml(FULL_SKILL)
    validate_openai_yaml(MCP_SKILL)
    validate_mcp_file_count()
    validate_internal_links()
    validate_compact_reference_coverage()
    validate_critical_references()
    validate_eval_prompts()
    validate_developer_card_coverage()
    validate_runtime_smoke_templates()
    validate_optimization_evidence_templates()
    validate_runtime_evidence_validator()
    validate_runtime_evidence_initializer()
    validate_optimization_evidence_validator()
    validate_optimization_evidence_initializer()
    validate_runtime_preflight_helper()
    validate_forbidden_markers()
    validate_git_diff_check()

    width = max(len(check.name) for check in checks)
    failed = [check for check in checks if not check.ok]
    for check in checks:
        status = "PASS" if check.ok else "FAIL"
        print(f"{status}  {check.name:<{width}}  {check.detail}")

    if failed:
        print(f"\nFAILED: {len(failed)} check(s)")
        return 1
    print("\nAll validation checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
