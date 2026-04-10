#!/usr/bin/env bash
# uninstall.sh — Remove the installed Bitrix Agent Skill copy
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ASSUME_YES=false

usage() {
  cat <<'EOF'
Usage:
  bash ~/.claude/skills/bitrix/uninstall.sh
  bash ~/.codex/skills/bitrix/uninstall.sh
  bash ~/.claude/skills/bitrix/uninstall.sh --yes
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --yes|-y)
      ASSUME_YES=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$ASSUME_YES" == false ]]; then
  printf 'Удалить Bitrix Agent Skill из %s? [y/N] ' "$SCRIPT_DIR"
  read -r answer
  case "${answer:-}" in
    y|Y|yes|YES)
      ;;
    *)
      echo "Отменено."
      exit 0
      ;;
  esac
fi

TARGET_DIR="$SCRIPT_DIR"
PARENT_DIR="$(dirname "$TARGET_DIR")"
BASE_NAME="$(basename "$TARGET_DIR")"

cd "$PARENT_DIR"
rm -rf "$BASE_NAME"

echo "Готово: навык удалён из ${TARGET_DIR}"
