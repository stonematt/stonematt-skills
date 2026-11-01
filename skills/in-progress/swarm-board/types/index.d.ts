/**
 * A lane's state at summary level.
 * run: its agent is working. merge: it handed back ready to merge.
 * esc: it escalated. stall: running but silent over 10 minutes.
 * done: its agent finished with nothing pending.
 */
export type LaneState = 'run' | 'merge' | 'esc' | 'stall' | 'done'

export type LaneView = {
  letter: string
  issues: number[]
  objective: string
  /** The latest link's place in the lane's queue. */
  k: number
  total: number
  state: LaneState
  /** Epoch ms the lane's transcript last changed. */
  lastAt: number
}

export type Summary = {
  /** The run log title, else the session title, else its tickets. */
  goal: string
  sessionId: string
  lanes: LaneView[]
  lastAt: number
}

declare module 'claude-code' {
  interface PluginState {
    'swarm-board': { swarms: Shaped<Summary[]> }
  }
}
