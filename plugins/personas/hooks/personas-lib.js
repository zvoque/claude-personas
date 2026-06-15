'use strict';
// Shared core for the personas plugin. Zero deps. Sole owner of state + persona
// resolution logic; required by the CLI and both hooks. Every read is defensive
// (any failure → safe default) so a broken state file never breaks a session.
const fs = require('fs');
const os = require('os');
const path = require('path');

const CLAUDE_DIR = path.join(os.homedir(), '.claude');
const STATE_FILE = path.join(CLAUDE_DIR, '.personas-active');
const RESERVED = ['list', 'off', 'on', 'solo', 'parallel', 'team', 'new', 'delete', 'help'];
const NAME_RE = /^[a-z0-9][a-z0-9-]*$/;

function isValidName(name) {
  return typeof name === 'string' && NAME_RE.test(name) && RESERVED.indexOf(name) === -1;
}

// Personal dir FIRST so a user persona overrides a bundled one of the same name.
function personaDirs() {
  const dirs = [path.join(CLAUDE_DIR, 'personas')];
  if (process.env.CLAUDE_PLUGIN_ROOT) dirs.push(path.join(process.env.CLAUDE_PLUGIN_ROOT, 'personas'));
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

function defaultState() { return { mode: 'solo', enabled: [] }; }

function readState() {
  let raw;
  try { raw = fs.readFileSync(STATE_FILE, 'utf8'); } catch (_) { return defaultState(); }
  let s;
  try { s = JSON.parse(raw); } catch (_) { return defaultState(); }
  const mode = (s && (s.mode === 'parallel' || s.mode === 'solo')) ? s.mode : 'solo';
  let enabled = (s && Array.isArray(s.enabled)) ? s.enabled.filter(isValidName) : [];
  enabled = enabled.filter((n) => personaFile(n));          // prune dangling
  if (mode === 'solo' && enabled.length > 1) enabled = enabled.slice(-1);
  return { mode, enabled };
}

function writeState(state) {
  fs.mkdirSync(CLAUDE_DIR, { recursive: true });
  const tmp = STATE_FILE + '.tmp';
  fs.writeFileSync(tmp, JSON.stringify({ mode: state.mode, enabled: state.enabled }) + '\n');
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
  return text.replace(/^﻿?---\r?\n[\s\S]*?\r?\n---\r?\n?/, '').trim();
}

function readPersonaBody(name) {
  const f = personaFile(name);
  if (!f) return null;
  try { return stripFrontmatter(fs.readFileSync(f, 'utf8')); } catch (_) { return null; }
}

module.exports = {
  CLAUDE_DIR, STATE_FILE, RESERVED,
  isValidName, personaDirs, personaFile, defaultState, readState, writeState,
  listPersonas, stripFrontmatter, readPersonaBody,
};
