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

# ===== names + resolution =====
reset
t "valid name";    eq "$(libcall 'console.log(m.isValidName("contrarian"))')" "true"
t "reserved name"; eq "$(libcall 'console.log(m.isValidName("team"))')" "false"
t "bad chars";     eq "$(libcall 'console.log(m.isValidName("Bad Name"))')" "false"
printf -- '---\nname: contrarian\ndescription: bundled\n---\nBUNDLED BODY.\n' > "$CLAUDE_PLUGIN_ROOT/personas/contrarian.md"
t "resolves bundled"; eq "$(libcall 'console.log(m.readPersonaBody("contrarian"))')" "BUNDLED BODY."
printf -- '---\nname: contrarian\ndescription: personal\n---\nPERSONAL BODY.\n' > "$HOME/.claude/personas/contrarian.md"
t "personal overrides bundled"; eq "$(libcall 'console.log(m.readPersonaBody("contrarian"))')" "PERSONAL BODY."
printf -- '---\nname: ghost\ndescription: x\n---\nG.\n' > "$HOME/.claude/personas/ghost.md"
t "list union sorted"; eq "$(libcall 'console.log(m.listPersonas().join(","))')" "contrarian,ghost"

finish
