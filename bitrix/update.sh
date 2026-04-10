#!/usr/bin/env bash
# update.sh — Check or update the Bitrix Agent Skill for Claude Code and Codex
# Run from an installed copy, for example:
#   bash ~/.claude/skills/bitrix/update.sh
#   bash ~/.codex/skills/bitrix/update.sh
#   bash ~/.claude/skills/bitrix/update.sh --check
set -euo pipefail

REPO_CANDIDATES=(
  "Poliklot/bitrix-agent-skill"
  "Poliklot/claude-bitrix-skill"
)
BRANCH="master"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_VERSION_FILE="${SCRIPT_DIR}/VERSION"

FORCE=false
CHECK_ONLY=false
SELECTED_REPO=""
REMOTE_VERSION=""

usage() {
  cat <<'EOF'
Usage:
  bash ~/.claude/skills/bitrix/update.sh
  bash ~/.codex/skills/bitrix/update.sh
  bash ~/.claude/skills/bitrix/update.sh --force
  bash ~/.codex/skills/bitrix/update.sh --check
EOF
}

build_raw_url() {
  local repo="$1"
  local path="$2"
  printf 'https://raw.githubusercontent.com/%s/%s/%s' "$repo" "$BRANCH" "$path"
}

resolve_repo() {
  local repo=""
  local version=""

  for repo in "${REPO_CANDIDATES[@]}"; do
    if version="$(curl -fsSL --retry 3 --retry-delay 2 "$(build_raw_url "$repo" "bitrix/VERSION")" 2>/dev/null | tr -d '[:space:]')"; then
      if [[ -n "$version" ]]; then
        SELECTED_REPO="$repo"
        REMOTE_VERSION="$version"
        return 0
      fi
    fi
  done

  return 1
}

read_local_version() {
  if [[ -f "$LOCAL_VERSION_FILE" ]]; then
    tr -d '[:space:]' < "$LOCAL_VERSION_FILE"
  else
    echo ""
  fi
}

normalize_version() {
  local version="${1#v}"
  local major=0
  local minor=0
  local patch=0
  local IFS=.

  read -r major minor patch <<< "$version"
  printf '%05d%05d%05d' "${major:-0}" "${minor:-0}" "${patch:-0}"
}

version_gt() {
  [[ "$(normalize_version "$1")" > "$(normalize_version "$2")" ]]
}

detect_target_flag() {
  local codex_dir="${CODEX_HOME:-${HOME}/.codex}/skills/bitrix"
  local claude_dir="${HOME}/.claude/skills/bitrix"

  if [[ "$SCRIPT_DIR" == "$codex_dir" || "$SCRIPT_DIR" == *"/.codex/skills/bitrix"* ]]; then
    echo "--codex"
    return 0
  fi

  if [[ "$SCRIPT_DIR" == "$claude_dir" || "$SCRIPT_DIR" == *"/.claude/skills/bitrix"* ]]; then
    echo "--claude"
    return 0
  fi

  echo "--auto"
}

check_mode() {
  local local_version=""

  local_version="$(read_local_version)"
  if ! resolve_repo; then
    echo "CHECK_FAILED reason=remote_version_unavailable"
    return 0
  fi

  if [[ -z "$local_version" ]]; then
    echo "UPDATE_AVAILABLE local=none remote=${REMOTE_VERSION}"
    return 0
  fi

  if version_gt "$REMOTE_VERSION" "$local_version"; then
    echo "UPDATE_AVAILABLE local=${local_version} remote=${REMOTE_VERSION}"
    return 0
  fi

  echo "UP_TO_DATE version=${local_version}"
}

for arg in "$@"; do
  case "$arg" in
    --force)
      FORCE=true
      ;;
    --check)
      CHECK_ONLY=true
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

if [[ "$CHECK_ONLY" == true ]]; then
  check_mode
  exit 0
fi

echo "Checking versions"

resolve_repo || {
  echo "Error: Could not fetch remote version from current or legacy repository slug" >&2
  exit 1
}

LOCAL_VERSION="$(read_local_version)"

if [[ "$FORCE" == false ]]; then
  if [[ -n "$LOCAL_VERSION" && "$LOCAL_VERSION" == "$REMOTE_VERSION" ]]; then
    echo "Already up to date (${LOCAL_VERSION})"
    exit 0
  fi

  if [[ -n "$LOCAL_VERSION" ]] && version_gt "$LOCAL_VERSION" "$REMOTE_VERSION"; then
    echo "Installed version (${LOCAL_VERSION}) is newer than remote (${REMOTE_VERSION})"
    exit 0
  fi
fi

echo "Fetching latest installer from GitHub..."
INSTALL_SCRIPT_URL="$(build_raw_url "$SELECTED_REPO" "install.sh")"
SCRIPT="$(curl -fsSL --retry 3 --retry-delay 2 "$INSTALL_SCRIPT_URL")"
[[ -n "$SCRIPT" ]] || {
  echo "Error: Could not download install.sh" >&2
  exit 1
}

TARGET_FLAG="$(detect_target_flag)"

if [[ "$FORCE" == true ]]; then
  exec bash -c "$SCRIPT" -- "$TARGET_FLAG" --force
fi

exec bash -c "$SCRIPT" -- "$TARGET_FLAG"
