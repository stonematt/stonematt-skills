import { expect, test } from 'claude-code/testing'

import { bandLine, goalOf, lastStatus, laneText, parseLink, summarize } from '../hooks/register'

const NOW = 1_000_000_000

test('parseLink reads one or several tickets', async () => {
  expect(parseLink('Lane C: #160 #161 (1/1) whole-run review')).toEqual({
    letter: 'C',
    issues: [160, 161],
    k: 1,
    total: 1,
    objective: 'whole-run review',
  })
  expect(parseLink('Spec axis review')).toBe(null)
})

test('lastStatus takes the last status line in a tail', async () => {
  const tail = '{"text":"swarm: ready-to-merge issue=1 pr=2"}\n{"text":"swarm: queue-done\\nbye"}'
  expect(lastStatus(tail)).toBe('queue-done')
  expect(lastStatus('nothing here')).toBe(undefined)
})

test('summarize folds links into one state per lane', async () => {
  const lanes = summarize(
    [
      { meta: { description: 'Lane A: #160 (1/2) safety', spawnDepth: 1, finished: true }, tail: 'swarm: queue-done', mtimeMs: NOW - 5000 },
      { meta: { description: 'Lane A: #162 (2/2) safety', spawnDepth: 1, finished: false }, tail: '', mtimeMs: NOW - 1000 },
      { meta: { description: 'Lane B: #161 (1/1) hardening', spawnDepth: 1, finished: true }, tail: 'swarm: escalation issue=161 reason=fence', mtimeMs: NOW },
      { meta: { description: 'Lane D: #160 (1/1) guard', spawnDepth: 1, finished: false }, tail: '', mtimeMs: NOW - 11 * 60_000 },
      { meta: { description: 'Lane E: #161 (1/1) query', spawnDepth: 1, finished: true }, tail: 'swarm: ready-to-merge issue=161 pr=9', mtimeMs: NOW },
      { meta: { description: 'Spec review', spawnDepth: 2, finished: true }, tail: '', mtimeMs: NOW },
    ],
    NOW,
  )
  expect(lanes.map(l => `${l.letter}:${l.state}:${l.k}`)).toEqual([
    'A:run:2',
    'B:esc:1',
    'D:stall:1',
    'E:merge:1',
  ])
  expect(laneText({ sessionId: 's', goal: 'g', lanes, lastAt: NOW })).toBe('0/4 A▸ B! D… E◆')
})

test('goalOf takes the run log title only for its own session', async () => {
  const log = '# Release-blocking fixes (spec #66)\n\n## Lanes\nSession: abc-1\n'
  expect(goalOf(log, 'abc-1')).toBe('Release-blocking fixes (spec #66)')
  expect(goalOf(log, 'other')).toBe(undefined)
})

test('bandLine keeps the counter and flags only lanes that need attention', async () => {
  const lane = (letter: string, state: 'done' | 'run' | 'stall' | 'esc', lastAt = NOW) => ({
    letter, issues: [1], objective: 'x', k: 1, total: 1, state, lastAt,
  })
  const s = {
    sessionId: 's',
    goal: 'Release-blocking fixes from the goal PR review (spec #66)',
    lastAt: NOW,
    lanes: [lane('A', 'done'), lane('B', 'esc'), lane('C', 'run'), lane('D', 'stall', NOW - 12 * 60_000)],
  }
  const line = bandLine(s, 80, NOW)
  expect(line.length).toBeLessThanOrEqual(80)
  expect(line.startsWith('Release-blocking')).toBe(true)
  expect(line.endsWith(' · 1/4 done · 2 running · B needs you · D stalled 12m')).toBe(true)
  expect(bandLine({ ...s, lanes: [lane('A', 'done')] }, 80, NOW)).toBe(`${s.goal} · 1/1 done`)
})
