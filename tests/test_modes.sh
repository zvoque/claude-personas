#!/usr/bin/env bash
set -u
. "$(dirname "$0")/helpers.sh"

fresh_home
trap 'rm -rf "$HOME"' EXIT

# --- activation -------------------------------------------------------------
out="$(run '{"prompt":"/contrarian"}' "$TRACKER")"
t "activation: flag created";            assert_file "$FLAG"
t "activation: persona injected";        assert_contains "$out" "CONTRARIAN MODE ACTIVE"
t "activation: additionalContext shape"; assert_contains "$out" "additionalContext"
t "activation: frontmatter stripped";    assert_not_contains "$out" "mode: true"

# --- persistence (unrelated next prompt) ------------------------------------
out="$(run '{"prompt":"what time is it"}' "$TRACKER")"
t "persistence: re-injected every turn"; assert_contains "$out" "CONTRARIAN MODE ACTIVE"

# --- SessionStart resume ----------------------------------------------------
out="$(printf '%s' '{"source":"resume"}' | bash "$ACTIVATE")"
t "sessionstart: injects when active";   assert_contains "$out" "CONTRARIAN MODE ACTIVE"

# --- deactivation -----------------------------------------------------------
out="$(run '{"prompt":"stop contrarian"}' "$TRACKER")"
t "deactivation: flag cleared";          assert_no_file "$FLAG"
t "deactivation: OFF override injected";  assert_contains "$out" "now OFF"
out="$(run '{"prompt":"hello again"}' "$TRACKER")"
t "deactivation: silent after off";      assert_eq "$out" ""

# --- normal mode global off -------------------------------------------------
run '{"prompt":"/contrarian"}' "$TRACKER" >/dev/null
run '{"prompt":"normal mode"}'  "$TRACKER" >/dev/null
t "normal mode turns off";               assert_no_file "$FLAG"

# --- false-positive guards --------------------------------------------------
run '{"prompt":"explain vim normal mode keybindings"}' "$TRACKER" >/dev/null || true
t "no spurious activation from prose";   assert_no_file "$FLAG"
run '{"prompt":"/nonexistent"}' "$TRACKER" >/dev/null
t "unknown mode ignored";                assert_no_file "$FLAG"
mkdir -p "$HOME/.claude/skills/plainskill"
printf -- '---\nname: plainskill\ndescription: x\n---\nbody\n' > "$HOME/.claude/skills/plainskill/SKILL.md"
run '{"prompt":"/plainskill"}' "$TRACKER" >/dev/null
t "unmarked skill not a mode";           assert_no_file "$FLAG"

# --- path traversal guard ---------------------------------------------------
printf '../../etc/passwd' > "$FLAG"
out="$(run '{"prompt":"hi"}' "$TRACKER")"
t "malformed flag rejected";             assert_eq "$out" ""
rm -f "$FLAG"

# --- personal-mode fallback (~/.claude/skills, NOT bundled in the plugin) ----
mkdir -p "$HOME/.claude/skills/feral"
printf -- '---\nname: feral\ndescription: y\nmode: true\n---\nFERAL MODE ACTIVE.\n' > "$HOME/.claude/skills/feral/SKILL.md"
out="$(run '{"prompt":"/feral"}' "$TRACKER")"
t "personal mode: flag created";                 assert_file "$FLAG"
t "personal mode: injected from ~/.claude/skills"; assert_contains "$out" "FERAL MODE ACTIVE"

finish
