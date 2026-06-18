#!/usr/bin/env bash
set -uo pipefail

# Structural health checks for the skill pack. This is a lightweight pre-merge
# gate: it validates naming, bucket indexes, top-level index, installer manifest,
# and link scope.
#
# Run: ./scripts/test/validate-skills.test.sh

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"

pass=0
fail=0
ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL: %s\n   %s\n' "$1" "$2"; fail=$((fail+1)); }

skill_paths=()
shipped_skill_dirs=()
while IFS= read -r -d '' skill_md; do
  skill_paths+=("$skill_md")
done < <(find "$repo/skills" -name SKILL.md -not -path '*/node_modules/*' -print0 | sort -z)

[ "${#skill_paths[@]}" -gt 0 ] \
  && ok "found skill manifests" \
  || bad "found skill manifests" "no SKILL.md files found under skills/"

for skill_md in "${skill_paths[@]}"; do
  skill_dir="$(dirname "$skill_md")"
  skill_name="$(basename "$skill_dir")"
  bucket_dir="$(dirname "$skill_dir")"
  bucket="$(basename "$bucket_dir")"
  bucket_readme="$bucket_dir/README.md"
  rel_skill_md="${skill_md#$repo/}"

  frontmatter_name="$(awk '
    NR == 1 && $0 != "---" { exit 1 }
    NR > 1 && $0 == "---" { exit }
    NR > 1 && $1 == "name:" { print $2; exit }
  ' "$skill_md")"

  [ -n "$frontmatter_name" ] \
    && ok "$rel_skill_md declares name" \
    || bad "$rel_skill_md declares name" "missing name: in frontmatter"

  [ "$frontmatter_name" = "$skill_name" ] \
    && ok "$skill_name name matches folder" \
    || bad "$skill_name name matches folder" "frontmatter name is '$frontmatter_name'"

  case "$skill_name" in
    stone-*) ok "$skill_name uses stone namespace" ;;
    *) bad "$skill_name uses stone namespace" "all shipped skills should be stone-*" ;;
  esac

  if [ "$bucket" != "deprecated" ] && [ "$bucket" != "in-progress" ]; then
    shipped_skill_dirs+=("./skills/$bucket/$skill_name")

    if [ -f "$bucket_readme" ] && grep -Fq "[$skill_name](./$skill_name/SKILL.md)" "$bucket_readme"; then
      ok "$skill_name listed in $bucket README"
    else
      bad "$skill_name listed in $bucket README" "missing [$skill_name](./$skill_name/SKILL.md)"
    fi

    top_level_link="./skills/$bucket/$skill_name/SKILL.md"
    if grep -Fq "[$skill_name]($top_level_link)" "$repo/README.md"; then
      ok "$skill_name listed in top-level README"
    else
      bad "$skill_name listed in top-level README" "missing [$skill_name]($top_level_link)"
    fi
  fi
done

plugin_manifest="$repo/.claude-plugin/plugin.json"
if [ -f "$plugin_manifest" ]; then
  ok "installer manifest exists"
else
  bad "installer manifest exists" "missing .claude-plugin/plugin.json"
fi

manifest_name="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("name",""))' "$plugin_manifest" 2>/dev/null)"
if [ "$manifest_name" = "stonematt-skills" ]; then
  ok "installer manifest name is stonematt-skills"
else
  bad "installer manifest name is stonematt-skills" "found '$manifest_name'"
fi

manifest_skills="$(python3 -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1])).get("skills",[])))' "$plugin_manifest" 2>/dev/null | sort)"
expected_skills="$(printf '%s\n' "${shipped_skill_dirs[@]}" | sort)"
if [ "$manifest_skills" = "$expected_skills" ]; then
  ok "installer manifest matches shipped skills"
else
  bad "installer manifest matches shipped skills" "expected manifest skills to match non-deprecated, non-in-progress skills"
fi

marketplace_manifest="$repo/.claude-plugin/marketplace.json"
if [ -f "$marketplace_manifest" ]; then
  ok "marketplace manifest exists"
else
  bad "marketplace manifest exists" "missing .claude-plugin/marketplace.json"
fi

mkt_name="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("name",""))' "$marketplace_manifest" 2>/dev/null)"
if [ "$mkt_name" = "stonematt-skills" ]; then
  ok "marketplace manifest name is stonematt-skills"
else
  bad "marketplace manifest name is stonematt-skills" "found '$mkt_name'"
fi

mkt_plugin="$(python3 -c 'import json,sys; ps=json.load(open(sys.argv[1])).get("plugins",[]); print(ps[0].get("name","") if len(ps)==1 else "")' "$marketplace_manifest" 2>/dev/null)"
if [ "$mkt_plugin" = "stonematt-skills" ]; then
  ok "marketplace lists the stonematt-skills plugin"
else
  bad "marketplace lists the stonematt-skills plugin" "expected exactly one plugin named stonematt-skills"
fi

mkt_source="$(python3 -c 'import json,sys; ps=json.load(open(sys.argv[1])).get("plugins",[]); print(ps[0].get("source","") if ps else "")' "$marketplace_manifest" 2>/dev/null)"
if [ "$mkt_source" = "./" ]; then
  ok "marketplace plugin source is repo root"
else
  bad "marketplace plugin source is repo root" "expected source './', found '$mkt_source'"
fi

if grep -Fq -- "-not -path '*/deprecated/*'" "$repo/scripts/link-skills.sh" \
  && grep -Fq -- "-not -path '*/in-progress/*'" "$repo/scripts/link-skills.sh"; then
  ok "link-skills excludes deprecated and in-progress"
else
  bad "link-skills excludes deprecated and in-progress" "expected both exclusion filters"
fi

if grep -q -- "personal" "$repo/scripts/link-skills.sh"; then
  bad "link-skills keeps personal included" "personal should not be explicitly excluded"
else
  ok "link-skills keeps personal included"
fi

if grep -Fq -- '$HOME/.claude/skills' "$repo/scripts/link-skills.sh" \
  && grep -Fq -- '$HOME/.agents/skills' "$repo/scripts/link-skills.sh"; then
  ok "link-skills targets Claude and Codex stores"
else
  bad "link-skills targets Claude and Codex stores" "expected ~/.claude/skills and ~/.agents/skills"
fi

if [ "${#shipped_skill_dirs[@]}" -gt 0 ]; then
  tmp_home="$(mktemp -d)"
  cleanup_tmp_home() { rm -rf "$tmp_home"; }
  trap cleanup_tmp_home EXIT

  mkdir -p "$tmp_home/.claude/skills" "$tmp_home/.agents/skills" "$tmp_home/outside"
  ln -s "$repo/skills/removed/stone-stale" "$tmp_home/.claude/skills/stone-stale"
  ln -s "$tmp_home/outside" "$tmp_home/.claude/skills/foreign-link"
  mkdir -p "$tmp_home/.claude/skills/real-skill"

  if HOME="$tmp_home" "$repo/scripts/link-skills.sh" >/dev/null; then
    first_skill="$(basename "${shipped_skill_dirs[0]}")"

    if [ ! -L "$tmp_home/.claude/skills/stone-stale" ] \
      && [ -L "$tmp_home/.claude/skills/foreign-link" ] \
      && [ -d "$tmp_home/.claude/skills/real-skill" ] \
      && [ -L "$tmp_home/.claude/skills/$first_skill" ] \
      && [ -L "$tmp_home/.agents/skills/$first_skill" ]; then
      ok "link-skills prunes stale repo symlinks only"
    else
      bad "link-skills prunes stale repo symlinks only" "expected stale repo symlink removed, unrelated entries preserved, and current skills linked"
    fi
  else
    bad "link-skills prunes stale repo symlinks only" "link-skills failed under temporary HOME"
  fi
fi

echo
printf 'skill validation tests: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
