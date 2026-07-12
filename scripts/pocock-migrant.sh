#!/usr/bin/env bash
#
# pocock-migrant — the adopt-Pocock wrapper's version-stamp freshness + migrant
# path + drift-audit seam.
#
# The version stamp gives the fast current-vs-migrant decision; the slug-scan is
# the belt-and-suspenders that catches a repo migrated WITHOUT a stamp. On a
# migrant verdict this parses the repo's `pocock-stamp.md`, diffs its light
# whole-catalog map + bindings against the *installed* suite, and emits a dated
# drift report — grouped renamed/merged · contract-changed · added · removed ·
# bindings-shifted · stale-refs — that hands off to the migrant flow.
#
# Ordering is load-bearing (brief: Migrant scope = both halves, in order):
#   1. reconcile config first — issue-tracker / triage-labels / domain docs.
#   2. THEN the wrapping-layer rewrite — stale-ref + CONTRACT rewrite of prose.
# Audit-only misses the config seam; find-and-replace misses the contract half
# (old shape runs silently under a new name). The report echoes both, in order.
#
# Detection is NOT duplicated here: freshness comes from the pocock-plan emitter
# (the single detection authority). This seam parses the stamp and computes the
# drift diff — the parts the plan does not carry.
#
# Usage:
#   pocock-migrant.sh [--root DIR] [--json]
#
#   --root DIR   repo root to inspect (default: cwd)
#   --json       emit the machine-readable migrant plan + drift; write nothing
#
# Default (no --json): writes docs/agents/pocock-drift-<date>.md on a migrant
# verdict and echoes a session summary. `current` is a near-noop (no drift file).
#
# Determinism knobs (tests):
#   POCOCK_INSTALLED_CATALOG  path to the installed-suite JSON (catalog+bindings+
#                             version+contract_changed). Real runs read
#                             ~/.agents/skills; absent => version-only diff.
#   POCOCK_INSTALLED_VERSION  installed suite version (drift math; plan reads it
#                             too). Overridden by the catalog JSON's `version`.
#   POCOCK_DRIFT_DATE         drift-report date + filename stamp (default: today).

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ROOT="$PWD"
JSON=0

while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift ;;
    --json) JSON=1 ;;
    -h|--help) sed -n '2,44p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

STAMP="$ROOT/docs/agents/pocock-stamp.md"
CATALOG_JSON="${POCOCK_INSTALLED_CATALOG:-}"
DRIFT_DATE="${POCOCK_DRIFT_DATE:-$(date +%F)}"

# ---- freshness (consume the emitter — single detection authority) ----------

PLAN="$(bash "$SELF_DIR/pocock-plan.sh" --dry-run --json --root "$ROOT" 2>/dev/null)" || {
  echo "pocock-migrant: could not obtain a plan from pocock-plan.sh" >&2
  exit 2
}

plan_scalar() { # key -> value (strings only; null renders empty)
  printf '%s\n' "$PLAN" | grep -oE "\"$1\": (\"[^\"]*\"|null)" | head -1 \
    | sed -E 's/^"[^"]*": //; s/^"//; s/"$//; s/^null$//'
}

FRESHNESS="$(plan_scalar freshness)"

# stale slugs off the plan (the belt-and-suspenders that flags migrant with no
# stamp). Rendered inline "[]" when empty; else one quoted string per line.
plan_stale_slugs() {
  printf '%s\n' "$PLAN" | awk '
    /"stale_slugs": \[\]/ { next }
    /"stale_slugs": \[/   { grab=1; next }
    grab && /\]/          { grab=0; next }
    grab {
      gsub(/^[[:space:]]*"/, ""); gsub(/",?[[:space:]]*$/, "")
      if (length) print
    }'
}

# ---- stamp parse (AC: version, source, catalog-light map, bindings) --------
# Hand-rolled frontmatter walk (no PyYAML in this env). Catalog list items are
# `name|dmi=..|activated=..`; bindings are `role: skill`. Emits typed records.
stamp_records() {
  [ -f "$STAMP" ] || return 0
  awk '
    /^---[[:space:]]*$/ { d++; next }
    d != 1 { next }
    /^version:/  { sub(/^version:[[:space:]]*/, "");  print "VERSION\t" $0; next }
    /^source:/   { sub(/^source:[[:space:]]*/, "");   print "SOURCE\t" $0;  next }
    /^suite:/    { sub(/^suite:[[:space:]]*/, "");     print "SUITE\t" $0;   next }
    /^catalog:/  { mode="cat";  next }
    /^bindings:/ { mode="bind"; next }
    /^[A-Za-z]/  { mode=""; next }
    mode == "cat" && /^[[:space:]]*-[[:space:]]/ {
      s=$0; sub(/^[[:space:]]*-[[:space:]]*/, "", s); sub(/\|.*/, "", s)
      if (length(s)) print "CATALOG\t" s; next
    }
    mode == "bind" && /^[[:space:]]+[A-Za-z]/ {
      s=$0; sub(/^[[:space:]]+/, "", s)
      k=s; sub(/:.*/, "", k)
      v=s; sub(/^[^:]*:[[:space:]]*/, "", v)
      if (length(k) && length(v)) print "BIND\t" k "\t" v; next
    }
  ' "$STAMP"
}

RECORDS="$(stamp_records)"
STAMP_VERSION="$(printf '%s\n' "$RECORDS" | awk -F'\t' '$1=="VERSION"{print $2; exit}')"
STAMP_SOURCE="$(printf '%s\n' "$RECORDS" | awk -F'\t' '$1=="SOURCE"{print $2; exit}')"
stamp_catalog()  { printf '%s\n' "$RECORDS" | awk -F'\t' '$1=="CATALOG"{print $2}' | sort -u; }
stamp_bindings() { printf '%s\n' "$RECORDS" | awk -F'\t' '$1=="BIND"{print $2" "$3}' | sort; }

# ---- installed suite (injected JSON; real runs read ~/.agents/skills) ------

inst_json() { # python-expr over the catalog JSON, empty when no file
  [ -n "$CATALOG_JSON" ] && [ -f "$CATALOG_JSON" ] || return 0
  python3 -c "$1" "$CATALOG_JSON" 2>/dev/null
}
inst_version()   { inst_json 'import json,sys;print(json.load(open(sys.argv[1])).get("version",""))'; }
inst_catalog()   { inst_json 'import json,sys;print("\n".join(c["name"] for c in json.load(open(sys.argv[1])).get("catalog",[])))' | sort -u; }
inst_bindings()  { inst_json 'import json,sys;
d=json.load(open(sys.argv[1])).get("bindings",{})
print("\n".join(f"{k} {v}" for k,v in d.items()))' | sort; }
inst_contract()  { inst_json 'import json,sys;print("\n".join(json.load(open(sys.argv[1])).get("contract_changed",[])))'; }

INSTALLED_VERSION="$(inst_version)"
[ -n "$INSTALLED_VERSION" ] || INSTALLED_VERSION="${POCOCK_INSTALLED_VERSION:-}"

# ---- drift diff ------------------------------------------------------------
# added/removed from the catalog map; bindings-shifted from the binding map;
# renamed/merged derived where a shifted role's old skill left and new arrived;
# contract-changed from the changelog-declared class; stale-refs from the plan.

_added()   { comm -13 <(stamp_catalog) <(inst_catalog); }   # installed-only
_removed() { comm -23 <(stamp_catalog) <(inst_catalog); }   # stamp-only

_bindings_shifted() { # "role: old -> new" where the bound skill changed
  awk 'FNR==NR { s[$1]=$2; next }
       ($1 in s) && s[$1] != $2 { print $1 ": " s[$1] " -> " $2 }' \
    <(stamp_bindings) <(inst_bindings)
}

# renamed/merged: a shifted binding whose OLD skill was removed and NEW added is
# the same skill under a new name (rename) or folded into a sibling (merge).
_renamed_merged() {
  local added removed
  added="$(_added)"; removed="$(_removed)"
  _bindings_shifted | while IFS= read -r line; do
    [ -n "$line" ] || continue
    local old new
    old="${line#*: }"; old="${old%% -> *}"
    new="${line##* -> }"
    if printf '%s\n' "$removed" | grep -qxF "$old" \
       && printf '%s\n' "$added" | grep -qxF "$new"; then
      printf '%s -> %s\n' "$old" "$new"
    fi
  done
}

# ---- render helpers --------------------------------------------------------

# Markdown bullet list from stdin; "- (none)" when empty.
md_bullets() {
  local any=0 line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf -- '- %s\n' "$line"; any=1
  done
  [ "$any" -eq 1 ] || printf -- '- (none)\n'
}

# JSON string array from stdin lines at indent `pad`.
json_array() { # pad
  local pad="$1"; local -a items=(); local line
  while IFS= read -r line; do [ -n "$line" ] && items+=("$line"); done
  if [ "${#items[@]}" -eq 0 ]; then printf '[]'; return; fi
  printf '[\n'
  local i=1 n="${#items[@]}"
  for line in "${items[@]}"; do
    # escape backslashes and quotes for JSON safety
    line="${line//\\/\\\\}"; line="${line//\"/\\\"}"
    if [ "$i" -lt "$n" ]; then printf '%s  "%s",\n' "$pad" "$line"
    else                       printf '%s  "%s"\n'  "$pad" "$line"; fi
    i=$((i+1))
  done
  printf '%s]' "$pad"
}

json_str_or_null() { [ -n "$1" ] && printf '"%s"' "$1" || printf 'null'; }

# ---- current: near-noop, no drift file -------------------------------------

if [ "$FRESHNESS" = "current" ]; then
  if [ "$JSON" -eq 1 ]; then
    printf '{\n'
    printf '  "freshness": "current",\n'
    printf '  "action": "patch",\n'
    printf '  "stamp": {\n'
    printf '    "version": %s,\n'  "$(json_str_or_null "$STAMP_VERSION")"
    printf '    "source": %s,\n'   "$(json_str_or_null "$STAMP_SOURCE")"
    printf '    "catalog": %s,\n'  "$(stamp_catalog  | json_array '    ')"
    printf '    "bindings": %s\n'  "$(stamp_bindings | json_array '    ')"
    printf '  },\n'
    printf '  "installed_version": %s,\n' "$(json_str_or_null "$INSTALLED_VERSION")"
    printf '  "steps": [\n    "patch-overlay"\n  ],\n'
    printf '  "drift_report": null\n'
    printf '}\n'
  else
    printf 'pocock-migrant: current (stamp %s == installed %s) — near-noop patch, no drift.\n' \
      "${STAMP_VERSION:-none}" "${INSTALLED_VERSION:-unknown}"
    printf 'Trust cached bindings; patch only the user overlay. No migration needed.\n'
  fi
  exit 0
fi

# ---- greenfield: not this seam's job ---------------------------------------

if [ "$FRESHNESS" = "greenfield" ]; then
  echo "pocock-migrant: plan freshness=greenfield — run pocock-apply (greenfield scaffold), not the migrant seam" >&2
  exit 3
fi

# ---- migrant: compute drift, emit report -----------------------------------

ADDED="$(_added)"
REMOVED="$(_removed)"
BINDINGS_SHIFTED="$(_bindings_shifted)"
RENAMED_MERGED="$(_renamed_merged)"
CONTRACT_CHANGED="$(inst_contract)"
STALE_REFS="$(plan_stale_slugs)"

if [ "$JSON" -eq 1 ]; then
  printf '{\n'
  printf '  "freshness": "migrant",\n'
  printf '  "action": "migrant",\n'
  printf '  "stamp": {\n'
  printf '    "version": %s,\n'  "$(json_str_or_null "$STAMP_VERSION")"
  printf '    "source": %s,\n'   "$(json_str_or_null "$STAMP_SOURCE")"
  printf '    "catalog": %s,\n'  "$(stamp_catalog  | json_array '    ')"
  printf '    "bindings": %s\n'  "$(stamp_bindings | json_array '    ')"
  printf '  },\n'
  printf '  "installed_version": %s,\n' "$(json_str_or_null "$INSTALLED_VERSION")"
  # The migrant flow, in order — config first, wrapping layer second.
  printf '  "steps": [\n    "reconcile-config",\n    "wrapping-layer-rewrite"\n  ],\n'
  printf '  "drift": {\n'
  printf '    "renamed_merged": %s,\n'   "$(printf '%s\n' "$RENAMED_MERGED"   | json_array '    ')"
  printf '    "contract_changed": %s,\n' "$(printf '%s\n' "$CONTRACT_CHANGED" | json_array '    ')"
  printf '    "added": %s,\n'            "$(printf '%s\n' "$ADDED"            | json_array '    ')"
  printf '    "removed": %s,\n'          "$(printf '%s\n' "$REMOVED"          | json_array '    ')"
  printf '    "bindings_shifted": %s,\n' "$(printf '%s\n' "$BINDINGS_SHIFTED" | json_array '    ')"
  printf '    "stale_refs": %s\n'        "$(printf '%s\n' "$STALE_REFS"       | json_array '    ')"
  printf '  },\n'
  printf '  "drift_report": "docs/agents/pocock-drift-%s.md"\n' "$DRIFT_DATE"
  printf '}\n'
  exit 0
fi

# Default: write the dated drift report + session echo.
mkdir -p "$ROOT/docs/agents"
REPORT="$ROOT/docs/agents/pocock-drift-$DRIFT_DATE.md"

{
  printf -- '---\n'
  printf 'kind: pocock-drift\n'
  printf 'date: %s\n' "$DRIFT_DATE"
  printf 'from_version: %s\n' "${STAMP_VERSION:-none}"
  printf 'to_version: %s\n' "${INSTALLED_VERSION:-unknown}"
  printf 'freshness: migrant\n'
  printf -- '---\n\n'
  printf '# Pocock drift report — %s\n\n' "$DRIFT_DATE"
  printf 'Suite drift from stamped `%s` to installed `%s`. Migration runs\n' \
    "${STAMP_VERSION:-none}" "${INSTALLED_VERSION:-unknown}"
  printf 'config-first, then the wrapping-layer rewrite; this report hands off to\n'
  printf 'that flow. A "map that built successfully" is not proof of correct wiring.\n\n'
  printf '## Migrant flow (ordered)\n\n'
  printf '1. **Reconcile config first** — `docs/agents/{issue-tracker,triage-labels,domain}.md`\n'
  printf '   to the installed suite. Audit-only misses this config seam.\n'
  printf '2. **Then the wrapping-layer rewrite** — stale-ref **+ contract** rewrite of\n'
  printf '   `CLAUDE.md` / `AGENTS.md` / prose. Find-and-replace misses the contract half.\n\n'
  printf '## Drift\n\n'
  printf '### Renamed / merged\n\n';   printf '%s\n' "$RENAMED_MERGED"   | md_bullets; printf '\n'
  printf '### Contract-changed\n\n';   printf '%s\n' "$CONTRACT_CHANGED" | md_bullets; printf '\n'
  printf '### Added\n\n';              printf '%s\n' "$ADDED"            | md_bullets; printf '\n'
  printf '### Removed\n\n';            printf '%s\n' "$REMOVED"          | md_bullets; printf '\n'
  printf '### Bindings-shifted\n\n';   printf '%s\n' "$BINDINGS_SHIFTED" | md_bullets; printf '\n'
  printf '### Stale refs (wrapping layer)\n\n'; printf '%s\n' "$STALE_REFS" | md_bullets; printf '\n'
} > "$REPORT"

printf 'pocock-migrant: migrant (stamp %s -> installed %s) — drift report written.\n' \
  "${STAMP_VERSION:-none}" "${INSTALLED_VERSION:-unknown}"
printf '  wrote  docs/agents/pocock-drift-%s.md\n' "$DRIFT_DATE"
printf 'Migrant flow (in order):\n'
printf '  1. reconcile config first (issue-tracker / triage-labels / domain)\n'
printf '  2. then wrapping-layer rewrite (stale-ref + contract)\n'
printf 'Drift groups: renamed/merged, contract-changed, added, removed, bindings-shifted, stale-refs.\n'
