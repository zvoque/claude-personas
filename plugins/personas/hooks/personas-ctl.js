#!/usr/bin/env node
'use strict';
// Sole writer of state + persona files. A CLI (not a hook) — it lives in hooks/
// only so it can require('./personas-lib') directly. Invoked by the /personas
// command (via bash) and by create-persona. Prints human-readable lines for the
// command to relay. Exits non-zero on user error.
const fs = require('fs');
const path = require('path');
const m = require('./personas-lib');

function die(msg) { console.error(msg); process.exit(1); }
function say(msg) { console.log(msg); }

function cmdEnable(name) {
  if (!name) die('usage: /personas <name>');
  if (!m.isValidName(name)) die(`invalid name: ${name}`);
  if (!m.personaFile(name)) die(`no such persona: ${name} (try /personas list)`);
  const s = m.readState();
  const rest = s.enabled.filter((n) => n !== name);
  s.enabled = s.mode === 'solo' ? [name] : rest.concat(name);
  m.writeState(s);
  say(`enabled ${name} (${s.mode}); active: ${s.enabled.join(', ') || 'none'}`);
}

function cmdDisable(name) {                 // no name → clear all
  const s = m.readState();
  s.enabled = name ? s.enabled.filter((n) => n !== name) : [];
  m.writeState(s);
  say(`${name ? 'disabled ' + name : 'cleared all'}; active: ${s.enabled.join(', ') || 'none'}`);
}

function cmdMode(mode) {
  const s = m.readState();
  s.mode = mode;
  if (mode === 'solo' && s.enabled.length > 1) s.enabled = s.enabled.slice(-1);
  m.writeState(s);
  say(`mode: ${mode}; active: ${s.enabled.join(', ') || 'none'}`);
}

function cmdList() {
  const s = m.readState();
  const all = m.listPersonas();
  say(`mode: ${s.mode}`);
  if (!all.length) { say('(no personas; create one with /personas new)'); return; }
  for (const n of all) say(`${s.enabled.indexOf(n) !== -1 ? '* ' : '  '}${n}`);
}

// create reads the body from stdin (never an arg — avoids escaping a multi-line
// body). Always invoked with piped stdin (by create-persona / tests); don't run
// `create` interactively (fd 0 would block on EOF).
function readStdin() {
  try { return fs.readFileSync(0, 'utf8'); } catch (_) { return ''; }
}
function argVal(rest, flag) {
  const i = rest.indexOf(flag);
  return (i !== -1 && rest[i + 1]) ? rest[i + 1] : '';
}
function personalPath(name) { return path.join(m.CLAUDE_DIR, 'personas', name + '.md'); }
function bundledPath(name) {
  return process.env.CLAUDE_PLUGIN_ROOT
    ? path.join(process.env.CLAUDE_PLUGIN_ROOT, 'personas', name + '.md') : null;
}

function cmdCreate(name, rest) {
  if (!name) die('usage: /personas new <name>');
  if (m.RESERVED.indexOf(name) !== -1) die(`"${name}" is a reserved verb; pick another name`);
  if (!m.isValidName(name)) die(`invalid name: ${name} (use a-z, 0-9, -, starting with a letter/digit)`);
  if (fs.existsSync(personalPath(name))) die(`persona already exists: ${name} (delete it first to recreate)`);
  const desc = (argVal(rest, '--desc') || name).replace(/\n/g, ' ');
  const body = readStdin().trim();
  if (!body) die('empty body on stdin — nothing to write');
  const file = `---\nname: ${name}\ndescription: ${desc}\n---\n\n${body}\n`;
  fs.mkdirSync(path.dirname(personalPath(name)), { recursive: true });
  const tmp = personalPath(name) + '.tmp';
  fs.writeFileSync(tmp, file);
  fs.renameSync(tmp, personalPath(name));
  let msg = `created persona: ${personalPath(name)} — activate with /personas ${name}`;
  if (bundledPath(name) && fs.existsSync(bundledPath(name))) msg += ` (overrides the bundled ${name})`;
  say(msg);
}

function cmdDelete(name) {
  if (!name) die('usage: /personas delete <name>');
  if (!m.isValidName(name)) die(`invalid name: ${name}`);
  if (!fs.existsSync(personalPath(name))) {
    if (bundledPath(name) && fs.existsSync(bundledPath(name))) {
      die(`"${name}" is a bundled persona and can't be deleted — disable it or make a personal override with /personas new`);
    }
    die(`no such personal persona: ${name}`);
  }
  fs.unlinkSync(personalPath(name));
  const s = m.readState();
  const had = s.enabled.indexOf(name) !== -1;
  s.enabled = s.enabled.filter((n) => n !== name);
  m.writeState(s);
  let msg = `deleted ${name}`;
  if (had) msg += ' (removed from active set)';
  if (bundledPath(name) && fs.existsSync(bundledPath(name))) msg += `; bundled ${name} is now active again`;
  say(msg);
}

function main() {
  const [verb, ...rest] = process.argv.slice(2);
  switch (verb) {
    case 'enable':   return cmdEnable(rest[0]);
    case 'disable':
    case 'off':      return cmdDisable(rest[0]);
    case 'solo':     return cmdMode('solo');
    case 'parallel': return cmdMode('parallel');
    case 'list':
    case undefined:  return cmdList();
    case 'create':   return cmdCreate(rest[0], rest);
    case 'delete':   return cmdDelete(rest[0]);
    default: die(`unknown verb: ${verb}`);
  }
}
main();
