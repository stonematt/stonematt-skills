# Graph Report - .  (2026-08-08)

## Corpus Check
- 82 files · ~53,696 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 342 nodes · 442 edges · 40 communities (15 shown, 25 thin omitted)
- Extraction: 87% EXTRACTED · 12% INFERRED · 0% AMBIGUOUS · INFERRED: 54 edges (avg confidence: 0.82)
- Token cost: 286,759 input · 0 output

## Community Hubs (Navigation)
- Release & Label Governance
- Merge & Preflight Gating
- Commit, Journal & Voice Skills
- Test Fixtures & Shims
- Distribution & Packaging ADRs
- Projects v2 Board Sync
- Test Assertion Library
- Journal Sweep Daemon
- Plugin Marketplace Manifest
- Pocock Gate Fixtures
- Pocock Board GraphQL Helper
- Release Script Tests
- Skill Validation Tests
- Skill Symlink Dogfooding
- Release Version Script
- claude.ai Zip Build Tests
- Journal Enrichment & Redaction
- Claude CLI Test Shim
- Version Check Script
- Pocock Smoke gh Shim
- Lock Contention Tests
- Plist Generation Tests
- Contextual Intent & Area Slots
- Installer Script
- claude.ai Zip Builder
- Skill Listing Script
- Skill Rename Script
- Test Runner Entry
- Journal Commit Script
- Journal Setup Script
- GitHub Board Shim
- GitHub Label Shim
- osascript Notification Shim
- Phase 0 Smoke Test
- Run-All Test Driver
- Test Config Harness
- Pocock Board Tests
- Pocock Gate Tests
- Install Surface Concept
- Role Translation Table

## God Nodes (most connected - your core abstractions)
1. `stone-adopt-pocock skill` - 15 edges
2. `stone-commit skill` - 13 edges
3. `stone-merge skill` - 11 edges
4. `pocock-acceptance-gate.sh script` - 10 edges
5. `stone-adopt-pocock skill` - 10 edges
6. `stone-journal skill` - 10 edges
7. `Workbench (v2-durability engine)` - 9 edges
8. `build_fixtures()` - 8 edges
9. `_ok()` - 8 edges
10. `_bad()` - 8 edges

## Surprising Connections (you probably didn't know these)
- `Namespace (stone- prefix)` --semantically_similar_to--> `Shared plugin.json skills array of direct paths`  [INFERRED] [semantically similar]
  CONTEXT.md → docs/adr/0003-publish-plugin-marketplace.md
- `F1 - shared-board PAT is the weakest link` --references--> `PROJECT_TOKEN secret`  [INFERRED]
  docs/wayfinder/adopt-pocock/non-software-flex-catalog.md → .github/workflows/clean-status-on-close.yml
- `code-explorer agent (roadmap sketch)` --conceptually_related_to--> `Plugin (Claude Code packaging unit)`  [AMBIGUOUS]
  docs/roadmap.md → CONTEXT.md
- `CLAUDE.md Agent skills block` --implements--> `Fixed spine across every surveyed repo`  [INFERRED]
  CLAUDE.md → docs/wayfinder/adopt-pocock/non-software-flex-catalog.md
- `Kill list: 2100 lines of bash demolished` --conceptually_related_to--> `pocock-board.sh -F to -f GraphQL binding fix`  [AMBIGUOUS]
  docs/briefs/adopt-pocock-wrapper.md → CHANGELOG.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Projects v2 CI sync flow (label to board projection)** — _github_workflows_project_sync, _github_workflows_clean_status_on_close, _github_workflows_clean_status_on_close_project_token, docs_agents_issue_tracker_kanban_board, docs_wayfinder_adopt_pocock_manual_walkthrough_friction_d4_ci_actions_port, docs_briefs_ci_workflow_templates_spec [EXTRACTED 1.00]
- **Cross-surface distribution model** — context_namespace, context_central_store, context_surface, readme_npx_skills_install, readme_plugin_marketplace_install, readme_claudeai_zip_upload, docs_adr_0002_distribute_via_skills_cli_with_stone_namespace_decision, docs_adr_0003_publish_plugin_marketplace_decision [EXTRACTED 1.00]
- **Adopt-Pocock durability mechanisms for the unseen v2** — docs_briefs_adopt_pocock_wrapper_workbench, docs_briefs_adopt_pocock_wrapper_feedback_loop, docs_briefs_adopt_pocock_wrapper_live_role_binding, docs_wayfinder_adopt_pocock_prototype_version_stamp_stamp_file, docs_briefs_adopt_pocock_wrapper_preflight_gate, docs_briefs_adopt_pocock_wrapper_behavioral_smoke, docs_briefs_adopt_pocock_wrapper_idempotent_delta_reconcile [INFERRED 0.85]
- **stone-adopt-pocock six-step adoption run** — skills_in_progress_stone_adopt_pocock_skill_stone_adopt_pocock, skills_in_progress_stone_adopt_pocock_references_preflight_preflight_gate, skills_in_progress_stone_adopt_pocock_references_setup_and_delta_setup_and_delta, skills_in_progress_stone_adopt_pocock_references_role_binding_live_role_binding, skills_in_progress_stone_adopt_pocock_references_pocock_stamp_template_pocock_stamp, skills_in_progress_stone_adopt_pocock_skill_behavioral_smoke, skills_in_progress_stone_adopt_pocock_references_workbench_workbench [EXTRACTED 1.00]
- **Stone git lifecycle: commit to PR to merge to release** — skills_engineering_stone_commit_skill_stone_commit, skills_engineering_stone_commit_skill_multi_ticket_detection, skills_engineering_stone_commit_skill_graph_refresh_at_pr, skills_engineering_stone_merge_skill_stone_merge, skills_engineering_stone_merge_skill_status_staged_labeling, skills_engineering_stone_merge_skill_prod_promotion_gate [EXTRACTED 1.00]
- **Stop-and-surface / anti-silent-success discipline** — skills_in_progress_stone_adopt_pocock_references_role_binding_stop_and_surface, skills_in_progress_stone_adopt_pocock_references_preflight_halt_on_first_gap, skills_engineering_stone_merge_skill_code_review_gate, skills_in_progress_stone_adopt_pocock_skill_behavioral_smoke, skills_engineering_stone_promote_settings_skill_two_phase_workflow [INFERRED 0.85]

## Communities (40 total, 25 thin omitted)

### Community 0 - "Release & Label Governance"
Cohesion: 0.05
Nodes (51): Closed-issue job guard, afk-ready renamed to canonical afk flag, pocock-board.sh -F to -f GraphQL binding fix, Release 0.2.0, Release 0.3.0, stone-commit multi-ticket Closes detection, stone-merge strips every upstream status lane, CLAUDE.md Agent skills block (+43 more)

### Community 1 - "Merge & Preflight Gating"
Cohesion: 0.06
Nodes (49): skills/deprecated bucket, Knowledge-graph refresh rides the PR, Multi-ticket linked-issue detection, Local branch and worktree cleanup after merge, Section 2.0 code-review preflight gate, One re-run for unrelated flake, then escalate, No graph refresh at merge time, Gated production promotion (+41 more)

### Community 2 - "Commit, Journal & Voice Skills"
Cohesion: 0.07
Nodes (32): skills/engineering bucket, Conventional Commits message format, Heredoc, never command substitution, Group changes by logical concern, not by staging, No Co-Authored-By / AI attribution trailers, Never stage sensitive files, stone-commit skill, Sync-before-push over force-push (+24 more)

### Community 3 - "Test Fixtures & Shims"
Cohesion: 0.08
Nodes (24): build_fixtures(), _entry(), _mkrepo(), _remote(), fixtures.sh script, test-detector.sh script, mkcfg(), PATH (+16 more)

### Community 4 - "Distribution & Packaging ADRs"
Cohesion: 0.12
Nodes (24): Release 0.1.0 (baseline), Bucket (taxonomy folder), Bundle (claude.ai zip), Central store (~/.agents/skills), Marketplace (marketplace.json catalog), Namespace (stone- prefix), Plugin (Claude Code packaging unit), Locked scope: seven stone-* skills (+16 more)

### Community 5 - "Projects v2 Board Sync"
Cohesion: 0.13
Nodes (23): clean-status-on-close workflow, PROJECT_TOKEN secret, Set project status to Released step, Remove kanban status labels step, project-sync workflow, Hardcoded Status option-id map (OPT), Kanban board and status projection, Wayfinding operations (GitHub-native maps and tickets) (+15 more)

### Community 6 - "Test Assertion Library"
Cohesion: 0.23
Nodes (17): assert_contains(), assert_eq(), assert_file(), assert_le(), assert_nofile(), assert_not_contains(), _bad(), finish() (+9 more)

### Community 7 - "Journal Sweep Daemon"
Cohesion: 0.22
Nodes (6): acquire_lock(), discover_to_queue(), emit(), main(), notify(), journal-sweep.sh script

### Community 8 - "Plugin Marketplace Manifest"
Cohesion: 0.25
Nodes (7): description, name, owner, email, name, plugins, $schema

### Community 9 - "Pocock Gate Fixtures"
Cohesion: 0.46
Nodes (7): build_pocock_gate_fixtures(), _gate_agent_docs(), _gate_claude(), _gate_golden_corpus(), _gate_golden_tracker(), _gate_stamp(), pocock-gate-fixtures.sh script

### Community 10 - "Pocock Board GraphQL Helper"
Cohesion: 0.48
Nodes (5): op_backfill(), op_labels(), op_status_field(), pocock-board.sh script, usage()

### Community 11 - "Release Script Tests"
Cohesion: 0.60
Nodes (3): bad(), ok(), release.test.sh script

### Community 12 - "Skill Validation Tests"
Cohesion: 0.60
Nodes (3): bad(), ok(), validate-skills.test.sh script

### Community 15 - "claude.ai Zip Build Tests"
Cohesion: 0.83
Nodes (3): bad(), ok(), build-claudeai-zip.test.sh script

### Community 17 - "Claude CLI Test Shim"
Cohesion: 0.83
Nodes (3): claude-shim script, _dec(), _inc()

## Ambiguous Edges - Review These
- `Plugin (Claude Code packaging unit)` → `code-explorer agent (roadmap sketch)`  [AMBIGUOUS]
  docs/roadmap.md · relation: conceptually_related_to
- `pocock-board.sh -F to -f GraphQL binding fix` → `Kill list: 2100 lines of bash demolished`  [AMBIGUOUS]
  docs/briefs/adopt-pocock-wrapper.md · relation: conceptually_related_to

## Knowledge Gaps
- **65 isolated node(s):** `$schema`, `name`, `description`, `name`, `email` (+60 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **25 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Plugin (Claude Code packaging unit)` and `code-explorer agent (roadmap sketch)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `pocock-board.sh -F to -f GraphQL binding fix` and `Kill list: 2100 lines of bash demolished`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `stone-adopt-pocock skill` connect `Release & Label Governance` to `Distribution & Packaging ADRs`, `Projects v2 Board Sync`?**
  _High betweenness centrality (0.047) - this node is a cross-community bridge._
- **Why does `Roadmap / Brief / Issue three-level hierarchy` connect `Distribution & Packaging ADRs` to `Release & Label Governance`?**
  _High betweenness centrality (0.030) - this node is a cross-community bridge._
- **What connects `$schema`, `name`, `description` to the rest of the system?**
  _65 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Release & Label Governance` be split into smaller, more focused modules?**
  _Cohesion score 0.05333333333333334 - nodes in this community are weakly interconnected._
- **Should `Merge & Preflight Gating` be split into smaller, more focused modules?**
  _Cohesion score 0.055272108843537414 - nodes in this community are weakly interconnected._