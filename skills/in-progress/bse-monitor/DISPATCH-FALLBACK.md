# Dispatch fallback

The recipe a `bse-monitor` subagent follows when the project has no `implement` skill. It covers the work from a fresh task branch to a reviewed commit; the dispatch brief adds the gates, the push and the PR.

1. Read the issue's acceptance criteria. Each one becomes a test, or a check you can run, before you write the code that meets it.
2. Build test-first. When a `tdd` skill is installed, read its `SKILL.md` and follow it; otherwise work red-green-refactor, one behaviour at a time.
3. Run the typecheck and the single test file you are working in after each change. Run the full test suite once at the end.
4. Review the diff against the issue. When a `code-review` skill is installed, read its `SKILL.md` and follow it; otherwise check every acceptance criterion against the diff, and check the diff against the repo's documented standards. Resolve each finding.
5. Commit to the task branch with the repo's commit convention.

**Done when** every acceptance criterion has a passing test or check, the review has no open finding, and the work is committed.
