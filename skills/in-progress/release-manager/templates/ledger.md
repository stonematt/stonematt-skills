# Release ledger template

The ledger is a GitHub issue titled `Release: <initiative>`, labelled `release`, linked from the spec and the goal PR. Its body is the template below. The release manager edits the body (`gh issue edit <n> --body-file`) each time a fact lands, and reads it again on every wake.

Keep it to facts: SHAs, URLs, issue links, check results and dates. A line is done only when the release manager has checked it, not when a session says so.

```markdown
# Release: <initiative>

Started <YYYY-MM-DD>. Matt: "<his words that started the release>"
Spec: <link> · goal PR: <link> · release PR: <link or none yet>
Integration branch `<dev>` · release branch `<main>` · ops worktree `<path>`
Manager session: <project> · <name>

## Gate

Each check that must pass before the release merge.

- [ ] Goal PR checks green at `<sha>`
- [ ] Review panel verdict: <ship | fix | rethink> — <comment link>
- [ ] Blocker <link> closed
- [ ] Release head equals a tested tree: `git diff --stat <tested-sha> <release-head>` empty
- [ ] Matt says go: "<his words>", <date>

## Go-live

Each step from the release merge to production verified. A step that changes production names its rollback.

- [ ] Merge release PR <link> at `<sha>`
- [ ] Deploy <what, where> · rollback: <exact command>
- [ ] Verify <URL>: <the checks: loads, endpoints answer 200, data age>
- [ ] Point <host or job> at the release branch · old state: <branch, HEAD> · rollback: <step>

## Sessions

| Name | Address | Brief | Touches | State |
|---|---|---|---|---|
| <name> | <project> · <name> | `<brief path>` | <files, branches, data, hosts> | running / reported <date> / done |

## Waits on Matt

Each item is the exact step or `!` command, with the SHA or host it needs.

- [ ] `! git push origin --delete <branch>` (branch at `<sha>`)
- [ ] <dashboard step, in his words>

## Decisions

- <YYYY-MM-DD> <what was decided, by whom, and why>

## Close

- [ ] Production verified: <URL, deployment id, result, date>
- [ ] Spec closed, or each open child named as deferred
- [ ] Product brief initiative line updated
- [ ] Status page written
- [ ] Every open item above is done, filed, or a Waits-on-Matt line
- [ ] Retro run over this ledger; lessons in `docs/product-lead/lessons.md`
```
