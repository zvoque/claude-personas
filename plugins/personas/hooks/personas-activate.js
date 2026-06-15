#!/usr/bin/env node
'use strict';
// SessionStart hook. Injects the FULL persona(s) before the first prompt of a
// session (start/resume/clear, and compaction IF SessionStart fires with
// source=compact -- confirmed by the Task 0.5 spike). With full-per-turn tracking
// (default), the tracker re-establishes each turn anyway, so this only needs to
// cover turn-0. Echoes the firing event's name. Never blocks.
//
// One write, on one path only: crash-recovery for a `/personas team` suspend. If
// injection is suspended and this is a fresh start/resume (NOT a compact), the
// session that suspended it -- and its debate agent team -- is gone, so the flag
// is orphaned: clear it and restore the personas. On compact the same session
// continues, so a live debate stays suppressed.
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
  let state = m.readState();
  if (state.suspended) {
    if (input.source === 'compact') return;                // debate still live this session
    m.writeState({ mode: state.mode, enabled: state.enabled, suspended: false });
    state = m.readState();
  }
  const text = m.fullInjection(state);
  if (text) m.emitContext(event, text);
}

main().catch(() => {}).finally(() => process.exit(0));
