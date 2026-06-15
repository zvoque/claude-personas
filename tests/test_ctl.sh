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

# ===== injection + helpers =====
reset
printf -- '---\nname: contrarian\ndescription: x\n---\nBE SHARP.\n' > "$HOME/.claude/personas/contrarian.md"
printf -- '---\nname: hype\ndescription: x\n---\nBE LOUD.\n' > "$HOME/.claude/personas/hype.md"
t "isPersonasCommand yes"; eq "$(libcall 'console.log(m.isPersonasCommand("/personas team x"))')" "true"
t "isPersonasCommand no";  eq "$(libcall 'console.log(m.isPersonasCommand("about the personas feature"))')" "false"
t "full solo body"; eq "$(libcall 'console.log(m.fullInjection({mode:"solo",enabled:["contrarian"]}))')" "BE SHARP."
out="$(libcall 'console.log(m.fullInjection({mode:"parallel",enabled:["contrarian","hype"]}))')"
t "full parallel header"; contains "$out" "Respond as each in turn"
t "full parallel both"; contains "$out" "BE SHARP."; contains "$out" "BE LOUD."
out="$(libcall 'console.log(m.shortReassertion({mode:"solo",enabled:["contrarian"]}))')"
t "short names persona"; contains "$out" "contrarian"
t "short is short"; ncontains "$out" "BE SHARP."
out="$(libcall 'm.emitContext("UserPromptSubmit","hi \"q\"\nline2")')"
t "emit valid JSON"; eq "$(node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{console.log(JSON.parse(s).hookSpecificOutput.additionalContext)})' <<<"$out")" 'hi "q"
line2'

# ===== CLI control =====
reset
printf -- '---\nname: contrarian\ndescription: x\n---\nB.\n' > "$HOME/.claude/personas/contrarian.md"
printf -- '---\nname: hype\ndescription: x\n---\nL.\n' > "$HOME/.claude/personas/hype.md"
ctl() { node "$CTL" "$@"; }
ctl enable contrarian >/dev/null
t "solo enable sets one"; eq "$(libcall 'const s=m.readState();console.log(s.mode+":"+s.enabled.join(","))')" "solo:contrarian"
ctl enable hype >/dev/null
t "solo enable replaces"; eq "$(libcall 'console.log(m.readState().enabled.join(","))')" "hype"
ctl parallel >/dev/null; ctl enable contrarian >/dev/null
t "parallel appends"; eq "$(libcall 'const s=m.readState();console.log(s.mode+":"+s.enabled.slice().sort().join(","))')" "parallel:contrarian,hype"
ctl disable hype >/dev/null
t "disable removes"; eq "$(libcall 'console.log(m.readState().enabled.join(","))')" "contrarian"
ctl off >/dev/null
t "off clears all"; eq "$(libcall 'console.log(m.readState().enabled.length)')" "0"
ctl enable contrarian >/dev/null; ctl enable hype >/dev/null; ctl solo >/dev/null
t "solo collapses to last"; eq "$(libcall 'const s=m.readState();console.log(s.mode+":"+s.enabled.join(","))')" "solo:hype"
out="$(ctl list)"; t "list shows mode + marker"; contains "$out" "solo"; contains "$out" "* hype"
out="$(ctl enable nope 2>&1 || true)"; t "enable unknown errors"; contains "$out" "no such persona"

finish
