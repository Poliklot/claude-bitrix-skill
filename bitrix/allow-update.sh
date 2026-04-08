#!/usr/bin/env bash
# allow-update.sh — Enable global permission for running the Bitrix skill updater
set -euo pipefail

SETTINGS_FILE="${CLAUDE_SETTINGS_FILE:-${HOME}/.claude/settings.json}"
RULE="Bash(bash ~/.claude/skills/bitrix/update.sh:*)"

command -v python3 >/dev/null 2>&1 || {
  echo "Ошибка: требуется python3 для обновления ${SETTINGS_FILE}" >&2
  exit 1
}

mkdir -p "$(dirname "$SETTINGS_FILE")"

python3 - "$SETTINGS_FILE" "$RULE" <<'PY'
import json
import os
import sys

settings_file = sys.argv[1]
rule = sys.argv[2]

data = {}
if os.path.exists(settings_file):
    with open(settings_file, "r", encoding="utf-8") as fh:
        raw = fh.read().strip()
        if raw:
            data = json.loads(raw)

if not isinstance(data, dict):
    raise SystemExit(f"Ошибка: {settings_file} должен содержать JSON-объект")

permissions = data.setdefault("permissions", {})
if not isinstance(permissions, dict):
    raise SystemExit("Ошибка: поле permissions должно быть объектом")

allow = permissions.setdefault("allow", [])
if not isinstance(allow, list):
    raise SystemExit("Ошибка: поле permissions.allow должно быть массивом")

changed = False
if rule not in allow:
    allow.append(rule)
    changed = True

with open(settings_file, "w", encoding="utf-8") as fh:
    json.dump(data, fh, ensure_ascii=False, indent=2)
    fh.write("\n")

print("updated" if changed else "already_present")
PY

echo "Готово: разрешение для update.sh записано в ${SETTINGS_FILE}"
