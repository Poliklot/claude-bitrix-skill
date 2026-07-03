#!/usr/bin/env python3
"""Initialize a Bitrix optimization audit evidence pack from bundled templates."""

from __future__ import annotations

import argparse
import datetime as dt
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TEMPLATE_DIR = ROOT / "bitrix" / "assets" / "optimization-evidence"
DEFAULT_LAYERS = [
    "component-cache",
    "tagged-cache",
    "composite",
    "db-orm",
    "frontend-assets",
    "agents-imports",
    "shop",
]


def read_template(name: str) -> str:
    path = TEMPLATE_DIR / name
    if not path.exists():
        raise FileNotFoundError(f"missing template: {path}")
    return path.read_text(encoding="utf-8")


def write_file(path: Path, text: str, force: bool) -> None:
    if path.exists() and not force:
        raise FileExistsError(f"file exists: {path}; use --force to overwrite")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def build_summary(finding_count: int, date_value: str, project: str, static_report: str) -> str:
    text = read_template("summary.template.md")
    text = text.replace("- Дата: YYYY-MM-DD", f"- Дата: {date_value}")
    if project:
        text = text.replace("- Project/repo:", f"- Project/repo: {project}")
    text = text.replace("- Static audit report: `static-audit.md`", f"- Static audit report: `{static_report}`")

    rows = []
    for index in range(1, finding_count + 1):
        layer = DEFAULT_LAYERS[(index - 1) % len(DEFAULT_LAYERS)]
        priority = "P1" if index == 1 else "P2"
        rows.append(
            f"| OPT-{index:03d} | {priority} | {layer} | candidate | OPT-{index:03d}-finding.md | заполнить evidence |"
        )
    replacement = "\n".join(rows) if rows else "| — | — | — | blocked | 00-runtime-metrics.md | findings ещё не перенесены |"
    sample = "| OPT-001 | P1 | db-orm | candidate | OPT-001-finding.md | подтвердить perfmon SQL count/time |"
    return text.replace(sample, replacement)


def build_finding(index: int, layer: str, date_value: str) -> str:
    finding_id = f"OPT-{index:03d}"
    text = read_template("finding.template.md")
    text = text.replace("OPT-001", finding_id)
    text = text.replace(
        "- Layer: component-cache / tagged-cache / composite / db-orm / frontend-assets / agents-imports / shop",
        f"- Layer: {layer}",
    )
    text = text.replace("- Verdict: candidate / confirmed / blocked / fixed / accepted-risk", "- Verdict: candidate")
    text = text.replace("- Owner:", f"- Owner:\n- Date: {date_value}")
    return text


def init_evidence(
    output: Path,
    finding_count: int,
    date_value: str,
    project: str,
    static_report: str,
    force: bool,
) -> None:
    output.mkdir(parents=True, exist_ok=True)
    write_file(output / "summary.md", build_summary(finding_count, date_value, project, static_report), force)
    write_file(output / "00-runtime-metrics.md", read_template("runtime-metrics.template.md"), force)
    if finding_count > 0:
        for index in range(1, finding_count + 1):
            layer = DEFAULT_LAYERS[(index - 1) % len(DEFAULT_LAYERS)]
            write_file(output / f"OPT-{index:03d}-finding.md", build_finding(index, layer, date_value), force)
    readme = "\n".join(
        [
            "# Optimization evidence pack",
            "",
            "Сгенерированный evidence pack для аудита оптимизаций Bitrix-проекта.",
            "Перед коммитом удали secrets, cookies, session ids, production XML/дампы, персональные данные и приватный HTML.",
            "",
            "Проверка:",
            "",
            f"```bash\npython3 scripts/validate_optimization_evidence.py {output}\n```",
            "",
        ]
    )
    write_file(output / "README.md", readme, force)

    # Do not overwrite a real static report. Create an empty placeholder only when requested name is absent.
    static_path = output / static_report
    if static_report and not static_path.exists():
        write_file(
            static_path,
            "# Static audit placeholder\n\nСюда можно положить вывод `scripts/bitrix_static_optimization_audit.py`.\n",
            force=False,
        )


def resolve_default_output(date_value: str) -> Path:
    return Path("evidence") / f"{date_value}-optimization-audit"


def main() -> int:
    parser = argparse.ArgumentParser(description="Initialize Bitrix optimization audit evidence pack")
    parser.add_argument("--output", type=Path, help="Output evidence directory")
    parser.add_argument("--date", default=dt.date.today().isoformat(), help="Date prefix, YYYY-MM-DD")
    parser.add_argument("--finding-count", type=int, default=5, help="Number of OPT finding files to create")
    parser.add_argument("--project", default="", help="Project/repo label for summary.md")
    parser.add_argument("--static-report", default="static-audit.md", help="Static audit report filename inside evidence pack")
    parser.add_argument("--force", action="store_true", help="Overwrite existing files")
    args = parser.parse_args()

    try:
        dt.date.fromisoformat(args.date)
    except ValueError:
        print(f"ERROR: --date must be YYYY-MM-DD, got: {args.date}", file=sys.stderr)
        return 2
    if args.finding_count < 0:
        print("ERROR: --finding-count must be >= 0", file=sys.stderr)
        return 2
    if "/" in args.static_report or "\\" in args.static_report:
        print("ERROR: --static-report must be a filename, not a path", file=sys.stderr)
        return 2

    output = args.output or resolve_default_output(args.date)
    try:
        init_evidence(output, args.finding_count, args.date, args.project, args.static_report, args.force)
    except Exception as exc:  # noqa: BLE001 - CLI should report concise error
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    print(f"Initialized optimization evidence pack: {output}")
    print("Fill summary.md/finding files, remove secrets, then run:")
    print(f"  python3 scripts/validate_optimization_evidence.py {output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
