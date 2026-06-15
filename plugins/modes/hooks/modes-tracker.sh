#!/usr/bin/env bash
# UserPromptSubmit hook.
# Runs on EVERY prompt. Responsibilities:
#   1. Detect activation triggers   -> set the flag
#   2. Detect deactivation triggers -> clear the flag + inject an OFF override
#   3. While a mode is active        -> re-inject the persona every turn
#
# Re-injecting each turn is what makes the mode actually persist (and what makes
# deactivation take effect immediately — we simply stop re-asserting).
#
# Never blocks the prompt: all errors are swallowed and we exit 0.

export LC_ALL=C
. "$(cd "$(dirname "$0")" && pwd)/modes-lib.sh"

# Returns via globals INTENT_ACTION ('on'|'off'|'') and INTENT_MODE ('' = global).
# Deactivation is checked first so "stop X" never reads as activation. Order and
# boundaries mirror the original Node parseIntent exactly.
parse_intent() {
  INTENT_ACTION=""; INTENT_MODE=""
  local norm="$1"
  [ -n "$norm" ] || return 0

  # "normal mode" — global off. Whole prompt only, so "in CSS, normal mode
  # means..." doesn't fire.
  if [ "$norm" = "normal mode" ] || [ "$norm" = "/normal" ] || [ "$norm" = "normal" ]; then
    INTENT_ACTION="off"; INTENT_MODE=""; return 0
  fi
  # "/contrarian off"
  if [[ "$norm" =~ ^/([a-z0-9][a-z0-9-]*)[[:space:]]+off([[:space:]]|$) ]]; then
    INTENT_ACTION="off"; INTENT_MODE="${BASH_REMATCH[1]}"; return 0
  fi
  # "stop contrarian" / "stop contrarian mode"
  if [[ "$norm" =~ (^|[^a-z0-9-])stop[[:space:]]+([a-z0-9][a-z0-9-]*) ]]; then
    INTENT_ACTION="off"; INTENT_MODE="${BASH_REMATCH[2]}"; return 0
  fi
  # "/contrarian" at the start of the message — only if it's a real mode.
  if [[ "$norm" =~ ^/([a-z0-9][a-z0-9-]*) ]]; then
    if mode_exists "${BASH_REMATCH[1]}"; then
      INTENT_ACTION="on"; INTENT_MODE="${BASH_REMATCH[1]}"; return 0
    fi
  fi
  # Natural language "contrarian mode" — only if that mode really exists, which
  # keeps generic "X mode" phrasing from triggering anything.
  if [[ "$norm" =~ (^|[^a-z0-9-])([a-z0-9][a-z0-9-]*)[[:space:]]+mode([^a-z0-9-]|$) ]]; then
    if mode_exists "${BASH_REMATCH[2]}"; then
      INTENT_ACTION="on"; INTENT_MODE="${BASH_REMATCH[2]}"; return 0
    fi
  fi
  return 0
}

main() {
  local payload prompt norm
  payload="$(cat 2>/dev/null)"
  prompt="$(printf '%s' "$payload" | _modes_extract_prompt)"
  norm="$(printf '%s' "$prompt" | tr 'A-Z' 'a-z')"
  # trim leading/trailing whitespace (incl. newlines), mirroring String.trim()
  norm="${norm#"${norm%%[![:space:]]*}"}"
  norm="${norm%"${norm##*[![:space:]]}"}"

  parse_intent "$norm"

  if [ "$INTENT_ACTION" = "off" ]; then
    local was
    was="$(get_active_mode)" || was=""
    # Global off, or off matching the active mode.
    if [ -z "$INTENT_MODE" ] || [ "$INTENT_MODE" = "$was" ]; then
      clear_active_mode
      if [ -n "$was" ]; then
        emit_context "UserPromptSubmit" \
          "${was} mode is now OFF. Disregard the ${was} persona for the rest of this conversation and resume your normal behavior."
      fi
      return 0
    fi
    # "stop foo" while "bar" is active — ignore, leave bar running (fall through).
  fi

  if [ "$INTENT_ACTION" = "on" ]; then
    set_active_mode "$INTENT_MODE"
  fi

  local active persona
  active="$(get_active_mode)" || active=""
  if [ -n "$active" ]; then
    persona="$(read_persona "$active")" || persona=""
    [ -n "$persona" ] && emit_context "UserPromptSubmit" "$persona"
  fi
  return 0
}

main || modes_debug "tracker fatal"
exit 0
