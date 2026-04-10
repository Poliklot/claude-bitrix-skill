#!/usr/bin/env bash
# install.sh — Install or update the Bitrix Agent Skill for Claude Code and Codex
# Usage:
#   bash install.sh
#   bash install.sh --claude
#   bash install.sh --codex
#   bash install.sh --both
#   bash install.sh --version 1.5.1 --claude
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
REQUESTED_VERSION=""
SELECTED_REPO=""
REMOTE_VERSION=""
RELEASE_TAG=""
ARCHIVE_SOURCE=""

TARGET_NAMES=()
TARGET_DIRS=()

print_step()  { printf "\n\033[1;34m==>\033[0m %s\n" "$1"; }
print_ok()    { printf "  \033[1;32m✓\033[0m %s\n" "$1"; }
print_warn()  { printf "  \033[1;33m!\033[0m %s\n" "$1"; }
print_error() { printf "\n\033[1;31mError:\033[0m %s\n" "$1" >&2; }

usage() {
  cat <<'EOF'
Usage:
  bash install.sh [--force] [--auto|--claude|--codex|--both] [--version X.Y.Z]

Flags:
  --auto          Install/update all detected homes (default)
  --claude        Install/update only ~/.claude/skills/bitrix
  --codex         Install/update only $CODEX_HOME/skills/bitrix or ~/.codex/skills/bitrix
  --both          Install/update both Claude and Codex copies
  --version VER   Install a specific released version (example: 1.5.1 or v1.5.1)
  --force         Reinstall even if the target is already up to date
EOF
}

for cmd in curl tar; do
  command -v "$cmd" >/dev/null 2>&1 || {
    print_error "'$cmd' is required but not installed."
    exit 1
  }
done

normalize_version() {
  local version="${1#v}"
  printf '%s' "${version//[[:space:]]/}"
}

version_to_tag() {
  printf 'v%s' "$(normalize_version "$1")"
}

build_raw_url() {
  local repo="$1"
  local ref="$2"
  local path="$3"
  printf 'https://raw.githubusercontent.com/%s/%s/%s' "$repo" "$ref" "$path"
}

build_latest_release_url() {
  local repo="$1"
  printf 'https://github.com/%s/releases/latest' "$repo"
}

build_tag_archive_url() {
  local repo="$1"
  local tag="$2"
  printf 'https://github.com/%s/archive/refs/tags/%s.tar.gz' "$repo" "$tag"
}

build_branch_archive_url() {
  local repo="$1"
  printf 'https://github.com/%s/archive/refs/heads/%s.tar.gz' "$repo" "$BRANCH"
}

fetch_branch_version() {
  local repo="$1"
  curl -fsSL --retry 3 --retry-delay 2 "$(build_raw_url "$repo" "$BRANCH" "bitrix/VERSION")" 2>/dev/null | tr -d '[:space:]'
}

fetch_latest_release_tag() {
  local repo="$1"
  local effective_url=""

  effective_url="$(curl -fsSL -o /dev/null -w '%{url_effective}' "$(build_latest_release_url "$repo")" 2>/dev/null || true)"
  if [[ "$effective_url" == *"/releases/tag/"* ]]; then
    printf '%s' "${effective_url##*/}"
    return 0
  fi

  return 1
}

resolve_repo() {
  local repo=""
  local branch_version=""
  local latest_tag=""

  for repo in "${REPO_CANDIDATES[@]}"; do
    branch_version="$(fetch_branch_version "$repo" || true)"

    if [[ -n "$REQUESTED_VERSION" ]]; then
      if [[ -n "$branch_version" ]]; then
        SELECTED_REPO="$repo"
        REMOTE_VERSION="$(normalize_version "$REQUESTED_VERSION")"
        RELEASE_TAG="$(version_to_tag "$REQUESTED_VERSION")"
        return 0
      fi
      continue
    fi

    latest_tag="$(fetch_latest_release_tag "$repo" || true)"
    if [[ -n "$latest_tag" ]]; then
      SELECTED_REPO="$repo"
      RELEASE_TAG="$latest_tag"
      REMOTE_VERSION="$(normalize_version "$latest_tag")"
      return 0
    fi

    if [[ -n "$branch_version" ]]; then
      SELECTED_REPO="$repo"
      REMOTE_VERSION="$branch_version"
      RELEASE_TAG="$(version_to_tag "$branch_version")"
      return 0
    fi
  done

  return 1
}

download_archive() {
  local output_path="$1"
  local tag_url=""
  local branch_url=""

  if [[ -n "$RELEASE_TAG" ]]; then
    tag_url="$(build_tag_archive_url "$SELECTED_REPO" "$RELEASE_TAG")"
    if curl -fsSL --retry 3 --retry-delay 2 "$tag_url" -o "$output_path"; then
      ARCHIVE_SOURCE="release:${RELEASE_TAG}"
      return 0
    fi

    if [[ -n "$REQUESTED_VERSION" ]]; then
      print_error "Could not download release archive ${RELEASE_TAG} from ${SELECTED_REPO}."
      return 1
    fi

    print_warn "Could not download release archive ${RELEASE_TAG}. Falling back to ${BRANCH}."
  fi

  branch_url="$(build_branch_archive_url "$SELECTED_REPO")"
  curl -fsSL --retry 3 --retry-delay 2 "$branch_url" -o "$output_path"
  ARCHIVE_SOURCE="branch:${BRANCH}"
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

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE=true
      shift
      ;;
    --auto)
      TARGET_MODE="auto"
      shift
      ;;
    --claude)
      TARGET_MODE="claude"
      shift
      ;;
    --codex)
      TARGET_MODE="codex"
      shift
      ;;
    --both)
      TARGET_MODE="both"
      shift
      ;;
    --version)
      [[ "$#" -ge 2 ]] || {
        print_error "--version requires a value."
        exit 2
      }
      REQUESTED_VERSION="$(normalize_version "$2")"
      shift 2
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
  print_error "Could not resolve repository or target version."
  exit 1
}

print_ok "Resolved repository: ${SELECTED_REPO}"
print_ok "Target version: ${REMOTE_VERSION}"
if [[ -n "$RELEASE_TAG" ]]; then
  print_ok "Preferred release tag: ${RELEASE_TAG}"
fi

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

download_archive "${TMPDIR_WORK}/skill.tar.gz"
print_ok "Downloaded from ${ARCHIVE_SOURCE}"

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
printf "Source: %s\n" "$ARCHIVE_SOURCE"
printf "Usage: /bitrix <your task>\n\n"
