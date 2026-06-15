#!/usr/bin/env bash
# Shared test helpers. Source from each test file.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Run the hooks exactly as Claude Code would: with CLAUDE_PLUGIN_ROOT pointing
# at the installed plugin dir, so bundled modes (contrarian) resolve from there.
export CLAUDE_PLUGIN_ROOT="$REPO_ROOT/plugins/modes"
TRACKER="$CLAUDE_PLUGIN_ROOT/hooks/modes-tracker.sh"
ACTIVATE="$CLAUDE_PLUGIN_ROOT/hooks/modes-activate.sh"

FAILS=0
TEST_NAME=""
t() { TEST_NAME="$1"; }

assert_eq() { # actual expected
  if [ "$1" != "$2" ]; then echo "FAIL($TEST_NAME): expected [$2] got [$1]"; FAILS=$((FAILS+1)); fi
}
assert_contains() { # haystack needle
  case "$1" in *"$2"*) ;; *) echo "FAIL($TEST_NAME): output missing [$2]"; FAILS=$((FAILS+1));; esac
}
assert_not_contains() { # haystack needle
  case "$1" in *"$2"*) echo "FAIL($TEST_NAME): output should not contain [$2]"; FAILS=$((FAILS+1));; esac
}
assert_file() { # path
  [ -f "$1" ] || { echo "FAIL($TEST_NAME): missing file $1"; FAILS=$((FAILS+1)); }
}
assert_no_file() { # path
  [ ! -e "$1" ] || { echo "FAIL($TEST_NAME): file should not exist $1"; FAILS=$((FAILS+1)); }
}

# Fresh isolated HOME so the real ~/.claude is never touched. The active-mode
# flag and the personal-mode fallback dir both live under HOME.
fresh_home() {
  HOME="$(mktemp -d)"
  export HOME
  FLAG="$HOME/.claude/.modes-active"
  mkdir -p "$HOME/.claude"
}

# prompt-json, script -> stdout
run() { printf '%s' "$1" | bash "$2"; }

finish() {
  if [ "$FAILS" -eq 0 ]; then echo "OK $(basename "$0")"; exit 0
  else echo "FAILED $(basename "$0") ($FAILS)"; exit 1; fi
}
