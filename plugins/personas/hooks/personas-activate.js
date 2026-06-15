#!/usr/bin/env node
'use strict';
// SessionStart hook. Reader only. Injects the FULL persona(s) before the first
// prompt of a session (start/resume/clear, and compaction IF SessionStart fires
// with source=compact -- confirmed by the Task 0.5 spike). With full-per-turn
// tracking (default), the tracker re-establishes each turn anyway, so this only
// needs to cover turn-0. Echoes the firing event's name. Never blocks.
const m = require('./personas-lib');

function readStdin() {
  return new Promise((resolve) => {
    let d = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (c) => (d += c));
    process.stdin.on('end', () => resolve(d));
    process.stdin.on('error', () => resolve(''));
    setImmediate(() => { if (!process.stdin.readable) resolve(d); });
  });
}

async function main() {
  let input = {};
  try { input = JSON.parse(await readStdin()) || {}; } catch (_) { input = {}; }
  const event = input.hook_event_name || 'SessionStart';
  const text = m.fullInjection(m.readState());
  if (text) m.emitContext(event, text);
}

main().catch(() => {}).finally(() => process.exit(0));
