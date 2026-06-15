#!/usr/bin/env bash
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="$REPO_ROOT/plugins/personas"   # real plugin dir — for invoking the scripts
LIB="$PLUGIN/hooks/personas-lib.js"
CTL="$PLUGIN/hooks/personas-ctl.js"
TRACKER="$PLUGIN/hooks/personas-tracker.js"
ACTIVATE="$PLUGIN/hooks/personas-activate.js"
# CLAUDE_PLUGIN_ROOT is sandboxed per fresh_home (below), so bundled-persona
# fixtures never touch the real plugin dir.

FAILS=0; T=""
t() { T="$1"; }
eq()        { [ "$1" = "$2" ] || { echo "FAIL($T): expected [$2] got [$1]"; FAILS=$((FAILS+1)); }; }
contains()  { case "$1" in *"$2"*) ;; *) echo "FAIL($T): missing [$2] in [$1]"; FAILS=$((FAILS+1));; esac; }
ncontains() { case "$1" in *"$2"*) echo "FAIL($T): should not contain [$2]"; FAILS=$((FAILS+1));; esac; }
isfile()    { [ -f "$1" ] || { echo "FAIL($T): missing file $1"; FAILS=$((FAILS+1)); }; }
nofile()    { [ ! -e "$1" ] || { echo "FAIL($T): file should not exist $1"; FAILS=$((FAILS+1)); }; }

# Fresh sandbox HOME + sandbox CLAUDE_PLUGIN_ROOT so neither the real ~/.claude
# nor the real plugin dir is ever touched.
fresh_home() {
  HOME="$(mktemp -d)"; export HOME
  export CLAUDE_PLUGIN_ROOT="$HOME/.bundled"
  STATE="$HOME/.claude/.personas-active"
  mkdir -p "$HOME/.claude/personas" "$CLAUDE_PLUGIN_ROOT/personas"
}
# Reset between test blocks: clear state + personal/bundled persona dirs (avoids cross-block coupling).
reset() { rm -f "$STATE"; rm -f "$HOME/.claude/personas/"*.md "$CLAUDE_PLUGIN_ROOT/personas/"*.md 2>/dev/null || true; }
finish() { if [ "$FAILS" -eq 0 ]; then echo "OK $(basename "$0")"; exit 0; else echo "FAILED $(basename "$0") ($FAILS)"; exit 1; fi; }

libcall() { node -e "const m=require('$LIB'); $1"; }
