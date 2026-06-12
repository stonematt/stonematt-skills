#!/usr/bin/env bash
set -euo pipefail

# Links all shipped skills in the repository to local filesystem-agent skill
# stores for dogfooding.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DESTS=("$HOME/.claude/skills" "$HOME/.agents/skills")

resolve_link() {
  local path="$1"
  local target

  target="$(readlink -f "$path" 2>/dev/null || readlink "$path")"
  case "$target" in
    /*) printf '%s\n' "$target" ;;
    *) printf '%s/%s\n' "$(cd "$(dirname "$path")" && pwd)" "$target" ;;
  esac
}

is_shipped_skill() {
  local name="$1"
  local shipped

  for shipped in "${SHIPPED_SKILLS[@]}"; do
    [ "$name" = "$shipped" ] && return 0
  done

  return 1
}

SHIPPED_SKILLS=()
SKILL_DIRS=()
while IFS= read -r -d '' skill_md; do
  src="$(dirname "$skill_md")"
  SKILL_DIRS+=("$src")
  SHIPPED_SKILLS+=("$(basename "$src")")
done < <(find "$REPO/skills" -name SKILL.md -not -path '*/node_modules/*' -not -path '*/deprecated/*' -not -path '*/in-progress/*' -print0)

for dest in "${DESTS[@]}"; do
  # If the destination is a symlink that resolves into this repo, we'd end up
  # writing the per-skill symlinks back into the repo's own skills/ tree.
  # Detect and bail out instead of polluting the working copy.
  if [ -L "$dest" ]; then
    resolved="$(resolve_link "$dest")"
    case "$resolved" in
      "$REPO"|"$REPO"/*)
        echo "error: $dest is a symlink into this repo ($resolved)." >&2
        echo "Remove it (rm \"$dest\") and re-run; the script will recreate it as a real dir." >&2
        exit 1
        ;;
    esac
  fi

  mkdir -p "$dest"

  for target in "$dest"/*; do
    [ -e "$target" ] || [ -L "$target" ] || continue
    [ -L "$target" ] || continue

    resolved="$(resolve_link "$target")"
    name="$(basename "$target")"
    case "$resolved" in
      "$REPO"|"$REPO"/*)
        if ! is_shipped_skill "$name"; then
          rm "$target"
          echo "removed stale $name -> $target"
        fi
        ;;
    esac
  done
done

for src in "${SKILL_DIRS[@]}"; do
  name="$(basename "$src")"

  for dest in "${DESTS[@]}"; do
    target="$dest/$name"

    if [ -e "$target" ] && [ ! -L "$target" ]; then
      rm -rf "$target"
    fi

    ln -sfn "$src" "$target"
    echo "linked $name -> $target"
  done
done
