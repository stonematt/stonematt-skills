#!/usr/bin/env bash
# log-summary.sh — summarize the /stone-merge run log for a retro.
#
# Prints the runs since a date as counts, then every run that stopped, was
# blocked, or merged with something worth a look (a denial, a rerun, a resolved
# conflict, a merge that ran in the main session), grouped by cause.
#
# Usage:
#   log-summary.sh [--since YYYY-MM-DD] [--repo owner/name]
#
# --since defaults to 30 days ago. Reads the same log log-run.sh writes:
#   ${XDG_STATE_HOME:-$HOME/.local/state}/stone-merge/runs.jsonl
# Override with STONE_MERGE_LOG. Read-only.

log_path="${STONE_MERGE_LOG:-${XDG_STATE_HOME:-$HOME/.local/state}/stone-merge/runs.jsonl}"
[ -f "$log_path" ] || { echo "no run log at $log_path"; exit 0; }

STONE_MERGE_LOG_PATH="$log_path" python3 - "$@" <<'PY'
import collections, datetime, json, os, re, sys

args = sys.argv[1:]
since = (datetime.date.today() - datetime.timedelta(days=30)).isoformat()
repo = None
i = 0
while i < len(args):
    if args[i] == "--since" and i + 1 < len(args):
        since = args[i + 1]; i += 2
    elif args[i] == "--repo" and i + 1 < len(args):
        repo = args[i + 1]; i += 2
    else:
        sys.exit(f"unknown argument: {args[i]}")

rows, bad = [], 0
for line in open(os.environ["STONE_MERGE_LOG_PATH"], encoding="utf-8"):
    try:
        r = json.loads(line)
    except ValueError:
        bad += 1
        continue
    if str(r.get("ts", ""))[:10] < since:
        continue
    if repo and r.get("repo") != repo:
        continue
    rows.append(r)

def val(r, k):
    v = str(r.get(k) or "").strip()
    return "" if v in ("", "none") else v

def cause(text):
    # Collapse run-specific detail so the same cause groups together.
    t = re.sub(r"#?\b\d+\b", "N", text)
    t = re.sub(r"\b[0-9a-f]{7,40}\b", "SHA", t)
    return re.sub(r"\s+", " ", t)[:110]

outcomes = collections.Counter(r.get("outcome") or "unknown" for r in rows)
print(f"stone-merge runs since {since}" + (f" in {repo}" if repo else ""))
print(f"  {len(rows)} rows: " + ", ".join(f"{n} {o}" for o, n in outcomes.most_common())
      + (f"; {bad} unreadable lines" if bad else ""))
merged = [r for r in rows if r.get("outcome") == "merged"]
if merged:
    where = collections.Counter(r.get("merged_from") or "unrecorded" for r in merged)
    print("  merged from: " + ", ".join(f"{n} {w}" for w, n in where.most_common()))
    gates = collections.Counter((r.get("gate") or "unrecorded") for r in merged)
    print("  gates: " + ", ".join(f"{n} {g}" for g, n in gates.most_common()))

groups = collections.defaultdict(list)
for r in rows:
    out = r.get("outcome") or "unknown"
    if out != "merged":
        text = val(r, "note") or val(r, "classifier") or f"checks={r.get('checks')} gate={r.get('gate')}"
        groups[(out, cause(text))].append(r)
        continue
    if val(r, "classifier"):
        groups[("merged, with a denial", cause(val(r, "classifier")))].append(r)
    if r.get("checks") in ("rerun-passed", "bypassed-local"):
        groups[("merged, checks " + r["checks"], cause(val(r, "note") or "-"))].append(r)
    if val(r, "conflicts"):
        groups[("merged, conflict resolved", cause(val(r, "conflicts")))].append(r)

if not groups:
    print("\nnothing stopped, blocked or flagged")
order = sorted(groups.items(), key=lambda kv: (kv[0][0], -len(kv[1])))
last_kind = None
for (kind, text), rs in order:
    if kind != last_kind:
        print(f"\n{kind}")
        last_kind = kind
    repos = collections.Counter(r.get("repo") or "?" for r in rs)
    latest = max(rs, key=lambda r: str(r.get("ts", "")))
    print(f"  {len(rs)}x  {text}")
    print(f"       repos: {', '.join(f'{k} ({n})' for k, n in repos.most_common(3))}"
          f"; latest {str(latest.get('ts',''))[:10]} {latest.get('repo','?')}#{latest.get('pr','?')}")
PY
