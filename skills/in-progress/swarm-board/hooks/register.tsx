import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { LaneState, LaneView, Summary } from '../types'

const PANE = 'swarm-board'
const TITLE = 'Swarm'
const POLL_MS = 20_000
const STALL_MS = 10 * 60_000
/** A swarm whose lanes have been quiet this long is over; hide it. */
const ACTIVE_MS = 30 * 60_000
/** Sessions whose main transcript changed within this window are candidates. */
const RECENT_MS = 12 * 60 * 60_000
const TAIL_BYTES = 65_536

const swarms = atom(
  { plugin: 'swarm-board', key: 'swarms' } as const,
  [] as Summary[],
  { shape: 'swarms-1' },
)

const GLYPH: Record<LaneState, string> = {
  run: '▸',
  merge: '◆',
  esc: '!',
  stall: '…',
  done: '✓',
}

/** `Lane <X>: #<n> [#<m>…] (<k>/<total>) <objective>`, per swarm step 4. */
const LINK_RE = /^Lane\s+([A-Za-z]+):\s*((?:#\d+\s*)+)\((\d+)\/(\d+)\)\s*(.*)$/
const STATUS_RE = /swarm:\s*(ready-to-merge|escalation|queue-done)\b/g

export type Meta = { description?: string; spawnDepth?: number; finished?: boolean }

export const parseLink = (description: string) => {
  const m = LINK_RE.exec(description.trim())
  if (!m) return null

  return {
    letter: (m[1] ?? '').toUpperCase(),
    issues: [...(m[2] ?? '').matchAll(/#(\d+)/g)].map(x => Number(x[1])),
    k: Number(m[3]),
    total: Number(m[4]),
    objective: (m[5] ?? '').trim(),
  }
}

/** The last status line kind in a transcript's tail, if any. */
export const lastStatus = (tail: string): string | undefined => {
  let kind: string | undefined
  for (const m of tail.matchAll(STATUS_RE)) kind = m[1]

  return kind
}

export type AgentFile = { meta: Meta; tail: string; mtimeMs: number }

/** Folds a session's lane agents into one view per lane letter. */

const cut = (text: string, width: number): string =>
  text.length <= width ? text : text.slice(0, Math.max(1, width - 1)) + '…'

/**
 * Lane done, per swarm-console CONTRACT.md "Done": with a Lanes block (`ticked`
 * given), only a lane the orchestrator ticked is done; a finished link of an
 * unticked lane is between links, so the lane still runs. Without one, a
 * finished link with no pending status line is done.
 */
export const summarize = (agents: AgentFile[], now: number, ticked?: Set<string>): LaneView[] => {
  const latest = new Map<string, LaneView>()
  for (const a of agents) {
    if ((a.meta.spawnDepth ?? 1) !== 1) continue
    const link = parseLink(a.meta.description ?? '')
    if (!link) continue
    const status = lastStatus(a.tail)
    let state: LaneState
    if (!a.meta.finished) state = now - a.mtimeMs > STALL_MS ? 'stall' : 'run'
    else if (status === 'escalation') state = 'esc'
    else if (status === 'ready-to-merge') state = 'merge'
    else if (ticked && !ticked.has(link.letter)) state = 'run'
    else state = 'done'
    const view: LaneView = { ...link, state, lastAt: a.mtimeMs }
    const old = latest.get(link.letter)
    if (!old || view.k > old.k || (view.k === old.k && view.lastAt > old.lastAt)) {
      latest.set(link.letter, view)
    }
  }

  return [...latest.values()].sort((x, y) => x.letter.localeCompare(y.letter))
}

/** `4/5 A✓ B✓ C✓ D▸ E✓`: lanes done out of lanes, then each lane's state. */
export const laneText = (s: Summary): string => {
  const done = s.lanes.filter(l => l.state === 'done').length

  return `${done}/${s.lanes.length} ${s.lanes.map(l => l.letter + GLYPH[l.state]).join(' ')}`
}

export type Flag = { text: string; color: 'red' | 'yellow' }

/**
 * One row as parts: the goal, cut so the rest always fits; `4/5 done · 2
 * running`; then a flag for each lane waiting on the owner or stalled.
 */
export const bandParts = (s: Summary, width: number, now: number) => {
  const done = s.lanes.filter(l => l.state === 'done').length
  const running = s.lanes.filter(l => l.state === 'run' || l.state === 'stall').length
  const counts = `${done}/${s.lanes.length} done${running > 0 ? ` · ${running} running` : ''}`
  const flags: Flag[] = []
  for (const l of s.lanes) {
    if (l.state === 'esc') flags.push({ text: `${l.letter} needs you`, color: 'red' })
    if (l.state === 'stall') {
      flags.push({ text: `${l.letter} stalled ${ago(now - l.lastAt)}`, color: 'yellow' })
    }
  }
  const tail = flags.reduce((n, f) => n + f.text.length + 3, 0)
  const room = width - counts.length - tail - 3
  const goal = room >= 8 ? cut(s.goal, room) : ''

  return { goal, counts, flags }
}

/** The band row as plain text, as `bandParts` lays it out. */
export const bandLine = (s: Summary, width: number, now: number): string => {
  const p = bandParts(s, width, now)

  return [p.goal, p.counts, ...p.flags.map(f => f.text)].filter(Boolean).join(' · ')
}

/** The goal from a run log: its `# ` title, when it names `Session: <id>`. */
export const goalOf = (log: string, sessionId: string): string | undefined => {
  if (!log.includes(`Session: ${sessionId}`)) return undefined
  const m = /^#\s+(.+)$/m.exec(log)

  return m?.[1]?.trim()
}

/** The lane letters ticked `- [x] Lane <X>` in a run log's `## Lanes` block; undefined when it has none. */
export const ticksOf = (log: string): Set<string> | undefined => {
  const sec = (log.split(/^## Lanes\s*$/m)[1] ?? '').split(/^## /m)[0] ?? ''
  const lines = [...sec.matchAll(/^- (?:\[( |x)\] )?Lane\s+([A-Za-z]+)\b/gm)]
  if (lines.length === 0) return undefined

  return new Set(lines.filter(m => m[1] === 'x').map(m => (m[2] ?? '').toUpperCase()))
}

const ago = (ms: number): string => {
  const min = Math.floor(ms / 60_000)
  if (min < 1) return 'now'
  if (min < 60) return `${min}m`

  return `${Math.floor(min / 60)}h`
}


// Module caches, reset on reload. File reads keyed by path, refreshed when
// the file's size or mtime changes.
const tails = new Map<string, { size: number; text: string }>()
const metas = new Map<string, { mtimeMs: number; meta: Meta }>()
const logs = new Map<string, { mtimeMs: number; text: string }>()
const titles = new Map<string, { size: number; title?: string }>()
let home: string | undefined
let slug: string | undefined

async function locate($: EngineInterface) {
  if (home && slug) return true
  home = await $.env.get('HOME')
  const cwd = await $.session.cwd()
  const git = await $.process.run([
    'git', '-C', cwd, 'rev-parse', '--path-format=absolute', '--git-common-dir',
  ])
  const common = git.exitCode === 0 ? git.stdout.trim() : ''
  const root = common ? common.replace(/\/\.git\/?$/, '') : cwd
  slug = root.replace(/[^a-zA-Z0-9]/g, '-')

  return Boolean(home)
}

async function tailOf($: EngineInterface, path: string, size: number) {
  const hit = tails.get(path)
  if (hit && hit.size === size) return hit.text
  const run = await $.process.run(['tail', '-c', String(TAIL_BYTES), path])
  const text = run.exitCode === 0 ? run.stdout : ''
  tails.set(path, { size, text })

  return text
}

async function metaOf($: EngineInterface, path: string, mtimeMs: number) {
  const hit = metas.get(path)
  if (hit && hit.mtimeMs === mtimeMs) return hit.meta
  let meta: Meta = {}
  try {
    meta = JSON.parse(await $.fs.read(path)) as Meta
  } catch {
    meta = {}
  }
  metas.set(path, { mtimeMs, meta })

  return meta
}

/** The session's own title (`customTitle`), the goal when no run log names it. */
async function titleOf($: EngineInterface, path: string, size: number) {
  const hit = titles.get(path)
  if (hit && hit.size === size) return hit.title
  const run = await $.process.run(['grep', '-o', '"customTitle":"[^"]*"', path])
  const last = run.stdout.trim().split('\n').pop() ?? ''
  const title = /"customTitle":"([^"]*)"/.exec(last)?.[1]
  titles.set(path, { size, title })

  return title
}

/** The goal of each session that a recent run log names. */
async function runGoals($: EngineInterface, now: number) {
  const dir = `${home}/.claude/skill-workbench/swarm/runs`
  const goals = new Map<string, string>()
  const ticks = new Map<string, Set<string>>()
  let entries
  try {
    entries = await $.fs.list(dir)
  } catch {
    return { goals, ticks }
  }
  for (const e of entries) {
    if (e.kind !== 'file' || !e.name.endsWith('.md') || now - e.mtimeMs > RECENT_MS) continue
    const path = `${dir}/${e.name}`
    let hit = logs.get(path)
    if (!hit || hit.mtimeMs !== e.mtimeMs) {
      hit = { mtimeMs: e.mtimeMs, text: await $.fs.read(path) }
      logs.set(path, hit)
    }
    const id = /^Session:\s*(\S+)/m.exec(hit.text)?.[1]
    const goal = id ? goalOf(hit.text, id) : undefined
    if (id && goal) goals.set(id, goal)
    const t = id ? ticksOf(hit.text) : undefined
    if (id && t) ticks.set(id, t)
  }

  return { goals, ticks }
}

/** Every swarm in this repo with a lane active in the last 30 minutes. */
async function scan($: EngineInterface): Promise<Summary[]> {
  if (!(await locate($)) || !home || !slug) return []
  const projectsDir = `${home}/.claude/projects`
  const now = await $.clock.now()
  const projects = (await $.fs.list(projectsDir)).filter(
    d => d.kind === 'dir' && (d.name === slug || d.name.startsWith(`${slug}--claude-worktrees-`)),
  )
  const candidates: { dir: string; id: string; mtimeMs: number; size: number }[] = []
  for (const p of projects) {
    const pd = `${projectsDir}/${p.name}`
    for (const f of await $.fs.list(pd)) {
      if (f.kind === 'file' && f.name.endsWith('.jsonl') && now - f.mtimeMs < RECENT_MS) {
        const id = f.name.slice(0, -'.jsonl'.length)
        candidates.push({ dir: `${pd}/${id}`, id, mtimeMs: f.mtimeMs, size: f.size })
      }
    }
  }
  candidates.sort((a, b) => b.mtimeMs - a.mtimeMs)

  const { goals, ticks } = await runGoals($, now)
  const found: Summary[] = []
  for (const c of candidates.slice(0, 16)) {
    const sub = `${c.dir}/subagents`
    let entries
    try {
      entries = await $.fs.list(sub)
    } catch {
      continue
    }
    const files = new Map(entries.map(e => [e.name, e]))
    const agents: AgentFile[] = []
    for (const e of entries) {
      if (!e.name.endsWith('.meta.json')) continue
      const meta = await metaOf($, `${sub}/${e.name}`, e.mtimeMs)
      if ((meta.spawnDepth ?? 1) !== 1 || !parseLink(meta.description ?? '')) continue
      const log = files.get(e.name.replace(/\.meta\.json$/, '.jsonl'))
      const mtimeMs = log?.mtimeMs ?? e.mtimeMs
      const tail = log && meta.finished ? await tailOf($, `${sub}/${log.name}`, log.size) : ''
      agents.push({ meta, tail, mtimeMs })
    }
    if (agents.length === 0) continue
    const lanes = summarize(agents, now, ticks.get(c.id))
    const lastAt = Math.max(...lanes.map(l => l.lastAt))
    const isLive = lanes.some(l => l.state === 'run' || l.state === 'stall')
    if (!isLive && now - lastAt > ACTIVE_MS) continue
    const goal =
      goals.get(c.id) ??
      (await titleOf($, `${c.dir}.jsonl`, c.size)) ??
      [...new Set(lanes.flatMap(l => l.issues))].map(n => `#${n}`).join(' ')
    found.push({ sessionId: c.id, goal, lanes, lastAt })
  }

  return found.sort((a, b) => b.lastAt - a.lastAt)
}

async function refresh($: EngineInterface) {
  let next: Summary[] = []
  try {
    next = await scan($)
  } catch (err) {
    $.ui.log(`swarm-board scan failed: ${String(err)}`)
  }
  await update($, swarms, () => next)
}

/** One swarm as one line: goal dim, counts plain, flags bold in their color. */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const row = (Text: any, s: Summary, width: number, now: number, more = 0) => {
  const p = bandParts(s, width, now)

  return (
    <Text>
      {p.goal !== '' && <Text dimColor>{p.goal} · </Text>}
      <Text>{p.counts}</Text>
      {p.flags.map(f => (
        <Text>
          <Text dimColor> · </Text>
          <Text bold color={f.color}>
            {f.text}
          </Text>
        </Text>
      ))}
      {more > 0 && <Text dimColor> +{more}</Text>}
    </Text>
  )
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'swarm-board',
      description: 'Show the active swarms, one line each',
      argumentHint: '[close|reload]',
      immediate: true,
    })
    void refresh($)
    $.clock.every(POLL_MS, () => void refresh($))
    // Stall ages move with the time, not only with new scans.
    $.clock.every(60_000, () => $.ui.invalidate('ui.render'))

    return next(e)
  })

  // `/swarm-board` opens the pane; `close` closes it; `reload` rescans now.
  on('command.run', { command: 'swarm-board' }, async ($, e) => {
    const verb = e.args.trim().toLowerCase()
    if (verb === 'close') {
      await $.ui.close({ id: PANE })

      return { text: 'Swarm pane closed.' }
    }
    await refresh($)
    if (verb === 'reload') return { text: 'Swarm board reloaded.' }
    await $.ui.open({ id: PANE, title: TITLE, closeOnEscape: true })

    return { text: 'Swarm pane opened.' }
  })

  // One row per active swarm above the prompt; nothing when none is active.
  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const list = await read($, swarms)
    if (list.length === 0 || e.props.hasSurvey) return next(e)
    const { Box, Text } = $.ui.resolve(e)
    const width = Math.max(30, (e.viewport?.columns ?? 80) - 2)
    const rows = Math.max(1, Math.min(list.length, e.props.maxRows - 1))
    const shown = list.slice(0, rows)
    const more = list.length - shown.length
    const now = await $.clock.now()

    return (
      <Box flexDirection="column">
        {shown.map((s, i) => {
          const isLast = i === rows - 1 && more > 0

          return row(Text, s, width - (isLast ? 6 : 0), now, isLast ? more : 0)
        })}
      </Box>
    )
  })

  // The same one line per swarm as the band; lane detail lives in swarm-console.
  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text } = $.ui.resolve(e)
    const list = await read($, swarms)
    const width = Math.max(20, e.props.bodyColumns ?? 40)
    if (list.length === 0) return <Text dimColor>No active swarm in this repo.</Text>
    const now = await $.clock.now()

    return <Box flexDirection="column">{list.map(s => row(Text, s, width, now))}</Box>
  })
}
