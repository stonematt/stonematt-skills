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

// This repo's sessions that spawned subagents, newest first.
function listSessions() {
  const out = [];
  for (const p of fs.readdirSync(PROJECTS).filter(inProject)) {
    const pd = path.join(PROJECTS, p);
    if (!fs.statSync(pd).isDirectory()) continue;
    for (const s of fs.readdirSync(pd)) {
      const sub = path.join(pd, s, 'subagents');
      if (!fs.existsSync(sub)) continue;
      const metas = fs.readdirSync(sub).filter(n => n.endsWith('.meta.json')).map(n => readJson(path.join(sub, n)));
      const lanes = metas.filter(m => m.spawnDepth === 1 && /lane/i.test(m.description ?? '')).map(m => m.description);
      out.push({ id: s, dir: path.join(pd, s), project: p.startsWith(HOME_SLUG) ? p.slice(HOME_SLUG.length) : p, mtime: fs.statSync(sub).mtimeMs, agents: metas.length, lanes });
    }
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
  const v = { start: null, last: null, endT: null, tools: [], outTokens: 0, cwd: null };
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
      if (o > prev) { v.outTokens += o - prev; seen.set(m.id, o); }
    }
    const uses = (m.content ?? []).filter(c => c.type === 'tool_use');
    if (!uses.length && m.stop_reason === 'end_turn') {
      // A turn that ends in plain text is a hand-back too; its first line may carry the status line.
      v.endT = t;
      const text = (m.content ?? []).filter(c => c.type === 'text').map(c => c.text).join('\n');
      if (text.trim()) v.tools.push({ t, name: 'TurnEnd', text: text.slice(0, 900), brief: toolSummary({ message: text }), stage: null, refs: [] });
    }
    for (const c of uses) {
      const inp = c.input ?? {};
      const tool = { t, name: c.name, brief: toolSummary(inp), stage: stageOf(c.name, inp), refs: refsOf(inp), merge: /gh pr merge/.test(String(inp.command ?? '')) || undefined };
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

function state(id) {
  const sessions = listSessions();
  const s = sessions.find(x => x.id === id) ?? sessions[0];
  if (!s) return { empty: true };
  const sub = path.join(s.dir, 'subagents');
  const agents = fs.readdirSync(sub).filter(n => n.endsWith('.jsonl')).map(n => {
    const aid = n.replace(/^agent-|\.jsonl$/g, '');
    const meta = readJson(path.join(sub, `agent-${aid}.meta.json`));
    const desc = meta.description ?? aid;
    const isLane = (meta.spawnDepth ?? 1) === 1 && /lane/i.test(desc);
    return { id: aid, useId: meta.toolUseId, desc, model: meta.model ?? '?', parent: meta.parentAgentId ?? null, depth: meta.spawnDepth ?? 1,
      isLane, queue: isLane ? [...desc.matchAll(/#(\d+)/g)].map(m => Number(m[1])) : [], ...parseTranscript(path.join(sub, n)) };
  });
  const mainFile = s.dir + '.jsonl';
  const main = fs.existsSync(mainFile) ? parseTranscript(mainFile) : null;
  const start = Math.min(...agents.map(a => a.start).filter(Boolean), main?.start ?? Infinity);
  const last = Math.max(...agents.map(a => a.last ?? 0), main?.last ?? 0);
  return { now: Date.now(), session: s.id, project: path.basename(ROOT), start, last, main, agents, runLog: runLogFor(start, last), prs: prsNow(), repo: REPO };
}

const server = http.createServer((req, res) => {
  const u = new URL(req.url, 'http://x');
  const json = v => { res.writeHead(200, { 'content-type': 'application/json' }); res.end(JSON.stringify(v)); };
  if (u.pathname === '/whoami') return json({ app: 'swarm-console', pid: process.pid, project: PROJECT, root: ROOT });
  if (u.pathname === '/sessions') return json(listSessions().slice(0, 40).map(({ dir, ...s }) => s));
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
