#!/usr/bin/env bash
set -u
. "$(dirname "$0")/helpers.sh"
fresh_home; trap 'rm -rf "$HOME"' EXIT
reset
printf -- '---\nname: contrarian\ndescription: x\n---\nBE SHARP.\n' > "$HOME/.claude/personas/contrarian.md"

out="$(printf '{"prompt":"hi"}' | node "$TRACKER")"
t "no inject when none active"; eq "$out" ""
node "$CTL" enable contrarian >/dev/null

# default = FULL per turn (correct/proven; short is opt-in)
out="$(printf '{"prompt":"hi"}' | node "$TRACKER")"
t "default injects full"; contains "$out" "BE SHARP."; contains "$out" "additionalContext"

# PERSONAS_TERSE=1 = short re-assertion
out="$(printf '{"prompt":"hi"}' | PERSONAS_TERSE=1 node "$TRACKER")"
t "terse mode is short"; contains "$out" "contrarian"; ncontains "$out" "BE SHARP."

# self-suppress on /personas turns
out="$(printf '{"prompt":"/personas list"}' | node "$TRACKER")"
t "suppress on /personas turn"; eq "$out" ""

finish
