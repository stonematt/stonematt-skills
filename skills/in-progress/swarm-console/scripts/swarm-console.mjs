#!/usr/bin/env node
// Swarm console server: serves swarm-console.html and the swarm's state as JSON.
//
//   node swarm-console.mjs [--port 4186] [--runs <dir>]
//   open http://localhost:4186/?view=board&session=<session-id>
//
// Reads, never writes: Claude session transcripts and subagents/*.jsonl under ~/.claude/projects,
// swarm run logs in --runs (default ~/.claude/skill-workbench/swarm/runs), `gh pr list` and the
// origin remote of the session's repo. The page is re-read on every load.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import http from 'node:http';
import { execFile, execFileSync } from 'node:child_process';

const argv = process.argv.join(' ');
const PORT = Number((argv.match(/--port (\d+)/) ?? [])[1] ?? 4186);
// Ports tried in order when PORT is taken by something else. 4190 is skipped: Safari refuses it.
const PORTS = Array.from({ length: 14 }, (_, i) => PORT + i).filter(p => p !== 4190);
const PROJECTS = path.join(os.homedir(), '.claude/projects');
const RUNS = (argv.match(/--runs (\S+)/) ?? [])[1] ?? path.join(os.homedir(), '.claude/skill-workbench/swarm/runs');
const PAGE = new URL('./swarm-console.html', import.meta.url);

// The repo this console was started for, as Claude names its project folders: every non-alphanumeric becomes -.
// Resolved through git's common dir, so starting from any worktree names the main checkout.
function projectSlug(dir) {
  let root = path.resolve(dir);
  try { root = path.dirname(execFileSync('git', ['-C', dir, 'rev-parse', '--path-format=absolute', '--git-common-dir'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim()); } catch {}
  return root.replace(/[^a-zA-Z0-9]/g, '-');
}
const PROJECT = projectSlug((argv.match(/--project (\S+)/) ?? [])[1] ?? process.cwd());

function readJson(f) { try { return JSON.parse(fs.readFileSync(f, 'utf8')); } catch { return {}; } }

// Every session that spawned subagents, newest first.
function listSessions() {
  const out = [];
  for (const p of fs.readdirSync(PROJECTS)) {
    const pd = path.join(PROJECTS, p);
    if (!fs.statSync(pd).isDirectory()) continue;
    for (const s of fs.readdirSync(pd)) {
      const sub = path.join(pd, s, 'subagents');
      if (!fs.existsSync(sub)) continue;
      const metas = fs.readdirSync(sub).filter(n => n.endsWith('.meta.json')).map(n => readJson(path.join(sub, n)));
      const lanes = metas.filter(m => m.spawnDepth === 1 && /lane/i.test(m.description ?? '')).map(m => m.description);
      out.push({ id: s, dir: path.join(pd, s), projectDir: p, project: p.replace(/^-Users-[^-]+-/, ''), mtime: fs.statSync(sub).mtimeMs, agents: metas.length, lanes });
    }
  }
  return out.sort((a, b) => b.mtime - a.mtime);
}

// Where a tool call sits in the lane brief's steps.
function stageOf(name, input = {}) {
  const cmd = String(input.command ?? '');
  if (name === 'SubagentHandback') return 'hand';
  if (name === 'Agent' || name === 'Task') return 'review';
  if (/^(Edit|Write|MultiEdit|NotebookEdit)$/.test(name)) return 'build';
  if (/playwright|chrom/i.test(name) || /playwright|serverctl|screenshot|chromium/.test(cmd)) return 'look';
  if (/gh pr (create|edit|checks|ready)|git push/.test(cmd)) return 'pr';
  if (/vitest|pnpm (run )?(test|typecheck|lint|format|check|privacy|build)|\btsc\b|prettier|eslint/.test(cmd)) return 'gates';
  return null; // reading, grepping, git plumbing: keeps the previous stage
}
function brief(input = {}) {
  const s = input.command ?? input.file_path ?? input.description ?? input.pattern ?? input.message ?? input.prompt ?? '';
  // drop the cd/export/eval preamble lanes put on every command, keep the verb
  return String(s).replace(/\s+/g, ' ').replace(/^((cd|export|eval|source) [^&;]*(&&|;)\s*)+/, '').slice(0, 160);
}
// Issue-sized numbers named in the parts of a call that say what it is about.
function refsOf(input = {}) {
  const s = [input.command, input.file_path, input.description, input.subject].filter(Boolean).join(' ').slice(0, 3000);
  return [...new Set([...s.matchAll(/(?<![\d.:])(\d{3,4})(?![\d.])/g)].map(m => Number(m[1])))];
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
    if (!uses.length && m.stop_reason === 'end_turn') v.endT = t;
    for (const c of uses) {
      const cmd = String(c.input?.command ?? '');
      const tool = { t, name: c.name, brief: brief(c.input), stage: stageOf(c.name, c.input), refs: refsOf(c.input), merge: /gh pr merge/.test(cmd) || undefined };
      const inp = c.input ?? {};
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

function runLogFor(start, last) {
  if (!fs.existsSync(RUNS)) return null;
  const f = fs.readdirSync(RUNS).map(n => path.join(RUNS, n)).find(f => { const m = fs.statSync(f).mtimeMs; return m >= start && m <= last + 3600e3; });
  if (!f) return null;
  const text = fs.readFileSync(f, 'utf8');
  return {
    file: path.basename(f),
    title: (text.match(/^# (.*)$/m) ?? [])[1],
    tasks: [...text.matchAll(/^- \[( |x)\] (.*)$/gm)].map(m => ({ done: m[1] === 'x', text: m[2] })),
    incidents: (text.split(/^## Incidents\s*$/m)[1] ?? '').split('\n').filter(l => l.startsWith('- ')).map(l => l.slice(2)),
  };
}

const prsByRepo = new Map();
function prsFor(cwd) {
  if (!cwd) return [];
  const hit = prsByRepo.get(cwd);
  if (!hit || Date.now() - hit.at > 60_000) {
    prsByRepo.set(cwd, { at: Date.now(), prs: hit?.prs ?? [] });
    execFile('gh', ['pr', 'list', '--state', 'all', '--limit', '120', '--json', 'number,state,headRefName,mergedAt,url'], { cwd }, (err, out) => {
      if (!err) try { prsByRepo.set(cwd, { at: Date.now(), prs: JSON.parse(out) }); } catch {}
    });
  }
  return prsByRepo.get(cwd).prs;
}

// owner/name from the repo's origin remote, for GitHub links; null when it is not a GitHub repo
const repoByCwd = new Map();
function repoFor(cwd) {
  if (!cwd) return null;
  if (!repoByCwd.has(cwd)) {
    let slug = null;
    try {
      const url = execFileSync('git', ['-C', cwd, 'remote', 'get-url', 'origin'], { encoding: 'utf8' }).trim();
      slug = (url.match(/github\.com[:/]([^/]+\/[^/.]+?)(\.git)?$/) ?? [])[1] ?? null;
    } catch {}
    repoByCwd.set(cwd, slug);
  }
  return repoByCwd.get(cwd);
}

function state(id) {
  const sessions = listSessions();
  const s = sessions.find(x => x.id === id) ?? sessions[0];
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
  // Real-repo cwd: strip a .claude/worktrees/<name> suffix so gh sees the repo.
  const cwd = main?.cwd?.replace(/\/\.claude\/worktrees\/[^/]+$/, '');
  return { now: Date.now(), session: s.id, project: s.project, start, last, main, agents, runLog: runLogFor(start, last), prs: prsFor(cwd), repo: repoFor(cwd) };
}

const server = http.createServer((req, res) => {
  const u = new URL(req.url, 'http://x');
  const json = v => { res.writeHead(200, { 'content-type': 'application/json' }); res.end(JSON.stringify(v)); };
  if (u.pathname === '/whoami') return json({ app: 'swarm-console', pid: process.pid });
  if (u.pathname === '/sessions') {
    // A worktree's sessions live in folders named after the main checkout plus a suffix, so a prefix match keeps them.
    const project = u.searchParams.get('project');
    return json(listSessions().filter(s => !project || s.projectDir.startsWith(project)).slice(0, 40).map(({ dir, ...s }) => s));
  }
  if (u.pathname === '/state') return json(state(u.searchParams.get('session')));
  res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
  res.end(fs.readFileSync(PAGE));
});

// One console per machine serves every project. If one already runs, print this project's link and leave it be.
async function isConsole(port) {
  try { return (await (await fetch(`http://127.0.0.1:${port}/whoami`, { signal: AbortSignal.timeout(800) })).json()).app === 'swarm-console'; }
  catch { return false; }
}
const link = port => `http://localhost:${port}/?view=board&project=${PROJECT}`;
(function listen(i) {
  if (i >= PORTS.length) { console.error(`swarm console: ports ${PORTS[0]}–${PORTS.at(-1)} are all taken`); process.exit(1); }
  server.once('error', async err => {
    if (err.code !== 'EADDRINUSE') throw err;
    if (await isConsole(PORTS[i])) { console.log(`swarm console already running (reused) → ${link(PORTS[i])}`); process.exit(0); }
    listen(i + 1);
  });
  server.listen(PORTS[i], () => console.log(`swarm console started (pid ${process.pid}) → ${link(PORTS[i])}`));
})(0);
