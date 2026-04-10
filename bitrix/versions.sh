#!/usr/bin/env bash
# versions.sh — List available Bitrix Agent Skill releases
set -euo pipefail

REPO_CANDIDATES=(
  "Poliklot/bitrix-agent-skill"
  "Poliklot/claude-bitrix-skill"
)

command -v curl >/dev/null 2>&1 || {
  echo "Error: curl is required but not installed." >&2
  exit 1
}

command -v python3 >/dev/null 2>&1 || {
  echo "Error: python3 is required to list releases." >&2
  exit 1
}

resolve_repo() {
  local repo=""

  for repo in "${REPO_CANDIDATES[@]}"; do
    if curl -fsSL -o /dev/null "https://github.com/${repo}" 2>/dev/null; then
      printf '%s' "$repo"
      return 0
    fi
  done

  return 1
}

REPO="$(resolve_repo || true)"
[[ -n "$REPO" ]] || {
  echo "Error: could not resolve repository." >&2
  exit 1
}

JSON="$(curl -fsSL --retry 3 --retry-delay 2 "https://api.github.com/repos/${REPO}/releases?per_page=15")"

python3 - "$REPO" <<'PY' <<<"$JSON"
import json
import sys

repo = sys.argv[1]

try:
    releases = json.load(sys.stdin)
except json.JSONDecodeError as exc:
    raise SystemExit(f"Error: could not parse release list: {exc}")

if not isinstance(releases, list) or not releases:
    raise SystemExit("No releases found.")

print(f"Available releases for {repo}:")
for index, release in enumerate(releases):
    tag = release.get("tag_name", "").strip()
    if not tag:
        continue
    published = (release.get("published_at") or release.get("created_at") or "")[:10]
    suffix = " [latest]" if index == 0 else ""
    if published:
        print(f"  - {tag} ({published}){suffix}")
    else:
        print(f"  - {tag}{suffix}")

print()
print("Examples:")
print("  bash ~/.claude/skills/bitrix/update.sh --version 1.5.0")
print("  bash ~/.codex/skills/bitrix/update.sh --version 1.5.0")
PY
