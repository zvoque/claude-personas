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
    default: die(`unknown verb: ${verb}`);
  }
}
main();
