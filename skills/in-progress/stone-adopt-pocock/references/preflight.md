# Preflight — read-only readiness gate

The first step of `stone-adopt-pocock`. You (the model) inspect the environment,
then either pass through to setup or **halt on the first unmet precondition** with
the exact copy-paste fix. Matt fixes one thing in his own shell and re-invokes.

Spec: [`docs/briefs/adopt-pocock-wrapper.md`](../../../../docs/briefs/adopt-pocock-wrapper.md)
— "Preflight is a read-only readiness gate."

## Invariants (non-negotiable)

- **Preflight NEVER mutates the machine or credentials.** Reads only. No
  `gh auth refresh`, no `gh auth login`, no `git` state changes, no file writes,
  no `mkdir`, no label/board creation. Every command below is an inspection. The
  fixes are things you *print for Matt to run himself* — you never run them.
- **Halt on the first gap.** One gap → emit its exact fix and stop. No silent
  degrade, no half-run, no "I'll work around it." Matt runs the fix in his own
  shell (so scope/PAT changes stay in his history) and re-invokes the skill.
- **The `project` scope check is conditional.** Label-only is the portable default
  and needs no `project` scope. Only require `project` scope when Matt has opted
  the board **in** (see the board opt-in question, asked near preflight). Skip the
  scope check entirely for a label-only or trackerless-local adoption.
- **All-green passes through.** When every applicable check is green, proceed to
  the setup step — invoke `setup-matt-pocock-skills`. Do not re-prompt.

## The checks

Run each probe. On a green result, continue to the next. On a red result, print
the paired fix verbatim inside a fenced block, state that preflight is halting,
and stop.

### 1. `gh` auth state (+ `project` scope, board-only)

**Probe:**

```bash
gh auth status
```

- **Not logged in** (`gh auth status` reports no accounts / exits non-zero) → halt:

  ```bash
  gh auth login
  ```

- **Logged in but board opted in AND `project` scope absent** — inspect the scope
  line in the same `gh auth status` output (the `Token scopes:` list):

  ```bash
  gh auth status | grep -i 'token scopes'
  ```

  If `project` is not among the listed scopes, halt with the exact refresh:

  ```bash
  gh auth refresh -s project
  ```

  Skip this sub-check for a label-only / trackerless adoption — `project` scope is
  irrelevant there and its absence is not a gap.

### 2. Pocock suite installed at `~/.agents/skills`

`~/.agents/skills` is the canonical install location for Matt Pocock's suite. The
wrapper calls `setup-matt-pocock-skills` from there; without it there is nothing
to wrap.

**Probe:**

```bash
test -d ~/.agents/skills && echo present || echo missing
```

- **Missing** → halt. Install the suite via Pocock's installer, then re-invoke:

  ```bash
  npx skillsetup@latest
  ```

  (If Matt installs the suite by another route, he installs it his way — the fix
  is "install the suite to `~/.agents/skills`," and preflight stops until it exists.
  Do not create the directory or fake a suite yourself.)

### 3. `origin` remote present

Adoption wires a tracker-backed repo against its GitHub origin (labels, board,
smoke issue). No origin → nothing to adopt against.

**Probe:**

```bash
git remote get-url origin
```

- **No origin** (`git remote get-url origin` exits non-zero) → halt:

  ```bash
  git remote add origin git@github.com:<owner>/<repo>.git
  ```

  Matt substitutes the real `<owner>/<repo>`; preflight does not guess it.

### 4. Repo state clean enough to proceed

Adoption writes durable config and drives a behavioral smoke; a dirty tree risks
tangling Matt's in-flight edits with the wrapper's mutations. The tree should be
clean (or clean enough that Matt knowingly proceeds).

**Probe:**

```bash
git status --porcelain
```

- **Non-empty output** (uncommitted changes) → halt. Let Matt clear the tree his
  way — commit or stash — then re-invoke:

  ```bash
  git stash --include-untracked   # or: git commit -am "wip" — Matt's call
  ```

  Do not stash, commit, or discard anything yourself. Surface the dirty paths from
  the `git status --porcelain` output so Matt sees exactly what is outstanding.

## Pass-through

When checks 1–4 are green (with check 1's `project` sub-check applied only under
board opt-in), preflight is satisfied. Proceed to the setup step: invoke
`setup-matt-pocock-skills`. Report a one-line "preflight green" so the run is
legible, then continue — no extra prompt.
