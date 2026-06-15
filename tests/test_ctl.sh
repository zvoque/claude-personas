#!/usr/bin/env bash
set -u
. "$(dirname "$0")/helpers.sh"
fresh_home; trap 'rm -rf "$HOME"' EXIT

# ===== state =====
reset
t "default state when absent"; eq "$(libcall 'console.log(JSON.stringify(m.readState()))')" '{"mode":"solo","enabled":[]}'
libcall 'm.writeState({mode:"parallel",enabled:["a"]})'
t "state file written"; isfile "$STATE"
t "dangling pruned on read"; eq "$(libcall 'console.log(JSON.stringify(m.readState()))')" '{"mode":"parallel","enabled":[]}'

finish
