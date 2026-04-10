#!/usr/bin/env bash
# install.sh — Install or update the Bitrix Agent Skill for Claude Code and Codex
# Usage:
#   bash install.sh
#   bash install.sh --claude
#   bash install.sh --codex
#   bash install.sh --both
#   bash install.sh --force --both
set -euo pipefail

REPO_CANDIDATES=(
  "Poliklot/bitrix-agent-skill"
  "Poliklot/claude-bitrix-skill"
)
BRANCH="master"

CLAUDE_INSTALL_DIR="${HOME}/.claude/skills/bitrix"
CODEX_HOME_DIR="${CODEX_HOME:-${HOME}/.codex}"
CODEX_INSTALL_DIR="${CODEX_HOME_DIR}/skills/bitrix"

FORCE=false
TARGET_MODE="auto"
SELECTED_REPO=""
REMOTE_VERSION=""

TARGET_NAMES=()
TARGET_DIRS=()

print_step()  { printf "\n\033[1;34m==>\033[0m %s\n" "$1"; }
print_ok()    { printf "  \033[1;32m✓\033[0m %s\n" "$1"; }
print_warn()  { printf "  \033[1;33m!\033[0m %s\n" "$1"; }
print_error() { printf "\n\033[1;31mError:\033[0m %s\n" "$1" >&2; }

usage() {
  cat <<'EOF'
Usage:
  bash install.sh [--force] [--auto|--claude|--codex|--both]

Flags:
  --auto    Install/update all detected homes (default)
  --claude  Install/update only ~/.claude/skills/bitrix
  --codex   Install/update only $CODEX_HOME/skills/bitrix or ~/.codex/skills/bitrix
  --both    Install/update both Claude and Codex copies
  --force   Reinstall even if the target is already up to date
EOF
}

for cmd in curl tar; do
  command -v "$cmd" >/dev/null 2>&1 || {
    print_error "'$cmd' is required but not installed."
    exit 1
  }
done

build_raw_url() {
  local repo="$1"
  local path="$2"
  printf 'https://raw.githubusercontent.com/%s/%s/%s' "$repo" "$BRANCH" "$path"
}

build_tarball_url() {
  local repo="$1"
  printf 'https://github.com/%s/archive/refs/heads/%s.tar.gz' "$repo" "$BRANCH"
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

add_target() {
  local name="$1"
  local dir="$2"
  TARGET_NAMES+=("$name")
  TARGET_DIRS+=("$dir")
}

detect_targets() {
  TARGET_NAMES=()
  TARGET_DIRS=()

  case "$TARGET_MODE" in
    auto)
      if [[ -d "${HOME}/.claude" ]]; then
        add_target "Claude" "$CLAUDE_INSTALL_DIR"
      fi
      if [[ -n "${CODEX_HOME:-}" || -d "${HOME}/.codex" ]]; then
        add_target "Codex" "$CODEX_INSTALL_DIR"
      fi
      if [[ "${#TARGET_NAMES[@]}" -eq 0 ]]; then
        print_warn "Claude/Codex homes were not detected. Defaulting to both install paths."
        add_target "Claude" "$CLAUDE_INSTALL_DIR"
        add_target "Codex" "$CODEX_INSTALL_DIR"
      fi
      ;;
    claude)
      add_target "Claude" "$CLAUDE_INSTALL_DIR"
      ;;
    codex)
      add_target "Codex" "$CODEX_INSTALL_DIR"
      ;;
    both)
      add_target "Claude" "$CLAUDE_INSTALL_DIR"
      add_target "Codex" "$CODEX_INSTALL_DIR"
      ;;
    *)
      print_error "Unknown target mode: $TARGET_MODE"
      exit 2
      ;;
  esac
}

read_installed_version() {
  local dir="$1"
  local version_file="${dir}/VERSION"

  if [[ -f "$version_file" ]]; then
    tr -d '[:space:]' < "$version_file"
  else
    echo ""
  fi
}

clear_install_dir() {
  local dir="$1"
  mkdir -p "$dir"
  find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
}

for arg in "$@"; do
  case "$arg" in
    --force)
      FORCE=true
      ;;
    --auto)
      TARGET_MODE="auto"
      ;;
    --claude)
      TARGET_MODE="claude"
      ;;
    --codex)
      TARGET_MODE="codex"
      ;;
    --both)
      TARGET_MODE="both"
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

print_step "Checking versions"

resolve_repo || {
  print_error "Could not fetch remote version from current or legacy repository slug."
  exit 1
}

print_ok "Resolved repository: ${SELECTED_REPO}"
print_ok "Remote version: ${REMOTE_VERSION}"

detect_targets

DOWNLOAD_REQUIRED=false

for i in "${!TARGET_NAMES[@]}"; do
  name="${TARGET_NAMES[$i]}"
  dir="${TARGET_DIRS[$i]}"
  local_version="$(read_installed_version "$dir")"

  if [[ -n "$local_version" ]]; then
    print_ok "${name}: installed ${local_version}"
  else
    print_warn "${name}: no installed version found"
  fi

  if [[ "$FORCE" == true || "$local_version" != "$REMOTE_VERSION" ]]; then
    DOWNLOAD_REQUIRED=true
  fi
done

if [[ "$DOWNLOAD_REQUIRED" == false ]]; then
  printf "\n\033[1;32mAlready up to date.\033[0m (%s)\n" "$REMOTE_VERSION"
  exit 0
fi

print_step "Downloading"

TMPDIR_WORK="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_WORK"' EXIT

curl -fsSL --retry 3 --retry-delay 2 "$(build_tarball_url "$SELECTED_REPO")" -o "${TMPDIR_WORK}/skill.tar.gz"
print_ok "Downloaded"

tar -xzf "${TMPDIR_WORK}/skill.tar.gz" -C "$TMPDIR_WORK"
EXTRACTED_DIR="$(find "$TMPDIR_WORK" -maxdepth 1 -mindepth 1 -type d | head -1)"
SKILL_SOURCE="${EXTRACTED_DIR}/bitrix"
[[ -d "$SKILL_SOURCE" ]] || {
  print_error "Unexpected tarball structure."
  exit 1
}
print_ok "Extracted"

for i in "${!TARGET_NAMES[@]}"; do
  name="${TARGET_NAMES[$i]}"
  dir="${TARGET_DIRS[$i]}"
  local_version="$(read_installed_version "$dir")"

  if [[ "$FORCE" == false && "$local_version" == "$REMOTE_VERSION" ]]; then
    print_ok "${name}: already up to date, skipping"
    continue
  fi

  if [[ -n "$local_version" && "$local_version" != "$REMOTE_VERSION" ]]; then
    print_step "${name}: updating ${local_version} -> ${REMOTE_VERSION}"
  else
    print_step "${name}: installing ${REMOTE_VERSION}"
  fi

  clear_install_dir "$dir"
  cp -R "$SKILL_SOURCE/." "$dir/"
  print_ok "${name}: files copied to ${dir}"

  installed_version="$(read_installed_version "$dir")"
  [[ "$installed_version" == "$REMOTE_VERSION" ]] || {
    print_error "${name}: version mismatch after install"
    exit 1
  }
done

printf "\n\033[1;32mSuccess!\033[0m Bitrix Agent Skill %s installed\n" "$REMOTE_VERSION"
printf "Targets:\n"
for i in "${!TARGET_NAMES[@]}"; do
  printf "  - %s: %s\n" "${TARGET_NAMES[$i]}" "${TARGET_DIRS[$i]}"
done
printf "Usage: /bitrix <your task>\n\n"
