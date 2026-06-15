#!/usr/bin/env bash
# Shared helpers for the "modes" plugin hooks (pure bash + awk — no node, jq, or
# python, so it runs on every Claude Code install method).
#
# Single source of truth for: flag file location, mode-skill resolution,
# mode-name validation, persona reading (frontmatter stripped), JSON-escaped
# context emission, and debug logging.
#
# Everything here is defensive: any failure degrades to "do nothing" so a broken
# install can never block prompt submission or session start. Sourced by the two
# hook scripts; not meant to be run directly.

export LC_ALL=C   # byte-wise globs / awk: deterministic, UTF-8 passes through

CLAUDE_DIR="${HOME}/.claude"
FLAG_FILE="${CLAUDE_DIR}/.modes-active"

# Where mode skills live. Resolved in order:
#   1. ${CLAUDE_PLUGIN_ROOT}/skills  — modes bundled with this plugin. Claude
#      Code sets CLAUDE_PLUGIN_ROOT when it runs the hook, pointing at the
#      installed (read-only) plugin directory.
#   2. ~/.claude/skills              — personal modes a user drops in without
#      editing the installed plugin, and the legacy flat-install location.
# Searching both is what lets you add a mode locally (path 2) even though the
# marketplace plugin itself is read-only (path 1).
modes_skills_dirs() {
  [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && printf '%s\n' "${CLAUDE_PLUGIN_ROOT}/skills"
  printf '%s\n' "${CLAUDE_DIR}/skills"
}

modes_debug() {
  [ "${MODES_DEBUG:-}" = "1" ] || return 0
  printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null)" "$1" \
    >> "${CLAUDE_DIR}/.modes-debug.log" 2>/dev/null || true
}

# Mode names must be safe directory names — guards against path traversal when a
# malformed flag value is read back and used to build a file path. Equivalent to
# /^[a-z0-9][a-z0-9-]*$/ , done with globs (no locale/regex surprises).
is_valid_mode() {
  case "$1" in
    ''|*[!a-z0-9-]*) return 1 ;;   # empty, or contains a char outside the set
  esac
  case "$1" in
    [a-z0-9]*) return 0 ;;          # first char must be a letter or digit
    *)         return 1 ;;
  esac
}

# Print the first existing <dir>/<mode>/SKILL.md across the candidate dirs.
# Bundled modes win over personal ones of the same name. Returns 1 if none.
skill_file() {
  is_valid_mode "$1" || return 1
  local m="$1" dir f
  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    f="${dir}/${m}/SKILL.md"
    if [ -f "$f" ]; then printf '%s' "$f"; return 0; fi
  done <<EOF
$(modes_skills_dirs)
EOF
  return 1
}

# Print the YAML frontmatter block (between the leading '---' and the next
# '---'). Empty if the file doesn't open with a frontmatter fence.
_modes_frontmatter() {
  awk '
    NR==1 { sub(/^\357\273\277/,""); sub(/\r$/,""); if ($0!="---") exit; next }
    { sub(/\r$/,""); if ($0=="---") exit; print }
  ' "$1" 2>/dev/null
}

# True only if a resolvable SKILL.md exists AND its frontmatter declares
# `mode: true`, so ordinary skills can never be hijacked into a persona.
mode_exists() {
  local f
  f="$(skill_file "$1")" || return 1
  [ -n "$f" ] || return 1
  _modes_frontmatter "$f" | grep -Eq '(^|[[:space:]])mode:[[:space:]]*true([[:space:]]|$)'
}

# Echo the currently active mode name (validated + backed by a real marked
# skill), or return 1.
get_active_mode() {
  local raw
  raw="$(cat "$FLAG_FILE" 2>/dev/null)" || return 1
  # trim leading/trailing whitespace
  raw="${raw#"${raw%%[![:space:]]*}"}"
  raw="${raw%"${raw##*[![:space:]]}"}"
  [ -n "$raw" ] || return 1
  if ! is_valid_mode "$raw"; then modes_debug "flag value invalid: $raw"; return 1; fi
  if ! mode_exists "$raw"; then modes_debug "flag set to \"$raw\" but no marked mode skill"; return 1; fi
  printf '%s' "$raw"
}

set_active_mode() {
  is_valid_mode "$1" || return 1
  mkdir -p "$CLAUDE_DIR" 2>/dev/null || true
  printf '%s\n' "$1" > "$FLAG_FILE" 2>/dev/null && modes_debug "activated: $1"
}

clear_active_mode() {
  rm -f "$FLAG_FILE" 2>/dev/null || true
  modes_debug "deactivated"
}

# Read a mode's persona body with the YAML frontmatter stripped and leading
# blank lines removed, so the hook injects only the instructions. (Trailing
# whitespace is trimmed by the caller's command substitution.)
read_persona() {
  local f
  f="$(skill_file "$1")" || return 1
  [ -n "$f" ] || return 1
  awk '
    BEGIN { state=0 }
    {
      line=$0
      if (NR==1) sub(/^\357\273\277/,"",line)
      sub(/\r$/,"",line)
      if (state==0)      { if (line=="---") { state=1; next } else state=3 }
      else if (state==1) { if (line=="---") { state=2; next } else next }
      print line
    }
  ' "$f" 2>/dev/null | awk 'p||/[^ \t]/{p=1; print}'
}

# Print stdin as a JSON string literal (with surrounding quotes), matching
# JavaScript JSON.stringify: escape \ " and control chars; pass UTF-8 through.
_modes_json_string() {
  awk '
    BEGIN { for (i=0;i<256;i++) ORD[sprintf("%c",i)]=i; printf "\"" }
    {
      if (NR>1) printf "\\n"           # awk split on newline; re-emit it escaped
      L=length($0)
      for (i=1;i<=L;i++) {
        c=substr($0,i,1); b=ORD[c]
        if      (c=="\\") printf "\\\\"
        else if (c=="\"") printf "\\\""
        else if (b==8)    printf "\\b"
        else if (b==9)    printf "\\t"
        else if (b==12)   printf "\\f"
        else if (b==13)   printf "\\r"
        else if (b<32)    printf "\\u%04x", b
        else              printf "%c", c
      }
    }
    END { printf "\"" }
  '
}

# Emit the documented hook output envelope so Claude Code injects the text as
# context. Raw stdout is NOT parsed for context — this exact JSON shape is.
emit_context() {
  local event="$1" text="$2"
  [ -n "$text" ] || return 0
  printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":' "$event"
  printf '%s' "$text" | _modes_json_string
  printf '}}'
}

# Best-effort extraction of the top-level JSON "prompt" value from a hook stdin
# payload, with common escapes decoded. Pure awk (no jq/python/node). Triggers
# are plain ASCII, so this is faithful for every realistic prompt.
_modes_extract_prompt() {
  awk '
    { buf = buf $0 "\n" }
    END {
      n = index(buf, "\"prompt\"")
      if (n == 0) exit
      rest = substr(buf, n + 8)
      before = rest
      sub(/^[ \t\r\n]*:[ \t\r\n]*"/, "", rest)
      if (rest == before) exit            # no string value -> bail
      L = length(rest); i = 1; out = ""
      while (i <= L) {
        c = substr(rest, i, 1)
        if (c == "\\") {
          d = substr(rest, i+1, 1)
          if      (d == "n") out = out "\n"
          else if (d == "t") out = out "\t"
          else if (d == "r") out = out "\r"
          else if (d == "b") out = out sprintf("%c", 8)
          else if (d == "f") out = out sprintf("%c", 12)
          else if (d == "u") { i += 4 }   # skip \uXXXX (not used by triggers)
          else out = out d                # \"  \\  \/  and any other
          i += 2
        } else if (c == "\"") {
          break                            # closing quote -> end of value
        } else { out = out c; i++ }
      }
      printf "%s", out
    }
  '
}
