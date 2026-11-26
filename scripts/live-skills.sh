#!/usr/bin/env bash
set -euo pipefail

# Serve the installed skills from a worktree pinned to origin/dev, so a
# `git checkout` in the working copy never changes what running sessions load.
#
#   live-skills.sh                 create or update the live worktree, then point
#                                  every skill link that targets this repo at it
#   live-skills.sh --refresh       update the live worktree only (the post-merge hook)
#   live-skills.sh --checkout NAME point one skill at the working copy, to test a branch
#   live-skills.sh --status        show where each link points
#
# The live worktree is a detached HEAD at origin/dev:
#   ${STONE_SKILLS_LIVE:-$HOME/.local/share/stonematt-skills/live}
# A skill that is not on origin/dev yet keeps its link to the working copy.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
# From inside the live worktree, act on the main working copy.
REPO="$(dirname "$(git -C "$REPO" rev-parse --path-format=absolute --git-common-dir)")"
LIVE="${STONE_SKILLS_LIVE:-$HOME/.local/share/stonematt-skills/live}"
DESTS=("$HOME/.claude/skills" "$HOME/.agents/skills")
REF="${STONE_SKILLS_REF:-origin/dev}"

update_live() {
  if [ -e "$LIVE/.git" ]; then
    git -C "$LIVE" checkout -q --detach "$REF"
  else
    mkdir -p "$(dirname "$LIVE")"
    git -C "$REPO" worktree add -q --detach "$LIVE" "$REF"
  fi
}

install_hook() {
  local hook="$REPO/.git/hooks/post-merge"
  [ -e "$hook" ] && return 0
  cat > "$hook" <<'HOOK'
#!/usr/bin/env bash
# Installed by scripts/live-skills.sh: keep the live skills worktree at origin/dev.
s="$(git rev-parse --show-toplevel)/scripts/live-skills.sh"
[ -x "$s" ] && "$s" --refresh >/dev/null 2>&1
exit 0
HOOK
  chmod +x "$hook"
  echo "installed post-merge hook"
}

each_link() { # calls "$1" link target for every skill link into REPO or LIVE
  local fn="$1" dest link target
  for dest in "${DESTS[@]}"; do
    [ -d "$dest" ] || continue
    for link in "$dest"/*; do
      [ -L "$link" ] || continue
      target="$(readlink "$link")"
      case "$target" in
        "$REPO"/skills/*|"$LIVE"/skills/*) "$fn" "$link" "$target" ;;
      esac
    done
  done
}

to_live() {
  local link="$1" target="$2" rel
  case "$target" in "$LIVE"/*) return 0 ;; esac
  rel="${target#"$REPO"/}"
  if [ -f "$LIVE/$rel/SKILL.md" ] || [ -d "$LIVE/$rel" ]; then
    ln -sfn "$LIVE/$rel" "$link"
    echo "live      $(basename "$link")  ($link)"
  else
    echo "kept      $(basename "$link")  ($link): not on $REF yet"
  fi
}

show() {
  local link="$1" target="$2"
  case "$target" in
    "$LIVE"/*) echo "live      $(basename "$link")  ($link)" ;;
    *)         echo "checkout  $(basename "$link")  ($link)" ;;
  esac
}

case "${1:-}" in
  --refresh)
    [ -e "$LIVE/.git" ] && update_live
    ;;
  --status)
    each_link show
    [ -e "$LIVE/.git" ] && echo "live worktree at $(git -C "$LIVE" rev-parse --short HEAD) ($REF is $(git -C "$REPO" rev-parse --short "$REF"))"
    ;;
  --checkout)
    name="${2:?usage: live-skills.sh --checkout NAME}"
    src="$(find "$REPO/skills" -maxdepth 2 -type d -name "$name" -not -path '*/deprecated/*' | head -1)"
    [ -n "$src" ] || { echo "no skill named $name in the working copy" >&2; exit 1; }
    for dest in "${DESTS[@]}"; do
      [ -L "$dest/$name" ] && ln -sfn "$src" "$dest/$name" && echo "checkout  $name  ($dest/$name)"
    done
    echo "run scripts/live-skills.sh to put it back"
    ;;
  "")
    git -C "$REPO" fetch -q origin
    update_live
    install_hook
    each_link to_live
    echo "live worktree at $(git -C "$LIVE" rev-parse --short HEAD) ($REF)"
    ;;
  *)
    echo "unknown argument: $1" >&2; exit 1 ;;
esac
