'use strict';
// Shared core for the personas plugin. Zero deps. Sole owner of state + persona
// resolution logic; required by the CLI and both hooks. Every read is defensive
// (any failure → safe default) so a broken state file never breaks a session.
const fs = require('fs');
const os = require('os');
const path = require('path');

const CLAUDE_DIR = path.join(os.homedir(), '.claude');
const STATE_FILE = path.join(CLAUDE_DIR, '.personas-active');
const RESERVED = ['list', 'status', 'off', 'on', 'solo', 'parallel', 'team', 'new', 'delete', 'help', 'suspend', 'resume'];
const NAME_RE = /^[a-z0-9][a-z0-9-]*$/;
// A team-debate pause auto-expires after this long, so a debate that never runs
// its cleanup can't strand the user's personas in the off state — it self-heals
// with no restart and no user action. Generous enough to outlast any real debate.
const SUSPEND_TTL_MS = 30 * 60 * 1000;

function isValidName(name) {
  return typeof name === 'string' && NAME_RE.test(name) && RESERVED.indexOf(name) === -1;
}

// Personal dir FIRST so a user persona overrides a bundled one of the same name.
// Bundled dir comes from CLAUDE_PLUGIN_ROOT when set (hook execution, tests),
// otherwise from this file's own location — this lib always lives at
// <plugin-root>/hooks/, so <__dirname>/../personas IS the bundled dir. The
// fallback matters because the /personas command runs the CLI WITHOUT
// CLAUDE_PLUGIN_ROOT in the environment; without it, bundled personas are
// invisible to the command.
function personaDirs() {
  const dirs = [path.join(CLAUDE_DIR, 'personas')];
  dirs.push(process.env.CLAUDE_PLUGIN_ROOT
    ? path.join(process.env.CLAUDE_PLUGIN_ROOT, 'personas')
    : path.join(__dirname, '..', 'personas'));
  return dirs;
}

function personaFile(name) {
  if (!isValidName(name)) return null;
  for (const dir of personaDirs()) {
    const f = path.join(dir, name + '.md');
    try { if (fs.statSync(f).isFile()) return f; } catch (_) { /* next */ }
  }
  return null;
}

function defaultState() { return { mode: 'solo', enabled: [], suspended: false }; }

function readState() {
  let raw;
  try { raw = fs.readFileSync(STATE_FILE, 'utf8'); } catch (_) { return defaultState(); }
  let s;
  try { s = JSON.parse(raw); } catch (_) { return defaultState(); }
  const mode = (s && (s.mode === 'parallel' || s.mode === 'solo')) ? s.mode : 'solo';
  let enabled = (s && Array.isArray(s.enabled)) ? s.enabled.filter(isValidName) : [];
  enabled = enabled.filter((n) => personaFile(n));          // prune dangling
  if (mode === 'solo' && enabled.length > 1) enabled = enabled.slice(-1);
  // Team-debate pause, honored only within the TTL so a forgotten cleanup can't
  // strand personas off — past the window it reads as not-suspended (self-heals).
  let suspended = false;
  if (s && s.suspended === true) {
    const at = typeof s.suspended_at === 'number' ? s.suspended_at : 0;
    suspended = (Date.now() - at) < SUSPEND_TTL_MS;
  }
  return { mode, enabled, suspended };
}

function writeState(state) {
  fs.mkdirSync(CLAUDE_DIR, { recursive: true });
  const tmp = STATE_FILE + '.tmp';
  const mode = state.mode === 'parallel' ? 'parallel' : 'solo';   // never write an invalid mode
  const out = { mode, enabled: state.enabled };
  if (state.suspended === true) {                          // omit when false → clean file
    out.suspended = true;
    out.suspended_at = typeof state.suspended_at === 'number' ? state.suspended_at : Date.now();
  }
  fs.writeFileSync(tmp, JSON.stringify(out) + '\n');
  fs.renameSync(tmp, STATE_FILE);                           // atomic
}

function listPersonas() {
  const seen = new Set();
  for (const dir of personaDirs()) {
    let entries = [];
    try { entries = fs.readdirSync(dir); } catch (_) { entries = []; }
    for (const e of entries) {
      if (e.slice(-3) === '.md') {
        const n = e.slice(0, -3);
        if (isValidName(n)) seen.add(n);
      }
    }
  }
  return Array.from(seen).sort();
}

function stripFrontmatter(text) {
  return text.replace(/^\uFEFF?---\r?\n[\s\S]*?\r?\n---\r?\n?/, '').trim();
}

function readPersonaBody(name) {
  const f = personaFile(name);
  if (!f) return null;
  try { return stripFrontmatter(fs.readFileSync(f, 'utf8')); } catch (_) { return null; }
}

function isPersonasCommand(prompt) {
  return /^\s*\/personas(\s|$)/i.test(String(prompt || ''));
}

const PARALLEL_HEADER =
  'Multiple personas are active. Respond as each in turn, clearly labeled, in one message. Personas do not address one another.';

function fullInjection(state) {
  const parts = [];
  for (const n of state.enabled) {
    const b = readPersonaBody(n);
    if (b) parts.push({ n, b });
  }
  if (!parts.length) return null;
  if (state.mode === 'parallel' && parts.length > 1) {
    return PARALLEL_HEADER + '\n\n' + parts.map((p) => `## Persona: ${p.n}\n${p.b}`).join('\n\n');
  }
  return parts[0].b;
}

function shortReassertion(state) {
  const names = state.enabled.filter((n) => readPersonaBody(n));
  if (!names.length) return null;
  if (state.mode === 'parallel' && names.length > 1) {
    return `Personas active — respond as each in turn, labeled, one message; they do not address each other: ${names.join(', ')}. Maintain each as established earlier.`;
  }
  return `Persona active: ${names[0]}. Maintain it as established earlier — keep its structure and voice.`;
}

function emitContext(event, text) {
  if (!text) return;
  process.stdout.write(JSON.stringify({ hookSpecificOutput: { hookEventName: event, additionalContext: text } }));
}

module.exports = {
  CLAUDE_DIR, STATE_FILE, RESERVED,
  isValidName, personaDirs, personaFile, defaultState, readState, writeState,
  listPersonas, stripFrontmatter, readPersonaBody,
  isPersonasCommand, fullInjection, shortReassertion, emitContext,
};
