#!/usr/bin/env node
// Swarm console server for one repo: serves swarm-console.html and that repo's swarm state as JSON.
//
//   node swarm-console.mjs [--project <repo-path>] [--port 4186] [--runs <dir>]   start, or reuse this repo's console
//   node swarm-console.mjs --stop [--project <repo-path>]                          stop this repo's console
//
// Both print what they did and the link. --project defaults to the current directory; any worktree of the
// repo names the same console. Reads, never writes: Claude session transcripts under ~/.claude/projects,
// swarm run logs in --runs (default ~/.claude/skill-workbench/swarm/runs), `gh pr list` and the origin remote.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import http from 'node:http';
import { execFile, execFileSync } from 'node:child_process';

const argv = process.argv.join(' ');
const PORT = Number((argv.match(/--port (\d+)/) ?? [])[1] ?? 4186);
// Ports tried in order until one is free or already serves this repo. 4190 is skipped: Safari refuses it.
const PORTS = Array.from({ length: 14 }, (_, i) => PORT + i).filter(p => p !== 4190);
const PROJECTS = path.join(os.homedir(), '.claude/projects');
const RUNS = (argv.match(/--runs (\S+)/) ?? [])[1] ?? path.join(os.homedir(), '.claude/skill-workbench/swarm/runs');
const PAGE = new URL('./swarm-console.html', import.meta.url);

// Claude names a project folder after its path, every non-alphanumeric turned into -.
const slugOf = p => p.replace(/[^a-zA-Z0-9]/g, '-');
const HOME_SLUG = slugOf(os.homedir()) + '-';
// The repo's main checkout, resolved through git's common dir so any worktree names the same repo.
function repoRoot(dir) {
  try { return path.dirname(execFileSync('git', ['-C', dir, 'rev-parse', '--path-format=absolute', '--git-common-dir'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim()); }
  catch { return path.resolve(dir); }
}
const ROOT = repoRoot((argv.match(/--project (\S+)/) ?? [])[1] ?? process.cwd());
const PROJECT = slugOf(ROOT);
// The main checkout's folder, or a session started inside one of its .claude/worktrees.
const inProject = dir => dir === PROJECT || dir.startsWith(PROJECT + '--claude-worktrees-');

function readJson(f) { try { return JSON.parse(fs.readFileSync(f, 'utf8')); } catch { return {}; } }

// A resumed session is a new transcript that starts with a copy of the old one, message uuids and all.
// The first uuid is the run's key: every session that shares it is the same run.
const roots = new Map();
function rootOf(file) {
  if (roots.has(file)) return roots.get(file);
  let r = null;
  try {
    const fd = fs.openSync(file, 'r'), buf = Buffer.alloc(65536);
    r = (buf.toString('utf8', 0, fs.readSync(fd, buf, 0, buf.length, 0)).match(/"uuid":"([^"]+)"/) ?? [])[1] ?? null;
    fs.closeSync(fd);
  } catch {}
  if (r) roots.set(file, r);
  return r;
}

// This repo's runs that spawned subagents, newest first. A run resumed into new sessions is one entry,
// named by its newest session; `members` holds every session folder of the run, oldest first.
function listSessions() {
  const runs = new Map();
  for (const p of fs.readdirSync(PROJECTS).filter(inProject)) {
    const pd = path.join(PROJECTS, p);
    if (!fs.statSync(pd).isDirectory()) continue;
    for (const n of fs.readdirSync(pd).filter(n => n.endsWith('.jsonl'))) {
      const s = n.slice(0, -6), dir = path.join(pd, s), sub = path.join(dir, 'subagents');
      const metas = fs.existsSync(sub) ? fs.readdirSync(sub).filter(n => n.endsWith('.meta.json')).map(n => ({ id: n.replace(/^agent-|\.meta\.json$/g, ''), ...readJson(path.join(sub, n)) })) : [];
      const mtime = Math.max(fs.statSync(dir + '.jsonl').mtimeMs, metas.length ? fs.statSync(sub).mtimeMs : 0);
      const key = rootOf(dir + '.jsonl') ?? s;
      const run = runs.get(key) ?? { members: [], metas: new Map(), project: p.startsWith(HOME_SLUG) ? p.slice(HOME_SLUG.length) : p };
      run.members.push({ id: s, dir, mtime });
      for (const m of metas) run.metas.set(m.id, m);
      runs.set(key, run);
    }
  }
  const out = [];
  for (const run of runs.values()) {
    if (!run.metas.size) continue;
    run.members.sort((a, b) => a.mtime - b.mtime);
    const metas = [...run.metas.values()], newest = run.members.at(-1);
    // A lane may run as a chain of agents; count each lane letter once.
    const lanes = [...new Set(metas.filter(m => m.spawnDepth === 1 && /lane/i.test(m.description ?? '')).map(m => m.description.replace(/^Lane\s+/i, '').replace(/:.*/, '').trim()))];
    out.push({ id: newest.id, dir: newest.dir, members: run.members.map(m => m.dir), ids: run.members.map(m => m.id), project: run.project, mtime: newest.mtime, agents: metas.length, lanes });
  }
  return out.sort((a, b) => b.mtime - a.mtime);
}

// Where a tool call sits in the lane brief's steps; null keeps the previous stage (reading, grepping, git plumbing).
const RX_LOOK = /playwright|puppeteer|screenshot|chromium|lighthouse|\b(npm|pnpm|yarn|bun) (run )?(dev|start|serve|preview)\b/;
const RX_PR = /gh pr (create|edit|checks|ready)|git push/;
const RX_GATES = /\b(npm|pnpm|yarn|bun) (run )?(test|lint|typecheck|check|format|build)\b|\b(vitest|jest|mocha|pytest|tsc|prettier|eslint|ruff|mypy|rspec)\b|\bcargo (test|check|clippy|build)\b|\bgo (test|vet|build)\b|\bmake (test|check|lint)\b/;
function stageOf(name, input = {}) {
  const cmd = String(input.command ?? '');
  if (name === 'SubagentHandback') return 'hand';
  if (name === 'Agent' || name === 'Task') return 'review';
  if (/^(Edit|Write|MultiEdit|NotebookEdit)$/.test(name)) return 'build';
  if (/playwright|chrom/i.test(name) || RX_LOOK.test(cmd)) return 'look';
  if (RX_PR.test(cmd)) return 'pr';
  if (RX_GATES.test(cmd)) return 'gates';
  return null;
}
// One line saying what a tool call did, without the cd/export/eval preamble lanes put on every command.
function toolSummary(input = {}) {
  const s = input.command ?? input.file_path ?? input.description ?? input.pattern ?? input.message ?? input.prompt ?? '';
  return String(s).replace(/\s+/g, ' ').replace(/^((cd|export|eval|source) [^&;]*(&&|;)\s*)+/, '').slice(0, 160);
}
// Issue and PR numbers a call names: #n, issues/n, pull/n, `gh issue|pr <verb> n`, and branch or folder suffixes like feat/x-422.
// Temp paths are dropped first: their numbers (/tmp/claude-501/) are user ids, not issues.
function refsOf(input = {}) {
  const s = [input.command, input.file_path, input.description, input.subject].filter(Boolean).join(' ').slice(0, 3000).replace(/\/(private\/)?tmp\/\S*/g, ' ');
  const rx = /#(\d+)\b|\b(?:issues|pull)\/(\d+)\b|\bgh (?:issue|pr) [a-z-]+ (\d+)\b|[A-Za-z]-(\d+)\b/g;
  return [...new Set([...s.matchAll(rx)].map(m => Number(m[1] ?? m[2] ?? m[3] ?? m[4])))];
}

const cache = new Map();
function parseTranscript(file) {
  const st = fs.statSync(file);
  const key = `${st.size}:${st.mtimeMs}`;
  const hit = cache.get(file);
  if (hit && hit.key === key) return hit.v;
  const v = { start: null, last: null, endT: null, tools: [], outTokens: 0, cwd: null, tokensById: {} };
  const seen = new Map();
  for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
    if (!line) continue;
    let j; try { j = JSON.parse(line); } catch { continue; }
    const t = j.timestamp ? Date.parse(j.timestamp) : null;
    if (t) { v.start ??= t; v.last = t; }
    v.cwd ??= j.cwd;
    const m = j.message;
    if (j.type !== 'assistant' || !m) continue;
    if (m.usage) {
      const o = m.usage.output_tokens ?? 0, prev = seen.get(m.id) ?? 0;
      if (o > prev) { v.outTokens += o - prev; seen.set(m.id, o); v.tokensById[m.id] = o; }
    }
    const uses = (m.content ?? []).filter(c => c.type === 'tool_use');
    if (!uses.length && m.stop_reason === 'end_turn') {
      // A turn that ends in plain text is a hand-back too; its first line may carry the status line.
      v.endT = t;
      const text = (m.content ?? []).filter(c => c.type === 'text').map(c => c.text).join('\n');
      if (text.trim()) v.tools.push({ key: m.id, t, name: 'TurnEnd', text: text.slice(0, 900), brief: toolSummary({ message: text }), stage: null, refs: [] });
    }
    for (const c of uses) {
      const inp = c.input ?? {};
      const tool = { key: c.id, t, name: c.name, brief: toolSummary(inp), stage: stageOf(c.name, inp), refs: refsOf(inp), merge: /gh pr merge/.test(String(inp.command ?? '')) || undefined };
      // extras the page uses for edge annotations and the goal panel
      if (c.name === 'Agent' || c.name === 'Task') Object.assign(tool, { useId: c.id, agentName: inp.name, promptLen: String(inp.prompt ?? '').length });
      if (c.name === 'SendMessage') Object.assign(tool, { to: inp.to, summary: inp.summary ?? String(inp.message ?? '').slice(0, 120) });
      if (c.name === 'SubagentHandback') tool.text = String(inp.message ?? '').slice(0, 900);
      if (c.name === 'TaskCreate' || c.name === 'TaskUpdate') tool.task = { id: inp.taskId, subject: inp.subject, description: inp.description ? String(inp.description).slice(0, 1500) : undefined, status: inp.status };
      v.tools.push(tool);
    }
  }
  cache.set(file, { key, v });
  return v;
}

// The swarm skill names run logs <date>-<repo>[-n].md; take this repo's newest one written during the session.
function runLogFor(start, last) {
  if (!fs.existsSync(RUNS)) return null;
  const name = path.basename(ROOT);
  const f = fs.readdirSync(RUNS).filter(n => n.includes('-' + name)).map(n => path.join(RUNS, n))
    .map(f => [f, fs.statSync(f).mtimeMs]).filter(([, m]) => m >= start && m <= last + 3600e3).sort((a, b) => b[1] - a[1])[0]?.[0];
  if (!f) return null;
  const text = fs.readFileSync(f, 'utf8');
  return {
    file: path.basename(f),
    title: (text.match(/^# (.*)$/m) ?? [])[1],
    // `Key: value` lines between the title and the first section name the goal: Shape, Scope, Queue, Frontier.
    lines: [...text.split(/^## /m)[0].matchAll(/^([A-Z][A-Za-z -]{1,30}): (.+)$/gm)].map(m => ({ key: m[1], value: m[2] })),
    tasks: [...text.matchAll(/^- \[( |x)\] (.*)$/gm)].map(m => ({ done: m[1] === 'x', text: m[2] })),
    incidents: (text.split(/^## Incidents\s*$/m)[1] ?? '').split('\n').filter(l => l.startsWith('- ')).map(l => l.slice(2)),
  };
}

let prs = { at: 0, list: [] };
function prsNow() {
  if (Date.now() - prs.at > 60_000) {
    prs.at = Date.now();
    execFile('gh', ['pr', 'list', '--state', 'all', '--limit', '120', '--json', 'number,state,headRefName,mergedAt,url'], { cwd: ROOT }, (err, out) => {
      if (!err) try { prs.list = JSON.parse(out); } catch {}
    });
  }
  return prs.list;
}
// owner/name from the origin remote, for GitHub links; null when it is not a GitHub repo
const REPO = (() => {
  try { return (execFileSync('git', ['-C', ROOT, 'remote', 'get-url', 'origin'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim().match(/github\.com[:/]([^/]+\/[^/.]+?)(\.git)?$/) ?? [])[1] ?? null; }
  catch { return null; }
})();

// One orchestrator transcript from every session of a resumed run: the copied history counts once.
function mergeMains(parts) {
  if (parts.length < 2) return parts[0] ?? null;
  const tools = new Map(), tokensById = {};
  for (const p of parts) {
    for (const tl of p.tools) tools.set(tl.key ?? `${tl.t}:${tl.name}`, tl);
    Object.assign(tokensById, p.tokensById);
  }
  return { start: Math.min(...parts.map(p => p.start ?? Infinity)), last: Math.max(...parts.map(p => p.last ?? 0)), endT: Math.max(...parts.map(p => p.endT ?? 0)) || null,
    cwd: parts[0].cwd, tools: [...tools.values()].sort((a, b) => a.t - b.t), outTokens: Object.values(tokensById).reduce((s, o) => s + o, 0), tokensById };
}

function state(id) {
  const sessions = listSessions();
  const s = sessions.find(x => x.ids.includes(id)) ?? sessions[0];
  if (!s) return { empty: true };
  // An agent running when the run was resumed has a transcript in both sessions; keep the longer one.
  const files = new Map(), size = (sub, aid) => fs.statSync(path.join(sub, `agent-${aid}.jsonl`)).size;
  for (const dir of s.members) {
    const sub = path.join(dir, 'subagents');
    if (!fs.existsSync(sub)) continue;
    for (const n of fs.readdirSync(sub).filter(n => n.endsWith('.jsonl'))) {
      const aid = n.replace(/^agent-|\.jsonl$/g, ''), had = files.get(aid);
      if (!had || size(sub, aid) >= size(had, aid)) files.set(aid, sub);
    }
  }
  const agents = [...files].map(([aid, sub]) => {
    const meta = readJson(path.join(sub, `agent-${aid}.meta.json`));
    const desc = meta.description ?? aid;
    const isLane = (meta.spawnDepth ?? 1) === 1 && /lane/i.test(desc);
    return { id: aid, useId: meta.toolUseId, desc, model: meta.model ?? '?', parent: meta.parentAgentId ?? null, depth: meta.spawnDepth ?? 1,
      isLane, queue: isLane ? [...desc.matchAll(/#(\d+)/g)].map(m => Number(m[1])) : [], ...parseTranscript(path.join(sub, `agent-${aid}.jsonl`)) };
  });
  const main = mergeMains(s.members.map(d => d + '.jsonl').filter(f => fs.existsSync(f)).map(parseTranscript));
  const start = Math.min(...agents.map(a => a.start).filter(Boolean), main?.start ?? Infinity);
  const last = Math.max(...agents.map(a => a.last ?? 0), main?.last ?? 0);
  return { now: Date.now(), session: s.id, project: path.basename(ROOT), start, last, main, agents, runLog: runLogFor(start, last), prs: prsNow(), repo: REPO };
}

const server = http.createServer((req, res) => {
  const u = new URL(req.url, 'http://x');
  const json = v => { res.writeHead(200, { 'content-type': 'application/json' }); res.end(JSON.stringify(v)); };
  if (u.pathname === '/whoami') return json({ app: 'swarm-console', pid: process.pid, project: PROJECT, root: ROOT });
  if (u.pathname === '/sessions') return json(listSessions().slice(0, 40).map(({ dir, members, ...s }) => s));
  if (u.pathname === '/state') return json(state(u.searchParams.get('session')));
  res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
  res.end(fs.readFileSync(PAGE));
});

async function whoami(port) {
  try { const w = await (await fetch(`http://127.0.0.1:${port}/whoami`, { signal: AbortSignal.timeout(800) })).json(); return w.app === 'swarm-console' ? w : null; }
  catch { return null; }
}
const link = port => `http://localhost:${port}/?view=board`;

if (/--stop\b/.test(argv)) {
  for (const p of PORTS) {
    const w = await whoami(p);
    if (w?.project === PROJECT) { process.kill(w.pid); console.log(`swarm console stopped (pid ${w.pid}, port ${p}) for ${ROOT}`); process.exit(0); }
  }
  console.log(`no swarm console running for ${ROOT}`);
  process.exit(0);
}

// One console per repo. A port already serving this repo is reused; any other occupant moves us to the next port.
(function listen(i) {
  if (i >= PORTS.length) { console.error(`swarm console: ports ${PORTS[0]}–${PORTS.at(-1)} are all taken`); process.exit(1); }
  const onListening = () => { server.off('error', onError); console.log(`swarm console started (pid ${process.pid}) for ${ROOT} → ${link(PORTS[i])}`); };
  const onError = async err => {
    server.off('listening', onListening);
    if (err.code !== 'EADDRINUSE') throw err;
    const w = await whoami(PORTS[i]);
    if (w?.project === PROJECT) { console.log(`swarm console reused (pid ${w.pid}) for ${ROOT} → ${link(PORTS[i])}`); process.exit(0); }
    listen(i + 1);
  };
  server.once('error', onError).once('listening', onListening).listen(PORTS[i]);
})(0);
