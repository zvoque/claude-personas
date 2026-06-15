#!/usr/bin/env node
'use strict';
// UserPromptSubmit hook. Reader only. Re-injects the active persona(s) each turn
// so they persist. DEFAULT is the full body (correct/proven); set PERSONAS_TERSE=1
// for a short re-assertion once it's validated to hold over long sessions
// (SMOKE.md). Self-suppresses on the plugin's own /personas command turns (so
// control turns -- esp. the team moderator turn -- stay clean). Never blocks:
// errors swallowed, always exit 0.
const m = require('./personas-lib');

function readStdin() {
  return new Promise((resolve) => {
    let d = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (c) => (d += c));
    process.stdin.on('end', () => resolve(d));
    process.stdin.on('error', () => resolve(''));
  });
}

async function main() {
  let input = {};
  try { input = JSON.parse(await readStdin()) || {}; } catch (_) { input = {}; }
  if (m.isPersonasCommand(input.prompt)) return;            // self-suppress
  const state = m.readState();
  const text = process.env.PERSONAS_TERSE === '1' ? m.shortReassertion(state) : m.fullInjection(state);
  if (text) m.emitContext('UserPromptSubmit', text);
}

main().catch(() => {}).finally(() => process.exit(0));
